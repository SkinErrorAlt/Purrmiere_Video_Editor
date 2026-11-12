extends RefCounted

const SELF := preload("res://modules/core_panels/panel_place.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Io := preload("res://doc/io.gd")
const VIEW_KEY := "places"
const TOKEN_KEY := "places_id"
const PREF_APP := "ui.fold.places"
const CAP := 2000
const SAVE_QUIET_S := 1.5
const HOLD_FRAMES := 3
const EC := "effect_controls"
const KEYS := "keyframes"
const BIN := "bin"
const MIX := "audio_mix"
const SOURCE := "source"
const WAVE := "audio_editor"
const SETTINGS := "settings"
const META := "pm_place"
const CLIP_PREFIX := "clip:"

static var in_suites: bool = false
static var writes: int = 0
static var last_write_ms: float = 0.0
static var _adopted: Dictionary = {}
static var _pending: Array[WeakRef] = []
static var _armed: bool = false
static var _due: float = 0.0
static var _app: Dictionary = {}
static var _app_loaded: bool = false
static var _app_dirty: bool = false
static var _capture: Dictionary = {}
static var _tasks: Array[int] = []
static var _outs: Array[Array] = []
static var last_job_ok: bool = false
static var off: bool = OS.get_environment("PM_PLACES_OFF") == "1"


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


static func _stamp() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


static func token(d: Project) -> String:
	var t: Variant = d.view.get(TOKEN_KEY, "")
	if t is String and not (t as String).is_empty():
		return t
	var fresh: String = "%08x%04x" % [randi(), randi() % 65536]
	d.view[TOKEN_KEY] = fresh
	return fresh


static func store(d: Project, panel: String) -> Dictionary:
	var all_v: Variant = d.view.get(VIEW_KEY, null)
	var all: Dictionary = {}
	if all_v is Dictionary:
		all = all_v
	else:
		d.view[VIEW_KEY] = all
	var iid: int = d.get_instance_id()
	if not _adopted.has(iid):
		_adopted[iid] = true
		_adopt(d, all)
	var p: Variant = all.get(panel, null)
	if p is Dictionary:
		return p
	var fresh: Dictionary = {}
	all[panel] = fresh
	return fresh


static func _adopt(d: Project, all: Dictionary) -> void:
	if all.is_empty():
		return
	var pre: String = token(d) + "/"
	for panel: String in [EC, KEYS, WAVE]:
		var st: Variant = all.get(panel, null)
		if not (st is Dictionary):
			continue
		for k: Variant in (st as Dictionary).keys():
			var ks: String = String(k)
			if not ks.begins_with(CLIP_PREFIX):
				continue
			var cid: String = ks.substr(CLIP_PREFIX.length())
			var c: Clip = d.clip_by_id(cid)
			if c != null and c.place != pre + cid:
				c.place = pre + cid


static func inherited_id(d: Project, c: Clip) -> String:
	if c == null or c.place.is_empty():
		return ""
	var pre: String = token(d) + "/"
	if not c.place.begins_with(pre):
		return ""
	return c.place.substr(pre.length())


static func for_clip(d: Project, panel: String, c: Clip) -> Dictionary:
	if d == null or c == null:
		return {}
	var st: Dictionary = store(d, panel)
	var own: Variant = st.get(CLIP_PREFIX + c.id, null)
	if own is Dictionary:
		return own
	var from: String = inherited_id(d, c)
	if not from.is_empty() and from != c.id:
		var inh: Variant = st.get(CLIP_PREFIX + from, null)
		if inh is Dictionary:
			return inh
	return {}


static func put_clip(d: Project, panel: String, c: Clip, data: Dictionary) -> bool:
	if d == null or c == null:
		return false
	var st: Dictionary = store(d, panel)
	var k: String = CLIP_PREFIX + c.id
	var own: Variant = st.get(k, null)
	var entry: Dictionary = {}
	if own is Dictionary:
		entry = own
	else:
		entry = for_clip(d, panel, c).duplicate(true)
	var changed: bool = not (own is Dictionary)
	for key: Variant in data.keys():
		if not entry.has(key) or entry[key] != data[key]:
			entry[key] = data[key]
			changed = true
	var tag: String = token(d) + "/" + c.id
	if c.place != tag:
		c.place = tag
	if not changed:
		return false
	entry["t"] = _stamp()
	st[k] = entry
	_prune(st)
	touch(d)
	return true


static func for_thing(d: Project, panel: String, key: String) -> Dictionary:
	if d == null or key.is_empty():
		return {}
	var v: Variant = store(d, panel).get(key, null)
	return v if v is Dictionary else {}


static func put_thing(d: Project, panel: String, key: String, data: Dictionary) -> bool:
	if d == null or key.is_empty():
		return false
	var st: Dictionary = store(d, panel)
	var own: Variant = st.get(key, null)
	var entry: Dictionary = own if own is Dictionary else {}
	var changed: bool = not (own is Dictionary)
	for k: Variant in data.keys():
		if not entry.has(k) or entry[k] != data[k]:
			entry[k] = data[k]
			changed = true
	if not changed:
		return false
	entry["t"] = _stamp()
	st[key] = entry
	_prune(st)
	touch(d)
	return true


static func _prune(st: Dictionary) -> void:
	if st.size() <= CAP:
		return
	var keys: Array = st.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int((st[a] as Dictionary).get("t", 0)) < int((st[b] as Dictionary).get("t", 0)))
	var drop: int = st.size() - int(float(CAP) * 0.8)
	for i: int in drop:
		st.erase(keys[i])


static func _load_app() -> void:
	if _app_loaded:
		return
	_app_loaded = true
	if not Prefs.is_registered(PREF_APP):
		Prefs.register(PREF_APP, {}, {"label": "Where panels were scrolled to", "type": "dict"})
	var v: Variant = Prefs.get_value(PREF_APP)
	_app = (v as Dictionary).duplicate(true) if v is Dictionary else {}


static func for_app(key: String) -> Dictionary:
	_load_app()
	var v: Variant = _app.get(key, null)
	return v if v is Dictionary else {}


static func put_app(key: String, data: Dictionary) -> bool:
	_load_app()
	var own: Variant = _app.get(key, null)
	var entry: Dictionary = own if own is Dictionary else {}
	var changed: bool = not (own is Dictionary)
	for k: Variant in data.keys():
		if not entry.has(k) or entry[k] != data[k]:
			entry[k] = data[k]
			changed = true
	if not changed:
		return false
	_app[key] = entry
	_app_dirty = true
	_arm()
	return true


static func touch(d: Project) -> void:
	if d == null:
		return
	for w: WeakRef in _pending:
		if w.get_ref() == d:
			_arm()
			return
	_pending.append(weakref(d))
	_arm()


static func _arm() -> void:
	_due = _now() + SAVE_QUIET_S
	if _armed:
		return
	var tree: SceneTree = _tree()
	if tree == null:
		return
	_armed = true
	tree.create_timer(SAVE_QUIET_S).timeout.connect(func() -> void: SELF._on_timer())


static func _on_timer() -> void:
	_armed = false
	var left: float = _due - _now()
	if left > 0.02:
		var tree: SceneTree = _tree()
		if tree != null:
			_armed = true
			tree.create_timer(left).timeout.connect(func() -> void: SELF._on_timer())
		return
	flush()


static func may_write() -> bool:
	return in_suites or not Prefs.running_suite()


static func flush() -> int:
	for ck: Variant in _capture.keys():
		var cb: Callable = _capture[ck]
		if cb.is_valid():
			cb.call()
		else:
			_capture.erase(ck)
	var n: int = 0
	var keep: Array[WeakRef] = []
	var busy: bool = writing()
	for w: WeakRef in _pending:
		var d: Variant = w.get_ref()
		if not (d is Project):
			continue
		var p: Project = d
		if p.path.is_empty() or not may_write():
			continue
		if Io.background_busy() or busy:
			keep.append(w)
			continue
		var t0: int = Time.get_ticks_usec()
		var target: String = ProjectSettings.globalize_path(Io.view_path(p.path))
		var out: Array = []
		_outs.append(out)
		_tasks.append(WorkerThreadPool.add_task(Callable(SELF, "_write_job").bind(p.view.duplicate(true), target, out), false, "Save panel places"))
		n += 1
		writes += 1
		last_write_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	_pending = keep
	if _app_dirty and may_write():
		_app_dirty = false
		Prefs.set_value(PREF_APP, _app.duplicate(true))
	if not _pending.is_empty():
		_arm()
	return n


static func writing() -> bool:
	for t: int in _tasks:
		if not WorkerThreadPool.is_task_completed(t):
			return true
	if not _tasks.is_empty():
		wait()
	return false


static func wait() -> bool:
	var ok: bool = true
	for t: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	for out: Array in _outs:
		ok = ok and not out.is_empty() and bool(out[0])
	if not _tasks.is_empty():
		last_job_ok = ok
	_tasks.clear()
	_outs.clear()
	return last_job_ok


static func _write_job(view: Dictionary, target: String, out: Array) -> void:
	var text: String = JSON.stringify(view, "\t", false, true)
	if text.strip_edges().is_empty():
		text = "{}"
	var tmp: String = target + ".places.tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		out.append(false)
		return
	f.store_string(text)
	f.flush()
	f.close()
	if FileAccess.file_exists(target):
		DirAccess.remove_absolute(target)
	out.append(DirAccess.rename_absolute(tmp, target) == OK)


static func pending_count() -> int:
	return _pending.size()


static func on_capture(what: String, panel: Object, method: String) -> void:
	var ck: String = what + str(panel.get_instance_id())
	if not _capture.has(ck):
		_capture[ck] = Callable(SELF, method).bind(weakref(panel))


static func doc_key(d: Project) -> String:
	return str(d.get_instance_id()) + "|" if d != null else ""


class Keeper:
	extends RefCounted

	var key_fn: Callable = Callable()
	var read_y: Callable = Callable()
	var write_y: Callable = Callable()
	var load_fn: Callable = Callable()
	var save_fn: Callable = Callable()
	var arrive_fn: Callable = Callable()
	var visible_fn: Callable = Callable()
	var last_key: String = ""
	var hold_until: int = 0
	var want: float = -1.0
	var tries: int = 0

	func holding() -> bool:
		return Engine.get_process_frames() <= hold_until

	func changed(_a: Variant = null) -> void:
		if last_key.is_empty() or holding():
			return
		if visible_fn.is_valid() and not bool(visible_fn.call()):
			return
		var k: String = String(key_fn.call())
		if k != last_key:
			return
		save_fn.call(k, {"y": roundf(float(read_y.call()))})

	func leave() -> void:
		var k: String = String(key_fn.call())
		if k != last_key:
			last_key = ""

	func turn() -> bool:
		var k: String = String(key_fn.call())
		if k == last_key:
			return false
		last_key = k
		if k.is_empty():
			return true
		var data: Dictionary = load_fn.call(k)
		if arrive_fn.is_valid():
			arrive_fn.call(k, data)
		if data.has("y"):
			go(float(data["y"]))
		return true

	func go(y: float) -> void:
		want = maxf(y, 0.0)
		tries = HOLD_FRAMES
		hold_until = Engine.get_process_frames() + HOLD_FRAMES + 1
		write_y.call(want)
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null and not tree.process_frame.is_connected(_retry):
			tree.process_frame.connect(_retry, CONNECT_ONE_SHOT)

	func _retry() -> void:
		tries -= 1
		if want >= 0.0:
			write_y.call(want)
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tries > 0 and tree != null:
			hold_until = maxi(hold_until, Engine.get_process_frames() + 1)
			tree.process_frame.connect(_retry, CONNECT_ONE_SHOT)
		else:
			want = -1.0


static func keeper_of(holder: Object) -> Keeper:
	if holder == null or not holder.has_meta(META):
		return null
	var k: Variant = holder.get_meta(META)
	return k as Keeper


static func _scroll_keeper(scroll: ScrollContainer, key_fn: Callable, load_fn: Callable, save_fn: Callable) -> Keeper:
	var kp: Keeper = keeper_of(scroll)
	if kp != null:
		return kp
	kp = Keeper.new()
	kp.key_fn = key_fn
	kp.load_fn = load_fn
	kp.save_fn = save_fn
	kp.read_y = func() -> float: return float(scroll.scroll_vertical)
	kp.write_y = func(y: float) -> void:
		if is_instance_valid(scroll):
			scroll.scroll_vertical = int(y)
	kp.visible_fn = func() -> bool: return is_instance_valid(scroll) and scroll.is_visible_in_tree() and scroll.size.y > 1.0
	scroll.set_meta(META, kp)
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	if bar != null:
		bar.value_changed.connect(kp.changed)
	return kp


static func live_node(panel: Object, prop: String) -> Object:
	if panel == null or not is_instance_valid(panel):
		return null
	var v: Variant = panel.get(prop)
	if v == null or not is_instance_valid(v):
		return null
	return v as Object


static func _doc_of(panel: Object) -> Project:
	var v: Variant = panel.call("doc")
	return v as Project


static func _seq_of(panel: Object) -> Sequence:
	var v: Variant = panel.call("seq")
	return v as Sequence


static func ec_key(panel: Object) -> String:
	if not (panel.call("many_clips") as Array).is_empty():
		return ""
	var c: Variant = panel.call("target_clip")
	var d: Project = _doc_of(panel)
	if not (c is Clip) or d == null:
		return ""
	return doc_key(d) + CLIP_PREFIX + (c as Clip).id


static func _ec_clip(panel: Object, key: String) -> Clip:
	var d: Project = _doc_of(panel)
	if d == null or key.is_empty():
		return null
	var cid: String = key.get_slice(CLIP_PREFIX, 1)
	return d.clip_by_id(cid)


static func ec_keeper(panel: Object) -> Keeper:
	var scroll: ScrollContainer = panel.get("_scroll")
	if scroll == null:
		return null
	var kp: Keeper = keeper_of(scroll)
	if kp != null:
		return kp
	kp = _scroll_keeper(scroll, func() -> String: return SELF.ec_key(panel),
		func(k: String) -> Dictionary: return SELF.for_clip(SELF._doc_of(panel), EC, SELF._ec_clip(panel, k)),
		func(k: String, data: Dictionary) -> void: SELF.put_clip(SELF._doc_of(panel), EC, SELF._ec_clip(panel, k), SELF._with_folds(panel, data)))
	kp.arrive_fn = func(_k: String, data: Dictionary) -> void: SELF.apply_folds(panel, data)
	return kp


static func ec_leave(panel: Object) -> void:
	if off:
		return
	var kp: Keeper = ec_keeper(panel)
	if kp != null:
		kp.leave()


static func ec_arrive(panel: Object) -> void:
	if off:
		return
	var kp: Keeper = ec_keeper(panel)
	if kp == null:
		return
	kp.turn()
	load("res://modules/core_panels/section_style.gd").call("paint_list", panel.get("_list"), ec_styles(panel))


static func ec_styles(panel: Object) -> Dictionary:
	var kp: Keeper = ec_keeper(panel)
	if kp == null or kp.last_key.is_empty():
		return {}
	var c: Clip = _ec_clip(panel, kp.last_key)
	var v: Variant = for_clip(_doc_of(panel), EC, c).get("styles", {})
	return v if v is Dictionary else {}


static func ec_clip(panel: Object) -> Clip:
	var kp: Keeper = ec_keeper(panel)
	if kp == null or kp.last_key.is_empty():
		return null
	return _ec_clip(panel, kp.last_key)


static func set_clip_style(panel: Object, section: String, style: Variant) -> bool:
	var c: Clip = ec_clip(panel)
	var d: Project = _doc_of(panel)
	if c == null or d == null:
		return false
	var styles: Dictionary = ec_styles(panel).duplicate(true)
	if style == null:
		styles.erase(section)
	else:
		styles[section] = style
	put_clip(d, EC, c, {"styles": styles})
	return true


static func folds_in(list: Control) -> Array[Control]:
	var out: Array[Control] = []
	if list == null:
		return out
	for holder: Node in list.get_children():
		if not (holder is Control) or not (holder as Control).visible:
			continue
		var f: Control = fold_of(holder)
		if f != null:
			out.append(f)
	return out


static func fold_of(holder: Node) -> Control:
	if holder.has_method("show_open"):
		return holder as Control
	for ch: Node in holder.get_children():
		if ch.has_method("show_open"):
			return ch as Control
	return null


static func fold_ids(folds: Array[Control]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for f: Control in folds:
		var k: String = String(f.get("key"))
		var n: int = int(seen.get(k, 0))
		seen[k] = n + 1
		out.append(k + "#" + str(n))
	return out


static func apply_folds(panel: Object, data: Dictionary) -> void:
	var folds: Array[Control] = folds_in(panel.get("_list"))
	var ids: PackedStringArray = fold_ids(folds)
	var saved: Variant = data.get("folds", {})
	var map: Dictionary = saved if saved is Dictionary else {}
	for i: int in folds.size():
		var f: Control = folds[i]
		var want: bool = bool(f.get("open"))
		if map.has(ids[i]):
			want = bool(map[ids[i]])
		else:
			var pk: String = "ui.fold." + String(f.get("key"))
			if Prefs.is_registered(pk):
				want = bool(Prefs.get_value(pk))
		if bool(f.get("open")) != want:
			f.call("show_open", want)


static func record_folds(panel: Object) -> void:
	var kp: Keeper = ec_keeper(panel)
	if kp == null or kp.last_key.is_empty() or ec_key(panel) != kp.last_key:
		return
	put_clip(_doc_of(panel), EC, _ec_clip(panel, kp.last_key), _with_folds(panel, {"y": roundf(float(kp.read_y.call()))}))


static func fold_map(panel: Object) -> Dictionary:
	var folds: Array[Control] = folds_in(panel.get("_list"))
	var ids: PackedStringArray = fold_ids(folds)
	var map: Dictionary = {}
	for i: int in folds.size():
		map[ids[i]] = bool(folds[i].get("open"))
	return map


static func _with_folds(panel: Object, data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate()
	out["folds"] = fold_map(panel)
	return out


static func fold_made(panel: Object, f: Control, holder: Control) -> void:
	if off:
		return
	f.connect("toggled", Callable(SELF, "_on_fold_toggled").bind(panel))
	load("res://modules/core_panels/section_style.gd").call("attach", f, holder, panel)


static func _on_fold_toggled(_open: bool, panel: Object) -> void:
	if is_instance_valid(panel):
		record_folds(panel)


static func keys_turn(panel: Object) -> void:
	var d: Project = _doc_of(panel)
	var list: Object = SELF.live_node(panel, "list")
	if list == null:
		return
	var c: Variant = panel.call("target_clip")
	var key: String = doc_key(d) + CLIP_PREFIX + (c as Clip).id if c is Clip and d != null else ""
	var last: String = String(list.get_meta(META, ""))
	if key == last:
		return
	_keys_record(panel)
	list.set_meta(META, key)
	on_capture(KEYS, panel, "_keys_capture")
	if key.is_empty():
		return
	var data: Dictionary = for_clip(d, KEYS, c as Clip)
	var seen: String = String(list.get_meta(META + "_seen", ""))
	if data.has("path") and String(panel.get("property_path")) == seen:
		panel.set("property_path", String(data["path"]))
		if panel.has_method("rebuild"):
			panel.call("rebuild")
		elif panel.has_method("regroup"):
			panel.call("regroup", c as Clip)
	var rows: int = int(panel.call("row_count")) if panel.has_method("row_count") else (panel.call("properties_of", c) as Array).size()
	var row_v: Variant = list.get("ROW")
	var row_h: float = float(row_v) if row_v != null else 22.0
	var top: float = maxf(float(rows) * row_h - (list as Control).size.y, 0.0)
	list.set("scroll", clampf(float(data.get("y", 0.0)), 0.0, top) if data.has("y") else 0.0)
	list.set_meta(META + "_seen", String(panel.get("property_path")))
	(list as CanvasItem).queue_redraw()


static func _keys_record(panel: Object) -> void:
	var list: Object = SELF.live_node(panel, "list")
	if list == null:
		return
	var last: String = String(list.get_meta(META, ""))
	if last.is_empty():
		return
	var d: Project = _doc_of(panel)
	if d == null or not last.begins_with(doc_key(d)):
		return
	var c: Clip = d.clip_by_id(last.get_slice(CLIP_PREFIX, 1))
	if c == null:
		return
	put_clip(d, KEYS, c, {"y": roundf(float(list.get("scroll"))), "path": String(panel.get("property_path"))})
	list.set_meta(META + "_seen", String(panel.get("property_path")))


static func _keys_capture(ref: WeakRef) -> void:
	var panel: Variant = ref.get_ref()
	if panel is Object and is_instance_valid(panel):
		_keys_record(panel)


static func settings_turn(panel: Object, scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	var kp: Keeper = keeper_of(scroll)
	if kp == null:
		kp = _scroll_keeper(scroll, func() -> String: return SETTINGS + "|" + String(panel.get("search")),
			func(k: String) -> Dictionary: return SELF.for_app(k),
			func(k: String, data: Dictionary) -> void: SELF.put_app(k, data))
	kp.turn()


static func mix_turn(panel: Object) -> void:
	var pages: Variant = panel.get("_pages")
	if not (pages is Dictionary):
		return
	var scroll: ScrollContainer = (pages as Dictionary).get("mix", null) as ScrollContainer
	if scroll == null:
		return
	var kp: Keeper = keeper_of(scroll)
	if kp == null:
		kp = _scroll_keeper(scroll, func() -> String:
				var d: Project = SELF._doc_of(panel)
				var s: Sequence = SELF._seq_of(panel)
				return SELF.doc_key(d) + s.id if d != null and s != null else "",
			func(k: String) -> Dictionary: return SELF.for_thing(SELF._doc_of(panel), MIX, k.get_slice("|", 1)),
			func(k: String, data: Dictionary) -> void: SELF.put_thing(SELF._doc_of(panel), MIX, k.get_slice("|", 1), data))
	kp.turn()


static func bin_turn(panel: Object) -> void:
	var body: Object = SELF.live_node(panel, "_body")
	if body == null:
		return
	var sc: Object = body.get("scroll")
	if sc == null:
		return
	var kp: Keeper = keeper_of(sc)
	if kp == null:
		kp = Keeper.new()
		kp.key_fn = func() -> String:
			var d: Project = SELF._doc_of(panel)
			return SELF.doc_key(d) + String(panel.get("view")) + "|" + String(panel.get("folder")) if d != null else ""
		kp.load_fn = func(k: String) -> Dictionary: return SELF.for_thing(SELF._doc_of(panel), BIN, k.substr(k.find("|") + 1))
		kp.save_fn = func(k: String, data: Dictionary) -> void: SELF.put_thing(SELF._doc_of(panel), BIN, k.substr(k.find("|") + 1), data)
		kp.read_y = func() -> float: return float(sc.get("target_y"))
		kp.write_y = func(y: float) -> void:
			if is_instance_valid(sc):
				sc.call("scroll_to", 0.0, y, false)
		kp.visible_fn = func() -> bool: return is_instance_valid(body) and (body as CanvasItem).is_visible_in_tree()
		sc.set_meta(META, kp)
		sc.connect("changed", kp.changed)
	kp.turn()


static func source_leave(panel: Object) -> void:
	var d: Project = _doc_of(panel)
	var mid: String = String(panel.get("media_id"))
	if d == null or mid.is_empty():
		return
	put_thing(d, SOURCE, mid, {"time": float(panel.get("time"))})


static func source_arrive(panel: Object, in_: float, out_: float) -> void:
	var d: Project = _doc_of(panel)
	var mid: String = String(panel.get("media_id"))
	on_capture(SOURCE, panel, "_source_capture")
	if d == null or mid.is_empty() or in_ >= 0.0 or out_ >= 0.0 or float(panel.get("in_t")) >= 0.0:
		return
	var data: Dictionary = for_thing(d, SOURCE, mid)
	if not data.has("time"):
		return
	var length: float = float(panel.call("media_length"))
	var t: float = float(data["time"])
	if length > 0.0:
		t = clampf(t, 0.0, length)
	panel.set("time", maxf(t, 0.0))


static func _source_capture(ref: WeakRef) -> void:
	var panel: Variant = ref.get_ref()
	if panel is Object and is_instance_valid(panel):
		source_leave(panel)


static func wave_turn(panel: Object, c: Clip) -> void:
	var d: Project = _doc_of(panel)
	var holder: Object = SELF.live_node(panel, "_wave")
	if d == null or holder == null or c == null:
		return
	holder.set_meta(META, doc_key(d) + CLIP_PREFIX + c.id)
	on_capture(WAVE, panel, "_wave_capture")
	var data: Dictionary = for_clip(d, WAVE, c)
	if not data.has("t0") or not data.has("t1"):
		return
	var t0: float = float(data["t0"])
	var t1: float = float(data["t1"])
	var heard: PackedFloat64Array = panel.call("heard_span", c)
	if t1 <= t0 or heard.size() < 2 or t1 <= heard[0] or t0 >= heard[1]:
		return
	panel.set("t0", t0)
	panel.set("t1", t1)
	panel.set("_fit_pending", false)


static func wave_leave(panel: Object) -> void:
	_wave_record(panel)


static func _wave_record(panel: Object) -> void:
	var d: Project = _doc_of(panel)
	var holder: Object = SELF.live_node(panel, "_wave")
	if d == null or holder == null or bool(panel.get("_fit_pending")):
		return
	var last: String = String(holder.get_meta(META, ""))
	if last.is_empty() or not last.begins_with(doc_key(d)):
		return
	var c: Clip = d.clip_by_id(last.get_slice(CLIP_PREFIX, 1))
	var t0: float = float(panel.get("t0"))
	var t1: float = float(panel.get("t1"))
	if c != null and t1 > t0:
		put_clip(d, WAVE, c, {"t0": t0, "t1": t1})


static func _wave_capture(ref: WeakRef) -> void:
	var panel: Variant = ref.get_ref()
	if panel is Object and is_instance_valid(panel):
		_wave_record(panel)

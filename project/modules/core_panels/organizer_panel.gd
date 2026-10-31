extends "res://modules/core_panels/panel_base.gd"

const Canvas := preload("res://modules/core_panels/organizer/organizer_canvas.gd")
const Overlaps := preload("res://modules/core_panels/organizer/organizer_overlaps.gd")
const KindsUi := preload("res://modules/core_panels/organizer/organizer_kinds_ui.gd")
const Regions := preload("res://doc/media_regions.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const Store := preload("res://doc/region_store.gd")
const SourceReveal := preload("res://modules/core_panels/source_reveal.gd")
const RegionApply := preload("res://doc/region_apply.gd")
const FindSheet := preload("res://modules/core_panels/organizer/find_sheet.gd")
const Found := preload("res://doc/found_regions.gd")
const FindJob := preload("res://engine/picture_find_job.gd")
const FoldersSheet := preload("res://modules/core_panels/organizer/folders_sheet.gd")
const ProjectCards := preload("res://doc/project_cards.gd")
const DesktopWatch := preload("res://engine/desktop_watch.gd")
const DesktopNotes := preload("res://doc/desktop_notes.gd")
const WATCH_LABEL := "Watch the desktop"
const WATCH_STOP_LABEL := "Stop watching the desktop"
const CARD_SHEET := "res://ui/editor/project_card_sheet.gd"
const CMD_CARD := "file.project_card"
const SHOW_ALL := "all"
const SHOW_PICKED := "picked"
const HELP := "Drag to colour a region. Drag an edge to change its length. Right click where regions overlap to see them all."

var canvas: Control = null
var show_mode: String = SHOW_ALL
var picked_ids: PackedStringArray = PackedStringArray()
var _kinds_row: Container = null
var _tool_buttons: Dictionary = {}
var _lane_button: Button = null
var _foot: Label = null
var _overlaps: Control = null
var _queued: bool = false
var _kinds_serial: int = -1
var extra_buttons: Array[Button] = []
var _apply_button: Button = null
var _watched: Project = null
var _seen: Dictionary = {}
var _check_queued: bool = false
var _applying: bool = false
var auto_runs: int = 0
var auto_finds: int = 0
var _media_seen: Dictionary = {}
var _watch_button: Button = null
var _desktop_pending: PackedStringArray = PackedStringArray()
var desktop_applied: int = 0


func setup(id_: String, title_: String) -> void:
	super(id_, title_)
	RegionApply.register_prefs()
	if not Session.project_changed.is_connected(_watch_doc):
		Session.project_changed.connect(_watch_doc)
	_watch_doc()
	if not Cmd.has(CMD_CARD):
		Cmd.register(CMD_CARD, {"label": "Project card", "category": "File", "scope": "global", "handler": open_project_card, "owner": "organizer"})


func open_project_card() -> Node:
	var d: Project = Session.doc
	if d == null:
		Events.toast("Open a project first")
		return null
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	var host: Node = _root if _alive() else (loop.root if loop != null else null)
	if host == null:
		return null
	return load(CARD_SHEET).call("open", host, d)


func _watch_doc() -> void:
	var d: Project = Session.doc
	if _watched == d:
		return
	if _watched != null and _watched.changed.is_connected(_on_watched_change):
		_watched.changed.disconnect(_on_watched_change)
	_watched = d
	_seen = {}
	_media_seen = {}
	if d != null:
		d.changed.connect(_on_watched_change)
		_mark_seen(d)
		for m: MediaItem in d.media:
			_media_seen[m.id] = true
		ProjectCards.adopt(d)


func auto_fns() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if bool(RegionApply.pref(RegionApply.PREF_AUTO_CUT, false)):
		out.append(Kinds.FN_CUT)
	if bool(RegionApply.pref(RegionApply.PREF_AUTO_MUTE, false)):
		out.append(Kinds.FN_MUTE)
		out.append(Kinds.FN_CUT_MUTE)
	return out


func _mark_seen(d: Project) -> void:
	for sq: Sequence in d.sequences:
		for t: Track in sq.all_tracks():
			for c: Clip in t.clips:
				_seen[c.id] = true


func _on_watched_change(kind: String) -> void:
	if kind == "media":
		_check_new_media()
		if not _desktop_pending.is_empty():
			_retry_desktop()
		return
	if kind != "structure" or _applying or _check_queued:
		return
	if auto_fns().is_empty():
		_seen = {}
		return
	if _seen.is_empty() and _watched != null:
		_mark_seen(_watched)
		return
	_check_queued = true
	(func() -> void: check_placed()).call_deferred()


func auto_kinds() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: Dictionary in Kinds.kinds():
		var spec: Dictionary = Found.spec_of(String(k["id"]))
		if bool(spec["auto"]) and not (spec["frames"] as Array).is_empty():
			out.append(String(k["id"]))
	return out


func _check_new_media() -> int:
	var d: Project = _watched
	if d == null:
		return 0
	var fresh: Array[MediaItem] = []
	for m: MediaItem in d.media:
		if _media_seen.has(m.id):
			continue
		_media_seen[m.id] = true
		if m.kind == "video" and not m.path.is_empty():
			fresh.append(m)
	if fresh.is_empty():
		return 0
	if not DesktopNotes.paths().is_empty():
		for m: MediaItem in fresh:
			_desktop_one(d, m)
	var kinds: PackedStringArray = auto_kinds()
	if kinds.is_empty() or not FindJob.available():
		return 0
	var n: int = 0
	for m: MediaItem in fresh:
		for k: String in kinds:
			var js: Dictionary = Found.job_spec(d, m, k, true)
			var job: RefCounted = FindJob.start(js)
			job.connect("finished", _on_auto_found.bind(js, d))
			n += 1
	return n


func _desktop_one(d: Project, m: MediaItem) -> int:
	var n: int = DesktopNotes.apply_to(d, m)
	if n < 0:
		if not _desktop_pending.has(m.id):
			_desktop_pending.append(m.id)
		return 0
	if n > 0:
		desktop_applied += 1
	return n


func _retry_desktop() -> void:
	var d: Project = _watched
	var ids: PackedStringArray = _desktop_pending.duplicate()
	_desktop_pending = PackedStringArray()
	if d == null:
		return
	for id: String in ids:
		var m: MediaItem = d.media_by_id(id)
		if m != null:
			_desktop_one(d, m)


func desktop_to_shown() -> int:
	var d: Project = doc()
	if d == null:
		return 0
	var total: int = 0
	var list: Array[Dictionary] = DesktopNotes.sessions()
	if list.is_empty():
		Events.toast("No desktop notes yet. Start the desktop watch while you record.")
		return 0
	for id: String in shown_ids():
		var m: MediaItem = d.media_by_id(id)
		if m != null and m.kind == "video":
			total += maxi(DesktopNotes.apply_to(d, m, list), 0)
	Events.toast("Desktop notes: %d part%s put on the videos" % [total, "" if total == 1 else "s"])
	return total


func toggle_watch() -> bool:
	var w: Node = DesktopWatch.instance()
	if w == null:
		return false
	if bool(w.get("running")):
		var path: String = String(w.call("stop"))
		var st: Dictionary = w.call("stats")
		Events.toast("Desktop watch stopped after %d looks%s" % [int(st["captures"]), "" if path.is_empty() else ", notes saved"])
		return false
	if not bool(w.call("start")):
		Events.toast("Desktop watch could not start: " + String(w.get("last_error")))
		return false
	var names: PackedStringArray = PackedStringArray()
	for k: String in (w.call("kinds_watched") as PackedStringArray):
		names.append(Kinds.name_of(k))
	Events.toast("Watching the desktop for scene switches%s" % ("" if names.is_empty() else " and " + ", ".join(names)))
	return true


func _update_watch_button(_running: bool = false) -> void:
	if _watch_button == null or not is_instance_valid(_watch_button):
		return
	var on: bool = DesktopWatch.running_now()
	_watch_button.text = WATCH_STOP_LABEL if on else WATCH_LABEL
	_watch_button.set_pressed_no_signal(on)


func _on_watch_pressed() -> void:
	if DesktopWatch.running_now():
		toggle_watch()
		return
	_update_watch_button()
	open_watch_menu()


func watch_menu_items() -> Array:
	DesktopWatch.register_prefs()
	var screen_now: int = int(DesktopWatch.pref(DesktopWatch.PREF_SCREEN, -1))
	var screens: Array = [PmMenu.check_item("dw_screen:-1", "The main screen", screen_now == -1)]
	for i: int in DisplayServer.get_screen_count():
		var sz: Vector2i = DisplayServer.screen_get_size(i)
		screens.append(PmMenu.check_item("dw_screen:" + str(i), "Screen %d (%d x %d)" % [i + 1, sz.x, sz.y], screen_now == i))
	var rate_now: float = float(DesktopWatch.pref(DesktopWatch.PREF_RATE, DesktopWatch.DEFAULT_RATE))
	var rates: Array = []
	for r: int in [1, 2, 4]:
		rates.append(PmMenu.check_item("dw_rate:" + str(r), "%d times a second" % r, absf(rate_now - float(r)) < 0.01))
	var n: int = DesktopNotes.paths().size()
	var source_now: String = String(DesktopWatch.pref(DesktopWatch.PREF_SOURCE, "screen"))
	var sources: Array = [
		PmMenu.check_item("dw_source:screen", "A screen of this computer", source_now != "obs"),
		PmMenu.check_item("dw_source:obs", "OBS, through its WebSocket server", source_now == "obs"),
	]
	return [
		PmMenu.item("dw_start", "Start watching now"),
		PmMenu.item("dw_apply", "Put the desktop notes on the videos shown"),
		PmMenu.separator(),
		PmMenu.sub_item("dw_sources", "Look through", sources),
		PmMenu.item("dw_obs", "OBS address and password..."),
		PmMenu.sub_item("dw_screens", "Screen to watch", screens),
		PmMenu.sub_item("dw_rates", "Look at it", rates),
		PmMenu.item("dw_part", "Only a part of the screen..."),
		PmMenu.separator(),
		PmMenu.item("dw_forget", "Forget the desktop notes (%d)" % n, "", "trash"),
	]


func open_watch_menu() -> Control:
	if _watch_button == null:
		return null
	var m: Control = PmMenu.open(_watch_button, watch_menu_items())
	if m != null and m.is_inside_tree():
		m.connect("picked", on_watch_picked)
	return m


func on_watch_picked(id: String) -> bool:
	var prefs: Node = DesktopWatch.prefs_node()
	if id == "dw_start":
		toggle_watch()
	elif id == "dw_apply":
		desktop_to_shown()
	elif id.begins_with("dw_source:") and prefs != null:
		prefs.call("set_value", DesktopWatch.PREF_SOURCE, id.substr(10))
	elif id == "dw_obs" and prefs != null:
		ask_obs(prefs)
	elif id.begins_with("dw_screen:") and prefs != null:
		prefs.call("set_value", DesktopWatch.PREF_SCREEN, id.substr(10).to_int())
	elif id.begins_with("dw_rate:") and prefs != null:
		prefs.call("set_value", DesktopWatch.PREF_RATE, float(id.substr(8).to_int()))
	elif id == "dw_part" and prefs != null:
		ask_watch_part(prefs)
	elif id == "dw_forget":
		Events.toast("Forgot %d desktop watch notes" % DesktopNotes.forget_all())
	else:
		return false
	return true


func ask_obs(prefs: Node) -> void:
	if not _alive():
		return
	var fields: Array[Dictionary] = []
	fields.append({"key": "address", "label": "Address", "default": String(DesktopWatch.pref(DesktopWatch.PREF_OBS_ADDRESS, "127.0.0.1:4455"))})
	fields.append({"key": "password", "label": "Password", "default": String(DesktopWatch.pref(DesktopWatch.PREF_OBS_PASSWORD, ""))})
	fields.append({"key": "note", "type": "note", "default": "In OBS: Tools, WebSocket Server Settings, tick Enable WebSocket server, then Show connect info for the port and password. The watch then sees exactly what OBS records, notes each scene change and when a recording starts and stops."})
	var answered: Signal = PmUI.form(_root, "Watch through OBS", fields, "Apply", "Cancel")
	answered.connect(func(res: Variant) -> void:
		if res is Dictionary:
			prefs.call("set_value", DesktopWatch.PREF_OBS_ADDRESS, String((res as Dictionary).get("address", "")).strip_edges())
			prefs.call("set_value", DesktopWatch.PREF_OBS_PASSWORD, String((res as Dictionary).get("password", "")))
			prefs.call("set_value", DesktopWatch.PREF_SOURCE, "obs")
	)


func ask_watch_part(prefs: Node) -> void:
	if not _alive():
		return
	var fields: Array[Dictionary] = []
	fields.append({"key": "part", "label": "Left, top, width, height in percent", "default": String(DesktopWatch.pref(DesktopWatch.PREF_PART, ""))})
	fields.append({"key": "note", "type": "note", "default": "Empty watches the whole screen. 0, 0, 50, 100 is the left half. A game window is watched by giving its place on the screen."})
	var answered: Signal = PmUI.form(_root, "Part of the screen to watch", fields, "Apply", "Cancel")
	answered.connect(func(res: Variant) -> void:
		if res is Dictionary:
			prefs.call("set_value", DesktopWatch.PREF_PART, String((res as Dictionary).get("part", "")).strip_edges())
	)


func _on_auto_found(result: Dictionary, js: Dictionary, d: Project) -> void:
	if d != Session.doc:
		return
	if Found.apply_result(d, js, result) > 0:
		auto_finds += 1


func check_placed() -> int:
	_check_queued = false
	var d: Project = _watched
	var s: Sequence = Session.seq()
	if d == null or s == null or _applying:
		return 0
	var fresh: PackedStringArray = PackedStringArray()
	for t: Track in s.all_tracks():
		for c: Clip in t.clips:
			if not _seen.has(c.id):
				fresh.append(c.id)
	if fresh.is_empty():
		return 0
	var fns: PackedStringArray = auto_fns()
	var n: int = 0
	if not fns.is_empty():
		_applying = true
		var res: Dictionary = RegionApply.apply(d, s, fns, fresh, "Organizer regions on the placed clips")
		_applying = false
		if bool(res.get("ok", false)):
			n = 1
			auto_runs += 1
	_mark_seen(d)
	return n


func _build(root_: Control) -> void:
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	var show_b: Button = PmButton.make("Show", "film")
	show_b.set("quiet", true)
	PmUI.tip(show_b, "Choose which videos the organizer shows")
	show_b.pressed.connect(_on_show_menu.bind(show_b))
	head.add_child(show_b)
	head.add_child(PmUI.divider(true))
	for t: Array in [[Canvas.TOOL_PAINT, "Colour", "region", "P"], [Canvas.TOOL_PICK, "Pick", "select", "V"], [Canvas.TOOL_ERASE, "Erase", "trash", "E"], [Canvas.TOOL_CUTS, "Cuts", "razor", "C"]]:
		var b: Button = PmButton.make(String(t[1]), String(t[2]), true)
		b.set("quiet", true)
		PmUI.tip(b, "%s tool" % String(t[1]), String(t[3]))
		b.pressed.connect(set_tool.bind(String(t[0])))
		head.add_child(b)
		_tool_buttons[String(t[0])] = b
	_lane_button = PmButton.make(String(Regions.LANE_LABELS[""]))
	_lane_button.set("quiet", true)
	PmUI.tip(_lane_button, "What new regions cover: the whole clip, only the picture or only the sound")
	_lane_button.pressed.connect(_on_lane_menu)
	head.add_child(_lane_button)
	head.add_child(PmUI.divider(true))
	var prev: Button = quiet_icon("prev_key", "Go to the region of this kind before", "[")
	prev.pressed.connect(jump.bind(-1))
	head.add_child(prev)
	var next: Button = quiet_icon("next_key", "Go to the next region of this kind", "]")
	next.pressed.connect(jump.bind(1))
	head.add_child(next)
	var fit_b: Button = quiet_icon("maximize", "Fit every video in view", "F")
	fit_b.pressed.connect(_on_fit)
	head.add_child(fit_b)
	for b2: Button in extra_buttons:
		head.add_child(b2)
	var folders_b: Button = PmButton.make("Smart folders", "folder")
	folders_b.set("quiet", true)
	PmUI.tip(folders_b, "Every video with regions of a kind, in order, ready to edit or export")
	folders_b.pressed.connect(open_folders)
	head.add_child(folders_b)
	var find_b: Button = PmButton.make("Find a picture", "search")
	find_b.set("quiet", true)
	PmUI.tip(find_b, "Mark everywhere a picture shows up, from a few sample frames")
	find_b.pressed.connect(open_find)
	head.add_child(find_b)
	_watch_button = PmButton.make(WATCH_LABEL, "eye", true)
	_watch_button.set("quiet", true)
	PmUI.tip(_watch_button, "While you record or play, look at the screen a few times a second and note scene switches and your sample pictures, so the regions land on the recording when it is imported")
	_watch_button.pressed.connect(_on_watch_pressed)
	head.add_child(_watch_button)
	var watcher: Node = DesktopWatch.instance()
	if watcher != null and not watcher.is_connected("changed", _update_watch_button):
		watcher.connect("changed", _update_watch_button)
	_update_watch_button()
	_apply_button = PmButton.make("Use in the timeline", "check")
	_apply_button.set("quiet", true)
	PmUI.tip(_apply_button, "Cut, mute, skip, censor or mark the timeline where the regions are")
	_apply_button.pressed.connect(_on_apply_menu)
	head.add_child(_apply_button)
	PmWrapRow.adopt(head, head.get_child_count() - 4, 0)
	_root.tree_exiting.connect(func() -> void: Store.flush())
	_kinds_row = PmUI.flow(Tk.px(4.0), Tk.px(4.0))
	col.add_child(PmUI.inset(_kinds_row, 4.0, 4.0))
	var sc: ScrollContainer = vscroll_area(col)
	canvas = Canvas.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(canvas)
	canvas.connect("picked_time", _on_picked_time)
	canvas.connect("region_menu", _on_region_menu)
	canvas.connect("overlaps_wanted", open_overlaps)
	canvas.connect("empty_menu", _on_empty_menu)
	canvas.connect("selection_changed", _update_foot)
	col.add_child(PmUI.divider())
	_foot = PmLabel.dim(HELP)
	_foot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_foot.clip_text = true
	col.add_child(PmUI.inset(_foot))
	set_tool(Canvas.TOOL_PAINT)
	refresh()


func shown_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var d: Project = doc()
	if d == null:
		return out
	if show_mode == SHOW_PICKED:
		for id: String in picked_ids:
			if d.media_by_id(id) != null:
				out.append(id)
		return out
	for m: MediaItem in d.media:
		if (m.kind == "video" or m.kind == "audio") and not m.path.is_empty():
			out.append(m.id)
	return out


func refresh() -> void:
	_queued = false
	if not _alive() or canvas == null:
		return
	canvas.call("set_media", doc(), shown_ids())
	_rebuild_kinds()
	_update_foot()


func queue_refresh() -> void:
	if _queued or not _alive():
		return
	_queued = true
	_root.get_tree().process_frame.connect(refresh, CONNECT_ONE_SHOT)


func _rebuild_kinds() -> void:
	if _kinds_row == null:
		return
	_kinds_serial = Kinds.serial
	KindsUi.fill(_kinds_row, self, current_kind(), _kind_counts())


func _kind_counts() -> Dictionary:
	var out: Dictionary = {}
	var d: Project = doc()
	if d == null:
		return out
	for id: String in shown_ids():
		for r: Variant in Regions.list(d.media_by_id(id)):
			var k: String = String((r as Dictionary).get("kind", ""))
			out[k] = int(out.get(k, 0)) + 1
	return out


func current_kind() -> String:
	return String(canvas.get("kind")) if canvas != null else "dead"


func set_kind(id: String) -> void:
	if canvas == null:
		return
	canvas.set("kind", id)
	if String(canvas.get("tool")) == Canvas.TOOL_ERASE:
		set_tool(Canvas.TOOL_PAINT)
	_rebuild_kinds()
	_update_foot()


func set_tool(t: String) -> void:
	if canvas == null:
		return
	canvas.set("tool", t)
	for k: Variant in _tool_buttons.keys():
		(_tool_buttons[k] as Button).set_pressed_no_signal(String(k) == t)
	_update_foot()


func set_lane(l: String) -> void:
	if canvas == null or not Regions.LANES.has(l):
		return
	canvas.set("lane", l)
	_lane_button.text = String(Regions.LANE_LABELS[l])


func _update_foot() -> void:
	if _foot == null or canvas == null:
		return
	var sel: Dictionary = canvas.call("selected_region")
	if sel.is_empty():
		_foot.text = "%s: %s.  %s" % [Kinds.name_of(current_kind()), Kinds.function_label(Kinds.fn_of(current_kind())), HELP]
		return
	var a: float = float(sel.get("from", 0.0))
	var b: float = float(sel.get("to", 0.0))
	_foot.text = "%s from %s to %s (%s)%s" % [Kinds.name_of(String(sel.get("kind", ""))), Canvas.clock(a), Canvas.clock(b), Canvas.clock(b - a), ", acts as a cut" if Regions.acts_as_cut(sel) else ", marks only"]


func _on_doc_changed(kind: String) -> void:
	if kind == "markers" or kind == "media" or kind == "structure":
		queue_refresh()


func _on_history() -> void:
	queue_refresh()


func _on_project_changed() -> void:
	picked_ids = PackedStringArray()
	if canvas != null:
		canvas.set("_fitted", false)
		canvas.call("select", "", "")
	queue_refresh()


func _on_fit() -> void:
	if canvas != null:
		canvas.call("fit")


func _on_show_menu(anchor: Button) -> void:
	var items: Array = [
		PmMenu.check_item("show:all", "Every video and sound in the project", show_mode == SHOW_ALL),
		PmMenu.check_item("show:picked", "Only the items picked in the bin", show_mode == SHOW_PICKED),
	]
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_show_picked)


func _on_show_picked(id: String) -> void:
	if id == "show:all":
		show_all()
	elif id == "show:picked":
		var bin: Object = bus().panel("bin")
		var ids: PackedStringArray = bin.get("selected_ids") if bin != null else PackedStringArray()
		show_media(ids)


func show_all() -> void:
	show_mode = SHOW_ALL
	if canvas != null:
		canvas.set("_fitted", false)
	refresh()


func show_media(ids: PackedStringArray) -> void:
	show_mode = SHOW_PICKED
	picked_ids = ids.duplicate()
	if canvas != null:
		canvas.set("_fitted", false)
	refresh()


func _on_lane_menu() -> void:
	var items: Array = []
	for l: String in Regions.LANES:
		items.append(PmMenu.check_item("lane:" + l, String(Regions.LANE_LABELS[l]), String(canvas.get("lane")) == l))
	var m: Control = PmMenu.open(_lane_button, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", func(id: String) -> void: set_lane(id.substr(5)))


func _on_picked_time(media_id: String, t: float) -> void:
	show_in_source(media_id, t)


func show_in_source(media_id: String, t: float) -> void:
	var d: Project = doc()
	if d == null or d.media_by_id(media_id) == null or not _alive():
		return
	var bin: Object = bus().panel("bin")
	if bin != null and bin.has_method("open_in_source_at"):
		bin.call("open_in_source_at", media_id, t)


func jump(dir: int) -> bool:
	var d: Project = doc()
	if d == null or canvas == null:
		return false
	var ids: PackedStringArray = shown_ids()
	if ids.is_empty():
		return false
	var at_media: String = String(canvas.get("cursor_media"))
	var start: int = maxi(ids.find(at_media), 0)
	var t: float = float(canvas.get("cursor_t")) if ids.find(at_media) >= 0 else (-1.0 if dir > 0 else INF)
	for step: int in ids.size():
		var i: int = (start + step * dir + ids.size() * 4) % ids.size()
		if step > 0:
			t = -1.0 if dir > 0 else INF
		var hit: Dictionary = Regions.next_of_kind(Regions.list(d.media_by_id(ids[i])), current_kind(), t, dir)
		if not hit.is_empty():
			canvas.call("set_cursor", ids[i], float(hit["from"]))
			canvas.call("select", ids[i], String(hit["id"]))
			return true
	if _foot != null:
		_foot.text = "No more %s regions." % Kinds.name_of(current_kind())
	return false


func _on_empty_menu(media_id: String, t: float, at: Vector2) -> void:
	var items: Array = [
		PmMenu.item("org_source", "Show this moment in Source"),
		PmMenu.item("org_new_kind", "New kind of region..."),
		PmMenu.item("org_fit", "Fit every video in view"),
	]
	var m: Control = PmMenu.open(canvas, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_empty_picked.bind(media_id, t))


func _on_empty_picked(id: String, media_id: String, t: float) -> void:
	if id == "org_source":
		canvas.call("set_cursor", media_id, t)
	elif id == "org_new_kind":
		KindsUi.ask_new(_root, self)
	elif id == "org_fit":
		_on_fit()


func region_menu_items(media_id: String, region_id: String, with_swap: bool) -> Array:
	var d: Project = doc()
	var m: MediaItem = d.media_by_id(media_id) if d != null else null
	var r: Dictionary = Regions.by_id(Regions.list(m), region_id) if m != null else {}
	if r.is_empty():
		return []
	var kinds_sub: Array = []
	for k: Dictionary in Kinds.kinds():
		kinds_sub.append(PmMenu.check_item("rg_kind:" + String(k["id"]), String(k["name"]), String(k["id"]) == String(r.get("kind", ""))))
	var lane_sub: Array = []
	for l: String in Regions.LANES:
		lane_sub.append(PmMenu.check_item("rg_lane:" + l, String(Regions.LANE_LABELS[l]), String(r.get("lane", "")) == l))
	var items: Array = [
		PmMenu.item("rg_source", "Show in Source"),
		PmMenu.sub_item("rg_kinds", "Kind", kinds_sub),
		PmMenu.check_item("rg_cut", "Acts as a cut in the editor", Regions.acts_as_cut(r)),
		PmMenu.check_item("rg_come_back", "Come back to this later", bool(r.get("come_back", false))),
		PmMenu.sub_item("rg_lanes", "Covers", lane_sub),
		PmMenu.item("rg_area", "Part of the picture..."),
		PmMenu.item("rg_note", "Note..."),
	]
	if with_swap:
		var others: Array = []
		for o: Variant in Regions.overlapping(Regions.list(m), r):
			var od: Dictionary = o
			others.append(PmMenu.item("rg_swap:" + String(od["id"]), "%s (%s to %s)" % [Kinds.name_of(String(od.get("kind", ""))), Canvas.clock(float(od.get("from", 0.0))), Canvas.clock(float(od.get("to", 0.0)))]))
		if not others.is_empty():
			items.append(PmMenu.sub_item("rg_swaps", "Swap kinds with", others))
	var targets: Array = []
	for other: MediaItem in d.media:
		if other.id != media_id and not other.path.is_empty() and (other.kind == "video" or other.kind == "audio") and Store.key_of(other.path) != Store.key_of(m.path):
			targets.append(PmMenu.item("rg_move:" + other.id, other.label))
	if not targets.is_empty():
		items.append(PmMenu.sub_item("rg_moves", "Move to another video", targets))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("rg_delete", "Delete", "Delete", "trash"))
	return items


func _on_region_menu(media_id: String, region_id: String, _t: float, at: Vector2) -> void:
	var items: Array = region_menu_items(media_id, region_id, false)
	if items.is_empty():
		return
	var m: Control = PmMenu.open(canvas, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", on_region_picked.bind(media_id, region_id))


func on_region_picked(id: String, media_id: String, region_id: String) -> bool:
	var d: Project = doc()
	var m: MediaItem = d.media_by_id(media_id) if d != null else null
	var r: Dictionary = Regions.by_id(Regions.list(m), region_id) if m != null else {}
	if r.is_empty():
		return false
	if id == "rg_source":
		canvas.call("set_cursor", media_id, float(r.get("from", 0.0)))
	elif id.begins_with("rg_kind:"):
		Regions.change(d, media_id, region_id, {"kind": id.substr(8)}, "Change region kind")
	elif id == "rg_cut":
		Regions.change(d, media_id, region_id, {"cut": not Regions.acts_as_cut(r)}, "Region acts as a cut" if not Regions.acts_as_cut(r) else "Region marks only")
	elif id == "rg_come_back":
		Regions.change(d, media_id, region_id, {"come_back": true if not bool(r.get("come_back", false)) else null}, "Come back to this")
	elif id.begins_with("rg_lane:"):
		Regions.change(d, media_id, region_id, {"lane": id.substr(8)}, "Region covers")
	elif id.begins_with("rg_swap:"):
		Regions.swap_kinds(d, media_id, region_id, id.substr(8))
	elif id.begins_with("rg_move:"):
		var target: MediaItem = d.media_by_id(id.substr(8))
		if target != null:
			Regions.move_to(d, media_id, target.path, PackedStringArray([region_id]))
	elif id == "rg_area":
		KindsUi.ask_area(_root, d, media_id, r)
	elif id == "rg_note":
		KindsUi.ask_note(_root, d, media_id, r)
	elif id == "rg_delete":
		Regions.remove(d, media_id, PackedStringArray([region_id]))
		canvas.call("select", "", "")
	else:
		return false
	return true


func open_overlaps(media_id: String, t: float, at: Vector2) -> Control:
	var d: Project = doc()
	var m: MediaItem = d.media_by_id(media_id) if d != null else null
	if m == null or not _alive():
		return null
	var under: Array = Regions.covering(Regions.list(m), t)
	if under.is_empty():
		return null
	if _overlaps != null and is_instance_valid(_overlaps):
		_overlaps.call("close")
	var host: Node = PmUI.overlay_for(_root)
	_overlaps = Overlaps.new()
	host.add_child(_overlaps)
	_overlaps.call("open", media_id, t, under, at)
	_overlaps.connect("picked", func(rid: String) -> void:
		canvas.call("select", media_id, rid)
		canvas.call("set_cursor", media_id, t, false)
	)
	_overlaps.connect("node_menu", _on_node_menu.bind(media_id))
	return _overlaps


func _on_node_menu(region_id: String, at: Vector2, media_id: String) -> void:
	var items: Array = region_menu_items(media_id, region_id, true)
	if items.is_empty() or _overlaps == null or not is_instance_valid(_overlaps):
		return
	var m: Control = PmMenu.open(_overlaps, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", func(id: String) -> void:
			on_region_picked(id, media_id, region_id)
			if _overlaps != null and is_instance_valid(_overlaps):
				_overlaps.call("close")
		)


func open_folders() -> Node:
	if not _alive():
		return null
	return FoldersSheet.open(_root, self, doc(), current_kind())


func open_find() -> Node:
	if not _alive():
		return null
	return FindSheet.open(_root, self, doc(), current_kind())


func _on_apply_menu() -> void:
	var items: Array = [PmMenu.item("apply:all", "Use every region on the whole timeline"), PmMenu.item("apply:picked", "Use every region on the picked clips"), PmMenu.separator()]
	for fn: String in RegionApply.EDITOR_FNS:
		items.append(PmMenu.item("apply:" + fn, "Only: " + Kinds.function_label(fn)))
	var m: Control = PmMenu.open(_apply_button, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", func(id: String) -> void: apply_regions(id.substr(6)))


func apply_regions(what: String) -> Dictionary:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return {}
	var fns: PackedStringArray = RegionApply.EDITOR_FNS
	var ids: PackedStringArray = PackedStringArray()
	if what == "picked":
		ids = Verbs.selection(s)
		if ids.is_empty():
			Events.toast("Pick clips in the timeline first")
			return {}
	elif what != "all":
		fns = PackedStringArray([what])
	_applying = true
	var res: Dictionary = RegionApply.apply(d, s, fns, ids)
	_applying = false
	_mark_seen(d)
	if not bool(res.get("ok", false)):
		Events.toast("No regions are on the clips in this timeline")
		return res
	var parts: PackedStringArray = PackedStringArray()
	for k: String in RegionApply.DONE_KEYS:
		if int(res.get(k, 0)) > 0:
			parts.append("%s %d" % [Kinds.function_label(k), int(res[k])])
	Events.toast(", ".join(parts) if not parts.is_empty() else "The regions are already in use")
	return res


func reveal(media_id: String, region_id: String) -> void:
	var d: Project = doc()
	if d == null or d.media_by_id(media_id) == null:
		return
	if not shown_ids().has(media_id):
		show_all()
	if canvas == null:
		return
	var r: Dictionary = Regions.by_id(Regions.list(d.media_by_id(media_id)), region_id)
	canvas.call("select", media_id, region_id)
	if not r.is_empty():
		canvas.call("set_cursor", media_id, float(r.get("from", 0.0)))


func handle_key(e: InputEventKey) -> bool:
	if not e.pressed or canvas == null:
		return false
	if key_is(e, KEY_P):
		set_tool(Canvas.TOOL_PAINT)
	elif key_is(e, KEY_V):
		set_tool(Canvas.TOOL_PICK)
	elif key_is(e, KEY_E):
		set_tool(Canvas.TOOL_ERASE)
	elif key_is(e, KEY_C):
		set_tool(Canvas.TOOL_CUTS)
	elif key_is(e, KEY_BRACKETRIGHT):
		jump(1)
	elif key_is(e, KEY_BRACKETLEFT):
		jump(-1)
	elif key_is(e, KEY_F):
		_on_fit()
	elif key_is(e, KEY_DELETE) or key_is(e, KEY_BACKSPACE):
		var sel: Dictionary = canvas.get("selected")
		if sel.is_empty():
			return false
		Regions.remove(doc(), String(sel["media_id"]), PackedStringArray([String(sel["region_id"])]))
		canvas.call("select", "", "")
	else:
		return false
	return true


func save_state() -> Dictionary:
	if canvas == null:
		return {}
	return {"kind": current_kind(), "tool": String(canvas.get("tool")), "lane": String(canvas.get("lane")), "show": show_mode, "picked": Array(picked_ids)}


func restore_state(d: Dictionary) -> void:
	if canvas == null:
		return
	if not Kinds.by_id(String(d.get("kind", ""))).is_empty():
		canvas.set("kind", String(d["kind"]))
	set_tool(String(d.get("tool", Canvas.TOOL_PAINT)))
	set_lane(String(d.get("lane", "")))
	show_mode = String(d.get("show", SHOW_ALL))
	picked_ids = PackedStringArray()
	for v: Variant in d.get("picked", []):
		picked_ids.append(String(v))
	refresh()

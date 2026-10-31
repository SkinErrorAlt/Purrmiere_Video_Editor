extends RefCounted

const Bus := preload("res://modules/core_panels/panel_bus.gd")
const PairSyncState := preload("res://engine/pair_sync_state.gd")
const SyncView := preload("res://ui/timeline/pair_sync_view.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PAIR_VIEW_ID := "pair_view"
const COMMAND_ID := "clip.sync_regions"
const MENU_ID := "pair_sync"
const PREF_UNIT := "controls.pair_offset_unit"
const SELF_PATH := "res://modules/core_panels/pair_sync.gd"

static var _view: Control = null
static var _canvas: Control = null


static func state() -> RefCounted:
	return PairSyncState.instance()


static func active() -> bool:
	return bool(state().call("active"))


static func active_for(clip_id: String, uid: String) -> bool:
	return bool(state().call("is_for", clip_id, uid))


static func view() -> Control:
	if _view != null and is_instance_valid(_view):
		return _view
	return null


static func pair_uid(c: Clip) -> String:
	if c == null:
		return ""
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) == PAIR_VIEW_ID:
			return String(e.get("uid", ""))
	return ""


static func register_prefs() -> void:
	if not Prefs.is_registered(PREF_UNIT):
		Prefs.register(PREF_UNIT, "ms", {"label": "Pair View offsets show in", "type": "enum", "choices": ["ms", "s"]})


static func unit() -> String:
	register_prefs()
	return "s" if String(Prefs.get_value(PREF_UNIT)) == "s" else "ms"


static func set_unit(u: String) -> void:
	register_prefs()
	Prefs.set_value(PREF_UNIT, "s" if u == "s" else "ms")


static func format_offset(v: float, u: String = "") -> String:
	var which: String = u if not u.is_empty() else unit()
	if which == "s":
		return ("+" if v > 0.0 else "") + String.num(v, 3) + " s"
	var ms: float = v * 1000.0
	var shown: String = String.num(ms, 0) if absf(ms - round(ms)) < 0.05 else String.num(ms, 1)
	return ("+" if ms > 0.0005 else "") + shown + " ms"


static func toggle(clip_id: String, uid: String) -> bool:
	if active_for(clip_id, uid):
		leave()
		return false
	return enter(clip_id, uid)


static func toggle_selected() -> void:
	if active():
		leave()
		return
	var s: Sequence = Session.seq()
	var c: Clip = Bus.selected_clip(s) if s != null else null
	var uid: String = pair_uid(c)
	if uid.is_empty():
		Events.toast("Select a clip with a Pair View to sync its regions")
		return
	enter(c.id, uid)


static func timeline_canvas() -> Control:
	var tl: Object = Bus.instance().panel("timeline")
	if tl == null:
		return null
	var cv: Variant = tl.get("canvas")
	if cv is Control and is_instance_valid(cv):
		return cv
	return null


static func enter(clip_id: String, uid: String) -> bool:
	var s: Sequence = Session.seq()
	if s == null:
		return false
	var c: Clip = s.clip_by_id(clip_id)
	if c == null or c.effect_by_uid(uid).is_empty():
		return false
	var cv: Control = timeline_canvas()
	if cv == null or cv.get_parent() == null:
		Events.toast("Open the Timeline to sync regions")
		return false
	if active():
		leave()
	state().call("begin", s.id, clip_id, uid)
	_watch_state()
	var v: Control = SyncView.new()
	v.name = "PairSyncView"
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size = cv.custom_minimum_size
	var holder: Node = cv.get_parent()
	holder.add_child(v)
	holder.move_child(v, cv.get_index() + 1)
	cv.visible = false
	_view = v
	_canvas = cv
	v.call("setup", s.id, clip_id, uid)
	if Cmd.has("window.focus_timeline"):
		Cmd.run("window.focus_timeline")
	refresh_engine()
	return true


static func leave() -> void:
	var v: Control = view()
	if v != null:
		v.call("cancel_drag")
		PmUI.free_node(v)
	_view = null
	if _canvas != null and is_instance_valid(_canvas):
		_canvas.visible = true
	_canvas = null
	state().call("end")
	refresh_engine()


static func _watch_state() -> void:
	var st: RefCounted = state()
	var cb: Callable = Callable(load(SELF_PATH), "refresh_engine")
	if not st.is_connected("changed", cb):
		st.connect("changed", cb)


static func refresh_engine() -> void:
	if Session.has_method("push_playback_graph"):
		Session.push_playback_graph()
	var comp: Node = Session.compositor
	if comp != null and is_instance_valid(comp) and comp.has_method("render_time"):
		comp.call("render_time", Session.playhead(), false)


static func handle_key(e: InputEventKey) -> bool:
	var v: Control = view()
	if v == null or not active():
		return false
	return bool(v.call("handle_key", e))


static func blocks_drops() -> bool:
	return active() and view() != null


static func clip_menu_items(c: Clip) -> Array:
	var uid: String = pair_uid(c)
	if uid.is_empty():
		return []
	var label: String = "Stop syncing regions" if active_for(c.id, uid) else "Sync regions"
	var items: Array = [PmMenu.item(MENU_ID, label, Cmd.keys_text(COMMAND_ID))]
	items.append_array(ViewCutsMenu.clip_menu_items(c))
	items.append_array(OffsetEditor.clip_menu_items(c))
	items.append_array(PairOffsets.clip_menu_items(c))
	items.append(PmMenu.separator())
	return items


const ViewCutsMenu := preload("res://modules/core_panels/pair_view_cuts.gd")
const OffsetEditor := preload("res://modules/core_panels/offset_editor.gd")
const PairOffsets := preload("res://modules/core_panels/pair_offsets.gd")


static func on_clip_menu(id: String, clip_id: String) -> bool:
	if ViewCutsMenu.on_clip_menu(id, clip_id) or OffsetEditor.on_clip_menu(id, clip_id) or PairOffsets.on_clip_menu(id, clip_id):
		return true
	if id != MENU_ID:
		return false
	var s: Sequence = Session.seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	var uid: String = pair_uid(c)
	if not uid.is_empty():
		toggle(clip_id, uid)
	return true


const AudioGraph := preload("res://engine/audio_graph.gd")
const Project := preload("res://doc/project.gd")
const ViewMap := preload("res://doc/view_map.gd")
const LIVE := "live"

static var sound_pushes: int = 0
static var last_graph: Dictionary = {}
static var _sound_queued: bool = false
static var _watched: WeakRef = null


static func watch_session() -> void:
	var cb: Callable = Callable(load(SELF_PATH), "_on_session_project")
	if not Session.project_changed.is_connected(cb):
		Session.project_changed.connect(cb)
	_on_session_project()
	load("res://engine/view_sound.gd").call("watch_session")


static func _on_session_project() -> void:
	var cb: Callable = Callable(load(SELF_PATH), "_on_doc_live")
	var was: Object = _watched.get_ref() if _watched != null else null
	var d: Project = Session.doc
	if was != null and was != d and (was as Project).changed.is_connected(cb):
		(was as Project).changed.disconnect(cb)
	if d != null and not d.changed.is_connected(cb):
		d.changed.connect(cb)
	_watched = weakref(d) if d != null else null


static func _on_doc_live(kind: String) -> void:
	if kind != LIVE or _sound_queued:
		return
	var d: Project = Session.doc
	if d == null or not live_moves_sound(d):
		return
	_sound_queued = true
	Callable(load(SELF_PATH), "push_sound").call_deferred()


static func live_moves_sound(d: Project) -> bool:
	var s: Sequence = Session.seq()
	if s == null:
		return false
	for cmd: RefCounted in d.undo.live_commands():
		var parts: PackedStringArray = String(cmd.call("live_key")).split("|")
		var cid: String = ""
		var uid: String = ""
		var key: String = ""
		if parts.size() == 3 and parts[0] == "clip_param":
			var p: PackedStringArray = parts[2].split(".")
			if p.size() == 3 and p[0] == "effects":
				cid = parts[1]
				uid = p[1]
				key = p[2]
		elif parts.size() == 4 and parts[0] == "effect_param":
			cid = parts[1]
			uid = parts[2]
			key = parts[3]
		if not key.begins_with("offset"):
			continue
		var c: Clip = s.clip_by_id(cid)
		if c == null:
			continue
		var e: Dictionary = c.effect_by_uid(uid)
		if String(e.get("id", "")) == PAIR_VIEW_ID and not ViewMap.of(e).is_empty():
			return true
	return false


static func push_sound() -> void:
	_sound_queued = false
	var d: Project = Session.doc
	if d == null:
		return
	sound_pushes += 1
	last_graph = AudioGraph.build(d, Session.seq(), Session.media_handles)
	if PurrBridge.available and String(Session.audio_owner).is_empty():
		PurrBridge.set_audio_graph(last_graph)


static func pushes() -> int:
	return sound_pushes


static func pushed_graph() -> Dictionary:
	return last_graph

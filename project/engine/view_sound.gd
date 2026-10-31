extends RefCounted

const AudioGraph := preload("res://engine/audio_graph.gd")
const ViewMap := preload("res://doc/view_map.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const PairSyncState := preload("res://engine/pair_sync_state.gd")
const SELF_PATH := "res://engine/view_sound.gd"
const FrameJobs := preload("res://host/frame_jobs.gd")
const PAIR_VIEW_ID := "pair_view"
const LIVE := "live"
const LIVE_SOUND := "live_audio"
const CLIP_KEY := "clip_param"
const EFFECT_KEY := "effect_param"
const OFFSET_PREFIX := "offset"
const MAP_KEY := "view_audio"
const SOUND_VIEW_KEY := "sound_view"
const STRUCTURE := "structure"
const MEDIA := "media"
const EDIT_NONE := 0
const EDIT_GAINS := 1
const EDIT_GRAPH := 2

static var patches: int = 0
static var full_pushes: int = 0
static var last_patch: Dictionary = {}
static var last_mode: String = ""
static var last_ids: PackedStringArray = PackedStringArray()
static var push_us: int = 0
static var _queued: bool = false
static var _ids: PackedStringArray = PackedStringArray()
static var _graph: bool = false
static var _watched: WeakRef = null
static var _sigs: Dictionary = {}
static var _structural: bool = false
static var quick_patches: int = 0


static func _root() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	return (loop as SceneTree).root if loop is SceneTree else null


static func _node(name: String) -> Node:
	var r: Node = _root()
	return r.get_node_or_null(name) if r != null else null


static func watch_session() -> void:
	var s: Node = _node("Session")
	if s == null:
		return
	var cb: Callable = Callable(load(SELF_PATH), "_on_project")
	if not s.is_connected("project_changed", cb):
		s.connect("project_changed", cb)
	_on_project()


static func _on_project() -> void:
	var s: Node = _node("Session")
	var d: Project = s.get("doc") if s != null else null
	var cb: Callable = Callable(load(SELF_PATH), "on_doc_changed")
	var hb: Callable = Callable(load(SELF_PATH), "on_history")
	var was: Object = _watched.get_ref() if _watched != null else null
	if was != null and was != d:
		if (was as Project).changed.is_connected(cb):
			(was as Project).changed.disconnect(cb)
		if (was as Project).history_changed.is_connected(hb):
			(was as Project).history_changed.disconnect(hb)
	if d != null and not d.changed.is_connected(cb):
		d.changed.connect(cb)
	if d != null and not d.history_changed.is_connected(hb):
		d.history_changed.connect(hb)
	_watched = weakref(d) if d != null else null
	_sigs = {}
	_structural = false
	if d != null and s.call("seq") != null:
		view_changes(s.call("seq"))


static func signatures(seq: Sequence) -> Dictionary:
	var out: Dictionary = {}
	if seq == null:
		return out
	for src: Dictionary in AudioGraph.pair_view_sources(seq):
		var c: Clip = src["clip"]
		var e: Dictionary = src["entry"]
		var params: Dictionary = e.get("params", {})
		var key: String = c.id + "|" + String(e.get("uid", ""))
		out[key] = [hash([params.get("view"), params.get("view_mode"), params.get("crops"), e.get("speeds"), c.start, c.duration, c.anim_speed, c.anim_start, params.get("view2"), params.get("group"), params.get("groups"), params.get(SOUND_VIEW_KEY)]), hash(params.get(MAP_KEY))]
	return out


static func view_changes(seq: Sequence) -> Dictionary:
	var now: Dictionary = signatures(seq)
	var ids: PackedStringArray = PackedStringArray()
	var map_changed: bool = false
	for key: Variant in now.keys():
		var was: Variant = _sigs.get(key, null)
		if was == null:
			continue
		if (was as Array)[1] != (now[key] as Array)[1]:
			map_changed = true
		if (was as Array)[0] != (now[key] as Array)[0]:
			var cid: String = String(key).get_slice("|", 0)
			if not ids.has(cid):
				ids.append(cid)
	_sigs = now
	return {"ids": ids, "map": map_changed}


static func on_history() -> void:
	var structural: bool = _structural
	_structural = false
	if structural:
		FrameJobs.add("view_sound_signatures", Callable(load(SELF_PATH), "refresh_signatures"))
		return
	var s: Node = _node("Session")
	var d: Project = s.get("doc") if s != null else null
	var seq: Sequence = s.call("seq") if s != null else null
	if d == null or seq == null:
		return
	var found: Dictionary = view_changes(seq)
	var ids: PackedStringArray = found["ids"]
	if structural or bool(found["map"]) or ids.is_empty():
		return
	if quick_patch(d, seq, ids):
		quick_patches += 1


static func refresh_signatures() -> void:
	var s: Node = _node("Session")
	var seq: Sequence = s.call("seq") if s != null else null
	if seq != null:
		view_changes(seq)


static func quick_patch(d: Project, seq: Sequence, ids: PackedStringArray) -> bool:
	var s: Node = _node("Session")
	var bridge: Node = _node("PurrBridge")
	if s == null or bridge == null or not bool(bridge.get("available")) or not String(s.get("audio_owner")).is_empty():
		return false
	if not bridge.has_method("has_view_gains") or not bool(bridge.call("has_view_gains")) or needs_graph(seq, ids):
		return false
	var patch: Dictionary = AudioGraph.view_gain_patch(d, seq, ids)
	return not patch.is_empty() and int(bridge.call("set_view_gains", patch)) >= patch.size()


static func on_doc_changed(kind: String) -> void:
	if kind == STRUCTURE or kind == MEDIA:
		_structural = true
	if kind != LIVE and kind != LIVE_SOUND:
		return
	var s: Node = _node("Session")
	var d: Project = s.get("doc") if s != null else null
	var seq: Sequence = s.call("seq") if s != null else null
	if d == null or seq == null:
		return
	var found: Dictionary = live_view_clips(d, seq)
	var ids: PackedStringArray = found["ids"]
	if ids.is_empty():
		return
	for id: String in ids:
		if not _ids.has(id):
			_ids.append(id)
	if bool(found["graph"]):
		_graph = true
	if _queued:
		return
	_queued = true
	Callable(load(SELF_PATH), "flush").call_deferred()


static func flush() -> void:
	_queued = false
	var ids: PackedStringArray = _ids
	var graph: bool = _graph
	_ids = PackedStringArray()
	_graph = false
	var s: Node = _node("Session")
	if s == null or ids.is_empty():
		return
	push(s.get("doc"), s.call("seq"), ids, graph)


static func pair_entries(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null or c.effects.is_empty():
		return out
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) == PAIR_VIEW_ID and not ViewMap.of(e).is_empty():
			out.append(e)
	return out


static func view_edit(c: Clip, path: String) -> int:
	if path == AnimTime.SPEED_PATH or path == AnimTime.START_FIELD:
		return EDIT_GRAPH
	for e: Dictionary in pair_entries(c):
		var head: String = "effects." + String(e.get("uid", "")) + "."
		if not path.begins_with(head):
			continue
		var key: String = path.substr(head.length())
		if key.begins_with(OFFSET_PREFIX):
			return EDIT_GRAPH if key.contains(".") else EDIT_NONE
		if key.begins_with(MAP_KEY):
			return EDIT_GRAPH
		return EDIT_GAINS
	return EDIT_NONE


static func edits_of(cmd: RefCounted) -> Array:
	var out: Array = []
	var entries: Variant = cmd.get("entries")
	if entries is Array:
		for e: Variant in (entries as Array):
			if e is Dictionary:
				out.append([String((e as Dictionary).get("clip_id", "")), String((e as Dictionary).get("path", ""))])
		if not out.is_empty():
			return out
	var parts: PackedStringArray = String(cmd.call("live_key")).split("|")
	if parts.size() == 3 and parts[0] == CLIP_KEY:
		out.append([parts[1], parts[2]])
	elif parts.size() == 4 and parts[0] == EFFECT_KEY:
		out.append([parts[1], "effects." + parts[2] + "." + parts[3]])
	return out


static func live_view_clips(d: Project, seq: Sequence) -> Dictionary:
	var ids: PackedStringArray = PackedStringArray()
	var graph: bool = false
	if d == null or seq == null or d.undo == null:
		return {"ids": ids, "graph": graph}
	for cmd: RefCounted in d.undo.live_commands():
		for edit: Variant in edits_of(cmd):
			var cid: String = (edit as Array)[0]
			var c: Clip = seq.clip_by_id(cid)
			if c == null or pair_entries(c).is_empty():
				continue
			var kind: int = view_edit(c, (edit as Array)[1])
			if kind == EDIT_NONE:
				continue
			if not ids.has(cid):
				ids.append(cid)
			if kind == EDIT_GRAPH:
				graph = true
	return {"ids": ids, "graph": graph}


static func needs_graph(seq: Sequence, ids: PackedStringArray) -> bool:
	if bool(PairSyncState.instance().call("active")):
		return true
	for id: String in ids:
		var video: Clip = seq.clip_by_id(id)
		for e: Dictionary in pair_entries(video):
			for sh: Dictionary in ViewMap.shared_sounds(ViewMap.of(e), seq, video):
				if not ViewMap.same_offsets(e, sh["views"]):
					return true
	return false


static func push(d: Project, seq: Sequence, ids: PackedStringArray, graph: bool = false) -> String:
	var t0: int = Time.get_ticks_usec()
	last_ids = ids
	last_mode = _push(d, seq, ids, graph)
	push_us = Time.get_ticks_usec() - t0
	return last_mode


static func _push(d: Project, seq: Sequence, ids: PackedStringArray, graph: bool) -> String:
	var s: Node = _node("Session")
	var bridge: Node = _node("PurrBridge")
	if d == null or seq == null or s == null or bridge == null or not bool(bridge.get("available")):
		return "none"
	if not String(s.get("audio_owner")).is_empty():
		return "none"
	if not graph and not needs_graph(seq, ids) and bridge.has_method("has_view_gains") and bool(bridge.call("has_view_gains")):
		var patch: Dictionary = AudioGraph.view_gain_patch(d, seq, ids)
		if patch.is_empty():
			return "none"
		var n: int = int(bridge.call("set_view_gains", patch))
		if n >= patch.size():
			patches += 1
			last_patch = patch
			return "patch"
	full_pushes += 1
	bridge.call("set_audio_graph", AudioGraph.build(d, seq, s.get("media_handles")))
	return "graph"

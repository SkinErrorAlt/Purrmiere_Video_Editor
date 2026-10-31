extends RefCounted

signal changed

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const ViewMap := preload("res://doc/view_map.gd")
const ViewStreams := preload("res://doc/view_streams.gd")
const StreamLanes := preload("res://engine/stream_lanes.gd")
const AudioGraph := preload("res://engine/audio_graph.gd")
const SELF_PATH := "res://modules/core_panels/stream_listen.gd"
const OWNER := "pair_listen"
const KIND_STREAM := "stream"
const KIND_VIEWS := "views"

static var _inst: RefCounted = null

var kind: String = ""
var media_id: String = ""
var stream: int = -1
var clip_id: String = ""
var views: PackedInt32Array = PackedInt32Array()
var token: int = 0
var last_graph: Dictionary = {}
var _hooked: bool = false


static func instance() -> RefCounted:
	if _inst == null:
		var script: GDScript = load(SELF_PATH)
		_inst = script.new()
	return _inst


static func _session() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("Session") if loop is SceneTree else null


static func _bridge() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("PurrBridge") if loop is SceneTree else null


static func handle_of(item: MediaItem) -> int:
	var s: Node = _session()
	if item == null:
		return -1
	if s != null:
		var hs: Variant = s.get("media_handles")
		if hs is Dictionary and (hs as Dictionary).has(item.id):
			var h: Variant = (hs as Dictionary)[item.id]
			if typeof(h) == TYPE_INT and int(h) >= 0:
				return int(h)
	return item.handle


func active() -> bool:
	return not kind.is_empty()


func on_stream(p_media_id: String, p_stream: int) -> bool:
	return kind == KIND_STREAM and media_id == p_media_id and stream == p_stream


func on_views(p_clip_id: String, p_views: PackedInt32Array) -> bool:
	return kind == KIND_VIEWS and clip_id == p_clip_id and views == p_views


func _hook() -> void:
	var s: Node = _session()
	if _hooked or s == null or not s.has_signal("audio_owner_changed"):
		return
	_hooked = true
	s.connect("audio_owner_changed", _on_owner)


func _on_owner(owner: String) -> void:
	if owner != OWNER and active():
		_clear()


func _clear() -> void:
	kind = ""
	media_id = ""
	stream = -1
	clip_id = ""
	views = PackedInt32Array()
	changed.emit()


func _claim(graph: Dictionary, at: float) -> bool:
	var s: Node = _session()
	var b: Node = _bridge()
	last_graph = graph
	if s == null or b == null or not bool(b.get("available")):
		return false
	_hook()
	if not bool(s.call("claim_audio", OWNER, graph)):
		return false
	b.call("set_rate", 1.0)
	b.call("set_time", maxf(at, 0.0), 0)
	b.call("set_playing", true)
	return true


func play_stream(item: MediaItem, p_stream: int, at: float, rate: int = 48000) -> bool:
	stop()
	if item == null:
		return false
	var graph: Dictionary = AudioGraph.source_graph(item, handle_of(item), p_stream, rate)
	if not _claim(graph, at):
		return false
	kind = KIND_STREAM
	media_id = item.id
	stream = p_stream
	changed.emit()
	return true


func play_views(d: Project, s: Sequence, video: Clip, uid: String, p_views: PackedInt32Array, from_t: float, seconds: float) -> bool:
	stop()
	var sess: Node = _session()
	var handles: Dictionary = sess.get("media_handles") if sess != null and sess.get("media_handles") is Dictionary else {}
	var graph: Dictionary = views_graph(d, s, video, uid, p_views, handles)
	if not _claim(graph, from_t):
		return false
	kind = KIND_VIEWS
	clip_id = video.id
	views = p_views
	token += 1
	var mine: int = token
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		(loop as SceneTree).create_timer(maxf(seconds, 0.1)).timeout.connect(_on_timer.bind(mine))
	changed.emit()
	return true


func _on_timer(mine: int) -> void:
	if mine == token and kind == KIND_VIEWS:
		stop()


func stop() -> void:
	var s: Node = _session()
	if s != null and String(s.get("audio_owner")) == OWNER:
		s.call("release_audio", OWNER)
	if active():
		_clear()


static func base_id(entry_id: String) -> String:
	return entry_id.get_slice(StreamLanes.COPY_TAG, 0)


static func views_graph(d: Project, s: Sequence, video: Clip, uid: String, p_views: PackedInt32Array, handles: Dictionary) -> Dictionary:
	var g: Dictionary = AudioGraph.build(d, s, handles)
	if video == null:
		return g
	var e: Dictionary = video.effect_by_uid(uid)
	var map: Dictionary = ViewMap.of(e)
	var prefix: String = video.id + "_view_"
	for t: Variant in g.get("tracks", []):
		var td: Dictionary = t
		var owner_id: String = String(td.get("owner", td.get("id", "")))
		for ce: Variant in td.get("clips", []):
			var cd: Dictionary = ce
			var id: String = String(cd.get("id", ""))
			var c: Clip = s.clip_by_id(base_id(id))
			var copy_stream: int = int(cd.get("stream", -1)) if id.contains(StreamLanes.COPY_TAG) else -1
			if c == null or c == video:
				cd["muted"] = true
				continue
			var hit: bool = false
			if map.is_empty():
				hit = ViewMap.in_family(video, c) and c.end() > video.start and c.start < video.end()
			elif ViewMap.reaches(map, video, c, owner_id):
				var playing: PackedInt32Array = ViewStreams.views_playing(map, owner_id, c, video, copy_stream)
				for v: int in playing:
					if p_views.is_empty() or p_views.has(v):
						hit = true
			if not hit:
				cd["muted"] = true
				continue
			var kept: Array = []
			for fx: Variant in cd.get("effects", []):
				var fd: Dictionary = fx
				if String(fd.get("id", "")) == "gain" and String(fd.get("uid", "")).begins_with(prefix):
					continue
				kept.append(fd)
			cd["effects"] = kept
	return g

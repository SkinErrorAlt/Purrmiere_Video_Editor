extends Node

signal project_changed
signal sequence_changed(seq_id: String)
signal playhead_changed(t: float)
signal playing_changed(on: bool)
signal about_to_play
signal tool_changed(tool_id: String)
signal compositor_changed
signal audio_owner_changed(owner: String)

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Io := preload("res://doc/io.gd")
const PlaybackClock := preload("res://engine/playback_clock.gd")
const Icons := preload("res://ui/kit/icons.gd")
const FullQuality := preload("res://engine/full_quality.gd")
const RegionApply := preload("res://doc/region_apply.gd")

var doc: Project = null
var seq_id: String = ""
var compositor: Node = null
var tool_id: String = "select"
var playing: bool = false
var rate: float = 1.0
var loop: bool = false
var media_handles: Dictionary = {}
var playback_quality: int = 0
var asked_quality: int = 0
var audio_out: AudioStreamPlayer = null
var clock_source: String = "wall"
var audio_owner: String = ""
var _play_origin_time: float = 0.0
var _play_origin_clock: float = 0.0
var _last_engine_time: float = -1.0
var _engine_stall: float = 0.0
var _out_tried: bool = false
var _last_scrub_sent: float = -1.0
var _last_scrub_time: float = -1.0
var _span_stop: float = -1.0
var _span_back: float = -1.0


const CURSOR_SHAPES: Dictionary = {
	"arrow": Input.CURSOR_ARROW, "default": Input.CURSOR_ARROW, "select": Input.CURSOR_ARROW,
	"ibeam": Input.CURSOR_IBEAM, "razor": Input.CURSOR_IBEAM,
	"pointing_hand": Input.CURSOR_POINTING_HAND, "clip": Input.CURSOR_POINTING_HAND,
	"cross": Input.CURSOR_CROSS, "pen": Input.CURSOR_CROSS, "zoom": Input.CURSOR_CROSS,
	"drag": Input.CURSOR_DRAG, "hand": Input.CURSOR_DRAG,
	"hsize": Input.CURSOR_HSIZE, "vsize": Input.CURSOR_VSIZE, "hsplit": Input.CURSOR_HSPLIT, "vsplit": Input.CURSOR_VSPLIT,
	"move": Input.CURSOR_MOVE, "wait": Input.CURSOR_WAIT, "busy": Input.CURSOR_BUSY, "forbidden": Input.CURSOR_FORBIDDEN, "help": Input.CURSOR_HELP,
}


func _ready() -> void:
	set_process(true)
	call_deferred("_ensure_audio_out")
	call_deferred("load_cursors")
	preload("res://host/scrub_memory.gd").register()
	preload("res://host/drives.gd").register()
	preload("res://engine/look_ahead.gd").register(Prefs)
	preload("res://engine/proxies.gd").register(Prefs)
	FullQuality.register(Prefs)
	PurrBridge.set_full_quality(FullQuality.on_for(Prefs))
	Icons.register(Prefs)
	load("res://engine/purrframes/purrframes.gd").start()
	if not Prefs.changed.is_connected(_on_pref_changed):
		Prefs.changed.connect(_on_pref_changed)


func _on_pref_changed(key: String) -> void:
	if key == "undo_depth" and doc != null and doc.undo != null:
		doc.undo.set_depth(maxi(int(Prefs.get_value("undo_depth")), 1))
	elif key == "playback.hw_decode":
		Events.toast("Hardware decode applies to media opened from now on, reopen the project for everything")
	elif key == Icons.PREF_STYLE:
		if Icons.apply_style(Prefs):
			get_tree().root.propagate_call("queue_redraw")
	elif key == "playback.low_res_pictures":
		if compositor != null and compositor.has_method("render_time"):
			compositor.call("render_time", playhead(), false)
	elif key == FullQuality.PREF:
		apply_full_quality()


func apply_full_quality() -> void:
	PurrBridge.set_full_quality(FullQuality.on_for(Prefs))
	preload("res://engine/proxies.gd").refresh_route(true)
	set_playback_quality(asked_quality)
	if compositor != null and compositor.has_method("render_time"):
		compositor.call("render_time", playhead(), false)


func load_cursors() -> int:
	var dir_path: String = Prefs.data_path("cursors")
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return 0
	var count: int = 0
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and (entry.ends_with(".png") or entry.ends_with(".svg")):
			var key: String = entry.get_basename().to_lower()
			if CURSOR_SHAPES.has(key):
				var img: Image = Image.new()
				if img.load(dir_path.path_join(entry)) == OK:
					if img.get_width() > 256 or img.get_height() > 256:
						img.resize(mini(img.get_width(), 256), mini(img.get_height(), 256), Image.INTERPOLATE_LANCZOS)
					var hotspot: Vector2 = Vector2.ZERO
					var side: String = dir_path.path_join(entry.get_basename() + ".json")
					if FileAccess.file_exists(side):
						var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(side))
						if typeof(meta) == TYPE_DICTIONARY:
							hotspot = Vector2(float((meta as Dictionary).get("x", 0.0)), float((meta as Dictionary).get("y", 0.0)))
					elif key in ["cross", "pen", "zoom", "move", "hsize", "vsize", "hsplit", "vsplit"]:
						hotspot = Vector2(img.get_width(), img.get_height()) * 0.5
					Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), CURSOR_SHAPES[key], hotspot)
					count += 1
		entry = dir.get_next()
	dir.list_dir_end()
	return count


func _ensure_audio_out() -> bool:
	if audio_out != null and is_instance_valid(audio_out):
		return audio_out.playing
	if _out_tried:
		return false
	_out_tried = true
	if not PurrBridge.available:
		return false
	var stream: AudioStream = PurrBridge.audio_stream()
	if stream == null:
		Events.warn("Audio output is off", "The engine gave no audio stream, playback runs on the wall clock")
		return false
	audio_out = AudioStreamPlayer.new()
	audio_out.name = "AudioOut"
	audio_out.stream = stream
	audio_out.bus = "Master"
	add_child(audio_out)
	audio_out.play()
	var latency: float = AudioServer.get_output_latency()
	if latency > 0.0 and latency < 1.0:
		PurrBridge.set_output_latency(latency)
	clock_source = "engine"
	return true


func has_doc() -> bool:
	return doc != null


func seq() -> Sequence:
	if doc == null:
		return null
	if seq_id.is_empty():
		return doc.active_sequence()
	var s: Sequence = doc.sequence_by_id(seq_id)
	if s == null:
		return doc.active_sequence()
	return s


func set_project(p: Project, path: String = "") -> void:
	if doc != null and doc.has_signal("changed"):
		if doc.changed.is_connected(_on_doc_changed):
			doc.changed.disconnect(_on_doc_changed)
	var was_playing: bool = playing
	doc = p
	seq_id = ""
	playing = false
	if doc != null:
		if not path.is_empty():
			doc.path = path
		doc.changed.connect(_on_doc_changed)
		var s: Sequence = doc.active_sequence()
		if s != null:
			seq_id = s.id
	_sweep_voiceover()
	_on_project_swapped(was_playing)
	project_changed.emit()
	if not seq_id.is_empty():
		sequence_changed.emit(seq_id)


func _sweep_voiceover() -> void:
	if doc == null:
		return
	var vo: Node = get_tree().root.get_node_or_null("/root/VoiceOver") if is_inside_tree() else null
	if vo == null or not bool(vo.call("cleanup_enabled")):
		return
	var gone: PackedStringArray = vo.call("sweep_unused", doc)
	if not gone.is_empty():
		Events.info("Removed %d voice over recording%s no clip was using" % [gone.size(), "" if gone.size() == 1 else "s"])


func close_project() -> void:
	set_project(null)


func set_sequence(id: String) -> void:
	if doc == null or doc.sequence_by_id(id) == null:
		return
	if seq_id == id:
		return
	seq_id = id
	doc.active_sequence_id = id
	_sync_engine_time()
	sequence_changed.emit(id)


func playhead() -> float:
	var s: Sequence = seq()
	if s == null:
		return 0.0
	return s.playhead


func set_playhead(t: float, from_clock: bool = false) -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var v: float = maxf(t, 0.0)
	if absf(s.playhead - v) < 0.000001:
		return
	s.playhead = v
	if not from_clock:
		PurrBridge.set_time(v, 0)
		_play_origin_time = v
		_play_origin_clock = Time.get_ticks_usec() / 1000000.0
		_restart_follow(v)
	playhead_changed.emit(v)


var _peaks_asked: Dictionary = {}


func want_peaks(h: int, stream: int, focus: float) -> void:
	if h < 0 or not PurrBridge.available:
		return
	var key: String = str(h) + ":" + str(stream)
	var now: float = Time.get_ticks_usec() / 1000000.0
	if _peaks_asked.has(key) and now - float(_peaks_asked[key]) < 1.0:
		return
	_peaks_asked[key] = now
	PurrBridge.peaks_request(h, stream, focus)


func prepare_media(item: RefCounted) -> void:
	if item == null or not PurrBridge.available:
		return
	var h: Variant = media_handles.get(String(item.get("id")), -1)
	if typeof(h) != TYPE_INT or int(h) < 0:
		return
	var streams: Array = item.get("audio_streams")
	var off: GDScript = load("res://doc/stream_off.gd")
	off.call("push", doc, item)
	for si: int in maxi(1, streams.size()):
		if not bool(off.call("is_off", item, si)):
			PurrBridge.peaks_request(int(h), si, 0.0)
	PurrBridge.request_frame(int(h), 0.0, 0, 2)


func scrub_to(t: float) -> void:
	_scrub_mark(t)
	set_playhead(t)
	if playing or not PurrBridge.available:
		return
	if not Prefs.is_registered("audio.scrub"):
		Prefs.register("audio.scrub", true, {"label": "Play audio while scrubbing", "type": "bool"})
		Prefs.register("audio.scrub_window", 0.08, {"label": "Scrub audio window (seconds)", "type": "float", "min": 0.02, "max": 0.4})
	if bool(Prefs.get_value("audio.scrub")):
		var now: float = Time.get_ticks_usec() / 1000000.0
		var window: float = float(Prefs.get_value("audio.scrub_window"))
		if now - _last_scrub_sent < window * 0.5 and absf(t - _last_scrub_time) < window:
			return
		_last_scrub_sent = now
		_last_scrub_time = t
		_ensure_audio_out()
		PurrBridge.scrub(maxf(t, 0.0), window)


func claim_audio(owner: String, graph: Dictionary) -> bool:
	if owner.is_empty() or not PurrBridge.available:
		return false
	if playing:
		set_playing(false)
	audio_owner = owner
	_ensure_audio_out()
	PurrBridge.set_audio_graph(graph)
	audio_owner_changed.emit(owner)
	return true


func release_audio(owner: String) -> void:
	if owner.is_empty() or audio_owner != owner:
		return
	audio_owner = ""
	PurrBridge.set_playing(false)
	PurrBridge.set_rate(rate)
	audio_owner_changed.emit("")
	PurrBridge.set_time(playhead(), 0)


func set_playing(on: bool) -> void:
	_span_stop = -1.0
	_span_back = -1.0
	if on and not audio_owner.is_empty():
		release_audio(audio_owner)
	if playing == on:
		return
	playing = on
	_play_origin_time = playhead()
	_play_origin_clock = Time.get_ticks_usec() / 1000000.0
	_restart_follow(_play_origin_time)
	_last_engine_time = -1.0
	_engine_stall = 0.0
	if on and clock_source == "wall" and audio_out != null and is_instance_valid(audio_out) and audio_out.playing:
		clock_source = "engine"
	if on:
		_catch_up_engine_time()
		about_to_play.emit()
	PurrBridge.set_rate(rate)
	PurrBridge.set_playing(on)
	playing_changed.emit(on)


func toggle_play() -> void:
	set_playing(not playing)


func play_span(from_t: float, to_t: float, back_to: float = -1.0) -> void:
	if doc == null:
		return
	set_playing(false)
	set_rate(1.0)
	set_playhead(maxf(from_t, 0.0))
	set_playing(true)
	_span_stop = to_t
	_span_back = back_to


func span_stop() -> float:
	return _span_stop


func _span_reached(t: float) -> bool:
	if _span_stop < 0.0 or loop or t < _span_stop:
		return false
	var back: float = _span_back
	var stop_at: float = _span_stop
	set_playing(false)
	set_playhead(back if back >= 0.0 else stop_at)
	return true


func set_rate(r: float) -> void:
	rate = r
	_play_origin_time = playhead()
	_play_origin_clock = Time.get_ticks_usec() / 1000000.0
	_restart_follow(_play_origin_time)
	PurrBridge.set_rate(r)


const WINDOW_MOVE_QUIET_MS := 250

var _window_move_until: int = 0


func note_window_move() -> void:
	_window_move_until = Time.get_ticks_msec() + WINDOW_MOVE_QUIET_MS


func window_moving() -> bool:
	return Time.get_ticks_msec() < _window_move_until


func set_tool(id: String) -> void:
	if tool_id == id:
		return
	tool_id = id
	tool_changed.emit(id)


func set_compositor(c: Node) -> void:
	compositor = c
	compositor_changed.emit()


var render_handles: Dictionary = {}


func render_handle(path: String) -> int:
	if path.is_empty() or not PurrBridge.available:
		return -1
	if render_handles.has(path):
		return int(render_handles[path])
	if not FileAccess.file_exists(path):
		return -1
	var h: int = PurrBridge.open_media(path, {"hw": false})
	if h < 0:
		return -1
	render_handles[path] = h
	PurrBridge.peaks_request(h, 0, 0.0)
	return h


func forget_render(path: String) -> void:
	if render_handles.has(path):
		PurrBridge.close_media(int(render_handles[path]))
		render_handles.erase(path)


var lane_handles: Dictionary = {}


func lane_handle(path: String, lane: String) -> int:
	if path.is_empty() or not PurrBridge.available:
		return -1
	var key: String = path + "|" + lane
	if lane_handles.has(key):
		return int(lane_handles[key])
	if not FileAccess.file_exists(path):
		return -1
	var hw: bool = true
	if Prefs.is_registered("playback.hw_decode"):
		hw = bool(Prefs.get_value("playback.hw_decode"))
	var h: int = PurrBridge.open_media(path, {"hw": hw})
	if h < 0:
		return -1
	lane_handles[key] = h
	if playback_quality > 0:
		PurrBridge.set_quality(h, playback_quality)
	return h


func forget_lanes(path: String = "") -> void:
	for key: String in lane_handles.keys():
		if path.is_empty() or key.begins_with(path + "|"):
			PurrBridge.close_media(int(lane_handles[key]))
			lane_handles.erase(key)
	if path.is_empty():
		forget_proxies()


const PROXY_KEEP := 12
const PROXY_IDLE_MS := 3000

var proxy_handles: Dictionary = {}
var proxy_opened: int = 0
var _proxy_seen: Dictionary = {}


func proxy_handle(path: String, lane: String) -> int:
	if path.is_empty() or not PurrBridge.available:
		return -1
	var key: String = path + "|" + lane
	var now: int = Time.get_ticks_msec()
	if proxy_handles.has(key):
		_proxy_seen[key] = now
		return int(proxy_handles[key])
	if not FileAccess.file_exists(path):
		return -1
	var h: int = PurrBridge.open_media(path, {"hw": false})
	if h < 0:
		return -1
	proxy_handles[key] = h
	_proxy_seen[key] = now
	proxy_opened += 1
	if playback_quality > 0:
		PurrBridge.set_quality(h, playback_quality)
	_trim_proxies(now)
	return h


func _trim_proxies(now: int) -> void:
	while proxy_handles.size() > PROXY_KEEP:
		var oldest: String = ""
		var oldest_ms: int = now
		for key: String in proxy_handles.keys():
			var seen: int = int(_proxy_seen.get(key, 0))
			if now - seen >= PROXY_IDLE_MS and seen <= oldest_ms:
				oldest = key
				oldest_ms = seen
		if oldest.is_empty():
			return
		PurrBridge.close_media(int(proxy_handles[oldest]))
		proxy_handles.erase(oldest)
		_proxy_seen.erase(oldest)


func forget_proxies(path: String = "") -> void:
	for key: String in proxy_handles.keys():
		if path.is_empty() or key.begins_with(path):
			PurrBridge.close_media(int(proxy_handles[key]))
			proxy_handles.erase(key)
			_proxy_seen.erase(key)


func forget_lane(path: String, lane: String) -> void:
	var key: String = path + "|" + lane
	if lane_handles.has(key):
		PurrBridge.close_media(int(lane_handles[key]))
		lane_handles.erase(key)


const ENGINE_TIME_SLACK := 0.1


func _on_project_swapped(was_playing: bool) -> void:
	forget_lanes()
	if not PurrBridge.available:
		return
	if was_playing:
		PurrBridge.set_playing(false)
		playing_changed.emit(false)
	_sync_engine_time()


func _sync_engine_time() -> void:
	if not PurrBridge.available or playing or not audio_owner.is_empty() or doc == null:
		return
	var t: float = playhead()
	PurrBridge.set_time(t, 0)
	_play_origin_time = t
	_play_origin_clock = Time.get_ticks_usec() / 1000000.0


func _catch_up_engine_time() -> void:
	if not PurrBridge.available or not audio_owner.is_empty():
		return
	var t: float = playhead()
	var gap: float = PurrBridge.clock_time() - t
	var latency: float = clampf(AudioServer.get_output_latency(), 0.0, 1.0)
	if gap < -ENGINE_TIME_SLACK or gap > latency + ENGINE_TIME_SLACK:
		PurrBridge.set_time(t, 0)


var smooth_clock: bool = true
var audio_clock: float = 0.0
var _follow: PlaybackClock.Follower = PlaybackClock.Follower.new()


func _restart_follow(t: float) -> void:
	_follow.reset(t, Time.get_ticks_usec() / 1000000.0, rate)


func _follow_clock(raw: float) -> float:
	audio_clock = raw
	if not smooth_clock:
		return raw
	return _follow.step(raw, Time.get_ticks_usec() / 1000000.0)


func follow_stats() -> Dictionary:
	return {"resyncs": _follow.resyncs, "holds": _follow.holds, "smooth": smooth_clock}


func set_playback_quality(q: int) -> void:
	asked_quality = clampi(q, 0, 3)
	playback_quality = FullQuality.quality_for(asked_quality)
	if not PurrBridge.available:
		return
	for id: Variant in media_handles.keys():
		var h: int = int(media_handles[id])
		if h >= 0:
			PurrBridge.set_quality(h, playback_quality)
	for key: Variant in lane_handles.keys():
		PurrBridge.set_quality(int(lane_handles[key]), playback_quality)
	for key: Variant in proxy_handles.keys():
		PurrBridge.set_quality(int(proxy_handles[key]), playback_quality)


func _wall_time() -> float:
	return _play_origin_time + (Time.get_ticks_usec() / 1000000.0 - _play_origin_clock) * rate


func _process(dt: float) -> void:
	if not playing or doc == null:
		return
	var t: float
	if PurrBridge.available and _ensure_audio_out() and clock_source == "engine":
		t = PurrBridge.clock_time()
		if _last_engine_time >= 0.0 and absf(t - _last_engine_time) < 0.000001:
			_engine_stall += dt
			if _engine_stall > 0.35:
				clock_source = "wall"
				_play_origin_time = t
				_play_origin_clock = Time.get_ticks_usec() / 1000000.0
				Events.warn("Audio clock stalled", "The audio device is not pulling samples, playback continues on the wall clock")
				t = _wall_time()
		else:
			_engine_stall = 0.0
		_last_engine_time = t
	else:
		t = _wall_time()
	t = _follow_clock(t)
	var s: Sequence = seq()
	if s == null:
		return
	if _span_reached(t):
		return
	if rate > 0.0:
		var skip_to: float = RegionApply.past(doc, s, t)
		if skip_to > t:
			set_playhead(skip_to)
			return
	var end: float = s.duration()
	if s.out_point >= 0.0 and loop:
		end = s.out_point
	if end > 0.0 and t >= end:
		if loop:
			var start: float = maxf(s.in_point, 0.0)
			set_playhead(start)
			return
		set_playing(false)
		set_playhead(end)
		return
	set_playhead(t, true)


func _on_doc_changed(kind: String) -> void:
	if kind == "structure" and doc != null:
		if doc.sequence_by_id(seq_id) == null:
			var s: Sequence = doc.active_sequence()
			seq_id = s.id if s != null else ""
			sequence_changed.emit(seq_id)


signal nest_view_changed

const PREF_HEAR_OUTSIDE := "timeline.hear_outside"
const PREF_SHOW_WHOLE := "timeline.show_whole"
const NEST_AUDIO_PATH := "res://engine/nest_audio.gd"
const AUDIO_GRAPH_PATH := "res://engine/audio_graph.gd"

var nest_contexts: Dictionary = {}


func _nest_prefs() -> void:
	if not Prefs.is_registered(PREF_HEAR_OUTSIDE):
		Prefs.register(PREF_HEAR_OUTSIDE, true, {"label": "Inside a nest, hear the tracks around it", "type": "bool"})
	if not Prefs.is_registered(PREF_SHOW_WHOLE):
		Prefs.register(PREF_SHOW_WHOLE, false, {"label": "Inside a nest, show the whole sequence in the Program monitor", "type": "bool"})


func hear_outside() -> bool:
	_nest_prefs()
	return bool(Prefs.get_value(PREF_HEAR_OUTSIDE))


func show_whole() -> bool:
	_nest_prefs()
	return bool(Prefs.get_value(PREF_SHOW_WHOLE))


func set_hear_outside(on: bool) -> void:
	_nest_prefs()
	Prefs.set_value(PREF_HEAR_OUTSIDE, on)
	nest_view_changed.emit()
	push_playback_graph()


func set_show_whole(on: bool) -> void:
	_nest_prefs()
	Prefs.set_value(PREF_SHOW_WHOLE, on)
	nest_view_changed.emit()
	if compositor != null and is_instance_valid(compositor) and compositor.has_method("render_time"):
		compositor.call("render_time", playhead(), false)


func set_nest_context(nest_seq_id: String, parent_id: String, clip_id: String) -> void:
	if nest_seq_id.is_empty() or parent_id.is_empty() or clip_id.is_empty() or nest_seq_id == parent_id:
		return
	nest_contexts[nest_seq_id] = {"parent": parent_id, "clip": clip_id}
	nest_view_changed.emit()
	if nest_seq_id == seq_id:
		push_playback_graph()


func clear_nest_contexts() -> void:
	nest_contexts = {}
	nest_view_changed.emit()


func nest_context(nest_seq_id: String) -> Dictionary:
	if doc == null or not nest_contexts.has(nest_seq_id):
		return {}
	var ctx: Dictionary = nest_contexts[nest_seq_id]
	var parent: Sequence = doc.sequence_by_id(String(ctx.get("parent", "")))
	if parent == null or parent.id == nest_seq_id:
		return {}
	var c: RefCounted = parent.clip_by_id(String(ctx.get("clip", "")))
	if c == null:
		return {}
	var nest_audio: GDScript = load(NEST_AUDIO_PATH)
	if nest_audio == null or String(nest_audio.call("nest_sequence_id", doc, c)) != nest_seq_id:
		return {}
	return {"parent": parent.id, "clip": String(c.get("id"))}


func exporting() -> bool:
	for j: Dictionary in Jobs.list():
		if String(j.get("kind", "")) == "export" and bool(j.get("local", false)):
			return true
	return false


func outside_for(for_doc: Object, for_seq_id: String) -> Dictionary:
	if doc == null or for_doc != doc or for_seq_id != seq_id:
		return {}
	if not hear_outside() or exporting():
		return {}
	return nest_context(for_seq_id)


func whole_target(for_seq_id: String, t: float) -> Dictionary:
	if doc == null or for_seq_id != seq_id or not show_whole() or exporting():
		return {}
	var ctx: Dictionary = nest_context(for_seq_id)
	if ctx.is_empty():
		return {}
	var parent: Sequence = doc.sequence_by_id(String(ctx["parent"]))
	var c: RefCounted = parent.clip_by_id(String(ctx["clip"]))
	var nest_audio: GDScript = load(NEST_AUDIO_PATH)
	return {"seq": parent, "t": float(nest_audio.call("parent_time", c, t)), "clip": String(ctx["clip"])}


func push_playback_graph() -> void:
	if doc == null or not PurrBridge.available or not audio_owner.is_empty():
		return
	var graph: GDScript = load(AUDIO_GRAPH_PATH)
	if graph != null:
		PurrBridge.set_audio_graph(graph.call("build", doc, seq(), media_handles))


signal recording_changed(on: bool)

var recording: bool = false


func set_recording(on: bool) -> void:
	if recording == on:
		return
	recording = on
	recording_changed.emit(on)


func toggle_recording() -> void:
	set_recording(not recording)


signal scrub_ended(t: float)

const SCRUB_RECENT_MS := 1500
const SCRUB_LIVE_MS := 250

var _scrub_ms: int = -1000000
var _jump_t: float = -1.0


func _scrub_mark(t: float) -> void:
	_scrub_ms = Time.get_ticks_msec()
	if _jump_t >= 0.0 and absf(t - _jump_t) > 0.000001:
		_jump_t = -1.0


func jump_to(t: float) -> void:
	_jump_t = maxf(t, 0.0)
	scrub_to(t)


func jumping() -> bool:
	return _jump_t >= 0.0 and not playing and absf(playhead() - _jump_t) <= 0.000001


func scrub_live() -> bool:
	if playing or _jump_t >= 0.0 or Time.get_ticks_msec() - _scrub_ms >= SCRUB_LIVE_MS:
		return false
	return not exporting()


func scrub_done() -> void:
	_scrub_ms = Time.get_ticks_msec()
	scrub_ended.emit(playhead())


func scrub_recent() -> bool:
	if playing or Time.get_ticks_msec() - _scrub_ms >= SCRUB_RECENT_MS:
		return false
	return not exporting()

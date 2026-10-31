extends "res://modules/core_panels/panel_base.gd"

const MonitorView := preload("res://modules/core_panels/monitor_view.gd")
const TimecodeField := preload("res://ui/timeline/timecode_field.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const MediaLoader := preload("res://modules/core_panels/media_loader.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const FrameSource := preload("res://engine/frame_source.gd")
const AudioGraph := preload("res://engine/audio_graph.gd")
const EditTools := preload("res://doc/commands/edit_tools.gd")
const StreamRoles := preload("res://doc/stream_roles.gd")
const StreamOff := preload("res://doc/stream_off.gd")
const TitleEditor := preload("res://modules/core_panels/title_editor.gd")
const TextPopout := preload("res://modules/core_panels/text_popout.gd")
const SourceMarks := preload("res://doc/source_marks.gd")
const AUDIO_OWNER := "source"
const STRIP_H := 26.0
const WAVE_H := 40.0
const SNAP_W := 640
const HANDLE_W := 150.0

var view: Control = null
var media_id: String = ""
var time: float = 0.0
var in_t: float = -1.0
var out_t: float = -1.0
var stream: int = 0
var _head_label: Label = null
var _recent: Button = null
var _tc: LineEdit = null
var _streams: Button = null
var _stream_row: HBoxContainer = null
var _duration: Label = null
var _strip: Control = null
var _wave: Control = null
var _play_btn: Button = null
var _playing: bool = false
var play_rate: float = 1.0
var _heard: bool = false
var _heard_at: int = -2
var _snap_key: String = ""
var _snap_want: String = ""
var _snap_in_flight: String = ""
var _snap_pending: bool = false
var _wave_cache: PackedVector2Array = PackedVector2Array()
var _wave_key: String = ""
var _drag_video: Button = null
var _drag_audio: Button = null
var _drag_press: Vector2 = Vector2.ZERO
var _drag_part: String = ""
var _drag_armed: bool = false
var _fs: Node = null
var _fs_key: String = ""
var _fs_live: bool = false
var title_seq_id: String = ""
var title_clip_id: String = ""
var _title_editor: Control = null


func _build(root_: Control) -> void:
	root_.tree_exiting.connect(_on_root_leaving)
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_head_label = PmLabel.trim("Source", "text_bright")
	head.add_child(_head_label)
	_recent = PmButton.make("Recent", "chev_d")
	_recent.set("quiet", true)
	_recent.pressed.connect(_on_recent.bind(_recent))
	head.add_child(_recent)
	view = MonitorView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.set("empty_text", "Open a clip from the bin")
	view.connect("picture_input", _on_picture_input)
	col.add_child(view)
	_title_editor = TitleEditor.new()
	_title_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_title_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_editor.visible = false
	_title_editor.connect("popout_asked", _on_popout_asked)
	col.add_child(PmUI.inset(_title_editor, 4.0, 4.0))
	_wave = _WaveLane.new()
	_wave.panel = self
	_wave.custom_minimum_size = Vector2(0.0, float(Tk.px(WAVE_H)))
	_wave.visible = false
	col.add_child(_wave)
	_strip = _Strip.new()
	_strip.panel = self
	_strip.custom_minimum_size = Vector2(0.0, float(Tk.px(STRIP_H)))
	col.add_child(_strip)
	var bar: HBoxContainer = header_row(col)
	_tc = TimecodeField.make(fps())
	_tc.connect("time_entered", _on_tc)
	bar.add_child(_tc)
	bar.add_child(load("res://modules/core_panels/space_hold.gd").call("source_readout", self))
	_streams = PmDrop.make_drop([PmDrop.choice("0", "Stream 1")], "0")
	_streams.connect("changed", _on_stream)
	bar.add_child(_streams)
	_stream_row = PmUI.hbox(2)
	_stream_row.visible = false
	PmUI.tip(_stream_row, "Which audio tracks drag out to the timeline")
	bar.add_child(_stream_row)
	_drag_video = PmButton.make("", "film")
	_drag_video.set("quiet", true)
	PmUI.tip(_drag_video, "Drag video only to the timeline")
	_drag_video.gui_input.connect(_on_handle_input.bind("video"))
	bar.add_child(_drag_video)
	_drag_audio = PmButton.make("", "audio")
	_drag_audio.set("quiet", true)
	PmUI.tip(_drag_audio, "Drag audio only to the timeline")
	_drag_audio.gui_input.connect(_on_handle_input.bind("audio"))
	bar.add_child(_drag_audio)
	bar.add_child(PmUI.spacer())
	_duration = PmLabel.mono("00:00:00:00", "text_dim")
	bar.add_child(_duration)
	var trow: HBoxContainer = header_row(col)
	var transport: Container = PmToolbar.make()
	transport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for spec: Array in [["mark_in", "mark_in", "Mark in", "I"], ["mark_out", "mark_out", "Mark out", "O"], ["go_in", "to_start", "Go to in", "Shift+I"], ["step_back", "step_back", "Step back", "Left"], ["play", "play", "Play or stop", "Space"], ["step_fwd", "step_fwd", "Step forward", "Right"], ["go_out", "to_end", "Go to out", "Shift+O"], ["insert", "mark_in", "Insert at the playhead", ","], ["overwrite", "region", "Overwrite at the playhead", "."]]:
		var b: Button = PmButton.make("", String(spec[1]))
		b.set("quiet", true)
		PmUI.tip(b, String(spec[2]), String(spec[3]))
		b.pressed.connect(_on_transport.bind(String(spec[0])))
		transport.call("add_item", b, String(spec[0]), String(spec[2]))
		if String(spec[0]) == "play":
			_play_btn = b
	trow.add_child(transport)
	if not bus().source_requested.is_connected(_on_source_requested):
		bus().source_requested.connect(_on_source_requested)
	if PurrBridge.has_signal("peaks_progress") and not PurrBridge.peaks_progress.is_connected(_on_peaks_progress):
		PurrBridge.peaks_progress.connect(_on_peaks_progress)
	TextPopout.register_all()
	_restore_popout.call_deferred()
	_refresh()


func _restore_popout() -> void:
	if _alive():
		TextPopout.restore(_root)


func _on_popout_asked() -> void:
	if TextPopout.is_open():
		TextPopout.close()
		return
	TextPopout.open(_root)
	TextPopout.bind_clip(title_seq_id, title_clip_id)


func item() -> MediaItem:
	var d: Project = doc()
	if d == null or media_id.is_empty():
		return null
	return d.media_by_id(media_id)


func media_length() -> float:
	var d: Project = doc()
	var m: MediaItem = item()
	if d == null or m == null:
		return 0.0
	var l: float = d.media_duration(m)
	return l if l > 0.0 else MediaLoader.still_seconds()


func _on_source_requested(id: String, in_: float, out_: float) -> void:
	if _playing:
		set_playing(false)
	close_title()
	load("res://modules/core_panels/panel_place.gd").call("source_leave", self)
	media_id = id
	in_t = in_
	out_t = out_
	if in_t < 0.0 and out_t < 0.0:
		var sub: Vector2 = EditTools.subclip_range(item())
		if sub.x >= 0.0:
			in_t = sub.x
			out_t = sub.y
	time = maxf(in_t, 0.0)
	stream = 0
	_snap_key = ""
	_wave_key = ""
	_fs_live = false
	load("res://modules/core_panels/panel_place.gd").call("source_arrive", self, in_, out_)
	_refresh()
	_request_picture()


func _refresh() -> void:
	var m: MediaItem = item()
	_head_label.text = "Source: " + m.label if m != null else "Source"
	if m == null:
		view.call("set_texture", null)
		_duration.text = "00:00:00:00"
		_wave.visible = false
		_drag_video.visible = false
		_drag_audio.visible = false
		_streams.visible = false
		_stream_row.visible = false
		_sync_title_editor()
		_strip.queue_redraw()
		return
	var mfps: float = m.fps if m.fps > 0.0 else fps()
	_tc.call("set_rate", mfps, false)
	_tc.call("set_time", time)
	_duration.text = Timecode.format(media_length(), mfps, false)
	if m.width > 0 and m.height > 0:
		view.call("set_frame_size", float(m.width), float(m.height))
	else:
		var s: Sequence = seq()
		if s != null:
			view.call("set_frame_size", float(s.width), float(s.height))
	_wave.visible = m.kind == "audio" or m.audio_only
	_drag_video.visible = m.has_picture()
	_drag_audio.visible = m.has_audio or m.kind == "audio"
	var choices: Array = []
	if m.audio_streams.size() > 1:
		for i: int in m.audio_streams.size():
			if not StreamOff.is_off(m, i):
				choices.append(PmDrop.choice(str(i), StreamRoles.menu_label(m, i)))
	_streams.visible = choices.size() > 1
	if choices.size() > 1:
		_streams.call("set_choices", choices)
		_streams.call("set_value", str(heard_stream()), false)
	_rebuild_stream_toggles(m)
	if _heard and _heard_at != heard_stream():
		_claim_audio()
	_sync_title_editor()
	_strip.queue_redraw()
	_wave.queue_redraw()


func editing_title() -> bool:
	return not title_clip_id.is_empty()


func title_editor() -> Control:
	return _title_editor


func open_title(sequence_id: String, clip_id: String) -> bool:
	var d: Project = doc()
	if d == null:
		return false
	var s: Sequence = d.sequence_by_id(sequence_id)
	if s == null:
		return false
	var c: Clip = s.clip_by_id(clip_id)
	if c == null:
		return false
	var m: MediaItem = d.media_by_id(c.media_id)
	if m == null or m.kind != "title":
		return false
	bus().request_source(c.media_id, -1.0, -1.0)
	title_seq_id = sequence_id
	title_clip_id = clip_id
	Verbs.select(d, s, PackedStringArray([clip_id]), "replace")
	_sync_title_editor()
	if _title_editor != null:
		_title_editor.call("focus_text")
	TextPopout.bind_clip(title_seq_id, title_clip_id)
	return true


func close_title() -> void:
	if title_clip_id.is_empty():
		return
	title_seq_id = ""
	title_clip_id = ""
	_sync_title_editor()


func _title_clip() -> Clip:
	var d: Project = doc()
	if d == null or title_seq_id.is_empty() or title_clip_id.is_empty():
		return null
	var s: Sequence = d.sequence_by_id(title_seq_id)
	if s == null:
		return null
	return s.clip_by_id(title_clip_id)


func _sync_title_editor() -> void:
	if not title_clip_id.is_empty() and _title_clip() == null:
		title_seq_id = ""
		title_clip_id = ""
	var on: bool = not title_clip_id.is_empty()
	if _title_editor != null:
		if on:
			_title_editor.call("set_target", title_seq_id, title_clip_id)
		else:
			_title_editor.call("set_target", "", "")
		_title_editor.visible = on
	if view != null:
		view.visible = not on
	if _strip != null:
		_strip.visible = not on
	if on and _wave != null:
		_wave.visible = false


func _request_picture() -> void:
	var m: MediaItem = item()
	_fs_live = false
	if m == null:
		return
	if m.kind == "image":
		var key: String = m.id + "|image"
		if _snap_key == key:
			return
		_snap_key = key
		if not m.path.is_empty() and FileAccess.file_exists(m.path):
			var img: Image = Image.new()
			if img.load(m.path) == OK:
				view.call("set_texture", ImageTexture.create_from_image(img))
				return
		view.call("set_texture", null)
		view.set("empty_text", "The image could not be read")
		return
	if m.kind != "video":
		view.call("set_texture", null)
		if m.kind == "audio":
			view.set("empty_text", "Audio only")
		elif m.kind == "title":
			view.set("empty_text", "Double click the title on the timeline to edit it")
		else:
			view.set("empty_text", m.kind.capitalize())
		return
	if not PurrBridge.available or media_handle(m) < 0:
		view.call("set_texture", null)
		view.set("empty_text", "No engine")
		return
	if _ensure_frame_source(m):
		_fs_live = true
		_snap_pending = true
		return
	_snap_pending = true


func source_handle(m: MediaItem) -> int:
	if m == null:
		return -1
	var h: int = -1
	if Session.has_method("lane_handle"):
		h = int(Session.lane_handle(m.path, "source"))
	if h < 0:
		h = media_handle(m)
	return h


func _ensure_frame_source(m: MediaItem) -> bool:
	var h: int = source_handle(m)
	if h < 0 or _root == null or not _root.is_inside_tree():
		return false
	var key: String = m.id + "|" + str(h)
	if _fs != null and _fs_key == key:
		return true
	if _fs == null:
		_fs = FrameSource.new()
		_fs.name = "SourceFrames"
		_root.add_child(_fs)
	_fs.call("setup", FrameSource.KIND_NATIVE, m, Vector2i(m.width, m.height), h)
	_fs_key = key
	view.call("set_texture", _fs.call("texture"))
	view.set("empty_text", "")
	return true


func _tick_frame_source(m: MediaItem) -> void:
	if _fs == null or not _fs_live:
		return
	var hint: int = 1 if _playing else 0
	if _fs.has_method("request"):
		_fs.call("request", time, Session.playback_quality, hint)
	if String(_fs.get("state")) == "pending":
		_snap_pending = true
	var tex: Texture2D = _fs.call("texture")
	if tex != null and view.get("texture") != tex:
		view.call("set_texture", tex)


func tick(_dt: float) -> void:
	if _playing:
		if _root == null or not is_instance_valid(_root) or not _root.is_visible_in_tree():
			set_playing(false)
			return
		if String(Session.audio_owner) != AUDIO_OWNER and _heard:
			_heard = false
		var from_engine: float = _audio_time()
		time = clampf(from_engine if from_engine >= 0.0 else time + _dt * play_rate, 0.0, media_length())
		if time >= media_length() or (play_rate < 0.0 and time <= 0.0):
			set_playing(false)
		_tc.call("set_time", time)
		_strip.queue_redraw()
		_snap_pending = true
	if _snap_pending:
		_snap_pending = false
		var m: MediaItem = item()
		if m == null or m.kind != "video":
			return
		if _fs_live and _fs != null:
			_tick_frame_source(m)
			return
		var h: int = media_handle(m)
		if h < 0:
			return
		var q: float = round(time * (m.fps if m.fps > 0.0 else 30.0)) / (m.fps if m.fps > 0.0 else 30.0)
		var key: String = m.id + "|" + String.num(q, 3)
		if key == _snap_key:
			return
		_snap_key = key
		if PurrBridge.has_async_snapshots():
			if not PurrBridge.snapshot_ready.is_connected(_on_snapshot_ready):
				PurrBridge.snapshot_ready.connect(_on_snapshot_ready)
			_snap_want = str(h) + "|" + String.num(q, 3)
			if _snap_in_flight.is_empty():
				_snap_in_flight = _snap_want
				PurrBridge.request_snapshot(h, q, SNAP_W)
			return
		var img: Image = PurrBridge.snapshot(h, q, SNAP_W)
		if img != null:
			view.call("set_texture", ImageTexture.create_from_image(img))


func _on_snapshot_ready(h: int, seconds: float, width: int, image: Image) -> void:
	if width != SNAP_W:
		return
	var got: String = str(h) + "|" + String.num(seconds, 3)
	if got != _snap_in_flight:
		return
	_snap_in_flight = ""
	if image != null and view != null:
		view.call("set_texture", ImageTexture.create_from_image(image))
	if _snap_want != got and not _snap_want.is_empty():
		var parts: PackedStringArray = _snap_want.split("|")
		if parts.size() == 2:
			_snap_in_flight = _snap_want
			PurrBridge.request_snapshot(int(parts[0]), float(parts[1]), SNAP_W)


func _on_root_leaving() -> void:
	if _playing:
		set_playing(false)
	if PurrBridge.has_signal("peaks_progress") and PurrBridge.peaks_progress.is_connected(_on_peaks_progress):
		PurrBridge.peaks_progress.disconnect(_on_peaks_progress)


var wave_refreshes: int = 0


func _on_peaks_progress(h: int, s: int) -> void:
	var m: MediaItem = item()
	if m == null or _wave == null or not is_instance_valid(_wave) or not _wave.visible:
		return
	if h != media_handle(m) or s != heard_stream():
		return
	_wave_key = ""
	wave_refreshes += 1
	_wave.queue_redraw()


func set_playing(on: bool) -> void:
	if _playing == on:
		return
	_playing = on
	if _play_btn != null and is_instance_valid(_play_btn):
		_play_btn.set("icon_name", "pause" if on else "play")
	if on:
		_claim_audio()
	else:
		_drop_audio()


func set_play_rate(r: float) -> void:
	play_rate = r
	if _heard and String(Session.audio_owner) == AUDIO_OWNER:
		PurrBridge.set_rate(r)


func _claim_audio() -> void:
	_heard = false
	var m: MediaItem = item()
	if m == null or not PurrBridge.available:
		return
	if not m.has_audio and m.kind != "audio":
		return
	var h: int = media_handle(m)
	if h < 0:
		return
	var rate: int = 48000
	var s: Sequence = seq()
	if s != null:
		rate = s.sample_rate
	if not Session.claim_audio(AUDIO_OWNER, source_audio_graph(m, h, rate)):
		return
	_heard = true
	_heard_at = heard_stream()
	PurrBridge.set_rate(play_rate)
	PurrBridge.set_time(time, 0)
	PurrBridge.set_playing(true)


func _drop_audio() -> void:
	if not _heard:
		return
	_heard = false
	Session.release_audio(AUDIO_OWNER)


func _audio_time() -> float:
	if not _heard or String(Session.audio_owner) != AUDIO_OWNER:
		return -1.0
	return PurrBridge.clock_time()


func set_time(t: float) -> void:
	time = clampf(t, 0.0, media_length())
	if _heard:
		PurrBridge.set_time(time, 0)
	_tc.call("set_time", time)
	_strip.queue_redraw()
	_wave.queue_redraw()
	_snap_pending = true


func _on_tc(t: float) -> void:
	set_time(t)


func show_frame(id: String, t: float, in_: float, out_: float) -> void:
	bus().request_source(id, in_, out_)
	if media_id == id:
		set_time(t)


func source_audio_graph(m: MediaItem, h: int, rate: int) -> Dictionary:
	var hs: int = heard_stream()
	return AudioGraph.source_graph(m, h if hs >= 0 else -1, maxi(hs, 0), rate)


func _rebuild_stream_toggles(m: MediaItem) -> void:
	PmUI.clear(_stream_row)
	_stream_row.visible = m.audio_streams.size() > 1
	if not _stream_row.visible:
		return
	for i: int in m.audio_streams.size():
		var sd: Dictionary = m.audio_streams[i]
		var b: Button = PmButton.ghost(Verbs.stream_label(m, i), "", true)
		if StreamOff.is_off(m, i):
			b.button_pressed = false
			b.disabled = true
			PmUI.tip(b, "Switched off in the bin (Audio tracks to use): not heard and not dragged out")
			_stream_row.add_child(b)
			continue
		b.button_pressed = bool(sd.get("selected", true))
		b.toggled.connect(_on_stream_toggle.bind(i))
		PmUI.tip(b, "Drag this audio track out with the video")
		_stream_row.add_child(b)


func _on_stream_toggle(on: bool, index: int) -> void:
	var m: MediaItem = item()
	var d: Project = doc()
	if m == null or d == null or index < 0 or index >= m.audio_streams.size():
		return
	var streams: Array = []
	for sd: Dictionary in m.audio_streams:
		streams.append(sd.duplicate(true))
	streams[index]["selected"] = on
	var any: bool = false
	for sd2: Dictionary in streams:
		if bool(sd2.get("selected", true)):
			any = true
	if not any:
		streams[index]["selected"] = true
		return
	Verbs.run(d, "Audio tracks to drag", [MediaCmds.SetMediaField.new(m.id, "audio_streams", streams)])


func _on_stream(id: String) -> void:
	stream = int(id)
	_wave_key = ""
	_wave.queue_redraw()
	if _heard:
		_claim_audio()


func heard_stream() -> int:
	var m: MediaItem = item()
	if m == null:
		return AudioGraph.monitor_stream(m)
	var want: int = AudioGraph.monitor_stream(m) if m.audio_streams.size() <= 1 else clampi(stream, 0, m.audio_streams.size() - 1)
	if not StreamOff.is_off(m, want):
		return want
	var on: PackedInt32Array = StreamOff.want_streams(m)
	return on[0] if not on.is_empty() else -1


func _on_recent(anchor: Control) -> void:
	var d: Project = doc()
	var items: Array = []
	if d != null:
		for id: String in bus().recent_sources:
			var m: MediaItem = d.media_by_id(id)
			if m != null:
				items.append(PmMenu.item("src:" + id, m.label, "", kind_icon(m.kind)))
	if items.is_empty():
		var none: Dictionary = PmMenu.item("none", "No recent sources")
		none["disabled"] = true
		items.append(none)
	var menu: Control = PmMenu.open(anchor, items)
	if menu != null and menu.is_inside_tree():
		menu.connect("picked", _on_recent_picked)


func _on_recent_picked(id: String) -> void:
	if id.begins_with("src:"):
		bus().request_source(id.substr(4))


func _on_transport(id: String) -> void:
	var m: MediaItem = item()
	if m == null:
		return
	var f: float = 1.0 / (m.fps if m.fps > 0.0 else fps())
	if id == "mark_in":
		mark_in()
	elif id == "mark_out":
		mark_out()
	elif id == "go_in":
		if in_t >= 0.0:
			set_time(in_t)
	elif id == "go_out":
		if out_t >= 0.0:
			set_time(out_t)
	elif id == "step_back":
		set_time(time - f)
	elif id == "step_fwd":
		set_time(time + f)
	elif id == "play":
		set_playing(not _playing)
	elif id == "insert" or id == "overwrite":
		edit_to_timeline(id)


func mark_in() -> void:
	in_t = time
	if out_t >= 0.0 and out_t < in_t:
		out_t = in_t
	_strip.queue_redraw()


func mark_out() -> void:
	out_t = time
	if in_t >= 0.0 and in_t > out_t:
		in_t = out_t
	_strip.queue_redraw()


func range_in() -> float:
	return in_t if in_t >= 0.0 else 0.0


func range_out() -> float:
	return out_t if out_t >= 0.0 else media_length()


func add_source_marker() -> String:
	var d: Project = doc()
	if d == null or media_id.is_empty() or editing_title():
		return ""
	var id: String = SourceMarks.add(d, media_id, time)
	if id.is_empty():
		Events.toast("There is already a marker here")
	_strip.queue_redraw()
	return id


func source_marker_at(t: float, reach_px: float) -> Marker:
	var length: float = media_length()
	var w: float = maxf(_strip.size.x, 1.0) if _strip != null else 1.0
	return SourceMarks.near(item(), t, reach_px * length / w)


func go_source_marker(dir: int) -> bool:
	var t: float = SourceMarks.next_time(item(), time, dir)
	if t < 0.0:
		return false
	set_time(t)
	return true


func open_source_marker(marker_id: String) -> void:
	var m: MediaItem = item()
	if m == null:
		return
	var mk: Marker = null
	for e: Marker in m.markers:
		if e.id == marker_id:
			mk = e
	if mk == null:
		return
	var fields: Array[Dictionary] = []
	fields.append({"key": "label", "label": "Name", "type": "string", "default": mk.label})
	fields.append({"key": "comment", "label": "Comment", "type": "string", "default": mk.comment})
	fields.append({"key": "duration", "label": "Duration (seconds)", "type": "float", "default": mk.duration})
	fields.append({"key": "rgb", "label": "Colour, as #rrggbb", "type": "string", "default": mk.rgb})
	var answered: Signal = PmUI.form(_root, "Source marker", fields, "Apply", "Cancel")
	answered.connect(_on_source_marker_form.bind(media_id, marker_id))


func _on_source_marker_form(result: Variant, owner_id: String, marker_id: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var r: Dictionary = result
	SourceMarks.set_fields(doc(), owner_id, marker_id, {"label": String(r.get("label", "")), "comment": String(r.get("comment", "")), "duration": maxf(float(r.get("duration", 0.0)), 0.0), "rgb": Marker.clean_rgb(r.get("rgb", ""))})


func move_source_marker(marker_id: String, t: float) -> bool:
	return SourceMarks.set_fields(doc(), media_id, marker_id, {"time": clampf(t, 0.0, media_length())}, "Move source marker")


func source_marker_menu(marker_id: String, at: Vector2) -> void:
	var items: Array = [PmMenu.item("edit", "Edit source marker"), PmMenu.separator(), PmMenu.item("remove", "Remove source marker", "", "trash")]
	var menu: Control = PmMenu.open(_root, items, at)
	if menu != null and menu.is_inside_tree():
		menu.connect("picked", _on_source_marker_menu.bind(media_id, marker_id))


func _on_source_marker_menu(id: String, owner_id: String, marker_id: String) -> void:
	if id == "edit":
		open_source_marker(marker_id)
	elif id == "remove":
		SourceMarks.remove(doc(), owner_id, marker_id)


func edit_to_timeline(mode: String) -> bool:
	if media_id.is_empty():
		Events.toast("Open a clip in the Source monitor first")
		return false
	var tl: Object = bus().panel("timeline")
	if tl == null or not tl.has_method("place_at_playhead"):
		return false
	var ok: bool = bool(tl.call("place_at_playhead", PackedStringArray([media_id]), mode, "both", range_in(), range_out()))
	if not ok:
		Events.toast("Nothing was placed, check the targeted tracks")
	return ok


func drag_payload(part: String) -> Dictionary:
	return {"kind": "media", "ids": [media_id], "part": part, "in": range_in(), "out": range_out()}


func _on_handle_input(event: InputEvent, part: String) -> void:
	if media_id.is_empty():
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_press = mb.position
				_drag_part = part
				_drag_armed = true
			else:
				_drag_armed = false
		return
	if event is InputEventMouseMotion and _drag_armed:
		var mm: InputEventMouseMotion = event
		if (mm.position - _drag_press).length() >= float(Tk.px(4.0)):
			_drag_armed = false
			begin_drag(part)


func begin_drag(part: String) -> void:
	var m: MediaItem = item()
	var layer: CanvasLayer = PmDragLayer.find(_root)
	if m == null or layer == null:
		return
	var ghost: Control = _Ghost.new()
	ghost.label = m.label + (" (video)" if part == "video" else (" (audio)" if part == "audio" else ""))
	ghost.icon = "film" if part == "video" else ("audio" if part == "audio" else kind_icon(m.kind))
	ghost.size = Vector2(float(Tk.px(HANDLE_W)), float(Tk.px(26.0)))
	layer.call("begin", drag_payload(part), ghost, Vector2(12.0, 12.0))


func _on_picture_input(event: InputEvent, _pic: Rect2) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_drag_press = mb.position
			_drag_part = "both"
			_drag_armed = true
			view.accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_drag_armed = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			open_sample_menu(mb.global_position)
			view.accept_event()
		return
	if event is InputEventMouseMotion and _drag_armed:
		var mm: InputEventMouseMotion = event
		if (mm.position - _drag_press).length() >= float(Tk.px(4.0)):
			_drag_armed = false
			begin_drag("both")


func open_sample_menu(at: Vector2) -> Control:
	var m: MediaItem = item()
	if m == null or m.path.is_empty() or (m.kind != "video" and m.kind != "image"):
		return null
	var path: String = m.path
	var kind_of_file: String = m.kind
	var t: float = time
	var take: GDScript = load("res://modules/core_panels/organizer/sample_take.gd")
	return take.call("open_menu", view, at, func(id: String) -> void:
		take.call("take", path, t, String(take.call("kind_of_pick", id)), kind_of_file)
	)


func wave_points(width: float) -> PackedVector2Array:
	var m: MediaItem = item()
	if m == null or not PurrBridge.available:
		return PackedVector2Array()
	var h: int = media_handle(m)
	if h < 0:
		return PackedVector2Array()
	var hs: int = heard_stream()
	if hs < 0:
		return PackedVector2Array()
	var length: float = media_length()
	var key: String = m.id + "|" + str(hs) + "|" + str(int(width))
	if key == _wave_key:
		return _wave_cache
	var rate: float = Lanes.tier_rate(2)
	var count: int = int(ceil(length * rate))
	var stride: int = maxi(1, int(ceil(float(count) / maxf(width, 1.0))))
	var bytes: PackedByteArray = PurrBridge.peaks_read(h, hs, 2, 0, count)
	var coverage: PackedByteArray = PurrBridge.peaks_coverage(h, hs)
	var complete: bool = not coverage.is_empty()
	for cv: int in coverage:
		if cv == 0:
			complete = false
			break
	if not complete:
		Session.want_peaks(h, hs, time)
	_wave_cache = Paint.build_wave_points(bytes, 0, rate, stride, false, 1.0)
	if complete:
		_wave_key = key
	return _wave_cache


func handle_key(e: InputEventKey) -> bool:
	if not e.pressed or media_id.is_empty():
		return false
	if not editing_title() and Cmd.keys_for("marker.add").has(Cmd.key_string(e)):
		add_source_marker()
		return true
	var plain: bool = not (e.ctrl_pressed or e.meta_pressed or e.alt_pressed)
	if plain and not e.shift_pressed:
		if e.keycode == KEY_I:
			mark_in()
			return true
		if e.keycode == KEY_O:
			mark_out()
			return true
		if e.keycode == KEY_SPACE:
			return bool(load("res://modules/core_panels/space_hold.gd").call("key_for", e, self))
		if e.keycode == KEY_LEFT:
			_on_transport("step_back")
			return true
		if e.keycode == KEY_RIGHT:
			_on_transport("step_fwd")
			return true
		if e.keycode == KEY_HOME:
			set_time(0.0)
			return true
		if e.keycode == KEY_END:
			set_time(media_length())
			return true
		if e.keycode == KEY_COMMA:
			edit_to_timeline("insert")
			return true
		if e.keycode == KEY_PERIOD:
			edit_to_timeline("overwrite")
			return true
	if plain and e.shift_pressed:
		if e.keycode == KEY_I:
			_on_transport("go_in")
			return true
		if e.keycode == KEY_O:
			_on_transport("go_out")
			return true
	return false


func _on_project_changed() -> void:
	if _playing:
		set_playing(false)
	close_title()
	media_id = ""
	in_t = -1.0
	out_t = -1.0
	_refresh()


func _on_doc_changed(kind: String) -> void:
	if kind == "markers" and _strip != null:
		_strip.queue_redraw()
	if kind == "media":
		if item() == null:
			media_id = ""
		_refresh()
		_request_picture()


func save_state() -> Dictionary:
	return {"media_id": media_id, "in": in_t, "out": out_t, "time": time, "title_seq": title_seq_id, "title_clip": title_clip_id}


func restore_state(d: Dictionary) -> void:
	media_id = String(d.get("media_id", ""))
	in_t = float(d.get("in", -1.0))
	out_t = float(d.get("out", -1.0))
	time = float(d.get("time", 0.0))
	title_seq_id = String(d.get("title_seq", ""))
	title_clip_id = String(d.get("title_clip", ""))
	if _alive():
		_refresh()
		_request_picture()


class _Ghost:
	extends Control

	const IconsKit := preload("res://ui/kit/icons.gd")
	const PmTextKit := preload("res://ui/kit/pm_text.gd")

	var label: String = ""
	var icon: String = "film"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_panel_high"], true)
		draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2(1.0, 1.0)), Tk.c["bg_panel_high"].lightened(0.18), false, 1.0)
		IconsKit.draw(self, icon, Rect2(6.0, (size.y - 14.0) * 0.5, 14.0, 14.0), Tk.c["text"])
		var f: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_small"))
		PmTextKit.draw_in(self, f, Rect2(26.0, 0.0, size.x - 26.0 - PmTextKit.chip_pad(), size.y), label, fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, size.y * 0.5 + f.get_ascent(fs) * 0.5 - 1.0, PmTextKit.ELIDE_OWN_TIP, Rect2(Vector2.ZERO, size), PmTextKit.chip_pad())


class _Strip:
	extends Control

	const PaintKit := preload("res://ui/timeline/timeline_paint.gd")
	const TicksKit := preload("res://ui/timeline/marker_ticks.gd")
	const REACH_PX := 6.0
	const GRAB_BAND := 13.0
	const MOVE_SLOP := 3.0

	var panel: RefCounted = null
	var _dragging: bool = false
	var grab_id: String = ""
	var grab_t: float = 0.0
	var _grab_x0: float = 0.0
	var _grab_t0: float = 0.0
	var _grab_moved: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)

	func _t_of(x: float) -> float:
		var length: float = float(panel.call("media_length"))
		return clampf(x / maxf(size.x, 1.0), 0.0, 1.0) * length

	func _x_of(t: float) -> float:
		var length: float = maxf(float(panel.call("media_length")), 0.0001)
		return t / length * size.x

	func _on_input(event: InputEvent) -> void:
		if String(panel.get("media_id")).is_empty():
			return
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				var hit: Object = panel.call("source_marker_at", _t_of(mb.position.x), REACH_PX)
				if hit != null:
					panel.call("source_marker_menu", String(hit.get("id")), get_global_mouse_position())
					accept_event()
				return
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed and mb.double_click:
					var hit2: Object = panel.call("source_marker_at", _t_of(mb.position.x), REACH_PX)
					if hit2 != null:
						panel.call("open_source_marker", String(hit2.get("id")))
						accept_event()
						return
				if mb.pressed and mb.position.y <= GRAB_BAND:
					var hit3: Object = panel.call("source_marker_at", _t_of(mb.position.x), REACH_PX)
					if hit3 != null:
						grab_id = String(hit3.get("id"))
						_grab_t0 = float(hit3.get("time"))
						grab_t = _grab_t0
						_grab_x0 = mb.position.x
						_grab_moved = false
						accept_event()
						return
				if not mb.pressed and not grab_id.is_empty():
					var id: String = grab_id
					grab_id = ""
					if _grab_moved:
						panel.call("move_source_marker", id, grab_t)
					else:
						panel.call("set_time", _grab_t0)
					queue_redraw()
					accept_event()
					return
				_dragging = mb.pressed
				if mb.pressed:
					panel.call("set_time", _t_of(mb.position.x))
				accept_event()
			return
		if event is InputEventMouseMotion and not grab_id.is_empty():
			var mx: float = (event as InputEventMouseMotion).position.x
			if absf(mx - _grab_x0) >= MOVE_SLOP:
				_grab_moved = true
			if _grab_moved:
				grab_t = clampf(_grab_t0 + (mx - _grab_x0) / maxf(size.x, 1.0) * float(panel.call("media_length")), 0.0, float(panel.call("media_length")))
				queue_redraw()
			accept_event()
			return
		if event is InputEventMouseMotion and _dragging:
			panel.call("set_time", _t_of((event as InputEventMouseMotion).position.x))
			accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_ruler"], true)
		if String(panel.get("media_id")).is_empty():
			return
		var in_t: float = float(panel.get("in_t"))
		var out_t: float = float(panel.get("out_t"))
		var a: float = _x_of(in_t) if in_t >= 0.0 else 0.0
		var b: float = _x_of(out_t) if out_t >= 0.0 else size.x
		draw_rect(Rect2(a, 0.0, maxf(b - a, 1.0), size.y), Tk.c["selection_fill"], true)
		PaintKit.draw_in_out(self, Rect2(Vector2.ZERO, size), _x_of(in_t) if in_t >= 0.0 else -INF, _x_of(out_t) if out_t >= 0.0 else -INF)
		TicksKit.draw_strip(self, Rect2(Vector2.ZERO, size), panel.call("item"), float(panel.call("media_length")), grab_id if _grab_moved else "", grab_t)
		var px: float = _x_of(float(panel.get("time")))
		PaintKit.draw_playhead(self, px, 0.0, size.y, true)
		draw_rect(Rect2(0.0, size.y - 1.0, size.x, 1.0), Tk.c["border"], true)


class _WaveLane:
	extends Control

	const PmTextKit := preload("res://ui/kit/pm_text.gd")
	const WaveLookKit := preload("res://ui/timeline/wave_look.gd")
	const WaveSheetKit := preload("res://ui/timeline/wave_look_sheet.gd")

	var panel: RefCounted = null
	var _look_src: PackedVector2Array = PackedVector2Array()
	var _look_holder: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		gui_input.connect(_on_input)

	func _ready() -> void:
		WaveLookKit.register_prefs()
		WaveLookKit.listen(self)

	func _on_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				WaveSheetKit.open(self, get_global_mouse_position())
				accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_lane_audio"], true)
		var f: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_small"))
		if not PurrBridge.available:
			PmTextKit.draw(self, f, Rect2(Vector2.ZERO, size), "Waveform needs the engine", fs, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, size.y * 0.5 + 4.0)
			return
		var pts: PackedVector2Array = panel.call("wave_points", size.x)
		var lk: Dictionary = WaveLookKit.look()
		if WaveLookKit.anchor_of(lk) == WaveLookKit.GROW_MIDDLE:
			draw_line(Vector2(0.0, size.y * 0.5), Vector2(size.x, size.y * 0.5), Tk.c["wave_line"], 1.0)
		if pts.size() < 4:
			return
		var length: float = maxf(float(panel.call("media_length")), 0.0001)
		if pts != _look_src:
			_look_src = pts
			_look_holder = {}
		var it: Variant = panel.call("item")
		var media_colour: int = int((it as Object).get("colour")) if it is Object else -1
		var cols: Dictionary = WaveLookKit.columns_cached(_look_holder, pts, WaveLookKit.base_colour(lk, -1, media_colour), WaveLookKit.scale(false, 1.0), size.x / length, size.y * 0.5)
		draw_set_transform(Vector2(0.0, size.y * 0.5), 0.0, Vector2(size.x / length, size.y * 0.5))
		WaveLookKit.draw_columns(self, cols)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

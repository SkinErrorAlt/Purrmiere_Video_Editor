extends Node

signal progress(frac: float, message: String)
signal finished(ok: bool, message: String)

const ExportPresets := preload("res://modules/export/export_presets.gd")
const AudioGraph := preload("res://engine/audio_graph.gd")
const ListenMute := preload("res://engine/listen_mute.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const ViewExport := preload("res://modules/export/view_export.gd")
const WavJoin := preload("res://modules/export/wav_join.gd")
const SoundEnvelopes := preload("res://engine/sound_envelopes.gd")
const PictureSeries := preload("res://engine/picture_series.gd")
const DONE_NOTICE := "res://modules/export/export_done_notice.gd"
const REGION_APPLY := "res://doc/region_apply.gd"
const TEMP_DIR := "user://export_tmp/"
const PREF_BACKDROP_IN_EXPORT := "program.backdrop.in_export"
const SETTLE_LIMIT := 600
const SETTLE_SECONDS := 20.0
const PREF_SETTLE_SECONDS := "export.settle_seconds"
const PUSH_TIMEOUT_MS := 30000
const DONE_TIMEOUT_MS := 600000
const PREF_BUDGET_MS := "export.editor_budget_ms"
const PREF_PNG_VERIFY := "export.png_verify"
const PNG_VERIFY := true
const PNG_RETRIES := 3
const PNG_VERIFY_LABEL := "Export: check every PNG frame before it is written"
const PNG_VERIFY_HINT := "Only PNG exports are affected. Each frame is unpacked once and its zlib checksum compared with the data, which costs a little time on the slowest export path there is. It works around a defect in the bundled FFmpeg that writes about one frame in seventeen thousand with a checksum that does not match its own picture. Turning it off restores the old behaviour, including the encoder thread count."
const BUDGET_MS := 6
const BUDGET_MIN_MS := 1
const BUDGET_MAX_MS := 200
const MAX_IDLE_FRAMES := 8
const OFFLOAD_PIXELS := 1920 * 1080
const READBACK_DEPTH := 2
const READBACK_TIMEOUT_MS := 10000
const DELIVER_OK := 0
const DELIVER_READ_FAILED := 1
const DELIVER_STOPPED := 2

static var compositor_holders: int = 0

var settings: Dictionary = {}
var seq: Sequence = null
var doc: Project = null
var compositor: Node = null
var media_handles: Dictionary = {}
var encoders: Array[Dictionary] = []
var containers: Array[Dictionary] = []
var job: Dictionary = {}
var job_id: int = -1
var state: String = "idle"
var plan_text: String = ""
var result_message: String = ""
var output_path: String = ""
var frames_done: int = 0
var total_frames: int = 0
var settle_waits: int = 0
var started_ms: int = 0
var job_fps: float = 0.0
var ms_settle: int = 0
var ms_read: int = 0
var ms_convert: int = 0
var ms_push: int = 0
var ms_idle: int = 0
var idle_frames: int = 0
var offloaded_frames: int = 0
var async_frames: int = 0
var notify_on_finish: bool = true
var png_result: Dictionary = {}
var _since_yield_ms: int = 0
var _vsync_was: int = -1
var _max_fps_was: int = -1
var _reads_held: bool = false
var probe_times: PackedFloat64Array = PackedFloat64Array()
var job_spans: PackedVector2Array = PackedVector2Array()
var skip_spans: PackedVector2Array = PackedVector2Array()
var late_frames: int = 0
var late_text: String = ""
var cancel_requested: bool = false
var local_job_id: int = -1
var share_to_clipboard: bool = false
var transparent: bool = false
var backdrop_drawn: bool = false
var clipboard_copied: bool = false
var _backdrop_prev: Dictionary = {}
var view_run: RefCounted = null
var _seq_prev: Sequence = null
var _seq_held: bool = false
var _done: Dictionary = {}
var _bridge: Node = null
var _events: Node = null
var _jobs: Node = null


func _autoload(n: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(n)
	return null


func setup(settings_: Dictionary, seq_: Sequence, doc_: Project, compositor_: Node, handles: Dictionary = {}) -> void:
	settings = ExportPresets.normalise(settings_)
	seq = seq_
	doc = doc_
	compositor = compositor_
	media_handles = handles
	_bridge = _autoload("PurrBridge")
	_events = _autoload("Events")
	_jobs = _autoload("Jobs")
	encoders = ExportPresets.encoders_available(_bridge)
	containers = ExportPresets.containers_available(_bridge)
	settings = ExportPresets.effective(settings, containers)
	_view_setup()


static func backdrop_wanted(in_export_pref: bool, transparent_: bool) -> bool:
	return in_export_pref and not transparent_


func _backdrop_pref() -> bool:
	var prefs: Node = _autoload("Prefs")
	if prefs == null or not bool(prefs.call("is_registered", PREF_BACKDROP_IN_EXPORT)):
		return false
	return bool(prefs.call("get_value", PREF_BACKDROP_IN_EXPORT))


func _hold_backdrop(show: bool) -> void:
	backdrop_drawn = false
	if compositor == null or not compositor.has_method("set_backdrop_hidden"):
		return
	_backdrop_prev = {"hidden": bool(compositor.get("backdrop_hidden"))}
	compositor.call("set_backdrop_hidden", not show)
	backdrop_drawn = show and bool(compositor.call("has_backdrop"))


func _release_backdrop() -> void:
	_view_release()
	_release_sequence()
	if _backdrop_prev.is_empty() or compositor == null or not is_instance_valid(compositor):
		return
	compositor.call("set_backdrop_hidden", bool(_backdrop_prev["hidden"]))
	_backdrop_prev = {}
	if seq != null and compositor.has_method("render_time"):
		compositor.call("render_time", seq.playhead, true)


func _decide_transparency() -> void:
	transparent = false
	if not bool(settings.get("transparent", false)):
		return
	var caps: Dictionary = _bridge.call("export_caps") if _bridge != null and _bridge.has_method("export_caps") else {}
	var st: Dictionary = ExportPresets.alpha_status(caps, String(settings.get("container", "mp4")), String(settings.get("video_codec", "")))
	transparent = bool(st.get("ok", false))
	if not transparent:
		_info("Transparent background is off for this export, the empty parts are black", String(st.get("reason", "")))


func copy_file_to_clipboard(path: String) -> bool:
	var cmd: Dictionary = ExportPresets.share_clipboard_command(ProjectSettings.globalize_path(path), OS.get_name())
	if cmd.is_empty():
		return false
	var pid: int = OS.create_process(String(cmd["exe"]), cmd["args"], false)
	return pid > 0


func _free_the_clock() -> void:
	if _vsync_was >= 0 or DisplayServer.get_name() == "headless":
		return
	_vsync_was = int(DisplayServer.window_get_vsync_mode())
	_max_fps_was = Engine.max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0


func _hold_export_reads(on: bool) -> void:
	if on == _reads_held:
		return
	if compositor == null or not is_instance_valid(compositor) or not compositor.has_method("set_export_reads"):
		return
	_reads_held = on
	compositor.call("set_export_reads", on)


func _restore_the_clock() -> void:
	_hold_export_reads(false)
	if _vsync_was < 0:
		return
	DisplayServer.window_set_vsync_mode(_vsync_was as DisplayServer.VSyncMode)
	Engine.max_fps = _max_fps_was
	_vsync_was = -1
	_max_fps_was = -1


func _fail(message: String, fixes: PackedStringArray = PackedStringArray()) -> void:
	_restore_the_clock()
	_release_backdrop()
	state = "failed"
	result_message = message
	if _events != null:
		_events.error("Export failed: " + message, output_path, fixes)
	if _jobs != null and local_job_id >= 0:
		_jobs.done_local(local_job_id, false)
	_announce(false, false, message)
	finished.emit(false, message)


func _announce(ok: bool, cancelled: bool, message: String) -> void:
	if not notify_on_finish or not probe_times.is_empty() or not is_inside_tree():
		return
	var script: GDScript = load(DONE_NOTICE)
	if script == null:
		return
	script.call("show_result", self, ok, cancelled, output_path, message)


func _info(text: String, detail: String = "") -> void:
	if _events != null:
		_events.info(text, detail)


func cancel() -> void:
	cancel_requested = true


static func audio_groups(seq: Sequence, layout: String, spec: String) -> Array:
	var out: Array = []
	if seq == null:
		return [{"title": "", "tracks": []}]
	var stems: Array[Track] = stem_tracks(seq)
	if layout == "tracks":
		for i: int in stems.size():
			var tr: Track = stems[i]
			out.append({"title": stem_title(seq, tr, i), "tracks": [tr.id]})
	elif layout == "custom":
		for part: String in spec.split(","):
			var names: PackedStringArray = PackedStringArray()
			var ids: Array = []
			for token: String in part.split("+"):
				var name_: String = token.strip_edges().to_upper()
				if name_.is_empty():
					continue
				for i: int in stems.size():
					var tr: Track = stems[i]
					if (i < seq.audio_tracks.size() and name_ == "A" + str(i + 1)) or name_ == tr.label.to_upper() or name_ == tr.shown_label().to_upper():
						ids.append(tr.id)
						names.append(name_)
			if not ids.is_empty():
				out.append({"title": "+".join(names), "tracks": ids})
	if out.is_empty():
		out.append({"title": "", "tracks": []})
	return out


static func stem_tracks(seq: Sequence) -> Array[Track]:
	var out: Array[Track] = []
	out.append_array(seq.audio_tracks)
	for tr: Track in seq.extra_sound_tracks():
		for c: Clip in tr.clips:
			if tr.is_sound(c):
				out.append(tr)
				break
	return out


static func stem_title(seq: Sequence, tr: Track, i: int) -> String:
	if seq.free_tracks or i >= seq.audio_tracks.size():
		return tr.shown_label()
	return tr.label if not tr.label.is_empty() else "A" + str(i + 1)


static func graph_for_group(graph: Dictionary, group: Dictionary) -> Dictionary:
	var ids: Array = group.get("tracks", [])
	if ids.is_empty():
		return graph
	var out: Dictionary = graph.duplicate(true)
	var tracks: Array = []
	for tr: Variant in out.get("tracks", []):
		var td: Dictionary = tr
		if td.has("owner"):
			td["muted"] = bool(td.get("muted", false)) or not (String(td["owner"]) in ids)
		else:
			td["muted"] = not (String(td.get("id", "")) in ids)
		td["solo"] = false
		tracks.append(td)
	out["tracks"] = tracks
	return out


func _on_job_progress(id: int, _p: float, message: String) -> void:
	if id != job_id or message.is_empty():
		return
	if plan_text.is_empty():
		plan_text = message
		progress.emit(0.0, plan_text)
		_info("Export plan", plan_text)


func _on_job_done(id: int, ok: bool, message: String) -> void:
	if id == job_id:
		_done = {"ok": ok, "message": message}


func _temp_path(suffix: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_DIR))
	var stamp: String = str(Time.get_ticks_usec())
	return ProjectSettings.globalize_path(TEMP_DIR + "export_" + stamp + suffix)


func _thumbnail_time(range_v: Vector2) -> float:
	var thumb: Dictionary = settings.get("thumbnail", {})
	var source: String = String(thumb.get("source", "poster"))
	if source == "playhead":
		return clampf(seq.playhead, range_v.x, range_v.y)
	if source == "pick":
		return clampf(float(thumb.get("time", range_v.x)), range_v.x, range_v.y)
	var poster: float = range_v.x
	for m: Variant in doc.media:
		if m.kind == "sequence" and m.sequence_id == seq.id and m.poster_time > 0.0:
			poster = clampf(m.poster_time, range_v.x, range_v.y)
	return poster


func _unsettled() -> bool:
	if SoundEnvelopes.pending_for(compositor):
		return true
	if PictureSeries.pending_for(compositor):
		return true
	if compositor.has_method("unsettled"):
		return bool(compositor.call("unsettled"))
	var st: Dictionary = compositor.call("frame_state")
	return int(st.get("pending", 0)) > 0 or int(st.get("approx_layers", 0)) > 0


func _late_text() -> String:
	if compositor != null and compositor.has_method("unsettled_text"):
		var text: String = String(compositor.call("unsettled_text"))
		if not text.is_empty():
			return text
	var st: Dictionary = compositor.call("frame_state")
	return str(int(st.get("pending", 0))) + " with no picture and " + str(int(st.get("approx_layers", 0))) + " still rough"


func settle_timeout_ms() -> int:
	var prefs: Node = _autoload("Prefs")
	if prefs == null or not bool(prefs.call("is_registered", PREF_SETTLE_SECONDS)):
		return int(SETTLE_SECONDS * 1000.0)
	return int(maxf(float(prefs.call("get_value", PREF_SETTLE_SECONDS)), 1.0) * 1000.0)


func _settle(t: float) -> bool:
	compositor.call("render_time", t, true)
	if not _unsettled():
		return true
	var limit: int = settle_timeout_ms()
	var t0: int = Time.get_ticks_msec()
	while _unsettled():
		if cancel_requested:
			return false
		if Time.get_ticks_msec() - t0 > limit:
			late_frames += 1
			late_text = _late_text()
			return false
		await _yield_frame()
		settle_waits += 1
		compositor.call("render_time", t, true)
	return true


func editor_budget_ms() -> int:
	var prefs: Node = _autoload("Prefs")
	if prefs == null or not bool(prefs.call("is_registered", PREF_BUDGET_MS)):
		return BUDGET_MS
	return clampi(int(prefs.call("get_value", PREF_BUDGET_MS)), BUDGET_MIN_MS, BUDGET_MAX_MS)


func _read_png_result(id: int) -> Dictionary:
	if _bridge == null or id < 0 or not _bridge.has_method("export_result"):
		return {}
	var raw: Variant = _bridge.call("export_result", id)
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func png_verify() -> bool:
	var prefs: Node = _autoload("Prefs")
	if prefs == null or not bool(prefs.call("is_registered", PREF_PNG_VERIFY)):
		return PNG_VERIFY
	return bool(prefs.call("get_value", PREF_PNG_VERIFY))


static func png_check_line(result: Dictionary) -> String:
	if not bool(result.get("known", false)) or not bool(result.get("png_guard", false)):
		return ""
	var checked: int = int(result.get("png_checked", 0))
	if checked <= 0:
		return ""
	var fixed: int = int(result.get("png_reencoded", 0))
	var bad: int = int(result.get("png_failed", 0))
	var line: String = "PNG check: %d %s checked" % [checked, "frame" if checked == 1 else "frames"]
	if fixed > 0:
		line += ", %d written again because the zlib checksum did not match" % fixed
	if bad > 0:
		var frames: Array = result.get("png_failed_frames", []) as Array
		line += ", %d still wrong after %d more tries and written as %s" % [bad, PNG_RETRIES, "it is" if bad == 1 else "they are"]
		if not frames.is_empty():
			var names: PackedStringArray = PackedStringArray()
			for f: Variant in frames:
				names.append(str(int(f)))
			line += " (frame " + ", ".join(names) + ")"
	if fixed == 0 and bad == 0:
		line += ", none needed writing again"
	return line + "."


static func idle_frames_for(work_ms: int, budget_ms: int, cap: int) -> int:
	if cap < 1:
		return 1
	if budget_ms < BUDGET_MIN_MS:
		budget_ms = BUDGET_MIN_MS
	if work_ms <= budget_ms:
		return 1
	return clampi(int(ceil(float(work_ms) / float(budget_ms))) - 1, 1, cap)


func _yield_frame() -> void:
	await get_tree().process_frame
	_since_yield_ms = Time.get_ticks_msec()


func blocked_ms() -> int:
	if _since_yield_ms <= 0:
		return 0
	return Time.get_ticks_msec() - _since_yield_ms


func _breathe(work_ms: int) -> void:
	var want: int = idle_frames_for(work_ms, editor_budget_ms(), MAX_IDLE_FRAMES)
	var t0: int = Time.get_ticks_msec()
	for _i: int in want:
		await _yield_frame()
		idle_frames += 1
		if cancel_requested:
			break
	ms_idle += Time.get_ticks_msec() - t0


static func offload_wanted(src_w: int, src_h: int, dst_w: int, dst_h: int) -> bool:
	if src_w == dst_w and src_h == dst_h:
		return false
	return maxi(src_w * src_h, dst_w * dst_h) >= OFFLOAD_PIXELS


static func shape_frame(img: Image, w: int, h: int) -> void:
	if img.get_width() != w or img.get_height() != h:
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)


func _shape_on_worker(img: Image, w: int, h: int, out: Array) -> void:
	shape_frame(img, w, h)
	out[0] = img.get_data()


func _frame_bytes(img: Image, w: int, h: int) -> PackedByteArray:
	if img.get_width() == w and img.get_height() == h and img.get_format() == Image.FORMAT_RGBA8:
		return img.get_data()
	if not offload_wanted(img.get_width(), img.get_height(), w, h):
		shape_frame(img, w, h)
		return img.get_data()
	var out: Array = [PackedByteArray()]
	var task: int = WorkerThreadPool.add_task(_shape_on_worker.bind(img, w, h, out), true, "export frame")
	while not WorkerThreadPool.is_task_completed(task):
		await _yield_frame()
	WorkerThreadPool.wait_for_task_completion(task)
	offloaded_frames += 1
	return out[0]


func _render_exact(t: float) -> Image:
	_keep_compositor()
	var t0: int = Time.get_ticks_msec()
	var ready: bool = await _settle(t)
	ms_settle += Time.get_ticks_msec() - t0
	if not ready:
		return null
	compositor.call("render_time", t, true)
	var t1: int = Time.get_ticks_msec()
	var img: Image = await compositor.call("read_frame")
	ms_read += Time.get_ticks_msec() - t1
	return img


class ReadyFrame extends RefCounted:
	var done: bool = true
	var async: bool = false
	var image: Image = null

	func result() -> Image:
		return image


func _render_exact_begin(t: float) -> Object:
	_keep_compositor()
	var t0: int = Time.get_ticks_msec()
	var ready: bool = await _settle(t)
	ms_settle += Time.get_ticks_msec() - t0
	if not ready:
		return null
	compositor.call("render_time", t, true)
	var t1: int = Time.get_ticks_msec()
	var rb: Object = null
	if compositor.has_method("read_frame_begin"):
		rb = await compositor.call("read_frame_begin")
	else:
		var img: Image = await compositor.call("read_frame")
		if img != null:
			var f: ReadyFrame = ReadyFrame.new()
			f.image = img
			rb = f
	ms_read += Time.get_ticks_msec() - t1
	return rb


func _deliver(rb: Object, w: int, h: int) -> int:
	var t0: int = Time.get_ticks_msec()
	while not bool(rb.get("done")):
		if Time.get_ticks_msec() - t0 > READBACK_TIMEOUT_MS:
			break
		await _yield_frame()
	ms_read += Time.get_ticks_msec() - t0
	var img: Image = rb.call("result") if bool(rb.get("done")) else null
	if img == null:
		return DELIVER_READ_FAILED
	if bool(rb.get("async")):
		async_frames += 1
	var tc: int = Time.get_ticks_msec()
	var bytes: PackedByteArray = await _frame_bytes(img, w, h)
	ms_convert += Time.get_ticks_msec() - tc
	var tp: int = Time.get_ticks_msec()
	while not bool(_bridge.call("export_push_frame", job_id, bytes, w, h)):
		if cancel_requested or _done.has("ok"):
			break
		if Time.get_ticks_msec() - tp > PUSH_TIMEOUT_MS:
			break
		await _yield_frame()
	ms_push += Time.get_ticks_msec() - tp
	if _done.has("ok") and not bool(_done["ok"]):
		return DELIVER_STOPPED
	frames_done += 1
	var frac: float = float(frames_done) / float(maxi(total_frames, 1))
	progress.emit(frac, plan_text)
	if _jobs != null and local_job_id >= 0:
		_jobs.update_local(local_job_id, frac)
	return DELIVER_OK


func start() -> void:
	if state != "idle":
		return
	state = "running"
	if _bridge == null or not bool(_bridge.get("available")):
		_fail("the native engine (purrcore) is missing, so nothing can be encoded", PackedStringArray(["Reinstall the app so the purrcore extension is present", "Check the Events panel for the load error at startup"]))
		return
	if seq == null or doc == null:
		_fail("no sequence is open")
		return
	if compositor == null or not compositor.has_method("read_frame"):
		_fail("the compositor is not running")
		return
	if not bool(compositor.call("has_gpu")):
		_fail("there is no GPU renderer in this process, frames cannot be read back", PackedStringArray(["Run the app with a display and a graphics driver", "Headless runs cannot render pictures"]))
		return
	var range_v: Vector2 = ExportPresets.resolve_range(settings, seq)
	var fps: float = ExportPresets.resolve_fps(settings, seq.fps)
	var duration: float = range_v.y - range_v.x
	started_ms = Time.get_ticks_msec()
	job_fps = fps
	_free_the_clock()
	_hold_export_reads(true)
	_decide_transparency()
	_hold_backdrop(backdrop_wanted(_backdrop_pref(), transparent))
	if not _view_hold():
		return
	_hold_sequence()
	duration = _view_duration(range_v, duration)
	if duration <= 0.0 or fps <= 0.0:
		_fail("the range is empty")
		return
	var probing: bool = not probe_times.is_empty()
	job_spans = ExportPresets.span_list(settings, seq) if (not probing and view_run == null and ExportPresets.spans_chosen(settings)) else PackedVector2Array()
	if not probing and view_run == null:
		skip_spans = load(REGION_APPLY).call("export_spans", doc, seq, job_spans if not job_spans.is_empty() else PackedVector2Array([range_v]), fps)
		if not skip_spans.is_empty():
			job_spans = skip_spans
	if not job_spans.is_empty():
		duration = ExportPresets.spans_seconds(job_spans)
	output_path =_temp_path("_probe." + String(ExportPresets.container_by_id(containers, String(settings.get("container", "mp4"))).get("ext", "mp4"))) if probing else ExportPresets.output_path(settings, seq, containers)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var paths: Dictionary = {"output": output_path, "pcm": "", "thumbnail": ""}
	var container: Dictionary = ExportPresets.container_by_id(containers, String(settings.get("container", "mp4")))
	var audio_settings: Dictionary = settings.get("audio", {})
	var wants_audio: bool = bool(audio_settings.get("enabled", true)) and not (container.get("audio_codecs", []) as Array).is_empty()
	if probing:
		wants_audio = false
	if _jobs != null and not probing:
		local_job_id = _jobs.add_local("Export " + output_path.get_file(), "export")
	if wants_audio:
		ListenMute.hold()
		var graph: Dictionary = AudioGraph.build(doc, seq, media_handles)
		var groups: Array = audio_groups(seq, String(audio_settings.get("layout", "mix")), String(audio_settings.get("groups", "")))
		var rendered: Array = []
		for g: Dictionary in groups:
			var pcm: String = _temp_path("_" + str(rendered.size()) + ".wav")
			_bridge.call("set_audio_graph", graph_for_group(graph, g))
			var ok: bool = _render_audio_range(range_v, pcm, int(audio_settings.get("sample_rate", 48000)), int(audio_settings.get("channels", 2)))
			if ok and FileAccess.file_exists(pcm):
				rendered.append({"path": pcm, "title": String(g.get("title", ""))})
			elif _events != null:
				_events.warn("An audio stream could not be rendered: " + String(g.get("title", "mix")), pcm)
		if rendered.is_empty():
			if _events != null:
				_events.warn("The audio mix could not be rendered, the export continues without sound", "")
			wants_audio = false
		else:
			paths["pcm"] = String(rendered[0]["path"])
			paths["pcm_paths"] = rendered
		ListenMute.release()
		ViewExport.restore_playback_graph(doc, _view_seq(), media_handles, _bridge)
	var audio_only: bool = ExportPresets.is_audio_only(container)
	if not audio_only:
		await load("res://engine/purrframes/purrframes.gd").before_export(self, doc, _view_seq(), range_v)
	var thumb: Dictionary = settings.get("thumbnail", {})
	if not audio_only and not probing and (bool(thumb.get("embed", true)) or bool(thumb.get("sidecar", false))):
		var tt: float = _view_thumb(_thumbnail_time(range_v))
		var timg: Image = await _render_exact(tt)
		if timg != null:
			timg.convert(Image.FORMAT_RGBA8)
			var tpath: String = _temp_path("_thumb.png")
			if timg.save_png(tpath) == OK:
				paths["thumbnail"] = tpath
			if bool(thumb.get("sidecar", false)):
				timg.save_png(output_path.get_basename().replace("_%05d", "") + "_thumbnail.png")
	paths["alpha"] = transparent
	paths["png_verify"] = png_verify()
	job = ExportPresets.build_job(settings, seq, encoders, containers, paths)
	if view_run != null:
		view_run.call("fix_job", job, fps, range_v, bool(settings.get("chapters_from_markers", true)))
	if not skip_spans.is_empty():
		job["total_frames"] = ExportPresets.spans_frames(skip_spans, fps)
		job["chapters"] = load(REGION_APPLY).call("chapters_through", job.get("chapters", []), skip_spans, range_v.x)
	if not wants_audio:
		job["audio"]["codec"] = ""
		job["audio"]["pcm_path"] = ""
		job["audio"]["pcm_paths"] = []
	if not bool(thumb.get("embed", true)) or probing:
		job["thumbnail"]["path"] = ""
	total_frames = int(job["total_frames"])
	if audio_only:
		total_frames = 0
	if probing:
		total_frames = probe_times.size()
		job["total_frames"] = total_frames
		job["thumbnail"]["path"] = ""
	if not _bridge.is_connected("job_progress", _on_job_progress):
		_bridge.connect("job_progress", _on_job_progress)
	if not _bridge.is_connected("job_done", _on_job_done):
		_bridge.connect("job_done", _on_job_done)
	job_id = int(_bridge.call("export_begin", job))
	if job_id < 0:
		_fail("the engine refused the export job", PackedStringArray(["Check that the folder exists and is writable", "Pick another container or codec"]))
		return
	var prev_quality: int = int(compositor.get("quality"))
	compositor.call("set_quality", 0)
	var w: int = int(job["width"])
	var h: int = int(job["height"])
	var aborted: bool = false
	_since_yield_ms = Time.get_ticks_msec()
	if total_frames > 0:
		_info("Export running in the background, the editor stays usable", output_path)
	var inflight: Array[Object] = []
	var stopped: bool = false
	var unread: int = -1
	for n: int in total_frames:
		if cancel_requested:
			aborted = true
			break
		var t: float = _frame_time(n, range_v, fps)
		var rb: Object = await _render_exact_begin(t)
		if rb == null and cancel_requested:
			aborted = true
			break
		if rb == null:
			_bridge.call("export_abort", job_id)
			compositor.call("set_quality", prev_quality)
			if late_frames > 0:
				_fail("frame %d of %d was still not the real picture after %d s, so nothing was written for it: %s" % [n + 1, total_frames, int(settle_timeout_ms() / 1000), late_text], PackedStringArray([
					"That clip's file may be on a drive that cannot keep up; try again or make a proxy of it",
					"If the file is missing or broken, relink or replace it and export again",
					"Settings has export.settle_seconds if a slow drive needs longer",
				]))
			else:
				_fail("frame %d could not be read back from the renderer" % n)
			return
		inflight.append(rb)
		while inflight.size() > READBACK_DEPTH:
			var code: int = await _deliver(inflight.pop_front(), w, h)
			if code == DELIVER_READ_FAILED:
				unread = frames_done
				break
			if code == DELIVER_STOPPED:
				stopped = true
				break
		if stopped or unread >= 0:
			break
		await _breathe(blocked_ms())
	while not aborted and not stopped and unread < 0 and not inflight.is_empty():
		if cancel_requested:
			aborted = true
			break
		var last_code: int = await _deliver(inflight.pop_front(), w, h)
		if last_code == DELIVER_READ_FAILED:
			unread = frames_done
		elif last_code == DELIVER_STOPPED:
			stopped = true
	inflight.clear()
	if unread >= 0 and not aborted:
		_bridge.call("export_abort", job_id)
		compositor.call("set_quality", prev_quality)
		_fail("frame %d could not be read back from the renderer" % unread)
		return
	compositor.call("set_quality", prev_quality)
	_restore_the_clock()
	_release_backdrop()
	if aborted:
		_bridge.call("export_abort", job_id)
		state = "cancelled"
		result_message = "cancelled"
		if _jobs != null and local_job_id >= 0:
			_jobs.done_local(local_job_id, false)
		_info("Export cancelled", output_path)
		_announce(false, true, "You stopped this export, so the file is not finished.")
		finished.emit(false, "cancelled")
		return
	_bridge.call("export_finish", job_id)
	var t1: int = Time.get_ticks_msec()
	while not _done.has("ok"):
		if Time.get_ticks_msec() - t1 > DONE_TIMEOUT_MS:
			break
		await get_tree().process_frame
	var ok: bool = bool(_done.get("ok", false))
	result_message = String(_done.get("message", "timed out waiting for the encoder"))
	png_result = _read_png_result(job_id)
	var png_line: String = png_check_line(png_result)
	if not png_line.is_empty():
		result_message += " " + png_line
	state = "done" if ok else "failed"
	if _jobs != null and local_job_id >= 0:
		_jobs.done_local(local_job_id, ok)
	if ok and settle_waits > 0 and total_frames > 0:
		var per: float = float(settle_waits) / float(total_frames)
		if per >= 1.0:
			result_message += " Frames waited on the media " + String.num(per, 1) + " times each on average, so the drive was holding the export up."
	if ok:
		var sess: Node = get_tree().root.get_node_or_null("/root/Session") if is_inside_tree() else null
		if sess != null and sess.get("doc") != null:
			load("res://host/edit_clock.gd").call("note_export", sess.get("doc"), float(Time.get_ticks_msec() - started_ms) / 1000.0)
		if share_to_clipboard and ExportPresets.is_share_fit(settings):
			clipboard_copied = copy_file_to_clipboard(output_path)
		if clipboard_copied:
			result_message = "The file is on the clipboard, paste it into Discord or a chat. " + result_message
			if _events != null:
				_events.call("notice", "Export finished and copied to the clipboard", "Paste it into Discord or a chat: " + output_path.get_file(), [], 5.0)
		_info("Export finished: " + output_path, result_message)
	else:
		if _events != null:
			_events.error("Export failed: " + result_message, output_path, PackedStringArray(["The file may be open in another program", "The folder may be on a drive that is full"]))
	_announce(ok, false, result_message)
	finished.emit(ok, result_message)


func stats() -> Dictionary:
	var out: Dictionary = {"frames": frames_done, "total": total_frames, "rate": 0.0, "times_real": 0.0, "left": -1.0, "bytes": 0, "waits": settle_waits, "state": state}
	out["ms_settle"] = ms_settle
	out["ms_read"] = ms_read
	out["ms_convert"] = ms_convert
	out["ms_push"] = ms_push
	out["ms_idle"] = ms_idle
	out["idle_frames"] = idle_frames
	out["offloaded"] = offloaded_frames
	out["async_reads"] = async_frames
	var ms: int = Time.get_ticks_msec() - started_ms
	if started_ms > 0 and ms > 250 and frames_done > 0:
		var rate: float = float(frames_done) * 1000.0 / float(ms)
		out["rate"] = rate
		if job_fps > 0.0:
			out["times_real"] = rate / job_fps
		if total_frames > frames_done and rate > 0.0:
			out["left"] = float(total_frames - frames_done) / rate
	if not output_path.is_empty() and FileAccess.file_exists(output_path):
		var f: FileAccess = FileAccess.open(output_path, FileAccess.READ)
		if f != null:
			out["bytes"] = int(f.get_length())
			f.close()
	return out


static func stats_text(st: Dictionary) -> String:
	var total: int = int(st.get("total", 0))
	var done: int = int(st.get("frames", 0))
	var bits: PackedStringArray = PackedStringArray()
	if total > 0:
		bits.append("frame " + str(done) + " of " + str(total))
	var rate: float = float(st.get("rate", 0.0))
	if rate > 0.0:
		var speed: String = String.num(rate, 0) + " frames a second"
		var times: float = float(st.get("times_real", 0.0))
		if times > 0.0:
			speed += ", " + String.num(times, 1) + " times real time"
		bits.append(speed)
	var left: float = float(st.get("left", -1.0))
	if left >= 0.0:
		bits.append("about " + _short_time(left) + " left")
	var bytes_v: int = int(st.get("bytes", 0))
	if bytes_v > 0:
		bits.append(ExportPresets.fmt_mb(float(bytes_v) / (1024.0 * 1024.0)) + " written")
	return ", ".join(bits)


static func _short_time(seconds: float) -> String:
	if seconds < 60.0:
		return str(int(round(seconds))) + " s"
	if seconds < 3600.0:
		return str(int(seconds / 60.0)) + " min " + str(int(round(fmod(seconds, 60.0)))) + " s"
	return str(int(seconds / 3600.0)) + " h " + str(int(fmod(seconds, 3600.0) / 60.0)) + " min"


func _view_setup() -> void:
	view_run = ViewExport.for_job(settings, seq)
	if view_run != null:
		seq = view_run.get("forced")


func _view_seq() -> Sequence:
	return view_run.get("original") if view_run != null else seq


func _view_hold() -> bool:
	if view_run == null:
		return true
	var why: String = String(view_run.get("error"))
	if not why.is_empty():
		_fail(why, PackedStringArray(["Pick another range", "Untick that view in the Pair View group"]))
		return false
	view_run.call("hold", compositor, doc)
	return true


func _live_sequence() -> Sequence:
	var s: Node = _autoload("Session")
	if s == null or s.get("doc") != doc:
		return null
	return s.call("seq")


func _hold_sequence() -> void:
	if _seq_held or compositor == null or not compositor.has_method("set_sequence") or seq == null:
		return
	_seq_held = true
	compositor_holders += 1
	if view_run != null:
		return
	_seq_prev = compositor.get("seq")
	_keep_compositor()


func _keep_compositor() -> void:
	if compositor == null or not is_instance_valid(compositor) or not compositor.has_method("set_sequence"):
		return
	if seq != null and compositor.get("seq") != seq:
		compositor.call("set_sequence", seq, doc)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_hold_export_reads(false)
	if what == NOTIFICATION_PREDELETE and _seq_held:
		_seq_held = false
		compositor_holders = maxi(compositor_holders - 1, 0)


func _release_sequence() -> void:
	if not _seq_held:
		return
	_seq_held = false
	compositor_holders = maxi(compositor_holders - 1, 0)
	if compositor == null or not is_instance_valid(compositor) or not compositor.has_method("set_sequence"):
		return
	var back: Sequence = _live_sequence()
	if back == null:
		back = _seq_prev
	if back != null and compositor.get("seq") != back:
		compositor.call("set_sequence", back, doc)


func _view_release() -> void:
	if view_run != null:
		view_run.call("release", doc)


func _view_duration(range_v: Vector2, fallback: float) -> float:
	if view_run == null:
		return fallback
	return float(view_run.call("duration", range_v))


func _view_thumb(t: float) -> float:
	if view_run == null:
		return t
	return float(view_run.call("thumb_time", t))


func _frame_time(n: int, range_v: Vector2, fps: float) -> float:
	if not probe_times.is_empty():
		return probe_times[clampi(n, 0, probe_times.size() - 1)]
	if not job_spans.is_empty():
		return ExportPresets.span_frame_time(n, job_spans, fps)
	if view_run == null:
		return range_v.x + float(n) / fps
	return float(view_run.call("frame_time", n, range_v, fps))


func _render_audio_range(range_v: Vector2, pcm: String, rate: int, channels: int) -> bool:
	if not job_spans.is_empty():
		return _render_audio_spans(pcm, rate, channels)
	if view_run == null:
		return bool(_bridge.call("render_audio", range_v.x, range_v.y, pcm, rate, channels))
	return bool(view_run.call("render_audio", _bridge, range_v, pcm, rate, channels))


func _render_audio_spans(pcm: String, rate: int, channels: int) -> bool:
	var pieces: PackedStringArray = PackedStringArray()
	for i: int in job_spans.size():
		var v: Vector2 = job_spans[i]
		var piece: String = _temp_path("_span" + str(i) + ".wav")
		if not bool(_bridge.call("render_audio", v.x, v.y, piece, rate, channels)):
			_forget_pieces(pieces)
			return false
		pieces.append(piece)
	var joined: Dictionary = WavJoin.join(pieces, pcm)
	_forget_pieces(pieces)
	if not bool(joined["ok"]) and _events != null:
		_events.warn("The sound of the chosen parts could not be joined", String(joined["why"]))
	return bool(joined["ok"])


func _forget_pieces(paths: PackedStringArray) -> void:
	for p: String in paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

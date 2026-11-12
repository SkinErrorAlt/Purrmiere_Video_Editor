extends Node

signal media_ready(h: int, info: Dictionary)
signal media_failed(h: int, why: String)
signal frame_ready(h: int)
signal snapshot_ready(h: int, seconds: float, width: int, image: Image)
signal job_progress(id: int, progress: float, message: String)
signal job_done(id: int, ok: bool, message: String)
signal audio_edit_done(result: Dictionary)
signal audio_stats_ready(result: Dictionary)
signal strip_ready(h: int)
signal fine_peaks_ready(h: int, stream: int)
signal peaks_progress(h: int, stream: int)

const NATIVE_CLASS := "Purr"
const SIGNAL_NAMES: PackedStringArray = ["media_ready", "media_failed", "frame_ready", "snapshot_ready", "job_progress", "job_done", "audio_edit_done", "audio_stats_ready", "strip_ready", "fine_peaks_ready", "peaks_progress"]
const FINE_NONE := 0
const FINE_PENDING := 1
const FINE_READY := 2

var available: bool = false
var reason: String = "The purrcore extension did not load"
var _native: Object = null


func _ready() -> void:
	_connect_native()
	set_process(available)
	if available:
		set_cache_dir(Prefs.cache_dir())


func set_cache_dir(path: String) -> void:
	_call("set_cache_dir", [path], null)


func cache_dir() -> String:
	return String(_call("cache_dir", [], ""))


func clear_cache(h: int) -> int:
	return int(_call("clear_cache", [h], 0))


func purge_cache() -> int:
	return int(_call("purge_cache", [], 0))


func set_quality(h: int, quality: int) -> void:
	_call("set_quality", [h, quality], null)


func set_full_quality(on: bool) -> void:
	_call("set_full_quality", [on], null)


func full_quality() -> bool:
	return bool(_call("full_quality", [], false))


func set_scrub_memory(megabytes: int) -> void:
	_call("set_scrub_memory", [megabytes], null)


func scrub_memory() -> Dictionary:
	var d: Variant = _call("scrub_memory", [], {})
	return d if typeof(d) == TYPE_DICTIONARY else {}


func audio_edit(job: Dictionary) -> int:
	return int(_call("audio_edit", [job], -1))


func audio_stats(job: Dictionary) -> int:
	return int(_call("audio_stats", [job], -1))


func audio_filters() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var raw: Variant = _call("audio_filters", [], [])
	if raw is Array:
		for v: Variant in raw:
			out.append(String(v))
	return out


func audio_filter_help(name_: String) -> String:
	return String(_call("audio_filter_help", [name_], ""))


func has_audio_editing() -> bool:
	return available and _native != null and _native.has_method("audio_edit")


func _connect_native() -> void:
	if not ClassDB.class_exists(NATIVE_CLASS):
		available = false
		return
	if Engine.has_singleton(NATIVE_CLASS):
		_native = Engine.get_singleton(NATIVE_CLASS)
	elif ClassDB.can_instantiate(NATIVE_CLASS):
		_native = ClassDB.instantiate(NATIVE_CLASS)
	if _native == null:
		available = false
		reason = "The Purr class exists but could not be instantiated"
		return
	available = true
	reason = ""
	for sig: String in SIGNAL_NAMES:
		if _native.has_signal(sig):
			_native.connect(sig, Callable(self, "_relay_" + sig))


func _relay_media_ready(h: int, info: Dictionary) -> void:
	media_ready.emit(h, _info_defaults(info))


func _relay_media_failed(h: int, why: String) -> void:
	media_failed.emit(h, why)


func _relay_frame_ready(h: int) -> void:
	frame_ready.emit(h)


func _relay_snapshot_ready(h: int, seconds: float, width: int, image: Variant) -> void:
	snapshot_ready.emit(h, seconds, width, image if image is Image else null)


func _relay_job_progress(id: int, progress: float, message: String = "") -> void:
	job_progress.emit(id, progress, message)


func _relay_job_done(id: int, ok: bool, message: String) -> void:
	job_done.emit(id, ok, message)


func _relay_audio_edit_done(result: Dictionary) -> void:
	audio_edit_done.emit(result)


func _relay_audio_stats_ready(result: Dictionary) -> void:
	audio_stats_ready.emit(result)


func _relay_strip_ready(h: int) -> void:
	strip_ready.emit(h)


func _relay_fine_peaks_ready(h: int, stream: int) -> void:
	fine_peaks_ready.emit(h, stream)


func _relay_peaks_progress(h: int, stream: int) -> void:
	peaks_progress.emit(h, stream)


func _process(_dt: float) -> void:
	if not available or _native == null:
		return
	if not _native.has_method("poll"):
		return
	var out: Variant = _native.call("poll")
	if typeof(out) != TYPE_ARRAY:
		return
	for ev: Variant in out:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		_dispatch_event(ev)


func _dispatch_event(ev: Dictionary) -> void:
	var kind: String = String(ev.get("kind", ""))
	if kind == "media_ready":
		media_ready.emit(int(ev.get("h", -1)), _info_defaults(ev.get("info", {})))
	elif kind == "media_failed":
		media_failed.emit(int(ev.get("h", -1)), String(ev.get("why", "")))
	elif kind == "frame_ready":
		frame_ready.emit(int(ev.get("h", -1)))
	elif kind == "job_progress":
		job_progress.emit(int(ev.get("id", -1)), float(ev.get("progress", 0.0)), String(ev.get("message", "")))
	elif kind == "job_done":
		job_done.emit(int(ev.get("id", -1)), bool(ev.get("ok", false)), String(ev.get("message", "")))


func _call(method: String, args: Array, empty: Variant) -> Variant:
	if not available or _native == null or not _native.has_method(method):
		return empty
	return _native.callv(method, args)


func _info_defaults(d: Variant) -> Dictionary:
	var src: Dictionary = d if typeof(d) == TYPE_DICTIONARY else {}
	return {
		"ok": bool(src.get("ok", false)),
		"path": String(src.get("path", "")),
		"duration": float(src.get("duration", 0.0)),
		"fps": float(src.get("fps", 0.0)),
		"width": int(src.get("width", 0)),
		"height": int(src.get("height", 0)),
		"rotation": int(src.get("rotation", 0)),
		"coded_width": int(src.get("coded_width", src.get("width", 0))),
		"coded_height": int(src.get("coded_height", src.get("height", 0))),
		"creation_time": float(src.get("creation_time", 0.0)),
		"creation_found": bool(src.get("creation_found", false)),
		"creation_key": String(src.get("creation_key", "")),
		"has_video": bool(src.get("has_video", false)),
		"has_audio": bool(src.get("has_audio", false)),
		"audio_streams": src.get("audio_streams", []),
		"index_state": String(src.get("index_state", "none")),
		"strip_state": String(src.get("strip_state", "none")),
		"hw": bool(src.get("hw", false)),
		"codec": String(src.get("codec", "")),
		"container": String(src.get("container", "")),
		"scrub_near": bool(src.get("scrub_near", false)),
		"scrub": src.get("scrub", {}) if src.get("scrub", {}) is Dictionary else {},
		"cache_bytes": int(src.get("cache_bytes", 0)),
		"export_ahead": int(src.get("export_ahead", 0)),
		"export_ahead_seeks": int(src.get("export_ahead_seeks", 0)),
		"play_quality": int(src.get("play_quality", 0)),
		"full_quality": bool(src.get("full_quality", false)),
		"loop_filter_skips": int(src.get("loop_filter_skips", 0)),
		"hw_type": String(src.get("hw_type", "none")),
		"main": src.get("main", {}) if src.get("main", {}) is Dictionary else {},
	}


func _present_defaults(d: Variant) -> Dictionary:
	var src: Dictionary = d if typeof(d) == TYPE_DICTIONARY else {}
	return {
		"state": String(src.get("state", "none")),
		"tier": int(src.get("tier", 0)),
		"y": src.get("y", RID()),
		"uv": src.get("uv", RID()),
		"width": int(src.get("width", 0)),
		"height": int(src.get("height", 0)),
		"rgb": bool(src.get("rgb", false)),
		"colorspace": String(src.get("colorspace", "bt709")),
		"full_range": bool(src.get("full_range", false)),
		"pts": float(src.get("pts", 0.0)),
		"rotation": int(src.get("rotation", 0)),
	}


func api_version() -> int:
	return int(_call("api_version", [], 0))


func open_media(path: String, options: Dictionary = {}) -> int:
	return int(_call("open_media", [path, options], -1))


func close_media(h: int) -> void:
	_call("close_media", [h], null)


func media_info(h: int) -> Dictionary:
	return _info_defaults(_call("media_info", [h], {}))


func request_frame(h: int, seconds: float, quality: int, hint: int) -> void:
	_call("request_frame", [h, seconds, quality, hint], null)


func present(h: int) -> Dictionary:
	return _present_defaults(_call("present", [h], {}))


func can_tap() -> bool:
	return available and _native != null and _native.has_method("present_at") and _native.has_method("set_play_plan")


func present_at(h: int, seconds: float, slot: int) -> Dictionary:
	return _present_defaults(_call("present_at", [h, seconds, slot], {}))


func set_play_plan(h: int, times: PackedFloat64Array) -> void:
	_call("set_play_plan", [h, times], null)


func strip_frame(h: int, seconds: float) -> RID:
	var out: Variant = _call("strip_frame", [h, seconds], RID())
	if typeof(out) == TYPE_RID:
		return out
	return RID()


func request_proxy(h: int, seconds: float, priority: int) -> void:
	_call("request_proxy", [h, seconds, priority], null)


func set_rate(rate: float) -> void:
	_call("set_rate", [rate], null)


func set_playing(on: bool) -> void:
	_call("set_playing", [on], null)


func set_time(seconds: float, mode: int) -> void:
	_call("set_time", [seconds, mode], null)


func scrub(seconds: float, window: float = 0.08) -> void:
	_call("scrub", [seconds, window], null)


func set_output_latency(seconds: float) -> void:
	_call("set_output_latency", [seconds], null)


var graph_pushes: int = 0
var graph_clips: int = 0


func clock_time() -> float:
	return float(_call("clock_time", [], 0.0))


func set_audio_graph(graph: Dictionary) -> void:
	graph_pushes += 1
	graph_clips = 0
	for t: Variant in graph.get("tracks", []):
		graph_clips += (t as Dictionary).get("clips", []).size()
	var session: Node = get_node_or_null("/root/Session")
	var seq: Variant = session.call("seq") if session != null and session.has_method("seq") else null
	_call("set_audio_graph", [load("res://engine/listen_mute.gd").call("apply", graph, seq)], null)


func render_audio(from: float, to: float, wav_path: String, sample_rate: int, channels: int) -> bool:
	return bool(_call("render_audio", [from, to, wav_path, sample_rate, channels], false))


func has_audio_probe_live() -> bool:
	return available and _native != null and _native.has_method("audio_probe_live")


func audio_probe_live(from: float, seconds: float, sample_rate: int, pace: bool) -> Dictionary:
	return _call("audio_probe_live", [from, seconds, sample_rate, pace], {}) as Dictionary


func patch_audio_param(item_id: String, key: String, anim: Dictionary) -> void:
	_call("patch_audio_param", [item_id, key, anim], null)


func has_view_gains() -> bool:
	return available and _native != null and _native.has_method("set_view_gains")


func set_view_gains(gains: Dictionary) -> int:
	if not has_view_gains():
		return -1
	return int(_call("set_view_gains", [gains], 0))


func audio_graph_stats() -> Dictionary:
	var raw: Variant = _call("audio_graph_stats", [], {})
	var src: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	return {"known": not src.is_empty(), "adopts": int(src.get("adopts", 0)), "value_swaps": int(src.get("value_swaps", 0)), "gain_patches": int(src.get("gain_patches", 0)), "taken_at": float(src.get("taken_at", -1.0)), "taken_frames": int(src.get("taken_frames", 0)), "frames_mixed": int(src.get("frames_mixed", 0)), "waiting": bool(src.get("waiting", false)), "readers_live": int(src.get("readers_live", 0)), "readers_pair_max": int(src.get("readers_pair_max", 0)), "readers_pair_peak": int(src.get("readers_pair_peak", 0)), "readers_opened": int(src.get("readers_opened", 0)), "joins": int(src.get("joins", 0)), "join_detail": src.get("join_detail", {})}


func audio_stream() -> AudioStream:
	var out: Variant = _call("audio_stream", [], null)
	if out is AudioStream:
		return out
	return null


func meters() -> PackedFloat32Array:
	var out: Variant = _call("meters", [], PackedFloat32Array())
	if typeof(out) == TYPE_PACKED_FLOAT32_ARRAY:
		return out
	return PackedFloat32Array()


func has_loudness() -> bool:
	return available and _native != null and _native.has_method("loudness")


func loudness() -> Dictionary:
	return loudness_defaults(_call("loudness", [], {}))


func loudness_reset() -> void:
	_call("loudness_reset", [], null)


static func loudness_defaults(d: Variant) -> Dictionary:
	var src: Dictionary = d if typeof(d) == TYPE_DICTIONARY else {}
	return {
		"ok": bool(src.get("ok", false)),
		"momentary": float(src.get("momentary", -200.0)),
		"short_term": float(src.get("short_term", -200.0)),
		"integrated": float(src.get("integrated", -200.0)),
		"true_peak": float(src.get("true_peak", -200.0)),
		"momentary_max": float(src.get("momentary_max", -200.0)),
		"short_term_max": float(src.get("short_term_max", -200.0)),
		"seconds": float(src.get("seconds", 0.0)),
	}


func spectrum(bands: int) -> PackedFloat32Array:
	var out: Variant = _call("spectrum", [bands], PackedFloat32Array())
	if typeof(out) == TYPE_PACKED_FLOAT32_ARRAY:
		return out
	return PackedFloat32Array()


func peaks_request(h: int, stream: int, focus_seconds: float) -> void:
	_call("peaks_request", [h, stream, focus_seconds], null)


func peaks_read(h: int, stream: int, tier: int, from_bucket: int, count: int) -> PackedByteArray:
	var out: Variant = _call("peaks_read", [h, stream, tier, from_bucket, count], PackedByteArray())
	if typeof(out) == TYPE_PACKED_BYTE_ARRAY:
		return out
	return PackedByteArray()


func peaks_coverage(h: int, stream: int) -> PackedByteArray:
	var out: Variant = _call("peaks_coverage", [h, stream], PackedByteArray())
	if typeof(out) == TYPE_PACKED_BYTE_ARRAY:
		return out
	return PackedByteArray()


func peaks_skip(h: int, streams: PackedInt32Array) -> void:
	_call("peaks_skip", [h, streams], null)


func peaks_skipped(h: int) -> PackedInt32Array:
	var out: Variant = _call("peaks_skipped", [h], PackedInt32Array())
	if typeof(out) == TYPE_PACKED_INT32_ARRAY:
		return out
	return PackedInt32Array()


func peaks_set_one_pass(on: bool) -> void:
	_call("peaks_set_one_pass", [on], null)


func peaks_stats() -> Dictionary:
	var out: Variant = _call("peaks_stats", [], {})
	var d: Dictionary = out if typeof(out) == TYPE_DICTIONARY else {}
	return {"opens": int(d.get("opens", 0)), "passes": int(d.get("passes", 0)), "chunks": int(d.get("chunks", 0)), "skipped": int(d.get("skipped", 0)), "one_pass": bool(d.get("one_pass", true))}


func peaks_reset_stats() -> void:
	_call("peaks_reset_stats", [], null)


func peaks_file(h: int, stream: int) -> String:
	return String(_call("peaks_file", [h, stream], ""))


func has_fine_peaks() -> bool:
	return available and _native != null and _native.has_method("peaks_read_fine")


func peaks_request_fine(h: int, stream: int, from_seconds: float, to_seconds: float) -> int:
	return int(_call("peaks_request_fine", [h, stream, from_seconds, to_seconds], FINE_NONE))


func peaks_read_fine(h: int, stream: int, first_bucket: int, count: int, buckets_per_second: float) -> PackedByteArray:
	var out: Variant = _call("peaks_read_fine", [h, stream, first_bucket, count, buckets_per_second], PackedByteArray())
	if typeof(out) == TYPE_PACKED_BYTE_ARRAY:
		return out
	return PackedByteArray()


var _audio_caps: Dictionary = {}


func audio_caps() -> Dictionary:
	if not _audio_caps.is_empty():
		return _audio_caps
	var raw: Variant = _call("audio_caps", [], {})
	var src: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var caps: Dictionary = {"known": not src.is_empty(), "track_feed": bool(src.get("track_feed", false)), "fine_peaks": bool(src.get("fine_peaks", false)), "version": int(src.get("version", 0))}
	if available:
		_audio_caps = caps
	return caps


func has_track_feed() -> bool:
	return bool(audio_caps()["track_feed"])


func jobs() -> Array:
	var out: Variant = _call("jobs", [], [])
	if typeof(out) == TYPE_ARRAY:
		return out
	return []


func cancel_job(id: int) -> void:
	_call("cancel_job", [id], null)


func set_job_budget(percent: int) -> void:
	_call("set_job_budget", [percent], null)


func has_drives() -> bool:
	return available and _native != null and _native.has_method("volumes")


func _volume_defaults(d: Variant) -> Dictionary:
	var src: Dictionary = d if typeof(d) == TYPE_DICTIONARY else {}
	return {
		"root": String(src.get("root", "")),
		"label": String(src.get("label", "")),
		"kind": String(src.get("kind", "unknown")),
		"bus": String(src.get("bus", "unknown")),
		"seek_penalty": bool(src.get("seek_penalty", true)),
		"measured": bool(src.get("measured", false)),
		"measured_limit": int(src.get("measured_limit", 1)),
		"override_limit": int(src.get("override_limit", 0)),
		"limit": int(src.get("limit", 1)),
		"running": int(src.get("running", 0)),
		"running_light": int(src.get("running_light", 0)),
		"served": int(src.get("served", 0)),
		"waits": int(src.get("waits", 0)),
	}


func volumes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Variant = _call("volumes", [], [])
	if typeof(raw) != TYPE_ARRAY:
		return out
	for v: Variant in raw:
		out.append(_volume_defaults(v))
	return out


func volume_for_path(path: String) -> Dictionary:
	return _volume_defaults(_call("volume_for_path", [path], {}))


func set_volume_limit(root: String, limit: int) -> void:
	_call("set_volume_limit", [root, limit], null)


func take_drive_slot(path: String) -> bool:
	return bool(_call("take_drive_slot", [path], true))


func give_drive_slot(path: String) -> void:
	_call("give_drive_slot", [path], null)


func set_volume_keep(root: String, keep: int) -> void:
	_call("set_volume_keep", [root, keep], null)


func remeasure_volumes() -> void:
	_call("remeasure_volumes", [], null)


func set_residency(on: bool) -> void:
	_call("set_residency", [on], null)


func residency() -> Dictionary:
	var src: Variant = _call("residency", [], {})
	var d: Dictionary = src if typeof(src) == TYPE_DICTIONARY else {}
	return {
		"on": bool(d.get("on", false)),
		"open": int(d.get("open", 0)),
		"live": int(d.get("live", 0)),
		"parked_total": int(d.get("parked_total", 0)),
		"media": d.get("media", []) if typeof(d.get("media", [])) == TYPE_ARRAY else [],
	}


func decoder_stats() -> Dictionary:
	var src: Variant = _call("decoder_stats", [], {})
	var d: Dictionary = src if typeof(src) == TYPE_DICTIONARY else {}
	return {
		"known": not d.is_empty(),
		"hw_devices": int(d.get("hw_devices", 0)),
		"hw_device_users": int(d.get("hw_device_users", 0)),
		"hw_device_creates": int(d.get("hw_device_creates", 0)),
		"soft_live": int(d.get("soft_live", 0)),
		"soft_threads_last": int(d.get("soft_threads_last", 0)),
		"hardware_threads": int(d.get("hardware_threads", 0)),
	}


func set_decoder_policy(policy: Dictionary) -> void:
	_call("set_decoder_policy", [policy], null)


func park_media(h: int) -> void:
	_call("park_media", [h], null)


func export_begin(job: Dictionary) -> int:
	return int(_call("export_begin", [job], -1))


func export_push_frame(job_id: int, rgba: PackedByteArray, width: int, height: int) -> bool:
	return bool(_call("export_push_frame", [job_id, rgba, width, height], false))


func export_finish(job_id: int) -> void:
	_call("export_finish", [job_id], null)


func export_abort(job_id: int) -> void:
	_call("export_abort", [job_id], null)


func export_result(job_id: int) -> Dictionary:
	var raw: Variant = _call("export_result", [job_id], {})
	var src: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	return {
		"known": not src.is_empty(),
		"png_guard": bool(src.get("png_guard", false)),
		"png_threads": int(src.get("png_threads", 0)),
		"png_checked": int(src.get("png_checked", 0)),
		"png_reencoded": int(src.get("png_reencoded", 0)),
		"png_failed": int(src.get("png_failed", 0)),
		"png_retries": int(src.get("png_retries", 0)),
		"png_first_reason": String(src.get("png_first_reason", "")),
		"png_failed_frames": src.get("png_failed_frames", []),
	}


func clipcut(job: Dictionary) -> int:
	return int(_call("clipcut", [job], -1))


func request_snapshot(h: int, seconds: float, width: int) -> int:
	return int(_call("request_snapshot", [h, seconds, width], -1))


func has_async_snapshots() -> bool:
	return available and _native != null and _native.has_method("request_snapshot")


func snapshot(h: int, seconds: float, width: int) -> Image:
	var out: Variant = _call("snapshot", [h, seconds, width], null)
	if out is Image:
		return out
	return null


func has_snapshot_run() -> bool:
	return available and _native != null and _native.has_method("snapshot_run")


func snapshot_run(h: int, seconds: PackedFloat64Array, width: int) -> Array:
	var out: Variant = _call("snapshot_run", [h, seconds, width], [])
	return out if out is Array else []


func has_proxy_build() -> bool:
	return available and _native != null and _native.has_method("proxy_build_begin")


func proxy_build_begin(h: int, export_id: int, times: PackedFloat64Array, width: int, height: int) -> int:
	return int(_call("proxy_build_begin", [h, export_id, times, width, height], -1))


func proxy_build_state(id: int) -> Dictionary:
	var raw: Variant = _call("proxy_build_state", [id], {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func proxy_build_cancel(id: int) -> void:
	_call("proxy_build_cancel", [id], null)


func proxy_build_forget(id: int) -> void:
	_call("proxy_build_forget", [id], null)


func encoders() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Variant = _call("encoders", [], [])
	if typeof(raw) != TYPE_ARRAY:
		return out
	for e: Variant in raw:
		if typeof(e) == TYPE_DICTIONARY:
			out.append({"id": String(e.get("id", "")), "label": String(e.get("label", "")), "codec": String(e.get("codec", "")), "hw": bool(e.get("hw", false)), "alpha": bool(e.get("alpha", false)), "containers": e.get("containers", [])})
	return out


func export_caps() -> Dictionary:
	var raw: Variant = _call("export_caps", [], {})
	var src: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var codecs: PackedStringArray = PackedStringArray()
	for c: Variant in src.get("alpha_codecs", []):
		codecs.append(String(c))
	return {"known": not src.is_empty(), "alpha": bool(src.get("alpha", false)), "alpha_codecs": codecs, "premultiplied_input": bool(src.get("premultiplied_input", false)), "version": int(src.get("version", 0))}


func containers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Variant = _call("containers", [], [])
	if typeof(raw) != TYPE_ARRAY:
		return out
	for e: Variant in raw:
		if typeof(e) == TYPE_DICTIONARY:
			out.append({"id": String(e.get("id", "")), "label": String(e.get("label", "")), "ext": String(e.get("ext", "")), "video_codecs": e.get("video_codecs", []), "audio_codecs": e.get("audio_codecs", [])})
	return out


func has_envelopes() -> bool:
	return available and _native != null and _native.has_method("envelope_request")


func envelope_request(path: String, stream: int, bands: PackedFloat64Array, per_second: int) -> int:
	return int(_call("envelope_request", [path, stream, bands, per_second], -1))


func envelope_read(id: int, from_window: int) -> Dictionary:
	var out: Variant = _call("envelope_read", [id, from_window], {})
	var d: Dictionary = out if typeof(out) == TYPE_DICTIONARY else {}
	var values: Variant = d.get("values", PackedFloat32Array())
	return {"ok": bool(d.get("ok", false)), "done": bool(d.get("done", false)), "failed": bool(d.get("failed", d.is_empty())), "error": String(d.get("error", "")), "bands": int(d.get("bands", 0)), "per_second": int(d.get("per_second", 0)), "count": int(d.get("count", 0)), "from": int(d.get("from", 0)), "duration": float(d.get("duration", 0.0)), "from_disk": bool(d.get("from_disk", false)), "values": values if values is PackedFloat32Array else PackedFloat32Array()}


func envelope_forget(id: int) -> void:
	_call("envelope_forget", [id], null)


func envelope_file(path: String, stream: int, bands: PackedFloat64Array, per_second: int) -> String:
	return String(_call("envelope_file", [path, stream, bands, per_second], ""))


func has_pictures() -> bool:
	return available and _native != null and _native.has_method("picture_request")


func picture_request(path: String, per_second: int, width: int, height: int) -> int:
	return int(_call("picture_request", [path, per_second, width, height], -1))


func picture_read(id: int, from_frame: int) -> Dictionary:
	var out: Variant = _call("picture_read", [id, from_frame], {})
	var d: Dictionary = out if typeof(out) == TYPE_DICTIONARY else {}
	var pixels: Variant = d.get("pixels", PackedByteArray())
	return {"ok": bool(d.get("ok", false)), "done": bool(d.get("done", false)), "failed": bool(d.get("failed", d.is_empty())), "error": String(d.get("error", "")), "width": int(d.get("width", 0)), "height": int(d.get("height", 0)), "per_second": int(d.get("per_second", 0)), "count": int(d.get("count", 0)), "from": int(d.get("from", 0)), "duration": float(d.get("duration", 0.0)), "from_disk": bool(d.get("from_disk", false)), "pixels": pixels if pixels is PackedByteArray else PackedByteArray()}


func picture_forget(id: int) -> void:
	_call("picture_forget", [id], null)


func picture_file(path: String, per_second: int, width: int, height: int) -> String:
	return String(_call("picture_file", [path, per_second, width, height], ""))


func picture_measure(pixels: PackedByteArray, width: int, height: int, spec: Dictionary) -> PackedFloat32Array:
	var out: Variant = _call("picture_measure", [pixels, width, height, spec], PackedFloat32Array())
	return out if out is PackedFloat32Array else PackedFloat32Array()


func has_tracking() -> bool:
	return available and _native != null and _native.has_method("track_start")


func track_start(spec: Dictionary) -> int:
	return int(_call("track_start", [spec], -1))


func track_read(id: int, from_frame: int) -> Dictionary:
	var out: Variant = _call("track_read", [id, from_frame], {})
	var d: Dictionary = out if typeof(out) == TYPE_DICTIONARY else {}
	var r: Dictionary = {"ok": bool(d.get("ok", false)), "done": bool(d.get("done", d.is_empty())), "failed": bool(d.get("failed", d.is_empty())), "cancelled": bool(d.get("cancelled", false)), "error": String(d.get("error", "tracking is not available" if d.is_empty() else "")), "fallback": String(d.get("fallback", "")), "count": int(d.get("count", 0)), "from": int(d.get("from", 0))}
	for k: String in ["frame_pts", "frame_start", "frame_end"]:
		var a: Variant = d.get(k, PackedFloat64Array())
		r[k] = a if a is PackedFloat64Array else PackedFloat64Array()
	for k: String in ["frame_flags", "frame_first", "point_id", "point_flags", "crop"]:
		var a: Variant = d.get(k, PackedInt32Array())
		r[k] = a if a is PackedInt32Array else PackedInt32Array()
	for k: String in ["frame_motion", "point_xy", "point_score"]:
		var a: Variant = d.get(k, PackedFloat32Array())
		r[k] = a if a is PackedFloat32Array else PackedFloat32Array()
	for k: String in ["device", "adapter", "decode", "key", "results_hash", "speed_line", "version"]:
		r[k] = String(d.get(k, ""))
	r["from_cache"] = bool(d.get("from_cache", false))
	for k: String in ["width", "height", "decoded_before", "decoded_in", "decoded_after", "packets", "seeks", "births", "lost", "lost_klt", "lost_fb", "lost_ncc", "lost_area", "repeated", "mask_builds"]:
		r[k] = int(d.get(k, 0))
	for k: String in ["fps", "seconds", "setup_seconds", "frames_per_second", "minute_seconds", "first_result_ms", "gpu_ms", "gpu_crop_ms", "gpu_pyramid_ms", "gpu_motion_ms", "gpu_detect_ms", "gpu_track_ms", "alive_average"]:
		r[k] = float(d.get(k, 0.0))
	return r


func track_cancel(id: int) -> void:
	_call("track_cancel", [id], null)


func track_forget(id: int) -> void:
	_call("track_forget", [id], null)


func track_key(spec: Dictionary) -> String:
	return String(_call("track_key", [spec], ""))


func track_synth(spec: Dictionary, from: int, count: int) -> Dictionary:
	var out: Variant = _call("track_synth", [spec, from, count], null)
	return out if typeof(out) == TYPE_DICTIONARY else {"ok": false, "error": "tracking is not available"}


func track_bundle_check() -> Dictionary:
	var out: Variant = _call("track_bundle_check", [], null)
	return out if typeof(out) == TYPE_DICTIONARY else {"ok": false, "error": "tracking is not available"}


func track_info() -> Dictionary:
	var out: Variant = _call("track_info", [], null)
	return out if typeof(out) == TYPE_DICTIONARY else {"ok": false, "gpu": false, "error": "tracking is not available"}


func obj_status() -> Dictionary:
	var out: Variant = _call("obj_status", [], null)
	return out if typeof(out) == TYPE_DICTIONARY else {"built": false, "ok": false, "gpu": false, "error": "object select is not available"}


func obj_open(spec: Dictionary) -> Dictionary:
	var out: Variant = _call("obj_open", [spec], null)
	return out if typeof(out) == TYPE_DICTIONARY else {"ok": false, "error": "object select is not available"}


func obj_pick(frame: Image, spec: Dictionary) -> Dictionary:
	var out: Variant = _call("obj_pick", [frame, spec], null)
	return out if typeof(out) == TYPE_DICTIONARY else {"ok": false, "error": "object select is not available"}


func obj_follow(frame: Image, spec: Dictionary) -> Dictionary:
	var out: Variant = _call("obj_follow", [frame, spec], null)
	return out if typeof(out) == TYPE_DICTIONARY else {"ok": false, "error": "object select is not available"}


func obj_reset() -> void:
	_call("obj_reset", [], null)


func obj_close() -> void:
	_call("obj_close", [], null)


func shutdown() -> void:
	_call("shutdown", [], null)


func arm_exit_guard(seconds: float) -> void:
	_call("arm_exit_guard", [seconds], null)


func disarm_exit_guard() -> void:
	_call("disarm_exit_guard", [], null)


func close_report() -> Dictionary:
	var out: Variant = _call("close_report", [], null)
	return out if typeof(out) == TYPE_DICTIONARY else {"closed": false, "total_ms": 0.0, "error": "the engine is not loaded"}

extends Node

signal changed

const RifePlan := preload("res://engine/purrframes/rife_plan.gd")
const RifeTool := preload("res://engine/purrframes/rife_tool.gd")
const RifeCache := preload("res://engine/purrframes/rife_cache.gd")
const RifeWorker := preload("res://engine/purrframes/rife_worker.gd")
const TimeInterp := preload("res://engine/time_interp.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const NODE_NAME := "Purrframes"
const LABEL := "Frame interpolation (RIFE)"
const CACHE_SUB := "cache/purrframes"
const SUB_NAME := "purrframes"
const PREF_GPU := "purrframes.gpu"
const PREF_UHD := "purrframes.uhd"
const PREF_MODEL := "purrframes.model"
const PREF_SCENE := "purrframes.scene"
const PREF_CAP := "purrframes.cache_gb"
const PREF_CLEAR := "purrframes.clear"
const DEFAULT_CAP_GB := 20
const SCAN_DELAY := 0.4
const TEXTURE_KEEP := 48
const PREFETCH := 6
const IGNORED_CHANGES: PackedStringArray = ["live", "live_audio", "selection", "playhead", "markers", "bin_board", "warnings"]

var cache: RifeCache = null
var wanted: Dictionary = {}
var clip_plans: Dictionary = {}
var by_media: Dictionary = {}
var failed: Dictionary = {}
var doc: RefCounted = null
var enabled: bool = true
var paused: bool = false
var settings_override: Dictionary = {}
var _sigs: Dictionary = {}
var _scan_due: float = -1.0
var _thread: Thread = null
var _worker: RifeWorker = null
var _running: Dictionary = {}
var _job_id: int = -1
var _textures: Dictionary = {}
var _texture_order: Array[String] = []
var _load_thread: Thread = null
var _load_mutex: Mutex = Mutex.new()
var _load_sem: Semaphore = Semaphore.new()
var _load_queue: Array[String] = []
var _loaded: Dictionary = {}
var _loading: Dictionary = {}
var _load_quit: bool = false
var _watched_doc: RefCounted = null
var _redraw_due: bool = false
var _want_now: Dictionary = {}
var export_doc: RefCounted = null


static func instance() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var root: Window = (loop as SceneTree).root
	var n: Node = root.get_node_or_null(NODE_NAME)
	if n != null:
		return n
	n = (load("res://engine/purrframes/purrframes.gd") as GDScript).new()
	n.name = NODE_NAME
	root.add_child.call_deferred(n)
	TimeInterp.register_provider(TimeInterp.RIFE, LABEL, n)
	return n


static func start() -> void:
	instance()


func _init() -> void:
	cache = RifeCache.new("")


func _ready() -> void:
	register_prefs()
	cache.root = cache_root()
	cache.scan()
	var session: Node = _root("Session")
	if session != null and session.has_signal("project_changed"):
		session.connect("project_changed", _on_project_changed)
		_on_project_changed()
	var prefs: Node = _root("Prefs")
	if prefs != null:
		prefs.connect("changed", _on_pref_changed)
	TimeInterp.register_provider(TimeInterp.RIFE, LABEL, self)
	set_process(true)


func _exit_tree() -> void:
	if _worker != null:
		_worker.cancel()
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_stop_loader()


func _root(n: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(n)
	return null


func cache_root() -> String:
	var prefs: Node = _root("Prefs")
	if prefs != null and prefs.has_method("cache_dir"):
		return String(prefs.call("cache_dir")).path_join(SUB_NAME)
	return ProjectSettings.globalize_path("user://" + CACHE_SUB)


func register_prefs() -> void:
	var prefs: Node = _root("Prefs")
	if prefs == null:
		return
	var gpus: Array[Dictionary] = _read_gpu_probe()
	if not bool(prefs.call("is_registered", PREF_GPU)):
		prefs.call("register", PREF_GPU, RifeTool.GPU_AUTO, {"label": "RIFE graphics card", "type": "enum", "choices": Array(RifeTool.gpu_choices(gpus)), "hint": "Which graphics card renders the in-between frames. CPU is very slow but always works."})
	if not bool(prefs.call("is_registered", PREF_MODEL)):
		prefs.call("register", PREF_MODEL, RifeTool.DEFAULT_MODEL, {"label": "RIFE model", "type": "enum", "choices": Array(RifeTool.MODELS), "hint": "rife-v4.6 is the newest and best for most footage. rife-v4 is the first model that can make frames at any point in between."})
	if not bool(prefs.call("is_registered", PREF_UHD)):
		prefs.call("register", PREF_UHD, false, {"label": "RIFE UHD mode (4K footage)", "type": "bool", "hint": "Better on large motion in 4K footage, slower. Leave off for 1080p."})
	if not bool(prefs.call("is_registered", PREF_SCENE)):
		prefs.call("register", PREF_SCENE, RifePlan.SCENE_SKIP, {"label": "RIFE at a cut inside a clip", "type": "enum", "choices": [RifePlan.SCENE_SKIP, RifePlan.SCENE_BLEND, RifePlan.SCENE_OFF], "hint": "When the picture changes completely between two frames, Skip repeats the nearest frame, Blend mixes the two, Off lets RIFE morph them."})
	if not bool(prefs.call("is_registered", PREF_CAP)):
		prefs.call("register", PREF_CAP, DEFAULT_CAP_GB, {"label": "RIFE frame cache size (GB)", "type": "int", "min": 1, "max": 2000, "hint": "Rendered in-between frames are kept in the data folder up to this size. The oldest unused frames go first."})
	if not bool(prefs.call("is_registered", PREF_CLEAR)):
		prefs.call("register", PREF_CLEAR, 0, {"label": "RIFE frame cache", "type": "action", "button": "Clear", "run": clear_cache_from_settings, "note": "Deletes every rendered in-between frame. Clips render again when needed."})
	if gpus.is_empty() and RifeTool.available():
		_probe_gpus_later()


func _gpu_probe_path() -> String:
	var prefs: Node = _root("Prefs")
	if prefs == null:
		return ""
	return String(prefs.call("data_path", RifeTool.GPU_PROBE_FILE))


func _read_gpu_probe() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p: String = _gpu_probe_path()
	if p.is_empty() or not FileAccess.file_exists(p):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if parsed is Array:
		for g: Variant in parsed:
			if g is Dictionary:
				out.append({"id": int((g as Dictionary).get("id", 0)), "name": String((g as Dictionary).get("name", ""))})
	return out


var _probe_thread: Thread = null


func _probe_gpus_later() -> void:
	var prefs: Node = _root("Prefs")
	if prefs != null and bool(prefs.call("running_suite")):
		return
	if _probe_thread != null:
		return
	_probe_thread = Thread.new()
	_probe_thread.start(_probe_run)


func _probe_run() -> void:
	var gpus: Array[Dictionary] = RifeTool.probe_gpus()
	call_deferred("_probe_done", gpus)


func _probe_done(gpus: Array[Dictionary]) -> void:
	if _probe_thread != null and _probe_thread.is_started():
		_probe_thread.wait_to_finish()
	var p: String = _gpu_probe_path()
	if gpus.is_empty() or p.is_empty():
		return
	var f: FileAccess = FileAccess.open(p, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(gpus))
		f.close()
	var prefs: Node = _root("Prefs")
	if prefs != null:
		var spec: Dictionary = prefs.call("spec", PREF_GPU)
		spec["choices"] = Array(RifeTool.gpu_choices(gpus))


func settings() -> Dictionary:
	var out: Dictionary = {"model": RifeTool.DEFAULT_MODEL, "uhd": false, "scene": RifePlan.SCENE_SKIP, "gpu": RifeTool.GPU_AUTO, "cap_gb": DEFAULT_CAP_GB}
	var prefs: Node = _root("Prefs")
	if prefs != null and bool(prefs.call("is_registered", PREF_MODEL)):
		out["model"] = String(prefs.call("get_value", PREF_MODEL))
		out["uhd"] = bool(prefs.call("get_value", PREF_UHD))
		out["scene"] = String(prefs.call("get_value", PREF_SCENE))
		out["gpu"] = String(prefs.call("get_value", PREF_GPU))
		out["cap_gb"] = int(prefs.call("get_value", PREF_CAP))
	for k: Variant in settings_override.keys():
		out[k] = settings_override[k]
	return out


func _on_pref_changed(key: String) -> void:
	if not key.begins_with("purrframes."):
		return
	if key == PREF_CAP:
		_enforce_cap()
		return
	if key == PREF_CLEAR:
		return
	failed.clear()
	if key != PREF_GPU:
		_cancel_running()
	queue_scan()


func clear_cache_from_settings() -> void:
	var n: int = clear_cache()
	var ev: Node = _root("Events")
	if ev != null:
		ev.call("toast", "Deleted %d rendered RIFE frame set%s; they render again when needed" % [n, "" if n == 1 else "s"])


func clear_cache() -> int:
	_cancel_running()
	_forget_textures()
	var n: int = cache.clear()
	failed.clear()
	queue_scan()
	changed.emit()
	return n


func _on_project_changed() -> void:
	var session: Node = _root("Session")
	var d: RefCounted = session.get("doc") if session != null else null
	watch(d)


func watch(d: RefCounted) -> void:
	if _watched_doc != null and is_instance_valid(_watched_doc) and _watched_doc.has_signal("changed") and _watched_doc.is_connected("changed", _on_doc_changed):
		_watched_doc.disconnect("changed", _on_doc_changed)
	doc = d
	_watched_doc = d
	if d != null and d.has_signal("changed"):
		d.connect("changed", _on_doc_changed)
	failed.clear()
	queue_scan()


func _on_doc_changed(kind: String) -> void:
	if IGNORED_CHANGES.has(kind):
		return
	queue_scan()


func queue_scan() -> void:
	_scan_due = SCAN_DELAY


func _process(dt: float) -> void:
	if _scan_due >= 0.0:
		_scan_due -= dt
		if _scan_due < 0.0:
			scan()
	_poll_worker()
	_take_loaded()
	_update_job()
	if _redraw_due:
		_redraw_due = false
		_redraw()


func _redraw() -> void:
	var session: Node = _root("Session")
	if session == null or bool(session.get("playing")):
		return
	var comp: Variant = session.get("compositor")
	if comp is Node and is_instance_valid(comp) and (comp as Node).has_method("render_time"):
		(comp as Node).call("render_time", float(session.call("playhead")), false)


func media_sig(path: String) -> String:
	if not _sigs.has(path):
		_sigs[path] = RifePlan.media_sig(path)
	return String(_sigs[path])


func plan_clip(c: Clip, m: MediaItem, seq_fps: float, media_duration: float) -> Dictionary:
	var out: Dictionary = {"factor": 0, "keys": PackedStringArray(), "chunks": PackedInt32Array(), "fps": 0.0, "sig": "", "total": 0}
	if c == null or m == null or m.kind != "video" or m.fps <= 0.0 or m.path.is_empty():
		return out
	var factor: int = RifePlan.factor_for(c, m.fps, seq_fps)
	if factor < 2:
		return out
	var total: int = RifePlan.frame_count(media_duration if media_duration > 0.0 else m.duration, m.fps)
	var frames: Vector2i = RifePlan.frame_range(c.source_reach(), m.fps, total)
	var chunks: PackedInt32Array = RifePlan.chunks_for_range(frames)
	var sig: String = media_sig(m.path)
	var st: Dictionary = settings()
	var keys: PackedStringArray = PackedStringArray()
	for ch: int in chunks:
		keys.append(RifePlan.key(sig, ch, factor, m.fps, st))
	out["factor"] = factor
	out["keys"] = keys
	out["chunks"] = chunks
	out["fps"] = m.fps
	out["sig"] = sig
	out["total"] = total
	return out


func wants_rife(c: Clip, m: MediaItem) -> bool:
	if c == null or m == null:
		return false
	if TimeInterp.mode_of(c) != TimeInterp.RIFE:
		return false
	return TimeInterp.shows_row(m, c) and TimeInterp.retimed(c)


func scan() -> void:
	_scan_due = -1.0
	_sigs.clear()
	wanted.clear()
	by_media.clear()
	clip_plans.clear()
	if not enabled:
		changed.emit()
		return
	for d: RefCounted in _scan_docs():
		_scan_doc(d)
	if _running.has("key") and not wanted.has(String(_running["key"])):
		_cancel_running()
	_enforce_cap()
	changed.emit()


func _scan_docs() -> Array[RefCounted]:
	var out: Array[RefCounted] = []
	if doc != null:
		out.append(doc)
	if export_doc != null and export_doc != doc:
		out.append(export_doc)
	return out


func _scan_doc(d: RefCounted) -> void:
	var seqs: Array = d.get("sequences")
	for s: RefCounted in seqs:
		var seq_fps: float = float(s.get("fps"))
		for tr: RefCounted in s.call("all_tracks"):
			for c: Clip in tr.get("clips"):
				if not bool(tr.call("is_picture", c)):
					continue
				var m: MediaItem = d.call("media_by_id", c.media_id)
				if not wants_rife(c, m):
					continue
				var p: Dictionary = plan_clip(c, m, seq_fps, float(d.call("media_duration", m)))
				p["seq_id"] = String(s.get("id"))
				p["start"] = c.start
				p["end"] = c.end()
				clip_plans[c.id] = p
				var keys: PackedStringArray = p["keys"]
				var chunks: PackedInt32Array = p["chunks"]
				for i: int in keys.size():
					var k: String = keys[i]
					if not wanted.has(k):
						wanted[k] = {"key": k, "path": m.path, "fps": m.fps, "chunk": chunks[i], "factor": int(p["factor"]), "inputs": RifePlan.chunk_inputs(chunks[i], int(p["total"])), "clips": PackedStringArray(), "seq_id": String(s.get("id")), "start": c.start, "pixels": maxi(m.width * m.height, 1)}
					var ids: PackedStringArray = wanted[k]["clips"]
					ids.append(c.id)
					wanted[k]["clips"] = ids
					_index_media(m.path, m.fps, chunks[i], k, int(p["factor"]), RifePlan.output_count(wanted[k]["inputs"], int(p["factor"])))


func _index_media(path: String, fps: float, chunk: int, k: String, factor: int, count: int) -> void:
	var pk: String = path.simplify_path().to_lower()
	if not by_media.has(pk):
		by_media[pk] = {"fps": fps, "chunks": {}}
	var chunks: Dictionary = by_media[pk]["chunks"]
	if not chunks.has(chunk):
		chunks[chunk] = []
	for r: Dictionary in chunks[chunk]:
		if String(r["key"]) == k:
			return
	(chunks[chunk] as Array).append({"key": k, "factor": factor, "count": count})


func missing_keys() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: String in wanted.keys():
		if cache.has(k):
			continue
		if failed.has(k):
			continue
		out.append(k)
	return out


func _priority(k: String, playhead: float, seq_id: String) -> float:
	var w: Dictionary = wanted[k]
	var p: float = float(w.get("chunk", 0)) * 0.001
	if String(w.get("seq_id", "")) != seq_id:
		return 1000000.0 + p
	var start: float = float(w.get("start", 0.0))
	for cid: String in w.get("clips", PackedStringArray()):
		var cp: Dictionary = clip_plans.get(cid, {})
		if cp.is_empty():
			continue
		if playhead >= float(cp.get("start", 0.0)) and playhead < float(cp.get("end", 0.0)):
			return p
		start = minf(start, float(cp.get("start", 0.0)))
	return 1000.0 + absf(start - playhead) + p


func next_key() -> String:
	var miss: PackedStringArray = missing_keys()
	if miss.is_empty():
		return ""
	var session: Node = _root("Session")
	var playhead: float = float(session.call("playhead")) if session != null and session.has_method("playhead") else 0.0
	var seq_id: String = String(session.get("seq_id")) if session != null else ""
	var best: String = ""
	var best_p: float = INF
	for k: String in miss:
		var p: float = _priority(k, playhead, seq_id)
		if p < best_p:
			best_p = p
			best = k
	return best


func busy() -> bool:
	return not _running.is_empty()


func _poll_worker() -> void:
	if not _running.is_empty():
		if _thread != null and _thread.is_started() and not _thread.is_alive():
			var result: Variant = _thread.wait_to_finish()
			_finish(result if result is Dictionary else {})
		return
	if not enabled or paused or not RifeTool.available():
		return
	var k: String = next_key()
	if k.is_empty():
		return
	_start(k)


func _start(k: String) -> void:
	var w: Dictionary = wanted[k]
	var handle: int = -1
	var session: Node = _root("Session")
	if session != null and session.has_method("render_handle"):
		handle = int(session.call("render_handle", String(w["path"])))
	var bridge: Node = _root("PurrBridge")
	if handle < 0 or bridge == null:
		failed[k] = {"why": "the media file could not be opened", "at": Time.get_ticks_msec()}
		return
	var st: Dictionary = settings()
	var job: Dictionary = {"key": k, "root": cache.root, "inputs": w["inputs"], "factor": int(w["factor"]), "fps": float(w["fps"]), "handle": handle, "model": String(st["model"]), "uhd": bool(st["uhd"]), "scene": String(st["scene"]), "gpu": RifeTool.gpu_id(String(st["gpu"])), "media_path": String(w["path"]), "pixels": int(w.get("pixels", 1920 * 1080))}
	_running = job
	_worker = RifeWorker.new()
	_thread = Thread.new()
	_thread.start(_worker.run.bind(job, bridge), Thread.PRIORITY_LOW)
	changed.emit()


func _finish(result: Dictionary) -> void:
	var k: String = String(_running.get("key", ""))
	_running = {}
	_worker = null
	_thread = null
	if bool(result.get("ok", false)):
		cache.add(k, result)
		_enforce_cap()
		_redraw_due = true
	elif String(result.get("why", "")) != "cancelled":
		failed[k] = {"why": String(result.get("why", "")), "at": Time.get_ticks_msec()}
		var ev: Node = _root("Events")
		if ev != null:
			ev.call("warn", "RIFE could not render some frames: " + String(result.get("why", "")), k, PackedStringArray(["Pick another graphics card or the CPU under Settings, Purrframes", "Use Optical flow for this clip"]))
	changed.emit()


func _cancel_running() -> void:
	if _worker != null:
		_worker.cancel()
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_running = {}
	_worker = null
	_thread = null


func _enforce_cap() -> void:
	var busy_keys: Dictionary = {}
	if _running.has("key"):
		busy_keys[String(_running["key"])] = true
	var cap: int = int(settings().get("cap_gb", DEFAULT_CAP_GB)) * 1024 * 1024 * 1024
	var gone: PackedStringArray = cache.enforce(cap, wanted, busy_keys)
	if not gone.is_empty():
		_forget_textures()


func running_progress() -> float:
	return _worker.progress() if _worker != null else 0.0


func overall() -> Dictionary:
	var total: int = wanted.size()
	var ready: int = 0
	for k: String in wanted.keys():
		if cache.has(k):
			ready += 1
	var run: float = running_progress() if busy() else 0.0
	return {"total": total, "ready": ready, "progress": (float(ready) + run) / float(total) if total > 0 else 1.0}


func _update_job() -> void:
	var jobs: Node = _root("Jobs")
	if jobs == null:
		return
	var miss: int = missing_keys().size()
	if miss == 0 and not busy():
		if _job_id >= 0:
			jobs.call("done_local", _job_id, true)
			_job_id = -1
		return
	if _job_id < 0:
		_job_id = int(jobs.call("add_local", "Purrframes", "purrframes"))
	var o: Dictionary = overall()
	jobs.call("update_local", _job_id, float(o["progress"]))


func status_for(c: Clip) -> Dictionary:
	var out: Dictionary = {"state": "off", "progress": 0.0, "text": ""}
	if c == null:
		return out
	if not TimeInterp.retimed(c):
		out["state"] = "idle"
		out["text"] = "At 100% the frames are shown as they are"
		return out
	if not RifeTool.available():
		out["state"] = "missing"
		out["text"] = "rife-ncnn-vulkan is not installed, Optical flow is shown"
		return out
	var p: Dictionary = clip_plans.get(c.id, {})
	if p.is_empty():
		out["state"] = "waiting"
		out["text"] = "Checking the clip"
		return out
	if int(p.get("factor", 0)) < 2:
		out["state"] = "idle"
		out["text"] = "Not slowed down, the frames are shown as they are"
		return out
	var keys: PackedStringArray = p["keys"]
	var ready: int = 0
	var bad: String = ""
	var run: float = 0.0
	for k: String in keys:
		if cache.has(k):
			ready += 1
		elif failed.has(k):
			bad = String((failed[k] as Dictionary).get("why", ""))
		elif _running.get("key", "") == k:
			run = running_progress()
	var total: int = keys.size()
	out["progress"] = (float(ready) + run) / float(total) if total > 0 else 1.0
	if ready == total:
		out["state"] = "ready"
		out["text"] = "Ready, %dx in-between frames" % int(p["factor"])
	elif not bad.is_empty():
		out["state"] = "failed"
		out["text"] = "Could not render: " + bad
	else:
		out["state"] = "rendering"
		out["text"] = "Rendering %d%%, Optical flow until ready" % int(round(float(out["progress"]) * 100.0))
	return out


func frame_ref(c: Clip, m: MediaItem, src_t: float, seq_fps: float, media_duration: float) -> Dictionary:
	var none: Dictionary = {"key": "", "index": -1, "path": "", "on_grid": true}
	if c == null or m == null or m.fps <= 0.0:
		return none
	var factor: int = RifePlan.factor_for(c, m.fps, seq_fps)
	if factor < 2:
		return none
	var loc: Dictionary = RifePlan.locate(src_t, m.fps, factor)
	if bool(loc["on_grid"]):
		return {"key": "", "index": -1, "path": "", "on_grid": true, "frame": int(loc["frame"])}
	var total: int = RifePlan.frame_count(media_duration if media_duration > 0.0 else m.duration, m.fps)
	var inputs: Vector2i = RifePlan.chunk_inputs(int(loc["chunk"]), total)
	var idx: int = int(loc["index"])
	if idx >= RifePlan.output_count(inputs, factor):
		return none
	var k: String = RifePlan.key(media_sig(m.path), int(loc["chunk"]), factor, m.fps, settings())
	return {"key": k, "index": idx, "path": cache.frame_path(k, idx), "on_grid": false, "chunk": int(loc["chunk"]), "factor": factor, "amount": float(loc["amount"])}


func lookup(media_path: String, a_pts: float, weight: float) -> Dictionary:
	var out: Dictionary = {"key": "", "index": -1, "path": "", "factor": 0, "on_grid": false, "wanted": false}
	var per: Dictionary = by_media.get(media_path.simplify_path().to_lower(), {})
	if per.is_empty():
		return out
	var fps: float = float(per.get("fps", 0.0))
	if fps <= 0.0:
		return out
	var ia: int = int(round(a_pts * fps))
	var chunk: int = ia / RifePlan.CHUNK
	var rows: Array = (per.get("chunks", {}) as Dictionary).get(chunk, [])
	if rows.is_empty():
		return out
	var factors: PackedInt32Array = PackedInt32Array()
	for r: Dictionary in rows:
		factors.append(int(r["factor"]))
	var factor: int = RifePlan.pick_factor(weight, factors)
	var q: int = int(round(weight * float(factor)))
	if q <= 0 or q >= factor:
		out["on_grid"] = true
		return out
	for r: Dictionary in rows:
		if int(r["factor"]) != factor:
			continue
		var idx: int = (ia - chunk * RifePlan.CHUNK) * factor + q
		if idx >= int(r["count"]):
			return out
		var k: String = String(r["key"])
		return {"key": k, "index": idx, "path": cache.frame_path(k, idx), "factor": factor, "on_grid": false, "wanted": true}
	return out


func frame(media_path: String, a_pts: float, _b_pts: float, weight: float, _size: Vector2i, exact: bool) -> Dictionary:
	var ref: Dictionary = lookup(media_path, a_pts, weight)
	if not enabled or not bool(ref["wanted"]):
		return {"state": "none", "texture": null, "matrix": 0}
	var k: String = String(ref["key"])
	if not cache.has(k):
		var later: bool = not exact and not failed.has(k) and RifeTool.available()
		return {"state": "pending" if later else "none", "texture": null, "matrix": 0}
	var tex: Texture2D = texture_for(ref, exact, 1)
	if tex == null:
		return {"state": "pending", "texture": null, "matrix": 0}
	return {"state": "exact", "texture": tex, "matrix": 1}


static func given_matrix(main: Node, r: Dictionary) -> int:
	if int(r.get("matrix", 0)) == 0 or main == null:
		return 0
	var mat: Variant = main.get("_material")
	if mat is ShaderMaterial:
		var cs: Variant = (mat as ShaderMaterial).get_shader_parameter("colorspace")
		return int(cs) if cs != null else 1
	return 1


func texture_for(ref: Dictionary, exact: bool, ahead: int = 1) -> Texture2D:
	var k: String = String(ref.get("key", ""))
	if k.is_empty() or not cache.has(k):
		return null
	var path: String = String(ref["path"])
	cache.touch(k)
	var tex: Texture2D = _textures.get(path, null)
	if tex == null and exact:
		var img: Image = Image.load_from_file(path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
			_keep_texture(path, tex)
	elif tex == null:
		_want_now[path] = true
		_queue_load(path)
	if not exact:
		var idx: int = int(ref.get("index", 0))
		var factor: int = int(ref.get("factor", 2))
		for n: int in range(1, PREFETCH + 1):
			var j: int = idx + n * ahead
			if j < 0 or j % factor == 0:
				continue
			var pth: String = cache.frame_path(k, j)
			if not _textures.has(pth):
				_queue_load(pth)
	return tex


func _keep_texture(path: String, tex: Texture2D) -> void:
	_textures[path] = tex
	_texture_order.erase(path)
	_texture_order.append(path)
	while _texture_order.size() > TEXTURE_KEEP:
		var old: String = _texture_order.pop_front()
		_textures.erase(old)


func _forget_textures() -> void:
	_textures.clear()
	_texture_order.clear()


func _queue_load(path: String) -> void:
	if _loading.has(path):
		return
	if not FileAccess.file_exists(path):
		return
	_loading[path] = true
	_ensure_loader()
	_load_mutex.lock()
	_load_queue.append(path)
	_load_mutex.unlock()
	_load_sem.post()


func _ensure_loader() -> void:
	if _load_thread != null:
		return
	_load_quit = false
	_load_thread = Thread.new()
	_load_thread.start(_loader_run, Thread.PRIORITY_NORMAL)


func _loader_run() -> void:
	while true:
		_load_sem.wait()
		_load_mutex.lock()
		var quit: bool = _load_quit
		var path: String = "" if _load_queue.is_empty() else _load_queue.pop_front()
		_load_mutex.unlock()
		if quit:
			return
		if path.is_empty():
			continue
		var img: Image = Image.load_from_file(path)
		_load_mutex.lock()
		_loaded[path] = img
		_load_mutex.unlock()


func _take_loaded() -> void:
	if _load_thread == null:
		return
	_load_mutex.lock()
	var got: Dictionary = _loaded
	_loaded = {}
	_load_mutex.unlock()
	for path: String in got.keys():
		_loading.erase(path)
		var img: Image = got[path]
		if img != null and not img.is_empty():
			_keep_texture(path, ImageTexture.create_from_image(img))
			if _want_now.has(path):
				_want_now.erase(path)
				_redraw_due = true


func _stop_loader() -> void:
	if _load_thread == null:
		return
	_load_mutex.lock()
	_load_quit = true
	_load_mutex.unlock()
	_load_sem.post()
	_load_thread.wait_to_finish()
	_load_thread = null


func nested_ids(d: RefCounted, seq: RefCounted, into: Dictionary) -> void:
	if seq == null or into.has(String(seq.get("id"))):
		return
	into[String(seq.get("id"))] = true
	for tr: RefCounted in seq.call("all_tracks"):
		for c: Clip in tr.get("clips"):
			if not c.sequence_id.is_empty():
				nested_ids(d, d.call("sequence_by_id", c.sequence_id), into)


func ready_for(d: RefCounted, seq: RefCounted, from_t: float, to_t: float) -> bool:
	var ids: Dictionary = {}
	nested_ids(d, seq, ids)
	var top: String = String(seq.get("id")) if seq != null else ""
	for k: String in wanted.keys():
		if cache.has(k) or failed.has(k):
			continue
		var w: Dictionary = wanted[k]
		for cid: String in w.get("clips", PackedStringArray()):
			var cp: Dictionary = clip_plans.get(cid, {})
			var sid: String = String(cp.get("seq_id", ""))
			if not ids.has(sid):
				continue
			if sid != top or (float(cp.get("end", 0.0)) > from_t and float(cp.get("start", 0.0)) < to_t):
				return false
	return true


static func before_export(job: Node, d: RefCounted, seq: RefCounted, range_v: Vector2) -> void:
	var n: Node = instance()
	if n == null or d == null or seq == null or not RifeTool.available():
		return
	if not n.is_inside_tree():
		await (Engine.get_main_loop() as SceneTree).process_frame
	n.set("export_doc", d)
	n.call("scan")
	var tree: SceneTree = n.get_tree()
	var said: bool = false
	while not bool(n.call("ready_for", d, seq, range_v.x, range_v.y)):
		if bool(job.get("cancel_requested")):
			break
		if not said:
			said = true
			if job.has_method("_info"):
				job.call("_info", "Export is waiting for RIFE in-between frames", "They render once and are kept for next time")
		var o: Dictionary = n.call("overall")
		if job.has_signal("progress"):
			job.emit_signal("progress", 0.0, "Rendering RIFE frames %d%%" % int(round(float(o["progress"]) * 100.0)))
		await tree.process_frame
	n.set("export_doc", null)

extends RefCounted

signal finished(result: Dictionary)

const Find := preload("res://doc/picture_find.gd")
const POLL_MS := 30
const WAIT_LIMIT_MS := 600000

static var running: Array = []

var spec: Dictionary = {}
var result: Dictionary = {}
var progress: float = 0.0
var job_id: int = -1
var series_id: int = -1
var task_id: int = -1
var cancelled: bool = false
var done: bool = false
var worst_tick_us: int = 0
var _tree: SceneTree = null
var _bridge: Node = null


static func bridge() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var b: Node = (loop as SceneTree).root.get_node_or_null("PurrBridge")
	if b == null or not b.has_method("has_pictures") or not bool(b.call("has_pictures")):
		return null
	return b


static func available() -> bool:
	return bridge() != null


static func start(p_spec: Dictionary) -> RefCounted:
	var script: GDScript = load("res://engine/picture_find_job.gd")
	var j: RefCounted = script.new()
	j.call("_begin", p_spec)
	return j


func _begin(p_spec: Dictionary) -> void:
	spec = p_spec
	_bridge = bridge()
	var loop: MainLoop = Engine.get_main_loop()
	_tree = loop as SceneTree
	var path: String = String(spec.get("path", ""))
	if _bridge == null or path.is_empty() or not FileAccess.file_exists(path):
		_fail("the picture engine is not loaded" if _bridge == null else "the file is missing")
		return
	var rate: int = int(spec.get("rate", Find.RATE))
	series_id = int(_bridge.call("picture_request", path, rate, Find.FRAME_W, Find.FRAME_H))
	if series_id < 0:
		_fail("the picture reading could not start")
		return
	var jobs: Node = _tree.root.get_node_or_null("/root/Jobs")
	if jobs != null:
		job_id = int(jobs.call("add_local", String(spec.get("label", "Finding pictures in " + path.get_file())), "find"))
		jobs.connect("job_done", _on_job_done)
	running.append(self)
	task_id = WorkerThreadPool.add_task(_work, false, "Find pictures")
	_tree.process_frame.connect(_tick)


func _fail(why: String) -> void:
	result = {"ok": false, "error": why, "ranges": [], "views": [], "switches": PackedFloat64Array()}
	done = true
	(func() -> void: finished.emit(result)).call_deferred()


func _on_job_done(id: int, ok: bool) -> void:
	if id == job_id and not ok and not done:
		cancelled = true


func cancel() -> void:
	cancelled = true


func _tick() -> void:
	var t0: int = Time.get_ticks_usec()
	var jobs: Node = _tree.root.get_node_or_null("/root/Jobs") if _tree != null else null
	if task_id >= 0 and WorkerThreadPool.is_task_completed(task_id):
		WorkerThreadPool.wait_for_task_completion(task_id)
		task_id = -1
		_tree.process_frame.disconnect(_tick)
		running.erase(self)
		if jobs != null:
			if jobs.is_connected("job_done", _on_job_done):
				jobs.disconnect("job_done", _on_job_done)
			if not cancelled:
				jobs.call("done_local", job_id, bool(result.get("ok", false)))
		if _bridge != null and series_id >= 0 and bool(spec.get("forget", true)):
			_bridge.call("picture_forget", series_id)
		done = true
		finished.emit(result)
	elif jobs != null and job_id >= 0:
		jobs.call("update_local", job_id, progress)
	worst_tick_us = maxi(worst_tick_us, Time.get_ticks_usec() - t0)


func _work() -> void:
	var rate: float = float(int(spec.get("rate", Find.RATE)))
	var mode: String = String(spec.get("mode", "find"))
	var views: Array[Rect2] = Find.rects(spec.get("views", []))
	if views.is_empty():
		views.append(Find.FULL)
	var prep: Array[Dictionary] = Find.prepared(spec.get("samples", []), Find.rects(spec.get("focus", [])), Find.rects(spec.get("drop", [])))
	if mode == "find" and prep.is_empty():
		result = {"ok": false, "error": "there are no usable sample pictures", "ranges": [], "views": [], "switches": PackedFloat64Array()}
		return
	var scores: Array = []
	for v: Rect2 in views:
		scores.append(PackedFloat32Array())
	var changes: PackedFloat32Array = PackedFloat32Array()
	var last_grey: PackedByteArray = PackedByteArray()
	var maps: Array = []
	var fw: int = Find.FRAME_W
	var fh: int = Find.FRAME_H
	var have_maps: bool = false
	var scored: int = 0
	var expected: int = 0
	var t_start: int = Time.get_ticks_msec()
	while not cancelled:
		var got: Dictionary = _bridge.call("picture_read", series_id, scored)
		if not bool(got.get("ok", true)) and bool(got.get("failed", false)):
			result = {"ok": false, "error": String(got.get("error", "the file could not be read")), "ranges": [], "views": [], "switches": PackedFloat64Array()}
			return
		if int(got.get("width", 0)) > 0 and not have_maps:
			fw = int(got["width"])
			fh = int(got["height"])
		if not have_maps and fw > 0:
			maps = Find.view_maps(prep, views, fw, fh)
			have_maps = true
		var px: PackedByteArray = got.get("pixels", PackedByteArray())
		var fb: int = fw * fh * 3
		var n: int = px.size() / maxi(fb, 1)
		var dur: float = float(got.get("duration", 0.0))
		if dur > 0.0:
			expected = maxi(int(ceil(dur * rate)), 1)
		if n > 0:
			if mode == "switch":
				var greys: Array[PackedByteArray] = Find.frame_grids(px, fw, fh, 0, n)
				for g: PackedByteArray in greys:
					changes.append(Find.change(last_grey, g) if not last_grey.is_empty() else 0.0)
					last_grey = g
			else:
				Find.score_frames(px, fw, fh, 0, n, prep, maps, scores)
			scored += n
			progress = clampf(float(scored) / float(maxi(expected, scored + 1)), 0.0, 0.99)
		if bool(got.get("done", false)) and n == 0:
			break
		if n == 0:
			OS.delay_msec(POLL_MS)
		if Time.get_ticks_msec() - t_start > WAIT_LIMIT_MS * 6:
			break
	if cancelled:
		result = {"ok": false, "error": "cancelled", "ranges": [], "views": [], "switches": PackedFloat64Array()}
		return
	var threshold: float = float(spec.get("threshold", Find.DEFAULT_THRESHOLD))
	var min_len: float = float(spec.get("min_len", Find.DEFAULT_MIN_LEN))
	var gap: float = float(spec.get("gap", Find.DEFAULT_GAP))
	var per_view: Array = []
	for vi: int in scores.size():
		per_view.append(Find.ranges(scores[vi], rate, threshold, min_len, gap))
	var all: PackedVector2Array = per_view[0] if not per_view.is_empty() else PackedVector2Array()
	if per_view.size() > 1:
		for vi: int in range(1, per_view.size()):
			all = Find.intersect(all, per_view[vi])
	result = {"ok": true, "error": "", "frames": scored, "rate": rate, "ranges": all, "views": per_view, "scores": scores, "switches": Find.switches(changes, rate) if mode == "switch" else PackedFloat64Array(), "changes": changes}
	progress = 1.0


static func capture(path: String, t: float, view: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0), timeout_ms: int = 20000) -> Dictionary:
	var b: Node = bridge()
	if b == null or path.is_empty():
		return {}
	var id: int = int(b.call("picture_request", path, Find.RATE, Find.FRAME_W, Find.FRAME_H))
	if id < 0:
		return {}
	var slot: int = maxi(int(floor(t * float(Find.RATE) + 0.000001)), 0)
	var holder: Array = [{}]
	var task: int = WorkerThreadPool.add_task(_capture_work.bind(b, id, slot, view, t, path, timeout_ms, holder), false, "Sample picture")
	return {"task": task, "holder": holder}


static func _capture_work(b: Node, id: int, slot: int, view: Rect2, t: float, path: String, timeout_ms: int, holder: Array) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout_ms:
		var got: Dictionary = b.call("picture_read", id, slot)
		var px: PackedByteArray = got.get("pixels", PackedByteArray())
		var w: int = int(got.get("width", Find.FRAME_W))
		var h: int = int(got.get("height", Find.FRAME_H))
		if w > 0 and px.size() >= w * h * 3:
			var s: Dictionary = Find.sample_from(px, 0, w, h, view)
			s["t"] = t
			s["path"] = path
			if view != Find.FULL:
				s["view"] = Find.rect_array(view)
			holder[0] = s
			return
		if bool(got.get("done", false)):
			var all: Dictionary = b.call("picture_read", id, 0)
			var count: int = int(all.get("count", 0))
			if count > 0 and slot >= count:
				var px2: PackedByteArray = all.get("pixels", PackedByteArray())
				var w2: int = int(all.get("width", Find.FRAME_W))
				var h2: int = int(all.get("height", Find.FRAME_H))
				var s2: Dictionary = Find.sample_from(px2, (count - 1) * w2 * h2 * 3, w2, h2, view)
				s2["t"] = t
				s2["path"] = path
				holder[0] = s2
			return
		OS.delay_msec(POLL_MS)


static func capture_ready(job: Dictionary) -> bool:
	return job.has("task") and WorkerThreadPool.is_task_completed(int(job["task"]))


static func capture_take(job: Dictionary) -> Dictionary:
	if not job.has("task"):
		return {}
	WorkerThreadPool.wait_for_task_completion(int(job["task"]))
	var holder: Array = job["holder"]
	return holder[0]

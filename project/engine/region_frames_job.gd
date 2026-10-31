extends RefCounted

signal finished(result: Dictionary)

const CHUNK := 8

var plan: Array[Dictionary] = []
var width: int = 1280
var written: int = 0
var failed: int = 0
var total: int = 0
var cancelled: bool = false
var done: bool = false
var job_id: int = -1
var task_id: int = -1
var worst_tick_us: int = 0
var _handles: Dictionary = {}
var _tree: SceneTree = null
var _bridge: Node = null


static func start(p_plan: Array[Dictionary], p_width: int, label: String) -> RefCounted:
	var j: RefCounted = (load("res://engine/region_frames_job.gd") as GDScript).new()
	j.call("_begin", p_plan, p_width, label)
	return j


func _begin(p_plan: Array[Dictionary], p_width: int, label: String) -> void:
	plan = p_plan
	width = maxi(p_width, 16)
	_tree = Engine.get_main_loop() as SceneTree
	_bridge = _tree.root.get_node_or_null("PurrBridge") if _tree != null else null
	for e: Dictionary in plan:
		total += (e["times"] as PackedFloat64Array).size()
	if _bridge == null or not _bridge.has_method("has_snapshot_run") or not bool(_bridge.call("has_snapshot_run")):
		done = true
		(func() -> void: finished.emit({"ok": false, "error": "the picture engine is not loaded", "written": 0, "failed": total})).call_deferred()
		return
	for e: Dictionary in plan:
		var p: String = String(e["path"])
		if not _handles.has(p):
			_handles[p] = int(_bridge.call("open_media", p, {}))
		DirAccess.make_dir_recursive_absolute(String(e["dir"]))
	var jobs: Node = _tree.root.get_node_or_null("/root/Jobs")
	if jobs != null:
		job_id = int(jobs.call("add_local", label, "export"))
		jobs.connect("job_done", _on_job_done)
	task_id = WorkerThreadPool.add_task(_work, false, "Region frames")
	_tree.process_frame.connect(_tick)


func _on_job_done(id: int, ok: bool) -> void:
	if id == job_id and not ok and not done:
		cancelled = true


func _work() -> void:
	for e: Dictionary in plan:
		var h: int = int(_handles.get(String(e["path"]), -1))
		var times: PackedFloat64Array = e["times"]
		var dir: String = String(e["dir"])
		var i: int = 0
		while i < times.size() and not cancelled:
			var chunk: PackedFloat64Array = times.slice(i, mini(i + CHUNK, times.size()))
			var imgs: Array = _bridge.call("snapshot_run", h, chunk, width) if h >= 0 else []
			for k: int in chunk.size():
				var img: Variant = imgs[k] if k < imgs.size() else null
				if img is Image and not (img as Image).is_empty():
					if (img as Image).save_png(dir.path_join("frame_%04d.png" % (i + k + 1))) == OK:
						written += 1
					else:
						failed += 1
				else:
					failed += 1
			i += chunk.size()


func _tick() -> void:
	var t0: int = Time.get_ticks_usec()
	var jobs: Node = _tree.root.get_node_or_null("/root/Jobs")
	if task_id >= 0 and WorkerThreadPool.is_task_completed(task_id):
		WorkerThreadPool.wait_for_task_completion(task_id)
		task_id = -1
		_tree.process_frame.disconnect(_tick)
		for p: Variant in _handles.keys():
			if int(_handles[p]) >= 0:
				_bridge.call("close_media", int(_handles[p]))
		if jobs != null:
			if jobs.is_connected("job_done", _on_job_done):
				jobs.disconnect("job_done", _on_job_done)
			if not cancelled:
				jobs.call("done_local", job_id, failed == 0)
		done = true
		finished.emit({"ok": not cancelled and written > 0, "error": "cancelled" if cancelled else "", "written": written, "failed": failed})
	elif jobs != null and job_id >= 0 and total > 0:
		jobs.call("update_local", job_id, float(written + failed) / float(total))
	worst_tick_us = maxi(worst_tick_us, Time.get_ticks_usec() - t0)

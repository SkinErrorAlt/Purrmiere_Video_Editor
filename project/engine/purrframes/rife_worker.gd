extends RefCounted

const RifePlan := preload("res://engine/purrframes/rife_plan.gd")
const RifeTool := preload("res://engine/purrframes/rife_tool.gd")
const RifeCache := preload("res://engine/purrframes/rife_cache.gd")
const POLL_MS := 60
const DECODE_SHARE := 0.4
const BATCH_BYTES := 200000000.0
const MIN_BATCH := 4
const SAVE_THREADS := 4

var _mutex: Mutex = Mutex.new()
var _progress: float = 0.0
var _cancel: bool = false
var _pid: int = -1
var _stage: String = ""


func progress() -> float:
	_mutex.lock()
	var p: float = _progress
	_mutex.unlock()
	return p


func stage() -> String:
	_mutex.lock()
	var s: String = _stage
	_mutex.unlock()
	return s


func cancel() -> void:
	_mutex.lock()
	_cancel = true
	var pid: int = _pid
	_mutex.unlock()
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)


func cancelled() -> bool:
	_mutex.lock()
	var c: bool = _cancel
	_mutex.unlock()
	return c


func _report(p: float, s: String) -> void:
	_mutex.lock()
	_progress = clampf(p, 0.0, 1.0)
	_stage = s
	_mutex.unlock()


static func fail(job: Dictionary, why: String) -> Dictionary:
	return {"ok": false, "key": String(job.get("key", "")), "why": why, "bytes": 0, "count": 0, "factor": int(job.get("factor", 0)), "cuts": [], "ms": 0}


func run(job: Dictionary, bridge: Object) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	var cache: RifeCache = RifeCache.new(String(job.get("root", "")))
	var key: String = String(job.get("key", ""))
	var inputs: Vector2i = job.get("inputs", Vector2i.ZERO)
	var factor: int = int(job.get("factor", 2))
	var fps: float = float(job.get("fps", 0.0))
	var handle: int = int(job.get("handle", -1))
	var scene: String = String(job.get("scene", RifePlan.SCENE_SKIP))
	if key.is_empty() or factor < 2 or fps <= 0.0 or inputs.y <= inputs.x:
		return fail(job, "nothing to render")
	var exe: String = RifeTool.exe_path()
	if exe.is_empty():
		return fail(job, "rife-ncnn-vulkan is not installed")
	RifeCache.remove_tree(cache.entry_dir(key))
	DirAccess.make_dir_recursive_absolute(cache.in_dir(key))
	DirAccess.make_dir_recursive_absolute(cache.out_dir(key))
	var n_in: int = inputs.y - inputs.x + 1
	var small: Array[Image] = []
	var runs: bool = not job.has("frames") and bool(job.get("run", true)) and bridge != null and bridge.has_method("has_snapshot_run") and bool(bridge.call("has_snapshot_run"))
	var batch: int = clampi(int(BATCH_BYTES / (float(maxi(int(job.get("pixels", 1920 * 1080)), 1)) * 3.0)), MIN_BATCH, RifePlan.CHUNK + 1)
	_report(0.0, "decode")
	var at: int = 0
	while at < n_in:
		if cancelled():
			return _abandon(cache, key, job, "cancelled")
		var count_b: int = mini(batch, n_in - at)
		var imgs: Array = []
		if job.has("frames"):
			imgs = (job["frames"] as Array).slice(at, at + count_b)
		elif runs:
			var secs: PackedFloat64Array = PackedFloat64Array()
			for j: int in count_b:
				secs.append(RifePlan.frame_seconds(inputs.x + at + j, fps))
			imgs = bridge.call("snapshot_run", handle, secs, 0)
		elif bridge != null:
			for j: int in count_b:
				if cancelled():
					return _abandon(cache, key, job, "cancelled")
				imgs.append(bridge.call("snapshot", handle, RifePlan.frame_seconds(inputs.x + at + j, fps), 0))
		if imgs.size() != count_b:
			return _abandon(cache, key, job, "the source frames could not be decoded")
		for j: int in count_b:
			var img: Variant = imgs[j]
			if not (img is Image) or (img as Image).is_empty():
				return _abandon(cache, key, job, "source frame %d could not be decoded" % (inputs.x + at + j))
			var im: Image = img
			if im.get_format() != Image.FORMAT_RGB8 and im.get_format() != Image.FORMAT_RGBA8:
				im.convert(Image.FORMAT_RGB8)
		if not save_all(imgs, cache.in_dir(key), at):
			return _abandon(cache, key, job, "could not write to the cache folder")
		if scene != RifePlan.SCENE_OFF:
			for j: int in count_b:
				var sm: Image = (imgs[j] as Image).duplicate() as Image
				sm.convert(Image.FORMAT_L8)
				sm.resize(RifePlan.SCENE_W, RifePlan.SCENE_H, Image.INTERPOLATE_BILINEAR)
				small.append(sm)
		at += count_b
		_report(DECODE_SHARE * float(at) / float(n_in), "decode")
	var decode_ms: int = Time.get_ticks_msec() - t0
	var count: int = RifePlan.output_count(inputs, factor)
	var asked: int = RifePlan.asked_count(inputs, factor)
	var args: PackedStringArray = RifeTool.dir_args(cache.in_dir(key), cache.out_dir(key), asked, String(job.get("model", RifeTool.DEFAULT_MODEL)), int(job.get("gpu", -2)), bool(job.get("uhd", false)))
	var pid: int = OS.create_process(exe, args, false)
	if pid <= 0:
		return _abandon(cache, key, job, "rife-ncnn-vulkan did not start")
	_mutex.lock()
	_pid = pid
	_mutex.unlock()
	_report(DECODE_SHARE, "rife")
	while OS.is_process_running(pid):
		if cancelled():
			OS.kill(pid)
			return _abandon(cache, key, job, "cancelled")
		OS.delay_msec(POLL_MS)
		var made: int = DirAccess.get_files_at(cache.out_dir(key)).size()
		_report(DECODE_SHARE + (1.0 - DECODE_SHARE) * 0.95 * float(made) / float(asked), "rife")
	_mutex.lock()
	_pid = -1
	_mutex.unlock()
	var code: int = OS.get_process_exit_code(pid)
	var outs: int = DirAccess.get_files_at(cache.out_dir(key)).size()
	if outs < asked:
		return _abandon(cache, key, job, "rife-ncnn-vulkan stopped early (exit %d, %d of %d frames); try the CPU or another GPU in Settings" % [code, outs, asked])
	for j: int in range(count, asked):
		DirAccess.remove_absolute(cache.frame_path(key, j))
	var cuts: Array = []
	if scene != RifePlan.SCENE_OFF and small.size() == n_in:
		for i: int in n_in - 1:
			var d: float = RifePlan.scene_diff(small[i], small[i + 1])
			if RifePlan.is_cut(d):
				cuts.append(i)
				_fill_cut(cache, key, i, factor, scene)
	if not bool(job.get("keep_ends", false)):
		for j: int in range(0, count, factor):
			DirAccess.remove_absolute(cache.frame_path(key, j))
		RifeCache.remove_tree(cache.in_dir(key))
	var bytes: int = RifeCache.dir_bytes(cache.entry_dir(key))
	var info: Dictionary = {"key": key, "bytes": bytes, "count": count, "factor": factor, "cuts": cuts, "inputs": [inputs.x, inputs.y], "fps": fps, "used": int(Time.get_unix_time_from_system()), "media": String(job.get("media_path", ""))}
	cache.write_done(key, info)
	_report(1.0, "done")
	var out: Dictionary = info.duplicate()
	out["ok"] = true
	out["why"] = ""
	out["ms"] = Time.get_ticks_msec() - t0
	out["decode_ms"] = decode_ms
	out["runs"] = runs
	return out


static func save_all(imgs: Array, dir: String, first: int) -> bool:
	var errors: Array = [0]
	var lock: Mutex = Mutex.new()
	var one: Callable = func(j: int) -> void:
		var err: Error = (imgs[j] as Image).save_png(dir.path_join("%08d.png" % (first + j + 1)))
		if err != OK:
			lock.lock()
			errors[0] = int(errors[0]) + 1
			lock.unlock()
	var task: int = WorkerThreadPool.add_group_task(one, imgs.size(), SAVE_THREADS, false, "Purrframes frames")
	WorkerThreadPool.wait_for_group_task_completion(task)
	return int(errors[0]) == 0


func _fill_cut(cache: RifeCache, key: String, pair: int, factor: int, scene: String) -> void:
	var a_path: String = cache.in_dir(key).path_join("%08d.png" % (pair + 1))
	var b_path: String = cache.in_dir(key).path_join("%08d.png" % (pair + 2))
	var a: Image = Image.load_from_file(a_path)
	var b: Image = Image.load_from_file(b_path)
	if a == null or b == null:
		return
	for q: int in range(1, factor):
		var idx: int = pair * factor + q
		var amount: float = float(q) / float(factor)
		var img: Image = null
		if scene == RifePlan.SCENE_BLEND:
			img = RifePlan.blend_images(a, b, amount)
		else:
			img = a if amount < 0.5 else b
		img.save_png(cache.frame_path(key, idx))


func _abandon(cache: RifeCache, key: String, job: Dictionary, why: String) -> Dictionary:
	RifeCache.remove_tree(cache.entry_dir(key))
	_report(0.0, "failed")
	return fail(job, why)

extends RefCounted

const Swatch := preload("res://modules/core_panels/bin_views/swatch.gd")
const MAX_RUNNING := 3

var _queue: Array[Dictionary] = []
var _queued: Dictionary = {}
var _running: Dictionary = {}
var _running_keys: Dictionary = {}


func request_load(key: String, path: String, width: int, front: bool = true) -> void:
	_add({"kind": "load", "key": key, "path": path, "width": width}, front)


func request_swatch(key: String, image: Image) -> void:
	if image == null:
		return
	_add({"kind": "swatch", "key": key, "image": image}, false)


func _add(job: Dictionary, front: bool) -> void:
	var key: String = String(job["key"]) + "|" + String(job["kind"])
	if _queued.has(key) or _running_keys.has(key):
		return
	_queued[key] = true
	if front:
		_queue.push_front(job)
	else:
		_queue.push_back(job)
	_pump()


func is_waiting(key: String, kind: String = "load") -> bool:
	var k: String = key + "|" + kind
	return _queued.has(k) or _running_keys.has(k)


func pending() -> bool:
	return not _queue.is_empty() or not _running.is_empty()


func running() -> int:
	return _running.size()


func queued() -> int:
	return _queue.size()


func _pump() -> void:
	while _running.size() < MAX_RUNNING and not _queue.is_empty():
		var job: Dictionary = _queue.pop_front()
		var key: String = String(job["key"]) + "|" + String(job["kind"])
		_queued.erase(key)
		var box: Array = []
		var task: int = -1
		if String(job["kind"]) == "load":
			task = WorkerThreadPool.add_task(_load_work.bind(String(job["path"]), int(job["width"]), box), false, "Bin picture")
		else:
			task = WorkerThreadPool.add_task(_swatch_work.bind(job["image"] as Image, box), false, "Bin colour")
		_running[task] = {"key": String(job["key"]), "kind": String(job["kind"]), "box": box}
		_running_keys[key] = task


func _load_work(path: String, width: int, box: Array) -> void:
	var img: Image = Image.new()
	if img.load(path) != OK or img.is_empty():
		box.append({"image": null, "swatch": {}})
		return
	if img.is_compressed():
		img.decompress()
	if img.get_width() > width:
		img.resize(width, maxi(1, int(float(img.get_height()) * float(width) / float(img.get_width()))), Image.INTERPOLATE_BILINEAR)
	box.append({"image": img, "swatch": Swatch.from_image(img)})


func _swatch_work(image: Image, box: Array) -> void:
	box.append({"image": null, "swatch": Swatch.from_image(image)})


func poll() -> Array[Dictionary]:
	var done: Array[Dictionary] = []
	if _running.is_empty():
		return done
	for task: Variant in _running.keys():
		var id: int = int(task)
		if not WorkerThreadPool.is_task_completed(id):
			continue
		WorkerThreadPool.wait_for_task_completion(id)
		var rec: Dictionary = _running[id]
		_running.erase(id)
		_running_keys.erase(String(rec["key"]) + "|" + String(rec["kind"]))
		var box: Array = rec["box"]
		var res: Dictionary = box[0] if not box.is_empty() and box[0] is Dictionary else {"image": null, "swatch": {}}
		done.append({"key": String(rec["key"]), "kind": String(rec["kind"]), "image": res.get("image"), "swatch": res.get("swatch", {})})
	_pump()
	return done


func drop_queue() -> void:
	_queue.clear()
	_queued.clear()


func finish_all() -> void:
	drop_queue()
	for task: Variant in _running.keys():
		WorkerThreadPool.wait_for_task_completion(int(task))
	_running.clear()
	_running_keys.clear()

extends RefCounted

const SELF := preload("res://doc/asset_pack_watch.gd")
const AssetPacks := preload("res://doc/asset_packs.gd")
const FRESH_MS := 4000

static var _scans: Dictionary = {}
static var _task: int = -1
static var _result: Dictionary = {}
static var _mutex: Mutex = Mutex.new()
static var _waiting: Array[Dictionary] = []
static var _after: Array[Callable] = []
static var _job: int = -1
static var _version: int = 0


static func version() -> int:
	return _version


static func busy() -> bool:
	return _task >= 0


static func forget() -> void:
	_scans.clear()
	_version += 1


static func forget_one(pack_id: String) -> void:
	if _scans.has(pack_id):
		_scans.erase(pack_id)
		_version += 1


static func cached(pack_id: String) -> Dictionary:
	var rec: Variant = _scans.get(pack_id, null)
	if typeof(rec) != TYPE_DICTIONARY:
		return {}
	return rec


static func fresh(pack_id: String, age_ms: int = FRESH_MS) -> bool:
	var rec: Dictionary = cached(pack_id)
	if rec.is_empty():
		return false
	return Time.get_ticks_msec() - int(rec.get("when", 0)) <= age_ms


static func view_now(pack: Dictionary) -> Dictionary:
	if not AssetPacks.follows(pack):
		return AssetPacks.frozen_view(pack)
	return AssetPacks.view(pack, cached(String(pack.get("id", ""))), false)


static func scan_blocking(pack: Dictionary) -> Dictionary:
	if not AssetPacks.follows(pack):
		return AssetPacks.frozen_view(pack)
	var scan: Dictionary = AssetPacks.scan_pack(pack)
	_scans[String(pack.get("id", ""))] = scan
	_version += 1
	return AssetPacks.view(pack, scan, false)


static func followed(packs: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in packs:
		if AssetPacks.follows(p):
			out.append(p)
	return out


static func start(packs: Array[Dictionary], after: Callable = Callable()) -> bool:
	var want: Array[Dictionary] = followed(packs)
	if after.is_valid():
		_after.append(after)
	if want.is_empty():
		if _task < 0:
			_ring()
		return false
	if _task >= 0:
		for p: Dictionary in want:
			_waiting.append(p)
		return true
	AssetPacks.loader_script()
	var jobs: Node = _node("/root/Jobs")
	if jobs != null and jobs.has_method("add_local"):
		_job = int(jobs.call("add_local", "Checking asset package folders", "app"))
	var light: Array = []
	for p: Dictionary in want:
		light.append({"id": String(p.get("id", "")), "payload": AssetPacks.payload_of(p).duplicate(true), "kind": AssetPacks.KIND})
	_task = WorkerThreadPool.add_task(Callable(SELF, "_work").bind(light), false, "Asset package folders")
	return true


static func refresh_all(packs: Array[Dictionary]) -> bool:
	return start(packs)


static func with_view(pack: Dictionary, after: Callable) -> void:
	if not AssetPacks.follows(pack):
		if after.is_valid():
			after.call(AssetPacks.frozen_view(pack))
		return
	var id: String = String(pack.get("id", ""))
	if fresh(id):
		if after.is_valid():
			after.call(AssetPacks.view(pack, cached(id), false))
		return
	var one: Array[Dictionary] = [pack]
	start(one, func() -> void:
		if after.is_valid():
			after.call(AssetPacks.view(pack, cached(id), false)))


static func _work(packs: Array) -> void:
	var out: Dictionary = {}
	for p: Variant in packs:
		if not (p is Dictionary):
			continue
		var one: Dictionary = p
		out[String(one.get("id", ""))] = AssetPacks.scan_pack(one)
	_mutex.lock()
	for key: Variant in out.keys():
		_result[key] = out[key]
	_mutex.unlock()
	Callable(SELF, "_land").call_deferred()


static func _node(path: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(path)
	return null


static func _land() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_mutex.lock()
	var got: Dictionary = _result.duplicate(true)
	_result.clear()
	_mutex.unlock()
	for key: Variant in got.keys():
		_scans[key] = got[key]
	_version += 1
	var jobs: Node = _node("/root/Jobs")
	if _job >= 0 and jobs != null and jobs.has_method("done_local"):
		jobs.call("done_local", _job, true)
	_job = -1
	if not _waiting.is_empty():
		var next: Array[Dictionary] = _waiting.duplicate()
		_waiting.clear()
		start(next)
		return
	_ring()


static func _ring() -> void:
	var calls: Array[Callable] = _after.duplicate()
	_after.clear()
	for c: Callable in calls:
		if c.is_valid():
			c.call()

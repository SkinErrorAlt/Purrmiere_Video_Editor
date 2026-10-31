extends Node

signal changed
signal job_done(id: int, ok: bool)

const POLL_INTERVAL := 0.25

var _engine_jobs: Array[Dictionary] = []
var _local_jobs: Array[Dictionary] = []
var _next_local_id: int = 100000
var _accum: float = 0.0
var _all: Array[Dictionary] = []
var _all_stale: bool = true


func _ready() -> void:
	set_process(true)


func _process(dt: float) -> void:
	_accum += dt
	if _accum < POLL_INTERVAL:
		return
	_accum = 0.0
	_poll_engine()


func _poll_engine() -> void:
	var bridge: Node = get_node_or_null("/root/PurrBridge")
	if bridge == null or not bridge.has_method("jobs"):
		return
	var raw: Array = bridge.jobs()
	var fresh: Array[Dictionary] = []
	for item: Variant in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		fresh.append(_sanitise(item))
	var differs: bool = fresh.size() != _engine_jobs.size()
	if not differs:
		for i: int in range(fresh.size()):
			if fresh[i] != _engine_jobs[i]:
				differs = true
				break
	if differs:
		_engine_jobs = fresh
		_all_stale = true
		changed.emit()


func _sanitise(d: Dictionary) -> Dictionary:
	return {
		"id": int(d.get("id", -1)),
		"kind": String(d.get("kind", "engine")),
		"label": String(d.get("label", "")),
		"progress": clampf(float(d.get("progress", 0.0)), 0.0, 1.0),
		"state": String(d.get("state", "running")),
		"local": false,
	}


func add_local(label: String, kind: String = "app") -> int:
	var id: int = _next_local_id
	_next_local_id += 1
	_local_jobs.append({"id": id, "kind": kind, "label": label, "progress": 0.0, "state": "running", "local": true})
	_all_stale = true
	changed.emit()
	return id


func update_local(id: int, progress: float) -> void:
	for j: Dictionary in _local_jobs:
		if int(j["id"]) == id:
			j["progress"] = clampf(progress, 0.0, 1.0)
			_all_stale = true
			changed.emit()
			return


func done_local(id: int, ok: bool = true) -> void:
	for i: int in range(_local_jobs.size()):
		if int(_local_jobs[i]["id"]) == id:
			_local_jobs.remove_at(i)
			_all_stale = true
			job_done.emit(id, ok)
			changed.emit()
			return


func cancel(id: int) -> void:
	for i: int in range(_local_jobs.size()):
		if int(_local_jobs[i]["id"]) == id:
			_local_jobs.remove_at(i)
			_all_stale = true
			job_done.emit(id, false)
			changed.emit()
			return
	var bridge: Node = get_node_or_null("/root/PurrBridge")
	if bridge != null and bridge.has_method("cancel_job"):
		bridge.cancel_job(id)


func list() -> Array[Dictionary]:
	if not _all_stale:
		return _all
	var out: Array[Dictionary] = []
	for j: Dictionary in _engine_jobs:
		out.append(j)
	for j: Dictionary in _local_jobs:
		out.append(j)
	_all = out
	_all_stale = false
	return _all


func summary() -> String:
	var all: Array[Dictionary] = list()
	if all.is_empty():
		return "No jobs"
	var total: float = 0.0
	for j: Dictionary in all:
		total += float(j["progress"])
	var pct: int = int(round(100.0 * total / float(all.size())))
	if all.size() == 1:
		return String(all[0]["label"]) + " " + str(pct) + "%"
	return str(all.size()) + " jobs " + str(pct) + "%"

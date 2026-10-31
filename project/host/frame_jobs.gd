extends RefCounted

const SELF := preload("res://host/frame_jobs.gd")
const Project := preload("res://doc/project.gd")
const MAX_WAIT_FRAMES := 4
const BUDGET_US := 6000

static var _jobs: Array[Dictionary] = []
static var _keys: Dictionary = {}
static var _hooked: bool = false
static var ran: int = 0
static var skipped_busy: int = 0
static var plant_same_frame: bool = false
static var slow: PackedStringArray = PackedStringArray()
const SLOW_US := 2000
const SLOW_KEEP := 64


static func add(key: String, cb: Callable, next_frame: bool = false) -> void:
	if plant_same_frame:
		if cb.is_valid():
			cb.call()
		return
	var at: int = int(_keys.get(key, -1))
	if at >= 0 and at < _jobs.size() and String(_jobs[at]["key"]) == key:
		_jobs[at]["cb"] = cb
	else:
		_keys[key] = _jobs.size()
		_jobs.append({"key": key, "cb": cb, "since": Engine.get_process_frames(), "after": Engine.get_process_frames() if next_frame else -1})
	_hook()


static func pending(key: String) -> bool:
	return _keys.has(key)


static func busy_now() -> bool:
	return Project.change_frame == Engine.get_process_frames()


static func run_all() -> void:
	while not _jobs.is_empty():
		_run_one()


static func _hook() -> void:
	if _hooked:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_hooked = true
	tree.process_frame.connect(Callable(SELF, "_tick"))


static func _run_at(i: int) -> void:
	var j: Dictionary = _jobs[i]
	_jobs.remove_at(i)
	_keys.clear()
	for k: int in _jobs.size():
		_keys[String(_jobs[k]["key"])] = k
	var cb: Callable = j["cb"]
	ran += 1
	if not cb.is_valid():
		return
	var t0: int = Time.get_ticks_usec()
	cb.call()
	note(String(j["key"]).get_slice("|", 0), Time.get_ticks_usec() - t0)


static func note(label: String, us: int) -> void:
	if us < SLOW_US:
		return
	if slow.size() >= SLOW_KEEP:
		slow.remove_at(0)
	slow.append("%s %.1f ms" % [label, us / 1000.0])


static func take_slow() -> PackedStringArray:
	var out: PackedStringArray = slow
	slow = PackedStringArray()
	return out


static func _run_one() -> void:
	_run_at(0)


static func _tick() -> void:
	if _jobs.is_empty():
		return
	var frame: int = Engine.get_process_frames()
	if busy_now() and frame - int(_jobs[0]["since"]) < MAX_WAIT_FRAMES:
		skipped_busy += 1
		return
	var due: Array[Dictionary] = []
	for j: Dictionary in _jobs:
		if int(j["after"]) < frame:
			due.append(j)
	var t0: int = Time.get_ticks_usec()
	var n: int = 0
	for j2: Dictionary in due:
		if n > 0 and Time.get_ticks_usec() - t0 >= BUDGET_US and frame - int(j2["since"]) < MAX_WAIT_FRAMES:
			continue
		var i: int = _jobs.find(j2)
		if i >= 0:
			_run_at(i)
			n += 1

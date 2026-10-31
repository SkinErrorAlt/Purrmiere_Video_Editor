extends Node

const ROOTS: PackedStringArray = ["res://doc", "res://engine", "res://modules", "res://ui", "res://host", "res://effects"]
const SKIP: PackedStringArray = ["res://tools", "res://addons"]
const BUDGET_US := 2000
const START_DELAY_S := 2.0

var queue: PackedStringArray = PackedStringArray()
var loaded: int = 0
var done: bool = false
var _wait: float = START_DELAY_S


static func gather(dir: String, out: PackedStringArray) -> void:
	for skip: String in SKIP:
		if dir.begins_with(skip):
			return
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub: String in DirAccess.get_directories_at(dir):
		gather(dir.path_join(sub), out)


func _ready() -> void:
	name = "ScriptWarmer"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for r: String in ROOTS:
		if DirAccess.dir_exists_absolute(r):
			gather(r, queue)


func _process(delta: float) -> void:
	if done:
		set_process(false)
		return
	if _wait > 0.0:
		_wait -= delta
		return
	if Input.get_mouse_button_mask() != 0:
		return
	var t0: int = Time.get_ticks_usec()
	while not queue.is_empty() and Time.get_ticks_usec() - t0 < BUDGET_US:
		var p: String = queue[queue.size() - 1]
		queue.remove_at(queue.size() - 1)
		if not ResourceLoader.has_cached(p):
			load(p)
			loaded += 1
			break
	if queue.is_empty():
		done = true

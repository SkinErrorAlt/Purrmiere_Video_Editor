extends RefCounted

const ROOTS: PackedStringArray = ["res://host", "res://doc", "res://engine", "res://ui", "res://modules"]
const FORCE_ENV := "PURR_SCRIPT_WARM"

static var started: bool = false
static var requested: PackedStringArray = PackedStringArray()


static func _walk(dir: String, out: PackedStringArray) -> void:
	var da: DirAccess = DirAccess.open(dir)
	if da == null:
		return
	da.list_dir_begin()
	var e: String = da.get_next()
	while not e.is_empty():
		var full: String = dir.path_join(e)
		if da.current_is_dir():
			if not e.begins_with("."):
				_walk(full, out)
		elif e.ends_with(".gd"):
			out.append(full)
		elif e.ends_with(".gd.remap"):
			out.append(full.trim_suffix(".remap"))
		e = da.get_next()
	da.list_dir_end()


static func scripts() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for r: String in ROOTS:
		_walk(r, out)
	return out


static func start() -> int:
	if started:
		return requested.size()
	if Prefs.running_suite() and OS.get_environment(FORCE_ENV) != "1":
		return 0
	started = true
	for path: String in scripts():
		if ResourceLoader.has_cached(path):
			continue
		if ResourceLoader.load_threaded_request(path, "GDScript", false) == OK:
			requested.append(path)
	return requested.size()


static func pending() -> int:
	var n: int = 0
	for path: String in requested:
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			n += 1
	return n

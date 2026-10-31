extends RefCounted

const Io := preload("res://doc/io.gd")
const FILE := "regions.json"
const DIR := "organizer"
const VERSION := 1
const SAVE_DELAY_MS := 400

static var _cache: Dictionary = {}
static var _loaded: bool = false
static var _override_path: String = ""
static var _keys: Dictionary = {}
static var _dirty: bool = false
static var _save_due_ms: int = -1
static var _timer_armed: bool = false
static var serial: int = 0
static var writes: int = 0


static func path() -> String:
	if not _override_path.is_empty():
		return _override_path
	return Io.data_path(DIR).path_join(FILE)


static func use_path(p: String) -> void:
	flush()
	_override_path = p
	_loaded = false
	_cache = {}
	serial += 1


static func key_of(file_path: String) -> String:
	if file_path.is_empty():
		return ""
	var hit: Variant = _keys.get(file_path, null)
	if hit is String:
		return hit
	var k: String = file_path.replace("\\", "/").simplify_path()
	if OS.get_name() == "Windows" or OS.get_name() == "macOS":
		k = k.to_lower()
	_keys[file_path] = k
	return k


static func store() -> Dictionary:
	if _loaded:
		return _cache
	var d: Dictionary = Io.read_json(path())
	if d.is_empty() or not (d.get("files") is Dictionary):
		d = {"version": VERSION, "files": {}}
	_cache = d
	_loaded = true
	return _cache


static func files() -> Dictionary:
	return store()["files"]


static func has(file_path: String) -> bool:
	var k: String = key_of(file_path)
	return not k.is_empty() and files().has(k)


static func entry(file_path: String) -> Dictionary:
	var k: String = key_of(file_path)
	if k.is_empty():
		return {}
	var e: Variant = files().get(k, null)
	return e if e is Dictionary else {}


static func regions(file_path: String) -> Array:
	var e: Dictionary = entry(file_path)
	var r: Variant = e.get("regions", [])
	return r if r is Array else []


static func put(file_path: String, list: Array, facts: Dictionary = {}) -> void:
	var k: String = key_of(file_path)
	if k.is_empty():
		return
	var all: Dictionary = files()
	var e: Dictionary = all.get(k, {}) if all.get(k) is Dictionary else {}
	e["path"] = file_path
	e["regions"] = list.duplicate(true)
	for f: Variant in facts.keys():
		e[f] = facts[f]
	if list.is_empty() and not e.has("keep"):
		all.erase(k)
	else:
		all[k] = e
	_mark()


static func set_fact(file_path: String, field: String, value: Variant) -> void:
	var k: String = key_of(file_path)
	if k.is_empty():
		return
	var all: Dictionary = files()
	var e: Dictionary = all.get(k, {}) if all.get(k) is Dictionary else {"path": file_path, "regions": []}
	if value == null:
		e.erase(field)
	else:
		e[field] = value
	all[k] = e
	_mark()


static func fact(file_path: String, field: String, fallback: Variant) -> Variant:
	return entry(file_path).get(field, fallback)


static func paths() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in files().keys():
		var e: Variant = files()[k]
		if e is Dictionary:
			out.append(String((e as Dictionary).get("path", String(k))))
	return out


static func _mark() -> void:
	_dirty = true
	serial += 1
	_save_due_ms = Time.get_ticks_msec() + SAVE_DELAY_MS
	_arm()


static func _arm() -> void:
	if _timer_armed:
		return
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	_timer_armed = true
	(loop as SceneTree).create_timer(float(SAVE_DELAY_MS) / 1000.0).timeout.connect(_on_timer)


static func _on_timer() -> void:
	_timer_armed = false
	if not _dirty:
		return
	if Time.get_ticks_msec() < _save_due_ms:
		_arm()
		return
	flush()


static func flush() -> bool:
	if not _dirty or not _loaded:
		return true
	_dirty = false
	var d: Dictionary = _cache
	d["version"] = VERSION
	DirAccess.make_dir_recursive_absolute(path().get_base_dir())
	writes += 1
	return Io.write_atomic(path(), JSON.stringify(d, "", false, true), true) == OK


static func reread() -> void:
	flush()
	_loaded = false
	_cache = {}
	serial += 1

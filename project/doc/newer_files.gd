extends RefCounted

const Migrations := preload("res://doc/migrations.gd")

const OLD_STAMP := 1

static var _held: Dictionary = {}
static var _lock: Mutex = Mutex.new()
static var plant_old_build: bool = false


static func stamp() -> int:
	return OLD_STAMP if plant_old_build else Migrations.CURRENT_VERSION


static func key(path: String) -> String:
	var abs_path: String = ProjectSettings.globalize_path(path).simplify_path()
	if OS.get_name() == "Windows":
		return abs_path.replace("\\", "/").to_lower()
	return abs_path


static func is_newer(d: Dictionary) -> bool:
	return Migrations.version_of(d) > Migrations.CURRENT_VERSION


static func note_loaded(path: String, d: Dictionary) -> String:
	if plant_old_build:
		return ""
	if path.is_empty():
		return opened_text(Migrations.version_of(d)) if is_newer(d) else ""
	var k: String = key(path)
	_lock.lock()
	if is_newer(d):
		_held[k] = Migrations.version_of(d)
	else:
		_held.erase(k)
	_lock.unlock()
	return opened_text(Migrations.version_of(d)) if is_newer(d) else ""


static func version_held(path: String) -> int:
	if path.is_empty() or plant_old_build:
		return 0
	var k: String = key(path)
	_lock.lock()
	var v: int = int(_held.get(k, 0))
	_lock.unlock()
	return v


static func is_held(path: String) -> bool:
	return version_held(path) > 0


static func release(path: String) -> void:
	_lock.lock()
	_held.erase(key(path))
	_lock.unlock()


static func release_all() -> void:
	_lock.lock()
	_held.clear()
	_lock.unlock()


static func opened_text(version: int) -> String:
	return "This project was saved by a newer version of Purrmiere (file version %d; this version reads up to %d). It is open so you can look and keep working, but this version will not save over it, because anything the newer version added would be lost. Use Save As to keep your changes in a new file, or update Purrmiere." % [version, Migrations.CURRENT_VERSION]


static func refused_text(path: String) -> String:
	return "%s was saved by a newer version of Purrmiere (file version %d; this version reads up to %d), so this version will not save over it and lose what the newer one added. Use Save As to save your changes to a new file, or update Purrmiere." % [path.get_file(), version_held(path), Migrations.CURRENT_VERSION]

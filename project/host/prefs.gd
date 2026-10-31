extends Node

signal changed(key: String)

const POINTER := "user://data_dir.txt"
const FOLDER_NAME := "Purrmiere"
const SETTINGS_FILE := "settings.json"
const LEGACY_PATH := "user://prefs.json"
const MIGRATE_DIRS: PackedStringArray = ["layouts", "presets", "effects", "modules", "snapshots"]
const SUITE_ROOT := "user://purrtest/data"
const SUITE_MARK := "suite_started.txt"
const SUITE_KEEP_SECONDS := 21600
const SUITE_DEAD_KEEP_SECONDS := 600
const SUITE_HEARTBEAT_SECONDS := 60.0
const REAL_DATA_ENV := "PURR_REAL_DATA"
const AUTOMATION_FLAGS: PackedStringArray = ["--shot", "--layout-dump", "--headless-tests", "--probe-import", "--route", "--purr-test"]
const CACHE_POINTER := "user://cache_dir.txt"
const CACHE_SUB := "cache"
const SYNCED_MARKERS: PackedStringArray = ["onedrive", "dropbox", "google drive", "icloud", "/box/", "\\box\\"]

var _data_dir: String = ""
var _cache_dir: String = ""
var _defaults: Dictionary = {}
var _specs: Dictionary = {}
var _values: Dictionary = {}
var _stored: Dictionary = {}
var _dirty: bool = false
var _save_queued: bool = false
var _loaded: bool = false
const LOUD_WINDOW_ENV := "PURR_LOUD_WINDOW"


func _ready() -> void:
	_resolve_data_dir()
	if not running_suite():
		_migrate()
	_load()
	_quiet_suite_window()
	_start_suite_heartbeat()


func _start_suite_heartbeat() -> void:
	if not running_suite() or not _data_dir.begins_with(ProjectSettings.globalize_path(SUITE_ROOT)):
		return
	var beat := Timer.new()
	beat.name = "SuiteHeartbeat"
	beat.wait_time = SUITE_HEARTBEAT_SECONDS
	beat.autostart = true
	beat.timeout.connect(_suite_heartbeat)
	add_child(beat)


func _suite_heartbeat() -> void:
	var mark := FileAccess.open(_data_dir.path_join(SUITE_MARK), FileAccess.WRITE)
	if mark != null:
		mark.store_string(str(Time.get_unix_time_from_system()))
		mark.close()


func _quiet_suite_window() -> void:
	if not running_suite() or OS.get_environment(LOUD_WINDOW_ENV) == "1":
		return
	if DisplayServer.get_name() == "headless":
		return
	var w: Window = get_window()
	if w == null:
		return
	w.set_flag(Window.FLAG_NO_FOCUS, true)
	if w.has_method("set_unfocusable"):
		w.set("unfocusable", true)


static func running_suite() -> bool:
	if not OS.get_environment(REAL_DATA_ENV).is_empty():
		return false
	var loop: MainLoop = Engine.get_main_loop()
	if loop != null and loop.get_script() != null:
		return true
	return is_automation(OS.get_cmdline_args()) or is_automation(OS.get_cmdline_user_args())


static func is_automation(args: PackedStringArray) -> bool:
	for a: String in args:
		for flag: String in AUTOMATION_FLAGS:
			if a == flag or a.begins_with(flag + "="):
				return true
	return false


static func suite_data_dir() -> String:
	var root: String = ProjectSettings.globalize_path(SUITE_ROOT)
	_prune_suite_dirs(root)
	var dir: String = root.path_join(str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(dir)
	var mark := FileAccess.open(dir.path_join(SUITE_MARK), FileAccess.WRITE)
	if mark != null:
		mark.store_string(str(Time.get_unix_time_from_system()))
		mark.close()
	return dir


static func _prune_suite_dirs(root: String) -> void:
	var d: DirAccess = DirAccess.open(root)
	if d == null:
		return
	var now: float = Time.get_unix_time_from_system()
	for name_: String in d.get_directories():
		var dir: String = root.path_join(name_)
		var mark: String = dir.path_join(SUITE_MARK)
		var born: float = float(FileAccess.get_modified_time(mark)) if FileAccess.file_exists(mark) else 0.0
		if now - born > float(SUITE_KEEP_SECONDS) or (now - born > float(SUITE_DEAD_KEEP_SECONDS) and name_.is_valid_int() and int(name_) != OS.get_process_id()):
			_remove_tree(dir)


static func suite_dir_dead(name_: String) -> bool:
	if not name_.is_valid_int():
		return false
	var pid: int = int(name_)
	if pid == OS.get_process_id():
		return false
	return not OS.is_process_running(pid)


static func _remove_tree(dir: String) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	for sub: String in d.get_directories():
		_remove_tree(dir.path_join(sub))
	for f: String in d.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


static func default_data_dir() -> String:
	var docs: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs.is_empty():
		return ProjectSettings.globalize_path("user://data")
	return docs.path_join(FOLDER_NAME)


func _resolve_data_dir() -> void:
	if running_suite():
		_data_dir = suite_data_dir()
		return
	var want: String = ""
	if FileAccess.file_exists(POINTER):
		want = FileAccess.get_file_as_string(POINTER).strip_edges()
	if want.is_empty():
		want = default_data_dir()
	if DirAccess.make_dir_recursive_absolute(want) != OK and not DirAccess.dir_exists_absolute(want):
		print("Prefs: could not create the data folder " + want + ", using user://")
		want = ProjectSettings.globalize_path("user://data")
		DirAccess.make_dir_recursive_absolute(want)
	_data_dir = want


func data_dir() -> String:
	if _data_dir.is_empty():
		_resolve_data_dir()
	return _data_dir


func data_path(sub: String) -> String:
	var out: String = data_dir().path_join(sub)
	return out


func ensure_dir(sub: String) -> String:
	var out: String = data_path(sub)
	DirAccess.make_dir_recursive_absolute(out)
	return out


static func is_synced_folder(path: String) -> bool:
	var low: String = path.to_lower().replace("\\", "/")
	for mark: String in SYNCED_MARKERS:
		if low.contains(mark.replace("\\", "/")):
			return true
	return false


static func local_cache_root() -> String:
	var local: String = OS.get_environment("LOCALAPPDATA").strip_edges()
	if not local.is_empty() and DirAccess.dir_exists_absolute(local):
		return local.replace("\\", "/").path_join(FOLDER_NAME).path_join(CACHE_SUB)
	var c: String = OS.get_cache_dir().strip_edges()
	if not c.is_empty():
		return c.replace("\\", "/").path_join(FOLDER_NAME).path_join(CACHE_SUB)
	return ProjectSettings.globalize_path("user://" + CACHE_SUB)


func cache_dir() -> String:
	if not _cache_dir.is_empty():
		return _cache_dir
	_cache_dir = _resolve_cache_dir()
	DirAccess.make_dir_recursive_absolute(_cache_dir)
	return _cache_dir


static func cache_target_for(legacy: String) -> String:
	if legacy.is_empty() or not is_synced_folder(legacy):
		return legacy
	var fresh: String = local_cache_root()
	if is_synced_folder(fresh):
		return legacy
	return fresh


func _resolve_cache_dir() -> String:
	var legacy: String = data_path(CACHE_SUB)
	if running_suite():
		return legacy
	if FileAccess.file_exists(CACHE_POINTER):
		var want: String = FileAccess.get_file_as_string(CACHE_POINTER).strip_edges()
		if not want.is_empty() and (DirAccess.dir_exists_absolute(want) or DirAccess.make_dir_recursive_absolute(want) == OK):
			return want
	var fresh: String = cache_target_for(legacy)
	if fresh == legacy:
		return legacy
	if DirAccess.make_dir_recursive_absolute(fresh.get_base_dir()) != OK and not DirAccess.dir_exists_absolute(fresh.get_base_dir()):
		return legacy
	if DirAccess.dir_exists_absolute(legacy) and not DirAccess.dir_exists_absolute(fresh):
		if DirAccess.rename_absolute(legacy, fresh) != OK:
			print("Prefs: the media cache is in a synced folder and could not be moved out of it, leaving it at " + legacy)
			return legacy
		print("Prefs: moved the media cache out of a synced folder, from " + legacy + " to " + fresh)
	DirAccess.make_dir_recursive_absolute(fresh)
	var note: FileAccess = FileAccess.open(CACHE_POINTER, FileAccess.WRITE)
	if note != null:
		note.store_string(fresh)
		note.close()
	return fresh


func set_cache_dir_path(path: String) -> bool:
	var target: String = path.strip_edges()
	if target.is_empty():
		return false
	if DirAccess.make_dir_recursive_absolute(target) != OK and not DirAccess.dir_exists_absolute(target):
		return false
	_cache_dir = target
	var note: FileAccess = FileAccess.open(CACHE_POINTER, FileAccess.WRITE)
	if note != null:
		note.store_string(target)
		note.close()
	var bridge: Node = get_node_or_null("/root/PurrBridge")
	if bridge != null and bridge.has_method("set_cache_dir"):
		bridge.call("set_cache_dir", target)
	return true


func set_data_dir(path: String) -> bool:
	var target: String = path.strip_edges()
	if target.is_empty():
		return false
	if DirAccess.make_dir_recursive_absolute(target) != OK and not DirAccess.dir_exists_absolute(target):
		return false
	if not FileAccess.file_exists(target.path_join(SETTINGS_FILE)):
		_copy_tree(data_dir(), target, target)
	if running_suite():
		_data_dir = target
		return true
	var f := FileAccess.open(POINTER, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(target)
	f.close()
	_data_dir = target
	return true


func _copy_tree(from: String, to: String, skip: String = "") -> void:
	if from == to or from == skip or not DirAccess.dir_exists_absolute(from):
		return
	DirAccess.make_dir_recursive_absolute(to)
	var d: DirAccess = DirAccess.open(from)
	if d == null:
		return
	d.list_dir_begin()
	var name_: String = d.get_next()
	while not name_.is_empty():
		if name_ != "." and name_ != "..":
			var src: String = from.path_join(name_)
			var dst: String = to.path_join(name_)
			if d.current_is_dir():
				_copy_tree(src, dst, skip)
			elif not FileAccess.file_exists(dst):
				DirAccess.copy_absolute(src, dst)
		name_ = d.get_next()
	d.list_dir_end()


func _migrate() -> void:
	var settings: String = data_path(SETTINGS_FILE)
	if FileAccess.file_exists(settings):
		return
	if FileAccess.file_exists(LEGACY_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(LEGACY_PATH), settings)
	for sub: String in MIGRATE_DIRS:
		var legacy: String = ProjectSettings.globalize_path("user://" + sub)
		if DirAccess.dir_exists_absolute(legacy) and not DirAccess.dir_exists_absolute(data_path(sub)):
			_copy_tree(legacy, data_path(sub))


func settings_path() -> String:
	return data_path(SETTINGS_FILE)


func register(key: String, default: Variant, spec: Dictionary = {}) -> void:
	if key.is_empty():
		print("Prefs: refused to register an empty key")
		return
	if _defaults.has(key):
		return
	_defaults[key] = default
	_specs[key] = spec
	if _stored.has(key) and _same_type(_stored[key], default):
		_values[key] = _stored[key]
	else:
		_values[key] = default


func _same_type(a: Variant, b: Variant) -> bool:
	var ta: int = typeof(a)
	var tb: int = typeof(b)
	if ta == tb:
		return true
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		return true
	return false


func is_registered(key: String) -> bool:
	return _defaults.has(key)


func get_value(key: String) -> Variant:
	if not _defaults.has(key):
		print("Prefs: the key \"" + key + "\" is not registered, so there is nothing to read")
		return null
	var v: Variant = _values[key]
	var d: Variant = _defaults[key]
	if typeof(d) == TYPE_FLOAT and typeof(v) == TYPE_INT:
		return float(v)
	if typeof(d) == TYPE_INT and typeof(v) == TYPE_FLOAT:
		return int(v)
	return v


func set_value(key: String, v: Variant) -> void:
	if not _defaults.has(key):
		print("Prefs: the key \"" + key + "\" is not registered, so the value was not stored")
		return
	if not _same_type(v, _defaults[key]):
		print("Prefs: the value for \"" + key + "\" has the wrong type and was not stored")
		return
	if _values[key] == v:
		return
	_values[key] = v
	_stored[key] = v
	_dirty = true
	_queue_save()
	changed.emit(key)


func spec(key: String) -> Dictionary:
	if _specs.has(key):
		return _specs[key]
	return {}


func keys() -> PackedStringArray:
	var out := PackedStringArray()
	for k: String in _defaults.keys():
		out.append(k)
	out.sort()
	return out


func reset(key: String) -> void:
	if _defaults.has(key):
		set_value(key, _defaults[key])


func _queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	call_deferred("_flush")


func _flush() -> void:
	_save_queued = false
	if _dirty:
		save_now()


func save_now() -> bool:
	_dirty = false
	var merged: Dictionary = _stored.duplicate()
	for k: String in _values.keys():
		merged[k] = _values[k]
	var text: String = JSON.stringify(merged, "  ")
	return _write_atomic(text)


func _write_atomic(text: String) -> bool:
	if text.strip_edges().is_empty():
		print("Prefs: refused to write an empty file")
		return false
	var path: String = settings_path()
	var path_tmp: String = path + ".tmp"
	var path_bak: String = path + ".bak"
	var f := FileAccess.open(path_tmp, FileAccess.WRITE)
	if f == null:
		print("Prefs: could not open the temp file for writing at " + path_tmp)
		return false
	f.store_string(text)
	f.flush()
	f.close()
	if FileAccess.file_exists(path):
		var old := FileAccess.get_file_as_string(path)
		if not old.strip_edges().is_empty():
			var bak := FileAccess.open(path_bak, FileAccess.WRITE)
			if bak != null:
				bak.store_string(old)
				bak.flush()
				bak.close()
	var err: Error = DirAccess.rename_absolute(path_tmp, path)
	if err != OK:
		print("Prefs: rename failed with error ", err)
		return false
	return true


func _parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _load() -> void:
	var d: Dictionary = _parse_file(settings_path())
	if d.is_empty():
		d = _parse_file(settings_path() + ".bak")
	_stored = d
	_loaded = true
	for k: String in _defaults.keys():
		if _stored.has(k) and _same_type(_stored[k], _defaults[k]):
			_values[k] = _stored[k]


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if _dirty:
			save_now()

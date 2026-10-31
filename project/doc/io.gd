extends RefCounted

const Project := preload("res://doc/project.gd")
const Migrations := preload("res://doc/migrations.gd")
const Health := preload("res://doc/health.gd")
const EXT := ".purrmiere"
const SNAPSHOT_DIR := ".purrmiere_snapshots"
const SNAPSHOT_KEEP := 20
const SNAPSHOT_EXT := ".purrmiere.gz"
const PREF_RECENT := "projects.recent"
const PREF_RECENT_MAX := 20

const RECOVERY_DIR := "recovery"
const RECOVERY_SEP := "__"

static var _autosave: Dictionary = {}
static var last_error: String = ""
static var _bg_task: int = -1
static var _bg_out: Array = []
static var _bg_last: Dictionary = {}
static var _bg_path: String = ""
static var _bg_tag: Variant = null
static var _own_recovery: Dictionary = {}


static func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Prefs")
	return null


static func write_atomic(path: String, text: String, keep_bak: bool) -> Error:
	var r: Array = write_atomic_core(path, text, keep_bak)
	last_error = String(r[1])
	var err: Error = r[0]
	return err


static func write_atomic_core(path: String, text: String, keep_bak: bool) -> Array:
	if text.strip_edges().is_empty():
		return [ERR_INVALID_DATA, "refused to write an empty file to " + path]
	var dir: String = path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(_abs(dir)):
		var made: Error = DirAccess.make_dir_recursive_absolute(_abs(dir))
		if made != OK:
			return [made, "could not create " + dir]
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return [FileAccess.get_open_error(), "could not open " + tmp + " for writing"]
	f.store_string(text)
	f.flush()
	f.close()
	var written: FileAccess = FileAccess.open(tmp, FileAccess.READ)
	if written == null or written.get_length() == 0:
		if written != null:
			written.close()
		DirAccess.remove_absolute(_abs(tmp))
		return [ERR_FILE_CANT_WRITE, "the temp file came back empty"]
	written.close()
	var bak: String = path + ".bak"
	if FileAccess.file_exists(path):
		if keep_bak:
			if FileAccess.file_exists(bak):
				DirAccess.remove_absolute(_abs(bak))
			var moved: Error = DirAccess.rename_absolute(_abs(path), _abs(bak))
			if moved != OK:
				DirAccess.remove_absolute(_abs(tmp))
				return [moved, "could not move the previous file to " + bak]
		else:
			DirAccess.remove_absolute(_abs(path))
	var renamed: Error = DirAccess.rename_absolute(_abs(tmp), _abs(path))
	if renamed != OK:
		if keep_bak and FileAccess.file_exists(bak) and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(_abs(bak), _abs(path))
		return [renamed, "could not move the temp file over " + path]
	return [OK, ""]


static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	if path.ends_with(".gz"):
		var f: FileAccess = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
		if f == null:
			return ""
		var out: String = f.get_as_text()
		f.close()
		return out
	var text: String = FileAccess.get_file_as_string(path)
	return text


static func write_compressed(path: String, text: String) -> Error:
	last_error = ""
	var dir: String = path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(_abs(dir)):
		var made: Error = DirAccess.make_dir_recursive_absolute(_abs(dir))
		if made != OK:
			last_error = "could not create " + dir
			return made
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
	if f == null:
		last_error = "could not open " + tmp + " for writing"
		return FileAccess.get_open_error()
	f.store_string(text)
	f.flush()
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_abs(path))
	var renamed: Error = DirAccess.rename_absolute(_abs(tmp), _abs(path))
	if renamed != OK:
		last_error = "could not move the temp file over " + path
	return renamed


static func read_json(path: String) -> Dictionary:
	var text: String = read_text(path)
	if text.strip_edges().is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


static func project_dict(project: Project) -> Dictionary:
	var d: Dictionary = {"format_version": Project.FORMAT_VERSION}
	var body: Dictionary = project.to_dict()
	for k: Variant in body.keys():
		d[k] = body[k]
	return d


static func view_path(path: String) -> String:
	return path + ".view.json"


static func save(project: Project, path: String) -> Error:
	var err: Error = save_quiet(project, path)
	if err != OK:
		return err
	project.path = path
	project.dirty = false
	remember_recent(path)
	return OK


static func save_quiet(project: Project, path: String) -> Error:
	if project == null or path.is_empty():
		last_error = "nothing to save"
		return ERR_INVALID_PARAMETER
	wait_background()
	var text: String = JSON.stringify(project_dict(project), "\t", false, true)
	var err: Error = write_atomic(path, text, true)
	if err != OK:
		return err
	save_view(project, path)
	return OK


static func save_view(project: Project, path: String) -> Error:
	var text: String = JSON.stringify(project.view, "\t", false, true)
	if text.strip_edges().is_empty():
		text = "{}"
	return write_atomic(view_path(path), text, false)


static func load(path: String) -> Project:
	last_error = ""
	var d: Dictionary = read_json(path)
	if d.is_empty():
		d = read_json(path + ".bak")
		if d.is_empty():
			last_error = "could not read " + path + " or its .bak"
			return null
		print("Io: " + path + " was empty or unreadable, loaded the .bak instead")
	d = Migrations.migrate(d)
	var project: Project = Project.from_dict(d)
	project.path = path
	project.view = read_json(view_path(path))
	Health.check(project)
	Health.CutLinks.repair_chains(project)
	StreamOrdinals.repair(project)
	SpeedLength.rebase(project)
	project.dirty = false
	return project


const StreamOrdinals := preload("res://doc/stream_ordinals.gd")
const SpeedLength := preload("res://doc/speed_length.gd")


static func _safe_name(project: Project) -> String:
	var base: String = project.name if not project.name.is_empty() else project.id
	var out: String = ""
	for ch: String in base:
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "-" or ch == "_":
			out += ch
		else:
			out += "_"
	if out.is_empty():
		out = "project"
	return out


static func snapshot_dir(project: Project) -> String:
	if project.path.is_empty():
		return data_path("snapshots").path_join(project.id if not project.id.is_empty() else "untitled") + "/" + SNAPSHOT_DIR
	return project.path.get_base_dir().path_join(SNAPSHOT_DIR)


static func snapshot(project: Project) -> String:
	if project == null:
		return ""
	var dir: String = snapshot_dir(project)
	var stamp: String = Time.get_datetime_string_from_system(false, false).replace("-", "").replace(":", "").replace("T", "_")
	var base: String = _safe_name(project) + "_" + stamp
	var path: String = dir.path_join(base + SNAPSHOT_EXT)
	var n: int = 1
	while FileAccess.file_exists(path):
		path = dir.path_join(base + "_" + str(n) + SNAPSHOT_EXT)
		n += 1
	var text: String = JSON.stringify(project_dict(project), "", false, true)
	if write_compressed(path, text) != OK:
		return ""
	_prune_snapshots(project)
	return path


static func _snapshot_files(project: Project) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir_path: String = snapshot_dir(project)
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	var prefix: String = _safe_name(project) + "_"
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.begins_with(prefix) and (entry.ends_with(EXT) or entry.ends_with(SNAPSHOT_EXT)):
			out.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


static func _prune_snapshots(project: Project) -> void:
	var files: PackedStringArray = _snapshot_files(project)
	while files.size() > SNAPSHOT_KEEP:
		DirAccess.remove_absolute(_abs(files[0]))
		files.remove_at(0)


static func list_snapshots(project: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var files: PackedStringArray = _snapshot_files(project)
	for i: int in range(files.size() - 1, -1, -1):
		var p: String = files[i]
		out.append({"path": p, "name": p.get_file(), "modified": FileAccess.get_modified_time(p)})
	return out


static func count_clips(d: Dictionary) -> int:
	var n: int = 0
	for s: Variant in d.get("sequences", []):
		if not (s is Dictionary):
			continue
		for key: String in ["video_tracks", "audio_tracks"]:
			for t: Variant in (s as Dictionary).get(key, []):
				if t is Dictionary:
					var clips: Variant = (t as Dictionary).get("clips", [])
					if clips is Array:
						n += (clips as Array).size()
	return n


static func snapshot_info(path: String) -> Dictionary:
	var d: Dictionary = read_json(path)
	var seqs: Variant = d.get("sequences", [])
	var media: Variant = d.get("media", [])
	return {
		"path": path,
		"name": path.get_file(),
		"ok": not d.is_empty(),
		"modified": FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0,
		"project_name": str(d.get("name", "")),
		"clips": count_clips(d),
		"sequences": (seqs as Array).size() if seqs is Array else 0,
		"media": (media as Array).size() if media is Array else 0,
	}


static func load_snapshot(path: String) -> Project:
	last_error = ""
	var d: Dictionary = read_json(path)
	if d.is_empty():
		last_error = "could not read the snapshot " + path.get_file()
		return null
	d = Migrations.migrate(d)
	var project: Project = Project.from_dict(d)
	project.path = ""
	project.view = {}
	Health.check(project)
	StreamOrdinals.repair(project)
	SpeedLength.rebase(project)
	project.dirty = true
	return project


static func lock_path(project: Project) -> String:
	if project.path.is_empty():
		return ""
	return project.path + ".lock"


static func lock(project: Project) -> bool:
	var lp: String = lock_path(project)
	if lp.is_empty():
		return false
	var d: Dictionary = {"pid": OS.get_process_id(), "time": Time.get_datetime_string_from_system(true), "path": project.path}
	var f: FileAccess = FileAccess.open(lp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.flush()
	f.close()
	return true


static func unlock(project: Project) -> void:
	var lp: String = lock_path(project)
	if not lp.is_empty() and FileAccess.file_exists(lp):
		DirAccess.remove_absolute(_abs(lp))


static func lock_info(path: String) -> Dictionary:
	var d: Dictionary = read_json(path + ".lock")
	if d.is_empty():
		return {"found": false, "path": "", "time": "", "pid": 0, "stale": false}
	var pid: int = int(d.get("pid", 0))
	var stale: bool = pid != OS.get_process_id() and (pid <= 0 or not process_alive(pid))
	return {"found": true, "path": path, "time": str(d.get("time", "")), "pid": pid, "stale": stale}


static func process_alive(pid: int) -> bool:
	if pid <= 0:
		return false
	if OS.get_name() == "Windows" or OS.get_name() == "macOS":
		return OS.is_process_running(pid)
	if DirAccess.dir_exists_absolute("/proc"):
		return DirAccess.dir_exists_absolute("/proc/" + str(pid))
	return OS.is_process_running(pid)


static func crashed_session() -> Dictionary:
	for p: String in recent_projects():
		var info: Dictionary = lock_info(p)
		if bool(info["found"]) and bool(info["stale"]):
			return {"found": true, "path": p, "time": str(info["time"])}
	return {"found": false, "path": "", "time": ""}


static func recent_projects() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var prefs: Node = _prefs()
	if prefs == null:
		return out
	if not bool(prefs.call("is_registered", PREF_RECENT)):
		prefs.call("register", PREF_RECENT, [], {"label": "Recent projects", "type": "list"})
	var v: Variant = prefs.call("get_value", PREF_RECENT)
	var seen: Dictionary = {}
	if v is Array:
		for e: Variant in v:
			var p: String = str(e)
			var key: String = recent_key(p)
			if seen.has(key):
				continue
			seen[key] = true
			out.append(p)
	return out


static func recent_key(path: String) -> String:
	var key: String = _abs(path).replace("\\", "/").simplify_path()
	if OS.get_name() == "Windows":
		key = key.to_lower()
	return key


static func remember_recent(path: String) -> void:
	var prefs: Node = _prefs()
	if prefs == null or path.is_empty():
		return
	var key: String = recent_key(path)
	var current: PackedStringArray = PackedStringArray()
	for p: String in recent_projects():
		if recent_key(p) != key:
			current.append(p)
	current.insert(0, path)
	while current.size() > PREF_RECENT_MAX:
		current.remove_at(current.size() - 1)
	prefs.call("set_value", PREF_RECENT, Array(current))


static func autosave_tick(project: Project, interval_s: float) -> bool:
	if project == null:
		return false
	var now: float = Time.get_unix_time_from_system()
	var key: String = project.id if not project.id.is_empty() else "untitled"
	var state: Dictionary = _autosave.get(key, {"last": now, "serial": project.serial})
	if not _autosave.has(key):
		_autosave[key] = state
		return false
	if project.serial == int(state["serial"]):
		return false
	if now - float(state["last"]) < interval_s:
		return false
	var written: String = snapshot(project)
	if written.is_empty():
		return false
	_autosave[key] = {"last": now, "serial": project.serial}
	return true


static func reset_autosave(project: Project) -> void:
	if project != null:
		_autosave.erase(project.id if not project.id.is_empty() else "untitled")


static func background_busy() -> bool:
	if _bg_task < 0:
		return false
	if not WorkerThreadPool.is_task_completed(_bg_task):
		return true
	_finish_background()
	return false


static func wait_background() -> void:
	if _bg_task >= 0:
		_finish_background()


static func _finish_background() -> void:
	var task: int = _bg_task
	_bg_task = -1
	WorkerThreadPool.wait_for_task_completion(task)
	var out: Array = _bg_out
	_bg_out = []
	var err: String = String(out[0]) if out.size() > 0 else "the save did not finish"
	_bg_last = {"ok": err.is_empty(), "error": err, "ms": float(out[1]) if out.size() > 1 else 0.0, "bytes": int(out[2]) if out.size() > 2 else 0, "path": _bg_path, "tag": _bg_tag}


static func take_background_result() -> Dictionary:
	var r: Dictionary = _bg_last
	_bg_last = {}
	return r


static func save_background(d: Dictionary, view: Dictionary, path: String, tag: Variant, trash: Array) -> bool:
	if background_busy() or path.is_empty() or d.is_empty():
		return false
	_bg_out = []
	_bg_path = path
	_bg_tag = tag
	var job: Callable = Callable(load("res://doc/io.gd"), "_background_job").bind(d, view, path, trash, _bg_out)
	_bg_task = WorkerThreadPool.add_task(job, false, "Save " + path.get_file())
	return true


static func _background_job(d: Dictionary, view: Dictionary, path: String, trash: Array, out: Array) -> void:
	var t0: int = Time.get_ticks_usec()
	var text: String = JSON.stringify(d, "\t", false, true)
	var r: Array = write_atomic_core(path, text, true)
	if String(r[1]).is_empty():
		var vtext: String = JSON.stringify(view, "\t", false, true)
		write_atomic_core(view_path(path), vtext if not vtext.strip_edges().is_empty() else "{}", false)
	out.append(String(r[1]))
	out.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	out.append(text.length())
	d.clear()
	view.clear()
	for t: Variant in trash:
		if t is Dictionary:
			(t as Dictionary).clear()
		elif t is Array:
			(t as Array).clear()
	trash.clear()


static func recovery_dir() -> String:
	return data_path(RECOVERY_DIR)


static func new_recovery_path(project: Project) -> String:
	var stamp: String = Time.get_datetime_string_from_system(false, false).replace("-", "").replace(":", "").replace("T", "_")
	var base: String = _safe_name(project) + RECOVERY_SEP + str(OS.get_process_id()) + RECOVERY_SEP + stamp + "_" + str(Time.get_ticks_usec() % 1000000)
	return recovery_dir().path_join(base + EXT)


static func recovery_pid(path: String) -> int:
	var parts: PackedStringArray = path.get_file().trim_suffix(EXT).split(RECOVERY_SEP)
	if parts.size() < 3 or not parts[parts.size() - 2].is_valid_int():
		return 0
	return int(parts[parts.size() - 2])


static func remove_recovery(path: String) -> void:
	if path.is_empty():
		return
	for p: String in [path, path + ".bak", path + ".tmp", view_path(path), view_path(path) + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(_abs(p))
	_own_recovery.erase(path)


static func claim_recovery(path: String, project: Project) -> String:
	var fresh: String = new_recovery_path(project)
	DirAccess.make_dir_recursive_absolute(_abs(recovery_dir()))
	if DirAccess.rename_absolute(_abs(path), _abs(fresh)) != OK:
		return path
	if FileAccess.file_exists(view_path(path)):
		DirAccess.rename_absolute(_abs(view_path(path)), _abs(view_path(fresh)))
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(_abs(path + ".bak"))
	own_recovery(fresh)
	return fresh


static func own_recovery(path: String) -> void:
	_own_recovery[path] = true


static func orphan_recoveries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir_path: String = recovery_dir()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	var me: int = OS.get_process_id()
	for f: String in dir.get_files():
		if not f.ends_with(EXT):
			continue
		var p: String = dir_path.path_join(f)
		if _own_recovery.has(p):
			continue
		var pid: int = recovery_pid(p)
		if pid > 0 and pid != me and process_alive(pid):
			continue
		var info: Dictionary = snapshot_info(p)
		if bool(info["ok"]):
			out.append(info)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["modified"]) > int(b["modified"]))
	return out


static func preset_path(kind: String, id: String) -> String:
	return preset_root().path_join(kind).path_join(id + ".json")


static func data_path(sub: String) -> String:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
		if prefs != null and prefs.has_method("data_path"):
			return String(prefs.call("data_path", sub))
	return ProjectSettings.globalize_path("user://" + sub)


static func preset_root() -> String:
	return data_path("presets")


static func save_preset(preset: Dictionary) -> Error:
	var kind: String = str(preset.get("kind", ""))
	var id: String = str(preset.get("id", ""))
	if kind.is_empty() or id.is_empty():
		last_error = "a preset needs a kind and an id"
		return ERR_INVALID_PARAMETER
	return write_atomic(preset_path(kind, id), JSON.stringify(preset, "\t", false, true), false)


static func delete_preset(kind: String, id: String) -> bool:
	if kind.is_empty() or id.is_empty():
		return false
	var path: String = preset_path(kind, id)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK


static func load_user_presets(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir_path: String = preset_root().path_join(kind)
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.ends_with(".json"):
			var d: Dictionary = read_json(dir_path.path_join(entry))
			if not d.is_empty():
				out.append(d)
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return preset_before(a, b))
	return out


static func preset_before(a: Dictionary, b: Dictionary) -> bool:
	var sa: int = int(a.get("sort", 0))
	var sb: int = int(b.get("sort", 0))
	if sa != sb:
		return sa < sb
	return str(a.get("label", "")) < str(b.get("label", ""))


static func delete_user_preset(kind: String, id: String) -> bool:
	var p: String = preset_path(kind, id)
	if not FileAccess.file_exists(p):
		return false
	return DirAccess.remove_absolute(_abs(p)) == OK

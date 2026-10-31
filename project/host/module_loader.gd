extends RefCounted

const Io := preload("res://doc/io.gd")
const OFFICIAL_ROOT := "res://modules/"
const MANIFEST := "module.json"
const MAIN_SCRIPT := "module_main.gd"
const KILL_FILE := "res://modules/OFF.txt"
const KINDS: PackedStringArray = ["data", "code"]
const ID_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_"

var records: Array[Dictionary] = []
var _by_id: Dictionary = {}


static func manifest_defaults() -> Dictionary:
	return {
		"id": "",
		"label": "",
		"kind": "data",
		"version": "0.0.0",
		"api": {},
		"provides": [],
		"requires": [],
		"author": "",
		"blurb": "",
		"about": "",
		"formats": [],
		"settings": [],
		"actions": [],
		"wants": [],
		"core": false,
	}


static func valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 64:
		return false
	for ch: String in id:
		if not (ch in ID_CHARS):
			return false
	return true


static func sanitise(raw: Variant) -> Dictionary:
	var out: Dictionary = manifest_defaults()
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var src: Dictionary = raw
	for key: String in out.keys():
		if not src.has(key):
			continue
		var want: int = typeof(out[key])
		var v: Variant = src[key]
		if typeof(v) == want:
			out[key] = v
		elif want == TYPE_STRING and (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT):
			out[key] = str(v)
	out["id"] = String(out["id"]).strip_edges().to_lower()
	if not (String(out["kind"]) in KINDS):
		out["kind"] = "data"
	if String(out["label"]).is_empty():
		out["label"] = String(out["id"]).capitalize()
	var api: Dictionary = {}
	for k: Variant in (out["api"] as Dictionary).keys():
		if typeof(k) == TYPE_STRING:
			api[String(k)] = int(out["api"][k]) if (typeof(out["api"][k]) == TYPE_INT or typeof(out["api"][k]) == TYPE_FLOAT) else 1
	out["api"] = api
	for list_key: String in ["provides", "requires", "formats", "wants"]:
		var clean: Array = []
		for item: Variant in out[list_key]:
			if typeof(item) == TYPE_STRING:
				clean.append(String(item))
		out[list_key] = clean
	for list_key: String in ["settings", "actions"]:
		var clean: Array = []
		for item: Variant in out[list_key]:
			if typeof(item) == TYPE_DICTIONARY:
				clean.append(item)
		out[list_key] = clean
	return out


func _record(id: String, label: String, kind: String, version: String, state: String, reason: String, path: String, official: bool, manifest: Dictionary) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"kind": kind,
		"version": version,
		"state": state,
		"reason": reason,
		"path": path,
		"official": official,
		"manifest": manifest,
		"core": official and bool(manifest.get("core", false)),
	}


func _scan_root(root: String, official: bool) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var names: PackedStringArray = PackedStringArray()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir() and not entry.begins_with(".") and entry != "Removed":
			names.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for folder: String in names:
		var path: String = root + folder + "/"
		var manifest_path: String = path + MANIFEST
		if not FileAccess.file_exists(manifest_path):
			continue
		var text: String = FileAccess.get_file_as_string(manifest_path)
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			found.append(_record(folder, folder.capitalize(), "data", "0.0.0", "broken", "module.json is not a JSON object", path, official, manifest_defaults()))
			continue
		var m: Dictionary = sanitise(parsed)
		if not valid_id(String(m["id"])):
			found.append(_record(folder, String(m["label"]), String(m["kind"]), String(m["version"]), "broken", "the id in module.json is missing or has characters outside a-z, 0-9 and _", path, official, m))
			continue
		found.append(_record(String(m["id"]), String(m["label"]), String(m["kind"]), String(m["version"]), "ready", "", path, official, m))
	return found


func scan(no_modules: bool) -> Array[Dictionary]:
	records.clear()
	_by_id.clear()
	if no_modules or FileAccess.file_exists(KILL_FILE):
		return records
	var all: Array[Dictionary] = _scan_root(OFFICIAL_ROOT, true)
	all.append_array(_scan_root(Io.data_path("modules") + "/", false))
	for r: Dictionary in all:
		var id: String = r["id"]
		if String(r["state"]) != "broken" and _by_id.has(id):
			var other: Dictionary = _by_id[id]
			r["state"] = "broken"
			r["reason"] = "the id \"" + id + "\" is already used by " + String(other["path"])
		elif String(r["state"]) != "broken":
			_by_id[id] = r
		records.append(r)
	return records


func record_for(id: String) -> Dictionary:
	if _by_id.has(id):
		return _by_id[id]
	return {}


func load_code(r: Dictionary, host: Node) -> bool:
	var path: String = String(r["path"]) + MAIN_SCRIPT
	if not FileAccess.file_exists(path):
		r["state"] = "broken"
		r["reason"] = "module_main.gd is missing"
		return false
	var script: Variant = load(path)
	if script == null or not (script is GDScript):
		r["state"] = "broken"
		r["reason"] = "module_main.gd did not load"
		return false
	var gd: GDScript = script
	if not gd.can_instantiate():
		r["state"] = "broken"
		r["reason"] = "module_main.gd has a parse error"
		return false
	var inst: Object = gd.new()
	if inst == null or not inst.has_method("register"):
		r["state"] = "broken"
		r["reason"] = "module_main.gd has no register(host) function"
		if inst is Node:
			(inst as Node).free()
		return false
	r["instance"] = inst
	inst.call("register", host)
	r["state"] = "on"
	r["reason"] = ""
	return true


func unload(r: Dictionary) -> void:
	if r.has("instance"):
		var inst: Variant = r["instance"]
		if inst is Object and (inst as Object).has_method("unregister"):
			(inst as Object).call("unregister")
		if inst is Node:
			(inst as Node).free()
		r.erase("instance")
	if String(r["state"]) == "on":
		r["state"] = "off"

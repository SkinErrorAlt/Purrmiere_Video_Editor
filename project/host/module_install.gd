extends RefCounted
## Installing a module: a folder holding a module.json, or a zip of one, dropped on the window or picked from the
## File menu, is copied into Documents\Purrmiere\modules and shown on a card before it runs. The card lists what
## the module's code can reach, read from its source, in plain words.

const ModuleLoader := preload("res://host/module_loader.gd")
const MANIFEST := "module.json"
const REMOVED := "Removed"

## [pattern, plain words]. Matched against the module's .gd files.
const REACH: Array = [
	["api.run(", "Change your project, as undoable steps"],
	["api.import_files(", "Add media to your project's bin"],
	["api.add_panel(", "Add its own panels"],
	["api.add_workspace(", "Add a workspace tab"],
	["api.add_command(", "Add commands and keyboard shortcuts"],
	["api.add_menu_item(", "Add items to the menus"],
	["api.add_format(", "Open or save its own file types"],
	["api.add_document_kind(", "Own a kind of document"],
	["api.add_effects_folder(", "Add effects"],
	["api.add_transitions_folder(", "Add transitions"],
	["api.add_setting(", "Add settings"],
	["api.pick_file(", "Ask you to pick files"],
	["api.open_window(", "Open its own windows"],
	["api.compositor(", "Read frames of your video"],
	["api.render_image(", "Draw pictures of your sequences"],
	["api.add_drop_handler(", "Take files dropped on its own workspace"],
]
const RISKY: Array = [
	["OS.execute", "Run other programs on your computer"],
	["OS.create_process", "Run other programs on your computer"],
	["OS.shell_open", "Open web pages or files with other apps"],
	["HTTPRequest", "Use the internet"],
	["HTTPClient", "Use the internet"],
	["StreamPeerTCP", "Use the internet"],
	["WebSocketPeer", "Use the internet"],
	["DirAccess.remove", "Delete files"],
	["remove_absolute", "Delete files"],
	["FileAccess.WRITE", "Write files"],
	["get_node(\"/root/", "Reach inside Purrmiere directly, not through the module API"],
	["get_node_or_null(\"/root/", "Reach inside Purrmiere directly, not through the module API"],
	["preload(\"res://", "Use Purrmiere's own scripts directly, not through the module API"],
	["load(\"res://", "Use Purrmiere's own scripts directly, not through the module API"],
]


## The module folder a dropped path is, or would unpack to: "" when it is not a module.
static func module_root_of(path: String) -> String:
	var p: String = path.replace("\\", "/").trim_suffix("/")
	if DirAccess.dir_exists_absolute(p):
		return p if FileAccess.file_exists(p + "/" + MANIFEST) else ""
	return ""


static func is_module_zip(path: String) -> bool:
	if path.get_extension().to_lower() != "zip" or not FileAccess.file_exists(path):
		return false
	return not _zip_manifest_entry(path).is_empty()


static func is_module(path: String) -> bool:
	return not module_root_of(path).is_empty() or is_module_zip(path)


static func _zip_manifest_entry(path: String) -> String:
	var z: ZIPReader = ZIPReader.new()
	if z.open(path) != OK:
		return ""
	var best: String = ""
	for f: String in z.get_files():
		var parts: PackedStringArray = f.split("/", false)
		if parts.size() >= 1 and parts[parts.size() - 1] == MANIFEST and parts.size() <= 2:
			if best.is_empty() or parts.size() < best.split("/", false).size():
				best = f
	z.close()
	return best


static func read_manifest_at(dir: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(dir.trim_suffix("/") + "/" + MANIFEST)
	var parsed: Variant = JSON.parse_string(text)
	return ModuleLoader.sanitise(parsed) if parsed is Dictionary else {}


## Copies (or unpacks) a module into the modules folder. Returns {ok, id, path, reason, replaced}.
static func install(path: String, into: String = "") -> Dictionary:
	var dest_root: String = into if not into.is_empty() else ModuleLoader.user_root()
	dest_root = dest_root.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(dest_root)
	var m: Dictionary = {}
	var zip: bool = false
	var src: String = module_root_of(path)
	if not src.is_empty():
		m = read_manifest_at(src)
	elif is_module_zip(path):
		zip = true
		var z: ZIPReader = ZIPReader.new()
		z.open(path)
		var entry: String = _zip_manifest_entry(path)
		var parsed: Variant = JSON.parse_string(z.read_file(entry).get_string_from_utf8())
		z.close()
		m = ModuleLoader.sanitise(parsed) if parsed is Dictionary else {}
	else:
		return {"ok": false, "reason": "this is not a module: there is no module.json in it"}
	var id: String = String(m.get("id", ""))
	if not ModuleLoader.valid_id(id):
		return {"ok": false, "reason": "its module.json has no id, or the id has characters outside a-z, 0-9 and _"}
	if FileAccess.file_exists("res://modules/" + id + "/" + MANIFEST):
		return {"ok": false, "id": id, "reason": "\"" + id + "\" is the name of one of Purrmiere's own modules"}
	var dest: String = dest_root + id
	var replaced: bool = false
	if DirAccess.dir_exists_absolute(dest):
		replaced = true
		var bin: String = removed_path(dest_root, id)
		DirAccess.make_dir_recursive_absolute(bin.get_base_dir())
		if DirAccess.rename_absolute(dest, bin) != OK:
			return {"ok": false, "id": id, "reason": "the old copy in " + dest + " could not be moved aside; close anything using it"}
	var ok: bool = _unzip(path, dest) if zip else _copy_dir(src, dest)
	if not ok:
		return {"ok": false, "id": id, "reason": "copying it into " + dest + " failed"}
	return {"ok": true, "id": id, "path": dest + "/", "label": String(m.get("label", id)), "replaced": replaced}


static func _copy_dir(from: String, to: String) -> bool:
	DirAccess.make_dir_recursive_absolute(to)
	var d: DirAccess = DirAccess.open(from)
	if d == null:
		return false
	d.include_hidden = false
	for f: String in d.get_files():
		if d.copy(from + "/" + f, to + "/" + f) != OK:
			return false
	for sub: String in d.get_directories():
		if sub.begins_with(".") or sub == ".godot":
			continue
		if not _copy_dir(from + "/" + sub, to + "/" + sub):
			return false
	return true


static func _unzip(path: String, to: String) -> bool:
	var z: ZIPReader = ZIPReader.new()
	if z.open(path) != OK:
		return false
	var entry: String = _zip_manifest_entry(path)
	var prefix: String = entry.substr(0, entry.length() - MANIFEST.length())
	for f: String in z.get_files():
		if not f.begins_with(prefix) or f.ends_with("/"):
			continue
		var rel: String = f.substr(prefix.length())
		if rel.is_empty() or rel.contains(".."):
			continue
		var out: String = to + "/" + rel
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var fa: FileAccess = FileAccess.open(out, FileAccess.WRITE)
		if fa == null:
			z.close()
			return false
		fa.store_buffer(z.read_file(f))
		fa.close()
	z.close()
	return true


## What the module can do and reach, in plain words, read from its scripts. Each entry {what, risky}.
static func reach_of(dir: String) -> Array[Dictionary]:
	var texts: PackedStringArray = PackedStringArray()
	var native: bool = false
	_collect(dir.trim_suffix("/"), texts, [native])
	native = _has_native(dir.trim_suffix("/"))
	var seen: Dictionary = {}
	var out: Array[Dictionary] = []
	var all: String = "\n".join(texts)
	for pair: Array in REACH:
		if all.contains(String(pair[0])) and not seen.has(pair[1]):
			seen[pair[1]] = true
			out.append({"what": String(pair[1]), "risky": false})
	for pair2: Array in RISKY:
		if all.contains(String(pair2[0])) and not seen.has(pair2[1]):
			seen[pair2[1]] = true
			out.append({"what": String(pair2[1]), "risky": true})
	if native:
		out.append({"what": "Ships native code (a .dll), which can do anything a program can", "risky": true})
	return out


static func _collect(dir: String, into: PackedStringArray, _flag: Array) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		if f.get_extension() == "gd":
			into.append(FileAccess.get_file_as_string(dir + "/" + f))
	for sub: String in d.get_directories():
		if not sub.begins_with("."):
			_collect(dir + "/" + sub, into, _flag)


static func _has_native(dir: String) -> bool:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return false
	for f: String in d.get_files():
		var e: String = f.get_extension().to_lower()
		if e == "dll" or e == "so" or e == "dylib" or e == "gdextension":
			return true
	for sub: String in d.get_directories():
		if not sub.begins_with(".") and _has_native(dir + "/" + sub):
			return true
	return false


## Moves an installed module to the Removed folder, so it can be put back by hand.
static func remove(id: String, from: String = "") -> bool:
	var root: String = (from if not from.is_empty() else ModuleLoader.user_root()).trim_suffix("/") + "/"
	var dir: String = root + id
	if not DirAccess.dir_exists_absolute(dir):
		return false
	var bin: String = removed_path(root, id)
	DirAccess.make_dir_recursive_absolute(bin.get_base_dir())
	return DirAccess.rename_absolute(dir, bin) == OK


## A fresh folder name in Removed for an old copy of a module.
static func removed_path(root: String, id: String) -> String:
	var base: String = root.trim_suffix("/") + "/" + REMOVED + "/" + id + "_" + Time.get_datetime_string_from_system().replace(":", "-")
	var p: String = base
	var n: int = 2
	while DirAccess.dir_exists_absolute(p):
		p = base + "_" + str(n)
		n += 1
	return p

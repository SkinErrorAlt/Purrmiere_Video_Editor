extends RefCounted

const EffectRegistry := preload("res://engine/effect_registry.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const EXT := "purrfx"
const ITEM_EXPORT := "effect_file_export"
const ITEM_IMPORT := "effect_file_import"
const SKIP_EXT: PackedStringArray = ["uid", "import"]
const MAX_FILE_BYTES := 64 * 1024 * 1024

static var _dialog: FileDialog = null
static var _export_id: String = ""
static var last_error: String = ""


static func row_menu_items(id: String) -> Array:
	if id.begins_with("transition:"):
		return []
	return [PmMenu.item(ITEM_EXPORT, "Export this effect as a file...", "", "export")]


static func panel_menu_items() -> Array:
	return [PmMenu.item(ITEM_IMPORT, "Import an effect file...", "", "import")]


static func folder_of(id: String) -> String:
	var reg: RefCounted = EffectRegistry.shared()
	var def: Dictionary = reg.call("get_def", id)
	var p: String = String(def.get("path", ""))
	if p.is_empty():
		return ""
	return p if p.ends_with("/") else p + "/"


static func export_effect(id: String, out_path: String) -> bool:
	last_error = ""
	var folder: String = folder_of(id)
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder):
		last_error = "That effect has no folder to export"
		return false
	var zip := ZIPPacker.new()
	if zip.open(out_path) != OK:
		last_error = "The file could not be written"
		return false
	var count: int = 0
	for f: String in DirAccess.get_files_at(folder):
		if SKIP_EXT.has(f.get_extension().to_lower()):
			continue
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(folder + f)
		zip.start_file(id + "/" + f)
		zip.write_file(bytes)
		zip.close_file()
		count += 1
	zip.close()
	if count == 0:
		last_error = "That effect's folder is empty"
		return false
	return true


static func _safe(name: String) -> bool:
	return not name.is_empty() and not name.contains("..") and not name.contains(":") and not name.begins_with("/") and not name.contains("\\")


static func read(path: String) -> Dictionary:
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		return {"ok": false, "why": "That is not an effect file"}
	var files: Dictionary = {}
	var top: String = ""
	for name: String in zip.get_files():
		if name.ends_with("/"):
			continue
		if not _safe(name) or name.count("/") != 1:
			zip.close()
			return {"ok": false, "why": "The effect file holds a path that is not allowed: " + name}
		var folder: String = name.get_slice("/", 0)
		if top.is_empty():
			top = folder
		elif folder != top:
			zip.close()
			return {"ok": false, "why": "An effect file holds one effect"}
		var bytes: PackedByteArray = zip.read_file(name)
		if bytes.size() > MAX_FILE_BYTES:
			zip.close()
			return {"ok": false, "why": "A file in it is too large"}
		files[name.get_slice("/", 1)] = bytes
	zip.close()
	var has_shader: bool = false
	for k: String in files.keys():
		if k.get_extension().to_lower() == "gdshader":
			has_shader = true
	if not has_shader:
		return {"ok": false, "why": "The effect file has no shader in it"}
	var id: String = top.to_lower()
	if files.has("effect.json"):
		var parsed: Variant = JSON.parse_string((files["effect.json"] as PackedByteArray).get_string_from_utf8())
		if parsed is Dictionary and (parsed as Dictionary).has("id"):
			id = String((parsed as Dictionary)["id"]).to_lower()
	return {"ok": true, "id": id, "files": files}


static func import_file(path: String, root: String = "") -> String:
	last_error = ""
	var got: Dictionary = read(path)
	if not bool(got["ok"]):
		last_error = String(got["why"])
		return ""
	var base: String = root if not root.is_empty() else EffectRegistry.user_root()
	var id: String = String(got["id"])
	var files: Dictionary = got["files"]
	var reg: RefCounted = EffectRegistry.shared()
	var final_id: String = id
	var n: int = 2
	while DirAccess.dir_exists_absolute(base + final_id) or (root.is_empty() and not (reg.call("get_def", final_id) as Dictionary).is_empty()):
		final_id = id + "_" + str(n)
		n += 1
	var dest: String = base + final_id + "/"
	DirAccess.make_dir_recursive_absolute(dest)
	for name: String in files.keys():
		var bytes: PackedByteArray = files[name]
		if name == "effect.json" and final_id != id:
			var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
			if parsed is Dictionary:
				(parsed as Dictionary)["id"] = final_id
				bytes = JSON.stringify(parsed, " ").to_utf8_buffer()
		var f: FileAccess = FileAccess.open(dest + name, FileAccess.WRITE)
		if f == null:
			last_error = "The effect could not be saved"
			return ""
		f.store_buffer(bytes)
		f.close()
	if root.is_empty():
		reg.call("reload")
	return final_id


static func _make_dialog(host: Node) -> FileDialog:
	if _dialog == null or not is_instance_valid(_dialog):
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.use_native_dialog = true
		_dialog.filters = PackedStringArray(["*." + EXT + " ; Purrmiere effect"])
		_dialog.file_selected.connect(_on_file)
		host.get_tree().root.add_child(_dialog)
	return _dialog


static func open_export(host: Node, id: String) -> void:
	if host == null or not host.is_inside_tree():
		return
	var d: FileDialog = _make_dialog(host)
	_export_id = id
	d.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	d.title = "Export the effect"
	d.current_file = id + "." + EXT
	d.popup_centered(Vector2i(900, 600))


static func open_import(host: Node) -> void:
	if host == null or not host.is_inside_tree():
		return
	var d: FileDialog = _make_dialog(host)
	_export_id = ""
	d.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	d.title = "Import an effect file"
	d.popup_centered(Vector2i(900, 600))


static func _on_file(path: String) -> void:
	if not _export_id.is_empty():
		var p: String = path if path.get_extension().to_lower() == EXT else path + "." + EXT
		if export_effect(_export_id, p):
			Events.toast("Saved " + p.get_file())
		else:
			Events.toast(last_error)
		return
	var id: String = import_file(path)
	if id.is_empty():
		Events.toast(last_error)
	else:
		Events.toast("Imported " + String((EffectRegistry.shared().call("get_def", id) as Dictionary).get("label", id)) + " into the Effects panel")


static func row_menu_picked(panel: Object, pick: String, id: String) -> bool:
	if pick != ITEM_EXPORT:
		return false
	var host: Variant = panel.call("root") if panel.has_method("root") else null
	if host is Node:
		open_export(host, id)
	return true


static func panel_menu_picked(host: Node, pick: String) -> bool:
	if pick != ITEM_IMPORT:
		return false
	open_import(host)
	return true

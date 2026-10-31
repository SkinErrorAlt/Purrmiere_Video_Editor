extends Node

const ShaderImport := preload("res://modules/core_panels/shader_import.gd")
const ImportedShaders := preload("res://doc/imported_shaders.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const OWNER := "core_panels"
const CMD_FILE := "clip.import_shader"
const CMD_PASTE := "clip.paste_shader"

var _window: Window = null
var _doc: Object = null
var _sig: String = ""


func _ready() -> void:
	name = "ShaderFileDrop"
	_window = get_tree().root
	if not _window.files_dropped.is_connected(on_files_dropped):
		_window.files_dropped.connect(on_files_dropped)
	Session.project_changed.connect(_on_project)
	_register(CMD_FILE, "Import a Godot shader...", _on_cmd_file)
	_register(CMD_PASTE, "Paste Godot shader code...", _on_cmd_paste)
	_on_project()


func _exit_tree() -> void:
	if _window != null and is_instance_valid(_window) and _window.files_dropped.is_connected(on_files_dropped):
		_window.files_dropped.disconnect(on_files_dropped)


func _register(id: String, label: String, handler: Callable) -> void:
	var cat: Dictionary = Cmd.catalogue()
	var spec: Dictionary = {"label": String(cat[id]["label"]) if cat.has(id) else label, "category": String(cat[id]["category"]) if cat.has(id) else "Clip", "scope": "global", "handler": handler, "owner": OWNER, "enabled": Callable(Bus, "has_doc_static")}
	Cmd.register(id, spec)


func _on_cmd_file() -> void:
	ShaderImport.menu_pick(self, ShaderImport.MENU_FILE)


func _on_cmd_paste() -> void:
	ShaderImport.menu_pick(self, ShaderImport.MENU_PASTE)


func on_files_dropped(files: PackedStringArray) -> void:
	var parts: Dictionary = ShaderImport.split_files(files)
	var shaders: PackedStringArray = parts["shaders"]
	if shaders.is_empty() or Session.doc == null:
		return
	var at: Vector2 = get_viewport().get_mouse_position()
	ShaderImport.import_files(self, shaders, ShaderImport.targets_at(at))


func _on_project() -> void:
	if _doc != null and is_instance_valid(_doc) and _doc.has_signal("changed") and _doc.is_connected("changed", _on_doc_changed):
		_doc.disconnect("changed", _on_doc_changed)
	_doc = Session.doc
	_sig = ""
	if _doc != null:
		_doc.connect("changed", _on_doc_changed)
		ImportedShaders.refresh(_doc)
		_sig = signature(_doc)
	else:
		var reg: RefCounted = ImportedShaders.registry()
		if reg != null:
			reg.call("set_embedded_shown", PackedStringArray())
	ShaderImport.refresh_panels()


static func signature(doc: Object) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for e: Variant in ImportedShaders.store(doc).values():
		parts.append(String((e as Dictionary).get("id", "")) + ">" + String((e as Dictionary).get("library_id", "")))
	parts.sort()
	return "|".join(parts)


func _on_doc_changed(kind: String) -> void:
	if kind != "meta" or _doc == null:
		return
	var now: String = signature(_doc)
	if now == _sig:
		return
	_sig = now
	ShaderImport.refresh_panels()

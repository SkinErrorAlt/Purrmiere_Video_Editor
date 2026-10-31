extends RefCounted

const Bus := preload("res://modules/core_panels/panel_bus.gd")
const SELF_PATH := "res://modules/core_panels/views_commands.gd"
const OWNER := "core_panels"
const PANEL_ID := "views"
const OPEN_ID := "clip.views_panel"
const VIEW_PREFIX := "clip.view_"
const VIEW_COUNT := 8
const OPEN_LABEL := "Views panel"
const CATEGORY := "Clip"


static func register_all() -> void:
	var script: GDScript = load(SELF_PATH)
	_reg(OPEN_ID, OPEN_LABEL, "global", Callable(script, "open_panel"), Callable(Bus, "has_doc_static"))
	for i: int in VIEW_COUNT:
		_reg(VIEW_PREFIX + str(i + 1), "Switch to view " + str(i + 1), "program", Callable(script, "switch_key").bind(i), Callable(script, "keys_live"))


static func _reg(id: String, label: String, scope: String, handler: Callable, enabled: Callable) -> void:
	var cat: Dictionary = Cmd.catalogue()
	var shown: String = label
	var category: String = CATEGORY
	if cat.has(id):
		shown = String(cat[id]["label"])
		category = String(cat[id]["category"])
	Cmd.register(id, {"label": shown, "category": category, "scope": scope, "handler": handler, "owner": OWNER, "enabled": enabled})


static func panel() -> Object:
	return Bus.instance().panel(PANEL_ID)


static func keys_live() -> bool:
	if Session.doc == null:
		return false
	var p: Object = panel()
	return p != null and p.has_method("is_open") and bool(p.call("is_open"))


static func switch_key(index: int) -> void:
	var p: Object = panel()
	if p == null or not p.has_method("switch_to"):
		return
	p.call("switch_to", index)


static func _dock() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var editor: Node = (loop as SceneTree).root.find_child("EditorScreen", true, false)
	if editor == null:
		return null
	var dock: Variant = editor.get("dock")
	return dock if dock is Node else null


static func open_panel() -> void:
	var dock: Node = _dock()
	if dock == null or not dock.has_method("show_panel"):
		return
	var placed: bool = bool(dock.call("is_docked", PANEL_ID)) or bool(dock.call("is_floating", PANEL_ID))
	if not placed and bool(dock.call("is_docked", "effect_controls")):
		dock.call("focus_panel", "effect_controls")
	dock.call("show_panel", PANEL_ID)

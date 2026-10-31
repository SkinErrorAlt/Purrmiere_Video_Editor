extends RefCounted

const Bus := preload("res://modules/core_panels/panel_bus.gd")
const SELF_PATH := "res://modules/core_panels/groups_commands.gd"
const OWNER := "core_panels"
const PANEL_ID := "groups"
const OPEN_ID := "group.panel"
const OPEN_LABEL := "Groups panel"
const CATEGORY := "Clip"


static func register_all() -> void:
	var script: GDScript = load(SELF_PATH)
	var cat: Dictionary = Cmd.catalogue()
	var shown: String = OPEN_LABEL
	var category: String = CATEGORY
	if cat.has(OPEN_ID):
		shown = String(cat[OPEN_ID]["label"])
		category = String(cat[OPEN_ID]["category"])
	Cmd.register(OPEN_ID, {"label": shown, "category": category, "scope": "global", "handler": Callable(script, "open_panel").bind(""), "owner": OWNER, "enabled": Callable(Bus, "has_doc_static")})


static func panel() -> Object:
	return Bus.instance().panel(PANEL_ID)


static func _dock() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var editor: Node = (loop as SceneTree).root.find_child("EditorScreen", true, false)
	if editor == null:
		return null
	var dock: Variant = editor.get("dock")
	return dock if dock is Node else null


static func open_panel(gid: String = "") -> void:
	var dock: Node = _dock()
	if dock != null and dock.has_method("show_panel"):
		var placed: bool = bool(dock.call("is_docked", PANEL_ID)) or bool(dock.call("is_floating", PANEL_ID))
		if not placed and bool(dock.call("is_docked", "effect_controls")):
			dock.call("focus_panel", "effect_controls")
		dock.call("show_panel", PANEL_ID)
	var p: Object = panel()
	if p != null and not gid.is_empty() and p.has_method("reveal"):
		p.call("reveal", gid)

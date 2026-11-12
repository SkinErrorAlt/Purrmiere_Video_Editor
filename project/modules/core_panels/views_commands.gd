extends RefCounted

const Bus := preload("res://modules/core_panels/panel_bus.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const ViewMap := preload("res://doc/view_map.gd")
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
	var solo: GDScript = load("res://ui/timeline/timeline_view_solo.gd")
	_reg("views.solo_next_overlap", "Go to the next overlap in the soloed view", "timeline", Callable(solo, "jump_next_overlap"), Callable(solo, "soloing_now"))


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


static func set_view_colour(clip_id: String, uid: String, index: int, colour: int) -> bool:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null or s == null:
		return false
	var c: Clip = s.clip_by_id(clip_id)
	if c == null:
		return false
	var e: Dictionary = c.effect_by_uid(uid)
	if e.is_empty() or String(e.get("id", "")) != ViewMap.PAIR_VIEW_ID:
		return false
	var next: Dictionary = ViewMap.with_colour(ViewMap.of(e), index, colour, ViewMap.crop_count(e))
	if next.is_empty():
		return false
	var label: String = "Colour a view" if colour >= 0 else "Let a view pick its own colour"
	var cmds: Array[Command] = [EffectCmds.SetEffectParam.new(s.id, clip_id, uid, "view_audio", JSON.stringify(next), -1.0)]
	return Verbs.run(d, label, cmds)

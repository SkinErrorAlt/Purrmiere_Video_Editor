extends RefCounted

const Bus := preload("res://modules/core_panels/panel_bus.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Censor := preload("res://doc/censor.gd")
const CensorCmds := preload("res://doc/commands/censor_cmds.gd")
const TimelineCensor := preload("res://ui/timeline/timeline_censor.gd")
const SELF_PATH := "res://modules/core_panels/censor_commands.gd"
const OWNER := "core_panels"


static func _script() -> GDScript:
	return load(SELF_PATH)


static func _cmd(id: String, handler: Callable, toggle: Callable = Callable()) -> void:
	var cat: Dictionary = Cmd.catalogue()
	var label: String = id
	var category: String = "Tools"
	if cat.has(id):
		label = String(cat[id]["label"])
		category = String(cat[id]["category"])
	var spec: Dictionary = {"label": label, "category": category, "scope": "global", "handler": handler, "owner": OWNER, "enabled": Callable(Bus, "has_doc_static")}
	if toggle.is_valid():
		spec["toggle"] = toggle
	Cmd.register(id, spec)


static func register_all() -> void:
	Censor.register_prefs()
	var script: GDScript = _script()
	_cmd("tool.censor", Callable(script, "use_tool"), Callable(script, "tool_is"))
	_cmd("seq.censor_in_out", Callable(script, "censor_in_out"))


static func use_tool() -> void:
	Session.set_tool(Censor.TOOL_ID)


static func tool_is() -> bool:
	return Session.tool_id == Censor.TOOL_ID


static func censor_in_out() -> int:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null or s == null:
		return 0
	if s.in_point < 0.0 or s.out_point < 0.0:
		Events.toast("Set an in point and an out point first")
		return 0
	var n: int = CensorCmds.censor_in_out(d, s)
	if n <= 0:
		Events.toast("No sound clips on the targeted tracks between the in and out points")
		return 0
	Events.toast("Censored " + str(n) + (" clip" if n == 1 else " clips") + " between the in and out points")
	return n


static func timeline_canvas() -> Control:
	var tl: Object = Bus.instance().panel("timeline")
	if tl == null:
		return null
	var c: Variant = tl.get("canvas")
	return c if c is Control else null


static func delete_selected() -> bool:
	return TimelineCensor.delete_selected(timeline_canvas())

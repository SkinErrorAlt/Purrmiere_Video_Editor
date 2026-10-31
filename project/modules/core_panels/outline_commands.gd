extends RefCounted

const Bus := preload("res://modules/core_panels/panel_bus.gd")
const ProgramSelect := preload("res://modules/core_panels/program_select.gd")
const SELF_PATH := "res://modules/core_panels/outline_commands.gd"
const OWNER := "core_panels"
const CMD_ID := "view.program_outline"


static func register_all() -> void:
	ProgramSelect.ensure_prefs(Prefs)
	var script: GDScript = load(SELF_PATH)
	var cat: Dictionary = Cmd.catalogue()
	var label: String = "Show the transform outline"
	var category: String = "View"
	if cat.has(CMD_ID):
		label = String(cat[CMD_ID]["label"])
		category = String(cat[CMD_ID]["category"])
	Cmd.register(CMD_ID, {"label": label, "category": category, "scope": "global", "handler": Callable(script, "toggle"), "owner": OWNER, "toggle": Callable(script, "is_on")})


static func toggle() -> void:
	var on: bool = not is_on()
	Prefs.set_value(ProgramSelect.PREF_SHOW, on)
	Events.toast("The transform outline is shown" if on else "The transform outline is hidden: clicks still select and a drag still moves the clip")


static func is_on() -> bool:
	return not Prefs.is_registered(ProgramSelect.PREF_SHOW) or bool(Prefs.get_value(ProgramSelect.PREF_SHOW))

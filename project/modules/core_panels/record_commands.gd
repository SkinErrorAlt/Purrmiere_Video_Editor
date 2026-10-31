extends RefCounted

const Bus := preload("res://modules/core_panels/panel_bus.gd")
const RecordCmds := preload("res://doc/commands/record_cmds.gd")
const SELF_PATH := "res://modules/core_panels/record_commands.gd"
const OWNER := "core_panels"
const CMD_ID := "keys.record"


static func register_all() -> void:
	RecordCmds.ensure_prefs()
	var script: GDScript = load(SELF_PATH)
	var cat: Dictionary = Cmd.catalogue()
	var label: String = "Record keys"
	var category: String = "Clip"
	if cat.has(CMD_ID):
		label = String(cat[CMD_ID]["label"])
		category = String(cat[CMD_ID]["category"])
	Cmd.register(CMD_ID, {"label": label, "category": category, "scope": "global", "handler": Callable(script, "toggle"), "owner": OWNER, "enabled": Callable(Bus, "has_doc_static"), "toggle": Callable(script, "is_on")})


static func toggle() -> void:
	Session.toggle_recording()
	Events.toast("Record keys is on: changes write keys at the playhead" if Session.recording else "Record keys is off")


static func is_on() -> bool:
	return bool(Session.recording)

extends "res://ui/kit/pm_button.gd"

const PmUIKit := preload("res://ui/kit/pm_ui.gd")
const MonitorSnap := preload("res://modules/core_panels/monitor_snap.gd")

var own_tip: bool = true


static func make_snap(with_tip: bool = true) -> Button:
	var script: GDScript = load("res://modules/core_panels/monitor_snap_button.gd")
	var b: Button = script.new()
	b.name = "SnapInMonitor"
	b.set("own_tip", with_tip)
	b.set("quiet", true)
	b.set("icon_name", "snap")
	b.toggle_mode = true
	return b


func _ready() -> void:
	super()
	if own_tip:
		PmUIKit.tip(self, MonitorSnap.TIP, Cmd.keys_text(MonitorSnap.CMD_ID))
	if not toggled.is_connected(_on_flip):
		toggled.connect(_on_flip)
	_sync()


func _enter_tree() -> void:
	super()
	MonitorSnap.ensure_prefs(Prefs)
	if not Prefs.changed.is_connected(_on_pref):
		Prefs.changed.connect(_on_pref)
	_sync()


func _exit_tree() -> void:
	super()
	if Prefs.changed.is_connected(_on_pref):
		Prefs.changed.disconnect(_on_pref)


func _on_pref(key: String) -> void:
	if key == MonitorSnap.PREF_ON:
		_sync()


func _sync() -> void:
	var on: bool = MonitorSnap.is_on()
	if button_pressed != on:
		button_pressed = on


func _on_flip(on: bool) -> void:
	if on != MonitorSnap.is_on():
		Prefs.set_value(MonitorSnap.PREF_ON, on)

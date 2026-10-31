extends "res://ui/kit/pm_button.gd"

const PmUIKit := preload("res://ui/kit/pm_ui.gd")
const RecordCmds := preload("res://doc/commands/record_cmds.gd")
const CMD_ID := "keys.record"
const TIP := "Record keys: while it is on, every change writes a key at the playhead"
const DOT_ON := Color(0.898, 0.282, 0.302, 1.0)
const DOT_OFF := Color(0.702, 0.259, 0.247, 1.0)
const WASH_ON := Color(0.898, 0.282, 0.302, 0.22)
const DOT_PX := 9.0

var lit: bool = false


static func make_record() -> Button:
	var script: GDScript = load("res://modules/core_panels/record_button.gd")
	var b: Button = script.new()
	b.name = "RecordKeys"
	b.set("quiet", true)
	return b


func _ready() -> void:
	super()
	RecordCmds.ensure_prefs()
	var side: float = float(Tk.px(Tk.sz("button_h")))
	custom_minimum_size = Vector2(side, side)
	PmUIKit.tip(self, TIP, Cmd.keys_text(CMD_ID))
	lit = bool(Session.recording)
	if not Session.recording_changed.is_connected(_on_recording):
		Session.recording_changed.connect(_on_recording)
	if not pressed.is_connected(_on_click):
		pressed.connect(_on_click)
	queue_redraw()


func _enter_tree() -> void:
	super()
	lit = bool(Session.recording)
	if not Session.recording_changed.is_connected(_on_recording):
		Session.recording_changed.connect(_on_recording)


func _exit_tree() -> void:
	super()
	if Session.recording_changed.is_connected(_on_recording):
		Session.recording_changed.disconnect(_on_recording)


func _on_click() -> void:
	Session.toggle_recording()


func _on_recording(on: bool) -> void:
	lit = on
	queue_redraw()


func _draw() -> void:
	var r: float = float(Tk.px(Tk.sz("radius")))
	if lit:
		var wash := StyleBoxFlat.new()
		wash.bg_color = WASH_ON
		wash.set_corner_radius_all(int(r))
		draw_style_box(wash, Rect2(Vector2.ZERO, size))
	var d: float = float(Tk.px(DOT_PX))
	var centre: Vector2 = (size * 0.5).round()
	if lit:
		draw_circle(centre, d * 0.5, DOT_ON, true, -1.0, true)
	else:
		draw_arc(centre, d * 0.5 - 0.75, 0.0, TAU, 24, DOT_OFF, 1.5, true)

extends LineEdit

signal time_entered(t: float)

const Timecode := preload("res://doc/timecode.gd")

var fps: float = 30.0
var drop_frame: bool = false
var time: float = 0.0
var _editing: bool = false


static func make(fps_: float = 30.0) -> LineEdit:
	var script: GDScript = load("res://ui/timeline/timecode_field.gd")
	var f: LineEdit = script.new()
	f.set("fps", fps_)
	return f


func _init() -> void:
	context_menu_enabled = false
	focus_mode = Control.FOCUS_CLICK
	text_submitted.connect(_on_submitted)
	focus_entered.connect(_on_focus_in)
	focus_exited.connect(_on_focus_out)
	gui_input.connect(_on_input)


func _ready() -> void:
	add_theme_font_override("font", Tk.font("mono"))
	add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_body")))
	add_theme_color_override("font_color", Tk.c["text_bright"])
	custom_minimum_size = Vector2(float(Tk.px(96.0)), float(Tk.px(Tk.sz("field_h"))))
	_refresh()


func set_time(t: float) -> void:
	time = maxf(t, 0.0)
	if not _editing:
		_refresh()


func set_rate(fps_: float, drop: bool) -> void:
	fps = fps_ if fps_ > 0.0 else 30.0
	drop_frame = drop
	if not _editing:
		_refresh()


func _refresh() -> void:
	text = Timecode.format(time, fps, drop_frame)


func _on_focus_in() -> void:
	_editing = true
	select_all()


func _on_focus_out() -> void:
	_editing = false
	_refresh()


func _on_submitted(raw: String) -> void:
	var v: float = Timecode.parse(raw, fps, time)
	if is_nan(v):
		_refresh()
	else:
		time = maxf(v, 0.0)
		_refresh()
		time_entered.emit(time)
	release_focus()


func _on_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and k.keycode == KEY_ESCAPE:
			accept_event()
			_refresh()
			release_focus()

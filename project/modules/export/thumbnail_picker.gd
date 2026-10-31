extends Control

signal time_changed(t: float)

const PmText := preload("res://ui/kit/pm_text.gd")
const BAR_H := 10.0

var range_start: float = 0.0
var range_end: float = 10.0
var time: float = 0.0
var preview: Texture2D = null
var _dragging: bool = false
var _hover: bool = false


static func make() -> Control:
	var script: GDScript = load("res://modules/export/thumbnail_picker.gd")
	var p: Control = script.new()
	return p


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(float(Tk.px(160.0)), float(Tk.px(110.0)))
	gui_input.connect(_on_input)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)


func set_range(a: float, b: float) -> void:
	range_start = a
	range_end = maxf(b, a + 0.001)
	time = clampf(time, range_start, range_end)
	queue_redraw()


func set_time(t: float, emit: bool = false) -> void:
	var nt: float = clampf(t, range_start, range_end)
	if is_equal_approx(nt, time):
		return
	time = nt
	queue_redraw()
	if emit:
		time_changed.emit(time)


func set_preview(tex: Texture2D) -> void:
	preview = tex
	queue_redraw()


func _bar_rect() -> Rect2:
	var bar_h: float = float(Tk.px(BAR_H))
	return Rect2(0.0, size.y - bar_h, size.x, bar_h)


func _time_at(x: float) -> float:
	var f: float = clampf(x / maxf(size.x, 1.0), 0.0, 1.0)
	return range_start + (range_end - range_start) * f


func _on_enter() -> void:
	_hover = true
	queue_redraw()


func _on_exit() -> void:
	_hover = false
	queue_redraw()


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				set_time(_time_at(mb.position.x), true)
			else:
				_dragging = false
			accept_event()
		return
	if event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		set_time(_time_at(mm.position.x), true)
		accept_event()


func _draw() -> void:
	var bar: Rect2 = _bar_rect()
	var pic: Rect2 = Rect2(0.0, 0.0, size.x, maxf(size.y - bar.size.y - 2.0, 1.0))
	draw_rect(pic, Tk.c["bg_field"], true)
	if preview != null:
		var ts: Vector2 = preview.get_size()
		if ts.x > 0.0 and ts.y > 0.0:
			var s: float = minf(pic.size.x / ts.x, pic.size.y / ts.y)
			var ds: Vector2 = ts * s
			var at: Vector2 = pic.position + (pic.size - ds) * 0.5
			draw_texture_rect(preview, Rect2(at, ds), false)
	draw_rect(bar, Tk.c["bg_panel_high"] if _hover else Tk.c["bg_field"], true)
	var span: float = maxf(range_end - range_start, 0.001)
	var x: float = bar.position.x + bar.size.x * ((time - range_start) / span)
	draw_rect(Rect2(x - 1.0, bar.position.y, 2.0, bar.size.y), Tk.c["accent"], true)
	var font: Font = Tk.font("mono")
	var fsz: int = Tk.fs(Tk.sz("font_small"))
	var lh: float = font.get_height(fsz)
	PmText.draw(self, font, Rect2(0.0, bar.position.y - 2.0 - lh, size.x, lh), String.num(time, 2) + " s", fsz, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, NAN, PmText.WHOLE)

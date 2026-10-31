extends Node

signal changed
signal zoom_requested(steps: float, at: Vector2)

const SMOOTHING := 16.0
const SNAP := 0.5

var scroll_x: float = 0.0
var scroll_y: float = 0.0
var target_x: float = 0.0
var target_y: float = 0.0
var pps: float = 100.0
var pps_min: float = 0.0001
var pps_max: float = 100000.0
var content_w: float = 0.0
var content_h: float = 0.0
var view_w: float = 0.0
var view_h: float = 0.0
var tail_x: float = 0.0
var tail_y: float = 0.0
var wheel_step: float = 48.0
var horizontal_primary: bool = false
var alt_wheel_zooms: bool = true
var ctrl_wheel_zooms: bool = true
var smooth: bool = true
var _panning: bool = false
var _pan_last: Vector2 = Vector2.ZERO


static func make(horizontal_primary_: bool = false) -> Node:
	var script: GDScript = load("res://ui/kit/pm_scroll.gd")
	var s: Node = script.new()
	s.set("horizontal_primary", horizontal_primary_)
	return s


func _init() -> void:
	name = "PmScroll"
	set_process(true)


func max_x() -> float:
	return maxf(0.0, content_w - view_w + tail_x)


func max_y() -> float:
	return maxf(0.0, content_h - view_h + tail_y)


func set_content(w: float, h: float) -> void:
	content_w = maxf(0.0, w)
	content_h = maxf(0.0, h)
	clamp_targets()


func set_view(w: float, h: float) -> void:
	view_w = maxf(0.0, w)
	view_h = maxf(0.0, h)
	clamp_targets()


func clamp_targets() -> void:
	target_x = clampf(target_x, 0.0, max_x())
	target_y = clampf(target_y, 0.0, max_y())
	if not smooth:
		_settle()


func set_pps(v: float) -> void:
	pps = clampf(v, pps_min, pps_max)


func scroll_to(x: float, y: float, animate: bool = true) -> void:
	target_x = clampf(x, 0.0, max_x())
	target_y = clampf(y, 0.0, max_y())
	if not animate or not smooth:
		_settle()


func scroll_by(dx: float, dy: float, animate: bool = true) -> void:
	scroll_to(target_x + dx, target_y + dy, animate)


func is_animating() -> bool:
	return scroll_x != target_x or scroll_y != target_y


func is_panning() -> bool:
	return _panning


func _settle() -> void:
	var moved: bool = scroll_x != target_x or scroll_y != target_y
	scroll_x = target_x
	scroll_y = target_y
	if moved:
		changed.emit()


func _wheel_steps(mb: InputEventMouseButton) -> float:
	var f: float = mb.factor if mb.factor > 0.0 else 1.0
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT:
		return -f
	return f


func handle(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		var is_wheel: bool = mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT
		if is_wheel:
			if not mb.pressed:
				return true
			var steps: float = _wheel_steps(mb)
			if (mb.ctrl_pressed and ctrl_wheel_zooms) or (mb.alt_pressed and alt_wheel_zooms):
				zoom_requested.emit(-steps, mb.position)
				return true
			var on_x: bool = horizontal_primary
			if mb.shift_pressed:
				on_x = not on_x
			if mb.button_index == MOUSE_BUTTON_WHEEL_LEFT or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
				on_x = true
			if on_x:
				scroll_by(steps * wheel_step, 0.0)
			else:
				scroll_by(0.0, steps * wheel_step)
			return true
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_panning = true
				_pan_last = mb.position
			else:
				_panning = false
			return true
		return false
	if event is InputEventMouseMotion and _panning:
		var mm: InputEventMouseMotion = event
		var delta: Vector2 = mm.position - _pan_last
		_pan_last = mm.position
		target_x = clampf(target_x - delta.x, 0.0, max_x())
		target_y = clampf(target_y - delta.y, 0.0, max_y())
		_settle()
		return true
	return false


func _process(dt: float) -> void:
	if not smooth:
		return
	if scroll_x == target_x and scroll_y == target_y:
		return
	var k: float = 1.0 - exp(-SMOOTHING * dt)
	scroll_x = lerpf(scroll_x, target_x, k)
	scroll_y = lerpf(scroll_y, target_y, k)
	if absf(scroll_x - target_x) < SNAP:
		scroll_x = target_x
	if absf(scroll_y - target_y) < SNAP:
		scroll_y = target_y
	changed.emit()

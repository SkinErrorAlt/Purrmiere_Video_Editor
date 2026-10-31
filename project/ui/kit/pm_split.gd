extends Container

signal ratio_changed(r: float)

const HANDLE := 4.0
const HANDLE_HOVER := 6.0
const PREF_PREFIX := "ui.split."

var vertical: bool = false:
	set(v):
		vertical = v
		_update_cursor()
		queue_sort()
var ratio: float = 0.5:
	set(v):
		ratio = clampf(v, 0.0, 1.0)
		queue_sort()
var default_ratio: float = 0.5
var key: String = ""
var _handle: Control = null
var _drag: bool = false
var _hover: bool = false


static func make(vertical_: bool = false, ratio_: float = 0.5, key_: String = "") -> Container:
	var script: GDScript = load("res://ui/kit/pm_split.gd")
	var s: Container = script.new()
	s.set("vertical", vertical_)
	s.set("ratio", ratio_)
	s.set("default_ratio", ratio_)
	s.set("key", key_)
	return s


func _init() -> void:
	name = "PmSplit"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_handle = _Handle.new()
	_handle.split = self
	_handle.gui_input.connect(_on_input)
	_handle.mouse_entered.connect(_on_handle_enter)
	_handle.mouse_exited.connect(_on_handle_exit)
	add_child(_handle)
	_update_cursor()


func _ready() -> void:
	if not key.is_empty():
		var pk: String = PREF_PREFIX + key
		if not Prefs.is_registered(pk):
			Prefs.register(pk, default_ratio, {"label": "Split ratio: " + key, "type": "float", "min": 0.0, "max": 1.0})
		ratio = float(Prefs.get_value(pk))
	move_child(_handle, -1)


func _update_cursor() -> void:
	if _handle != null:
		_handle.mouse_default_cursor_shape = Control.CURSOR_VSPLIT if vertical else Control.CURSOR_HSPLIT


func set_pair(a: Control, b: Control) -> void:
	for c: Node in get_children():
		if c != _handle:
			remove_child(c)
			c.queue_free()
	add_child(a)
	add_child(b)
	move_child(_handle, -1)


func first() -> Control:
	for c: Node in get_children():
		if c != _handle and c is Control:
			return c
	return null


func second() -> Control:
	var seen: bool = false
	for c: Node in get_children():
		if c == _handle or not (c is Control):
			continue
		if seen:
			return c
		seen = true
	return null


func handle_rect() -> Rect2:
	return _handle.get_rect()


func _handle_px() -> float:
	return float(Tk.px(HANDLE_HOVER))


func _get_minimum_size() -> Vector2:
	var a: Control = first()
	var b: Control = second()
	var ma: Vector2 = a.get_combined_minimum_size() if a != null else Vector2.ZERO
	var mb: Vector2 = b.get_combined_minimum_size() if b != null else Vector2.ZERO
	var hp: float = _handle_px()
	if vertical:
		return Vector2(maxf(ma.x, mb.x), ma.y + mb.y + hp)
	return Vector2(ma.x + mb.x + hp, maxf(ma.y, mb.y))


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort()


func _sort() -> void:
	var a: Control = first()
	var b: Control = second()
	var hp: float = _handle_px()
	if a == null and b == null:
		fit_child_in_rect(_handle, Rect2(Vector2.ZERO, Vector2.ZERO))
		return
	if a == null or b == null:
		var only: Control = a if a != null else b
		fit_child_in_rect(only, Rect2(Vector2.ZERO, size))
		fit_child_in_rect(_handle, Rect2(Vector2.ZERO, Vector2.ZERO))
		_handle.visible = false
		return
	_handle.visible = true
	var ma: Vector2 = a.get_combined_minimum_size()
	var mb: Vector2 = b.get_combined_minimum_size()
	if vertical:
		var total: float = maxf(0.0, size.y - hp)
		var a_len: float = clampf(round(total * ratio), ma.y, maxf(ma.y, total - mb.y))
		fit_child_in_rect(a, Rect2(0.0, 0.0, size.x, a_len))
		fit_child_in_rect(_handle, Rect2(0.0, a_len, size.x, hp))
		fit_child_in_rect(b, Rect2(0.0, a_len + hp, size.x, maxf(0.0, total - a_len)))
	else:
		var total: float = maxf(0.0, size.x - hp)
		var a_len: float = clampf(round(total * ratio), ma.x, maxf(ma.x, total - mb.x))
		fit_child_in_rect(a, Rect2(0.0, 0.0, a_len, size.y))
		fit_child_in_rect(_handle, Rect2(a_len, 0.0, hp, size.y))
		fit_child_in_rect(b, Rect2(a_len + hp, 0.0, maxf(0.0, total - a_len), size.y))


func _on_handle_enter() -> void:
	_hover = true
	_handle.queue_redraw()


func _on_handle_exit() -> void:
	_hover = false
	_handle.queue_redraw()


func is_hovered() -> bool:
	return _hover or _drag


func _persist() -> void:
	if not key.is_empty():
		Prefs.set_value(PREF_PREFIX + key, ratio)
	ratio_changed.emit(ratio)


func reset_ratio() -> void:
	ratio = default_ratio
	_persist()


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if mb.double_click:
				_drag = false
				reset_ratio()
			else:
				_drag = true
			_handle.accept_event()
		else:
			if _drag:
				_drag = false
				_persist()
			_handle.queue_redraw()
			_handle.accept_event()
		return
	if event is InputEventMouseMotion and _drag:
		var local: Vector2 = get_local_mouse_position()
		var hp: float = _handle_px()
		var total: float = maxf(1.0, (size.y if vertical else size.x) - hp)
		var along: float = (local.y if vertical else local.x) - hp * 0.5
		ratio = clampf(along / total, 0.0, 1.0)
		_handle.accept_event()


class _Handle:
	extends Control

	var split: Container = null

	func _init() -> void:
		name = "Handle"
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE

	func _draw() -> void:
		if split == null:
			return
		var hot: bool = bool(split.call("is_hovered"))
		var w: float = float(Tk.px(HANDLE_HOVER if hot else HANDLE))
		var col: Color = Tk.c["accent_dim"] if hot else Tk.c["border"]
		if bool(split.get("vertical")):
			draw_rect(Rect2(0.0, (size.y - w) * 0.5, size.x, w), col, true)
		else:
			draw_rect(Rect2((size.x - w) * 0.5, 0.0, w, size.y), col, true)

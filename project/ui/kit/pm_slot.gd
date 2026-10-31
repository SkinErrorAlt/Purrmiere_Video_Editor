extends Control

signal dropped(payload: Dictionary, local_pos: Vector2)
signal hover_changed(on: bool)
signal hover_moved(local_pos: Vector2)

const GROUP := "pm_slot"

var kinds: PackedStringArray = PackedStringArray()
var priority: int = 0
var can_accept_cb: Callable = Callable()
var hovering: bool = false
var draw_highlight: bool = true


static func make(kinds_: PackedStringArray = PackedStringArray()) -> Control:
	var script: GDScript = load("res://ui/kit/pm_slot.gd")
	var s: Control = script.new()
	s.set("kinds", kinds_)
	return s


func _init() -> void:
	name = "PmSlot"
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	add_to_group(GROUP)


func can_accept(payload: Dictionary) -> bool:
	if not kinds.is_empty():
		var kind: String = String(payload.get("kind", ""))
		if not (kind in kinds):
			return false
	if can_accept_cb.is_valid():
		return bool(can_accept_cb.call(payload))
	return true


func accept(payload: Dictionary, local_pos: Vector2) -> void:
	set_hover(false)
	dropped.emit(payload, local_pos)


func set_hover(on: bool) -> void:
	if hovering == on:
		return
	hovering = on
	queue_redraw()
	hover_changed.emit(on)


func hover_at(local_pos: Vector2) -> void:
	hover_moved.emit(local_pos)


func _draw() -> void:
	if not hovering or not draw_highlight:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Tk.c["selection_fill"], true)
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2(1.0, 1.0)), Tk.c["accent"], false, 1.0)

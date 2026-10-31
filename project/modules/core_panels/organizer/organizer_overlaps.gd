extends Control

signal picked(region_id: String)
signal node_menu(region_id: String, at: Vector2)
signal closed

const Regions := preload("res://doc/media_regions.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const NODE_W := 168.0
const NODE_H := 38.0
const REACH := 70.0
const NODE_GAP := 8.0
const CURVE_STEPS := 16
const HUB_R := 9.0
const OPEN_S := 0.32
const CLOSE_S := 0.16
const STAGGER := 0.05

var media_id: String = ""
var at_t: float = 0.0
var regions: Array = []
var hub: Vector2 = Vector2.ZERO
var grow: float = 0.0
var hover: int = -1
var _closing: bool = false
var _tween: Tween = null


func _init() -> void:
	name = "OrganizerOverlaps"
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gui_input.connect(_on_input)


func open(p_media_id: String, t: float, list: Array, global_at: Vector2) -> void:
	media_id = p_media_id
	at_t = t
	regions = list
	hub = global_at - get_global_rect().position
	grow = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "grow", 1.0 + STAGGER * float(regions.size()), OPEN_S + STAGGER * float(regions.size())).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	grab_focus.call_deferred()
	queue_redraw()


func _process(_dt: float) -> void:
	if _tween != null and _tween.is_valid() and _tween.is_running():
		queue_redraw()


func amount(i: int) -> float:
	var a: float = clampf(grow - STAGGER * float(i), 0.0, 1.0)
	var c: float = 1.70158
	var u: float = a - 1.0
	return 1.0 + (c + 1.0) * u * u * u + c * u * u


func side() -> float:
	return -1.0 if hub.x + REACH + NODE_W + 8.0 > size.x else 1.0


func column_top() -> float:
	var total: float = float(regions.size()) * (NODE_H + NODE_GAP) - NODE_GAP
	return clampf(hub.y - total * 0.5, 6.0, maxf(size.y - total - 6.0, 6.0))


func target(i: int) -> Vector2:
	var x: float = hub.x + side() * (REACH + NODE_W * 0.5)
	var y: float = column_top() + float(i) * (NODE_H + NODE_GAP) + NODE_H * 0.5
	return Vector2(x, y)


func spot(i: int) -> Vector2:
	return hub.lerp(target(i), amount(i))


func curve(i: int) -> PackedVector2Array:
	var p: Vector2 = spot(i)
	var end: Vector2 = Vector2(p.x - side() * node_rect(i).size.x * 0.5, p.y)
	var bend: float = (end.x - hub.x) * 0.5
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in CURVE_STEPS + 1:
		var u: float = float(k) / float(CURVE_STEPS)
		var a: Vector2 = hub
		var b: Vector2 = hub + Vector2(bend, 0.0)
		var c: Vector2 = end - Vector2(bend, 0.0)
		var v: float = 1.0 - u
		pts.append(a * v * v * v + b * 3.0 * v * v * u + c * 3.0 * v * u * u + end * u * u * u)
	return pts


func node_rect(i: int) -> Rect2:
	var p: Vector2 = spot(i)
	var k: float = clampf(amount(i), 0.2, 1.05)
	var sz: Vector2 = Vector2(NODE_W, NODE_H) * k
	return Rect2(p - sz * 0.5, sz)


func node_at(pos: Vector2) -> int:
	for i: int in range(regions.size() - 1, -1, -1):
		if node_rect(i).has_point(pos):
			return i
	return -1


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h: int = node_at((event as InputEventMouseMotion).position)
		if h != hover:
			hover = h
			queue_redraw()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		accept_event()
		return
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return
	var mb: InputEventMouseButton = event
	var i: int = node_at(mb.position)
	accept_event()
	if i < 0:
		close()
		return
	var rid: String = String((regions[i] as Dictionary).get("id", ""))
	if mb.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(rid)
		close()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		node_menu.emit(rid, mb.global_position)


func close() -> void:
	if _closing:
		return
	_closing = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "grow", 0.0, CLOSE_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.finished.connect(_gone)


func _gone() -> void:
	closed.emit()
	var p: Node = get_parent()
	if p != null:
		p.remove_child(self)
	queue_free()


func _draw() -> void:
	var veil: Color = Color(Tk.c["bg_app"], 0.35 * clampf(grow, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), veil, true)
	var font: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var tiny: int = Tk.fs(Tk.sz("font_tiny"))
	for i: int in regions.size():
		var rd: Dictionary = regions[i]
		var col: Color = Regions.colour_of(rd)
		draw_polyline(curve(i), Color(col, 0.85 * clampf(amount(i), 0.0, 1.0)), 2.0, true)
	draw_circle(hub, HUB_R, Tk.c["bg_panel_high"])
	draw_arc(hub, HUB_R, 0.0, TAU, 32, Tk.c["text_bright"], 1.5, true)
	for i: int in regions.size():
		var rd: Dictionary = regions[i]
		var rc: Rect2 = node_rect(i)
		var col: Color = Regions.colour_of(rd)
		var a: float = clampf(amount(i), 0.0, 1.0)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(Tk.c["bg_panel_high"], a)
		box.border_color = Color(col, a)
		box.set_border_width_all(2 if i == hover else 1)
		box.set_corner_radius_all(6)
		box.anti_aliasing = true
		draw_style_box(box, rc)
		draw_rect(Rect2(rc.position + Vector2(6.0, 6.0), Vector2(6.0, rc.size.y - 12.0)), Color(col, a), true)
		if a > 0.6:
			var name_text: String = Kinds.name_of(String(rd.get("kind", "")))
			var span: String = "%s to %s" % [_clock(float(rd.get("from", 0.0))), _clock(float(rd.get("to", 0.0)))]
			PmText.draw_at(self, font, rc.position + Vector2(18.0, 16.0), name_text, fs, Color(Tk.c["text_bright"], a), rc.size.x - 22.0)
			PmText.draw_at(self, font, rc.position + Vector2(18.0, 31.0), span, tiny, Color(Tk.c["text_dim"], a), rc.size.x - 22.0)


static func _clock(t: float) -> String:
	var whole: int = int(floor(maxf(t, 0.0) + 0.0005))
	var h: int = whole / 3600
	var m: int = (whole % 3600) / 60
	var s: int = whole % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%d:%02d" % [m, s]

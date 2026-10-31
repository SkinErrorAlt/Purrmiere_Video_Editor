extends CanvasLayer

signal drag_started(payload: Dictionary)
signal drag_ended(payload: Dictionary, dropped: bool)
signal dropped_outside(payload: Dictionary, at: Vector2)

const PmUI := preload("res://ui/kit/pm_ui.gd")
const GROUP := "pm_drag_layer"
const SLOT_GROUP := "pm_slot"
const FLOAT_GROUP := "pm_float_window"
const LAYER := 100

var active: bool = false
var payload: Dictionary = {}
var poll: bool = true
var _ghost: Control = null
var _grab: Vector2 = Vector2.ZERO
var _hover_slot: Control = null
var _last_pos: Vector2 = Vector2.ZERO
var _fade: Tween = null


static func find(node: Node) -> CanvasLayer:
	if node == null or not node.is_inside_tree():
		return null
	var tree: SceneTree = node.get_tree()
	var found: Node = tree.get_first_node_in_group(GROUP)
	if found != null and found is CanvasLayer:
		return found
	var overlay: Node = tree.get_first_node_in_group(PmUI.OVERLAY_GROUP)
	if overlay == null:
		overlay = tree.root
	var script: GDScript = load("res://ui/kit/pm_drag_layer.gd")
	var layer: CanvasLayer = script.new()
	overlay.add_child(layer)
	return layer


func _init() -> void:
	name = "PmDragLayer"
	layer = LAYER
	add_to_group(GROUP)
	set_process(true)


func _set_ignore(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in c.get_children():
		if child is Control:
			_set_ignore(child)


func begin(payload_: Dictionary, ghost: Control, grab_offset: Vector2 = Vector2.ZERO) -> void:
	if active:
		cancel()
	payload = payload_.duplicate(true)
	if not payload.has("kind"):
		payload["kind"] = ""
	active = true
	_grab = grab_offset
	_ghost = ghost
	if _ghost != null:
		_set_ignore(_ghost)
		_ghost.top_level = false
		add_child(_ghost)
		var d: float = Tk.dur("fast")
		if d > 0.0 and is_inside_tree():
			_ghost.modulate.a = 0.0
			_fade = create_tween()
			_fade.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			_fade.tween_property(_ghost, "modulate:a", 1.0, d)
		else:
			_ghost.modulate.a = 1.0
	var start: Vector2 = _last_pos
	if is_inside_tree():
		start = pointer()
	drag_started.emit(payload)
	update(start)


func slot_at(pos: Vector2) -> Control:
	if not is_inside_tree():
		return null
	var hit: Control = null
	var best: int = 0
	var over: Window = window_at(pos)
	for n: Node in get_tree().get_nodes_in_group(SLOT_GROUP):
		if not (n is Control):
			continue
		var c: Control = n
		if not c.is_visible_in_tree():
			continue
		if over != null and c.get_window() != over:
			continue
		var p: Vector2 = slot_point(c, pos)
		if not c.get_global_rect().has_point(p) or not shown_at(c, p):
			continue
		if not bool(c.call("can_accept", payload)):
			continue
		var pv: Variant = c.get("priority")
		var rank: int = int(pv) if pv is int else 0
		if hit == null or rank >= best:
			hit = c
			best = rank
	return hit


func floats() -> Array[Window]:
	var out: Array[Window] = []
	if not is_inside_tree():
		return out
	var home: Window = get_window()
	for n: Node in get_tree().get_nodes_in_group(FLOAT_GROUP):
		if n is Window and n != home and (n as Window).visible and (n as Window).is_inside_tree():
			out.append(n)
	return out


func pointer() -> Vector2:
	var home: Window = get_window()
	if home != null and DisplayServer.get_name() != "headless" and not floats().is_empty():
		return Vector2(DisplayServer.mouse_get_position() - home.position)
	return get_viewport().get_mouse_position()


func window_at(pos: Vector2) -> Window:
	var list: Array[Window] = floats()
	if list.is_empty():
		return null
	var home: Window = get_window()
	var screen: Vector2i = home.position + Vector2i(pos.round())
	for w: Window in list:
		if Rect2i(w.position, w.size).has_point(screen):
			return w
	return home


func slot_point(c: Control, pos: Vector2) -> Vector2:
	if not is_inside_tree() or not c.is_inside_tree():
		return pos
	var home: Window = get_window()
	var w: Window = c.get_window()
	if home == null or w == null or w == home:
		return pos
	return pos + Vector2(home.position - w.position)


static func shown_at(c: Control, pos: Vector2) -> bool:
	var up: Node = c.get_parent()
	while up != null and not (up is Viewport):
		if up is Control and (up as Control).clip_contents and not (up as Control).get_global_rect().has_point(pos):
			return false
		up = up.get_parent()
	return true


func update(pos: Vector2) -> void:
	if not active:
		return
	_last_pos = pos
	if _ghost != null:
		_ghost.position = (pos - _grab).round()
	var slot: Control = slot_at(pos)
	if slot != _hover_slot:
		if _hover_slot != null and is_instance_valid(_hover_slot):
			_hover_slot.call("set_hover", false)
		_hover_slot = slot
		if slot != null:
			slot.call("set_hover", true)
	if slot != null:
		slot.call("hover_at", slot.get_global_transform().affine_inverse() * slot_point(slot, pos))


func drop() -> void:
	if not active:
		return
	var pos: Vector2 = _last_pos
	var slot: Control = slot_at(pos)
	var p: Dictionary = payload
	_end_ghost(false)
	if _hover_slot != null and is_instance_valid(_hover_slot):
		_hover_slot.call("set_hover", false)
	_hover_slot = null
	if slot != null:
		var local: Vector2 = slot.get_global_transform().affine_inverse() * slot_point(slot, pos)
		slot.call("accept", p, local)
		drag_ended.emit(p, true)
	else:
		dropped_outside.emit(p, pos)
		drag_ended.emit(p, false)
	payload = {}


func cancel() -> void:
	if not active:
		return
	var p: Dictionary = payload
	_end_ghost(true)
	if _hover_slot != null and is_instance_valid(_hover_slot):
		_hover_slot.call("set_hover", false)
	_hover_slot = null
	drag_ended.emit(p, false)
	payload = {}


func _end_ghost(fade: bool) -> void:
	active = false
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
	var g: Control = _ghost
	_ghost = null
	if g == null:
		return
	var d: float = Tk.dur("fast")
	if fade and d > 0.0 and g.is_inside_tree():
		var tw: Tween = g.create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(g, "modulate:a", 0.0, d)
		tw.tween_callback(Callable(PmUI, "free_node").bind(g))
	else:
		PmUI.free_node(g)


func _process(_dt: float) -> void:
	if not active or not poll or not is_inside_tree():
		return
	if Input.is_key_pressed(KEY_ESCAPE):
		cancel()
		return
	var pos: Vector2 = pointer()
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		update(pos)
		drop()
		return
	update(pos)

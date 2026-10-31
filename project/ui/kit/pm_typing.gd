extends Node

const SELF_PATH := "res://ui/kit/pm_typing.gd"
const NODE_NAME := "PmTypingWatch"
const ENDING_BUTTONS: Array[MouseButton] = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
const KEEP_GROUP := "pm_keeps_typing"

static var enabled: bool = true
static var ended: int = 0
static var _watchers: Array[Node] = []


static func watch_tree(tree: SceneTree) -> void:
	if tree == null:
		return
	Callable(load(SELF_PATH), "attach").call_deferred(tree.root)
	var hook: Callable = Callable(load(SELF_PATH), "_on_node_added")
	if not tree.node_added.is_connected(hook):
		tree.node_added.connect(hook)


static func _on_node_added(n: Node) -> void:
	if n is Window and not (n is Popup) and n.name != NODE_NAME:
		Callable(load(SELF_PATH), "attach").call_deferred(n)


static func attach(w: Window) -> Node:
	if w == null or not is_instance_valid(w) or not w.is_inside_tree():
		return null
	var existing: Node = w.get_node_or_null(NODE_NAME)
	if existing != null:
		return existing
	var watcher: Node = (load(SELF_PATH) as GDScript).new()
	watcher.name = NODE_NAME
	w.add_child(watcher, false, Node.INTERNAL_MODE_BACK)
	return watcher


static func watchers() -> int:
	return _watchers.size()


static func is_typing(c: Control) -> bool:
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return false
	if c is LineEdit:
		return (c as LineEdit).editable
	if c is TextEdit:
		return (c as TextEdit).editable
	return false


static func inside(c: Control, pos: Vector2) -> bool:
	var local: Vector2 = c.get_global_transform_with_canvas().affine_inverse() * pos
	return Rect2(Vector2.ZERO, c.size).has_point(local)


static func keeps_typing(vp: Viewport, pos: Vector2) -> bool:
	if vp == null:
		return false
	for n: Node in vp.get_tree().get_nodes_in_group(KEEP_GROUP):
		var c: Control = n as Control
		if c != null and c.is_visible_in_tree() and c.get_viewport() == vp and inside(c, pos):
			return true
	return false


static func end_typing(c: Control) -> void:
	ended += 1
	if c is LineEdit:
		var le: LineEdit = c
		le.text_submitted.emit(le.text)
	if is_instance_valid(c) and c.is_inside_tree() and c.has_focus():
		c.release_focus()


static func typing_control() -> Control:
	for w: Node in _watchers:
		if is_instance_valid(w) and w.is_inside_tree():
			var owner: Control = w.get_viewport().gui_get_focus_owner()
			if is_typing(owner):
				return owner
	return null


func _enter_tree() -> void:
	if not (self in _watchers):
		_watchers.append(self)


func _exit_tree() -> void:
	_watchers.erase(self)


func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed or not (mb.button_index in ENDING_BUTTONS):
		return
	var here: Viewport = get_viewport()
	for w: Node in _watchers.duplicate():
		if not is_instance_valid(w) or not w.is_inside_tree():
			continue
		var vp: Viewport = w.get_viewport()
		var owner: Control = vp.gui_get_focus_owner()
		if not is_typing(owner):
			continue
		if vp == here and inside(owner, mb.position):
			continue
		if vp == here and keeps_typing(vp, mb.position):
			continue
		end_typing(owner)

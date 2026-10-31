extends RefCounted

const SELF_PATH := "res://modules/core_panels/file_drop_router.gd"

static var _tree: SceneTree = null
static var _bins: Array[WeakRef] = []
static var _windows: Dictionary = {}
static var routed: int = 0
static var plant_visible_only: bool = false


static func attach(tree: SceneTree, bin: Object) -> void:
	if tree == null or bin == null:
		return
	var known: bool = false
	for w: WeakRef in _bins:
		if w.get_ref() == bin:
			known = true
	if not known:
		_bins.append(weakref(bin))
	if _tree != tree:
		_tree = tree
		_windows = {}
		var script: GDScript = load(SELF_PATH)
		if not tree.node_added.is_connected(Callable(script, "_on_node_added")):
			tree.node_added.connect(Callable(script, "_on_node_added"))
	_watch(tree.root)
	for n: Node in tree.root.find_children("*", "Window", true, false):
		_watch(n as Window)


static func _on_node_added(n: Node) -> void:
	if n is Window:
		_watch(n as Window)


static func _watch(w: Window) -> void:
	if w == null or _windows.has(w.get_instance_id()):
		return
	_windows[w.get_instance_id()] = true
	var script: GDScript = load(SELF_PATH)
	var cb: Callable = Callable(script, "_on_files").bind(weakref(w))
	if not w.files_dropped.is_connected(cb):
		w.files_dropped.connect(cb)


static func bin() -> Object:
	var best: Object = null
	for w: WeakRef in _bins:
		var b: Object = w.get_ref()
		if b == null or not is_instance_valid(b):
			continue
		if best == null:
			best = b
		var root: Variant = b.call("root") if b.has_method("root") else null
		if root is Control and is_instance_valid(root) and (root as Control).is_visible_in_tree():
			return b
	return null if plant_visible_only else best


static func _on_files(files: PackedStringArray, wr: WeakRef) -> void:
	var w: Window = wr.get_ref() as Window
	if w == null:
		return
	route(files, w, w.get_mouse_position())


static func route(files: PackedStringArray, w: Window, pos: Vector2) -> bool:
	var b: Object = bin()
	if b == null:
		return false
	routed += 1
	b.call("on_files_dropped_in", files, w, pos)
	return true

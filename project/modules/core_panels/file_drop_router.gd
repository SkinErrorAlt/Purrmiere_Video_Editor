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


## Modules dropped on the window install and show their card; files a module opens go to it. Returns the rest.
static func take_module_files(files: PackedStringArray, w: Window) -> PackedStringArray:
	var install: GDScript = load("res://host/module_install.gd")
	var extras: Object = load("res://host/module_extras.gd").call("shared")
	var rest: PackedStringArray = PackedStringArray()
	var captions: GDScript = load("res://doc/captions.gd")
	for f: String in files:
		if bool(install.call("is_module", f)):
			install_and_show(f, w)
			continue
		if bool(captions.call("is_caption_file", f)) and Session.doc != null and Session.seq() != null:
			(load("res://modules/core_panels/captions_ui.gd") as GDScript).call("import_path", f)
			continue
		var fmt: Dictionary = extras.call("format_for", f)
		if not fmt.is_empty() and bool((fmt["open"] as Callable).call(f)):
			continue
		rest.append(f)
	var screen: Node = w.find_child("EditorScreen", true, false) if w != null else null
	var dock: Object = screen.get("dock") if screen != null else null
	var handler: Callable = extras.call("drop_handler_for", String(dock.get("layout_name"))) if dock != null else Callable()
	if handler.is_valid() and not rest.is_empty():
		var left: Variant = handler.call(rest)
		if left is PackedStringArray:
			return left
	return rest


static func install_and_show(path: String, w: Window) -> Dictionary:
	var install: GDScript = load("res://host/module_install.gd")
	var res: Dictionary = install.call("install", path)
	var loop: MainLoop = Engine.get_main_loop()
	var root: Node = (loop as SceneTree).root if loop is SceneTree else null
	var events: Node = root.get_node_or_null("/root/Events") if root != null else null
	if not bool(res.get("ok", false)):
		if events != null:
			events.call("warn", "That module could not be installed", String(res.get("reason", "")))
		return res
	var host: Node = root.get_node_or_null("/root/Host") if root != null else null
	if host != null:
		host.call("reload_modules")
	if events != null:
		events.call("toast", ("Updated " if bool(res.get("replaced", false)) else "Installed ") + String(res.get("label", res["id"])) + ". Check its card, then turn it on")
	var card_host: Node = root.find_child("EditorScreen", true, false) if root != null else null
	var card: GDScript = load("res://ui/editor/module_card.gd")
	card.call("open", card_host if card_host != null else (w if w != null else root), String(res["id"]))
	return res


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
	files = take_module_files(files, w)
	if files.is_empty():
		return true
	var b: Object = bin()
	if b == null:
		return false
	routed += 1
	b.call("on_files_dropped_in", files, w, pos)
	return true

extends RefCounted

const SELF_PATH := "res://modules/core_panels/text_popout.gd"
const TitleEditor := preload("res://modules/core_panels/title_editor.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const OWNER := "core_panels"
const CMD_ID := "view.text_popout"
const PREF_OPEN := "ui.text_popout_open"
const WINDOW_KEY := "text_popout"
const WINDOW_TITLE := "Text"
const WINDOW_SIZE := Vector2(420.0, 320.0)

static var _window: Control = null
static var _editor: Control = null


static func ensure_prefs(prefs: Node) -> void:
	if prefs == null:
		return
	if not bool(prefs.call("is_registered", PREF_OPEN)):
		prefs.call("register", PREF_OPEN, false, {"label": "Keep the text editor popped out", "type": "bool"})


static func register_all() -> void:
	ensure_prefs(Prefs)
	if Cmd == null:
		return
	var script: GDScript = load(SELF_PATH)
	var cat: Dictionary = Cmd.catalogue()
	var label: String = "Pop out the text editor"
	var category: String = "View"
	if cat.has(CMD_ID):
		label = String(cat[CMD_ID]["label"])
		category = String(cat[CMD_ID]["category"])
	Cmd.register(CMD_ID, {"label": label, "category": category, "scope": "global", "handler": Callable(script, "toggle"), "owner": OWNER, "toggle": Callable(script, "is_open")})


static func is_open() -> bool:
	return _window != null and is_instance_valid(_window) and _window.is_inside_tree()


static func editor() -> Control:
	if is_open():
		return _editor
	return null


static func wants_open() -> bool:
	return Prefs.is_registered(PREF_OPEN) and bool(Prefs.get_value(PREF_OPEN))


static func host_node() -> Node:
	var p: Object = Bus.instance().panel("source")
	if p != null and p.has_method("root"):
		var r: Variant = p.call("root")
		if r is Control and (r as Control).is_inside_tree():
			return r
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root
	return null


static func toggle() -> void:
	if is_open():
		close()
		return
	open(host_node())


static func restore(host: Node) -> void:
	if wants_open() and not is_open():
		open(host)


static func open(host: Node) -> Control:
	ensure_prefs(Prefs)
	if is_open():
		_window.call("raise")
		return _window
	if host == null or not host.is_inside_tree():
		return null
	_editor = TitleEditor.new()
	_editor.set("follow_selection", true)
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body: MarginContainer = PmUI.inset(_editor, 4.0, 6.0)
	_window = PmWindow.open(host, WINDOW_TITLE, body, WINDOW_SIZE, WINDOW_KEY)
	if _window == null:
		_editor = null
		return null
	_window.connect("closed", Callable(load(SELF_PATH), "_on_closed"))
	Prefs.set_value(PREF_OPEN, true)
	return _window


static func close() -> void:
	if not is_open():
		_clear()
		return
	_window.call("close")
	_clear()


static func _on_closed() -> void:
	ensure_prefs(Prefs)
	Prefs.set_value(PREF_OPEN, false)
	_clear()


static func _clear() -> void:
	_window = null
	_editor = null


static func bind_clip(sequence_id: String, clip_id: String) -> void:
	if _editor != null and is_instance_valid(_editor):
		_editor.call("set_target", sequence_id, clip_id)

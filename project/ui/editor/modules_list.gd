extends VBoxContainer

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmIcon := preload("res://ui/kit/pm_icon.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const SELF_PATH := "res://ui/editor/modules_list.gd"
const CORE_NOTE := "Core module, always on: the editor needs it"
const WINDOW_TITLE := "Modules"
const WINDOW_KEY := "modules"
const WINDOW_INTRO := "The Settings panel is not installed. Turn a module on here; it loads at once."
const MISSING_DETAIL := "It comes with a module that is off or missing"
const OPEN_LABEL := "Modules..."
const SETTINGS_PANEL := "settings"

static var _window: Control = null


func _init() -> void:
	name = "Rows"
	var host: Node = _host()
	if host != null and host.has_signal("modules_changed"):
		host.connect("modules_changed", _refresh)


func _refresh() -> void:
	PmUI.clear(self)
	build_rows(self)


static func _host() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/Host")
	return null


static func records() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var host: Node = _host()
	if host == null:
		return out
	for r: Dictionary in host.call("modules"):
		out.append(r)
	return out


static func is_locked(r: Dictionary) -> bool:
	return bool(r.get("core", false)) and String(r.get("state", "")) != "broken"


static func note_for(r: Dictionary) -> String:
	if is_locked(r):
		return CORE_NOTE
	var reason: String = String(r.get("reason", ""))
	return String(r.get("state", "")) + (": " + reason if not reason.is_empty() else "")


static func matches(search: String) -> bool:
	var s: String = search.strip_edges().to_lower()
	if s.is_empty() or "modules".contains(s) or s.contains("module"):
		return true
	for r: Dictionary in records():
		if String(r.get("label", "")).to_lower().contains(s) or String(r.get("id", "")).to_lower().contains(s):
			return true
	return false


static func toggle(on: bool, id: String) -> void:
	var host: Node = _host()
	if host != null:
		host.call("set_module_enabled", id, on)


static func build_rows(parent: Container) -> Array[CheckBox]:
	var boxes: Array[CheckBox] = []
	var script: GDScript = load(SELF_PATH)
	for r: Dictionary in records():
		var row: HBoxContainer = PmUI.hbox()
		row.name = "Module_" + String(r["id"])
		var cb: CheckBox = CheckBox.new()
		cb.name = "Switch"
		cb.text = String(r["label"]) + " " + String(r["version"])
		cb.focus_mode = Control.FOCUS_NONE
		var locked: bool = is_locked(r)
		cb.button_pressed = locked or String(r["state"]) == "on"
		cb.disabled = locked or String(r["state"]) == "broken"
		cb.set_meta("module_id", String(r["id"]))
		cb.set_meta("locked", locked)
		if locked:
			PmUI.tip(cb, CORE_NOTE)
		else:
			cb.toggled.connect(Callable(script, "toggle").bind(String(r["id"])))
		row.add_child(cb)
		if locked:
			row.add_child(PmIcon.make("lock", 14.0))
		var note: Label = PmLabel.dim(note_for(r))
		note.name = "Note"
		row.add_child(note)
		parent.add_child(row)
		boxes.append(cb)
	return boxes


static func make_rows() -> VBoxContainer:
	var rows: VBoxContainer = (load(SELF_PATH) as GDScript).new()
	build_rows(rows)
	return rows


static func missing_panel(id: String) -> Control:
	var v: Control = PmUI.empty_state("The panel \"" + id + "\" is not installed", MISSING_DETAIL)
	var b: Button = PmButton.make(OPEN_LABEL)
	b.name = "OpenModules"
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(Callable(load(SELF_PATH), "open_window").bind(v))
	v.add_child(b)
	return v


static func settings_missing() -> bool:
	var host: Node = _host()
	return host == null or host.call("get_impl", "IPanel", SETTINGS_PANEL) == null


static func open_preferences(host: Node, show_settings: Callable) -> String:
	if settings_missing():
		open_window(host)
		return "modules"
	show_settings.call()
	return "settings"


static func window_open() -> bool:
	return _window != null and is_instance_valid(_window) and _window.is_inside_tree()


static func open_window(host: Node) -> Control:
	if window_open():
		_window.call("raise")
		return _window
	var col: VBoxContainer = PmUI.vbox()
	col.name = "ModulesList"
	col.add_child(PmLabel.wrap(WINDOW_INTRO, "text_dim"))
	col.add_child(make_rows())
	var margin: MarginContainer = PmUI.inset(col, 6.0, 6.0)
	_window = PmWindow.open(host, WINDOW_TITLE, margin, Vector2(440.0, 240.0), WINDOW_KEY)
	return _window

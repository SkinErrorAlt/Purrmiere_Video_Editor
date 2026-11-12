extends VBoxContainer
## The card for one module: its icon, name, version, author and blurb, what its code can do (read from its source
## before it ever runs), and Turn on, Turn off and Remove. Shown after a module is dropped in, and from Modules.

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmIcon := preload("res://ui/kit/pm_icon.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const ModuleInstall := preload("res://host/module_install.gd")
const ICON_PX := 48.0

var module_id: String = ""
var _state: Label = null
var _on_btn: Button = null
var _off_btn: Button = null
var _remove_btn: Button = null
var _window: Control = null


static func _host() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("/root/Host") if loop is SceneTree else null


static func record(id: String) -> Dictionary:
	var h: Node = _host()
	if h == null:
		return {}
	for r: Dictionary in h.call("modules"):
		if String(r["id"]) == id:
			return r
	return {}


static func make(id: String) -> Control:
	var card: VBoxContainer = (load("res://ui/editor/module_card.gd") as GDScript).new()
	card.set("module_id", id)
	card.name = "ModuleCard"
	card.call("_build")
	return card


static func open(host_node: Node, id: String) -> Control:
	var card: Control = make(id)
	var r: Dictionary = record(id)
	var w: Control = PmWindow.open(host_node, "Module: " + String(r.get("label", id)), PmUI.inset(card, 10.0, 10.0), Vector2(460.0, 420.0), "module_card")
	card.set("_window", w)
	return w


func _build() -> void:
	add_theme_constant_override("separation", Tk.px(8.0))
	var r: Dictionary = record(module_id)
	var dir: String = String(r.get("path", ""))
	var m: Dictionary = ModuleInstall.read_manifest_at(dir) if not dir.is_empty() else {}
	var head: HBoxContainer = PmUI.hbox(Tk.px(10.0))
	head.add_child(_icon(dir, String(m.get("icon", ""))))
	var names: VBoxContainer = PmUI.vbox(Tk.px(2.0))
	var title: Label = PmLabel.headline(String(r.get("label", module_id)))
	title.name = "Title"
	names.add_child(title)
	var by: String = "Version " + String(r.get("version", "?"))
	if not String(m.get("author", "")).is_empty():
		by += " by " + String(m["author"])
	names.add_child(PmLabel.dim(by))
	_state = PmLabel.dim("")
	_state.name = "State"
	names.add_child(_state)
	head.add_child(names)
	add_child(head)
	var blurb: String = String(m.get("blurb", ""))
	if not blurb.is_empty():
		add_child(PmLabel.wrap(blurb, "text"))
	add_child(PmLabel.trim("What it can do", "text_bright"))
	var list: VBoxContainer = PmUI.vbox(Tk.px(3.0))
	list.name = "Reach"
	var reach: Array[Dictionary] = ModuleInstall.reach_of(dir) if not dir.is_empty() else []
	if reach.is_empty():
		list.add_child(PmLabel.dim("Nothing beyond what it shows you: it has no code that reaches into Purrmiere."))
	for e: Dictionary in reach:
		var l: Label = PmLabel.wrap(("⚠ " if bool(e["risky"]) else "• ") + String(e["what"]), "key_negative" if bool(e["risky"]) else "text")
		list.add_child(l)
	add_child(list)
	if not String(m.get("homepage", "")).is_empty():
		add_child(PmLabel.dim("From " + String(m["homepage"])))
	add_child(PmLabel.dim("Read from its files before it runs. A module only does what its code says, so turn on modules you trust."))
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	_on_btn = PmButton.make("Turn on")
	_on_btn.name = "TurnOn"
	_on_btn.pressed.connect(_set_on.bind(true))
	row.add_child(_on_btn)
	_off_btn = PmButton.make("Turn off")
	_off_btn.name = "TurnOff"
	_off_btn.pressed.connect(_set_on.bind(false))
	row.add_child(_off_btn)
	_remove_btn = PmButton.make("Remove")
	_remove_btn.name = "Remove"
	_remove_btn.pressed.connect(_remove)
	PmUI.tip(_remove_btn, "Turns it off and moves its folder to Modules\\Removed, so it can be put back by hand")
	row.add_child(_remove_btn)
	add_child(row)
	var h: Node = _host()
	if h != null and not h.is_connected("modules_changed", refresh):
		h.connect("modules_changed", refresh)
	refresh()


func _icon(dir: String, rel: String) -> Control:
	if not rel.is_empty() and FileAccess.file_exists(dir + rel):
		var img: Image = Image.load_from_file(dir + rel)
		if img != null and not img.is_empty():
			var tr: TextureRect = TextureRect.new()
			tr.texture = ImageTexture.create_from_image(img)
			tr.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			return tr
	return PmIcon.make("wrench", ICON_PX * 0.75)


func refresh() -> void:
	if not is_instance_valid(self):
		return
	var r: Dictionary = record(module_id)
	var state: String = String(r.get("state", "missing"))
	var core: bool = bool(r.get("core", false))
	var words: Dictionary = {"on": "On", "off": "Off", "ready": "Off", "broken": "Cannot load", "missing": "Not installed"}
	_state.text = String(words.get(state, state.capitalize())) + ("" if String(r.get("reason", "")).is_empty() else ": " + String(r["reason"]))
	_on_btn.visible = state != "on" and state != "broken" and state != "missing"
	_off_btn.visible = state == "on" and not core
	_remove_btn.visible = not bool(r.get("official", true)) and state != "missing"


func _set_on(v: bool) -> void:
	var h: Node = _host()
	if h != null:
		h.call("set_module_enabled", module_id, v)
	refresh()


func _remove() -> void:
	var h: Node = _host()
	var r: Dictionary = record(module_id)
	if h == null or r.is_empty() or bool(r.get("official", true)):
		return
	h.call("set_module_enabled", module_id, false)
	var root: String = String(r["path"]).trim_suffix("/").get_base_dir()
	ModuleInstall.remove(module_id, root)
	h.call("reload_modules")
	if _window != null and is_instance_valid(_window) and _window.has_method("close"):
		_window.call("close")

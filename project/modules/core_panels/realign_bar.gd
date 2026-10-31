extends PanelContainer

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const Realign := preload("res://doc/realign.gd")
const SELF_PATH := "res://modules/core_panels/realign_bar.gd"
const MENU_LOOP := "realign_loop"
const MENU_SCOPE := "realign_scope:"

var loop_box: CheckBox = null
var scope_drop: Button = null
var hint: Label = null
var _syncing: bool = false


static func make() -> Control:
	var script: GDScript = load(SELF_PATH)
	var bar: PanelContainer = script.new()
	bar.call("build")
	return bar


static func scope_choices() -> Array:
	var out: Array = []
	for k: String in Realign.SCOPES:
		out.append(PmDrop.choice(k, String(Realign.SCOPE_LABELS[k])))
	return out


static func menu_items() -> Array:
	var sc: String = Realign.scope()
	var items: Array = [PmMenu.check_item(MENU_LOOP, Realign.LOOP_LABEL, Realign.loop_on()), PmMenu.separator()]
	for k: String in ["views", "cuts"]:
		items.append(PmMenu.check_item(MENU_SCOPE + k, String(Realign.SCOPE_LABELS[k]), sc == k))
	return items


static func picked(id: String) -> void:
	if id == MENU_LOOP:
		Realign.set_pref(Realign.PREF_LOOP, not Realign.loop_on())
	elif id.begins_with(MENU_SCOPE):
		var k: String = id.substr(MENU_SCOPE.length())
		if Realign.SCOPES.has(k):
			Realign.set_pref(Realign.PREF_SCOPE, k)


static func open_menu(anchor: Control) -> Control:
	if anchor == null or not anchor.is_inside_tree():
		return null
	var m: Control = PmMenu.open(anchor, menu_items())
	if m != null and m.is_inside_tree():
		m.connect("picked", Callable(load(SELF_PATH), "picked"))
	return m


static func attach(button: Control) -> void:
	if button == null:
		return
	var handler: Callable = Callable(load(SELF_PATH), "_on_input").bind(button)
	if not button.gui_input.is_connected(handler):
		button.gui_input.connect(handler)
	PmUI.tip(button, "Realign: drag to move the source under a section. Right click for options", Cmd.keys_text("tool.realign"))


static func _on_input(event: InputEvent, button: Control) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			open_menu(button)
			button.accept_event()


func build() -> void:
	name = "RealignBar"
	Realign.register_prefs()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tk.c["bg_panel_alt"]
	sb.border_color = Tk.c["border"]
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	var pad: float = float(Tk.px(Tk.sz("pad")))
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = float(Tk.px(3.0))
	sb.content_margin_bottom = float(Tk.px(3.0))
	add_theme_stylebox_override("panel", sb)
	var row: HBoxContainer = PmUI.hbox(Tk.px(Tk.sz("pad")))
	add_child(row)
	var title: Label = PmLabel.meta("Realign")
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	loop_box = CheckBox.new()
	loop_box.text = "Loop round the ends"
	loop_box.focus_mode = Control.FOCUS_NONE
	loop_box.toggled.connect(_on_loop)
	PmUI.tip(loop_box, "Sliding past the start of the source carries on from its end, and past the end from its start, for loops and music beds. Where the wrap falls inside the section it becomes two pieces")
	row.add_child(loop_box)
	var lab: Label = PmLabel.dim("Sections")
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lab)
	scope_drop = PmDrop.make_drop(scope_choices(), Realign.scope())
	scope_drop.connect("changed", _on_scope)
	PmUI.tip(lab, "Pair View slices: with Cut on view changes on, a drag moves only the view span under the pointer (it is cut there for real). Real cuts only: a drag moves the whole clip")
	PmUI.tip(scope_drop, "Pair View slices: with Cut on view changes on, a drag moves only the view span under the pointer (it is cut there for real). Real cuts only: a drag moves the whole clip")
	row.add_child(scope_drop)
	hint = PmLabel.trim(Realign.HINT, "text_faint")
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.tooltip_text = Realign.HINT
	row.add_child(hint)
	visible = Session.tool_id == Realign.TOOL_ID
	_connect()
	sync()


func _connect() -> void:
	if not Session.tool_changed.is_connected(_on_tool):
		Session.tool_changed.connect(_on_tool)
	if not Prefs.changed.is_connected(_on_pref):
		Prefs.changed.connect(_on_pref)


func _enter_tree() -> void:
	if loop_box != null:
		_connect()


func _exit_tree() -> void:
	if Session.tool_changed.is_connected(_on_tool):
		Session.tool_changed.disconnect(_on_tool)
	if Prefs.changed.is_connected(_on_pref):
		Prefs.changed.disconnect(_on_pref)


func sync() -> void:
	if loop_box == null:
		return
	_syncing = true
	loop_box.set_pressed_no_signal(Realign.loop_on())
	scope_drop.call("set_value", Realign.scope(), false)
	_syncing = false


func _on_tool(tool_id: String) -> void:
	var on: bool = tool_id == Realign.TOOL_ID
	if on:
		sync()
	if on != visible:
		PmUI.set_shown(self, on)


func _on_pref(key: String) -> void:
	if key.begins_with("realign.") and not _syncing:
		sync()


func _on_loop(on: bool) -> void:
	if not _syncing:
		Realign.set_pref(Realign.PREF_LOOP, on)


func _on_scope(id: String) -> void:
	if not _syncing and Realign.SCOPES.has(id):
		Realign.set_pref(Realign.PREF_SCOPE, id)

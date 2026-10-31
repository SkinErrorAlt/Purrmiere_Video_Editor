extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const SheetList := preload("res://modules/core_panels/sheet_list.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const Keybind := preload("res://modules/core_panels/keybind_edit.gd")
const SELF_PATH := "res://modules/core_panels/shortcuts_sheet.gd"

var sheet: Control = null
var field: LineEdit = null
var list: Control = null
var status: Label = null
var keymap_drop: Button = null
var clear_button: Button = null
var cancel_button: Button = null
var assign_button: Button = null
var catcher: Control = null
var capturing: String = ""
var pending_key: String = ""
var pending_clashes: Array[Dictionary] = []
var _row_ids: PackedStringArray = PackedStringArray()


static func open(host: Node) -> Node:
	var script: GDScript = load(SELF_PATH)
	var s: Node = script.new()
	s.call("build", host)
	return s


static func scope_word(scope: String) -> String:
	return Keybind.scope_word(scope)


static func category_of(id: String) -> String:
	return Keybind.category_of(id)


static func entries(query: String) -> Array[Dictionary]:
	return Keybind.entries(query)


func build(host: Node) -> void:
	name = "ShortcutsSheet"
	sheet = Sheet.open(host, "Keyboard shortcuts", 760.0, 620.0)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	var bar: HBoxContainer = PmUI.hbox()
	field = PmUI.line_edit("Search commands or keys")
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.gui_input.connect(_on_field_input)
	field.text_changed.connect(_on_text)
	bar.add_child(field)
	var maps: Array = []
	for n: String in Cmd.keymap_names():
		maps.append(PmDrop.choice(n, n.capitalize()))
	keymap_drop = PmDrop.make_drop(maps, Cmd.keymap_name())
	keymap_drop.connect("changed", _on_keymap)
	PmUI.tip(keymap_drop, "The keymap your changes sit on top of")
	bar.add_child(keymap_drop)
	var reset: Button = PmButton.make("Reset to Premiere defaults")
	reset.pressed.connect(_on_reset)
	bar.add_child(reset)
	col.add_child(bar)
	list = SheetList.make(28.0, false, 0.0)
	list.set("click_activates", false)
	list.set("right_px", 170.0)
	list.set("tag_px", 120.0)
	list.connect("activated", _on_activated)
	list.connect("pressed_row", _on_pressed_row)
	col.add_child(list)
	catcher = Control.new()
	catcher.name = "KeyCatcher"
	catcher.focus_mode = Control.FOCUS_ALL
	catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catcher.custom_minimum_size = Vector2(0.0, 0.0)
	catcher.gui_input.connect(_on_capture_input)
	col.add_child(catcher)
	col.add_child(PmUI.divider())
	var foot: HBoxContainer = PmUI.hbox()
	status = PmLabel.trim(Keybind.IDLE_TEXT, "text_dim")
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(status)
	clear_button = PmButton.make("Remove the key")
	clear_button.pressed.connect(_on_clear_key)
	foot.add_child(clear_button)
	cancel_button = PmButton.make("Cancel")
	cancel_button.pressed.connect(cancel_capture)
	foot.add_child(cancel_button)
	assign_button = PmButton.primary("Assign")
	assign_button.pressed.connect(assign_pending)
	foot.add_child(assign_button)
	var close_b: Button = PmButton.make("Close")
	close_b.pressed.connect(_on_close)
	foot.add_child(close_b)
	col.add_child(foot)
	_show_state()
	refresh()
	field.grab_focus.call_deferred()


func refresh() -> void:
	var list_entries: Array[Dictionary] = entries(field.text)
	var rows: Array[Dictionary] = []
	_row_ids = PackedStringArray()
	var last_cat: String = ""
	for e: Dictionary in list_entries:
		if String(e["category"]) != last_cat:
			last_cat = String(e["category"])
			rows.append({"head": true, "title": last_cat})
			_row_ids.append("")
		var id: String = String(e["id"])
		var keys: Array[String] = e["keys"]
		var text: String = ", ".join(PackedStringArray(keys)) if not keys.is_empty() else Keybind.NO_KEY
		var row: Dictionary = {"title": String(e["label"]), "tag": scope_word(String(e["scope"])), "right": text, "chip": true, "strong": bool(e["user"]), "dim": not Cmd.has(id)}
		if id == capturing:
			row["right"] = pending_key if not pending_key.is_empty() else "Press a key"
			row["ink"] = true
		rows.append(row)
		_row_ids.append(id)
	list.call("set_rows", rows, true)


func id_at(index: int) -> String:
	if index < 0 or index >= _row_ids.size():
		return ""
	return _row_ids[index]


func index_of(id: String) -> int:
	return _row_ids.find(id)


func start_capture(id: String) -> void:
	if id.is_empty():
		return
	capturing = id
	pending_key = ""
	pending_clashes = []
	var i: int = index_of(id)
	if i >= 0:
		list.call("set_cursor", i)
	refresh()
	_show_state()
	catcher.grab_focus()


func cancel_capture() -> void:
	capturing = ""
	pending_key = ""
	pending_clashes = []
	refresh()
	_show_state()
	if field.is_inside_tree():
		field.grab_focus()


func propose(key: String) -> bool:
	if capturing.is_empty() or key.is_empty():
		return false
	pending_key = key
	pending_clashes = Keybind.clashes_for(capturing, key)
	if pending_clashes.is_empty():
		assign_pending()
		return true
	refresh()
	_show_state()
	return false


func assign_pending() -> void:
	if capturing.is_empty() or pending_key.is_empty():
		return
	Keybind.assign(capturing, pending_key, pending_clashes)
	cancel_capture()


func _on_clear_key() -> void:
	if capturing.is_empty():
		return
	Keybind.clear_keys(capturing)
	cancel_capture()


func _show_state() -> void:
	var capture_on: bool = not capturing.is_empty()
	var clash_on: bool = capture_on and not pending_clashes.is_empty()
	clear_button.visible = capture_on and not clash_on
	cancel_button.visible = capture_on
	assign_button.visible = clash_on
	status.text = Keybind.status_text(capturing, pending_key, pending_clashes)
	if clash_on:
		PmLabel.set_colour(status, "text_bright")
	elif capture_on:
		PmLabel.set_colour(status, "text")
	else:
		PmLabel.set_colour(status, "text_dim")


func key_event_text(k: InputEventKey) -> String:
	return Keybind.key_event_text(k)


func feed_key(k: InputEventKey) -> bool:
	if capturing.is_empty() or not k.pressed or k.echo:
		return false
	if Keybind.is_cancel(k):
		cancel_capture()
		return true
	var text: String = key_event_text(k)
	if text.is_empty():
		return true
	propose(text)
	return true


func _on_capture_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	catcher.accept_event()
	feed_key(event as InputEventKey)


func _on_field_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed:
		return
	if k.keycode == KEY_ESCAPE:
		field.accept_event()
		_on_close()
		return
	if bool(list.call("handle_nav_key", k)):
		field.accept_event()


func _on_activated(index: int) -> void:
	start_capture(id_at(index))


func _on_pressed_row(index: int, on_right: bool) -> void:
	if on_right:
		start_capture(id_at(index))


func _on_text(_t: String) -> void:
	refresh()


func _on_keymap(id: String) -> void:
	Cmd.set_keymap(id)
	refresh()


func _on_reset() -> void:
	var answered: Signal = PmUI.confirm(sheet, Keybind.RESET_TITLE, Keybind.RESET_TEXT, Keybind.RESET_OK, "Cancel")
	answered.connect(_on_reset_answered)


func _on_reset_answered(ok: Variant) -> void:
	if not bool(ok):
		return
	reset_all()


func reset_all() -> void:
	Keybind.reset_all()
	keymap_drop.call("set_value", Cmd.keymap_name(), false)
	cancel_capture()


func _on_close() -> void:
	sheet.call("close")

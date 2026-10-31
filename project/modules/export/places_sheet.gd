extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const Places := preload("res://modules/export/export_places.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const SHEET_W := 520.0
const NOTE := "Places are the folders you export to, one per channel or person you edit for. Each keeps where to write, what to call the file and, if you want, its own format. They live with your settings, so they are the same in every project."

var sheet: Control = null
var list_box: VBoxContainer = null
var editing: Dictionary = {}
var name_field: LineEdit = null
var dir_field: LineEdit = null
var pattern_field: LineEdit = null
var colour_button: Button = null
var border_button: Button = null
var on_done: Callable = Callable()
var _dialog: FileDialog = null


static func open(host: Node, _settings: Dictionary, done: Callable) -> Node:
	var n: Node = load("res://modules/export/places_sheet.gd").new()
	n.set("on_done", done)
	n.call("_build", host)
	return n


func _build(host: Node) -> void:
	sheet = Sheet.open(host, "Export places", SHEET_W)
	if sheet == null:
		return
	sheet.add_child(self)
	sheet.call("add_note", NOTE)
	var col: VBoxContainer = sheet.get("col")
	list_box = PmUI.vbox(0)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(list_box)
	var form: VBoxContainer = PmUI.vbox(0)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(form)
	name_field = _field_row(form, "Name", "what you call it")
	dir_field = _field_row(form, "Folder", "where the file goes")
	var browse: Button = PmButton.make("Choose a folder")
	browse.pressed.connect(_on_browse)
	form.add_child(browse)
	colour_button = _pick_row(form, "Colour", _on_colour)
	border_button = _pick_row(form, "Border", _on_border)
	pattern_field = _field_row(form, "Name files like", "the project")
	sheet.call("add_note", "Leave the naming blank to use the project's name. You can also write a pattern with {project}, {sequence}, {date}, {height} and {fps}.")
	var row: HBoxContainer = sheet.call("add_buttons")
	var add_b: Button = sheet.call("add_button", "Save this place", true)
	add_b.pressed.connect(_on_save)
	var clear_b: Button = sheet.call("add_button", "Clear")
	clear_b.pressed.connect(_on_clear)
	sheet.call("add_spacer")
	var close_b: Button = sheet.call("add_button", "Done")
	close_b.pressed.connect(_on_close)
	if row == null:
		pass
	_on_clear()
	_rebuild_list()


func _field_row(parent: Control, label: String, hint: String) -> LineEdit:
	var row: HBoxContainer = PmUI.hbox()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l: Label = PmLabel.dim(label)
	l.custom_minimum_size.x = 120.0
	row.add_child(l)
	var f: LineEdit = PmUI.line_edit(hint)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(f)
	parent.add_child(row)
	return f


func _pick_row(parent: Control, label: String, on_pick: Callable) -> Button:
	var row: HBoxContainer = PmUI.hbox()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l: Label = PmLabel.dim(label)
	l.custom_minimum_size.x = 120.0
	row.add_child(l)
	var b: Button = PmButton.make("")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(on_pick.bind(b))
	row.add_child(b)
	parent.add_child(row)
	return b


func _rebuild_list() -> void:
	if list_box == null:
		return
	PmUI.clear(list_box)
	var places: Array[Dictionary] = Places.list()
	if places.is_empty():
		list_box.add_child(PmLabel.dim("No places yet. Fill the boxes below and save one."))
		return
	for pl: Dictionary in places:
		var row: HBoxContainer = PmUI.hbox()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(12.0, 12.0)
		swatch.color = Color.html(Places.colour_hex(String(pl["colour"])))
		row.add_child(swatch)
		var nm: Label = PmLabel.trim(String(pl["name"]), "text")
		nm.custom_minimum_size.x = 140.0
		row.add_child(nm)
		var path: Label = PmLabel.trim(String(pl["dir"]), "text_dim")
		path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(path)
		var edit_b: Button = PmButton.make("Edit")
		edit_b.pressed.connect(_on_edit.bind(pl))
		row.add_child(edit_b)
		var del_b: Button = PmButton.make("Remove")
		del_b.pressed.connect(_on_remove.bind(String(pl["id"])))
		row.add_child(del_b)
		list_box.add_child(row)


func _on_edit(pl: Dictionary) -> void:
	editing = pl.duplicate(true)
	name_field.text = String(pl["name"])
	dir_field.text = String(pl["dir"])
	pattern_field.text = String(pl["pattern"])
	_sync_pickers()


func _on_clear() -> void:
	editing = Places.make("", "", "grey", "solid")
	if name_field != null:
		name_field.text = ""
		dir_field.text = ""
		pattern_field.text = ""
	_sync_pickers()


func _sync_pickers() -> void:
	if colour_button != null:
		colour_button.text = Places.colour_label(String(editing.get("colour", "grey")))
	if border_button != null:
		border_button.text = String(editing.get("border", "solid")).capitalize()


func _on_colour(anchor: Button) -> void:
	var items: Array = []
	for c: Array in Places.COLOURS:
		items.append(PmMenu.item(String(c[0]), String(c[1])))
	var menu: Control = PmMenu.open(anchor, items)
	menu.connect("picked", _picked_colour)


func _picked_colour(id: String) -> void:
	editing["colour"] = id
	_sync_pickers()


func _on_border(anchor: Button) -> void:
	var items: Array = []
	for b: String in Places.BORDERS:
		items.append(PmMenu.item(b, b.capitalize()))
	var menu: Control = PmMenu.open(anchor, items)
	menu.connect("picked", _picked_border)


func _picked_border(id: String) -> void:
	editing["border"] = id
	_sync_pickers()


func _on_browse() -> void:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_dialog.use_native_dialog = true
		_dialog.title = "Choose where this place writes to"
		_dialog.dir_selected.connect(_on_dir_picked)
		add_child(_dialog)
	_dialog.popup_centered(Vector2i(900, 600))


func _on_dir_picked(dir: String) -> void:
	dir_field.text = dir


func _on_save() -> void:
	var made: Dictionary = Places.make(name_field.text, dir_field.text, String(editing.get("colour", "grey")), String(editing.get("border", "solid")), pattern_field.text, editing.get("settings", {}))
	made["id"] = String(editing.get("id", ""))
	if not Places.valid(made):
		Events.warn("That place needs a name and a folder", "Both boxes have to be filled in before it can be saved")
		return
	if not Places.save(made):
		Events.error("The place could not be saved", made["dir"])
		return
	Events.toast("Saved the place " + String(made["name"]))
	_on_clear()
	_rebuild_list()


func _on_remove(id: String) -> void:
	if Places.remove(id):
		_rebuild_list()


func _on_close() -> void:
	if on_done.is_valid():
		on_done.call()
	if sheet != null and sheet.has_method("close"):
		sheet.call("close")

extends AcceptDialog

const Proxies := preload("res://engine/proxies.gd")
const NODE_NAME := "ProxyDrivesDialog"
const CHOICE_CACHE := 0
const CHOICE_DRIVE := 1
const DEFAULT_FOLDER := "Purrmiere Proxies"

var rows: Dictionary = {}
var _list: VBoxContainer = null
var _browse: FileDialog = null
var _browse_for: String = ""


static func open() -> void:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var root: Window = (loop as SceneTree).root
	var old: Node = root.get_node_or_null(NODE_NAME)
	if old != null:
		old.queue_free()
	var script: GDScript = load("res://modules/core_panels/proxy_drives_dialog.gd")
	var d: AcceptDialog = script.new()
	d.name = NODE_NAME
	root.add_child(d)
	d.popup_centered(Vector2i(560, 320))


static func drives_in_use() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var loop: MainLoop = Engine.get_main_loop()
	var session: Node = (loop as SceneTree).root.get_node_or_null("Session") if loop is SceneTree else null
	var doc: Object = session.get("doc") if session != null else null
	if doc != null:
		for m: Variant in doc.get("media"):
			var p: String = String((m as Object).get("path"))
			if p.is_empty() or String((m as Object).get("kind")) != "video":
				continue
			var d: String = Proxies.drive_of(p)
			if not out.has(d):
				out.append(d)
	if OS.get_name() == "Windows":
		for i: int in DirAccess.get_drive_count():
			var name_: String = DirAccess.get_drive_name(i).to_upper()
			if name_.length() >= 2 and not out.has(name_.substr(0, 2)):
				out.append(name_.substr(0, 2))
	for k: Variant in Proxies.drive_folders().keys():
		if not out.has(String(k)):
			out.append(String(k))
	out.sort()
	return out


func _init() -> void:
	title = "Proxy folder for each drive"
	ok_button_text = "Save"
	exclusive = false
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	var note: Label = Label.new()
	note.text = "Pick where the proxies of footage on each drive are kept. This computer's cache folder is the default; a folder on the footage's own drive keeps them with the footage."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 520.0
	body.add_child(note)
	_list = VBoxContainer.new()
	body.add_child(_list)
	add_child(body)
	_browse = FileDialog.new()
	_browse.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_browse.access = FileDialog.ACCESS_FILESYSTEM
	_browse.dir_selected.connect(_on_dir)
	add_child(_browse)
	confirmed.connect(save)
	build()


func build() -> void:
	for ch: Node in _list.get_children():
		ch.queue_free()
	rows = {}
	var map: Dictionary = Proxies.drive_folders()
	for d: String in drives_in_use():
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lab: Label = Label.new()
		lab.text = d
		lab.custom_minimum_size.x = 48.0
		row.add_child(lab)
		var pick: OptionButton = OptionButton.new()
		pick.add_item("This computer's cache folder", CHOICE_CACHE)
		pick.add_item("A folder on this drive", CHOICE_DRIVE)
		var folder: LineEdit = LineEdit.new()
		folder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var own: String = String(map.get(d, ""))
		folder.text = own if not own.is_empty() else default_folder(d)
		pick.select(CHOICE_DRIVE if not own.is_empty() else CHOICE_CACHE)
		folder.editable = not own.is_empty()
		pick.item_selected.connect(func(i: int) -> void: folder.editable = i == CHOICE_DRIVE)
		var browse: Button = Button.new()
		browse.text = "Browse"
		browse.pressed.connect(_on_browse.bind(d))
		row.add_child(pick)
		row.add_child(folder)
		row.add_child(browse)
		_list.add_child(row)
		rows[d] = {"pick": pick, "folder": folder}


static func default_folder(drive: String) -> String:
	if drive.length() == 2 and drive[1] == ":":
		return drive + "/" + DEFAULT_FOLDER
	return drive.path_join(DEFAULT_FOLDER)


func _on_browse(drive: String) -> void:
	_browse_for = drive
	_browse.current_dir = drive + "/" if drive.length() == 2 else drive
	_browse.popup_centered(Vector2i(640, 420))


func _on_dir(dir: String) -> void:
	if not rows.has(_browse_for):
		return
	var r: Dictionary = rows[_browse_for]
	(r["pick"] as OptionButton).select(CHOICE_DRIVE)
	(r["folder"] as LineEdit).editable = true
	(r["folder"] as LineEdit).text = dir


func values() -> Dictionary:
	var out: Dictionary = {}
	for d: Variant in rows.keys():
		var r: Dictionary = rows[d]
		if (r["pick"] as OptionButton).get_selected_id() == CHOICE_DRIVE:
			var f: String = (r["folder"] as LineEdit).text.strip_edges()
			if not f.is_empty():
				out[String(d)] = f
	return out


func save() -> void:
	Proxies.set_drive_folders(values())

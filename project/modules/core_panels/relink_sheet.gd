extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const SheetList := preload("res://modules/core_panels/sheet_list.gd")
const Relink := preload("res://modules/core_panels/relink.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const Project := preload("res://doc/project.gd")
const SELF_PATH := "res://modules/core_panels/relink_sheet.gd"

var sheet: Control = null
var list: Control = null
var intro: Label = null
var status: Label = null
var search_button: Button = null
var relink_button: Button = null
var missing: Array[Dictionary] = []
var plan: Array[Dictionary] = []
var folder: String = ""
var _dialog: FileDialog = null
var _task: int = -1
var _scan_folder: String = ""
var _scan_result: PackedStringArray = PackedStringArray()
var _mutex: Mutex = Mutex.new()


static func open(host: Node) -> Node:
	var script: GDScript = load(SELF_PATH)
	var r: Node = script.new()
	r.call("build", host)
	return r


func build(host: Node) -> void:
	name = "RelinkSheet"
	sheet = Sheet.open(host, "Relink missing media", 720.0, 520.0)
	sheet.add_child(self)
	sheet.connect("closed", _on_closed)
	var col: VBoxContainer = sheet.get("col")
	intro = sheet.call("add_note", "")
	var bar: HBoxContainer = PmUI.hbox()
	search_button = PmButton.make("Search a folder", "folder")
	search_button.pressed.connect(_on_search_pressed)
	bar.add_child(search_button)
	status = PmLabel.trim("", "text_dim")
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(status)
	col.add_child(bar)
	list = SheetList.make(38.0, true, 0.0)
	list.set("click_activates", false)
	list.set("auto_cursor", false)
	list.set("right_px", 230.0)
	list.set("empty_text", "Nothing is missing")
	col.add_child(list)
	var cancel: Button = sheet.call("add_button", "Cancel")
	cancel.pressed.connect(_on_cancel)
	relink_button = sheet.call("add_button", "Relink", true)
	relink_button.pressed.connect(_on_relink)
	reload()


func reload() -> void:
	missing = Relink.missing_items(Session.doc)
	plan = Relink.plan(missing, PackedStringArray(), "")
	for r: Dictionary in plan:
		r["how"] = ""
	var n: int = missing.size()
	if n == 0:
		intro.text = "Every file in this project is where it should be."
	else:
		intro.text = str(n) + (" file is" if n == 1 else " files are") + " missing. Choose a folder to search; nothing changes until you press Relink."
	status.text = ""
	search_button.disabled = n == 0
	_show_plan()


func _show_plan() -> void:
	var rows: Array[Dictionary] = []
	for r: Dictionary in plan:
		var new_path: String = String(r.get("new", ""))
		var how: String = String(r.get("how", ""))
		var detail: String = String(r["old"])
		if not new_path.is_empty():
			detail = String(r["old"]) + "  to  " + new_path
		elif not String(r.get("note", "")).is_empty():
			detail = String(r["old"]) + ", " + String(r["note"])
		rows.append({"title": String(r["label"]), "detail": detail, "right": Relink.how_text(how), "strong": not new_path.is_empty(), "rule": true})
	list.call("set_rows", rows, true)
	var found: int = Relink.found_count(plan)
	relink_button.text = "Relink " + str(found) + (" file" if found == 1 else " files") if found > 0 else "Relink"
	relink_button.disabled = found == 0


func search_folder(path: String) -> void:
	folder = path
	var files: PackedStringArray = Relink.scan(path)
	_apply_scan(path, files)


func search_folder_async(path: String) -> void:
	if _task >= 0:
		return
	folder = path
	_scan_folder = path
	status.text = "Searching " + path + " ..."
	search_button.disabled = true
	_task = WorkerThreadPool.add_task(_scan_worker)
	set_process(true)


func _scan_worker() -> void:
	var files: PackedStringArray = Relink.scan(_scan_folder)
	_mutex.lock()
	_scan_result = files
	_mutex.unlock()


func _process(_dt: float) -> void:
	if _task < 0:
		set_process(false)
		return
	if not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	set_process(false)
	_mutex.lock()
	var files: PackedStringArray = _scan_result
	_scan_result = PackedStringArray()
	_mutex.unlock()
	search_button.disabled = missing.is_empty()
	_apply_scan(_scan_folder, files)


func _apply_scan(path: String, files: PackedStringArray) -> void:
	var fresh: Array[Dictionary] = Relink.plan(missing, files, path)
	plan = Relink.merge(plan, fresh)
	var cap_note: String = ", stopped at the limit" if files.size() >= Relink.FILE_CAP else ""
	status.text = "Searched " + path + ", " + _thousands(files.size()) + (" file" if files.size() == 1 else " files") + cap_note
	_show_plan()


static func _thousands(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	var count: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


func relink_now() -> int:
	var doc: Project = Session.doc
	var n: int = Relink.apply(doc, plan)
	if n > 0:
		Events.toast("Relinked " + str(n) + (" file" if n == 1 else " files"))
	return n


func _on_search_pressed() -> void:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_dialog.use_native_dialog = true
		_dialog.title = "Choose a folder to search"
		_dialog.dir_selected.connect(search_folder_async)
		add_child(_dialog)
	_dialog.popup_centered(Vector2i(900, 600))


func _on_relink() -> void:
	relink_now()
	sheet.call("close")


func _on_cancel() -> void:
	sheet.call("close")


func _on_closed() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

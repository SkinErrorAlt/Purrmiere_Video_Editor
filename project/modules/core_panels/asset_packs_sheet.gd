extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const SheetList := preload("res://modules/core_panels/sheet_list.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AssetPacks := preload("res://doc/asset_packs.gd")
const AssetPackWatch := preload("res://doc/asset_pack_watch.gd")
const Presets := preload("res://doc/presets.gd")
const SELF_PATH := "res://modules/core_panels/asset_packs_sheet.gd"
const MODE_PACKS := "packs"
const MODE_ITEMS := "items"
const MODE_SAVE := "save"
const LIBRARY_NOTE := "A package is a set of files you use again and again. It remembers where the files are, not copies of them, so it works in every project."

var sheet: Control = null
var list: Control = null
var note: Label = null
var status: Label = null
var bin_row: Control = null
var pick_row: Control = null
var bin_box: LineEdit = null
var name_box: LineEdit = null
var auto_button: Button = null
var follow_button: Button = null
var watch_button: Button = null
var watch_box: Control = null
var deep_button: Button = null
var tree_button: Button = null
var folder_label: Label = null
var folder_button: Button = null
var main_button: Button = null
var back_button: Button = null
var delete_button: Button = null
var rename_button: Button = null
var refresh_button: Button = null
var update_button: Button = null
var mode: String = MODE_PACKS
var packs: Array[Dictionary] = []
var open_pack: Dictionary = {}
var open_view: Dictionary = {}
var row_keys: PackedStringArray = PackedStringArray()
var picked: Dictionary = {}
var media_ids: PackedStringArray = PackedStringArray()
var watch_folder: String = ""
var _dialog: FileDialog = null


static func open(host: Node) -> Node:
	var script: GDScript = load(SELF_PATH)
	var s: Node = script.new()
	s.call("build_library", host)
	return s


static func open_save(host: Node, ids: PackedStringArray) -> Node:
	var script: GDScript = load(SELF_PATH)
	var s: Node = script.new()
	s.call("build_save", host, ids)
	return s


static func save_pack(doc: Project, ids: PackedStringArray, label: String, bin: String, import_at_once: bool, opts: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"ok": false, "pack": {}, "why": ""}
	var clean_label: String = label.strip_edges()
	if doc == null:
		out["why"] = "there is no project open"
		return out
	if clean_label.is_empty():
		out["why"] = "give the package a name first"
		return out
	var pack: Dictionary = Presets.asset_pack_from(doc, ids, clean_label, bin, import_at_once, opts)
	if AssetPacks.items_of(pack).is_empty() and AssetPacks.folders_of(pack).is_empty():
		out["why"] = "mark some bin items that came from files first, or watch a folder"
		return out
	if not Presets.save_asset_pack(pack):
		out["why"] = "the package could not be written to the preset folder"
		return out
	out["pack"] = pack
	out["ok"] = true
	return out


static func rename_pack(pack: Dictionary, label: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "pack": pack, "why": ""}
	if not AssetPacks.is_pack(pack):
		out["why"] = "that package could not be read"
		return out
	var clean: String = label.strip_edges()
	if clean.is_empty():
		out["why"] = "give the package a name first"
		return out
	if clean == AssetPacks.label_of(pack):
		out["why"] = "that is already its name"
		return out
	var fresh: Dictionary = pack.duplicate(true)
	fresh["label"] = clean
	if not Presets.save_asset_pack(fresh):
		out["why"] = "the package could not be written to the preset folder"
		return out
	out["pack"] = fresh
	out["ok"] = true
	return out


static func update_pack(pack: Dictionary) -> Dictionary:
	var out: Dictionary = {"ok": false, "pack": pack, "why": "", "note": ""}
	if not AssetPacks.is_pack(pack):
		out["why"] = "that package could not be read"
		return out
	if not AssetPacks.follows(pack):
		out["why"] = AssetPacks.label_of(pack) + " does not watch a folder"
		return out
	var v: Dictionary = AssetPackWatch.view_now(pack)
	if not bool(v.get("scanned", false)):
		v = AssetPackWatch.scan_blocking(pack)
	var said: String = AssetPacks.change_note(v)
	var fresh: Dictionary = AssetPacks.refreshed(pack, v)
	if not Presets.save_asset_pack(fresh):
		out["why"] = "the package could not be written to the preset folder"
		return out
	AssetPackWatch.forget_one(String(pack.get("id", "")))
	out["pack"] = fresh
	out["note"] = said
	out["ok"] = true
	return out


static func bin_names(doc: Project) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null:
		return out
	var seen: Dictionary = {}
	for b: String in doc.bins:
		var tidy: String = AssetPacks.clean_bin(b)
		if tidy.is_empty() or seen.has(tidy):
			continue
		seen[tidy] = true
		out.append(tidy)
	for m: MediaItem in doc.media:
		var tidy2: String = AssetPacks.clean_bin(m.bin)
		if tidy2.is_empty() or seen.has(tidy2):
			continue
		seen[tidy2] = true
		out.append(tidy2)
	out.sort()
	return out


func doc() -> Project:
	return Session.doc


func build_library(host: Node) -> void:
	name = "AssetPacksSheet"
	mode = MODE_PACKS
	sheet = Sheet.open(host, "Asset packages", 560.0, 500.0)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	note = sheet.call("add_note", LIBRARY_NOTE)
	status = PmLabel.dim("")
	col.add_child(status)
	list = SheetList.make(38.0, true, 52.0)
	list.set("click_activates", false)
	list.set("empty_text", "No packages yet. Mark some bin items, right click and save them as a package.")
	list.connect("activated", _on_activated)
	list.connect("pressed_row", _on_pressed_row)
	col.add_child(list)
	bin_row = _bin_row()
	col.add_child(bin_row)
	pick_row = _pick_row()
	col.add_child(pick_row)
	var close_button: Button = sheet.call("add_button", "Close")
	close_button.name = "Close"
	close_button.pressed.connect(_on_close)
	back_button = sheet.call("add_button", "Back to the packages")
	back_button.name = "Back"
	back_button.pressed.connect(_on_back)
	refresh_button = sheet.call("add_button", "Look at the folders again")
	refresh_button.name = "Refresh"
	refresh_button.pressed.connect(_on_refresh)
	update_button = sheet.call("add_button", "Update this package")
	update_button.name = "Update"
	update_button.pressed.connect(_on_update)
	rename_button = sheet.call("add_button", "Rename package")
	rename_button.name = "Rename"
	rename_button.pressed.connect(_on_rename)
	delete_button = sheet.call("add_button", "Delete package")
	delete_button.name = "Delete"
	delete_button.pressed.connect(_on_delete)
	main_button = sheet.call("add_button", "Open package", true)
	main_button.name = "Main"
	main_button.pressed.connect(_on_main)
	show_packs()


func build_save(host: Node, ids: PackedStringArray) -> void:
	name = "AssetPackSaveSheet"
	mode = MODE_SAVE
	media_ids = ids.duplicate()
	var d: Project = doc()
	var pack: Dictionary = Presets.asset_pack_from(d, media_ids, "Package", "", true)
	var items: Array[Dictionary] = AssetPacks.items_of(pack)
	sheet = Sheet.open(host, "Save as a package", 560.0)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	if items.is_empty():
		sheet.call("add_note", "None of the marked items came from a file on disk. Watch a folder below, or mark video, sound or image items in the bin first.")
	else:
		sheet.call("add_note", str(items.size()) + (" file is" if items.size() == 1 else " files are") + " going into this package: " + AssetPacks.names_text(items) + ". The package keeps the paths and the names, not copies of the files.")
	name_box = PmUI.line_edit("Package name", "")
	name_box.name = "PackName"
	PmUI.tip(name_box, "What you call this set, for example Sound effects or Stingers")
	col.add_child(name_box)
	col.add_child(_bin_pick_row(AssetPacks.suggested_bin(d, media_ids), "The bin folder the items land in when the package is opened. Leave it empty to land at the top of the bin"))
	auto_button = PmButton.make("Bring everything in as soon as the package is picked", "", true)
	auto_button.name = "ImportAtOnce"
	auto_button.button_pressed = true
	PmUI.tip(auto_button, "On: picking the package imports every file. Off: picking it shows the list so you choose")
	col.add_child(auto_button)
	col.add_child(PmUI.divider())
	watch_button = PmButton.make("Keep up with a folder on disk", "", true)
	watch_button.name = "Watch"
	watch_button.button_pressed = false
	PmUI.tip(watch_button, "On: the package takes everything in the folder below as well as the marked items")
	watch_button.toggled.connect(_on_watch_toggled)
	col.add_child(watch_button)
	watch_box = PmUI.vbox(Tk.px(4.0))
	var folder_row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	folder_button = PmButton.make("Choose a folder", "folder")
	folder_button.name = "ChooseFolder"
	folder_button.pressed.connect(_on_choose_folder)
	folder_row.add_child(folder_button)
	folder_label = PmLabel.dim("No folder chosen")
	folder_label.clip_text = true
	folder_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	folder_row.add_child(folder_label)
	watch_box.add_child(folder_row)
	follow_button = PmButton.make("Always update itself from that folder", "", true)
	follow_button.name = "Follow"
	follow_button.button_pressed = true
	PmUI.tip(follow_button, "On: files added to or changed in the folder turn up in the package by themselves. Off: the package keeps the files that are in the folder right now")
	watch_box.add_child(follow_button)
	deep_button = PmButton.make("Include the folders inside it", "", true)
	deep_button.name = "Deep"
	deep_button.button_pressed = true
	watch_box.add_child(deep_button)
	tree_button = PmButton.make("Keep the folder structure in the bin", "", true)
	tree_button.name = "KeepTree"
	tree_button.button_pressed = true
	watch_box.add_child(tree_button)
	watch_box.visible = false
	col.add_child(watch_box)
	suggest_watch_folder(AssetPacks.common_dir(d, media_ids))
	var cancel: Button = sheet.call("add_button", "Cancel")
	cancel.name = "Cancel"
	cancel.pressed.connect(_on_close)
	main_button = sheet.call("add_button", "Save package", true)
	main_button.name = "Main"
	main_button.disabled = items.is_empty()
	main_button.pressed.connect(_on_save)


func _bin_pick_row(start_text: String, tip: String) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	bin_box = PmUI.line_edit("Bin folder for these items, for example Sound effects", start_text)
	bin_box.name = "PackBin"
	bin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PmUI.tip(bin_box, tip)
	row.add_child(bin_box)
	var pick: Button = PmButton.make("Pick a bin", "folder")
	pick.name = "PickBin"
	PmUI.tip(pick, "Choose one of the bins this project already has, or type a new name")
	pick.pressed.connect(_on_pick_bin.bind(pick))
	row.add_child(pick)
	return row


func _on_pick_bin(anchor: Button) -> void:
	var names: PackedStringArray = bin_names(doc())
	var items: Array = [PmMenu.item("bin:", "The top of the bin")]
	if not names.is_empty():
		items.append(PmMenu.separator())
	for b: String in names:
		items.append(PmMenu.item("bin:" + b, b))
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_bin_picked)


func _on_bin_picked(id: String) -> void:
	if not id.begins_with("bin:") or bin_box == null:
		return
	bin_box.text = id.substr(4)


func _on_choose_folder() -> void:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_dialog.use_native_dialog = true
		_dialog.title = "Choose a folder for this package to watch"
		_dialog.dir_selected.connect(set_watch_folder)
		add_child(_dialog)
	_dialog.popup_centered(Vector2i(900, 600))


func _on_watch_toggled(on: bool) -> void:
	if watch_box != null:
		watch_box.visible = on
	if main_button == null:
		return
	main_button.disabled = media_ids.is_empty() and not (on and not watch_folder.is_empty())


func suggest_watch_folder(path: String) -> void:
	watch_folder = path.strip_edges()
	if folder_label != null:
		folder_label.text = watch_folder if not watch_folder.is_empty() else "No folder chosen"


func set_watch_folder(path: String) -> void:
	suggest_watch_folder(path)
	if watch_button != null:
		watch_button.button_pressed = true
	if watch_box != null:
		watch_box.visible = true
	if main_button != null and not watch_folder.is_empty():
		main_button.disabled = false
	if bin_box != null and bin_box.text.strip_edges().is_empty() and not watch_folder.is_empty():
		bin_box.text = AssetPacks.clean_bin(watch_folder.get_file())


static func watch_options(folder: String, watching: bool, follow: bool, deep: bool, keep_tree: bool) -> Dictionary:
	if folder.strip_edges().is_empty() or not watching:
		return {}
	return {"folders": [AssetPacks.folder_entry(folder, deep, keep_tree)], "follow": follow}


func save_options() -> Dictionary:
	return watch_options(
		watch_folder,
		watch_button == null or watch_button.button_pressed,
		follow_button == null or follow_button.button_pressed,
		deep_button == null or deep_button.button_pressed,
		tree_button == null or tree_button.button_pressed)


func _bin_row() -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row.add_child(PmLabel.dim("Lands in"))
	bin_box = PmUI.line_edit("The folder the package asks for", "")
	bin_box.name = "PackBin"
	bin_box.custom_minimum_size.x = float(Tk.px(220.0))
	PmUI.tip(bin_box, "The bin folder these items land in this time. Clear it to use the folder the package itself asks for")
	row.add_child(bin_box)
	var pick: Button = PmButton.make("Pick a bin", "folder")
	pick.name = "PickBin"
	PmUI.tip(pick, "Choose one of the bins this project already has, or type a new name")
	pick.pressed.connect(_on_pick_bin.bind(pick))
	row.add_child(pick)
	row.add_child(PmUI.spacer())
	row.visible = false
	return row


func _pick_row() -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	var all_button: Button = PmButton.make("Pick all")
	all_button.name = "PickAll"
	all_button.pressed.connect(_on_pick_all)
	row.add_child(all_button)
	var none_button: Button = PmButton.make("Pick none")
	none_button.name = "PickNone"
	none_button.pressed.connect(_on_pick_none)
	row.add_child(none_button)
	row.add_child(PmUI.spacer())
	row.visible = false
	return row


func _alive() -> bool:
	return is_inside_tree() and sheet != null and is_instance_valid(sheet)


func show_packs() -> void:
	mode = MODE_PACKS
	open_pack = {}
	open_view = {}
	picked.clear()
	packs = Presets.list_asset_packs(doc())
	row_keys = PackedStringArray()
	var rows: Array[Dictionary] = []
	var watched: int = 0
	for p: Dictionary in packs:
		row_keys.append(String(p.get("id", "")))
		var v: Dictionary = AssetPackWatch.view_now(p)
		if AssetPacks.follows(p):
			watched += 1
		var detail: String = AssetPacks.summary(p, v)
		var gone: String = AssetPacks.missing_note(p, v)
		if not gone.is_empty():
			detail += ". " + gone
		var said: String = AssetPacks.change_note(v)
		if not said.is_empty():
			detail += ". " + said
		rows.append({"lead": str(AssetPacks.items_for(p, v).size()), "title": AssetPacks.label_of(p), "detail": detail, "rule": true, "dim": false})
	list.call("set_rows", rows)
	bin_row.visible = false
	pick_row.visible = false
	back_button.visible = false
	delete_button.visible = not packs.is_empty()
	delete_button.disabled = packs.is_empty()
	rename_button.visible = not packs.is_empty()
	rename_button.disabled = packs.is_empty()
	refresh_button.visible = watched > 0
	update_button.visible = false
	main_button.text = "Open package"
	main_button.disabled = packs.is_empty()
	if note != null:
		note.text = LIBRARY_NOTE
	_set_status("")
	if watched > 0:
		_refresh_async()


func _set_status(text: String) -> void:
	if status == null:
		return
	status.text = text
	status.visible = not text.is_empty()


func _refresh_async() -> void:
	if packs.is_empty():
		return
	_set_status("Looking in the watched folders ...")
	if refresh_button != null:
		refresh_button.disabled = true
	AssetPackWatch.start(packs, _on_scan_landed)


func _on_scan_landed() -> void:
	if not _alive():
		return
	if refresh_button != null:
		refresh_button.disabled = false
	if mode == MODE_PACKS:
		_redraw_packs()
	elif mode == MODE_ITEMS:
		open_view = AssetPackWatch.view_now(open_pack)
		show_items(open_pack)


func _redraw_packs() -> void:
	var rows: Array[Dictionary] = []
	var busy: bool = false
	for p: Dictionary in packs:
		var v: Dictionary = AssetPackWatch.view_now(p)
		if AssetPacks.follows(p) and not bool(v.get("scanned", false)):
			busy = true
		var detail: String = AssetPacks.summary(p, v)
		var gone: String = AssetPacks.missing_note(p, v)
		if not gone.is_empty():
			detail += ". " + gone
		var said: String = AssetPacks.change_note(v)
		if not said.is_empty():
			detail += ". " + said
		rows.append({"lead": str(AssetPacks.items_for(p, v).size()), "title": AssetPacks.label_of(p), "detail": detail, "rule": true, "dim": false})
	list.call("set_rows", rows)
	_set_status("Still looking in the watched folders ..." if busy else "")


func show_items(pack: Dictionary) -> void:
	mode = MODE_ITEMS
	open_pack = pack.duplicate(true)
	if not open_view.has("items"):
		open_view = AssetPackWatch.view_now(open_pack)
	picked.clear()
	row_keys = PackedStringArray()
	var fresh: Dictionary = {}
	for it: Dictionary in (open_view.get("added", []) as Array):
		fresh[AssetPacks.path_key(String(it["path"]))] = "New"
	for it: Dictionary in (open_view.get("changed", []) as Array):
		fresh[AssetPacks.path_key(String(it["path"]))] = "Changed"
	var rows: Array[Dictionary] = []
	for it: Dictionary in AssetPacks.items_for(open_pack, open_view):
		var path: String = String(it["path"])
		var there: bool = AssetPacks.file_there(path)
		var key: String = AssetPacks.path_key(path)
		row_keys.append(path)
		if there:
			picked[key] = true
		var right: String = "Missing"
		if there:
			right = String(fresh.get(key, "In"))
		var detail: String = path
		var sub: String = String(it.get("sub", ""))
		if not sub.is_empty():
			detail += "  into " + sub
		rows.append({"lead": "", "title": String(it["label"]), "detail": detail, "rule": true, "dim": not there, "right": right, "chip": true, "ink": there, "strong": there})
	list.call("set_rows", rows)
	bin_box.text = AssetPacks.bin_of(open_pack)
	bin_row.visible = true
	pick_row.visible = true
	back_button.visible = true
	delete_button.visible = false
	rename_button.visible = false
	refresh_button.visible = AssetPacks.follows(open_pack)
	update_button.visible = AssetPacks.follows(open_pack)
	main_button.text = "Bring in the picked items"
	main_button.disabled = rows.is_empty()
	if note != null:
		var gone: String = AssetPacks.missing_note(open_pack, open_view)
		note.text = AssetPacks.label_of(open_pack) + ": click a row to leave it out or put it back in." + ((" " + gone + ". Those are left out and the rest still come in.") if not gone.is_empty() else "")
	_set_status(AssetPacks.change_note(open_view))


func cursor_pack() -> Dictionary:
	var i: int = int(list.get("cursor"))
	if i < 0 or i >= packs.size():
		return {}
	return packs[i]


func chosen_paths() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for it: Dictionary in AssetPacks.items_for(open_pack, open_view):
		var path: String = String(it["path"])
		if bool(picked.get(AssetPacks.path_key(path), false)):
			out.append(path)
	return out


func _refresh_ticks() -> void:
	var rows: Array[Dictionary] = list.get("rows")
	for i: int in rows.size():
		if i >= row_keys.size():
			continue
		var path: String = row_keys[i]
		var there: bool = AssetPacks.file_there(path)
		var on: bool = there and bool(picked.get(AssetPacks.path_key(path), false))
		rows[i]["right"] = ("In" if on else "Out") if there else "Missing"
		rows[i]["ink"] = on
		rows[i]["strong"] = there
	list.queue_redraw()


func _on_pick_all() -> void:
	if mode != MODE_ITEMS:
		return
	for path: String in row_keys:
		if AssetPacks.file_there(path):
			picked[AssetPacks.path_key(path)] = true
	_refresh_ticks()


func _on_pick_none() -> void:
	if mode != MODE_ITEMS:
		return
	picked.clear()
	_refresh_ticks()


func _on_pressed_row(index: int, _on_right: bool) -> void:
	if mode != MODE_ITEMS or index < 0 or index >= row_keys.size():
		return
	var path: String = row_keys[index]
	if not AssetPacks.file_there(path):
		Events.toast(path.get_file() + " is not where the package left it")
		return
	var key: String = AssetPacks.path_key(path)
	picked[key] = not bool(picked.get(key, false))
	_refresh_ticks()


func _on_activated(_index: int) -> void:
	if mode == MODE_PACKS:
		_open_cursor_pack()


func _on_main() -> void:
	if mode == MODE_PACKS:
		_open_cursor_pack()
	elif mode == MODE_ITEMS:
		_bring_in(open_pack, chosen_paths(), bin_box.text, open_view)


func _open_cursor_pack() -> void:
	var pack: Dictionary = cursor_pack()
	if pack.is_empty():
		Events.toast("Pick a package first")
		return
	_set_status("Looking in the watched folders ..." if AssetPacks.follows(pack) else "")
	AssetPackWatch.with_view(pack, func(v: Dictionary) -> void: _open_with_view(pack, v))


func _open_with_view(pack: Dictionary, v: Dictionary) -> void:
	if not _alive():
		return
	_set_status("")
	if AssetPacks.items_for(pack, v).is_empty():
		Events.toast(AssetPacks.label_of(pack) + " has nothing in it")
		return
	open_view = v
	if AssetPacks.import_at_once_of(pack):
		_bring_in(pack, AssetPacks.every_path(pack, v), "", v)
		return
	show_items(pack)


func _bring_in(pack: Dictionary, chosen: PackedStringArray, bin: String, v: Dictionary) -> void:
	var result: Dictionary = AssetPacks.import_chosen(doc(), pack, chosen, bin, v)
	var text: String = AssetPacks.result_note(result)
	if bool(result["ok"]):
		Events.toast(text if not text.is_empty() else "Package brought in")
		sheet.call("close")
		return
	Events.toast(text if not text.is_empty() else "Nothing came in from " + AssetPacks.label_of(pack))


func _on_back() -> void:
	show_packs()


func _on_refresh() -> void:
	AssetPackWatch.forget()
	if mode == MODE_ITEMS:
		_set_status("Looking in the watched folders ...")
		var one: Array[Dictionary] = [open_pack]
		AssetPackWatch.start(one, _on_scan_landed)
		return
	_refresh_async()


func _on_update() -> void:
	var pack: Dictionary = open_pack if mode == MODE_ITEMS else cursor_pack()
	if pack.is_empty():
		Events.toast("Pick a package first")
		return
	var result: Dictionary = update_pack(pack)
	if not bool(result["ok"]):
		Events.toast(String(result["why"]))
		return
	var said: String = String(result["note"])
	Events.toast(AssetPacks.label_of(pack) + " brought up to date" + ((": " + said) if not said.is_empty() else ""))
	open_view = {}
	show_packs()


func _on_rename() -> void:
	var pack: Dictionary = cursor_pack()
	if pack.is_empty():
		Events.toast("Pick a package first")
		return
	var fields: Array[Dictionary] = [{"key": "label", "label": "Name", "type": "string", "default": AssetPacks.label_of(pack)}]
	var answered: Signal = PmUI.form(sheet, "Rename package", fields, "Rename", "Cancel")
	answered.connect(_on_rename_form.bind(String(pack.get("id", ""))))


func _on_rename_form(result: Variant, pack_id: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var pack: Dictionary = {}
	for p: Dictionary in Presets.list_asset_packs(doc()):
		if String(p.get("id", "")) == pack_id:
			pack = p
	if pack.is_empty():
		return
	var res: Dictionary = rename_pack(pack, String((result as Dictionary).get("label", "")))
	if not bool(res["ok"]):
		Events.toast(String(res["why"]))
		return
	Events.toast("Package renamed to " + AssetPacks.label_of(res["pack"]))
	if _alive():
		show_packs()


func _on_delete() -> void:
	var pack: Dictionary = cursor_pack()
	if pack.is_empty():
		return
	var label: String = AssetPacks.label_of(pack)
	if not Presets.delete_asset_pack(String(pack.get("id", ""))):
		Events.toast(label + " could not be deleted")
		return
	AssetPackWatch.forget_one(String(pack.get("id", "")))
	Events.toast(label + " deleted. The files on disk stay where they are")
	show_packs()


func _on_save() -> void:
	var result: Dictionary = save_pack(doc(), media_ids, name_box.text, bin_box.text, auto_button.button_pressed, save_options())
	if not bool(result["ok"]):
		Events.toast(String(result["why"]))
		return
	Events.toast("Package " + AssetPacks.label_of(result["pack"]) + " saved")
	sheet.call("close")


func _on_close() -> void:
	sheet.call("close")

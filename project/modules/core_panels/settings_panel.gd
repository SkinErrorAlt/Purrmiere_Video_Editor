extends "res://modules/core_panels/panel_base.gd"

const ModulesList := preload("res://ui/editor/modules_list.gd")
const Keybind := preload("res://modules/core_panels/keybind_edit.gd")
const KEYS_FOLD := "settings.shortcuts"
const KEYS_TITLE := "Shortcuts"
const KEYS_NOTE := "Click the key beside a command, then press the new key. Escape cancels."
const KEYS_RESET := "Reset every key"
const KEYS_WAITING := "Press a key"
const KEYS_TIP := "Click to set a new key for this command"
const KEYS_WIDTH := 150.0

var search: String = ""
var capturing: String = ""
var pending_key: String = ""
var pending_clashes: Array[Dictionary] = []
var _search: LineEdit = null
var _list: VBoxContainer = null
var _queued: bool = false
var _editors: Dictionary = {}
var _built_keys: int = -1
var _editing: bool = false
var _folder_dialog: FileDialog = null
var _folder_label: Label = null
var _cache_dialog: FileDialog = null
var _cache_label: Label = null
var _keys_fold: VBoxContainer = null
var _keys_body: VBoxContainer = null
var _keys_catcher: Control = null
var _keys_status: Label = null
var _key_buttons: Dictionary = {}


func _build(root_: Control) -> void:
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_search = PmUI.line_edit("Search settings")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_on_search)
	head.add_child(_search)
	var folder_row: HBoxContainer = PmUI.hbox()
	folder_row.add_child(PmLabel.dim("Data folder"))
	_folder_label = PmLabel.trim(Prefs.data_dir(), "text")
	_folder_label.add_theme_font_override("font", Tk.font("mono"))
	PmUI.tip(_folder_label, "Settings, layouts, presets, user effects and modules live here. Nothing in this folder is touched when the app is updated.")
	folder_row.add_child(_folder_label)
	var open_b: Button = PmButton.make("Open")
	open_b.pressed.connect(_on_open_folder)
	folder_row.add_child(open_b)
	var change_b: Button = PmButton.make("Change")
	change_b.pressed.connect(_on_change_folder)
	folder_row.add_child(change_b)
	col.add_child(PmUI.inset(folder_row, 4.0, 0.0))
	var cache_row: HBoxContainer = PmUI.hbox()
	cache_row.add_child(PmLabel.dim("Cache folder"))
	_cache_label = PmLabel.trim(Prefs.cache_dir(), "text")
	_cache_label.add_theme_font_override("font", Tk.font("mono"))
	PmUI.tip(_cache_label, "Seek indexes, filmstrips and waveforms live here so the next open is fast. Safe to delete at any time; they are rebuilt on demand. Keep it off a folder that OneDrive or Dropbox syncs, or every index and filmstrip is uploaded.")
	cache_row.add_child(_cache_label)
	var open_c: Button = PmButton.make("Open")
	open_c.pressed.connect(_on_open_cache)
	cache_row.add_child(open_c)
	var change_c: Button = PmButton.make("Change")
	change_c.pressed.connect(_on_change_cache)
	cache_row.add_child(change_c)
	var purge_c: Button = PmButton.make("Delete all caches")
	purge_c.pressed.connect(_on_purge_cache)
	cache_row.add_child(purge_c)
	col.add_child(PmUI.inset(cache_row, 0.0, 4.0))
	var scroll: ScrollContainer = vscroll_area(col)
	_list = PmUI.vbox(0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	if not Prefs.changed.is_connected(_on_pref_changed):
		Prefs.changed.connect(_on_pref_changed)
	if not Host.modules_changed.is_connected(_queue):
		Host.modules_changed.connect(_queue)
	rebuild()


func _on_open_cache() -> void:
	OS.shell_open(Prefs.cache_dir())


func _on_change_cache() -> void:
	if _cache_dialog == null:
		_cache_dialog = FileDialog.new()
		_cache_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_cache_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_cache_dialog.use_native_dialog = true
		_cache_dialog.title = "Choose the cache folder"
		_cache_dialog.dir_selected.connect(_on_cache_chosen)
		_root.add_child(_cache_dialog)
	_cache_dialog.current_dir = Prefs.cache_dir()
	_cache_dialog.popup_centered(Vector2i(900, 600))


func _on_cache_chosen(dir: String) -> void:
	if Prefs.set_cache_dir_path(dir):
		if _cache_label != null:
			_cache_label.text = Prefs.cache_dir()
		Events.toast("Cache folder is now " + dir + ". Anything already built stays where it was.")
	else:
		Events.error("Could not use that folder", dir)


func _on_purge_cache() -> void:
	var n: int = PurrBridge.purge_cache()
	Events.toast("Deleted " + str(n) + " cache files; they rebuild when needed")


func _on_open_folder() -> void:
	OS.shell_open(Prefs.data_dir())


func _on_change_folder() -> void:
	if _folder_dialog == null:
		_folder_dialog = FileDialog.new()
		_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_folder_dialog.use_native_dialog = true
		_folder_dialog.title = "Choose the data folder"
		_folder_dialog.dir_selected.connect(_on_folder_chosen)
		_root.add_child(_folder_dialog)
	_folder_dialog.current_dir = Prefs.data_dir()
	_folder_dialog.popup_centered(Vector2i(900, 600))


func _on_folder_chosen(dir: String) -> void:
	if Prefs.set_data_dir(dir):
		_folder_label.text = Prefs.data_dir()
		Events.toast("Data folder is now " + dir + ". Restart to load everything from it.")
	else:
		Events.error("Could not use that folder", dir)


func _on_search(text: String) -> void:
	search = text.strip_edges().to_lower()
	rebuild()


func _on_pref_changed(key: String) -> void:
	if _editing:
		return
	if _editors.has(key):
		_sync_editor(key)
		return
	if key.begins_with("ui.fold.") or key.begins_with("ui.window.") or key.begins_with("ui.split."):
		return
	_queue()


func _sync_editor(key: String) -> void:
	var ed: Control = _editors.get(key, null)
	if ed == null or not is_instance_valid(ed):
		return
	var v: Variant = Prefs.get_value(key)
	if ed is CheckBox:
		var cb: CheckBox = ed
		if cb.button_pressed != bool(v):
			cb.set_pressed_no_signal(bool(v))
	elif ed is ColorPickerButton:
		var cpb: ColorPickerButton = ed
		var want: Color = Color.from_string(String(v), cpb.color)
		if not cpb.color.is_equal_approx(want):
			cpb.color = want
	elif ed is LineEdit:
		var le: LineEdit = ed
		if le.text != String(v) and not le.has_focus():
			le.text = String(v)
	elif ed.has_method("set_choices"):
		ed.call("set_value", str(v), false)
	elif ed.has_method("commit"):
		if absf(float(ed.get("value")) - float(v)) > 0.00001:
			ed.set("value", float(v))
			ed.queue_redraw()


func _queue() -> void:
	if _queued or not _alive():
		return
	_queued = true
	_root.get_tree().process_frame.connect(rebuild, CONNECT_ONE_SHOT)


static func choice_label(c: String) -> String:
	if c == c.to_lower() and not c.contains(" ") and not c.contains(","):
		return c.capitalize()
	return c


static func group_of(key: String) -> String:
	return key.get_slice(".", 0)


func rebuild() -> void:
	if not _alive():
		return
	_queued = false
	_forget_capture()
	_keys_fold = null
	_keys_body = null
	_keys_catcher = null
	_keys_status = null
	_key_buttons.clear()
	var scroll: ScrollContainer = _list.get_parent() as ScrollContainer
	var keep_scroll: int = scroll.scroll_vertical if scroll != null else 0
	PmUI.clear(_list)
	_editors.clear()
	_built_keys = Prefs.keys().size()
	var groups: Dictionary = {}
	for key: String in Prefs.keys():
		if key.begins_with("ui.fold.") or key.begins_with("ui.window.") or key.begins_with("ui.split.") or key.begins_with("modules.") or key == "ui.workspace" or key == "app.recent" or key == "projects.recent":
			continue
		var spec: Dictionary = Prefs.spec(key)
		var label: String = String(spec.get("label", key))
		if not search.is_empty() and not key.to_lower().contains(search) and not label.to_lower().contains(search):
			continue
		var g: String = group_of(key)
		if not groups.has(g):
			groups[g] = []
		(groups[g] as Array).append(key)
	var names: Array = groups.keys()
	names.sort()
	for g: String in names:
		var fold: VBoxContainer = PmFold.make(g.capitalize(), "settings." + g, search.is_empty() == false or g == "ui")
		if not search.is_empty():
			fold.set("open", true)
		var body: VBoxContainer = fold.get("body")
		var grid: GridContainer = GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for key: String in groups[g]:
			var spec: Dictionary = Prefs.spec(key)
			var l: Label = PmLabel.trim(String(spec.get("label", key)))
			PmUI.tip(l, String(spec.get("hint", "")) + ("\n" if spec.has("hint") else "") + key)
			grid.add_child(l)
			var ed: Control = _editor_for(key, spec)
			_editors[key] = ed
			grid.add_child(value_cell(ed))
		body.add_child(grid)
		_list.add_child(load("res://modules/core_panels/section_style.gd").call("wrap", fold, self))
	if Keybind.section_matches(search):
		_build_shortcuts()
	if bool(ModulesList.matches(search)):
		var mods: VBoxContainer = PmFold.make("Modules", "settings.modules", true)
		var mbody: VBoxContainer = mods.get("body")
		ModulesList.build_rows(mbody)
		_list.add_child(mods)
	if scroll != null and keep_scroll > 0:
		PmUI.restore_scroll(scroll, keep_scroll)
	load("res://modules/core_panels/panel_place.gd").call("settings_turn", self, scroll)


static func value_cell(ed: Control) -> Control:
	var cell: HBoxContainer = HBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(ed)
	return cell


func _build_shortcuts() -> void:
	var fold: VBoxContainer = PmFold.make(KEYS_TITLE, KEYS_FOLD, false)
	_keys_fold = fold
	_keys_body = fold.get("body")
	fold.connect("toggled", _on_keys_toggled)
	_list.add_child(load("res://modules/core_panels/section_style.gd").call("wrap", fold, self))
	if not search.is_empty() and not bool(fold.get("open")):
		fold.call("show_open", true)
	_fill_shortcuts()


func _on_keys_toggled(_open: bool) -> void:
	_forget_capture()
	_fill_shortcuts()


func _fill_shortcuts() -> void:
	if _keys_body == null or not is_instance_valid(_keys_body):
		return
	PmUI.clear(_keys_body)
	_key_buttons.clear()
	_keys_catcher = null
	_keys_status = null
	if _keys_fold == null or not bool(_keys_fold.get("open")):
		return
	var top: HBoxContainer = PmUI.hbox()
	var note: Label = PmLabel.wrap(KEYS_NOTE, "text_dim")
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(note)
	var reset: Button = PmButton.make(KEYS_RESET)
	reset.name = "ResetKeys"
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(_on_keys_reset)
	top.add_child(reset)
	_keys_body.add_child(top)
	var rows: Array[Dictionary] = Keybind.entries(search)
	if rows.is_empty():
		rows = Keybind.entries("")
	var last_cat: String = ""
	for e: Dictionary in rows:
		var cat: String = String(e["category"])
		if cat != last_cat:
			last_cat = cat
			_keys_body.add_child(PmLabel.meta(cat))
		_keys_body.add_child(_keys_row(e))
		if String(e["id"]) == capturing:
			_keys_body.add_child(_keys_capture_box())


func _keys_row(e: Dictionary) -> HBoxContainer:
	var id: String = String(e["id"])
	var row: HBoxContainer = PmUI.hbox()
	row.set_meta("cmd_id", id)
	var l: Label = PmLabel.trim(String(e["label"]))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var note: String = Keybind.changed_note(id)
	PmUI.tip(l, "Works in " + Keybind.scope_word(String(e["scope"])) + "\n" + id + ("\n" + note if not note.is_empty() else ""))
	row.add_child(l)
	var b: Button = PmButton.make(_keys_label(id))
	b.name = "Key"
	b.custom_minimum_size.x = float(Tk.px(KEYS_WIDTH))
	PmUI.tip(b, KEYS_TIP if note.is_empty() else note + " " + KEYS_TIP)
	b.pressed.connect(_on_keys_row.bind(id))
	row.add_child(b)
	_key_buttons[id] = b
	return row


func _keys_label(id: String) -> String:
	if id != capturing:
		return Keybind.keys_text(id)
	if pending_key.is_empty():
		return KEYS_WAITING
	return pending_key


func _keys_capture_box() -> VBoxContainer:
	var box: VBoxContainer = PmUI.vbox()
	box.name = "Capture"
	var colour: String = "text" if pending_clashes.is_empty() else "text_bright"
	_keys_status = PmLabel.wrap(Keybind.status_text(capturing, pending_key, pending_clashes), colour)
	_keys_status.name = "Status"
	box.add_child(_keys_status)
	var row: HBoxContainer = PmUI.hbox()
	if pending_clashes.is_empty():
		var clear_b: Button = PmButton.make("Remove the key")
		clear_b.name = "RemoveKey"
		clear_b.pressed.connect(keys_clear)
		row.add_child(clear_b)
	else:
		var assign_b: Button = PmButton.primary("Assign")
		assign_b.name = "Assign"
		assign_b.pressed.connect(keys_assign)
		row.add_child(assign_b)
	var cancel_b: Button = PmButton.make("Cancel")
	cancel_b.name = "CancelKey"
	cancel_b.pressed.connect(keys_cancel)
	row.add_child(cancel_b)
	box.add_child(row)
	_keys_catcher = Control.new()
	_keys_catcher.name = "KeyCatcher"
	_keys_catcher.focus_mode = Control.FOCUS_ALL
	_keys_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys_catcher.gui_input.connect(_on_input)
	box.add_child(_keys_catcher)
	return box


func _grab_catcher() -> void:
	_grab_catcher_now.call_deferred()


func _grab_catcher_now() -> void:
	if _keys_catcher != null and is_instance_valid(_keys_catcher) and _keys_catcher.is_inside_tree():
		_keys_catcher.grab_focus()


func _forget_capture() -> void:
	capturing = ""
	pending_key = ""
	pending_clashes = []


func keys_start(id: String) -> void:
	if id.is_empty():
		return
	capturing = id
	pending_key = ""
	pending_clashes = []
	_fill_shortcuts()
	_grab_catcher()


func keys_cancel() -> void:
	_forget_capture()
	_fill_shortcuts()


func keys_propose(key: String) -> bool:
	if capturing.is_empty() or key.is_empty():
		return false
	pending_key = key
	pending_clashes = Keybind.clashes_for(capturing, key)
	if pending_clashes.is_empty():
		keys_assign()
		return true
	_fill_shortcuts()
	_grab_catcher()
	return false


func keys_feed(k: InputEventKey) -> bool:
	if capturing.is_empty() or not k.pressed or k.echo:
		return false
	if Keybind.is_cancel(k):
		keys_cancel()
		return true
	var text: String = Keybind.key_event_text(k)
	if text.is_empty():
		return true
	keys_propose(text)
	return true


func keys_assign() -> void:
	if capturing.is_empty() or pending_key.is_empty():
		return
	Keybind.assign(capturing, pending_key, pending_clashes)
	keys_cancel()


func keys_clear() -> void:
	if capturing.is_empty():
		return
	Keybind.clear_keys(capturing)
	keys_cancel()


func keys_reset_all() -> void:
	Keybind.reset_all()
	keys_cancel()


func _on_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if _keys_catcher != null and is_instance_valid(_keys_catcher):
		_keys_catcher.accept_event()
	keys_feed(event as InputEventKey)


func _on_keys_row(id: String) -> void:
	if capturing == id:
		keys_cancel()
		return
	keys_start(id)


func _on_keys_reset() -> void:
	var answered: Signal = PmUI.confirm(_root, Keybind.RESET_TITLE, Keybind.RESET_TEXT, Keybind.RESET_OK, "Cancel")
	answered.connect(_on_keys_reset_answered)


func _on_keys_reset_answered(ok: Variant) -> void:
	if not bool(ok):
		return
	keys_reset_all()


func _editor_for(key: String, spec: Dictionary) -> Control:
	var v: Variant = Prefs.get_value(key)
	var kind: String = String(spec.get("type", ""))
	if kind.is_empty():
		if v is bool:
			kind = "bool"
		elif v is int:
			kind = "int"
		elif v is float:
			kind = "float"
		elif v is String:
			kind = "string"
	if kind == "action":
		var row: VBoxContainer = PmUI.vbox(Tk.px(2.0))
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b: Button = PmButton.make(String(spec.get("button", "Do it")))
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var call: Variant = spec.get("run", null)
		if call is Callable:
			b.pressed.connect(call as Callable)
		else:
			b.disabled = true
		row.add_child(b)
		var note: String = String(spec.get("note", ""))
		if not note.is_empty():
			var nl: Label = PmLabel.dim(note)
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nl.custom_minimum_size.x = float(Tk.px(60.0))
			var room: MarginContainer = MarginContainer.new()
			room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			room.mouse_filter = Control.MOUSE_FILTER_IGNORE
			room.add_theme_constant_override("margin_right", Tk.px(8.0))
			room.add_child(nl)
			row.add_child(room)
		return row
	if kind == "bool":
		var cb: CheckBox = CheckBox.new()
		cb.button_pressed = bool(v)
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(_on_bool.bind(key))
		return cb
	if kind == "int" or kind == "float":
		var f: Control = PmField.make(float(v), float(spec.get("min", -INF)), float(spec.get("max", INF)), 1.0 if kind == "int" else 0.1, "")
		if kind == "int":
			f.set("precision", 0)
		f.set("show_range", spec.has("min") and spec.has("max"))
		f.custom_minimum_size.x = float(Tk.px(100.0))
		f.connect("value_changed", _on_number.bind(key, kind == "int"))
		f.connect("edit_begun", _on_edit_begun)
		f.connect("edit_ended", _on_edit_ended)
		return f
	if kind == "enum":
		var choices: Array = []
		for c: Variant in spec.get("choices", []):
			choices.append(PmDrop.choice(String(c), choice_label(String(c))))
		var drop: Button = PmDrop.make_drop(choices, str(v))
		drop.connect("changed", _on_enum.bind(key, v is int))
		return drop
	if kind == "colour":
		var cp: ColorPickerButton = ColorPickerButton.new()
		cp.color = Color.from_string(String(v), Color.WHITE)
		cp.edit_alpha = true
		cp.focus_mode = Control.FOCUS_NONE
		cp.custom_minimum_size = Vector2(float(Tk.px(64.0)), float(Tk.px(20.0)))
		cp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		cp.color_changed.connect(_on_colour.bind(key))
		return cp
	if kind == "string":
		var le: LineEdit = PmUI.line_edit("", String(v))
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.text_submitted.connect(_on_string.bind(key))
		return le
	var ro: Label = PmLabel.faint(str(v).left(60))
	return ro


func _on_edit_begun() -> void:
	_editing = true


func _on_edit_ended() -> void:
	_editing = false


func _on_bool(on: bool, key: String) -> void:
	Prefs.set_value(key, on)


func _on_number(v: float, key: String, is_int: bool) -> void:
	_editing = true
	Prefs.set_value(key, int(round(v)) if is_int else v)
	_editing = false


func _on_enum(id: String, key: String, numeric: bool) -> void:
	Prefs.set_value(key, int(id) if numeric else id)


func _on_colour(col: Color, key: String) -> void:
	Prefs.set_value(key, "#" + col.to_html(true))


func _on_string(text: String, key: String) -> void:
	Prefs.set_value(key, text)


func _on_module(on: bool, id: String) -> void:
	Host.set_module_enabled(id, on)

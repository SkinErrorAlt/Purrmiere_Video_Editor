extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const Convert := preload("res://engine/gdshader_convert.gd")
const ImportedShaders := preload("res://doc/imported_shaders.gd")
const SELF_PATH := "res://modules/core_panels/shader_sheet.gd"
const IMPORT_PATH := "res://modules/core_panels/shader_import.gd"
const WIDTH := 700.0
const CODE_H := 236.0
const LABEL_W := 96.0
const CHECK_DELAY := 0.5
const LINE_W := 52.0
const ERROR_TOKEN := "key_over"

var sheet: Control = null
var name_edit: LineEdit = null
var code_edit: CodeEdit = null
var status_box: VBoxContainer = null
var target_note: Label = null
var import_button: Button = null
var source: String = ""
var targets: PackedStringArray = PackedStringArray()
var edit_id: String = ""
var last: Dictionary = {}
var _wait: float = -1.0
var _dialog: FileDialog = null


static func open(host: Node, p_name: String, p_source: String, code: String, p_targets: PackedStringArray, p_edit_id: String = "", first: Dictionary = {}) -> Node:
	var script: GDScript = load(SELF_PATH)
	var s: Node = script.new()
	s.call("build", host, p_name, p_source, code, p_targets, p_edit_id, first)
	return s


func _importer() -> GDScript:
	return load(IMPORT_PATH)


func build(host: Node, p_name: String, p_source: String, code: String, p_targets: PackedStringArray, p_edit_id: String, first: Dictionary) -> void:
	name = "ShaderImportSheet"
	source = p_source
	targets = p_targets
	edit_id = p_edit_id
	sheet = Sheet.open(host, "Edit " + p_name if not edit_id.is_empty() else "Import a Godot shader", WIDTH)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	var row: HBoxContainer = PmUI.hbox(Tk.px(10.0))
	var nl: Label = PmLabel.body("Name")
	nl.custom_minimum_size.x = float(Tk.px(LABEL_W))
	row.add_child(nl)
	name_edit = PmUI.line_edit("Name of the effect", p_name)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_edit)
	col.add_child(row)
	code_edit = CodeEdit.new()
	code_edit.name = "Code"
	code_edit.gutters_draw_line_numbers = true
	code_edit.placeholder_text = "Paste the shader code here, for example from godotshaders.com"
	code_edit.custom_minimum_size = Vector2(float(sheet.get("inner_w")), float(Tk.px(CODE_H)))
	code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_edit.add_theme_font_override("font", Tk.font("mono"))
	code_edit.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_body")))
	code_edit.add_theme_color_override("font_color", Tk.c["text"])
	code_edit.add_theme_color_override("line_number_color", Tk.c["text_faint"])
	code_edit.add_theme_color_override("background_color", Tk.c["bg_field"])
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tk.c["bg_field"]
	sb.border_color = Tk.c["border"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(Tk.px(Tk.sz("radius_field"))))
	sb.content_margin_left = 4.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	code_edit.add_theme_stylebox_override("normal", sb)
	code_edit.add_theme_stylebox_override("focus", sb)
	code_edit.text = code
	code_edit.text_changed.connect(_on_code_changed)
	col.add_child(code_edit)
	var box: PanelContainer = PmUI.panel("bg_panel_alt")
	status_box = PmUI.vbox(Tk.px(2.0))
	box.add_child(PmUI.inset(status_box))
	col.add_child(box)
	target_note = sheet.call("add_note", String(_importer().call("target_text", Session.seq(), targets)) if edit_id.is_empty() else "Changes this effect on every clip that uses it, keeping the values of options that stay. One undo step.")
	var buttons: HBoxContainer = sheet.call("add_buttons")
	buttons.alignment = BoxContainer.ALIGNMENT_BEGIN
	var open_file: Button = PmButton.make("Open a file...")
	open_file.pressed.connect(_on_open_file)
	buttons.add_child(open_file)
	var gap: Control = PmUI.spacer(true)
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(gap)
	var cancel: Button = PmButton.make("Cancel")
	cancel.pressed.connect(close)
	buttons.add_child(cancel)
	import_button = PmButton.primary("Update" if not edit_id.is_empty() else "Import")
	import_button.pressed.connect(_on_import)
	buttons.add_child(import_button)
	name_edit.text_changed.connect(_on_name_changed)
	if first.is_empty():
		recheck()
	else:
		last = first
		show_result(first, true)
	set_process(true)


func _process(dt: float) -> void:
	if _wait < 0.0:
		return
	_wait -= dt
	if _wait < 0.0:
		recheck()


func _on_code_changed() -> void:
	_wait = CHECK_DELAY
	import_button.disabled = true


func _on_name_changed(_t: String) -> void:
	import_button.disabled = not bool(last.get("ok", false)) or name_edit.text.strip_edges().is_empty()


func recheck() -> void:
	_wait = -1.0
	last = _importer().call("check", name_edit.text, source, code_edit.text)
	show_result(last, false)


func _status_line(text: String, token: String, bold: bool = false) -> Label:
	var l: Label = PmLabel.wrap(text, token)
	l.custom_minimum_size.x = float(sheet.get("inner_w")) - float(Tk.px(20.0))
	if bold:
		l.add_theme_font_override("font", Tk.font("body_semibold"))
	status_box.add_child(l)
	return l


func show_result(r: Dictionary, jump: bool) -> void:
	PmUI.clear(status_box)
	for i: int in code_edit.get_line_count():
		code_edit.set_line_background_color(i, Color(0.0, 0.0, 0.0, 0.0))
	var conv: Dictionary = r.get("conv", {})
	if code_edit.text.strip_edges().is_empty():
		_status_line("Paste a Godot 4 canvas_item shader, or open a .gdshader file.", "text_dim")
		import_button.disabled = true
		return
	if bool(r.get("ok", false)):
		var params: Array = conv.get("params", [])
		var head: String = "Ready. " + (str(params.size()) + (" option." if params.size() == 1 else " options.") if not params.is_empty() else "No options: the shader has no uniforms to change.")
		if not bool(r.get("compiled", false)):
			head += " It was not compiled here, because this process has no graphics card."
		_status_line(head, "text_bright", true)
		if not params.is_empty():
			_status_line("Options: " + Convert.option_summary(params) + ". Every option can be keyframed.", "text_dim")
		for n: String in conv.get("notes", PackedStringArray()):
			_status_line(n, "text_dim")
		import_button.disabled = name_edit.text.strip_edges().is_empty()
		return
	import_button.disabled = true
	var first_line: int = -1
	var errc: Color = Tk.c[ERROR_TOKEN]
	for p: Variant in r.get("problems", []):
		var d: Dictionary = p
		var line: int = int(d.get("line", 0))
		var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
		var ln: Label = PmLabel.tight("Line " + str(line) if line > 0 else "", ERROR_TOKEN)
		ln.custom_minimum_size.x = float(Tk.px(LINE_W))
		ln.add_theme_font_override("font", Tk.font("mono"))
		row.add_child(ln)
		var txt: Label = PmLabel.wrap(String(d.get("text", "")), ERROR_TOKEN)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.custom_minimum_size.x = float(sheet.get("inner_w")) - float(Tk.px(LINE_W + 30.0))
		row.add_child(txt)
		status_box.add_child(row)
		if line > 0 and line <= code_edit.get_line_count():
			code_edit.set_line_background_color(line - 1, Color(errc.r, errc.g, errc.b, 0.2))
			if first_line < 0:
				first_line = line - 1
	if bool(conv.get("ok", false)):
		_status_line("Fix the line and the check runs again. Nothing is added until it compiles.", "text_dim")
	if jump and first_line >= 0:
		code_edit.set_line_as_center_visible(first_line)


func _entry() -> Dictionary:
	return ImportedShaders.make_entry(name_edit.text, source, code_edit.text, last.get("conv", {}))


func _on_import() -> void:
	if _wait >= 0.0 or last.is_empty():
		recheck()
	if not bool(last.get("ok", false)) or name_edit.text.strip_edges().is_empty():
		return
	var entry: Dictionary = _entry()
	var imp: GDScript = _importer()
	if not edit_id.is_empty():
		var only: String = targets[0] if targets.size() == 1 else ""
		if bool(imp.call("update_entry", Session.doc, edit_id, entry, only)):
			Events.toast("Updated " + String(entry["label"]))
	else:
		var placed: int = int(imp.call("import_entry", Session.doc, Session.seq(), entry, targets))
		if placed >= 0:
			Events.toast(String(imp.call("done_toast", String(entry["label"]), placed)))
	imp.call("refresh_panels")
	close()


func _on_open_file() -> void:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.use_native_dialog = true
		_dialog.filters = PackedStringArray(["*.gdshader,*.shader ; Godot shaders"])
		_dialog.file_selected.connect(load_file)
		add_child(_dialog)
	_dialog.popup_centered(Vector2i(900, 600))


func load_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	code_edit.text = FileAccess.get_file_as_string(path)
	source = path.get_file()
	if name_edit.text.strip_edges().is_empty() or name_edit.text == "Pasted shader":
		name_edit.text = String(_importer().call("name_from_path", path))
	recheck()


func close() -> void:
	if sheet != null and is_instance_valid(sheet):
		sheet.call("close")

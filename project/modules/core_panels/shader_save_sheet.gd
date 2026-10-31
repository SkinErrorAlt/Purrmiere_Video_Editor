extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const ImportedShaders := preload("res://doc/imported_shaders.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const SELF_PATH := "res://modules/core_panels/shader_save_sheet.gd"
const IMPORT_PATH := "res://modules/core_panels/shader_import.gd"
const WIDTH := 520.0
const LABEL_W := 96.0
const DEFAULT_CATEGORY := "User"

var sheet: Control = null
var source_id: String = ""
var name_edit: LineEdit = null
var category_drop: Button = null
var blurb_edit: LineEdit = null
var switch_box: CheckBox = null
var warn_label: Label = null
var save_button: Button = null
var category: String = DEFAULT_CATEGORY


static func open(host: Node, id: String) -> Node:
	var entry: Dictionary = ImportedShaders.entry_for(Session.doc, id)
	if entry.is_empty():
		Events.toast("The code of this effect is not in this project")
		return null
	var script: GDScript = load(SELF_PATH)
	var s: Node = script.new()
	s.call("build", host, id, entry)
	return s


static func categories() -> PackedStringArray:
	var seen: Dictionary = {}
	for d: Dictionary in EffectSource.list():
		if bool(d.get("audio", false)) or bool(d.get("embedded", false)):
			continue
		seen[String(d.get("category", ""))] = true
	seen.erase(DEFAULT_CATEGORY)
	seen.erase(ImportedShaders.CATEGORY)
	seen.erase("")
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in seen.keys():
		out.append(String(k))
	out.sort()
	out.insert(0, DEFAULT_CATEGORY)
	return out


func _row(col: VBoxContainer, label: String, control: Control) -> void:
	var row: HBoxContainer = PmUI.hbox(Tk.px(10.0))
	var l: Label = PmLabel.body(label)
	l.custom_minimum_size.x = float(Tk.px(LABEL_W))
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	col.add_child(row)


func build(host: Node, id: String, entry: Dictionary) -> void:
	name = "ShaderSaveSheet"
	source_id = id
	sheet = Sheet.open(host, "Save to the Effects panel", WIDTH)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	var start_name: String = String(entry.get("library_label", "")) if not String(entry.get("library_label", "")).is_empty() else String(entry.get("label", ""))
	name_edit = PmUI.line_edit("Name", start_name)
	name_edit.text_changed.connect(_on_name)
	name_edit.text_submitted.connect(_on_submit)
	_row(col, "Name", name_edit)
	var choices: Array = []
	for c: String in categories():
		choices.append(PmDrop.choice(c, c))
	var want: String = String(entry.get("library_category", ""))
	category = want if not want.is_empty() else DEFAULT_CATEGORY
	category_drop = PmDrop.make_drop(choices, category)
	category_drop.connect("changed", _on_category)
	_row(col, "Category", category_drop)
	blurb_edit = PmUI.line_edit("Optional, shown when you hover it", "")
	blurb_edit.text_submitted.connect(_on_submit)
	_row(col, "Description", blurb_edit)
	var used: int = ImportedShaders.used_count(Session.doc, String(entry["id"]))
	if not String(entry.get("library_id", "")).is_empty():
		used += ImportedShaders.used_count(Session.doc, String(entry["library_id"]))
	switch_box = CheckBox.new()
	switch_box.text = "Use the saved effect on the " + str(used) + (" clip that uses this one" if used == 1 else " clips that use this one")
	switch_box.button_pressed = true
	switch_box.focus_mode = Control.FOCUS_NONE
	switch_box.visible = used > 0
	col.add_child(switch_box)
	warn_label = PmLabel.wrap("", "key_over")
	warn_label.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_small")))
	warn_label.custom_minimum_size.x = float(sheet.get("inner_w"))
	col.add_child(warn_label)
	sheet.call("add_note", "Saved as a folder in your effects folder (" + ProjectSettings.globalize_path(EffectSource.user_root()) + "), with an effect.json and the converted shader. It is listed at once and works in every project. This project keeps its own copy too, so it still opens on a computer without the saved effect.")
	var cancel: Button = sheet.call("add_button", "Cancel")
	cancel.pressed.connect(close)
	save_button = sheet.call("add_button", "Save", true)
	save_button.pressed.connect(save)
	_on_name(name_edit.text)


func _on_category(id: String) -> void:
	category = id


func _on_name(text: String) -> void:
	var clean: String = text.strip_edges()
	save_button.disabled = clean.is_empty()
	if clean.is_empty():
		warn_label.text = ""
		warn_label.visible = false
		return
	var plan: Dictionary = load(IMPORT_PATH).call("library_plan", clean)
	var msg: String = ""
	if bool(plan.get("replaces", false)):
		msg = "An effect called " + clean + " is already in your effects folder. Saving replaces it."
	elif bool(plan.get("renamed", false)):
		msg = "An effect that comes with Purrmiere already uses this name, so it is saved in the folder " + String(plan["id"]) + "."
	warn_label.text = msg
	warn_label.visible = not msg.is_empty()


func _on_submit(_t: String) -> void:
	if not save_button.disabled:
		save()


func save() -> Dictionary:
	var clean: String = name_edit.text.strip_edges()
	var r: Dictionary = load(IMPORT_PATH).call("save_library", Session.doc, source_id, clean, category, blurb_edit.text, switch_box.visible and switch_box.button_pressed)
	if bool(r.get("ok", false)):
		Events.toast("Saved " + clean + " to the Effects panel, in " + category)
		close()
	else:
		Events.toast(String(r.get("reason", "Could not save it")))
	return r


func close() -> void:
	if sheet != null and is_instance_valid(sheet):
		sheet.call("close")

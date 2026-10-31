extends Node

const Cards := preload("res://doc/project_cards.gd")
const Project := preload("res://doc/project.gd")
const Sheet := preload("res://modules/core_panels/sheet.gd")
const RatingSheet := preload("res://ui/editor/rating_sheet.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const SELF_PATH := "res://ui/editor/project_card_sheet.gd"
const WIDTH := 560.0

var doc: Project = null
var sheet: Control = null
var _preview: TextureRect = null
var _desc: TextEdit = null
var _finished: CheckBox = null


static func open(host: Node, p_doc: Project) -> Node:
	var s: Node = (load(SELF_PATH) as GDScript).new()
	s.call("build", host, p_doc)
	return s


func build(host: Node, p_doc: Project) -> void:
	name = "ProjectCardSheet"
	doc = p_doc
	sheet = Sheet.open(host, "Project card", WIDTH)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(256.0, 144.0)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(_preview)
	var pic_row: HBoxContainer = PmUI.hbox()
	col.add_child(pic_row)
	var grab: Button = PmButton.make("Use the Program picture", "camera")
	grab.pressed.connect(use_program_picture)
	pic_row.add_child(grab)
	var choices: Array = [PmDrop.choice("none", "No picture")]
	for i: int in Cards.PREMADE_COUNT:
		choices.append(PmDrop.choice(Cards.PREMADE + str(i), "Premade picture " + str(i + 1)))
	var current: String = String(doc.info.get(Cards.INFO_THUMB, "")) if doc != null else ""
	var premade: Button = PmDrop.make_drop(choices, current if Cards.premade_index(current) >= 0 else "none")
	premade.connect("changed", func(id: String) -> void: set_thumb("" if id == "none" else id))
	pic_row.add_child(premade)
	col.add_child(PmLabel.body("Description"))
	_desc = TextEdit.new()
	_desc.custom_minimum_size = Vector2(0.0, 80.0)
	_desc.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_desc.text = doc.description if doc != null else ""
	col.add_child(_desc)
	_finished = CheckBox.new()
	_finished.text = "This project is finished"
	_finished.focus_mode = Control.FOCUS_NONE
	_finished.button_pressed = bool(doc.info.get(Cards.INFO_FINISHED, false)) if doc != null else false
	col.add_child(_finished)
	var rate_b: Button = sheet.call("add_button", "Rate...")
	rate_b.pressed.connect(func() -> void: RatingSheet.open(sheet, doc.path, Cards.facts_of(doc.to_dict(), doc.path), PackedStringArray(), doc))
	var cancel: Button = sheet.call("add_button", "Cancel")
	cancel.pressed.connect(func() -> void: sheet.call("close"))
	var ok_b: Button = sheet.call("add_button", "Apply", true)
	ok_b.pressed.connect(apply)
	_show_thumb()


func _show_thumb() -> void:
	if doc == null or _preview == null:
		return
	var t: String = String(doc.info.get(Cards.INFO_THUMB, ""))
	var pre: int = Cards.premade_index(t)
	if pre >= 0:
		_preview.texture = ImageTexture.create_from_image(Cards.premade_image(pre, 256, 144))
	elif not t.is_empty() and FileAccess.file_exists(t):
		var img: Image = Image.load_from_file(t)
		_preview.texture = ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null
	else:
		_preview.texture = null


func set_thumb(value: String) -> void:
	Cards.write_to(doc, {Cards.INFO_THUMB: value if not value.is_empty() else null}, "Project picture")
	_show_thumb()


func program_picture() -> Image:
	var panel: Object = Bus.instance().panel("program")
	var area: Control = panel.call("root") if panel != null and panel.has_method("root") else null
	if area == null or not is_instance_valid(area) or not area.is_visible_in_tree():
		return null
	var tex: ViewportTexture = area.get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.is_empty():
		return null
	var r: Rect2i = Rect2i(area.get_global_rect()).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x < 8 or r.size.y < 8:
		return null
	return img.get_region(r)


func use_program_picture() -> bool:
	var img: Image = program_picture()
	if img == null:
		Events.toast("Show the Program monitor first")
		return false
	var p: String = Cards.save_thumb(doc.id, img)
	if p.is_empty():
		return false
	set_thumb(p)
	return true


func apply() -> void:
	var fields: Dictionary = {"description": _desc.text.strip_edges(), Cards.INFO_FINISHED: _finished.button_pressed}
	Cards.write_to(doc, fields, "Project card")
	sheet.call("close")

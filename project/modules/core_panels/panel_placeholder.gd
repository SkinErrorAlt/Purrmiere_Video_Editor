extends "res://host/interfaces/i_panel.gd"

const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const SCOPES: Dictionary = {
	"timeline": "timeline",
	"program": "program",
	"source": "source",
	"bin": "bin",
	"keyframes": "keys",
	"effect_controls": "controls",
}

var _id: String = ""
var _title: String = ""
var _control: Control = null
var _focused: bool = false


static func make(id_: String, title_: String) -> RefCounted:
	var script: GDScript = load("res://modules/core_panels/panel_placeholder.gd")
	var p: RefCounted = script.new()
	p.set("_id", id_)
	p.set("_title", title_ if not title_.is_empty() else id_.capitalize())
	return p


func id() -> String:
	return _id


func title() -> String:
	return _title


func scope() -> String:
	return String(SCOPES.get(_id, "global"))


func build(parent: Control) -> Control:
	var root := Control.new()
	root.name = "Placeholder_" + _id
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: ColorRect = PmUI.fill("bg_panel")
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(fill)
	var col: VBoxContainer = PmUI.vbox()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head: Label = PmLabel.headline(_title)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(head)
	var idl: Label = PmLabel.mono(_id, "text_dim")
	idl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	idl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(idl)
	var note: Label = PmLabel.faint("Placeholder panel, the real one arrives with its module")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(note)
	root.add_child(col)
	parent.add_child(root)
	_control = root
	return root


func handle_key(_e: InputEventKey) -> bool:
	return false


func save_state() -> Dictionary:
	return {}


func restore_state(_d: Dictionary) -> void:
	pass


func on_focus(has: bool) -> void:
	_focused = has

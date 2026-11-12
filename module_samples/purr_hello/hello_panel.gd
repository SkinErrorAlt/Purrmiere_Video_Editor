extends RefCounted
## A small dockable panel: shows the open sequence and a button that runs the module's command.

var _id: String = ""
var _title: String = ""
var _label: Label = null


func setup(id_: String, title_: String) -> void:
	_id = id_
	_title = title_


func id() -> String:
	return _id


func title() -> String:
	return _title


func icon() -> String:
	return ""


func build(parent: Control) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "HelloPanel"
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label = Label.new()
	_label.text = "Hello from a module. This panel was added through the Purrmiere module API."
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_label)
	parent.add_child(box)
	return box


func handle_key(_e: InputEventKey) -> bool:
	return false


func save_state() -> Dictionary:
	return {}


func restore_state(_d: Dictionary) -> void:
	pass


func on_focus(_has: bool) -> void:
	pass


func scope() -> String:
	return "global"

extends RefCounted

const VERSION := 1
const IFACE := "IPanel"


func id() -> String:
	return ""


func title() -> String:
	return id().capitalize()


func icon() -> String:
	return ""


func build(parent: Control) -> Control:
	var c := Control.new()
	c.name = "EmptyPanel"
	parent.add_child(c)
	return c


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

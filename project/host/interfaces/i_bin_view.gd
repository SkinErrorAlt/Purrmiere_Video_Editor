extends RefCounted

const VERSION := 1
const IFACE := "IBinView"


func id() -> String:
	return ""


func label() -> String:
	return id().capitalize()


func icon() -> String:
	return "list"


func build(parent: Control) -> Control:
	var c := Control.new()
	parent.add_child(c)
	return c


func set_items(_items: Array[Dictionary]) -> void:
	pass


func selection() -> PackedStringArray:
	return PackedStringArray()

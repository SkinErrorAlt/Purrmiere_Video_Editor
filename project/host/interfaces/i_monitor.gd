extends RefCounted

const VERSION := 1
const IFACE := "IMonitor"


func id() -> String:
	return ""


func label() -> String:
	return id().capitalize()


func build(parent: Control) -> Control:
	var c := Control.new()
	parent.add_child(c)
	return c


func set_texture(_tex: Texture2D) -> void:
	pass


func set_overlay(_kind: String, _data: Dictionary) -> void:
	pass


func picture_rect() -> Rect2:
	return Rect2()

extends RefCounted

const VERSION := 1
const IFACE := "ITimelineView"


func id() -> String:
	return ""


func label() -> String:
	return id().capitalize()


func build(parent: Control) -> Control:
	var c := Control.new()
	parent.add_child(c)
	return c


func set_sequence(_seq: Object, _doc: Object) -> void:
	pass


func set_view(_scroll_x: float, _scroll_y: float, _pps: float) -> void:
	pass


func view() -> Dictionary:
	return {"scroll_x": 0.0, "scroll_y": 0.0, "pps": 38.0, "header_w": 160.0}

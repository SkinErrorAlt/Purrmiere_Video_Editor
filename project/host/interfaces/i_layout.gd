extends RefCounted

const VERSION := 1
const IFACE := "ILayout"


func id() -> String:
	return ""


func label() -> String:
	return id().capitalize()


func tree() -> Dictionary:
	return {"t": "g", "tabs": [], "active": ""}


func floats() -> Array[Dictionary]:
	return []

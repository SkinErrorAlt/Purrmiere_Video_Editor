extends RefCounted

const VERSION := 1
const IFACE := "ITheme"


func id() -> String:
	return ""


func label() -> String:
	return id().capitalize()


func colours() -> Dictionary:
	return {}


func sizes() -> Dictionary:
	return {}

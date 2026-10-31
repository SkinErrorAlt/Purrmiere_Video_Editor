extends RefCounted

const VERSION := 1
const IFACE := "IKeymap"


func id() -> String:
	return ""


func label() -> String:
	return id().capitalize()


func keys() -> Dictionary:
	return {}

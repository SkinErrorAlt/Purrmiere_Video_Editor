extends RefCounted

const VERSION := 1
const IFACE := "IExporter"


func id() -> String:
	return ""


func label() -> String:
	return id().capitalize()


func options_spec() -> Array[Dictionary]:
	return []


func run(_job: Dictionary) -> int:
	return -1

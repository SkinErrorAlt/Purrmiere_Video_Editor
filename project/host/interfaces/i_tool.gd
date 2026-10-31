extends RefCounted

const VERSION := 1
const IFACE := "ITool"


func id() -> String:
	return ""


func label() -> String:
	return id().capitalize()


func icon() -> String:
	return id()


func key() -> String:
	return ""


func cursor() -> String:
	return "arrow"


func timeline_press(_ctx: Dictionary) -> bool:
	return false


func timeline_motion(_ctx: Dictionary) -> bool:
	return false


func timeline_release(_ctx: Dictionary) -> bool:
	return false

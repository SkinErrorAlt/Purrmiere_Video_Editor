extends RefCounted

const VERSION := 1
const IFACE := "ITrackKind"


func id() -> String:
	return ""


func label() -> String:
	return id().capitalize()


func icon() -> String:
	return "film"


func default_height() -> float:
	return 54.0


func header_buttons() -> PackedStringArray:
	return PackedStringArray(["eye", "lock", "target"])


func paint_lane(_canvas: CanvasItem, _rect: Rect2, _ctx: Dictionary) -> void:
	pass


func item_kind() -> String:
	return "clip"

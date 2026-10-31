extends RefCounted

const VERSION := 1
const IFACE := "IPresetKind"


func id() -> String:
	return ""


func label() -> String:
	return id().capitalize()


func targets() -> PackedStringArray:
	return PackedStringArray()


func preview(_preset: Dictionary, _size: Vector2i) -> Image:
	return null


func apply(_preset: Dictionary, _target: Dictionary) -> bool:
	return false


func capture(_source: Dictionary) -> Dictionary:
	return {}

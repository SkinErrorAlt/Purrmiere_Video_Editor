extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const INTERP := "ease_both"
const EASE := "sine"

static var enabled: bool = true


static func applies(path: String) -> bool:
	return path == AnimTime.MEDIA_SPEED_PATH or path == AnimTime.SPEED_PATH or AnimTime.is_speed_path(path)


static func fresh(path: String, old: Dictionary, next: Dictionary) -> Dictionary:
	if not enabled or not applies(path) or not AnimProp.is_animated(next):
		return next
	var before: Array[Dictionary] = AnimProp.keys(old) if AnimProp.is_animated(old) else ([] as Array[Dictionary])
	var after: Array[Dictionary] = AnimProp.keys(next)
	if after.size() <= before.size():
		return next
	var out: Dictionary = next
	for k: Dictionary in after:
		var t: float = float(k.get("t", 0.0))
		if _has_time(before, t):
			continue
		if String(k.get("i", "")) != INTERP or k.has("ease") or k.has("dir"):
			continue
		out = AnimProp.set_key_fields(out, t, {"ease": EASE})
	return out


static func _has_time(list: Array[Dictionary], t: float) -> bool:
	for k: Dictionary in list:
		if absf(float(k.get("t", 0.0)) - t) <= AnimProp.KEY_TOLERANCE:
			return true
	return false

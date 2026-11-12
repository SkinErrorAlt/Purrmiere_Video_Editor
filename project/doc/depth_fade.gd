extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const PlaneDepth := preload("res://doc/plane_depth.gd")
const KEY := "depth_fade"
const ON := "on"
const NEAR := "near"
const FAR := "far"
const SOFTNESS := "softness"
const REVERSE := "reverse"
const PROPS: PackedStringArray = ["near", "far", "softness", "reverse"]
const DEFAULT_NEAR := 1.0
const DEFAULT_FAR := 3.0
const DEFAULT_SOFTNESS := 0.0


static func of(e: Dictionary) -> Dictionary:
	var d: Variant = e.get(KEY, null)
	return d if d is Dictionary else {}


static func is_on(e: Dictionary) -> bool:
	return bool(of(e).get(ON, false))


static func default_of(key: String) -> Variant:
	if key == NEAR:
		return DEFAULT_NEAR
	if key == FAR:
		return DEFAULT_FAR
	if key == REVERSE:
		return false
	return DEFAULT_SOFTNESS


static func made(near: float, far: float) -> Dictionary:
	return {ON: true, NEAR: AnimProp.make(near), FAR: AnimProp.make(far), SOFTNESS: AnimProp.make(DEFAULT_SOFTNESS), REVERSE: AnimProp.make(false)}


static func switched(e: Dictionary, on: bool, near: float, far: float) -> Dictionary:
	var cur: Dictionary = of(e)
	if cur.is_empty():
		var fresh: Dictionary = made(near, far)
		fresh[ON] = on
		return fresh
	var out: Dictionary = cur.duplicate(true)
	out[ON] = on
	for k: String in PROPS:
		if not (out.get(k) is Dictionary):
			out[k] = AnimProp.make(near if k == NEAR else (far if k == FAR else default_of(k)))
	return out


static func path_of(uid: String, key: String) -> String:
	return "effects." + uid + "." + KEY + "." + key


static func split(path: String) -> PackedStringArray:
	var parts: PackedStringArray = path.split(".")
	if parts.size() != 4 or parts[0] != "effects" or parts[2] != KEY or not PROPS.has(parts[3]):
		return PackedStringArray()
	return PackedStringArray([parts[1], parts[3]])


static func get_prop(e: Dictionary, key: String) -> Dictionary:
	var v: Variant = of(e).get(key, null)
	return v if v is Dictionary else AnimProp.make(default_of(key))


static func stored(e: Dictionary, key: String) -> Dictionary:
	var v: Variant = of(e).get(key, null)
	return v if v is Dictionary else {}


static func set_prop(e: Dictionary, key: String, anim: Dictionary) -> bool:
	if not PROPS.has(key):
		return false
	if not (e.get(KEY) is Dictionary):
		e[KEY] = {ON: false}
	(e[KEY] as Dictionary)[key] = anim
	return true


static func erase_prop(e: Dictionary, key: String) -> void:
	if not (e.get(KEY) is Dictionary):
		return
	var d: Dictionary = e[KEY]
	d.erase(key)
	if bool(d.get(ON, false)):
		return
	for k: String in PROPS:
		if d.has(k):
			return
	e.erase(KEY)


static func paths(e: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var d: Dictionary = of(e)
	for k: String in PROPS:
		if d.get(k) is Dictionary:
			out.append(path_of(str(e.get("uid", "")), k))
	return out


static func source_index(effects: Array, index: int, registry: Object) -> int:
	if registry == null:
		return -1
	for k: int in range(mini(index, effects.size()) - 1, -1, -1):
		var other: Dictionary = effects[k]
		if not bool(other.get("enabled", true)):
			continue
		var def: Variant = registry.call("get_def", str(other.get("id", "")))
		if def is Dictionary and PlaneDepth.declares(def):
			return k
	return -1


static func source_uid(effects: Array, index: int, registry: Object) -> String:
	if index < 0 or index >= effects.size() or not is_on(effects[index]):
		return ""
	var k: int = source_index(effects, index, registry)
	return str((effects[k] as Dictionary).get("uid", "")) if k >= 0 else ""

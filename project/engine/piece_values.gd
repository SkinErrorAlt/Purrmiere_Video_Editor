extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const RangeValues := preload("res://doc/range_values.gd")
const PER_PIECE: PackedStringArray = ["gravity", "weight", "knock", "fly", "spin", "spread"]


static func ranges_of(e: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var params: Variant = e.get("params", null)
	if not (params is Dictionary):
		return out
	for k: String in PER_PIECE:
		var p: Variant = (params as Dictionary).get(k, null)
		if p is Dictionary and AnimProp.is_range(p):
			out[k] = p
	return out


static func stamp(ranges: Dictionary) -> String:
	if ranges.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for k: String in PER_PIECE:
		if ranges.has(k):
			parts.append(k + "=" + RangeValues.stamp(ranges[k]))
	return "|".join(parts)


static func value(ranges: Dictionary, key: String, index: int, fallback: float) -> float:
	if not ranges.has(key):
		return fallback
	return RangeValues.piece_value(ranges[key], index, fallback)


static func arrays(overrides: Dictionary, ranges: Dictionary, n: int, gravity: float, weight: float = 1.0) -> Dictionary:
	var masses := PackedFloat32Array()
	var gravities := PackedFloat32Array()
	masses.resize(n)
	gravities.resize(n)
	for i: int in n:
		masses[i] = maxf(0.0, value(ranges, "weight", i, weight))
		gravities[i] = maxf(0.0, value(ranges, "gravity", i, gravity))
	for k: Variant in overrides.keys():
		var idx: int = int(String(k))
		if idx < 0 or idx >= n:
			continue
		var ov: Dictionary = overrides[k] if overrides[k] is Dictionary else {}
		if ov.has("weight"):
			masses[idx] = maxf(0.0, float(ov["weight"]))
		if ov.has("gravity"):
			gravities[idx] = maxf(0.0, float(ov["gravity"]))
	return {"masses": masses, "gravities": gravities}

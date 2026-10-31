extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const MODES: PackedStringArray = ["add", "subtract", "intersect"]
const KEYS: PackedStringArray = ["mode", "centre", "size", "rotation", "feather", "expand", "opacity", "invert", "points"]
const BOX_KINDS: PackedStringArray = ["rect", "ellipse"]
const POLY_KINDS: PackedStringArray = ["polygon", "draw", "picture"]
const KIND_LABELS: Dictionary = {"rect": "Rectangle", "ellipse": "Ellipse", "polygon": "Shape", "draw": "Shape", "picture": "Shape"}
const DEFAULT_BOX := Rect2(0.25, 0.25, 0.5, 0.5)
const MIN_POINTS := 3


static func make(kind: String, id: String) -> Dictionary:
	return {"id": id, "kind": kind, "mode": "add", "centre": [0.5, 0.5], "size": [0.5, 0.5], "rotation": 0.0, "feather": 0.0, "expand": 0.0, "opacity": 1.0, "invert": false, "enabled": true}


static func make_polygon(id: String, pts: Variant) -> Dictionary:
	return {"id": id, "kind": "polygon", "mode": "add", "points": flat_points(pts), "rotation": 0.0, "feather": 0.0, "expand": 0.0, "opacity": 1.0, "invert": false, "enabled": true}


static func is_box(m: Dictionary) -> bool:
	return BOX_KINDS.has(str(m.get("kind", "")))


static func is_polygon(m: Dictionary) -> bool:
	return not is_box(m)


static func label_of(m: Dictionary, index: int) -> String:
	var custom: String = str(m.get("label", ""))
	if not custom.is_empty():
		return custom
	return "Mask " + str(index + 1) + " (" + String(KIND_LABELS.get(str(m.get("kind", "")), "Shape")) + ")"


static func index_of(masks: Array, id: String) -> int:
	for i: int in masks.size():
		if str((masks[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


static func _flat(v: Variant) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if v is Array:
		for e: Variant in v:
			if e is Array:
				for f: Variant in e:
					out.append(float(f))
			else:
				out.append(float(e))
	return out


static func _nested(v: Variant) -> bool:
	return v is Array and not (v as Array).is_empty() and (v as Array)[0] is Array


static func flat_points(v: Variant) -> Array:
	var out: Array = []
	for f: float in _flat(v):
		out.append(f)
	return out


static func pairs_of(flat: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in flat.size() / 2:
		out.append(Vector2(float(flat[i * 2]), float(flat[i * 2 + 1])))
	return out


static func flat_of(pts: PackedVector2Array) -> Array:
	var out: Array = []
	for p: Vector2 in pts:
		out.append(p.x)
		out.append(p.y)
	return out


static func key_time(m: Dictionary, key: String, t: float, dur: float) -> float:
	if not m.has(AnimTime.SPEEDS_FIELD):
		return t
	return AnimTime.holder_time(m, key, t, dur)


static func points_box(m: Dictionary, t: float, dur: float, fps: float) -> Rect2:
	var raw: Variant = m.get("points", null)
	var arr: Variant = AnimProp.evaluate(raw, key_time(m, "points", t, dur), dur, fps) if raw is Dictionary else raw
	var flat: PackedFloat64Array = _flat(arr)
	var kind: String = str(m.get("kind", ""))
	if _nested(arr) or flat.size() >= 8:
		var lo: Vector2 = Vector2(INF, INF)
		var hi: Vector2 = Vector2(-INF, -INF)
		for i: int in flat.size() / 2:
			var p: Vector2 = Vector2(flat[i * 2], flat[i * 2 + 1])
			lo = lo.min(p)
			hi = hi.max(p)
		if lo.x <= hi.x and lo.y <= hi.y:
			return Rect2(lo, hi - lo)
		return DEFAULT_BOX
	if flat.size() >= 4:
		if kind == "ellipse":
			return Rect2(flat[0] - absf(flat[2]), flat[1] - absf(flat[3]), absf(flat[2]) * 2.0, absf(flat[3]) * 2.0)
		var a: Vector2 = Vector2(flat[0], flat[1])
		var b: Vector2 = Vector2(flat[2], flat[3])
		return Rect2(a.min(b), (b - a).abs())
	return DEFAULT_BOX


static func _vec2(v: Variant, t: float, dur: float, fps: float, fallback: Vector2) -> Vector2:
	if v is Dictionary:
		return AnimProp.evaluate_vec2(v, t, dur, fps)
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback


static func box_at(m: Dictionary, t: float, dur: float, fps: float) -> Rect2:
	var legacy: Rect2 = DEFAULT_BOX
	if not m.has("centre") or not m.has("size"):
		legacy = points_box(m, t, dur, fps)
	var centre: Vector2 = _vec2(m.get("centre", null), key_time(m, "centre", t, dur), dur, fps, legacy.get_center())
	var size: Vector2 = _vec2(m.get("size", null), key_time(m, "size", t, dur), dur, fps, legacy.size).abs()
	return Rect2(centre - size * 0.5, size)


static func points_at(m: Dictionary, t: float, dur: float, fps: float) -> PackedVector2Array:
	var raw: Variant = m.get("points", null)
	var arr: Variant = AnimProp.evaluate(raw, key_time(m, "points", t, dur), dur, fps) if raw is Dictionary else raw
	return pairs_of(flat_points(arr))


static func default_points(m: Dictionary) -> Array:
	var raw: Variant = m.get("points", null)
	if raw is Dictionary:
		return flat_points(AnimProp.static_value(raw))
	if raw != null:
		var held: Array = flat_points(raw)
		if not held.is_empty():
			return held
	var box: Rect2 = box_at(m, 0.0, 1.0, 0.0)
	return [box.position.x, box.position.y, box.end.x, box.position.y, box.end.x, box.end.y, box.position.x, box.end.y]


static func default_value(m: Dictionary, key: String) -> Variant:
	if key == "mode":
		return "add"
	if key == "invert":
		return false
	if key == "opacity":
		return 1.0
	if key == "points":
		return default_points(m)
	if key == "centre":
		return [points_box(m, 0.0, 1.0, 0.0).get_center().x, points_box(m, 0.0, 1.0, 0.0).get_center().y]
	if key == "size":
		var box: Rect2 = points_box(m, 0.0, 1.0, 0.0)
		return [box.size.x, box.size.y]
	return 0.0


static func _flat_value(v: Variant) -> Variant:
	return flat_points(v) if v is Array else v


static func flatten_prop(anim: Dictionary) -> Dictionary:
	var out: Dictionary = anim.duplicate(true)
	if out.has("v"):
		out["v"] = _flat_value(out["v"])
	if out.has("base"):
		out["base"] = _flat_value(out["base"])
	for l: Variant in out.get("layers", []):
		var layer: Dictionary = l
		if str(layer.get("type", "")) != "keys":
			continue
		for k: Variant in layer.get("keys", []):
			var kd: Dictionary = k
			if kd.has("v"):
				kd["v"] = _flat_value(kd["v"])
	return out


static func point_count(anim: Dictionary) -> int:
	var base: Array = flat_points(AnimProp.static_value(anim))
	if not base.is_empty():
		return base.size() / 2
	for k: Dictionary in AnimProp.keys(anim):
		var kv: Array = flat_points(k.get("v", []))
		if not kv.is_empty():
			return kv.size() / 2
	return 0


static func _with_point(flat: Array, at: int) -> Array:
	var n: int = flat.size() / 2
	if n < 2:
		return flat
	var i: int = clampi(at, 0, n)
	var a: int = (i - 1 + n) % n
	var b: int = i % n
	var mx: float = (float(flat[a * 2]) + float(flat[b * 2])) * 0.5
	var my: float = (float(flat[a * 2 + 1]) + float(flat[b * 2 + 1])) * 0.5
	var out: Array = flat.duplicate()
	out.insert(i * 2, my)
	out.insert(i * 2, mx)
	return out


static func _without_point(flat: Array, at: int) -> Array:
	var n: int = flat.size() / 2
	if n <= MIN_POINTS or at < 0 or at >= n:
		return flat
	var out: Array = flat.duplicate()
	out.remove_at(at * 2)
	out.remove_at(at * 2)
	return out


static func _edited(flat: Array, insert: bool, at: int) -> Array:
	return _with_point(flat, at) if insert else _without_point(flat, at)


static func _edit_arrays(anim: Dictionary, insert: bool, at: int) -> Dictionary:
	var out: Dictionary = flatten_prop(anim)
	if out.get("v") is Array:
		out["v"] = _edited(out["v"], insert, at)
	if out.get("base") is Array:
		out["base"] = _edited(out["base"], insert, at)
	for l: Variant in out.get("layers", []):
		var layer: Dictionary = l
		if str(layer.get("type", "")) != "keys":
			continue
		for k: Variant in layer.get("keys", []):
			var kd: Dictionary = k
			if kd.get("v") is Array:
				kd["v"] = _edited(kd["v"], insert, at)
	return out


static func insert_point(anim: Dictionary, at: int, want: Vector2) -> Dictionary:
	var out: Dictionary = _edit_arrays(anim, true, at)
	if AnimProp.is_animated(out) or not (out.get("v") is Array):
		return out
	var a: Array = out["v"]
	var i: int = clampi(at, 0, a.size() / 2 - 1)
	if i * 2 + 1 < a.size():
		a[i * 2] = want.x
		a[i * 2 + 1] = want.y
	return out


static func remove_point(anim: Dictionary, at: int) -> Dictionary:
	return _edit_arrays(anim, false, at)


static func get_param(masks: Array, id: String, key: String) -> Dictionary:
	var i: int = index_of(masks, id)
	if i < 0 or not KEYS.has(key):
		return {}
	var m: Dictionary = masks[i]
	var v: Variant = m.get(key, null)
	if v is Dictionary and ((v as Dictionary).has("v") or (v as Dictionary).has("a")):
		return v
	if v == null:
		return AnimProp.make(default_value(m, key))
	return AnimProp.make(v)


static func set_param(masks: Array, id: String, key: String, anim: Dictionary) -> bool:
	var i: int = index_of(masks, id)
	if i < 0 or not KEYS.has(key):
		return false
	var m: Dictionary = masks[i]
	m[key] = flatten_prop(anim) if key == "points" else anim.duplicate(true)
	return true


static func erase_param(masks: Array, id: String, key: String) -> void:
	var i: int = index_of(masks, id)
	if i >= 0:
		(masks[i] as Dictionary).erase(key)


static func param_paths(masks: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for m: Variant in masks:
		var md: Dictionary = m
		for key: String in KEYS:
			if md.get(key) is Dictionary:
				out.append("masks." + str(md.get("id", "")) + "." + key)
	return out


static func value_at(m: Dictionary, key: String, t: float, dur: float, fps: float) -> Variant:
	var v: Variant = m.get(key, null)
	if v is Dictionary and ((v as Dictionary).has("v") or (v as Dictionary).has("a")):
		return AnimProp.evaluate(v, key_time(m, key, t, dur), dur, fps)
	if v == null:
		return default_value(m, key)
	return v

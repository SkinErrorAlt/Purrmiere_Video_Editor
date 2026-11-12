extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const MODES: PackedStringArray = ["add", "subtract", "intersect"]
const KEYS: PackedStringArray = ["mode", "centre", "size", "rotation", "feather", "expand", "opacity", "invert", "points", "handles", "channel", "low", "high"]
const BOX_KINDS: PackedStringArray = ["rect", "ellipse", "picture"]
const POLY_KINDS: PackedStringArray = ["polygon", "draw"]
const KIND_LABELS: Dictionary = {"rect": "Rectangle", "ellipse": "Ellipse", "polygon": "Shape", "draw": "Drawn", "picture": "Picture", "object": "Object"}
const PICTURE_CHANNELS: PackedStringArray = ["luma", "alpha", "red", "green", "blue"]
const PICTURE_CHANNEL_LABELS: PackedStringArray = ["Brightness", "See through (alpha)", "Red", "Green", "Blue"]
const PICTURE_EXTS: PackedStringArray = ["png", "jpg", "jpeg", "webp", "bmp", "tga", "exr", "hdr", "svg"]
const DEFAULT_BOX := Rect2(0.25, 0.25, 0.5, 0.5)
const MIN_POINTS := 3
const CURVE_MIN_STEPS := 4
const CURVE_MAX_STEPS := 24
const CURVE_STEP_SCALE := 64.0
const STRAIGHT := 0.0005


static func make(kind: String, id: String) -> Dictionary:
	return {"id": id, "kind": kind, "mode": "add", "centre": [0.5, 0.5], "size": [0.5, 0.5], "rotation": 0.0, "feather": 0.0, "expand": 0.0, "opacity": 1.0, "invert": false, "enabled": true}


static func make_polygon(id: String, pts: Variant) -> Dictionary:
	return {"id": id, "kind": "polygon", "mode": "add", "points": flat_points(pts), "rotation": 0.0, "feather": 0.0, "expand": 0.0, "opacity": 1.0, "invert": false, "enabled": true}


## A mask drawn by hand: the stroke thinned to the points that matter and given smooth curves through them.
static func make_drawn(id: String, stroke: PackedVector2Array, tolerance: float = 0.002) -> Dictionary:
	var pts: PackedVector2Array = simplify(stroke, tolerance, true)
	var m: Dictionary = make_polygon(id, flat_of(pts))
	m["kind"] = "draw"
	m["handles"] = flat_of(smooth_handles(pts))
	return m


## A mask made from a picture file: its brightness (or alpha, or one colour) cuts the clip, placed in a box.
static func make_picture(id: String, path: String, aspect: float = 1.0) -> Dictionary:
	var m: Dictionary = make("picture", id)
	m["image"] = path
	m["channel"] = "luma"
	m["low"] = 0.0
	m["high"] = 1.0
	var w: float = 1.0
	var h: float = 1.0
	if aspect > 1.0:
		h = 1.0 / aspect
	elif aspect > 0.0:
		w = aspect
	m["size"] = [w, h]
	return m


static func is_picture(m: Dictionary) -> bool:
	return str(m.get("kind", "")) == "picture"


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
	if key == "opacity" or key == "high":
		return 1.0
	if key == "channel":
		return "luma"
	if key == "points":
		return default_points(m)
	if key == "handles":
		return zero_handles(default_points(m).size() / 2)
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


static func _with_point(flat: Array, at: int, frac: float = 0.5) -> Array:
	var n: int = flat.size() / 2
	if n < 2:
		return flat
	var i: int = clampi(at, 0, n)
	var a: int = (i - 1 + n) % n
	var b: int = i % n
	var mx: float = lerpf(float(flat[a * 2]), float(flat[b * 2]), frac)
	var my: float = lerpf(float(flat[a * 2 + 1]), float(flat[b * 2 + 1]), frac)
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


static func _edited(flat: Array, insert: bool, at: int, frac: float = 0.5) -> Array:
	return _with_point(flat, at, frac) if insert else _without_point(flat, at)


static func _edit_arrays(anim: Dictionary, insert: bool, at: int, frac: float = 0.5) -> Dictionary:
	var out: Dictionary = flatten_prop(anim)
	if out.get("v") is Array:
		out["v"] = _edited(out["v"], insert, at, frac)
	if out.get("base") is Array:
		out["base"] = _edited(out["base"], insert, at, frac)
	for l: Variant in out.get("layers", []):
		var layer: Dictionary = l
		if str(layer.get("type", "")) != "keys":
			continue
		for k: Variant in layer.get("keys", []):
			var kd: Dictionary = k
			if kd.get("v") is Array:
				kd["v"] = _edited(kd["v"], insert, at, frac)
	return out


## Inserts a point before index `at`. On an animated shape every key gets it at the same fraction `frac` along its
## own edge, so the new point sits where it was clicked on this frame and keeps its place on the others.
static func insert_point(anim: Dictionary, at: int, want: Vector2, frac: float = 0.5) -> Dictionary:
	var out: Dictionary = _edit_arrays(anim, true, at, clampf(frac, 0.0, 1.0))
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
	m[key] = flatten_prop(anim) if key == "points" or key == "handles" else anim.duplicate(true)
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


static func handles_at(m: Dictionary, t: float, dur: float, fps: float) -> PackedVector2Array:
	var raw: Variant = m.get("handles", null)
	if raw == null:
		return PackedVector2Array()
	var arr: Variant = AnimProp.evaluate(raw, key_time(m, "handles", t, dur), dur, fps) if raw is Dictionary else raw
	return pairs_of(flat_points(arr))


static func zero_handles(points: int) -> Array:
	var out: Array = []
	for i: int in points * 4:
		out.append(0.0)
	return out


static func is_straight(handles: PackedVector2Array) -> bool:
	for h: Vector2 in handles:
		if h.length() > STRAIGHT:
			return false
	return true


static func segment_curved(handles: PackedVector2Array, i: int, j: int) -> bool:
	if handles.size() < maxi(i, j) * 2 + 2:
		return false
	return handles[i * 2 + 1].length() > STRAIGHT or handles[j * 2].length() > STRAIGHT


static func bezier_steps(a: Vector2, c1: Vector2, c2: Vector2, b: Vector2) -> int:
	var span: float = a.distance_to(c1) + c1.distance_to(c2) + c2.distance_to(b)
	return clampi(int(ceil(span * CURVE_STEP_SCALE)), CURVE_MIN_STEPS, CURVE_MAX_STEPS)


static func curve_walk(pts: PackedVector2Array, handles: PackedVector2Array) -> Dictionary:
	var n: int = pts.size()
	var owners: PackedInt32Array = PackedInt32Array()
	if n < 2 or handles.size() < n * 2 or is_straight(handles):
		for i0: int in n:
			owners.append(i0)
		return {"path": pts, "owners": owners}
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in n:
		var j: int = (i + 1) % n
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[j]
		out.append(a)
		owners.append(i)
		if not segment_curved(handles, i, j):
			continue
		var c1: Vector2 = a + handles[i * 2 + 1]
		var c2: Vector2 = b + handles[j * 2]
		var steps: int = bezier_steps(a, c1, c2, b)
		for k: int in range(1, steps):
			out.append(a.bezier_interpolate(c1, c2, b, float(k) / float(steps)))
			owners.append(i)
	return {"path": out, "owners": owners}


static func curve_path(pts: PackedVector2Array, handles: PackedVector2Array) -> PackedVector2Array:
	return curve_walk(pts, handles)["path"]


static func split_segment(a: Vector2, c1: Vector2, c2: Vector2, b: Vector2) -> Dictionary:
	var p01: Vector2 = (a + c1) * 0.5
	var p12: Vector2 = (c1 + c2) * 0.5
	var p23: Vector2 = (c2 + b) * 0.5
	var q0: Vector2 = (p01 + p12) * 0.5
	var q1: Vector2 = (p12 + p23) * 0.5
	var mid: Vector2 = (q0 + q1) * 0.5
	return {"point": mid, "out_a": p01 - a, "in_mid": q0 - mid, "out_mid": q1 - mid, "in_b": p23 - b}


static func _handles_with(flat: Array, at: int, points: int) -> Array:
	var out: Array = flat.duplicate() if flat.size() >= points * 4 else zero_handles(points)
	var i: int = clampi(at, 0, points)
	for k: int in 4:
		out.insert(i * 4, 0.0)
	return out


static func _handles_without(flat: Array, at: int, points: int) -> Array:
	if flat.size() < points * 4 or at < 0 or at >= points:
		return flat
	var out: Array = flat.duplicate()
	for k: int in 4:
		out.remove_at(at * 4)
	return out


static func _handles_edited(anim: Dictionary, insert: bool, at: int, points: int) -> Dictionary:
	var out: Dictionary = flatten_prop(anim)
	if out.get("v") is Array:
		out["v"] = _handles_with(out["v"], at, points) if insert else _handles_without(out["v"], at, points)
	if out.get("base") is Array:
		out["base"] = _handles_with(out["base"], at, points) if insert else _handles_without(out["base"], at, points)
	for l: Variant in out.get("layers", []):
		var layer: Dictionary = l
		if str(layer.get("type", "")) != "keys":
			continue
		for k: Variant in layer.get("keys", []):
			var kd: Dictionary = k
			if kd.get("v") is Array:
				kd["v"] = _handles_with(kd["v"], at, points) if insert else _handles_without(kd["v"], at, points)
	return out


static func set_handle(anim: Dictionary, at: int, side: int, to: Vector2, points: int) -> Dictionary:
	var out: Dictionary = flatten_prop(anim)
	if not (out.get("v") is Array):
		return out
	var a: Array = out["v"]
	if a.size() < points * 4:
		a = zero_handles(points)
	var i: int = at * 4 + (0 if side == 0 else 2)
	if i + 1 >= a.size():
		return out
	a[i] = to.x
	a[i + 1] = to.y
	out["v"] = a
	return out


static func insert_curve_point(points: Dictionary, handles: Dictionary, at: int, want: Vector2, frac: float = 0.5) -> Dictionary:
	var count: int = point_count(points)
	if count < 2:
		return {}
	var i: int = clampi(at, 0, count)
	var a_at: int = (i - 1 + count) % count
	var b_at: int = i % count
	var pts: PackedVector2Array = pairs_of(flat_points(AnimProp.static_value(points)))
	var hs: PackedVector2Array = pairs_of(flat_points(AnimProp.static_value(handles))) if not handles.is_empty() else PackedVector2Array()
	var held: bool = not handles.is_empty() and not is_straight(hs)
	var curved: bool = held and not AnimProp.is_animated(points) and pts.size() == count and segment_curved(hs, a_at, b_at)
	var next_points: Dictionary = insert_point(points, i, want, frac)
	var next_handles: Dictionary = _handles_edited(handles, true, i, count) if held else {}
	if not curved:
		return {"points": next_points, "handles": next_handles}
	var split: Dictionary = split_segment(pts[a_at], pts[a_at] + hs[a_at * 2 + 1], pts[b_at] + hs[b_at * 2], pts[b_at])
	var flat: Array = flat_points(AnimProp.static_value(next_points))
	var mid: Vector2 = split["point"]
	if i * 2 + 1 < flat.size():
		flat[i * 2] = mid.x
		flat[i * 2 + 1] = mid.y
	next_points = AnimProp.make(flat)
	var b_now: int = (i + 1) % (count + 1)
	var a_now: int = a_at + 1 if a_at >= i else a_at
	next_handles = set_handle(next_handles, a_now, 1, split["out_a"], count + 1)
	next_handles = set_handle(next_handles, i, 0, split["in_mid"], count + 1)
	next_handles = set_handle(next_handles, i, 1, split["out_mid"], count + 1)
	next_handles = set_handle(next_handles, b_now, 0, split["in_b"], count + 1)
	return {"points": next_points, "handles": next_handles}


static func remove_curve_point(points: Dictionary, handles: Dictionary, at: int) -> Dictionary:
	var count: int = point_count(points)
	if count <= MIN_POINTS:
		return {}
	var hs: PackedVector2Array = pairs_of(flat_points(AnimProp.static_value(handles))) if not handles.is_empty() else PackedVector2Array()
	var kept: Dictionary = _handles_edited(handles, false, at, count) if not handles.is_empty() and not is_straight(hs) else {}
	return {"points": remove_point(points, at), "handles": kept}


## How far along the edge a to b the point nearest p lies, 0 to 1.
static func segment_frac(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	if len2 <= 1e-12:
		return 0.5
	return clampf((p - a).dot(ab) / len2, 0.0, 1.0)


## Thins a hand drawn stroke (Ramer, Douglas, Peucker) to the points that hold its shape within `tolerance`.
static func simplify(stroke: PackedVector2Array, tolerance: float, closed: bool = true) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in stroke:
		if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > tolerance * 0.25:
			pts.append(p)
	if closed and pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) <= tolerance:
		pts.remove_at(pts.size() - 1)
	if pts.size() <= MIN_POINTS:
		return pts
	var keep: PackedByteArray = PackedByteArray()
	keep.resize(pts.size())
	keep.fill(0)
	keep[0] = 1
	keep[pts.size() - 1] = 1
	var far_i: int = 0
	var far_d: float = -1.0
	for i: int in pts.size():
		var dd: float = pts[i].distance_to(pts[0])
		if dd > far_d:
			far_d = dd
			far_i = i
	keep[far_i] = 1
	var stack: Array[Vector2i] = [Vector2i(0, far_i), Vector2i(far_i, pts.size() - 1)]
	while not stack.is_empty():
		var span: Vector2i = stack.pop_back()
		if span.y - span.x < 2:
			continue
		var a: Vector2 = pts[span.x]
		var b: Vector2 = pts[span.y]
		var best: int = -1
		var best_d: float = tolerance
		for j: int in range(span.x + 1, span.y):
			var on: Vector2 = Geometry2D.get_closest_point_to_segment(pts[j], a, b)
			var d2: float = on.distance_to(pts[j])
			if d2 > best_d:
				best_d = d2
				best = j
		if best >= 0:
			keep[best] = 1
			stack.append(Vector2i(span.x, best))
			stack.append(Vector2i(best, span.y))
	var out: PackedVector2Array = PackedVector2Array()
	for k: int in pts.size():
		if keep[k] == 1:
			out.append(pts[k])
	if out.size() < MIN_POINTS:
		return pts
	if closed:
		var changed: bool = true
		while changed and out.size() > MIN_POINTS:
			changed = false
			for i2: int in out.size():
				var prev: Vector2 = out[(i2 - 1 + out.size()) % out.size()]
				var next: Vector2 = out[(i2 + 1) % out.size()]
				if Geometry2D.get_closest_point_to_segment(out[i2], prev, next).distance_to(out[i2]) <= tolerance:
					out.remove_at(i2)
					changed = true
					break
	return out


## Smooth curve handles through every point (the Catmull Rom curve written as bezier handles); `amount` 1 is the
## usual roundness, 0 is straight.
static func smooth_handles(pts: PackedVector2Array, amount: float = 1.0) -> PackedVector2Array:
	var n: int = pts.size()
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in n:
		var tangent: Vector2 = (pts[(i + 1) % n] - pts[(i - 1 + n) % n]) / 6.0 * amount
		out.append(-tangent)
		out.append(tangent)
	return out


## A shape grown to `n` points by splitting its longest edges, curves split exactly, so it looks the same.
static func grow_shape(pts: PackedVector2Array, hs: PackedVector2Array, n: int) -> Dictionary:
	var p: PackedVector2Array = pts.duplicate()
	var h: PackedVector2Array = hs.duplicate()
	var curved: bool = h.size() >= p.size() * 2 and not is_straight(h)
	if not curved:
		h = PackedVector2Array()
	while p.size() < n and p.size() >= 2:
		var best: int = 0
		var best_len: float = -1.0
		for i: int in p.size():
			var l: float = p[i].distance_to(p[(i + 1) % p.size()])
			if l > best_len:
				best_len = l
				best = i
		var j: int = (best + 1) % p.size()
		if curved:
			var sp: Dictionary = split_segment(p[best], p[best] + h[best * 2 + 1], p[j] + h[j * 2], p[j])
			h[best * 2 + 1] = sp["out_a"]
			h[j * 2] = sp["in_b"]
			p.insert(best + 1, sp["point"])
			h.insert(best * 2 + 2, sp["out_mid"])
			h.insert(best * 2 + 2, sp["in_mid"])
		else:
			p.insert(best + 1, p[best].lerp(p[j], 0.5))
	return {"points": p, "handles": h}


## Turns and, when it fits better, reverses a shape so its points line up with `ref` point for point, so a morph
## between them slides each point the shortest way instead of twisting the outline.
static func align_shape(ref: PackedVector2Array, pts: PackedVector2Array, hs: PackedVector2Array) -> Dictionary:
	var n: int = pts.size()
	if n != ref.size() or n < 2:
		return {"points": pts, "handles": hs}
	var best_cost: float = INF
	var best_shift: int = 0
	var best_rev: bool = false
	for rev: int in 2:
		for shift: int in n:
			var cost: float = 0.0
			for i: int in n:
				var k: int = (shift + (i if rev == 0 else -i) + n * 2) % n
				cost += ref[i].distance_squared_to(pts[k])
			if cost < best_cost:
				best_cost = cost
				best_shift = shift
				best_rev = rev == 1
	var op: PackedVector2Array = PackedVector2Array()
	var oh: PackedVector2Array = PackedVector2Array()
	var has_h: bool = hs.size() >= n * 2
	for i2: int in n:
		var k2: int = (best_shift + (i2 if not best_rev else -i2) + n * 2) % n
		op.append(pts[k2])
		if has_h:
			if best_rev:
				oh.append(hs[k2 * 2 + 1])
				oh.append(hs[k2 * 2])
			else:
				oh.append(hs[k2 * 2])
				oh.append(hs[k2 * 2 + 1])
	return {"points": op, "handles": oh}


static func _edge_weights(anim: Dictionary) -> PackedFloat64Array:
	var n: int = point_count(anim)
	var w: PackedFloat64Array = PackedFloat64Array()
	w.resize(n)
	w.fill(0.0)
	var values: Array = []
	var flat: Dictionary = flatten_prop(anim)
	if flat.get("v") is Array:
		values.append(flat["v"])
	for k: Dictionary in AnimProp.keys(flat):
		if k.get("v") is Array:
			values.append(k["v"])
	for v: Variant in values:
		var pts: PackedVector2Array = pairs_of(v)
		if pts.size() != n:
			continue
		for i: int in n:
			w[i] += pts[i].distance_to(pts[(i + 1) % n])
	return w


## Grows an animated shape to `n` points, the same new points in every key, so every key keeps matching.
static func grow_anim(points: Dictionary, handles: Dictionary, n: int) -> Dictionary:
	var p: Dictionary = flatten_prop(points)
	var h: Dictionary = flatten_prop(handles) if not handles.is_empty() else {}
	var guard: int = 0
	while point_count(p) < n and guard < 4096:
		guard += 1
		var count: int = point_count(p)
		var w: PackedFloat64Array = _edge_weights(p)
		var best: int = 0
		for i: int in w.size():
			if w[i] > w[best]:
				best = i
		p = insert_point(p, best + 1, Vector2.ZERO, 0.5)
		if not h.is_empty():
			h = _handles_edited(h, true, best + 1, count)
	return {"points": p, "handles": h}


## Keys a whole shape (points and their curves together) at `key_t`, even when it has a different number of points
## from the shape already there: the one with fewer points is grown to match, then the new one is lined up with the
## shape at that time, so the change morphs smoothly.
static func key_whole_shape(points: Dictionary, handles: Dictionary, key_t: float, dur: float, fps: float, pts: PackedVector2Array, hs: PackedVector2Array) -> Dictionary:
	var have: int = point_count(points)
	var n: int = maxi(have, pts.size())
	var grown: Dictionary = grow_anim(points, handles, n)
	var p_anim: Dictionary = grown["points"]
	var h_anim: Dictionary = grown["handles"]
	var shaped: Dictionary = grow_shape(pts, hs, n)
	var ref_raw: Variant = AnimProp.evaluate(p_anim, key_t, dur, fps)
	var ref: PackedVector2Array = pairs_of(flat_points(ref_raw))
	var lined: Dictionary = align_shape(ref, shaped["points"], shaped["handles"])
	var new_pts: PackedVector2Array = lined["points"]
	var new_hs: PackedVector2Array = lined["handles"]
	if new_hs.size() < n * 2:
		new_hs = PackedVector2Array()
		for i: int in n * 2:
			new_hs.append(Vector2.ZERO)
	if h_anim.is_empty():
		h_anim = AnimProp.make(zero_handles(n))
	for pk: Dictionary in AnimProp.keys(p_anim):
		var kt: float = float(pk.get("t", 0.0))
		if AnimProp.find_key(h_anim, kt) < 0:
			var held: Array = flat_points(AnimProp.evaluate(h_anim, kt, dur, fps))
			if held.size() < n * 4:
				held = zero_handles(n)
			h_anim = AnimProp.set_key(h_anim, kt, held)
	var p_out: Dictionary = AnimProp.set_key(p_anim, key_t, flat_of(new_pts))
	var h_out: Dictionary = AnimProp.set_key(h_anim, key_t, flat_of(new_hs))
	return {"points": flatten_prop(p_out), "handles": flatten_prop(h_out)}

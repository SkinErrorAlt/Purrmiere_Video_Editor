extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const CUT_KEY := "cut"
const TURN_PREFIX := "turn"
const REGION_MAX := 8
const MIN_SPAN := 0.02
const EDGE_NAMES: PackedStringArray = ["Left", "Top", "Right", "Bottom"]
const CORNER_NAMES: PackedStringArray = ["Top left", "Top right", "Bottom right", "Bottom left"]

static var _uniform_cache: Dictionary = {}


static func turn_key(i: int) -> String:
	return TURN_PREFIX + str(i)


static func numbers(cut: Variant) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if cut is Array or cut is PackedFloat64Array or cut is PackedFloat32Array:
		for v: Variant in cut:
			if v is float or v is int:
				out.append(float(v))
			else:
				return PackedFloat64Array()
	if out.size() != 4 and out.size() != 8:
		return PackedFloat64Array()
	return out


static func is_free(cut: Variant) -> bool:
	return numbers(cut).size() == 8


static func is_cut(cut: Variant) -> bool:
	var n: PackedFloat64Array = numbers(cut)
	if n.size() == 8:
		return true
	if n.size() == 4:
		for v: float in n:
			if absf(v) > 0.000001:
				return true
	return false


static func edges(cut: Variant) -> PackedFloat64Array:
	var n: PackedFloat64Array = numbers(cut)
	if n.size() == 4:
		return n
	if n.size() == 8:
		var box: Rect2 = bounds(quad(cut))
		return PackedFloat64Array([box.position.x, box.position.y, 1.0 - box.end.x, 1.0 - box.end.y])
	return PackedFloat64Array([0.0, 0.0, 0.0, 0.0])


static func quad(cut: Variant) -> PackedVector2Array:
	var n: PackedFloat64Array = numbers(cut)
	if n.size() == 8:
		return PackedVector2Array([Vector2(n[0], n[1]), Vector2(n[2], n[3]), Vector2(n[4], n[5]), Vector2(n[6], n[7])])
	var e: PackedFloat64Array = edges(cut)
	return quad_of_edges(e)


static func quad_of_edges(e: PackedFloat64Array) -> PackedVector2Array:
	var l: float = e[0]
	var t: float = e[1]
	var r: float = 1.0 - e[2]
	var b: float = 1.0 - e[3]
	return PackedVector2Array([Vector2(l, t), Vector2(r, t), Vector2(r, b), Vector2(l, b)])


static func bounds(q: PackedVector2Array) -> Rect2:
	if q.is_empty():
		return Rect2(0.0, 0.0, 1.0, 1.0)
	var lo: Vector2 = q[0]
	var hi: Vector2 = q[0]
	for p: Vector2 in q:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return Rect2(lo, hi - lo)


static func tidy_edges(e: PackedFloat64Array) -> Array:
	var l: float = clampf(e[0], 0.0, 1.0 - MIN_SPAN)
	var t: float = clampf(e[1], 0.0, 1.0 - MIN_SPAN)
	var r: float = clampf(e[2], 0.0, 1.0 - l - MIN_SPAN)
	var b: float = clampf(e[3], 0.0, 1.0 - t - MIN_SPAN)
	return [_r(l), _r(t), _r(r), _r(b)]


static func tidy_quad(q: PackedVector2Array) -> Array:
	var out: Array = []
	for p: Vector2 in q:
		out.append(_r(clampf(p.x, 0.0, 1.0)))
		out.append(_r(clampf(p.y, 0.0, 1.0)))
	return out


static func _r(v: float) -> float:
	return snappedf(v, 0.0001)


static func as_edges(cut: Variant) -> Variant:
	if not is_cut(cut):
		return null
	return tidy_edges(edges(cut))


static func as_free(cut: Variant) -> Array:
	return tidy_quad(quad(cut))


static func inside(q: PackedVector2Array, p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, q)


static func raw_list(text: String) -> Array:
	var parsed: Variant = JSON.parse_string(text.strip_edges())
	return parsed if parsed is Array else []


static func crops_text(e: Dictionary) -> String:
	var raw: Variant = (e.get("params", {}) as Dictionary).get("crops", null)
	if raw is Dictionary:
		return String(AnimProp.static_value(raw))
	return ""


static func cut_of(e: Dictionary, index: int) -> Variant:
	var list: Array = raw_list(crops_text(e))
	if index < 0 or index >= list.size() or not (list[index] is Dictionary):
		return null
	return (list[index] as Dictionary).get(CUT_KEY, null)


static func text_with_cut(text: String, index: int, cut: Variant) -> String:
	var list: Array = raw_list(text)
	if index < 0 or index >= list.size() or not (list[index] is Dictionary):
		return text
	var d: Dictionary = list[index]
	if cut == null or not is_cut(cut):
		d.erase(CUT_KEY)
	else:
		d[CUT_KEY] = cut
	return JSON.stringify(list)


static func carry(into: Dictionary, raw: Variant) -> void:
	if raw is Dictionary and (raw as Dictionary).has(CUT_KEY) and is_cut((raw as Dictionary)[CUT_KEY]):
		into[CUT_KEY] = (raw as Dictionary)[CUT_KEY]


static func fill_uniforms(values: Dictionary, text: String) -> void:
	if not _uniform_cache.has(text):
		if _uniform_cache.size() > 256:
			_uniform_cache.clear()
		var made: Dictionary = {}
		_make_uniforms(made, text)
		_uniform_cache[text] = made
	values.merge(_uniform_cache[text], true)


static func _make_uniforms(values: Dictionary, text: String) -> void:
	var list: Array = raw_list(text)
	var bits: int = 0
	for i: int in REGION_MAX:
		var q: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
		if i < list.size() and list[i] is Dictionary:
			var cut: Variant = (list[i] as Dictionary).get(CUT_KEY, null)
			if is_cut(cut):
				bits |= 1 << i
				q = quad(cut)
		values["cut_a" + str(i)] = Vector4(q[0].x, q[0].y, q[1].x, q[1].y)
		values["cut_b" + str(i)] = Vector4(q[2].x, q[2].y, q[3].x, q[3].y)
	values["cut_on"] = bits


static func region_frame(b: Dictionary, crop_rect: Rect2) -> Transform2D:
	var box: Rect2 = b.get("box", Rect2(0.0, 0.0, 1.0, 1.0))
	var src: Rect2 = b.get("source", crop_rect)
	var cs: Vector2 = Vector2(maxf(crop_rect.size.x, 0.000001), maxf(crop_rect.size.y, 0.000001))
	var la: Vector2 = (src.position - crop_rect.position) / cs
	var lb: Vector2 = (src.end - crop_rect.position) / cs
	var span: Vector2 = Vector2(maxf(lb.x - la.x, 0.000001), maxf(lb.y - la.y, 0.000001))
	var k: Vector2 = box.size / span
	var local: Transform2D = Transform2D(Vector2(k.x, 0.0), Vector2(0.0, k.y), box.position - la * k)
	return turned(b, box.get_center()) * local


static func turned(b: Dictionary, centre: Vector2) -> Transform2D:
	var turn: float = float(b.get("turn", 0.0))
	if absf(turn) < 0.000001:
		return Transform2D.IDENTITY
	var aspect: float = maxf(float(b.get("aspect", 1.0)), 0.000001)
	var to_px: Transform2D = Transform2D(Vector2(aspect, 0.0), Vector2(0.0, 1.0), -centre * Vector2(aspect, 1.0))
	var spin: Transform2D = Transform2D(deg_to_rad(turn), Vector2.ZERO)
	return to_px.affine_inverse() * spin * to_px

extends RefCounted

const TextDecode := preload("res://doc/text_decode.gd")
const PATH_SHAPES: PackedStringArray = ["none", "arc", "circle", "wave", "points", "ellipse", "spiral", "polygon"]
const PATH_LABELS: PackedStringArray = ["Straight", "Arc", "Circle", "Wave", "A drawn path", "Oval", "Spiral", "Polygon"]
const CLOSED_SHAPES: PackedStringArray = ["circle", "ellipse", "polygon"]
const BLEND_STEPS := 240
const TILT_MAX := 85.0
const SLANT_MAX := 70.0
const COUNTER_FORMATS: PackedStringArray = ["number", "thousands", "percent", "time", "time_long"]
const COUNTER_LABELS: PackedStringArray = ["1234.5", "1,234.5", "50%", "1:05", "0:01:05"]
const CIRCLE_STEPS := 180
const CURVE_STEPS := 120
const POINT_MIN := 2
const BEND_MAX := 200.0
const SIZE_MAX := 400.0
const WAVES_MIN := 0.1
const WAVES_MAX := 20.0
const COUNT_MAX := 9999.0
const TOKENS: PackedStringArray = ["{value}", "{drive}"]


static func defaults() -> Dictionary:
	return {
		"path_shape": "none",
		"path_start": 0.0,
		"path_size": 30.0,
		"path_bend": 40.0,
		"path_waves": 1.0,
		"path_turn": true,
		"path_points": [],
		"path_amount": 100.0,
		"path_shape_b": "none",
		"path_mix": 0.0,
		"path_aspect": 60.0,
		"path_sides": 6.0,
		"tilt": 0.0,
		"slant": 0.0,
		"reveal_count": -1.0,
		"counter_on": false,
		"counter_value": 0.0,
		"counter_decimals": 0,
		"counter_format": "number",
		"counter_prefix": "",
		"counter_suffix": "",
	}


static func plain(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("v"):
			return plain(d["v"])
		if d.has("base"):
			return plain(d["base"])
		return null
	return v


static func get_value(props: Dictionary, key: String) -> Variant:
	var v: Variant = plain(props.get(key, null))
	return defaults()[key] if v == null else v


static func path_shape(props: Dictionary) -> String:
	var s: Variant = get_value(props, "path_shape")
	var shape: String = String(s) if s is String else "none"
	return shape if PATH_SHAPES.has(shape) else "none"


static func shape_b(props: Dictionary) -> String:
	var s: Variant = get_value(props, "path_shape_b")
	var shape: String = String(s) if s is String else "none"
	if shape == "points" or not PATH_SHAPES.has(shape):
		return "none"
	return shape


static func mix_of(props: Dictionary) -> float:
	if shape_b(props) == "none":
		return 0.0
	return clampf(float(get_value(props, "path_mix")) / 100.0, 0.0, 1.0)


static func amount_of(props: Dictionary) -> float:
	return clampf(float(get_value(props, "path_amount")) / 100.0, 0.0, 1.0)


static func _shape_live(props: Dictionary, shape: String) -> bool:
	if shape == "points":
		return flat(get_value(props, "path_points")).size() >= 4
	return shape != "none"


static func path_on(props: Dictionary) -> bool:
	if _shape_live(props, path_shape(props)):
		return true
	return mix_of(props) > 0.0


static func tilt_on(props: Dictionary) -> bool:
	return absf(float(get_value(props, "tilt"))) > 0.001 or absf(float(get_value(props, "slant"))) > 0.001


static func centring(props: Dictionary) -> float:
	var a: float = 0.0 if CLOSED_SHAPES.has(path_shape(props)) or path_shape(props) == "points" else 1.0
	if path_shape(props) == "arc" or path_shape(props) == "wave":
		a = 1.0
	var m: float = mix_of(props)
	if m <= 0.0:
		return a
	var b: float = 0.0 if CLOSED_SHAPES.has(shape_b(props)) else 1.0
	return lerpf(a, b, m)


static func counter_on(props: Dictionary) -> bool:
	return bool(get_value(props, "counter_on"))


static func reveal_count(props: Dictionary) -> float:
	var v: Variant = plain(props.get("reveal_count", null))
	return float(v) if v is float or v is int else -1.0


static func count_on(props: Dictionary) -> bool:
	return reveal_count(props) >= 0.0


static func shown_count(props: Dictionary, length: int) -> int:
	if not count_on(props):
		return length
	return clampi(int(floor(reveal_count(props) + 0.0001)), 0, length)


static func token_on(props: Dictionary) -> bool:
	var t: Variant = plain(props.get("text", ""))
	if not (t is String):
		return false
	for tok: String in TOKENS:
		if (t as String).contains(tok):
			return true
	return false


static func decode_on(props: Dictionary) -> bool:
	return TextDecode.on(props)


static func active(props: Dictionary) -> bool:
	return path_on(props) or counter_on(props) or token_on(props) or count_on(props) or decode_on(props) or tilt_on(props)


static func group_thousands(digits: String) -> String:
	var out: String = ""
	var n: int = digits.length()
	for i: int in n:
		out += digits[i]
		var left: int = n - 1 - i
		if left > 0 and left % 3 == 0:
			out += ","
	return out


static func counter_text(props: Dictionary) -> String:
	return String(get_value(props, "counter_prefix")) + number_text(props) + String(get_value(props, "counter_suffix"))


static func number_text(props: Dictionary) -> String:
	var v: float = float(get_value(props, "counter_value"))
	var decimals: int = clampi(int(get_value(props, "counter_decimals")), 0, 6)
	var fmt: String = String(get_value(props, "counter_format"))
	var body: String = ""
	if fmt == "time" or fmt == "time_long":
		var neg: bool = v < 0.0
		var total: float = absf(v)
		var whole: int = int(floor(total))
		var h: int = whole / 3600
		var m: int = (whole / 60) % 60
		var s: int = whole % 60
		var frac: String = ""
		if decimals > 0:
			frac = "." + String.num(total - float(whole), decimals).substr(2).rpad(decimals, "0")
		if fmt == "time_long" or h > 0:
			body = "%d:%02d:%02d" % [h, m, s] + frac
		else:
			body = "%d:%02d" % [whole / 60, s] + frac
		if neg:
			body = "-" + body
	else:
		var shown: float = v * 100.0 if fmt == "percent" else v
		var txt: String = String.num(snappedf(shown, pow(10.0, -decimals)) if decimals > 0 else roundf(shown), decimals)
		if decimals > 0 and not txt.contains("."):
			txt += "." + "0".repeat(decimals)
		elif decimals > 0:
			var have: int = txt.length() - txt.find(".") - 1
			if have < decimals:
				txt += "0".repeat(decimals - have)
		if fmt == "thousands":
			var neg2: bool = txt.begins_with("-")
			var digits: String = txt.trim_prefix("-")
			var dot: int = digits.find(".")
			var whole_part: String = digits if dot < 0 else digits.substr(0, dot)
			var rest: String = "" if dot < 0 else digits.substr(dot)
			txt = ("-" if neg2 else "") + group_thousands(whole_part) + rest
		body = txt + ("%" if fmt == "percent" else "")
	return body


static func shown_text(props: Dictionary) -> String:
	if counter_on(props):
		return counter_text(props)
	var t: Variant = plain(props.get("text", ""))
	var text: String = String(t) if t is String else ""
	if token_on(props):
		var shown: String = number_text(props)
		for tok: String in TOKENS:
			text = text.replace(tok, shown)
	return text


static func flat(v: Variant) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if not (v is Array):
		return out
	for x: Variant in v:
		if x is Array and (x as Array).size() >= 2:
			out.append(float((x as Array)[0]))
			out.append(float((x as Array)[1]))
		elif x is float or x is int:
			out.append(float(x))
	return out


static func path_points(props: Dictionary, size: Vector2, text_width: float, run_w: float = -1.0) -> PackedVector2Array:
	var shape: String = path_shape(props)
	var amount: float = amount_of(props)
	var mix: float = mix_of(props)
	var plain_a: bool = _shape_live(props, shape)
	if plain_a and amount >= 0.9999 and mix <= 0.0:
		return shape_points(props, shape, size, text_width)
	var a: PackedVector2Array = shape_points(props, shape, size, text_width) if plain_a else PackedVector2Array()
	var straight: PackedVector2Array = straight_for(props, a, shape, size, text_width, run_w)
	var got: PackedVector2Array = straight
	if not a.is_empty():
		got = blend(straight, a, amount)
	if mix > 0.0:
		var sb: String = shape_b(props)
		var b: PackedVector2Array = shape_points(props, sb, size, text_width)
		var b_amt: PackedVector2Array = blend(straight_for(props, b, sb, size, text_width, run_w), b, amount)
		got = blend(got, b_amt, mix)
	return got


static func straight_for(props: Dictionary, shape_pts: PackedVector2Array, shape: String, size: Vector2, text_width: float, run_w: float) -> PackedVector2Array:
	var centre: Vector2 = size * 0.5
	var total: float = path_span(size, text_width)
	if shape_pts.size() >= 2:
		var lens: PackedFloat64Array = lengths(shape_pts)
		total = maxf(lens[lens.size() - 1], 1.0)
	var x0: float = centre.x - total * 0.5
	if CLOSED_SHAPES.has(shape):
		var rw: float = run_w if run_w > 0.0 else minf(total, path_span(size, text_width))
		x0 = centre.x - rw * 0.5
	var out: PackedVector2Array = PackedVector2Array()
	out.append(Vector2(x0, centre.y))
	out.append(Vector2(x0 + total, centre.y))
	return out


static func resample(pts: PackedVector2Array, n: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if pts.size() < 2:
		for i0: int in n:
			out.append(pts[0] if pts.size() == 1 else Vector2.ZERO)
		return out
	var lens: PackedFloat64Array = lengths(pts)
	var total: float = lens[lens.size() - 1]
	for i: int in n:
		var d: float = total * float(i) / float(n - 1)
		out.append(sample(pts, lens, d)[0])
	return out


static func blend(a: PackedVector2Array, b: PackedVector2Array, w: float) -> PackedVector2Array:
	if w <= 0.0:
		return a
	if w >= 1.0:
		return b
	var ra: PackedVector2Array = resample(a, BLEND_STEPS)
	var rb: PackedVector2Array = resample(b, BLEND_STEPS)
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in BLEND_STEPS:
		out.append(ra[i].lerp(rb[i], w))
	return out


static func shape_points(props: Dictionary, shape: String, size: Vector2, text_width: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var scale_f: float = size.y / 1080.0
	var centre: Vector2 = size * 0.5
	if shape == "points":
		var f: PackedFloat64Array = flat(get_value(props, "path_points"))
		for i: int in f.size() / 2:
			out.append(Vector2(f[i * 2] * size.x, f[i * 2 + 1] * size.y))
		return out
	if shape == "circle":
		var r: float = maxf(float(get_value(props, "path_size")), 1.0) / 100.0 * size.y
		for i2: int in CIRCLE_STEPS + 1:
			var a: float = -PI * 0.5 + TAU * float(i2) / float(CIRCLE_STEPS)
			out.append(centre + Vector2(cos(a), sin(a)) * r)
		return out
	if shape == "ellipse":
		var rx: float = maxf(float(get_value(props, "path_size")), 1.0) / 100.0 * size.y
		var ry: float = rx * clampf(float(get_value(props, "path_aspect")), 5.0, 400.0) / 100.0
		for i5: int in CIRCLE_STEPS + 1:
			var a5: float = -PI * 0.5 + TAU * float(i5) / float(CIRCLE_STEPS)
			out.append(centre + Vector2(cos(a5) * rx, sin(a5) * ry))
		return out
	if shape == "polygon":
		var rp: float = maxf(float(get_value(props, "path_size")), 1.0) / 100.0 * size.y
		var sides: int = clampi(int(round(float(get_value(props, "path_sides")))), 3, 24)
		for i6: int in sides + 1:
			var a6: float = -PI * 0.5 + TAU * float(i6) / float(sides)
			out.append(centre + Vector2(cos(a6), sin(a6)) * rp)
		return out
	if shape == "spiral":
		var rs: float = maxf(float(get_value(props, "path_size")), 1.0) / 100.0 * size.y
		var turns: float = clampf(float(get_value(props, "path_waves")), 0.25, 12.0)
		var steps: int = int(CIRCLE_STEPS * maxf(turns, 1.0))
		for i7: int in steps + 1:
			var u7: float = float(i7) / float(steps)
			var a7: float = -PI * 0.5 + TAU * turns * u7
			out.append(centre + Vector2(cos(a7), sin(a7)) * rs * (0.12 + 0.88 * u7))
		return out
	var w: float = maxf(text_width, size.x * 0.2)
	if shape == "arc":
		var bend: float = float(get_value(props, "path_bend")) / 100.0
		var sag: float = bend * w * 0.5
		for i3: int in CURVE_STEPS + 1:
			var u: float = float(i3) / float(CURVE_STEPS)
			var x: float = centre.x - w * 0.5 + w * u
			var y: float = centre.y - sag * (1.0 - pow(2.0 * u - 1.0, 2.0)) + sag * 0.5
			out.append(Vector2(x, y))
		return out
	var amp: float = float(get_value(props, "path_size")) * scale_f
	var waves: float = float(get_value(props, "path_waves"))
	for i4: int in CURVE_STEPS + 1:
		var u2: float = float(i4) / float(CURVE_STEPS)
		out.append(Vector2(centre.x - w * 0.5 + w * u2, centre.y + sin(TAU * waves * u2) * amp))
	return out


static func lengths(pts: PackedVector2Array) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array([0.0])
	for i: int in range(1, pts.size()):
		out.append(out[i - 1] + pts[i].distance_to(pts[i - 1]))
	return out


static func sample(pts: PackedVector2Array, lens: PackedFloat64Array, s: float) -> Array:
	if pts.size() < 2:
		return [pts[0] if pts.size() == 1 else Vector2.ZERO, 0.0]
	var total: float = lens[lens.size() - 1]
	var d: float = s
	if d <= 0.0:
		var dir0: Vector2 = (pts[1] - pts[0]).normalized()
		return [pts[0] + dir0 * d, dir0.angle()]
	if d >= total:
		var n: int = pts.size()
		var dir1: Vector2 = (pts[n - 1] - pts[n - 2]).normalized()
		return [pts[n - 1] + dir1 * (d - total), dir1.angle()]
	var lo: int = 0
	var hi: int = lens.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if lens[mid] <= d:
			lo = mid
		else:
			hi = mid
	var seg: float = lens[hi] - lens[lo]
	var u: float = (d - lens[lo]) / seg if seg > 0.0 else 0.0
	var dir: Vector2 = (pts[hi] - pts[lo]).normalized()
	return [pts[lo].lerp(pts[hi], u), dir.angle()]


static func path_span(size: Vector2, text_width: float) -> float:
	return maxf(text_width, size.x * 0.2)


static func grips(props: Dictionary, size: Vector2, text_width: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if size.x < 2.0 or size.y < 2.0:
		return out
	var shape: String = path_shape(props)
	var centre: Vector2 = size * 0.5
	var scale_f: float = size.y / 1080.0
	var w: float = path_span(size, text_width)
	if shape == "arc":
		var sag: float = float(get_value(props, "path_bend")) / 100.0 * w * 0.5
		out.append({"id": "bend", "at": Vector2(centre.x, centre.y - sag * 0.5), "look": "ring", "name": "Bend"})
	elif shape == "circle" or shape == "ellipse" or shape == "polygon" or shape == "spiral":
		var r: float = maxf(float(get_value(props, "path_size")), 1.0) / 100.0 * size.y
		out.append({"id": "radius", "at": centre - Vector2(r, 0.0), "look": "ring", "name": "Circle size" if shape == "circle" else "Size"})
	elif shape == "wave":
		var amp: float = float(get_value(props, "path_size")) * scale_f
		var waves: float = clampf(float(get_value(props, "path_waves")), WAVES_MIN, WAVES_MAX)
		var u: float = clampf(0.25 / waves, 0.0, 1.0)
		out.append({"id": "crest", "at": Vector2(centre.x - w * 0.5 + w * u, centre.y + amp), "look": "ring", "name": "Wave"})
	elif shape == "points":
		var pts: PackedVector2Array = point_list(props)
		for i: int in pts.size():
			out.append({"id": "p" + str(i), "at": pts[i] * size, "look": "dot", "name": "Point " + str(i + 1)})
	return out


static func bend_for(size: Vector2, w: float, at: Vector2) -> float:
	return clampf((size.y * 0.5 - at.y) * 400.0 / maxf(w, 1.0), -BEND_MAX, BEND_MAX)


static func radius_for(size: Vector2, at: Vector2) -> float:
	return clampf((at - size * 0.5).length() / maxf(size.y, 1.0) * 100.0, 1.0, SIZE_MAX)


static func amp_for(size: Vector2, at: Vector2) -> float:
	return clampf((at.y - size.y * 0.5) / maxf(size.y / 1080.0, 0.0001), 0.0, SIZE_MAX)


static func waves_for(size: Vector2, w: float, at: Vector2) -> float:
	var du: float = (at.x - (size.x * 0.5 - w * 0.5)) / maxf(w, 1.0)
	return clampf(0.25 / maxf(du, 0.0001), WAVES_MIN, WAVES_MAX)


static func point_list(props: Dictionary) -> PackedVector2Array:
	var f: PackedFloat64Array = flat(get_value(props, "path_points"))
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in f.size() / 2:
		out.append(Vector2(f[i * 2], f[i * 2 + 1]))
	return out


static func point_flat(pts: PackedVector2Array) -> Array:
	var out: Array = []
	for p: Vector2 in pts:
		out.append(p.x)
		out.append(p.y)
	return out


static func nearest_leg(pts: PackedVector2Array, at: Vector2) -> Dictionary:
	var best: int = -1
	var best_d: float = INF
	var best_p: Vector2 = at
	for i: int in maxi(pts.size() - 1, 0):
		var on: Vector2 = Geometry2D.get_closest_point_to_segment(at, pts[i], pts[i + 1])
		var dd: float = on.distance_to(at)
		if dd < best_d:
			best_d = dd
			best = i
			best_p = on
	return {"index": best, "distance": best_d, "at": best_p}


static func with_point(pts: PackedVector2Array, at: int, p: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	out.insert(clampi(at, 0, out.size()), p)
	return out


static func without_point(pts: PackedVector2Array, at: int) -> PackedVector2Array:
	if pts.size() <= POINT_MIN or at < 0 or at >= pts.size():
		return pts
	var out: PackedVector2Array = pts.duplicate()
	out.remove_at(at)
	return out


static func mask_path(points: PackedVector2Array, closed: bool) -> Array:
	var out: Array = []
	for p: Vector2 in points:
		out.append(p.x)
		out.append(p.y)
	if closed and points.size() > 2:
		out.append(points[0].x)
		out.append(points[0].y)
	return out

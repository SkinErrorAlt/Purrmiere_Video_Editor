extends RefCounted

const PATH_SHAPES: PackedStringArray = ["none", "arc", "circle", "wave", "points"]
const PATH_LABELS: PackedStringArray = ["Straight", "Arc", "Circle", "Wave", "A drawn path"]
const COUNTER_FORMATS: PackedStringArray = ["number", "thousands", "percent", "time", "time_long"]
const COUNTER_LABELS: PackedStringArray = ["1234.5", "1,234.5", "50%", "1:05", "0:01:05"]
const CIRCLE_STEPS := 180
const CURVE_STEPS := 120
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


static func path_on(props: Dictionary) -> bool:
	var shape: String = path_shape(props)
	if shape == "points":
		return flat(get_value(props, "path_points")).size() >= 4
	return shape != "none"


static func counter_on(props: Dictionary) -> bool:
	return bool(get_value(props, "counter_on"))


static func token_on(props: Dictionary) -> bool:
	var t: Variant = plain(props.get("text", ""))
	if not (t is String):
		return false
	for tok: String in TOKENS:
		if (t as String).contains(tok):
			return true
	return false


static func active(props: Dictionary) -> bool:
	return path_on(props) or counter_on(props) or token_on(props)


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


static func path_points(props: Dictionary, size: Vector2, text_width: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var shape: String = path_shape(props)
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


static func mask_path(points: PackedVector2Array, closed: bool) -> Array:
	var out: Array = []
	for p: Vector2 in points:
		out.append(p.x)
		out.append(p.y)
	if closed and points.size() > 2:
		out.append(points[0].x)
		out.append(points[0].y)
	return out

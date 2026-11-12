extends RefCounted
## Shape layer outlines: rectangle, ellipse, polygon, star and line, with rounded corners, plus trimming the
## outline (start, end, offset) for draw-on animations and gradient fill helpers. All sizes are in the layer's
## pixels; props use the same keys as the Shape item (width and height as a share of the frame, radius in
## 1080-line pixels).

const TitleStyle := preload("res://doc/title_style.gd")

const SHAPES: PackedStringArray = ["rect", "ellipse", "polygon", "star", "line"]
const SHAPE_LABELS: PackedStringArray = ["Rectangle", "Ellipse", "Polygon", "Star", "Line"]
const FILLS: PackedStringArray = ["solid", "linear", "radial", "none"]
const FILL_LABELS: PackedStringArray = ["Solid colour", "Gradient, straight", "Gradient, round", "No fill"]
const ELLIPSE_STEPS := 120
const CORNER_STEPS := 10


static func defaults() -> Dictionary:
	return {"sides": 6.0, "points": 5.0, "inner": 0.45, "spin": 0.0, "fill": "solid", "colour2": [0.1, 0.1, 0.1, 1.0], "gradient_angle": 90.0, "gradient_mid": 0.5, "trim_start": 0.0, "trim_end": 1.0, "trim_offset": 0.0}


## Whether the shape needs the new drawing (polygon, star, gradient or no fill, a trim, a turn); plain shapes keep
## drawing exactly as they always have.
static func uses_new(props: Dictionary) -> bool:
	var shape: String = String(props.get("shape", "rect"))
	if shape == "polygon" or shape == "star":
		return true
	if String(props.get("fill", "solid")) != "solid":
		return true
	if num(props, "trim_start") > 0.0001 or num(props, "trim_end") < 0.9999:
		return true
	return absf(num(props, "spin")) > 0.0001


static func num(props: Dictionary, key: String) -> float:
	var v: Variant = props.get(key, defaults().get(key, 0.0))
	if v is Dictionary:
		v = (v as Dictionary).get("v", (v as Dictionary).get("base", 0.0))
	return float(v) if (v is float or v is int) else float(defaults().get(key, 0.0))


static func box(props: Dictionary, size: Vector2) -> Rect2:
	var w: float = clampf(num(props, "width") if props.has("width") else 0.5, 0.001, 1.0) * size.x
	var h: float = clampf(num(props, "height") if props.has("height") else 0.5, 0.001, 1.0) * size.y
	return Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)


## The closed outline of the shape (the line shape gives its two end points, open).
static func outline(props: Dictionary, size: Vector2) -> PackedVector2Array:
	var r: Rect2 = box(props, size)
	var shape: String = String(props.get("shape", "rect"))
	var radius: float = maxf(num(props, "radius"), 0.0) * size.y / 1080.0
	var spin: float = deg_to_rad(num(props, "spin"))
	match shape:
		"ellipse":
			return _ellipse(r, spin)
		"polygon":
			return rounded(_polygon(r, clampi(int(round(num(props, "sides"))), 3, 64), spin), radius)
		"star":
			return rounded(_star(r, clampi(int(round(num(props, "points"))), 3, 64), clampf(num(props, "inner"), 0.02, 1.0), spin), radius)
		"line":
			return PackedVector2Array([Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y)])
	return rounded(_rotated(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), r.get_center(), spin), radius)


static func _rotated(pts: PackedVector2Array, c: Vector2, a: float) -> PackedVector2Array:
	if is_zero_approx(a):
		return pts
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		out.append(c + (p - c).rotated(a))
	return out


static func _ellipse(r: Rect2, spin: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var c: Vector2 = r.get_center()
	for i: int in ELLIPSE_STEPS:
		var a: float = TAU * float(i) / float(ELLIPSE_STEPS)
		out.append(c + Vector2(cos(a) * r.size.x * 0.5, sin(a) * r.size.y * 0.5).rotated(spin))
	return out


## A regular polygon fitted to the box, first corner at the top.
static func _polygon(r: Rect2, sides: int, spin: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var c: Vector2 = r.get_center()
	for i: int in sides:
		var a: float = -PI * 0.5 + TAU * float(i) / float(sides) + spin
		out.append(c + Vector2(cos(a) * r.size.x * 0.5, sin(a) * r.size.y * 0.5))
	return out


static func _star(r: Rect2, points: int, inner: float, spin: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var c: Vector2 = r.get_center()
	for i: int in points * 2:
		var a: float = -PI * 0.5 + PI * float(i) / float(points) + spin
		var k: float = 1.0 if i % 2 == 0 else inner
		out.append(c + Vector2(cos(a) * r.size.x * 0.5 * k, sin(a) * r.size.y * 0.5 * k))
	return out


## Rounds every corner of a closed outline by up to `radius` pixels (limited by half the shorter edge).
static func rounded(pts: PackedVector2Array, radius: float) -> PackedVector2Array:
	var n: int = pts.size()
	if radius <= 0.01 or n < 3:
		return pts
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in n:
		var p: Vector2 = pts[i]
		var a: Vector2 = pts[(i - 1 + n) % n]
		var b: Vector2 = pts[(i + 1) % n]
		var da: Vector2 = a - p
		var db: Vector2 = b - p
		var la: float = da.length()
		var lb: float = db.length()
		if la < 0.001 or lb < 0.001:
			out.append(p)
			continue
		var ua: Vector2 = da / la
		var ub: Vector2 = db / lb
		var half: float = acos(clampf(ua.dot(ub), -1.0, 1.0)) * 0.5
		if half < 0.001 or half > PI * 0.5 - 0.001:
			out.append(p)
			continue
		var cut: float = minf(radius / tan(half), minf(la, lb) * 0.5)
		var r_eff: float = cut * tan(half)
		var p1: Vector2 = p + ua * cut
		var p2: Vector2 = p + ub * cut
		var centre: Vector2 = p + (ua + ub).normalized() * (r_eff / sin(half))
		var a1: float = (p1 - centre).angle()
		var a2: float = (p2 - centre).angle()
		var sweep: float = wrapf(a2 - a1, -PI, PI)
		for k: int in CORNER_STEPS + 1:
			out.append(centre + Vector2.from_angle(a1 + sweep * float(k) / float(CORNER_STEPS)) * r_eff)
	return out


static func perimeter(pts: PackedVector2Array, closed: bool) -> float:
	var total: float = 0.0
	var n: int = pts.size()
	for i: int in (n if closed else n - 1):
		total += pts[i].distance_to(pts[(i + 1) % n])
	return total


## The parts of the outline between trim start and end (shares of its length, 0 to 1), shifted round by offset.
## Returns polylines to stroke; a closed outline trimmed to the full length gives one closed polyline.
static func trimmed(pts: PackedVector2Array, closed: bool, start: float, end: float, offset: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var n: int = pts.size()
	if n < 2:
		return out
	var a: float = clampf(minf(start, end), 0.0, 1.0)
	var b: float = clampf(maxf(start, end), 0.0, 1.0)
	if b - a <= 0.0001:
		return out
	var ring: PackedVector2Array = pts.duplicate()
	if closed:
		ring.append(pts[0])
	if closed and a <= 0.0001 and b >= 0.9999:
		out.append(ring)
		return out
	var total: float = perimeter(pts, closed)
	if total <= 0.0001:
		return out
	var off: float = fposmod(offset, 1.0) if closed else 0.0
	var spans: Array[Vector2] = []
	var s0: float = a + off
	var s1: float = b + off
	if closed and s1 > 1.0:
		if s0 < 1.0:
			spans.append(Vector2(s0, 1.0))
		spans.append(Vector2(maxf(s0 - 1.0, 0.0), s1 - 1.0))
	else:
		spans.append(Vector2(minf(s0, 1.0), minf(s1, 1.0)))
	for sp: Vector2 in spans:
		var piece: PackedVector2Array = _cut(ring, total, sp.x * total, sp.y * total)
		if piece.size() >= 2:
			out.append(piece)
	return out


static func _cut(ring: PackedVector2Array, _total: float, from_d: float, to_d: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var run: float = 0.0
	for i: int in ring.size() - 1:
		var p: Vector2 = ring[i]
		var q: Vector2 = ring[i + 1]
		var seg: float = p.distance_to(q)
		var s_end: float = run + seg
		if s_end >= from_d and run <= to_d and seg > 0.0:
			var t0: float = clampf((from_d - run) / seg, 0.0, 1.0)
			var t1: float = clampf((to_d - run) / seg, 0.0, 1.0)
			if out.is_empty():
				out.append(p.lerp(q, t0))
			out.append(p.lerp(q, t1))
		run = s_end
		if run > to_d:
			break
	return out


## A gradient texture for the fill: straight at an angle, or round from the middle. Built straight into an image
## (a GradientTexture2D fills itself later, so the first frame would draw white) and kept for the same settings.
const GRAD_SIZE := 128
static var _grad_cache: Dictionary = {}


static func gradient_texture(props: Dictionary) -> Texture2D:
	var c1: Color = TitleStyle.colour_of(props.get("colour", null), Color(0.5, 0.5, 0.5, 1.0))
	var c2: Color = TitleStyle.colour_of(props.get("colour2", null), Color(0.1, 0.1, 0.1, 1.0))
	var mid: float = clampf(num(props, "gradient_mid"), 0.02, 0.98)
	var radial: bool = String(props.get("fill", "solid")) == "radial"
	var ang: float = 0.0 if radial else num(props, "gradient_angle")
	var key: String = "%s|%s|%.3f|%s|%.2f" % [c1.to_html(), c2.to_html(), mid, str(radial), ang]
	if _grad_cache.has(key):
		return _grad_cache[key]
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, mid, 1.0])
	g.colors = PackedColorArray([c1, c1.lerp(c2, 0.5), c2])
	var img: Image = Image.create(GRAD_SIZE, GRAD_SIZE, false, Image.FORMAT_RGBA8)
	var a: float = deg_to_rad(ang)
	var dir: Vector2 = Vector2(cos(a), sin(a))
	var inv: float = 1.0 / float(GRAD_SIZE - 1)
	for y: int in GRAD_SIZE:
		for x: int in GRAD_SIZE:
			var uv: Vector2 = Vector2(float(x) * inv, float(y) * inv) - Vector2(0.5, 0.5)
			var t: float = uv.length() * 2.0 if radial else uv.dot(dir) + 0.5
			img.set_pixel(x, y, g.sample(clampf(t, 0.0, 1.0)))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	if _grad_cache.size() > 32:
		_grad_cache.clear()
	_grad_cache[key] = tex
	return tex


## UVs for a polygon so a texture spans its bounding box.
static func box_uvs(pts: PackedVector2Array) -> PackedVector2Array:
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for p: Vector2 in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var span: Vector2 = Vector2(maxf(hi.x - lo.x, 0.001), maxf(hi.y - lo.y, 0.001))
	var out: PackedVector2Array = PackedVector2Array()
	for p2: Vector2 in pts:
		out.append((p2 - lo) / span)
	return out


## Draws the shape: fill (solid, gradient or none) and its trimmed border.
static func draw(ci: CanvasItem, props: Dictionary, size: Vector2) -> void:
	var shape: String = String(props.get("shape", "rect"))
	var col: Color = TitleStyle.colour_of(props.get("colour", null), Color(0.5, 0.5, 0.5, 1.0))
	var border: float = num(props, "border") * size.y / 1080.0
	var bcol: Color = TitleStyle.colour_of(props.get("border_colour", null), Color.BLACK)
	var pts: PackedVector2Array = outline(props, size)
	var t0: float = num(props, "trim_start")
	var t1: float = num(props, "trim_end")
	var toff: float = num(props, "trim_offset")
	if shape == "line":
		var r: Rect2 = box(props, size)
		for piece: PackedVector2Array in trimmed(pts, false, t0, t1, 0.0):
			ci.draw_polyline(piece, col, maxf(r.size.y, 1.0), true)
		return
	var fill: String = String(props.get("fill", "solid"))
	var full: bool = t0 <= 0.0001 and t1 >= 0.9999
	if fill != "none" and full and pts.size() >= 3:
		if fill == "linear" or fill == "radial":
			ci.draw_colored_polygon(pts, Color.WHITE, box_uvs(pts), gradient_texture(props))
		else:
			ci.draw_colored_polygon(pts, col)
	if border > 0.0:
		for piece2: PackedVector2Array in trimmed(pts, true, t0, t1, toff):
			ci.draw_polyline(piece2, bcol, border, true)
	elif not full:
		for piece3: PackedVector2Array in trimmed(pts, true, t0, t1, toff):
			ci.draw_polyline(piece3, col, maxf(2.0 * size.y / 1080.0, 1.0), true)

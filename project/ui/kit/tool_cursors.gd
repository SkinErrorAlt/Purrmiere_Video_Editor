extends RefCounted

const Icons := preload("res://ui/kit/icons.gd")
const SLOT := Control.CURSOR_HELP
const SAMPLES := 3
const HALO_PX := 1.6
const PAD_PX := 2.0
const ARC_STEPS := 24
const INK := Color(1.0, 1.0, 1.0, 1.0)
const HALO := Color(0.04, 0.04, 0.05, 1.0)
const TOOLS: Dictionary = {
	"track_select": ["track_fwd", Vector2(2.0, 3.0)],
	"ripple": ["ripple", Vector2(6.5, 8.0)],
	"roll": ["roll", Vector2(8.0, 8.0)],
	"rate": ["rate", Vector2(8.0, 8.0)],
	"razor": ["razor", Vector2(8.0, 8.0)],
	"slip": ["slip", Vector2(8.0, 8.0)],
	"slide": ["slide", Vector2(8.0, 8.0)],
	"pen": ["pen", Vector2(8.0, 2.0)],
	"hand": ["hand", Vector2(8.0, 8.0)],
	"zoom": ["zoom", Vector2(6.8, 6.8)],
}
const ZONES: PackedStringArray = ["lane", "empty", "new_track"]
const DRAWN: PackedStringArray = ["razor"]
const RAZOR_TALL := 1.5
const RAZOR_WIDE := 0.28
const RAZOR_GAP := 0.045
const RAZOR_BEND := 2.6
const RAZOR_EDGE := 0.3
const EDGE := Color(1.0, 0.23, 0.28, 1.0)

static var _cache: Dictionary = {}
static var _shown: String = ""
static var stats: Dictionary = {"built": 0, "claims": 0}


static func icon_for(tool: String) -> String:
	if not Icons.filmcraft or not TOOLS.has(tool):
		return ""
	return String((TOOLS[tool] as Array)[0])


static func drawn(tool: String) -> bool:
	return DRAWN.has(tool)


static func wants(tool: String, zone: String) -> bool:
	return (drawn(tool) or not icon_for(tool).is_empty()) and ZONES.has(zone)


static func size_px() -> int:
	return clampi(int(round(Tk.px(26))), 20, 64)


static func claim(tool: String) -> Control.CursorShape:
	if not drawn(tool) and icon_for(tool).is_empty():
		return Control.CURSOR_ARROW
	var px: int = size_px()
	var key: String = tool + "|" + str(px) + "|" + str(Icons.serial)
	if _shown != key:
		var entry: Dictionary = built(tool, px)
		Input.set_custom_mouse_cursor(entry["tex"], Input.CURSOR_HELP, entry["hot"])
		_shown = key
		stats["claims"] = int(stats["claims"]) + 1
	return SLOT


static func built(tool: String, px: int) -> Dictionary:
	var key: String = tool + "|" + str(px) + "|" + str(Icons.serial)
	if _cache.has(key):
		return _cache[key]
	if drawn(tool):
		var made: Dictionary = razor(px)
		_cache[key] = made
		stats["built"] = int(stats["built"]) + 1
		return made
	var spec: Array = TOOLS[tool]
	var icon: String = String(spec[0])
	var img: Image = image(icon, px)
	var k: float = (float(px) - PAD_PX * 2.0) / Icons.grid_of(icon)
	var hot_grid: Vector2 = spec[1]
	var hot: Vector2 = (Vector2(PAD_PX, PAD_PX) + hot_grid * k).round()
	var entry: Dictionary = {"tex": ImageTexture.create_from_image(img), "img": img, "hot": hot}
	_cache[key] = entry
	stats["built"] = int(stats["built"]) + 1
	return entry


static func image(icon: String, px: int) -> Image:
	var img: Image = Image.create_empty(px, px, false, Image.FORMAT_RGBA8)
	var k: float = (float(px) - PAD_PX * 2.0) / Icons.grid_of(icon)
	var origin: Vector2 = Vector2(PAD_PX, PAD_PX)
	var hw: float = maxf(0.75, Icons.stroke_of(icon) * k * 0.55)
	var shapes: Dictionary = _shapes(Icons.ops_of(icon), origin, k)
	var inv: float = 1.0 / float(SAMPLES * SAMPLES)
	for y: int in px:
		for x: int in px:
			var ink: float = 0.0
			var halo: float = 0.0
			for sy: int in SAMPLES:
				for sx: int in SAMPLES:
					var p: Vector2 = Vector2(float(x) + (float(sx) + 0.5) / float(SAMPLES), float(y) + (float(sy) + 0.5) / float(SAMPLES))
					var d: float = _distance(shapes, p, hw)
					if d <= 0.0:
						ink += inv
					if d <= HALO_PX:
						halo += inv
			if halo <= 0.0:
				continue
			var c: Color = HALO.lerp(INK, ink / halo)
			c.a = halo
			img.set_pixel(x, y, c)
	return img


static func razor(px: int) -> Dictionary:
	var w: int = px
	var h: int = maxi(int(round(float(px) * RAZOR_TALL)), px + 8)
	var hot: Vector2 = Vector2(floorf(float(w) * 0.5), floorf(float(h) * 0.5))
	var cx: float = hot.x + 0.5
	var cy: float = hot.y + 0.5
	var gap: float = maxf(1.5, float(h) * RAZOR_GAP)
	var wide: float = float(w) * RAZOR_WIDE
	var top: float = PAD_PX
	var tip_top: float = cy - gap
	var tip_bottom: float = cy + gap
	var bottom: float = float(h) - PAD_PX
	var needle: float = gap + (tip_top - top) * RAZOR_EDGE
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var inv: float = 1.0 / float(SAMPLES * SAMPLES)
	for y: int in h:
		for x: int in w:
			var ink: float = 0.0
			var edge: float = 0.0
			var halo: float = 0.0
			for sy: int in SAMPLES:
				for sx: int in SAMPLES:
					var p: Vector2 = Vector2(float(x) + (float(sx) + 0.5) / float(SAMPLES), float(y) + (float(sy) + 0.5) / float(SAMPLES))
					var dx: float = absf(p.x - cx)
					var a: Vector2 = _blade(dx, tip_top - p.y, tip_top - top, wide)
					var b: Vector2 = _blade(dx, p.y - tip_bottom, bottom - tip_bottom, wide)
					var line: float = maxf(dx - 0.5, absf(p.y - cy) - needle)
					var d: float = minf(minf(a.x, b.x), line)
					if d <= 0.0:
						ink += inv
						if line <= 0.0 or (a.x <= 0.0 and a.y < RAZOR_EDGE) or (b.x <= 0.0 and b.y < RAZOR_EDGE):
							edge += inv
					if d <= HALO_PX:
						halo += inv
			if halo <= 0.0:
				continue
			var body: Color = INK.lerp(EDGE, edge / ink) if ink > 0.0 else INK
			var c: Color = HALO.lerp(body, ink / halo)
			c.a = halo
			img.set_pixel(x, y, c)
	return {"tex": ImageTexture.create_from_image(img), "img": img, "hot": hot}


static func _blade(dx: float, s: float, length: float, wide: float) -> Vector2:
	if length <= 0.0:
		return Vector2(INF, 1.0)
	if s < 0.0:
		return Vector2(sqrt(dx * dx + s * s), 0.0)
	var u: float = s / length
	if u > 1.0:
		return Vector2(maxf(s - length, dx - wide), 1.0)
	var half: float = wide * pow(u, RAZOR_BEND)
	var slope: float = wide * RAZOR_BEND * pow(u, RAZOR_BEND - 1.0) / length
	return Vector2((dx - half) / sqrt(1.0 + slope * slope), u)


static func _shapes(ops: Array, origin: Vector2, k: float) -> Dictionary:
	var segs: PackedVector2Array = PackedVector2Array()
	var rings: Array[Vector3] = []
	var polys: Array[PackedVector2Array] = []
	var dots: Array[Vector3] = []
	for op: Array in ops:
		var kind: String = op[0]
		if kind == "p" or kind == "o":
			var pts: PackedVector2Array = _pts(op[1], origin, k)
			for i: int in range(pts.size() - 1):
				segs.append(pts[i])
				segs.append(pts[i + 1])
			if kind == "o" and pts.size() > 2:
				segs.append(pts[pts.size() - 1])
				segs.append(pts[0])
		elif kind == "l":
			segs.append(origin + Vector2(float(op[1]), float(op[2])) * k)
			segs.append(origin + Vector2(float(op[3]), float(op[4])) * k)
		elif kind == "f":
			polys.append(_pts(op[1], origin, k))
		elif kind == "c":
			var c: Vector2 = origin + Vector2(float(op[1]), float(op[2])) * k
			rings.append(Vector3(c.x, c.y, float(op[3]) * k))
		elif kind == "d":
			var dc: Vector2 = origin + Vector2(float(op[1]), float(op[2])) * k
			dots.append(Vector3(dc.x, dc.y, maxf(1.0, float(op[3]) * k)))
		elif kind == "r" or kind == "fr":
			var a: Vector2 = origin + Vector2(float(op[1]), float(op[2])) * k
			var b: Vector2 = a + Vector2(float(op[3]), float(op[4])) * k
			var box: PackedVector2Array = PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])
			if kind == "fr":
				polys.append(box)
			else:
				for i: int in 4:
					segs.append(box[i])
					segs.append(box[(i + 1) % 4])
		elif kind == "a":
			var ac: Vector2 = origin + Vector2(float(op[1]), float(op[2])) * k
			var r: float = float(op[3]) * k
			var a0: float = deg_to_rad(float(op[4]))
			var a1: float = deg_to_rad(float(op[5]))
			var prev: Vector2 = ac + Vector2(cos(a0), sin(a0)) * r
			for i: int in range(1, ARC_STEPS + 1):
				var t: float = lerpf(a0, a1, float(i) / float(ARC_STEPS))
				var next: Vector2 = ac + Vector2(cos(t), sin(t)) * r
				segs.append(prev)
				segs.append(next)
				prev = next
		elif kind == "e":
			var ec: Vector2 = origin + Vector2(float(op[1]), float(op[2])) * k
			var ring: PackedVector2Array = PackedVector2Array()
			for i: int in 40:
				var t2: float = TAU * float(i) / 40.0
				ring.append(ec + Vector2(cos(t2) * float(op[3]), sin(t2) * float(op[4])) * k)
			polys.append(ring)
	return {"segs": segs, "rings": rings, "polys": polys, "dots": dots}


static func _pts(raw: Array, origin: Vector2, k: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var i: int = 0
	while i + 1 < raw.size():
		out.append(origin + Vector2(float(raw[i]), float(raw[i + 1])) * k)
		i += 2
	return out


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	if len2 <= 0.000001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _distance(shapes: Dictionary, p: Vector2, hw: float) -> float:
	var d: float = INF
	var segs: PackedVector2Array = shapes["segs"]
	var i: int = 0
	while i + 1 < segs.size():
		d = minf(d, _seg_dist(p, segs[i], segs[i + 1]) - hw)
		i += 2
	for ring: Vector3 in shapes["rings"]:
		d = minf(d, absf(p.distance_to(Vector2(ring.x, ring.y)) - ring.z) - hw)
	for dot: Vector3 in shapes["dots"]:
		d = minf(d, p.distance_to(Vector2(dot.x, dot.y)) - dot.z)
	for poly: PackedVector2Array in shapes["polys"]:
		if poly.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(p, poly):
			return -1.0
		for j: int in poly.size():
			d = minf(d, _seg_dist(p, poly[j], poly[(j + 1) % poly.size()]))
	return d

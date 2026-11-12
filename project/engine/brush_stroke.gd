extends RefCounted

const HARD := 0
const SOFT := 1
const SQUARE := 2
const AIR := 3
const MOST_PROMPTS := 3
const STEP_PART := 0.07
const AIR_FLOW := 0.3


static func thin(points: PackedVector2Array, least: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if points.is_empty():
		return out
	out.append(points[0])
	for i: int in range(1, points.size()):
		if points[i].distance_to(out[out.size() - 1]) >= least:
			out.append(points[i])
	if points.size() > 1 and out[out.size() - 1] != points[points.size() - 1]:
		out.append(points[points.size() - 1])
	return out


static func length_of(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


static func bounds(points: PackedVector2Array, pad: float = 0.0) -> Rect2:
	if points.is_empty():
		return Rect2(0, 0, 0, 0)
	var low: Vector2 = points[0]
	var high: Vector2 = points[0]
	for p: Vector2 in points:
		low = low.min(p)
		high = high.max(p)
	low -= Vector2(pad, pad)
	high += Vector2(pad, pad)
	return Rect2(low, high - low)


static func along(points: PackedVector2Array, want: int) -> Array:
	var out: Array = []
	if points.is_empty() or want <= 0:
		return out
	if points.size() == 1 or want == 1:
		out.append(points[0])
		return out
	var total: float = length_of(points)
	if total <= 0.0:
		out.append(points[0])
		return out
	var step: float = total / float(want - 1)
	out.append(points[0])
	var walked: float = 0.0
	var due: float = step
	for i: int in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var seg: float = a.distance_to(b)
		if seg <= 0.0:
			continue
		while walked + seg >= due and out.size() < want - 1:
			var t: float = (due - walked) / seg
			out.append(a.lerp(b, t))
			due += step
		walked += seg
	out.append(points[points.size() - 1])
	return out


static func weight(d: Vector2, kind: int) -> float:
	if kind == SQUARE:
		var far: float = maxf(absf(d.x), absf(d.y))
		return clampf((1.0 - far) * 8.0, 0.0, 1.0)
	var r: float = d.length()
	if kind == SOFT:
		return clampf(1.0 - smoothstep(0.0, 1.0, r), 0.0, 1.0)
	if kind == AIR:
		return clampf(1.0 - smoothstep(0.0, 1.0, r), 0.0, 1.0)
	return clampf((1.0 - r) * 8.0, 0.0, 1.0)


static func stamp(img: Image, at: Vector2, radius: Vector2, kind: int, on: bool) -> void:
	var one: PackedVector2Array = PackedVector2Array()
	one.append(at)
	paint(img, one, radius, kind, on)


static func dab(buf: Image, at: Vector2, radius: Vector2, kind: int) -> void:
	if buf == null:
		return
	var w: int = buf.get_width()
	var h: int = buf.get_height()
	var rx: float = maxf(radius.x, 0.5)
	var ry: float = maxf(radius.y, 0.5)
	var x0: int = maxi(int(floor(at.x - rx)), 0)
	var x1: int = mini(int(ceil(at.x + rx)), w - 1)
	var y0: int = maxi(int(floor(at.y - ry)), 0)
	var y1: int = mini(int(ceil(at.y + ry)), h - 1)
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var d: Vector2 = Vector2((float(x) + 0.5 - at.x) / rx, (float(y) + 0.5 - at.y) / ry)
			var k: float = weight(d, kind)
			if k <= 0.0:
				continue
			if k > buf.get_pixel(x, y).r:
				buf.set_pixel(x, y, Color(k, k, k, 1.0))


static func merge(img: Image, buf: Image, kind: int, on: bool, where: Rect2i) -> void:
	for y: int in range(where.position.y, where.end.y + 1):
		for x: int in range(where.position.x, where.end.x + 1):
			var k: float = buf.get_pixel(x, y).r
			if k <= 0.0:
				continue
			var was: float = img.get_pixel(x, y).r
			var now: float = was
			if kind == AIR:
				now = clampf(was + k * AIR_FLOW, 0.0, 1.0) if on else clampf(was - k * AIR_FLOW, 0.0, 1.0)
			else:
				now = maxf(was, k) if on else minf(was, 1.0 - k)
			img.set_pixel(x, y, Color(now, now, now, 1.0))


static func paint(img: Image, points: PackedVector2Array, radius: Vector2, kind: int, on: bool) -> void:
	if img == null or points.is_empty():
		return
	var w: int = img.get_width()
	var h: int = img.get_height()
	var buf: Image = Image.create(w, h, false, Image.FORMAT_R8)
	buf.fill(Color(0.0, 0.0, 0.0, 1.0))
	var rx: float = maxf(radius.x, 0.5)
	var ry: float = maxf(radius.y, 0.5)
	var step: float = maxf(minf(rx, ry) * STEP_PART, 0.5)
	if points.size() == 1:
		dab(buf, points[0], radius, kind)
	else:
		for i: int in range(1, points.size()):
			var a: Vector2 = points[i - 1]
			var b: Vector2 = points[i]
			var seg: float = a.distance_to(b)
			var steps: int = maxi(int(ceil(seg / step)), 1)
			for sp: int in range(steps + 1):
				if i > 1 and sp == 0:
					continue
				dab(buf, a.lerp(b, float(sp) / float(steps)), radius, kind)
	var span: Rect2 = bounds(points, 0.0)
	var low := Vector2i(maxi(int(floor(span.position.x - rx)) - 1, 0), maxi(int(floor(span.position.y - ry)) - 1, 0))
	var high := Vector2i(mini(int(ceil(span.end.x + rx)) + 1, w - 1), mini(int(ceil(span.end.y + ry)) + 1, h - 1))
	if high.x < low.x or high.y < low.y:
		return
	merge(img, buf, kind, on, Rect2i(low, high - low))


static func blank(side: int) -> Image:
	var img: Image = Image.create(maxi(side, 8), maxi(side, 8), false, Image.FORMAT_R8)
	img.fill(Color(0.0, 0.0, 0.0, 1.0))
	return img


static func coverage(img: Image) -> float:
	if img == null:
		return 0.0
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w <= 0 or h <= 0:
		return 0.0
	var total: float = 0.0
	for y: int in h:
		for x: int in w:
			total += img.get_pixel(x, y).r
	return total / float(w * h)

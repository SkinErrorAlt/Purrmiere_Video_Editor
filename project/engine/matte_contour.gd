extends RefCounted

const LEVEL := 0.5
const MAX_LOOPS := 48
const MIN_LOOP := 6


static func lines(matte: Image, step: int = 1) -> Array:
	var out: Array = []
	if matte == null:
		return out
	var w: int = matte.get_width()
	var h: int = matte.get_height()
	if w < 2 or h < 2:
		return out
	var reach: int = maxi(1, step)
	var grid_w: int = int(w / reach)
	var grid_h: int = int(h / reach)
	if grid_w < 2 or grid_h < 2:
		return out
	var level: PackedFloat32Array = PackedFloat32Array()
	level.resize(grid_w * grid_h)
	for y: int in grid_h:
		for x: int in grid_w:
			level[y * grid_w + x] = matte.get_pixel(mini(x * reach, w - 1), mini(y * reach, h - 1)).r
	var segments: Array = []
	for y: int in grid_h - 1:
		for x: int in grid_w - 1:
			var a: float = level[y * grid_w + x]
			var b: float = level[y * grid_w + x + 1]
			var c: float = level[(y + 1) * grid_w + x + 1]
			var d: float = level[(y + 1) * grid_w + x]
			var code: int = 0
			if a >= LEVEL:
				code |= 1
			if b >= LEVEL:
				code |= 2
			if c >= LEVEL:
				code |= 4
			if d >= LEVEL:
				code |= 8
			if code == 0 or code == 15:
				continue
			var top: Vector2 = Vector2(float(x) + _mix(a, b), float(y))
			var right: Vector2 = Vector2(float(x + 1), float(y) + _mix(b, c))
			var bottom: Vector2 = Vector2(float(x) + _mix(d, c), float(y + 1))
			var left: Vector2 = Vector2(float(x), float(y) + _mix(a, d))
			match code:
				1, 14:
					segments.append([left, top])
				2, 13:
					segments.append([top, right])
				3, 12:
					segments.append([left, right])
				4, 11:
					segments.append([right, bottom])
				5:
					segments.append([left, top])
					segments.append([right, bottom])
				6, 9:
					segments.append([top, bottom])
				7, 8:
					segments.append([left, bottom])
				10:
					segments.append([top, right])
					segments.append([left, bottom])
	var scale: Vector2 = Vector2(1.0 / float(grid_w - 1), 1.0 / float(grid_h - 1))
	for seg: Variant in segments:
		var pair: Array = seg
		var line: PackedVector2Array = PackedVector2Array()
		line.append((pair[0] as Vector2) * scale)
		line.append((pair[1] as Vector2) * scale)
		out.append(line)
		if out.size() >= grid_w * grid_h:
			break
	return out


static func bounds(matte: Image) -> Rect2:
	if matte == null:
		return Rect2(0, 0, 0, 0)
	var w: int = matte.get_width()
	var h: int = matte.get_height()
	var min_x: int = w
	var min_y: int = h
	var max_x: int = -1
	var max_y: int = -1
	for y: int in h:
		for x: int in w:
			if matte.get_pixel(x, y).r < LEVEL:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2(0, 0, 0, 0)
	return Rect2(float(min_x) / float(w), float(min_y) / float(h), float(max_x - min_x + 1) / float(w), float(max_y - min_y + 1) / float(h))


static func coverage(matte: Image) -> float:
	if matte == null:
		return 0.0
	var w: int = matte.get_width()
	var h: int = matte.get_height()
	if w <= 0 or h <= 0:
		return 0.0
	var inside: int = 0
	for y: int in h:
		for x: int in w:
			if matte.get_pixel(x, y).r >= LEVEL:
				inside += 1
	return float(inside) / float(w * h)


static func _mix(a: float, b: float) -> float:
	var span: float = b - a
	if absf(span) < 0.00001:
		return 0.5
	return clampf((LEVEL - a) / span, 0.0, 1.0)

extends RefCounted

## Small drawing pieces the effect panel kinds share.


static func s(v: float) -> float:
	return float(Tk.px(v))


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, width: float = 1.0, steps: int = 64) -> void:
	var pts := PackedVector2Array()
	for i: int in steps + 1:
		var a: float = TAU * float(i) / float(steps)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_polyline(pts, col, width, true)


static func ellipse_fill(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, steps: int = 48) -> void:
	var pts := PackedVector2Array()
	for i: int in steps:
		var a: float = TAU * float(i) / float(steps)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


static func dashed(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, width: float = 1.0, dash: float = 4.0, gap: float = 3.0) -> void:
	var length: float = a.distance_to(b)
	if length < 0.5:
		return
	var dir: Vector2 = (b - a) / length
	var at: float = 0.0
	while at < length:
		var end: float = minf(at + dash, length)
		ci.draw_line(a + dir * at, a + dir * end, col, width, true)
		at = end + gap


static func glow_dot(ci: CanvasItem, at: Vector2, r: float, core: Color, lit: bool) -> void:
	var halo: Color = core
	halo.a = 0.10 if not lit else 0.18
	ci.draw_circle(at, r * 2.3, halo)
	halo.a = 0.20 if not lit else 0.32
	ci.draw_circle(at, r * 1.55, halo)
	ci.draw_circle(at, r, core)
	var rim: Color = core.darkened(0.55)
	rim.a = 0.9
	ci.draw_arc(at, r, 0.0, TAU, 24, rim, 1.0, true)


static func waves(ci: CanvasItem, from: Vector2, toward: Vector2, col: Color, count: int = 3, first: float = 9.0, step: float = 5.0, spread: float = 0.6) -> void:
	var dir: Vector2 = toward - from
	if dir.length() < 1.0:
		return
	var a: float = dir.angle()
	for i: int in count:
		var c: Color = col
		c.a *= 1.0 - float(i) / float(count + 1)
		ci.draw_arc(from, s(first + step * float(i)), a - spread, a + spread, 12, c, 1.2, true)


static func arrow_head(ci: CanvasItem, tip: Vector2, dir: Vector2, size: float, col: Color) -> void:
	if dir.length() < 0.0001:
		return
	var d: Vector2 = dir.normalized()
	var side: Vector2 = Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([tip, tip - d * size + side * size * 0.55, tip - d * size - side * size * 0.55]), col)


## A listener seen from above, facing up the screen (front).
static func head_top(ci: CanvasItem, at: Vector2, r: float, fill: Color, line: Color, facing: float = 0.0) -> void:
	var fwd: Vector2 = Vector2(sin(facing), -cos(facing))
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var shoulders := PackedVector2Array()
	for i: int in 25:
		var a: float = TAU * float(i) / 24.0
		shoulders.append(at + side * cos(a) * r * 1.75 + fwd * (sin(a) * r * 0.7 - r * 0.15))
	var sh: Color = fill.darkened(0.25)
	ci.draw_colored_polygon(shoulders, sh)
	ci.draw_polyline(shoulders, Color(line, line.a * 0.5), 1.0, true)
	for e: float in [-1.0, 1.0]:
		ci.draw_circle(at + side * e * r * 0.98, r * 0.28, line)
	ci.draw_circle(at, r, fill)
	ci.draw_arc(at, r, 0.0, TAU, 32, line, 1.2, true)
	ci.draw_colored_polygon(PackedVector2Array([at + fwd * r * 1.45, at + fwd * r * 0.8 + side * r * 0.32, at + fwd * r * 0.8 - side * r * 0.32]), line)


## A listener seen from the side, facing right.
static func head_side(ci: CanvasItem, at: Vector2, r: float, fill: Color, line: Color) -> void:
	var neck := PackedVector2Array([at + Vector2(-r * 0.45, r * 0.7), at + Vector2(r * 0.25, r * 0.7), at + Vector2(r * 0.35, r * 1.7), at + Vector2(-r * 0.7, r * 1.7)])
	ci.draw_colored_polygon(neck, fill.darkened(0.25))
	var body := PackedVector2Array()
	for i: int in 13:
		var a: float = PI + PI * float(i) / 12.0
		body.append(at + Vector2(cos(a) * r * 1.6 - r * 0.2, r * 2.6 + sin(a) * r * 0.9))
	ci.draw_colored_polygon(body, fill.darkened(0.25))
	ci.draw_circle(at, r, fill)
	ci.draw_arc(at, r, 0.0, TAU, 32, line, 1.2, true)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(r * 1.35, r * 0.1), at + Vector2(r * 0.85, -r * 0.25), at + Vector2(r * 0.85, r * 0.35)]), line)
	ci.draw_circle(at + Vector2(-r * 0.1, r * 0.05), r * 0.26, line)


static func round_rect(ci: CanvasItem, r: Rect2, radius: float, fill: Color, border: Color = Color(0, 0, 0, 0), width: float = 1.0) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	if border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(int(maxf(1.0, width)))
	ci.draw_style_box(box, r)


static func nice_marks(lo: float, hi: float, room: int) -> PackedFloat32Array:
	var all: Array[float] = [0.5, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 30.0, 50.0, 100.0, 200.0, 300.0]
	var out := PackedFloat32Array()
	for v: float in all:
		if v > lo * 1.15 and v < hi * 0.999:
			out.append(v)
	while out.size() > room:
		var keep := PackedFloat32Array()
		for i: int in out.size():
			if i % 2 == 1 or i == out.size() - 1:
				keep.append(out[i])
		if keep.size() == out.size():
			break
		out = keep
	return out


static func metres(v: float) -> String:
	if v >= 10.0 or is_equal_approx(v, round(v)):
		return str(int(round(v))) + " m"
	return String.num(v, 1) + " m"

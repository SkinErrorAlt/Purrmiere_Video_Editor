extends "res://modules/core_panels/effect_panel_kind.gd"

## Where the light comes from, shown on a lit ball and on a small raised tile.
## Drag the sun round the ball to turn the light; with a "height" role, nearer
## the middle is higher up. Options "zero" (up, right, down or left) and "turn"
## (cw or ccw) say which way the effect counts its angle, the same words its
## monitor handle uses.

const D := preload("res://modules/core_panels/effect_panel_draw.gd")
const SUN := "sun"
const RINGS := 14
const SEGMENTS := 40
const BALL_DARK := Color(0.07, 0.075, 0.085)
const BALL_MID := Color(0.55, 0.56, 0.58)
const BALL_BRIGHT := Color(0.97, 0.97, 0.98)


func title() -> String:
	return "Light"


func roles() -> Dictionary:
	return {
		"angle": role("Light direction", true),
		"height": role("Light height", false),
	}


func height() -> float:
	return 150.0


func undo_label(_part: String) -> String:
	return "Move the light"


func tip(view: PanelView, part: String) -> String:
	if part == SUN:
		return "Drag the light round the ball" + (", towards the middle to raise it" if view.has("height") else "")
	return "Where the light comes from. Drag the sun round the ball."


func _zero(view: PanelView) -> Vector2:
	match String(view.option("zero", "up")):
		"right":
			return Vector2.RIGHT
		"left":
			return Vector2.LEFT
		"down":
			return Vector2.DOWN
	return Vector2.UP


func _dir_of(view: PanelView, deg: float) -> Vector2:
	var sign_: float = -1.0 if String(view.option("turn", "cw")) == "ccw" else 1.0
	return _zero(view).rotated(deg_to_rad(deg) * sign_)


func _deg_of(view: PanelView, dir: Vector2) -> float:
	var z: Vector2 = _zero(view)
	var sign_: float = -1.0 if String(view.option("turn", "cw")) == "ccw" else 1.0
	var a: float = rad_to_deg(z.angle_to(dir)) * sign_
	var lo: float = view.low("angle", -180.0)
	var hi: float = view.high("angle", 180.0)
	if lo >= 0.0 and a < 0.0:
		a += 360.0
	return clampf(a, lo, hi)


func _elev(view: PanelView) -> float:
	if view.has("height"):
		return deg_to_rad(clampf(view.value("height"), -89.0, 89.0))
	return deg_to_rad(float(view.option("height", 40.0)))


func _light(view: PanelView) -> Vector3:
	var d: Vector2 = _dir_of(view, view.value("angle"))
	var e: float = _elev(view)
	return Vector3(d.x * cos(e), d.y * cos(e), sin(e))


func _geo(view: PanelView) -> Dictionary:
	var r: Rect2 = view.stage()
	var foot: float = view.text_height("font_small") + D.s(8.0)
	var body := Rect2(r.position.x, r.position.y, r.size.x, r.size.y - foot)
	var rad: float = minf(body.size.y * 0.36, body.size.x * 0.22)
	var c: Vector2 = Vector2(body.position.x + body.size.x * (0.34 if r.size.x > D.s(240.0) else 0.5), body.get_center().y)
	var orbit: float = rad + D.s(13.0)
	return {"stage": r, "centre": c, "rad": rad, "orbit": orbit, "tile": r.size.x > D.s(240.0)}


func _sun_at(view: PanelView, g: Dictionary) -> Vector2:
	var d: Vector2 = _dir_of(view, view.value("angle"))
	var c: Vector2 = g["centre"]
	if not view.has("height"):
		return c + d * float(g["orbit"])
	var e: float = _elev(view)
	var reach: float = cos(e) * float(g["orbit"]) if e >= 0.0 else float(g["orbit"]) * (1.0 + absf(sin(e)) * 0.2)
	return c + d * maxf(reach, D.s(4.0))


func _shade(n: Vector3, l: Vector3) -> Color:
	var lam: float = maxf(n.dot(l), 0.0)
	var h: Vector3 = (l + Vector3(0, 0, 1)).normalized()
	var spec: float = pow(maxf(n.dot(h), 0.0), 28.0) * 0.55
	var dark: Color = BALL_DARK
	var mid: Color = BALL_MID
	var bright: Color = BALL_BRIGHT
	var c: Color = dark.lerp(mid, clampf(0.08 + lam * 0.92, 0.0, 1.0))
	return c.lerp(bright, clampf(spec + lam * lam * 0.25, 0.0, 1.0))


func draw(view: PanelView) -> void:
	var g: Dictionary = _geo(view)
	var c: Vector2 = g["centre"]
	var rad: float = float(g["rad"])
	var l: Vector3 = _light(view)
	var shadow_off: Vector2 = -Vector2(l.x, l.y) * rad * 0.35
	D.ellipse_fill(view, c + Vector2(0, rad * 0.92) + shadow_off * Vector2(1.0, 0.3), rad * 0.95, rad * 0.22, view.shadow(0.45))
	var rings: Array[PackedVector2Array] = []
	var cols: Array[PackedColorArray] = []
	for i: int in RINGS + 1:
		var rr: float = float(i) / float(RINGS)
		var pts := PackedVector2Array()
		var cs := PackedColorArray()
		for j: int in SEGMENTS:
			var a: float = TAU * float(j) / float(SEGMENTS)
			var x: float = cos(a) * rr
			var y: float = sin(a) * rr
			var z: float = sqrt(maxf(0.0, 1.0 - x * x - y * y))
			pts.append(c + Vector2(x, y) * rad)
			cs.append(_shade(Vector3(x, y, z), l))
		rings.append(pts)
		cols.append(cs)
	var centre_col: Color = _shade(Vector3(0, 0, 1), l)
	for j2: int in SEGMENTS:
		var k: int = (j2 + 1) % SEGMENTS
		view.draw_polygon(PackedVector2Array([c, rings[1][j2], rings[1][k]]), PackedColorArray([centre_col, cols[1][j2], cols[1][k]]))
	for i2: int in range(1, RINGS):
		for j3: int in SEGMENTS:
			var k2: int = (j3 + 1) % SEGMENTS
			view.draw_polygon(PackedVector2Array([rings[i2][j3], rings[i2 + 1][j3], rings[i2 + 1][k2], rings[i2][k2]]), PackedColorArray([cols[i2][j3], cols[i2 + 1][j3], cols[i2 + 1][k2], cols[i2][k2]]))
	view.draw_arc(c, rad, 0.0, TAU, 64, view.col("border_soft"), 1.0, true)
	var orbit: float = float(g["orbit"])
	for m: int in 72:
		var a0: float = TAU * float(m) / 72.0
		view.draw_arc(c, orbit, a0, a0 + TAU / 144.0, 2, view.col("border_soft"), 1.0, true)
	var z: Vector2 = _zero(view)
	view.draw_line(c + z * (orbit - D.s(3.0)), c + z * (orbit + D.s(3.0)), view.col("text_faint"), 1.0, true)
	var sun: Vector2 = _sun_at(view, g)
	var lit: bool = view.grab == SUN or view.hover == SUN
	var to_ball: Vector2 = (c - sun)
	if to_ball.length() > rad + D.s(6.0):
		var from: Vector2 = sun + to_ball.normalized() * D.s(9.0)
		var to: Vector2 = c - to_ball.normalized() * (rad + D.s(3.0))
		D.dashed(view, from, to, view.col("key_over", 0.7), 1.0, D.s(3.0), D.s(3.0))
	for ray: int in 8:
		var ra: float = TAU * float(ray) / 8.0
		var rv: Vector2 = Vector2(cos(ra), sin(ra))
		view.draw_line(sun + rv * D.s(7.5), sun + rv * D.s(10.5), view.col("key_over", 0.85), 1.2, true)
	D.glow_dot(view, sun, D.s(5.0), view.col("key_over").lerp(view.col("text_bright"), 0.35), lit)
	if bool(g["tile"]):
		_tile(view, g, l)
	var r: Rect2 = g["stage"]
	view.text(Vector2(r.position.x + D.s(8.0), r.end.y - D.s(8.0)), _words(view), "text", "font_small", r.size.x - D.s(16.0))


func _tile(view: PanelView, g: Dictionary, l: Vector3) -> void:
	var r: Rect2 = g["stage"]
	var rad: float = float(g["rad"])
	var side: float = rad * 1.5
	var c: Vector2 = Vector2(r.position.x + r.size.x * 0.76, (g["centre"] as Vector2).y)
	var outer := Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side))
	var bevel: float = side * 0.2
	var inner := outer.grow(-bevel)
	var flat: Color = _shade(Vector3(0, 0, 1), l)
	var s2: float = 0.70710678
	var faces: Array = [
		[PackedVector2Array([outer.position, Vector2(outer.end.x, outer.position.y), Vector2(inner.end.x, inner.position.y), inner.position]), Vector3(0, -s2, s2)],
		[PackedVector2Array([Vector2(outer.end.x, outer.position.y), outer.end, inner.end, Vector2(inner.end.x, inner.position.y)]), Vector3(s2, 0, s2)],
		[PackedVector2Array([outer.end, Vector2(outer.position.x, outer.end.y), Vector2(inner.position.x, inner.end.y), inner.end]), Vector3(0, s2, s2)],
		[PackedVector2Array([Vector2(outer.position.x, outer.end.y), outer.position, inner.position, Vector2(inner.position.x, inner.end.y)]), Vector3(-s2, 0, s2)],
	]
	view.draw_rect(outer.grow(D.s(5.0)), view.col("bg_panel"), true)
	for f: Array in faces:
		view.draw_colored_polygon(f[0] as PackedVector2Array, _shade(f[1] as Vector3, l))
	view.draw_rect(inner, flat, true)
	view.draw_rect(outer, view.col("border_soft"), false, 1.0)
	view.text(Vector2(outer.position.x - D.s(10.0), outer.end.y + D.s(14.0)), "Raised shape", "text_faint", "font_tiny", side + D.s(20.0), HORIZONTAL_ALIGNMENT_CENTER)


func _words(view: PanelView) -> String:
	var d: Vector2 = _dir_of(view, view.value("angle"))
	var parts: PackedStringArray = PackedStringArray()
	if d.y < -0.38:
		parts.append("top")
	elif d.y > 0.38:
		parts.append("bottom")
	if d.x < -0.38:
		parts.append("left")
	elif d.x > 0.38:
		parts.append("right")
	var from: String = "Light from the " + (" ".join(parts) if not parts.is_empty() else "middle")
	from += " (" + view.shown("angle") + ")"
	if view.has("height"):
		var h: float = view.value("height")
		if h > 80.0:
			from += ", straight on"
		elif h >= 15.0:
			from += ", " + view.shown("height") + " up"
		elif h >= 0.0:
			from += ", low, from the side"
		else:
			from += ", " + view.shown("height", absf(h)) + " from behind"
	return from


func _part(view: PanelView, at: Vector2) -> String:
	var g: Dictionary = _geo(view)
	if at.distance_to(_sun_at(view, g)) < D.s(14.0):
		return SUN
	if at.distance_to(g["centre"] as Vector2) < float(g["orbit"]) + D.s(10.0):
		return SUN
	return ""


func hover(view: PanelView, at: Vector2) -> String:
	return _part(view, at)


func press(view: PanelView, at: Vector2) -> String:
	var g: Dictionary = _geo(view)
	var part: String = _part(view, at)
	if part == SUN:
		view.frozen["offset"] = _sun_at(view, g) - at if at.distance_to(_sun_at(view, g)) < D.s(14.0) else Vector2.ZERO
	return part


func drag(view: PanelView, part: String, at: Vector2) -> Dictionary:
	if part != SUN:
		return {}
	var g: Dictionary = _geo(view)
	var v: Vector2 = at + (view.frozen.get("offset", Vector2.ZERO) as Vector2) - (g["centre"] as Vector2)
	if v.length() < 1.0:
		return {}
	var out: Dictionary = {"angle": _deg_of(view, v.normalized())}
	if view.has("height"):
		var reach: float = clampf(v.length() / float(g["orbit"]), 0.0, 1.0)
		out["height"] = clampf(rad_to_deg(acos(reach)), view.low("height", 0.0), view.high("height", 90.0))
	return out


func click(view: PanelView, part: String, at: Vector2) -> Dictionary:
	var g: Dictionary = _geo(view)
	if at.distance_to(_sun_at(view, g)) < D.s(14.0):
		return {}
	return drag(view, part, at)

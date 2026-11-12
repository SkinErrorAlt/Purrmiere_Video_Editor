extends "res://modules/core_panels/effect_panel_kind.gd"

## A sound placed around a listener's head: seen from above and behind (direction
## and distance) and from the side (height). Drag the sound in either view.
## Direction is in degrees, 0 in front, positive to the right.

const D := preload("res://modules/core_panels/effect_panel_draw.gd")
const SQUASH := 0.44
const LIFT := 0.85
const NEAR := 0.2
const GROUND := "ground"
const SIDE := "side"
const SPEED_OF_SOUND := 343.0
## The trip from the sound to your head is slowed this many times so it can be seen.
const SLOW := 60.0
const PULSE_EVERY := 0.14

var pulses: Array[Dictionary] = []
var _since: float = 0.0
var _last: float = 0.0


func title() -> String:
	return "Sound position"


func roles() -> Dictionary:
	return {
		"angle": role("Direction", true),
		"distance": role("Distance", false),
		"height": role("Height", false),
		"spin": role("Circle around", false),
	}


func height() -> float:
	return 210.0


func live() -> bool:
	return true


func toggles() -> Array:
	return [["waves", "Sound travelling to you while playing", true], ["ears", "Loudness at each ear while playing", true], ["rings", "Distance rings", true], ["side", "Height view", true], ["labels", "Labels", true]]


func tick(view: PanelView, dt: float) -> void:
	_since += dt
	var trip: float = _trip_seconds(view)
	for i: int in range(pulses.size() - 1, -1, -1):
		if view.live_clock - float(pulses[i]["born"]) > trip:
			pulses.remove_at(i)
	var lv: float = view.live_level
	if lv > 0.04 and (lv > _last * 1.3 + 0.03 or _since >= PULSE_EVERY):
		pulses.append({"born": view.live_clock, "strength": clampf(lv, 0.0, 1.0)})
		_since = 0.0
	_last = lv


func live_stop(_view: PanelView) -> void:
	pulses.clear()
	_since = 0.0
	_last = 0.0


func _trip_seconds(view: PanelView) -> float:
	var d: float = view.value("distance", 1.5) if view.has("distance") else 1.5
	return clampf(d / SPEED_OF_SOUND * SLOW, 0.08, 1.2)


func undo_label(part: String) -> String:
	return "Move the sound up or down" if part == SIDE else "Move the sound"


func tip(view: PanelView, part: String) -> String:
	if part == SIDE:
		return "Drag up or down to raise or lower the sound, out or in to move it away or closer"
	if part == GROUND:
		return "Drag to place the sound around you" + (", nearer or further" if view.has("distance") else "")
	return "Where the sound is, around your head. Drag it in either picture."


func _split(view: PanelView) -> Dictionary:
	var r: Rect2 = view.stage()
	var pad: float = D.s(8.0)
	var cap: float = view.text_height("font_tiny") + D.s(4.0)
	var foot: float = view.text_height("font_small") + D.s(6.0)
	var with_side: bool = view.has("height") and r.size.x >= D.s(250.0)
	var gw: float = r.size.x * (0.6 if with_side else 1.0)
	var ground := Rect2(r.position.x + pad, r.position.y + pad + cap, gw - pad * 2.0, r.size.y - pad * 2.0 - cap - foot)
	var side := Rect2(r.position.x + gw + pad * 0.5, ground.position.y, r.size.x - gw - pad * 1.5, ground.size.y)
	var rad: float = minf(ground.size.x * 0.46, ground.size.y / (2.0 * SQUASH + 0.3))
	var centre: Vector2 = Vector2(ground.get_center().x, ground.position.y + ground.size.y - rad * SQUASH - D.s(2.0))
	var lo: float = deg_to_rad(view.low("height", -90.0)) if view.has("height") else 0.0
	var hi: float = deg_to_rad(view.high("height", 90.0)) if view.has("height") else 0.0
	var up: float = maxf(sin(hi), 0.05)
	var down: float = maxf(-sin(lo), 0.05)
	var side_rad: float = minf(side.size.x - D.s(66.0), side.size.y / (up + down))
	var head_at: Vector2 = Vector2(side.position.x + D.s(24.0), side.position.y + side_rad * up)
	return {"stage": r, "ground": ground, "side": side, "with_side": with_side, "centre": centre, "rad": rad, "head": head_at, "side_rad": side_rad, "cap": cap, "pad": pad, "foot": foot}


func _reach(view: PanelView, d: float) -> float:
	if not view.has("distance"):
		return 0.72
	var lo: float = maxf(view.low("distance"), 0.01)
	var hi: float = maxf(view.high("distance"), lo * 1.01)
	if d < lo:
		return NEAR * maxf(d, 0.0) / lo
	return NEAR + (1.0 - NEAR) * clampf(log(d / lo) / log(hi / lo), 0.0, 1.0)


func _distance_of(view: PanelView, reach: float) -> float:
	var lo: float = maxf(view.low("distance"), 0.01)
	var hi: float = maxf(view.high("distance"), lo * 1.01)
	if reach <= NEAR:
		return lo
	return lo * exp(clampf((reach - NEAR) / (1.0 - NEAR), 0.0, 1.0) * log(hi / lo))


func _now(view: PanelView) -> Dictionary:
	var a: float = deg_to_rad(view.value("angle"))
	if view.live_on and view.has("spin"):
		a += view.value("spin") * TAU * view.clip_time()
	var h: float = deg_to_rad(view.value("height")) if view.has("height") else 0.0
	var d: float = view.value("distance", 1.0) if view.has("distance") else 1.0
	return {"a": a, "h": h, "reach": _reach(view, d)}


func _ground_point(g: Dictionary, a: float, reach_h: float) -> Vector2:
	var c: Vector2 = g["centre"]
	var rad: float = float(g["rad"])
	return c + Vector2(sin(a) * reach_h * rad, -cos(a) * reach_h * rad * SQUASH)


func _points(view: PanelView, g: Dictionary) -> Dictionary:
	var n: Dictionary = _now(view)
	var reach: float = float(n["reach"])
	var h: float = float(n["h"])
	var shadow: Vector2 = _ground_point(g, float(n["a"]), reach * cos(h))
	var dot: Vector2 = shadow - Vector2(0.0, reach * sin(h) * float(g["rad"]) * LIFT)
	var side_dot: Vector2 = (g["head"] as Vector2) + Vector2(cos(h), -sin(h)) * reach * float(g["side_rad"])
	return {"shadow": shadow, "dot": dot, "side": side_dot}


func draw(view: PanelView) -> void:
	var g: Dictionary = _split(view)
	var ground: Rect2 = g["ground"]
	var c: Vector2 = g["centre"]
	var rad: float = float(g["rad"])
	var line: Color = view.col("border_soft")
	var faint: Color = view.col("text_faint")
	view.text(Vector2(ground.position.x, ground.position.y - D.s(5.0)), "Around you", "text_faint")
	D.ellipse_fill(view, c, rad, rad * SQUASH, view.col("bg_panel", 0.9))
	if view.has("distance") and view.toggle("rings"):
		var marks: PackedFloat32Array = D.nice_marks(view.low("distance"), view.high("distance"), 3 if rad > D.s(70.0) else 2)
		for m: float in marks:
			var k: float = _reach(view, m)
			D.ellipse(view, c, rad * k, rad * k * SQUASH, line, 1.0)
			var words: String = D.metres(m)
			var w: float = view.text_width(words)
			view.text(c + Vector2(rad * k - w - D.s(3.0), -D.s(3.0)), words, "text_faint")
	D.ellipse(view, c, rad, rad * SQUASH, view.col("accent_dim"), 1.0)
	view.draw_line(c - Vector2(rad, 0.0), c + Vector2(rad, 0.0), view.col("border"), 1.0)
	view.draw_line(c - Vector2(0.0, rad * SQUASH), c + Vector2(0.0, rad * SQUASH), view.col("border"), 1.0)
	if view.toggle("labels"):
		view.text(Vector2(c.x - D.s(40.0), c.y - rad * SQUASH - D.s(3.0)), "Front", "text_dim", "font_tiny", D.s(80.0), HORIZONTAL_ALIGNMENT_CENTER)
		view.text(Vector2(c.x - rad - D.s(10.0), c.y + D.s(4.0)), "L", "text_faint")
		view.text(Vector2(c.x + rad + D.s(3.0), c.y + D.s(4.0)), "R", "text_faint")
	var p: Dictionary = _points(view, g)
	var n: Dictionary = _now(view)
	var spin: float = view.value("spin") if view.has("spin") else 0.0
	if absf(spin) > 0.0005:
		var a0: float = float(n["a"])
		var arc := PackedVector2Array()
		var steps: int = 20
		for i: int in steps + 1:
			var a: float = a0 + signf(spin) * deg_to_rad(70.0) * float(i) / float(steps)
			arc.append(_ground_point(g, a, 1.0))
		view.draw_polyline(arc, view.col("text_dim", 0.8), 1.4, true)
		D.arrow_head(view, arc[steps], arc[steps] - arc[steps - 1], D.s(6.0), view.col("text_dim"))
	var shadow: Vector2 = p["shadow"]
	var dot: Vector2 = p["dot"]
	D.dashed(view, c, shadow, faint, 1.0, D.s(3.0), D.s(3.0))
	D.ellipse_fill(view, shadow, D.s(6.0), D.s(6.0) * SQUASH, view.shadow(0.55))
	if shadow.distance_to(dot) > 1.0:
		D.dashed(view, shadow, dot, view.col("text_dim"), 1.0, D.s(2.0), D.s(2.0))
	D.head_top(view, c, D.s(8.0), view.col("bg_panel_high"), view.col("text_dim"))
	if view.live_on and view.toggle("ears"):
		for e: float in [-1.0, 1.0]:
			var lv: float = view.live_l if e < 0.0 else view.live_r
			if lv > 0.02:
				view.draw_circle(c + Vector2(e * D.s(9.0), 0.0), D.s(2.0) + D.s(3.5) * lv, view.col("accent", clampf(0.25 + lv, 0.0, 0.9)))
	var lit: bool = view.grab == GROUND or view.hover == GROUND
	if view.live_on and view.toggle("waves"):
		var trip: float = _trip_seconds(view)
		var dir: Vector2 = (c - dot).normalized()
		for pl: Dictionary in pulses:
			var t: float = (view.live_clock - float(pl["born"])) / trip
			if t <= 0.0 or t >= 1.0:
				continue
			var a2: float = float(pl["strength"]) * (1.0 - t * 0.7)
			view.draw_arc(dot.lerp(c, t), D.s(6.0 + 6.0 * t), dir.angle() - 0.8, dir.angle() + 0.8, 12, view.col("accent", minf(a2, 0.9)), 1.2 + a2, true)
	else:
		D.waves(view, dot, c, view.col("accent", 0.55), 3, 9.0, 4.5, 0.55)
	D.glow_dot(view, dot, D.s(5.5) * (1.0 + (view.live_level * 0.5 if view.live_on else 0.0)), view.col("accent"), lit or (view.live_on and view.live_level > 0.3))
	var words: String = _where(view)
	view.text(Vector2(ground.position.x, float((g["stage"] as Rect2).end.y) - D.s(8.0)), words, "text", "font_small", (g["stage"] as Rect2).size.x - D.s(16.0))
	if bool(g["with_side"]) and view.toggle("side"):
		_draw_side(view, g, p)


func _draw_side(view: PanelView, g: Dictionary, p: Dictionary) -> void:
	var side: Rect2 = g["side"]
	var head: Vector2 = g["head"]
	var srad: float = float(g["side_rad"])
	view.draw_line(Vector2(side.position.x - D.s(4.0), (g["stage"] as Rect2).position.y + D.s(10.0)), Vector2(side.position.x - D.s(4.0), (g["stage"] as Rect2).end.y - D.s(10.0)), view.col("border"), 1.0)
	view.text(Vector2(side.position.x + D.s(2.0), side.position.y - D.s(5.0)), "Height", "text_faint")
	var lo: float = deg_to_rad(view.low("height", -90.0))
	var hi: float = deg_to_rad(view.high("height", 90.0))
	var fan := PackedVector2Array([head])
	for i: int in 25:
		var a: float = lerpf(lo, hi, float(i) / 24.0)
		fan.append(head + Vector2(cos(a), -sin(a)) * srad)
	view.draw_colored_polygon(fan, view.col("bg_panel", 0.9))
	fan.append(head)
	view.draw_polyline(fan, view.col("border_soft"), 1.0, true)
	view.draw_line(head, head + Vector2(srad, 0.0), view.col("border_soft"), 1.0)
	view.text(head + Vector2(srad + D.s(4.0), D.s(4.0)), "Level", "text_faint")
	if hi > 0.35:
		view.text(head + Vector2(cos(hi), -sin(hi)) * srad + Vector2(D.s(5.0), D.s(9.0)), "Above", "text_faint")
	if lo < -0.35:
		view.text(head + Vector2(cos(lo), -sin(lo)) * srad + Vector2(D.s(5.0), D.s(2.0)), "Below", "text_faint")
	D.head_side(view, head, D.s(8.0), view.col("bg_panel_high"), view.col("text_dim"))
	var sd: Vector2 = p["side"]
	D.dashed(view, head, sd, view.col("text_faint"), 1.0, D.s(3.0), D.s(3.0))
	var lit: bool = view.grab == SIDE or view.hover == SIDE
	D.glow_dot(view, sd, D.s(5.5), view.col("accent"), lit)
	view.text(sd + Vector2(D.s(9.0), D.s(-7.0)), view.shown("height"), "text_dim", "font_tiny")


func _where(view: PanelView) -> String:
	var a: float = wrapf(view.value("angle"), -180.0, 180.0)
	var aa: float = absf(a)
	var side: String = "right" if a > 0.0 else "left"
	var dir: String = "In front"
	if aa > 165.0:
		dir = "Behind"
	elif aa > 115.0:
		dir = "Behind, to the " + side
	elif aa > 65.0:
		dir = "To the " + side
	elif aa > 15.0:
		dir = "In front, to the " + side
	var out: String = dir
	if view.has("distance"):
		out += ", " + view.shown("distance") + " away"
	if view.has("height"):
		var h: float = view.value("height")
		out += ", level" if absf(h) < 4.0 else (", raised " if h > 0.0 else ", lowered ") + view.shown("height", absf(h))
	return out


func _part_at(view: PanelView, g: Dictionary, at: Vector2) -> String:
	if bool(g["with_side"]) and (g["side"] as Rect2).grow(D.s(6.0)).has_point(at):
		return SIDE
	var ground: Rect2 = g["ground"]
	if ground.grow(D.s(8.0)).has_point(at):
		return GROUND
	var p: Dictionary = _points(view, g)
	if at.distance_to(p["dot"]) < D.s(14.0):
		return GROUND
	return ""


func hover(view: PanelView, at: Vector2) -> String:
	return _part_at(view, _split(view), at)


func press(view: PanelView, at: Vector2) -> String:
	var g: Dictionary = _split(view)
	var part: String = _part_at(view, g, at)
	if part == GROUND:
		var p: Dictionary = _points(view, g)
		var off: Vector2 = (p["shadow"] as Vector2) - (p["dot"] as Vector2)
		view.frozen["offset"] = off if at.distance_to(p["dot"]) < D.s(14.0) else Vector2.ZERO
	return part


func drag(view: PanelView, part: String, at: Vector2) -> Dictionary:
	return _place(view, part, at)


func click(view: PanelView, part: String, at: Vector2) -> Dictionary:
	var p: Dictionary = _points(view, _split(view))
	if part == GROUND and at.distance_to(p["dot"]) < D.s(14.0):
		return {}
	if part == SIDE and at.distance_to(p["side"]) < D.s(14.0):
		return {}
	return _place(view, part, at)


func _place(view: PanelView, part: String, at: Vector2) -> Dictionary:
	var g: Dictionary = _split(view)
	var out: Dictionary = {}
	if part == GROUND:
		var q: Vector2 = at + (view.frozen.get("offset", Vector2.ZERO) as Vector2) - (g["centre"] as Vector2)
		var rad: float = float(g["rad"])
		var x: float = q.x / rad
		var y: float = -q.y / (rad * SQUASH)
		var reach_h: float = Vector2(x, y).length()
		if reach_h < 0.02:
			return out
		var a: float = rad_to_deg(atan2(x, y))
		var lo: float = view.low("angle", -180.0)
		var hi: float = view.high("angle", 180.0)
		if lo >= 0.0 and a < 0.0:
			a += 360.0
		out["angle"] = clampf(a, lo, hi)
		if view.has("distance"):
			var h: float = deg_to_rad(view.value("height")) if view.has("height") else 0.0
			out["distance"] = _distance_of(view, minf(reach_h, 1.0) / maxf(cos(h), 0.15))
	elif part == SIDE:
		var v: Vector2 = at - (g["head"] as Vector2)
		var srad: float = float(g["side_rad"])
		var h2: float = rad_to_deg(atan2(-v.y, maxf(v.x, 0.001)))
		out["height"] = clampf(h2, view.low("height", -90.0), view.high("height", 90.0))
		if view.has("distance"):
			out["distance"] = _distance_of(view, minf(v.length() / srad, 1.0))
	return out

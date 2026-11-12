extends "res://modules/core_panels/effect_panel_kind.gd"

const D := preload("res://modules/core_panels/effect_panel_draw.gd")
const WHEELS: PackedStringArray = ["shadows", "midtones", "highlights"]
const NAMES: PackedStringArray = ["Shadows", "Midtones", "Highlights"]
const RINGS := 10
const SEGMENTS := 48
const PUCK := "puck_"
const LEVEL := "level_"


func title() -> String:
	return "Colour wheels"


func roles() -> Dictionary:
	var out: Dictionary = {}
	for i: int in WHEELS.size():
		var w: String = WHEELS[i]
		out[w + "_hue"] = role(NAMES[i] + " colour", true)
		out[w + "_amount"] = role(NAMES[i] + " push", true)
		out[w + "_level"] = role(NAMES[i] + " brightness", false)
	return out


func height() -> float:
	return 170.0


func undo_label(part: String) -> String:
	var w: String = part.trim_prefix(PUCK).trim_prefix(LEVEL)
	var i: int = WHEELS.find(w)
	var name: String = NAMES[i].to_lower() if i >= 0 else "colour"
	return ("Brighten or darken the " if part.begins_with(LEVEL) else "Push the colour of the ") + name


func tip(_view: PanelView, part: String) -> String:
	if part.begins_with(PUCK):
		return "Drag the dot towards a colour to push the " + part.trim_prefix(PUCK) + " that way; further out is stronger"
	if part.begins_with(LEVEL):
		return "Drag along the arc to brighten or darken the " + part.trim_prefix(LEVEL)
	return "Drag a dot inside a wheel to push shadows, midtones or highlights towards a colour"


func _geo(view: PanelView) -> Array[Dictionary]:
	var r: Rect2 = view.stage()
	var foot: float = view.text_height("font_small") + D.s(10.0)
	var cell_w: float = r.size.x / 3.0
	var rad: float = minf(cell_w * 0.36, (r.size.y - foot) * 0.36)
	var out: Array[Dictionary] = []
	for i: int in 3:
		var c := Vector2(r.position.x + cell_w * (float(i) + 0.5), r.position.y + (r.size.y - foot) * 0.5 + D.s(2.0))
		out.append({"centre": c, "rad": rad, "arc": rad + D.s(9.0), "label_at": Vector2(r.position.x + cell_w * float(i), r.end.y - D.s(6.0)), "cell_w": cell_w})
	return out


static func hue_colour(hue_deg: float, sat: float) -> Color:
	var c: Color = Color.from_hsv(fposmod(hue_deg, 360.0) / 360.0, 1.0, 1.0)
	return Color(0.5, 0.5, 0.5).lerp(c, clampf(sat, 0.0, 1.0))


static func puck_offset(hue_deg: float, amount01: float, rad: float) -> Vector2:
	var a: float = deg_to_rad(hue_deg - 90.0)
	return Vector2(cos(a), sin(a)) * clampf(amount01, 0.0, 1.0) * rad


static func hue_amount_of(offset: Vector2, rad: float) -> Vector2:
	var amt: float = clampf(offset.length() / maxf(rad, 0.001), 0.0, 1.0)
	var hue: float = fposmod(rad_to_deg(atan2(offset.y, offset.x)) + 90.0, 360.0)
	return Vector2(hue, amt)


func _level01(view: PanelView, w: String) -> float:
	if not view.has(w + "_level"):
		return 0.5
	return view.norm(w + "_level")


func _level_point(g: Dictionary, t: float) -> Vector2:
	var a: float = deg_to_rad(lerpf(150.0, 30.0, clampf(t, 0.0, 1.0)))
	return (g["centre"] as Vector2) + Vector2(cos(a), sin(a)) * float(g["arc"])


func draw(view: PanelView) -> void:
	var geo: Array[Dictionary] = _geo(view)
	for i: int in 3:
		var g: Dictionary = geo[i]
		var w: String = WHEELS[i]
		var c: Vector2 = g["centre"]
		var rad: float = float(g["rad"])
		var rings: Array[PackedVector2Array] = []
		var cols: Array[PackedColorArray] = []
		for ri: int in RINGS + 1:
			var rr: float = float(ri) / float(RINGS)
			var pts := PackedVector2Array()
			var cs := PackedColorArray()
			for j: int in SEGMENTS:
				var hue: float = 360.0 * float(j) / float(SEGMENTS)
				pts.append(c + puck_offset(hue, rr, rad))
				cs.append(hue_colour(hue, rr * 0.85))
			rings.append(pts)
			cols.append(cs)
		var mid_col: Color = hue_colour(0.0, 0.0)
		for j2: int in SEGMENTS:
			var k: int = (j2 + 1) % SEGMENTS
			view.draw_polygon(PackedVector2Array([c, rings[1][j2], rings[1][k]]), PackedColorArray([mid_col, cols[1][j2], cols[1][k]]))
		for ri2: int in range(1, RINGS):
			for j3: int in SEGMENTS:
				var k2: int = (j3 + 1) % SEGMENTS
				view.draw_polygon(PackedVector2Array([rings[ri2][j3], rings[ri2 + 1][j3], rings[ri2 + 1][k2], rings[ri2][k2]]), PackedColorArray([cols[ri2][j3], cols[ri2 + 1][j3], cols[ri2 + 1][k2], cols[ri2][k2]]))
		view.draw_arc(c, rad, 0.0, TAU, 64, view.col("border_soft"), 1.0, true)
		view.draw_line(c - Vector2(D.s(4.0), 0), c + Vector2(D.s(4.0), 0), Color(0, 0, 0, 0.45), 1.0, true)
		view.draw_line(c - Vector2(0, D.s(4.0)), c + Vector2(0, D.s(4.0)), Color(0, 0, 0, 0.45), 1.0, true)
		var lvl: float = _level01(view, w)
		if view.has(w + "_level"):
			var arc_pts := PackedVector2Array()
			for s: int in 25:
				arc_pts.append(_level_point(g, float(s) / 24.0))
			view.draw_polyline(arc_pts, view.col("border_soft"), D.s(3.0), true)
			var fill_pts := PackedVector2Array()
			var from_t: float = minf(0.5, lvl)
			var to_t: float = maxf(0.5, lvl)
			for s2: int in 13:
				fill_pts.append(_level_point(g, lerpf(from_t, to_t, float(s2) / 12.0)))
			view.draw_polyline(fill_pts, view.col("sol"), D.s(3.0), true)
			var knob: Vector2 = _level_point(g, lvl)
			var lit_l: bool = view.grab == LEVEL + w or view.hover == LEVEL + w
			D.glow_dot(view, knob, D.s(4.0), view.col("text_bright"), lit_l)
		var amt01: float = view.norm(w + "_amount")
		var at: Vector2 = c + puck_offset(view.value(w + "_hue"), amt01, rad)
		var lit: bool = view.grab == PUCK + w or view.hover == PUCK + w
		if amt01 > 0.001:
			view.draw_line(c, at, Color(1, 1, 1, 0.55), 1.0, true)
		view.draw_circle(at, D.s(6.0), Color(0, 0, 0, 0.55))
		view.draw_circle(at, D.s(4.5), hue_colour(view.value(w + "_hue"), amt01 * 0.85))
		view.draw_arc(at, D.s(5.5), 0.0, TAU, 24, view.col("text_bright") if lit else Color(1, 1, 1, 0.85), D.s(1.5), true)
		var la: Vector2 = g["label_at"]
		var words: String = NAMES[i]
		if amt01 > 0.001 or absf(lvl - 0.5) > 0.002:
			words += "  " + str(int(round(view.value(w + "_amount")))) + "%"
		view.text(la, words, "text", "font_small", float(g["cell_w"]), HORIZONTAL_ALIGNMENT_CENTER)


func _part(view: PanelView, at: Vector2) -> String:
	var geo: Array[Dictionary] = _geo(view)
	for i: int in 3:
		var g: Dictionary = geo[i]
		var w: String = WHEELS[i]
		var c: Vector2 = g["centre"]
		var puck: Vector2 = c + puck_offset(view.value(w + "_hue"), view.norm(w + "_amount"), float(g["rad"]))
		if at.distance_to(puck) < D.s(9.0):
			return PUCK + w
		if view.has(w + "_level") and at.distance_to(_level_point(g, _level01(view, w))) < D.s(9.0):
			return LEVEL + w
		if at.distance_to(c) <= float(g["rad"]) + D.s(3.0):
			return PUCK + w
		var d: float = at.distance_to(c)
		if view.has(w + "_level") and absf(d - float(g["arc"])) < D.s(7.0) and at.y > c.y:
			return LEVEL + w
	return ""


func hover(view: PanelView, at: Vector2) -> String:
	return _part(view, at)


func press(view: PanelView, at: Vector2) -> String:
	var part: String = _part(view, at)
	if part.is_empty():
		return ""
	var geo: Array[Dictionary] = _geo(view)
	var w: String = part.trim_prefix(PUCK).trim_prefix(LEVEL)
	var g: Dictionary = geo[WHEELS.find(w)]
	view.frozen["offset"] = Vector2.ZERO
	if part.begins_with(PUCK):
		var puck: Vector2 = (g["centre"] as Vector2) + puck_offset(view.value(w + "_hue"), view.norm(w + "_amount"), float(g["rad"]))
		if at.distance_to(puck) < D.s(9.0):
			view.frozen["offset"] = puck - at
	return part


func drag(view: PanelView, part: String, at: Vector2) -> Dictionary:
	var w: String = part.trim_prefix(PUCK).trim_prefix(LEVEL)
	var i: int = WHEELS.find(w)
	if i < 0:
		return {}
	var g: Dictionary = _geo(view)[i]
	var c: Vector2 = g["centre"]
	if part.begins_with(PUCK):
		var off: Vector2 = at + (view.frozen.get("offset", Vector2.ZERO) as Vector2) - c
		var ha: Vector2 = hue_amount_of(off, float(g["rad"]))
		var out: Dictionary = {w + "_amount": view.denorm(w + "_amount", ha.y)}
		if ha.y > 0.0005:
			out[w + "_hue"] = clampf(ha.x, view.low(w + "_hue", 0.0), view.high(w + "_hue", 360.0))
		return out
	var v: Vector2 = at - c
	var ang: float = rad_to_deg(atan2(v.y, v.x))
	var t: float = clampf(inverse_lerp(150.0, 30.0, clampf(ang, 30.0, 150.0)), 0.0, 1.0)
	if v.y < 0.0:
		t = 0.0 if v.x < 0.0 else 1.0
	return {w + "_level": view.denorm(w + "_level", t)}


func click(view: PanelView, part: String, at: Vector2) -> Dictionary:
	if part.begins_with(PUCK) and not (view.frozen.get("offset", Vector2.ZERO) as Vector2).is_zero_approx():
		return {}
	return drag(view, part, at)

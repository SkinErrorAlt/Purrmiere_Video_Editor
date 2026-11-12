extends "res://modules/core_panels/effect_panel_kind.gd"

## A picture turned in 3D in front of a camera. On the left the card, the camera
## and what the lens takes in, seen from the side; on the right the shape the
## picture makes in the frame. Drag left or right to swivel it, up or down to tilt
## it. The maths follows transform_extra's shader: tilt turns about the
## picture's across line, swivel about its up line, then the camera at its
## distance with its lens looks at it.

const D := preload("res://modules/core_panels/effect_panel_draw.gd")
const CARD := "card"
const DEG_PER_PX := 0.6
const ASPECT := 16.0 / 9.0
const OBLIQUE := Vector2(0.62, -0.36)
const CONE_MAX := 1.3


func title() -> String:
	return "Picture in 3D"


func roles() -> Dictionary:
	return {
		"tilt": role("Tilt", false),
		"swivel": role("Swivel", false),
		"distance": role("Camera distance", false),
		"lens": role("Lens", false),
		"scale": role("Scale", false),
	}


func height() -> float:
	return 170.0


func undo_label(_part: String) -> String:
	return "Turn the picture"


func tip(view: PanelView, part: String) -> String:
	if part == CARD:
		var ways: PackedStringArray = PackedStringArray()
		if view.has("swivel"):
			ways.append("left or right to swivel")
		if view.has("tilt"):
			ways.append("up or down to tilt")
		return "Drag " + " and ".join(ways)
	return "How the picture is turned in front of the camera"


func _rot(view: PanelView) -> Basis:
	var rx: float = deg_to_rad(view.value("tilt")) if view.has("tilt") else 0.0
	var ry: float = deg_to_rad(view.value("swivel")) if view.has("swivel") else 0.0
	var mx := Basis(Vector3(1, 0, 0), Vector3(0, cos(rx), -sin(rx)), Vector3(0, sin(rx), cos(rx)))
	var my := Basis(Vector3(cos(ry), 0, sin(ry)), Vector3(0, 1, 0), Vector3(-sin(ry), 0, cos(ry)))
	return my * mx


func _corner(rot: Basis, qx: float, qy: float) -> Vector3:
	return rot * Vector3(qx, qy, 0.0)


func _geo(view: PanelView) -> Dictionary:
	var r: Rect2 = view.stage()
	var foot: float = view.text_height("font_small") + D.s(8.0)
	var cap: float = view.text_height("font_tiny") + D.s(6.0)
	var wide: bool = r.size.x > D.s(250.0)
	var left := Rect2(r.position.x + D.s(8.0), r.position.y + cap + D.s(4.0), r.size.x * (0.56 if wide else 1.0) - D.s(12.0), r.size.y - cap - foot - D.s(10.0))
	var right := Rect2(r.position.x + r.size.x * 0.56 + D.s(6.0), left.position.y, r.size.x * 0.44 - D.s(14.0), left.size.y)
	var fw: float = minf(right.size.x, right.size.y * ASPECT)
	var frame := Rect2(right.get_center() - Vector2(fw, fw / ASPECT) * 0.5, Vector2(fw, fw / ASPECT))
	if view.frozen.has("k"):
		return {"stage": r, "left": left, "right": right, "frame": frame, "wide": wide, "k": view.frozen["k"], "o": view.frozen["o"], "cap": cap}
	var dist: float = view.value("distance", 1.5) if view.has("distance") else 1.5
	var lens: float = view.value("lens", 1.5) if view.has("lens") else 1.5
	var sc: float = maxf(view.value("scale", 1.0), 0.01) if view.has("scale") else 1.0
	var rot: Basis = _rot(view)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var half_w: float = minf(ASPECT * dist / (lens * sc), CONE_MAX * ASPECT)
	var half_h: float = minf(dist / (lens * sc), CONE_MAX)
	var pts: Array[Vector3] = [Vector3(0, 0, -dist), Vector3(-ASPECT * 1.15, 1.12, -dist), Vector3(ASPECT * 1.15, 1.12, 1.4)]
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			pts.append(_corner(rot, sx * ASPECT, sy))
			pts.append(Vector3(sx * half_w, sy * half_h, 0.0))
	for p: Vector3 in pts:
		var q: Vector2 = Vector2(p.x, p.y) + OBLIQUE * p.z
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var span: Vector2 = hi - lo
	var k: float = minf(left.size.x / span.x, left.size.y / span.y)
	var o: Vector2 = left.get_center() - (lo + hi) * 0.5 * k
	return {"stage": r, "left": left, "right": right, "frame": frame, "wide": wide, "k": k, "o": o, "cap": cap}


func _side(g: Dictionary, p: Vector3) -> Vector2:
	return (g["o"] as Vector2) + (Vector2(p.x, p.y) + OBLIQUE * p.z) * float(g["k"])


func draw(view: PanelView) -> void:
	var g: Dictionary = _geo(view)
	var left: Rect2 = g["left"]
	var rot: Basis = _rot(view)
	var dist: float = view.value("distance", 1.5) if view.has("distance") else 1.5
	var lens: float = view.value("lens", 1.5) if view.has("lens") else 1.5
	var sc: float = maxf(view.value("scale", 1.0), 0.01) if view.has("scale") else 1.0
	view.text(Vector2(left.position.x, left.position.y - D.s(6.0)), "The picture and the camera", "text_faint")
	var gx: float = ASPECT * 1.15
	var gy: float = 1.12
	var floor_pts := PackedVector2Array([_side(g, Vector3(-gx, gy, -dist)), _side(g, Vector3(gx, gy, -dist)), _side(g, Vector3(gx, gy, 1.4)), _side(g, Vector3(-gx, gy, 1.4))])
	view.draw_colored_polygon(floor_pts, view.col("bg_panel", 0.7))
	for i: int in 7:
		var z: float = lerpf(-dist, 1.4, float(i) / 6.0)
		view.draw_line(_side(g, Vector3(-gx, gy, z)), _side(g, Vector3(gx, gy, z)), view.col("lane_line"), 1.0, true)
	var cam: Vector3 = Vector3(0, 0, -dist)
	var half_w: float = minf(ASPECT * dist / (lens * sc), CONE_MAX * ASPECT)
	var half_h: float = minf(dist / (lens * sc), CONE_MAX)
	var reach: Array[Vector3] = [Vector3(-half_w, -half_h, 0), Vector3(half_w, -half_h, 0), Vector3(half_w, half_h, 0), Vector3(-half_w, half_h, 0)]
	var cone: Color = view.col("text_faint", 0.8)
	for p: Vector3 in reach:
		D.dashed(view, _side(g, cam), _side(g, p), cone, 1.0, D.s(3.0), D.s(3.0))
	var shown := PackedVector2Array()
	for p2: Vector3 in reach:
		shown.append(_side(g, p2))
	shown.append(shown[0])
	view.draw_polyline(shown, view.col("border_soft"), 1.0, true)
	var corners: Array[Vector3] = [_corner(rot, -ASPECT, -1.0), _corner(rot, ASPECT, -1.0), _corner(rot, ASPECT, 1.0), _corner(rot, -ASPECT, 1.0)]
	var card := PackedVector2Array()
	for cpt: Vector3 in corners:
		card.append(_side(g, cpt))
	var facing: float = (rot * Vector3(0, 0, 1)).z
	var lit: bool = view.grab == CARD or view.hover == CARD
	view.draw_colored_polygon(card, view.col("bg_panel_high").lightened(0.04 if facing > 0.0 else -0.2))
	_grid(view, rot, g)
	var edge: PackedVector2Array = card.duplicate()
	edge.append(edge[0])
	view.draw_polyline(edge, view.col("accent") if lit else view.col("text_dim"), 1.4 if lit else 1.0, true)
	view.draw_line(card[0], card[1], view.col("accent"), 2.0, true)
	_camera(view, _side(g, cam), float(g["k"]))
	if bool(g["wide"]):
		_frame(view, g, rot, dist, lens, sc)
	var r: Rect2 = g["stage"]
	view.text(Vector2(r.position.x + D.s(8.0), r.end.y - D.s(8.0)), _words(view), "text", "font_small", r.size.x - D.s(16.0))


func _grid(view: PanelView, rot: Basis, g: Dictionary) -> void:
	var c: Color = view.col("text_faint", 0.55)
	for i: int in range(1, 4):
		var x: float = lerpf(-ASPECT, ASPECT, float(i) / 4.0)
		view.draw_line(_side(g, _corner(rot, x, -1.0)), _side(g, _corner(rot, x, 1.0)), c, 1.0, true)
	for j: int in range(1, 3):
		var y: float = lerpf(-1.0, 1.0, float(j) / 3.0)
		view.draw_line(_side(g, _corner(rot, -ASPECT, y)), _side(g, _corner(rot, ASPECT, y)), c, 1.0, true)


func _camera(view: PanelView, at: Vector2, k: float) -> void:
	var w: float = clampf(0.36 * k, D.s(9.0), D.s(16.0))
	var body := Rect2(at + Vector2(-w * 1.1, -w * 0.32), Vector2(w, w * 0.64))
	D.round_rect(view, body, D.s(2.0), view.col("bg_panel_high"), view.col("text_dim"))
	view.draw_colored_polygon(PackedVector2Array([at + Vector2(-w * 0.1, -w * 0.18), at + Vector2(w * 0.25, -w * 0.3), at + Vector2(w * 0.25, w * 0.3), at + Vector2(-w * 0.1, w * 0.18)]), view.col("text_dim"))
	view.draw_circle(body.position + Vector2(w * 0.28, -w * 0.05), w * 0.16, view.col("bg_panel_high"))
	view.draw_arc(body.position + Vector2(w * 0.28, -w * 0.05), w * 0.16, 0.0, TAU, 12, view.col("text_dim"), 1.0, true)


func _project(p: Vector3, dist: float, lens: float, sc: float) -> Vector3:
	var depth: float = p.z + dist
	if depth <= 0.02:
		return Vector3(0, 0, -1)
	var px: float = lens * p.x / depth
	var py: float = lens * p.y / depth
	return Vector3(px * sc / (2.0 * ASPECT) + 0.5, py * sc / 2.0 + 0.5, 1)


func _frame(view: PanelView, g: Dictionary, rot: Basis, dist: float, lens: float, sc: float) -> void:
	var frame: Rect2 = g["frame"]
	view.text(Vector2(frame.position.x, (g["left"] as Rect2).position.y - D.s(6.0)), "What the camera sees", "text_faint", "font_tiny", frame.size.x)
	view.draw_rect(frame, view.shadow(0.6), true)
	var quad := PackedVector2Array()
	var behind: bool = false
	for q: Vector2 in [Vector2(-ASPECT, -1.0), Vector2(ASPECT, -1.0), Vector2(ASPECT, 1.0), Vector2(-ASPECT, 1.0)]:
		var uv: Vector3 = _project(_corner(rot, q.x, q.y), dist, lens, sc)
		if uv.z < 0.0:
			behind = true
			break
		quad.append(frame.position + Vector2(uv.x, uv.y) * frame.size)
	if behind:
		view.text_in(frame, "Turned away from the camera", "text_dim", "font_tiny", HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var clip := _clip_to(quad, frame)
		if clip.size() >= 3:
			view.draw_colored_polygon(clip, view.col("bg_panel_high").lightened(0.06))
		for i: int in range(1, 4):
			var a: Vector3 = _project(_corner(rot, lerpf(-ASPECT, ASPECT, float(i) / 4.0), -1.0), dist, lens, sc)
			var b: Vector3 = _project(_corner(rot, lerpf(-ASPECT, ASPECT, float(i) / 4.0), 1.0), dist, lens, sc)
			_clipped_line(view, frame, frame.position + Vector2(a.x, a.y) * frame.size, frame.position + Vector2(b.x, b.y) * frame.size, view.col("text_faint", 0.55))
		for j: int in range(1, 3):
			var a2: Vector3 = _project(_corner(rot, -ASPECT, lerpf(-1.0, 1.0, float(j) / 3.0)), dist, lens, sc)
			var b2: Vector3 = _project(_corner(rot, ASPECT, lerpf(-1.0, 1.0, float(j) / 3.0)), dist, lens, sc)
			_clipped_line(view, frame, frame.position + Vector2(a2.x, a2.y) * frame.size, frame.position + Vector2(b2.x, b2.y) * frame.size, view.col("text_faint", 0.55))
		for e: int in 4:
			var col: Color = view.col("accent") if e == 0 else view.col("text_dim")
			_clipped_line(view, frame, quad[e], quad[(e + 1) % 4], col, 2.0 if e == 0 else 1.0)
	view.draw_rect(frame, view.col("border_soft"), false, 1.0)


func _clip_to(poly: PackedVector2Array, r: Rect2) -> PackedVector2Array:
	var box := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var hits: Array[PackedVector2Array] = Geometry2D.intersect_polygons(poly, box)
	return hits[0] if not hits.is_empty() else PackedVector2Array()


func _clipped_line(view: PanelView, r: Rect2, a: Vector2, b: Vector2, col: Color, width: float = 1.0) -> void:
	var t0: float = 0.0
	var t1: float = 1.0
	var d: Vector2 = b - a
	for axis: int in 2:
		var lo: float = r.position[axis]
		var hi: float = r.end[axis]
		if absf(d[axis]) < 0.00001:
			if a[axis] < lo or a[axis] > hi:
				return
			continue
		var ta: float = (lo - a[axis]) / d[axis]
		var tb: float = (hi - a[axis]) / d[axis]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	if t1 > t0:
		view.draw_line(a + d * t0, a + d * t1, col, width, true)


func _words(view: PanelView) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if view.has("tilt"):
		var t: float = view.value("tilt")
		parts.append("Upright" if absf(t) < 0.5 else ("Top leans away " if t > 0.0 else "Top leans towards you ") + view.shown("tilt", absf(t)))
	if view.has("swivel"):
		var s_: float = view.value("swivel")
		parts.append("facing straight on" if absf(s_) < 0.5 else ("right side turned away " if s_ > 0.0 else "left side turned away ") + view.shown("swivel", absf(s_)))
	return ", ".join(parts)


func _part(view: PanelView, at: Vector2) -> String:
	var g: Dictionary = _geo(view)
	if (g["left"] as Rect2).grow(D.s(6.0)).has_point(at):
		return CARD
	if bool(g["wide"]) and (g["frame"] as Rect2).grow(D.s(6.0)).has_point(at):
		return CARD
	return ""


func hover(view: PanelView, at: Vector2) -> String:
	return _part(view, at)


func press(view: PanelView, at: Vector2) -> String:
	var part: String = _part(view, at)
	if not part.is_empty():
		var g: Dictionary = _geo(view)
		view.frozen["k"] = g["k"]
		view.frozen["o"] = g["o"]
	return part


func drag(view: PanelView, part: String, at: Vector2) -> Dictionary:
	if part != CARD:
		return {}
	var move: Vector2 = at - view.press_at
	var out: Dictionary = {}
	if view.has("swivel"):
		out["swivel"] = view.start_value("swivel") + move.x * DEG_PER_PX / maxf(Tk.ui_scale, 0.5)
	if view.has("tilt"):
		out["tilt"] = view.start_value("tilt") - move.y * DEG_PER_PX / maxf(Tk.ui_scale, 0.5)
	return out

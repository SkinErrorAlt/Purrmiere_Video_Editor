extends "res://modules/core_panels/effect_panel_kind.gd"

## Two speakers in front of the listener and where the sound sits between them.
## "pan" places it (-1 left to 1 right). "sweep" is how far an automatic pan
## swings either side; "start", "shape" and "rate" only add to the picture.

const D := preload("res://modules/core_panels/effect_panel_draw.gd")
const SPREAD := 0.95
const SPOT := "spot"
const EDGE := "edge"
## Sound from the speakers drawn at a slowed pace the eye can follow.
const TRAVEL_SECONDS := 0.32
const PULSE_EVERY := 0.14

var pulses: Array[Dictionary] = []
var _since: float = 0.0
var _last: float = 0.0


func title() -> String:
	return "Speakers"


func roles() -> Dictionary:
	return {
		"pan": role("Position", false),
		"sweep": role("Swing", false),
		"start": role("Start position", false),
		"shape": role("Shape", false, TYPES_CHOICE),
		"rate": role("Rate", false),
	}


func height() -> float:
	return 150.0


func live() -> bool:
	return true


func toggles() -> Array:
	return [["waves", "Sound going out to the speakers while playing", true], ["labels", "Labels", true]]


func tick(view: PanelView, _dt: float) -> void:
	_since += _dt
	for i: int in range(pulses.size() - 1, -1, -1):
		if view.live_clock - float(pulses[i]["born"]) > TRAVEL_SECONDS:
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


## Where the sound is right now: Pan's value, or for Auto Pan the swing worked out from the clip time, the same
## shapes the effect uses.
func _x_now(view: PanelView) -> float:
	if view.has("pan"):
		return view.value("pan")
	if view.live_on and view.has("rate"):
		return _swing_at(view, view.value("start") + view.value("rate") * view.clip_time())
	return _start_x(view)


func _swing_at(view: PanelView, ph: float) -> float:
	var depth: float = view.value("sweep")
	var shape: int = int(view.value("shape")) if view.has("shape") else 0
	var w: float = 0.0
	match shape:
		1:
			var t: float = fposmod(ph + 0.25, 1.0)
			w = 1.0 - 4.0 * absf(t - 0.5)
		2:
			w = 1.0 if fposmod(ph, 1.0) < 0.5 else -1.0
		3:
			w = fposmod(ph, 1.0) * 2.0 - 1.0
		4:
			w = 1.0 - fposmod(ph, 1.0) * 2.0
		_:
			w = sin(TAU * ph)
	return clampf(w * depth, -1.0, 1.0)


func undo_label(part: String) -> String:
	return "Change the swing" if part == EDGE else "Move the sound"


func tip(view: PanelView, part: String) -> String:
	if part == EDGE:
		return "Drag the ends out or in to swing further or less"
	if part == SPOT:
		return "Drag the sound between the speakers"
	return "Where the sound plays between the two speakers" if view.has("pan") else "How far the sound swings between the speakers"


func _geo(view: PanelView) -> Dictionary:
	var r: Rect2 = view.stage()
	var foot: float = view.text_height("font_small") + D.s(8.0)
	var c: Vector2 = Vector2(r.get_center().x, r.end.y - foot - D.s(12.0))
	var ry: float = maxf(r.size.y - foot - D.s(40.0), D.s(30.0))
	var rx: float = minf(r.size.x * 0.4 / sin(SPREAD * 1.15), ry * 2.2)
	return {"stage": r, "centre": c, "rad": ry, "rx": rx, "foot": foot}


func _arc_point(g: Dictionary, x: float) -> Vector2:
	var a: float = clampf(x, -1.2, 1.2) * SPREAD
	return (g["centre"] as Vector2) + Vector2(sin(a) * float(g["rx"]), -cos(a) * float(g["rad"]))


func _x_of(g: Dictionary, at: Vector2) -> float:
	var v: Vector2 = at - (g["centre"] as Vector2)
	return clampf(atan2(v.x / float(g["rx"]), -v.y / float(g["rad"])) / SPREAD, -1.0, 1.0)


func _start_x(view: PanelView) -> float:
	var depth: float = view.value("sweep")
	var ph: float = view.value("start") if view.has("start") else 0.0
	var shape: int = int(view.value("shape")) if view.has("shape") else 0
	var w: float = 0.0
	match shape:
		1:
			var t: float = fposmod(ph + 0.25, 1.0)
			w = 1.0 - 4.0 * absf(t - 0.5)
		2:
			w = 1.0 if fposmod(ph, 1.0) < 0.5 else -1.0
		3:
			w = fposmod(ph, 1.0) * 2.0 - 1.0
		4:
			w = 1.0 - fposmod(ph, 1.0) * 2.0
		_:
			w = sin(TAU * ph)
	return clampf(w * depth, -1.0, 1.0)


func draw(view: PanelView) -> void:
	var g: Dictionary = _geo(view)
	var c: Vector2 = g["centre"]
	var rad: float = float(g["rad"])
	var r: Rect2 = g["stage"]
	var arc := PackedVector2Array()
	for i: int in 41:
		arc.append(_arc_point(g, lerpf(-1.0, 1.0, float(i) / 40.0)))
	var floor_pts := PackedVector2Array([c])
	floor_pts.append_array(arc)
	view.draw_colored_polygon(floor_pts, view.col("bg_panel", 0.9))
	view.draw_polyline(arc, view.col("border_soft"), 1.0, true)
	for k: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		var p: Vector2 = _arc_point(g, k)
		view.draw_line(p, p.lerp(c, 0.08), view.col("text_faint"), 1.0, true)
	view.draw_line(c, _arc_point(g, 0.0), view.col("border"), 1.0)
	for e: float in [-1.0, 1.0]:
		var push: float = (view.live_l if e < 0.0 else view.live_r) if view.live_on else 0.0
		_speaker(view, _arc_point(g, e * 1.12), c, push)
	if view.toggle("labels"):
		view.text(_arc_point(g, -1.12) + Vector2(-D.s(6.0), D.s(22.0)), "Left", "text_faint")
		view.text(_arc_point(g, 1.12) + Vector2(-D.s(10.0), D.s(22.0)), "Right", "text_faint")
	if view.live_on and view.toggle("waves"):
		_live_waves(view, g)
	D.head_top(view, c, D.s(7.0), view.col("bg_panel_high"), view.col("text_dim"))
	var words: String = ""
	if view.has("sweep"):
		var depth: float = view.value("sweep")
		var band := PackedVector2Array()
		for i: int in 33:
			band.append(_arc_point(g, lerpf(-depth, depth, float(i) / 32.0)))
		var lit: bool = view.grab == EDGE or view.hover == EDGE
		view.draw_polyline(band, view.col("accent", 0.22), D.s(9.0), true)
		view.draw_polyline(band, view.col("accent", 0.85 if lit else 0.6), D.s(2.0), true)
		for e2: float in [-1.0, 1.0]:
			var end: Vector2 = _arc_point(g, e2 * depth)
			view.draw_circle(end, D.s(4.5 if lit else 3.5), view.col("accent"))
			D.arrow_head(view, _arc_point(g, e2 * minf(depth + 0.07, 1.15)), _arc_point(g, e2 * minf(depth + 0.07, 1.15)) - end, D.s(5.0), view.col("accent", 0.6))
		var sx: float = _x_now(view)
		var sp: Vector2 = _arc_point(g, sx)
		D.waves(view, sp, c, view.col("accent", 0.5), 2, 8.0, 4.5, 0.5)
		view.draw_circle(sp, D.s(3.0), view.col("bg_shell"))
		view.draw_arc(sp, D.s(3.0), 0.0, TAU, 16, view.col("accent"), 1.2, true)
		words = "Swings " + str(int(round(depth * 100.0))) + "% of the way to each side"
		if view.has("rate"):
			words += ", " + view.shown("rate")
	if view.has("pan"):
		var x: float = view.value("pan")
		var spot: Vector2 = _arc_point(g, x)
		var lit2: bool = view.grab == SPOT or view.hover == SPOT
		D.dashed(view, c, spot, view.col("text_faint"), 1.0, D.s(3.0), D.s(3.0))
		D.waves(view, spot, c, view.col("accent", 0.55), 3, 9.0, 4.5, 0.55)
		D.glow_dot(view, spot, D.s(5.5) * (1.0 + (view.live_level * 0.5 if view.live_on else 0.0)), view.col("accent"), lit2 or (view.live_on and view.live_level > 0.3))
		words = _pan_words(x)
	view.text(Vector2(r.position.x + D.s(8.0), r.end.y - D.s(8.0)), words, "text", "font_small", r.size.x - D.s(16.0))


## Pulses running from the sound to each speaker, as strong as the pan sends to that side (equal power law) and
## as loud as the clip is when each left.
func _live_waves(view: PanelView, g: Dictionary) -> void:
	var x: float = _x_now(view)
	var from: Vector2 = _arc_point(g, x)
	var gains: Array[float] = [cos((x + 1.0) * PI * 0.25), sin((x + 1.0) * PI * 0.25)]
	for pl: Dictionary in pulses:
		var t: float = (view.live_clock - float(pl["born"])) / TRAVEL_SECONDS
		if t <= 0.0 or t >= 1.0:
			continue
		for i: int in 2:
			var to: Vector2 = _arc_point(g, -1.12 if i == 0 else 1.12)
			var a: float = float(pl["strength"]) * gains[i] * (1.0 - t)
			if a < 0.04:
				continue
			var at: Vector2 = from.lerp(to, t)
			var dir: Vector2 = (to - from).normalized()
			var rr: float = D.s(5.0 + 7.0 * t)
			view.draw_arc(at, rr, dir.angle() - 0.7, dir.angle() + 0.7, 12, view.col("accent", minf(a, 0.9)), 1.2 + a, true)


func _speaker(view: PanelView, at: Vector2, toward: Vector2, push: float = 0.0) -> void:
	var dir: Vector2 = (toward - at).normalized()
	var across: Vector2 = Vector2(-dir.y, dir.x)
	var w: float = D.s(12.0)
	var h: float = D.s(16.0)
	if push > 0.02:
		for k: int in 2:
			var rr: float = D.s(10.0 + 7.0 * float(k)) * (1.0 + push * 0.4)
			view.draw_arc(at, rr, dir.angle() - 0.6, dir.angle() + 0.6, 14, view.col("accent", clampf(push * (0.75 - 0.3 * float(k)), 0.0, 0.8)), 1.2, true)
		w *= 1.0 + push * 0.12
	var body := PackedVector2Array([at - across * w * 0.5 - dir * h * 0.5, at + across * w * 0.5 - dir * h * 0.5, at + across * w * 0.5 + dir * h * 0.5, at - across * w * 0.5 + dir * h * 0.5])
	view.draw_colored_polygon(body, view.col("bg_panel_high"))
	body.append(body[0])
	view.draw_polyline(body, view.col("text_dim"), 1.0, true)
	view.draw_circle(at + dir * h * 0.18, w * 0.28, view.col("text_dim"))
	view.draw_circle(at - dir * h * 0.28, w * 0.13, view.col("text_dim"))


func _pan_words(x: float) -> String:
	if absf(x) < 0.03:
		return "In the middle, the same in both speakers"
	var side: String = "right" if x > 0.0 else "left"
	if absf(x) > 0.97:
		return "All the way " + side
	return str(int(round(absf(x) * 100.0))) + "% to the " + side


func _part(view: PanelView, g: Dictionary, at: Vector2) -> String:
	var r: Rect2 = g["stage"]
	if not r.has_point(at):
		return ""
	if view.has("sweep"):
		var depth: float = view.value("sweep")
		for e: float in [-1.0, 1.0]:
			if at.distance_to(_arc_point(g, e * depth)) < D.s(12.0):
				return EDGE
		if not view.has("pan"):
			var v: Vector2 = at - (g["centre"] as Vector2)
			var e2: Vector2 = Vector2(v.x / float(g["rx"]), v.y / float(g["rad"]))
			if absf(e2.length() - 1.0) * float(g["rad"]) < D.s(18.0):
				return EDGE
	if view.has("pan"):
		return SPOT
	return ""


func hover(view: PanelView, at: Vector2) -> String:
	return _part(view, _geo(view), at)


func press(view: PanelView, at: Vector2) -> String:
	return _part(view, _geo(view), at)


func drag(view: PanelView, part: String, at: Vector2) -> Dictionary:
	var g: Dictionary = _geo(view)
	var x: float = _x_of(g, at)
	if part == EDGE:
		return {"sweep": absf(x)}
	if part == SPOT:
		return {"pan": x}
	return {}


func click(view: PanelView, part: String, at: Vector2) -> Dictionary:
	if part == SPOT:
		return drag(view, part, at)
	return {}

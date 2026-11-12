extends "res://modules/core_panels/effect_panel_kind.gd"

## A sound going past the listener along a straight road, seen from above. The
## rings it sends out bunch up ahead of it and spread out behind, which is the
## rise and fall in pitch. Drag the road nearer or further; drag or click the
## sound to send it the other way.

const D := preload("res://modules/core_panels/effect_panel_draw.gd")
const SOUND_KMH := 1235.0
const ROAD := "road"
const CAR := "car"
const EMIT_EVERY := 0.07
const MAX_RINGS := 26

var rings: Array[Dictionary] = []
var _since: float = 0.0


func title() -> String:
	return "Pass by"


func roles() -> Dictionary:
	return {
		"closest": role("Closest distance", true),
		"direction": role("Direction", false, TYPES_CHOICE),
		"speed": role("Speed", false),
		"bend": role("Pitch bend", false),
		"pass_at": role("Passes at", false),
	}


func height() -> float:
	return 176.0


func live() -> bool:
	return true


func toggles() -> Array:
	return [["rings", "Sound rings from the moving source while playing", true], ["labels", "Distances and words", true]]


## While playing, the source sends a ring from wherever it is every few hundredths of a second, as strong as the
## sound then. Rings keep their own centre, so they crowd ahead of it and spread behind: the real Doppler picture.
func tick(view: PanelView, dt: float) -> void:
	_since += dt
	var g: Dictionary = _geo(view)
	var span: float = float((g["stage"] as Rect2).size.x)
	for i: int in range(rings.size() - 1, -1, -1):
		var age: float = view.live_clock - float(rings[i]["born"])
		if age * _ring_speed(view, g) > span * 0.55:
			rings.remove_at(i)
	if _since >= EMIT_EVERY and view.toggle("rings"):
		_since = 0.0
		rings.append({"born": view.live_clock, "at": _car_at(view, g), "strength": clampf(0.25 + view.live_level, 0.0, 1.0)})
		while rings.size() > MAX_RINGS:
			rings.remove_at(0)


func live_stop(_view: PanelView) -> void:
	rings.clear()
	_since = 0.0


## Pixels a metre, measured at the road, so the car's speed on screen matches its km/h against the distance shown.
func _px_per_m(view: PanelView, g: Dictionary) -> float:
	var gap: float = (g["me"] as Vector2).y - _road_y(view, g)
	return gap / maxf(view.value("closest", 4.0), 0.1)


func _car_speed_px(view: PanelView, g: Dictionary) -> float:
	var kmh: float = view.value("speed", 100.0) if view.has("speed") else 100.0
	return kmh / 3.6 * _px_per_m(view, g) * 0.35


## Rings travel faster than the car by the speed of sound over the car's speed (bent by Pitch bend), kept in a range
## the eye can follow.
func _ring_speed(view: PanelView, g: Dictionary) -> float:
	var m: float = 0.0
	if view.has("speed"):
		m = clampf(view.value("speed") / SOUND_KMH, 0.0, 0.9) * 1.6
	if view.has("bend"):
		m *= view.value("bend")
	m = clampf(m * 2.6, 0.12, 0.8)
	return _car_speed_px(view, g) / m


func undo_label(part: String) -> String:
	return "Change the way it goes" if part == CAR else "Move the road"


func tip(view: PanelView, part: String) -> String:
	if part == CAR:
		return "Click to send it the other way, or drag it nearer or further" if view.has("direction") else "Drag it nearer or further"
	if part == ROAD:
		return "Drag the road nearer to you or further away"
	return "The path of the sound as it goes past you"


func _geo(view: PanelView) -> Dictionary:
	var r: Rect2 = view.stage()
	var foot: float = view.text_height("font_small") + D.s(8.0)
	var me: Vector2 = Vector2(r.get_center().x, r.end.y - foot - D.s(16.0))
	var top: float = r.position.y + D.s(30.0)
	return {"stage": r, "me": me, "top": top, "span": me.y - top, "foot": foot}


func _reach(view: PanelView, d: float) -> float:
	var lo: float = maxf(view.low("closest", 1.0), 0.01)
	var hi: float = maxf(view.high("closest", 50.0), lo * 1.01)
	return 0.18 + 0.82 * clampf(log(maxf(d, lo) / lo) / log(hi / lo), 0.0, 1.0)


func _closest_of(view: PanelView, reach: float) -> float:
	var lo: float = maxf(view.low("closest", 1.0), 0.01)
	var hi: float = maxf(view.high("closest", 50.0), lo * 1.01)
	return lo * exp(clampf((reach - 0.18) / 0.82, 0.0, 1.0) * log(hi / lo))


func _road_y(view: PanelView, g: Dictionary) -> float:
	return (g["me"] as Vector2).y - _reach(view, view.value("closest")) * float(g["span"])


func _going(view: PanelView) -> float:
	return -1.0 if view.has("direction") and int(round(view.value("direction"))) == 1 else 1.0


func _car_at(view: PanelView, g: Dictionary) -> Vector2:
	var r: Rect2 = g["stage"]
	if view.live_on:
		var pass_at: float = view.value("pass_at", 1.5) if view.has("pass_at") else view.clip_length() * 0.5
		var x: float = (g["me"] as Vector2).x + _going(view) * (view.clip_time() - pass_at) * _car_speed_px(view, g)
		return Vector2(clampf(x, r.position.x - D.s(30.0), r.end.x + D.s(30.0)), _road_y(view, g))
	return Vector2((g["me"] as Vector2).x - _going(view) * r.size.x * 0.2, _road_y(view, g))


func draw(view: PanelView) -> void:
	var g: Dictionary = _geo(view)
	var r: Rect2 = g["stage"]
	var me: Vector2 = g["me"]
	var y: float = _road_y(view, g)
	var half: float = D.s(7.0)
	var left: float = r.position.x + D.s(6.0)
	var right: float = r.end.x - D.s(6.0)
	var lit_road: bool = view.grab == ROAD or view.hover == ROAD
	view.draw_rect(Rect2(left, y - half, right - left, half * 2.0), view.col("bg_panel_high", 0.9 if lit_road else 0.65), true)
	view.draw_line(Vector2(left, y - half), Vector2(right, y - half), view.col("border_soft"), 1.0)
	view.draw_line(Vector2(left, y + half), Vector2(right, y + half), view.col("border_soft"), 1.0)
	D.dashed(view, Vector2(left, y), Vector2(right, y), view.col("text_faint"), 1.0, D.s(6.0), D.s(5.0))
	var go: float = _going(view)
	var car: Vector2 = _car_at(view, g)
	var m: float = 0.0
	if view.has("speed"):
		m = clampf(view.value("speed") / SOUND_KMH, 0.0, 0.9) * 1.6
	if view.has("bend"):
		m *= view.value("bend")
	m = clampf(m, 0.0, 0.75)
	if view.live_on and view.toggle("rings"):
		var sp: float = _ring_speed(view, g)
		var span: float = r.size.x
		for ring: Dictionary in rings:
			var rr2: float = (view.live_clock - float(ring["born"])) * sp
			if rr2 < 1.0:
				continue
			var a2: float = float(ring["strength"]) * clampf(1.0 - rr2 / (span * 0.55), 0.0, 1.0) * 0.7
			view.draw_arc(ring["at"], rr2, 0.0, TAU, 56, view.col("accent", a2), 1.0, true)
	else:
		var ring_step: float = clampf((y - r.position.y - D.s(3.0)) / 5.2, D.s(4.0), D.s(12.0))
		for i: int in range(1, 6):
			var rr: float = ring_step * float(i)
			var at: Vector2 = car - Vector2(go * m * rr, 0.0)
			view.draw_arc(at, rr, 0.0, TAU, 48, view.col("accent", 0.34 - 0.05 * float(i)), 1.0, true)
	for k: int in 4:
		var tail: float = D.s(10.0 + 7.0 * float(k))
		view.draw_line(car - Vector2(go * tail, D.s(-3.0 + 2.0 * float(k))), car - Vector2(go * (tail + D.s(9.0)), D.s(-3.0 + 2.0 * float(k))), view.col("text_dim", 0.5 - 0.1 * float(k)), 1.2, true)
	var tip_at: Vector2 = Vector2(me.x + go * r.size.x * 0.32, y)
	view.draw_line(car + Vector2(go * D.s(12.0), 0.0), tip_at, view.col("accent", 0.7), 1.4, true)
	D.arrow_head(view, tip_at + Vector2(go * D.s(6.0), 0.0), Vector2(go, 0.0), D.s(7.0), view.col("accent"))
	var lit_car: bool = view.grab == CAR or view.hover == CAR
	D.glow_dot(view, car, D.s(5.5) * (1.0 + (view.live_level * 0.5 if view.live_on else 0.0)), view.col("accent"), lit_car or (view.live_on and view.live_level > 0.3))
	D.dashed(view, me + Vector2(0.0, -D.s(10.0)), Vector2(me.x, y + half), view.col("text_faint"), 1.0, D.s(3.0), D.s(3.0))
	view.draw_line(Vector2(me.x - D.s(4.0), y + half + 1.0), Vector2(me.x + D.s(4.0), y + half + 1.0), view.col("text_dim"), 1.0)
	if view.toggle("labels"):
		view.text(Vector2(me.x + D.s(6.0), (me.y + y) * 0.5 + D.s(4.0)), view.shown("closest"), "text_dim")
	D.head_top(view, me, D.s(7.0), view.col("bg_panel_high"), view.col("text_dim"))
	var words: String = "Passes " + view.shown("closest") + " in front of you"
	if view.has("direction"):
		words += ", " + ("right to left" if go < 0.0 else "left to right")
	if view.has("speed"):
		words += ", at " + view.shown("speed")
	if view.toggle("labels"):
		view.text(Vector2(r.position.x + D.s(8.0), r.end.y - D.s(8.0)), words, "text", "font_small", r.size.x - D.s(16.0))


func _part(view: PanelView, at: Vector2) -> String:
	var g: Dictionary = _geo(view)
	if not (g["stage"] as Rect2).has_point(at):
		return ""
	if at.distance_to(_car_at(view, g)) < D.s(14.0):
		return CAR
	if absf(at.y - _road_y(view, g)) < D.s(12.0):
		return ROAD
	return ""


func hover(view: PanelView, at: Vector2) -> String:
	return _part(view, at)


func press(view: PanelView, at: Vector2) -> String:
	var part: String = _part(view, at)
	if not part.is_empty():
		view.frozen["dy"] = at.y - _road_y(view, _geo(view))
	return part


func drag(view: PanelView, part: String, at: Vector2) -> Dictionary:
	var g: Dictionary = _geo(view)
	var y: float = at.y - float(view.frozen.get("dy", 0.0))
	var out: Dictionary = {"closest": _closest_of(view, ((g["me"] as Vector2).y - y) / float(g["span"]))}
	if part == CAR and view.has("direction"):
		var dx: float = at.x - view.press_at.x
		if absf(dx) > D.s(14.0):
			out["direction"] = 0.0 if dx > 0.0 else 1.0
	return out


func click(view: PanelView, part: String, _at: Vector2) -> Dictionary:
	if part == CAR and view.has("direction"):
		return {"direction": 0.0 if _going(view) < 0.0 else 1.0}
	return {}

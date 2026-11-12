extends "res://modules/core_panels/effect_panel_kind.gd"

## An EQ drawn as the curve it makes: frequency across (low on the left), louder up, quieter down. Each band is a
## point to drag; Shift and drag up or down makes a band sharper or wider. Low and high cut are lines to drag.
## Roles are all optional: up to four bands (f1 g1 q1 ... f4 g4 q4), low_cut and high_cut, a low shelf
## (lo_f lo_g lo_q), a high shelf (hi_f hi_g hi_q), and a tilt (pivot, tilt).

const D := preload("res://modules/core_panels/effect_panel_draw.gd")
const RATE := 48000.0
const F_LO := 20.0
const F_HI := 20000.0
const STEPS := 160
const GRID_F: Array = [50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0]
const BAND_TINT: Array = [Color(0.96, 0.55, 0.28), Color(0.98, 0.82, 0.30), Color(0.45, 0.85, 0.55), Color(0.40, 0.70, 1.0)]
const PICK_PX := 12.0


func title() -> String:
	return "EQ curve"


func roles() -> Dictionary:
	var out: Dictionary = {}
	for n: int in range(1, 5):
		out["f" + str(n)] = role("Band " + str(n) + " frequency", false)
		out["g" + str(n)] = role("Band " + str(n) + " amount", false)
		out["q" + str(n)] = role("Band " + str(n) + " sharpness", false)
	for k: String in ["low_cut", "high_cut", "lo_f", "lo_g", "lo_q", "hi_f", "hi_g", "hi_q", "pivot", "tilt"]:
		out[k] = role(k.capitalize(), false)
	return out


func height() -> float:
	return 190.0


func undo_label(part: String) -> String:
	if part.begins_with("b"):
		return "Shape band " + part.substr(1)
	if part == "low_cut" or part == "high_cut":
		return "Move the " + part.replace("_", " ")
	return "Shape the EQ"


func tip(_view: PanelView, part: String) -> String:
	if part.begins_with("b") or part == "lo" or part == "hi":
		return "Drag across for the frequency and up or down for louder or quieter. Shift and drag up or down to make it sharper or wider"
	if part == "low_cut":
		return "Drag right to cut more of the low rumble, all the way left for off"
	if part == "high_cut":
		return "Drag left to cut more of the high hiss, all the way right for off"
	if part == "tilt":
		return "Drag up or down to tip the sound brighter or darker, across to move where it pivots"
	return "The shape the EQ gives the sound: louder above the middle line, quieter below"


# Geometry ---------------------------------------------------------------------------------------------------------

func _db_range(view: PanelView) -> float:
	var top: float = 6.0
	for n: int in range(1, 5):
		if view.has("g" + str(n)):
			top = maxf(top, absf(view.high("g" + str(n), 24.0)))
	for k: String in ["lo_g", "hi_g"]:
		if view.has(k):
			top = maxf(top, absf(view.high(k, 24.0)))
	if view.has("tilt"):
		top = maxf(top, absf(view.high("tilt", 12.0)))
	return minf(top, 24.0)


func _plot(view: PanelView) -> Rect2:
	var r: Rect2 = view.stage()
	var foot: float = view.text_height("font_small") + D.s(10.0)
	var left: float = D.s(30.0)
	return Rect2(r.position.x + left, r.position.y + D.s(8.0), r.size.x - left - D.s(8.0), r.size.y - foot - D.s(22.0))


static func x_of(p: Rect2, f: float) -> float:
	var t: float = (log(clampf(f, F_LO, F_HI)) - log(F_LO)) / (log(F_HI) - log(F_LO))
	return p.position.x + t * p.size.x


static func f_of(p: Rect2, x: float) -> float:
	var t: float = clampf((x - p.position.x) / maxf(p.size.x, 1.0), 0.0, 1.0)
	return exp(log(F_LO) + t * (log(F_HI) - log(F_LO)))


static func y_of(p: Rect2, db: float, range_db: float) -> float:
	return p.get_center().y - clampf(db / range_db, -1.1, 1.1) * p.size.y * 0.5


static func db_of(p: Rect2, y: float, range_db: float) -> float:
	return (p.get_center().y - y) / (p.size.y * 0.5) * range_db


# The curve --------------------------------------------------------------------------------------------------------

## Biquad coefficients [b0, b1, b2, a0, a1, a2] after the RBJ cookbook.
static func coeffs(kind: String, f: float, db: float, q: float) -> PackedFloat64Array:
	var w0: float = TAU * clampf(f, 5.0, RATE * 0.49) / RATE
	var c: float = cos(w0)
	var alpha: float = sin(w0) / (2.0 * maxf(q, 0.05))
	var a: float = pow(10.0, db / 40.0)
	var sa: float = 2.0 * sqrt(a) * alpha
	match kind:
		"peak":
			return PackedFloat64Array([1.0 + alpha * a, -2.0 * c, 1.0 - alpha * a, 1.0 + alpha / a, -2.0 * c, 1.0 - alpha / a])
		"low_shelf":
			return PackedFloat64Array([a * ((a + 1.0) - (a - 1.0) * c + sa), 2.0 * a * ((a - 1.0) - (a + 1.0) * c), a * ((a + 1.0) - (a - 1.0) * c - sa), (a + 1.0) + (a - 1.0) * c + sa, -2.0 * ((a - 1.0) + (a + 1.0) * c), (a + 1.0) + (a - 1.0) * c - sa])
		"high_shelf":
			return PackedFloat64Array([a * ((a + 1.0) + (a - 1.0) * c + sa), -2.0 * a * ((a - 1.0) + (a + 1.0) * c), a * ((a + 1.0) + (a - 1.0) * c - sa), (a + 1.0) - (a - 1.0) * c + sa, 2.0 * ((a - 1.0) - (a + 1.0) * c), (a + 1.0) - (a - 1.0) * c - sa])
		"high_pass":
			return PackedFloat64Array([(1.0 + c) * 0.5, -(1.0 + c), (1.0 + c) * 0.5, 1.0 + alpha, -2.0 * c, 1.0 - alpha])
		"low_pass":
			return PackedFloat64Array([(1.0 - c) * 0.5, 1.0 - c, (1.0 - c) * 0.5, 1.0 + alpha, -2.0 * c, 1.0 - alpha])
	return PackedFloat64Array([1.0, 0.0, 0.0, 1.0, 0.0, 0.0])


## The gain in dB of one biquad at frequency f.
static func response_db(k: PackedFloat64Array, f: float) -> float:
	var w: float = TAU * f / RATE
	var c1: float = cos(w)
	var s1: float = sin(w)
	var c2: float = cos(2.0 * w)
	var s2: float = sin(2.0 * w)
	var nr: float = k[0] + k[1] * c1 + k[2] * c2
	var ni: float = -(k[1] * s1 + k[2] * s2)
	var dr: float = k[3] + k[4] * c1 + k[5] * c2
	var di: float = -(k[4] * s1 + k[5] * s2)
	var num: float = nr * nr + ni * ni
	var den: float = maxf(dr * dr + di * di, 1e-30)
	return 10.0 * log(maxf(num / den, 1e-30)) / log(10.0)


## Every filter the bound values make, as [coeffs, ...].
func filters(view: PanelView) -> Array[PackedFloat64Array]:
	var out: Array[PackedFloat64Array] = []
	for n: int in range(1, 5):
		var s: String = str(n)
		if view.has("f" + s) and view.has("g" + s):
			out.append(coeffs("peak", view.value("f" + s), view.value("g" + s), view.value("q" + s, 1.0) if view.has("q" + s) else 1.0))
	if view.has("lo_f") and view.has("lo_g"):
		out.append(coeffs("low_shelf", view.value("lo_f"), view.value("lo_g"), view.value("lo_q", 0.7071) if view.has("lo_q") else 0.7071))
	if view.has("hi_f") and view.has("hi_g"):
		out.append(coeffs("high_shelf", view.value("hi_f"), view.value("hi_g"), view.value("hi_q", 0.7071) if view.has("hi_q") else 0.7071))
	if view.has("pivot") and view.has("tilt"):
		var t: float = view.value("tilt")
		out.append(coeffs("low_shelf", view.value("pivot"), -t * 0.5, 0.5))
		out.append(coeffs("high_shelf", view.value("pivot"), t * 0.5, 0.5))
	if view.has("low_cut") and _cut_on(view, "low_cut"):
		out.append(coeffs("high_pass", view.value("low_cut"), 0.0, 0.7071))
	if view.has("high_cut") and _cut_on(view, "high_cut"):
		out.append(coeffs("low_pass", view.value("high_cut"), 0.0, 0.7071))
	return out


func _cut_on(view: PanelView, key: String) -> bool:
	var v: float = view.value(key)
	if key == "low_cut":
		return v > maxf(view.low(key, 0.0), 1.0) + 0.5
	return v < view.high(key, F_HI) - 0.5


func total_db(view: PanelView, f: float) -> float:
	var sum: float = 0.0
	for k: PackedFloat64Array in filters(view):
		sum += response_db(k, f)
	return sum


# Drawing ----------------------------------------------------------------------------------------------------------

func draw(view: PanelView) -> void:
	var p: Rect2 = _plot(view)
	var rng: float = _db_range(view)
	D.round_rect(view, p.grow(D.s(2.0)), D.s(4.0), view.col("bg_field", 0.9), view.col("border_soft"))
	for f: float in GRID_F:
		var x: float = x_of(p, f)
		view.draw_line(Vector2(x, p.position.y), Vector2(x, p.end.y), view.col("border_soft", 0.6), 1.0)
		view.text(Vector2(x - D.s(10.0), p.end.y + D.s(14.0)), _hz(f), "text_faint")
	var step: float = 6.0 if rng <= 12.5 else 12.0
	var db: float = -floorf(rng / step) * step
	while db <= rng + 0.01:
		var y: float = y_of(p, db, rng)
		view.draw_line(Vector2(p.position.x, y), Vector2(p.end.x, y), view.col("border" if is_zero_approx(db) else "border_soft", 0.9 if is_zero_approx(db) else 0.5), 1.0)
		if absf(db) < rng - 0.01:
			view.text(Vector2(p.position.x - D.s(28.0), y + D.s(4.0)), ("+" if db > 0.0 else "") + str(int(db)), "text_faint")
		db += step
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in STEPS + 1:
		var x2: float = lerpf(p.position.x, p.end.x, float(i) / float(STEPS))
		pts.append(Vector2(x2, y_of(p, total_db(view, f_of(p, x2)), rng)))
	var zero: float = y_of(p, 0.0, rng)
	var shade: Color = view.col("accent", 0.16)
	for i2: int in range(1, pts.size()):
		var a: Vector2 = pts[i2 - 1]
		var b: Vector2 = pts[i2]
		if (a.y - zero) * (b.y - zero) < 0.0:
			var t: float = (zero - a.y) / (b.y - a.y)
			var mid: Vector2 = Vector2(lerpf(a.x, b.x, t), zero)
			view.draw_colored_polygon(PackedVector2Array([Vector2(a.x, zero), a, mid]), shade)
			view.draw_colored_polygon(PackedVector2Array([mid, b, Vector2(b.x, zero)]), shade)
		elif absf(a.y - zero) + absf(b.y - zero) > 0.5:
			view.draw_colored_polygon(PackedVector2Array([Vector2(a.x, zero), a, b, Vector2(b.x, zero)]), shade)
	view.draw_polyline(pts, view.col("accent"), D.s(2.0), true)
	for cut: String in ["low_cut", "high_cut"]:
		if view.has(cut):
			_cut_line(view, p, cut)
	for part: Dictionary in _points(view, p, rng):
		var lit: bool = view.grab == String(part["id"]) or view.hover == String(part["id"])
		var col: Color = part["col"]
		if lit and part.has("q_span"):
			var span: Vector2 = part["q_span"]
			view.draw_line(Vector2(span.x, (part["at"] as Vector2).y), Vector2(span.y, (part["at"] as Vector2).y), Color(col.r, col.g, col.b, 0.6), D.s(2.0), true)
		view.draw_circle(part["at"], D.s(7.0 if lit else 6.0), Color(col.r, col.g, col.b, 0.25))
		view.draw_circle(part["at"], D.s(4.5), col)
		view.text(part["at"] + Vector2(-D.s(3.0), -D.s(9.0)), String(part["name"]), "text_bright")
	var r: Rect2 = view.stage()
	view.text(Vector2(r.position.x + D.s(8.0), r.end.y - D.s(6.0)), _words(view), "text", "font_small", r.size.x - D.s(16.0))


func _cut_line(view: PanelView, p: Rect2, key: String) -> void:
	var on: bool = _cut_on(view, key)
	var x: float = x_of(p, view.value(key)) if on else (p.position.x if key == "low_cut" else p.end.x)
	var lit: bool = view.grab == key or view.hover == key
	var col: Color = view.col("text_bright" if lit else "text_dim", 1.0 if on else 0.5)
	D.dashed(view, Vector2(x, p.position.y), Vector2(x, p.end.y), col, 1.0, D.s(4.0), D.s(3.0))
	var grip: Rect2 = Rect2(Vector2(x - D.s(4.0), p.end.y - D.s(18.0)), Vector2(D.s(8.0), D.s(16.0)))
	D.round_rect(view, grip, D.s(2.0), view.col("bg_panel_high"), col)


func _points(view: PanelView, p: Rect2, rng: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: int in range(1, 5):
		var s: String = str(n)
		if not (view.has("f" + s) and view.has("g" + s)):
			continue
		var f: float = view.value("f" + s)
		var q: float = view.value("q" + s, 1.0) if view.has("q" + s) else 1.0
		var bw: float = pow(2.0, 1.0 / maxf(q, 0.05) * 0.5)
		var at: Vector2 = Vector2(x_of(p, f), y_of(p, view.value("g" + s), rng))
		out.append({"id": "b" + s, "name": s, "at": at, "col": BAND_TINT[n - 1], "q_span": Vector2(x_of(p, f / bw), x_of(p, f * bw))})
	if view.has("lo_f") and view.has("lo_g"):
		out.append({"id": "lo", "name": "L", "at": Vector2(x_of(p, view.value("lo_f")), y_of(p, view.value("lo_g"), rng)), "col": BAND_TINT[0]})
	if view.has("hi_f") and view.has("hi_g"):
		out.append({"id": "hi", "name": "H", "at": Vector2(x_of(p, view.value("hi_f")), y_of(p, view.value("hi_g"), rng)), "col": BAND_TINT[3]})
	if view.has("pivot") and view.has("tilt"):
		var px: float = x_of(p, view.value("pivot"))
		out.append({"id": "tilt", "name": "", "at": Vector2(minf(px + p.size.x * 0.25, p.end.x - D.s(8.0)), y_of(p, view.value("tilt") * 0.5, rng)), "col": BAND_TINT[2]})
	return out


static func _hz(f: float) -> String:
	if f >= 1000.0:
		var k: float = f / 1000.0
		return (str(int(k)) if is_equal_approx(k, roundf(k)) else "%.1f" % k) + "k"
	return str(int(f))


func _words(view: PanelView) -> String:
	var part: String = view.grab if not view.grab.is_empty() else view.hover
	if part.begins_with("b"):
		var s: String = part.substr(1)
		var g: float = view.value("g" + s)
		var w: String = "Band " + s + ": " + _hz(view.value("f" + s)) + "Hz, " + ("+" if g >= 0.0 else "") + "%.1f dB" % g
		if view.has("q" + s):
			w += ", sharpness %.2f" % view.value("q" + s)
		return w
	if part == "low_cut" or part == "high_cut":
		return part.replace("_", " ").capitalize() + ": " + (_hz(view.value(part)) + "Hz" if _cut_on(view, part) else "off")
	if part == "lo" or part == "hi":
		var k: String = part
		return ("Low" if k == "lo" else "High") + " shelf: " + _hz(view.value(k + "_f")) + "Hz, %+.1f dB" % view.value(k + "_g")
	if part == "tilt":
		return "Tilt %+.1f dB around " % view.value("tilt") + _hz(view.value("pivot")) + "Hz"
	return "Drag a point to shape the sound. Shift and drag up or down for sharper or wider."


# Input ------------------------------------------------------------------------------------------------------------

func _part(view: PanelView, at: Vector2) -> String:
	var p: Rect2 = _plot(view)
	if not view.stage().has_point(at):
		return ""
	var best: String = ""
	var best_d: float = D.s(PICK_PX)
	for part: Dictionary in _points(view, p, _db_range(view)):
		var d: float = at.distance_to(part["at"])
		if d < best_d:
			best_d = d
			best = String(part["id"])
	if not best.is_empty():
		return best
	for cut: String in ["low_cut", "high_cut"]:
		if not view.has(cut):
			continue
		var x: float = x_of(p, view.value(cut)) if _cut_on(view, cut) else (p.position.x if cut == "low_cut" else p.end.x)
		if absf(at.x - x) < D.s(8.0) and at.y > p.position.y and at.y < p.end.y + D.s(4.0):
			return cut
	return ""


func hover(view: PanelView, at: Vector2) -> String:
	return _part(view, at)


func press(view: PanelView, at: Vector2) -> String:
	return _part(view, at)


func drag(view: PanelView, part: String, at: Vector2) -> Dictionary:
	var p: Rect2 = _plot(view)
	var rng: float = _db_range(view)
	if part.begins_with("b"):
		var s: String = part.substr(1)
		if Input.is_key_pressed(KEY_SHIFT) and view.has("q" + s):
			var dy: float = (view.press_at.y - at.y) / D.s(40.0)
			return {"q" + s: clampf(view.start_value("q" + s, 1.0) * pow(2.0, dy), view.low("q" + s, 0.1), view.high("q" + s, 16.0))}
		return {"f" + s: clampf(f_of(p, at.x), view.low("f" + s, F_LO), view.high("f" + s, F_HI)), "g" + s: clampf(db_of(p, at.y, rng), view.low("g" + s, -24.0), view.high("g" + s, 24.0))}
	if part == "lo" or part == "hi":
		if Input.is_key_pressed(KEY_SHIFT) and view.has(part + "_q"):
			var dy2: float = (view.press_at.y - at.y) / D.s(40.0)
			return {part + "_q": clampf(view.start_value(part + "_q", 0.7071) * pow(2.0, dy2), view.low(part + "_q", 0.3), view.high(part + "_q", 2.0))}
		return {part + "_f": clampf(f_of(p, at.x), view.low(part + "_f", F_LO), view.high(part + "_f", F_HI)), part + "_g": clampf(db_of(p, at.y, rng), view.low(part + "_g", -24.0), view.high(part + "_g", 24.0))}
	if part == "tilt":
		var px: float = at.x - p.size.x * 0.25
		return {"pivot": clampf(f_of(p, px), view.low("pivot", 100.0), view.high("pivot", 8000.0)), "tilt": clampf(db_of(p, at.y, rng) * 2.0, view.low("tilt", -12.0), view.high("tilt", 12.0))}
	if part == "low_cut":
		if at.x <= p.position.x + D.s(4.0):
			return {part: view.low(part, 0.0)}
		return {part: clampf(f_of(p, at.x), view.low(part, 0.0), view.high(part, F_HI))}
	if part == "high_cut":
		if at.x >= p.end.x - D.s(4.0):
			return {part: view.high(part, F_HI)}
		return {part: clampf(f_of(p, at.x), view.low(part, 0.0), view.high(part, F_HI))}
	return {}

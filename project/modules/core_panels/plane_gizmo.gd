extends RefCounted

const PlaneDepth := preload("res://doc/plane_depth.gd")
const EffectHandlesUi := preload("res://modules/core_panels/effect_handles_ui.gd")
const UNITS_FRAME := "frame"
const ROLES: PackedStringArray = ["tilt", "swivel", "roll", "distance", "fov", "offset", "scale"]
const UV_CORNERS: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
const SIDE_MID: Array[Vector2] = [Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)]
const CENTRE := Vector2(0.5, 0.5)
const NEAR := 0.02
const KNOB_GAP := 30.0
const SPAN := 90.0
const STEP := 1.0
const REFINE := 30
const SCALE_SAMPLES := 240
const ANGLE_STEP := 15.0
const ANGLE_REACH := 2.0
const SHADE := Color(0.0, 0.0, 0.0, 0.55)


static func is_frame_units(sd: Dictionary) -> bool:
	return String(sd.get("units", "")) == UNITS_FRAME


static func named_keys(sd: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for role: String in ROLES:
		var k: String = String(sd.get(role, ""))
		if not k.is_empty() and not out.has(k):
			out.append(k)
	return out


static func key_of(sd: Dictionary, handle: String) -> String:
	var role: String = role_of(handle)
	return String(sd.get(role, "")) if not role.is_empty() else ""


static func role_of(handle: String) -> String:
	if handle == "in":
		return "offset"
	if handle == "r":
		return "roll"
	if handle.begins_with("c"):
		return "scale"
	if handle.begins_with("e") and handle.length() == 2:
		return "tilt" if int(handle.substr(1)) % 2 == 0 else "swivel"
	return ""


static func plane_of(sd: Dictionary, values: Dictionary) -> Dictionary:
	return PlaneDepth.resolve(sd, values)


static func with_value(sd: Dictionary, values: Dictionary, role: String, v: Variant) -> Dictionary:
	var out: Dictionary = values.duplicate()
	var k: String = String(sd.get(role, ""))
	if not k.is_empty():
		out[k] = v
	return out


static func project(uv: Vector2, aspect: float, plane: Dictionary) -> Vector2:
	var p: Vector2 = PlaneDepth.project(uv, aspect, plane)
	if not is_finite(p.x) or not is_finite(p.y):
		return Vector2(NAN, NAN)
	return p


static func camera_point(uv: Vector2, aspect: float, plane: Dictionary) -> Vector3:
	var sc: float = float(plane["scale"])
	var q: Vector3 = Vector3((uv.x - 0.5) * aspect * sc, (uv.y - 0.5) * sc, 0.0)
	var off: Vector2 = plane["offset"]
	return Vector3(off.x * aspect, off.y, 0.0) + PlaneDepth.rotate(q, float(plane["tilt"]), float(plane["swivel"]), float(plane["roll"]))


static func screen_of(p: Vector3, aspect: float, plane: Dictionary) -> Vector2:
	var z: float = p.z + float(plane["distance"])
	var s: Vector2 = Vector2(p.x, p.y) * float(plane["focal"]) / z
	return Vector2(s.x / aspect + 0.5, s.y + 0.5)


static func outline(aspect: float, plane: Dictionary) -> PackedVector2Array:
	var d: float = float(plane["distance"])
	var pts: Array[Vector3] = []
	for uv: Vector2 in UV_CORNERS:
		pts.append(camera_point(uv, aspect, plane))
	var kept: Array[Vector3] = []
	for i: int in pts.size():
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		var ina: bool = a.z + d >= NEAR
		var inb: bool = b.z + d >= NEAR
		if ina:
			kept.append(a)
		if ina != inb:
			var t: float = (NEAR - d - a.z) / (b.z - a.z)
			kept.append(a.lerp(b, t))
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector3 in kept:
		out.append(screen_of(p, aspect, plane))
	return out


static func build(t: Dictionary, values: Dictionary, aspect: float, k: float) -> bool:
	var sd: Dictionary = t["spec"]
	var xf: Transform2D = t["xf"]
	var plane: Dictionary = plane_of(sd, values)
	var centre_uv: Vector2 = project(CENTRE, aspect, plane)
	if is_nan(centre_uv.x):
		return false
	var shape: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in outline(aspect, plane):
		shape.append(xf * p)
	var hs: Array[Dictionary] = []
	if not String(sd.get("scale", "")).is_empty():
		for i: int in 4:
			var o: Vector2 = project(UV_CORNERS[i], aspect, plane)
			if not is_nan(o.x):
				hs.append({"id": "c" + str(i), "at": xf * o, "look": "square", "name": "Scale"})
	for i2: int in 4:
		var role: String = "tilt" if i2 % 2 == 0 else "swivel"
		if String(sd.get(role, "")).is_empty():
			continue
		var o2: Vector2 = project(SIDE_MID[i2], aspect, plane)
		if is_nan(o2.x):
			continue
		hs.append({"id": "e" + str(i2), "at": xf * o2, "look": "cross", "name": "Tilt" if role == "tilt" else "Swivel"})
	var centre: Vector2 = xf * centre_uv
	if not String(sd.get("roll", "")).is_empty():
		var top_uv: Vector2 = project(SIDE_MID[0], aspect, plane)
		var top: Vector2 = xf * top_uv if not is_nan(top_uv.x) else centre
		var dir: Vector2 = top - centre
		if dir.length() < 0.5:
			var up: Vector2 = Vector2(0.0, -1.0).rotated(deg_to_rad(float(plane["roll"])))
			dir = xf.basis_xform(Vector2(up.x / maxf(aspect, 0.0001), up.y))
		var knob: Vector2 = top + dir.normalized() * KNOB_GAP / maxf(k, 0.0001)
		hs.append({"id": "r", "at": knob, "look": "knob", "name": "Roll"})
		t["stem"] = PackedVector2Array([top, knob])
	t["values"] = values
	t["plane"] = plane
	t["aspect"] = aspect
	t["shape"] = shape
	t["handles"] = hs
	t["centre"] = centre
	t["keys"] = named_keys(sd)
	t["movable"] = not String(sd.get("offset", "")).is_empty() and shape.size() >= 3
	if t["movable"]:
		t["name"] = "Position"
	return true


static func draw_stem(ci: CanvasItem, t: Dictionary, to_screen: Callable, ink: Color, lit: bool) -> void:
	var stem: PackedVector2Array = t.get("stem", PackedVector2Array())
	if stem.size() < 2:
		return
	var a: Vector2 = to_screen.call(stem[0])
	var b: Vector2 = to_screen.call(stem[1])
	var n: float = a.distance_to(b)
	if n <= EffectHandlesUi.KNOB + 2.0:
		return
	var u: Vector2 = (b - a) / n
	var tip: Vector2 = b - u * (EffectHandlesUi.KNOB - 1.0)
	ci.draw_line(a, tip, SHADE, 3.0, true)
	ci.draw_line(a, tip, ink, 1.5 if lit else 1.25, true)


static func _clamp_param(def: Dictionary, key: String, v: float, lo: float, hi: float) -> float:
	for p: Variant in def.get("params", []):
		if p is Dictionary and String((p as Dictionary).get("key", "")) == key:
			return clampf(v, float((p as Dictionary).get("min", lo)), float((p as Dictionary).get("max", hi)))
	return clampf(v, lo, hi)


static func _range_of(def: Dictionary, key: String, lo: float, hi: float) -> Vector2:
	for p: Variant in def.get("params", []):
		if p is Dictionary and String((p as Dictionary).get("key", "")) == key:
			return Vector2(float((p as Dictionary).get("min", lo)), float((p as Dictionary).get("max", hi)))
	return Vector2(lo, hi)


static func _miss(uv: Vector2, sd: Dictionary, values: Dictionary, role: String, v: float, aspect: float, xf: Transform2D, want: Vector2) -> float:
	var got: Vector2 = project(uv, aspect, plane_of(sd, with_value(sd, values, role, v)))
	if is_nan(got.x):
		return INF
	return (xf * got).distance_to(want)


static func solve_angle(t: Dictionary, role: String, uv: Vector2, want: Vector2, def: Dictionary) -> float:
	var sd: Dictionary = t["spec"]
	var values: Dictionary = t["values"]
	var xf: Transform2D = t["xf"]
	var aspect: float = float(t["aspect"])
	var key: String = String(sd.get(role, ""))
	var now: float = float((t["plane"] as Dictionary)[role])
	var lim: Vector2 = _range_of(def, key, -180.0, 180.0)
	var lo_all: float = maxf(now - SPAN, lim.x)
	var hi_all: float = minf(now + SPAN, lim.y)
	var best: float = now
	var best_d: float = INF
	var a: float = lo_all
	while a <= hi_all + 0.0001:
		var dd: float = _miss(uv, sd, values, role, a, aspect, xf, want) + absf(a - now) * 0.00001
		if dd < best_d:
			best_d = dd
			best = a
		a += STEP
	var lo: float = maxf(best - STEP, lo_all)
	var hi: float = minf(best + STEP, hi_all)
	for i: int in REFINE:
		var m1: float = lo + (hi - lo) / 3.0
		var m2: float = hi - (hi - lo) / 3.0
		if _miss(uv, sd, values, role, m1, aspect, xf, want) <= _miss(uv, sd, values, role, m2, aspect, xf, want):
			hi = m2
		else:
			lo = m1
	return clampf((lo + hi) * 0.5, lim.x, lim.y)


static func solve_scale(t: Dictionary, corner: int, want: Vector2, def: Dictionary) -> float:
	var sd: Dictionary = t["spec"]
	var values: Dictionary = t["values"]
	var xf: Transform2D = t["xf"]
	var aspect: float = float(t["aspect"])
	var lim: Vector2 = _range_of(def, String(sd.get("scale", "")), 0.05, 20.0)
	var l0: float = log(maxf(lim.x, 0.0001))
	var l1: float = log(maxf(lim.y, lim.x + 0.0001))
	var uv: Vector2 = UV_CORNERS[clampi(corner, 0, 3)]
	var best: int = 0
	var best_d: float = INF
	for i: int in SCALE_SAMPLES + 1:
		var s: float = exp(lerpf(l0, l1, float(i) / float(SCALE_SAMPLES)))
		var dd: float = _miss(uv, sd, values, "scale", s, aspect, xf, want)
		if dd < best_d:
			best_d = dd
			best = i
	var lo: float = lerpf(l0, l1, float(maxi(best - 1, 0)) / float(SCALE_SAMPLES))
	var hi: float = lerpf(l0, l1, float(mini(best + 1, SCALE_SAMPLES)) / float(SCALE_SAMPLES))
	for j: int in REFINE:
		var m1: float = lo + (hi - lo) / 3.0
		var m2: float = hi - (hi - lo) / 3.0
		if _miss(uv, sd, values, "scale", exp(m1), aspect, xf, want) <= _miss(uv, sd, values, "scale", exp(m2), aspect, xf, want):
			hi = m2
		else:
			lo = m1
	return clampf(exp((lo + hi) * 0.5), lim.x, lim.y)


static func offset_for(t: Dictionary, press_uv: Vector2, cursor_uv: Vector2) -> Vector2:
	var plane: Dictionary = t["plane"]
	var aspect: float = float(t["aspect"])
	var grabbed: Vector2 = PlaneDepth.picture_uv_at(press_uv, aspect, plane)
	var off: Vector2 = plane["offset"]
	if grabbed.x == -1.0 and grabbed.y == -1.0:
		return off
	var sc: float = float(plane["scale"])
	var rq: Vector3 = PlaneDepth.rotate(Vector3((grabbed.x - 0.5) * aspect * sc, (grabbed.y - 0.5) * sc, 0.0), float(plane["tilt"]), float(plane["swivel"]), float(plane["roll"]))
	var depth: float = rq.z + float(plane["distance"])
	if depth <= NEAR:
		return off
	var s: Vector2 = Vector2((cursor_uv.x - 0.5) * aspect, cursor_uv.y - 0.5)
	var o: Vector2 = s * depth / float(plane["focal"]) - Vector2(rq.x, rq.y)
	return Vector2(o.x / aspect, o.y)


static func _top_angle(t: Dictionary, roll: float) -> float:
	var sd: Dictionary = t["spec"]
	var xf: Transform2D = t["xf"]
	var top: Vector2 = project(SIDE_MID[0], float(t["aspect"]), plane_of(sd, with_value(sd, t["values"], "roll", roll)))
	if is_nan(top.x):
		return NAN
	var v: Vector2 = xf * top - Vector2(t["centre"])
	return v.angle() if v.length() > 0.0001 else NAN


static func roll_for(t: Dictionary, press_seq: Vector2, cursor_seq: Vector2) -> float:
	var centre: Vector2 = t["centre"]
	var start: float = float((t["plane"] as Dictionary)["roll"])
	var a0: Vector2 = press_seq - centre
	var a1: Vector2 = cursor_seq - centre
	if a0.length() < 0.0001 or a1.length() < 0.0001:
		return float(t.get("spin_value", start))
	var last: float = float(t.get("spin_last", a0.angle()))
	var turn: float = float(t.get("spin_total", 0.0)) + angle_difference(last, a1.angle())
	t["spin_last"] = a1.angle()
	t["spin_total"] = turn
	var guess: float = start + rad_to_deg(turn)
	var top0: float = _top_angle(t, start)
	var v: float = guess
	if not is_nan(top0):
		var aim: float = top0 + turn
		var lo: float = guess - 30.0
		var hi: float = guess + 30.0
		var best: float = guess
		var best_d: float = INF
		var r: float = lo
		while r <= hi + 0.0001:
			var ta: float = _top_angle(t, r)
			var dd: float = absf(angle_difference(ta, aim)) if not is_nan(ta) else INF
			if dd < best_d:
				best_d = dd
				best = r
			r += STEP
		lo = best - STEP
		hi = best + STEP
		for i: int in REFINE:
			var m1: float = lo + (hi - lo) / 3.0
			var m2: float = hi - (hi - lo) / 3.0
			var t1: float = _top_angle(t, m1)
			var t2: float = _top_angle(t, m2)
			var d1: float = absf(angle_difference(t1, aim)) if not is_nan(t1) else INF
			var d2: float = absf(angle_difference(t2, aim)) if not is_nan(t2) else INF
			if d1 <= d2:
				hi = m2
			else:
				lo = m1
		if best_d < INF:
			v = (lo + hi) * 0.5
	t["spin_value"] = v
	return v


static func snap_angle(v: float, shift: bool, snapping: bool) -> float:
	if shift:
		return round(v / ANGLE_STEP) * ANGLE_STEP
	if snapping:
		var step: float = round(v / ANGLE_STEP) * ANGLE_STEP
		if absf(v - step) <= ANGLE_REACH:
			return step
	return v


static func drag(t: Dictionary, handle: String, want: Vector2, press_seq: Vector2, cursor_seq: Vector2, def: Dictionary, shift: bool, snapping: bool, reach: float) -> Dictionary:
	var sd: Dictionary = t["spec"]
	var xf: Transform2D = t["xf"]
	var inv: Transform2D = xf.affine_inverse()
	var role: String = role_of(handle)
	var key: String = String(sd.get(role, "")) if not role.is_empty() else ""
	if key.is_empty():
		return {}
	var aspect: float = float(t["aspect"])
	match role:
		"scale":
			var s: float = solve_scale(t, int(handle.substr(1)), want, def)
			if snapping and not shift:
				var corner: Vector2 = UV_CORNERS[clampi(int(handle.substr(1)), 0, 3)]
				var at_one: Vector2 = project(corner, aspect, plane_of(sd, with_value(sd, t["values"], "scale", 1.0)))
				var at_s: Vector2 = project(corner, aspect, plane_of(sd, with_value(sd, t["values"], "scale", s)))
				if not is_nan(at_one.x) and not is_nan(at_s.x) and (xf * at_one).distance_to(xf * at_s) <= reach:
					s = _clamp_param(def, key, 1.0, 0.05, 20.0)
			return {"writes": {key: s}, "chip": "Scale " + str(snappedf(s * 100.0, 0.1)) + " %"}
		"tilt", "swivel":
			var side: int = int(handle.substr(1))
			var a: float = snap_angle(solve_angle(t, role, SIDE_MID[side], want, def), shift, snapping)
			a = _clamp_param(def, key, a, -180.0, 180.0)
			return {"writes": {key: a}, "chip": ("Tilt " if role == "tilt" else "Swivel ") + str(snappedf(a, 0.1)) + " deg"}
		"roll":
			var r: float = snap_angle(roll_for(t, press_seq, cursor_seq), shift, snapping)
			r = _clamp_param(def, key, r, -360.0, 360.0)
			return {"writes": {key: r}, "chip": "Roll " + str(snappedf(r, 0.1)) + " deg"}
		"offset":
			var o: Vector2 = offset_for(t, inv * press_seq, inv * cursor_seq)
			var start: Vector2 = (t["plane"] as Dictionary)["offset"]
			if shift:
				var moved: Vector2 = cursor_seq - press_seq
				o = Vector2(o.x, start.y) if absf(moved.x) >= absf(moved.y) else Vector2(start.x, o.y)
			if snapping and not shift:
				var plane: Dictionary = plane_of(sd, with_value(sd, t["values"], "offset", [o.x, o.y]))
				var c_uv: Vector2 = project(CENTRE, aspect, plane)
				if not is_nan(c_uv.x):
					if xf.basis_xform(Vector2(c_uv.x - 0.5, 0.0)).length() <= reach:
						o.x = 0.0
					if xf.basis_xform(Vector2(0.0, c_uv.y - 0.5)).length() <= reach:
						o.y = 0.0
			return {"writes": {key: [o.x, o.y]}, "chip": "Position " + str(snappedf(o.x, 0.001)) + ", " + str(snappedf(o.y, 0.001))}
	return {}

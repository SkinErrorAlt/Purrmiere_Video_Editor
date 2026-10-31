extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const PIN := "pin"
const AT := "pin_at"
const OWNER := "pin_clip"
const MOVE_EPS := 0.0002
const UNIT_STEPS := 2048
const KIND_HOLD := 0
const KIND_SHAPE := 1
const KIND_GENERAL := 2
const KIND_HERMITE := 3
const SOLVE_PASSES := 4
const INVERT_STEPS := 64
const BEZ_STEPS := 48
const ROOT_EPS := 0.000000000001
const GAP := 0.0005
const PLAN_MEMO_MAX := 256
const WALK_RATE := 240.0
const WALK_MAX := 21600.0
const LOCAL_STEPS := 48

static var _units: Dictionary = {}
static var _plans: Dictionary = {}
static var compiles: int = 0
static var solves: int = 0
static var memo_hits: int = 0
static var plant_ignore: bool = false


static func _unit(family: String, dir: String) -> Array:
	var key: String = family + "|" + dir
	var hit: Variant = _units.get(key, null)
	if hit is Array:
		return hit
	var area: PackedFloat64Array = PackedFloat64Array()
	var rate: PackedFloat64Array = PackedFloat64Array()
	area.resize(UNIT_STEPS + 1)
	rate.resize(UNIT_STEPS + 1)
	var h: float = 1.0 / float(UNIT_STEPS)
	area[0] = 0.0
	rate[0] = _shape(family, dir, 0.0)
	var lo: float = rate[0]
	var hi: float = rate[0]
	for i: int in UNIT_STEPS:
		var a: float = float(i) * h
		var mid: float = _shape(family, dir, a + h * 0.5)
		rate[i + 1] = _shape(family, dir, 1.0 if i == UNIT_STEPS - 1 else a + h)
		area[i + 1] = area[i] + (rate[i] + 4.0 * mid + rate[i + 1]) / 6.0 * h
		lo = minf(lo, minf(mid, rate[i + 1]))
		hi = maxf(hi, maxf(mid, rate[i + 1]))
	var out: Array = [area, rate, lo, hi]
	_units[key] = out
	return out


static func unit_table(family: String, dir: String) -> PackedFloat64Array:
	return _unit(family, dir)[0]


static func _shape(family: String, dir: String, u: float) -> float:
	if family.is_empty():
		return u
	return AnimProp.ease_curve(family, dir, u)


static func _herm_val(area: PackedFloat64Array, rate: PackedFloat64Array, x: float) -> float:
	var n: int = area.size() - 1
	var f: float = clampf(x, 0.0, 1.0) * float(n)
	var i: int = mini(int(f), n - 1)
	var s: float = f - float(i)
	var h: float = 1.0 / float(n)
	var s2: float = s * s
	var s3: float = s2 * s
	return (2.0 * s3 - 3.0 * s2 + 1.0) * area[i] + (s3 - 2.0 * s2 + s) * h * rate[i] + (3.0 * s2 - 2.0 * s3) * area[i + 1] + (s3 - s2) * h * rate[i + 1]


static func _herm_der(area: PackedFloat64Array, rate: PackedFloat64Array, x: float) -> float:
	var n: int = area.size() - 1
	var f: float = clampf(x, 0.0, 1.0) * float(n)
	var i: int = mini(int(f), n - 1)
	var s: float = f - float(i)
	var h: float = 1.0 / float(n)
	var s2: float = s * s
	return ((6.0 * s2 - 6.0 * s) * (area[i] - area[i + 1])) / h + (3.0 * s2 - 4.0 * s + 1.0) * rate[i] + (3.0 * s2 - 2.0 * s) * rate[i + 1]


static func keys_layer(p: Dictionary) -> Dictionary:
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0:
		return {}
	return p["layers"][li]


static func fast(p: Dictionary) -> bool:
	if not AnimProp.is_animated(p):
		return true
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0:
		return false
	var layers: Array = p.get("layers", [])
	for i: int in layers.size():
		var l: Dictionary = layers[i]
		if i != li and bool(l.get("on", true)):
			return false
	var kl: Dictionary = layers[li]
	return bool(kl.get("on", true)) and float(kl.get("weight", 1.0)) == 1.0 and str(kl.get("blend", "over")) == "over" and str(kl.get("loop", "once")) == "once"


static func exact_ok(p: Dictionary) -> bool:
	if not AnimProp.is_animated(p):
		var sv: Variant = p.get("v", 1.0)
		return sv is float or sv is int
	if not fast(p):
		return false
	var base: Variant = p.get("base", 0.0)
	if not (base is float or base is int):
		return false
	var raw: Variant = keys_layer(p).get("keys", [])
	if not (raw is Array):
		return false
	var ts: PackedFloat64Array = PackedFloat64Array()
	for k: Variant in raw:
		if not (k is Dictionary):
			return false
		var kv: Variant = (k as Dictionary).get("v", 0.0)
		var kt: Variant = (k as Dictionary).get("t", 0.0)
		if not (kv is float or kv is int) or not (kt is float or kt is int):
			return false
		ts.append(float(kt))
	ts.sort()
	for i: int in range(1, ts.size()):
		if ts[i] - ts[i - 1] < AnimProp.KEY_TOLERANCE:
			return false
	return true


static func sorted_keys(p: Dictionary) -> Array:
	var out: Array = []
	var l: Dictionary = keys_layer(p)
	for k: Variant in l.get("keys", []):
		if k is Dictionary:
			out.append((k as Dictionary).duplicate(true))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))
	return out


static func with_keys(p: Dictionary, ks: Array) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	var li: int = AnimProp.keys_layer_index(out)
	if li < 0:
		return out
	(out["layers"][li] as Dictionary)["keys"] = ks.duplicate(true)
	return out


static func key_value(k: Dictionary) -> float:
	return AnimProp._comp(k.get("v", 0.0), -1)


static func static_value(p: Dictionary) -> float:
	var v: Variant = AnimProp.static_value(p) if not AnimProp.is_animated(p) else p.get("base", 1.0)
	if v is float or v is int:
		return float(v)
	return 1.0


static func _static_plan(v: float) -> Dictionary:
	return {"static": true, "v": v, "rising": v > 0.0}


static func compile(p: Dictionary) -> Dictionary:
	compiles += 1
	if not AnimProp.is_animated(p):
		return _static_plan(static_value(p))
	var ks: Array = sorted_keys(p)
	if ks.is_empty():
		return _static_plan(AnimProp._comp(p.get("base", 0.0), -1))
	return compile_keys(ks)


static func plan_of(p: Dictionary) -> Dictionary:
	var h: int = p.hash()
	var hit: Variant = _plans.get(h, null)
	if hit is Array and (hit as Array)[0] == p:
		memo_hits += 1
		return (hit as Array)[1]
	var plan: Dictionary = compile(p) if exact_ok(p) else {}
	if _plans.size() >= PLAN_MEMO_MAX:
		_plans.clear()
	_plans[h] = [p.duplicate(true), plan]
	return plan


static func _ease_of(a: Dictionary, mode: String) -> PackedStringArray:
	var fam: String = ""
	var dir: String = ""
	if mode == "ease_in" or mode == "ease_out" or mode == "ease_both":
		fam = str(a.get("ease", "cubic"))
		dir = str(a.get("dir", ""))
		if dir.is_empty():
			dir = "in" if mode == "ease_in" else ("out" if mode == "ease_out" else "inout")
	return PackedStringArray([fam, dir])


static func _bez_poly(a: Dictionary, b: Dictionary, va: float, vb: float, seg: float) -> PackedFloat64Array:
	var ho: Array = AnimProp._handle(a, "ho", seg, true, -1)
	var hi: Array = AnimProp._handle(b, "hi", seg, false, -1)
	var x1: float = float(ho[0])
	var x2: float = seg + float(hi[0])
	var y0: float = va
	var y1: float = va + float(ho[1])
	var y2: float = vb + float(hi[1])
	var y3: float = vb
	var a1: float = 3.0 * x1
	var a2: float = 3.0 * (x2 - 2.0 * x1)
	var a3: float = 3.0 * x1 - 3.0 * x2 + seg
	var b0: float = y0
	var b1: float = 3.0 * (y1 - y0)
	var b2: float = 3.0 * (y0 - 2.0 * y1 + y2)
	var b3: float = 3.0 * (y1 - y2) + y3 - y0
	var bs: PackedFloat64Array = PackedFloat64Array([b0, b1, b2, b3])
	var ds: PackedFloat64Array = PackedFloat64Array([a1, 2.0 * a2, 3.0 * a3])
	var e: PackedFloat64Array = PackedFloat64Array()
	e.resize(6)
	e.fill(0.0)
	for i: int in 4:
		for j: int in 3:
			e[i + j] += bs[i] * ds[j]
	var out: PackedFloat64Array = PackedFloat64Array([a1, a2, a3, b0, b1, b2, b3])
	for k: int in 6:
		out.append(e[k] / float(k + 1))
	out.append(minf(minf(y0, y1), minf(y2, y3)))
	out.append(maxf(maxf(y0, y1), maxf(y2, y3)))
	return out


static func _bez_s(poly: PackedFloat64Array, tr: float, seg: float) -> float:
	var a1: float = poly[0]
	var a2: float = poly[1]
	var a3: float = poly[2]
	if tr <= 0.0:
		return 0.0
	if tr >= seg:
		return 1.0
	var lo: float = 0.0
	var hi: float = 1.0
	var s: float = tr / seg
	for _k: int in BEZ_STEPS:
		var err: float = ((a3 * s + a2) * s + a1) * s - tr
		if absf(err) <= ROOT_EPS * maxf(seg, 1.0):
			break
		if err < 0.0:
			lo = s
		else:
			hi = s
		var d: float = (3.0 * a3 * s + 2.0 * a2) * s + a1
		var ns: float = s - err / d if d > 0.0 else -1.0
		if not (ns > lo and ns < hi):
			ns = (lo + hi) * 0.5
		s = ns
		if hi - lo <= 0.000000000000001:
			break
	return s


static func _bez_area(poly: PackedFloat64Array, s: float) -> float:
	return (((((poly[12] * s + poly[11]) * s + poly[10]) * s + poly[9]) * s + poly[8]) * s + poly[7]) * s


static func _bez_y(poly: PackedFloat64Array, s: float) -> float:
	return ((poly[6] * s + poly[5]) * s + poly[4]) * s + poly[3]


static func _herm_poly(ks: Array, i: int, va: float, vb: float, seg: float, auto: bool) -> PackedFloat64Array:
	var sm0: float = seg * AnimProp._tangent(ks, i, auto, -1)
	var sm1: float = seg * AnimProp._tangent(ks, i + 1, auto, -1)
	var c0: float = va
	var c1: float = sm0
	var c2: float = -3.0 * va - 2.0 * sm0 + 3.0 * vb - sm1
	var c3: float = 2.0 * va + sm0 - 2.0 * vb + sm1
	var lo: float = minf(va, vb)
	var hi: float = maxf(va, vb)
	var qa: float = 3.0 * c3
	var qb: float = 2.0 * c2
	var qc: float = c1
	var roots: PackedFloat64Array = PackedFloat64Array()
	if absf(qa) > 0.000000001:
		var disc: float = qb * qb - 4.0 * qa * qc
		if disc >= 0.0:
			var sq: float = sqrt(disc)
			roots.append((-qb + sq) / (2.0 * qa))
			roots.append((-qb - sq) / (2.0 * qa))
	elif absf(qb) > 0.000000001:
		roots.append(-qc / qb)
	for r: float in roots:
		if r > 0.0 and r < 1.0:
			var v: float = ((c3 * r + c2) * r + c1) * r + c0
			lo = minf(lo, v)
			hi = maxf(hi, v)
	return PackedFloat64Array([c0, c1, c2, c3, lo, hi])


static func compile_keys(ks: Array) -> Dictionary:
	var n: int = ks.size()
	if n == 0:
		return _static_plan(1.0)
	if n == 1:
		return _static_plan(key_value(ks[0]))
	var ts: PackedFloat64Array = PackedFloat64Array()
	var vs: PackedFloat64Array = PackedFloat64Array()
	ts.resize(n)
	vs.resize(n)
	for i: int in n:
		ts[i] = float((ks[i] as Dictionary).get("t", 0.0))
		vs[i] = key_value(ks[i])
	var kinds: PackedInt32Array = PackedInt32Array()
	kinds.resize(n - 1)
	var tabs: Array = []
	var los: PackedFloat64Array = PackedFloat64Array()
	var his: PackedFloat64Array = PackedFloat64Array()
	los.resize(n - 1)
	his.resize(n - 1)
	var area: PackedFloat64Array = PackedFloat64Array()
	area.resize(n)
	area[0] = vs[0] * ts[0]
	var rising: bool = vs[0] > 0.0 and vs[n - 1] > 0.0
	for i: int in n - 1:
		var a: Dictionary = ks[i]
		var seg: float = ts[i + 1] - ts[i]
		var mode: String = str(a.get("i", "linear"))
		var whole: float = 0.0
		var lo: float = vs[i]
		var hi: float = vs[i]
		if seg <= 0.0 or mode == "hold":
			kinds[i] = KIND_HOLD
			tabs.append([])
			whole = vs[i] * maxf(seg, 0.0)
		elif mode == "bezier":
			kinds[i] = KIND_GENERAL
			var bp: PackedFloat64Array = _bez_poly(a, ks[i + 1], vs[i], vs[i + 1], seg)
			tabs.append(bp)
			whole = _bez_area(bp, 1.0)
			lo = bp[13]
			hi = bp[14]
		elif mode == "continuous" or mode == "auto":
			kinds[i] = KIND_HERMITE
			var hp: PackedFloat64Array = _herm_poly(ks, i, vs[i], vs[i + 1], seg, mode == "auto")
			tabs.append(hp)
			whole = seg * (hp[0] + hp[1] / 2.0 + hp[2] / 3.0 + hp[3] / 4.0)
			lo = hp[4]
			hi = hp[5]
		else:
			kinds[i] = KIND_SHAPE
			var fd: PackedStringArray = _ease_of(a, mode)
			var unit: Array = _unit(fd[0], fd[1])
			tabs.append(unit)
			var ua: PackedFloat64Array = unit[0]
			var dv: float = vs[i + 1] - vs[i]
			whole = seg * (vs[i] + dv * ua[ua.size() - 1])
			var e0: float = vs[i] + dv * float(unit[2])
			var e1: float = vs[i] + dv * float(unit[3])
			lo = minf(e0, e1)
			hi = maxf(e0, e1)
		los[i] = lo
		his[i] = hi
		if lo <= 0.0:
			rising = false
		area[i + 1] = area[i] + whole
	var plan: Dictionary = {"static": false, "n": n, "t": ts, "v": vs, "kind": kinds, "tab": tabs, "area": area, "zero": 0.0, "keys": ks, "lo": los, "hi": his, "rising": rising}
	plan["zero"] = _antideriv(plan, 0.0)
	return plan


static func _partial(plan: Dictionary, i: int, x: float) -> float:
	var ts: PackedFloat64Array = plan["t"]
	var vs: PackedFloat64Array = plan["v"]
	var seg: float = ts[i + 1] - ts[i]
	var kind: int = (plan["kind"] as PackedInt32Array)[i]
	if kind == KIND_HOLD:
		return vs[i] * x * seg
	if kind == KIND_GENERAL:
		var bp: PackedFloat64Array = (plan["tab"] as Array)[i]
		return _bez_area(bp, _bez_s(bp, x * seg, seg))
	if kind == KIND_HERMITE:
		var hp: PackedFloat64Array = (plan["tab"] as Array)[i]
		return seg * ((((hp[3] / 4.0) * x + hp[2] / 3.0) * x + hp[1] / 2.0) * x + hp[0]) * x
	var unit: Array = (plan["tab"] as Array)[i]
	return seg * (vs[i] * x + (vs[i + 1] - vs[i]) * _herm_val(unit[0], unit[1], x))


static func _partial_rate(plan: Dictionary, i: int, x: float) -> float:
	var ts: PackedFloat64Array = plan["t"]
	var vs: PackedFloat64Array = plan["v"]
	var seg: float = ts[i + 1] - ts[i]
	var kind: int = (plan["kind"] as PackedInt32Array)[i]
	if kind == KIND_HOLD:
		return vs[i] * seg
	if kind == KIND_GENERAL:
		var bp: PackedFloat64Array = (plan["tab"] as Array)[i]
		return seg * _bez_y(bp, _bez_s(bp, x * seg, seg))
	if kind == KIND_HERMITE:
		var hp: PackedFloat64Array = (plan["tab"] as Array)[i]
		return seg * (((hp[3] * x + hp[2]) * x + hp[1]) * x + hp[0])
	var unit: Array = (plan["tab"] as Array)[i]
	return seg * (vs[i] + (vs[i + 1] - vs[i]) * _herm_der(unit[0], unit[1], x))


static func _seg_solve(plan: Dictionary, i: int, need: float) -> float:
	var ts: PackedFloat64Array = plan["t"]
	var vs: PackedFloat64Array = plan["v"]
	var seg: float = ts[i + 1] - ts[i]
	if seg <= 0.0:
		return 0.0
	if (plan["kind"] as PackedInt32Array)[i] == KIND_HOLD:
		return clampf(need / (vs[i] * seg), 0.0, 1.0) if absf(vs[i]) > 0.000000000001 else 0.0
	var whole: float = _partial(plan, i, 1.0)
	var up: bool = whole >= 0.0
	var lo: float = 0.0
	var hi: float = 1.0
	var x: float = clampf(need / whole, 0.0, 1.0) if absf(whole) > 0.000000000001 else 0.5
	for _k: int in INVERT_STEPS:
		var f: float = _partial(plan, i, x) - need
		if absf(f) <= ROOT_EPS * maxf(1.0, absf(need)):
			break
		if (f < 0.0) == up:
			lo = x
		else:
			hi = x
		var d: float = _partial_rate(plan, i, x)
		var nx: float = x - f / d if d != 0.0 else -1.0
		if not (nx > lo and nx < hi):
			nx = (lo + hi) * 0.5
		x = nx
		if hi - lo <= 0.000000000000001:
			break
	return x


static func _antideriv(plan: Dictionary, u: float) -> float:
	var ts: PackedFloat64Array = plan["t"]
	var vs: PackedFloat64Array = plan["v"]
	var area: PackedFloat64Array = plan["area"]
	var n: int = int(plan["n"])
	if u <= ts[0]:
		return vs[0] * u
	if u >= ts[n - 1]:
		return area[n - 1] + vs[n - 1] * (u - ts[n - 1])
	var i: int = clampi(ts.bsearch(u, true) - 1, 0, n - 2)
	var seg: float = ts[i + 1] - ts[i]
	if seg <= 0.0:
		return area[i]
	return area[i] + _partial(plan, i, (u - ts[i]) / seg)


static func integral(plan: Dictionary, u: float) -> float:
	if bool(plan["static"]):
		return float(plan["v"]) * u
	return _antideriv(plan, u) - float(plan["zero"])


static func value_at(plan: Dictionary, u: float) -> float:
	if bool(plan["static"]):
		return float(plan["v"])
	var ts: PackedFloat64Array = plan["t"]
	var vs: PackedFloat64Array = plan["v"]
	var n: int = int(plan["n"])
	if u <= ts[0]:
		return vs[0]
	if u >= ts[n - 1]:
		return vs[n - 1]
	var i: int = clampi(ts.bsearch(u, true) - 1, 0, n - 2)
	var seg: float = ts[i + 1] - ts[i]
	if seg <= 0.0 or (plan["kind"] as PackedInt32Array)[i] == KIND_HOLD:
		return vs[i]
	return AnimProp._eval_segment(plan["keys"], i, u, -1)


static func inverse(plan: Dictionary, s: float) -> float:
	if bool(plan["static"]):
		var v: float = float(plan["v"])
		return s / v if absf(v) > 0.000001 else 0.0
	var want: float = s + float(plan["zero"])
	var ts: PackedFloat64Array = plan["t"]
	var vs: PackedFloat64Array = plan["v"]
	var area: PackedFloat64Array = plan["area"]
	var n: int = int(plan["n"])
	if want <= area[0]:
		return want / vs[0] if vs[0] > 0.000001 else ts[0]
	if want >= area[n - 1]:
		return ts[n - 1] + ((want - area[n - 1]) / vs[n - 1] if vs[n - 1] > 0.000001 else 0.0)
	var i: int = clampi(area.bsearch(want, true) - 1, 0, n - 2)
	var seg: float = ts[i + 1] - ts[i]
	if seg <= 0.0:
		return ts[i]
	return ts[i] + _seg_solve(plan, i, want - area[i]) * seg


static func frame_map(p: Dictionary, dur: float) -> Dictionary:
	if not AnimProp.is_animated(p):
		var sv: Variant = p.get("v", 1.0)
		if not (sv is float or sv is int):
			return {}
		var v: float = float(sv)
		return {"plan": _static_plan(v), "dur": dur, "end": v * maxf(dur, 0.0), "v0": v, "v1": v, "rising": v > 0.0}
	var plan: Dictionary = plan_of(p)
	if plan.is_empty():
		return {}
	var v0: float = AnimProp.evaluate_float(p, 0.0, dur)
	var v1: float = AnimProp.evaluate_float(p, dur, dur)
	var end: float = integral(plan, dur) if dur > 0.0 else 0.0
	return {"plan": plan, "dur": dur, "end": end, "v0": v0, "v1": v1, "rising": bool(plan["rising"]) and v0 > 0.0 and v1 > 0.0}


static func map_source(m: Dictionary, u: float) -> float:
	var dur: float = float(m["dur"])
	if dur <= 0.0 or u <= 0.0:
		return u * float(m["v0"])
	if u >= dur:
		return float(m["end"]) + (u - dur) * float(m["v1"])
	return integral(m["plan"], u)


static func map_local(m: Dictionary, s: float, lo: float, hi: float) -> float:
	if bool(m["rising"]):
		var dur: float = float(m["dur"])
		var end: float = float(m["end"])
		var u: float = 0.0
		if dur <= 0.0 or s <= 0.0:
			u = s / float(m["v0"])
		elif s >= end:
			u = dur + (s - end) / float(m["v1"])
		else:
			u = inverse(m["plan"], s)
		return clampf(u, lo, hi)
	var a: float = lo
	var b: float = hi
	for _i: int in LOCAL_STEPS:
		var mid: float = (a + b) * 0.5
		if map_source(m, mid) < s:
			a = mid
		else:
			b = mid
	return (a + b) * 0.5


static func curve_local(plan: Dictionary, s: float, lo: float, hi: float) -> float:
	if bool(plan["rising"]):
		return clampf(inverse(plan, s), lo, hi)
	var a: float = lo
	var b: float = hi
	for _i: int in LOCAL_STEPS:
		var mid: float = (a + b) * 0.5
		if integral(plan, mid) < s:
			a = mid
		else:
			b = mid
	return (a + b) * 0.5


static func _region_mono(plan: Dictionary, a: float, b: float) -> bool:
	var ts: PackedFloat64Array = plan["t"]
	var n: int = int(plan["n"])
	var mid: float = (a + b) * 0.5
	if mid <= ts[0] or mid >= ts[n - 1]:
		return true
	var i: int = clampi(ts.bsearch(mid, true) - 1, 0, n - 2)
	return (plan["lo"] as PackedFloat64Array)[i] >= 0.0 or (plan["hi"] as PackedFloat64Array)[i] <= 0.0


static func _solve_region(plan: Dictionary, a: float, b: float, target: float) -> float:
	var ts: PackedFloat64Array = plan["t"]
	var vs: PackedFloat64Array = plan["v"]
	var area: PackedFloat64Array = plan["area"]
	var n: int = int(plan["n"])
	var want: float = target + float(plan["zero"])
	var mid: float = (a + b) * 0.5
	if mid <= ts[0]:
		return want / vs[0]
	if mid >= ts[n - 1]:
		return ts[n - 1] + (want - area[n - 1]) / vs[n - 1]
	var i: int = clampi(ts.bsearch(mid, true) - 1, 0, n - 2)
	var seg: float = ts[i + 1] - ts[i]
	return ts[i] + _seg_solve(plan, i, want - area[i]) * seg


static func walk_span(plan: Dictionary, span: float) -> float:
	if bool(plan["static"]):
		var v: float = absf(float(plan["v"]))
		if v <= 0.000001:
			return -1.0
		var u0: float = span / v
		return u0 if u0 < WALK_MAX else -1.0
	var cuts: PackedFloat64Array = PackedFloat64Array([0.0])
	for t: float in (plan["t"] as PackedFloat64Array):
		if t > 0.0 and t < WALK_MAX:
			cuts.append(t)
	cuts.append(WALK_MAX)
	var step: float = 1.0 / WALK_RATE
	for c: int in cuts.size() - 1:
		var a: float = cuts[c]
		var b: float = cuts[c + 1]
		if b <= a:
			continue
		var ia: float = integral(plan, a)
		var ib: float = integral(plan, b)
		if _region_mono(plan, a, b):
			if absf(ib) >= span and absf(ib - ia) > 0.0:
				return _solve_region(plan, a, b, span if ib > ia else -span)
			continue
		var u: float = a
		var acc: float = ia
		while u < b:
			var nu: float = minf(u + step, b)
			var nxt: float = integral(plan, nu)
			if absf(nxt) >= span:
				var need: float = span - absf(acc)
				var rate: float = absf(nxt - acc) / (nu - u)
				return u + (need / rate if rate > 0.0 else nu - u)
			acc = nxt
			u = nu
	return -1.0


static func positive(p: Dictionary) -> bool:
	if not AnimProp.is_animated(p):
		return static_value(p) > 0.0
	for k: Variant in keys_layer(p).get("keys", []):
		if key_value(k) <= 0.0:
			return false
	return true


static func pinned(k: Dictionary, owner: String) -> bool:
	if not k.has(PIN) or float(k[PIN]) < 0.0 or String(k.get(OWNER, "")) != owner:
		return false
	var at: float = float(k.get(AT, NAN))
	return not is_nan(at) and absf(at - float(k.get("t", 0.0))) <= MOVE_EPS


static func solve_pins(p: Dictionary, in_offset: float, owner: String) -> Dictionary:
	solves += 1
	if not AnimProp.is_animated(p) or plant_ignore:
		return {"prop": p, "ok": true, "plan": compile(p)}
	var ks: Array = sorted_keys(p)
	var n: int = ks.size()
	var pins: PackedFloat64Array = PackedFloat64Array()
	pins.resize(n)
	var any: bool = false
	var general: bool = false
	for i: int in n:
		var k: Dictionary = ks[i]
		pins[i] = float(k[PIN]) - in_offset if pinned(k, owner) else NAN
		if not is_nan(pins[i]):
			any = true
		var mode: String = str(k.get("i", "linear"))
		if mode == "bezier" or mode == "continuous" or mode == "auto":
			general = true
	if not any or n < 1:
		return {"prop": p, "ok": true, "plan": compile_keys(ks)}
	var ok: bool = true
	var plan: Dictionary = {}
	for pass_i: int in (SOLVE_PASSES if general else 1):
		plan = compile_keys(ks)
		var moved: bool = false
		ok = true
		var ts: PackedFloat64Array = PackedFloat64Array()
		ts.resize(n)
		var acc: float = 0.0
		for i: int in n:
			var k: Dictionary = ks[i]
			var t: float = float(k.get("t", 0.0))
			var v: float = key_value(k)
			if i == 0:
				if not is_nan(pins[0]) and t >= 0.0 and v > 0.0:
					t = maxf(pins[0] / v, 0.0)
				acc = v * t if t >= 0.0 else -_head_back(plan, t)
			else:
				var prev_t: float = ts[i - 1]
				var mean: float = _mean(plan, ks, i - 1, prev_t, t)
				if not is_nan(pins[i]):
					if mean <= 0.000001:
						ok = false
					else:
						t = prev_t + (pins[i] - acc) / mean
				if t <= prev_t + GAP:
					ok = false
					t = prev_t + GAP
				acc += mean * (t - prev_t)
			ts[i] = t
			if absf(t - float(k.get("t", 0.0))) > 0.0000001:
				moved = true
		for i2: int in n:
			var k2: Dictionary = ks[i2]
			if absf(float(k2.get("t", 0.0)) - ts[i2]) > 0.0000001:
				k2["t"] = ts[i2]
				if not is_nan(pins[i2]):
					k2[AT] = ts[i2]
		if not moved:
			break
	plan = compile_keys(ks)
	return {"prop": with_keys(p, ks), "ok": ok, "plan": plan}


static func _head_back(plan: Dictionary, t: float) -> float:
	if bool(plan["static"]):
		return float(plan["v"]) * -t
	return float(plan["zero"]) - _antideriv(plan, t)


static func _mean(plan: Dictionary, ks: Array, i: int, ta: float, tb: float) -> float:
	var a: Dictionary = ks[i]
	var b: Dictionary = ks[i + 1]
	var va: float = key_value(a)
	var vb: float = key_value(b)
	var mode: String = str(a.get("i", "linear"))
	if mode == "hold":
		return va
	if mode == "bezier" or mode == "continuous" or mode == "auto":
		if bool(plan["static"]):
			return va
		var ts: PackedFloat64Array = plan["t"]
		var seg: float = ts[i + 1] - ts[i]
		if seg <= 0.0:
			return va
		return (_partial(plan, i, 1.0)) / seg
	var fd: PackedStringArray = _ease_of(a, mode)
	var tab: PackedFloat64Array = unit_table(fd[0], fd[1])
	return va + (vb - va) * tab[tab.size() - 1]


static func moved_pins(p: Dictionary, plan: Dictionary, in_offset: float, owner: String) -> Dictionary:
	if not AnimProp.is_animated(p):
		return p
	var ks: Array = sorted_keys(p)
	var changed: bool = false
	for kv: Variant in ks:
		var k: Dictionary = kv
		if not pinned(k, owner):
			continue
		var nt: float = inverse(plan, float(k[PIN]) - in_offset)
		if absf(nt - float(k.get("t", 0.0))) <= 0.0000001:
			continue
		k["t"] = nt
		k[AT] = nt
		changed = true
	if not changed:
		return p
	ks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))
	return with_keys(p, ks)


static func has_pins(p: Dictionary, owner: String) -> bool:
	if not AnimProp.is_animated(p):
		return false
	for k: Variant in keys_layer(p).get("keys", []):
		if k is Dictionary and pinned(k, owner):
			return true
	return false

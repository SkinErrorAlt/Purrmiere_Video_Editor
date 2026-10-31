extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const PATH := "transform.pos"
const TEMPORAL_MODES: PackedStringArray = ["linear", "hold", "ease_in", "ease_out", "ease_both"]
const SIMPLIFY_SHARE := 0.01
const SIMPLIFY_MIN := 0.5
const SIMPLIFY_PROBES := 8
const ROVE_GAP := 0.001
const HANDLE_MIN := 0.0001


static func keys_array(p: Dictionary) -> Array:
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0:
		return []
	var out: Array = []
	for k: Variant in (p["layers"][li] as Dictionary).get("keys", []):
		if k is Dictionary:
			out.append((k as Dictionary).duplicate(true))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))
	return out


static func with_keys(p: Dictionary, ks: Array) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	var li: int = AnimProp.keys_layer_index(out)
	if li < 0:
		return out
	(out["layers"][li] as Dictionary)["keys"] = ks
	return out


static func is_path(p: Dictionary) -> bool:
	var ks: Array = keys_array(p)
	if ks.size() < 2:
		return false
	for k: Dictionary in ks:
		var v: Variant = k.get("v", 0.0)
		if not (v is Array) or (v as Array).size() != 2:
			return false
	return true


static func key_pos(ks: Array, i: int) -> Vector2:
	return AnimProp.vec_of((ks[i] as Dictionary).get("v", 0.0))


static func tangents(ks: Array, i: int) -> PackedVector2Array:
	return PackedVector2Array([AnimProp.spatial_in(ks, i), AnimProp.spatial_out(ks, i)])


static func _targets(ks: Array, idx: PackedInt32Array) -> PackedInt32Array:
	if not idx.is_empty():
		var out: PackedInt32Array = PackedInt32Array()
		for i: int in idx:
			if i >= 0 and i < ks.size():
				out.append(i)
		return out
	var all: PackedInt32Array = PackedInt32Array()
	for i: int in ks.size():
		all.append(i)
	return all


static func _put(k: Dictionary, field: String, v: Vector2) -> void:
	k[field] = [v.x, v.y]


static func _drop_handles(k: Dictionary) -> void:
	k.erase(AnimProp.SPATIAL_OUT)
	k.erase(AnimProp.SPATIAL_IN)


static func _store(k: Dictionary, i: int, n: int, tin: Vector2, tout: Vector2) -> void:
	_drop_handles(k)
	if i > 0:
		_put(k, AnimProp.SPATIAL_IN, tin)
	if i < n - 1:
		_put(k, AnimProp.SPATIAL_OUT, tout)


static func set_spatial(p: Dictionary, idx: PackedInt32Array, kind: String) -> Dictionary:
	if not AnimProp.SPATIAL_KINDS.has(kind):
		return p.duplicate(true)
	var ks: Array = keys_array(p)
	var n: int = ks.size()
	var plan: Array = []
	for i: int in _targets(ks, idx):
		var tg: PackedVector2Array = tangents(ks, i)
		if tg[0].length() <= HANDLE_MIN and tg[1].length() <= HANDLE_MIN:
			tg = AnimProp.auto_tangents(ks, i)
		plan.append([i, tg])
	for row: Array in plan:
		var i: int = row[0]
		var tg: PackedVector2Array = row[1]
		var k: Dictionary = ks[i]
		k[AnimProp.SPATIAL_KIND] = kind
		if kind == AnimProp.SPATIAL_LINEAR or kind == AnimProp.SPATIAL_SMOOTH:
			_drop_handles(k)
			continue
		var tin: Vector2 = tg[0]
		var tout: Vector2 = tg[1]
		if kind == AnimProp.SPATIAL_CONTINUOUS and tin.length() > HANDLE_MIN and tout.length() > HANDLE_MIN:
			var dir: Vector2 = (tout - tin).normalized()
			tout = dir * tout.length()
			tin = -dir * tin.length()
		_store(k, i, n, tin, tout)
	return with_keys(p, ks)


static func set_temporal(p: Dictionary, idx: PackedInt32Array, mode: String) -> Dictionary:
	if not TEMPORAL_MODES.has(mode):
		return p.duplicate(true)
	var ks: Array = keys_array(p)
	for i: int in _targets(ks, idx):
		var k: Dictionary = ks[i]
		k["i"] = mode
		k.erase("dir")
	return with_keys(p, ks)


static func move_key(p: Dictionary, i: int, pos: Vector2) -> Dictionary:
	var ks: Array = keys_array(p)
	if i < 0 or i >= ks.size():
		return p.duplicate(true)
	(ks[i] as Dictionary)["v"] = [pos.x, pos.y]
	return with_keys(p, ks)


static func set_handle(p: Dictionary, i: int, side: String, v: Vector2, broken: bool) -> Dictionary:
	var ks: Array = keys_array(p)
	var n: int = ks.size()
	if i < 0 or i >= n:
		return p.duplicate(true)
	var k: Dictionary = ks[i]
	var tg: PackedVector2Array = tangents(ks, i)
	var free: bool = broken or AnimProp.spatial_kind(k) == AnimProp.SPATIAL_BEZIER
	var tin: Vector2 = tg[0]
	var tout: Vector2 = tg[1]
	if side == "out":
		tout = v
		if not free and i > 0:
			var reach: float = tin.length() if tin.length() > HANDLE_MIN else v.length()
			tin = -v.normalized() * reach
	else:
		tin = v
		if not free and i < n - 1:
			var reach2: float = tout.length() if tout.length() > HANDLE_MIN else v.length()
			tout = -v.normalized() * reach2
	k[AnimProp.SPATIAL_KIND] = AnimProp.SPATIAL_BEZIER if free else AnimProp.SPATIAL_CONTINUOUS
	_store(k, i, n, tin, tout)
	return with_keys(p, ks)


static func pull_handles(p: Dictionary, i: int, v: Vector2) -> Dictionary:
	var ks: Array = keys_array(p)
	var n: int = ks.size()
	if i < 0 or i >= n:
		return p.duplicate(true)
	var k: Dictionary = ks[i]
	k[AnimProp.SPATIAL_KIND] = AnimProp.SPATIAL_CONTINUOUS
	_store(k, i, n, -v, v)
	return with_keys(p, ks)


static func _keys_only(p: Dictionary, ks: Array) -> Dictionary:
	var layer: Dictionary = {"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": "once", "keys": ks}
	return {"a": true, "base": p.get("base", [0.0, 0.0]), "layers": [layer]}


static func path_value(p: Dictionary, kt: float) -> Vector2:
	return AnimProp.evaluate_vec2(_keys_only(p, keys_array(p)), kt, 0.0, 0.0)


static func segment_of(ks: Array, kt: float) -> int:
	for i: int in range(ks.size() - 1):
		if kt >= float((ks[i] as Dictionary).get("t", 0.0)) and kt < float((ks[i + 1] as Dictionary).get("t", 0.0)):
			return i
	return -1


static func _lerp2(a: Vector2, b: Vector2, s: float) -> Vector2:
	return a + (b - a) * s


static func add_key(p: Dictionary, kt: float) -> Dictionary:
	var ks: Array = keys_array(p)
	if AnimProp.has_key_at(p, kt):
		return p.duplicate(true)
	var i: int = segment_of(ks, kt)
	if i < 0:
		var v0: Vector2 = path_value(p, kt)
		return AnimProp.set_key(p, kt, [v0.x, v0.y])
	var a: Dictionary = ks[i]
	var b: Dictionary = ks[i + 1]
	var nk: Dictionary = {"t": kt, "i": str(a.get("i", "linear"))}
	for f: String in ["ease", "dir"]:
		if a.has(f):
			nk[f] = a[f]
	if not AnimProp.seg_spatial(ks, i):
		var v1: Vector2 = path_value(p, kt)
		nk["v"] = [v1.x, v1.y]
		ks.insert(i + 1, nk)
		return with_keys(p, ks)
	var cp: PackedVector2Array = AnimProp.seg_controls(ks, i)
	var table: PackedFloat64Array = AnimProp.arc_table(cp)
	var total: float = table[AnimProp.ARC_STEPS]
	var s: float = AnimProp.param_at_length(table, clampf(AnimProp.spatial_travel(ks, i, kt, total), 0.0, total))
	var q1: Vector2 = _lerp2(cp[0], cp[1], s)
	var q2: Vector2 = _lerp2(cp[1], cp[2], s)
	var q3: Vector2 = _lerp2(cp[2], cp[3], s)
	var r1: Vector2 = _lerp2(q1, q2, s)
	var r2: Vector2 = _lerp2(q2, q3, s)
	var mid: Vector2 = _lerp2(r1, r2, s)
	nk["v"] = [mid.x, mid.y]
	var ka: String = AnimProp.spatial_kind(a)
	var kb: String = AnimProp.spatial_kind(b)
	var explicit: Array = [AnimProp.SPATIAL_BEZIER, AnimProp.SPATIAL_CONTINUOUS]
	if explicit.has(ka) or (ka.is_empty() and a.get(AnimProp.SPATIAL_OUT) is Array):
		_put(a, AnimProp.SPATIAL_OUT, q1 - cp[0])
	if explicit.has(kb) or (kb.is_empty() and b.get(AnimProp.SPATIAL_IN) is Array):
		_put(b, AnimProp.SPATIAL_IN, q3 - cp[3])
	if ka == AnimProp.SPATIAL_SMOOTH or kb == AnimProp.SPATIAL_SMOOTH:
		nk[AnimProp.SPATIAL_KIND] = AnimProp.SPATIAL_SMOOTH
	elif ka == AnimProp.SPATIAL_LINEAR and kb == AnimProp.SPATIAL_LINEAR:
		nk[AnimProp.SPATIAL_KIND] = AnimProp.SPATIAL_LINEAR
	else:
		nk[AnimProp.SPATIAL_KIND] = AnimProp.SPATIAL_CONTINUOUS
		_put(nk, AnimProp.SPATIAL_IN, r1 - mid)
		_put(nk, AnimProp.SPATIAL_OUT, r2 - mid)
	ks.insert(i + 1, nk)
	return with_keys(p, ks)


static func delete_keys(p: Dictionary, idx: PackedInt32Array) -> Dictionary:
	var ks: Array = keys_array(p)
	var times: Array[float] = []
	for i: int in idx:
		if i >= 0 and i < ks.size():
			times.append(float((ks[i] as Dictionary).get("t", 0.0)))
	var out: Dictionary = p.duplicate(true)
	for t: float in times:
		out = AnimProp.remove_key(out, t)
	return out


static func delete_all_but_ends(p: Dictionary) -> Dictionary:
	var ks: Array = keys_array(p)
	if ks.size() <= 2:
		return p.duplicate(true)
	return with_keys(p, [ks[0], ks[ks.size() - 1]])


static func path_length(ks: Array) -> float:
	var total: float = 0.0
	for i: int in range(ks.size() - 1):
		total += AnimProp.seg_length(ks, i)
	return total


static func rove(p: Dictionary) -> Dictionary:
	var ks: Array = keys_array(p)
	var n: int = ks.size()
	if n < 2:
		return p.duplicate(true)
	var lengths: Array[float] = []
	for i: int in range(n - 1):
		lengths.append(AnimProp.seg_length(ks, i))
	var total: float = 0.0
	for l: float in lengths:
		total += l
	var t0: float = float((ks[0] as Dictionary).get("t", 0.0))
	var t1: float = float((ks[n - 1] as Dictionary).get("t", 0.0))
	if total <= 0.0 or t1 <= t0:
		return p.duplicate(true)
	var run: float = 0.0
	var prev: float = t0
	for j: int in range(1, n - 1):
		run += lengths[j - 1]
		var t: float = maxf(t0 + (t1 - t0) * run / total, prev + ROVE_GAP)
		(ks[j] as Dictionary)["t"] = t
		prev = t
	for j2: int in range(n - 1):
		var k: Dictionary = ks[j2]
		k["i"] = "linear"
		for f: String in ["dir", "ho", "hi"]:
			k.erase(f)
	return with_keys(p, ks)


static func _swap_dir(mode: String) -> String:
	if mode == "ease_in":
		return "ease_out"
	if mode == "ease_out":
		return "ease_in"
	return mode


static func reverse(p: Dictionary) -> Dictionary:
	var ks: Array = keys_array(p)
	var n: int = ks.size()
	if n < 2:
		return p.duplicate(true)
	var out: Array = []
	var t_first: float = float((ks[0] as Dictionary).get("t", 0.0))
	var t_last: float = float((ks[n - 1] as Dictionary).get("t", 0.0))
	for j: int in n:
		var src: Dictionary = ks[n - 1 - j]
		var timing: Dictionary = ks[maxi(n - 2 - j, 0)] if j < n - 1 else ks[0]
		var k: Dictionary = {"t": t_first + t_last - float(src.get("t", 0.0)), "v": (src.get("v", [0.0, 0.0]) as Array).duplicate(), "i": _swap_dir(str(timing.get("i", "linear")))}
		if timing.has("ease"):
			k["ease"] = timing["ease"]
		var dir: String = str(timing.get("dir", ""))
		if dir == "in":
			k["dir"] = "out"
		elif dir == "out":
			k["dir"] = "in"
		elif not dir.is_empty():
			k["dir"] = dir
		if src.has(AnimProp.SPATIAL_KIND):
			k[AnimProp.SPATIAL_KIND] = src[AnimProp.SPATIAL_KIND]
		if src.get(AnimProp.SPATIAL_IN) is Array:
			k[AnimProp.SPATIAL_OUT] = (src[AnimProp.SPATIAL_IN] as Array).duplicate()
		if src.get(AnimProp.SPATIAL_OUT) is Array:
			k[AnimProp.SPATIAL_IN] = (src[AnimProp.SPATIAL_OUT] as Array).duplicate()
		out.append(k)
	return with_keys(p, out)


static func default_tolerance(p: Dictionary) -> float:
	var ks: Array = keys_array(p)
	if ks.is_empty():
		return SIMPLIFY_MIN
	var box: Rect2 = Rect2(key_pos(ks, 0), Vector2.ZERO)
	for i: int in ks.size():
		box = box.expand(key_pos(ks, i))
	return maxf(SIMPLIFY_MIN, box.size.length() * SIMPLIFY_SHARE)


static func _probe_times(ks: Array, j: int, all_times: PackedFloat64Array) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var ta: float = float((ks[j - 1] as Dictionary).get("t", 0.0))
	var tb: float = float((ks[j + 1] as Dictionary).get("t", 0.0))
	for q: int in range(1, SIMPLIFY_PROBES):
		out.append(ta + (tb - ta) * float(q) / float(SIMPLIFY_PROBES))
	for t: float in all_times:
		if t > ta and t < tb:
			out.append(t)
	return out


static func simplify(p: Dictionary, tol: float) -> Dictionary:
	var ks: Array = keys_array(p)
	var whole: Dictionary = _keys_only(p, keys_array(p))
	var all_times: PackedFloat64Array = PackedFloat64Array()
	for k: Dictionary in ks:
		all_times.append(float(k.get("t", 0.0)))
	var j: int = 1
	while j < ks.size() - 1:
		var trial: Array = ks.duplicate(true)
		var probes: PackedFloat64Array = _probe_times(ks, j, all_times)
		trial.remove_at(j)
		var cand: Dictionary = _keys_only(p, trial)
		var worst: float = 0.0
		for t: float in probes:
			worst = maxf(worst, AnimProp.evaluate_vec2(cand, t, 0.0, 0.0).distance_to(AnimProp.evaluate_vec2(whole, t, 0.0, 0.0)))
			if worst > tol:
				break
		if worst <= tol:
			ks = trial
		else:
			j += 1
	return with_keys(p, ks)


static func smooth_path(p: Dictionary) -> Dictionary:
	var ks: Array = keys_array(p)
	var n: int = ks.size()
	if n < 3:
		return p.duplicate(true)
	var out: Array = ks.duplicate(true)
	for j: int in range(1, n - 1):
		var v: Vector2 = key_pos(ks, j - 1) * 0.25 + key_pos(ks, j) * 0.5 + key_pos(ks, j + 1) * 0.25
		(out[j] as Dictionary)["v"] = [v.x, v.y]
	return with_keys(p, out)


const CURVE_PRESETS: PackedStringArray = ["straight", "gentle", "strong", "s", "arc"]
const GENTLE_BOW := 0.2
const STRONG_BOW := 0.5
const S_BOW := 0.3
const BEND_EDGE := 0.08
const BEND_PROBES := 64
const BEND_REFINE := 24
const ARC_MAX := 5.6
const LINE_EPS := 0.0001


static func _tangent_table(ks: Array) -> Array:
	var out: Array = []
	for i: int in ks.size():
		out.append(tangents(ks, i))
	return out


static func _finish_handles(p: Dictionary, ks: Array, tg: Array, touched: Dictionary) -> Dictionary:
	var n: int = ks.size()
	for idx: Variant in touched.keys():
		var j: int = int(idx)
		var k: Dictionary = ks[j]
		var pair: PackedVector2Array = tg[j]
		k[AnimProp.SPATIAL_KIND] = String(touched[idx])
		_store(k, j, n, pair[0], pair[1])
	return with_keys(p, ks)


static func _set_seg(ks: Array, tg: Array, touched: Dictionary, i: int, out_h: Vector2, in_h: Vector2) -> void:
	var a: PackedVector2Array = tg[i]
	a[1] = out_h
	tg[i] = a
	var b: PackedVector2Array = tg[i + 1]
	b[0] = in_h
	tg[i + 1] = b
	if not touched.has(i):
		touched[i] = AnimProp.SPATIAL_BEZIER
	if not touched.has(i + 1):
		touched[i + 1] = AnimProp.SPATIAL_BEZIER


static func bend_controls(ks: Array, i: int) -> PackedVector2Array:
	var cp: PackedVector2Array = AnimProp.seg_controls(ks, i)
	if (cp[1] - cp[0]).length() <= HANDLE_MIN and (cp[2] - cp[3]).length() <= HANDLE_MIN:
		var third: Vector2 = (cp[3] - cp[0]) / 3.0
		cp[1] = cp[0] + third
		cp[2] = cp[3] - third
	return cp


static func nearest_param(cp: PackedVector2Array, at: Vector2) -> float:
	var best: float = 0.0
	var best_d: float = INF
	for j: int in BEND_PROBES + 1:
		var s: float = float(j) / float(BEND_PROBES)
		var d: float = AnimProp.bez2(cp, s).distance_squared_to(at)
		if d < best_d:
			best_d = d
			best = s
	var lo: float = maxf(best - 1.0 / float(BEND_PROBES), 0.0)
	var hi: float = minf(best + 1.0 / float(BEND_PROBES), 1.0)
	for _r: int in BEND_REFINE:
		var m1: float = lo + (hi - lo) / 3.0
		var m2: float = hi - (hi - lo) / 3.0
		if AnimProp.bez2(cp, m1).distance_squared_to(at) < AnimProp.bez2(cp, m2).distance_squared_to(at):
			hi = m2
		else:
			lo = m1
	return (lo + hi) * 0.5


static func bend_grab(p: Dictionary, kt: float) -> Dictionary:
	var ks: Array = keys_array(p)
	var i: int = segment_of(ks, kt)
	if i < 0:
		return {}
	var cp: PackedVector2Array = bend_controls(ks, i)
	var s: float = clampf(nearest_param(cp, path_value(p, kt)), BEND_EDGE, 1.0 - BEND_EDGE)
	return {"i": i, "s": s, "base": AnimProp.bez2(cp, s)}


static func bend(p: Dictionary, i: int, s: float, target: Vector2) -> Dictionary:
	var ks: Array = keys_array(p)
	if i < 0 or i + 1 >= ks.size():
		return p.duplicate(true)
	var u: float = clampf(s, BEND_EDGE, 1.0 - BEND_EDGE)
	var cp: PackedVector2Array = bend_controls(ks, i)
	var delta: Vector2 = (target - AnimProp.bez2(cp, u)) / (3.0 * u * (1.0 - u))
	var tg: Array = _tangent_table(ks)
	var touched: Dictionary = {}
	_set_seg(ks, tg, touched, i, cp[1] + delta - cp[0], cp[2] + delta - cp[3])
	return _finish_handles(p, ks, tg, touched)


static func _bow_side(ks: Array, i: int) -> float:
	var cp: PackedVector2Array = AnimProp.seg_controls(ks, i)
	var chord: Vector2 = cp[3] - cp[0]
	var n: Vector2 = chord.orthogonal().normalized()
	var bulge: float = (AnimProp.bez2(cp, 0.5) - (cp[0] + cp[3]) * 0.5).dot(n)
	return -1.0 if bulge < -HANDLE_MIN else 1.0


static func _circle(a: Vector2, b: Vector2, c: Vector2) -> Variant:
	var d: float = 2.0 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y))
	var size2: float = maxf(a.distance_squared_to(b), a.distance_squared_to(c))
	if absf(d) <= LINE_EPS * maxf(size2, 1.0):
		return null
	var aa: float = a.length_squared()
	var bb: float = b.length_squared()
	var cc: float = c.length_squared()
	return Vector2((aa * (b.y - c.y) + bb * (c.y - a.y) + cc * (a.y - b.y)) / d, (aa * (c.x - b.x) + bb * (a.x - c.x) + cc * (b.x - a.x)) / d)


static func _sweep(c: Vector2, a: Vector2, via: Vector2, b: Vector2) -> PackedFloat64Array:
	var a0: float = (a - c).angle()
	var whole: float = fposmod((b - c).angle() - a0, TAU)
	var part: float = fposmod((via - c).angle() - a0, TAU)
	if part <= whole:
		return PackedFloat64Array([whole, part])
	return PackedFloat64Array([whole - TAU, part - TAU])


static func _arc_handles(c: Vector2, a: Vector2, b: Vector2, theta: float) -> PackedVector2Array:
	var th: float = clampf(theta, -ARC_MAX, ARC_MAX)
	var k: float = 4.0 / 3.0 * tan(th / 4.0)
	var ra: Vector2 = a - c
	var rb: Vector2 = b - c
	return PackedVector2Array([Vector2(-ra.y, ra.x) * k, -Vector2(-rb.y, rb.x) * k])


static func _bow(ks: Array, tg: Array, touched: Dictionary, i: int, share: float, s_shape: bool) -> void:
	var a: Vector2 = key_pos(ks, i)
	var b: Vector2 = key_pos(ks, i + 1)
	var chord: Vector2 = b - a
	var lift: Vector2 = chord.orthogonal().normalized() * chord.length() * share * _bow_side(ks, i)
	_set_seg(ks, tg, touched, i, chord / 3.0 + lift, -chord / 3.0 + (-lift if s_shape else lift))


static func _arc_seg(ks: Array, tg: Array, touched: Dictionary, i: int, via: Vector2) -> void:
	var a: Vector2 = key_pos(ks, i)
	var b: Vector2 = key_pos(ks, i + 1)
	var centre: Variant = _circle(a, via, b)
	if not (centre is Vector2):
		_bow(ks, tg, touched, i, GENTLE_BOW, false)
		return
	var sw: PackedFloat64Array = _sweep(centre, a, via, b)
	var h: PackedVector2Array = _arc_handles(centre, a, b, sw[0])
	_set_seg(ks, tg, touched, i, h[0], h[1])


static func _arc_key(ks: Array, tg: Array, touched: Dictionary, j: int) -> void:
	var a: Vector2 = key_pos(ks, j - 1)
	var m: Vector2 = key_pos(ks, j)
	var b: Vector2 = key_pos(ks, j + 1)
	var centre: Variant = _circle(a, m, b)
	if not (centre is Vector2):
		_set_seg(ks, tg, touched, j - 1, (m - a) / 3.0, (a - m) / 3.0)
		_set_seg(ks, tg, touched, j, (b - m) / 3.0, (m - b) / 3.0)
	else:
		var sw: PackedFloat64Array = _sweep(centre, a, m, b)
		var h1: PackedVector2Array = _arc_handles(centre, a, m, sw[1])
		var h2: PackedVector2Array = _arc_handles(centre, m, b, sw[0] - sw[1])
		_set_seg(ks, tg, touched, j - 1, h1[0], h1[1])
		_set_seg(ks, tg, touched, j, h2[0], h2[1])
	touched[j] = AnimProp.SPATIAL_CONTINUOUS


static func preset_segments(ks: Array, keys: PackedInt32Array, seg: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if seg >= 0:
		if seg + 1 < ks.size():
			out.append(seg)
		return out
	for j: int in _targets(ks, keys):
		for i: int in [j - 1, j]:
			if i >= 0 and i + 1 < ks.size() and not out.has(i):
				out.append(i)
	out.sort()
	return out


static func arc_keys(ks: Array, keys: PackedInt32Array) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for j: int in _targets(ks, keys):
		if j > 0 and j + 1 < ks.size():
			out.append(j)
	return out


static func curve_preset(p: Dictionary, keys: PackedInt32Array, seg: int, preset: String, kt: float) -> Dictionary:
	if not CURVE_PRESETS.has(preset):
		return p.duplicate(true)
	var ks: Array = keys_array(p)
	var tg: Array = _tangent_table(ks)
	var touched: Dictionary = {}
	if preset == "arc" and seg < 0:
		for j: int in arc_keys(ks, keys):
			_arc_key(ks, tg, touched, j)
		return _finish_handles(p, ks, tg, touched)
	for i: int in preset_segments(ks, keys, seg):
		if preset == "straight":
			_set_seg(ks, tg, touched, i, Vector2.ZERO, Vector2.ZERO)
		elif preset == "gentle":
			_bow(ks, tg, touched, i, GENTLE_BOW, false)
		elif preset == "strong":
			_bow(ks, tg, touched, i, STRONG_BOW, false)
		elif preset == "s":
			_bow(ks, tg, touched, i, S_BOW, true)
		else:
			_arc_seg(ks, tg, touched, i, path_value(p, kt))
	return _finish_handles(p, ks, tg, touched)

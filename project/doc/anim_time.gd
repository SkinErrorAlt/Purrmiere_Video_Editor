extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const SPEED_PATH := "anim_speed"
const MEDIA_SPEED_PATH := "speed"
const START_FIELD := "anim_start"
const SPEED_MIN := -10.0
const SPEED_MAX := 10.0
const TABLE_RATE := 120.0
const TABLE_MAX := 8192
const EXACT_RATE := 960.0
const EXACT_MAX := 200000
const BAKE_RATE := 100.0
const BAKE_MAX := 400000
const BAKE_TOLERANCE := 0.0005
const SOLVE_EPS := 0.000001
const STEP_PROBE := 0.0005
const SAFE_EASES: PackedStringArray = ["sine", "quad", "cubic", "quart", "quint", "expo", "circ"]
const SPEED_TAIL := ".~speed"
const START_TAIL := ".~start"
const WHOLE := "~"
const SPEEDS_FIELD := "speeds"
const SPEED_KEY := "speed"
const START_KEY := "start"
const MOTION_KEYS: PackedStringArray = ["pos", "scale", "rotation", "anchor"]
const GROUPS: PackedStringArray = ["motion", "audio", "props"]
const INNER_SPAN := 32768
const BAND_KEYS: Dictionary = {"lowpass_hz": "audio_lowpass_hz", "highpass_hz": "audio_highpass_hz", "crush": "audio_crush"}


static func exempt(path: String) -> bool:
	return path == SPEED_PATH or path == MEDIA_SPEED_PATH


static func is_default_speed(p: Dictionary) -> bool:
	if AnimProp.is_animated(p):
		return false
	var v: Variant = p.get("v", 1.0)
	return (v is float or v is int) and float(v) == 1.0


static func speed_at(p: Dictionary, u: float, dur: float) -> float:
	return AnimProp.evaluate_float(p, u, dur)


static func break_times(p: Dictionary, dur: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if not AnimProp.is_animated(p):
		return out
	for k: Dictionary in AnimProp.keys(p):
		var t: float = float(k.get("t", 0.0))
		if t > 0.0 and t < dur:
			out.append(t)
	out.sort()
	return out


static func build_table(p: Dictionary, dur: float) -> PackedFloat64Array:
	var n: int = clampi(int(ceil(dur * TABLE_RATE)), 2, TABLE_MAX)
	var step: float = dur / float(n)
	var breaks: PackedFloat64Array = break_times(p, dur)
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(n + 1)
	out[0] = 0.0
	var bi: int = 0
	for i: int in n:
		var a: float = float(i) * step
		var b: float = a + step
		var acc: float = 0.0
		var x: float = a
		while bi < breaks.size() and breaks[bi] <= a:
			bi += 1
		var j: int = bi
		while j < breaks.size() and breaks[j] < b:
			acc += speed_at(p, (x + breaks[j]) * 0.5, dur) * (breaks[j] - x)
			x = breaks[j]
			j += 1
		out[i + 1] = out[i] + acc + speed_at(p, (x + b) * 0.5, dur) * (b - x)
	return out


static func table_step(table: PackedFloat64Array, dur: float) -> float:
	return dur / float(maxi(table.size() - 1, 1))


static func table_integral(p: Dictionary, table: PackedFloat64Array, dur: float, u: float) -> float:
	if dur <= 0.0 or table.size() < 2:
		return u * speed_at(p, 0.0, dur)
	if u <= 0.0:
		return u * speed_at(p, 0.0, dur)
	if u >= dur:
		return table[table.size() - 1] + (u - dur) * speed_at(p, dur, dur)
	var step: float = table_step(table, dur)
	var x: float = u / step
	var i: int = clampi(int(floor(x)), 0, table.size() - 2)
	return lerpf(table[i], table[i + 1], x - float(i))


static func integrate(p: Dictionary, dur: float, u: float) -> float:
	if not AnimProp.is_animated(p):
		return u * float(AnimProp.static_value(p))
	if u == 0.0:
		return 0.0
	var n: int = clampi(int(ceil(absf(u) * EXACT_RATE)), 16, EXACT_MAX)
	var h: float = u / float(n)
	var acc: float = 0.0
	for i: int in n:
		acc += speed_at(p, (float(i) + 0.5) * h, dur) * h
	return acc


static func runs_of(table: PackedFloat64Array) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array([0])
	var n: int = table.size()
	var dir: int = 0
	for i: int in range(1, n):
		var d: float = table[i] - table[i - 1]
		var sgn: int = 1 if d > 0.0 else (-1 if d < 0.0 else 0)
		if sgn == 0:
			continue
		if dir == 0:
			dir = sgn
		elif sgn != dir:
			out.append(i - 1)
			dir = sgn
	out.append(n - 1)
	return out


static func _solve_run(table: PackedFloat64Array, a: int, b: int, step: float, want: float) -> float:
	var va: float = table[a]
	var vb: float = table[b]
	var lo_v: float = minf(va, vb)
	var hi_v: float = maxf(va, vb)
	if want < lo_v - SOLVE_EPS or want > hi_v + SOLVE_EPS:
		return NAN
	var rising: bool = vb >= va
	var lo: int = a
	var hi: int = b
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		var vm: float = table[mid]
		if (vm < want) == rising and vm != want:
			lo = mid
		else:
			hi = mid
	var t0: float = table[lo]
	var t1: float = table[hi]
	if absf(t0 - want) <= SOLVE_EPS:
		return float(lo) * step
	if t1 == t0:
		return float(lo) * step
	var f: float = clampf((want - t0) / (t1 - t0), 0.0, 1.0)
	return (float(lo) + f) * step


static func solve(p: Dictionary, table: PackedFloat64Array, runs: PackedInt32Array, dur: float, start: float, key_t: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var want: float = key_t - start
	if dur <= 0.0 or table.size() < 2:
		var s: float = speed_at(p, 0.0, dur)
		if s != 0.0:
			out.append(want / s)
		return out
	var s0: float = speed_at(p, 0.0, dur)
	if s0 != 0.0:
		var before: float = want / s0
		if before < 0.0:
			out.append(before)
	var step: float = table_step(table, dur)
	for r: int in range(runs.size() - 1):
		var u: float = _solve_run(table, runs[r], runs[r + 1], step, want)
		if is_nan(u):
			continue
		if out.is_empty() or absf(out[out.size() - 1] - u) > SOLVE_EPS * 10.0:
			out.append(u)
	var s1: float = speed_at(p, dur, dur)
	if s1 != 0.0:
		var after: float = dur + (want - table[table.size() - 1]) / s1
		if after > dur and (out.is_empty() or absf(out[out.size() - 1] - after) > SOLVE_EPS * 10.0):
			out.append(after)
	return out


static func flat_solve(s: float, start: float, key_t: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if s == 0.0:
		if absf(key_t - start) <= SOLVE_EPS:
			out.append(0.0)
		return out
	out.append((key_t - start) / s)
	return out


static func reversed_start(s: float, dur: float) -> float:
	if s >= 0.0:
		return 0.0
	return -s * maxf(dur, 0.0)


static func bake(p: Dictionary, warp: Callable, dur: float, fps: float) -> Dictionary:
	if not AnimProp.is_animated(p):
		return p.duplicate(true)
	var rate: float = maxf(BAKE_RATE, fps)
	var span: float = maxf(dur, 0.0)
	var n: int = clampi(int(ceil(span * rate)), 1, BAKE_MAX)
	var times: PackedFloat64Array = PackedFloat64Array()
	var samples: Array = []
	for i: int in n + 1:
		var u: float = span * float(i) / float(n)
		times.append(u)
		samples.append(AnimProp.evaluate(p, float(warp.call(u)), dur, fps))
	var discrete: bool = AnimProp.holds_only(p) or AnimProp.is_discrete_value(AnimProp.static_value(p))
	var ks: Array = hold_keys(times, samples) if discrete else line_keys(times, samples)
	var layer: Dictionary = {"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": "once", "keys": ks}
	return {"a": true, "base": samples[0], "layers": [layer]}


static func hold_keys(times: PackedFloat64Array, samples: Array) -> Array:
	var out: Array = []
	var last: Variant = null
	for i: int in times.size():
		if i == 0 or samples[i] != last:
			out.append({"t": times[i], "v": samples[i], "i": "hold"})
			last = samples[i]
	return out


static func _parts(v: Variant) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if v is Array:
		for e: Variant in v:
			out.append(float(e) if (e is float or e is int) else 0.0)
	elif v is float or v is int:
		out.append(float(v))
	elif v is bool:
		out.append(1.0 if v else 0.0)
	else:
		out.append(0.0)
	return out


static func tolerance_of(samples: Array) -> float:
	var lo: float = INF
	var hi: float = -INF
	for s: Variant in samples:
		for f: float in _parts(s):
			lo = minf(lo, f)
			hi = maxf(hi, f)
	if lo == INF:
		return BAKE_TOLERANCE
	return maxf((hi - lo) * BAKE_TOLERANCE, 0.000001)


static func line_keys(times: PackedFloat64Array, samples: Array) -> Array:
	var n: int = times.size()
	var out: Array = [{"t": times[0], "v": samples[0], "i": "linear"}]
	if n < 2:
		return out
	var tol: float = tolerance_of(samples)
	var a: int = 0
	var va: PackedFloat64Array = _parts(samples[0])
	var comps: int = va.size()
	var lo: PackedFloat64Array = PackedFloat64Array()
	var hi: PackedFloat64Array = PackedFloat64Array()
	lo.resize(comps)
	hi.resize(comps)
	lo.fill(-INF)
	hi.fill(INF)
	var k: int = 1
	while k < n:
		var dt: float = times[k] - times[a]
		var vk: PackedFloat64Array = _parts(samples[k])
		var fits: bool = dt > 0.0
		if fits:
			for c: int in comps:
				var vc: float = vk[c] if c < vk.size() else 0.0
				var slope: float = (vc - va[c]) / dt
				if slope < lo[c] or slope > hi[c]:
					fits = false
					break
		if fits or k == a + 1:
			for c2: int in comps:
				var vc2: float = vk[c2] if c2 < vk.size() else 0.0
				lo[c2] = maxf(lo[c2], (vc2 - tol - va[c2]) / maxf(dt, 0.000000001))
				hi[c2] = minf(hi[c2], (vc2 + tol - va[c2]) / maxf(dt, 0.000000001))
			k += 1
			continue
		a = k - 1
		out.append({"t": times[a], "v": samples[a], "i": "linear"})
		va = _parts(samples[a])
		lo.fill(-INF)
		hi.fill(INF)
	if absf(float((out[out.size() - 1] as Dictionary)["t"]) - times[n - 1]) > 0.0:
		out.append({"t": times[n - 1], "v": samples[n - 1], "i": "linear"})
	return out


static func warp_audio_entry(c: RefCounted, entry: Dictionary, partner: RefCounted = null, fps: float = 0.0) -> Dictionary:
	var own: bool = bool(c.call("anim_warped")) or bool(c.call("has_inner_speeds"))
	var other: bool = partner != null and (bool(partner.call("anim_warped")) or bool(partner.call("has_inner_speeds")))
	if not own and not other:
		return entry
	var dur: float = float(c.get("duration"))
	if own:
		for key: String in ["volume", "pan"]:
			var vpath: String = "audio." + key
			if entry.get(key) is Dictionary and bool(c.call("path_warped", vpath)):
				entry[key] = bake(entry[key], own_warp_of(c, vpath), dur, fps)
	var own_uids: Dictionary = {}
	var clip_effects: Variant = c.call("audio_effects")
	for ae: Variant in clip_effects:
		var auid: String = String((ae as Dictionary).get("uid", ""))
		own_uids[auid] = "audio_effects." + auid + "."
	for ve: Variant in c.get("effects"):
		var vuid: String = String((ve as Dictionary).get("uid", ""))
		own_uids[vuid + "_band"] = "effects." + vuid + "."
	var partner_uids: Dictionary = {}
	if other:
		for pe: Variant in partner.get("effects"):
			var puid: String = String((pe as Dictionary).get("uid", ""))
			partner_uids[puid + "_band"] = "effects." + puid + "."
	var list: Variant = entry.get("effects", [])
	if not (list is Array):
		return entry
	for e: Variant in list:
		if not (e is Dictionary):
			continue
		var ed: Dictionary = e
		if ed.has(SPEEDS_FIELD):
			ed.erase(SPEEDS_FIELD)
		var uid: String = String(ed.get("uid", ""))
		var prefix: String = ""
		var who: RefCounted = null
		if own and own_uids.has(uid):
			prefix = String(own_uids[uid])
			who = c
		elif other and partner_uids.has(uid):
			prefix = String(partner_uids[uid])
			who = partner
		if who == null:
			continue
		var params: Variant = ed.get("params", {})
		if not (params is Dictionary):
			continue
		var baked: Dictionary = {}
		for pk: Variant in (params as Dictionary).keys():
			var pv: Variant = (params as Dictionary)[pk]
			var ppath: String = prefix + (String(BAND_KEYS.get(String(pk), String(pk))) if uid.ends_with("_band") else String(pk))
			if pv is Dictionary and bool(who.call("path_warped", ppath)):
				baked[pk] = bake(pv, own_warp_of(c, ppath) if who == c else partner_warp_of(c, partner, ppath), dur, fps)
			else:
				baked[pk] = pv
		ed["params"] = baked
	return entry


static func own_warp_of(c: RefCounted, path: String) -> Callable:
	return func(u: float) -> float: return float(c.call("param_time", path, u))


static func partner_warp_of(c: RefCounted, partner: RefCounted, path: String) -> Callable:
	return func(u: float) -> float: return float(partner.call("param_time", path, u + float(c.get("start")) - float(partner.get("start"))))


static func warped_steps(view: Dictionary, video: RefCounted, pick: Callable, path: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dur: float = float(video.get("duration"))
	var start: float = float(video.get("start"))
	var times: PackedFloat64Array = PackedFloat64Array([0.0])
	for k: Dictionary in AnimProp.keys(view):
		var played: PackedFloat64Array = video.call("played_times", float(k.get("t", 0.0))) if path.is_empty() else video.call("played_times_for", path, float(k.get("t", 0.0)))
		for u: float in played:
			if u > 0.0 and u < dur:
				times.append(u)
	times.sort()
	var last: int = -1
	for u: float in times:
		var probe: float = u if u == 0.0 else minf(u + STEP_PROBE, dur)
		var at: float = float(video.call("anim_time", probe)) if path.is_empty() else float(video.call("param_time", path, probe))
		var idx: int = int(pick.call(AnimProp.evaluate_float(view, at, dur)))
		if idx != last:
			out.append({"t": start + u, "view": idx})
			last = idx
	return out


static func played_list(c: RefCounted, path: String) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var p: Dictionary = c.call("get_param", path)
	for k: Dictionary in AnimProp.keys(p):
		var times: PackedFloat64Array = c.call("played_times_for", path, float(k.get("t", 0.0)))
		out.append_array(times)
	return out


static func plain_keys(p: Dictionary) -> bool:
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0:
		return false
	var layers: Array = p.get("layers", [])
	for i: int in layers.size():
		var l: Dictionary = layers[i]
		if i == li or not bool(l.get("on", true)):
			continue
		var kind: String = str(l.get("type", ""))
		if kind == "noise" or kind == "wave":
			return false
	var kl: Dictionary = layers[li]
	return bool(kl.get("on", true)) and float(kl.get("weight", 1.0)) == 1.0 and str(kl.get("blend", "over")) == "over"


static func segment_stays_inside(k: Dictionary) -> bool:
	var mode_i: String = str(k.get("i", "linear"))
	if mode_i == "linear" or mode_i == "hold":
		return true
	if mode_i == "ease_in" or mode_i == "ease_out" or mode_i == "ease_both":
		return SAFE_EASES.has(str(k.get("ease", "cubic")))
	return false


static func speed_path(target: String) -> String:
	return target + SPEED_TAIL


static func start_path(target: String) -> String:
	return target + START_TAIL


static func is_speed_path(path: String) -> bool:
	return path.ends_with(SPEED_TAIL)


static func is_start_path(path: String) -> bool:
	return path.ends_with(START_TAIL)


static func is_inner(path: String) -> bool:
	return path.ends_with(SPEED_TAIL) or path.ends_with(START_TAIL)


static func target_of(path: String) -> String:
	if path.ends_with(SPEED_TAIL):
		return path.left(path.length() - SPEED_TAIL.length())
	if path.ends_with(START_TAIL):
		return path.left(path.length() - START_TAIL.length())
	return path


static func is_fx_target(target: String) -> bool:
	return target.begins_with("effects.") or target.begins_with("audio_effects.") or target.begins_with("masks.")


static func is_group(target: String) -> bool:
	if GROUPS.has(target):
		return true
	return is_fx_target(target) and target.count(".") == 1


static func group_of(path: String) -> String:
	var parts: PackedStringArray = path.split(".")
	if parts.size() == 2:
		if parts[0] == "transform":
			return "motion" if MOTION_KEYS.has(parts[1]) else ""
		if parts[0] == "motion_blur":
			return "motion"
		if parts[0] == "audio":
			return "audio" if parts[1] == "volume" or parts[1] == "pan" else ""
		if parts[0] == "props":
			return "props"
		return ""
	if parts.size() == 3 and (parts[0] == "effects" or parts[0] == "audio_effects" or parts[0] == "masks"):
		return parts[0] + "." + parts[1]
	return ""


static func speed_able(path: String) -> bool:
	if exempt(path) or path == START_FIELD or is_inner(path):
		return false
	return path == "transform.opacity" or not group_of(path).is_empty()


static func target_ok(target: String) -> bool:
	return is_group(target) or speed_able(target)


static func chain_of(path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if exempt(path) or path == START_FIELD or path.ends_with(START_TAIL):
		return out
	if path.ends_with(SPEED_TAIL):
		var tgt: String = target_of(path)
		if is_group(tgt):
			return out
		var g: String = group_of(tgt)
		if not g.is_empty():
			out.append(g)
		return out
	var g2: String = group_of(path)
	if not g2.is_empty():
		out.append(g2)
	if speed_able(path):
		out.append(path)
	return out


static func fx_key(target: String) -> String:
	var parts: PackedStringArray = target.split(".")
	return WHOLE if parts.size() == 2 else parts[2]


static func cache_key(target: String) -> String:
	if not is_fx_target(target):
		return target
	var parts: PackedStringArray = target.split(".")
	return parts[1] + "|" + (WHOLE if parts.size() == 2 else parts[2])


static func entry_speed(en: Dictionary) -> Dictionary:
	var sp: Variant = en.get(SPEED_KEY, null)
	return sp if sp is Dictionary else AnimProp.make(1.0)


static func entry_start(en: Dictionary) -> float:
	var st: Variant = en.get(START_KEY, 0.0)
	return float(st) if (st is float or st is int) else 0.0


static func entry_default(en: Dictionary) -> bool:
	if en.is_empty():
		return true
	return entry_start(en) == 0.0 and is_default_speed(entry_speed(en))


static func make_entry(sp: Dictionary, st: float) -> Dictionary:
	var en: Dictionary = {SPEED_KEY: sp}
	if st != 0.0:
		en[START_KEY] = st
	return en


static func normalised(entries: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in entries.keys():
		var en: Variant = entries[k]
		if en is Dictionary and not entry_default(en):
			out[k] = (en as Dictionary).duplicate(true)
	return out


static func level(en: Dictionary, x: float, cache: Dictionary, dur: float) -> float:
	var sp: Dictionary = entry_speed(en)
	var st: float = entry_start(en)
	if not AnimProp.is_animated(sp):
		var k: float = float(AnimProp.static_value(sp))
		if k == 1.0 and st == 0.0:
			return x
		return st + x * k
	return st + inner_integral(cache, sp, dur, x)


static func inner_step(dur: float) -> float:
	return maxf(1.0 / TABLE_RATE, maxf(dur, 0.0) / float(TABLE_MAX))


static func inner_integral(cache: Dictionary, sp: Dictionary, dur: float, x: float) -> float:
	var src: Variant = cache.get("src", null)
	if float(cache.get("dur", -1.0)) != dur or not (src is Dictionary) or src != sp:
		cache.clear()
		cache["dur"] = dur
		cache["src"] = sp.duplicate(true)
		cache["h"] = inner_step(dur)
		cache["i0"] = 0
		cache["vals"] = PackedFloat64Array([0.0])
		_grow(cache, sp, dur, 0, int(ceil(maxf(dur, 0.0) / float(cache["h"]))))
	var h: float = cache["h"]
	var fx: float = x / h
	var i: int = int(floor(fx))
	var i0: int = cache["i0"]
	var vals: PackedFloat64Array = cache["vals"]
	if i < i0 or i + 1 > i0 + vals.size() - 1:
		_grow(cache, sp, dur, i, i + 1)
		i0 = cache["i0"]
		vals = cache["vals"]
	var last: int = i0 + vals.size() - 1
	if i < i0:
		return vals[0] + (x - float(i0) * h) * speed_at(sp, float(i0) * h, dur)
	if i + 1 > last:
		return vals[vals.size() - 1] + (x - float(last) * h) * speed_at(sp, float(last) * h, dur)
	return lerpf(vals[i - i0], vals[i + 1 - i0], fx - float(i))


static func _grow(cache: Dictionary, sp: Dictionary, dur: float, lo_i: int, hi_i: int) -> void:
	var h: float = cache["h"]
	var i0: int = cache["i0"]
	var vals: PackedFloat64Array = cache["vals"]
	var last: int = i0 + vals.size() - 1
	var room: int = INNER_SPAN - vals.size()
	if hi_i > last and room > 0:
		var to: int = mini(hi_i + maxi(vals.size() >> 2, 16), last + room)
		var acc: float = vals[vals.size() - 1]
		for j: int in range(last, to):
			acc += speed_at(sp, (float(j) + 0.5) * h, dur) * h
			vals.append(acc)
		room = INNER_SPAN - vals.size()
	if lo_i < i0 and room > 0:
		var from: int = maxi(lo_i - maxi(vals.size() >> 2, 16), i0 - room)
		var block: PackedFloat64Array = PackedFloat64Array()
		block.resize(i0 - from)
		var acc2: float = vals[0]
		for j2: int in range(i0 - 1, from - 1, -1):
			acc2 -= speed_at(sp, (float(j2) + 0.5) * h, dur) * h
			block[j2 - from] = acc2
		block.append_array(vals)
		vals = block
		i0 = from
	cache["i0"] = i0
	cache["vals"] = vals


static func solve_abs(table: PackedFloat64Array, runs: PackedInt32Array, dur: float, s0: float, s1: float, key_t: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if table.is_empty():
		return out
	if dur <= 0.0 or table.size() < 2:
		if s0 != 0.0:
			out.append((key_t - table[0]) / s0)
		return out
	if s0 != 0.0:
		var before: float = (key_t - table[0]) / s0
		if before < 0.0:
			out.append(before)
	var step: float = table_step(table, dur)
	for r: int in range(runs.size() - 1):
		var u: float = _solve_run(table, runs[r], runs[r + 1], step, key_t)
		if is_nan(u):
			continue
		if out.is_empty() or absf(out[out.size() - 1] - u) > SOLVE_EPS * 10.0:
			out.append(u)
	if s1 != 0.0:
		var after: float = dur + (key_t - table[table.size() - 1]) / s1
		if after > dur and (out.is_empty() or absf(out[out.size() - 1] - after) > SOLVE_EPS * 10.0):
			out.append(after)
	return out


static func shifted_entry(en: Dictionary, delta: float, dur: float) -> Dictionary:
	var sp: Dictionary = entry_speed(en)
	var st: float = entry_start(en) + integrate(sp, dur, -delta)
	return make_entry(AnimProp.shift_keys(sp, delta) if AnimProp.is_animated(sp) else sp.duplicate(true), st)


static func scaled_entry(en: Dictionary, factor: float) -> Dictionary:
	var sp: Dictionary = entry_speed(en)
	return make_entry(AnimProp.scale_times(sp, factor) if AnimProp.is_animated(sp) else sp.duplicate(true), entry_start(en) * factor)


static var _shared: Dictionary = {}
const SHARED_MAX := 256


static func shared_cache(sp: Dictionary, dur: float) -> Dictionary:
	var key: Array = [sp.hash(), dur]
	var hit: Variant = _shared.get(key, null)
	if hit is Dictionary:
		return hit
	if _shared.size() >= SHARED_MAX:
		_shared.clear()
	var fresh: Dictionary = {}
	_shared[key] = fresh
	return fresh


static func holder_time(holder: Dictionary, key: String, x: float, dur: float) -> float:
	var sp: Variant = holder.get(SPEEDS_FIELD, null)
	if not (sp is Dictionary):
		return x
	var a: float = x
	for k: String in [WHOLE, key]:
		var en: Variant = (sp as Dictionary).get(k, null)
		if en is Dictionary:
			var s: Dictionary = entry_speed(en)
			a = level(en, a, shared_cache(s, dur) if AnimProp.is_animated(s) else {}, dur)
	return a


static func reversed_entry_start(sp: float, span: float) -> float:
	if sp >= 0.0:
		return 0.0
	return -sp * maxf(span, 0.0)

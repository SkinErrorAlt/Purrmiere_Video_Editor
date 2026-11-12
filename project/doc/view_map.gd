extends RefCounted

const VERSION := 1
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const PAIR_VIEW_ID := "pair_view"
const COLOURS: Array[int] = [0, 2, 7, 5, 11, 1, 13, 4]
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const REGION_MAX := 8
const OFFSET_MAX := 600.0
const OFFSET_EPS := 0.0000005
const HEARD_KEY := "heard"
const HEARD_EPS := 0.0000001
const VIEW_KEY := "view"
const MODE_KEY := "view_mode"
const VIEW2_KEY := "view2"
const GROUP_KEY := "group"
const GROUPS_KEY := "groups"
const GROUP_MAX := 4
const ALWAYS_KEY := "always"
const ALWAYS_EVERY_KEY := "always_every"
const SOUND_VIEW_KEY := "sound_view"

static var _groups_cache: Dictionary = {}


static func groups_text(e: Dictionary) -> String:
	var params: Variant = e.get("params", null)
	if not (params is Dictionary):
		return ""
	var raw: Variant = (params as Dictionary).get(GROUPS_KEY, null)
	if not (raw is Dictionary):
		return ""
	var v: Variant = AnimProp.static_value(raw)
	if not (v is String) or (v as String).is_empty():
		return ""
	return (v as String).strip_edges()


static func every_region(count: int) -> Array[PackedInt32Array]:
	var all: PackedInt32Array = PackedInt32Array()
	for i: int in maxi(count, 1):
		all.append(i)
	var out: Array[PackedInt32Array] = [all]
	return out


static func members_of(text: String, count: int) -> Array[PackedInt32Array]:
	var t: String = text.strip_edges()
	if t.is_empty():
		return every_region(count)
	var key: String = str(count) + "|" + t
	if _groups_cache.has(key):
		return _groups_cache[key]
	var out: Array[PackedInt32Array] = []
	var reader: JSON = JSON.new()
	var parsed: Variant = reader.data if reader.parse(t) == OK else null
	var seen: Dictionary = {}
	if parsed is Array:
		for g: Variant in parsed:
			if not (g is Array) or out.size() >= GROUP_MAX:
				continue
			var list: PackedInt32Array = PackedInt32Array()
			for r: Variant in g:
				if not (r is float or r is int):
					continue
				var ri: int = int(r)
				if ri < 0 or ri >= mini(maxi(count, 1), REGION_MAX) or seen.has(ri):
					continue
				seen[ri] = true
				list.append(ri)
			if not list.is_empty():
				out.append(list)
	if out.is_empty() or (out.size() == 1 and out[0].size() >= mini(maxi(count, 1), REGION_MAX)):
		out = every_region(count)
	if _groups_cache.size() > 256:
		_groups_cache.clear()
	_groups_cache[key] = out
	return out


static func members(e: Dictionary) -> Array[PackedInt32Array]:
	return members_of(groups_text(e), crop_count(e))


static func grouped(e: Dictionary) -> bool:
	var text: String = groups_text(e)
	if text.is_empty():
		return false
	return limited(members_of(text, crop_count(e)), crop_count(e))


static func limited(m: Array[PackedInt32Array], count: int) -> bool:
	if m.size() >= 2:
		return true
	return m.size() == 1 and m[0].size() < mini(maxi(count, 1), REGION_MAX)


static func left_out(e: Dictionary) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var count: int = mini(maxi(crop_count(e), 1), REGION_MAX)
	var m: Array[PackedInt32Array] = members(e)
	for i: int in count:
		var found: bool = false
		for g: PackedInt32Array in m:
			if g.has(i):
				found = true
				break
		if not found:
			out.append(i)
	return out


static func view_key_for(group: int) -> String:
	if group <= 0:
		return VIEW_KEY
	if group == 1:
		return VIEW2_KEY
	return VIEW_KEY + str(group + 1)


static func resolve_in(m: Array[PackedInt32Array], group_value: float, view_values: Array[float], mode: int) -> int:
	if m.size() < 2:
		var only: PackedInt32Array = m[0] if not m.is_empty() else PackedInt32Array([0])
		return only[index_at(view_values[0] if not view_values.is_empty() else 0.0, mode, only.size())]
	var g: int = index_at(group_value, 0, m.size())
	var list: PackedInt32Array = m[g]
	var v: float = view_values[g] if g < view_values.size() else 0.0
	return list[index_at(v, mode, list.size())]


static func resolve_values(values: Dictionary, count: int) -> int:
	var m: Array[PackedInt32Array] = members_of(String(values.get(GROUPS_KEY, "")) if values.get(GROUPS_KEY, "") is String else "", count)
	var mode: int = int(round(_num(values.get(MODE_KEY, 0.0))))
	if not limited(m, count):
		return index_at(_num(values.get(VIEW_KEY, 0.0)), mode, count)
	var vals: Array[float] = []
	for g: int in m.size():
		vals.append(_num(values.get(view_key_for(g), 0.0)))
	return resolve_in(m, _num(values.get(GROUP_KEY, 0.0)), vals, mode)


static func place_of(e: Dictionary, region: int) -> Vector2i:
	var m: Array[PackedInt32Array] = members(e)
	for g: int in m.size():
		var at: int = m[g].find(region)
		if at >= 0:
			return Vector2i(g, at)
	return Vector2i(-1, -1)


static func remap_groups(text: String, old_count: int, remap: Dictionary, new_count: int) -> String:
	var m: Array[PackedInt32Array] = members_of(text, old_count)
	if not limited(m, old_count):
		return text
	var out: Array = []
	var seen: Dictionary = {}
	for g: PackedInt32Array in m:
		var list: Array = []
		for r: int in g:
			var nr: int = int(remap.get(r, r)) if not remap.is_empty() else r
			if nr >= 0 and nr < new_count and not seen.has(nr):
				seen[nr] = true
				list.append(nr)
		out.append(list)
	if remap.is_empty():
		for i: int in range(old_count, new_count):
			if not seen.has(i):
				(out[out.size() - 1] as Array).append(i)
	return groups_json(out)


static func split_in_two(count: int) -> String:
	var n: int = maxi(count, 2)
	var half: int = int(ceil(float(n) / 2.0))
	var a: Array = []
	var b: Array = []
	for i: int in n:
		if i < half:
			a.append(i)
		else:
			b.append(i)
	return groups_json([a, b])


static func moved_to(text: String, count: int, region: int, group: int) -> String:
	var m: Array[PackedInt32Array] = members_of(text, count)
	var out: Array = []
	for g: PackedInt32Array in m:
		var list: Array = []
		for r: int in g:
			if r != region:
				list.append(r)
		out.append(list)
	if group >= 0:
		while out.size() <= mini(group, GROUP_MAX - 1):
			out.append([])
		var target: Array = out[mini(group, GROUP_MAX - 1)]
		target.append(region)
		target.sort()
	var kept: Array = []
	for l: Variant in out:
		if not (l as Array).is_empty():
			kept.append(l)
	if kept.is_empty() or (kept.size() == 1 and (kept[0] as Array).size() >= mini(maxi(count, 1), REGION_MAX)):
		return ""
	return groups_json(kept)


static func split_in(count: int, parts: int) -> String:
	var n: int = mini(maxi(count, 1), REGION_MAX)
	var k: int = clampi(parts, 2, mini(GROUP_MAX, n))
	if n < 2:
		return ""
	var out: Array = []
	for g: int in k:
		out.append([])
	for i: int in n:
		(out[mini(i * k / n, k - 1)] as Array).append(i)
	return groups_json(out)


static func groups_json(m: Array) -> String:
	var out: Array = []
	for g: Variant in m:
		var list: Array = []
		for r: Variant in g:
			list.append(int(r))
		out.append(list)
	return JSON.stringify(out)


static func of(e: Dictionary) -> Dictionary:
	var params: Dictionary = e.get("params", {})
	var raw: Variant = params.get("view_audio", null)
	if not (raw is Dictionary):
		return {}
	var text: String = String(AnimProp.static_value(raw)).strip_edges()
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	var map: Dictionary = parsed
	if not (map.get("views", null) is Array):
		return {}
	return map


static var _count_cache: Dictionary = {}


static func crop_count(e: Dictionary) -> int:
	var params: Dictionary = e.get("params", {})
	var raw: Variant = params.get("crops", null)
	if not (raw is Dictionary):
		return 1
	var text: String = String(AnimProp.static_value(raw))
	if _count_cache.has(text):
		return int(_count_cache[text])
	var parsed: Variant = JSON.parse_string(text.strip_edges())
	var n: int = maxi((parsed as Array).size(), 1) if parsed is Array else 1
	if _count_cache.size() > 256:
		_count_cache.clear()
	_count_cache[text] = n
	return n


static func index_at(value: float, mode: int, count: int) -> int:
	var n: int = maxi(count, 1)
	if mode == 1:
		return clampi(int(floor(clampf(value, 0.0, 0.99999) * float(n))), 0, n - 1)
	return clampi(int(floor(value + 0.5)), 0, n - 1)


static func steps(e: Dictionary, video: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if video == null:
		return out
	for ch: Dictionary in changes(e, video):
		out.append({"t": video.start + float(ch["u"]), "view": int(ch["view"])})
	return out


const CHANGE_SAMPLES_PER_SECOND := 8.0
const CHANGE_SAMPLES_MAX := 64
const CHANGE_SCAN_PER_SECOND := 30.0
const CHANGE_SCAN_MAX := 4096
const CHANGE_BISECT_MAX := 64
const CHANGE_PRECISION := 0.0000001
const CHANGE_MERGE := 0.000001
const CHANGE_TAIL := 0.000001
const CHANGE_COVER_SAMPLES := 16
const CUTS_KEY := "view_cuts"

static var change_stats: Dictionary = {"calls": 0, "evals": 0}


static func prop_of(e: Dictionary, key: String) -> Dictionary:
	var params: Dictionary = e.get("params", {})
	var raw: Variant = params.get(key, null)
	return raw if raw is Dictionary else AnimProp.make(0.0)


static func param_path(e: Dictionary, key: String) -> String:
	return "effects." + String(e.get("uid", "")) + "." + key


static func cuts_on(e: Dictionary) -> bool:
	var params: Dictionary = e.get("params", {})
	var raw: Variant = params.get(CUTS_KEY, null)
	if not (raw is Dictionary):
		return false
	return bool(AnimProp.static_value(raw))


static func cut_entry(c: Clip) -> Dictionary:
	if c == null or c.effects.is_empty():
		return {}
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) == PAIR_VIEW_ID and bool(e.get("enabled", true)) and cuts_on(e):
			return e
	return {}


static func changes(e: Dictionary, video: Clip) -> Array[Dictionary]:
	if video == null:
		var none: Array[Dictionary] = []
		return none
	var text: String = groups_text(e)
	if text.is_empty():
		return _single(e, video, VIEW_KEY, MODE_KEY, crop_count(e))
	var m: Array[PackedInt32Array] = members_of(text, crop_count(e))
	if not limited(m, crop_count(e)):
		return _single(e, video, VIEW_KEY, MODE_KEY, crop_count(e))
	return _grouped_changes(e, video, m)


static func prop_changes(e: Dictionary, video: Clip, vkey: String, mkey: String, count: int) -> Array[Dictionary]:
	if video == null:
		var none: Array[Dictionary] = []
		return none
	return _single(e, video, vkey, mkey, count)


static func _grouped_changes(e: Dictionary, video: Clip, m: Array[PackedInt32Array]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var gch: Array[Dictionary] = _single(e, video, GROUP_KEY, "", m.size())
	var per: Dictionary = {}
	var times: Array[float] = []
	for ch: Dictionary in gch:
		times.append(float(ch["u"]))
		var g: int = int(ch["view"])
		if not per.has(g):
			per[g] = _single(e, video, view_key_for(g), MODE_KEY, m[g].size())
			for ch2: Dictionary in per[g]:
				times.append(float(ch2["u"]))
	times.sort()
	var last: float = -INF
	for u: float in times:
		if u - last <= CHANGE_MERGE and not out.is_empty():
			continue
		last = u
		var g2: int = clampi(heard_view_at(gch, u), 0, m.size() - 1)
		var list: PackedInt32Array = m[g2]
		var region: int = list[clampi(heard_view_at(per[g2], u), 0, list.size() - 1)]
		if out.is_empty():
			out.append({"u": 0.0, "view": region})
		else:
			_record(out, u, region)
	return out


static func _single(e: Dictionary, video: Clip, vkey: String, mkey: String, count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	change_stats["calls"] = int(change_stats["calls"]) + 1
	var run: Array[Dictionary] = _held_run(e, video, vkey, mkey, count)
	if not run.is_empty():
		return run
	var ctx: Dictionary = _probe(e, video, vkey, mkey, count)
	var memo_key: String = _memo_key(ctx, e, video)
	var hit: Variant = _memo.get(memo_key, null)
	if hit is Array:
		for ch: Variant in (hit as Array):
			out.append((ch as Dictionary).duplicate())
		return out
	_slow_changes(ctx, out)
	change_stats["evals"] = int(change_stats["evals"]) + int(ctx["evals"])
	if _memo.size() >= MEMO_MAX:
		_memo.clear()
	var keep: Array = []
	for ch2: Dictionary in out:
		keep.append(ch2.duplicate())
	_memo[memo_key] = keep
	return out


static func _memo_key(ctx: Dictionary, e: Dictionary, video: Clip) -> String:
	var parts: Array = [ctx["view"], ctx["mode"], ctx["count"], ctx["dur"], ctx["view_warped"], ctx["mode_warped"]]
	if String(ctx["view_key"]) != VIEW_KEY or String(ctx["mode_key"]) != MODE_KEY:
		parts.append_array([ctx["view_key"], ctx["mode_key"]])
	if bool(ctx["view_warped"]) or bool(ctx["mode_warped"]):
		var outer: Dictionary = {}
		for k: Variant in e.keys():
			if String(k) != "params":
				outer[k] = e[k]
		parts.append_array([outer, video.anim_start, video.anim_speed, video.get("speeds")])
	return JSON.stringify(parts, "", false, true)


const MEMO_MAX := 256
static var _memo: Dictionary = {}


static func _slow_changes(ctx: Dictionary, out: Array[Dictionary]) -> void:
	out.append({"u": 0.0, "view": _index_on(ctx, 0.0)})
	var dur: float = float(ctx["dur"])
	if not bool(ctx["keyed"]) or dur <= 0.0:
		return
	var bounds: PackedFloat64Array = _bounds(ctx)
	if bounds.is_empty():
		_scan(ctx, out, 0.0, dur, clampi(int(ceil(dur * CHANGE_SCAN_PER_SECOND)), 2, CHANGE_SCAN_MAX))
	else:
		for i: int in bounds.size() - 1:
			var a: float = bounds[i]
			var b: float = bounds[i + 1]
			if b - a <= CHANGE_MERGE:
				continue
			var mid: float = (a + b) * 0.5
			var held: int = _held_index(ctx, mid)
			if held >= 0:
				_record(out, a, held)
			elif _smooth(ctx, a, b):
				_smooth_changes(ctx, out, a, b)
			else:
				_scan(ctx, out, a, b, clampi(int(ceil((b - a) * CHANGE_SAMPLES_PER_SECOND)), 2, CHANGE_SAMPLES_MAX))


static func _value_on(ctx: Dictionary, u: float) -> float:
	ctx["evals"] = int(ctx["evals"]) + 1
	var view: Dictionary = ctx["view"]
	if not AnimProp.is_animated(view):
		return float(AnimProp.static_value(view))
	return AnimProp.evaluate_float(view, _time(ctx, "view", u), float(ctx["dur"]))


static func _mode_on(ctx: Dictionary, u: float) -> int:
	if not bool(ctx["mode_keyed"]):
		return int(ctx["mode_fixed"])
	return int(AnimProp.evaluate_float(ctx["mode"], _time(ctx, "mode", u), float(ctx["dur"])))


static func _threshold(mode: int, count: int, cur: int, rising: bool) -> float:
	var n: float = float(maxi(count, 1))
	if mode == 1:
		return float(cur + 1) / n if rising else float(cur) / n
	return float(cur) + 0.5 if rising else float(cur) - 0.5


static func _smooth_changes(ctx: Dictionary, out: Array[Dictionary], a: float, b: float) -> void:
	var cur: int = int(out[out.size() - 1]["view"])
	if a > 0.0:
		var at_a: int = _index_on(ctx, a)
		if at_a != cur:
			_record(out, a, at_a)
			cur = at_a
	var hi: float = b - minf(CHANGE_TAIL, (b - a) * 0.001)
	var goal: int = _index_on(ctx, hi)
	var mode: int = _mode_on(ctx, (a + b) * 0.5)
	var count: int = int(ctx["count"])
	var lo: float = a
	var guard: int = 0
	while cur != goal and guard < 64:
		guard += 1
		var rising: bool = goal > cur
		var thr: float = _threshold(mode, count, cur, rising)
		var x0: float = lo
		var x1: float = hi
		var f0: float = _value_on(ctx, x0) - thr
		var f1: float = _value_on(ctx, x1) - thr
		if (f0 < 0.0) == (f1 < 0.0):
			_bisect(ctx, out, lo, hi, cur, goal)
			return
		var side: int = 0
		var it: int = 0
		while x1 - x0 > CHANGE_PRECISION * 16.0 and it < CHANGE_BISECT_MAX:
			it += 1
			var x: float = x1 - f1 * (x1 - x0) / (f1 - f0)
			if not (x > x0 and x < x1):
				x = (x0 + x1) * 0.5
			var fx: float = _value_on(ctx, x) - thr
			if (fx < 0.0) == (f0 < 0.0):
				x0 = x
				f0 = fx
				if side == -1:
					f1 *= 0.5
				side = -1
			else:
				x1 = x
				f1 = fx
				if side == 1:
					f0 *= 0.5
				side = 1
		var before: int = out.size()
		_bisect(ctx, out, x0, x1, cur, _index_on(ctx, x1))
		if out.size() == before and int(out[out.size() - 1]["view"]) == cur:
			_bisect(ctx, out, lo, hi, cur, goal)
			return
		cur = int(out[out.size() - 1]["view"])
		lo = float(out[out.size() - 1]["u"])


static func _held_run(e: Dictionary, video: Clip, vkey: String, mkey: String, count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mode_prop: Dictionary = prop_of(e, mkey)
	if AnimProp.is_animated(mode_prop):
		return out
	var mode: int = int(AnimProp.static_value(mode_prop))
	var view: Dictionary = prop_of(e, vkey)
	if not AnimProp.is_animated(view):
		out.append({"u": 0.0, "view": index_at(float(AnimProp.static_value(view)), mode, count)})
		return out
	if not AnimTime.plain_keys(view):
		return out
	var li: int = AnimProp.keys_layer_index(view)
	var layer: Dictionary = view["layers"][li]
	if str(layer.get("loop", "once")) != "once":
		return out
	var ks: Array = layer.get("keys", [])
	var n: int = ks.size()
	if n == 0:
		return out
	var last_t: float = -INF
	for i: int in n:
		var k: Dictionary = ks[i]
		var kt: float = float(k.get("t", 0.0))
		if kt - last_t < AnimProp.KEY_TOLERANCE:
			return out
		if i < n - 1 and str(k.get("i", "linear")) != "hold":
			return out
		last_t = kt
	if video.anim_warped() or _warped(video, param_path(e, vkey)):
		return out
	var base: float = _num(view.get("base", 0.0))
	var dur: float = maxf(video.duration, 0.0)
	var first: Variant = (ks[0] as Dictionary).get("v", 0.0)
	for k2: Variant in ks:
		if float((k2 as Dictionary).get("t", 0.0)) > 0.0:
			break
		first = (k2 as Dictionary).get("v", 0.0)
	out.append({"u": 0.0, "view": index_at(base + (_num(first) - base) * 1.0, mode, count)})
	for k3: Variant in ks:
		var t3: float = float((k3 as Dictionary).get("t", 0.0))
		if t3 > 0.0 and t3 < dur:
			_record(out, t3, index_at(base + (_num((k3 as Dictionary).get("v", 0.0)) - base) * 1.0, mode, count))
	return out


static func _probe(e: Dictionary, video: Clip, vkey: String, mkey: String, count: int) -> Dictionary:
	var view: Dictionary = prop_of(e, vkey)
	var mode: Dictionary = prop_of(e, mkey)
	var mode_keyed: bool = AnimProp.is_animated(mode)
	var view_path: String = param_path(e, vkey)
	var mode_path: String = param_path(e, mkey)
	return {
		"video": video, "entry": e, "view": view, "mode": mode, "view_path": view_path, "mode_path": mode_path,
		"view_key": vkey, "mode_key": mkey, "fx": video.has_method("fx_time"),
		"view_warped": _warped(video, view_path), "mode_warped": mode_keyed and _warped(video, mode_path),
		"count": count, "dur": maxf(video.duration, 0.0), "mode_keyed": mode_keyed,
		"mode_fixed": 0 if mode_keyed else int(AnimProp.static_value(mode)),
		"keyed": AnimProp.is_animated(view) or mode_keyed, "evals": 0,
	}


static func _warped(video: Clip, path: String) -> bool:
	if video.has_method("path_warped"):
		return bool(video.call("path_warped", path))
	return video.anim_warped()


static func _time(ctx: Dictionary, which: String, u: float) -> float:
	if not bool(ctx[which + "_warped"]):
		return u
	if bool(ctx["fx"]):
		return float((ctx["video"] as Clip).call("fx_time", ctx["entry"], String(ctx[which + "_key"]), u))
	return (ctx["video"] as Clip).param_time(String(ctx[which + "_path"]), u)


static func _played(ctx: Dictionary, which: String, kt: float) -> PackedFloat64Array:
	if not bool(ctx[which + "_warped"]):
		return PackedFloat64Array([kt])
	return (ctx["video"] as Clip).played_times_for(String(ctx[which + "_path"]), kt)


static func _index_on(ctx: Dictionary, u: float) -> int:
	ctx["evals"] = int(ctx["evals"]) + 1
	var dur: float = float(ctx["dur"])
	var mode: int = int(ctx["mode_fixed"])
	if bool(ctx["mode_keyed"]):
		mode = int(AnimProp.evaluate_float(ctx["mode"], _time(ctx, "mode", u), dur))
	var view: Dictionary = ctx["view"]
	var value: float = float(AnimProp.static_value(view))
	if AnimProp.is_animated(view):
		value = AnimProp.evaluate_float(view, _time(ctx, "view", u), dur)
	return index_at(value, mode, int(ctx["count"]))


static func _record(out: Array[Dictionary], u: float, view: int) -> void:
	var last: Dictionary = out[out.size() - 1]
	if int(last["view"]) == view:
		return
	if u - float(last["u"]) <= CHANGE_MERGE:
		last["view"] = view
		if out.size() >= 2 and int(out[out.size() - 2]["view"]) == view:
			out.remove_at(out.size() - 1)
		return
	out.append({"u": u, "view": view})


static func _scan(ctx: Dictionary, out: Array[Dictionary], a: float, b: float, n: int) -> void:
	var lo: float = a
	var cur: int = int(out[out.size() - 1]["view"])
	if a > 0.0:
		var at_a: int = _index_on(ctx, a)
		if at_a != cur:
			_record(out, a, at_a)
			cur = at_a
	for j: int in range(1, n + 1):
		var x: float = a + (b - a) * float(j) / float(n) if j < n else b - minf(CHANGE_TAIL, (b - a) * 0.001)
		var v: int = _index_on(ctx, x)
		if v != cur:
			_bisect(ctx, out, lo, x, cur, v)
			cur = v
		lo = x


static func _bisect(ctx: Dictionary, out: Array[Dictionary], lo: float, hi: float, from_view: int, to_view: int) -> void:
	var cur: int = from_view
	var a: float = lo
	var guard: int = 0
	while cur != to_view and guard < 16:
		var l: float = a
		var r: float = hi
		var it: int = 0
		while r - l > CHANGE_PRECISION and it < CHANGE_BISECT_MAX:
			var m: float = (l + r) * 0.5
			if _index_on(ctx, m) == cur:
				l = m
			else:
				r = m
			it += 1
		var now: int = _index_on(ctx, r)
		if now == cur:
			break
		_record(out, r, now)
		cur = now
		a = r
		guard += 1
	if cur != to_view:
		_record(out, hi, to_view)


static func _bounds(ctx: Dictionary) -> PackedFloat64Array:
	var video: Clip = ctx["video"]
	var dur: float = float(ctx["dur"])
	var cuts: PackedFloat64Array = PackedFloat64Array()
	for which: String in ["view", "mode"]:
		var p: Dictionary = ctx[which]
		if not AnimProp.is_animated(p):
			continue
		if not AnimTime.plain_keys(p) and not _keys_off(p):
			return PackedFloat64Array()
		var times: PackedFloat64Array = _key_times(ctx, which)
		if times.size() > CHANGE_SCAN_MAX:
			return PackedFloat64Array()
		for kt: float in times:
			for u: float in _played(ctx, which, kt):
				if u > 0.0 and u < dur:
					cuts.append(u)
	if cuts.size() > CHANGE_SCAN_MAX:
		return PackedFloat64Array()
	cuts.append(0.0)
	cuts.append(dur)
	cuts.sort()
	var out: PackedFloat64Array = PackedFloat64Array([cuts[0]])
	for i: int in range(1, cuts.size()):
		if cuts[i] - out[out.size() - 1] > CHANGE_MERGE:
			out.append(cuts[i])
	if out[out.size() - 1] < dur:
		out.append(dur)
	return out


static func _keys_off(p: Dictionary) -> bool:
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0:
		return false
	for l: Variant in p.get("layers", []):
		var ld: Dictionary = l
		var kind: String = str(ld.get("type", ""))
		if bool(ld.get("on", true)) and (kind == "noise" or kind == "wave"):
			return false
	return not bool((p["layers"][li] as Dictionary).get("on", true))


static func _key_list(p: Dictionary) -> Array:
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0:
		return []
	var layer: Dictionary = p["layers"][li]
	if not bool(layer.get("on", true)):
		return []
	return layer.get("keys", [])


static func _key_times(ctx: Dictionary, which: String) -> PackedFloat64Array:
	var p: Dictionary = ctx[which]
	var dur: float = float(ctx["dur"])
	var out: PackedFloat64Array = PackedFloat64Array()
	var ks: Array = _key_list(p)
	for k: Variant in ks:
		out.append(float((k as Dictionary).get("t", 0.0)))
	out.sort()
	var li: int = AnimProp.keys_layer_index(p)
	var loop: String = str((p["layers"][li] as Dictionary).get("loop", "once")) if li >= 0 else "once"
	if out.size() < 2 or (loop != "loop" and loop != "pingpong"):
		return out
	var t0: float = out[0]
	var t1: float = out[out.size() - 1]
	var span: float = t1 - t0
	if span <= 0.0:
		return out
	var base: PackedFloat64Array = out.duplicate()
	var period: float = span
	if loop == "pingpong":
		period = span * 2.0
		for i: int in range(out.size() - 2, 0, -1):
			base.append(t1 + (t1 - out[i]))
	var lo: float = INF
	var hi: float = -INF
	for s: int in CHANGE_COVER_SAMPLES + 1:
		var kt: float = _time(ctx, which, dur * float(s) / float(CHANGE_COVER_SAMPLES))
		lo = minf(lo, kt)
		hi = maxf(hi, kt)
	var n0: int = int(floor((lo - t0) / period)) - 1
	var n1: int = int(ceil((hi - t0) / period)) + 1
	if (n1 - n0 + 1) * base.size() > CHANGE_SCAN_MAX:
		var huge: PackedFloat64Array = PackedFloat64Array()
		huge.resize(CHANGE_SCAN_MAX + 1)
		return huge
	var reps: PackedFloat64Array = PackedFloat64Array()
	for n: int in range(n0, n1 + 1):
		for bt: float in base:
			reps.append(bt + float(n) * period)
	reps.sort()
	return reps


static func _held_index(ctx: Dictionary, u: float) -> int:
	var mode: int = int(ctx["mode_fixed"])
	if bool(ctx["mode_keyed"]):
		var ms: Dictionary = _segment(ctx["mode"], _time(ctx, "mode", u))
		if int(ms["state"]) != SEG_HELD:
			return -1
		mode = int(float(ms["v"]))
	var view: Dictionary = ctx["view"]
	var value: float = float(AnimProp.static_value(view))
	if AnimProp.is_animated(view):
		var vs: Dictionary = _segment(view, _time(ctx, "view", u))
		if int(vs["state"]) != SEG_HELD:
			return -1
		value = float(vs["v"])
	return index_at(value, mode, int(ctx["count"]))


static func _smooth(ctx: Dictionary, a: float, b: float) -> bool:
	for which: String in ["view", "mode"]:
		var p: Dictionary = ctx[which]
		if not AnimProp.is_animated(p):
			continue
		var seg: Dictionary = _segment(p, _time(ctx, which, (a + b) * 0.5))
		if int(seg["state"]) == SEG_UNKNOWN or (which == "mode" and int(seg["state"]) != SEG_HELD):
			return false
		if int(seg["state"]) == SEG_MOVING and not AnimTime.segment_stays_inside(seg["key"]):
			return false
		if not bool(ctx[which + "_warped"]):
			continue
		var rising: int = 0
		var last: float = _time(ctx, which, a)
		for s: int in range(1, CHANGE_COVER_SAMPLES + 1):
			var now: float = _time(ctx, which, a + (b - a) * float(s) / float(CHANGE_COVER_SAMPLES))
			var dir: int = 1 if now > last else (-1 if now < last else 0)
			if dir != 0:
				if rising != 0 and dir != rising:
					return false
				rising = dir
			last = now
	return true


const SEG_HELD := 0
const SEG_MOVING := 1
const SEG_UNKNOWN := 2


static func _num(v: Variant) -> float:
	if v is float or v is int:
		return float(v)
	if v is bool:
		return 1.0 if v else 0.0
	if v is Array and not (v as Array).is_empty():
		return float(v[0])
	return 0.0


static func _segment(p: Dictionary, kt: float) -> Dictionary:
	var ks: Array = _key_list(p)
	var n: int = ks.size()
	var base: float = _num(p.get("base", 0.0))
	if n == 0:
		return {"state": SEG_HELD, "v": base}
	if n == 1:
		return {"state": SEG_HELD, "v": base + (_num((ks[0] as Dictionary).get("v", 0.0)) - base) * 1.0}
	var t0: float = float((ks[0] as Dictionary).get("t", 0.0))
	var t1: float = float((ks[n - 1] as Dictionary).get("t", 0.0))
	var li: int = AnimProp.keys_layer_index(p)
	var loop: String = str((p["layers"][li] as Dictionary).get("loop", "once"))
	var span: float = t1 - t0
	var tt: float = kt
	if loop == "loop" and span > 0.0:
		var w: float = kt - t0
		tt = t0 + w - floor(w / span) * span
	elif loop == "pingpong" and span > 0.0:
		var w2: float = kt - t0
		w2 = w2 - floor(w2 / (span * 2.0)) * span * 2.0
		tt = t0 + (span * 2.0 - w2 if w2 > span else w2)
	elif loop == "continue" and (kt < t0 or kt > t1):
		return {"state": SEG_UNKNOWN}
	if tt < t0:
		return {"state": SEG_HELD, "v": base + (_num((ks[0] as Dictionary).get("v", 0.0)) - base) * 1.0}
	if tt >= t1:
		return {"state": SEG_HELD, "v": base + (_num((ks[n - 1] as Dictionary).get("v", 0.0)) - base) * 1.0}
	var lo: int = 0
	var hi: int = n - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if float((ks[mid] as Dictionary).get("t", 0.0)) <= tt:
			lo = mid
		else:
			hi = mid
	var a: Dictionary = ks[lo]
	var b: Dictionary = ks[lo + 1]
	if float(a.get("t", 0.0)) > tt or float(b.get("t", 0.0)) <= tt:
		return {"state": SEG_UNKNOWN}
	var interp: String = str(a.get("i", "linear"))
	var va: float = _num(a.get("v", 0.0))
	if interp == "hold" or (va == _num(b.get("v", 0.0)) and (interp == "linear" or interp.begins_with("ease"))):
		return {"state": SEG_HELD, "v": base + (va - base) * 1.0}
	return {"state": SEG_MOVING, "key": a}


static func hears(map: Dictionary, index: int, track_id: String, clip_id: String) -> bool:
	var views: Array = map.get("views", [])
	if index < 0 or index >= views.size():
		return false
	var v: Dictionary = views[index]
	for cid: Variant in v.get("clips", []):
		if String(cid) == clip_id:
			return true
	for tid: Variant in v.get("tracks", []):
		if String(tid) == track_id:
			return true
	return false


static func governs(map: Dictionary, track_id: String, clip_id: String) -> bool:
	if ViewStreams.always(map, track_id):
		return false
	for v: Variant in map.get("views", []):
		var vd: Dictionary = v
		for cid: Variant in vd.get("clips", []):
			if String(cid) == clip_id:
				return true
		for tid: Variant in vd.get("tracks", []):
			if String(tid) == track_id:
				return true
	return ViewStreams.picked_anywhere(map, track_id)


static func named_clip(map: Dictionary, clip_id: String) -> bool:
	for v: Variant in map.get("views", []):
		for cid: Variant in (v as Dictionary).get("clips", []):
			if String(cid) == clip_id:
				return true
	return false


static func in_family(video: Clip, c: Clip) -> bool:
	if video == null or c == null:
		return false
	if not video.link_id.is_empty() and video.link_id == c.link_id:
		return true
	if not video.group_id.is_empty() and video.group_id == c.group_id:
		return true
	return false


static func colour_for(map: Dictionary, index: int) -> int:
	var views: Array = map.get("views", [])
	if index >= 0 and index < views.size():
		var set_to: int = int((views[index] as Dictionary).get("colour", -1))
		if set_to >= 0:
			return set_to
	if index < 0:
		return -1
	return COLOURS[index % COLOURS.size()]


static func picked_colour(map: Dictionary, index: int) -> int:
	var views: Array = map.get("views", [])
	if index < 0 or index >= views.size():
		return -1
	return int((views[index] as Dictionary).get("colour", -1))


static func with_colour(map: Dictionary, index: int, colour: int, count: int = 0) -> Dictionary:
	if index < 0 or index >= REGION_MAX:
		return {}
	var out: Dictionary = map.duplicate(true) if not map.is_empty() else {"views": []}
	var views: Array = out.get("views", [])
	if not (views is Array):
		views = []
	var want: int = maxi(index + 1, count)
	while views.size() < want:
		views.append({"tracks": [], "clips": [], "colour": -1})
	var one: Dictionary = views[index]
	var set_to: int = -1 if colour < 0 else clampi(colour, 0, 15)
	if int(one.get("colour", -1)) == set_to:
		return {}
	one["colour"] = set_to
	views[index] = one
	out["views"] = views
	return out


static func clip_in_view(map: Dictionary, index: int, clip_id: String) -> bool:
	var views: Array = map.get("views", [])
	if index < 0 or index >= views.size():
		return false
	for cid: Variant in (views[index] as Dictionary).get("clips", []):
		if String(cid) == clip_id:
			return true
	return false


static func with_clip(map: Dictionary, index: int, clip_id: String, on: bool, count: int = 0) -> Dictionary:
	if index < 0 or index >= REGION_MAX or clip_id.is_empty():
		return {}
	var out: Dictionary = map.duplicate(true) if not map.is_empty() else {"views": []}
	var views: Array = out.get("views", [])
	if not (views is Array):
		views = []
	var want: int = maxi(index + 1, count)
	while views.size() < want:
		views.append({"tracks": [], "clips": [], "colour": -1})
	var one: Dictionary = views[index]
	var clips: Array = one.get("clips", [])
	if not (clips is Array):
		clips = []
	var at: int = clips.find(clip_id)
	if on and at >= 0:
		return {}
	if not on and at < 0:
		return {}
	if on:
		clips.append(clip_id)
	else:
		clips.remove_at(at)
	one["clips"] = clips
	views[index] = one
	out["views"] = views
	return out


static func track_order(map: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for v: Variant in map.get("views", []):
		for tid: Variant in (v as Dictionary).get("tracks", []):
			var id: String = String(tid)
			if not out.has(id):
				out.append(id)
	return out


static func region_names(e: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var params: Dictionary = e.get("params", {})
	var raw: Variant = params.get("crops", null)
	if raw is Dictionary:
		var parsed: Variant = JSON.parse_string(String(AnimProp.static_value(raw)).strip_edges())
		if parsed is Array:
			for cr: Variant in parsed:
				if cr is Dictionary:
					out.append(String((cr as Dictionary).get("name", "")))
	if out.is_empty():
		out.append("Full")
	for i: int in out.size():
		if out[i].strip_edges().is_empty():
			out[i] = "View " + str(i + 1)
	return out


static func offset_key(index: int) -> String:
	return "offset" + str(index)


static func offset_prop(e: Dictionary, index: int) -> Dictionary:
	var params: Dictionary = e.get("params", {})
	var raw: Variant = params.get(offset_key(index), null)
	return raw if raw is Dictionary else {}


static func clamp_offset(v: float) -> float:
	return clampf(v, -OFFSET_MAX, OFFSET_MAX)


static func has_offset(e: Dictionary, index: int) -> bool:
	var p: Dictionary = offset_prop(e, index)
	if p.is_empty():
		return false
	if AnimProp.is_animated(p):
		return true
	return absf(float(AnimProp.static_value(p))) > OFFSET_EPS


static func any_offset(e: Dictionary) -> bool:
	for i: int in mini(crop_count(e), REGION_MAX):
		if has_offset(e, i):
			return true
	return false


static func key_time(video: Clip, local: float) -> float:
	if video != null and video.has_method("anim_time"):
		return float(video.call("anim_time", local))
	return local


static func offset_at(e: Dictionary, index: int, video: Clip, local: float) -> float:
	if e.has(HEARD_KEY):
		return heard_offset_at(e[HEARD_KEY], video, local)
	var p: Dictionary = offset_prop(e, index)
	if p.is_empty():
		return 0.0
	if not AnimProp.is_animated(p):
		return clamp_offset(float(AnimProp.static_value(p)))
	var dur: float = video.duration if video != null else 0.0
	return clamp_offset(AnimProp.evaluate_float(p, video.fx_time(e, offset_key(index), local) if video != null else local, dur))


static func offset_plus(p: Dictionary, delta: float) -> Dictionary:
	if p.is_empty():
		return AnimProp.make(clamp_offset(delta))
	if not AnimProp.is_animated(p):
		return AnimProp.make(clamp_offset(float(AnimProp.static_value(p)) + delta))
	var out: Dictionary = p.duplicate(true)
	out["base"] = clamp_offset(float(out.get("base", 0.0)) + delta)
	var li: int = AnimProp.keys_layer_index(out)
	if li >= 0:
		for k: Variant in (out["layers"][li] as Dictionary).get("keys", []):
			var kd: Dictionary = k
			kd["v"] = clamp_offset(float(kd.get("v", 0.0)) + delta)
	return out


static func views_hearing(map: Dictionary, track_id: String, clip_id: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var views: Array = map.get("views", [])
	for i: int in views.size():
		if hears(map, i, track_id, clip_id):
			out.append(i)
	return out


static func reaches(map: Dictionary, video: Clip, c: Clip, track_id: String) -> bool:
	if video == null or c == null:
		return false
	if not governs(map, track_id, c.id):
		return false
	if String(map.get("scope", "group")) == "group" and not in_family(video, c) and not named_clip(map, c.id):
		return false
	if c.end() <= video.start or c.start >= video.end():
		return false
	return true


static func view_sounds(map: Dictionary, s: Sequence, video: Clip, index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s == null or video == null or map.is_empty():
		return out
	for tr: Track in s.all_tracks():
		var clips: Array[Clip] = []
		for c: Clip in tr.clips:
			if c == video:
				continue
			if reaches(map, video, c, tr.id) and hears(map, index, tr.id, c.id):
				clips.append(c)
		if not clips.is_empty():
			out.append({"track": tr, "clips": clips})
	return out


static func shared_sounds(map: Dictionary, s: Sequence, video: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s == null or video == null or map.is_empty():
		return out
	for tr: Track in s.all_tracks():
		for c: Clip in tr.clips:
			if c == video or not reaches(map, video, c, tr.id):
				continue
			for views: PackedInt32Array in ViewStreams.hearing_groups(map, tr.id, c, video):
				if views.size() >= 2:
					out.append({"track": tr, "clip": c, "views": views})
	return out


const ViewStreams := preload("res://doc/view_streams.gd")


static func plain_heard(e: Dictionary, index: int) -> Dictionary:
	return {"params": {offset_key(0): offset_prop(e, index)}}


static func same_offsets(e: Dictionary, views: PackedInt32Array) -> bool:
	var first: Dictionary = offset_prop(e, views[0])
	var first_on: bool = has_offset(e, views[0])
	for i: int in range(1, views.size()):
		var on: bool = has_offset(e, views[i])
		if not on and not first_on:
			continue
		if on != first_on or offset_prop(e, views[i]) != first:
			return false
	return true


static func heard_changes(e: Dictionary, video: Clip, views: PackedInt32Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ch: Dictionary in sound_changes(e, video):
		var v: int = int(ch["view"])
		if not views.has(v):
			continue
		if not out.is_empty() and int(out[out.size() - 1]["view"]) == v:
			continue
		out.append({"u": float(ch["u"]), "view": v})
	return out


static func heard_view_at(changes: Array, local: float) -> int:
	if changes.is_empty():
		return -1
	var view: int = int((changes[0] as Dictionary)["view"])
	for ch: Variant in changes:
		var cd: Dictionary = ch
		if float(cd["u"]) <= local + HEARD_EPS:
			view = int(cd["view"])
		else:
			break
	return view


static func heard_offset_at(h: Dictionary, video: Clip, local: float) -> float:
	var view: int = heard_view_at(h["changes"], local)
	var fixed: Dictionary = h["fixed"]
	if fixed.has(view):
		return float(fixed[view])
	return offset_at(h["entry"], view, video, local)


static func heard_entry(e: Dictionary, video: Clip, c: Clip, views: PackedInt32Array, live: bool) -> Dictionary:
	if views.is_empty():
		return {}
	if live or views.size() < 2 or video == null or same_offsets(e, views):
		return plain_heard(e, views[0])
	var changes: Array[Dictionary] = heard_changes(e, video, views)
	if changes.is_empty():
		return plain_heard(e, views[0])
	var u0: float = (c.start if c != null else video.start) - video.start
	var u1: float = (c.end() if c != null else video.end()) - video.start
	var turns: bool = false
	for ch: Dictionary in changes:
		var u: float = float(ch["u"])
		if u > u0 + HEARD_EPS and u < u1 - HEARD_EPS:
			turns = true
	if not turns:
		return plain_heard(e, heard_view_at(changes, u0))
	var times: Array[float] = []
	for ch2: Dictionary in changes:
		times.append(float(ch2["u"]))
	var used: PackedInt32Array = PackedInt32Array()
	var fixed: Dictionary = {}
	for ch3: Dictionary in changes:
		var cv: int = int(ch3["view"])
		if used.has(cv):
			continue
		used.append(cv)
		if not AnimProp.is_animated(offset_prop(e, cv)):
			fixed[cv] = offset_at(e, cv, video, 0.0)
	var h: Dictionary = {"entry": e, "changes": changes, "fixed": fixed}
	for v: int in used:
		for k: Dictionary in AnimProp.keys(offset_prop(e, v)):
			times.append(float(k.get("t", 0.0)))
	times.sort()
	var keys: Array = []
	var last_t: float = -INF
	for t: float in times:
		if t - last_t <= AnimProp.KEY_TOLERANCE:
			continue
		keys.append({"t": t, "v": heard_offset_at(h, video, t), "i": "hold"})
		last_t = t
	var marks: Dictionary = {"a": true, "base": float((keys[0] as Dictionary)["v"]), "layers": [{"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": "once", "keys": keys}]}
	return {"params": {offset_key(0): marks}, HEARD_KEY: h}


static func always_heard(map: Dictionary, track_id: String) -> bool:
	return ViewStreams.always(map, track_id)


static func always_tracks(map: Dictionary, key: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var raw: Variant = map.get(key, null)
	if raw is Array:
		for id: Variant in (raw as Array):
			if not out.has(String(id)):
				out.append(String(id))
	return out


static func with_always(map: Dictionary, key: String, track_id: String, on: bool) -> Dictionary:
	var out: Dictionary = map.duplicate(true)
	var list: PackedStringArray = always_tracks(out, key)
	var at: int = list.find(track_id)
	if on and at < 0:
		list.append(track_id)
	elif not on and at >= 0:
		list.remove_at(at)
	if list.is_empty():
		out.erase(key)
	else:
		out[key] = Array(list)
	return out


static func every_of(sources: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for src: Dictionary in sources:
		if not (src["map"] as Dictionary).has(ALWAYS_EVERY_KEY):
			continue
		for id: String in always_tracks(src["map"], ALWAYS_EVERY_KEY):
			if not out.has(id):
				out.append(id)
	return out


static func share_every(sources: Array[Dictionary]) -> void:
	var every: PackedStringArray = every_of(sources)
	if every.is_empty():
		return
	for src: Dictionary in sources:
		var map: Dictionary = src["map"]
		if always_tracks(map, ALWAYS_EVERY_KEY) == every:
			continue
		var shared: Dictionary = map.duplicate()
		shared[ALWAYS_EVERY_KEY] = Array(every)
		src["map"] = shared


static func governed_tracks(map: Dictionary, s: Sequence) -> Array[Track]:
	var out: Array[Track] = []
	if s == null or map.is_empty():
		return out
	var named: Dictionary = {}
	for v: Variant in map.get("views", []):
		if not (v is Dictionary):
			continue
		for cid: Variant in (v as Dictionary).get("clips", []):
			named[String(cid)] = true
	var always_ids: PackedStringArray = always_tracks(map, ALWAYS_KEY) + always_tracks(map, ALWAYS_EVERY_KEY)
	for tr: Track in s.all_tracks():
		var take: bool = always_ids.has(tr.id) or track_order(map).has(tr.id) or ViewStreams.picked_anywhere(map, tr.id)
		if not take and not named.is_empty():
			for c: Clip in tr.clips:
				if named.has(c.id):
					take = true
					break
		if take:
			out.append(tr)
	return out


static func sound_override(e: Dictionary) -> bool:
	var params: Variant = e.get("params", null)
	if not (params is Dictionary):
		return false
	var raw: Variant = (params as Dictionary).get(SOUND_VIEW_KEY, null)
	if not (raw is Dictionary):
		return false
	if AnimProp.is_animated(raw):
		return true
	return index_at(_num(AnimProp.static_value(raw)), 0, REGION_MAX + 1) != 0


static func sound_picks(e: Dictionary, video: Clip) -> Array[Dictionary]:
	if video == null or not sound_override(e):
		var none: Array[Dictionary] = [{"u": 0.0, "view": 0}]
		return none
	return _single(e, video, SOUND_VIEW_KEY, "", mini(crop_count(e), REGION_MAX) + 1)


static func sound_changes(e: Dictionary, video: Clip) -> Array[Dictionary]:
	var shown: Array[Dictionary] = changes(e, video)
	if video == null or not sound_override(e):
		return shown
	var n: int = maxi(mini(crop_count(e), REGION_MAX), 1)
	var picks: Array[Dictionary] = sound_picks(e, video)
	var times: Array[float] = []
	for ch: Dictionary in shown:
		times.append(float(ch["u"]))
	for ch2: Dictionary in picks:
		times.append(float(ch2["u"]))
	times.sort()
	var out: Array[Dictionary] = []
	var last: float = -INF
	for u: float in times:
		if u - last <= CHANGE_MERGE and not out.is_empty():
			continue
		last = u
		var pick: int = heard_view_at(picks, u)
		var v: int = clampi(pick - 1 if pick > 0 else heard_view_at(shown, u), 0, n - 1)
		if out.is_empty():
			out.append({"u": 0.0, "view": v})
		else:
			_record(out, u, v)
	return out


static func sound_steps(e: Dictionary, video: Clip) -> Array[Dictionary]:
	if not sound_override(e):
		return steps(e, video)
	var out: Array[Dictionary] = []
	if video == null:
		return out
	for ch: Dictionary in sound_changes(e, video):
		out.append({"t": video.start + float(ch["u"]), "view": int(ch["view"])})
	return out


static func remap_always(map: Dictionary, remap: Dictionary) -> Dictionary:
	var out: Dictionary = map
	for key: String in [ALWAYS_KEY, ALWAYS_EVERY_KEY]:
		var list: PackedStringArray = always_tracks(map, key)
		if list.is_empty():
			continue
		var fresh: Array = []
		for id: String in list:
			var to: String = String(remap.get(id, id))
			if not fresh.has(to):
				fresh.append(to)
		if is_same(out, map):
			out = map.duplicate(true)
		out[key] = fresh
	return out

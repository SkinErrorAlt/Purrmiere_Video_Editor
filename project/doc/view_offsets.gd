extends RefCounted

const VERSION := 1
const Clip := preload("res://doc/clip.gd")
const Sequence := preload("res://doc/sequence.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ViewMap := preload("res://doc/view_map.gd")
const Command := preload("res://doc/commands/command.gd")
const PairCmds := preload("res://doc/commands/pair_cmds.gd")
const EDGE := 0.000001
const GUARD := 0.0005
const HOLD := "hold"
const ONCE := "once"
const WRAPPED: PackedStringArray = ["loop", "pingpong"]


static func _num(v: Variant) -> float:
	if v is float or v is int:
		return float(v)
	if v is bool:
		return 1.0 if v else 0.0
	if v is Array and not (v as Array).is_empty():
		return float(v[0])
	return 0.0


static func cuts_of(e: Dictionary, video: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if e.is_empty() or video == null:
		return out
	var dur: float = maxf(video.duration, 0.0)
	var chs: Array[Dictionary] = ViewMap.changes(e, video)
	if chs.is_empty():
		out.append({"u0": 0.0, "u1": dur, "view": 0})
		return out
	for i: int in chs.size():
		var u0: float = clampf(float(chs[i]["u"]), 0.0, dur)
		var u1: float = dur if i + 1 >= chs.size() else clampf(float(chs[i + 1]["u"]), 0.0, dur)
		if u1 - u0 <= EDGE:
			continue
		out.append({"u0": u0, "u1": u1, "view": int(chs[i]["view"])})
	if out.is_empty():
		out.append({"u0": 0.0, "u1": dur, "view": int(chs[0]["view"])})
	return out


static func cut_count(e: Dictionary, video: Clip) -> int:
	return cuts_of(e, video).size()


static func cut_index_at(cuts: Array[Dictionary], local: float) -> int:
	if cuts.is_empty():
		return -1
	var at: int = 0
	for i: int in cuts.size():
		if float(cuts[i]["u0"]) <= local + EDGE:
			at = i
	return at


static func cut_at(e: Dictionary, video: Clip, local: float) -> Dictionary:
	var cuts: Array[Dictionary] = cuts_of(e, video)
	var i: int = cut_index_at(cuts, local)
	return {} if i < 0 else cuts[i]


static func whole_clip(cut: Dictionary, video: Clip) -> bool:
	if cut.is_empty() or video == null:
		return true
	return float(cut["u0"]) <= GUARD * 2.0 and float(cut["u1"]) >= maxf(video.duration, 0.0) - GUARD * 2.0


static func _loop_of(p: Dictionary) -> String:
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0:
		return ONCE
	return String((p["layers"][li] as Dictionary).get("loop", ONCE))


static func _value_of(ks: Array, loop: String, t: float, dur: float, base: float) -> float:
	if ks.is_empty():
		return base
	var tmp: Dictionary = {"a": true, "base": base, "layers": [{"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": loop, "keys": ks}]}
	return AnimProp.evaluate_float(tmp, t, dur)


static func _interp_at(ks: Array, t: float) -> String:
	var best: int = -1
	var best_t: float = -INF
	for i: int in ks.size():
		var kt: float = float((ks[i] as Dictionary).get("t", 0.0))
		if kt <= t + AnimProp.KEY_TOLERANCE and kt > best_t:
			best_t = kt
			best = i
	if best < 0:
		return HOLD
	return String((ks[best] as Dictionary).get("i", "linear"))


static func _ramps_into(ks: Array, t: float) -> bool:
	var best: int = -1
	var best_t: float = -INF
	var after: bool = false
	for i: int in ks.size():
		var kt: float = float((ks[i] as Dictionary).get("t", 0.0))
		if kt < t - AnimProp.KEY_TOLERANCE:
			if kt > best_t:
				best_t = kt
				best = i
		else:
			after = true
	if best < 0 or not after:
		return false
	return String((ks[best] as Dictionary).get("i", "linear")) != HOLD


static func _any_before(ks: Array, t: float) -> bool:
	for k: Variant in ks:
		if float((k as Dictionary).get("t", 0.0)) < t - AnimProp.KEY_TOLERANCE:
			return true
	return false


static func _pin(list: Array, t: float, v: float, interp: String) -> void:
	for k: Variant in list:
		if absf(float((k as Dictionary).get("t", 0.0)) - t) <= AnimProp.KEY_TOLERANCE:
			return
	list.append({"t": t, "v": v, "i": interp})


static func _hold_before(list: Array, t: float) -> void:
	var best: int = -1
	var best_t: float = -INF
	for i: int in list.size():
		var kt: float = float((list[i] as Dictionary).get("t", 0.0))
		if kt < t - AnimProp.KEY_TOLERANCE and kt > best_t:
			best_t = kt
			best = i
	if best >= 0:
		(list[best] as Dictionary)["i"] = HOLD


static func _sorted_by_time(list: Array) -> Array:
	list.sort_custom(func(a: Variant, b: Variant) -> bool:
		return float((a as Dictionary).get("t", 0.0)) < float((b as Dictionary).get("t", 0.0)))
	return list


static func section_plus(p: Dictionary, delta: float, k0: float, k1: float, k_end: float, dur: float) -> Dictionary:
	if absf(delta) <= ViewMap.OFFSET_EPS:
		return p.duplicate(true)
	var head: bool = k0 > GUARD * 2.0
	var tail: bool = k1 < k_end - GUARD * 2.0
	if not head and not tail:
		return ViewMap.offset_plus(p, delta)
	if WRAPPED.has(_loop_of(p)):
		return ViewMap.offset_plus(p, delta)
	var animated: bool = AnimProp.is_animated(p)
	var base: float = _num(AnimProp.static_value(p))
	var out: Dictionary = p.duplicate(true) if animated else {"base": base, "layers": []}
	out["a"] = true
	var li: int = AnimProp.keys_layer_index(out)
	if li < 0:
		(out["layers"] as Array).insert(0, {"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": ONCE, "keys": []})
		li = 0
	var layer: Dictionary = (out["layers"] as Array)[li]
	var loop: String = String(layer.get("loop", ONCE))
	var was: Array = []
	for k: Variant in layer.get("keys", []):
		was.append((k as Dictionary).duplicate(true))
	var at0: float = _value_of(was, loop, k0, dur, base)
	var at1: float = _value_of(was, loop, k1, dur, base)
	var fresh: Array = []
	for k2: Variant in was:
		var kd: Dictionary = (k2 as Dictionary).duplicate(true)
		var t: float = float(kd.get("t", 0.0))
		if t >= k0 - AnimProp.KEY_TOLERANCE and t < k1 - AnimProp.KEY_TOLERANCE:
			kd["v"] = ViewMap.clamp_offset(_num(kd.get("v", 0.0)) + delta)
		fresh.append(kd)
	if head:
		if _ramps_into(was, k0):
			_pin(fresh, k0 - GUARD, _value_of(was, loop, k0 - GUARD, dur, base), HOLD)
		elif not _any_before(was, k0):
			_pin(fresh, 0.0, _value_of(was, loop, 0.0, dur, base), HOLD)
		else:
			_hold_before(fresh, k0)
	_pin(fresh, k0, ViewMap.clamp_offset(at0 + delta), _interp_at(was, k0))
	if tail:
		if _ramps_into(was, k1):
			_pin(fresh, k1 - GUARD, ViewMap.clamp_offset(_value_of(was, loop, k1 - GUARD, dur, base) + delta), HOLD)
		else:
			_hold_before(fresh, k1)
		_pin(fresh, k1, ViewMap.clamp_offset(at1), _interp_at(was, k1))
	layer["keys"] = _sorted_by_time(fresh)
	layer["on"] = true
	return out


static func cut_plus(e: Dictionary, video: Clip, index: int, cut: Dictionary, delta: float, from: Dictionary = {}) -> Dictionary:
	var p: Dictionary = from if not from.is_empty() else ViewMap.offset_prop(e, index)
	if video == null or cut.is_empty() or e.is_empty():
		return ViewMap.offset_plus(p, delta)
	var key: String = ViewMap.offset_key(index)
	var dur: float = maxf(video.duration, 0.0)
	var k0: float = video.fx_time(e, key, float(cut["u0"]))
	var k1: float = video.fx_time(e, key, float(cut["u1"]))
	var k_end: float = video.fx_time(e, key, dur)
	if k1 <= k0 + EDGE or k_end <= EDGE:
		return ViewMap.offset_plus(p, delta)
	return section_plus(p, delta, k0, k1, k_end, dur)


static func cut_set(e: Dictionary, video: Clip, index: int, cut: Dictionary, seconds: float, local: float) -> Dictionary:
	var now: float = ViewMap.offset_at(e, index, video, local)
	return cut_plus(e, video, index, cut, ViewMap.clamp_offset(seconds) - now, {})


static func pair_entries(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null:
		return out
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) == ViewMap.PAIR_VIEW_ID and bool(e.get("enabled", true)):
			out.append(e)
	return out


static func pair_clips(s: Sequence, ids: PackedStringArray) -> Array[Clip]:
	var out: Array[Clip] = []
	if s == null:
		return out
	for id: String in ids:
		var c: Clip = s.clip_by_id(id)
		if c != null and not out.has(c) and not pair_entries(c).is_empty():
			out.append(c)
	return out


static func targets(s: Sequence, ids: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Clip in pair_clips(s, ids):
		for e: Dictionary in pair_entries(c):
			for i: int in mini(ViewMap.crop_count(e), ViewMap.REGION_MAX):
				out.append({"clip": c, "uid": String(e.get("uid", "")), "entry": e, "index": i})
	return out


static func offset_command(s: Sequence, target: Dictionary, next: Dictionary) -> Command:
	var e: Dictionary = target["entry"]
	var path: String = ViewMap.param_path(e, ViewMap.offset_key(int(target["index"])))
	return PairCmds.SetOffset.new(s.id, (target["clip"] as Clip).id, path, next, not ViewMap.of(e).is_empty())


static func nudge_commands(s: Sequence, ids: PackedStringArray, delta: float) -> Array[Command]:
	var out: Array[Command] = []
	if s == null or absf(delta) <= ViewMap.OFFSET_EPS:
		return out
	for t: Dictionary in targets(s, ids):
		var e: Dictionary = t["entry"]
		var i: int = int(t["index"])
		out.append(offset_command(s, t, ViewMap.offset_plus(ViewMap.offset_prop(e, i), delta)))
	return out


static func set_commands(s: Sequence, ids: PackedStringArray, seconds: float, at: float) -> Array[Command]:
	var out: Array[Command] = []
	if s == null:
		return out
	var want: float = ViewMap.clamp_offset(seconds)
	for t: Dictionary in targets(s, ids):
		var c: Clip = t["clip"]
		var e: Dictionary = t["entry"]
		var i: int = int(t["index"])
		var local: float = clampf(at - c.start, 0.0, maxf(c.duration, 0.0))
		var delta: float = want - ViewMap.offset_at(e, i, c, local)
		if absf(delta) <= ViewMap.OFFSET_EPS:
			continue
		out.append(offset_command(s, t, ViewMap.offset_plus(ViewMap.offset_prop(e, i), delta)))
	return out

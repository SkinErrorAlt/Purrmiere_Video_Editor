extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const Clip := preload("res://doc/clip.gd")
const Track := preload("res://doc/track.gd")
const Sequence := preload("res://doc/sequence.gd")
const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const PROGRESS := "progress"
const PARAMS := "params"
const IN_FIELD := "transition_in"
const OUT_FIELD := "transition_out"
const ADJACENT := 0.002
const TIMINGS: Array = [["even", "Even"], ["ease_in", "Ease in"], ["ease_out", "Ease out"], ["ease_both", "Ease in and out"], ["overshoot", "Overshoot"], ["reverse", "Reverse"]]
const FITS: Array = [["start", "Fit keys to the start", 0.0, 0.5], ["end", "Fit keys to the end", 0.5, 1.0], ["middle", "Fit keys to the middle", 0.25, 0.75]]
const PROGRESS_CLAMP := 0.5

static var plant_no_stretch: bool = false


static func curve(name: String, dur: float) -> Dictionary:
	var d: float = maxf(dur, Clip.MIN_TRANSITION)
	var p: Dictionary = AnimProp.make(0.0)
	if name == "reverse":
		p = AnimProp.set_key(p, 0.0, 1.0, "linear")
		p = AnimProp.set_key(p, d, 0.0, "linear")
		return p
	var interp: String = "linear"
	if name == "ease_in" or name == "ease_out" or name == "ease_both":
		interp = name
	elif name == "overshoot":
		interp = "ease_out"
	p = AnimProp.set_key(p, 0.0, 0.0, interp)
	p = AnimProp.set_key(p, d, 1.0, "linear")
	if name == "overshoot":
		p = AnimProp.set_key_fields(p, 0.0, {"ease": "back"})
	return p


static func with_progress(tr: Dictionary) -> Dictionary:
	var out: Dictionary = tr.duplicate(true)
	if not (out.get(PARAMS) is Dictionary):
		out[PARAMS] = {}
	var params: Dictionary = out[PARAMS]
	if not (params.get(PROGRESS) is Dictionary):
		params[PROGRESS] = curve("even", float(out.get("duration", 1.0)))
	return out


static func progress_at(tr: Dictionary, span_t: float, dur: float, fps: float) -> float:
	var linear: float = clampf(span_t / maxf(dur, 0.0001), 0.0, 1.0)
	var params: Variant = tr.get(PARAMS, null)
	if not (params is Dictionary):
		return linear
	var p: Variant = (params as Dictionary).get(PROGRESS, null)
	if not (p is Dictionary) or not AnimProp.is_animated(p):
		return linear
	var v: Variant = AnimProp.evaluate(p, span_t, dur, fps)
	if not (v is float or v is int):
		return linear
	return clampf(float(v), -PROGRESS_CLAMP, 1.0 + PROGRESS_CLAMP)


static func key_times(tr: Dictionary) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var params: Variant = tr.get(PARAMS, null)
	if not (params is Dictionary):
		return out
	for k: Variant in (params as Dictionary).keys():
		var p: Variant = (params as Dictionary)[k]
		if p is Dictionary and AnimProp.is_animated(p):
			for kd: Dictionary in AnimProp.keys(p):
				out.append(float(kd.get("t", 0.0)))
	out.sort()
	return out


static func _remap(tr: Dictionary, scale: float, shift: float) -> Dictionary:
	var out: Dictionary = tr.duplicate(true)
	var params: Variant = out.get(PARAMS, null)
	if not (params is Dictionary):
		return out
	for k: Variant in (params as Dictionary).keys():
		var p: Variant = (params as Dictionary)[k]
		if p is Dictionary and AnimProp.is_animated(p):
			var q: Dictionary = AnimProp.scale_times(p, scale) if scale > 0.0 and absf(scale - 1.0) > 0.0000001 else (p as Dictionary)
			if absf(shift) > 0.0000001:
				q = AnimProp.shift_keys(q, shift)
			(params as Dictionary)[k] = q
	return out


static func stretched(tr: Dictionary, new_dur: float) -> Dictionary:
	var old: float = maxf(float(tr.get("duration", new_dur)), 0.0001)
	var out: Dictionary = _remap(tr, 1.0 if plant_no_stretch else maxf(new_dur, 0.0001) / old, 0.0)
	out["duration"] = new_dur
	return out


static func fitted(tr: Dictionary, from_frac: float, to_frac: float) -> Dictionary:
	var times: PackedFloat64Array = key_times(tr)
	if times.is_empty():
		return tr.duplicate(true)
	var dur: float = maxf(float(tr.get("duration", 1.0)), 0.0001)
	var a: float = clampf(minf(from_frac, to_frac), 0.0, 1.0) * dur
	var b: float = clampf(maxf(from_frac, to_frac), 0.0, 1.0) * dur
	var lo: float = times[0]
	var hi: float = times[times.size() - 1]
	if hi - lo <= 0.0000001:
		return _remap(tr, 1.0, a - lo)
	var k: float = (b - a) / (hi - lo)
	if k <= 0.0:
		return _remap(tr, 1.0, a - lo)
	return _remap(tr, k, a - lo * k)


static func fit_range(id: String) -> Vector2:
	for f: Array in FITS:
		if String(f[0]) == id:
			return Vector2(float(f[2]), float(f[3]))
	return Vector2(0.0, 1.0)


static func with_timing(tr: Dictionary, name: String) -> Dictionary:
	var out: Dictionary = with_progress(tr)
	(out[PARAMS] as Dictionary)[PROGRESS] = curve(name, float(out.get("duration", 1.0)))
	return out


static func relative(tr: Dictionary) -> Dictionary:
	var dur: float = maxf(float(tr.get("duration", 1.0)), 0.0001)
	var out: Dictionary = _remap(tr, 1.0 / dur, 0.0)
	return out


static func absolute(rel: Dictionary, dur: float) -> Dictionary:
	var out: Dictionary = _remap(rel, maxf(dur, 0.0001), 0.0)
	out["duration"] = dur
	return out


static func preset_payload(tr: Dictionary) -> Dictionary:
	var rel: Dictionary = relative(tr)
	return {"transition": rel, "length": float(tr.get("duration", 1.0)), "offset": Clip.transition_offset(tr)}


static func from_preset(payload: Dictionary, dur: float, offset: float) -> Dictionary:
	var rel: Dictionary = payload.get("transition", {})
	var out: Dictionary = absolute(rel, dur)
	out["offset"] = offset
	out.erase("align")
	return out


static func neighbour_before(tr: Track, c: Clip) -> Clip:
	var p: Clip = tr.prev_clip(c) if tr != null else null
	if p != null and absf(p.end() - c.start) <= ADJACENT:
		return p
	return null


static func neighbour_after(tr: Track, c: Clip) -> Clip:
	var n: Clip = tr.next_clip(c) if tr != null else null
	if n != null and absf(n.start - c.end()) <= ADJACENT:
		return n
	return null


static func _speed(c: Clip) -> float:
	return maxf(absf(c.static_speed()), 0.0001)


static func _media_len(d: Project, c: Clip) -> float:
	if d == null or c == null:
		return -1.0
	var m: MediaItem = d.media_by_id(c.media_id)
	if m == null or c.loop or not (m.kind == "video" or m.kind == "audio"):
		return -1.0
	var dur: float = d.media_duration(m)
	return dur if dur > 0.0 else -1.0


static func limits(d: Project, s: Sequence, c: Clip, field: String) -> Vector2:
	var tr: Track = s.track_of(c.id) if s != null else null
	if field == OUT_FIELD:
		var lo_o: float = c.start
		var nxt: Clip = tr.next_clip(c) if tr != null else null
		var hi_o: float = nxt.start if nxt != null else c.end() + 3600.0
		var ml: float = _media_len(d, c)
		if ml >= 0.0:
			hi_o = minf(hi_o, c.end() + maxf(ml - (c.in_offset + c.duration * _speed(c)), 0.0) / _speed(c))
		return Vector2(lo_o, maxf(hi_o, c.end()))
	var prev: Clip = neighbour_before(tr, c)
	var lo: float = prev.start if prev != null else c.start - 3600.0
	if prev == null and tr != null and tr.prev_clip(c) != null:
		lo = maxf(lo, tr.prev_clip(c).end())
	var head: float = c.in_offset / _speed(c) if _media_len(d, c) >= 0.0 else 3600.0
	lo = maxf(maxf(lo, c.start - head), 0.0)
	var hi: float = c.end()
	if prev != null:
		var pl: float = _media_len(d, prev)
		if pl >= 0.0:
			hi = minf(hi, prev.end() + maxf(pl - (prev.in_offset + prev.duration * _speed(prev)), 0.0) / _speed(prev))
	return Vector2(minf(lo, c.start), maxf(hi, c.start))

extends RefCounted

const WINDOW_POINTS := 1200
const MIN_WINDOW_POINTS := 8
const MAX_WINDOW_POINTS := 1024
const FINEST_TIER_RATE := 100.0
const FINE_MAX_RATE := 262144.0
const FINE_MAX_SPAN := 80.0
const FINE_NONE := 0
const FINE_PENDING := 1
const FINE_READY := 2
const BRIDGE_PATH := "/root/PurrBridge"
const AudioGraph := preload("res://engine/audio_graph.gd")
const PairSyncState := preload("res://engine/pair_sync_state.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const HEARD_CACHE_MAX := 8
const HEARD_SPEED_EPS := 0.000000001
const HEARD_CURVE_STEP := 0.05
const HEARD_CURVE_MAX := 64
const POSE_SHIFT_EPS := 0.000000001

static var request_hook: Callable = Callable()
static var read_hook: Callable = Callable()
static var heard_stats: Dictionary = {"index_builds": 0, "index_usec": 0, "plans": 0, "plan_usec": 0}
static var _heard_cache: Dictionary = {}
static var posing: int = 0
static var posed_by: Object = null


static func pose_delta(c: Clip) -> float:
	if posing <= 0 or posed_by == null or not is_instance_valid(posed_by):
		return 0.0
	return float(posed_by.call("delta_of", c))


static var _ramp_cache: Dictionary = {}


static func ramp_spans(c: Clip) -> Array:
	var rec: Dictionary = _ramp_cache.get(c.id, {})
	if not rec.is_empty() and float(rec["start"]) == c.start and float(rec["duration"]) == c.duration and float(rec["in"]) == c.in_offset and rec["speed"] == c.speed:
		return rec["spans"]
	var entry: Dictionary = {"start": c.start, "duration": c.duration, "in_offset": c.in_offset, "speed": c.speed}
	var spans: Array[Dictionary] = clip_spans(read_spans(entry), c.start, c.end())
	if _ramp_cache.size() > HEARD_CACHE_MAX * 32:
		_ramp_cache.clear()
	_ramp_cache[c.id] = {"start": c.start, "duration": c.duration, "in": c.in_offset, "speed": c.speed.duplicate(true), "spans": spans}
	return spans


static func fine_rate_for(px_per_second: float) -> float:
	var want: float = 2.0 * absf(px_per_second)
	if want <= FINEST_TIER_RATE:
		return 0.0
	var rate: float = pow(2.0, floor(log(want) / log(2.0)))
	if rate <= FINEST_TIER_RATE:
		return 0.0
	return minf(rate, FINE_MAX_RATE)


static func hooked() -> bool:
	return request_hook.is_valid() and read_hook.is_valid()


static func _bridge() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(BRIDGE_PATH)
	return null


static func fine_available(handle: int) -> bool:
	if hooked():
		return true
	if handle < 0:
		return false
	var b: Node = _bridge()
	return b != null and b.has_method("has_fine_peaks") and bool(b.call("has_fine_peaks"))


static func fine_request(handle: int, stream: int, from_seconds: float, to_seconds: float) -> int:
	if hooked():
		return int(request_hook.call(handle, stream, from_seconds, to_seconds))
	var b: Node = _bridge()
	if b == null or not b.has_method("peaks_request_fine"):
		return 0
	return int(b.call("peaks_request_fine", handle, stream, from_seconds, to_seconds))


static func fine_read(handle: int, stream: int, first_bucket: int, count: int, rate: float) -> PackedByteArray:
	var out: Variant = PackedByteArray()
	if hooked():
		out = read_hook.call(handle, stream, first_bucket, count, rate)
	else:
		var b: Node = _bridge()
		if b != null and b.has_method("peaks_read_fine"):
			out = b.call("peaks_read_fine", handle, stream, first_bucket, count, rate)
	if typeof(out) == TYPE_PACKED_BYTE_ARRAY and (out as PackedByteArray).size() == count * 2:
		return out
	return PackedByteArray()


static func fine_wave_rate(handle: int, stream: int, r: Rect2, origin_x: float, scale_x: float, src_in: float, src_out: float, tiers_faked: bool) -> float:
	if tiers_faked and not hooked():
		return 0.0
	var rate: float = fine_rate_for(scale_x)
	if rate <= 0.0 or not fine_available(handle):
		return 0.0
	var vis: Vector2 = visible_span(r, origin_x, scale_x, src_in, src_out)
	if vis.y <= vis.x:
		return 0.0
	var pad: float = float(window_buckets(1, 0) + 2) / rate
	var a: float = maxf(vis.x - pad, src_in)
	var b: float = minf(vis.y + pad, src_out)
	if b - a > FINE_MAX_SPAN or fine_request(handle, stream, a, b) != FINE_READY:
		return 0.0
	return rate


static func listen_fine(ci: CanvasItem) -> void:
	var b: Node = _bridge()
	if b == null or not b.has_signal("fine_peaks_ready"):
		return
	var redraw: Callable = Callable(ci, "queue_redraw").unbind(2)
	if not b.is_connected("fine_peaks_ready", redraw):
		b.connect("fine_peaks_ready", redraw)


static func window_buckets(stride: int, smooth: int) -> int:
	var per_bucket: int = maxi(smooth, 0) + 1
	var points: int = MAX_WINDOW_POINTS
	while points > MIN_WINDOW_POINTS and points * per_bucket > WINDOW_POINTS:
		points = points / 2
	return points * maxi(stride, 1)


static func estimate_points(buckets: int, stride: int, smooth: int) -> int:
	var s: int = maxi(stride, 1)
	var groups: int = (maxi(buckets, 0) + s - 1) / s
	return groups * (maxi(smooth, 0) + 1) + 4


static func aligned_from(first_bucket: int, window_start: int, stride: int) -> int:
	var s: int = maxi(stride, 1)
	var b: int = maxi(first_bucket, window_start)
	return window_start + ((b - window_start) / s) * s


static func _lerp_pair(out: PackedVector2Array, pa: Vector2, pb: Vector2, a: Vector2, b: Vector2, x: float) -> void:
	var t: float = (x - pa.x) / maxf(a.x - pa.x, 0.0000001)
	out.append(Vector2(x, lerpf(pa.y, a.y, t)))
	out.append(Vector2(x, lerpf(pb.y, b.y, t)))


static func trim_ribbon(pts: PackedVector2Array, x0: float, x1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var pairs: int = pts.size() / 2
	if pairs < 2 or x1 <= x0:
		return out
	for i: int in pairs:
		var a: Vector2 = pts[i * 2]
		var b: Vector2 = pts[i * 2 + 1]
		if i > 0:
			var pa: Vector2 = pts[i * 2 - 2]
			var pb: Vector2 = pts[i * 2 - 1]
			if pa.x < x0 and a.x > x0:
				_lerp_pair(out, pa, pb, a, b, x0)
			if pa.x < x1 and a.x > x1:
				_lerp_pair(out, pa, pb, a, b, x1)
		if a.x >= x0 and a.x <= x1:
			out.append(a)
			out.append(b)
	return out


static func visible_span(r: Rect2, origin_x: float, scale_x: float, src_in: float, src_out: float) -> Vector2:
	if scale_x == 0.0:
		return Vector2(src_in, src_in)
	var a: float = (r.position.x - origin_x) / scale_x
	var b: float = (r.end.x - origin_x) / scale_x
	return Vector2(maxf(minf(a, b), src_in), minf(maxf(a, b), src_out))


static func heard_sources(d: Project, s: Sequence) -> Dictionary:
	var key: int = s.get_instance_id()
	var rec: Dictionary = _heard_cache.get(key, {})
	if not rec.is_empty() and int(rec["doc"]) == d.get_instance_id() and (int(rec["serial"]) == d.serial or d.undo.has_live()):
		return rec
	var t0: int = Time.get_ticks_usec()
	var list: Array[Dictionary] = []
	var keys: Dictionary = {}
	for src: Dictionary in AudioGraph.pair_view_sources(s):
		var v: Clip = src["clip"]
		var uid: String = String((src["entry"] as Dictionary).get("uid", ""))
		list.append({"clip": v, "uid": uid, "map": src["map"]})
		keys[v.id + "|" + uid] = true
	rec = {"doc": d.get_instance_id(), "serial": d.serial, "sources": list, "keys": keys, "family": _family_index(list), "plans": {}, "plan_serial": d.serial, "plan_sync": ""}
	if _heard_cache.size() >= HEARD_CACHE_MAX and not _heard_cache.has(key):
		_heard_cache.clear()
	_heard_cache[key] = rec
	heard_stats["index_builds"] = int(heard_stats["index_builds"]) + 1
	heard_stats["index_usec"] = int(heard_stats["index_usec"]) + Time.get_ticks_usec() - t0
	return rec


static func heard_sync_sign() -> String:
	var st: RefCounted = PairSyncState.instance()
	return String(st.get("clip_id")) + "|" + String(st.get("uid")) + "|" + str(st.get("hidden"))


static func heard_plan(d: Project, s: Sequence, c: Clip) -> Dictionary:
	if d == null or s == null or c == null:
		return {}
	var rec: Dictionary = heard_sources(d, s)
	var list: Array = rec["sources"]
	if list.is_empty():
		return {}
	var shift: float = 0.0
	if posing > 0:
		var fam: Array = family_sources(rec, c)
		shift = _pose_shift(s, c, fam)
		if is_nan(shift):
			return _heard_build(d, s, c, fam)
	var sign: String = heard_sync_sign()
	if int(rec["plan_serial"]) != d.serial or String(rec["plan_sync"]) != sign:
		rec["plans"] = {}
		rec["plan_serial"] = d.serial
		rec["plan_sync"] = sign
	var plans: Dictionary = rec["plans"]
	if plans.has(c.id):
		return shifted_plan(plans[c.id], shift)
	var plan: Dictionary = _heard_build(d, s, c, family_sources(rec, c))
	if shift == 0.0:
		plans[c.id] = plan
	return plan


static func _pose_shift(s: Sequence, c: Clip, fam: Array) -> float:
	var shift: float = pose_delta(c)
	if is_nan(shift):
		return NAN
	for src: Variant in fam:
		if not _same_shift(pose_delta((src as Dictionary)["clip"]), shift):
			return NAN
	var tr: Track = s.track_of(c.id)
	if tr == null:
		return shift
	var at: int = tr.index_of_clip(c, c.start)
	if at < 0:
		return shift
	var nxt: Clip = tr.clips[at + 1] if at + 1 < tr.clips.size() else null
	var into: bool = c.has_transition() and str(c.transition_in.get("kind", "")) == "crossfade"
	var out_of: bool = nxt != null and nxt.has_transition() and str(nxt.transition_in.get("kind", "")) == "crossfade"
	if into and at > 0 and not _same_shift(pose_delta(tr.clips[at - 1]), shift):
		return NAN
	if out_of and not _same_shift(pose_delta(nxt), shift):
		return NAN
	return shift


static func _same_shift(a: float, b: float) -> bool:
	return not is_nan(a) and absf(a - b) <= POSE_SHIFT_EPS


static func shifted_plan(plan: Dictionary, delta: float) -> Dictionary:
	if plan.is_empty() or delta == 0.0:
		return plan
	var spans: Array[Dictionary] = []
	for sp: Variant in plan.get("spans", []):
		var sd: Dictionary = sp
		spans.append({"t0": float(sd["t0"]) + delta, "t1": float(sd["t1"]) + delta, "s0": sd["s0"], "s1": sd["s1"], "v": sd["v"]})
	var entry: Dictionary = (plan.get("entry", {}) as Dictionary).duplicate()
	if entry.has("start"):
		entry["start"] = float(entry["start"]) + delta
	return {"entry": entry, "spans": spans}


static func _family_index(list: Array[Dictionary]) -> Dictionary:
	var by_link: Dictionary = {}
	var by_group: Dictionary = {}
	var wide: Array[int] = []
	for i: int in list.size():
		var v: Clip = list[i]["clip"]
		var map: Dictionary = list[i]["map"]
		if String(map.get("scope", "group")) != "group" or _names_clips(map):
			wide.append(i)
			continue
		if not v.link_id.is_empty():
			if not by_link.has(v.link_id):
				by_link[v.link_id] = []
			(by_link[v.link_id] as Array).append(i)
		if not v.group_id.is_empty():
			if not by_group.has(v.group_id):
				by_group[v.group_id] = []
			(by_group[v.group_id] as Array).append(i)
	return {"link": by_link, "group": by_group, "wide": wide}


static func _names_clips(map: Dictionary) -> bool:
	for v: Variant in map.get("views", []):
		if not (v is Dictionary):
			continue
		var named: Variant = (v as Dictionary).get("clips", [])
		if not (named is Array) or not (named as Array).is_empty():
			return true
	return false


static func family_sources(rec: Dictionary, c: Clip) -> Array:
	var list: Array = rec["sources"]
	var fam: Dictionary = rec.get("family", {})
	if fam.is_empty():
		return list
	var picks: Array[int] = []
	picks.append_array(fam["wide"] as Array)
	if not c.link_id.is_empty():
		picks.append_array((fam["link"] as Dictionary).get(c.link_id, []))
	if not c.group_id.is_empty():
		picks.append_array((fam["group"] as Dictionary).get(c.group_id, []))
	picks.sort()
	var out: Array = []
	var last: int = -1
	for i: int in picks:
		if i != last:
			out.append(list[i])
		last = i
	return out


static func _heard_build(d: Project, s: Sequence, c: Clip, list: Array) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var out: Dictionary = {}
	var tr: Track = s.track_of(c.id)
	if tr != null and s.clip_by_id(c.id) == c:
		var sources: Array[Dictionary] = []
		for src: Variant in list:
			var sd: Dictionary = src
			var v: Clip = sd["clip"]
			var e: Dictionary = v.effect_by_uid(String(sd["uid"]))
			if e.is_empty() or not bool(e.get("enabled", true)):
				continue
			sources.append({"clip": v, "entry": e, "map": sd["map"]})
		var entry: Dictionary = AudioGraph.pair_read_entry(d, s, tr, c, sources)
		if not entry.is_empty():
			out = {"entry": entry, "spans": clip_spans(read_spans(entry), c.start, c.end())}
	heard_stats["plans"] = int(heard_stats["plans"]) + 1
	heard_stats["plan_usec"] = int(heard_stats["plan_usec"]) + Time.get_ticks_usec() - t0
	return out


static func heard_moved(d: Project, s: Sequence, cmds: Array) -> bool:
	if d == null or s == null or cmds.is_empty():
		return false
	var keys: Dictionary = heard_sources(d, s)["keys"]
	if keys.is_empty():
		return false
	for cmd: Variant in cmds:
		var parts: PackedStringArray = String((cmd as Object).call("live_key")).split("|")
		if parts.size() == 3 and parts[0] == "clip_param":
			var p: PackedStringArray = parts[2].split(".")
			if p.size() >= 2 and p[0] == "effects" and keys.has(parts[1] + "|" + p[1]):
				return true
		elif parts.size() == 4 and parts[0] == "effect_param" and keys.has(parts[1] + "|" + parts[2]):
			return true
	return false


static func _speed_on(sp: Dictionary, ks: Array[Dictionary], hold: bool, u: float, dur: float) -> float:
	if not AnimProp.is_animated(sp):
		return float(AnimProp.static_value(sp))
	if not hold:
		return AnimProp.evaluate_float(sp, u, dur)
	var v: float = float(ks[0].get("v", 0.0))
	for k: Dictionary in ks:
		if float(k.get("t", 0.0)) <= u:
			v = float(k.get("v", 0.0))
		else:
			break
	return v


static func read_spans(entry: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dur: float = float(entry.get("duration", 0.0))
	if bool(entry.get("muted", false)) or dur <= 0.0:
		return out
	var start: float = float(entry.get("start", 0.0))
	var pos: float = float(entry.get("in_offset", 0.0))
	var sp: Dictionary = entry.get("speed", AnimProp.make(1.0))
	var animated: bool = AnimProp.is_animated(sp)
	var ks: Array[Dictionary] = AnimProp.keys(sp)
	var hold: bool = animated and AnimProp.holds_only(sp)
	if animated and ks.is_empty():
		animated = false
		sp = AnimProp.make(AnimProp.static_value(sp))
	var cuts: Array[float] = [0.0, dur]
	for k: Dictionary in ks:
		var u: float = float(k.get("t", 0.0))
		if u > 0.0 and u < dur:
			cuts.append(u)
	cuts.sort()
	for i: int in range(1, cuts.size()):
		var a: float = cuts[i - 1]
		var b: float = cuts[i]
		if b - a <= 0.0:
			continue
		var n: int = 1 if hold or not animated else clampi(int(ceil((b - a) / HEARD_CURVE_STEP)), 1, HEARD_CURVE_MAX)
		for j: int in n:
			var x0: float = a + (b - a) * float(j) / float(n)
			var x1: float = a + (b - a) * float(j + 1) / float(n)
			var v: float = _speed_on(sp, ks, hold, (x0 + x1) * 0.5, dur)
			var s1: float = pos + v * (x1 - x0)
			var last: Dictionary = out[out.size() - 1] if not out.is_empty() else {}
			if not last.is_empty() and absf(float(last["v"]) - v) <= HEARD_SPEED_EPS:
				last["t1"] = start + x1
				last["s1"] = s1
			else:
				out.append({"t0": start + x0, "t1": start + x1, "s0": pos, "s1": s1, "v": v})
			pos = s1
	return out


static func clip_spans(spans: Array[Dictionary], a: float, b: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sp: Dictionary in spans:
		var t0: float = maxf(float(sp["t0"]), a)
		var t1: float = minf(float(sp["t1"]), b)
		if t1 - t0 <= 0.0:
			continue
		var v: float = float(sp["v"])
		var s0: float = float(sp["s0"]) + (t0 - float(sp["t0"])) * v
		out.append({"t0": t0, "t1": t1, "s0": s0, "s1": s0 + (t1 - t0) * v, "v": v})
	return out


static func heard_source_at(spans: Array, t: float) -> float:
	if spans.is_empty():
		return NAN
	var pick: Dictionary = spans[0]
	for sp: Variant in spans:
		if t >= float((sp as Dictionary)["t0"]):
			pick = sp
		else:
			break
	return float(pick["s0"]) + (t - float(pick["t0"])) * float(pick["v"])


static func heard_time_of(spans: Array, src: float) -> float:
	for sp: Variant in spans:
		var sd: Dictionary = sp
		var v: float = float(sd["v"])
		var lo: float = minf(float(sd["s0"]), float(sd["s1"]))
		var hi: float = maxf(float(sd["s0"]), float(sd["s1"]))
		if absf(v) > HEARD_SPEED_EPS and src >= lo and src <= hi:
			return float(sd["t0"]) + (src - float(sd["s0"])) / v
	return NAN


static func heard_window(spans: Array) -> Vector2:
	var w: PackedFloat64Array = heard_bounds(spans)
	return Vector2(w[0], w[1])


static func heard_bounds(spans: Array) -> PackedFloat64Array:
	if spans.is_empty():
		return PackedFloat64Array([NAN, NAN])
	var lo: float = INF
	var hi: float = -INF
	for sp: Variant in spans:
		var sd: Dictionary = sp
		lo = minf(lo, minf(float(sd["s0"]), float(sd["s1"])))
		hi = maxf(hi, maxf(float(sd["s0"]), float(sd["s1"])))
	return PackedFloat64Array([lo, hi])


static func _first_pair_from(pts: PackedVector2Array, pairs: int, x: float) -> int:
	var lo: int = 0
	var hi: int = pairs
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if pts[mid * 2].x < x:
			lo = mid + 1
		else:
			hi = mid
	return lo


static func trim_sorted(pts: PackedVector2Array, x0: float, x1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var pairs: int = pts.size() / 2
	if pairs < 2 or x1 <= x0:
		return out
	var i0: int = _first_pair_from(pts, pairs, x0)
	var i1: int = _first_pair_from(pts, pairs, x1)
	if i1 < pairs and pts[i1 * 2].x <= x1:
		i1 += 1
	if i0 > 0 and i0 < pairs and pts[i0 * 2].x > x0:
		_lerp_pair(out, pts[i0 * 2 - 2], pts[i0 * 2 - 1], pts[i0 * 2], pts[i0 * 2 + 1], x0)
	if i1 > i0:
		out.append_array(pts.slice(i0 * 2, i1 * 2))
	if i1 > 0 and i1 < pairs and pts[i1 * 2 - 2].x < x1 and pts[i1 * 2].x > x1:
		_lerp_pair(out, pts[i1 * 2 - 2], pts[i1 * 2 - 1], pts[i1 * 2], pts[i1 * 2 + 1], x1)
	return out

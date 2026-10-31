extends RefCounted

const FIELD := "tracking"
const VERSION := 1
const GOOD := 1
const BORN := 2
const LOST := 8
const HAND := 256
const WEAK := 512
const WEAK_BELOW := 0.95
const STOP_BELOW := 0.75
const KIND_BOX := "box"
const KIND_SHAPE := "shape"
const KIND_POINTS := "points"
const ARRAYS: PackedStringArray = ["t", "x", "y", "s", "f"]
const CACHE_MAX := 64
const PX_STEP := 0.001

static var _cache: Dictionary = {}
static var _rev_serial: int = 0


static func store(doc: Object) -> Dictionary:
	if doc == null:
		return {}
	var raw: Variant = doc.get(FIELD)
	return raw if raw is Dictionary else {}


static func read(doc: Object, d: Dictionary) -> void:
	var out: Dictionary = {}
	var raw: Variant = d.get(FIELD, {})
	if raw is Dictionary:
		for k: Variant in (raw as Dictionary).keys():
			var e: Variant = (raw as Dictionary)[k]
			if e is Dictionary and not String((e as Dictionary).get("id", "")).is_empty():
				out[String((e as Dictionary)["id"])] = clean_set(e)
	doc.set(FIELD, out)


static func write(doc: Object, d: Dictionary) -> void:
	var st: Dictionary = store(doc)
	if not st.is_empty():
		d[FIELD] = st.duplicate(true)


static func clean_set(e: Dictionary) -> Dictionary:
	var s: Dictionary = e.duplicate(true)
	s["id"] = String(s.get("id", ""))
	s["label"] = String(s.get("label", ""))
	s["media"] = String(s.get("media", ""))
	s["clip"] = String(s.get("clip", ""))
	s["fps"] = maxf(float(s.get("fps", 30.0)), 1.0)
	s["size"] = _pair(s.get("size", [0, 0]))
	s["range"] = _pair(s.get("range", [0.0, 0.0]))
	s["stop_below"] = clampf(float(s.get("stop_below", STOP_BELOW)), 0.3, 0.99)
	s["version"] = VERSION
	var areas: Array = []
	for a: Variant in (s.get("areas", []) as Array if s.get("areas") is Array else []):
		if a is Dictionary:
			areas.append(a)
	s["areas"] = areas
	var trs: Array = []
	for t: Variant in (s.get("trackers", []) as Array if s.get("trackers") is Array else []):
		if t is Dictionary:
			trs.append(t)
	s["trackers"] = trs
	return s


static func _pair(v: Variant) -> Array:
	if v is Array and (v as Array).size() >= 2:
		return [float((v as Array)[0]), float((v as Array)[1])]
	return [0.0, 0.0]


static func set_by_id(doc: Object, set_id: String) -> Dictionary:
	var st: Dictionary = store(doc)
	var v: Variant = st.get(set_id, {})
	return v if v is Dictionary else {}


static func sets_for_clip(doc: Object, clip_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k: Variant in store(doc).keys():
		var s: Dictionary = store(doc)[k]
		if String(s.get("clip", "")) == clip_id:
			out.append(s)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	return out


static func new_id(doc: Object, prefix: String) -> String:
	var taken: Dictionary = store(doc)
	var n: int = taken.size() + 1
	while taken.has(prefix + str(n)):
		n += 1
	return prefix + str(n)


static func default_range(clip: Object, media_duration: float) -> Array:
	var a: float = maxf(0.0, float(clip.call("source_time", float(clip.get("start")))))
	var b: float = float(clip.call("source_time", float(clip.call("end"))))
	if media_duration > 0.0:
		b = minf(b, media_duration)
	if b <= a:
		b = a + 1.0
	return [a, b]


static func make_set(set_id: String, clip: Object, media: Object, points: int, at_t: float) -> Dictionary:
	var w: float = float(media.get("width")) if media != null else 1920.0
	var h: float = float(media.get("height")) if media != null else 1080.0
	var fps: float = float(media.get("fps")) if media != null and float(media.get("fps")) > 0.0 else 30.0
	var dur: float = float(media.get("duration")) if media != null else 0.0
	var s: Dictionary = {
		"id": set_id,
		"label": "Tracker on " + String(clip.get("label")),
		"media": String(media.get("id")) if media != null else "",
		"clip": String(clip.get("id")),
		"fps": fps,
		"size": [w, h],
		"range": default_range(clip, dur),
		"stop_below": STOP_BELOW,
		"version": VERSION,
		"areas": [],
		"trackers": [],
	}
	var trs: Array = []
	if points >= 2:
		trs.append(make_tracker("t1", "Tracker 1", at_t, Vector2(w * 0.4, h * 0.5)))
		trs.append(make_tracker("t2", "Tracker 2", at_t, Vector2(w * 0.6, h * 0.5)))
	else:
		trs.append(make_tracker("t1", "Tracker 1", at_t, Vector2(w * 0.5, h * 0.5)))
	s["trackers"] = trs
	return s


static func make_tracker(id: String, name: String, at_t: float, p: Vector2) -> Dictionary:
	return {"id": id, "name": name, "kind": "point", "at": [at_t, p.x, p.y], "rev": "", "data": {}}


static func next_rev() -> String:
	_rev_serial += 1
	return "%d_%d_%d" % [Time.get_ticks_usec(), _rev_serial, randi() % 100000]


static func empty_samples() -> Dictionary:
	return {"t": PackedFloat64Array(), "x": PackedFloat32Array(), "y": PackedFloat32Array(), "s": PackedFloat32Array(), "f": PackedInt32Array()}


static func samples(tr: Dictionary) -> Dictionary:
	var rev: String = String(tr.get("rev", ""))
	if rev.is_empty():
		return _decoded(empty_samples())
	if _cache.has(rev):
		return _cache[rev]
	var raw: Dictionary = tr.get("data", {}) if tr.get("data") is Dictionary else {}
	var out: Dictionary = empty_samples()
	out["t"] = Marshalls.base64_to_raw(String(raw.get("t", ""))).to_float64_array()
	out["x"] = Marshalls.base64_to_raw(String(raw.get("x", ""))).to_float32_array()
	out["y"] = Marshalls.base64_to_raw(String(raw.get("y", ""))).to_float32_array()
	out["s"] = Marshalls.base64_to_raw(String(raw.get("s", ""))).to_float32_array()
	out["f"] = Marshalls.base64_to_raw(String(raw.get("f", ""))).to_int32_array()
	var n: int = (out["t"] as PackedFloat64Array).size()
	if (out["x"] as PackedFloat32Array).size() != n or (out["y"] as PackedFloat32Array).size() != n or (out["s"] as PackedFloat32Array).size() != n or (out["f"] as PackedInt32Array).size() != n:
		out = empty_samples()
	var d: Dictionary = _decoded(out)
	if _cache.size() >= CACHE_MAX:
		_cache.clear()
	_cache[rev] = d
	return d


static func _decoded(raw: Dictionary) -> Dictionary:
	var t: PackedFloat64Array = raw["t"]
	var x: PackedFloat32Array = raw["x"]
	var y: PackedFloat32Array = raw["y"]
	var f: PackedInt32Array = raw["f"]
	var vt: PackedFloat64Array = PackedFloat64Array()
	var vx: PackedFloat32Array = PackedFloat32Array()
	var vy: PackedFloat32Array = PackedFloat32Array()
	for i: int in t.size():
		if (f[i] & LOST) == 0:
			vt.append(t[i])
			vx.append(x[i])
			vy.append(y[i])
	var d: Dictionary = raw.duplicate()
	d["vt"] = vt
	d["vx"] = vx
	d["vy"] = vy
	return d


static func pack(tr: Dictionary, sm: Dictionary) -> Dictionary:
	var out: Dictionary = tr.duplicate(true)
	var t: PackedFloat64Array = sm["t"]
	if t.is_empty():
		out["data"] = {}
		out["rev"] = ""
		return out
	out["data"] = {
		"t": Marshalls.raw_to_base64((sm["t"] as PackedFloat64Array).to_byte_array()),
		"x": Marshalls.raw_to_base64((sm["x"] as PackedFloat32Array).to_byte_array()),
		"y": Marshalls.raw_to_base64((sm["y"] as PackedFloat32Array).to_byte_array()),
		"s": Marshalls.raw_to_base64((sm["s"] as PackedFloat32Array).to_byte_array()),
		"f": Marshalls.raw_to_base64((sm["f"] as PackedInt32Array).to_byte_array()),
	}
	var rev: String = next_rev()
	out["rev"] = rev
	_cache[rev] = _decoded({"t": sm["t"], "x": sm["x"], "y": sm["y"], "s": sm["s"], "f": sm["f"]})
	return out


static func merge(old: Dictionary, add: Dictionary, a: float, b: float, eps: float) -> Dictionary:
	var out: Dictionary = empty_samples()
	var ot: PackedFloat64Array = old["t"]
	var nt: PackedFloat64Array = add["t"]
	var order: Array[int] = []
	for i: int in nt.size():
		order.append(i)
	order.sort_custom(func(p: int, q: int) -> bool: return nt[p] < nt[q])
	var lo: float = a - eps
	var hi: float = b + eps
	var i_old: int = 0
	while i_old < ot.size() and ot[i_old] < lo:
		_copy(old, i_old, out)
		i_old += 1
	var last: float = -INF
	for k: int in order:
		if nt[k] - last <= eps * 0.5:
			continue
		_copy(add, k, out)
		last = nt[k]
	while i_old < ot.size() and ot[i_old] <= hi:
		i_old += 1
	while i_old < ot.size():
		if ot[i_old] > last + eps * 0.5:
			_copy(old, i_old, out)
		i_old += 1
	return out


static func _copy(src: Dictionary, i: int, out: Dictionary) -> void:
	add_sample(out, (src["t"] as PackedFloat64Array)[i], Vector2((src["x"] as PackedFloat32Array)[i], (src["y"] as PackedFloat32Array)[i]), (src["s"] as PackedFloat32Array)[i], (src["f"] as PackedInt32Array)[i])


static func add_sample(out: Dictionary, t: float, p: Vector2, score: float, flags: int) -> void:
	var at: PackedFloat64Array = out["t"]
	var ax: PackedFloat32Array = out["x"]
	var ay: PackedFloat32Array = out["y"]
	var a_s: PackedFloat32Array = out["s"]
	var af: PackedInt32Array = out["f"]
	at.append(t)
	ax.append(p.x)
	ay.append(p.y)
	a_s.append(score)
	af.append(flags)
	out["t"] = at
	out["x"] = ax
	out["y"] = ay
	out["s"] = a_s
	out["f"] = af


static func last_at_or_before(t: PackedFloat64Array, at: float) -> int:
	var lo: int = 0
	var hi: int = t.size() - 1
	var found: int = -1
	while lo <= hi:
		var mid: int = (lo + hi) >> 1
		if t[mid] <= at:
			found = mid
			lo = mid + 1
		else:
			hi = mid - 1
	return found


static func frame_eps(fps: float) -> float:
	return 0.25 / maxf(fps, 1.0)


static func placed(tr: Dictionary) -> Vector2:
	var at: Array = tr.get("at", [0.0, 0.0, 0.0]) if tr.get("at") is Array else [0.0, 0.0, 0.0]
	if at.size() < 3:
		return Vector2.ZERO
	return Vector2(float(at[1]), float(at[2]))


static func position_at(tr: Dictionary, mt: float, fps: float) -> Dictionary:
	var sm: Dictionary = samples(tr)
	var vt: PackedFloat64Array = sm["vt"]
	if vt.is_empty():
		return {"ok": true, "p": placed(tr), "tracked": false, "flags": 0, "index": -1, "score": 1.0}
	var i: int = last_at_or_before(vt, mt + frame_eps(fps))
	if i < 0:
		i = 0
	var all_t: PackedFloat64Array = sm["t"]
	var j: int = last_at_or_before(all_t, mt + frame_eps(fps))
	var flags: int = 0
	var score: float = 1.0
	var exact: bool = false
	if j >= 0 and mt - all_t[j] < 1.5 / maxf(fps, 1.0):
		flags = (sm["f"] as PackedInt32Array)[j]
		score = (sm["s"] as PackedFloat32Array)[j]
		exact = true
	return {"ok": true, "p": Vector2((sm["vx"] as PackedFloat32Array)[i], (sm["vy"] as PackedFloat32Array)[i]), "tracked": exact and (flags & LOST) == 0, "flags": flags, "index": j if exact else -1, "score": score}


static func sample_frame(tr: Dictionary, mt: float, fps: float) -> int:
	var sm: Dictionary = samples(tr)
	var all_t: PackedFloat64Array = sm["t"]
	var j: int = last_at_or_before(all_t, mt + frame_eps(fps))
	if j >= 0 and mt - all_t[j] < 1.0 / maxf(fps, 1.0) - frame_eps(fps) * 0.5:
		return j
	return -1


static func frame_start(mt: float, fps: float) -> float:
	var f: float = maxf(fps, 1.0)
	return floor(mt * f + 0.0001) / f


static func with_hand(tr: Dictionary, mt: float, fps: float, p: Vector2) -> Dictionary:
	var sm: Dictionary = samples(tr)
	var j: int = sample_frame(tr, mt, fps)
	var t_key: float = (sm["t"] as PackedFloat64Array)[j] if j >= 0 else frame_start(mt, fps)
	var add: Dictionary = empty_samples()
	add_sample(add, t_key, p, 1.0, GOOD | HAND)
	var eps: float = frame_eps(fps)
	var merged: Dictionary = merge(sm, add, t_key, t_key, eps)
	var out: Dictionary = pack(tr, merged)
	if (sm["t"] as PackedFloat64Array).is_empty():
		out["at"] = [t_key, snap_px(p.x), snap_px(p.y)]
	return out


static func tracked_span(tr: Dictionary) -> Vector2:
	var sm: Dictionary = samples(tr)
	var vt: PackedFloat64Array = sm["vt"]
	if vt.is_empty():
		return Vector2(INF, -INF)
	return Vector2(vt[0], vt[vt.size() - 1])


static func lost_at(tr: Dictionary) -> float:
	var sm: Dictionary = samples(tr)
	var f: PackedInt32Array = sm["f"]
	var t: PackedFloat64Array = sm["t"]
	for i: int in f.size():
		if (f[i] & LOST) != 0:
			return t[i]
	return -1.0


static func tracker_by_id(s: Dictionary, tid: String) -> Dictionary:
	for t: Variant in s.get("trackers", []):
		if t is Dictionary and String((t as Dictionary).get("id", "")) == tid:
			return t
	return {}


static func tracker_index(s: Dictionary, tid: String) -> int:
	var trs: Array = s.get("trackers", [])
	for i: int in trs.size():
		if String((trs[i] as Dictionary).get("id", "")) == tid:
			return i
	return -1


static func with_tracker(s: Dictionary, tr: Dictionary) -> Dictionary:
	var out: Dictionary = s.duplicate(true)
	var trs: Array = out.get("trackers", [])
	var i: int = tracker_index(out, String(tr.get("id", "")))
	if i >= 0:
		trs[i] = tr
	else:
		trs.append(tr)
	out["trackers"] = trs
	return out


static func area_points_at(area: Dictionary, mt: float) -> PackedVector2Array:
	var keys: Array = area.get("keys", []) if area.get("keys") is Array else []
	if keys.is_empty():
		return PackedVector2Array()
	var a: Dictionary = keys[0]
	var b: Dictionary = keys[0]
	var f: float = 0.0
	if keys.size() > 1:
		if mt <= float((keys[0] as Dictionary).get("t", 0.0)):
			a = keys[0]
			b = keys[0]
		elif mt >= float((keys[keys.size() - 1] as Dictionary).get("t", 0.0)):
			a = keys[keys.size() - 1]
			b = a
		else:
			for i: int in range(keys.size() - 1):
				var k0: Dictionary = keys[i]
				var k1: Dictionary = keys[i + 1]
				var t0: float = float(k0.get("t", 0.0))
				var t1: float = float(k1.get("t", 0.0))
				if mt >= t0 and mt <= t1:
					a = k0
					b = k1
					f = (mt - t0) / maxf(t1 - t0, 0.000001)
					break
	var pa: Array = a.get("points", [])
	var pb: Array = b.get("points", [])
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = pa.size() / 2
	var same: bool = pb.size() == pa.size()
	for i: int in n:
		var p: Vector2 = Vector2(float(pa[2 * i]), float(pa[2 * i + 1]))
		if same and f > 0.0:
			p = p.lerp(Vector2(float(pb[2 * i]), float(pb[2 * i + 1])), f)
		out.append(p)
	return out


static func area_keyed(area: Dictionary) -> bool:
	return bool(area.get("keyed", false)) or (area.get("keys") is Array and (area["keys"] as Array).size() > 1)


static func snap_px(v: float) -> float:
	return snappedf(v, PX_STEP)


static func flat_of(pts: PackedVector2Array) -> Array:
	var flat: Array = []
	for p: Vector2 in pts:
		flat.append(snap_px(p.x))
		flat.append(snap_px(p.y))
	return flat


static func with_area_points(area: Dictionary, mt: float, pts: PackedVector2Array, key_it: bool) -> Dictionary:
	var out: Dictionary = area.duplicate(true)
	var flat: Array = flat_of(pts)
	var keys: Array = out.get("keys", []) if out.get("keys") is Array else []
	if not key_it and keys.size() <= 1:
		var t0: float = float((keys[0] as Dictionary).get("t", 0.0)) if not keys.is_empty() else mt
		out["keys"] = [{"t": t0, "points": flat}]
		return out
	var done: bool = false
	for i: int in keys.size():
		if absf(float((keys[i] as Dictionary).get("t", 0.0)) - mt) < 0.0005:
			keys[i] = {"t": float((keys[i] as Dictionary)["t"]), "points": flat}
			done = true
			break
	if not done:
		keys.append({"t": mt, "points": flat})
		keys.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p.get("t", 0.0)) < float(q.get("t", 0.0)))
	out["keys"] = keys
	return out


static func make_area(id: String, kind: String, mt: float, pts: PackedVector2Array, leave_out: bool) -> Dictionary:
	var flat: Array = flat_of(pts)
	return {"id": id, "kind": kind, "leave_out": leave_out, "keys": [{"t": mt, "points": flat}]}


static func box_points(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func engine_area(s: Dictionary) -> Array:
	var out: Array = []
	for a: Variant in s.get("areas", []):
		var ad: Dictionary = a
		var keys: Array = []
		for k: Variant in ad.get("keys", []):
			var kd: Dictionary = k
			var pts: Array = kd.get("points", [])
			if pts.size() >= 6:
				keys.append({"t": float(kd.get("t", 0.0)), "points": PackedFloat32Array(pts)})
		if not keys.is_empty():
			out.append({"leave_out": bool(ad.get("leave_out", false)), "keys": keys})
	return out


static func new_area_id(s: Dictionary) -> String:
	var n: int = 1
	var taken: Dictionary = {}
	for a: Variant in s.get("areas", []):
		taken[String((a as Dictionary).get("id", ""))] = true
	while taken.has("a" + str(n)):
		n += 1
	return "a" + str(n)


static func has_include(s: Dictionary) -> bool:
	for a: Variant in s.get("areas", []):
		if not bool((a as Dictionary).get("leave_out", false)):
			return true
	return false

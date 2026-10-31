extends RefCounted

const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ViewMap := preload("res://doc/view_map.gd")
const ViewOffsets := preload("res://doc/view_offsets.gd")
const MARKS_KEY := "sync_marks"
const FOLLOW_KEY := "marks_follow"
const SNAP_GAP := 0.0005
const SAME_MARK := 0.02
const MATCH_RATE := 200.0
const MATCH_HALF := 4.0
const MATCH_REACH := 2.0

static var plant_flip: bool = false


static func marks_of(e: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Variant = (e.get("params", {}) as Dictionary).get(MARKS_KEY, null)
	var text: String = String(AnimProp.static_value(raw)) if raw is Dictionary else ""
	if text.strip_edges().is_empty():
		return out
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Array):
		return out
	for m: Variant in parsed:
		if m is Dictionary and (m as Dictionary).has("v") and (m as Dictionary).has("t"):
			out.append({"v": int((m as Dictionary)["v"]), "t": float((m as Dictionary)["t"]), "o": float((m as Dictionary).get("o", 0.0))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	return out


static func marks_text(list: Array[Dictionary]) -> String:
	var plain: Array = []
	for m: Dictionary in list:
		plain.append({"v": int(m["v"]), "t": snappedf(float(m["t"]), 0.000001), "o": snappedf(float(m["o"]), 0.000001)})
	return JSON.stringify(plain)


static func follows(e: Dictionary) -> bool:
	var raw: Variant = (e.get("params", {}) as Dictionary).get(FOLLOW_KEY, null)
	return bool(AnimProp.static_value(raw)) if raw is Dictionary else false


static func with_mark(list: Array[Dictionary], v: int, t: float, o: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var replaced: bool = false
	for m: Dictionary in list:
		if int(m["v"]) == v and absf(float(m["t"]) - t) < SAME_MARK:
			replaced = true
			continue
		out.append(m)
	if not replaced:
		out.append({"v": v, "t": t, "o": o})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	return out


static func of_view(list: Array[Dictionary], v: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Dictionary in list:
		if int(m["v"]) == v:
			out.append(m)
	return out


static func shown_at(m: Dictionary, e: Dictionary, video: Clip, speed: float) -> float:
	if video == null:
		return float(m["t"])
	var t: float = float(m["t"])
	var now: float = ViewMap.offset_at(e, int(m["v"]), video, t - video.start)
	return t + (now - float(m["o"])) / maxf(absf(speed), 0.00001)


static func reference_view(list: Array[Dictionary]) -> int:
	return -1 if list.is_empty() else int(list[0]["v"])


static func pairs(list: Array[Dictionary], e: Dictionary, video: Clip, speed: float, ref: int, v: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var a: Array[Dictionary] = of_view(list, ref)
	var b: Array[Dictionary] = of_view(list, v)
	var n: int = mini(a.size(), b.size())
	for i: int in n:
		var ta: float = shown_at(a[i], e, video, speed)
		var tb: float = shown_at(b[i], e, video, speed)
		var ob: float = ViewMap.offset_at(e, v, video, ta - video.start)
		var need: float = ViewMap.clamp_offset(ob + (tb - ta if plant_flip else ta - tb) * absf(speed))
		out.append({"t": ta, "need": need})
	return out


static func lined_prop(e: Dictionary, video: Clip, list: Array[Dictionary]) -> Dictionary:
	if list.is_empty() or video == null:
		return {}
	if list.size() == 1:
		return AnimProp.make(float(list[0]["need"]))
	var keys: Array = []
	var follow: bool = follows(e)
	var cuts: Array[Dictionary] = ViewOffsets.cuts_of(e, video)
	var last_cut: int = -1
	var last_need: float = 0.0
	for p: Dictionary in list:
		var u: float = clampf(float(p["t"]) - video.start, 0.0, maxf(video.duration, 0.0))
		var need: float = float(p["need"])
		var ci: int = ViewOffsets.cut_index_at(cuts, u)
		if not follow and last_cut >= 0 and ci != last_cut and ci >= 0 and ci < cuts.size():
			var u0: float = float(cuts[ci]["u0"])
			if u0 - SNAP_GAP > float((keys.back() as Dictionary)["t"]):
				keys.append({"t": u0 - SNAP_GAP, "v": last_need, "i": "linear"})
			if u0 < u - SNAP_GAP:
				keys.append({"t": u0, "v": need, "i": "linear"})
		keys.append({"t": u, "v": need, "i": "linear"})
		last_cut = ci
		last_need = need
	var clean: Array = []
	for k: Dictionary in keys:
		if not clean.is_empty() and absf(float(k["t"]) - float((clean.back() as Dictionary)["t"])) < AnimProp.KEY_TOLERANCE:
			clean[clean.size() - 1] = k
		else:
			clean.append(k)
	return {"a": true, "base": float((clean[0] as Dictionary)["v"]), "layers": [{"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": "once", "keys": clean}]}


static func best_lag(a: PackedFloat32Array, b: PackedFloat32Array, reach: int) -> Dictionary:
	var n: int = a.size()
	if n == 0 or b.size() != n + reach * 2:
		return {"lag": 0, "score": 0.0}
	var mean_a: float = 0.0
	for x: float in a:
		mean_a += x
	mean_a /= float(n)
	var energy_a: float = 0.0
	var ca: PackedFloat32Array = PackedFloat32Array()
	ca.resize(n)
	for i: int in n:
		ca[i] = a[i] - mean_a
		energy_a += ca[i] * ca[i]
	var best: float = -INF
	var best_k: int = 0
	for k: int in range(-reach, reach + 1):
		var start: int = reach + k
		var mean_b: float = 0.0
		for i2: int in n:
			mean_b += b[start + i2]
		mean_b /= float(n)
		var dot: float = 0.0
		var energy_b: float = 0.0
		for i3: int in n:
			var vb: float = b[start + i3] - mean_b
			dot += ca[i3] * vb
			energy_b += vb * vb
		var score: float = dot / sqrt(maxf(energy_a * energy_b, 0.000000001))
		if score > best:
			best = score
			best_k = k
	return {"lag": best_k, "score": best}

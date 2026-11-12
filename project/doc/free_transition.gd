extends RefCounted

const KEY_ID := "id"
const KEY_START := "start"
const KEY_DURATION := "duration"
const KEY_SPEC := "spec"
const FIELD := "free_transitions"
const PARAMS := "params"
const MIN_DURATION := 0.04
const ID_PREFIX := "ft"
const EPS := 0.00001


static func make(ft_id: String, start: float, duration: float, spec: Dictionary) -> Dictionary:
	return {
		KEY_ID: ft_id,
		KEY_START: maxf(start, 0.0),
		KEY_DURATION: maxf(duration, MIN_DURATION),
		KEY_SPEC: spec.duplicate(true),
	}


static func normalised(raw: Variant, fallback_id: String = "") -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	var ft_id: String = String(d.get(KEY_ID, "")).strip_edges()
	if ft_id.is_empty():
		ft_id = fallback_id
	if ft_id.is_empty():
		return {}
	var spec: Dictionary = (d[KEY_SPEC] as Dictionary).duplicate(true) if d.get(KEY_SPEC) is Dictionary else {}
	if spec.is_empty():
		return {}
	var start: float = float(d.get(KEY_START, 0.0)) if (d.get(KEY_START) is float or d.get(KEY_START) is int) else 0.0
	var dur: float = float(d.get(KEY_DURATION, MIN_DURATION)) if (d.get(KEY_DURATION) is float or d.get(KEY_DURATION) is int) else MIN_DURATION
	var out: Dictionary = d.duplicate(true)
	out[KEY_ID] = ft_id
	out[KEY_START] = maxf(start, 0.0)
	out[KEY_DURATION] = maxf(dur, MIN_DURATION)
	out[KEY_SPEC] = spec
	return out


static func normalise_list(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (raw is Array):
		return out
	var seen: Dictionary = {}
	var n: int = 0
	for item: Variant in raw as Array:
		var ft: Dictionary = normalised(item, ID_PREFIX + "_" + str(n))
		n += 1
		if ft.is_empty() or seen.has(String(ft[KEY_ID])):
			continue
		seen[String(ft[KEY_ID])] = true
		out.append(ft)
	out.sort_custom(_by_start)
	return out


static func _by_start(a: Dictionary, b: Dictionary) -> bool:
	var sa: float = float(a.get(KEY_START, 0.0))
	var sb: float = float(b.get(KEY_START, 0.0))
	if sa == sb:
		return String(a.get(KEY_ID, "")) < String(b.get(KEY_ID, ""))
	return sa < sb


static func to_array(list: Array[Dictionary]) -> Array:
	var out: Array = []
	for ft: Dictionary in list:
		out.append(ft.duplicate(true))
	return out


static func id_of(ft: Dictionary) -> String:
	return String(ft.get(KEY_ID, ""))


static func start_of(ft: Dictionary) -> float:
	return float(ft.get(KEY_START, 0.0))


static func duration_of(ft: Dictionary) -> float:
	return maxf(float(ft.get(KEY_DURATION, MIN_DURATION)), MIN_DURATION)


static func span(ft: Dictionary) -> Vector2:
	if ft.is_empty():
		return Vector2(-1.0, -1.0)
	var s: float = start_of(ft)
	return Vector2(s, s + duration_of(ft))


static func spec_of(ft: Dictionary) -> Dictionary:
	var v: Variant = ft.get(KEY_SPEC, null)
	return v if v is Dictionary else {}


static func covers(ft: Dictionary, t: float) -> bool:
	if ft.is_empty():
		return false
	var w: Vector2 = span(ft)
	return t >= w.x - EPS and t < w.y


static func touches(ft: Dictionary, t: float) -> bool:
	if ft.is_empty():
		return false
	var w: Vector2 = span(ft)
	return t >= w.x - EPS and t <= w.y + EPS


static func active(list: Array[Dictionary], t: float) -> Dictionary:
	for ft: Dictionary in list:
		if covers(ft, t):
			return ft
	return {}


static func at_point(list: Array[Dictionary], t: float) -> Dictionary:
	for ft: Dictionary in list:
		if touches(ft, t):
			return ft
	return {}


static func by_id(list: Array[Dictionary], ft_id: String) -> Dictionary:
	for ft: Dictionary in list:
		if id_of(ft) == ft_id:
			return ft
	return {}


static func with_span(ft: Dictionary, start: float, duration: float) -> Dictionary:
	var out: Dictionary = ft.duplicate(true)
	out[KEY_START] = maxf(start, 0.0)
	out[KEY_DURATION] = maxf(duration, MIN_DURATION)
	return out


static func param_of(ft: Dictionary, key: String) -> Dictionary:
	var params: Variant = spec_of(ft).get(PARAMS, null)
	var v: Variant = (params as Dictionary).get(key, null) if params is Dictionary else null
	return v if v is Dictionary else {}


static func with_param(ft: Dictionary, key: String, anim: Dictionary) -> Dictionary:
	var out: Dictionary = ft.duplicate(true)
	var spec: Dictionary = out[KEY_SPEC] if out.get(KEY_SPEC) is Dictionary else {}
	if not (spec.get(PARAMS) is Dictionary):
		spec[PARAMS] = {}
	if anim.is_empty():
		(spec[PARAMS] as Dictionary).erase(key)
	else:
		(spec[PARAMS] as Dictionary)[key] = anim.duplicate(true)
	out[KEY_SPEC] = spec
	return out


static func put(list: Array[Dictionary], ft: Dictionary) -> Array[Dictionary]:
	var clean: Dictionary = normalised(ft)
	if clean.is_empty():
		return list.duplicate(true)
	var out: Array[Dictionary] = []
	var done: bool = false
	for old: Dictionary in list:
		if id_of(old) == id_of(clean):
			out.append(clean)
			done = true
		else:
			out.append(old.duplicate(true))
	if not done:
		out.append(clean)
	out.sort_custom(_by_start)
	return out


static func without(list: Array[Dictionary], ft_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for old: Dictionary in list:
		if id_of(old) != ft_id:
			out.append(old.duplicate(true))
	return out


static func fresh_id(list: Array[Dictionary], seed_text: String = "") -> String:
	var taken: Dictionary = {}
	for ft: Dictionary in list:
		taken[id_of(ft)] = true
	var n: int = list.size() + 1
	var base: String = ID_PREFIX + ("_" + seed_text if not seed_text.is_empty() else "")
	while taken.has(base + "_" + str(n)):
		n += 1
	return base + "_" + str(n)


static func overlaps(list: Array[Dictionary], start: float, duration: float, skip_id: String = "") -> bool:
	var t0: float = start
	var t1: float = start + maxf(duration, MIN_DURATION)
	for ft: Dictionary in list:
		if id_of(ft) == skip_id:
			continue
		var w: Vector2 = span(ft)
		if w.y > t0 + EPS and w.x < t1 - EPS:
			return true
	return false


static func free_room(list: Array[Dictionary], want: float, duration: float, skip_id: String = "") -> float:
	if not overlaps(list, want, duration, skip_id):
		return want
	var tries: Array[float] = []
	for ft: Dictionary in list:
		if id_of(ft) == skip_id:
			continue
		var w: Vector2 = span(ft)
		tries.append(w.y)
		tries.append(maxf(w.x - duration, 0.0))
	tries.sort_custom(func(a: float, b: float) -> bool: return absf(a - want) < absf(b - want))
	for at: float in tries:
		if not overlaps(list, at, duration, skip_id):
			return at
	return -1.0

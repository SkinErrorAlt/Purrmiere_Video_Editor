extends RefCounted

const VERSION := 1
const KEY_TOLERANCE := 0.0001
const INTERP_MODES := ["linear", "ease_in", "ease_out", "ease_both", "bezier", "continuous", "auto", "hold"]
const EASE_FAMILIES := ["sine", "quad", "cubic", "quart", "quint", "expo", "circ", "back", "elastic", "bounce", "spring"]
const LAYER_TYPES := ["keys", "noise", "wave", "expr", "driven"]
const HASH_SEED_MIX := -7046029254386353131
const HASH_MUL_A := -4658895280553007687
const HASH_MUL_B := -7723592293110705685
const MANTISSA_SCALE := 9007199254740992.0
const PREP_CACHE_MAX := 256
const PREP_BUCKET_MAX := 12
const EXPR_CACHE_MAX := 256
const EXPR_FUNCS := ["sin", "cos", "tan", "asin", "acos", "atan", "atan2", "sqrt", "abs", "floor", "ceil", "round", "min", "max", "clamp", "lerp", "pow", "exp", "log", "sign", "fract", "smoothstep", "step", "mod", "wrap"]
const EXPR_SLOTS := ["t", "dur", "value", "fps", "frame", "comp"]
const EXPR_CONSTS := {"pi": PI, "e": 2.718281828459045, "tau": TAU}
const EXPR_BINS := ["+", "-", "*", "/", "%", "^", "<", ">", "<=", ">=", "==", "!=", "&&", "||"]
const OP_NUM := 0
const OP_SLOT := 1
const OP_NEG := 2
const OP_NOT := 3
const OP_COND := 4
const OP_BIN := 5
const OP_CALL := 6
const SMOOTH_MODES := ["off", "average", "gauss"]
const DRIVEN_CURVES := ["linear", "ease_in", "ease_out", "ease_both"]
const SMOOTH_TAPS_MIN := 1
const SMOOTH_TAPS_MAX := 33
const EMPTY_WINDOW := Vector2(INF, -INF)
const OFFSET_FIELD := "offset"
const SPATIAL_KIND := "sp"
const SPATIAL_OUT := "sho"
const SPATIAL_IN := "shi"
const SPATIAL_LINEAR := "linear"
const SPATIAL_SMOOTH := "smooth"
const SPATIAL_BEZIER := "bezier"
const SPATIAL_CONTINUOUS := "continuous"
const SPATIAL_KINDS: PackedStringArray = ["linear", "smooth", "bezier", "continuous"]
const ARC_STEPS := 48
const ARC_CACHE_MAX := 1024
const CSPACE_KEY := "cspace"
const COLOUR_SPACES: PackedStringArray = ["rgb", "linear", "hsv", "hsv_long", "hsl", "oklab", "oklch"]
const COLOUR_SPACE_LABELS: PackedStringArray = ["RGB, straight between the two", "Linear light, as real light mixes", "Hue, the short way round the wheel", "Hue, the long way round the wheel", "Hue, lightness and saturation", "Perceptual (OKLab), even steps to the eye", "Perceptual hue (OKLCH), vivid in between"]
const CSPACE_CACHE_MAX := 256
static var _cspace_cache: Dictionary = {}

static var session_salt: int = 0
static var driver: Callable = Callable()
static var driver_scope: Object = null
static var _prep_cache: Dictionary = {}
static var _prep_count: int = 0
static var _expr_cache: Dictionary = {}
static var _arc_cache: Dictionary = {}


static func norm(v: Variant) -> Variant:
	if v is int:
		return float(v)
	if v is Vector2:
		var a: Vector2 = v
		return [a.x, a.y]
	if v is Vector3:
		var b: Vector3 = v
		return [b.x, b.y, b.z]
	if v is Color:
		var c: Color = v
		return [c.r, c.g, c.b, c.a]
	if v is Array:
		var out: Array = []
		for e: Variant in v:
			out.append(norm(e))
		return out
	return v


static func make(value: Variant) -> Dictionary:
	return {"v": norm(value)}


static func make_range(lo: float, hi: float, seed: int) -> Dictionary:
	var a: float = minf(lo, hi)
	var b: float = maxf(lo, hi)
	var u: float = unit(seed, 0) * 0.5 + 0.5
	return {"v": a + (b - a) * u, "rng": [a, b], "seed": seed}


static func is_range(p: Dictionary) -> bool:
	return not bool(p.get("a", false)) and p.has("rng")


static func range_of(p: Dictionary) -> Array:
	var r: Variant = p.get("rng", null)
	if r is Array and (r as Array).size() >= 2:
		return [float((r as Array)[0]), float((r as Array)[1])]
	return []


static func range_seed(p: Dictionary) -> int:
	return int(p.get("seed", 0))


static func rebake_range(p: Dictionary, new_seed: int) -> Dictionary:
	var r: Array = range_of(p)
	if r.is_empty():
		return p.duplicate(true)
	return make_range(r[0], r[1], new_seed)


static func set_range_bounds(p: Dictionary, lo: float, hi: float) -> Dictionary:
	return make_range(lo, hi, range_seed(p))


static func values_equal(a: Variant, b: Variant) -> bool:
	var na: Variant = norm(a)
	var nb: Variant = norm(b)
	if na is Array and nb is Array:
		var aa: Array = na
		var bb: Array = nb
		if aa.size() != bb.size():
			return false
		for i: int in aa.size():
			if not values_equal(aa[i], bb[i]):
				return false
		return true
	if (na is float or na is int) and (nb is float or nb is int):
		return absf(float(na) - float(nb)) <= 0.000001 * maxf(1.0, absf(float(na)))
	if typeof(na) != typeof(nb):
		return false
	return na == nb


static var plant_no_collapse: bool = false


static func autokey_next(base: Dictionary, local_t: float, value: Variant, dur: float, fps: float, interp: String = "") -> Dictionary:
	if not plant_no_collapse and not base.is_empty():
		var base_eval: Variant = evaluate(base, local_t, dur, fps)
		if values_equal(value, base_eval):
			return base
	var seed: Dictionary = base if not base.is_empty() else make(value)
	return set_key(seed, local_t, value, interp)


static func is_animated(p: Dictionary) -> bool:
	return bool(p.get("a", false))


static func static_value(p: Dictionary) -> Variant:
	if is_animated(p):
		return p.get("base", 0.0)
	return p.get("v", 0.0)


static func keys_layer_index(p: Dictionary) -> int:
	if not is_animated(p):
		return -1
	var layers: Array = p.get("layers", [])
	for i: int in layers.size():
		var l: Dictionary = layers[i]
		if str(l.get("type", "")) == "keys" and not bool(l.get(OFFSET_FIELD, false)):
			return i
	return -1


static func keys(p: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var li: int = keys_layer_index(p)
	if li < 0:
		return out
	var layer: Dictionary = p["layers"][li]
	for k: Variant in layer.get("keys", []):
		out.append((k as Dictionary).duplicate(true))
	return out


static func find_key(p: Dictionary, t: float) -> int:
	var li: int = keys_layer_index(p)
	if li < 0:
		return -1
	var ks: Array = p["layers"][li].get("keys", [])
	for i: int in ks.size():
		if absf(float(ks[i].get("t", 0.0)) - t) <= KEY_TOLERANCE:
			return i
	return -1


static func has_key_at(p: Dictionary, t: float) -> bool:
	return find_key(p, t) >= 0


static func _new_keys_layer() -> Dictionary:
	return {"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": "once", "keys": []}


static func is_discrete_value(v: Variant) -> bool:
	return v is bool or v is String or v is StringName


static func holds_only(p: Dictionary) -> bool:
	var ks: Array[Dictionary] = keys(p)
	if ks.is_empty():
		return false
	for k: Dictionary in ks:
		if str(k.get("i", "")) != "hold":
			return false
	return true


static func auto_interp(p: Dictionary, v: Variant) -> String:
	if is_discrete_value(v) or holds_only(p):
		return "hold"
	return "ease_both"


static func scale_times(p: Dictionary, factor: float) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	var li: int = keys_layer_index(out)
	if li < 0 or factor <= 0.0:
		return out
	for k: Variant in out["layers"][li].get("keys", []):
		var kd: Dictionary = k
		kd["t"] = float(kd.get("t", 0.0)) * factor
		for side: String in ["ho", "hi"]:
			if kd.get(side) is Array and (kd[side] as Array).size() >= 1:
				var h: Array = kd[side]
				h[0] = float(h[0]) * factor
	return out


static func set_key(p: Dictionary, t: float, v: Variant, interp: String = "") -> Dictionary:
	if interp.is_empty():
		interp = auto_interp(p, v)
	var out: Dictionary = p.duplicate(true)
	if not is_animated(out):
		out = {"a": true, "base": static_value(out), "layers": [_new_keys_layer()]}
	var li: int = keys_layer_index(out)
	if li < 0:
		out["layers"].insert(0, _new_keys_layer())
		li = 0
	var layer: Dictionary = out["layers"][li]
	var ks: Array = layer.get("keys", [])
	var nv: Variant = norm(v)
	for i: int in ks.size():
		var k: Dictionary = ks[i]
		if absf(float(k.get("t", 0.0)) - t) <= KEY_TOLERANCE:
			k["v"] = nv
			return out
	var key: Dictionary = {"t": float(t), "v": nv, "i": interp}
	var at: int = ks.size()
	for i: int in ks.size():
		if float(ks[i].get("t", 0.0)) > t:
			at = i
			break
	ks.insert(at, key)
	layer["keys"] = ks
	return out


static func set_key_fields(p: Dictionary, t: float, fields: Dictionary) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	var li: int = keys_layer_index(out)
	if li < 0:
		return out
	var ks: Array = out["layers"][li].get("keys", [])
	for k: Variant in ks:
		var kd: Dictionary = k
		if absf(float(kd.get("t", 0.0)) - t) <= KEY_TOLERANCE:
			for f: String in fields.keys():
				kd[f] = norm(fields[f])
	return out


static func remove_key(p: Dictionary, t: float) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	var li: int = keys_layer_index(out)
	if li < 0:
		return out
	var ks: Array = out["layers"][li].get("keys", [])
	for i: int in ks.size():
		if absf(float(ks[i].get("t", 0.0)) - t) <= KEY_TOLERANCE:
			ks.remove_at(i)
			break
	out["layers"][li]["keys"] = ks
	return simplify(out)


static func shift_keys(p: Dictionary, delta: float) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	var li: int = keys_layer_index(out)
	if li < 0:
		return out
	for k: Variant in out["layers"][li].get("keys", []):
		var kd: Dictionary = k
		kd["t"] = float(kd.get("t", 0.0)) + delta
	return out


static func add_layer(p: Dictionary, layer: Dictionary) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	if not is_animated(out):
		out = {"a": true, "base": static_value(out), "layers": []}
	out["layers"].append(layer.duplicate(true))
	return out


static func remove_layer(p: Dictionary, index: int) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	if not is_animated(out):
		return out
	var layers: Array = out["layers"]
	if index >= 0 and index < layers.size():
		layers.remove_at(index)
	return simplify(out)


static func modifier_indices(p: Dictionary) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if not is_animated(p):
		return out
	var layers: Array = p.get("layers", [])
	for i: int in layers.size():
		var kind: String = str((layers[i] as Dictionary).get("type", ""))
		if kind == "noise" or kind == "wave" or kind == "expr" or kind == "driven":
			out.append(i)
	return out


static func has_modifiers(p: Dictionary) -> bool:
	return not modifier_indices(p).is_empty()


static func new_noise_layer(amp: float = 1.0, freq: float = 2.0) -> Dictionary:
	return {"type": "noise", "on": true, "weight": 1.0, "blend": "add", "kind": "perlin", "amp": amp, "freq": freq, "oct": 3, "seed": randi() % 100000, "seed_mode": "fixed", "offset": 0.0}


static func new_wave_layer(amp: float = 1.0, freq: float = 1.0) -> Dictionary:
	return {"type": "wave", "on": true, "weight": 1.0, "blend": "add", "shape": "sine", "amp": amp, "freq": freq, "phase": 0.0, "duty": 0.5}


static func new_expr_layer(code: String = "value") -> Dictionary:
	return {"type": "expr", "on": true, "weight": 1.0, "blend": "over", "code": code}


static func new_driven_layer(clip_id: String = "", path: String = "") -> Dictionary:
	return {
		"type": "driven",
		"on": true,
		"weight": 1.0,
		"blend": "over",
		"src": new_driven_source(clip_id, path),
		"in_min": 0.0,
		"in_max": 1.0,
		"out_min": 0.0,
		"out_max": 1.0,
		"overshoot": false,
		"curve": "linear",
		"smooth": new_smooth(),
		"invert": false,
		"attack": 0.0,
		"release": 0.0,
		"hold": 0.0,
		"step": 0.0,
		"step_unit": "frames",
		"axis": -1,
	}


static func new_driven_source(clip_id: String = "", path: String = "") -> Dictionary:
	return {"clip": clip_id, "path": path, "comp": -1, "lead": 0.0, "src_start": 0.0, "dst_start": 0.0}


static func new_smooth() -> Dictionary:
	return {"mode": "off", "window": 0.2, "taps": 5, "centre": true}


static func driven_source(layer: Dictionary) -> Dictionary:
	var raw: Variant = layer.get("src", null)
	if raw is Dictionary:
		var d: Dictionary = raw
		var out: Dictionary = {
			"clip": str(d.get("clip", "")),
			"path": str(d.get("path", "")),
			"comp": int(d.get("comp", -1)),
			"lead": float(d.get("lead", 0.0)),
			"src_start": float(d.get("src_start", 0.0)),
			"dst_start": float(d.get("dst_start", 0.0)),
		}
		for k: Variant in d.keys():
			if not out.has(k):
				out[k] = d[k]
		if not out.has("kind"):
			out["kind"] = "value"
		return out
	var legacy: String = str(layer.get("source", ""))
	var cut: int = legacy.rfind("/")
	if cut <= 0:
		return new_driven_source("", legacy)
	return new_driven_source(legacy.substr(0, cut), legacy.substr(cut + 1))


static func driven_key(src: Dictionary) -> String:
	return str(src.get("clip", "")) + "|" + str(src.get("path", ""))


static func set_layer_field(p: Dictionary, index: int, key: String, value: Variant) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	if not is_animated(out):
		return out
	var layers: Array = out["layers"]
	if index >= 0 and index < layers.size():
		(layers[index] as Dictionary)[key] = value
	return out


static func _layer_live(l: Dictionary) -> bool:
	if not bool(l.get("on", true)):
		return false
	if str(l.get("type", "")) == "keys":
		return not (l.get("keys", []) as Array).is_empty()
	return true


static func simplify(p: Dictionary) -> Dictionary:
	if not is_animated(p):
		return p.duplicate(true)
	var live: bool = false
	for l: Variant in p.get("layers", []):
		if _layer_live(l):
			live = true
	if not live:
		return {"v": p.get("base", 0.0)}
	return p.duplicate(true)


static func evaluate_float(p: Dictionary, t: float, dur: float, fps: float = 0.0) -> float:
	var v: Variant = evaluate(p, t, dur, fps)
	if v is float or v is int:
		return float(v)
	if v is bool:
		return 1.0 if v else 0.0
	if v is Array and not (v as Array).is_empty():
		return float(v[0])
	return 0.0


static func evaluate_vec2(p: Dictionary, t: float, dur: float, fps: float = 0.0) -> Vector2:
	var v: Variant = evaluate(p, t, dur, fps)
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is float or v is int:
		return Vector2(float(v), float(v))
	return Vector2.ZERO


static func evaluate(p: Dictionary, t: float, dur: float, fps: float = 0.0) -> Variant:
	return _evaluate(p, t, dur, fps)


static func evaluate_full(p: Dictionary, t: float, dur: float, fps: float = 0.0) -> Variant:
	return _evaluate(p, t, dur, fps)


static func _component_count(p: Dictionary) -> int:
	var base: Variant = p.get("base", 0.0)
	if base is Array:
		return (base as Array).size()
	var li: int = keys_layer_index(p)
	if li >= 0:
		var ks: Array = p["layers"][li].get("keys", [])
		if not ks.is_empty():
			var v0: Variant = (ks[0] as Dictionary).get("v", 0.0)
			if v0 is Array:
				return (v0 as Array).size()
	return 0


static func _evaluate(p: Dictionary, t: float, dur: float, fps: float) -> Variant:
	if not is_animated(p):
		return p.get("v", 0.0)
	var base: Variant = p.get("base", 0.0)
	if base is bool or base is String:
		return _eval_discrete(p, t, base)
	var n: int = _component_count(p)
	if n == 0:
		return _eval_scalar(p, t, dur, fps, -1)
	if n >= 3 and n <= 4 and p.has(CSPACE_KEY):
		var cs: String = String(p[CSPACE_KEY])
		if cs == "rgb" or not COLOUR_SPACES.has(cs):
			cs = ""
		if cs.is_empty():
			var plain_out: Array = []
			for c3: int in n:
				plain_out.append(_eval_scalar(p, t, dur, fps, c3))
			return plain_out
		var q: Dictionary = _in_space(p, cs)
		var mixed: Array = []
		for c2: int in n:
			mixed.append(_eval_scalar(q, t, dur, fps, c2))
		return from_space(mixed, cs)
	var out: Array = []
	for c: int in n:
		out.append(_eval_scalar(p, t, dur, fps, c))
	return out


static func _eval_discrete(p: Dictionary, t: float, base: Variant) -> Variant:
	var li: int = keys_layer_index(p)
	if li < 0:
		return base
	var layer: Dictionary = p["layers"][li]
	if not bool(layer.get("on", true)):
		return base
	var ks: Array = _prepared_keys(layer.get("keys", []))
	if ks.is_empty():
		return base
	var i: int = _segment_index(ks, t)
	if i < 0:
		return (ks[0] as Dictionary).get("v", base)
	return (ks[i] as Dictionary).get("v", base)


static func _comp(v: Variant, c: int) -> float:
	if v is Array:
		var a: Array = v
		if a.is_empty():
			return 0.0
		if c >= 0 and c < a.size():
			return float(a[c])
		return float(a[0])
	if v is bool:
		return 1.0 if v else 0.0
	if v is float or v is int:
		return float(v)
	return 0.0


static func _eval_scalar(p: Dictionary, t: float, dur: float, fps: float, c: int) -> float:
	var value: float = _comp(p.get("base", 0.0), c)
	var keys_done: bool = false
	for l: Variant in p.get("layers", []):
		var layer: Dictionary = l
		if not bool(layer.get("on", true)):
			continue
		var kind: String = str(layer.get("type", ""))
		var cv: float = 0.0
		var default_blend: String = "over"
		if kind == "keys":
			var is_offset: bool = bool(layer.get(OFFSET_FIELD, false))
			if keys_done and not is_offset:
				continue
			if not is_offset:
				keys_done = true
			var ks: Array = _prepared_keys(layer.get("keys", []))
			if ks.is_empty():
				continue
			cv = _eval_keys(ks, str(layer.get("loop", "once")), t, c)
		elif kind == "noise":
			cv = _eval_noise(layer, t)
			default_blend = "add"
		elif kind == "wave":
			cv = _eval_wave(layer, t)
			default_blend = "add"
		elif kind == "expr":
			cv = _eval_expr_layer(layer, t, dur, value, fps, c)
		elif kind == "driven":
			var axis: int = int(layer.get("axis", -1))
			if axis >= 0 and c >= 0 and c != axis:
				continue
			var got: Dictionary = driven_sample(layer, t, fps)
			if not bool(got["ok"]):
				continue
			cv = driven_map(layer, float(got["raw"]), c, t, dur, fps) if got.has("raw") else float(got["v"])
			value = _blend(value, cv, str(layer.get("blend", default_blend)), driven_out(layer, "weight", 1.0, c, t, dur, fps))
			continue
		else:
			continue
		value = _blend(value, cv, str(layer.get("blend", default_blend)), float(layer.get("weight", 1.0)))
	return value


static func _blend(value: float, c: float, mode: String, w: float) -> float:
	if mode == "add":
		return value + c * w
	if mode == "multiply":
		return value + (value * c - value) * w
	return value + (c - value) * w


static func _keys_sorted_clean(ks: Array) -> bool:
	var prev: float = -INF
	for k: Variant in ks:
		if not (k is Dictionary):
			return false
		var t: float = float((k as Dictionary).get("t", 0.0))
		if t - prev < KEY_TOLERANCE:
			return false
		prev = t
	return true


static func _prepared_keys(ks: Array) -> Array:
	var n: int = ks.size()
	if n <= 1:
		if n == 1 and ks[0] is Dictionary:
			return ks
		return []
	var bucket: Array = _prep_cache.get(n, [])
	for bi: int in range(bucket.size() - 1, -1, -1):
		var pair: Array = bucket[bi]
		if is_same(pair[0], ks):
			return pair[1]
	var out: Array = ks
	if not _keys_sorted_clean(ks):
		out = []
		for k: Variant in ks:
			if k is Dictionary:
				out.append(k)
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))
		var clean: Array = []
		var prev: float = -INF
		for k: Dictionary in out:
			var t: float = float(k.get("t", 0.0))
			if t - prev < KEY_TOLERANCE:
				continue
			clean.append(k)
			prev = t
		out = clean
	if _prep_count >= PREP_CACHE_MAX:
		_prep_cache = {}
		_prep_count = 0
		bucket = []
	bucket.append([ks, out])
	if bucket.size() > PREP_BUCKET_MAX:
		bucket.remove_at(0)
	else:
		_prep_count += 1
	_prep_cache[n] = bucket
	return out


static func _segment_index(ks: Array, tt: float) -> int:
	var n: int = ks.size()
	if tt < float((ks[0] as Dictionary).get("t", 0.0)):
		return -1
	var lo: int = 0
	var hi: int = n - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if float((ks[mid] as Dictionary).get("t", 0.0)) <= tt:
			lo = mid
		else:
			hi = mid
	if n > 1 and tt >= float((ks[n - 1] as Dictionary).get("t", 0.0)):
		return n - 1
	return lo


static func _slope(ks: Array, i: int, j: int, c: int) -> float:
	var a: Dictionary = ks[i]
	var b: Dictionary = ks[j]
	var dt: float = float(b.get("t", 0.0)) - float(a.get("t", 0.0))
	if dt <= 0.0:
		return 0.0
	return (_comp(b.get("v", 0.0), c) - _comp(a.get("v", 0.0), c)) / dt


static func _eval_keys(ks: Array, loop: String, t: float, c: int) -> float:
	var n: int = ks.size()
	var first: Dictionary = ks[0]
	var last: Dictionary = ks[n - 1]
	if n == 1:
		return _comp(first.get("v", 0.0), c)
	var t0: float = float(first.get("t", 0.0))
	var t1: float = float(last.get("t", 0.0))
	var span: float = t1 - t0
	var tt: float = t
	if loop == "loop" and span > 0.0:
		var u: float = t - t0
		u = u - floor(u / span) * span
		tt = t0 + u
	elif loop == "pingpong" and span > 0.0:
		var p: float = 2.0 * span
		var u2: float = t - t0
		u2 = u2 - floor(u2 / p) * p
		if u2 > span:
			u2 = p - u2
		tt = t0 + u2
	elif loop == "continue":
		if t < t0:
			return _comp(first.get("v", 0.0), c) + (t - t0) * _slope(ks, 0, 1, c)
		if t > t1:
			return _comp(last.get("v", 0.0), c) + (t - t1) * _slope(ks, n - 2, n - 1, c)
	if tt < t0:
		return _comp(first.get("v", 0.0), c)
	if tt >= t1:
		return _comp(last.get("v", 0.0), c)
	var lo: int = 0
	var hi: int = n - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if float((ks[mid] as Dictionary).get("t", 0.0)) <= tt:
			lo = mid
		else:
			hi = mid
	if (c == 0 or c == 1) and seg_spatial(ks, lo):
		var sp: Vector2 = spatial_at(ks, lo, tt)
		return sp.x if c == 0 else sp.y
	return _eval_segment(ks, lo, tt, c)


static func _eval_segment(ks: Array, i: int, tt: float, c: int) -> float:
	var a: Dictionary = ks[i]
	var b: Dictionary = ks[i + 1]
	var ta: float = float(a.get("t", 0.0))
	var tb: float = float(b.get("t", 0.0))
	var va: float = _comp(a.get("v", 0.0), c)
	var vb: float = _comp(b.get("v", 0.0), c)
	var seg: float = tb - ta
	if seg <= 0.0:
		return va
	var mode: String = str(a.get("i", "linear"))
	if mode == "hold":
		return va
	var u: float = (tt - ta) / seg
	if mode == "linear":
		return va + (vb - va) * u
	if mode == "bezier":
		return _eval_bezier(a, b, va, vb, seg, tt, c)
	if mode == "continuous" or mode == "auto":
		return _eval_hermite(ks, i, va, vb, seg, u, mode == "auto", c)
	if mode == "ease_in" or mode == "ease_out" or mode == "ease_both":
		var dir: String = str(a.get("dir", ""))
		if dir.is_empty():
			if mode == "ease_in":
				dir = "in"
			elif mode == "ease_out":
				dir = "out"
			else:
				dir = "inout"
		return va + (vb - va) * ease_curve(str(a.get("ease", "cubic")), dir, u)
	return va + (vb - va) * u


static func _handle(k: Dictionary, name: String, seg: float, out_side: bool, c: int) -> Array:
	var dt: float = seg / 3.0 if out_side else -seg / 3.0
	var dv: float = 0.0
	if k.has(name) and k[name] is Array and (k[name] as Array).size() >= 2:
		var h: Array = k[name]
		dt = float(h[0])
		dv = _comp(norm(h[1]), c)
	if out_side:
		dt = clampf(dt, 0.0, seg)
	else:
		dt = clampf(dt, -seg, 0.0)
	return [dt, dv]


static func _eval_bezier(a: Dictionary, b: Dictionary, va: float, vb: float, seg: float, tt: float, c: int) -> float:
	var ta: float = float(a.get("t", 0.0))
	var tb: float = float(b.get("t", 0.0))
	var ho: Array = _handle(a, "ho", seg, true, c)
	var hi: Array = _handle(b, "hi", seg, false, c)
	var x0: float = ta
	var x1: float = ta + float(ho[0])
	var x2: float = tb + float(hi[0])
	var x3: float = tb
	var y0: float = va
	var y1: float = va + float(ho[1])
	var y2: float = vb + float(hi[1])
	var y3: float = vb
	var lo: float = 0.0
	var hi_s: float = 1.0
	for _i: int in 40:
		var mid: float = (lo + hi_s) * 0.5
		if _bez1(x0, x1, x2, x3, mid) < tt:
			lo = mid
		else:
			hi_s = mid
	var s: float = (lo + hi_s) * 0.5
	return _bez1(y0, y1, y2, y3, s)


static func _bez1(p0: float, p1: float, p2: float, p3: float, s: float) -> float:
	var r: float = 1.0 - s
	return r * r * r * p0 + 3.0 * r * r * s * p1 + 3.0 * r * s * s * p2 + s * s * s * p3


static func _tangent(ks: Array, j: int, auto: bool, c: int) -> float:
	var n: int = ks.size()
	if j <= 0:
		return _slope(ks, 0, 1, c)
	if j >= n - 1:
		return _slope(ks, n - 2, n - 1, c)
	if auto:
		var vp: float = _comp((ks[j - 1] as Dictionary).get("v", 0.0), c)
		var vj: float = _comp((ks[j] as Dictionary).get("v", 0.0), c)
		var vn: float = _comp((ks[j + 1] as Dictionary).get("v", 0.0), c)
		if (vj - vp) * (vn - vj) <= 0.0:
			return 0.0
	return _slope(ks, j - 1, j + 1, c)


static func _eval_hermite(ks: Array, i: int, va: float, vb: float, seg: float, u: float, auto: bool, c: int) -> float:
	var m0: float = _tangent(ks, i, auto, c)
	var m1: float = _tangent(ks, i + 1, auto, c)
	var u2: float = u * u
	var u3: float = u2 * u
	var h00: float = 2.0 * u3 - 3.0 * u2 + 1.0
	var h10: float = u3 - 2.0 * u2 + u
	var h01: float = -2.0 * u3 + 3.0 * u2
	var h11: float = u3 - u2
	return h00 * va + h10 * seg * m0 + h01 * vb + h11 * seg * m1


static func key_spatial(k: Dictionary) -> bool:
	return k.has(SPATIAL_KIND) or k.get(SPATIAL_OUT) is Array or k.get(SPATIAL_IN) is Array


static func _pair(v: Variant) -> bool:
	return v is Array and (v as Array).size() == 2


static func vec_of(v: Variant) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Vector2:
		return v
	return Vector2.ZERO


static func seg_spatial(ks: Array, i: int) -> bool:
	if i < 0 or i + 1 >= ks.size():
		return false
	var a: Dictionary = ks[i]
	var b: Dictionary = ks[i + 1]
	if not (key_spatial(a) or key_spatial(b)):
		return false
	return _pair(a.get("v", 0.0)) and _pair(b.get("v", 0.0))


static func spatial_kind(k: Dictionary) -> String:
	return str(k.get(SPATIAL_KIND, ""))


static func auto_tangents(ks: Array, j: int) -> PackedVector2Array:
	var n: int = ks.size()
	var p: Vector2 = vec_of((ks[j] as Dictionary).get("v", 0.0))
	if n < 2:
		return PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	if j == 0:
		var nx: Vector2 = vec_of((ks[1] as Dictionary).get("v", 0.0))
		return PackedVector2Array([Vector2.ZERO, (nx - p) / 3.0])
	if j == n - 1:
		var pv: Vector2 = vec_of((ks[n - 2] as Dictionary).get("v", 0.0))
		return PackedVector2Array([(pv - p) / 3.0, Vector2.ZERO])
	var prev: Vector2 = vec_of((ks[j - 1] as Dictionary).get("v", 0.0))
	var next: Vector2 = vec_of((ks[j + 1] as Dictionary).get("v", 0.0))
	var dir: Vector2 = (next - prev).normalized()
	return PackedVector2Array([-dir * p.distance_to(prev) / 3.0, dir * p.distance_to(next) / 3.0])


static func spatial_out(ks: Array, i: int) -> Vector2:
	var k: Dictionary = ks[i]
	var kind: String = spatial_kind(k)
	if kind == SPATIAL_LINEAR:
		return Vector2.ZERO
	if kind == SPATIAL_SMOOTH:
		return auto_tangents(ks, i)[1]
	if k.get(SPATIAL_OUT) is Array:
		return vec_of(k[SPATIAL_OUT])
	return Vector2.ZERO


static func spatial_in(ks: Array, i: int) -> Vector2:
	var k: Dictionary = ks[i]
	var kind: String = spatial_kind(k)
	if kind == SPATIAL_LINEAR:
		return Vector2.ZERO
	if kind == SPATIAL_SMOOTH:
		return auto_tangents(ks, i)[0]
	if k.get(SPATIAL_IN) is Array:
		return vec_of(k[SPATIAL_IN])
	return Vector2.ZERO


static func seg_controls(ks: Array, i: int) -> PackedVector2Array:
	var p0: Vector2 = vec_of((ks[i] as Dictionary).get("v", 0.0))
	var p3: Vector2 = vec_of((ks[i + 1] as Dictionary).get("v", 0.0))
	return PackedVector2Array([p0, p0 + spatial_out(ks, i), p3 + spatial_in(ks, i + 1), p3])


static func bez2(cp: PackedVector2Array, s: float) -> Vector2:
	var r: float = 1.0 - s
	return cp[0] * (r * r * r) + cp[1] * (3.0 * r * r * s) + cp[2] * (3.0 * r * s * s) + cp[3] * (s * s * s)


static func arc_table(cp: PackedVector2Array) -> PackedFloat64Array:
	var sig: int = [cp[0], cp[1], cp[2], cp[3]].hash()
	var hit: Variant = _arc_cache.get(sig, null)
	if hit is PackedFloat64Array:
		return hit
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(ARC_STEPS + 1)
	out[0] = 0.0
	var prev: Vector2 = cp[0]
	var run: float = 0.0
	for j: int in range(1, ARC_STEPS + 1):
		var here: Vector2 = bez2(cp, float(j) / float(ARC_STEPS))
		run += prev.distance_to(here)
		out[j] = run
		prev = here
	if _arc_cache.size() >= ARC_CACHE_MAX:
		_arc_cache = {}
	_arc_cache[sig] = out
	return out


static func param_at_length(table: PackedFloat64Array, d: float) -> float:
	var total: float = table[ARC_STEPS]
	if total <= 0.0:
		return 0.0
	var lo: int = 0
	var hi: int = ARC_STEPS
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if table[mid] <= d:
			lo = mid
		else:
			hi = mid
	var span: float = table[hi] - table[lo]
	var f: float = 0.0 if span <= 0.0 else (d - table[lo]) / span
	return (float(lo) + clampf(f, 0.0, 1.0)) / float(ARC_STEPS)


static func point_at_length(cp: PackedVector2Array, table: PackedFloat64Array, d: float) -> Vector2:
	var total: float = table[ARC_STEPS]
	if total <= 0.0:
		return cp[0]
	if cp[1].is_equal_approx(cp[0]) and cp[2].is_equal_approx(cp[3]):
		return cp[0] + (cp[3] - cp[0]) * (d / total)
	if d <= 0.0:
		var a: Vector2 = (bez2(cp, 1.0 / float(ARC_STEPS)) - cp[0]).normalized()
		return cp[0] + a * d
	if d >= total:
		var b: Vector2 = (cp[3] - bez2(cp, 1.0 - 1.0 / float(ARC_STEPS))).normalized()
		return cp[3] + b * (d - total)
	return bez2(cp, param_at_length(table, d))


static func seg_length(ks: Array, i: int) -> float:
	if i < 0 or i + 1 >= ks.size():
		return 0.0
	if seg_spatial(ks, i):
		return arc_table(seg_controls(ks, i))[ARC_STEPS]
	var a: Variant = (ks[i] as Dictionary).get("v", 0.0)
	var b: Variant = (ks[i + 1] as Dictionary).get("v", 0.0)
	if _pair(a) and _pair(b):
		return vec_of(a).distance_to(vec_of(b))
	return absf(_comp(b, 0) - _comp(a, 0))


static func _along(h: Variant, chord: Vector2) -> float:
	if h is Array and (h as Array).size() >= 2:
		var dir: Vector2 = chord.normalized()
		return Vector2(float(h[0]), float(h[1])).dot(dir)
	if h is float or h is int:
		return float(h)
	return 0.0


static func spatial_travel(ks: Array, i: int, tt: float, total: float) -> float:
	var a: Dictionary = ks[i]
	var b: Dictionary = ks[i + 1]
	var ta: float = float(a.get("t", 0.0))
	var tb: float = float(b.get("t", 0.0))
	var seg: float = tb - ta
	if seg <= 0.0:
		return 0.0
	var mode: String = str(a.get("i", "linear"))
	if mode == "hold":
		return 0.0
	var u: float = (tt - ta) / seg
	if mode == "linear":
		return total * u
	if mode == "ease_in" or mode == "ease_out" or mode == "ease_both":
		var dir: String = str(a.get("dir", ""))
		if dir.is_empty():
			if mode == "ease_in":
				dir = "in"
			elif mode == "ease_out":
				dir = "out"
			else:
				dir = "inout"
		return total * ease_curve(str(a.get("ease", "cubic")), dir, u)
	if mode == "bezier":
		var chord: Vector2 = vec_of(b.get("v", 0.0)) - vec_of(a.get("v", 0.0))
		var dto: float = seg / 3.0
		var dvo: float = 0.0
		if a.get("ho") is Array and (a["ho"] as Array).size() >= 2:
			dto = float(a["ho"][0])
			dvo = _along(a["ho"][1], chord)
		var dti: float = -seg / 3.0
		var dvi: float = 0.0
		if b.get("hi") is Array and (b["hi"] as Array).size() >= 2:
			dti = float(b["hi"][0])
			dvi = _along(b["hi"][1], chord)
		dto = clampf(dto, 0.0, seg)
		dti = clampf(dti, -seg, 0.0)
		var lo: float = 0.0
		var hi_s: float = 1.0
		for _j: int in 40:
			var mid: float = (lo + hi_s) * 0.5
			if _bez1(ta, ta + dto, tb + dti, tb, mid) < tt:
				lo = mid
			else:
				hi_s = mid
		return _bez1(0.0, dvo, total + dvi, total, (lo + hi_s) * 0.5)
	if mode == "continuous" or mode == "auto":
		var n: int = ks.size()
		var m0: float = total / seg
		if i > 0:
			var before: float = seg_length(ks, i - 1)
			var span0: float = tb - float((ks[i - 1] as Dictionary).get("t", 0.0))
			m0 = (before + total) / span0 if span0 > 0.0 else 0.0
			if mode == "auto" and before * total <= 0.0:
				m0 = 0.0
		var m1: float = total / seg
		if i + 2 < n:
			var after: float = seg_length(ks, i + 1)
			var span1: float = float((ks[i + 2] as Dictionary).get("t", 0.0)) - ta
			m1 = (total + after) / span1 if span1 > 0.0 else 0.0
			if mode == "auto" and total * after <= 0.0:
				m1 = 0.0
		var u2: float = u * u
		var u3: float = u2 * u
		return (u3 - 2.0 * u2 + u) * seg * m0 + (-2.0 * u3 + 3.0 * u2) * total + (u3 - u2) * seg * m1
	return total * u


static func spatial_at(ks: Array, i: int, tt: float) -> Vector2:
	var cp: PackedVector2Array = seg_controls(ks, i)
	var table: PackedFloat64Array = arc_table(cp)
	return point_at_length(cp, table, spatial_travel(ks, i, tt, table[ARC_STEPS]))


static func ease_curve(family: String, dir: String, u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	if dir == "in":
		return ease_in(family, u)
	if dir == "out":
		return 1.0 - ease_in(family, 1.0 - u)
	if dir == "outin":
		if u < 0.5:
			return (1.0 - ease_in(family, 1.0 - 2.0 * u)) * 0.5
		return 0.5 + ease_in(family, 2.0 * u - 1.0) * 0.5
	if u < 0.5:
		return ease_in(family, 2.0 * u) * 0.5
	return 1.0 - ease_in(family, 2.0 - 2.0 * u) * 0.5


static func ease_in(family: String, u: float) -> float:
	if family == "sine":
		return 1.0 - cos(u * PI * 0.5)
	if family == "quad":
		return u * u
	if family == "quart":
		return u * u * u * u
	if family == "quint":
		return u * u * u * u * u
	if family == "expo":
		return 0.0 if u <= 0.0 else pow(2.0, 10.0 * u - 10.0)
	if family == "circ":
		return 1.0 - sqrt(1.0 - u * u)
	if family == "back":
		var c1: float = 1.70158
		var c3: float = c1 + 1.0
		return c3 * u * u * u - c1 * u * u
	if family == "elastic":
		if u <= 0.0:
			return 0.0
		if u >= 1.0:
			return 1.0
		return -(pow(2.0, 10.0 * u - 10.0)) * sin((10.0 * u - 10.75) * 2.0 * PI / 3.0)
	if family == "bounce":
		return 1.0 - bounce_out(1.0 - u)
	if family == "spring":
		return 1.0 - spring_out(1.0 - u)
	return u * u * u


static func bounce_out(x: float) -> float:
	var n1: float = 7.5625
	var d1: float = 2.75
	if x < 1.0 / d1:
		return n1 * x * x
	if x < 2.0 / d1:
		var a: float = x - 1.5 / d1
		return n1 * a * a + 0.75
	if x < 2.5 / d1:
		var b: float = x - 2.25 / d1
		return n1 * b * b + 0.9375
	var c: float = x - 2.625 / d1
	return n1 * c * c + 0.984375


static func spring_out(x: float) -> float:
	return 1.0 - (1.0 - x) * exp(-4.0 * x) * cos(3.0 * PI * x)


static func _lsr(h: int, n: int) -> int:
	return (h >> n) & ((1 << (64 - n)) - 1)


static func hash64(seed: int, step: int) -> int:
	var h: int = seed ^ HASH_SEED_MIX
	h = h ^ (step * HASH_MUL_A)
	h = h ^ _lsr(h, 30)
	h = h * HASH_MUL_A
	h = h ^ _lsr(h, 27)
	h = h * HASH_MUL_B
	h = h ^ _lsr(h, 31)
	return h


static func unit(seed: int, step: int) -> float:
	return float(_lsr(hash64(seed, step), 11)) * (1.0 / MANTISSA_SCALE) * 2.0 - 1.0


static func _value_noise(seed: int, x: float) -> float:
	var i: int = int(floor(x))
	var f: float = x - float(i)
	var s: float = f * f * (3.0 - 2.0 * f)
	var a: float = unit(seed, i)
	var b: float = unit(seed, i + 1)
	return a + (b - a) * s


static func noise_sample(kind: String, tn: float, freq: float, seed: int, oct: int) -> float:
	var x: float = tn * freq
	var i: int = int(floor(x))
	var f: float = x - float(i)
	if kind == "white":
		return unit(seed, i)
	if kind == "perlin" or kind == "simplex":
		var g0: float = unit(seed, i)
		var g1: float = unit(seed, i + 1)
		var n0: float = g0 * f
		var n1: float = g1 * (f - 1.0)
		var s: float = f * f * f * (f * (f * 6.0 - 15.0) + 10.0)
		return 2.0 * (n0 + (n1 - n0) * s)
	if kind == "fractal":
		var sum: float = 0.0
		var norm_total: float = 0.0
		var a: float = 1.0
		var fr: float = freq
		for o: int in clampi(oct, 1, 8):
			sum = sum + a * _value_noise(seed + o, tn * fr)
			norm_total = norm_total + a
			a = a * 0.5
			fr = fr * 2.0
		return sum / norm_total
	if kind == "brownian":
		var k: int = int(floor(x))
		if k < 1:
			return 0.0
		var s2: float = 0.0
		for j: int in range(1, k + 1):
			s2 = s2 + unit(seed, j)
		return clampf(s2 / sqrt(float(k)), -1.0, 1.0)
	return _value_noise(seed, x)


static func _eval_noise(layer: Dictionary, t: float) -> float:
	var kind: String = str(layer.get("kind", "value"))
	var amp: float = float(layer.get("amp", 1.0))
	var freq: float = float(layer.get("freq", 1.0))
	var oct: int = int(layer.get("oct", 4))
	var seed: int = int(layer.get("seed", 0))
	if str(layer.get("seed_mode", "fixed")) == "session":
		seed = seed ^ session_salt
	var tn: float = t + float(layer.get("offset", 0.0))
	return amp * noise_sample(kind, tn, freq, seed, oct)


static func wave_sample(shape: String, ph: float, duty: float) -> float:
	var u: float = ph - floor(ph)
	if shape == "triangle":
		return 1.0 - 4.0 * absf(u - 0.5)
	if shape == "square":
		return 1.0 if u < duty else -1.0
	if shape == "saw":
		return 2.0 * u - 1.0
	return sin(2.0 * PI * u)


static func _eval_wave(layer: Dictionary, t: float) -> float:
	var amp: float = float(layer.get("amp", 1.0))
	var freq: float = float(layer.get("freq", 1.0))
	var phase: float = float(layer.get("phase", 0.0))
	var duty: float = float(layer.get("duty", 0.5))
	return amp * wave_sample(str(layer.get("shape", "sine")), t * freq + phase, duty)


static func smooth_taps(layer: Dictionary) -> Array:
	var raw: Variant = layer.get("smooth", null)
	var mode: String = "off"
	var window: float = 0.0
	var taps: int = 1
	var centre: bool = true
	if raw is Dictionary:
		var s: Dictionary = raw
		mode = str(s.get("mode", "off"))
		window = maxf(float(s.get("window", 0.0)), 0.0)
		taps = clampi(int(s.get("taps", 5)), SMOOTH_TAPS_MIN, SMOOTH_TAPS_MAX)
		centre = bool(s.get("centre", true))
	if mode == "off" or window <= 0.0 or taps <= 1:
		return [PackedFloat64Array([0.0]), PackedFloat64Array([1.0])]
	if taps % 2 == 0:
		taps += 1
	var offsets: PackedFloat64Array = PackedFloat64Array()
	var weights: PackedFloat64Array = PackedFloat64Array()
	var half: float = window * 0.5
	var total: float = 0.0
	var last: int = taps - 1
	for i: int in taps:
		var u: float = float(i) / float(last)
		var off: float = (u * 2.0 - 1.0) * half if centre else (u - 1.0) * window
		var w: float = 1.0
		if mode == "gauss":
			var x: float = (u * 2.0 - 1.0) * 2.0
			w = exp(-0.5 * x * x)
		offsets.append(off)
		weights.append(w)
		total += w
	if total <= 0.0:
		return [PackedFloat64Array([0.0]), PackedFloat64Array([1.0])]
	for i: int in weights.size():
		weights[i] = weights[i] / total
	return [offsets, weights]


static func driven_in(layer: Dictionary, key: String, fallback: float) -> float:
	var v: Variant = layer.get(key, fallback)
	if v is Dictionary:
		return _comp(static_value(v), 0)
	return _comp(v, 0)


static func driven_out(layer: Dictionary, key: String, fallback: float, c: int, t: float, dur: float, fps: float) -> float:
	var v: Variant = layer.get(key, fallback)
	if v is Dictionary:
		v = evaluate(v, t, dur, fps)
	if v is Array:
		var a: Array = v
		if a.is_empty():
			return fallback
		return float(a[c]) if c >= 0 and c < a.size() else float(a[0])
	return _comp(v, c)


static func driven_extended(layer: Dictionary) -> bool:
	if str(driven_source(layer).get("kind", "value")) != "value":
		return true
	if layer.has("recorded") or not str(layer.get("rec_id", "")).is_empty():
		return true
	if bool(layer.get("invert", false)) or int(layer.get("axis", -1)) >= 0:
		return true
	for k: String in ["attack", "release", "hold", "step"]:
		if float(layer.get(k, 0.0)) > 0.0:
			return true
	for k2: String in ["out_min", "out_max", "in_min", "in_max", "weight"]:
		var v: Variant = layer.get(k2, 0.0)
		if v is Dictionary or v is Array:
			return true
	return false


static func driven_map(layer: Dictionary, raw: float, c: int = -1, t: float = 0.0, dur: float = 0.0, fps: float = 0.0) -> float:
	var in_min: float = driven_in(layer, "in_min", 0.0)
	var in_max: float = driven_in(layer, "in_max", 1.0)
	var out_min: float = driven_out(layer, "out_min", 0.0, c, t, dur, fps)
	var out_max: float = driven_out(layer, "out_max", 1.0, c, t, dur, fps)
	var overshoot: bool = bool(layer.get("overshoot", false))
	var span: float = in_max - in_min
	var u: float = 0.0 if absf(span) <= 0.0 else (raw - in_min) / span
	if not overshoot:
		u = clampf(u, 0.0, 1.0)
	if bool(layer.get("invert", false)):
		u = 1.0 - u
	var curve: String = str(layer.get("curve", "linear"))
	if curve != "linear" and u >= 0.0 and u <= 1.0:
		var dir: String = "in"
		if curve == "ease_out":
			dir = "out"
		elif curve == "ease_both":
			dir = "inout"
		u = ease_curve(str(layer.get("ease", "cubic")), dir, u)
	return out_min + (out_max - out_min) * u


static func driven_sample(layer: Dictionary, t: float, fps: float) -> Dictionary:
	if driver_scope != null:
		return driver_scope.call("driven_raw", layer, t, fps)
	if not driver.is_valid():
		return {"ok": false, "v": 0.0}
	var legacy: float = float(driver.call(str(layer.get("source", "")), t))
	if layer.has("src") or layer.has("in_min") or layer.has("out_min"):
		return {"ok": true, "v": driven_map(layer, legacy)}
	return {"ok": true, "v": legacy * float(layer.get("scale", 1.0)) + float(layer.get("offset", 0.0))}


static func _eval_expr_layer(layer: Dictionary, t: float, dur: float, value: float, fps: float, c: int) -> float:
	var prog: Dictionary = expr_program(str(layer.get("code", "")))
	if not bool(prog["fast"]):
		return value
	var out: float = _run(prog["node"], t, dur, value, fps, t * fps, float(maxi(c, 0)))
	if is_nan(out) or is_inf(out):
		return value
	return out


static func expr_parse(code: String) -> Dictionary:
	return expr_program(code)


static func expr_program(code: String) -> Dictionary:
	var hit: Variant = _expr_cache.get(code, null)
	if hit is Dictionary:
		return hit
	var tokens: Array = _tokenize(code)
	var result: Dictionary = {"ok": false, "error": "", "tree": [], "node": [], "fast": false}
	if tokens.is_empty():
		result["error"] = "empty expression"
	elif (tokens[tokens.size() - 1] as Dictionary).get("k", "") == "err":
		result["error"] = str((tokens[tokens.size() - 1] as Dictionary).get("v", "bad token"))
	else:
		var state: Dictionary = {"tokens": tokens, "pos": 0, "error": ""}
		var tree: Array = _parse_ternary(state)
		if str(state["error"]).is_empty() and int(state["pos"]) < tokens.size():
			state["error"] = "unexpected token at " + str(int(state["pos"]))
		if str(state["error"]).is_empty():
			result["ok"] = true
			result["tree"] = tree
			var node: Variant = _compile(tree)
			if node is Array:
				result["node"] = node
				result["fast"] = true
		else:
			result["error"] = str(state["error"])
	if _expr_cache.size() >= EXPR_CACHE_MAX:
		_expr_cache = {}
	_expr_cache[code] = result
	return result


static func expr_forget() -> void:
	_expr_cache = {}


static func _compile(node: Array) -> Variant:
	if node.is_empty():
		return null
	var kind: String = str(node[0])
	if kind == "num":
		return [OP_NUM, float(node[1])]
	if kind == "var":
		var name: String = str(node[1])
		if EXPR_CONSTS.has(name):
			return [OP_NUM, float(EXPR_CONSTS[name])]
		var slot: int = EXPR_SLOTS.find(name)
		if slot < 0:
			return null
		return [OP_SLOT, slot]
	if kind == "neg":
		var a: Variant = _compile(node[1])
		if a == null:
			return null
		return [OP_NEG, a]
	if kind == "not":
		var b: Variant = _compile(node[1])
		if b == null:
			return null
		return [OP_NOT, b]
	if kind == "cond":
		var c0: Variant = _compile(node[1])
		var c1: Variant = _compile(node[2])
		var c2: Variant = _compile(node[3])
		if c0 == null or c1 == null or c2 == null:
			return null
		return [OP_COND, c0, c1, c2]
	if kind == "bin":
		var op: int = EXPR_BINS.find(str(node[1]))
		var l: Variant = _compile(node[2])
		var r: Variant = _compile(node[3])
		if op < 0 or l == null or r == null:
			return null
		return [OP_BIN, op, l, r]
	if kind == "call":
		var fid: int = EXPR_FUNCS.find(str(node[1]))
		if fid < 0:
			return null
		var args: Array = []
		for a2: Variant in node[2]:
			var ca: Variant = _compile(a2)
			if ca == null:
				return null
			args.append(ca)
		return [OP_CALL, fid, args]
	return null


static func _run(node: Array, t: float, dur: float, value: float, fps: float, frame: float, comp: float) -> float:
	var op: int = node[0]
	if op == OP_NUM:
		return float(node[1])
	if op == OP_SLOT:
		var slot: int = node[1]
		if slot == 0:
			return t
		if slot == 1:
			return dur
		if slot == 2:
			return value
		if slot == 3:
			return fps
		if slot == 4:
			return frame
		return comp
	if op == OP_BIN:
		return _run_bin(node[1], node[2], node[3], t, dur, value, fps, frame, comp)
	if op == OP_NEG:
		return -_run(node[1], t, dur, value, fps, frame, comp)
	if op == OP_NOT:
		return 0.0 if _run(node[1], t, dur, value, fps, frame, comp) != 0.0 else 1.0
	if op == OP_COND:
		if _run(node[1], t, dur, value, fps, frame, comp) != 0.0:
			return _run(node[2], t, dur, value, fps, frame, comp)
		return _run(node[3], t, dur, value, fps, frame, comp)
	return _run_call(node[1], node[2], t, dur, value, fps, frame, comp)


static func _run_bin(op: int, l: Array, r: Array, t: float, dur: float, value: float, fps: float, frame: float, comp: float) -> float:
	if op == 12:
		if _run(l, t, dur, value, fps, frame, comp) == 0.0:
			return 0.0
		return 1.0 if _run(r, t, dur, value, fps, frame, comp) != 0.0 else 0.0
	if op == 13:
		if _run(l, t, dur, value, fps, frame, comp) != 0.0:
			return 1.0
		return 1.0 if _run(r, t, dur, value, fps, frame, comp) != 0.0 else 0.0
	var a: float = _run(l, t, dur, value, fps, frame, comp)
	var b: float = _run(r, t, dur, value, fps, frame, comp)
	if op == 0:
		return a + b
	if op == 1:
		return a - b
	if op == 2:
		return a * b
	if op == 3:
		return 0.0 if b == 0.0 else a / b
	if op == 4:
		return 0.0 if b == 0.0 else fmod(a, b)
	if op == 5:
		return pow(a, b)
	if op == 6:
		return 1.0 if a < b else 0.0
	if op == 7:
		return 1.0 if a > b else 0.0
	if op == 8:
		return 1.0 if a <= b else 0.0
	if op == 9:
		return 1.0 if a >= b else 0.0
	if op == 10:
		return 1.0 if a == b else 0.0
	return 1.0 if a != b else 0.0


static func _run_call(fid: int, args: Array, t: float, dur: float, value: float, fps: float, frame: float, comp: float) -> float:
	var n: int = args.size()
	var a0: float = _run(args[0], t, dur, value, fps, frame, comp) if n > 0 else 0.0
	if fid == 0 and n == 1:
		return sin(a0)
	if fid == 1 and n == 1:
		return cos(a0)
	if fid == 2 and n == 1:
		return tan(a0)
	if fid == 3 and n == 1:
		return asin(clampf(a0, -1.0, 1.0))
	if fid == 4 and n == 1:
		return acos(clampf(a0, -1.0, 1.0))
	if fid == 5 and n == 1:
		return atan(a0)
	if fid == 8 and n == 1:
		return absf(a0)
	if fid == 9 and n == 1:
		return floor(a0)
	if fid == 10 and n == 1:
		return ceil(a0)
	if fid == 11 and n == 1:
		return round(a0)
	if fid == 7 and n == 1:
		return sqrt(maxf(a0, 0.0))
	if fid == 19 and n == 1:
		return signf(a0)
	if fid == 20 and n == 1:
		return a0 - floor(a0)
	if fid == 17 and n == 1:
		return exp(a0)
	if fid == 18 and n == 1:
		return log(a0) if a0 > 0.0 else 0.0
	if fid == 12 and n >= 1:
		var lo: float = a0
		for i: int in range(1, n):
			lo = minf(lo, _run(args[i], t, dur, value, fps, frame, comp))
		return lo
	if fid == 13 and n >= 1:
		var hi: float = a0
		for i: int in range(1, n):
			hi = maxf(hi, _run(args[i], t, dur, value, fps, frame, comp))
		return hi
	var a1: float = _run(args[1], t, dur, value, fps, frame, comp) if n > 1 else 0.0
	if fid == 6 and n == 2:
		return atan2(a0, a1)
	if fid == 16 and n == 2:
		return pow(a0, a1)
	if fid == 23 and n == 2:
		return 0.0 if a1 == 0.0 else fposmod(a0, a1)
	if fid == 22 and n == 2:
		return 0.0 if a1 < a0 else 1.0
	var a2: float = _run(args[2], t, dur, value, fps, frame, comp) if n > 2 else 0.0
	if fid == 14 and n == 3:
		return clampf(a0, a1, a2)
	if fid == 15 and n == 3:
		return a0 + (a1 - a0) * a2
	if fid == 24 and n == 3:
		return wrapf(a0, a1, a2)
	if fid == 21 and n == 3:
		return smoothstep(a0, a1, a2)
	return NAN


static func eval_expr(code: String, env: Dictionary) -> Dictionary:
	var parsed: Dictionary = expr_parse(code)
	if not bool(parsed["ok"]):
		return {"ok": false, "value": 0.0, "error": str(parsed["error"])}
	var st: Dictionary = {"env": env, "error": ""}
	var v: float = _exec(parsed["tree"], st)
	if not str(st["error"]).is_empty():
		return {"ok": false, "value": 0.0, "error": str(st["error"])}
	if is_nan(v) or is_inf(v):
		return {"ok": false, "value": 0.0, "error": "not a finite number"}
	return {"ok": true, "value": v, "error": ""}


static func _tokenize(code: String) -> Array:
	var out: Array = []
	var i: int = 0
	var n: int = code.length()
	while i < n:
		var ch: String = code[i]
		if ch == " " or ch == "\t" or ch == "\n" or ch == "\r":
			i += 1
			continue
		if (ch >= "0" and ch <= "9") or (ch == "." and i + 1 < n and code[i + 1] >= "0" and code[i + 1] <= "9"):
			var j: int = i
			var seen_e: bool = false
			while j < n:
				var cj: String = code[j]
				if (cj >= "0" and cj <= "9") or cj == ".":
					j += 1
				elif (cj == "e" or cj == "E") and not seen_e and j + 1 < n and (code[j + 1] == "-" or code[j + 1] == "+" or (code[j + 1] >= "0" and code[j + 1] <= "9")):
					seen_e = true
					j += 2
				else:
					break
			var text: String = code.substr(i, j - i)
			if not text.is_valid_float():
				out.append({"k": "err", "v": "bad number " + text})
				return out
			out.append({"k": "num", "v": float(text)})
			i = j
			continue
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or ch == "_":
			var j2: int = i
			while j2 < n:
				var c2: String = code[j2]
				if (c2 >= "a" and c2 <= "z") or (c2 >= "A" and c2 <= "Z") or (c2 >= "0" and c2 <= "9") or c2 == "_":
					j2 += 1
				else:
					break
			out.append({"k": "id", "v": code.substr(i, j2 - i)})
			i = j2
			continue
		var two: String = code.substr(i, 2)
		if two == "<=" or two == ">=" or two == "==" or two == "!=" or two == "&&" or two == "||":
			out.append({"k": "op", "v": two})
			i += 2
			continue
		if "+-*/%^()<>?:,!".contains(ch):
			out.append({"k": "op", "v": ch})
			i += 1
			continue
		out.append({"k": "err", "v": "unexpected character " + ch})
		return out
	return out


static func _peek(state: Dictionary) -> Dictionary:
	var tokens: Array = state["tokens"]
	var pos: int = state["pos"]
	if pos < tokens.size():
		return tokens[pos]
	return {"k": "end", "v": ""}


static func _accept(state: Dictionary, kind: String, value: String) -> bool:
	var tk: Dictionary = _peek(state)
	if str(tk["k"]) == kind and str(tk["v"]) == value:
		state["pos"] = int(state["pos"]) + 1
		return true
	return false


static func _parse_ternary(state: Dictionary) -> Array:
	var cond: Array = _parse_or(state)
	if _accept(state, "op", "?"):
		var a: Array = _parse_ternary(state)
		if not _accept(state, "op", ":"):
			state["error"] = "expected : in conditional"
			return []
		var b: Array = _parse_ternary(state)
		return ["cond", cond, a, b]
	return cond


static func _parse_or(state: Dictionary) -> Array:
	var left: Array = _parse_and(state)
	while _accept(state, "op", "||"):
		left = ["bin", "||", left, _parse_and(state)]
	return left


static func _parse_and(state: Dictionary) -> Array:
	var left: Array = _parse_cmp(state)
	while _accept(state, "op", "&&"):
		left = ["bin", "&&", left, _parse_cmp(state)]
	return left


static func _parse_cmp(state: Dictionary) -> Array:
	var left: Array = _parse_add(state)
	while true:
		var tk: Dictionary = _peek(state)
		var v: String = str(tk["v"])
		if str(tk["k"]) == "op" and (v == "<" or v == ">" or v == "<=" or v == ">=" or v == "==" or v == "!="):
			state["pos"] = int(state["pos"]) + 1
			left = ["bin", v, left, _parse_add(state)]
		else:
			break
	return left


static func _parse_add(state: Dictionary) -> Array:
	var left: Array = _parse_mul(state)
	while true:
		var tk: Dictionary = _peek(state)
		var v: String = str(tk["v"])
		if str(tk["k"]) == "op" and (v == "+" or v == "-"):
			state["pos"] = int(state["pos"]) + 1
			left = ["bin", v, left, _parse_mul(state)]
		else:
			break
	return left


static func _parse_mul(state: Dictionary) -> Array:
	var left: Array = _parse_unary(state)
	while true:
		var tk: Dictionary = _peek(state)
		var v: String = str(tk["v"])
		if str(tk["k"]) == "op" and (v == "*" or v == "/" or v == "%"):
			state["pos"] = int(state["pos"]) + 1
			left = ["bin", v, left, _parse_unary(state)]
		else:
			break
	return left


static func _parse_unary(state: Dictionary) -> Array:
	if _accept(state, "op", "-"):
		return ["neg", _parse_unary(state)]
	if _accept(state, "op", "+"):
		return _parse_unary(state)
	if _accept(state, "op", "!"):
		return ["not", _parse_unary(state)]
	return _parse_pow(state)


static func _parse_pow(state: Dictionary) -> Array:
	var base: Array = _parse_atom(state)
	if _accept(state, "op", "^"):
		return ["bin", "^", base, _parse_unary(state)]
	return base


static func _parse_atom(state: Dictionary) -> Array:
	var tk: Dictionary = _peek(state)
	var kind: String = str(tk["k"])
	if kind == "num":
		state["pos"] = int(state["pos"]) + 1
		return ["num", float(tk["v"])]
	if kind == "id":
		state["pos"] = int(state["pos"]) + 1
		var name: String = str(tk["v"])
		if _accept(state, "op", "("):
			var args: Array = []
			if not _accept(state, "op", ")"):
				while true:
					args.append(_parse_ternary(state))
					if _accept(state, "op", ","):
						continue
					if _accept(state, "op", ")"):
						break
					state["error"] = "expected , or ) in call to " + name
					return []
			if not EXPR_FUNCS.has(name):
				state["error"] = "unknown function " + name
				return []
			return ["call", name, args]
		return ["var", name]
	if _accept(state, "op", "("):
		var inner: Array = _parse_ternary(state)
		if not _accept(state, "op", ")"):
			state["error"] = "expected )"
			return []
		return inner
	state["error"] = "unexpected token"
	return []


static func _truthy(v: float) -> bool:
	return v != 0.0


static func _exec(node: Array, st: Dictionary) -> float:
	if node.is_empty():
		return 0.0
	var kind: String = str(node[0])
	if kind == "num":
		return float(node[1])
	if kind == "var":
		var env: Dictionary = st["env"]
		var name: String = str(node[1])
		if env.has(name):
			var v: Variant = env[name]
			if v is float or v is int:
				return float(v)
			if v is bool:
				return 1.0 if v else 0.0
			return 0.0
		st["error"] = "unknown name " + name
		return 0.0
	if kind == "neg":
		return -_exec(node[1], st)
	if kind == "not":
		return 0.0 if _truthy(_exec(node[1], st)) else 1.0
	if kind == "cond":
		if _truthy(_exec(node[1], st)):
			return _exec(node[2], st)
		return _exec(node[3], st)
	if kind == "bin":
		return _exec_bin(str(node[1]), node[2], node[3], st)
	if kind == "call":
		return _exec_call(str(node[1]), node[2], st)
	st["error"] = "bad node"
	return 0.0


static func _exec_bin(op: String, l: Array, r: Array, st: Dictionary) -> float:
	if op == "&&":
		if not _truthy(_exec(l, st)):
			return 0.0
		return 1.0 if _truthy(_exec(r, st)) else 0.0
	if op == "||":
		if _truthy(_exec(l, st)):
			return 1.0
		return 1.0 if _truthy(_exec(r, st)) else 0.0
	var a: float = _exec(l, st)
	var b: float = _exec(r, st)
	if op == "+":
		return a + b
	if op == "-":
		return a - b
	if op == "*":
		return a * b
	if op == "/":
		return 0.0 if b == 0.0 else a / b
	if op == "%":
		return 0.0 if b == 0.0 else fmod(a, b)
	if op == "^":
		return pow(a, b)
	if op == "<":
		return 1.0 if a < b else 0.0
	if op == ">":
		return 1.0 if a > b else 0.0
	if op == "<=":
		return 1.0 if a <= b else 0.0
	if op == ">=":
		return 1.0 if a >= b else 0.0
	if op == "==":
		return 1.0 if a == b else 0.0
	if op == "!=":
		return 1.0 if a != b else 0.0
	st["error"] = "bad operator " + op
	return 0.0


static func _exec_call(name: String, args: Array, st: Dictionary) -> float:
	var vals: PackedFloat64Array = PackedFloat64Array()
	for a: Variant in args:
		vals.append(_exec(a, st))
	var n: int = vals.size()
	if name == "sin" and n == 1:
		return sin(vals[0])
	if name == "cos" and n == 1:
		return cos(vals[0])
	if name == "tan" and n == 1:
		return tan(vals[0])
	if name == "asin" and n == 1:
		return asin(clampf(vals[0], -1.0, 1.0))
	if name == "acos" and n == 1:
		return acos(clampf(vals[0], -1.0, 1.0))
	if name == "atan" and n == 1:
		return atan(vals[0])
	if name == "atan2" and n == 2:
		return atan2(vals[0], vals[1])
	if name == "sqrt" and n == 1:
		return sqrt(maxf(vals[0], 0.0))
	if name == "abs" and n == 1:
		return absf(vals[0])
	if name == "floor" and n == 1:
		return floor(vals[0])
	if name == "ceil" and n == 1:
		return ceil(vals[0])
	if name == "round" and n == 1:
		return round(vals[0])
	if name == "sign" and n == 1:
		return signf(vals[0])
	if name == "fract" and n == 1:
		return vals[0] - floor(vals[0])
	if name == "exp" and n == 1:
		return exp(vals[0])
	if name == "log" and n == 1:
		return log(vals[0]) if vals[0] > 0.0 else 0.0
	if name == "min" and n >= 1:
		var m: float = vals[0]
		for v: float in vals:
			m = minf(m, v)
		return m
	if name == "max" and n >= 1:
		var m2: float = vals[0]
		for v: float in vals:
			m2 = maxf(m2, v)
		return m2
	if name == "clamp" and n == 3:
		return clampf(vals[0], vals[1], vals[2])
	if name == "lerp" and n == 3:
		return vals[0] + (vals[1] - vals[0]) * vals[2]
	if name == "pow" and n == 2:
		return pow(vals[0], vals[1])
	if name == "mod" and n == 2:
		return 0.0 if vals[1] == 0.0 else fposmod(vals[0], vals[1])
	if name == "wrap" and n == 3:
		return wrapf(vals[0], vals[1], vals[2])
	if name == "step" and n == 2:
		return 0.0 if vals[1] < vals[0] else 1.0
	if name == "smoothstep" and n == 3:
		return smoothstep(vals[0], vals[1], vals[2])
	st["error"] = "bad call " + name + " with " + str(n) + " arguments"
	return 0.0


static func time_range(p: Dictionary) -> Vector2:
	var ks: Array[Dictionary] = keys(p)
	if ks.is_empty():
		return Vector2.ZERO
	return Vector2(float(ks[0].get("t", 0.0)), float(ks[ks.size() - 1].get("t", 0.0)))


static func bake(p: Dictionary, dur: float, fps: float, tolerance: float = 0.01) -> Dictionary:
	return bake_span(p, 0.0, dur, dur, fps, tolerance)


static func bake_span(p: Dictionary, t0: float, t1: float, dur: float, fps: float, tolerance: float = 0.01) -> Dictionary:
	if not is_animated(p) or fps <= 0.0 or dur < 0.0 or t1 < t0:
		return p.duplicate(true)
	var n: int = int(ceil((t1 - t0) * fps)) + 1
	var times: PackedFloat64Array = PackedFloat64Array()
	var samples: Array = []
	for i: int in n:
		var t: float = minf(t0 + float(i) / fps, t1)
		times.append(t)
		samples.append(evaluate_full(p, t, dur, fps))
	var layer: Dictionary = _new_keys_layer()
	var ks: Array = []
	if t0 > KEY_TOLERANCE:
		ks.append({"t": 0.0, "v": samples[0], "i": "linear"})
	var i: int = 0
	while i < n - 1:
		var best: int = _fit_run(times, samples, i, n, tolerance)
		ks.append({"t": times[i], "v": samples[i], "i": "linear"})
		i = best
	ks.append({"t": times[n - 1], "v": samples[n - 1], "i": "linear"})
	if t1 < dur - KEY_TOLERANCE:
		ks.append({"t": dur, "v": samples[n - 1], "i": "linear"})
	layer["keys"] = ks
	return {"a": true, "base": samples[0], "layers": [layer]}


static func needs_flatten(p: Dictionary) -> bool:
	if not is_animated(p):
		return false
	for l: Variant in p.get("layers", []):
		var kind: String = str((l as Dictionary).get("type", ""))
		if kind == "expr" or kind == "driven":
			return true
	return false


static func _parts_at(samples: Array, i: int) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var v: Variant = samples[i]
	if v is Array:
		for e: Variant in (v as Array):
			out.append(float(e) if (e is float or e is int) else 0.0)
		return out
	out.append(_comp(v, -1))
	return out


static func _fit_run(times: PackedFloat64Array, samples: Array, i: int, n: int, tol: float) -> int:
	var base: PackedFloat64Array = _parts_at(samples, i)
	var w: int = base.size()
	var lo: PackedFloat64Array = PackedFloat64Array()
	var hi: PackedFloat64Array = PackedFloat64Array()
	for c: int in w:
		lo.append(-INF)
		hi.append(INF)
	var best: int = i + 1
	var j: int = i + 1
	while j < n:
		var cur: PackedFloat64Array = _parts_at(samples, j)
		if cur.size() != w:
			break
		var dt: float = times[j] - times[i]
		var fits: bool = true
		if dt > 0.0:
			for c2: int in w:
				var m: float = (cur[c2] - base[c2]) / dt
				if m < lo[c2] or m > hi[c2]:
					fits = false
					break
		if not fits:
			break
		best = j
		if dt > 0.0:
			var band: float = tol / dt
			for c3: int in w:
				var d: float = (cur[c3] - base[c3]) / dt
				lo[c3] = maxf(lo[c3], d - band)
				hi[c3] = minf(hi[c3], d + band)
		else:
			for c4: int in w:
				if absf(cur[c4] - base[c4]) > tol:
					lo[c4] = INF
					hi[c4] = -INF
		j += 1
	return best


static func colour_space(p: Dictionary) -> String:
	var cs: String = String(p.get(CSPACE_KEY, "rgb"))
	return cs if COLOUR_SPACES.has(cs) else "rgb"


static func with_colour_space(p: Dictionary, cs: String) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	if cs == "rgb" or not COLOUR_SPACES.has(cs):
		out.erase(CSPACE_KEY)
	else:
		out[CSPACE_KEY] = cs
	return out


static func _in_space(p: Dictionary, cs: String) -> Dictionary:
	var ck: String = cs + ":" + str(p.hash())
	if _cspace_cache.has(ck):
		return _cspace_cache[ck]
	var q: Dictionary = p.duplicate(true)
	q.erase(CSPACE_KEY)
	if q.get("base", null) is Array:
		q["base"] = to_space(q["base"], cs)
	var li: int = keys_layer_index(q)
	if li >= 0:
		var ks: Array = (q["layers"][li] as Dictionary).get("keys", [])
		var prev_h: float = INF
		var conv: Array = []
		for k: Variant in ks:
			var kd: Dictionary = (k as Dictionary).duplicate(true)
			if kd.get("v", null) is Array:
				kd["v"] = to_space(kd["v"], cs)
			conv.append(kd)
		_fix_hues(conv, cs)
		q["layers"][li]["keys"] = conv
	if _cspace_cache.size() >= CSPACE_CACHE_MAX:
		_cspace_cache.clear()
	_cspace_cache[ck] = q
	return q


static func _hue_slot(cs: String) -> int:
	if cs == "hsv" or cs == "hsv_long" or cs == "hsl":
		return 0
	if cs == "oklch":
		return 2
	return -1


static func _chroma_slot(cs: String) -> int:
	if cs == "oklch":
		return 1
	if _hue_slot(cs) == 0:
		return 1
	return -1


static func _fix_hues(keys_: Array, cs: String) -> void:
	var hs: int = _hue_slot(cs)
	if hs < 0 or keys_.is_empty():
		return
	var cs_slot: int = _chroma_slot(cs)
	var vals: Array = []
	for k: Variant in keys_:
		vals.append((k as Dictionary).get("v", null))
	var known: float = INF
	for v: Variant in vals:
		if v is Array and float((v as Array)[cs_slot]) > 0.0001:
			known = float((v as Array)[hs])
			break
	if known == INF:
		return
	for v2: Variant in vals:
		if v2 is Array and float((v2 as Array)[cs_slot]) <= 0.0001:
			(v2 as Array)[hs] = known
		elif v2 is Array:
			known = float((v2 as Array)[hs])
	var long_way: bool = cs == "hsv_long"
	for i: int in range(1, vals.size()):
		if not (vals[i] is Array) or not (vals[i - 1] is Array):
			continue
		var a: float = float((vals[i - 1] as Array)[hs])
		var b: float = float((vals[i] as Array)[hs])
		var d: float = b - a
		if long_way:
			if absf(d) < 0.5 and absf(d) > 0.0001:
				b += -1.0 if d > 0.0 else 1.0
		else:
			while d > 0.5:
				b -= 1.0
				d -= 1.0
			while d < -0.5:
				b += 1.0
				d += 1.0
		(vals[i] as Array)[hs] = b


static func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


static func _gam(c: float) -> float:
	var x: float = maxf(c, 0.0)
	return x * 12.92 if x <= 0.0031308 else 1.055 * pow(x, 1.0 / 2.4) - 0.055


static func to_space(v: Variant, cs: String) -> Array:
	var a: Array = v
	var r: float = float(a[0])
	var g: float = float(a[1])
	var b: float = float(a[2])
	var out: Array = []
	if cs == "linear":
		out = [_lin(r), _lin(g), _lin(b)]
	elif cs == "hsv" or cs == "hsv_long":
		var col: Color = Color(r, g, b)
		out = [col.h, col.s, col.v]
	elif cs == "hsl":
		var mx: float = maxf(r, maxf(g, b))
		var mn: float = minf(r, minf(g, b))
		var l: float = (mx + mn) * 0.5
		var dd: float = mx - mn
		var sat: float = 0.0 if dd < 0.000001 else dd / (1.0 - absf(2.0 * l - 1.0) + 0.000001)
		out = [Color(r, g, b).h, clampf(sat, 0.0, 1.0), l]
	elif cs == "oklab" or cs == "oklch":
		var lab: Vector3 = _oklab(Vector3(_lin(r), _lin(g), _lin(b)))
		if cs == "oklab":
			out = [lab.x, lab.y, lab.z]
		else:
			out = [lab.x, sqrt(lab.y * lab.y + lab.z * lab.z), fposmod(atan2(lab.z, lab.y) / TAU, 1.0)]
	else:
		out = [r, g, b]
	if a.size() > 3:
		out.append(float(a[3]))
	return out


static func from_space(v: Array, cs: String) -> Array:
	var x: float = float(v[0])
	var y: float = float(v[1])
	var z: float = float(v[2])
	var out: Array = []
	if cs == "linear":
		out = [_gam(x), _gam(y), _gam(z)]
	elif cs == "hsv" or cs == "hsv_long":
		var col: Color = Color.from_hsv(fposmod(x, 1.0), clampf(y, 0.0, 1.0), clampf(z, 0.0, 1.0))
		out = [col.r, col.g, col.b]
	elif cs == "hsl":
		var h: float = fposmod(x, 1.0)
		var s2: float = clampf(y, 0.0, 1.0)
		var l: float = clampf(z, 0.0, 1.0)
		var c: float = (1.0 - absf(2.0 * l - 1.0)) * s2
		var vv: float = l + c * 0.5
		var sv: float = 0.0 if vv <= 0.000001 else 2.0 * (1.0 - l / vv)
		var col2: Color = Color.from_hsv(h, clampf(sv, 0.0, 1.0), clampf(vv, 0.0, 1.0))
		out = [col2.r, col2.g, col2.b]
	elif cs == "oklab" or cs == "oklch":
		var lab: Vector3 = Vector3(x, y, z)
		if cs == "oklch":
			var ang: float = z * TAU
			lab = Vector3(x, y * cos(ang), y * sin(ang))
		var rgb: Vector3 = _oklab_to_linear(lab)
		out = [clampf(_gam(rgb.x), 0.0, 1.0), clampf(_gam(rgb.y), 0.0, 1.0), clampf(_gam(rgb.z), 0.0, 1.0)]
	else:
		out = [x, y, z]
	if v.size() > 3:
		out.append(float(v[3]))
	return out


static func _oklab(c: Vector3) -> Vector3:
	var l: float = 0.4122214708 * c.x + 0.5363325363 * c.y + 0.0514459929 * c.z
	var m: float = 0.2119034982 * c.x + 0.6806995451 * c.y + 0.1073969566 * c.z
	var s3: float = 0.0883024619 * c.x + 0.2817188376 * c.y + 0.6299787005 * c.z
	var l_: float = sign(l) * pow(absf(l), 1.0 / 3.0)
	var m_: float = sign(m) * pow(absf(m), 1.0 / 3.0)
	var s_: float = sign(s3) * pow(absf(s3), 1.0 / 3.0)
	return Vector3(
		0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
		1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
		0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_)


static func _oklab_to_linear(c: Vector3) -> Vector3:
	var l_: float = c.x + 0.3963377774 * c.y + 0.2158037573 * c.z
	var m_: float = c.x - 0.1055613458 * c.y - 0.0638541728 * c.z
	var s_: float = c.x - 0.0894841775 * c.y - 1.2914855480 * c.z
	var l: float = l_ * l_ * l_
	var m: float = m_ * m_ * m_
	var s3: float = s_ * s_ * s_
	return Vector3(
		4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s3,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s3,
		-0.0041960863 * l - 0.7034296019 * m + 1.7076956695 * s3)


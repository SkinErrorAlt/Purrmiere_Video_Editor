extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const Clip := preload("res://doc/clip.gd")
const DepthFade := preload("res://doc/depth_fade.gd")
const PlaneDepth := preload("res://doc/plane_depth.gd")


static func _as_float(v: Variant, fallback: float) -> float:
	if v is float or v is int:
		return float(v)
	if v is bool:
		return 1.0 if bool(v) else 0.0
	return fallback


static func fade_at(c: Clip, e: Dictionary, local_t: float, fps: float) -> Dictionary:
	var uid: String = str(e.get("uid", ""))
	var raw: Dictionary = {}
	for k: String in DepthFade.PROPS:
		var p: Dictionary = DepthFade.get_prop(e, k)
		raw[k] = AnimProp.evaluate(p, c.param_time(DepthFade.path_of(uid, k), local_t), c.duration, fps)
	var rv: Variant = raw[DepthFade.REVERSE]
	return {
		"near": _as_float(raw[DepthFade.NEAR], DepthFade.DEFAULT_NEAR),
		"far": _as_float(raw[DepthFade.FAR], DepthFade.DEFAULT_FAR),
		"softness": maxf(_as_float(raw[DepthFade.SOFTNESS], DepthFade.DEFAULT_SOFTNESS), 0.0),
		"reverse": bool(rv) if rv is bool else _as_float(rv, 0.0) >= 0.5,
	}


static func source_values(c: Clip, src: Dictionary, def: Dictionary, local_t: float, fps: float) -> Dictionary:
	var wanted: PackedStringArray = PlaneDepth.param_keys(PlaneDepth.declaration(def))
	var params: Dictionary = src.get("params", {})
	var out: Dictionary = {}
	for ps: Variant in def.get("params", []):
		var spec: Dictionary = ps
		var key: String = String(spec.get("key", ""))
		if not wanted.has(key):
			continue
		var p: Variant = params.get(key, null)
		if not (p is Dictionary):
			out[key] = spec.get("default", null)
			continue
		var kt: float = c.fx_time(src, key, local_t) if src.has(AnimTime.SPEEDS_FIELD) else c.anim_time(local_t)
		out[key] = AnimProp.evaluate(p, kt, c.duration, fps)
	return out


static func plane_of(c: Clip, src: Dictionary, def: Dictionary, local_t: float, fps: float) -> Dictionary:
	var decl: Dictionary = PlaneDepth.declaration(def)
	if decl.is_empty():
		return {}
	return PlaneDepth.resolve(decl, source_values(c, src, def, local_t, fps))


static func plane_for(c: Clip, index: int, registry: Object, local_t: float, fps: float) -> Dictionary:
	var k: int = DepthFade.source_index(c.effects, index, registry)
	if k < 0:
		return {}
	var src: Dictionary = c.effects[k]
	var def: Variant = registry.call("get_def", str(src.get("id", "")))
	return plane_of(c, src, def, local_t, fps) if def is Dictionary else {}


static func uniforms(plane: Dictionary, fade: Dictionary) -> Dictionary:
	return {
		"plane_tilt": float(plane["tilt"]),
		"plane_swivel": float(plane["swivel"]),
		"plane_roll": float(plane["roll"]),
		"plane_distance": float(plane["distance"]),
		"plane_focal": float(plane["focal"]),
		"plane_offset": plane["offset"],
		"fade_near": float(fade["near"]),
		"fade_far": float(fade["far"]),
		"fade_softness": float(fade["softness"]),
		"fade_reverse": bool(fade["reverse"]),
	}

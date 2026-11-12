extends RefCounted

const DECL_KEY := "depth"
const KIND := "plane"
const DEFAULT_DISTANCE := 2.0
const DEFAULT_FOV := 40.0
const ROLE_TILT := "tilt"
const ROLE_SWIVEL := "swivel"
const ROLE_ROLL := "roll"
const ROLE_DISTANCE := "distance"
const ROLE_FOV := "fov"
const ROLE_OFFSET := "offset"
const ROLE_SCALE := "scale"
const ROLE_FOCAL := "focal"
const ROLE_ZOOM := "zoom"
const UNIT_KEY := "unit"
const ROLES: PackedStringArray = ["tilt", "swivel", "roll", "distance", "fov", "offset", "scale", "focal", "zoom"]
const MIN_LENGTH := 0.01
const MISS := -1.0
const EPS := 0.000001
const FIT_STEPS := 9


static func declaration(def: Dictionary) -> Dictionary:
	var d: Variant = def.get(DECL_KEY, null)
	if d is Dictionary and String((d as Dictionary).get("kind", "")) == KIND:
		return d
	return {}


static func declares(def: Dictionary) -> bool:
	return not declaration(def).is_empty()


static func param_keys(decl: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for role: String in ROLES:
		var k: String = String(decl.get(role, ""))
		if not k.is_empty() and not out.has(k):
			out.append(k)
	return out


static func focal_of_fov(fov_deg: float) -> float:
	return 0.5 / tan(deg_to_rad(clampf(fov_deg, 0.1, 179.9)) * 0.5)


static func _named(decl: Dictionary, values: Dictionary, role: String) -> Variant:
	var k: String = String(decl.get(role, ""))
	if k.is_empty():
		return null
	return values.get(k, null)


static func _num(decl: Dictionary, values: Dictionary, role: String, fallback: float) -> float:
	var v: Variant = _named(decl, values, role)
	if v is float or v is int:
		return float(v)
	if v is bool:
		return 1.0 if bool(v) else 0.0
	return fallback


static func _vec(decl: Dictionary, values: Dictionary, role: String) -> Vector2:
	var v: Variant = _named(decl, values, role)
	if v is Vector2:
		return v
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float((v as Array)[0]), float((v as Array)[1]))
	return Vector2.ZERO


static func resolve(decl: Dictionary, values: Dictionary) -> Dictionary:
	var unit_raw: Variant = decl.get(UNIT_KEY, 1.0)
	var unit: float = float(unit_raw) if (unit_raw is float or unit_raw is int) and float(unit_raw) > 0.0 else 1.0
	var distance: float = DEFAULT_DISTANCE
	if _named(decl, values, ROLE_DISTANCE) != null:
		distance = maxf(_num(decl, values, ROLE_DISTANCE, DEFAULT_DISTANCE), MIN_LENGTH) * unit
	var focal: float = 0.0
	if _named(decl, values, ROLE_FOCAL) != null:
		focal = maxf(_num(decl, values, ROLE_FOCAL, 1.0), MIN_LENGTH) * unit
	else:
		focal = focal_of_fov(_num(decl, values, ROLE_FOV, DEFAULT_FOV))
	focal *= maxf(_num(decl, values, ROLE_ZOOM, 1.0), MIN_LENGTH)
	return {
		"tilt": _num(decl, values, ROLE_TILT, 0.0),
		"swivel": _num(decl, values, ROLE_SWIVEL, 0.0),
		"roll": _num(decl, values, ROLE_ROLL, 0.0),
		"distance": distance,
		"focal": focal,
		"offset": _vec(decl, values, ROLE_OFFSET),
		"scale": maxf(_num(decl, values, ROLE_SCALE, 1.0), MIN_LENGTH),
	}


static func rotate(v: Vector3, tilt_deg: float, swivel_deg: float, roll_deg: float) -> Vector3:
	var t: float = deg_to_rad(tilt_deg)
	var s: float = deg_to_rad(swivel_deg)
	var r: float = deg_to_rad(roll_deg)
	var a: Vector3 = Vector3(v.x, cos(t) * v.y + sin(t) * v.z, -sin(t) * v.y + cos(t) * v.z)
	var b: Vector3 = Vector3(cos(s) * a.x - sin(s) * a.z, a.y, sin(s) * a.x + cos(s) * a.z)
	return Vector3(cos(r) * b.x - sin(r) * b.y, sin(r) * b.x + cos(r) * b.y, b.z)


static func normal(plane: Dictionary) -> Vector3:
	return rotate(Vector3(0.0, 0.0, 1.0), float(plane["tilt"]), float(plane["swivel"]), float(plane["roll"]))


static func depth_at(uv: Vector2, aspect: float, plane: Dictionary) -> float:
	var f: float = float(plane["focal"])
	var d: float = float(plane["distance"])
	var s: Vector2 = Vector2((uv.x - 0.5) * aspect, uv.y - 0.5)
	var dir: Vector3 = Vector3(s.x / f, s.y / f, 1.0)
	var n: Vector3 = normal(plane)
	var off: Vector2 = plane["offset"]
	var o: Vector3 = Vector3(off.x * aspect, off.y, 0.0)
	var cam: Vector3 = Vector3(0.0, 0.0, -d)
	var denom: float = dir.dot(n)
	if absf(denom) < EPS:
		return MISS
	var lam: float = (o - cam).dot(n) / denom
	if lam <= 0.0:
		return MISS
	return lam


static func project(picture_uv: Vector2, aspect: float, plane: Dictionary) -> Vector2:
	var sc: float = float(plane["scale"])
	var q: Vector3 = Vector3((picture_uv.x - 0.5) * aspect * sc, (picture_uv.y - 0.5) * sc, 0.0)
	var off: Vector2 = plane["offset"]
	var p: Vector3 = Vector3(off.x * aspect, off.y, 0.0) + rotate(q, float(plane["tilt"]), float(plane["swivel"]), float(plane["roll"]))
	var z: float = p.z + float(plane["distance"])
	if z <= EPS:
		return Vector2(INF, INF)
	var s: Vector2 = Vector2(p.x, p.y) * float(plane["focal"]) / z
	return Vector2(s.x / aspect + 0.5, s.y + 0.5)


static func weight(depth: float, near: float, far: float, softness: float, reverse: bool) -> float:
	var w: float = 0.0
	if depth >= 0.0:
		var soft: float = maxf(softness, 0.0)
		var lo: float = near - soft
		var hi: float = far + soft
		var t: float = clampf((depth - lo) / maxf(hi - lo, 0.00001), 0.0, 1.0)
		w = 1.0 - t * t * (3.0 - 2.0 * t)
	return 1.0 - w if reverse else w


static func depth_range(plane: Dictionary, aspect: float) -> Vector2:
	var lo: float = INF
	var hi: float = -INF
	for iy: int in FIT_STEPS:
		for ix: int in FIT_STEPS:
			var uv: Vector2 = Vector2(float(ix) / float(FIT_STEPS - 1), float(iy) / float(FIT_STEPS - 1))
			var pic: Vector2 = picture_uv_at(uv, aspect, plane)
			if pic.x < 0.0 or pic.y < 0.0 or pic.x > 1.0 or pic.y > 1.0:
				continue
			var dp: float = depth_at(uv, aspect, plane)
			if dp < 0.0:
				continue
			lo = minf(lo, dp)
			hi = maxf(hi, dp)
	if lo > hi:
		return Vector2(MISS, MISS)
	return Vector2(lo, hi)


static func picture_uv_at(uv: Vector2, aspect: float, plane: Dictionary) -> Vector2:
	var dp: float = depth_at(uv, aspect, plane)
	if dp < 0.0:
		return Vector2(-1.0, -1.0)
	var f: float = float(plane["focal"])
	var s: Vector2 = Vector2((uv.x - 0.5) * aspect, uv.y - 0.5)
	var hit: Vector3 = Vector3(s.x / f * dp, s.y / f * dp, dp - float(plane["distance"]))
	var off: Vector2 = plane["offset"]
	var rel: Vector3 = hit - Vector3(off.x * aspect, off.y, 0.0)
	var ax: Vector3 = rotate(Vector3(1.0, 0.0, 0.0), float(plane["tilt"]), float(plane["swivel"]), float(plane["roll"]))
	var ay: Vector3 = rotate(Vector3(0.0, 1.0, 0.0), float(plane["tilt"]), float(plane["swivel"]), float(plane["roll"]))
	var sc: float = float(plane["scale"])
	return Vector2(rel.dot(ax) / sc / aspect + 0.5, rel.dot(ay) / sc + 0.5)

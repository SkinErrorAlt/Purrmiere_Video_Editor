extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const FIELD := "locks"
const MAP := "map"
const KEY_AREAS := "areas"
const KEY_AMOUNT := "lock_amount"
const SIDE := 128
const AMOUNT_DEFAULT := 100.0
const AREA_RADIUS_DEFAULT := 80.0
const AREA_STRENGTH_DEFAULT := 100.0
const AREA_SOFT_DEFAULT := 30.0
const FULL_FROM := 0.88
const ANCHOR := 100000.0
const CACHE_MAX := 24
const FULL_INK := Color(1.0, 0.18, 0.22, 0.55)
const PART_INK := Color(1.0, 0.68, 0.12, 0.42)
const FREE_INK := Color(1.0, 0.68, 0.12, 0.0)

static var _map_cache: Dictionary = {}
static var _field_cache: Dictionary = {}
static var _weight_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func _params(e: Dictionary) -> Dictionary:
	var p: Variant = e.get("params", {})
	return p if p is Dictionary else {}


static func area_key(i: int, part: String) -> String:
	return "area_" + str(i) + "_" + part


static func info_of(e: Dictionary) -> Dictionary:
	var v: Variant = e.get(FIELD, null)
	return v if v is Dictionary else {}


static func map_size(layer: Vector2) -> Vector2i:
	var longest: float = maxf(maxf(layer.x, layer.y), 1.0)
	var k: float = float(SIDE) / longest
	return Vector2i(maxi(int(round(layer.x * k)), 1), maxi(int(round(layer.y * k)), 1))


static func map_bytes(info: Dictionary) -> PackedByteArray:
	var code: Variant = info.get(MAP, "")
	var w: int = int(info.get("mw", 0))
	var h: int = int(info.get("mh", 0))
	if not (code is String) or String(code).is_empty() or w < 1 or h < 1:
		return PackedByteArray()
	var key: String = str(w) + "x" + str(h) + "|" + str(hash(String(code)))
	var hit: Variant = _map_cache.get(key, null)
	if hit is PackedByteArray:
		return hit
	var raw: PackedByteArray = Marshalls.base64_to_raw(String(code)).decompress(w * h, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != w * h:
		raw = PackedByteArray()
	if _map_cache.size() > CACHE_MAX:
		_map_cache = {}
	_map_cache[key] = raw
	return raw


static func encode(bytes: PackedByteArray, w: int, h: int) -> Dictionary:
	var any: bool = false
	for b: int in bytes:
		if b > 0:
			any = true
			break
	if not any or bytes.size() != w * h:
		return {}
	return {MAP: Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_DEFLATE)), "mw": w, "mh": h}


static func areas_of(e: Dictionary) -> PackedVector2Array:
	var p: Variant = _params(e).get(KEY_AREAS, null)
	var v: Variant = AnimProp.static_value(p) if p is Dictionary else p
	var out: PackedVector2Array = PackedVector2Array()
	if not (v is Array):
		return out
	var a: Array = v
	for i: int in a.size() / 2:
		var x: Variant = a[i * 2]
		var y: Variant = a[i * 2 + 1]
		out.append(Vector2(float(x) if (x is float or x is int) else 0.0, float(y) if (y is float or y is int) else 0.0))
	return out


static func area_count(e: Dictionary) -> int:
	return areas_of(e).size()


static func _static_float(e: Dictionary, key: String, fallback: float) -> float:
	var p: Variant = _params(e).get(key, null)
	var v: Variant = AnimProp.static_value(p) if p is Dictionary else p
	return float(v) if (v is float or v is int) else fallback


static func area_values(e: Dictionary) -> Dictionary:
	var at: PackedVector2Array = areas_of(e)
	var r: PackedFloat64Array = PackedFloat64Array()
	var s: PackedFloat64Array = PackedFloat64Array()
	var f: PackedFloat64Array = PackedFloat64Array()
	for i: int in at.size():
		r.append(maxf(_static_float(e, area_key(i, "r"), AREA_RADIUS_DEFAULT), 0.0))
		s.append(clampf(_static_float(e, area_key(i, "s"), AREA_STRENGTH_DEFAULT) / 100.0, 0.0, 1.0))
		f.append(clampf(_static_float(e, area_key(i, "f"), AREA_SOFT_DEFAULT) / 100.0, 0.0, 1.0))
	return {"at": at, "r": r, "s": s, "f": f}


static func has_locks(e: Dictionary) -> bool:
	return not map_bytes(info_of(e)).is_empty() or area_count(e) > 0


static func falloff(d: float, r: float, soft: float) -> float:
	if r <= 0.0 or d >= r:
		return 0.0
	var inner: float = r * (1.0 - clampf(soft, 0.0, 1.0))
	if d <= inner:
		return 1.0
	return 1.0 - smoothstep(inner, r, d)


static func field_key(e: Dictionary, size: Vector2) -> String:
	var info: Dictionary = info_of(e)
	var av: Dictionary = area_values(e)
	return "%.2f|%.2f|%s|%s|%s|%s|%s|%s" % [size.x, size.y, str(hash(String(info.get(MAP, "")))), str(int(info.get("mw", 0))), str(av["at"]), str(av["r"]), str(av["s"]), str(av["f"])]


static func field(e: Dictionary, size: Vector2) -> Dictionary:
	var key: String = field_key(e, size)
	var hit: Variant = _field_cache.get(key, null)
	if hit is Dictionary:
		return hit
	var dims: Vector2i = map_size(size)
	var info: Dictionary = info_of(e)
	var w: int = dims.x
	var h: int = dims.y
	var vals: PackedFloat32Array = PackedFloat32Array()
	vals.resize(w * h)
	var raw: PackedByteArray = map_bytes(info)
	var mw: int = int(info.get("mw", 0))
	var mh: int = int(info.get("mh", 0))
	if not raw.is_empty():
		for y: int in h:
			var sy: int = clampi(int(float(y) * float(mh) / float(h)), 0, mh - 1)
			for x: int in w:
				var sx: int = clampi(int(float(x) * float(mw) / float(w)), 0, mw - 1)
				vals[y * w + x] = float(raw[sy * mw + sx]) / 255.0
	var av: Dictionary = area_values(e)
	var at: PackedVector2Array = av["at"]
	var rr: PackedFloat64Array = av["r"]
	var ss: PackedFloat64Array = av["s"]
	var ff: PackedFloat64Array = av["f"]
	var cell: Vector2 = Vector2(size.x / float(w), size.y / float(h))
	for i: int in at.size():
		if rr[i] <= 0.0 or ss[i] <= 0.0:
			continue
		var lo: Vector2i = Vector2i(floori((at[i].x - rr[i] + size.x * 0.5) / cell.x), floori((at[i].y - rr[i] + size.y * 0.5) / cell.y))
		var hi: Vector2i = Vector2i(ceili((at[i].x + rr[i] + size.x * 0.5) / cell.x), ceili((at[i].y + rr[i] + size.y * 0.5) / cell.y))
		for y2: int in range(maxi(lo.y, 0), mini(hi.y + 1, h)):
			for x2: int in range(maxi(lo.x, 0), mini(hi.x + 1, w)):
				var p: Vector2 = Vector2((float(x2) + 0.5) * cell.x, (float(y2) + 0.5) * cell.y) - size * 0.5
				var v: float = ss[i] * falloff(p.distance_to(at[i]), rr[i], ff[i])
				if v > vals[y2 * w + x2]:
					vals[y2 * w + x2] = v
	var made: Dictionary = {"w": w, "h": h, "v": vals, "size": size, "key": key}
	if _field_cache.size() > CACHE_MAX:
		_field_cache = {}
	_field_cache[key] = made
	return made


static func vertex_weights(e: Dictionary, mesh: Dictionary) -> PackedFloat64Array:
	if not has_locks(e):
		return PackedFloat64Array()
	var size: Vector2 = mesh["size"]
	var fd: Dictionary = field(e, size)
	var key: String = String(mesh.get("key", "")) + "|" + String(fd["key"])
	var hit: Variant = _weight_cache.get(key, null)
	if hit is PackedFloat64Array:
		return hit
	var verts: PackedVector2Array = mesh["verts"]
	var w: int = int(fd["w"])
	var h: int = int(fd["h"])
	var vals: PackedFloat32Array = fd["v"]
	var half: Vector2 = Vector2(size.x / float(maxi(int(mesh.get("nx", 1)), 1)), size.y / float(maxi(int(mesh.get("ny", 1)), 1))) * 0.5
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(verts.size())
	for vi: int in verts.size():
		var p: Vector2 = verts[vi] + size * 0.5
		var x0: int = clampi(floori((p.x - half.x) / size.x * float(w)), 0, w - 1)
		var x1: int = clampi(ceili((p.x + half.x) / size.x * float(w)) - 1, x0, w - 1)
		var y0: int = clampi(floori((p.y - half.y) / size.y * float(h)), 0, h - 1)
		var y1: int = clampi(ceili((p.y + half.y) / size.y * float(h)) - 1, y0, h - 1)
		var best: float = 0.0
		for y: int in range(y0, y1 + 1):
			for x: int in range(x0, x1 + 1):
				best = maxf(best, vals[y * w + x])
		out[vi] = best
	if _weight_cache.size() > CACHE_MAX:
		_weight_cache = {}
	_weight_cache[key] = out
	return out


static func anchors(weights: PackedFloat64Array) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(weights.size())
	for i: int in weights.size():
		out[i] = ANCHOR * smoothstep(FULL_FROM, 1.0, weights[i]) if weights[i] > FULL_FROM else 0.0
	return out


static func ink(v: float) -> Color:
	if v <= 0.0:
		return FREE_INK
	if v < FULL_FROM:
		return FREE_INK.lerp(PART_INK, clampf(v / FULL_FROM * 1.4, 0.0, 1.0))
	return PART_INK.lerp(FULL_INK, smoothstep(FULL_FROM, 1.0, v))


static func texture(e: Dictionary, size: Vector2) -> ImageTexture:
	var fd: Dictionary = field(e, size)
	var key: String = String(fd["key"])
	var hit: Variant = _tex_cache.get(key, null)
	if hit is ImageTexture:
		return hit
	var w: int = int(fd["w"])
	var h: int = int(fd["h"])
	var vals: PackedFloat32Array = fd["v"]
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			img.set_pixel(x, y, ink(vals[y * w + x]))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	if _tex_cache.size() > 8:
		_tex_cache = {}
	_tex_cache[key] = tex
	return tex


static func start_bytes(e: Dictionary, size: Vector2) -> PackedByteArray:
	var dims: Vector2i = map_size(size)
	var info: Dictionary = info_of(e)
	var raw: PackedByteArray = map_bytes(info)
	var out: PackedByteArray = PackedByteArray()
	out.resize(dims.x * dims.y)
	if raw.is_empty():
		return out
	var mw: int = int(info.get("mw", 0))
	var mh: int = int(info.get("mh", 0))
	if mw == dims.x and mh == dims.y:
		return raw.duplicate()
	for y: int in dims.y:
		var sy: int = clampi(int(float(y) * float(mh) / float(dims.y)), 0, mh - 1)
		for x: int in dims.x:
			var sx: int = clampi(int(float(x) * float(mw) / float(dims.x)), 0, mw - 1)
			out[y * dims.x + x] = raw[sy * mw + sx]
	return out


static func stamp(bytes: PackedByteArray, w: int, h: int, size: Vector2, at: Vector2, radius: float, strength: float, soft: float, erase: bool) -> PackedByteArray:
	var out: PackedByteArray = bytes
	var cell: Vector2 = Vector2(size.x / float(w), size.y / float(h))
	var target: float = 0.0 if erase else clampf(strength, 0.0, 1.0) * 255.0
	var lo: Vector2i = Vector2i(floori((at.x - radius + size.x * 0.5) / cell.x), floori((at.y - radius + size.y * 0.5) / cell.y))
	var hi: Vector2i = Vector2i(ceili((at.x + radius + size.x * 0.5) / cell.x), ceili((at.y + radius + size.y * 0.5) / cell.y))
	for y: int in range(maxi(lo.y, 0), mini(hi.y + 1, h)):
		for x: int in range(maxi(lo.x, 0), mini(hi.x + 1, w)):
			var p: Vector2 = Vector2((float(x) + 0.5) * cell.x, (float(y) + 0.5) * cell.y) - size * 0.5
			var f: float = falloff(p.distance_to(at), radius, soft)
			if f <= 0.0:
				continue
			var old: float = float(out[y * w + x])
			out[y * w + x] = clampi(int(round(old + (target - old) * f)), 0, 255)
	return out


static func stroke(bytes: PackedByteArray, w: int, h: int, size: Vector2, from: Vector2, to: Vector2, radius: float, strength: float, soft: float, erase: bool) -> PackedByteArray:
	var span: float = from.distance_to(to)
	var step: float = maxf(radius * 0.3, 0.5)
	var n: int = maxi(int(ceil(span / step)), 1)
	var out: PackedByteArray = bytes
	for i: int in n + 1:
		out = stamp(out, w, h, size, from.lerp(to, float(i) / float(n)), radius, strength, soft, erase)
	return out

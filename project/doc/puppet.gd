extends RefCounted

const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const PuppetSolve := preload("res://doc/puppet_solve.gd")
const PuppetLocks := preload("res://doc/puppet_locks.gd")
const EFFECT_ID := "puppet"
const KEY_PINS := "pins"
const KEY_REST := "rest"
const KEY_DENSITY := "density"
const KEY_HOLDS := "holds"
const KEY_LINKS := "links"
const KEY_OVERLAPS := "overlaps"
const KEY_KINDS := "kinds"
const KEY_TURNS := "turns"
const KEY_EXPANSION := "expansion"
const KIND_POSITION := 0
const KIND_BEND := 1
const KIND_ADVANCED := 2
const KIND_NAMES: PackedStringArray = ["Position", "Bend", "Advanced"]
const TURN_REST := Vector2(0.0, 100.0)
const SCALE_MIN := 1.0
const SCALE_MAX := 1000.0
const BEND_REACH_CELLS := 2.5
const EXPANSION_MAX := 400.0
const DRAFT_FROM := 900
const DRAFT_CELLS := 16
const OVER_FRONT_DEFAULT := 50.0
const OVER_FRONT_MAX := 100.0
const OVER_EXTENT_DEFAULT := 40.0
const SHAPE_FIELD := "shape"
const SHAPE_CUT := 5
const HOLD_RADIUS_DEFAULT := 60.0
const HOLD_AMOUNT_DEFAULT := 100.0
const LINK_STRENGTH_DEFAULT := 50.0
const HOLD_STIFF := 10000.0
const HOLD_CORE := 0.6
const LINK_PASSES := 8
const MESH_FIELD := "mesh"
const FRAMES_FIELD := "frames"
const DENSITY_DEFAULT := 16.0
const DENSITY_MIN := 4
const DENSITY_MAX := 64
const ALPHA_MIN := 0.02
const ALPHA_SIDE := 256
const PIN_WEIGHT := 100000.0
const HOLD_WEIGHT := 100000.0
const TINY := 0.0000001
const CACHE_MAX := 24
const RESULT_MAX := 64

static var _alpha_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}
static var _solver_cache: Dictionary = {}
static var _result_cache: Dictionary = {}
static var _shape_cache: Dictionary = {}
static var _order_cache: Dictionary = {}
static var _weights_cache: Dictionary = {}
static var _pending: Dictionary = {}
static var _draft_cache: Dictionary = {}
static var draft_ok: bool = false
static var draft_count: int = 0


static func is_puppet(e: Dictionary) -> bool:
	return String(e.get("id", "")) == EFFECT_ID


static func effect_of(c: Clip) -> Dictionary:
	if c == null:
		return {}
	for e: Dictionary in c.effects:
		if is_puppet(e) and bool(e.get("enabled", true)):
			return e
	return {}


static func any_effect_of(c: Clip) -> Dictionary:
	if c == null:
		return {}
	for e: Dictionary in c.effects:
		if is_puppet(e):
			return e
	return {}


static func flat_of(v: Variant) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if not (v is Array):
		return out
	var a: Array = v
	for i: int in a.size() / 2:
		var x: Variant = a[i * 2]
		var y: Variant = a[i * 2 + 1]
		out.append(Vector2(float(x) if (x is float or x is int) else 0.0, float(y) if (y is float or y is int) else 0.0))
	return out


static func flat(pts: PackedVector2Array) -> Array:
	var out: Array = []
	for p: Vector2 in pts:
		out.append(p.x)
		out.append(p.y)
	return out


static func _param(e: Dictionary, key: String) -> Variant:
	var params: Variant = e.get("params", {})
	return (params as Dictionary).get(key, null) if params is Dictionary else null


static func rest_of(e: Dictionary) -> PackedVector2Array:
	var p: Variant = _param(e, KEY_REST)
	if p is Dictionary:
		return flat_of(AnimProp.static_value(p))
	return flat_of(p)


static func pin_count_of(c: Clip) -> int:
	return rest_of(any_effect_of(c)).size()


static func key_time(c: Clip, e: Dictionary, key: String, t: float) -> float:
	var local_t: float = t - c.start
	return c.fx_time(e, key, local_t) if e.has(Clip.AnimTime.SPEEDS_FIELD) else c.anim_time(local_t)


static func keyed_pins_at(c: Clip, e: Dictionary, t: float, fps: float) -> PackedVector2Array:
	var rest: PackedVector2Array = rest_of(e)
	var p: Variant = _param(e, KEY_PINS)
	var out: PackedVector2Array = PackedVector2Array()
	if p is Dictionary:
		out = flat_of(AnimProp.evaluate(p, key_time(c, e, KEY_PINS, t), c.duration, fps))
	while out.size() < rest.size():
		out.append(rest[out.size()])
	if out.size() > rest.size():
		out.resize(rest.size())
	return out


static func linked_pins_at(c: Clip, e: Dictionary, t: float, fps: float) -> PackedVector2Array:
	var keyed: PackedVector2Array = keyed_pins_at(c, e, t, fps)
	if link_count(e) == 0:
		return keyed
	return apply_links(rest_of(e), keyed, gains_at(c, e, t, fps))


static func pins_at(c: Clip, e: Dictionary, t: float, fps: float) -> PackedVector2Array:
	if not any_bend(e):
		return linked_pins_at(c, e, t, fps)
	return deformed_at(c, e, t, fps, size_of(e, Vector2(1920.0, 1080.0)))["pins"]


static func kinds_of(e: Dictionary) -> PackedInt32Array:
	var n: int = rest_of(e).size()
	var p: Variant = _param(e, KEY_KINDS)
	var v: Variant = AnimProp.static_value(p) if p is Dictionary else p
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(n)
	if v is Array:
		var a: Array = v
		for i: int in mini(a.size(), n):
			var x: Variant = a[i]
			out[i] = clampi(int(x), KIND_POSITION, KIND_ADVANCED) if (x is float or x is int) else KIND_POSITION
	return out


static func kind_of(e: Dictionary, i: int) -> int:
	var k: PackedInt32Array = kinds_of(e)
	return k[i] if i >= 0 and i < k.size() else KIND_POSITION


static func any_bend(e: Dictionary) -> bool:
	for k: int in kinds_of(e):
		if k != KIND_POSITION:
			return true
	return false


static func turns_at(c: Clip, e: Dictionary, t: float, fps: float) -> PackedVector2Array:
	var n: int = rest_of(e).size()
	var p: Variant = _param(e, KEY_TURNS)
	var out: PackedVector2Array = PackedVector2Array()
	if p is Dictionary:
		out = flat_of(AnimProp.evaluate(p, key_time(c, e, KEY_TURNS, t), c.duration, fps))
	while out.size() < n:
		out.append(TURN_REST)
	if out.size() > n:
		out.resize(n)
	for i: int in n:
		out[i] = Vector2(out[i].x, clampf(out[i].y, SCALE_MIN, SCALE_MAX))
	return out


static func expansion_of(e: Dictionary) -> float:
	var p: Variant = _param(e, KEY_EXPANSION)
	var v: Variant = AnimProp.static_value(p) if p is Dictionary else p
	return clampf(float(v), 0.0, EXPANSION_MAX) if (v is float or v is int) else 0.0


static func value_at(c: Clip, e: Dictionary, key: String, t: float, fps: float, fallback: float) -> float:
	var p: Variant = _param(e, key)
	if p is Dictionary:
		var v: Variant = AnimProp.evaluate(p, key_time(c, e, key, t), c.duration, fps)
		return float(v) if (v is float or v is int) else fallback
	if p is float or p is int:
		return float(p)
	return fallback


static func hold_key(i: int, part: String) -> String:
	return "hold_" + str(i) + "_" + part


static func link_key(i: int, part: String) -> String:
	return "link_" + str(i) + "_" + part


static func holds_of(e: Dictionary) -> PackedVector2Array:
	var p: Variant = _param(e, KEY_HOLDS)
	if p is Dictionary:
		return flat_of(AnimProp.static_value(p))
	return flat_of(p)


static func hold_count(e: Dictionary) -> int:
	return holds_of(e).size()


static func links_of(e: Dictionary) -> PackedInt32Array:
	var p: Variant = _param(e, KEY_LINKS)
	var v: Variant = AnimProp.static_value(p) if p is Dictionary else p
	var out: PackedInt32Array = PackedInt32Array()
	if not (v is Array):
		return out
	var a: Array = v
	for i: int in (a.size() / 2) * 2:
		var x: Variant = a[i]
		out.append(int(x) if (x is float or x is int) else -1)
	return out


static func link_count(e: Dictionary) -> int:
	return links_of(e).size() / 2


static func holds_at(c: Clip, e: Dictionary, t: float, fps: float) -> Dictionary:
	var at: PackedVector2Array = holds_of(e)
	var r: PackedFloat64Array = PackedFloat64Array()
	var a: PackedFloat64Array = PackedFloat64Array()
	for i: int in at.size():
		r.append(maxf(value_at(c, e, hold_key(i, "r"), t, fps, HOLD_RADIUS_DEFAULT), 0.0))
		a.append(clampf(value_at(c, e, hold_key(i, "a"), t, fps, HOLD_AMOUNT_DEFAULT) / 100.0, 0.0, 1.0))
	return {"at": at, "r": r, "a": a}


static func over_key(i: int, part: String) -> String:
	return "over_" + str(i) + "_" + part


static func overlaps_of(e: Dictionary) -> PackedVector2Array:
	var p: Variant = _param(e, KEY_OVERLAPS)
	if p is Dictionary:
		return flat_of(AnimProp.static_value(p))
	return flat_of(p)


static func overlap_count(e: Dictionary) -> int:
	return overlaps_of(e).size()


static func overlaps_at(c: Clip, e: Dictionary, t: float, fps: float) -> Dictionary:
	var at: PackedVector2Array = overlaps_of(e)
	var f: PackedFloat64Array = PackedFloat64Array()
	var x: PackedFloat64Array = PackedFloat64Array()
	for i: int in at.size():
		f.append(clampf(value_at(c, e, over_key(i, "f"), t, fps, OVER_FRONT_DEFAULT), -OVER_FRONT_MAX, OVER_FRONT_MAX))
		x.append(maxf(value_at(c, e, over_key(i, "x"), t, fps, OVER_EXTENT_DEFAULT), 0.0))
	return {"at": at, "f": f, "x": x}


static func tri_depths(mesh: Dictionary, overlaps: Dictionary) -> PackedFloat64Array:
	var verts: PackedVector2Array = mesh["verts"]
	var tris: PackedInt32Array = mesh["tris"]
	var at: PackedVector2Array = overlaps.get("at", PackedVector2Array())
	var f: PackedFloat64Array = overlaps.get("f", PackedFloat64Array())
	var x: PackedFloat64Array = overlaps.get("x", PackedFloat64Array())
	var n: int = mini(at.size(), mini(f.size(), x.size()))
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(tris.size() / 3)
	if n == 0:
		return out
	for t: int in tris.size() / 3:
		var mid: Vector2 = (verts[tris[t * 3]] + verts[tris[t * 3 + 1]] + verts[tris[t * 3 + 2]]) / 3.0
		var best: float = INF
		for i: int in n:
			if x[i] <= 0.0:
				continue
			var dd: float = mid.distance_to(at[i])
			if dd <= x[i] and dd < best:
				best = dd
				out[t] = f[i]
	return out


static func draw_order(mesh: Dictionary, overlaps: Dictionary) -> PackedInt32Array:
	var tris: PackedInt32Array = mesh["tris"]
	var at: PackedVector2Array = overlaps.get("at", PackedVector2Array())
	if at.is_empty():
		return tris
	var key: String = String(mesh.get("key", "")) + "|" + str(at) + "|" + str(overlaps.get("f", PackedFloat64Array())) + "|" + str(overlaps.get("x", PackedFloat64Array()))
	var hit: Variant = _order_cache.get(key, null)
	if hit is PackedInt32Array:
		return hit
	var depths: PackedFloat64Array = tri_depths(mesh, overlaps)
	var levels: Dictionary = {}
	for t: int in depths.size():
		var lv: float = depths[t]
		var list: PackedInt32Array = levels.get(lv, PackedInt32Array())
		list.append(t)
		levels[lv] = list
	var order: Array = levels.keys()
	order.sort()
	var out: PackedInt32Array = PackedInt32Array()
	for lv2: Variant in order:
		for t2: int in (levels[lv2] as PackedInt32Array):
			out.append(tris[t2 * 3])
			out.append(tris[t2 * 3 + 1])
			out.append(tris[t2 * 3 + 2])
	if _order_cache.size() > RESULT_MAX:
		_order_cache = {}
	_order_cache[key] = out
	return out


static func strengths_at(c: Clip, e: Dictionary, t: float, fps: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	for i: int in link_count(e):
		out.append(clampf(value_at(c, e, link_key(i, "ab"), t, fps, LINK_STRENGTH_DEFAULT) / 100.0, 0.0, 1.0))
		out.append(clampf(value_at(c, e, link_key(i, "ba"), t, fps, LINK_STRENGTH_DEFAULT) / 100.0, 0.0, 1.0))
	return out


static func gains_at(c: Clip, e: Dictionary, t: float, fps: float) -> PackedFloat64Array:
	return link_gains(rest_of(e).size(), links_of(e), strengths_at(c, e, t, fps))


static func link_gains(n: int, links: PackedInt32Array, strengths: PackedFloat64Array) -> PackedFloat64Array:
	var g: PackedFloat64Array = PackedFloat64Array()
	g.resize(n * n)
	var edges: Array[Vector3] = []
	for i: int in links.size() / 2:
		var a: int = links[i * 2]
		var b: int = links[i * 2 + 1]
		if a < 0 or b < 0 or a >= n or b >= n or a == b:
			continue
		var sab: float = strengths[i * 2] if i * 2 < strengths.size() else LINK_STRENGTH_DEFAULT / 100.0
		var sba: float = strengths[i * 2 + 1] if i * 2 + 1 < strengths.size() else LINK_STRENGTH_DEFAULT / 100.0
		edges.append(Vector3(float(a), float(b), sab))
		edges.append(Vector3(float(b), float(a), sba))
	if edges.is_empty():
		return g
	for src: int in n:
		for ed: Vector3 in edges:
			if int(ed.x) == src and int(ed.y) != src:
				var k: int = src * n + int(ed.y)
				g[k] = maxf(g[k], ed.z)
		for pass_i: int in mini(LINK_PASSES, n):
			for ed2: Vector3 in edges:
				var from: int = int(ed2.x)
				var to: int = int(ed2.y)
				if from == src or to == src:
					continue
				var via: float = g[src * n + from] * ed2.z
				if via > g[src * n + to]:
					g[src * n + to] = via
	return g


static func apply_links(rest: PackedVector2Array, keyed: PackedVector2Array, gains: PackedFloat64Array) -> PackedVector2Array:
	var n: int = mini(rest.size(), keyed.size())
	if gains.size() != n * n:
		return keyed
	var out: PackedVector2Array = keyed.duplicate()
	for b: int in n:
		var pull: Vector2 = Vector2.ZERO
		for a: int in n:
			var k: float = gains[a * n + b]
			if k > 0.0 and a != b:
				pull += (keyed[a] - rest[a]) * k
		out[b] = keyed[b] + pull
	return out


static func keyed_for(rest: PackedVector2Array, keyed: PackedVector2Array, gains: PackedFloat64Array, index: int, want: Vector2) -> Vector2:
	var n: int = mini(rest.size(), keyed.size())
	if gains.size() != n * n or index < 0 or index >= n:
		return want
	var pull: Vector2 = Vector2.ZERO
	for a: int in n:
		var k: float = gains[a * n + index]
		if k > 0.0 and a != index:
			pull += (keyed[a] - rest[a]) * k
	return want - pull


static func density_of(e: Dictionary) -> int:
	var p: Variant = _param(e, KEY_DENSITY)
	var v: Variant = AnimProp.static_value(p) if p is Dictionary else p
	var f: float = float(v) if (v is float or v is int) else DENSITY_DEFAULT
	return clampi(int(round(f)), DENSITY_MIN, DENSITY_MAX)


static func mesh_info(e: Dictionary) -> Dictionary:
	var m: Variant = e.get(MESH_FIELD, null)
	return m if m is Dictionary else {}


static func size_of(e: Dictionary, fallback: Vector2) -> Vector2:
	var m: Dictionary = mesh_info(e)
	var w: float = float(m.get("w", 0.0))
	var h: float = float(m.get("h", 0.0))
	if w >= 1.0 and h >= 1.0:
		return Vector2(w, h)
	return fallback


static func alpha_image(path: String) -> Image:
	if path.is_empty():
		return null
	if _alpha_cache.has(path):
		return _alpha_cache[path]
	var img: Image = null
	if FileAccess.file_exists(path):
		var loaded: Image = Image.new()
		if loaded.load(path) == OK and not loaded.is_empty():
			loaded.convert(Image.FORMAT_RGBA8)
			var longest: int = maxi(loaded.get_width(), loaded.get_height())
			if longest > ALPHA_SIDE:
				var k: float = float(ALPHA_SIDE) / float(longest)
				loaded.resize(maxi(int(round(float(loaded.get_width()) * k)), 1), maxi(int(round(float(loaded.get_height()) * k)), 1), Image.INTERPOLATE_BILINEAR)
			img = loaded
	if _alpha_cache.size() > CACHE_MAX:
		_alpha_cache = {}
	_alpha_cache[path] = img
	return img


static func shape_code(info: Dictionary) -> String:
	var v: Variant = info.get(SHAPE_FIELD, "")
	return String(v) if v is String else ""


static func encode_shape(img: Image) -> Dictionary:
	if img == null or img.is_empty():
		return {}
	var a: Image = img.duplicate() as Image
	a.convert(Image.FORMAT_RGBA8)
	var longest: int = maxi(a.get_width(), a.get_height())
	if longest > ALPHA_SIDE:
		var k: float = float(ALPHA_SIDE) / float(longest)
		a.resize(maxi(int(round(float(a.get_width()) * k)), 1), maxi(int(round(float(a.get_height()) * k)), 1), Image.INTERPOLATE_BILINEAR)
	var w: int = a.get_width()
	var h: int = a.get_height()
	var data: PackedByteArray = a.get_data()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(w * h)
	var full: bool = true
	var empty: bool = true
	for i: int in w * h:
		if data[i * 4 + 3] > SHAPE_CUT:
			bytes[i] = 255
			empty = false
		else:
			full = false
	if full:
		return {"full": true}
	if empty:
		return {"empty": true}
	return {SHAPE_FIELD: Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_DEFLATE)), "sw": w, "sh": h}


static func shape_image(info: Dictionary) -> Image:
	var code: String = shape_code(info)
	var w: int = int(info.get("sw", 0))
	var h: int = int(info.get("sh", 0))
	if code.is_empty() or w < 1 or h < 1:
		return null
	var key: String = str(w) + "x" + str(h) + "|" + str(hash(code))
	if _shape_cache.has(key):
		return _shape_cache[key]
	var raw: PackedByteArray = Marshalls.base64_to_raw(code).decompress(w * h, FileAccess.COMPRESSION_DEFLATE)
	var img: Image = null
	if raw.size() == w * h:
		var la: PackedByteArray = PackedByteArray()
		la.resize(w * h * 2)
		for i: int in w * h:
			la[i * 2] = 255
			la[i * 2 + 1] = raw[i]
		img = Image.create_from_data(w, h, false, Image.FORMAT_LA8, la)
	if _shape_cache.size() > CACHE_MAX:
		_shape_cache = {}
	_shape_cache[key] = img
	return img


static func shape_cover(info: Dictionary) -> float:
	var img: Image = shape_image(info)
	if img == null:
		return 1.0
	var on: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a > ALPHA_MIN:
				on += 1
	return float(on) / float(maxi(img.get_width() * img.get_height(), 1))


static func mesh_for(size: Vector2, cells: int, alpha_path: String, shape_info: Dictionary = {}, expand: float = 0.0) -> Dictionary:
	var code: String = shape_code(shape_info)
	var key: String = "%.3f|%.3f|%d|%s" % [size.x, size.y, cells, alpha_path]
	if not code.is_empty():
		key += "|shape" + str(int(shape_info.get("sw", 0))) + "x" + str(int(shape_info.get("sh", 0))) + ":" + str(hash(code))
	if expand > 0.0:
		key += "|grow%.2f" % expand
	var hit: Variant = _mesh_cache.get(key, null)
	if hit is Dictionary:
		return hit
	var made: Dictionary = build_mesh(size, cells, shape_image(shape_info) if not code.is_empty() else alpha_image(alpha_path), expand)
	made["key"] = key
	if _mesh_cache.size() > CACHE_MAX:
		_mesh_cache = {}
	_mesh_cache[key] = made
	return made


static func _cell_has_alpha(alpha: Image, size: Vector2, r: Rect2) -> bool:
	if alpha == null:
		return true
	var aw: int = alpha.get_width()
	var ah: int = alpha.get_height()
	var x0: int = clampi(int(floor(r.position.x / size.x * float(aw))), 0, aw - 1)
	var y0: int = clampi(int(floor(r.position.y / size.y * float(ah))), 0, ah - 1)
	var x1: int = clampi(int(ceil(r.end.x / size.x * float(aw))), x0 + 1, aw)
	var y1: int = clampi(int(ceil(r.end.y / size.y * float(ah))), y0 + 1, ah)
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			if alpha.get_pixel(x, y).a > ALPHA_MIN:
				return true
	return false


static func build_mesh(size: Vector2, cells: int, alpha: Image, expand: float = 0.0) -> Dictionary:
	var w: float = maxf(size.x, 1.0)
	var h: float = maxf(size.y, 1.0)
	var step: float = maxf(w, h) / float(clampi(cells, 1, DENSITY_MAX))
	var nx: int = maxi(int(round(w / step)), 1)
	var ny: int = maxi(int(round(h / step)), 1)
	var sx: float = w / float(nx)
	var sy: float = h / float(ny)
	var keep: PackedByteArray = PackedByteArray()
	keep.resize(nx * ny)
	for cy: int in ny:
		for cx: int in nx:
			keep[cy * nx + cx] = 1 if _cell_has_alpha(alpha, Vector2(w, h), Rect2(float(cx) * sx, float(cy) * sy, sx, sy).grow(maxf(expand, 0.0))) else 0
	var ids: PackedInt32Array = PackedInt32Array()
	ids.resize((nx + 1) * (ny + 1))
	ids.fill(-1)
	for cy2: int in ny:
		for cx2: int in nx:
			if keep[cy2 * nx + cx2] == 0:
				continue
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				ids[(cy2 + corner.y) * (nx + 1) + cx2 + corner.x] = 0
	var verts: PackedVector2Array = PackedVector2Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var across: bool = nx > ny
	var outer: int = (nx + 1) if across else (ny + 1)
	var inner: int = (ny + 1) if across else (nx + 1)
	for o: int in outer:
		for q: int in inner:
			var vx: int = o if across else q
			var vy: int = q if across else o
			var gi: int = vy * (nx + 1) + vx
			if ids[gi] < 0:
				continue
			ids[gi] = verts.size()
			var px: Vector2 = Vector2(float(vx) * sx, float(vy) * sy)
			verts.append(px - Vector2(w, h) * 0.5)
			uv.append(Vector2(px.x / w, px.y / h))
	var tris: PackedInt32Array = PackedInt32Array()
	for cy3: int in ny:
		for cx3: int in nx:
			if keep[cy3 * nx + cx3] == 0:
				continue
			var v00: int = ids[cy3 * (nx + 1) + cx3]
			var v10: int = ids[cy3 * (nx + 1) + cx3 + 1]
			var v01: int = ids[(cy3 + 1) * (nx + 1) + cx3]
			var v11: int = ids[(cy3 + 1) * (nx + 1) + cx3 + 1]
			tris.append_array(PackedInt32Array([v00, v10, v11, v00, v11, v01]))
	return {"verts": verts, "uv": uv, "tris": tris, "size": Vector2(w, h), "nx": nx, "ny": ny}


static func bary(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0: Vector2 = b - a
	var v1: Vector2 = c - a
	var v2: Vector2 = p - a
	var den: float = v0.x * v1.y - v1.x * v0.y
	if absf(den) < TINY:
		return Vector3(-1.0e9, -1.0e9, -1.0e9)
	var bv: float = (v2.x * v1.y - v1.x * v2.y) / den
	var cv: float = (v0.x * v2.y - v2.x * v0.y) / den
	return Vector3(1.0 - bv - cv, bv, cv)


static func locate(verts: PackedVector2Array, tris: PackedInt32Array, p: Vector2) -> Dictionary:
	var best: int = -1
	var best_w: Vector3 = Vector3.ZERO
	var best_out: float = INF
	for t: int in tris.size() / 3:
		var w: Vector3 = bary(p, verts[tris[t * 3]], verts[tris[t * 3 + 1]], verts[tris[t * 3 + 2]])
		if w.x < -1.0e8:
			continue
		var outside: float = maxf(maxf(-w.x, -w.y), -w.z)
		if outside < best_out:
			best_out = outside
			best = t
			best_w = w
			if outside <= 0.0:
				break
	if best < 0:
		return {}
	if best_out > 0.0:
		best_w = Vector3(maxf(best_w.x, 0.0), maxf(best_w.y, 0.0), maxf(best_w.z, 0.0))
		var sum: float = best_w.x + best_w.y + best_w.z
		best_w = best_w / sum if sum > TINY else Vector3(1.0, 0.0, 0.0)
	return {"tri": best, "w": best_w, "inside": best_out <= 0.000001}


static func reach_of(mesh: Dictionary) -> float:
	var msize: Vector2 = mesh.get("size", Vector2.ONE)
	var cell: float = maxf(msize.x / float(maxi(int(mesh.get("nx", 1)), 1)), msize.y / float(maxi(int(mesh.get("ny", 1)), 1)))
	return cell * BEND_REACH_CELLS


static func solver_key(mesh: Dictionary, rest_pins: PackedVector2Array, hold_w: PackedFloat64Array, kinds: PackedInt32Array, rigid: PackedFloat64Array) -> String:
	var key: String = String(mesh.get("key", "")) + "|" + str(rest_pins) + "|" + str(hash(hold_w))
	var bent: bool = false
	for k: int in kinds:
		if k != KIND_POSITION:
			bent = true
	if bent:
		key += "|k" + str(kinds)
	if not rigid.is_empty():
		key += "|r" + str(hash(rigid))
	return key


static func solver_for(mesh: Dictionary, rest_pins: PackedVector2Array, hold_w: PackedFloat64Array = PackedFloat64Array(), kinds: PackedInt32Array = PackedInt32Array(), rigid: PackedFloat64Array = PackedFloat64Array()) -> Dictionary:
	var key: String = solver_key(mesh, rest_pins, hold_w, kinds, rigid)
	var hit: Variant = _solver_cache.get(key, null)
	if hit is Dictionary:
		return hit
	if _pending.has(key):
		_finish_job(key)
		var done: Variant = _solver_cache.get(key, null)
		if done is Dictionary:
			return done
	var made: Dictionary = build_solver(mesh, rest_pins, hold_w, kinds, rigid)
	PuppetSolve.factor_count += 1
	PuppetSolve.last_factor_ms = float(made.get("ms", 0.0))
	made["key"] = key
	if _solver_cache.size() > CACHE_MAX:
		_solver_cache = {}
	_solver_cache[key] = made
	return made


static func _bind(mesh: Dictionary, p: Vector2) -> Dictionary:
	var verts: PackedVector2Array = mesh["verts"]
	var tris: PackedInt32Array = mesh["tris"]
	var got: Dictionary = locate(verts, tris, p)
	if got.is_empty():
		return {"v": PackedInt32Array(), "w": PackedFloat64Array()}
	var t: int = int(got["tri"])
	var w: Vector3 = got["w"]
	return {"v": PackedInt32Array([tris[t * 3], tris[t * 3 + 1], tris[t * 3 + 2]]), "w": PackedFloat64Array([w.x, w.y, w.z]), "tri": t}


static func build_solver(mesh: Dictionary, rest_pins: PackedVector2Array, hold_w: PackedFloat64Array = PackedFloat64Array(), kinds: PackedInt32Array = PackedInt32Array(), rigid: PackedFloat64Array = PackedFloat64Array()) -> Dictionary:
	var binds: Array[Dictionary] = []
	for p: Vector2 in rest_pins:
		binds.append(_bind(mesh, p))
	return PuppetSolve.build(mesh, rest_pins, binds, kinds, hold_w, rigid, reach_of(mesh))


static func factor_count() -> int:
	return PuppetSolve.factor_count


static func solve_count() -> int:
	return PuppetSolve.solve_count


static func deform(mesh: Dictionary, rest_pins: PackedVector2Array, pins: PackedVector2Array, hold_w: PackedFloat64Array = PackedFloat64Array(), kinds: PackedInt32Array = PackedInt32Array(), turns: PackedVector2Array = PackedVector2Array(), rigid: PackedFloat64Array = PackedFloat64Array()) -> PackedVector2Array:
	var verts: PackedVector2Array = mesh["verts"]
	if rest_pins.is_empty() or pins.size() != rest_pins.size() or verts.is_empty():
		return verts
	var skey: String = solver_key(mesh, rest_pins, hold_w, kinds, rigid)
	var rkey: String = skey + "|" + str(pins) + ("|t" + str(turns) if not turns.is_empty() else "")
	var hit: Variant = _result_cache.get(rkey, null)
	if hit is PackedVector2Array:
		return hit
	var out: PackedVector2Array = PackedVector2Array()
	if PuppetSolve.any_bends(kinds):
		var full_turns: PackedVector2Array = turns.duplicate()
		var still: PackedVector2Array = PackedVector2Array()
		while full_turns.size() < rest_pins.size():
			full_turns.append(TURN_REST)
		var turned: bool = false
		for i: int in rest_pins.size():
			still.append(TURN_REST)
			if full_turns[i] != TURN_REST and i < kinds.size() and PuppetSolve.bends(kinds[i]):
				turned = true
		var base: PackedVector2Array = deform(mesh, rest_pins, pins, hold_w, PuppetSolve.plain_kinds(kinds), PackedVector2Array(), rigid)
		out = base.duplicate()
		var only_bends: bool = true
		for k: int in kinds:
			if PuppetSolve.moves(k):
				only_bends = false
		if turned or only_bends:
			var solver: Dictionary = solver_for(mesh, rest_pins, hold_w, kinds, rigid)
			var moved: PackedVector2Array = PuppetSolve.run(solver, verts, rest_pins, pins, PuppetSolve.relative_mats(solver, base, full_turns))
			var held: PackedVector2Array = PuppetSolve.run(solver, verts, rest_pins, pins, PuppetSolve.relative_mats(solver, base, still))
			for v: int in mini(out.size(), mini(moved.size(), held.size())):
				out[v] = base[v] + moved[v] - held[v]
	else:
		out = PuppetSolve.run(solver_for(mesh, rest_pins, hold_w, kinds, rigid), verts, rest_pins, pins, PackedVector2Array())
	if _result_cache.size() > RESULT_MAX:
		_result_cache = {}
	_result_cache[rkey] = out
	return out


static func mesh_of_effect(e: Dictionary, fallback_size: Vector2) -> Dictionary:
	var info: Dictionary = mesh_info(e)
	return mesh_for(size_of(e, fallback_size), density_of(e), String(info.get("alpha", "")), info, expansion_of(e))


static func follows_frames(info: Dictionary) -> bool:
	var frames: Variant = info.get(FRAMES_FIELD, null)
	return frames is Array and not (frames as Array).is_empty()


static func info_at(info: Dictionary, local_t: float) -> Dictionary:
	if not follows_frames(info):
		return info
	var frames: Array = info[FRAMES_FIELD]
	var pick: Dictionary = frames[0]
	for fr: Variant in frames:
		if fr is Dictionary and float((fr as Dictionary).get("at", 0.0)) <= local_t + 0.0001:
			pick = fr
	var out: Dictionary = info.duplicate()
	out.erase(FRAMES_FIELD)
	if not shape_code(pick).is_empty():
		out[SHAPE_FIELD] = pick[SHAPE_FIELD]
		out["sw"] = int(pick.get("sw", 0))
		out["sh"] = int(pick.get("sh", 0))
	return out


static func mesh_at(c: Clip, e: Dictionary, t: float, fallback_size: Vector2) -> Dictionary:
	var info: Dictionary = info_at(mesh_info(e), t - c.start)
	return mesh_for(size_of(e, fallback_size), density_of(e), String(info.get("alpha", "")), info, expansion_of(e))


static func setup_at(c: Clip, e: Dictionary, t: float, fps: float, mesh: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if any_bend(e):
		out["kinds"] = kinds_of(e)
		out["turns"] = turns_at(c, e, t, fps)
	if PuppetLocks.has_locks(e):
		out["locks"] = PuppetLocks.vertex_weights(e, mesh)
		out["amount"] = clampf(value_at(c, e, PuppetLocks.KEY_AMOUNT, t, fps, PuppetLocks.AMOUNT_DEFAULT) / 100.0, 0.0, 1.0)
	return out


static func spot_of(mesh: Dictionary, deformed: PackedVector2Array, rest_p: Vector2) -> Vector2:
	var rv: PackedVector2Array = mesh["verts"]
	var tris: PackedInt32Array = mesh["tris"]
	if deformed.size() != rv.size():
		return rest_p
	var got: Dictionary = locate(rv, tris, rest_p)
	if got.is_empty():
		return rest_p
	var t: int = int(got["tri"])
	var w: Vector3 = got["w"]
	var shift: Vector2 = (deformed[tris[t * 3]] - rv[tris[t * 3]]) * w.x + (deformed[tris[t * 3 + 1]] - rv[tris[t * 3 + 1]]) * w.y + (deformed[tris[t * 3 + 2]] - rv[tris[t * 3 + 2]]) * w.z
	return rest_p + shift


static func deformed_at(c: Clip, e: Dictionary, t: float, fps: float, fallback_size: Vector2) -> Dictionary:
	var mesh: Dictionary = mesh_at(c, e, t, fallback_size)
	var rest: PackedVector2Array = rest_of(e)
	var pins: PackedVector2Array = linked_pins_at(c, e, t, fps)
	var holds: Dictionary = holds_at(c, e, t, fps)
	var overlaps: Dictionary = overlaps_at(c, e, t, fps)
	var setup: Dictionary = setup_at(c, e, t, fps, mesh)
	var verts: PackedVector2Array = PackedVector2Array()
	var drafted: bool = false
	if draft_ok and (mesh["verts"] as PackedVector2Array).size() >= DRAFT_FROM and density_of(e) > DRAFT_CELLS and not ready_for(mesh, rest, holds, setup):
		var info: Dictionary = info_at(mesh_info(e), t - c.start)
		var coarse: Dictionary = mesh_for(size_of(e, fallback_size), DRAFT_CELLS, String(info.get("alpha", "")), info, expansion_of(e))
		verts = draft_map(mesh, coarse, solve(coarse, rest, pins, holds, setup_at(c, e, t, fps, coarse)))
		draft_count += 1
		drafted = true
	else:
		verts = solve(mesh, rest, pins, holds, setup)
	var shown: PackedVector2Array = pins
	var kinds: PackedInt32Array = setup.get("kinds", PackedInt32Array())
	if not kinds.is_empty():
		shown = pins.duplicate()
		for i: int in mini(kinds.size(), shown.size()):
			if kinds[i] == KIND_BEND:
				shown[i] = spot_of(mesh, verts, rest[i])
	return {"mesh": mesh, "verts": verts, "pins": shown, "rest": rest, "holds": holds, "overlaps": overlaps, "drawn": draw_order(mesh, overlaps), "setup": setup, "draft": drafted}


static func hold_weights(mesh: Dictionary, holds: Dictionary) -> PackedFloat64Array:
	var verts: PackedVector2Array = mesh["verts"]
	var at: PackedVector2Array = holds.get("at", PackedVector2Array())
	var r: PackedFloat64Array = holds.get("r", PackedFloat64Array())
	var key: String = "w|" + String(mesh.get("key", "")) + "|" + str(at) + "|" + str(r)
	var hit: Variant = _weights_cache.get(key, null)
	if hit is PackedFloat64Array:
		return hit
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(verts.size())
	for v: int in verts.size():
		var best: float = 0.0
		for i: int in mini(at.size(), r.size()):
			if r[i] <= 0.0:
				continue
			var x: float = verts[v].distance_to(at[i]) / r[i]
			if x >= 1.0:
				continue
			best = maxf(best, 1.0 if x <= HOLD_CORE else 1.0 - smoothstep(HOLD_CORE, 1.0, x))
		out[v] = HOLD_STIFF * best
	_keep_weights(key, out)
	return out


static func _keep_weights(key: String, v: PackedFloat64Array) -> void:
	if _weights_cache.size() > RESULT_MAX:
		_weights_cache = {}
	_weights_cache[key] = v


static func hold_blend(mesh: Dictionary, holds: Dictionary) -> PackedFloat64Array:
	var verts: PackedVector2Array = mesh["verts"]
	var at: PackedVector2Array = holds.get("at", PackedVector2Array())
	var r: PackedFloat64Array = holds.get("r", PackedFloat64Array())
	var a: PackedFloat64Array = holds.get("a", PackedFloat64Array())
	var key: String = "b|" + String(mesh.get("key", "")) + "|" + str(at) + "|" + str(r) + "|" + str(a)
	var hit: Variant = _weights_cache.get(key, null)
	if hit is PackedFloat64Array:
		return hit
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(verts.size())
	var n: int = mini(at.size(), mini(r.size(), a.size()))
	for v: int in verts.size():
		var num: float = 0.0
		var den: float = 0.0
		for i: int in n:
			var x: float = verts[v].distance_to(at[i]) / maxf(r[i], 1.0)
			var g: float = 1.0 / pow(1.0 + x * x, 2.0)
			num += a[i] * g
			den += g
		out[v] = num / den if den > TINY else 0.0
	_keep_weights(key, out)
	return out


static func solve_plan(mesh: Dictionary, rest: PackedVector2Array, holds: Dictionary, setup: Dictionary) -> Dictionary:
	var kinds: PackedInt32Array = setup.get("kinds", PackedInt32Array())
	var turns: PackedVector2Array = setup.get("turns", PackedVector2Array())
	var lockw: PackedFloat64Array = setup.get("locks", PackedFloat64Array())
	var amount: float = clampf(float(setup.get("amount", 1.0)), 0.0, 1.0)
	var plain: Dictionary = {"kinds": kinds, "turns": turns, "kept": false, "loose": true}
	var amounts: PackedFloat64Array = holds.get("a", PackedFloat64Array())
	var any_hold: bool = false
	for k: float in amounts:
		if k > 0.0001:
			any_hold = true
	var any_lock: bool = false
	if amount > 0.0001:
		for lw: float in lockw:
			if lw > 0.0:
				any_lock = true
				break
	if rest.is_empty() or (not any_hold and not any_lock):
		return plain
	var anchor: PackedFloat64Array = hold_weights(mesh, holds) if any_hold else PackedFloat64Array()
	var rigid: PackedFloat64Array = PackedFloat64Array()
	if any_lock:
		var la: PackedFloat64Array = PuppetLocks.anchors(lockw)
		if anchor.is_empty():
			anchor = la
		else:
			anchor = anchor.duplicate()
			for i: int in mini(anchor.size(), la.size()):
				anchor[i] = maxf(anchor[i], la[i])
		rigid = lockw
	var mix: PackedFloat64Array = hold_blend(mesh, holds) if any_hold else PackedFloat64Array()
	if any_lock:
		if mix.is_empty():
			mix = PackedFloat64Array()
			mix.resize((mesh["verts"] as PackedVector2Array).size())
			mix.fill(amount)
		else:
			mix = mix.duplicate()
			for j: int in mix.size():
				mix[j] = maxf(mix[j], amount)
	var whole: bool = true
	for mv: float in mix:
		if mv < 1.0:
			whole = false
			break
	return {"kinds": kinds, "turns": turns, "kept": true, "loose": not whole, "anchor": anchor, "rigid": rigid, "mix": mix}


static func solve(mesh: Dictionary, rest: PackedVector2Array, pins: PackedVector2Array, holds: Dictionary = {}, setup: Dictionary = {}) -> PackedVector2Array:
	var pl: Dictionary = solve_plan(mesh, rest, holds, setup)
	var kinds: PackedInt32Array = pl["kinds"]
	var turns: PackedVector2Array = pl["turns"]
	if not bool(pl["kept"]):
		return deform(mesh, rest, pins, PackedFloat64Array(), kinds, turns)
	var kept: PackedVector2Array = deform(mesh, rest, pins, pl["anchor"], kinds, turns, pl["rigid"])
	if not bool(pl["loose"]):
		return kept
	var mix: PackedFloat64Array = pl["mix"]
	var loose: PackedVector2Array = deform(mesh, rest, pins, PackedFloat64Array(), kinds, turns)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(loose.size())
	for v: int in loose.size():
		out[v] = loose[v].lerp(kept[v], mix[v]) if v < kept.size() else loose[v]
	return out


static func harvest() -> void:
	for key: Variant in _pending.keys():
		var job: Dictionary = _pending[key]
		if not WorkerThreadPool.is_task_completed(int(job["task"])):
			continue
		_finish_job(String(key))


static func _finish_job(key: String) -> void:
	var job: Dictionary = _pending.get(key, {})
	if job.is_empty():
		return
	WorkerThreadPool.wait_for_task_completion(int(job["task"]))
	_pending.erase(key)
	var holder: Dictionary = job["out"]
	var made: Variant = holder.get("solver", null)
	if made is Dictionary:
		PuppetSolve.factor_count += 1
		(made as Dictionary)["key"] = key
		if _solver_cache.size() > CACHE_MAX:
			_solver_cache = {}
		_solver_cache[key] = made


static func _build_into(holder: Dictionary, mesh: Dictionary, rest_pins: PackedVector2Array, binds: Array[Dictionary], kinds: PackedInt32Array, hold_w: PackedFloat64Array, rigid: PackedFloat64Array, reach: float) -> void:
	holder["solver"] = PuppetSolve.build(mesh, rest_pins, binds, kinds, hold_w, rigid, reach)


static func prepare(mesh: Dictionary, rest_pins: PackedVector2Array, hold_w: PackedFloat64Array, kinds: PackedInt32Array, rigid: PackedFloat64Array) -> bool:
	var key: String = solver_key(mesh, rest_pins, hold_w, kinds, rigid)
	if _solver_cache.has(key):
		return true
	if _pending.has(key):
		if WorkerThreadPool.is_task_completed(int((_pending[key] as Dictionary)["task"])):
			_finish_job(key)
			return _solver_cache.has(key)
		return false
	var binds: Array[Dictionary] = []
	for p: Vector2 in rest_pins:
		binds.append(_bind(mesh, p))
	var holder: Dictionary = {}
	var task: int = WorkerThreadPool.add_task(_build_into.bind(holder, mesh, rest_pins, binds, kinds, hold_w, rigid, reach_of(mesh)), false, "Puppet factor")
	_pending[key] = {"task": task, "out": holder}
	return false


static func ready_for(mesh: Dictionary, rest: PackedVector2Array, holds: Dictionary, setup: Dictionary) -> bool:
	if rest.is_empty():
		return true
	var pl: Dictionary = solve_plan(mesh, rest, holds, setup)
	var kinds: PackedInt32Array = pl["kinds"]
	var ok: bool = true
	var kind_sets: Array[PackedInt32Array] = [kinds]
	if PuppetSolve.any_bends(kinds):
		kind_sets.append(PuppetSolve.plain_kinds(kinds))
	for ks: PackedInt32Array in kind_sets:
		if bool(pl["kept"]):
			ok = prepare(mesh, rest, pl["anchor"], ks, pl["rigid"]) and ok
		if bool(pl["loose"]):
			ok = prepare(mesh, rest, PackedFloat64Array(), ks, PackedFloat64Array()) and ok
	return ok


static func busy() -> bool:
	harvest()
	return not _pending.is_empty()


static func wait_all() -> void:
	for key: Variant in _pending.keys():
		_finish_job(String(key))


static func draft_map(mesh: Dictionary, coarse: Dictionary, coarse_verts: PackedVector2Array) -> PackedVector2Array:
	var key: String = String(mesh.get("key", "")) + "|" + String(coarse.get("key", ""))
	var hit: Variant = _draft_cache.get(key, null)
	var map: Dictionary = hit if hit is Dictionary else {}
	if map.is_empty():
		map = _draft_weights(mesh, coarse)
		if _draft_cache.size() > CACHE_MAX:
			_draft_cache = {}
		_draft_cache[key] = map
	var tri_of: PackedInt32Array = map["tri"]
	var wts: PackedVector3Array = map["w"]
	var ctris: PackedInt32Array = coarse["tris"]
	var rv: PackedVector2Array = mesh["verts"]
	var crv: PackedVector2Array = coarse["verts"]
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(rv.size())
	for v: int in rv.size():
		var t: int = tri_of[v]
		if t < 0 or coarse_verts.size() != crv.size():
			out[v] = rv[v]
			continue
		var w: Vector3 = wts[v]
		var a: int = ctris[t * 3]
		var b: int = ctris[t * 3 + 1]
		var c: int = ctris[t * 3 + 2]
		out[v] = rv[v] + (coarse_verts[a] - crv[a]) * w.x + (coarse_verts[b] - crv[b]) * w.y + (coarse_verts[c] - crv[c]) * w.z
	return out


static func _draft_weights(mesh: Dictionary, coarse: Dictionary) -> Dictionary:
	var rv: PackedVector2Array = mesh["verts"]
	var crv: PackedVector2Array = coarse["verts"]
	var ctris: PackedInt32Array = coarse["tris"]
	var size: Vector2 = coarse["size"]
	var nx: int = maxi(int(coarse.get("nx", 1)), 1)
	var ny: int = maxi(int(coarse.get("ny", 1)), 1)
	var cell_tri: PackedInt32Array = PackedInt32Array()
	cell_tri.resize(nx * ny)
	cell_tri.fill(-1)
	var cell: Vector2 = Vector2(size.x / float(nx), size.y / float(ny))
	for t: int in ctris.size() / 6:
		var mid: Vector2 = (crv[ctris[t * 6]] + crv[ctris[t * 6 + 1]] + crv[ctris[t * 6 + 2]]) / 3.0 + size * 0.5
		var cx: int = clampi(int(floor(mid.x / cell.x)), 0, nx - 1)
		var cy: int = clampi(int(floor(mid.y / cell.y)), 0, ny - 1)
		cell_tri[cy * nx + cx] = t * 2
	var tri_of: PackedInt32Array = PackedInt32Array()
	tri_of.resize(rv.size())
	var wts: PackedVector3Array = PackedVector3Array()
	wts.resize(rv.size())
	for v: int in rv.size():
		var p: Vector2 = rv[v]
		var q: Vector2 = p + size * 0.5
		var cx2: int = clampi(int(floor(q.x / cell.x)), 0, nx - 1)
		var cy2: int = clampi(int(floor(q.y / cell.y)), 0, ny - 1)
		var first: int = cell_tri[cy2 * nx + cx2]
		var found: int = -1
		var fw: Vector3 = Vector3.ZERO
		if first >= 0:
			for t2: int in [first, first + 1]:
				var w: Vector3 = bary(p, crv[ctris[t2 * 3]], crv[ctris[t2 * 3 + 1]], crv[ctris[t2 * 3 + 2]])
				if w.x > -0.0001 and w.y > -0.0001 and w.z > -0.0001:
					found = t2
					fw = w
					break
		if found < 0:
			var got: Dictionary = locate(crv, ctris, p)
			if not got.is_empty():
				found = int(got["tri"])
				fw = got["w"]
		tri_of[v] = found
		wts[v] = fw
	return {"tri": tri_of, "w": wts}


static func locate_top(verts: PackedVector2Array, tris: PackedInt32Array, p: Vector2) -> Dictionary:
	var t: int = tris.size() / 3 - 1
	while t >= 0:
		var w: Vector3 = bary(p, verts[tris[t * 3]], verts[tris[t * 3 + 1]], verts[tris[t * 3 + 2]])
		if w.x > -1.0e8 and w.x >= 0.0 and w.y >= 0.0 and w.z >= 0.0:
			return {"tri": t, "w": w, "inside": true}
		t -= 1
	return locate(verts, tris, p)


static func rest_point(mesh: Dictionary, deformed: PackedVector2Array, p: Vector2, drawn: PackedInt32Array = PackedInt32Array()) -> Vector2:
	var top: bool = not drawn.is_empty() and drawn.size() == (mesh["tris"] as PackedInt32Array).size()
	var tris: PackedInt32Array = drawn if top else mesh["tris"]
	var got: Dictionary = locate_top(deformed, tris, p) if top else locate(deformed, tris, p)
	if got.is_empty() or not bool(got["inside"]):
		return p
	var t: int = int(got["tri"])
	var w: Vector3 = got["w"]
	var rv: PackedVector2Array = mesh["verts"]
	return rv[tris[t * 3]] * w.x + rv[tris[t * 3 + 1]] * w.y + rv[tris[t * 3 + 2]] * w.z


static func rotation_at(mesh: Dictionary, deformed: PackedVector2Array, rest_p: Vector2) -> float:
	var rv: PackedVector2Array = mesh["verts"]
	var tris: PackedInt32Array = mesh["tris"]
	var got: Dictionary = locate(rv, tris, rest_p)
	if got.is_empty() or deformed.size() != rv.size():
		return 0.0
	var t: int = int(got["tri"])
	var a: int = tris[t * 3]
	var b: int = tris[t * 3 + 1]
	var c: int = tris[t * 3 + 2]
	var r: Transform2D = Transform2D(rv[b] - rv[a], rv[c] - rv[a], Vector2.ZERO)
	var d: Transform2D = Transform2D(deformed[b] - deformed[a], deformed[c] - deformed[a], Vector2.ZERO)
	if absf(r.determinant()) < TINY:
		return 0.0
	var m: Transform2D = d * r.affine_inverse()
	return atan2(m.x.y - m.y.x, m.x.x + m.y.y)


static func pin_frame(c: Clip, pin: int, t: float, fps: float, with_rotation: bool) -> Variant:
	var e: Dictionary = effect_of(c)
	if e.is_empty():
		return null
	var rest: PackedVector2Array = rest_of(e)
	if pin < 0 or pin >= rest.size():
		return null
	if not with_rotation and not any_bend(e):
		return Transform2D(0.0, linked_pins_at(c, e, t, fps)[pin])
	var made: Dictionary = deformed_at(c, e, t, fps, size_of(e, Vector2(1920.0, 1080.0)))
	var pins: PackedVector2Array = made["pins"]
	var angle: float = rotation_at(made["mesh"], made["verts"], rest[pin]) if with_rotation else 0.0
	return Transform2D(angle, pins[pin])

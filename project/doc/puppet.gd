extends RefCounted

const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const EFFECT_ID := "puppet"
const KEY_PINS := "pins"
const KEY_REST := "rest"
const KEY_DENSITY := "density"
const KEY_HOLDS := "holds"
const KEY_LINKS := "links"
const KEY_OVERLAPS := "overlaps"
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
static var factor_count: int = 0
static var solve_count: int = 0


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


static func pins_at(c: Clip, e: Dictionary, t: float, fps: float) -> PackedVector2Array:
	var keyed: PackedVector2Array = keyed_pins_at(c, e, t, fps)
	if link_count(e) == 0:
		return keyed
	return apply_links(rest_of(e), keyed, gains_at(c, e, t, fps))


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


static func mesh_for(size: Vector2, cells: int, alpha_path: String, shape_info: Dictionary = {}) -> Dictionary:
	var code: String = shape_code(shape_info)
	var key: String = "%.3f|%.3f|%d|%s" % [size.x, size.y, cells, alpha_path]
	if not code.is_empty():
		key += "|shape" + str(int(shape_info.get("sw", 0))) + "x" + str(int(shape_info.get("sh", 0))) + ":" + str(hash(code))
	var hit: Variant = _mesh_cache.get(key, null)
	if hit is Dictionary:
		return hit
	var made: Dictionary = build_mesh(size, cells, shape_image(shape_info) if not code.is_empty() else alpha_image(alpha_path))
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


static func build_mesh(size: Vector2, cells: int, alpha: Image) -> Dictionary:
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
			keep[cy * nx + cx] = 1 if _cell_has_alpha(alpha, Vector2(w, h), Rect2(float(cx) * sx, float(cy) * sy, sx, sy)) else 0
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


static func _components(n: int, tris: PackedInt32Array) -> PackedInt32Array:
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(n)
	for i: int in n:
		parent[i] = i
	for t: int in tris.size() / 3:
		for k: int in 2:
			var a: int = _root(parent, tris[t * 3])
			var b: int = _root(parent, tris[t * 3 + k + 1])
			if a != b:
				parent[maxi(a, b)] = mini(a, b)
	var comp: PackedInt32Array = PackedInt32Array()
	comp.resize(n)
	for i2: int in n:
		comp[i2] = _root(parent, i2)
	return comp


static func _root(parent: PackedInt32Array, i: int) -> int:
	var r: int = i
	while parent[r] != r:
		r = parent[r]
	var at: int = i
	while parent[at] != r:
		var nxt: int = parent[at]
		parent[at] = r
		at = nxt
	return r


static func solver_for(mesh: Dictionary, rest_pins: PackedVector2Array, hold_w: PackedFloat64Array = PackedFloat64Array()) -> Dictionary:
	var key: String = String(mesh.get("key", "")) + "|" + str(rest_pins) + "|" + str(hash(hold_w))
	var hit: Variant = _solver_cache.get(key, null)
	if hit is Dictionary:
		return hit
	var made: Dictionary = build_solver(mesh, rest_pins, hold_w)
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


static func build_solver(mesh: Dictionary, rest_pins: PackedVector2Array, hold_w: PackedFloat64Array = PackedFloat64Array()) -> Dictionary:
	factor_count += 1
	var verts: PackedVector2Array = mesh["verts"]
	var tris: PackedInt32Array = mesh["tris"]
	var n: int = verts.size()
	var edge_map: Dictionary = {}
	for t: int in tris.size() / 3:
		for k: int in 3:
			var a: int = tris[t * 3 + k]
			var b: int = tris[t * 3 + (k + 1) % 3]
			var o: int = tris[t * 3 + (k + 2) % 3]
			var ek: int = mini(a, b) * n + maxi(a, b)
			if not edge_map.has(ek):
				edge_map[ek] = [mini(a, b), maxi(a, b), PackedInt32Array()]
			var entry: Array = edge_map[ek]
			var opp: PackedInt32Array = entry[2]
			opp.append(o)
			entry[2] = opp
	var binds: Array[Dictionary] = []
	for p: Vector2 in rest_pins:
		binds.append(_bind(mesh, p))
	var comp: PackedInt32Array = _components(n, tris)
	var comp_pins: Dictionary = {}
	for i: int in binds.size():
		var bv: PackedInt32Array = binds[i]["v"]
		if bv.is_empty():
			continue
		var cid: int = comp[bv[0]]
		var list: PackedInt32Array = comp_pins.get(cid, PackedInt32Array())
		list.append(i)
		comp_pins[cid] = list
	var stiff: PackedFloat64Array = hold_w if hold_w.size() == n else PackedFloat64Array()
	var comp_holds: Dictionary = {}
	for sv: int in stiff.size():
		if stiff[sv] > 0.0:
			comp_holds[comp[sv]] = true
	var held: PackedInt32Array = PackedInt32Array()
	held.resize(n)
	for v: int in n:
		var pins_here: PackedInt32Array = comp_pins.get(comp[v], PackedInt32Array())
		held[v] = 1 if pins_here.size() + (1 if comp_holds.has(comp[v]) else 0) < 2 else 0
	var edges: Array = []
	var bw1: int = 1
	var bw2: int = 1
	for ev: Variant in edge_map.values():
		var ea: Array = ev
		var i0: int = ea[0]
		var j0: int = ea[1]
		var nb: PackedInt32Array = PackedInt32Array([i0, j0])
		nb.append_array(ea[2] as PackedInt32Array)
		var lo: int = nb[0]
		var hi: int = nb[0]
		for x: int in nb:
			lo = mini(lo, x)
			hi = maxi(hi, x)
		bw1 = maxi(bw1, (hi - lo) * 2 + 1)
		bw2 = maxi(bw2, j0 - i0)
		edges.append(_edge_rows(verts, nb))
	for b: Dictionary in binds:
		var bv2: PackedInt32Array = b["v"]
		for x2: int in bv2:
			for y2: int in bv2:
				bw1 = maxi(bw1, absi(x2 - y2) * 2 + 1)
				bw2 = maxi(bw2, absi(x2 - y2))
	var a1: PackedFloat64Array = PackedFloat64Array()
	a1.resize(2 * n * (bw1 + 1))
	var a2: PackedFloat64Array = PackedFloat64Array()
	a2.resize(n * (bw2 + 1))
	for ed: Dictionary in edges:
		var nb2: PackedInt32Array = ed["nb"]
		var h0: PackedFloat64Array = ed["h0"]
		var h1: PackedFloat64Array = ed["h1"]
		var m2: int = nb2.size() * 2
		for r: int in m2:
			var gr: int = 2 * nb2[r / 2] + r % 2
			for q: int in m2:
				var gq: int = 2 * nb2[q / 2] + q % 2
				if gq > gr:
					continue
				_band_add(a1, bw1, gr, gq, h0[r] * h0[q] + h1[r] * h1[q])
		var ei: int = nb2[0]
		var ej: int = nb2[1]
		_band_add(a2, bw2, ei, ei, 1.0)
		_band_add(a2, bw2, ej, ej, 1.0)
		_band_add(a2, bw2, ej, ei, -1.0)
	for b2: Dictionary in binds:
		var bv3: PackedInt32Array = b2["v"]
		var bw: PackedFloat64Array = b2["w"]
		var comp_ok: bool = not bv3.is_empty() and held[bv3[0]] == 0
		if not comp_ok:
			continue
		for x3: int in bv3.size():
			for y3: int in bv3.size():
				if bv3[y3] > bv3[x3]:
					continue
				var wv: float = PIN_WEIGHT * bw[x3] * bw[y3]
				_band_add(a1, bw1, 2 * bv3[x3], 2 * bv3[y3], wv)
				_band_add(a1, bw1, 2 * bv3[x3] + 1, 2 * bv3[y3] + 1, wv)
				_band_add(a2, bw2, bv3[x3], bv3[y3], wv)
	for v2: int in n:
		var hold: float = HOLD_WEIGHT if held[v2] == 1 else (stiff[v2] if not stiff.is_empty() else 0.0)
		_band_add(a1, bw1, 2 * v2, 2 * v2, hold + TINY)
		_band_add(a1, bw1, 2 * v2 + 1, 2 * v2 + 1, hold + TINY)
		_band_add(a2, bw2, v2, v2, hold + TINY)
	_band_factor(a1, 2 * n, bw1)
	_band_factor(a2, n, bw2)
	return {"n": n, "edges": edges, "binds": binds, "held": held, "stiff": stiff, "comp": comp, "comp_pins": comp_pins, "l1": a1, "bw1": bw1, "l2": a2, "bw2": bw2}


static func _edge_rows(verts: PackedVector2Array, nb: PackedInt32Array) -> Dictionary:
	var m: int = nb.size()
	var base: Vector2 = verts[nb[0]]
	var g: Array[PackedFloat64Array] = []
	for k: int in m:
		var v: Vector2 = verts[nb[k]] - base
		g.append(PackedFloat64Array([v.x, v.y, 1.0, 0.0]))
		g.append(PackedFloat64Array([v.y, -v.x, 0.0, 1.0]))
	var gtg: Array[PackedFloat64Array] = []
	for r: int in 4:
		var row: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
		for q: int in 4:
			var sum: float = 0.0
			for k2: int in g.size():
				sum += g[k2][r] * g[k2][q]
			row[q] = sum
		gtg.append(row)
	var inv: Array[PackedFloat64Array] = _inverse4(gtg)
	var p0: PackedFloat64Array = PackedFloat64Array()
	var p1: PackedFloat64Array = PackedFloat64Array()
	p0.resize(2 * m)
	p1.resize(2 * m)
	for col: int in 2 * m:
		var s0: float = 0.0
		var s1: float = 0.0
		for q2: int in 4:
			s0 += inv[0][q2] * g[col][q2]
			s1 += inv[1][q2] * g[col][q2]
		p0[col] = s0
		p1[col] = s1
	var e: Vector2 = verts[nb[1]] - verts[nb[0]]
	var h0: PackedFloat64Array = PackedFloat64Array()
	var h1: PackedFloat64Array = PackedFloat64Array()
	h0.resize(2 * m)
	h1.resize(2 * m)
	for col2: int in 2 * m:
		h0[col2] = -(e.x * p0[col2] + e.y * p1[col2])
		h1[col2] = -(e.y * p0[col2] - e.x * p1[col2])
	h0[0] -= 1.0
	h0[2] += 1.0
	h1[1] -= 1.0
	h1[3] += 1.0
	return {"nb": nb, "p0": p0, "p1": p1, "h0": h0, "h1": h1, "e": e}


static func _inverse4(a: Array[PackedFloat64Array]) -> Array[PackedFloat64Array]:
	var m: Array[PackedFloat64Array] = []
	for r: int in 4:
		var row: PackedFloat64Array = PackedFloat64Array()
		row.resize(8)
		for q: int in 4:
			row[q] = a[r][q]
		row[4 + r] = 1.0
		m.append(row)
	for c: int in 4:
		var piv: int = c
		for r2: int in range(c + 1, 4):
			if absf(m[r2][c]) > absf(m[piv][c]):
				piv = r2
		if piv != c:
			var tmp: PackedFloat64Array = m[c]
			m[c] = m[piv]
			m[piv] = tmp
		var d: float = m[c][c]
		if absf(d) < 1.0e-12:
			d = 1.0e-12
		var lead: PackedFloat64Array = m[c]
		for q2: int in 8:
			lead[q2] /= d
		m[c] = lead
		for r3: int in 4:
			if r3 == c:
				continue
			var f: float = m[r3][c]
			if f == 0.0:
				continue
			var row3: PackedFloat64Array = m[r3]
			for q3: int in 8:
				row3[q3] -= f * lead[q3]
			m[r3] = row3
	var out: Array[PackedFloat64Array] = []
	for r4: int in 4:
		out.append(m[r4].slice(4, 8))
	return out


static func _band_add(a: PackedFloat64Array, bw: int, i: int, j: int, v: float) -> void:
	if j > i:
		var t: int = i
		i = j
		j = t
	a[i * (bw + 1) + (j - i + bw)] += v


static func _band_factor(a: PackedFloat64Array, n: int, bw: int) -> void:
	var w: int = bw + 1
	for i: int in n:
		var j0: int = maxi(0, i - bw)
		for j: int in range(j0, i + 1):
			var sum: float = a[i * w + (j - i + bw)]
			var k0: int = maxi(j0, j - bw)
			var ri: int = i * w - i + bw
			var rj: int = j * w - j + bw
			for k: int in range(k0, j):
				sum -= a[ri + k] * a[rj + k]
			if i == j:
				a[ri + i] = sqrt(maxf(sum, TINY))
			else:
				a[ri + j] = sum / a[rj + j]


static func _band_solve(a: PackedFloat64Array, n: int, bw: int, b: PackedFloat64Array) -> PackedFloat64Array:
	var w: int = bw + 1
	var y: PackedFloat64Array = b.duplicate()
	for i: int in n:
		var ri: int = i * w - i + bw
		var sum: float = y[i]
		for k: int in range(maxi(0, i - bw), i):
			sum -= a[ri + k] * y[k]
		y[i] = sum / a[ri + i]
	for i2: int in range(n - 1, -1, -1):
		var sum2: float = y[i2]
		for k2: int in range(i2 + 1, mini(n, i2 + bw + 1)):
			sum2 -= a[k2 * w - k2 + bw + i2] * y[k2]
		y[i2] = sum2 / a[i2 * w - i2 + bw + i2]
	return y


static func _hold_target(solver: Dictionary, verts: PackedVector2Array, rest_pins: PackedVector2Array, pins: PackedVector2Array, v: int) -> Vector2:
	var cp: Dictionary = solver["comp_pins"]
	var comp: PackedInt32Array = solver["comp"]
	var mine: PackedInt32Array = cp.get(comp[v], PackedInt32Array())
	if mine.size() == 1:
		return verts[v] + pins[mine[0]] - rest_pins[mine[0]]
	return verts[v]


static func deform(mesh: Dictionary, rest_pins: PackedVector2Array, pins: PackedVector2Array, hold_w: PackedFloat64Array = PackedFloat64Array()) -> PackedVector2Array:
	var verts: PackedVector2Array = mesh["verts"]
	if rest_pins.is_empty() or pins.size() != rest_pins.size() or verts.is_empty():
		return verts
	var rkey: String = String(mesh.get("key", "")) + "|" + str(rest_pins) + "|" + str(pins) + "|" + str(hash(hold_w))
	var hit: Variant = _result_cache.get(rkey, null)
	if hit is PackedVector2Array:
		return hit
	var solver: Dictionary = solver_for(mesh, rest_pins, hold_w)
	solve_count += 1
	var n: int = int(solver["n"])
	var held: PackedInt32Array = solver["held"]
	var stiff: PackedFloat64Array = solver["stiff"]
	var binds: Array[Dictionary] = solver["binds"]
	var b1: PackedFloat64Array = PackedFloat64Array()
	b1.resize(2 * n)
	var bx: PackedFloat64Array = PackedFloat64Array()
	var by: PackedFloat64Array = PackedFloat64Array()
	bx.resize(n)
	by.resize(n)
	for v: int in n:
		if held[v] == 1:
			var tg: Vector2 = _hold_target(solver, verts, rest_pins, pins, v)
			b1[2 * v] += HOLD_WEIGHT * tg.x
			b1[2 * v + 1] += HOLD_WEIGHT * tg.y
			bx[v] += HOLD_WEIGHT * tg.x
			by[v] += HOLD_WEIGHT * tg.y
		elif not stiff.is_empty() and stiff[v] > 0.0:
			b1[2 * v] += stiff[v] * verts[v].x
			b1[2 * v + 1] += stiff[v] * verts[v].y
			bx[v] += stiff[v] * verts[v].x
			by[v] += stiff[v] * verts[v].y
	for i: int in binds.size():
		var bv: PackedInt32Array = binds[i]["v"]
		if bv.is_empty() or held[bv[0]] == 1:
			continue
		var bw: PackedFloat64Array = binds[i]["w"]
		for k: int in bv.size():
			b1[2 * bv[k]] += PIN_WEIGHT * bw[k] * pins[i].x
			b1[2 * bv[k] + 1] += PIN_WEIGHT * bw[k] * pins[i].y
			bx[bv[k]] += PIN_WEIGHT * bw[k] * pins[i].x
			by[bv[k]] += PIN_WEIGHT * bw[k] * pins[i].y
	var v1: PackedFloat64Array = _band_solve(solver["l1"], 2 * n, int(solver["bw1"]), b1)
	for ed: Dictionary in solver["edges"]:
		var nb: PackedInt32Array = ed["nb"]
		var p0: PackedFloat64Array = ed["p0"]
		var p1: PackedFloat64Array = ed["p1"]
		var c: float = 0.0
		var s: float = 0.0
		for q: int in nb.size():
			var x: float = v1[2 * nb[q]]
			var y: float = v1[2 * nb[q] + 1]
			c += p0[2 * q] * x + p0[2 * q + 1] * y
			s += p1[2 * q] * x + p1[2 * q + 1] * y
		var mag: float = sqrt(c * c + s * s)
		if mag > TINY:
			c /= mag
			s /= mag
		else:
			c = 1.0
			s = 0.0
		var e: Vector2 = ed["e"]
		var tx: float = c * e.x + s * e.y
		var ty: float = -s * e.x + c * e.y
		bx[nb[1]] += tx
		bx[nb[0]] -= tx
		by[nb[1]] += ty
		by[nb[0]] -= ty
	var xs: PackedFloat64Array = _band_solve(solver["l2"], n, int(solver["bw2"]), bx)
	var ys: PackedFloat64Array = _band_solve(solver["l2"], n, int(solver["bw2"]), by)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	for v2: int in n:
		out[v2] = Vector2(xs[v2], ys[v2])
	if _result_cache.size() > RESULT_MAX:
		_result_cache = {}
	_result_cache[rkey] = out
	return out


static func mesh_of_effect(e: Dictionary, fallback_size: Vector2) -> Dictionary:
	var info: Dictionary = mesh_info(e)
	return mesh_for(size_of(e, fallback_size), density_of(e), String(info.get("alpha", "")), info)


static func deformed_at(c: Clip, e: Dictionary, t: float, fps: float, fallback_size: Vector2) -> Dictionary:
	var mesh: Dictionary = mesh_of_effect(e, fallback_size)
	var rest: PackedVector2Array = rest_of(e)
	var pins: PackedVector2Array = pins_at(c, e, t, fps)
	var holds: Dictionary = holds_at(c, e, t, fps)
	var overlaps: Dictionary = overlaps_at(c, e, t, fps)
	return {"mesh": mesh, "verts": solve(mesh, rest, pins, holds), "pins": pins, "rest": rest, "holds": holds, "overlaps": overlaps, "drawn": draw_order(mesh, overlaps)}


static func hold_weights(mesh: Dictionary, holds: Dictionary) -> PackedFloat64Array:
	var verts: PackedVector2Array = mesh["verts"]
	var at: PackedVector2Array = holds.get("at", PackedVector2Array())
	var r: PackedFloat64Array = holds.get("r", PackedFloat64Array())
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
	return out


static func hold_blend(mesh: Dictionary, holds: Dictionary) -> PackedFloat64Array:
	var verts: PackedVector2Array = mesh["verts"]
	var at: PackedVector2Array = holds.get("at", PackedVector2Array())
	var r: PackedFloat64Array = holds.get("r", PackedFloat64Array())
	var a: PackedFloat64Array = holds.get("a", PackedFloat64Array())
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
	return out


static func solve(mesh: Dictionary, rest: PackedVector2Array, pins: PackedVector2Array, holds: Dictionary = {}) -> PackedVector2Array:
	var loose: PackedVector2Array = deform(mesh, rest, pins)
	var amounts: PackedFloat64Array = holds.get("a", PackedFloat64Array())
	var any: bool = false
	for k: float in amounts:
		if k > 0.0001:
			any = true
	if not any or rest.is_empty():
		return loose
	var w: PackedFloat64Array = hold_weights(mesh, holds)
	var kept: PackedVector2Array = deform(mesh, rest, pins, w)
	var mix: PackedFloat64Array = hold_blend(mesh, holds)
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(loose.size())
	for v: int in loose.size():
		out[v] = loose[v].lerp(kept[v], mix[v]) if v < kept.size() else loose[v]
	return out


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
	var pins: PackedVector2Array = pins_at(c, e, t, fps)
	var angle: float = 0.0
	if with_rotation:
		var mesh: Dictionary = mesh_of_effect(e, size_of(e, Vector2(1920.0, 1080.0)))
		angle = rotation_at(mesh, solve(mesh, rest, pins, holds_at(c, e, t, fps)), rest[pin])
	return Transform2D(angle, pins[pin])

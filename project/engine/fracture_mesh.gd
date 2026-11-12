extends RefCounted


const TAU_F := 6.28318530718


static func build(opts: Dictionary) -> Array:
	var asp: float = float(opts.get("asp", 1.777))
	var h: float = float(opts.get("h", 5.0))
	var n: int = int(opts.get("seeds", 90))
	var impact: Vector2 = opts.get("impact", Vector2(0.5, 0.45))
	var pattern: String = String(opts.get("pattern", "uniform"))
	var thick: float = float(opts.get("thickness", 0.12)) * h
	var seed: int = int(opts.get("seed", 0))
	var img: Image = opts.get("alpha_img", null)
	var athr: float = float(opts.get("alpha_threshold", 0.04))

	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 2654435761 + 1013904223

	var pts: PackedVector2Array
	if pattern == "radial":
		pts = _radial_seeds(impact, asp, rng, n)
	else:
		pts = _uniform_seeds(asp, rng, n)

	var hw: float = asp * 0.5
	var hh: float = 0.5
	var out: Array = []
	for i: int in pts.size():
		var cell: PackedVector2Array = _voronoi_cell(pts, i, hw, hh)
		if cell.size() < 3:
			continue
		var cen: Vector2 = _centroid(cell)
		var cuv := Vector2(cen.x / maxf(asp, 0.0001) + 0.5, 0.5 - cen.y)
		if img != null and _alpha_at(img, cuv) < athr:
			continue
		var r: float = 0.0
		for v: Vector2 in cell:
			r = maxf(r, (v - cen).length())
		var mesh: ArrayMesh = _extrude(cell, cen, asp, h, thick)
		if mesh.get_surface_count() == 0:
			continue
		out.append({
			"centroid": Vector3(cen.x * h, cen.y * h, 0.0),
			"mesh": mesh,
			"radius": maxf(r * h, 0.001),
			"uv_center": cuv,
		})
	return out


static func _uniform_seeds(asp: float, rng: RandomNumberGenerator, n: int) -> PackedVector2Array:
	var cols: int = maxi(int(round(sqrt(float(n) * asp))), 3)
	var rows: int = maxi(int(round(float(n) / float(cols))), 2)
	var pts := PackedVector2Array()
	var cw: float = asp / float(cols)
	var ch: float = 1.0 / float(rows)
	for ry: int in rows:
		for cx: int in cols:
			var x: float = (-asp * 0.5) + (float(cx) + 0.5 + (rng.randf() - 0.5) * 0.8) * cw
			var y: float = (-0.5) + (float(ry) + 0.5 + (rng.randf() - 0.5) * 0.8) * ch
			pts.append(Vector2(x, y))
	return pts


static func _radial_seeds(impact: Vector2, asp: float, rng: RandomNumberGenerator, n: int) -> PackedVector2Array:
	var ip := Vector2((impact.x - 0.5) * asp, 0.5 - impact.y)
	var pts := PackedVector2Array()
	pts.append(ip + Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * 0.02)
	var rings: int = 10
	var maxr: float = maxf(asp, 1.0) * 0.95
	var made: int = 1
	for _c: int in 5:
		pts.append(ip + Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * maxr * 0.10)
		made += 1
	for ring: int in range(1, rings + 1):
		var rr: float = maxr * pow(float(ring) / float(rings), 1.7)
		var count: int = maxi(ring * 4 + 5, 7)
		var a0: float = rng.randf() * TAU_F
		for a: int in count:
			var ang: float = a0 + (float(a) / float(count)) * TAU_F + (rng.randf() - 0.5) * 0.4
			var jr: float = rr * (0.82 + 0.34 * rng.randf())
			pts.append(ip + Vector2(cos(ang), sin(ang)) * jr)
			made += 1
	while made < n:
		pts.append(Vector2((rng.randf() - 0.5) * asp, rng.randf() - 0.5))
		made += 1
	return pts


static func _voronoi_cell(pts: PackedVector2Array, i: int, hw: float, hh: float) -> PackedVector2Array:
	var poly := PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)
	])
	var pi: Vector2 = pts[i]
	var order: Array = []
	for j: int in pts.size():
		if j == i:
			continue
		order.append([(pts[j] - pi).length_squared(), j])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var lim: int = mini(order.size(), 22)
	for k: int in lim:
		var pj: Vector2 = pts[int(order[k][1])]
		var mid: Vector2 = (pi + pj) * 0.5
		var nrm: Vector2 = pj - pi
		poly = _clip(poly, mid, nrm)
		if poly.size() < 3:
			break
	return poly


static func _clip(poly: PackedVector2Array, mid: Vector2, nrm: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cnt: int = poly.size()
	for a: int in cnt:
		var cur: Vector2 = poly[a]
		var nxt: Vector2 = poly[(a + 1) % cnt]
		var dc: float = (cur - mid).dot(nrm)
		var dn: float = (nxt - mid).dot(nrm)
		var ic: bool = dc <= 0.0
		var inx: bool = dn <= 0.0
		if ic:
			out.append(cur)
		if ic != inx:
			var t: float = dc / (dc - dn)
			out.append(cur + (nxt - cur) * t)
	return out


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	var area: float = 0.0
	var cnt: int = poly.size()
	for a: int in cnt:
		var p0: Vector2 = poly[a]
		var p1: Vector2 = poly[(a + 1) % cnt]
		var cr: float = p0.x * p1.y - p1.x * p0.y
		area += cr
		c += (p0 + p1) * cr
	if absf(area) < 0.000001:
		var s := Vector2.ZERO
		for p: Vector2 in poly:
			s += p
		return s / float(maxi(cnt, 1))
	return c / (3.0 * area)


static func _alpha_at(img: Image, uv: Vector2) -> float:
	var w: int = img.get_width()
	var hgt: int = img.get_height()
	var x: int = clampi(int(uv.x * float(w)), 0, w - 1)
	var y: int = clampi(int(uv.y * float(hgt)), 0, hgt - 1)
	return img.get_pixel(x, y).a


static func _extrude(cell: PackedVector2Array, cen: Vector2, asp: float, h: float, thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = cell.size()
	var hz: float = thick * 0.5
	var loc: Array = []
	var uvs: Array = []
	for a: int in n:
		var p: Vector2 = cell[a]
		loc.append(Vector3((p.x - cen.x) * h, (p.y - cen.y) * h, 0.0))
		uvs.append(Vector2(p.x / maxf(asp, 0.0001) + 0.5, 0.5 - p.y))
	for a: int in range(1, n - 1):
		_tri(st, Vector3(0, 0, 1),
			loc[0] + Vector3(0, 0, hz), uvs[0],
			loc[a] + Vector3(0, 0, hz), uvs[a],
			loc[a + 1] + Vector3(0, 0, hz), uvs[a + 1])
	for a: int in range(1, n - 1):
		_tri(st, Vector3(0, 0, -1),
			loc[0] + Vector3(0, 0, -hz), uvs[0],
			loc[a + 1] + Vector3(0, 0, -hz), uvs[a + 1],
			loc[a] + Vector3(0, 0, -hz), uvs[a])
	for a: int in n:
		var b: int = (a + 1) % n
		var ea: Vector3 = loc[a]
		var eb: Vector3 = loc[b]
		var edge: Vector2 = Vector2(eb.x - ea.x, eb.y - ea.y)
		var nrm2 := Vector2(edge.y, -edge.x).normalized()
		var midxy := Vector2((ea.x + eb.x) * 0.5, (ea.y + eb.y) * 0.5)
		if nrm2.dot(midxy) < 0.0:
			nrm2 = -nrm2
		var sn := Vector3(nrm2.x, nrm2.y, 0.0)
		var uva: Vector2 = uvs[a]
		var uvb: Vector2 = uvs[b]
		_tri(st, sn, ea + Vector3(0, 0, hz), uva, eb + Vector3(0, 0, hz), uvb, eb + Vector3(0, 0, -hz), uvb)
		_tri(st, sn, ea + Vector3(0, 0, hz), uva, eb + Vector3(0, 0, -hz), uvb, ea + Vector3(0, 0, -hz), uva)
	return st.commit()


static func _tri(st: SurfaceTool, nrm: Vector3, a: Vector3, ua: Vector2, b: Vector3, ub: Vector2, c: Vector3, uc: Vector2) -> void:
	st.set_normal(nrm)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_normal(nrm)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_normal(nrm)
	st.set_uv(uc)
	st.add_vertex(c)

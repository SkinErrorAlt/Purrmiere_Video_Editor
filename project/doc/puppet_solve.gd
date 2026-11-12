extends RefCounted

const PIN_WEIGHT := 100000.0
const HOLD_WEIGHT := 100000.0
const TINY := 0.0000001
const KIND_POSITION := 0
const KIND_BEND := 1
const KIND_ADVANCED := 2
const KIND_OFF := 3
const BEND_GAIN := 60.0
const BEND_CORE := 0.45
const RIGID_GAIN := 400.0
const COL_X := 0
const COL_A := 2
const HELD_STILL := -1
const FREE := -2

const NATIVE_CLASS := "PurrPuppet"

static var factor_count: int = 0
static var solve_count: int = 0
static var last_factor_ms: float = 0.0
static var last_solve_ms: float = 0.0
static var use_native: bool = true
static var _native: Object = null
static var _native_tried: bool = false


static func native() -> Object:
	if not use_native:
		return null
	if not _native_tried:
		_native_tried = true
		if ClassDB.class_exists(NATIVE_CLASS):
			_native = ClassDB.instantiate(NATIVE_CLASS)
	return _native


static func has_native() -> bool:
	return ClassDB.class_exists(NATIVE_CLASS)


static func moves(kind: int) -> bool:
	return kind == KIND_POSITION or kind == KIND_ADVANCED


static func bends(kind: int) -> bool:
	return kind == KIND_BEND or kind == KIND_ADVANCED


static func kind_at(kinds: PackedInt32Array, i: int) -> int:
	return kinds[i] if i < kinds.size() else KIND_POSITION


static func turn_matrix(turn: Vector2) -> Vector2:
	var s: float = turn.y / 100.0
	var r: float = deg_to_rad(turn.x)
	return Vector2(s * cos(r), s * sin(r))


static func build(mesh: Dictionary, rest: PackedVector2Array, binds: Array[Dictionary], kinds: PackedInt32Array, anchor: PackedFloat64Array, rigid: PackedFloat64Array, reach: float) -> Dictionary:
	var nat: Object = native()
	if nat != null:
		var made: Dictionary = nat.call("build", mesh["verts"], mesh["tris"], rest, binds, kinds, anchor, rigid, reach)
		made["binds"] = binds
		return made
	var t0: int = Time.get_ticks_usec()
	var verts: PackedVector2Array = mesh["verts"]
	var tris: PackedInt32Array = mesh["tris"]
	var n: int = verts.size()
	var stiff: PackedFloat64Array = anchor if anchor.size() == n else PackedFloat64Array()
	var hard: PackedFloat64Array = rigid if rigid.size() == n else PackedFloat64Array()
	var edge_index: Dictionary = {}
	var e_nb: PackedInt32Array = PackedInt32Array()
	var e_cnt: PackedInt32Array = PackedInt32Array()
	for t: int in tris.size() / 3:
		for k: int in 3:
			var a: int = tris[t * 3 + k]
			var b: int = tris[t * 3 + (k + 1) % 3]
			var o: int = tris[t * 3 + (k + 2) % 3]
			var lo: int = mini(a, b)
			var hi: int = maxi(a, b)
			var ek: int = lo * n + hi
			var idx: int = int(edge_index.get(ek, -1))
			if idx < 0:
				idx = e_cnt.size()
				edge_index[ek] = idx
				e_nb.append_array(PackedInt32Array([lo, hi, o, -1]))
				e_cnt.append(3)
			elif e_cnt[idx] == 3:
				e_nb[idx * 4 + 3] = o
				e_cnt[idx] = 4
	var ne: int = e_cnt.size()
	var comp: PackedInt32Array = _components(n, tris)
	var pos_count: Dictionary = {}
	var bend_count: Dictionary = {}
	var single: Dictionary = {}
	for i: int in binds.size():
		var bv: PackedInt32Array = binds[i]["v"]
		if bv.is_empty():
			continue
		var cid: int = comp[bv[0]]
		var kd: int = kind_at(kinds, i)
		if moves(kd):
			pos_count[cid] = int(pos_count.get(cid, 0)) + 1
			single[cid] = i
		if bends(kd):
			bend_count[cid] = int(bend_count.get(cid, 0)) + 1
	var anchored: Dictionary = {}
	for sv: int in stiff.size():
		if stiff[sv] > 0.0:
			anchored[comp[sv]] = true
	var held: PackedInt32Array = PackedInt32Array()
	held.resize(n)
	var fix: Dictionary = {}
	for v: int in n:
		var cid2: int = comp[v]
		var pc: int = int(pos_count.get(cid2, 0))
		var fixed: int = pc + (1 if anchored.has(cid2) else 0)
		var bc: int = int(bend_count.get(cid2, 0))
		if fixed >= 2 or bc >= 1:
			held[v] = FREE
			if fixed == 0:
				fix[cid2] = true
		elif pc == 1:
			held[v] = int(single[cid2])
		else:
			held[v] = HELD_STILL
	var bwc: int = 1
	var bw2: int = 1
	var e_p0: PackedFloat64Array = PackedFloat64Array()
	var e_p1: PackedFloat64Array = PackedFloat64Array()
	var e_h0: PackedFloat64Array = PackedFloat64Array()
	var e_h1: PackedFloat64Array = PackedFloat64Array()
	e_p0.resize(ne * 8)
	e_p1.resize(ne * 8)
	e_h0.resize(ne * 8)
	e_h1.resize(ne * 8)
	var e_vec: PackedVector2Array = PackedVector2Array()
	e_vec.resize(ne)
	var e_w: PackedFloat64Array = PackedFloat64Array()
	e_w.resize(ne)
	var free_edges: PackedInt32Array = PackedInt32Array()
	for ei: int in ne:
		var m: int = e_cnt[ei]
		var lo2: int = e_nb[ei * 4]
		var hi2: int = e_nb[ei * 4]
		for q: int in m:
			lo2 = mini(lo2, e_nb[ei * 4 + q])
			hi2 = maxi(hi2, e_nb[ei * 4 + q])
		bwc = maxi(bwc, hi2 - lo2)
		bw2 = maxi(bw2, e_nb[ei * 4 + 1] - e_nb[ei * 4])
		_edge_rows(verts, e_nb, ei, m, e_p0, e_p1, e_h0, e_h1)
		e_vec[ei] = verts[e_nb[ei * 4 + 1]] - verts[e_nb[ei * 4]]
		var wr: float = 0.0
		if not hard.is_empty():
			wr = (hard[e_nb[ei * 4]] + hard[e_nb[ei * 4 + 1]]) * 0.5
		e_w[ei] = 1.0 + RIGID_GAIN * wr
		if held[e_nb[ei * 4]] == FREE:
			free_edges.append(ei)
	for b: Dictionary in binds:
		var bv2: PackedInt32Array = b["v"]
		for x2: int in bv2:
			for y2: int in bv2:
				bwc = maxi(bwc, absi(x2 - y2))
				bw2 = maxi(bw2, absi(x2 - y2))
	var bend_edge: PackedInt32Array = PackedInt32Array()
	var bend_pin: PackedInt32Array = PackedInt32Array()
	var bend_w: PackedFloat64Array = PackedFloat64Array()
	var r: float = maxf(reach, 1.0)
	for p: int in binds.size():
		var bvp: PackedInt32Array = binds[p]["v"]
		if not bends(kind_at(kinds, p)) or bvp.is_empty() or held[bvp[0]] != FREE:
			continue
		var centre: Vector2 = rest[p] if p < rest.size() else Vector2.ZERO
		for ei2: int in free_edges:
			var mid: Vector2 = (verts[e_nb[ei2 * 4]] + verts[e_nb[ei2 * 4 + 1]]) * 0.5
			var dd: float = mid.distance_to(centre)
			if dd >= r:
				continue
			bend_edge.append(ei2)
			bend_pin.append(p)
			bend_w.append(BEND_GAIN * (1.0 - smoothstep(BEND_CORE * r, r, dd)))
	var wc: int = bwc + 1
	var w2: int = bw2 + 1
	var hr: PackedFloat64Array = PackedFloat64Array()
	var hi: PackedFloat64Array = PackedFloat64Array()
	hr.resize(n * wc)
	hi.resize(n * wc)
	var a2: PackedFloat64Array = PackedFloat64Array()
	a2.resize(n * w2)
	for ei3: int in ne:
		var m3: int = e_cnt[ei3]
		var we: float = e_w[ei3]
		var base: int = ei3 * 8
		var nbase: int = ei3 * 4
		for qa: int in m3:
			var va: int = e_nb[nbase + qa]
			var ga_r: float = e_h0[base + 2 * qa]
			var ga_i: float = e_h1[base + 2 * qa]
			for qb: int in m3:
				var vb: int = e_nb[nbase + qb]
				if vb > va:
					continue
				var gb_r: float = e_h0[base + 2 * qb]
				var gb_i: float = e_h1[base + 2 * qb]
				var at_c: int = va * wc + (vb - va + bwc)
				hr[at_c] += we * (ga_r * gb_r + ga_i * gb_i)
				hi[at_c] += we * (ga_r * gb_i - ga_i * gb_r)
		var ia: int = e_nb[nbase]
		var ib: int = e_nb[nbase + 1]
		a2[ia * w2 + bw2] += we
		a2[ib * w2 + bw2] += we
		a2[ib * w2 + (ia - ib + bw2)] -= we
	for k4: int in bend_edge.size():
		var ei4: int = bend_edge[k4]
		var bwt: float = bend_w[k4]
		var ia4: int = e_nb[ei4 * 4]
		var ib4: int = e_nb[ei4 * 4 + 1]
		hr[ia4 * wc + bwc] += bwt
		hr[ib4 * wc + bwc] += bwt
		hr[ib4 * wc + (ia4 - ib4 + bwc)] -= bwt
		a2[ia4 * w2 + bw2] += bwt
		a2[ib4 * w2 + bw2] += bwt
		a2[ib4 * w2 + (ia4 - ib4 + bw2)] -= bwt
	var bx0: PackedFloat64Array = PackedFloat64Array()
	var by0: PackedFloat64Array = PackedFloat64Array()
	bx0.resize(n)
	by0.resize(n)
	var pin_on: PackedInt32Array = PackedInt32Array()
	pin_on.resize(binds.size())
	for i2: int in binds.size():
		var bv3: PackedInt32Array = binds[i2]["v"]
		if bv3.is_empty() or held[bv3[0]] != FREE:
			continue
		var kd2: int = kind_at(kinds, i2)
		var fixes: bool = not moves(kd2) and fix.has(comp[bv3[0]])
		if not moves(kd2) and not fixes:
			continue
		pin_on[i2] = 2 if fixes else 1
		var bw3: PackedFloat64Array = b_w(binds[i2])
		for x3: int in bv3.size():
			for y3: int in bv3.size():
				if bv3[y3] > bv3[x3]:
					continue
				var wv: float = PIN_WEIGHT * bw3[x3] * bw3[y3]
				hr[bv3[x3] * wc + (bv3[y3] - bv3[x3] + bwc)] += wv
				_band_add(a2, bw2, bv3[x3], bv3[y3], wv)
		if fixes:
			var at: Vector2 = rest[i2] if i2 < rest.size() else Vector2.ZERO
			for x4: int in bv3.size():
				bx0[bv3[x4]] += PIN_WEIGHT * bw3[x4] * at.x
				by0[bv3[x4]] += PIN_WEIGHT * bw3[x4] * at.y
	for v2: int in n:
		var hold: float = HOLD_WEIGHT if held[v2] != FREE else (stiff[v2] if not stiff.is_empty() else 0.0)
		hr[v2 * wc + bwc] += hold + TINY
		a2[v2 * w2 + bw2] += hold + TINY
		if held[v2] == FREE and not stiff.is_empty() and stiff[v2] > 0.0:
			bx0[v2] += stiff[v2] * verts[v2].x
			by0[v2] += stiff[v2] * verts[v2].y
	_cband_factor(hr, hi, n, bwc)
	_band_factor(a2, n, bw2)
	var cols_kind: PackedInt32Array = PackedInt32Array()
	var cols_pin: PackedInt32Array = PackedInt32Array()
	for i3: int in binds.size():
		if pin_on[i3] == 1:
			cols_kind.append(COL_X)
			cols_pin.append(i3)
	var bend_first: Dictionary = {}
	for k5: int in bend_pin.size():
		if not bend_first.has(bend_pin[k5]):
			bend_first[bend_pin[k5]] = true
			cols_kind.append(COL_A)
			cols_pin.append(bend_pin[k5])
	var zr: PackedFloat64Array = PackedFloat64Array()
	var zi: PackedFloat64Array = PackedFloat64Array()
	zr.resize(cols_kind.size() * n)
	zi.resize(cols_kind.size() * n)
	var v0: Array = _cband_solve(hr, hi, n, bwc, bx0, by0, 0)
	for c: int in cols_kind.size():
		var rr: PackedFloat64Array = PackedFloat64Array()
		var ri: PackedFloat64Array = PackedFloat64Array()
		rr.resize(n)
		ri.resize(n)
		var start: int = n
		var pin: int = cols_pin[c]
		if cols_kind[c] == COL_X:
			var bv4: PackedInt32Array = binds[pin]["v"]
			var bw4: PackedFloat64Array = b_w(binds[pin])
			for x5: int in bv4.size():
				rr[bv4[x5]] += PIN_WEIGHT * bw4[x5]
				start = mini(start, bv4[x5])
		else:
			for k6: int in bend_pin.size():
				if bend_pin[k6] != pin:
					continue
				var ei6: int = bend_edge[k6]
				var ev: Vector2 = e_vec[ei6]
				var ia6: int = e_nb[ei6 * 4]
				var ib6: int = e_nb[ei6 * 4 + 1]
				rr[ib6] += bend_w[k6] * ev.x
				ri[ib6] += bend_w[k6] * ev.y
				rr[ia6] -= bend_w[k6] * ev.x
				ri[ia6] -= bend_w[k6] * ev.y
				start = mini(start, ia6)
		var sol: Array = _cband_solve(hr, hi, n, bwc, rr, ri, start)
		var sr: PackedFloat64Array = sol[0]
		var si: PackedFloat64Array = sol[1]
		var off: int = c * n
		for gi2: int in n:
			zr[off + gi2] = sr[gi2]
			zi[off + gi2] = si[gi2]
	var spent: float = float(Time.get_ticks_usec() - t0) / 1000.0
	return {
		"n": n, "bw1": 2 * bwc + 1, "bwc": bwc, "bw2": bw2, "l2": a2, "held": held, "comp": comp,
		"e_nb": e_nb, "e_cnt": e_cnt, "e_p0": e_p0, "e_p1": e_p1, "e_vec": e_vec, "e_w": e_w, "free_edges": free_edges,
		"bend_edge": bend_edge, "bend_pin": bend_pin, "bend_w": bend_w, "pin_on": pin_on, "binds": binds,
		"cols_kind": cols_kind, "cols_pin": cols_pin, "zr": zr, "zi": zi, "v0r": v0[0], "v0i": v0[1], "bx0": bx0, "by0": by0,
		"stiff": stiff, "ms": spent,
	}


static func b_w(b: Dictionary) -> PackedFloat64Array:
	return b["w"]


static func plain_kinds(kinds: PackedInt32Array) -> PackedInt32Array:
	var out: PackedInt32Array = kinds.duplicate()
	for i: int in out.size():
		if out[i] == KIND_BEND:
			out[i] = KIND_OFF
		elif out[i] == KIND_ADVANCED:
			out[i] = KIND_POSITION
	return out


static func any_bends(kinds: PackedInt32Array) -> bool:
	for k: int in kinds:
		if bends(k):
			return true
	return false


static func relative_mats(solver: Dictionary, base: PackedVector2Array, turns: PackedVector2Array) -> PackedVector2Array:
	var n: int = turns.size()
	var num: PackedVector2Array = PackedVector2Array()
	num.resize(n)
	var bend_edge: PackedInt32Array = solver["bend_edge"]
	var bend_pin: PackedInt32Array = solver["bend_pin"]
	var bend_w: PackedFloat64Array = solver["bend_w"]
	var e_vec: PackedVector2Array = solver["e_vec"]
	var e_nb: PackedInt32Array = solver["e_nb"]
	for k: int in bend_edge.size():
		var p: int = bend_pin[k]
		if p >= n:
			continue
		var ei: int = bend_edge[k]
		var er: Vector2 = e_vec[ei]
		var ia: int = e_nb[ei * 4]
		var ib: int = e_nb[ei * 4 + 1]
		if ib >= base.size():
			continue
		var ed: Vector2 = base[ib] - base[ia]
		num[p] += bend_w[k] * Vector2(er.dot(ed), er.cross(ed))
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	for i: int in n:
		var natural: Vector2 = num[i].normalized() if num[i].length() > TINY else Vector2(1.0, 0.0)
		var user: Vector2 = turn_matrix(turns[i])
		out[i] = Vector2(natural.x * user.x - natural.y * user.y, natural.x * user.y + natural.y * user.x)
	return out


static func run(solver: Dictionary, verts: PackedVector2Array, rest: PackedVector2Array, pins: PackedVector2Array, mats: PackedVector2Array) -> PackedVector2Array:
	var t0: int = Time.get_ticks_usec()
	solve_count += 1
	var nat: Object = native()
	if nat != null:
		var fast: PackedVector2Array = nat.call("run", solver, verts, rest, pins, mats)
		last_solve_ms = float(Time.get_ticks_usec() - t0) / 1000.0
		return fast
	var n: int = int(solver["n"])
	var held: PackedInt32Array = solver["held"]
	var cols_kind: PackedInt32Array = solver["cols_kind"]
	var cols_pin: PackedInt32Array = solver["cols_pin"]
	var zr: PackedFloat64Array = solver["zr"]
	var zi: PackedFloat64Array = solver["zi"]
	var vr: PackedFloat64Array = (solver["v0r"] as PackedFloat64Array).duplicate()
	var vi: PackedFloat64Array = (solver["v0i"] as PackedFloat64Array).duplicate()
	for c: int in cols_kind.size():
		var pin: int = cols_pin[c]
		var m: Vector2 = Vector2.ZERO
		if cols_kind[c] == COL_X:
			m = pins[pin] if pin < pins.size() else Vector2.ZERO
		else:
			m = mats[pin] if pin < mats.size() else Vector2(1.0, 0.0)
		if m == Vector2.ZERO:
			continue
		var off: int = c * n
		var mr: float = m.x
		var mi: float = m.y
		for g: int in n:
			var ar: float = zr[off + g]
			var ai: float = zi[off + g]
			vr[g] += ar * mr - ai * mi
			vi[g] += ar * mi + ai * mr
	var bx: PackedFloat64Array = (solver["bx0"] as PackedFloat64Array).duplicate()
	var by: PackedFloat64Array = (solver["by0"] as PackedFloat64Array).duplicate()
	var e_nb: PackedInt32Array = solver["e_nb"]
	var e_cnt: PackedInt32Array = solver["e_cnt"]
	var e_p0: PackedFloat64Array = solver["e_p0"]
	var e_p1: PackedFloat64Array = solver["e_p1"]
	var e_vec: PackedVector2Array = solver["e_vec"]
	var e_w: PackedFloat64Array = solver["e_w"]
	var free_edges: PackedInt32Array = solver["free_edges"]
	for ei: int in free_edges:
		var base: int = ei * 8
		var nbase: int = ei * 4
		var cs: float = 0.0
		var sn: float = 0.0
		for q: int in e_cnt[ei]:
			var vq: int = e_nb[nbase + q]
			var x: float = vr[vq]
			var y: float = vi[vq]
			cs += e_p0[base + 2 * q] * x + e_p0[base + 2 * q + 1] * y
			sn += e_p1[base + 2 * q] * x + e_p1[base + 2 * q + 1] * y
		var mag: float = sqrt(cs * cs + sn * sn)
		if mag > TINY:
			cs /= mag
			sn /= mag
		else:
			cs = 1.0
			sn = 0.0
		var e: Vector2 = e_vec[ei]
		var we: float = e_w[ei]
		var tx: float = we * (cs * e.x + sn * e.y)
		var ty: float = we * (-sn * e.x + cs * e.y)
		var ia: int = e_nb[nbase]
		var ib: int = e_nb[nbase + 1]
		bx[ib] += tx
		bx[ia] -= tx
		by[ib] += ty
		by[ia] -= ty
	var bend_edge: PackedInt32Array = solver["bend_edge"]
	var bend_pin: PackedInt32Array = solver["bend_pin"]
	var bend_w: PackedFloat64Array = solver["bend_w"]
	for k: int in bend_edge.size():
		var p: int = bend_pin[k]
		var mt2: Vector2 = mats[p] if p < mats.size() else Vector2(1.0, 0.0)
		var ev: Vector2 = e_vec[bend_edge[k]]
		var bwt: float = bend_w[k]
		var tx2: float = bwt * (mt2.x * ev.x - mt2.y * ev.y)
		var ty2: float = bwt * (mt2.y * ev.x + mt2.x * ev.y)
		var ia2: int = e_nb[bend_edge[k] * 4]
		var ib2: int = e_nb[bend_edge[k] * 4 + 1]
		bx[ib2] += tx2
		bx[ia2] -= tx2
		by[ib2] += ty2
		by[ia2] -= ty2
	var binds: Array[Dictionary] = solver["binds"]
	var pin_on: PackedInt32Array = solver["pin_on"]
	for i: int in pin_on.size():
		if pin_on[i] != 1 or i >= pins.size():
			continue
		var bv: PackedInt32Array = binds[i]["v"]
		var bw: PackedFloat64Array = binds[i]["w"]
		for k2: int in bv.size():
			bx[bv[k2]] += PIN_WEIGHT * bw[k2] * pins[i].x
			by[bv[k2]] += PIN_WEIGHT * bw[k2] * pins[i].y
	var both: Array = _band_solve2(solver["l2"], n, int(solver["bw2"]), bx, by, 0)
	var xs: PackedFloat64Array = both[0]
	var ys: PackedFloat64Array = both[1]
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	for v: int in n:
		var h: int = held[v]
		if h == FREE:
			out[v] = Vector2(xs[v], ys[v])
		elif h >= 0 and h < pins.size() and h < rest.size():
			out[v] = verts[v] + pins[h] - rest[h]
		else:
			out[v] = verts[v]
	last_solve_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	return out


static func _edge_rows(verts: PackedVector2Array, e_nb: PackedInt32Array, ei: int, m: int, p0: PackedFloat64Array, p1: PackedFloat64Array, h0: PackedFloat64Array, h1: PackedFloat64Array) -> void:
	var base_v: Vector2 = verts[e_nb[ei * 4]]
	var g: Array[PackedFloat64Array] = []
	for k: int in m:
		var v: Vector2 = verts[e_nb[ei * 4 + k]] - base_v
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
	var e: Vector2 = verts[e_nb[ei * 4 + 1]] - verts[e_nb[ei * 4]]
	var base: int = ei * 8
	for col: int in 2 * m:
		var s0: float = 0.0
		var s1: float = 0.0
		for q2: int in 4:
			s0 += inv[0][q2] * g[col][q2]
			s1 += inv[1][q2] * g[col][q2]
		p0[base + col] = s0
		p1[base + col] = s1
		h0[base + col] = -(e.x * s0 + e.y * s1)
		h1[base + col] = -(e.y * s0 - e.x * s1)
	h0[base] -= 1.0
	h0[base + 2] += 1.0
	h1[base + 1] -= 1.0
	h1[base + 3] += 1.0


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
		var ri: int = i * w - i + bw
		for j: int in range(j0, i + 1):
			var sum: float = a[ri + j]
			var k0: int = maxi(j0, j - bw)
			var rj: int = j * w - j + bw
			for k: int in range(k0, j):
				sum -= a[ri + k] * a[rj + k]
			if i == j:
				a[ri + i] = sqrt(maxf(sum, TINY))
			else:
				a[ri + j] = sum / a[rj + j]


static func _band_solve2(a: PackedFloat64Array, n: int, bw: int, bx: PackedFloat64Array, by: PackedFloat64Array, start: int) -> Array:
	var w: int = bw + 1
	var x: PackedFloat64Array = bx.duplicate()
	var y: PackedFloat64Array = by.duplicate()
	for i: int in range(clampi(start, 0, n), n):
		var ri: int = i * w - i + bw
		var sx: float = x[i]
		var sy: float = y[i]
		for k: int in range(maxi(start, i - bw), i):
			var l: float = a[ri + k]
			sx -= l * x[k]
			sy -= l * y[k]
		var d: float = a[ri + i]
		x[i] = sx / d
		y[i] = sy / d
	for i2: int in range(n - 1, -1, -1):
		var sx2: float = x[i2]
		var sy2: float = y[i2]
		for k2: int in range(i2 + 1, mini(n, i2 + bw + 1)):
			var l2: float = a[k2 * w - k2 + bw + i2]
			sx2 -= l2 * x[k2]
			sy2 -= l2 * y[k2]
		var d2: float = a[i2 * w - i2 + bw + i2]
		x[i2] = sx2 / d2
		y[i2] = sy2 / d2
	return [x, y]


static func _cband_factor(lr: PackedFloat64Array, li: PackedFloat64Array, n: int, bw: int) -> void:
	var w: int = bw + 1
	for i: int in n:
		var j0: int = maxi(0, i - bw)
		var ri: int = i * w - i + bw
		for j: int in range(j0, i + 1):
			var sr: float = lr[ri + j]
			var si: float = li[ri + j]
			var rj: int = j * w - j + bw
			for k: int in range(maxi(j0, j - bw), j):
				var ar: float = lr[ri + k]
				var ai: float = li[ri + k]
				var br: float = lr[rj + k]
				var bi: float = li[rj + k]
				sr -= ar * br + ai * bi
				si -= ai * br - ar * bi
			if i == j:
				lr[ri + i] = sqrt(maxf(sr, TINY))
				li[ri + i] = 0.0
			else:
				var d: float = lr[rj + j]
				lr[ri + j] = sr / d
				li[ri + j] = si / d


static func _cband_solve(lr: PackedFloat64Array, li: PackedFloat64Array, n: int, bw: int, br: PackedFloat64Array, bi: PackedFloat64Array, start: int) -> Array:
	var w: int = bw + 1
	var yr: PackedFloat64Array = br.duplicate()
	var yi: PackedFloat64Array = bi.duplicate()
	for i: int in range(clampi(start, 0, n), n):
		var ri: int = i * w - i + bw
		var sr: float = yr[i]
		var si: float = yi[i]
		for k: int in range(maxi(start, i - bw), i):
			var ar: float = lr[ri + k]
			var ai: float = li[ri + k]
			sr -= ar * yr[k] - ai * yi[k]
			si -= ar * yi[k] + ai * yr[k]
		var d: float = lr[ri + i]
		yr[i] = sr / d
		yi[i] = si / d
	for i2: int in range(n - 1, -1, -1):
		var sr2: float = yr[i2]
		var si2: float = yi[i2]
		for k2: int in range(i2 + 1, mini(n, i2 + bw + 1)):
			var at: int = k2 * w - k2 + bw + i2
			var cr: float = lr[at]
			var ci: float = li[at]
			sr2 -= cr * yr[k2] + ci * yi[k2]
			si2 -= cr * yi[k2] - ci * yr[k2]
		var d2: float = lr[i2 * w - i2 + bw + i2]
		yr[i2] = sr2 / d2
		yi[i2] = si2 / d2
	return [yr, yi]

extends RefCounted

const Tracking := preload("res://doc/tracking.gd")
const DRIVER := "res://doc/anim_driver.gd"
const PARENTING := "res://doc/parenting.gd"
const STAB_KEY := "stabilise"
const TRACK_KEY := "track"
const KIND := "tracker"
const ZOOM_MAX := 3.0
const SMOOTH_PASSES := 3
const STAB_CACHE_MAX := 32

static var _stab: Dictionary = {}
static var _seq_of: Dictionary = {}
static var _seq_serial: int = -1
static var plant_stab_sign: bool = false


static func current_doc() -> Object:
	var d: Object = load(DRIVER).call("bound_doc")
	if d != null:
		return d
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var session: Node = (loop as SceneTree).root.get_node_or_null("/root/Session")
		if session != null:
			var sd: Variant = session.get("doc")
			if sd is Object:
				return sd
	return null


static func seq_of(doc: Object, clip_id: String) -> Object:
	if doc == null:
		return null
	var serial: int = int(doc.get("serial"))
	if serial != _seq_serial:
		_seq_of = {}
		_seq_serial = serial
	if _seq_of.has(clip_id):
		var w: WeakRef = _seq_of[clip_id]
		var o: Object = w.get_ref()
		if o != null:
			return o
	var s: Object = doc.call("sequence_of_clip", clip_id)
	if s != null:
		_seq_of[clip_id] = weakref(s)
	return s


static func layer_size(doc: Object, c: Object, s: Object) -> Vector2:
	var m: Object = doc.call("media_by_id", String(c.get("media_id"))) if doc != null else null
	if bool(c.call("is_nest")) or (m != null and String(m.get("kind")) == "sequence"):
		var ns: Object = doc.call("sequence_by_id", String(c.get("sequence_id")) if bool(c.call("is_nest")) else String(m.get("sequence_id"))) if doc != null else null
		if ns != null:
			return Vector2(float(ns.get("width")), float(ns.get("height")))
	if m != null and int(m.get("width")) > 0 and int(m.get("height")) > 0 and String(m.get("kind")) != "adjust":
		return Vector2(float(m.get("width")), float(m.get("height")))
	if s != null:
		return Vector2(float(s.get("width")), float(s.get("height")))
	return Vector2(1920.0, 1080.0)


static func world_tf(c: Object, s: Object, t: float, fps: float) -> Dictionary:
	return load(PARENTING).call("world_tf", c, s, t, fps, -1)


static func basis_of(tf: Dictionary) -> Transform2D:
	return Transform2D(deg_to_rad(float(tf["rotation"])), tf["scale"], 0.0, Vector2.ZERO)


static func layer_xf(tf: Dictionary, layer_px: Vector2, seq_size: Vector2) -> Transform2D:
	var b: Transform2D = basis_of(tf)
	var pivot: Vector2 = layer_px * 0.5 + (tf["anchor"] as Vector2)
	var centre: Vector2 = seq_size * 0.5 + (tf["pos"] as Vector2)
	b.origin = centre - b.basis_xform(pivot)
	return b


static func media_to_seq(tf: Dictionary, layer_px: Vector2, seq_size: Vector2, m: Vector2) -> Vector2:
	return layer_xf(tf, layer_px, seq_size) * m


static func seq_to_media(tf: Dictionary, layer_px: Vector2, seq_size: Vector2, p: Vector2) -> Vector2:
	return layer_xf(tf, layer_px, seq_size).affine_inverse() * p


static func seq_time_of(c: Object, mt: float) -> float:
	var start: float = float(c.get("start"))
	var spd: Dictionary = c.get("speed")
	var a0: float = float(c.call("source_time", start))
	if not bool(spd.get("a", false)):
		var v: float = float(spd.get("v", 1.0))
		if absf(v) < 0.000001:
			return start
		return start + (mt - a0) / v
	var lo: float = start
	var hi: float = float(c.call("end"))
	var up: bool = float(c.call("source_time", hi)) >= a0
	for i: int in 48:
		var mid: float = (lo + hi) * 0.5
		var v2: float = float(c.call("source_time", mid))
		if (v2 < mt) == up:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


static func media_time(c: Object, t_seq: float) -> float:
	return float(c.call("source_time", t_seq))


static func tracker_list(s: Dictionary, ids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: Variant in ids:
		var tr: Dictionary = Tracking.tracker_by_id(s, String(id))
		if not tr.is_empty():
			out.append(tr)
	return out


static func similarity_at(doc: Object, src: Dictionary, at_seq: float, fps: float) -> Dictionary:
	var fail: Dictionary = {"ok": false}
	if doc == null:
		return fail
	var s: Dictionary = Tracking.set_by_id(doc, String(src.get("set", "")))
	if s.is_empty():
		return fail
	var tracked: Object = doc.call("clip_by_id", String(src.get("footage", s.get("clip", ""))))
	if tracked == null:
		return fail
	var seq: Object = seq_of(doc, String(tracked.get("id")))
	if seq == null:
		return fail
	var trs: Array[Dictionary] = tracker_list(s, src.get("trackers", []) if src.get("trackers") is Array else [])
	if trs.is_empty():
		return fail
	var sfps: float = float(s.get("fps", 30.0))
	var mt: float = media_time(tracked, at_seq)
	var t0: float = float(src.get("t0", mt))
	var tf: Dictionary = world_tf(tracked, seq, at_seq, fps)
	var lp: Vector2 = Vector2(float((s["size"] as Array)[0]), float((s["size"] as Array)[1]))
	var ss: Vector2 = Vector2(float(seq.get("width")), float(seq.get("height")))
	var xf: Transform2D = layer_xf(tf, lp, ss)
	var a_now: Vector2 = xf * (Tracking.position_at(trs[0], mt, sfps)["p"] as Vector2)
	var a_then: Vector2 = xf * (Tracking.position_at(trs[0], t0, sfps)["p"] as Vector2)
	var ang: float = 0.0
	var k: float = 1.0
	if trs.size() >= 2:
		var b_now: Vector2 = xf * (Tracking.position_at(trs[1], mt, sfps)["p"] as Vector2)
		var b_then: Vector2 = xf * (Tracking.position_at(trs[1], t0, sfps)["p"] as Vector2)
		var d0: Vector2 = b_then - a_then
		var d1: Vector2 = b_now - a_now
		if d0.length() > 0.001 and d1.length() > 0.001:
			ang = d1.angle() - d0.angle()
			ang = wrapf(ang, -PI, PI)
			k = d1.length() / d0.length()
	return {"ok": true, "a_now": a_now, "a_then": a_then, "angle": ang, "scale": k, "seq": seq, "seq_size": ss}


static func follow(sim: Dictionary, p: Vector2) -> Vector2:
	var a_now: Vector2 = sim["a_now"]
	var a_then: Vector2 = sim["a_then"]
	return a_now + (p - a_then).rotated(float(sim["angle"])) * float(sim["scale"])


static func driven_raw(doc: Object, layer: Dictionary, src: Dictionary, t: float, fps: float) -> Dictionary:
	var fail: Dictionary = {"ok": false, "v": 0.0}
	if doc == null:
		return fail
	var owner: Object = doc.call("clip_by_id", String(src.get("owner", "")))
	if owner == null:
		return fail
	var at_seq: float = float(owner.get("start")) + t
	var sim: Dictionary = similarity_at(doc, src, at_seq, fps)
	if not bool(sim["ok"]):
		return fail
	var out: String = String(src.get("out", "x"))
	if out == "angle":
		return {"ok": true, "v": rad_to_deg(float(sim["angle"]))}
	if out == "scale":
		return {"ok": true, "v": float(sim["scale"])}
	var bv: Array = src.get("base", [0.0, 0.0]) if src.get("base") is Array else [0.0, 0.0]
	var base: Vector2 = Vector2(float(bv[0]), float(bv[1]))
	var now: Vector2 = follow(sim, base)
	if out == "x":
		return {"ok": true, "v": now.x - base.x}
	if out == "y":
		return {"ok": true, "v": now.y - base.y}
	if out == "ux" or out == "uy":
		var oseq: Object = seq_of(doc, String(owner.get("id")))
		if oseq == null:
			return fail
		var otf: Dictionary = world_tf(owner, oseq, at_seq, fps)
		var lp: Vector2 = layer_size(doc, owner, oseq)
		var inv: Transform2D = layer_xf(otf, lp, sim["seq_size"]).affine_inverse()
		var d_uv: Vector2 = (inv * now - inv * base) / Vector2(maxf(lp.x, 1.0), maxf(lp.y, 1.0))
		return {"ok": true, "v": d_uv.x if out == "ux" else d_uv.y}
	return fail


static func mask_xf(doc: Object, owner: Object, mask: Dictionary, at_seq: float, fps: float) -> Variant:
	var tk: Variant = mask.get(TRACK_KEY)
	if not (tk is Dictionary):
		return null
	var sim: Dictionary = similarity_at(doc, tk, at_seq, fps)
	if not bool(sim["ok"]):
		return null
	var oseq: Object = seq_of(doc, String(owner.get("id")))
	if oseq == null:
		return null
	var otf: Dictionary = world_tf(owner, oseq, at_seq, fps)
	var lp: Vector2 = layer_size(doc, owner, oseq)
	var to_seq: Transform2D = layer_xf(otf, lp, sim["seq_size"]) * Transform2D(Vector2(lp.x, 0.0), Vector2(0.0, lp.y), Vector2.ZERO)
	var k: float = float(sim["scale"])
	var sx: Transform2D = Transform2D(float(sim["angle"]), Vector2(k, k), 0.0, Vector2.ZERO)
	sx.origin = (sim["a_now"] as Vector2) - sx.basis_xform(sim["a_then"])
	return to_seq.affine_inverse() * sx * to_seq


static func masks_at(doc: Object, owner: Object, masks: Array, at_seq: float, fps: float) -> Array:
	var any: bool = false
	for m: Variant in masks:
		if m is Dictionary and (m as Dictionary).has(TRACK_KEY):
			any = true
			break
	if not any:
		return masks
	var out: Array = []
	for m: Variant in masks:
		if m is Dictionary and (m as Dictionary).has(TRACK_KEY):
			var xf: Variant = mask_xf(doc, owner, m, at_seq, fps)
			if xf is Transform2D:
				var copy: Dictionary = (m as Dictionary).duplicate()
				copy["track_xf"] = xf
				out.append(copy)
				continue
		out.append(m)
	return out


static func stab_of(c: Object) -> Dictionary:
	var props: Dictionary = c.get("props")
	if props.is_empty() or not props.has(STAB_KEY):
		return {}
	var st: Variant = props[STAB_KEY]
	if not (st is Dictionary) or not bool((st as Dictionary).get("on", true)):
		return {}
	return st


static func stabilised(c: Object, tf: Dictionary, t_seq: float) -> Dictionary:
	var st: Dictionary = stab_of(c)
	if st.is_empty():
		return tf
	var doc: Object = current_doc()
	var s: Dictionary = Tracking.set_by_id(doc, String(st.get("set", "")))
	if s.is_empty():
		return tf
	var path: Dictionary = stab_path(s, st)
	if not bool(path.get("ok", false)):
		return tf
	var lp: Vector2 = Vector2(float((s["size"] as Array)[0]), float((s["size"] as Array)[1]))
	var corr: Dictionary = correction_at(path, media_time(c, t_seq), String(st.get("edges", "crop")) == "crop", lp)
	return apply_correction(tf, corr, lp)


static func apply_correction(tf: Dictionary, corr: Dictionary, lp: Vector2) -> Dictionary:
	var q: Vector2 = corr["q"]
	var m: Vector2 = corr["m"]
	var a: float = float(corr["a"])
	var f: float = float(corr["f"])
	var pivot0: Vector2 = lp * 0.5 + (tf["anchor"] as Vector2)
	var b: Transform2D = basis_of(tf)
	var out: Dictionary = tf.duplicate()
	out["pos"] = (tf["pos"] as Vector2) + b.basis_xform(q - pivot0)
	out["anchor"] = m - lp * 0.5
	out["rotation"] = float(tf["rotation"]) + rad_to_deg(a)
	out["scale"] = (tf["scale"] as Vector2) * f
	return out


static func correction_at(path: Dictionary, mt: float, crop: bool, lp: Vector2) -> Dictionary:
	var t: PackedFloat64Array = path["t"]
	var i: int = clampi(Tracking.last_at_or_before(t, mt + Tracking.frame_eps(float(path["fps"]))), 0, t.size() - 1)
	var m: Vector2 = (path["m"] as PackedVector2Array)[i]
	var target: Vector2 = (path["target"] as PackedVector2Array)[i]
	var a: float = (path["a"] as PackedFloat64Array)[i]
	var f: float = (path["f"] as PackedFloat64Array)[i]
	var z: float = float(path["zoom"]) if crop else 1.0
	var mc: Vector2 = lp * 0.5
	return {"m": m, "q": mc + (target - mc) * z, "a": a, "f": f * z, "zoom": z}


static func stab_key(s: Dictionary, st: Dictionary) -> String:
	var revs: String = ""
	for tr: Dictionary in tracker_list(s, st.get("trackers", []) if st.get("trackers") is Array else []):
		revs += String(tr.get("rev", "")) + ";" + str(tr.get("at", [])) + ";"
	var keep: Dictionary = st.duplicate()
	keep.erase("on")
	return String(s.get("id", "")) + "|" + revs + "|" + JSON.stringify(keep) + "|" + str(s.get("size", [])) + "|" + str(plant_stab_sign)


static func stab_path(s: Dictionary, st: Dictionary) -> Dictionary:
	var key: String = stab_key(s, st)
	if _stab.has(key):
		return _stab[key]
	var path: Dictionary = build_path(s, st)
	if _stab.size() >= STAB_CACHE_MAX:
		_stab.clear()
	_stab[key] = path
	return path


static func build_path(s: Dictionary, st: Dictionary) -> Dictionary:
	var trs: Array[Dictionary] = tracker_list(s, st.get("trackers", []) if st.get("trackers") is Array else [])
	if trs.is_empty():
		return {"ok": false}
	var fps: float = float(s.get("fps", 30.0))
	var sa: Dictionary = Tracking.samples(trs[0])
	var vt: PackedFloat64Array = sa["vt"]
	if vt.is_empty():
		return {"ok": false}
	var n: int = vt.size()
	var mx: PackedFloat64Array = PackedFloat64Array()
	var my: PackedFloat64Array = PackedFloat64Array()
	var ang: PackedFloat64Array = PackedFloat64Array()
	var dist: PackedFloat64Array = PackedFloat64Array()
	var two: bool = trs.size() >= 2
	var prev_ang: float = 0.0
	for i: int in n:
		var a: Vector2 = Vector2((sa["vx"] as PackedFloat32Array)[i], (sa["vy"] as PackedFloat32Array)[i])
		if two:
			var b: Vector2 = Tracking.position_at(trs[1], vt[i], fps)["p"]
			var d: Vector2 = b - a
			var mid: Vector2 = (a + b) * 0.5
			mx.append(mid.x)
			my.append(mid.y)
			var raw: float = d.angle()
			if i > 0:
				raw = prev_ang + wrapf(raw - prev_ang, -PI, PI)
			prev_ang = raw
			ang.append(raw)
			dist.append(maxf(d.length(), 0.001))
		else:
			mx.append(a.x)
			my.append(a.y)
			ang.append(0.0)
			dist.append(1.0)
	var keep_pos: bool = bool(st.get("position", true))
	var keep_rot: bool = bool(st.get("rotation", true)) and two
	var keep_scale: bool = bool(st.get("scale", true)) and two
	var lock: bool = String(st.get("mode", "lock")) == "lock"
	var tx: PackedFloat64Array = mx.duplicate()
	var ty: PackedFloat64Array = my.duplicate()
	var tang: PackedFloat64Array = ang.duplicate()
	var tdist: PackedFloat64Array = dist.duplicate()
	if lock:
		var r: int = clampi(Tracking.last_at_or_before(vt, float(st.get("ref", vt[0])) + Tracking.frame_eps(fps)), 0, n - 1)
		for i: int in n:
			tx[i] = mx[r]
			ty[i] = my[r]
			tang[i] = ang[r]
			tdist[i] = dist[r]
	else:
		var sigma: float = maxf(float(st.get("smooth", 1.0)), 0.0) * fps
		tx = smooth(mx, sigma)
		ty = smooth(my, sigma)
		tang = smooth(ang, sigma)
		var logd: PackedFloat64Array = PackedFloat64Array()
		for v: float in dist:
			logd.append(log(v))
		var sl: PackedFloat64Array = smooth(logd, sigma)
		for i: int in n:
			tdist[i] = exp(sl[i])
	var m_out: PackedVector2Array = PackedVector2Array()
	var t_out: PackedVector2Array = PackedVector2Array()
	var a_out: PackedFloat64Array = PackedFloat64Array()
	var f_out: PackedFloat64Array = PackedFloat64Array()
	for i: int in n:
		var m: Vector2 = Vector2(mx[i], my[i])
		var target: Vector2 = Vector2(tx[i], ty[i]) if keep_pos else m
		if plant_stab_sign:
			target = m + (m - target)
		m_out.append(m)
		t_out.append(target)
		a_out.append(tang[i] - ang[i] if keep_rot else 0.0)
		f_out.append(tdist[i] / dist[i] if keep_scale else 1.0)
	var lp: Vector2 = Vector2(float((s["size"] as Array)[0]), float((s["size"] as Array)[1]))
	var zoom: float = crop_zoom(m_out, t_out, a_out, f_out, lp)
	return {"ok": true, "fps": fps, "t": vt, "m": m_out, "target": t_out, "a": a_out, "f": f_out, "zoom": zoom}


static func smooth(v: PackedFloat64Array, sigma: float) -> PackedFloat64Array:
	var n: int = v.size()
	if n < 3 or sigma < 0.5:
		return v.duplicate()
	var w: int = maxi(1, int(round(sqrt(12.0 * sigma * sigma / float(SMOOTH_PASSES) + 1.0))))
	var r: int = w / 2
	var cur: PackedFloat64Array = v.duplicate()
	for p: int in SMOOTH_PASSES:
		var nxt: PackedFloat64Array = PackedFloat64Array()
		nxt.resize(n)
		var acc: float = 0.0
		for j: int in range(-r, r + 1):
			acc += cur[clampi(j, 0, n - 1)]
		for i: int in n:
			nxt[i] = acc / float(2 * r + 1)
			acc += cur[clampi(i + r + 1, 0, n - 1)] - cur[clampi(i - r, 0, n - 1)]
		cur = nxt
	return cur


static func crop_zoom(m: PackedVector2Array, target: PackedVector2Array, a: PackedFloat64Array, f: PackedFloat64Array, lp: Vector2) -> float:
	var mc: Vector2 = lp * 0.5
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(lp.x, 0.0), lp, Vector2(0.0, lp.y)]
	var u_min: float = 1.0
	for i: int in m.size():
		var fi: float = maxf(f[i], 0.0001)
		var base: Vector2 = m[i] + (mc - target[i]).rotated(-a[i]) / fi
		for c: Vector2 in corners:
			var dir: Vector2 = (c - mc).rotated(-a[i]) / fi
			u_min = minf(u_min, _limit(base.x, dir.x, lp.x))
			u_min = minf(u_min, _limit(base.y, dir.y, lp.y))
	if u_min <= 1.0 / ZOOM_MAX:
		return ZOOM_MAX
	return 1.0 / u_min


static func _limit(a: float, b: float, hi: float) -> float:
	if a < 0.0 or a > hi:
		return 0.0
	if b > 0.000001:
		return (hi - a) / b
	if b < -0.000001:
		return -a / b
	return 1.0

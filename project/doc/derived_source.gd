extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const MaskShape := preload("res://doc/mask_shape.gd")
const Parenting := preload("res://doc/parenting.gd")
const Puppet := preload("res://doc/puppet.gd")
const MaskPass := preload("res://engine/mask_pass.gd")
const PairLayout := preload("res://engine/pair_layout.gd")
const PREFIX := "derived."
const VISIBLE := "derived.visible"
const ON_SCREEN := "derived.on_screen"
const SPEED := "derived.speed"
const SPEED_WIDTHS := "derived.speed_widths"
const SPIN := "derived.spin"
const PATH_PROGRESS := "derived.path"
const DISTANCE := "derived.distance:"
const PIN := "derived.pin:"
const MASK_VISIBLE := "derived.mask_visible:"
const CROP_ID := "crop"
const DEFAULT_FPS := 30.0
const PATH_STEPS_MAX := 512
const MEMO_MAX := 8192
const BAKE_KEYS_MAX := 4096
const DISTANCE_LIST_MAX := 12

static var _memo: Dictionary = {}
static var _memo_token: int = -1
static var _paths: Dictionary = {}
static var evaluations: int = 0
static var memo_hits: int = 0


static func is_derived(path: String) -> bool:
	return path.begins_with(PREFIX)


static func forget() -> void:
	_memo = {}
	_memo_token = -1
	_paths = {}


static func label_of(path: String, d: Object = null) -> String:
	if path == VISIBLE:
		return "Visible area, percent of the frame"
	if path == ON_SCREEN:
		return "How much of it is on screen, percent"
	if path == SPEED:
		return "Speed, pixels a second"
	if path == SPEED_WIDTHS:
		return "Speed, frame widths a second"
	if path == SPIN:
		return "Turning speed, degrees a second"
	if path == PATH_PROGRESS:
		return "Along its motion path, percent"
	if path.begins_with(DISTANCE):
		var other: String = path.substr(DISTANCE.length())
		var oc: Object = d.call("clip_by_id", other) if d != null else null
		var name: String = str(oc.get("label")) if oc != null and not str(oc.get("label")).is_empty() else other
		return "Distance to " + name + ", pixels"
	if path.begins_with(PIN):
		var rest: String = path.substr(PIN.length())
		var parts: PackedStringArray = rest.split(".")
		var n: int = int(parts[0]) + 1 if not parts.is_empty() else 1
		return "Puppet pin " + str(n) + " " + (parts[1].to_upper() if parts.size() > 1 else "X") + ", pixels"
	if path.begins_with(MASK_VISIBLE):
		return "Visible area of mask " + path.substr(MASK_VISIBLE.length()) + ", percent of the frame"
	return path


static func paths_for(d: Object, c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null:
		return out
	for p: String in [VISIBLE, ON_SCREEN, SPEED, SPEED_WIDTHS, SPIN, PATH_PROGRESS]:
		out.append({"path": p, "label": label_of(p, d)})
	for i: int in c.masks.size():
		var mid: String = String(c.masks[i].get("id", ""))
		if not mid.is_empty():
			out.append({"path": MASK_VISIBLE + mid, "label": "Visible area of " + MaskShape.label_of(c.masks[i], i) + ", percent of the frame"})
	var pins: int = Puppet.pin_count_of(c)
	for j: int in pins:
		for axis: String in ["x", "y"]:
			var pp: String = PIN + str(j) + "." + axis
			out.append({"path": pp, "label": label_of(pp, d)})
	var s: Sequence = d.call("sequence_of_clip", c.id) if d != null else null
	if s != null:
		var listed: int = 0
		for o: Clip in s.all_clips():
			if o == c or listed >= DISTANCE_LIST_MAX:
				continue
			if o.start < c.end() and o.end() > c.start:
				out.append({"path": DISTANCE + o.id, "label": label_of(DISTANCE + o.id, d)})
				listed += 1
	return out


static func depends(d: Object, clip_id: String, path: String) -> Array[String]:
	var out: Array[String] = []
	if d == null:
		return out
	var c: Clip = d.call("clip_by_id", clip_id)
	if c == null:
		return out
	var s: Sequence = d.call("sequence_of_clip", clip_id)
	var chain: Array[Clip] = [c]
	if s != null:
		chain.append_array(Parenting.chain_of(c, s))
	if path.begins_with(DISTANCE):
		var other: Clip = d.call("clip_by_id", path.substr(DISTANCE.length()))
		if other != null:
			chain.append(other)
			if s != null:
				chain.append_array(Parenting.chain_of(other, s))
	for k: Clip in chain:
		for key: String in ["pos", "rotation", "scale", "anchor"]:
			var node: String = k.id + "|transform." + key
			if not out.has(node):
				out.append(node)
	if path.begins_with(PIN):
		var e: Dictionary = Puppet.effect_of(c)
		if not e.is_empty():
			out.append(c.id + "|effects." + String(e.get("uid", "")) + "." + Puppet.KEY_PINS)
	return out


static func sample(d: Object, c: Clip, path: String, local_t: float, fps: float) -> Dictionary:
	if d == null or c == null:
		return {"ok": false, "v": 0.0}
	var s: Sequence = d.call("sequence_of_clip", c.id)
	if s == null:
		return {"ok": false, "v": 0.0}
	var token: int = Parenting.token_of(d as Project) if d is Project else -1
	var key: String = ""
	if token >= 0:
		if token != _memo_token or _memo.size() > MEMO_MAX:
			_memo = {}
			_memo_token = token
		key = c.id + "|" + path + "|" + str(local_t)
		var hit: Variant = _memo.get(key, null)
		if hit is Dictionary:
			memo_hits += 1
			return hit
	evaluations += 1
	var out: Dictionary = _compute(d, s, c, path, c.start + local_t, fps if fps > 0.0 else s.fps, token)
	if not key.is_empty():
		_memo[key] = out
	return out


static func _step(fps: float) -> float:
	return 1.0 / (fps if fps > 0.0 else DEFAULT_FPS)


static func _compute(d: Object, s: Sequence, c: Clip, path: String, t: float, fps: float, token: int) -> Dictionary:
	if path == VISIBLE or path == ON_SCREEN:
		var areas: Vector2 = areas_at(d, s, c, t, fps, token, "")
		if path == VISIBLE:
			return {"ok": true, "v": areas.x / maxf(float(s.width) * float(s.height), 1.0) * 100.0}
		return {"ok": true, "v": areas.x / areas.y * 100.0 if areas.y > 0.000001 else 0.0}
	if path.begins_with(MASK_VISIBLE):
		var ma: Vector2 = areas_at(d, s, c, t, fps, token, path.substr(MASK_VISIBLE.length()))
		return {"ok": true, "v": ma.x / maxf(float(s.width) * float(s.height), 1.0) * 100.0}
	if path == SPEED or path == SPEED_WIDTHS:
		var h: float = _step(fps)
		var a: Vector2 = anchor_at(s, c, t - h, fps, token)
		var b: Vector2 = anchor_at(s, c, t, fps, token)
		var v: float = a.distance_to(b) / h
		return {"ok": true, "v": v if path == SPEED else v / maxf(float(s.width), 1.0)}
	if path == SPIN:
		var h2: float = _step(fps)
		var r0: float = float(Parenting.world_tf(c, s, t - h2, fps, token)["rotation"])
		var r1: float = float(Parenting.world_tf(c, s, t, fps, token)["rotation"])
		return {"ok": true, "v": wrapf(r1 - r0, -180.0, 180.0) / h2}
	if path.begins_with(DISTANCE):
		var o: Clip = s.clip_by_id(path.substr(DISTANCE.length()))
		if o == null:
			return {"ok": false, "v": 0.0}
		return {"ok": true, "v": anchor_at(s, c, t, fps, token).distance_to(anchor_at(s, o, t, fps, token))}
	if path == PATH_PROGRESS:
		return {"ok": true, "v": path_progress(d, s, c, t, fps)}
	if path.begins_with(PIN):
		var parts: PackedStringArray = path.substr(PIN.length()).split(".")
		var e: Dictionary = Puppet.effect_of(c)
		var pins: PackedVector2Array = Puppet.pins_at(c, e, t, fps) if not e.is_empty() else PackedVector2Array()
		var n: int = int(parts[0]) if not parts.is_empty() else 0
		if n < 0 or n >= pins.size():
			return {"ok": false, "v": 0.0}
		var anchor: Vector2 = Parenting.local_tf(c, t, fps)["anchor"]
		var at: Vector2 = Vector2(float(s.width), float(s.height)) * 0.5 + Parenting.world_frame(c, s, t, fps, token) * (pins[n] - anchor)
		return {"ok": true, "v": at.y if parts.size() > 1 and parts[1] == "y" else at.x}
	return {"ok": false, "v": 0.0}


static func anchor_at(s: Sequence, c: Clip, t: float, fps: float, token: int) -> Vector2:
	return Vector2(float(s.width), float(s.height)) * 0.5 + (Parenting.world_tf(c, s, t, fps, token)["pos"] as Vector2)


static func layer_size(d: Object, s: Sequence, c: Clip) -> Vector2:
	var m: MediaItem = d.call("media_by_id", c.media_id)
	var base: Vector2 = Vector2(float(s.width), float(s.height))
	if c.is_nest() or (m != null and m.kind == "sequence"):
		var ns: Sequence = d.call("sequence_by_id", c.sequence_id if c.is_nest() else m.sequence_id)
		if ns != null:
			base = Vector2(float(ns.width), float(ns.height))
	elif m != null and m.width > 0 and m.height > 0 and m.kind != "adjust":
		base = Vector2(float(m.width), float(m.height))
	return PairLayout.picture_size(c, base, Vector2(float(s.width), float(s.height)))


static func _param(params: Dictionary, key: String, t: float, dur: float, fps: float) -> float:
	var p: Variant = params.get(key, null)
	if p is Dictionary:
		return AnimProp.evaluate_float(p, t, dur, fps)
	if p is float or p is int:
		return float(p)
	return 0.0


static func crop_rect(c: Clip, local: float, fps: float) -> Rect2:
	var r: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) != CROP_ID or not bool(e.get("enabled", true)):
			continue
		var params: Dictionary = e.get("params", {})
		var l: float = clampf(_param(params, "left", c.fx_inner(e, "left", local), c.duration, fps), 0.0, 1.0)
		var tp: float = clampf(_param(params, "top", c.fx_inner(e, "top", local), c.duration, fps), 0.0, 1.0)
		var rr: float = clampf(_param(params, "right", c.fx_inner(e, "right", local), c.duration, fps), 0.0, 1.0)
		var b: float = clampf(_param(params, "bottom", c.fx_inner(e, "bottom", local), c.duration, fps), 0.0, 1.0)
		r = r.intersection(Rect2(l, tp, maxf(1.0 - rr - l, 0.0), maxf(1.0 - b - tp, 0.0)))
	return r


static func rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func mask_poly(c: Clip, m: Dictionary, local: float, fps: float, size: Vector2) -> PackedVector2Array:
	var box: bool = MaskShape.BOX_KINDS.has(str(m.get("kind", "")))
	var expand: float = float(MaskShape.value_at(m, "expand", local, c.duration, fps))
	var grow: Vector2 = Vector2(expand / maxf(size.x, 1.0), expand / maxf(size.y, 1.0)) if box else Vector2.ZERO
	var pts: PackedVector2Array = MaskPass.shape_points(m, local, c.duration, fps, size.x / maxf(size.y, 1.0), grow)
	var poly: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		poly.append(p * size)
	if not box and absf(expand) > 0.0001 and poly.size() >= 3:
		poly = MaskPass.offset_polygon(poly, expand)
	return poly


static func _clip_all(a: Array, b: PackedVector2Array) -> Array:
	var out: Array = []
	for p: Variant in a:
		out.append_array(Geometry2D.clip_polygons(p, b))
	return out


static func _intersect_all(a: Array, b: PackedVector2Array) -> Array:
	var out: Array = []
	for p: Variant in a:
		out.append_array(Geometry2D.intersect_polygons(p, b))
	return out


static func _merge_all(a: Array, b: PackedVector2Array) -> Array:
	var fresh: Array = [b]
	for p: Variant in a:
		var cut: Array = []
		for q: Variant in fresh:
			cut.append_array(Geometry2D.clip_polygons(q, p))
		fresh = cut
	var out: Array = a.duplicate()
	out.append_array(fresh)
	return out


static func area_of(polys: Array) -> float:
	var total: float = 0.0
	for p: Variant in polys:
		var poly: PackedVector2Array = p
		if poly.size() < 3:
			continue
		var a: float = 0.0
		for i: int in poly.size():
			a += poly[i].cross(poly[(i + 1) % poly.size()])
		total += absf(a) * 0.5 * (-1.0 if Geometry2D.is_polygon_clockwise(poly) else 1.0)
	return absf(total)


static func content_polys(c: Clip, local: float, fps: float, size: Vector2, only_mask: String) -> Array:
	var whole: PackedVector2Array = rect_poly(Rect2(Vector2.ZERO, size))
	var cr: Rect2 = crop_rect(c, local, fps)
	var crop: PackedVector2Array = rect_poly(Rect2(cr.position * size, cr.size * size))
	var cover: Array = [whole]
	var bound: PackedStringArray = PackedStringArray()
	for e: Dictionary in c.effects:
		var mid: String = str(e.get("mask", ""))
		if not mid.is_empty():
			bound.append(mid)
	var first: bool = true
	for i: int in c.masks.size():
		var m: Dictionary = c.masks[i]
		var mid2: String = String(m.get("id", ""))
		if not only_mask.is_empty() and mid2 != only_mask:
			continue
		if only_mask.is_empty() and (not bool(m.get("enabled", true)) or bound.has(MaskPass.mask_id(m, i))):
			continue
		var poly: PackedVector2Array = mask_poly(c, m, local, fps, size)
		if poly.size() < 3:
			continue
		var shape: Array = [poly]
		if MaskPass.invert_of(m, local, c.duration, fps):
			shape = Geometry2D.clip_polygons(whole, poly)
		var mode: int = 0 if not only_mask.is_empty() else MaskPass.mode_of(m, local, c.duration, fps)
		if first:
			cover = shape if mode != 1 else _subtract(whole, shape)
			first = false
		elif mode == 1:
			for sp: Variant in shape:
				cover = _clip_all(cover, sp)
		elif mode == 2:
			var kept: Array = []
			for sp2: Variant in shape:
				kept.append_array(_intersect_all(cover, sp2))
			cover = kept
		else:
			for sp3: Variant in shape:
				cover = _merge_all(cover, sp3)
	return _intersect_all(cover, crop)


static func _subtract(whole: PackedVector2Array, shape: Array) -> Array:
	var out: Array = [whole]
	for sp: Variant in shape:
		out = _clip_all(out, sp)
	return out


static func areas_at(d: Object, s: Sequence, c: Clip, t: float, fps: float, token: int, only_mask: String) -> Vector2:
	var size: Vector2 = layer_size(d, s, c)
	var local: float = c.anim_time(t - c.start)
	var polys: Array = content_polys(c, local, fps, size, only_mask)
	var tf: Dictionary = Parenting.world_tf(c, s, t, fps, token)
	var pivot: Vector2 = size * 0.5 + (tf["anchor"] as Vector2)
	var centre: Vector2 = Vector2(float(s.width), float(s.height)) * 0.5 + (tf["pos"] as Vector2)
	var xf: Transform2D = Transform2D(deg_to_rad(float(tf["rotation"])), tf["scale"], 0.0, centre) * Transform2D(0.0, -pivot)
	var screen: Array = []
	for p: Variant in polys:
		var mapped: PackedVector2Array = xf * (p as PackedVector2Array)
		if Geometry2D.is_polygon_clockwise(mapped) != Geometry2D.is_polygon_clockwise(p as PackedVector2Array):
			mapped.reverse()
		screen.append(mapped)
	var own: float = area_of(screen)
	var frame: PackedVector2Array = rect_poly(Rect2(0.0, 0.0, float(s.width), float(s.height)))
	var shown: float = area_of(_intersect_signed(screen, frame))
	return Vector2(shown, own)


static func _intersect_signed(polys: Array, frame: PackedVector2Array) -> Array:
	var out: Array = []
	for p: Variant in polys:
		var poly: PackedVector2Array = p
		var hole: bool = Geometry2D.is_polygon_clockwise(poly)
		var forward: PackedVector2Array = poly.duplicate()
		if hole:
			forward.reverse()
		for q: Variant in Geometry2D.intersect_polygons(forward, frame):
			var piece: PackedVector2Array = q
			if Geometry2D.is_polygon_clockwise(piece) != hole:
				piece.reverse()
			out.append(piece)
	return out


static func path_progress(d: Object, s: Sequence, c: Clip, t: float, fps: float) -> float:
	var live: int = (d as Project).undo.live_serial if d is Project and (d as Project).undo != null else 0
	var serial: int = int(d.get("serial")) if d != null else 0
	var sig: int = [serial, live, c.start, c.duration].hash()
	var hit: Variant = _paths.get(c.id, null)
	var table: PackedFloat64Array = PackedFloat64Array()
	if hit is Dictionary and int((hit as Dictionary)["sig"]) == sig:
		table = (hit as Dictionary)["table"]
	else:
		var n: int = clampi(int(ceil(c.duration * (fps if fps > 0.0 else DEFAULT_FPS))), 2, PATH_STEPS_MAX)
		table.resize(n + 1)
		var prev: Vector2 = anchor_at(s, c, c.start, fps, -1)
		var run: float = 0.0
		table[0] = 0.0
		for i: int in range(1, n + 1):
			var here: Vector2 = anchor_at(s, c, c.start + c.duration * float(i) / float(n), fps, -1)
			run += prev.distance_to(here)
			table[i] = run
			prev = here
		_paths[c.id] = {"sig": sig, "table": table}
	var total: float = table[table.size() - 1]
	if total <= 0.000001:
		return 0.0
	var u: float = clampf((t - c.start) / maxf(c.duration, 0.000001), 0.0, 1.0) * float(table.size() - 1)
	var i0: int = mini(int(floor(u)), table.size() - 2)
	var f: float = u - float(i0)
	return lerpf(table[i0], table[i0 + 1], f) / total * 100.0


static func bake(d: Object, c: Clip, path: String, fps: float) -> Dictionary:
	var dur: float = maxf(c.duration, 0.0)
	var rate: float = fps if fps > 0.0 else DEFAULT_FPS
	var n: int = clampi(int(ceil(dur * rate)), 1, BAKE_KEYS_MAX)
	var prop: Dictionary = AnimProp.make(0.0)
	var first: Dictionary = sample(d, c, path, 0.0, rate)
	if not bool(first["ok"]):
		return {}
	prop = {"a": true, "base": float(first["v"]), "layers": [{"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": "once", "keys": []}]}
	var keys: Array = []
	for i: int in n + 1:
		var lt: float = dur * float(i) / float(n)
		var got: Dictionary = sample(d, c, path, lt, rate)
		keys.append({"t": lt, "v": float(got["v"]) if bool(got["ok"]) else 0.0, "i": "linear"})
	(prop["layers"][0] as Dictionary)["keys"] = keys
	return prop

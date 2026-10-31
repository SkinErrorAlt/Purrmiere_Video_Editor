extends RefCounted

const GRID_W := 24
const GRID_H := 14
const FRAME_W := 48
const FRAME_H := 27
const RATE := 2
const SCALE := 64.0
const DEFAULT_THRESHOLD := 0.8
const HYSTERESIS := 0.08
const DEFAULT_MIN_LEN := 0.5
const DEFAULT_GAP := 1.0
const SWITCH_JUMP := 28.0
const SWITCH_HOLD := 1.0
const SWITCH_LEN := 1.0
const FULL := Rect2(0.0, 0.0, 1.0, 1.0)


static func rect_of(v: Variant) -> Rect2:
	if v is Rect2:
		return v
	if v is Array and (v as Array).size() >= 4:
		var a: Array = v
		return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return FULL


static func rect_array(r: Rect2) -> Array:
	return [snappedf(r.position.x, 0.0001), snappedf(r.position.y, 0.0001), snappedf(r.size.x, 0.0001), snappedf(r.size.y, 0.0001)]


static func rects(list: Variant) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if list is Array:
		for v: Variant in list:
			var r: Rect2 = rect_of(v)
			if r.size.x > 0.0 and r.size.y > 0.0:
				out.append(r)
	return out


static func grey(r: int, g: int, b: int) -> int:
	return (r * 77 + g * 150 + b * 29) >> 8


static func grid_point(i: int) -> Vector2:
	return Vector2((float(i % GRID_W) + 0.5) / float(GRID_W), (float(i / GRID_W) + 0.5) / float(GRID_H))


static func frame_index(view: Rect2, i: int, fw: int, fh: int) -> int:
	var p: Vector2 = view.position + grid_point(i) * view.size
	var x: int = clampi(int(p.x * float(fw)), 0, fw - 1)
	var y: int = clampi(int(p.y * float(fh)), 0, fh - 1)
	return y * fw + x


static func mask(focus: Array[Rect2], drop: Array[Rect2]) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in GRID_W * GRID_H:
		var p: Vector2 = grid_point(i)
		var keep: bool = focus.is_empty()
		for r: Rect2 in focus:
			if r.has_point(p):
				keep = true
				break
		if keep:
			for r: Rect2 in drop:
				if r.has_point(p):
					keep = false
					break
		if keep:
			out.append(i)
	return out


static func sample_from(rgb: PackedByteArray, offset: int, fw: int, fh: int, view: Rect2 = FULL) -> Dictionary:
	var g: PackedByteArray = PackedByteArray()
	var c: PackedByteArray = PackedByteArray()
	g.resize(GRID_W * GRID_H)
	c.resize(GRID_W * GRID_H * 3)
	for i: int in GRID_W * GRID_H:
		var k: int = offset + frame_index(view, i, fw, fh) * 3
		var r: int = rgb[k]
		var gg: int = rgb[k + 1]
		var b: int = rgb[k + 2]
		g[i] = grey(r, gg, b)
		c[i * 3] = r
		c[i * 3 + 1] = gg
		c[i * 3 + 2] = b
	return {"grey": g, "rgb": c, "drop": []}


static func sample_to_dict(s: Dictionary) -> Dictionary:
	var out: Dictionary = {"grey": Marshalls.raw_to_base64(s["grey"]), "rgb": Marshalls.raw_to_base64(s["rgb"]), "drop": (s.get("drop", []) as Array).duplicate(true)}
	for k: String in ["t", "path", "view"]:
		if s.has(k):
			out[k] = s[k]
	return out


static func sample_from_dict(d: Dictionary) -> Dictionary:
	var g: PackedByteArray = Marshalls.base64_to_raw(String(d.get("grey", "")))
	var c: PackedByteArray = Marshalls.base64_to_raw(String(d.get("rgb", "")))
	if g.size() != GRID_W * GRID_H or c.size() != GRID_W * GRID_H * 3:
		return {}
	var out: Dictionary = {"grey": g, "rgb": c, "drop": (d.get("drop", []) as Array).duplicate(true) if d.get("drop") is Array else []}
	for k: String in ["t", "path", "view"]:
		if d.has(k):
			out[k] = d[k]
	return out


static func sample_image(s: Dictionary) -> Image:
	var c: PackedByteArray = s.get("rgb", PackedByteArray())
	if c.size() != GRID_W * GRID_H * 3:
		return Image.create(GRID_W, GRID_H, false, Image.FORMAT_RGB8)
	return Image.create_from_data(GRID_W, GRID_H, false, Image.FORMAT_RGB8, c)


static func prepared(samples: Array, focus: Array[Rect2], drop: Array[Rect2]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Variant in samples:
		if not (s is Dictionary) or not (s as Dictionary).has("grey"):
			continue
		var sd: Dictionary = s
		var own_drop: Array[Rect2] = drop.duplicate()
		own_drop.append_array(rects(sd.get("drop", [])))
		var idx: PackedInt32Array = mask(focus, own_drop)
		if idx.is_empty():
			continue
		var g: PackedByteArray = sd["grey"]
		var c: PackedByteArray = sd["rgb"]
		var sg: PackedInt32Array = PackedInt32Array()
		var mr: float = 0.0
		var mg: float = 0.0
		var mb: float = 0.0
		for i: int in idx:
			sg.append(g[i])
			mr += float(c[i * 3])
			mg += float(c[i * 3 + 1])
			mb += float(c[i * 3 + 2])
		var n: float = float(idx.size())
		out.append({"idx": idx, "grey": sg, "mean": Vector3(mr / n, mg / n, mb / n)})
	return out


static func view_maps(prepared_list: Array[Dictionary], views: Array[Rect2], fw: int, fh: int) -> Array:
	var out: Array = []
	for v: Rect2 in views:
		var per: Array = []
		for s: Dictionary in prepared_list:
			var m: PackedInt32Array = PackedInt32Array()
			for i: int in (s["idx"] as PackedInt32Array):
				m.append(frame_index(v, i, fw, fh) * 3)
			per.append(m)
		out.append(per)
	return out


static func score_frame(px: PackedByteArray, base: int, s: Dictionary, map: PackedInt32Array) -> float:
	var sg: PackedInt32Array = s["grey"]
	var n: int = map.size()
	if n == 0:
		return 0.0
	var diff: int = 0
	var sr: int = 0
	var sgg: int = 0
	var sb: int = 0
	for j: int in n:
		var k: int = base + map[j]
		var r: int = px[k]
		var g: int = px[k + 1]
		var b: int = px[k + 2]
		var fg: int = (r * 77 + g * 150 + b * 29) >> 8
		var d: int = fg - sg[j]
		diff += d if d >= 0 else -d
		sr += r
		sgg += g
		sb += b
	var fn: float = float(n)
	var mean: Vector3 = s["mean"]
	var col: float = (absf(float(sr) / fn - mean.x) + absf(float(sgg) / fn - mean.y) + absf(float(sb) / fn - mean.z)) / 3.0
	var mad: float = float(diff) / fn
	return clampf(1.0 - (mad + 0.5 * col) / SCALE, 0.0, 1.0)


static func score_frames(px: PackedByteArray, fw: int, fh: int, first: int, count: int, prepared_list: Array[Dictionary], maps: Array, out: Array) -> void:
	var fb: int = fw * fh * 3
	for vi: int in maps.size():
		var arr: PackedFloat32Array = out[vi]
		var per: Array = maps[vi]
		for f: int in count:
			var base: int = (first + f) * fb
			if base + fb > px.size():
				break
			var best: float = 0.0
			for si: int in prepared_list.size():
				var sc: float = score_frame(px, base, prepared_list[si], per[si])
				if sc > best:
					best = sc
			arr.append(best)
		out[vi] = arr


static func ranges(scores: PackedFloat32Array, rate: float, threshold: float, min_len: float, gap: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var lo: float = threshold - HYSTERESIS
	var inside: bool = false
	var a: int = 0
	for i: int in scores.size():
		var s: float = scores[i]
		if not inside and s >= threshold:
			inside = true
			a = i
		elif inside and s < lo:
			inside = false
			out.append(Vector2(float(a) / rate, float(i) / rate))
	if inside:
		out.append(Vector2(float(a) / rate, float(scores.size()) / rate))
	var joined: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in out:
		var n: int = joined.size()
		if n > 0 and v.x - joined[n - 1].y <= gap:
			joined[n - 1] = Vector2(joined[n - 1].x, v.y)
		else:
			joined.append(v)
	var kept: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in joined:
		if v.y - v.x >= min_len:
			kept.append(v)
	return kept


static func intersect(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var i: int = 0
	var j: int = 0
	while i < a.size() and j < b.size():
		var lo: float = maxf(a[i].x, b[j].x)
		var hi: float = minf(a[i].y, b[j].y)
		if hi > lo:
			out.append(Vector2(lo, hi))
		if a[i].y < b[j].y:
			i += 1
		else:
			j += 1
	return out


static func frame_grids(px: PackedByteArray, fw: int, fh: int, first: int, count: int) -> Array[PackedByteArray]:
	var out: Array[PackedByteArray] = []
	var fb: int = fw * fh * 3
	for f: int in count:
		var base: int = (first + f) * fb
		if base + fb > px.size():
			break
		var g: PackedByteArray = PackedByteArray()
		g.resize(GRID_W * GRID_H * 3)
		for i: int in GRID_W * GRID_H:
			var k: int = base + frame_index(FULL, i, fw, fh) * 3
			g[i * 3] = px[k]
			g[i * 3 + 1] = px[k + 1]
			g[i * 3 + 2] = px[k + 2]
		out.append(g)
	return out


static func change(a: PackedByteArray, b: PackedByteArray) -> float:
	var n: int = mini(a.size(), b.size())
	if n == 0:
		return 0.0
	var d: int = 0
	for i: int in n:
		var v: int = int(a[i]) - int(b[i])
		d += v if v >= 0 else -v
	return float(d) / float(n)


static func switches(changes: PackedFloat32Array, rate: float, jump: float = SWITCH_JUMP, hold: float = SWITCH_HOLD) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var quiet_need: int = maxi(int(ceil(hold * rate)), 1)
	var last: float = -INF
	for i: int in changes.size():
		if changes[i] < jump:
			continue
		var calm: bool = true
		for k: int in range(i + 1, mini(i + 1 + quiet_need, changes.size())):
			if changes[k] >= jump * 0.6:
				calm = false
				break
		var t: float = float(i) / rate
		if calm and t - last >= hold:
			out.append(t)
			last = t
	return out


static func small_rgb(img: Image, in_place: bool = false) -> PackedByteArray:
	if img == null or img.is_empty():
		return PackedByteArray()
	var small: Image = img
	if small.is_compressed():
		small = img.duplicate() as Image
		small.decompress()
	var owned: bool = in_place or small != img
	while small.get_width() >= FRAME_W * 4 and small.get_height() >= FRAME_H * 4:
		if not owned:
			small = small.duplicate() as Image
			owned = true
		small.shrink_x2()
	if not owned:
		small = small.duplicate() as Image
	small.convert(Image.FORMAT_RGB8)
	small.resize(FRAME_W, FRAME_H, Image.INTERPOLATE_BILINEAR)
	return small.get_data()

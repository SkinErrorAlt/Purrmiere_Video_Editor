extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const Clip := preload("res://doc/clip.gd")
const PairCrop := preload("res://engine/pair_crop.gd")
const FrameCanvas := preload("res://engine/frame_canvas.gd")
const PlaybackClock := preload("res://engine/playback_clock.gd")
const ViewMap := preload("res://doc/view_map.gd")
const PAIR_VIEW_ID := "pair_view"
const REGION_MAX := 8
const FULL := 0
const SIDE := 1
const STACK := 2
const PIP := 3
const LAYOUT_NAMES: PackedStringArray = ["Full view", "Side by side", "Top and bottom", "Picture in picture"]
const LAYOUT_KEY := "layout"
const SPLIT_FIT_KEY := "split_fit"
const SOLO_KEY := "solo"
const OUT_KEY := "out"
const SIZE_DEFAULT := 0.3
const SIZE_MIN := 0.02
const SIZE_MAX := 1.0
const PLACE_MIN := -1.0
const PLACE_MAX := 2.0
const MARGIN := 0.04
const BETTER := 1.0001
const FIT := 0
const FILL := 1
const STRETCH := 2
const ROLE_VIEW := "view"
const ROLE_CELL := "cell"
const ROLE_INSET := "inset"
const ROLE_SOLO := "solo"
const CORNERS: PackedStringArray = ["tl", "tr", "bl", "br"]
const DEFAULT_PLACES: Array[Vector2] = [Vector2(0.2, 0.2), Vector2(0.8, 0.8), Vector2(0.2, 0.8), Vector2(0.8, 0.2)]

static var _parse_cache: Dictionary = {}


static func place_key(i: int) -> String:
	return "place" + str(i)


static func size_key(i: int) -> String:
	return "size" + str(i)


static func default_place(i: int) -> Vector2:
	return DEFAULT_PLACES[posmod(i, DEFAULT_PLACES.size())]


static func default_of(key: String) -> Variant:
	if key == LAYOUT_KEY:
		return float(FULL)
	if key == "grid":
		return false
	if key == SPLIT_FIT_KEY:
		return float(FILL)
	if key.begins_with("place") and key.substr(5).is_valid_int():
		var p: Vector2 = default_place(int(key.substr(5)))
		return [p.x, p.y]
	if key.begins_with("size") and key.substr(4).is_valid_int():
		return SIZE_DEFAULT
	return 0.0


static func canvas_for(src: Vector2i, frame: Vector2i) -> Vector2i:
	if src.x <= 0 or src.y <= 0 or frame.x <= 0 or frame.y <= 0:
		return src
	var fa: float = float(frame.x) / float(frame.y)
	var sa: float = float(src.x) / float(src.y)
	if fa > sa:
		return Vector2i(src.x + 2 * maxi(int(round((float(src.y) * fa - float(src.x)) * 0.5)), 0), src.y)
	return Vector2i(src.x, src.y + 2 * maxi(int(round((float(src.x) / fa - float(src.y)) * 0.5)), 0))


static func source_box(src: Vector2i, canvas: Vector2i) -> Rect2:
	if canvas.x <= 0 or canvas.y <= 0:
		return Rect2(0.0, 0.0, 1.0, 1.0)
	var sz: Vector2 = Vector2(float(src.x) / float(canvas.x), float(src.y) / float(canvas.y))
	return Rect2((Vector2.ONE - sz) * 0.5, sz)


static func has_pair(c: Clip) -> bool:
	if c == null:
		return false
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) == PAIR_VIEW_ID and bool(e.get("enabled", true)):
			return true
	return false


static func picture_size(c: Clip, src: Vector2, frame: Vector2) -> Vector2:
	if not has_pair(c) and (c == null or not FrameCanvas.wants(c.effects)):
		return src
	return Vector2(canvas_for(Vector2i(int(round(src.x)), int(round(src.y))), Vector2i(int(round(frame.x)), int(round(frame.y)))))


static func fill_scale(ar: float, dst_aspect: float, mode: int) -> Vector2:
	if mode == FIT:
		if ar > dst_aspect:
			return Vector2(1.0, dst_aspect / ar)
		return Vector2(ar / dst_aspect, 1.0)
	if mode == FILL:
		if ar > dst_aspect:
			return Vector2(ar / dst_aspect, 1.0)
		return Vector2(1.0, dst_aspect / ar)
	return Vector2.ONE


static func fitted(ar: float, box_aspect: float) -> Vector2:
	return fill_scale(ar, box_aspect, FIT)


static func region_aspect(rect: Rect2, src: Vector2) -> float:
	return maxf(rect.size.x * src.x, 1.0) / maxf(rect.size.y * src.y, 1.0)


static func inset_box(ar: float, canvas_aspect: float, centre: Vector2, size: float) -> Rect2:
	var sz: Vector2 = fitted(ar, canvas_aspect) * maxf(size, 0.0)
	return Rect2(centre - sz * 0.5, sz)


static func centre_for_size(ar: float, canvas_aspect: float, box: Rect2) -> Dictionary:
	var full: Vector2 = fitted(ar, canvas_aspect)
	var s: float = box.size.x / maxf(full.x, 0.000001)
	return {"centre": box.get_center(), "size": s}


static func margin_uv(canvas: Vector2) -> Vector2:
	var m: float = MARGIN * minf(canvas.x, canvas.y)
	return Vector2(m / maxf(canvas.x, 1.0), m / maxf(canvas.y, 1.0))


static func corner_centres(sizes: Array[Vector2], corner: String, canvas: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var m: Vector2 = margin_uv(canvas)
	var right: bool = corner.ends_with("r")
	var bottom: bool = corner.begins_with("b")
	var run: float = 0.0
	for sz: Vector2 in sizes:
		var x: float = 1.0 - m.x - sz.x * 0.5 if right else m.x + sz.x * 0.5
		var y: float = 1.0 - m.y - run - sz.y * 0.5 if bottom else m.y + run + sz.y * 0.5
		out.append(Vector2(x, y))
		run += sz.y + m.y
	return out


static func corner_of(centre: Vector2) -> String:
	return ("b" if centre.y >= 0.5 else "t") + ("r" if centre.x >= 0.5 else "l")


static func grid_columns(aspects: PackedFloat64Array, canvas_aspect: float, gap: float) -> int:
	var count: int = aspects.size()
	if count <= 1:
		return 1
	var base: int = int(ceil(sqrt(float(count))))
	var best: int = base
	var best_area: float = _grid_area(aspects, base, canvas_aspect, gap)
	for cols: int in range(1, count + 1):
		if cols == base:
			continue
		var a: float = _grid_area(aspects, cols, canvas_aspect, gap)
		if a > best_area * BETTER:
			best = cols
			best_area = a
	return best


static func _grid_area(aspects: PackedFloat64Array, cols: int, canvas_aspect: float, gap: float) -> float:
	var rows: int = int(ceil(float(aspects.size()) / float(cols)))
	var inner: float = maxf(1.0 - gap * 2.0, 0.0001)
	var cw: float = canvas_aspect / float(cols) * inner
	var ch: float = 1.0 / float(rows) * inner
	var worst: float = INF
	for ar: float in aspects:
		var area: float = cw * cw / ar if ar > cw / ch else ch * ch * ar
		worst = minf(worst, area)
	return worst


static func grid_cells(count: int, cols: int, gap: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if count <= 0:
		return out
	var c: int = clampi(cols, 1, count)
	var rows: int = int(ceil(float(count) / float(c)))
	var cell: Vector2 = Vector2(1.0 / float(c), 1.0 / float(rows))
	var inner: float = maxf(1.0 - gap * 2.0, 0.0001)
	for k: int in count:
		var at: Vector2 = Vector2(float(k % c), float(k / c)) * cell
		out.append(Rect2(at + cell * gap, cell * inner))
	return out


static func split_cells(count: int, across: bool) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for k: int in count:
		var f: float = 1.0 / float(count)
		out.append(Rect2(float(k) * f, 0.0, f, 1.0) if across else Rect2(0.0, float(k) * f, 1.0, f))
	return out


static func parse(text: String) -> Array:
	if _parse_cache.has(text):
		return _parse_cache[text]
	var out: Array = []
	var parsed: Variant = JSON.parse_string(text.strip_edges())
	if parsed is Array:
		for v: Variant in parsed:
			if v is Dictionary and (v as Dictionary).get("rect") is Array and ((v as Dictionary)["rect"] as Array).size() >= 4:
				var d: Dictionary = v
				var r: Array = d["rect"]
				out.append({"name": String(d.get("name", "")), "rect": Rect2(float(r[0]), float(r[1]), maxf(float(r[2]), 0.001), maxf(float(r[3]), 0.001)), "rot": float(d.get("rot", 0.0)), OUT_KEY: bool(d.get(OUT_KEY, false))})
	if out.is_empty():
		out.append({"name": "Full", "rect": Rect2(0.0, 0.0, 1.0, 1.0), "rot": 0.0, OUT_KEY: false})
	if _parse_cache.size() > 256:
		_parse_cache.clear()
	_parse_cache[text] = out
	return out


static func crops_text(e: Dictionary) -> String:
	var raw: Variant = (e.get("params", {}) as Dictionary).get("crops", null)
	if raw is Dictionary:
		return String(AnimProp.static_value(raw))
	return ""


static func out_bits(crops: Array) -> int:
	var bits: int = 0
	for i: int in mini(crops.size(), REGION_MAX):
		if bool((crops[i] as Dictionary).get(OUT_KEY, false)):
			bits |= 1 << i
	return bits


static func solo_of(e: Dictionary) -> int:
	var raw: Variant = (e.get("params", {}) as Dictionary).get(SOLO_KEY, null)
	if raw is Dictionary:
		return int(round(float(AnimProp.static_value(raw))))
	return -1


static func group_uniforms(values: Dictionary) -> void:
	var text: Variant = values.get(ViewMap.GROUPS_KEY, "")
	if not (text is String) or (text as String).strip_edges().is_empty():
		return
	var n: int = int(values.get("crop_count", 0))
	if n <= 0:
		n = mini(maxi(parse(String(values.get("crops", ""))).size(), 1), REGION_MAX)
	if ViewMap.members_of(String(text), n).size() < 2:
		return
	values[ViewMap.VIEW_KEY] = float(ViewMap.resolve_values(values, n))
	values[ViewMap.MODE_KEY] = 0


static func fill_uniforms(values: Dictionary, src: Vector2i, canvas: Vector2i, seq: Vector2i) -> void:
	group_uniforms(values)
	values["canvas_px"] = Vector2(canvas)
	var sb: Rect2 = source_box(src, canvas)
	values["source_box"] = Vector4(sb.position.x, sb.position.y, sb.size.x, sb.size.y)
	var crops: Array = parse(String(values.get("crops", "")))
	var bits: int = out_bits(crops)
	values["region_out"] = bits
	values["grid_cols"] = 0
	if int(round(float(values.get(LAYOUT_KEY, 0.0)))) != PIP and int(round(float(values.get(SOLO_KEY, -1.0)))) < 0:
		for i: int in REGION_MAX:
			values.erase(place_key(i))
			values.erase(size_key(i))
			values.erase(PairCrop.turn_key(i))
	PairCrop.fill_uniforms(values, String(values.get("crops", "")))
	if not bool(values.get("grid", false)):
		return
	var n: int = mini(crops.size(), REGION_MAX)
	var aspects: PackedFloat64Array = PackedFloat64Array()
	for i: int in n:
		if (bits >> i) & 1 == 0:
			aspects.append(region_aspect((crops[i] as Dictionary)["rect"], Vector2(src)))
	values["grid_cols"] = grid_columns(aspects, float(canvas.x) / maxf(float(canvas.y), 1.0), float(values.get("grid_gap", 0.01)))


static func index_at(value: float, mode: int, count: int) -> int:
	var n: int = maxi(count, 1)
	if mode == 1:
		return clampi(int(floor(clampf(value, 0.0, 0.99999) * float(n))), 0, n - 1)
	return clampi(int(floor(value + 0.5)), 0, n - 1)


static func value_at(c: Clip, e: Dictionary, key: String, local: float, fps: float, fallback: Variant) -> Variant:
	var p: Variant = (e.get("params", {}) as Dictionary).get(key, null)
	if not (p is Dictionary):
		return fallback
	var at: float = c.fx_time(e, key, local) if e.has(Clip.AnimTime.SPEEDS_FIELD) else c.anim_time(local)
	return AnimProp.evaluate(p, at, c.duration, fps)


static func num_at(c: Clip, e: Dictionary, key: String, local: float, fps: float, fallback: float) -> float:
	var v: Variant = value_at(c, e, key, local, fps, fallback)
	if v is bool:
		return 1.0 if v else 0.0
	if v is float or v is int:
		return float(v)
	return fallback


static func place_at(c: Clip, e: Dictionary, i: int, local: float, fps: float) -> Vector2:
	var v: Variant = value_at(c, e, place_key(i), local, fps, default_place(i))
	if v is Vector2:
		return v
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return default_place(i)


static func size_at(c: Clip, e: Dictionary, i: int, local: float, fps: float) -> float:
	return clampf(num_at(c, e, size_key(i), local, fps, SIZE_DEFAULT), 0.0, SIZE_MAX)


static func state_at(c: Clip, e: Dictionary, t: float, fps: float) -> Dictionary:
	var local: float = t - c.start
	var pick: float = PlaybackClock.clip_local(t, c.start, fps)
	var crops: Array = parse(crops_text(e))
	var n: int = mini(crops.size(), REGION_MAX)
	var mode: int = int(round(num_at(c, e, "view_mode", pick, fps, 0.0)))
	var active: int = index_at(num_at(c, e, "view", pick, fps, 0.0), mode, n)
	if ViewMap.grouped(e):
		active = active_at(c, e, pick, fps, mode, n)
	return {
		"crops": crops, "n": n, "local": local,
		"active": active,
		"grid": num_at(c, e, "grid", pick, fps, 0.0) > 0.5,
		"layout": clampi(int(round(num_at(c, e, LAYOUT_KEY, pick, fps, 0.0))), FULL, PIP),
		"fit": int(round(num_at(c, e, "fit", local, fps, 0.0))),
		"split_fit": int(round(num_at(c, e, SPLIT_FIT_KEY, local, fps, float(FILL)))),
		"zoom": num_at(c, e, "zoom", local, fps, 1.0),
		"pan": Vector2(num_at(c, e, "pan_x", local, fps, 0.0), num_at(c, e, "pan_y", local, fps, 0.0)),
		"gap": num_at(c, e, "grid_gap", local, fps, 0.01),
		"solo": solo_of(e),
	}


static func active_at(c: Clip, e: Dictionary, pick: float, fps: float, mode: int, n: int) -> int:
	var vals: Dictionary = {ViewMap.GROUPS_KEY: ViewMap.groups_text(e), ViewMap.MODE_KEY: mode, ViewMap.GROUP_KEY: num_at(c, e, ViewMap.GROUP_KEY, pick, fps, 0.0)}
	for g: int in ViewMap.GROUP_MAX:
		var k: String = ViewMap.view_key_for(g)
		vals[k] = num_at(c, e, k, pick, fps, 0.0)
	return ViewMap.resolve_values(vals, maxi(n, 1))


static func drawn_part(cell: Rect2, crop: Rect2, ar: float, cell_px: Vector2, mode: int, zoom: float, pan: Vector2) -> Dictionary:
	var sc: Vector2 = fill_scale(ar, cell_px.x / maxf(cell_px.y, 0.000001), mode)
	var z: float = maxf(zoom, 0.01)
	var pv: Vector2 = Vector2(pan.x, -pan.y) * 0.5
	var lo: Vector2 = (Vector2(0.5, 0.5) + (Vector2(-0.5, -0.5) - pv) * sc * z).clamp(Vector2.ZERO, Vector2.ONE)
	var hi: Vector2 = (Vector2(0.5, 0.5) + (Vector2(0.5, 0.5) - pv) * sc * z).clamp(Vector2.ZERO, Vector2.ONE)
	if hi.x <= lo.x or hi.y <= lo.y:
		return {}
	var la: Vector2 = (lo - Vector2(0.5, 0.5)) / sc / z + pv + Vector2(0.5, 0.5)
	var lb: Vector2 = (hi - Vector2(0.5, 0.5)) / sc / z + pv + Vector2(0.5, 0.5)
	var box: Rect2 = Rect2(cell.position + lo * cell.size, (hi - lo) * cell.size)
	var source: Rect2 = Rect2(crop.position + la * crop.size, (lb - la) * crop.size)
	return {"box": box, "source": source}


static func region_boxes(c: Clip, e: Dictionary, t: float, frame: Vector2i, src: Vector2i, fps: float = 30.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null or e.is_empty():
		return out
	var st: Dictionary = state_at(c, e, t, fps)
	var crops: Array = st["crops"]
	var n: int = int(st["n"])
	var canvas: Vector2i = canvas_for(src, frame)
	var cpx: Vector2 = Vector2(canvas)
	var ca: float = cpx.x / maxf(cpx.y, 1.0)
	var srcf: Vector2 = Vector2(src)
	var local: float = float(st["local"])
	var solo: int = int(st["solo"])
	if solo >= 0:
		var si: int = clampi(solo, 0, n - 1)
		var sr: Rect2 = (crops[si] as Dictionary)["rect"]
		out.append(_turned(_box(crops, si, inset_box(region_aspect(sr, srcf), ca, place_at(c, e, si, local, fps), size_at(c, e, si, local, fps)), sr, ROLE_SOLO), c, e, local, fps, ca))
		return out
	var shown: Array[int] = []
	for i: int in n:
		if not bool((crops[i] as Dictionary).get(OUT_KEY, false)):
			shown.append(i)
	var zoom: float = float(st["zoom"])
	var pan: Vector2 = st["pan"]
	if bool(st["grid"]):
		var aspects: PackedFloat64Array = PackedFloat64Array()
		for i2: int in shown:
			aspects.append(region_aspect((crops[i2] as Dictionary)["rect"], srcf))
		var cells: Array[Rect2] = grid_cells(shown.size(), grid_columns(aspects, ca, float(st["gap"])), float(st["gap"]))
		for k: int in shown.size():
			_add_part(out, crops, shown[k], cells[k], cpx, srcf, int(st["fit"]), zoom, pan, ROLE_CELL)
		return out
	var layout: int = int(st["layout"])
	if layout == SIDE or layout == STACK:
		var parts: Array[Rect2] = split_cells(shown.size(), layout == SIDE)
		for k2: int in shown.size():
			_add_part(out, crops, shown[k2], parts[k2], cpx, srcf, int(st["split_fit"]), zoom, pan, ROLE_CELL)
		return out
	var active: int = int(st["active"])
	if layout == PIP:
		for k3: int in range(shown.size() - 1, -1, -1):
			var j: int = shown[k3]
			if j == active:
				continue
			var jr: Rect2 = (crops[j] as Dictionary)["rect"]
			out.append(_turned(_box(crops, j, inset_box(region_aspect(jr, srcf), ca, place_at(c, e, j, local, fps), size_at(c, e, j, local, fps)), jr, ROLE_INSET), c, e, local, fps, ca))
	_add_part(out, crops, active, Rect2(0.0, 0.0, 1.0, 1.0), cpx, srcf, int(st["fit"]), zoom, pan, ROLE_VIEW)
	return out


static func _box(crops: Array, i: int, box: Rect2, source: Rect2, role: String) -> Dictionary:
	return {"index": i, "name": String((crops[i] as Dictionary).get("name", "")), "box": box, "source": source, "role": role, "rot": float((crops[i] as Dictionary).get("rot", 0.0))}


static func _add_part(out: Array[Dictionary], crops: Array, i: int, cell: Rect2, cpx: Vector2, srcf: Vector2, mode: int, zoom: float, pan: Vector2, role: String) -> void:
	if i < 0 or i >= crops.size():
		return
	var r: Rect2 = (crops[i] as Dictionary)["rect"]
	var part: Dictionary = drawn_part(cell, r, region_aspect(r, srcf), cell.size * cpx, mode, zoom, pan)
	if part.is_empty():
		return
	out.append(_box(crops, i, part["box"], part["source"], role))


static func pair_entry(c: Clip) -> Dictionary:
	if c == null:
		return {}
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) == PAIR_VIEW_ID and bool(e.get("enabled", true)):
			return e
	return {}


static func hits(c: Clip, t: float, frame: Vector2i, src: Vector2i, uv: Vector2, fps: float) -> bool:
	var e: Dictionary = pair_entry(c)
	if e.is_empty() or solo_of(e) < 0:
		return true
	return region_at(region_boxes(c, e, t, frame, src, fps), uv) >= 0


static func region_at(boxes: Array[Dictionary], uv: Vector2) -> int:
	for b: Dictionary in boxes:
		var at: Vector2 = PairCrop.turned(b, (b["box"] as Rect2).get_center()).affine_inverse() * uv if b.has("turn") else uv
		if (b["box"] as Rect2).has_point(at) or (b["box"] as Rect2).end.is_equal_approx(at):
			return int(b["index"])
	return -1


static func turn_at(c: Clip, e: Dictionary, i: int, local: float, fps: float) -> float:
	return num_at(c, e, PairCrop.turn_key(i), local, fps, 0.0)


static func _turned(b: Dictionary, c: Clip, e: Dictionary, local: float, fps: float, aspect: float) -> Dictionary:
	var turn: float = turn_at(c, e, int(b["index"]), local, fps)
	if absf(turn) > 0.000001:
		b["turn"] = turn
		b["aspect"] = aspect
	return b

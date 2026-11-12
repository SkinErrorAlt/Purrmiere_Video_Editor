extends RefCounted

const Clip := preload("res://doc/clip.gd")
const Track := preload("res://doc/track.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const Icons := preload("res://ui/kit/icons.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const Fold := preload("res://ui/timeline/timeline_fold.gd")
const PlayheadLook := preload("res://ui/timeline/playhead_look.gd")
const SEAM_HATCH := 4.0
const HATCH_STEP := 8.0
const NAME_ROW := 14.0
const MIN_NAME_W := 30.0
const WAVE_FLOOR_DB := -48.0
const DIAMOND := 4.0
const LEVEL_MIN_H := 24.0
const KEY_MIN_H := 40.0
const KEY_GAP := 3.0
const KEY_DRAW_MAX := 97
const STRIPE := 5.0
const STRIPE_MIN_W := 18.0


static func hatch(ci: CanvasItem, r: Rect2, col: Color, step: float = HATCH_STEP) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var pts := PackedVector2Array()
	var x: float = r.position.x - r.size.y
	var right: float = r.end.x
	while x < right:
		var ax: float = maxf(x, r.position.x)
		var bx: float = minf(x + r.size.y, right)
		if bx > ax:
			var ay: float = r.end.y - (ax - x)
			var by: float = r.end.y - (bx - x)
			pts.append(Vector2(ax, ay))
			pts.append(Vector2(bx, by))
		x += step
	if pts.size() >= 2:
		ci.draw_multiline(pts, col, 1.0)


static var _stripe_cache: Dictionary = {}
static var _box_cache: Dictionary = {}


static func stripe_texture(col: Color) -> ImageTexture:
	var key: String = col.to_html(true)
	if _stripe_cache.has(key):
		return _stripe_cache[key]
	var side: int = int(STRIPE * 2.0)
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in range(side):
		for x: int in range(side):
			if (x + y) % side < int(STRIPE):
				img.set_pixel(x, y, col)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_stripe_cache[key] = tex
	return tex


static func stripes(ci: CanvasItem, r: Rect2, col: Color, _band: float = STRIPE) -> void:
	if r.size.x < STRIPE_MIN_W or r.size.y <= 2.0:
		return
	ci.draw_texture_rect(stripe_texture(col), r, true)


static func rounded(ci: CanvasItem, r: Rect2, fill: Color, radius: float, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> void:
	var key: String = fill.to_html(true) + ":" + str(int(radius)) + ":" + border.to_html(true) + ":" + str(border_w)
	var sb: StyleBoxFlat = _box_cache.get(key, null)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = fill
		sb.set_corner_radius_all(int(radius))
		sb.anti_aliasing = radius > 0.0
		sb.anti_aliasing_size = 0.7
		if border_w > 0 and border.a > 0.0:
			sb.border_color = border
			sb.set_border_width_all(border_w)
			sb.draw_center = fill.a > 0.0
		if _box_cache.size() > 512:
			_box_cache.clear()
		_box_cache[key] = sb
	ci.draw_style_box(sb, r)


static func stripe_colour(body: Color) -> Color:
	var base: Color = Tk.c["clip_video"]
	if body.is_equal_approx(base) or body.is_equal_approx(Tk.c["clip_audio"]) or body.is_equal_approx(Tk.c["clip_nest"]) or body.is_equal_approx(Tk.c["clip_adjust"]) or body.is_equal_approx(Tk.c["clip_title"]):
		return Tk.c["clip_stripe"]
	if Tk.is_light():
		return body.darkened(0.06)
	return body.lightened(0.07)


static func lane_fill(kind: String, pinned: bool, nest: bool) -> Color:
	var c: Color = Tk.c["bg_lane_video"] if kind == "video" else Tk.c["bg_lane_audio"]
	if pinned:
		c = Tk.c["bg_pinned"]
	if nest:
		c = c.darkened(0.08)
	return c


static func clip_colour(c: Clip, item: MediaItem, t: Track) -> Color:
	if c.colour >= 0:
		return Tk.label_colour(c.colour).darkened(0.45)
	if item != null and item.colour >= 0:
		return Tk.label_colour(item.colour).darkened(0.45)
	if t != null and t.colour >= 0:
		return Tk.label_colour(t.colour).darkened(0.5)
	if c.is_nest():
		return Tk.c["clip_nest"]
	var kind: String = item.kind if item != null else t.kind
	if kind == "title" or kind == "shape" or kind == "generator":
		return Tk.c["clip_title"]
	if kind == "adjust":
		return Tk.c["clip_adjust"]
	if t != null and t.is_sound(c):
		return Tk.c["clip_audio"]
	return Tk.c["clip_video"]


static func draw_body(ci: CanvasItem, r: Rect2, col: Color, selected: bool, hover: bool, enabled: bool) -> void:
	var body: Color = col
	if not enabled:
		body = body.lerp(Tk.c["bg_lane_video"], 0.55)
	var radius: float = minf(float(Tk.px(Tk.sz("radius_clip"))), r.size.y * 0.5)
	if r.size.x < 24.0 or r.size.y < 12.0:
		ci.draw_rect(r, body, true)
		if hover and not selected:
			ci.draw_rect(r, Tk.c["glass"], true)
		ci.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2(1.0, 1.0)), Tk.c["sol"] if selected else Tk.c["border_soft"], false, 1.0)
		return
	rounded(ci, r, body, radius)
	if enabled and r.size.y >= 10.0:
		var inner: Rect2 = Rect2(r.position + Vector2(2.0, 2.0), r.size - Vector2(4.0, 4.0))
		stripes(ci, inner, stripe_colour(body))
	if hover and not selected:
		rounded(ci, r, Tk.c["glass"], radius)
	if selected:
		rounded(ci, r, Color(0, 0, 0, 0), radius, Tk.c["sol"], 1)
		rounded(ci, r.grow(-1.0), Color(0, 0, 0, 0), maxf(radius - 1.0, 0.0), Tk.c["sol"], 1)
	else:
		rounded(ci, r, Color(0, 0, 0, 0), radius, Tk.c["border_soft"] if enabled else Tk.c["border"], 1)


static func draw_nest_border(ci: CanvasItem, r: Rect2) -> void:
	if r.size.x > 6.0 and r.size.y > 6.0:
		rounded(ci, r.grow(-3.0), Color(0, 0, 0, 0), maxf(float(Tk.px(Tk.sz("radius_clip"))) - 2.0, 0.0), Tk.c["text_faint"], 1)


const PmText := preload("res://ui/kit/pm_text.gd")


static var _row_h_frame: int = -1
static var _row_h: float = NAME_ROW


static func name_row_h() -> float:
	var frame: int = Engine.get_process_frames()
	if frame != _row_h_frame:
		_row_h_frame = frame
		_row_h = maxf(NAME_ROW, ceil(Tk.font("body").get_height(Tk.fs(Tk.sz("font_small")))) + 3.0)
	return _row_h


static func draw_name(ci: CanvasItem, r: Rect2, text: String, right_text: String, font: Font, fs: int) -> void:
	if r.size.x < MIN_NAME_W or r.size.y < font.get_height(fs) + 2.0:
		return
	var y: float = r.position.y + 2.0 + font.get_ascent(fs)
	var pad: float = PmText.pad()
	var row := Rect2(r.position.x, r.position.y, r.size.x, minf(r.size.y, font.get_height(fs) + 4.0))
	var name_right: float = r.end.x - pad
	if not right_text.is_empty():
		var rw: float = PmText.width_of(font, right_text, fs)
		var br: Rect2 = PmText.draw_in(ci, font, Rect2(r.end.x - pad - rw, row.position.y, rw, row.size.y), right_text, fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, y, PmText.WHOLE, row)
		if br.has_area():
			name_right = br.position.x - pad
	PmText.draw_in(ci, font, Rect2(r.position.x + pad, row.position.y, name_right - r.position.x - pad, row.size.y), text, fs, Tk.c["text"], HORIZONTAL_ALIGNMENT_LEFT, y, PmText.ELIDE, row)


static func draw_fades(ci: CanvasItem, r: Rect2, fade_in_px: float, fade_out_px: float) -> void:
	var col: Color = Color(Tk.c["bg_app"], 0.45)
	if fade_in_px > 1.0:
		var w: float = minf(fade_in_px, r.size.x)
		ci.draw_colored_polygon(PackedVector2Array([r.position, Vector2(r.position.x + w, r.position.y), Vector2(r.position.x, r.end.y)]), col)
		ci.draw_line(Vector2(r.position.x, r.end.y), Vector2(r.position.x + w, r.position.y), Tk.c["text_dim"], 1.0)
	if fade_out_px > 1.0:
		var w2: float = minf(fade_out_px, r.size.x)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(r.end.x - w2, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y)]), col)
		ci.draw_line(Vector2(r.end.x - w2, r.position.y), Vector2(r.end.x, r.end.y), Tk.c["text_dim"], 1.0)


static func draw_transition(ci: CanvasItem, r: Rect2, dur_px: float, hot: bool = false, kind: String = "", font: Font = null, fs: int = 0, chosen: bool = false) -> void:
	if dur_px < 2.0 or r.size.x < 1.0:
		return
	var tr := Rect2(r.position, Vector2(r.size.x, r.size.y))
	ci.draw_rect(tr, Color(Tk.c["bg_app"], 0.55 if hot or chosen else 0.4), true)
	var col: Color = Tk.c["text_bright"] if hot or chosen else Tk.c["text_faint"]
	ci.draw_line(tr.position, Vector2(tr.end.x, tr.end.y), col, 1.0)
	ci.draw_line(Vector2(tr.position.x, tr.end.y), Vector2(tr.end.x, tr.position.y), col, 1.0)
	if chosen:
		rounded(ci, tr, Color(0, 0, 0, 0), 3.0, Tk.c["sol"], 2)
		rounded(ci, tr.grow(-2.0), Color(0, 0, 0, 0), 2.0, col, 1)
	else:
		rounded(ci, tr, Color(0, 0, 0, 0), 3.0, col, 2 if hot else 1)
	if hot or chosen:
		ci.draw_rect(Rect2(tr.position.x, tr.position.y, 3.0, tr.size.y), col, true)
		ci.draw_rect(Rect2(tr.end.x - 3.0, tr.position.y, 3.0, tr.size.y), col, true)
	if font != null and fs > 0 and not kind.is_empty() and tr.size.x > 40.0 and tr.size.y > 26.0:
		PmText.draw(ci, font, tr, kind, fs, col, HORIZONTAL_ALIGNMENT_CENTER, PmText.chip_pad(), tr.end.y - 4.0, PmText.WHOLE)


static func draw_free_transition(ci: CanvasItem, r: Rect2, dur_px: float, hot: bool = false, kind: String = "", font: Font = null, fs: int = 0, chosen: bool = false) -> void:
	if dur_px < 2.0 or r.size.x < 1.0:
		return
	var tr := Rect2(r.position, Vector2(r.size.x, r.size.y))
	rounded(ci, tr, Color(Tk.c["bg_app"], 0.62 if hot or chosen else 0.46), 3.0)
	var col: Color = Tk.c["text_bright"] if hot or chosen else Tk.c["text_faint"]
	var step: float = maxf(tr.size.y * 0.5, 6.0)
	var x: float = tr.position.x
	while x < tr.end.x:
		var x1: float = minf(x + step, tr.end.x)
		ci.draw_line(Vector2(x, tr.end.y), Vector2(x1, tr.position.y), Color(col, 0.75), 1.0)
		x += step
	for y: float in [tr.position.y + 1.0, tr.end.y - 1.0]:
		var dx: float = tr.position.x
		while dx < tr.end.x:
			ci.draw_line(Vector2(dx, y), Vector2(minf(dx + 3.0, tr.end.x), y), col, 1.0)
			dx += 6.0
	if chosen:
		rounded(ci, tr, Color(0, 0, 0, 0), 3.0, Tk.c["sol"], 2)
		rounded(ci, tr.grow(-2.0), Color(0, 0, 0, 0), 2.0, col, 1)
	else:
		rounded(ci, tr, Color(0, 0, 0, 0), 3.0, col, 2 if hot else 1)
	if hot or chosen:
		ci.draw_rect(Rect2(tr.position.x, tr.position.y, 3.0, tr.size.y), col, true)
		ci.draw_rect(Rect2(tr.end.x - 3.0, tr.position.y, 3.0, tr.size.y), col, true)
	if font != null and fs > 0 and not kind.is_empty() and tr.size.x > 40.0 and tr.size.y > 26.0:
		PmText.draw(ci, font, tr, kind, fs, col, HORIZONTAL_ALIGNMENT_CENTER, PmText.chip_pad(), tr.end.y - 4.0, PmText.WHOLE)


static func draw_diamond(ci: CanvasItem, at: Vector2, side: float, col: Color, filled: bool) -> void:
	var pts := PackedVector2Array([at + Vector2(0.0, -side), at + Vector2(side, 0.0), at + Vector2(0.0, side), at + Vector2(-side, 0.0)])
	if filled:
		ci.draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		ci.draw_polyline(pts, col, 1.0)


static func draw_level_line(ci: CanvasItem, r: Rect2, c: Clip, prop: Dictionary, lo: float, hi: float, pps: float, show_keys: bool, origin_x: float = -INF) -> void:
	if r.size.y < LEVEL_MIN_H or r.size.x < 4.0:
		return
	var inner: Rect2 = Rect2(r.position + Vector2(0.0, name_row_h() + 2.0), r.size - Vector2(0.0, name_row_h() + 4.0))
	if inner.size.y < 6.0:
		return
	var col: Color = Tk.c["text_bright"]
	if not AnimProp.is_animated(prop):
		var v: float = clampf(AnimProp.evaluate_float(prop, 0.0, c.duration), lo, hi)
		var y: float = inner.end.y - (v - lo) / maxf(hi - lo, 0.0001) * inner.size.y
		ci.draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(col, 0.7), 1.0)
		return
	var clip_x0: float = origin_x if origin_x > -INF else r.position.x
	var with_keys: bool = show_keys and r.size.y >= KEY_MIN_H
	var shift: float = inner.position.x - clip_x0
	var sig: Array = ["line", prop.hash(), anim_sig(c), inner.size, shift, pps, lo, hi, with_keys, colour_sig()]
	var entry: Dictionary = cached(sig)
	if entry.is_empty():
		entry = level_entry(c, prop, lo, hi, pps, inner.size, shift, with_keys)
		remember(sig, entry)
	ci.draw_set_transform(inner.position, 0.0, Vector2.ONE)
	var pts: PackedVector2Array = entry["pts"]
	if pts.size() >= 2:
		ci.draw_polyline_colors(pts, entry["cols"], 1.0, true)
	draw_batch(ci, entry)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static var _draw_cache: Dictionary = {}
static var draw_cache_hits: int = 0
static var draw_cache_misses: int = 0
const DRAW_CACHE_MAX := 512
const LINE_STEP := 6.0


static func colour_sig() -> Array:
	return [Tk.c["key_negative"], Tk.c["key_over"], Tk.c["key_low"], Tk.c["key_high"]]


static func anim_sig(c: Clip) -> Array:
	if c.anim_warped() or c.has_inner_speeds():
		return [c.duration, c.anim_start, c.anim_speed.hash(), c.speed_sig()]
	return [c.duration]


static func level_path(c: Clip, prop: Dictionary) -> String:
	if is_same(prop, c.transform.get("opacity")):
		return "transform.opacity"
	if is_same(prop, c.audio.get("volume")):
		return "audio.volume"
	return ""


static func cached(sig: Array) -> Dictionary:
	var entry: Dictionary = _draw_cache.get(sig, {})
	if entry.is_empty():
		draw_cache_misses += 1
	else:
		draw_cache_hits += 1
	return entry


static func remember(sig: Array, entry: Dictionary) -> void:
	if _draw_cache.size() >= DRAW_CACHE_MAX:
		_draw_cache.clear()
	_draw_cache[sig] = entry


static func clear_draw_cache() -> void:
	_draw_cache.clear()


static func level_entry(c: Clip, prop: Dictionary, lo: float, hi: float, pps: float, size: Vector2, shift: float, with_keys: bool) -> Dictionary:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var xs_line: PackedFloat64Array = PackedFloat64Array()
	var ts_line: PackedFloat64Array = PackedFloat64Array()
	var x: float = 0.0
	var lpath: String = level_path(c, prop)
	while x <= size.x:
		xs_line.append(x)
		ts_line.append(c.param_time(lpath, (x + shift) / pps))
		x += LINE_STEP
	var span: float = maxf(hi - lo, 0.0001)
	var raws: PackedFloat64Array = curve_values(prop, ts_line, c.duration, 0.0, 0, not c.path_warped(lpath))
	for q: int in raws.size():
		var raw: float = raws[q]
		var v: float = clampf(raw, lo, hi)
		pts.append(Vector2(xs_line[q], size.y - (v - lo) / span * size.y))
		cols.append(Tk.key_colour(raw, lo, hi, raw > hi or raw < lo))
	var centres := PackedVector2Array()
	var dcols := PackedColorArray()
	if with_keys:
		var ks: Array = key_list(prop)
		var picked: Dictionary = pick_keys(c, lpath, ks, -shift, pps, -4.0, size.x + 4.0, -INF, false, KEY_DRAW_MAX)
		var idx: PackedInt32Array = picked["i"]
		var xs: PackedFloat64Array = picked["x"]
		var kts: PackedFloat64Array = PackedFloat64Array()
		for j: int in idx.size():
			kts.append(float((ks[idx[j]] as Dictionary).get("t", 0.0)))
		var kraws: PackedFloat64Array = curve_values(prop, kts, c.duration, 0.0, 0, true)
		for j: int in idx.size():
			var raw: float = kraws[j]
			var kv: float = clampf(raw, lo, hi)
			centres.append(Vector2(xs[j], size.y - (kv - lo) / span * size.y))
			dcols.append(Tk.key_colour(raw, lo, hi, raw > hi or raw < lo))
	var out: Dictionary = diamond_batch(centres, dcols)
	out["pts"] = pts
	out["cols"] = cols
	return out


static func diamond_batch(centres: PackedVector2Array, cols: PackedColorArray) -> Dictionary:
	var tri_pts := PackedVector2Array()
	var tri_cols := PackedColorArray()
	var tri_idx := PackedInt32Array()
	for j: int in centres.size():
		var at: Vector2 = centres[j]
		var b: int = tri_pts.size()
		tri_pts.append(at + Vector2(0.0, -DIAMOND))
		tri_pts.append(at + Vector2(DIAMOND, 0.0))
		tri_pts.append(at + Vector2(0.0, DIAMOND))
		tri_pts.append(at + Vector2(-DIAMOND, 0.0))
		for q: int in 4:
			tri_cols.append(cols[j])
		tri_idx.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))
	return {"centres": centres, "dcols": cols, "tri_pts": tri_pts, "tri_cols": tri_cols, "tri_idx": tri_idx}


static func draw_batch(ci: CanvasItem, entry: Dictionary) -> void:
	var idx: PackedInt32Array = entry.get("tri_idx", PackedInt32Array())
	if idx.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, entry["tri_pts"], entry["tri_cols"])


static func value_comp(v: Variant, ci: int) -> float:
	if v is Array:
		var a: Array = v
		if ci < a.size():
			return float(a[ci])
		return 0.0
	if v is bool:
		return 1.0 if v else 0.0
	if v is float or v is int:
		return float(v)
	return 0.0


static func curve_values(p: Dictionary, ts: PackedFloat64Array, dur: float, f: float, ci: int, rising: bool) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(ts.size())
	var li: int = AnimProp.keys_layer_index(p)
	var base: Variant = p.get("base", 0.0)
	var fast: bool = AnimProp.is_animated(p) and AnimTime.plain_keys(p) and not (base is bool or base is String)
	var layer: Dictionary = p["layers"][li] if fast else {}
	if fast and str(layer.get("loop", "once")) != "once":
		fast = false
	if not fast:
		for i: int in ts.size():
			out[i] = value_comp(AnimProp.evaluate(p, ts[i], dur, f), ci)
		return out
	var n_comp: int = AnimProp._component_count(p)
	if n_comp > 0 and ci >= n_comp:
		out.fill(0.0)
		return out
	var c: int = -1 if n_comp == 0 else ci
	var base_c: float = AnimProp._comp(base, c)
	var blend: String = str(layer.get("blend", "over"))
	var w: float = float(layer.get("weight", 1.0))
	var ks: Array = AnimProp._prepared_keys(layer.get("keys", []))
	var n: int = ks.size()
	if n == 0:
		out.fill(base_c)
		return out
	var first_v: float = AnimProp._comp((ks[0] as Dictionary).get("v", 0.0), c)
	if n == 1:
		out.fill(AnimProp._blend(base_c, first_v, blend, w))
		return out
	var last_v: float = AnimProp._comp((ks[n - 1] as Dictionary).get("v", 0.0), c)
	var kts: PackedFloat64Array = PackedFloat64Array()
	kts.resize(n)
	for k: int in n:
		kts[k] = float((ks[k] as Dictionary).get("t", 0.0))
	var ka: float = kts[0]
	var kb: float = kts[n - 1]
	var idx: int = 0
	for i: int in ts.size():
		var tt: float = ts[i]
		var cv: float
		if tt < ka:
			cv = first_v
		elif tt >= kb:
			cv = last_v
		else:
			if rising:
				if kts[idx] > tt:
					idx = 0
				while idx + 1 < n - 1 and kts[idx + 1] <= tt:
					idx += 1
			else:
				idx = kts.bsearch(tt, false) - 1
			cv = AnimProp._eval_segment(ks, idx, tt, c)
		out[i] = AnimProp._blend(base_c, cv, blend, w)
	return out


static func draw_opacity_line(ci: CanvasItem, r: Rect2, c: Clip, pps: float, origin_x: float) -> void:
	if r.size.y < KEY_MIN_H:
		return
	var prop: Dictionary = c.get_param("transform.opacity")
	draw_level_line(ci, r, c, prop if not prop.is_empty() else AnimProp.make(1.0), 0.0, 1.0, pps, false, origin_x)


static func key_list(p: Dictionary) -> Array:
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0:
		return []
	var raw: Variant = (p["layers"][li] as Dictionary).get("keys", [])
	if not (raw is Array):
		return []
	return AnimProp._prepared_keys(raw)


static func key_x(c: Clip, path: String, warped: bool, origin_x: float, pps: float, k: Dictionary) -> float:
	var kt: float = float(k.get("t", 0.0))
	return origin_x + (c.first_played_for(path, kt) if warped else kt) * pps


static func _first_at_least(ks: Array, from: int, origin_x: float, pps: float, lo_x: float) -> int:
	var a: int = from
	var b: int = ks.size()
	while a < b:
		var mid: int = (a + b) >> 1
		if origin_x + float((ks[mid] as Dictionary).get("t", 0.0)) * pps < lo_x:
			a = mid + 1
		else:
			b = mid
	return a


static func _first_clear_of(ks: Array, from: int, origin_x: float, pps: float, last_x: float) -> int:
	var a: int = from
	var b: int = ks.size()
	while a < b:
		var mid: int = (a + b) >> 1
		if origin_x + float((ks[mid] as Dictionary).get("t", 0.0)) * pps - last_x < KEY_GAP:
			a = mid + 1
		else:
			b = mid
	return a


static func pick_keys(c: Clip, path: String, ks: Array, origin_x: float, pps: float, lo_x: float, hi_x: float, last_x: float, both_sides: bool, room: int) -> Dictionary:
	var out_i: PackedInt32Array = PackedInt32Array()
	var out_x: PackedFloat64Array = PackedFloat64Array()
	var warped: bool = c.anim_warped() if (path.is_empty() or AnimTime.exempt(path)) else c.path_warped(path)
	var n: int = ks.size()
	var i: int = 0 if warped else _first_at_least(ks, 0, origin_x, pps, lo_x)
	while i < n and out_i.size() < room:
		var kx: float = key_x(c, path, warped, origin_x, pps, ks[i])
		if not warped and kx > hi_x:
			break
		var near: bool = absf(kx - last_x) < KEY_GAP if both_sides else kx - last_x < KEY_GAP
		if kx < lo_x or kx > hi_x or near:
			if not warped and near and kx >= lo_x:
				i = maxi(_first_clear_of(ks, i + 1, origin_x, pps, last_x), i + 1)
			else:
				i += 1
			continue
		last_x = kx
		out_i.append(i)
		out_x.append(kx)
		i += 1
	return {"i": out_i, "x": out_x, "last_x": last_x}


static func key_span(p: Dictionary) -> Vector2:
	var lo: float = INF
	var hi: float = -INF
	for k: Variant in key_list(p):
		var v: Variant = (k as Dictionary).get("v", 0.0)
		var f: float = float(v) if (v is float or v is int) else (float((v as Array)[0]) if (v is Array and not (v as Array).is_empty()) else 0.0)
		lo = minf(lo, f)
		hi = maxf(hi, f)
	if lo == INF:
		return Vector2(0.0, 1.0)
	return Vector2(lo, hi)


static func key_value(k: Dictionary) -> float:
	var v: Variant = k.get("v", 0.0)
	if v is float or v is int:
		return float(v)
	if v is Array and not (v as Array).is_empty():
		return float((v as Array)[0])
	return 0.0


static func segment_overshoots(p: Dictionary, k: Dictionary, next: Dictionary, dur: float) -> bool:
	if next.is_empty():
		return false
	if AnimTime.plain_keys(p) and AnimTime.segment_stays_inside(k):
		return false
	var ta: float = float(k.get("t", 0.0))
	var tb: float = float(next.get("t", 0.0))
	if tb - ta <= 0.0001:
		return false
	var a: float = key_value(k)
	var b: float = key_value(next)
	var lo: float = minf(a, b)
	var hi: float = maxf(a, b)
	var tol: float = maxf(absf(hi - lo), 1.0) * 0.005
	for i: int in range(1, 8):
		var t: float = ta + (tb - ta) * float(i) / 8.0
		var v: float = AnimProp.evaluate_float(p, t, dur)
		if v > hi + tol or v < lo - tol:
			return true
	return false


static var _over_memo: Dictionary = {}
const OVER_MEMO_MAX := 8192


static func key_overshoots(p: Dictionary, ks: Array, i: int, dur: float, memo_on: bool) -> bool:
	var n: int = ks.size()
	var k: Dictionary = ks[i]
	var next: Dictionary = ks[i + 1] if i + 1 < n else {}
	if not memo_on:
		return segment_overshoots(p, k, next, dur) or (i > 0 and segment_overshoots(p, ks[i - 1], k, dur))
	var li: int = AnimProp.keys_layer_index(p)
	var memo_key: Array = [p.get("base", 0.0), str((p["layers"][li] as Dictionary).get("loop", "once")), ks[i - 2] if i >= 2 else null, ks[i - 1] if i >= 1 else null, k, ks[i + 1] if i + 1 < n else null, ks[i + 2] if i + 2 < n else null]
	var hit: Variant = _over_memo.get(memo_key, null)
	if hit is bool:
		return hit
	var over: bool = segment_overshoots(p, k, next, dur) or (i > 0 and segment_overshoots(p, ks[i - 1], k, dur))
	if _over_memo.size() >= OVER_MEMO_MAX:
		_over_memo.clear()
	_over_memo[memo_key] = over
	return over


static func draw_key_diamonds(ci: CanvasItem, r: Rect2, c: Clip, pps: float, view: Vector2 = Vector2(-INF, INF)) -> void:
	if r.size.y < KEY_MIN_H:
		return
	var params: Array = []
	for path: String in c.param_paths():
		var p: Dictionary = c.get_param(path)
		if AnimProp.is_animated(p):
			params.append(path)
			params.append(p.hash())
	if params.is_empty():
		return
	var lo: float = maxf(r.position.x, view.x) - r.position.x
	var hi: float = minf(r.end.x, view.y) - r.position.x
	var sig: Array = ["keys", params, anim_sig(c), r.size, lo, hi, pps, colour_sig()]
	var entry: Dictionary = cached(sig)
	if entry.is_empty():
		entry = diamond_entry(c, r.size, pps, lo, hi)
		remember(sig, entry)
	ci.draw_set_transform(r.position, 0.0, Vector2.ONE)
	draw_batch(ci, entry)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func diamond_entry(c: Clip, size: Vector2, pps: float, lo_x: float, hi_x: float) -> Dictionary:
	var y: float = size.y - 7.0
	var last_x: float = -INF
	var n: int = 0
	var centres := PackedVector2Array()
	var cols := PackedColorArray()
	for path: String in c.param_paths():
		if n >= KEY_DRAW_MAX:
			break
		var p: Dictionary = c.get_param(path)
		if not AnimProp.is_animated(p):
			continue
		var ks: Array = key_list(p)
		if ks.is_empty():
			continue
		var picked: Dictionary = pick_keys(c, path, ks, 0.0, pps, lo_x, hi_x, last_x, true, KEY_DRAW_MAX - n)
		var idx: PackedInt32Array = picked["i"]
		if idx.is_empty():
			continue
		var xs: PackedFloat64Array = picked["x"]
		last_x = float(picked["last_x"])
		var span: Vector2 = key_span(p)
		var memo_on: bool = AnimTime.plain_keys(p)
		for j: int in idx.size():
			var i: int = idx[j]
			var over: bool = key_overshoots(p, ks, i, c.duration, memo_on)
			centres.append(Vector2(xs[j], y))
			cols.append(Tk.key_colour(key_value(ks[i]), span.x, span.y, over))
		n += idx.size()
	return diamond_batch(centres, cols)


static func draw_playhead(ci: CanvasItem, x: float, y0: float, y1: float, with_head: bool, frame_px: float = 0.0) -> void:
	PlayheadLook.draw(ci, x, y0, y1, {"head": with_head, "frame_px": frame_px})


static func draw_marker(ci: CanvasItem, x: float, y: float, col: Color, has_comment: bool, selected: bool) -> void:
	var pts := PackedVector2Array([Vector2(x - 5.0, y), Vector2(x + 5.0, y), Vector2(x + 5.0, y + 6.0), Vector2(x, y + 11.0), Vector2(x - 5.0, y + 6.0)])
	ci.draw_colored_polygon(pts, col)
	if selected:
		pts.append(pts[0])
		ci.draw_polyline(pts, Tk.c["accent"], 1.0)
	if has_comment:
		ci.draw_circle(Vector2(x, y + 4.0), 1.5, Tk.c["bg_app"])


static func ruler_marks(r: Rect2, scroll_x: float, pps: float, fps: float, fold: Dictionary = {}) -> Dictionary:
	var font: Font = Tk.font("mono")
	var fs: int = Tk.fs(Tk.sz("font_meta"))
	var t_end: float = Fold.real(fold, (scroll_x + r.size.x) / pps)
	var inset: float = PmText.chip_pad()
	var step: float = Lanes.nice_tick(pps, maxf(64.0, PmText.width_of(font, Lanes.ruler_label(maxf(t_end, 0.0), fps, pps), fs) + inset * 2.0 + 4.0))
	var minor: float = step / 4.0
	var major := PackedVector2Array()
	var room := PackedFloat32Array()
	var minors := PackedFloat32Array()
	for piece: Dictionary in Fold.pieces(fold):
		var lo: float = float(piece["lo"])
		var hi: float = float(piece["hi"])
		var off: float = scroll_x + float(piece["cut"]) * pps
		var x_hi: float = r.position.x + hi * pps - off if hi < INF else INF
		var right: float = minf(r.end.x, x_hi)
		if x_hi < r.position.x - 1.0 or r.position.x + lo * pps - off > r.end.x + 1.0:
			continue
		var t0: float = off / pps
		var t1: float = minf((off + r.size.x) / pps, hi)
		var t: float = floor(maxf(t0, lo) / step) * step if lo > 0.0 else floor(t0 / step) * step
		while t <= t1 + step:
			var x: float = r.position.x + t * pps - off
			if t >= lo and t <= hi and x >= r.position.x - 1.0 and x <= r.end.x + 1.0:
				major.append(Vector2(t, x))
				room.append(minf(step * pps, right - x))
			for i: int in range(1, 4):
				var mt: float = t + minor * float(i)
				var mx: float = r.position.x + mt * pps - off
				if mt >= lo and mt <= hi and mx >= r.position.x and mx <= r.end.x:
					minors.append(mx)
			t += step
	var seams: Array[Rect2] = []
	for sp: Vector2 in Fold.seams(fold):
		var sx0: float = Fold.x_of(fold, sp.x, r.position.x, pps, scroll_x)
		var sx1: float = Fold.x_of(fold, sp.y, r.position.x, pps, scroll_x)
		if sx1 >= r.position.x and sx0 <= r.end.x:
			seams.append(Rect2(sx0, r.position.y, sx1 - sx0, r.size.y))
	return {"major": major, "room": room, "minor": minors, "seams": seams, "step": step, "font": font, "fs": fs, "inset": inset}


static func draw_ruler(ci: CanvasItem, r: Rect2, scroll_x: float, pps: float, fps: float, _font_: Font, _fs_: int, fold: Dictionary = {}) -> void:
	ci.draw_rect(r, Tk.c["bg_ruler"], true)
	var m: Dictionary = ruler_marks(r, scroll_x, pps, fps, fold)
	var font: Font = m["font"]
	var fs: int = int(m["fs"])
	var inset: float = float(m["inset"])
	var col_tick: Color = Tk.c["text_faint"]
	var col_text: Color = Tk.c["text_dim"]
	var base_y: float = r.end.y
	var major: PackedVector2Array = m["major"]
	var room: PackedFloat32Array = m["room"]
	for i: int in major.size():
		var x: float = major[i].y
		ci.draw_rect(Rect2(x, base_y - 9.0, 1.0, 9.0), col_tick, true)
		PmText.draw(ci, font, Rect2(x, r.position.y, room[i], r.size.y), Lanes.ruler_label(major[i].x, fps, pps), fs, col_text, HORIZONTAL_ALIGNMENT_LEFT, inset, r.position.y + 2.0 + font.get_ascent(fs), PmText.WHOLE)
	for mx: float in (m["minor"] as PackedFloat32Array):
		ci.draw_rect(Rect2(mx, base_y - 4.0, 1.0, 4.0), col_tick, true)
	for sr: Rect2 in (m["seams"] as Array[Rect2]):
		draw_seam(ci, sr.intersection(r) if sr.intersects(r) else sr)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), Tk.c["border"], true)


static func draw_seam(ci: CanvasItem, r: Rect2) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	ci.draw_rect(r, Color(Tk.c["bg_panel"], 0.85), true)
	hatch(ci, r, Tk.c["hatch"], SEAM_HATCH)
	ci.draw_rect(Rect2(r.position.x, r.position.y, 1.0, r.size.y), Tk.c["border"], true)
	ci.draw_rect(Rect2(r.end.x - 1.0, r.position.y, 1.0, r.size.y), Tk.c["border"], true)


static func draw_fold_seams(ci: CanvasItem, fold: Dictionary, header_w: float, pps: float, scroll_x: float, top: float, bottom: float, right: float) -> int:
	var drawn: int = 0
	for sp: Vector2 in Fold.seams(fold):
		var x0: float = maxf(Fold.x_of(fold, sp.x, header_w, pps, scroll_x), header_w)
		var x1: float = minf(Fold.x_of(fold, sp.y, header_w, pps, scroll_x), right)
		if x1 <= x0 or bottom <= top:
			continue
		draw_seam(ci, Rect2(x0, top, x1 - x0, bottom - top))
		drawn += 1
	return drawn


static func draw_in_out(ci: CanvasItem, r: Rect2, x_in: float, x_out: float) -> void:
	if x_in > -INF and x_out > -INF and x_out > x_in:
		var a: float = maxf(x_in, r.position.x)
		var b: float = minf(x_out, r.end.x)
		if b > a:
			ci.draw_rect(Rect2(a, r.position.y, b - a, 3.0), Tk.c["accent"], true)
	if x_in > -INF and x_in >= r.position.x and x_in <= r.end.x:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x_in, r.position.y), Vector2(x_in + 6.0, r.position.y), Vector2(x_in, r.position.y + 6.0)]), Tk.c["text_bright"])
	if x_out > -INF and x_out >= r.position.x and x_out <= r.end.x:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x_out, r.position.y), Vector2(x_out - 6.0, r.position.y), Vector2(x_out, r.position.y + 6.0)]), Tk.c["text_bright"])


static func wave_amp(byte: int, log_mode: bool, gain: float, cap: float = 1.0) -> float:
	if byte <= 0:
		return 0.0
	var lin: float = float(byte) / 127.0 * gain
	if not log_mode:
		return clampf(lin, 0.0, cap)
	if lin <= 0.0001:
		return 0.0
	var db: float = 20.0 * log(lin) / log(10.0)
	return clampf(1.0 - db / WAVE_FLOOR_DB, 0.0, cap)


static func build_wave_points(bytes: PackedByteArray, from_bucket: int, rate: float, stride: int, log_mode: bool, gain: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = bytes.size() / 2
	if n == 0:
		return pts
	var s: int = maxi(1, stride)
	var count: int = (n + s - 1) / s
	pts.resize(count * 2)
	var bucket_s: float = 1.0 / rate
	var i: int = 0
	var k: int = 0
	while i < n:
		var lo: int = 0
		var hi: int = 0
		var stop: int = mini(i + s, n)
		for j: int in range(i, stop):
			var lo_b: int = bytes[j * 2]
			var hi_b: int = bytes[j * 2 + 1]
			if lo_b == 0 and hi_b == 0:
				continue
			lo = maxi(lo, 128 - lo_b)
			hi = maxi(hi, hi_b - 128)
		var down: float = maxf(wave_amp(lo, log_mode, gain), 0.01)
		var up: float = maxf(wave_amp(hi, log_mode, gain), 0.01)
		var x: float = (float(from_bucket + i) + float(stop - i) * 0.5) * bucket_s
		pts[k] = Vector2(x, -up)
		pts[k + 1] = Vector2(x, down)
		k += 2
		i += s
	return pts


static var _ribbon_indices: Dictionary = {}


static func wave_smooth_steps(spacing_px: float) -> int:
	if spacing_px <= 2.0:
		return 0
	return clampi(int(spacing_px / 2.5), 1, 12)


static func wave_ribbon_indices(pairs: int) -> PackedInt32Array:
	if pairs < 2:
		return PackedInt32Array()
	if _ribbon_indices.has(pairs):
		return _ribbon_indices[pairs]
	var idx := PackedInt32Array()
	idx.resize((pairs - 1) * 6)
	var w: int = 0
	for i: int in range(pairs - 1):
		var a: int = i * 2
		idx[w] = a
		idx[w + 1] = a + 1
		idx[w + 2] = a + 2
		idx[w + 3] = a + 1
		idx[w + 4] = a + 3
		idx[w + 5] = a + 2
		w += 6
	if _ribbon_indices.size() > 64:
		_ribbon_indices.clear()
	_ribbon_indices[pairs] = idx
	return idx


static func build_wave_ribbon(bytes: PackedByteArray, from_bucket: int, rate: float, stride: int, log_mode: bool, gain: float, steps: int, span_from: float = -1.0e30, span_to: float = 1.0e30, origin: float = 0.0, cap: float = 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = bytes.size() / 2
	if n == 0:
		return out
	var s: int = maxi(1, stride)
	var bucket_s: float = 1.0 / rate
	var xs := PackedFloat32Array()
	var ups := PackedFloat32Array()
	var downs := PackedFloat32Array()
	var i: int = 0
	while i < n:
		var lo: int = 0
		var hi: int = 0
		var stop: int = mini(i + s, n)
		for j: int in range(i, stop):
			var lo_b: int = bytes[j * 2]
			var hi_b: int = bytes[j * 2 + 1]
			if lo_b == 0 and hi_b == 0:
				continue
			lo = maxi(lo, 128 - lo_b)
			hi = maxi(hi, hi_b - 128)
		xs.append(clampf((float(from_bucket + i) + float(stop - i) * 0.5) * bucket_s, span_from, span_to) - origin)
		ups.append(maxf(wave_amp(hi, log_mode, gain, cap), 0.005))
		downs.append(maxf(wave_amp(lo, log_mode, gain, cap), 0.005))
		i += s
	var m: int = xs.size()
	if m == 0:
		return out
	var k: int = clampi(steps, 0, 12)
	var pairs: int = 2 + (m - 1) * (k + 1) + 1
	out.resize(pairs * 2)
	var w: int = 0
	var x_first: float = clampf(float(from_bucket) * bucket_s, span_from, span_to) - origin
	out[w] = Vector2(x_first, -ups[0])
	out[w + 1] = Vector2(x_first, downs[0])
	w += 2
	for a: int in range(m - 1):
		out[w] = Vector2(xs[a], -ups[a])
		out[w + 1] = Vector2(xs[a], downs[a])
		w += 2
		for t: int in range(1, k + 1):
			var f: float = float(t) / float(k + 1)
			var e: float = f * f * (3.0 - 2.0 * f)
			var x: float = lerpf(xs[a], xs[a + 1], f)
			out[w] = Vector2(x, -lerpf(ups[a], ups[a + 1], e))
			out[w + 1] = Vector2(x, lerpf(downs[a], downs[a + 1], e))
			w += 2
	out[w] = Vector2(xs[m - 1], -ups[m - 1])
	out[w + 1] = Vector2(xs[m - 1], downs[m - 1])
	w += 2
	var x_last: float = clampf(float(from_bucket + n) * bucket_s, span_from, span_to) - origin
	out[w] = Vector2(x_last, -ups[m - 1])
	out[w + 1] = Vector2(x_last, downs[m - 1])
	return out


static func draw_wave_ribbon(ci: CanvasItem, pts: PackedVector2Array, colour: Color) -> void:
	var pairs: int = pts.size() / 2
	if pairs < 2:
		return
	var idx: PackedInt32Array = wave_ribbon_indices(pairs)
	if idx.is_empty():
		return
	var cols := PackedColorArray([colour])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


static func draw_loading(ci: CanvasItem, r: Rect2, font: Font, fs: int) -> void:
	ci.draw_rect(r, Tk.c["bg_panel_high"], true)
	if r.size.x > 44.0 and r.size.y > 12.0:
		PmText.draw(ci, font, r, "loading", fs, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, PmText.chip_pad(), NAN, PmText.WHOLE)


static func draw_scrollbar(ci: CanvasItem, r: Rect2, scroll: float, content: float, view: float, vertical: bool) -> void:
	ci.draw_rect(r, Tk.c["bg_panel"], true)
	if content <= view or content <= 0.0:
		return
	var frac: float = view / content
	var track_len: float = (r.size.y if vertical else r.size.x) - 4.0
	var len_px: float = maxf(16.0, track_len * frac)
	var pos: float = (track_len - len_px) * clampf(scroll / maxf(content - view, 1.0), 0.0, 1.0) + 2.0
	var thumb: Rect2
	if vertical:
		thumb = Rect2(r.position.x + 2.0, r.position.y + pos, r.size.x - 4.0, len_px)
	else:
		thumb = Rect2(r.position.x + pos, r.position.y + 2.0, len_px, r.size.y - 4.0)
	rounded(ci, thumb, Tk.c["border_soft"], minf(thumb.size.x, thumb.size.y) * 0.5)


static func draw_grip(ci: CanvasItem, r: Rect2, hot: bool) -> void:
	ci.draw_rect(r, Tk.c["bg_panel_alt"], true)
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), Tk.c["border"], true)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), Tk.c["border"], true)
	var col: Color = Tk.c["text_dim"] if hot else Tk.c["text_faint"]
	var cx: float = r.get_center().x
	var cy: float = r.get_center().y
	var pts := PackedVector2Array()
	var x: float = cx - 200.0
	while x < cx + 200.0:
		pts.append(Vector2(x, cy))
		pts.append(Vector2(x + 3.0, cy))
		x += 6.0
	ci.draw_multiline(pts, col, 1.0)

extends RefCounted

const TitleStyle := preload("res://doc/title_style.gd")
const TextAnimators := preload("res://doc/text_animators.gd")
const TextExtras := preload("res://doc/text_extras.gd")
const TextRuns := preload("res://doc/text_runs.gd")
const TextDecode := preload("res://doc/text_decode.gd")
const TextFrame := preload("res://doc/text_frame.gd")
const LetterRig := preload("res://doc/letter_rig.gd")
const ParaAlign := preload("res://doc/text_paragraphs.gd")
const TRUE_BLUR := "true_blur"
const MIN_BLUR := 0.25
const BAND_STEP := 2.0

static var draws: int = 0
static var enabled: bool = true
static var plant_blocks: bool = false
static var plant_ring: bool = false


static func active(props: Dictionary) -> bool:
	if not enabled:
		return false
	return TextFrame.framed(props) or styled(props) or TextAnimators.active(props) or TextExtras.active(props) or TextRuns.active(props) or typing(props) or LetterRig.active(props)


static func styled(props: Dictionary) -> bool:
	if not bool(props.get("fill_on", true)) or not bool(props.get("stroke_on", true)) or not bool(props.get("box_on", true)):
		return true
	if float(props.get("shadow_size", 0.0)) > 0.0 or absf(float(props.get("baseline", 0.0))) > 0.0001:
		return true
	if bool(props.get("underline", false)) or bool(props.get("small_caps", false)) or not String(props.get("script", "")).is_empty():
		return true
	if bool(props.get("box_lines", false)) or bool(props.get("stroke2_on", false)) or float(props.get("text_opacity", 100.0)) < 99.999:
		return true
	if TitleStyle.colour_of(props.get("highlight", null), Color(0, 0, 0, 0)).a > 0.001:
		return true
	if tab_width(props) > 0.0 or tsume_of(props) > 0.0 or ParaAlign.active(props) or not stroke_list(props).is_empty():
		return true
	return TextFrame.is_justify(String(props.get("align", "center")))


static func stroke_list(props: Dictionary) -> Array:
	var raw: Variant = TextRuns.plain(props.get("strokes_more", null))
	if raw is String and not String(raw).is_empty():
		raw = JSON.parse_string(String(raw))
	return raw if raw is Array else []


static func more_strokes(props: Dictionary, scale_f: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var reach: float = 0.0
	for s: Variant in stroke_list(props):
		if not (s is Dictionary) or not bool((s as Dictionary).get("on", true)):
			continue
		var w: float = maxf(float((s as Dictionary).get("width", 0.0)), 0.0) * scale_f
		if w <= 0.0:
			continue
		reach += w
		out.append({"reach": int(round(reach)), "col": TitleStyle.colour_of((s as Dictionary).get("colour", null), Color.BLACK)})
	return out


static func tab_width(props: Dictionary) -> float:
	var v: Variant = TextRuns.plain(props.get("tab_width", 0.0))
	return maxf(float(v), 0.0) if v is float or v is int else 0.0


static func tsume_of(props: Dictionary) -> float:
	var v: Variant = TextRuns.plain(props.get("tsume", 0.0))
	return clampf(float(v), 0.0, 100.0) if v is float or v is int else 0.0


static func may_blur(props: Dictionary) -> bool:
	for a: Dictionary in TextAnimators.list(props):
		if absf(float(a.get("blur", 0.0))) > 0.0001:
			return true
	if not LetterRig.active(props):
		return false
	for k: Variant in props.keys():
		var name_: String = String(k)
		if name_.begins_with("lr_") and name_.ends_with("_blur"):
			var v: Variant = TextRuns.plain(props[k])
			if (v is float or v is int) and float(v) > 0.0001:
				return true
			if props[k] is Dictionary:
				return true
	return false


static func blurred_glyphs(props: Dictionary, size: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if plant_ring or not active(props) or not may_blur(props):
		return out
	var sink: Array = []
	draw(null, props, size, "blurred", sink)
	for g: Variant in sink:
		out.append(g)
	return out


static func side_bearings(ts: TextServer, font_rid: RID, fsz: int, gi: int, adv: float) -> Vector2:
	var sz: Vector2 = ts.font_get_glyph_size(font_rid, Vector2i(fsz, 0), gi)
	if sz.x <= 0.0:
		return Vector2.ZERO
	var off: Vector2 = ts.font_get_glyph_offset(font_rid, Vector2i(fsz, 0), gi)
	return Vector2(maxf(off.x, 0.0), maxf(adv - off.x - sz.x, 0.0))


static func squeeze_line(ts: TextServer, line_rid: RID, styles: Array[Dictionary], run_of: PackedInt32Array, from: int, to: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(maxi(to - from + 1, 1))
	out.fill(-1.0)
	var total: float = 0.0
	for gv: Dictionary in ts.shaped_text_get_glyphs(line_rid):
		var start: int = int(gv.get("start", -1))
		var font_rid: RID = gv.get("font_rid", RID())
		var si: int = run_of[start] if start >= 0 and start < run_of.size() else 0
		var t: float = float((styles[si] if si < styles.size() else {}).get("tsume", 0.0))
		var lr: Vector2 = Vector2.ZERO
		if t > 0.0 and font_rid.is_valid():
			lr = side_bearings(ts, font_rid, int(gv.get("font_size", 16)), int(gv.get("index", 0)), float(gv.get("advance", 0.0))) * t
		var k: int = start - from
		if k >= 0 and k < out.size() and out[k] < 0.0:
			out[k] = total + lr.x
		total += (lr.x + lr.y) * float(maxi(int(gv.get("repeat", 1)), 1))
	var last: float = 0.0
	for i: int in out.size():
		if out[i] < 0.0:
			out[i] = last
		last = out[i]
	out[out.size() - 1] = total
	return out


static func small_caps_runs(props: Dictionary, runs: Array[Dictionary]) -> Array[Dictionary]:
	var base: bool = bool(props.get("small_caps", false))
	var any: bool = base
	for r0: Dictionary in runs:
		if bool(TextRuns.run_style(r0).get("small_caps", false)):
			any = true
	if not any:
		return runs
	var out: Array[Dictionary] = []
	for r: Dictionary in runs:
		var st: Dictionary = TextRuns.run_style(r)
		if not bool(st.get("small_caps", base)):
			out.append(r)
			continue
		var t: String = TextRuns.run_text(r)
		var buf: String = ""
		var buf_small: bool = false
		for ch: String in t:
			var up: String = ch.to_upper()
			var small: bool = up != ch and up.length() == 1
			if small != buf_small and not buf.is_empty():
				out.append(_sc_run(buf, st, buf_small))
				buf = ""
			buf_small = small
			buf += up if small else ch
		if not buf.is_empty():
			out.append(_sc_run(buf, st, buf_small))
	return out


static func _sc_run(text: String, st: Dictionary, small: bool) -> Dictionary:
	var s2: Dictionary = st.duplicate(true)
	if small:
		s2["sc"] = true
	return {"text": text, "style": s2}


static func set_alignment(para: TextParagraph, align: String) -> void:
	if TextFrame.is_justify(align):
		para.alignment = HORIZONTAL_ALIGNMENT_FILL
		var flags: int = TextServer.JUSTIFICATION_WORD_BOUND | TextServer.JUSTIFICATION_TRIM_EDGE_SPACES
		if align != "justify_all":
			flags |= TextServer.JUSTIFICATION_SKIP_LAST_LINE
		para.justification_flags = flags
		return
	para.alignment = HORIZONTAL_ALIGNMENT_LEFT if align == "left" else (HORIZONTAL_ALIGNMENT_RIGHT if align == "right" else HORIZONTAL_ALIGNMENT_CENTER)


static func typing(props: Dictionary) -> bool:
	if TextExtras.count_on(props):
		return true
	var r: Variant = TextAnimators.plain(props.get("reveal", 1.0))
	return (r is float or r is int) and float(r) < 0.99999


static func para_width(props: Dictionary, size: Vector2) -> float:
	return TextFrame.path_width(props, size)


static func path_line(props: Dictionary, size: Vector2) -> PackedVector2Array:
	if size.x < 2.0 or size.y < 2.0 or not TextExtras.path_on(props):
		return PackedVector2Array()
	return TextExtras.path_points(props, size, para_width(props, size))


static func quads(props: Dictionary, size: Vector2) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	draw(null, props, size, "text", out)
	return out


static func bounds(props: Dictionary, size: Vector2) -> Rect2:
	var have: bool = false
	var r: Rect2 = Rect2()
	for q: PackedVector2Array in quads(props, size):
		for p: Vector2 in q:
			if not have:
				r = Rect2(p, Vector2.ZERO)
				have = true
			else:
				r = r.expand(p)
	return r


static func hit(props: Dictionary, size: Vector2, at: Vector2, slack: float = 0.0) -> bool:
	for q: PackedVector2Array in quads(props, size):
		if Geometry2D.is_point_in_polygon(at, q):
			return true
		if slack > 0.0:
			for i: int in q.size():
				var a: Vector2 = q[i]
				var b: Vector2 = q[(i + 1) % q.size()]
				if Geometry2D.get_closest_point_to_segment(at, a, b).distance_to(at) <= slack:
					return true
	return false


static func draw(ci: CanvasItem, props: Dictionary, size: Vector2, part: String, sink: Array = [], detail: bool = false) -> void:
	if props.is_empty() or size.x < 2.0 or size.y < 2.0:
		return
	var glyphs_only: bool = part == "glyphs"
	var runs: Array[Dictionary] = TextRuns.for_props(props, TextExtras.shown_text(props))
	if bool(props.get("uppercase", false)):
		runs = TextRuns.upper_runs(runs)
	runs = small_caps_runs(props, runs)
	var text: String = TextRuns.text_of(runs)
	if text.strip_edges().is_empty():
		return
	var reveal: float = clampf(float(props.get("reveal", 1.0)), 0.0, 1.0)
	var shown: int = text.length()
	var decoding: bool = TextDecode.on(props)
	if TextExtras.count_on(props):
		shown = TextExtras.shown_count(props, text.length())
		if shown <= 0 and not decoding:
			return
	elif reveal < 0.99999:
		shown = int(ceil(float(text.length()) * reveal - 0.0001))
		if shown <= 0 and not decoding:
			return
	var cut: int = shown
	var subs: PackedInt32Array = TextDecode.subs(props, text, shown) if decoding else PackedInt32Array()
	if decoding:
		cut = text.length()
	var plain_len: int = text.length()
	var caret: String = String(props.get("cursor", ""))
	if not caret.is_empty() and shown < text.length() and not decoding:
		var kept: Array[Dictionary] = TextRuns.cut_runs(runs, shown)
		var caret_style: Dictionary = TextRuns.style_at(runs, maxi(shown - 1, 0))
		runs = TextRuns.insert(kept, shown, caret, caret_style)
		text = TextRuns.text_of(runs)
		cut = text.length()
	var scale_f: float = size.y / 1080.0
	var styles: Array[Dictionary] = span_styles(props, runs, scale_f, glyphs_only)
	var run_of: PackedInt32Array = TextRuns.char_runs(runs)
	var para: TextParagraph = TextParagraph.new()
	var pad: float = float(props.get("box_pad", 12.0)) * scale_f
	var on_path: bool = TextExtras.path_on(props)
	para.width = para_width(props, size) if on_path else TextFrame.wrap_width(props, size)
	var align: String = String(props.get("align", "center"))
	var per_para: bool = not on_path and ParaAlign.active(props)
	set_alignment(para, "left" if per_para else align)
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	var tab_px: float = tab_width(props)
	if tab_px > 0.0:
		para.tab_align(PackedFloat32Array([tab_px * scale_f]))
	for i0: int in runs.size():
		para.add_string(TextRuns.run_text(runs[i0]), styles[i0]["font"], int(styles[i0]["size"]))
	var extra_line: float = float(props.get("line_spacing", 0.0)) * scale_f
	var text_size: Vector2 = para.get_size()
	var lines: int = maxi(para.get_line_count(), 1)
	var block_h: float = text_size.y + extra_line * float(lines - 1)
	var block_w: float = text_size.x
	var plan: Array[Dictionary] = []
	if per_para:
		plan = ParaAlign.line_plan(para, props, text)
	var any_tsume: bool = false
	for st_t: Dictionary in styles:
		if float(st_t.get("tsume", 0.0)) > 0.0:
			any_tsume = true
	var squeezes: Array[PackedFloat32Array] = []
	if any_tsume:
		var ts0: TextServer = TextServerManager.get_primary_interface()
		block_w = 0.0
		for li0: int in lines:
			var sp0: Vector2i = para.get_line_range(li0)
			var sq: PackedFloat32Array = squeeze_line(ts0, para.get_line_rid(li0), styles, run_of, sp0.x, sp0.y)
			squeezes.append(sq)
			var lw0: float = float(plan[li0]["w"]) if per_para else para.get_line_width(li0)
			block_w = maxf(block_w, lw0 - sq[sq.size() - 1])
	elif per_para:
		block_w = ParaAlign.block_width(plan, block_w)
	var placed_at: Dictionary = TextFrame.place(props, size, para.width, block_w, block_h, para.get_line_ascent(0))
	var x0: float = float(placed_at["x0"])
	var area_w: float = float(placed_at["w"])
	var y0: float = float(placed_at["y0"])
	if part == "box" or part == "all":
		var box_col: Color = TitleStyle.colour_of(props.get("box_colour", null), Color(0, 0, 0, 0))
		if box_col.a > 0.001 and not on_path and bool(props.get("box_on", true)) and not bool(props.get("box_lines", false)):
			var bx: float = TextFrame.line_x(props, x0, area_w, block_w, not TextFrame.is_justify(align)) - pad
			var bw: float = block_w
			if per_para:
				var lo: float = INF
				var hi: float = -INF
				for lp: int in lines:
					var lwp: float = float(plan[lp]["w"]) - (squeezes[lp][squeezes[lp].size() - 1] if any_tsume else 0.0)
					var lxp: float = TextFrame.line_x_as(String(plan[lp]["align"]), props, x0, area_w, lwp, bool(plan[lp]["last"]))
					lo = minf(lo, lxp)
					hi = maxf(hi, lxp + lwp)
				bx = lo - pad
				bw = hi - lo
			var box := StyleBoxFlat.new()
			box.bg_color = box_col
			box.set_corner_radius_all(int(round(float(props.get("box_radius", 8.0)) * scale_f)))
			box.anti_aliasing = true
			if ci != null:
				ci.draw_style_box(box, Rect2(bx, y0 - pad, bw + pad * 2.0, block_h + pad * 2.0))
		if part == "box":
			return
	var any_outline: bool = false
	for st0: Dictionary in styles:
		if int(st0["outline"]) > 0:
			any_outline = true
	var box_lines: bool = bool(props.get("box_lines", false)) and bool(props.get("box_on", true))
	var line_box_col: Color = TitleStyle.colour_of(props.get("box_colour", null), Color(0, 0, 0, 0))
	if line_box_col.a <= 0.001:
		box_lines = false
	var stroke2: int = 0
	var stroke2_col: Color = TitleStyle.colour_of(props.get("stroke2_colour", null), Color.WHITE)
	if bool(props.get("stroke2_on", false)) and not glyphs_only:
		stroke2 = maxi(int(round(maxf(float(props.get("stroke2_width", 6.0)), 0.0) * scale_f)), 0)
	var more: Array[Dictionary] = []
	if not glyphs_only:
		more = more_strokes(props, scale_f)
	var rid: RID = ci.get_canvas_item() if ci != null else RID()
	var skip_blur: bool = ci != null and not glyphs_only and ci.has_meta(TRUE_BLUR) and not plant_ring
	var ts: TextServer = TextServerManager.get_primary_interface()
	var line_of: PackedInt32Array = PackedInt32Array()
	line_of.resize(text.length())
	for i: int in lines:
		var span: Vector2i = para.get_line_range(i)
		for c: int in range(span.x, mini(span.y, text.length())):
			line_of[c] = i
	var anims: Array[Dictionary] = TextAnimators.list(props)
	var maps: Array[Dictionary] = []
	var unit_text: String = text.substr(0, plain_len) if plain_len < text.length() else text
	for a: Dictionary in anims:
		maps.append(TextAnimators.unit_map(unit_text, String(a["units"]), line_of))
	draws += 1
	var path: Dictionary = {}
	if on_path:
		var total_w: float = 0.0
		for li: int in lines:
			total_w += para.get_line_width(li) - (squeezes[li][squeezes[li].size() - 1] if any_tsume else 0.0)
		var pts: PackedVector2Array = TextExtras.path_points(props, size, para_width(props, size), total_w)
		var lens: PackedFloat64Array = TextExtras.lengths(pts)
		var plen: float = lens[lens.size() - 1] if lens.size() > 0 else 0.0
		var s0: float = float(TextExtras.get_value(props, "path_start")) / 100.0 * plen
		s0 += (plen - total_w) * 0.5 * TextExtras.centring(props)
		path = {"pts": pts, "lens": lens, "s0": s0, "turn": bool(TextExtras.get_value(props, "path_turn")), "done": 0.0}
	var warp: Dictionary = warp_of(props, size, size * 0.5 if on_path else Vector2(x0 + area_w * 0.5, y0 + block_h * 0.5))
	var rigged: bool = LetterRig.active(props)
	var rig_words: PackedInt32Array = LetterRig.word_map(unit_text) if rigged else PackedInt32Array()
	var rig_cache: Dictionary = {}
	var rig_root: Vector2 = Vector2(x0 + area_w * 0.5, y0 + block_h * 0.5)
	var y: float = y0
	for i2: int in lines:
		var line_rid: RID = para.get_line_rid(i2)
		var span2: Vector2i = para.get_line_range(i2)
		var stop_at: int = -1
		if cut < text.length():
			if cut <= span2.x:
				break
			if cut < span2.y:
				stop_at = cut
		var lw: float = para.get_line_width(i2)
		if per_para:
			lw = float(plan[i2]["w"])
		if any_tsume:
			lw -= squeezes[i2][squeezes[i2].size() - 1]
		var lx: float = TextFrame.line_x(props, x0, area_w, lw, i2 == lines - 1)
		if per_para:
			lx = TextFrame.line_x_as(String(plan[i2]["align"]), props, x0, area_w, lw, bool(plan[i2]["last"]))
		if not TextFrame.line_shown(placed_at, y, para.get_line_size(i2).y):
			break
		var asc: float = para.get_line_ascent(i2)
		var desc: float = para.get_line_descent(i2)
		var pos: Vector2 = Vector2(lx, y + asc)
		var placed: Array[Dictionary] = place_line(ts, line_rid, pos, stop_at, anims, maps, scale_f, asc, desc, path, styles, run_of, subs, any_tsume)
		if rigged:
			LetterRig.apply_line(props, placed, rig_words, i2, Rect2(lx, y, lw, para.get_line_size(i2).y), rig_root, scale_f, rig_cache)
		if not warp.is_empty():
			for gw: Dictionary in placed:
				var pivot_l: Vector2 = (gw["at"] as Vector2) + Vector2(float(gw.get("adv", 0.0)) * 0.5, -asc * 0.35)
				gw["xf"] = warp_xf(warp, (gw["xf"] as Transform2D) * pivot_l) * (gw["xf"] as Transform2D)
		if not path.is_empty():
			path["done"] = float(path["done"]) + lw
		if ci == null and part == "blurred":
			for gb: Dictionary in placed:
				if float(gb.get("blur", 0.0)) >= MIN_BLUR:
					var copy: Dictionary = gb.duplicate()
					copy["stroke2"] = stroke2
					copy["stroke2_col"] = stroke2_col
					copy["more"] = more
					copy["line"] = i2
					sink.append(copy)
			y += para.get_line_size(i2).y + extra_line
			continue
		if ci == null:
			for gq: Dictionary in placed:
				if float(gq["opacity"]) <= 0.0:
					continue
				var adv_q: float = float(gq.get("adv", 0.0))
				var at_q: Vector2 = (gq["at"] as Vector2) - Vector2(float(gq.get("lean", 0.0)), 0.0)
				var xf_q: Transform2D = gq["xf"]
				var grow: float = float(gq.get("outline", 0.0)) + float(gq.get("blur", 0.0))
				var box_q: PackedVector2Array = PackedVector2Array([Vector2(at_q.x - grow, at_q.y - asc - grow), Vector2(at_q.x + adv_q + grow, at_q.y - asc - grow), Vector2(at_q.x + adv_q + grow, at_q.y + desc + grow), Vector2(at_q.x - grow, at_q.y + desc + grow)])
				if detail:
					sink.append({"ci": int(gq.get("ci", -1)), "line": i2, "quad": xf_q * box_q})
				else:
					sink.append(xf_q * box_q)
			y += para.get_line_size(i2).y + extra_line
			continue
		if box_lines and not glyphs_only and not on_path and lw > 0.0:
			var lb: StyleBoxFlat = StyleBoxFlat.new()
			lb.bg_color = line_box_col
			lb.set_corner_radius_all(int(round(float(props.get("box_radius", 8.0)) * scale_f)))
			lb.anti_aliasing = true
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
			ci.draw_style_box(lb, Rect2(lx - pad, y - pad * 0.5, lw + pad * 2.0, para.get_line_size(i2).y + pad))
		if on_path and not glyphs_only and not plant_blocks:
			draw_bands(ci, path, warp, placed, scale_f)
		else:
			for gh: Dictionary in placed:
				var hc: Color = gh.get("hl", Color(0, 0, 0, 0))
				if hc.a > 0.001 and not glyphs_only:
					hc.a *= float(gh["opacity"])
					ci.draw_set_transform_matrix(gh["xf"])
					var hat: Vector2 = gh["at"]
					var grow_h: float = 2.0 * scale_f
					ci.draw_rect(Rect2(hat.x - float(gh.get("lean", 0.0)) - 0.5, hat.y - float(gh["asc"]) - grow_h, float(gh["adv"]) + 1.0, float(gh["asc"]) + float(gh["desc"]) + grow_h * 2.0), hc, true)
		if skip_blur:
			var sharp: Array[Dictionary] = []
			for gs: Dictionary in placed:
				if float(gs.get("blur", 0.0)) < MIN_BLUR:
					sharp.append(gs)
			placed = sharp
		for mi: int in range(more.size() - 1, -1, -1):
			var ms: Dictionary = more[mi]
			for gm: Dictionary in placed:
				draw_one(ci, ts, rid, gm, int(gm.get("outline", 0)) + stroke2 + int(ms["reach"]), ms["col"])
		if stroke2 > 0:
			for g0: Dictionary in placed:
				draw_one(ci, ts, rid, g0, int(g0.get("outline", 0)) + stroke2, stroke2_col)
		if any_outline:
			for g: Dictionary in placed:
				if int(g.get("outline", 0)) > 0:
					draw_one(ci, ts, rid, g, int(g["outline"]), g["ocol"])
		for g2: Dictionary in placed:
			draw_one(ci, ts, rid, g2, 0, g2["col"])
		for g3: Dictionary in placed:
			if bool(g3.get("under", false)):
				draw_underline(ci, ts, g3, glyphs_only)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		y += para.get_line_size(i2).y + extra_line


static func caret_layout(props: Dictionary, size: Vector2) -> Dictionary:
	var raw: Variant = TextRuns.plain(props.get("text", ""))
	var text: String = String(raw) if raw is String else ""
	var out: Dictionary = {"text": text, "lines": []}
	if size.x < 2.0 or size.y < 2.0:
		return out
	var runs: Array[Dictionary] = TextRuns.for_props(props, text)
	if bool(props.get("uppercase", false)):
		runs = TextRuns.upper_runs(runs)
	runs = small_caps_runs(props, runs)
	var shaped: String = TextRuns.text_of(runs)
	var scale_f: float = size.y / 1080.0
	var styles: Array[Dictionary] = span_styles(props, runs, scale_f, true)
	var para: TextParagraph = TextParagraph.new()
	para.width = TextFrame.wrap_width(props, size)
	var per_para: bool = ParaAlign.active(props)
	set_alignment(para, "left" if per_para else String(props.get("align", "center")))
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	var tab_px: float = tab_width(props)
	if tab_px > 0.0:
		para.tab_align(PackedFloat32Array([tab_px * scale_f]))
	var empty: bool = shaped.is_empty()
	if empty:
		var st0: Dictionary = span_styles(props, [TextRuns.make(" ", {})], scale_f, true)[0]
		para.add_string(" ", st0["font"], int(st0["size"]))
	else:
		for i0: int in runs.size():
			para.add_string(TextRuns.run_text(runs[i0]), styles[i0]["font"], int(styles[i0]["size"]))
	var extra_line: float = float(props.get("line_spacing", 0.0)) * scale_f
	var lines: int = maxi(para.get_line_count(), 1)
	var block_h: float = para.get_size().y + extra_line * float(lines - 1)
	var block_w: float = 0.0 if empty else para.get_size().x
	var plan: Array[Dictionary] = []
	if per_para and not empty:
		plan = ParaAlign.line_plan(para, props, shaped)
	var any_tsume: bool = false
	for st_t: Dictionary in styles:
		if float(st_t.get("tsume", 0.0)) > 0.0:
			any_tsume = true
	any_tsume = any_tsume and not empty
	var run_of: PackedInt32Array = TextRuns.char_runs(runs) if any_tsume else PackedInt32Array()
	var squeezes: Array[PackedFloat32Array] = []
	if any_tsume:
		block_w = 0.0
		for li0: int in lines:
			var sp0: Vector2i = para.get_line_range(li0)
			var sq: PackedFloat32Array = squeeze_line(TextServerManager.get_primary_interface(), para.get_line_rid(li0), styles, run_of, sp0.x, sp0.y)
			squeezes.append(sq)
			var lw0: float = float(plan[li0]["w"]) if not plan.is_empty() else para.get_line_width(li0)
			block_w = maxf(block_w, lw0 - sq[sq.size() - 1])
	elif not plan.is_empty():
		block_w = ParaAlign.block_width(plan, block_w)
	var placed_at: Dictionary = TextFrame.place(props, size, para.width, block_w, block_h, para.get_line_ascent(0))
	var x0: float = float(placed_at["x0"])
	var area_w: float = float(placed_at["w"])
	var ts: TextServer = TextServerManager.get_primary_interface()
	var y: float = float(placed_at["y0"])
	var list: Array = []
	for i: int in lines:
		var span: Vector2i = para.get_line_range(i)
		if empty:
			span = Vector2i(0, 0)
		var lw: float = 0.0 if empty else para.get_line_width(i)
		if not plan.is_empty():
			lw = float(plan[i]["w"])
		var natural_w: float = lw
		var sq_line: PackedFloat32Array = squeezes[i] if any_tsume else PackedFloat32Array()
		if any_tsume:
			lw -= sq_line[sq_line.size() - 1]
		var lx: float = TextFrame.line_x(props, x0, area_w, lw, i == lines - 1)
		if not plan.is_empty():
			lx = TextFrame.line_x_as(String(plan[i]["align"]), props, x0, area_w, lw, bool(plan[i]["last"]))
		var rid: RID = para.get_line_rid(i)
		var xs: PackedFloat32Array = PackedFloat32Array()
		var hi: int = mini(span.y, text.length())
		for j: int in range(span.x, hi + 1):
			var cx: float = 0.0
			if not empty:
				var cr: Dictionary = ts.shaped_text_get_carets(rid, j)
				var lead: Rect2 = cr.get("leading_rect", Rect2())
				cx = lead.position.x
				if j >= hi and j > span.x and lead == Rect2():
					cx = natural_w
				if any_tsume:
					cx -= sq_line[clampi(j - span.x, 0, sq_line.size() - 1)]
			xs.append(lx + cx)
		var asc: float = para.get_line_ascent(i)
		var desc: float = para.get_line_descent(i)
		var lh: float = para.get_line_size(i).y
		list.append({"from": span.x, "to": hi, "top": y, "asc": asc, "desc": desc, "h": lh, "xs": xs, "x": lx, "w": lw})
		y += lh + extra_line
	out["lines"] = list
	out["warp"] = warp_of(props, size, Vector2(x0 + area_w * 0.5, float(placed_at["y0"]) + block_h * 0.5))
	return out


static func unwarp_point(w: Dictionary, p: Vector2) -> Vector2:
	if w.is_empty():
		return p
	var q: Vector2 = p
	for i: int in 12:
		q += p - warp_point(w, q)
	return q


static func warp_of(props: Dictionary, size: Vector2, centre: Vector2) -> Dictionary:
	var tilt: float = clampf(float(TextExtras.get_value(props, "tilt")), -TextExtras.TILT_MAX, TextExtras.TILT_MAX)
	var slant: float = clampf(float(TextExtras.get_value(props, "slant")), -TextExtras.SLANT_MAX, TextExtras.SLANT_MAX)
	if absf(tilt) < 0.001 and absf(slant) < 0.001:
		return {}
	return {"c": centre, "tilt": deg_to_rad(tilt), "slant": tan(deg_to_rad(slant)), "f": size.y * 1.6}


static func warp_point(w: Dictionary, p: Vector2) -> Vector2:
	if w.is_empty():
		return p
	var c: Vector2 = w["c"]
	var d: Vector2 = p - c
	d.x -= d.y * float(w["slant"])
	var th: float = float(w["tilt"])
	var f: float = float(w["f"])
	var z: float = d.y * sin(th)
	var k: float = f / maxf(f + z, f * 0.05)
	return c + Vector2(d.x * k, d.y * cos(th) * k)


static func warp_xf(w: Dictionary, pivot: Vector2) -> Transform2D:
	var e: float = 1.0
	var p0: Vector2 = warp_point(w, pivot)
	var ex: Vector2 = warp_point(w, pivot + Vector2(e, 0.0)) - p0
	var ey: Vector2 = warp_point(w, pivot + Vector2(0.0, e)) - p0
	var lin: Transform2D = Transform2D(ex / e, ey / e, Vector2.ZERO)
	return Transform2D(lin.x, lin.y, p0 - lin.basis_xform(pivot))


static func caret_line(layout: Dictionary, index: int) -> int:
	var lines: Array = layout.get("lines", [])
	if lines.is_empty():
		return -1
	for i: int in lines.size():
		if index < int((lines[i] as Dictionary)["to"]):
			return i
	return lines.size() - 1


static func caret_rect(layout: Dictionary, index: int) -> Rect2:
	var li: int = caret_line(layout, index)
	if li < 0:
		return Rect2()
	var ln: Dictionary = (layout["lines"] as Array)[li]
	var xs: PackedFloat32Array = ln["xs"]
	var k: int = clampi(index - int(ln["from"]), 0, maxi(xs.size() - 1, 0))
	var x: float = xs[k] if xs.size() > 0 else float(ln["x"])
	return Rect2(x, float(ln["top"]), 0.0, float(ln["h"]))


static func caret_at_point(layout: Dictionary, p: Vector2) -> int:
	var lines: Array = layout.get("lines", [])
	if lines.is_empty():
		return 0
	var li: int = lines.size() - 1
	for i: int in lines.size():
		var ln: Dictionary = lines[i]
		if p.y < float(ln["top"]) + float(ln["h"]):
			li = i
			break
	var ln2: Dictionary = lines[li]
	var xs: PackedFloat32Array = ln2["xs"]
	var from: int = int(ln2["from"])
	var best: int = from
	var best_d: float = INF
	for k: int in xs.size():
		var idx: int = from + k
		if idx == int(ln2["to"]) and li < lines.size() - 1:
			continue
		var dd: float = absf(xs[k] - p.x)
		if dd < best_d:
			best_d = dd
			best = idx
	return best


static func selection_rects(layout: Dictionary, a: int, b: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var lo: int = mini(a, b)
	var hi: int = maxi(a, b)
	if lo == hi:
		return out
	for ln: Dictionary in layout.get("lines", []):
		var from: int = int(ln["from"])
		var to: int = int(ln["to"])
		var s0: int = maxi(lo, from)
		var s1: int = mini(hi, to)
		if s1 <= s0:
			continue
		var xs: PackedFloat32Array = ln["xs"]
		var x0: float = xs[clampi(s0 - from, 0, xs.size() - 1)]
		var x1: float = xs[clampi(s1 - from, 0, xs.size() - 1)]
		out.append(Rect2(minf(x0, x1), float(ln["top"]), absf(x1 - x0), float(ln["h"])))
	return out


static func span_styles(props: Dictionary, runs: Array, scale_f: float, glyphs_only: bool) -> Array[Dictionary]:
	var base_font: String = String(props.get("font", ""))
	var base_bold: bool = bool(props.get("bold", false))
	var base_italic: bool = bool(props.get("italic", false))
	var base_size: float = float(props.get("size", 72.0))
	var base_space: float = float(props.get("letter_spacing", 0.0))
	var base_outline: float = float(props.get("outline", 0.0))
	var base_col: Color = Color.WHITE if glyphs_only else TitleStyle.colour_of(props.get("colour", null), Color.WHITE)
	var base_ocol: Color = Color.WHITE if glyphs_only else TitleStyle.colour_of(props.get("outline_colour", null), Color.BLACK)
	var fill_on: bool = bool(props.get("fill_on", true))
	var stroke_on: bool = bool(props.get("stroke_on", true))
	var spread: float = maxf(float(props.get("shadow_size", 0.0)), 0.0) * scale_f if glyphs_only else 0.0
	var base_under: bool = bool(props.get("underline", false))
	var base_rise: float = float(props.get("baseline", 0.0))
	var base_script: String = String(props.get("script", ""))
	var base_hl: Color = TitleStyle.colour_of(props.get("highlight", null), Color(0, 0, 0, 0))
	var base_op: float = float(props.get("text_opacity", 100.0))
	var base_tsume: float = tsume_of(props)
	var out: Array[Dictionary] = []
	for r: Variant in runs:
		var st: Dictionary = TextRuns.run_style(r)
		var raw_st: Variant = (r as Dictionary).get("style", {}) if r is Dictionary else {}
		var small_cap: bool = raw_st is Dictionary and bool((raw_st as Dictionary).get("sc", false))
		var f: Font = TitleStyle.font_for(String(st.get("font", base_font)), bool(st.get("bold", base_bold)), bool(st.get("italic", base_italic)))
		f = TitleStyle.spaced(f, int(round(float(st.get("letter_spacing", base_space)) * scale_f)))
		var col: Color = base_col
		if not glyphs_only and st.has("colour"):
			col = TitleStyle.colour_of(st["colour"], base_col)
		if not fill_on and not glyphs_only:
			col.a = 0.0
		var ocol: Color = base_ocol
		if not glyphs_only and st.has("outline_colour"):
			ocol = TitleStyle.colour_of(st["outline_colour"], base_ocol)
		var px: float = float(st.get("size", base_size)) * scale_f
		var script: String = String(st.get("script", base_script))
		var rise: float = float(st.get("baseline", base_rise)) * scale_f
		if script == "super":
			rise += px * 0.35
			px *= 0.583
		elif script == "sub":
			rise -= px * 0.15
			px *= 0.583
		if small_cap:
			px *= 0.72
		var outline: float = float(st.get("outline", base_outline)) * scale_f if stroke_on else 0.0
		var op: float = clampf(float(st.get("text_opacity", base_op)) / 100.0, 0.0, 1.0)
		if not glyphs_only:
			col.a *= op
			ocol.a *= op
		var hl: Color = base_hl
		if st.has("highlight"):
			hl = TitleStyle.colour_of(st["highlight"], base_hl)
		out.append({
			"hl": Color(0, 0, 0, 0) if glyphs_only else hl,
			"font": f,
			"size": maxi(int(round(px)), 4),
			"col": col,
			"outline": int(round(maxf(outline, spread))),
			"ocol": ocol,
			"rise": rise,
			"under": bool(st.get("underline", base_under)),
			"tsume": clampf(float(st.get("tsume", base_tsume)), 0.0, 100.0) / 100.0,
		})
	return out


static func draw_underline(ci: CanvasItem, ts: TextServer, g: Dictionary, glyphs_only: bool) -> void:
	var col: Color = Color.WHITE if glyphs_only else (g["col"] as Color)
	col.a *= float(g["opacity"])
	if col.a <= 0.0:
		return
	var font_rid: RID = g["font"]
	var sz: int = int(g["size"])
	var upos: float = ts.font_get_underline_position(font_rid, sz)
	var thick: float = maxf(ts.font_get_underline_thickness(font_rid, sz), 1.0)
	var at: Vector2 = g["at"]
	ci.draw_set_transform_matrix(g["xf"])
	ci.draw_rect(Rect2(at.x - float(g.get("lean", 0.0)), at.y + upos - thick * 0.5, float(g["adv"]), thick), col, true)


static func band_runs(placed: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cur: Dictionary = {}
	for g: Dictionary in placed:
		var hc: Color = g.get("hl", Color(0, 0, 0, 0))
		hc.a *= float(g.get("opacity", 1.0))
		if hc.a <= 0.001 or not g.has("pd"):
			cur = {}
			continue
		var adv: float = float(g.get("adv", 0.0))
		var a: float = float(g.get("pd", 0.0)) - adv * 0.5
		var b: float = float(g.get("pd", 0.0)) + adv * 0.5
		if not cur.is_empty() and (cur["col"] as Color).is_equal_approx(hc) and absf(a - float(cur["to"])) < maxf(adv, 1.0) * 0.75:
			cur["to"] = b
			continue
		var at: Vector2 = g["at"]
		cur = {"col": hc, "from": a, "to": b, "top": at.y - float(g.get("asc", 0.0)), "bottom": at.y + float(g.get("desc", 0.0))}
		out.append(cur)
	return out


static func band_points(path: Dictionary, warp: Dictionary, run: Dictionary, grow: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var d0: float = float(run["from"]) - 0.5
	var d1: float = float(run["to"]) + 0.5
	var n: int = clampi(int(ceil((d1 - d0) / BAND_STEP)), 1, 4000)
	var turn: bool = bool(path.get("turn", true))
	var top: float = float(run["top"]) - grow
	var bottom: float = float(run["bottom"]) + grow
	for i: int in n + 1:
		var d: float = lerpf(d0, d1, float(i) / float(n))
		var hit: Array = TextExtras.sample(path["pts"], path["lens"], d)
		var p: Vector2 = hit[0]
		var ang: float = float(hit[1]) if turn else 0.0
		var nrm: Vector2 = Vector2(-sin(ang), cos(ang))
		out.append(warp_point(warp, p + nrm * top))
		out.append(warp_point(warp, p + nrm * bottom))
	return out


static func draw_bands(ci: CanvasItem, path: Dictionary, warp: Dictionary, placed: Array[Dictionary], scale_f: float) -> int:
	if path.is_empty():
		return 0
	var made: int = 0
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	for run: Dictionary in band_runs(placed):
		var pts: PackedVector2Array = band_points(path, warp, run, 2.0 * scale_f)
		var idx: PackedInt32Array = PackedInt32Array()
		for i: int in pts.size() / 2 - 1:
			var t0: int = i * 2
			idx.append_array([t0, t0 + 2, t0 + 1, t0 + 1, t0 + 2, t0 + 3])
		var cols: PackedColorArray = PackedColorArray()
		cols.resize(pts.size())
		cols.fill(run["col"])
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)
		made += 1
	return made


static func place_line(ts: TextServer, line_rid: RID, pos: Vector2, stop_at: int, anims: Array[Dictionary], maps: Array[Dictionary], scale_f: float, asc: float, desc: float, path: Dictionary = {}, styles: Array[Dictionary] = [], run_of: PackedInt32Array = PackedInt32Array(), subs: PackedInt32Array = PackedInt32Array(), squeeze: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ofs: Vector2 = pos
	var shift: float = 0.0
	for gv: Dictionary in ts.shaped_text_get_glyphs(line_rid):
		var repeat: int = maxi(int(gv.get("repeat", 1)), 1)
		var adv: float = float(gv.get("advance", 0.0))
		var off: Vector2 = gv.get("offset", Vector2.ZERO)
		var font_rid: RID = gv.get("font_rid", RID())
		var start: int = int(gv.get("start", -1))
		var lr: Vector2 = Vector2.ZERO
		if squeeze and font_rid.is_valid():
			var si0: int = run_of[start] if start >= 0 and start < run_of.size() else 0
			var t_s: float = float((styles[si0] if si0 < styles.size() else {}).get("tsume", 0.0))
			if t_s > 0.0:
				lr = side_bearings(ts, font_rid, int(gv.get("font_size", 16)), int(gv.get("index", 0)), adv) * t_s
		for r: int in repeat:
			if stop_at >= 0 and start >= stop_at:
				return out
			shift -= lr.x
			if font_rid.is_valid():
				var st: Dictionary = TextAnimators.glyph_state(anims, maps, start)
				shift += float(st["tracking"]) * scale_f
				var at: Vector2 = ofs + off + Vector2(shift, 0.0)
				var gi: int = int(gv.get("index", 0))
				var lean: float = 0.0
				if start >= 0 and start < subs.size() and subs[start] > 0:
					var fsz: int = int(gv.get("font_size", 16))
					var swap: int = ts.font_get_glyph_index(font_rid, fsz, subs[start], 0)
					if swap != 0:
						gi = swap
						lean = (adv - ts.font_get_glyph_advance(font_rid, fsz, swap).x) * 0.5
				var pivot: Vector2 = Vector2(ofs.x + shift + adv * 0.5, pos.y - (asc - desc) * 0.5)
				var m: Transform2D = Transform2D.IDENTITY
				var sc: float = float(st["scale"])
				var rot: float = deg_to_rad(float(st["rot"]))
				var sk: float = deg_to_rad(clampf(float(st["skew"]), -80.0, 80.0))
				var moved: Vector2 = TextAnimators.vec(st["pos"]) * scale_f
				var pd: float = 0.0
				if not path.is_empty():
					var d: float = float(path["s0"]) + float(path["done"]) + (ofs.x - pos.x) + shift + adv * 0.5
					var hit: Array = TextExtras.sample(path["pts"], path["lens"], d)
					var on: Transform2D = Transform2D(float(hit[1]) if bool(path["turn"]) else 0.0, hit[0])
					pd = d
					var lp: Vector2 = Vector2(0.0, -(asc - desc) * 0.5)
					var local: Transform2D = Transform2D(rot, Vector2(sc, sc), sk, lp + moved) * Transform2D(0.0, -lp)
					m = on * local
					at = Vector2(-adv * 0.5 + off.x, off.y)
				elif not is_equal_approx(sc, 1.0) or not is_zero_approx(rot) or not moved.is_zero_approx() or not is_zero_approx(sk):
					m = Transform2D(rot, Vector2(sc, sc), sk, pivot + moved) * Transform2D(0.0, -pivot)
				var si: int = run_of[start] if start >= 0 and start < run_of.size() else 0
				var sty: Dictionary = styles[si] if si < styles.size() else {"col": Color.WHITE, "outline": 0, "ocol": Color.BLACK}
				if not is_zero_approx(lean):
					at += Vector2(lean, 0.0)
				var rise: float = float(sty.get("rise", 0.0))
				if not is_zero_approx(rise):
					at.y -= rise
				out.append({"font": font_rid, "ci": start, "size": int(gv.get("font_size", 16)), "index": gi, "lean": lean, "at": at, "xf": m, "opacity": float(st["opacity"]), "tint": st["tint"], "tint_w": float(st["tint_w"]), "blur": float(st["blur"]) * scale_f, "adv": adv, "col": sty["col"], "outline": int(sty["outline"]), "ocol": sty["ocol"], "under": bool(sty.get("under", false)), "hl": sty.get("hl", Color(0, 0, 0, 0)), "asc": asc, "desc": desc})
				if not path.is_empty():
					out[out.size() - 1]["pd"] = pd
			ofs.x += adv
			shift -= lr.y
	return out


static func draw_one(ci: CanvasItem, ts: TextServer, rid: RID, g: Dictionary, outline: int, base: Color) -> void:
	var col: Color = base
	var tw: float = float(g["tint_w"])
	if tw > 0.0 and outline == 0:
		var tint: Color = g["tint"]
		col = Color(lerpf(base.r, tint.r, tw), lerpf(base.g, tint.g, tw), lerpf(base.b, tint.b, tw), base.a * lerpf(1.0, tint.a, tw))
	col.a *= float(g["opacity"])
	if col.a <= 0.0:
		return
	ci.draw_set_transform_matrix(g["xf"])
	var radius: float = float(g.get("blur", 0.0))
	if radius < 0.25:
		draw_glyph(ts, rid, g, outline, col, g["at"])
		return
	var taps: PackedVector2Array = blur_taps(radius)
	var share: Color = Color(col.r, col.g, col.b, clampf(col.a * 3.0 / float(taps.size()), 0.0, 1.0))
	for tap: Vector2 in taps:
		draw_glyph(ts, rid, g, outline, share, g["at"] + tap)


static func draw_glyph(ts: TextServer, rid: RID, g: Dictionary, outline: int, col: Color, at: Vector2) -> void:
	if outline > 0:
		ts.font_draw_glyph_outline(g["font"], rid, int(g["size"]), outline, at, int(g["index"]), col)
	else:
		ts.font_draw_glyph(g["font"], rid, int(g["size"]), at, int(g["index"]), col)


static func blur_taps(radius: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	var rings: int = clampi(int(ceil(radius / 2.0)), 1, 4)
	for r: int in rings:
		var rr: float = radius * float(r + 1) / float(rings)
		var n: int = 6 + r * 4
		for k: int in n:
			var a: float = TAU * (float(k) + 0.5 * float(r)) / float(n)
			out.append(Vector2(cos(a), sin(a)) * rr)
	return out


## Every drawn glyph's character index, line and box (four corners in layer pixels), as the picture shows them.
static func glyph_quads(props: Dictionary, size: Vector2) -> Array:
	var sink: Array = []
	draw(null, props, size, "text", sink, true)
	return sink

extends RefCounted

const TitleStyle := preload("res://doc/title_style.gd")
const TextAnimators := preload("res://doc/text_animators.gd")
const TextExtras := preload("res://doc/text_extras.gd")

static var draws: int = 0
static var enabled: bool = true


static func active(props: Dictionary) -> bool:
	if not enabled:
		return false
	return TextAnimators.active(props) or TextExtras.active(props) or typing(props)


static func typing(props: Dictionary) -> bool:
	var r: Variant = TextAnimators.plain(props.get("reveal", 1.0))
	return (r is float or r is int) and float(r) < 0.99999


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


static func draw(ci: CanvasItem, props: Dictionary, size: Vector2, part: String, sink: Array = []) -> void:
	if props.is_empty() or size.x < 2.0 or size.y < 2.0:
		return
	var text: String = TextExtras.shown_text(props)
	if bool(props.get("uppercase", false)):
		text = text.to_upper()
	if text.strip_edges().is_empty():
		return
	var reveal: float = clampf(float(props.get("reveal", 1.0)), 0.0, 1.0)
	var shown: int = text.length()
	if reveal < 0.99999:
		shown = int(ceil(float(text.length()) * reveal - 0.0001))
		if shown <= 0:
			return
	var cut: int = shown
	var plain_len: int = text.length()
	var caret: String = String(props.get("cursor", ""))
	if not caret.is_empty() and shown < text.length():
		text = text.substr(0, shown) + caret
		cut = text.length()
	var scale_f: float = size.y / 1080.0
	var font: Font = TitleStyle.font_for(String(props.get("font", "")), bool(props.get("bold", false)), bool(props.get("italic", false)))
	font = TitleStyle.spaced(font, int(round(float(props.get("letter_spacing", 0.0)) * scale_f)))
	var fs: int = maxi(int(round(float(props.get("size", 72.0)) * scale_f)), 4)
	var para: TextParagraph = TextParagraph.new()
	var width_frac: float = clampf(float(props.get("width", 0.9)), 0.05, 1.0)
	var pad: float = float(props.get("box_pad", 12.0)) * scale_f
	para.width = size.x * width_frac - pad * 2.0
	var align: String = String(props.get("align", "center"))
	para.alignment = HORIZONTAL_ALIGNMENT_LEFT if align == "left" else (HORIZONTAL_ALIGNMENT_RIGHT if align == "right" else HORIZONTAL_ALIGNMENT_CENTER)
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	para.add_string(text, font, fs)
	var extra_line: float = float(props.get("line_spacing", 0.0)) * scale_f
	var text_size: Vector2 = para.get_size()
	var lines: int = maxi(para.get_line_count(), 1)
	var block_h: float = text_size.y + extra_line * float(lines - 1)
	var block_w: float = text_size.x
	var valign: String = String(props.get("valign", "center"))
	var x0: float = (size.x - para.width) * 0.5
	if align == "left":
		x0 = size.x * (1.0 - width_frac) * 0.5 + pad
	elif align == "right":
		x0 = size.x - size.x * (1.0 - width_frac) * 0.5 - pad - para.width
	var y0: float = (size.y - block_h) * 0.5
	if valign == "top":
		y0 = size.y * 0.06
	elif valign == "bottom":
		y0 = size.y - block_h - size.y * 0.06
	var on_path: bool = TextExtras.path_on(props)
	if part == "box" or part == "all":
		var box_col: Color = TitleStyle.colour_of(props.get("box_colour", null), Color(0, 0, 0, 0))
		if box_col.a > 0.001 and not on_path:
			var bx: float = x0 + (para.width - block_w) * (0.0 if align == "left" else (1.0 if align == "right" else 0.5)) - pad
			var box := StyleBoxFlat.new()
			box.bg_color = box_col
			box.set_corner_radius_all(int(round(float(props.get("box_radius", 8.0)) * scale_f)))
			box.anti_aliasing = true
			if ci != null:
				ci.draw_style_box(box, Rect2(bx, y0 - pad, block_w + pad * 2.0, block_h + pad * 2.0))
		if part == "box":
			return
	var glyphs_only: bool = part == "glyphs"
	var colour: Color = Color.WHITE if glyphs_only else TitleStyle.colour_of(props.get("colour", null), Color.WHITE)
	var outline: int = int(round(float(props.get("outline", 0.0)) * scale_f))
	var outline_col: Color = Color.WHITE if glyphs_only else TitleStyle.colour_of(props.get("outline_colour", null), Color.BLACK)
	var rid: RID = ci.get_canvas_item() if ci != null else RID()
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
			total_w += para.get_line_width(li)
		var pts: PackedVector2Array = TextExtras.path_points(props, size, para.width)
		var lens: PackedFloat64Array = TextExtras.lengths(pts)
		var plen: float = lens[lens.size() - 1] if lens.size() > 0 else 0.0
		var shape: String = TextExtras.path_shape(props)
		var s0: float = float(TextExtras.get_value(props, "path_start")) / 100.0 * plen
		if shape == "arc" or shape == "wave":
			s0 += (plen - total_w) * 0.5
		path = {"pts": pts, "lens": lens, "s0": s0, "turn": bool(TextExtras.get_value(props, "path_turn")), "done": 0.0}
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
		var lx: float = x0
		if align == "center":
			lx = x0 + (para.width - lw) * 0.5
		elif align == "right":
			lx = x0 + para.width - lw
		var asc: float = para.get_line_ascent(i2)
		var desc: float = para.get_line_descent(i2)
		var pos: Vector2 = Vector2(lx, y + asc)
		var placed: Array[Dictionary] = place_line(ts, line_rid, pos, stop_at, anims, maps, scale_f, asc, desc, path)
		if not path.is_empty():
			path["done"] = float(path["done"]) + lw
		if ci == null:
			for gq: Dictionary in placed:
				if float(gq["opacity"]) <= 0.0:
					continue
				var adv_q: float = float(gq.get("adv", 0.0))
				var at_q: Vector2 = gq["at"]
				var xf_q: Transform2D = gq["xf"]
				var grow: float = float(outline) + float(gq.get("blur", 0.0))
				var box_q: PackedVector2Array = PackedVector2Array([Vector2(at_q.x - grow, at_q.y - asc - grow), Vector2(at_q.x + adv_q + grow, at_q.y - asc - grow), Vector2(at_q.x + adv_q + grow, at_q.y + desc + grow), Vector2(at_q.x - grow, at_q.y + desc + grow)])
				sink.append(xf_q * box_q)
			y += para.get_line_size(i2).y + extra_line
			continue
		if outline > 0:
			for g: Dictionary in placed:
				draw_one(ci, ts, rid, g, outline, outline_col)
		for g2: Dictionary in placed:
			draw_one(ci, ts, rid, g2, 0, colour)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		y += para.get_line_size(i2).y + extra_line


static func place_line(ts: TextServer, line_rid: RID, pos: Vector2, stop_at: int, anims: Array[Dictionary], maps: Array[Dictionary], scale_f: float, asc: float, desc: float, path: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ofs: Vector2 = pos
	var shift: float = 0.0
	for gv: Dictionary in ts.shaped_text_get_glyphs(line_rid):
		var repeat: int = maxi(int(gv.get("repeat", 1)), 1)
		var adv: float = float(gv.get("advance", 0.0))
		var off: Vector2 = gv.get("offset", Vector2.ZERO)
		var font_rid: RID = gv.get("font_rid", RID())
		var start: int = int(gv.get("start", -1))
		for r: int in repeat:
			if stop_at >= 0 and start >= stop_at:
				return out
			if font_rid.is_valid():
				var st: Dictionary = TextAnimators.glyph_state(anims, maps, start)
				shift += float(st["tracking"]) * scale_f
				var at: Vector2 = ofs + off + Vector2(shift, 0.0)
				var pivot: Vector2 = Vector2(ofs.x + shift + adv * 0.5, pos.y - (asc - desc) * 0.5)
				var m: Transform2D = Transform2D.IDENTITY
				var sc: float = float(st["scale"])
				var rot: float = deg_to_rad(float(st["rot"]))
				var sk: float = deg_to_rad(clampf(float(st["skew"]), -80.0, 80.0))
				var moved: Vector2 = TextAnimators.vec(st["pos"]) * scale_f
				if not path.is_empty():
					var d: float = float(path["s0"]) + float(path["done"]) + (ofs.x - pos.x) + shift + adv * 0.5
					var hit: Array = TextExtras.sample(path["pts"], path["lens"], d)
					var on: Transform2D = Transform2D(float(hit[1]) if bool(path["turn"]) else 0.0, hit[0])
					var lp: Vector2 = Vector2(0.0, -(asc - desc) * 0.5)
					var local: Transform2D = Transform2D(rot, Vector2(sc, sc), sk, lp + moved) * Transform2D(0.0, -lp)
					m = on * local
					at = Vector2(-adv * 0.5 + off.x, off.y)
				elif not is_equal_approx(sc, 1.0) or not is_zero_approx(rot) or not moved.is_zero_approx() or not is_zero_approx(sk):
					m = Transform2D(rot, Vector2(sc, sc), sk, pivot + moved) * Transform2D(0.0, -pivot)
				out.append({"font": font_rid, "size": int(gv.get("font_size", 16)), "index": int(gv.get("index", 0)), "at": at, "xf": m, "opacity": float(st["opacity"]), "tint": st["tint"], "tint_w": float(st["tint_w"]), "blur": float(st["blur"]) * scale_f, "adv": adv})
			ofs.x += adv
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

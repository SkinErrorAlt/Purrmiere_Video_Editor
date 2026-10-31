extends RefCounted

const ELLIPSIS := "…"
const DRAWS_META := "pm_text_draws"
const CACHE_MAX := 4096
const ELIDE := 0
const ELIDE_OWN_TIP := 1
const WHOLE := 2

static var recording: bool = false
static var _elided: Dictionary = {}
static var _any_kept: bool = false
static var _ignore_kept: bool = false


static func pad() -> float:
	return float(Tk.px(Tk.sz("pad")))


static func chip_pad() -> float:
	return float(Tk.px(4.0))


static func width_of(font: Font, text: String, fs: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


static func elide(font: Font, text: String, room: float, fs: int) -> String:
	if text.is_empty() or room < 1.0:
		return ""
	if width_of(font, text, fs) <= room + 0.01:
		return text
	var whole: float = floor(room)
	var key: String = "%d|%d|%d|%s" % [font.get_instance_id(), fs, int(whole), text]
	if _elided.has(key):
		return _elided[key]
	var lo: int = 0
	var hi: int = text.length()
	while lo < hi:
		var mid: int = (lo + hi + 1) / 2
		if width_of(font, text.substr(0, mid).strip_edges(false, true) + ELLIPSIS, fs) <= whole:
			lo = mid
		else:
			hi = mid - 1
	var out: String = text.substr(0, lo).strip_edges(false, true) + ELLIPSIS if lo > 0 else ""
	if _elided.size() >= CACHE_MAX:
		_elided.clear()
	_elided[key] = out
	return out


static func size_for(font: Font, fs: int, height: float) -> int:
	var s: int = fs
	while s > 6 and font.get_height(s) > height:
		s -= 1
	return s


static func baseline_in(font: Font, fs: int, box: Rect2) -> float:
	return box.position.y + (box.size.y - font.get_height(fs)) * 0.5 + font.get_ascent(fs)


static func draw(ci: CanvasItem, font: Font, box: Rect2, text: String, fs: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, inset: float = -1.0, base_y: float = NAN, fit: int = ELIDE) -> Rect2:
	var p: float = inset if inset >= 0.0 else pad()
	return draw_in(ci, font, Rect2(box.position.x + p, box.position.y, box.size.x - p * 2.0, box.size.y), text, fs, col, align, base_y, fit, box, p)


static func draw_in(ci: CanvasItem, font: Font, area: Rect2, text: String, fs: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, base_y: float = NAN, fit: int = ELIDE, frame: Rect2 = Rect2(), frame_pad: float = -1.0) -> Rect2:
	if ci == null or font == null or text.is_empty():
		return Rect2()
	var box: Rect2 = frame if frame.has_area() else area
	var p: float = frame_pad if frame_pad >= 0.0 else (pad() if frame.has_area() else 0.0)
	var y: float = base_y if not is_nan(base_y) else baseline_in(font, fs, area)
	var room_rect: Rect2 = _clear_of_kept(ci, area, y - font.get_ascent(fs), y + font.get_descent(fs))
	var room: float = room_rect.size.x
	if room < 1.0:
		return Rect2()
	var need: float = width_of(font, text, fs)
	var shown: String = text
	var drawn: float = need
	var elided: bool = need > room + 0.01
	if elided:
		if fit == WHOLE:
			return Rect2()
		shown = elide(font, text, room, fs)
		if shown.is_empty():
			return Rect2()
		drawn = width_of(font, shown, fs)
	var x: float = room_rect.position.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x += (room - drawn) * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x += room - drawn
	ci.draw_string(font, Vector2(x, y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	var r := Rect2(x, y - font.get_ascent(fs), drawn, font.get_height(fs))
	if elided and fit == ELIDE:
		_note_tip(ci, r, text)
	if recording:
		var tipped: bool = fit != ELIDE or can_tip(ci)
		_draws(ci).items.append({"text": text, "rect": r, "need": need, "box": box, "pad": p, "elided": elided, "tip": tipped, "vcheck": true})
	return r


static func draw_at(ci: CanvasItem, font: Font, pos: Vector2, text: String, fs: int, col: Color, width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Rect2:
	if ci == null or font == null or text.is_empty():
		return Rect2()
	var w: float = width if width > 0.0 else width_of(font, text, fs) + 1.0
	var area := Rect2(pos.x, pos.y - font.get_ascent(fs), w, font.get_height(fs))
	return draw_in(ci, font, area, text, fs, col, align, pos.y)


static func draw_lines_at(ci: CanvasItem, font: Font, pos: Vector2, text: String, fs: int, col: Color, width: float, max_lines: int) -> Rect2:
	if font == null:
		return Rect2()
	var box := Rect2(pos.x, pos.y - font.get_ascent(fs), width, font.get_height(fs) * float(maxi(max_lines, 1)) + 0.5)
	return draw_lines(ci, font, box, text, fs, col, max_lines, 0.0)


static func draw_lines(ci: CanvasItem, font: Font, box: Rect2, text: String, fs: int, col: Color, max_lines: int = -1, inset: float = -1.0) -> Rect2:
	if ci == null or font == null or text.strip_edges().is_empty():
		return Rect2()
	var p: float = inset if inset >= 0.0 else pad()
	var room: Vector2 = box.size - Vector2(p, p) * 2.0
	if room.x < 1.0 or room.y < font.get_height(fs) - 0.5:
		return Rect2()
	var line_h: float = font.get_height(fs)
	var fit_lines: int = int(floor((room.y + 0.01) / line_h))
	var limit: int = fit_lines if max_lines < 0 else mini(fit_lines, max_lines)
	var para := TextParagraph.new()
	para.add_string(text, font, fs)
	para.width = room.x
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	para.max_lines_visible = limit
	para.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var total: int = para.get_line_count()
	var shown: int = mini(total, limit)
	para.draw(ci.get_canvas_item(), box.position + Vector2(p, p), col)
	var widest: float = 0.0
	for i: int in shown:
		widest = maxf(widest, para.get_line_width(i))
	var r := Rect2(box.position + Vector2(p, p), Vector2(minf(widest, room.x), line_h * float(shown)))
	var elided: bool = total > shown
	if elided:
		_note_tip(ci, r, text)
	if recording:
		_draws(ci).items.append({"text": text, "rect": r, "need": widest, "box": box, "pad": p, "elided": elided, "tip": can_tip(ci), "vcheck": true})
	return r


static func keep_out(ci: CanvasItem, rects: Array[Rect2]) -> void:
	if ci == null or rects.is_empty():
		return
	_any_kept = true
	_draws(ci).kept.append_array(rects)


static func cover(ci: CanvasItem, r: Rect2) -> void:
	if ci == null or not ci.has_meta(DRAWS_META):
		return
	var d: Variant = ci.get_meta(DRAWS_META)
	if not (d is _Draws):
		return
	var dr: _Draws = d
	for i: int in range(dr.items.size() - 1, -1, -1):
		if ((dr.items[i] as Dictionary)["rect"] as Rect2).intersects(r):
			dr.items.remove_at(i)
	for j: int in range(dr.tip_rects.size() - 1, -1, -1):
		if dr.tip_rects[j].intersects(r):
			dr.tip_rects.remove_at(j)
			dr.tip_texts.remove_at(j)


static func draw_on_kept(ci: CanvasItem, font: Font, area: Rect2, text: String, fs: int, col: Color) -> Rect2:
	_ignore_kept = true
	var r: Rect2 = draw_in(ci, font, area, text, fs, col)
	_ignore_kept = false
	return r


static func _clear_of_kept(ci: CanvasItem, area: Rect2, top: float, bottom: float) -> Rect2:
	if _ignore_kept or not _any_kept or not ci.has_meta(DRAWS_META):
		return area
	var d: Variant = ci.get_meta(DRAWS_META)
	if not (d is _Draws) or (d as _Draws).kept.is_empty():
		return area
	var gap: float = float(Tk.px(Tk.sz("gap")))
	var x0: float = area.position.x
	var x1: float = area.end.x
	for pass_i: int in 2:
		for k: Rect2 in (d as _Draws).kept:
			if minf(k.end.y, bottom) - maxf(k.position.y, top) <= 1.0:
				continue
			if k.end.x <= x0 or k.position.x >= x1:
				continue
			if k.position.x <= x0 + 0.5:
				x0 = k.end.x + gap
			else:
				x1 = minf(x1, k.position.x - gap)
	return Rect2(x0, area.position.y, maxf(x1 - x0, 0.0), area.size.y)


static func report(ci: CanvasItem) -> Array:
	if ci == null or not ci.has_meta(DRAWS_META):
		return []
	var d: Variant = ci.get_meta(DRAWS_META)
	if d is _Draws:
		return (d as _Draws).items.duplicate()
	return []


static func tip_at(ci: CanvasItem, local: Vector2) -> String:
	if ci == null or not ci.has_meta(DRAWS_META):
		return ""
	var d: Variant = ci.get_meta(DRAWS_META)
	if d is _Draws:
		return (d as _Draws).tip_at(local)
	return ""


static func can_tip(ci: CanvasItem) -> bool:
	return ci is Control and (ci as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE


static func _draws(ci: CanvasItem) -> _Draws:
	if ci.has_meta(DRAWS_META):
		var d: Variant = ci.get_meta(DRAWS_META)
		if d is _Draws:
			return d
	var fresh := _Draws.new()
	ci.set_meta(DRAWS_META, fresh)
	ci.draw.connect(fresh.clear)
	return fresh


static func _note_tip(ci: CanvasItem, r: Rect2, full: String) -> void:
	if not can_tip(ci):
		return
	var d: _Draws = _draws(ci)
	d.tip_rects.append(r)
	d.tip_texts.append(full)
	if not d.hooked:
		d.hooked = true
		var ctl: Control = ci
		ctl.gui_input.connect(d.on_input.bind(ctl))
		ctl.mouse_exited.connect(d.leave.bind(ctl))


class _Draws:
	extends RefCounted

	var items: Array = []
	var kept: Array[Rect2] = []
	var tip_rects: Array[Rect2] = []
	var tip_texts: PackedStringArray = PackedStringArray()
	var hooked: bool = false
	var showing: String = ""
	var own_tip: String = ""

	func clear() -> void:
		items.clear()
		kept.clear()
		tip_rects.clear()
		tip_texts.clear()

	func tip_at(local: Vector2) -> String:
		for i: int in tip_rects.size():
			if tip_rects[i].grow(2.0).has_point(local):
				return tip_texts[i]
		return ""

	func on_input(event: InputEvent, ctl: Control) -> void:
		if not (event is InputEventMouseMotion):
			return
		_show(tip_at((event as InputEventMouseMotion).position), ctl)

	func leave(ctl: Control) -> void:
		_show("", ctl)

	func _show(text: String, ctl: Control) -> void:
		if text == showing or not is_instance_valid(ctl) or not ctl.is_inside_tree():
			return
		var PmTip: GDScript = load("res://ui/kit/pm_tip.gd")
		if showing.is_empty():
			own_tip = String(PmTip.call("text_of", ctl))
		showing = text
		var tip: Control = PmTip.call("instance_for", ctl)
		PmTip.call("attach", ctl, own_tip if text.is_empty() else text)
		if tip == null:
			return
		if text.is_empty():
			if tip.get("target") == ctl:
				tip.call("disarm", ctl)
			if not own_tip.is_empty() and ctl.get_global_rect().has_point(ctl.get_global_mouse_position()):
				tip.call("arm", ctl)
		else:
			tip.call("arm", ctl)

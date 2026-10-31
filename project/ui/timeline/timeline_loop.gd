extends RefCounted

const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const LoopAudio := preload("res://engine/loop_audio.gd")
const SEAM_W := 2.0
const SEAM_GAP := 5.0
const EDGE_GAP := 2.0
const MARK := 4.0
const PIECES_MAX := 96
const HUES: PackedFloat32Array = [0.86, 0.98, 0.1, 0.48]
const PIECE := "~loop"

static var seams_drawn: int = 0
static var seams_skipped: int = 0


static func media_length(d: RefCounted, c: Clip, item: MediaItem) -> float:
	if c == null or item == null:
		return 0.0
	if d != null and d.has_method("media_duration"):
		return float(d.call("media_duration", item))
	return item.duration


static func seam_xs(c: Clip, media_dur: float, clip_x0: float, pps: float, lo_x: float, hi_x: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	if c == null or not c.loop or pps <= 0.0:
		return out
	var seams: PackedFloat64Array = c.loop_seams(media_dur)
	if seams.is_empty():
		return out
	var gap: float = maxf(SEAM_GAP, float(Tk.px(SEAM_GAP)))
	var clip_x1: float = clip_x0 + c.duration * pps
	var last_x: float = clip_x0
	var first: int = seams.bsearch(maxf((lo_x - clip_x0) / pps - gap / pps, 0.0))
	for i: int in range(first, seams.size()):
		var x: float = clip_x0 + float(seams[i]) * pps
		if x > hi_x + gap:
			break
		if x - last_x < gap or clip_x1 - x < EDGE_GAP or x - clip_x0 < EDGE_GAP:
			seams_skipped += 1
			continue
		last_x = x
		if x >= lo_x - SEAM_W and x <= hi_x + SEAM_W:
			out.append(x)
	return out


static func seam_colour(i: int) -> Color:
	return Color.from_hsv(HUES[i % HUES.size()], 0.85, 1.0)


static func draw_seams(ci: CanvasItem, c: Clip, media_dur: float, r: Rect2, clip_x0: float, pps: float) -> int:
	var xs: PackedFloat32Array = seam_xs(c, media_dur, clip_x0, pps, r.position.x, r.end.x)
	if xs.is_empty():
		return 0
	var top: float = r.position.y
	var h: float = r.size.y
	var w: float = maxf(SEAM_W, float(Tk.px(SEAM_W)))
	var mark: float = maxf(MARK, float(Tk.px(MARK)))
	var outline: Color = Color(Tk.c["bg_app"], 0.7)
	var bands: int = HUES.size() - 1
	for x: float in xs:
		ci.draw_rect(Rect2(x - w * 0.5 - 1.0, top, w + 2.0, h), outline, true)
		for b: int in bands:
			var y0: float = top + h * float(b) / float(bands)
			var y1: float = top + h * float(b + 1) / float(bands)
			var pts: PackedVector2Array = PackedVector2Array([Vector2(x - w * 0.5, y0), Vector2(x + w * 0.5, y0), Vector2(x + w * 0.5, y1), Vector2(x - w * 0.5, y1)])
			var cols: PackedColorArray = PackedColorArray([seam_colour(b), seam_colour(b), seam_colour(b + 1), seam_colour(b + 1)])
			ci.draw_polygon(pts, cols)
		var tri: PackedVector2Array = PackedVector2Array([Vector2(x - mark - 1.0, top), Vector2(x + mark + 1.0, top), Vector2(x, top + mark + 2.0)])
		ci.draw_colored_polygon(tri, outline)
		var inner: PackedVector2Array = PackedVector2Array([Vector2(x - mark, top), Vector2(x + mark, top), Vector2(x, top + mark)])
		ci.draw_colored_polygon(inner, Tk.c["text_bright"])
	seams_drawn += xs.size()
	return xs.size()


static func pieces(c: Clip, media_dur: float) -> Array[Dictionary]:
	if c == null or not c.loop:
		return []
	var win: Vector2 = c.loop_window(media_dur)
	if c.loop_seams_in(win).is_empty():
		return []
	return LoopAudio.pieces_in(c, win, c.loop_forward())


static func piece_clip(c: Clip, piece: Dictionary) -> Clip:
	var p: Clip = LoopAudio.piece_clip(c, piece)
	p.id = c.id + PIECE + str(int(piece["k"]))
	return p


static func source_spans(c: Clip, media_dur: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var list: Array[Dictionary] = pieces(c, media_dur)
	if list.is_empty():
		return span_of(c)
	for piece: Dictionary in list:
		out.append_array(span_of(piece_clip(c, piece)))
	return out


static func span_of(c: Clip) -> PackedFloat64Array:
	var sp: float = c.static_speed()
	if sp != 0.0:
		return PackedFloat64Array([c.start, c.start + c.duration, c.in_offset, c.in_offset + c.duration * sp])
	return PackedFloat64Array([c.start, c.start + c.duration, c.source_time(c.start), c.source_time(c.start + c.duration)])


static func draw_wave_pieces(canvas: Control, c: Clip, item: MediaItem, r: Rect2, clip_x0: float, lane_h: float, lane_y: float, media_dur: float) -> bool:
	var list: Array[Dictionary] = pieces(c, media_dur)
	if list.is_empty():
		return false
	var pps: float = float(canvas.get("pps"))
	var drawn: int = 0
	for piece: Dictionary in list:
		var x0: float = clip_x0 + float(piece["a"]) * pps
		var x1: float = clip_x0 + float(piece["b"]) * pps
		var a: float = maxf(x0, r.position.x)
		var b: float = minf(x1, r.end.x)
		if b <= a:
			continue
		if drawn >= PIECES_MAX:
			break
		canvas.call("_draw_wave", piece_clip(c, piece), item, Rect2(a, r.position.y, b - a, r.size.y), x0, lane_h, lane_y)
		drawn += 1
	return true

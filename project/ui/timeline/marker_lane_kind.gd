extends "res://host/interfaces/i_track_kind.gd"

const Fold := preload("res://ui/timeline/timeline_fold.gd")
const Marker := preload("res://doc/marker.gd")
const Follow := preload("res://doc/marker_follow.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const Shapes := preload("res://ui/timeline/marker_shapes.gd")
const ID := "marker_lane"
const LANE_H := 20.0
const PENNANT_Y := 2.0
const BAR_H := 3.0
const LABEL_MIN_W := 26.0
const LABEL_GAP := 7.0
const CROWD_PX := 2.0
const DENSE_PX := 8.0
const TAG_KIND := "tag"
const TAG_FILL := 0.3
const DENSE_CROWD_PX := 3.0

static var drawn: int = 0
static var cull: bool = true


func id() -> String:
	return ID


func label() -> String:
	return "Marker lane"


func icon() -> String:
	return "marker"


func default_height() -> float:
	return LANE_H


func header_buttons() -> PackedStringArray:
	return PackedStringArray(["target", "eye", "lock"])


func item_kind() -> String:
	return "marker"


static func lane_h() -> float:
	return float(Tk.px(LANE_H))


static func layer_colour(layer: Dictionary) -> Color:
	if layer.is_empty():
		return Tk.c["text"]
	var rgb: String = String(layer.get("rgb", ""))
	if not rgb.is_empty():
		return Color.from_string(rgb, Tk.c["text"])
	var idx: int = int(layer.get("colour", -1))
	return Tk.label_colour(idx) if idx >= 0 else Tk.c["text"]


static func colour_of(m: Marker, layer: Dictionary) -> Color:
	if m.has_free_colour():
		return m.free_colour()
	if m.colour >= 0:
		return Tk.label_colour(m.colour)
	return layer_colour(layer)


static func pennant(ci: CanvasItem, x: float, y: float, col: Color, has_comment: bool, picked: bool) -> void:
	var pts := PackedVector2Array([Vector2(x - 5.0, y), Vector2(x + 5.0, y), Vector2(x + 5.0, y + 6.0), Vector2(x, y + 11.0), Vector2(x - 5.0, y + 6.0)])
	ci.draw_colored_polygon(pts, col)
	if picked:
		pts.append(pts[0])
		ci.draw_polyline(pts, Tk.c["accent"], 1.0)
	if has_comment:
		ci.draw_circle(Vector2(x, y + 4.0), 1.5, Tk.c["bg_app"])


static func is_dense(count: int, width: float) -> bool:
	return cull and float(count) * DENSE_PX > width


static func tick(ci: CanvasItem, x: float, y: float, col: Color) -> void:
	ci.draw_rect(Rect2(x - 1.0, y, 2.0, 10.0), col, true)


func paint_lane(canvas: CanvasItem, rect: Rect2, ctx: Dictionary) -> void:
	paint(canvas, rect, ctx)


static func paint(canvas: CanvasItem, rect: Rect2, ctx: Dictionary) -> void:
	var layer: Dictionary = ctx.get("layer", {})
	var hidden: bool = bool(layer.get("hidden", false))
	var lane_col: Color = layer_colour(layer)
	canvas.draw_rect(rect, Tk.c["bg_ruler"], true)
	canvas.draw_rect(Rect2(rect.position.x, rect.end.y - 1.0, rect.size.x, 1.0), Tk.c["lane_line"], true)
	if bool(layer.get("locked", false)):
		canvas.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.18), true)
	if hidden:
		return
	var list: Array = ctx.get("markers", [])
	var seq: RefCounted = ctx.get("seq", null)
	var header_w: float = float(ctx.get("header_w", 0.0))
	var pps: float = float(ctx.get("pps", 1.0))
	var scroll_x: float = float(ctx.get("scroll_x", 0.0))
	var fold: Dictionary = ctx.get("fold", {})
	var x_max: float = rect.end.x
	var runs: Array = ctx.get("runs", [])
	if not runs.is_empty():
		var x_of: Callable = func(t: float) -> float: return Fold.x_of(fold, t, header_w, pps, scroll_x)
		for run: Dictionary in runs:
			var first: Marker = run["first"]
			var rcol: Color = lane_col if first.colour < 0 and first.rgb.is_empty() else colour_of(first, layer)
			Shapes.draw_run(canvas, rect.position.y, rect.size.y, x_of, run, rcol, header_w, x_max, ctx.get("font", null), int(ctx.get("fs", 10)))
	if list.is_empty():
		return
	var picked: PackedStringArray = ctx.get("picked", PackedStringArray())
	var font: Font = ctx.get("font", null)
	var fs: int = int(ctx.get("fs", 10))
	var y: float = rect.position.y
	var h: float = rect.size.y
	var last_px: float = -INF
	var dense: bool = is_dense(list.size(), x_max - header_w)
	var crowd: float = DENSE_CROWD_PX if dense else CROWD_PX
	for i: int in list.size():
		var m: Marker = list[i]
		var mt: float = Follow.resolved_time(seq, m) if m.follows() else m.time
		var mx: float = Fold.x_of(fold, mt, header_w, pps, scroll_x)
		var mw: float = maxf(m.duration, 0.0) * pps if fold.is_empty() else Fold.px_between(fold, mt, mt + maxf(m.duration, 0.0), pps)
		if cull and (mx + mw < header_w - 6.0 or mx > x_max + 6.0):
			continue
		var on: bool = not picked.is_empty() and picked.has(m.id)
		if cull and mw <= 0.0 and not on and mx - last_px < crowd:
			continue
		if mw <= 0.0:
			last_px = mx
		var col: Color = lane_col if m.colour < 0 and m.rgb.is_empty() else colour_of(m, layer)
		if dense and not on:
			if mw > 1.0:
				canvas.draw_rect(Rect2(maxf(mx, header_w), y + h - BAR_H - 1.0, minf(mx + mw, x_max) - maxf(mx, header_w), BAR_H), col, true)
			tick(canvas, mx, y + PENNANT_Y, col)
			drawn += 1
			continue
		if mw > 0.0:
			var bx0: float = maxf(mx, header_w)
			var bx1: float = minf(mx + mw, x_max)
			if bx1 > bx0:
				canvas.draw_rect(Rect2(bx0, y + h - BAR_H - 1.0, bx1 - bx0, BAR_H), col, true)
				if m.kind == TAG_KIND:
					canvas.draw_rect(Rect2(bx0, y + 1.0, bx1 - bx0, h - 2.0), Color(col, TAG_FILL), true)
				else:
					canvas.draw_rect(Rect2(bx0, y + PENNANT_Y + 4.0, bx1 - bx0, h - PENNANT_Y - BAR_H - 6.0), Color(col, 0.16), true)
			if on:
				canvas.draw_rect(Rect2(mx - 1.0, y + 2.0, 2.0, h - 4.0), col, true)
				canvas.draw_rect(Rect2(mx + mw - 1.0, y + 2.0, 2.0, h - 4.0), col, true)
		if m.follows():
			canvas.draw_circle(Vector2(mx, y + h - 6.0), 1.5, col)
		Shapes.draw(canvas, m, mx, y + PENNANT_Y, col, not m.comment.is_empty(), on)
		drawn += 1
		if font != null and not m.label.is_empty():
			var room_end: float = x_max
			if i + 1 < list.size():
				room_end = Fold.x_of(fold, Follow.resolved_time(seq, list[i + 1]), header_w, pps, scroll_x) - LABEL_GAP
			room_end = minf(maxf(room_end, mx + mw), x_max)
			var lx: float = maxf(mx + LABEL_GAP, header_w + 2.0)
			if room_end - lx >= LABEL_MIN_W:
				PmText.draw_in(canvas, font, Rect2(lx, y, room_end - lx, h), m.label, fs, lane_col.lerp(Tk.c["text"], 0.5), HORIZONTAL_ALIGNMENT_LEFT, y + h * 0.5 + font.get_ascent(fs) * 0.5 - 1.0, PmText.ELIDE, Rect2(lx, y, room_end - lx, h))


static func header_rects(r: Rect2, layer: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ic: float = minf(float(Tk.px(13.0)), r.size.y - 4.0)
	var y: float = r.position.y + (r.size.y - ic) * 0.5
	var x: float = r.end.x - ic - 6.0
	var is_locked: bool = bool(layer.get("locked", false))
	var is_hidden: bool = bool(layer.get("hidden", false))
	var is_target: bool = bool(layer.get("target", false))
	out.append({"id": "lock", "rect": Rect2(x, y, ic, ic), "icon": "lock" if is_locked else "unlock", "on": is_locked, "tip": "Unlock this marker lane" if is_locked else "Lock this marker lane"})
	x -= ic + 5.0
	out.append({"id": "eye", "rect": Rect2(x, y, ic, ic), "icon": "eye_off" if is_hidden else "eye", "on": not is_hidden, "tip": "Show this marker lane" if is_hidden else "Hide this marker lane, view only"})
	x -= ic + 5.0
	out.append({"id": "target", "rect": Rect2(x, y, ic, ic), "icon": "target" if is_target else "target_off", "on": is_target, "tip": "New markers go on this lane" if not is_target else "New markers go on the ruler again"})
	return out


static func header_button_at(r: Rect2, layer: Dictionary, pos: Vector2) -> String:
	for b: Dictionary in header_rects(r, layer):
		if (b["rect"] as Rect2).grow(2.0).has_point(pos):
			return String(b["id"])
	return ""

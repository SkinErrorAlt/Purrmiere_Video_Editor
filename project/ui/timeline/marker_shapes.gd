extends RefCounted

const Marker := preload("res://doc/marker.gd")
const MarkerKinds := preload("res://doc/marker_kinds.gd")
const Icons := preload("res://ui/kit/icons.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const HALF := 5.0
const TALL := 11.0
const ICON_PX := 9.0
const RUN_H := 3.0
const RUN_TICK := 6.0
const RUN_FILL := 0.12

static var drawn_shapes: Dictionary = {}
static var shape_of_kind: Dictionary = _table("shape")
static var icon_of_kind: Dictionary = _table("icon")
static var count_shapes: bool = false


static func _table(field: String) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in MarkerKinds.REGISTRY.keys():
		out[k] = String((MarkerKinds.REGISTRY[k] as Dictionary)[field])
	return out


static func outline(shape: String, x: float, y: float) -> PackedVector2Array:
	if shape == "pennant":
		return PackedVector2Array([Vector2(x - HALF, y), Vector2(x + HALF, y), Vector2(x + HALF, y + 6.0), Vector2(x, y + TALL), Vector2(x - HALF, y + 6.0)])
	if shape == "flag":
		return PackedVector2Array([Vector2(x - 1.0, y), Vector2(x + 8.0, y), Vector2(x + 5.5, y + 3.5), Vector2(x + 8.0, y + 7.0), Vector2(x + 1.0, y + 7.0), Vector2(x + 1.0, y + TALL), Vector2(x - 1.0, y + TALL)])
	if shape == "bar":
		return PackedVector2Array([Vector2(x - 1.5, y), Vector2(x + 1.5, y), Vector2(x + 1.5, y + TALL), Vector2(x - 1.5, y + TALL)])
	if shape == "diamond":
		return PackedVector2Array([Vector2(x, y), Vector2(x + HALF + 0.5, y + TALL * 0.5), Vector2(x, y + TALL), Vector2(x - HALF - 0.5, y + TALL * 0.5)])
	if shape == "dot":
		var pts: PackedVector2Array = PackedVector2Array()
		var c: Vector2 = Vector2(x, y + TALL * 0.5)
		for i: int in 12:
			var a: float = TAU * float(i) / 12.0
			pts.append(c + Vector2(cos(a), sin(a)) * 4.5)
		return pts
	return PackedVector2Array([Vector2(x - HALF, y), Vector2(x + HALF, y), Vector2(x + HALF, y + 6.0), Vector2(x, y + TALL), Vector2(x - HALF, y + 6.0)])


static func draw(ci: CanvasItem, m: Marker, x: float, y: float, col: Color, has_comment: bool, picked: bool) -> void:
	var shape: String = m.shape if not m.shape.is_empty() else String(shape_of_kind.get(m.kind, "pennant"))
	if count_shapes:
		drawn_shapes[shape] = int(drawn_shapes.get(shape, 0)) + 1
	var pts: PackedVector2Array = outline(shape, x, y)
	ci.draw_colored_polygon(pts, col)
	if picked:
		var ring: PackedVector2Array = pts.duplicate()
		ring.append(pts[0])
		ci.draw_polyline(ring, Tk.c["accent"], 1.0)
	var icon: String = m.icon if not m.icon.is_empty() else String(icon_of_kind.get(m.kind, ""))
	if not icon.is_empty() and icon != "none" and Icons.has(icon):
		Icons.draw(ci, icon, Rect2(x + HALF + 2.0, y + 1.0, ICON_PX, ICON_PX), col)
	elif has_comment and shape != "bar":
		ci.draw_circle(Vector2(x, y + 4.0), 1.5, Tk.c["bg_app"])


static func draw_run(ci: CanvasItem, y: float, h: float, x_of: Callable, run: Dictionary, col: Color, clip_lo: float, clip_hi: float, font: Font, fs: int) -> void:
	var x0: float = float(x_of.call(float(run["from"])))
	var x1: float = float(x_of.call(float(run["to"])))
	if x1 < clip_lo or x0 > clip_hi:
		return
	var a: float = maxf(x0, clip_lo)
	var b: float = minf(x1, clip_hi)
	if b - a < 1.0:
		return
	ci.draw_rect(Rect2(a, y + 1.0, b - a, h - 2.0), Color(col, RUN_FILL), true)
	for part: Vector2 in run["parts"] as PackedVector2Array:
		var pa: float = maxf(float(x_of.call(part.x)), clip_lo)
		var pb: float = minf(float(x_of.call(part.y)), clip_hi)
		if pb - pa >= 1.0:
			ci.draw_rect(Rect2(pa, y + h - RUN_H - 1.0, pb - pa, RUN_H), Color(col, 0.75), true)
	ci.draw_rect(Rect2(a, y, b - a, 1.5), col, true)
	if x0 >= clip_lo:
		ci.draw_rect(Rect2(x0, y, 1.5, RUN_TICK), col, true)
	if x1 <= clip_hi:
		ci.draw_rect(Rect2(x1 - 1.5, y, 1.5, RUN_TICK), col, true)
	if font == null:
		return
	var text: String = String(run["name"]) + "  " + str(int(run["count"]))
	var tw: float = PmText.width_of(font, text, fs)
	var room: float = b - a - 8.0
	if room < 24.0:
		return
	var lx: float = b - minf(tw, room) - 4.0
	PmText.draw_in(ci, font, Rect2(lx, y, minf(tw, room) + 2.0, h), text, fs, col.lerp(Tk.c["text"], 0.35), HORIZONTAL_ALIGNMENT_LEFT, y + h * 0.5 + font.get_ascent(fs) * 0.5 - 1.0, PmText.ELIDE, Rect2(lx, y, minf(tw, room) + 2.0, h))

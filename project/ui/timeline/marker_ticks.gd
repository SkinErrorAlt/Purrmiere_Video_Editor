extends RefCounted

const Marker := preload("res://doc/marker.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Kind := preload("res://ui/timeline/marker_lane_kind.gd")
const TILE_TICK_W := 2.0
const TILE_TICK_H := 6.0
const TILE_CROWD_PX := 3.0
const STRIP_CROWD_PX := 2.0

static var tile_ticks: int = 0
static var strip_marks: int = 0


static func draw_tile(ci: CanvasItem, pic: Rect2, item: MediaItem, length: float) -> void:
	if item == null or item.markers.is_empty() or length <= 0.0 or pic.size.x < 8.0:
		return
	var last: float = -INF
	var y: float = pic.position.y + 2.0
	for m: Marker in item.markers:
		var x: float = pic.position.x + clampf(m.time / length, 0.0, 1.0) * (pic.size.x - TILE_TICK_W)
		if x - last < TILE_CROWD_PX:
			continue
		last = x
		var col: Color = Kind.colour_of(m, {})
		ci.draw_rect(Rect2(x - 1.0, y - 1.0, TILE_TICK_W + 2.0, TILE_TICK_H + 2.0), Color(Tk.c["bg_app"], 0.7), true)
		ci.draw_rect(Rect2(x, y, TILE_TICK_W, TILE_TICK_H), col, true)
		tile_ticks += 1


static func draw_strip(ci: CanvasItem, r: Rect2, item: MediaItem, length: float, moving_id: String = "", moving_t: float = 0.0) -> void:
	if item == null or item.markers.is_empty() or length <= 0.0:
		return
	var last: float = -INF
	for m: Marker in item.markers:
		var t: float = moving_t if m.id == moving_id else m.time
		var x: float = r.position.x + t / length * r.size.x
		if x < r.position.x - 6.0 or x > r.end.x + 6.0:
			continue
		var w: float = maxf(m.duration, 0.0) / length * r.size.x
		if w <= 0.0 and x - last < STRIP_CROWD_PX:
			continue
		if w <= 0.0:
			last = x
		var col: Color = Kind.colour_of(m, {})
		if w > 0.0:
			ci.draw_rect(Rect2(x, r.end.y - 4.0, minf(w, r.end.x - x), 3.0), col, true)
		Kind.pennant(ci, x, r.position.y + 1.0, col, not m.comment.is_empty(), false)
		strip_marks += 1

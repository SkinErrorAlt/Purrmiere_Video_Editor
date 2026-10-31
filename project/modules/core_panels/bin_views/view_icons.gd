extends RefCounted

const GRID := 24.0
const STROKE := 1.6
const PATHS: Dictionary = {
	"board": [["r", 3, 4, 8, 6], ["r", 13, 9, 8, 6], ["r", 4, 15, 7, 5], ["p", [11, 7, 14, 7, 16, 9]]],
	"strips": [["r", 3, 4, 18, 6], ["l", 9, 4, 9, 10], ["l", 15, 4, 15, 10], ["p", [3, 17, 5, 17, 6.5, 14, 8, 19, 9.5, 15, 11, 18, 12.5, 16.5, 21, 16.5]]],
	"colours": [["fr", 4, 4, 4, 4], ["r", 10, 4, 4, 4], ["fr", 16, 4, 4, 4], ["r", 4, 10, 4, 4], ["fr", 10, 10, 4, 4], ["r", 16, 10, 4, 4], ["fr", 4, 16, 4, 4], ["r", 10, 16, 4, 4], ["fr", 16, 16, 4, 4]],
	"recorded": [["c", 7.5, 8, 4.5], ["p", [7.5, 5.5, 7.5, 8, 9.3, 9.2]], ["l", 3, 20, 21, 20], ["r", 13, 6, 8, 3], ["r", 11, 13, 7, 3]],
	"used": [["r", 4, 4, 16, 10], ["r", 4, 17, 16, 3], ["fr", 4, 17, 5, 3], ["fr", 12, 17, 4, 3]],
	"views": [["r", 4, 4, 7, 7], ["l", 13, 5.5, 20, 5.5], ["l", 13, 9.5, 18, 9.5], ["fr", 4, 13, 7, 7], ["r", 13, 13, 7, 7]],
}


static func has(name: String) -> bool:
	return PATHS.has(name)


static func draw(ci: CanvasItem, name: String, rect: Rect2, tint: Color, bold: float = 1.0) -> void:
	var side: float = minf(rect.size.x, rect.size.y)
	if side <= 0.0 or not PATHS.has(name):
		return
	var k: float = side / GRID
	var origin: Vector2 = rect.position + (rect.size - Vector2(side, side)) * 0.5
	var w: float = maxf(1.0, STROKE * k * bold)
	for op: Array in PATHS[name]:
		_op(ci, op, origin, k, w, tint)


static func _op(ci: CanvasItem, op: Array, origin: Vector2, k: float, w: float, tint: Color) -> void:
	var kind: String = op[0]
	if kind == "l":
		ci.draw_line(origin + Vector2(float(op[1]), float(op[2])) * k, origin + Vector2(float(op[3]), float(op[4])) * k, tint, w, true)
	elif kind == "p":
		var pts: PackedVector2Array = _pts(op[1], origin, k)
		if pts.size() >= 2:
			ci.draw_polyline(pts, tint, w, true)
	elif kind == "o":
		var loop: PackedVector2Array = _pts(op[1], origin, k)
		if loop.size() >= 2:
			loop.append(loop[0])
			ci.draw_polyline(loop, tint, w, true)
	elif kind == "r":
		ci.draw_rect(Rect2(origin + Vector2(float(op[1]), float(op[2])) * k, Vector2(float(op[3]), float(op[4])) * k), tint, false, w)
	elif kind == "fr":
		ci.draw_rect(Rect2(origin + Vector2(float(op[1]), float(op[2])) * k, Vector2(float(op[3]), float(op[4])) * k), tint, true)
	elif kind == "c":
		ci.draw_arc(origin + Vector2(float(op[1]), float(op[2])) * k, float(op[3]) * k, 0.0, TAU, 32, tint, w, true)


static func _pts(raw: Array, origin: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var i: int = 0
	while i + 1 < raw.size():
		out.append(origin + Vector2(float(raw[i]), float(raw[i + 1])) * k)
		i += 2
	return out

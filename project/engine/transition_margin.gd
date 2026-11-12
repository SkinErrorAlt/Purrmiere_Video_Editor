extends Control

var frame_px: Vector2 = Vector2.ZERO
var margin_px: Vector2 = Vector2.ZERO


func _init() -> void:
	name = "Margin"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO


func set_area(frame: Vector2i, margin: Vector2i) -> void:
	if Vector2(frame) == frame_px and Vector2(margin) == margin_px:
		return
	frame_px = Vector2(frame)
	margin_px = Vector2(margin)
	queue_redraw()


static func strips(frame: Vector2, margin: Vector2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if frame.x <= 0.0 or frame.y <= 0.0:
		return out
	if margin.y > 0.0:
		out.append(Rect2(-margin.x, -margin.y, frame.x + margin.x * 2.0, margin.y))
		out.append(Rect2(-margin.x, frame.y, frame.x + margin.x * 2.0, margin.y))
	if margin.x > 0.0:
		out.append(Rect2(-margin.x, 0.0, margin.x, frame.y))
		out.append(Rect2(frame.x, 0.0, margin.x, frame.y))
	return out


func _draw() -> void:
	for r: Rect2 in strips(frame_px, margin_px):
		var pts: PackedVector2Array = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		var uvs: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			uvs.append(p / frame_px)
		draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs)

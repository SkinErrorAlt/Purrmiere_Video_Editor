extends RefCounted

const MaskShape := preload("res://doc/mask_shape.gd")
const KEY := "path_mask_live"
const ROUND_STEPS := 96


static func live(props: Dictionary) -> bool:
	var v: Variant = props.get(KEY, false)
	if v is Dictionary:
		var d: Dictionary = v
		v = d.get("v", d.get("base", false))
	return v is bool and bool(v)


static func points(m: Dictionary, t: float, dur: float, fps: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	if MaskShape.is_box(m):
		var r: Rect2 = MaskShape.box_at(m, t, dur, fps)
		if str(m.get("kind", "")) == "ellipse":
			for i: int in ROUND_STEPS:
				var a: float = -PI * 0.5 + TAU * float(i) / float(ROUND_STEPS)
				pts.append(r.get_center() + Vector2(cos(a) * r.size.x * 0.5, sin(a) * r.size.y * 0.5))
		else:
			pts = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	else:
		pts = MaskShape.points_at(m, t, dur, fps)
	return pts


static func flat(pts: PackedVector2Array, closed: bool = true) -> Array:
	var out: Array = []
	for p: Vector2 in pts:
		out.append(p.x)
		out.append(p.y)
	if closed and pts.size() > 2:
		out.append(pts[0].x)
		out.append(pts[0].y)
	return out


static func path_at(masks: Array, t: float, dur: float, fps: float) -> Array:
	if masks.is_empty() or not (masks[0] is Dictionary):
		return []
	var pts: PackedVector2Array = points(masks[0], t, dur, fps)
	if pts.size() < 2:
		return []
	return flat(pts, true)


static func follow(out: Dictionary, masks: Array, t: float, dur: float, fps: float) -> void:
	if not live(out):
		return
	var f: Array = path_at(masks, t, dur, fps)
	if f.size() >= 4:
		out["path_points"] = f
		out["path_shape"] = "points"

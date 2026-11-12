extends RefCounted

const PairLayout := preload("res://engine/pair_layout.gd")
const PairCrop := preload("res://engine/pair_crop.gd")
const FrameCanvas := preload("res://engine/frame_canvas.gd")
const REGION_MAX := 8
const PLACE_KEY := "canvas_picture"
const FULL_BOX := Vector4(0.0, 0.0, 1.0, 1.0)
const MISS := Vector2(-1000.0, -1000.0)

static var plant_off: bool = false


static func region(box: Rect2, source: Rect2, turn_inv: Transform2D) -> Dictionary:
	return {"box": Vector4(box.position.x, box.position.y, box.size.x, box.size.y), "src": Vector4(source.position.x, source.position.y, source.size.x, source.size.y), "ta": Vector4(turn_inv.x.x, turn_inv.y.x, turn_inv.origin.x, 0.0), "tb": Vector4(turn_inv.x.y, turn_inv.y.y, turn_inv.origin.y, 0.0)}


static func pair_regions(boxes: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Dictionary in boxes:
		if out.size() >= REGION_MAX:
			break
		var box: Rect2 = b["box"]
		var inv: Transform2D = PairCrop.turned(b, PairLayout.pivot_of(b)).affine_inverse() if b.has("turn") else Transform2D.IDENTITY
		out.append(region(box, b["source"], inv))
	return out


static func frame_regions(src: Vector2i, canvas: Vector2i, size: float = 1.0, at: Vector2 = Vector2(0.5, 0.5)) -> Array[Dictionary]:
	var bx: Vector4 = FrameCanvas.box_of(src, canvas)
	var sz: Vector2 = Vector2(bx.z, bx.w) * maxf(size, 0.01)
	var out: Array[Dictionary] = [region(Rect2(at - sz * 0.5, sz), Rect2(0.0, 0.0, 1.0, 1.0), Transform2D.IDENTITY)]
	return out


static func plan(state_src: Dictionary, now_canvas: bool, now_room: bool, room_box: Vector4, room_outer: bool, regions: Array[Dictionary], size_now: Vector2) -> Dictionary:
	var out: Dictionary = {"room": FULL_BOX, "room_outer": room_outer, "regions": [] as Array[Dictionary], "size": size_now}
	if state_src.is_empty() or plant_off:
		return out
	if now_room and not bool(state_src.get("room", false)):
		out["room"] = room_box
	if now_canvas and not bool(state_src.get("canvas", false)):
		out["regions"] = regions
	out["size"] = state_src.get("size", size_now)
	return out


static func from_room(uv: Vector2, room: Vector4) -> Vector2:
	return (uv - Vector2(room.x, room.y)) / Vector2(maxf(room.z, 0.000001), maxf(room.w, 0.000001))


static func from_regions(uv: Vector2, regions: Array[Dictionary]) -> Vector2:
	if regions.is_empty():
		return uv
	for r: Dictionary in regions:
		var ta: Vector4 = r["ta"]
		var tb: Vector4 = r["tb"]
		var at: Vector2 = Vector2(ta.x * uv.x + ta.y * uv.y + ta.z, tb.x * uv.x + tb.y * uv.y + tb.z)
		var box: Vector4 = r["box"]
		var l: Vector2 = (at - Vector2(box.x, box.y)) / Vector2(maxf(box.z, 0.000001), maxf(box.w, 0.000001))
		if l.x >= 0.0 and l.y >= 0.0 and l.x <= 1.0 and l.y <= 1.0:
			var src: Vector4 = r["src"]
			return Vector2(src.x, src.y) + l * Vector2(src.z, src.w)
	return MISS


static func source_uv(uv: Vector2, p: Dictionary) -> Vector2:
	var regions: Array[Dictionary] = p.get("regions", [] as Array[Dictionary])
	if bool(p.get("room_outer", true)):
		return from_regions(from_room(uv, p["room"]), regions)
	var q: Vector2 = from_regions(uv, regions)
	return q if q == MISS else from_room(q, p["room"])


static func fill(pass_node: Object, p: Dictionary) -> void:
	var regions: Array[Dictionary] = p.get("regions", [] as Array[Dictionary])
	var boxes: PackedVector4Array = PackedVector4Array()
	var srcs: PackedVector4Array = PackedVector4Array()
	var tas: PackedVector4Array = PackedVector4Array()
	var tbs: PackedVector4Array = PackedVector4Array()
	for i: int in REGION_MAX:
		var r: Dictionary = regions[i] if i < regions.size() else region(Rect2(), Rect2(), Transform2D.IDENTITY)
		boxes.append(r["box"])
		srcs.append(r["src"])
		tas.append(r["ta"])
		tbs.append(r["tb"])
	pass_node.call("set_param", "depth_room", p.get("room", FULL_BOX))
	pass_node.call("set_param", "depth_room_outer", bool(p.get("room_outer", true)))
	pass_node.call("set_param", "depth_regions", mini(regions.size(), REGION_MAX))
	pass_node.call("set_param", "depth_box", boxes)
	pass_node.call("set_param", "depth_src", srcs)
	pass_node.call("set_param", "depth_ta", tas)
	pass_node.call("set_param", "depth_tb", tbs)
	pass_node.call("set_param", "depth_size", Vector2(p.get("size", Vector2.ZERO)))

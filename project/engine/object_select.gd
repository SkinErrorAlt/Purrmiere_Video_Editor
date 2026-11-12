extends RefCounted

const Models := preload("res://engine/obj_models.gd")

static var _open_id: String = ""
static var _side: int = 0
static var _image_size: int = 0
static var _last_error: String = ""

const RETRY_BELOW := 0.35


static func available() -> bool:
	var status: Dictionary = status_of()
	return bool(status.get("built", false)) and bool(status.get("ok", false))


static func status_of() -> Dictionary:
	var bridge: Node = _bridge()
	if bridge == null:
		return {"built": false, "ok": false, "gpu": false, "error": "the engine is not loaded", "search": []}
	return bridge.obj_status()


static func last_error() -> String:
	return _last_error


static func open_id() -> String:
	return _open_id


static func mask_side() -> int:
	return _side


static func wanted_id() -> String:
	if Models.installed(Models.BEST):
		return Models.BEST
	return Models.FAST


static func ensure(model_id: String = "") -> Dictionary:
	var out: Dictionary = {"ok": false, "error": "", "model": "", "mask_side": 0, "image_size": 0, "gpu": false}
	var bridge: Node = _bridge()
	if bridge == null:
		out["error"] = "the engine is not loaded"
		_last_error = String(out["error"])
		return out
	var want: String = model_id if model_id != "" else wanted_id()
	if _open_id == want and _side > 0:
		out["ok"] = true
		out["model"] = _open_id
		out["mask_side"] = _side
		out["image_size"] = _image_size
		out["gpu"] = bool(status_of().get("gpu", false))
		return out
	var man: Dictionary = Models.read_manifest(want)
	if not bool(man.get("ok", false)):
		out["error"] = String(man.get("error", "the model is not ready"))
		_last_error = String(out["error"])
		return out
	var spec: Dictionary = man.duplicate(true)
	spec["id"] = want
	var opened: Dictionary = bridge.obj_open(spec)
	if not bool(opened.get("ok", false)):
		out["error"] = String(opened.get("error", "the model would not open"))
		_last_error = String(out["error"])
		return out
	_open_id = want
	_side = int(opened.get("mask_side", 0))
	_image_size = int(opened.get("image_size", 0))
	_last_error = ""
	out["ok"] = true
	out["model"] = _open_id
	out["mask_side"] = _side
	out["image_size"] = _image_size
	out["gpu"] = bool(opened.get("gpu", false))
	return out


static func pick(frame: Image, points: Array, labels: Array, box: Rect2, frame_index: int = 0) -> Dictionary:
	var out: Dictionary = _blank()
	var bridge: Node = _bridge()
	if bridge == null:
		out["error"] = "the engine is not loaded"
		return out
	var ready: Dictionary = ensure()
	if not bool(ready.get("ok", false)):
		out["error"] = String(ready.get("error", ""))
		return out
	var spec: Dictionary = {"points": points, "labels": labels, "box": box, "frame": frame_index}
	var first: Dictionary = _finish(bridge.obj_pick(frame, spec))
	return _retry_middle(bridge, frame, points, labels, box, frame_index, first)


static func follow(frame: Image, frame_index: int, reverse: bool, frame_count: int) -> Dictionary:
	var out: Dictionary = _blank()
	var bridge: Node = _bridge()
	if bridge == null:
		out["error"] = "the engine is not loaded"
		return out
	if _open_id == "":
		out["error"] = "nothing has been selected yet"
		return out
	var spec: Dictionary = {"frame": frame_index, "reverse": reverse, "frame_count": frame_count}
	var got: Dictionary = bridge.obj_follow(frame, spec)
	return _finish(got)


static func reset() -> void:
	var bridge: Node = _bridge()
	if bridge != null:
		bridge.obj_reset()


static func close() -> void:
	var bridge: Node = _bridge()
	if bridge != null:
		bridge.obj_close()
	_open_id = ""
	_side = 0
	_image_size = 0


static func matte_image(result: Dictionary) -> Image:
	var side: int = int(result.get("side", 0))
	var bytes: PackedByteArray = result.get("matte", PackedByteArray())
	if side <= 0 or bytes.size() < side * side:
		return null
	return Image.create_from_data(side, side, false, Image.FORMAT_R8, bytes)


static func middle_positive(points: Array, labels: Array) -> int:
	var wanted: Array[int] = []
	for i: int in points.size():
		if i < labels.size() and int(labels[i]) == 1:
			wanted.append(i)
	if wanted.size() < 2:
		return -1
	return wanted[wanted.size() / 2]


static func _retry_middle(bridge: Node, frame: Image, points: Array, labels: Array, box: Rect2, frame_index: int, first: Dictionary) -> Dictionary:
	if not bool(first.get("ok", false)) or float(first.get("iou", 0.0)) >= RETRY_BELOW:
		return first
	var mid: int = middle_positive(points, labels)
	if mid < 0:
		return first
	var spec: Dictionary = {"points": [points[mid]], "labels": [1], "box": box, "frame": frame_index}
	var second: Dictionary = _finish(bridge.obj_pick(frame, spec))
	if bool(second.get("ok", false)) and float(second.get("iou", 0.0)) > float(first.get("iou", 0.0)):
		return second
	return first


static func _finish(got: Dictionary) -> Dictionary:
	var out: Dictionary = _blank()
	for key in out.keys():
		if got.has(key):
			out[key] = got[key]
	if not bool(out["ok"]):
		_last_error = String(out["error"])
	return out


static func _blank() -> Dictionary:
	return {"ok": false, "error": "", "side": 0, "matte": PackedByteArray(), "score": 0.0, "iou": 0.0, "head": 0, "empty": true, "bounds": Rect2(0, 0, 0, 0), "area": 0.0, "ms": 0.0, "ms_enc": 0.0, "ms_attn": 0.0, "ms_dec": 0.0, "ms_mem": 0.0, "attn_fixed": false, "candidates": []}


static func _bridge() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null:
		return null
	var tree: SceneTree = loop as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("PurrBridge")

extends RefCounted

const KEY := "canvas"
const FRAME := "frame"
const PLACE_KEY := "canvas_picture"
const FULL_BOX := Vector4(0.0, 0.0, 1.0, 1.0)

static var ids: Dictionary = {}


static func note(def: Dictionary, raw: Dictionary) -> void:
	if String(raw.get(KEY, "")) != FRAME:
		return
	def[KEY] = FRAME
	ids[String(def.get("id", ""))] = true
	if raw.get(PLACE_KEY, null) is Dictionary:
		def[PLACE_KEY] = (raw[PLACE_KEY] as Dictionary).duplicate(true)


static func is_canvas_def(def: Dictionary) -> bool:
	return String(def.get(KEY, "")) == FRAME


static func wants(effects: Array) -> bool:
	if ids.is_empty():
		return false
	for e: Variant in effects:
		if e is Dictionary and ids.has(String((e as Dictionary).get("id", ""))) and bool((e as Dictionary).get("enabled", true)):
			return true
	return false


static func box_of(src: Vector2i, canvas: Vector2i) -> Vector4:
	if canvas.x <= 0 or canvas.y <= 0 or src.x <= 0 or src.y <= 0:
		return FULL_BOX
	var sz: Vector2 = Vector2(float(src.x) / float(canvas.x), float(src.y) / float(canvas.y))
	var at: Vector2 = (Vector2.ONE - sz) * 0.5
	return Vector4(at.x, at.y, sz.x, sz.y)


static func fill(p: Object, first: bool, src: Vector2i, canvas: Vector2i) -> void:
	p.call("set_param", "source_box", box_of(src, canvas) if first else FULL_BOX)
	p.call("set_param", "canvas_px", Vector2(canvas))

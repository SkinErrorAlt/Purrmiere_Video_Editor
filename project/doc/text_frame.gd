extends RefCounted

const KEY := "frame"
const POINT := "point"
const BOX := "box"
const BOX_W := "box_w"
const BOX_H := "box_h"
const MIN_BOX := 8.0
const REF_H := 1080.0


static func mode(props: Dictionary) -> String:
	var m: String = String(_plain(props.get(KEY, "")))
	return m if m == POINT or m == BOX else ""


static func framed(props: Dictionary) -> bool:
	return not mode(props).is_empty()


static func is_point(props: Dictionary) -> bool:
	return mode(props) == POINT


static func is_box(props: Dictionary) -> bool:
	return mode(props) == BOX


static func scale_of(size: Vector2) -> float:
	return size.y / REF_H


static func box_size(props: Dictionary, size: Vector2) -> Vector2:
	var k: float = scale_of(size)
	var w: float = maxf(float(_plain(props.get(BOX_W, 800.0))), MIN_BOX)
	var h: float = maxf(float(_plain(props.get(BOX_H, 300.0))), MIN_BOX)
	return Vector2(w, h) * k


static func legacy_width(props: Dictionary, size: Vector2) -> float:
	var scale_f: float = scale_of(size)
	var width_frac: float = clampf(float(props.get("width", 0.9)), 0.05, 1.0)
	var pad: float = float(props.get("box_pad", 12.0)) * scale_f
	return size.x * width_frac - pad * 2.0


static func wrap_width(props: Dictionary, size: Vector2) -> float:
	var m: String = mode(props)
	if m == POINT:
		return -1.0
	if m == BOX:
		return box_size(props, size).x
	return legacy_width(props, size)


static func path_width(props: Dictionary, size: Vector2) -> float:
	if is_point(props):
		return legacy_width(props, size)
	return wrap_width(props, size)


static func place(props: Dictionary, size: Vector2, wrap: float, block_w: float, block_h: float, first_asc: float) -> Dictionary:
	var align: String = String(props.get("align", "center"))
	var valign: String = String(props.get("valign", "center"))
	var centre: Vector2 = size * 0.5
	var m: String = mode(props)
	if m == POINT:
		var x0: float = centre.x
		if is_justify(align):
			align = "left"
		if align == "center":
			x0 = centre.x - block_w * 0.5
		elif align == "right":
			x0 = centre.x - block_w
		return {"x0": x0, "w": block_w, "y0": centre.y - first_asc, "clip_h": -1.0}
	if m == BOX:
		var bs: Vector2 = box_size(props, size)
		var y0: float = centre.y
		if valign == "center":
			y0 = centre.y + (bs.y - block_h) * 0.5
		elif valign == "bottom":
			y0 = centre.y + bs.y - block_h
		return {"x0": centre.x, "w": bs.x, "y0": y0, "clip_h": bs.y, "top": centre.y}
	var scale_f: float = scale_of(size)
	var width_frac: float = clampf(float(props.get("width", 0.9)), 0.05, 1.0)
	var pad: float = float(props.get("box_pad", 12.0)) * scale_f
	var lx: float = (size.x - wrap) * 0.5
	if align == "left":
		lx = size.x * (1.0 - width_frac) * 0.5 + pad
	elif align == "right":
		lx = size.x - size.x * (1.0 - width_frac) * 0.5 - pad - wrap
	var ly: float = (size.y - block_h) * 0.5
	if valign == "top":
		ly = size.y * 0.06
	elif valign == "bottom":
		ly = size.y - block_h - size.y * 0.06
	return {"x0": lx, "w": wrap, "y0": ly, "clip_h": -1.0}


static func is_justify(align: String) -> bool:
	return align.begins_with("justify")


static func line_x(props: Dictionary, x0: float, area_w: float, line_w: float, last: bool = true) -> float:
	return line_x_as(String(props.get("align", "center")), props, x0, area_w, line_w, last)


static func line_x_as(align: String, props: Dictionary, x0: float, area_w: float, line_w: float, last: bool = true) -> float:
	if is_justify(align):
		if is_point(props) or not last or align == "justify" or align == "justify_all":
			return x0
		align = "center" if align == "justify_center" else "right"
	if align == "center":
		return x0 + (area_w - line_w) * 0.5
	if align == "right":
		return x0 + area_w - line_w
	return x0


static func line_shown(placed: Dictionary, line_top: float, line_h: float) -> bool:
	var clip_h: float = float(placed.get("clip_h", -1.0))
	if clip_h < 0.0:
		return true
	var top: float = float(placed.get("top", 0.0))
	return line_top + line_h <= top + clip_h + 0.5


static func box_rect(props: Dictionary, size: Vector2) -> Rect2:
	if not is_box(props):
		return Rect2()
	return Rect2(size * 0.5, box_size(props, size))


static func _plain(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("v"):
			return _plain(d["v"])
		if d.has("base"):
			return _plain(d["base"])
		return null
	return v

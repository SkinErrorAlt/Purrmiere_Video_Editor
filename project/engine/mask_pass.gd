extends Node

const AnimProp := preload("res://doc/anim_prop.gd")
const EffectPass := preload("res://engine/effect_pass.gd")
const MaskShape := preload("res://doc/mask_shape.gd")
const ObjectMask := preload("res://doc/object_mask.gd")
const ObjectMatte := preload("res://engine/object_matte.gd")
const FEATHER_SHADER := "res://engine/mask_feather.gdshader"
const COMBINE_SHADER := "res://engine/mask_combine.gdshader"
const PLATE_SHADER := "res://engine/object_plate.gdshader"
const PICTURE_SHADER := "res://engine/mask_picture.gdshader"
const PICTURE_CACHE_MAX := 24
const ELLIPSE_SEGMENTS := 64
const MODES: Dictionary = {"add": 0, "subtract": 1, "intersect": 2}

static var _feather_shader: Shader = null
static var _combine_shader: Shader = null
static var _plate_shader: Shader = null
static var _picture_shader: Shader = null
static var _pictures: Dictionary = {}

var units: Dictionary = {}
var combine_chain: Array[EffectPass] = []
var alpha_ids: PackedStringArray = PackedStringArray()
var size_px: Vector2i = Vector2i(2, 2)
var quality_scale: float = 1.0
var _signature: String = ""


static func feather_shader() -> Shader:
	if _feather_shader == null:
		_feather_shader = load(FEATHER_SHADER)
	return _feather_shader


static func plate_shader() -> Shader:
	if _plate_shader == null:
		_plate_shader = load(PLATE_SHADER)
	return _plate_shader


static func picture_shader() -> Shader:
	if _picture_shader == null:
		_picture_shader = load(PICTURE_SHADER)
	return _picture_shader


## The picture a picture mask uses, loaded once and kept while the file is unchanged. Null when it cannot be read.
static func picture_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var stamp: int = 0
	if not path.begins_with("res://"):
		if not FileAccess.file_exists(path):
			return null
		stamp = int(FileAccess.get_modified_time(path))
	var key: String = path + "@" + str(stamp)
	if _pictures.has(key):
		return _pictures[key]
	var tex: Texture2D = null
	if path.begins_with("res://"):
		tex = load(path) as Texture2D
	else:
		var img: Image = Image.load_from_file(path)
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	if _pictures.size() >= PICTURE_CACHE_MAX:
		_pictures.clear()
	_pictures[key] = tex
	return tex


static func combine_shader() -> Shader:
	if _combine_shader == null:
		_combine_shader = load(COMBINE_SHADER)
	return _combine_shader


static func mask_id(m: Dictionary, index: int) -> String:
	var id: String = str(m.get("id", ""))
	if id.is_empty():
		return "mask" + str(index)
	return id


static func signature(masks: Array, effect_bound: PackedStringArray, spill_bound: PackedStringArray = PackedStringArray()) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for i: int in masks.size():
		var m: Dictionary = masks[i]
		if not bool(m.get("enabled", true)):
			continue
		var id: String = mask_id(m, i)
		parts.append(id + ":" + ("e" if effect_bound.has(id) else "a") + ("+c" if cuts_alpha(m, effect_bound.has(id), spill_bound.has(id)) else ""))
	return ",".join(parts)


static func cuts_alpha(m: Dictionary, effect_bound: bool, spill_bound: bool = false) -> bool:
	if not effect_bound:
		return true
	if not ObjectMask.is_object(m) or not bool(m.get("cuts", true)):
		return false
	return not spill_bound


func rebuild(masks: Array, effect_bound: PackedStringArray, size: Vector2i, force: bool = false, spill_bound: PackedStringArray = PackedStringArray()) -> bool:
	var sig: String = signature(masks, effect_bound, spill_bound)
	if not force and sig == _signature and size == size_px:
		return false
	_signature = sig
	size_px = size
	_clear()
	alpha_ids = PackedStringArray()
	for i: int in masks.size():
		var m: Dictionary = masks[i]
		if not bool(m.get("enabled", true)):
			continue
		var id: String = mask_id(m, i)
		var unit: Dictionary = _build_unit(id)
		units[id] = unit
		if cuts_alpha(m, effect_bound.has(id), spill_bound.has(id)):
			alpha_ids.append(id)
	var prev: EffectPass = null
	for id: String in alpha_ids:
		var c: EffectPass = _make_pass(combine_shader())
		c.name = "Combine_" + id
		c.set_size_px(size_px)
		var unit: Dictionary = units[id]
		var feather_v: EffectPass = unit["feather_v"]
		c.add_child(feather_v)
		c.set_param("mask_tex", feather_v.output())
		if prev != null:
			c.add_child(prev)
			c.set_input(prev.output())
			c.set_param("first", false)
		else:
			c.set_input(feather_v.output())
			c.set_param("first", true)
		combine_chain.append(c)
		prev = c
	return true


func _clear() -> void:
	for c: EffectPass in combine_chain:
		_free_tree(c)
	combine_chain = []
	for id: Variant in units.keys():
		var u: Dictionary = units[id]
		_free_tree(u["feather_v"])
	units = {}


static func _free_tree(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	var p: Node = n.get_parent()
	if p != null:
		p.remove_child(n)
	n.queue_free()


func _make_pass(sh: Shader) -> EffectPass:
	var p: EffectPass = EffectPass.new()
	var m := ShaderMaterial.new()
	m.shader = sh
	var types: Dictionary = {}
	for u: Dictionary in sh.get_shader_uniform_list(true):
		types[String(u.get("name", ""))] = int(u.get("type", TYPE_NIL))
	p.setup(m, types)
	return p


func _build_unit(id: String) -> Dictionary:
	var raster := SubViewport.new()
	raster.name = "Raster_" + id
	raster.transparent_bg = true
	raster.disable_3d = true
	raster.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	raster.size = size_px
	var poly := Polygon2D.new()
	poly.color = Color.WHITE
	poly.antialiased = true
	raster.add_child(poly)
	var plate := TextureRect.new()
	plate.name = "Plate_" + id
	plate.visible = false
	plate.position = Vector2.ZERO
	plate.size = Vector2(size_px)
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var plate_mat := ShaderMaterial.new()
	plate_mat.shader = plate_shader()
	plate.material = plate_mat
	raster.add_child(plate)
	var fh: EffectPass = _make_pass(feather_shader())
	fh.name = "FeatherH_" + id
	fh.set_size_px(size_px)
	fh.add_child(raster)
	fh.set_input(raster.get_texture())
	fh.set_param("direction", Vector2(1.0, 0.0))
	var fv: EffectPass = _make_pass(feather_shader())
	fv.name = "FeatherV_" + id
	fv.set_size_px(size_px)
	fv.add_child(fh)
	fv.set_input(fh.output())
	fv.set_param("direction", Vector2(0.0, 1.0))
	return {"raster": raster, "poly": poly, "plate": plate, "plate_mat": plate_mat, "feather_h": fh, "feather_v": fv}


func unit_root(id: String) -> Node:
	if units.has(id):
		return (units[id] as Dictionary)["feather_v"]
	return null


func mask_texture(id: String) -> Texture2D:
	if units.has(id):
		return ((units[id] as Dictionary)["feather_v"] as EffectPass).output()
	return null


func alpha_root() -> Node:
	if combine_chain.is_empty():
		return null
	return combine_chain[combine_chain.size() - 1]


func alpha_texture() -> Texture2D:
	if combine_chain.is_empty():
		return null
	return combine_chain[combine_chain.size() - 1].output()


func has_alpha_masks() -> bool:
	return not combine_chain.is_empty()


static func _eval_float(m: Dictionary, key: String, default: float, t: float, dur: float, fps: float) -> float:
	var v: Variant = m.get(key, null)
	if v is Dictionary:
		return AnimProp.evaluate_float(v, MaskShape.key_time(m, key, t, dur), dur, fps)
	if v is float or v is int:
		return float(v)
	return default


static func _eval_vec2(m: Dictionary, key: String, default: Vector2, t: float, dur: float, fps: float) -> Vector2:
	var v: Variant = m.get(key, null)
	if v is Dictionary:
		return AnimProp.evaluate_vec2(v, MaskShape.key_time(m, key, t, dur), dur, fps)
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return default


static func _eval_points(m: Dictionary, t: float, dur: float, fps: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var v: Variant = m.get("points", null)
	var arr: Variant = v
	if v is Dictionary:
		arr = AnimProp.evaluate(v, MaskShape.key_time(m, "points", t, dur), dur, fps)
	if arr is Array:
		for e: Variant in arr:
			if e is Array:
				for f: Variant in e:
					out.append(float(f))
			else:
				out.append(float(e))
	return out


static func shape_points(m: Dictionary, t: float, dur: float, fps: float, aspect: float = 1.0, grow: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var kind: String = str(m.get("kind", "polygon"))
	var pts: PackedVector2Array = PackedVector2Array()
	if MaskShape.BOX_KINDS.has(kind):
		var box: Rect2 = MaskShape.box_at(m, t, dur, fps).grow_individual(grow.x, grow.y, grow.x, grow.y)
		if box.size.x <= 0.0 or box.size.y <= 0.0:
			return PackedVector2Array()
		if kind == "rect":
			pts.append(box.position)
			pts.append(Vector2(box.end.x, box.position.y))
			pts.append(box.end)
			pts.append(Vector2(box.position.x, box.end.y))
		else:
			var mid: Vector2 = box.get_center()
			var r: Vector2 = box.size * 0.5
			for i: int in ELLIPSE_SEGMENTS:
				var a: float = TAU * float(i) / float(ELLIPSE_SEGMENTS)
				pts.append(Vector2(mid.x + cos(a) * r.x, mid.y + sin(a) * r.y))
	else:
		var flat: PackedFloat64Array = _eval_points(m, t, dur, fps)
		var n: int = flat.size() / 2
		for i: int in n:
			pts.append(Vector2(flat[i * 2], flat[i * 2 + 1]))
		pts = MaskShape.curve_path(pts, MaskShape.handles_at(m, t, dur, fps))
	if pts.size() < 3:
		return PackedVector2Array()
	var centre: Vector2 = Vector2.ZERO
	for p: Vector2 in pts:
		centre += p
	centre /= float(pts.size())
	var offset: Vector2 = _eval_vec2(m, "offset", Vector2.ZERO, t, dur, fps)
	var scale: Vector2 = _eval_vec2(m, "scale", Vector2.ONE, t, dur, fps)
	var rotation: float = deg_to_rad(_eval_float(m, "rotation", 0.0, t, dur, fps))
	var ax: float = maxf(aspect, 0.0001)
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		var d: Vector2 = (p - centre) * scale
		d.x *= ax
		d = d.rotated(rotation)
		d.x /= ax
		out.append(centre + d + offset)
	var tx: Variant = m.get("track_xf")
	if tx is Transform2D:
		return (tx as Transform2D) * out
	return out


static func offset_polygon(pts: PackedVector2Array, amount: float) -> PackedVector2Array:
	var n: int = pts.size()
	if n < 3 or absf(amount) < 0.0001:
		return pts
	var area: float = 0.0
	for i: int in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	var outward: float = 1.0 if area > 0.0 else -1.0
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in n:
		var prev: Vector2 = pts[(i + n - 1) % n]
		var cur: Vector2 = pts[i]
		var next: Vector2 = pts[(i + 1) % n]
		var e0: Vector2 = (cur - prev).normalized()
		var e1: Vector2 = (next - cur).normalized()
		var n0: Vector2 = Vector2(e0.y, -e0.x) * outward
		var n1: Vector2 = Vector2(e1.y, -e1.x) * outward
		var bis: Vector2 = (n0 + n1)
		if bis.length() < 0.0001:
			bis = n0
		bis = bis.normalized()
		var reach: float = amount / maxf(bis.dot(n0), 0.25)
		out.append(cur + bis * reach)
	return out


static func mode_of(m: Dictionary, t: float, dur: float, fps: float) -> int:
	return int(MODES.get(str(MaskShape.value_at(m, "mode", t, dur, fps)), 0))


static func invert_of(m: Dictionary, t: float, dur: float, fps: float) -> bool:
	var v: Variant = MaskShape.value_at(m, "invert", t, dur, fps)
	if v is bool:
		return v
	if v is float or v is int:
		return float(v) >= 0.5
	return false


func update(masks: Array, t: float, dur: float, fps: float, q_scale: float) -> void:
	quality_scale = q_scale
	var chain_index: int = 0
	var px_size: Vector2 = Vector2(maxf(float(size_px.x), 1.0), maxf(float(size_px.y), 1.0))
	var aspect: float = px_size.x / px_size.y
	for i: int in masks.size():
		var m: Dictionary = masks[i]
		if not bool(m.get("enabled", true)):
			continue
		var id: String = mask_id(m, i)
		if not units.has(id):
			continue
		var unit: Dictionary = units[id]
		var poly: Polygon2D = unit["poly"]
		var plate: TextureRect = unit["plate"]
		var expand: float = _eval_float(m, "expand", 0.0, t, dur, fps) * quality_scale
		if ObjectMask.is_object(m):
			poly.polygon = PackedVector2Array()
			poly.visible = false
			plate.visible = true
			plate.size = px_size
			var frame: int = int(round(t * maxf(fps, 1.0)))
			var tex: Texture2D = ObjectMatte.texture_for(m, frame)
			plate.texture = tex
			var mat: ShaderMaterial = plate.material
			if mat != null:
				var reg: Rect2 = ObjectMask.region_of(m)
				mat.set_shader_parameter("region", Vector4(reg.position.x, reg.position.y, maxf(reg.size.x, 0.0001), maxf(reg.size.y, 0.0001)))
				var matte_side: float = float(tex.get_width()) if tex != null else 128.0
				mat.set_shader_parameter("matte_size", Vector2(matte_side, matte_side))
				mat.set_shader_parameter("edge_contrast", maxf(_eval_float(m, "edge_contrast", 1.6, t, dur, fps), 1.0))
				mat.set_shader_parameter("edge_shift", clampf(_eval_float(m, "edge_shift", 0.0, t, dur, fps), -0.5, 0.5))
			var ofh: EffectPass = unit["feather_h"]
			var ofv: EffectPass = unit["feather_v"]
			var ofeather: float = maxf(_eval_float(m, "feather", 0.0, t, dur, fps), 0.0) * quality_scale
			for fp: EffectPass in [ofh, ofv]:
				fp.set_param("radius", ofeather)
				fp.set_param("expand", expand)
				fp.set_param("tex_size", px_size)
			if alpha_ids.has(id) and chain_index < combine_chain.size():
				var oc: EffectPass = combine_chain[chain_index]
				oc.set_param("mode", mode_of(m, t, dur, fps))
				oc.set_param("opacity", clampf(_eval_float(m, "opacity", 1.0, t, dur, fps), 0.0, 1.0))
				oc.set_param("invert", invert_of(m, t, dur, fps))
				chain_index += 1
			continue
		if MaskShape.is_picture(m):
			_update_picture(unit, m, t, dur, fps, px_size, aspect, expand)
			if alpha_ids.has(id) and chain_index < combine_chain.size():
				var pc: EffectPass = combine_chain[chain_index]
				pc.set_param("mode", mode_of(m, t, dur, fps))
				pc.set_param("opacity", clampf(_eval_float(m, "opacity", 1.0, t, dur, fps), 0.0, 1.0))
				pc.set_param("invert", invert_of(m, t, dur, fps))
				chain_index += 1
			continue
		if plate.material != unit["plate_mat"]:
			plate.material = unit["plate_mat"]
		poly.visible = true
		plate.visible = false
		var box_kind: bool = MaskShape.BOX_KINDS.has(str(m.get("kind", "")))
		var grow: Vector2 = Vector2(expand / px_size.x, expand / px_size.y) if box_kind else Vector2.ZERO
		var pts: PackedVector2Array = shape_points(m, t, dur, fps, aspect, grow)
		var px: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			px.append(Vector2(p.x * px_size.x, p.y * px_size.y))
		if not box_kind:
			px = offset_polygon(px, expand)
		poly.polygon = px
		var feather: float = maxf(_eval_float(m, "feather", 0.0, t, dur, fps), 0.0) * quality_scale
		var fh: EffectPass = unit["feather_h"]
		var fv: EffectPass = unit["feather_v"]
		for fp: EffectPass in [fh, fv]:
			fp.set_param("radius", feather)
			fp.set_param("expand", 0.0)
			fp.set_param("tex_size", px_size)
		if alpha_ids.has(id) and chain_index < combine_chain.size():
			var c: EffectPass = combine_chain[chain_index]
			c.set_param("mode", mode_of(m, t, dur, fps))
			c.set_param("opacity", clampf(_eval_float(m, "opacity", 1.0, t, dur, fps), 0.0, 1.0))
			c.set_param("invert", invert_of(m, t, dur, fps))
			chain_index += 1


func _update_picture(unit: Dictionary, m: Dictionary, t: float, dur: float, fps: float, px_size: Vector2, aspect: float, expand: float) -> void:
	var poly: Polygon2D = unit["poly"]
	var plate: TextureRect = unit["plate"]
	poly.polygon = PackedVector2Array()
	poly.visible = false
	var tex: Texture2D = picture_texture(str(m.get("image", "")))
	plate.visible = tex != null
	plate.size = px_size
	plate.texture = tex
	var mat: ShaderMaterial = unit.get("pic_mat")
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = picture_shader()
		unit["pic_mat"] = mat
	if plate.material != mat:
		plate.material = mat
	var box: Rect2 = MaskShape.box_at(m, t, dur, fps)
	mat.set_shader_parameter("box", Vector4(box.get_center().x, box.get_center().y, maxf(box.size.x, 0.0001), maxf(box.size.y, 0.0001)))
	mat.set_shader_parameter("rotation", deg_to_rad(_eval_float(m, "rotation", 0.0, t, dur, fps)))
	mat.set_shader_parameter("aspect", aspect)
	mat.set_shader_parameter("channel", maxi(MaskShape.PICTURE_CHANNELS.find(str(m.get("channel", "luma"))), 0))
	mat.set_shader_parameter("low", clampf(_eval_float(m, "low", 0.0, t, dur, fps), 0.0, 1.0))
	mat.set_shader_parameter("high", clampf(_eval_float(m, "high", 1.0, t, dur, fps), 0.0, 1.0))
	var feather: float = maxf(_eval_float(m, "feather", 0.0, t, dur, fps), 0.0) * quality_scale
	for fp: EffectPass in [unit["feather_h"], unit["feather_v"]]:
		fp.set_param("radius", feather)
		fp.set_param("expand", expand)
		fp.set_param("tex_size", px_size)

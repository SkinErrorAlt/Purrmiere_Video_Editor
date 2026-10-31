extends Node

const OVER_SHADER := "res://engine/transform.gdshader"
const TransitionRegistry := preload("res://engine/transition_registry.gd")
const Pyramid := preload("res://engine/transition_pyramid.gd")

static var plant_swap: bool = false

var cut_id: String = ""
var out_vp: SubViewport = null
var from_vp: SubViewport = null
var to_vp: SubViewport = null
var rect: ColorRect = null
var backbuffer: BackBufferCopy = null
var quad: TextureRect = null
var quad_mat: ShaderMaterial = null
var mat: ShaderMaterial = null
var shader: Shader = null
var types: Dictionary = {}
var shown_id: String = ""
var fell_back: bool = false
var frame_size: Vector2i = Vector2i.ZERO
var drawn: int = 0
var from_pyr: Node = null
var to_pyr: Node = null
var pyramid_on: bool = false


func _init() -> void:
	name = "Transition"
	out_vp = _make_vp("Out")
	add_child(out_vp)
	from_vp = _make_vp("From")
	out_vp.add_child(from_vp)
	to_vp = _make_vp("To")
	out_vp.add_child(to_vp)
	rect = ColorRect.new()
	rect.name = "Mix"
	rect.color = Color.WHITE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out_vp.add_child(rect)
	backbuffer = BackBufferCopy.new()
	backbuffer.name = "BackBuffer"
	backbuffer.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	add_child(backbuffer)
	quad = TextureRect.new()
	quad.name = "Quad"
	quad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	quad.stretch_mode = TextureRect.STRETCH_SCALE
	quad.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	quad.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quad_mat = ShaderMaterial.new()
	quad_mat.shader = load(OVER_SHADER)
	quad_mat.set_shader_parameter("opacity", 1.0)
	quad_mat.set_shader_parameter("blend", 0)
	quad.material = quad_mat
	quad.texture = out_vp.get_texture()
	add_child(quad)


static func _make_vp(n: String) -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.name = n
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(2, 2)
	return vp


func side(is_outgoing: bool) -> SubViewport:
	return from_vp if is_outgoing != plant_swap else to_vp


func fit(size_px: Vector2i) -> void:
	frame_size = size_px
	for vp: SubViewport in [out_vp, from_vp, to_vp]:
		if vp.size != size_px:
			vp.size = size_px
		if vp.is_inside_tree() and vp.canvas_transform != Transform2D.IDENTITY:
			vp.canvas_transform = Transform2D.IDENTITY
	rect.position = Vector2.ZERO
	rect.size = Vector2(size_px)
	if pyramid_on:
		from_pyr.call("set_source", from_vp.get_texture(), size_px)
		to_pyr.call("set_source", to_vp.get_texture(), size_px)
		_bind_pyramid()
	quad.position = Vector2.ZERO
	quad.size = Vector2(size_px)


func use(info: Dictionary) -> void:
	var sh: Shader = info.get("shader", null)
	fell_back = bool(info.get("fell_back", false))
	shown_id = String(info.get("id", ""))
	if sh == shader and mat != null:
		return
	shader = sh
	types = (info.get("uniforms", {}) as Dictionary).duplicate()
	mat = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("from_tex", from_vp.get_texture())
	mat.set_shader_parameter("to_tex", to_vp.get_texture())
	rect.material = mat
	_bind_pyramid()


func set_pyramid(on: bool) -> void:
	if on == pyramid_on:
		_bind_pyramid()
		return
	pyramid_on = on
	if on:
		from_pyr = Pyramid.new()
		from_pyr.name = "FromPyramid"
		out_vp.add_child(from_pyr)
		to_pyr = Pyramid.new()
		to_pyr.name = "ToPyramid"
		out_vp.add_child(to_pyr)
		_move(from_vp, from_pyr.call("source_holder"))
		_move(to_vp, to_pyr.call("source_holder"))
		from_pyr.call("set_source", from_vp.get_texture(), frame_size)
		to_pyr.call("set_source", to_vp.get_texture(), frame_size)
	else:
		_move(from_vp, out_vp)
		_move(to_vp, out_vp)
		for p: Node in [from_pyr, to_pyr]:
			if p != null and is_instance_valid(p):
				if p.get_parent() != null:
					p.get_parent().remove_child(p)
				p.queue_free()
		from_pyr = null
		to_pyr = null
	_bind_pyramid()


static func _move(n: Node, to: Node) -> void:
	if n.get_parent() == to:
		return
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	to.add_child(n)


func _bind_pyramid() -> void:
	if mat == null:
		return
	if not pyramid_on or Pyramid.plant_unbound:
		mat.set_shader_parameter("tr_pyr_levels", 0)
		return
	mat.set_shader_parameter("tr_from_pyr", from_pyr.call("texture"))
	mat.set_shader_parameter("tr_to_pyr", to_pyr.call("texture"))
	mat.set_shader_parameter("tr_pyr_px", from_pyr.call("size_of_atlas"))
	mat.set_shader_parameter("tr_pyr_levels", Pyramid.LEVELS)


func set_blend(blend: int) -> void:
	quad_mat.set_shader_parameter("blend", blend)
	backbuffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if blend != 0 else BackBufferCopy.COPY_MODE_DISABLED


func apply(progress: float, px_scale: float, cut_seed: float, duration: float, time: float, values: Dictionary) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("progress", progress)
	mat.set_shader_parameter("frame_px", Vector2(frame_size))
	mat.set_shader_parameter("px_scale", px_scale)
	mat.set_shader_parameter("seed", cut_seed)
	mat.set_shader_parameter("duration", duration)
	mat.set_shader_parameter("time", time)
	for k: Variant in values.keys():
		var key: String = String(k)
		if not types.has(key):
			continue
		mat.set_shader_parameter(key, TransitionRegistry.shader_value(values[k], int(types[key])))
	drawn += 1

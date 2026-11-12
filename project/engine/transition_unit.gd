extends Node

const OVER_SHADER := "res://engine/transform.gdshader"
const TransitionRegistry := preload("res://engine/transition_registry.gd")
const Pyramid := preload("res://engine/transition_pyramid.gd")
const TransitionShatter := preload("res://engine/transition_shatter.gd")
const Margin := preload("res://engine/transition_margin.gd")

static var plant_swap: bool = false
static var plant_no_margin: bool = false

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
var engine_name: String = ""
var engine_active: bool = false
var engine_pass: SubViewport = null
var engine_rect: TextureRect = null
var margin_px: Vector2i = Vector2i.ZERO
var margin: Control = null
var margin_mat: ShaderMaterial = null


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
	margin = Margin.new()
	margin.visible = false
	out_vp.add_child(margin)
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


func fit(size_px: Vector2i, margin_wanted: Vector2i = Vector2i.ZERO) -> void:
	frame_size = size_px
	margin_px = margin_wanted
	_layout()


func drawn_margin() -> Vector2i:
	if engine_active or plant_no_margin or frame_size.x <= 0 or frame_size.y <= 0:
		return Vector2i.ZERO
	return Vector2i(maxi(margin_px.x, 0), maxi(margin_px.y, 0))


func _layout() -> void:
	var m: Vector2i = drawn_margin()
	var canvas: Vector2i = frame_size + m * 2
	var xf: Transform2D = Transform2D(0.0, Vector2(m))
	for vp: SubViewport in [out_vp, from_vp, to_vp]:
		if vp.size != canvas:
			vp.size = canvas
		if vp.is_inside_tree() and vp.canvas_transform != xf:
			vp.canvas_transform = xf
	rect.position = Vector2.ZERO
	rect.size = Vector2(frame_size)
	margin.call("set_area", frame_size, m)
	margin.visible = m != Vector2i.ZERO and margin_mat != null
	if pyramid_on:
		from_pyr.call("set_source", from_vp.get_texture(), frame_size, m)
		to_pyr.call("set_source", to_vp.get_texture(), frame_size, m)
		_bind_pyramid()
	quad.position = -Vector2(m)
	quad.size = Vector2(canvas)
	_bind_canvas()
	_size_engine()


func _bind_canvas() -> void:
	var m: Vector2i = drawn_margin()
	var f: Vector2 = Vector2(maxi(frame_size.x, 1), maxi(frame_size.y, 1))
	var canvas: Vector2 = f + Vector2(m) * 2.0
	var lo: Vector2 = -Vector2(m) / f
	_param("tr_canvas_on", m != Vector2i.ZERO)
	_param("tr_canvas_map", Vector4(f.x / canvas.x, f.y / canvas.y, float(m.x) / canvas.x, float(m.y) / canvas.y))
	_param("tr_canvas_lo", lo)
	_param("tr_canvas_hi", Vector2.ONE - lo)
	if margin_mat != null:
		margin_mat.set_shader_parameter("tr_margin_pass", true)


func _param(key: String, value: Variant) -> void:
	if mat != null:
		mat.set_shader_parameter(key, value)
	if margin_mat != null:
		margin_mat.set_shader_parameter(key, value)


func use(info: Dictionary) -> void:
	var eng: String = String(info.get("engine", ""))
	if not eng.is_empty():
		_use_engine(eng)
		return
	_set_engine_active(false)
	var sh: Shader = info.get("shader", null)
	fell_back = bool(info.get("fell_back", false))
	shown_id = String(info.get("id", ""))
	if sh == shader and mat != null:
		return
	shader = sh
	types = (info.get("uniforms", {}) as Dictionary).duplicate()
	mat = ShaderMaterial.new()
	mat.shader = sh
	margin_mat = ShaderMaterial.new()
	margin_mat.shader = sh
	_param("from_tex", from_vp.get_texture())
	_param("to_tex", to_vp.get_texture())
	rect.material = mat
	margin.material = margin_mat
	_layout()
	_bind_pyramid()


func _use_engine(eng: String) -> void:
	fell_back = false
	shown_id = eng
	engine_name = eng
	if engine_pass == null:
		engine_pass = TransitionShatter.make()
		add_child(engine_pass)
		engine_rect = TextureRect.new()
		engine_rect.name = "EngineQuad"
		engine_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		engine_rect.stretch_mode = TextureRect.STRETCH_SCALE
		engine_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		engine_rect.texture = engine_pass.get_texture()
		out_vp.add_child(engine_rect)
	engine_pass.call("set_sources", from_vp.get_texture(), to_vp.get_texture())
	_set_engine_active(true)
	_size_engine()


func _set_engine_active(on: bool) -> void:
	engine_active = on
	if engine_rect != null:
		engine_rect.visible = on
	if engine_pass != null:
		engine_pass.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if rect != null:
		rect.visible = not on
	if margin != null and frame_size != Vector2i.ZERO:
		_layout()


func _size_engine() -> void:
	if engine_pass == null or frame_size.x <= 0 or frame_size.y <= 0:
		return
	if engine_pass.size != frame_size:
		engine_pass.size = frame_size
	if engine_rect != null:
		engine_rect.position = Vector2.ZERO
		engine_rect.size = Vector2(frame_size)


func set_pyramid(on: bool) -> void:
	if engine_active:
		return
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
		from_pyr.call("set_source", from_vp.get_texture(), frame_size, drawn_margin())
		to_pyr.call("set_source", to_vp.get_texture(), frame_size, drawn_margin())
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
		_param("tr_pyr_levels", 0)
		return
	_param("tr_from_pyr", from_pyr.call("texture"))
	_param("tr_to_pyr", to_pyr.call("texture"))
	_param("tr_pyr_px", from_pyr.call("size_of_atlas"))
	_param("tr_pyr_levels", Pyramid.LEVELS)


func set_blend(blend: int) -> void:
	quad_mat.set_shader_parameter("blend", blend)
	backbuffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if blend != 0 else BackBufferCopy.COPY_MODE_DISABLED


func apply(progress: float, px_scale: float, cut_seed: float, duration: float, time: float, values: Dictionary) -> void:
	if engine_active:
		var asp: float = float(frame_size.x) / maxf(float(frame_size.y), 1.0)
		TransitionShatter.drive(engine_pass, progress, asp, values)
		drawn += 1
		return
	if mat == null:
		return
	_param("progress", progress)
	_param("frame_px", Vector2(frame_size))
	_param("px_scale", px_scale)
	_param("seed", cut_seed)
	_param("duration", duration)
	_param("time", time)
	for k: Variant in values.keys():
		var key: String = String(k)
		if not types.has(key):
			continue
		_param(key, TransitionRegistry.shader_value(values[k], int(types[key])))
	drawn += 1

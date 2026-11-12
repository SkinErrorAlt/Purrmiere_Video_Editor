extends Node

const MediaItem := preload("res://doc/media_item.gd")
const KIND_PATTERN := "pattern"
const KIND_IMAGE := "image"
const KIND_NATIVE := "native"
const KIND_NEST := "nest"
const KIND_TITLE := "title"
const KIND_SOLID := "solid"
const KIND_SHAPE := "shape"
const KIND_MISSING := "missing"
const FIRST_FRAME_WAIT_MS := 4000
const TitleStyle := preload("res://doc/title_style.gd")
const TextGlyphs := preload("res://engine/text_glyphs.gd")
const ShapeGeometry := preload("res://doc/shape_geometry.gd")
const TextBlurLayer := preload("res://engine/text_blur_layer.gd")
const PATTERN_W := 160
const PATTERN_H := 90
const YUV_SHADER := "res://engine/yuv.gdshader"
const TITLE_SHADOW_SHADER := "res://engine/title_shadow.gdshader"
const COLORSPACES: Dictionary = {"bt601": 0, "601": 0, "smpte170m": 0, "bt709": 1, "709": 1, "bt2020": 2, "2020": 2, "bt2020nc": 2}
const Proxies := preload("res://engine/proxies.gd")
const FullQuality := preload("res://engine/full_quality.gd")
const PROXY_LANE := "proxy"
const PROXY_SAME_PTS := 0.0005
const PROXY_PREOPEN_SECONDS := 1.5
const HINT_PLAY := 1
const HINT_STEP := 2
const PROXY_COLORSPACE := "bt709"
const MadePicture := preload("res://engine/made_picture.gd")

static var _yuv_shader: Shader = null
static var _missing_tex: ImageTexture = null

var kind: String = KIND_PATTERN
var media: MediaItem = null
var handle: int = -1
var native_size: Vector2i = Vector2i(1280, 720)
var state: String = "none"
var quality_scale: float = 1.0
var _had_exact: bool = false
var _had_frame: bool = false
var _opened_ms: int = 0
var last_time: float = 0.0
var shown_pts: float = -1.0
var has_picture: bool = false
var primed: bool = false
var _viewport: SubViewport = null
var _rect: ColorRect = null
var _material: ShaderMaterial = null
var _label: Control = null
var _box_layer: Control = null
var _blur_layer: Control = null
var _shadow_quad: TextureRect = null
var _shadow_h: SubViewport = null
var _shadow_h_rect: TextureRect = null
var _shadow_src: SubViewport = null
var _shadow_glyphs: Control = null
var _made: Control = null
var _props: Dictionary = {}
var _props_stamp: String = ""
var _image_tex: ImageTexture = null
var _pattern_tex: ImageTexture = null
var _pattern_bytes: PackedByteArray = PackedByteArray()
var _pattern_time: float = -1.0
var _nest_tex: Texture2D = null
var _bridge: Node = null
var use_proxy: bool = false
var proxy_on: bool = false
var proxy_path: String = ""
var proxy_switches: int = 0
var _req_handle: int = -1
var _switch_ms: int = -1000000
var _preopened: String = ""
var _from_original: bool = false
var proxy_waiting: bool = false
var warm_for_play: bool = false
var primes: int = 0
var _req_at: float = -1.0
var _primed_at: float = -1.0
var _primed_h: int = -1
var tap_handle: int = -1
var tap_slot: int = 0
var tap_offsets: PackedFloat64Array = PackedFloat64Array()
var tapping: bool = false
var tap_requests: int = 0


static func yuv_shader() -> Shader:
	if _yuv_shader == null:
		_yuv_shader = load(YUV_SHADER)
	return _yuv_shader


static func missing_texture() -> ImageTexture:
	if _missing_tex == null:
		var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y: int in 64:
			for x: int in 64:
				var on: bool = ((x + y) / 8) % 2 == 0
				img.set_pixel(x, y, Color(0.35, 0.08, 0.08, 1.0) if on else Color(0.12, 0.12, 0.12, 1.0))
		_missing_tex = ImageTexture.create_from_image(img)
	return _missing_tex


static func pattern_bytes(t: float, w: int, h: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(w * h * 4)
	var i: int = 0
	for y: int in h:
		var fy: float = float(y) / float(maxi(h - 1, 1))
		for x: int in w:
			var fx: float = float(x) / float(maxi(w - 1, 1))
			var r: float = fposmod(fx + t * 0.25, 1.0)
			var g: float = fy
			var b: float = 0.5 + 0.5 * sin(fx * 12.0 + t * 3.0) * cos(fy * 9.0)
			out[i] = int(clampf(r, 0.0, 1.0) * 255.0)
			out[i + 1] = int(clampf(g, 0.0, 1.0) * 255.0)
			out[i + 2] = int(clampf(b, 0.0, 1.0) * 255.0)
			out[i + 3] = 255
			i += 4
	return out


func setup(kind_: String, media_: MediaItem, size: Vector2i, handle_: int = -1) -> void:
	kind = kind_
	media = media_
	handle = handle_
	_had_frame = false
	_opened_ms = Time.get_ticks_msec()
	shown_pts = -1.0
	has_picture = false
	primed = false
	proxy_on = false
	proxy_path = ""
	_req_handle = -1
	_switch_ms = -1000000
	_preopened = ""
	if size.x > 0 and size.y > 0:
		native_size = size
	_bridge = _find_bridge()
	_teardown()
	if kind == KIND_NATIVE:
		_build_native()
	elif kind == KIND_TITLE or kind == KIND_SOLID or kind == KIND_SHAPE:
		_build_title()
	elif kind == KIND_IMAGE:
		_load_image()
	elif kind == KIND_PATTERN:
		_pattern_tex = null
	state = "none"


func _find_bridge() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("PurrBridge")
	return null


func _teardown() -> void:
	if _viewport != null:
		if _viewport.get_parent() != null:
			_viewport.get_parent().remove_child(_viewport)
		_viewport.queue_free()
	_viewport = null
	_rect = null
	_material = null
	_label = null
	_box_layer = null
	_blur_layer = null
	_shadow_quad = null
	_shadow_h = null
	_shadow_h_rect = null
	_shadow_src = null
	_shadow_glyphs = null
	_made = null
	_frozen = false


func _viewport_size() -> Vector2i:
	var s: Vector2 = Vector2(native_size) * quality_scale
	return Vector2i(maxi(int(round(s.x)), 2), maxi(int(round(s.y)), 2))


func _build_native() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "Source"
	_viewport.size = _viewport_size()
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color.WHITE
	_rect.size = Vector2(_viewport.size)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = yuv_shader()
	_material.set_shader_parameter("has_frame", false)
	_rect.material = _material
	_viewport.add_child(_rect)
	add_child(_viewport)


func _build_title() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "Source"
	_viewport.size = _viewport_size()
	_viewport.transparent_bg = kind != KIND_SOLID
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if kind == KIND_SOLID:
		_rect = ColorRect.new()
		_rect.color = TitleStyle.colour_of(_props.get("colour", null), Color(0.5, 0.5, 0.5, 1.0))
		_rect.size = Vector2(_viewport.size)
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_viewport.add_child(_rect)
		_made = MadePicture.new()
		_viewport.add_child(_made)
		MadePicture.apply(_viewport, _rect, _made, _props)
	elif kind == KIND_SHAPE:
		var sb: Control = _ShapeBox.new()
		sb.set("props", TitleStyle.merged("shape", {}, _props))
		sb.size = Vector2(_viewport.size)
		_viewport.add_child(sb)
		_label = sb
	else:
		var merged: Dictionary = TitleStyle.merged("title", {}, _props, media.label if media != null else "")
		_box_layer = _TitleBox.new()
		_box_layer.name = "TitleBoxLayer"
		_box_layer.set("part", "box")
		_box_layer.set("props", merged)
		_box_layer.size = Vector2(_viewport.size)
		_viewport.add_child(_box_layer)
		var tb: Control = _TitleBox.new()
		tb.name = "TitleText"
		tb.set("part", "text")
		tb.set_meta(TextGlyphs.TRUE_BLUR, true)
		tb.set("props", merged)
		tb.size = Vector2(_viewport.size)
		_viewport.add_child(tb)
		_label = tb
		_blur_layer = TextBlurLayer.new()
		_blur_layer.name = "TitleBlur"
		_blur_layer.size = Vector2(_viewport.size)
		_viewport.add_child(_blur_layer)
		_blur_layer.set("props", merged)
		_update_shadow(merged)
	add_child(_viewport)
	_props_stamp = TitleStyle.stamp(_props)


func has_soft_shadow() -> bool:
	return _shadow_quad != null


func _build_shadow() -> void:
	var sh: Shader = load(TITLE_SHADOW_SHADER)
	var vs: Vector2i = _viewport.size
	_shadow_src = SubViewport.new()
	_shadow_src.name = "ShadowGlyphs"
	_shadow_src.transparent_bg = true
	_shadow_src.disable_3d = true
	_shadow_src.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_shadow_src.size = vs
	_shadow_glyphs = _TitleBox.new()
	_shadow_glyphs.set("part", "glyphs")
	_shadow_glyphs.size = Vector2(vs)
	_shadow_src.add_child(_shadow_glyphs)
	_shadow_h = SubViewport.new()
	_shadow_h.name = "ShadowBlurH"
	_shadow_h.transparent_bg = true
	_shadow_h.disable_3d = true
	_shadow_h.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_shadow_h.size = vs
	_shadow_h_rect = TextureRect.new()
	_shadow_h_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shadow_h_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_shadow_h_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow_h_rect.size = Vector2(vs)
	var mh := ShaderMaterial.new()
	mh.shader = sh
	mh.set_shader_parameter("direction", Vector2(1.0, 0.0))
	mh.set_shader_parameter("final_pass", false)
	_shadow_h_rect.material = mh
	_shadow_h_rect.add_child(_shadow_src)
	_shadow_h_rect.texture = _shadow_src.get_texture()
	_shadow_h.add_child(_shadow_h_rect)
	_shadow_quad = TextureRect.new()
	_shadow_quad.name = "TitleShadow"
	_shadow_quad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shadow_quad.stretch_mode = TextureRect.STRETCH_SCALE
	_shadow_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow_quad.size = Vector2(vs)
	var mv := ShaderMaterial.new()
	mv.shader = sh
	mv.set_shader_parameter("direction", Vector2(0.0, 1.0))
	mv.set_shader_parameter("final_pass", true)
	_shadow_quad.material = mv
	_shadow_quad.add_child(_shadow_h)
	_shadow_quad.texture = _shadow_h.get_texture()
	_viewport.add_child(_shadow_quad)
	_viewport.move_child(_shadow_quad, _box_layer.get_index() + 1 if _box_layer != null else 0)


func _drop_shadow() -> void:
	if _shadow_quad == null:
		return
	if _shadow_quad.get_parent() != null:
		_shadow_quad.get_parent().remove_child(_shadow_quad)
	_shadow_quad.queue_free()
	_shadow_quad = null
	_shadow_h = null
	_shadow_h_rect = null
	_shadow_src = null
	_shadow_glyphs = null


func _update_shadow(merged: Dictionary) -> void:
	if _viewport == null or kind != KIND_TITLE:
		return
	var on: bool = bool(merged.get("shadow_on", false))
	var col: Color = TitleStyle.colour_of(merged.get("shadow_colour", null), Color(0.0, 0.0, 0.0, 0.6))
	if not on or col.a <= 0.001:
		_drop_shadow()
		return
	if _shadow_quad == null:
		_build_shadow()
	var scale_f: float = float(_viewport.size.y) / 1080.0
	var sigma: float = maxf(float(merged.get("shadow_softness", 8.0)), 0.0) * scale_f / 3.0
	var off: Vector2 = TitleStyle.shadow_offset(float(merged.get("shadow_distance", 6.0)), float(merged.get("shadow_angle", 135.0))) * scale_f
	_shadow_glyphs.set("props", merged)
	_shadow_glyphs.queue_redraw()
	(_shadow_h_rect.material as ShaderMaterial).set_shader_parameter("sigma", sigma)
	var mv: ShaderMaterial = _shadow_quad.material
	mv.set_shader_parameter("sigma", sigma)
	mv.set_shader_parameter("tint", col)
	_shadow_quad.position = off


func _resize_shadow() -> void:
	if _shadow_quad == null or _viewport == null:
		return
	var vs: Vector2i = _viewport.size
	_shadow_src.size = vs
	_shadow_h.size = vs
	_shadow_glyphs.size = Vector2(vs)
	_shadow_h_rect.size = Vector2(vs)
	_shadow_quad.size = Vector2(vs)
	_update_shadow(TitleStyle.merged("title", {}, _props, media.label if media != null else ""))


func set_props(p: Dictionary) -> void:
	var st: String = TitleStyle.stamp(p)
	if st == _props_stamp and _viewport != null:
		return
	_props = p.duplicate(true)
	_props_stamp = st
	if _viewport == null:
		return
	if kind == KIND_SOLID and _rect != null:
		_rect.color = TitleStyle.colour_of(_props.get("colour", null), Color(0.5, 0.5, 0.5, 1.0))
		MadePicture.apply(_viewport, _rect, _made, _props)
	elif _label != null:
		var merged: Dictionary = TitleStyle.merged("shape" if kind == KIND_SHAPE else "title", {}, _props, media.label if media != null else "")
		_label.set("props", merged)
		_label.queue_redraw()
		if _box_layer != null:
			_box_layer.set("props", merged)
			_box_layer.queue_redraw()
		if _blur_layer != null:
			_blur_layer.set("props", merged)
		_update_shadow(merged)


class _TitleBox:
	extends Control

	var part: String = "all"
	var props: Dictionary = {}:
		set(v):
			props = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if props.is_empty() or size.x < 2.0 or size.y < 2.0:
			return
		if part != "all" and TextGlyphs.active(props):
			TextGlyphs.draw(self, props, size, part)
			return
		var text: String = String(props.get("text", ""))
		if bool(props.get("uppercase", false)):
			text = text.to_upper()
		if text.strip_edges().is_empty():
			return
		var reveal: float = clampf(float(props.get("reveal", 1.0)), 0.0, 1.0)
		var shown: int = text.length()
		if reveal < 0.99999:
			shown = int(ceil(float(text.length()) * reveal - 0.0001))
			if shown <= 0:
				return
		var cut: int = shown
		var caret: String = String(props.get("cursor", ""))
		if not caret.is_empty() and shown < text.length():
			text = text.substr(0, shown) + caret
			cut = text.length()
		var scale_f: float = size.y / 1080.0
		var font: Font = TitleStyle.font_for(String(props.get("font", "")), bool(props.get("bold", false)), bool(props.get("italic", false)))
		font = TitleStyle.spaced(font, int(round(float(props.get("letter_spacing", 0.0)) * scale_f)))
		var fs: int = maxi(int(round(float(props.get("size", 72.0)) * scale_f)), 4)
		var para: TextParagraph = TextParagraph.new()
		var width_frac: float = clampf(float(props.get("width", 0.9)), 0.05, 1.0)
		var pad: float = float(props.get("box_pad", 12.0)) * scale_f
		para.width = size.x * width_frac - pad * 2.0
		var align: String = String(props.get("align", "center"))
		para.alignment = HORIZONTAL_ALIGNMENT_LEFT if align == "left" else (HORIZONTAL_ALIGNMENT_RIGHT if align == "right" else HORIZONTAL_ALIGNMENT_CENTER)
		para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
		para.add_string(text, font, fs)
		var extra_line: float = float(props.get("line_spacing", 0.0)) * scale_f
		var text_size: Vector2 = para.get_size()
		var lines: int = maxi(para.get_line_count(), 1)
		var block_h: float = text_size.y + extra_line * float(lines - 1)
		var block_w: float = text_size.x
		var valign: String = String(props.get("valign", "center"))
		var x0: float = (size.x - para.width) * 0.5
		if align == "left":
			x0 = size.x * (1.0 - width_frac) * 0.5 + pad
		elif align == "right":
			x0 = size.x - size.x * (1.0 - width_frac) * 0.5 - pad - para.width
		var y0: float = (size.y - block_h) * 0.5
		if valign == "top":
			y0 = size.y * 0.06
		elif valign == "bottom":
			y0 = size.y - block_h - size.y * 0.06
		var box_col: Color = TitleStyle.colour_of(props.get("box_colour", null), Color(0, 0, 0, 0))
		if box_col.a > 0.001 and (part == "all" or part == "box"):
			var bx: float = x0 + (para.width - block_w) * (0.0 if align == "left" else (1.0 if align == "right" else 0.5)) - pad
			var box := StyleBoxFlat.new()
			box.bg_color = box_col
			box.set_corner_radius_all(int(round(float(props.get("box_radius", 8.0)) * scale_f)))
			box.anti_aliasing = true
			draw_style_box(box, Rect2(bx, y0 - pad, block_w + pad * 2.0, block_h + pad * 2.0))
		if part == "box":
			return
		var glyphs: bool = part == "glyphs"
		var colour: Color = Color.WHITE if glyphs else TitleStyle.colour_of(props.get("colour", null), Color.WHITE)
		var outline: int = int(round(float(props.get("outline", 0.0)) * scale_f))
		var outline_col: Color = Color.WHITE if glyphs else TitleStyle.colour_of(props.get("outline_colour", null), Color.BLACK)
		var rid: RID = get_canvas_item()
		var y: float = y0
		var ts: TextServer = TextServerManager.get_primary_interface()
		for i: int in lines:
			var line_rid: RID = para.get_line_rid(i)
			var span: Vector2i = para.get_line_range(i)
			var clip_r: float = -1.0
			if cut < text.length():
				if cut <= span.x:
					break
				if cut < span.y:
					clip_r = ts.shaped_text_get_grapheme_bounds(line_rid, cut).x
			var lw: float = para.get_line_width(i)
			var lx: float = x0
			if align == "center":
				lx = x0 + (para.width - lw) * 0.5
			elif align == "right":
				lx = x0 + para.width - lw
			var asc: float = para.get_line_ascent(i)
			var pos: Vector2 = Vector2(lx, y + asc)
			if outline > 0:
				ts.shaped_text_draw_outline(line_rid, rid, pos, -1.0, clip_r, outline, outline_col)
			ts.shaped_text_draw(line_rid, rid, pos, -1.0, clip_r, colour)
			y += para.get_line_size(i).y + extra_line


class _ShapeBox:
	extends Control

	var props: Dictionary = {}:
		set(v):
			props = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if props.is_empty():
			return
		if ShapeGeometry.uses_new(props):
			ShapeGeometry.draw(self, props, size)
			return
		var w: float = clampf(float(props.get("width", 0.5)), 0.001, 1.0) * size.x
		var h: float = clampf(float(props.get("height", 0.5)), 0.001, 1.0) * size.y
		var r: Rect2 = Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)
		var col: Color = TitleStyle.colour_of(props.get("colour", null), Color(0.5, 0.5, 0.5, 1.0))
		var border: float = float(props.get("border", 0.0)) * size.y / 1080.0
		var bcol: Color = TitleStyle.colour_of(props.get("border_colour", null), Color.BLACK)
		var shape: String = String(props.get("shape", "rect"))
		if shape == "ellipse":
			var pts := PackedVector2Array()
			var n: int = 96
			for i: int in n:
				var a: float = TAU * float(i) / float(n)
				pts.append(r.get_center() + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.5))
			draw_colored_polygon(pts, col)
			if border > 0.0:
				pts.append(pts[0])
				draw_polyline(pts, bcol, border, true)
			return
		if shape == "line":
			draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), col, maxf(h, 1.0), true)
			return
		var box := StyleBoxFlat.new()
		box.bg_color = col
		box.set_corner_radius_all(int(round(float(props.get("radius", 0.0)) * size.y / 1080.0)))
		box.anti_aliasing = true
		if border > 0.0:
			box.set_border_width_all(int(round(border)))
			box.border_color = bcol
		draw_style_box(box, r)


func _load_image() -> void:
	_image_tex = null
	if media == null or media.path.is_empty():
		return
	var img: Image = Image.new()
	var path: String = ProjectSettings.globalize_path(media.path) if media.path.begins_with("res://") or media.path.begins_with("user://") else media.path
	if img.load(path) != OK:
		return
	if img.get_width() < 1 or img.get_height() < 1:
		return
	img.convert(Image.FORMAT_RGBA8)
	img.premultiply_alpha()
	native_size = img.get_size()
	_image_tex = ImageTexture.create_from_image(img)


func set_quality_scale(s: float) -> void:
	if is_equal_approx(s, quality_scale):
		return
	quality_scale = s
	if _viewport != null:
		_viewport.size = _viewport_size()
		if _rect != null:
			_rect.size = Vector2(_viewport.size)
		if _label != null:
			_label.size = Vector2(_viewport.size)
		if _box_layer != null:
			_box_layer.size = Vector2(_viewport.size)
		if _blur_layer != null:
			_blur_layer.size = Vector2(_viewport.size)
		_resize_shadow()


func viewport() -> SubViewport:
	return _viewport


func set_nest_texture(tex: Texture2D, size: Vector2i) -> void:
	_nest_tex = tex
	if size.x > 0 and size.y > 0:
		native_size = size


func texture() -> Texture2D:
	if kind == KIND_NATIVE or kind == KIND_TITLE or kind == KIND_SOLID or kind == KIND_SHAPE:
		return _viewport.get_texture() if _viewport != null else null
	if kind == KIND_IMAGE:
		return _image_tex if _image_tex != null else missing_texture()
	if kind == KIND_NEST:
		return _nest_tex
	if kind == KIND_PATTERN:
		if _pattern_tex == null:
			_render_pattern(0.0)
		return _pattern_tex
	return missing_texture()


func is_exact() -> bool:
	return state == "exact" or state == "static"


func request(seconds: float, quality: int, hint: int) -> void:
	last_time = seconds
	if kind == KIND_PATTERN:
		_render_pattern(seconds)
		state = "static"
		return
	if kind == KIND_NATIVE:
		_request_native(seconds, quality, hint)
		return
	if kind == KIND_IMAGE:
		state = "static" if _image_tex != null else "none"
		return
	state = "static"


func _render_pattern(seconds: float) -> void:
	var q: float = round(seconds * 1000.0) / 1000.0
	if _pattern_tex != null and is_equal_approx(q, _pattern_time):
		return
	_pattern_time = q
	_pattern_bytes = pattern_bytes(q, PATTERN_W, PATTERN_H)
	var img: Image = Image.create_from_data(PATTERN_W, PATTERN_H, false, Image.FORMAT_RGBA8, _pattern_bytes)
	if _pattern_tex == null:
		_pattern_tex = ImageTexture.create_from_image(img)
	else:
		_pattern_tex.update(img)


func _request_native(seconds: float, quality: int, hint: int) -> void:
	if tap_handle >= 0 and hint != HINT_EXPORT and _bridge != null and _bridge.has_method("can_tap") and bool(_bridge.call("can_tap")):
		if _request_tap(seconds):
			return
	tapping = false
	if _bridge == null or not bool(_bridge.get("available")) or handle < 0:
		state = "none"
		if _material != null:
			_material.set_shader_parameter("has_frame", false)
			_thaw()
		has_picture = false
		return
	proxy_waiting = false
	var req_h: int = handle
	var at: float = seconds
	var off: float = 0.0
	var route: Dictionary = _proxy_route(seconds)
	if not route.is_empty():
		req_h = int(route["handle"])
		off = float(route["start"])
		at = maxf(float(route["pick_at"]), 0.0) if route.has("pick_at") else maxf(seconds - off, 0.0)
	var now: int = Time.get_ticks_msec()
	if req_h != _req_handle:
		if _req_handle >= 0:
			proxy_switches += 1
			_switch_ms = now
			_from_original = _req_handle == handle
		_req_handle = req_h
	proxy_on = req_h != handle
	proxy_path = String(route.get("path", ""))
	_req_at = at
	if not _scrub_use(at, quality, hint, req_h):
		_bridge.call("request_frame", req_h, at, quality, HINT_PLAY if warm_for_play and hint == HINT_STEP else hint)
	var p: Dictionary = _scrub_after(_bridge.call("present", req_h), at)
	if proxy_on:
		var proxy_pts: float = float(p.get("pts", at))
		if route.has("pick_pts") and absf(proxy_pts - at) < PROXY_SAME_PTS:
			p["pts"] = float(route["pick_pts"])
		else:
			p["pts"] = proxy_pts + off
		p["colorspace"] = PROXY_COLORSPACE
	if proxy_on and hint == HINT_PLAY:
		_preopen_next(route, seconds, quality)
	var recent: bool = has_picture and now - _switch_ms < FIRST_FRAME_WAIT_MS
	if recent and proxy_on and _from_original and not _ready_frame(p):
		_bridge.call("request_frame", handle, seconds, quality, hint)
		p = _bridge.call("present", handle)
		proxy_on = false
		proxy_waiting = true
	if recent and String(p.get("state", "none")) == "none":
		state = "pending"
		return
	if _keeps_picture(p, hint, seconds):
		state = "pending"
		return
	state = first_frame_state(String(p.get("state", "none")), p.get("y", RID()))
	if state == "approx" and not approx_allowed():
		if _had_exact:
			state = "pending"
			return
		return
	var y: RID = p.get("y", RID())
	var uv: RID = p.get("uv", RID())
	if state == "none" or state == "pending" and not y.is_valid():
		if _material != null and state == "none":
			_material.set_shader_parameter("has_frame", false)
			_thaw()
			has_picture = false
		return
	var rgb: bool = bool(p.get("rgb", false))
	if not y.is_valid() or (not rgb and not uv.is_valid()):
		return
	var turn: int = turn_of(p)
	var w: int = int(p.get("width", 0))
	var h: int = int(p.get("height", 0))
	if turn == 90 or turn == 270:
		var keep: int = w
		w = h
		h = keep
	_material.set_shader_parameter("turn", turn)
	if w > 0 and h > 0 and Vector2i(w, h) != native_size and not is_reduced_copy(Vector2i(w, h), native_size):
		native_size = Vector2i(w, h)
		_viewport.size = _viewport_size()
		_rect.size = Vector2(_viewport.size)
	_thaw()
	RenderingServer.material_set_param(_material.get_rid(), "y_tex", y)
	if uv.is_valid():
		RenderingServer.material_set_param(_material.get_rid(), "uv_tex", uv)
	_material.set_shader_parameter("rgb_frame", rgb)
	_material.set_shader_parameter("colorspace", int(COLORSPACES.get(String(p.get("colorspace", "bt709")).to_lower(), 1)))
	_material.set_shader_parameter("full_range", bool(p.get("full_range", false)))
	_material.set_shader_parameter("has_frame", true)
	has_picture = true
	shown_pts = float(p.get("pts", seconds))
	_note_shown(w, h, rgb)
	if not rgb and state == "exact":
		_had_exact = true
		primed = true


static func turn_of(p: Dictionary) -> int:
	var r: int = posmod(int(p.get("rotation", 0)), 360)
	return posmod(int(round(float(r) / 90.0)) * 90, 360)


static func approx_allowed() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
		if prefs != null and prefs.has_method("is_registered"):
			if not bool(prefs.call("is_registered", "playback.low_res_pictures")):
				prefs.call("register", "playback.low_res_pictures", false, {"label": "Show the low resolution filmstrip picture while a frame decodes", "type": "bool"})
			if FullQuality.on_for(prefs):
				return false
			return bool(prefs.call("get_value", "playback.low_res_pictures"))
	return true


func set_yuv_textures(y: RID, uv: RID, colorspace: int, full_range: bool) -> void:
	if _material == null:
		return
	_thaw()
	RenderingServer.material_set_param(_material.get_rid(), "y_tex", y)
	RenderingServer.material_set_param(_material.get_rid(), "uv_tex", uv)
	_material.set_shader_parameter("rgb_frame", false)
	_material.set_shader_parameter("colorspace", colorspace)
	_material.set_shader_parameter("full_range", full_range)
	_material.set_shader_parameter("has_frame", true)
	has_picture = true
	state = "exact"


var _frozen: bool = false


func hold_picture() -> void:
	if kind != KIND_NATIVE or _viewport == null or _frozen or not has_picture:
		return
	if _viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_frozen = true


func picture_held() -> bool:
	return _frozen


func _thaw() -> void:
	if _frozen and _viewport != null and _viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_frozen = false


func first_frame_state(engine_state: String, y: Variant) -> String:
	if y is RID and (y as RID).is_valid():
		_had_frame = true
	if engine_state == "none" and not _had_frame and Time.get_ticks_msec() - _opened_ms < FIRST_FRAME_WAIT_MS:
		return "pending"
	return engine_state


static func is_reduced_copy(decoded: Vector2i, full: Vector2i) -> bool:
	for k: int in 4:
		var want: Vector2i = Vector2i(maxi((full.x >> k) & ~1, 2), maxi((full.y >> k) & ~1, 2))
		if decoded == want:
			return true
	return false


const ScrubRoute := preload("res://engine/scrub_route.gd")

var shown_size: Vector2i = Vector2i.ZERO
var shown_rgb: bool = false
var _scrub: ScrubRoute = null
var _scrubbed: bool = false


func _scrub_use(seconds: float, quality: int, hint: int, h: int) -> bool:
	_scrubbed = ScrubRoute.wants(hint)
	if not _scrubbed:
		return false
	if _scrub == null:
		_scrub = ScrubRoute.new()
	_scrub.request(_bridge, h, seconds, quality)
	return true


func _scrub_after(p: Dictionary, seconds: float) -> Dictionary:
	if not _scrubbed or _scrub == null:
		return p
	return _scrub.after_present(_bridge, p, seconds, media.fps if media != null and media.fps > 0.0 else 60.0)


func scrub_stats() -> Dictionary:
	if _scrub == null:
		return {"sent": 0, "held": 0, "paced": true}
	return {"sent": _scrub.sent, "held": _scrub.held, "paced": _scrub.paced}


func _keeps_picture(p: Dictionary, hint: int, seconds: float) -> bool:
	if kind != KIND_NATIVE:
		return false
	return ScrubRoute.keeps(p, hint, has_picture, shown_rgb, shown_pts, seconds, _scrub != null and _scrub.known and not _scrub.paced)


func _note_shown(w: int, h: int, rgb: bool) -> void:
	shown_size = Vector2i(w, h)
	shown_rgb = rgb


func _session_node() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Session")
	return null


static func _ready_frame(p: Dictionary) -> bool:
	var st: String = String(p.get("state", "none"))
	var y: Variant = p.get("y", RID())
	return (st == "exact" or st == "near") and y is RID and (y as RID).is_valid()


func _proxy_lane() -> String:
	return PROXY_LANE + str(handle)


func _proxy_route(seconds: float) -> Dictionary:
	if not use_proxy or media == null or media.path.is_empty() or media.fps <= 0.0:
		return {}
	var seg: Dictionary = Proxies.playback_segment(media.path, media.fps, seconds, media.width)
	if seg.is_empty():
		return {}
	var pick: Dictionary = Proxies.proxy_pick(String(seg["path"]), media.fps, seconds)
	if bool(pick.get("before", false)) and int(seg["index"]) > 0:
		var prev: Dictionary = Proxies.playback_segment(media.path, media.fps, Proxies.segment_start_for(int(seg["index"]) - 1, media.fps), media.width)
		var prev_pick: Dictionary = {} if prev.is_empty() else Proxies.proxy_pick(String(prev["path"]), media.fps, seconds)
		if prev_pick.has("frame"):
			seg = prev
			pick = prev_pick
	if pick.has("frame"):
		seg["pick_at"] = float(pick["at"])
		seg["pick_pts"] = float(pick["pts"])
	var s: Node = _session_node()
	if s == null or not s.has_method("proxy_handle"):
		return {}
	var h: int = int(s.call("proxy_handle", String(seg["path"]), _proxy_lane()))
	if h < 0:
		return {}
	seg["handle"] = h
	return seg


func _preopen_next(route: Dictionary, seconds: float, quality: int) -> void:
	var nxt_start: float = Proxies.segment_start_for(int(route["index"]) + 1, media.fps)
	var lead: float = nxt_start - seconds
	if lead <= 0.0 or lead > PROXY_PREOPEN_SECONDS:
		return
	if media.duration > 0.0 and nxt_start >= media.duration:
		return
	var nxt: Dictionary = Proxies.playback_segment(media.path, media.fps, nxt_start, media.width)
	if nxt.is_empty() or String(nxt["path"]) == _preopened:
		return
	var s: Node = _session_node()
	if s == null or not s.has_method("proxy_handle"):
		return
	var h2: int = int(s.call("proxy_handle", String(nxt["path"]), _proxy_lane()))
	if h2 < 0:
		return
	_preopened = String(nxt["path"])
	_bridge.call("request_frame", h2, 0.0, quality, HINT_PLAY)


const HINT_EXPORT := 3


func _request_tap(seconds: float) -> bool:
	tapping = true
	tap_requests += 1
	proxy_waiting = false
	proxy_on = false
	_req_handle = -1
	_req_at = seconds
	var p: Dictionary = _bridge.call("present_at", tap_handle, seconds, tap_slot)
	var st: String = String(p.get("state", "none"))
	var y: RID = p.get("y", RID())
	var uv: RID = p.get("uv", RID())
	if st == "none" or st == "pending" or not y.is_valid() or not uv.is_valid():
		state = "pending"
		return true
	state = st
	var turn: int = turn_of(p)
	var w: int = int(p.get("width", 0))
	var h: int = int(p.get("height", 0))
	if turn == 90 or turn == 270:
		var keep: int = w
		w = h
		h = keep
	if _viewport == null or _material == null:
		return true
	_material.set_shader_parameter("turn", turn)
	if w > 0 and h > 0 and Vector2i(w, h) != native_size and not is_reduced_copy(Vector2i(w, h), native_size):
		native_size = Vector2i(w, h)
		_viewport.size = _viewport_size()
		_rect.size = Vector2(_viewport.size)
	_thaw()
	RenderingServer.material_set_param(_material.get_rid(), "y_tex", y)
	RenderingServer.material_set_param(_material.get_rid(), "uv_tex", uv)
	_material.set_shader_parameter("rgb_frame", false)
	_material.set_shader_parameter("colorspace", int(COLORSPACES.get(String(p.get("colorspace", "bt709")).to_lower(), 1)))
	_material.set_shader_parameter("full_range", bool(p.get("full_range", false)))
	_material.set_shader_parameter("has_frame", true)
	has_picture = true
	_had_frame = true
	shown_pts = float(p.get("pts", seconds))
	_note_shown(w, h, false)
	if state == "exact":
		_had_exact = true
		primed = true
	return true


func rehandle(h: int) -> void:
	if h == handle:
		return
	handle = h
	primed = false
	_req_handle = -1
	_primed_h = -1
	_had_frame = false
	_opened_ms = Time.get_ticks_msec()
	state = "pending" if has_picture else "none"


func ready_now() -> bool:
	if not primed or not has_picture:
		return false
	if state == "exact":
		return true
	var fps: float = media.fps if media != null and media.fps > 0.0 else 30.0
	return state == "near" and absf(shown_pts - last_time) <= 1.5 / fps


func prime_for_play(quality: int) -> bool:
	if kind != KIND_NATIVE or _bridge == null or _req_handle < 0 or _req_at < 0.0 or not has_picture or _frozen:
		return false
	if _primed_h == _req_handle and absf(_primed_at - _req_at) < 0.0005:
		return false
	_primed_h = _req_handle
	_primed_at = _req_at
	primes += 1
	_bridge.call("request_frame", _req_handle, _req_at, quality, HINT_PLAY)
	return true


func proxy_state() -> Dictionary:
	return {"on": proxy_on, "path": proxy_path, "switches": proxy_switches, "handle": _req_handle}

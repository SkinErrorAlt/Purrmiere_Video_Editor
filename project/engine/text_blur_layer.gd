extends Control

const TextGlyphs := preload("res://engine/text_glyphs.gd")
const MAX_SIGMA := 40.0
const ATLAS_MIN_W := 1024
const ATLAS_MAX := 8192
const BLUR_CODE := """shader_type canvas_item;
render_mode blend_disabled;
uniform vec2 direction = vec2(1.0, 0.0);
varying float sigma;
void vertex() {
	sigma = COLOR.r * 64.0;
}
void fragment() {
	float s = max(sigma, 0.3);
	int r = int(ceil(s * 3.0));
	vec2 step_px = TEXTURE_PIXEL_SIZE * direction;
	vec4 acc = vec4(0.0);
	float total = 0.0;
	for (int i = -r; i <= r; i++) {
		float w = exp(-float(i * i) / (2.0 * s * s));
		acc += texture(TEXTURE, UV + step_px * float(i)) * w;
		total += w;
	}
	COLOR = acc / total;
}
"""
const SHOW_CODE := """shader_type canvas_item;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 rgb = t.a > 0.0001 ? t.rgb / t.a : vec3(0.0);
	COLOR = vec4(rgb, t.a) * tint;
}
"""

static var builds: int = 0
static var _blur_shader: Shader = null
static var _show_shader: Shader = null

var props: Dictionary = {}:
	set(v):
		props = v
		rebuild()
var items: Array[Dictionary] = []
var spill: Array[Dictionary] = []
var atlas_size: Vector2i = Vector2i.ZERO
var _atlas_vp: SubViewport = null
var _atlas_draw: Control = null
var _h_vp: SubViewport = null
var _h_draw: Control = null
var _v_vp: SubViewport = null
var _v_draw: Control = null
var _spill_draw: Control = null


static func blur_shader() -> Shader:
	if _blur_shader == null:
		_blur_shader = Shader.new()
		_blur_shader.code = BLUR_CODE
	return _blur_shader


static func show_shader() -> Shader:
	if _show_shader == null:
		_show_shader = Shader.new()
		_show_shader.code = SHOW_CODE
	return _show_shader


static func sigma_of(radius: float) -> float:
	return clampf(radius * 0.5, 0.3, MAX_SIGMA)


static func content_rect(g: Dictionary) -> Rect2:
	var at: Vector2 = g["at"]
	var adv: float = float(g.get("adv", 0.0))
	var sz: float = float(g.get("size", 16))
	var grow: float = float(g.get("outline", 0)) + float(g.get("stroke2", 0)) + 1.0
	var more: Array = g.get("more", [])
	if not more.is_empty():
		grow += float((more[more.size() - 1] as Dictionary)["reach"])
	var lean: float = float(g.get("lean", 0.0))
	var margin: float = sz * 0.3
	var x0: float = at.x - lean - grow - margin
	var x1: float = at.x + adv + grow + margin
	var y0: float = at.y - float(g.get("asc", sz)) - grow - margin * 0.5
	var y1: float = at.y + float(g.get("desc", 0.0)) + grow + margin * 0.5
	return Rect2(x0, y0, x1 - x0, y1 - y0)


static func pack(got: Array[Dictionary], max_w: int) -> Dictionary:
	var placed: Array[Dictionary] = []
	var left: Array[Dictionary] = []
	var top_sigma: float = 0.3
	for g0: Dictionary in got:
		top_sigma = maxf(top_sigma, sigma_of(float(g0.get("blur", 0.0))))
	var pad: float = ceilf(top_sigma * 3.0) + 2.0
	var widest: float = 0.0
	for g1: Dictionary in got:
		widest = maxf(widest, content_rect(g1).size.x + pad * 2.0)
	var w: int = clampi(int(ceilf(widest)), ATLAS_MIN_W, mini(max_w, ATLAS_MAX))
	var x: float = 0.0
	var y: float = 0.0
	var row_h: float = 0.0
	for g: Dictionary in got:
		var cr: Rect2 = content_rect(g)
		var local: Rect2 = cr.grow(pad)
		var tw: float = ceilf(local.size.x)
		var th: float = ceilf(local.size.y)
		local.size = Vector2(tw, th)
		if tw > float(w):
			left.append(g)
			continue
		if x + tw > float(w):
			x = 0.0
			y += row_h
			row_h = 0.0
		if y + th > float(ATLAS_MAX):
			left.append(g)
			continue
		var item: Dictionary = g.duplicate()
		item["local"] = local
		item["tile"] = Rect2(x, y, tw, th)
		item["sigma"] = sigma_of(float(g.get("blur", 0.0)))
		placed.append(item)
		x += tw
		row_h = maxf(row_h, th)
	var h: int = int(ceilf(y + row_h))
	return {"items": placed, "spill": left, "size": Vector2i(w, maxi(h, 2))}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = show_shader()
	material = mat
	_spill_draw = _Pass.new()
	_spill_draw.name = "BlurSpill"
	_spill_draw.set("layer", self)
	_spill_draw.set("mode", 2)
	_spill_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_spill_draw)


func rebuild() -> void:
	var had: bool = not items.is_empty() or not spill.is_empty()
	items = []
	spill = []
	var got: Array[Dictionary] = []
	if not props.is_empty() and size.x >= 2.0 and size.y >= 2.0:
		got = TextGlyphs.blurred_glyphs(props, size)
	if got.is_empty():
		_drop()
		if had:
			queue_redraw()
			_spill_draw.queue_redraw()
		return
	var packed: Dictionary = pack(got, maxi(int(size.x), ATLAS_MIN_W))
	items = packed["items"]
	spill = packed["spill"]
	atlas_size = packed["size"]
	builds += 1
	if not items.is_empty():
		_ensure()
		_atlas_vp.size = atlas_size
		_h_vp.size = atlas_size
		_v_vp.size = atlas_size
		_atlas_draw.size = Vector2(atlas_size)
		_h_draw.size = Vector2(atlas_size)
		_v_draw.size = Vector2(atlas_size)
		_atlas_draw.queue_redraw()
		_h_draw.queue_redraw()
		_v_draw.queue_redraw()
	else:
		_drop()
	queue_redraw()
	_spill_draw.queue_redraw()


func _on_resized() -> void:
	rebuild()


func _ready() -> void:
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)


func _ensure() -> void:
	if _v_vp != null:
		return
	_atlas_vp = _viewport("BlurAtlas")
	_atlas_draw = _Pass.new()
	_atlas_draw.set("layer", self)
	_atlas_draw.set("mode", 0)
	_atlas_vp.add_child(_atlas_draw)
	_h_vp = _viewport("BlurAcross")
	_h_draw = _Pass.new()
	_h_draw.set("layer", self)
	_h_draw.set("mode", 1)
	_h_draw.set("source", _atlas_vp)
	_h_draw.material = _blur_material(Vector2(1.0, 0.0))
	_h_draw.add_child(_atlas_vp)
	_h_vp.add_child(_h_draw)
	_v_vp = _viewport("BlurDown")
	_v_draw = _Pass.new()
	_v_draw.set("layer", self)
	_v_draw.set("mode", 1)
	_v_draw.set("source", _h_vp)
	_v_draw.material = _blur_material(Vector2(0.0, 1.0))
	_v_draw.add_child(_h_vp)
	_v_vp.add_child(_v_draw)
	add_child(_v_vp)


func _blur_material(dir: Vector2) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = blur_shader()
	m.set_shader_parameter("direction", dir)
	return m


func _viewport(n: String) -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.name = n
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(2, 2)
	return vp


func _drop() -> void:
	if _v_vp == null:
		return
	remove_child(_v_vp)
	_v_vp.queue_free()
	_v_vp = null
	_v_draw = null
	_h_vp = null
	_h_draw = null
	_atlas_vp = null
	_atlas_draw = null


func blurred_texture() -> Texture2D:
	return _v_vp.get_texture() if _v_vp != null else null


func _draw() -> void:
	var tex: Texture2D = blurred_texture()
	if tex != null:
		for it: Dictionary in items:
			var op: float = float(it.get("opacity", 1.0))
			if op <= 0.0:
				continue
			draw_set_transform_matrix(it["xf"])
			draw_texture_rect_region(tex, it["local"], it["tile"], Color(1.0, 1.0, 1.0, op))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func draw_spill(ci: CanvasItem) -> void:
	var ts: TextServer = TextServerManager.get_primary_interface()
	var rid: RID = ci.get_canvas_item()
	for g: Dictionary in spill:
		var s2: int = int(g.get("stroke2", 0))
		var more: Array = g.get("more", [])
		for mi: int in range(more.size() - 1, -1, -1):
			TextGlyphs.draw_one(ci, ts, rid, g, int(g.get("outline", 0)) + s2 + int((more[mi] as Dictionary)["reach"]), (more[mi] as Dictionary)["col"])
		if s2 > 0:
			TextGlyphs.draw_one(ci, ts, rid, g, int(g.get("outline", 0)) + s2, g["stroke2_col"])
		if int(g.get("outline", 0)) > 0:
			TextGlyphs.draw_one(ci, ts, rid, g, int(g["outline"]), g["ocol"])
		TextGlyphs.draw_one(ci, ts, rid, g, 0, g["col"])
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func draw_tiles(ci: CanvasItem) -> void:
	var ts: TextServer = TextServerManager.get_primary_interface()
	var rid: RID = ci.get_canvas_item()
	for it: Dictionary in items:
		var tile: Rect2 = it["tile"]
		var local: Rect2 = it["local"]
		var g: Dictionary = it.duplicate()
		g["xf"] = Transform2D(0.0, tile.position - local.position)
		g["blur"] = 0.0
		g["opacity"] = 1.0
		var s2: int = int(g.get("stroke2", 0))
		var more: Array = g.get("more", [])
		for mi: int in range(more.size() - 1, -1, -1):
			TextGlyphs.draw_one(ci, ts, rid, g, int(g.get("outline", 0)) + s2 + int((more[mi] as Dictionary)["reach"]), (more[mi] as Dictionary)["col"])
		if s2 > 0:
			TextGlyphs.draw_one(ci, ts, rid, g, int(g.get("outline", 0)) + s2, g["stroke2_col"])
		if int(g.get("outline", 0)) > 0:
			TextGlyphs.draw_one(ci, ts, rid, g, int(g["outline"]), g["ocol"])
		TextGlyphs.draw_one(ci, ts, rid, g, 0, g["col"])
		if bool(g.get("under", false)):
			TextGlyphs.draw_underline(ci, ts, g, false)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func blur_tiles(ci: CanvasItem, source: SubViewport) -> void:
	var tex: Texture2D = source.get_texture()
	for it: Dictionary in items:
		var tile: Rect2 = it["tile"]
		ci.draw_texture_rect_region(tex, tile, tile, Color(float(it["sigma"]) / 64.0, 0.0, 0.0, 1.0))


class _Pass:
	extends Control

	var layer: Control = null
	var mode: int = 0
	var source: SubViewport = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if layer == null:
			return
		if mode == 0:
			layer.call("draw_tiles", self)
		elif mode == 2:
			layer.call("draw_spill", self)
		elif source != null:
			layer.call("blur_tiles", self, source)

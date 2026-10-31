extends Node

const DOWN_SHADER := "res://engine/transition_down13.gdshader"
const COPY_SHADER := "res://engine/copy.gdshader"
const LEVELS := 6
const GAP := 2

static var plant_unbound: bool = false

var levels: Array[SubViewport] = []
var mats: Array[ShaderMaterial] = []
var rects: Array[ColorRect] = []
var tiles: Array[TextureRect] = []
var atlas: SubViewport = null
var base: Vector2i = Vector2i.ZERO
var source: Texture2D = null


static func level_px(size_px: Vector2i, l: int) -> Vector2i:
	if l <= 0:
		return size_px
	var k: float = pow(2.0, float(l))
	return Vector2i(maxi(int(ceil(float(size_px.x) / k)), 1), maxi(int(ceil(float(size_px.y) / k)), 1))


static func origin(size_px: Vector2i, l: int) -> Vector2i:
	if l <= 1:
		return Vector2i.ZERO
	var o: Vector2i = Vector2i(level_px(size_px, 1).x + GAP, 0)
	for k: int in range(2, l):
		o.y += level_px(size_px, k).y + GAP
	return o


static func atlas_px(size_px: Vector2i) -> Vector2i:
	var l1: Vector2i = level_px(size_px, 1)
	var right: Vector2i = origin(size_px, LEVELS) + level_px(size_px, LEVELS)
	return Vector2i(maxi(l1.x + GAP + level_px(size_px, 2).x, right.x), maxi(l1.y, right.y))


static func _vp(n: String) -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.name = n
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(2, 2)
	return vp


func _init() -> void:
	name = "Pyramid"
	atlas = _vp("Atlas")
	add_child(atlas)
	var down: Shader = load(DOWN_SHADER)
	var copy: Shader = load(COPY_SHADER)
	levels.resize(LEVELS)
	mats.resize(LEVELS)
	rects.resize(LEVELS)
	var parent: Node = atlas
	for i: int in range(LEVELS - 1, -1, -1):
		var vp: SubViewport = _vp("L" + str(i + 1))
		parent.add_child(vp)
		parent = vp
		levels[i] = vp
		var r: ColorRect = ColorRect.new()
		r.name = "Down"
		r.color = Color.WHITE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = down
		r.material = m
		vp.add_child(r)
		mats[i] = m
		rects[i] = r
	for i: int in range(1, LEVELS):
		mats[i].set_shader_parameter("src", levels[i - 1].get_texture())
	for i: int in LEVELS:
		var t: TextureRect = TextureRect.new()
		t.name = "Tile" + str(i + 1)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cm: ShaderMaterial = ShaderMaterial.new()
		cm.shader = copy
		t.material = cm
		t.texture = levels[i].get_texture()
		atlas.add_child(t)
		tiles.append(t)


func source_holder() -> SubViewport:
	return levels[0]


func set_source(tex: Texture2D, size_px: Vector2i) -> void:
	if tex != source:
		source = tex
		mats[0].set_shader_parameter("src", tex)
	fit(size_px)


func fit(size_px: Vector2i) -> void:
	if size_px == base:
		return
	base = size_px
	var ap: Vector2i = atlas_px(size_px)
	if atlas.size != ap:
		atlas.size = ap
	for i: int in LEVELS:
		var s: Vector2i = level_px(size_px, i + 1)
		if levels[i].size != s:
			levels[i].size = s
		rects[i].position = Vector2.ZERO
		rects[i].size = Vector2(s)
		mats[i].set_shader_parameter("src_px", Vector2(level_px(size_px, i)))
		tiles[i].position = Vector2(origin(size_px, i + 1))
		tiles[i].size = Vector2(s)


func texture() -> Texture2D:
	return atlas.get_texture()


func size_of_atlas() -> Vector2:
	return Vector2(atlas_px(base))


func viewports() -> Array[SubViewport]:
	var out: Array[SubViewport] = [atlas]
	out.append_array(levels)
	return out

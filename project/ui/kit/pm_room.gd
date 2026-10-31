extends TextureRect

const BLUR_MAX := 16.0
const RISE := 18.0
const SHADER_CODE := """shader_type canvas_item;
uniform float blur : hint_range(0.0, 32.0) = 0.0;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	float lod = blur <= 0.5 ? 0.0 : log2(blur);
	vec2 px = TEXTURE_PIXEL_SIZE * blur;
	vec4 c = textureLod(TEXTURE, UV, lod) * 0.4;
	c += textureLod(TEXTURE, UV + vec2(px.x, 0.0), lod) * 0.15;
	c += textureLod(TEXTURE, UV - vec2(px.x, 0.0), lod) * 0.15;
	c += textureLod(TEXTURE, UV + vec2(0.0, px.y), lod) * 0.15;
	c += textureLod(TEXTURE, UV - vec2(0.0, px.y), lod) * 0.15;
	COLOR = c * tint;
}
"""

var blur: float = 0.0:
	set(v):
		blur = v
		if material is ShaderMaterial:
			(material as ShaderMaterial).set_shader_parameter("blur", v)


static func can_run(node: Node) -> bool:
	if node == null or not node.is_inside_tree():
		return false
	if DisplayServer.get_name() == "headless":
		return false
	return Tk.dur("page") > 0.0


static func snapshot(ctl: Control) -> ImageTexture:
	var vp: Viewport = ctl.get_viewport()
	if vp == null:
		return null
	var tex: ViewportTexture = vp.get_texture()
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return null
	var r: Rect2i = Rect2i(ctl.get_global_rect())
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x <= 0 or r.size.y <= 0:
		return null
	var part: Image = img.get_region(r)
	part.generate_mipmaps()
	return ImageTexture.create_from_image(part)


static func leave(ctl: Control, overlay: Node) -> Control:
	if not can_run(ctl) or overlay == null:
		return null
	var tex: ImageTexture = snapshot(ctl)
	if tex == null:
		return null
	var script: GDScript = load("res://ui/kit/pm_room.gd")
	var veil: TextureRect = script.new()
	veil.name = "RoomVeil"
	veil.texture = tex
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	var shader := Shader.new()
	shader.code = SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	veil.material = mat
	var r: Rect2 = ctl.get_global_rect()
	overlay.add_child(veil)
	veil.global_position = r.position
	veil.size = r.size
	veil.pivot_offset = r.size * 0.5
	var d: float = Tk.dur("page")
	var tw: Tween = Tk.ease(veil.create_tween())
	tw.set_parallel(true)
	tw.tween_property(veil, "blur", BLUR_MAX, d * 0.7)
	tw.tween_property(veil, "modulate:a", 0.0, d * 0.7)
	tw.tween_property(veil, "scale", Vector2(1.01, 1.01), d * 0.7)
	tw.chain().tween_callback(veil.queue_free)
	return veil


static func enter(ctl: Control) -> void:
	if not can_run(ctl):
		return
	var d: float = Tk.dur("page")
	ctl.pivot_offset = ctl.size * 0.5
	ctl.modulate.a = 0.0
	ctl.scale = Vector2(0.99, 0.99)
	var tw: Tween = Tk.ease(ctl.create_tween())
	tw.set_parallel(true)
	tw.tween_property(ctl, "modulate:a", 1.0, d)
	tw.tween_property(ctl, "scale", Vector2.ONE, d)


static func switch(ctl: Control, overlay: Node, work: Callable) -> void:
	var veil: Control = leave(ctl, overlay)
	work.call()
	if veil != null:
		enter(ctl)

extends Control

const MAX_ITEMS := 8
const SECOND_ALPHA := 0.55

var shader: Shader = null
var uniforms: Dictionary = {}
var values: Dictionary = {}
var colour: Color = Color.WHITE
var thickness: float = 1.0
var reach: float = 1.5
var animated: bool = false
var clock: float = 0.0
var shown_count: int = 0
var draws: int = 0
var _items: Array[Control] = []


func _init() -> void:
	name = "Outline"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_style(shader_: Shader, uniforms_: Dictionary, values_: Dictionary, colour_: Color, thickness_: float, reach_: float, animated_: bool) -> void:
	shader = shader_
	uniforms = uniforms_
	values = values_
	colour = colour_
	thickness = maxf(thickness_, 0.1)
	reach = maxf(reach_, 0.0)
	animated = animated_
	for i: int in _items.size():
		_apply(i)
	_sync_process()


func band() -> float:
	return thickness * 0.5 + reach


func has_style() -> bool:
	return shader != null


func show_quads(quads: Array[PackedVector2Array]) -> void:
	var n: int = mini(quads.size(), MAX_ITEMS)
	if shader == null:
		n = 0
	while _items.size() < n:
		_items.append(_make_item())
		_apply(_items.size() - 1)
	var half: float = band()
	for i: int in _items.size():
		var it: Control = _items[i]
		if i < n:
			if it.get("quad") != quads[i] or not is_equal_approx(float(it.get("half")), half):
				it.call("set_quad", quads[i], half, ring(quads[i], half), perimeter(quads[i]))
			if not it.visible:
				it.visible = true
		elif it.visible:
			it.visible = false
	shown_count = n
	if visible != (n > 0):
		visible = n > 0
	_sync_process()


func hide_all() -> void:
	if shown_count == 0 and not visible:
		return
	shown_count = 0
	visible = false
	for it: Control in _items:
		it.visible = false
	_sync_process()


func item(i: int) -> Control:
	return _items[i] if i >= 0 and i < _items.size() else null


func _make_item() -> Control:
	var it: Control = _Item.new()
	it.set("owner_layer", self)
	var mat := ShaderMaterial.new()
	it.material = mat
	add_child(it)
	it.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return it


func _apply(i: int) -> void:
	var it: Control = _items[i]
	var mat: ShaderMaterial = it.material as ShaderMaterial
	if mat == null:
		return
	if mat.shader != shader:
		mat.shader = shader
	var col: Color = colour if i == 0 else Color(colour.r, colour.g, colour.b, colour.a * SECOND_ALPHA)
	if uniforms.has("colour"):
		mat.set_shader_parameter("colour", col)
	if uniforms.has("thickness"):
		mat.set_shader_parameter("thickness", thickness)
	if uniforms.has("time"):
		mat.set_shader_parameter("time", clock)
	for k: Variant in values.keys():
		var uname: String = String(k)
		if uniforms.has(uname):
			mat.set_shader_parameter(uname, _typed(values[k], int(uniforms[uname])))
	it.call("resend")


static func _typed(v: Variant, type: int) -> Variant:
	if type == TYPE_INT:
		return int(v) if v is float or v is int or v is bool else 0
	if type == TYPE_FLOAT:
		return float(v) if v is float or v is int or v is bool else 0.0
	if type == TYPE_BOOL:
		return bool(v)
	return v


func _sync_process() -> void:
	var want: bool = animated and visible and shown_count > 0 and not _reduce_motion()
	if is_processing() != want:
		set_process(want)


static func _reduce_motion() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	var prefs: Node = (loop as SceneTree).root.get_node_or_null("Prefs") if loop is SceneTree else null
	return prefs != null and bool(prefs.call("is_registered", "ui.reduce_motion")) and bool(prefs.call("get_value", "ui.reduce_motion"))


func _process(dt: float) -> void:
	clock += dt
	if not uniforms.has("time"):
		return
	for i: int in shown_count:
		(_items[i].material as ShaderMaterial).set_shader_parameter("time", clock)


static func ring(quad: PackedVector2Array, half: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if quad.size() != 4 or half <= 0.0:
		return out
	var centre: Vector2 = (quad[0] + quad[1] + quad[2] + quad[3]) * 0.25
	var normals: Array[Vector2] = []
	var shortest: float = INF
	for i: int in 4:
		var a: Vector2 = quad[i]
		var b: Vector2 = quad[(i + 1) % 4]
		var e: Vector2 = b - a
		var len_e: float = e.length()
		if len_e < 0.01:
			return out
		shortest = minf(shortest, len_e)
		var n: Vector2 = Vector2(e.y, -e.x) / len_e
		if n.dot((a + b) * 0.5 - centre) < 0.0:
			n = -n
		normals.append(n)
	var outer: PackedVector2Array = PackedVector2Array()
	var inner: PackedVector2Array = PackedVector2Array()
	for i: int in 4:
		var n0: Vector2 = normals[(i + 3) % 4]
		var n1: Vector2 = normals[i]
		var denom: float = maxf(1.0 + n0.dot(n1), 0.05)
		var mitre: Vector2 = (n0 + n1) / denom
		outer.append(quad[i] + mitre * half)
		inner.append(quad[i] - mitre * half)
	if shortest <= half * 2.0 + 0.5:
		out.append(outer)
		return out
	for i: int in 4:
		var j: int = (i + 1) % 4
		out.append(PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]))
	return out


static func perimeter(quad: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in quad.size():
		total += quad[i].distance_to(quad[(i + 1) % quad.size()])
	return total


class _Item:
	extends Control

	var owner_layer: Control = null
	var quad: PackedVector2Array = PackedVector2Array()
	var half: float = -1.0
	var around: float = 1.0
	var _parts: Array[PackedVector2Array] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_quad(q: PackedVector2Array, half_: float, parts: Array[PackedVector2Array], around_: float) -> void:
		quad = q
		half = half_
		around = around_
		_parts = parts
		resend()
		queue_redraw()

	func resend() -> void:
		var mat: ShaderMaterial = material as ShaderMaterial
		if mat == null or quad.size() != 4:
			return
		mat.set_shader_parameter("outline_corners", quad)
		mat.set_shader_parameter("outline_perimeter", around)

	func _draw() -> void:
		var white: PackedColorArray = PackedColorArray([Color.WHITE])
		for part: PackedVector2Array in _parts:
			draw_polygon(part, white, part)
		if owner_layer != null:
			owner_layer.set("draws", int(owner_layer.get("draws")) + 1)

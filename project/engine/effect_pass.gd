extends SubViewport

var rect: TextureRect = null
var mat: ShaderMaterial = null
var uniform_types: Dictionary = {}
var scale_rel: float = 1.0
var index: int = 0
var effect_uid: String = ""
var ok: bool = true


func _init() -> void:
	name = "Pass"
	transparent_bg = true
	disable_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	size = Vector2i(2, 2)
	rect = TextureRect.new()
	rect.name = "Rect"
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = Vector2(size)
	add_child(rect)


func setup(material: ShaderMaterial, types: Dictionary) -> void:
	mat = material
	uniform_types = types
	rect.material = mat
	ok = mat != null


func set_input(tex: Texture2D) -> void:
	rect.texture = tex


func set_size_px(sz: Vector2i) -> void:
	var clamped: Vector2i = Vector2i(clampi(sz.x, 2, 16384), clampi(sz.y, 2, 16384))
	if clamped != size:
		size = clamped
	if rect.size != Vector2(clamped):
		rect.size = Vector2(clamped)


func has_uniform(uname: String) -> bool:
	return uniform_types.has(uname)


func output() -> Texture2D:
	return get_texture()


static func coerce(type: int, value: Variant) -> Variant:
	if type == TYPE_FLOAT:
		return _to_float(value)
	if type == TYPE_INT:
		return int(round(_to_float(value)))
	if type == TYPE_BOOL:
		if value is bool:
			return value
		return _to_float(value) >= 0.5
	if type == TYPE_VECTOR2:
		if value is Vector2:
			return value
		if value is Array and (value as Array).size() >= 2:
			return Vector2(float(value[0]), float(value[1]))
		var f: float = _to_float(value)
		return Vector2(f, f)
	if type == TYPE_VECTOR3:
		if value is Vector3:
			return value
		if value is Array and (value as Array).size() >= 3:
			return Vector3(float(value[0]), float(value[1]), float(value[2]))
		var f3: float = _to_float(value)
		return Vector3(f3, f3, f3)
	if type == TYPE_VECTOR4:
		if value is Vector4:
			return value
		if value is Color:
			var c: Color = value
			return Vector4(c.r, c.g, c.b, c.a)
		if value is Array and (value as Array).size() >= 4:
			return Vector4(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
		if value is Array and (value as Array).size() == 3:
			return Vector4(float(value[0]), float(value[1]), float(value[2]), 1.0)
		var f4: float = _to_float(value)
		return Vector4(f4, f4, f4, f4)
	if type == TYPE_COLOR:
		if value is Color:
			return value
		if value is Array and (value as Array).size() >= 4:
			return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
		if value is Array and (value as Array).size() == 3:
			return Color(float(value[0]), float(value[1]), float(value[2]), 1.0)
		var fc: float = _to_float(value)
		return Color(fc, fc, fc, 1.0)
	if type == TYPE_OBJECT:
		if value is Texture2D:
			return value
		return null
	return value


static func _to_float(value: Variant) -> float:
	if value is float or value is int:
		return float(value)
	if value is bool:
		return 1.0 if value else 0.0
	if value is Array and not (value as Array).is_empty():
		return float((value as Array)[0])
	return 0.0


func param_value(uname: String) -> Variant:
	if mat == null:
		return null
	return mat.get_shader_parameter(uname)


func set_param(uname: String, value: Variant) -> void:
	if mat == null or not uniform_types.has(uname):
		return
	var type: int = int(uniform_types[uname])
	var v: Variant = coerce(type, value)
	if type == TYPE_OBJECT and v == null:
		return
	mat.set_shader_parameter(uname, v)

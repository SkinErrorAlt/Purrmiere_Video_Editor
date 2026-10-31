extends Control

const PmUI := preload("res://ui/kit/pm_ui.gd")

var open: bool = true
var inner: VBoxContainer = null
var _veil: ColorRect = null
var _tween: Tween = null
var _shown: float = 1.0
static var _veil_shader: Shader = null


static func make(open_: bool = true) -> Control:
	var script: GDScript = load("res://ui/kit/pm_slide.gd")
	var s: Control = script.new()
	s.set("open", open_)
	return s


static func veil_shader() -> Shader:
	if _veil_shader == null:
		_veil_shader = Shader.new()
		_veil_shader.code = "shader_type canvas_item;\nuniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);\nuniform float strength = 0.0;\nvoid fragment() {\n\tCOLOR = vec4(tint.rgb, clamp((1.0 - UV.y) * strength, 0.0, 1.0));\n}\n"
	return _veil_shader


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner = PmUI.vbox(0)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.set_anchors_preset(Control.PRESET_TOP_LEFT)
	inner.minimum_size_changed.connect(_on_inner_min_changed)
	add_child(inner)
	_veil = ColorRect.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.visible = false
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = veil_shader()
	_veil.material = mat
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	resized.connect(_sync_inner)


func _ready() -> void:
	_shown = 1.0 if open else 0.0
	_set_shown(_shown)


func _full_height() -> float:
	return inner.get_combined_minimum_size().y


func _sync_inner() -> void:
	var want: Vector2 = Vector2(size.x, _full_height())
	if inner.size != want:
		inner.size = want


func _on_inner_min_changed() -> void:
	_sync_inner()
	if _tween == null or not _tween.is_valid():
		custom_minimum_size.y = _full_height() if open else 0.0


func set_open(v: bool, animate: bool = true) -> void:
	if open == v and (_tween == null or not _tween.is_valid()):
		return
	open = v
	if _tween != null and _tween.is_valid():
		_tween.kill()
		_tween = null
	var dur: float = Tk.dur("fast") if animate and is_inside_tree() else 0.0
	if dur <= 0.0:
		_shown = 1.0 if open else 0.0
		_set_shown(_shown)
		_veil.visible = false
		return
	_veil.visible = true
	inner.visible = true
	(_veil.material as ShaderMaterial).set_shader_parameter("tint", Tk.c["bg_panel"])
	_tween = Tk.ease(create_tween())
	_tween.tween_method(_set_shown, _shown, 1.0 if open else 0.0, dur)
	_tween.tween_callback(_on_done)


func _set_shown(k: float) -> void:
	_shown = k
	var full: float = _full_height()
	_sync_inner()
	custom_minimum_size.y = full * k
	inner.position.y = -(full * (1.0 - k)) * 0.35
	if _tween == null or not _tween.is_valid():
		inner.visible = k > 0.001
	(_veil.material as ShaderMaterial).set_shader_parameter("strength", (1.0 - k) * 1.4)


func _on_done() -> void:
	_tween = null
	_veil.visible = false
	_set_shown(1.0 if open else 0.0)
	inner.position.y = 0.0

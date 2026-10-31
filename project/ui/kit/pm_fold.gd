extends VBoxContainer

signal toggled(open: bool)

const PmButton := preload("res://ui/kit/pm_button.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmIcon := preload("res://ui/kit/pm_icon.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmWrapRow := preload("res://ui/kit/pm_wrap_row.gd")
const PREF_PREFIX := "ui.fold."

var key: String = ""
var open: bool = true
var title: String = "":
	set(v):
		title = v
		if _title_label != null:
			_title_label.text = v
var header: Button = null
var right: HFlowContainer = null
var body: VBoxContainer = null
var _chev: Control = null
var _title_label: Label = null
var _row: Container = null
var _clip: Control = null
var _veil: ColorRect = null
var _tween: Tween = null
var _shown: float = 1.0
static var _veil_shader: Shader = null


static func make(title_: String, key_: String = "", open_default: bool = true) -> VBoxContainer:
	var script: GDScript = load("res://ui/kit/pm_fold.gd")
	var f: VBoxContainer = script.new()
	f.set("key", key_)
	f.set("open", open_default)
	f.set("title", title_)
	return f


func _init() -> void:
	add_theme_constant_override("separation", 0)
	header = PmButton.make("")
	header.set("quiet", true)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.pressed.connect(_on_header)
	add_child(header)
	_row = PmWrapRow.make()
	_row.set("wrap_from", 2)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.minimum_size_changed.connect(_sync_header_min)
	header.add_child(_row)
	_chev = PmIcon.make("chev_d", 14.0)
	_row.add_child(_chev)
	_title_label = PmLabel.trim(title, "text_bright")
	_row.add_child(_title_label)
	right = PmUI.flow()
	right.alignment = FlowContainer.ALIGNMENT_END
	right.size_flags_stretch_ratio = 0.001
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(right)
	_clip = Control.new()
	_clip.name = "Clip"
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_PASS
	_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_clip)
	body = PmUI.vbox()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.set_anchors_preset(Control.PRESET_TOP_LEFT)
	body.minimum_size_changed.connect(_on_body_min_changed)
	body.resized.connect(_on_body_resized)
	_clip.resized.connect(_on_clip_resized)
	_clip.add_child(body)
	_veil = ColorRect.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.visible = false
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = veil_shader()
	_veil.material = mat
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clip.add_child(_veil)


static func veil_shader() -> Shader:
	if _veil_shader == null:
		_veil_shader = Shader.new()
		_veil_shader.code = "shader_type canvas_item;\nuniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);\nuniform float strength = 0.0;\nvoid fragment() {\n\tCOLOR = vec4(tint.rgb, clamp((1.0 - UV.y) * strength, 0.0, 1.0));\n}\n"
	return _veil_shader


func _on_body_min_changed() -> void:
	_sync_body_size()
	if _tween == null or not _tween.is_valid():
		_clip.custom_minimum_size.y = _full_height() if open else 0.0


func _on_body_resized() -> void:
	if _tween == null or not _tween.is_valid():
		var want: Vector2 = Vector2(_clip.size.x, body.get_combined_minimum_size().y)
		if absf(body.size.y - want.y) > 0.5 or absf(body.size.x - want.x) > 0.5:
			body.size = want


func _on_clip_resized() -> void:
	_sync_body_size()


func _sync_body_size() -> void:
	var want: Vector2 = Vector2(_clip.size.x, body.get_combined_minimum_size().y)
	if body.size != want:
		body.size = want


func _full_height() -> float:
	return body.get_combined_minimum_size().y


func _ready() -> void:
	_title_label.text = title
	var pad: float = float(Tk.px(Tk.sz("pad")))
	_row.set("separation", float(Tk.px(Tk.sz("gap"))))
	_row.offset_left = pad
	_row.offset_right = -pad
	_sync_header_min()
	if not key.is_empty():
		var pk: String = PREF_PREFIX + key
		if not Prefs.is_registered(pk):
			Prefs.register(pk, open, {"label": "Fold open: " + key, "type": "bool"})
		open = bool(Prefs.get_value(pk))
	_apply(false)


func add_right(c: Control) -> void:
	right.add_child(c)


func _sync_header_min() -> void:
	if header == null or _row == null:
		return
	var pad: float = float(Tk.px(Tk.sz("pad")))
	var need: Vector2 = _row.get_combined_minimum_size()
	var want := Vector2(ceil(need.x + pad * 2.0), maxf(float(Tk.px(Tk.sz("row_h"))) + 4.0, ceil(need.y + 2.0)))
	if not header.custom_minimum_size.is_equal_approx(want):
		header.custom_minimum_size = want


func set_open(v: bool, animate: bool = true) -> void:
	if open == v:
		return
	open = v
	if not key.is_empty():
		Prefs.set_value(PREF_PREFIX + key, open)
	_apply(animate)
	toggled.emit(open)


func toggle() -> void:
	set_open(not open)


func show_open(v: bool) -> void:
	if open == v:
		return
	open = v
	_apply(false)


func _on_header() -> void:
	toggle()


func _apply(animate: bool) -> void:
	_chev.set("name_", "chev_d" if open else "chev_r")
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
	body.visible = true
	(_veil.material as ShaderMaterial).set_shader_parameter("tint", Tk.c["bg_panel"])
	_tween = Tk.ease(create_tween())
	_tween.tween_method(_set_shown, _shown, 1.0 if open else 0.0, dur)
	_tween.tween_callback(_on_anim_done)


func _set_shown(k: float) -> void:
	_shown = k
	var full: float = _full_height()
	_sync_body_size()
	_clip.custom_minimum_size.y = full * k
	body.position.y = -(full * (1.0 - k)) * 0.35
	if _tween == null or not _tween.is_valid():
		body.visible = k > 0.001
	(_veil.material as ShaderMaterial).set_shader_parameter("strength", (1.0 - k) * 1.4)


func _on_anim_done() -> void:
	_tween = null
	_veil.visible = false
	_set_shown(1.0 if open else 0.0)
	body.position.y = 0.0

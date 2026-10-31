extends Button

const Icons := preload("res://ui/kit/icons.gd")
const PmTheme := preload("res://ui/kit/pm_theme.gd")
const PRESS_SCALE := 0.985

signal activated

var icon_name: String = "":
	set(v):
		if v == icon_name:
			return
		icon_name = v
		_restyle()
		queue_redraw()
var icon_px: float = 16.0:
	set(v):
		icon_px = v
		_restyle()
		queue_redraw()
var active: bool = false:
	set(v):
		if v == active:
			return
		active = v
		_restyle()
		queue_redraw()
var quiet: bool = false:
	set(v):
		quiet = v
		if v and variant == "secondary":
			variant = "ghost"
		elif not v and variant == "ghost":
			variant = "secondary"
		_restyle()
var variant: String = "secondary":
	set(v):
		variant = v
		_restyle()
var tool_square: bool = false:
	set(v):
		tool_square = v
		if v and variant == "secondary":
			variant = "ghost"
		_restyle()
var area: String = "":
	set(v):
		area = v
		_restyle()
var elide: bool = false:
	set(v):
		elide = v
		clip_text = v
		text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if v else TextServer.OVERRUN_NO_TRIMMING
		_restyle()
var elide_w: float = 150.0
var _hover: bool = false
var _press_tween: Tween = null
var _base_tip: String = ""
var _written_tip: String = ""
var _auto_min: Vector2 = Vector2(-1.0, -1.0)
var _asked_w: float = 0.0


static func make(text_: String, icon_: String = "", toggle: bool = false) -> Button:
	var script: GDScript = load("res://ui/kit/pm_button.gd")
	var b: Button = script.new()
	b.text = text_
	b.set("icon_name", icon_)
	b.toggle_mode = toggle
	return b


static func primary(text_: String, icon_: String = "") -> Button:
	var b: Button = make(text_, icon_)
	b.set("variant", "primary")
	return b


static func ghost(text_: String, icon_: String = "", toggle: bool = false) -> Button:
	var b: Button = make(text_, icon_, toggle)
	b.set("variant", "ghost")
	return b


static func tool(icon_: String, area_: String = "tools", toggle: bool = false) -> Button:
	var script: GDScript = load("res://ui/kit/pm_button.gd")
	var b: Button = script.new()
	b.set("icon_name", icon_)
	b.set("area", area_)
	b.set("tool_square", true)
	b.toggle_mode = toggle
	return b


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	clip_text = false
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	pressed.connect(_on_pressed)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	toggled.connect(_on_toggled)
	resized.connect(_on_resized)


func _ready() -> void:
	_restyle()


func _enter_tree() -> void:
	if not Tk.tokens_changed.is_connected(_restyle):
		Tk.tokens_changed.connect(_restyle)
	if not Tk.icon_scale_changed.is_connected(_on_icon_scale):
		Tk.icon_scale_changed.connect(_on_icon_scale)
	if is_node_ready():
		_restyle()


func _exit_tree() -> void:
	if Tk.tokens_changed.is_connected(_restyle):
		Tk.tokens_changed.disconnect(_restyle)
	if Tk.icon_scale_changed.is_connected(_on_icon_scale):
		Tk.icon_scale_changed.disconnect(_on_icon_scale)


func _on_icon_scale(changed_area: String) -> void:
	if changed_area == area:
		_restyle()


func _on_resized() -> void:
	pivot_offset = size * 0.5


func _scale() -> float:
	if area.is_empty():
		return 1.0
	return Tk.icon_scale(area)


func _icon_side() -> float:
	if tool_square:
		return float(Tk.px(Tk.sz("tool_icon"))) * _scale()
	return float(Tk.px(icon_px)) * _scale()


func _is_ink() -> bool:
	return active or (toggle_mode and button_pressed)


func _restyle() -> void:
	if not is_inside_tree():
		return
	var has_icon: bool = not icon_name.is_empty()
	var pad_x: float = float(Tk.px(Tk.sz("pad"))) + 4.0
	var pad_y: float = float(Tk.px(Tk.sz("gap")))
	var gutter: float = 0.0
	if has_icon and not text.is_empty():
		gutter = _icon_side() + float(Tk.px(Tk.sz("gap")))
	var radius: float = float(Tk.px(Tk.sz("radius")))
	var look: String = "primary" if _is_ink() else variant
	var boxes: Dictionary = PmTheme.button_boxes(has_icon, gutter, pad_x, pad_y, radius, look)
	begin_bulk_theme_override()
	for state: String in PmTheme.BUTTON_STATES:
		add_theme_stylebox_override(state, boxes[state])
	add_theme_stylebox_override("focus", boxes["focus"])
	add_theme_color_override("font_color", PmTheme.button_text("normal", look))
	add_theme_color_override("font_hover_color", PmTheme.button_text("hover", look))
	add_theme_color_override("font_pressed_color", PmTheme.button_text("pressed", look))
	add_theme_color_override("font_hover_pressed_color", PmTheme.button_text("pressed", look))
	add_theme_color_override("font_disabled_color", PmTheme.button_text("disabled", look))
	add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_body")))
	add_theme_font_override("font", Tk.font("body_semibold" if look == "primary" else "body_medium"))
	end_bulk_theme_override()
	if tool_square:
		var side: float = float(Tk.px(Tk.sz("tool_button"))) * _scale()
		custom_minimum_size = Vector2(side, side)
		for state: String in PmTheme.BUTTON_STATES:
			var sb: StyleBoxFlat = get_theme_stylebox(state)
			sb.content_margin_left = 0.0
			sb.content_margin_right = 0.0
			sb.content_margin_top = 0.0
			sb.content_margin_bottom = 0.0
	elif has_icon and text.is_empty():
		var side: float = float(Tk.px(Tk.sz("button_h")))
		if custom_minimum_size.x > 0.0 and not custom_minimum_size.is_equal_approx(_auto_min):
			_asked_w = custom_minimum_size.x
		var w: float = maxf(_asked_w, _icon_side() + float(Tk.px(4.0))) if _asked_w > 0.0 else side
		custom_minimum_size = Vector2(w, side)
		_auto_min = custom_minimum_size
		if _asked_w > 0.0:
			for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
				var ib: StyleBox = get_theme_stylebox(state)
				ib.content_margin_left = 0.0
				ib.content_margin_right = 0.0
	else:
		custom_minimum_size = Vector2(0, float(Tk.px(Tk.sz("button_h"))))
	elide_fit()
	pivot_offset = size * 0.5
	queue_redraw()


func natural_width() -> float:
	var sb: StyleBox = get_theme_stylebox("normal")
	var m: float = sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0
	var f: Font = get_theme_font("font")
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")).x if f != null else 0.0
	return ceil(w + m)


func elide_fit() -> void:
	if not elide or not is_inside_tree():
		return
	custom_minimum_size.x = minf(natural_width(), float(Tk.px(elide_w)))


func is_elided() -> bool:
	return elide and not text.is_empty() and natural_width() > size.x + 0.5


func _elide_tip() -> void:
	if not elide:
		return
	elide_fit()
	var PmTip: GDScript = load("res://ui/kit/pm_tip.gd")
	var current: String = String(PmTip.call("text_of", self))
	if current != _written_tip:
		_base_tip = current
	var want: String = _base_tip
	if is_elided() and not _base_tip.contains(text):
		want = text if _base_tip.is_empty() else text + "\n" + _base_tip
	_written_tip = want
	if want != current:
		PmTip.call("attach", self, want)


func _on_enter() -> void:
	_hover = true
	queue_redraw()


func _on_exit() -> void:
	_hover = false
	queue_redraw()


func _on_pressed() -> void:
	activated.emit()


func _on_toggled(_on: bool) -> void:
	_restyle()


func _kill_press() -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = null


func _on_down() -> void:
	_kill_press()
	var d: float = Tk.dur("fast")
	if d <= 0.0 or not is_inside_tree():
		return
	pivot_offset = size * 0.5
	_press_tween = Tk.ease(create_tween())
	_press_tween.tween_property(self, "scale", Vector2(PRESS_SCALE, PRESS_SCALE), d * 0.5)


func _on_up() -> void:
	_kill_press()
	var d: float = Tk.dur("fast")
	if d <= 0.0 or not is_inside_tree():
		scale = Vector2.ONE
		return
	_press_tween = Tk.ease(create_tween())
	_press_tween.tween_property(self, "scale", Vector2.ONE, d)


func _icon_tint() -> Color:
	var look: String = "primary" if _is_ink() else variant
	if disabled:
		return PmTheme.button_text("disabled", look)
	if _hover or button_pressed:
		return PmTheme.button_text("hover", look)
	return PmTheme.button_text("normal", look)


func _draw() -> void:
	_elide_tip()
	if not icon_name.is_empty():
		var side: float = _icon_side()
		var pos: Vector2
		if text.is_empty():
			pos = (size - Vector2(side, side)) * 0.5
		else:
			var sb: StyleBox = get_theme_stylebox("normal")
			var left: float = sb.content_margin_left - side - float(Tk.px(Tk.sz("gap")))
			pos = Vector2(maxf(2.0, left), (size.y - side) * 0.5)
		Icons.draw(self, icon_name, Rect2(pos.round(), Vector2(side, side)), _icon_tint())

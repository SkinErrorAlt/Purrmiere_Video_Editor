extends Control

signal closed
signal action(id: String)
signal moved

const PmButton := preload("res://ui/kit/pm_button.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const Icons := preload("res://ui/kit/icons.gd")
const PREF_PREFIX := "ui.window."
const GRIP := 14.0

var title: String = "":
	set(v):
		title = v
		if _title_label != null:
			_title_label.text = v
var key: String = ""
var close_guard: Callable = Callable()
var min_size: Vector2 = Vector2(160.0, 100.0)
var body: Control = null
var _title_bar: Control = null
var _title_label: Label = null
var _actions: HBoxContainer = null
var _close: Button = null
var _grip: Control = null
var _drag_mode: String = ""
var _drag_start: Vector2 = Vector2.ZERO
var _start_rect: Rect2 = Rect2()


static func open(host: Node, title_: String, content: Control, size_: Vector2, key_: String = "") -> Control:
	var script: GDScript = load("res://ui/kit/pm_window.gd")
	var w: Control = script.new()
	w.set("key", key_)
	w.set("title", title_)
	var overlay: Node = PmUI.overlay_for(host)
	if overlay == null:
		overlay = host
	overlay.add_child(w)
	w.size = size_
	if content != null:
		w.call("set_content", content)
	w.call("place_default")
	w.call("raise")
	w.modulate.a = 0.0
	(func() -> void: PmUI.pop_in(w, Tk.dur("medium"), 8.0, 0.98)).call_deferred()
	return w


func _init() -> void:
	name = "PmWindow"
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	gui_input.connect(_on_input)
	_title_bar = Control.new()
	_title_bar.name = "TitleBar"
	_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar.focus_mode = Control.FOCUS_ALL
	_title_bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_title_bar.gui_input.connect(_on_title_input)
	add_child(_title_bar)
	var row: HBoxContainer = PmUI.hbox()
	row.name = "TitleRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_bar.add_child(row)
	_title_label = PmLabel.trim(title, "text_bright")
	_title_label.add_theme_font_override("font", Tk.font("body_semibold"))
	row.add_child(_title_label)
	_actions = PmUI.hbox()
	_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_actions)
	_close = PmButton.make("", "close")
	_close.set("quiet", true)
	_close.pressed.connect(ask_close)
	row.add_child(_close)
	body = Control.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.clip_contents = true
	add_child(body)
	_grip = Control.new()
	_grip.name = "Grip"
	_grip.mouse_filter = Control.MOUSE_FILTER_STOP
	_grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_grip.gui_input.connect(_on_grip_input)
	add_child(_grip)
	resized.connect(_on_resized)


func _ready() -> void:
	_title_label.text = title
	_layout_chrome()
	if is_inside_tree():
		get_viewport().size_changed.connect(clamp_to_viewport)
	_restore()


func _title_h() -> float:
	return float(Tk.px(Tk.sz("row_h"))) + float(Tk.px(Tk.sz("gap"))) * 2.0


func _layout_chrome() -> void:
	var th: float = _title_h()
	var pad: float = float(Tk.px(Tk.sz("pad")))
	_title_bar.position = Vector2(1.0, 1.0)
	_title_bar.size = Vector2(maxf(0.0, size.x - 2.0), th)
	var row: Control = _title_bar.get_child(0)
	row.offset_left = pad
	row.offset_right = -2.0
	body.position = Vector2(1.0, th + 1.0)
	body.size = Vector2(maxf(0.0, size.x - 2.0), maxf(0.0, size.y - th - 2.0))
	var g: float = float(Tk.px(GRIP))
	_grip.position = Vector2(size.x - g - 1.0, size.y - g - 1.0)
	_grip.size = Vector2(g, g)
	queue_redraw()


func _on_resized() -> void:
	_layout_chrome()


func set_content(content: Control) -> void:
	PmUI.clear(body)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(content)


func content() -> Control:
	if body.get_child_count() > 0:
		return body.get_child(0)
	return null


func take_content() -> Control:
	var c: Control = content()
	if c != null:
		body.remove_child(c)
	return c


func add_action(id: String, icon: String, tip: String = "") -> Button:
	var b: Button = PmButton.make("", icon)
	b.set("quiet", true)
	b.pressed.connect(_on_action.bind(id))
	if not tip.is_empty():
		PmUI.tip(b, tip)
	_actions.add_child(b)
	return b


func _on_action(id: String) -> void:
	action.emit(id)


func place_default() -> void:
	if not is_inside_tree():
		return
	var vp: Rect2 = get_viewport_rect()
	position = ((vp.size - size) * 0.5).round()
	clamp_to_viewport()


func place_at(p: Vector2) -> void:
	position = p.round()
	clamp_to_viewport()


func clamp_to_viewport() -> void:
	if not is_inside_tree():
		return
	var vp: Rect2 = get_viewport_rect()
	size.x = clampf(size.x, min_size.x, maxf(min_size.x, vp.size.x))
	size.y = clampf(size.y, min_size.y, maxf(min_size.y, vp.size.y))
	position.x = clampf(position.x, 0.0, maxf(0.0, vp.size.x - size.x))
	position.y = clampf(position.y, 0.0, maxf(0.0, vp.size.y - size.y))


func raise() -> void:
	var parent: Node = get_parent()
	if parent != null:
		parent.move_child(self, parent.get_child_count() - 1)
	_title_bar.grab_focus()


func rect() -> Rect2:
	return Rect2(position, size)


func _pref_key() -> String:
	return PREF_PREFIX + key


func _restore() -> void:
	if key.is_empty():
		return
	var pk: String = _pref_key()
	if not Prefs.is_registered(pk):
		Prefs.register(pk, {}, {"label": "Window rect: " + key, "type": "rect"})
	var d: Variant = Prefs.get_value(pk)
	if typeof(d) != TYPE_DICTIONARY:
		return
	var dd: Dictionary = d
	if dd.has("w") and dd.has("h"):
		size = Vector2(float(dd["w"]), float(dd["h"]))
	if dd.has("x") and dd.has("y"):
		position = Vector2(float(dd["x"]), float(dd["y"]))
	clamp_to_viewport()


func _persist() -> void:
	if key.is_empty():
		return
	var pk: String = _pref_key()
	if not Prefs.is_registered(pk):
		Prefs.register(pk, {}, {"label": "Window rect: " + key, "type": "rect"})
	Prefs.set_value(pk, {"x": position.x, "y": position.y, "w": size.x, "h": size.y})


func ask_close() -> void:
	if close_guard.is_valid() and not bool(close_guard.call()):
		return
	close()


func close() -> void:
	_persist()
	closed.emit()
	PmUI.free_node(self)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
			raise()


func _on_title_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and k.keycode == KEY_ESCAPE:
			_title_bar.accept_event()
			ask_close()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			raise()
			_drag_mode = "move"
			_drag_start = get_global_mouse_position()
			_start_rect = rect()
		else:
			if _drag_mode == "move":
				_drag_mode = ""
				_persist()
				moved.emit()
		_title_bar.accept_event()
		return
	if event is InputEventMouseMotion and _drag_mode == "move":
		var delta: Vector2 = get_global_mouse_position() - _drag_start
		position = (_start_rect.position + delta).round()
		clamp_to_viewport()
		_title_bar.accept_event()


func _on_grip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			raise()
			_drag_mode = "resize"
			_drag_start = get_global_mouse_position()
			_start_rect = rect()
		else:
			if _drag_mode == "resize":
				_drag_mode = ""
				_persist()
				moved.emit()
		_grip.accept_event()
		return
	if event is InputEventMouseMotion and _drag_mode == "resize":
		var delta: Vector2 = get_global_mouse_position() - _drag_start
		size = (_start_rect.size + delta).max(min_size).round()
		clamp_to_viewport()
		_grip.accept_event()


func _draw() -> void:
	var radius: int = Tk.px(Tk.sz("radius_panel"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tk.c["bg_panel"]
	sb.border_color = Tk.c["border_soft"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	sb.shadow_color = Tk.c["shadow"]
	sb.shadow_size = Tk.px(12.0)
	sb.shadow_offset = Vector2(0.0, float(Tk.px(4.0)))
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var head := StyleBoxFlat.new()
	head.bg_color = Tk.c["bg_panel_alt"]
	head.corner_radius_top_left = radius - 1
	head.corner_radius_top_right = radius - 1
	head.anti_aliasing = true
	draw_style_box(head, Rect2(1.0, 1.0, size.x - 2.0, _title_h()))
	draw_rect(Rect2(1.0, _title_h() + 1.0, size.x - 2.0, 1.0), Tk.c["border"], true)
	var g: float = float(Tk.px(GRIP))
	var o: Vector2 = Vector2(size.x - 3.0, size.y - 3.0)
	var col: Color = Tk.c["text_faint"]
	draw_line(Vector2(o.x - g * 0.7, o.y), Vector2(o.x, o.y - g * 0.7), col, 1.0)
	draw_line(Vector2(o.x - g * 0.4, o.y), Vector2(o.x, o.y - g * 0.4), col, 1.0)

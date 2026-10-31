extends Control

signal closed

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const MODAL_GROUP := "pm_modal"
const SELF_PATH := "res://modules/core_panels/sheet.gd"

var card: PanelContainer = null
var col: VBoxContainer = null
var title_label: Label = null
var buttons: HBoxContainer = null
var close_on_veil: bool = false
var inner_w: float = 0.0
var _dim: ColorRect = null
var _closing: bool = false


static func open(host: Node, title_: String, width: float, height: float = 0.0, top: float = -1.0) -> Control:
	var script: GDScript = load(SELF_PATH)
	var s: Control = script.new()
	s.call("build", title_, width, height, top)
	var overlay: Node = PmUI.overlay_for(host)
	if overlay == null:
		overlay = host
	if overlay == null:
		return s
	overlay.add_child(s)
	s.call("enter")
	return s


static func is_open() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	return (loop as SceneTree).get_first_node_in_group(MODAL_GROUP) != null


static func close_all() -> void:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	for n: Node in (loop as SceneTree).get_nodes_in_group(MODAL_GROUP):
		if n.has_method("close"):
			n.call("close")


func _init() -> void:
	name = "SystemSheet"
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	add_to_group(MODAL_GROUP)


func build(title_: String, width: float, height: float, top: float) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim = PmUI.fill("veil")
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_input)
	add_child(_dim)
	card = PmUI.panel("bg_panel")
	card.name = "Card"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb: StyleBoxFlat = card.get_theme_stylebox("panel")
	sb.border_color = Tk.c["border_soft"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(Tk.px(Tk.sz("radius_panel")) + 1)
	sb.anti_aliasing = true
	sb.shadow_color = Tk.c["shadow"]
	sb.shadow_size = Tk.px(14.0)
	sb.shadow_offset = Vector2(0.0, float(Tk.px(4.0)))
	var pad: float = float(Tk.px(Tk.sz("pad"))) * 2.5
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	var w: float = float(Tk.px(width))
	var h: float = float(Tk.px(height)) if height > 0.0 else 0.0
	inner_w = maxf(w - pad * 2.0 - 2.0, 40.0)
	card.custom_minimum_size = Vector2(w, h)
	if top >= 0.0:
		card.set_anchors_preset(Control.PRESET_CENTER_TOP)
		card.grow_horizontal = Control.GROW_DIRECTION_BOTH
		card.grow_vertical = Control.GROW_DIRECTION_END
		card.offset_left = -w * 0.5
		card.offset_right = w * 0.5
		card.offset_top = float(Tk.px(top))
		card.offset_bottom = float(Tk.px(top)) + h
	else:
		card.set_anchors_preset(Control.PRESET_CENTER)
		card.grow_horizontal = Control.GROW_DIRECTION_BOTH
		card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(card)
	col = PmUI.vbox(Tk.px(Tk.sz("pad")))
	card.add_child(col)
	title_label = PmLabel.headline(title_)
	col.add_child(title_label)


func enter() -> void:
	PmUI.set_shown(_dim, true, Tk.dur("medium"))
	card.modulate.a = 0.0
	_pop_card.call_deferred()


func _pop_card() -> void:
	if is_instance_valid(card) and card.is_inside_tree():
		PmUI.pop_in(card, Tk.dur("medium"), 10.0, 0.98)
	elif is_instance_valid(card):
		card.modulate.a = 1.0


func add_note(text: String, colour_token: String = "text_dim") -> Label:
	var l: Label = PmLabel.wrap(text, colour_token)
	l.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_small")))
	l.custom_minimum_size.x = inner_w
	col.add_child(l)
	return l


func add_buttons() -> HBoxContainer:
	if buttons != null:
		return buttons
	buttons = PmUI.hbox()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(buttons)
	return buttons


func add_button(text: String, primary: bool = false, icon: String = "") -> Button:
	var row: HBoxContainer = add_buttons()
	var b: Button = PmButton.primary(text, icon) if primary else PmButton.make(text, icon)
	row.add_child(b)
	return b


func add_spacer() -> Control:
	var s: Control = PmUI.spacer(false)
	col.add_child(s)
	return s


func is_closing() -> bool:
	return _closing


func close() -> void:
	if _closing:
		return
	_closing = true
	remove_from_group(MODAL_GROUP)
	closed.emit()
	PmUI.free_node(self)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_dim.accept_event()
			if close_on_veil:
				close()


func _unhandled_key_input(event: InputEvent) -> void:
	if _closing or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.pressed and k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

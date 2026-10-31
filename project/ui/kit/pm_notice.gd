extends Control

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmTheme := preload("res://ui/kit/pm_theme.gd")
const GROUP := "pm_notices"
const MARGIN := 16.0
const MAX_CARDS := 4

var _stack: VBoxContainer = null


static func host_for(node: Node) -> Control:
	if node == null or not node.is_inside_tree():
		return null
	var found: Node = node.get_tree().get_first_node_in_group(GROUP)
	if found is Control:
		return found
	var overlay: Node = PmUI.overlay_for(node)
	if overlay == null:
		return null
	var script: GDScript = load("res://ui/kit/pm_notice.gd")
	var host: Control = script.new()
	overlay.add_child(host)
	return host


static func post(node: Node, entry: Dictionary) -> void:
	var host: Control = host_for(node)
	if host != null:
		host.call("push", entry)


func _init() -> void:
	name = "PmNotices"
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stack = PmUI.vbox(Tk.px(8.0))
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.alignment = BoxContainer.ALIGNMENT_END
	_stack.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_stack.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_stack.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_stack.offset_left = -float(Tk.px(360.0)) - MARGIN
	_stack.offset_right = -MARGIN
	_stack.offset_top = -MARGIN - float(Tk.px(40.0))
	_stack.offset_bottom = -MARGIN - float(Tk.px(28.0))
	add_child(_stack)


func push(entry: Dictionary) -> void:
	while _stack.get_child_count() >= MAX_CARDS:
		var old: Node = _stack.get_child(0)
		_stack.remove_child(old)
		old.queue_free()
	var card: Control = _Card.new()
	_stack.add_child(card)
	_stack.move_child(card, _stack.get_child_count() - 1)
	card.call("setup", entry)


class _Card:
	extends PanelContainer

	var _entry: Dictionary = {}
	var _timer: Timer = null
	var _hovered: bool = false

	func setup(entry: Dictionary) -> void:
		_entry = entry
		mouse_filter = Control.MOUSE_FILTER_STOP
		var sb := StyleBoxFlat.new()
		sb.bg_color = Tk.c["bg_panel_high"]
		sb.border_color = Tk.c["border"]
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(Tk.px(Tk.sz("radius_menu")))
		var pad: float = float(Tk.px(Tk.sz("pad")))
		sb.content_margin_left = pad + 4.0
		sb.content_margin_right = pad + 4.0
		sb.content_margin_top = pad
		sb.content_margin_bottom = pad
		add_theme_stylebox_override("panel", PmTheme.shadowed(sb, 1.0))
		custom_minimum_size.x = float(Tk.px(360.0))
		var col: VBoxContainer = PmUI.vbox(Tk.px(6.0))
		add_child(col)
		var top: HBoxContainer = PmUI.hbox(Tk.px(8.0))
		col.add_child(top)
		var text: Label = PmLabel.wrap(String(entry.get("text", "")), "text_bright")
		top.add_child(text)
		var close: Button = PmButton.make("", "close")
		close.set("quiet", true)
		close.pressed.connect(dismiss)
		top.add_child(close)
		var detail: String = String(entry.get("detail", ""))
		if not detail.is_empty():
			var d: Label = PmLabel.wrap(detail, "text_dim")
			col.add_child(d)
		var actions: Array = entry.get("actions", [])
		if not actions.is_empty():
			var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
			row.alignment = BoxContainer.ALIGNMENT_END
			col.add_child(row)
			for a: Variant in actions:
				if not (a is Dictionary):
					continue
				var ad: Dictionary = a
				var b: Button = PmButton.make(String(ad.get("label", "")), String(ad.get("icon", "")))
				b.set("quiet", not bool(ad.get("primary", false)))
				b.pressed.connect(_on_action.bind(ad))
				row.add_child(b)
		gui_input.connect(_on_input)
		mouse_entered.connect(func() -> void: _hovered = true)
		mouse_exited.connect(func() -> void: _hovered = false)
		var seconds: float = float(entry.get("seconds", 3.0))
		if seconds > 0.0:
			_timer = Timer.new()
			_timer.wait_time = seconds
			_timer.one_shot = true
			_timer.timeout.connect(_on_timeout)
			add_child(_timer)
			if is_inside_tree():
				_timer.start()
			else:
				_timer.autostart = true
		modulate.a = 0.0
		if is_inside_tree():
			var tw: Tween = create_tween()
			tw.tween_property(self, "modulate:a", 1.0, maxf(Tk.dur("toast"), 0.01))
		else:
			modulate.a = 1.0

	func _on_timeout() -> void:
		if _hovered:
			_timer.start(1.0)
			return
		dismiss()

	func _on_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var actions: Array = _entry.get("actions", [])
			for a: Variant in actions:
				if a is Dictionary and bool((a as Dictionary).get("primary", false)):
					_on_action(a)
					accept_event()
					return
			if not actions.is_empty() and actions[0] is Dictionary:
				_on_action(actions[0])
			accept_event()

	func _on_action(a: Dictionary) -> void:
		var cb: Variant = a.get("call", null)
		if cb is Callable and (cb as Callable).is_valid():
			(cb as Callable).call()
		dismiss()

	func dismiss() -> void:
		if not is_inside_tree():
			return
		var parent: Node = get_parent()
		if parent != null:
			parent.remove_child(self)
		queue_free()

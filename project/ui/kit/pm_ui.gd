extends RefCounted

const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmTip := preload("res://ui/kit/pm_tip.gd")
const OVERLAY_GROUP := "pm_overlay"
const WINDOW_OVERLAY_META := "pm_window_overlay"
const WINDOW_TIP_META := "pm_window_tip_node"


static func tip(control: Control, text: String, keys: String = "") -> void:
	PmTip.attach(control, text, keys)


static func clear(holder: Node) -> void:
	if holder == null:
		return
	for child: Node in holder.get_children():
		holder.remove_child(child)
		child.queue_free()


static func free_node(node: Node) -> void:
	if node == null:
		return
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.queue_free()


static func _can_rise(node: CanvasItem) -> bool:
	if not (node is Control):
		return false
	var parent: Node = node.get_parent()
	return parent != null and not (parent is Container)


static func _restore_rise(node: CanvasItem) -> void:
	if node.has_meta("pm_rise_base"):
		var base: Vector2 = node.get_meta("pm_rise_base")
		node.remove_meta("pm_rise_base")
		if is_instance_valid(node) and node is Control:
			(node as Control).position = base


static func scroll_of(node: Node) -> ScrollContainer:
	var n: Node = node
	while n != null:
		if n is ScrollContainer:
			return n
		n = n.get_parent()
	return null


static func keep_scroll(list: Node) -> void:
	var scroll: ScrollContainer = scroll_of(list)
	if scroll == null or not scroll.is_inside_tree():
		return
	var y: int = scroll.scroll_vertical
	var x: int = scroll.scroll_horizontal
	if y == 0 and x == 0:
		return
	restore_scroll(scroll, y, x)


static func restore_scroll(scroll: ScrollContainer, y: int, x: int = -1) -> void:
	if scroll == null or not scroll.is_inside_tree():
		return
	scroll.scroll_vertical = y
	if x >= 0:
		scroll.scroll_horizontal = x
	var tree: SceneTree = scroll.get_tree()
	if tree == null:
		return
	tree.process_frame.connect(func() -> void:
		if is_instance_valid(scroll):
			scroll.scroll_vertical = y
			if x >= 0:
				scroll.scroll_horizontal = x
	, CONNECT_ONE_SHOT)


static func set_shown(node: CanvasItem, shown: bool, dur: float = -1.0, rise: float = 0.0) -> void:
	if node == null:
		return
	var d: float = dur if dur >= 0.0 else Tk.dur("fast")
	if node.has_meta("pm_fade"):
		var old: Variant = node.get_meta("pm_fade")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
		node.remove_meta("pm_fade")
		_restore_rise(node)
	if shown:
		if not node.visible or node.modulate.a < 1.0:
			if d <= 0.0 or not node.is_inside_tree():
				node.visible = true
				node.modulate.a = 1.0
				return
			node.modulate.a = 0.0
			node.visible = true
			var tw: Tween = Tk.ease(node.create_tween())
			tw.set_parallel(true)
			tw.tween_property(node, "modulate:a", 1.0, d)
			if rise != 0.0 and _can_rise(node):
				var ctl: Control = node
				var base: Vector2 = ctl.position
				node.set_meta("pm_rise_base", base)
				ctl.position = base + Vector2(0.0, rise)
				tw.tween_property(ctl, "position", base, d)
				tw.chain().tween_callback(_restore_rise.bind(node))
			node.set_meta("pm_fade", tw)
	else:
		if not node.visible:
			return
		if d <= 0.0 or not node.is_inside_tree():
			node.visible = false
			node.modulate.a = 1.0
			return
		var tw: Tween = Tk.ease(node.create_tween())
		tw.tween_property(node, "modulate:a", 0.0, d)
		tw.tween_callback(_hide_after.bind(node))
		node.set_meta("pm_fade", tw)


static func _hide_after(node: CanvasItem) -> void:
	if is_instance_valid(node):
		node.visible = false
		node.modulate.a = 1.0


static func pop_in(node: CanvasItem, dur: float = -1.0, drop: float = -7.0, from_scale: float = 0.97) -> void:
	if node == null or not node.is_inside_tree():
		return
	var d: float = dur if dur >= 0.0 else Tk.dur("medium")
	if d <= 0.0:
		node.modulate.a = 1.0
		return
	node.modulate.a = 0.0
	var tw: Tween = Tk.ease(node.create_tween())
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, d)
	if node is Control:
		var ctl: Control = node
		ctl.pivot_offset = Vector2(ctl.size.x * 0.5, 0.0)
		ctl.scale = Vector2(from_scale, from_scale)
		tw.tween_property(ctl, "scale", Vector2.ONE, d)
		if _can_rise(node) and drop != 0.0:
			var base: Vector2 = ctl.position
			ctl.position = base + Vector2(0.0, drop)
			tw.tween_property(ctl, "position", base, d)


static func overlay_for(node: Node) -> Node:
	if node == null or not node.is_inside_tree():
		return null
	var own: Node = window_node(node, WINDOW_OVERLAY_META)
	if own != null:
		return own
	var tree: SceneTree = node.get_tree()
	var found: Node = tree.get_first_node_in_group(OVERLAY_GROUP)
	if found != null:
		return found
	return tree.root


static func window_node(node: Node, meta: String) -> Node:
	if node == null or not node.is_inside_tree():
		return null
	var w: Window = node.get_window()
	if w == null or not w.has_meta(meta):
		return null
	var o: Variant = w.get_meta(meta)
	if is_instance_valid(o) and o is Node and (o as Node).is_inside_tree():
		return o
	return null


static func hbox(sep: int = -1) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep if sep >= 0 else Tk.px(Tk.sz("gap")))
	return h


static func vbox(sep: int = -1) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep if sep >= 0 else Tk.px(Tk.sz("gap")))
	return v


static func inset(child: Control, top: float = 0.0, bottom: float = 0.0) -> MarginContainer:
	var m := MarginContainer.new()
	m.name = "Inset"
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad: int = Tk.px(Tk.sz("pad"))
	m.add_theme_constant_override("margin_left", pad)
	m.add_theme_constant_override("margin_right", pad)
	m.add_theme_constant_override("margin_top", Tk.px(top))
	m.add_theme_constant_override("margin_bottom", Tk.px(bottom))
	if child != null:
		m.size_flags_horizontal = child.size_flags_horizontal
		m.size_flags_vertical = child.size_flags_vertical
		m.size_flags_stretch_ratio = child.size_flags_stretch_ratio
		m.visible = child.visible
		child.visibility_changed.connect(func() -> void:
			if is_instance_valid(m) and is_instance_valid(child):
				m.visible = child.visible)
		m.add_child(child)
	return m


static func flow(h_sep: int = -1, v_sep: int = -1) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", h_sep if h_sep >= 0 else Tk.px(Tk.sz("gap")))
	f.add_theme_constant_override("v_separation", v_sep if v_sep >= 0 else Tk.px(Tk.sz("gap")))
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f


static func wrap_button(b: Button, min_w: float = 120.0) -> Button:
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.x = float(Tk.px(min_w))
	return b


static func spacer(h: bool = true) -> Control:
	var s := Control.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if h:
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


static func divider(vertical: bool = false) -> Control:
	var d := ColorRect.new()
	d.color = Tk.c["border"]
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical:
		d.custom_minimum_size = Vector2(1, 0)
		d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		d.custom_minimum_size = Vector2(0, 1)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return d


static func panel(colour_token: String = "bg_panel") -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tk.c[colour_token]
	var pad: float = float(Tk.px(Tk.sz("pad")))
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	p.add_theme_stylebox_override("panel", sb)
	return p


static func fill(colour_token: String) -> ColorRect:
	var r := ColorRect.new()
	r.color = Tk.c[colour_token]
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func line_edit(placeholder: String = "", text: String = "") -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.text = text
	le.custom_minimum_size = Vector2(placeholder_room(placeholder), float(Tk.px(Tk.sz("field_h"))))
	le.context_menu_enabled = false
	return le


static func placeholder_room(placeholder: String) -> float:
	if placeholder.is_empty():
		return 0.0
	var fs: int = Tk.fs(Tk.sz("font_body"))
	var w: float = Tk.font("body").get_string_size(placeholder, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var margins: float = (float(Tk.px(Tk.sz("pad"))) + 2.0) * 2.0 + 4.0
	return minf(ceil(w + margins), float(Tk.px(160.0)))


static func empty_state(text: String, detail: String = "") -> Control:
	var v: VBoxContainer = vbox()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var l: Label = PmLabel.dim(text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(l)
	if not detail.is_empty():
		var d: Label = PmLabel.faint(detail)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(d)
	return v


static func _sheet_root(host: Node, title: String) -> Dictionary:
	var overlay: Node = overlay_for(host)
	var catcher := Control.new()
	catcher.name = "Sheet"
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = fill("veil")
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.add_child(dim)
	var card: PanelContainer = panel("bg_panel")
	var sb: StyleBoxFlat = card.get_theme_stylebox("panel")
	sb.border_color = Tk.c["border_soft"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(Tk.px(Tk.sz("radius_panel")))
	sb.anti_aliasing = true
	sb.shadow_color = Tk.c["shadow"]
	sb.shadow_size = Tk.px(14.0)
	sb.shadow_offset = Vector2(0.0, float(Tk.px(4.0)))
	var pad: float = float(Tk.px(Tk.sz("pad"))) * 2.5
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	card.custom_minimum_size = Vector2(float(Tk.px(360.0)), 0)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	catcher.add_child(card)
	var col: VBoxContainer = vbox(Tk.px(Tk.sz("pad")))
	card.add_child(col)
	col.add_child(PmLabel.headline(title))
	overlay.add_child(catcher)
	set_shown(dim, true, Tk.dur("medium"))
	card.modulate.a = 0.0
	(func() -> void: pop_in(card, Tk.dur("medium"), 10.0, 0.98)).call_deferred()
	return {"catcher": catcher, "card": card, "col": col}


static func _button_row(col: VBoxContainer, ok: String, cancel: String, on_ok: Callable, on_cancel: Callable) -> void:
	var row: HBoxContainer = hbox()
	row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row)
	if not cancel.is_empty():
		var cb: Button = PmButton.make(cancel)
		cb.pressed.connect(on_cancel)
		row.add_child(cb)
	var ob: Button = PmButton.primary(ok)
	ob.pressed.connect(on_ok)
	row.add_child(ob)


static func confirm(host: Node, title: String, text: String, ok: String = "OK", cancel: String = "Cancel") -> Signal:
	var parts: Dictionary = _sheet_root(host, title)
	var catcher: Control = parts["catcher"]
	var col: VBoxContainer = parts["col"]
	var body: Label = PmLabel.wrap(text)
	col.add_child(body)
	var relay := _SheetRelay.new()
	relay.catcher = catcher
	catcher.add_child(relay)
	_button_row(col, ok, cancel, relay.answer_ok.bind(catcher), relay.answer_cancel.bind(catcher))
	return relay.answered


static func choose(host: Node, title: String, text: String, choices: Array) -> Signal:
	var parts: Dictionary = _sheet_root(host, title)
	var catcher: Control = parts["catcher"]
	var col: VBoxContainer = parts["col"]
	var body: Label = PmLabel.wrap(text)
	col.add_child(body)
	var relay := _SheetRelay.new()
	relay.catcher = catcher
	catcher.add_child(relay)
	var row: HBoxContainer = hbox()
	row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row)
	for i: int in choices.size():
		var ch: Dictionary = choices[i]
		var id: String = String(ch.get("id", str(i)))
		var b: Button = PmButton.primary(String(ch.get("label", id))) if bool(ch.get("primary", false)) else PmButton.make(String(ch.get("label", id)))
		b.pressed.connect(relay.answer_id.bind(id, catcher))
		row.add_child(b)
	return relay.answered


static func form(host: Node, title: String, fields: Array[Dictionary], ok: String = "OK", cancel: String = "Cancel") -> Signal:
	var parts: Dictionary = _sheet_root(host, title)
	var catcher: Control = parts["catcher"]
	var col: VBoxContainer = parts["col"]
	var grid := GridContainer.new()
	grid.columns = 2
	col.add_child(grid)
	var editors: Dictionary = {}
	for f: Dictionary in fields:
		var key: String = String(f.get("key", ""))
		var label: String = String(f.get("label", key))
		var kind: String = String(f.get("type", "string"))
		var value: Variant = f.get("default", "")
		if kind == "note":
			var note: Label = PmLabel.dim(String(value))
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size.x = float(Tk.px(320.0))
			var pad: Control = Control.new()
			pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(pad)
			grid.add_child(note)
			continue
		grid.add_child(PmLabel.body(label))
		if kind == "bool":
			var cb := CheckBox.new()
			cb.button_pressed = bool(value)
			cb.focus_mode = Control.FOCUS_NONE
			grid.add_child(cb)
			editors[key] = cb
		elif kind == "enum":
			var ob := OptionButton.new()
			ob.focus_mode = Control.FOCUS_NONE
			var choices: Array = f.get("choices", [])
			for i: int in range(choices.size()):
				ob.add_item(String(choices[i]), i)
			ob.select(int(value) if typeof(value) == TYPE_INT else 0)
			grid.add_child(ob)
			editors[key] = ob
		else:
			var le: LineEdit = line_edit("", str(value))
			le.custom_minimum_size.x = float(Tk.px(200.0))
			grid.add_child(le)
			editors[key] = le
	var relay := _SheetRelay.new()
	relay.catcher = catcher
	relay.form_editors = editors
	relay.form_fields = fields
	relay.is_form = true
	catcher.add_child(relay)
	_button_row(col, ok, cancel, relay.answer_form.bind(catcher), relay.answer_form_cancel.bind(catcher))
	return relay.answered


class _SheetRelay:
	extends Node

	signal answered(result: Variant)

	var form_editors: Dictionary = {}
	var form_fields: Array[Dictionary] = []
	var catcher: Control = null
	var is_form: bool = false
	var _done: bool = false

	func _finish(result: Variant, catcher: Control) -> void:
		if _done:
			return
		_done = true
		answered.emit(result)
		var parent: Node = catcher.get_parent()
		if parent != null:
			parent.remove_child(catcher)
		catcher.queue_free()

	func answer_ok(catcher: Control) -> void:
		_finish(true, catcher)

	func answer_cancel(catcher: Control) -> void:
		_finish(false, catcher)

	func answer_id(id: String, catcher: Control) -> void:
		_finish(id, catcher)

	func answer_form(catcher: Control) -> void:
		var out: Dictionary = {}
		for f: Dictionary in form_fields:
			var key: String = String(f.get("key", ""))
			var kind: String = String(f.get("type", "string"))
			var ed: Variant = form_editors.get(key, null)
			if ed == null:
				continue
			if kind == "bool":
				out[key] = (ed as CheckBox).button_pressed
			elif kind == "enum":
				out[key] = (ed as OptionButton).selected
			elif kind == "float":
				out[key] = float((ed as LineEdit).text)
			elif kind == "int":
				out[key] = int((ed as LineEdit).text)
			else:
				out[key] = (ed as LineEdit).text
		_finish(out, catcher)

	func answer_form_cancel(catcher: Control) -> void:
		_finish({}, catcher)

	func _unhandled_key_input(event: InputEvent) -> void:
		if catcher == null:
			return
		if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if is_form:
				_finish({}, catcher)
			else:
				_finish(false, catcher)

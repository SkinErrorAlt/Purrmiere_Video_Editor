extends RefCounted

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const WaveLook := preload("res://ui/timeline/wave_look.gd")
const VeryLoud := preload("res://engine/very_loud.gd")
const TITLE := "Wave look"
const WINDOW_KEY := "waves.window"
const SIZE := Vector2(400.0, 640.0)
const PREVIEW := Vector2(96.0, 34.0)
const ROW_H := 42.0
const FIELD_W := 92.0

static var _window: Control = null
static var opened: int = 0


static func window() -> Control:
	return _window if _window != null and is_instance_valid(_window) and _window.is_inside_tree() else null


static func open(host: Control, at: Vector2 = Vector2(INF, INF)) -> Control:
	if host == null:
		return null
	WaveLook.register_prefs()
	var w: Control = window()
	if w != null:
		refresh()
		w.call("raise")
	else:
		w = PmWindow.open(host, TITLE, build(), Vector2(float(Tk.px(SIZE.x)), float(Tk.px(SIZE.y))), WINDOW_KEY)
		_window = w
	if at.x < INF and at.y < INF and w != null:
		w.call("place_at", at + Vector2(8.0, 8.0))
	opened += 1
	return w


static func close() -> void:
	var w: Control = window()
	if w != null:
		w.call("close")
	_window = null


static func refresh() -> void:
	var w: Control = window()
	if w == null:
		return
	var old: Variant = w.call("content")
	var keep: int = (old as ScrollContainer).scroll_vertical if old is ScrollContainer else 0
	var fresh: Control = build()
	w.call("set_content", fresh)
	if keep > 0 and fresh is ScrollContainer:
		PmUI.restore_scroll(fresh as ScrollContainer, keep)


static func _value(key: String, fallback: Variant) -> Variant:
	if not Prefs.is_registered(key):
		return fallback
	return Prefs.get_value(key)


static func build() -> Control:
	var sc: ScrollContainer = load("res://ui/kit/pm_scroll_keep.gd").new()
	sc.name = "WaveLookSheet"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, Tk.px(10.0))
	margin.add_theme_constant_override("margin_top", Tk.px(6.0))
	margin.add_theme_constant_override("margin_bottom", Tk.px(10.0))
	sc.add_child(margin)
	var col: VBoxContainer = PmUI.vbox(Tk.px(4.0))
	col.name = "Rows"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(col)
	col.add_child(_meta("Style"))
	var chosen: String = String(_value(WaveLook.PREF_STYLE, WaveLook.STYLE_MIRRORED))
	for st: String in WaveLook.STYLES:
		col.add_child(_style_row(st, st == chosen))
	col.add_child(_drop_row("Grows from", WaveLook.PREF_GROW, WaveLook.GROWS))
	col.add_child(_meta("Colour"))
	col.add_child(_drop_row("Colour comes from", WaveLook.PREF_COLOUR_FROM, WaveLook.COLOUR_FROMS))
	col.add_child(_colour_row("Custom colour", WaveLook.PREF_COLOUR))
	col.add_child(_field_row("Opacity", WaveLook.PREF_OPACITY, 0.1, 1.0, 0.05, ""))
	col.add_child(_colour_row("Gradient top", WaveLook.PREF_GRAD_TOP))
	col.add_child(_colour_row("Gradient bottom", WaveLook.PREF_GRAD_BOTTOM))
	col.add_child(_meta("Shape"))
	col.add_child(_check_row("Show the average loudness (RMS) inside", WaveLook.PREF_RMS))
	col.add_child(_field_row("Smoothing", WaveLook.PREF_SMOOTH, 0.0, 1.0, 0.05, ""))
	col.add_child(_field_row("Bar width", WaveLook.PREF_BAR_W, 1.0, 24.0, 1.0, " px"))
	col.add_child(_field_row("Bar gap", WaveLook.PREF_BAR_GAP, 0.0, 12.0, 1.0, " px"))
	col.add_child(_field_row("Line thickness", WaveLook.PREF_LINE, 0.5, 6.0, 0.5, " px"))
	if Prefs.is_registered(WaveLook.PREF_LOG):
		col.add_child(_check_row("Timeline waves in log dB", WaveLook.PREF_LOG))
	if Prefs.is_registered(WaveLook.PREF_GAIN):
		col.add_child(_field_row("Timeline wave gain", WaveLook.PREF_GAIN, 0.25, 4.0, 0.25, ""))
	col.add_child(_meta("Volume"))
	col.add_child(_check_row("Waves show the volume", WaveLook.PREF_SHOW_VOLUME))
	col.add_child(_meta("Highs and lows"))
	col.add_child(_check_row("Show highs", WaveLook.PREF_HIGHS))
	col.add_child(_field_row("High line", WaveLook.PREF_HIGH_DB, -60.0, 0.0, 1.0, " dB"))
	col.add_child(_colour_row("High colour", WaveLook.PREF_HIGH_COLOUR))
	col.add_child(_check_row("Show lows", WaveLook.PREF_LOWS))
	col.add_child(_field_row("Low line", WaveLook.PREF_LOW_DB, -90.0, -1.0, 1.0, " dB"))
	col.add_child(_colour_row("Low colour", WaveLook.PREF_LOW_COLOUR))
	col.add_child(_check_row("Ease into the colours", WaveLook.PREF_EASE))
	col.add_child(_field_row("Ease over", WaveLook.PREF_EASE_DB, 0.0, 24.0, 0.5, " dB"))
	col.add_child(_meta("Very loud"))
	col.add_child(_check_row("Mark very loud sounds", WaveLook.PREF_VERY_LOUD))
	col.add_child(_field_row("Very loud line", VeryLoud.PREF_DB, VeryLoud.MIN_DB, VeryLoud.MAX_DB, 0.5, " dB"))
	col.add_child(_colour_row("Very loud colour", WaveLook.PREF_VERY_LOUD_COLOUR))
	col.add_child(_drop_row("What happens", VeryLoud.PREF_ACTION, VeryLoud.ACTIONS))
	col.add_child(_drop_row("Judged on", VeryLoud.PREF_JUDGE, VeryLoud.JUDGES))
	col.add_child(_field_row("Turn down by", VeryLoud.PREF_DOWN_DB, 0.0, 60.0, 0.5, " dB"))
	col.add_child(_field_row("Turn down to", VeryLoud.PREF_PERCENT, 0.0, 100.0, 1.0, " %"))
	col.add_child(_field_row("Gradient width", VeryLoud.PREF_GRADIENT_DB, 0.0, 24.0, 0.5, " dB"))
	col.add_child(_field_row("Let go over", VeryLoud.PREF_RELEASE, 1.0, 2000.0, 5.0, " ms"))
	col.add_child(_check_row("Show what is turned down", WaveLook.PREF_SHOW_DUCKED))
	var note: Label = PmLabel.dim("The very loud action changes what you hear and what you export, the same way. Everything quieter than the line is left exactly as it was.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = float(Tk.px(200.0))
	col.add_child(note)
	var tools: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	var reset: Button = PmButton.make("Back to the defaults")
	reset.name = "ResetLook"
	reset.pressed.connect(reset_all)
	tools.add_child(reset)
	col.add_child(tools)
	return sc


static func all_keys() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for spec: Array in WaveLook.pref_specs():
		out.append(String(spec[0]))
	for k: String in [VeryLoud.PREF_DB, VeryLoud.PREF_ACTION, VeryLoud.PREF_JUDGE, VeryLoud.PREF_DOWN_DB, VeryLoud.PREF_PERCENT, VeryLoud.PREF_GRADIENT_DB, VeryLoud.PREF_RELEASE]:
		out.append(k)
	return out


static func reset_all() -> void:
	for k: String in all_keys():
		if Prefs.is_registered(k):
			Prefs.reset(k)
	refresh()


static func _meta(text: String) -> Control:
	var l: Label = PmLabel.meta(text)
	var box: MarginContainer = MarginContainer.new()
	box.add_theme_constant_override("margin_left", Tk.px(6.0))
	box.add_theme_constant_override("margin_top", Tk.px(6.0))
	box.add_child(l)
	return box


static func _row_box(chosen: bool) -> Dictionary:
	var out: Dictionary = {}
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.set_corner_radius_all(Tk.px(Tk.sz("radius_row")))
		var fill: Color = Color(0.0, 0.0, 0.0, 0.0)
		if chosen or state == "pressed":
			fill = Tk.c["glass_strong"]
		elif state == "hover":
			fill = Tk.c["glass"]
		sb.bg_color = fill
		out[state] = sb
	return out


static func _style_row(style: String, chosen: bool) -> Control:
	var b: Button = Button.new()
	b.name = "Style_" + style.replace(" ", "_")
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0.0, float(Tk.px(ROW_H)))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var boxes: Dictionary = _row_box(chosen)
	for state: String in boxes.keys():
		b.add_theme_stylebox_override(state, boxes[state])
	b.pressed.connect(set_style.bind(style))
	PmUI.tip(b, style + ": " + String(WaveLook.STYLE_BLURBS.get(style, "")))
	var row: HBoxContainer = PmUI.hbox(Tk.px(10.0))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = float(Tk.px(6.0))
	row.offset_right = -float(Tk.px(6.0))
	b.add_child(row)
	var pv: Control = _Preview.new()
	pv.name = "Preview"
	pv.set("style", style)
	pv.custom_minimum_size = Vector2(float(Tk.px(PREVIEW.x)), float(Tk.px(PREVIEW.y)))
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pv)
	var name_l: Label = PmLabel.trim(style)
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_l)
	return b


static func set_style(style: String) -> void:
	if Prefs.is_registered(WaveLook.PREF_STYLE):
		Prefs.set_value(WaveLook.PREF_STYLE, style)
	refresh()


static func _label(text: String) -> Label:
	var l: Label = PmLabel.trim(text)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func _short(key: String) -> String:
	return key.get_slice(".", key.get_slice_count(".") - 1)


static func _drop_row(label: String, key: String, choices: PackedStringArray) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(8.0))
	row.add_child(_label(label))
	var items: Array = []
	for c: String in choices:
		items.append(PmDrop.choice(c, c))
	var drop: Button = PmDrop.make_drop(items, String(_value(key, choices[0] if not choices.is_empty() else "")))
	drop.name = "Drop_" + _short(key)
	drop.custom_minimum_size.x = float(Tk.px(170.0))
	drop.connect("changed", _on_choice.bind(key))
	row.add_child(drop)
	return row


static func _on_choice(id: String, key: String) -> void:
	if Prefs.is_registered(key):
		Prefs.set_value(key, id)


static func _check_row(label: String, key: String) -> Control:
	var cb: CheckBox = CheckBox.new()
	cb.name = "Check_" + _short(key)
	cb.text = label
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = bool(_value(key, false))
	cb.toggled.connect(_on_check.bind(key))
	return cb


static func _on_check(on: bool, key: String) -> void:
	if Prefs.is_registered(key):
		Prefs.set_value(key, on)


static func _field_row(label: String, key: String, lo: float, hi: float, step: float, suffix: String) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(8.0))
	row.add_child(_label(label))
	var f: Control = PmField.make(float(_value(key, lo)), lo, hi, step, suffix)
	f.name = "Field_" + _short(key)
	f.custom_minimum_size.x = float(Tk.px(FIELD_W))
	f.set("show_range", true)
	f.connect("value_changed", _on_field.bind(key))
	row.add_child(f)
	return row


static func _on_field(v: float, key: String) -> void:
	if Prefs.is_registered(key):
		Prefs.set_value(key, v)


static func _colour_row(label: String, key: String) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(8.0))
	row.add_child(_label(label))
	var cp: ColorPickerButton = ColorPickerButton.new()
	cp.name = "Colour_" + _short(key)
	cp.color = WaveLook.colour_of(String(_value(key, "#ffffffff")), Color.WHITE)
	cp.edit_alpha = true
	cp.focus_mode = Control.FOCUS_NONE
	cp.custom_minimum_size = Vector2(float(Tk.px(FIELD_W)), float(Tk.px(20.0)))
	cp.color_changed.connect(_on_colour.bind(key))
	row.add_child(cp)
	return row


static func _on_colour(col: Color, key: String) -> void:
	if Prefs.is_registered(key):
		Prefs.set_value(key, "#" + col.to_html(true))


class _Preview:
	extends Control

	const WaveLookKit := preload("res://ui/timeline/wave_look.gd")

	var style: String = "Mirrored"
	var last_mesh: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _ready() -> void:
		WaveLookKit.listen(self)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_lane_audio"], true)
		if size.x < 4.0 or size.y < 4.0:
			return
		var lk: Dictionary = WaveLookKit.with_style(WaveLookKit.look(), style)
		var half: float = size.y * 0.5 - 2.0
		last_mesh = WaveLookKit.mesh(WaveLookKit.sample_pairs(), lk, WaveLookKit.base_colour(lk), WaveLookKit.scale(false, 1.0), size.x, half)
		draw_set_transform(Vector2(0.0, size.y * 0.5), 0.0, Vector2(size.x, half))
		WaveLookKit.draw_mesh(self, last_mesh)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

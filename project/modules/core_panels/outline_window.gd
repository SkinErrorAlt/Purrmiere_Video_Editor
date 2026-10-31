extends RefCounted

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const OutlineStyles := preload("res://modules/core_panels/outline_styles.gd")
const MonitorOutline := preload("res://modules/core_panels/monitor_outline.gd")
const PREF_SHOW := "program.outline.show"
const PREF_THICKNESS := "program.outline.thickness"
const PREVIEW := Vector2(96.0, 40.0)
const PREVIEW_INSET := Vector2(14.0, 9.0)
const ROW_H := 48.0
const FIELD_W := 96.0
const SWATCH := 22.0


static func build(helper: Object) -> Control:
	var sc: ScrollContainer = load("res://ui/kit/pm_scroll_keep.gd").new()
	sc.name = "OutlineWindow"
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
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(col)
	var reg: RefCounted = OutlineStyles.shared()
	col.add_child(_show_row(helper))
	col.add_child(_meta("Style"))
	var chosen: String = String(helper.call("style_id"))
	var used: String = String((helper.get("styled") as Dictionary).get("id", chosen))
	for d: Dictionary in reg.call("list"):
		col.add_child(_style_row(helper, d, String(d["id"]) == chosen, reg))
	var tools: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	var folder: Button = PmButton.make("Open the outlines folder")
	folder.name = "OpenFolder"
	folder.pressed.connect(Callable(helper, "open_folder"))
	PmUI.tip(folder, "Drop a folder with an outline.json and an outline.gdshader, or a single .gdshader file, in here")
	tools.add_child(folder)
	var again: Button = PmButton.make("Look again")
	again.name = "LookAgain"
	again.pressed.connect(Callable(helper, "reload_styles"))
	PmUI.tip(again, "Read the outlines folder again")
	tools.add_child(again)
	col.add_child(tools)
	var notes: PackedStringArray = PackedStringArray()
	for b: Dictionary in reg.call("broken"):
		notes.append(String(b.get("id", "")) + " (" + String(b["reason"]) + ")")
	if used != chosen:
		notes.append(chosen + " is chosen but cannot be used, so Solid is drawn instead")
	if not notes.is_empty():
		var bad: Label = PmLabel.wrap("Could not load: " + ", ".join(notes), "text_dim")
		bad.name = "Broken"
		bad.custom_minimum_size.x = float(Tk.px(200.0))
		col.add_child(bad)
	col.add_child(_meta("Colour"))
	col.add_child(_colour_row(helper))
	col.add_child(_field_row("Thickness", PREF_THICKNESS, float(helper.call("thickness")), OutlineStyles.THICK_MIN, OutlineStyles.THICK_MAX, 0.5, " px", helper, PREF_THICKNESS))
	var def: Dictionary = reg.call("get_def", used)
	var params: Array = def.get("params", [])
	if not params.is_empty():
		col.add_child(_meta(String(def.get("label", used)) + " settings"))
		for p: Dictionary in params:
			col.add_child(_param_row(helper, used, p, reg))
	return sc


static func _meta(text: String) -> Control:
	var l: Label = PmLabel.meta(text)
	var box: MarginContainer = MarginContainer.new()
	box.add_theme_constant_override("margin_left", Tk.px(6.0))
	box.add_theme_constant_override("margin_top", Tk.px(4.0))
	box.add_child(l)
	return box


static func _show_row(helper: Object) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(8.0))
	var cb: CheckBox = CheckBox.new()
	cb.name = "ShowOutline"
	cb.text = "Show the transform outline"
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = bool(helper.call("outline_on"))
	cb.toggled.connect(_on_show.bind(helper))
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cb)
	var keys: String = Cmd.keys_text("view.program_outline")
	if not keys.is_empty():
		row.add_child(PmLabel.faint(keys))
	return row


static func _on_show(on: bool, helper: Object) -> void:
	if bool(helper.call("outline_on")) != on:
		helper.call("toggle_outline")


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


static func _style_row(helper: Object, d: Dictionary, chosen: bool, reg: RefCounted) -> Control:
	var id: String = String(d["id"])
	var b: Button = Button.new()
	b.name = "Style_" + id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0.0, float(Tk.px(ROW_H)))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var boxes: Dictionary = _row_box(chosen)
	for state: String in boxes.keys():
		b.add_theme_stylebox_override(state, boxes[state])
	b.pressed.connect(Callable(helper, "set_style").bind(id))
	var blurb: String = String(d.get("blurb", ""))
	PmUI.tip(b, String(d["label"]) + (": " + blurb if not blurb.is_empty() else ""))
	var row: HBoxContainer = PmUI.hbox(Tk.px(10.0))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = float(Tk.px(6.0))
	row.offset_right = -float(Tk.px(6.0))
	b.add_child(row)
	var pv: Control = preview(helper, id, reg)
	row.add_child(pv)
	var name_l: Label = PmLabel.trim(String(d["label"]))
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_l)
	if String(d["source"]) == "user":
		var tag: Label = PmLabel.faint("your style")
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(tag)
	return b


static func preview(helper: Object, id: String, reg: RefCounted) -> Control:
	var box: Control = Control.new()
	box.name = "Preview"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(float(Tk.px(PREVIEW.x)), float(Tk.px(PREVIEW.y)))
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.clip_contents = true
	var ground: ColorRect = ColorRect.new()
	ground.color = Color.BLACK
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(ground)
	var info: Dictionary = reg.call("shader_info", id)
	if not bool(info.get("ok", false)):
		var x: Label = PmLabel.faint("cannot load")
		x.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		x.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(x)
		return box
	var layer: Control = MonitorOutline.new()
	box.add_child(layer)
	var values: Dictionary = reg.call("param_values", Prefs, id)
	layer.call("set_style", info["shader"], info["uniforms"], values, helper.call("outline_colour"), float(helper.call("thickness")), float(reg.call("reach_of", id, values)), (info["uniforms"] as Dictionary).has("time"))
	var w: Vector2 = Vector2(float(Tk.px(PREVIEW.x)), float(Tk.px(PREVIEW.y)))
	var inset: Vector2 = Vector2(float(Tk.px(PREVIEW_INSET.x)), float(Tk.px(PREVIEW_INSET.y)))
	var quad: PackedVector2Array = PackedVector2Array([inset, Vector2(w.x - inset.x, inset.y), w - inset, Vector2(inset.x, w.y - inset.y)])
	var quads: Array[PackedVector2Array] = [quad]
	layer.call("show_quads", quads)
	var previews: Dictionary = helper.get("previews")
	previews[id] = layer
	return box


static func _colour_row(helper: Object) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row.name = "Colours"
	var now: String = String(helper.call("colour_text")).strip_edges().to_lower()
	for pair: Array in helper.call("colours"):
		var hex: String = String(pair[1])
		var col: Color = Tk.c["accent"] if hex.is_empty() else Color.from_string(hex, Color.WHITE)
		var same: bool = now == hex if hex.is_empty() else (not now.is_empty() and Color.from_string(now, Color(0, 0, 0, 0)).is_equal_approx(col))
		var ring: PanelContainer = PanelContainer.new()
		ring.name = "Ring_" + (hex.trim_prefix("#") if not hex.is_empty() else "theme")
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var rb: StyleBoxFlat = StyleBoxFlat.new()
		rb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		rb.set_corner_radius_all(Tk.px(7.0))
		rb.set_border_width_all(Tk.px(2.0) if same else 0)
		rb.border_color = Tk.c["sol"]
		rb.set_content_margin_all(float(Tk.px(3.0)))
		ring.add_theme_stylebox_override("panel", rb)
		var sw: Button = Button.new()
		sw.name = "Swatch_" + (hex.trim_prefix("#") if not hex.is_empty() else "theme")
		sw.focus_mode = Control.FOCUS_NONE
		sw.custom_minimum_size = Vector2(float(Tk.px(SWATCH - 6.0)), float(Tk.px(SWATCH - 6.0)))
		for state: String in ["normal", "hover", "pressed", "focus"]:
			var sb: StyleBoxFlat = StyleBoxFlat.new()
			sb.bg_color = col
			sb.set_corner_radius_all(Tk.px(4.0))
			sb.set_border_width_all(1)
			sb.border_color = Tk.c["text_faint"] if state == "hover" else Tk.c["border_soft"]
			sw.add_theme_stylebox_override(state, sb)
		sw.pressed.connect(Callable(helper, "on_menu_picked").bind("ol:col:" + (hex if not hex.is_empty() else "theme")))
		PmUI.tip(sw, String(pair[0]) + (", chosen" if same else ""))
		ring.add_child(sw)
		row.add_child(ring)
	row.add_child(PmUI.spacer())
	var pick: Button = PmButton.make("Choose...")
	pick.name = "ChooseColour"
	pick.pressed.connect(Callable(helper, "open_colour_window"))
	PmUI.tip(pick, "Any colour, with how see through it is")
	row.add_child(pick)
	return row


static func _field_row(label: String, name_: String, v: float, lo: float, hi: float, step: float, suffix: String, helper: Object, pref: String) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(8.0))
	var l: Label = PmLabel.trim(label)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var f: Control = PmField.make(v, lo, hi, step, suffix)
	f.name = "Field_" + name_.get_slice(".", name_.get_slice_count(".") - 1)
	f.custom_minimum_size.x = float(Tk.px(FIELD_W))
	f.set("show_range", true)
	f.connect("value_changed", _on_field_value.bind(helper, pref))
	f.connect("edit_ended", _on_field_done.bind(f, helper, pref))
	row.add_child(f)
	return row


static func _on_field_value(v: float, helper: Object, pref: String) -> void:
	var key: String = pref if pref == PREF_THICKNESS else pref.get_slice(".", pref.get_slice_count(".") - 1)
	helper.call("preview_value", key, v)


static func _on_field_done(f: Control, helper: Object, pref: String) -> void:
	var v: float = float(f.get("value"))
	var spec: Dictionary = Prefs.spec(pref) if Prefs.is_registered(pref) else {}
	if String(spec.get("type", "float")) == "int":
		helper.call("commit_value", pref, int(round(v)))
	else:
		helper.call("commit_value", pref, v)


static func _param_row(helper: Object, style_id: String, p: Dictionary, reg: RefCounted) -> Control:
	var pref: String = OutlineStyles.pref_key(style_id, String(p["key"]))
	var type: String = String(p["type"])
	var v: Variant = reg.call("param_value", Prefs, style_id, p)
	if type == "bool":
		var cb: CheckBox = CheckBox.new()
		cb.name = "Param_" + String(p["key"])
		cb.text = String(p["label"])
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = bool(v)
		cb.toggled.connect(_on_bool.bind(helper, pref))
		return cb
	if type == "colour":
		var row: HBoxContainer = PmUI.hbox(Tk.px(8.0))
		var l: Label = PmLabel.trim(String(p["label"]))
		row.add_child(l)
		var b: Button = PmButton.make("Choose...")
		b.name = "Param_" + String(p["key"])
		b.pressed.connect(Callable(helper, "open_param_colour").bind(pref, String(p["label"])))
		row.add_child(b)
		return row
	var unit: String = String(p.get("unit", ""))
	var step: float = float(p.get("step", 0.1))
	return _field_row(String(p["label"]) + (" (" + unit + ")" if not unit.is_empty() and unit != "px" else ""), pref, float(v), float(p["min"]), float(p["max"]), step, " px" if unit == "px" else "", helper, pref)


static func _on_bool(on: bool, helper: Object, pref: String) -> void:
	helper.call("commit_value", pref, on)

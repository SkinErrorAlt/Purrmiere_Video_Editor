extends VBoxContainer

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Verbs := preload("res://doc/verbs.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const TextRuns := preload("res://doc/text_runs.gd")
const TextFrame := preload("res://doc/text_frame.gd")
const FontLibrary := preload("res://doc/font_library.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const TextAnimators := preload("res://doc/text_animators.gd")
const TextExtras := preload("res://doc/text_extras.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const RUNS_PATH := "props.runs"
const BUILT_IN := "Figtree (built in)"
const FONT_PICK := "tfont:"
const STYLES: Array = [["regular", "Regular"], ["italic", "Italic"], ["bold", "Bold"], ["bold_italic", "Bold Italic"]]
const ALIGN_ROW: Array = [
	["left", "Align left"], ["center", "Centre text"], ["right", "Align right"],
	["justify", "Justify, last line left"], ["justify_center", "Justify, last line centred"],
	["justify_right", "Justify, last line right"], ["justify_all", "Justify all lines"],
]
const VALIGN_ROW: Array = [["top", "Top align text"], ["center", "Centre text vertically"], ["bottom", "Bottom align text"]]
const FRAME_ROW: Array = [
	["left", "Align left to the video frame"], ["hcenter", "Align centre horizontally to the video frame"], ["right", "Align right to the video frame"],
	["top", "Align top to the video frame"], ["vcenter", "Align centre vertically to the video frame"], ["bottom", "Align bottom to the video frame"],
]
const MonitorPick := preload("res://modules/core_panels/monitor_pick.gd")
const TextParaUI := preload("res://modules/core_panels/text_para_ui.gd")
const TextStrokesUI := preload("res://modules/core_panels/text_strokes_ui.gd")
const FAUX: Array = [
	["bold", "T", "Faux bold"], ["italic", "T", "Faux italic"], ["uppercase", "TT", "All caps"],
	["small_caps", "Tt", "Small caps"], ["super", "T¹", "Superscript"], ["sub", "T₁", "Subscript"],
	["underline", "T", "Underline"],
]
const LABEL_W := 92.0
const FIELD_W := 64.0

var panel: Object = null
var clip_id: String = ""
var _stamp: String = ""
var _font_btn: Button = null
var _style_drop: Button = null
var _fields: Dictionary = {}
var _toggles: Dictionary = {}
var _aligns: Dictionary = {}
var _valigns: Dictionary = {}
var _checks: Dictionary = {}
var _swatches: Dictionary = {}
var _live: bool = false
var _colour_window: Control = null
var _scope_note: Label = null
var _animate_btn: Button = null
var _keys: Dictionary = {}
var _shape_drop: Button = null
var _shape_b_drop: Button = null
var _strokes: Control = null
var writes: int = 0


static func make(host: Object, id: String) -> Control:
	var script: GDScript = load("res://modules/core_panels/text_ec_block.gd")
	var b: VBoxContainer = script.new()
	b.set("panel", host)
	b.set("clip_id", id)
	b.name = "TextBlock"
	b.call("_build")
	return b


func _doc() -> Project:
	return Session.doc


func _seq() -> Sequence:
	return Session.seq()


func target() -> Clip:
	var s: Sequence = _seq()
	return s.clip_by_id(clip_id) if s != null else null


func props_now() -> Dictionary:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var c: Clip = target()
	if d == null or s == null or c == null:
		return {}
	var m: MediaItem = d.media_by_id(c.media_id)
	if m == null:
		return {}
	var base: Dictionary = m.props.duplicate(true)
	var now: Dictionary = c.props_at(s.playhead - c.start, s.fps)
	for k: Variant in now.keys():
		base[k] = now[k]
	return TitleStyle.merged("title", {}, base, m.label)


func _text_edit() -> RefCounted:
	var bus: Object = Bus.instance()
	var pp: Object = bus.call("panel", "program") if bus != null else null
	if pp == null or not pp.has_method("monitor_text_edit"):
		return null
	var te: RefCounted = pp.call("monitor_text_edit")
	if not bool(te.call("editing")) or String(te.get("clip_id")) != clip_id:
		return null
	return te


func field_edit() -> TextEdit:
	if panel == null or not panel.has_method("_row_for"):
		return null
	var r: Dictionary = panel.call("_row_for", "props.text")
	if r.is_empty():
		return null
	var eds: Array = r.get("editors", [])
	if eds.is_empty() or not (eds[0] is TextEdit) or not is_instance_valid(eds[0]):
		return null
	return eds[0]


func picked_span() -> Vector2i:
	var te: RefCounted = _text_edit()
	if te != null:
		if not bool(te.call("has_selection")):
			return Vector2i(-1, -1)
		return te.call("selection")
	var fe: TextEdit = field_edit()
	if fe != null and fe.has_selection():
		var pop: GDScript = load("res://modules/core_panels/text_popout.gd")
		var sp: Vector2i = pop.call("selection_of", fe)
		var raw: Variant = TextRuns.plain(props_now().get("text", ""))
		var n: int = String(raw).length() if raw is String else 0
		if sp.x >= 0 and sp.y <= n and sp.y > sp.x:
			return sp
	return Vector2i(-1, -1)


func value_of(key: String) -> Variant:
	var props: Dictionary = props_now()
	var fallback: Variant = TextRuns.plain(props.get(key, null))
	var sp: Vector2i = picked_span()
	if sp.x >= 0 and TextRuns.STYLE_KEYS.has(key):
		var raw: Variant = TextRuns.plain(props.get("text", ""))
		var runs: Array[Dictionary] = TextRuns.for_props(props, String(raw) if raw is String else "")
		return TextRuns.common_value(runs, sp.x, sp.y, key, fallback)
	return fallback


func write(key: String, value: Variant, live: bool = false) -> bool:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var c: Clip = target()
	if d == null or s == null or c == null:
		return false
	var te: RefCounted = _text_edit()
	var bus: Object = Bus.instance()
	if te != null and not live:
		var pp: Object = bus.call("panel", "program")
		te.call("commit", pp)
	writes += 1
	var sp: Vector2i = picked_span()
	if sp.x >= 0 and TextRuns.STYLE_KEYS.has(key):
		var at: float = bus.call("key_time_for", c, RUNS_PATH, s.playhead)
		var pop: GDScript = load("res://modules/core_panels/text_popout.gd")
		var ok: bool = bool(pop.call("apply_range", d, s.id, c.id, sp.x, sp.y, {key: value}, at))
		refresh(true)
		return ok
	var path: String = "props." + key
	var group: Array[Clip] = many_targets()
	if group.size() > 1:
		for mc: Clip in group:
			Verbs.set_clip_param(d, s, mc.id, path, value, bus.call("key_time_for", mc, path, s.playhead), true)
		if not live:
			d.undo.commit_live("Set " + key.replace("_", " ") + " on %d titles" % group.size())
		refresh(true)
		return true
	var key_at: float = bus.call("key_time_for", c, path, s.playhead)
	var done: bool = Verbs.set_clip_param(d, s, c.id, path, value, key_at, live)
	refresh(true)
	return done


func many_targets() -> Array[Clip]:
	var out: Array[Clip] = []
	var s: Sequence = _seq()
	var d: Project = _doc()
	if panel == null or s == null or d == null or not bool(panel.get("_many_on")):
		return out
	for id: String in s.selected_clip_ids:
		var mc: Clip = s.clip_by_id(id)
		if mc == null:
			continue
		var m: MediaItem = d.media_by_id(mc.media_id)
		if m != null and m.kind == "title":
			out.append(mc)
	return out


func _build() -> void:
	add_theme_constant_override("separation", Tk.px(4.0))
	var pad: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		pad.add_theme_constant_override(side, Tk.px(10.0))
	pad.add_theme_constant_override("margin_top", Tk.px(4.0))
	pad.add_theme_constant_override("margin_bottom", Tk.px(6.0))
	add_child(pad)
	var col: VBoxContainer = PmUI.vbox(Tk.px(6.0))
	pad.add_child(col)
	_scope_note = PmLabel.dim("")
	_scope_note.visible = false
	col.add_child(_scope_note)
	col.add_child(_heading("Align and Transform"))
	var row0: HBoxContainer = PmUI.hbox(Tk.px(1.0))
	for fa: Array in FRAME_ROW:
		var fb: Button = PmButton.make("", "", false)
		fb.set("quiet", true)
		fb.name = "Frame_" + String(fa[0])
		fb.custom_minimum_size = Vector2(float(Tk.px(26.0)), float(Tk.px(24.0)))
		fb.focus_mode = Control.FOCUS_NONE
		var gl: Control = _Glyph.make("frame", String(fa[0]))
		gl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fb.add_child(gl)
		PmUI.tip(fb, String(fa[1]))
		fb.pressed.connect(align_to_frame.bind(String(fa[0])))
		row0.add_child(fb)
		if String(fa[0]) == "right":
			row0.add_child(_gap(10.0))
	col.add_child(row0)
	col.add_child(_heading("Text"))
	_font_btn = PmButton.make(BUILT_IN)
	_font_btn.name = "FontFamily"
	_font_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_font_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font_btn.pressed.connect(_on_font)
	PmUI.tip(_font_btn, "Font")
	col.add_child(_font_btn)
	var row2: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	var choices: Array = []
	for st: Array in STYLES:
		choices.append(PmDrop.choice(String(st[0]), String(st[1])))
	_style_drop = PmDrop.make_drop(choices, "regular")
	_style_drop.name = "FontStyle"
	_style_drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_drop.connect("changed", _on_style)
	row2.add_child(_style_drop)
	row2.add_child(_field("size", 4.0, 1000.0, 1.0, "", "Font size"))
	row2.add_child(_key_btn("size"))
	col.add_child(row2)
	var row3: HBoxContainer = PmUI.hbox(Tk.px(1.0))
	for a: Array in ALIGN_ROW:
		var b: Button = _icon_toggle(_Glyph.make("align", String(a[0])), String(a[1]))
		b.pressed.connect(_on_align.bind(String(a[0])))
		_aligns[String(a[0])] = b
		row3.add_child(b)
	row3.add_child(_gap(10.0))
	for v: Array in VALIGN_ROW:
		var vb: Button = _icon_toggle(_Glyph.make("valign", String(v[0])), String(v[1]))
		vb.pressed.connect(_on_valign.bind(String(v[0])))
		_valigns[String(v[0])] = vb
		row3.add_child(vb)
	col.add_child(row3)
	var row4: HFlowContainer = HFlowContainer.new()
	row4.add_theme_constant_override("h_separation", Tk.px(10.0))
	row4.add_theme_constant_override("v_separation", Tk.px(4.0))
	row4.add_child(_labelled(_Glyph.make("tracking", ""), _field("letter_spacing", -200.0, 1000.0, 1.0, "", "Tracking"), _key_btn("letter_spacing")))
	row4.add_child(_labelled(_Glyph.make("kerning", ""), _field("kerning", -200.0, 1000.0, 1.0, "", "Kerning: the space between the two letters either side of the caret")))
	row4.add_child(_labelled(_Glyph.make("leading", ""), _field("line_spacing", -400.0, 1000.0, 1.0, "", "Leading"), _key_btn("line_spacing")))
	row4.add_child(_labelled(_Glyph.make("baseline", ""), _field("baseline", -500.0, 500.0, 1.0, "", "Baseline shift"), _key_btn("baseline")))
	row4.add_child(_labelled(_Glyph.make("opacity", ""), _field("text_opacity", 0.0, 100.0, 1.0, "", "Opacity of the letters"), _key_btn("text_opacity")))
	row4.add_child(_labelled(_Glyph.make("tsume", ""), _field("tsume", 0.0, 100.0, 1.0, "", "Tsume: takes away this much of the empty space either side of each letter, in percent"), _key_btn("tsume")))
	row4.add_child(_labelled(_Glyph.make("tab", ""), _field("tab_width", 0.0, 2000.0, 1.0, "", "Tab width: how far each Tab moves the text along, 0 uses the font's own"), _key_btn("tab_width")))
	col.add_child(row4)
	var row5: HBoxContainer = PmUI.hbox(Tk.px(1.0))
	for f: Array in FAUX:
		var tb: Button = _icon_toggle(_Glyph.make("faux", String(f[0]), String(f[1])), String(f[2]))
		tb.pressed.connect(_on_faux.bind(String(f[0])))
		_toggles[String(f[0])] = tb
		row5.add_child(tb)
	col.add_child(row5)
	_animate_btn = PmButton.make("Animate these characters")
	_animate_btn.name = "AnimatePicked"
	_animate_btn.visible = false
	_animate_btn.pressed.connect(animate_picked)
	PmUI.tip(_animate_btn, "Adds a text animator that moves only the selected characters. Keyframe its Move, Size, Turn, Opacity and Colour")
	col.add_child(_animate_btn)
	col.add_child(_heading("Shape and tilt"))
	var srow: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	var shapes: Array = []
	var shapes_b: Array = []
	for i: int in TextExtras.PATH_SHAPES.size():
		var sid: String = TextExtras.PATH_SHAPES[i]
		shapes.append(PmDrop.choice(sid, TextExtras.PATH_LABELS[i]))
		if sid != "points":
			shapes_b.append(PmDrop.choice(sid, "Nothing" if sid == "none" else TextExtras.PATH_LABELS[i]))
	_shape_drop = PmDrop.make_drop(shapes, "none")
	_shape_drop.name = "PathShape"
	_shape_drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shape_drop.connect("changed", _on_drop_prop.bind("path_shape"))
	PmUI.tip(_shape_drop, "The shape the text follows")
	srow.add_child(_shape_drop)
	srow.add_child(_key_btn("path_shape"))
	col.add_child(srow)
	col.add_child(_value_row("How much of it", "path_amount", 0.0, 100.0, 1.0))
	col.add_child(_value_row("Size", "path_size", 0.0, 400.0, 1.0))
	col.add_child(_value_row("Bend", "path_bend", -200.0, 200.0, 1.0))
	var brow: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	var bl: Label = PmLabel.dim("Blend into")
	bl.custom_minimum_size.x = float(Tk.px(LABEL_W))
	bl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	brow.add_child(bl)
	_shape_b_drop = PmDrop.make_drop(shapes_b, "none")
	_shape_b_drop.name = "PathShapeB"
	_shape_b_drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shape_b_drop.connect("changed", _on_drop_prop.bind("path_shape_b"))
	brow.add_child(_shape_b_drop)
	col.add_child(brow)
	col.add_child(_value_row("Blend", "path_mix", 0.0, 100.0, 1.0))
	col.add_child(_value_row("Tilt", "tilt", -85.0, 85.0, 0.5))
	col.add_child(_value_row("Slant", "slant", -70.0, 70.0, 0.5))
	col.add_child(_heading("Appearance"))
	col.add_child(_appearance_row("fill_on", "Fill", "colour", []))
	col.add_child(_appearance_row("stroke_on", "Stroke", "outline_colour", [["outline", "Stroke width", 0.0, 60.0, 0.5]]))
	col.add_child(_appearance_row("stroke2_on", "Second stroke", "stroke2_colour", [["stroke2_width", "Second stroke width", 0.0, 60.0, 0.5]]))
	_strokes = TextStrokesUI.make(self)
	col.add_child(_strokes)
	col.add_child(_appearance_row("highlight_on", "Highlight", "highlight", []))
	col.add_child(_appearance_row("box_on", "Background", "box_colour", [["box_opacity", "Opacity", 0.0, 100.0, 1.0], ["box_pad", "Size", 0.0, 200.0, 1.0], ["box_radius", "Corner radius", 0.0, 200.0, 1.0]]))
	var lines_row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	lines_row.add_child(_gap(30.0))
	var lines_cb: CheckBox = CheckBox.new()
	lines_cb.name = "Check_box_lines"
	lines_cb.text = "One box for each line"
	lines_cb.focus_mode = Control.FOCUS_NONE
	lines_cb.toggled.connect(_on_check.bind("box_lines"))
	_checks["box_lines"] = lines_cb
	lines_row.add_child(lines_cb)
	col.add_child(lines_row)
	col.add_child(_appearance_row("shadow_on", "Shadow", "shadow_colour", [["shadow_opacity", "Opacity", 0.0, 100.0, 1.0], ["shadow_angle", "Angle", 0.0, 360.0, 1.0], ["shadow_distance", "Distance", 0.0, 200.0, 0.5], ["shadow_size", "Size", 0.0, 60.0, 0.5], ["shadow_softness", "Blur", 0.0, 150.0, 0.5]]))
	refresh(true)


func _value_row(label: String, key: String, lo: float, hi: float, step_: float) -> Control:
	var r: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	var l: Label = PmLabel.dim(label)
	l.custom_minimum_size.x = float(Tk.px(LABEL_W))
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	r.add_child(l)
	r.add_child(_field(key, lo, hi, step_, "", label))
	r.add_child(_key_btn(key))
	return r


func _on_drop_prop(id: String, key: String) -> void:
	write(key, id)
	if key == "path_shape_b" and id != "none" and float(TextExtras.get_value(props_now(), "path_mix")) <= 0.0:
		write("path_mix", 50.0)


func _gap(w: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(float(Tk.px(w)), 0.0)
	return c


func _heading(text: String) -> Control:
	var l: Label = PmLabel.trim(text, "text_bright")
	return l


func _icon_toggle(glyph: Control, tip: String) -> Button:
	var b: Button = PmButton.make("", "", true)
	b.set("quiet", true)
	b.custom_minimum_size = Vector2(float(Tk.px(26.0)), float(Tk.px(24.0)))
	b.focus_mode = Control.FOCUS_NONE
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(glyph)
	PmUI.tip(b, tip)
	return b


func _labelled(glyph: Control, field: Control, key_btn: Button = null) -> Control:
	var h: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	glyph.custom_minimum_size = Vector2(float(Tk.px(22.0)), float(Tk.px(22.0)))
	h.add_child(glyph)
	h.add_child(field)
	if key_btn != null:
		h.add_child(key_btn)
	return h


func _key_btn(key: String) -> Button:
	var b: Button = PmButton.make("", "stopwatch", true)
	b.set("quiet", true)
	b.set("icon_px", 12.0)
	b.name = "Key_" + key
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(float(Tk.px(20.0)), float(Tk.px(20.0)))
	b.pressed.connect(_on_key_btn.bind(key))
	PmUI.tip(b, "Add or remove a keyframe here")
	_keys[key] = b
	return b


func _on_key_btn(key: String) -> void:
	toggle_key(key)


func keyed(key: String) -> bool:
	var c: Clip = target()
	return c != null and AnimProp.is_animated(c.get_param("props." + key))


func toggle_key(key: String) -> bool:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var c: Clip = target()
	if d == null or s == null or c == null:
		return false
	var te: RefCounted = _text_edit()
	if te != null:
		te.call("commit", Bus.instance().call("panel", "program"))
	var path: String = "props." + key
	var p: Dictionary = c.get_param(path)
	writes += 1
	if p.is_empty() or not AnimProp.is_animated(p):
		var v: Variant = TextRuns.plain(props_now().get(key, null))
		if v == null and TextExtras.defaults().has(key):
			v = TextExtras.get_value(props_now(), key)
		if v == null and (key == "tsume" or key == "tab_width"):
			v = 0.0
		if v == null:
			return false
		var base: Dictionary = p if not p.is_empty() else AnimProp.make(v)
		var cmds: Array[Command] = [ClipCmds.SetClipParam.new(s.id, c.id, path, AnimProp.set_key(base, c.param_time(path, s.playhead - c.start), v))]
		var ok: bool = Verbs.run(d, "Keyframe", cmds)
		refresh(true)
		return ok
	var done: bool = Verbs.toggle_keyframe(d, s, c.id, path, s.playhead)
	refresh(true)
	return done


func _field(key: String, lo: float, hi: float, step_: float, suffix_: String, tip: String) -> Control:
	var f: Control = PmField.make(0.0, lo, hi, step_, suffix_)
	f.name = "Field_" + key
	f.custom_minimum_size.x = float(Tk.px(FIELD_W))
	f.connect("value_changed", _on_field.bind(key))
	f.connect("edit_begun", _on_begun)
	f.connect("edit_ended", _on_ended.bind(tip))
	PmUI.tip(f, tip)
	_fields[key] = f
	return f


func _appearance_row(check_key: String, label: String, colour_key: String, extra: Array) -> Control:
	var box: VBoxContainer = PmUI.vbox(Tk.px(3.0))
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	var cb: CheckBox = CheckBox.new()
	cb.name = "Check_" + check_key
	cb.focus_mode = Control.FOCUS_NONE
	cb.toggled.connect(_on_check.bind(check_key))
	_checks[check_key] = cb
	row.add_child(cb)
	var l: Label = PmLabel.trim(label)
	l.custom_minimum_size.x = float(Tk.px(LABEL_W))
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(l)
	var sw: Button = PmButton.make("")
	sw.name = "Swatch_" + colour_key
	sw.custom_minimum_size = Vector2(float(Tk.px(34.0)), float(Tk.px(20.0)))
	sw.focus_mode = Control.FOCUS_NONE
	var chip: ColorRect = ColorRect.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chip.offset_left = 3.0
	chip.offset_top = 3.0
	chip.offset_right = -3.0
	chip.offset_bottom = -3.0
	sw.add_child(chip)
	sw.pressed.connect(_on_swatch.bind(colour_key, label, sw))
	_swatches[colour_key] = chip
	row.add_child(sw)
	row.add_child(_key_btn(colour_key))
	if extra.size() == 1:
		var e0: Array = extra[0]
		row.add_child(_field(String(e0[0]), float(e0[2]), float(e0[3]), float(e0[4]), "", String(e0[1])))
		row.add_child(_key_btn(String(e0[0])))
	box.add_child(row)
	if extra.size() > 1:
		for e: Array in extra:
			var r2: HBoxContainer = PmUI.hbox(Tk.px(6.0))
			r2.add_child(_gap(30.0))
			var l2: Label = PmLabel.dim(String(e[1]))
			l2.custom_minimum_size.x = float(Tk.px(LABEL_W))
			l2.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			r2.add_child(l2)
			r2.add_child(_field(String(e[0]), float(e[2]), float(e[3]), float(e[4]), "", String(e[1])))
			if not String(e[0]).ends_with("_opacity"):
				r2.add_child(_key_btn(String(e[0])))
			box.add_child(r2)
	return box


func _process(_dt: float) -> void:
	if not is_visible_in_tree():
		return
	refresh(false)


func refresh(force: bool) -> void:
	var d: Project = _doc()
	var s: Sequence = _seq()
	if d == null or s == null:
		return
	var sp: Vector2i = picked_span()
	var st: String = str(d.serial) + ":" + str(s.playhead) + ":" + str(sp) + ":" + clip_id + ":" + str(TextParaUI.caret_span(self))
	if st == _stamp and not force:
		return
	_stamp = st
	var props: Dictionary = props_now()
	if props.is_empty():
		return
	_scope_note.visible = sp.x >= 0
	_scope_note.text = "Changes go to the %d selected characters" % (sp.y - sp.x)
	_animate_btn.visible = sp.x >= 0
	_animate_btn.text = "Animate these %d characters" % (sp.y - sp.x)
	var font: String = String(value_of("font")) if value_of("font") is String else ""
	_font_btn.text = _font_name(font)
	var bold: bool = bool(value_of("bold"))
	var italic: bool = bool(value_of("italic"))
	_style_drop.call("set_value", ("bold_italic" if italic else "bold") if bold else ("italic" if italic else "regular"), false)
	_set_field("size", float(value_of("size")))
	_set_field("letter_spacing", float(value_of("letter_spacing")))
	_set_field("line_spacing", float(props.get("line_spacing", 0.0)))
	_set_field("baseline", float(value_of("baseline")))
	_set_field("outline", float(value_of("outline")))
	_set_field("box_pad", float(props.get("box_pad", 12.0)))
	_set_field("box_radius", float(props.get("box_radius", 8.0)))
	_set_field("shadow_angle", float(props.get("shadow_angle", 135.0)))
	_set_field("shadow_distance", float(props.get("shadow_distance", 6.0)))
	_set_field("shadow_size", float(props.get("shadow_size", 0.0)))
	_set_field("shadow_softness", float(props.get("shadow_softness", 8.0)))
	var box_col: Color = TitleStyle.colour_of(props.get("box_colour", null), Color(0, 0, 0, 0))
	var sh_col: Color = TitleStyle.colour_of(props.get("shadow_colour", null), Color(0, 0, 0, 0.6))
	_set_field("box_opacity", box_col.a * 100.0)
	_set_field("shadow_opacity", sh_col.a * 100.0)
	var align: String = TextParaUI.shown_align(self, props)
	for k: String in _aligns.keys():
		(_aligns[k] as Button).set_pressed_no_signal(k == align)
	var valign: String = String(props.get("valign", "center"))
	for k2: String in _valigns.keys():
		(_valigns[k2] as Button).set_pressed_no_signal(k2 == valign)
		(_valigns[k2] as Button).disabled = TextFrame.is_point(props)
	var script: String = String(value_of("script")) if value_of("script") is String else ""
	(_toggles["bold"] as Button).set_pressed_no_signal(bold)
	(_toggles["italic"] as Button).set_pressed_no_signal(italic)
	(_toggles["uppercase"] as Button).set_pressed_no_signal(bool(props.get("uppercase", false)))
	(_toggles["small_caps"] as Button).set_pressed_no_signal(bool(value_of("small_caps")))
	(_toggles["super"] as Button).set_pressed_no_signal(script == "super")
	(_toggles["sub"] as Button).set_pressed_no_signal(script == "sub")
	(_toggles["underline"] as Button).set_pressed_no_signal(bool(value_of("underline")))
	(_checks["fill_on"] as CheckBox).set_pressed_no_signal(bool(props.get("fill_on", true)))
	(_checks["stroke_on"] as CheckBox).set_pressed_no_signal(bool(props.get("stroke_on", true)) and float(props.get("outline", 0.0)) > 0.0)
	(_checks["box_on"] as CheckBox).set_pressed_no_signal(bool(props.get("box_on", true)) and box_col.a > 0.001)
	(_checks["shadow_on"] as CheckBox).set_pressed_no_signal(bool(props.get("shadow_on", false)))
	(_checks["stroke2_on"] as CheckBox).set_pressed_no_signal(bool(props.get("stroke2_on", false)))
	(_checks["box_lines"] as CheckBox).set_pressed_no_signal(bool(props.get("box_lines", false)))
	(_checks["highlight_on"] as CheckBox).set_pressed_no_signal(TitleStyle.colour_of(value_of("highlight"), Color(0, 0, 0, 0)).a > 0.001)
	_set_field("text_opacity", float(value_of("text_opacity")))
	var tsv: Variant = value_of("tsume")
	_set_field("tsume", float(tsv) if tsv is float or tsv is int else 0.0)
	var tbv: Variant = TextRuns.plain(props.get("tab_width", 0.0))
	_set_field("tab_width", float(tbv) if tbv is float or tbv is int else 0.0)
	if _strokes != null:
		_strokes.call("show_for", props)
	var ki: int = kern_index()
	var kf: Control = _fields.get("kerning", null)
	if kf != null:
		kf.modulate.a = 1.0 if ki >= 0 else 0.4
		if ki >= 0:
			var rawk: Variant = TextRuns.plain(props.get("text", ""))
			var runs_k: Array[Dictionary] = TextRuns.for_props(props, String(rawk) if rawk is String else "")
			_set_field("kerning", float(TextRuns.style_at(runs_k, ki).get("letter_spacing", props.get("letter_spacing", 0.0))))
	for pk: String in ["path_amount", "path_size", "path_bend", "path_mix", "tilt", "slant"]:
		_set_field(pk, float(TextExtras.get_value(props, pk)))
	_shape_drop.call("set_value", TextExtras.path_shape(props), false)
	_shape_b_drop.call("set_value", TextExtras.shape_b(props), false)
	_set_field("stroke2_width", float(props.get("stroke2_width", 6.0)))
	for kk: String in _keys.keys():
		(_keys[kk] as Button).set_pressed_no_signal(keyed(kk))
	for ck: String in _swatches.keys():
		var cv: Variant = value_of(ck) if TextRuns.STYLE_KEYS.has(ck) else props.get(ck, null)
		var c0: Color = TitleStyle.colour_of(cv, Color.WHITE)
		(_swatches[ck] as ColorRect).color = Color(c0.r, c0.g, c0.b, 1.0)


func _set_field(key: String, v: float) -> void:
	var f: Control = _fields.get(key, null)
	if f == null or bool(f.get("_dragging")) or f.get("_editor") != null:
		return
	f.set("value", v)


func _font_name(name_: String) -> String:
	if name_.is_empty() or name_ == "default":
		return BUILT_IN
	if FontLibrary.is_token(name_):
		return FontLibrary.file_of(name_).get_basename()
	return name_


func font_items(current: String) -> Array:
	var out: Array = [PmMenu.check_item(FONT_PICK, BUILT_IN, current.is_empty() or current == "default")]
	var d: Project = _doc()
	var seen: Dictionary = {}
	for f: Dictionary in FontLibrary.listing(d):
		out.append(PmMenu.check_item(FONT_PICK + String(f["token"]), String(f["label"]), String(f["token"]) == current))
		seen[String(f["token"])] = true
	var sys: PackedStringArray = TitleStyle.system_fonts()
	if not sys.is_empty():
		out.append(PmMenu.separator())
	for n: String in sys:
		if seen.has(n):
			continue
		out.append(PmMenu.check_item(FONT_PICK + n, n, n == current))
	return out


func _on_font() -> void:
	var cur: Variant = value_of("font")
	var menu: Control = PmMenu.open(_font_btn, font_items(String(cur) if cur is String else ""))
	if menu != null and menu.is_inside_tree():
		menu.connect("picked", _on_font_pick)


func _on_font_pick(id: String) -> void:
	if not id.begins_with(FONT_PICK):
		return
	write("font", id.substr(FONT_PICK.length()))


func _on_style(id: String) -> void:
	var sp: Vector2i = picked_span()
	var bold: bool = id == "bold" or id == "bold_italic"
	var italic: bool = id == "italic" or id == "bold_italic"
	if sp.x >= 0:
		write("bold", bold)
		write("italic", italic)
		return
	write("bold", bold)
	write("italic", italic)


func animate_picked() -> int:
	var sp: Vector2i = picked_span()
	var d: Project = _doc()
	var s: Sequence = _seq()
	var c: Clip = target()
	if sp.x < 0 or d == null or s == null or c == null:
		return -1
	var n: int = TextAnimators.count(c.props)
	if n >= TextAnimators.MAX_ANIMATORS:
		Events.toast("This title already has the most animators it can hold")
		return -1
	var raw: Variant = TextRuns.plain(props_now().get("text", ""))
	var text: String = String(raw) if raw is String else ""
	var label: String = text.substr(sp.x, sp.y - sp.x).strip_edges().replace("
", " ")
	if label.length() > 20:
		label = label.substr(0, 20)
	var next: Dictionary = TextAnimators.with_added(c.props, {"name": "\"" + label + "\"", "pick": true, "pick_from": float(sp.x), "pick_to": float(sp.y), "units": "characters"})
	var te: RefCounted = _text_edit()
	if te != null:
		te.call("commit", Bus.instance().call("panel", "program"))
	writes += 1
	var cmds: Array[Command] = [ClipCmds.SetClipField.new(s.id, c.id, "props", next)]
	if not Verbs.run(d, "Animate characters", cmds):
		return -1
	refresh(true)
	return n


func align_to_frame(how: String) -> bool:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var c: Clip = target()
	if d == null or s == null or c == null:
		return false
	var q: PackedVector2Array = MonitorPick.words_quad_of_clip(c, s, d, s.playhead)
	if q.size() != 4:
		return false
	var r: Rect2 = Rect2(q[0], Vector2.ZERO)
	for p: Vector2 in q:
		r = r.expand(p)
	var fw: float = float(s.width)
	var fh: float = float(s.height)
	var delta: Vector2 = Vector2.ZERO
	match how:
		"left":
			delta.x = -r.position.x
		"hcenter":
			delta.x = fw * 0.5 - r.get_center().x
		"right":
			delta.x = fw - r.end.x
		"top":
			delta.y = -r.position.y
		"vcenter":
			delta.y = fh * 0.5 - r.get_center().y
		"bottom":
			delta.y = fh - r.end.y
	if delta.is_zero_approx():
		return true
	var lt: float = c.anim_time(s.playhead - c.start)
	var pos: Vector2 = AnimProp.evaluate_vec2(c.transform["pos"], c.inner_time("transform.pos", lt), c.duration, s.fps) + delta
	var key_at: float = Bus.instance().call("key_time_for", c, "transform.pos", s.playhead)
	writes += 1
	return Verbs.set_clip_param(d, s, c.id, "transform.pos", [pos.x, pos.y], key_at)


func _on_align(id: String) -> void:
	TextParaUI.apply(self, id)


func _on_valign(id: String) -> void:
	write("valign", id)


func _on_faux(id: String) -> void:
	match id:
		"bold", "italic", "small_caps", "underline":
			write(id, not bool(value_of(id)))
		"uppercase":
			write("uppercase", not bool(props_now().get("uppercase", false)))
		"super", "sub":
			var cur: Variant = value_of("script")
			write("script", "" if (cur is String and String(cur) == id) else id)


func _on_check(on: bool, key: String) -> void:
	var props: Dictionary = props_now()
	if key == "highlight_on":
		var hv: Variant = value_of("highlight")
		var hc: Color = TitleStyle.colour_of(hv, Color(1.0, 0.85, 0.1, 0.0))
		write("highlight", [hc.r, hc.g, hc.b, 1.0 if on else 0.0])
		return
	write(key, on)
	if not on:
		return
	if key == "stroke_on" and float(props.get("outline", 0.0)) <= 0.0:
		write("outline", 4.0)
	elif key == "box_on":
		var bc: Color = TitleStyle.colour_of(props.get("box_colour", null), Color(0, 0, 0, 0))
		if bc.a <= 0.001:
			write("box_colour", [bc.r, bc.g, bc.b, 0.75])


func kern_index() -> int:
	var te: RefCounted = _text_edit()
	if te == null or bool(te.call("has_selection")):
		return -1
	var at: int = int(te.get("caret"))
	var raw: Variant = TextRuns.plain(props_now().get("text", ""))
	var n: int = String(raw).length() if raw is String else 0
	if at <= 0 or at >= n:
		return -1
	return at - 1


func set_kerning(v: float) -> bool:
	var i: int = kern_index()
	var d: Project = _doc()
	var s: Sequence = _seq()
	var c: Clip = target()
	if i < 0 or d == null or s == null or c == null:
		return false
	var te: RefCounted = _text_edit()
	te.call("commit", Bus.instance().call("panel", "program"))
	var at: float = Bus.instance().call("key_time_for", c, RUNS_PATH, s.playhead)
	var pop: GDScript = load("res://modules/core_panels/text_popout.gd")
	writes += 1
	var ok: bool = bool(pop.call("apply_range", d, s.id, c.id, i, i + 1, {"letter_spacing": v}, at))
	refresh(true)
	return ok


func _on_field(v: float, key: String) -> void:
	if key == "kerning":
		set_kerning(v)
		return
	var props: Dictionary = props_now()
	if key == "box_opacity" or key == "shadow_opacity":
		var ck: String = "box_colour" if key == "box_opacity" else "shadow_colour"
		var c: Color = TitleStyle.colour_of(props.get(ck, null), Color(0, 0, 0, 0))
		write(ck, [c.r, c.g, c.b, clampf(v / 100.0, 0.0, 1.0)], _live)
		return
	write(key, v, _live)


func _on_begun() -> void:
	_live = true
	var d: Project = _doc()
	var te: RefCounted = _text_edit()
	if te != null:
		te.call("commit", Bus.instance().call("panel", "program"))
	if d != null and d.undo.has_live():
		d.undo.commit_live("Edit text")


func _on_ended(label: String) -> void:
	_live = false
	var d: Project = _doc()
	if d != null and d.undo.has_live():
		d.undo.commit_live(label)


func _on_swatch(key: String, label: String, anchor: Control) -> void:
	if _colour_window != null and is_instance_valid(_colour_window):
		_colour_window.call("close")
	var picker: ColorPicker = ColorPicker.new()
	var cv: Variant = value_of(key) if TextRuns.STYLE_KEYS.has(key) else props_now().get(key, null)
	picker.color = TitleStyle.colour_of(cv, Color.WHITE)
	picker.edit_alpha = key != "box_colour" and key != "shadow_colour" and key != "highlight"
	picker.color_changed.connect(_on_colour.bind(key))
	var root: Node = get_tree().root.find_child("EditorScreen", true, false)
	_colour_window = PmWindow.open(root if root != null else self, label + " colour", picker, Vector2(300.0, 420.0), "controls.colour")
	if _colour_window != null:
		_colour_window.call("place_at", anchor.global_position + Vector2(0.0, anchor.size.y))


func _on_colour(col: Color, key: String) -> void:
	var props: Dictionary = props_now()
	var a: float = col.a
	if key == "box_colour" or key == "shadow_colour":
		a = TitleStyle.colour_of(props.get(key, null), Color(0, 0, 0, 0.75)).a
		if a <= 0.001:
			a = 0.75
	elif key == "highlight":
		a = 1.0
	write(key, [col.r, col.g, col.b, a])
	if key == "colour" and not bool(props.get("fill_on", true)):
		write("fill_on", true)


class _Glyph:
	extends Control

	var kind: String = ""
	var mode: String = ""
	var label: String = ""

	static func make(kind_: String, mode_: String, label_: String = "") -> Control:
		var g: _Glyph = _Glyph.new()
		g.kind = kind_
		g.mode = mode_
		g.label = label_
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return g

	func _draw() -> void:
		var ink: Color = Tk.c["text"]
		var c: Vector2 = size * 0.5
		if kind == "align":
			var w: float = 14.0
			var lens: Array = [1.0, 0.62, 1.0, 0.62]
			var justify: bool = mode.begins_with("justify")
			for i: int in 4:
				var lw: float = w * float(lens[i])
				var last: bool = i == 3
				if justify and not (last and mode != "justify_all"):
					lw = w
				var x0: float = c.x - w * 0.5
				var how: String = mode
				if justify:
					how = "left" if mode == "justify" else ("center" if mode == "justify_center" else ("right" if mode == "justify_right" else "left"))
					if not last:
						how = "left"
				if how == "center":
					x0 = c.x - lw * 0.5
				elif how == "right":
					x0 = c.x + w * 0.5 - lw
				var y: float = c.y - 6.0 + float(i) * 4.0
				draw_line(Vector2(x0, y), Vector2(x0 + lw, y), ink, 1.5)
			return
		if kind == "frame":
			var box: Rect2 = Rect2(c - Vector2(8.0, 8.0), Vector2(16.0, 16.0))
			var dim: Color = Color(ink, 0.45)
			var horiz: bool = mode == "left" or mode == "hcenter" or mode == "right"
			if horiz:
				var x: float = box.position.x if mode == "left" else (c.x if mode == "hcenter" else box.end.x)
				draw_line(Vector2(x, box.position.y - 1.0), Vector2(x, box.end.y + 1.0), ink, 1.5)
				var w1: float = 11.0
				var w2: float = 7.0
				var xa: float = x if mode == "left" else (x - w1 * 0.5 if mode == "hcenter" else x - w1)
				var xb: float = x if mode == "left" else (x - w2 * 0.5 if mode == "hcenter" else x - w2)
				draw_rect(Rect2(xa, c.y - 5.0, w1, 4.0), dim, true)
				draw_rect(Rect2(xb, c.y + 1.0, w2, 4.0), dim, true)
			else:
				var y: float = box.position.y if mode == "top" else (c.y if mode == "vcenter" else box.end.y)
				draw_line(Vector2(box.position.x - 1.0, y), Vector2(box.end.x + 1.0, y), ink, 1.5)
				var h1: float = 11.0
				var h2: float = 7.0
				var ya: float = y if mode == "top" else (y - h1 * 0.5 if mode == "vcenter" else y - h1)
				var yb: float = y if mode == "top" else (y - h2 * 0.5 if mode == "vcenter" else y - h2)
				draw_rect(Rect2(c.x - 5.0, ya, 4.0, h1), dim, true)
				draw_rect(Rect2(c.x + 1.0, yb, 4.0, h2), dim, true)
			return
		if kind == "valign":
			var top: float = c.y - 7.0
			draw_line(Vector2(c.x - 7.0, top), Vector2(c.x + 7.0, top), Color(ink, 0.5), 1.0)
			draw_line(Vector2(c.x - 7.0, top + 14.0), Vector2(c.x + 7.0, top + 14.0), Color(ink, 0.5), 1.0)
			var y0: float = top + 2.5 if mode == "top" else (c.y - 2.0 if mode == "center" else top + 7.5)
			draw_line(Vector2(c.x - 5.0, y0), Vector2(c.x + 5.0, y0), ink, 1.5)
			draw_line(Vector2(c.x - 3.5, y0 + 4.0), Vector2(c.x + 3.5, y0 + 4.0), ink, 1.5)
			return
		var font: Font = get_theme_default_font()
		var fs: int = Tk.fs(12.0)
		if kind == "kerning":
			var kt: String = "V|A"
			var kw: float = font.get_string_size(kt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			PmText.draw_at(self, font, Vector2(c.x - kw * 0.5, c.y + fs * 0.35), kt, fs, Color(ink, 0.8))
			return
		if kind == "tracking" or kind == "leading" or kind == "baseline" or kind == "opacity" or kind == "tsume" or kind == "tab":
			var t: String = "VA" if kind == "tracking" else ("A↕" if kind == "leading" else ("A↑" if kind == "baseline" else ("◐" if kind == "opacity" else ("]A[" if kind == "tsume" else "Tab"))))
			var tw: float = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			PmText.draw_at(self, font, Vector2(c.x - tw * 0.5, c.y + fs * 0.35), t, fs, Color(ink, 0.8))
			if kind == "tracking":
				draw_line(Vector2(c.x - tw * 0.5, c.y + fs * 0.55), Vector2(c.x + tw * 0.5, c.y + fs * 0.55), Color(ink, 0.8), 1.0)
			return
		if kind == "faux":
			var f2: Font = font
			if mode == "bold":
				var fv: FontVariation = FontVariation.new()
				fv.base_font = font
				fv.variation_embolden = 1.0
				f2 = fv
			elif mode == "italic":
				var fi: FontVariation = FontVariation.new()
				fi.base_font = font
				fi.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.25, 1.0), Vector2.ZERO)
				f2 = fi
			var fs2: int = Tk.fs(13.0)
			var tw2: float = f2.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
			var at: Vector2 = Vector2(c.x - tw2 * 0.5, c.y + fs2 * 0.36)
			PmText.draw_at(self, f2, at, label, fs2, ink)
			if mode == "underline":
				draw_line(at + Vector2(0.0, 3.0), at + Vector2(tw2, 3.0), ink, 1.0)

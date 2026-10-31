extends VBoxContainer

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const MaskShape := preload("res://doc/mask_shape.gd")
const TextExtras := preload("res://doc/text_extras.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const LIVE_LABEL := "Path and counter"
const NUMBERS: Array = [
	["path_start", "Start along the path", -1000.0, 1000.0, 0.5, " %", "path"],
	["path_size", "Size", 0.0, 400.0, 1.0, "", "path"],
	["path_bend", "Bend", -200.0, 200.0, 1.0, " %", "path"],
	["path_waves", "Waves", 0.0, 20.0, 0.1, "", "path"],
	["counter_value", "Value", -1000000000.0, 1000000000.0, 1.0, "", "counter"],
	["counter_decimals", "Decimals", 0.0, 6.0, 1.0, "", "counter"],
]

var seq_id: String = ""
var clip_id: String = ""
var _doc: Project = null
var _fields: Dictionary = {}
var _keys: Dictionary = {}
var _shape_drop: Button = null
var _format_drop: Button = null
var _turn: CheckBox = null
var _counter_on: CheckBox = null
var _prefix: LineEdit = null
var _suffix: LineEdit = null
var _mask_btn: Button = null
var _note: Label = null


func _init() -> void:
	name = "TextExtras"
	add_theme_constant_override("separation", Tk.px(3.0))
	var title: Label = PmLabel.trim("Path and counter", "text_bright")
	add_child(title)
	var path_row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	path_row.add_child(PmLabel.body("Text follows"))
	var shapes: Array = []
	for i: int in TextExtras.PATH_SHAPES.size():
		shapes.append(PmDrop.choice(TextExtras.PATH_SHAPES[i], TextExtras.PATH_LABELS[i]))
	_shape_drop = PmDrop.make_drop(shapes, "none")
	_shape_drop.name = "PathShape"
	_shape_drop.connect("changed", _on_shape)
	path_row.add_child(_shape_drop)
	_turn = CheckBox.new()
	_turn.text = "Letters turn with it"
	_turn.focus_mode = Control.FOCUS_NONE
	_turn.toggled.connect(_on_turn)
	path_row.add_child(_turn)
	add_child(path_row)
	_mask_btn = PmButton.make("Use this clip's first mask as the path", "pen")
	_mask_btn.name = "PathFromMask"
	_mask_btn.set("quiet", true)
	_mask_btn.pressed.connect(_on_from_mask)
	add_child(_mask_btn)
	var grid: GridContainer = GridContainer.new()
	grid.name = "ExtrasGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", Tk.px(4.0))
	for spec: Array in NUMBERS:
		if String(spec[6]) == "counter" and String(spec[0]) == "counter_value":
			_counter_on = CheckBox.new()
			_counter_on.text = "Count a number instead of the text"
			_counter_on.focus_mode = Control.FOCUS_NONE
			_counter_on.toggled.connect(_on_counter_on)
			grid.add_child(_counter_on)
			grid.add_child(Control.new())
			grid.add_child(Control.new())
		grid.add_child(PmLabel.body(String(spec[1])))
		var f: Control = PmField.make(0.0, float(spec[2]), float(spec[3]), float(spec[4]), String(spec[5]))
		f.name = "Field_" + String(spec[0])
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f.connect("value_changed", _on_number.bind(String(spec[0])))
		f.connect("edit_ended", _on_edit_ended)
		grid.add_child(f)
		var k: Button = PmButton.make("", "diamond", true)
		k.name = "Key_" + String(spec[0])
		k.set("quiet", true)
		PmUI.tip(k, "Keyframe this at the playhead")
		k.toggled.connect(_on_key.bind(String(spec[0])))
		grid.add_child(k)
		_fields[String(spec[0])] = f
		_keys[String(spec[0])] = k
	add_child(grid)
	var fmt_row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	fmt_row.add_child(PmLabel.body("Looks like"))
	var fmts: Array = []
	for j: int in TextExtras.COUNTER_FORMATS.size():
		fmts.append(PmDrop.choice(TextExtras.COUNTER_FORMATS[j], TextExtras.COUNTER_LABELS[j]))
	_format_drop = PmDrop.make_drop(fmts, "number")
	_format_drop.name = "CounterFormat"
	_format_drop.connect("changed", _on_format)
	fmt_row.add_child(_format_drop)
	_prefix = PmUI.line_edit("Before")
	_prefix.name = "CounterPrefix"
	_prefix.text_submitted.connect(_on_affix.bind("counter_prefix"))
	fmt_row.add_child(_prefix)
	_suffix = PmUI.line_edit("After")
	_suffix.name = "CounterSuffix"
	_suffix.text_submitted.connect(_on_affix.bind("counter_suffix"))
	fmt_row.add_child(_suffix)
	add_child(fmt_row)
	_note = PmLabel.wrap("", "text_faint")
	_note.visible = false
	add_child(_note)


func target() -> Clip:
	if _doc == null or seq_id.is_empty() or clip_id.is_empty():
		return null
	var s: Sequence = _doc.sequence_by_id(seq_id)
	return s.clip_by_id(clip_id) if s != null else null


func seq() -> Sequence:
	return _doc.sequence_by_id(seq_id) if _doc != null else null


func show_for(doc: Project, sequence_id: String, id: String) -> void:
	_doc = doc
	seq_id = sequence_id
	clip_id = id
	var c: Clip = target()
	visible = c != null
	if c == null:
		return
	var s: Sequence = seq()
	var live: Dictionary = c.props_at(s.playhead - c.start) if s != null else c.props
	var shape: String = TextExtras.path_shape(live)
	_shape_drop.call("set_value", shape, false)
	_turn.set_pressed_no_signal(bool(TextExtras.get_value(live, "path_turn")))
	_counter_on.set_pressed_no_signal(TextExtras.counter_on(live))
	_format_drop.call("set_value", String(TextExtras.get_value(live, "counter_format")), false)
	if not _prefix.has_focus():
		_prefix.text = String(TextExtras.get_value(live, "counter_prefix"))
	if not _suffix.has_focus():
		_suffix.text = String(TextExtras.get_value(live, "counter_suffix"))
	_mask_btn.disabled = c.masks.is_empty()
	for spec: Array in NUMBERS:
		var field: String = String(spec[0])
		var f: Control = _fields[field]
		if not bool(f.get("_dragging")) and f.get("_editor") == null:
			f.set("value", float(TextExtras.get_value(live, field)))
		(_keys[field] as Button).set_pressed_no_signal(is_keyed(c, field))


func is_keyed(c: Clip, field: String) -> bool:
	var v: Variant = c.props.get(field)
	var s: Sequence = seq()
	if not (v is Dictionary) or not AnimProp.is_animated(v) or s == null:
		return false
	return AnimProp.find_key(v, c.param_time("props." + field, s.playhead - c.start)) >= 0


func write(field: String, value: Variant, live: bool = false) -> bool:
	var c: Clip = target()
	var s: Sequence = seq()
	if c == null or s == null:
		return false
	var cur: Variant = c.props.get(field)
	var keyed: bool = cur is Dictionary and AnimProp.is_animated(cur)
	var v: Variant = int(value) if field == "counter_decimals" else value
	return Verbs.set_clip_param(_doc, s, clip_id, "props." + field, v, s.playhead if keyed else -1.0, live)


func toggle_key(field: String) -> bool:
	var c: Clip = target()
	var s: Sequence = seq()
	if c == null or s == null:
		return false
	var path: String = "props." + field
	var cur: Variant = c.props.get(field)
	if not (cur is Dictionary) or not AnimProp.is_animated(cur):
		var v: Variant = TextExtras.get_value(c.props_at(s.playhead - c.start), field)
		var cmd: Command = ClipCmds.SetClipParam.new(seq_id, clip_id, path, AnimProp.set_key(AnimProp.make(v), c.param_time(path, s.playhead - c.start), v))
		return Verbs.run(_doc, "Keyframe", [cmd] as Array[Command])
	return Verbs.toggle_keyframe(_doc, s, clip_id, path, s.playhead)


func path_from_mask() -> bool:
	var c: Clip = target()
	var s: Sequence = seq()
	if c == null or s == null or c.masks.is_empty():
		return false
	var m: Dictionary = c.masks[0]
	var t: float = s.playhead - c.start
	var pts: PackedVector2Array = PackedVector2Array()
	var closed: bool = true
	if MaskShape.is_box(m):
		var r: Rect2 = MaskShape.box_at(m, t, c.duration, s.fps)
		if str(m.get("kind", "")) == "ellipse":
			for i: int in 96:
				var a: float = -PI * 0.5 + TAU * float(i) / 96.0
				pts.append(r.get_center() + Vector2(cos(a) * r.size.x * 0.5, sin(a) * r.size.y * 0.5))
		else:
			pts = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	else:
		pts = MaskShape.points_at(m, t, c.duration, s.fps)
	if pts.size() < 2:
		return false
	var props: Dictionary = c.props.duplicate(true)
	props["path_points"] = TextExtras.mask_path(pts, closed)
	props["path_shape"] = "points"
	return Verbs.run(_doc, "Path from mask", [ClipCmds.SetClipField.new(seq_id, clip_id, "props", props)] as Array[Command])


func _on_shape(id: String) -> void:
	write("path_shape", id)


func _on_turn(on: bool) -> void:
	write("path_turn", on)


func _on_counter_on(on: bool) -> void:
	write("counter_on", on)


func _on_format(id: String) -> void:
	write("counter_format", id)


func _on_affix(text: String, field: String) -> void:
	write(field, text)


func _on_number(v: float, field: String) -> void:
	write(field, v, true)


func _on_edit_ended() -> void:
	if _doc != null and _doc.undo.has_live():
		_doc.undo.commit_live(LIVE_LABEL)


func _on_key(_on: bool, field: String) -> void:
	toggle_key(field)


func _on_from_mask() -> void:
	path_from_mask()

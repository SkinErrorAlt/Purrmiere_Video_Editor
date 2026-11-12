extends VBoxContainer

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const TextAnimators := preload("res://doc/text_animators.gd")
const TextPresets := preload("res://doc/text_presets.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const SHEET_PATH := "res://modules/core_panels/text_presets_sheet.gd"
const LIVE_LABEL := "Letter animation"
const NUMBERS: Array = [
	["start", "Start", 0.0, 100.0, 1.0, " %"],
	["end", "End", 0.0, 100.0, 1.0, " %"],
	["offset", "Offset", -100.0, 100.0, 1.0, " %"],
	["amount", "Amount", -100.0, 100.0, 1.0, " %"],
	["pos_x", "Move across", -2000.0, 2000.0, 1.0, " px"],
	["pos_y", "Move up and down", -2000.0, 2000.0, 1.0, " px"],
	["scale", "Size", 0.0, 1000.0, 1.0, " %"],
	["rotation", "Turn", -INF, INF, 1.0, " deg"],
	["opacity", "Opacity", 0.0, 100.0, 1.0, " %"],
	["blur", "Blur", 0.0, 100.0, 0.5, " px"],
	["skew", "Skew", -80.0, 80.0, 1.0, " deg"],
	["tracking", "Spacing", -200.0, 400.0, 1.0, " px"],
	["frequency", "Waves across the text", 0.0, 20.0, 0.1, ""],
	["seed", "Random seed", 0.0, 99999.0, 1.0, ""],
]

var seq_id: String = ""
var clip_id: String = ""
var _doc: Project = null
var _shape: String = ""
var _list: VBoxContainer = null
var _add_btn: Button = null
var _browse_btn: Button = null
var _fields: Dictionary = {}
var _folded: Dictionary = {}


func _init() -> void:
	name = "TextAnimators"
	add_theme_constant_override("separation", Tk.px(4.0))
	var head: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	var title: Label = PmLabel.trim("Letter animation", "text_bright")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_browse_btn = PmButton.make("Presets", "type")
	_browse_btn.name = "BrowsePresets"
	_browse_btn.set("quiet", true)
	PmUI.tip(_browse_btn, "Open the text presets: finished looks and your own saved ones, each with a picture of what it does")
	_browse_btn.pressed.connect(_on_browse_pressed)
	head.add_child(_browse_btn)
	_add_btn = PmButton.make("Add", "plus")
	_add_btn.name = "AddAnimator"
	_add_btn.set("quiet", true)
	PmUI.tip(_add_btn, "Animate the letters, words or lines one by one: pick a preset or start blank")
	_add_btn.pressed.connect(_on_add_pressed)
	head.add_child(_add_btn)
	add_child(head)
	_list = PmUI.vbox(Tk.px(6.0))
	add_child(_list)


func show_for(doc: Project, sequence_id: String, id: String) -> void:
	_doc = doc
	seq_id = sequence_id
	clip_id = id
	var c: Clip = target()
	visible = c != null
	if c == null:
		return
	var shape: String = structure(c.props)
	if shape != _shape:
		_shape = shape
		_rebuild(c)
	else:
		_refresh_values(c)


func target() -> Clip:
	if _doc == null or seq_id.is_empty() or clip_id.is_empty():
		return null
	var s: Sequence = _doc.sequence_by_id(seq_id)
	return s.clip_by_id(clip_id) if s != null else null


func seq() -> Sequence:
	return _doc.sequence_by_id(seq_id) if _doc != null else null


static func structure(props: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray([str(TextAnimators.count(props))])
	for i: int in TextAnimators.count(props):
		var a: Dictionary = TextAnimators.animator(props, i)
		parts.append("%s|%s|%s|%s|%s|%s" % [str(a["on"]), a["name"], a["units"], a["shape"], a["ease"], str(a["colour_on"])])
	return ";".join(parts)


func _rebuild(c: Clip) -> void:
	PmUI.clear(_list)
	_fields = {}
	var n: int = TextAnimators.count(c.props)
	if n == 0:
		var note: Label = PmLabel.wrap("No letter animation. Add one to move, turn, fade or colour the text one letter, word or line at a time.", "text_faint")
		_list.add_child(note)
		return
	for i: int in n:
		_list.add_child(_animator_box(c, i))


func _animator_box(c: Clip, i: int) -> Control:
	var a: Dictionary = TextAnimators.animator(c.props, i)
	var box: VBoxContainer = PmUI.vbox(Tk.px(2.0))
	box.name = "Animator%d" % i
	var head: HBoxContainer = PmUI.hbox(Tk.px(2.0))
	var shut: bool = is_folded(i)
	var fold: Button = PmButton.make("", "chev_r" if shut else "chev_d")
	fold.name = "Fold_%d" % i
	fold.set("quiet", true)
	PmUI.tip(fold, "Show or hide this animator's settings")
	fold.pressed.connect(_on_fold.bind(i))
	head.add_child(fold)
	var on: Button = PmButton.ghost(String(a["name"]), "", true)
	on.button_pressed = bool(a["on"])
	on.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PmUI.tip(on, "Turn this animator on or off")
	on.toggled.connect(_on_toggle_on.bind(i))
	head.add_child(on)
	for spec: Array in [["chev_u", "Move it up", -1], ["chev_d", "Move it down", 1]]:
		var mv: Button = PmButton.make("", String(spec[0]))
		mv.set("quiet", true)
		PmUI.tip(mv, String(spec[1]))
		mv.pressed.connect(_on_move.bind(i, int(spec[2])))
		head.add_child(mv)
	var rm: Button = PmButton.make("", "trash")
	rm.set("quiet", true)
	PmUI.tip(rm, "Remove this animator")
	rm.pressed.connect(_on_remove.bind(i))
	head.add_child(rm)
	box.add_child(head)
	var body: VBoxContainer = PmUI.vbox(Tk.px(2.0))
	body.name = "Body_%d" % i
	body.visible = not shut
	box.add_child(body)
	var drops: HBoxContainer = PmUI.hbox(Tk.px(2.0))
	drops.add_child(_drop(i, "units", TextAnimators.UNITS, TextAnimators.UNIT_LABELS, String(a["units"]), "What counts as one: a letter, a word or a line"))
	drops.add_child(_drop(i, "shape", TextAnimators.SHAPES, TextAnimators.SHAPE_LABELS, String(a["shape"]), "How the selection is shaped across the text"))
	drops.add_child(_drop(i, "ease", TextAnimators.EASES, TextAnimators.EASE_LABELS, String(a["ease"]), "How the edges of the selection soften"))
	body.add_child(drops)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", Tk.px(4.0))
	for spec2: Array in NUMBERS:
		var field: String = String(spec2[0])
		if (field == "frequency" and String(a["shape"]) != "wave") or (field == "seed" and String(a["shape"]) != "random"):
			continue
		grid.add_child(PmLabel.body(String(spec2[1])))
		var f: Control = PmField.make(number_of(a, field), float(spec2[2]), float(spec2[3]), float(spec2[4]), String(spec2[5]))
		f.name = "Field_%d_%s" % [i, field]
		f.set("turns", field == "rotation")
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f.connect("value_changed", _on_number.bind(i, field))
		f.connect("edit_ended", _on_edit_ended)
		grid.add_child(f)
		var k: Button = PmButton.make("", "diamond", true)
		k.name = "Key_%d_%s" % [i, field]
		k.set("quiet", true)
		k.button_pressed = is_keyed(c, i, field)
		PmUI.tip(k, "Keyframe this at the playhead")
		k.toggled.connect(_on_key.bind(i, field))
		grid.add_child(k)
		_fields[str(i) + "|" + field] = [f, k]
	body.add_child(grid)
	var colour_row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	var col_on: CheckBox = CheckBox.new()
	col_on.text = "Colour"
	col_on.button_pressed = bool(a["colour_on"])
	col_on.focus_mode = Control.FOCUS_NONE
	col_on.toggled.connect(_on_colour_on.bind(i))
	colour_row.add_child(col_on)
	var picker: ColorPickerButton = ColorPickerButton.new()
	picker.name = "Colour_%d" % i
	picker.color = TextAnimators.colour(a["colour"])
	picker.custom_minimum_size = Vector2(float(Tk.px(48.0)), float(Tk.px(20.0)))
	picker.popup_closed.connect(_on_colour_closed.bind(picker, i))
	colour_row.add_child(picker)
	body.add_child(colour_row)
	box.add_child(PmUI.divider())
	return box


func fold_key(i: int) -> String:
	return clip_id + "|" + str(i)


func is_folded(i: int) -> bool:
	return bool(_folded.get(fold_key(i), false))


func set_folded(i: int, shut: bool) -> void:
	_folded[fold_key(i)] = shut
	var body: Control = _list.find_child("Body_%d" % i, true, false) as Control
	if body != null:
		body.visible = not shut
	var fold: Button = _list.find_child("Fold_%d" % i, true, false) as Button
	if fold != null:
		fold.set("icon_name", "chev_r" if shut else "chev_d")
		fold.queue_redraw()


func _on_fold(i: int) -> void:
	set_folded(i, not is_folded(i))


func _drop(i: int, field: String, ids: PackedStringArray, labels: PackedStringArray, value: String, tip: String) -> Button:
	var choices: Array = []
	for n: int in ids.size():
		choices.append(PmDrop.choice(ids[n], labels[n]))
	var d: Button = PmDrop.make_drop(choices, value)
	d.name = "Drop_%d_%s" % [i, field]
	PmUI.tip(d, tip)
	d.connect("changed", _on_drop.bind(i, field))
	return d


static func number_of(a: Dictionary, field: String) -> float:
	if field == "pos_x":
		return TextAnimators.vec(a["pos"]).x
	if field == "pos_y":
		return -TextAnimators.vec(a["pos"]).y
	return float(a[field])


static func prop_field(field: String) -> String:
	return "pos" if field == "pos_x" or field == "pos_y" else field


func is_keyed(c: Clip, i: int, field: String) -> bool:
	var v: Variant = c.props.get(TextAnimators.key(i, prop_field(field)))
	if not (v is Dictionary) or not AnimProp.is_animated(v):
		return false
	var s: Sequence = seq()
	if s == null:
		return false
	return AnimProp.find_key(v, c.param_time("props." + TextAnimators.key(i, prop_field(field)), s.playhead - c.start)) >= 0


func _refresh_values(c: Clip) -> void:
	for i: int in TextAnimators.count(c.props):
		var a: Dictionary = TextAnimators.animator(c.props, i)
		var s: Sequence = seq()
		var live: Dictionary = c.props_at(s.playhead - c.start) if s != null else c.props
		var at: Dictionary = TextAnimators.animator(live, i)
		for spec: Array in NUMBERS:
			var field: String = String(spec[0])
			var pair: Variant = _fields.get(str(i) + "|" + field)
			if not (pair is Array):
				continue
			var f: Control = (pair as Array)[0]
			var k: Button = (pair as Array)[1]
			if not bool(f.get("_dragging")) and f.get("_editor") == null:
				f.set("value", number_of(at, field))
			k.set_pressed_no_signal(is_keyed(c, i, field))
		var picker: ColorPickerButton = _list.find_child("Colour_%d" % i, true, false) as ColorPickerButton
		if picker != null and not picker.get_popup().visible:
			picker.color = TextAnimators.colour(a["colour"])


func _write(i: int, field: String, value: Variant, live: bool) -> bool:
	var c: Clip = target()
	var s: Sequence = seq()
	if c == null or s == null:
		return false
	var path: String = "props." + TextAnimators.key(i, field)
	var cur: Variant = c.props.get(TextAnimators.key(i, field))
	var keyed: bool = cur is Dictionary and AnimProp.is_animated(cur)
	return Verbs.set_clip_param(_doc, s, clip_id, path, value, s.playhead if keyed else -1.0, live)


func _value_for(i: int, field: String, v: float) -> Variant:
	if field != "pos_x" and field != "pos_y":
		return v
	var c: Clip = target()
	var s: Sequence = seq()
	var live: Dictionary = c.props_at(s.playhead - c.start) if c != null and s != null else {}
	var p: Vector2 = TextAnimators.vec(TextAnimators.animator(live, i)["pos"])
	if field == "pos_x":
		p.x = v
	else:
		p.y = -v
	return [p.x, p.y]


func set_number(i: int, field: String, v: float) -> bool:
	return _write(i, prop_field(field), _value_for(i, field, v), false)


func _on_number(v: float, i: int, field: String) -> void:
	_write(i, prop_field(field), _value_for(i, field, v), true)


func _on_edit_ended() -> void:
	if _doc != null and _doc.undo.has_live():
		_doc.undo.commit_live(LIVE_LABEL)


func _on_key(on: bool, i: int, field: String) -> void:
	toggle_key(i, field, on)


func toggle_key(i: int, field: String, _on: bool) -> bool:
	var c: Clip = target()
	var s: Sequence = seq()
	if c == null or s == null:
		return false
	var k: String = TextAnimators.key(i, prop_field(field))
	var path: String = "props." + k
	var cur: Variant = c.props.get(k)
	if not (cur is Dictionary) or not AnimProp.is_animated(cur):
		var a: Dictionary = TextAnimators.animator(c.props_at(s.playhead - c.start), i)
		var v: Variant = a[prop_field(field)]
		var cmd: Command = ClipCmds.SetClipParam.new(seq_id, clip_id, path, AnimProp.set_key(AnimProp.make(v), c.param_time(path, s.playhead - c.start), v))
		return Verbs.run(_doc, "Keyframe", [cmd] as Array[Command])
	return Verbs.toggle_keyframe(_doc, s, clip_id, path, s.playhead)


func _on_drop(id: String, i: int, field: String) -> void:
	set_choice(i, field, id)


func set_choice(i: int, field: String, id: String) -> bool:
	return _write(i, field, id, false)


func _on_colour_on(on: bool, i: int) -> void:
	_write(i, "colour_on", on, false)


func _on_colour_closed(picker: ColorPickerButton, i: int) -> void:
	var c: Color = picker.color
	_write(i, "colour", [c.r, c.g, c.b, c.a], false)


func _on_toggle_on(on: bool, i: int) -> void:
	_write(i, "on", on, false)


func _set_props(next: Dictionary, label: String) -> bool:
	var c: Clip = target()
	if c == null:
		return false
	return Verbs.run(_doc, label, [ClipCmds.SetClipField.new(seq_id, clip_id, "props", next)] as Array[Command])


func add(preset_id: String = "") -> bool:
	var c: Clip = target()
	if c == null:
		return false
	for n: int in TextAnimators.count(c.props):
		_folded[fold_key(n)] = true
	var s: Sequence = seq()
	return _set_props(TextPresets.applied(c.props, preset_id, c, s.fps if s != null else 30.0), "Add letter animation")


func remove(i: int) -> bool:
	var c: Clip = target()
	return c != null and _set_props(TextAnimators.with_removed(c.props, i), "Remove letter animation")


func _on_remove(i: int) -> void:
	remove(i)


func _on_move(i: int, step: int) -> void:
	var c: Clip = target()
	if c != null:
		_set_props(TextAnimators.with_moved(c.props, i, step), "Reorder letter animation")


func add_items() -> Array:
	var out: Array = [PmMenu.item("ta:blank", "Blank animator")]
	out.append(PmMenu.separator())
	for p: Dictionary in TextPresets.listing():
		out.append(PmMenu.item("ta:" + String(p["id"]), String(p["label"])))
	return out


func _on_add_pressed() -> void:
	var menu: Control = PmMenu.open(_add_btn, add_items())
	if menu != null and menu.is_inside_tree():
		menu.connect("picked", _on_add_picked)


func open_browser() -> Node:
	if _doc == null or target() == null:
		return null
	var script: GDScript = load(SHEET_PATH)
	if script == null:
		return null
	return script.call("open", self, _doc, seq_id, clip_id)


func _on_browse_pressed() -> void:
	open_browser()


func _on_add_picked(id: String) -> void:
	if not id.begins_with("ta:"):
		return
	var which: String = id.substr(3)
	add("" if which == "blank" else which)

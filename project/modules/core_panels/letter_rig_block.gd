extends VBoxContainer
## The Letter rig section of a title's Effect Controls: turn posing on, choose what a click picks, and set or key
## the selected letters, words or lines. Also stagger their keys, copy and paste poses, and reset them.

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Verbs := preload("res://doc/verbs.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const LetterRig := preload("res://doc/letter_rig.gd")
const Pose := preload("res://modules/core_panels/monitor_letter_pose.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")

## [prop field, component (-1 whole), label, min, max, step, suffix]
const ROWS: Array = [
	["pos", 0, "Position X", -4000.0, 4000.0, 1.0, " px"],
	["pos", 1, "Position Y", -4000.0, 4000.0, 1.0, " px"],
	["rot", -1, "Rotation", -3600.0, 3600.0, 1.0, "°"],
	["scale", 0, "Scale width", -1000.0, 1000.0, 1.0, " %"],
	["scale", 1, "Scale height", -1000.0, 1000.0, 1.0, " %"],
	["opacity", -1, "Opacity", 0.0, 100.0, 1.0, " %"],
	["skew", -1, "Skew", -80.0, 80.0, 1.0, "°"],
	["blur", -1, "Blur", 0.0, 200.0, 0.5, " px"],
	["pivot", 0, "Pivot X", -4000.0, 4000.0, 1.0, " px"],
	["pivot", 1, "Pivot Y", -4000.0, 4000.0, 1.0, " px"],
]
const LABEL_W := 96.0
const FIELD_W := 70.0

var panel: Object = null
var clip_id: String = ""
var _stamp: String = ""
var _pose_btn: Button = null
var _pick_btns: Dictionary = {}
var _name: Label = null
var _hint: Label = null
var _fields: Dictionary = {}
var _keys: Dictionary = {}
var _colour: ColorRect = null
var _tint_field: Control = null
var _rows_box: VBoxContainer = null
var _step: Control = null
var _order: Button = null
var _live: bool = false
var _colour_window: Control = null


static func make(host: Object, id: String) -> Control:
	var script: GDScript = load("res://modules/core_panels/letter_rig_block.gd")
	var b: VBoxContainer = script.new()
	b.set("panel", host)
	b.set("clip_id", id)
	b.name = "LetterRigBlock"
	b.call("_build")
	return b


func _doc() -> Project:
	return Session.doc


func _seq() -> Sequence:
	return Session.seq()


func target() -> Clip:
	var s: Sequence = _seq()
	return s.clip_by_id(clip_id) if s != null else null


func _program() -> Object:
	var bus: Object = Bus.instance()
	return bus.call("panel", "program") if bus != null else null


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


func text_now() -> String:
	var raw: Variant = LetterRig.plain(props_now().get("text", ""))
	return String(raw) if raw is String else ""


## The bones the section edits: the posing selection when it is for this clip.
func bones() -> PackedStringArray:
	if Pose.clip_id != clip_id:
		return PackedStringArray()
	return Pose.selected


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
	var top: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	_pose_btn = PmButton.make("Pose on the picture", "", true)
	_pose_btn.name = "PoseToggle"
	_pose_btn.toggled.connect(_on_pose)
	PmUI.tip(_pose_btn, "Click letters on the Program monitor to pick them, then drag to move, the round knob to turn and the corners to scale. Every change makes a keyframe at the playhead")
	top.add_child(_pose_btn)
	col.add_child(top)
	var picks: HBoxContainer = PmUI.hbox(Tk.px(2.0))
	picks.add_child(_label("Click picks"))
	for i: int in Pose.PICKS.size():
		var b: Button = PmButton.make(Pose.PICK_LABELS[i], "", true)
		b.name = "Pick_" + Pose.PICKS[i]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_pick.bind(Pose.PICKS[i]))
		picks.add_child(b)
		_pick_btns[Pose.PICKS[i]] = b
	col.add_child(picks)
	_name = PmLabel.trim("", "text_bright")
	col.add_child(_name)
	_hint = PmLabel.wrap("Turn on posing, then click letters on the picture. Shift adds more, double-click picks a word, triple-click a line, Ctrl+A picks them all.", "text_dim")
	col.add_child(_hint)
	_rows_box = PmUI.vbox(Tk.px(3.0))
	col.add_child(_rows_box)
	for r: Array in ROWS:
		_rows_box.add_child(_value_row(r))
	_rows_box.add_child(_colour_row())
	var acts: HFlowContainer = HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", Tk.px(4.0))
	acts.add_theme_constant_override("v_separation", Tk.px(4.0))
	for a: Array in [["Key pose", "key_pose", "Keyframe every value of the selected parts at the playhead"], ["Rest pose", "rest_pose", "Key the selected parts back at rest at the playhead"], ["Copy pose", "copy_pose", "Copy the selected parts' pose (Ctrl+C on the picture)"], ["Paste pose", "paste_pose", "Paste the copied pose at the playhead (Ctrl+V on the picture)"], ["Clear keys", "clear", "Remove every rig value and keyframe from the selected parts"]]:
		var ab: Button = PmButton.make(String(a[0]))
		ab.name = "Act_" + String(a[1])
		ab.focus_mode = Control.FOCUS_NONE
		ab.pressed.connect(_on_act.bind(String(a[1])))
		PmUI.tip(ab, String(a[2]))
		acts.add_child(ab)
	_rows_box.add_child(acts)
	col.add_child(PmLabel.trim("Stagger", "text_bright"))
	var st: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	st.add_child(_label("Each one later by"))
	_step = PmField.make(2.0, 0.0, 600.0, 1.0, " fr")
	_step.name = "StaggerStep"
	_step.custom_minimum_size.x = float(Tk.px(FIELD_W))
	st.add_child(_step)
	var orders: Array = []
	for i2: int in LetterRig.STAGGER_ORDERS.size():
		orders.append(PmDrop.choice(LetterRig.STAGGER_ORDERS[i2], LetterRig.STAGGER_LABELS[i2]))
	_order = PmDrop.make_drop(orders, "forward")
	_order.name = "StaggerOrder"
	st.add_child(_order)
	var go: Button = PmButton.make("Stagger")
	go.name = "Act_stagger"
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(_on_act.bind("stagger"))
	PmUI.tip(go, "Spread the keys of the selected parts (or every keyed letter when nothing is picked) so each starts a little after the one before")
	st.add_child(go)
	col.add_child(st)
	refresh(true)


func _label(text: String) -> Label:
	var l: Label = PmLabel.trim(text, "text_dim")
	l.custom_minimum_size.x = float(Tk.px(LABEL_W))
	return l


func _value_row(r: Array) -> Control:
	var h: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	var id: String = String(r[0]) + ":" + str(int(r[1]))
	h.add_child(_label(String(r[2])))
	var f: Control = PmField.make(0.0, float(r[3]), float(r[4]), float(r[5]), String(r[6]))
	f.name = "Field_" + id.replace(":", "_")
	f.custom_minimum_size.x = float(Tk.px(FIELD_W))
	f.connect("value_changed", _on_field.bind(String(r[0]), int(r[1])))
	f.connect("edit_begun", _on_begun)
	f.connect("edit_ended", _on_ended)
	h.add_child(f)
	_fields[id] = f
	if not _keys.has(String(r[0])):
		h.add_child(_key_btn(String(r[0])))
	return h


func _colour_row() -> Control:
	var h: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	h.add_child(_label("Colour"))
	var sw: Button = PmButton.make("", "", false)
	sw.name = "TintSwatch"
	sw.custom_minimum_size = Vector2(float(Tk.px(28.0)), float(Tk.px(20.0)))
	_colour = ColorRect.new()
	_colour.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colour.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_colour.offset_left = 3
	_colour.offset_top = 3
	_colour.offset_right = -3
	_colour.offset_bottom = -3
	sw.add_child(_colour)
	sw.pressed.connect(_on_swatch.bind(sw))
	h.add_child(sw)
	_tint_field = PmField.make(0.0, 0.0, 100.0, 1.0, " %")
	_tint_field.name = "Field_tint_3"
	_tint_field.custom_minimum_size.x = float(Tk.px(FIELD_W))
	_tint_field.connect("value_changed", _on_field.bind("tint", 3))
	_tint_field.connect("edit_begun", _on_begun)
	_tint_field.connect("edit_ended", _on_ended)
	PmUI.tip(_tint_field, "How strongly the colour covers the letters")
	h.add_child(_tint_field)
	h.add_child(_key_btn("tint"))
	return h


func _key_btn(field: String) -> Button:
	var b: Button = PmButton.make("", "stopwatch", true)
	b.set("quiet", true)
	b.set("icon_px", 12.0)
	b.name = "Key_" + field
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(float(Tk.px(20.0)), float(Tk.px(20.0)))
	b.pressed.connect(toggle_key.bind(field))
	PmUI.tip(b, "Add or remove a keyframe here for the selected parts")
	_keys[field] = b
	return b


func _process(_dt: float) -> void:
	if not is_visible_in_tree():
		return
	refresh(false)


func refresh(force: bool) -> void:
	var d: Project = _doc()
	var s: Sequence = _seq()
	if d == null or s == null:
		return
	var st: String = str(d.serial) + ":" + str(s.playhead) + ":" + str(Pose.serial) + ":" + clip_id
	if st == _stamp and not force:
		return
	_stamp = st
	_pose_btn.set_pressed_no_signal(Pose.on)
	for k: String in _pick_btns.keys():
		(_pick_btns[k] as Button).set_pressed_no_signal(k == Pose.pick)
	var bs: PackedStringArray = bones()
	_name.text = Pose.selection_name(text_now()) if not bs.is_empty() else ""
	_name.visible = not bs.is_empty()
	_hint.visible = bs.is_empty()
	_rows_box.visible = not bs.is_empty()
	if bs.is_empty():
		return
	var props: Dictionary = props_now()
	var first: String = bs[0]
	for r: Array in ROWS:
		var id: String = String(r[0]) + ":" + str(int(r[1]))
		var v: Variant = LetterRig.value(props, first, String(r[0]))
		var num: float = float(LetterRig.vec(v)[int(r[1])]) if int(r[1]) >= 0 else float(v)
		_set_field(_fields[id], num)
	var tint: Color = LetterRig.colour(LetterRig.value(props, first, "tint"))
	_colour.color = Color(tint.r, tint.g, tint.b, 1.0)
	_set_field(_tint_field, tint.a * 100.0)
	var c: Clip = target()
	for f: String in _keys.keys():
		(_keys[f] as Button).set_pressed_no_signal(c != null and AnimProp.is_animated(c.get_param("props." + LetterRig.key(first, f))))


func _set_field(f: Control, v: float) -> void:
	if f == null or bool(f.get("_dragging")) or f.get("_editor") != null:
		return
	f.set("value", v)


func _on_pose(v: bool) -> void:
	Pose.clip_id = clip_id
	Pose.set_on(v)
	refresh(true)


func _on_pick(p: String) -> void:
	Pose.set_pick(p)
	if not Pose.on:
		Pose.clip_id = clip_id
		Pose.set_on(true)
	refresh(true)


## Writes one value (or one component of a pair or colour) to every selected part, keyed at the playhead.
func set_value(field: String, comp: int, v: float, live: bool) -> bool:
	var bs: PackedStringArray = bones()
	if bs.is_empty():
		return false
	var props: Dictionary = props_now()
	var writes: Dictionary = {}
	for b: String in bs:
		var cur: Variant = LetterRig.value(props, b, field)
		var next: Variant = v
		if field == "tint":
			var c: Color = LetterRig.colour(cur)
			c[comp] = clampf(v / 100.0, 0.0, 1.0) if comp == 3 else v
			next = [c.r, c.g, c.b, c.a]
		elif comp >= 0:
			var p: Vector2 = LetterRig.vec(cur)
			p[comp] = v
			next = [p.x, p.y]
		writes[LetterRig.key(b, field)] = next
	return Pose.write_keys(_program_or_self(), writes, live, "Set " + LetterRig.field_label(field).to_lower())


## write_keys needs doc(), seq(); this block answers them itself so it works with or without the Program panel.
func _program_or_self() -> Object:
	return self


func doc() -> Project:
	return _doc()


func seq() -> Sequence:
	return _seq()


func _on_field(v: float, field: String, comp: int) -> void:
	Pose.clip_id = clip_id
	set_value(field, comp, v, _live)


func _on_begun() -> void:
	_live = true


func _on_ended() -> void:
	_live = false
	var d: Project = _doc()
	if d != null and d.undo.has_live():
		d.undo.commit_live("Set letter rig")


func toggle_key(field: String) -> bool:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var c: Clip = target()
	var bs: PackedStringArray = bones()
	if d == null or s == null or c == null or bs.is_empty():
		return false
	var props: Dictionary = props_now()
	var first_path: String = "props." + LetterRig.key(bs[0], field)
	var first: Dictionary = c.get_param(first_path)
	var removing: bool = AnimProp.is_animated(first) and AnimProp.find_key(first, c.param_time(first_path, s.playhead - c.start)) >= 0
	var cmds: Array[Command] = []
	for b: String in bs:
		var path: String = "props." + LetterRig.key(b, field)
		var p: Dictionary = c.get_param(path)
		var lt: float = c.param_time(path, s.playhead - c.start)
		var next: Dictionary
		if removing:
			if not AnimProp.is_animated(p) or AnimProp.find_key(p, lt) < 0:
				continue
			next = AnimProp.remove_key(p, lt)
		else:
			var v: Variant = LetterRig.value(props, b, field)
			next = AnimProp.set_key(p if not p.is_empty() else AnimProp.make(v), lt, v)
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, path, next))
	var ok: bool = Verbs.run(d, "Remove keyframe" if removing else "Keyframe", cmds)
	refresh(true)
	return ok


func key_pose() -> bool:
	var bs: PackedStringArray = bones()
	var props: Dictionary = props_now()
	var writes: Dictionary = {}
	for b: String in bs:
		for f: String in ["pos", "rot", "scale", "opacity"]:
			writes[LetterRig.key(b, f)] = LetterRig.value(props, b, f)
	return _key_all(writes, "Key pose")


func rest_pose() -> bool:
	var writes: Dictionary = {}
	for b: String in bones():
		for f: String in ["pos", "rot", "scale", "opacity", "skew"]:
			writes[LetterRig.key(b, f)] = LetterRig.default_of(f)
	return _key_all(writes, "Rest pose")


## Keys values even when they equal what is already there, so a pose can be held.
func _key_all(writes: Dictionary, label: String) -> bool:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var c: Clip = target()
	if d == null or s == null or c == null or writes.is_empty():
		return false
	var cmds: Array[Command] = []
	for k: Variant in writes.keys():
		var path: String = "props." + String(k)
		var p: Dictionary = c.get_param(path)
		var v: Variant = writes[k]
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, path, AnimProp.set_key(p if not p.is_empty() else AnimProp.make(v), c.param_time(path, s.playhead - c.start), v)))
	var ok: bool = Verbs.run(d, label, cmds)
	refresh(true)
	return ok


func clear_keys() -> bool:
	var c: Clip = target()
	var bs: PackedStringArray = bones()
	if c == null or bs.is_empty():
		return false
	return _set_props(LetterRig.without(c.props, bs), "Clear letter keys")


func stagger(step_frames: float = -1.0, order: String = "") -> bool:
	var c: Clip = target()
	var s: Sequence = _seq()
	if c == null or s == null:
		return false
	var frames: float = step_frames if step_frames >= 0.0 else float(_step.get("value"))
	var how: String = order if not order.is_empty() else String(_order.get("value"))
	var bs: PackedStringArray = bones()
	if bs.is_empty():
		for b: String in LetterRig.bones_in(c.props):
			if LetterRig.kind_of(b) == "c" and not LetterRig.key_times(c.props, b).is_empty():
				bs.append(b)
	bs = LetterRig.sorted(bs)
	var keyed: PackedStringArray = PackedStringArray()
	for b2: String in bs:
		if not LetterRig.key_times(c.props, b2).is_empty():
			keyed.append(b2)
	if keyed.size() < 2:
		return false
	return _set_props(LetterRig.staggered(c.props, keyed, frames / maxf(s.fps, 1.0), how), "Stagger letter keys")


func _set_props(next: Dictionary, label: String) -> bool:
	var d: Project = _doc()
	var s: Sequence = _seq()
	if d == null or s == null:
		return false
	var ok: bool = Verbs.run(d, label, [ClipCmds.SetClipField.new(s.id, clip_id, "props", next)] as Array[Command])
	refresh(true)
	return ok


func _on_act(id: String) -> void:
	Pose.clip_id = clip_id
	match id:
		"key_pose":
			key_pose()
		"rest_pose":
			rest_pose()
		"copy_pose":
			Pose.copy_pose(props_now())
		"paste_pose":
			Pose.paste_pose(self)
			refresh(true)
		"clear":
			clear_keys()
		"stagger":
			stagger()


func _on_swatch(anchor: Control) -> void:
	if bones().is_empty():
		return
	if _colour_window != null and is_instance_valid(_colour_window):
		_colour_window.call("close")
	var picker: ColorPicker = ColorPicker.new()
	var t: Color = LetterRig.colour(LetterRig.value(props_now(), bones()[0], "tint"))
	picker.color = Color(t.r, t.g, t.b, 1.0)
	picker.edit_alpha = false
	picker.color_changed.connect(_on_colour)
	var root: Node = get_tree().root.find_child("EditorScreen", true, false)
	_colour_window = PmWindow.open(root if root != null else self, "Letter colour", picker, Vector2(300.0, 420.0), "controls.colour")
	if _colour_window != null:
		_colour_window.call("place_at", anchor.global_position + Vector2(0.0, anchor.size.y))


func _on_colour(col: Color) -> void:
	Pose.clip_id = clip_id
	var bs: PackedStringArray = bones()
	var props: Dictionary = props_now()
	var writes: Dictionary = {}
	for b: String in bs:
		var cur: Color = LetterRig.colour(LetterRig.value(props, b, "tint"))
		var strength: float = cur.a if cur.a > 0.0005 else 1.0
		writes[LetterRig.key(b, "tint")] = [col.r, col.g, col.b, strength]
	Pose.write_keys(self, writes, false, "Letter colour")
	refresh(true)

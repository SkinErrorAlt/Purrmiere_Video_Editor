extends VBoxContainer

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const Verbs := preload("res://doc/verbs.gd")
const ViewMap := preload("res://doc/view_map.gd")
const ViewOffsets := preload("res://doc/view_offsets.gd")
const NamedOffsets := preload("res://doc/named_offsets.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const HEAD_TIP := "Name the offset between two views, one for each direction. Match then lines the views up at every cut from one into the other"
const EMPTY_NOTE := "No named offsets yet. Line two views up at a cut, then Add from this cut"
const ADD_LABEL := "Add from this cut"
const MATCH_ONE := "Match this cut"
const MATCH_ALL := "Match every cut"
const AUTO_LABEL := "Match new cuts by themselves"
const LIST_LABEL := "Named offset"

var clip_id: String = ""
var uid: String = ""
var _status: Label = null
var _list_box: VBoxContainer = null
var _auto: CheckBox = null
var _stamp: String = ""
var last_note: String = ""


static func make(c: Clip, e: Dictionary) -> Control:
	var script: GDScript = load("res://modules/core_panels/named_offset_rows.gd")
	var b: VBoxContainer = script.new()
	b.name = "NamedOffsets"
	b.set("clip_id", c.id)
	b.set("uid", String(e.get("uid", "")))
	b.call("_build")
	return b


func _doc() -> Project:
	return Session.doc


func _seq() -> Sequence:
	return Session.seq()


func clip() -> Clip:
	var s: Sequence = _seq()
	return s.clip_by_id(clip_id) if s != null else null


func entry() -> Dictionary:
	var c: Clip = clip()
	return c.effect_by_uid(uid) if c != null else {}


func local_now() -> float:
	var c: Clip = clip()
	var s: Sequence = _seq()
	if c == null or s == null:
		return 0.0
	return clampf(s.playhead - c.start, 0.0, maxf(c.duration, 0.0))


func cut_now() -> int:
	var c: Clip = clip()
	var e: Dictionary = entry()
	if c == null or e.is_empty():
		return -1
	return ViewOffsets.cut_index_at(ViewOffsets.cuts_of(e, c), local_now())


func _build() -> void:
	add_theme_constant_override("separation", Tk.px(4.0))
	var pad: float = float(Tk.px(Tk.sz("button_h")))
	var head: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	head.add_child(_gap(pad))
	var title: Label = PmLabel.trim("Named offsets", "text_bright")
	PmUI.tip(title, HEAD_TIP)
	head.add_child(title)
	var add: Button = PmButton.make(ADD_LABEL, "plus")
	add.name = "AddNamed"
	add.set("quiet", true)
	PmUI.tip(add, "Saves the offset between the view before this cut and this one, under a name, for this direction")
	add.pressed.connect(add_from_cut)
	head.add_child(add)
	add_child(head)
	_list_box = PmUI.vbox(Tk.px(3.0))
	add_child(_list_box)
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row.add_child(_gap(pad))
	var one: Button = PmButton.make(MATCH_ONE)
	one.name = "MatchOne"
	PmUI.tip(one, "Lines up the cut the playhead is in, using the named offset for its direction")
	one.pressed.connect(func() -> void: match_cuts(true))
	row.add_child(one)
	var all: Button = PmButton.make(MATCH_ALL)
	all.name = "MatchAll"
	PmUI.tip(all, "Lines up every cut in this clip, each with the named offset for its own direction")
	all.pressed.connect(func() -> void: match_cuts(false))
	row.add_child(all)
	add_child(row)
	var row2: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row2.add_child(_gap(pad))
	_auto = CheckBox.new()
	_auto.name = "MatchAuto"
	_auto.text = AUTO_LABEL
	_auto.focus_mode = Control.FOCUS_NONE
	PmUI.tip(_auto, "Every time you switch view, the new cut is lined up with the named offset for that direction straight away")
	_auto.toggled.connect(set_auto)
	row2.add_child(_auto)
	add_child(row2)
	var row3: HBoxContainer = PmUI.hbox(0)
	row3.add_child(_gap(pad))
	_status = PmLabel.dim("")
	row3.add_child(_status)
	add_child(row3)
	refresh(true)


func _gap(w: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(w, 0.0)
	return c


func _process(_dt: float) -> void:
	if is_visible_in_tree():
		refresh(false)


func refresh(force: bool) -> void:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var e: Dictionary = entry()
	if d == null or s == null or e.is_empty():
		return
	var st: String = str(d.serial) + ":" + str(cut_now())
	if st == _stamp and not force:
		return
	_stamp = st
	_auto.set_pressed_no_signal(NamedOffsets.auto_on(e))
	_rebuild_list(e)
	var c: Clip = clip()
	var cuts: Array[Dictionary] = ViewOffsets.cuts_of(e, c)
	var k: int = cut_now()
	var names: PackedStringArray = ViewMap.region_names(e)
	if k < 1 or k >= cuts.size():
		_status.text = "The playhead is in the first cut, which has nothing before it" if cuts.size() > 1 else "This clip has no view changes yet"
		return
	var a: int = int(cuts[k - 1]["view"])
	var b: int = int(cuts[k]["view"])
	var named: Dictionary = NamedOffsets.find(NamedOffsets.list_of(e), a, b)
	var now_ms: float = NamedOffsets.measured_ms(e, c, k)
	var dir: String = _name(names, a) + " into " + _name(names, b)
	if named.is_empty():
		_status.text = "Cut %d is %s, lined up at %+.0f ms, no named offset for that way yet" % [k + 1, dir, now_ms]
	else:
		var want: float = float(named["ms"])
		var ok: bool = absf(want - now_ms) < 0.5
		_status.text = "Cut %d is %s, %+.0f ms%s" % [k + 1, dir, now_ms, ", matched" if ok else ", " + NamedOffsets.label_for(e, named) + " wants %+.0f ms" % want]


func _name(names: PackedStringArray, i: int) -> String:
	return names[i] if i >= 0 and i < names.size() else "View " + str(i + 1)


func _rebuild_list(e: Dictionary) -> void:
	for ch: Node in _list_box.get_children():
		_list_box.remove_child(ch)
		ch.queue_free()
	var list: Array[Dictionary] = NamedOffsets.list_of(e)
	var pad: float = float(Tk.px(Tk.sz("button_h")))
	if list.is_empty():
		var r0: HBoxContainer = PmUI.hbox(0)
		r0.add_child(_gap(pad))
		r0.add_child(PmLabel.dim(EMPTY_NOTE))
		_list_box.add_child(r0)
		return
	var names: PackedStringArray = ViewMap.region_names(e)
	var choices: Array = []
	for i: int in names.size():
		choices.append(PmDrop.choice(str(i), names[i]))
	for i2: int in list.size():
		var d: Dictionary = list[i2]
		var r: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		r.name = "Named" + str(i2)
		r.add_child(_gap(pad))
		var le: LineEdit = PmUI.line_edit("Name", String(d["name"]))
		le.custom_minimum_size.x = float(Tk.px(150.0))
		le.placeholder_text = NamedOffsets.label_for(e, d)
		le.text_submitted.connect(func(t: String) -> void: edit(i2, "name", t))
		le.focus_exited.connect(func() -> void: edit(i2, "name", le.text))
		r.add_child(le)
		var fd: Button = PmDrop.make_drop(choices, str(int(d["from"])))
		fd.custom_minimum_size.x = float(Tk.px(80.0))
		fd.connect("changed", func(id: String) -> void: edit(i2, "from", int(id)))
		PmUI.tip(fd, "Cutting from this view")
		r.add_child(fd)
		r.add_child(PmLabel.dim("into"))
		var td: Button = PmDrop.make_drop(choices, str(int(d["into"])))
		td.custom_minimum_size.x = float(Tk.px(80.0))
		td.connect("changed", func(id: String) -> void: edit(i2, "into", int(id)))
		PmUI.tip(td, "Into this view, which is the one that moves")
		r.add_child(td)
		var f: Control = PmField.make(float(d["ms"]), -NamedOffsets.MS_MAX, NamedOffsets.MS_MAX, 1.0, " ms")
		f.set("precision", 1)
		f.custom_minimum_size.x = float(Tk.px(84.0))
		f.connect("value_changed", func(v: float) -> void: edit(i2, "ms", v))
		PmUI.tip(f, "How far the second view sits from the first when cutting this way")
		r.add_child(f)
		var take: Button = PmButton.make("Take")
		take.set("quiet", true)
		PmUI.tip(take, "Take this value from the cut the playhead is in, when it goes this way")
		take.pressed.connect(func() -> void: take_from_cut(i2))
		r.add_child(take)
		var del: Button = PmButton.make("", "trash")
		del.set("quiet", true)
		PmUI.tip(del, "Remove this named offset")
		del.pressed.connect(func() -> void: remove(i2))
		r.add_child(del)
		_list_box.add_child(r)


func _write_list(list: Array, label: String) -> bool:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var c: Clip = clip()
	var e: Dictionary = entry()
	if d == null or s == null or c == null or e.is_empty():
		return false
	var cmds: Array[Command] = [NamedOffsets.list_command(s, c, e, list)]
	var ok: bool = Verbs.run(d, label, cmds)
	refresh(true)
	return ok


func add_from_cut() -> bool:
	var c: Clip = clip()
	var e: Dictionary = entry()
	if c == null or e.is_empty():
		return false
	var cuts: Array[Dictionary] = ViewOffsets.cuts_of(e, c)
	var k: int = cut_now()
	if k < 1 or k >= cuts.size():
		last_note = "Put the playhead in a cut that comes after a view change first"
		Events.toast(last_note)
		return false
	var a: int = int(cuts[k - 1]["view"])
	var b: int = int(cuts[k]["view"])
	var list: Array[Dictionary] = NamedOffsets.list_of(e)
	var ms: float = NamedOffsets.measured_ms(e, c, k)
	for i: int in list.size():
		if int(list[i]["from"]) == a and int(list[i]["into"]) == b:
			list[i]["ms"] = ms
			last_note = "Updated " + NamedOffsets.label_for(e, list[i])
			return _write_list(list, "Update named offset")
	var names: PackedStringArray = ViewMap.region_names(e)
	list.append({"name": _name(names, a) + " into " + _name(names, b), "from": a, "into": b, "ms": ms})
	last_note = "Added " + _name(names, a) + " into " + _name(names, b)
	return _write_list(list, "Add named offset")


func edit(index: int, field: String, value: Variant) -> bool:
	var e: Dictionary = entry()
	var list: Array[Dictionary] = NamedOffsets.list_of(e)
	if index < 0 or index >= list.size():
		return false
	if list[index].get(field) == value:
		return false
	list[index][field] = value
	return _write_list(list, "Change named offset")


func take_from_cut(index: int) -> bool:
	var c: Clip = clip()
	var e: Dictionary = entry()
	var list: Array[Dictionary] = NamedOffsets.list_of(e)
	var cuts: Array[Dictionary] = ViewOffsets.cuts_of(e, c)
	var k: int = cut_now()
	if index < 0 or index >= list.size() or k < 1 or k >= cuts.size():
		return false
	if int(cuts[k - 1]["view"]) != int(list[index]["from"]) or int(cuts[k]["view"]) != int(list[index]["into"]):
		last_note = "The cut the playhead is in goes the other way, or between other views"
		Events.toast(last_note)
		return false
	list[index]["ms"] = NamedOffsets.measured_ms(e, c, k)
	return _write_list(list, "Take named offset from cut")


func remove(index: int) -> bool:
	var e: Dictionary = entry()
	var list: Array[Dictionary] = NamedOffsets.list_of(e)
	if index < 0 or index >= list.size():
		return false
	list.remove_at(index)
	return _write_list(list, "Remove named offset")


func match_cuts(only_here: bool) -> int:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var c: Clip = clip()
	var e: Dictionary = entry()
	if d == null or s == null or c == null or e.is_empty():
		return 0
	var k: int = cut_now() if only_here else -1
	if only_here and k < 1:
		last_note = "The playhead is in the first cut, which has nothing before it"
		Events.toast(last_note)
		return 0
	var matched: Array = []
	var cmds: Array[Command] = []
	for mc: Clip in group_clips():
		for me: Dictionary in ViewOffsets.pair_entries(mc):
			var mk: int = k
			if only_here and mc != c:
				mk = ViewOffsets.cut_index_at(ViewOffsets.cuts_of(me, mc), clampf(s.playhead - mc.start, 0.0, maxf(mc.duration, 0.0)))
				if mk < 1:
					continue
			var me_list: Array[Dictionary] = NamedOffsets.list_of(me)
			var use: Dictionary = me
			if me_list.is_empty() and mc != c:
				use = me.duplicate(true)
				(use["params"] as Dictionary)[NamedOffsets.KEY] = NamedOffsets.encode(NamedOffsets.list_of(e))
			matched.append_array((NamedOffsets.plan(use, mc, mk)["matched"] as Array))
			cmds.append_array(NamedOffsets.match_commands(s, mc, use, mk))
	if matched.is_empty():
		last_note = "No named offset fits " + ("this cut" if only_here else "any cut") + " yet"
		Events.toast(last_note)
		return 0
	if not cmds.is_empty():
		Verbs.run(d, MATCH_ONE if only_here else MATCH_ALL, cmds)
	last_note = ("Matched cut %d" % (k + 1)) if only_here else ("Matched %d cuts" % matched.size())
	Events.toast(last_note)
	refresh(true)
	return matched.size()


func group_clips() -> Array[Clip]:
	var out: Array[Clip] = []
	var s: Sequence = _seq()
	var c: Clip = clip()
	if c == null or s == null:
		return out
	out.append(c)
	if s.selected_clip_ids.size() > 1 and s.selected_clip_ids.has(c.id):
		for oc: Clip in ViewOffsets.pair_clips(s, s.selected_clip_ids):
			if oc != c:
				out.append(oc)
	return out


func set_auto(on: bool) -> bool:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var c: Clip = clip()
	var e: Dictionary = entry()
	if d == null or s == null or c == null or e.is_empty():
		return false
	var cmds: Array[Command] = [NamedOffsets.auto_command(s, c, e, on)]
	var ok: bool = Verbs.run(d, "Match new cuts" if on else "Stop matching new cuts", cmds)
	refresh(true)
	return ok

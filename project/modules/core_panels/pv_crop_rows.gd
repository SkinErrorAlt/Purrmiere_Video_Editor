extends RefCounted

const Clip := preload("res://doc/clip.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const LayoutCmds := preload("res://doc/commands/pair_layout_cmds.gd")
const PairCrop := preload("res://engine/pair_crop.gd")
const MonitorHandles := preload("res://modules/core_panels/monitor_handles.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const LABEL := "Crop region"
const FREE_LABEL := "Four corners"
const MONITOR_LABEL := "Crop on the monitor"
const FREE_TIP := "Let each corner of the crop go anywhere, so the shape does not have to be a rectangle. Holding Alt while dragging a corner on the Program monitor does the same"
const MONITOR_TIP := "Show the crop boxes of every region on the Program monitor to drag them (the same as the handles switch in the header)"
const ROW_TIP := "Cut the edges off what this view shows, in percent of the region. The picture stays where it is on screen"
const FIELD_PX := 64.0
const CORNER_PX := 52.0


static func make(c: Clip, uid: String, index: int, indent: float) -> Control:
	var box: VBoxContainer = PmUI.vbox(0)
	box.name = "PvCrop" + str(index)
	if c == null:
		return box
	var clip_id: String = c.id
	var cut: Variant = PairCrop.cut_of(c.effect_by_uid(uid), index)
	var free: bool = PairCrop.is_free(cut)
	var ev: PackedFloat64Array = PairCrop.edges(cut)
	var row: HBoxContainer = _row(indent)
	var lab: Label = PmLabel.dim("Crop")
	lab.custom_minimum_size.x = float(Tk.px(60.0))
	PmUI.tip(lab, ROW_TIP)
	row.add_child(lab)
	for k: int in 4:
		var f: Control = PmField.make(ev[k] * 100.0, 0.0, 100.0, 0.5, " %")
		f.set("precision", 1)
		f.custom_minimum_size.x = float(Tk.px(FIELD_PX))
		f.connect("value_changed", func(v: float) -> void: set_edge(clip_id, uid, index, k, v / 100.0))
		PmUI.tip(f, PairCrop.EDGE_NAMES[k] + " crop")
		row.add_child(f)
	var four: Button = PmButton.make(FREE_LABEL, "", true)
	four.set("quiet", true)
	four.button_pressed = free
	PmUI.tip(four, FREE_TIP)
	four.toggled.connect(func(on: bool) -> void: set_free(clip_id, uid, index, on))
	row.add_child(four)
	var show: Button = PmButton.make(MONITOR_LABEL)
	show.set("quiet", true)
	PmUI.tip(show, MONITOR_TIP)
	show.pressed.connect(func() -> void: show_on_monitor(clip_id, uid))
	row.add_child(show)
	box.add_child(row)
	if free:
		var q: PackedVector2Array = PairCrop.quad(cut)
		var row2: HBoxContainer = _row(indent)
		var lab2: Label = PmLabel.dim("Corners")
		lab2.custom_minimum_size.x = float(Tk.px(60.0))
		row2.add_child(lab2)
		for i: int in 4:
			for axis: int in 2:
				var f2: Control = PmField.make((q[i].x if axis == 0 else q[i].y) * 100.0, 0.0, 100.0, 0.5, "")
				f2.set("precision", 1)
				f2.custom_minimum_size.x = float(Tk.px(CORNER_PX))
				f2.connect("value_changed", func(v: float) -> void: set_corner(clip_id, uid, index, i, axis, v / 100.0))
				PmUI.tip(f2, PairCrop.CORNER_NAMES[i] + (" across" if axis == 0 else " down") + ", percent of the region")
				row2.add_child(f2)
		box.add_child(row2)
	return box


static func make_many(clips: Array[Clip], uids: Dictionary, index: int, indent: float) -> Control:
	var box: VBoxContainer = PmUI.vbox(0)
	box.name = "ManyPvCrop" + str(index)
	var pairs: Dictionary = {}
	var first: Variant = null
	var mixed: bool = false
	var all_free: bool = true
	for c: Clip in clips:
		var uid: String = String(uids.get(c.id, ""))
		var e: Dictionary = c.effect_by_uid(uid)
		if e.is_empty():
			continue
		var cut: Variant = PairCrop.cut_of(e, index)
		if pairs.is_empty():
			first = cut
		elif str(cut) != str(first):
			mixed = true
		all_free = all_free and PairCrop.is_free(cut)
		pairs[c.id] = uid
	if pairs.is_empty():
		box.visible = false
		return box
	var ev: PackedFloat64Array = PairCrop.edges(first)
	var row: HBoxContainer = _row(indent)
	var lab: Label = PmLabel.dim("Crop")
	lab.custom_minimum_size.x = float(Tk.px(60.0))
	PmUI.tip(lab, ROW_TIP + ". Typing a value sets that side on every selected clip that has this region")
	row.add_child(lab)
	for k: int in 4:
		var f: Control = PmField.make(ev[k] * 100.0, 0.0, 100.0, 0.5, " %")
		f.set("precision", 1)
		f.custom_minimum_size.x = float(Tk.px(FIELD_PX))
		f.connect("value_changed", func(v: float) -> void: set_edge_many(pairs, index, k, v / 100.0))
		PmUI.tip(f, PairCrop.EDGE_NAMES[k] + " crop, on every selected clip")
		row.add_child(f)
	var four: Button = PmButton.make(FREE_LABEL, "", true)
	four.set("quiet", true)
	four.name = "ManyFourCorners"
	four.button_pressed = all_free
	PmUI.tip(four, FREE_TIP)
	four.toggled.connect(func(on: bool) -> void: set_free_many(pairs, index, on))
	row.add_child(four)
	var show: Button = PmButton.make(MONITOR_LABEL)
	show.set("quiet", true)
	show.name = "ManyCropOnMonitor"
	PmUI.tip(show, MONITOR_TIP + ". The boxes show on the selected clip under the playhead")
	show.pressed.connect(func() -> void: show_many(pairs))
	row.add_child(show)
	if mixed:
		row.add_child(PmLabel.dim("mixed"))
	box.add_child(row)
	return box


static func write_many(d: Project, s: Sequence, pairs: Dictionary, index: int, change: Callable) -> bool:
	if d == null or s == null:
		return false
	var cmds: Array[Command] = []
	for cid: Variant in pairs.keys():
		var c: Clip = s.clip_by_id(String(cid))
		var uid: String = String(pairs[cid])
		if c == null or c.effect_by_uid(uid).is_empty():
			continue
		var e: Dictionary = c.effect_by_uid(uid)
		if index >= PairCrop.raw_list(PairCrop.crops_text(e)).size():
			continue
		var was: String = PairCrop.crops_text(e)
		var text: String = PairCrop.text_with_cut(was, index, change.call(PairCrop.cut_of(e, index)))
		if text == was:
			continue
		var cmd: ClipCmds.SetClipParam = ClipCmds.SetClipParam.new(s.id, c.id, LayoutCmds.path_of(uid, "crops"), AnimProp.make(text))
		cmd.label = LABEL
		cmds.append(cmd)
	if cmds.is_empty():
		return false
	return Verbs.run(d, LABEL, cmds)


static func set_edge_many(pairs: Dictionary, index: int, side: int, value: float) -> bool:
	return write_many(Session.doc, Session.seq(), pairs, index, func(cut: Variant) -> Variant: return edge_cut(cut, side, value))


static func set_free_many(pairs: Dictionary, index: int, on: bool) -> bool:
	return write_many(Session.doc, Session.seq(), pairs, index, func(cut: Variant) -> Variant: return free_cut(cut, on))


static func show_many(pairs: Dictionary) -> void:
	for cid: Variant in pairs.keys():
		MonitorHandles.set_focus(String(cid), String(pairs[cid]), true)
	Events.toast("The crop boxes show on the Program monitor for the selected clip under the playhead. Alt drags one corner on its own")


static func _row(indent: float) -> HBoxContainer:
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	var lead: Control = Control.new()
	lead.custom_minimum_size = Vector2(indent, 0.0)
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lead)
	return row


static func write_cut(d: Project, s: Sequence, clip_id: String, uid: String, index: int, cut: Variant) -> bool:
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null:
		return false
	var e: Dictionary = c.effect_by_uid(uid)
	var was: String = PairCrop.crops_text(e)
	var text: String = PairCrop.text_with_cut(was, index, cut)
	if text == was:
		return false
	var cmd: ClipCmds.SetClipParam = ClipCmds.SetClipParam.new(s.id, c.id, LayoutCmds.path_of(uid, "crops"), AnimProp.make(text))
	cmd.label = LABEL
	return Verbs.run(d, LABEL, [cmd])


static func edge_cut(cut: Variant, side: int, value: float) -> Variant:
	var ev: PackedFloat64Array = PairCrop.edges(cut)
	var next: PackedFloat64Array = ev.duplicate()
	next[side] = value
	var tidy: PackedFloat64Array = PackedFloat64Array(PairCrop.tidy_edges(next))
	if not PairCrop.is_free(cut):
		return PairCrop.as_edges(tidy)
	var from: Rect2 = PairCrop.bounds(PairCrop.quad(cut))
	var to: Rect2 = PairCrop.bounds(PairCrop.quad_of_edges(tidy))
	var pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in PairCrop.quad(cut):
		var u: Vector2 = (p - from.position) / Vector2(maxf(from.size.x, 0.000001), maxf(from.size.y, 0.000001))
		pts.append(to.position + u * to.size)
	return PairCrop.tidy_quad(pts)


static func set_edge(clip_id: String, uid: String, index: int, side: int, value: float) -> bool:
	var s: Sequence = Session.seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c == null:
		return false
	return write_cut(Session.doc, s, clip_id, uid, index, edge_cut(PairCrop.cut_of(c.effect_by_uid(uid), index), side, value))


static func set_corner(clip_id: String, uid: String, index: int, corner: int, axis: int, value: float) -> bool:
	var s: Sequence = Session.seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c == null:
		return false
	var q: PackedVector2Array = PairCrop.quad(PairCrop.cut_of(c.effect_by_uid(uid), index))
	var p: Vector2 = q[corner]
	if axis == 0:
		p.x = value
	else:
		p.y = value
	q[corner] = p
	return write_cut(Session.doc, s, clip_id, uid, index, PairCrop.tidy_quad(q))


static func free_cut(cut: Variant, on: bool) -> Variant:
	if on:
		return PairCrop.as_free(cut)
	return PairCrop.as_edges(cut)


static func set_free(clip_id: String, uid: String, index: int, on: bool) -> bool:
	var s: Sequence = Session.seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c == null:
		return false
	return write_cut(Session.doc, s, clip_id, uid, index, free_cut(PairCrop.cut_of(c.effect_by_uid(uid), index), on))


static func show_on_monitor(clip_id: String, uid: String) -> void:
	MonitorHandles.set_focus(clip_id, uid, true)
	Events.toast("The crop boxes show on the Program monitor while the clip is selected under the playhead. Alt drags one corner on its own")

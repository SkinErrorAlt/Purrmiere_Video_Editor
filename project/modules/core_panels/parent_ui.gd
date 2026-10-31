extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Parenting := preload("res://doc/parenting.gd")
const Command := preload("res://doc/commands/command.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const Icons := preload("res://ui/kit/icons.gd")
const SELF_PATH := "res://modules/core_panels/parent_ui.gd"
const PUPPET_PATH := "res://doc/puppet.gd"
const PREFIX := "parent:"
const PIN_PREFIX := "parent_pin:"
const MENU_REMOVE := "parent_remove"
const MENU_WHIP := "parent_whip"
const MENU_KEEP := "parent_keep"
const MENU_PIN_ROT := "parent_pin_rot"
const MENU_SUB := "parent_to"
const MENU_OTHER := "parent_other"
const WHIP_DRAG_MIN := 4.0
const WHIP_LINE := "ParentWhipLine"
const BADGE_INK := Color(1.0, 1.0, 1.0, 0.85)
const DRAG_TIP := "Drag onto the clip this one should follow, in the timeline or on its picture in the Program. A click picks it on the Program instead"
const LIST_MAX := 40
const NONE_TEXT := "None"
const WHIP_TIP := "Click the clip this one should follow on the Program monitor. Right click or Esc cancels"
const LINE_INK := Color(1.0, 1.0, 1.0, 0.6)
const LINE_SHADOW := Color(0.0, 0.0, 0.0, 0.45)
const DASH := 5.0
const END_RING := 4.0

static var keep_in_place: bool = true
static var turn_with_pin: bool = true
static var whip_child: String = ""
static var whip_group: PackedStringArray = PackedStringArray()
static var whip_mouse: Vector2 = Vector2(-1.0, -1.0)
static var drag_group: PackedStringArray = PackedStringArray()
static var drag_from: Vector2 = Vector2.ZERO
static var drag_to: Vector2 = Vector2.ZERO
static var drag_moved: bool = false
static var drag_line: Control = null
static var badges_drawn: int = 0


static func key(c: Clip) -> String:
	return "" if c == null or c.parent.is_empty() else str(c.parent.hash())


static func _script() -> GDScript:
	return load(SELF_PATH)


static func candidates(s: Sequence, c: Clip) -> Array[Clip]:
	var near: Array[Clip] = []
	var far: Array[Clip] = []
	if s == null or c == null:
		return near
	for tr: Track in s.picture_tracks():
		for o: Clip in tr.clips:
			if o == c or not tr.is_picture(o) or Parenting.would_cycle(s, c.id, o.id):
				continue
			if o.start < c.end() and o.end() > c.start:
				near.append(o)
			else:
				far.append(o)
	near.append_array(far)
	if near.size() > LIST_MAX:
		near.resize(LIST_MAX)
	return near


static func pin_count(c: Clip) -> int:
	if not ResourceLoader.exists(PUPPET_PATH):
		return 0
	var Puppet: GDScript = load(PUPPET_PATH)
	if Puppet == null:
		return 0
	return int(Puppet.call("pin_count_of", c))


static func on_screen(d: Project, s: Sequence, c: Clip) -> Array[Clip]:
	var out: Array[Clip] = []
	if s == null or c == null:
		return out
	var pick: GDScript = load("res://modules/core_panels/monitor_pick.gd")
	var here: Array = pick.call("candidates", s, d, s.playhead)
	for v: Variant in here:
		var o: Clip = v as Clip
		if o == null or o == c or Parenting.would_cycle(s, c.id, o.id):
			continue
		out.append(o)
	return out


static func _target_items(d: Project, s: Sequence, c: Clip, list: Array[Clip]) -> Array:
	var items: Array = []
	var current: String = Parenting.parent_id(c)
	var cur_pin: int = Parenting.pin_of(c)
	for o: Clip in list:
		var tr: Track = s.track_of(o.id)
		var where: String = "  (" + s.display_label(tr) + ")" if tr != null else ""
		items.append(PmMenu.check_item(PREFIX + o.id, Parenting.name_of(d, o) + where, current == o.id and cur_pin < 0))
		var pins: int = pin_count(o)
		for i: int in pins:
			items.append(PmMenu.check_item(PIN_PREFIX + o.id + ":" + str(i), "    pin " + str(i + 1) + " of " + Parenting.name_of(d, o), current == o.id and cur_pin == i))
	return items


static func parent_to_items(d: Project, s: Sequence, c: Clip) -> Array:
	var shown: Array[Clip] = on_screen(d, s, c)
	var items: Array = _target_items(d, s, c, shown)
	if items.is_empty():
		var none: Dictionary = PmMenu.item("parent_none", "No other picture on screen at the playhead")
		none["disabled"] = true
		items.append(none)
	var rest: Array[Clip] = []
	for o: Clip in candidates(s, c):
		if not shown.has(o):
			rest.append(o)
	if not rest.is_empty():
		items.append(PmMenu.separator())
		items.append(PmMenu.sub_item(MENU_OTHER, "Other clips", _target_items(d, s, c, rest)))
	items.append(PmMenu.separator())
	items.append(PmMenu.item(MENU_WHIP, "Pick the parent on the Program monitor", "", "target"))
	items.append(PmMenu.check_item(MENU_KEEP, "Keep in place when parenting", keep_in_place))
	items.append(PmMenu.check_item(MENU_PIN_ROT, "Turn with the pin when following a pin", turn_with_pin))
	return items


static func menu_items(d: Project, s: Sequence, c: Clip, with_remove: bool) -> Array:
	var items: Array = []
	var current: String = Parenting.parent_id(c)
	var cur_pin: int = Parenting.pin_of(c)
	for o: Clip in candidates(s, c):
		var tr: Track = s.track_of(o.id)
		var where: String = "  (" + s.display_label(tr) + ")" if tr != null else ""
		items.append(PmMenu.check_item(PREFIX + o.id, Parenting.name_of(d, o) + where, current == o.id and cur_pin < 0))
		var pins: int = pin_count(o)
		for i: int in pins:
			items.append(PmMenu.check_item(PIN_PREFIX + o.id + ":" + str(i), "    pin " + str(i + 1) + " of " + Parenting.name_of(d, o), current == o.id and cur_pin == i))
	if items.is_empty():
		var none: Dictionary = PmMenu.item("parent_none", "No other picture clips in this sequence")
		none["disabled"] = true
		items.append(none)
	items.append(PmMenu.separator())
	items.append(PmMenu.item(MENU_WHIP, "Pick the parent on the Program monitor", "", "target"))
	items.append(PmMenu.check_item(MENU_KEEP, "Keep in place when parenting", keep_in_place))
	items.append(PmMenu.check_item(MENU_PIN_ROT, "Turn with the pin when following a pin", turn_with_pin))
	if with_remove and not current.is_empty():
		items.append(PmMenu.separator())
		items.append(PmMenu.item(MENU_REMOVE, "Remove parent"))
	return items


static func clip_menu_items(c: Clip) -> Array:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	var items: Array = []
	if d == null or s == null or c == null:
		return items
	var tr: Track = s.track_of(c.id)
	if tr == null or not tr.is_picture(c):
		return items
	items.append(PmMenu.sub_item(MENU_SUB, "Parent to", parent_to_items(d, s, c), "chain"))
	if Parenting.is_parented(c):
		items.append(PmMenu.item(MENU_REMOVE, "Unparent"))
	return items


static func owns(id: String) -> bool:
	return id.begins_with(PREFIX) or id.begins_with(PIN_PREFIX) or id == MENU_REMOVE or id == MENU_WHIP or id == MENU_KEEP or id == MENU_PIN_ROT


static func on_menu(id: String, clip_id: String) -> bool:
	return on_menu_many(id, PackedStringArray([clip_id]))


static func on_menu_many(id: String, clip_ids: PackedStringArray) -> bool:
	if not owns(id):
		return false
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null or s == null:
		return true
	var why: String = ""
	if id == MENU_KEEP:
		keep_in_place = not keep_in_place
		Events.toast("Parenting keeps clips in place" if keep_in_place else "Parenting reads the clip's values in the parent's space")
	elif id == MENU_PIN_ROT:
		turn_with_pin = not turn_with_pin
		Events.toast("Clips following a pin turn with it" if turn_with_pin else "Clips following a pin only move with it")
	elif id == MENU_WHIP:
		whip_start_many(clip_ids)
	elif id == MENU_REMOVE:
		why = apply(d, s, clip_ids, "", -1)
	elif id.begins_with(PIN_PREFIX):
		var rest: PackedStringArray = id.substr(PIN_PREFIX.length()).rsplit(":", true, 1)
		if rest.size() == 2:
			why = apply(d, s, clip_ids, rest[0], int(rest[1]))
	else:
		why = apply(d, s, clip_ids, id.substr(PREFIX.length()), -1)
	if not why.is_empty():
		Events.toast(why)
	_redraw_program()
	return true


static func apply(d: Project, s: Sequence, clip_ids: PackedStringArray, parent_id: String, pin: int) -> String:
	var cmds: Array[Command] = []
	var refused: PackedStringArray = PackedStringArray()
	for id: String in clip_ids:
		if parent_id.is_empty():
			cmds.append_array(Parenting.unlink_commands(s, id, keep_in_place))
			continue
		if id == parent_id:
			continue
		var why: String = Parenting.refusal(d, s, id, parent_id)
		if not why.is_empty():
			refused.append(why)
			continue
		cmds.append_array(Parenting.link_commands(s, id, parent_id, keep_in_place, pin, pin >= 0 and turn_with_pin))
	if cmds.is_empty():
		if not refused.is_empty():
			return refused[0]
		return "That clip has no parent" if parent_id.is_empty() else "Nothing to parent"
	var label: String = "Remove parent" if parent_id.is_empty() else "Parent to " + Parenting.name_of(d, s.clip_by_id(parent_id))
	Parenting.run(d, label, cmds)
	return refused[0] if not refused.is_empty() else ""


static func on_clip_menu(id: String, clip_id: String) -> bool:
	return on_menu_many(id, group_for(clip_id))


static func group_for(clip_id: String) -> PackedStringArray:
	var s: Sequence = Session.seq()
	if s == null or not s.selected_clip_ids.has(clip_id):
		return PackedStringArray([clip_id])
	var out: PackedStringArray = PackedStringArray([clip_id])
	for id: String in s.selected_clip_ids:
		var tr: Track = s.track_of(id)
		var o: Clip = s.clip_by_id(id)
		if id != clip_id and o != null and tr != null and tr.is_picture(o):
			out.append(id)
	return out


static func row(c: Clip, label_w: float, many: Array = []) -> Control:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	var ids: PackedStringArray = PackedStringArray([c.id])
	var mixed: bool = false
	if not many.is_empty():
		ids = PackedStringArray()
		for mv: Variant in many:
			var m: Clip = mv as Clip
			if m == null:
				continue
			ids.append(m.id)
			if Parenting.parent_id(m) != Parenting.parent_id(c) or Parenting.pin_of(m) != Parenting.pin_of(c):
				mixed = true
	var box: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	box.custom_minimum_size = Vector2(0.0, float(Tk.px(Tk.sz("row_h"))) + 2.0)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(float(Tk.px(Tk.sz("button_h"))), 0.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)
	var label: Label = PmLabel.trim("Parent")
	label.custom_minimum_size = Vector2(label_w, 0.0)
	box.add_child(label)
	var p: Clip = Parenting.parent_of(c, s)
	var text: String = NONE_TEXT
	if p != null:
		text = Parenting.name_of(d, p)
		if Parenting.pin_of(c) >= 0:
			text += ", pin " + str(Parenting.pin_of(c) + 1)
	elif Parenting.is_parented(c):
		text = "Missing clip"
	if mixed:
		text = "Mixed"
	var pick: Button = PmButton.make(text, "chain")
	pick.set("quiet", true)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.clip_text = true
	PmUI.tip(pick, "The clip this one follows: it moves, turns and scales with it, round its own anchor point")
	pick.pressed.connect(_script().open_menu.bind(pick, ids))
	box.add_child(pick)
	box.add_child(whip_handle(ids))
	var drop: Button = PmButton.make("", "close")
	drop.set("quiet", true)
	PmUI.tip(drop, "Remove parent")
	drop.visible = Parenting.is_parented(c) or mixed
	drop.pressed.connect(_script().on_menu_many.bind(MENU_REMOVE, ids))
	box.add_child(drop)
	return box


static func open_menu(anchor: Control, clip_ids: PackedStringArray) -> void:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	var c: Clip = s.clip_by_id(clip_ids[0]) if s != null and not clip_ids.is_empty() else null
	if c == null:
		return
	var m: Control = PmMenu.open(anchor, menu_items(d, s, c, true))
	if m != null:
		m.connect("picked", _script().on_menu_many.bind(clip_ids))


static func whip_start(clip_id: String) -> void:
	whip_start_many(PackedStringArray([clip_id]))


static func whip_start_many(clip_ids: PackedStringArray) -> void:
	whip_group = clip_ids
	whip_child = clip_ids[0] if not clip_ids.is_empty() else ""
	whip_mouse = Vector2(-1.0, -1.0)
	Events.toast(WHIP_TIP)
	_redraw_program()


static func whip_cancel() -> void:
	whip_child = ""
	_redraw_program()


static func _redraw_program() -> void:
	var bus: Object = load("res://modules/core_panels/panel_bus.gd").call("instance")
	var p: Object = bus.call("panel", "program") if bus != null else null
	var v: Variant = p.get("view") if p != null else null
	if v is Control and is_instance_valid(v):
		(v as Control).call("redraw_overlay")


static func whip_key(e: InputEventKey) -> bool:
	if whip_child.is_empty() or not e.pressed or e.keycode != KEY_ESCAPE:
		return false
	whip_cancel()
	return true


static func whip_input(event: InputEvent, pic: Rect2, panel: Object) -> bool:
	if whip_child.is_empty():
		return false
	if event is InputEventMouseMotion:
		whip_mouse = (event as InputEventMouseMotion).position
		panel.get("view").call("redraw_overlay")
		return true
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return event is InputEventMouseButton
	var mb: InputEventMouseButton = event
	var child_id: String = whip_child
	var group: PackedStringArray = whip_group if not whip_group.is_empty() else PackedStringArray([child_id])
	whip_child = ""
	whip_group = PackedStringArray()
	if mb.button_index != MOUSE_BUTTON_LEFT:
		panel.get("view").call("redraw_overlay")
		return true
	var target: String = ""
	for id: String in panel.call("hits_at", mb.position, pic):
		if not group.has(id):
			target = id
			break
	if target.is_empty():
		Events.toast("No other clip under the pointer, nothing was parented")
	else:
		var tc: Clip = (panel.call("seq") as Sequence).clip_by_id(target)
		var pin: int = int(load("res://modules/core_panels/puppet_ui.gd").call("_pin_near", panel, pic, tc, mb.position))
		var why: String = apply(panel.call("doc"), panel.call("seq"), group, target, pin)
		if not why.is_empty():
			Events.toast(why)
	panel.get("view").call("redraw_overlay")
	return true


static func parent_point(c: Clip, s: Sequence, d: Project, t: float) -> Vector2:
	var p: Clip = Parenting.parent_of(c, s)
	if p == null:
		return Vector2(INF, INF)
	var f: Transform2D = Parenting.link_frame(p, c.parent, s, t, s.fps, Parenting.token_of(d))
	return Vector2(float(s.width), float(s.height)) * 0.5 + f.origin


static func draw(ci: CanvasItem, pic: Rect2, panel: Object) -> void:
	var s: Sequence = panel.call("seq")
	var d: Project = panel.call("doc")
	if s == null or pic.size.x <= 0.0:
		return
	if not whip_child.is_empty():
		var wc: Clip = s.clip_by_id(whip_child)
		if wc != null and whip_mouse.x >= 0.0:
			var from_w: Vector2 = panel.call("_to_picture", pic, (panel.call("quad_for", wc) as Dictionary).get("pivot", Vector2.ZERO))
			_line(ci, from_w, whip_mouse)
		return
	for pair: Array in shown_links(s):
		var c: Clip = pair[0]
		var to_seq: Vector2 = parent_point(c, s, d, s.playhead)
		if not to_seq.is_finite():
			continue
		var from_seq: Vector2 = (panel.call("quad_for", c) as Dictionary).get("pivot", Vector2.ZERO)
		_line(ci, panel.call("_to_picture", pic, from_seq), panel.call("_to_picture", pic, to_seq))


static func shown_links(s: Sequence) -> Array:
	var out: Array = []
	if s == null or s.selected_clip_ids.is_empty():
		return out
	for c: Clip in s.all_clips():
		if c.parent.is_empty() or s.playhead < c.start or s.playhead >= c.end():
			continue
		var p: Clip = Parenting.parent_of(c, s)
		if p == null:
			continue
		var tr: Track = s.track_of(c.id)
		if tr == null or not tr.is_picture(c):
			continue
		if s.selected_clip_ids.has(c.id) or s.selected_clip_ids.has(p.id):
			out.append([c, p])
	return out


static func draw_badge(ci: CanvasItem, c: Clip, r: Rect2) -> void:
	if c == null or c.parent.is_empty() or r.size.x < 30.0 or r.size.y < 14.0:
		return
	var box: Rect2 = Rect2(r.end.x - 14.0, r.end.y - 13.0, 10.0, 10.0)
	ci.draw_rect(box.grow(1.5), Color(0.0, 0.0, 0.0, 0.35), true)
	Icons.draw(ci, "chain", box, BADGE_INK)
	badges_drawn += 1


static func header_whip(c: Clip, many: Array = []) -> Button:
	var ids: PackedStringArray = PackedStringArray([c.id])
	if not many.is_empty():
		ids = PackedStringArray()
		for mv: Variant in many:
			var m: Clip = mv as Clip
			if m != null:
				ids.append(m.id)
	var b: Button = whip_handle(ids)
	b.name = "ParentWhipHeader"
	return b


static func whip_handle(ids: PackedStringArray) -> Button:
	var whip: Button = PmButton.make("", "target")
	whip.set("quiet", true)
	whip.name = "ParentWhip"
	PmUI.tip(whip, DRAG_TIP)
	whip.gui_input.connect(_script()._on_input.bind(whip, ids))
	return whip


static func _on_input(event: InputEvent, handle: Control, ids: PackedStringArray) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var at: Vector2 = handle.get_global_transform() * mb.position
		if mb.pressed:
			drag_begin(ids, at)
		else:
			drag_end(at)
		handle.accept_event()
	elif event is InputEventMouseMotion and not drag_group.is_empty():
		drag_move(handle.get_global_transform() * (event as InputEventMouseMotion).position)
		handle.accept_event()


static func dragging() -> bool:
	return not drag_group.is_empty()


static func drag_begin(ids: PackedStringArray, at: Vector2) -> void:
	drag_group = ids
	drag_from = at
	drag_to = at
	drag_moved = false


static func drag_move(at: Vector2) -> void:
	if drag_group.is_empty():
		return
	drag_to = at
	if not drag_moved and at.distance_to(drag_from) >= WHIP_DRAG_MIN:
		drag_moved = true
		_show_line()
	if drag_line != null and is_instance_valid(drag_line):
		drag_line.queue_redraw()


static func drag_end(at: Vector2) -> String:
	var group: PackedStringArray = drag_group
	var moved: bool = drag_moved
	drag_group = PackedStringArray()
	drag_moved = false
	_hide_line()
	if group.is_empty():
		return ""
	if not moved:
		whip_start_many(group)
		return ""
	var got: Dictionary = target_at(at, group)
	if got.is_empty():
		Events.toast("No clip under the pointer, nothing was parented")
		return "none"
	var why: String = apply(Session.doc, Session.seq(), group, String(got["clip"]), int(got.get("pin", -1)))
	if not why.is_empty():
		Events.toast(why)
	_redraw_program()
	return why


static func drag_cancel() -> void:
	drag_group = PackedStringArray()
	drag_moved = false
	_hide_line()


static func _show_line() -> void:
	_hide_line()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var host: Node = tree.get_first_node_in_group(PmUI.OVERLAY_GROUP)
	if host == null:
		host = tree.root
	var line: Control = Control.new()
	line.name = WHIP_LINE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.z_index = 100
	line.draw.connect(_script()._draw_drag.bind(line))
	host.add_child(line)
	drag_line = line


static func _hide_line() -> void:
	if drag_line != null and is_instance_valid(drag_line):
		var parent: Node = drag_line.get_parent()
		if parent != null:
			parent.remove_child(drag_line)
		drag_line.queue_free()
	drag_line = null


static func _draw_drag(line: Control) -> void:
	var inv: Transform2D = line.get_global_transform().affine_inverse()
	_line(line, inv * drag_from, inv * drag_to)


static func timeline_press(canvas: Control, h: Dictionary, mods: Dictionary, at: Vector2) -> bool:
	if not (bool(mods.get("ctrl", false)) and bool(mods.get("alt", false))) or bool(mods.get("shift", false)):
		return false
	var c: Clip = h.get("clip", null)
	var tr: Track = h.get("track", null)
	if c == null or tr == null or not tr.is_picture(c) or bool(h.get("nest", false)):
		return false
	drag_begin(group_for(c.id), canvas.get_global_transform() * at)
	return true


static func timeline_input(canvas: Control, event: InputEvent) -> bool:
	if drag_group.is_empty():
		return false
	if event is InputEventMouseMotion:
		drag_move(canvas.get_global_transform() * (event as InputEventMouseMotion).position)
		return true
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			var at: Vector2 = canvas.get_global_transform() * mb.position
			if not drag_moved:
				drag_cancel()
				return true
			drag_end(at)
			return true
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			drag_cancel()
			return true
	return false


static func target_at(at: Vector2, group: PackedStringArray) -> Dictionary:
	var bus: Object = load("res://modules/core_panels/panel_bus.gd").call("instance")
	if bus == null:
		return {}
	var s: Sequence = Session.seq()
	if s == null:
		return {}
	var tl: Object = bus.call("panel", "timeline")
	var canvas: Variant = tl.get("canvas") if tl != null else null
	if canvas is Control and is_instance_valid(canvas) and (canvas as Control).is_visible_in_tree() and (canvas as Control).get_global_rect().has_point(at):
		var cv: Control = canvas
		var h: Dictionary = cv.call("hit_at", cv.get_global_transform().affine_inverse() * at)
		var c: Clip = h.get("clip", null)
		var tr: Track = h.get("track", null)
		if c != null and tr != null and tr.is_picture(c) and not group.has(c.id) and not bool(h.get("nest", false)):
			return {"clip": c.id, "pin": -1}
		return {}
	var pp: Object = bus.call("panel", "program")
	var view: Variant = pp.get("view") if pp != null else null
	if view is Control and is_instance_valid(view) and (view as Control).is_visible_in_tree() and (view as Control).get_global_rect().has_point(at):
		var vw: Control = view
		var local: Vector2 = vw.get_global_transform().affine_inverse() * at
		var pic: Rect2 = vw.call("picture_rect")
		for id: String in pp.call("hits_at", local, pic):
			if group.has(id):
				continue
			var tc: Clip = s.clip_by_id(id)
			var pin: int = int(load("res://modules/core_panels/puppet_ui.gd").call("_pin_near", pp, pic, tc, local))
			return {"clip": id, "pin": pin}
	return {}


static func _line(ci: CanvasItem, a: Vector2, b: Vector2) -> void:
	ci.draw_dashed_line(a + Vector2.ONE, b + Vector2.ONE, LINE_SHADOW, 1.0, DASH)
	ci.draw_dashed_line(a, b, LINE_INK, 1.0, DASH)
	ci.draw_arc(b, END_RING, 0.0, TAU, 16, LINE_INK, 1.0, true)

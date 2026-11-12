extends RefCounted

const SELF := preload("res://modules/core_panels/pv_groups.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const PairCmds := preload("res://doc/commands/pair_cmds.gd")
const ViewMap := preload("res://doc/view_map.gd")
const ViewSwitch := preload("res://doc/view_switch.gd")
const SPLIT_TIP := "Splits the regions into two groups. Group picks the group, View switches inside group 1 and Group 2 view inside group 2, and each of the three keys on its own"
const CLEAR_TIP := "Puts every region back in one group, so View picks from all of them again"
const MOVE_TIP := "Moves this region to the other group"
const GROUP_TIP := "Shows this group from the playhead on, keeping the view it was on"
const SPLIT_MORE_TIP := "Splits the regions into %d groups, in order. Group picks the group and each group has its own view"
const ADD_TIP := "Makes one more group, up to four, from the last region of the biggest group"
const REGION_TIP := "Move this region to another group, or leave it out of every group"
const OUT_TIP := "This region is in no group, so no view switch reaches it. Click to put it back in a group"
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const MOVE_PREFIX := "pv_group_move:"
const NEW_GROUP := "new"
const LEAVE_OUT := "out"
const COUNT_WORDS: PackedStringArray = ["", "one", "two", "three", "four"]


static func _session() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Session")
	return null


static func _where() -> Dictionary:
	var s: Node = _session()
	if s == null:
		return {}
	var d: Variant = s.get("doc")
	var sq: Variant = s.call("seq")
	if not (d is Project) or not (sq is Sequence):
		return {}
	return {"doc": d, "seq": sq}


static func remap_cmds(s: Sequence, c: Clip, uid: String, new_count: int, remap: Dictionary) -> Array[Command]:
	var out: Array[Command] = []
	if s == null or c == null:
		return out
	var e: Dictionary = c.effect_by_uid(uid)
	if e.is_empty() or not ViewMap.grouped(e):
		return out
	var text: String = ViewMap.groups_text(e)
	var next: String = ViewMap.remap_groups(text, ViewMap.crop_count(e), remap, new_count)
	if next != text:
		out.append(EffectCmds.SetEffectParam.new(s.id, c.id, uid, ViewMap.GROUPS_KEY, next, -1.0))
	return out


static func set_groups(targets: Dictionary, make: String) -> bool:
	var w: Dictionary = _where()
	if w.is_empty():
		return false
	var s: Sequence = w["seq"]
	var cmds: Array[Command] = []
	for cid: Variant in targets.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var uid: String = String(targets[cid])
		var e: Dictionary = c.effect_by_uid(uid)
		if e.is_empty():
			continue
		var parts: int = parts_of(make)
		var want: String = ""
		if parts == 2:
			want = ViewMap.split_in_two(ViewMap.crop_count(e))
		elif parts > 2:
			want = ViewMap.split_in(ViewMap.crop_count(e), parts)
		if parts >= 2 and ViewMap.crop_count(e) < parts:
			continue
		if want == ViewMap.groups_text(e):
			continue
		cmds.append(EffectCmds.SetEffectParam.new(s.id, c.id, uid, ViewMap.GROUPS_KEY, want, -1.0))
	if cmds.is_empty():
		return false
	var parts2: int = parts_of(make)
	return Verbs.run(w["doc"], ("Split into " + COUNT_WORDS[parts2] + " groups") if parts2 >= 2 else "One group", cmds)


static func parts_of(make: String) -> int:
	if make == "split":
		return 2
	if make.begins_with("split") and make.substr(5).is_valid_int():
		return clampi(int(make.substr(5)), 2, ViewMap.GROUP_MAX)
	return 0


static func move_region_to(targets: Dictionary, region: int, group: int) -> bool:
	var w: Dictionary = _where()
	if w.is_empty():
		return false
	var s: Sequence = w["seq"]
	var cmds: Array[Command] = []
	for cid: Variant in targets.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var uid: String = String(targets[cid])
		var e: Dictionary = c.effect_by_uid(uid)
		if e.is_empty() or region >= ViewMap.crop_count(e):
			continue
		var text: String = ViewMap.groups_text(e)
		var next: String = ViewMap.moved_to(text, ViewMap.crop_count(e), region, mini(group, ViewMap.members(e).size()) if group >= 0 else -1)
		if next == text:
			continue
		cmds.append(EffectCmds.SetEffectParam.new(s.id, c.id, uid, ViewMap.GROUPS_KEY, next, -1.0))
	if cmds.is_empty():
		return false
	var label: String = "Leave the region out of every group" if group < 0 else "Move the region to group " + str(group + 1)
	return Verbs.run(w["doc"], label, cmds)


static func add_group(targets: Dictionary) -> bool:
	var w: Dictionary = _where()
	if w.is_empty():
		return false
	var s: Sequence = w["seq"]
	var cmds: Array[Command] = []
	for cid: Variant in targets.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var uid: String = String(targets[cid])
		var e: Dictionary = c.effect_by_uid(uid)
		if e.is_empty():
			continue
		var m: Array[PackedInt32Array] = ViewMap.members(e)
		if m.size() >= ViewMap.GROUP_MAX:
			continue
		var biggest: int = -1
		for g: int in m.size():
			if m[g].size() >= 2 and (biggest < 0 or m[g].size() >= m[biggest].size()):
				biggest = g
		if biggest < 0:
			continue
		var region: int = m[biggest][m[biggest].size() - 1]
		var next: String = ViewMap.moved_to(ViewMap.groups_text(e), ViewMap.crop_count(e), region, m.size())
		if next != ViewMap.groups_text(e):
			cmds.append(EffectCmds.SetEffectParam.new(s.id, c.id, uid, ViewMap.GROUPS_KEY, next, -1.0))
	if cmds.is_empty():
		return false
	return Verbs.run(w["doc"], "Add a group", cmds)


static func region_menu_items(e: Dictionary, region: int) -> Array:
	var items: Array = []
	var m: Array[PackedInt32Array] = ViewMap.members(e)
	var place: Vector2i = ViewMap.place_of(e, region)
	var grouped: bool = ViewMap.grouped(e)
	for g: int in m.size():
		if grouped and g == place.x:
			continue
		if not grouped and m.size() < 2:
			continue
		items.append(PmMenu.item(MOVE_PREFIX + str(g), "Move to group " + str(g + 1)))
	if m.size() < ViewMap.GROUP_MAX and (place.x < 0 or m[place.x].size() >= 2 or not grouped):
		items.append(PmMenu.item(MOVE_PREFIX + NEW_GROUP, "Move to a new group" if grouped else "Put it in a group of its own"))
	if place.x >= 0 and ViewMap.crop_count(e) >= 2:
		items.append(PmMenu.item(MOVE_PREFIX + LEAVE_OUT, "Leave out of every group"))
	return items


static func region_menu_picked(id: String, targets: Dictionary, region: int, group_count: int) -> bool:
	if not id.begins_with(MOVE_PREFIX):
		return false
	var what: String = id.substr(MOVE_PREFIX.length())
	if what == LEAVE_OUT:
		return move_region_to(targets, region, -1)
	if what == NEW_GROUP:
		return move_region_to(targets, region, group_count if group_count >= 2 else 1)
	return move_region_to(targets, region, int(what))


static func open_region_menu(anchor: Control, targets: Dictionary, e: Dictionary, region: int) -> Control:
	var items: Array = region_menu_items(e, region)
	if items.is_empty() or anchor == null or not anchor.is_inside_tree():
		return null
	var count: int = ViewMap.members(e).size() if ViewMap.grouped(e) else 1
	var menu: Control = PmMenu.open(anchor, items, anchor.global_position + Vector2(0.0, anchor.size.y))
	if menu != null:
		menu.connect("picked", func(id: String) -> void: region_menu_picked(id, targets, region, count))
	return menu


static func move_region(targets: Dictionary, region: int) -> bool:
	var w: Dictionary = _where()
	if w.is_empty():
		return false
	var s: Sequence = w["seq"]
	var cmds: Array[Command] = []
	for cid: Variant in targets.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var uid: String = String(targets[cid])
		var e: Dictionary = c.effect_by_uid(uid)
		if e.is_empty() or not ViewMap.grouped(e) or region >= ViewMap.crop_count(e):
			continue
		var place: Vector2i = ViewMap.place_of(e, region)
		var to: int = 1 if place.x == 0 else 0
		var next: String = ViewMap.moved_to(ViewMap.groups_text(e), ViewMap.crop_count(e), region, to)
		cmds.append(EffectCmds.SetEffectParam.new(s.id, c.id, uid, ViewMap.GROUPS_KEY, next, -1.0))
	if cmds.is_empty():
		return false
	return Verbs.run(w["doc"], "Move region to the other group", cmds)


static func switch_group(targets: Dictionary, group: int) -> bool:
	var w: Dictionary = _where()
	if w.is_empty():
		return false
	var s: Sequence = w["seq"]
	var cmds: Array[Command] = []
	var rec: bool = false
	var ses: Node = _session()
	if ses != null:
		rec = bool(ses.get("recording"))
	for cid: Variant in targets.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var e: Dictionary = c.effect_by_uid(String(targets[cid]))
		if e.is_empty() or group >= ViewMap.members(e).size():
			continue
		cmds.append(PairCmds.SwitchView.new(s.id, c.id, String(targets[cid]), group, s.playhead, rec, true))
	if cmds.is_empty():
		return false
	var ok: bool = Verbs.run(w["doc"], "Switch to group " + str(group + 1), cmds)
	if not ok:
		var events: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Events")
		if events != null:
			events.call("toast", ViewSwitch.why_text(String((cmds[0] as Object).get("why")), "group " + str(group + 1)))
	return ok


static func shown_group(s: Sequence, c: Clip, e: Dictionary) -> int:
	if s == null or c == null or e.is_empty():
		return -1
	var region: int = ViewSwitch.shown_view(s, c, e, s.playhead)
	return ViewMap.place_of(e, region).x


static func row(targets: Dictionary, lead_w: float) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "PairGroups"
	var w: Dictionary = _where()
	var s: Sequence = w.get("seq", null)
	var grouped: Array[Dictionary] = []
	var most: int = 0
	var texts: Dictionary = {}
	for cid: Variant in targets.keys():
		var c: Clip = s.clip_by_id(String(cid)) if s != null else null
		if c == null:
			continue
		var e: Dictionary = c.effect_by_uid(String(targets[cid]))
		if e.is_empty():
			continue
		most = maxi(most, ViewMap.crop_count(e))
		texts[ViewMap.groups_text(e)] = true
		if ViewMap.grouped(e):
			grouped.append({"clip": c, "entry": e})
	var head: HBoxContainer = PmUI.hbox(6)
	var lead: Control = Control.new()
	lead.custom_minimum_size.x = lead_w
	head.add_child(lead)
	head.add_child(PmLabel.dim("Groups"))
	if grouped.is_empty():
		var split: Button = PmButton.make("Split into two groups", "")
		split.set("quiet", true)
		split.name = "PairGroupsSplit"
		split.disabled = most < 2
		PmUI.tip(split, SPLIT_TIP)
		split.pressed.connect(Callable(SELF, "set_groups").bind(targets, "split"))
		head.add_child(split)
		for parts: int in [3, 4]:
			var more: Button = PmButton.make(COUNT_WORDS[parts].capitalize() + " groups", "")
			more.set("quiet", true)
			more.name = "PairGroupsSplit" + str(parts)
			more.disabled = most < parts
			PmUI.tip(more, SPLIT_MORE_TIP % parts)
			more.pressed.connect(Callable(SELF, "set_groups").bind(targets, "split" + str(parts)))
			head.add_child(more)
		head.add_child(PmUI.spacer())
		box.add_child(head)
		if texts.size() == 1:
			_region_lines(box, targets, s, lead_w)
		return box
	var lit: int = shown_group(s, grouped[0]["clip"], grouped[0]["entry"]) if grouped.size() == 1 else -1
	var count: int = ViewMap.members(grouped[0]["entry"]).size()
	for g: int in count:
		var b: Button = PmButton.make("Group " + str(g + 1), "")
		b.set("quiet", true)
		b.name = "PairGroupSwitch" + str(g)
		b.set("active", lit == g)
		b.disabled = count < 2
		PmUI.tip(b, GROUP_TIP)
		b.pressed.connect(Callable(SELF, "switch_group").bind(targets, g))
		head.add_child(b)
	head.add_child(PmUI.spacer())
	var add: Button = PmButton.make("Add a group", "plus")
	add.set("quiet", true)
	add.name = "PairGroupsAdd"
	add.disabled = count >= ViewMap.GROUP_MAX
	PmUI.tip(add, ADD_TIP)
	add.pressed.connect(Callable(SELF, "add_group").bind(targets))
	head.add_child(add)
	var clear: Button = PmButton.make("One group", "")
	clear.set("quiet", true)
	clear.name = "PairGroupsClear"
	PmUI.tip(clear, CLEAR_TIP)
	clear.pressed.connect(Callable(SELF, "set_groups").bind(targets, "clear"))
	head.add_child(clear)
	box.add_child(head)
	if texts.size() == 1 and grouped.size() == targets.size():
		_region_lines(box, targets, s, lead_w)
	return box


static func _lead(lead_w: float) -> Control:
	var lead2: Control = Control.new()
	lead2.custom_minimum_size.x = lead_w
	return lead2


static func _first_entry(targets: Dictionary, s: Sequence) -> Dictionary:
	for cid: Variant in targets.keys():
		var c: Clip = s.clip_by_id(String(cid)) if s != null else null
		if c != null and not c.effect_by_uid(String(targets[cid])).is_empty():
			return c.effect_by_uid(String(targets[cid]))
	return {}


static func _region_button(targets: Dictionary, e: Dictionary, r: int, text: String, tip: String) -> Button:
	var rb: Button = PmButton.make(text, "")
	rb.set("quiet", true)
	rb.name = "PairGroupRegion" + str(r)
	PmUI.tip(rb, tip)
	rb.pressed.connect(func() -> void: open_region_menu(rb, targets, e, r))
	return rb


static func _region_lines(box: VBoxContainer, targets: Dictionary, s: Sequence, lead_w: float) -> void:
	var e1: Dictionary = _first_entry(targets, s)
	if e1.is_empty() or ViewMap.crop_count(e1) < 2:
		return
	var names: PackedStringArray = ViewMap.region_names(e1)
	var m: Array[PackedInt32Array] = ViewMap.members(e1)
	var grouped: bool = ViewMap.grouped(e1)
	for g2: int in m.size():
		var line: HBoxContainer = PmUI.hbox(4)
		line.name = "PairGroupLine" + str(g2)
		line.add_child(_lead(lead_w))
		var title: String = "Group " + str(g2 + 1) + " (" + ("View" if g2 == 0 else "Group " + str(g2 + 1) + " view") + ")" if grouped and m.size() >= 2 else "Regions"
		line.add_child(PmLabel.dim(title))
		for pos: int in m[g2].size():
			var r: int = m[g2][pos]
			line.add_child(_region_button(targets, e1, r, str(pos) + ": " + (names[r] if r < names.size() else str(r + 1)), REGION_TIP))
		line.add_child(PmUI.spacer())
		box.add_child(line)
	var outside: PackedInt32Array = ViewMap.left_out(e1)
	if outside.is_empty():
		return
	var out_line: HBoxContainer = PmUI.hbox(4)
	out_line.name = "PairGroupLeftOut"
	out_line.add_child(_lead(lead_w))
	out_line.add_child(PmLabel.dim("In no group"))
	for r2: int in outside:
		out_line.add_child(_region_button(targets, e1, r2, names[r2] if r2 < names.size() else str(r2 + 1), OUT_TIP))
	out_line.add_child(PmUI.spacer())
	box.add_child(out_line)

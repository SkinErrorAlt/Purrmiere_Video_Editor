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
		var want: String = ViewMap.split_in_two(ViewMap.crop_count(e)) if make == "split" else ""
		if make == "split" and ViewMap.crop_count(e) < 2:
			continue
		if want == ViewMap.groups_text(e):
			continue
		cmds.append(EffectCmds.SetEffectParam.new(s.id, c.id, uid, ViewMap.GROUPS_KEY, want, -1.0))
	if cmds.is_empty():
		return false
	return Verbs.run(w["doc"], "Split into two groups" if make == "split" else "One group", cmds)


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
	for cid: Variant in targets.keys():
		var c: Clip = s.clip_by_id(String(cid)) if s != null else null
		if c == null:
			continue
		var e: Dictionary = c.effect_by_uid(String(targets[cid]))
		if e.is_empty():
			continue
		most = maxi(most, ViewMap.crop_count(e))
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
		head.add_child(PmUI.spacer())
		box.add_child(head)
		return box
	var lit: int = shown_group(s, grouped[0]["clip"], grouped[0]["entry"]) if grouped.size() == 1 else -1
	var count: int = ViewMap.members(grouped[0]["entry"]).size()
	for g: int in count:
		var b: Button = PmButton.make("Group " + str(g + 1), "")
		b.set("quiet", true)
		b.name = "PairGroupSwitch" + str(g)
		b.set("active", lit == g)
		PmUI.tip(b, GROUP_TIP)
		b.pressed.connect(Callable(SELF, "switch_group").bind(targets, g))
		head.add_child(b)
	head.add_child(PmUI.spacer())
	var clear: Button = PmButton.make("One group", "")
	clear.set("quiet", true)
	clear.name = "PairGroupsClear"
	PmUI.tip(clear, CLEAR_TIP)
	clear.pressed.connect(Callable(SELF, "set_groups").bind(targets, "clear"))
	head.add_child(clear)
	box.add_child(head)
	if grouped.size() != 1:
		return box
	var e1: Dictionary = grouped[0]["entry"]
	var names: PackedStringArray = ViewMap.region_names(e1)
	var m: Array[PackedInt32Array] = ViewMap.members(e1)
	for g2: int in m.size():
		var line: HBoxContainer = PmUI.hbox(4)
		var lead2: Control = Control.new()
		lead2.custom_minimum_size.x = lead_w
		line.add_child(lead2)
		line.add_child(PmLabel.dim("Group " + str(g2 + 1) + ((" (View)" if g2 == 0 else " (Group 2 view)") if g2 < 2 else "")))
		for pos: int in m[g2].size():
			var r: int = m[g2][pos]
			var rb: Button = PmButton.make(str(pos) + ": " + (names[r] if r < names.size() else str(r + 1)), "")
			rb.set("quiet", true)
			rb.name = "PairGroupRegion" + str(r)
			PmUI.tip(rb, MOVE_TIP)
			rb.pressed.connect(Callable(SELF, "move_region").bind(targets, r))
			line.add_child(rb)
		line.add_child(PmUI.spacer())
		box.add_child(line)
	return box

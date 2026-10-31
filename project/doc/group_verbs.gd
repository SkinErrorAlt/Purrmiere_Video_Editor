extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const GroupCmds := preload("res://doc/commands/group_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const GroupTree := preload("res://doc/group_tree.gd")
const MIN_MEMBERS := 2


static func _ids_of(clips: Array[Clip]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for c: Clip in clips:
		out.append(c.id)
	return out


static func _emptied_groups(seq: Sequence, leaving: PackedStringArray, joining: String = "") -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var gone: Dictionary = {}
	for id: String in leaving:
		gone[id] = true
	for g: Dictionary in seq.groups:
		var gid: String = String(g.get("id", ""))
		if gid == joining:
			continue
		var members: Array[Clip] = seq.group_clips(gid)
		var left: int = 0
		for c: Clip in members:
			if not gone.has(c.id):
				left += 1
		if left == 0 and not members.is_empty():
			out.append(gid)
	return out


static func _unmute_cmds(seq: Sequence, gid: String, only: PackedStringArray = PackedStringArray()) -> Array[Command]:
	var cmds: Array[Command] = []
	var g: Dictionary = seq.group_by_id(gid)
	if g.is_empty() or not bool(g.get("muted", false)):
		return cmds
	var was_off: Array = g.get("was_off", [])
	var back: PackedStringArray = PackedStringArray()
	for c: Clip in seq.group_clips(gid):
		if not only.is_empty() and not only.has(c.id):
			continue
		if not was_off.has(c.id) and not c.enabled:
			back.append(c.id)
	if not back.is_empty():
		cmds.append(GroupCmds.SetClipsEnabled.new(seq.id, back, true))
	return cmds


static func make_group(doc: Project, seq: Sequence, ids: PackedStringArray, name_: String = "", colour: int = -1) -> String:
	if doc == null or seq == null:
		return ""
	var members: PackedStringArray = PackedStringArray()
	for id: String in ids:
		if seq.clip_by_id(id) != null and not members.has(id):
			members.append(id)
	if members.size() < MIN_MEMBERS:
		return ""
	var gid: String = doc.mint_id("g")
	var record: Dictionary = Sequence.default_group(gid, name_ if not name_.is_empty() else seq.next_group_name(), colour if colour >= 0 else seq.next_group_colour())
	var cmds: Array[Command] = []
	var touched: PackedStringArray = PackedStringArray()
	for id: String in members:
		var c: Clip = seq.clip_by_id(id)
		if not c.group_id.is_empty() and not touched.has(c.group_id):
			touched.append(c.group_id)
	for old_gid: String in touched:
		cmds.append_array(_unmute_cmds(seq, old_gid, members))
	cmds.append(GroupCmds.AddGroup.new(seq.id, record))
	cmds.append(ClipCmds.Group.new(seq.id, members, gid))
	for empty_gid: String in _emptied_groups(seq, members, gid):
		cmds.append(GroupCmds.RemoveGroup.new(seq.id, empty_gid))
	for g: Dictionary in seq.groups:
		var orphan: String = String(g.get("id", ""))
		if not GroupTree.live(seq, orphan):
			cmds.append(GroupCmds.RemoveGroup.new(seq.id, orphan))
	if not Verbs.run(doc, "Group", cmds):
		return ""
	return gid


static func group_selection(doc: Project, seq: Sequence) -> bool:
	if doc == null or seq == null:
		return false
	var gid: String = make_group(doc, seq, GroupTree.picked(seq))
	if gid.is_empty():
		_toast("Select at least two clips to group")
		return false
	return true


static func _ungroup_cmds(seq: Sequence, gid: String) -> Array[Command]:
	var cmds: Array[Command] = _unmute_cmds(seq, gid)
	var ids: PackedStringArray = _ids_of(seq.group_clips(gid))
	if not ids.is_empty():
		cmds.append(ClipCmds.Ungroup.new(seq.id, ids))
	if not seq.group_by_id(gid).is_empty():
		cmds.append(GroupCmds.RemoveGroup.new(seq.id, gid))
	return cmds


static func ungroup(doc: Project, seq: Sequence, gid: String) -> bool:
	if doc == null or seq == null or gid.is_empty():
		return false
	return Verbs.run(doc, "Ungroup", _ungroup_cmds(seq, gid))


static func groups_of(seq: Sequence, ids: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		if c != null and not c.group_id.is_empty() and not out.has(c.group_id):
			out.append(c.group_id)
	return out


static func ungroup_selection(doc: Project, seq: Sequence) -> bool:
	if doc == null or seq == null:
		return false
	var cmds: Array[Command] = []
	for gid: String in groups_of(seq, Verbs.selection(seq)):
		cmds.append_array(_ungroup_cmds(seq, gid))
	return Verbs.run(doc, "Ungroup", cmds)


static func _ensure_record(seq: Sequence, gid: String, cmds: Array[Command]) -> void:
	if seq.group_by_id(gid).is_empty():
		cmds.append(GroupCmds.AddGroup.new(seq.id, Sequence.default_group(gid, seq.next_group_name(), seq.next_group_colour())))


static func set_field(doc: Project, seq: Sequence, gid: String, key: String, value: Variant, label: String) -> bool:
	if doc == null or seq == null or gid.is_empty() or not GroupTree.live(seq, gid):
		return false
	var cmds: Array[Command] = []
	_ensure_record(seq, gid, cmds)
	cmds.append(GroupCmds.SetGroupField.new(seq.id, gid, key, value))
	return Verbs.run(doc, label, cmds)


static func rename(doc: Project, seq: Sequence, gid: String, name_: String) -> bool:
	var clean: String = name_.strip_edges()
	if clean.is_empty():
		return false
	return set_field(doc, seq, gid, "name", clean, "Rename group")


static func recolour(doc: Project, seq: Sequence, gid: String, colour: int) -> bool:
	return set_field(doc, seq, gid, "colour", clampi(colour, -1, Sequence.GROUP_COLOURS - 1), "Group colour")


static func set_locked(doc: Project, seq: Sequence, gid: String, on: bool) -> bool:
	return set_field(doc, seq, gid, "locked", on, "Lock group" if on else "Unlock group")


static func set_muted(doc: Project, seq: Sequence, gid: String, on: bool) -> bool:
	if doc == null or seq == null or gid.is_empty():
		return false
	var members: Array[Clip] = seq.group_clips(gid)
	if members.is_empty():
		return false
	var g: Dictionary = seq.group_by_id(gid)
	if not g.is_empty() and bool(g.get("muted", false)) == on:
		return false
	var cmds: Array[Command] = []
	_ensure_record(seq, gid, cmds)
	if on:
		var was_off: Array = []
		var turn_off: PackedStringArray = PackedStringArray()
		for c: Clip in members:
			if c.enabled:
				turn_off.append(c.id)
			else:
				was_off.append(c.id)
		cmds.append(GroupCmds.SetGroupField.new(seq.id, gid, "was_off", was_off))
		cmds.append(GroupCmds.SetGroupField.new(seq.id, gid, "muted", true))
		if not turn_off.is_empty():
			cmds.append(GroupCmds.SetClipsEnabled.new(seq.id, turn_off, false))
		return Verbs.run(doc, "Mute group", cmds)
	cmds.append_array(_unmute_cmds(seq, gid))
	cmds.append(GroupCmds.SetGroupField.new(seq.id, gid, "muted", false))
	cmds.append(GroupCmds.SetGroupField.new(seq.id, gid, "was_off", []))
	return Verbs.run(doc, "Unmute group", cmds)


static func select_group(doc: Project, seq: Sequence, gid: String) -> bool:
	if doc == null or seq == null:
		return false
	var ids: PackedStringArray = _ids_of(seq.group_clips(gid))
	if ids.is_empty():
		return false
	Verbs.select(doc, seq, Verbs.MoveRule.pick(seq, ids, Verbs.MoveRule.linked_on()), "replace", ids)
	return true


static func add_to_group(doc: Project, seq: Sequence, gid: String, ids: PackedStringArray) -> bool:
	if doc == null or seq == null or gid.is_empty() or seq.group_clips(gid).is_empty():
		return false
	var joining: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		if c != null and c.group_id != gid and not joining.has(id):
			joining.append(id)
	if joining.is_empty():
		return false
	var cmds: Array[Command] = []
	_ensure_record(seq, gid, cmds)
	for old_gid: String in groups_of(seq, joining):
		cmds.append_array(_unmute_cmds(seq, old_gid, joining))
	cmds.append(ClipCmds.Group.new(seq.id, joining, gid))
	var g: Dictionary = seq.group_by_id(gid)
	if bool(g.get("muted", false)):
		var was_off: Array = (g.get("was_off", []) as Array).duplicate()
		var turn_off: PackedStringArray = PackedStringArray()
		for id: String in joining:
			if seq.clip_by_id(id).enabled:
				turn_off.append(id)
			elif not was_off.has(id):
				was_off.append(id)
		cmds.append(GroupCmds.SetGroupField.new(seq.id, gid, "was_off", was_off))
		if not turn_off.is_empty():
			cmds.append(GroupCmds.SetClipsEnabled.new(seq.id, turn_off, false))
	for empty_gid: String in _emptied_groups(seq, joining, gid):
		cmds.append(GroupCmds.RemoveGroup.new(seq.id, empty_gid))
	return Verbs.run(doc, "Add to group", cmds)


static func remove_from_group(doc: Project, seq: Sequence, ids: PackedStringArray) -> bool:
	if doc == null or seq == null:
		return false
	var leaving: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		if c != null and not c.group_id.is_empty() and not leaving.has(id):
			leaving.append(id)
	if leaving.is_empty():
		return false
	var cmds: Array[Command] = []
	for gid: String in groups_of(seq, leaving):
		cmds.append_array(_unmute_cmds(seq, gid, leaving))
	cmds.append(ClipCmds.Ungroup.new(seq.id, leaving))
	for empty_gid: String in _emptied_groups(seq, leaving):
		cmds.append(GroupCmds.RemoveGroup.new(seq.id, empty_gid))
	return Verbs.run(doc, "Remove from group", cmds)


static func group_to_nest(doc: Project, seq: Sequence, gid: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null or seq == null or gid.is_empty():
		return out
	var members: PackedStringArray = _ids_of(seq.group_clips(gid))
	if members.is_empty():
		return out
	if bool(seq.group_by_id(gid).get("locked", false)):
		_toast("Unlock the group before turning it into a nest")
		return out
	var ids: PackedStringArray = Verbs.unlocked(seq, members)
	if ids.size() != members.size():
		_toast("Some clips of the group are on locked tracks")
		return out
	var name_: String = GroupTree.title(seq, gid)
	var cmds: Array[Command] = _unmute_cmds(seq, gid)
	cmds.append(ClipCmds.Ungroup.new(seq.id, ids))
	var nest: Command = EditCmds.NestClips.new(seq.id, ids, name_)
	cmds.append(nest)
	if not seq.group_by_id(gid).is_empty():
		cmds.append(GroupCmds.RemoveGroup.new(seq.id, gid))
	if not Verbs.run(doc, "Group to nest", cmds):
		return out
	out = nest.get("nest_clip_ids")
	Verbs.select(doc, seq, out, "replace")
	return out


static func unnest_to_group(doc: Project, seq: Sequence, clip_ids: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null or seq == null:
		return out
	var cmds: Array[Command] = []
	var seen: Dictionary = {}
	var colour: int = seq.next_group_colour()
	var names: Dictionary = {}
	for g: Dictionary in seq.groups:
		names[String(g.get("name", ""))] = true
	for id: String in clip_ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null or not c.is_nest():
			continue
		var family: String = c.link_id if not c.link_id.is_empty() else c.id
		if seen.has(family):
			continue
		seen[family] = true
		if Verbs.unlocked(seq, PackedStringArray([id])).is_empty():
			continue
		var name_: String = c.label if not c.label.is_empty() else Sequence.GROUP_NAME
		var n: int = 2
		var base: String = name_
		while names.has(name_):
			name_ = base + " " + str(n)
			n += 1
		names[name_] = true
		cmds.append(GroupCmds.UnnestToGroup.new(seq.id, id, name_, colour))
		colour = (colour + 5) % Sequence.GROUP_COLOURS
	if cmds.is_empty():
		_toast("Select a nest that is not locked")
		return out
	if not Verbs.run(doc, "Unnest to group", cmds):
		return out
	var picked: PackedStringArray = PackedStringArray()
	for cmd: Command in cmds:
		if not cmd.ok:
			continue
		var gid: String = String(cmd.get("group_id"))
		if not gid.is_empty():
			out.append(gid)
		picked.append_array(cmd.get("placed_ids"))
	Verbs.select(doc, seq, picked, "replace")
	return out


static func unnest_selection_to_groups(doc: Project, seq: Sequence) -> bool:
	if doc == null or seq == null:
		return false
	return not unnest_to_group(doc, seq, Verbs.selection(seq)).is_empty()


static func _toast(text: String) -> void:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var ev: Node = (loop as SceneTree).root.get_node_or_null("/root/Events")
		if ev != null and ev.has_method("toast"):
			ev.call("toast", text)

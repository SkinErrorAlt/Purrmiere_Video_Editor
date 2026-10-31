extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const MoveRule := preload("res://doc/move_rule.gd")
const GroupCmds := preload("res://doc/commands/group_cmds.gd")
const VERBS_PATH := "res://doc/verbs.gd"
const PARENT := "parent"
const SLICE_TITLE := "Slice %d of %s"
const EPS := 0.00001
const MAX_DEPTH := 16
const RULE := "A cut through a group (every clip of it that runs through the cut is cut) makes each side its own slice of the group: \"Slice 1 of <group>\", \"Slice 2 of <group>\", tagged on the timeline in the group's colour. Cutting a slice again makes another slice of the same group. A slice's tag picks that slice; the whole group moves only when all of it is picked (its row in the Groups panel, Select the whole group, or every clip by hand)."

const PREF_SLICE := "timeline.slice_groups"

static var _numbers_cache: Dictionary = {}


static func slicing_on() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return true
	var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
	if prefs == null or not prefs.has_method("is_registered") or not bool(prefs.call("is_registered", PREF_SLICE)):
		return true
	return bool(prefs.call("get_value", PREF_SLICE))


static func parent_of(seq: Sequence, gid: String) -> String:
	if seq == null or gid.is_empty():
		return ""
	return String(seq.group_by_id(gid).get(PARENT, ""))


static func is_slice(seq: Sequence, gid: String) -> bool:
	return not parent_of(seq, gid).is_empty()


static func root_of(seq: Sequence, gid: String) -> String:
	var at: String = gid
	for i: int in MAX_DEPTH:
		var up: String = parent_of(seq, at)
		if up.is_empty() or up == at:
			return at
		at = up
	return at


static func child_ids(seq: Sequence, root: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null or root.is_empty():
		return out
	for g: Dictionary in seq.groups:
		var gid: String = String(g.get("id", ""))
		if gid != root and root_of(seq, gid) == root:
			out.append(gid)
	return out


static func members(seq: Sequence, gid: String) -> Array[Clip]:
	var out: Array[Clip] = []
	if seq == null or gid.is_empty():
		return out
	var ids: Dictionary = {gid: true}
	if not is_slice(seq, gid):
		for sid: String in child_ids(seq, gid):
			ids[sid] = true
	for c: Clip in seq.all_clips():
		if not c.group_id.is_empty() and ids.has(c.group_id):
			out.append(c)
	return out


static func member_ids(seq: Sequence, gid: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for c: Clip in members(seq, gid):
		out.append(c.id)
	return out


static func live(seq: Sequence, gid: String) -> bool:
	return not members(seq, gid).is_empty()


static func _starts(seq: Sequence) -> Dictionary:
	var first: Dictionary = {}
	for c: Clip in seq.all_clips():
		if c.group_id.is_empty():
			continue
		if not first.has(c.group_id) or c.start < float(first[c.group_id]):
			first[c.group_id] = c.start
	return first


static func numbers(seq: Sequence, serial: int = -1) -> Dictionary:
	if seq == null:
		return {}
	var key: String = str(seq.get_instance_id()) + "|" + str(serial)
	if serial >= 0:
		var hit: Variant = _numbers_cache.get(str(seq.get_instance_id()), null)
		if hit is Dictionary and String((hit as Dictionary).get("key", "")) == key:
			return (hit as Dictionary)["numbers"]
	var first: Dictionary = _starts(seq)
	var by_root: Dictionary = {}
	for gid: Variant in first.keys():
		var id: String = String(gid)
		if not is_slice(seq, id):
			continue
		var root: String = root_of(seq, id)
		if not by_root.has(root):
			by_root[root] = []
		(by_root[root] as Array).append([float(first[id]), id])
	var out: Dictionary = {}
	for root: Variant in by_root.keys():
		var rows: Array = by_root[root]
		rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (is_equal_approx(float(a[0]), float(b[0])) and String(a[1]) < String(b[1])))
		for i: int in rows.size():
			out[String((rows[i] as Array)[1])] = i + 1
	if serial >= 0:
		_numbers_cache[str(seq.get_instance_id())] = {"key": key, "numbers": out}
	return out


static func slices_of(seq: Sequence, root: String, serial: int = -1) -> PackedStringArray:
	var nums: Dictionary = numbers(seq, serial)
	var rows: Array = []
	for sid: String in child_ids(seq, root):
		if nums.has(sid):
			rows.append([int(nums[sid]), sid])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var out: PackedStringArray = PackedStringArray()
	for r: Array in rows:
		out.append(String(r[1]))
	return out


static func title(seq: Sequence, gid: String, serial: int = -1) -> String:
	if seq == null or gid.is_empty():
		return Sequence.GROUP_NAME
	var rec: Dictionary = seq.group_record(gid)
	var own: String = String(rec.get("name", "")).strip_edges()
	if not own.is_empty():
		return own
	if is_slice(seq, gid):
		var root: String = root_of(seq, gid)
		var n: int = int(numbers(seq, serial).get(gid, 0))
		return SLICE_TITLE % [maxi(n, 1), title(seq, root, serial)]
	return Sequence.GROUP_NAME


static func display_record(seq: Sequence, gid: String, serial: int = -1) -> Dictionary:
	var rec: Dictionary = seq.group_record(gid).duplicate(true)
	rec["name"] = title(seq, gid, serial)
	rec["slice"] = is_slice(seq, gid)
	return rec


static func roots(seq: Sequence) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null:
		return out
	var first: Dictionary = _starts(seq)
	var at: Dictionary = {}
	for gid: Variant in first.keys():
		var root: String = root_of(seq, String(gid))
		var t: float = float(first[gid])
		if not at.has(root) or t < float(at[root]):
			at[root] = t
	var rows: Array = []
	for root: Variant in at.keys():
		rows.append([float(at[root]), String(root)])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (is_equal_approx(float(a[0]), float(b[0])) and String(a[1]) < String(b[1])))
	for r: Array in rows:
		out.append(String(r[1]))
	return out


static func span(seq: Sequence, gid: String) -> Vector2:
	var t0: float = INF
	var t1: float = -INF
	for c: Clip in members(seq, gid):
		t0 = minf(t0, c.start)
		t1 = maxf(t1, c.end())
	if t0 == INF:
		return Vector2.ZERO
	return Vector2(t0, t1)


static func slice_record(doc: Project, from: Dictionary, root: String, ids: PackedStringArray) -> Dictionary:
	var rec: Dictionary = Sequence.default_group(doc.mint_id("g"), "", int(from.get("colour", -1)))
	rec[PARENT] = root
	rec["locked"] = bool(from.get("locked", false))
	rec["muted"] = bool(from.get("muted", false))
	var off: Array = []
	for cid: Variant in from.get("was_off", []):
		if ids.has(String(cid)):
			off.append(String(cid))
	rec["was_off"] = off
	return rec


static func sides(seq: Sequence, gid: String, t: float) -> Array[PackedStringArray]:
	var left: PackedStringArray = PackedStringArray()
	var right: PackedStringArray = PackedStringArray()
	for m: Clip in seq.group_clips(gid):
		if m.end() <= t + EPS:
			left.append(m.id)
		elif m.start >= t - EPS:
			right.append(m.id)
		else:
			return []
	if left.is_empty() or right.is_empty():
		return []
	return [left, right]


static func slice_after_cut(owner: Object, doc: Project, seq: Sequence, cut_ids: PackedStringArray, t: float) -> int:
	if owner == null or doc == null or seq == null or not slicing_on():
		return 0
	var gids: PackedStringArray = PackedStringArray()
	for id: String in cut_ids:
		var c: Clip = seq.clip_by_id(id)
		if c != null and not c.group_id.is_empty() and not gids.has(c.group_id):
			gids.append(c.group_id)
	var made: int = 0
	for gid: String in gids:
		var parts: Array[PackedStringArray] = sides(seq, gid, t)
		if parts.is_empty():
			continue
		if seq.group_by_id(gid).is_empty():
			owner.call("apply", doc, GroupCmds.AddGroup.new(seq.id, Sequence.default_group(gid, Sequence.GROUP_NAME, -1)))
		var rec: Dictionary = seq.group_by_id(gid).duplicate(true)
		var root: String = root_of(seq, gid)
		if root == gid:
			var left_rec: Dictionary = slice_record(doc, rec, root, parts[0])
			owner.call("apply", doc, GroupCmds.AddGroup.new(seq.id, left_rec))
			owner.call("apply", doc, ClipCmds.Group.new(seq.id, parts[0], String(left_rec["id"])))
			made += 1
		var right_rec: Dictionary = slice_record(doc, rec, root, parts[1])
		owner.call("apply", doc, GroupCmds.AddGroup.new(seq.id, right_rec))
		owner.call("apply", doc, ClipCmds.Group.new(seq.id, parts[1], String(right_rec["id"])))
		made += 1
	return made


static func _verbs() -> GDScript:
	return load(VERBS_PATH)


static func picked(seq: Sequence) -> PackedStringArray:
	return MoveRule.moving(seq)


static func select(doc: Project, seq: Sequence, gid: String, add: bool = false) -> bool:
	if doc == null or seq == null:
		return false
	var ids: PackedStringArray = member_ids(seq, gid)
	if ids.is_empty():
		return false
	var verbs: GDScript = _verbs()
	return bool(verbs.call("select", doc, seq, MoveRule.pick(seq, ids, MoveRule.linked_on()), "add" if add else "replace", MoveRule.picked_after(seq, ids, add)))


static func recolour(doc: Project, seq: Sequence, gid: String, colour: int, clips_too: bool = false) -> bool:
	if doc == null or seq == null or not live(seq, gid):
		return false
	var value: int = clampi(colour, -1, Sequence.GROUP_COLOURS - 1)
	var cmds: Array[Command] = []
	var records: PackedStringArray = PackedStringArray([gid])
	if not is_slice(seq, gid):
		records.append_array(child_ids(seq, gid))
	for rid: String in records:
		if seq.group_by_id(rid).is_empty():
			cmds.append(GroupCmds.AddGroup.new(seq.id, Sequence.default_group(rid, Sequence.GROUP_NAME, value)))
		else:
			cmds.append(GroupCmds.SetGroupField.new(seq.id, rid, "colour", value))
	if clips_too:
		for c: Clip in members(seq, gid):
			if c.colour != value:
				cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "colour", value))
	return bool(_verbs().call("run", doc, "Group and clip colour" if clips_too else "Group colour", cmds))


static func rename(doc: Project, seq: Sequence, gid: String, name_: String) -> bool:
	if doc == null or seq == null or not live(seq, gid):
		return false
	var clean: String = name_.strip_edges()
	if clean.is_empty() and not is_slice(seq, gid):
		return false
	var own: String = String(seq.group_record(gid).get("name", ""))
	if clean == own or (own.is_empty() and clean == title(seq, gid)):
		return false
	var cmds: Array[Command] = []
	if seq.group_by_id(gid).is_empty():
		cmds.append(GroupCmds.AddGroup.new(seq.id, Sequence.default_group(gid, clean, -1)))
	else:
		cmds.append(GroupCmds.SetGroupField.new(seq.id, gid, "name", clean))
	return bool(_verbs().call("run", doc, "Rename slice" if is_slice(seq, gid) else "Rename group", cmds))


static func ungroup(doc: Project, seq: Sequence, gid: String) -> bool:
	if doc == null or seq == null or gid.is_empty():
		return false
	var gv: GDScript = load("res://doc/group_verbs.gd")
	if is_slice(seq, gid):
		return bool(gv.call("ungroup", doc, seq, gid))
	var cmds: Array[Command] = []
	var records: PackedStringArray = PackedStringArray([gid])
	records.append_array(child_ids(seq, gid))
	for rid: String in records:
		cmds.append_array(gv.call("_ungroup_cmds", seq, rid))
	return bool(_verbs().call("run", doc, "Ungroup", cmds))


static func effect_targets(seq: Sequence, gid: String, def: Dictionary) -> PackedStringArray:
	if seq == null or def.is_empty():
		return PackedStringArray()
	return _verbs().call("effect_targets", seq, member_ids(seq, gid), def)


static func apply_effect(doc: Project, seq: Sequence, gid: String, def: Dictionary) -> int:
	if doc == null or seq == null or def.is_empty():
		return 0
	var ids: PackedStringArray = member_ids(seq, gid)
	if ids.is_empty():
		return 0
	return int(_verbs().call("drop_effect", doc, seq, ids, def))


static func live_ids(seq: Sequence) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null:
		return out
	for gid: String in seq.group_ids_in_use():
		if not out.has(gid):
			out.append(gid)
		var up: String = root_of(seq, gid)
		if not out.has(up):
			out.append(up)
	return out

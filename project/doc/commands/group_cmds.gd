extends RefCounted

const VERSION := 1
const EditCmds := preload("res://doc/commands/edit_cmds.gd")


class AddGroup extends "res://doc/commands/command.gd":
	var group: Dictionary = {}

	func _init(p_seq_id: String, p_group: Dictionary) -> void:
		label = "Add group"
		seq_id = p_seq_id
		group = Sequence.clean_group(p_group)

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null or group.is_empty() or not s.group_by_id(String(group["id"])).is_empty():
			ok = false
			return
		s.groups.append(group.duplicate(true))
		doc.touch("structure")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		for i: int in range(s.groups.size() - 1, -1, -1):
			if String(s.groups[i].get("id", "")) == String(group["id"]):
				s.groups.remove_at(i)
		doc.touch("structure")


class RemoveGroup extends "res://doc/commands/command.gd":
	var group_id: String = ""
	var old: Dictionary = {}
	var index: int = -1

	func _init(p_seq_id: String, p_group_id: String) -> void:
		label = "Remove group"
		seq_id = p_seq_id
		group_id = p_group_id

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		index = -1
		if s != null:
			for i: int in s.groups.size():
				if String(s.groups[i].get("id", "")) == group_id:
					index = i
		if index < 0:
			ok = false
			return
		old = s.groups[index].duplicate(true)
		s.groups.remove_at(index)
		doc.touch("structure")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		s.groups.insert(mini(index, s.groups.size()), old.duplicate(true))
		doc.touch("structure")


class SetGroupField extends "res://doc/commands/command.gd":
	var group_id: String = ""
	var key: String = ""
	var value: Variant = null
	var old: Variant = null

	func _init(p_seq_id: String, p_group_id: String, p_key: String, p_value: Variant) -> void:
		label = "Group " + p_key
		seq_id = p_seq_id
		group_id = p_group_id
		key = p_key
		value = dup(p_value)

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		var g: Dictionary = s.group_by_id(group_id) if s != null else {}
		if g.is_empty() or not g.has(key):
			ok = false
			return
		old = dup(g[key])
		g[key] = dup(value)
		doc.touch("structure")

	func undo(doc: Project) -> void:
		var g: Dictionary = seq(doc).group_by_id(group_id)
		if not g.is_empty():
			g[key] = dup(old)
		doc.touch("structure")


class SetClipsEnabled extends "res://doc/commands/command.gd":
	var ids: PackedStringArray = PackedStringArray()
	var value: bool = true
	var old: Dictionary = {}

	func _init(p_seq_id: String, p_ids: PackedStringArray, p_value: bool) -> void:
		label = "Enable clips" if p_value else "Disable clips"
		seq_id = p_seq_id
		ids = p_ids
		value = p_value

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		old = {}
		for i: String in ids:
			var c: Clip = s.clip_by_id(i) if s != null else null
			if c == null:
				continue
			old[i] = c.enabled
			c.enabled = value
		if old.is_empty():
			ok = false
			return
		doc.touch("structure")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		for i: Variant in old.keys():
			var c: Clip = s.clip_by_id(String(i))
			if c != null:
				c.enabled = bool(old[i])
		doc.touch("structure")


class UnnestToGroup extends "res://doc/commands/composite.gd":
	var clip_id: String = ""
	var group_name: String = ""
	var colour: int = 0
	var group_id: String = ""
	var placed_ids: PackedStringArray = PackedStringArray()

	func _init(p_seq_id: String, p_clip_id: String, p_name: String, p_colour: int) -> void:
		label = "Unnest to group"
		seq_id = p_seq_id
		clip_id = p_clip_id
		group_name = p_name
		colour = p_colour

	func _plan(doc: Project) -> bool:
		var unnest: EditCmds.UnnestClips = EditCmds.UnnestClips.new(seq_id, clip_id)
		unnest.carry_groups = false
		var un: Command = apply(doc, unnest)
		if not un.ok:
			return false
		placed_ids = un.get("placed_ids")
		if placed_ids.size() < 2:
			return true
		group_id = doc.mint_id("g")
		apply(doc, AddGroup.new(seq_id, Sequence.default_group(group_id, group_name, colour)))
		apply(doc, ClipCmds.Group.new(seq_id, placed_ids, group_id))
		return true

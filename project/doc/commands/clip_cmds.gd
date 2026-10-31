extends RefCounted

const VERSION := 1


class PlaceClip extends "res://doc/commands/command.gd":
	var track_id: String = ""
	var clip_dict: Dictionary = {}

	func _init(p_seq_id: String, p_track_id: String, p_clip_dict: Dictionary, p_copy: bool = true) -> void:
		label = "Place clip"
		seq_id = p_seq_id
		track_id = p_track_id
		clip_dict = p_clip_dict.duplicate(true) if p_copy else p_clip_dict

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		var t: Track = s.track_by_id(track_id)
		s.insert_clip(t, Clip.from_dict(clip_dict))
		doc.touch("structure")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		s.remove_clip(str(clip_dict.get("id", "")))
		doc.touch("structure")


class RemoveClips extends "res://doc/commands/command.gd":
	var ids: PackedStringArray = PackedStringArray()
	var removed: Array[Dictionary] = []

	func _init(p_seq_id: String, p_ids: PackedStringArray) -> void:
		label = "Remove clips"
		seq_id = p_seq_id
		ids = p_ids

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		removed = []
		for r: Dictionary in s.remove_clips(ids):
			var c: Clip = r["clip"]
			removed.append({"track_id": str(r["track_id"]), "clip": c.to_dict()})
			var si: int = s.selected_clip_ids.find(c.id)
			if si >= 0:
				s.selected_clip_ids.remove_at(si)
		if removed.is_empty():
			ok = false
			return
		doc.touch("structure")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		for r: Dictionary in removed:
			var t: Track = s.track_by_id(str(r["track_id"]))
			s.insert_clip(t, Clip.from_dict(r["clip"]))
		doc.touch("structure")


class MoveClips extends "res://doc/commands/command.gd":
	var moves: Array[Dictionary] = []
	var old: Array[Dictionary] = []

	func _init(p_seq_id: String, p_moves: Array[Dictionary]) -> void:
		label = "Move clips"
		seq_id = p_seq_id
		moves = p_moves.duplicate(true)

	func _apply(doc: Project, list: Array[Dictionary]) -> void:
		var s: Sequence = seq(doc)
		s.move_clips(list)
		doc.touch("structure")

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		old = []
		for m: Dictionary in moves:
			var c: Clip = s.clip_by_id(str(m["id"]))
			var t: Track = s.track_of(str(m["id"]))
			if c == null or t == null:
				continue
			old.append({"id": c.id, "start": c.start, "track_id": t.id})
		if old.is_empty():
			ok = false
			return
		_apply(doc, moves)

	func undo(doc: Project) -> void:
		_apply(doc, old)


class SetClipField extends "res://doc/commands/command.gd":
	var clip_id: String = ""
	var field: String = ""
	var value: Variant = null
	var old: Variant = null

	func _init(p_seq_id: String, p_clip_id: String, p_field: String, p_value: Variant) -> void:
		label = "Set " + p_field
		seq_id = p_seq_id
		clip_id = p_clip_id
		field = p_field
		value = dup(p_value)

	func _write(doc: Project, v: Variant) -> void:
		var s: Sequence = seq(doc)
		var c: Clip = s.clip_by_id(clip_id)
		var old_start: float = c.start
		c.set(field, dup(v))
		if field == "start":
			s.resort_clip(s.track_of(clip_id), c, old_start)
		doc.touch("structure")

	func do(doc: Project) -> void:
		old = dup(clip(doc, clip_id).get(field))
		_write(doc, value)

	func undo(doc: Project) -> void:
		_write(doc, old)


class ReplaceClip extends "res://doc/commands/command.gd":
	var clip_id: String = ""
	var new_dict: Dictionary = {}
	var old_dict: Dictionary = {}

	func _init(p_seq_id: String, p_clip_id: String, p_new: Dictionary) -> void:
		label = "Edit clip"
		seq_id = p_seq_id
		clip_id = p_clip_id
		new_dict = p_new.duplicate(true)
		new_dict["id"] = p_clip_id

	func _apply(doc: Project, d: Dictionary) -> void:
		var s: Sequence = seq(doc)
		var c: Clip = s.clip_by_id(clip_id)
		var old_start: float = c.start
		c.apply_dict(d)
		s.resort_clip(s.track_of(clip_id), c, old_start)
		doc.touch("structure")

	func do(doc: Project) -> void:
		old_dict = clip(doc, clip_id).to_dict()
		_apply(doc, new_dict)

	func undo(doc: Project) -> void:
		_apply(doc, old_dict)


class SetClipParam extends "res://doc/commands/command.gd":
	var clip_id: String = ""
	var path: String = ""
	var anim: Dictionary = {}
	var old: Dictionary = {}

	func _init(p_seq_id: String, p_clip_id: String, p_path: String, p_anim: Dictionary) -> void:
		label = "Set " + p_path
		seq_id = p_seq_id
		clip_id = p_clip_id
		path = p_path
		anim = p_anim.duplicate(true)

	func live_key() -> String:
		return "clip_param|" + clip_id + "|" + path

	func do(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		old = c.get_param(path).duplicate(true)
		anim = preload("res://doc/speed_ease.gd").fresh(path, old, anim)
		anim = preload("res://doc/key_defaults.gd").fresh(c, path, old, anim)
		anim = preload("res://doc/key_anchor.gd").stamp_new(c, path, old, anim)
		ok = c.set_param(path, anim)
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		if old.is_empty():
			c.erase_param(path)
		else:
			c.set_param(path, old)
		doc.touch("meta")


class SetIds extends "res://doc/commands/command.gd":
	var ids: PackedStringArray = PackedStringArray()
	var field: String = ""
	var value: String = ""
	var old: Dictionary = {}

	func _init(p_seq_id: String, p_ids: PackedStringArray, p_field: String, p_value: String, p_label: String) -> void:
		label = p_label
		seq_id = p_seq_id
		ids = p_ids
		field = p_field
		value = p_value

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		old = {}
		for i: String in ids:
			var c: Clip = s.clip_by_id(i)
			if c == null:
				continue
			old[i] = c.get(field)
			c.set(field, value)
		doc.touch("structure")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		for i: String in old.keys():
			var c: Clip = s.clip_by_id(i)
			if c != null:
				c.set(field, old[i])
		doc.touch("structure")


class Link extends SetIds:
	func _init(p_seq_id: String, p_ids: PackedStringArray, p_link_id: String) -> void:
		super(p_seq_id, p_ids, "link_id", p_link_id, "Link")


class Unlink extends SetIds:
	func _init(p_seq_id: String, p_ids: PackedStringArray) -> void:
		super(p_seq_id, p_ids, "link_id", "", "Unlink")


class Group extends SetIds:
	func _init(p_seq_id: String, p_ids: PackedStringArray, p_group_id: String) -> void:
		super(p_seq_id, p_ids, "group_id", p_group_id, "Group")


class Ungroup extends SetIds:
	func _init(p_seq_id: String, p_ids: PackedStringArray) -> void:
		super(p_seq_id, p_ids, "group_id", "", "Ungroup")


class SetNestOption extends "res://doc/commands/command.gd":
	var clip_id: String = ""
	var key: String = ""
	var value: Variant = null
	var old: Dictionary = {}

	func _init(p_seq_id: String, p_clip_id: String, p_key: String, p_value: Variant) -> void:
		label = "Nest option"
		seq_id = p_seq_id
		clip_id = p_clip_id
		key = p_key
		value = AnimProp.norm(p_value)

	func do(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		old = c.nest.duplicate(true)
		c.nest[key] = dup(value)
		doc.touch("meta")

	func undo(doc: Project) -> void:
		clip(doc, clip_id).nest = old.duplicate(true)
		doc.touch("meta")


class SetTransition extends "res://doc/commands/command.gd":
	var clip_id: String = ""
	var transition: Dictionary = {}
	var old: Dictionary = {}

	func _init(p_seq_id: String, p_clip_id: String, p_transition: Dictionary) -> void:
		label = "Set transition"
		seq_id = p_seq_id
		clip_id = p_clip_id
		transition = p_transition.duplicate(true)

	func do(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		old = c.transition_in.duplicate(true)
		c.transition_in = transition.duplicate(true)
		doc.touch("structure")

	func undo(doc: Project) -> void:
		clip(doc, clip_id).transition_in = old.duplicate(true)
		doc.touch("structure")

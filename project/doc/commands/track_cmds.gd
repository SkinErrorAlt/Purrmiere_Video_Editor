extends RefCounted

const VERSION := 1


class AddTrack extends "res://doc/commands/command.gd":
	var kind: String = "video"
	var index: int = -1
	var track_dict: Dictionary = {}

	func _init(p_seq_id: String, p_kind: String, p_index: int, p_track_dict: Dictionary) -> void:
		label = "Add track"
		seq_id = p_seq_id
		kind = p_kind
		index = p_index
		track_dict = p_track_dict.duplicate(true)
		track_dict["kind"] = p_kind

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		var list: Array[Track] = s.tracks_of_kind(kind)
		var t: Track = Track.from_dict(track_dict)
		if index < 0 or index > list.size():
			index = list.size()
		list.insert(index, t)
		s.invalidate()
		doc.touch("structure")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		var list: Array[Track] = s.tracks_of_kind(kind)
		for i: int in list.size():
			if list[i].id == str(track_dict.get("id", "")):
				list.remove_at(i)
				break
		s.invalidate()
		doc.touch("structure")


class RemoveTrack extends "res://doc/commands/command.gd":
	var track_id: String = ""
	var kind: String = ""
	var index: int = -1
	var track_dict: Dictionary = {}

	func _init(p_seq_id: String, p_track_id: String) -> void:
		label = "Remove track"
		seq_id = p_seq_id
		track_id = p_track_id

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		var t: Track = s.track_by_id(track_id)
		if t == null:
			ok = false
			return
		kind = t.kind
		var list: Array[Track] = s.tracks_of_kind(kind)
		index = list.find(t)
		track_dict = t.to_dict()
		list.remove_at(index)
		for c: Clip in t.clips:
			var si: int = s.selected_clip_ids.find(c.id)
			if si >= 0:
				s.selected_clip_ids.remove_at(si)
		s.invalidate()
		doc.touch("structure")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		var list: Array[Track] = s.tracks_of_kind(kind)
		list.insert(mini(index, list.size()), Track.from_dict(track_dict))
		s.invalidate()
		doc.touch("structure")


class SetTrackField extends "res://doc/commands/command.gd":
	var track_id: String = ""
	var field: String = ""
	var value: Variant = null
	var old: Variant = null

	func _init(p_seq_id: String, p_track_id: String, p_field: String, p_value: Variant) -> void:
		label = "Track " + p_field
		seq_id = p_seq_id
		track_id = p_track_id
		field = p_field
		value = dup(p_value)

	func do(doc: Project) -> void:
		var t: Track = track(doc, track_id)
		old = dup(t.get(field))
		t.set(field, dup(value))
		doc.touch("structure")

	func undo(doc: Project) -> void:
		track(doc, track_id).set(field, dup(old))
		doc.touch("structure")


class PinTrack extends SetTrackField:
	func _init(p_seq_id: String, p_track_id: String, p_on: bool) -> void:
		super(p_seq_id, p_track_id, "pinned", p_on)
		label = "Pin track" if p_on else "Unpin track"


class ReorderTrack extends "res://doc/commands/command.gd":
	var track_id: String = ""
	var new_index: int = 0
	var old_index: int = 0

	func _init(p_seq_id: String, p_track_id: String, p_new_index: int) -> void:
		label = "Reorder track"
		seq_id = p_seq_id
		track_id = p_track_id
		new_index = p_new_index

	func _move(doc: Project, to: int) -> void:
		var s: Sequence = seq(doc)
		var t: Track = s.track_by_id(track_id)
		var list: Array[Track] = s.tracks_of_kind(t.kind)
		list.erase(t)
		list.insert(clampi(to, 0, list.size()), t)
		s.invalidate()
		doc.touch("structure")

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		old_index = s.track_index(track_id)
		_move(doc, new_index)

	func undo(doc: Project) -> void:
		_move(doc, old_index)

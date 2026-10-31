extends RefCounted

const VERSION := 1


class AddSequence extends "res://doc/commands/command.gd":
	var seq_dict: Dictionary = {}
	var media_dict: Dictionary = {}
	var index: int = -1
	var make_active: bool = false
	var old_active: String = ""

	func _init(p_seq_dict: Dictionary, p_media_dict: Dictionary = {}, p_index: int = -1, p_make_active: bool = false) -> void:
		label = "Add sequence"
		seq_dict = p_seq_dict.duplicate(true)
		seq_id = str(seq_dict.get("id", ""))
		media_dict = p_media_dict.duplicate(true)
		index = p_index
		make_active = p_make_active

	func do(doc: Project) -> void:
		if seq_id.is_empty() or doc.sequence_by_id(seq_id) != null:
			ok = false
			return
		if index < 0 or index > doc.sequences.size():
			index = doc.sequences.size()
		doc.sequences.insert(index, Sequence.from_dict(seq_dict))
		if not media_dict.is_empty() and doc.media_by_id(str(media_dict.get("id", ""))) == null:
			doc.media.append(MediaItem.from_dict(media_dict))
		old_active = doc.active_sequence_id
		if make_active or doc.active_sequence_id.is_empty():
			doc.active_sequence_id = seq_id
		doc.touch("structure")

	func undo(doc: Project) -> void:
		var s: Sequence = doc.sequence_by_id(seq_id)
		if s != null:
			doc.sequences.erase(s)
		if not media_dict.is_empty():
			var m: MediaItem = doc.media_by_id(str(media_dict.get("id", "")))
			if m != null:
				doc.media.erase(m)
		doc.active_sequence_id = old_active
		doc.touch("structure")


class RemoveSequence extends "res://doc/commands/command.gd":
	var force: bool = false
	var seq_dict: Dictionary = {}
	var index: int = -1
	var media_dict: Dictionary = {}
	var media_index: int = -1
	var old_active: String = ""
	var removed_clips: Array[Dictionary] = []

	func _init(p_seq_id: String, p_force: bool = false) -> void:
		label = "Remove sequence"
		seq_id = p_seq_id
		force = p_force

	func do(doc: Project) -> void:
		var s: Sequence = doc.sequence_by_id(seq_id)
		if s == null:
			ok = false
			return
		removed_clips = []
		for other: Sequence in doc.sequences:
			if other == s:
				continue
			for t: Track in other.all_tracks():
				for c: Clip in t.clips:
					if c.sequence_id == seq_id:
						removed_clips.append({"seq_id": other.id, "track_id": t.id, "clip": c.to_dict()})
		if not removed_clips.is_empty() and not force:
			ok = false
			print("RemoveSequence: \"" + s.label + "\" is nested in " + str(removed_clips.size()) + " clips, pass force to remove them too")
			removed_clips = []
			return
		for r: Dictionary in removed_clips:
			var other: Sequence = doc.sequence_by_id(str(r["seq_id"]))
			other.remove_clip(str((r["clip"] as Dictionary).get("id", "")))
		index = doc.sequences.find(s)
		seq_dict = s.to_dict()
		doc.sequences.remove_at(index)
		var m: MediaItem = doc.media_for_sequence(seq_id)
		media_dict = {}
		media_index = -1
		if m != null:
			media_index = doc.media.find(m)
			media_dict = m.to_dict()
			doc.media.remove_at(media_index)
		old_active = doc.active_sequence_id
		if doc.active_sequence_id == seq_id:
			doc.active_sequence_id = doc.sequences[0].id if not doc.sequences.is_empty() else ""
		doc.touch("structure")

	func undo(doc: Project) -> void:
		doc.sequences.insert(mini(index, doc.sequences.size()), Sequence.from_dict(seq_dict))
		if media_index >= 0:
			doc.media.insert(mini(media_index, doc.media.size()), MediaItem.from_dict(media_dict))
		for r: Dictionary in removed_clips:
			var other: Sequence = doc.sequence_by_id(str(r["seq_id"]))
			var t: Track = other.track_by_id(str(r["track_id"]))
			other.insert_clip(t, Clip.from_dict(r["clip"]))
		doc.active_sequence_id = old_active
		doc.touch("structure")


class SetSequenceField extends "res://doc/commands/command.gd":
	var field: String = ""
	var value: Variant = null
	var old: Variant = null

	func _init(p_seq_id: String, p_field: String, p_value: Variant) -> void:
		label = "Sequence " + p_field
		seq_id = p_seq_id
		field = p_field
		value = dup(p_value)

	func live_key() -> String:
		return "seq_field|" + seq_id + "|" + field

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null:
			ok = false
			return
		old = dup(s.get(field))
		s.set(field, dup(value))
		if field == "label":
			var m: MediaItem = doc.media_for_sequence(seq_id)
			if m != null:
				m.label = str(value)
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		s.set(field, dup(old))
		if field == "label":
			var m: MediaItem = doc.media_for_sequence(seq_id)
			if m != null:
				m.label = str(old)
		doc.touch("meta")


class SetInOut extends "res://doc/commands/command.gd":
	var in_point: float = -1.0
	var out_point: float = -1.0
	var old_in: float = -1.0
	var old_out: float = -1.0

	func _init(p_seq_id: String, p_in: float, p_out: float) -> void:
		label = "Set in and out"
		seq_id = p_seq_id
		in_point = p_in
		out_point = p_out

	func live_key() -> String:
		return "inout|" + seq_id

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		old_in = s.in_point
		old_out = s.out_point
		s.in_point = in_point
		s.out_point = out_point
		doc.touch("markers")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		s.in_point = old_in
		s.out_point = old_out
		doc.touch("markers")


class SetPinnedBand extends "res://doc/commands/command.gd":
	var pinned: Dictionary = {}
	var old: Dictionary = {}

	func _init(p_seq_id: String, p_pinned: Dictionary) -> void:
		label = "Pinned band"
		seq_id = p_seq_id
		pinned = Sequence.default_pinned()
		for k: String in pinned.keys():
			if p_pinned.has(k):
				pinned[k] = AnimProp.norm(p_pinned[k])

	func live_key() -> String:
		return "pinned|" + seq_id

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		old = s.pinned.duplicate(true)
		s.pinned = pinned.duplicate(true)
		doc.touch("meta")

	func undo(doc: Project) -> void:
		seq(doc).pinned = old.duplicate(true)
		doc.touch("meta")

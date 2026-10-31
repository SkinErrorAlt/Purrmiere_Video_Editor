extends RefCounted

const VERSION := 1


class AddMedia extends "res://doc/commands/command.gd":
	var item_dict: Dictionary = {}
	var index: int = -1

	func _init(p_item_dict: Dictionary, p_index: int = -1) -> void:
		label = "Add media"
		item_dict = p_item_dict.duplicate(true)
		index = p_index

	func do(doc: Project) -> void:
		var item: MediaItem = MediaItem.from_dict(item_dict)
		if item.id.is_empty() or doc.media_by_id(item.id) != null:
			ok = false
			return
		if index < 0 or index > doc.media.size():
			index = doc.media.size()
		doc.media.insert(index, item)
		doc.touch("media")

	func undo(doc: Project) -> void:
		var item: MediaItem = doc.media_by_id(str(item_dict.get("id", "")))
		if item != null:
			doc.media.erase(item)
		doc.touch("media")


class RemoveMedia extends "res://doc/commands/command.gd":
	var media_id: String = ""
	var force: bool = false
	var item_dict: Dictionary = {}
	var index: int = -1
	var removed_clips: Array[Dictionary] = []

	func _init(p_media_id: String, p_force: bool = false) -> void:
		label = "Remove media"
		media_id = p_media_id
		force = p_force

	func _users(doc: Project) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for s: Sequence in doc.sequences:
			for t: Track in s.all_tracks():
				for c: Clip in t.clips:
					if c.media_id == media_id:
						out.append({"seq_id": s.id, "track_id": t.id, "clip": c.to_dict()})
		return out

	func do(doc: Project) -> void:
		var item: MediaItem = doc.media_by_id(media_id)
		if item == null:
			ok = false
			return
		removed_clips = _users(doc)
		if not removed_clips.is_empty() and not force:
			ok = false
			print("RemoveMedia: \"" + item.label + "\" is used by " + str(removed_clips.size()) + " clips, pass force to remove them too")
			removed_clips = []
			return
		for r: Dictionary in removed_clips:
			var s: Sequence = doc.sequence_by_id(str(r["seq_id"]))
			var cid: String = str((r["clip"] as Dictionary).get("id", ""))
			s.remove_clip(cid)
			var si: int = s.selected_clip_ids.find(cid)
			if si >= 0:
				s.selected_clip_ids.remove_at(si)
		index = doc.media.find(item)
		item_dict = item.to_dict()
		doc.media.remove_at(index)
		doc.touch("media")

	func undo(doc: Project) -> void:
		doc.media.insert(mini(index, doc.media.size()), MediaItem.from_dict(item_dict))
		for r: Dictionary in removed_clips:
			var s: Sequence = doc.sequence_by_id(str(r["seq_id"]))
			var t: Track = s.track_by_id(str(r["track_id"]))
			s.insert_clip(t, Clip.from_dict(r["clip"]))
		doc.touch("media")


class SetMediaField extends "res://doc/commands/command.gd":
	var media_id: String = ""
	var field: String = ""
	var value: Variant = null
	var old: Variant = null

	func _init(p_media_id: String, p_field: String, p_value: Variant) -> void:
		label = "Media " + p_field
		media_id = p_media_id
		field = p_field
		value = dup(p_value)

	func live_key() -> String:
		return "media_field|" + media_id + "|" + field

	static func fit(current: Variant, incoming: Variant) -> Variant:
		if current is Array and incoming is Array and (current as Array).is_typed() and not (incoming as Array).is_typed():
			var shaped: Array = (current as Array).duplicate()
			shaped.clear()
			for e: Variant in (incoming as Array):
				shaped.append(e)
			return shaped
		return incoming

	func do(doc: Project) -> void:
		var item: MediaItem = doc.media_by_id(media_id)
		if item == null:
			ok = false
			return
		old = dup(item.get(field))
		item.set(field, fit(old, dup(value)))
		doc.touch("media")

	func undo(doc: Project) -> void:
		var item: MediaItem = doc.media_by_id(media_id)
		if item != null:
			item.set(field, dup(old))
		doc.touch("media")


class MoveMediaToBin extends SetMediaField:
	func _init(p_media_id: String, p_bin: String) -> void:
		super(p_media_id, "bin", p_bin)
		label = "Move to bin"


class AddBin extends "res://doc/commands/command.gd":
	var path: String = ""
	var old_bins: PackedStringArray = PackedStringArray()

	func _init(p_path: String) -> void:
		label = "New bin"
		path = p_path.strip_edges().trim_prefix("/").trim_suffix("/")

	func do(doc: Project) -> void:
		if path.is_empty():
			ok = false
			return
		old_bins = doc.bins.duplicate()
		var parts: PackedStringArray = path.split("/")
		var acc: String = ""
		for p: String in parts:
			acc = p if acc.is_empty() else acc + "/" + p
			if not doc.bins.has(acc):
				doc.bins.append(acc)
		doc.touch("media")

	func undo(doc: Project) -> void:
		doc.bins = old_bins.duplicate()
		doc.touch("media")


class RemoveBin extends "res://doc/commands/command.gd":
	var path: String = ""
	var old_bins: PackedStringArray = PackedStringArray()
	var old_item_bins: Dictionary = {}

	func _init(p_path: String) -> void:
		label = "Remove bin"
		path = p_path

	func do(doc: Project) -> void:
		old_bins = doc.bins.duplicate()
		old_item_bins = {}
		var parent: String = path.get_base_dir() if path.contains("/") else ""
		var kept: PackedStringArray = PackedStringArray()
		for b: String in doc.bins:
			if not (b == path or b.begins_with(path + "/")):
				kept.append(b)
		if kept.size() == doc.bins.size():
			ok = false
			return
		doc.bins = kept
		for m: MediaItem in doc.media:
			if m.bin == path or m.bin.begins_with(path + "/"):
				old_item_bins[m.id] = m.bin
				m.bin = parent
		doc.touch("media")

	func undo(doc: Project) -> void:
		doc.bins = old_bins.duplicate()
		for id: String in old_item_bins.keys():
			var m: MediaItem = doc.media_by_id(id)
			if m != null:
				m.bin = str(old_item_bins[id])
		doc.touch("media")


class RenameBin extends "res://doc/commands/command.gd":
	const TAGS_KEY := "bin_tags"
	var old_path: String = ""
	var new_path: String = ""
	var old_tags: Variant = null

	func _init(p_old: String, p_new: String) -> void:
		label = "Rename bin"
		old_path = p_old
		new_path = p_new.strip_edges().trim_prefix("/").trim_suffix("/")

	func _rename(doc: Project, from: String, to: String) -> void:
		for i: int in doc.bins.size():
			var b: String = doc.bins[i]
			if b == from:
				doc.bins[i] = to
			elif b.begins_with(from + "/"):
				doc.bins[i] = to + b.substr(from.length())
		for m: MediaItem in doc.media:
			if m.bin == from:
				m.bin = to
			elif m.bin.begins_with(from + "/"):
				m.bin = to + m.bin.substr(from.length())
		doc.touch("media")

	func do(doc: Project) -> void:
		if new_path.is_empty() or old_path == new_path or doc.bins.has(new_path):
			ok = false
			return
		_rename(doc, old_path, new_path)
		_move_tags(doc, old_path, new_path)

	func undo(doc: Project) -> void:
		_rename(doc, new_path, old_path)
		if old_tags is Dictionary:
			doc.info[TAGS_KEY] = (old_tags as Dictionary).duplicate(true)
		else:
			doc.info.erase(TAGS_KEY)

	static func moved_tags(all: Dictionary, from: String, to: String) -> Dictionary:
		var out: Dictionary = {}
		for k: Variant in all.keys():
			var key: String = String(k)
			if key != from and not key.begins_with(from + "/"):
				out[key] = all[k]
		for k: Variant in all.keys():
			var key: String = String(k)
			if key == from:
				out[to] = all[k]
			elif key.begins_with(from + "/"):
				out[to + key.substr(from.length())] = all[k]
		return out

	func _move_tags(doc: Project, from: String, to: String) -> void:
		var raw: Variant = doc.info.get(TAGS_KEY, null)
		old_tags = (raw as Dictionary).duplicate(true) if raw is Dictionary else null
		if raw is Dictionary:
			doc.info[TAGS_KEY] = moved_tags(raw, from, to)

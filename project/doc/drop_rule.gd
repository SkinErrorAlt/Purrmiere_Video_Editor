extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const LinkAsOne := preload("res://doc/link_as_one.gd")
const RULE := "A dropped effect goes on the clip under the pointer only. When that clip is one of several clips you picked yourself (Ctrl or Shift click, a box, Select all), it goes on each of them. Clips that are only selected because they are linked to a picked clip are left alone. A link group set to Act as one is the one exception: its members are a single clip, so a drop on any of them goes on all of them."


static func on_purpose(seq: Sequence) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null:
		return out
	var picked: PackedStringArray = seq.picked_clip_ids
	for id: String in seq.selected_clip_ids:
		if seq.clip_by_id(id) == null:
			continue
		if picked.is_empty() or picked.has(id):
			out.append(id)
	return out


static func picked_targets(seq: Sequence, clip_id: String) -> PackedStringArray:
	if seq == null or clip_id.is_empty():
		return PackedStringArray()
	var many: PackedStringArray = on_purpose(seq)
	if many.size() >= 2 and many.has(clip_id):
		return many
	return PackedStringArray([clip_id])


static func targets(seq: Sequence, clip_id: String) -> PackedStringArray:
	return LinkAsOne.widen(seq, picked_targets(seq, clip_id))


static func hint(seq: Sequence, clip_id: String, receivers: PackedStringArray) -> String:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null and not clip_id.is_empty() else null
	if c == null or receivers.is_empty():
		return ""
	if LinkAsOne.acts_as_one(seq, c) and receivers.size() > 1:
		return "On all %d clips that act as one" % receivers.size()
	if targets(seq, clip_id).size() >= 2:
		return "On the %d clips you picked" % receivers.size()
	if receivers.size() == 1 and receivers[0] == clip_id:
		return "On " + c.label + " only"
	return "On the %d linked clips of %s" % [receivers.size(), c.label] if receivers.size() > 1 else "On the linked clip of " + c.label

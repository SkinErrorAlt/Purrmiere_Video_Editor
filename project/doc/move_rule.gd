extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const LinkAsOne := preload("res://doc/link_as_one.gd")
const ViewMap := preload("res://doc/view_map.gd")
const EPS := 0.00001
const PREF_LINKED := "timeline.linked_selection"
const PREF_MOVE_LINKS := "timeline.move_links"
const MOVE_LINKS_LABEL := "With linked selection off, moving a clip still takes its own linked clips (the ones under it piece for piece)"
const RULE := "Moves, nudges (Alt and the arrows), moves up or down a track, slides and slips act on the clips you picked. Each picked clip brings its own linked clips: the ones that sit under it piece for piece (usually the same start and end), never the other pieces of a long link family or other slices. With linked selection on they are selected with it, and Alt click picks one lane alone. With linked selection off a click selects just the clip and a move still takes its own linked clips along, unless that is turned off in Settings, Timeline. A group moves as a whole only when all of it is picked: click its tag, use Select group, or pick every clip in it. Clicking one clip of a group picks that clip only. Alt drag a clip's edge to lengthen or shorten that clip alone, leaving its linked clips and keeping it in its group, even where the group's tag covers the edge. A link group set to Act as one goes further: every member moves with any other member, touching or not, until you Alt click one member and Shift drag it on its own."


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/Prefs")
	return null


static func linked_on() -> bool:
	var prefs: Node = _prefs()
	if prefs == null or not prefs.has_method("is_registered") or not bool(prefs.call("is_registered", PREF_LINKED)):
		return true
	return bool(prefs.call("get_value", PREF_LINKED))


static func move_links() -> bool:
	var prefs: Node = _prefs()
	if prefs == null or not prefs.has_method("is_registered") or not bool(prefs.call("is_registered", PREF_MOVE_LINKS)):
		return true
	return bool(prefs.call("get_value", PREF_MOVE_LINKS))


static func keeps_links(linked: bool) -> bool:
	return linked or move_links()


static func overlaps(a: Clip, b: Clip) -> bool:
	return a != null and b != null and a.end() > b.start + EPS and b.end() > a.start + EPS


static func own_partners(seq: Sequence, c: Clip) -> Array[Clip]:
	var out: Array[Clip] = []
	if seq == null or c == null:
		return out
	out.append(c)
	if c.link_id.is_empty():
		return out
	var family: Array[Clip] = seq.linked(c)
	if family.size() < 2:
		return out
	var home: Track = seq.track_of(c.id)
	var by_track: Dictionary = {}
	for f: Clip in family:
		var ft: Track = seq.track_of(f.id)
		if ft == null:
			continue
		if not by_track.has(ft.id):
			var none: Array[Clip] = []
			by_track[ft.id] = none
		(by_track[ft.id] as Array[Clip]).append(f)
	for f: Clip in family:
		if f == c or not overlaps(c, f):
			continue
		var ft2: Track = seq.track_of(f.id)
		if ft2 == null or ft2 == home:
			continue
		var alone_over_c: bool = _count_over(by_track.get(ft2.id, []), c) == 1
		var alone_over_f: bool = home != null and _count_over(by_track.get(home.id, []), f) == 1
		if not alone_over_f:
			continue
		if alone_over_c or pair_leads(seq, c, f):
			out.append(f)
	return out


static func pair_videos_over(seq: Sequence, c: Clip) -> Array[Clip]:
	var out: Array[Clip] = []
	if seq == null or c == null:
		return out
	for tr: Track in seq.picture_tracks():
		for v: Clip in tr.clips:
			if v.start >= c.end() - EPS:
				break
			if v.end() <= c.start + EPS:
				continue
			for e: Dictionary in v.effects:
				if String(e.get("id", "")) == ViewMap.PAIR_VIEW_ID:
					out.append(v)
					break
	return out


static func pair_entry_of(c: Clip) -> Dictionary:
	if c == null:
		return {}
	for one: Dictionary in c.effects:
		if String(one.get("id", "")) == ViewMap.PAIR_VIEW_ID:
			return one
	return {}


static func pair_leads(seq: Sequence, lead: Clip, under: Clip) -> bool:
	if seq == null or lead == null or under == null or lead == under or not overlaps(lead, under):
		return false
	var e: Dictionary = pair_entry_of(lead)
	if e.is_empty():
		return false
	if not pair_entry_of(under).is_empty():
		return false
	return _reached(seq, ViewMap.of(e), lead, under)


static func _reached(seq: Sequence, map: Dictionary, video: Clip, c: Clip) -> bool:
	var tr: Track = seq.track_of(c.id)
	if tr == null:
		return false
	if not map.is_empty() and ViewMap.reaches(map, video, c, tr.id):
		return true
	return ViewMap.in_family(video, c) and overlaps(video, c)


static func _count_over(list: Array, c: Clip) -> int:
	var n: int = 0
	for o: Variant in list:
		if overlaps(o as Clip, c):
			n += 1
	return n


static func with_as_one(seq: Sequence, ids: PackedStringArray, alone: PackedStringArray) -> PackedStringArray:
	if seq == null or ids.is_empty():
		return ids
	var out: PackedStringArray = ids.duplicate()
	for id: String in ids:
		if alone.has(id):
			continue
		for m: Clip in LinkAsOne.members(seq, seq.clip_by_id(id)):
			if not out.has(m.id):
				out.append(m.id)
	return out


static func pick(seq: Sequence, ids: PackedStringArray, linked: bool = true) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null:
		return out
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			continue
		if not out.has(id):
			out.append(id)
		if not linked:
			continue
		for f: Clip in own_partners(seq, c):
			if not out.has(f.id):
				out.append(f.id)
	if not linked:
		return out
	return with_as_one(seq, out, PackedStringArray())


static var _lone: Dictionary = {}


static func mark_lone(seq: Sequence, ids: PackedStringArray) -> void:
	if seq == null:
		return
	if ids.is_empty():
		_lone.erase(seq.id)
		return
	_lone[seq.id] = {"ids": ids.duplicate(), "sel": seq.selected_clip_ids.duplicate()}


static func lone_ids(seq: Sequence) -> PackedStringArray:
	var e: Dictionary = _lone.get(seq.id, {}) if seq != null else {}
	if e.is_empty() or (e["sel"] as PackedStringArray) != seq.selected_clip_ids:
		return PackedStringArray()
	return e["ids"]


static func moving(seq: Sequence) -> PackedStringArray:
	var sel: PackedStringArray = PackedStringArray()
	if seq == null:
		return sel
	for id: String in seq.selected_clip_ids:
		if seq.clip_by_id(id) != null and not sel.has(id):
			sel.append(id)
	var picked: PackedStringArray = seq.picked_clip_ids
	var out: PackedStringArray = PackedStringArray()
	for id: String in sel:
		if picked.is_empty() or picked.has(id):
			out.append(id)
	if out.is_empty():
		out = sel.duplicate()
	var all_partners: bool = keeps_links(linked_on())
	var alone: PackedStringArray = lone_ids(seq)
	if out.size() == sel.size() and not all_partners:
		return with_as_one(seq, sel, alone)
	for id: String in out.duplicate():
		if alone.has(id):
			continue
		for f: Clip in own_partners(seq, seq.clip_by_id(id)):
			if (all_partners or sel.has(f.id)) and not out.has(f.id):
				out.append(f.id)
	for id: String in sel:
		if not out.has(id) and (picked.is_empty() or picked.has(id)):
			out.append(id)
	return with_as_one(seq, out, alone)


static func drag_ids(seq: Sequence, clip_id: String, linked: bool) -> PackedStringArray:
	if seq == null or seq.clip_by_id(clip_id) == null:
		return PackedStringArray()
	if seq.selected_clip_ids.has(clip_id):
		var now: PackedStringArray = moving(seq)
		if now.has(clip_id):
			return now
	return pick(seq, PackedStringArray([clip_id]), keeps_links(linked))


static func needs_select(seq: Sequence, clip_id: String) -> bool:
	return seq != null and (not seq.selected_clip_ids.has(clip_id) or not moving(seq).has(clip_id))


static func picked_after(seq: Sequence, ids: PackedStringArray, add: bool) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if add and seq != null:
		for id: String in seq.picked_clip_ids:
			if seq.selected_clip_ids.has(id) and not out.has(id):
				out.append(id)
	for id: String in ids:
		if not out.has(id):
			out.append(id)
	return out


static func slide_ids(seq: Sequence, clip_id: String) -> PackedStringArray:
	return pick(seq, PackedStringArray([clip_id]), keeps_links(linked_on()) and not lone_ids(seq).has(clip_id))

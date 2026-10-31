extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const CW := preload("res://doc/clip_warnings.gd")
const EPS := 0.0005
const NONE_AFTER := "No open warnings after the playhead"
const NONE_BEFORE := "No open warnings before the playhead"
const NONE_AT_ALL := "No open warnings in this sequence"


static func stops(doc: Project, seq: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for e: Dictionary in CW.entries(doc, seq, "open"):
		var cid: String = String(e.get("outer_clip_id", e.get("clip_id", "")))
		var t: float = CW.shown_time(e)
		var key: String = cid + "|%.4f" % t
		if seen.has(key):
			continue
		seen[key] = true
		out.append(e)
	return out


static func pick(list: Array[Dictionary], playhead: float, selected: PackedStringArray, dir: int) -> int:
	var here: int = -1
	for i: int in list.size():
		var cid: String = String(list[i].get("outer_clip_id", list[i].get("clip_id", "")))
		if absf(CW.shown_time(list[i]) - playhead) <= EPS and selected.has(cid):
			here = i
	if here >= 0:
		var next: int = here + (1 if dir > 0 else -1)
		return next if next >= 0 and next < list.size() else -1
	if dir > 0:
		for i: int in list.size():
			if CW.shown_time(list[i]) > playhead + EPS:
				return i
		return -1
	for i: int in range(list.size() - 1, -1, -1):
		if CW.shown_time(list[i]) < playhead - EPS:
			return i
	return -1


static func target(doc: Project, seq: Sequence, dir: int) -> Dictionary:
	if doc == null or seq == null:
		return {}
	var list: Array[Dictionary] = stops(doc, seq)
	var i: int = pick(list, seq.playhead, seq.selected_clip_ids, dir)
	return list[i] if i >= 0 else {}


static func go(dir: int) -> bool:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null or s == null:
		return false
	var e: Dictionary = target(d, s, dir)
	if e.is_empty():
		Events.toast(NONE_AT_ALL if stops(d, s).is_empty() else (NONE_AFTER if dir > 0 else NONE_BEFORE))
		return false
	return bool(load("res://ui/timeline/timeline_warnings.gd").call("jump", e))

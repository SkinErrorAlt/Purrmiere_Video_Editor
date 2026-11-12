extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const OVERWRITE := "overwrite"

static var enabled: bool = true
static var used: int = 0
static var fell_back: int = 0


class LiftAround extends "res://doc/commands/composite.gd":
	const EditCmds := preload("res://doc/commands/edit_cmds.gd")

	var t0: float = 0.0
	var t1: float = 0.0
	var track_id: String = ""
	var skip: PackedStringArray = PackedStringArray()

	func _init(p_seq_id: String, p_t0: float, p_t1: float, p_track_id: String, p_skip: PackedStringArray) -> void:
		label = "Lift"
		seq_id = p_seq_id
		t0 = minf(p_t0, p_t1)
		t1 = maxf(p_t0, p_t1)
		track_id = p_track_id
		skip = p_skip

	func _others(s: Sequence, t: Track) -> PackedStringArray:
		var ids: PackedStringArray = PackedStringArray()
		for c: Clip in s.clips_overlapping(t, t0, t1):
			if not skip.has(c.id):
				ids.append(c.id)
		return ids

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		var t: Track = s.track_by_id(track_id) if s != null else null
		if t == null or t.locked or t1 - t0 <= EditMath.EPS:
			return false
		var ids: PackedStringArray = _others(s, t)
		if ids.is_empty():
			return false
		apply(doc, EditCmds.SplitClips.new(seq_id, ids, t0, false))
		apply(doc, EditCmds.SplitClips.new(seq_id, _others(s, t), t1, false))
		var inside: PackedStringArray = PackedStringArray()
		for id: String in _others(s, t):
			var c: Clip = s.clip_by_id(id)
			if c.start >= t0 - EditMath.EPS and c.end() <= t1 + EditMath.EPS:
				inside.append(c.id)
		if inside.is_empty():
			return false
		apply(doc, ClipCmds.RemoveClips.new(seq_id, inside))
		return true


static func commands(seq: Sequence, rows: Array[Dictionary], delta_t: float, mode: String, ids: PackedStringArray) -> Array[Command]:
	var out: Array[Command] = []
	if not enabled or seq == null or mode != OVERWRITE or rows.is_empty():
		return out
	var moves: Array[Dictionary] = []
	var lifts: Array[Command] = []
	for r: Dictionary in rows:
		var c: Clip = r["clip"]
		var dest: Track = r["track"]
		var own: Track = seq.track_of(c.id)
		if own == null or dest != own or dest.part_for(String(r["kind"])) != c.part:
			fell_back += 1
			return out
		moves.append({"id": c.id, "start": c.start + delta_t, "track_id": dest.id})
		lifts.append(LiftAround.new(seq.id, c.start + delta_t, c.end() + delta_t, dest.id, ids))
	out.append_array(lifts)
	out.append(ClipCmds.MoveClips.new(seq.id, moves))
	used += 1
	return out

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const FreeTransition := preload("res://doc/free_transition.gd")
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const BandCmds := preload("res://doc/commands/speed_band_cmds.gd")
const FreeRide := preload("res://doc/commands/free_ride_cmds.gd")
const LABEL := "Move everything after"
const EPS := 0.00001
const OVERLAP := "overlap"


const FenceMath := preload("res://doc/commands/edit_math.gd")

class MoveAfter extends "res://doc/commands/composite.gd":
	var clip_ids: PackedStringArray = PackedStringArray()
	var free: Array[Dictionary] = []
	var delta: float = 0.0
	var place: String = "overwrite"
	var applied: float = 0.0

	func _init(p_seq_id: String, p_clip_ids: PackedStringArray, p_free: Array[Dictionary], p_delta: float, p_place: String) -> void:
		label = LABEL
		seq_id = p_seq_id
		clip_ids = p_clip_ids
		free = p_free.duplicate(true)
		delta = p_delta
		place = p_place

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var lowest: float = INF
		var first_on: Dictionary = {}
		var clips: Array[Clip] = []
		for id: String in clip_ids:
			var c: Clip = s.clip_by_id(id)
			var t: Track = s.track_of(id)
			if c == null or t == null or t.locked:
				continue
			clips.append(c)
			lowest = minf(lowest, c.start)
			if not first_on.has(t.id) or c.start < float(first_on[t.id]):
				first_on[t.id] = c.start
		var shifts: Array[Dictionary] = []
		for f: Dictionary in free:
			var tr: Track = s.track_by_id(String(f.get("track_id", "")))
			if tr == null or tr.locked:
				continue
			var ft: Dictionary = FreeTransition.by_id(tr.free_transitions, String(f.get("id", "")))
			if ft.is_empty():
				continue
			lowest = minf(lowest, FreeTransition.start_of(ft))
			shifts.append({"track_id": tr.id, "id": FreeTransition.id_of(ft), "start": FreeTransition.start_of(ft)})
		if clips.is_empty() and shifts.is_empty():
			return false
		applied = maxf(delta, -lowest) if lowest < INF else delta
		if absf(applied) < EPS:
			return false
		if applied < 0.0 and place != OVERLAP:
			for tid: Variant in first_on.keys():
				var at: float = float(first_on[tid])
				apply(doc, EditCmds.LiftRange.new(seq_id, at + applied, at, PackedStringArray([String(tid)])))
		var moves: Array[Dictionary] = []
		for c2: Clip in clips:
			if s.clip_by_id(c2.id) == null:
				continue
			moves.append({"id": c2.id, "start": c2.start + applied})
		if not moves.is_empty():
			apply(doc, BandCmds.ShiftStarts.new(seq_id, moves))
		for m: Dictionary in shifts:
			m["start"] = float(m["start"]) + applied
		if not shifts.is_empty():
			apply(doc, FreeRide.ShiftFree.new(seq_id, shifts))
		return not steps.is_empty()


static func forward_ids(s: Sequence, t: float, only: Track = null, back: bool = false) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if s == null:
		return out
	var tracks: Array[Track] = []
	if only != null:
		tracks.append(only)
	else:
		tracks = s.all_tracks()
	var stop: float = INF if back else FenceMath.fence_stop(s, t)
	for tr: Track in tracks:
		for c: Clip in tr.clips:
			if not back and c.start >= stop:
				continue
			if (not back and c.end() > t + EPS) or (back and c.start < t - EPS):
				out.append(c.id)
	return out


static func forward_free(s: Sequence, t: float, only: Track = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s == null:
		return out
	var tracks: Array[Track] = []
	if only != null:
		tracks.append(only)
	else:
		tracks = s.all_tracks()
	for tr: Track in tracks:
		if tr.locked:
			continue
		for ft: Dictionary in tr.free_transitions:
			if FreeTransition.start_of(ft) >= FenceMath.fence_stop(s, t):
				continue
			if FreeTransition.start_of(ft) + FreeTransition.duration_of(ft) > t + EPS:
				out.append({"track_id": tr.id, "id": FreeTransition.id_of(ft)})
	return out


static func fast_ok(s: Sequence, ids: PackedStringArray, every_track: bool) -> bool:
	if s == null or not every_track:
		return false
	var seen: Dictionary = {}
	for id: String in ids:
		var t: Track = s.track_of(id)
		if t == null or seen.has(t):
			continue
		seen[t] = true
		if t.has_stack():
			return false
	return true


static func command(s: Sequence, ids: PackedStringArray, free: Array[Dictionary], delta: float, place: String) -> MoveAfter:
	return MoveAfter.new(s.id, ids, free, delta, place)

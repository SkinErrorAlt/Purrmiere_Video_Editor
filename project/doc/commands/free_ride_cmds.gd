extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const FreeTransition := preload("res://doc/free_transition.gd")
const EPS := 0.00001


class ShiftFree extends "res://doc/commands/command.gd":
	var moves: Array[Dictionary] = []
	var _old: Array[Dictionary] = []

	func _init(p_seq_id: String, p_moves: Array[Dictionary]) -> void:
		label = "Move transitions"
		seq_id = p_seq_id
		moves = p_moves.duplicate(true)

	func _apply(doc: Project, list: Array[Dictionary]) -> void:
		var s: Sequence = seq(doc)
		var touched: Dictionary = {}
		for m: Dictionary in list:
			var tr: Track = s.track_by_id(String(m["track_id"]))
			if tr == null:
				continue
			for ft: Dictionary in tr.free_transitions:
				if FreeTransition.id_of(ft) == String(m["id"]):
					ft[FreeTransition.KEY_START] = maxf(float(m["start"]), 0.0)
					touched[tr] = true
					break
		for tr2: Variant in touched.keys():
			(tr2 as Track).free_transitions.sort_custom(FreeTransition._by_start)
			(tr2 as Track).mark_changed()
		doc.touch("structure")

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		_old = []
		for m: Dictionary in moves:
			var tr: Track = s.track_by_id(String(m["track_id"])) if s != null else null
			if tr == null:
				continue
			var ft: Dictionary = FreeTransition.by_id(tr.free_transitions, String(m["id"]))
			if ft.is_empty():
				continue
			_old.append({"track_id": tr.id, "id": String(m["id"]), "start": FreeTransition.start_of(ft)})
		if _old.is_empty():
			ok = false
			return
		_apply(doc, moves)

	func undo(doc: Project) -> void:
		_apply(doc, _old)


## The free transitions a ripple from `from_t` carries by `delta`, stopping at `stop` (a locked region's start).
static func after(tracks: Array[Track], from_t: float, delta: float, stop: float = INF) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if absf(delta) < EPS:
		return out
	for tr: Track in tracks:
		if tr == null or tr.locked:
			continue
		for ft: Dictionary in tr.free_transitions:
			var st: float = FreeTransition.start_of(ft)
			if st >= from_t - EPS and st < stop:
				out.append({"track_id": tr.id, "id": FreeTransition.id_of(ft), "start": maxf(st + delta, 0.0)})
	return out


static func across(s: Sequence, track_ids: PackedStringArray, at: float, delta: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s == null or absf(delta) < EPS:
		return out
	for tid: String in track_ids:
		var tr: Track = s.track_by_id(tid)
		if tr == null or tr.locked:
			continue
		for ft: Dictionary in tr.free_transitions:
			var st: float = FreeTransition.start_of(ft)
			var en: float = st + FreeTransition.duration_of(ft)
			if st <= at + EPS and en >= at - EPS:
				out.append({"track_id": tr.id, "id": FreeTransition.id_of(ft), "start": maxf(st + delta, 0.0)})
	return out


static func ride(owner: Object, doc: Project, seq_id: String, moves: Array[Dictionary]) -> void:
	if moves.is_empty() or owner == null:
		return
	owner.call("apply", doc, ShiftFree.new(seq_id, moves))

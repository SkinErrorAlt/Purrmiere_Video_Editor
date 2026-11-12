extends RefCounted

const FreeTransition := preload("res://doc/free_transition.gd")
const Timing := preload("res://doc/transition_timing.gd")
const LIVE_PARAM := "free_param|"
const LIVE_SPAN := "free_span|"


class SetFreeParam extends "res://doc/commands/command.gd":
	var track_id: String = ""
	var ft_id: String = ""
	var key: String = ""
	var anim: Dictionary = {}
	var old: Dictionary = {}
	var old_ft: Dictionary = {}

	func _init(p_seq_id: String, p_track_id: String, p_ft_id: String, p_key: String, p_anim: Dictionary) -> void:
		label = "Set transition " + p_key
		seq_id = p_seq_id
		track_id = p_track_id
		ft_id = p_ft_id
		key = p_key
		anim = p_anim.duplicate(true)

	func live_key() -> String:
		return LIVE_PARAM + track_id + "|" + ft_id + "|" + key

	func do(doc: Project) -> void:
		var t: Track = track(doc, track_id)
		var ft: Dictionary = FreeTransition.by_id(t.free_transitions, ft_id) if t != null else {}
		if ft.is_empty():
			ok = false
			return
		old_ft = ft.duplicate(true)
		old = FreeTransition.param_of(ft, key).duplicate(true)
		t.free_transitions = FreeTransition.put(t.free_transitions, FreeTransition.with_param(ft, key, anim))
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var t: Track = track(doc, track_id)
		if t == null or old_ft.is_empty():
			return
		t.free_transitions = FreeTransition.put(t.free_transitions, old_ft)
		doc.touch("meta")


class SetFreeSpan extends "res://doc/commands/command.gd":
	var track_id: String = ""
	var ft_id: String = ""
	var duration: float = 0.0
	var old_ft: Dictionary = {}

	func _init(p_seq_id: String, p_track_id: String, p_ft_id: String, p_duration: float) -> void:
		label = "Set transition length"
		seq_id = p_seq_id
		track_id = p_track_id
		ft_id = p_ft_id
		duration = maxf(p_duration, FreeTransition.MIN_DURATION)

	func live_key() -> String:
		return LIVE_SPAN + track_id + "|" + ft_id

	func do(doc: Project) -> void:
		var t: Track = track(doc, track_id)
		var ft: Dictionary = FreeTransition.by_id(t.free_transitions, ft_id) if t != null else {}
		if ft.is_empty() or FreeTransition.overlaps(t.free_transitions, FreeTransition.start_of(ft), duration, ft_id):
			ok = false
			return
		old_ft = ft.duplicate(true)
		var next: Dictionary = FreeTransition.with_span(ft, FreeTransition.start_of(ft), duration)
		next[FreeTransition.KEY_SPEC] = Timing.stretched(FreeTransition.spec_of(ft), duration)
		t.free_transitions = FreeTransition.put(t.free_transitions, next)
		doc.touch("structure")

	func undo(doc: Project) -> void:
		var t: Track = track(doc, track_id)
		if t == null or old_ft.is_empty():
			return
		t.free_transitions = FreeTransition.put(t.free_transitions, old_ft)
		doc.touch("structure")

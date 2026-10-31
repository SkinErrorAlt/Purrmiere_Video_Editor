extends RefCounted

const VERSION := 1


class SetLinkRule extends "res://doc/commands/command.gd":
	var link_id: String = ""
	var as_one: bool = false
	var fill: bool = false
	var old: Dictionary = {}

	func _init(p_seq_id: String, p_link_id: String, p_as_one: bool, p_fill: bool, p_label: String) -> void:
		label = p_label
		seq_id = p_seq_id
		link_id = p_link_id
		as_one = p_as_one
		fill = p_fill

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null or link_id.is_empty():
			ok = false
			return
		old = s.link_rule(link_id)
		if bool(old.get("as_one", false)) == as_one and bool(old.get("fill", false)) == fill:
			ok = false
			return
		s.set_link_rule(link_id, as_one, fill)
		doc.touch("structure")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null:
			return
		s.set_link_rule(link_id, bool(old.get("as_one", false)), bool(old.get("fill", false)))
		doc.touch("structure")

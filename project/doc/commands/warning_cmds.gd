extends RefCounted

const CHANGE_KIND := "warnings"


class SetWarnings extends "res://doc/commands/command.gd":
	var clip_id: String = ""
	var value: Array[Dictionary] = []
	var old: Array[Dictionary] = []

	func _init(p_seq_id: String, p_clip_id: String, p_value: Array[Dictionary]) -> void:
		label = "Set warnings"
		seq_id = p_seq_id
		clip_id = p_clip_id
		for w: Dictionary in p_value:
			value.append(w.duplicate(true))

	func _write(doc: Project, v: Array[Dictionary]) -> void:
		var c: Clip = clip(doc, clip_id)
		if c == null:
			ok = false
			return
		var fresh: Array[Dictionary] = []
		for w: Dictionary in v:
			fresh.append(w.duplicate(true))
		c.warnings = fresh
		doc.touch("warnings")

	func do(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		if c == null:
			ok = false
			return
		old = []
		for w: Dictionary in c.warnings:
			old.append(w.duplicate(true))
		_write(doc, value)

	func undo(doc: Project) -> void:
		_write(doc, old)

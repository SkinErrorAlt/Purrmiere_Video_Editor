extends RefCounted

const VERSION := 1


class SetSubProjects extends "res://doc/commands/command.gd":
	var before: Array[Dictionary] = []
	var after: Array[Dictionary] = []

	func _init(p_label: String, p_after: Array[Dictionary]) -> void:
		label = p_label
		for g: Dictionary in p_after:
			after.append(g.duplicate(true))

	func do(doc: Project) -> void:
		before = []
		for g: Dictionary in doc.sub_projects:
			before.append(g.duplicate(true))
		if JSON.stringify(before) == JSON.stringify(after):
			ok = false
			return
		_put(doc, after)

	func undo(doc: Project) -> void:
		_put(doc, before)

	func _put(doc: Project, list: Array[Dictionary]) -> void:
		var out: Array[Dictionary] = []
		for g: Dictionary in list:
			out.append(g.duplicate(true))
		doc.sub_projects = out
		doc.touch("structure")

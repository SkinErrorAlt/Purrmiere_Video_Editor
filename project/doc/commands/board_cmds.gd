extends RefCounted

const Project := preload("res://doc/project.gd")
const VERSION := 1
const STORE_KEY := "bin_boards"
const CHANGE_KIND := "bin_board"


static func store(doc: Project) -> Dictionary:
	var raw: Variant = doc.view.get(STORE_KEY, null)
	if raw is Dictionary:
		return raw
	var fresh: Dictionary = {}
	doc.view[STORE_KEY] = fresh
	return fresh


class SetBoard extends "res://doc/commands/command.gd":
	var key: String = ""
	var after: Dictionary = {}
	var before: Dictionary = {}
	var had: bool = false

	func _init(p_key: String, p_after: Dictionary, p_label: String = "Board") -> void:
		label = p_label
		key = p_key
		after = p_after.duplicate(true)

	func live_key() -> String:
		return "bin_board|" + key

	func _store(doc: Project) -> Dictionary:
		var raw: Variant = doc.view.get("bin_boards", null)
		if raw is Dictionary:
			return raw
		var fresh: Dictionary = {}
		doc.view["bin_boards"] = fresh
		return fresh

	func do(doc: Project) -> void:
		var st: Dictionary = _store(doc)
		had = st.has(key)
		before = (st[key] as Dictionary).duplicate(true) if had and st[key] is Dictionary else {}
		if had and before == after:
			ok = false
			return
		st[key] = after.duplicate(true)
		doc.touch("bin_board")

	func undo(doc: Project) -> void:
		var st: Dictionary = _store(doc)
		if had:
			st[key] = before.duplicate(true)
		else:
			st.erase(key)
		doc.touch("bin_board")

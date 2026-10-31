extends RefCounted

const VERSION := 1
const TOUCH := "tracking"


class SetSet extends "res://doc/commands/command.gd":
	var set_id: String = ""
	var before: Dictionary = {}
	var after: Dictionary = {}
	var had: bool = false
	var key: String = ""

	func _init(p_label: String, p_set_id: String, p_after: Dictionary, p_key: String = "") -> void:
		label = p_label
		set_id = p_set_id
		after = p_after.duplicate(true)
		key = p_key

	func live_key() -> String:
		return "tracking|" + set_id + "|" + (key if not key.is_empty() else label)

	func do(doc: Project) -> void:
		var st: Dictionary = doc.tracking
		had = st.has(set_id)
		before = (st[set_id] as Dictionary).duplicate(true) if had else {}
		if had and before == after:
			ok = false
			return
		if not had and after.is_empty():
			ok = false
			return
		_put(doc, after)

	func undo(doc: Project) -> void:
		_put(doc, before if had else {})

	func _put(doc: Project, value: Dictionary) -> void:
		if value.is_empty():
			doc.tracking.erase(set_id)
		else:
			doc.tracking[set_id] = value.duplicate(true)
		doc.touch(TOUCH)

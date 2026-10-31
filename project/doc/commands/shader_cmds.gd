extends RefCounted

const ImportedShaders := preload("res://doc/imported_shaders.gd")
const CHANGE_KIND := "meta"


class SetImportedShader extends "res://doc/commands/command.gd":
	var id: String = ""
	var after: Dictionary = {}
	var before: Dictionary = {}
	var had: bool = false

	func _init(p_id: String, p_entry: Dictionary, p_label: String = "Import shader") -> void:
		label = p_label
		id = p_id
		after = p_entry.duplicate(true)

	func do(doc: Project) -> void:
		var st: Dictionary = doc.imported_shaders
		had = st.has(id)
		before = (st[id] as Dictionary).duplicate(true) if had else {}
		if had and before == after:
			ok = false
			return
		if after.is_empty():
			if not had:
				ok = false
				return
			st.erase(id)
		else:
			st[id] = after.duplicate(true)
		ImportedShaders.refresh(doc)
		doc.touch(CHANGE_KIND)

	func undo(doc: Project) -> void:
		var st: Dictionary = doc.imported_shaders
		if had:
			st[id] = before.duplicate(true)
		else:
			st.erase(id)
		ImportedShaders.refresh(doc)
		doc.touch(CHANGE_KIND)


class SwitchEffectId extends "res://doc/commands/command.gd":
	var from_id: String = ""
	var to_id: String = ""
	var defaults: Dictionary = {}
	var only_clip: String = ""
	var _changed: Array = []

	func _init(p_from: String, p_to: String, p_defaults: Dictionary, p_label: String, p_only_clip: String = "") -> void:
		label = p_label
		from_id = p_from
		to_id = p_to
		defaults = p_defaults.duplicate(true)
		only_clip = p_only_clip

	func do(doc: Project) -> void:
		_changed = []
		for s: Sequence in doc.sequences:
			for t: Track in s.all_tracks():
				for c: Clip in t.clips:
					if not only_clip.is_empty() and c.id != only_clip:
						continue
					for i: int in c.effects.size():
						var e: Dictionary = c.effects[i]
						if String(e.get("id", "")) != from_id:
							continue
						_changed.append({"clip": c, "index": i, "old": e.duplicate(true)})
						e["id"] = to_id
						var params: Dictionary = e.get("params", {}) if e.get("params") is Dictionary else {}
						for k: Variant in defaults.keys():
							if not params.has(k):
								params[k] = AnimProp.make(defaults[k])
						e["params"] = params
		if _changed.is_empty():
			ok = false
			return
		ImportedShaders.refresh(doc)
		doc.touch(CHANGE_KIND)

	func undo(doc: Project) -> void:
		for i: int in range(_changed.size() - 1, -1, -1):
			var rec: Dictionary = _changed[i]
			var c: Clip = rec["clip"]
			var at: int = int(rec["index"])
			if at < c.effects.size():
				c.effects[at] = (rec["old"] as Dictionary).duplicate(true)
		ImportedShaders.refresh(doc)
		doc.touch(CHANGE_KIND)

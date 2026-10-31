extends RefCounted

const VERSION := 1
const LIVE_PREFIX := "clip_param|many|"


class SetParams extends "res://doc/commands/command.gd":
	var entries: Array[Dictionary] = []
	var key: String = ""
	var path: String = ""
	var audio: bool = false

	func _init(p_seq_id: String, p_entries: Array[Dictionary], p_key: String, p_label: String) -> void:
		label = p_label
		seq_id = p_seq_id
		key = p_key
		for e: Dictionary in p_entries:
			var p: String = String(e.get("path", ""))
			entries.append({"clip_id": String(e.get("clip_id", "")), "path": p, "anim": (e.get("anim", {}) as Dictionary).duplicate(true), "old": {}})
			if path.is_empty():
				path = p
			if p.begins_with("audio"):
				audio = true

	func live_key() -> String:
		return LIVE_PREFIX + key

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		var any: bool = false
		for e: Dictionary in entries:
			var c: Clip = s.clip_by_id(String(e["clip_id"])) if s != null else null
			if c == null:
				continue
			e["old"] = c.get_param(String(e["path"])).duplicate(true)
			e["anim"] = preload("res://doc/speed_ease.gd").fresh(String(e["path"]), e["old"], e["anim"])
			if c.set_param(String(e["path"]), e["anim"]):
				any = true
		ok = any
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		for i: int in range(entries.size() - 1, -1, -1):
			var e: Dictionary = entries[i]
			var c: Clip = s.clip_by_id(String(e["clip_id"])) if s != null else null
			if c == null:
				continue
			var old: Dictionary = e["old"]
			if old.is_empty():
				c.erase_param(String(e["path"]))
			else:
				c.set_param(String(e["path"]), old)
		doc.touch("meta")

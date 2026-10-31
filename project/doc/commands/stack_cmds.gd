extends RefCounted

const VERSION := 1
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const MODE_FIELDS: PackedStringArray = ["free_tracks", "overlap_clips"]


class SetStackOrder extends "res://doc/commands/command.gd":
	var order: Dictionary = {}
	var old: Dictionary = {}

	func _init(p_seq_id: String, p_order: Dictionary, p_label: String = "Stack order") -> void:
		label = p_label
		seq_id = p_seq_id
		order = p_order.duplicate()

	func _write(doc: Project, values: Dictionary) -> void:
		var s: Sequence = seq(doc)
		for id: Variant in values.keys():
			var c: Clip = s.clip_by_id(String(id))
			if c == null:
				continue
			c.stack = int(values[id])
			var t: Track = s.track_of(c.id)
			if t != null:
				t.can_stack = true
				t.mark_changed()
		doc.touch("structure")

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null:
			ok = false
			return
		old = {}
		for id: Variant in order.keys():
			var c: Clip = s.clip_by_id(String(id))
			if c != null and c.stack != int(order[id]):
				old[String(id)] = c.stack
		if old.is_empty():
			ok = false
			return
		_write(doc, order)

	func undo(doc: Project) -> void:
		_write(doc, old)


class SetSequenceMode extends "res://doc/commands/command.gd":
	var field: String = ""
	var value: bool = false
	var old: bool = false

	func _init(p_seq_id: String, p_field: String, p_value: bool) -> void:
		seq_id = p_seq_id
		field = p_field
		value = p_value
		label = ("Free tracks " if p_field == "free_tracks" else "Clips may overlap ") + ("on" if p_value else "off")

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null or not (field in MODE_FIELDS) or bool(s.get(field)) == value:
			ok = false
			return
		old = bool(s.get(field))
		s.set(field, value)
		s.invalidate()
		doc.touch("structure")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		s.set(field, old)
		s.invalidate()
		doc.touch("structure")


class PasteOverlap extends "res://doc/commands/composite.gd":
	var clipboard: Dictionary = {}
	var t: float = 0.0
	var pasted_ids: PackedStringArray = PackedStringArray()

	func _init(p_seq_id: String, p_clipboard: Dictionary, p_t: float) -> void:
		label = "Paste overlapping"
		seq_id = p_seq_id
		clipboard = p_clipboard.duplicate(true)
		t = p_t

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var paste: EditCmds.PasteClips = EditCmds.PasteClips.new(seq_id, clipboard, t)
		var rows: Array[Dictionary] = paste.prepare(doc, s)
		if rows.is_empty():
			return false
		paste.add_groups(doc, s, self)
		pasted_ids = PackedStringArray()
		for i: int in rows.size():
			var row: Dictionary = rows[i]
			var tr: Track = s.track_by_id(String(row["track_id"]))
			if tr == null:
				continue
			var d: Dictionary = row["clip"]
			var own_part: String = String(d.get("part", ""))
			var want: String = own_part if not own_part.is_empty() else tr.kind
			var p2: String = tr.part_for(want)
			if p2.is_empty():
				d.erase("part")
			else:
				d["part"] = p2
			var t0: float = float(d.get("start", 0.0))
			var base: int = tr.top_stack_over(t0, t0 + float(d.get("duration", 0.0)))
			if base != 0:
				d["stack"] = base
			else:
				d.erase("stack")
			apply(doc, ClipCmds.PlaceClip.new(seq_id, tr.id, d))
			pasted_ids.append(String(d["id"]))
		return not pasted_ids.is_empty()

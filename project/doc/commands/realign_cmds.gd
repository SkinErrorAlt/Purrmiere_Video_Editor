extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const EditMath := preload("res://doc/commands/edit_math.gd")
const EPS := 0.00001
const LOOP_NEEDS_SPEED := "Loop needs clips that play forwards at a steady speed, so the source was held at its ends instead"
const LOOP_NEEDS_FILE := "Loop needs clips from a file with a known length, so the source was held at its ends instead"
const LOOP_TOO_LONG := "The section is longer than its source, so it cannot loop round; the source was held at its ends instead"


class Realign extends "res://doc/commands/composite.gd":
	var clip_ids: PackedStringArray = PackedStringArray()
	var a: float = 0.0
	var b: float = 0.0
	var span: bool = false
	var delta: float = 0.0
	var loop: bool = false
	var applied: float = 0.0
	var clamped: bool = false
	var looped: bool = false
	var loop_refused: String = ""
	var cuts: PackedFloat64Array = PackedFloat64Array()
	var wraps: PackedFloat64Array = PackedFloat64Array()
	var pieces: PackedStringArray = PackedStringArray()

	func _init(p_seq_id: String, p_clip_ids: PackedStringArray, p_delta: float, p_loop: bool, p_span: bool = false, p_a: float = 0.0, p_b: float = 0.0) -> void:
		label = "Realign"
		seq_id = p_seq_id
		clip_ids = p_clip_ids.duplicate()
		delta = p_delta
		loop = p_loop
		span = p_span
		a = p_a
		b = p_b

	func live_key() -> String:
		return "realign|" + ",".join(clip_ids)

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null or absf(delta) < EPS:
			return false
		var ids: PackedStringArray = PackedStringArray()
		for id: String in clip_ids:
			if s.clip_by_id(id) != null and not ids.has(id):
				ids.append(id)
		if ids.is_empty():
			return false
		if span:
			ids = _cut(doc, s, ids, a)
			ids = _cut(doc, s, ids, b)
			ids = _inside(s, ids)
			if ids.is_empty():
				return false
		pieces = ids.duplicate()
		if loop:
			loop_refused = _loop_blocker(doc, s, ids)
			if loop_refused.is_empty():
				return _loop(doc, s, ids)
		var slip := EditCmds.SlipClip.new(seq_id, ids, -delta)
		apply(doc, slip)
		if not slip.ok:
			return false
		applied = -slip.applied_delta
		clamped = absf(applied - delta) > EPS
		return true

	func _cut(doc: Project, s: Sequence, ids: PackedStringArray, t: float) -> PackedStringArray:
		var crossing: PackedStringArray = PackedStringArray()
		for id: String in ids:
			var c: Clip = s.clip_by_id(id)
			if c != null and t > c.start + EPS and t < c.end() - EPS:
				crossing.append(id)
		if crossing.is_empty():
			return ids
		var split := EditCmds.SplitClips.new(seq_id, crossing, t, false)
		apply(doc, split)
		if not split.ok:
			return ids
		cuts.append(t)
		var out: PackedStringArray = ids.duplicate()
		for r: String in split.right_ids:
			if not out.has(r):
				out.append(r)
		return out

	func _inside(s: Sequence, ids: PackedStringArray) -> PackedStringArray:
		var out: PackedStringArray = PackedStringArray()
		for id: String in ids:
			var c: Clip = s.clip_by_id(id)
			if c != null and c.start >= a - EPS and c.end() <= b + EPS:
				out.append(id)
		return out

	func _loop_blocker(doc: Project, s: Sequence, ids: PackedStringArray) -> String:
		for id: String in ids:
			var c: Clip = s.clip_by_id(id)
			if c == null:
				continue
			var sp: float = EditMath.static_speed(c)
			if sp <= 0.0:
				return LOOP_NEEDS_SPEED
			if c.is_nest() or not EditMath.media_bounded(doc, c) or EditMath.media_duration(doc, c) <= EPS:
				return LOOP_NEEDS_FILE
			if c.duration * sp > EditMath.media_duration(doc, c) + EPS:
				return LOOP_TOO_LONG
		return ""

	func _loop(doc: Project, s: Sequence, ids: PackedStringArray) -> bool:
		var groups: Dictionary = {}
		var wrap_in: Dictionary = {}
		for id: String in ids:
			var c: Clip = s.clip_by_id(id)
			var sp: float = EditMath.static_speed(c)
			var total: float = EditMath.media_duration(doc, c)
			var src_len: float = c.duration * sp
			var raw: float = c.in_offset - delta * sp
			if raw < -EPS or raw + src_len > total + EPS:
				looped = true
			var new_in: float = fposmod(raw, total)
			if (total - new_in) / sp < EPS * 4.0:
				new_in = 0.0
			var tw: float = c.start + (total - new_in) / sp
			if new_in + src_len <= total + EPS or tw >= c.end() - EPS * 4.0:
				apply(doc, EditCmds.SetTiming.new(seq_id, id, c.start, c.duration, minf(new_in, maxf(total - src_len, 0.0)), 0.0))
				continue
			var key: String = "%.7f" % tw
			if not groups.has(key):
				groups[key] = {"t": tw, "ids": PackedStringArray()}
			var list: PackedStringArray = (groups[key] as Dictionary)["ids"]
			list.append(id)
			(groups[key] as Dictionary)["ids"] = list
			wrap_in[id] = new_in
		for g: Variant in groups.values():
			var gd: Dictionary = g
			var gids: PackedStringArray = gd["ids"]
			var split := EditCmds.SplitClips.new(seq_id, gids, float(gd["t"]), false)
			apply(doc, split)
			if not split.ok or split.right_ids.size() != gids.size():
				return false
			wraps.append(float(gd["t"]))
			for i: int in gids.size():
				var left: Clip = s.clip_by_id(gids[i])
				var right: Clip = s.clip_by_id(split.right_ids[i])
				if left == null or right == null:
					return false
				apply(doc, EditCmds.SetTiming.new(seq_id, left.id, left.start, left.duration, float(wrap_in[left.id]), 0.0))
				apply(doc, EditCmds.SetTiming.new(seq_id, right.id, right.start, right.duration, 0.0, 0.0))
				pieces.append(right.id)
		wraps.sort()
		applied = delta
		return true

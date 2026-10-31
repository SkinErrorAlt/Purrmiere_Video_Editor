extends RefCounted

const VERSION := 1
const EditCmds := preload("res://doc/commands/edit_cmds.gd")


class SetClipKey extends "res://doc/commands/command.gd":
	var clip_id: String = ""
	var field: String = ""
	var key: String = ""
	var value: Variant = null
	var had: bool = false
	var old: Variant = null

	func _init(p_seq_id: String, p_clip_id: String, p_field: String, p_key: String, p_value: Variant, p_label: String) -> void:
		label = p_label
		seq_id = p_seq_id
		clip_id = p_clip_id
		field = p_field
		key = p_key
		value = dup(p_value)

	func live_key() -> String:
		return "clip_key|" + clip_id + "|" + field + "|" + key

	func _target(c: Clip) -> Dictionary:
		if field == "audio":
			return c.audio
		return c.props

	func do(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		if c == null or not (field == "audio" or field == "props"):
			ok = false
			return
		var d: Dictionary = _target(c)
		had = d.has(key)
		old = dup(d.get(key))
		if had and old == value:
			ok = false
			return
		if value == null:
			if not had:
				ok = false
				return
			d.erase(key)
		else:
			d[key] = dup(value)
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		if c == null:
			return
		var d: Dictionary = _target(c)
		if had:
			d[key] = dup(old)
		else:
			d.erase(key)
		doc.touch("meta")


class FreezeFrame extends "res://doc/commands/composite.gd":
	var clip_id: String = ""
	var t: float = 0.0
	var length: float = 2.0
	var ripple: bool = true
	var hold_id: String = ""

	func _init(p_seq_id: String, p_clip_id: String, p_t: float, p_length: float, p_ripple: bool) -> void:
		label = "Freeze frame"
		seq_id = p_seq_id
		clip_id = p_clip_id
		t = p_t
		length = p_length
		ripple = p_ripple

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null or length <= EditMath.EPS:
			return false
		var c: Clip = s.clip_by_id(clip_id)
		var tr: Track = s.track_of(clip_id)
		if c == null or tr == null or tr.locked or not tr.is_picture(c):
			return false
		if t < c.start - EditMath.EPS or t >= c.end() - EditMath.EPS:
			return false
		var at: float = maxf(t, c.start)
		var hold: Clip = c.copy()
		hold.shift_keys(-(at - c.start))
		hold.id = doc.mint_id("c")
		hold.start = at
		hold.duration = length
		hold.in_offset = c.source_time(at)
		hold.speed = AnimProp.make(0.0)
		hold.transition_in = {}
		hold.transition_out = {}
		hold.link_id = ""
		hold.markers = []
		hold.props.erase("fade_in")
		hold.props.erase("fade_out")
		hold_id = hold.id
		if ripple:
			apply(doc, EditCmds.InsertGap.new(seq_id, at, length, PackedStringArray([tr.id])))
		else:
			apply(doc, EditCmds.LiftRange.new(seq_id, at, at + length, PackedStringArray([tr.id])))
		var placed: Command = apply(doc, ClipCmds.PlaceClip.new(seq_id, tr.id, hold.to_dict()))
		return placed.ok


class HoldToEnd extends "res://doc/commands/composite.gd":
	var clip_id: String = ""
	var t: float = 0.0
	var hold_id: String = ""

	func _init(p_seq_id: String, p_clip_id: String, p_t: float) -> void:
		label = "Hold this frame to the end"
		seq_id = p_seq_id
		clip_id = p_clip_id
		t = p_t

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var c: Clip = s.clip_by_id(clip_id)
		var tr: Track = s.track_of(clip_id)
		if c == null or tr == null or tr.locked or not tr.is_picture(c):
			return false
		if t >= c.end() - EditMath.EPS or t < c.start - EditMath.EPS:
			return false
		var target: String = c.id
		if t > c.start + EditMath.EPS:
			var split: Command = apply(doc, EditCmds.SplitClips.new(seq_id, PackedStringArray([c.id]), t, false))
			var rights: PackedStringArray = split.get("right_ids")
			if not split.ok or rights.is_empty():
				return false
			target = rights[0]
		hold_id = target
		var held: Command = apply(doc, ClipCmds.SetClipParam.new(seq_id, target, "speed", AnimProp.make(0.0)))
		return held.ok


class HealEdit extends "res://doc/commands/composite.gd":
	var pairs: Array[PackedStringArray] = []
	var healed: PackedStringArray = PackedStringArray()

	func _init(p_seq_id: String, p_pairs: Array[PackedStringArray]) -> void:
		label = "Join through edit"
		seq_id = p_seq_id
		pairs = p_pairs.duplicate()

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		healed = PackedStringArray()
		for pair: PackedStringArray in pairs:
			if pair.size() < 2:
				continue
			var a: Clip = s.clip_by_id(pair[0])
			var b: Clip = s.clip_by_id(pair[1])
			if a == null or b == null or s.track_of(a.id) != s.track_of(b.id):
				continue
			var joined: Dictionary = a.to_dict()
			joined["duration"] = b.end() - a.start
			var marks: Array = joined.get("markers", [])
			for m: Marker in b.markers:
				var md: Dictionary = m.to_dict()
				md["time"] = m.time + (b.start - a.start)
				marks.append(md)
			if not marks.is_empty():
				joined["markers"] = marks
			apply(doc, ClipCmds.RemoveClips.new(seq_id, PackedStringArray([b.id])))
			apply(doc, ClipCmds.ReplaceClip.new(seq_id, a.id, joined))
			healed.append(a.id)
		return not healed.is_empty()


class CloseAllGaps extends "res://doc/commands/composite.gd":
	var track_ids: PackedStringArray = PackedStringArray()
	var closed: int = 0

	func _init(p_seq_id: String, p_track_ids: PackedStringArray) -> void:
		label = "Close all gaps"
		seq_id = p_seq_id
		track_ids = p_track_ids

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		closed = 0
		for tid: String in track_ids:
			var tr: Track = s.track_by_id(tid)
			if tr == null or tr.locked:
				continue
			var probes: PackedFloat64Array = PackedFloat64Array()
			var reach: float = -INF
			for i: int in tr.clips.size():
				var c: Clip = tr.clips[i]
				if reach > -INF and c.start - reach > EditMath.EPS:
					probes.append((reach + c.start) * 0.5)
				reach = maxf(reach, c.end())
			for k: int in range(probes.size() - 1, -1, -1):
				var cmd: Command = apply(doc, EditCmds.CloseGap.new(seq_id, tid, probes[k]))
				if cmd.ok:
					closed += 1
		return closed > 0


class CutAtMarkers extends "res://doc/commands/composite.gd":
	var times: PackedFloat64Array = PackedFloat64Array()
	var clip_ids: PackedStringArray = PackedStringArray()
	var track_ids: PackedStringArray = PackedStringArray()
	var expand_links: bool = true
	var cuts: int = 0

	func _init(p_seq_id: String, p_times: PackedFloat64Array, p_clip_ids: PackedStringArray, p_track_ids: PackedStringArray, p_expand_links: bool) -> void:
		label = "Cut at markers"
		seq_id = p_seq_id
		times = p_times
		clip_ids = p_clip_ids
		track_ids = p_track_ids
		expand_links = p_expand_links

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		cuts = 0
		var candidates: PackedStringArray = clip_ids.duplicate()
		for t: float in times:
			var ids: PackedStringArray = PackedStringArray()
			if not candidates.is_empty():
				for id: String in candidates:
					var c: Clip = s.clip_by_id(id)
					if c != null and t > c.start + EditMath.EPS and t < c.end() - EditMath.EPS and not ids.has(id):
						ids.append(id)
			else:
				for tid: String in track_ids:
					var tr: Track = s.track_by_id(tid)
					if tr == null or tr.locked:
						continue
					var hit: Clip = tr.clip_at(t)
					if hit != null and t > hit.start + EditMath.EPS and t < hit.end() - EditMath.EPS:
						ids.append(hit.id)
			if ids.is_empty():
				continue
			var split: Command = apply(doc, EditCmds.SplitClips.new(seq_id, ids, t, expand_links and clip_ids.is_empty()))
			if split.ok:
				cuts += 1
				if not candidates.is_empty():
					candidates.append_array(split.get("right_ids"))
		return cuts > 0

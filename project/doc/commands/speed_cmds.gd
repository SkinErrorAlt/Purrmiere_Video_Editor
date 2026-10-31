extends RefCounted

const VERSION := 1
const MODES: Array[String] = ["ripple", "trim_next", "hold_length", "stop_at_next"]
const MODE_LABELS: Array[String] = ["Push the clips after it along", "Trim the clip ahead, give it back when this one shrinks", "Keep this clip the same length, so it holds less or more footage", "Stop at the next clip, dropping whatever will not fit"]
const MIN_SPEED := 0.01
const MAX_SPEED := 100.0


static func mode_index(mode: String) -> int:
	var at: int = MODES.find(mode)
	return at if at >= 0 else 0


static func mode_at(index: int) -> String:
	return MODES[clampi(index, 0, MODES.size() - 1)]


class SetSpeed extends "res://doc/commands/composite.gd":
	const EditCmds := preload("res://doc/commands/edit_cmds.gd")
	const MIN_SPEED := 0.01
	const MAX_SPEED := 100.0

	var clip_ids: PackedStringArray = PackedStringArray()
	var speed: float = 1.0
	var keep_pitch: bool = false
	var mode: String = "ripple"
	var fit_length: float = -1.0
	var touch_pitch: bool = true

	func _init(p_seq_id: String, p_clip_ids: PackedStringArray, p_speed: float, p_keep_pitch: bool, p_mode: String) -> void:
		label = "Speed"
		seq_id = p_seq_id
		clip_ids = p_clip_ids.duplicate()
		speed = p_speed
		keep_pitch = p_keep_pitch
		mode = p_mode

	func _family(s: Sequence) -> Array[Clip]:
		var out: Array[Clip] = []
		var seen: Dictionary = {}
		var links: Dictionary = {}
		for id: String in clip_ids:
			var c: Clip = s.clip_by_id(id)
			if c == null:
				continue
			if not c.link_id.is_empty():
				links[c.link_id] = true
			elif not seen.has(c.id):
				seen[c.id] = true
				out.append(c)
		if not links.is_empty():
			for t: Track in s.all_tracks():
				for f: Clip in t.clips:
					if links.has(f.link_id) and not seen.has(f.id):
						seen[f.id] = true
						out.append(f)
		var kept: Array[Clip] = []
		for f2: Clip in out:
			var tr: Track = s.track_of(f2.id)
			if tr != null and not tr.locked:
				kept.append(f2)
		return kept

	func _room_to_next(s: Sequence, c: Clip) -> float:
		var tr: Track = s.track_of(c.id)
		if tr == null:
			return INF
		var nxt: Clip = tr.next_clip(c)
		return nxt.start - c.start if nxt != null else INF

	func _room_through_next(s: Sequence, c: Clip, frame: float) -> float:
		var tr: Track = s.track_of(c.id)
		if tr == null:
			return INF
		var nxt: Clip = tr.next_clip(c)
		if nxt == null:
			return INF
		return nxt.end() - frame - c.start


	func _give_back(doc: Project, s: Sequence, c: Clip) -> void:
		var tr: Track = s.track_of(c.id)
		if tr == null:
			return
		var nxt: Clip = tr.next_clip(c)
		if nxt == null or nxt.start <= c.end() + EditMath.EPS:
			return
		var sp: float = maxf(absf(nxt.static_speed()), MIN_SPEED)
		var handle: float = nxt.in_offset / sp
		var grow: float = minf(nxt.start - c.end(), handle)
		if grow <= EditMath.EPS:
			return
		apply(doc, EditCmds.SetTiming.new(seq_id, nxt.id, nxt.start - grow, nxt.duration + grow, nxt.in_offset - grow * sp, grow))

	func _take_from(doc: Project, s: Sequence, c: Clip) -> void:
		var tr: Track = s.track_of(c.id)
		if tr == null:
			return
		var nxt: Clip = tr.next_clip(c)
		if nxt == null or nxt.start >= c.end() - EditMath.EPS:
			return
		var sp: float = maxf(absf(nxt.static_speed()), MIN_SPEED)
		var eaten: float = minf(c.end() - nxt.start, nxt.duration)
		if eaten <= EditMath.EPS:
			return
		apply(doc, EditCmds.SetTiming.new(seq_id, nxt.id, nxt.start + eaten, nxt.duration - eaten, nxt.in_offset + eaten * sp, -eaten))

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var family: Array[Clip] = _family(s)
		if family.is_empty():
			return false
		var frame: float = 1.0 / maxf(s.fps, 1.0)
		var rows: Array[Dictionary] = []
		for c: Clip in family:
			var span: float = c.source_span()
			if span <= EditMath.EPS:
				span = c.duration * maxf(absf(c.static_speed()), MIN_SPEED)
			var mag: float = clampf(absf(speed), MIN_SPEED, MAX_SPEED)
			if fit_length > EditMath.EPS:
				mag = clampf(span / fit_length, MIN_SPEED, MAX_SPEED)
			var want: float = maxf(span / mag, frame)
			if mode == "hold_length":
				want = c.duration
			elif mode == "stop_at_next":
				want = minf(want, maxf(_room_to_next(s, c), frame))
			elif mode == "trim_next":
				want = minf(want, maxf(_room_through_next(s, c, frame), frame))
			rows.append({"clip": c, "want": want, "delta": want - c.duration, "signed": mag if speed >= 0.0 else -mag})
		var moves: Array[Dictionary] = []
		if mode == "ripple":
			moves = _ripple_moves(s, rows)
		for row: Dictionary in rows:
			var c: Clip = row["clip"]
			var want: float = float(row["want"])
			var signed: float = float(row["signed"])
			if touch_pitch:
				var audio: Dictionary = c.audio.duplicate(true)
				audio["keep_pitch"] = keep_pitch
				if audio != c.audio:
					apply(doc, ClipCmds.SetClipField.new(seq_id, c.id, "audio", audio))
			if not is_equal_approx(float(c.speed.get("v", 1.0)), signed) or AnimProp.is_animated(c.speed):
				apply(doc, ClipCmds.SetClipParam.new(seq_id, c.id, "speed", AnimProp.make(signed)))
			if absf(want - c.duration) > EditMath.EPS:
				apply(doc, EditCmds.SetTiming.new(seq_id, c.id, c.start, want, c.in_offset, 0.0))
		if mode == "trim_next":
			for row2: Dictionary in rows:
				var c2: Clip = row2["clip"]
				if float(row2["delta"]) < -EditMath.EPS:
					_give_back(doc, s, c2)
				else:
					_take_from(doc, s, c2)
		elif not moves.is_empty():
			apply(doc, ClipCmds.MoveClips.new(seq_id, moves))
		return not steps.is_empty()

	func _ripple_moves(s: Sequence, rows: Array[Dictionary]) -> Array[Dictionary]:
		var wants: Dictionary = {}
		var tracks: Array[Track] = []
		for row: Dictionary in rows:
			var c: Clip = row["clip"]
			if absf(float(row["delta"])) <= EditMath.EPS:
				continue
			wants[c.id] = float(row["want"])
			var tr: Track = s.track_of(c.id)
			if tr != null and not tracks.has(tr):
				tracks.append(tr)
		var moves: Array[Dictionary] = []
		for t: Track in tracks:
			moves.append_array(EditMath.resize_ripple_moves(t, wants))
		return moves


class RateStretch extends "res://doc/commands/composite.gd":
	const EditCmds := preload("res://doc/commands/edit_cmds.gd")
	const MIN_SPEED := 0.01
	const MAX_SPEED := 100.0

	var clip_ids: PackedStringArray = PackedStringArray()
	var side: String = "tail"
	var new_t: float = 0.0

	func _init(p_seq_id: String, p_clip_ids: PackedStringArray, p_side: String, p_new_t: float) -> void:
		label = "Rate stretch"
		seq_id = p_seq_id
		clip_ids = p_clip_ids.duplicate()
		side = p_side
		new_t = p_new_t

	func live_key() -> String:
		return "rate|" + side + "|" + ",".join(clip_ids)

	func _family(s: Sequence) -> Array[Clip]:
		var out: Array[Clip] = []
		var seen: PackedStringArray = PackedStringArray()
		for id: String in clip_ids:
			var c: Clip = s.clip_by_id(id)
			if c == null:
				continue
			for f: Clip in s.linked(c):
				var tr: Track = s.track_of(f.id)
				if tr == null or tr.locked or seen.has(f.id):
					continue
				seen.append(f.id)
				out.append(f)
		return out

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var family: Array[Clip] = _family(s)
		if family.is_empty():
			return false
		var frame: float = 1.0 / maxf(s.fps, 1.0)
		var want: float = new_t
		for c: Clip in family:
			var tr: Track = s.track_of(c.id)
			if tr == null:
				continue
			if side == "tail":
				var nxt: Clip = tr.next_clip(c)
				if nxt != null:
					want = minf(want, nxt.start)
				want = maxf(want, c.start + frame)
			else:
				var prv: Clip = tr.prev_clip(c)
				if prv != null:
					want = maxf(want, prv.end())
				want = minf(want, c.end() - frame)
		for c2: Clip in family:
			var span: float = c2.source_span()
			if span <= EditMath.EPS:
				span = c2.duration * maxf(absf(c2.static_speed()), MIN_SPEED)
			var was: float = float(c2.speed.get("v", 1.0))
			var start: float = c2.start
			var dur: float = c2.duration
			if side == "tail":
				dur = want - c2.start
			else:
				start = want
				dur = c2.end() - want
			if dur <= EditMath.EPS:
				continue
			var mag: float = clampf(span / dur, MIN_SPEED, MAX_SPEED)
			var signed: float = -mag if was < 0.0 else mag
			if absf(signed - was) > 0.00001 or AnimProp.is_animated(c2.speed):
				apply(doc, ClipCmds.SetClipParam.new(seq_id, c2.id, "speed", AnimProp.make(signed)))
			if absf(start - c2.start) > EditMath.EPS or absf(dur - c2.duration) > EditMath.EPS:
				apply(doc, EditCmds.SetTiming.new(seq_id, c2.id, start, dur, c2.in_offset, 0.0))
		return not steps.is_empty()

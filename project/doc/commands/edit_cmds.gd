extends RefCounted

const VERSION := 1
const CutLinks := preload("res://doc/cut_links.gd")
const FreeRide := preload("res://doc/commands/free_ride_cmds.gd")


class SetTiming extends "res://doc/commands/command.gd":
	var clip_id: String = ""
	var new_start: float = 0.0
	var new_duration: float = 0.0
	var new_in_offset: float = 0.0
	var key_shift: float = 0.0
	var old_start: float = 0.0
	var old_duration: float = 0.0
	var old_in_offset: float = 0.0

	func _init(p_seq_id: String, p_clip_id: String, p_start: float, p_duration: float, p_in_offset: float, p_key_shift: float = 0.0) -> void:
		label = "Timing"
		seq_id = p_seq_id
		clip_id = p_clip_id
		new_start = p_start
		new_duration = p_duration
		new_in_offset = p_in_offset
		key_shift = p_key_shift

	func live_key() -> String:
		return "timing|" + clip_id

	func _write(doc: Project, s0: float, d0: float, i0: float, shift: float) -> void:
		var s: Sequence = seq(doc)
		var c: Clip = s.clip_by_id(clip_id)
		var old_start: float = c.start
		c.start = s0
		c.duration = d0
		c.in_offset = i0
		if shift != 0.0:
			c.shift_keys(shift)
		if old_start != s0:
			s.resort_clip(s.track_of(clip_id), c, old_start)
		else:
			s.invalidate_edits()
		doc.touch("structure")

	func do(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		if c == null:
			ok = false
			return
		old_start = c.start
		old_duration = c.duration
		old_in_offset = c.in_offset
		_write(doc, new_start, new_duration, new_in_offset, key_shift)

	func undo(doc: Project) -> void:
		_write(doc, old_start, old_duration, old_in_offset, -key_shift)


class TrimClip extends "res://doc/commands/composite.gd":
	var clip_ids: PackedStringArray = PackedStringArray()
	var side: String = "head"
	var new_t: float = 0.0
	var applied_delta: float = 0.0

	func _init(p_seq_id: String, p_clip_ids: PackedStringArray, p_side: String, p_new_t: float) -> void:
		label = "Trim head" if p_side == "head" else "Trim tail"
		seq_id = p_seq_id
		clip_ids = p_clip_ids
		side = p_side
		new_t = p_new_t

	func live_key() -> String:
		return "trim|" + side + "|" + ",".join(clip_ids)

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var bounds: Vector2 = Vector2(-INF, INF)
		var clips: Array[Clip] = []
		var wanted: float = 0.0
		for id: String in clip_ids:
			var c: Clip = s.clip_by_id(id)
			if c == null:
				continue
			clips.append(c)
			if side == "head":
				bounds = EditMath.intersect(bounds, EditMath.head_delta_range(doc, s, c, true))
				wanted = new_t - c.start
			else:
				bounds = EditMath.intersect(bounds, EditMath.tail_delta_range(doc, s, c, true))
				wanted = new_t - c.end()
		if clips.is_empty():
			return false
		applied_delta = EditMath.clamp_delta(wanted, bounds)
		if absf(applied_delta) < EditMath.EPS:
			return false
		for c: Clip in clips:
			if side == "head":
				var speed: float = EditMath.static_speed(c)
				var new_in: float = c.source_time(c.start + applied_delta) if speed == 0.0 else c.in_offset + applied_delta * speed
				apply(doc, SetTiming.new(seq_id, c.id, c.start + applied_delta, c.duration - applied_delta, new_in, -applied_delta))
			else:
				apply(doc, SetTiming.new(seq_id, c.id, c.start, c.duration + applied_delta, c.in_offset, 0.0))
		return true


class RippleTrim extends "res://doc/commands/composite.gd":
	var clip_ids: PackedStringArray = PackedStringArray()
	var side: String = "head"
	var new_t: float = 0.0
	var applied_delta: float = 0.0

	func _init(p_seq_id: String, p_clip_ids: PackedStringArray, p_side: String, p_new_t: float) -> void:
		label = "Ripple trim head" if p_side == "head" else "Ripple trim tail"
		seq_id = p_seq_id
		clip_ids = p_clip_ids
		side = p_side
		new_t = p_new_t

	func live_key() -> String:
		return "ripple_trim|" + side + "|" + ",".join(clip_ids)

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var bounds: Vector2 = Vector2(-INF, INF)
		var clips: Array[Clip] = []
		var seed_tracks: PackedStringArray = PackedStringArray()
		var wanted: float = 0.0
		var edge: float = 0.0
		for id: String in clip_ids:
			var c: Clip = s.clip_by_id(id)
			if c == null:
				continue
			clips.append(c)
			seed_tracks.append(s.track_of(id).id)
			if side == "head":
				bounds = EditMath.intersect(bounds, EditMath.head_delta_range(doc, s, c, false))
				wanted = new_t - c.start
				edge = c.start
			else:
				bounds = EditMath.intersect(bounds, EditMath.tail_delta_range(doc, s, c, false))
				wanted = new_t - c.end()
				edge = c.end()
		if clips.is_empty():
			return false
		var tracks: Array[Track] = EditMath.ripple_tracks(s, seed_tracks)
		var shape: Dictionary = EditMath.stack_trim_shape(s, clips, clip_ids)
		var shift_from: float = edge if shape.is_empty() else float(shape["end"])
		var plan: Dictionary = EditMath.ripple_plan(s, tracks, shift_from, clip_ids)
		var limit: float = float(plan["back"])
		var ahead: float = float(plan["ahead"])
		if not shape.is_empty():
			bounds = EditMath.intersect(bounds, EditMath.shape_trim_range(shape, side, limit, ahead))
		elif side == "head":
			bounds.y = minf(bounds.y, limit)
			bounds.x = maxf(bounds.x, -ahead)
		else:
			bounds.x = maxf(bounds.x, -limit)
			bounds.y = minf(bounds.y, ahead)
		if bool(plan["stacked"]):
			for c: Clip in clips:
				bounds = EditMath.intersect(bounds, EditMath.stack_trim_range(s, c, side, plan, clip_ids))
		applied_delta = EditMath.clamp_delta(wanted, bounds)
		if absf(applied_delta) < EditMath.EPS:
			return false
		var shift: float = -applied_delta if side == "head" else applied_delta
		if not shape.is_empty():
			shift = EditMath.shape_shift(shape, side, applied_delta)
		var moves: Array[Dictionary] = EditMath.plan_moves(plan, shift) if absf(shift) > EditMath.EPS else ([] as Array[Dictionary])
		for c: Clip in clips:
			if side == "head":
				var speed: float = EditMath.static_speed(c)
				var new_in: float = c.source_time(c.start + applied_delta) if speed == 0.0 else c.in_offset + applied_delta * speed
				apply(doc, SetTiming.new(seq_id, c.id, c.start, c.duration - applied_delta, new_in, -applied_delta))
			else:
				apply(doc, SetTiming.new(seq_id, c.id, c.start, c.duration + applied_delta, c.in_offset, 0.0))
		if not moves.is_empty():
			apply(doc, ClipCmds.MoveClips.new(seq_id, moves))
		FreeRide.ride(self, doc, seq_id, FreeRide.after(tracks, shift_from, shift, EditMath.fence_stop(s, shift_from)))
		return true


class RollEdit extends "res://doc/commands/composite.gd":
	var edit_t: float = 0.0
	var track_ids: PackedStringArray = PackedStringArray()
	var new_t: float = 0.0
	var applied_delta: float = 0.0

	func _init(p_seq_id: String, p_edit_t: float, p_track_ids: PackedStringArray, p_new_t: float) -> void:
		label = "Roll edit"
		seq_id = p_seq_id
		edit_t = p_edit_t
		track_ids = p_track_ids
		new_t = p_new_t

	func live_key() -> String:
		return "roll|" + str(edit_t) + "|" + ",".join(track_ids)

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var bounds: Vector2 = Vector2(-INF, INF)
		var pairs: Array[Array] = []
		var rolled: PackedStringArray = PackedStringArray()
		for tid: String in track_ids:
			var t: Track = s.track_by_id(tid)
			if t == null or t.locked:
				continue
			var a: Clip = null
			var b: Clip = null
			for c: Clip in t.clips:
				if absf(c.end() - edit_t) < EditMath.EPS:
					a = c
				if absf(c.start - edit_t) < EditMath.EPS:
					b = c
			if a == null and b == null:
				continue
			if a != null:
				bounds = EditMath.intersect(bounds, EditMath.tail_delta_range(doc, s, a, b == null))
			if b != null:
				bounds = EditMath.intersect(bounds, EditMath.head_delta_range(doc, s, b, a == null))
			pairs.append([a, b])
			rolled.append(tid)
		if pairs.is_empty():
			return false
		applied_delta = EditMath.clamp_delta(new_t - edit_t, bounds)
		if absf(applied_delta) < EditMath.EPS:
			return false
		for pair: Array in pairs:
			var a: Clip = pair[0]
			var b: Clip = pair[1]
			if b != null:
				var speed: float = EditMath.static_speed(b)
				var new_in: float = b.source_time(b.start + applied_delta) if speed == 0.0 else b.in_offset + applied_delta * speed
				apply(doc, SetTiming.new(seq_id, b.id, b.start + applied_delta, b.duration - applied_delta, new_in, -applied_delta))
			if a != null:
				apply(doc, SetTiming.new(seq_id, a.id, a.start, a.duration + applied_delta, a.in_offset, 0.0))
		FreeRide.ride(self, doc, seq_id, FreeRide.across(s, rolled, edit_t, applied_delta))
		return true


class SlipClip extends "res://doc/commands/composite.gd":
	var clip_ids: PackedStringArray = PackedStringArray()
	var delta: float = 0.0
	var applied_delta: float = 0.0

	func _init(p_seq_id: String, p_clip_ids: PackedStringArray, p_delta: float) -> void:
		label = "Slip"
		seq_id = p_seq_id
		clip_ids = p_clip_ids
		delta = p_delta

	func live_key() -> String:
		return "slip|" + ",".join(clip_ids)

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var bounds: Vector2 = Vector2(-INF, INF)
		var clips: Array[Clip] = []
		for id: String in clip_ids:
			var c: Clip = s.clip_by_id(id)
			if c == null:
				continue
			clips.append(c)
			bounds = EditMath.intersect(bounds, EditMath.slip_delta_range(doc, c))
		if clips.is_empty():
			return false
		applied_delta = EditMath.clamp_delta(delta, bounds)
		if absf(applied_delta) < EditMath.EPS:
			return false
		for c: Clip in clips:
			var speed: float = EditMath.static_speed(c)
			if speed == 0.0:
				speed = 1.0
			apply(doc, SetTiming.new(seq_id, c.id, c.start, c.duration, c.in_offset + applied_delta * speed, 0.0))
		return true


class SlideClip extends "res://doc/commands/composite.gd":
	var clip_ids: PackedStringArray = PackedStringArray()
	var delta: float = 0.0
	var applied_delta: float = 0.0

	func _init(p_seq_id: String, p_clip_ids: PackedStringArray, p_delta: float) -> void:
		label = "Slide"
		seq_id = p_seq_id
		clip_ids = p_clip_ids
		delta = p_delta

	func live_key() -> String:
		return "slide|" + ",".join(clip_ids)

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var bounds: Vector2 = Vector2(-INF, INF)
		var rows: Array[Array] = []
		for id: String in clip_ids:
			var c: Clip = s.clip_by_id(id)
			if c == null:
				continue
			var t: Track = s.track_of(id)
			var prev: Clip = t.prev_clip(c)
			var next: Clip = t.next_clip(c)
			if prev != null and clip_ids.has(prev.id):
				prev = null
			if next != null and clip_ids.has(next.id):
				next = null
			var prev_adjacent: bool = prev != null and absf(prev.end() - c.start) < EditMath.EPS
			var next_adjacent: bool = next != null and absf(next.start - c.end()) < EditMath.EPS
			bounds = EditMath.intersect(bounds, Vector2(-c.start, INF))
			if prev_adjacent:
				bounds = EditMath.intersect(bounds, EditMath.tail_delta_range(doc, s, prev, false))
			elif prev != null:
				bounds = EditMath.intersect(bounds, Vector2(prev.end() - c.start, INF))
			if next_adjacent:
				bounds = EditMath.intersect(bounds, EditMath.head_delta_range(doc, s, next, false))
			elif next != null:
				bounds = EditMath.intersect(bounds, Vector2(-INF, next.start - c.end()))
			rows.append([c, prev if prev_adjacent else null, next if next_adjacent else null, t])
		if rows.is_empty():
			return false
		applied_delta = EditMath.clamp_delta(delta, bounds)
		if absf(applied_delta) < EditMath.EPS:
			return false
		var moves: Array[Dictionary] = []
		for row: Array in rows:
			var c: Clip = row[0]
			var prev: Clip = row[1]
			var next: Clip = row[2]
			var t: Track = row[3]
			if next != null:
				var speed: float = EditMath.static_speed(next)
				var new_in: float = next.source_time(next.start + applied_delta) if speed == 0.0 else next.in_offset + applied_delta * speed
				apply(doc, SetTiming.new(seq_id, next.id, next.start + applied_delta, next.duration - applied_delta, new_in, -applied_delta))
			if prev != null:
				apply(doc, SetTiming.new(seq_id, prev.id, prev.start, prev.duration + applied_delta, prev.in_offset, 0.0))
			moves.append({"id": c.id, "start": c.start + applied_delta, "track_id": t.id})
		apply(doc, ClipCmds.MoveClips.new(seq_id, moves))
		return true


class SplitClips extends "res://doc/commands/composite.gd":
	var clip_ids: PackedStringArray = PackedStringArray()
	var t: float = 0.0
	var expand_links: bool = true
	var right_ids: PackedStringArray = PackedStringArray()

	func _init(p_seq_id: String, p_clip_ids: PackedStringArray, p_t: float, p_expand_links: bool = true) -> void:
		label = "Split"
		seq_id = p_seq_id
		clip_ids = p_clip_ids
		t = p_t
		expand_links = p_expand_links

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var ids: PackedStringArray = PackedStringArray()
		for id: String in clip_ids:
			var c: Clip = s.clip_by_id(id)
			if c == null:
				continue
			var family: Array[Clip] = []
			if expand_links:
				family = s.linked(c)
			else:
				family.append(c)
			for f: Clip in family:
				if not ids.has(f.id):
					ids.append(f.id)
		var targets: Array[Clip] = []
		for id: String in ids:
			var c: Clip = s.clip_by_id(id)
			if t > c.start + EditMath.EPS and t < c.end() - EditMath.EPS:
				targets.append(c)
		if targets.is_empty():
			return false
		var new_links: Dictionary = {}
		var relink: Dictionary = {}
		var placed: Array[Array] = []
		var cut: Dictionary = {}
		for c: Clip in targets:
			cut[c.id] = true
		right_ids = PackedStringArray()
		for c: Clip in targets:
			var right_id: String = doc.mint_id("c")
			right_ids.append(right_id)
			var parts: Array[Dictionary] = EditMath.split_dicts(c, t, right_id)
			var right: Dictionary = parts[1]
			var link: String = str(right.get("link_id", ""))
			var crossed: bool = CutLinks.still_crossed(s, c, cut, t)
			if not link.is_empty() and (not crossed or not _stays_with_picture(s, c, cut)):
				if not new_links.has(link):
					new_links[link] = doc.mint_id("l")
					if not crossed:
						relink[new_links[link]] = CutLinks.later_members(s, c, cut, t)
				right["link_id"] = new_links[link]
			var tr: Track = s.track_of(c.id)
			placed.append([tr.id, parts[0], right])
		for row: Array in placed:
			var left: Dictionary = row[1]
			apply(doc, ClipCmds.ReplaceClip.new(seq_id, str(left["id"]), left))
			apply(doc, ClipCmds.PlaceClip.new(seq_id, str(row[0]), row[2]))
		for fresh: Variant in relink.keys():
			if not (relink[fresh] as PackedStringArray).is_empty():
				apply(doc, ClipCmds.Link.new(seq_id, relink[fresh], String(fresh)))
		load("res://doc/group_tree.gd").call("slice_after_cut", self, doc, s, PackedStringArray(cut.keys()), t)
		return true

	func _stays_with_picture(s: Sequence, c: Clip, cut: Dictionary) -> bool:
		var tr: Track = s.track_of(c.id)
		if tr == null:
			return false
		var sound: bool = tr.is_sound(c)
		var picture: bool = tr.is_picture(c) and _views_sound(c)
		for p: Clip in s.linked(c):
			if p == c or cut.has(p.id) or p.end() <= t + EditMath.EPS or p.start >= c.end() - EditMath.EPS:
				continue
			var pt: Track = s.track_of(p.id)
			if pt != null and ((sound and pt.is_picture(p)) or (picture and pt.is_sound(p))):
				return true
		return false

	func _views_sound(c: Clip) -> bool:
		for e: Dictionary in c.effects:
			if String(e.get("id", "")) != "pair_view" or not bool(e.get("enabled", true)):
				continue
			var raw: Variant = (e.get("params", {}) as Dictionary).get("view_audio", null)
			if raw is Dictionary and not String((raw as Dictionary).get("v", (raw as Dictionary).get("base", ""))).strip_edges().is_empty():
				return true
		return false


class RippleRemove extends "res://doc/commands/composite.gd":
	var clip_ids: PackedStringArray = PackedStringArray()

	func _init(p_seq_id: String, p_clip_ids: PackedStringArray) -> void:
		label = "Ripple delete"
		seq_id = p_seq_id
		clip_ids = p_clip_ids

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var ranges: Array[Array] = []
		var found: bool = false
		var stacked: Dictionary = {}
		for id: String in clip_ids:
			var c: Clip = s.clip_by_id(id)
			if c == null:
				continue
			found = true
			var ct: Track = s.track_of(id)
			if ct.has_stack():
				stacked[ct] = true
				continue
			ranges.append([c.start, c.end(), PackedStringArray([ct.id])])
		if not found:
			return false
		ranges.append_array(_stack_holes(stacked))
		ranges.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var merged: Array[Array] = []
		for r: Array in ranges:
			if not merged.is_empty() and float(r[0]) <= float(merged[merged.size() - 1][1]) + EditMath.EPS:
				var last: Array = merged[merged.size() - 1]
				last[1] = maxf(float(last[1]), float(r[1]))
				var seeds: PackedStringArray = last[2]
				for tid: String in (r[2] as PackedStringArray):
					if not seeds.has(tid):
						seeds.append(tid)
				last[2] = seeds
			else:
				merged.append([float(r[0]), float(r[1]), r[2]])
		apply(doc, ClipCmds.RemoveClips.new(seq_id, clip_ids))
		for i: int in range(merged.size() - 1, -1, -1):
			var a: float = merged[i][0]
			var b: float = merged[i][1]
			var tracks: Array[Track] = EditMath.ripple_tracks(s, merged[i][2])
			var plan: Dictionary = EditMath.ripple_plan(s, tracks, b, PackedStringArray())
			var d: float = minf(b - a, float(plan["back"]))
			if d <= EditMath.EPS:
				continue
			var moves: Array[Dictionary] = EditMath.plan_moves(plan, -d)
			if not moves.is_empty():
				apply(doc, ClipCmds.MoveClips.new(seq_id, moves))
			FreeRide.ride(self, doc, seq_id, FreeRide.after(tracks, b, -d, EditMath.fence_stop(s, b)))
		return true

	func _stack_holes(stacked: Dictionary) -> Array[Array]:
		var out: Array[Array] = []
		var gone: Dictionary = {}
		for id: String in clip_ids:
			gone[id] = true
		for key: Variant in stacked.keys():
			var t: Track = key
			for hole: PackedFloat64Array in EditMath.lost_cover(t, gone):
				out.append([hole[0], hole[1], PackedStringArray([t.id])])
		return out


class LiftRange extends "res://doc/commands/composite.gd":
	var t0: float = 0.0
	var t1: float = 0.0
	var track_ids: PackedStringArray = PackedStringArray()

	func _init(p_seq_id: String, p_t0: float, p_t1: float, p_track_ids: PackedStringArray) -> void:
		label = "Lift"
		seq_id = p_seq_id
		t0 = minf(p_t0, p_t1)
		t1 = maxf(p_t0, p_t1)
		track_ids = p_track_ids

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null or t1 - t0 <= EditMath.EPS:
			return false
		var tracks: Array[Track] = []
		for tid: String in track_ids:
			var t: Track = s.track_by_id(tid)
			if t != null and not t.locked and not tracks.has(t):
				tracks.append(t)
		var ids: PackedStringArray = _ids_overlapping(s, tracks)
		if ids.is_empty():
			return false
		apply(doc, SplitClips.new(seq_id, ids, t0, false))
		apply(doc, SplitClips.new(seq_id, _ids_overlapping(s, tracks), t1, false))
		var inside: PackedStringArray = PackedStringArray()
		for id: String in _ids_overlapping(s, tracks):
			var c: Clip = s.clip_by_id(id)
			if c.start >= t0 - EditMath.EPS and c.end() <= t1 + EditMath.EPS:
				inside.append(c.id)
		if inside.is_empty():
			return false
		apply(doc, ClipCmds.RemoveClips.new(seq_id, inside))
		return true

	func _ids_overlapping(s: Sequence, tracks: Array[Track]) -> PackedStringArray:
		var ids: PackedStringArray = PackedStringArray()
		for t: Track in tracks:
			for c: Clip in s.clips_overlapping(t, t0, t1):
				ids.append(c.id)
		return ids


class ExtractRange extends "res://doc/commands/composite.gd":
	var t0: float = 0.0
	var t1: float = 0.0
	var track_ids: PackedStringArray = PackedStringArray()

	func _init(p_seq_id: String, p_t0: float, p_t1: float, p_track_ids: PackedStringArray) -> void:
		label = "Extract"
		seq_id = p_seq_id
		t0 = minf(p_t0, p_t1)
		t1 = maxf(p_t0, p_t1)
		track_ids = p_track_ids

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null or t1 - t0 <= EditMath.EPS:
			return false
		apply(doc, LiftRange.new(seq_id, t0, t1, track_ids))
		var tracks: Array[Track] = EditMath.ripple_tracks(s, track_ids)
		var plan: Dictionary = EditMath.ripple_plan(s, tracks, t1, PackedStringArray())
		var d: float = minf(t1 - t0, float(plan["back"]))
		if d > EditMath.EPS:
			var moves: Array[Dictionary] = EditMath.plan_moves(plan, -d)
			if not moves.is_empty():
				apply(doc, ClipCmds.MoveClips.new(seq_id, moves))
			FreeRide.ride(self, doc, seq_id, FreeRide.after(tracks, t1, -d, EditMath.fence_stop(s, t1)))
		return not steps.is_empty()


class InsertGap extends "res://doc/commands/composite.gd":
	var t: float = 0.0
	var gap: float = 0.0
	var track_ids: PackedStringArray = PackedStringArray()
	## Set when a locked region left too little room to push the clips after `t` along (doc/fences.gd).
	var blocked_by_fence: bool = false

	func _init(p_seq_id: String, p_t: float, p_gap: float, p_track_ids: PackedStringArray) -> void:
		label = "Insert gap"
		seq_id = p_seq_id
		t = p_t
		gap = p_gap
		track_ids = p_track_ids

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null or gap <= EditMath.EPS:
			return false
		var tracks: Array[Track] = EditMath.ripple_tracks(s, track_ids)
		var stop: float = EditMath.fence_stop(s, t)
		if stop < INF:
			var room: float = EditMath.fence_ahead(s, tracks, t, PackedStringArray())
			for ftr: Track in tracks:
				for fc: Clip in ftr.clips_at(t):
					if t > fc.start + EditMath.EPS:
						room = minf(room, stop - fc.end())
			if room < gap - EditMath.EPS:
				blocked_by_fence = true
				return false
		var spanning: PackedStringArray = PackedStringArray()
		for tr: Track in tracks:
			for c: Clip in tr.clips_at(t):
				if t > c.start + EditMath.EPS:
					spanning.append(c.id)
		if not spanning.is_empty():
			apply(doc, SplitClips.new(seq_id, spanning, t, false))
		var moves: Array[Dictionary] = EditMath.plan_moves(EditMath.ripple_plan(s, tracks, t, PackedStringArray()), gap)
		if not moves.is_empty():
			apply(doc, ClipCmds.MoveClips.new(seq_id, moves))
		FreeRide.ride(self, doc, seq_id, FreeRide.after(tracks, t, gap, EditMath.fence_stop(s, t)))
		return true


class CloseGap extends "res://doc/commands/composite.gd":
	var track_id: String = ""
	var t: float = 0.0

	func _init(p_seq_id: String, p_track_id: String, p_t: float) -> void:
		label = "Close gap"
		seq_id = p_seq_id
		track_id = p_track_id
		t = p_t

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		var tr: Track = track(doc, track_id)
		if s == null or tr == null or tr.clip_at(t) != null:
			return false
		var gap_start: float = 0.0
		var gap_end: float = -1.0
		for c: Clip in tr.clips:
			if c.end() <= t + EditMath.EPS:
				gap_start = maxf(gap_start, c.end())
			elif c.start >= t - EditMath.EPS:
				gap_end = c.start
				break
		if gap_end < 0.0 or gap_end - gap_start <= EditMath.EPS:
			return false
		var tracks: Array[Track] = EditMath.ripple_tracks(s, PackedStringArray([track_id]))
		var plan: Dictionary = EditMath.ripple_plan(s, tracks, gap_end, PackedStringArray())
		var d: float = minf(gap_end - gap_start, float(plan["back"]))
		if d <= EditMath.EPS:
			return false
		apply(doc, ClipCmds.MoveClips.new(seq_id, EditMath.plan_moves(plan, -d)))
		FreeRide.ride(self, doc, seq_id, FreeRide.after(tracks, gap_end, -d, EditMath.fence_stop(s, gap_end)))
		return true


class PasteClips extends "res://doc/commands/composite.gd":
	var clipboard: Dictionary = {}
	var t: float = 0.0
	var pasted_ids: PackedStringArray = PackedStringArray()
	var _prepared: Array[Dictionary] = []

	func _init(p_seq_id: String, p_clipboard: Dictionary, p_t: float) -> void:
		label = "Paste"
		seq_id = p_seq_id
		clipboard = p_clipboard.duplicate(true)
		t = p_t

	func prepare(doc: Project, s: Sequence) -> Array[Dictionary]:
		if not _prepared.is_empty():
			return _prepared
		var raw: Array[Dictionary] = []
		var rows: Array = clipboard.get("clips", [])
		for r: Variant in rows:
			var rd: Dictionary = r
			raw.append(rd.get("clip", {}))
		var remapped: Array[Dictionary] = EditMath.remap_ids(raw, doc)
		_maps = EditMath.id_maps(raw, remapped)
		for i: int in rows.size():
			var rd: Dictionary = rows[i]
			var tr: Track = EditMath.resolve_track(s, str(rd.get("track_id", "")), str(rd.get("kind", "video")), int(rd.get("track_index", 0)))
			if tr == null or tr.locked:
				continue
			var d: Dictionary = remapped[i]
			d["start"] = t + float(rd.get("offset", 0.0))
			_prepared.append({"track_id": tr.id, "clip": d})
		return _prepared

	var _maps: Dictionary = {}

	func group_records(doc: Project, s: Sequence) -> Dictionary:
		var out: Dictionary = {}
		var carried: Variant = clipboard.get("groups", {})
		if carried is Dictionary:
			out = (carried as Dictionary).duplicate(true)
		var source: Sequence = doc.sequence_by_id(str(clipboard.get("seq_id", "")))
		for from_seq: Sequence in [source, s]:
			if from_seq == null:
				continue
			for g: Dictionary in from_seq.groups:
				var gid: String = String(g.get("id", ""))
				if not out.has(gid):
					out[gid] = g.duplicate(true)
		return out

	func new_groups(doc: Project, s: Sequence) -> Array[Dictionary]:
		var used: PackedStringArray = PackedStringArray()
		for row: Dictionary in _prepared:
			var gid: String = str((row["clip"] as Dictionary).get("group_id", ""))
			if not gid.is_empty() and not used.has(gid):
				used.append(gid)
		if used.is_empty():
			return []
		return EditMath.copied_groups(s, group_records(doc, s), _maps, used)

	func add_groups(doc: Project, s: Sequence, owner: Command) -> void:
		for g: Dictionary in new_groups(doc, s):
			var cmd: Command = EditMath.add_group_command(owner.seq_id, g) as Command
			owner.call("apply", doc, cmd)

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var rows: Array[Dictionary] = prepare(doc, s)
		if rows.is_empty():
			return false
		add_groups(doc, s, self)
		pasted_ids = PackedStringArray()
		for row: Dictionary in rows:
			var d: Dictionary = row["clip"]
			var c0: float = float(d["start"])
			var c1: float = c0 + float(d.get("duration", 0.0))
			apply(doc, LiftRange.new(seq_id, c0, c1, PackedStringArray([str(row["track_id"])])))
		for row: Dictionary in rows:
			apply(doc, ClipCmds.PlaceClip.new(seq_id, str(row["track_id"]), row["clip"]))
			pasted_ids.append(str((row["clip"] as Dictionary)["id"]))
		return true


class PasteInsert extends "res://doc/commands/composite.gd":
	var clipboard: Dictionary = {}
	var t: float = 0.0
	var pasted_ids: PackedStringArray = PackedStringArray()

	func _init(p_seq_id: String, p_clipboard: Dictionary, p_t: float) -> void:
		label = "Paste insert"
		seq_id = p_seq_id
		clipboard = p_clipboard.duplicate(true)
		t = p_t

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var paste: PasteClips = PasteClips.new(seq_id, clipboard, t)
		var rows: Array[Dictionary] = paste.prepare(doc, s)
		if rows.is_empty():
			return false
		var span: float = float(clipboard.get("span", 0.0))
		var seeds: PackedStringArray = PackedStringArray()
		for row: Dictionary in rows:
			if not seeds.has(str(row["track_id"])):
				seeds.append(str(row["track_id"]))
		if span > EditMath.EPS:
			apply(doc, InsertGap.new(seq_id, t, span, seeds))
		apply(doc, paste)
		pasted_ids = paste.pasted_ids
		return paste.ok


class PasteAttributes extends "res://doc/commands/command.gd":
	const FIELDS := ["transform", "motion_blur", "effects", "masks", "audio", "speed", "nest", "colour", "enabled", "tags", "props"]
	var clip_ids: PackedStringArray = PackedStringArray()
	var source: Dictionary = {}
	var which: PackedStringArray = PackedStringArray()
	var old: Dictionary = {}
	var _uids: Dictionary = {}

	func _init(p_seq_id: String, p_clip_ids: PackedStringArray, p_source_clip: Dictionary, p_which: PackedStringArray) -> void:
		label = "Paste attributes"
		seq_id = p_seq_id
		clip_ids = p_clip_ids
		source = p_source_clip.duplicate(true)
		which = p_which

	const SPEED_HEADS: Dictionary = {"transform": ["motion", "transform."], "motion_blur": ["motion", "motion_blur."], "audio": ["audio", "audio."], "props": ["props", "props."]}

	func _carry_speeds(c: Clip, saved: Dictionary) -> void:
		var heads: PackedStringArray = PackedStringArray()
		for f: String in which:
			if SPEED_HEADS.has(f):
				for h: Variant in (SPEED_HEADS[f] as Array):
					heads.append(String(h))
		if heads.is_empty():
			return
		var src: Clip = Clip.from_dict(source)
		saved["speeds"] = dup(c.speeds)
		var kept: Dictionary = {}
		for t: Variant in c.speeds.keys():
			if not _under(String(t), heads):
				kept[t] = dup(c.speeds[t])
		for t2: Variant in src.speeds.keys():
			if _under(String(t2), heads):
				kept[t2] = dup(src.speeds[t2])
		c.speeds = kept

	static func _under(t: String, heads: PackedStringArray) -> bool:
		for h: String in heads:
			if t == h or (h.ends_with(".") and t.begins_with(h)):
				return true
		return false

	func _value_for(doc: Project, clip_id: String, field: String) -> Variant:
		var c: Clip = Clip.from_dict(source)
		var v: Variant = c.get(field)
		if field == "effects":
			var out: Array[Dictionary] = []
			var key: String = clip_id + "|effects"
			if not _uids.has(key):
				var minted: Array = []
				for _e: Dictionary in c.effects:
					minted.append(doc.mint_id("e"))
				_uids[key] = minted
			var minted_uids: Array = _uids[key]
			for i: int in c.effects.size():
				var e: Dictionary = c.effects[i].duplicate(true)
				e["uid"] = minted_uids[i]
				out.append(e)
			return out
		return dup(v)

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null:
			ok = false
			return
		old = {}
		var any: bool = false
		for id: String in clip_ids:
			var c: Clip = s.clip_by_id(id)
			if c == null:
				continue
			var saved: Dictionary = {}
			for f: String in which:
				if not FIELDS.has(f):
					continue
				saved[f] = dup(c.get(f))
				c.set(f, _value_for(doc, id, f))
				any = true
			_carry_speeds(c, saved)
			old[id] = saved
		if not any:
			ok = false
			return
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		for id: String in old.keys():
			var c: Clip = s.clip_by_id(id)
			if c == null:
				continue
			var saved: Dictionary = old[id]
			for f: String in saved.keys():
				c.set(f, dup(saved[f]))
		doc.touch("meta")


class NestClips extends "res://doc/commands/composite.gd":
	var clip_ids: PackedStringArray = PackedStringArray()
	var nest_label: String = ""
	var new_seq_id: String = ""
	var nest_clip_ids: PackedStringArray = PackedStringArray()

	func _init(p_seq_id: String, p_clip_ids: PackedStringArray, p_label: String) -> void:
		label = "Nest"
		seq_id = p_seq_id
		clip_ids = p_clip_ids
		nest_label = p_label

	func _group_records(s: Sequence, clips: Array[Clip]) -> Array:
		var out: Array = []
		var seen: Dictionary = {}
		for c: Clip in clips:
			if c.group_id.is_empty() or seen.has(c.group_id):
				continue
			seen[c.group_id] = true
			var g: Dictionary = s.group_by_id(c.group_id)
			if not g.is_empty():
				out.append(g.duplicate(true))
		return out

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var clips: Array[Clip] = []
		var t0: float = INF
		var t1: float = -INF
		var used_video: Array[int] = []
		var used_audio: Array[int] = []
		for id: String in clip_ids:
			var c: Clip = s.clip_by_id(id)
			if c == null:
				continue
			clips.append(c)
			t0 = minf(t0, c.start)
			t1 = maxf(t1, c.end())
			var tr: Track = s.track_of(id)
			var idx: int = s.track_index(tr.id)
			if tr.kind == "video":
				if not used_video.has(idx):
					used_video.append(idx)
			elif not used_audio.has(idx):
				used_audio.append(idx)
		if clips.is_empty():
			return false
		used_video.sort()
		used_audio.sort()
		new_seq_id = doc.mint_id("s")
		var seq_dict: Dictionary = {"id": new_seq_id, "label": nest_label, "fps": s.fps, "width": s.width, "height": s.height, "sample_rate": s.sample_rate}
		var vt: Array = []
		var at: Array = []
		var track_map: Dictionary = {}
		for i: int in used_video.size():
			var src: Track = s.video_tracks[used_video[i]]
			var td: Dictionary = src.header_dict()
			td["id"] = doc.mint_id("t")
			td["label"] = "V" + str(i + 1)
			td["clips"] = []
			track_map[src.id] = td
			vt.append(td)
		for i: int in used_audio.size():
			var src: Track = s.audio_tracks[used_audio[i]]
			var td: Dictionary = src.header_dict()
			td["id"] = doc.mint_id("t")
			td["label"] = "A" + str(i + 1)
			td["clips"] = []
			track_map[src.id] = td
			at.append(td)
		for c: Clip in clips:
			var d: Dictionary = c.to_dict()
			d["start"] = c.start - t0
			var tr: Track = s.track_of(c.id)
			(track_map[tr.id]["clips"] as Array).append(d)
		seq_dict["video_tracks"] = vt
		seq_dict["audio_tracks"] = at
		var carried: Array = _group_records(s, clips)
		if not carried.is_empty():
			seq_dict["groups"] = carried
		var media_id: String = doc.mint_id("m")
		var media_dict: Dictionary = {"id": media_id, "kind": "sequence", "label": nest_label, "sequence_id": new_seq_id, "probed": true}
		apply(doc, ClipCmds.RemoveClips.new(seq_id, clip_ids))
		apply(doc, SequenceCmds.AddSequence.new(seq_dict, media_dict))
		var anchors: PackedStringArray = PackedStringArray()
		if not used_video.is_empty():
			anchors.append(s.video_tracks[used_video[0]].id)
		if not used_audio.is_empty():
			anchors.append(s.audio_tracks[used_audio[0]].id)
		for tid: String in anchors:
			apply(doc, LiftRange.new(seq_id, t0, t1, PackedStringArray([tid])))
		nest_clip_ids = PackedStringArray()
		var link_id: String = doc.mint_id("l") if not used_video.is_empty() and not used_audio.is_empty() else ""
		if not used_video.is_empty():
			var vid: String = doc.mint_id("c")
			var vd: Dictionary = {"id": vid, "media_id": media_id, "sequence_id": new_seq_id, "label": nest_label, "start": t0, "duration": t1 - t0, "in_offset": 0.0}
			if not link_id.is_empty():
				vd["link_id"] = link_id
			apply(doc, ClipCmds.PlaceClip.new(seq_id, s.video_tracks[used_video[0]].id, vd))
			nest_clip_ids.append(vid)
		if not used_audio.is_empty():
			var aid: String = doc.mint_id("c")
			var ad: Dictionary = {"id": aid, "media_id": media_id, "sequence_id": new_seq_id, "label": nest_label, "start": t0, "duration": t1 - t0, "in_offset": 0.0}
			if not link_id.is_empty():
				ad["link_id"] = link_id
			apply(doc, ClipCmds.PlaceClip.new(seq_id, s.audio_tracks[used_audio[0]].id, ad))
			nest_clip_ids.append(aid)
		return true


class UnnestClips extends "res://doc/commands/composite.gd":
	var clip_id: String = ""
	var placed_ids: PackedStringArray = PackedStringArray()
	var carry_groups: bool = true

	func _init(p_seq_id: String, p_clip_id: String) -> void:
		label = "Unnest"
		seq_id = p_seq_id
		clip_id = p_clip_id

	func _carry_groups(doc: Project, s: Sequence, inner: Sequence, raw: Array[Dictionary], remapped: Array[Dictionary]) -> void:
		var used: PackedStringArray = PackedStringArray()
		for d: Dictionary in remapped:
			var gid: String = str(d.get("group_id", ""))
			if not gid.is_empty() and not used.has(gid):
				used.append(gid)
		if used.is_empty():
			return
		var records: Dictionary = {}
		for g: Dictionary in inner.groups:
			records[String(g.get("id", ""))] = g
		for rec: Dictionary in EditMath.copied_groups(s, records, EditMath.id_maps(raw, remapped), used, true):
			apply(doc, EditMath.add_group_command(seq_id, rec) as Command)

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var nest: Clip = s.clip_by_id(clip_id)
		if nest == null or not nest.is_nest():
			return false
		var inner: Sequence = doc.sequence_by_id(nest.sequence_id)
		if inner == null:
			return false
		var family: Array[Clip] = s.linked(nest)
		var remove_ids: PackedStringArray = PackedStringArray()
		var video_anchor: Track = null
		var audio_anchor: Track = null
		for f: Clip in family:
			if f.sequence_id == nest.sequence_id:
				remove_ids.append(f.id)
				var tr: Track = s.track_of(f.id)
				if tr.kind == "video" and video_anchor == null:
					video_anchor = tr
				if tr.kind == "audio" and audio_anchor == null:
					audio_anchor = tr
		if video_anchor == null and not s.video_tracks.is_empty():
			video_anchor = s.video_tracks[0]
		if audio_anchor == null and not s.audio_tracks.is_empty():
			audio_anchor = s.audio_tracks[0]
		var origin: float = nest.start - nest.in_offset * EditMath.static_speed(nest)
		var raw: Array[Dictionary] = []
		var targets: Array[Dictionary] = []
		for kind: String in ["video", "audio"]:
			var inner_tracks: Array[Track] = inner.tracks_of_kind(kind)
			var anchor: Track = video_anchor if kind == "video" else audio_anchor
			if anchor == null:
				continue
			var base_index: int = s.track_index(anchor.id)
			for i: int in inner_tracks.size():
				var want: int = base_index + i
				var list: Array[Track] = s.tracks_of_kind(kind)
				while want >= list.size():
					var td: Dictionary = {"id": doc.mint_id("t"), "label": ("V" if kind == "video" else "A") + str(list.size() + 1)}
					apply(doc, TrackCmds.AddTrack.new(seq_id, kind, -1, td))
					list = s.tracks_of_kind(kind)
				var target: Track = list[want]
				for c: Clip in inner_tracks[i].clips:
					var d: Dictionary = c.to_dict()
					var start: float = origin + c.start
					var end: float = start + c.duration
					if end <= nest.start + EditMath.EPS or start >= nest.end() - EditMath.EPS:
						continue
					d["start"] = start
					if start < nest.start - EditMath.EPS:
						d = EditMath.head_trim_dict(d, nest.start - start)
					if float(d["start"]) + float(d["duration"]) > nest.end() + EditMath.EPS:
						d = EditMath.tail_trim_dict(d, nest.end() - float(d["start"]))
					raw.append(d)
					targets.append({"track_id": target.id})
		var remapped: Array[Dictionary] = EditMath.remap_ids(raw, doc)
		apply(doc, ClipCmds.RemoveClips.new(seq_id, remove_ids))
		if carry_groups:
			_carry_groups(doc, s, inner, raw, remapped)
		placed_ids = PackedStringArray()
		for i: int in remapped.size():
			var d: Dictionary = remapped[i]
			var tid: String = str(targets[i]["track_id"])
			apply(doc, LiftRange.new(seq_id, float(d["start"]), float(d["start"]) + float(d["duration"]), PackedStringArray([tid])))
			apply(doc, ClipCmds.PlaceClip.new(seq_id, tid, d))
			placed_ids.append(str(d["id"]))
		return true

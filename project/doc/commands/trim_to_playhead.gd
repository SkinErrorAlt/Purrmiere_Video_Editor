extends RefCounted

const SELF := preload("res://doc/commands/trim_to_playhead.gd")
const VIEW_TRIMS_PATH := "res://doc/view_trims.gd"
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const EditMath := preload("res://doc/commands/edit_math.gd")
const EPS := 0.00001


static func edge_of(c: Clip, side: String) -> float:
	return c.start if side == "head" else c.end()


static func crosses(c: Clip, t: float) -> bool:
	return c != null and t > c.start + EPS and t < c.end() - EPS


static func partners(s: Sequence, c: Clip, side: String, t: float) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var edge: float = edge_of(c, side)
	for f: Clip in s.linked(c):
		var tr: Track = s.track_of(f.id)
		if tr == null or tr.locked:
			continue
		if f != c and (absf(edge_of(f, side) - edge) >= EPS or not crosses(f, t)):
			continue
		out.append(f.id)
	return out


static func groups(s: Sequence, ids: PackedStringArray, side: String, t: float) -> Array[Dictionary]:
	var by_edge: Dictionary = {}
	var taken: Dictionary = {}
	for id: String in ids:
		var c: Clip = s.clip_by_id(id)
		if c == null:
			continue
		var edge: float = edge_of(c, side)
		var key: String = "%.5f" % edge
		if not by_edge.has(key):
			by_edge[key] = {"edge": edge, "ids": PackedStringArray()}
		var g: Dictionary = by_edge[key]
		var members: PackedStringArray = g["ids"]
		for f: String in partners(s, c, side, t):
			if not members.has(f) and not taken.has(f):
				members.append(f)
				taken[f] = true
		g["ids"] = members
	var out: Array[Dictionary] = []
	for v: Variant in by_edge.values():
		if not ((v as Dictionary)["ids"] as PackedStringArray).is_empty():
			out.append(v)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["edge"]) > float(b["edge"]))
	return out


static func _one_owner_per_track(s: Sequence, list: Array[Dictionary]) -> bool:
	var owner: Dictionary = {}
	for i: int in list.size():
		for id: String in (list[i]["ids"] as PackedStringArray):
			var tr: Track = s.track_of(id)
			if tr == null or tr.has_stack():
				return false
			if owner.has(tr.id) and int(owner[tr.id]) != i:
				return false
			owner[tr.id] = i
	return true


static func _on_stacks(s: Sequence, list: Array[Dictionary]) -> bool:
	for g: Dictionary in list:
		for id: String in (g["ids"] as PackedStringArray):
			var tr: Track = s.track_of(id)
			if tr != null and tr.has_stack():
				return true
	return false


static func commands(s: Sequence, ids: PackedStringArray, side: String, t: float) -> Array[Command]:
	var out: Array[Command] = []
	if s == null:
		return out
	var list: Array[Dictionary] = groups(s, ids, side, t)
	if _on_stacks(s, list):
		out.append(StackSpread.new(s.id, list, side, t))
		return out
	if list.size() > 1 and _one_owner_per_track(s, list):
		out.append(Spread.new(s.id, list, side, t))
		return out
	for g: Dictionary in list:
		out.append(EditCmds.RippleTrim.new(s.id, g["ids"], side, t))
	return out


class CutThrough extends "res://doc/commands/composite.gd":
	var clip_ids: PackedStringArray = PackedStringArray()
	var side: String = "head"
	var t: float = 0.0
	var track_ids: PackedStringArray = PackedStringArray()
	var edge: float = 0.0
	var span: float = 0.0

	func _init(p_seq_id: String, p_clip_ids: PackedStringArray, p_side: String, p_t: float, p_track_ids: PackedStringArray, p_edge: float, p_span: float) -> void:
		label = "Ripple trim head" if p_side == "head" else "Ripple trim tail"
		seq_id = p_seq_id
		clip_ids = p_clip_ids
		side = p_side
		t = p_t
		track_ids = p_track_ids
		edge = p_edge
		span = p_span

	func _inner(s: Sequence) -> Array[Command]:
		var by_lines: Command = load(SELF.VIEW_TRIMS_PATH).call("ripple", s, clip_ids, side, t)
		if by_lines != null:
			var one: Array[Command] = [by_lines]
			return one
		return SELF.commands(s, clip_ids, side, t)

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null or span <= EPS or track_ids.is_empty():
			return false
		apply(doc, EditCmds.LiftRange.new(seq_id, edge, edge + span, track_ids))
		if steps.is_empty():
			return false
		var any: bool = false
		for cmd: Command in _inner(s):
			apply(doc, cmd)
			any = any or cmd.ok
		return any


class Spread extends "res://doc/commands/composite.gd":
	var groups: Array[Dictionary] = []
	var side: String = "head"
	var t: float = 0.0

	func _init(p_seq_id: String, p_groups: Array[Dictionary], p_side: String, p_t: float) -> void:
		label = "Ripple trim head" if p_side == "head" else "Ripple trim tail"
		seq_id = p_seq_id
		groups = p_groups
		side = p_side
		t = p_t

	func _amount(doc: Project, s: Sequence, ids: PackedStringArray, edge: float) -> float:
		var want: float = t - edge if side == "head" else edge - t
		var bounds: Vector2 = Vector2(-INF, INF)
		for id: String in ids:
			var c: Clip = s.clip_by_id(id)
			if side == "head":
				bounds = EditMath.intersect(bounds, EditMath.head_delta_range(doc, s, c, false))
			else:
				bounds = EditMath.intersect(bounds, EditMath.tail_delta_range(doc, s, c, false))
		if side == "head":
			return maxf(EditMath.clamp_delta(want, bounds), 0.0)
		return maxf(-EditMath.clamp_delta(-want, bounds), 0.0)

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null or groups.is_empty():
			return false
		var trimmed: PackedStringArray = PackedStringArray()
		var owner: Dictionary = {}
		var amounts: PackedFloat64Array = PackedFloat64Array()
		var seeds: PackedStringArray = PackedStringArray()
		for i: int in groups.size():
			var ids: PackedStringArray = groups[i]["ids"]
			amounts.append(_amount(doc, s, ids, float(groups[i]["edge"])))
			for id: String in ids:
				trimmed.append(id)
				var tr: Track = s.track_of(id)
				owner[tr.id] = i
				if not seeds.has(tr.id):
					seeds.append(tr.id)
		var least: float = INF
		var near_edge: float = -INF if side == "head" else INF
		for i: int in groups.size():
			least = minf(least, amounts[i])
			var e: float = float(groups[i]["edge"])
			near_edge = maxf(near_edge, e) if side == "head" else minf(near_edge, e)
		var moves: Array[Dictionary] = []
		for tr: Track in EditMath.ripple_tracks(s, seeds):
			var from: float = near_edge
			var amount: float = least
			if owner.has(tr.id):
				var gi: int = int(owner[tr.id])
				from = float(groups[gi]["edge"])
				amount = amounts[gi]
			else:
				amount = minf(amount, EditMath.ripple_limit(s, [tr] as Array[Track], from, trimmed))
			if amount > EditMath.EPS:
				moves.append_array(EditMath.shift_moves(s, [tr] as Array[Track], from, -amount, trimmed))
		var any: bool = false
		for i: int in groups.size():
			var d: float = amounts[i]
			if d <= EditMath.EPS:
				continue
			for id: String in (groups[i]["ids"] as PackedStringArray):
				var c: Clip = s.clip_by_id(id)
				if side == "head":
					var speed: float = EditMath.static_speed(c)
					var new_in: float = c.source_time(c.start + d) if speed == 0.0 else c.in_offset + d * speed
					apply(doc, EditCmds.SetTiming.new(seq_id, c.id, c.start, c.duration - d, new_in, -d))
				else:
					apply(doc, EditCmds.SetTiming.new(seq_id, c.id, c.start, c.duration - d, c.in_offset, 0.0))
				any = true
		if not moves.is_empty():
			apply(doc, ClipCmds.MoveClips.new(seq_id, moves))
		return any


class StackSpread extends Spread:
	const GAP_EPS := 0.00001

	static func merged(spans: Array[PackedFloat64Array]) -> Array[PackedFloat64Array]:
		var sorted: Array[PackedFloat64Array] = spans.duplicate()
		sorted.sort_custom(func(a: PackedFloat64Array, b: PackedFloat64Array) -> bool: return a[0] < b[0])
		var out: Array[PackedFloat64Array] = []
		for sp: PackedFloat64Array in sorted:
			if sp[1] - sp[0] <= GAP_EPS:
				continue
			if not out.is_empty() and sp[0] <= out[out.size() - 1][1] + GAP_EPS:
				var last: PackedFloat64Array = out[out.size() - 1]
				last[1] = maxf(last[1], sp[1])
				out[out.size() - 1] = last
			else:
				out.append(PackedFloat64Array([sp[0], sp[1]]))
		return out

	static func holes(before: Array[PackedFloat64Array], after: Array[PackedFloat64Array]) -> Array[PackedFloat64Array]:
		var out: Array[PackedFloat64Array] = []
		var k: int = 0
		for seg: PackedFloat64Array in before:
			var edge: float = seg[0]
			while k < after.size() and after[k][1] <= edge + GAP_EPS:
				k += 1
			var j: int = k
			while j < after.size() and after[j][0] < seg[1] - GAP_EPS:
				if after[j][0] > edge + GAP_EPS:
					out.append(PackedFloat64Array([edge, after[j][0]]))
				edge = maxf(edge, after[j][1])
				j += 1
			if seg[1] > edge + GAP_EPS:
				out.append(PackedFloat64Array([edge, seg[1]]))
		return out

	static func closed_before(list: Array[PackedFloat64Array], at: float) -> float:
		var total: float = 0.0
		for h: PackedFloat64Array in list:
			if h[1] <= at + GAP_EPS:
				total += h[1] - h[0]
		return total

	func _kept(c: Clip, d: float) -> PackedFloat64Array:
		if d <= EditMath.EPS:
			return PackedFloat64Array([c.start, c.end()])
		if side == "head":
			return PackedFloat64Array([c.start + d, c.end()])
		return PackedFloat64Array([c.start, c.end() - d])

	func _new_in(c: Clip, d: float) -> float:
		if side != "head":
			return c.in_offset
		var speed: float = EditMath.static_speed(c)
		return c.source_time(c.start + d) if speed == 0.0 else c.in_offset + d * speed

	func _close_stack(tr: Track, cut: Dictionary, timings: Array[Array], moves: Array[Dictionary]) -> float:
		var before: Array[PackedFloat64Array] = []
		var after: Array[PackedFloat64Array] = []
		for c: Clip in tr.clips:
			before.append(PackedFloat64Array([c.start, c.end()]))
			after.append(_kept(c, float(cut.get(c.id, 0.0))))
		var gone: Array[PackedFloat64Array] = holes(merged(before), merged(after))
		for c: Clip in tr.clips:
			var d: float = float(cut.get(c.id, 0.0))
			var kept: PackedFloat64Array = _kept(c, d)
			var shift: float = closed_before(gone, kept[0])
			if cut.has(c.id):
				if d > EditMath.EPS:
					timings.append([c.id, kept[0] - shift, c.duration - d, _new_in(c, d), -d if side == "head" else 0.0])
			elif shift > EditMath.EPS:
				moves.append({"id": c.id, "start": c.start - shift, "track_id": tr.id})
		return closed_before(gone, INF)

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null or groups.is_empty():
			return false
		var cut: Dictionary = {}
		var trimmed: PackedStringArray = PackedStringArray()
		var seeds: PackedStringArray = PackedStringArray()
		var owner: Dictionary = {}
		var amounts: PackedFloat64Array = PackedFloat64Array()
		var near_edge: float = -INF if side == "head" else INF
		for i: int in groups.size():
			var ids: PackedStringArray = groups[i]["ids"]
			var e: float = float(groups[i]["edge"])
			amounts.append(_amount(doc, s, ids, e))
			near_edge = maxf(near_edge, e) if side == "head" else minf(near_edge, e)
			for id: String in ids:
				var tr: Track = s.track_of(id)
				if tr == null:
					continue
				cut[id] = amounts[i]
				trimmed.append(id)
				if not seeds.has(tr.id):
					seeds.append(tr.id)
				if not tr.has_stack():
					owner[tr.id] = i
		var timings: Array[Array] = []
		var moves: Array[Dictionary] = []
		var least: float = INF
		var rest: Array[Track] = []
		for tr: Track in EditMath.ripple_tracks(s, seeds):
			if not seeds.has(tr.id):
				rest.append(tr)
			elif tr.has_stack():
				least = minf(least, _close_stack(tr, cut, timings, moves))
			elif owner.has(tr.id):
				var gi: int = int(owner[tr.id])
				least = minf(least, amounts[gi])
				if amounts[gi] > EditMath.EPS:
					moves.append_array(EditMath.shift_moves(s, [tr] as Array[Track], float(groups[gi]["edge"]), -amounts[gi], trimmed))
				for c: Clip in tr.clips:
					if cut.has(c.id) and amounts[gi] > EditMath.EPS:
						timings.append([c.id, c.start, c.duration - amounts[gi], _new_in(c, amounts[gi]), -amounts[gi] if side == "head" else 0.0])
		if least == INF:
			least = 0.0
		for tr: Track in rest:
			var plan: Dictionary = EditMath.ripple_plan(s, [tr] as Array[Track], near_edge, trimmed)
			var amount: float = minf(least, float(plan["back"]))
			if amount > EditMath.EPS:
				moves.append_array(EditMath.plan_moves(plan, -amount))
		for row: Array in timings:
			apply(doc, EditCmds.SetTiming.new(seq_id, String(row[0]), float(row[1]), float(row[2]), float(row[3]), float(row[4])))
		if not moves.is_empty():
			apply(doc, ClipCmds.MoveClips.new(seq_id, moves))
		return not timings.is_empty()

extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const EPS := 0.00001
const AS_ONE_LABEL := "Act as one"
const FILL_LABEL := "Count the space between"
const RULE := "A link group can be set to act as one. Then the members behave like a single clip: an effect dropped on any member goes on every member in one undo step, and a move of one member moves them all, even when the members do not touch each other. Count the space between adds the gaps between members on their own tracks to the group, but only the parts of those gaps that nothing else is using. Alt click a member and then Shift drag it to move that one piece on its own. With Act as one off, a link behaves exactly as it always has: it keeps the pieces selected and cuts them together, and a dropped effect still reaches only the clips picked on purpose."


static func rule_of(seq: Sequence, link_id: String) -> Dictionary:
	if seq == null or link_id.is_empty():
		return Sequence.default_link_rule(link_id)
	return seq.link_rule(link_id)


static func is_on(seq: Sequence, link_id: String) -> bool:
	return bool(rule_of(seq, link_id).get("as_one", false))


static func fills(seq: Sequence, link_id: String) -> bool:
	var r: Dictionary = rule_of(seq, link_id)
	return bool(r.get("as_one", false)) and bool(r.get("fill", false))


static func acts_as_one(seq: Sequence, c: Clip) -> bool:
	return seq != null and c != null and not c.link_id.is_empty() and is_on(seq, c.link_id)


static func members(seq: Sequence, c: Clip) -> Array[Clip]:
	var out: Array[Clip] = []
	if not acts_as_one(seq, c):
		return out
	for m: Clip in seq.linked(c):
		out.append(m)
	return out


static func member_ids(seq: Sequence, c: Clip) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for m: Clip in members(seq, c):
		if not out.has(m.id):
			out.append(m.id)
	return out


static func widen(seq: Sequence, ids: PackedStringArray) -> PackedStringArray:
	if seq == null or ids.is_empty():
		return ids
	var out: PackedStringArray = ids.duplicate()
	for id: String in ids:
		for m: Clip in members(seq, seq.clip_by_id(id)):
			if not out.has(m.id):
				out.append(m.id)
	return out


static func extent(seq: Sequence, c: Clip) -> Vector2:
	var list: Array[Clip] = members(seq, c)
	if list.is_empty():
		return Vector2(c.start, c.end()) if c != null else Vector2.ZERO
	var lo: float = INF
	var hi: float = -INF
	for m: Clip in list:
		lo = minf(lo, m.start)
		hi = maxf(hi, m.end())
	return Vector2(lo, hi)


static func by_track(seq: Sequence, c: Clip) -> Dictionary:
	var out: Dictionary = {}
	for m: Clip in members(seq, c):
		var tr: Track = seq.track_of(m.id)
		if tr == null:
			continue
		if not out.has(tr.id):
			var none: Array[Clip] = []
			out[tr.id] = none
		(out[tr.id] as Array[Clip]).append(m)
	for key: Variant in out.keys():
		(out[key] as Array[Clip]).sort_custom(func(a: Clip, b: Clip) -> bool: return a.start < b.start)
	return out


static func unused_parts(seq: Sequence, track_id: String, from: float, to: float, link_id: String) -> Array[Vector2]:
	var out: Array[Vector2] = [Vector2(from, to)]
	var tr: Track = seq.track_by_id(track_id) if seq != null else null
	if tr == null:
		return out
	for o: Clip in tr.clips:
		if o.link_id == link_id or o.end() <= from + EPS or o.start >= to - EPS:
			continue
		var next: Array[Vector2] = []
		for sp: Vector2 in out:
			if o.end() <= sp.x + EPS or o.start >= sp.y - EPS:
				next.append(sp)
				continue
			if o.start > sp.x + EPS:
				next.append(Vector2(sp.x, o.start))
			if o.end() < sp.y - EPS:
				next.append(Vector2(o.end(), sp.y))
		out = next
	return out


static func gaps(seq: Sequence, c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null or not acts_as_one(seq, c):
		return out
	var lanes: Dictionary = by_track(seq, c)
	for key: Variant in lanes.keys():
		var track_id: String = key
		var list: Array[Clip] = lanes[key]
		if list.size() < 2:
			continue
		var reach: float = list[0].end()
		for i: int in range(1, list.size()):
			if list[i].start > reach + EPS:
				out.append({"track": track_id, "from": reach, "to": list[i].start})
			reach = maxf(reach, list[i].end())
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["from"]) < float(b["from"]))
	return out


static func fill_spans(seq: Sequence, c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null or not fills(seq, c.link_id):
		return out
	for gap: Dictionary in gaps(seq, c):
		var track_id: String = String(gap["track"])
		for part: Vector2 in unused_parts(seq, track_id, float(gap["from"]), float(gap["to"]), c.link_id):
			if part.y > part.x + EPS:
				out.append({"track": track_id, "from": part.x, "to": part.y})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["from"]) < float(b["from"]))
	return out


static func fill_seconds(seq: Sequence, c: Clip) -> float:
	var total: float = 0.0
	for sp: Dictionary in fill_spans(seq, c):
		total += float(sp["to"]) - float(sp["from"])
	return total


static func covers(seq: Sequence, c: Clip, track_id: String, t: float) -> bool:
	for m: Clip in members(seq, c):
		var tr: Track = seq.track_of(m.id)
		if tr != null and tr.id == track_id and t >= m.start - EPS and t <= m.end() + EPS:
			return true
	for sp: Dictionary in fill_spans(seq, c):
		if String(sp["track"]) == track_id and t >= float(sp["from"]) - EPS and t <= float(sp["to"]) - EPS:
			return true
	return false


static func blocks(seq: Sequence, c: Clip) -> int:
	var list: Array[Clip] = members(seq, c)
	if list.is_empty():
		return 0
	var sorted: Array[Clip] = list.duplicate()
	sorted.sort_custom(func(a: Clip, b: Clip) -> bool: return a.start < b.start)
	var n: int = 0
	var reach: float = -INF
	for m: Clip in sorted:
		if m.start >= reach - EPS:
			n += 1
			reach = m.end()
		else:
			reach = maxf(reach, m.end())
	return n


static func apart(seq: Sequence, c: Clip) -> bool:
	return blocks(seq, c) > 1


static func summary(seq: Sequence, c: Clip) -> String:
	if c == null or c.link_id.is_empty():
		return "This clip is not linked to anything, so there is nothing to act as one."
	if not acts_as_one(seq, c):
		return "This link keeps its pieces selected and cuts them together. Turn on Act as one to treat them as a single clip."
	var list: Array[Clip] = members(seq, c)
	var text: String = "%d clips act as one" % list.size()
	var n: int = blocks(seq, c)
	if n > 1:
		text += ", in %d pieces that do not touch" % n
	if fills(seq, c.link_id):
		var secs: float = fill_seconds(seq, c)
		text += ", and %s seconds of free space between them counts as part of it" % String.num(secs, 2)
	return text + "."

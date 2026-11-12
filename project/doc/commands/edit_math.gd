extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Marker := preload("res://doc/marker.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const EPS := 0.00001


static func min_duration(s: Sequence) -> float:
	if s.fps <= 0.0:
		return 1.0 / 30.0
	return 1.0 / s.fps


static func static_speed(c: Clip) -> float:
	if AnimProp.is_animated(c.speed):
		return 0.0
	return float(c.speed.get("v", 1.0))


static func media_bounded(doc: Project, c: Clip) -> bool:
	if c.is_nest():
		return doc.sequence_by_id(c.sequence_id) != null
	var item: Variant = doc.media_by_id(c.media_id)
	if item == null:
		return false
	return doc.media_is_bounded(item) and not c.placeholder


static func media_duration(doc: Project, c: Clip) -> float:
	if c.is_nest():
		var s: Sequence = doc.sequence_by_id(c.sequence_id)
		return s.duration() if s != null else 0.0
	return doc.media_duration(doc.media_by_id(c.media_id))


static func head_delta_range(doc: Project, s: Sequence, c: Clip, respect_prev: bool) -> Vector2:
	var lo: float = -INF
	var hi: float = c.duration - min_duration(s)
	if respect_prev:
		lo = maxf(lo, -c.start)
	var speed: float = static_speed(c)
	if speed != 0.0 and not c.loop and media_bounded(doc, c):
		var md: float = media_duration(doc, c)
		if speed > 0.0:
			lo = maxf(lo, -c.in_offset / speed)
		else:
			lo = maxf(lo, (md - c.in_offset) / speed)
	if respect_prev:
		var tr: Track = s.track_of(c.id)
		if tr != null:
			var prev: Clip = tr.prev_clip(c)
			if prev != null and prev.end() <= c.start + EPS:
				lo = maxf(lo, prev.end() - c.start)
	return Vector2(lo, hi)


static func tail_delta_range(doc: Project, s: Sequence, c: Clip, respect_next: bool) -> Vector2:
	var lo: float = min_duration(s) - c.duration
	var hi: float = INF
	var speed: float = static_speed(c)
	if speed != 0.0 and not c.loop and media_bounded(doc, c):
		var md: float = media_duration(doc, c)
		var dur_max: float = (md - c.in_offset) / speed if speed > 0.0 else -c.in_offset / speed
		hi = minf(hi, dur_max - c.duration)
	if respect_next:
		var tr: Track = s.track_of(c.id)
		if tr != null:
			var next: Clip = tr.next_clip(c)
			if next != null and next.start >= c.end() - EPS:
				hi = minf(hi, next.start - c.end())
	return Vector2(lo, hi)


static func slip_delta_range(doc: Project, c: Clip) -> Vector2:
	var speed: float = static_speed(c)
	if not media_bounded(doc, c):
		return Vector2(-INF, INF)
	var md: float = media_duration(doc, c)
	if speed == 0.0:
		var reach: Vector2 = c.source_reach()
		return Vector2(-reach.x, md - reach.y)
	if speed > 0.0:
		return Vector2(-c.in_offset / speed, (md - c.in_offset - c.duration * speed) / speed)
	return Vector2((md - c.in_offset) / speed, (-c.in_offset - c.duration * speed) / speed)


static func clamp_delta(d: float, r: Vector2) -> float:
	if r.x > r.y:
		return 0.0
	return clampf(d, r.x, r.y)


static func intersect(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(maxf(a.x, b.x), minf(a.y, b.y))


static func ripple_tracks(s: Sequence, seed_track_ids: PackedStringArray) -> Array[Track]:
	var out: Array[Track] = []
	for t: Track in s.all_tracks():
		if t.locked:
			continue
		if t.sync_lock or seed_track_ids.has(t.id):
			out.append(t)
	return out


## Where a ripple from `from_t` stops because of a locked region (doc/fences.gd): the start of the first fence that
## ends after it, `from_t` itself when it is inside one (nothing moves), INF with no fence in the way.
static func fence_stop(s: Sequence, from_t: float) -> float:
	if s == null or s.fences.is_empty():
		return INF
	var stop: float = INF
	for f: Variant in s.fences:
		if not (f is Dictionary):
			continue
		var a: float = float((f as Dictionary).get("start", 0.0))
		var b: float = float((f as Dictionary).get("end", 0.0))
		if b <= from_t + EPS:
			continue
		if a <= from_t + EPS:
			return from_t - EPS * 2.0
		stop = minf(stop, a)
	return stop


## How far right the clips a ripple moves can go before they would run into what a fence holds still.
static func fence_ahead(s: Sequence, tracks: Array[Track], from_t: float, exclude: PackedStringArray) -> float:
	var stop: float = fence_stop(s, from_t)
	if stop == INF:
		return INF
	var ahead: float = INF
	for t: Track in tracks:
		var moving_end: float = -INF
		var held_start: float = INF
		for c: Clip in t.clips:
			if exclude.has(c.id) or c.start < from_t - EPS:
				continue
			if c.start < stop:
				moving_end = maxf(moving_end, c.end())
			else:
				held_start = minf(held_start, c.start)
		if moving_end > -INF:
			ahead = minf(ahead, minf(held_start, maxf(stop, moving_end)) - moving_end)
	return maxf(ahead, 0.0)


static func ripple_limit(s: Sequence, tracks: Array[Track], from_t: float, exclude: PackedStringArray) -> float:
	var limit: float = INF
	var stop: float = fence_stop(s, from_t)
	for t: Track in tracks:
		var prev_end: float = 0.0
		var first_start: float = -1.0
		for c: Clip in t.clips:
			if exclude.has(c.id):
				continue
			if c.start >= from_t - EPS:
				first_start = c.start
				break
			prev_end = maxf(prev_end, c.end())
		if first_start >= 0.0 and first_start < stop:
			limit = minf(limit, first_start - prev_end)
	return maxf(limit, 0.0)


static func shift_moves(s: Sequence, tracks: Array[Track], from_t: float, delta: float, exclude: PackedStringArray) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	var stop: float = fence_stop(s, from_t)
	for t: Track in tracks:
		for c: Clip in t.clips:
			if exclude.has(c.id):
				continue
			if c.start >= from_t - EPS and c.start < stop:
				moves.append({"id": c.id, "start": c.start + delta, "track_id": t.id})
	return moves


static func has_stacks(tracks: Array[Track]) -> bool:
	for t: Track in tracks:
		if t.has_stack():
			return true
	return false


static func spans_of(t: Track, exclude: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cur: Dictionary = {}
	for c: Clip in t.clips:
		if exclude.has(c.id):
			continue
		if cur.is_empty() or c.start >= float(cur["t1"]) - Track.STACK_EPS:
			var clips: Array[Clip] = [c]
			cur = {"t0": c.start, "t1": c.end(), "clips": clips, "track_id": t.id, "moves": false}
			out.append(cur)
		else:
			cur["t1"] = maxf(float(cur["t1"]), c.end())
			(cur["clips"] as Array[Clip]).append(c)
	return out


static func ripple_plan(s: Sequence, tracks: Array[Track], from_t: float, exclude: PackedStringArray) -> Dictionary:
	var plan: Dictionary = {"s": s, "tracks": tracks, "from": from_t, "exclude": exclude, "stacked": false, "spans": [], "back": 0.0, "ahead": INF}
	if not has_stacks(tracks):
		plan["back"] = ripple_limit(s, tracks, from_t, exclude)
		plan["ahead"] = fence_ahead(s, tracks, from_t, exclude)
		return plan
	var stop: float = fence_stop(s, from_t)
	plan["stacked"] = true
	var per_track: Array = []
	for t: Track in tracks:
		var spans: Array[Dictionary] = spans_of(t, exclude)
		for sp: Dictionary in spans:
			sp["moves"] = float(sp["t0"]) >= from_t - EPS and float(sp["t0"]) < stop
		per_track.append(spans)
	_hold_linked(per_track, from_t)
	var back: float = INF
	var ahead: float = INF
	for spans: Array in per_track:
		var stay_end: float = 0.0
		for sp: Dictionary in spans:
			if bool(sp["moves"]):
				back = minf(back, float(sp["t0"]) - stay_end)
			else:
				stay_end = maxf(stay_end, float(sp["t1"]))
		var stay_start: float = INF
		for i: int in range(spans.size() - 1, -1, -1):
			var sp2: Dictionary = spans[i]
			if bool(sp2["moves"]):
				ahead = minf(ahead, stay_start - float(sp2["t1"]))
			else:
				stay_start = minf(stay_start, float(sp2["t0"]))
	plan["spans"] = per_track
	plan["back"] = maxf(back, 0.0)
	plan["ahead"] = minf(maxf(ahead, 0.0), fence_ahead(s, tracks, from_t, exclude))
	return plan


static func _hold_linked(per_track: Array, from_t: float) -> void:
	var by_link: Dictionary = {}
	var any_held: bool = false
	for spans: Array in per_track:
		for sp: Dictionary in spans:
			for c: Clip in (sp["clips"] as Array[Clip]):
				if c.link_id.is_empty():
					continue
				if not by_link.has(c.link_id):
					by_link[c.link_id] = []
				(by_link[c.link_id] as Array).append(sp)
				if not bool(sp["moves"]) and c.start >= from_t - EPS:
					any_held = true
	if not any_held:
		return
	var changed: bool = true
	while changed:
		changed = false
		for spans: Array in per_track:
			for sp: Dictionary in spans:
				if bool(sp["moves"]):
					continue
				for c: Clip in (sp["clips"] as Array[Clip]):
					if c.link_id.is_empty() or c.start < from_t - EPS:
						continue
					for other: Variant in by_link.get(c.link_id, []):
						var od: Dictionary = other
						if bool(od["moves"]):
							od["moves"] = false
							changed = true


static func plan_moves(plan: Dictionary, delta: float) -> Array[Dictionary]:
	if not bool(plan["stacked"]):
		return shift_moves(plan["s"], plan["tracks"], float(plan["from"]), delta, plan["exclude"])
	var moves: Array[Dictionary] = []
	for spans: Array in plan["spans"]:
		for sp: Dictionary in spans:
			if not bool(sp["moves"]):
				continue
			for c: Clip in (sp["clips"] as Array[Clip]):
				moves.append({"id": c.id, "start": c.start + delta, "track_id": String(sp["track_id"])})
	return moves


static func resize_ripple_moves(t: Track, wants: Dictionary) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	var acc: float = 0.0
	var shift: float = 0.0
	var old_end: float = -INF
	var new_end: float = -INF
	for c: Clip in t.clips:
		var grown: float = c.start + float(wants.get(c.id, c.duration))
		if c.start >= old_end - Track.STACK_EPS:
			if old_end > -INF:
				acc += new_end - old_end
			shift = acc
			old_end = c.end()
			new_end = grown
		else:
			old_end = maxf(old_end, c.end())
			new_end = maxf(new_end, grown)
		if absf(shift) > EPS:
			moves.append({"id": c.id, "start": c.start + shift, "track_id": t.id})
	return moves


static func plan_moving(plan: Dictionary, clip_id: String) -> bool:
	if not bool(plan["stacked"]):
		var c: Clip = (plan["s"] as Sequence).clip_by_id(clip_id)
		var t: Track = (plan["s"] as Sequence).track_of(clip_id)
		return c != null and (plan["tracks"] as Array[Track]).has(t) and not (plan["exclude"] as PackedStringArray).has(clip_id) and c.start >= float(plan["from"]) - EPS
	for spans: Array in plan["spans"]:
		for sp: Dictionary in spans:
			for c: Clip in (sp["clips"] as Array[Clip]):
				if c.id == clip_id:
					return bool(sp["moves"])
	return false


static func stack_trim_range(s: Sequence, c: Clip, side: String, plan: Dictionary, trimmed: PackedStringArray) -> Vector2:
	var r: Vector2 = Vector2(-INF, INF)
	var tr: Track = s.track_of(c.id)
	if tr == null or not tr.has_stack():
		return r
	var frame: float = min_duration(s)
	for o: Clip in tr.overlapping(c):
		if trimmed.has(o.id):
			continue
		var moves: bool = plan_moving(plan, o.id)
		if side == "tail":
			if moves:
				r.x = maxf(r.x, minf(0.0, c.start - o.end() + frame))
			else:
				r.x = maxf(r.x, minf(0.0, o.start - c.end() + frame))
		elif moves:
			r.y = minf(r.y, maxf(0.0, o.end() - c.start - frame))
		else:
			r.y = minf(r.y, maxf(0.0, c.end() - o.start - frame))
	return r


static func stack_trim_shape(s: Sequence, clips: Array[Clip], trimmed: PackedStringArray) -> Dictionary:
	var shape: Dictionary = {}
	for c: Clip in clips:
		var tr: Track = s.track_of(c.id)
		if tr == null or not tr.has_stack():
			return {}
		var others: PackedStringArray = trimmed.duplicate()
		others.remove_at(others.find(c.id))
		var others_end: float = -INF
		for sp: Dictionary in spans_of(tr, others):
			var members: Array[Clip] = sp["clips"]
			if not members.has(c):
				continue
			for o: Clip in members:
				if o != c:
					others_end = maxf(others_end, o.end())
		if others_end == -INF:
			return {}
		if shape.is_empty():
			shape = {"clip_end": c.end(), "others_end": others_end, "end": maxf(c.end(), others_end)}
		elif absf(float(shape["clip_end"]) - c.end()) > EPS or absf(float(shape["others_end"]) - others_end) > EPS:
			return {}
	return shape


static func shape_shift(shape: Dictionary, side: String, delta: float) -> float:
	var clip_end: float = float(shape["clip_end"])
	var new_end: float = clip_end + delta if side == "tail" else clip_end - delta
	return maxf(new_end, float(shape["others_end"])) - float(shape["end"])


static func shape_trim_range(shape: Dictionary, side: String, back: float, ahead: float) -> Vector2:
	var clip_end: float = float(shape["clip_end"])
	var span_end: float = float(shape["end"])
	var held: bool = float(shape["others_end"]) >= span_end - back
	var r: Vector2 = Vector2(-INF, INF)
	if side == "tail":
		if not held:
			r.x = span_end - back - clip_end
		r.y = span_end + ahead - clip_end
	else:
		if not held:
			r.y = clip_end - span_end + back
		r.x = clip_end - span_end - ahead
	return r


static func cover(t: Track, skip: Dictionary) -> Array[PackedFloat64Array]:
	var out: Array[PackedFloat64Array] = []
	for c: Clip in t.clips:
		if skip.has(c.id):
			continue
		if not out.is_empty() and c.start <= out[out.size() - 1][1] + EPS:
			var last: PackedFloat64Array = out[out.size() - 1]
			last[1] = maxf(last[1], c.end())
			out[out.size() - 1] = last
		else:
			out.append(PackedFloat64Array([c.start, c.end()]))
	return out


static func lost_cover(t: Track, removed: Dictionary) -> Array[PackedFloat64Array]:
	var out: Array[PackedFloat64Array] = []
	var after: Array[PackedFloat64Array] = cover(t, removed)
	var k: int = 0
	for seg: PackedFloat64Array in cover(t, {}):
		var edge: float = seg[0]
		while k < after.size() and after[k][1] <= edge + EPS:
			k += 1
		while k < after.size() and after[k][0] < seg[1] - EPS:
			var keep: PackedFloat64Array = after[k]
			if keep[0] > edge + EPS:
				out.append(PackedFloat64Array([edge, keep[0]]))
			edge = maxf(edge, keep[1])
			k += 1
		if seg[1] > edge + EPS:
			out.append(PackedFloat64Array([edge, seg[1]]))
	return out


static func shift_markers(d: Dictionary, delta: float, keep_from: float, keep_to: float) -> void:
	var out: Array = []
	for m: Variant in d.get("markers", []):
		var md: Dictionary = m
		var tm: float = float(md.get("time", 0.0))
		if tm >= keep_from - EPS and tm < keep_to - EPS:
			var nd: Dictionary = md.duplicate(true)
			nd["time"] = tm + delta
			out.append(nd)
	if out.is_empty():
		d.erase("markers")
	else:
		d["markers"] = out


static func split_dicts(c: Clip, t: float, right_id: String) -> Array[Dictionary]:
	var local_t: float = t - c.start
	var left: Dictionary = c.to_dict()
	left["duration"] = local_t
	left.erase("transition_out")
	shift_markers(left, 0.0, 0.0, local_t)
	var right_clip: Clip = c.copy()
	right_clip.shift_keys(-local_t)
	right_clip.id = right_id
	right_clip.start = t
	right_clip.duration = c.end() - t
	right_clip.in_offset = c.source_time(t)
	right_clip.transition_in = {}
	var right: Dictionary = right_clip.to_dict()
	shift_markers(right, 0.0, 0.0, right_clip.duration)
	return [left, right]


static func head_trim_dict(d: Dictionary, delta: float) -> Dictionary:
	var c: Clip = Clip.from_dict(d)
	c.in_offset = c.source_time(c.start + delta)
	c.shift_keys(-delta)
	c.start += delta
	c.duration -= delta
	var out: Dictionary = c.to_dict()
	shift_markers(out, 0.0, 0.0, c.duration)
	return out


static func tail_trim_dict(d: Dictionary, new_duration: float) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	out["duration"] = new_duration
	shift_markers(out, 0.0, 0.0, new_duration)
	return out


static func remap_ids(clips: Array[Dictionary], doc: Project) -> Array[Dictionary]:
	var links: Dictionary = {}
	var groups: Dictionary = {}
	var out: Array[Dictionary] = []
	for d: Dictionary in clips:
		var nd: Dictionary = d.duplicate(true)
		nd["id"] = doc.mint_id("c")
		var link: String = str(nd.get("link_id", ""))
		if not link.is_empty():
			if not links.has(link):
				links[link] = doc.mint_id("l")
			nd["link_id"] = links[link]
		var group: String = str(nd.get("group_id", ""))
		if not group.is_empty():
			if not groups.has(group):
				groups[group] = doc.mint_id("g")
			nd["group_id"] = groups[group]
		out.append(nd)
	return out


const GROUP_CMDS_PATH := "res://doc/commands/group_cmds.gd"
const COPY_WORD := " copy"


static func id_maps(raw: Array[Dictionary], remapped: Array[Dictionary]) -> Dictionary:
	var clips: Dictionary = {}
	var groups: Dictionary = {}
	for i: int in mini(raw.size(), remapped.size()):
		clips[str(raw[i].get("id", ""))] = str(remapped[i].get("id", ""))
		var g: String = str(raw[i].get("group_id", ""))
		if not g.is_empty():
			groups[g] = str(remapped[i].get("group_id", ""))
	return {"clips": clips, "groups": groups}


static func copy_root(name: String) -> String:
	var rx: RegEx = RegEx.create_from_string("^(.*)" + COPY_WORD + "( [0-9]+)?$")
	var m: RegExMatch = rx.search(name)
	if m != null and not m.get_string(1).is_empty():
		return m.get_string(1)
	return name


static func copy_name(name: String, taken: Dictionary) -> String:
	var root: String = copy_root(name)
	var want: String = root + COPY_WORD
	var n: int = 2
	while taken.has(want):
		want = root + COPY_WORD + " " + str(n)
		n += 1
	return want


static func copied_groups(target: Sequence, records: Dictionary, maps: Dictionary, used: PackedStringArray, keep_names: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var taken: Dictionary = {}
	var in_use: PackedStringArray = target.group_ids_in_use()
	for g: Dictionary in target.groups:
		if in_use.has(String(g.get("id", ""))):
			taken[String(g.get("name", ""))] = true
	var clip_map: Dictionary = maps.get("clips", {})
	var group_map: Dictionary = maps.get("groups", {})
	for old_id: Variant in group_map.keys():
		var new_id: String = String(group_map[old_id])
		var rec: Dictionary = records.get(String(old_id), {})
		if rec.is_empty() or not used.has(new_id) or not target.group_by_id(new_id).is_empty():
			continue
		var source_name: String = String(rec.get("name", Sequence.GROUP_NAME))
		if source_name.strip_edges().is_empty():
			source_name = String(load("res://doc/group_tree.gd").call("title", target, String(old_id)))
		var name: String = source_name if keep_names and not taken.has(source_name) else copy_name(source_name, taken)
		taken[name] = true
		var g: Dictionary = Sequence.default_group(new_id, name, int(rec.get("colour", 0)))
		if bool(rec.get("muted", false)):
			g["muted"] = true
			var off: Array = []
			for cid: Variant in rec.get("was_off", []):
				if clip_map.has(String(cid)):
					off.append(String(clip_map[String(cid)]))
			g["was_off"] = off
		out.append(g)
	return out


static func add_group_command(seq_id: String, record: Dictionary) -> RefCounted:
	var script: GDScript = load(GROUP_CMDS_PATH)
	var inner: GDScript = script.get_script_constant_map().get("AddGroup")
	return inner.new(seq_id, record)


static func resolve_track(s: Sequence, track_id: String, kind: String, index: int) -> Track:
	var t: Track = s.track_by_id(track_id)
	if t != null and t.kind == kind:
		return t
	var list: Array[Track] = s.tracks_of_kind(kind)
	if list.is_empty():
		return null
	return list[clampi(index, 0, list.size() - 1)]

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const ViewMap := preload("res://doc/view_map.gd")
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const TrimToPlayhead := preload("res://doc/commands/trim_to_playhead.gd")
const VERBS_PATH := "res://doc/verbs.gd"
const EPS := 0.00001
const RIPPLE := "ripple"
const TRIM := "trim"
const EXTEND := "extend"

static var _last: Dictionary = {}
static var stats: Dictionary = {"plans": 0, "cuts": 0, "owner_scans": 0}


static func _verbs() -> GDScript:
	return load(VERBS_PATH)


static func crosses(c: Clip, t: float) -> bool:
	return c != null and t > c.start + EPS and t < c.end() - EPS


static func shows_lines(video: Clip, e: Dictionary, c: Clip, tr: Track) -> bool:
	if video == null or c == null or tr == null or c == video or not tr.is_sound(c):
		return false
	if c.end() <= video.start or c.start >= video.end():
		return false
	var map: Dictionary = ViewMap.of(e)
	if map.is_empty():
		return not video.link_id.is_empty() and c.link_id == video.link_id
	return ViewMap.reaches(map, video, c, tr.id)


static func owners(s: Sequence, c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s == null or c == null:
		return out
	var tr: Track = s.track_of(c.id)
	if tr == null:
		return out
	if tr.is_picture(c):
		var own: Dictionary = ViewMap.cut_entry(c)
		if not own.is_empty():
			out.append({"video": c, "entry": own})
		return out
	if not tr.is_sound(c):
		return out
	stats["owner_scans"] = int(stats["owner_scans"]) + 1
	for pt: Track in s.all_tracks():
		if not pt.makes_picture():
			continue
		for v: Clip in pt.clips_in_range(c.start, c.end()):
			if v == c or not pt.is_picture(v):
				continue
			var e: Dictionary = ViewMap.cut_entry(v)
			if e.is_empty():
				continue
			if shows_lines(v, e, c, tr):
				out.append({"video": v, "entry": e})
	return out


static func video_lines(video: Clip, e: Dictionary) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var chs: Array[Dictionary] = ViewMap.changes(e, video)
	for i: int in range(1, chs.size()):
		out.append(video.start + float(chs[i]["u"]))
	return out


static func lines_of(s: Sequence, c: Clip) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	for o: Dictionary in owners(s, c):
		for l: float in video_lines(o["video"], o["entry"]):
			if l > c.start + EPS and l < c.end() - EPS:
				out.append(l)
	out.sort()
	return out


static func line_before(lines: PackedFloat64Array, lo: float, t: float) -> float:
	var best: float = NAN
	for l: float in lines:
		if l > lo + EPS and l < t - EPS:
			best = l
	return best


static func line_after(lines: PackedFloat64Array, t: float, hi: float) -> float:
	for l: float in lines:
		if l > t + EPS and l < hi - EPS:
			return l
	return NAN


static func on_line(lines: PackedFloat64Array, t: float) -> bool:
	for l: float in lines:
		if absf(l - t) <= EPS:
			return true
	return false


static func line_clips(s: Sequence, video: Clip, e: Dictionary) -> Array[Clip]:
	var out: Array[Clip] = [video]
	for tr: Track in s.sound_carriers():
		for c: Clip in tr.clips_in_range(video.start, video.end()):
			if shows_lines(video, e, c, tr) and not out.has(c):
				out.append(c)
	return out


static func cut_family(s: Sequence, seeds: Array[Clip], at: float, t: float) -> PackedStringArray:
	var verbs: GDScript = _verbs()
	var ids: PackedStringArray = PackedStringArray()
	for c: Clip in seeds:
		if not ids.has(c.id):
			ids.append(c.id)
		for o: Dictionary in owners(s, c):
			var e: Dictionary = o["entry"]
			var video: Clip = o["video"]
			if not video_lines(video, e).has(at):
				continue
			for f: Clip in line_clips(s, video, e):
				if not ids.has(f.id):
					ids.append(f.id)
	ids = verbs.call("with_linked", s, ids)
	ids = verbs.call("unlocked", s, ids)
	var out: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var c: Clip = s.clip_by_id(id)
		if crosses(c, at) and t >= c.start - EPS and t <= c.end() + EPS:
			out.append(id)
	return out


static func _add_cut(cuts: Dictionary, at: float, c: Clip) -> void:
	var key: String = "%.9f" % at
	if not cuts.has(key):
		cuts[key] = {"t": at, "seeds": PackedStringArray()}
	var seeds: PackedStringArray = (cuts[key] as Dictionary)["seeds"]
	if not seeds.has(c.id):
		seeds.append(c.id)
	(cuts[key] as Dictionary)["seeds"] = seeds


static func _sorted_cuts(cuts: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Variant in cuts.values():
		out.append(v)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	return out


static func plan_edges(s: Sequence, ids: PackedStringArray, side: String, t: float) -> Dictionary:
	var cuts: Dictionary = {}
	var drop: PackedStringArray = PackedStringArray()
	stats["plans"] = int(stats["plans"]) + 1
	for id: String in ids:
		var c: Clip = s.clip_by_id(id)
		if c == null:
			continue
		var lines: PackedFloat64Array = lines_of(s, c)
		if lines.is_empty():
			continue
		if on_line(lines, t):
			drop.append(id)
			continue
		var at: float = line_before(lines, c.start, t) if side == "head" else line_after(lines, t, c.end())
		if not is_nan(at):
			_add_cut(cuts, at, c)
	return {"cuts": _sorted_cuts(cuts), "drop": drop}


static func ripple(s: Sequence, ids: PackedStringArray, side: String, t: float) -> Command:
	_last = {}
	if s == null or ids.is_empty():
		return null
	var plan: Dictionary = plan_edges(s, ids, side, t)
	if (plan["cuts"] as Array).is_empty() and (plan["drop"] as PackedStringArray).is_empty():
		return null
	var keep: PackedStringArray = PackedStringArray()
	for id: String in ids:
		if not (plan["drop"] as PackedStringArray).has(id):
			keep.append(id)
	return CutThen.new(s.id, plan["cuts"], RIPPLE, {"ids": keep, "side": side, "t": t})


static func under_playhead(s: Sequence) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var verbs: GDScript = _verbs()
	for tr: Track in (verbs.call("working_tracks", s) as Array):
		var c: Clip = tr.clip_at(s.playhead)
		if c != null and not out.has(c.id):
			out.append(c.id)
	return out


static func trims(s: Sequence, side: String) -> Command:
	_last = {}
	if s == null:
		return null
	var t: float = s.playhead
	var ids: PackedStringArray = under_playhead(s)
	if ids.is_empty():
		return null
	var plan: Dictionary = plan_edges(s, ids, side, t)
	var keep: PackedStringArray = PackedStringArray()
	for id: String in ids:
		if not (plan["drop"] as PackedStringArray).has(id):
			keep.append(id)
	return CutThen.new(s.id, plan["cuts"], TRIM, {"ids": keep, "side": side, "t": t})


static func trim_to_playhead(doc: Project, s: Sequence, side: String) -> int:
	var cmd: Command = trims(s, side)
	if cmd == null:
		return -1
	var list: Array[Command] = [cmd]
	return 1 if bool(_verbs().call("run", doc, "Trim to playhead", list)) else 0


static func _edge_dist(tr: Track, t: float, direction: int, only: PackedStringArray) -> float:
	var best: float = INF
	for c: Clip in tr.clips:
		if not only.is_empty() and not only.has(c.id):
			continue
		for e: float in [c.start, c.end()]:
			var d: float = absf(e - t)
			if d <= EPS or (direction < 0 and e > t) or (direction > 0 and e < t):
				continue
			best = minf(best, d)
	return best


static func extend(s: Sequence, direction: int, only: PackedStringArray) -> Command:
	_last = {}
	if s == null:
		return null
	var t: float = s.playhead
	var cuts: Dictionary = {}
	stats["plans"] = int(stats["plans"]) + 1
	for tr: Track in (_verbs().call("working_tracks", s) as Array):
		var best_c: Clip = null
		var best_l: float = NAN
		var best_d: float = INF
		for c: Clip in tr.clips_at(t):
			if not only.is_empty() and not only.has(c.id):
				continue
			for l: float in lines_of(s, c):
				var d: float = absf(l - t)
				if d <= EPS or (direction < 0 and l > t) or (direction > 0 and l < t):
					continue
				if d < best_d:
					best_d = d
					best_l = l
					best_c = c
		if best_c == null or best_d >= _edge_dist(tr, t, direction, only) - EPS:
			continue
		_add_cut(cuts, best_l, best_c)
	if cuts.is_empty():
		return null
	return CutThen.new(s.id, _sorted_cuts(cuts), EXTEND, {"direction": direction, "only": only, "t": t})


static func take(doc: Project, s: Sequence) -> Dictionary:
	if _last.is_empty() or doc == null or s == null:
		return {}
	if int(_last.get("doc", 0)) != doc.get_instance_id() or String(_last.get("seq", "")) != s.id:
		return {}
	var out: Dictionary = _last.get("post", {})
	_last = {}
	return out


static func note(doc: Project, seq_id: String, post: Dictionary) -> void:
	_last = {"doc": doc.get_instance_id(), "seq": seq_id, "post": post}


class CutThen extends "res://doc/commands/composite.gd":
	const SELF_DOC := preload("res://doc/view_trims.gd")
	var cuts: Array[Dictionary] = []
	var kind: String = ""
	var args: Dictionary = {}
	var clip_ids: PackedStringArray = PackedStringArray()
	var right_ids: PackedStringArray = PackedStringArray()

	func _init(p_seq_id: String, p_cuts: Array, p_kind: String, p_args: Dictionary) -> void:
		label = "Cut at the view change"
		seq_id = p_seq_id
		for cv: Variant in p_cuts:
			cuts.append((cv as Dictionary).duplicate(true))
		kind = p_kind
		args = p_args.duplicate(true)

	func _pieces_of(pieces: Dictionary, id: String) -> PackedStringArray:
		for orig: Variant in pieces.keys():
			var list: PackedStringArray = pieces[orig]
			if list.has(id):
				return list
		return PackedStringArray([id])

	func _join(pieces: Dictionary, a: String, b: String) -> void:
		for orig: Variant in pieces.keys():
			var list: PackedStringArray = pieces[orig]
			if list.has(a):
				if not list.has(b):
					list.append(b)
				pieces[orig] = list
				return
		pieces[a] = PackedStringArray([a, b])

	func _resolve(s: Sequence, pieces: Dictionary, ids: PackedStringArray, t: float) -> PackedStringArray:
		var out: PackedStringArray = PackedStringArray()
		for id: String in ids:
			for p: String in _pieces_of(pieces, id):
				var c: Clip = s.clip_by_id(p)
				if SELF_DOC.crosses(c, t) and not out.has(p):
					out.append(p)
		return out

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		var pieces: Dictionary = {}
		for cut: Dictionary in cuts:
			var at: float = float(cut["t"])
			var seeds: Array[Clip] = []
			for orig: String in (cut["seeds"] as PackedStringArray):
				var c: Clip = null
				for p: String in _pieces_of(pieces, orig):
					var pc: Clip = s.clip_by_id(p)
					if SELF_DOC.crosses(pc, at):
						c = pc
				if c != null and not seeds.has(c):
					seeds.append(c)
			if seeds.is_empty():
				continue
			var ids: PackedStringArray = SELF_DOC.cut_family(s, seeds, at, float(args.get("t", s.playhead)))
			if ids.is_empty():
				continue
			var split := EditCmds.SplitClips.new(seq_id, ids, at, false)
			apply(doc, split)
			if not split.ok:
				continue
			SELF_DOC.stats["cuts"] = int(SELF_DOC.stats["cuts"]) + 1
			var fresh: PackedStringArray = split.right_ids
			var n: int = 0
			for id: String in ids:
				if n >= fresh.size():
					break
				_join(pieces, id, fresh[n])
				if not clip_ids.has(id):
					clip_ids.append(id)
				right_ids.append(fresh[n])
				clip_ids.append(fresh[n])
				n += 1
		var post: Dictionary = {}
		for orig: Variant in pieces.keys():
			for id: String in (pieces[orig] as PackedStringArray):
				var pc: Clip = s.clip_by_id(id)
				if pc != null:
					post[id] = {"vals": PackedFloat64Array([pc.start, pc.duration, pc.in_offset]), "dict": pc.to_dict()}
		var done: bool = _then(doc, s, pieces)
		if done and not post.is_empty():
			SELF_DOC.note(doc, seq_id, post)
		return done

	func _then(doc: Project, s: Sequence, pieces: Dictionary) -> bool:
		var t: float = float(args.get("t", s.playhead))
		var verbs: GDScript = load(SELF_DOC.VERBS_PATH)
		var any: bool = false
		if kind == SELF_DOC.RIPPLE:
			var ids: PackedStringArray = _resolve(s, pieces, args["ids"], t)
			for cmd: Command in TrimToPlayhead.commands(s, ids, String(args["side"]), t):
				apply(doc, cmd)
				any = any or cmd.ok
			return any
		if kind == SELF_DOC.TRIM:
			var side: String = String(args["side"])
			var taken: Dictionary = {}
			for id: String in _resolve(s, pieces, args["ids"], t):
				if taken.has(id):
					continue
				var fam: PackedStringArray = verbs.call("edge_family", s, id, side)
				var fresh: PackedStringArray = PackedStringArray()
				for f: String in fam:
					if not taken.has(f):
						fresh.append(f)
						taken[f] = true
				if fresh.is_empty():
					continue
				var cmd2 := EditCmds.TrimClip.new(seq_id, fresh, side, t)
				apply(doc, cmd2)
				any = any or cmd2.ok
			return any
		if kind == SELF_DOC.EXTEND:
			var only: PackedStringArray = args.get("only", PackedStringArray())
			var widened: PackedStringArray = PackedStringArray()
			for id: String in only:
				for p: String in _pieces_of(pieces, id):
					if not widened.has(p):
						widened.append(p)
			for cmd3: Command in (verbs.call("extend_commands", s, int(args.get("direction", 0)), widened) as Array):
				apply(doc, cmd3)
				any = any or cmd3.ok
			return any
		return false

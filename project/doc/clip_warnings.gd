extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const WarningCmds := preload("res://doc/commands/warning_cmds.gd")
const BUILT_IN: PackedStringArray = ["Fix the offset", "Redo this cut", "Re-edit", "Check the sound", "Replace this clip"]
const EPS := 0.0005
const MAX_TEXT := 200
const NEST_DEPTH := 8
const CACHE_SLOTS := 32

static var _cache: Dictionary = {}
static var _last: Dictionary = {}
static var scans: int = 0


static func clean_text(text: String) -> String:
	var t: String = text.strip_edges().replace("\n", " ").replace("\t", " ")
	while t.contains("  "):
		t = t.replace("  ", " ")
	return t.left(MAX_TEXT)


static func same_text(a: String, b: String) -> bool:
	return clean_text(a).to_lower() == clean_text(b).to_lower()


static func point_src(c: Clip, t: float) -> float:
	var at: float = t if t >= c.start and t < c.end() else c.start
	return c.source_time(at)


static func make(doc: Project, c: Clip, text: String, t: float) -> Dictionary:
	return {"id": doc.mint_id("w"), "text": clean_text(text), "done": false, "src": point_src(c, t)}


static func open_of(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in c.warnings:
		if not bool(w.get("done", false)):
			out.append(w)
	return out


static func has_open(c: Clip, text: String) -> bool:
	for w: Dictionary in c.warnings:
		if not bool(w.get("done", false)) and same_text(String(w.get("text", "")), text):
			return true
	return false


static func has_open_live(doc: Project, seq: Sequence, c: Clip, text: String) -> bool:
	for w: Dictionary in open_live_on(doc, seq, c):
		if same_text(String(w.get("text", "")), text):
			return true
	return false


static func holds(c: Clip, src: float) -> bool:
	return src >= c.source_in() - EPS and src < c.source_out() - EPS


static func distance(c: Clip, src: float) -> float:
	var si: float = c.source_in()
	var so: float = c.source_out()
	if src < si:
		return si - src
	if src >= so:
		return src - so
	return 0.0


static func _key(doc: Project, seq: Sequence) -> String:
	return str(seq.get_instance_id()) + ":" + str(doc.get_instance_id() if doc != null else 0) + ":" + str(doc.serial if doc != null else 0)


static func live_map(doc: Project, seq: Sequence) -> Dictionary:
	if seq == null:
		return {}
	var key: String = _key(doc, seq)
	if _cache.has(key):
		return _cache[key]
	var sid: int = seq.get_instance_id()
	if doc != null and doc.undo.has_live() and _last.has(sid):
		return _last[sid]
	scans += 1
	var carriers: Dictionary = {}
	for t: Track in seq.all_tracks():
		for c: Clip in t.clips:
			if c.warnings.is_empty():
				continue
			for w: Dictionary in c.warnings:
				var wid: String = String(w.get("id", ""))
				if not carriers.has(wid):
					carriers[wid] = []
				(carriers[wid] as Array).append(c)
	var live: Dictionary = {}
	for wid: String in carriers.keys():
		var list: Array = carriers[wid]
		var chosen: Array = []
		if list.size() == 1:
			chosen = list
		else:
			var src: float = float(_warning_in(list[0] as Clip, wid).get("src", 0.0))
			for o: Variant in list:
				if holds(o as Clip, src):
					chosen.append(o)
			if chosen.is_empty():
				var best: Clip = null
				var best_d: float = INF
				for o: Variant in list:
					var oc: Clip = o
					var dd: float = distance(oc, src)
					if dd < best_d - EPS or (absf(dd - best_d) <= EPS and best != null and oc.start < best.start):
						best = oc
						best_d = dd
				chosen = [best]
		for o: Variant in chosen:
			var oc: Clip = o
			if not live.has(oc.id):
				var fresh: Array[Dictionary] = []
				live[oc.id] = fresh
			(live[oc.id] as Array[Dictionary]).append(_warning_in(oc, wid))
	if _cache.size() >= CACHE_SLOTS:
		_cache.clear()
		_last.clear()
	_cache[key] = live
	_last[sid] = live
	return live


static func _warning_in(c: Clip, wid: String) -> Dictionary:
	for w: Dictionary in c.warnings:
		if String(w.get("id", "")) == wid:
			return w
	return {}


static func live_on(doc: Project, seq: Sequence, c: Clip) -> Array[Dictionary]:
	if c == null or c.warnings.is_empty():
		return []
	var live: Dictionary = live_map(doc, seq)
	if not live.has(c.id):
		return []
	return live[c.id]


static func open_live_on(doc: Project, seq: Sequence, c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in live_on(doc, seq, c):
		if not bool(w.get("done", false)):
			out.append(w)
	return out


static func time_of(c: Clip, src: float) -> float:
	var last: float = maxf(c.start, c.end() - 0.001)
	var sp: float = c.static_speed()
	if sp != 0.0:
		return clampf(c.start + (src - c.in_offset) / sp, c.start, last)
	var a: float = c.start
	var b: float = c.end()
	var rising: bool = c.source_time(b) >= c.source_time(a)
	for i: int in 40:
		var m: float = (a + b) * 0.5
		if (c.source_time(m) < src) == rising:
			a = m
		else:
			b = m
	return clampf(a, c.start, last)


static func clip_name(doc: Project, c: Clip) -> String:
	if not c.label.is_empty():
		return c.label
	var m: MediaItem = doc.media_by_id(c.media_id) if doc != null else null
	return m.label if m != null else "Clip"


static func entries(doc: Project, seq: Sequence, show: String = "open", depth: int = 0, seen: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null or seq == null or depth > NEST_DEPTH or seen.has(seq.id):
		return out
	var live: Dictionary = live_map(doc, seq)
	var order: Dictionary = {}
	var tracks: Array[Track] = seq.all_tracks()
	for i: int in tracks.size():
		order[tracks[i].id] = i
	for cid: String in live.keys():
		var c: Clip = seq.clip_by_id(cid)
		var t: Track = seq.track_of(cid)
		if c == null or t == null:
			continue
		for w: Dictionary in live[cid]:
			var done: bool = bool(w.get("done", false))
			if (show == "open" and done) or (show == "done" and not done):
				continue
			out.append({"seq_id": seq.id, "clip_id": cid, "id": String(w.get("id", "")), "text": String(w.get("text", "")), "done": done, "time": time_of(c, float(w.get("src", 0.0))), "track_id": t.id, "track_label": t.label, "track_order": int(order.get(t.id, 0)), "clip_label": clip_name(doc, c), "outer_clip_id": cid, "outer_time": -1.0, "nest_label": ""})
	var inner: Dictionary = seen.duplicate()
	inner[seq.id] = true
	for t: Track in tracks:
		for c: Clip in t.clips:
			if not c.is_nest():
				continue
			var sub: Sequence = doc.sequence_by_id(c.sequence_id)
			if sub == null:
				continue
			for e: Dictionary in entries(doc, sub, show, depth + 1, inner):
				var ne: Dictionary = e.duplicate()
				var in_t: float = float(e["outer_time"]) if float(e["outer_time"]) >= 0.0 else float(e["time"])
				var sp: float = c.static_speed()
				var mapped: float = c.start + (in_t - c.in_offset) / (sp if sp != 0.0 else 1.0)
				ne["outer_time"] = clampf(mapped, c.start, maxf(c.start, c.end() - 0.001))
				ne["outer_clip_id"] = c.id
				ne["outer_track_id"] = t.id
				ne["outer_track_label"] = t.label
				ne["outer_order"] = int(order.get(t.id, 0))
				ne["nest_label"] = clip_name(doc, c) + (", " + String(e["nest_label"]) if not String(e["nest_label"]).is_empty() else "")
				out.append(ne)
	if depth == 0:
		out.sort_custom(_before)
	return out


static func shown_time(e: Dictionary) -> float:
	return float(e["outer_time"]) if float(e.get("outer_time", -1.0)) >= 0.0 else float(e["time"])


static func shown_track(e: Dictionary) -> String:
	return String(e.get("outer_track_label", e.get("track_label", "")))


static func _before(a: Dictionary, b: Dictionary) -> bool:
	var ta: float = shown_time(a)
	var tb: float = shown_time(b)
	if absf(ta - tb) > 0.000001:
		return ta < tb
	var oa: int = int(a.get("outer_order", a.get("track_order", 0)))
	var ob: int = int(b.get("outer_order", b.get("track_order", 0)))
	if oa != ob:
		return oa < ob
	return String(a["text"]).naturalnocasecmp_to(String(b["text"])) < 0


static func open_count(doc: Project, seq: Sequence) -> int:
	return entries(doc, seq, "open").size()


static func targets(seq: Sequence, clicked_id: String, ids: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null:
		return out
	var pool: PackedStringArray = ids.duplicate()
	if not clicked_id.is_empty() and not pool.has(clicked_id):
		pool.insert(0, clicked_id)
	var families: Dictionary = {}
	var order: Array[String] = []
	for id: String in pool:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			continue
		var fam: String = c.link_id if not c.link_id.is_empty() else "clip:" + c.id
		if not families.has(fam):
			var members_new: Array[Clip] = []
			families[fam] = members_new
			order.append(fam)
		(families[fam] as Array[Clip]).append(c)
	for fam: String in order:
		var members: Array[Clip] = families[fam]
		var pick: Clip = null
		for c: Clip in members:
			if c.id == clicked_id:
				pick = c
		if pick == null:
			for c: Clip in members:
				var t: Track = seq.track_of(c.id)
				if t != null and t.is_picture(c):
					pick = c
					break
		if pick == null:
			pick = members[0]
		out.append(pick.id)
	return out


static func _copy(list: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in list:
		out.append(w.duplicate(true))
	return out


static func add(doc: Project, seq: Sequence, ids: PackedStringArray, text: String, t: float) -> bool:
	var body: String = clean_text(text)
	if doc == null or seq == null or body.is_empty():
		return false
	var cmds: Array[Command] = []
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null or has_open_live(doc, seq, c, body):
			continue
		var next: Array[Dictionary] = _copy(c.warnings)
		next.append(make(doc, c, body, t))
		cmds.append(WarningCmds.SetWarnings.new(seq.id, id, next))
	if cmds.is_empty():
		return false
	return Verbs.run(doc, "Add warning", cmds)


static func toggle(doc: Project, seq: Sequence, ids: PackedStringArray, text: String, t: float) -> bool:
	if doc == null or seq == null or ids.is_empty():
		return false
	var all_have: bool = true
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		if c != null and not has_open_live(doc, seq, c, text):
			all_have = false
	if not all_have:
		return add(doc, seq, ids, text, t)
	var pairs: Array = []
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			continue
		for w: Dictionary in open_live_on(doc, seq, c):
			if same_text(String(w.get("text", "")), text):
				pairs.append([id, String(w.get("id", ""))])
	return _edit(doc, seq, pairs, -1, "Remove warning")


static func twins(doc: Project, seq: Sequence, clip_id: String, wid: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray([clip_id])
	var live: Dictionary = live_map(doc, seq)
	for t: Track in seq.all_tracks():
		for c: Clip in t.clips:
			if c.id == clip_id or c.warnings.is_empty() or _warning_in(c, wid).is_empty():
				continue
			var shown: bool = false
			for w: Dictionary in live.get(c.id, []):
				if String(w.get("id", "")) == wid:
					shown = true
			if not shown:
				out.append(c.id)
	return out


static func _edit(doc: Project, seq: Sequence, pairs: Array, done: int, label: String) -> bool:
	if doc == null or seq == null:
		return false
	var by_clip: Dictionary = {}
	for p: Variant in pairs:
		var pa: Array = p
		for cid: String in twins(doc, seq, String(pa[0]), String(pa[1])):
			if not by_clip.has(cid):
				by_clip[cid] = {}
			(by_clip[cid] as Dictionary)[String(pa[1])] = true
	var cmds: Array[Command] = []
	for cid: String in by_clip.keys():
		var c: Clip = seq.clip_by_id(cid)
		if c == null:
			continue
		var wanted: Dictionary = by_clip[cid]
		var next: Array[Dictionary] = []
		var changed: bool = false
		for w: Dictionary in c.warnings:
			var hit: bool = wanted.has(String(w.get("id", "")))
			if hit and done < 0:
				changed = true
				continue
			var nw: Dictionary = w.duplicate(true)
			if hit and bool(nw.get("done", false)) != (done == 1):
				nw["done"] = done == 1
				changed = true
			next.append(nw)
		if changed:
			cmds.append(WarningCmds.SetWarnings.new(seq.id, cid, next))
	if cmds.is_empty():
		return false
	return Verbs.run(doc, label, cmds)


static func set_done(doc: Project, seq: Sequence, clip_id: String, wid: String, done: bool) -> bool:
	return _edit(doc, seq, [[clip_id, wid]], 1 if done else 0, "Mark warning done" if done else "Open warning again")


static func remove(doc: Project, seq: Sequence, clip_id: String, wid: String) -> bool:
	return _edit(doc, seq, [[clip_id, wid]], -1, "Remove warning")


static func _live_pairs(doc: Project, seq: Sequence, ids: PackedStringArray, only_open: bool) -> Array:
	var pairs: Array = []
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			continue
		for w: Dictionary in live_on(doc, seq, c):
			if only_open and bool(w.get("done", false)):
				continue
			pairs.append([id, String(w.get("id", ""))])
	return pairs


static func done_all(doc: Project, seq: Sequence, ids: PackedStringArray) -> bool:
	if seq == null:
		return false
	return _edit(doc, seq, _live_pairs(doc, seq, ids, true), 1, "Mark warnings done")


static func remove_all(doc: Project, seq: Sequence, ids: PackedStringArray) -> bool:
	if seq == null:
		return false
	return _edit(doc, seq, _live_pairs(doc, seq, ids, false), -1, "Remove warnings")


static func any_live(doc: Project, seq: Sequence, ids: PackedStringArray, only_open: bool) -> bool:
	if seq == null:
		return false
	return not _live_pairs(doc, seq, ids, only_open).is_empty()

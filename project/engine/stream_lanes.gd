extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Project := preload("res://doc/project.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ViewStreams := preload("res://doc/view_streams.gd")
const GRAPH_PATH := "res://engine/audio_graph.gd"
const GAIN_TAG := "_s"
const COPY_TAG := "~s"
const LANE_TAG := "_stream"
const VIEW_GAIN_ID := "gain"
const HEARD_DB := -40.0

static var stats: Dictionary = {"expands": 0, "copies": 0, "lanes": 0}
static var off: bool = false


static func _graph() -> GDScript:
	return load(GRAPH_PATH)


static func copy_id(clip_id: String, stream: int) -> String:
	return clip_id + COPY_TAG + str(stream)


static func lane_id(track_id: String, stream: int) -> String:
	return track_id + LANE_TAG + str(stream)


static func any_streams(sources: Array) -> bool:
	for src: Variant in sources:
		if ViewStreams.on((src as Dictionary)["map"]):
			return true
	return false


static func extra_streams(sources: Array, reach: PackedInt32Array, c: Clip, track_id: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var mine: int = ViewStreams.own(c)
	for si: int in reach:
		var src: Dictionary = sources[si]
		var map: Dictionary = src["map"]
		var video: Clip = src["clip"]
		if not ViewStreams.applies(map, c, video):
			continue
		if not _reaches(map, video, c, track_id):
			continue
		for s: int in ViewStreams.streams_of(map, track_id, c, video):
			if s != mine and not out.has(s):
				out.append(s)
	out.sort()
	return out


static func entry_streams(sources: Array, reach: PackedInt32Array, c: Clip, track_id: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array([-1])
	out.append_array(extra_streams(sources, reach, c, track_id))
	return out


static func _reaches(map: Dictionary, video: Clip, c: Clip, track_id: String) -> bool:
	if not ViewStreams.governs(map, track_id, c.id):
		return false
	if String(map.get("scope", "group")) == "group" and not ViewStreams.family(video, c) and not ViewStreams.named_clip(map, c.id):
		return false
	return c.end() > video.start and c.start < video.end()


static func expand(seq: Sequence, tracks: Array) -> void:
	if seq == null or tracks.is_empty() or off:
		return
	var g: GDScript = _graph()
	var sources: Array[Dictionary] = g.call("pair_view_sources", seq)
	if sources.is_empty() or not any_streams(sources):
		return
	stats["expands"] = int(stats["expands"]) + 1
	var index: Dictionary = g.call("reach_for", seq, sources)
	var feeds: bool = bool(g.call("feeds_on"))
	var by_id: Dictionary = (g.call("clip_owners", seq) as Dictionary)["id"]
	var made: Array = []
	for t: Variant in tracks:
		var td: Dictionary = t
		var owner_id: String = String(td.get("owner", td.get("id", "")))
		var by_stream: Dictionary = {}
		for ce: Variant in td.get("clips", []):
			var cd: Dictionary = ce
			if bool(cd.get("rendered", not String(cd.get("path", "")).is_empty())):
				continue
			var pair: Variant = by_id.get(String(cd.get("id", "")), null)
			if not (pair is Array):
				continue
			var c: Clip = (pair as Array)[0]
			var reach: PackedInt32Array = g.call("reaching_in", index, c)
			if reach.is_empty():
				continue
			for s: int in extra_streams(sources, reach, c, owner_id):
				if not by_stream.has(s):
					by_stream[s] = []
				(by_stream[s] as Array).append(copy_entry(seq, cd, c, owner_id, s))
		var keys: Array = by_stream.keys()
		keys.sort()
		for s2: Variant in keys:
			var clips: Array = by_stream[s2]
			stats["copies"] = int(stats["copies"]) + clips.size()
			stats["lanes"] = int(stats["lanes"]) + 1
			made.append(lane_entry(g, td, owner_id, int(s2), clips, feeds))
	tracks.append_array(made)


static func lane_entry(g: GDScript, td: Dictionary, owner_id: String, stream: int, clips: Array, feeds: bool) -> Dictionary:
	var id: String = lane_id(String(td.get("id", owner_id)), stream)
	if feeds:
		return g.call("feed_entry", id, owner_id, owner_id, bool(td.get("muted", false)), bool(td.get("solo", false)), [], clips)
	var copy: Dictionary = {}
	for key: Variant in td.keys():
		if String(key) == "clips":
			continue
		var v: Variant = td[key]
		copy[key] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	copy["id"] = id
	copy["owner"] = owner_id
	copy.erase("feed")
	copy["clips"] = clips
	return copy


static func copy_entry(seq: Sequence, entry: Dictionary, c: Clip, track_id: String, stream: int) -> Dictionary:
	var g: GDScript = _graph()
	var copy: Dictionary = entry.duplicate(true)
	copy["id"] = copy_id(c.id, stream)
	copy["stream"] = stream
	var tail: String = "_view_" + c.id
	var kept: Array = []
	var at: int = -1
	for fx: Variant in copy.get("effects", []):
		var fd: Dictionary = fx
		if String(fd.get("id", "")) == VIEW_GAIN_ID and String(fd.get("uid", "")).ends_with(tail):
			if at < 0:
				at = kept.size()
			continue
		kept.append(fd)
	var gains: Array[Dictionary] = g.call("view_gain_from", seq, c, track_id, stream)
	if at < 0:
		at = kept.size()
	for i: int in gains.size():
		kept.insert(at + i, gains[i])
	copy["effects"] = kept
	return copy


static func shift_copies(by_id: Dictionary, c: Clip, track_id: String, video: Clip, e: Dictionary, map: Dictionary, live: bool, sync: RefCounted, shifts: bool) -> void:
	if not ViewStreams.applies(map, c, video):
		return
	var g: GDScript = _graph()
	for s: int in ViewStreams.extra_of(map, track_id, c, video):
		var id: String = copy_id(c.id, s)
		if by_id.has(id):
			g.call("pair_shift", by_id[id], c, track_id, video, e, map, live, sync, shifts, s)


static func governed_by_streams(sources: Array, c: Clip, track_id: String) -> bool:
	for src: Variant in sources:
		var sd: Dictionary = src
		if ViewStreams.applies(sd["map"], c, sd["clip"]) and _reaches(sd["map"], sd["clip"], c, track_id):
			return true
	return false


static func read_entry(d: Project, seq: Sequence, tr: Track, c: Clip, sources: Array[Dictionary], stream: int) -> Dictionary:
	var g: GDScript = _graph()
	var gains: Array[Dictionary] = g.call("view_gain_from", seq, c, tr.id, stream)
	var entry: Dictionary = {"id": c.id, "start": c.start, "duration": c.duration, "in_offset": c.in_offset, "speed": c.speed.duplicate(true), "fade_in": 0.0, "fade_out": 0.0, "muted": false, "effects": gains}
	g.call("crossfade_read", d, tr, c, entry)
	var sync: RefCounted = (load("res://engine/pair_sync_state.gd") as GDScript).call("instance")
	for src: Dictionary in sources:
		var video: Clip = src["clip"]
		var e: Dictionary = src["entry"]
		var map: Dictionary = src["map"]
		var live: bool = bool(sync.call("live_for", video.id, String(e.get("uid", ""))))
		if not live and not _any_offset(e):
			continue
		if not _reaches(map, video, c, tr.id):
			continue
		g.call("pair_shift", entry, c, tr.id, video, e, map, live, sync, g.call("offset_piece", sources, src, c, tr.id), stream)
	return entry


static func _any_offset(e: Dictionary) -> bool:
	return bool((load("res://doc/view_map.gd") as GDScript).call("any_offset", e))


static func heard_intervals(entry: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var start: float = float(entry.get("start", 0.0))
	var dur: float = float(entry.get("duration", 0.0))
	if bool(entry.get("muted", false)) or dur <= 0.0:
		return out
	var gains: Array[Dictionary] = []
	var cuts: Array[float] = [0.0, dur]
	for fx: Variant in entry.get("effects", []):
		var fd: Dictionary = fx
		if String(fd.get("id", "")) != VIEW_GAIN_ID or not String(fd.get("uid", "")).contains("_view_"):
			continue
		var db: Dictionary = (fd.get("params", {}) as Dictionary).get("db", AnimProp.make(0.0))
		gains.append(db)
		for k: Dictionary in AnimProp.keys(db):
			var u: float = float(k.get("t", 0.0))
			if u > 0.0 and u < dur:
				cuts.append(u)
	cuts.sort()
	for i: int in range(1, cuts.size()):
		var a: float = cuts[i - 1]
		var b: float = cuts[i]
		if b - a <= 0.0000001:
			continue
		var mid: float = (a + b) * 0.5
		var heard: bool = true
		for db2: Dictionary in gains:
			if AnimProp.evaluate_float(db2, mid, dur) < HEARD_DB:
				heard = false
				break
		if not heard:
			continue
		if not out.is_empty() and absf(out[out.size() - 1].y - (start + a)) <= 0.0000001:
			out[out.size() - 1].y = start + b
		else:
			out.append(Vector2(start + a, start + b))
	return out


static func plan_spans(d: Project, seq: Sequence, tr: Track, c: Clip, sources: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var waves: GDScript = load("res://ui/timeline/timeline_wave.gd")
	var reach: PackedInt32Array = PackedInt32Array()
	for i: int in sources.size():
		reach.append(i)
	for st: int in entry_streams(sources, reach, c, tr.id):
		var entry: Dictionary = read_entry(d, seq, tr, c, sources, st)
		var played: int = st if st >= 0 else ViewStreams.own(c)
		var spans: Array[Dictionary] = waves.call("read_spans", entry)
		for iv: Vector2 in heard_intervals(entry):
			var cut: Array[Dictionary] = waves.call("clip_spans", spans, maxf(iv.x, c.start), minf(iv.y, c.end()))
			for sp: Dictionary in cut:
				sp["stream"] = played
				out.append(sp)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t0"]) < float(b["t0"]))
	return out

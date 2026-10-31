extends RefCounted

const MarkerLayers := preload("res://doc/marker_layers.gd")
const TAG_KIND := "tag"
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Marker := preload("res://doc/marker.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")

const LABEL := "Scatter sounds"
const MODE_GAPS := "gaps"
const MODE_MARKERS := "markers"
const MODES: PackedStringArray = [MODE_GAPS, MODE_MARKERS]
const MODE_LABELS: Dictionary = {MODE_GAPS: "At random gaps", MODE_MARKERS: "On the markers"}
const BY_COUNT := "count"
const BY_GAP := "gap"
const SPACINGS: PackedStringArray = [BY_COUNT, BY_GAP]
const SPACING_LABELS: Dictionary = {BY_COUNT: "This many copies", BY_GAP: "This average gap"}
const ON_PUSH := "push"
const ON_LANE := "lane"
const ON_CUT := "cut"
const RULES: PackedStringArray = [ON_PUSH, ON_LANE, ON_CUT]
const RULE_LABELS: Dictionary = {ON_PUSH: "Push the later one later", ON_LANE: "Put it on the next track", ON_CUT: "Cut the earlier one short"}

const EPS := 0.00001
const MIN_GAP := 0.002
const MIN_LENGTH := 0.01
const MAX_COPIES := 2000
const FALLBACK_LENGTH := 0.5
const GAIN_MIN := -60.0
const GAIN_MAX := 24.0
const GAIN_RANDOM_MAX := 24.0
const PITCH_MIN := 0.25
const PITCH_MAX := 4.0
const PITCH_RANDOM_MAX := 0.9
const COUNT_MAX := 2000
const GAP_MAX := 600.0


static func defaults() -> Dictionary:
	return {
		"seed": 1,
		"mode": MODE_GAPS,
		"spacing": BY_COUNT,
		"count": 12,
		"gap": 0.5,
		"gap_random": 0.3,
		"gain_db": 0.0,
		"gain_random_db": 0.0,
		"pitch": 1.0,
		"pitch_random": 0.0,
		"allow_overlap": false,
		"on_overlap": ON_LANE,
		"lanes": PackedStringArray(),
		"sounds": [] as Array[Dictionary],
		"markers": PackedFloat64Array(),
		"from": 0.0,
		"to": 0.0,
	}


static func _list(v: Variant) -> Array:
	if v is Array:
		return v as Array
	if v is PackedStringArray:
		return Array(v as PackedStringArray)
	if v is PackedFloat64Array:
		return Array(v as PackedFloat64Array)
	if v is PackedFloat32Array:
		return Array(v as PackedFloat32Array)
	return []


static func sound_row(media_id: String, label: String, duration: float, in_offset: float = 0.0) -> Dictionary:
	return {"media_id": media_id, "label": label, "duration": maxf(duration, 0.0), "in_offset": maxf(in_offset, 0.0)}


static func normalise(raw: Dictionary) -> Dictionary:
	var o: Dictionary = defaults()
	o["seed"] = int(raw.get("seed", o["seed"]))
	var mode: String = str(raw.get("mode", MODE_GAPS))
	o["mode"] = mode if MODES.has(mode) else MODE_GAPS
	var spacing: String = str(raw.get("spacing", BY_COUNT))
	o["spacing"] = spacing if SPACINGS.has(spacing) else BY_COUNT
	o["count"] = clampi(int(raw.get("count", 12)), 0, COUNT_MAX)
	o["gap"] = clampf(float(raw.get("gap", 0.5)), MIN_GAP, GAP_MAX)
	o["gap_random"] = clampf(float(raw.get("gap_random", 0.3)), 0.0, 1.0)
	o["gain_db"] = clampf(float(raw.get("gain_db", 0.0)), GAIN_MIN, GAIN_MAX)
	o["gain_random_db"] = clampf(float(raw.get("gain_random_db", 0.0)), 0.0, GAIN_RANDOM_MAX)
	o["pitch"] = clampf(float(raw.get("pitch", 1.0)), PITCH_MIN, PITCH_MAX)
	o["pitch_random"] = clampf(float(raw.get("pitch_random", 0.0)), 0.0, PITCH_RANDOM_MAX)
	o["allow_overlap"] = bool(raw.get("allow_overlap", false))
	var rule: String = str(raw.get("on_overlap", ON_LANE))
	o["on_overlap"] = rule if RULES.has(rule) else ON_LANE
	var lanes: PackedStringArray = PackedStringArray()
	for v: Variant in _list(raw.get("lanes", [])):
		var lane_id: String = str(v)
		if not lane_id.is_empty() and not lanes.has(lane_id):
			lanes.append(lane_id)
	o["lanes"] = lanes
	var sounds: Array[Dictionary] = []
	for v: Variant in _list(raw.get("sounds", [])):
		if not (v is Dictionary):
			continue
		var d: Dictionary = v
		var mid: String = str(d.get("media_id", ""))
		if mid.is_empty():
			continue
		sounds.append(sound_row(mid, str(d.get("label", mid)), float(d.get("duration", 0.0)), float(d.get("in_offset", 0.0))))
	o["sounds"] = sounds
	var times: PackedFloat64Array = PackedFloat64Array()
	for v: Variant in _list(raw.get("markers", [])):
		times.append(float(v))
	times.sort()
	o["markers"] = times
	var from: float = maxf(float(raw.get("from", 0.0)), 0.0)
	var to: float = maxf(float(raw.get("to", 0.0)), 0.0)
	o["from"] = from
	o["to"] = to if to > from else from
	return o


static func _times(o: Dictionary, rng: RandomNumberGenerator) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var from: float = float(o["from"])
	var to: float = float(o["to"])
	var bounded: bool = to > from + EPS
	if String(o["mode"]) == MODE_MARKERS:
		var ms: PackedFloat64Array = o["markers"]
		for t: float in ms:
			if bounded and (t < from - EPS or t > to + EPS):
				continue
			if not out.is_empty() and absf(out[out.size() - 1] - t) <= EPS:
				continue
			out.append(t)
		return out
	if not bounded:
		return out
	var jitter: float = float(o["gap_random"])
	if String(o["spacing"]) == BY_COUNT:
		var n: int = int(o["count"])
		if n <= 0:
			return out
		var nominal: float = (to - from) / float(n)
		for i: int in n:
			var base: float = from + nominal * float(i)
			out.append(clampf(base + rng.randf_range(-1.0, 1.0) * jitter * nominal * 0.5, from, to))
		out.sort()
		return out
	var gap: float = float(o["gap"])
	var walk: float = from
	while walk < to - EPS and out.size() < MAX_COPIES:
		out.append(walk)
		walk += maxf(gap * (1.0 + rng.randf_range(-1.0, 1.0) * jitter), MIN_GAP)
	return out


static func report(raw: Dictionary) -> Dictionary:
	var o: Dictionary = normalise(raw)
	var clips: Array[Dictionary] = []
	var out: Dictionary = {"clips": clips, "dropped": 0, "lanes": PackedStringArray(), "why": "", "options": o}
	var sounds: Array[Dictionary] = o["sounds"]
	var lanes: PackedStringArray = o["lanes"]
	if sounds.is_empty():
		out["why"] = "Pick at least one sound"
		return out
	if lanes.is_empty():
		out["why"] = "Allow at least one track"
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = int(o["seed"])
	var times: PackedFloat64Array = _times(o, rng)
	if times.is_empty():
		out["why"] = "There is nothing to place in that span"
		return out
	var allow: bool = bool(o["allow_overlap"])
	var rule: String = String(o["on_overlap"])
	var base_gain: float = float(o["gain_db"])
	var gain_spread: float = float(o["gain_random_db"])
	var base_pitch: float = float(o["pitch"])
	var pitch_spread: float = float(o["pitch_random"])
	var to: float = float(o["to"])
	var bounded: bool = to > float(o["from"]) + EPS
	var reach: Dictionary = {}
	var last_on: Dictionary = {}
	for lane_id: String in lanes:
		reach[lane_id] = -INF
		last_on[lane_id] = -1
	var dropped: int = 0
	for i: int in times.size():
		var pick: int = rng.randi() % sounds.size()
		var gain_off: float = rng.randf_range(-1.0, 1.0) * gain_spread
		var pitch_off: float = rng.randf_range(-1.0, 1.0) * pitch_spread
		var sound: Dictionary = sounds[pick]
		var pitch: float = clampf(base_pitch * (1.0 + pitch_off), PITCH_MIN, PITCH_MAX)
		var source: float = float(sound["duration"])
		if source <= 0.0:
			source = FALLBACK_LENGTH
		var dur: float = maxf(source / pitch, MIN_LENGTH)
		var start: float = times[i]
		var lane: String = lanes[0]
		var trim_at: int = -1
		if not allow:
			if rule == ON_LANE:
				var found: String = ""
				for lane_id2: String in lanes:
					if start >= float(reach[lane_id2]) - EPS:
						found = lane_id2
						break
				if found.is_empty():
					dropped += 1
					continue
				lane = found
			elif rule == ON_PUSH:
				start = maxf(start, float(reach[lane]))
				if bounded and start >= to - EPS:
					dropped += 1
					continue
			else:
				if start < float(reach[lane]) - EPS:
					var at: int = int(last_on[lane])
					if at < 0:
						dropped += 1
						continue
					var room: float = start - float(clips[at]["start"])
					if room < MIN_LENGTH:
						dropped += 1
						continue
					trim_at = at
		if trim_at >= 0:
			clips[trim_at]["duration"] = start - float(clips[trim_at]["start"])
			clips[trim_at]["trimmed"] = true
		clips.append({
			"track_id": lane,
			"media_id": String(sound["media_id"]),
			"label": String(sound["label"]),
			"start": start,
			"duration": dur,
			"in_offset": float(sound["in_offset"]),
			"gain_db": clampf(base_gain + gain_off, GAIN_MIN, GAIN_MAX),
			"pitch": pitch,
			"sound": pick,
			"trimmed": false,
		})
		reach[lane] = start + dur
		last_on[lane] = clips.size() - 1
	var used: PackedStringArray = PackedStringArray()
	for lane_id3: String in lanes:
		if int(last_on[lane_id3]) >= 0:
			used.append(lane_id3)
	out["clips"] = clips
	out["dropped"] = dropped
	out["lanes"] = used
	return out


static func plan(raw: Dictionary) -> Array[Dictionary]:
	var clips: Array[Dictionary] = report(raw)["clips"]
	return clips


static func overlaps(clips: Array[Dictionary]) -> bool:
	var reach: Dictionary = {}
	for c: Dictionary in clips:
		var lane: String = String(c["track_id"])
		var start: float = float(c["start"])
		if reach.has(lane) and start < float(reach[lane]) - EPS:
			return true
		reach[lane] = maxf(float(reach.get(lane, -INF)), start + float(c["duration"]))
	return false


static func summary(raw: Dictionary) -> String:
	var r: Dictionary = report(raw)
	var clips: Array[Dictionary] = r["clips"]
	if clips.is_empty():
		var why: String = String(r["why"])
		return why if not why.is_empty() else "Nothing to place"
	var used: PackedStringArray = r["lanes"]
	var text: String = "%d copies on %d track%s" % [clips.size(), used.size(), "" if used.size() == 1 else "s"]
	var dropped: int = int(r["dropped"])
	if dropped > 0:
		text += ", %d had no room and were left out" % dropped
	if overlaps(clips):
		text += ", some of them overlap"
	return text


static func span_of(seq: Sequence) -> Dictionary:
	if seq == null:
		return {"from": 0.0, "to": 0.0}
	if seq.in_point >= 0.0 and seq.out_point > seq.in_point:
		return {"from": seq.in_point, "to": seq.out_point}
	var lo: float = INF
	var hi: float = -INF
	for clip_id: String in seq.selected_clip_ids:
		var c: Clip = seq.clip_by_id(clip_id)
		if c == null:
			continue
		lo = minf(lo, c.start)
		hi = maxf(hi, c.end())
	if hi > lo:
		return {"from": lo, "to": hi}
	return {"from": 0.0, "to": seq.duration()}


static func span_source(seq: Sequence) -> String:
	if seq == null:
		return "no sequence"
	if seq.in_point >= 0.0 and seq.out_point > seq.in_point:
		return "the in and out points"
	for clip_id: String in seq.selected_clip_ids:
		if seq.clip_by_id(clip_id) != null:
			return "the clips you picked"
	return "the whole sequence"


static func lanes_of(seq: Sequence) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null:
		return out
	for t: Track in seq.sound_carriers():
		if not t.locked:
			out.append(t.id)
	return out


static func markers_of(seq: Sequence) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if seq == null:
		return out
	for m: Marker in MarkerLayers.usable(seq):
		if m.kind == TAG_KIND:
			continue
		out.append(m.time)
	out.sort()
	return out


static func sound_media(doc: Project) -> Array[MediaItem]:
	var out: Array[MediaItem] = []
	if doc == null:
		return out
	for m: MediaItem in doc.media:
		if m.kind == "sequence" or m.kind == "title" or m.kind == "shape" or m.kind == "adjust" or m.kind == "generator":
			continue
		if m.kind == "audio" or m.audio_only or m.has_audio:
			out.append(m)
	return out


static func sound_rows(doc: Project, media_ids: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null:
		return out
	for media_id: String in media_ids:
		var m: MediaItem = doc.media_by_id(media_id)
		if m == null:
			continue
		out.append(sound_row(m.id, m.label, doc.media_duration(m)))
	return out


static func options_for(doc: Project, seq: Sequence, raw: Dictionary) -> Dictionary:
	var o: Dictionary = normalise(raw)
	var span: Dictionary = span_of(seq)
	o["from"] = float(span["from"])
	o["to"] = float(span["to"])
	o["markers"] = markers_of(seq)
	var lanes: PackedStringArray = PackedStringArray()
	var allowed: PackedStringArray = o["lanes"]
	for lane_id: String in lanes_of(seq):
		if allowed.has(lane_id):
			lanes.append(lane_id)
	o["lanes"] = lanes
	var ids: PackedStringArray = PackedStringArray()
	for s: Dictionary in (o["sounds"] as Array[Dictionary]):
		ids.append(String(s["media_id"]))
	o["sounds"] = sound_rows(doc, ids)
	return o


static func run(doc: Project, seq: Sequence, raw: Dictionary) -> int:
	if doc == null or seq == null:
		return 0
	var rows: Array[Dictionary] = plan(options_for(doc, seq, raw))
	if rows.is_empty():
		return 0
	var cmd: RefCounted = Place.new(seq.id, rows)
	var tx: RefCounted = doc.undo.begin(LABEL)
	tx.call("apply", cmd)
	if not bool(tx.call("commit")):
		return 0
	var made: PackedStringArray = cmd.get("made")
	return made.size()


class Place extends "res://doc/commands/composite.gd":
	var rows: Array[Dictionary] = []
	var made: PackedStringArray = PackedStringArray()

	func _init(p_seq_id: String, p_rows: Array[Dictionary]) -> void:
		label = "Scatter sounds"
		seq_id = p_seq_id
		for r: Dictionary in p_rows:
			rows.append(r.duplicate(true))

	func _plan(doc: Project) -> bool:
		var s: Sequence = seq(doc)
		if s == null:
			return false
		made = PackedStringArray()
		for r: Dictionary in rows:
			var t: Track = s.track_by_id(String(r["track_id"]))
			if t == null or t.locked:
				continue
			var start: float = float(r["start"])
			var dur: float = float(r["duration"])
			if dur <= 0.0:
				continue
			var clip_id: String = doc.mint_id("c")
			var d: Dictionary = {
				"id": clip_id,
				"media_id": String(r["media_id"]),
				"label": String(r["label"]),
				"start": start,
				"duration": dur,
				"in_offset": float(r.get("in_offset", 0.0)),
				"audio": {"stream": 0.0, "volume": AnimProp.make(db_to_linear(float(r.get("gain_db", 0.0))))},
			}
			var pitch: float = float(r.get("pitch", 1.0))
			if not is_equal_approx(pitch, 1.0):
				d["speed"] = AnimProp.make(pitch)
			var part: String = t.part_for("audio")
			if not part.is_empty():
				d["part"] = part
			var top: int = t.top_stack_over(start, start + dur)
			if top != 0:
				d["stack"] = top
			apply(doc, ClipCmds.PlaceClip.new(seq_id, t.id, d))
			made.append(clip_id)
		return not made.is_empty()

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const KEY := "censor"
const TOOL_ID := "censor"
const RES_DIR := "res://assets/censor/"
const USER_DIR := "user://censor/"
const SOUNDS: Dictionary = {
	"bleep": {"label": "Bleep 1 kHz", "tag": "Bleep", "file": "bleep_1k.wav", "length": 3.0, "endless": true},
	"low_bleep": {"label": "Low bleep", "tag": "Low bleep", "file": "low_bleep.wav", "length": 3.0, "endless": true},
	"beep_pair": {"label": "Beep pair", "tag": "Beep pair", "file": "beep_pair.wav", "length": 0.3, "endless": false},
	"silence": {"label": "Silence", "tag": "Silence", "file": "", "length": 0.0, "endless": false},
}
const BUILT_IN: PackedStringArray = ["bleep", "low_bleep", "beep_pair", "silence"]
const PREF_SOUNDS: PackedStringArray = ["bleep", "low_bleep", "beep_pair", "silence", "custom"]
const CUTS: PackedStringArray = ["mute", "duck", "fade"]
const CUT_LABELS: Dictionary = {"mute": "Mute at once", "duck": "Duck", "fade": "Fade out and back in"}
const FITS: PackedStringArray = ["cut", "loop", "once"]
const FIT_LABELS: Dictionary = {"cut": "Cut to the censor", "loop": "Loop to fill the censor", "once": "Play once"}
const SNAP_FROM_CLIP := "clip"
const SNAP_FROM_TRACKS := 16
const SNAP_FROM_CLIP_LABEL := "The clip you censor"
const SETTING_KEYS: PackedStringArray = ["sound", "volume_db", "cut", "duck_db", "fade_ms", "fit"]
const PREF_SOUND := "censor.sound"
const PREF_CUSTOM := "censor.custom_path"
const PREF_VOLUME := "censor.volume_db"
const PREF_CUT := "censor.cut"
const PREF_DUCK := "censor.duck_db"
const PREF_FADE := "censor.fade_ms"
const PREF_FIT := "censor.fit"
const PREF_SNAP_TIMELINE := "censor.snap_timeline"
const PREF_SNAP_SOUND := "censor.snap_sound"
const PREF_SNAP_FROM := "censor.snap_sound_from"
const PREF_OVERLAP := "censor.overlap"
const VOLUME_MIN := -40.0
const VOLUME_MAX := 12.0
const DUCK_MIN := 3.0
const DUCK_MAX := 60.0
const FADE_MIN := 5.0
const FADE_MAX := 2000.0
const HARD: Dictionary = {"sound": "bleep", "volume_db": 0.0, "cut": "mute", "duck_db": 18.0, "fade_ms": 60.0, "fit": "cut"}
const SILENT_DB := -80.0
const EDGE_LEAD := 0.006
const EDGE_STEP := 0.001
const SOUND_EDGE := 0.005
const MIN_SPAN := 0.02
const TOUCH := 0.0005
const CHAIN_GAP := 0.000000001
const MAX_PIECES := 400
const FADE_STEPS: Array = [0.0, 0.25, 0.5, 0.75, 0.9, 1.0]
const GAIN_UID := "_censor"
const ENTRY_PREFIX := "censor_"
const TRACK_SUFFIX := "_censor_"
const PEAK_RATE := 100.0
const QUIET_REACH := 0.3
const QUIET_SHARE := 0.15
const QUIET_FLOOR := 3
const QUIET_MIN_TOP := 8
const QUIET_GAP := 3
const QUIET_PAD := 0.015
const BASE_MEDIA := "media"
const AUDIO_OPS_PATH := "res://modules/core_panels/audio_ops.gd"
const JOIN_BEFORE := "|before"
const JOIN_AFTER := "|after"
const JOIN_EPS := 0.0001

static var _paths: Dictionary = {}


static func pref_specs() -> Array:
	return [
		[PREF_SOUND, "bleep", {"label": "Sound for new censors", "type": "enum", "choices": Array(PREF_SOUNDS)}],
		[PREF_CUSTOM, "", {"label": "Custom censor sound file", "type": "string"}],
		[PREF_VOLUME, 0.0, {"label": "Censor sound volume (dB)", "type": "float", "min": VOLUME_MIN, "max": VOLUME_MAX}],
		[PREF_CUT, "mute", {"label": "How the words are cut", "type": "enum", "choices": Array(CUTS)}],
		[PREF_DUCK, 18.0, {"label": "Duck by (dB)", "type": "float", "min": DUCK_MIN, "max": DUCK_MAX}],
		[PREF_FADE, 60.0, {"label": "Fade out and back in over (ms)", "type": "float", "min": FADE_MIN, "max": FADE_MAX}],
		[PREF_FIT, "cut", {"label": "Fit the sound to the censor", "type": "enum", "choices": Array(FITS)}],
		[PREF_SNAP_TIMELINE, true, {"label": "Censor edges snap to the timeline (edits, markers, playhead, view changes, frames)", "type": "bool"}],
		[PREF_SNAP_SOUND, false, {"label": "Censor edges snap to the sound (quiet gaps around a word)", "type": "bool"}],
		[PREF_SNAP_FROM, SNAP_FROM_CLIP, {"label": "Sound the censor edges snap to (Clip is the clip you censor)", "type": "enum", "choices": Array(snap_from_choices())}],
		[PREF_OVERLAP, false, {"label": "Censors may overlap", "type": "bool"}],
	]


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var n: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
		if n != null and n.has_method("register"):
			return n
	return null


static func register_prefs() -> void:
	var p: Node = _prefs()
	if p == null:
		return
	for spec: Array in pref_specs():
		if not bool(p.call("is_registered", String(spec[0]))):
			p.call("register", String(spec[0]), spec[1], spec[2])


static func pref(key: String) -> Variant:
	var p: Node = _prefs()
	for spec: Array in pref_specs():
		if String(spec[0]) != key:
			continue
		if p == null:
			return spec[1]
		if not bool(p.call("is_registered", key)):
			p.call("register", key, spec[1], spec[2])
		return p.call("get_value", key)
	return null


static func set_pref(key: String, v: Variant) -> void:
	register_prefs()
	var p: Node = _prefs()
	if p != null:
		p.call("set_value", key, v)


static func pick(v: String, allowed: PackedStringArray, fallback: String) -> String:
	return v if allowed.has(v) else fallback


static func snap_from_choices() -> PackedStringArray:
	var out: PackedStringArray = [SNAP_FROM_CLIP]
	for i: int in SNAP_FROM_TRACKS:
		out.append("A" + str(i + 1))
	return out


static func snaps_timeline() -> bool:
	return bool(pref(PREF_SNAP_TIMELINE))


static func snaps_sound() -> bool:
	return bool(pref(PREF_SNAP_SOUND))


static func snap_from() -> String:
	return pick(String(pref(PREF_SNAP_FROM)), snap_from_choices(), SNAP_FROM_CLIP)


static func snap_track(seq: Sequence, from: String) -> Track:
	if seq == null or not from.begins_with("A") or not from.substr(1).is_valid_int():
		return null
	var i: int = int(from.substr(1)) - 1
	return seq.audio_tracks[i] if i >= 0 and i < seq.audio_tracks.size() else null


static func snap_from_label(seq: Sequence, from: String) -> String:
	if from == SNAP_FROM_CLIP:
		return SNAP_FROM_CLIP_LABEL
	var tr: Track = snap_track(seq, from)
	if tr == null:
		return from
	var shown: String = seq.display_label(tr)
	return from if shown == from or shown.is_empty() else from + " " + shown


static func overlap_allowed() -> bool:
	return bool(pref(PREF_OVERLAP))


static func custom_sound(doc: Project, path: String) -> String:
	if path.is_empty():
		return "bleep"
	if path.begins_with("media:"):
		if doc != null and doc.media_by_id(path.substr(6)) != null:
			return path
		return "bleep"
	if doc != null:
		for m: MediaItem in doc.media:
			if m.path == path and (m.kind == "audio" or m.has_audio):
				return "media:" + m.id
	return "file:" + path


static func new_settings(doc: Project) -> Dictionary:
	var sound: String = String(pref(PREF_SOUND))
	if sound == "custom":
		sound = custom_sound(doc, String(pref(PREF_CUSTOM)))
	return normalised_settings({
		"sound": sound,
		"volume_db": float(pref(PREF_VOLUME)),
		"cut": String(pref(PREF_CUT)),
		"duck_db": float(pref(PREF_DUCK)),
		"fade_ms": float(pref(PREF_FADE)),
		"fit": String(pref(PREF_FIT)),
	})


static func valid_sound(sound: String) -> bool:
	return BUILT_IN.has(sound) or (sound.begins_with("media:") and sound.length() > 6) or (sound.begins_with("file:") and sound.length() > 5)


static func normalised_settings(d: Dictionary) -> Dictionary:
	var sound: String = String(d.get("sound", HARD["sound"]))
	return {
		"sound": sound if valid_sound(sound) else String(HARD["sound"]),
		"volume_db": clampf(float(d.get("volume_db", HARD["volume_db"])), VOLUME_MIN, VOLUME_MAX),
		"cut": pick(String(d.get("cut", HARD["cut"])), CUTS, String(HARD["cut"])),
		"duck_db": clampf(float(d.get("duck_db", HARD["duck_db"])), DUCK_MIN, DUCK_MAX),
		"fade_ms": clampf(float(d.get("fade_ms", HARD["fade_ms"])), FADE_MIN, FADE_MAX),
		"fit": pick(String(d.get("fit", HARD["fit"])), FITS, String(HARD["fit"])),
	}


static func settings_of(r: Dictionary) -> Dictionary:
	return normalised_settings(r)


static func make_region(id: String, from_s: float, to_s: float, settings: Dictionary) -> Dictionary:
	var r: Dictionary = normalised_settings(settings)
	r["id"] = id
	r["from"] = minf(from_s, to_s)
	r["to"] = maxf(from_s, to_s)
	return r


static func with_settings(r: Dictionary, settings: Dictionary) -> Dictionary:
	var out: Dictionary = r.duplicate(true)
	var clean: Dictionary = normalised_settings(settings)
	for k: String in SETTING_KEYS:
		out[k] = clean[k]
	return out


static func regions(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null:
		return out
	var box: Variant = c.audio.get(KEY, null)
	if not (box is Dictionary):
		return out
	var raw: Variant = (box as Dictionary).get("regions", [])
	if raw is Array:
		for r: Variant in raw:
			if r is Dictionary:
				out.append(r)
	return out


static func regions_copy(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in regions(c):
		out.append(r.duplicate(true))
	return out


static func has_regions(c: Clip) -> bool:
	if c == null:
		return false
	var box: Variant = c.audio.get(KEY, null)
	if not (box is Dictionary):
		return false
	var raw: Variant = (box as Dictionary).get("regions", [])
	return raw is Array and not (raw as Array).is_empty()


static func region_by_id(c: Clip, region_id: String) -> Dictionary:
	for r: Dictionary in regions(c):
		if String(r.get("id", "")) == region_id:
			return r
	return {}


static func write(c: Clip, list: Array) -> void:
	write_based(c, list, base_of(c))


static func write_based(c: Clip, list: Array, base: String) -> void:
	if c == null:
		return
	if list.is_empty():
		c.audio.erase(KEY)
		return
	var clean: Array = []
	for r: Variant in list:
		if r is Dictionary:
			clean.append((r as Dictionary).duplicate(true))
	var box: Dictionary = {"regions": clean}
	if base == BASE_MEDIA:
		box["base"] = BASE_MEDIA
	c.audio[KEY] = box


static func base_of(c: Clip) -> String:
	if c == null:
		return BASE_MEDIA
	var box: Variant = c.audio.get(KEY, null)
	if box is Dictionary:
		return String((box as Dictionary).get("base", ""))
	return BASE_MEDIA


static func audio_edits(c: Clip) -> Array:
	if c == null:
		return []
	var raw: Variant = c.audio.get("edits", [])
	return raw if raw is Array else []


static func edit_step(e: Dictionary) -> Dictionary:
	var op_id: String = String(e.get("op", ""))
	var mode: String = ""
	var factor: float = 1.0
	var ops: GDScript = load(AUDIO_OPS_PATH) if ResourceLoader.exists(AUDIO_OPS_PATH) else null
	if ops != null:
		var o: Dictionary = ops.call("op", op_id)
		mode = String(o.get("duration", ""))
		if mode == "tempo" or mode == "speed":
			factor = float(ops.call("duration_factor", op_id, e.get("params", {})))
	if op_id == "reverse":
		mode = "reverse"
	var b: float = float(e.get("to", -1.0))
	return {"mode": mode, "a": float(e.get("from", 0.0)), "b": b if b >= 0.0 else INF, "factor": factor}


static func through_edit(t: float, step: Dictionary, forward: bool) -> float:
	var mode: String = String(step["mode"])
	var a: float = float(step["a"])
	var b: float = float(step["b"])
	if mode == "delete":
		if t < a:
			return t
		if forward:
			return a if t < b else t - (b - a)
		return t + (b - a)
	if mode == "keep":
		return clampf(t - a, 0.0, b - a) if forward else t + a
	if mode == "tempo" or mode == "speed":
		var f: float = maxf(float(step["factor"]), 0.000001)
		if t < a:
			return t
		if forward:
			return a + (t - a) * f if t <= b else t + (b - a) * (f - 1.0)
		var stretched_end: float = a + (b - a) * f
		return a + (t - a) / f if t <= stretched_end else t - (b - a) * (f - 1.0)
	if mode == "reverse" and b < INF and t >= a and t <= b:
		return a + b - t
	return t


static func render_time(c: Clip, stored: float) -> float:
	if base_of(c) != BASE_MEDIA:
		return stored
	var t: float = stored
	for e: Variant in audio_edits(c):
		if e is Dictionary:
			t = through_edit(t, edit_step(e), true)
	return t


static func stored_time(c: Clip, render_t: float) -> float:
	if base_of(c) != BASE_MEDIA:
		return render_t
	var list: Array = audio_edits(c)
	var t: float = render_t
	for i: int in range(list.size() - 1, -1, -1):
		if list[i] is Dictionary:
			t = through_edit(t, edit_step(list[i]), false)
	return t


static func stored_span(c: Clip, t0: float, t1: float) -> Vector2:
	var src: Vector2 = source_span(c, t0, t1)
	var a: float = stored_time(c, src.x)
	var b: float = stored_time(c, src.y)
	return Vector2(minf(a, b), maxf(a, b))


static func takes_censor(doc: Project, c: Clip) -> bool:
	if c == null or c.is_nest():
		return false
	var m: MediaItem = doc.media_by_id(c.media_id) if doc != null else null
	if m == null:
		return false
	if m.kind == "sequence" or m.kind == "title" or m.kind == "shape" or m.kind == "adjust" or m.kind == "generator":
		return false
	return m.kind == "audio" or m.has_audio


static func timeline_at(c: Clip, s: float) -> float:
	if c.is_speed_static():
		var v: float = c.static_speed()
		if absf(v) < 0.000001:
			return c.start
		return c.start + (s - c.in_offset) / v
	var a: float = c.start
	var b: float = c.end()
	var sa: float = c.source_time(a)
	var sb: float = c.source_time(b)
	if absf(sb - sa) < 0.000001:
		return a
	var rising: bool = sb > sa
	if (rising and s <= sa) or (not rising and s >= sa):
		return a
	if (rising and s >= sb) or (not rising and s <= sb):
		return b
	var lo: float = a
	var hi: float = b
	for i: int in 48:
		var mid: float = (lo + hi) * 0.5
		var sm: float = c.source_time(mid)
		if (sm < s) == rising:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


static func full_range(c: Clip, r: Dictionary) -> PackedFloat64Array:
	var a: float = timeline_at(c, render_time(c, float(r.get("from", 0.0))))
	var b: float = timeline_at(c, render_time(c, float(r.get("to", 0.0))))
	return PackedFloat64Array([minf(a, b), maxf(a, b)])


static func span(c: Clip, r: Dictionary) -> Vector2:
	var full: PackedFloat64Array = full_range(c, r)
	var lo: float = maxf(full[0], c.start)
	var hi: float = minf(full[1], c.end())
	if hi <= lo:
		return Vector2(lo, lo)
	return Vector2(lo, hi)


static func shape_range(c: Clip, r: Dictionary) -> PackedFloat64Array:
	var sp: Vector2 = span(c, r)
	var full: PackedFloat64Array = full_range(c, r)
	var a: float = sp.x if full[0] >= c.start - TOUCH else full[0]
	var b: float = sp.y if full[1] <= c.end() + TOUCH else full[1]
	return PackedFloat64Array([a, b])


static func shows(c: Clip, r: Dictionary) -> bool:
	var sp: Vector2 = span(c, r)
	return sp.y - sp.x > TOUCH


static func source_span(c: Clip, t0: float, t1: float) -> Vector2:
	var a: float = c.source_time(clampf(minf(t0, t1), c.start, c.end()))
	var b: float = c.source_time(clampf(maxf(t0, t1), c.start, c.end()))
	return Vector2(minf(a, b), maxf(a, b))


static func _sorted(list: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = list.duplicate()
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.get("from", 0.0)) < float(y.get("from", 0.0)))
	return out


static func _touches(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("to", 0.0)) >= float(b.get("from", 0.0)) - TOUCH and float(a.get("from", 0.0)) <= float(b.get("to", 0.0)) + TOUCH


static func _absorb(list: Array[Dictionary], host_index: int) -> Array[Dictionary]:
	var host: Dictionary = list[host_index].duplicate(true)
	var rest: Array[Dictionary] = []
	for i: int in list.size():
		if i != host_index:
			rest.append(list[i])
	var grew: bool = true
	while grew:
		grew = false
		var keep: Array[Dictionary] = []
		for e: Dictionary in rest:
			if _touches(host, e):
				host["from"] = minf(float(host["from"]), float(e.get("from", 0.0)))
				host["to"] = maxf(float(host["to"]), float(e.get("to", 0.0)))
				grew = true
			else:
				keep.append(e)
		rest = keep
	rest.append(host)
	return _sorted(rest)


static func added(list: Array[Dictionary], r: Dictionary, overlap: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in list:
		out.append(e.duplicate(true))
	var fresh: Dictionary = r.duplicate(true)
	if overlap:
		out.append(fresh)
		return _sorted(out)
	var host_index: int = -1
	for i: int in out.size():
		if _touches(out[i], fresh) and (host_index < 0 or float(out[i].get("from", 0.0)) < float(out[host_index].get("from", 0.0))):
			host_index = i
	if host_index < 0:
		out.append(fresh)
		return _sorted(out)
	var host: Dictionary = out[host_index]
	host["from"] = minf(float(host.get("from", 0.0)), float(fresh["from"]))
	host["to"] = maxf(float(host.get("to", 0.0)), float(fresh["to"]))
	return _absorb(out, host_index)


static func resized(list: Array[Dictionary], region_id: String, from_s: float, to_s: float, overlap: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at: int = -1
	for e: Dictionary in list:
		var d: Dictionary = e.duplicate(true)
		if String(d.get("id", "")) == region_id:
			d["from"] = minf(from_s, to_s)
			d["to"] = maxf(from_s, to_s)
			at = out.size()
		out.append(d)
	if at < 0:
		return out
	if overlap:
		return _sorted(out)
	return _absorb(out, at)


static func removed(list: Array[Dictionary], region_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in list:
		if String(e.get("id", "")) != region_id:
			out.append(e.duplicate(true))
	return out


static func restyled(list: Array[Dictionary], region_id: String, settings: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in list:
		if String(e.get("id", "")) == region_id:
			out.append(with_settings(e, settings))
		else:
			out.append(e.duplicate(true))
	return out


static func _amp_db(amp: float) -> float:
	if amp <= 0.0001:
		return SILENT_DB
	return maxf(20.0 * log(amp) / log(10.0), SILENT_DB)


static func shape(r: Dictionary, a: float, b: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cut: String = pick(String(r.get("cut", "mute")), CUTS, "mute")
	if cut == "fade":
		var t_fade: float = minf(clampf(float(r.get("fade_ms", 60.0)), FADE_MIN, FADE_MAX) / 1000.0, (b - a) * 0.5)
		if t_fade <= EDGE_STEP:
			cut = "mute"
		else:
			for u: float in FADE_STEPS:
				pts.append(Vector2(a + u * t_fade, _amp_db(1.0 - u)))
			for i: int in range(FADE_STEPS.size() - 1, -1, -1):
				var u2: float = float(FADE_STEPS[i])
				pts.append(Vector2(b - u2 * t_fade, _amp_db(1.0 - u2)))
			return pts
	var level: float = SILENT_DB if cut == "mute" else -clampf(float(r.get("duck_db", 18.0)), DUCK_MIN, DUCK_MAX)
	pts.append(Vector2(a - EDGE_LEAD - EDGE_STEP, 0.0))
	pts.append(Vector2(a - EDGE_LEAD, level))
	pts.append(Vector2(b, level))
	pts.append(Vector2(b + EDGE_STEP, 0.0))
	return pts


static func shape_at(pts: PackedVector2Array, t: float) -> float:
	if pts.is_empty() or t <= pts[0].x or t >= pts[pts.size() - 1].x:
		return 0.0
	for i: int in range(1, pts.size()):
		var p1: Vector2 = pts[i]
		if t <= p1.x:
			var p0: Vector2 = pts[i - 1]
			var w: float = p1.x - p0.x
			if w <= 0.0:
				return p1.y
			return lerpf(p0.y, p1.y, (t - p0.x) / w)
	return 0.0


static func envelope(c: Clip) -> Dictionary:
	var shapes: Array[PackedVector2Array] = []
	for r: Dictionary in regions(c):
		var sp: Vector2 = span(c, r)
		if sp.y - sp.x <= TOUCH:
			continue
		var reach: PackedFloat64Array = shape_range(c, r)
		shapes.append(shape(r, reach[0] - c.start, reach[1] - c.start))
	if shapes.is_empty():
		return {}
	var times: Array[float] = []
	for pts: PackedVector2Array in shapes:
		for p: Vector2 in pts:
			times.append(maxf(p.x, 0.0))
	times.sort()
	var keys: Array = []
	var last: float = -INF
	for t: float in times:
		if t - last < AnimProp.KEY_TOLERANCE * 1.5:
			continue
		last = t
		var db: float = 0.0
		for pts2: PackedVector2Array in shapes:
			db = minf(db, shape_at(pts2, t))
		keys.append({"t": t, "v": db, "i": "linear"})
	var prop: Dictionary = AnimProp.set_key(AnimProp.make(0.0), float(keys[0]["t"]), float(keys[0]["v"]), "linear")
	var layer: Dictionary = (prop["layers"] as Array)[AnimProp.keys_layer_index(prop)]
	layer["keys"] = keys
	return prop


static func gain_effects(c: Clip) -> Array:
	var env: Dictionary = envelope(c)
	if env.is_empty():
		return []
	return [{"id": "gain", "uid": c.id + GAIN_UID, "enabled": true, "params": {"db": env}}]


static func prepend_gain(c: Clip, effects: Array) -> Array:
	if not has_regions(c):
		return effects
	var out: Array = gain_effects(c)
	out.append_array(effects)
	return out


static func builtin_path(kind: String) -> String:
	if _paths.has(kind):
		return String(_paths[kind])
	var spec: Dictionary = SOUNDS.get(kind, {})
	var file: String = String(spec.get("file", ""))
	if file.is_empty():
		return ""
	var res: String = RES_DIR + file
	var direct: String = ProjectSettings.globalize_path(res)
	var out: String = ""
	if FileAccess.file_exists(direct):
		out = direct
	else:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(res)
		if bytes.is_empty():
			return ""
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_DIR))
		var target: String = ProjectSettings.globalize_path(USER_DIR + file)
		if FileAccess.get_file_as_bytes(target).size() != bytes.size():
			var f: FileAccess = FileAccess.open(target, FileAccess.WRITE)
			if f == null:
				return ""
			f.store_buffer(bytes)
			f.close()
		out = target
	_paths[kind] = out
	return out


static func wav_length(path: String) -> float:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 44:
		return -1.0
	if f.get_buffer(4).get_string_from_ascii() != "RIFF":
		return -1.0
	f.get_32()
	if f.get_buffer(4).get_string_from_ascii() != "WAVE":
		return -1.0
	var byte_rate: int = 0
	while f.get_position() + 8 <= f.get_length():
		var id: String = f.get_buffer(4).get_string_from_ascii()
		var size: int = f.get_32()
		if id == "fmt ":
			var start: int = f.get_position()
			f.get_16()
			f.get_16()
			f.get_32()
			byte_rate = f.get_32()
			f.seek(start + size + (size % 2))
		elif id == "data":
			if byte_rate <= 0:
				return -1.0
			return float(size) / float(byte_rate)
		else:
			f.seek(f.get_position() + size + (size % 2))
	return -1.0


static func sound_source(doc: Project, sound: String, handles: Dictionary) -> Dictionary:
	if sound.is_empty() or sound == "silence":
		return {}
	if SOUNDS.has(sound):
		var path: String = builtin_path(sound)
		if path.is_empty():
			return {}
		return {"path": path, "media": -1, "stream": 0, "length": float(SOUNDS[sound]["length"]), "endless": bool(SOUNDS[sound]["endless"])}
	if sound.begins_with("media:"):
		var m: MediaItem = doc.media_by_id(sound.substr(6)) if doc != null else null
		if m == null or m.path.is_empty() or not (m.kind == "audio" or m.has_audio):
			return {}
		var h: int = int(handles.get(m.id, m.handle))
		var stream: int = 0
		return {"path": m.path, "media": h, "stream": stream, "length": m.duration, "endless": false}
	if sound.begins_with("file:"):
		var p: String = sound.substr(5)
		if not FileAccess.file_exists(p):
			return {}
		return {"path": p, "media": -1, "stream": 0, "length": wav_length(p) if p.get_extension().to_lower() == "wav" else -1.0, "endless": false}
	return {}


static func sound_label(doc: Project, sound: String) -> String:
	if SOUNDS.has(sound):
		return String(SOUNDS[sound]["label"])
	if sound.begins_with("media:"):
		var m: MediaItem = doc.media_by_id(sound.substr(6)) if doc != null else null
		return m.label if m != null else "Missing sound"
	if sound.begins_with("file:"):
		return sound.substr(5).get_file()
	return "Bleep 1 kHz"


static func tag_text(doc: Project, r: Dictionary) -> String:
	var sound: String = String(r.get("sound", "bleep"))
	var text: String = String(SOUNDS[sound]["tag"]) if SOUNDS.has(sound) else sound_label(doc, sound)
	var cut: String = String(r.get("cut", "mute"))
	if cut == "duck":
		text += ", duck " + str(int(round(float(r.get("duck_db", 18.0))))) + " dB"
	elif cut == "fade":
		text += ", fade"
	return text


static func _piece(id: String, src: Dictionary, start: float, dur: float, gain: float, fade_in: float, fade_out: float, muted: bool) -> Dictionary:
	return {
		"id": id,
		"media": int(src.get("media", -1)),
		"path": String(src.get("path", "")),
		"stream": int(src.get("stream", 0)),
		"start": start,
		"duration": dur,
		"in_offset": 0.0,
		"speed": AnimProp.make(1.0),
		"reversed": false,
		"keep_pitch": false,
		"volume": AnimProp.make(gain),
		"pan": AnimProp.make(0.0),
		"fade_in": fade_in,
		"fade_out": fade_out,
		"fade_shape": 0.0,
		"muted": muted,
		"effects": [],
	}


static func sound_entries(doc: Project, c: Clip, handles: Dictionary, joins: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in regions(c):
		var sp: Vector2 = span(c, r)
		var a: float = sp.x
		var b: float = sp.y
		if b - a <= TOUCH:
			continue
		var src: Dictionary = sound_source(doc, String(r.get("sound", "bleep")), handles)
		if src.is_empty():
			continue
		var rid: String = String(r.get("id", ""))
		var joined_before: bool = bool(joins.get(rid + JOIN_BEFORE, false))
		var joined_after: bool = bool(joins.get(rid + JOIN_AFTER, false))
		var lo: float = a
		var hi: float = b
		if joined_before or joined_after:
			var full: PackedFloat64Array = full_range(c, r)
			if joined_before:
				a = full[0]
				lo = c.start
			if joined_after:
				b = full[1]
				hi = c.end()
		var gain: float = db_to_linear(clampf(float(r.get("volume_db", 0.0)), VOLUME_MIN, VOLUME_MAX))
		var length: float = float(src.get("length", -1.0))
		var endless: bool = bool(src.get("endless", false))
		var fit: String = pick(String(r.get("fit", "cut")), FITS, "cut")
		var starts: Array[float] = []
		var ends: Array[float] = []
		if length > 0.01 and (endless or fit == "loop"):
			var t: float = a
			var k: int = 0
			while t < b - TOUCH and k < MAX_PIECES:
				starts.append(t)
				k += 1
				t = a + float(k) * length
				ends.append(minf(t, b))
		elif fit == "once" and length > 0.01:
			starts.append(a)
			ends.append(a + length)
		else:
			starts.append(a)
			ends.append(b if length <= 0.01 else minf(b, a + length))
		var base: String = ENTRY_PREFIX + c.id + "_" + rid
		var n: int = starts.size()
		for i: int in n:
			var first: bool = i == 0
			var final: bool = i == n - 1
			var dur: float = ends[i] - starts[i]
			if not final:
				dur = starts[i + 1] - starts[i] - CHAIN_GAP
			var p0: float = starts[i]
			var head_cut: bool = joined_before and p0 < lo - TOUCH * 0.01
			var tail_cut: bool = joined_after and p0 + dur > hi + TOUCH * 0.01
			if head_cut:
				dur -= lo - p0
				p0 = lo
			if tail_cut:
				dur = hi - CHAIN_GAP - p0
			var fin: float = SOUND_EDGE if (first or not endless) and not head_cut else 0.0
			var fout: float = SOUND_EDGE if (final or not endless) and not tail_cut else 0.0
			if dur <= 0.0:
				continue
			var piece: Dictionary = _piece(base + "_" + str(i), src, p0, dur, gain, minf(fin, dur * 0.5), minf(fout, dur * 0.5), not c.enabled)
			if head_cut:
				piece["in_offset"] = p0 - starts[i]
			out.append(piece)
	return out


static func censored_clips(tr: Track) -> Array[Clip]:
	var out: Array[Clip] = []
	for c: Clip in tr.clips:
		if has_regions(c) and tr.is_sound(c):
			out.append(c)
	return out


static func joins_on(track_clips: Array[Clip]) -> Dictionary:
	var out: Dictionary = {}
	for i: int in track_clips.size():
		var left: Clip = track_clips[i]
		for j: int in range(i + 1, track_clips.size()):
			var right: Clip = track_clips[j]
			if right.start > left.end() + JOIN_EPS:
				break
			if absf(right.start - left.end()) > JOIN_EPS or right.enabled != left.enabled:
				continue
			for r: Dictionary in regions(left):
				var rid: String = String(r.get("id", ""))
				var other: Dictionary = region_by_id(right, rid)
				if other.is_empty() or settings_of(other) != settings_of(r):
					continue
				var lf: PackedFloat64Array = full_range(left, r)
				var rf: PackedFloat64Array = full_range(right, other)
				if lf[1] <= left.end() + TOUCH or rf[0] >= right.start - TOUCH:
					continue
				if absf(lf[0] - rf[0]) > JOIN_EPS * 10.0 or absf(lf[1] - rf[1]) > JOIN_EPS * 10.0:
					continue
				if not out.has(left.id):
					out[left.id] = {}
				if not out.has(right.id):
					out[right.id] = {}
				(out[left.id] as Dictionary)[rid + JOIN_AFTER] = true
				(out[right.id] as Dictionary)[rid + JOIN_BEFORE] = true
	return out


static func sound_tracks(doc: Project, seq: Sequence, handles: Dictionary) -> Array:
	var out: Array = []
	if doc == null or seq == null:
		return out
	for tr: Track in seq.all_tracks():
		var lanes: Array = []
		var lane_end: Array[float] = []
		var joins: Dictionary = joins_on(censored_clips(tr))
		for c: Clip in tr.clips:
			if not has_regions(c) or (tr.has_method("is_sound") and not bool(tr.call("is_sound", c))):
				continue
			for e: Dictionary in sound_entries(doc, c, handles, joins.get(c.id, {})):
				var s0: float = float(e["start"])
				var placed: int = -1
				for i: int in lanes.size():
					if lane_end[i] <= s0 + CHAIN_GAP * 2.0:
						placed = i
						break
				if placed < 0:
					lanes.append([])
					lane_end.append(-INF)
					placed = lanes.size() - 1
				(lanes[placed] as Array).append(e)
				lane_end[placed] = s0 + float(e["duration"])
		for i: int in lanes.size():
			out.append({
				"id": tr.id + TRACK_SUFFIX + str(i),
				"owner": tr.id,
				"muted": tr.muted,
				"solo": tr.solo,
				"volume": tr.volume.duplicate(true),
				"pan": tr.pan.duplicate(true),
				"effects": [],
				"clips": lanes[i],
			})
	return out


static func is_censor_track(track_dict: Dictionary) -> bool:
	return String(track_dict.get("id", "")).contains(TRACK_SUFFIX)


static func level(bytes: PackedByteArray, i: int) -> int:
	var lo: int = bytes[i * 2]
	var hi: int = bytes[i * 2 + 1]
	if lo == 0 and hi == 0:
		return -1
	return maxi(128 - lo, hi - 128)


static func _quiet_run(q: Array[bool], from_i: int, step: int, need: int) -> bool:
	var n: int = 0
	var i: int = from_i
	while i >= 0 and i < q.size() and n < need:
		if not q[i]:
			return false
		n += 1
		i += step
	return n >= need or i < 0 or i >= q.size()


static func quiet_edge(bytes: PackedByteArray, first_bucket: int, rate: float, want: float, side: String) -> float:
	var n: int = bytes.size() / 2
	if n < QUIET_GAP * 2 or rate <= 0.0:
		return want
	var levels: Array[int] = []
	var top: int = 0
	for i: int in n:
		var v: int = level(bytes, i)
		levels.append(v)
		top = maxi(top, v)
	if top < QUIET_MIN_TOP:
		return want
	var thr: int = maxi(QUIET_FLOOR, int(round(float(top) * QUIET_SHARE)))
	var q: Array[bool] = []
	for v2: int in levels:
		q.append(v2 >= 0 and v2 <= thr)
	var at: int = clampi(int(floor(want * rate)) - first_bucket, 0, n - 1)
	if levels[at] < 0:
		return want
	var bucket: float = 1.0 / rate
	if side == "from":
		if q[at]:
			var j: int = at
			while j + 1 < n and q[j + 1]:
				j += 1
			if j + 1 >= n:
				return want
			var onset: float = float(first_bucket + j + 1) * bucket
			return clampf(onset - QUIET_PAD, want, onset)
		var k: int = at
		while k - 1 >= 0 and not (q[k - 1] and _quiet_run(q, k - 1, -1, QUIET_GAP)):
			k -= 1
		if k - 1 < 0:
			return want
		var onset2: float = float(first_bucket + k) * bucket
		return maxf(onset2 - QUIET_PAD, float(first_bucket + k - QUIET_GAP) * bucket)
	if q[at]:
		var j2: int = at
		while j2 - 1 >= 0 and q[j2 - 1]:
			j2 -= 1
		if j2 - 1 < 0:
			return want
		var offset: float = float(first_bucket + j2) * bucket
		return clampf(offset + QUIET_PAD, offset, want)
	var k2: int = at
	while k2 + 1 < n and not (q[k2 + 1] and _quiet_run(q, k2 + 1, 1, QUIET_GAP)):
		k2 += 1
	if k2 + 1 >= n:
		return want
	var offset2: float = float(first_bucket + k2 + 1) * bucket
	return minf(offset2 + QUIET_PAD, float(first_bucket + k2 + 1 + QUIET_GAP) * bucket)


static func quiet_snap(reader: Callable, c: Clip, t: float, side: String) -> float:
	if c == null or not reader.is_valid():
		return t
	var sp: float = absf(c.static_speed()) if c.is_speed_static() else 1.0
	if sp < 0.000001:
		return t
	var src: float = c.source_time(clampf(t, c.start, c.end()))
	var reach: float = QUIET_REACH * sp
	var first: int = maxi(int(floor((src - reach) * PEAK_RATE)), 0)
	var count: int = int(ceil((src + reach) * PEAK_RATE)) - first + 1
	var bytes: Variant = reader.call(first, count)
	if not (bytes is PackedByteArray):
		return t
	var reversed: bool = c.is_speed_static() and c.static_speed() < 0.0
	var src_side: String = side
	if reversed:
		src_side = "to" if side == "from" else "from"
	var snapped: float = quiet_edge(bytes as PackedByteArray, first, PEAK_RATE, src, src_side)
	if absf(snapped - src) < 0.0000001:
		return t
	return clampf(timeline_at(c, snapped), c.start, c.end())

extends RefCounted

const SELF := preload("res://engine/audio_react.gd")
const SoundEnvelopes := preload("res://engine/sound_envelopes.gd")
const ReactShape := preload("res://engine/react_shape.gd")
const ReactFeed := preload("res://engine/react_feed.gd")
const ReactRecord := preload("res://engine/react_record.gd")
const VeryLoud := preload("res://engine/very_loud.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const SOURCE_KEY := "snd_source"
const GROUP := "Sound settings"
const GROUP_BARS := "Bars and smoothing"
const GROUP_LOOK := "Look"
const PREVIEW_CLIP := "preview_clip"
const PREVIEW_LEVEL := 0.8
const KIND_OWN := "own"
const KIND_CLIP := "clip"
const KIND_MEDIA := "media"
const KIND_NONE := "none"
const KIND_MIX := "mix"
const KIND_VIEWS := "views"
const KIND_VIEW := "view"
const BANDS: PackedStringArray = ["Full", "Bass", "Low mid", "High mid", "Treble", "Custom"]
const BAND_CUSTOM := 5
const CURVES: PackedStringArray = ["Linear", "Soft", "Hard", "Very hard", "S curve"]
const MODES: PackedStringArray = ["Level", "Beat"]
const MODE_BEAT := 1
const BEAT_GAP_S := 0.1
const BEAT_AVG_S := 0.25
const BEAT_RISE := 0.08
const REBUILD_MS := 250
const TEXTURES_MAX := 512
const DERIVED_MAX := 256
const WAVE_POINTS := 128
const BAND_COUNTS: PackedInt32Array = [16, 32, 64]
const BAND_COUNT_NAMES: PackedStringArray = ["16", "32", "64"]
const SCALES: PackedStringArray = ["Musical (log)", "Even (linear)", "Hearing (mel)"]
const INTERPS: PackedStringArray = ["Straight lines", "Smooth curve", "Steps"]
const SCALE_LOG := 0
const SCALE_LINEAR := 1
const SCALE_MEL := 2
const INTERP_STRAIGHT := 0
const INTERP_SMOOTH := 1
const INTERP_STEPS := 2
const SETTING_KEYS: PackedStringArray = ["snd_offset", "snd_band", "snd_low", "snd_high", "snd_gain", "snd_threshold", "snd_attack", "snd_release", "snd_curve", "snd_mode", "snd_decay", "snd_liquid"]
const SPECTRUM_KEYS: PackedStringArray = ["snd_bands", "snd_scale", "snd_interp", "snd_spread", "snd_peaks", "snd_peak_hold", "snd_peak_fall"]
const SHAPE_KEYS: PackedStringArray = ["snd_gain", "snd_threshold", "snd_attack", "snd_release", "snd_mode", "snd_decay", "snd_liquid", "snd_peaks", "snd_peak_hold", "snd_peak_fall"]
const ENGINE_KEYS: PackedStringArray = ["snd_hand", "snd_hand_level", "snd_record", "snd_bands", "snd_scale", "snd_interp", "snd_spread", "snd_peaks", "snd_peak_hold", "snd_peak_fall", "look_levels", "look_low_db", "look_high_db", "look_ease_db"]
const HAND_KEY := "snd_hand"
const HAND_LEVEL_KEY := "snd_hand_level"
const RECORD_KEY := "snd_record"
const CACHE_FLOATS := 12000000
const PREFETCH_AHEAD := 2
const BLOCK_MAX := 40000
const LOOK_LOW_DB := -40.0
const LOOK_HIGH_DB := -6.0
const LOOK_EASE_DB := 6.0
const BEATS_MAX := 12
const BEAT_WARM_S := 2.0

static var _derived: Dictionary = {}
static var _textures: Dictionary = {}
static var _parsed: Dictionary = {}
static var _chunks: Dictionary = {}
static var _floats: int = 0
static var _tasks: Dictionary = {}
static var _box: Dictionary = {}
static var _mutex: Mutex = Mutex.new()
static var fills: int = 0
static var chunk_builds: int = 0
static var chunk_hits: int = 0
static var prefetched: int = 0
static var local_builds: int = 0
static var _plant_ignore_offset: bool = false
static var _plant_skip_hand: bool = false
static var _plant_no_ahead: bool = false
static var _ahead_at: Dictionary = {}


static func is_reactive(def: Dictionary) -> bool:
	return def.get("reactive") is Dictionary


static func _f(d: Dictionary, k: String, fallback: float) -> float:
	var v: Variant = d.get(k, fallback)
	if v is bool:
		return 1.0 if v else 0.0
	return float(v) if (v is float or v is int) else fallback


static func wrap_params(own: Variant, defaults: Variant, spec: Variant = {}) -> Array:
	var d: Dictionary = defaults if defaults is Dictionary else {}
	var sp: Dictionary = spec if spec is Dictionary else {}
	var head: Array = [
		{"key": SOURCE_KEY, "label": "Sound", "type": "sound", "default": String(d.get(SOURCE_KEY, "")), "keyable": false},
		{"key": HAND_KEY, "label": "By hand", "type": "bool", "default": bool(d.get(HAND_KEY, false)), "keyable": true},
		{"key": HAND_LEVEL_KEY, "label": "Hand amount", "type": "float", "min": 0.0, "max": 100.0, "step": 0.5, "default": _f(d, HAND_LEVEL_KEY, 100.0), "unit": " %", "keyable": true},
		{"key": RECORD_KEY, "label": "Record while playing", "type": "bool", "default": false, "keyable": false},
	]
	var tail: Array = [
		{"key": "snd_offset", "label": "Offset", "type": "float", "min": -10.0, "max": 10.0, "step": 0.01, "default": _f(d, "snd_offset", 0.0), "unit": " s", "keyable": true, "group": GROUP},
		{"key": "snd_mode", "label": "Follow", "type": "enum", "choices": Array(MODES), "default": int(_f(d, "snd_mode", 0.0)), "keyable": true, "group": GROUP},
		{"key": "snd_band", "label": "Band", "type": "enum", "choices": Array(BANDS), "default": int(_f(d, "snd_band", 0.0)), "keyable": false, "group": GROUP},
		{"key": "snd_low", "label": "Custom low", "type": "float", "min": 20.0, "max": 20000.0, "step": 1.0, "default": _f(d, "snd_low", 80.0), "unit": " Hz", "keyable": false, "group": GROUP},
		{"key": "snd_high", "label": "Custom high", "type": "float", "min": 20.0, "max": 20000.0, "step": 1.0, "default": _f(d, "snd_high", 2000.0), "unit": " Hz", "keyable": false, "group": GROUP},
		{"key": "snd_gain", "label": "Sensitivity", "type": "float", "min": 0.0, "max": 1000.0, "step": 1.0, "default": _f(d, "snd_gain", 100.0), "unit": " %", "keyable": true, "group": GROUP},
		{"key": "snd_threshold", "label": "Threshold", "type": "float", "min": 0.0, "max": 100.0, "step": 0.5, "default": _f(d, "snd_threshold", 5.0), "unit": " %", "keyable": true, "group": GROUP},
		{"key": "snd_attack", "label": "Attack", "type": "float", "min": 0.0, "max": 2000.0, "step": 1.0, "default": _f(d, "snd_attack", 10.0), "unit": " ms", "keyable": true, "group": GROUP},
		{"key": "snd_release", "label": "Release", "type": "float", "min": 0.0, "max": 5000.0, "step": 1.0, "default": _f(d, "snd_release", 200.0), "unit": " ms", "keyable": true, "group": GROUP},
		{"key": "snd_curve", "label": "Response", "type": "enum", "choices": Array(CURVES), "default": int(_f(d, "snd_curve", 0.0)), "keyable": true, "group": GROUP},
		{"key": "snd_decay", "label": "Beat decay", "type": "float", "min": 20.0, "max": 3000.0, "step": 1.0, "default": _f(d, "snd_decay", 300.0), "unit": " ms", "keyable": true, "group": GROUP},
		{"key": "snd_liquid", "label": "Liquid smoothing", "type": "float", "min": 0.0, "max": 100.0, "step": 1.0, "default": _f(d, "snd_liquid", 0.0), "unit": " %", "keyable": true, "group": GROUP},
	]
	if sp.get("spectrum") is Dictionary:
		tail.append_array([
			{"key": "snd_bands", "label": "Slices of sound", "type": "enum", "choices": Array(BAND_COUNT_NAMES), "default": int(_f(d, "snd_bands", 0.0)), "keyable": false, "group": GROUP_BARS},
			{"key": "snd_scale", "label": "Spread of pitches", "type": "enum", "choices": Array(SCALES), "default": int(_f(d, "snd_scale", 0.0)), "keyable": true, "group": GROUP_BARS},
			{"key": "snd_interp", "label": "Between slices", "type": "enum", "choices": Array(INTERPS), "default": int(_f(d, "snd_interp", 0.0)), "keyable": true, "group": GROUP_BARS},
			{"key": "snd_spread", "label": "Smooth across bars", "type": "float", "min": 0.0, "max": 100.0, "step": 1.0, "default": _f(d, "snd_spread", 0.0), "unit": " %", "keyable": true, "group": GROUP_BARS},
			{"key": "snd_peaks", "label": "Peak caps", "type": "bool", "default": bool(d.get("snd_peaks", false)), "keyable": true, "group": GROUP_BARS},
			{"key": "snd_peak_hold", "label": "Peak hold", "type": "float", "min": 0.0, "max": 3000.0, "step": 10.0, "default": _f(d, "snd_peak_hold", 300.0), "unit": " ms", "keyable": true, "group": GROUP_BARS},
			{"key": "snd_peak_fall", "label": "Peak fall speed", "type": "float", "min": 1.0, "max": 500.0, "step": 1.0, "default": _f(d, "snd_peak_fall", 60.0), "unit": " %/s", "keyable": true, "group": GROUP_BARS},
		])
	if bool(sp.get("look", false)):
		tail.append_array(look_params(d))
	var out: Array = head
	if own is Array:
		out.append_array(own as Array)
	out.append_array(tail)
	return out


static func look_params(d: Dictionary) -> Array:
	return [
		{"key": "look_height_mix", "label": "Colour by height", "type": "float", "min": 0.0, "max": 1.0, "step": 0.01, "default": _f(d, "look_height_mix", 0.0), "keyable": true, "group": GROUP_LOOK},
		{"key": "look_height_colour", "label": "Height colour", "type": "color", "default": d.get("look_height_colour", [1.0, 0.85, 0.3, 1.0]), "keyable": true, "group": GROUP_LOOK},
		{"key": "look_levels", "label": "Colour quiet and loud", "type": "bool", "default": bool(d.get("look_levels", false)), "keyable": true, "group": GROUP_LOOK},
		{"key": "look_low_colour", "label": "Quiet colour", "type": "color", "default": d.get("look_low_colour", [0.302, 0.553, 1.0, 0.85]), "keyable": true, "group": GROUP_LOOK},
		{"key": "look_high_colour", "label": "Loud colour", "type": "color", "default": d.get("look_high_colour", [1.0, 0.302, 0.302, 0.85]), "keyable": true, "group": GROUP_LOOK},
		{"key": "look_low_db", "label": "Quiet below", "type": "float", "min": -60.0, "max": 0.0, "step": 0.5, "default": _f(d, "look_low_db", LOOK_LOW_DB), "unit": " dB", "keyable": true, "group": GROUP_LOOK},
		{"key": "look_high_db", "label": "Loud above", "type": "float", "min": -60.0, "max": 0.0, "step": 0.5, "default": _f(d, "look_high_db", LOOK_HIGH_DB), "unit": " dB", "keyable": true, "group": GROUP_LOOK},
		{"key": "look_ease_db", "label": "Blend over", "type": "float", "min": 0.0, "max": 24.0, "step": 0.5, "default": _f(d, "look_ease_db", LOOK_EASE_DB), "unit": " dB", "keyable": true, "group": GROUP_LOOK},
		{"key": "look_glow", "label": "Glow", "type": "float", "min": 0.0, "max": 1.0, "step": 0.01, "default": _f(d, "look_glow", 0.0), "keyable": true, "group": GROUP_LOOK},
		{"key": "look_round", "label": "Rounded ends", "type": "float", "min": 0.0, "max": 1.0, "step": 0.01, "default": _f(d, "look_round", 0.0), "keyable": true, "group": GROUP_LOOK},
	]


static func encode(src: Dictionary) -> String:
	var kind: String = String(src.get("kind", KIND_OWN))
	if kind == KIND_OWN:
		return ""
	if kind == KIND_NONE or kind == KIND_MIX or kind == KIND_VIEWS:
		return JSON.stringify({"kind": kind})
	if kind == KIND_VIEW:
		return JSON.stringify({"kind": KIND_VIEW, "view": int(src.get("view", 0)), "clip": String(src.get("clip", ""))})
	if kind == KIND_CLIP:
		return JSON.stringify({"kind": KIND_CLIP, "clip": String(src.get("clip", ""))})
	if kind == KIND_MEDIA:
		return JSON.stringify({"kind": KIND_MEDIA, "media": String(src.get("media", "")), "stream": int(src.get("stream", 0)), "in": snappedf(float(src.get("in", 0.0)), 0.0001), "out": snappedf(float(src.get("out", -1.0)), 0.0001)})
	return ""


static func parse(text: String) -> Dictionary:
	var hit: Variant = _parsed.get(text, null)
	if hit is Dictionary:
		return hit
	var out: Dictionary = {"kind": KIND_OWN}
	var raw: Variant = JSON.parse_string(text) if not text.strip_edges().is_empty() else null
	if raw is Dictionary:
		var d: Dictionary = raw
		var kind: String = String(d.get("kind", KIND_OWN))
		if kind == KIND_CLIP:
			out = {"kind": KIND_CLIP, "clip": String(d.get("clip", ""))}
		elif kind == KIND_MEDIA:
			out = {"kind": KIND_MEDIA, "media": String(d.get("media", "")), "stream": int(d.get("stream", 0)), "in": float(d.get("in", 0.0)), "out": float(d.get("out", -1.0))}
		elif kind == KIND_NONE or kind == KIND_MIX or kind == KIND_VIEWS:
			out = {"kind": kind}
		elif kind == KIND_VIEW:
			out = {"kind": KIND_VIEW, "view": int(d.get("view", 0)), "clip": String(d.get("clip", ""))}
	if _parsed.size() > 1024:
		_parsed = {}
	_parsed[text] = out
	return out


static func source_from_payload(doc: Object, payload: Dictionary) -> String:
	var kind: String = String(payload.get("kind", ""))
	if kind == "clip":
		var ids: Array = payload.get("ids", [])
		var cid: String = String(ids[0]) if not ids.is_empty() else String(payload.get("id", ""))
		if cid.is_empty():
			return ""
		return encode({"kind": KIND_CLIP, "clip": cid})
	if kind != "media":
		return ""
	var mids: Array = payload.get("ids", [])
	var mid: String = String(mids[0]) if not mids.is_empty() else String(payload.get("id", ""))
	if mid.is_empty():
		return ""
	var a: float = float(payload.get("in", -1.0))
	var b: float = float(payload.get("out", -1.0))
	var stream: int = 0
	if doc != null:
		var m: Object = doc.call("media_by_id", mid)
		if m != null:
			var picked: Array = m.call("selected_streams")
			if not picked.is_empty():
				stream = int(picked[0])
	return encode({"kind": KIND_MEDIA, "media": mid, "stream": stream, "in": maxf(a, 0.0), "out": b if b > maxf(a, 0.0) else -1.0})


static func accepts_payload(payload: Dictionary) -> bool:
	var kind: String = String(payload.get("kind", ""))
	if kind == "clip":
		return not (payload.get("ids", []) as Array).is_empty() or not String(payload.get("id", "")).is_empty()
	if kind == "media":
		return String(payload.get("part", "both")) != "video"
	return false


static func _has_sound(m: Object) -> bool:
	if m == null:
		return false
	if String(m.get("kind")) == "sequence":
		return false
	return bool(m.get("has_audio"))


static func _clip_with_sound(doc: Object, c: Object) -> Object:
	if doc == null or c == null:
		return null
	if _has_sound(doc.call("media_by_id", String(c.get("media_id")))):
		return c
	var link: String = String(c.get("link_id"))
	if link.is_empty():
		return null
	var s: Object = doc.call("sequence_of_clip", String(c.get("id")))
	if s == null:
		return null
	for o: Variant in s.call("all_clips"):
		var oc: Object = o
		if oc != c and String(oc.get("link_id")) == link and _has_sound(doc.call("media_by_id", String(oc.get("media_id")))):
			return oc
	return null


static func resolve(doc: Object, clip: Object, text: String, t: float) -> Dictionary:
	var out: Dictionary = {"ok": false, "path": "", "stream": 0, "at": 0.0, "label": "No sound", "kind": KIND_NONE, "mix": false}
	if doc == null or clip == null:
		return out
	var src: Dictionary = parse(text)
	var kind: String = String(src["kind"])
	out["kind"] = kind
	if kind == KIND_NONE:
		return out
	if ReactFeed.is_mix_kind(kind):
		var seq: Object = doc.call("sequence_of_clip", String(clip.get("id")))
		if seq == null:
			out["label"] = "The clip is not in a sequence"
			return out
		out["ok"] = true
		out["mix"] = true
		out["seq"] = seq
		out["src"] = src
		out["at"] = t
		out["label"] = ReactFeed.label_of(doc, seq, clip, src)
		return out
	if kind == KIND_OWN or kind == KIND_CLIP:
		var c: Object = clip
		if kind == KIND_CLIP:
			c = doc.call("clip_by_id", String(src.get("clip", "")))
			if c == null:
				out["label"] = "The clip is gone"
				return out
		var sc: Object = _clip_with_sound(doc, c)
		if sc == null:
			out["label"] = "No sound in this clip" if kind == KIND_OWN else "That clip has no sound"
			return out
		var m: Object = doc.call("media_by_id", String(sc.get("media_id")))
		out["path"] = String(m.get("path"))
		var aud: Variant = sc.get("audio")
		out["stream"] = int((aud as Dictionary).get("stream", 0.0)) if aud is Dictionary else 0
		out["label"] = ("This clip: " if kind == KIND_OWN else "Clip: ") + (String(sc.get("label")) if not String(sc.get("label")).is_empty() else String(m.get("label")))
		var st: float = float(sc.get("start"))
		var en: float = st + float(sc.get("duration"))
		if t < st or t >= en:
			out["at"] = -1.0
		else:
			out["at"] = float(sc.call("source_time", t))
		out["ok"] = true
		return out
	var mm: Object = doc.call("media_by_id", String(src.get("media", "")))
	if not _has_sound(mm):
		out["label"] = "That media has no sound" if mm != null else "The media is gone"
		return out
	out["path"] = String(mm.get("path"))
	out["stream"] = int(src.get("stream", 0))
	var a: float = maxf(float(src.get("in", 0.0)), 0.0)
	var b: float = float(src.get("out", -1.0))
	var at: float = a + (t - float(clip.get("start")))
	if at < a or (b > a and at > b):
		at = -1.0
	out["at"] = at
	out["label"] = "Media: " + String(mm.get("label")) + (" (" + _clock(a) + " to " + _clock(b) + ")" if b > a else "")
	out["ok"] = true
	return out


static func _clock(s: float) -> String:
	var whole: int = int(floor(maxf(s, 0.0)))
	return "%d:%02d.%d" % [whole / 60, whole % 60, int(floor((s - float(whole)) * 10.0))]


static func label_of(doc: Object, clip: Object, text: String) -> String:
	if doc == null or clip == null:
		return "No sound"
	var r: Dictionary = resolve(doc, clip, text, float(clip.get("start")))
	return String(r["label"])


static func settings_of(values: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in SETTING_KEYS:
		out[k] = _f(values, k, 0.0)
	for k2: String in SPECTRUM_KEYS:
		if values.has(k2):
			out[k2] = _f(values, k2, 0.0)
	return out


static func edges_for(settings: Dictionary) -> PackedFloat64Array:
	var band: int = int(settings.get("snd_band", 0.0))
	return SoundEnvelopes.band_edges(band if band != BAND_CUSTOM else -1, float(settings.get("snd_low", 80.0)), float(settings.get("snd_high", 2000.0)))


static func band_count(values: Dictionary) -> int:
	return BAND_COUNTS[clampi(int(_f(values, "snd_bands", 0.0)), 0, BAND_COUNTS.size() - 1)]


static func curve(x: float, kind: int) -> float:
	var v: float = clampf(x, 0.0, 1.0)
	if kind == 1:
		return sqrt(v)
	if kind == 2:
		return v * v
	if kind == 3:
		return v * v * v
	if kind == 4:
		return v * v * (3.0 - 2.0 * v)
	return v


static func _sig(settings: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for k: String in ["snd_gain", "snd_threshold", "snd_attack", "snd_release", "snd_curve", "snd_mode", "snd_decay"]:
		parts.append(str(snappedf(float(settings.get(k, 0.0)), 0.0001)))
	return ",".join(parts)


static func derived(env: Dictionary, settings: Dictionary, band: int) -> PackedFloat32Array:
	var key: String = String(env["key"]) + "#" + str(band) + "#" + _sig(settings)
	var hit: Variant = _derived.get(key, null)
	var now: int = Time.get_ticks_msec()
	if hit is Dictionary:
		var hd: Dictionary = hit
		if int(hd["serial"]) == int(env["serial"]):
			return hd["arr"]
		if not bool(env["done"]) and now - int(hd["ms"]) < REBUILD_MS:
			return hd["arr"]
	var arr: PackedFloat32Array = compute(env["values"], int(env["bands"]), band, band_reference(env["peaks"], band), settings)
	if _derived.size() >= DERIVED_MAX:
		_derived = {}
	_derived[key] = {"serial": int(env["serial"]), "ms": now, "arr": arr}
	return arr


static func band_reference(peaks: PackedFloat32Array, band: int) -> float:
	return ReactFeed.band_ref(peaks, band)


static func compute(values: PackedFloat32Array, bands: int, band: int, ref: float, settings: Dictionary) -> PackedFloat32Array:
	var n: int = values.size() / maxi(bands, 1)
	var p: Dictionary = ReactShape.params_of(settings)
	p["peaks"] = false
	var arr: PackedFloat32Array = ReactShape.run(values, maxi(bands, 1), 0, band, 1, PackedFloat32Array([ref]), 0, n, 0, p)
	var kind: int = int(settings.get("snd_curve", 0.0))
	for i: int in arr.size():
		arr[i] = curve(arr[i], kind)
	return arr


static func sample(arr: PackedFloat32Array, s: float) -> float:
	var n: int = arr.size()
	if n == 0 or s < 0.0:
		return 0.0
	var pos: float = s * float(SoundEnvelopes.RATE)
	if pos >= float(n):
		return 0.0
	var f: float = pos - 0.5
	var i0: int = int(floor(f))
	var fr: float = f - float(i0)
	var v0: float = arr[clampi(i0, 0, n - 1)]
	var v1: float = arr[clampi(i0 + 1, 0, n - 1)]
	return lerpf(v0, v1, fr)


static func _offset(settings: Dictionary) -> float:
	return 0.0 if _plant_ignore_offset else float(settings.get("snd_offset", 0.0))


static func feed(doc: Object, clip: Object, text: String, edges: PackedFloat64Array, t: float) -> Dictionary:
	var r: Dictionary = resolve(doc, clip, text, t)
	var bands: int = maxi(edges.size() / 2, 1)
	var out: Dictionary = {"ok": false, "at": -1.0, "label": String(r["label"]), "mix": false, "key": "", "n": 0, "done": true, "waiting": PackedStringArray(), "bands": bands}
	if not bool(r["ok"]):
		return out
	out["ok"] = true
	out["at"] = float(r["at"])
	if bool(r["mix"]):
		var pset: Dictionary = ReactFeed.part_set(doc, r["seq"], clip, r["src"], edges)
		var st: Dictionary = ReactFeed.state(pset)
		out["mix"] = true
		out["pset"] = pset
		out["done"] = bool(st["done"])
		out["waiting"] = st["waiting"]
		out["key"] = String(pset["key"]) + ("" if bool(st["done"]) else "@" + str(int(st["serial"])))
		var rk: String = String(out["key"])
		if String(pset.get("refs_key", "")) != rk:
			pset["refs"] = ReactFeed.refs(pset, bands)
			pset["refs_key"] = rk
		out["refs"] = pset["refs"]
		out["n"] = 1 << 30
		out["stride"] = bands
		return out
	var env: Dictionary = SoundEnvelopes.entry(String(r["path"]), int(r["stream"]), edges)
	out["env"] = env
	out["done"] = bool(env["done"])
	if not bool(env["done"]):
		out["waiting"] = PackedStringArray([String(env["key"])])
	out["key"] = String(env["key"]) + ("" if bool(env["done"]) else "@" + str(int(env["serial"])))
	if int(env.get("refs_serial", -1)) != int(env["serial"]) or not env.has("refs"):
		var refs: PackedFloat32Array = PackedFloat32Array()
		var peaks: PackedFloat32Array = env["peaks"]
		refs.resize(int(env["bands"]))
		for b: int in refs.size():
			refs[b] = band_reference(peaks, b)
		env["refs"] = refs
		env["refs_serial"] = int(env["serial"])
	out["refs"] = env["refs"]
	out["n"] = int(env["count"])
	out["stride"] = int(env["bands"])
	out["raw"] = env["values"]
	return out


static func _wait(comp: Node, f: Dictionary) -> void:
	for k: String in f.get("waiting", PackedStringArray()):
		SoundEnvelopes.note_waiting(comp, k)


static func _block(f: Dictionary, band_from: int, band_n: int, start: int, count: int) -> Dictionary:
	if bool(f["mix"]):
		return {"raw": ReactFeed.mix_raw(f["pset"], band_n, start, count), "stride": band_n, "base": start, "from": 0, "refs": (f["refs"] as PackedFloat32Array).slice(0, band_n)}
	return {"raw": f["raw"], "stride": int(f["stride"]), "base": 0, "from": band_from, "refs": (f["refs"] as PackedFloat32Array).slice(band_from, band_from + band_n)}


static func _compute(f: Dictionary, p: Dictionary, band_from: int, band_n: int, from: int, count: int) -> PackedFloat32Array:
	var warm: int = ReactShape.warm_of(p)
	var start: int = maxi(from - warm, 0)
	var blk: Dictionary = _block(f, band_from, band_n, start, from + count - start)
	return ReactShape.run(blk["raw"], int(blk["stride"]), int(blk["base"]), int(blk["from"]), band_n, blk["refs"], from, count, warm, p)


static func _work(key: String, raw: PackedFloat32Array, stride: int, band_from: int, band_n: int, refs: PackedFloat32Array, from: int, count: int, warm: int, p: Dictionary) -> void:
	var arr: PackedFloat32Array = ReactShape.run(raw, stride, 0, band_from, band_n, refs, from, count, warm, p)
	_mutex.lock()
	_box[key] = arr
	_mutex.unlock()


static func _reap() -> void:
	if _tasks.is_empty():
		return
	for k: Variant in _tasks.keys():
		var id: int = int(_tasks[k])
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_tasks.erase(k)
			_take(String(k))


static func _take(key: String) -> bool:
	_mutex.lock()
	var got: Variant = _box.get(key, null)
	_box.erase(key)
	_mutex.unlock()
	if got is PackedFloat32Array:
		_store(key, got)
		return true
	return false


static func _store(key: String, arr: PackedFloat32Array) -> void:
	if _chunks.has(key):
		return
	_chunks[key] = arr
	_floats += arr.size()
	if _floats <= CACHE_FLOATS:
		return
	for k: Variant in _chunks.keys():
		if _floats <= CACHE_FLOATS * 3 / 4:
			break
		_floats -= (_chunks[k] as PackedFloat32Array).size()
		_chunks.erase(k)


static func _chunk_base(f: Dictionary, psig: String, band_from: int, band_n: int) -> String:
	return String(f["key"]) + "#" + str(band_from) + ":" + str(band_n) + "#" + psig


static func _chunk_key(base: String, k: int) -> String:
	return base + "#" + str(k)


static func _mix_work(key: String, plans: Array, band_n: int, start: int, refs: PackedFloat32Array, from: int, count: int, warm: int, p: Dictionary) -> void:
	var raw: PackedFloat32Array = ReactFeed.apply(plans, band_n, from + count - start)
	var arr: PackedFloat32Array = ReactShape.run(raw, band_n, start, 0, band_n, refs, from, count, warm, p)
	_mutex.lock()
	_box[key] = arr
	_mutex.unlock()


static func _prefetch(f: Dictionary, p: Dictionary, base: String, band_from: int, band_n: int, k: int) -> void:
	if not bool(f["done"]):
		return
	var mix: bool = bool(f["mix"])
	if mix and _plant_no_ahead:
		return
	if k * ReactShape.CHUNK >= int(f["n"]):
		return
	var warm: int = ReactShape.warm_of(p)
	if mix and float(k * ReactShape.CHUNK - warm) > float((f["pset"] as Dictionary).get("end", 0.0)) * float(ReactShape.RATE):
		return
	var key: String = _chunk_key(base, k)
	if _chunks.has(key) or _tasks.has(key):
		return
	var refs: PackedFloat32Array = (f["refs"] as PackedFloat32Array).slice(band_from, band_from + band_n)
	var from: int = k * ReactShape.CHUNK
	var task: Callable
	if mix:
		var start: int = maxi(from - warm, 0)
		var plans: Array = ReactFeed.plan(f["pset"], band_n, start, from + ReactShape.CHUNK - start)
		task = Callable(SELF, "_mix_work").bind(key, plans, band_n, start, refs, from, ReactShape.CHUNK, warm, p.duplicate())
	else:
		task = Callable(SELF, "_work").bind(key, f["raw"], int(f["stride"]), band_from, band_n, refs, from, ReactShape.CHUNK, warm, p.duplicate())
	_tasks[key] = WorkerThreadPool.add_task(task, false, "Sound for effects")
	prefetched += 1


static func _ahead(f: Dictionary, p: Dictionary, base: String, band_from: int, band_n: int, k: int) -> void:
	if int(_ahead_at.get(base, -1)) == k:
		return
	if _ahead_at.size() >= DERIVED_MAX:
		_ahead_at = {}
	_ahead_at[base] = k
	for ahead: int in PREFETCH_AHEAD:
		_prefetch(f, p, base, band_from, band_n, k + 1 + ahead)


static func _chunk(f: Dictionary, p: Dictionary, base: String, band_from: int, band_n: int, k: int) -> PackedFloat32Array:
	var key: String = _chunk_key(base, k)
	var hit: Variant = _chunks.get(key, null)
	if hit is PackedFloat32Array:
		chunk_hits += 1
		return hit
	_reap()
	if _tasks.has(key):
		WorkerThreadPool.wait_for_task_completion(int(_tasks[key]))
		_tasks.erase(key)
		_take(key)
	hit = _chunks.get(key, null)
	if hit is PackedFloat32Array:
		chunk_hits += 1
		return hit
	chunk_builds += 1
	var arr: PackedFloat32Array = _compute(f, p, band_from, band_n, k * ReactShape.CHUNK, ReactShape.CHUNK)
	_store(key, arr)
	return arr


static func values_at(f: Dictionary, p: Dictionary, band_from: int, band_n: int, at: float, animated: bool, psig: String = "") -> PackedFloat32Array:
	var with_peaks: bool = bool(p.get("peaks", false))
	var width: int = band_n * (2 if with_peaks else 1)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(width)
	var n: int = int(f.get("n", 0))
	if not bool(f.get("ok", false)) or at < 0.0 or n <= 0:
		return out
	var pos: float = at * float(ReactShape.RATE)
	if pos >= float(n):
		return out
	var f0: float = pos - 0.5
	var i0: int = int(floor(f0))
	var fr: float = f0 - float(i0)
	var a: int = clampi(i0, 0, n - 1)
	var b: int = clampi(i0 + 1, 0, n - 1)
	var arr_a: PackedFloat32Array
	var arr_b: PackedFloat32Array
	var off_a: int = 0
	var off_b: int = 0
	var cnt_a: int = 0
	var cnt_b: int = 0
	if animated:
		local_builds += 1
		arr_a = _compute(f, p, band_from, band_n, a, b - a + 1)
		arr_b = arr_a
		off_a = 0
		off_b = b - a
		cnt_a = b - a + 1
		cnt_b = cnt_a
	else:
		var ps: String = psig if not psig.is_empty() else ReactShape.sig(p)
		var ka: int = a / ReactShape.CHUNK
		var kb: int = b / ReactShape.CHUNK
		var base: String = _chunk_base(f, ps, band_from, band_n)
		arr_a = _chunk(f, p, base, band_from, band_n, ka)
		arr_b = arr_a if kb == ka else _chunk(f, p, base, band_from, band_n, kb)
		_ahead(f, p, base, band_from, band_n, kb)
		off_a = a - ka * ReactShape.CHUNK
		off_b = b - kb * ReactShape.CHUNK
		cnt_a = ReactShape.CHUNK
		cnt_b = ReactShape.CHUNK
	for j: int in band_n:
		out[j] = lerpf(arr_a[off_a * band_n + j], arr_b[off_b * band_n + j], fr)
		if with_peaks:
			out[band_n + j] = lerpf(arr_a[cnt_a * band_n + off_a * band_n + j], arr_b[cnt_b * band_n + off_b * band_n + j], fr)
	return out


static func animated_shape(e: Dictionary) -> bool:
	var params: Variant = e.get("params", null)
	if not (params is Dictionary):
		return false
	for k: String in SHAPE_KEYS:
		var p: Variant = (params as Dictionary).get(k, null)
		if p is Dictionary and AnimProp.is_animated(p):
			return true
	return false


static func hand_level(values: Dictionary) -> float:
	return clampf(_f(values, HAND_LEVEL_KEY, 100.0) / 100.0, 0.0, 1.0)


static func by_hand(values: Dictionary) -> bool:
	return not _plant_skip_hand and _f(values, HAND_KEY, 0.0) > 0.5


static func level_at(doc: Object, clip: Object, values: Dictionary, t: float, comp: Node = null, animated: bool = false) -> float:
	if by_hand(values):
		return hand_level(values)
	return sound_level(doc, clip, values, t, comp, animated)


static func sound_level(doc: Object, clip: Object, values: Dictionary, t: float, comp: Node = null, animated: bool = false) -> float:
	var settings: Dictionary = settings_of(values)
	var f: Dictionary = feed(doc, clip, String(values.get(SOURCE_KEY, "")), edges_for(settings), t - _offset(settings))
	if not bool(f["ok"]) or float(f["at"]) < 0.0:
		return 0.0
	_wait(comp, f)
	var p: Dictionary = ReactShape.params_of(settings)
	p["peaks"] = false
	var v: PackedFloat32Array = values_at(f, p, 0, 1, float(f["at"]), animated)
	return curve(v[0], int(settings.get("snd_curve", 0.0)))


static func wave_at(doc: Object, clip: Object, values: Dictionary, t: float, span: float, points: int, comp: Node = null, animated: bool = false) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(points)
	var settings: Dictionary = settings_of(values)
	var text: String = String(values.get(SOURCE_KEY, ""))
	var edges: PackedFloat64Array = edges_for(settings)
	var f: Dictionary = feed(doc, clip, text, edges, t - _offset(settings))
	if not bool(f["ok"]):
		return out
	_wait(comp, f)
	var p: Dictionary = ReactShape.params_of(settings)
	p["peaks"] = false
	var kind: int = int(settings.get("snd_curve", 0.0))
	var sp: float = maxf(span, 0.05)
	var step: float = sp / float(maxi(points - 1, 1))
	var ats: PackedFloat64Array = PackedFloat64Array()
	ats.resize(points)
	for k: int in points:
		var tk: float = t - sp + float(k) * step
		if bool(f["mix"]):
			ats[k] = tk - _offset(settings)
		else:
			var rk: Dictionary = resolve(doc, clip, text, tk - _offset(settings))
			ats[k] = float(rk["at"]) if bool(rk["ok"]) else -1.0
	if animated:
		return _wave_block(f, p, ats, kind)
	var psig: String = ReactShape.sig(p)
	for k2: int in points:
		out[k2] = curve(values_at(f, p, 0, 1, ats[k2], false, psig)[0], kind)
	return out


static func _wave_block(f: Dictionary, p: Dictionary, ats: PackedFloat64Array, kind: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(ats.size())
	var n: int = int(f["n"])
	var lo: int = 1 << 30
	var hi: int = -1
	for at: float in ats:
		if at < 0.0 or at * float(ReactShape.RATE) >= float(n):
			continue
		var i0: int = int(floor(at * float(ReactShape.RATE) - 0.5))
		lo = mini(lo, clampi(i0, 0, n - 1))
		hi = maxi(hi, clampi(i0 + 1, 0, n - 1))
	if hi < lo or hi - lo > BLOCK_MAX:
		for k: int in ats.size():
			out[k] = curve(values_at(f, p, 0, 1, ats[k], true)[0], kind)
		return out
	local_builds += 1
	var arr: PackedFloat32Array = _compute(f, p, 0, 1, lo, hi - lo + 1)
	for k2: int in ats.size():
		var at2: float = ats[k2]
		if at2 < 0.0 or at2 * float(ReactShape.RATE) >= float(n):
			continue
		var f0: float = at2 * float(ReactShape.RATE) - 0.5
		var i1: int = int(floor(f0))
		var fr: float = f0 - float(i1)
		var a: int = clampi(i1, 0, n - 1) - lo
		var b: int = clampi(i1 + 1, 0, n - 1) - lo
		out[k2] = curve(lerpf(arr[a], arr[b], fr), kind)
	return out


static func spectrum_at(doc: Object, clip: Object, values: Dictionary, t: float, comp: Node = null, animated: bool = false) -> PackedFloat32Array:
	var nb: int = band_count(values)
	var settings: Dictionary = settings_of(values)
	var p: Dictionary = ReactShape.params_of(settings)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(nb * (2 if bool(p["peaks"]) else 1))
	var f: Dictionary = feed(doc, clip, String(values.get(SOURCE_KEY, "")), SoundEnvelopes.spectrum_edges(nb), t - _offset(settings))
	if not bool(f["ok"]) or float(f["at"]) < 0.0:
		return out
	_wait(comp, f)
	var v: PackedFloat32Array = values_at(f, p, 0, nb, float(f["at"]), animated)
	var kind: int = int(settings.get("snd_curve", 0.0))
	for i: int in v.size():
		v[i] = curve(v[i], kind)
	return v


static func beats_at(doc: Object, clip: Object, values: Dictionary, t: float, life: float, comp: Node = null) -> PackedFloat32Array:
	var settings: Dictionary = settings_of(values)
	var out: PackedFloat32Array = PackedFloat32Array()
	var f: Dictionary = feed(doc, clip, String(values.get(SOURCE_KEY, "")), edges_for(settings), t - _offset(settings))
	if not bool(f["ok"]) or float(f["at"]) < 0.0:
		return out
	_wait(comp, f)
	var p: Dictionary = ReactShape.params_of(settings)
	var rate: float = float(ReactShape.RATE)
	var now_i: int = mini(int(floor(float(f["at"]) * rate)), int(f["n"]) - 1)
	var from: int = maxi(now_i - int(ceil(maxf(life, 0.05) * rate)), 0)
	var count: int = now_i - from + 1
	if count <= 0:
		return out
	var warm: int = int(BEAT_WARM_S * rate)
	var start: int = maxi(from - warm, 0)
	var blk: Dictionary = _block(f, 0, 1, start, from + count - start)
	var refs: PackedFloat32Array = blk["refs"]
	var hits: PackedFloat32Array = ReactShape.onsets(blk["raw"], int(blk["stride"]), int(blk["base"]), int(blk["from"]), refs[0] if not refs.is_empty() else 0.0, from, count, warm, p)
	var pairs: int = hits.size() / 2
	var first: int = maxi(pairs - BEATS_MAX, 0)
	for i: int in range(first, pairs):
		var idx: float = hits[i * 2]
		out.append(float(f["at"]) - (idx + 0.5) / rate)
		out.append(hits[i * 2 + 1])
		out.append(fmod(idx * 0.6180339887, 1.0))
		out.append(1.0)
	return out


static func bars_of(levels: PackedFloat32Array, nb: int, nbars: int, scale: int, interp: int, spread: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var n: int = maxi(nbars, 1)
	out.resize(n)
	if nb <= 0 or levels.size() < nb:
		return out
	var lo_hz: float = SoundEnvelopes.SPECTRUM_LOW
	var hi_hz: float = SoundEnvelopes.SPECTRUM_HIGH
	for i: int in n:
		var u0: float = float(i) / float(n)
		var u1: float = float(i + 1) / float(n)
		var uc: float = (float(i) + 0.5) / float(n)
		var x0: float = _band_pos(u0, nb, scale, lo_hz, hi_hz)
		var x1: float = _band_pos(u1, nb, scale, lo_hz, hi_hz)
		var xc: float = _band_pos(uc, nb, scale, lo_hz, hi_hz) - 0.5
		if interp != INTERP_STRAIGHT and x1 - x0 > 1.0:
			out[i] = _band_mean(levels, nb, x0, x1)
		elif interp == INTERP_STEPS:
			out[i] = levels[clampi(int(floor(xc + 0.5)), 0, nb - 1)]
		elif interp == INTERP_SMOOTH:
			out[i] = clampf(_cubic(levels, nb, xc), 0.0, 1.0)
		else:
			var k0: int = int(floor(xc))
			var fr: float = xc - float(k0)
			out[i] = lerpf(levels[clampi(k0, 0, nb - 1)], levels[clampi(k0 + 1, 0, nb - 1)], fr)
	if spread > 0.0:
		out = blur(out, spread / 100.0 * maxf(float(n) / 16.0, 1.0))
	return out


static func _mel(f: float) -> float:
	return 2595.0 * log(1.0 + f / 700.0) / log(10.0)


static func _mel_inv(m: float) -> float:
	return 700.0 * (pow(10.0, m / 2595.0) - 1.0)


static func _band_pos(u: float, nb: int, scale: int, lo_hz: float, hi_hz: float) -> float:
	if scale == SCALE_LOG:
		return u * float(nb)
	var hz: float = lerpf(lo_hz, hi_hz, u) if scale == SCALE_LINEAR else _mel_inv(lerpf(_mel(lo_hz), _mel(hi_hz), u))
	return float(nb) * log(maxf(hz, lo_hz) / lo_hz) / log(hi_hz / lo_hz)


static func _band_mean(levels: PackedFloat32Array, nb: int, x0: float, x1: float) -> float:
	var sum: float = 0.0
	var wsum: float = 0.0
	var k: int = int(floor(x0))
	while float(k) < x1 and k < nb:
		var a: float = maxf(x0, float(k))
		var b: float = minf(x1, float(k + 1))
		if b > a and k >= 0:
			sum += levels[k] * (b - a)
			wsum += b - a
		k += 1
	return sum / wsum if wsum > 0.0 else 0.0


static func _cubic(levels: PackedFloat32Array, nb: int, x: float) -> float:
	var k: int = int(floor(x))
	var t: float = x - float(k)
	var p0: float = levels[clampi(k - 1, 0, nb - 1)]
	var p1: float = levels[clampi(k, 0, nb - 1)]
	var p2: float = levels[clampi(k + 1, 0, nb - 1)]
	var p3: float = levels[clampi(k + 2, 0, nb - 1)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


static func blur(vals: PackedFloat32Array, sigma: float) -> PackedFloat32Array:
	if sigma <= 0.01 or vals.size() < 2:
		return vals
	var n: int = vals.size()
	var reach: int = mini(int(ceil(sigma * 3.0)), n)
	var weights: PackedFloat32Array = PackedFloat32Array()
	weights.resize(reach * 2 + 1)
	for i: int in weights.size():
		var d: float = float(i - reach)
		weights[i] = exp(-0.5 * d * d / (sigma * sigma))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i2: int in n:
		var s: float = 0.0
		var w: float = 0.0
		for j: int in weights.size():
			var at: int = i2 + j - reach
			if at < 0 or at >= n:
				continue
			s += vals[at] * weights[j]
			w += weights[j]
		out[i2] = s / w if w > 0.0 else vals[i2]
	return out


static func look_of(values: Dictionary) -> Dictionary:
	var on: bool = _f(values, "look_levels", 0.0) > 0.5
	var ease: float = _f(values, "look_ease_db", LOOK_EASE_DB)
	return {"lows": on, "highs": on, "low_db": _f(values, "look_low_db", LOOK_LOW_DB), "high_db": _f(values, "look_high_db", LOOK_HIGH_DB), "ease": ease > 0.0001, "ease_db": ease, "loud": false}


static func _ease01(f: float) -> float:
	var u: float = clampf(f, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func look_weights(db: float, look: Dictionary) -> Vector2:
	var ease_on: bool = bool(look.get("ease", true))
	var ease_db: float = float(look.get("ease_db", LOOK_EASE_DB))
	var w := Vector2.ZERO
	var low: float = float(look.get("low_db", LOOK_LOW_DB))
	var high: float = float(look.get("high_db", LOOK_HIGH_DB))
	if bool(look.get("lows", false)):
		if not ease_on or ease_db <= 0.0001:
			w.x = 1.0 if db <= low else 0.0
		else:
			w.x = _ease01(((low + ease_db) - db) / ease_db)
	if bool(look.get("highs", false)):
		if not ease_on or ease_db <= 0.0001:
			w.y = 1.0 if db >= high else 0.0
		else:
			w.y = _ease01((db - (high - ease_db)) / ease_db)
	return w


static func pack(vals: PackedFloat32Array, peaks: PackedFloat32Array, look: Dictionary) -> PackedFloat32Array:
	var n: int = vals.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(maxi(n, 1) * 4)
	var tint: bool = bool(look.get("lows", false)) or bool(look.get("highs", false))
	for i: int in n:
		var v: float = vals[i]
		out[i * 4] = v
		out[i * 4 + 1] = peaks[i] if i < peaks.size() else v
		if tint:
			var w: Vector2 = look_weights(VeryLoud.lin_to_db(v), look)
			out[i * 4 + 2] = w.x
			out[i * 4 + 3] = w.y
	return out


static func preview_wave(points: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(points)
	for k: int in points:
		var x: float = float(k) / float(maxi(points - 1, 1))
		out[k] = clampf(0.25 + 0.55 * absf(sin(x * 19.0)) * (0.5 + 0.5 * sin(x * 5.0 + 1.0)), 0.0, 1.0)
	return out


static func preview_spectrum(nb: int = SoundEnvelopes.SPECTRUM_BANDS) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(nb)
	for b: int in nb:
		var x: float = float(b) / float(maxi(nb - 1, 1))
		out[b] = clampf(0.9 - 0.6 * x + 0.15 * sin(x * 13.0), 0.05, 1.0)
	return out


static func preview_beats() -> PackedFloat32Array:
	return PackedFloat32Array([0.15, 0.9, 0.3, 1.0, 0.6, 0.7, 0.7, 1.0])


static func _mix(rest: Variant, peak: Variant, level: float) -> Variant:
	if rest is Array or peak is Array:
		var ra: Array = rest if rest is Array else []
		var pa: Array = peak if peak is Array else []
		var n: int = maxi(ra.size(), pa.size())
		var out: Array = []
		for i: int in n:
			var a: float = float(ra[i]) if i < ra.size() else (float(rest) if (rest is float or rest is int) else 0.0)
			var b: float = float(pa[i]) if i < pa.size() else (float(peak) if (peak is float or peak is int) else 0.0)
			out.append(lerpf(a, b, level))
		return out
	return lerpf(float(rest), float(peak), level)


static func _value(values: Dictionary, v: Variant) -> Variant:
	if v is String:
		var raw: Variant = values.get(String(v), 0.0)
		if raw is bool:
			return 1.0 if raw else 0.0
		return raw
	return v


static func drive_value(values: Dictionary, d: Dictionary, level: float) -> Variant:
	var mixed: Variant = _mix(_value(values, d.get("rest", 0.0)), _value(values, d.get("peak", 1.0)), level)
	var k: float = float(_value(values, d.get("scale", 1.0))) * float(d.get("mul", 1.0))
	var add: float = float(d.get("add", 0.0))
	if mixed is Array:
		var out: Array = []
		for c: Variant in mixed:
			out.append(float(c) * k + add)
		return out
	return float(mixed) * k + add


static func hand_from(e: Dictionary, clip: Object, t: float) -> float:
	var start: float = float(clip.get("start")) if clip != null else 0.0
	var params: Variant = e.get("params", null)
	var p: Variant = (params as Dictionary).get(HAND_KEY, null) if params is Dictionary else null
	if not (p is Dictionary) or not AnimProp.is_animated(p):
		return start
	var local: float = t - start
	var found: float = 0.0
	var prev: bool = false
	var first: bool = true
	for k: Dictionary in AnimProp.keys(p):
		var kt: float = float(k.get("t", 0.0))
		if kt > local + 0.000001:
			break
		var on: bool = _f(k, "v", 0.0) > 0.5
		if on and (first or not prev):
			found = kt
		prev = on
		first = false
	return start + found


static func fill(values: Dictionary, def: Dictionary, e: Dictionary, layer: Node, t: float) -> void:
	var spec: Dictionary = def.get("reactive", {})
	if spec.is_empty() or layer == null:
		return
	fills += 1
	var clip: Object = layer.get("clip")
	var comp: Node = layer.call("_owner_comp") if layer.has_method("_owner_comp") else null
	var doc: Object = comp.get("doc") if comp != null else null
	var preview: bool = clip != null and String(clip.get("id")) == PREVIEW_CLIP
	var animated: bool = animated_shape(e)
	var hand: bool = by_hand(values)
	var hand_k: float = hand_level(values)
	var look_t: float = hand_from(e, clip, t) if hand else t
	var level: float = PREVIEW_LEVEL if preview else level_at(doc, clip, values, t, comp, animated)
	if not preview and _f(values, RECORD_KEY, 0.0) > 0.5 and comp != null and bool(comp.get("playing")) and clip != null:
		ReactRecord.note(doc, clip, String(e.get("uid", "")), t, sound_level(doc, clip, values, t, comp, animated))
	var drive: Dictionary = spec.get("drive", {})
	for target: Variant in drive.keys():
		var d: Dictionary = drive[target]
		values[String(target)] = drive_value(values, d, level)
	var level_key: String = String(spec.get("level", ""))
	if not level_key.is_empty():
		values[level_key] = level
	var uid: String = String(e.get("uid", ""))
	var look: Dictionary = look_of(values)
	var wave: Variant = spec.get("wave", null)
	if wave is Dictionary:
		var wd: Dictionary = wave
		var points: int = int(wd.get("points", WAVE_POINTS))
		var span: float = float(_value(values, wd.get("span", 2.0)))
		var w: PackedFloat32Array = preview_wave(points) if preview else wave_at(doc, clip, values, look_t, span, points, comp, animated)
		if hand and not preview:
			for i: int in w.size():
				w[i] *= hand_k
		values[String(wd.get("uniform", "wave_tex"))] = _texture(layer, uid + ":wave", pack(w, PackedFloat32Array(), look))
	var spectrum: Variant = spec.get("spectrum", null)
	if spectrum is Dictionary:
		var sd: Dictionary = spectrum
		var nb: int = band_count(values)
		var raw: PackedFloat32Array = preview_spectrum(nb) if preview else spectrum_at(doc, clip, values, look_t, comp, animated)
		var levels: PackedFloat32Array = raw.slice(0, nb)
		var peaks: PackedFloat32Array = raw.slice(nb, nb * 2) if raw.size() >= nb * 2 else PackedFloat32Array()
		if hand and not preview:
			for i2: int in levels.size():
				levels[i2] *= hand_k
			for i3: int in peaks.size():
				peaks[i3] *= hand_k
		var bars_key: String = String(sd.get("bars", ""))
		var nbars: int = clampi(int(floor(_f(values, bars_key, float(nb)))), 1, 1024) if not bars_key.is_empty() else nb
		var scale: int = int(_f(values, "snd_scale", 0.0))
		var interp: int = int(_f(values, "snd_interp", 0.0))
		var spread: float = _f(values, "snd_spread", 0.0)
		var bar_vals: PackedFloat32Array = bars_of(levels, nb, nbars, scale, interp, spread)
		var bar_peaks: PackedFloat32Array = bars_of(peaks, nb, nbars, scale, interp, spread) if not peaks.is_empty() else PackedFloat32Array()
		values[String(sd.get("uniform", "spec_tex"))] = _texture(layer, uid + ":spectrum", pack(bar_vals, bar_peaks, look))
		if sd.has("peaks_on"):
			values[String(sd["peaks_on"])] = not bar_peaks.is_empty()
	var beats: Variant = spec.get("beats", null)
	if beats is Dictionary:
		var bd: Dictionary = beats
		var life: float = float(_value(values, bd.get("life", 1.5)))
		var list: PackedFloat32Array = preview_beats() if preview else beats_at(doc, clip, values, t, life, comp)
		if hand and not preview:
			for i4: int in list.size() / 4:
				list[i4 * 4 + 1] *= hand_k
		var full: PackedFloat32Array = PackedFloat32Array()
		full.resize(BEATS_MAX * 4)
		for i5: int in mini(list.size(), full.size()):
			full[i5] = list[i5]
		values[String(bd.get("uniform", "beat_tex"))] = _raw_texture(layer, uid + ":beats", full, BEATS_MAX)


static func _texture(layer: Node, key: String, data: PackedFloat32Array) -> ImageTexture:
	return _raw_texture(layer, key, data, maxi(data.size() / 4, 1))


static func _raw_texture(layer: Node, key: String, data: PackedFloat32Array, width: int) -> ImageTexture:
	var full: String = str(layer.get_instance_id()) + ":" + key
	var bytes: PackedFloat32Array = data
	if bytes.size() < width * 4:
		bytes = data.duplicate()
		bytes.resize(width * 4)
	var img: Image = Image.create_from_data(width, 1, false, Image.FORMAT_RGBAF, bytes.to_byte_array())
	var hit: Variant = _textures.get(full, null)
	if hit is ImageTexture and is_instance_valid(hit):
		var tex: ImageTexture = hit
		if tex.get_width() == img.get_width() and tex.get_format() == Image.FORMAT_RGBAF:
			tex.update(img)
			return tex
	if _textures.size() >= TEXTURES_MAX:
		_textures = {}
	var made: ImageTexture = ImageTexture.create_from_image(img)
	_textures[full] = made
	return made


static func cache_stats() -> Dictionary:
	return {"chunks": _chunks.size(), "floats": _floats, "tasks": _tasks.size(), "builds": chunk_builds, "hits": chunk_hits, "prefetched": prefetched, "local": local_builds}


static func settle_tasks() -> void:
	for k: Variant in _tasks.keys():
		WorkerThreadPool.wait_for_task_completion(int(_tasks[k]))
		_take(String(k))
	_tasks = {}


static func forget() -> void:
	settle_tasks()
	_derived = {}
	_textures = {}
	_parsed = {}
	_chunks = {}
	_floats = 0
	_ahead_at = {}
	_mutex.lock()
	_box = {}
	_mutex.unlock()
	ReactFeed.forget()

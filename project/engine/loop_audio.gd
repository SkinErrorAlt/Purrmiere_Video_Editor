extends RefCounted

const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const NEST_AUDIO_PATH := "res://engine/nest_audio.gd"
const KEY := "loop_window"
const SEG := "~loop"
const BUS := "~loopbus"
const FEED_KEY := "feed"
const GAIN_ID := "gain"
const VIEW_TAG := "_view_"
const PROP_KEYS: PackedStringArray = ["volume", "pan", "speed", "pitch_keep"]
const STATELESS_IDS: PackedStringArray = ["gain", "pan"]
const MIN_PIECE := 0.000001
const DECLICK := 0.004
const FADE_STEPS := 16
const OVERLAP_EPS := 0.0005

static var stats: Dictionary = {"split": 0, "pieces": 0, "buses": 0}


static func tag(entry: Dictionary, c: Clip, media_dur: float) -> Dictionary:
	if c == null or not c.loop:
		return entry
	var win: Vector2 = c.loop_window(media_dur)
	if win.y - win.x <= Clip.LOOP_MIN:
		return entry
	entry[KEY] = [win.x, win.y, c.loop_forward()]
	return entry


static func is_piece_of(entry_id: String, clip_id: String) -> bool:
	return entry_id == clip_id or entry_id.begins_with(clip_id + SEG)


static func piece_id(base_id: String, k: int) -> String:
	return base_id if k == 0 else base_id + SEG + str(k)


static func pieces_in(c: Clip, win: Vector2, forward: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null or win.y - win.x <= Clip.LOOP_MIN:
		return out
	var bounds: PackedFloat64Array = PackedFloat64Array([0.0])
	bounds.append_array(c.loop_seams_in(win))
	bounds.append(c.duration)
	for k: int in bounds.size() - 1:
		var a: float = bounds[k]
		var b: float = bounds[k + 1]
		if b - a <= MIN_PIECE:
			continue
		var mid: float = (a + b) * 0.5
		var raw_a: float = c.source_time(c.start + a)
		var raw_mid: float = c.source_time(c.start + mid)
		out.append({"k": k, "a": a, "b": b, "in": Clip.wrap_in(raw_mid, win, forward) - (raw_mid - raw_a)})
	return out


static func piece_clip(c: Clip, piece: Dictionary, fps: float = 0.0) -> Clip:
	var p: Clip = Clip.new()
	p.id = piece_id(c.id, int(piece["k"]))
	p.media_id = c.media_id
	p.sequence_id = c.sequence_id
	p.start = c.start + float(piece["a"])
	p.duration = float(piece["b"]) - float(piece["a"])
	p.in_offset = float(piece["in"])
	p.speed = c.speed.duplicate(true)
	if AnimProp.is_animated(c.speed) and float(piece["a"]) > 0.0:
		p.speed = shifted(c.speed, float(piece["a"]), p.duration, fps)
	p.audio = c.audio.duplicate(true)
	p.enabled = c.enabled
	return p


static func split_tracks(tracks: Array, fps: float, bus: bool = false) -> void:
	var extra: Array = []
	for t: Variant in tracks:
		if not (t is Dictionary):
			continue
		var td: Dictionary = t
		var list: Variant = td.get("clips", null)
		if not (list is Array) or not _any_tagged(list):
			continue
		var out: Array = []
		for e: Variant in list:
			if not (e is Dictionary) or not (e as Dictionary).has(KEY):
				out.append(e)
			elif bus and bus_ok(e, list):
				extra.append(bussed(e, td, fps))
			else:
				out.append_array(segments(e, fps))
		td["clips"] = out
	tracks.append_array(extra)


static func _any_tagged(list: Array) -> bool:
	for e: Variant in list:
		if e is Dictionary and (e as Dictionary).has(KEY):
			return true
	return false


static func probe_of(entry: Dictionary) -> Clip:
	var c: Clip = Clip.new()
	c.id = String(entry.get("id", ""))
	c.start = float(entry.get("start", 0.0))
	c.duration = float(entry.get("duration", 0.0))
	c.in_offset = float(entry.get("in_offset", 0.0))
	var sp: Variant = entry.get("speed", null)
	c.speed = (sp as Dictionary).duplicate(true) if sp is Dictionary else AnimProp.make(1.0)
	c.loop = true
	return c


static func segments(entry: Dictionary, fps: float) -> Array:
	var info: Array = entry[KEY]
	var win: Vector2 = Vector2(float(info[0]), float(info[1]))
	var forward: bool = bool(info[2])
	var base: Dictionary = entry.duplicate(true)
	base.erase(KEY)
	var probe: Clip = probe_of(base)
	var last: int = probe.loop_seams_in(win).size()
	var out: Array = []
	for piece: Dictionary in pieces_in(probe, win, forward):
		var k: int = int(piece["k"])
		var a: float = float(piece["a"])
		var b: float = float(piece["b"])
		var one: Dictionary = base.duplicate(true) if k < last else base
		one["id"] = piece_id(probe.id, k)
		one["start"] = probe.start + a
		one["duration"] = b - a
		one["in_offset"] = float(piece["in"])
		if k > 0:
			one["fade_in"] = 0.0
		if k < last:
			one["fade_out"] = 0.0
		if a > 0.0:
			_shift_entry(one, a, b - a, fps)
		if k > 0:
			_name_view_gains(one, k)
		out.append(one)
	stats["split"] = int(stats["split"]) + 1
	stats["pieces"] = int(stats["pieces"]) + out.size()
	return out


static func is_view_gain(e: Variant) -> bool:
	if not (e is Dictionary):
		return false
	var ed: Dictionary = e
	return String(ed.get("id", "")) == GAIN_ID and String(ed.get("uid", "")).contains(VIEW_TAG)


static func _name_view_gains(piece: Dictionary, k: int) -> void:
	var list: Variant = piece.get("effects", null)
	if not (list is Array):
		return
	for e: Variant in list:
		if is_view_gain(e):
			var ed: Dictionary = e
			ed["uid"] = piece_id(String(ed["uid"]), k)


static func view_gains_of(pieces: Array, out: Dictionary) -> void:
	for p: Variant in pieces:
		for e: Variant in (p as Dictionary).get("effects", []):
			if is_view_gain(e):
				var ed: Dictionary = e
				out[String(ed["uid"])] = (ed["params"] as Dictionary)["db"]


static func _shift_entry(piece: Dictionary, by: float, span: float, fps: float) -> void:
	for key: String in PROP_KEYS:
		var p: Variant = piece.get(key, null)
		if p is Dictionary and AnimProp.is_animated(p):
			piece[key] = shifted(p, by, span, fps)
	var list: Variant = piece.get("effects", null)
	if not (list is Array):
		return
	for e: Variant in list:
		if not (e is Dictionary):
			continue
		var ed: Dictionary = e
		var mix: Variant = ed.get("mix", null)
		if mix is Dictionary and AnimProp.is_animated(mix):
			ed["mix"] = shifted(mix, by, span, fps)
		var params: Variant = ed.get("params", null)
		if not (params is Dictionary):
			continue
		for pk: Variant in (params as Dictionary).keys():
			var pv: Variant = (params as Dictionary)[pk]
			if pv is Dictionary and AnimProp.is_animated(pv):
				(params as Dictionary)[pk] = shifted(pv, by, span, fps)


static func keys_only(p: Dictionary) -> bool:
	for l: Variant in p.get("layers", []):
		if not (l is Dictionary) or String((l as Dictionary).get("type", "")) != "keys":
			return false
	return true


static func shifted(p: Dictionary, by: float, span: float, fps: float) -> Dictionary:
	if not keys_only(p):
		return AnimTime.bake(p, func(u: float) -> float: return u + by, span, fps)
	var out: Dictionary = p.duplicate(true)
	for l: Variant in out.get("layers", []):
		for k: Variant in (l as Dictionary).get("keys", []):
			var kd: Dictionary = k
			kd["t"] = float(kd.get("t", 0.0)) - by
	return out


static func bus_safe(p: Variant) -> bool:
	if not (p is Dictionary) or not AnimProp.is_animated(p):
		return true
	for l: Variant in (p as Dictionary).get("layers", []):
		if not (l is Dictionary):
			return false
		var ld: Dictionary = l
		if String(ld.get("type", "")) != "keys" or String(ld.get("loop", "once")) != "once" or String(ld.get("blend", "over")) == "multiply":
			return false
	return true


static func _effect_safe(ed: Dictionary) -> bool:
	if not bus_safe(ed.get("mix", null)):
		return false
	var params: Variant = ed.get("params", null)
	if not (params is Dictionary):
		return true
	for pv: Variant in (params as Dictionary).values():
		if not bus_safe(pv):
			return false
	return true


static func bus_ok(entry: Dictionary, list: Array) -> bool:
	if bool(entry.get("muted", false)) or not bus_safe(entry.get("volume", null)) or not bus_safe(entry.get("pan", null)):
		return false
	var stateful: bool = false
	for e: Variant in entry.get("effects", []):
		if not (e is Dictionary):
			return false
		var ed: Dictionary = e
		if is_view_gain(ed):
			continue
		if not _effect_safe(ed):
			return false
		if bool(ed.get("enabled", true)) and not STATELESS_IDS.has(String(ed.get("id", ""))):
			stateful = true
	if not stateful:
		return false
	var s0: float = float(entry.get("start", 0.0))
	var s1: float = s0 + float(entry.get("duration", 0.0))
	for o: Variant in list:
		if not (o is Dictionary) or is_same(o, entry):
			continue
		var os: float = float((o as Dictionary).get("start", 0.0))
		var oe: float = os + float((o as Dictionary).get("duration", 0.0))
		if os < s1 - OVERLAP_EPS and oe > s0 + OVERLAP_EPS:
			return false
	return true


static func fade_curve(shape: int, x: float) -> float:
	var u: float = clampf(x, 0.0, 1.0)
	if shape == 1:
		return sin(u * PI * 0.5)
	if shape == 2:
		return u * u * (3.0 - 2.0 * u)
	return u


static func edge_gain(s0: float, dur: float, fade_in: float, fade_out: float, shape: int, t: float) -> float:
	var local: float = clampf(t - s0, 0.0, dur)
	var g: float = 1.0
	if fade_in > 0.0 and local < fade_in:
		g *= fade_curve(shape, local / fade_in)
	var remain: float = dur - local
	if fade_out > 0.0 and remain < fade_out:
		g *= fade_curve(shape, remain / fade_out)
	var over: float = t - s0 - dur
	if over > 0.0:
		g *= clampf(1.0 - over / DECLICK, 0.0, 1.0)
	return g


static func edge_envelope(s0: float, dur: float, fade_in: float, fade_out: float, shape: int) -> Dictionary:
	var fin: float = clampf(fade_in, 0.0, dur)
	var fout: float = clampf(fade_out, 0.0, dur)
	var steps: int = 1 if shape == 0 else FADE_STEPS
	var times: PackedFloat64Array = PackedFloat64Array([s0, s0 + dur, s0 + dur + DECLICK])
	for i: int in steps + 1:
		var u: float = float(i) / float(steps)
		if fin > 0.0:
			times.append(s0 + u * fin)
		if fout > 0.0:
			times.append(s0 + dur - fout + u * fout)
	times.sort()
	var keys: Array = []
	var last: float = -INF
	for t: float in times:
		if t - last <= MIN_PIECE:
			continue
		last = t
		keys.append({"t": t, "v": edge_gain(s0, dur, fin, fout, shape, t), "i": "linear"})
	return {"a": true, "base": float((keys[0] as Dictionary)["v"]), "layers": [{"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": "once", "keys": keys}]}


static func bussed(entry: Dictionary, td: Dictionary, fps: float) -> Dictionary:
	var na: GDScript = load(NEST_AUDIO_PATH)
	var s0: float = float(entry.get("start", 0.0))
	var dur: float = float(entry.get("duration", 0.0))
	var s1: float = s0 + dur
	var to_seq: Dictionary = {"a": 1.0, "b": -s0}
	var keep: Array = []
	var moved: Array = []
	for e: Variant in entry.get("effects", []):
		if is_view_gain(e):
			keep.append(e)
		else:
			moved.append(e)
	var fx: Array = na.call("retime_effects", moved, to_seq, s0, s1, dur)
	for i: int in mini(fx.size(), moved.size()):
		var mix: Variant = (moved[i] as Dictionary).get("mix", null)
		if mix is Dictionary and AnimProp.is_animated(mix):
			(fx[i] as Dictionary)["mix"] = na.call("retime", mix, to_seq, s0, s1, dur)
	var vol: Variant = entry.get("volume", null)
	var pan: Variant = entry.get("pan", null)
	var stages: Array = [
		{"kind": "fx", "list": fx},
		{"kind": "gain", "prop": na.call("retime", vol if vol is Dictionary else AnimProp.make(1.0), to_seq, s0, s1, dur), "t0": s0, "t1": s1},
		{"kind": "gain", "prop": edge_envelope(s0, dur, float(entry.get("fade_in", 0.0)), float(entry.get("fade_out", 0.0)), int(entry.get("fade_shape", 0.0))), "t0": s0, "t1": s1 + DECLICK},
		{"kind": "pan", "prop": na.call("retime", pan if pan is Dictionary else AnimProp.make(0.0), to_seq, s0, s1, dur)},
	]
	var clip_id: String = String(entry.get("id", ""))
	var track_id: String = String(td.get("id", ""))
	var bare: Dictionary = entry.duplicate()
	bare["effects"] = keep
	bare["volume"] = AnimProp.make(1.0)
	bare["pan"] = AnimProp.make(0.0)
	bare["fade_in"] = 0.0
	bare["fade_out"] = 0.0
	var out: Dictionary = {
		"id": track_id + "/" + clip_id + BUS,
		"owner": String(td.get("owner", track_id)),
		FEED_KEY: track_id,
		"muted": false,
		"solo": false,
		"volume": AnimProp.make(1.0),
		"pan": AnimProp.make(0.0),
		"effects": na.call("apply_stages", stages, [], clip_id + BUS, false),
		"clips": segments(bare, fps),
		"loop_bus": clip_id,
	}
	if td.has("nest"):
		out["nest"] = td["nest"]
	stats["buses"] = int(stats["buses"]) + 1
	return out

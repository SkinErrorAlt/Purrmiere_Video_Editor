extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const AudioGraph := preload("res://engine/audio_graph.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const LoopAudio := preload("res://engine/loop_audio.gd")
const MAX_DEPTH := 4
const LINEAR_IDS: PackedStringArray = ["gain", "pan"]
const GAIN_FLOOR := 0.0001
const DB_FLOOR := -80.0
const DB_CEIL := 24.0
const SAMPLE_STEP := 0.05
const SAMPLE_MAX := 2000
const HOLD_EDGE := 0.001
const SPEED_RATE := 120.0
const SPEED_STEPS := 4096
const BISECT_STEPS := 48
const TINY := 0.000001
const FAR := 1000000000.0
const OUTSIDE_PREFIX := "outside/"
const PART_JOIN := 0.0001


static func nest_sequence_id(doc: Project, c: Clip) -> String:
	if c == null:
		return ""
	if not c.sequence_id.is_empty():
		return c.sequence_id
	if doc == null:
		return ""
	var m: MediaItem = doc.media_by_id(c.media_id)
	if m != null and m.kind == "sequence":
		return m.sequence_id
	return ""


static func is_carrier(doc: Project, seq: Sequence, tr: Track, c: Clip) -> bool:
	var sid: String = nest_sequence_id(doc, c)
	if sid.is_empty() or tr == null or seq == null:
		return false
	if tr.is_sound(c):
		return true
	for f: Clip in seq.linked(c):
		if f == c or nest_sequence_id(doc, f) != sid:
			continue
		var ft: Track = seq.track_of(f.id)
		if ft != null and ft.is_sound(f):
			return false
	return true


static func carrier_of(doc: Project, seq: Sequence, c: Clip) -> Clip:
	var sid: String = nest_sequence_id(doc, c)
	if sid.is_empty() or seq == null:
		return null
	for f: Clip in seq.linked(c):
		if nest_sequence_id(doc, f) != sid:
			continue
		if is_carrier(doc, seq, seq.track_of(f.id), f):
			return f
	return c


static func nest_tracks(doc: Project, seq: Sequence, handles: Dictionary, depth: int = 0, ancestry: PackedStringArray = PackedStringArray(), skip: Dictionary = {}) -> Array:
	var cache: Dictionary = {}
	return _nest_tracks(doc, seq, handles, depth, ancestry, skip, cache)


static func _nest_tracks(doc: Project, seq: Sequence, handles: Dictionary, depth: int, ancestry: PackedStringArray, skip: Dictionary, cache: Dictionary) -> Array:
	var out: Array = []
	if doc == null or seq == null or depth >= MAX_DEPTH:
		return out
	var anc: PackedStringArray = ancestry.duplicate()
	if not anc.has(seq.id):
		anc.append(seq.id)
	var audio_parts: Dictionary = {}
	for at: Track in seq.all_tracks():
		for ac: Clip in at.clips:
			if at.is_sound(ac) and not ac.link_id.is_empty():
				var asid: String = nest_sequence_id(doc, ac)
				if not asid.is_empty():
					audio_parts[ac.link_id + "|" + asid] = true
	for tr: Track in seq.all_tracks():
		for c: Clip in tr.clips:
			if skip.has(c.id) or not c.enabled:
				continue
			var sid: String = nest_sequence_id(doc, c)
			if sid.is_empty() or anc.has(sid):
				continue
			if not bool(c.nest.get("hear_audio", true)):
				continue
			if not tr.is_sound(c) and not c.link_id.is_empty() and audio_parts.has(c.link_id + "|" + sid):
				continue
			var inner: Sequence = doc.sequence_by_id(sid)
			if inner == null:
				continue
			out.append_array(flatten(doc, seq, tr, c, inner, handles, depth, anc, cache))
	return out


static func resolve_mute_solo(tracks: Array) -> Array:
	var any_solo: bool = false
	for t: Variant in tracks:
		if bool((t as Dictionary).get("solo", false)):
			any_solo = true
	var out: Array = []
	for t: Variant in tracks:
		var td: Dictionary = t
		if bool(td.get("muted", false)):
			continue
		if any_solo and not bool(td.get("solo", false)):
			continue
		out.append(td)
	return out


static func inner_level(doc: Project, inner: Sequence, handles: Dictionary, depth: int, anc: PackedStringArray, cache: Dictionary = {}) -> Array:
	var key: String = inner.id + "|" + str(depth) + "|" + ",".join(anc)
	if cache.has(key):
		return cache[key]
	var all: Array = AudioGraph.own_tracks(doc, inner, handles)
	all.append_array(_nest_tracks(doc, inner, handles, depth, anc, {}, cache))
	AudioGraph.ensure_feed_targets(inner, all)
	var level: Array = resolve_mute_solo(all)
	cache[key] = level
	return level


static func allow_list(n: Clip) -> Array:
	var raw: Variant = n.nest.get("audio_allow", [])
	if raw is Array:
		return raw
	if raw is PackedStringArray:
		return Array(raw)
	return []


static func flatten(doc: Project, seq: Sequence, tr: Track, n: Clip, inner: Sequence, handles: Dictionary, depth: int, anc: PackedStringArray, cache: Dictionary = {}) -> Array:
	var out: Array = []
	var level: Array = inner_level(doc, inner, handles, depth + 1, anc, cache)
	if level.is_empty():
		return out
	var allow: Array = allow_list(n)
	var map: Dictionary = track_map(n, inner)
	var parts: Array = nest_parts(n, inner)
	var span: Vector2 = Vector2(n.start, n.end())
	var on_audio: bool = tr.is_sound(n)
	var keep_pitch: bool = bool(n.audio.get("keep_pitch", false)) and absf(n.static_speed() - 1.0) > TINY
	var own: Array = nest_stage(seq, tr, n, span)
	var master: Variant = inner.get("master_volume")
	if AudioGraph.feeds_on():
		return flatten_fed(tr, n, level, allow, map, parts, span, on_audio, keep_pitch, own, master)
	for x: Variant in level:
		var xd: Dictionary = x
		var owner: String = String(xd.get("owner", xd.get("id", "")))
		if not allow.is_empty() and not allow.has(owner):
			continue
		var clips: Array = map_parts(xd.get("clips", []), parts, keep_pitch)
		if clips.is_empty():
			continue
		var base_uid: String = n.id + "/" + String(xd.get("id", ""))
		var stages: Array = []
		stages.append({"kind": "fx", "list": retime_effects(xd.get("effects", []), map, span.x, span.y, span.y - span.x)})
		stages.append({"kind": "gain", "prop": retime(xd.get("volume", AnimProp.make(1.0)), map, span.x, span.y, span.y - span.x), "t0": span.x, "t1": span.y})
		stages.append({"kind": "pan", "prop": retime(xd.get("pan", AnimProp.make(0.0)), map, span.x, span.y, span.y - span.x)})
		if master is Dictionary:
			stages.append({"kind": "gain", "prop": retime(master, map, span.x, span.y, span.y - span.x), "t0": span.x, "t1": span.y})
		elif master is float:
			stages.append({"kind": "gain", "prop": AnimProp.make(float(master)), "t0": span.x, "t1": span.y})
		stages.append_array(own)
		var effects: Array = apply_stages(stages, clips, base_uid)
		if on_audio:
			for te: Dictionary in tr.effects:
				effects.append(te.duplicate(true))
		out.append({
			"id": tr.id + "/" + base_uid,
			"owner": tr.id,
			"nest": n.id,
			"muted": tr.muted if on_audio else false,
			"solo": tr.solo if on_audio else false,
			"volume": tr.volume.duplicate(true) if on_audio else AnimProp.make(1.0),
			"pan": tr.pan.duplicate(true) if on_audio else AnimProp.make(0.0),
			"effects": effects,
			"clips": clips,
		})
	return out


static func flatten_fed(tr: Track, n: Clip, level: Array, allow: Array, map: Dictionary, parts: Array, span: Vector2, on_audio: bool, keep_pitch: bool, own: Array, master: Variant) -> Array:
	var out: Array = []
	var prefix: String = tr.id + "/" + n.id + "/"
	var picked: Array = []
	var by_id: Dictionary = {}
	for x: Variant in level:
		var xd: Dictionary = x
		if not allow.is_empty() and not allow.has(String(xd.get("owner", xd.get("id", "")))):
			continue
		picked.append(xd)
		by_id[String(xd.get("id", ""))] = xd
	var fed: Dictionary = {}
	var clips_of: Dictionary = {}
	for x: Variant in picked:
		var xd: Dictionary = x
		var feed: String = String(xd.get(AudioGraph.FEED_KEY, ""))
		if not feed.is_empty() and by_id.has(feed):
			fed[feed] = true
		clips_of[String(xd.get("id", ""))] = map_parts(xd.get("clips", []), parts, keep_pitch)
	var needed: Dictionary = needed_ids(by_id, clips_of)
	if needed.is_empty():
		return out
	var bus_id: String = tr.id + "/" + n.id
	var use_bus: bool = not stages_linear(own)
	var tail: Array = master_stages(master, map, span)
	tail.append_array(own)
	var outer_feed: String = tr.id if on_audio else ""
	var muted: bool = tr.muted if on_audio else false
	var solo: bool = tr.solo if on_audio else false
	var len_: float = span.y - span.x
	for x: Variant in picked:
		var xd: Dictionary = x
		var id: String = String(xd.get("id", ""))
		if not needed.has(id):
			continue
		var clips: Array = clips_of[id]
		var inner_feed: String = String(xd.get(AudioGraph.FEED_KEY, ""))
		var feeder: bool = not inner_feed.is_empty() and by_id.has(inner_feed)
		var stages: Array = [{"kind": "fx", "list": retime_effects(xd.get("effects", []), map, span.x, span.y, len_)}]
		if not feeder:
			stages.append({"kind": "gain", "prop": retime(xd.get("volume", AnimProp.make(1.0)), map, span.x, span.y, len_), "t0": span.x, "t1": span.y})
			stages.append({"kind": "pan", "prop": retime(xd.get("pan", AnimProp.make(0.0)), map, span.x, span.y, len_)})
			if not use_bus:
				stages.append_array(tail)
		var effects: Array = apply_stages(stages, clips, n.id + "/" + id, not fed.has(id))
		var target: String = prefix + inner_feed if feeder else (bus_id if use_bus else outer_feed)
		var entry: Dictionary = AudioGraph.feed_entry(prefix + id, tr.id, target, muted, solo, effects, clips)
		entry["nest"] = n.id
		if target.is_empty():
			entry.erase(AudioGraph.FEED_KEY)
		out.append(entry)
	if use_bus:
		var bus: Dictionary = AudioGraph.feed_entry(bus_id, tr.id, outer_feed, muted, solo, apply_stages(tail, [], bus_id, false), [])
		bus["nest_bus"] = n.id
		if outer_feed.is_empty():
			bus.erase(AudioGraph.FEED_KEY)
		out.append(bus)
	return out


static func loop_window_of(n: Clip, inner: Sequence) -> Vector2:
	if n == null or inner == null or not n.loop:
		return Vector2.ZERO
	var win: Vector2 = n.loop_window(inner.duration())
	return win if win.y - win.x > Clip.LOOP_MIN else Vector2.ZERO


static func track_map(n: Clip, inner: Sequence) -> Dictionary:
	var win: Vector2 = loop_window_of(n, inner)
	if win == Vector2.ZERO:
		return nest_map(n)
	return {"clip": n, "sn": 0.0, "so": 0.0, "win": win, "fwd": n.loop_forward()}


static func nest_parts(n: Clip, inner: Sequence) -> Array:
	var parts: Array = []
	var win: Vector2 = loop_window_of(n, inner)
	if win == Vector2.ZERO:
		parts.append([nest_map(n), Vector2(n.source_in(), n.source_out()), n.id + "/"])
		return parts
	for piece: Dictionary in LoopAudio.pieces_in(n, win, n.loop_forward()):
		var p: Clip = LoopAudio.piece_clip(n, piece)
		parts.append([nest_map(p), Vector2(p.source_in(), p.source_out()), p.id + "/"])
	return parts


static func map_parts(list: Variant, parts: Array, keep_pitch: bool) -> Array:
	var clips: Array = []
	if not (list is Array):
		return clips
	for part: Variant in parts:
		var pa: Array = part
		for e: Variant in (list as Array):
			var me: Dictionary = map_entry(e, pa[0], pa[1], pa[2], keep_pitch)
			if not me.is_empty():
				clips.append(me)
	return clips


static func needed_ids(by_id: Dictionary, clips_of: Dictionary) -> Dictionary:
	var needed: Dictionary = {}
	for id: Variant in by_id.keys():
		if (clips_of.get(id, []) as Array).is_empty():
			continue
		var cur: String = String(id)
		var hops: int = 0
		while not cur.is_empty() and not needed.has(cur) and hops <= by_id.size():
			needed[cur] = true
			var up: String = String((by_id[cur] as Dictionary).get(AudioGraph.FEED_KEY, ""))
			cur = up if by_id.has(up) else ""
			hops += 1
	return needed


static func stages_linear(stages: Array) -> bool:
	for st: Variant in stages:
		var sd: Dictionary = st
		if String(sd.get("kind", "")) != "fx":
			continue
		for e: Variant in sd.get("list", []):
			var ed: Dictionary = e
			if bool(ed.get("enabled", true)) and not LINEAR_IDS.has(String(ed.get("id", ""))):
				return false
	return true


static func master_stages(master: Variant, map: Dictionary, span: Vector2) -> Array:
	var out: Array = []
	if master is Dictionary:
		out.append({"kind": "gain", "prop": retime(master, map, span.x, span.y, span.y - span.x), "t0": span.x, "t1": span.y})
	elif master is float:
		out.append({"kind": "gain", "prop": AnimProp.make(float(master)), "t0": span.x, "t1": span.y})
	return out


static func nest_stage(seq: Sequence, tr: Track, n: Clip, span: Vector2) -> Array:
	var stages: Array = []
	var shift: Dictionary = {"a": 1.0, "b": -n.start}
	var local_fx: Array = []
	for ae: Variant in n.audio_effects():
		if ae is Dictionary:
			local_fx.append((ae as Dictionary).duplicate(true))
	local_fx.append_array(AudioGraph.band_limit_from(n))
	var partner: Clip = AudioGraph.link_partner(seq, n)
	if partner != null:
		local_fx.append_array(AudioGraph.band_limit_from(partner))
	local_fx.append_array(AudioGraph.view_gain_from(seq, n, tr.id))
	var warped: Dictionary = AnimTime.warp_audio_entry(n, {"volume": n.audio.get("volume", AnimProp.make(1.0)), "pan": n.get_param("audio.pan"), "effects": local_fx}, partner, seq.fps if seq != null else 0.0)
	stages.append({"kind": "fx", "list": retime_effects(local_fx, shift, span.x, span.y, n.duration)})
	var vol: Dictionary = warped["volume"]
	stages.append({"kind": "gain", "prop": retime(vol, shift, span.x, span.y, n.duration), "t0": span.x, "t1": span.y})
	var fade_in: float = clampf(float(n.audio.get("fade_in", 0.0)), 0.0, n.duration)
	var fade_out: float = clampf(float(n.audio.get("fade_out", 0.0)), 0.0, n.duration)
	if fade_in > TINY or fade_out > TINY:
		stages.append({"kind": "gain", "prop": fade_envelope(n.start, n.duration, fade_in, fade_out), "t0": span.x, "t1": span.y})
	stages.append({"kind": "pan", "prop": retime(warped["pan"], shift, span.x, span.y, n.duration)})
	return stages


static func fade_envelope(start: float, dur: float, fade_in: float, fade_out: float) -> Dictionary:
	var p: Dictionary = AnimProp.make(1.0)
	if fade_in > TINY:
		p = AnimProp.set_key(p, start, 0.0, "linear")
		p = AnimProp.set_key(p, start + fade_in, 1.0, "linear")
	if fade_out > TINY:
		p = AnimProp.set_key(p, start + dur - fade_out, 1.0, "linear")
		p = AnimProp.set_key(p, start + dur, 0.0, "linear")
	return p


static func apply_stages(stages: Array, clips: Array, base_uid: String, fold_gains: bool = true) -> Array:
	var effects: Array = []
	var linear: bool = fold_gains
	var index: int = 0
	for st: Variant in stages:
		var sd: Dictionary = st
		var kind: String = String(sd.get("kind", ""))
		index += 1
		if kind == "fx":
			for e: Variant in sd.get("list", []):
				var ed: Dictionary = (e as Dictionary).duplicate(true)
				effects.append(ed)
				if bool(ed.get("enabled", true)) and not LINEAR_IDS.has(String(ed.get("id", ""))):
					linear = false
		elif kind == "gain":
			var g: Dictionary = sd.get("prop", AnimProp.make(1.0))
			if is_constant(g, 1.0):
				continue
			if linear:
				for c: Variant in clips:
					var cd: Dictionary = c
					cd["volume"] = fold(cd.get("volume", AnimProp.make(1.0)), g, float(cd.get("start", 0.0)), float(cd.get("duration", 0.0)))
			else:
				effects.append(gain_effect(g, float(sd.get("t0", 0.0)), float(sd.get("t1", 0.0)), base_uid + "_gain" + str(index)))
		elif kind == "pan":
			var p: Dictionary = sd.get("prop", AnimProp.make(0.0))
			if is_constant(p, 0.0):
				continue
			effects.append({"uid": base_uid + "_pan" + str(index), "id": "pan", "enabled": true, "params": {"pan": p}})
	return effects


static func is_constant(p: Dictionary, value: float) -> bool:
	if AnimProp.is_animated(p):
		return false
	var v: Variant = p.get("v", value)
	return (v is float or v is int) and absf(float(v) - value) < TINY


static func gain_effect(g: Dictionary, t0: float, t1: float, uid: String) -> Dictionary:
	var db: Dictionary
	if not AnimProp.is_animated(g):
		db = AnimProp.make(to_db(float(g.get("v", 1.0))))
	else:
		var times: PackedFloat64Array = sample_times(t0, t1, key_times(g))
		var keys: Array = []
		for t: float in times:
			keys.append({"t": t, "v": to_db(AnimProp.evaluate_float(g, t, t1 - t0)), "i": "linear"})
		db = keys_prop(keys)
	return {"uid": uid, "id": "gain", "enabled": true, "params": {"db": db}}


static func to_db(v: float) -> float:
	return clampf(20.0 * log(maxf(v, GAIN_FLOOR)) / log(10.0), DB_FLOOR, DB_CEIL)


static func nest_map(n: Clip) -> Dictionary:
	if n.is_speed_static():
		var k: float = n.static_speed()
		if absf(k) < TINY:
			k = TINY
		return {"a": k, "b": n.in_offset - n.start * k}
	return {"clip": n, "sn": 0.0, "so": 0.0}


static func inverse_nest_map(n: Clip) -> Dictionary:
	var k: float = n.static_speed()
	if not n.is_speed_static():
		k = (n.source_time(n.end()) - n.source_time(n.start)) / maxf(n.duration, TINY)
	if absf(k) < TINY:
		k = 1.0
	return {"a": 1.0 / k, "b": n.start - n.in_offset / k}


static func shifted(map: Dictionary, new_shift: float, old_shift: float) -> Dictionary:
	if map.has("clip"):
		var out: Dictionary = {"clip": map["clip"], "sn": float(map.get("sn", 0.0)) + new_shift, "so": float(map.get("so", 0.0)) + old_shift}
		if map.has("win"):
			out["win"] = map["win"]
			out["fwd"] = map["fwd"]
		return out
	var a: float = float(map["a"])
	return {"a": a, "b": a * new_shift + float(map["b"]) - old_shift}


static func old_of(map: Dictionary, t: float) -> float:
	if map.has("parts"):
		return old_of(part_map(map, t), t)
	if map.has("clip"):
		var n: Clip = map["clip"]
		var src: float = n.source_time(t + float(map.get("sn", 0.0)))
		if map.has("win"):
			src = Clip.wrap_in(src, map["win"], bool(map["fwd"]))
		return src - float(map.get("so", 0.0))
	return float(map["a"]) * t + float(map["b"])


static func new_of(map: Dictionary, s: float) -> float:
	if map.has("parts"):
		return new_of(part_from(map, s), s)
	if map.has("clip"):
		var n: Clip = map["clip"]
		var want: float = s + float(map.get("so", 0.0))
		var lo: float = n.start
		var hi: float = n.end()
		var rising: bool = n.source_time(hi) >= n.source_time(lo)
		for _i: int in BISECT_STEPS:
			var mid: float = (lo + hi) * 0.5
			var below: bool = n.source_time(mid) < want
			if below == rising:
				lo = mid
			else:
				hi = mid
		return (lo + hi) * 0.5 - float(map.get("sn", 0.0))
	return (s - float(map["b"])) / float(map["a"])


static func rate_of(map: Dictionary, t: float) -> float:
	if map.has("clip"):
		var n: Clip = map["clip"]
		return n.speed_at(t + float(map.get("sn", 0.0)) - n.start)
	return float(map["a"])


static func keys_only(p: Dictionary) -> bool:
	if not AnimProp.is_animated(p):
		return true
	for l: Variant in p.get("layers", []):
		var ld: Dictionary = l
		if String(ld.get("type", "")) != "keys":
			return false
		if String(ld.get("blend", "over")) == "multiply":
			return false
	return true


static func key_times(p: Dictionary) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if not AnimProp.is_animated(p):
		return out
	for l: Variant in p.get("layers", []):
		for k: Variant in (l as Dictionary).get("keys", []):
			out.append(float((k as Dictionary).get("t", 0.0)))
	return out


static func keys_prop(keys: Array) -> Dictionary:
	if keys.is_empty():
		return AnimProp.make(0.0)
	if keys.size() == 1:
		return AnimProp.make(float((keys[0] as Dictionary).get("v", 0.0)))
	return {"a": true, "base": float((keys[0] as Dictionary).get("v", 0.0)), "layers": [{"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": "once", "keys": keys}]}


static func sample_times(t0: float, t1: float, extra: PackedFloat64Array) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if t1 <= t0:
		out.append(t0)
		return out
	var step: float = maxf(SAMPLE_STEP, (t1 - t0) / float(SAMPLE_MAX))
	var t: float = t0
	while t < t1:
		out.append(t)
		t += step
	out.append(t1)
	for x: float in extra:
		if x > t0 and x < t1:
			out.append(x)
			if x - HOLD_EDGE > t0:
				out.append(x - HOLD_EDGE)
	out.sort()
	var clean: PackedFloat64Array = PackedFloat64Array()
	for v: float in out:
		if clean.is_empty() or v - clean[clean.size() - 1] > TINY:
			clean.append(v)
	return clean


static func retime_keys(p: Dictionary, a: float, b: float) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	for l: Variant in out.get("layers", []):
		for k: Variant in (l as Dictionary).get("keys", []):
			var kd: Dictionary = k
			kd["t"] = (float(kd.get("t", 0.0)) - b) / a
			for hk: String in ["ho", "hi"]:
				if kd.get(hk) is Array and (kd[hk] as Array).size() >= 2:
					var h: Array = kd[hk]
					h[0] = float(h[0]) / a
	return out


static func bake(p: Dictionary, map: Dictionary, t0: float, t1: float, dur: float) -> Dictionary:
	var extra: PackedFloat64Array = PackedFloat64Array()
	for kt: float in key_times(p):
		extra.append(new_of(map, kt))
	var keys: Array = []
	for t: float in sample_times(t0, t1, extra):
		keys.append({"t": t, "v": AnimProp.evaluate_float(p, old_of(map, t), dur), "i": "linear"})
	return keys_prop(keys)


static func retime(p: Dictionary, map: Dictionary, t0: float, t1: float, dur: float) -> Dictionary:
	if not AnimProp.is_animated(p):
		return p.duplicate(true)
	if not map.has("clip") and not map.has("parts") and float(map["a"]) > 0.0 and keys_only(p):
		return retime_keys(p, float(map["a"]), float(map["b"]))
	return bake(p, map, t0, t1, dur)


static func retime_effects(list: Variant, map: Dictionary, t0: float, t1: float, dur: float) -> Array:
	var out: Array = []
	if not (list is Array):
		return out
	for e: Variant in list:
		if not (e is Dictionary):
			continue
		var ed: Dictionary = (e as Dictionary).duplicate(true)
		var params: Dictionary = ed.get("params", {})
		var moved: Dictionary = {}
		for k: Variant in params.keys():
			var pv: Variant = params[k]
			moved[k] = retime(pv, map, t0, t1, dur) if pv is Dictionary else pv
		ed["params"] = moved
		out.append(ed)
	return out


static func scale(p: Dictionary, f: float) -> Dictionary:
	if not AnimProp.is_animated(p):
		var v: Variant = p.get("v", 1.0)
		return AnimProp.make(float(v) * f if (v is float or v is int) else f)
	var out: Dictionary = p.duplicate(true)
	var base: Variant = out.get("base", 0.0)
	if base is float or base is int:
		out["base"] = float(base) * f
	for l: Variant in out.get("layers", []):
		for k: Variant in (l as Dictionary).get("keys", []):
			var kd: Dictionary = k
			var kv: Variant = kd.get("v", 0.0)
			if kv is float or kv is int:
				kd["v"] = float(kv) * f
			for hk: String in ["ho", "hi"]:
				if kd.get(hk) is Array and (kd[hk] as Array).size() >= 2:
					var h: Array = kd[hk]
					h[1] = float(h[1]) * f
	return out


static func fold(vol: Dictionary, g: Dictionary, start: float, dur: float) -> Dictionary:
	var to_track: Dictionary = {"a": 1.0, "b": start}
	if not AnimProp.is_animated(g):
		var gv: float = float(g.get("v", 1.0))
		if keys_only(vol):
			return scale(vol, gv)
		return scale(bake(vol, {"a": 1.0, "b": 0.0}, 0.0, dur, dur), gv)
	if not AnimProp.is_animated(vol):
		return scale(retime(g, to_track, 0.0, dur, dur), float(vol.get("v", 1.0)))
	var extra: PackedFloat64Array = key_times(vol)
	for kt: float in key_times(g):
		extra.append(kt - start)
	var keys: Array = []
	for t: float in sample_times(0.0, dur, extra):
		keys.append({"t": t, "v": AnimProp.evaluate_float(vol, t, dur) * AnimProp.evaluate_float(g, t + start, dur), "i": "linear"})
	return keys_prop(keys)


static func speed_integral(p: Dictionary, dur: float, u: float) -> float:
	if not AnimProp.is_animated(p):
		return float(p.get("v", 1.0)) * u
	var steps: int = clampi(int(ceil(absf(u) * SPEED_RATE)), 1, SPEED_STEPS)
	var h: float = u / float(steps)
	var acc: float = 0.0
	var prev: float = AnimProp.evaluate_float(p, 0.0, dur)
	for i: int in steps:
		var cur: float = AnimProp.evaluate_float(p, h * float(i + 1), dur)
		acc += (prev + cur) * 0.5 * h
		prev = cur
	return acc


static func mapped_speed(speed: Dictionary, e_dur: float, local: Dictionary, dur: float) -> Dictionary:
	if not local.has("clip"):
		var a: float = float(local["a"])
		if not AnimProp.is_animated(speed):
			return AnimProp.make(float(speed.get("v", 1.0)) * a)
		if a > 0.0 and keys_only(speed):
			return scale(retime_keys(speed, a, float(local["b"])), a)
	var extra: PackedFloat64Array = PackedFloat64Array()
	for kt: float in key_times(speed):
		extra.append(new_of(local, kt))
	var keys: Array = []
	for t: float in sample_times(0.0, dur, extra):
		keys.append({"t": t, "v": AnimProp.evaluate_float(speed, old_of(local, t), e_dur) * rate_of(local, t), "i": "linear"})
	return keys_prop(keys)


static func map_entry(e: Variant, map: Dictionary, window: Vector2, prefix: String, keep_pitch: bool = false) -> Dictionary:
	if not (e is Dictionary):
		return {}
	var ed: Dictionary = e
	if bool(ed.get("muted", false)):
		return {}
	var e_start: float = float(ed.get("start", 0.0))
	var e_dur: float = float(ed.get("duration", 0.0))
	var lo: float = maxf(e_start, window.x)
	var hi: float = minf(e_start + e_dur, window.y)
	if hi - lo <= TINY:
		return {}
	var p0: float = new_of(map, lo)
	var p1: float = new_of(map, hi)
	var start: float = minf(p0, p1)
	var dur: float = absf(p1 - p0)
	if dur <= TINY:
		return {}
	var forward: bool = p1 >= p0
	var u0: float = (lo if forward else hi) - e_start
	var speed: Dictionary = ed.get("speed", AnimProp.make(1.0))
	var local: Dictionary = shifted(map, start, e_start)
	var out: Dictionary = ed.duplicate(true)
	out["id"] = prefix + String(ed.get("id", ""))
	out["start"] = start
	out["duration"] = dur
	out["in_offset"] = float(ed.get("in_offset", 0.0)) + speed_integral(speed, e_dur, u0)
	out["speed"] = mapped_speed(speed, e_dur, local, dur)
	out["volume"] = retime(ed.get("volume", AnimProp.make(1.0)), local, 0.0, dur, e_dur)
	out["pan"] = retime(ed.get("pan", AnimProp.make(0.0)), local, 0.0, dur, e_dur)
	out["effects"] = retime_effects(ed.get("effects", []), local, 0.0, dur, e_dur)
	var rate: float = (hi - lo) / dur
	var fade_in: float = maxf(float(ed.get("fade_in", 0.0)) - (lo - e_start), 0.0) / rate
	var fade_out: float = maxf(float(ed.get("fade_out", 0.0)) - (e_start + e_dur - hi), 0.0) / rate
	out["fade_in"] = fade_in if forward else fade_out
	out["fade_out"] = fade_out if forward else fade_in
	if keep_pitch:
		out["keep_pitch"] = true
	if out.get("pitch_keep") is Dictionary and (keep_pitch or AnimProp.is_animated(out["pitch_keep"])):
		out["pitch_keep"] = AnimProp.make(1.0 if bool(out.get("keep_pitch", false)) else 0.0)
	return out


static func _session() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/Session")
	return null


static func outside_context(doc: Project, seq: Sequence) -> Dictionary:
	var s: Node = _session()
	if doc == null or seq == null or s == null or not s.has_method("outside_for"):
		return {}
	var raw: Variant = s.call("outside_for", doc, seq.id)
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return {}
	var ctx: Dictionary = raw
	var parent: Sequence = doc.sequence_by_id(String(ctx.get("parent", "")))
	if parent == null or parent == seq:
		return {}
	var n: Clip = parent.clip_by_id(String(ctx.get("clip", "")))
	if n == null or nest_sequence_id(doc, n) != seq.id:
		return {}
	return {"parent": parent, "clip": n}


static func outside_tracks(doc: Project, seq: Sequence, handles: Dictionary) -> Array:
	var ctx: Dictionary = outside_context(doc, seq)
	if ctx.is_empty():
		return []
	return outside_from(doc, seq, ctx["parent"], ctx["clip"], handles)


static func outside_from(doc: Project, seq: Sequence, parent: Sequence, n: Clip, handles: Dictionary) -> Array:
	var out: Array = []
	var skip: Dictionary = {n.id: true}
	for f: Clip in parent.linked(n):
		skip[f.id] = true
	var level: Array = AudioGraph.own_tracks(doc, parent, handles)
	level.append_array(nest_tracks(doc, parent, handles, 0, PackedStringArray(), skip))
	AudioGraph.ensure_feed_targets(parent, level)
	level = resolve_mute_solo(level)
	var map: Dictionary = inverse_nest_map(n)
	var t_a: float = new_of(map, 0.0)
	var t_b: float = new_of(map, maxf(parent.duration(), n.end()))
	var t0: float = minf(t_a, t_b)
	var t1: float = maxf(t_a, t_b)
	var keep_pitch: bool = absf(float(map["a"]) - 1.0) > TINY
	var parts: Array = outside_parts(n, seq)
	if not parts.is_empty():
		map = {"parts": parts}
		var span: Vector2 = outside_span(parts, maxf(parent.duration(), n.end()))
		t0 = span.x
		t1 = span.y
	if AudioGraph.feeds_on():
		return outside_fed(level, map, t0, t1, keep_pitch)
	for x: Variant in level:
		var xd: Dictionary = x
		var clips: Array = outside_clips(xd.get("clips", []), map, keep_pitch)
		if clips.is_empty():
			continue
		out.append({
			"id": OUTSIDE_PREFIX + String(xd.get("id", "")),
			"owner": "",
			"outside": true,
			"muted": false,
			"solo": false,
			"volume": retime(xd.get("volume", AnimProp.make(1.0)), map, t0, t1, t1 - t0),
			"pan": retime(xd.get("pan", AnimProp.make(0.0)), map, t0, t1, t1 - t0),
			"effects": retime_effects(xd.get("effects", []), map, t0, t1, t1 - t0),
			"clips": clips,
		})
	return out


static func outside_fed(level: Array, map: Dictionary, t0: float, t1: float, keep_pitch: bool) -> Array:
	var by_id: Dictionary = {}
	var clips_of: Dictionary = {}
	for x: Variant in level:
		var xd: Dictionary = x
		var id: String = String(xd.get("id", ""))
		by_id[id] = xd
		clips_of[id] = outside_clips(xd.get("clips", []), map, keep_pitch)
	var needed: Dictionary = needed_ids(by_id, clips_of)
	var out: Array = []
	for x: Variant in level:
		var xd: Dictionary = x
		var id: String = String(xd.get("id", ""))
		if not needed.has(id):
			continue
		var entry: Dictionary = {
			"id": OUTSIDE_PREFIX + id,
			"owner": "",
			"outside": true,
			"muted": false,
			"solo": false,
			"volume": retime(xd.get("volume", AnimProp.make(1.0)), map, t0, t1, t1 - t0),
			"pan": retime(xd.get("pan", AnimProp.make(0.0)), map, t0, t1, t1 - t0),
			"effects": retime_effects(xd.get("effects", []), map, t0, t1, t1 - t0),
			"clips": clips_of[id],
		}
		var feed: String = String(xd.get(AudioGraph.FEED_KEY, ""))
		if not feed.is_empty() and by_id.has(feed):
			entry[AudioGraph.FEED_KEY] = OUTSIDE_PREFIX + feed
		out.append(entry)
	return out


static func outside_clips(list: Variant, map: Dictionary, keep_pitch: bool) -> Array:
	var clips: Array = []
	if not (list is Array):
		return clips
	if not map.has("parts"):
		for e: Variant in (list as Array):
			var me: Dictionary = map_entry(e, map, Vector2(-FAR, FAR), OUTSIDE_PREFIX, keep_pitch)
			if not me.is_empty():
				clips.append(me)
		return clips
	var parts: Array = map["parts"]
	for j: int in parts.size():
		var part: Dictionary = parts[j]
		for e: Variant in (list as Array):
			var me: Dictionary = map_entry(e, part["m"], part["w"], OUTSIDE_PREFIX, keep_pitch)
			if me.is_empty():
				continue
			me["id"] = LoopAudio.piece_id(String(me["id"]), j)
			clips.append(me)
	return clips


static func outside_parts(n: Clip, inner: Sequence) -> Array:
	var out: Array = []
	var win: Vector2 = loop_window_of(n, inner)
	if win == Vector2.ZERO:
		return out
	var maps: Array[Dictionary] = []
	var spans: Array[Vector2] = []
	for piece: Dictionary in LoopAudio.pieces_in(n, win, n.loop_forward()):
		var p: Clip = LoopAudio.piece_clip(n, piece)
		var m: Dictionary = inverse_nest_map(p)
		maps.append(m)
		spans.append(_sorted(new_of(m, p.start), new_of(m, p.end())))
	if maps.is_empty():
		return out
	var covered: Array[Vector2] = []
	var raw: Array = []
	for i: int in maps.size():
		for u: Vector2 in _uncovered(spans[i], covered):
			raw.append({"u": u, "m": maps[i]})
		covered.append(spans[i])
	var m0: Dictionary = maps[0]
	var head: float = new_of(m0, n.start)
	var head_ray: Vector2 = Vector2(head - FAR, head) if new_of(m0, n.start - 1.0) < head else Vector2(head, head + FAR)
	for u2: Vector2 in _uncovered(head_ray, covered):
		raw.append({"u": u2, "m": m0})
	var ml: Dictionary = maps[maps.size() - 1]
	var tail: float = new_of(ml, n.end())
	var tail_ray: Vector2 = Vector2(tail, tail + FAR) if new_of(ml, n.end() + 1.0) > tail else Vector2(tail - FAR, tail)
	for u3: Vector2 in _uncovered(tail_ray, covered):
		raw.append({"u": u3, "m": ml})
	raw.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["u"] as Vector2).x < (b["u"] as Vector2).x)
	for r: Dictionary in raw:
		if not out.is_empty():
			var last: Dictionary = out[out.size() - 1]
			if absf((last["u"] as Vector2).y - (r["u"] as Vector2).x) <= PART_JOIN and _same_map(last["m"], r["m"]):
				last["u"] = Vector2((last["u"] as Vector2).x, (r["u"] as Vector2).y)
				continue
		out.append({"u": r["u"], "m": r["m"]})
	if out.size() == 1 and _same_map(out[0]["m"], inverse_nest_map(n)):
		return []
	for part: Dictionary in out:
		var u: Vector2 = part["u"]
		part["w"] = _sorted(old_of(part["m"], u.x), old_of(part["m"], u.y))
	return out


static func outside_span(parts: Array, parent_end: float) -> Vector2:
	var lo: float = INF
	var hi: float = -INF
	for part: Variant in parts:
		var pd: Dictionary = part
		var w: Vector2 = pd["w"]
		var a: float = maxf(w.x, 0.0)
		var b: float = minf(w.y, parent_end)
		if b < a:
			continue
		var ua: float = new_of(pd["m"], a)
		var ub: float = new_of(pd["m"], b)
		lo = minf(lo, minf(ua, ub))
		hi = maxf(hi, maxf(ua, ub))
	if lo > hi:
		return Vector2.ZERO
	return Vector2(lo, hi)


static func part_map(map: Dictionary, t: float) -> Dictionary:
	var parts: Array = map["parts"]
	var best: Dictionary = parts[0]
	var gap: float = INF
	for part: Variant in parts:
		var u: Vector2 = (part as Dictionary)["u"]
		var d: float = maxf(u.x - t, t - u.y)
		if d <= 0.0:
			return (part as Dictionary)["m"]
		if d < gap:
			gap = d
			best = part
	return best["m"]


static func part_from(map: Dictionary, s: float) -> Dictionary:
	var parts: Array = map["parts"]
	for part: Variant in parts:
		var w: Vector2 = (part as Dictionary)["w"]
		if s >= w.x and s <= w.y:
			return (part as Dictionary)["m"]
	return (parts[0] as Dictionary)["m"]


static func _sorted(a: float, b: float) -> Vector2:
	return Vector2(minf(a, b), maxf(a, b))


static func _same_map(a: Dictionary, b: Dictionary) -> bool:
	return absf(float(a["a"]) - float(b["a"])) <= TINY and absf(float(a["b"]) - float(b["b"])) <= PART_JOIN


static func _uncovered(span: Vector2, covered: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = [span]
	for c: Vector2 in covered:
		var next: Array[Vector2] = []
		for u: Vector2 in out:
			if c.y <= u.x or c.x >= u.y:
				next.append(u)
				continue
			if c.x - u.x > TINY:
				next.append(Vector2(u.x, c.x))
			if u.y - c.y > TINY:
				next.append(Vector2(c.y, u.y))
		out = next
	return out


static func parent_time(n: Clip, s: float) -> float:
	if n == null:
		return s
	return new_of(nest_map(n), s)

extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const ViewMap := preload("res://doc/view_map.gd")
const ViewStreams := preload("res://doc/view_streams.gd")
const Clip := preload("res://doc/clip.gd")
const SoundEnvelopes := preload("res://engine/sound_envelopes.gd")
const ReactShape := preload("res://engine/react_shape.gd")
const PAIR_VIEW_ID := "pair_view"
const KIND_MIX := "mix"
const KIND_VIEWS := "views"
const KIND_VIEW := "view"
const GRID := 10
const SETS_MAX := 64
const SIGS_MAX := 16
const NEST_DEPTH := 4
const WRAP_EPS := 0.002

static var _sigs: Dictionary = {}
static var _sets: Dictionary = {}
static var builds: int = 0
static var _plant_no_offsets: bool = false
static var _plant_no_nests: bool = false


static func forget() -> void:
	_sigs = {}
	_sets = {}


static func is_mix_kind(kind: String) -> bool:
	return kind == KIND_MIX or kind == KIND_VIEWS or kind == KIND_VIEW


static func _has_sound(doc: Object, c: Object) -> bool:
	var m: Object = doc.call("media_by_id", String(c.get("media_id")))
	if m == null or String(m.get("kind")) == "sequence":
		return false
	return bool(m.get("has_audio")) or String(m.get("kind")) == "audio"


static func nest_sid(doc: Object, c: Object) -> String:
	if doc == null or c == null:
		return ""
	var sid: String = String(c.get("sequence_id"))
	if not sid.is_empty():
		return sid
	var m: Object = doc.call("media_by_id", String(c.get("media_id")))
	if m != null and String(m.get("kind")) == "sequence":
		return String(m.get("sequence_id"))
	return ""


static func _carrier(doc: Object, seq: Object, tr: Object, c: Object, sid: String) -> bool:
	if bool(tr.call("is_sound", c)):
		return true
	for fv: Variant in seq.call("linked", c):
		var f: Object = fv
		if f == c or nest_sid(doc, f) != sid:
			continue
		var ft: Object = seq.call("track_of", String(f.get("id")))
		if ft != null and bool(ft.call("is_sound", f)):
			return false
	return true


static func pair_entry(c: Object) -> Dictionary:
	if c == null:
		return {}
	for e: Variant in c.get("effects"):
		var ed: Dictionary = e
		if String(ed.get("id", "")) == PAIR_VIEW_ID and bool(ed.get("enabled", true)):
			return ed
	return {}


static func pair_clips(seq: Object) -> Array:
	var out: Array = []
	if seq == null:
		return out
	for tr: Variant in seq.call("picture_tracks"):
		for c: Variant in (tr as Object).get("clips"):
			if not pair_entry(c).is_empty():
				out.append(c)
	return out


static func pair_sources(seq: Object) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if seq == null:
		return out
	for tv: Variant in seq.call("picture_tracks"):
		var tr: Object = tv
		for cv: Variant in tr.get("clips"):
			var v: Object = cv
			if (v.get("effects") as Array).is_empty() or not bool(tr.call("is_picture", v)):
				continue
			for ev: Variant in v.get("effects"):
				var e: Dictionary = ev
				if String(e.get("id", "")) != PAIR_VIEW_ID or not bool(e.get("enabled", true)):
					continue
				var map: Dictionary = ViewMap.of(e)
				if map.is_empty():
					continue
				out.append({"clip": v, "entry": e, "map": map})
	ViewMap.share_every(out)
	return out


static func _track_sig(t: Object, parts: PackedStringArray) -> void:
	parts.append("%s,%s,%s,%d" % [String(t.get("id")), str(t.get("muted")), str(t.get("solo")), (t.get("volume") as Dictionary).hash()])
	for cv: Variant in t.get("clips"):
		var c: Object = cv
		parts.append("%s,%s,%s,%s,%s,%s,%d,%d" % [String(c.get("id")), String(c.get("media_id")), str(c.get("start")), str(c.get("duration")), str(c.get("in_offset")), str(c.get("enabled")), (c.get("speed") as Dictionary).hash(), (c.get("audio") as Dictionary).hash()])


static func _nest_sig(doc: Object, seq: Object, parts: PackedStringArray, depth: int, anc: PackedStringArray) -> void:
	if depth >= NEST_DEPTH:
		return
	for tv: Variant in seq.call("all_tracks"):
		var tr: Object = tv
		for cv: Variant in tr.get("clips"):
			var c: Object = cv
			var sid: String = nest_sid(doc, c)
			if sid.is_empty() or anc.has(sid):
				continue
			var inner: Object = doc.call("sequence_by_id", sid)
			if inner == null:
				continue
			parts.append("nest,%s,%s,%s,%s,%s,%s,%s,%s,%s,%d,%d,%d" % [String(tr.get("id")), String(c.get("id")), sid, str(c.get("start")), str(c.get("duration")), str(c.get("in_offset")), str(c.get("enabled")), str(c.get("loop")), str(c.get("loop_in")), (c.get("speed") as Dictionary).hash(), (c.get("audio") as Dictionary).hash(), (c.get("nest") as Dictionary).hash()])
			parts.append("in,%d" % [(inner.get("master_volume") as Dictionary).hash()])
			for itv: Variant in inner.call("sound_carriers"):
				_track_sig(itv, parts)
			var deeper: PackedStringArray = anc.duplicate()
			deeper.append(sid)
			_nest_sig(doc, inner, parts, depth + 1, deeper)
			parts.append("out")


static func arrangement(doc: Object, seq: Object) -> String:
	var key: String = str(doc.get_instance_id()) + "|" + str(int(doc.get("serial"))) + "|" + String(seq.get("id"))
	var hit: Variant = _sigs.get(key, null)
	if hit is String:
		return hit
	var parts: PackedStringArray = PackedStringArray()
	for tr: Variant in seq.call("sound_carriers"):
		_track_sig(tr, parts)
	for pc: Variant in pair_clips(seq):
		var v: Object = pc
		parts.append("pv,%s,%s,%s,%d" % [String(v.get("id")), str(v.get("start")), str(v.get("duration")), pair_entry(v).hash()])
	var anc: PackedStringArray = PackedStringArray([String(seq.get("id"))])
	_nest_sig(doc, seq, parts, 0, anc)
	var text: String = "|".join(parts)
	var out: String = str(text.hash()) + ":" + str(text.length())
	if _sigs.size() >= SIGS_MAX:
		_sigs = {}
	_sigs[key] = out
	return out


static func label_of(doc: Object, seq: Object, own: Object, src: Dictionary) -> String:
	var kind: String = String(src.get("kind", ""))
	if kind == KIND_MIX:
		return "Everything you hear here"
	if kind == KIND_VIEWS:
		return "Pair View: the view on screen"
	var n: int = int(src.get("view", 0))
	var names: PackedStringArray = PackedStringArray()
	var pc: Object = _chosen_pair(doc, seq, own, src)
	if pc != null:
		names = ViewMap.region_names(pair_entry(pc))
	var name: String = names[n] if n >= 0 and n < names.size() else "view %d" % (n + 1)
	return "Pair View: " + name


static func _chosen_pair(doc: Object, seq: Object, own: Object, src: Dictionary) -> Object:
	var id: String = String(src.get("clip", ""))
	if not id.is_empty() and doc != null:
		var c: Object = doc.call("clip_by_id", id)
		if c != null and not pair_entry(c).is_empty():
			return c
	if own != null and not pair_entry(own).is_empty():
		return own
	var list: Array = pair_clips(seq)
	return list[0] if not list.is_empty() else null


static func view_choices(doc: Object, seq: Object, own: Object) -> Array:
	var out: Array = []
	for pc: Variant in pair_clips(seq):
		var v: Object = pc
		var e: Dictionary = pair_entry(v)
		var names: PackedStringArray = ViewMap.region_names(e)
		var n: int = maxi(ViewMap.crop_count(e), 1)
		for i: int in n:
			var nm: String = names[i] if i < names.size() else "view %d" % (i + 1)
			out.append({"clip": String(v.get("id")), "view": i, "label": nm, "own": v == own, "clip_label": String(v.get("label")) if not String(v.get("label")).is_empty() else String(v.get("id"))})
	return out


static func _env_for(doc: Object, c: Object, edges: PackedFloat64Array) -> Dictionary:
	var m: Object = doc.call("media_by_id", String(c.get("media_id")))
	var aud: Variant = c.get("audio")
	var stream: int = int((aud as Dictionary).get("stream", 0.0)) if aud is Dictionary else 0
	return SoundEnvelopes.entry(String(m.get("path")), stream, edges)


static func _span(a: float, b: float) -> PackedFloat64Array:
	return PackedFloat64Array([a, b])


static func _cut(spans: PackedFloat64Array, a: float, b: float) -> PackedFloat64Array:
	var cut: PackedFloat64Array = PackedFloat64Array()
	for i: int in range(0, spans.size() - 1, 2):
		var s0: float = maxf(spans[i], a)
		var s1: float = minf(spans[i + 1], b)
		if s1 > s0:
			cut.append(s0)
			cut.append(s1)
	return cut


static func _clip_part(doc: Object, tr: Object, c: Object, edges: PackedFloat64Array, spans: PackedFloat64Array, shifts: Array = []) -> Dictionary:
	var a: float = float(c.get("start"))
	var cut: PackedFloat64Array = _cut(spans, a, a + float(c.get("duration")))
	if cut.is_empty():
		return {}
	return {"clip": c, "track": tr, "env": _env_for(doc, c, edges), "spans": cut, "chain": [], "shifts": shifts}


static func _audible_tracks(seq: Object) -> Array:
	var out: Array = []
	var solo: bool = false
	var carriers: Array = seq.call("sound_carriers")
	for tr: Variant in carriers:
		if bool((tr as Object).get("solo")):
			solo = true
	for tr2: Variant in carriers:
		var t: Object = tr2
		if bool(t.get("muted")):
			continue
		if solo and not bool(t.get("solo")):
			continue
		out.append(t)
	return out


static func _view_spans(e: Dictionary, video: Object, view: int) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var vs: float = float(video.get("start"))
	var ve: float = vs + float(video.get("duration"))
	var ch: Array[Dictionary] = ViewMap.changes(e, video)
	if ch.is_empty():
		if view == 0:
			out.append(vs)
			out.append(ve)
		return out
	for i: int in ch.size():
		if int(ch[i]["view"]) != view:
			continue
		var a: float = vs + (0.0 if i == 0 else float(ch[i]["u"]))
		var b: float = ve if i + 1 >= ch.size() else vs + float(ch[i + 1]["u"])
		if b > a:
			out.append(a)
			out.append(b)
	return out


static func _gap(video: Object, t: float) -> float:
	var vs: float = float(video.get("start"))
	var ve: float = vs + float(video.get("duration"))
	if t >= vs and t < ve:
		return 0.0
	return vs - t if vs > t else t - ve


static func _best_piece(sources: Array[Dictionary], uid: String, c: Object, tid: String) -> Dictionary:
	var best: Dictionary = {}
	var at: float = float(c.get("start"))
	for src: Dictionary in sources:
		if String((src["entry"] as Dictionary).get("uid", "")) != uid:
			continue
		var ov: Object = src["clip"]
		if not ViewMap.reaches(src["map"], ov, c, tid):
			continue
		if best.is_empty():
			best = src
			continue
		var bv: Object = best["clip"]
		var go: float = _gap(ov, at)
		var gb: float = _gap(bv, at)
		if go < gb or (go == gb and float(ov.get("start")) < float(bv.get("start"))):
			best = src
	return best


static func _shift(video: Object, e: Dictionary, index: int) -> Dictionary:
	var fixed: bool = not e.has(ViewMap.HEARD_KEY) and not AnimProp.is_animated(ViewMap.offset_prop(e, index))
	return {"video": video, "e": e, "index": index, "fixed": fixed, "d": ViewMap.offset_at(e, index, video, 0.0) if fixed else 0.0}


static func heard_shifts(sources: Array[Dictionary], c: Object, tid: String) -> Array:
	var out: Array = []
	if _plant_no_offsets:
		return out
	for src: Dictionary in sources:
		var e: Dictionary = src["entry"]
		var video: Object = src["clip"]
		var map: Dictionary = src["map"]
		if not ViewMap.any_offset(e) or not ViewMap.reaches(map, video, c, tid):
			continue
		var best: Dictionary = _best_piece(sources, String(e.get("uid", "")), c, tid)
		if best.is_empty() or best["clip"] != video:
			continue
		var views: PackedInt32Array = ViewStreams.views_playing(map, tid, c, video, -1) if ViewStreams.on(map) else ViewMap.views_hearing(map, tid, String(c.get("id")))
		if views.is_empty():
			continue
		var heard: Dictionary = ViewMap.heard_entry(e, video, c, views, false)
		if ViewMap.has_offset(heard, 0):
			out.append(_shift(video, heard, 0))
	return out


static func view_shifts(sources: Array[Dictionary], video: Object, e: Dictionary, view: int, c: Object, tid: String) -> Array:
	var out: Array = []
	if _plant_no_offsets:
		return out
	var best: Dictionary = _best_piece(sources, String(e.get("uid", "")), c, tid)
	var bv: Object = best["clip"] if not best.is_empty() else video
	var be: Dictionary = best["entry"] if not best.is_empty() else e
	if ViewMap.has_offset(be, view):
		out.append(_shift(bv, be, view))
	return out


static func _allow_of(n: Object) -> Array:
	var raw: Variant = (n.get("nest") as Dictionary).get("audio_allow", [])
	if raw is Array:
		return raw
	if raw is PackedStringArray:
		return Array(raw)
	return []


static func _nest_into(doc: Object, seq: Object, tr: Object, n: Object, sid: String, edges: PackedFloat64Array, spans: PackedFloat64Array, chain: Array, anc: PackedStringArray, out: Array) -> void:
	if chain.size() >= NEST_DEPTH or anc.has(sid):
		return
	if not bool((n.get("nest") as Dictionary).get("hear_audio", true)):
		return
	var inner: Object = doc.call("sequence_by_id", sid)
	if inner == null:
		return
	var own_spans: PackedFloat64Array = spans
	if chain.is_empty():
		var a: float = float(n.get("start"))
		own_spans = _cut(spans, a, a + float(n.get("duration")))
		if own_spans.is_empty():
			return
	var win: Vector2 = Vector2.ZERO
	if bool(n.get("loop")):
		var w: Vector2 = n.call("loop_window", float(inner.call("duration")))
		if w.y - w.x > Clip.LOOP_MIN:
			win = w
	var deeper: Array = chain.duplicate()
	deeper.append({"clip": n, "track": tr, "sound": bool(tr.call("is_sound", n)), "win": win, "fwd": bool(n.call("loop_forward")), "inner": inner})
	var anc2: PackedStringArray = anc.duplicate()
	anc2.append(sid)
	var none: Array[Dictionary] = []
	_heard_parts(doc, inner, edges, own_spans, deeper, anc2, _allow_of(n), none, out)


static func _heard_parts(doc: Object, seq: Object, edges: PackedFloat64Array, spans: PackedFloat64Array, chain: Array, anc: PackedStringArray, allow: Array, sources: Array[Dictionary], out: Array) -> void:
	for tv: Variant in _audible_tracks(seq):
		var t: Object = tv
		if not allow.is_empty() and not allow.has(String(t.get("id"))):
			continue
		for cv: Variant in t.get("clips"):
			var c: Object = cv
			if not bool(c.get("enabled")):
				continue
			var sid: String = nest_sid(doc, c)
			if not sid.is_empty():
				if not _plant_no_nests and _carrier(doc, seq, t, c, sid):
					_nest_into(doc, seq, t, c, sid, edges, spans, chain, anc, out)
				continue
			if not bool(t.call("is_sound", c)) or not _has_sound(doc, c):
				continue
			if chain.is_empty():
				var part: Dictionary = _clip_part(doc, t, c, edges, spans, heard_shifts(sources, c, String(t.get("id"))))
				if not part.is_empty():
					out.append(part)
			else:
				out.append({"clip": c, "track": t, "env": _env_for(doc, c, edges), "spans": spans, "chain": chain, "shifts": []})
	if _plant_no_nests:
		return
	for pv: Variant in seq.call("picture_tracks"):
		var vt: Object = pv
		if not allow.is_empty() and not allow.has(String(vt.get("id"))):
			continue
		for nv: Variant in vt.get("clips"):
			var n: Object = nv
			if not bool(n.get("enabled")):
				continue
			var vsid: String = nest_sid(doc, n)
			if vsid.is_empty() or bool(vt.call("is_sound", n)) or not _carrier(doc, seq, vt, n, vsid):
				continue
			_nest_into(doc, seq, vt, n, vsid, edges, spans, chain, anc, out)


static func part_set(doc: Object, seq: Object, own: Object, src: Dictionary, edges: PackedFloat64Array) -> Dictionary:
	var kind: String = String(src.get("kind", ""))
	var key: String = arrangement(doc, seq) + "|" + kind + "|" + String(src.get("clip", "")) + "|" + str(int(src.get("view", 0))) + "|" + (String(own.get("id")) if own != null else "") + "|" + str(edges.size()) + ":" + str(hash(edges))
	var hit: Variant = _sets.get(key, null)
	if hit is Dictionary:
		return hit
	builds += 1
	var parts: Array = []
	var sources: Array[Dictionary] = pair_sources(seq)
	if kind == KIND_MIX:
		_heard_parts(doc, seq, edges, _span(-INF, INF), [], PackedStringArray([String(seq.get("id"))]), [], sources, parts)
	else:
		var audible: Array = _audible_tracks(seq)
		var videos: Array = []
		var chosen: Object = _chosen_pair(doc, seq, own, src) if kind == KIND_VIEW else null
		if kind == KIND_VIEW:
			if chosen != null:
				videos.append(chosen)
		elif own != null and not pair_entry(own).is_empty():
			videos.append(own)
		else:
			videos = pair_clips(seq)
		for vv: Variant in videos:
			var video: Object = vv
			var e: Dictionary = pair_entry(video)
			var map: Dictionary = ViewMap.of(e)
			if map.is_empty():
				continue
			var count: int = maxi(ViewMap.crop_count(e), 1)
			var views: PackedInt32Array = PackedInt32Array()
			if kind == KIND_VIEW:
				views.append(clampi(int(src.get("view", 0)), 0, count - 1))
			else:
				for i: int in count:
					views.append(i)
			for vi: int in views:
				var spans: PackedFloat64Array = _span(float(video.get("start")), float(video.get("start")) + float(video.get("duration"))) if kind == KIND_VIEW else _view_spans(e, video, vi)
				if spans.is_empty():
					continue
				for grp: Dictionary in ViewMap.view_sounds(map, seq, video, vi):
					var t2: Object = grp["track"]
					if not audible.has(t2):
						continue
					for c2: Variant in grp["clips"]:
						var cc: Object = c2
						if not bool(cc.get("enabled")) or not bool(t2.call("is_sound", cc)) or not _has_sound(doc, cc):
							continue
						var part2: Dictionary = _clip_part(doc, t2, cc, edges, spans, view_shifts(sources, video, e, vi, cc, String(t2.get("id"))))
						if not part2.is_empty():
							parts.append(part2)
	var end: float = 0.0
	for pv: Variant in parts:
		var sp: PackedFloat64Array = (pv as Dictionary)["spans"]
		if not sp.is_empty():
			end = maxf(end, sp[sp.size() - 1])
	var out: Dictionary = {"key": key, "parts": parts, "end": end}
	if _sets.size() >= SETS_MAX:
		_sets = {}
	_sets[key] = out
	return out


static func state(pset: Dictionary) -> Dictionary:
	var ser: int = 0
	var done: bool = true
	var waiting: PackedStringArray = PackedStringArray()
	for p: Variant in pset["parts"]:
		var env: Dictionary = (p as Dictionary)["env"]
		ser += int(env["serial"])
		if not bool(env["done"]):
			done = false
			waiting.append(String(env["key"]))
	return {"serial": ser, "done": done, "waiting": waiting}


static func band_ref(peaks: PackedFloat32Array, band: int) -> float:
	if band < 0 or band >= peaks.size():
		return 0.0
	if peaks.size() == 1:
		return peaks[0]
	var top: float = 0.0
	for v: float in peaks:
		top = maxf(top, v)
	return sqrt(maxf(peaks[band], 0.0) * top)


static func refs(pset: Dictionary, band_n: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(band_n)
	for p: Variant in pset["parts"]:
		var env: Dictionary = (p as Dictionary)["env"]
		var peaks: PackedFloat32Array = env["peaks"]
		for b: int in band_n:
			out[b] = maxf(out[b], band_ref(peaks, b))
	return out


static func _prop_at(v: Variant, t: float, dur: float) -> float:
	if v is Dictionary:
		var p: Dictionary = v
		return AnimProp.evaluate_float(p, t, dur) if AnimProp.is_animated(p) else float(AnimProp.static_value(p))
	if v is float or v is int:
		return float(v)
	return 1.0


static func _gain_at(c: Object, tr: Object, t: float) -> float:
	var g: float = 1.0
	var aud: Variant = c.get("audio")
	if aud is Dictionary and (aud as Dictionary).get("volume", null) is Dictionary:
		g *= _prop_at((aud as Dictionary)["volume"], t - float(c.get("start")), float(c.get("duration")))
	if tr != null:
		var tv: Variant = tr.get("volume")
		if tv is Dictionary:
			g *= _prop_at(tv, t, 0.0)
	return maxf(g, 0.0)


static func _shift_at(shifts: Array, t: float) -> float:
	var d: float = 0.0
	for sv: Variant in shifts:
		var sd: Dictionary = sv
		if bool(sd["fixed"]):
			d += float(sd["d"])
		else:
			var video: Object = sd["video"]
			d += ViewMap.offset_at(sd["e"], int(sd["index"]), video, t - float(video.get("start")))
	return d


static func _point(part: Dictionary, t: float) -> PackedFloat64Array:
	var chain: Array = part["chain"]
	var levels: int = chain.size()
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(levels + 3)
	var g: float = 1.0
	var tt: float = t
	out[1] = t
	for k: int in levels:
		var link: Dictionary = chain[k]
		var n: Object = link["clip"]
		g *= _gain_at(n, link["track"] if bool(link["sound"]) else null, tt)
		tt = float(n.call("source_time", tt))
		var win: Vector2 = link["win"]
		if win != Vector2.ZERO:
			tt = Clip.wrap_in(tt, win, bool(link["fwd"]))
		g *= maxf(_prop_at((link["inner"] as Object).get("master_volume"), tt, 0.0), 0.0)
		out[k + 2] = tt
	var c: Object = part["clip"]
	g *= _gain_at(c, part["track"], tt)
	out[0] = g
	out[levels + 2] = float(c.call("source_time", tt)) - _shift_at(part["shifts"], tt)
	return out


static func _still(v: Variant) -> bool:
	return not (v is Dictionary) or not AnimProp.is_animated(v)


static func _linear(part: Dictionary) -> bool:
	if not (part["chain"] as Array).is_empty():
		return false
	var c: Object = part["clip"]
	if not _still(c.get("speed")) or not _still((part["track"] as Object).get("volume")):
		return false
	var aud: Variant = c.get("audio")
	if aud is Dictionary and not _still((aud as Dictionary).get("volume", null)):
		return false
	for sv: Variant in part["shifts"]:
		if not bool((sv as Dictionary)["fixed"]):
			return false
	return true


static func _runs(spans: PackedFloat64Array, a: int, n: int, rate: float) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for si: int in range(0, spans.size() - 1, 2):
		var i0: int = maxi(a, int(ceil(spans[si] * rate - 0.5)))
		var i1: int = mini(a + n, int(ceil(spans[si + 1] * rate - 0.5)))
		if i1 > i0:
			out.append(i0 - a)
			out.append(i1 - a)
	return out


static func plan(pset: Dictionary, band_n: int, a: int, n: int) -> Array:
	var out: Array = []
	if n <= 0:
		return out
	var rate: float = float(ReactShape.RATE)
	for pv: Variant in pset["parts"]:
		var part: Dictionary = pv
		var env: Dictionary = part["env"]
		var cnt: int = int(env["count"])
		if cnt <= 0:
			continue
		if _linear(part):
			var runs: PackedInt32Array = _runs(part["spans"], a, n, rate)
			if runs.is_empty():
				continue
			var ta: float = (float(a) + 0.5) / rate
			var pa0: PackedFloat64Array = _point(part, ta)
			var pb0: PackedFloat64Array = _point(part, ta + 1.0)
			out.append({"vals": env["values"], "stride": maxi(int(env["bands"]), 1), "cnt": cnt, "rate": rate, "runs": runs, "s0": pa0[2], "k": (pb0[2] - pa0[2]) / rate, "g": pa0[0]})
			continue
		var chain: Array = part["chain"]
		var levels: int = chain.size()
		var lo: PackedFloat64Array = PackedFloat64Array()
		var hi: PackedFloat64Array = PackedFloat64Array()
		for k: int in range(1, levels):
			var nk: Object = (chain[k] as Dictionary)["clip"]
			lo.append(float(nk.get("start")))
			hi.append(float(nk.get("start")) + float(nk.get("duration")))
		if levels > 0:
			var leaf: Object = part["clip"]
			lo.append(float(leaf.get("start")))
			hi.append(float(leaf.get("start")) + float(leaf.get("duration")))
		var idx: PackedInt32Array = PackedInt32Array()
		idx.resize(n)
		idx.fill(-1)
		var gain: PackedFloat32Array = PackedFloat32Array()
		gain.resize(n)
		var any: bool = false
		var spans: PackedFloat64Array = part["spans"]
		var src_at: int = levels + 2
		for si: int in range(0, spans.size() - 1, 2):
			var i0: int = maxi(a, int(ceil(spans[si] * rate - 0.5)))
			var i1: int = mini(a + n, int(ceil(spans[si + 1] * rate - 0.5)))
			if i1 <= i0:
				continue
			var g0: int = i0
			var pa: PackedFloat64Array = _point(part, (float(g0) + 0.5) / rate)
			while g0 < i1:
				var g1: int = mini(g0 + GRID, i1)
				var pb: PackedFloat64Array = _point(part, (float(g1) + 0.5) / rate)
				var exact: bool = false
				if levels > 0:
					var pm: PackedFloat64Array = _point(part, (float(g0 + g1) * 0.5 + 0.5) / rate)
					for k2: int in range(2, src_at + 1):
						if absf(lerpf(pa[k2], pb[k2], 0.5) - pm[k2]) > WRAP_EPS:
							exact = true
							break
				var span: float = float(g1 - g0)
				for i: int in range(g0, g1):
					var f: float = float(i - g0) / span
					var pt: PackedFloat64Array = _point(part, (float(i) + 0.5) / rate) if exact else PackedFloat64Array()
					var inside: bool = true
					for j: int in lo.size():
						var tj: float = pt[j + 2] if exact else lerpf(pa[j + 2], pb[j + 2], f)
						if tj < lo[j] or tj >= hi[j]:
							inside = false
							break
					if not inside:
						continue
					var sv: float = pt[src_at] if exact else lerpf(pa[src_at], pb[src_at], f)
					var ix: int = int(floor(sv * rate))
					if ix < 0 or ix >= cnt:
						continue
					idx[i - a] = ix
					gain[i - a] = pt[0] if exact else lerpf(pa[0], pb[0], f)
					any = true
				g0 = g1
				pa = pb
		if any:
			out.append({"vals": env["values"], "stride": maxi(int(env["bands"]), 1), "idx": idx, "gain": gain})
	return out


static func apply(plans: Array, band_n: int, n: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(maxi(n, 0) * band_n)
	if n <= 0:
		return out
	for pv: Variant in plans:
		var pl: Dictionary = pv
		if pl.has("runs"):
			_apply_linear(pl, band_n, n, out)
			continue
		var vals: PackedFloat32Array = pl["vals"]
		var stride: int = int(pl["stride"])
		var idx: PackedInt32Array = pl["idx"]
		var gain: PackedFloat32Array = pl["gain"]
		var bands: int = mini(band_n, stride)
		for i: int in mini(n, idx.size()):
			var ix: int = idx[i]
			if ix < 0:
				continue
			var g: float = gain[i]
			var o: int = i * band_n
			var r: int = ix * stride
			for b: int in bands:
				var x: float = vals[r + b] * g
				out[o + b] += x * x
	for k: int in out.size():
		out[k] = sqrt(out[k])
	return out


static func _apply_linear(pl: Dictionary, band_n: int, n: int, out: PackedFloat32Array) -> void:
	var vals: PackedFloat32Array = pl["vals"]
	var stride: int = int(pl["stride"])
	var cnt: int = int(pl["cnt"])
	var rate: float = float(pl["rate"])
	var runs: PackedInt32Array = pl["runs"]
	var s0: float = float(pl["s0"])
	var k: float = float(pl["k"])
	var g: float = float(pl["g"])
	var bands: int = mini(band_n, stride)
	for r: int in range(0, runs.size() - 1, 2):
		for i: int in range(runs[r], mini(runs[r + 1], n)):
			var ix: int = int(floor((s0 + float(i) * k) * rate))
			if ix < 0 or ix >= cnt:
				continue
			var o: int = i * band_n
			var ri: int = ix * stride
			for b: int in bands:
				var x: float = vals[ri + b] * g
				out[o + b] += x * x


static func mix_raw(pset: Dictionary, band_n: int, a: int, n: int) -> PackedFloat32Array:
	return apply(plan(pset, band_n, a, n), band_n, n)

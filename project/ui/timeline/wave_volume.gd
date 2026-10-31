extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const VOLUME_PATH := "audio.volume"
const GAIN_ID := "gain"
const SHAPES: Dictionary = {"linear": 0, "equal_power": 1, "s_curve": 2}
const KEEP_AMP := 0.005
const CAP := 8.0
const MEMO_MAX := 4096
const UNITY_EPS := 0.000001
const EDGE_SLACK := 0.001
const LANE_CLIP_MAX := 400
const CROSSFADE_KIND := "crossfade"
const ABUT_SLACK := 0.002

static var _memo: Dictionary = {}
static var _lanes: Dictionary = {}
static var _wins: Dictionary = {}
static var _xf: Dictionary = {}
static var _seq_dur: Dictionary = {}
static var _doc_w: WeakRef = null
static var _doc_id: int = 0
static var _serial: int = -1
static var _live: int = -1
static var stats: Dictionary = {"envs": 0, "env_usec": 0, "lanes": 0, "applied": 0, "points": 0, "usec": 0}
static var last_applied: PackedVector2Array = PackedVector2Array()
static var last_gains: PackedFloat32Array = PackedFloat32Array()


static func reset() -> void:
	_memo.clear()
	_wins.clear()
	_lanes.clear()
	_xf.clear()
	_seq_dur.clear()
	_doc_w = null
	_serial = -1
	_live = -1
	_doc_id = 0


static func _stamp(d: Project) -> void:
	var did: int = d.get_instance_id() if d != null else 0
	var ser: int = d.serial if d != null else 0
	var lv: int = d.undo.live_serial if d != null and d.undo != null else 0
	if did == _doc_id and ser == _serial and lv == _live:
		return
	var narrow: bool = did == _doc_id and d != null and d.undo != null and d.undo.has_live() and _forget_live(d.undo.live_commands())
	_doc_id = did
	_serial = ser
	_live = lv
	_doc_w = weakref(d) if d != null else null
	_lanes.clear()
	_xf.clear()
	_seq_dur.clear()
	if narrow:
		stats["narrow"] = int(stats.get("narrow", 0)) + 1
		return
	_memo.clear()
	_wins.clear()


static func _forget_live(cmds: Array) -> bool:
	var clip_ids: PackedStringArray = PackedStringArray()
	var track_ids: PackedStringArray = PackedStringArray()
	for cmd: Variant in cmds:
		if not (cmd is Object) or not (cmd as Object).has_method("live_key"):
			return false
		var k: String = String((cmd as Object).call("live_key"))
		if not k.begins_with("clip_param|"):
			return false
		var id: String = k.get_slice("|", 1)
		if id.begins_with("seq:"):
			return false
		if id.begins_with("track:"):
			track_ids.append(id.substr(6))
		else:
			clip_ids.append(id)
	for cid: String in clip_ids:
		_memo.erase(cid)
	if not track_ids.is_empty():
		var drop: PackedStringArray = PackedStringArray()
		for key: Variant in _memo.keys():
			if track_ids.has(String((_memo[key] as Dictionary).get("track_id", ""))):
				drop.append(String(key))
		for key2: String in drop:
			_memo.erase(key2)
	return true


static func for_clip(d: Project, s: Sequence, c: Clip, tr: Track = null) -> Dictionary:
	if c == null:
		return {}
	_stamp(d)
	var hit: Variant = _memo.get(c.id, null)
	if hit is Dictionary and is_same((hit as Dictionary)["clip"], c):
		return hit
	return _build(s, c, tr)


static func prepare(d: Project) -> void:
	_stamp(d)


static func cached(s: Sequence, c: Clip) -> Dictionary:
	var hit: Variant = _memo.get(c.id, null)
	if hit is Dictionary and is_same((hit as Dictionary)["clip"], c):
		return hit
	return _build(s, c, null)


static func _build(s: Sequence, c: Clip, tr: Track) -> Dictionary:
	var t: Track = tr
	if t == null and s != null:
		t = s.track_of(c.id)
	var e0: int = Time.get_ticks_usec()
	var d: Project = null
	if _doc_w != null:
		var got: Variant = _doc_w.get_ref()
		if got is Project:
			d = got
	var env: Dictionary = envelope(c, t, s, d)
	stats["env_usec"] = int(stats["env_usec"]) + Time.get_ticks_usec() - e0
	if _memo.size() >= MEMO_MAX:
		_memo.clear()
	_memo[c.id] = env
	return env


static func _num(v: Variant, fallback: float) -> float:
	if v is float or v is int:
		return float(v)
	return fallback


static func _static_of(p: Variant, fallback: float) -> float:
	if p is Dictionary:
		return _num(AnimProp.static_value(p as Dictionary), fallback)
	return _num(p, fallback)


static func static_speed(c: Clip) -> float:
	if AnimProp.is_animated(c.speed):
		return 1.0
	return maxf(absf(float(c.speed.get("v", 1.0))), 0.01)


static func crossfades(t: Track, d: Project = null) -> Dictionary:
	var key: int = t.get_instance_id()
	var hit: Variant = _xf.get(key, null)
	if hit is Dictionary:
		return hit
	var out: Dictionary = {}
	for i: int in range(1, t.clips.size()):
		var c: Clip = t.clips[i]
		if not c.has_transition() or str(c.transition_in.get("kind", "")) != CROSSFADE_KIND:
			continue
		var prev: Clip = t.clips[i - 1]
		if absf(prev.end() - c.start) > ABUT_SLACK or not t.is_sound(c) or not t.is_sound(prev):
			continue
		var span: Vector2 = c.transition_span()
		var cut: float = c.start
		var head: float = cut - span.x
		var tail: float = span.y - cut
		var head_avail: float = INF if c.loop else c.in_offset / static_speed(c)
		head = minf(head, head_avail)
		var m_out: MediaItem = d.media_by_id(prev.media_id) if d != null else null
		if m_out != null and m_out.duration > 0.0 and not prev.loop:
			var left: float = (m_out.duration - prev.in_offset) / static_speed(prev) - prev.duration
			tail = clampf(minf(tail, left), 0.0, tail)
		if head <= 0.0 and tail <= 0.0:
			continue
		var inc: Dictionary = out.get(c.id, {})
		inc["in_off"] = head
		inc["in_len"] = head + tail
		out[c.id] = inc
		var leaving: Dictionary = out.get(prev.id, {})
		leaving["out_off"] = tail
		leaving["out_len"] = head + tail
		out[prev.id] = leaving
	if _xf.size() >= 256:
		_xf.clear()
	_xf[key] = out
	return out


static func _master_dur(s: Sequence) -> float:
	var key: int = s.get_instance_id()
	var hit: Variant = _seq_dur.get(key, null)
	if hit is float:
		return hit
	var dur: float = s.duration()
	_seq_dur[key] = dur
	return dur


static func envelope(c: Clip, t: Track, s: Sequence = null, d: Project = null) -> Dictionary:
	stats["envs"] = int(stats["envs"]) + 1
	if not c.enabled:
		var msig: int = hash(["muted", c.duration])
		var muted: Dictionary = {"unity": false, "flat": true, "g": 0.0, "sig": msig if msig != 0 else 1, "track_id": t.id if t != null else "", "vol": {}, "trk": {}, "trk_dur": 0.0, "mst": {}, "mst_dur": 0.0, "fx": [], "fin": 0.0, "fout": 0.0, "fin_off": 0.0, "fout_off": 0.0, "shape": 0, "dur": c.duration, "start": c.start, "clip": c, "muted": true}
		muted["win"] = {"sig": muted["sig"], "flat": true, "g": 0.0}
		return muted
	var g: float = 1.0
	var down: float = 1.0
	var parts: Array = []
	var vol_v: Variant = c.audio.get("volume", null)
	var keyed_vol: Dictionary = {}
	if vol_v is Dictionary and AnimProp.is_animated(vol_v as Dictionary):
		keyed_vol = vol_v
		parts.append((vol_v as Dictionary).hash())
		parts.append(Paint.anim_sig(c))
	else:
		g *= maxf(_static_of(vol_v, 1.0), 0.0)
	var keyed_trk: Dictionary = {}
	var trk_dur: float = 0.0
	if t != null:
		if AnimProp.is_animated(t.volume):
			keyed_trk = t.volume
			parts.append(t.volume.hash())
			parts.append(c.start)
			if not t.clips.is_empty():
				trk_dur = t.clips[t.clips.size() - 1].end()
		else:
			var tgv: float = maxf(_static_of(t.volume, 1.0), 0.0)
			g *= tgv
			down *= tgv
	var keyed_mst: Dictionary = {}
	var mst_dur: float = 0.0
	if s != null:
		if AnimProp.is_animated(s.master_volume):
			keyed_mst = s.master_volume
			mst_dur = _master_dur(s)
			parts.append(s.master_volume.hash())
			parts.append(c.start)
			parts.append(mst_dur)
		else:
			var mgv: float = maxf(_static_of(s.master_volume, 1.0), 0.0)
			g *= mgv
			down *= mgv
	var fx: Array[Dictionary] = []
	var fx_v: Variant = c.audio.get("effects", [])
	if fx_v is Array:
		for e: Variant in fx_v:
			if not (e is Dictionary):
				continue
			var ed: Dictionary = e
			if String(ed.get("id", "")) != GAIN_ID or not bool(ed.get("enabled", true)):
				continue
			var params: Variant = ed.get("params", {})
			var db_v: Variant = (params as Dictionary).get("db", 0.0) if params is Dictionary else 0.0
			if db_v is Dictionary and AnimProp.is_animated(db_v as Dictionary):
				var path: String = "audio_effects." + String(ed.get("uid", "")) + ".db"
				fx.append({"prop": db_v, "path": path})
				parts.append((db_v as Dictionary).hash())
			else:
				g *= pow(10.0, _static_of(db_v, 0.0) / 20.0)
	var fin: float = maxf(_num(c.audio.get("fade_in", 0.0), 0.0), 0.0)
	var fout: float = maxf(_num(c.audio.get("fade_out", 0.0), 0.0), 0.0)
	var shape: int = int(SHAPES.get(String(c.audio.get("fade_shape", "linear")), 0))
	var fin_off: float = 0.0
	var fout_off: float = 0.0
	if t != null:
		var xf: Variant = crossfades(t, d).get(c.id, null)
		if xf is Dictionary:
			var xd: Dictionary = xf
			if xd.has("in_len"):
				fin_off = float(xd["in_off"])
				fin = maxf(fin, float(xd["in_len"]))
			if xd.has("out_len"):
				fout_off = float(xd["out_off"])
				fout = maxf(fout, float(xd["out_len"]))
	var flat: bool = keyed_vol.is_empty() and keyed_trk.is_empty() and keyed_mst.is_empty() and fx.is_empty() and fin <= 0.0 and fout <= 0.0
	var unity: bool = flat and absf(g - 1.0) <= UNITY_EPS
	var sig: int = 0
	if not unity:
		parts.append(g)
		if not flat:
			parts.append(fin)
			parts.append(fout)
			parts.append(fin_off)
			parts.append(fout_off)
			parts.append(shape)
			parts.append(c.duration)
		sig = hash(parts)
		if sig == 0:
			sig = 1
	var env: Dictionary = {"unity": unity, "flat": flat, "g": g, "down": down, "sig": sig, "track_id": t.id if t != null else "", "vol": keyed_vol, "trk": keyed_trk, "trk_dur": trk_dur, "mst": keyed_mst, "mst_dur": mst_dur, "fx": fx, "fin": fin, "fout": fout, "fin_off": fin_off, "fout_off": fout_off, "shape": shape, "dur": c.duration, "start": c.start, "clip": c}

	if flat and not unity:
		env["win"] = {"sig": sig, "flat": true, "g": g, "down": down}
	return env


static func window(env: Dictionary, a: float, b: float) -> Dictionary:
	if env.is_empty() or bool(env["unity"]):
		return {}
	if bool(env["flat"]):
		return env["win"]
	var s: int = int(env["sig"]) * 1000003 + int(round(a * 10000.0)) * 7919 + int(round(b * 1000000.0))
	if s == 0:
		s = 1
	var hit: Variant = _wins.get(s, null)
	if hit is Dictionary and is_same((hit as Dictionary)["env"], env):
		return hit
	var out: Dictionary = {"env": env, "sig": s, "a": a, "b": b}
	if _wins.size() >= MEMO_MAX:
		_wins.clear()
	_wins[s] = out
	return out


static func fade_curve(shape: int, x: float) -> float:
	var u: float = clampf(x, 0.0, 1.0)
	if shape == 1:
		return sin(u * PI * 0.5)
	if shape == 2:
		return u * u * (3.0 - 2.0 * u)
	return u


static func gain_at(env: Dictionary, local: float) -> float:
	var g: PackedFloat32Array = gains(env, PackedFloat64Array([local]))
	return g[0] if not g.is_empty() else 1.0


static func gains(env: Dictionary, locals: PackedFloat64Array) -> PackedFloat32Array:
	var n: int = locals.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var g0: float = float(env.get("g", 1.0))
	out.fill(g0)
	if n == 0 or bool(env.get("flat", true)):
		return out
	var dur: float = float(env["dur"])
	var c: Clip = env["clip"]
	var rising: bool = n < 2 or locals[n - 1] >= locals[0]
	var inside: PackedFloat64Array = PackedFloat64Array()
	inside.resize(n)
	for i: int in n:
		inside[i] = clampf(locals[i], 0.0, dur)
	var vol: Dictionary = env["vol"]
	if not vol.is_empty():
		var ts: PackedFloat64Array = inside
		if c.path_warped(VOLUME_PATH):
			ts = PackedFloat64Array()
			ts.resize(n)
			for i2: int in n:
				ts[i2] = c.param_time(VOLUME_PATH, inside[i2])
		var vs: PackedFloat64Array = Paint.curve_values(vol, ts, dur, 0.0, 0, rising and not c.path_warped(VOLUME_PATH))
		for i3: int in n:
			out[i3] *= maxf(vs[i3], 0.0)
	var trk: Dictionary = env["trk"]
	if not trk.is_empty():
		var start: float = float(env["start"])
		var tts: PackedFloat64Array = PackedFloat64Array()
		tts.resize(n)
		for i4: int in n:
			tts[i4] = start + inside[i4]
		var tvs: PackedFloat64Array = Paint.curve_values(trk, tts, maxf(float(env["trk_dur"]), start + dur), 0.0, 0, rising)
		for i5: int in n:
			out[i5] *= maxf(tvs[i5], 0.0)
	var mst: Dictionary = env.get("mst", {})
	if not mst.is_empty():
		var m0: float = float(env["start"])
		var mts: PackedFloat64Array = PackedFloat64Array()
		mts.resize(n)
		for i9: int in n:
			mts[i9] = m0 + inside[i9]
		var mvs: PackedFloat64Array = Paint.curve_values(mst, mts, maxf(float(env.get("mst_dur", 0.0)), m0 + dur), 0.0, 0, rising)
		for i10: int in n:
			out[i10] *= maxf(mvs[i10], 0.0)
	for f: Dictionary in (env["fx"] as Array):
		var fp: Dictionary = f["prop"]
		var path: String = String(f["path"])
		var fts: PackedFloat64Array = inside
		var warped: bool = c.path_warped(path)
		if warped:
			fts = PackedFloat64Array()
			fts.resize(n)
			for i6: int in n:
				fts[i6] = c.param_time(path, inside[i6])
		var dbs: PackedFloat64Array = Paint.curve_values(fp, fts, dur, 0.0, 0, rising and not warped)
		for i7: int in n:
			out[i7] *= pow(10.0, dbs[i7] / 20.0)
	var fin: float = float(env["fin"])
	var fout: float = float(env["fout"])
	if fin > 0.0 or fout > 0.0:
		var shape: int = int(env["shape"])
		var fin_off: float = float(env.get("fin_off", 0.0))
		var fout_off: float = float(env.get("fout_off", 0.0))
		for i8: int in n:
			var local: float = locals[i8]
			if local < -EDGE_SLACK or local > dur + EDGE_SLACK:
				continue
			local = clampf(local, 0.0, dur)
			var into: float = local + fin_off
			if fin > 0.0 and into < fin:
				out[i8] *= fade_curve(shape, into / fin)
			var remain: float = dur - local + fout_off
			if fout > 0.0 and remain < fout:
				out[i8] *= fade_curve(shape, remain / fout)
	return out


static func scale_amp(amp: float, g: float, log_mode: bool, floor_db: float) -> float:
	if amp <= KEEP_AMP:
		return amp
	var out: float
	if log_mode:
		if g <= 0.0000001:
			out = 0.0
		else:
			out = amp - 20.0 * log(g) / log(10.0) / floor_db
	else:
		out = amp * g
	return clampf(maxf(out, KEEP_AMP), 0.0, CAP)


static func apply(pts: PackedVector2Array, vol: Dictionary, sc: Dictionary) -> PackedVector2Array:
	var t0: int = Time.get_ticks_usec()
	var n: int = pts.size() / 2
	var out: PackedVector2Array = pts.duplicate()
	if n == 0:
		return out
	var gs: PackedFloat32Array
	if vol.has("lane"):
		gs = _lane_gains(pts, vol["lane"])
	else:
		if bool(vol.get("flat", false)):
			gs = PackedFloat32Array()
			gs.resize(n)
			gs.fill(float(vol["g"]))
		else:
			var env: Dictionary = vol["env"]
			var a: float = float(vol["a"])
			var b: float = float(vol["b"])
			var locals: PackedFloat64Array = PackedFloat64Array()
			locals.resize(n)
			for i: int in n:
				locals[i] = a + b * pts[i * 2].x
			gs = gains(env, locals)
	var log_mode: bool = bool(sc.get("log", false))
	var floor_db: float = float(sc.get("floor", -48.0))
	if floor_db >= 0.0:
		floor_db = -48.0
	for j: int in n:
		var g: float = gs[j]
		if absf(g - 1.0) <= UNITY_EPS:
			continue
		var p0: Vector2 = out[j * 2]
		var p1: Vector2 = out[j * 2 + 1]
		out[j * 2] = Vector2(p0.x, -scale_amp(-p0.y, g, log_mode, floor_db))
		out[j * 2 + 1] = Vector2(p1.x, scale_amp(p1.y, g, log_mode, floor_db))
	stats["applied"] = int(stats["applied"]) + 1
	stats["points"] = int(stats["points"]) + n
	stats["usec"] = int(stats["usec"]) + Time.get_ticks_usec() - t0
	last_applied = out
	last_gains = gs
	return out


static func for_lane(d: Project, s: Sequence, t: Track) -> Dictionary:
	if t == null:
		return {}
	_stamp(d)
	var key: int = t.get_instance_id()
	var hit: Variant = _lanes.get(key, null)
	if hit is Dictionary:
		return hit
	stats["lanes"] = int(stats["lanes"]) + 1
	if t.clips.size() > LANE_CLIP_MAX:
		var only: Dictionary = _track_only(t, s)
		if _lanes.size() >= 256:
			_lanes.clear()
		_lanes[key] = only
		return only
	var starts: PackedFloat64Array = PackedFloat64Array()
	var ends: PackedFloat64Array = PackedFloat64Array()
	var envs: Array[Dictionary] = []
	var parts: Array = []
	var any: bool = false
	for c: Clip in t.clips:
		var env: Dictionary = for_clip(d, s, c, t)
		starts.append(c.start)
		ends.append(c.end())
		envs.append(env)
		if not bool(env["unity"]):
			any = true
			parts.append(c.start)
			parts.append(int(env["sig"]))
	var out: Dictionary = {}
	if any:
		var sig: int = hash(parts)
		out = {"sig": sig if sig != 0 else 1, "lane": {"starts": starts, "ends": ends, "envs": envs}}
	if _lanes.size() >= 256:
		_lanes.clear()
	_lanes[key] = out
	return out


static func _track_only(t: Track, s: Sequence = null) -> Dictionary:
	var g: float = 1.0
	var mst: Dictionary = {}
	var mst_dur: float = 0.0
	if s != null:
		if AnimProp.is_animated(s.master_volume):
			mst = s.master_volume
			mst_dur = _master_dur(s)
		else:
			g *= maxf(_static_of(s.master_volume, 1.0), 0.0)
	var trk: Dictionary = {}
	var dur: float = 0.0
	if AnimProp.is_animated(t.volume):
		trk = t.volume
		dur = t.clips[t.clips.size() - 1].end() if not t.clips.is_empty() else 0.0
	else:
		g *= maxf(_static_of(t.volume, 1.0), 0.0)
	if trk.is_empty() and mst.is_empty() and absf(g - 1.0) <= UNITY_EPS:
		return {}
	var sig: int = hash([g, trk.hash() if not trk.is_empty() else 0, dur, mst.hash() if not mst.is_empty() else 0, mst_dur])
	return {"sig": sig if sig != 0 else 1, "lane": {"track_g": g, "trk": trk, "trk_dur": dur, "mst": mst, "mst_dur": mst_dur}}


static func _lane_gains(pts: PackedVector2Array, lane: Dictionary) -> PackedFloat32Array:
	var n: int = pts.size() / 2
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	out.fill(1.0)
	if lane.has("track_g"):
		out.fill(float(lane["track_g"]))
		var trk: Dictionary = lane["trk"]
		if not trk.is_empty():
			var ts: PackedFloat64Array = PackedFloat64Array()
			ts.resize(n)
			for i0: int in n:
				ts[i0] = pts[i0 * 2].x
			var tv: PackedFloat64Array = Paint.curve_values(trk, ts, maxf(float(lane["trk_dur"]), 1.0), 0.0, 0, true)
			for i1: int in n:
				out[i1] *= maxf(tv[i1], 0.0)
		var mst: Dictionary = lane.get("mst", {})
		if not mst.is_empty():
			var ms: PackedFloat64Array = PackedFloat64Array()
			ms.resize(n)
			for i2: int in n:
				ms[i2] = pts[i2 * 2].x
			var mv: PackedFloat64Array = Paint.curve_values(mst, ms, maxf(float(lane.get("mst_dur", 0.0)), 1.0), 0.0, 0, true)
			for i3: int in n:
				out[i3] *= maxf(mv[i3], 0.0)
		return out
	var starts: PackedFloat64Array = lane["starts"]
	var ends: PackedFloat64Array = lane["ends"]
	var envs: Array[Dictionary] = lane["envs"]
	var m: int = starts.size()
	if m == 0:
		return out
	var i: int = 0
	while i < n:
		var x: float = pts[i * 2].x
		var k: int = starts.bsearch(x, false) - 1
		while k > 0 and ends[k] <= x and ends[k - 1] > x:
			k -= 1
		if k < 0 or k >= m or x >= ends[k]:
			i += 1
			continue
		var env: Dictionary = envs[k]
		var j: int = i
		while j < n and pts[j * 2].x < ends[k] and (k + 1 >= m or pts[j * 2].x < starts[k + 1]):
			j += 1
		if j == i:
			j = i + 1
		if bool(env["unity"]):
			i = j
			continue
		if bool(env["flat"]):
			var gf: float = float(env["g"])
			for q: int in range(i, j):
				out[q] = gf
		else:
			var locals: PackedFloat64Array = PackedFloat64Array()
			locals.resize(j - i)
			var c0: float = starts[k]
			for q2: int in range(i, j):
				locals[q2 - i] = pts[q2 * 2].x - c0
			var gs: PackedFloat32Array = gains(env, locals)
			for q3: int in range(i, j):
				out[q3] = gs[q3 - i]
		i = j
	return out


static func live_touches(cmds: Array) -> bool:
	for cmd: Variant in cmds:
		if not (cmd is Object) or not (cmd as Object).has_method("live_key"):
			continue
		var k: String = String((cmd as Object).call("live_key"))
		if not k.begins_with("clip_param|"):
			continue
		var path: String = k.get_slice("|", 2)
		if path == "volume" or path == "master_volume" or path.begins_with("audio"):
			return true
	return false


static func downstream(env: Dictionary, locals: PackedFloat64Array) -> PackedFloat32Array:
	var n: int = locals.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	out.fill(float(env.get("down", 1.0)))
	if n == 0 or bool(env.get("flat", true)):
		return out
	var dur: float = float(env.get("dur", 0.0))
	var start: float = float(env.get("start", 0.0))
	var rising: bool = n < 2 or locals[n - 1] >= locals[0]
	var at: PackedFloat64Array = PackedFloat64Array()
	at.resize(n)
	for i: int in n:
		at[i] = start + clampf(locals[i], 0.0, dur)
	var trk: Dictionary = env.get("trk", {})
	if not trk.is_empty():
		var tvs: PackedFloat64Array = Paint.curve_values(trk, at, maxf(float(env.get("trk_dur", 0.0)), start + dur), 0.0, 0, rising)
		for i2: int in n:
			out[i2] *= maxf(tvs[i2], 0.0)
	var mst: Dictionary = env.get("mst", {})
	if not mst.is_empty():
		var mvs: PackedFloat64Array = Paint.curve_values(mst, at, maxf(float(env.get("mst_dur", 0.0)), start + dur), 0.0, 0, rising)
		for i3: int in n:
			out[i3] *= maxf(mvs[i3], 0.0)
	return out


static func downstream_for(pts: PackedVector2Array, vol: Dictionary) -> PackedFloat32Array:
	var n: int = pts.size() / 2
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	out.fill(1.0)
	if n == 0 or vol.is_empty():
		return out
	if vol.has("lane"):
		var lane: Dictionary = vol["lane"]
		if lane.has("track_g"):
			return _lane_gains(pts, lane)
		var starts: PackedFloat64Array = lane["starts"]
		var ends: PackedFloat64Array = lane["ends"]
		var envs: Array[Dictionary] = lane["envs"]
		var m: int = starts.size()
		var i: int = 0
		while i < n:
			var x: float = pts[i * 2].x
			var k: int = starts.bsearch(x, false) - 1
			while k > 0 and ends[k] <= x and ends[k - 1] > x:
				k -= 1
			if k < 0 or k >= m or x >= ends[k]:
				i += 1
				continue
			var env: Dictionary = envs[k]
			var j: int = i
			while j < n and pts[j * 2].x < ends[k] and (k + 1 >= m or pts[j * 2].x < starts[k + 1]):
				j += 1
			if j == i:
				j = i + 1
			var locals: PackedFloat64Array = PackedFloat64Array()
			locals.resize(j - i)
			for q: int in range(i, j):
				locals[q - i] = pts[q * 2].x - starts[k]
			var ds: PackedFloat32Array = downstream(env, locals)
			for q2: int in range(i, j):
				out[q2] = ds[q2 - i]
			i = j
		return out
	if bool(vol.get("flat", false)):
		out.fill(float(vol.get("down", 1.0)))
		return out
	if not vol.has("env"):
		return out
	var a: float = float(vol["a"])
	var b: float = float(vol["b"])
	var locs: PackedFloat64Array = PackedFloat64Array()
	locs.resize(n)
	for i4: int in n:
		locs[i4] = a + b * pts[i4 * 2].x
	return downstream(vol["env"], locs)

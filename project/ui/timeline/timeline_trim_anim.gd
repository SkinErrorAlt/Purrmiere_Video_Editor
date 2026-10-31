extends Node

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Verbs := preload("res://doc/verbs.gd")
const Waves := preload("res://ui/timeline/timeline_wave.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const SELF_PATH := "res://ui/timeline/timeline_trim_anim.gd"
const ViewTrimShot := preload("res://ui/timeline/timeline_view_trims.gd")
const PREF_ON := "timeline.animate_trims"
const PREF_SECONDS := "timeline.animate_trims_seconds"
const PREF_REDUCE := "ui.reduce_motion"
const DEFAULT_SECONDS := 0.5
const MIN_SECONDS := 0.1
const MAX_SECONDS := 1.0
const NODE_NAME := "TrimAnimation"
const DENSE_LIMIT := 80
const CAPTURE_LIMIT := 3000
const EPS := 0.000001

var canvas: Control = null
var doc: Project = null
var seq: Sequence = null
var clips: Array[Clip] = []
var from_v: PackedFloat64Array = PackedFloat64Array()
var to_v: PackedFloat64Array = PackedFloat64Array()
var playhead_from: float = 0.0
var playhead_to: float = 0.0
var seconds: float = DEFAULT_SECONDS
var started_usec: int = 0
var serial: int = -1
var view: PackedFloat64Array = PackedFloat64Array()
var running: bool = false
var posed: bool = false
var unpose_queued: bool = false
var posed_frames: int = 0
var pose_usec: int = 0
var last_u: float = 0.0
var last_k: float = 0.0
var k_frame: int = -1
var runs: int = 0
var held_buttons: int = 0
var last_playhead: float = 0.0
var stop_reason: String = ""
var _index: Dictionary = {}
var _keys: Dictionary = {}
var _keyed_ids: Dictionary = {}
var _primed: int = -1


static func register_prefs() -> void:
	if not Prefs.is_registered(PREF_ON):
		Prefs.register(PREF_ON, true, {"label": "Animate trims to the playhead", "type": "bool"})
	if not Prefs.is_registered(PREF_SECONDS):
		Prefs.register(PREF_SECONDS, DEFAULT_SECONDS, {"label": "Trim animation length (seconds)", "type": "float", "min": MIN_SECONDS, "max": MAX_SECONDS})


static func enabled() -> bool:
	register_prefs()
	if not bool(Prefs.get_value(PREF_ON)):
		return false
	if Prefs.is_registered(PREF_REDUCE) and bool(Prefs.get_value(PREF_REDUCE)):
		return false
	return true


static func length() -> float:
	register_prefs()
	return clampf(float(Prefs.get_value(PREF_SECONDS)), MIN_SECONDS, MAX_SECONDS)


static func eased(u: float) -> float:
	var v: float = clampf(u, 0.0, 1.0)
	return 1.0 - pow(1.0 - v, 4.0)


static func finish_on(cv: Control) -> void:
	if cv == null or not is_instance_valid(cv):
		return
	var n: Variant = cv.get("trim_anim")
	if n is Node and is_instance_valid(n):
		(n as Node).call("finish")


static func running_on(cv: Control) -> Node:
	if cv == null or not is_instance_valid(cv):
		return null
	var n: Variant = cv.get("trim_anim")
	if n is Node and is_instance_valid(n) and bool((n as Node).get("running")):
		return n
	return null


static func before(cv: Control, d: Project, s: Sequence, kind: String) -> Dictionary:
	var at: Array[Clip] = []
	var at_vals: PackedFloat64Array = PackedFloat64Array()
	var captured: Array[Clip] = []
	var vals: PackedFloat64Array = PackedFloat64Array()
	var shot: Dictionary = {"canvas": cv, "doc": d, "seq": s, "playhead": 0.0, "at": at, "at_vals": at_vals, "clips": captured, "vals": vals, "animate": false, "dense": false, "t0": 0.0, "t1": 0.0, "reach": 0.0}
	if d == null or s == null:
		return shot
	finish_on(cv)
	var p: float = s.playhead
	shot["playhead"] = p
	for t: Track in s.all_tracks():
		for c: Clip in t.clips_at(p):
			at.append(c)
			at_vals.append(c.start)
			at_vals.append(c.duration)
	if cv == null or not is_instance_valid(cv) or not cv.is_visible_in_tree() or cv.call("seq") != s or not enabled():
		return shot
	shot["animate"] = true
	var t0: float = float(cv.call("t_of", float(cv.get("header_w"))))
	var t1: float = float(cv.call("t_of", cv.size.x))
	shot["t0"] = t0
	shot["t1"] = t1
	for t: Track in s.all_tracks():
		if t.index_of_last_starting_before(t1) - maxi(t.index_of_first_visible(t0), 0) + 1 > DENSE_LIMIT:
			shot["dense"] = true
			return shot
	var reach: float = reach_for(s, p, kind) + 1.0
	shot["reach"] = reach
	for t: Track in s.all_tracks():
		var i: int = maxi(t.index_of_first_visible(t0 - reach), 0)
		var j: int = t.index_of_last_starting_before(t1 + reach)
		if j < i:
			continue
		if captured.size() + j - i + 1 > CAPTURE_LIMIT:
			shot["dense"] = true
			captured.clear()
			vals.clear()
			return shot
		for idx: int in range(i, j + 1):
			var c: Clip = t.clips[idx]
			captured.append(c)
			vals.append(c.start)
			vals.append(c.duration)
			vals.append(c.in_offset)
	var keyed: Dictionary = {}
	for c: Clip in captured:
		if c.end() >= p - reach and c.start <= p + reach:
			keyed[c.get_instance_id()] = _key_times(c)
	shot["keyed"] = keyed
	return shot


static func _key_dicts(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for path: String in c.param_paths():
		var p: Dictionary = c.get_param(path)
		if not AnimProp.is_animated(p):
			continue
		var li: int = AnimProp.keys_layer_index(p)
		if li < 0:
			continue
		for k: Variant in ((p["layers"] as Array)[li] as Dictionary).get("keys", []):
			if k is Dictionary:
				out.append(k)
	return out


static func _key_times(c: Clip) -> Dictionary:
	var keys: PackedFloat64Array = PackedFloat64Array()
	for kd: Dictionary in _key_dicts(c):
		keys.append(float(kd.get("t", 0.0)))
	var marks: PackedFloat64Array = PackedFloat64Array()
	for m: Variant in c.markers:
		marks.append(float((m as Object).get("time")))
	var anim: Variant = c.get("anim_start")
	var ramp: Dictionary = c.speed.duplicate(true) if AnimProp.is_animated(c.speed) else {}
	return {"keys": keys, "marks": marks, "anim": float(anim) if anim is float else NAN, "ramp": ramp, "start": c.start, "duration": c.duration, "in": c.in_offset}


static func key_motion(shot: Dictionary, moved: Array[Clip]) -> Dictionary:
	var refs: Array[Dictionary] = []
	var key_from: PackedFloat64Array = PackedFloat64Array()
	var key_to: PackedFloat64Array = PackedFloat64Array()
	var marks: Array[Object] = []
	var mark_from: PackedFloat64Array = PackedFloat64Array()
	var mark_to: PackedFloat64Array = PackedFloat64Array()
	var anims: Array[Clip] = []
	var anim_from: PackedFloat64Array = PackedFloat64Array()
	var anim_to: PackedFloat64Array = PackedFloat64Array()
	var ramps: Array[Clip] = []
	var ghosts: Array[Clip] = []
	var heads: PackedFloat64Array = PackedFloat64Array()
	var ids: Dictionary = {}
	var keyed: Dictionary = shot.get("keyed", {})
	for c: Clip in moved:
		var was: Variant = keyed.get(c.get_instance_id(), null)
		if not (was is Dictionary):
			continue
		var wd: Dictionary = was
		var now: Array[Dictionary] = _key_dicts(c)
		var before_keys: PackedFloat64Array = wd["keys"]
		if now.size() == before_keys.size():
			for i: int in now.size():
				var t_now: float = float(now[i].get("t", 0.0))
				if t_now != before_keys[i]:
					refs.append(now[i])
					key_from.append(before_keys[i])
					key_to.append(t_now)
					ids[c.id] = true
		var before_marks: PackedFloat64Array = wd["marks"]
		if c.markers.size() == before_marks.size():
			for i: int in c.markers.size():
				var m: Object = c.markers[i]
				var m_now: float = float(m.get("time"))
				if m_now != before_marks[i]:
					marks.append(m)
					mark_from.append(before_marks[i])
					mark_to.append(m_now)
					ids[c.id] = true
		var a_now: Variant = c.get("anim_start")
		if a_now is float and not is_nan(float(wd["anim"])) and float(a_now) != float(wd["anim"]):
			anims.append(c)
			anim_from.append(float(wd["anim"]))
			anim_to.append(float(a_now))
			ids[c.id] = true
		var ramp: Dictionary = wd["ramp"]
		if not ramp.is_empty() and c.in_offset != float(wd["in"]):
			var ghost: Clip = Clip.new()
			ghost.start = float(wd["start"])
			ghost.duration = float(wd["duration"])
			ghost.in_offset = float(wd["in"])
			ghost.speed = ramp
			ramps.append(c)
			ghosts.append(ghost)
			heads.append(float(wd["duration"]) - c.duration)
			ids[c.id] = true
	return {"refs": refs, "key_from": key_from, "key_to": key_to, "marks": marks, "mark_from": mark_from, "mark_to": mark_to, "anims": anims, "anim_from": anim_from, "anim_to": anim_to, "ramps": ramps, "ghosts": ghosts, "heads": heads, "ids": ids}


static func reach_for(s: Sequence, p: float, kind: String) -> float:
	if kind == "edit":
		var most: float = 0.0
		for t: Track in Verbs.working_tracks(s):
			most = maxf(most, _nearest_edge(t, p))
		return most
	var hits: Array[Clip] = []
	for id: String in Verbs.unlocked(s, Verbs.selection(s)):
		var c: Clip = s.clip_by_id(id)
		if c != null and p > c.start + EPS and p < c.end() - EPS:
			hits.append(c)
	if hits.is_empty():
		for t: Track in Verbs.working_tracks(s):
			for c: Clip in t.clips_at(p):
				if p > c.start + EPS and p < c.end() - EPS:
					hits.append(c)
	var per_edge: Dictionary = {}
	for c: Clip in hits:
		var edge: float = c.start if kind == "head" else c.end()
		var key: String = "%.5f" % edge
		per_edge[key] = maxf(float(per_edge.get(key, 0.0)), absf(p - edge))
	var total: float = 0.0
	for v: Variant in per_edge.values():
		total += float(v)
	return total


static func _nearest_edge(t: Track, p: float) -> float:
	var n: int = t.clips.size()
	if n == 0:
		return 0.0
	var near: Array[Clip] = t.clips_at(p)
	var i: int = t.index_of_last_starting_before(p)
	for idx: int in [i - 1, i, i + 1]:
		if idx >= 0 and idx < n:
			near.append(t.clips[idx])
	var best: float = INF
	for c: Clip in near:
		for e: float in [c.start, c.end()]:
			var dist: float = absf(e - p)
			if dist > EPS:
				best = minf(best, dist)
	return 0.0 if best == INF else best


static func head_target(shot: Dictionary) -> float:
	var p: float = float(shot.get("playhead", 0.0))
	var at: Array[Clip] = shot.get("at", [] as Array[Clip])
	var vals: PackedFloat64Array = shot.get("at_vals", PackedFloat64Array())
	var best: float = -INF
	for i: int in at.size():
		var c: Clip = at[i]
		var cut: float = vals[i * 2 + 1] - c.duration
		if c.start == vals[i * 2] and cut > EPS:
			best = maxf(best, p - cut)
	return best if best > -INF else p


static func after(shot: Dictionary, follow_head: bool) -> Node:
	ViewTrimShot.mend(shot)
	var d: Project = shot.get("doc", null)
	var s: Sequence = shot.get("seq", null)
	if d == null or s == null:
		return null
	var p: float = float(shot["playhead"])
	var target: float = p
	if follow_head:
		target = maxf(head_target(shot), 0.0)
		if absf(target - p) > EPS and Session.seq() == s:
			Session.set_playhead(target)
		target = s.playhead
	if not bool(shot.get("animate", false)):
		return null
	var cv: Control = shot["canvas"]
	if cv == null or not is_instance_valid(cv):
		return null
	var captured: Array[Clip] = shot["clips"]
	var vals: PackedFloat64Array = shot["vals"]
	var t0: float = float(shot["t0"])
	var t1: float = float(shot["t1"])
	var moved: Array[Clip] = []
	var a: PackedFloat64Array = PackedFloat64Array()
	var b: PackedFloat64Array = PackedFloat64Array()
	for i: int in captured.size():
		var c: Clip = captured[i]
		var o: int = i * 3
		if c.start == vals[o] and c.duration == vals[o + 1] and c.in_offset == vals[o + 2]:
			continue
		if maxf(c.end(), vals[o] + vals[o + 1]) <= t0 or minf(c.start, vals[o]) >= t1:
			continue
		moved.append(c)
		a.append(vals[o])
		a.append(vals[o + 1])
		a.append(vals[o + 2])
		b.append(c.start)
		b.append(c.duration)
		b.append(c.in_offset)
	if moved.is_empty() and absf(target - p) <= EPS:
		return null
	var n: Node = cv.get_node_or_null(NODE_NAME)
	if n == null:
		var script: GDScript = load(SELF_PATH)
		n = script.new()
		n.name = NODE_NAME
		cv.add_child(n)
	n.call("start", cv, d, s, moved, a, b, p, target)
	n.call("take_keys", key_motion(shot, moved))
	return n


func take_keys(motion: Dictionary) -> void:
	_keys = motion
	_keyed_ids = motion.get("ids", {})


func _pose_keys(k: float) -> void:
	if _keys.is_empty():
		return
	var refs: Array[Dictionary] = _keys["refs"]
	var kf: PackedFloat64Array = _keys["key_from"]
	var kt: PackedFloat64Array = _keys["key_to"]
	for i: int in refs.size():
		refs[i]["t"] = lerpf(kf[i], kt[i], k)
	var marks: Array[Object] = _keys["marks"]
	var mf: PackedFloat64Array = _keys["mark_from"]
	var mt: PackedFloat64Array = _keys["mark_to"]
	for i: int in marks.size():
		marks[i].set("time", lerpf(mf[i], mt[i], k))
	var anims: Array[Clip] = _keys["anims"]
	var af: PackedFloat64Array = _keys["anim_from"]
	var at: PackedFloat64Array = _keys["anim_to"]
	for i: int in anims.size():
		anims[i].set("anim_start", lerpf(af[i], at[i], k))
	var ramps: Array[Clip] = _keys["ramps"]
	var ghosts: Array[Clip] = _keys["ghosts"]
	var heads: PackedFloat64Array = _keys["heads"]
	for i: int in ramps.size():
		ramps[i].in_offset = ghosts[i].source_time(ghosts[i].start + heads[i] * k)


func _unpose_keys() -> void:
	if _keys.is_empty():
		return
	var refs: Array[Dictionary] = _keys["refs"]
	var kt: PackedFloat64Array = _keys["key_to"]
	for i: int in refs.size():
		refs[i]["t"] = kt[i]
	var marks: Array[Object] = _keys["marks"]
	var mt: PackedFloat64Array = _keys["mark_to"]
	for i: int in marks.size():
		marks[i].set("time", mt[i])
	var anims: Array[Clip] = _keys["anims"]
	var at: PackedFloat64Array = _keys["anim_to"]
	for i: int in anims.size():
		anims[i].set("anim_start", at[i])


func _init() -> void:
	set_process(false)


func start(cv: Control, d: Project, s: Sequence, moved: Array[Clip], a: PackedFloat64Array, b: PackedFloat64Array, ph_from: float, ph_to: float) -> void:
	finish()
	canvas = cv
	doc = d
	seq = s
	clips = moved
	from_v = a
	to_v = b
	_index = {}
	for i: int in moved.size():
		_index[moved[i].id] = i
	playhead_from = ph_from
	playhead_to = ph_to
	seconds = length()
	serial = d.serial
	view = _view_of(cv)
	held_buttons = int(Input.get_mouse_button_mask())
	started_usec = Time.get_ticks_usec()
	k_frame = -1
	last_u = 0.0
	last_k = 0.0
	last_playhead = ph_from
	stop_reason = ""
	posed = false
	running = true
	runs += 1
	cv.set("trim_anim", self)
	set_process(true)
	_redraw()


func progress() -> float:
	if not running:
		return 1.0
	if seconds <= 0.0:
		return 1.0
	return clampf(float(Time.get_ticks_usec() - started_usec) / (seconds * 1000000.0), 0.0, 1.0)


func _k() -> float:
	var f: int = Engine.get_process_frames()
	if f != k_frame:
		k_frame = f
		last_u = progress()
		last_k = eased(last_u)
	return last_k


func _stale() -> bool:
	return doc == null or seq == null or doc.serial != serial


func _prime_plans() -> void:
	if _primed == serial:
		return
	_primed = serial
	for c: Clip in clips:
		var tr: Track = seq.track_of(c.id)
		if tr != null and tr.is_sound(c):
			Waves.heard_plan(doc, seq, c)


func pose() -> void:
	if not running or posed or _stale():
		return
	for t: Track in seq.all_tracks():
		t.has_stack()
	canvas.call("duration")
	_prime_plans()
	var t0: int = Time.get_ticks_usec()
	var k: float = _k()
	for i: int in clips.size():
		var c: Clip = clips[i]
		var o: int = i * 3
		c.start = lerpf(from_v[o], to_v[o], k)
		c.duration = lerpf(from_v[o + 1], to_v[o + 1], k)
		c.in_offset = lerpf(from_v[o + 2], to_v[o + 2], k)
	_pose_keys(k)
	posed = true
	Waves.posing += 1
	Waves.posed_by = self
	posed_frames += 1
	if not unpose_queued:
		unpose_queued = true
		call_deferred("_safety_unpose")
	pose_usec += Time.get_ticks_usec() - t0


func unpose() -> void:
	if not posed:
		return
	var t0: int = Time.get_ticks_usec()
	for i: int in clips.size():
		var c: Clip = clips[i]
		var o: int = i * 3
		c.start = to_v[o]
		c.duration = to_v[o + 1]
		c.in_offset = to_v[o + 2]
	_unpose_keys()
	posed = false
	Waves.posing = maxi(Waves.posing - 1, 0)
	if Waves.posed_by == self:
		Waves.posed_by = null
	pose_usec += Time.get_ticks_usec() - t0


func _safety_unpose() -> void:
	unpose_queued = false
	unpose()


func delta_of(c: Clip) -> float:
	if not posed or c == null:
		return 0.0
	if _keyed_ids.has(c.id):
		return NAN
	var i: int = int(_index.get(c.id, -1))
	if i < 0 or i >= clips.size() or clips[i] != c:
		return 0.0
	var o: int = i * 3
	if c.duration != to_v[o + 1] or c.in_offset != to_v[o + 2]:
		return NAN
	return c.start - to_v[o]


func pose_and_playhead(ph: float) -> float:
	pose()
	return drawn_playhead(ph)


func drawn_playhead(ph: float) -> float:
	if not running or _stale() or absf(ph - playhead_to) > EPS:
		return ph
	last_playhead = lerpf(playhead_from, playhead_to, _k())
	return last_playhead


func drawn_span(c: Clip) -> Vector2:
	var i: int = clips.find(c)
	if i < 0 or not running:
		return Vector2(c.start, c.end())
	var o: int = i * 3
	var st: float = lerpf(from_v[o], to_v[o], last_k)
	return Vector2(st, st + lerpf(from_v[o + 1], to_v[o + 1], last_k))


func finish() -> void:
	if not running:
		return
	if stop_reason.is_empty():
		stop_reason = "finished early"
	unpose()
	running = false
	set_process(false)
	var cv: Control = canvas
	clips = []
	from_v = PackedFloat64Array()
	to_v = PackedFloat64Array()
	_index = {}
	_keys = {}
	_keyed_ids = {}
	doc = null
	seq = null
	canvas = null
	if cv != null and is_instance_valid(cv):
		if cv.get("trim_anim") == self:
			cv.set("trim_anim", null)
		cv.queue_redraw()
		var ov: Variant = cv.call("overlay")
		if ov is Control:
			(ov as Control).queue_redraw()


func _view_of(cv: Control) -> PackedFloat64Array:
	return PackedFloat64Array([float(cv.get("pps")), float(cv.get("scroll_x")), float(cv.get("scroll_y")), cv.size.x, cv.size.y])


func _interruption() -> String:
	if canvas == null or not is_instance_valid(canvas) or not canvas.is_visible_in_tree():
		return "timeline hidden"
	if _stale():
		return "document changed"
	if Session.playing:
		return "playback"
	if not enabled():
		return "setting off"
	if absf(seq.playhead - playhead_to) > EPS or canvas.call("seq") != seq:
		return "playhead or sequence changed"
	if _view_of(canvas) != view:
		return "view changed"
	var mask: int = int(Input.get_mouse_button_mask())
	if mask & ~held_buttons != 0:
		return "click"
	held_buttons &= mask
	return ""


func _process(_dt: float) -> void:
	if not running:
		set_process(false)
		return
	var why: String = _interruption()
	if why.is_empty() and progress() >= 1.0:
		why = "done"
	if not why.is_empty():
		stop_reason = why
		finish()
		return
	_redraw()


func _redraw() -> void:
	if canvas == null or not is_instance_valid(canvas):
		return
	canvas.queue_redraw()
	var ov: Variant = canvas.call("overlay")
	if ov is Control:
		(ov as Control).queue_redraw()

extends Node

const Tracking := preload("res://doc/tracking.gd")
const TrackingEval := preload("res://engine/tracking_eval.gd")
const TrackingCmds := preload("res://doc/commands/tracking_cmds.gd")
const Timecode := preload("res://doc/timecode.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const NODE_NAME := "TrackerRun"
const SELF_PATH := "res://modules/core_panels/tracker_run.gd"
const FOLLOW_MS := 80
const SOFT_THREADS := 8

signal changed
signal finished(ok: bool, info: Dictionary)

var job: int = -1
var state: Dictionary = {}
var preview: Dictionary = {}
var last_info: Dictionary = {}
var _got: int = 0
var _follow_at: int = 0
var _doc: Object = null
var follow_playhead: bool = true


static func shared() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var root: Window = (loop as SceneTree).root
	var n: Node = root.get_node_or_null(NODE_NAME)
	if n == null:
		n = (load(SELF_PATH) as GDScript).new()
		n.name = NODE_NAME
		root.add_child(n)
	return n


static func bridge() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null("/root/PurrBridge")


func running() -> bool:
	return job >= 0


func running_set() -> String:
	return String(state.get("set", "")) if running() else ""


func start(doc: Object, set_id: String, direction: String, mt: float, until: float = NAN) -> String:
	if running():
		return "a tracker is already running"
	var br: Node = bridge()
	if br == null or not bool(br.call("has_tracking")):
		return "tracking is not in this build"
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	if s.is_empty():
		return "no tracker"
	var media: Object = doc.call("media_by_id", String(s.get("media", "")))
	if media == null or String(media.get("path")).is_empty():
		return "the clip has no file to track"
	var fps: float = float(s.get("fps", 30.0))
	var eps: float = Tracking.frame_eps(fps)
	var seeds: PackedFloat32Array = PackedFloat32Array()
	var ids: Array[String] = []
	var at: float = mt
	for t: Variant in s.get("trackers", []):
		var tr: Dictionary = t
		var pos: Dictionary = Tracking.position_at(tr, mt, fps)
		var sm: Dictionary = Tracking.samples(tr)
		var j: int = Tracking.sample_frame(tr, mt, fps)
		if j >= 0:
			if ((sm["f"] as PackedInt32Array)[j] & Tracking.LOST) != 0:
				continue
			at = (sm["t"] as PackedFloat64Array)[j] + eps
		elif not (sm["vt"] as PackedFloat64Array).is_empty():
			continue
		var p: Vector2 = pos["p"]
		seeds.append(p.x)
		seeds.append(p.y)
		ids.append(String(tr["id"]))
	if ids.is_empty():
		return "no tracker has a place on this frame: drag one onto the picture first"
	var rng: Array = s.get("range", [0.0, 0.0])
	var ra: float = float(rng[0])
	var rb: float = float(rng[1])
	var a: float = 0.0
	var b: float = 0.0
	if direction == "forward":
		a = at
		b = rb if is_nan(until) else minf(rb, until)
		if a >= b - eps:
			return "the playhead is at the end of the track range"
	else:
		a = ra if is_nan(until) else maxf(ra, until)
		b = at + eps * 0.5
		if b <= a + eps:
			return "the playhead is at the start of the track range"
	if mt < ra - eps * 4.0 or mt > rb + eps * 4.0:
		return "the playhead is outside the track range"
	var spec: Dictionary = {
		"path": String(media.get("path")),
		"start": a,
		"end": b,
		"mode": "points",
		"seeds": seeds,
		"direction": direction,
		"cache": false,
		"soft_threads": SOFT_THREADS,
		"settings": {"ncc_min": float(s.get("stop_below", Tracking.STOP_BELOW))},
	}
	var area: Array = Tracking.engine_area(s)
	if not area.is_empty() and Tracking.has_include(s):
		spec["area"] = area
	var id: int = int(br.call("track_start", spec))
	if id < 0:
		return "the tracker could not start"
	job = id
	_doc = doc
	_got = 0
	_follow_at = 0
	state = {"set": set_id, "ids": ids, "direction": direction, "a": a, "b": b, "fps": fps, "clip": String(s.get("clip", "")), "started": Time.get_ticks_msec()}
	preview = {}
	for tid: String in ids:
		preview[tid] = Tracking.empty_samples()
	set_process(true)
	changed.emit()
	return ""


func stop() -> void:
	if not running():
		return
	var br: Node = bridge()
	if br != null:
		br.call("track_cancel", job)


func progress() -> float:
	if not running():
		return 0.0
	var span: float = maxf(float(state["b"]) - float(state["a"]), 0.000001)
	var done: float = 0.0
	for tid: String in preview.keys():
		var t: PackedFloat64Array = (preview[tid] as Dictionary)["t"]
		if t.is_empty():
			continue
		var edge: float = t[t.size() - 1]
		done = maxf(done, (edge - float(state["a"])) if String(state["direction"]) == "forward" else (float(state["b"]) - edge))
	return clampf(done / span, 0.0, 1.0)


func _ready() -> void:
	set_process(running())


func _process(_dt: float) -> void:
	if not running():
		set_process(false)
		return
	poll()


func poll() -> void:
	var br: Node = bridge()
	if br == null:
		_end(false, {"error": "the engine went away"})
		return
	var r: Dictionary = br.call("track_read", job, _got)
	var n: int = int(r["count"]) - _got
	if n > 0:
		_absorb(r)
		_got = int(r["count"])
		_follow()
		changed.emit()
	if bool(r["done"]):
		_end(not bool(r["failed"]) or bool(r["cancelled"]), r)


func _absorb(r: Dictionary) -> void:
	var starts: PackedFloat64Array = r["frame_start"]
	var pts: PackedFloat64Array = r["frame_pts"]
	var first: PackedInt32Array = r["frame_first"]
	var pid: PackedInt32Array = r["point_id"]
	var xy: PackedFloat32Array = r["point_xy"]
	var score: PackedFloat32Array = r["point_score"]
	var pf: PackedInt32Array = r["point_flags"]
	var ids: Array = state["ids"]
	for i: int in pts.size():
		var t: float = starts[i] if i < starts.size() and starts[i] > -1.0 else pts[i]
		for k: int in range(first[i], first[i + 1]):
			var slot: int = pid[k]
			if slot < 0 or slot >= ids.size():
				continue
			var sm: Dictionary = preview[ids[slot]]
			var ef: int = pf[k]
			var flags: int = 0
			if (ef & 8) != 0:
				flags = Tracking.LOST
			elif (ef & 1) != 0:
				flags = Tracking.GOOD
				if score[k] < Tracking.WEAK_BELOW:
					flags |= Tracking.WEAK
			else:
				continue
			Tracking.add_sample(sm, t, Vector2(xy[2 * k], xy[2 * k + 1]), score[k], flags)


func latest_time() -> float:
	var best: float = NAN
	for tid: String in preview.keys():
		var t: PackedFloat64Array = (preview[tid] as Dictionary)["t"]
		if t.is_empty():
			continue
		var e: float = t[t.size() - 1]
		if is_nan(best):
			best = e
		elif String(state.get("direction", "forward")) == "forward":
			best = maxf(best, e)
		else:
			best = minf(best, e)
	return best


func _follow() -> void:
	if not follow_playhead:
		return
	var now: int = Time.get_ticks_msec()
	if now - _follow_at < FOLLOW_MS:
		return
	_follow_at = now
	_seek_to(latest_time())


func _seek_to(mt: float) -> void:
	if is_nan(mt) or _doc == null:
		return
	var c: Object = _doc.call("clip_by_id", String(state.get("clip", "")))
	var session: Node = get_node_or_null("/root/Session")
	if c == null or session == null or bool(session.get("playing")):
		return
	var t: float = TrackingEval.seq_time_of(c, mt + Tracking.frame_eps(float(state.get("fps", 30.0))))
	t = clampf(t, float(c.get("start")), float(c.call("end")) - 0.0001)
	session.call("set_playhead", t)


func preview_samples(set_id: String, tid: String) -> Dictionary:
	if not running() or String(state.get("set", "")) != set_id or not preview.has(tid):
		return {}
	return preview[tid]


func _end(ok: bool, r: Dictionary) -> void:
	var br: Node = bridge()
	var info: Dictionary = {"ok": ok, "cancelled": bool(r.get("cancelled", false)), "error": String(r.get("error", "")), "speed_line": String(r.get("speed_line", "")), "frames": int(r.get("count", 0)), "lost": []}
	if br != null and job >= 0:
		br.call("track_forget", job)
	job = -1
	set_process(false)
	var doc: Object = _doc
	var committed: bool = false
	if doc != null and (ok or bool(info["cancelled"])):
		committed = _commit(doc, info)
	info["committed"] = committed
	if committed:
		_seek_to(latest_time())
	last_info = info
	preview = {}
	changed.emit()
	finished.emit(ok, info)
	var lost: Array = info["lost"]
	if not lost.is_empty():
		_toast_lost(doc, float(lost[0]))
	elif not ok and not bool(info["cancelled"]):
		_toast("The tracker stopped: " + String(info["error"]))


func _commit(doc: Object, info: Dictionary) -> bool:
	var s: Dictionary = Tracking.set_by_id(doc, String(state["set"]))
	if s.is_empty():
		return false
	var fps: float = float(state["fps"])
	var eps: float = Tracking.frame_eps(fps)
	var forward: bool = String(state["direction"]) == "forward"
	var out: Dictionary = s.duplicate(true)
	var any: bool = false
	var lost: Array = info["lost"]
	for tid: String in preview.keys():
		var add: Dictionary = preview[tid]
		var t: PackedFloat64Array = add["t"]
		if t.is_empty():
			continue
		var lo: float = INF
		var hi: float = -INF
		for v: float in t:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		var f: PackedInt32Array = add["f"]
		for i: int in f.size():
			if (f[i] & Tracking.LOST) != 0:
				lost.append(t[i])
				break
		if not bool(info["cancelled"]):
			if forward:
				hi = maxf(hi, float(state["b"]) - eps)
			else:
				lo = minf(lo, float(state["a"]) + eps)
		var tr: Dictionary = Tracking.tracker_by_id(out, tid)
		var j0: int = Tracking.sample_frame(tr, t[0], fps)
		if j0 >= 0 and ((Tracking.samples(tr)["f"] as PackedInt32Array)[j0] & Tracking.HAND) != 0 and (f[0] & Tracking.LOST) == 0:
			f[0] = f[0] | Tracking.HAND
			add["f"] = f
		var merged: Dictionary = Tracking.merge(Tracking.samples(tr), add, lo, hi, eps)
		out = Tracking.with_tracker(out, Tracking.pack(tr, merged))
		any = true
	if not any:
		return false
	var label: String = "Track forward" if forward else "Track backward"
	var cmds: Array[Command] = [TrackingCmds.SetSet.new(label, String(state["set"]), out)]
	return Verbs.run(doc, label, cmds)


func _toast_lost(doc: Object, mt: float) -> void:
	var c: Object = doc.call("clip_by_id", String(state.get("clip", ""))) if doc != null else null
	var s: Object = doc.call("sequence_of_clip", String(c.get("id"))) if c != null else null
	if c == null or s == null:
		_toast("The tracker lost its point: drag it back and track on")
		return
	var t: float = TrackingEval.seq_time_of(c, mt)
	_toast("Lost at %s, drag it back and track on" % Timecode.format(t, float(s.get("fps")), bool(s.get("drop_frame"))))


func _toast(text: String) -> void:
	var ev: Node = get_node_or_null("/root/Events")
	if ev != null:
		ev.call("toast", text)

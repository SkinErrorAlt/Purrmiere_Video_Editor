extends Node

signal finished(built: int, failed: int)

const Proxies := preload("res://engine/proxies.gd")
const ProxyBuilder := preload("res://engine/proxy_builder.gd")
const ViewMap := preload("res://doc/view_map.gd")
const PAIR_VIEW_ID := "pair_view"
const NODE_NAME := "ProxyQueue"
const SCRIPT_PATH := "res://engine/proxy_queue.gd"
const SAMPLE_SECONDS := 1.0
const PAD_SECONDS := 0.5
const OPEN_WAIT_MS := 20000
const SLOT_POLL_SECONDS := 0.1
const HOLD_POLL_SECONDS := 0.25
const POLICY_GO := "go"
const POLICY_HOLD := "hold"
const POLICY_SKIP := "skip"

var queue: Array[Dictionary] = []
var running: bool = false
var cancelled: bool = false
var total: int = 0
var done: int = 0
var built: int = 0
var failed: int = 0
var last_error: String = ""
var job_id: int = -1
var _builder: Node = null
var _handles: Dictionary = {}
var _slot_path: String = ""
var slot_waits: int = 0
var auto_policy: Callable = Callable()
var held_ms: int = 0
var skipped: int = 0
var _manual_in_run: bool = false
var picks: Array[Dictionary] = []
var playhead_source: Callable = Callable()
const FAR := 1.0e12
const USE_STEP_SECONDS := 0.25


static func instance() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var root: Window = (loop as SceneTree).root
	var n: Node = root.get_node_or_null(NODE_NAME)
	if n == null:
		var script: GDScript = load(SCRIPT_PATH)
		n = script.new()
		n.name = NODE_NAME
		root.add_child(n)
	return n


static func _root_node(node_name: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(node_name)
	return null


static func clip_spans(c: Object, from_t: float, to_t: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var a: float = maxf(float(c.get("start")), from_t)
	var b: float = minf(float(c.call("end")), to_t)
	if b <= a:
		return out
	var entries: Array = []
	for ev: Variant in c.get("effects"):
		var e: Dictionary = ev
		if String(e.get("id", "")) == PAIR_VIEW_ID and bool(e.get("enabled", true)):
			entries.append(e)
	var lo: Array[float] = [1.0e18]
	var hi: Array[float] = [-1.0e18]
	var slots: Array[Dictionary] = []
	for ei: int in entries.size():
		var e2: Dictionary = entries[ei]
		for i: int in mini(ViewMap.crop_count(e2), ViewMap.REGION_MAX):
			if ViewMap.has_offset(e2, i):
				slots.append({"e": e2, "i": i})
				lo.append(1.0e18)
				hi.append(-1.0e18)
	var t: float = a
	while true:
		var at: float = minf(t, b - 0.0005)
		var st: float = float(c.call("source_time", at))
		lo[0] = minf(lo[0], st)
		hi[0] = maxf(hi[0], st)
		for k: int in slots.size():
			var o: float = ViewMap.offset_at(slots[k]["e"], int(slots[k]["i"]), c, at - float(c.get("start")))
			lo[k + 1] = minf(lo[k + 1], st - o)
			hi[k + 1] = maxf(hi[k + 1], st - o)
		if t >= b:
			break
		t = minf(t + SAMPLE_SECONDS, b)
	for k2: int in lo.size():
		if hi[k2] >= lo[k2]:
			out.append(Vector2(maxf(lo[k2] - PAD_SECONDS, 0.0), hi[k2] + PAD_SECONDS))
	return out


static func used_spans(doc: Object, media_id: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if doc == null:
		return out
	for s: Variant in doc.get("sequences"):
		var sq: Object = s
		for tr: Variant in sq.call("picture_tracks"):
			var track: Object = tr
			for cv: Variant in track.get("clips"):
				var c: Object = cv
				if String(c.get("media_id")) != media_id or not bool(track.call("is_picture", c)):
					continue
				out.append_array(clip_spans(c, -1.0e18, 1.0e18))
	return out


static func segments_for(doc: Object, m: Object, used_only: bool) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if m == null:
		return out
	var fps: float = float(m.get("fps"))
	var duration: float = float(m.get("duration"))
	if fps <= 0.0 or duration <= 0.0:
		return out
	var want: Dictionary = {}
	if used_only:
		for span: Vector2 in used_spans(doc, String(m.get("id"))):
			for i: int in Proxies.segments_for_span(span.x, minf(span.y, duration), fps, duration):
				want[i] = true
	if want.is_empty():
		for i: int in Proxies.segment_count_for(duration, fps):
			want[i] = true
	var keys: Array = want.keys()
	keys.sort()
	for k: Variant in keys:
		out.append(int(k))
	return out


static func describe(doc: Object, m: Object) -> Dictionary:
	var prefs: Node = _root_node("Prefs")
	var out: Dictionary = {"root": "", "built": 0, "count": 0, "used": 0, "used_built": 0, "bytes": 0}
	if m == null or prefs == null or String(m.get("path")).is_empty():
		return out
	var fps: float = float(m.get("fps"))
	var duration: float = float(m.get("duration"))
	var r: String = Proxies.root_now(prefs, String(m.get("path")), int(m.get("width")))
	out["root"] = r
	out["count"] = Proxies.segment_count_for(duration, fps)
	out["built"] = Proxies.built_segments(r, duration, fps).size()
	out["bytes"] = Proxies.bytes_used(r, duration, fps)
	var used: PackedInt32Array = segments_for(doc, m, true)
	out["used"] = used.size()
	var have: int = 0
	for i: int in used:
		if Proxies.have(r, i):
			have += 1
	out["used_built"] = have
	return out


func make_for(doc: Object, media_ids: PackedStringArray, used_only: bool = true, auto: bool = false) -> int:
	var prefs: Node = _root_node("Prefs")
	if doc == null or prefs == null:
		return 0
	var added: int = 0
	for id: String in media_ids:
		var m: Object = doc.call("media_by_id", id)
		if m == null or String(m.get("kind")) != "video" or String(m.get("path")).is_empty() or not FileAccess.file_exists(String(m.get("path"))):
			continue
		var r: String = Proxies.root_now(prefs, String(m.get("path")), int(m.get("width")))
		for i: int in segments_for(doc, m, used_only):
			if Proxies.have(r, i):
				continue
			if _queued(String(m.get("path")), i):
				for e1: Dictionary in queue:
					if String(e1["path"]) == String(m.get("path")) and int(e1["index"]) == i and bool(e1.get("around", false)):
						e1["auto"] = auto
						e1.erase("around")
				continue
			queue.append({"path": String(m.get("path")), "label": String(m.get("label")), "index": i, "fps": float(m.get("fps")), "duration": float(m.get("duration")), "w": int(m.get("width")), "h": int(m.get("height")), "root": r, "auto": auto})
			added += 1
		if not auto and added > 0:
			_manual_in_run = true
			for e2: Dictionary in queue:
				if String(e2["path"]) == String(m.get("path")):
					e2["auto"] = false
	total += added
	if added > 0 and not running:
		_pump()
	return added


func queue_around(doc: Object, wanted: Array[Dictionary]) -> int:
	var prefs: Node = _root_node("Prefs")
	if doc == null or prefs == null:
		return 0
	var added: int = 0
	for w: Dictionary in wanted:
		var m: Object = doc.call("media_by_id", String(w.get("media_id", "")))
		if m == null or String(m.get("kind")) != "video" or String(m.get("path")).is_empty() or not FileAccess.file_exists(String(m.get("path"))):
			continue
		var r: String = Proxies.root_now(prefs, String(m.get("path")), int(m.get("width")))
		var i: int = int(w.get("index", -1))
		if i < 0 or Proxies.have(r, i) or _queued(String(m.get("path")), i):
			continue
		queue.append({"path": String(m.get("path")), "label": String(m.get("label")), "index": i, "fps": float(m.get("fps")), "duration": float(m.get("duration")), "w": int(m.get("width")), "h": int(m.get("height")), "root": r, "auto": false, "around": true})
		added += 1
	total += added
	if added > 0 and not running:
		_pump()
	return added


func forget_for(doc: Object, media_ids: PackedStringArray) -> int:
	var prefs: Node = _root_node("Prefs")
	var session: Node = _root_node("Session")
	if doc == null or prefs == null:
		return 0
	var gone: int = 0
	for id: String in media_ids:
		var m: Object = doc.call("media_by_id", id)
		if m == null or String(m.get("path")).is_empty():
			continue
		var r: String = Proxies.root_now(prefs, String(m.get("path")), int(m.get("width")))
		var keep: Array[Dictionary] = []
		for e: Dictionary in queue:
			if String(e["root"]) != r:
				keep.append(e)
		queue = keep
		if session != null and session.has_method("forget_proxies"):
			session.call("forget_proxies", r)
		gone += Proxies.forget_all(r, float(m.get("duration")), float(m.get("fps")))
	Proxies.forget_known()
	return gone


func drop_auto(path: String = "") -> int:
	var keep: Array[Dictionary] = []
	var gone: int = 0
	for e: Dictionary in queue:
		if bool(e.get("auto", false)) and (path.is_empty() or String(e["path"]) == path):
			gone += 1
		else:
			keep.append(e)
	queue = keep
	total = maxi(total - gone, done)
	return gone


func queued_count(auto_only: bool = false) -> int:
	var n: int = 0
	for e: Dictionary in queue:
		if not auto_only or bool(e.get("auto", false)):
			n += 1
	return n


func _policy(e: Dictionary) -> String:
	if not bool(e.get("auto", false)) or not auto_policy.is_valid():
		return POLICY_GO
	return String(auto_policy.call(String(e["path"])))


func cancel() -> void:
	cancelled = true
	queue.clear()
	_give_slot()
	if _builder != null and is_instance_valid(_builder):
		_builder.call("cancel")


func _queued(path: String, index: int) -> bool:
	for e: Dictionary in queue:
		if String(e["path"]) == path and int(e["index"]) == index:
			return true
	return false


func _codec() -> String:
	var bridge: Node = _root_node("PurrBridge")
	if bridge == null or not bool(bridge.get("available")):
		return ""
	var list: Variant = bridge.call("encoders")
	return Proxies.codec_for(list if list is Array else [])


func _handle(path: String) -> int:
	if _handles.has(path):
		return int(_handles[path])
	var bridge: Node = _root_node("PurrBridge")
	if bridge == null or not bool(bridge.get("available")):
		return -1
	var h: int = int(bridge.call("open_media", path, {"hw": false}))
	if h < 0:
		return -1
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < OPEN_WAIT_MS:
		var info: Dictionary = bridge.call("media_info", h)
		if bool(info.get("ok", false)):
			break
		await get_tree().process_frame
	_handles[path] = h
	return h


func _take_slot(path: String) -> bool:
	var bridge: Node = _root_node("PurrBridge")
	if bridge == null or not bridge.has_method("take_drive_slot"):
		return true
	var waited: bool = false
	while not cancelled:
		if bool(bridge.call("take_drive_slot", path)):
			_slot_path = path
			if waited:
				slot_waits += 1
			return true
		waited = true
		await get_tree().create_timer(SLOT_POLL_SECONDS).timeout
	return false


func _give_slot() -> void:
	if _slot_path.is_empty():
		return
	var bridge: Node = _root_node("PurrBridge")
	if bridge != null and bridge.has_method("give_drive_slot"):
		bridge.call("give_drive_slot", _slot_path)
	_slot_path = ""


func _exit_tree() -> void:
	_give_slot()


func _close_handles() -> void:
	var bridge: Node = _root_node("PurrBridge")
	for p: Variant in _handles.keys():
		if bridge != null:
			bridge.call("close_media", int(_handles[p]))
	_handles = {}


func _on_job_done(id: int, ok: bool) -> void:
	if id == job_id and not ok and running:
		cancel()


func _pump() -> void:
	running = true
	cancelled = false
	var jobs: Node = _root_node("Jobs")
	var prefs: Node = _root_node("Prefs")
	if jobs != null:
		job_id = int(jobs.call("add_local", "Making proxies" if _manual_in_run else "Making proxies for footage on slow drives", "proxy"))
		if not jobs.is_connected("job_done", _on_job_done):
			jobs.connect("job_done", _on_job_done)
	var codec: String = _codec()
	if codec.is_empty():
		last_error = "this engine has no h264 encoder, so no proxy can be made"
		failed += queue.size()
		queue.clear()
	_builder = ProxyBuilder.new()
	add_child(_builder)
	while not queue.is_empty() and not cancelled:
		var e: Dictionary = take_next()
		var policy: String = _policy(e)
		while policy == POLICY_HOLD and not cancelled:
			var t_hold: int = Time.get_ticks_msec()
			await get_tree().create_timer(HOLD_POLL_SECONDS).timeout
			held_ms += Time.get_ticks_msec() - t_hold
			policy = _policy(e)
		if cancelled:
			break
		if policy == POLICY_SKIP:
			skipped += 1
			done += 1
			continue
		var h: int = await _handle(String(e["path"]))
		var width: int = Proxies.wanted_width(Proxies.size_for(prefs), Proxies.width_for(prefs), int(e["w"]))
		var crf: int = Proxies.quality_for(prefs)
		var made: Dictionary = {"ok": false, "why": "the file did not open"}
		if bool(e.get("auto", false)):
			_builder.set("pause_check", func() -> bool: return _policy(e) == POLICY_HOLD)
		else:
			_builder.set("pause_check", Callable())
		if h >= 0 and await _take_slot(String(e["path"])):
			made = await _builder.call("build_segment", h, String(e["root"]), int(e["index"]), float(e["fps"]), float(e["duration"]), int(e["w"]), int(e["h"]), width, crf, codec)
			_give_slot()
		elif h >= 0:
			made = {"ok": false, "why": "cancelled while waiting for the drive"}
		done += 1
		if bool(made.get("ok", false)):
			built += 1
		else:
			failed += 1
			last_error = String(made.get("why", ""))
		if jobs != null and job_id >= 0:
			jobs.call("update_local", job_id, float(done) / float(maxi(total, 1)))
	if _builder != null and is_instance_valid(_builder):
		_builder.queue_free()
	_builder = null
	_close_handles()
	if jobs != null and job_id >= 0 and not cancelled:
		jobs.call("done_local", job_id, failed == 0)
	job_id = -1
	running = false
	var b: int = built
	var f: int = failed
	var loud: bool = _manual_in_run
	_manual_in_run = false
	total = 0
	done = 0
	built = 0
	failed = 0
	var events: Node = _root_node("Events")
	if events != null and events.has_method("toast") and (loud or f > 0):
		if f == 0:
			events.call("toast", "Proxies ready: %d part%s built" % [b, "" if b == 1 else "s"])
		else:
			events.call("toast", "Proxies: %d built, %d could not be made (%s)" % [b, f, last_error])
	finished.emit(b, f)


func _playhead_now() -> Dictionary:
	if playhead_source.is_valid():
		var v: Variant = playhead_source.call()
		if v is Dictionary:
			return v
	var session: Node = _root_node("Session")
	if session == null or session.get("doc") == null:
		return {}
	var d: Object = session.get("doc")
	var sq: Object = d.call("active_sequence")
	if sq == null:
		return {}
	return {"seq": sq, "t": float(session.call("playhead"))}


static func uses_of(sq: Object, path: String, doc: Object) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if sq == null or doc == null:
		return out
	for tr: Variant in sq.call("picture_tracks"):
		var track: Object = tr
		for cv: Variant in track.get("clips"):
			var c: Object = cv
			var m: Object = doc.call("media_by_id", String(c.get("media_id")))
			if m == null or String(m.get("path")) != path:
				continue
			var a: float = float(c.get("start"))
			var b: float = float(c.call("end"))
			var t: float = a
			while t < b:
				out.append(Vector2(t, float(c.call("source_time", t))))
				t += USE_STEP_SECONDS
			out.append(Vector2(b, float(c.call("source_time", maxf(b - 0.0005, a)))))
	return out


static func distance_of(uses: PackedVector2Array, index: int, fps: float, playhead: float) -> float:
	var a: float = Proxies.segment_start_for(index, fps)
	var b: float = Proxies.segment_start_for(index + 1, fps)
	var best: float = FAR
	for u: Vector2 in uses:
		if u.y >= a and u.y < b:
			best = minf(best, absf(u.x - playhead))
	return best


func take_next() -> Dictionary:
	if queue.size() <= 1:
		var only: Dictionary = queue.pop_front()
		picks.append(only)
		return only
	var here: Dictionary = _playhead_now()
	var session: Node = _root_node("Session")
	var d: Object = session.get("doc") if session != null else null
	if here.has("doc"):
		d = here["doc"]
	var uses: Dictionary = {}
	var best_i: int = 0
	var best_score: float = INF
	for i: int in queue.size():
		var e: Dictionary = queue[i]
		var path: String = String(e["path"])
		if not uses.has(path):
			uses[path] = uses_of(here.get("seq", null), path, d) if not here.is_empty() else PackedVector2Array()
		var dist: float = distance_of(uses[path], int(e["index"]), float(e["fps"]), float(here.get("t", 0.0)))
		var score: float = dist + (0.0 if dist < FAR else float(i))
		if score < best_score:
			best_score = score
			best_i = i
	var picked: Dictionary = queue[best_i]
	queue.remove_at(best_i)
	picked["distance"] = best_score
	picks.append(picked)
	if picks.size() > 256:
		picks.remove_at(0)
	return picked

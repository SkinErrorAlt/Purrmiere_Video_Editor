extends Node

const SELF_PATH := "res://engine/drive_bake.gd"
const TICKER_NAME := "DriveBake"
const AnimProp := preload("res://doc/anim_prop.gd")
const AnimDriver := preload("res://doc/anim_driver.gd")
const DriveSources := preload("res://engine/drive_sources.gd")
const BUDGET_USEC := 4000
const SYNC_USEC := 20000
const READY_POLL_MS := 250
const DONE_MAX := 256
const MAX_STEPS := 200000
const COMPUTED: PackedStringArray = ["src_prop", "src_dur", "src_comp", "shift", "taps_at", "taps_w"]

static var _done: Dictionary = {}
static var _last_good: Dictionary = {}
static var _jobs: Dictionary = {}
static var _waiting: Dictionary = {}
static var _ticker: Node = null
static var _push_due: bool = false
static var _poll_ms: int = 0
static var background: bool = true
static var completed: int = 0
static var pushes: int = 0
static var sync_runs: int = 0
static var started: int = 0
static var step_usec: int = 0


static func _session() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null("/root/Session")


static func _bare(layer: Dictionary) -> Dictionary:
	var out: Dictionary = layer.duplicate(true)
	for k: String in COMPUTED:
		out.erase(k)
	return out


static func _owner(doc: Object, layer: Dictionary) -> Object:
	var src: Dictionary = AnimProp.driven_source(layer)
	var oid: String = str(src.get("owner", ""))
	var found: Variant = doc.call("clip_by_id", oid if not oid.is_empty() else str(src.get("clip", "")))
	return found if found is Object else null


static func ident(layer: Dictionary, doc: Object, fps: float) -> String:
	var owner: Object = _owner(doc, layer)
	var timing: String = ""
	if owner != null:
		timing = "%s,%s,%s,%s,%d" % [String(owner.get("id")), str(owner.get("start")), str(owner.get("duration")), str(owner.get("in_offset")), (owner.get("speed") as Dictionary).hash()]
	return str(_bare(layer).hash()) + "|" + timing + "|" + str(fps) + "|" + str(doc.get_instance_id())


static func readiness(layer: Dictionary, doc: Object) -> Dictionary:
	var src: Dictionary = AnimProp.driven_source(layer)
	var kind: String = str(src.get("kind", "value"))
	if kind == "value":
		var c: Object = doc.call("clip_by_id", str(src.get("clip", "")))
		var p: Variant = c.call("get_param", str(src.get("path", ""))) if c != null else {}
		return {"ready": true, "sig": "v" + str((p as Dictionary).hash() if p is Dictionary else 0)}
	var owner: Object = DriveSources.owner_of(doc, src)
	if owner == null:
		return {"ready": true, "sig": "none"}
	var got: Dictionary = DriveSources.entry_for(doc, src, owner, float(owner.get("start")))
	if not bool(got["ok"]):
		return {"ready": true, "sig": "off"}
	var e: Dictionary = got["entry"]
	var fk: String = String((got["feed"] as Dictionary).get("key", "")) if got.has("feed") else String(e.get("key", ""))
	return {"ready": bool(e.get("done", true)), "sig": fk + "#" + str(int(e.get("serial", 0))) + ("d" if bool(e.get("done", true)) else "b")}


static func _sync_allowed() -> bool:
	if not background:
		return true
	var s: Node = _session()
	if s == null:
		return true
	if s.has_method("exporting") and bool(s.call("exporting")):
		return true
	return false


static func bake(layer: Dictionary, doc: Object, fps: float) -> Dictionary:
	if doc == null:
		return {}
	var base: String = ident(layer, doc, fps)
	var rd: Dictionary = readiness(layer, doc)
	var key: String = base + "|" + String(rd["sig"])
	var hit: Variant = _done.get(key, null)
	if hit is Dictionary:
		return hit
	var full: bool = _sync_allowed()
	if not bool(rd["ready"]) and not full:
		_waiting[base] = {"layer": _bare(layer), "doc": weakref(doc), "fps": fps}
		_ensure_ticker()
		return _last_good.get(base, {})
	var job: Dictionary = _jobs.get(key, {})
	if job.is_empty():
		job = _new_job(layer, doc, fps, key, base)
		if job.is_empty():
			return {}
		started += 1
	sync_runs += 1
	_step(job, MAX_STEPS * 1000000 if full else SYNC_USEC)
	if bool(job["finished"]):
		_jobs.erase(key)
		return _finish(job)
	_jobs[key] = job
	_ensure_ticker()
	return _last_good.get(base, {})


static func _new_job(layer: Dictionary, doc: Object, fps: float, key: String, base: String) -> Dictionary:
	var owner: Object = _owner(doc, layer)
	if owner == null:
		return {}
	var dur: float = maxf(float(owner.get("duration")), 0.0)
	var rate: float = fps if fps > 0.0 else 30.0
	var n: int = clampi(int(ceil(dur * rate)), 1, MAX_STEPS)
	return {"key": key, "base": base, "layer": _bare(layer), "doc": weakref(doc), "rate": rate, "dur": dur, "n": n, "i": 0, "keys": [], "last": 0.0, "any": false, "finished": false}


static func _step(job: Dictionary, budget_usec: int) -> void:
	var doc: Object = (job["doc"] as WeakRef).get_ref()
	if doc == null:
		job["finished"] = true
		job["any"] = false
		return
	var t0: int = Time.get_ticks_usec()
	var was: Object = AnimDriver.bound()
	if was != doc:
		AnimDriver.bind(doc)
	var layer: Dictionary = job["layer"]
	var keys: Array = job["keys"]
	var n: int = int(job["n"])
	var dur: float = float(job["dur"])
	var rate: float = float(job["rate"])
	var i: int = int(job["i"])
	var last: float = float(job["last"])
	var any: bool = bool(job["any"])
	AnimDriver.baking += 1
	while i <= n:
		var t: float = dur * float(i) / float(n)
		var got: Dictionary = AnimDriver.driven_raw(layer, t, rate)
		if bool(got.get("ok", false)):
			last = AnimProp.driven_map(layer, float(got.get("raw", got.get("v", 0.0))), 0, t, dur, rate)
			any = true
		keys.append({"t": t, "v": last, "i": "linear"})
		i += 1
		if (i & 15) == 0 and Time.get_ticks_usec() - t0 > budget_usec:
			break
	AnimDriver.baking -= 1
	if was != doc:
		if was != null:
			AnimDriver.bind(was)
		else:
			AnimDriver.unbind()
	job["i"] = i
	job["last"] = last
	job["any"] = any
	job["keys"] = keys
	job["finished"] = i > n
	step_usec += Time.get_ticks_usec() - t0


static func _finish(job: Dictionary) -> Dictionary:
	completed += 1
	if not bool(job["any"]):
		_store(String(job["key"]), String(job["base"]), {})
		return {}
	var out: Dictionary = {"keys": job["keys"], "last": float(job["last"]), "dur": float(job["dur"])}
	_store(String(job["key"]), String(job["base"]), out)
	return out


static func _store(key: String, base: String, out: Dictionary) -> void:
	if _done.size() >= DONE_MAX:
		_done = {}
	_done[key] = out
	_last_good[base] = out
	if _last_good.size() > DONE_MAX:
		_last_good = {}


static func _ensure_ticker() -> void:
	if _ticker != null and is_instance_valid(_ticker) and _ticker.is_inside_tree():
		return
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var root: Window = (loop as SceneTree).root
	var have: Node = root.get_node_or_null(TICKER_NAME)
	if have != null:
		_ticker = have
		return
	var t: Node = (load(SELF_PATH) as GDScript).new()
	t.name = TICKER_NAME
	root.add_child.call_deferred(t)
	_ticker = t


static func busy() -> bool:
	return not _jobs.is_empty() or not _waiting.is_empty()


static func pump(budget_usec: int) -> bool:
	var t0: int = Time.get_ticks_usec()
	var finished_any: bool = false
	for k: Variant in _jobs.keys():
		var job: Dictionary = _jobs[k]
		var left: int = budget_usec - (Time.get_ticks_usec() - t0)
		if left <= 0:
			break
		_step(job, left)
		if bool(job["finished"]):
			_jobs.erase(k)
			_finish(job)
			finished_any = true
	var now: int = Time.get_ticks_msec()
	if not _waiting.is_empty() and now - _poll_ms >= READY_POLL_MS:
		_poll_ms = now
		for b: Variant in _waiting.keys():
			var w: Dictionary = _waiting[b]
			var doc: Object = (w["doc"] as WeakRef).get_ref()
			if doc == null:
				_waiting.erase(b)
				continue
			if bool(readiness(w["layer"], doc)["ready"]):
				_waiting.erase(b)
				finished_any = true
	if finished_any:
		_push_due = true
	return finished_any


func _process(_dt: float) -> void:
	if busy():
		pump(BUDGET_USEC)
	if _push_due:
		_push_due = false
		var s: Node = _session()
		if s != null and s.has_method("push_playback_graph"):
			pushes += 1
			s.call_deferred("push_playback_graph")


static func forget() -> void:
	_done = {}
	_last_good = {}
	_jobs = {}
	_waiting = {}

extends Node

const Proxies := preload("res://engine/proxies.gd")
const ProxyQueue := preload("res://engine/proxy_queue.gd")
const NODE_NAME := "ProxyAround"
const SCRIPT_PATH := "res://engine/proxy_around.gd"
const REACH_SECONDS := 45.0
const CHECK_MS := 700
const MOVE_SECONDS := 2.0
const MOST_AT_ONCE := 4

var _doc: WeakRef = null
var _last_ms: int = -1000000
var _last_t: float = -1.0e9
var _last_count: int = -1
var checks: int = 0
var queued: int = 0
var reach_seconds: float = REACH_SECONDS


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


func watch(doc: Object) -> void:
	_doc = weakref(doc) if doc != null else null
	_last_t = -1.0e9


static func on_now() -> bool:
	var prefs: Node = _root_node("Prefs")
	return prefs != null and Proxies.on(prefs)


static func wanted(doc: Object, sq: Object, t: float, reach: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null or sq == null:
		return out
	var seen: Dictionary = {}
	for tr: Variant in sq.call("picture_tracks"):
		var track: Object = tr
		for cv: Variant in track.get("clips"):
			var c: Object = cv
			var a: float = float(c.get("start"))
			var b: float = float(c.call("end"))
			if b < t - reach or a > t + reach:
				continue
			var m: Object = doc.call("media_by_id", String(c.get("media_id")))
			if m == null or String(m.get("kind")) != "video" or float(m.get("fps")) <= 0.0:
				continue
			var fps: float = float(m.get("fps"))
			var duration: float = float(m.get("duration"))
			var from: float = maxf(a, t - reach)
			var to: float = minf(b, t + reach)
			var x: float = from
			while x <= to:
				var src: float = clampf(float(c.call("source_time", minf(x, b - 0.0005))), 0.0, maxf(duration - 0.001, 0.0))
				var idx: int = Proxies.segment_index_for(src, fps)
				var key: String = String(m.get("id")) + "#" + str(idx)
				var d: float = absf(x - t) if (x >= a and x <= b) else minf(absf(a - t), absf(b - t))
				if not seen.has(key) or float(seen[key]["distance"]) > d:
					seen[key] = {"media_id": String(m.get("id")), "index": idx, "distance": d}
				if x >= to:
					break
				x = minf(x + 1.0, to)
	for k: Variant in seen.keys():
		out.append(seen[k])
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["distance"]) < float(q["distance"]))
	return out


func check(force: bool = false) -> int:
	checks += 1
	if not on_now():
		return 0
	var doc: Object = _doc.get_ref() if _doc != null else null
	var session: Node = _root_node("Session")
	if doc == null and session != null:
		doc = session.get("doc")
	if doc == null or session == null:
		return 0
	if session.has_method("exporting") and bool(session.call("exporting")):
		return 0
	var sq: Object = doc.call("active_sequence")
	var t: float = float(session.call("playhead"))
	if not force and absf(t - _last_t) < MOVE_SECONDS:
		return 0
	_last_t = t
	var list: Array[Dictionary] = wanted(doc, sq, t, reach_seconds)
	var q: Node = ProxyQueue.instance()
	if q == null:
		return 0
	var take: Array[Dictionary] = []
	for w: Dictionary in list:
		take.append(w)
		if take.size() >= MOST_AT_ONCE * 4:
			break
	var added: int = int(q.call("queue_around", doc, take))
	queued += added
	return added


func _process(_dt: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_ms < CHECK_MS:
		return
	_last_ms = now
	check()

extends Node

const ProxyQueue := preload("res://engine/proxy_queue.gd")
const Verbs := preload("res://doc/verbs.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const NODE_NAME := "AutoProxies"
const SCRIPT_PATH := "res://engine/auto_proxies.gd"
const PREF := "media.auto_proxies"
const PREF_LABEL := "Build proxies automatically for slow drives"
const OFF_KEY := "auto_proxies_off"
const OPEN_DELAY_SECONDS := 1.0
const SETTLE_SECONDS := 2.0
const SLOW_LIMIT := 1

var scans: int = 0
var last_added: int = 0
var last_candidates: PackedStringArray = PackedStringArray()
var _doc: WeakRef = null
var _due_ms: int = -1


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


static func register() -> void:
	var prefs: Node = _root_node("Prefs")
	if prefs != null and not bool(prefs.call("is_registered", PREF)):
		prefs.call("register", PREF, false, {"label": PREF_LABEL, "type": "bool"})


static func enabled() -> bool:
	register()
	var prefs: Node = _root_node("Prefs")
	return prefs != null and bool(prefs.call("get_value", PREF))


static func is_slow(path: String) -> bool:
	var bridge: Node = _root_node("PurrBridge")
	if bridge == null or not bool(bridge.get("available")) or not bool(bridge.call("has_drives")):
		return false
	var v: Dictionary = bridge.call("volume_for_path", path)
	return int(v.get("limit", 0)) <= SLOW_LIMIT


static func file_off(m: Object) -> bool:
	if m == null:
		return true
	var props: Dictionary = m.get("props")
	return bool(props.get(OFF_KEY, false))


static func candidates(doc: Object) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null:
		return out
	for mv: Variant in doc.get("media"):
		var m: Object = mv
		var path: String = String(m.get("path"))
		if String(m.get("kind")) != "video" or path.is_empty() or bool(m.get("missing")) or file_off(m):
			continue
		if float(m.get("fps")) <= 0.0 or float(m.get("duration")) <= 0.0:
			continue
		if ProxyQueue.used_spans(doc, String(m.get("id"))).is_empty():
			continue
		if not FileAccess.file_exists(path) or not is_slow(path):
			continue
		out.append(String(m.get("id")))
	return out


const FRAME_CAP_PATH := "res://host/frame_cap.gd"
const BUSY_MS := 5000


static func hold_reason() -> String:
	var session: Node = _root_node("Session")
	if session == null:
		return ""
	if bool(session.get("playing")):
		return "playing"
	if session.has_method("exporting") and bool(session.call("exporting")):
		return "exporting"
	var cap: GDScript = load(FRAME_CAP_PATH)
	if cap != null and int(cap.get("ours")) >= 0 and Time.get_ticks_msec() - int(cap.get("active_ms")) < BUSY_MS:
		return "busy"
	return ""


static func policy_for(path: String) -> String:
	if not enabled():
		return ProxyQueue.POLICY_SKIP
	var session: Node = _root_node("Session")
	var doc: Object = session.get("doc") if session != null else null
	if doc != null:
		for mv: Variant in doc.get("media"):
			var m: Object = mv
			if String(m.get("path")) == path and file_off(m):
				return ProxyQueue.POLICY_SKIP
	if not hold_reason().is_empty():
		return ProxyQueue.POLICY_HOLD
	return ProxyQueue.POLICY_GO


func watch(doc: Object) -> void:
	var around: Node = load("res://engine/proxy_around.gd").call("instance")
	if around != null:
		around.call("watch", doc)
	if _doc != null:
		var old: Object = _doc.get_ref()
		if old != null and old.is_connected("changed", _on_doc_changed):
			old.disconnect("changed", _on_doc_changed)
	_doc = weakref(doc) if doc != null else null
	var q: Node = ProxyQueue.instance()
	if q != null:
		q.call("drop_auto")
	if doc == null:
		_due_ms = -1
		return
	doc.connect("changed", _on_doc_changed)
	_schedule(OPEN_DELAY_SECONDS)


func _schedule(seconds: float) -> void:
	_due_ms = Time.get_ticks_msec() + int(seconds * 1000.0)


func _on_doc_changed(_kind: String) -> void:
	_schedule(SETTLE_SECONDS)


func _process(_dt: float) -> void:
	if _due_ms >= 0 and Time.get_ticks_msec() >= _due_ms:
		_due_ms = -1
		scan()


func scan() -> int:
	scans += 1
	last_added = 0
	var doc: Object = _doc.get_ref() if _doc != null else null
	if doc == null or not enabled():
		last_candidates = PackedStringArray()
		return 0
	last_candidates = candidates(doc)
	if last_candidates.is_empty():
		return 0
	var q: Node = ProxyQueue.instance()
	if q == null:
		return 0
	if not (q.get("auto_policy") as Callable).is_valid():
		q.set("auto_policy", Callable(get_script(), "policy_for"))
	last_added = int(q.call("make_for", doc, last_candidates, true, true))
	return last_added


static func set_file_off(doc: Object, media_id: String, off: bool) -> bool:
	if doc == null:
		return false
	var m: Object = doc.call("media_by_id", media_id)
	if m == null or file_off(m) == off:
		return false
	var props: Dictionary = (m.get("props") as Dictionary).duplicate(true)
	if off:
		props[OFF_KEY] = true
	else:
		props.erase(OFF_KEY)
	var label: String = ("Stop building proxies automatically for " if off else "Build proxies automatically for ") + String(m.get("label"))
	var cmds: Array[Command] = [MediaCmds.SetMediaField.new(media_id, "props", props)]
	Verbs.run(doc, label, cmds)
	if off:
		var q: Node = ProxyQueue.instance()
		if q != null:
			q.call("drop_auto", String(m.get("path")))
	return true

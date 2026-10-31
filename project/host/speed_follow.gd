extends Node

const KeyAnchor := preload("res://doc/key_anchor.gd")
const PREF := "speed.playhead_follows"
const EPS := 0.0002

static var held_until: int = -1
static var current: Node = null
var anchor: Dictionary = {}
var follows: int = 0
var _moving: bool = false
var _doc: Object = null


func _ready() -> void:
	name = "SpeedFollow"
	current = self
	var s: Node = get_node_or_null("/root/Session")
	if s == null:
		return
	s.connect("playhead_changed", _on_playhead)
	s.connect("project_changed", _on_project)
	_on_project()


static func is_held() -> bool:
	return Engine.get_process_frames() <= held_until


static func pref_on() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs") if loop is SceneTree else null
	if prefs == null:
		return false
	if not bool(prefs.call("is_registered", PREF)):
		prefs.call("register", PREF, true, {"label": "When a clip's speed changes, the playhead moves with it so the same frame stays under it", "type": "bool"})
	return bool(prefs.call("get_value", PREF))


func _on_project() -> void:
	var s: Node = get_node_or_null("/root/Session")
	var d: Object = s.get("doc") if s != null else null
	if _doc != null and is_instance_valid(_doc) and _doc.is_connected("changed", _on_doc_changed):
		_doc.disconnect("changed", _on_doc_changed)
	_doc = d
	if d != null and not d.is_connected("changed", _on_doc_changed):
		d.connect("changed", _on_doc_changed)
	anchor = {}


func clip_at(seq: Object, t: float) -> Object:
	for id: String in seq.get("selected_clip_ids"):
		var c: Object = seq.call("clip_by_id", id)
		if c != null and float(c.get("start")) <= t and t < float(c.call("end")):
			return c
	var tracks: Array = seq.get("video_tracks")
	for i: int in range(tracks.size() - 1, -1, -1):
		for c2: Object in tracks[i].get("clips"):
			if bool(c2.get("enabled")) and float(c2.get("start")) <= t and t < float(c2.call("end")):
				return c2
	return null


func _on_playhead(t: float) -> void:
	if _moving or is_held():
		return
	note(t)


func note(t: float) -> void:
	var s: Node = get_node_or_null("/root/Session")
	var seq: Object = s.call("seq") if s != null else null
	anchor = {}
	if seq == null:
		return
	var c: Object = clip_at(seq, t)
	if c == null:
		return
	anchor = {"seq": String(seq.get("id")), "clip": String(c.get("id")), "t": t, "src": float(c.call("source_time_exact", t)), "speed": var_to_str(c.get("speed")), "start": float(c.get("start")), "in": float(c.get("in_offset"))}


func _on_doc_changed(kind: String) -> void:
	if is_held() or kind == "selection" or anchor.is_empty() or not pref_on():
		return
	var s: Node = get_node_or_null("/root/Session")
	if s == null or bool(s.get("playing")):
		return
	var seq: Object = s.call("seq")
	if seq == null or String(seq.get("id")) != String(anchor["seq"]):
		return
	var c: Object = seq.call("clip_by_id", String(anchor["clip"]))
	if c == null or not KeyAnchor.positive_speed(c):
		return
	var sig: String = var_to_str(c.get("speed"))
	if sig == String(anchor["speed"]) or absf(float(c.get("start")) - float(anchor["start"])) > EPS or absf(float(c.get("in_offset")) - float(anchor["in"])) > EPS:
		note(float(s.call("playhead")))
		return
	anchor["speed"] = sig
	var t: float = float(anchor["t"])
	var src: float = float(anchor["src"])
	if absf(float(c.call("source_time_exact", t)) - src) <= EPS:
		return
	var nt: float = float(c.get("start")) + KeyAnchor.local_for_source(c, src)
	anchor["t"] = nt
	follows += 1
	_moving = true
	s.call("set_playhead", maxf(nt, 0.0))
	_moving = false

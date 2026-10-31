extends RefCounted

const PREF_TIMELINE := "timeline.glide_click"
const PREF_KEYFRAMES := "timeline.keyframe_glide_click"
const MIN_SPAN := 0.0005

var from_t: float = 0.0
var to_t: float = 0.0
var at: float = 0.0
var length: float = 0.0


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/Prefs")
	return null


static func _tokens() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/Tk")
	return null


static func register_prefs() -> void:
	var prefs: Node = _prefs()
	if prefs == null:
		return
	var specs: Array = [
		[PREF_TIMELINE, false, {"label": "Timeline: glide the playhead to a click", "type": "bool", "hint": "Off: a click on the timeline goes straight to the exact frame. On: the playhead glides there and the picture runs through the frames on the way."}],
		[PREF_KEYFRAMES, true, {"label": "Keyframe editor: glide the playhead to a click", "type": "bool", "hint": "On: a click in a keyframe editor glides the playhead there, so you see the keyed values change. Off: it goes straight there."}],
	]
	for spec: Array in specs:
		if not bool(prefs.call("is_registered", String(spec[0]))):
			prefs.call("register", String(spec[0]), spec[1], spec[2])


static func _on(key: String, fallback: bool) -> bool:
	register_prefs()
	var prefs: Node = _prefs()
	if prefs == null or not bool(prefs.call("is_registered", key)):
		return fallback
	return bool(prefs.call("get_value", key))


static func timeline_on() -> bool:
	return _on(PREF_TIMELINE, false)


static func keyframes_on() -> bool:
	return _on(PREF_KEYFRAMES, true)


static func length_for(span: float) -> float:
	var tk: Node = _tokens()
	var full: float = float(tk.call("dur", "fast")) if tk != null else 0.18
	if span < MIN_SPAN or full <= 0.0:
		return 0.0
	return clampf(full * 0.5 + span * 0.02, full * 0.5, full * 1.5)


static func shape(f: float) -> float:
	var x: float = clampf(f, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func start(from: float, to: float) -> bool:
	from_t = from
	to_t = to
	at = 0.0
	length = length_for(absf(to - from))
	return length > 0.0


func active() -> bool:
	return length > 0.0


func stop() -> void:
	length = 0.0


func step(dt: float) -> float:
	if length <= 0.0:
		return to_t
	at += dt
	var f: float = clampf(at / length, 0.0, 1.0)
	if f >= 1.0:
		length = 0.0
		return to_t
	return lerpf(from_t, to_t, shape(f))

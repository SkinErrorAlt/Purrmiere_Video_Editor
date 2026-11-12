extends RefCounted

const AUDIO_GRAPH_PATH := "res://engine/audio_graph.gd"
const PREF_PITCH := "playback.shuttle_keep_pitch"
const FAST: Array[float] = [1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0, 100.0]
const SLOW: Array[float] = [0.5, 0.25, 0.1, 0.05, 0.01]
const MIN_RATE := 0.01
const MAX_RATE := 100.0

static var pitch_on: bool = false
static var pushes: int = 0
static var plant_old: bool = false
const OLD_FAST: Array[float] = [1.0, 2.0, 4.0, 8.0, 16.0, 32.0]


static func _autoload(name_: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(name_)
	return null


static func register_prefs() -> void:
	var prefs: Node = _autoload("Prefs")
	if prefs != null and not bool(prefs.call("is_registered", PREF_PITCH)):
		prefs.call("register", PREF_PITCH, true, {"label": "Keep the pitch while J, K and L change the speed", "type": "bool"})


static func keeps_pitch() -> bool:
	register_prefs()
	var prefs: Node = _autoload("Prefs")
	return prefs == null or bool(prefs.call("get_value", PREF_PITCH))


static func clamp_rate(r: float) -> float:
	if r == 0.0:
		return 0.0
	return signf(r) * clampf(absf(r), MIN_RATE, MAX_RATE)


static func next_fast(rate: float, dir: float, playing: bool) -> float:
	if playing and signf(rate) == dir and absf(rate) >= 1.0:
		var mag: float = absf(rate)
		var list: Array[float] = OLD_FAST if plant_old else FAST
		for v: float in list:
			if v > mag + 0.0001:
				return dir * v
		return dir * list[list.size() - 1]
	return dir


static func next_slow(rate: float, dir: float, playing: bool) -> float:
	if playing and signf(rate) == dir and absf(rate) < 1.0 and not plant_old:
		var mag: float = absf(rate)
		for v: float in SLOW:
			if v < mag - 0.00001:
				return dir * v
		return dir * MIN_RATE
	return dir * SLOW[0]


static func apply(rate: float) -> void:
	var s: Node = _autoload("Session")
	if s == null:
		return
	var r: float = clamp_rate(rate)
	s.call("set_rate", r)
	set_pitch(absf(r) != 1.0 and keeps_pitch() and not plant_old)
	if not bool(s.get("playing")):
		s.call("set_playing", true)


static func stop() -> void:
	var s: Node = _autoload("Session")
	if s != null:
		s.call("set_playing", false)
		s.call("set_rate", 1.0)
	set_pitch(false)


static func set_pitch(on: bool) -> void:
	if on == pitch_on:
		return
	pitch_on = on
	var graph: GDScript = load(AUDIO_GRAPH_PATH)
	if graph == null:
		return
	graph.set("hold_keep_pitch", on)
	pushes += 1
	var s: Node = _autoload("Session")
	if s != null and s.has_method("push_playback_graph"):
		s.call("push_playback_graph")

extends RefCounted

const PREF_DB := "waves.very_loud_db"
const PREF_ACTION := "waves.loud_action"
const PREF_DOWN_DB := "waves.loud_down_db"
const PREF_PERCENT := "waves.loud_percent"
const PREF_GRADIENT_DB := "waves.loud_gradient_db"
const PREF_RELEASE := "waves.loud_release_ms"
const PREF_JUDGE := "waves.loud_judged_on"
const GRAPH_KEY := "very_loud"
const ACTION_OFF := "Off"
const ACTION_HOLD := "Hold it at the line"
const ACTION_DOWN := "Turn down by dB"
const ACTION_PERCENT := "Turn down to a percent"
const ACTION_MUTE := "Mute"
const ACTION_GRADIENT := "Turn down on a gradient"
const ACTIONS: PackedStringArray = ["Off", "Hold it at the line", "Turn down by dB", "Turn down to a percent", "Mute", "Turn down on a gradient"]
const DEFAULT_DB := -1.0
const DEFAULT_ACTION := "Hold it at the line"
const DEFAULT_DOWN_DB := 6.0
const DEFAULT_PERCENT := 50.0
const DEFAULT_GRADIENT_DB := 6.0
const DEFAULT_RELEASE := 60.0
const JUDGE_FILE := "The file's own level"
const JUDGE_HEARD := "What you hear, after volume and effects"
const JUDGES: PackedStringArray = ["What you hear, after volume and effects", "The file's own level"]
const DEFAULT_JUDGE := "What you hear, after volume and effects"
const MIN_DB := -24.0
const MAX_DB := 0.0


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/Prefs")
	return null


static func register_prefs() -> void:
	var p: Node = _prefs()
	if p == null:
		return
	var specs: Array = [
		[PREF_DB, DEFAULT_DB, {"label": "Very loud line (dBFS)", "type": "float", "min": MIN_DB, "max": MAX_DB, "hint": "Sounds above this are marked on every wave and handled by the very loud action."}],
		[PREF_ACTION, DEFAULT_ACTION, {"label": "Very loud sounds: what happens", "type": "enum", "choices": ACTIONS, "hint": "Changes what you hear and what you export, the same way. Hold it at the line stops the sound going over the line and leaves everything quieter exactly as it was."}],
		[PREF_DOWN_DB, DEFAULT_DOWN_DB, {"label": "Very loud: turn down by (dB)", "type": "float", "min": 0.0, "max": 60.0, "hint": "Used by Turn down by dB, and as the most a gradient turns it down."}],
		[PREF_PERCENT, DEFAULT_PERCENT, {"label": "Very loud: turn down to (percent)", "type": "float", "min": 0.0, "max": 100.0}],
		[PREF_GRADIENT_DB, DEFAULT_GRADIENT_DB, {"label": "Very loud: gradient width (dB)", "type": "float", "min": 0.0, "max": 24.0, "hint": "How far over the line the turn down takes to reach its full amount."}],
		[PREF_RELEASE, DEFAULT_RELEASE, {"label": "Very loud: let go over (ms)", "type": "float", "min": 1.0, "max": 2000.0, "hint": "How quickly the sound comes back up after a very loud moment."}],
		[PREF_JUDGE, DEFAULT_JUDGE, {"label": "Very loud is judged on", "type": "enum", "choices": JUDGES, "hint": "What you hear judges each clip after its volume, its keys, the fades and its effects, so a loud file turned down is left alone and a quiet file turned up past the line is held. The file's own level judges the sound as it is in the file, before any of that."}],
	]
	for spec: Array in specs:
		if not bool(p.call("is_registered", String(spec[0]))):
			p.call("register", String(spec[0]), spec[1], spec[2])


static func _pref(p: Node, key: String, fallback: Variant) -> Variant:
	if p == null or not bool(p.call("is_registered", key)):
		return fallback
	return p.call("get_value", key)


static func mode_of(action: String) -> int:
	if action == ACTION_HOLD:
		return 0
	if action == ACTION_DOWN:
		return 1
	if action == ACTION_PERCENT:
		return 2
	if action == ACTION_MUTE:
		return 3
	if action == ACTION_GRADIENT:
		return 4
	return -1


static func heard_of(judge: String) -> bool:
	return judge != JUDGE_FILE


static func settings() -> Dictionary:
	var p: Node = _prefs()
	var action: String = String(_pref(p, PREF_ACTION, DEFAULT_ACTION))
	var judge: String = String(_pref(p, PREF_JUDGE, DEFAULT_JUDGE))
	return {
		"action": action,
		"mode": mode_of(action),
		"judge": judge,
		"heard": heard_of(judge),
		"db": clampf(float(_pref(p, PREF_DB, DEFAULT_DB)), MIN_DB, MAX_DB),
		"down_db": clampf(float(_pref(p, PREF_DOWN_DB, DEFAULT_DOWN_DB)), 0.0, 60.0),
		"percent": clampf(float(_pref(p, PREF_PERCENT, DEFAULT_PERCENT)), 0.0, 100.0),
		"gradient_db": clampf(float(_pref(p, PREF_GRADIENT_DB, DEFAULT_GRADIENT_DB)), 0.0, 24.0),
		"release_ms": clampf(float(_pref(p, PREF_RELEASE, DEFAULT_RELEASE)), 1.0, 2000.0),
	}


static func db_to_lin(db: float) -> float:
	return pow(10.0, db / 20.0)


static func lin_to_db(v: float) -> float:
	if v <= 0.0000001:
		return -140.0
	return 20.0 * log(v) / log(10.0)


static func gain_for(level: float, s: Dictionary) -> float:
	var mode: int = int(s.get("mode", -1))
	var thr: float = db_to_lin(float(s.get("db", DEFAULT_DB)))
	if mode < 0 or level <= thr:
		return 1.0
	if mode == 0:
		return thr / level
	if mode == 1:
		return db_to_lin(-float(s.get("down_db", DEFAULT_DOWN_DB)))
	if mode == 2:
		return clampf(float(s.get("percent", DEFAULT_PERCENT)) / 100.0, 0.0, 1.0)
	if mode == 3:
		return 0.0
	var over: float = lin_to_db(level / thr)
	var width: float = float(s.get("gradient_db", DEFAULT_GRADIENT_DB))
	var f: float = 1.0 if width <= 0.000000001 else minf(1.0, over / width)
	var sm: float = f * f * (3.0 - 2.0 * f)
	return db_to_lin(-float(s.get("down_db", DEFAULT_DOWN_DB)) * sm)


static func graph_entry(s: Dictionary) -> Dictionary:
	return {
		"mode": float(int(s.get("mode", -1))),
		"threshold_db": float(s.get("db", DEFAULT_DB)),
		"down_db": float(s.get("down_db", DEFAULT_DOWN_DB)),
		"percent": float(s.get("percent", DEFAULT_PERCENT)),
		"gradient_db": float(s.get("gradient_db", DEFAULT_GRADIENT_DB)),
		"release_ms": float(s.get("release_ms", DEFAULT_RELEASE)),
		"heard": 1.0 if bool(s.get("heard", true)) else 0.0,
	}


static func stamp(graph: Dictionary) -> Dictionary:
	var s: Dictionary = settings()
	if int(s["mode"]) >= 0:
		graph[GRAPH_KEY] = graph_entry(s)
	return graph


static func process_block(buf: PackedFloat32Array, sample_rate: int, s: Dictionary) -> PackedFloat32Array:
	var out: PackedFloat32Array = buf.duplicate()
	var mode: int = int(s.get("mode", -1))
	if mode < 0:
		return out
	var coef: float = exp(-1.0 / (maxf(1.0, float(s.get("release_ms", DEFAULT_RELEASE))) * 0.001 * float(maxi(sample_rate, 1))))
	var current: float = 1.0
	var frames: int = out.size() / 2
	for i: int in frames:
		var l: float = out[i * 2]
		var r: float = out[i * 2 + 1]
		var want: float = gain_for(maxf(absf(l), absf(r)), s)
		current = want if want < current else want + (current - want) * coef
		if current > 0.9999999:
			current = 1.0
			continue
		out[i * 2] = l * current
		out[i * 2 + 1] = r * current
	return out

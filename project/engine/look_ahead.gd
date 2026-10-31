extends RefCounted

const PREF := "playback.look_ahead"
const PREF_CUSTOM := "playback.look_ahead_steps"
const STEP_SECONDS := 2.0
const MIN_STEPS := 1
const MAX_STEPS := 10
const NONE := "None"
const DECENT := "Decent editing"
const HEAVY := "Heavy editing"
const QUICK := "Quick editing"
const CUSTOM := "Custom"
const CHOICES: PackedStringArray = [NONE, DECENT, HEAVY, QUICK, CUSTOM]
const STEPS: Dictionary = {NONE: 1, DECENT: 2, HEAVY: 3, QUICK: 5}
const LABEL := "How far ahead playback prepares the next clip"
const TIP := "None is what the editor has always done: the next clip is prepared about two seconds early. The others prepare further ahead, which helps a slow drive keep up at a cut and costs more memory and more work. Quick editing is the heaviest."
const CUSTOM_LABEL := "How far ahead, in steps of two seconds (only used when the one above is Custom)"


static func steps_for(choice: String, custom: int) -> int:
	if choice == CUSTOM:
		return clampi(custom, MIN_STEPS, MAX_STEPS)
	if STEPS.has(choice):
		return int(STEPS[choice])
	return MIN_STEPS


static func seconds_for(steps: int) -> float:
	return float(clampi(steps, MIN_STEPS, MAX_STEPS)) * STEP_SECONDS


static func heaviest(choice: String) -> bool:
	return choice == QUICK or choice == CUSTOM


static func describe(choice: String, custom: int) -> String:
	var n: int = steps_for(choice, custom)
	var secs: float = seconds_for(n)
	var text: String = str(n) + (" step" if n == 1 else " steps") + ", about " + String.num(secs, 0) + " s ahead"
	if choice == NONE:
		text += ", which is what it has always done"
	elif heaviest(choice):
		text += ", the heaviest setting"
	return text


static func register(prefs: Node) -> void:
	if prefs == null:
		return
	if not bool(prefs.call("is_registered", PREF)):
		prefs.call("register", PREF, NONE, {"label": LABEL, "type": "enum", "choices": Array(CHOICES), "tip": TIP})
	if not bool(prefs.call("is_registered", PREF_CUSTOM)):
		prefs.call("register", PREF_CUSTOM, 2, {"label": CUSTOM_LABEL, "type": "int", "min": MIN_STEPS, "max": MAX_STEPS})


static func current_steps(prefs: Node) -> int:
	if prefs == null or not bool(prefs.call("is_registered", PREF)):
		return MIN_STEPS
	return steps_for(String(prefs.call("get_value", PREF)), int(prefs.call("get_value", PREF_CUSTOM)) if bool(prefs.call("is_registered", PREF_CUSTOM)) else 2)


static func current_seconds(prefs: Node) -> float:
	return seconds_for(current_steps(prefs))

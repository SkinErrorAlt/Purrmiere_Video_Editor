extends Node

const PREF_ON := "input.block_double_press"
const PREF_MS := "input.double_press_ms"
const PREF_SPACE_MS := "input.double_space_ms"
const DEFAULT_MS := 45
const DEFAULT_SPACE_MS := 70
const MS_MIN := 0
const MS_MAX := 400
const HELD_GRACE_MS := 600

static var blocked: int = 0
static var last_blocked_key: int = 0
static var last_blocked_ms: int = 0

var _last_down: Dictionary = {}
var _held: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var prefs: Node = get_node_or_null("/root/Prefs")
	if prefs == null or not prefs.has_method("register"):
		return
	prefs.register(PREF_ON, true, {"label": "Block a key that presses itself twice", "type": "bool", "note": "For a keyboard that bounces: a second press of the same key inside the gap below is thrown away. Real double letters are slower than this, so typing is untouched."})
	prefs.register(PREF_MS, DEFAULT_MS, {"label": "Gap a repeat must beat, in milliseconds", "type": "int", "min": MS_MIN, "max": MS_MAX})
	prefs.register(PREF_SPACE_MS, DEFAULT_SPACE_MS, {"label": "The same gap for the space bar", "type": "int", "min": MS_MIN, "max": MS_MAX})


static func tool_run() -> bool:
	for a: String in OS.get_cmdline_args():
		if a == "--script":
			return true
	return false


static func real_keyboard() -> bool:
	return DisplayServer.get_name() != "headless" and not tool_run()


func on() -> bool:
	if not real_keyboard():
		return false
	var prefs: Node = get_node_or_null("/root/Prefs")
	if prefs == null or not prefs.has_method("get_value"):
		return false
	if not bool(prefs.call("is_registered", PREF_ON)):
		return false
	return bool(prefs.call("get_value", PREF_ON))


func switched_on() -> bool:
	var prefs: Node = get_node_or_null("/root/Prefs")
	if prefs == null or not prefs.has_method("get_value") or not bool(prefs.call("is_registered", PREF_ON)):
		return false
	return bool(prefs.call("get_value", PREF_ON))


func gap_for(keycode: int) -> int:
	var prefs: Node = get_node_or_null("/root/Prefs")
	if prefs == null or not prefs.has_method("get_value"):
		return 0
	var key: String = PREF_SPACE_MS if keycode == KEY_SPACE else PREF_MS
	if not bool(prefs.call("is_registered", key)):
		return 0
	return clampi(int(prefs.call("get_value", key)), MS_MIN, MS_MAX)


static func should_block(gap_ms: int, since_ms: int, echo: bool, held: bool) -> bool:
	if gap_ms <= 0 or echo or held:
		return false
	return since_ms >= 0 and since_ms < gap_ms


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	var code: int = k.keycode if k.keycode != 0 else k.physical_keycode
	if code == 0:
		return
	var now: int = Time.get_ticks_msec()
	if not k.pressed:
		_held.erase(code)
		return
	if k.echo:
		_held[code] = now
		return
	if not on():
		_last_down[code] = now
		return
	var was: int = int(_last_down.get(code, -1))
	var since: int = now - was if was >= 0 else -1
	var holding: bool = _held.has(code) and now - int(_held[code]) < HELD_GRACE_MS
	if should_block(gap_for(code), since, k.echo, holding):
		blocked += 1
		last_blocked_key = code
		last_blocked_ms = since
		get_viewport().set_input_as_handled()
		return
	_last_down[code] = now


func forget() -> void:
	_last_down.clear()
	_held.clear()


static func reset_count() -> void:
	blocked = 0
	last_blocked_key = 0
	last_blocked_ms = 0


static func report() -> String:
	if blocked <= 0:
		return "No double presses have been thrown away yet"
	var key: String = OS.get_keycode_string(last_blocked_key)
	return "Thrown away %d double press%s, the last was %s %d ms after itself" % [blocked, "" if blocked == 1 else "es", key if not key.is_empty() else "a key", last_blocked_ms]


static func say() -> void:
	var loop: MainLoop = Engine.get_main_loop()
	var events: Node = (loop as SceneTree).root.get_node_or_null("/root/Events") if loop is SceneTree else null
	if events != null and events.has_method("toast"):
		events.call("toast", report())

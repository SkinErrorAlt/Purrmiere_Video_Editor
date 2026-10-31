extends RefCounted

const PREF := "playback.scrub_memory_mb"
const DEFAULT_MB := 768
const MIN_MB := 128
const MAX_MB := 8192
const LABEL := "Scrub and reverse memory (MB, shared by every file)"

static var _cb: Callable = Callable()


static func register() -> void:
	var prefs: Node = _root_node("Prefs")
	if prefs == null:
		return
	if not bool(prefs.call("is_registered", PREF)):
		prefs.call("register", PREF, DEFAULT_MB, {"label": LABEL, "type": "int", "min": MIN_MB, "max": MAX_MB})
	if not _cb.is_valid():
		_cb = func(key: String) -> void:
			if key == PREF:
				apply()
	var sig: Signal = prefs.get("changed")
	if not sig.is_connected(_cb):
		sig.connect(_cb)
	apply()


static func megabytes() -> int:
	var prefs: Node = _root_node("Prefs")
	if prefs == null or not bool(prefs.call("is_registered", PREF)):
		return DEFAULT_MB
	return clampi(int(prefs.call("get_value", PREF)), MIN_MB, MAX_MB)


static func apply() -> void:
	var bridge: Node = _root_node("PurrBridge")
	if bridge != null and bridge.has_method("set_scrub_memory"):
		bridge.call("set_scrub_memory", megabytes())


static func _root_node(node_name: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(node_name)
	return null


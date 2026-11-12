extends RefCounted

const PREF := "audio.scrub"
const WINDOW_PREF := "audio.scrub_window"
const COMMAND_ID := "play.scrub_audio"
const LABEL := "Audio while scrubbing"
const ANNOUNCE_SECONDS := 1.6


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Prefs")
	return null


static func register(prefs: Node) -> void:
	if prefs == null or not prefs.has_method("is_registered"):
		return
	if not bool(prefs.call("is_registered", PREF)):
		prefs.call("register", PREF, true, {"label": "Play audio while scrubbing", "type": "bool"})
	if not bool(prefs.call("is_registered", WINDOW_PREF)):
		prefs.call("register", WINDOW_PREF, 0.08, {"label": "Scrub audio window (seconds)", "type": "float", "min": 0.02, "max": 0.4})


static func is_on() -> bool:
	var prefs: Node = _prefs()
	if prefs == null or not prefs.has_method("is_registered"):
		return true
	register(prefs)
	return bool(prefs.call("get_value", PREF))


static func set_on(on: bool) -> void:
	var prefs: Node = _prefs()
	if prefs == null:
		return
	register(prefs)
	prefs.call("set_value", PREF, on)


static func toggle() -> void:
	set_on(not is_on())
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		var notice: GDScript = load("res://ui/kit/pm_notice.gd")
		if notice != null:
			notice.call("post", (loop as SceneTree).root, {"text": LABEL + (" on" if is_on() else " off"), "detail": "Dragging the playhead plays a little of the sound under it." if is_on() else "Dragging the playhead is silent now.", "actions": [], "seconds": ANNOUNCE_SECONDS})

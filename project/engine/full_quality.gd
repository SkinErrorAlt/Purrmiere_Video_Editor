extends RefCounted

const PREF := "playback.full_quality"
const COMMAND_ID := "play.full_quality"
const ICON := "full_quality"
const LABEL := "Full quality"
const TIP := "Full quality playback: plays the originals at full size with every frame decoded fully, as export draws it. A frame that is not ready in time is dropped, the sound keeps going."
const ANNOUNCE_SECONDS := 1.6
const TAG_TIP := "Full quality playback is on: no proxies, no lower quality, nothing cut short while playing. Frames that are not ready in time are dropped."

static var _plant_keep_proxies: bool = false


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Prefs")
	return null


static func register(prefs: Node) -> void:
	if prefs == null or not prefs.has_method("is_registered"):
		return
	if not bool(prefs.call("is_registered", PREF)):
		prefs.call("register", PREF, false, {"label": "Full quality playback: originals at full size, no shortcuts while playing", "type": "bool"})


static func on_for(prefs: Node) -> bool:
	if prefs == null or not prefs.has_method("is_registered") or not bool(prefs.call("is_registered", PREF)):
		return false
	return bool(prefs.call("get_value", PREF))


static func is_on() -> bool:
	return on_for(_prefs())


static func set_on(on: bool) -> void:
	var prefs: Node = _prefs()
	if prefs == null:
		return
	register(prefs)
	prefs.call("set_value", PREF, on)


static func toggle() -> void:
	set_on(not is_on())


static func quality_for(asked: int) -> int:
	return 0 if is_on() else clampi(asked, 0, 3)


static func proxies_allowed(prefs: Node) -> bool:
	return _plant_keep_proxies or not on_for(prefs)


static func announce(node: Node) -> void:
	var notice: GDScript = load("res://ui/kit/pm_notice.gd")
	notice.call("post", node, {"text": LABEL + (" on" if is_on() else " off"), "detail": TAG_TIP if is_on() else "Playback may lower the picture again to keep up.", "actions": [], "seconds": ANNOUNCE_SECONDS})

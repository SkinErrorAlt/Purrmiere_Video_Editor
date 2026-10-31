extends RefCounted

const Bus := preload("res://modules/core_panels/panel_bus.gd")
const SOURCE := "source"
const NEIGHBOURS: PackedStringArray = ["effect_controls", "audio_editor", "keyframes", "effects", "presets", "metadata"]
const AVOID: PackedStringArray = ["bin", "timeline", "program"]


static func dock_for(from: Node) -> Node:
	var n: Node = from
	while n != null:
		if n.has_method("show_panel") and n.has_method("group_of"):
			return n
		n = n.get_parent()
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var editor: Node = (loop as SceneTree).root.find_child("EditorScreen", true, false)
	if editor != null and editor.get("dock") is Node:
		return editor.get("dock")
	return null


static func show_source(from: Node) -> bool:
	var dock: Node = dock_for(from)
	if dock == null:
		return false
	if not bool(dock.call("is_docked", SOURCE)) and not bool(dock.call("is_floating", SOURCE)):
		var home: String = home_tab(dock)
		if not home.is_empty():
			dock.call("focus_panel", home)
	dock.call("show_panel", SOURCE)
	return true


static func home_tab(dock: Node) -> String:
	var groups: Array = dock.call("groups")
	for want: String in NEIGHBOURS:
		for g: Variant in groups:
			if ((g as Dictionary).get("tabs", []) as Array).has(want):
				return String((g as Dictionary).get("active", want))
	for g2: Variant in groups:
		var tabs: Array = (g2 as Dictionary).get("tabs", [])
		var clear: bool = not tabs.is_empty()
		for a: String in AVOID:
			if tabs.has(a):
				clear = false
		if clear:
			return String((g2 as Dictionary).get("active", ""))
	return ""


static func open(from: Node, media_id: String, in_t: float = -1.0, out_t: float = -1.0, at: float = -1.0) -> bool:
	if media_id.is_empty():
		return false
	var shown: bool = show_source(from)
	var bus: RefCounted = Bus.instance()
	var src: Object = bus.call("panel", SOURCE)
	if at >= 0.0 and src != null and src.has_method("show_frame"):
		src.call("show_frame", media_id, at, in_t, out_t)
	else:
		bus.call("request_source", media_id, in_t, out_t)
	_catch_up.call_deferred(media_id, in_t, out_t, at)
	return shown


static func _catch_up(media_id: String, in_t: float, out_t: float, at: float) -> void:
	var bus: RefCounted = Bus.instance()
	var src: Object = bus.call("panel", SOURCE)
	if src == null or String(src.get("media_id")) == media_id:
		return
	if at >= 0.0 and src.has_method("show_frame"):
		src.call("show_frame", media_id, at, in_t, out_t)
	else:
		bus.call("request_source", media_id, in_t, out_t)

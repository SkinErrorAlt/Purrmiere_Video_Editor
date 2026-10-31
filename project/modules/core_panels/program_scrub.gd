extends RefCounted

const ScrubRoute := preload("res://engine/scrub_route.gd")

var render: Callable = Callable()
var rerenders: int = 0
var releases: int = 0
var _dirty: bool = false


static func _root_node(node_name: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(node_name)
	return null


func attach() -> void:
	var bridge: Node = _root_node("PurrBridge")
	if bridge != null and bridge.has_signal("frame_ready") and not bridge.is_connected("frame_ready", _on_frame_ready):
		bridge.connect("frame_ready", _on_frame_ready)
	var s: Node = _root_node("Session")
	if s != null and s.has_signal("scrub_ended") and not s.is_connected("scrub_ended", _on_scrub_ended):
		s.connect("scrub_ended", _on_scrub_ended)


func detach() -> void:
	var bridge: Node = _root_node("PurrBridge")
	if bridge != null and bridge.is_connected("frame_ready", _on_frame_ready):
		bridge.disconnect("frame_ready", _on_frame_ready)
	var s: Node = _root_node("Session")
	if s != null and s.has_signal("scrub_ended") and s.is_connected("scrub_ended", _on_scrub_ended):
		s.disconnect("scrub_ended", _on_scrub_ended)


func _on_frame_ready(_h: int) -> void:
	_dirty = true


func _on_scrub_ended(_t: float) -> void:
	if not ScrubRoute.enabled or not render.is_valid():
		return
	_dirty = false
	releases += 1
	render.call(true)


func tick() -> void:
	if not _dirty:
		return
	_dirty = false
	if not ScrubRoute.enabled or not render.is_valid():
		return
	var s: Node = _root_node("Session")
	if s == null or bool(s.get("playing")):
		return
	var comp: Variant = s.get("compositor")
	if comp == null or not is_instance_valid(comp) or not (comp as Node).has_method("frame_state"):
		return
	if (comp as Node).has_method("unsettled"):
		return
	var st: Dictionary = (comp as Node).call("frame_state")
	if int(st.get("pending", 0)) == 0 and int(st.get("approx_layers", 0)) == 0:
		return
	rerenders += 1
	render.call(bool((comp as Node).get("last_exact")))

extends RefCounted

const HINT_SCRUB := 0
const HINT_PLAY := 1
const HINT_STEP := 2
const PACE_MS := 1500
const KEEP_SHARP_SECONDS := 2.0
const REST_MS := 150

static var enabled: bool = true
static var _plant_keep_decoded: bool = false

var handle: int = -1
var known: bool = false
var paced: bool = true
var want: float = -1.0
var want_quality: int = 0
var in_flight: float = -1.0
var sent_quality: int = 0
var rest_sent: bool = false
var sent_ms: int = 0
var landed: bool = true
var sent: int = 0
var held: int = 0


static func _root_node(node_name: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(node_name)
	return null


static func wants(hint: int) -> bool:
	return enabled and hint == HINT_SCRUB


static func live() -> bool:
	var s: Node = _root_node("Session")
	return s != null and s.has_method("scrub_live") and bool(s.call("scrub_live"))


static func keeps(p: Dictionary, hint: int, has_picture: bool, shown_rgb: bool, shown_pts: float, seconds: float, engine_scrubs: bool = false) -> bool:
	if not enabled or not has_picture or shown_rgb or hint == HINT_PLAY:
		return false
	var st: String = String(p.get("state", "none"))
	if st == "exact" or st == "none" or st == "static":
		return false
	var rgb: bool = bool(p.get("rgb", false))
	if live():
		if not rgb:
			return false
		return engine_scrubs or absf(shown_pts - seconds) <= KEEP_SHARP_SECONDS
	return rgb or _plant_keep_decoded


func _bind(bridge: Node, h: int) -> void:
	if h != handle:
		handle = h
		known = false
		in_flight = -1.0
		landed = true
	if not known:
		var info: Dictionary = bridge.call("media_info", h)
		if bool(info.get("ok", false)):
			known = true
			paced = not bool(info.get("scrub_near", false))


func request(bridge: Node, h: int, seconds: float, quality: int) -> void:
	_bind(bridge, h)
	want = seconds
	want_quality = quality
	if not paced:
		if in_flight >= 0.0 and absf(seconds - in_flight) <= 0.0000005 and quality == sent_quality:
			if rest_sent or Time.get_ticks_msec() - sent_ms < REST_MS:
				return
			rest_sent = true
		else:
			rest_sent = false
		_send(bridge, h, seconds, quality)
		return
	if in_flight >= 0.0 and not landed and Time.get_ticks_msec() - sent_ms < PACE_MS:
		if absf(seconds - in_flight) > 0.0000005:
			held += 1
		return
	if landed and absf(seconds - in_flight) <= 0.0000005 and quality == want_quality and in_flight >= 0.0:
		return
	_send(bridge, h, seconds, quality)


func _send(bridge: Node, h: int, seconds: float, quality: int) -> void:
	bridge.call("request_frame", h, seconds, quality, HINT_SCRUB)
	in_flight = seconds
	sent_quality = quality
	sent_ms = Time.get_ticks_msec()
	landed = false
	sent += 1


func after_present(bridge: Node, p: Dictionary, seconds: float, fps: float) -> Dictionary:
	var st: String = String(p.get("state", "none"))
	if paced and not landed and (st == "exact" or st == "near"):
		landed = true
		if absf(want - in_flight) > 0.0000005:
			_send(bridge, handle, want, want_quality)
	if st != "exact":
		return p
	var step: float = 1.0 / maxf(fps, 1.0)
	var ahead: float = seconds - float(p.get("pts", seconds))
	if ahead >= -0.001 and ahead < step - 0.0005:
		return p
	var out: Dictionary = p.duplicate()
	out["state"] = "near"
	return out

extends RefCounted

const AudioReact := preload("res://engine/audio_react.gd")
const ReactFeed := preload("res://engine/react_feed.gd")
const ID_SOURCE := "source_monitor"
const NEST_PREFIX := "nest:"
const BUS_PATH := "res://modules/core_panels/panel_bus.gd"


static func _source_panel() -> Object:
	var bus: GDScript = load(BUS_PATH)
	if bus == null:
		return null
	var b: Object = bus.call("instance")
	return b.call("panel", "source") if b != null else null


static func source_choice(d: Object) -> Dictionary:
	var sp: Object = _source_panel()
	if sp == null or d == null or not sp.has_method("drag_payload"):
		return {}
	var mid: String = String(sp.get("media_id"))
	if mid.is_empty():
		return {}
	var m: Object = d.call("media_by_id", mid)
	if m == null or String(m.get("kind")) == "sequence" or not (bool(m.get("has_audio")) or String(m.get("kind")) == "audio"):
		return {}
	var payload: Dictionary = sp.call("drag_payload", "audio")
	var a: float = float(payload.get("in", 0.0))
	var b: float = float(payload.get("out", -1.0))
	var label: String = "Source monitor: " + String(m.get("label"))
	if b > a:
		label += " (" + AudioReact._clock(a) + " to " + AudioReact._clock(b) + ")"
	return {"payload": payload, "label": label}


static func nest_choices(panel: Object) -> Array:
	var out: Array = []
	var s: Object = panel.call("seq")
	var d: Object = panel.call("doc")
	var own: Object = panel.call("target_clip")
	if s == null or d == null:
		return out
	var t: float = float(panel.call("playhead"))
	var seen: Dictionary = {}
	var tracks: Array = []
	tracks.append_array(s.get("audio_tracks"))
	tracks.append_array(s.get("video_tracks"))
	for tr: Variant in tracks:
		var track: Object = tr
		var c: Object = track.call("clip_at", t)
		if c == null or c == own or ReactFeed.nest_sid(d, c).is_empty():
			continue
		var sid: String = ReactFeed.nest_sid(d, c)
		var key: String = sid + "|" + String(c.get("link_id")) if not String(c.get("link_id")).is_empty() else String(c.get("id"))
		if seen.has(key):
			continue
		seen[key] = true
		var name: String = String(c.get("label")) if not String(c.get("label")).is_empty() else "nested sequence"
		out.append({"id": NEST_PREFIX + String(c.get("id")), "label": String(track.call("shown_label")) + ": " + name + " (nested sequence)"})
	return out


static func items(panel: Object, make_item: Callable) -> Array:
	var out: Array = []
	for n: Variant in nest_choices(panel):
		out.append(make_item.call(String((n as Dictionary)["id"]), String((n as Dictionary)["label"])))
	var src: Dictionary = source_choice(panel.call("doc"))
	if not src.is_empty():
		out.append(make_item.call(ID_SOURCE, String(src["label"])))
	return out


static func text_for(id: String, panel: Object) -> String:
	if id.begins_with(NEST_PREFIX):
		return AudioReact.encode({"kind": AudioReact.KIND_NEST, "clip": id.substr(NEST_PREFIX.length())})
	if id == ID_SOURCE:
		var d: Object = panel.call("doc")
		var src: Dictionary = source_choice(d)
		if src.is_empty():
			return ""
		return AudioReact.source_from_payload(d, src["payload"])
	return ""

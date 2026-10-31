extends RefCounted

const SELF := preload("res://doc/marker.gd")
const KINDS: PackedStringArray = ["comment", "chapter", "segment", "web", "todo", "warning", "tag"]
const KIND_LABELS: PackedStringArray = ["Comment", "Chapter", "Segment", "Web", "To do", "Warning", "Tag"]
const DEFAULT_KIND := "comment"

var id: String = ""
var time: float = 0.0
var duration: float = 0.0
var label: String = ""
var colour: int = -1
var comment: String = ""
var kind: String = DEFAULT_KIND
var anchor: String = ""
var anchor_clip: String = ""
var anchor_offset: float = 0.0
var layer: String = ""
var rgb: String = ""


func end() -> float:
	return time + duration


func follows() -> bool:
	return not anchor.is_empty()


func has_free_colour() -> bool:
	return not rgb.is_empty()


func free_colour() -> Color:
	return Color.from_string(rgb, Color.WHITE)


static func clean_rgb(v: Variant) -> String:
	var text: String = str(v).strip_edges()
	if text.is_empty():
		return ""
	if not text.begins_with("#"):
		text = "#" + text
	if not Color.html_is_valid(text):
		return ""
	return "#" + Color.html(text).to_html(false)


static func kind_index(k: String) -> int:
	var i: int = KINDS.find(k)
	return i if i >= 0 else 0


static func kind_at(i: int) -> String:
	return KINDS[clampi(i, 0, KINDS.size() - 1)]


static func kind_label(k: String) -> String:
	return KIND_LABELS[kind_index(k)]


static func kind_choices() -> Array:
	var out: Array = []
	for name: String in KIND_LABELS:
		out.append(name)
	return out


func to_dict() -> Dictionary:
	var d: Dictionary = {"id": id, "time": time}
	if duration != 0.0:
		d["duration"] = duration
	if not label.is_empty():
		d["label"] = label
	if colour != -1:
		d["colour"] = colour
	if not comment.is_empty():
		d["comment"] = comment
	if kind != DEFAULT_KIND:
		d["kind"] = kind
	if not anchor.is_empty():
		d["anchor"] = anchor
	if not anchor_clip.is_empty():
		d["anchor_clip"] = anchor_clip
	if anchor_offset != 0.0:
		d["anchor_offset"] = anchor_offset
	if not layer.is_empty():
		d["layer"] = layer
	if not rgb.is_empty():
		d["rgb"] = rgb
	return d


static func from_dict(d: Dictionary) -> SELF:
	var m: SELF = SELF.new()
	m.apply_dict(d)
	return m


func apply_dict(d: Dictionary) -> void:
	id = str(d.get("id", ""))
	time = float(d.get("time", 0.0))
	duration = float(d.get("duration", 0.0))
	label = str(d.get("label", ""))
	colour = int(d.get("colour", -1))
	comment = str(d.get("comment", ""))
	kind = str(d.get("kind", DEFAULT_KIND))
	anchor = str(d.get("anchor", ""))
	anchor_clip = str(d.get("anchor_clip", ""))
	anchor_offset = float(d.get("anchor_offset", 0.0))
	layer = str(d.get("layer", ""))
	rgb = clean_rgb(d.get("rgb", ""))

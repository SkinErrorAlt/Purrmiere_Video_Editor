extends RefCounted

const SELF := preload("res://doc/media_item.gd")
const Marker := preload("res://doc/marker.gd")
const KINDS := ["video", "audio", "image", "sequence", "title", "shape", "adjust", "generator"]
const PLACEHOLDER_DURATION := 5.0
const OBJECT_PROP := "object_of"

var id: String = ""
var path: String = ""
var label: String = ""
var kind: String = "video"
var bin: String = ""
var colour: int = -1
var probed: bool = false
var duration: float = 0.0
var fps: float = 0.0
var width: int = 0
var height: int = 0
var has_audio: bool = false
var audio_streams: Array[Dictionary] = []
var audio_only: bool = false
var poster_time: float = 0.0
var notes: String = ""
var recorded_at: float = -1.0
var tags: PackedStringArray = PackedStringArray()
var tags_off: PackedStringArray = PackedStringArray()
var regions: Array[Dictionary] = []
var missing: bool = false
var sequence_id: String = ""
var props: Dictionary = {}
var markers: Array[Marker] = []
var handle: int = -1


func is_timed() -> bool:
	return kind == "video" or kind == "audio" or kind == "sequence"


func is_object_source() -> bool:
	return props.get(OBJECT_PROP) is Dictionary


func object_of() -> Dictionary:
	var v: Variant = props.get(OBJECT_PROP, null)
	return v if v is Dictionary else {}


func has_picture() -> bool:
	return kind != "audio" and not audio_only


func selected_streams() -> Array[int]:
	var out: Array[int] = []
	var off: Variant = props.get("streams_off", [])
	var skip: Array = off if off is Array else []
	for i: int in audio_streams.size():
		if bool(audio_streams[i].get("selected", true)) and not skip.has(i) and not skip.has(float(i)):
			out.append(i)
	if out.is_empty() and has_audio and audio_streams.is_empty():
		out.append(0)
	return out


func to_dict() -> Dictionary:
	var d: Dictionary = {"id": id, "kind": kind, "label": label}
	if not path.is_empty():
		d["path"] = path
	if not bin.is_empty():
		d["bin"] = bin
	if colour != -1:
		d["colour"] = colour
	if probed:
		d["probed"] = true
	if duration != 0.0:
		d["duration"] = duration
	if fps != 0.0:
		d["fps"] = fps
	if width != 0:
		d["width"] = width
	if height != 0:
		d["height"] = height
	if has_audio:
		d["has_audio"] = true
	if not audio_streams.is_empty():
		d["audio_streams"] = audio_streams.duplicate(true)
	if audio_only:
		d["audio_only"] = true
	if poster_time != 0.0:
		d["poster_time"] = poster_time
	if not notes.is_empty():
		d["notes"] = notes
	if recorded_at >= 0.0:
		d["recorded_at"] = recorded_at
	if not tags.is_empty():
		d["tags"] = Array(tags)
	if not tags_off.is_empty():
		d["tags_off"] = Array(tags_off)
	if not regions.is_empty():
		d["regions"] = regions.duplicate(true)
	if not sequence_id.is_empty():
		d["sequence_id"] = sequence_id
	if not props.is_empty():
		d["props"] = props.duplicate(true)
	if not markers.is_empty():
		var ms: Array = []
		for m: Marker in markers:
			ms.append(m.to_dict())
		d["markers"] = ms
	return d


static func from_dict(d: Dictionary) -> SELF:
	var m: SELF = SELF.new()
	m.apply_dict(d)
	return m


func apply_dict(d: Dictionary) -> void:
	id = str(d.get("id", ""))
	path = str(d.get("path", ""))
	label = str(d.get("label", ""))
	kind = str(d.get("kind", "video"))
	bin = str(d.get("bin", ""))
	colour = int(d.get("colour", -1))
	probed = bool(d.get("probed", false))
	duration = float(d.get("duration", 0.0))
	fps = float(d.get("fps", 0.0))
	width = int(d.get("width", 0))
	height = int(d.get("height", 0))
	has_audio = bool(d.get("has_audio", false))
	audio_streams = []
	for s: Variant in d.get("audio_streams", []):
		if s is Dictionary:
			var sd: Dictionary = (s as Dictionary).duplicate(true)
			sd["index"] = int(sd.get("index", audio_streams.size()))
			sd["channels"] = int(sd.get("channels", 2))
			sd["sample_rate"] = int(sd.get("sample_rate", 48000))
			sd["selected"] = bool(sd.get("selected", true))
			audio_streams.append(sd)
	audio_only = bool(d.get("audio_only", false))
	poster_time = float(d.get("poster_time", 0.0))
	notes = str(d.get("notes", ""))
	recorded_at = float(d.get("recorded_at", -1.0))
	tags = _strings(d.get("tags", []))
	tags_off = _strings(d.get("tags_off", []))
	regions = []
	for r: Variant in d.get("regions", []):
		if r is Dictionary:
			regions.append((r as Dictionary).duplicate(true))
	sequence_id = str(d.get("sequence_id", ""))
	props = (d["props"] as Dictionary).duplicate(true) if d.get("props") is Dictionary else {}
	markers = []
	for mk: Variant in d.get("markers", []):
		if mk is Dictionary:
			markers.append(Marker.from_dict(mk))
	markers.sort_custom(func(a: Marker, b: Marker) -> bool: return a.time < b.time)
	missing = false
	handle = -1


static func _strings(v: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if v is Array or v is PackedStringArray:
		for e: Variant in v:
			var t: String = str(e).strip_edges()
			if not t.is_empty() and not out.has(t):
				out.append(t)
	return out

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Marker := preload("res://doc/marker.gd")
const MediaItem := preload("res://doc/media_item.gd")

var label: String = ""
var ok: bool = true
var seq_id: String = ""


func do(_doc: Project) -> void:
	pass


func undo(_doc: Project) -> void:
	pass


func live_key() -> String:
	return label + "|" + seq_id


func seq(doc: Project) -> Sequence:
	return doc.sequence_by_id(seq_id)


func clip(doc: Project, clip_id: String) -> Clip:
	var s: Sequence = seq(doc)
	if s == null:
		return null
	return s.clip_by_id(clip_id)


func track(doc: Project, track_id: String) -> Track:
	var s: Sequence = seq(doc)
	if s == null:
		return null
	return s.track_by_id(track_id)


static func dup(v: Variant) -> Variant:
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	if v is Array:
		return (v as Array).duplicate(true)
	return v

extends RefCounted

signal source_requested(media_id: String, in_t: float, out_t: float)
signal focus_changed(panel_id: String)
signal arm_changed(clip_id: String, path: String, armed: bool)
signal property_picked(clip_id: String, path: String)
signal shot_settled

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")

static var _instance: RefCounted = null

var focused_panel: String = ""
var armed: Dictionary = {}
var clipboard: Dictionary = {}
var key_clipboard: Array = []
var source_media_id: String = ""
var source_in: float = -1.0
var source_out: float = -1.0
var recent_sources: PackedStringArray = PackedStringArray()
var panels: Dictionary = {}


static func has_doc_static() -> bool:
	return Session.doc != null


static func instance() -> RefCounted:
	if _instance == null:
		var script: GDScript = load("res://modules/core_panels/panel_bus.gd")
		_instance = script.new()
	return _instance


func panel(id: String) -> Object:
	var p: Variant = panels.get(id, null)
	if p == null or not is_instance_valid(p):
		return null
	if p is Object:
		return p
	return null


func set_focused(id: String) -> void:
	if focused_panel == id:
		return
	focused_panel = id
	focus_changed.emit(id)


func arm_key(clip_id: String, path: String) -> String:
	return clip_id + "|" + path


func is_armed(clip_id: String, path: String) -> bool:
	return bool(armed.get(arm_key(clip_id, path), false))


func set_armed(clip_id: String, path: String, on: bool) -> void:
	var k: String = arm_key(clip_id, path)
	if on:
		armed[k] = true
	else:
		armed.erase(k)
	arm_changed.emit(clip_id, path, on)


func key_time_for(c: Clip, path: String, playhead: float) -> float:
	if c == null:
		return -1.0
	var p: Dictionary = c.get_param(path)
	if AnimProp.is_animated(p) or is_armed(c.id, path):
		return playhead
	return -1.0


func request_source(media_id: String, in_t: float = -1.0, out_t: float = -1.0) -> void:
	source_media_id = media_id
	source_in = in_t
	source_out = out_t
	if not media_id.is_empty():
		var i: int = recent_sources.find(media_id)
		if i >= 0:
			recent_sources.remove_at(i)
		recent_sources.insert(0, media_id)
		while recent_sources.size() > 12:
			recent_sources.remove_at(recent_sources.size() - 1)
	source_requested.emit(media_id, in_t, out_t)


static func selected_clip(seq: Sequence) -> Clip:
	if seq == null:
		return null
	for id: String in seq.selected_clip_ids:
		var c: Clip = seq.clip_by_id(id)
		if c != null:
			return c
	return null


static func selected_video_clip(seq: Sequence) -> Clip:
	if seq == null:
		return null
	for id: String in seq.selected_clip_ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			continue
		var t: Variant = seq.track_of(id)
		if t != null and t.is_picture(c):
			return c
	return selected_clip(seq)

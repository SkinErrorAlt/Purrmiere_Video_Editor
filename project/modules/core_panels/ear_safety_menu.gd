extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const EAR_PATH := "res://engine/ear_safety.gd"
const MENU_TRACK := "ear_track"
const MENU_CLIP := "ear_clip"


static func _ear() -> GDScript:
	return load(EAR_PATH)


static func clip_menu_items(c: Clip) -> Array:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null or s == null or c == null:
		return []
	var tr: Track = s.track_of(c.id)
	if tr == null or not tr.is_sound(c):
		return []
	var ear: GDScript = _ear()
	var sc: String = String(ear.call("scope"))
	if sc == String(ear.get_script_constant_map()["SCOPE_TRACKS"]):
		return [PmMenu.check_item(MENU_TRACK, "Ear safety: protect this track", bool(ear.call("is_marked", d, "tracks", tr.id)))]
	if sc == String(ear.get_script_constant_map()["SCOPE_CLIPS"]):
		return [PmMenu.check_item(MENU_CLIP, "Ear safety: protect this clip", bool(ear.call("is_marked", d, "clips", c.id)))]
	return []


static func on_clip_menu(id: String, clip_id: String) -> bool:
	if id != MENU_TRACK and id != MENU_CLIP:
		return false
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null:
		return true
	var ear: GDScript = _ear()
	if id == MENU_TRACK:
		var tr: Track = s.track_of(c.id)
		if tr != null:
			ear.call("set_marked", d, "tracks", tr.id, not bool(ear.call("is_marked", d, "tracks", tr.id)))
	else:
		ear.call("set_marked", d, "clips", c.id, not bool(ear.call("is_marked", d, "clips", c.id)))
	return true

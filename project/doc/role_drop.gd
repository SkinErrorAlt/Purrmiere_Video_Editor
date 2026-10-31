extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const StreamRoles := preload("res://doc/stream_roles.gd")
const StreamOrdinals := preload("res://doc/stream_ordinals.gd")
const Presets := preload("res://doc/presets.gd")
const Io := preload("res://doc/io.gd")
const DRAG_KIND := "role_preset"
const ENTRY_KIND := "role_preset"
const ENTRY_PREFIX := "roles:"
const ENTRY_ICON := "combo"
const META_PREFIX := "track names · "
const ONLY_PREFIX := "On "
const ONLY_SUFFIX := " only"
const WHOLE_HINT := "Alt: whole video"
const BIN_WHOLE_HINT := "Alt: every file here"
const EMPTY_PRESET := "That set of track names is empty"
const NO_TARGET := "Drop a set of track names on a file in the bin or on a sound clip"
const NO_SOUND := "This clip has no sound, so there are no audio tracks to name"
const NO_STREAMS_TAIL := " has no sound streams to name"
const NONE_HERE := "No file here has sound streams to name"
const GONE := "That clip's file is not in the project any more"
const UNREADABLE := "That set of track names could not be read"
const ALREADY := "Those names are already set"
const NO_NAME_HEAD := " has no name for stream "


static func whole_held() -> bool:
	return Input.is_key_pressed(KEY_ALT)


static func is_entry(entry_id: String) -> bool:
	return entry_id.begins_with(ENTRY_PREFIX)


static func entry_id_for(preset_id: String) -> String:
	return ENTRY_PREFIX + preset_id


static func preset_id_of(entry_id: String) -> String:
	return entry_id.substr(ENTRY_PREFIX.length()) if is_entry(entry_id) else ""


static func label_of(preset: Dictionary) -> String:
	var text: String = String(preset.get("label", "")).strip_edges()
	return text if not text.is_empty() else "Unnamed names"


static func summary_of(preset: Dictionary) -> String:
	return StreamRoles.preset_summary(preset)


static func meta_of(preset: Dictionary) -> String:
	var text: String = summary_of(preset)
	return META_PREFIX + (text if not text.is_empty() else "nothing named yet")


static func step_label(preset: Dictionary) -> String:
	return "Apply " + label_of(preset)


static func listed(doc: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for p: Dictionary in Presets.list_user(StreamRoles.KIND):
		seen[String(p.get("id", ""))] = true
		out.append(p)
	if doc != null:
		for p: Dictionary in Presets.list_project(doc, StreamRoles.KIND):
			if not seen.has(String(p.get("id", ""))):
				out.append(p)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return label_of(a).naturalnocasecmp_to(label_of(b)) < 0)
	return out


static func by_id(doc: Project, preset_id: String) -> Dictionary:
	if preset_id.is_empty():
		return {}
	for p: Dictionary in listed(doc):
		if String(p.get("id", "")) == preset_id:
			return p
	return {}


static func in_project(doc: Project, preset_id: String) -> bool:
	return doc != null and not Presets.find_project(doc, preset_id).is_empty()


static func forget(doc: Project, preset_id: String) -> bool:
	if preset_id.is_empty():
		return false
	if in_project(doc, preset_id):
		return Presets.remove_from_project(doc, preset_id)
	return Io.delete_user_preset(StreamRoles.KIND, preset_id)


static func in_user(preset_id: String) -> Dictionary:
	for p: Dictionary in Presets.list_user(StreamRoles.KIND):
		if String(p.get("id", "")) == preset_id:
			return p
	return {}


static func rename(doc: Project, preset_id: String, text: String) -> bool:
	var clean: String = text.strip_edges()
	var p: Dictionary = by_id(doc, preset_id)
	if clean.is_empty() or p.is_empty() or label_of(p) == clean:
		return false
	var done: bool = false
	if in_project(doc, preset_id):
		var held: Dictionary = Presets.find_project(doc, preset_id)
		held["label"] = clean
		done = Presets.replace_in_project(doc, held, "Rename track names")
	var mine: Dictionary = in_user(preset_id)
	if not mine.is_empty():
		mine["label"] = clean
		done = Presets.save_to_user(mine) or done
	return done


static func result(ok: bool, changed: bool, why: String, note: String) -> Dictionary:
	return {"ok": ok, "changed": changed, "why": why, "note": note}


static func plan(ok: bool, why: String, wanted: Dictionary) -> Dictionary:
	return {"ok": ok, "why": why, "wanted": wanted}


static func clip_stream(c: Clip) -> int:
	if c == null or c.audio.is_empty():
		return -1
	return int(c.audio.get("stream", 0.0))


static func makes_sound(seq: Sequence, c: Clip) -> bool:
	if c == null or c.audio.is_empty():
		return false
	var t: Track = seq.track_of(c.id) if seq != null else null
	if t != null:
		return t.is_sound(c)
	return c.part == "audio"


static func media_plan(doc: Project, media_ids: PackedStringArray, preset: Dictionary) -> Dictionary:
	var names: Dictionary = StreamRoles.names_from_preset(preset)
	if names.is_empty():
		return plan(false, EMPTY_PRESET, {})
	var wanted: Dictionary = {}
	var first: String = ""
	for mid: String in media_ids:
		var m: MediaItem = doc.media_by_id(mid) if doc != null else null
		if m == null:
			continue
		if first.is_empty():
			first = m.label
		if StreamRoles.count(m) <= 0:
			continue
		wanted[mid] = names
	if wanted.is_empty():
		if media_ids.size() == 1:
			return plan(false, (first if not first.is_empty() else "That file") + NO_STREAMS_TAIL, {})
		return plan(false, NONE_HERE, {})
	return plan(true, "", wanted)


static func clip_plan(doc: Project, seq: Sequence, clip_id: String, preset: Dictionary, whole: bool) -> Dictionary:
	var names: Dictionary = StreamRoles.names_from_preset(preset)
	if names.is_empty():
		return plan(false, EMPTY_PRESET, {})
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if c == null:
		return plan(false, NO_TARGET, {})
	var m: MediaItem = doc.media_by_id(c.media_id) if doc != null else null
	if m == null:
		return plan(false, GONE, {})
	if not makes_sound(seq, c) or StreamRoles.count(m) <= 0:
		return plan(false, NO_SOUND, {})
	if whole:
		return plan(true, "", {m.id: names})
	var ordinal: int = clip_stream(c)
	var one: String = String(names.get(str(ordinal), "")).strip_edges()
	if one.is_empty():
		return plan(false, label_of(preset) + NO_NAME_HEAD + str(ordinal + 1), {})
	var merged: Dictionary = StreamOrdinals.names_of(m)
	merged[str(ordinal)] = one
	return plan(true, "", merged_for(m.id, merged))


static func merged_for(media_id: String, names: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	out[media_id] = names
	return out


static func note_for(doc: Project, wanted: Dictionary, preset: Dictionary) -> String:
	if wanted.size() == 1:
		var m: MediaItem = doc.media_by_id(String(wanted.keys()[0])) if doc != null else null
		return label_of(preset) + " named the tracks on " + (m.label if m != null else "that file")
	return label_of(preset) + " named the tracks on " + str(wanted.size()) + " files"


static func run(doc: Project, made: Dictionary, preset: Dictionary) -> Dictionary:
	if not bool(made.get("ok", false)):
		return result(false, false, String(made.get("why", NO_TARGET)), "")
	var wanted: Dictionary = made.get("wanted", {})
	if not StreamRoles.set_names_each(doc, wanted, step_label(preset)):
		return result(true, false, "", ALREADY)
	return result(true, true, "", note_for(doc, wanted, preset))


static func drop_on_media(doc: Project, media_ids: PackedStringArray, preset: Dictionary) -> Dictionary:
	return run(doc, media_plan(doc, media_ids, preset), preset)


static func drop_on_clip(doc: Project, seq: Sequence, clip_id: String, preset: Dictionary, whole: bool) -> Dictionary:
	return run(doc, clip_plan(doc, seq, clip_id, preset, whole), preset)


static func clips_of_media(seq: Sequence, media_id: String, sound_only: bool) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null or media_id.is_empty():
		return out
	for c: Clip in seq.all_clips():
		if c.media_id != media_id:
			continue
		if sound_only and not makes_sound(seq, c):
			continue
		out.append(c.id)
	return out


static func clip_hint(doc: Project, seq: Sequence, clip_id: String, preset: Dictionary, whole: bool) -> Dictionary:
	var made: Dictionary = clip_plan(doc, seq, clip_id, preset, whole)
	if not bool(made["ok"]):
		return {"text": String(made["why"]), "hint": ""}
	var c: Clip = seq.clip_by_id(clip_id)
	var m: MediaItem = doc.media_by_id(c.media_id)
	if whole:
		return {"text": "Every track of " + (m.label if m != null else "this video"), "hint": ""}
	return {"text": ONLY_PREFIX + StreamRoles.name_of(m, clip_stream(c)) + ONLY_SUFFIX, "hint": WHOLE_HINT}


static func media_hint(doc: Project, media_ids: PackedStringArray, preset: Dictionary, whole: bool) -> Dictionary:
	var made: Dictionary = media_plan(doc, media_ids, preset)
	if not bool(made["ok"]):
		return {"text": String(made["why"]), "hint": ""}
	var wanted: Dictionary = made["wanted"]
	if whole:
		return {"text": "Every file here (" + str(wanted.size()) + ")", "hint": ""}
	var m: MediaItem = doc.media_by_id(media_ids[0])
	return {"text": ONLY_PREFIX + (m.label if m != null else "this file") + ONLY_SUFFIX, "hint": BIN_WHOLE_HINT}

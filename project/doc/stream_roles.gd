extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const StreamOrdinals := preload("res://doc/stream_ordinals.gd")
const Command := preload("res://doc/commands/command.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const KIND := "stream_roles"
const USUAL: PackedStringArray = ["Mic", "Game", "Discord"]


static func count(item: MediaItem) -> int:
	if item == null:
		return 0
	if not item.audio_streams.is_empty():
		return item.audio_streams.size()
	return 1 if item.has_audio or item.kind == "audio" else 0


static func usual_name(ordinal: int) -> String:
	if ordinal >= 0 and ordinal < USUAL.size():
		return USUAL[ordinal]
	return ""


static func file_title(item: MediaItem, ordinal: int) -> String:
	if item == null or ordinal < 0 or ordinal >= item.audio_streams.size():
		return ""
	return String(item.audio_streams[ordinal].get("title", "")).strip_edges()


static func given(item: MediaItem, ordinal: int) -> String:
	return StreamOrdinals.given(item, ordinal)


static func name_of(item: MediaItem, ordinal: int) -> String:
	var mine: String = StreamOrdinals.given(item, ordinal)
	if not mine.is_empty():
		return mine
	var title: String = file_title(item, ordinal)
	return title if not title.is_empty() else "Stream " + str(ordinal + 1)


static func menu_label(item: MediaItem, ordinal: int) -> String:
	var mine: String = StreamOrdinals.given(item, ordinal)
	if mine.is_empty():
		mine = file_title(item, ordinal)
	if mine.is_empty():
		return "Stream " + str(ordinal + 1)
	return mine + " (" + str(ordinal + 1) + ")"


static func shared_menu_label(items: Array, ordinal: int) -> String:
	var agreed: String = ""
	for v: Variant in items:
		if not (v is MediaItem):
			continue
		var one: String = menu_label(v as MediaItem, ordinal)
		if agreed.is_empty():
			agreed = one
		elif agreed != one:
			return "Stream " + str(ordinal + 1)
	return agreed if not agreed.is_empty() else "Stream " + str(ordinal + 1)


static func names_of(item: MediaItem) -> Dictionary:
	return StreamOrdinals.names_of(item)


static func any_named(item: MediaItem) -> bool:
	return not StreamOrdinals.names_of(item).is_empty()


static func ordered(names: Dictionary) -> PackedStringArray:
	var clean: Dictionary = StreamOrdinals.clean_names(names, 0)
	var keys: Array[int] = []
	for k: Variant in clean.keys():
		keys.append(int(String(k)))
	keys.sort()
	var out: PackedStringArray = PackedStringArray()
	for o: int in keys:
		out.append(String(clean[str(o)]))
	return out


static func summary(item: MediaItem) -> String:
	var n: int = count(item)
	if n <= 0 or not any_named(item):
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for o: int in n:
		parts.append(name_of(item, o))
	return ", ".join(parts)


static func suggest(item: MediaItem) -> Dictionary:
	var out: Dictionary = {}
	for o: int in count(item):
		var mine: String = StreamOrdinals.given(item, o)
		if mine.is_empty():
			mine = usual_name(o)
		if not mine.is_empty():
			out[str(o)] = mine
	return out


static func commands_for(doc: Project, media_ids: PackedStringArray, names: Dictionary) -> Array[Command]:
	var cmds: Array[Command] = []
	if doc == null:
		return cmds
	var done: Dictionary = {}
	for mid: String in media_ids:
		if done.has(mid):
			continue
		done[mid] = true
		var m: MediaItem = doc.media_by_id(mid)
		if m == null:
			continue
		var want: Dictionary = StreamOrdinals.clean_names(names, count(m))
		if StreamOrdinals.names_of(m) == want:
			continue
		cmds.append(MediaCmds.SetMediaField.new(mid, "props", StreamOrdinals.props_with_names(m, want, count(m))))
	return cmds


static func commands_for_each(doc: Project, wanted: Dictionary) -> Array[Command]:
	var cmds: Array[Command] = []
	if doc == null:
		return cmds
	for key: Variant in wanted.keys():
		var mid: String = String(key)
		var m: MediaItem = doc.media_by_id(mid)
		if m == null or not (wanted[key] is Dictionary):
			continue
		var want: Dictionary = StreamOrdinals.clean_names(wanted[key], count(m))
		if StreamOrdinals.names_of(m) == want:
			continue
		cmds.append(MediaCmds.SetMediaField.new(mid, "props", StreamOrdinals.props_with_names(m, want, count(m))))
	return cmds


static func set_names_each(doc: Project, wanted: Dictionary, label: String = "") -> bool:
	var cmds: Array[Command] = commands_for_each(doc, wanted)
	if cmds.is_empty():
		return false
	return Verbs.run(doc, label if not label.is_empty() else "Name audio tracks", cmds)


static func set_names(doc: Project, media_ids: PackedStringArray, names: Dictionary, label: String = "") -> bool:
	var cmds: Array[Command] = commands_for(doc, media_ids, names)
	if cmds.is_empty():
		return false
	return Verbs.run(doc, label if not label.is_empty() else "Name audio tracks", cmds)


static func to_payload(names: Dictionary) -> Dictionary:
	return {"names": StreamOrdinals.clean_names(names, 0)}


static func names_from_preset(preset: Dictionary) -> Dictionary:
	var payload: Variant = preset.get("payload", {})
	if not (payload is Dictionary):
		return {}
	var names: Variant = (payload as Dictionary).get("names", {})
	if not (names is Dictionary):
		return {}
	return StreamOrdinals.clean_names(names as Dictionary, 0)


static func preset_summary(preset: Dictionary) -> String:
	return ", ".join(ordered(names_from_preset(preset)))


static func apply_preset(doc: Project, preset: Dictionary, media_ids: PackedStringArray) -> bool:
	var names: Dictionary = names_from_preset(preset)
	if names.is_empty():
		return false
	var label: String = String(preset.get("label", "")).strip_edges()
	return set_names(doc, media_ids, names, "Apply " + (label if not label.is_empty() else "audio track names"))


static func clip_role(item: MediaItem, c: Clip) -> String:
	if item == null or c == null:
		return ""
	return StreamOrdinals.given(item, int(c.audio.get("stream", 0.0)))


static func shown_label(item: MediaItem, c: Clip, is_sound: bool) -> String:
	var base: String = ""
	if c != null and not c.label.is_empty():
		base = c.label
	elif item != null:
		base = item.label
	if not is_sound or c == null:
		return base
	var role: String = clip_role(item, c)
	if role.is_empty() or base == role:
		return base
	if item != null and not item.label.is_empty() and base.begins_with(item.label):
		return item.label + " " + role
	return base

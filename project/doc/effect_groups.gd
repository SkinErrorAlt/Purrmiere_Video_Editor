extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const LABEL_KEY := "group_label"
const GROUP_KEY := "group"


static func group_of(e: Dictionary) -> String:
	return String(e.get(GROUP_KEY, ""))


static func label_of(e: Dictionary) -> String:
	var l: String = String(e.get(LABEL_KEY, ""))
	return l if not l.is_empty() else "Effect group"


static func tag(entries: Array, gid: String, label: String) -> void:
	for e: Variant in entries:
		if e is Dictionary:
			(e as Dictionary)[GROUP_KEY] = gid
			(e as Dictionary)[LABEL_KEY] = label


static func run_at(entries: Array, index: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if index < 0 or index >= entries.size():
		return out
	var gid: String = group_of(entries[index])
	if gid.is_empty():
		return out
	var start: int = index
	while start > 0 and group_of(entries[start - 1]) == gid:
		start -= 1
	var i: int = start
	while i < entries.size() and group_of(entries[i]) == gid:
		out.append(i)
		i += 1
	return out


static func starts_run(entries: Array, index: int) -> bool:
	if index < 0 or index >= entries.size():
		return false
	var gid: String = group_of(entries[index])
	if gid.is_empty():
		return false
	if index > 0 and group_of(entries[index - 1]) == gid:
		return false
	return run_at(entries, index).size() >= 2


static func in_shown_group(entries: Array, index: int) -> bool:
	return run_at(entries, index).size() >= 2


static func members(c: Clip, gid: String, sound: bool) -> PackedStringArray:
	var out := PackedStringArray()
	if c == null or gid.is_empty():
		return out
	for e: Variant in (c.audio_effects() if sound else c.effects):
		if e is Dictionary and group_of(e) == gid:
			out.append(String((e as Dictionary).get("uid", "")))
	return out


static func all_on(c: Clip, gid: String, sound: bool) -> bool:
	for uid: String in members(c, gid, sound):
		var e: Dictionary = c.audio_effect_by_uid(uid) if sound else c.effect_by_uid(uid)
		if not bool(e.get("enabled", true)):
			return false
	return true


static func set_on(d: Project, s: Sequence, clip_id: String, gid: String, sound: bool, on: bool) -> bool:
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null:
		return false
	var cmds: Array[Command] = []
	for uid: String in members(c, gid, sound):
		cmds.append(EffectCmds.SetEffectEnabled.new(s.id, clip_id, uid, on, sound))
	if cmds.is_empty():
		return false
	return Verbs.run(d, "Turn the group on" if on else "Turn the group off", cmds)


static func toggle(d: Project, s: Sequence, clip_id: String, gid: String, sound: bool) -> bool:
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c == null:
		return false
	return set_on(d, s, clip_id, gid, sound, not all_on(c, gid, sound))


static func remove(d: Project, s: Sequence, clip_id: String, gid: String, sound: bool) -> bool:
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null:
		return false
	var cmds: Array[Command] = []
	for uid: String in members(c, gid, sound):
		cmds.append(EffectCmds.RemoveEffect.new(s.id, clip_id, uid, sound))
	if cmds.is_empty():
		return false
	return Verbs.run(d, "Remove the effect group", cmds)


static func ungroup(d: Project, s: Sequence, clip_id: String, gid: String, sound: bool) -> bool:
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null:
		return false
	var cmds: Array[Command] = []
	for uid: String in members(c, gid, sound):
		cmds.append(EffectCmds.SetEffectEntry.new(s.id, clip_id, uid, {GROUP_KEY: "", LABEL_KEY: null}, sound, "Ungroup"))
	if cmds.is_empty():
		return false
	return Verbs.run(d, "Ungroup the effects", cmds)


static func rename(d: Project, s: Sequence, clip_id: String, gid: String, sound: bool, label: String) -> bool:
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null or label.strip_edges().is_empty():
		return false
	var cmds: Array[Command] = []
	for uid: String in members(c, gid, sound):
		cmds.append(EffectCmds.SetEffectEntry.new(s.id, clip_id, uid, {LABEL_KEY: label.strip_edges()}, sound, "Rename the group"))
	if cmds.is_empty():
		return false
	return Verbs.run(d, "Rename the effect group", cmds)


static func make_group(d: Project, s: Sequence, clip_id: String, uids: PackedStringArray, sound: bool, label: String) -> String:
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null or uids.size() < 2:
		return ""
	var gid: String = d.mint_id("g")
	var order: Array[String] = []
	for e: Variant in (c.audio_effects() if sound else c.effects):
		if e is Dictionary and uids.has(String((e as Dictionary).get("uid", ""))):
			order.append(String((e as Dictionary).get("uid", "")))
	var cmds: Array[Command] = []
	if order.size() >= 2:
		var anchor: int = -1
		var list: Array = c.audio_effects() if sound else c.effects
		for i: int in list.size():
			if String((list[i] as Dictionary).get("uid", "")) == order[0]:
				anchor = i
				break
		var want: int = anchor
		for uid: String in order:
			cmds.append(EffectCmds.SetEffectEntry.new(s.id, clip_id, uid, {GROUP_KEY: gid, LABEL_KEY: label}, sound, "Group"))
		for k: int in range(1, order.size()):
			want += 1
			cmds.append(EffectCmds.ReorderEffect.new(s.id, clip_id, order[k], want, sound))
	if cmds.is_empty() or not Verbs.run(d, "Group the effects", cmds):
		return ""
	return gid

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const TextFx := preload("res://doc/text_fx/text_fx.gd")
const ValueClipboard := preload("res://modules/core_panels/value_clipboard.gd")
const ClipWarnings := preload("res://doc/clip_warnings.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PASTE_CHOICES: Array = [["motion", "Motion", true], ["opacity", "Opacity and blend", true], ["effects", "Effects", true], ["masks", "Masks", false], ["audio_volume", "Volume and pan", true], ["audio_effects", "Sound effects", true], ["speed", "Speed", false]]
const MOVE_KIND := "effect_reorder"
const NO_TARGET := "Drop the effect on a clip in the timeline or on a file in the bin"
const GONE := "That effect is not on its clip any more"
const SOURCE_LOCKED := "That effect's own clip is locked, so it cannot be moved off it"
const NO_SOUND_HERE := "Sound effects go on clips that have sound"
const NO_PICTURE_HERE := "Picture effects go on clips that have a picture"
const SAME_CLIP := "That effect is already on this clip"
const NO_CLIPS_OF_FILE := "No clip in this sequence uses that file"

static var clipboard: Dictionary = {}


static func copy_effect(c: Clip, uid: String) -> bool:
	if c == null:
		return false
	var sound: bool = c.is_audio_effect(uid)
	var e: Dictionary = c.audio_effect_by_uid(uid) if sound else c.effect_by_uid(uid)
	if e.is_empty():
		return false
	var def: Dictionary = EffectSource.get_def(String(e.get("id", "")))
	clipboard = {"entry": e.duplicate(true), "audio": sound, "label": String(def.get("label", e.get("id", "effect")))}
	return true


static func has_copied() -> bool:
	return not clipboard.is_empty()


static func copied_label() -> String:
	return String(clipboard.get("label", ""))


static func paste_effect(doc: Project, seq: Sequence, clip_ids: PackedStringArray) -> int:
	if doc == null or seq == null or clipboard.is_empty():
		return 0
	var sound: bool = bool(clipboard.get("audio", false))
	var targets: PackedStringArray = Verbs.audio_targets(seq, clip_ids) if sound else Verbs.video_targets(seq, clip_ids)
	if TextFx.text_only(EffectSource.get_def(String((clipboard["entry"] as Dictionary).get("id", "")))):
		targets = Verbs.title_targets(doc, seq, targets)
	var cmds: Array[Command] = []
	for id: String in targets:
		cmds.append(EffectCmds.InsertEffectEntry.new(seq.id, id, clipboard["entry"], doc.mint_id("e"), -1, sound))
	if cmds.is_empty():
		return 0
	if not Verbs.run(doc, "Paste " + copied_label(), cmds):
		return 0
	EffectSource.note_used(String((clipboard["entry"] as Dictionary).get("id", "")))
	return cmds.size()


static func duplicate_effect(doc: Project, seq: Sequence, clip_id: String, uid: String) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if doc == null or c == null:
		return false
	var sound: bool = c.is_audio_effect(uid)
	var e: Dictionary = c.audio_effect_by_uid(uid) if sound else c.effect_by_uid(uid)
	if e.is_empty():
		return false
	var at: int = -1
	var list: Array = c.audio_effects() if sound else c.effects
	for i: int in list.size():
		if String((list[i] as Dictionary).get("uid", "")) == uid:
			at = i
	var cmd: Command = EffectCmds.InsertEffectEntry.new(seq.id, clip_id, e, doc.mint_id("e"), at + 1, sound)
	cmd.label = "Duplicate effect"
	return Verbs.run(doc, cmd.label, [cmd])


static func stack_of(c: Clip, sound: bool) -> Array:
	if c == null:
		return []
	return c.audio_effects() if sound else c.effects


static func stack_index(c: Clip, uid: String, sound: bool) -> int:
	if c == null or uid.is_empty():
		return -1
	if not sound:
		return c.effect_index(uid)
	var list: Array = c.audio_effects()
	for i: int in list.size():
		if String((list[i] as Dictionary).get("uid", "")) == uid:
			return i
	return -1


static func same_stack(c: Clip, uid: String, other_uid: String) -> bool:
	if c == null or uid.is_empty() or other_uid.is_empty():
		return false
	var sound: bool = c.is_audio_effect(uid)
	if sound != c.is_audio_effect(other_uid):
		return false
	return stack_index(c, uid, sound) >= 0 and stack_index(c, other_uid, sound) >= 0


static func gap_for(at: int, local_y: float, height: float) -> int:
	if at < 0:
		return -1
	return at + 1 if local_y > height * 0.5 else at


static func drop_index(from: int, gap: int, count: int) -> int:
	if from < 0 or from >= count or count < 2 or gap < 0:
		return -1
	var want: int = clampi(gap, 0, count)
	if want == from or want == from + 1:
		return -1
	return want - 1 if want > from else want


static func move_effect(doc: Project, seq: Sequence, clip_id: String, uid: String, gap: int, sound: bool) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if doc == null or c == null:
		return false
	var from: int = stack_index(c, uid, sound)
	var to: int = drop_index(from, gap, stack_of(c, sound).size())
	if to < 0:
		return false
	return Verbs.run(doc, "Move effect", [EffectCmds.ReorderEffect.new(seq.id, clip_id, uid, to, sound)])


static func step_effect(doc: Project, seq: Sequence, clip_id: String, uid: String, delta: int) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if doc == null or c == null:
		return false
	var sound: bool = c.is_audio_effect(uid)
	var at: int = stack_index(c, uid, sound)
	var to: int = at + delta
	if at < 0 or to < 0 or to >= stack_of(c, sound).size():
		return false
	return Verbs.run(doc, "Move effect " + ("up" if delta < 0 else "down"), [EffectCmds.ReorderEffect.new(seq.id, clip_id, uid, to, sound)])


static func reset_effect(doc: Project, seq: Sequence, clip_id: String, uid: String) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if doc == null or c == null:
		return false
	var sound: bool = c.is_audio_effect(uid)
	var e: Dictionary = c.audio_effect_by_uid(uid) if sound else c.effect_by_uid(uid)
	var def: Dictionary = EffectSource.get_def(String(e.get("id", "")))
	if e.is_empty() or def.is_empty():
		return false
	var fresh: Dictionary = EffectCmds.EffectCommand.entry_from_def(Verbs.effect_def_for_clip(doc, seq, c, def), uid)
	var fields: Dictionary = {"params": fresh["params"]}
	if not sound:
		fields["mix"] = AnimProp.make(1.0)
	if e.has(Clip.AnimTime.SPEEDS_FIELD):
		fields[Clip.AnimTime.SPEEDS_FIELD] = null
	var same: bool = true
	for k: Variant in fields.keys():
		if e.get(k) != fields[k]:
			same = false
	if same:
		return false
	return Verbs.run(doc, "Reset effect", [EffectCmds.SetEffectEntry.new(seq.id, clip_id, uid, fields, sound, "Reset effect")])


static func _targets(seq: Sequence, clip_ids: PackedStringArray) -> Array[Clip]:
	var out: Array[Clip] = []
	for id: String in clip_ids:
		var c: Clip = seq.clip_by_id(id)
		var t: Track = seq.track_of(id)
		if c != null and t != null and not t.locked:
			out.append(c)
	return out


static func effect_count(seq: Sequence, clip_ids: PackedStringArray) -> int:
	var n: int = 0
	if seq == null:
		return 0
	for c: Clip in _targets(seq, clip_ids):
		n += c.effects.size() + c.audio_effects().size()
	return n


static func remove_all(doc: Project, seq: Sequence, clip_ids: PackedStringArray) -> bool:
	if doc == null or seq == null:
		return false
	var cmds: Array[Command] = []
	for c: Clip in _targets(seq, clip_ids):
		for e: Dictionary in c.effects:
			cmds.append(EffectCmds.RemoveEffect.new(seq.id, c.id, String(e.get("uid", "")), false))
		for ae: Variant in c.audio_effects():
			cmds.append(EffectCmds.RemoveEffect.new(seq.id, c.id, String((ae as Dictionary).get("uid", "")), true))
	return Verbs.run(doc, "Remove all effects", cmds)


static func any_on(seq: Sequence, clip_ids: PackedStringArray) -> bool:
	if seq == null:
		return false
	for c: Clip in _targets(seq, clip_ids):
		for e: Dictionary in c.effects:
			if bool(e.get("enabled", true)):
				return true
		for ae: Variant in c.audio_effects():
			if bool((ae as Dictionary).get("enabled", true)):
				return true
	return false


static func toggle_all(doc: Project, seq: Sequence, clip_ids: PackedStringArray) -> bool:
	if doc == null or seq == null:
		return false
	var want: bool = not any_on(seq, clip_ids)
	var cmds: Array[Command] = []
	for c: Clip in _targets(seq, clip_ids):
		for e: Dictionary in c.effects:
			if bool(e.get("enabled", true)) != want:
				cmds.append(EffectCmds.SetEffectEnabled.new(seq.id, c.id, String(e.get("uid", "")), want, false))
		for ae: Variant in c.audio_effects():
			if bool((ae as Dictionary).get("enabled", true)) != want:
				cmds.append(EffectCmds.SetEffectEnabled.new(seq.id, c.id, String((ae as Dictionary).get("uid", "")), want, true))
	return Verbs.run(doc, "Turn all effects on" if want else "Turn all effects off", cmds)


static func sources_of(cb: Dictionary) -> Dictionary:
	var picture: Dictionary = {}
	var sound: Dictionary = {}
	for r: Variant in cb.get("clips", []):
		var rd: Dictionary = r
		var kind: String = String(rd.get("kind", ""))
		if kind == "video" and picture.is_empty():
			picture = rd.get("clip", {})
		elif kind == "audio" and sound.is_empty():
			sound = rd.get("clip", {})
	var named: Dictionary = picture if not picture.is_empty() else sound
	var label: String = String(named.get("label", ""))
	if label.is_empty():
		label = String(named.get("id", "the copied clip"))
	return {"picture": picture, "sound": sound, "label": label}


static func paste_attributes(doc: Project, seq: Sequence, cb: Dictionary, which: PackedStringArray, keep_keys: bool, scale_times: bool) -> bool:
	if doc == null or seq == null or which.is_empty():
		return false
	var src: Dictionary = sources_of(cb)
	if (src["picture"] as Dictionary).is_empty() and (src["sound"] as Dictionary).is_empty():
		return false
	var ids: PackedStringArray = Verbs.unlocked(seq, Verbs.selection(seq))
	if ids.is_empty():
		return false
	var cmd: Command = EffectCmds.PasteChosen.new(seq.id, ids, src["picture"], src["sound"], which, keep_keys, scale_times)
	return Verbs.run(doc, cmd.label, [cmd])


static func paste_fields(cb: Dictionary, target_count: int) -> Array[Dictionary]:
	var saved: Dictionary = EffectSource.paste_choice()
	var fields: Array[Dictionary] = []
	for spec: Array in PASTE_CHOICES:
		fields.append({"key": String(spec[0]), "label": String(spec[1]), "type": "bool", "default": bool(saved.get(String(spec[0]), spec[2]))})
	fields.append({"key": "keys", "label": "Keyframes", "type": "bool", "default": bool(saved.get("keys", true))})
	fields.append({"key": "scale", "label": "Scale key times to the clip length", "type": "bool", "default": bool(saved.get("scale", false))})
	var src: Dictionary = sources_of(cb)
	var note: String = "From " + String(src["label"]) + " onto " + str(target_count) + (" selected clip." if target_count == 1 else " selected clips.")
	note += " Picture choices go to video clips and sound choices to audio clips. With Keyframes off, each value is pasted as it is at the start of the copied clip."
	fields.append({"key": "note", "label": "", "type": "note", "default": note})
	return fields


static func open_paste_sheet(host: Node, doc: Project, seq: Sequence, cb: Dictionary) -> bool:
	if host == null or doc == null or seq == null:
		return false
	if cb.get("clips", []).is_empty():
		Events.toast("Copy a clip first, then paste its attributes")
		return false
	var ids: PackedStringArray = Verbs.unlocked(seq, Verbs.selection(seq))
	if ids.is_empty():
		Events.toast("Select the clips to paste onto")
		return false
	var answered: Signal = PmUI.form(host, "Paste attributes", paste_fields(cb, ids.size()), "Paste", "Cancel")
	answered.connect(_on_paste_answered.bind(doc, seq, cb.duplicate(true)))
	return true


static func answer_to_choice(r: Dictionary) -> Dictionary:
	var choice: Dictionary = {}
	for spec: Array in PASTE_CHOICES:
		choice[String(spec[0])] = bool(r.get(String(spec[0]), false))
	choice["keys"] = bool(r.get("keys", true))
	choice["scale"] = bool(r.get("scale", false))
	return choice


static func which_of(choice: Dictionary) -> PackedStringArray:
	var which: PackedStringArray = PackedStringArray()
	for spec: Array in PASTE_CHOICES:
		if bool(choice.get(String(spec[0]), false)):
			which.append(String(spec[0]))
	return which


static func _on_paste_answered(result: Variant, doc: Project, seq: Sequence, cb: Dictionary) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var choice: Dictionary = answer_to_choice(result)
	EffectSource.set_paste_choice(choice)
	var which: PackedStringArray = which_of(choice)
	if which.is_empty():
		Events.toast("Nothing was ticked, so nothing was pasted")
		return
	if not paste_attributes(doc, seq, cb, which, bool(choice["keys"]), bool(choice["scale"])):
		Events.toast("Nothing to paste onto the selected clips")


static func result(ok: bool, changed: bool, why: String, note: String, count: int = 0) -> Dictionary:
	return {"ok": ok, "changed": changed, "why": why, "note": note, "count": count}


static func entry_of(c: Clip, uid: String) -> Dictionary:
	if c == null or uid.is_empty():
		return {}
	return c.audio_effect_by_uid(uid) if c.is_audio_effect(uid) else c.effect_by_uid(uid)


static func effect_label(c: Clip, uid: String) -> String:
	var e: Dictionary = entry_of(c, uid)
	if e.is_empty():
		return "effect"
	var eid: String = String(e.get("id", ""))
	return String(EffectSource.get_def(eid).get("label", eid))


static func clip_label(doc: Project, seq: Sequence, clip_id: String) -> String:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if c == null:
		return "that clip"
	return ClipWarnings.clip_name(doc, c)


static func clips_of_media(seq: Sequence, media_id: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null or media_id.is_empty():
		return out
	for c: Clip in seq.all_clips():
		if c.media_id == media_id and not out.has(c.id):
			out.append(c.id)
	return out


static func move_targets(seq: Sequence, from_clip_id: String, uid: String, ids: PackedStringArray, copy: bool) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var src: Clip = seq.clip_by_id(from_clip_id) if seq != null else null
	if src == null or entry_of(src, uid).is_empty():
		return out
	var sound: bool = src.is_audio_effect(uid)
	var reach: PackedStringArray = Verbs.audio_targets(seq, ids) if sound else Verbs.video_targets(seq, ids)
	if TextFx.text_only(EffectSource.get_def(String(entry_of(src, uid).get("id", "")))):
		reach = Verbs.title_targets(Session.doc, seq, reach)
	for id: String in reach:
		if id == from_clip_id and not copy:
			continue
		if not out.has(id):
			out.append(id)
	return out


static func move_refusal(seq: Sequence, from_clip_id: String, uid: String, ids: PackedStringArray, copy: bool) -> String:
	var src: Clip = seq.clip_by_id(from_clip_id) if seq != null else null
	if src == null or entry_of(src, uid).is_empty():
		return GONE
	if ids.is_empty():
		return NO_TARGET
	if move_targets(seq, from_clip_id, uid, ids, copy).is_empty():
		if ids.size() == 1 and ids[0] == from_clip_id:
			return SAME_CLIP
		if TextFx.text_only(EffectSource.get_def(String(entry_of(src, uid).get("id", "")))):
			return TextFx.REFUSAL
		return NO_SOUND_HERE if src.is_audio_effect(uid) else NO_PICTURE_HERE
	if not copy and Verbs.unlocked(seq, PackedStringArray([from_clip_id])).is_empty():
		return SOURCE_LOCKED
	return ""


static func move_to(doc: Project, seq: Sequence, from_clip_id: String, uid: String, ids: PackedStringArray, copy: bool) -> Dictionary:
	if doc == null or seq == null:
		return result(false, false, GONE, "")
	var why: String = move_refusal(seq, from_clip_id, uid, ids, copy)
	if not why.is_empty():
		return result(false, false, why, "")
	var src: Clip = seq.clip_by_id(from_clip_id)
	var sound: bool = src.is_audio_effect(uid)
	var e: Dictionary = entry_of(src, uid)
	var targets: PackedStringArray = move_targets(seq, from_clip_id, uid, ids, copy)
	var cmds: Array[Command] = []
	for id: String in targets:
		cmds.append(EffectCmds.InsertEffectEntry.new(seq.id, id, e, doc.mint_id("e"), -1, sound))
	if not copy:
		cmds.append(EffectCmds.RemoveEffect.new(seq.id, from_clip_id, uid, sound))
	var name_: String = effect_label(src, uid)
	var label: String = ("Copy " if copy else "Move ") + name_
	if not Verbs.run(doc, label, cmds):
		return result(false, false, GONE, "")
	return result(true, true, "", move_note(doc, seq, name_, targets, copy), targets.size())


static func move_note(doc: Project, seq: Sequence, name_: String, targets: PackedStringArray, copy: bool) -> String:
	var head: String = ("Copied " if copy else "Moved ") + name_ + " to "
	if targets.size() == 1:
		return head + clip_label(doc, seq, targets[0])
	return head + str(targets.size()) + " clips"


static func move_hint(doc: Project, seq: Sequence, from_clip_id: String, uid: String, ids: PackedStringArray, copy: bool, copy_hint: String = "") -> Dictionary:
	var src: Clip = seq.clip_by_id(from_clip_id) if seq != null else null
	var name_: String = effect_label(src, uid) if src != null else "effect"
	var tail: String = "" if copy else copy_hint
	var why: String = move_refusal(seq, from_clip_id, uid, ids, copy)
	if not why.is_empty():
		return {"text": why, "hint": tail}
	var targets: PackedStringArray = move_targets(seq, from_clip_id, uid, ids, copy)
	var head: String = ("Copy " if copy else "Move ") + name_ + " to "
	if targets.size() == 1:
		return {"text": head + clip_label(doc, seq, targets[0]), "hint": tail}
	return {"text": head + str(targets.size()) + " clips", "hint": tail}


static func param_of(def: Dictionary, key: String) -> Dictionary:
	for p: Dictionary in EffectSource.param_specs(def):
		if String(p.get("key", "")) == key:
			return p
	return {}


static func pasted_spec(def: Dictionary, uid: String, key: String, sound: bool) -> Dictionary:
	var prefix: String = "audio_effects." if sound else "effects."
	var eid: String = String(def.get("id", ""))
	if key == "mix" and not sound:
		return {"path": prefix + uid + "." + key, "label": "Amount", "kind": "float", "min": 0.0, "max": 1.0, "key": key, "eid": eid, "keyable": true}
	var p: Dictionary = param_of(def, key)
	if p.is_empty():
		return {}
	var spec: Dictionary = {"path": prefix + uid + "." + key, "label": String(p.get("label", key)), "kind": String(p.get("type", "float")), "key": key, "eid": eid, "keyable": bool(p.get("keyable", true))}
	if p.has("min"):
		spec["min"] = float(p["min"])
	if p.has("max"):
		spec["max"] = float(p["max"])
	return spec


static func add_refusal(seq: Sequence, c: Clip, cb: Dictionary) -> String:
	if cb.is_empty():
		return "Copy a value first, then paste"
	var eid: String = String(cb.get("eid", ""))
	var key: String = String(cb.get("name", ""))
	if eid.is_empty() or key.is_empty():
		return "That value does not belong to an effect, so there is no effect to add"
	var def: Dictionary = EffectSource.get_def(eid)
	if def.is_empty():
		return "The effect that value came from is not installed here"
	if c == null or seq == null:
		return "Select a clip first"
	var t: Track = seq.track_of(c.id)
	if t == null or t.locked:
		return "That clip's track is locked"
	var sound: bool = bool(def.get("audio", false))
	if sound and not t.is_sound(c):
		return NO_SOUND_HERE
	if not sound and not t.is_picture(c):
		return NO_PICTURE_HERE
	var spec: Dictionary = pasted_spec(def, "probe", key, sound)
	if spec.is_empty():
		return String(def.get("label", eid)) + " has no value called " + ValueClipboard.plain_name(cb)
	return ValueClipboard.refusal(cb, spec)


static func add_with_value(doc: Project, seq: Sequence, c: Clip, cb: Dictionary, at: float = -1.0) -> Dictionary:
	var why: String = add_refusal(seq, c, cb)
	if not why.is_empty():
		return {"ok": false, "why": why, "uid": "", "path": "", "label": "", "effect": ""}
	var def: Dictionary = EffectSource.get_def(String(cb.get("eid", "")))
	var sound: bool = bool(def.get("audio", false))
	var key: String = String(cb.get("name", ""))
	var uid: String = doc.mint_id("e")
	var spec: Dictionary = pasted_spec(def, uid, key, sound)
	var entry: Dictionary = EffectCmds.EffectCommand.entry_from_def(Verbs.effect_def_for_clip(doc, seq, c, def), uid)
	var prop: Dictionary = ValueClipboard.prop_for(c, spec, cb, at)
	if key == "mix":
		entry["mix"] = prop
	else:
		if not (entry.get("params") is Dictionary):
			entry["params"] = {}
		(entry["params"] as Dictionary)[key] = prop
	var name_: String = String(def.get("label", def.get("id", "effect")))
	var label: String = "Paste " + ValueClipboard.plain_name(cb) + " and add " + name_
	var cmd: Command = EffectCmds.InsertEffectEntry.new(seq.id, c.id, entry, uid, -1, sound)
	cmd.label = label
	if not Verbs.run(doc, label, [cmd]):
		return {"ok": false, "why": "The effect could not be added to this clip", "uid": "", "path": "", "label": "", "effect": ""}
	EffectSource.note_used(String(def.get("id", "")))
	return {"ok": true, "why": "", "uid": uid, "path": String(spec["path"]), "label": String(spec["label"]), "effect": name_}

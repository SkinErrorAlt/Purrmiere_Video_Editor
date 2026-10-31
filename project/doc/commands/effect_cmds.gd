extends RefCounted

const VERSION := 1
const MIX_KEY := "mix"


class EffectCommand extends "res://doc/commands/command.gd":
	const MIX_KEY := "mix"

	var clip_id: String = ""
	var audio: bool = false

	static func entry_from_def(def: Dictionary, uid: String) -> Dictionary:
		var params: Dictionary = {}
		for p: Variant in def.get("params", []):
			if p is Dictionary:
				var pd: Dictionary = p
				var key: String = str(pd.get("key", ""))
				if key.is_empty():
					continue
				params[key] = AnimProp.make(pd.get("default", 0.0))
		var entry: Dictionary = {"uid": uid, "id": str(def.get("id", "")), "enabled": true, "params": params, "group": "", "mask": ""}
		if not bool(def.get("audio", false)):
			entry[MIX_KEY] = AnimProp.make(1.0)
		return entry

	func list(doc: Project) -> Array:
		var c: Clip = clip(doc, clip_id)
		if c == null:
			return []
		if audio:
			if not (c.audio.get("effects") is Array):
				c.audio["effects"] = []
			return c.audio["effects"]
		return c.effects

	func index_of(doc: Project, uid: String) -> int:
		var l: Array = list(doc)
		for i: int in l.size():
			if str((l[i] as Dictionary).get("uid", "")) == uid:
				return i
		return -1

	func entry(doc: Project, uid: String) -> Dictionary:
		var i: int = index_of(doc, uid)
		if i < 0:
			return {}
		return list(doc)[i]

	static func has_mask(c: Clip, mask_id: String) -> bool:
		for m: Dictionary in c.masks:
			if str(m.get("id", "")) == mask_id:
				return true
		return false


class AddEffect extends EffectCommand:
	var def: Dictionary = {}
	var uid: String = ""
	var index: int = -1

	func _init(p_seq_id: String, p_clip_id: String, p_def: Dictionary, p_uid: String = "", p_index: int = -1, p_audio: bool = false) -> void:
		label = "Add " + str(p_def.get("label", p_def.get("id", "effect")))
		seq_id = p_seq_id
		clip_id = p_clip_id
		def = p_def.duplicate(true)
		uid = p_uid
		index = p_index
		audio = p_audio

	func do(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		if c == null or str(def.get("id", "")).is_empty():
			ok = false
			return
		if uid.is_empty():
			uid = doc.mint_id("e")
		if index_of(doc, uid) >= 0:
			ok = false
			return
		var l: Array = list(doc)
		if index < 0 or index > l.size():
			index = l.size()
		l.insert(index, entry_from_def(def, uid))
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var i: int = index_of(doc, uid)
		if i >= 0:
			list(doc).remove_at(i)
		doc.touch("meta")


class RemoveEffect extends EffectCommand:
	var uid: String = ""
	var old_entry: Dictionary = {}
	var old_index: int = -1

	func _init(p_seq_id: String, p_clip_id: String, p_uid: String, p_audio: bool = false) -> void:
		label = "Remove effect"
		seq_id = p_seq_id
		clip_id = p_clip_id
		uid = p_uid
		audio = p_audio

	func do(doc: Project) -> void:
		old_index = index_of(doc, uid)
		if old_index < 0:
			ok = false
			return
		var l: Array = list(doc)
		old_entry = (l[old_index] as Dictionary).duplicate(true)
		l.remove_at(old_index)
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var l: Array = list(doc)
		l.insert(mini(old_index, l.size()), old_entry.duplicate(true))
		doc.touch("meta")


class ReorderEffect extends EffectCommand:
	var uid: String = ""
	var new_index: int = 0
	var old_index: int = 0

	func _init(p_seq_id: String, p_clip_id: String, p_uid: String, p_new_index: int, p_audio: bool = false) -> void:
		label = "Reorder effect"
		seq_id = p_seq_id
		clip_id = p_clip_id
		uid = p_uid
		new_index = p_new_index
		audio = p_audio

	func _move(doc: Project, to: int) -> void:
		var l: Array = list(doc)
		var i: int = index_of(doc, uid)
		var e: Dictionary = l[i]
		l.remove_at(i)
		l.insert(clampi(to, 0, l.size()), e)
		doc.touch("meta")

	func do(doc: Project) -> void:
		old_index = index_of(doc, uid)
		if old_index < 0:
			ok = false
			return
		_move(doc, new_index)

	func undo(doc: Project) -> void:
		_move(doc, old_index)


class SetEffectEnabled extends EffectCommand:
	var uid: String = ""
	var on: bool = true
	var old: bool = true

	func _init(p_seq_id: String, p_clip_id: String, p_uid: String, p_on: bool, p_audio: bool = false) -> void:
		label = "Enable effect" if p_on else "Disable effect"
		seq_id = p_seq_id
		clip_id = p_clip_id
		uid = p_uid
		on = p_on
		audio = p_audio

	func do(doc: Project) -> void:
		var e: Dictionary = entry(doc, uid)
		if e.is_empty():
			ok = false
			return
		old = bool(e.get("enabled", true))
		e["enabled"] = on
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var e: Dictionary = entry(doc, uid)
		if not e.is_empty():
			e["enabled"] = old
		doc.touch("meta")


class SetEffectParam extends EffectCommand:
	var uid: String = ""
	var key: String = ""
	var value: Variant = null
	var key_at: float = -1.0
	var interp: String = ""
	var old: Dictionary = {}
	var had: bool = false
	var collapse: bool = false

	func _init(p_seq_id: String, p_clip_id: String, p_uid: String, p_key: String, p_value: Variant, p_key_at: float = -1.0, p_audio: bool = false, p_interp: String = "", p_collapse: bool = false) -> void:
		label = "Set " + p_key
		seq_id = p_seq_id
		clip_id = p_clip_id
		uid = p_uid
		key = p_key
		value = AnimProp.norm(p_value)
		key_at = p_key_at
		audio = p_audio
		interp = p_interp
		collapse = p_collapse

	func live_key() -> String:
		return "effect_param|" + clip_id + "|" + uid + "|" + key

	func _params(doc: Project) -> Dictionary:
		var e: Dictionary = entry(doc, uid)
		if e.is_empty():
			return {}
		if key == MIX_KEY:
			return e
		if not (e.get("params") is Dictionary):
			e["params"] = {}
		return e["params"]

	func do(doc: Project) -> void:
		var e: Dictionary = entry(doc, uid)
		if e.is_empty():
			ok = false
			return
		var params: Dictionary = _params(doc)
		had = params.has(key)
		old = (params[key] as Dictionary).duplicate(true) if had and params[key] is Dictionary else {}
		var current: Dictionary = old if not old.is_empty() else AnimProp.make(value)
		if key_at < 0.0:
			params[key] = AnimProp.make(value)
		elif collapse and not old.is_empty():
			var c: Clip = clip(doc, clip_id)
			var s: Sequence = seq(doc)
			params[key] = AnimProp.autokey_next(old, key_at, value, c.duration if c != null else 0.0, s.fps if s != null else 30.0, interp)
		else:
			params[key] = AnimProp.set_key(current, key_at, value, interp)
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var params: Dictionary = _params(doc)
		if had:
			params[key] = old.duplicate(true)
		else:
			params.erase(key)
		doc.touch("meta")


class SetMask extends EffectCommand:
	var uid: String = ""
	var mask: Variant = ""
	var old: Variant = ""

	func _init(p_seq_id: String, p_clip_id: String, p_uid: String, p_mask: Variant) -> void:
		label = "Set mask"
		seq_id = p_seq_id
		clip_id = p_clip_id
		uid = p_uid
		mask = dup(p_mask)

	func do(doc: Project) -> void:
		var e: Dictionary = entry(doc, uid)
		if e.is_empty():
			ok = false
			return
		old = dup(e.get("mask", ""))
		e["mask"] = dup(mask)
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var e: Dictionary = entry(doc, uid)
		if not e.is_empty():
			e["mask"] = dup(old)
		doc.touch("meta")


class SetMaskMode extends EffectCommand:
	var uid: String = ""
	var spill: bool = false
	var had: bool = false
	var old: Variant = ""

	func _init(p_seq_id: String, p_clip_id: String, p_uid: String, p_spill: bool) -> void:
		label = "Spill out" if p_spill else "Keep inside"
		seq_id = p_seq_id
		clip_id = p_clip_id
		uid = p_uid
		spill = p_spill

	func do(doc: Project) -> void:
		var e: Dictionary = entry(doc, uid)
		if e.is_empty():
			ok = false
			return
		had = e.has(Clip.MASK_MODE_KEY)
		old = e.get(Clip.MASK_MODE_KEY, "")
		if spill:
			e[Clip.MASK_MODE_KEY] = Clip.MASK_SPILL
		else:
			e.erase(Clip.MASK_MODE_KEY)
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var e: Dictionary = entry(doc, uid)
		if not e.is_empty():
			if had:
				e[Clip.MASK_MODE_KEY] = old
			else:
				e.erase(Clip.MASK_MODE_KEY)
		doc.touch("meta")


class InsertEffectEntry extends EffectCommand:
	var entry_in: Dictionary = {}
	var uid: String = ""
	var index: int = -1

	func _init(p_seq_id: String, p_clip_id: String, p_entry: Dictionary, p_uid: String, p_index: int = -1, p_audio: bool = false) -> void:
		label = "Paste effect"
		seq_id = p_seq_id
		clip_id = p_clip_id
		entry_in = p_entry.duplicate(true)
		uid = p_uid
		index = p_index
		audio = p_audio

	func do(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		if c == null or str(entry_in.get("id", "")).is_empty() or uid.is_empty() or index_of(doc, uid) >= 0:
			ok = false
			return
		var e: Dictionary = entry_in.duplicate(true)
		e["uid"] = uid
		var mid: String = str(e.get("mask", ""))
		if not mid.is_empty() and not has_mask(c, mid):
			e["mask"] = ""
		var l: Array = list(doc)
		var at: int = index if index >= 0 and index <= l.size() else l.size()
		l.insert(at, e)
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var i: int = index_of(doc, uid)
		if i >= 0:
			list(doc).remove_at(i)
		doc.touch("meta")


class SetEffectEntry extends EffectCommand:
	var uid: String = ""
	var fields: Dictionary = {}
	var old_entry: Dictionary = {}

	func _init(p_seq_id: String, p_clip_id: String, p_uid: String, p_fields: Dictionary, p_audio: bool = false, p_label: String = "Reset effect") -> void:
		label = p_label
		seq_id = p_seq_id
		clip_id = p_clip_id
		uid = p_uid
		fields = p_fields.duplicate(true)
		audio = p_audio

	func do(doc: Project) -> void:
		var i: int = index_of(doc, uid)
		if i < 0:
			ok = false
			return
		var l: Array = list(doc)
		var e: Dictionary = l[i]
		old_entry = e.duplicate(true)
		for k: Variant in fields.keys():
			if fields[k] == null:
				e.erase(k)
			else:
				e[k] = dup(fields[k])
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var i: int = index_of(doc, uid)
		if i >= 0:
			list(doc)[i] = old_entry.duplicate(true)
		doc.touch("meta")


class PasteChosen extends EffectCommand:
	const PICTURE: PackedStringArray = ["motion", "opacity", "effects", "masks"]
	const SOUND: PackedStringArray = ["audio_volume", "audio_effects"]
	const CHOICES: PackedStringArray = ["motion", "opacity", "speed", "effects", "masks", "audio_volume", "audio_effects"]
	const MOTION_KEYS: PackedStringArray = ["pos", "scale", "scale_linked", "rotation", "anchor"]
	const OPACITY_KEYS: PackedStringArray = ["opacity", "blend"]
	const FIELDS: PackedStringArray = ["transform", "motion_blur", "speed", "effects", "masks", "audio", "speeds"]
	const MOTION_SPEEDS: PackedStringArray = ["motion", "transform.pos", "transform.scale", "transform.rotation", "transform.anchor", "motion_blur.shutter_angle", "motion_blur.shutter_phase", "motion_blur.samples"]
	const OPACITY_SPEEDS: PackedStringArray = ["transform.opacity"]
	const SOUND_SPEEDS: PackedStringArray = ["audio", "audio.volume", "audio.pan"]

	var clip_ids: PackedStringArray = PackedStringArray()
	var picture_src: Dictionary = {}
	var sound_src: Dictionary = {}
	var which: PackedStringArray = PackedStringArray()
	var keep_keys: bool = true
	var scale_times: bool = false
	var old: Dictionary = {}
	var _uids: Dictionary = {}

	func _init(p_seq_id: String, p_clip_ids: PackedStringArray, p_picture_src: Dictionary, p_sound_src: Dictionary, p_which: PackedStringArray, p_keep_keys: bool, p_scale_times: bool) -> void:
		label = "Paste attributes"
		seq_id = p_seq_id
		clip_ids = p_clip_ids
		picture_src = p_picture_src.duplicate(true)
		sound_src = p_sound_src.duplicate(true)
		which = p_which
		keep_keys = p_keep_keys
		scale_times = p_scale_times

	func _prop(p: Variant, src: Clip, target: Clip, path: String = "") -> Variant:
		if not (p is Dictionary) or not AnimProp.is_animated(p):
			return dup(p)
		if not keep_keys:
			return AnimProp.make(AnimProp.evaluate(p, 0.0 if is_same(p, src.speed) else (src.anim_time(0.0) if path.is_empty() else src.param_time(path, 0.0)), src.duration))
		if scale_times and src.duration > 0.0 and target.duration > 0.0:
			return AnimProp.scale_times(p, target.duration / src.duration)
		return dup(p)

	func _entries(doc: Project, key: String, src_list: Array, src: Clip, target: Clip) -> Array:
		if not _uids.has(key):
			var minted: Array = []
			for _e: Variant in src_list:
				minted.append(doc.mint_id("e"))
			_uids[key] = minted
		var minted_uids: Array = _uids[key]
		var out: Array = []
		for i: int in src_list.size():
			var e: Dictionary = (src_list[i] as Dictionary).duplicate(true)
			var base: String = ("audio_effects." if key.ends_with("|audio_effects") else "effects.") + String(e.get("uid", "")) + "."
			e["uid"] = minted_uids[i]
			var params: Dictionary = e.get("params", {})
			for pk: Variant in params.keys():
				params[pk] = _prop(params[pk], src, target, base + String(pk))
			if e.has("mix"):
				e["mix"] = _prop(e["mix"], src, target, base + "mix")
			_carry_fx_speeds(e, src, target)
			out.append(e)
		return out

	func _carry_fx_speeds(e: Dictionary, src: Clip, target: Clip) -> void:
		if not e.has(Clip.AnimTime.SPEEDS_FIELD):
			return
		if not keep_keys or not (e[Clip.AnimTime.SPEEDS_FIELD] is Dictionary):
			e.erase(Clip.AnimTime.SPEEDS_FIELD)
			return
		if not scale_times or src.duration <= 0.0 or target.duration <= 0.0:
			return
		var scaled: Dictionary = {}
		var had: Dictionary = e[Clip.AnimTime.SPEEDS_FIELD]
		for sk: Variant in had.keys():
			scaled[sk] = Clip.AnimTime.scaled_entry(had[sk], target.duration / src.duration)
		e[Clip.AnimTime.SPEEDS_FIELD] = scaled

	func _carry_speeds(src: Clip, target: Clip, targets: PackedStringArray) -> void:
		for t: String in targets:
			var en: Dictionary = src.speed_entry(t) if keep_keys else {}
			if not en.is_empty() and scale_times and src.duration > 0.0 and target.duration > 0.0:
				en = Clip.AnimTime.scaled_entry(en, target.duration / src.duration)
			target.put_speed(t, Clip.AnimTime.entry_speed(en).duplicate(true), Clip.AnimTime.entry_start(en))

	func _relink_regions(src: Clip, target: Clip) -> void:
		var minted: Array = _uids.get(target.id + "|effects", [])
		var renamed: Dictionary = {}
		for i: int in mini(src.effects.size(), minted.size()):
			renamed[String(src.effects[i].get("uid", ""))] = String(minted[i])
		for m: Dictionary in target.masks:
			var of: String = String(m.get("region_of", ""))
			if renamed.has(of):
				m["region_of"] = renamed[of]

	func applies(which_one: String, is_audio: bool) -> bool:
		if not which.has(which_one):
			return false
		if PICTURE.has(which_one):
			return not is_audio and not picture_src.is_empty()
		if SOUND.has(which_one):
			return is_audio and not sound_src.is_empty()
		return not picture_src.is_empty() or not sound_src.is_empty()

	func _paste_into(doc: Project, c: Clip, is_audio: bool) -> bool:
		var any: bool = false
		var pic: Clip = Clip.from_dict(picture_src) if not picture_src.is_empty() else null
		var snd: Clip = Clip.from_dict(sound_src) if not sound_src.is_empty() else null
		if applies("motion", is_audio):
			for k: String in MOTION_KEYS:
				if pic.transform.has(k):
					c.transform[k] = _prop(pic.transform[k], pic, c, "transform." + k)
			var mb: Dictionary = {}
			for mk: Variant in pic.motion_blur.keys():
				mb[mk] = _prop(pic.motion_blur[mk], pic, c, "motion_blur." + String(mk))
			c.motion_blur = mb
			_carry_speeds(pic, c, MOTION_SPEEDS)
			any = true
		if applies("opacity", is_audio):
			for k2: String in OPACITY_KEYS:
				if pic.transform.has(k2):
					c.transform[k2] = _prop(pic.transform[k2], pic, c, "transform." + k2)
			_carry_speeds(pic, c, OPACITY_SPEEDS)
			any = true
		if applies("speed", is_audio):
			var from: Clip = snd if is_audio and snd != null else pic
			if from == null:
				from = snd
			c.speed = _prop(from.speed, from, c)
			any = true
		if applies("masks", is_audio):
			var masks: Array[Dictionary] = []
			for m: Dictionary in pic.masks:
				var mm: Dictionary = m.duplicate(true)
				for mk2: Variant in mm.keys():
					mm[mk2] = _prop(mm[mk2], pic, c, "masks." + String(mm.get("id", "")) + "." + String(mk2))
				_carry_fx_speeds(mm, pic, c)
				masks.append(mm)
			c.masks = masks
			any = true
		if applies("effects", is_audio):
			for e: Variant in _entries(doc, c.id + "|effects", pic.effects, pic, c):
				c.effects.append(e)
			_relink_regions(pic, c)
			any = true
		for e2: Dictionary in c.effects:
			var mid: String = str(e2.get("mask", ""))
			if not mid.is_empty() and not has_mask(c, mid):
				e2["mask"] = ""
		if applies("audio_volume", is_audio):
			c.audio["volume"] = _prop(snd.audio.get("volume", AnimProp.make(1.0)), snd, c, "audio.volume")
			if snd.audio.has("pan"):
				c.audio["pan"] = _prop(snd.audio["pan"], snd, c, "audio.pan")
			else:
				c.audio.erase("pan")
			_carry_speeds(snd, c, SOUND_SPEEDS)
			any = true
		if applies("audio_effects", is_audio):
			if not (c.audio.get("effects") is Array):
				c.audio["effects"] = []
			for e3: Variant in _entries(doc, c.id + "|audio_effects", snd.audio_effects(), snd, c):
				(c.audio["effects"] as Array).append(e3)
			any = true
		return any

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null:
			ok = false
			return
		old = {}
		var any: bool = false
		for id: String in clip_ids:
			var c: Clip = s.clip_by_id(id)
			var t: Track = s.track_of(id)
			if c == null or t == null:
				continue
			var saved: Dictionary = {}
			for f: String in FIELDS:
				saved[f] = dup(c.get(f))
			if _paste_into(doc, c, t.is_sound(c)):
				old[id] = saved
				any = true
			else:
				for f2: String in FIELDS:
					c.set(f2, dup(saved[f2]))
		if not any:
			ok = false
			return
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		for id: String in old.keys():
			var c: Clip = s.clip_by_id(id)
			if c == null:
				continue
			var saved: Dictionary = old[id]
			for f: String in saved.keys():
				c.set(f, dup(saved[f]))
		doc.touch("meta")


class AddPreset extends "res://doc/commands/command.gd":
	var preset: Dictionary = {}

	func _init(p_preset: Dictionary) -> void:
		label = "Save preset"
		preset = p_preset.duplicate(true)

	func do(doc: Project) -> void:
		var id: String = str(preset.get("id", ""))
		if id.is_empty():
			ok = false
			return
		for p: Dictionary in doc.presets:
			if str(p.get("id", "")) == id:
				ok = false
				return
		doc.presets.append(preset.duplicate(true))
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var id: String = str(preset.get("id", ""))
		for i: int in doc.presets.size():
			if str(doc.presets[i].get("id", "")) == id:
				doc.presets.remove_at(i)
				break
		doc.touch("meta")


class RemovePreset extends "res://doc/commands/command.gd":
	var preset_id: String = ""
	var old: Dictionary = {}
	var index: int = -1

	func _init(p_preset_id: String) -> void:
		label = "Remove preset"
		preset_id = p_preset_id

	func do(doc: Project) -> void:
		index = -1
		for i: int in doc.presets.size():
			if str(doc.presets[i].get("id", "")) == preset_id:
				index = i
				break
		if index < 0:
			ok = false
			return
		old = doc.presets[index].duplicate(true)
		doc.presets.remove_at(index)
		doc.touch("meta")

	func undo(doc: Project) -> void:
		doc.presets.insert(mini(index, doc.presets.size()), old.duplicate(true))
		doc.touch("meta")

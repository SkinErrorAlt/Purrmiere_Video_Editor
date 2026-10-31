extends "res://doc/commands/composite.gd"

const TagApply := preload("res://doc/tag_apply.gd")
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const Presets := preload("res://doc/presets.gd")

var regions: PackedVector2Array = PackedVector2Array()
var key: String = ""
var scope: String = "audio"
var track_ids: PackedStringArray = PackedStringArray()
var ops: Dictionary = {}
var cuts: int = 0
var reused: int = 0
var touched: PackedStringArray = PackedStringArray()
var placed: PackedStringArray = PackedStringArray()


func _init(p_seq_id: String, p_regions: PackedVector2Array, p_key: String, p_scope: String, p_track_ids: PackedStringArray, p_ops: Dictionary) -> void:
	label = "Apply to tagged regions"
	seq_id = p_seq_id
	regions = TagApply.merged(p_regions)
	key = p_key
	scope = p_scope if TagApply.SCOPES.has(p_scope) else TagApply.SCOPE_AUDIO
	track_ids = p_track_ids
	ops = p_ops.duplicate(true)


func _plan(doc: Project) -> bool:
	var s: Sequence = seq(doc)
	if s == null or regions.is_empty() or not TagApply.enabled:
		return false
	cuts = 0
	reused = 0
	if ops.has("volume_db") or ops.has("param") or ops.has("effect") or ops.has("preset"):
		_cut_edges(doc, s)
	touched = TagApply.pieces(s, regions, scope, track_ids)
	if ops.has("volume_db"):
		var gain: float = TagApply.db_to_gain(float(ops["volume_db"]))
		for id: String in touched:
			var c: Clip = s.clip_by_id(id)
			var t: Track = s.track_of(id)
			if c != null and t != null and t.is_sound(c):
				apply(doc, ClipCmds.SetClipParam.new(seq_id, id, TagApply.VOLUME_PATH, AnimProp.make(gain)))
	if ops.has("param"):
		_apply_param(doc, s, ops["param"])
	if ops.has("effect"):
		_apply_effect(doc, s, ops["effect"])
	if ops.has("preset"):
		_apply_preset(doc, s, ops["preset"])
	if ops.has("file"):
		_apply_file(doc, s)
	return not steps.is_empty()


func _cut_edges(doc: Project, s: Sequence) -> void:
	var tracks: Array[Track] = TagApply.scope_tracks(s, scope, track_ids)
	for v: Vector2 in regions:
		for edge: float in [v.x, v.y]:
			var ids: PackedStringArray = PackedStringArray()
			for t: Track in tracks:
				for c: Clip in t.clips_in_range(edge - TagApply.EPS, edge + TagApply.EPS):
					if not TagApply.in_scope(t, c, scope) or not TagApply.placed_by_tag(c).is_empty():
						continue
					if edge > c.start + TagApply.EPS and edge < c.end() - TagApply.EPS:
						ids.append(c.id)
					elif absf(c.start - edge) <= TagApply.EPS:
						reused += 1
			if not ids.is_empty():
				var split: Command = apply(doc, EditCmds.SplitClips.new(seq_id, ids, edge, false))
				if split.ok:
					cuts += ids.size()


func _apply_param(doc: Project, s: Sequence, pd: Dictionary) -> void:
	var path: String = String(pd.get("path", ""))
	if path.is_empty():
		return
	var sound_path: bool = path.begins_with("audio.")
	for id: String in touched:
		var c: Clip = s.clip_by_id(id)
		var t: Track = s.track_of(id)
		if c == null or t == null:
			continue
		if (sound_path and not t.is_sound(c)) or (not sound_path and not t.is_picture(c)):
			continue
		apply(doc, ClipCmds.SetClipParam.new(seq_id, id, path, AnimProp.make(pd.get("value", 0.0))))


func _stamped(entries: Array, prefix: String, doc: Project) -> Array:
	var out: Array = []
	for e: Variant in entries:
		if not (e is Dictionary):
			continue
		var ed: Dictionary = (e as Dictionary).duplicate(true)
		ed["uid"] = prefix + doc.mint_id("e")
		if not ed.has("enabled"):
			ed["enabled"] = true
		if not (ed.get("params") is Dictionary):
			ed["params"] = {}
		if not ed.has("group"):
			ed["group"] = ""
		if not ed.has("mask"):
			ed["mask"] = ""
		out.append(ed)
	return out


func _without(list: Array, prefix: String) -> Array:
	var out: Array = []
	for e: Variant in list:
		if e is Dictionary and not String((e as Dictionary).get("uid", "")).begins_with(prefix):
			out.append((e as Dictionary).duplicate(true))
	return out


func _apply_preset(doc: Project, s: Sequence, preset: Dictionary) -> void:
	var kind: String = String(preset.get("kind", ""))
	if not TagApply.preset_ok(preset):
		return
	var prefix: String = TagApply.PRESET_PREFIX + key + "_" + String(preset.get("id", "p")).validate_node_name() + "_"
	for id: String in touched:
		var c: Clip = s.clip_by_id(id)
		var t: Track = s.track_of(id)
		if c == null or t == null:
			continue
		var payload: Dictionary = Presets.anchored_payload(preset, c, 0.0)
		if kind == "audio_fx":
			if not t.is_sound(c):
				continue
			var audio: Dictionary = c.audio.duplicate(true)
			var chain: Array = _without(audio.get("effects", []) if audio.get("effects") is Array else [], prefix)
			chain.append_array(_stamped(payload.get("audio_effects", []) if payload.get("audio_effects") is Array else [], prefix, doc))
			audio["effects"] = chain
			if payload.has("volume"):
				audio["volume"] = payload["volume"]
			if payload.has("pan"):
				audio["pan"] = payload["pan"]
			apply(doc, ClipCmds.SetClipField.new(seq_id, id, "audio", audio))
			continue
		if not t.is_picture(c):
			continue
		if kind == "transform":
			if not (payload.get("transform") is Dictionary):
				continue
			var tf: Dictionary = Clip.default_transform()
			for k: Variant in (payload["transform"] as Dictionary).keys():
				var v: Variant = payload["transform"][k]
				if v is Dictionary:
					tf[k] = (v as Dictionary).duplicate(true)
				elif v is float or v is int or v is Array:
					tf[k] = AnimProp.make(v)
				else:
					tf[k] = v
			apply(doc, ClipCmds.SetClipField.new(seq_id, id, "transform", tf))
			continue
		var entries: Array = []
		if payload.get("effects") is Array:
			entries = payload["effects"]
		elif payload.get("effect") is Dictionary:
			entries = [payload["effect"]]
		if entries.is_empty():
			continue
		var list: Array = _without(c.effects, prefix)
		list.append_array(_stamped(entries, prefix, doc))
		var typed: Array[Dictionary] = []
		for e2: Variant in list:
			typed.append(e2)
		apply(doc, ClipCmds.SetClipField.new(seq_id, id, "effects", typed))


func _apply_effect(doc: Project, s: Sequence, def: Dictionary) -> void:
	var is_audio: bool = bool(def.get("audio", false))
	var prefix: String = TagApply.UID_PREFIX + key + "_"
	for id: String in touched:
		var c: Clip = s.clip_by_id(id)
		var t: Track = s.track_of(id)
		if c == null or t == null or (is_audio and not t.is_sound(c)) or (not is_audio and not t.is_picture(c)):
			continue
		var list: Array = c.audio_effects() if is_audio else c.effects
		for e: Variant in list.duplicate():
			var ed: Dictionary = e
			if String(ed.get("uid", "")).begins_with(prefix) and String(ed.get("id", "")) == String(def.get("id", "")):
				apply(doc, EffectCmds.RemoveEffect.new(seq_id, id, String(ed["uid"]), is_audio))
		apply(doc, EffectCmds.AddEffect.new(seq_id, id, Verbs.effect_def_for_clip(doc, s, c, def), prefix + doc.mint_id("e"), -1, is_audio))


func _apply_file(doc: Project, s: Sequence) -> void:
	var sound: String = String(ops["file"])
	var target: Track = s.track_by_id(String(ops.get("file_track", "")))
	if target == null or target.locked:
		return
	var media_id: String = TagApply.sound_media_id(doc, sound)
	if media_id.is_empty() and TagApply.BUILT_IN_SOUNDS.has(sound):
		var md: Dictionary = TagApply.sound_media_dict(doc, sound)
		if md.is_empty():
			return
		apply(doc, MediaCmds.AddMedia.new(md))
		media_id = String(md["id"])
	var item: MediaItem = doc.media_by_id(media_id)
	if item == null:
		return
	var old: PackedStringArray = PackedStringArray()
	for t: Track in s.all_tracks():
		for c: Clip in t.clips:
			if TagApply.placed_by_tag(c) == key:
				old.append(c.id)
	if not old.is_empty():
		apply(doc, ClipCmds.RemoveClips.new(seq_id, old))
	var length: float = doc.media_duration(item)
	var loop: bool = bool(ops.get("file_loop", false)) and length > TagApply.EPS
	for v: Vector2 in regions:
		var span: float = v.y - v.x
		var dur: float = span if length <= 0.0 else minf(span, length)
		if dur <= TagApply.EPS:
			continue
		var fill: float = span if loop else dur
		apply(doc, EditCmds.LiftRange.new(seq_id, v.x, v.x + fill, PackedStringArray([target.id])))
		var at: float = v.x
		while at < v.x + fill - TagApply.EPS:
			var piece: float = minf(dur, v.x + fill - at)
			_place_sound(doc, target, media_id, item.label, at, piece)
			at += piece
			if not loop:
				break


func _place_sound(doc: Project, target: Track, media_id: String, label_text: String, at: float, dur: float) -> void:
	var cid: String = doc.mint_id("c")
	var cd: Dictionary = {"id": cid, "media_id": media_id, "label": label_text, "start": at, "duration": dur, "in_offset": 0.0, "props": {TagApply.PROP_KEY: key}}
	var audio: Dictionary = {"stream": 0.0}
	if ops.has("file_db"):
		audio["volume"] = AnimProp.make(TagApply.db_to_gain(float(ops["file_db"])))
	if target.kind == "audio" or target.free:
		cd["audio"] = audio
	var placed_cmd: Command = apply(doc, ClipCmds.PlaceClip.new(seq_id, target.id, cd))
	if placed_cmd.ok:
		placed.append(cid)

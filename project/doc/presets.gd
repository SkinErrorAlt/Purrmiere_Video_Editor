extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Io := preload("res://doc/io.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const SequenceCmds := preload("res://doc/commands/sequence_cmds.gd")
const StreamRoles := preload("res://doc/stream_roles.gd")
const AssetPacks := preload("res://doc/asset_packs.gd")
const YtPresets := preload("res://doc/yt_presets.gd")
const VoicePresets := preload("res://doc/voice_presets.gd")
const KINDS := ["effect", "effect_stack", "transform", "sequence", "export", "export_place", "audio_fx", "sfx_combo", "composition", "text_style", "stream_roles", "asset_pack", "driver", "transition"]
const SEQUENCE_FIELDS := ["fps", "width", "height", "sample_rate", "drop_frame"]
const ANCHORS: PackedStringArray = ["start", "end", "percent", "playhead"]
const PLACED: PackedStringArray = ["composition", "sfx_combo"]
const ELSEWHERE: Dictionary = {
	"export": "Export presets are applied in the Export panel",
	"export_place": "Export places are chosen in the Export panel",
	"asset_pack": "Asset packages are brought in from the packages sheet",
	"driver": "A driver preset is applied from the Drive button on a value in Effect Controls",
}
const SORT_STEP := 10

static var _counter: int = 0
static var last_refusal: String = ""


static func kind_known(kind: String) -> bool:
	return KINDS.has(kind)


static func refuse_kind(kind: String, where: String) -> String:
	var named: String = kind if not kind.strip_edges().is_empty() else "(none)"
	last_refusal = "unknown preset kind " + named + " in " + where + ", nothing was written"
	print("Presets: " + last_refusal)
	push_error("Presets: " + last_refusal)
	return last_refusal


static func mint_id(kind: String) -> String:
	_counter += 1
	var stamp: String = str(Time.get_unix_time_from_system()).replace(".", "")
	return kind + "_" + stamp + "_" + str(_counter) + "_" + str(randi() % 100000)


static func make(kind: String, label: String, payload: Dictionary, tags: PackedStringArray = PackedStringArray()) -> Dictionary:
	if not kind_known(kind):
		refuse_kind(kind, "make")
		return {}
	return {
		"id": mint_id(kind),
		"kind": kind,
		"label": label,
		"tags": Array(tags),
		"payload": payload.duplicate(true),
		"created": Time.get_datetime_string_from_system(true),
		"anchor": "start",
		"percent": 0.0,
		"max_length": 0.0,
		"sort": 0,
	}


static func normalize(d: Dictionary) -> Dictionary:
	var kind: String = str(d.get("kind", ""))
	if not kind_known(kind):
		refuse_kind(kind, "normalize")
		return {}
	var out: Dictionary = {"id": str(d.get("id", "")), "kind": kind, "label": str(d.get("label", "")), "tags": [], "payload": {}, "created": str(d.get("created", "")), "anchor": str(d.get("anchor", "start")), "percent": float(d.get("percent", 0.0)), "max_length": float(d.get("max_length", 0.0)), "sort": int(d.get("sort", 0))}
	if not ANCHORS.has(str(out["anchor"])):
		out["anchor"] = "start"
	for t: Variant in d.get("tags", []):
		(out["tags"] as Array).append(str(t))
	if d.get("payload") is Dictionary:
		out["payload"] = (d["payload"] as Dictionary).duplicate(true)
	return out


static func is_valid(d: Dictionary) -> bool:
	return not str(d.get("id", "")).is_empty() and KINDS.has(str(d.get("kind", ""))) and d.get("payload") is Dictionary


static func sort_of(p: Dictionary) -> int:
	return int(p.get("sort", 0))


static func before(a: Dictionary, b: Dictionary) -> bool:
	var sa: int = sort_of(a)
	var sb: int = sort_of(b)
	if sa != sb:
		return sa < sb
	return str(a.get("label", "")).nocasecmp_to(str(b.get("label", ""))) < 0


static func order(list: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(list)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return before(a, b))
	return out


static func ids_of(list: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for p: Dictionary in list:
		out.append(str(p.get("id", "")))
	return out


static func numbered(ids: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for i: int in ids.size():
		out[ids[i]] = (i + 1) * SORT_STEP
	return out


static func moved_order(ids: PackedStringArray, id: String, to_index: int) -> PackedStringArray:
	var from: int = ids.find(id)
	if from < 0:
		return ids.duplicate()
	var rest: PackedStringArray = PackedStringArray()
	for i: int in ids.size():
		if i != from:
			rest.append(ids[i])
	var at: int = clampi(to_index, 0, rest.size())
	rest.insert(at, id)
	return rest


static func copy_label(label: String, taken: PackedStringArray) -> String:
	var base: String = label.strip_edges()
	if base.is_empty():
		base = "Preset"
	var wanted: String = base + " copy"
	var n: int = 2
	while taken.has(wanted):
		wanted = base + " copy " + str(n)
		n += 1
	return wanted


static func duplicate_of(preset: Dictionary, taken: PackedStringArray = PackedStringArray()) -> Dictionary:
	var kind: String = str(preset.get("kind", ""))
	if not kind_known(kind):
		refuse_kind(kind, "duplicate")
		return {}
	var out: Dictionary = preset.duplicate(true)
	out["id"] = mint_id(kind)
	out["label"] = copy_label(str(preset.get("label", "")), taken)
	out["created"] = Time.get_datetime_string_from_system(true)
	out["sort"] = sort_of(preset) + 1
	return out


static func list_project(doc: Project, kind: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null:
		return out
	for p: Dictionary in doc.presets:
		if kind.is_empty() or str(p.get("kind", "")) == kind:
			out.append(p.duplicate(true))
	return order(out)


static func find_project(doc: Project, id: String) -> Dictionary:
	for p: Dictionary in doc.presets:
		if str(p.get("id", "")) == id:
			return p.duplicate(true)
	return {}


static func save_to_project(doc: Project, preset: Dictionary) -> bool:
	if not is_valid(preset):
		refuse_kind(str(preset.get("kind", "")), "save to project")
		return false
	var cmd: Command = EffectCmds.AddPreset.new(preset)
	return Verbs.run(doc, cmd.label, [cmd])


static func remove_from_project(doc: Project, id: String) -> bool:
	var cmd: Command = EffectCmds.RemovePreset.new(id)
	return Verbs.run(doc, cmd.label, [cmd])


static func replace_in_project(doc: Project, preset: Dictionary, what: String = "Edit preset") -> bool:
	if doc == null:
		return false
	if not is_valid(preset):
		refuse_kind(str(preset.get("kind", "")), "save to project")
		return false
	var id: String = str(preset.get("id", ""))
	var cmds: Array[Command] = []
	if not find_project(doc, id).is_empty():
		cmds.append(EffectCmds.RemovePreset.new(id))
	cmds.append(EffectCmds.AddPreset.new(preset))
	return Verbs.run(doc, what, cmds)


static func save_to_user(preset: Dictionary) -> bool:
	if not is_valid(preset):
		refuse_kind(str(preset.get("kind", "")), "save to the library")
		return false
	return Io.save_preset(preset) == OK


static func save_user(preset: Dictionary) -> bool:
	if str(preset.get("kind", "")) == AssetPacks.KIND:
		return save_asset_pack(preset)
	return save_to_user(preset)


static func delete_user(kind: String, id: String) -> bool:
	if kind == AssetPacks.KIND:
		return delete_asset_pack(id)
	return Io.delete_user_preset(kind, id)


static func list_user(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in Io.load_user_presets(kind):
		var n: Dictionary = normalize(d)
		if is_valid(n):
			out.append(n)
	return out


static func list_user_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for kind: String in KINDS:
		out.append_array(list_user(kind))
	out.append_array(built_in_unshadowed(ids_of(out)))
	return order(out)


static func list_built_in() -> Array[Dictionary]:
	var out: Array[Dictionary] = YtPresets.listing()
	out.append_array(VoicePresets.listing())
	return out


static func built_in_unshadowed(taken: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in list_built_in():
		if not taken.has(str(p.get("id", ""))):
			out.append(p)
	return out


static func is_built_in_preset(id: String) -> bool:
	return YtPresets.ships(id) or VoicePresets.ships(id)


static func reorder_user(ids: PackedStringArray) -> bool:
	if ids.is_empty():
		return false
	var nums: Dictionary = numbered(ids)
	var wrote: bool = false
	for p: Dictionary in list_user_all():
		var id: String = str(p.get("id", ""))
		if not nums.has(id) or sort_of(p) == int(nums[id]):
			continue
		p["sort"] = int(nums[id])
		if save_user(p):
			wrote = true
	return wrote


static func reorder_project(doc: Project, ids: PackedStringArray) -> bool:
	if doc == null or ids.is_empty():
		return false
	var nums: Dictionary = numbered(ids)
	var cmds: Array[Command] = []
	for p: Dictionary in list_project(doc):
		var id: String = str(p.get("id", ""))
		if not nums.has(id) or sort_of(p) == int(nums[id]):
			continue
		var fresh: Dictionary = p.duplicate(true)
		fresh["sort"] = int(nums[id])
		cmds.append(EffectCmds.RemovePreset.new(id))
		cmds.append(EffectCmds.AddPreset.new(fresh))
	if cmds.is_empty():
		return false
	return Verbs.run(doc, "Reorder presets", cmds)


static func effect_stack_from_clip(c: Clip, label: String) -> Dictionary:
	var effects: Array = []
	for e: Dictionary in c.effects:
		var ed: Dictionary = e.duplicate(true)
		ed.erase("uid")
		effects.append(ed)
	return make("effect_stack", label, {"effects": effects})


static func effect_from_entry(entry: Dictionary, label: String) -> Dictionary:
	var ed: Dictionary = entry.duplicate(true)
	ed.erase("uid")
	return make("effect", label, {"effect": ed})


static func transform_from_clip(c: Clip, label: String) -> Dictionary:
	return make("transform", label, {"transform": c.transform.duplicate(true), "motion_blur": c.motion_blur.duplicate(true)})


static func sequence_from(s: Sequence, label: String) -> Dictionary:
	var payload: Dictionary = {}
	for f: String in SEQUENCE_FIELDS:
		payload[f] = s.get(f)
	return make("sequence", label, payload)


static func key_span(p: Dictionary) -> Vector2:
	var ks: Array[Dictionary] = AnimProp.keys(p)
	if ks.is_empty():
		return Vector2(-1.0, -1.0)
	return Vector2(float(ks[0].get("t", 0.0)), float(ks[ks.size() - 1].get("t", 0.0)))


static func payload_span(payload: Dictionary) -> Vector2:
	var lo: float = INF
	var hi: float = -INF
	var stack: Array = [payload]
	while not stack.is_empty():
		var v: Variant = stack.pop_back()
		if v is Dictionary:
			var dv: Dictionary = v
			if AnimProp.is_animated(dv):
				var sp: Vector2 = key_span(dv)
				if sp.x >= 0.0:
					lo = minf(lo, sp.x)
					hi = maxf(hi, sp.y)
				continue
			for k: Variant in dv.keys():
				stack.append(dv[k])
		elif v is Array:
			for e: Variant in v:
				stack.append(e)
	if lo == INF:
		return Vector2(-1.0, -1.0)
	return Vector2(lo, hi)


static func retime_prop(p: Dictionary, offset: float, scale: float, origin: float) -> Dictionary:
	if not AnimProp.is_animated(p):
		return p.duplicate(true)
	var out: Dictionary = p.duplicate(true)
	var li: int = AnimProp.keys_layer_index(out)
	if li < 0:
		return out
	for k: Variant in (out["layers"][li] as Dictionary).get("keys", []):
		var kd: Dictionary = k
		kd["t"] = maxf((float(kd.get("t", 0.0)) - origin) * scale + origin + offset, 0.0)
		for h: String in ["hi", "ho"]:
			if kd.get(h) is Array and (kd[h] as Array).size() >= 1:
				(kd[h] as Array)[0] = float((kd[h] as Array)[0]) * scale
	return out


static func retime_payload(v: Variant, offset: float, scale: float, origin: float) -> Variant:
	if v is Dictionary:
		var dv: Dictionary = v
		if AnimProp.is_animated(dv):
			return retime_prop(dv, offset, scale, origin)
		var out: Dictionary = {}
		for k: Variant in dv.keys():
			out[k] = retime_payload(dv[k], offset, scale, origin)
		return out
	if v is Array:
		var arr: Array = []
		for e: Variant in v:
			arr.append(retime_payload(e, offset, scale, origin))
		return arr
	return v


static func anchored_payload(preset: Dictionary, c: Clip, playhead_local: float) -> Dictionary:
	var payload: Dictionary = preset.get("payload", {})
	var span: Vector2 = payload_span(payload)
	if span.x < 0.0 or c == null:
		return payload
	var anchor: String = str(preset.get("anchor", "start"))
	var max_len: float = float(preset.get("max_length", 0.0))
	var length: float = maxf(span.y - span.x, 0.0)
	var scale: float = 1.0
	if max_len > 0.0 and length > max_len:
		scale = max_len / length
		length = max_len
	var target: float = span.x
	if anchor == "end":
		target = maxf(c.duration - length, 0.0)
	elif anchor == "percent":
		target = clampf(float(preset.get("percent", 0.0)), 0.0, 1.0) * c.duration
	elif anchor == "playhead":
		target = maxf(playhead_local, 0.0)
	else:
		target = span.x
	if anchor == "start" and scale == 1.0:
		return payload
	return retime_payload(payload, target - span.x, scale, span.x)


static func why_not_applied(kind: String) -> String:
	if PLACED.has(kind):
		return "a " + kind.replace("_", " ") + " preset is placed on the timeline, not applied to a clip"
	if ELSEWHERE.has(kind):
		return str(ELSEWHERE[kind])
	return "there is nothing to apply for a " + kind.replace("_", " ") + " preset"


static func apply(doc: Project, seq: Sequence, preset: Dictionary, clip_ids: PackedStringArray = PackedStringArray()) -> bool:
	var kind: String = str(preset.get("kind", ""))
	if not kind_known(kind):
		refuse_kind(kind, "apply")
		return false
	if kind == "effect_stack" or kind == "effect":
		return apply_effects(doc, seq, clip_ids, preset)
	if kind == "transform":
		return apply_transform(doc, seq, clip_ids, preset)
	if kind == "sequence":
		return apply_sequence(doc, seq, preset)
	if kind == "text_style":
		return apply_text_style(doc, seq, clip_ids, preset)
	if kind == "audio_fx":
		return apply_audio_fx(doc, seq, clip_ids, preset)
	if kind == StreamRoles.KIND:
		return apply_stream_roles(doc, seq, clip_ids, preset)
	last_refusal = why_not_applied(kind)
	print("Presets: " + last_refusal)
	return false


static func audio_fx_from_clip(c: Clip, label: String) -> Dictionary:
	var effects: Array = []
	for e: Variant in c.audio_effects():
		if not (e is Dictionary):
			continue
		var ed: Dictionary = (e as Dictionary).duplicate(true)
		ed.erase("uid")
		effects.append(ed)
	var payload: Dictionary = {"audio_effects": effects}
	if c.audio.has("volume"):
		payload["volume"] = c.audio["volume"]
	if c.audio.has("pan"):
		payload["pan"] = c.audio["pan"]
	return make("audio_fx", label, payload)


static func combo_from_clipboard(cb: Dictionary, label: String) -> Dictionary:
	var clips: Array = []
	for e: Variant in cb.get("clips", []):
		if e is Dictionary and str((e as Dictionary).get("kind", "")) == "audio":
			clips.append(e)
	if clips.is_empty():
		last_refusal = "an SFX combo needs at least one sound clip in the selection"
		return {}
	var payload: Dictionary = {"clips": clips, "span": float(cb.get("span", 0.0))}
	if cb.get("groups") is Dictionary:
		payload["groups"] = cb["groups"]
	return make("sfx_combo", label, payload)


static func apply_audio_fx(doc: Project, seq: Sequence, clip_ids: PackedStringArray, preset: Dictionary) -> bool:
	if doc == null or seq == null:
		return false
	var cmds: Array[Command] = []
	for id: String in clip_ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			continue
		var payload: Dictionary = anchored_payload(preset, c, seq.playhead - c.start)
		var entries: Array = payload["audio_effects"] if payload.get("audio_effects") is Array else []
		if entries.is_empty() and not payload.has("volume") and not payload.has("pan"):
			continue
		var audio: Dictionary = c.audio.duplicate(true)
		var chain: Array = []
		if audio.get("effects") is Array:
			chain.append_array(audio["effects"])
		for e: Variant in entries:
			if not (e is Dictionary):
				continue
			var ed: Dictionary = (e as Dictionary).duplicate(true)
			ed["uid"] = doc.mint_id("e")
			if not ed.has("enabled"):
				ed["enabled"] = true
			if not (ed.get("params") is Dictionary):
				ed["params"] = {}
			chain.append(ed)
		audio["effects"] = chain
		if payload.has("volume"):
			audio["volume"] = payload["volume"]
		if payload.has("pan"):
			audio["pan"] = payload["pan"]
		cmds.append(ClipCmds.SetClipField.new(seq.id, id, "audio", audio))
	if cmds.is_empty():
		last_refusal = "that audio preset holds nothing to put on the selection"
		return false
	return Verbs.run(doc, "Apply " + str(preset.get("label", "preset")), cmds)


static func stream_roles_from(item: MediaItem, label: String) -> Dictionary:
	return make(StreamRoles.KIND, label, StreamRoles.to_payload(StreamRoles.names_of(item)))


static func asset_pack_from(doc: Project, media_ids: PackedStringArray, label: String, bin: String, import_at_once: bool, opts: Dictionary = {}) -> Dictionary:
	return make(AssetPacks.KIND, label, AssetPacks.payload_from(doc, media_ids, bin, import_at_once, opts))


static func list_asset_packs(doc: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for p: Dictionary in list_user(AssetPacks.KIND):
		seen[String(p.get("id", ""))] = true
		out.append(p)
	if doc != null:
		for p: Dictionary in list_project(doc, AssetPacks.KIND):
			if not seen.has(String(p.get("id", ""))):
				out.append(p)
	return order(out)


static func save_asset_pack(pack: Dictionary) -> bool:
	if not AssetPacks.is_pack(pack):
		return false
	if AssetPacks.items_of(pack).is_empty() and AssetPacks.folders_of(pack).is_empty():
		return false
	if not save_to_user(pack):
		return false
	AssetPacks.bump_library()
	return true


static func delete_asset_pack(id: String) -> bool:
	var gone: bool = Io.delete_user_preset(AssetPacks.KIND, id)
	if gone:
		AssetPacks.bump_library()
	return gone


static func apply_stream_roles(doc: Project, seq: Sequence, clip_ids: PackedStringArray, preset: Dictionary) -> bool:
	if doc == null or seq == null:
		last_refusal = "there is no sequence open to name tracks in"
		return false
	var ids: PackedStringArray = PackedStringArray()
	for id: String in clip_ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null or c.media_id.is_empty() or ids.has(c.media_id):
			continue
		ids.append(c.media_id)
	if ids.is_empty():
		last_refusal = "nothing in the selection has a file whose tracks can be named"
		return false
	return StreamRoles.apply_preset(doc, preset, ids)


static func apply_text_style(doc: Project, seq: Sequence, clip_ids: PackedStringArray, preset: Dictionary) -> bool:
	if seq == null:
		last_refusal = "there is no sequence open to style"
		return false
	var style: Dictionary = (preset.get("payload", {}) as Dictionary).get("props", {})
	var cmds: Array[Command] = []
	for id: String in clip_ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			continue
		var m: MediaItem = doc.media_by_id(c.media_id)
		if m == null or m.kind != "title":
			continue
		var props: Dictionary = c.props.duplicate(true)
		for k: Variant in style.keys():
			if String(k) != "text":
				props[k] = style[k]
		cmds.append(ClipCmds.SetClipField.new(seq.id, id, "props", props))
	if cmds.is_empty():
		last_refusal = "nothing in the selection is a title, so there was no text to style"
		return false
	return Verbs.run(doc, "Apply " + str(preset.get("label", "style")), cmds)


static func apply_effects(doc: Project, seq: Sequence, clip_ids: PackedStringArray, preset: Dictionary) -> bool:
	if seq == null:
		last_refusal = "there is no sequence open to put effects on"
		return false
	var cmds: Array[Command] = []
	for id: String in clip_ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			continue
		var payload: Dictionary = anchored_payload(preset, c, seq.playhead - c.start)
		var entries: Array = []
		if payload.get("effects") is Array:
			entries = payload["effects"]
		elif payload.get("effect") is Dictionary:
			entries = [payload["effect"]]
		if entries.is_empty():
			continue
		var new_effects: Array[Dictionary] = c.effects.duplicate(true)
		var gid: String = doc.mint_id("g") if str(preset.get("kind", "")) == "effect_stack" and entries.size() >= 2 else ""
		for e: Variant in entries:
			if not (e is Dictionary):
				continue
			var ed: Dictionary = (e as Dictionary).duplicate(true)
			ed["uid"] = doc.mint_id("e")
			if not gid.is_empty():
				ed["group"] = gid
				ed["group_label"] = str(preset.get("label", "Effect group"))
			if not ed.has("enabled"):
				ed["enabled"] = true
			if not (ed.get("params") is Dictionary):
				ed["params"] = {}
			if not ed.has("group"):
				ed["group"] = ""
			if not ed.has("mask"):
				ed["mask"] = ""
			new_effects.append(ed)
		cmds.append(ClipCmds.SetClipField.new(seq.id, id, "effects", new_effects))
	if cmds.is_empty():
		last_refusal = "that preset holds no effects to add to the selection"
		return false
	return Verbs.run(doc, "Apply " + str(preset.get("label", "preset")), cmds)


static func apply_transform(doc: Project, seq: Sequence, clip_ids: PackedStringArray, preset: Dictionary) -> bool:
	if not ((preset.get("payload", {}) as Dictionary).get("transform") is Dictionary) or seq == null:
		last_refusal = "that preset holds no transform to apply"
		return false
	var cmds: Array[Command] = []
	for id: String in clip_ids:
		var tc: Clip = seq.clip_by_id(id)
		if tc == null:
			continue
		var payload: Dictionary = anchored_payload(preset, tc, seq.playhead - tc.start)
		var tf: Dictionary = Clip.default_transform()
		for k: Variant in (payload["transform"] as Dictionary).keys():
			tf[k] = AnimProp.norm(payload["transform"][k]) if not (payload["transform"][k] is Dictionary) else (payload["transform"][k] as Dictionary).duplicate(true)
		cmds.append(ClipCmds.SetClipField.new(seq.id, id, "transform", tf))
		if payload.get("motion_blur") is Dictionary:
			var mb: Dictionary = Clip.default_motion_blur()
			for k: Variant in (payload["motion_blur"] as Dictionary).keys():
				mb[k] = AnimProp.norm(payload["motion_blur"][k])
			cmds.append(ClipCmds.SetClipField.new(seq.id, id, "motion_blur", mb))
	if cmds.is_empty():
		last_refusal = "nothing in the selection took the transform"
		return false
	return Verbs.run(doc, "Apply " + str(preset.get("label", "preset")), cmds)


static func apply_sequence(doc: Project, seq: Sequence, preset: Dictionary) -> bool:
	var payload: Dictionary = preset.get("payload", {})
	if seq == null:
		last_refusal = "there is no sequence open to set"
		return false
	var cmds: Array[Command] = []
	for f: String in SEQUENCE_FIELDS:
		if payload.has(f) and payload[f] != seq.get(f):
			cmds.append(SequenceCmds.SetSequenceField.new(seq.id, f, payload[f]))
	if cmds.is_empty():
		last_refusal = "the sequence is already set that way"
		return false
	return Verbs.run(doc, "Apply " + str(preset.get("label", "preset")), cmds)

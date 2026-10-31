extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const Subtitles := preload("res://doc/subtitles.gd")
const Presets := preload("res://doc/presets.gd")
const Io := preload("res://doc/io.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const KIND := "subtitle_character"
const VERSION := 1
const PROP_CHARACTER := "character"
const ENTRY_MARK := "from_character"
const PREF_SCOPE := "subtitles.character_saves_to"
const SCOPE_USER := "user"
const SCOPE_PROJECT := "project"
const SCOPES: PackedStringArray = ["user", "project"]
const ROOM: PackedStringArray = ["position", "animations"]
const DEFAULT_COLOUR := [1.0, 0.42, 0.72, 1.0]

static var _counter: int = 0


static func kind_registered() -> bool:
	return Presets.KINDS.has(KIND)


static func mint_id() -> String:
	_counter += 1
	var stamp: String = str(Time.get_unix_time_from_system()).replace(".", "")
	return KIND + "_" + stamp + "_" + str(_counter) + "_" + str(randi() % 100000)


static func prefs_node() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
		if prefs != null and prefs.has_method("register"):
			return prefs
	return null


static func register_prefs() -> Node:
	var prefs: Node = prefs_node()
	if prefs != null and not bool(prefs.call("is_registered", PREF_SCOPE)):
		prefs.call("register", PREF_SCOPE, SCOPE_USER, {"label": "Where a new subtitle character preset is saved (user for every project, project for this one)", "type": "enum", "choices": ["user", "project"]})
	return prefs


static func default_scope() -> String:
	var prefs: Node = register_prefs()
	if prefs == null:
		return SCOPE_USER
	var v: String = String(prefs.call("get_value", PREF_SCOPE))
	return v if SCOPES.has(v) else SCOPE_USER


static func set_default_scope(scope: String) -> void:
	var prefs: Node = register_prefs()
	if prefs != null:
		prefs.call("set_value", PREF_SCOPE, scope if SCOPES.has(scope) else SCOPE_USER)


static func blank_payload() -> Dictionary:
	return {"version": VERSION, "name": "", "colour": DEFAULT_COLOUR.duplicate(true), "style": {}, "effects": [], "position": {}, "animations": {}}


static func normalize_payload(raw: Dictionary) -> Dictionary:
	var out: Dictionary = blank_payload()
	out["version"] = int(raw.get("version", VERSION))
	out["name"] = str(raw.get("name", ""))
	if raw.get("colour") is Array and (raw["colour"] as Array).size() >= 3:
		out["colour"] = (raw["colour"] as Array).duplicate(true)
	if raw.get("style") is Dictionary:
		out["style"] = TitleStyle.style_subset(raw["style"])
	if raw.get("effects") is Array:
		var list: Array = []
		for e: Variant in raw["effects"]:
			if not (e is Dictionary):
				continue
			var ed: Dictionary = (e as Dictionary).duplicate(true)
			ed.erase("uid")
			ed.erase(ENTRY_MARK)
			list.append(ed)
		out["effects"] = list
	for k: String in ROOM:
		if raw.get(k) is Dictionary:
			out[k] = (raw[k] as Dictionary).duplicate(true)
	for k2: Variant in raw.keys():
		if not out.has(String(k2)):
			out[String(k2)] = raw[k2]
	return out


static func make(label: String, payload: Dictionary, tags: PackedStringArray = PackedStringArray()) -> Dictionary:
	var body: Dictionary = normalize_payload(payload)
	if str(body["name"]).is_empty():
		body["name"] = label
	if kind_registered():
		var via: Dictionary = Presets.make(KIND, label, body, tags)
		if not via.is_empty():
			return via
	return {
		"id": mint_id(),
		"kind": KIND,
		"label": label,
		"tags": Array(tags),
		"payload": body,
		"created": Time.get_datetime_string_from_system(true),
		"anchor": "start",
		"percent": 0.0,
		"max_length": 0.0,
		"sort": 0,
	}


static func is_character(preset: Dictionary) -> bool:
	return str(preset.get("kind", "")) == KIND and preset.get("payload") is Dictionary


static func normalize(preset: Dictionary) -> Dictionary:
	if not is_character(preset):
		return {}
	var id: String = str(preset.get("id", ""))
	if id.is_empty():
		return {}
	var out: Dictionary = preset.duplicate(true)
	out["id"] = id
	out["kind"] = KIND
	out["label"] = str(preset.get("label", ""))
	out["tags"] = []
	for t: Variant in preset.get("tags", []):
		(out["tags"] as Array).append(str(t))
	out["payload"] = normalize_payload(preset["payload"])
	out["created"] = str(preset.get("created", ""))
	out["anchor"] = "start"
	out["percent"] = float(preset.get("percent", 0.0))
	out["max_length"] = float(preset.get("max_length", 0.0))
	out["sort"] = int(preset.get("sort", 0))
	return out


static func payload_of(preset: Dictionary) -> Dictionary:
	if preset.get("payload") is Dictionary:
		return preset["payload"]
	return {}


static func name_of(preset: Dictionary) -> String:
	return str(payload_of(preset).get("name", ""))


static func label_of(preset: Dictionary) -> String:
	var lab: String = str(preset.get("label", "")).strip_edges()
	if not lab.is_empty():
		return lab
	var nm: String = name_of(preset).strip_edges()
	return nm if not nm.is_empty() else "Character"


static func colour_of(preset: Dictionary) -> Array:
	var c: Variant = payload_of(preset).get("colour", null)
	if c is Array and (c as Array).size() >= 3:
		return (c as Array).duplicate(true)
	return DEFAULT_COLOUR.duplicate(true)


static func style_of(preset: Dictionary) -> Dictionary:
	var s: Variant = payload_of(preset).get("style", null)
	return (s as Dictionary).duplicate(true) if s is Dictionary else {}


static func effects_of(preset: Dictionary) -> Array:
	var e: Variant = payload_of(preset).get("effects", null)
	return (e as Array).duplicate(true) if e is Array else []


static func room_of(preset: Dictionary, key: String) -> Dictionary:
	var r: Variant = payload_of(preset).get(key, null)
	return (r as Dictionary).duplicate(true) if r is Dictionary else {}


static func with_room(preset: Dictionary, key: String, data: Dictionary) -> Dictionary:
	var p: Dictionary = normalize(preset)
	if p.is_empty() or not ROOM.has(key):
		return preset.duplicate(true)
	(p["payload"] as Dictionary)[key] = data.duplicate(true)
	return p


static func renamed(preset: Dictionary, label: String) -> Dictionary:
	var p: Dictionary = normalize(preset)
	if p.is_empty():
		return {}
	var want: String = label.strip_edges()
	if want.is_empty():
		return p
	p["label"] = want
	(p["payload"] as Dictionary)["name"] = want
	return p


static func recoloured(preset: Dictionary, colour: Array) -> Dictionary:
	var p: Dictionary = normalize(preset)
	if p.is_empty() or colour.size() < 3:
		return p
	(p["payload"] as Dictionary)["colour"] = colour.duplicate(true)
	return p


static func copy_of(preset: Dictionary, label: String = "") -> Dictionary:
	var p: Dictionary = normalize(preset)
	if p.is_empty():
		return {}
	var want: String = label.strip_edges()
	if want.is_empty():
		want = label_of(p) + " copy"
	var fresh: Dictionary = make(want, p["payload"])
	fresh["sort"] = int(p.get("sort", 0)) + 1
	return fresh


static func effect_entries(c: Clip) -> Array:
	var out: Array = []
	if c == null:
		return out
	for e: Dictionary in c.effects:
		var ed: Dictionary = e.duplicate(true)
		ed.erase("uid")
		ed.erase(ENTRY_MARK)
		out.append(ed)
	return out


static func from_clip(doc: Project, c: Clip, label: String, colour: Array = []) -> Dictionary:
	if doc == null or c == null:
		return {}
	var m: MediaItem = doc.media_by_id(c.media_id)
	var media_props: Dictionary = m.props.duplicate(true) if m != null else {}
	var payload: Dictionary = blank_payload()
	payload["name"] = label
	payload["style"] = TitleStyle.full_style(media_props, c.props)
	payload["effects"] = effect_entries(c)
	if colour.size() >= 3:
		payload["colour"] = colour.duplicate(true)
	return make(label, payload)


static func from_style(label: String, style: Dictionary, effects: Array = [], colour: Array = []) -> Dictionary:
	var payload: Dictionary = blank_payload()
	payload["name"] = label
	payload["style"] = TitleStyle.style_subset(style)
	payload["effects"] = effects.duplicate(true)
	if colour.size() >= 3:
		payload["colour"] = colour.duplicate(true)
	return make(label, payload)


static func pretty_id(id: String) -> String:
	var t: String = id.replace("_", " ").replace("-", " ").strip_edges()
	if t.is_empty():
		return "effect"
	return t.substr(0, 1).to_upper() + t.substr(1)


static func effect_label(entry: Dictionary, labels: Dictionary = {}) -> String:
	var id: String = str(entry.get("id", ""))
	if labels.has(id):
		return str(labels[id])
	var own: String = str(entry.get("label", ""))
	if not own.is_empty():
		return own
	return pretty_id(id)


static func text_boxes(doc: Project, seq: Sequence, clip_ids: PackedStringArray) -> Array[Clip]:
	if doc == null or seq == null:
		return [] as Array[Clip]
	return Subtitles.sorted_text_clips(doc, seq, clip_ids)


static func character_of(c: Clip) -> String:
	if c == null:
		return ""
	return str(c.props.get(PROP_CHARACTER, ""))


static func kept_effects(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in c.effects:
		if str(e.get(ENTRY_MARK, "")).is_empty():
			out.append(e.duplicate(true))
	return out


static func fresh_entry(doc: Project, entry: Dictionary, owner_id: String) -> Dictionary:
	var ed: Dictionary = entry.duplicate(true)
	ed["uid"] = doc.mint_id("e")
	ed[ENTRY_MARK] = owner_id
	if not ed.has("enabled"):
		ed["enabled"] = true
	if not (ed.get("params") is Dictionary):
		ed["params"] = {}
	if not ed.has("group"):
		ed["group"] = ""
	if not ed.has("mask"):
		ed["mask"] = ""
	return ed


static func live_style(doc: Project, c: Clip) -> Dictionary:
	var m: MediaItem = doc.media_by_id(c.media_id)
	var media_props: Dictionary = m.props.duplicate(true) if m != null else {}
	return TitleStyle.full_style(media_props, c.props)


static func preview(doc: Project, seq: Sequence, preset: Dictionary, clip_ids: PackedStringArray, labels: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"ok": false, "name": "", "boxes": 0, "properties": 0, "changes": 0, "adds": PackedStringArray(), "removes": PackedStringArray(), "lines": PackedStringArray(), "text": ""}
	var p: Dictionary = normalize(preset)
	if p.is_empty():
		out["lines"] = PackedStringArray(["that is not a character preset"])
		out["text"] = "that is not a character preset"
		return out
	out["name"] = label_of(p)
	var boxes: Array[Clip] = text_boxes(doc, seq, clip_ids)
	out["boxes"] = boxes.size()
	var style: Dictionary = style_of(p)
	out["properties"] = style.size()
	var changed: Dictionary = {}
	var removes: PackedStringArray = PackedStringArray()
	for c: Clip in boxes:
		var now: Dictionary = live_style(doc, c)
		for k: Variant in style.keys():
			if str(now.get(k, null)) != str(style[k]):
				changed[String(k)] = true
		for e: Dictionary in c.effects:
			if not str(e.get(ENTRY_MARK, "")).is_empty():
				removes.append(effect_label(e, labels))
	out["changes"] = changed.size()
	var adds: PackedStringArray = PackedStringArray()
	for e2: Variant in effects_of(p):
		if e2 is Dictionary:
			adds.append(effect_label(e2, labels))
	out["adds"] = adds
	out["removes"] = removes
	out["ok"] = not boxes.is_empty()
	var lines: PackedStringArray = PackedStringArray()
	if boxes.is_empty():
		lines.append("no text boxes are selected, so there is nothing to apply it to")
	else:
		lines.append("%s goes on %d text %s" % [str(out["name"]), boxes.size(), "box" if boxes.size() == 1 else "boxes"])
		lines.append("%d style properties, %d of them change" % [int(out["properties"]), int(out["changes"])])
		if adds.is_empty():
			lines.append("it adds no effects")
		else:
			lines.append("it adds %d %s from the effects panel: %s" % [adds.size(), "effect" if adds.size() == 1 else "effects", ", ".join(adds)])
		if not removes.is_empty():
			lines.append("it takes off %d %s left by an earlier character preset: %s" % [removes.size(), "effect" if removes.size() == 1 else "effects", ", ".join(removes)])
		lines.append("all of it is one undo step")
	out["lines"] = lines
	out["text"] = "\n".join(lines)
	return out


static func apply(doc: Project, seq: Sequence, preset: Dictionary, clip_ids: PackedStringArray, with_effects: bool = true) -> bool:
	if doc == null or seq == null:
		return false
	var p: Dictionary = normalize(preset)
	if p.is_empty():
		return false
	var boxes: Array[Clip] = text_boxes(doc, seq, clip_ids)
	if boxes.is_empty():
		return false
	var style: Dictionary = style_of(p)
	var entries: Array = effects_of(p)
	var owner_id: String = str(p["id"])
	var cmds: Array[Command] = []
	for c: Clip in boxes:
		var props: Dictionary = c.props.duplicate(true)
		for k: Variant in style.keys():
			if String(k) != "text":
				props[String(k)] = style[k]
		props[PROP_CHARACTER] = owner_id
		cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "props", props))
		if not with_effects:
			continue
		var kept: Array[Dictionary] = kept_effects(c)
		var touched: bool = kept.size() != c.effects.size()
		for e: Variant in entries:
			if not (e is Dictionary):
				continue
			kept.append(fresh_entry(doc, e, owner_id))
			touched = true
		if touched:
			cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "effects", kept))
	if cmds.is_empty():
		return false
	return Verbs.run(doc, "Apply " + label_of(p), cmds)


static func clear_from(doc: Project, seq: Sequence, clip_ids: PackedStringArray) -> bool:
	if doc == null or seq == null:
		return false
	var cmds: Array[Command] = []
	for c: Clip in text_boxes(doc, seq, clip_ids):
		if character_of(c).is_empty() and kept_effects(c).size() == c.effects.size():
			continue
		var props: Dictionary = c.props.duplicate(true)
		props.erase(PROP_CHARACTER)
		cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "props", props))
		var kept: Array[Dictionary] = kept_effects(c)
		if kept.size() != c.effects.size():
			cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "effects", kept))
	if cmds.is_empty():
		return false
	return Verbs.run(doc, "Clear character", cmds)


static func save_to_user(preset: Dictionary) -> bool:
	var p: Dictionary = normalize(preset)
	if p.is_empty():
		return false
	if kind_registered():
		return Presets.save_to_user(p)
	return Io.save_preset(p) == OK


static func delete_user(id: String) -> bool:
	if id.is_empty():
		return false
	return Io.delete_user_preset(KIND, id)


static func save_to_project(doc: Project, preset: Dictionary) -> bool:
	var p: Dictionary = normalize(preset)
	if doc == null or p.is_empty():
		return false
	if kind_registered():
		return Presets.save_to_project(doc, p)
	var cmd: Command = EffectCmds.AddPreset.new(p)
	return Verbs.run(doc, cmd.label, [cmd])


static func remove_from_project(doc: Project, id: String) -> bool:
	if doc == null or id.is_empty():
		return false
	var cmd: Command = EffectCmds.RemovePreset.new(id)
	return Verbs.run(doc, cmd.label, [cmd])


static func save(doc: Project, preset: Dictionary, scope: String = "") -> bool:
	var want: String = scope if SCOPES.has(scope) else default_scope()
	if SCOPES.has(scope):
		set_default_scope(scope)
	if want == SCOPE_PROJECT:
		return save_to_project(doc, preset)
	return save_to_user(preset)


static func list_user() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Array[Dictionary] = Presets.list_user(KIND) if kind_registered() else Io.load_user_presets(KIND)
	for d: Dictionary in raw:
		var n: Dictionary = normalize(d)
		if not n.is_empty():
			out.append(n)
	return out


static func list_project(doc: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null:
		return out
	for p: Dictionary in doc.presets:
		var n: Dictionary = normalize(p)
		if not n.is_empty():
			out.append(n)
	return out


static func list_all(doc: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for p: Dictionary in list_user():
		seen[str(p.get("id", ""))] = true
		out.append(p)
	for p2: Dictionary in list_project(doc):
		if not seen.has(str(p2.get("id", ""))):
			out.append(p2)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return label_of(a).nocasecmp_to(label_of(b)) < 0)
	return out


static func project_only_ids(doc: Project) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for p: Dictionary in list_user():
		seen[str(p.get("id", ""))] = true
	for p2: Dictionary in list_project(doc):
		var id: String = str(p2.get("id", ""))
		if not seen.has(id):
			out.append(id)
	return out


static func find(doc: Project, id: String) -> Dictionary:
	for p: Dictionary in list_all(doc):
		if str(p.get("id", "")) == id:
			return p
	return {}

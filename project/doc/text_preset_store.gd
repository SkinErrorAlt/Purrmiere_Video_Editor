extends RefCounted

const Io := preload("res://doc/io.gd")
const Presets := preload("res://doc/presets.gd")
const Project := preload("res://doc/project.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const TextAnimators := preload("res://doc/text_animators.gd")
const TextPresets := preload("res://doc/text_presets.gd")
const KIND := "text_style"
const EVERYTHING := "Everything"
const GROUP_TAG := "group:"
const DEFAULT_GROUP := "My presets"
const PROJECT_GROUP := "This project"
const GROUPS_FILE := "text_preset_groups.json"
const NAME_MAX := 40

static var last_refusal: String = ""


static func groups_path() -> String:
	return Io.data_path(GROUPS_FILE)


static func clean_name(name_: String) -> String:
	var out: String = name_.strip_edges().replace("\n", " ").replace("\t", " ")
	while out.contains("  "):
		out = out.replace("  ", " ")
	if out.length() > NAME_MAX:
		out = out.substr(0, NAME_MAX).strip_edges()
	return out


static func normalize_groups(raw: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if raw is Array:
		for v: Variant in raw:
			var n: String = clean_name(String(v))
			if not n.is_empty() and not out.has(n):
				out.append(n)
	return out


static func load_groups() -> PackedStringArray:
	var d: Dictionary = Io.read_json(groups_path())
	var out: PackedStringArray = normalize_groups(d.get("groups", []))
	if out.is_empty():
		out.append(DEFAULT_GROUP)
	return out


static func save_groups(names: PackedStringArray) -> bool:
	var keep: PackedStringArray = normalize_groups(Array(names))
	if keep.is_empty():
		keep.append(DEFAULT_GROUP)
	return Io.write_atomic(groups_path(), JSON.stringify({"groups": Array(keep)}, "\t", false, true), false) == OK


static func reserved(name_: String) -> bool:
	var n: String = clean_name(name_)
	if n == EVERYTHING or n == PROJECT_GROUP:
		return true
	return TextPresets.groups().has(n)


static func add_group(name_: String) -> bool:
	var n: String = clean_name(name_)
	if n.is_empty():
		last_refusal = "a group needs a name"
		return false
	if reserved(n):
		last_refusal = n + " is the name of a group that ships with the editor"
		return false
	var names: PackedStringArray = load_groups()
	if names.has(n):
		last_refusal = "there is already a group called " + n
		return false
	names.append(n)
	return save_groups(names)


static func remove_group(name_: String) -> bool:
	var n: String = clean_name(name_)
	var names: PackedStringArray = load_groups()
	var at: int = names.find(n)
	if at < 0:
		return false
	names.remove_at(at)
	if not save_groups(names):
		return false
	for p: Dictionary in list_user():
		if group_of(p) == n:
			Presets.save_to_user(with_group(p, ""))
	return true


static func rename_group(was: String, now: String) -> bool:
	var a: String = clean_name(was)
	var b: String = clean_name(now)
	if a.is_empty() or b.is_empty() or a == b:
		last_refusal = "a group needs a new name of its own"
		return false
	if reserved(b):
		last_refusal = b + " is the name of a group that ships with the editor"
		return false
	var names: PackedStringArray = load_groups()
	var at: int = names.find(a)
	if at < 0:
		last_refusal = "there is no group called " + a
		return false
	if names.has(b):
		last_refusal = "there is already a group called " + b
		return false
	names[at] = b
	if not save_groups(names):
		return false
	for p: Dictionary in list_user():
		if group_of(p) == a:
			Presets.save_to_user(with_group(p, b))
	return true


static func group_of(preset: Dictionary) -> String:
	for t: Variant in preset.get("tags", []):
		var s: String = String(t)
		if s.begins_with(GROUP_TAG):
			return clean_name(s.substr(GROUP_TAG.length()))
	return ""


static func with_group(preset: Dictionary, group: String) -> Dictionary:
	var out: Dictionary = preset.duplicate(true)
	var tags: Array = []
	for t: Variant in preset.get("tags", []):
		if not String(t).begins_with(GROUP_TAG):
			tags.append(String(t))
	var n: String = clean_name(group)
	if not n.is_empty():
		tags.append(GROUP_TAG + n)
	out["tags"] = tags
	return out


static func animator_keys(props: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in props.keys():
		var s: String = String(k)
		if s == TextAnimators.COUNT_KEY or (s.begins_with("ta") and s.contains("_") and s.substr(2, s.find("_") - 2).is_valid_int()):
			out.append(s)
	return out


static func style_props(doc: Project, c: Clip) -> Dictionary:
	if c == null:
		return {}
	var m: MediaItem = doc.media_by_id(c.media_id) if doc != null else null
	var out: Dictionary = TitleStyle.full_style(m.props if m != null else {}, c.props)
	var merged: Dictionary = TitleStyle.merged("title", m.props if m != null else {}, c.props)
	for k: String in animator_keys(merged):
		var v: Variant = merged[k]
		out[k] = (v as Dictionary).duplicate(true) if v is Dictionary else ((v as Array).duplicate(true) if v is Array else v)
	out.erase("text")
	return out


static func made(doc: Project, c: Clip, label: String, group: String) -> Dictionary:
	var props: Dictionary = style_props(doc, c)
	if props.is_empty():
		last_refusal = "there is no title selected to take a preset from"
		return {}
	var name_: String = clean_name(label)
	if name_.is_empty():
		name_ = "Text preset"
	return with_group(Presets.make(KIND, name_, {"props": props}), group)


static func list_user() -> Array[Dictionary]:
	return Presets.list_user(KIND)


static func mine(doc: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for p: Dictionary in list_user():
		seen[String(p.get("id", ""))] = true
		out.append(p)
	if doc != null:
		for q: Dictionary in Presets.list_project(doc, KIND):
			if not seen.has(String(q.get("id", ""))):
				var row: Dictionary = q.duplicate(true)
				row["in_project"] = true
				out.append(row)
	return Presets.order(out)


static func group_label(preset: Dictionary) -> String:
	if bool(preset.get("in_project", false)):
		return PROJECT_GROUP
	var g: String = group_of(preset)
	return g if not g.is_empty() else DEFAULT_GROUP


static func my_groups(doc: Project) -> PackedStringArray:
	var out: PackedStringArray = load_groups()
	for p: Dictionary in mine(doc):
		var g: String = group_label(p)
		if not out.has(g):
			out.append(g)
	return out


static func in_group(doc: Project, group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in mine(doc):
		if group_label(p) == group:
			out.append(p)
	return out


static func props_of(preset: Dictionary) -> Dictionary:
	var payload: Variant = preset.get("payload", null)
	if not (payload is Dictionary):
		return {}
	var props: Variant = (payload as Dictionary).get("props", null)
	return (props as Dictionary).duplicate(true) if props is Dictionary else {}


static func carries_motion(preset: Dictionary) -> bool:
	return TextAnimators.count(props_of(preset)) > 0


static func trimmed(props: Dictionary, keep: int) -> Dictionary:
	var out: Dictionary = props.duplicate(true)
	for k: String in animator_keys(props):
		if k == TextAnimators.COUNT_KEY:
			continue
		var cut: int = k.find("_")
		if int(k.substr(2, cut - 2)) >= keep:
			out.erase(k)
	return out


static func applied_to(props: Dictionary, preset: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var mine_props: Dictionary = props_of(preset)
	if mine_props.is_empty():
		return props.duplicate(true)
	var out: Dictionary = props.duplicate(true)
	if bool(opts.get("replace_motion", false)):
		out = TextAnimators.strip(out)
	for k: Variant in mine_props.keys():
		if String(k) == "text":
			continue
		out[String(k)] = mine_props[k]
	if mine_props.has(TextAnimators.COUNT_KEY):
		out = trimmed(out, TextAnimators.count(mine_props))
	return out


static func renamed(preset: Dictionary, label: String) -> Dictionary:
	var out: Dictionary = preset.duplicate(true)
	var n: String = clean_name(label)
	if n.is_empty():
		return {}
	out["label"] = n
	return out


static func save(preset: Dictionary) -> bool:
	if not Presets.is_valid(preset):
		last_refusal = "that preset is not complete enough to save"
		return false
	return Presets.save_to_user(preset)


static func forget(preset: Dictionary) -> bool:
	if bool(preset.get("in_project", false)):
		last_refusal = "that preset lives in the project, remove it from the Presets panel"
		return false
	return Presets.delete_user(KIND, String(preset.get("id", "")))

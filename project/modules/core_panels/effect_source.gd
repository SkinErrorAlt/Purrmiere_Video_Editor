extends RefCounted

const REGISTRY_PATH := "res://engine/effect_registry.gd"
const AudioEffects := preload("res://engine/audio_effects.gd")
const Io := preload("res://doc/io.gd")
const LISTS_FILE := "effect_lists.json"
const RECENT_MAX := 12

static var _registry: RefCounted = null
static var _tried: bool = false
static var lists_path_override: String = ""
static var _lists: Dictionary = {}
static var _lists_from: String = ""


static func registry() -> RefCounted:
	if _registry != null:
		return _registry
	if _tried:
		return null
	_tried = true
	if not FileAccess.file_exists(REGISTRY_PATH):
		return null
	var script: Variant = load(REGISTRY_PATH)
	if script == null or not (script is GDScript) or not (script as GDScript).can_instantiate():
		return null
	var gd: GDScript = script
	var has_shared: bool = false
	for m: Dictionary in gd.get_script_method_list():
		if String(m.get("name", "")) == "shared":
			has_shared = true
	var inst: Variant = gd.call("shared") if has_shared else gd.new()
	if not (inst is RefCounted):
		return null
	_registry = inst
	if _registry.has_method("is_loaded") and not bool(_registry.call("is_loaded")) and _registry.has_method("load_all"):
		_registry.call("load_all")
	return _registry


static func available() -> bool:
	return registry() != null


static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r: RefCounted = registry()
	if r != null and r.has_method("list"):
		var raw: Variant = r.call("list")
		if typeof(raw) == TYPE_ARRAY:
			for d: Variant in raw:
				if typeof(d) == TYPE_DICTIONARY:
					out.append(d)
	out.append_array(AudioEffects.list())
	return out


static func audio_list() -> Array[Dictionary]:
	return AudioEffects.list()


static func is_audio(id: String) -> bool:
	return get_def(id).get("audio", false)


static func get_def(id: String) -> Dictionary:
	var r: RefCounted = registry()
	if r != null and r.has_method("get_def"):
		var raw: Variant = r.call("get_def", id)
		if typeof(raw) == TYPE_DICTIONARY and not (raw as Dictionary).is_empty():
			return raw
	return AudioEffects.get_def(id)


static func tags_of(def: Dictionary) -> PackedStringArray:
	var raw: Variant = def.get("tags", null)
	if raw is PackedStringArray:
		return raw
	var out: PackedStringArray = PackedStringArray()
	if typeof(raw) == TYPE_STRING:
		var one: String = String(raw).strip_edges().to_lower()
		if not one.is_empty():
			out.append(one)
		return out
	if typeof(raw) != TYPE_ARRAY:
		return out
	for t: Variant in raw:
		var tag: String = str(t).strip_edges().to_lower()
		if not tag.is_empty() and not out.has(tag):
			out.append(tag)
	out.sort()
	return out


static func has_tag(def: Dictionary, tag: String) -> bool:
	return tags_of(def).has(tag.strip_edges().to_lower())


static func all_tags() -> PackedStringArray:
	var seen: Dictionary = {}
	for d: Dictionary in list():
		for t: String in tags_of(d):
			seen[t] = true
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in seen.keys():
		out.append(String(k))
	out.sort()
	return out


static func ids_with_tag(tag: String) -> PackedStringArray:
	var want: String = tag.strip_edges().to_lower()
	var out: PackedStringArray = PackedStringArray()
	for d: Dictionary in list():
		if tags_of(d).has(want):
			out.append(String(d.get("id", "")))
	return out


static func media_kind(def: Dictionary) -> String:
	if bool(def.get("audio", false)):
		return "audio"
	var track: String = String(def.get("track", ""))
	if track == "audio":
		return "audio"
	return "video"


static func has_handles(def: Dictionary) -> bool:
	var raw: Variant = def.get("handles", null)
	return raw is Array and not (raw as Array).is_empty()


static func is_user_made(def: Dictionary) -> bool:
	var source: String = String(def.get("source", ""))
	return source == "user" or source == "project" or bool(def.get("embedded", false))


static func user_root() -> String:
	var r: RefCounted = registry()
	if r == null:
		return "user://effects/"
	return String(r.call("user_root"))


static func user_stamp() -> String:
	var r: RefCounted = registry()
	if r == null:
		return ""
	return String(r.call("user_stamp"))


static func reload_effects() -> void:
	reload()


static func reload() -> void:
	var r: RefCounted = registry()
	if r == null:
		_tried = false
		registry()
		return
	if r.has_method("reload"):
		r.call("reload")
	elif r.has_method("load_all"):
		r.call("load_all")


static func enum_writes(id: String, key: String, index: int) -> Dictionary:
	var r: RefCounted = registry()
	if r == null or not r.has_method("enum_writes"):
		return {}
	var raw: Variant = r.call("enum_writes", id, key, index)
	if typeof(raw) == TYPE_DICTIONARY:
		return raw
	return {}


static func param_specs(def: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Variant in def.get("params", []):
		if typeof(p) == TYPE_DICTIONARY and not bool((p as Dictionary).get("hidden", false)):
			out.append(p)
	return out


static func lists_path() -> String:
	if not lists_path_override.is_empty():
		return lists_path_override
	return Io.data_path(LISTS_FILE)


static func lists() -> Dictionary:
	var path: String = lists_path()
	if _lists_from != path:
		_lists_from = path
		_lists = Io.read_json(path)
	return _lists


static func _save_lists() -> void:
	var err: Error = Io.write_atomic(lists_path(), JSON.stringify(_lists, " "), false)
	if err != OK:
		print("EffectSource: could not save the effect lists, " + Io.last_error)


static func _ids(key: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var raw: Variant = lists().get(key, [])
	if raw is Array:
		for v: Variant in raw:
			out.append(str(v))
	return out


static func favourites() -> PackedStringArray:
	return _ids("favourites")


static func is_favourite(id: String) -> bool:
	return favourites().has(id)


static func set_favourite(id: String, on: bool) -> void:
	var favs: PackedStringArray = favourites()
	var at: int = favs.find(id)
	if on and at < 0:
		favs.append(id)
	elif not on and at >= 0:
		favs.remove_at(at)
	else:
		return
	lists()["favourites"] = Array(favs)
	_save_lists()


static func recent() -> PackedStringArray:
	return _ids("recent")


static func note_used(id: String) -> void:
	if id.is_empty():
		return
	var ids: PackedStringArray = recent()
	var at: int = ids.find(id)
	if at == 0:
		return
	if at > 0:
		ids.remove_at(at)
	ids.insert(0, id)
	while ids.size() > RECENT_MAX:
		ids.remove_at(ids.size() - 1)
	lists()["recent"] = Array(ids)
	_save_lists()


static func paste_choice() -> Dictionary:
	var raw: Variant = lists().get("paste", {})
	return raw if raw is Dictionary else {}


static func set_paste_choice(choice: Dictionary) -> void:
	lists()["paste"] = choice.duplicate(true)
	_save_lists()


static func audio_group(def: Dictionary) -> String:
	var g: String = String(def.get("group", ""))
	return g if not g.is_empty() else "Other"

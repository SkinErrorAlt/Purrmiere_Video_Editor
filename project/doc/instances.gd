extends RefCounted

const Io := preload("res://doc/io.gd")
const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const FILE := "library.json"
const VERSION := 1
const KINDS: PackedStringArray = ["video", "audio", "image", "gif", "font", "text", "preset", "sequence", "other"]
const IMAGE_EXT: PackedStringArray = ["png", "jpg", "jpeg", "webp", "bmp", "tga", "tif", "tiff", "exr", "svg"]
const AUDIO_EXT: PackedStringArray = ["wav", "mp3", "flac", "ogg", "aac", "m4a", "opus", "aiff", "wma"]
const FONT_EXT: PackedStringArray = ["ttf", "otf", "woff", "woff2"]
const TEXT_EXT: PackedStringArray = ["txt", "srt", "md"]
const PRESET_EXT: PackedStringArray = ["json"]
const SEQUENCE_EXT: PackedStringArray = ["purrmiere", "gz"]

static var _cache: Dictionary = {}
static var _loaded: bool = false
static var _override_path: String = ""


static func path() -> String:
	if not _override_path.is_empty():
		return _override_path
	return Io.data_path("instances").path_join(FILE)


static func use_path(p: String) -> void:
	_override_path = p
	_loaded = false
	_cache = {}


static func empty() -> Dictionary:
	return {"version": VERSION, "items": [], "groups": []}


static func library() -> Dictionary:
	if _loaded:
		return _cache
	var d: Dictionary = Io.read_json(path())
	if d.is_empty() or not (d.get("items") is Array) or not (d.get("groups") is Array):
		d = empty()
	_cache = d
	_loaded = true
	return _cache


static func save() -> bool:
	var d: Dictionary = library()
	d["version"] = VERSION
	DirAccess.make_dir_recursive_absolute(path().get_base_dir())
	return Io.write_atomic(path(), JSON.stringify(d, "\t", false, true), false) == OK


static func reread() -> void:
	_loaded = false
	_cache = {}


static func kind_for(p: String) -> String:
	var ext: String = p.get_extension().to_lower()
	if ext == "gif":
		return "gif"
	if IMAGE_EXT.has(ext):
		return "image"
	if AUDIO_EXT.has(ext):
		return "audio"
	if FONT_EXT.has(ext):
		return "font"
	if TEXT_EXT.has(ext):
		return "text"
	if PRESET_EXT.has(ext):
		return "preset"
	if SEQUENCE_EXT.has(ext):
		return "sequence"
	if ["mp4", "mov", "mkv", "webm", "avi", "m4v", "mts", "m2ts", "ts", "flv", "wmv", "mxf", "mpg", "mpeg", "3gp", "ogv"].has(ext):
		return "video"
	return "other"


static func importable(kind: String) -> bool:
	return kind == "video" or kind == "audio" or kind == "image" or kind == "gif"


static func mint(prefix: String) -> String:
	return prefix + "_" + str(Time.get_unix_time_from_system()).replace(".", "") + "_" + str(randi() % 1000000)


static func items() -> Array:
	return library()["items"]


static func groups() -> Array:
	return library()["groups"]


static func item_by_id(id: String) -> Dictionary:
	for it: Dictionary in items():
		if String(it.get("id", "")) == id:
			return it
	return {}


static func item_by_path(p: String) -> Dictionary:
	for it: Dictionary in items():
		if String(it.get("path", "")) == p:
			return it
	return {}


static func group_by_id(id: String) -> Dictionary:
	for g: Dictionary in groups():
		if String(g.get("id", "")) == id:
			return g
	return {}


static func group_by_name(name_: String) -> Dictionary:
	for g: Dictionary in groups():
		if String(g.get("name", "")).to_lower() == name_.to_lower():
			return g
	return {}


static func add_path(p: String, group: String = "", tags: PackedStringArray = PackedStringArray()) -> Dictionary:
	if p.is_empty():
		return {}
	var existing: Dictionary = item_by_path(p)
	if not existing.is_empty():
		var changed: bool = false
		if not group.is_empty() and String(existing.get("group", "")) != group:
			existing["group"] = group
			changed = true
		for t: String in tags:
			if not (existing["tags"] as Array).has(t):
				(existing["tags"] as Array).append(t)
				changed = true
		if changed:
			save()
		return existing
	var it: Dictionary = {
		"id": mint("i"),
		"path": p,
		"label": p.get_file().get_basename(),
		"kind": kind_for(p),
		"tags": Array(tags),
		"group": group,
		"thumb": "",
		"added": Time.get_datetime_string_from_system(true),
	}
	(library()["items"] as Array).append(it)
	save()
	return it


static func add_paths(paths: PackedStringArray, group: String = "", tags: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for p: String in paths:
		var it: Dictionary = add_path(p, group, tags)
		if not it.is_empty():
			out.append(String(it["id"]))
	return out


static func add_folder(folder: String, group: String = "", tags: PackedStringArray = PackedStringArray(), cap: int = 2000) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var stack: PackedStringArray = PackedStringArray([folder])
	while not stack.is_empty() and out.size() < cap:
		var cur: String = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var dir: DirAccess = DirAccess.open(cur)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while not entry.is_empty() and out.size() < cap:
			if entry.begins_with("."):
				entry = dir.get_next()
				continue
			var full: String = cur.path_join(entry)
			if dir.current_is_dir():
				stack.append(full)
			elif kind_for(full) != "other":
				var it: Dictionary = add_path(full, group, tags)
				if not it.is_empty():
					out.append(String(it["id"]))
			entry = dir.get_next()
		dir.list_dir_end()
	return out


static func set_field(id: String, key: String, value: Variant) -> bool:
	var it: Dictionary = item_by_id(id)
	if it.is_empty() or not ["label", "tags", "group", "thumb", "kind"].has(key):
		return false
	if key == "tags":
		var arr: Array = []
		for t: Variant in value:
			var s: String = String(t).strip_edges()
			if not s.is_empty() and not arr.has(s):
				arr.append(s)
		it["tags"] = arr
	else:
		it[key] = value
	return save()


static func add_tag(id: String, tag: String) -> bool:
	var it: Dictionary = item_by_id(id)
	tag = tag.strip_edges()
	if it.is_empty() or tag.is_empty():
		return false
	if (it["tags"] as Array).has(tag):
		return true
	(it["tags"] as Array).append(tag)
	return save()


static func remove_tag(id: String, tag: String) -> bool:
	var it: Dictionary = item_by_id(id)
	if it.is_empty():
		return false
	(it["tags"] as Array).erase(tag)
	return save()


static func remove(id: String) -> bool:
	var list: Array = items()
	for i: int in list.size():
		if String((list[i] as Dictionary).get("id", "")) == id:
			list.remove_at(i)
			return save()
	return false


static func add_group(name_: String, auto_import: bool = false, parent: String = "") -> Dictionary:
	name_ = name_.strip_edges()
	if name_.is_empty():
		return {}
	var existing: Dictionary = group_by_name(name_)
	if not existing.is_empty():
		return existing
	var g: Dictionary = {"id": mint("g"), "name": name_, "auto_import": auto_import, "parent": parent}
	(library()["groups"] as Array).append(g)
	save()
	return g


static func set_group_field(id: String, key: String, value: Variant) -> bool:
	var g: Dictionary = group_by_id(id)
	if g.is_empty() or not ["name", "auto_import", "parent"].has(key):
		return false
	g[key] = value
	return save()


static func remove_group(id: String, keep_items: bool = true) -> bool:
	var list: Array = groups()
	var found: bool = false
	for i: int in list.size():
		if String((list[i] as Dictionary).get("id", "")) == id:
			list.remove_at(i)
			found = true
			break
	if not found:
		return false
	var its: Array = items()
	for i2: int in range(its.size() - 1, -1, -1):
		var it: Dictionary = its[i2]
		if String(it.get("group", "")) == id:
			if keep_items:
				it["group"] = ""
			else:
				its.remove_at(i2)
	for g: Dictionary in list:
		if String(g.get("parent", "")) == id:
			g["parent"] = ""
	return save()


static func all_tags() -> PackedStringArray:
	var seen: Dictionary = {}
	for it: Dictionary in items():
		for t: Variant in it.get("tags", []):
			seen[String(t)] = true
	var out: PackedStringArray = PackedStringArray(seen.keys())
	out.sort()
	return out


static func by_tag(tag: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Dictionary in items():
		if (it.get("tags", []) as Array).has(tag):
			out.append(it)
	return out


static func by_group(group: String, deep: bool = true) -> Array[Dictionary]:
	var ids: Dictionary = {group: true}
	if deep:
		var grew: bool = true
		while grew:
			grew = false
			for g: Dictionary in groups():
				var pid: String = String(g.get("parent", ""))
				var gid: String = String(g.get("id", ""))
				if ids.has(pid) and not ids.has(gid):
					ids[gid] = true
					grew = true
	var out: Array[Dictionary] = []
	for it: Dictionary in items():
		if ids.has(String(it.get("group", ""))):
			out.append(it)
	return out


static func by_kind(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Dictionary in items():
		if String(it.get("kind", "")) == kind:
			out.append(it)
	return out


static func search(text: String) -> Array[Dictionary]:
	var q: String = text.strip_edges().to_lower()
	var out: Array[Dictionary] = []
	for it: Dictionary in items():
		if q.is_empty():
			out.append(it)
			continue
		var hay: String = (String(it.get("label", "")) + " " + String(it.get("path", "")) + " " + " ".join(PackedStringArray(it.get("tags", [])))).to_lower()
		if hay.contains(q):
			out.append(it)
	return out


static func auto_import_groups() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Dictionary in groups():
		if bool(g.get("auto_import", false)):
			out.append(g)
	return out


static func paths_for_new_project() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for g: Dictionary in auto_import_groups():
		for it: Dictionary in by_group(String(g["id"]), true):
			var p: String = String(it.get("path", ""))
			if seen.has(p) or not importable(String(it.get("kind", ""))):
				continue
			seen[p] = true
			out.append({"path": p, "bin": String(g.get("name", "")), "item": it})
	return out


static func entries_for(list: Array[Dictionary], bin: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Dictionary in list:
		if importable(String(it.get("kind", ""))):
			out.append({"path": String(it.get("path", "")), "bin": bin, "label": String(it.get("label", ""))})
	return out


static func missing(it: Dictionary) -> bool:
	return not FileAccess.file_exists(String(it.get("path", "")))


static func group_path(id: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var cur: String = id
	var guard: int = 0
	while not cur.is_empty() and guard < 32:
		var g: Dictionary = group_by_id(cur)
		if g.is_empty():
			break
		parts.insert(0, String(g.get("name", "")))
		cur = String(g.get("parent", ""))
		guard += 1
	return "/".join(parts)

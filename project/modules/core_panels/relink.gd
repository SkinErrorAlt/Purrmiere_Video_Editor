extends RefCounted

const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const MediaLoader := preload("res://modules/core_panels/media_loader.gd")
const FILE_CAP := 200000
const HOW_TEXT: Dictionary = {
	"layout": "Found by folder layout",
	"name": "Found by name",
	"name_folder": "Found by name and folder",
	"ambiguous": "More than one match, left alone",
	"none": "Not found",
	"": "Missing",
}


static func norm(p: String) -> String:
	return p.replace("\\", "/")


static func missing_items(doc: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null:
		return out
	for m: MediaItem in doc.media:
		if m.kind == "sequence" or m.path.is_empty():
			continue
		m.missing = not FileAccess.file_exists(m.path)
		if m.missing:
			out.append({"id": m.id, "label": m.label, "path": m.path})
	return out


static func scan(folder: String, cap: int = FILE_CAP) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var stack: PackedStringArray = PackedStringArray([norm(folder).trim_suffix("/")])
	while not stack.is_empty() and out.size() < cap:
		var dir_path: String = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.include_hidden = false
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while not entry.is_empty():
			if not entry.begins_with("."):
				var full: String = dir_path.path_join(entry)
				if dir.current_is_dir():
					stack.append(full)
				else:
					out.append(full)
					if out.size() >= cap:
						break
			entry = dir.get_next()
		dir.list_dir_end()
	return out


static func plan(missing: Array[Dictionary], files: PackedStringArray, folder: String) -> Array[Dictionary]:
	var root: String = norm(folder).trim_suffix("/")
	var have: Dictionary = {}
	var by_name: Dictionary = {}
	for f: String in files:
		var n: String = norm(f)
		have[n.to_lower()] = n
		var key: String = n.get_file().to_lower()
		if not by_name.has(key):
			by_name[key] = PackedStringArray()
		var bucket: PackedStringArray = by_name[key]
		bucket.append(n)
		by_name[key] = bucket
	var out: Array[Dictionary] = []
	for m: Dictionary in missing:
		var old: String = norm(String(m.get("path", "")))
		var parts: PackedStringArray = old.split("/", false)
		var r: Dictionary = {"id": String(m.get("id", "")), "label": String(m.get("label", "")), "old": String(m.get("path", "")), "new": "", "how": "none", "note": ""}
		var k: int = parts.size() - 1
		while k >= 2:
			var tail: String = "/".join(parts.slice(parts.size() - k))
			var cand: String = (root + "/" + tail).to_lower()
			if have.has(cand):
				r["new"] = have[cand]
				r["how"] = "layout"
				break
			k -= 1
		if String(r["new"]).is_empty():
			var name_: String = old.get_file().to_lower()
			var hits: PackedStringArray = by_name.get(name_, PackedStringArray())
			if hits.size() == 1:
				r["new"] = hits[0]
				r["how"] = "name"
			elif hits.size() > 1:
				var parent: String = parts[parts.size() - 2].to_lower() if parts.size() >= 2 else ""
				var narrowed: PackedStringArray = PackedStringArray()
				for h: String in hits:
					if h.get_base_dir().get_file().to_lower() == parent:
						narrowed.append(h)
				if narrowed.size() == 1:
					r["new"] = narrowed[0]
					r["how"] = "name_folder"
				else:
					r["how"] = "ambiguous"
					r["note"] = str(hits.size()) + " files share this name"
		out.append(r)
	return out


static func merge(previous: Array[Dictionary], fresh: Array[Dictionary]) -> Array[Dictionary]:
	var found: Dictionary = {}
	for p: Dictionary in previous:
		if not String(p.get("new", "")).is_empty():
			found[String(p["id"])] = p
	var out: Array[Dictionary] = []
	for f: Dictionary in fresh:
		if String(f.get("new", "")).is_empty() and found.has(String(f["id"])):
			out.append(found[String(f["id"])])
		else:
			out.append(f)
	return out


static func found_count(p: Array[Dictionary]) -> int:
	var n: int = 0
	for r: Dictionary in p:
		if not String(r.get("new", "")).is_empty():
			n += 1
	return n


static func how_text(how: String) -> String:
	return String(HOW_TEXT.get(how, how))


static func apply(doc: Project, p: Array[Dictionary]) -> int:
	if doc == null:
		return 0
	var cmds: Array[Command] = []
	for r: Dictionary in p:
		var new_path: String = String(r.get("new", ""))
		var id: String = String(r.get("id", ""))
		var m: MediaItem = doc.media_by_id(id)
		if new_path.is_empty() or m == null or m.path == new_path:
			continue
		cmds.append(RelinkCmd.new(id, new_path))
	if cmds.is_empty():
		return 0
	var label: String = "Relink " + str(cmds.size()) + (" file" if cmds.size() == 1 else " files")
	if not Verbs.run(doc, label, cmds):
		return 0
	return cmds.size()


static func reopen(doc: Project, m: MediaItem) -> void:
	if m == null:
		return
	m.missing = not FileAccess.file_exists(m.path)
	var h: Variant = Session.media_handles.get(m.id, -1)
	if typeof(h) == TYPE_INT and int(h) >= 0:
		var shared: bool = false
		for other: MediaItem in doc.media:
			if other != m and Session.media_handles.get(other.id, -1) == h:
				shared = true
				break
		if not shared:
			PurrBridge.close_media(int(h))
		Session.media_handles.erase(m.id)
	m.handle = -1
	if not m.missing and doc == Session.doc:
		MediaLoader.instance().open_item(doc, m)


class RelinkCmd extends "res://doc/commands/command.gd":
	const RelinkScript := preload("res://modules/core_panels/relink.gd")
	var media_id: String = ""
	var new_path: String = ""
	var old_path: String = ""

	func _init(p_media_id: String, p_new_path: String) -> void:
		label = "Relink"
		media_id = p_media_id
		new_path = p_new_path

	func _set_path(doc: Project, path: String) -> void:
		var m: MediaItem = doc.media_by_id(media_id)
		if m == null:
			ok = false
			return
		m.path = path
		RelinkScript.reopen(doc, m)
		doc.touch("media")

	func do(doc: Project) -> void:
		var m: MediaItem = doc.media_by_id(media_id)
		if m == null:
			ok = false
			return
		old_path = m.path
		_set_path(doc, new_path)

	func undo(doc: Project) -> void:
		_set_path(doc, old_path)

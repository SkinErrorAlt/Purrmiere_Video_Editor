extends RefCounted

const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const KIND := "asset_pack"
const LOADER_PATH := "res://modules/core_panels/media_loader.gd"
const MAX_ITEMS := 2000
const NAMED_IN_NOTE := 4
const FILE_KINDS: PackedStringArray = ["video", "audio", "image"]

static var _loader: GDScript = null
static var _library_version: int = 0


static func library_version() -> int:
	return _library_version


static func bump_library() -> void:
	_library_version += 1


static func loader_script() -> GDScript:
	if _loader == null:
		_loader = load(LOADER_PATH)
	return _loader


static func media_kind(path: String) -> String:
	var s: GDScript = loader_script()
	if s == null:
		return ""
	return String(s.call("kind_for", path))


static func path_key(path: String) -> String:
	var key: String = path.replace("\\", "/").simplify_path()
	if OS.get_name() == "Windows":
		key = key.to_lower()
	return key


static func clean_bin(bin: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for raw: String in bin.replace("\\", "/").split("/"):
		var one: String = raw.strip_edges()
		if not one.is_empty():
			parts.append(one)
	return "/".join(parts)


static func join_bin(head: String, tail: String) -> String:
	var a: String = clean_bin(head)
	var b: String = clean_bin(tail)
	if a.is_empty():
		return b
	if b.is_empty():
		return a
	return a + "/" + b


static func sub_under(root: String, bin: String) -> String:
	var r: String = clean_bin(root)
	var b: String = clean_bin(bin)
	if r.is_empty() or b == r:
		return ""
	if b.begins_with(r + "/"):
		return b.substr(r.length() + 1)
	return ""


static func common_bin(doc: Project, media_ids: PackedStringArray) -> String:
	if doc == null:
		return ""
	var shared: PackedStringArray = PackedStringArray()
	var first: bool = true
	for id: String in media_ids:
		var m: MediaItem = doc.media_by_id(id)
		if m == null or m.kind == "sequence" or m.path.strip_edges().is_empty():
			continue
		var parts: PackedStringArray = PackedStringArray()
		var tidy: String = clean_bin(m.bin)
		if not tidy.is_empty():
			parts = tidy.split("/")
		if first:
			first = false
			shared = parts
			continue
		var keep: PackedStringArray = PackedStringArray()
		for i: int in mini(shared.size(), parts.size()):
			if shared[i] != parts[i]:
				break
			keep.append(shared[i])
		shared = keep
		if shared.is_empty():
			break
	return "/".join(shared)


static func common_dir(doc: Project, media_ids: PackedStringArray) -> String:
	if doc == null:
		return ""
	var shared: PackedStringArray = PackedStringArray()
	var first: bool = true
	for id: String in media_ids:
		var m: MediaItem = doc.media_by_id(id)
		if m == null or m.kind == "sequence" or m.path.strip_edges().is_empty():
			continue
		var dir: String = m.path.replace("\\", "/").get_base_dir()
		var parts: PackedStringArray = PackedStringArray()
		if not dir.is_empty():
			parts = dir.split("/")
		if first:
			first = false
			shared = parts
			continue
		var keep: PackedStringArray = PackedStringArray()
		for i: int in mini(shared.size(), parts.size()):
			if path_key(shared[i]) != path_key(parts[i]):
				break
			keep.append(shared[i])
		shared = keep
		if shared.is_empty():
			break
	if shared.size() < 2:
		return ""
	return "/".join(shared)


static func clean_item(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	var path: String = String(d.get("path", "")).strip_edges()
	if path.is_empty():
		return {}
	var label: String = String(d.get("label", "")).strip_edges()
	if label.is_empty():
		label = path.get_file()
	return {
		"path": path,
		"label": label,
		"sub": clean_bin(String(d.get("sub", ""))),
		"modified": maxi(int(d.get("modified", 0)), 0),
		"from": String(d.get("from", "")).strip_edges(),
	}


static func clean_items(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (raw is Array):
		return out
	var seen: Dictionary = {}
	for e: Variant in (raw as Array):
		if out.size() >= MAX_ITEMS:
			break
		var one: Dictionary = clean_item(e)
		if one.is_empty():
			continue
		var key: String = path_key(String(one["path"]))
		if seen.has(key):
			continue
		seen[key] = true
		out.append(one)
	return out


static func folder_entry(path: String, deep: bool = true, keep_tree: bool = true, kinds: PackedStringArray = PackedStringArray()) -> Dictionary:
	return clean_folder({"path": path, "deep": deep, "keep_tree": keep_tree, "kinds": kinds})


static func clean_folder(raw: Variant) -> Dictionary:
	var d: Dictionary = {}
	if raw is String:
		d = {"path": raw}
	elif raw is Dictionary:
		d = raw
	else:
		return {}
	var path: String = String(d.get("path", "")).strip_edges().replace("\\", "/")
	while path.length() > 1 and path.ends_with("/"):
		path = path.substr(0, path.length() - 1)
	if path.is_empty():
		return {}
	var kinds: PackedStringArray = PackedStringArray()
	var raw_kinds: Variant = d.get("kinds", [])
	var listed: Array = []
	if raw_kinds is PackedStringArray:
		listed = Array(raw_kinds as PackedStringArray)
	elif raw_kinds is Array:
		listed = raw_kinds
	for k: Variant in listed:
		var one: String = String(k).strip_edges().to_lower()
		if FILE_KINDS.has(one) and not kinds.has(one):
			kinds.append(one)
	return {"path": path, "deep": bool(d.get("deep", true)), "keep_tree": bool(d.get("keep_tree", true)), "kinds": kinds}


static func clean_folders(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (raw is Array):
		return out
	var seen: Dictionary = {}
	for e: Variant in (raw as Array):
		var one: Dictionary = clean_folder(e)
		if one.is_empty():
			continue
		var key: String = path_key(String(one["path"]))
		if seen.has(key):
			continue
		seen[key] = true
		out.append(one)
	return out


static func payload(items: Array, bin: String, import_at_once: bool, opts: Dictionary = {}) -> Dictionary:
	return {
		"items": clean_items(items),
		"bin": clean_bin(bin),
		"import_at_once": import_at_once,
		"folders": clean_folders(opts.get("folders", [])),
		"follow": bool(opts.get("follow", false)),
	}


static func payload_from(doc: Project, media_ids: PackedStringArray, bin: String, import_at_once: bool, opts: Dictionary = {}) -> Dictionary:
	var items: Array = []
	var root: String = clean_bin(String(opts.get("root_bin", ""))) if opts.has("root_bin") else common_bin(doc, media_ids)
	if doc != null:
		for id: String in media_ids:
			var m: MediaItem = doc.media_by_id(id)
			if m == null or m.kind == "sequence" or m.path.strip_edges().is_empty():
				continue
			items.append({"path": m.path, "label": m.label, "sub": sub_under(root, m.bin), "modified": stamp_of(m.path)})
	var folders: Array[Dictionary] = clean_folders(opts.get("folders", []))
	if not folders.is_empty():
		items.append_array(scan_folders(folders, MAX_ITEMS - items.size())["items"])
	var full: Dictionary = opts.duplicate(true)
	full["folders"] = folders
	return payload(items, bin, import_at_once, full)


static func stamp_of(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	return maxi(int(FileAccess.get_modified_time(path)), 0)


static func suggested_bin(doc: Project, media_ids: PackedStringArray) -> String:
	return common_bin(doc, media_ids)


static func payload_of(pack: Dictionary) -> Dictionary:
	if not (pack.get("payload") is Dictionary):
		return {}
	return pack["payload"]


static func is_pack(pack: Dictionary) -> bool:
	return String(pack.get("kind", "")) == KIND and pack.get("payload") is Dictionary


static func items_of(pack: Dictionary) -> Array[Dictionary]:
	return clean_items(payload_of(pack).get("items", []))


static func folders_of(pack: Dictionary) -> Array[Dictionary]:
	return clean_folders(payload_of(pack).get("folders", []))


static func bin_of(pack: Dictionary) -> String:
	return clean_bin(String(payload_of(pack).get("bin", "")))


static func import_at_once_of(pack: Dictionary) -> bool:
	var p: Dictionary = payload_of(pack)
	if p.has("import_at_once"):
		return bool(p["import_at_once"])
	return bool(p.get("auto_import", false))


static func follows(pack: Dictionary) -> bool:
	return bool(payload_of(pack).get("follow", false)) and not folders_of(pack).is_empty()


static func label_of(pack: Dictionary) -> String:
	var label: String = String(pack.get("label", "")).strip_edges()
	return label if not label.is_empty() else "Unnamed package"


static func folder_names(pack: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for f: Dictionary in folders_of(pack):
		var p: String = String(f["path"])
		var leaf: String = p.get_file()
		out.append(leaf if not leaf.is_empty() else p)
	return out


static func kind_taken(path: String, kinds: PackedStringArray) -> bool:
	var k: String = media_kind(path)
	if k.is_empty():
		return false
	return kinds.is_empty() or kinds.has(k)


static func scan_folder(folder: Dictionary, budget: int) -> Dictionary:
	var out: Array[Dictionary] = []
	var res: Dictionary = {"items": out, "ok": false, "capped": false}
	var root: String = String(folder.get("path", ""))
	if root.is_empty() or not DirAccess.dir_exists_absolute(root):
		return res
	res["ok"] = true
	if budget <= 0:
		res["capped"] = true
		return res
	var deep: bool = bool(folder.get("deep", true))
	var keep_tree: bool = bool(folder.get("keep_tree", true))
	var kinds: PackedStringArray = PackedStringArray(folder.get("kinds", []))
	var stack: Array = [[root, ""]]
	while not stack.is_empty():
		var top: Array = stack.pop_back()
		var dir_path: String = String(top[0])
		var sub: String = String(top[1])
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.include_hidden = false
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		var subs: Array = []
		while not entry.is_empty():
			if entry.begins_with("."):
				entry = dir.get_next()
				continue
			var full: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				if deep:
					subs.append([full, (sub + "/" + entry) if not sub.is_empty() else entry])
			elif kind_taken(full, kinds):
				if out.size() >= budget:
					res["capped"] = true
				else:
					out.append({"path": full, "label": entry.get_basename(), "sub": sub if keep_tree else "", "modified": stamp_of(full), "from": root})
			entry = dir.get_next()
		dir.list_dir_end()
		subs.sort_custom(func(a: Array, b: Array) -> bool: return String(a[0]) > String(b[0]))
		for one: Array in subs:
			stack.append(one)
	res["items"] = out
	return res


static func scan_folders(folders: Array[Dictionary], budget: int) -> Dictionary:
	var items: Array[Dictionary] = []
	var away: PackedStringArray = PackedStringArray()
	var capped: bool = false
	for f: Dictionary in folders:
		var one: Dictionary = scan_folder(f, budget - items.size())
		if not bool(one["ok"]):
			away.append(String(f["path"]))
			continue
		if bool(one["capped"]):
			capped = true
		for it: Dictionary in (one["items"] as Array[Dictionary]):
			items.append(it)
	return {"items": items, "away": away, "capped": capped}


static func scan_pack(pack: Dictionary) -> Dictionary:
	var res: Dictionary = scan_folders(folders_of(pack), MAX_ITEMS)
	res["when"] = Time.get_ticks_msec()
	return res


static func frozen_view(pack: Dictionary) -> Dictionary:
	var none: Array[Dictionary] = []
	return {
		"items": items_of(pack),
		"away": PackedStringArray(),
		"capped": false,
		"added": none.duplicate(),
		"changed": none.duplicate(),
		"gone": none.duplicate(),
		"scanned": false,
	}


static func view(pack: Dictionary, scan: Dictionary = {}, may_scan: bool = true) -> Dictionary:
	if not follows(pack):
		return frozen_view(pack)
	var use: Dictionary = scan
	if not use.has("items"):
		if not may_scan:
			return frozen_view(pack)
		use = scan_pack(pack)
	var base: Array[Dictionary] = items_of(pack)
	var away: PackedStringArray = use.get("away", PackedStringArray())
	var away_keys: Dictionary = {}
	for a: String in away:
		away_keys[path_key(a)] = true
	var base_by: Dictionary = {}
	for it: Dictionary in base:
		base_by[path_key(String(it["path"]))] = it
	var live: Array[Dictionary] = []
	var seen: Dictionary = {}
	for it: Dictionary in base:
		var from: String = String(it["from"])
		if not from.is_empty() and not away_keys.has(path_key(from)):
			continue
		var key: String = path_key(String(it["path"]))
		if seen.has(key):
			continue
		seen[key] = true
		live.append(it)
	var added: Array[Dictionary] = []
	var changed: Array[Dictionary] = []
	var capped: bool = bool(use.get("capped", false))
	for it: Dictionary in (use["items"] as Array):
		var key2: String = path_key(String(it["path"]))
		if seen.has(key2):
			continue
		if live.size() >= MAX_ITEMS:
			capped = true
			break
		seen[key2] = true
		live.append(it)
		if not base_by.has(key2):
			added.append(it)
			continue
		var was: Dictionary = base_by[key2]
		var then: int = int(was.get("modified", 0))
		if then > 0 and int(it.get("modified", 0)) != then:
			changed.append(it)
	var gone: Array[Dictionary] = []
	for it: Dictionary in base:
		var from2: String = String(it["from"])
		if from2.is_empty() or away_keys.has(path_key(from2)):
			continue
		if not seen.has(path_key(String(it["path"]))):
			gone.append(it)
	return {"items": live, "away": away, "capped": capped, "added": added, "changed": changed, "gone": gone, "scanned": true}


static func items_for(pack: Dictionary, v: Dictionary) -> Array[Dictionary]:
	if v.has("items"):
		var raw: Array[Dictionary] = []
		for it: Variant in (v["items"] as Array):
			raw.append(it as Dictionary)
		return raw
	return items_of(pack)


static func refreshed(pack: Dictionary, v: Dictionary) -> Dictionary:
	var out: Dictionary = pack.duplicate(true)
	if not (out.get("payload") is Dictionary):
		return out
	var p: Dictionary = out["payload"]
	p["items"] = Array(items_for(pack, v))
	out["payload"] = p
	return out


static func every_path(pack: Dictionary, v: Dictionary = {}) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for it: Dictionary in items_for(pack, v):
		out.append(String(it["path"]))
	return out


static func file_there(path: String) -> bool:
	return not path.strip_edges().is_empty() and FileAccess.file_exists(path)


static func check_items(items: Array[Dictionary]) -> Dictionary:
	var found: Array[Dictionary] = []
	var missing: Array[Dictionary] = []
	for it: Dictionary in items:
		if file_there(String(it["path"])):
			found.append(it)
		else:
			missing.append(it)
	return {"found": found, "missing": missing}


static func check(pack: Dictionary, v: Dictionary = {}) -> Dictionary:
	return check_items(items_for(pack, v))


static func missing_paths(pack: Dictionary, v: Dictionary = {}) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var missing: Array[Dictionary] = check(pack, v)["missing"]
	for it: Dictionary in missing:
		out.append(String(it["path"]))
	return out


static func names_text(items: Array[Dictionary]) -> String:
	var shown: PackedStringArray = PackedStringArray()
	for it: Dictionary in items:
		if shown.size() >= NAMED_IN_NOTE:
			return ", ".join(shown) + " and " + str(items.size() - shown.size()) + " more"
		shown.append(String(it["label"]))
	return ", ".join(shown)


static func missing_note(pack: Dictionary, v: Dictionary = {}) -> String:
	var missing: Array[Dictionary] = check(pack, v)["missing"]
	if missing.is_empty():
		return ""
	var head: String = "1 file has moved: " if missing.size() == 1 else str(missing.size()) + " files have moved: "
	return head + names_text(missing)


static func change_note(v: Dictionary) -> String:
	if not bool(v.get("scanned", false)):
		return ""
	var parts: PackedStringArray = PackedStringArray()
	var added: Array = v.get("added", [])
	var changed: Array = v.get("changed", [])
	var gone: Array = v.get("gone", [])
	var away: PackedStringArray = v.get("away", PackedStringArray())
	if not added.is_empty():
		parts.append(str(added.size()) + (" file is new" if added.size() == 1 else " files are new"))
	if not changed.is_empty():
		parts.append(str(changed.size()) + (" file has changed" if changed.size() == 1 else " files have changed"))
	if not gone.is_empty():
		parts.append(str(gone.size()) + (" file is no longer in the folder" if gone.size() == 1 else " files are no longer in the folder"))
	if not away.is_empty():
		var names: PackedStringArray = PackedStringArray()
		for a: String in away:
			names.append(a)
		parts.append(("1 folder cannot be reached: " if away.size() == 1 else str(away.size()) + " folders cannot be reached: ") + ", ".join(names))
	return ", ".join(parts)


static func summary(pack: Dictionary, v: Dictionary = {}) -> String:
	var items: Array[Dictionary] = items_for(pack, v)
	var parts: PackedStringArray = PackedStringArray()
	parts.append(str(items.size()) + (" file" if items.size() == 1 else " files"))
	var bin: String = bin_of(pack)
	parts.append(("lands in " + bin) if not bin.is_empty() else "lands at the top of the bin")
	parts.append("brings everything in" if import_at_once_of(pack) else "shows the list first")
	if follows(pack):
		parts.append("updates itself from " + ", ".join(folder_names(pack)))
	return ", ".join(parts)


static func entries_for(pack: Dictionary, chosen: PackedStringArray, bin_override: String, v: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not is_pack(pack):
		return out
	var bin: String = bin_of(pack)
	if not bin_override.strip_edges().is_empty():
		bin = clean_bin(bin_override)
	var want: Dictionary = {}
	for p: String in chosen:
		want[path_key(p)] = true
	for it: Dictionary in items_for(pack, v):
		var path: String = String(it["path"])
		if not want.has(path_key(path)) or not file_there(path):
			continue
		out.append({"path": path, "label": String(it["label"]), "bin": join_bin(bin, String(it.get("sub", "")))})
	return out


static func all_entries(pack: Dictionary, bin_override: String, v: Dictionary = {}) -> Array[Dictionary]:
	return entries_for(pack, every_path(pack, v), bin_override, v)


static func import_label(pack: Dictionary) -> String:
	return "Import package " + label_of(pack)


static func blank_result() -> Dictionary:
	return {"ok": false, "ids": PackedStringArray(), "brought_in": 0, "missing": PackedStringArray(), "bin": "", "why": ""}


static func import_chosen(doc: Project, pack: Dictionary, chosen: PackedStringArray, bin_override: String, v: Dictionary = {}) -> Dictionary:
	var result: Dictionary = blank_result()
	if doc == null or not is_pack(pack):
		result["why"] = "that package could not be read"
		return result
	var use: Dictionary = v if v.has("items") else view(pack)
	var entries: Array[Dictionary] = entries_for(pack, chosen, bin_override, use)
	var gone: PackedStringArray = PackedStringArray()
	var want: Dictionary = {}
	for p: String in chosen:
		want[path_key(p)] = true
	for it: Dictionary in items_for(pack, use):
		var path: String = String(it["path"])
		if want.has(path_key(path)) and not file_there(path):
			gone.append(path)
	result["missing"] = gone
	result["bin"] = clean_bin(bin_override) if not bin_override.strip_edges().is_empty() else bin_of(pack)
	if entries.is_empty():
		if chosen.is_empty():
			result["why"] = "nothing was picked out of " + label_of(pack)
		elif not gone.is_empty():
			result["why"] = "none of those files are where " + label_of(pack) + " left them"
		else:
			result["why"] = "there is nothing in " + label_of(pack) + " to bring in"
		return result
	var loader: GDScript = loader_script()
	if loader == null or not loader.can_instantiate():
		result["why"] = "the importer did not load"
		return result
	var ids: PackedStringArray = loader.call("instance").call("import_entries", doc, entries, import_label(pack))
	result["ids"] = ids
	result["brought_in"] = ids.size()
	result["ok"] = not ids.is_empty()
	if not result["ok"]:
		result["why"] = "the import was refused"
	return result


static func import_all(doc: Project, pack: Dictionary, bin_override: String, v: Dictionary = {}) -> Dictionary:
	var use: Dictionary = v if v.has("items") else view(pack)
	return import_chosen(doc, pack, every_path(pack, use), bin_override, use)


static func result_note(result: Dictionary) -> String:
	var n: int = int(result.get("brought_in", 0))
	var gone: PackedStringArray = result.get("missing", PackedStringArray())
	var parts: PackedStringArray = PackedStringArray()
	if n > 0:
		var where: String = String(result.get("bin", ""))
		parts.append("Brought in " + str(n) + (" item" if n == 1 else " items") + ((" to " + where) if not where.is_empty() else ""))
	elif not String(result.get("why", "")).is_empty():
		var why: String = String(result["why"])
		parts.append(why.substr(0, 1).to_upper() + why.substr(1))
	if not gone.is_empty():
		var names: PackedStringArray = PackedStringArray()
		for p: String in gone:
			if names.size() >= NAMED_IN_NOTE:
				names.append(str(gone.size() - names.size()) + " more")
				break
			names.append(p.get_file())
		parts.append(("1 file is missing: " if gone.size() == 1 else str(gone.size()) + " files are missing: ") + ", ".join(names))
	return ". ".join(parts)

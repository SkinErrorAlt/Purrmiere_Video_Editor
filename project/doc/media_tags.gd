extends RefCounted

const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Command := preload("res://doc/commands/command.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const OrganizerCmds := preload("res://doc/commands/organizer_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const INFO_KEY := "bin_tags"
const PREF_SPLIT := "bin.tag_split"
const SPLIT_COMMAS := "commas"
const SPLIT_WORDS := "words"
const SPLITS: PackedStringArray = ["commas", "words"]
const TAG_PREFIX := "#"

static var split_override: String = ""


static func prefs_node() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
		if prefs != null and prefs.has_method("register"):
			return prefs
	return null


static func register_prefs() -> Node:
	var prefs: Node = prefs_node()
	if prefs != null and not bool(prefs.call("is_registered", PREF_SPLIT)):
		prefs.call("register", PREF_SPLIT, SPLIT_COMMAS, {"label": "Bin tags are split by", "type": "enum", "choices": Array(SPLITS), "hint": "commas: \"foot step, hit\" is two tags. words: every word is its own tag, and a search checks each word against every tag."})
	return prefs


static func split_mode() -> String:
	if not split_override.is_empty():
		return split_override
	var prefs: Node = register_prefs()
	if prefs == null:
		return SPLIT_COMMAS
	var v: String = String(prefs.call("get_value", PREF_SPLIT))
	return v if SPLITS.has(v) else SPLIT_COMMAS


static func clean(t: String) -> String:
	var out: String = t.strip_edges().trim_prefix(TAG_PREFIX).strip_edges()
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out


static func split(text: String, mode: String = "") -> PackedStringArray:
	var m: String = mode if not mode.is_empty() else split_mode()
	var out: PackedStringArray = PackedStringArray()
	var pieces: PackedStringArray = text.split(",", false)
	for p: String in pieces:
		var words: PackedStringArray = PackedStringArray([p])
		if m == SPLIT_WORDS:
			words = p.replace("\t", " ").split(" ", false)
		for w: String in words:
			var c: String = clean(w)
			if not c.is_empty() and not has_tag(out, c):
				out.append(c)
	return out


static func has_tag(list: PackedStringArray, t: String) -> bool:
	var low: String = t.to_lower()
	for e: String in list:
		if e.to_lower() == low:
			return true
	return false


static func joined(list: PackedStringArray) -> String:
	return ", ".join(list)


static func bin_chain(bin: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var b: String = bin.strip_edges().trim_prefix("/").trim_suffix("/")
	while not b.is_empty():
		out.append(b)
		b = b.get_base_dir() if b.contains("/") else ""
	return out


static func all_bin_tags(doc: Project) -> Dictionary:
	if doc == null:
		return {}
	var v: Variant = doc.info.get(INFO_KEY, {})
	return v if v is Dictionary else {}


static func bin_tags(doc: Project, bin: String) -> PackedStringArray:
	var v: Variant = all_bin_tags(doc).get(bin, [])
	return MediaItem._strings(v)


static func folder_tags(doc: Project, bin: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for b: String in bin_chain(bin):
		for t: String in bin_tags(doc, b):
			if not has_tag(out, t):
				out.append(t)
	return out


static func from_folder(doc: Project, m: MediaItem) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if m == null:
		return out
	for t: String in folder_tags(doc, m.bin):
		if not has_tag(m.tags_off, t) and not has_tag(m.tags, t):
			out.append(t)
	return out


static func effective(doc: Project, m: MediaItem) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if m == null:
		return out
	for t: String in m.tags:
		if not has_tag(out, t):
			out.append(t)
	for t: String in from_folder(doc, m):
		if not has_tag(out, t):
			out.append(t)
	return out


static func known(doc: Project) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null:
		return out
	for m: MediaItem in doc.media:
		for t: String in effective(doc, m):
			if not has_tag(out, t):
				out.append(t)
	for b: Variant in all_bin_tags(doc).keys():
		for t: String in bin_tags(doc, String(b)):
			if not has_tag(out, t):
				out.append(t)
	out.sort()
	return out


static func terms(query: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var q: String = query.strip_edges()
	if q.is_empty():
		return out
	var mode: String = split_mode()
	var parts: PackedStringArray = q.split(",", false)
	for p: String in parts:
		var words: PackedStringArray = PackedStringArray([p])
		if mode == SPLIT_WORDS:
			words = p.replace("\t", " ").split(" ", false)
		for w: String in words:
			var s: String = w.strip_edges()
			if s.is_empty():
				continue
			var only_tags: bool = s.begins_with(TAG_PREFIX)
			var needle: String = clean(s).to_lower()
			if not needle.is_empty():
				out.append({"needle": needle, "tags_only": only_tags})
	return out


static func term_hits(doc: Project, m: MediaItem, term: Dictionary, tags_now: PackedStringArray) -> bool:
	var needle: String = String(term["needle"])
	for t: String in tags_now:
		if t.to_lower().contains(needle):
			return true
	if bool(term["tags_only"]):
		return false
	return m.label.to_lower().contains(needle)


static func search_hit(doc: Project, m: MediaItem, query: String) -> bool:
	if m == null:
		return false
	var list: Array[Dictionary] = terms(query)
	if list.is_empty():
		return true
	var tags_now: PackedStringArray = effective(doc, m)
	for term: Dictionary in list:
		if term_hits(doc, m, term, tags_now):
			return true
	var whole: String = query.strip_edges().to_lower()
	return not whole.begins_with(TAG_PREFIX) and m.label.to_lower().contains(whole)


static func with_added(list: PackedStringArray, more: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = list.duplicate()
	for t: String in more:
		if not has_tag(out, t):
			out.append(t)
	return out


static func without(list: PackedStringArray, gone: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for t: String in list:
		if not has_tag(gone, t):
			out.append(t)
	return out


static func add_tags(doc: Project, ids: PackedStringArray, more: PackedStringArray) -> bool:
	if doc == null or more.is_empty():
		return false
	var cmds: Array[Command] = []
	for id: String in ids:
		var m: MediaItem = doc.media_by_id(id)
		if m == null:
			continue
		var next: PackedStringArray = with_added(m.tags, more)
		if next != m.tags:
			cmds.append(MediaCmds.SetMediaField.new(id, "tags", next))
		var off: PackedStringArray = without(m.tags_off, more)
		if off != m.tags_off:
			cmds.append(MediaCmds.SetMediaField.new(id, "tags_off", off))
	return Verbs.run(doc, "Tag " + joined(more), cmds)


static func remove_tags(doc: Project, ids: PackedStringArray, gone: PackedStringArray) -> bool:
	if doc == null or gone.is_empty():
		return false
	var cmds: Array[Command] = []
	for id: String in ids:
		var m: MediaItem = doc.media_by_id(id)
		if m == null:
			continue
		var next: PackedStringArray = without(m.tags, gone)
		if next != m.tags:
			cmds.append(MediaCmds.SetMediaField.new(id, "tags", next))
		var off: PackedStringArray = m.tags_off.duplicate()
		for t: String in gone:
			if has_tag(folder_tags(doc, m.bin), t) and not has_tag(off, t):
				off.append(t)
		if off != m.tags_off:
			cmds.append(MediaCmds.SetMediaField.new(id, "tags_off", off))
	return Verbs.run(doc, "Remove tag " + joined(gone), cmds)


static func set_tags(doc: Project, id: String, list: PackedStringArray) -> bool:
	var m: MediaItem = doc.media_by_id(id) if doc != null else null
	if m == null:
		return false
	var gone: PackedStringArray = PackedStringArray()
	for t: String in effective(doc, m):
		if not has_tag(list, t):
			gone.append(t)
	var cmds: Array[Command] = []
	var own: PackedStringArray = PackedStringArray()
	var folder: PackedStringArray = folder_tags(doc, m.bin)
	for t: String in list:
		if not has_tag(folder, t) and not has_tag(own, t):
			own.append(t)
	var off: PackedStringArray = PackedStringArray()
	for t: String in folder:
		if not has_tag(list, t):
			off.append(t)
	if own != m.tags:
		cmds.append(MediaCmds.SetMediaField.new(id, "tags", own))
	if off != m.tags_off:
		cmds.append(MediaCmds.SetMediaField.new(id, "tags_off", off))
	return Verbs.run(doc, "Tags on " + m.label, cmds)


static func set_bin_tags(doc: Project, bin: String, list: PackedStringArray) -> bool:
	if doc == null or bin.is_empty():
		return false
	var cmds: Array[Command] = [OrganizerCmds.SetBinTags.new(bin, list)]
	return Verbs.run(doc, "Folder tags on " + bin.get_file(), cmds)


static func give_back(doc: Project, id: String, t: String) -> bool:
	var m: MediaItem = doc.media_by_id(id) if doc != null else null
	if m == null or not has_tag(m.tags_off, t):
		return false
	var cmds: Array[Command] = [MediaCmds.SetMediaField.new(id, "tags_off", without(m.tags_off, PackedStringArray([t])))]
	return Verbs.run(doc, "Give back folder tag " + t, cmds)

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const SubCmds := preload("res://doc/commands/sub_project_cmds.gd")
const TOP := ""
const TOP_NAME := "Top level"

static var _cache: Dictionary = {}


static func groups(doc: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null:
		return out
	for g: Dictionary in doc.sub_projects:
		out.append(g)
	return out


static func group_by_id(doc: Project, gid: String) -> Dictionary:
	if doc == null or gid.is_empty():
		return {}
	for g: Dictionary in doc.sub_projects:
		if String(g.get("id", "")) == gid:
			return g
	return {}


static func name_of(doc: Project, gid: String) -> String:
	if gid.is_empty():
		return TOP_NAME
	return String(group_by_id(doc, gid).get("name", ""))


static func group_of(doc: Project, seq_id: String) -> String:
	if doc == null or seq_id.is_empty():
		return TOP
	for g: Dictionary in doc.sub_projects:
		if (g.get("sequences", []) as Array).has(seq_id):
			return String(g.get("id", ""))
	return TOP


static func active_group(doc: Project) -> String:
	if doc == null:
		return TOP
	return group_of(doc, doc.active_sequence_id)


static func is_scoped(doc: Project) -> bool:
	if doc == null:
		return false
	for g: Dictionary in doc.sub_projects:
		for sid: Variant in g.get("sequences", []):
			if doc.sequence_by_id(String(sid)) != null:
				return true
	return false


static func members(doc: Project, gid: String) -> Array[Sequence]:
	var out: Array[Sequence] = []
	if doc == null:
		return out
	if gid.is_empty():
		for s: Sequence in doc.sequences:
			if group_of(doc, s.id).is_empty():
				out.append(s)
		return out
	for sid: Variant in group_by_id(doc, gid).get("sequences", []):
		var s2: Sequence = doc.sequence_by_id(String(sid))
		if s2 != null:
			out.append(s2)
	return out


static func ordered(doc: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null:
		return out
	var top: Array[Sequence] = members(doc, TOP)
	if not top.is_empty() or doc.sub_projects.is_empty():
		out.append({"id": TOP, "name": TOP_NAME, "sequences": top})
	for g: Dictionary in doc.sub_projects:
		var gid: String = String(g.get("id", ""))
		out.append({"id": gid, "name": String(g.get("name", "")), "sequences": members(doc, gid)})
	return out


static func _inner_of(doc: Project, c: Clip) -> String:
	if not c.sequence_id.is_empty():
		return c.sequence_id
	if c.media_id.is_empty():
		return ""
	var m: MediaItem = doc.media_by_id(c.media_id)
	if m != null and m.kind == "sequence":
		return m.sequence_id
	return ""


static func with_nested(doc: Project, seqs: Array[Sequence]) -> Array[Sequence]:
	var out: Array[Sequence] = []
	if doc == null:
		return out
	var seen: Dictionary = {}
	var queue: Array[Sequence] = []
	for s: Sequence in seqs:
		if s != null and not seen.has(s.id):
			seen[s.id] = true
			queue.append(s)
	while not queue.is_empty():
		var s2: Sequence = queue.pop_front()
		out.append(s2)
		for tr: Track in s2.all_tracks():
			for c: Clip in tr.clips:
				var inner: String = _inner_of(doc, c)
				if inner.is_empty() or seen.has(inner):
					continue
				var n: Sequence = doc.sequence_by_id(inner)
				if n != null:
					seen[inner] = true
					queue.append(n)
	return out


static func media_ids_of(doc: Project, seqs: Array[Sequence]) -> Dictionary:
	var ids: Dictionary = {}
	if doc == null:
		return ids
	var known: Dictionary = {}
	for m: MediaItem in doc.media:
		known[m.id] = true
	var todo: Array[Sequence] = with_nested(doc, seqs)
	var done: Dictionary = {}
	while not todo.is_empty():
		var s: Sequence = todo.pop_front()
		if done.has(s.id):
			continue
		done[s.id] = true
		var m_seq: MediaItem = doc.media_for_sequence(s.id)
		if m_seq != null:
			ids[m_seq.id] = true
		for tr: Track in s.all_tracks():
			for c: Clip in tr.clips:
				if not c.media_id.is_empty():
					ids[c.media_id] = true
		collect_ids(s.to_dict(), known, ids)
		for id: Variant in ids.keys():
			var m: MediaItem = doc.media_by_id(String(id))
			if m != null and m.kind == "sequence" and not done.has(m.sequence_id):
				var n: Sequence = doc.sequence_by_id(m.sequence_id)
				if n != null:
					todo.append(n)
	var grew: bool = true
	var rounds: int = 0
	while grew and rounds < 8:
		grew = false
		rounds += 1
		for id2: Variant in ids.keys():
			var m2: MediaItem = doc.media_by_id(String(id2))
			if m2 == null or m2.props.is_empty():
				continue
			var inner: Dictionary = {}
			collect_ids(m2.props, known, inner)
			for k: Variant in inner.keys():
				if not ids.has(k):
					ids[k] = true
					grew = true
	return ids


static func collect_ids(v: Variant, known: Dictionary, out: Dictionary) -> void:
	var t: int = typeof(v)
	if t == TYPE_STRING or t == TYPE_STRING_NAME:
		if known.has(String(v)):
			out[String(v)] = true
	elif t == TYPE_DICTIONARY:
		for k: Variant in (v as Dictionary).keys():
			collect_ids(k, known, out)
			collect_ids((v as Dictionary)[k], known, out)
	elif t == TYPE_ARRAY:
		for e: Variant in v:
			collect_ids(e, known, out)
	elif t == TYPE_PACKED_STRING_ARRAY:
		for e2: String in v:
			if known.has(e2):
				out[e2] = true


static func _key(doc: Project) -> String:
	return "%d|%d|%s|%d|%d" % [doc.get_instance_id(), doc.serial, doc.active_sequence_id, doc.sequences.size(), doc.media.size()]


static func scope(doc: Project) -> Dictionary:
	if doc == null:
		return {"scoped": false, "group": TOP, "in": {}, "elsewhere": {}}
	var key: String = _key(doc)
	if _cache.has(key):
		return _cache[key]
	var gid: String = active_group(doc)
	var scoped: bool = is_scoped(doc)
	var inside: Dictionary = media_ids_of(doc, members(doc, gid)) if scoped else {}
	var elsewhere: Dictionary = {}
	if scoped:
		var others: Array[Sequence] = []
		for s: Sequence in doc.sequences:
			if group_of(doc, s.id) != gid:
				others.append(s)
		for id: Variant in media_ids_of(doc, others).keys():
			if not inside.has(id):
				elsewhere[id] = true
	var out: Dictionary = {"scoped": scoped, "group": gid, "in": inside, "elsewhere": elsewhere}
	if _cache.size() > 16:
		_cache.clear()
	_cache[key] = out
	return out


static func in_scope(doc: Project, media_id: String) -> bool:
	var sc: Dictionary = scope(doc)
	if not bool(sc["scoped"]):
		return true
	return not (sc["elsewhere"] as Dictionary).has(media_id)


static func _copy(doc: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Dictionary in doc.sub_projects:
		out.append(g.duplicate(true))
	return out


static func _commit(doc: Project, label: String, list: Array[Dictionary]) -> bool:
	var cmds: Array[Command] = [SubCmds.SetSubProjects.new(label, list)]
	return Verbs.run(doc, label, cmds)


static func _strip(list: Array[Dictionary], seq_id: String) -> void:
	for g: Dictionary in list:
		var seqs: Array = g.get("sequences", [])
		seqs.erase(seq_id)
		g["sequences"] = seqs


static func unique_name(doc: Project, want: String) -> String:
	var base: String = want.strip_edges()
	if base.is_empty():
		base = "Sub project"
	var taken: Dictionary = {}
	for g: Dictionary in doc.sub_projects:
		taken[String(g.get("name", ""))] = true
	if not taken.has(base):
		return base
	var n: int = 2
	while taken.has(base + " " + str(n)):
		n += 1
	return base + " " + str(n)


static func add(doc: Project, name_: String, seq_ids: PackedStringArray = PackedStringArray()) -> String:
	if doc == null:
		return ""
	var list: Array[Dictionary] = _copy(doc)
	var ids: Array = []
	for sid: String in seq_ids:
		if doc.sequence_by_id(sid) != null and not ids.has(sid):
			_strip(list, sid)
			ids.append(sid)
	var gid: String = doc.mint_id("g")
	list.append({"id": gid, "name": unique_name(doc, name_), "sequences": ids})
	if not _commit(doc, "New sub project", list):
		return ""
	return gid


static func rename(doc: Project, gid: String, name_: String) -> bool:
	var clean: String = name_.strip_edges()
	if doc == null or clean.is_empty():
		return false
	var list: Array[Dictionary] = _copy(doc)
	for g: Dictionary in list:
		if String(g.get("id", "")) == gid:
			g["name"] = clean
			return _commit(doc, "Rename sub project", list)
	return false


static func move(doc: Project, gid: String, delta: int) -> bool:
	if doc == null:
		return false
	var list: Array[Dictionary] = _copy(doc)
	for i: int in list.size():
		if String(list[i].get("id", "")) == gid:
			var j: int = clampi(i + delta, 0, list.size() - 1)
			if j == i:
				return false
			var g: Dictionary = list[i]
			list.remove_at(i)
			list.insert(j, g)
			return _commit(doc, "Reorder sub projects", list)
	return false


static func assign(doc: Project, seq_id: String, gid: String) -> bool:
	if doc == null or doc.sequence_by_id(seq_id) == null:
		return false
	var list: Array[Dictionary] = _copy(doc)
	_strip(list, seq_id)
	if not gid.is_empty():
		var found: bool = false
		for g: Dictionary in list:
			if String(g.get("id", "")) == gid:
				var seqs: Array = g.get("sequences", [])
				seqs.append(seq_id)
				g["sequences"] = seqs
				found = true
		if not found:
			return false
	return _commit(doc, "Move sequence to a sub project" if not gid.is_empty() else "Move sequence to the top level", list)


static func move_sequence(doc: Project, seq_id: String, delta: int) -> bool:
	var gid: String = group_of(doc, seq_id)
	if doc == null or gid.is_empty():
		return false
	var list: Array[Dictionary] = _copy(doc)
	for g: Dictionary in list:
		if String(g.get("id", "")) != gid:
			continue
		var seqs: Array = g.get("sequences", [])
		var i: int = seqs.find(seq_id)
		var j: int = clampi(i + delta, 0, seqs.size() - 1)
		if i < 0 or j == i:
			return false
		seqs.remove_at(i)
		seqs.insert(j, seq_id)
		g["sequences"] = seqs
	return _commit(doc, "Reorder sequences", list)


static func remove(doc: Project, gid: String) -> bool:
	if doc == null:
		return false
	var list: Array[Dictionary] = _copy(doc)
	for i: int in list.size():
		if String(list[i].get("id", "")) == gid:
			list.remove_at(i)
			return _commit(doc, "Remove sub project", list)
	return false


static func export_check(doc: Project, gid: String) -> Dictionary:
	var seqs: Array[Sequence] = members(doc, gid)
	var ids: PackedStringArray = PackedStringArray()
	for s: Sequence in seqs:
		ids.append(s.id)
	if seqs.is_empty():
		return {"ids": ids, "stitch": false, "why": "This sub project has no sequences"}
	var first: Sequence = seqs[0]
	for s2: Sequence in seqs:
		if s2.width != first.width or s2.height != first.height or absf(s2.fps - first.fps) > 0.0001:
			return {"ids": ids, "stitch": false, "why": "The sequences differ in size or frame rate, so they cannot be joined into one file"}
	return {"ids": ids, "stitch": true, "why": ""}

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Command := preload("res://doc/commands/command.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const StreamOrdinals := preload("res://doc/stream_ordinals.gd")
const PROP := "streams_off"
const BRIDGE_PATH := "/root/PurrBridge"
const SESSION_PATH := "/root/Session"
const MENU_PREFIX := "stream_on:"

static var stats: Dictionary = {"pushes": 0, "stripped": 0}
static var _watched: WeakRef = null


static func off_list(item: MediaItem) -> PackedInt32Array:
	return StreamOrdinals.off_list(item)


static func is_off(item: MediaItem, ordinal: int) -> bool:
	return StreamOrdinals.is_off(item, ordinal)


static func all_off(item: MediaItem) -> bool:
	return StreamOrdinals.all_off(item)


static func count(item: MediaItem) -> int:
	if item == null or not (item.has_audio or item.kind == "audio"):
		return 0
	return maxi(item.audio_streams.size(), 1)


static func clip_stream(c: Clip) -> int:
	return int(c.audio.get("stream", 0.0)) if c != null else 0


static func clip_off(doc: Project, c: Clip) -> bool:
	if doc == null or c == null or c.media_id.is_empty():
		return false
	var item: MediaItem = doc.media_by_id(c.media_id)
	if item == null or item.kind == "sequence":
		return false
	return is_off(item, clip_stream(c))


static func props_with(item: MediaItem, ordinal: int, off: bool) -> Dictionary:
	var props: Dictionary = item.props.duplicate(true) if item != null else {}
	var list: PackedInt32Array = off_list(item)
	if off and not list.has(ordinal):
		list.append(ordinal)
	elif not off and list.has(ordinal):
		list.remove_at(list.find(ordinal))
	list.sort()
	if list.is_empty():
		props.erase(PROP)
	else:
		var arr: Array = []
		for o: int in list:
			arr.append(o)
		props[PROP] = arr
	return props


static func set_off(doc: Project, media_ids: PackedStringArray, ordinal: int, off: bool) -> bool:
	if doc == null or ordinal < 0:
		return false
	var cmds: Array[Command] = []
	var what: String = ""
	for mid: String in media_ids:
		var item: MediaItem = doc.media_by_id(mid)
		if item == null or ordinal >= count(item) or is_off(item, ordinal) == off:
			continue
		if what.is_empty():
			what = StreamOrdinals.label(item, ordinal)
		cmds.append(MediaCmds.SetMediaField.new(mid, "props", props_with(item, ordinal, off)))
	if cmds.is_empty():
		return false
	var done: bool = bool(_verbs().call("run", doc, ("Switch off audio track " if off else "Switch on audio track ") + what, cmds))
	sync(doc)
	return done


static func _verbs() -> GDScript:
	return load("res://doc/verbs.gd")


static func menu_items(item: MediaItem) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: int = count(item)
	if n < 2:
		return out
	for o: int in n:
		out.append({"id": MENU_PREFIX + str(o), "label": StreamOrdinals.label(item, o), "checked": not is_off(item, o)})
	return out


static func ordinal_of_menu(id: String) -> int:
	if not id.begins_with(MENU_PREFIX):
		return -1
	var tail: String = id.substr(MENU_PREFIX.length())
	return int(tail) if tail.is_valid_int() else -1


static func _root() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root
	return null


static func _bridge() -> Node:
	var r: Node = _root()
	if r == null:
		return null
	var b: Node = r.get_node_or_null(BRIDGE_PATH)
	if b == null or not bool(b.get("available")):
		return null
	return b


static func handle_of(item: MediaItem) -> int:
	if item == null:
		return -1
	var r: Node = _root()
	var s: Node = r.get_node_or_null(SESSION_PATH) if r != null else null
	if s != null:
		var handles: Variant = s.get("media_handles")
		if handles is Dictionary and (handles as Dictionary).has(item.id):
			var h: int = int((handles as Dictionary)[item.id])
			if h >= 0:
				return h
	return item.handle


static func wanted_off(doc: Project, h: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if doc == null or h < 0:
		return out
	var first: bool = true
	for item: MediaItem in doc.media:
		if handle_of(item) != h:
			continue
		var mine: PackedInt32Array = off_list(item)
		if first:
			out = mine
			first = false
			continue
		var keep: PackedInt32Array = PackedInt32Array()
		for o: int in out:
			if mine.has(o):
				keep.append(o)
		out = keep
	return out


static func push(doc: Project, item: MediaItem) -> void:
	var b: Node = _bridge()
	var h: int = handle_of(item)
	if b == null or h < 0:
		return
	b.call("peaks_skip", h, wanted_off(doc, h))
	stats["pushes"] = int(stats["pushes"]) + 1
	watch(doc)


static func sync(doc: Project) -> void:
	if doc == null or _bridge() == null:
		return
	var seen: Dictionary = {}
	for item: MediaItem in doc.media:
		var h: int = handle_of(item)
		if h < 0 or seen.has(h):
			continue
		seen[h] = true
		push(doc, item)
	watch(doc)


static func watch(doc: Project) -> void:
	if doc == null:
		return
	if _watched != null and _watched.get_ref() == doc:
		return
	_watched = weakref(doc)
	if not doc.changed.is_connected(_on_doc_changed):
		doc.changed.connect(_on_doc_changed)


static func _on_doc_changed(kind: String) -> void:
	if kind != "media" or _watched == null:
		return
	var doc: Project = _watched.get_ref()
	if doc != null:
		sync(doc)


static func want_streams(item: MediaItem) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for o: int in maxi(count(item), 1):
		if not is_off(item, o):
			out.append(o)
	return out


static func strip_graph(doc: Project, handles: Dictionary, tracks: Array) -> int:
	if doc == null or tracks.is_empty():
		return 0
	var keys: Dictionary = {}
	for item: MediaItem in doc.media:
		var off: PackedInt32Array = off_list(item)
		if off.is_empty():
			continue
		var h: int = int(handles[item.id]) if handles.has(item.id) else item.handle
		if h < 0:
			continue
		for o: int in off:
			keys[str(h) + ":" + str(o)] = true
	if keys.is_empty():
		return 0
	var removed: int = 0
	for t: Variant in tracks:
		if not (t is Dictionary):
			continue
		var td: Dictionary = t
		var clips: Variant = td.get("clips", [])
		if not (clips is Array):
			continue
		var kept: Array = []
		for ce: Variant in (clips as Array):
			var cd: Dictionary = ce if ce is Dictionary else {}
			var key: String = str(int(cd.get("media", -1))) + ":" + str(int(cd.get("stream", 0)))
			if int(cd.get("media", -1)) >= 0 and keys.has(key):
				removed += 1
				continue
			kept.append(ce)
		if kept.size() != (clips as Array).size():
			(clips as Array).assign(kept)
	stats["stripped"] = int(stats["stripped"]) + removed
	return removed


static func strip_entries(doc: Project, handles: Dictionary, entries: Dictionary) -> int:
	if doc == null or entries.is_empty():
		return 0
	var holder: Array = [{"clips": entries.values()}]
	var before: int = entries.size()
	var removed: int = strip_graph(doc, handles, holder)
	if removed == 0:
		return 0
	var keep: Dictionary = {}
	for ce: Variant in (holder[0] as Dictionary)["clips"]:
		keep[String((ce as Dictionary).get("id", ""))] = true
	for k: Variant in entries.keys():
		if not keep.has(String(k)):
			entries.erase(k)
	return before - entries.size()

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const NAMES_PROP := "stream_names"
const OFF_PROP := "streams_off"

static var repaired: int = 0


static func ordinal_of_index(item: MediaItem, index: int) -> int:
	if item == null:
		return -1
	for i: int in item.audio_streams.size():
		if int(item.audio_streams[i].get("index", i)) == index:
			return i
	return -1


static func selected(item: MediaItem) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if item == null:
		return out
	var off: PackedInt32Array = off_list(item)
	for i: int in item.audio_streams.size():
		if bool(item.audio_streams[i].get("selected", true)) and not off.has(i):
			out.append(i)
	if out.is_empty():
		for i2: int in maxi(item.audio_streams.size(), 1):
			if not off.has(i2):
				out.append(i2)
				break
	return out


static func first_selected(item: MediaItem) -> int:
	if item == null:
		return 0
	var picks: PackedInt32Array = selected(item)
	return picks[0] if not picks.is_empty() else 0


static func off_list(item: MediaItem) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if item == null:
		return out
	var raw: Variant = item.props.get(OFF_PROP, [])
	if not (raw is Array):
		return out
	for v: Variant in (raw as Array):
		var o: int = int(v)
		if o >= 0 and not out.has(o):
			out.append(o)
	out.sort()
	return out


static func is_off(item: MediaItem, ordinal: int) -> bool:
	return item != null and ordinal >= 0 and off_list(item).has(ordinal)


static func all_off(item: MediaItem) -> bool:
	if item == null:
		return false
	var off: PackedInt32Array = off_list(item)
	if off.is_empty():
		return false
	for i: int in maxi(item.audio_streams.size(), 1):
		if not off.has(i):
			return false
	return true


static func given(item: MediaItem, ordinal: int) -> String:
	if item == null or ordinal < 0:
		return ""
	var names: Variant = item.props.get(NAMES_PROP, {})
	if names is Dictionary:
		return String((names as Dictionary).get(str(ordinal), "")).strip_edges()
	return ""


static func names_of(item: MediaItem) -> Dictionary:
	if item == null:
		return {}
	var names: Variant = item.props.get(NAMES_PROP, {})
	if not (names is Dictionary):
		return {}
	return clean_names(names, 0)


static func clean_names(names: Dictionary, limit: int) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in names.keys():
		var key: String = String(k)
		if not key.is_valid_int():
			continue
		var ordinal: int = int(key)
		if ordinal < 0 or (limit > 0 and ordinal >= limit):
			continue
		var text: String = String(names[k]).strip_edges()
		if not text.is_empty():
			out[str(ordinal)] = text
	return out


static func props_with_names(item: MediaItem, names: Dictionary, limit: int = 0) -> Dictionary:
	var props: Dictionary = item.props.duplicate(true) if item != null else {}
	var clean: Dictionary = clean_names(names, limit)
	if clean.is_empty():
		props.erase(NAMES_PROP)
	else:
		props[NAMES_PROP] = clean
	return props


static func props_with_name(item: MediaItem, ordinal: int, text: String) -> Dictionary:
	var names: Dictionary = names_of(item)
	var clean: String = text.strip_edges()
	if clean.is_empty():
		names.erase(str(ordinal))
	elif ordinal >= 0:
		names[str(ordinal)] = clean
	return props_with_names(item, names)


static func label(item: MediaItem, ordinal: int) -> String:
	var mine: String = given(item, ordinal)
	if not mine.is_empty():
		return mine
	if item != null and ordinal >= 0 and ordinal < item.audio_streams.size():
		var title: String = String(item.audio_streams[ordinal].get("title", ""))
		if not title.is_empty():
			return title
	return "A" + str(ordinal + 1)


static func wrong(item: MediaItem, stream: int) -> bool:
	return item != null and not item.audio_streams.is_empty() and stream >= item.audio_streams.size() and ordinal_of_index(item, stream) >= 0


static func repair(project: Project) -> int:
	var fixed: int = 0
	if project == null:
		return 0
	for s: Sequence in project.sequences:
		var groups: Dictionary = {}
		var all: Array[Clip] = []
		for tr: Track in s.all_tracks():
			for c: Clip in tr.clips:
				if c.audio.is_empty() or not c.audio.has("stream"):
					continue
				all.append(c)
				var key: String = c.media_id + "|" + (c.link_id if not c.link_id.is_empty() else c.id)
				if not groups.has(key):
					groups[key] = []
				(groups[key] as Array).append(c)
		for key: Variant in groups.keys():
			var list: Array = groups[key]
			var item: MediaItem = project.media_by_id((list[0] as Clip).media_id)
			var bad: bool = false
			for c2: Variant in list:
				if wrong(item, int((c2 as Clip).audio.get("stream", 0.0))):
					bad = true
			if not bad:
				continue
			for c3: Variant in list:
				var cc: Clip = c3
				var at: int = ordinal_of_index(item, int(cc.audio.get("stream", 0.0)))
				if at >= 0 and at != int(cc.audio.get("stream", 0.0)):
					cc.audio["stream"] = float(at)
					fixed += 1
	repaired += fixed
	return fixed

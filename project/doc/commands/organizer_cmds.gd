extends RefCounted

const VERSION := 1


class SetBinTags extends "res://doc/commands/command.gd":
	const INFO_KEY := "bin_tags"
	var bin: String = ""
	var tags: Array = []
	var had: bool = false
	var old: Array = []

	func _init(p_bin: String, p_tags: PackedStringArray) -> void:
		label = "Folder tags"
		bin = p_bin
		tags = Array(p_tags)

	func do(doc: Project) -> void:
		if bin.is_empty():
			ok = false
			return
		var all: Dictionary = doc.info.get(INFO_KEY, {}) if doc.info.get(INFO_KEY) is Dictionary else {}
		had = all.has(bin)
		old = (all.get(bin, []) as Array).duplicate() if all.get(bin) is Array else []
		if tags.is_empty():
			all.erase(bin)
		else:
			all[bin] = tags.duplicate()
		if all.is_empty():
			doc.info.erase(INFO_KEY)
		else:
			doc.info[INFO_KEY] = all
		doc.touch("media")

	func undo(doc: Project) -> void:
		var all: Dictionary = doc.info.get(INFO_KEY, {}) if doc.info.get(INFO_KEY) is Dictionary else {}
		if had:
			all[bin] = old.duplicate()
		else:
			all.erase(bin)
		if all.is_empty():
			doc.info.erase(INFO_KEY)
		else:
			doc.info[INFO_KEY] = all
		doc.touch("media")


class SetMediaRegions extends "res://doc/commands/command.gd":
	const Store := preload("res://doc/region_store.gd")
	var media_id: String = ""
	var file_path: String = ""
	var regions: Array = []
	var old_items: Dictionary = {}
	var old_store: Array = []
	var had_store: bool = false

	func _init(p_media_id: String, p_regions: Array, p_label: String = "Regions", p_file_path: String = "") -> void:
		label = p_label
		media_id = p_media_id
		file_path = p_file_path
		regions = p_regions.duplicate(true)

	func live_key() -> String:
		return "regions|" + media_id + "|" + file_path

	func _same(doc: Project) -> Array[MediaItem]:
		var out: Array[MediaItem] = []
		var key: String = Store.key_of(file_path)
		for m: MediaItem in doc.media:
			if m.id == media_id or (not key.is_empty() and Store.key_of(m.path) == key):
				out.append(m)
		return out

	func do(doc: Project) -> void:
		var item: MediaItem = doc.media_by_id(media_id)
		if item == null and file_path.is_empty():
			ok = false
			return
		if file_path.is_empty():
			file_path = item.path
		old_items = {}
		for m: MediaItem in _same(doc):
			old_items[m.id] = m.regions.duplicate(true)
			var typed: Array[Dictionary] = []
			for r: Variant in regions:
				if r is Dictionary:
					typed.append((r as Dictionary).duplicate(true))
			m.regions = typed
		if not file_path.is_empty():
			had_store = Store.has(file_path)
			old_store = Store.regions(file_path).duplicate(true)
			Store.put(file_path, regions, facts_of(item))
		doc.touch("markers")

	static func facts_of(item: MediaItem) -> Dictionary:
		if item == null:
			return {}
		var f: Dictionary = {"label": item.label, "kind": item.kind, "duration": item.duration, "fps": item.fps, "width": item.width, "height": item.height, "has_audio": item.has_audio}
		if not item.audio_streams.is_empty():
			f["audio_streams"] = item.audio_streams.duplicate(true)
		if item.recorded_at >= 0.0:
			f["recorded"] = item.recorded_at
		return f

	func undo(doc: Project) -> void:
		for id: Variant in old_items.keys():
			var m: MediaItem = doc.media_by_id(String(id))
			if m == null:
				continue
			var typed: Array[Dictionary] = []
			for r: Variant in old_items[id]:
				if r is Dictionary:
					typed.append((r as Dictionary).duplicate(true))
			m.regions = typed
		if not file_path.is_empty():
			if had_store:
				Store.put(file_path, old_store)
			else:
				Store.put(file_path, [])
		doc.touch("markers")


class SetMediaProp extends "res://doc/commands/command.gd":
	var media_id: String = ""
	var key: String = ""
	var value: Variant = null
	var had: bool = false
	var old: Variant = null

	func _init(p_media_id: String, p_key: String, p_value: Variant, p_label: String = "") -> void:
		label = p_label if not p_label.is_empty() else "Media " + p_key
		media_id = p_media_id
		key = p_key
		value = dup(p_value)

	func do(doc: Project) -> void:
		var m: MediaItem = doc.media_by_id(media_id)
		if m == null:
			ok = false
			return
		had = m.props.has(key)
		old = dup(m.props.get(key))
		if value == null:
			m.props.erase(key)
		else:
			m.props[key] = dup(value)
		doc.touch("markers")

	func undo(doc: Project) -> void:
		var m: MediaItem = doc.media_by_id(media_id)
		if m == null:
			return
		if had:
			m.props[key] = dup(old)
		else:
			m.props.erase(key)
		doc.touch("markers")

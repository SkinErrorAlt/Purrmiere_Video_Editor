extends RefCounted

const VERSION := 1
const Follow := preload("res://doc/marker_follow.gd")
const Layers := preload("res://doc/marker_layers.gd")


class MarkerCommand extends "res://doc/commands/command.gd":
	var clip_id: String = ""
	var media_id: String = ""

	func on_media(p_media_id: String) -> MarkerCommand:
		media_id = p_media_id
		return self

	func owner_ok(doc: Project) -> bool:
		if not media_id.is_empty():
			return doc.media_by_id(media_id) != null
		if seq(doc) == null:
			return false
		return clip_id.is_empty() or clip(doc, clip_id) != null

	func markers(doc: Project) -> Array:
		if not media_id.is_empty():
			var item: MediaItem = doc.media_by_id(media_id)
			return item.markers if item != null else []
		var s: Sequence = seq(doc)
		if s == null:
			return []
		if clip_id.is_empty():
			return s.markers
		var c: Clip = s.clip_by_id(clip_id)
		if c == null:
			return []
		return c.markers

	func find(doc: Project, marker_id: String) -> Marker:
		for m: Marker in markers(doc):
			if m.id == marker_id:
				return m
		return null

	func sort_list(doc: Project) -> void:
		var list: Array = markers(doc)
		list.sort_custom(func(a: Marker, b: Marker) -> bool: return a.time < b.time)


class AddMarker extends MarkerCommand:
	var marker_dict: Dictionary = {}

	func _init(p_seq_id: String, p_clip_id: String, p_marker_dict: Dictionary) -> void:
		label = "Add marker"
		seq_id = p_seq_id
		clip_id = p_clip_id
		marker_dict = p_marker_dict.duplicate(true)

	func do(doc: Project) -> void:
		if not owner_ok(doc):
			ok = false
			return
		var list: Array = markers(doc)
		var s: Sequence = seq(doc)
		if media_id.is_empty() and clip_id.is_empty() and not marker_dict.has("anchor"):
			marker_dict.merge(Follow.new_marker_fields(s, float(marker_dict.get("time", 0.0))))
		if media_id.is_empty() and clip_id.is_empty():
			marker_dict.merge(Layers.new_marker_fields(s, marker_dict))
		var m: Marker = Marker.from_dict(marker_dict)
		if m.id.is_empty() or find(doc, m.id) != null:
			ok = false
			return
		list.append(m)
		sort_list(doc)
		doc.touch("markers")

	func undo(doc: Project) -> void:
		var m: Marker = find(doc, str(marker_dict.get("id", "")))
		if m != null:
			markers(doc).erase(m)
		doc.touch("markers")


class RemoveMarker extends MarkerCommand:
	var marker_id: String = ""
	var marker_dict: Dictionary = {}

	func _init(p_seq_id: String, p_clip_id: String, p_marker_id: String) -> void:
		label = "Remove marker"
		seq_id = p_seq_id
		clip_id = p_clip_id
		marker_id = p_marker_id

	func do(doc: Project) -> void:
		var m: Marker = find(doc, marker_id)
		if m == null:
			ok = false
			return
		marker_dict = m.to_dict()
		markers(doc).erase(m)
		doc.touch("markers")

	func undo(doc: Project) -> void:
		markers(doc).append(Marker.from_dict(marker_dict))
		sort_list(doc)
		doc.touch("markers")


class SetMarker extends MarkerCommand:
	var marker_id: String = ""
	var fields: Dictionary = {}
	var old: Dictionary = {}

	func _init(p_seq_id: String, p_clip_id: String, p_marker_id: String, p_fields: Dictionary) -> void:
		label = "Edit marker"
		seq_id = p_seq_id
		clip_id = p_clip_id
		marker_id = p_marker_id
		fields = p_fields.duplicate(true)

	func live_key() -> String:
		return "marker|" + seq_id + "|" + clip_id + "|" + media_id + "|" + marker_id

	func do(doc: Project) -> void:
		var m: Marker = find(doc, marker_id)
		if m == null:
			ok = false
			return
		old = m.to_dict()
		var d: Dictionary = old.duplicate(true)
		for k: String in fields.keys():
			d[k] = fields[k]
		d["id"] = marker_id
		m.apply_dict(d)
		sort_list(doc)
		doc.touch("markers")

	func undo(doc: Project) -> void:
		var m: Marker = find(doc, marker_id)
		if m != null:
			m.apply_dict(old)
		sort_list(doc)
		doc.touch("markers")


class SetMarkerLayers extends "res://doc/commands/command.gd":
	var layers_next: Array = []
	var view_next: Dictionary = {}
	var layers_old: Array = []
	var view_old: Dictionary = {}

	func _init(p_seq_id: String, p_layers: Array, p_view: Dictionary, p_label: String = "Marker lanes") -> void:
		label = p_label
		seq_id = p_seq_id
		layers_next = p_layers.duplicate(true)
		view_next = p_view.duplicate(true)

	static func put(s: Sequence, list: Array, view: Dictionary) -> void:
		var typed: Array[Dictionary] = []
		for e: Variant in list:
			if e is Dictionary and not str((e as Dictionary).get("id", "")).is_empty():
				typed.append((e as Dictionary).duplicate(true))
		s.marker_layers = typed
		s.marker_view = view.duplicate(true)

	func do(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null:
			ok = false
			return
		layers_old = s.marker_layers.duplicate(true)
		view_old = s.marker_view.duplicate(true)
		put(s, layers_next, view_next)
		doc.touch("markers")

	func undo(doc: Project) -> void:
		var s: Sequence = seq(doc)
		if s == null:
			return
		put(s, layers_old, view_old)
		doc.touch("markers")

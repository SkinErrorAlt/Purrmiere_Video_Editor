extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Verbs := preload("res://doc/verbs.gd")
const Subtitles := preload("res://doc/subtitles.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")

const THIS := "this"
const PICKED := "picked"
const GROUP := "group"
const SHARED := "shared"
const TRACK := "track"
const ORDER: PackedStringArray = [THIS, PICKED, GROUP, SHARED, TRACK]
const LABELS: Dictionary = {
	THIS: "This box",
	PICKED: "Selected boxes",
	GROUP: "This group",
	SHARED: "Boxes sharing this title",
	TRACK: "Every text on this track",
}


static func is_text(doc: Project, c: Clip) -> bool:
	if doc == null or c == null:
		return false
	var m: MediaItem = doc.media_by_id(c.media_id)
	return m != null and m.kind == "title"


static func ids_for(doc: Project, seq: Sequence, c: Clip, scope: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null or seq == null or c == null:
		return out
	if scope == PICKED:
		for id: String in seq.selected_clip_ids:
			var p: Clip = seq.clip_by_id(id)
			if is_text(doc, p) and not out.has(id):
				out.append(id)
		if not out.has(c.id):
			out.append(c.id)
		return out
	if scope == GROUP or scope == SHARED or scope == TRACK:
		var tr: Track = seq.track_of(c.id)
		var pool: Array[Track] = []
		if scope == TRACK and tr != null:
			pool.append(tr)
		else:
			pool = seq.all_tracks()
		for t: Track in pool:
			for o: Clip in t.clips:
				if not is_text(doc, o):
					continue
				var hit: bool = false
				if scope == GROUP:
					hit = not c.group_id.is_empty() and o.group_id == c.group_id
				elif scope == SHARED:
					hit = o.media_id == c.media_id
				else:
					hit = true
				if hit or o.id == c.id:
					out.append(o.id)
		return out
	out.append(c.id)
	return out


static func choices(doc: Project, seq: Sequence, c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sc: String in ORDER:
		var n: int = ids_for(doc, seq, c, sc).size()
		if sc != THIS and n <= 1:
			continue
		var label: String = String(LABELS[sc])
		if sc != THIS:
			label += " (%d)" % n
		out.append({"id": sc, "label": label, "count": n})
	return out


static func usable(doc: Project, seq: Sequence, c: Clip, scope: String) -> String:
	for ch: Dictionary in choices(doc, seq, c):
		if String(ch["id"]) == scope:
			return scope
	return THIS


static func write_prop(doc: Project, seq: Sequence, ids: PackedStringArray, key: String, value: Variant) -> bool:
	if doc == null or seq == null or ids.is_empty():
		return false
	var path: String = "props." + key
	var bus: Object = Bus.instance()
	if ids.size() == 1:
		var c1: Clip = seq.clip_by_id(ids[0])
		if c1 == null:
			return false
		return Verbs.set_clip_param(doc, seq, c1.id, path, value, float(bus.call("key_time_for", c1, path, seq.playhead)), false)
	if doc.undo.has_live():
		doc.undo.commit_live("Edit text")
	var changed: bool = false
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null:
			continue
		if Verbs.set_clip_param(doc, seq, c.id, path, value, float(bus.call("key_time_for", c, path, seq.playhead)), true):
			changed = true
	if doc.undo.has_live():
		doc.undo.commit_live("Set " + key.replace("_", " ") + " on %d boxes" % ids.size())
	return changed


static func apply_style(doc: Project, seq: Sequence, ids: PackedStringArray, style: Dictionary) -> bool:
	return Subtitles.apply_style(doc, seq, ids, style)

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")

const KIND := "adjust"
const GRAPH_KEY := "adjust"
const STAGE_KEY := "adjust_stage"
const COVERS_KEY := "adjust_covers"
const COVERS_ABOVE := "above"
const COVERS_ALL := "all"
const COVERS: PackedStringArray = ["above", "all"]
const COVERS_LABELS: Dictionary = {"above": "Tracks above it", "all": "Every track"}
const COVERS_HINTS: Dictionary = {
	"above": "Changes the sound of every track above this one, and the sound of picture tracks. Clips on its own track and the tracks below are not changed.",
	"all": "Changes the sound of every track in the sequence, its own track and the tracks below too.",
}
const EVERY_INDEX := 1000000
const OUTSIDE_INDEX := 2000000
const PICTURE_INDEX := -1
const FADE_SHAPE_CODES: Dictionary = {"linear": 0, "equal_power": 1, "s_curve": 2}


static func is_adjust_media(m: MediaItem) -> bool:
	return m != null and m.kind == KIND


static func drops_on(item: MediaItem, target: Track) -> bool:
	return is_adjust_media(item) and target != null and not target.accepts("video") and target.accepts("audio")


static func is_sound_adjust(doc: Project, tr: Track, c: Clip) -> bool:
	if doc == null or tr == null or c == null or not tr.is_sound(c):
		return false
	return is_adjust_media(doc.media_by_id(c.media_id))


static func covers_of(c: Clip) -> String:
	var v: String = String(c.audio.get(COVERS_KEY, COVERS_ABOVE)) if c != null else COVERS_ABOVE
	return v if COVERS.has(v) else COVERS_ABOVE


static func clips_in(doc: Project, seq: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null or seq == null:
		return out
	for i: int in seq.audio_tracks.size():
		var tr: Track = seq.audio_tracks[i]
		for c: Clip in tr.clips:
			if not is_sound_adjust(doc, tr, c):
				continue
			var every: bool = covers_of(c) == COVERS_ALL
			out.append({"clip": c, "track": tr, "index": EVERY_INDEX if every else i})
	out.sort_custom(_before)
	return out


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["index"]) != int(b["index"]):
		return int(a["index"]) < int(b["index"])
	var ca: Clip = a["clip"]
	var cb: Clip = b["clip"]
	if ca.start != cb.start:
		return ca.start < cb.start
	return ca.id < cb.id


static func heard(found: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f: Dictionary in found:
		var c: Clip = f["clip"]
		var tr: Track = f["track"]
		if c.enabled and not tr.muted and c.duration > 0.0:
			out.append(f)
	return out


static func entry_of(c: Clip) -> Dictionary:
	var effects: Array = []
	for ae: Variant in c.audio_effects():
		if ae is Dictionary:
			effects.append((ae as Dictionary).duplicate(true))
	var dur: float = maxf(c.duration, 0.0)
	return {
		"id": c.id,
		"start": c.start,
		"duration": dur,
		"fade_in": clampf(float(c.audio.get("fade_in", 0.0)), 0.0, dur),
		"fade_out": clampf(float(c.audio.get("fade_out", 0.0)), 0.0, dur),
		"fade_shape": float(FADE_SHAPE_CODES.get(String(c.audio.get("fade_shape", "linear")), 0)),
		"volume": (c.audio.get("volume", AnimProp.make(1.0)) as Dictionary).duplicate(true),
		"effects": effects,
	}


static func track_index(seq: Sequence, entry: Dictionary) -> int:
	if bool(entry.get("outside", false)):
		return OUTSIDE_INDEX
	var owner: String = String(entry.get("owner", ""))
	if owner.is_empty():
		owner = String(entry.get("id", ""))
	for i: int in seq.audio_tracks.size():
		if seq.audio_tracks[i].id == owner:
			return i
	return PICTURE_INDEX


static func stage_for(index: int, order: PackedInt32Array) -> int:
	var n: int = 0
	for k: int in order:
		if k <= index:
			n += 1
	return n


static func stamp(doc: Project, seq: Sequence, graph: Dictionary) -> int:
	var found: Array[Dictionary] = heard(clips_in(doc, seq))
	if found.is_empty():
		return 0
	var list: Array = []
	var order: PackedInt32Array = PackedInt32Array()
	for f: Dictionary in found:
		list.append(entry_of(f["clip"]))
		order.append(int(f["index"]))
	for t: Variant in graph.get("tracks", []):
		if t is Dictionary:
			(t as Dictionary)[STAGE_KEY] = stage_for(track_index(seq, t as Dictionary), order)
	graph[GRAPH_KEY] = list
	return list.size()


static func stage_of_track(graph: Dictionary, track_id: String) -> int:
	for t: Variant in graph.get("tracks", []):
		var td: Dictionary = t
		if String(td.get("id", "")) == track_id:
			return int(td.get(STAGE_KEY, 0))
	return -1


static func covered_tracks(doc: Project, seq: Sequence, c: Clip) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null or seq == null or c == null:
		return out
	var own: Track = seq.track_of(c.id)
	var at: int = seq.audio_tracks.find(own)
	var every: bool = covers_of(c) == COVERS_ALL
	for i: int in seq.audio_tracks.size():
		if every or i < at:
			out.append(seq.audio_tracks[i].label if not seq.audio_tracks[i].label.is_empty() else "A" + str(i + 1))
	return out

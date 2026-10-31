extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const StreamLanes := preload("res://engine/stream_lanes.gd")

static var export_holds: int = 0
static var enabled: bool = true
static var applied: int = 0


static func seen() -> bool:
	return Track.listen_seen or Clip.listen_seen


static func hold() -> void:
	export_holds += 1


static func release() -> void:
	export_holds = maxi(export_holds - 1, 0)


static func muted_ids(seq: Sequence) -> Dictionary:
	var tracks: Dictionary = {}
	var clips: Dictionary = {}
	if seq != null and seen():
		for t: Track in seq.all_tracks():
			if t.listen_muted:
				tracks[t.id] = true
			for c: Clip in t.clips:
				if c.listen_muted:
					clips[c.id] = true
	return {"tracks": tracks, "clips": clips}


static func _clip_hit(clips: Dictionary, id: String) -> bool:
	if clips.has(id):
		return true
	var at: int = id.find(StreamLanes.COPY_TAG)
	return at > 0 and clips.has(id.substr(0, at))


static func apply(graph: Dictionary, seq: Sequence) -> Dictionary:
	if not enabled or export_holds > 0 or seq == null or not seen():
		return graph
	var ids: Dictionary = muted_ids(seq)
	var tracks: Dictionary = ids["tracks"]
	var clips: Dictionary = ids["clips"]
	if tracks.is_empty() and clips.is_empty():
		return graph
	var out: Dictionary = graph.duplicate(true)
	for v: Variant in out.get("tracks", []):
		if not (v is Dictionary):
			continue
		var tr: Dictionary = v
		if tracks.has(String(tr.get("owner", ""))) or tracks.has(String(tr.get("id", ""))):
			tr["muted"] = true
		for cv: Variant in tr.get("clips", []):
			if cv is Dictionary and _clip_hit(clips, String((cv as Dictionary).get("id", ""))):
				(cv as Dictionary)["muted"] = true
	applied += 1
	return out

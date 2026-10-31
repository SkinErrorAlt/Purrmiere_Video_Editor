extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const EXPORT_JOB := "res://modules/export/export_job.gd"

static var suspended: int = 0
static var filtered_last: bool = false
static var dropped_total: int = 0
static var enabled: bool = true


static func any_seen() -> bool:
	return Clip.view_hidden_seen or Track.view_hidden_seen


static func is_hidden(c: Clip, tr: Track) -> bool:
	return (c != null and c.view_hidden) or (tr != null and tr.view_hidden)


static func exporting(comp: Node) -> bool:
	var job: Variant = load(EXPORT_JOB) if ResourceLoader.exists(EXPORT_JOB) else null
	if job is GDScript and int((job as GDScript).get("compositor_holders")) > 0:
		return true
	return comp != null and comp.has_method("_exporting_now") and bool(comp.call("_exporting_now"))


static func active(comp: Node) -> bool:
	return enabled and suspended == 0 and any_seen() and not exporting(comp)


static func filter(comp: Node, s: Sequence, plan: Array[Dictionary]) -> Array[Dictionary]:
	if not any_seen():
		return plan
	if not active(comp):
		return plan
	var tracks: Array[Track] = s.picture_tracks()
	var out: Array[Dictionary] = []
	for e: Dictionary in plan:
		var ti: int = int(e.get("track", -1))
		var tr: Track = tracks[ti] if ti >= 0 and ti < tracks.size() else null
		if is_hidden(e.get("clip") as Clip, tr):
			dropped_total += 1
			filtered_last = true
			continue
		out.append(e)
	return out

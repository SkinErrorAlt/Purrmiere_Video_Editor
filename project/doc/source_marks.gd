extends RefCounted

const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Marker := preload("res://doc/marker.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Project := preload("res://doc/project.gd")
const Command := preload("res://doc/commands/command.gd")
const MarkerCmds := preload("res://doc/commands/marker_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const SAME_EPS := 0.0005
const BISECT_STEPS := 24

static var enabled: bool = true


static func first_at_or_after(list: Array[Marker], t: float) -> int:
	var lo: int = 0
	var hi: int = list.size()
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if list[mid].time < t:
			lo = mid + 1
		else:
			hi = mid
	return lo


static func local_of(c: Clip, source_t: float) -> float:
	if not AnimProp.is_animated(c.speed):
		var v: float = float(c.speed.get("v", 1.0))
		if absf(v) < 0.000001:
			return -1.0
		return (source_t - c.in_offset) / v
	var lo: float = 0.0
	var hi: float = c.duration
	var a: float = c.source_time(c.start)
	var b: float = c.source_time(c.start + c.duration)
	var rising: bool = b >= a
	if (rising and (source_t < a or source_t > b)) or (not rising and (source_t > a or source_t < b)):
		return -1.0
	for i: int in BISECT_STEPS:
		var mid: float = (lo + hi) * 0.5
		var at: float = c.source_time(c.start + mid)
		if (at < source_t) == rising:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


static func on_clip(c: Clip, item: MediaItem) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not enabled or c == null or item == null or item.markers.is_empty() or c.duration <= 0.0:
		return out
	var s0: float = c.source_in()
	var s1: float = c.source_out()
	var i: int = first_at_or_after(item.markers, s0)
	while i < item.markers.size():
		var m: Marker = item.markers[i]
		if m.time > s1:
			break
		var u: float = local_of(c, m.time)
		if u >= -0.0001 and u <= c.duration + 0.0001:
			var spd: float = absf(float(c.speed.get("v", 1.0))) if not AnimProp.is_animated(c.speed) else 1.0
			out.append({"marker": m, "local": u, "length": m.duration / maxf(spd, 0.000001)})
		i += 1
	return out


static func add(doc: Project, media_id: String, t: float, fields: Dictionary = {}) -> String:
	if doc == null:
		return ""
	var item: MediaItem = doc.media_by_id(media_id)
	if item == null:
		return ""
	for m: Marker in item.markers:
		if absf(m.time - t) < SAME_EPS:
			return ""
	var d: Dictionary = fields.duplicate()
	d["id"] = doc.mint_id("k")
	d["time"] = maxf(t, 0.0)
	var cmd: Command = MarkerCmds.AddMarker.new("", "", d).on_media(media_id)
	if not Verbs.run(doc, "Add source marker", [cmd]):
		return ""
	return String(d["id"])


static func remove(doc: Project, media_id: String, marker_id: String) -> bool:
	if doc == null:
		return false
	return Verbs.run(doc, "Remove source marker", [MarkerCmds.RemoveMarker.new("", "", marker_id).on_media(media_id)])


static func set_fields(doc: Project, media_id: String, marker_id: String, fields: Dictionary, label: String = "Edit source marker") -> bool:
	if doc == null or fields.is_empty():
		return false
	return Verbs.run(doc, label, [MarkerCmds.SetMarker.new("", "", marker_id, fields).on_media(media_id)])


static func near(item: MediaItem, t: float, reach: float) -> Marker:
	if item == null:
		return null
	var best: Marker = null
	var best_d: float = reach
	for m: Marker in item.markers:
		var dist: float = absf(m.time - t)
		if dist <= best_d:
			best_d = dist
			best = m
	return best


static func next_time(item: MediaItem, t: float, dir: int) -> float:
	if item == null:
		return -1.0
	var out: float = -1.0
	for m: Marker in item.markers:
		if dir > 0 and m.time > t + SAME_EPS:
			return m.time
		if dir < 0 and m.time < t - SAME_EPS:
			out = m.time
	return out

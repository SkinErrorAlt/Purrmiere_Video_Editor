extends RefCounted

const Marker := preload("res://doc/marker.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Clip := preload("res://doc/clip.gd")
const KIND := "sync"
const NONE := -1.0


static func sync_marks(item: MediaItem) -> Array[Marker]:
	var out: Array[Marker] = []
	if item == null:
		return out
	for m: Marker in item.markers:
		if m != null and m.kind == KIND:
			out.append(m)
	return out


static func sync_time(item: MediaItem) -> float:
	var marks: Array[Marker] = sync_marks(item)
	return marks[0].time if not marks.is_empty() else NONE


static func has_sync(item: MediaItem) -> bool:
	return sync_time(item) > NONE


static func aligned_in_offset(from_item: MediaItem, to_item: MediaItem, in_offset: float) -> float:
	var was: float = sync_time(from_item)
	var now: float = sync_time(to_item)
	if was <= NONE or now <= NONE:
		return NONE
	return now + (in_offset - was)


static func room_for(item: MediaItem, used: float) -> float:
	if item == null or item.duration <= 0.0:
		return 0.0
	return maxf(item.duration - used, 0.0)


static func fits(item: MediaItem, in_offset: float, used: float) -> bool:
	if in_offset < 0.0:
		return false
	return in_offset <= room_for(item, used) + 0.000001


static func drift_of(from_item: MediaItem, to_item: MediaItem, in_offset: float, used: float) -> float:
	var want: float = aligned_in_offset(from_item, to_item, in_offset)
	if want <= NONE:
		return NONE
	if fits(to_item, want, used):
		return 0.0
	var held: float = clampf(want, 0.0, room_for(to_item, used))
	return absf(want - held)


static func reason(from_item: MediaItem, to_item: MediaItem) -> String:
	if from_item == null or to_item == null:
		return "That bin item cannot replace this clip"
	if not has_sync(from_item):
		return "This clip's footage has no sync mark: put one on a moment you can see in both recordings"
	if not has_sync(to_item):
		return "The footage in the bin has no sync mark: put one on the same moment"
	return ""

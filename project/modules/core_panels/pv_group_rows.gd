extends RefCounted

const ViewMap := preload("res://doc/view_map.gd")
const EFFECT_ID := "pair_view"


static func group_of_key(key: String) -> int:
	if key == ViewMap.VIEW_KEY:
		return 0
	if key == ViewMap.VIEW2_KEY:
		return 1
	for g: int in range(2, ViewMap.GROUP_MAX):
		if key == ViewMap.view_key_for(g):
			return g
	return -1


static func is_group_key(key: String) -> bool:
	return key == ViewMap.GROUP_KEY or group_of_key(key) >= 1


static func hides(eid: String, key: String, e: Dictionary) -> bool:
	if eid != EFFECT_ID or not is_group_key(key):
		return false
	var m: Array[PackedInt32Array] = ViewMap.members(e)
	if not ViewMap.grouped(e) or m.size() < 2:
		return true
	if key == ViewMap.GROUP_KEY:
		return false
	return group_of_key(key) >= m.size()


static func cap(eid: String, key: String, e: Dictionary) -> float:
	if eid != EFFECT_ID or not ViewMap.grouped(e):
		return -1.0
	var m: Array[PackedInt32Array] = ViewMap.members(e)
	if key == ViewMap.GROUP_KEY:
		return maxf(float(m.size() - 1), 0.0)
	var g: int = group_of_key(key)
	if g < 0 or g >= m.size():
		return -1.0
	return maxf(float(m[g].size() - 1), 0.0)


static func hides_all(eid: String, key: String, entries: Array) -> bool:
	if eid != EFFECT_ID or not is_group_key(key):
		return false
	for e: Variant in entries:
		if e is Dictionary and not hides(eid, key, e):
			return false
	return true

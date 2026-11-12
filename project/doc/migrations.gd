extends RefCounted

# Saves write this number (Project.FORMAT_VERSION). Raise it, with a step below, whenever the file gains
# something an older build would drop, so that build opens the file without saving over it.
const CURRENT_VERSION := 3
const PAIR_VIEW := "pair_view"
const CROP_MAX := 8
const FreeTransition := preload("res://doc/free_transition.gd")


static func steps() -> Dictionary:
	return {
		0: _from_0_to_1,
		1: _from_1_to_2,
		2: _from_2_to_3,
	}


static func version_of(d: Dictionary) -> int:
	var v: Variant = d.get("format_version", 0)
	if v is int or v is float:
		return int(v)
	return 0


static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var v: int = version_of(out)
	var table: Dictionary = steps()
	while v < CURRENT_VERSION:
		if not table.has(v):
			print("Migrations: no step from format version " + str(v) + ", the file is loaded as is")
			break
		var step: Callable = table[v]
		out = step.call(out)
		v += 1
		out["format_version"] = v
	if v > CURRENT_VERSION:
		print("Migrations: the file is format version " + str(v) + " and this build reads up to " + str(CURRENT_VERSION) + ", so it opens but is not saved over")
	out["format_version"] = v
	return out


static func _from_0_to_1(d: Dictionary) -> Dictionary:
	return d


static func _from_1_to_2(d: Dictionary) -> Dictionary:
	var fixed: int = 0
	for s: Variant in _list(d, "sequences"):
		if not (s is Dictionary):
			continue
		for key: String in ["video_tracks", "audio_tracks"]:
			for t: Variant in _list(s, key):
				if not (t is Dictionary):
					continue
				for c: Variant in _list(t, "clips"):
					if not (c is Dictionary):
						continue
					for e: Variant in _list(c, "effects"):
						if e is Dictionary and String((e as Dictionary).get("id", "")) == PAIR_VIEW:
							if pair_view_crops(e):
								fixed += 1
	if fixed > 0:
		print("Migrations: rebuilt the crops of " + str(fixed) + " pair view effects from their saved crop boxes")
	return d


static func _from_2_to_3(d: Dictionary) -> Dictionary:
	var tidied: int = 0
	var dropped: int = 0
	for s: Variant in _list(d, "sequences"):
		if not (s is Dictionary):
			continue
		for key: String in ["video_tracks", "audio_tracks"]:
			for t: Variant in _list(s, key):
				if not (t is Dictionary):
					continue
				var track: Dictionary = t
				if not track.has(FreeTransition.FIELD):
					continue
				var raw: Variant = track[FreeTransition.FIELD]
				if not (raw is Array):
					track.erase(FreeTransition.FIELD)
					dropped += 1
					continue
				var was: int = (raw as Array).size()
				var list: Array[Dictionary] = FreeTransition.normalise_list(raw)
				if list.is_empty():
					track.erase(FreeTransition.FIELD)
					dropped += was
					continue
				var fixed: Array = FreeTransition.to_array(list)
				if fixed != raw:
					tidied += 1
				dropped += was - list.size()
				track[FreeTransition.FIELD] = fixed
	if tidied > 0 or dropped > 0:
		print("Migrations: tidied the free transitions on " + str(tidied) + " tracks and dropped " + str(dropped) + " that could not be read")
	return d


static func _list(d: Variant, key: String) -> Array:
	if not (d is Dictionary):
		return []
	var v: Variant = (d as Dictionary).get(key, null)
	return v if v is Array else []


static func value_of(raw: Variant) -> Variant:
	if not (raw is Dictionary):
		return raw
	var p: Dictionary = raw
	if p.has("v"):
		return p["v"]
	if p.has("base"):
		return p["base"]
	return null


static func _number(raw: Variant, fallback: float) -> float:
	var v: Variant = value_of(raw)
	if v is float or v is int:
		return float(v)
	return fallback


static func needs_crops(e: Dictionary) -> bool:
	var params: Variant = e.get("params", null)
	if not (params is Dictionary):
		return false
	var p: Dictionary = params
	if not p.has("crop0"):
		return false
	if p.has("crops") and not String(value_of(p["crops"])).strip_edges().is_empty():
		return false
	return true


static func crops_text_from_boxes(p: Dictionary) -> String:
	var count: int = int(round(_number(p.get("crop_count", null), 1.0)))
	var list: Array = []
	for i: int in mini(maxi(count, 1), CROP_MAX):
		var rect: Variant = value_of(p.get("crop" + str(i), null))
		if not (rect is Array) or (rect as Array).size() < 4:
			continue
		var r: Array = rect
		list.append({
			"name": "",
			"rect": [float(r[0]), float(r[1]), maxf(float(r[2]), 0.001), maxf(float(r[3]), 0.001)],
			"rot": _number(p.get("crop_rot" + str(i), null), 0.0),
			"out": false,
		})
	if list.is_empty():
		return ""
	return JSON.stringify(list)


static func pair_view_crops(e: Dictionary) -> bool:
	if not needs_crops(e):
		return false
	var p: Dictionary = e["params"]
	var text: String = crops_text_from_boxes(p)
	if text.is_empty():
		return false
	p["crops"] = {"v": text}
	return true

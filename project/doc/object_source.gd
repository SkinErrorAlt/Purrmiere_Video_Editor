extends RefCounted

const MediaItem := preload("res://doc/media_item.gd")
const Clip := preload("res://doc/clip.gd")
const ObjectMask := preload("res://doc/object_mask.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const PROP := "object_of"
const MASK_LINK := "object_of"
const MASK_AT := "object_at"
const SUFFIX := " object"
const WHY_NOT_ONE := "this source is not a cut out object"
const WHY_SEQUENCE := "the sequence it was cut from is gone"
const WHY_CLIP := "the clip it was cut from is gone"
const WHY_MASK := "the object it was cut from is gone"
const WHY_EMPTY := "the object it was cut from has no tracked frames"
const FPS_FALLBACK := 30.0


static func is_source(item: MediaItem) -> bool:
	return item != null and item.is_object_source()


static func link_of(item: MediaItem) -> Dictionary:
	return item.object_of() if item != null else {}


static func mask_link_of(m: Dictionary) -> Dictionary:
	var v: Variant = m.get(MASK_LINK, null)
	return v if v is Dictionary else {}


static func is_linked_mask(m: Dictionary) -> bool:
	return ObjectMask.is_object(m) and not mask_link_of(m).is_empty()


static func frame_offset(m: Dictionary) -> int:
	return int(m.get(MASK_AT, 0))


static func has_linked_mask(c: Clip) -> bool:
	if c == null:
		return false
	for m: Dictionary in c.masks:
		if is_linked_mask(m):
			return true
	return false


static func span_of(m: Dictionary, store: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	var frames: PackedInt32Array = ObjectMask.key_frames(m)
	var lo: int = frames[0] if not frames.is_empty() else -1
	var hi: int = frames[frames.size() - 1] if not frames.is_empty() else -1
	if store.x >= 0:
		lo = store.x if lo < 0 else mini(lo, store.x)
		hi = maxi(hi, store.y)
	if lo < 0:
		return Vector2i(-1, -1)
	return Vector2i(lo, maxi(hi, lo))


static func frames_of(link: Dictionary) -> int:
	return maxi(int(link.get("to", 0)) - int(link.get("from", 0)) + 1, 1)


static func rate_of(link: Dictionary) -> float:
	var fps: float = float(link.get("fps", FPS_FALLBACK))
	return fps if fps > 0.0 else FPS_FALLBACK


static func duration_of(link: Dictionary) -> float:
	return float(frames_of(link)) / rate_of(link)


static func ramped(link: Dictionary) -> bool:
	return bool(link.get("ramped", false))


static func link_dict(seq_id: String, c: Clip, mask: Dictionary, span: Vector2i, fps: float) -> Dictionary:
	var rate: float = fps if fps > 0.0 else FPS_FALLBACK
	var out: Dictionary = {"seq": seq_id, "clip": "", "mask": String(mask.get("id", "")), "from": span.x, "to": maxi(span.y, span.x), "fps": rate, "in": 0.0, "speed": 1.0}
	if c == null:
		return out
	out["clip"] = c.id
	out["in"] = c.source_time(c.start + float(span.x) / rate)
	if AnimProp.is_animated(c.speed):
		out["ramped"] = true
	else:
		out["speed"] = float(c.speed.get("v", 1.0))
	return out


static func label_for(c: Clip, mask: Dictionary, src: MediaItem) -> String:
	var stem: String = String(mask.get("label", ""))
	if stem.is_empty() and c != null:
		stem = c.label
	if stem.is_empty() and src != null:
		stem = src.label
	if stem.is_empty():
		stem = "Object"
	return stem + SUFFIX


static func item_dict(id: String, src: MediaItem, link: Dictionary, label: String) -> Dictionary:
	var d: Dictionary = {"id": id, "kind": src.kind if src != null else "video", "label": label, "probed": true, "duration": duration_of(link), "props": {PROP: link.duplicate(true)}}
	if src == null:
		return d
	if not src.path.is_empty():
		d["path"] = src.path
	if src.width > 0:
		d["width"] = src.width
	if src.height > 0:
		d["height"] = src.height
	if src.fps > 0.0:
		d["fps"] = src.fps
	if not src.bin.is_empty():
		d["bin"] = src.bin
	return d


static func mask_dict(mask_id: String, link: Dictionary, label: String, from: Dictionary = {}) -> Dictionary:
	var m: Dictionary = ObjectMask.make(mask_id, label)
	m[MASK_LINK] = link.duplicate(true)
	m[MASK_AT] = int(link.get("from", 0))
	if not from.is_empty():
		m["region"] = (from.get("region", [0.0, 0.0, 1.0, 1.0]) as Array).duplicate()
		m["side"] = int(from.get("side", ObjectMask.MATTE_SIDE))
	return m


static func clip_extras(item: MediaItem, mask_id: String, from: Dictionary = {}) -> Dictionary:
	var link: Dictionary = link_of(item)
	if link.is_empty():
		return {}
	var out: Dictionary = {"in_offset": float(link.get("in", 0.0)), "masks": [mask_dict(mask_id, link, item.label if item != null else "", from)]}
	var sp: float = float(link.get("speed", 1.0))
	if sp > 0.0 and not is_equal_approx(sp, 1.0):
		out["speed"] = AnimProp.make(sp)
	return out


static func resolve(doc: Object, link: Dictionary) -> Dictionary:
	var out: Dictionary = {"ok": false, "why": WHY_NOT_ONE, "mask": {}, "clip": null}
	if doc == null or link.is_empty():
		return out
	var s: Object = doc.call("sequence_by_id", String(link.get("seq", "")))
	if s == null:
		out["why"] = WHY_SEQUENCE
		return out
	var c: Clip = s.call("clip_by_id", String(link.get("clip", "")))
	if c == null:
		out["why"] = WHY_CLIP
		return out
	var want: String = String(link.get("mask", ""))
	for m: Dictionary in c.masks:
		if String(m.get("id", "")) != want or not ObjectMask.is_object(m) or is_linked_mask(m):
			continue
		out["mask"] = m
		out["clip"] = c
		out["ok"] = true
		out["why"] = ""
		return out
	out["why"] = WHY_MASK
	return out


static func state_of(doc: Object, item: MediaItem, store_frames: int = 0) -> Dictionary:
	var link: Dictionary = link_of(item)
	if link.is_empty():
		return {"ok": false, "why": WHY_NOT_ONE, "frames": 0, "from": -1, "to": -1}
	var got: Dictionary = resolve(doc, link)
	var out: Dictionary = {"ok": false, "why": String(got["why"]), "frames": 0, "from": int(link.get("from", -1)), "to": int(link.get("to", -1))}
	if not bool(got["ok"]):
		return out
	var m: Dictionary = got["mask"]
	out["frames"] = maxi(ObjectMask.key_frames(m).size(), maxi(store_frames, 0))
	if int(out["frames"]) <= 0:
		out["why"] = WHY_EMPTY
		return out
	out["ok"] = true
	out["why"] = ""
	return out

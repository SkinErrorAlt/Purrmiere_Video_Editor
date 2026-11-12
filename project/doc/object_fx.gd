extends RefCounted

const ObjectMask := preload("res://doc/object_mask.gd")
const EFFECT_ID := "object_select"


static func is_object_fx(e: Dictionary) -> bool:
	return str(e.get("id", "")) == EFFECT_ID


static func entry_of(c: Object) -> Dictionary:
	if c == null:
		return {}
	for e: Dictionary in c.get("effects"):
		if is_object_fx(e):
			return e
	return {}


static func object_id(c: Object) -> String:
	if c == null:
		return ""
	for m: Dictionary in c.get("masks"):
		if ObjectMask.is_object(m):
			return str(m.get("id", ""))
	return ""


static func count(c: Object) -> int:
	var n: int = 0
	if c == null:
		return n
	for m: Dictionary in c.get("masks"):
		if ObjectMask.is_object(m):
			n += 1
	return n


static func ensure_mask(doc: Object, c: Object) -> Dictionary:
	var out: Dictionary = {"id": "", "made": false}
	if doc == null or c == null:
		return out
	var found: String = object_id(c)
	if not found.is_empty():
		out["id"] = found
		return out
	var masks: Array = c.get("masks")
	var mask: Dictionary = ObjectMask.make(String(doc.call("mint_id", "mask")), "Object " + str(count(c) + 1))
	masks.append(mask)
	out["id"] = str(mask.get("id", ""))
	out["made"] = true
	return out


static func drop_mask(c: Object, mask_id: String) -> void:
	if c == null or mask_id.is_empty():
		return
	var masks: Array = c.get("masks")
	for i: int in masks.size():
		if str((masks[i] as Dictionary).get("id", "")) == mask_id:
			masks.remove_at(i)
			return

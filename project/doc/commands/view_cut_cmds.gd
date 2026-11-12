extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ViewMap := preload("res://doc/view_map.gd")
const ViewSwitch := preload("res://doc/view_switch.gd")
const SELF := preload("res://doc/commands/view_cut_cmds.gd")
const LABEL := "Move view cut"


class MoveViewCut extends "res://doc/commands/command.gd":
	var clip_id: String = ""
	var uid: String = ""
	var from_u: float = 0.0
	var to_u: float = 0.0
	var _old: Dictionary = {}

	func _init(p_seq_id: String, p_clip_id: String, p_uid: String, p_from_u: float, p_to_u: float) -> void:
		label = LABEL
		seq_id = p_seq_id
		clip_id = p_clip_id
		uid = p_uid
		from_u = p_from_u
		to_u = p_to_u

	func live_key() -> String:
		return "view_cut|" + clip_id + "|" + uid + "|" + str(from_u)

	func do(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		if c == null:
			ok = false
			return
		var e: Dictionary = c.effect_by_uid(uid)
		var params: Dictionary = e.get("params", {}) if e.get("params", null) is Dictionary else {}
		_old = {}
		for key: Variant in params.keys():
			var p: Variant = params[key]
			if not (p is Dictionary) or not AnimProp.is_animated(p):
				continue
			var kt0: float = ViewSwitch.key_time(c, e, String(key), from_u)
			var kt1: float = ViewSwitch.key_time(c, e, String(key), to_u)
			var moved: Dictionary = SELF.moved_key(p, kt0, kt1)
			if moved.is_empty():
				continue
			_old[key] = (p as Dictionary).duplicate(true)
			params[key] = moved
		if _old.is_empty():
			ok = false
			return
		doc.touch("structure")

	func undo(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		if c == null:
			return
		var params: Dictionary = c.effect_by_uid(uid).get("params", {})
		for key: Variant in _old.keys():
			params[key] = (_old[key] as Dictionary).duplicate(true)
		doc.touch("structure")


static func moved_key(p: Dictionary, from_t: float, to_t: float) -> Dictionary:
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0 or AnimProp.find_key(p, from_t) < 0:
		return {}
	if absf(from_t - to_t) <= AnimProp.KEY_TOLERANCE:
		return {}
	var out: Dictionary = p.duplicate(true)
	var ks: Array = (out["layers"][li] as Dictionary).get("keys", [])
	for k: Variant in ks:
		if k is Dictionary and absf(float((k as Dictionary).get("t", 0.0)) - from_t) <= AnimProp.KEY_TOLERANCE:
			(k as Dictionary)["t"] = to_t
			break
	ks.sort_custom(func(a: Variant, b: Variant) -> bool: return float((a as Dictionary).get("t", 0.0)) < float((b as Dictionary).get("t", 0.0)))
	return out


static func cut_times(c: Clip) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var e: Dictionary = pair_entry(c)
	if e.is_empty():
		return out
	var chs: Array[Dictionary] = ViewMap.changes(e, c)
	for i: int in range(1, chs.size()):
		out.append(float(chs[i]["u"]))
	return out


static func pair_entry(c: Clip) -> Dictionary:
	if c == null:
		return {}
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) == ViewMap.PAIR_VIEW_ID:
			return e
	return {}


static func bounds(c: Clip, from_u: float, frame: float) -> Vector2:
	var cuts: PackedFloat64Array = cut_times(c)
	var lo: float = frame
	var hi: float = c.duration - frame
	for u: float in cuts:
		if u < from_u - AnimProp.KEY_TOLERANCE:
			lo = maxf(lo, u + frame)
		elif u > from_u + AnimProp.KEY_TOLERANCE:
			hi = minf(hi, u - frame)
	return Vector2(lo, maxf(lo, hi))

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const SEED_SPAN := 1000000

static var plant_same_seed: bool = false


static func make(lo: float, hi: float, seed: int, whole: bool) -> Dictionary:
	var p: Dictionary = AnimProp.make_range(lo, hi, seed)
	if whole:
		var r: Array = AnimProp.range_of(p)
		p["v"] = clampf(round(float(p["v"])), ceilf(float(r[0])), floorf(float(r[1])))
	return p


static func new_seed(old: int = -1) -> int:
	if plant_same_seed and old >= 0:
		return old
	var s: int = randi() % SEED_SPAN
	if s == old:
		s = (s + 1 + randi() % (SEED_SPAN - 1)) % SEED_SPAN
	return s


static func piece_value(p: Dictionary, index: int, fallback: float) -> float:
	if not AnimProp.is_range(p):
		return fallback
	var r: Array = AnimProp.range_of(p)
	var u: float = AnimProp.unit(AnimProp.range_seed(p) * 7919 + 13, index + 1) * 0.5 + 0.5
	return float(r[0]) + (float(r[1]) - float(r[0])) * u


static func stamp(p: Dictionary) -> String:
	if not AnimProp.is_range(p):
		return ""
	var r: Array = AnimProp.range_of(p)
	return "%.4f~%.4f~%d" % [float(r[0]), float(r[1]), AnimProp.range_seed(p)]


static func effect_param(c: Clip, uid: String, key: String) -> Dictionary:
	if c == null:
		return {}
	var e: Dictionary = c.effect_by_uid(uid)
	if e.is_empty() or not (e.get("params") is Dictionary):
		return {}
	var v: Variant = (e["params"] as Dictionary).get(key, {})
	return v if v is Dictionary else {}


static func _write_params(doc: Project, seq: Sequence, c: Clip, uid: String, key: String, prop: Dictionary, label: String) -> bool:
	var e: Dictionary = c.effect_by_uid(uid)
	if e.is_empty():
		return false
	var params: Dictionary = (e.get("params", {}) as Dictionary).duplicate(true) if e.get("params") is Dictionary else {}
	params[key] = prop
	var cmd := EffectCmds.SetEffectEntry.new(seq.id, c.id, uid, {"params": params}, c.is_audio_effect(uid), label)
	return _run(doc, label, cmd)


static func _run(doc: Project, label: String, cmd: Object) -> bool:
	var tx: Object = doc.undo.begin(label)
	tx.call("apply", cmd)
	return bool(tx.call("commit"))


static func set_range(doc: Project, seq: Sequence, clip_id: String, uid: String, key: String, lo: float, hi: float, whole: bool = false) -> String:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if doc == null or c == null:
		return "No clip"
	var old: Dictionary = effect_param(c, uid, key)
	if not old.is_empty() and AnimProp.is_animated(old):
		return "A range holds one value for the whole clip, so it works on a value without keyframes. Clear the keyframes first."
	var seed: int = AnimProp.range_seed(old) if AnimProp.is_range(old) else new_seed()
	var prop: Dictionary = make(lo, hi, seed, whole)
	if not _write_params(doc, seq, c, uid, key, prop, "Set a range"):
		return "The range could not be set"
	return ""


static func reroll(doc: Project, seq: Sequence, clip_id: String, uid: String, key: String, whole: bool = false) -> bool:
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if doc == null or c == null:
		return false
	var old: Dictionary = effect_param(c, uid, key)
	if not AnimProp.is_range(old):
		return false
	var r: Array = AnimProp.range_of(old)
	var prop: Dictionary = make(float(r[0]), float(r[1]), new_seed(AnimProp.range_seed(old)), whole)
	return _write_params(doc, seq, c, uid, key, prop, "Roll the range again")

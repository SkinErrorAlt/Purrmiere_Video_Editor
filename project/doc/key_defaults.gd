extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const AUTO := "auto"
const CHOICES: PackedStringArray = ["auto", "linear", "ease_both", "bezier", "hold"]
const LABELS: PackedStringArray = ["Auto (eased, hold for on and off values)", "Linear", "Ease in and out", "Bezier", "Hold"]
const BUILT_IN: Dictionary = {"pair_view.view": "hold", "pair_view.view2": "hold", "pair_view.layout": "hold", "pair_view.grid": "hold", "pair_view.view_mode": "hold", "pair_view.group": "hold", "pair_view.sound_view": "hold"}

static var everywhere: String = AUTO
static var by_value: Dictionary = {}


static func value_key(c: Object, path: String) -> String:
	var parts: PackedStringArray = path.split(".")
	if parts.size() == 3 and (parts[0] == "effects" or parts[0] == "audio_effects") and c != null:
		var e: Dictionary = c.call("audio_effect_by_uid", parts[1]) if parts[0] == "audio_effects" else c.call("effect_by_uid", parts[1])
		var eid: String = String(e.get("id", ""))
		if not eid.is_empty():
			return eid + "." + parts[2]
	return path


static func own_choice(vkey: String) -> String:
	var v: String = String(by_value.get(vkey, ""))
	return v if v in CHOICES else ""


static func choice_for(vkey: String) -> String:
	var own: String = own_choice(vkey)
	if not own.is_empty() and own != AUTO:
		return own
	if own.is_empty() and BUILT_IN.has(vkey):
		return String(BUILT_IN[vkey])
	return everywhere if everywhere in CHOICES else AUTO


static func fresh(c: Object, path: String, old: Dictionary, next: Dictionary) -> Dictionary:
	if not AnimProp.is_animated(next):
		return next
	var want: String = choice_for(value_key(c, path))
	if want == AUTO:
		return next
	var before: Array[Dictionary] = AnimProp.keys(old) if AnimProp.is_animated(old) else ([] as Array[Dictionary])
	var after: Array[Dictionary] = AnimProp.keys(next)
	if after.size() <= before.size():
		return next
	var out: Dictionary = next
	for k: Dictionary in after:
		var t: float = float(k.get("t", 0.0))
		if _has_time(before, t):
			continue
		if String(k.get("i", "")) != "ease_both" or k.has("ease") or k.has("dir"):
			continue
		out = AnimProp.set_key_fields(out, t, {"i": want})
	return out


static func _has_time(list: Array[Dictionary], t: float) -> bool:
	for k: Dictionary in list:
		if absf(float(k.get("t", 0.0)) - t) <= AnimProp.KEY_TOLERANCE:
			return true
	return false

extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const RangeValues := preload("res://doc/range_values.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const SEED_KEY := "seed"
const RANGE_TIP := "Type (low, high) to have one random value picked in that range and kept. Pieces of a breaking effect each pick their own."


static func wants_range(spec: Dictionary) -> bool:
	if not spec.has("fx_uid") or spec.has("members") or spec.has("component") or bool(spec.get("db", false)):
		return false
	var kind: String = String(spec.get("kind", ""))
	if kind != "float" and kind != "int":
		return false
	return String(spec.get("eid", "")) != "pair_view"


static func is_seed(spec: Dictionary) -> bool:
	return wants_range(spec) and String(spec.get("key", "")) == SEED_KEY and String(spec.get("kind", "")) == "int"


static func attach(panel: Object, f: Control, spec: Dictionary) -> void:
	if not wants_range(spec):
		return
	f.set("accepts_range", true)
	f.set("dice", is_seed(spec))
	f.tooltip_text = RANGE_TIP if not is_seed(spec) else "Press the dice for a new random seed. " + RANGE_TIP
	f.connect("range_typed", on_range.bind(panel, String(spec["path"])))
	f.connect("dice_pressed", on_dice.bind(panel, String(spec["path"])))


static func prop_of(panel: Object, spec: Dictionary) -> Dictionary:
	var c: Object = panel.call("target_clip")
	if c == null:
		return {}
	return RangeValues.effect_param(c, String(spec.get("uid", "")), String(spec.get("key", "")))


static func sync(panel: Object, f: Control, spec: Dictionary) -> void:
	if not bool(f.get("accepts_range")):
		return
	var p: Dictionary = prop_of(panel, spec)
	if AnimProp.is_range(p):
		var r: Array = AnimProp.range_of(p)
		var mul: float = float(spec.get("display_mul", 1.0))
		var d: int = 0 if String(spec.get("kind", "")) == "int" else int(f.call("decimals"))
		f.set("range_text", PmField.range_label(float(r[0]) * mul, float(r[1]) * mul, d))
		f.set("dice", true)
		f.tooltip_text = "Picked %s from this range. Press the dice to pick again, or type a single number to go back to one value." % String.num(float(p.get("v", 0.0)) * mul, maxi(d, 2))
	else:
		f.set("range_text", "")
		f.set("dice", is_seed(spec))
		f.tooltip_text = RANGE_TIP if not is_seed(spec) else "Press the dice for a new random seed. " + RANGE_TIP


static func _spec(panel: Object, path: String) -> Dictionary:
	var r: Dictionary = panel.call("_row_for", path)
	return r.get("spec", {}) if not r.is_empty() else {}


static func on_range(lo: float, hi: float, panel: Object, path: String) -> void:
	var spec: Dictionary = _spec(panel, path)
	var c: Object = panel.call("target_clip")
	if spec.is_empty() or c == null:
		return
	var mul: float = float(spec.get("display_mul", 1.0))
	var whole: bool = String(spec.get("kind", "")) == "int"
	var why: String = RangeValues.set_range(panel.call("doc"), panel.call("seq"), String(c.get("id")), String(spec["uid"]), String(spec["key"]), lo / mul, hi / mul, whole)
	if not why.is_empty():
		Events.toast(why)


static func on_dice(panel: Object, path: String) -> void:
	var spec: Dictionary = _spec(panel, path)
	var c: Object = panel.call("target_clip")
	if spec.is_empty() or c == null:
		return
	var whole: bool = String(spec.get("kind", "")) == "int"
	if AnimProp.is_range(prop_of(panel, spec)):
		RangeValues.reroll(panel.call("doc"), panel.call("seq"), String(c.get("id")), String(spec["uid"]), String(spec["key"]), whole)
		return
	if is_seed(spec):
		panel.call("_write", spec, new_seed_value(spec, int(round(float(panel.call("current_value", spec))))))


static func new_seed_value(spec: Dictionary, old: int) -> int:
	var lo: int = int(spec.get("min", 0.0)) if spec.has("min") else 0
	var hi: int = int(spec.get("max", 9999.0)) if spec.has("max") else 9999
	if hi <= lo:
		return lo
	var v: int = lo + randi() % (hi - lo + 1)
	if v == old:
		v = lo + ((v - lo + 1 + randi() % (hi - lo)) % (hi - lo + 1))
	return v

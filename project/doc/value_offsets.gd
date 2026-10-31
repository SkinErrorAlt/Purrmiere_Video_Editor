extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const FIELD := "offset"
const LABEL_FIELD := "label"
const BASE_REFUSAL := "The base value stays: it is what the offsets are added to. Remove the offsets above it instead."


static func is_offset(layer: Variant) -> bool:
	return layer is Dictionary and str((layer as Dictionary).get("type", "")) == "keys" and bool((layer as Dictionary).get(FIELD, false))


static func zero_like(v: Variant) -> Variant:
	if v is Array:
		var out: Array = []
		for x: Variant in v:
			out.append(0.0)
		return out
	return 0.0


static func layer_for(value: Variant, keys: Array = [], label: String = "") -> Dictionary:
	var ks: Array = []
	if keys.is_empty():
		ks.append({"t": 0.0, "v": AnimProp.norm(value), "i": "hold"})
	else:
		for k: Variant in keys:
			if k is Dictionary:
				ks.append((k as Dictionary).duplicate(true))
	return {"type": "keys", "on": true, "weight": 1.0, "blend": "add", "loop": "once", FIELD: true, LABEL_FIELD: label, "keys": ks}


static func with_offset(p: Dictionary, value: Variant, keys: Array = [], label: String = "") -> Dictionary:
	var out: Dictionary = p.duplicate(true) if not p.is_empty() else AnimProp.make(zero_like(value))
	if not AnimProp.is_animated(out):
		out = {"a": true, "base": AnimProp.static_value(out), "layers": []}
	(out["layers"] as Array).append(layer_for(value, keys, label))
	return out


static func indices(p: Dictionary) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if not AnimProp.is_animated(p):
		return out
	var layers: Array = p.get("layers", [])
	for i: int in layers.size():
		if is_offset(layers[i]):
			out.append(i)
	return out


static func count(p: Dictionary) -> int:
	return indices(p).size()


static func stack(p: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"kind": "base", "label": "Base value", "removable": false, "why": BASE_REFUSAL}]
	var layers: Array = p.get("layers", []) if AnimProp.is_animated(p) else []
	var n: int = 0
	for i: int in layers.size():
		if not is_offset(layers[i]):
			continue
		var l: Dictionary = layers[i]
		n += 1
		var lab: String = String(l.get(LABEL_FIELD, ""))
		out.append({"kind": "offset", "index": n - 1, "layer": i, "label": "Offset " + str(n) + ((", from " + lab) if not lab.is_empty() else ""), "removable": true, "on": bool(l.get("on", true))})
	return out


static func without_offset(p: Dictionary, nth: int) -> Dictionary:
	var at: PackedInt32Array = indices(p)
	if nth < 0 or nth >= at.size():
		return p.duplicate(true)
	return AnimProp.simplify(AnimProp.remove_layer(p, at[nth]))


static func can_remove(p: Dictionary, entry_kind: String) -> bool:
	return entry_kind == "offset" and count(p) > 0


static func toggled(p: Dictionary, nth: int, on: bool) -> Dictionary:
	var at: PackedInt32Array = indices(p)
	if nth < 0 or nth >= at.size():
		return p.duplicate(true)
	return AnimProp.set_layer_field(p, at[nth], "on", on)


static func part_offset(value: Variant, component: int, like: Variant) -> Variant:
	var base: Array = (like as Array).duplicate(true) if like is Array else [0.0, 0.0]
	for i: int in base.size():
		base[i] = 0.0
	while base.size() <= component:
		base.append(0.0)
	base[component] = float(value) if (value is float or value is int) else 0.0
	return base

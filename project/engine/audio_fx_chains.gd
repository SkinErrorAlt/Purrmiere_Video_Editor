extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const PackK := preload("res://engine/audio_effects_k.gd")
const GUARD_ID := "limiter"
const GUARD_CEILING_DB := -1.0
const GUARD_RELEASE_MS := 80.0
const STEP_MARK := "~"

static var _by_id: Dictionary = {}


static func table() -> Dictionary:
	if _by_id.is_empty():
		for raw: Dictionary in PackK.DEFS:
			_by_id[String(raw["id"])] = raw
	return _by_id


static func is_chain(id: String) -> bool:
	return table().has(id)


static func chain_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for raw: Dictionary in PackK.DEFS:
		out.append(String(raw["id"]))
	return out


static func holds_chain(list: Array) -> bool:
	for e: Variant in list:
		if e is Dictionary and is_chain(String((e as Dictionary).get("id", ""))):
			return true
	return false


static func expand(list: Variant) -> void:
	if not (list is Array):
		return
	var arr: Array = list
	if not holds_chain(arr):
		return
	var out: Array = []
	for e: Variant in arr:
		if e is Dictionary and is_chain(String((e as Dictionary).get("id", ""))):
			out.append_array(steps_for(e as Dictionary))
		else:
			out.append(e)
	arr.clear()
	arr.append_array(out)


static func expanded(list: Array) -> Array:
	var copy: Array = list.duplicate(true)
	expand(copy)
	return copy


static func props_of(raw: Dictionary, params: Dictionary) -> Dictionary:
	var props: Dictionary = {}
	for p: Variant in raw.get("params", []):
		var pd: Dictionary = p
		var key: String = String(pd["key"])
		var have: Variant = params.get(key, null)
		if have is Dictionary:
			props[key] = have
		elif have is float or have is int:
			props[key] = AnimProp.make(float(have))
		else:
			props[key] = AnimProp.make(float(pd.get("default", 0.0)))
	return props


static func steps_for(fx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var id: String = String(fx.get("id", ""))
	if not is_chain(id):
		return out
	var raw: Dictionary = table()[id]
	var given: Variant = fx.get("params", {})
	var props: Dictionary = props_of(raw, given if given is Dictionary else {})
	var uid: String = String(fx.get("uid", ""))
	var enabled: bool = bool(fx.get("enabled", true))
	var steps: Array = raw.get("chain", [])
	for i: int in steps.size():
		var st: Dictionary = steps[i]
		var np: Dictionary = {}
		var sets: Dictionary = st.get("p", {})
		for k: Variant in sets.keys():
			np[String(k)] = mapped(sets[k], props)
		var one: Dictionary = {"id": String(st["id"]), "enabled": enabled, "params": np}
		if not uid.is_empty():
			one["uid"] = uid + STEP_MARK + str(i)
		out.append(one)
	if not bool(raw.get("no_guard", false)):
		var guard: Dictionary = {"id": GUARD_ID, "enabled": enabled, "params": {"ceiling_db": AnimProp.make(GUARD_CEILING_DB), "release_ms": AnimProp.make(GUARD_RELEASE_MS)}}
		if not uid.is_empty():
			guard["uid"] = uid + STEP_MARK + "guard"
		out.append(guard)
	return out


static func mapped(how: Variant, props: Dictionary) -> Dictionary:
	if how is float or how is int:
		return AnimProp.make(float(how))
	if how is String:
		var src: Variant = props.get(String(how), null)
		return (src as Dictionary).duplicate(true) if src is Dictionary else AnimProp.make(0.0)
	if how is Array and (how as Array).size() >= 2:
		var rule: Array = how
		var src2: Variant = props.get(String(rule[0]), null)
		if not (src2 is Dictionary):
			return AnimProp.make(0.0)
		return transformed(src2 as Dictionary, rule)
	return AnimProp.make(0.0)


static func is_linear(rule: Array) -> bool:
	return not (rule[1] is String)


static func apply(v: float, rule: Array) -> float:
	var kind: Variant = rule[1]
	if kind is String:
		if String(kind) == "pick":
			var list: Array = rule[2] if rule.size() > 2 and rule[2] is Array else []
			if list.is_empty():
				return v
			return float(list[clampi(int(round(v)), 0, list.size() - 1)])
		if String(kind) == "db":
			var off: float = float(rule[2]) if rule.size() > 2 else 0.0
			return pow(10.0, (v + off) / 20.0)
		return v
	var add: float = float(rule[2]) if rule.size() > 2 else 0.0
	return v * float(kind) + add


static func transformed(p: Dictionary, rule: Array) -> Dictionary:
	if not AnimProp.is_animated(p):
		return AnimProp.make(apply(float(AnimProp.static_value(p)), rule))
	var scale_only: bool = is_linear(rule) and (rule.size() < 3 or is_zero_approx(float(rule[2])))
	var out: Dictionary = p.duplicate(true)
	out["base"] = apply(float(out.get("base", 0.0)), rule)
	var kept: Array = []
	for l: Variant in out.get("layers", []):
		if not (l is Dictionary):
			continue
		var layer: Dictionary = l
		var kind: String = String(layer.get("type", ""))
		var adds: bool = String(layer.get("blend", "over")) != "over" or bool(layer.get(AnimProp.OFFSET_FIELD, false))
		if kind == "keys" and not adds:
			for k: Variant in layer.get("keys", []):
				var kd: Dictionary = k
				var kv: Variant = kd.get("v", 0.0)
				if kv is float or kv is int:
					kd["v"] = apply(float(kv), rule)
			kept.append(layer)
		elif scale_only and kind == "keys":
			for k2: Variant in layer.get("keys", []):
				var kd2: Dictionary = k2
				var kv2: Variant = kd2.get("v", 0.0)
				if kv2 is float or kv2 is int:
					kd2["v"] = apply(float(kv2), rule)
			kept.append(layer)
	if kept.is_empty():
		return AnimProp.make(float(out["base"]))
	out["layers"] = kept
	return out

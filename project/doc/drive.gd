extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const PRESET_KIND := "driver"
const KIND_VALUE := "value"
const KIND_SOUND := "sound"
const KIND_PICTURE := "picture"
const SOURCE_KINDS: PackedStringArray = ["sound", "picture", "value"]
const MEASURES: PackedStringArray = ["colour", "bright", "sat", "hue", "red", "green", "blue", "motion", "cx", "cy"]
const BLENDS: PackedStringArray = ["over", "add", "multiply"]
const SOURCE_KEYS: PackedStringArray = ["clip", "path", "sound", "pic", "owner", "src_start", "dst_start"]
const MAIN_KEY := "mix"

static var clipboard: Dictionary = {}


static func new_layer(kind: String, owner_id: String, owner_start: float, out_lo: Variant, out_hi: Variant) -> Dictionary:
	var layer: Dictionary = AnimProp.new_driven_layer("", "")
	var src: Dictionary = layer["src"]
	src["kind"] = kind if SOURCE_KINDS.has(kind) else KIND_SOUND
	src["owner"] = owner_id
	src["dst_start"] = owner_start
	src["src_start"] = owner_start
	if kind == KIND_VALUE:
		src["clip"] = owner_id
	elif kind == KIND_PICTURE:
		src["pic"] = ""
		src["measure"] = "colour"
		src["colour"] = [0.0, 1.0, 0.0]
		src["tol"] = 0.3
		src["region"] = []
		layer["in_max"] = 100.0
	else:
		src["sound"] = ""
		src["band"] = 0
		src["low"] = 80.0
		src["high"] = 2000.0
		layer["in_max"] = 100.0
	layer["out_min"] = out_lo
	layer["out_max"] = out_hi
	layer["name"] = ""
	return layer


static func is_driver(layer: Variant) -> bool:
	return layer is Dictionary and str((layer as Dictionary).get("type", "")) == "driven"


static func indices(p: Dictionary) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if not AnimProp.is_animated(p):
		return out
	var layers: Array = p.get("layers", [])
	for i: int in layers.size():
		if is_driver(layers[i]):
			out.append(i)
	return out


static func count(p: Dictionary) -> int:
	return indices(p).size()


static func seeded(p: Dictionary, current: Variant) -> Dictionary:
	if not p.is_empty():
		return p
	return AnimProp.make(current if current != null else 0.0)


static func add(p: Dictionary, layer: Dictionary) -> Dictionary:
	return AnimProp.add_layer(p, layer)


static func set_field(p: Dictionary, index: int, key: String, value: Variant) -> Dictionary:
	return AnimProp.set_layer_field(p, index, key, value)


static func set_src(p: Dictionary, index: int, key: String, value: Variant) -> Dictionary:
	var layers: Array = p.get("layers", []) if AnimProp.is_animated(p) else []
	if index < 0 or index >= layers.size():
		return p.duplicate(true)
	var src: Dictionary = AnimProp.driven_source(layers[index])
	src[key] = value
	return AnimProp.set_layer_field(p, index, "src", src)


static func set_kind(p: Dictionary, index: int, kind: String, owner_id: String, owner_start: float) -> Dictionary:
	var layers: Array = p.get("layers", []) if AnimProp.is_animated(p) else []
	if index < 0 or index >= layers.size():
		return p.duplicate(true)
	var old: Dictionary = layers[index]
	var fresh: Dictionary = new_layer(kind, owner_id, owner_start, old.get("out_min", 0.0), old.get("out_max", 1.0))
	for k: String in ["on", "weight", "blend", "invert", "attack", "release", "hold", "step", "step_unit", "axis", "curve", "ease", "overshoot", "name"]:
		if old.has(k):
			fresh[k] = old[k]
	return _replace(p, index, fresh)


static func _replace(p: Dictionary, index: int, layer: Dictionary) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	var layers: Array = out["layers"]
	layers[index] = layer.duplicate(true)
	return out


static func remove(p: Dictionary, index: int) -> Dictionary:
	return AnimProp.remove_layer(p, index)


static func move(p: Dictionary, from: int, to: int) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	if not AnimProp.is_animated(out):
		return out
	var layers: Array = out["layers"]
	if from < 0 or from >= layers.size():
		return out
	var want: int = clampi(to, 0, layers.size() - 1)
	if want == from:
		return out
	var one: Variant = layers[from]
	layers.remove_at(from)
	layers.insert(want, one)
	return out


static func move_driver(p: Dictionary, nth: int, dir: int) -> Dictionary:
	var idx: PackedInt32Array = indices(p)
	if nth < 0 or nth >= idx.size():
		return p.duplicate(true)
	var other: int = nth + dir
	if other < 0 or other >= idx.size():
		return p.duplicate(true)
	var out: Dictionary = p.duplicate(true)
	var layers: Array = out["layers"]
	var a: int = idx[nth]
	var b: int = idx[other]
	var keep: Variant = layers[a]
	layers[a] = layers[b]
	layers[b] = keep
	return out


static func info(lo: float, hi: float, comps: int, unit: String, label: String) -> Dictionary:
	return {"lo": lo, "hi": hi, "comps": comps, "unit": unit, "label": label}


static func _bounded(i: Dictionary) -> bool:
	return not is_inf(float(i.get("lo", -INF))) and not is_inf(float(i.get("hi", INF))) and float(i.get("hi", 0.0)) > float(i.get("lo", 0.0))


static func _num(v: Variant, c: int) -> float:
	if v is Array:
		var a: Array = v
		if a.is_empty():
			return 0.0
		return float(a[clampi(c, 0, a.size() - 1)])
	if v is Dictionary:
		return _num(AnimProp.static_value(v), c)
	if v is float or v is int:
		return float(v)
	return 0.0


static func _shape(v: Variant, comps: int) -> Variant:
	if comps <= 1:
		return _num(v, 0)
	var out: Array = []
	for c: int in comps:
		out.append(_num(v, c))
	return out


static func _map(v: Variant, from: Dictionary, to: Dictionary, comps: int) -> Variant:
	var flo: float = float(from["lo"])
	var fhi: float = float(from["hi"])
	var tlo: float = float(to["lo"])
	var thi: float = float(to["hi"])
	if comps <= 1:
		return tlo + (_num(v, 0) - flo) / (fhi - flo) * (thi - tlo)
	var out: Array = []
	for c: int in comps:
		out.append(tlo + (_num(v, c) - flo) / (fhi - flo) * (thi - tlo))
	return out


static func fit(layer: Dictionary, from: Dictionary, to: Dictionary) -> Dictionary:
	var out: Dictionary = layer.duplicate(true)
	var note: String = ""
	var tc: int = maxi(int(to.get("comps", 1)), 1)
	var fc: int = maxi(int(from.get("comps", 1)), 1)
	var same_unit: bool = String(from.get("unit", "")) == String(to.get("unit", ""))
	var same_range: bool = is_equal_approx(float(from.get("lo", 0.0)), float(to.get("lo", 0.0))) and is_equal_approx(float(from.get("hi", 0.0)), float(to.get("hi", 0.0)))
	if not (same_unit and same_range):
		if _bounded(from) and _bounded(to):
			for k: String in ["out_min", "out_max"]:
				var v: Variant = out.get(k, 0.0)
				if v is Dictionary:
					v = AnimProp.static_value(v)
				out[k] = _map(v, from, to, tc)
			note = "The output was moved from %s to %s%s onto %s to %s%s" % [_fmt(float(from["lo"])), _fmt(float(from["hi"])), String(from.get("unit", "")), _fmt(float(to["lo"])), _fmt(float(to["hi"])), String(to.get("unit", ""))]
		elif not same_unit:
			note = "The units differ (%s and %s), so the output numbers were kept: check To" % [_unit_name(String(from.get("unit", ""))), _unit_name(String(to.get("unit", "")))]
	if fc != tc:
		for k2: String in ["out_min", "out_max"]:
			var v2: Variant = out.get(k2, 0.0)
			if v2 is Dictionary:
				v2 = AnimProp.static_value(v2)
			out[k2] = _shape(v2, tc)
		if int(out.get("axis", -1)) >= tc:
			out["axis"] = -1
		var part: String = "one number became %d" % tc if fc < tc else "only the first of %d numbers was kept" % fc
		note = part if note.is_empty() else note + "; " + part
	elif tc <= 1:
		for k3: String in ["out_min", "out_max"]:
			if out.get(k3, 0.0) is Array:
				out[k3] = _num(out[k3], 0)
	return {"layer": out, "note": note}


static func _unit_name(u: String) -> String:
	var t: String = u.strip_edges()
	return t if not t.is_empty() else "no unit"


static func _fmt(v: float) -> String:
	if absf(v - roundf(v)) < 0.0001:
		return str(int(roundf(v)))
	return str(snappedf(v, 0.01))


static func retarget(layer: Dictionary, owner_id: String, owner_start: float, from_owner: String) -> Dictionary:
	var out: Dictionary = layer.duplicate(true)
	var src: Dictionary = AnimProp.driven_source(out)
	var kind: String = String(src.get("kind", KIND_VALUE))
	src["owner"] = owner_id
	src["dst_start"] = owner_start
	if kind == KIND_VALUE and (String(src.get("clip", "")) == from_owner or String(src.get("clip", "")).is_empty()):
		src["clip"] = owner_id
		src["src_start"] = owner_start
	out["src"] = src
	return out


static func copy(p: Dictionary, nth: int, from: Dictionary, owner_id: String) -> Dictionary:
	var layers: Array = p.get("layers", []) if AnimProp.is_animated(p) else []
	var idx: PackedInt32Array = indices(p)
	var picked: Array = []
	for i: int in idx.size():
		if nth < 0 or i == nth:
			picked.append((layers[idx[i]] as Dictionary).duplicate(true))
	if picked.is_empty():
		return {}
	clipboard = {"layers": picked, "from": from.duplicate(true), "owner": owner_id}
	return clipboard


static func has_clip() -> bool:
	return not (clipboard.get("layers", []) as Array).is_empty()


static func paste(p: Dictionary, cb: Dictionary, to: Dictionary, owner_id: String, owner_start: float) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	var notes: PackedStringArray = PackedStringArray()
	for l: Variant in cb.get("layers", []):
		var moved: Dictionary = retarget(l, owner_id, owner_start, String(cb.get("owner", "")))
		var fitted: Dictionary = fit(moved, cb.get("from", to), to)
		out = AnimProp.add_layer(out, fitted["layer"])
		if not String(fitted["note"]).is_empty() and not notes.has(String(fitted["note"])):
			notes.append(String(fitted["note"]))
	return {"prop": out, "note": ". ".join(notes)}


static func with_drivers(own: Dictionary, layers: Array, owner_id: String, owner_start: float, from_owner: String) -> Dictionary:
	var out: Dictionary = own.duplicate(true)
	if AnimProp.is_animated(out):
		var keep: Array = []
		for l: Variant in out.get("layers", []):
			if not is_driver(l):
				keep.append(l)
		out["layers"] = keep
	for l2: Variant in layers:
		out = AnimProp.add_layer(out, retarget(l2, owner_id, owner_start, from_owner))
	return AnimProp.simplify(out)


static func strip_source(layer: Dictionary) -> Dictionary:
	var out: Dictionary = layer.duplicate(true)
	var src: Dictionary = AnimProp.driven_source(out)
	var kind: String = String(src.get("kind", KIND_VALUE))
	for k: String in SOURCE_KEYS:
		src.erase(k)
	if kind == KIND_VALUE:
		src["path"] = String(AnimProp.driven_source(layer).get("path", ""))
	out["src"] = src
	return out


static func preset_payload(layers: Array, from: Dictionary) -> Dictionary:
	var list: Array = []
	for l: Variant in layers:
		if is_driver(l):
			list.append(strip_source(l))
	return {"layers": list, "from": from.duplicate(true)}


static func from_preset(p: Dictionary, preset: Dictionary, to: Dictionary, owner_id: String, owner_start: float, source_text: String) -> Dictionary:
	var payload: Dictionary = preset.get("payload", {})
	var layers: Array = []
	for l: Variant in payload.get("layers", []):
		if not is_driver(l):
			continue
		var one: Dictionary = (l as Dictionary).duplicate(true)
		var src: Dictionary = AnimProp.driven_source(one)
		var kind: String = String(src.get("kind", KIND_VALUE))
		if kind == KIND_SOUND:
			src["sound"] = source_text
		elif kind == KIND_PICTURE:
			src["pic"] = source_text
		else:
			src["clip"] = owner_id
			src["src_start"] = owner_start
		src["owner"] = owner_id
		src["dst_start"] = owner_start
		one["src"] = src
		layers.append(one)
	return paste(p, {"layers": layers, "from": payload.get("from", to), "owner": owner_id}, to, owner_id, owner_start)


static func label_of(layer: Dictionary, n: int) -> String:
	var named: String = String(layer.get("name", "")).strip_edges()
	if not named.is_empty():
		return named
	var kind: String = String(AnimProp.driven_source(layer).get("kind", KIND_VALUE))
	var what: String = "Sound" if kind == KIND_SOUND else ("Picture" if kind == KIND_PICTURE else "Value")
	return "Driver %d, %s" % [n + 1, what.to_lower()]

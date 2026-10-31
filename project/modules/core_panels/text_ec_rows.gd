extends RefCounted

const Clip := preload("res://doc/clip.gd")
const TextAnimators := preload("res://doc/text_animators.gd")
const TextExtras := preload("res://doc/text_extras.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const ANIM_FOLD := "text_animators"
const EXTRAS_FOLD := "text_extras"
const ANIM_ROWS: Array = [
	["on", "On", "bool", {}],
	["units", "Counts", "enum", {}],
	["shape", "Shape", "enum", {}],
	["ease", "Ease", "enum", {}],
	["start", "Start", "float", {"min": 0.0, "max": 100.0, "step": 1.0, "suffix": " %"}],
	["end", "End", "float", {"min": 0.0, "max": 100.0, "step": 1.0, "suffix": " %"}],
	["offset", "Offset", "float", {"min": -100.0, "max": 100.0, "step": 1.0, "suffix": " %"}],
	["amount", "Amount", "float", {"min": -100.0, "max": 100.0, "step": 1.0, "suffix": " %"}],
	["pos", "Move", "vec2", {"step": 1.0}],
	["scale", "Size", "float", {"min": 0.0, "max": 1000.0, "step": 1.0, "suffix": " %"}],
	["rotation", "Turn", "float", {"step": 1.0, "suffix": " °", "turns": true}],
	["opacity", "Opacity", "float", {"min": 0.0, "max": 100.0, "step": 1.0, "suffix": " %"}],
	["blur", "Blur", "float", {"min": 0.0, "max": 100.0, "step": 0.5, "suffix": " px"}],
	["skew", "Skew", "float", {"min": -80.0, "max": 80.0, "step": 1.0, "suffix": " °"}],
	["tracking", "Spacing", "float", {"min": -200.0, "max": 400.0, "step": 1.0, "suffix": " px"}],
	["colour_on", "Colour on", "bool", {}],
	["colour", "Colour", "color", {}],
	["frequency", "Waves across", "float", {"min": 0.0, "max": 20.0, "step": 0.1}],
	["seed", "Random seed", "float", {"min": 0.0, "max": 99999.0, "step": 1.0}],
	["whole", "Whole letters", "bool", {}],
]
const EXTRA_ROWS: Array = [
	["path_shape", "Text follows", "enum", {}],
	["path_start", "Start along the path", "float", {"min": -1000.0, "max": 1000.0, "step": 0.5, "suffix": " %"}],
	["path_size", "Path size", "float", {"min": 0.0, "max": 400.0, "step": 1.0}],
	["path_bend", "Bend", "float", {"min": -200.0, "max": 200.0, "step": 1.0, "suffix": " %"}],
	["path_waves", "Waves", "float", {"min": 0.0, "max": 20.0, "step": 0.1}],
	["path_turn", "Letters turn with it", "bool", {}],
	["counter_on", "Counter", "bool", {}],
	["counter_value", "Counter value", "float", {"step": 1.0}],
	["counter_decimals", "Decimals", "int", {"min": 0.0, "max": 6.0, "step": 1.0}],
	["counter_format", "Looks like", "enum", {}],
	["counter_prefix", "Before", "string", {}],
	["counter_suffix", "After", "string", {}],
]


static func is_animator_key(key: String) -> bool:
	if not key.begins_with("ta") or key.length() < 5:
		return false
	var cut: int = key.find("_")
	return cut > 2 and key.substr(2, cut - 2).is_valid_int()


static func default_of(key: String) -> Variant:
	if key == TextAnimators.COUNT_KEY:
		return 0
	if is_animator_key(key):
		var field: String = key.substr(key.find("_") + 1)
		var d: Dictionary = TextAnimators.defaults()
		return d.get(field, null)
	var e: Dictionary = TextExtras.defaults()
	return e.get(key, null)


static func choices_for(field: String) -> Array:
	var ids: PackedStringArray = PackedStringArray()
	var labels: PackedStringArray = PackedStringArray()
	if field == "units":
		ids = TextAnimators.UNITS
		labels = TextAnimators.UNIT_LABELS
	elif field == "shape":
		ids = TextAnimators.SHAPES
		labels = TextAnimators.SHAPE_LABELS
	elif field == "ease":
		ids = TextAnimators.EASES
		labels = TextAnimators.EASE_LABELS
	elif field == "path_shape":
		ids = TextExtras.PATH_SHAPES
		labels = TextExtras.PATH_LABELS
	elif field == "counter_format":
		ids = TextExtras.COUNTER_FORMATS
		labels = TextExtras.COUNTER_LABELS
	var out: Array = []
	for i: int in ids.size():
		out.append(PmDrop.choice(ids[i], labels[i]))
	return out


static func spec_for(key: String, label: String, kind: String, extra: Dictionary, field: String, indent: int) -> Dictionary:
	var spec: Dictionary = {"path": "props." + key, "prop": key, "keyable": true, "label": label, "kind": kind, "indent": indent}
	for k: Variant in extra.keys():
		spec[k] = extra[k]
	if kind == "enum":
		spec["choices"] = choices_for(field)
	return spec


static func animator_specs(c: Clip, i: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Array in ANIM_ROWS:
		var field: String = String(row[0])
		out.append(spec_for(TextAnimators.key(i, field), String(row[1]), String(row[2]), row[3], field, 1))
	return out


static func extra_specs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Array in EXTRA_ROWS:
		out.append(spec_for(String(row[0]), String(row[1]), String(row[2]), row[3], String(row[0]), 0))
	return out


static func all_specs(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null:
		return out
	for i: int in TextAnimators.count(c.props):
		out.append_array(animator_specs(c, i))
	out.append_array(extra_specs())
	return out


static func members_of(panel: Object, c: Clip) -> Array[Clip]:
	var out: Array[Clip] = []
	if panel != null and bool(panel.get("_many_on")):
		for m: Variant in panel.get("_many_members"):
			if m is Clip:
				out.append(m)
	if out.is_empty() and c != null:
		out.append(c)
	return out


static func shared_count(members: Array[Clip]) -> int:
	if members.is_empty():
		return 0
	var n: int = TextAnimators.MAX_ANIMATORS
	for m: Clip in members:
		n = mini(n, TextAnimators.count(m.props))
	return n


static func key(c: Clip, members: Array[Clip] = []) -> String:
	if c == null:
		return ""
	var group: Array[Clip] = members if not members.is_empty() else ([c] as Array[Clip])
	var n: int = shared_count(group)
	var parts: PackedStringArray = PackedStringArray([str(n), str(group.size())])
	for i: int in n:
		parts.append(String(TextAnimators.animator(c.props, i)["name"]))
	return "|".join(parts)


static func build(panel: Object, c: Clip) -> void:
	if c == null:
		return
	var n: int = shared_count(members_of(panel, c))
	if n > 0:
		var f: VBoxContainer = panel.call("_fold", "Letter animation", ANIM_FOLD)
		var body: VBoxContainer = f.get("body")
		for i: int in n:
			var title: Label = Label.new()
			title.text = String(TextAnimators.animator(c.props, i)["name"])
			body.add_child(title)
			for spec: Dictionary in animator_specs(c, i):
				panel.call("_add_row", body, spec)
	var f2: VBoxContainer = panel.call("_fold", "Path and counter", EXTRAS_FOLD)
	var body2: VBoxContainer = f2.get("body")
	for spec2: Dictionary in extra_specs():
		panel.call("_add_row", body2, spec2)

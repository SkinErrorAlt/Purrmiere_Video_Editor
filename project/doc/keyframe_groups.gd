extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const LetterRig := preload("res://doc/letter_rig.gd")
const SEPARATOR := " · "
const TRANSFORM := "transform"
const AUDIO := "audio"
const TEXT := "props"
const EXTRAS := "props.extras"
const TIMING := "timing"
const LOOSE := "loose"
const ANIM_PREFIX := "props.ta"
const RIG_PREFIX := "props.lr."
const MIN_FOLD := 2
const MARK_STEPS := 1000.0
const TITLES: Dictionary = {
	"transform": "Transform",
	"audio": "Audio",
	"props": "Text",
	"props.extras": "Path and counter",
	"timing": "Speed",
	"transition": "Transition in",
	"transition_out": "Transition out",
	"loose": "Other",
}


static func animator_index(key: String) -> int:
	if not key.begins_with(ANIM_PREFIX):
		return -1
	var tail: String = key.substr(ANIM_PREFIX.length())
	return int(tail) if tail.is_valid_int() else -1


static func is_animator_prop(prop: String) -> bool:
	var cut: int = prop.find("_")
	if not prop.begins_with("ta") or cut <= 2:
		return false
	return prop.substr(2, cut - 2).is_valid_int()


static func animator_field(prop: String) -> String:
	if not is_animator_prop(prop):
		return prop
	return prop.substr(prop.find("_") + 1)


static func prop_group(prop: String) -> String:
	if prop.begins_with(LetterRig.PREFIX):
		var rp: PackedStringArray = LetterRig.parse(prop)
		if rp.size() == 2:
			return RIG_PREFIX + rp[0]
	if is_animator_prop(prop):
		return ANIM_PREFIX + prop.substr(2, prop.find("_") - 2)
	if prop.begins_with("path_") or prop.begins_with("counter_"):
		return EXTRAS
	return TEXT


static func key_of(path: String) -> String:
	var base: String = AnimTime.target_of(path)
	if base == "speed" or base == AnimTime.SPEED_PATH or base == AnimTime.START_FIELD:
		return TIMING
	if base == "motion":
		return TRANSFORM
	if base == AUDIO:
		return AUDIO
	if base == TEXT:
		return TEXT
	var parts: PackedStringArray = base.split(".")
	var head: String = parts[0]
	if head == "transform" or head == "motion_blur":
		return TRANSFORM
	if head == AUDIO:
		return AUDIO
	if head == "transition" or head == "transition_out":
		return head
	if parts.size() >= 2 and (head == "effects" or head == "audio_effects" or head == "masks"):
		return head + "." + parts[1]
	if parts.size() >= 2 and head == "props":
		return prop_group(parts[1])
	return LOOSE


static func title_of(key: String, label: String) -> String:
	var i: int = animator_index(key)
	if i >= 0:
		return "Letter animation " + str(i + 1)
	if TITLES.has(key):
		return String(TITLES[key])
	var cut: int = label.find(SEPARATOR)
	if cut > 0:
		return label.substr(0, cut)
	return label if not label.is_empty() else key


## How far a letter rig group sits in, so the list reads like a rig tree: whole text, then lines and words, then
## letters under their word.
static func rig_indent(key: String) -> int:
	if not key.begins_with(RIG_PREFIX):
		return 0
	var kind: String = LetterRig.kind_of(key.substr(RIG_PREFIX.length()))
	if kind == "c":
		return 2
	return 0 if kind == LetterRig.ROOT else 1


static func short_label(label: String, head: String) -> String:
	var lead: String = head + SEPARATOR
	if head.is_empty() or not label.begins_with(lead):
		return label
	return label.substr(lead.length())


static func keys_in(items: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for it: Dictionary in items:
		var key: String = key_of(String(it.get("path", "")))
		if not out.has(key):
			out.append(key)
	return out


static func all_open(items: Array) -> Dictionary:
	var out: Dictionary = {}
	for key: String in keys_in(items):
		out[key] = true
	return out


static func row_paths(rows: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for r: Dictionary in rows:
		if String(r.get("kind", "")) == "group":
			for p: String in (r.get("paths", PackedStringArray()) as PackedStringArray):
				if not out.has(p):
					out.append(p)
			continue
		var path: String = String(r.get("path", ""))
		if not path.is_empty() and not out.has(path):
			out.append(path)
	return out


static func build(items: Array, open: Dictionary, titles: Dictionary = {}) -> Array[Dictionary]:
	var order: PackedStringArray = PackedStringArray()
	var by_key: Dictionary = {}
	for it: Dictionary in items:
		var key: String = key_of(String(it.get("path", "")))
		if not by_key.has(key):
			by_key[key] = []
			order.append(key)
		(by_key[key] as Array).append(it)
	var folders: Dictionary = {}
	var folder_labels: Dictionary = {}
	for it2: Dictionary in items:
		var parent: String = String(it2.get("rig_parent", ""))
		if parent.is_empty():
			continue
		if not folders.has(parent):
			folders[parent] = PackedStringArray()
			folder_labels[parent] = String(it2.get("rig_parent_label", parent))
		var fp: PackedStringArray = folders[parent]
		fp.append(String(it2.get("path", "")))
		folders[parent] = fp
	var shown_folders: Dictionary = {}
	var out: Array[Dictionary] = []
	for key2: String in order:
		var kids: Array = by_key[key2]
		var rig_parent: String = String((kids[0] as Dictionary).get("rig_parent", ""))
		if not rig_parent.is_empty():
			if not shown_folders.has(rig_parent) and not by_key.has(rig_parent):
				shown_folders[rig_parent] = true
				var fpaths: PackedStringArray = folders.get(rig_parent, PackedStringArray())
				var fkeyed: int = 0
				for fi: Dictionary in items:
					if String(fi.get("rig_parent", "")) == rig_parent and bool(fi.get("animated", false)):
						fkeyed += 1
				out.append({"kind": "group", "key": rig_parent, "label": String(folder_labels.get(rig_parent, rig_parent)), "path": "", "count": fpaths.size(), "keyed": fkeyed, "animated": fkeyed > 0, "paths": fpaths, "open": bool(open.get(rig_parent, false)), "depth": 0, "indent": rig_indent(rig_parent), "marks": PackedFloat32Array(), "folder": true})
			if not bool(open.get(rig_parent, false)):
				continue
		if kids.size() < MIN_FOLD and not key2.begins_with(RIG_PREFIX):
			for solo: Dictionary in kids:
				var flat: Dictionary = solo.duplicate()
				flat["kind"] = "row"
				flat["group"] = ""
				flat["depth"] = 0
				out.append(flat)
			continue
		var paths: PackedStringArray = PackedStringArray()
		var keyed: int = 0
		for k2: Dictionary in kids:
			paths.append(String(k2.get("path", "")))
			if bool(k2.get("animated", false)):
				keyed += 1
		var head: String = String(titles.get(key2, title_of(key2, String((kids[0] as Dictionary).get("label", key2)))))
		var is_open: bool = bool(open.get(key2, false))
		var indent: int = rig_indent(key2)
		out.append({"kind": "group", "key": key2, "label": head, "path": "", "count": kids.size(), "keyed": keyed, "animated": keyed > 0, "paths": paths, "open": is_open, "depth": 0, "indent": indent, "marks": PackedFloat32Array()})
		if not is_open:
			continue
		for k3: Dictionary in kids:
			var row: Dictionary = k3.duplicate()
			row["kind"] = "row"
			row["group"] = key2
			row["depth"] = 1
			row["indent"] = rig_indent(key2)
			row["label"] = short_label(String(k3.get("label", "")), head)
			out.append(row)
	return out


static func key_marks(c: Object, paths: PackedStringArray) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	if c == null or not c.has_method("get_param"):
		return out
	var dur: float = float(c.get("duration"))
	if dur <= 0.0:
		return out
	var seen: Dictionary = {}
	for p: String in paths:
		var prop: Dictionary = c.call("get_param", p)
		if not AnimProp.is_animated(prop):
			continue
		for k: Dictionary in AnimProp.keys(prop):
			var q: int = int(round(clampf(float(k.get("t", 0.0)) / dur, 0.0, 1.0) * MARK_STEPS))
			if seen.has(q):
				continue
			seen[q] = true
			out.append(float(q) / MARK_STEPS)
	out.sort()
	return out


static func with_marks(c: Object, rows: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in rows:
		if String(r.get("kind", "")) == "group" and not bool(r.get("open", false)) and bool(r.get("animated", false)):
			var row: Dictionary = r.duplicate()
			row["marks"] = key_marks(c, r.get("paths", PackedStringArray()))
			out.append(row)
			continue
		out.append(r)
	return out

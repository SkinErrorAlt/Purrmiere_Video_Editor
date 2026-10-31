extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")

const NUMBER := "number"
const POINT := "point"
const FLAG := "flag"
const CHOICE := "choice"
const COLOUR := "colour"
const CURVE := "curve"
const WORDS := "words"
const LAYER := "layer"

const KEY_FIELDS: PackedStringArray = ["ease", "dir", "ho", "hi", "sp", "sho", "shi"]

const FAMILIES: Dictionary = {
	"float": NUMBER,
	"int": NUMBER,
	"vec2": POINT,
	"bool": FLAG,
	"enum": CHOICE,
	"color": COLOUR,
	"curve": CURVE,
	"string": WORDS,
	"multiline": WORDS,
	"texture": WORDS,
	"layer": LAYER,
}

const FAMILY_NAMES: Dictionary = {
	NUMBER: "a number",
	POINT: "a pair of numbers",
	FLAG: "a tick",
	CHOICE: "a choice",
	COLOUR: "a colour",
	CURVE: "a curve",
	WORDS: "some words",
	LAYER: "a layer",
}

static var held: Dictionary = {}


static func family(kind: String) -> String:
	return String(FAMILIES.get(kind, ""))


static func family_name(fam: String) -> String:
	return String(FAMILY_NAMES.get(fam, "something else"))


static func name_of(spec: Dictionary) -> String:
	var key: String = String(spec.get("key", ""))
	if not key.is_empty():
		return key
	var path: String = String(spec.get("path", ""))
	var parts: PackedStringArray = path.split(".")
	if parts.size() == 0:
		return path
	return parts[parts.size() - 1]


static func keys_of(p: Dictionary) -> Array:
	var out: Array = []
	var ks: Array[Dictionary] = AnimProp.keys(p)
	if ks.is_empty():
		return out
	var base: float = base_time(p)
	for k: Dictionary in ks:
		var kd: Dictionary = k.duplicate(true)
		kd["t"] = float(k.get("t", 0.0)) - base
		out.append(kd)
	return out


static func base_time(p: Dictionary) -> float:
	var ks: Array[Dictionary] = AnimProp.keys(p)
	if ks.is_empty():
		return 0.0
	var base: float = INF
	for k: Dictionary in ks:
		base = minf(base, float(k.get("t", 0.0)))
	return 0.0 if is_inf(base) else base


static func grab(spec: Dictionary, value: Variant, prop: Dictionary) -> Dictionary:
	var kind: String = String(spec.get("kind", ""))
	var fam: String = family(kind)
	if fam.is_empty():
		return {}
	var part: bool = spec.has("component")
	var keys: Array = [] if part else keys_of(prop)
	var under: Variant = AnimProp.norm(value)
	if not keys.is_empty() and AnimProp.is_animated(prop):
		under = AnimProp.static_value(prop)
	return {
		"name": name_of(spec),
		"label": String(spec.get("label", "")),
		"path": String(spec.get("path", "")),
		"eid": String(spec.get("eid", "")),
		"kind": kind,
		"family": fam,
		"value": AnimProp.norm(value),
		"under": AnimProp.norm(under),
		"base": 0.0 if part else base_time(prop),
		"keys": keys,
	}


static func take(cb: Dictionary) -> bool:
	if cb.is_empty():
		return false
	held = cb.duplicate(true)
	return true


static func holding() -> bool:
	return not held.is_empty()


static func key_count(cb: Dictionary) -> int:
	return (cb.get("keys", []) as Array).size()


static func copied_note(cb: Dictionary) -> String:
	if cb.is_empty():
		return "Nothing to copy here"
	var what: String = String(cb.get("label", ""))
	if what.is_empty():
		what = String(cb.get("name", "value"))
	var n: int = key_count(cb)
	if n == 1:
		return "Copied " + what + " with 1 key"
	if n > 1:
		return "Copied " + what + " with " + str(n) + " keys"
	return "Copied " + what


static func score(cb: Dictionary, spec: Dictionary) -> int:
	if cb.is_empty():
		return 0
	if family(String(spec.get("kind", ""))) != String(cb.get("family", "")):
		return 0
	var pts: int = 0
	if String(spec.get("path", "")) == String(cb.get("path", "")):
		pts += 8
	var eid: String = String(cb.get("eid", ""))
	if not eid.is_empty() and String(spec.get("eid", "")) == eid:
		pts += 4
	if name_of(spec) == String(cb.get("name", "")):
		pts += 2
	var label: String = String(cb.get("label", ""))
	if not label.is_empty() and String(spec.get("label", "")).to_lower() == label.to_lower():
		pts += 1
	return pts


static func best_match(specs: Array, cb: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var top: int = 0
	for item: Variant in specs:
		if not (item is Dictionary):
			continue
		var spec: Dictionary = item
		var n: int = score(cb, spec)
		if n > top:
			top = n
			best = spec
	return best if top > 0 else {}


static func refusal(cb: Dictionary, spec: Dictionary) -> String:
	if cb.is_empty():
		return "Copy a value first, then paste"
	if spec.is_empty():
		return "Nothing on this clip holds " + family_name(String(cb.get("family", ""))) + " called " + plain_name(cb)
	if spec.has("members"):
		return "Select one clip to paste a value"
	if not String(spec.get("special", "")).is_empty():
		return plain_label(spec) + " is set another way, so a value cannot be pasted into it"
	var fam: String = family(String(spec.get("kind", "")))
	if fam.is_empty():
		return plain_label(spec) + " cannot take a pasted value"
	if fam != String(cb.get("family", "")):
		return "The copied value is " + family_name(String(cb.get("family", ""))) + " and " + plain_label(spec) + " takes " + family_name(fam)
	if spec.has("component") and key_count(cb) > 0:
		return "Keys cannot go into one half of a pair, paste them into " + plain_label(spec)
	return ""


static func plain_label(spec: Dictionary) -> String:
	var label: String = String(spec.get("label", ""))
	return label if not label.is_empty() else "this value"


static func plain_name(cb: Dictionary) -> String:
	var label: String = String(cb.get("label", ""))
	return label if not label.is_empty() else String(cb.get("name", "that value"))


static func fit(spec: Dictionary, v: Variant) -> Variant:
	var kind: String = String(spec.get("kind", ""))
	if kind != "float" and kind != "int":
		return v
	var f: float = float(v) if (v is float or v is int) else 0.0
	if spec.has("min"):
		f = maxf(f, float(spec["min"]))
	if spec.has("max"):
		f = minf(f, float(spec["max"]))
	if kind == "int":
		f = roundf(f)
	return f


static func part_value(c: Clip, spec: Dictionary, v: Variant) -> Variant:
	var at: int = int(spec.get("component", 0))
	var now: Variant = AnimProp.static_value(c.get_param(String(spec.get("path", ""))))
	var arr: Array = (now as Array).duplicate(true) if now is Array else []
	while arr.size() <= at:
		arr.append(0.0)
	arr[at] = float(v) if (v is float or v is int) else 0.0
	return arr


static func value_for(c: Clip, spec: Dictionary, cb: Dictionary) -> Variant:
	var v: Variant = fit(spec, cb.get("value", null))
	if spec.has("component") and c != null:
		return part_value(c, spec, v)
	return AnimProp.norm(v)


static func prop_for(c: Clip, spec: Dictionary, cb: Dictionary, at: float) -> Dictionary:
	var keys: Array = cb.get("keys", [])
	if keys.is_empty():
		return AnimProp.make(value_for(c, spec, cb))
	var base: float = at if at >= 0.0 else float(cb.get("base", 0.0))
	var p: Dictionary = AnimProp.make(fit(spec, cb.get("under", cb.get("value", 0.0))))
	for item: Variant in keys:
		var kd: Dictionary = item
		var t: float = maxf(base + float(kd.get("t", 0.0)), 0.0)
		p = AnimProp.set_key(p, t, fit(spec, kd.get("v", 0.0)), String(kd.get("i", "ease_both")))
		var fields: Dictionary = {}
		for f: String in KEY_FIELDS:
			if kd.has(f):
				fields[f] = kd[f]
		if not fields.is_empty():
			p = AnimProp.set_key_fields(p, t, fields)
	return p


static func paste_cmds(seq: Sequence, c: Clip, spec: Dictionary, cb: Dictionary, at: float = -1.0) -> Array[Command]:
	var out: Array[Command] = []
	if seq == null or c == null or not refusal(cb, spec).is_empty():
		return out
	if spec.has("field"):
		var was: Dictionary = c.get(String(spec["field"]))
		var dict: Dictionary = was.duplicate(true)
		dict[String(spec.get("key", ""))] = value_for(c, spec, cb)
		if dict == was:
			return out
		out.append(ClipCmds.SetClipField.new(seq.id, c.id, String(spec["field"]), dict))
		return out
	var p: Dictionary = prop_for(c, spec, cb, at)
	if p.is_empty() or p == c.get_param(String(spec.get("path", ""))):
		return out
	out.append(ClipCmds.SetClipParam.new(seq.id, c.id, String(spec.get("path", "")), p))
	return out


static func paste_label(cb: Dictionary) -> String:
	return "Paste " + plain_name(cb)


static func paste(doc: Project, seq: Sequence, c: Clip, spec: Dictionary, cb: Dictionary, at: float = -1.0) -> bool:
	var cmds: Array[Command] = paste_cmds(seq, c, spec, cb, at)
	if cmds.is_empty():
		return false
	return Verbs.run(doc, paste_label(cb), cmds)

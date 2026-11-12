extends RefCounted

# Voice presets that ship with Purrmiere: one click audio chains that turn a spoken voice into a
# robot, an alien, a ghost, a radio and so on. They live as read only JSON files in
# res://presets/voice/, one file per group, and show in every user's Presets Library under the
# Voice shelf. They are applied exactly like a user's audio preset (Presets.apply_audio_fx) and are
# never written to: renaming one saves a user copy that hides it, Duplicate makes a user copy.
#
# A group file: {"group": "Robots", "order": 1, "presets": [{"id", "label", "blurb", "chain": [
#   {"effect": "<audio effect id>", "params": {"<key>": <number>, ...}}, ...]}]}
# Params left out keep the effect's default.

const AudioEffects := preload("res://engine/audio_effects.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const DIR := "res://presets/voice"
const ID_PREFIX := "voice_"
const KIND := "audio_fx"
const SHELF := "Voice"
const TAG := "voice"
const SORT_BASE := 2000000

static var _cache: Array[Dictionary] = []
static var _loaded: bool = false


static func group_files() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for f: String in DirAccess.get_files_at(DIR):
		if f.get_extension() == "json":
			out.append(DIR.path_join(f))
	out.sort()
	return out


static func read_group(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var v: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if not (v is Dictionary) or not ((v as Dictionary).get("presets") is Array):
		push_warning("VoicePresets: " + path + " is not a voice preset group")
		return {}
	return v


static func groups() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for path: String in group_files():
		var g: Dictionary = read_group(path)
		if not g.is_empty():
			out.append(g)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	return out


# One chain step as a clip audio effect entry: every param of the effect, the given ones set.
static func entry(step: Dictionary) -> Dictionary:
	var id: String = String(step.get("effect", ""))
	if not AudioEffects.has(id):
		return {}
	var params: Dictionary = AudioEffects.default_params(id)
	var given: Variant = step.get("params", {})
	if given is Dictionary:
		for key: Variant in (given as Dictionary).keys():
			if params.has(String(key)):
				params[String(key)] = AnimProp.make(float((given as Dictionary)[key]))
	return {"id": id, "enabled": true, "params": params}


static func build(raw: Dictionary, group: String, index: int) -> Dictionary:
	var effects: Array = []
	for s: Variant in raw.get("chain", []):
		if not (s is Dictionary):
			return {}
		var e: Dictionary = entry(s as Dictionary)
		if e.is_empty():
			push_warning("VoicePresets: " + String(raw.get("id", "")) + " uses an unknown effect")
			return {}
		effects.append(e)
	if effects.is_empty() or String(raw.get("id", "")).is_empty():
		return {}
	return {
		"id": ID_PREFIX + String(raw["id"]),
		"kind": KIND,
		"label": group + ": " + String(raw.get("label", raw["id"])),
		"tags": [TAG, group.to_lower()],
		"payload": {"audio_effects": effects},
		"created": "",
		"anchor": "start",
		"percent": 0.0,
		"max_length": 0.0,
		"sort": SORT_BASE + index,
		"built_in": true,
		"shelf": SHELF,
		"group": group,
		"blurb": String(raw.get("blurb", "")),
	}


static func listing() -> Array[Dictionary]:
	if not _loaded:
		_loaded = true
		var i: int = 0
		for g: Dictionary in groups():
			var name: String = String(g.get("group", "Voice"))
			for raw: Variant in g["presets"]:
				if not (raw is Dictionary):
					continue
				var p: Dictionary = build(raw as Dictionary, name, i)
				if not p.is_empty():
					_cache.append(p)
					i += 1
	var out: Array[Dictionary] = []
	for p: Dictionary in _cache:
		out.append(p.duplicate(true))
	return out


static func forget() -> void:
	_cache.clear()
	_loaded = false


static func ships(id: String) -> bool:
	if not id.begins_with(ID_PREFIX):
		return false
	return not find(id).is_empty()


static func find(id: String) -> Dictionary:
	for p: Dictionary in listing():
		if String(p["id"]) == id:
			return p
	return {}

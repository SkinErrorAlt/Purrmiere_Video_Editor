extends RefCounted

const VERSION := 1
const AnimProp := preload("res://doc/anim_prop.gd")
const CATEGORY := "Audio"
const PackA := preload("res://engine/audio_effects_a.gd")
const PackB := preload("res://engine/audio_effects_b.gd")
const PackC := preload("res://engine/audio_effects_c.gd")
const PackD := preload("res://engine/audio_effects_d.gd")
const PackE := preload("res://engine/audio_effects_e.gd")
const PackF := preload("res://engine/audio_effects_f.gd")
const PackG := preload("res://engine/audio_effects_g.gd")
const PackH := preload("res://engine/audio_effects_h.gd")
const PackI := preload("res://engine/audio_effects_i.gd")
const PackJ := preload("res://engine/audio_effects_j.gd")
const PackK := preload("res://engine/audio_effects_k.gd")

const DEFS: Array[Dictionary] = [
	{
		"id": "gain",
		"group": "Utility",
		"label": "Gain",
		"blurb": "Turns the clip up or down, with a short slew so a step does not click.",
		"params": [
			{"key": "db", "label": "Gain", "default": 0.0, "min": -80.0, "max": 24.0, "step": 0.1, "unit": " dB"},
		],
	},
	{
		"id": "pan",
		"group": "Stereo",
		"label": "Pan",
		"blurb": "Moves the clip between the speakers, constant power, so the middle is not louder.",
		"params": [
			{"key": "pan", "label": "Pan", "default": 0.0, "min": -1.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "lowpass",
		"group": "EQ and Filters",
		"label": "Low pass",
		"blurb": "Keeps what is below the cutoff and rolls off above it.",
		"params": [
			{"key": "cutoff", "label": "Cutoff", "default": 1000.0, "min": 10.0, "max": 20000.0, "step": 10.0, "unit": " Hz"},
			{"key": "q", "label": "Resonance", "default": 0.7071, "min": 0.1, "max": 20.0, "step": 0.01},
		],
	},
	{
		"id": "highpass",
		"group": "EQ and Filters",
		"label": "High pass",
		"blurb": "Keeps what is above the cutoff, for taking rumble out of a microphone.",
		"params": [
			{"key": "cutoff", "label": "Cutoff", "default": 100.0, "min": 10.0, "max": 20000.0, "step": 10.0, "unit": " Hz"},
			{"key": "q", "label": "Resonance", "default": 0.7071, "min": 0.1, "max": 20.0, "step": 0.01},
		],
	},
	{
		"id": "band_limit",
		"group": "EQ and Filters",
		"label": "Band limit",
		"blurb": "A telephone or radio sound, a low pass and a high pass together with optional bit crush.",
		"params": [
			{"key": "lowpass_hz", "label": "Low pass", "default": 20500.0, "min": 10.0, "max": 20500.0, "step": 10.0, "unit": " Hz"},
			{"key": "highpass_hz", "label": "High pass", "default": 0.0, "min": 0.0, "max": 1000.0, "step": 5.0, "unit": " Hz"},
			{"key": "crush", "label": "Crush", "default": 0.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "crossfeed",
		"group": "Stereo",
		"label": "Crossfeed",
		"blurb": "Lets each ear hear a little of the other side, late and dulled, the way it would in a room. Takes the hard left and right out of headphones.",
		"params": [
			{"key": "amount", "label": "Amount", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "cutoff", "label": "Only below", "default": 700.0, "min": 200.0, "max": 2000.0, "step": 10.0, "unit": " Hz"},
			{"key": "delay_ms", "label": "Delay", "default": 0.3, "min": 0.0, "max": 2.0, "step": 0.05, "unit": " ms"},
		],
	},
	{
		"id": "eq3",
		"group": "EQ and Filters",
		"label": "EQ, three band",
		"blurb": "Lifts or cuts three parts of the sound, each with its own frequency, amount and width.",
		"params": [
			{"key": "low_hz", "label": "Low frequency", "default": 120.0, "min": 20.0, "max": 20000.0, "step": 5.0, "unit": " Hz"},
			{"key": "low_db", "label": "Low", "default": 0.0, "min": -24.0, "max": 24.0, "step": 0.1, "unit": " dB"},
			{"key": "low_q", "label": "Low width", "default": 0.9, "min": 0.1, "max": 12.0, "step": 0.01},
			{"key": "mid_hz", "label": "Mid frequency", "default": 1000.0, "min": 20.0, "max": 20000.0, "step": 10.0, "unit": " Hz"},
			{"key": "mid_db", "label": "Mid", "default": 0.0, "min": -24.0, "max": 24.0, "step": 0.1, "unit": " dB"},
			{"key": "mid_q", "label": "Mid width", "default": 0.9, "min": 0.1, "max": 12.0, "step": 0.01},
			{"key": "high_hz", "label": "High frequency", "default": 8000.0, "min": 20.0, "max": 20000.0, "step": 50.0, "unit": " Hz"},
			{"key": "high_db", "label": "High", "default": 0.0, "min": -24.0, "max": 24.0, "step": 0.1, "unit": " dB"},
			{"key": "high_q", "label": "High width", "default": 0.9, "min": 0.1, "max": 12.0, "step": 0.01},
		],
	},
	{
		"id": "delay",
		"group": "Delay and Reverb",
		"label": "Delay",
		"blurb": "Repeats the sound after a gap, each repeat quieter and duller than the last.",
		"params": [
			{"key": "delay_ms", "label": "Time", "default": 250.0, "min": 0.0, "max": 4000.0, "step": 1.0, "unit": " ms"},
			{"key": "feedback", "label": "Repeats", "default": 0.35, "min": 0.0, "max": 0.95, "step": 0.01},
			{"key": "wet", "label": "Mix", "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "damp_hz", "label": "Repeats get duller above", "default": 6000.0, "min": 200.0, "max": 20000.0, "step": 50.0, "unit": " Hz"},
			{"key": "spread", "label": "Stereo spread", "default": 0.2, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "reverb",
		"group": "Delay and Reverb",
		"label": "Reverb",
		"blurb": "Puts the sound in a room, from a small booth to a hall.",
		"params": [
			{"key": "size", "label": "Room size", "default": 1.0, "min": 0.1, "max": 2.0, "step": 0.01},
			{"key": "decay", "label": "Tail", "default": 0.6, "min": 0.0, "max": 0.95, "step": 0.01},
			{"key": "wet", "label": "Mix", "default": 0.25, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "damp_hz", "label": "Soft above", "default": 5000.0, "min": 200.0, "max": 20000.0, "step": 50.0, "unit": " Hz"},
			{"key": "width", "label": "Width", "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "chorus",
		"group": "Modulation",
		"label": "Chorus",
		"blurb": "Doubles the sound with a slow wobble, so one voice sounds like several.",
		"params": [
			{"key": "rate_hz", "label": "Rate", "default": 0.6, "min": 0.01, "max": 10.0, "step": 0.01, "unit": " Hz"},
			{"key": "depth_ms", "label": "Depth", "default": 3.0, "min": 0.0, "max": 20.0, "step": 0.1, "unit": " ms"},
			{"key": "centre_ms", "label": "Spacing", "default": 12.0, "min": 1.0, "max": 40.0, "step": 0.1, "unit": " ms"},
			{"key": "wet", "label": "Mix", "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "stereo", "label": "Stereo", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "flanger",
		"group": "Modulation",
		"label": "Flanger",
		"blurb": "A sweeping jet sound, made by mixing the sound with a copy of itself a hair behind.",
		"params": [
			{"key": "rate_hz", "label": "Rate", "default": 0.25, "min": 0.01, "max": 10.0, "step": 0.01, "unit": " Hz"},
			{"key": "depth_ms", "label": "Depth", "default": 3.0, "min": 0.0, "max": 10.0, "step": 0.05, "unit": " ms"},
			{"key": "feedback", "label": "Feedback", "default": 0.3, "min": -0.95, "max": 0.95, "step": 0.01},
			{"key": "wet", "label": "Mix", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "tremolo",
		"group": "Modulation",
		"label": "Tremolo",
		"blurb": "Turns the sound up and down over and over, from a gentle sway to a hard chop.",
		"params": [
			{"key": "rate_hz", "label": "Rate", "default": 5.0, "min": 0.01, "max": 30.0, "step": 0.01, "unit": " Hz"},
			{"key": "depth", "label": "Depth", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "shape", "label": "Sway to chop", "default": 0.0, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "stereo", "label": "Left and right apart", "default": 0.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "distortion",
		"group": "Character",
		"label": "Distortion",
		"blurb": "Pushes the sound until it breaks up, four different ways of breaking.",
		"params": [
			{"key": "drive", "label": "Drive", "default": 4.0, "min": 1.0, "max": 60.0, "step": 0.1},
			{"key": "mode", "label": "Kind", "default": 0.0, "min": 0.0, "choices": ["Soft", "Hard", "Smooth", "Sine"]},
			{"key": "tone_hz", "label": "Tone", "default": 8000.0, "min": 500.0, "max": 20000.0, "step": 50.0, "unit": " Hz"},
			{"key": "wet", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "out_db", "label": "Output", "default": 0.0, "min": -24.0, "max": 12.0, "step": 0.1, "unit": " dB"},
		],
	},
	{
		"id": "bitcrush",
		"group": "Character",
		"label": "Bit Crush",
		"blurb": "Throws away bits and sample rate, for an old console or a broken radio sound.",
		"params": [
			{"key": "bits", "label": "Bits", "default": 8.0, "min": 1.0, "max": 16.0, "step": 0.1},
			{"key": "rate_hz", "label": "Sample rate", "default": 12000.0, "min": 200.0, "max": 48000.0, "step": 100.0, "unit": " Hz"},
			{"key": "wet", "label": "Mix", "default": 1.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "noise_gate",
		"group": "Dynamics",
		"label": "Noise Gate",
		"blurb": "Shuts the sound off when it drops below a level, for cutting room tone between words.",
		"params": [
			{"key": "threshold_db", "label": "Shuts below", "default": -45.0, "min": -90.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "attack_ms", "label": "Open time", "default": 2.0, "min": 0.1, "max": 200.0, "step": 0.1, "unit": " ms"},
			{"key": "hold_ms", "label": "Hold open", "default": 120.0, "min": 0.0, "max": 2000.0, "step": 1.0, "unit": " ms"},
			{"key": "release_ms", "label": "Close time", "default": 250.0, "min": 1.0, "max": 4000.0, "step": 1.0, "unit": " ms"},
			{"key": "floor_db", "label": "How far it shuts", "default": -90.0, "min": -90.0, "max": 0.0, "step": 0.5, "unit": " dB"},
		],
	},
	{
		"id": "limiter",
		"group": "Dynamics",
		"label": "Limiter",
		"blurb": "Stops the sound going above a ceiling, so nothing ever clips.",
		"params": [
			{"key": "ceiling_db", "label": "Ceiling", "default": -1.0, "min": -24.0, "max": 0.0, "step": 0.1, "unit": " dB"},
			{"key": "release_ms", "label": "Release", "default": 60.0, "min": 1.0, "max": 2000.0, "step": 1.0, "unit": " ms"},
			{"key": "in_db", "label": "Push in", "default": 0.0, "min": -12.0, "max": 24.0, "step": 0.1, "unit": " dB"},
		],
	},
	{
		"id": "stereo_width",
		"group": "Stereo",
		"label": "Stereo Width",
		"blurb": "Pushes the two channels apart or folds them together, right down to mono.",
		"params": [
			{"key": "width", "label": "Width", "default": 1.0, "min": 0.0, "max": 4.0, "step": 0.01},
			{"key": "mid_db", "label": "Middle", "default": 0.0, "min": -24.0, "max": 12.0, "step": 0.1, "unit": " dB"},
			{"key": "mono", "label": "Fold to mono", "default": 0.0, "min": 0.0, "max": 1.0, "step": 0.01},
		],
	},
	{
		"id": "compressor",
		"group": "Dynamics",
		"label": "Compressor",
		"blurb": "Holds the loud parts back so the quiet parts can come up.",
		"params": [
			{"key": "threshold_db", "label": "Threshold", "default": -18.0, "min": -80.0, "max": 0.0, "step": 0.5, "unit": " dB"},
			{"key": "ratio", "label": "Ratio", "default": 4.0, "min": 1.0, "max": 40.0, "step": 0.1},
			{"key": "attack_ms", "label": "Attack", "default": 10.0, "min": 0.1, "max": 500.0, "step": 0.1, "unit": " ms"},
			{"key": "release_ms", "label": "Release", "default": 100.0, "min": 1.0, "max": 5000.0, "step": 1.0, "unit": " ms"},
			{"key": "makeup_db", "label": "Makeup", "default": 0.0, "min": -24.0, "max": 24.0, "step": 0.1, "unit": " dB"},
			{"key": "knee_db", "label": "Knee", "default": 6.0, "min": 0.0, "max": 24.0, "step": 0.5, "unit": " dB"},
		],
	},
]


static func _param(raw: Dictionary) -> Dictionary:
	var choices: Array = []
	for c: Variant in raw.get("choices", []):
		choices.append(String(c))
	return {
		"key": String(raw["key"]),
		"label": String(raw.get("label", String(raw["key"]).capitalize())),
		"type": "enum" if not choices.is_empty() else "float",
		"min": float(raw.get("min", 0.0)),
		"max": float(choices.size() - 1) if not choices.is_empty() else float(raw.get("max", 1.0)),
		"step": 1.0 if not choices.is_empty() else float(raw.get("step", 0.01)),
		"default": float(raw.get("default", 0.0)),
		"choices": choices,
		"writes": {},
		"keyable": true,
		"unit": String(raw.get("unit", "")),
		"hidden": false,
		"group": "",
	}


static func all_raw() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(DEFS)
	out.append_array(PackA.DEFS)
	out.append_array(PackB.DEFS)
	out.append_array(PackC.DEFS)
	out.append_array(PackD.DEFS)
	out.append_array(PackE.DEFS)
	out.append_array(PackF.DEFS)
	out.append_array(PackG.DEFS)
	out.append_array(PackH.DEFS)
	out.append_array(PackI.DEFS)
	out.append_array(PackJ.DEFS)
	out.append_array(PackK.DEFS)
	return out


static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: Dictionary in all_raw():
		out.append(get_def(String(raw["id"])))
	return out


static func ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for raw: Dictionary in all_raw():
		out.append(String(raw["id"]))
	return out


static func native_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for raw: Dictionary in all_raw():
		if not raw.has("chain"):
			out.append(String(raw["id"]))
	return out


static func is_chain(id: String) -> bool:
	for raw: Dictionary in PackK.DEFS:
		if String(raw["id"]) == id:
			return true
	return false


static func has(id: String) -> bool:
	return ids().has(id)


static func get_def(id: String) -> Dictionary:
	for raw: Dictionary in all_raw():
		if String(raw["id"]) != id:
			continue
		var params: Array = []
		for p: Variant in raw["params"]:
			params.append(_param(p))
		return {
			"id": id,
			"label": String(raw["label"]),
			"category": CATEGORY,
			"group": String(raw.get("group", "")),
			"version": VERSION,
			"blurb": String(raw.get("blurb", "")),
			"params": params,
			"passes": [],
			"path": "",
			"source": "engine",
			"ok": true,
			"audio": true,
			"pairs_with": PackedStringArray(),
		}
	return {}


static func param_spec(id: String, key: String) -> Dictionary:
	for p: Variant in get_def(id).get("params", []):
		if String((p as Dictionary)["key"]) == key:
			return p
	return {}


static func default_params(id: String) -> Dictionary:
	var out: Dictionary = {}
	for p: Variant in get_def(id).get("params", []):
		out[String((p as Dictionary)["key"])] = AnimProp.make(float((p as Dictionary)["default"]))
	return out


static func is_audio_def(def: Dictionary) -> bool:
	return bool(def.get("audio", false))

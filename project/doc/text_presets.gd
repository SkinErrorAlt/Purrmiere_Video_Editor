extends RefCounted

const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const TextAnimators := preload("res://doc/text_animators.gd")
const RUN_ON := 3600.0
const SEED_RANGE := 99991
const PRESETS: Array = [
	{"id": "type_on", "label": "Type on, letter by letter", "set": {"opacity": 0.0, "whole": true}, "sweep": "start", "seconds": 1.0},
	{"id": "fade_words", "label": "Fade in word by word", "set": {"units": "words", "opacity": 0.0, "ease": "ease_both"}, "sweep": "start", "seconds": 1.0},
	{"id": "rise", "label": "Rise in, letter by letter", "set": {"opacity": 0.0, "pos": [0.0, 60.0], "ease": "ease_out"}, "sweep": "start", "seconds": 0.8},
	{"id": "pop_letters", "label": "Pop in, letter by letter", "set": {"opacity": 0.0, "scale": 0.0}, "sweep": "start", "seconds": 0.7},
	{"id": "drop_lines", "label": "Drop in line by line", "set": {"units": "lines", "opacity": 0.0, "pos": [0.0, -80.0], "ease": "ease_out"}, "sweep": "start", "seconds": 0.8},
	{"id": "wave", "label": "Wave", "set": {"shape": "wave", "pos": [0.0, -24.0], "frequency": 1.5}, "flow": 0.8},
	{"id": "wave_ramp", "label": "Wave, building up", "set": {"shape": "wave", "pos": [0.0, -24.0], "frequency": 1.5}, "flow": 0.8, "ramp": 1.5},
	{"id": "wave_settle", "label": "Wave, settling down", "set": {"shape": "wave", "pos": [0.0, -24.0], "frequency": 1.5}, "flow": 0.8, "damp": 2.0},
	{"id": "bounce", "label": "Bounce through", "set": {"shape": "round", "start": 0.0, "end": 25.0, "pos": [0.0, -36.0]}, "slide": 1.2},
	{"id": "jitter", "label": "Jitter, its own seed", "set": {"shape": "random", "rotation": 10.0, "pos": [0.0, -6.0]}, "seed": true},
	{"id": "jitter_reroll", "label": "Jitter, new pattern every half second", "set": {"shape": "random", "rotation": 10.0, "pos": [0.0, -6.0]}, "seed": true, "reroll": 0.5},
	{"id": "colour_sweep", "label": "Colour sweep", "set": {"shape": "smooth", "start": 0.0, "end": 30.0, "colour_on": true, "colour": [1.0, 0.82, 0.2, 1.0]}, "slide": 1.5},
]


static func listing() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in PRESETS:
		out.append(p.duplicate(true))
	return out


static func find(id: String) -> Dictionary:
	for p: Dictionary in PRESETS:
		if String(p["id"]) == id:
			return p.duplicate(true)
	return {}


static func linear(points: Array) -> Dictionary:
	var first: Array = points[0]
	var p: Dictionary = AnimProp.make(first[1])
	for pt: Variant in points:
		var a: Array = pt
		p = AnimProp.set_key(p, float(a[0]), a[1], String(a[2]) if a.size() > 2 else "linear")
	return p


static func seed_for(c: Clip) -> int:
	if c == null:
		return 1
	return absi(hash(c.id + "|" + c.media_id)) % SEED_RANGE + 1


static func applied(props: Dictionary, preset_id: String, c: Clip = null, fps: float = 30.0, opts: Dictionary = {}) -> Dictionary:
	var p: Dictionary = find(preset_id)
	var settings: Dictionary = (p.get("set", {}) as Dictionary).duplicate(true) if not p.is_empty() else {}
	if not p.is_empty():
		settings["name"] = String(p["label"])
	var out: Dictionary = TextAnimators.with_added(props, settings)
	var i: int = TextAnimators.count(out) - 1
	if p.is_empty() or i < 0:
		return out
	var dur: float = c.duration if c != null and c.duration > 0.0 else 3.0
	var speed: float = float(opts.get("speed", 1.0))
	if p.has("sweep"):
		var secs: float = minf(float(opts.get("seconds", p["seconds"])), dur)
		out[TextAnimators.key(i, String(p["sweep"]))] = linear([[0.0, 0.0], [maxf(secs, 1.0 / maxf(fps, 1.0)), 100.0]])
	if p.has("flow"):
		var per_second: float = float(p["flow"]) * 100.0 * speed
		out[TextAnimators.key(i, "offset")] = linear([[0.0, 0.0], [RUN_ON, per_second * RUN_ON]])
	if p.has("slide"):
		var across: float = float(p["slide"]) / maxf(speed, 0.001)
		out[TextAnimators.key(i, "offset")] = linear([[0.0, -40.0], [minf(across, dur), 100.0]])
	if p.has("ramp"):
		out[TextAnimators.key(i, "amount")] = linear([[0.0, 0.0], [minf(float(opts.get("ramp", p["ramp"])), dur), 100.0, "ease_out"]])
	if p.has("damp"):
		out[TextAnimators.key(i, "amount")] = linear([[0.0, 100.0], [minf(float(opts.get("damp", p["damp"])), dur), 0.0, "ease_in"]])
	if bool(p.get("seed", false)):
		var base: int = int(opts.get("seed", seed_for(c)))
		var every: float = float(opts.get("reroll", p.get("reroll", 0.0)))
		if every <= 0.0:
			out[TextAnimators.key(i, "seed")] = float(base)
		else:
			var keyed: Dictionary = AnimProp.make(float(base))
			var t: float = 0.0
			var n: int = 0
			while t <= dur + every and n < 2000:
				keyed = AnimProp.set_key(keyed, t, float((base + n * 7919) % SEED_RANGE), "hold")
				t += every
				n += 1
			out[TextAnimators.key(i, "seed")] = keyed
	return out

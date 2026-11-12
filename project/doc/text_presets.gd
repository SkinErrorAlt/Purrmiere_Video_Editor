extends RefCounted

const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const TextAnimators := preload("res://doc/text_animators.gd")
const RUN_ON := 3600.0
const SEED_RANGE := 99991
const MOTION_GROUP := "Letter animation"
const SAMPLE := "Headline"
const SAMPLE_MAX := 11
const PREVIEW_FRAME := 175.0
const REST_POINT := 1.0
const LOOP_SECONDS := 2.4
const LOOK_SCALED: PackedStringArray = ["size", "outline", "letter_spacing", "line_spacing", "shadow_distance", "shadow_softness", "box_pad", "box_radius"]
const ANIM_SCALED: PackedStringArray = ["tracking", "blur"]
const MOTION_KEYS: PackedStringArray = ["set", "sweep", "flow", "slide", "ramp", "damp", "seed"]
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
const LOOKS: Array = [
	{
		"id": "look_clean_caps",
		"label": "Clean caps",
		"group": "Titles",
		"detail": "Wide white capitals with a soft dark halo, one word at a time",
		"look": {"size": 58.0, "uppercase": true, "bold": false, "letter_spacing": 12.0, "colour": [1.0, 1.0, 1.0, 1.0], "outline": 0.0, "shadow_on": true, "shadow_colour": [0.0, 0.0, 0.0, 0.55], "shadow_distance": 0.0, "shadow_softness": 26.0, "box_colour": [0.0, 0.0, 0.0, 0.0], "align": "center", "valign": "center", "width": 0.82},
		"set": {"units": "words", "opacity": 0.0, "ease": "ease_both"},
		"sweep": "start",
		"seconds": 1.1,
	},
	{
		"id": "look_bar_lower_third",
		"label": "Dark bar lower third",
		"group": "Lower thirds",
		"detail": "Bold white text on a dark bar at the bottom left, sliding in letter by letter",
		"look": {"size": 48.0, "bold": true, "uppercase": false, "letter_spacing": 2.0, "colour": [1.0, 1.0, 1.0, 1.0], "outline": 0.0, "shadow_on": false, "box_colour": [0.04, 0.04, 0.06, 0.86], "box_pad": 22.0, "box_radius": 4.0, "align": "left", "valign": "bottom", "width": 0.9},
		"set": {"opacity": 0.0, "pos": [-26.0, 0.0], "ease": "ease_out"},
		"sweep": "start",
		"seconds": 0.7,
	},
	{
		"id": "look_outline_pop",
		"label": "Bold outline pop",
		"group": "Social",
		"detail": "Heavy capitals with a thick dark edge, popping in letter by letter",
		"look": {"size": 76.0, "bold": true, "uppercase": true, "letter_spacing": 1.0, "colour": [1.0, 1.0, 1.0, 1.0], "outline": 16.0, "outline_colour": [0.05, 0.05, 0.08, 1.0], "shadow_on": true, "shadow_colour": [0.0, 0.0, 0.0, 0.45], "shadow_distance": 9.0, "shadow_angle": 180.0, "shadow_softness": 10.0, "box_colour": [0.0, 0.0, 0.0, 0.0], "align": "center", "valign": "center", "width": 0.82},
		"set": {"opacity": 0.0, "scale": 0.0, "ease": "ease_out"},
		"sweep": "start",
		"seconds": 0.8,
	},
	{
		"id": "look_highlight",
		"label": "Yellow highlight",
		"group": "Social",
		"detail": "Dark text on a yellow block, growing in word by word",
		"look": {"size": 58.0, "bold": true, "uppercase": false, "letter_spacing": 0.0, "colour": [0.08, 0.07, 0.05, 1.0], "outline": 0.0, "shadow_on": false, "box_colour": [1.0, 0.84, 0.16, 1.0], "box_pad": 16.0, "box_radius": 6.0, "align": "center", "valign": "center", "width": 0.72},
		"set": {"units": "words", "opacity": 0.0, "scale": 70.0, "ease": "ease_out"},
		"sweep": "start",
		"seconds": 0.8,
	},
	{
		"id": "look_neon",
		"label": "Neon glow",
		"group": "Titles",
		"detail": "Pale capitals with a cyan edge and glow, easing on across the line",
		"look": {"size": 68.0, "bold": true, "uppercase": true, "letter_spacing": 5.0, "colour": [0.94, 1.0, 1.0, 1.0], "outline": 4.0, "outline_colour": [0.1, 0.94, 1.0, 0.95], "shadow_on": true, "shadow_colour": [0.06, 0.78, 1.0, 1.0], "shadow_distance": 0.0, "shadow_softness": 20.0, "box_colour": [0.0, 0.0, 0.0, 0.0], "align": "center", "valign": "center", "width": 0.84},
		"set": {"shape": "smooth", "opacity": 0.0, "ease": "ease_both"},
		"sweep": "start",
		"seconds": 0.9,
	},
	{
		"id": "look_soft_quote",
		"label": "Quote card",
		"group": "Titles",
		"detail": "Narrow italic lines on a soft dark card, rising in line by line",
		"look": {"size": 46.0, "bold": false, "italic": true, "uppercase": false, "letter_spacing": 1.0, "line_spacing": 14.0, "colour": [1.0, 0.98, 0.94, 1.0], "outline": 0.0, "shadow_on": true, "shadow_colour": [0.0, 0.0, 0.0, 0.45], "shadow_distance": 6.0, "shadow_angle": 160.0, "shadow_softness": 18.0, "box_colour": [0.03, 0.03, 0.05, 0.52], "box_pad": 34.0, "box_radius": 18.0, "align": "center", "valign": "center", "width": 0.5},
		"set": {"units": "lines", "opacity": 0.0, "pos": [0.0, 26.0], "ease": "ease_out"},
		"sweep": "start",
		"seconds": 0.9,
	},
	{
		"id": "look_subtitle_bar",
		"label": "Subtitle bar",
		"group": "Lower thirds",
		"detail": "Small white text on a see through black bar, fading on quickly",
		"look": {"size": 40.0, "bold": false, "uppercase": false, "letter_spacing": 0.0, "colour": [1.0, 1.0, 1.0, 1.0], "outline": 0.0, "shadow_on": false, "box_colour": [0.0, 0.0, 0.0, 0.62], "box_pad": 14.0, "box_radius": 4.0, "align": "center", "valign": "bottom", "width": 0.7},
		"set": {"opacity": 0.0, "ease": "ease_both"},
		"sweep": "start",
		"seconds": 0.25,
	},
]


static func listing() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in PRESETS:
		out.append(p.duplicate(true))
	return out


static func looks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in LOOKS:
		out.append(p.duplicate(true))
	return out


static func motion_only() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in PRESETS:
		var row: Dictionary = p.duplicate(true)
		row["group"] = MOTION_GROUP
		row["detail"] = "Letter animation on its own, the look you already have is kept"
		out.append(row)
	return out


static func all_listing() -> Array[Dictionary]:
	var out: Array[Dictionary] = looks()
	out.append_array(motion_only())
	return out


static func groups() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for p: Dictionary in LOOKS:
		var g: String = String(p.get("group", ""))
		if not g.is_empty() and not out.has(g):
			out.append(g)
	out.append(MOTION_GROUP)
	return out


static func find(id: String) -> Dictionary:
	for p: Dictionary in PRESETS:
		if String(p["id"]) == id:
			return p.duplicate(true)
	for q: Dictionary in LOOKS:
		if String(q["id"]) == id:
			return q.duplicate(true)
	return {}


static func ships(id: String) -> bool:
	return not find(id).is_empty()


static func has_look(id: String) -> bool:
	return not look_of(id).is_empty()


static func look_of(id: String) -> Dictionary:
	var p: Dictionary = find(id)
	var l: Variant = p.get("look", null)
	return (l as Dictionary).duplicate(true) if l is Dictionary else {}


static func has_motion(id: String) -> bool:
	var p: Dictionary = find(id)
	if p.is_empty():
		return false
	for k: String in MOTION_KEYS:
		if p.has(k):
			return true
	return false


static func writes(id: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in look_of(id).keys():
		out.append(String(k))
	return out


static func styled(props: Dictionary, id: String) -> Dictionary:
	var out: Dictionary = props.duplicate(true)
	var look: Dictionary = look_of(id)
	for k: Variant in look.keys():
		if String(k) == "text":
			continue
		out[String(k)] = look[k]
	return out


static func full(props: Dictionary, id: String, c: Clip = null, fps: float = 30.0, opts: Dictionary = {}) -> Dictionary:
	var out: Dictionary = props.duplicate(true)
	if bool(opts.get("replace_motion", false)):
		out = TextAnimators.strip(out)
	if has_motion(id):
		out = applied(out, id, c, fps, opts)
	return styled(out, id)


static func sample_text(text: String) -> String:
	var want: String = text.strip_edges()
	if want.is_empty():
		return SAMPLE
	var line: String = want.split("\n")[0].strip_edges()
	if line.is_empty():
		return SAMPLE
	if line.length() <= SAMPLE_MAX:
		return line
	var cut: String = line.substr(0, SAMPLE_MAX)
	var space: int = cut.rfind(" ")
	if space >= 4:
		cut = cut.substr(0, space)
	return cut.strip_edges()


static func moment(id: String) -> float:
	var p: Dictionary = find(id)
	if p.has("sweep"):
		return maxf(float(p.get("seconds", 1.0)), 0.2) * REST_POINT
	if p.has("ramp"):
		return float(p["ramp"]) * 0.6
	if p.has("damp"):
		return float(p["damp"]) * 0.3
	return 0.9


static func preview_props(id: String, text: String) -> Dictionary:
	var props: Dictionary = TitleStyle.title_defaults()
	props["text"] = sample_text(text)
	var c: Clip = Clip.new()
	c.id = "textpreview"
	c.media_id = id
	c.duration = LOOP_SECONDS
	return full(props, id, c, 30.0)


static func preview_clip(id: String, text: String) -> Clip:
	var c: Clip = Clip.new()
	c.id = "textpreview"
	c.media_id = id
	c.duration = LOOP_SECONDS
	c.props = preview_props(id, text)
	return c


static func scaled(props: Dictionary, f: float) -> Dictionary:
	var out: Dictionary = props.duplicate(true)
	for k: String in LOOK_SCALED:
		var v: Variant = out.get(k, null)
		if v is float or v is int:
			out[k] = float(v) * f
	for i: int in TextAnimators.count(props):
		for k2: String in ANIM_SCALED:
			var ak: String = TextAnimators.key(i, k2)
			var av: Variant = out.get(ak, null)
			if av is float or av is int:
				out[ak] = float(av) * f
		var pk: String = TextAnimators.key(i, "pos")
		var pv: Variant = out.get(pk, null)
		if pv is Array and (pv as Array).size() >= 2:
			out[pk] = [float((pv as Array)[0]) * f, float((pv as Array)[1]) * f]
	return out


static func shadow_pass(props: Dictionary) -> Dictionary:
	if not bool(props.get("shadow_on", false)):
		return {}
	var c: Color = TitleStyle.colour_of(props.get("shadow_colour", null), Color(0.0, 0.0, 0.0, 0.6))
	if c.a <= 0.001:
		return {}
	var off: Vector2 = TitleStyle.shadow_offset(float(props.get("shadow_distance", 6.0)), float(props.get("shadow_angle", 135.0)))
	var out: Dictionary = props.duplicate(true)
	out["outline"] = 0.0
	out["box_colour"] = [0.0, 0.0, 0.0, 0.0]
	out["colour"] = [1.0, 1.0, 1.0, 1.0]
	return TextAnimators.with_added(out, {"name": "Shadow", "colour_on": true, "colour": [c.r, c.g, c.b, c.a], "pos": [off.x, off.y], "blur": maxf(float(props.get("shadow_softness", 8.0)), 0.0)})


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

extends RefCounted

const P := preload("res://doc/text_fx/fx_params.gd")
const Ciphers := preload("res://doc/text_fx/fx_ciphers.gd")
const Encodings := preload("res://doc/text_fx/fx_encodings.gd")
const FxCrypto := preload("res://doc/text_fx/fx_crypto.gd")
const Horror := preload("res://doc/text_fx/fx_horror.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const TextRuns := preload("res://doc/text_runs.gd")
const TextExtras := preload("res://doc/text_extras.gd")
const APPLIES_TEXT := "text"
const OFF := "off"
const PREVIEW_CHARS := 64
const SAMPLE := "Hello World 42"
const RIG_CHAR := "lr_c"
const REFUSAL := "Text effects go on titles only: drop it on a text clip"
const TRANSFORMS: PackedStringArray = [
	"caesar", "rot13", "rot47", "atbash", "vigenere", "affine", "rail_fence", "bacon", "a1z26", "morse",
	"binary", "octal", "hex", "base32", "base64", "url", "html_entities", "reverse", "upside_down", "leetspeak",
	"keyboard_shift", "xor", "aes", "hash", "hmac", "decode_reveal", "subliminal", "redact", "glitch", "zalgo",
	"vhs_osd", "first_letters", "every_nth", "timed_reveal",
]


static func text_only(def: Dictionary) -> bool:
	return String(def.get("applies_to", "")) == APPLIES_TEXT


static func transform_of(def: Dictionary) -> String:
	return String(def.get("text_transform", ""))


static func known(transform: String) -> bool:
	return TRANSFORMS.has(transform)


static func run_one(transform: String, text: String, p: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	match transform:
		"caesar":
			return Ciphers.caesar(text, p)
		"rot13":
			return Ciphers.rot13(text, p)
		"rot47":
			return Ciphers.rot47(text, p)
		"atbash":
			return Ciphers.atbash(text, p)
		"vigenere":
			return Ciphers.vigenere(text, p)
		"affine":
			return Ciphers.affine(text, p)
		"rail_fence":
			return Ciphers.rail_fence(text, p)
		"bacon":
			return Ciphers.bacon(text, p)
		"a1z26":
			return Ciphers.a1z26(text, p)
		"reverse":
			return Ciphers.reverse(text, p)
		"upside_down":
			return Ciphers.upside_down(text, p)
		"leetspeak":
			return Ciphers.leetspeak(text, p)
		"keyboard_shift":
			return Ciphers.keyboard_shift(text, p)
		"morse":
			return Encodings.morse(text, p)
		"binary":
			return Encodings.binary(text, p)
		"octal":
			return Encodings.octal(text, p)
		"hex":
			return Encodings.hex(text, p)
		"base32":
			return Encodings.base32(text, p)
		"base64":
			return Encodings.base64(text, p)
		"url":
			return Encodings.url(text, p)
		"html_entities":
			return Encodings.html_entities(text, p)
		"xor":
			return FxCrypto.xor_text(text, p)
		"aes":
			return FxCrypto.aes(text, p)
		"hash":
			return FxCrypto.digest_text(text, p)
		"hmac":
			return FxCrypto.hmac_text(text, p)
		"decode_reveal":
			return Horror.decode_reveal(text, p, ctx)
		"subliminal":
			return Horror.subliminal(text, p, ctx)
		"redact":
			return Horror.redact(text, p, ctx)
		"glitch":
			return Horror.glitch(text, p, ctx)
		"zalgo":
			return Horror.zalgo(text, p, ctx)
		"vhs_osd":
			return Horror.vhs_osd(text, p, ctx)
		"first_letters":
			return Horror.first_letters(text, p, ctx)
		"every_nth":
			return Horror.every_nth(text, p, ctx)
		"timed_reveal":
			return Horror.timed_reveal(text, p, ctx)
	return P.unchanged(text, "This text effect isn't known to this version of Purrmiere, so the text passes through unchanged")


static func defaults_of(def: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for spec: Variant in def.get("params", []):
		if spec is Dictionary:
			out[String((spec as Dictionary).get("key", ""))] = (spec as Dictionary).get("default", null)
	return out


static func run_def(def: Dictionary, text: String, values: Dictionary = {}, ctx: Dictionary = {}) -> Dictionary:
	var p: Dictionary = defaults_of(def)
	for k: Variant in values.keys():
		p[k] = values[k]
	return run_one(transform_of(def), text, p, ctx)


static func values_at(c: Clip, e: Dictionary, def: Dictionary, local_t: float, fps: float) -> Dictionary:
	var out: Dictionary = {}
	var params: Dictionary = e.get("params", {})
	for spec_v: Variant in def.get("params", []):
		if not (spec_v is Dictionary):
			continue
		var spec: Dictionary = spec_v
		var key: String = String(spec.get("key", ""))
		var pv: Variant = params.get(key, null)
		if pv is Dictionary:
			var kt: float = c.fx_time(e, key, local_t) if e.has(Clip.AnimTime.SPEEDS_FIELD) else c.anim_time(local_t)
			out[key] = AnimProp.evaluate(pv, kt, c.duration, fps)
		else:
			out[key] = spec.get("default", null)
	return out


static func mix_at(c: Clip, e: Dictionary, local_t: float, fps: float) -> float:
	var m: Variant = e.get("mix", null)
	if not (m is Dictionary):
		return 1.0
	var kt: float = c.fx_time(e, "mix", local_t) if e.has(Clip.AnimTime.SPEEDS_FIELD) else c.anim_time(local_t)
	return clampf(AnimProp.evaluate_float(m, kt, c.duration, fps), 0.0, 1.0)


static func steps(c: Clip, defs: Object) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null or defs == null:
		return out
	for e: Dictionary in c.effects:
		var def: Dictionary = defs.call("get_def", String(e.get("id", "")))
		if text_only(def):
			out.append({"e": e, "def": def})
	return out


static func has_text_fx(c: Clip, defs: Object) -> bool:
	if c == null or defs == null or c.effects.is_empty():
		return false
	for e: Dictionary in c.effects:
		if text_only(defs.call("get_def", String(e.get("id", "")))):
			return true
	return false


static func identity(n: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(n)
	for i: int in n:
		out[i] = i
	return out


static func step_map(r: Dictionary, in_len: int, out_len: int) -> Dictionary:
	var m: Variant = r.get("map", null)
	if m is PackedInt32Array and (m as PackedInt32Array).size() == out_len:
		return {"map": m, "exact": true}
	if in_len == out_len:
		return {"map": identity(out_len), "exact": true}
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(out_len)
	for j: int in out_len:
		out[j] = mini(int(floor(float(j) * float(in_len) / float(maxi(out_len, 1)))), in_len - 1) if in_len > 0 else -1
	return {"map": out, "exact": false}


## Runs a list of text effects in order, each on the previous one's output. Each step is
## {"def": Dictionary, "values": Dictionary, "amount": float, "enabled": bool, "uid": String}.
static func run_steps(list: Array, text: String, ctx: Dictionary = {}) -> Dictionary:
	var cur: String = text
	var marks: Array = []
	var map: PackedInt32Array = identity(text.length())
	var rows: Array[Dictionary] = []
	for st_v: Variant in list:
		var st: Dictionary = st_v
		var def: Dictionary = st.get("def", {})
		var row: Dictionary = {"uid": String(st.get("uid", "")), "id": String(def.get("id", "")), "label": String(def.get("label", "")), "in": cur}
		if not bool(st.get("enabled", true)):
			row["out"] = cur
			row["level"] = OFF
			row["say"] = "Turned off, so the text passes through"
			rows.append(row)
			continue
		var r: Dictionary = run_def(def, cur, st.get("values", {}), ctx)
		var out: String = String(r.get("text", cur))
		var sm: Dictionary = step_map(r, cur.length(), out.length())
		var smap: PackedInt32Array = sm["map"]
		var new_marks: Array = []
		new_marks.resize(out.length())
		var styles: Array = r.get("styles", [])
		for j: int in out.length():
			var carried: Dictionary = {}
			if bool(sm["exact"]) and j < smap.size() and smap[j] >= 0 and smap[j] < marks.size() and marks[smap[j]] is Dictionary:
				carried = (marks[smap[j]] as Dictionary).duplicate()
			if j < styles.size() and styles[j] is Dictionary:
				for k: Variant in (styles[j] as Dictionary).keys():
					carried[k] = (styles[j] as Dictionary)[k]
			new_marks[j] = carried
		var amount: float = clampf(float(st.get("amount", 1.0)), 0.0, 1.0)
		if amount < 0.9999:
			var take_out: int = int(roundf(amount * float(out.length())))
			var take_in: int = int(roundf(amount * float(cur.length())))
			var blended: String = out.substr(0, take_out) + cur.substr(take_in)
			var bmap: PackedInt32Array = smap.slice(0, take_out)
			var bmarks: Array = new_marks.slice(0, take_out)
			for i: int in range(take_in, cur.length()):
				bmap.append(i)
				bmarks.append(marks[i] if i < marks.size() and marks[i] is Dictionary else {})
			out = blended
			smap = bmap
			new_marks = bmarks
			row["amount"] = amount
		var composed: PackedInt32Array = PackedInt32Array()
		composed.resize(smap.size())
		for j2: int in smap.size():
			var s: int = smap[j2]
			composed[j2] = map[s] if s >= 0 and s < map.size() else -1
		map = composed
		marks = new_marks
		cur = out
		row["out"] = cur
		row["level"] = String(r.get("level", P.WORKS))
		row["say"] = String(r.get("say", ""))
		rows.append(row)
	return {"rows": rows, "text": cur, "marks": marks, "map": map}


static func clip_steps(c: Clip, defs: Object, local_t: float, fps: float) -> Array:
	var list: Array = []
	for st: Dictionary in steps(c, defs):
		var e: Dictionary = st["e"]
		var def: Dictionary = st["def"]
		list.append({
			"def": def,
			"uid": String(e.get("uid", "")),
			"enabled": bool(e.get("enabled", true)),
			"values": values_at(c, e, def, local_t, fps),
			"amount": mix_at(c, e, local_t, fps),
		})
	return list


static func context(c: Clip, local_t: float, fps: float) -> Dictionary:
	return {"t": local_t, "fps": fps if fps > 0.0 else 30.0, "dur": c.duration if c != null else 0.0}


static func run_clip(c: Clip, defs: Object, text: String, local_t: float, fps: float) -> Dictionary:
	return run_steps(clip_steps(c, defs, local_t, fps), text, context(c, local_t, fps))


static func base_text(props: Dictionary, fallback_text: String) -> String:
	if not props.has("text"):
		return fallback_text
	return TextExtras.shown_text(props)


## Puts the clip's text effects into a title's props for drawing: the text, its styling runs
## (carried along with the characters) and the letter rig's per letter values.
static func apply_to_props(c: Clip, defs: Object, props: Dictionary, fallback_text: String, local_t: float, fps: float) -> bool:
	if not has_text_fx(c, defs):
		return false
	var base: String = base_text(props, fallback_text)
	var run: Dictionary = run_clip(c, defs, base, local_t, fps)
	var out_text: String = run["text"]
	var marks: Array = run["marks"]
	var any_mark: bool = false
	for m: Variant in marks:
		if m is Dictionary and not (m as Dictionary).is_empty():
			any_mark = true
			break
	if out_text == base and not any_mark:
		return false
	var map: PackedInt32Array = run["map"]
	var in_runs: Array[Dictionary] = TextRuns.for_props(props, base)
	var built: Array = []
	for j: int in out_text.length():
		var src: int = map[j] if j < map.size() else -1
		var st: Dictionary = TextRuns.style_at(in_runs, src if src >= 0 else 0)
		if j < marks.size() and marks[j] is Dictionary and not (marks[j] as Dictionary).is_empty():
			st = TextRuns.merge_style(st, marks[j])
		built.append(TextRuns.make(out_text[j], st))
	props[TextRuns.RUNS_KEY] = TextRuns.encode(TextRuns.canonical(built))
	props["text"] = out_text
	props["counter_on"] = false
	remap_rig(props, map)
	return true


static func remap_rig(props: Dictionary, map: PackedInt32Array) -> void:
	var by_char: Dictionary = {}
	for k: Variant in props.keys():
		var key: String = String(k)
		if not key.begins_with(RIG_CHAR):
			continue
		var rest: String = key.substr(RIG_CHAR.length())
		var cut: int = rest.find("_")
		if cut <= 0 or not rest.substr(0, cut).is_valid_int():
			continue
		var ci: int = rest.substr(0, cut).to_int()
		if not by_char.has(ci):
			by_char[ci] = {}
		(by_char[ci] as Dictionary)[rest.substr(cut + 1)] = props[k]
	if by_char.is_empty():
		return
	for ci2: Variant in by_char.keys():
		for field: Variant in (by_char[ci2] as Dictionary).keys():
			props.erase(RIG_CHAR + str(ci2) + "_" + String(field))
	for j: int in map.size():
		if by_char.has(map[j]):
			var fields: Dictionary = by_char[map[j]]
			for field2: Variant in fields.keys():
				props[RIG_CHAR + str(j) + "_" + String(field2)] = fields[field2]


static func preview(s: String, limit: int = PREVIEW_CHARS) -> String:
	var one: String = s.replace("\r", "").replace("\n", " ⏎ ")
	if one.length() > limit:
		return one.substr(0, limit - 1) + "…"
	return one


const LEVEL_WORDS: Dictionary = {"ok": "Works", "note": "Works, with a note", "one_way": "One way", "idle": "Nothing to change", "fail": "Can't work on this", "off": "Off"}
const LEVEL_COLOURS: Dictionary = {"ok": Color(0.45, 0.85, 0.5), "note": Color(0.95, 0.8, 0.35), "one_way": Color(0.55, 0.75, 1.0), "fail": Color(1.0, 0.45, 0.4)}


static func level_word(level: String) -> String:
	return String(LEVEL_WORDS.get(level, ""))


static func level_colour(level: String) -> Color:
	return LEVEL_COLOURS.get(level, Color(0.65, 0.65, 0.65))


## The info shown in the Effects panel for a text effect: what it does and a worked example.
static func about(def: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var blurb: String = String(def.get("blurb", ""))
	if not blurb.is_empty():
		lines.append(blurb)
	var r: Dictionary = run_def(def, SAMPLE, {}, {"t": 1.0, "fps": 30.0})
	lines.append("Example: \"" + SAMPLE + "\" becomes \"" + preview(String(r.get("text", "")), 48) + "\"")
	var say: String = String(r.get("say", ""))
	if not say.is_empty():
		lines.append(level_word(String(r.get("level", ""))) + ": " + say)
	lines.append("Text only: it goes on titles, and stacks in order with the other text effects; each one changes what the one above it made.")
	return "\n".join(lines)

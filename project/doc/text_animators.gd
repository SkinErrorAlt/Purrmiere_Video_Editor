extends RefCounted

const COUNT_KEY := "ta_count"
const MAX_ANIMATORS := 8
const UNITS: PackedStringArray = ["characters", "characters_no_spaces", "words", "lines"]
const UNIT_LABELS: PackedStringArray = ["Characters", "Characters, not spaces", "Words", "Lines"]
const SHAPES: PackedStringArray = ["square", "ramp_up", "ramp_down", "triangle", "round", "smooth", "wave", "random"]
const SHAPE_LABELS: PackedStringArray = ["Square", "Ramp up", "Ramp down", "Triangle", "Round", "Smooth", "Wave", "Random"]
const EASES: PackedStringArray = ["linear", "ease_in", "ease_out", "ease_both"]
const EASE_LABELS: PackedStringArray = ["Straight", "Ease in", "Ease out", "Ease in and out"]
const NUMBER_FIELDS: PackedStringArray = ["start", "end", "offset", "amount", "frequency", "seed", "scale", "rotation", "opacity", "tracking"]
const VECTOR_FIELDS: PackedStringArray = ["pos"]
const COLOUR_FIELDS: PackedStringArray = ["colour"]


static func defaults() -> Dictionary:
	return {
		"on": true,
		"name": "",
		"units": "characters",
		"shape": "square",
		"start": 0.0,
		"end": 100.0,
		"offset": 0.0,
		"amount": 100.0,
		"ease": "linear",
		"frequency": 1.0,
		"seed": 0.0,
		"pos": [0.0, 0.0],
		"scale": 100.0,
		"rotation": 0.0,
		"opacity": 100.0,
		"colour_on": false,
		"colour": [1.0, 1.0, 1.0, 1.0],
		"tracking": 0.0,
		"blur": 0.0,
		"skew": 0.0,
		"run": false,
		"whole": false,
	}


static func key(i: int, field: String) -> String:
	return "ta%d_%s" % [i, field]


static func plain(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("v"):
			return plain(d["v"])
		if d.has("base"):
			return plain(d["base"])
		return null
	return v


static func count(props: Dictionary) -> int:
	var v: Variant = plain(props.get(COUNT_KEY, 0))
	if not (v is int or v is float):
		return 0
	return clampi(int(v), 0, MAX_ANIMATORS)


static func animator(props: Dictionary, i: int) -> Dictionary:
	var out: Dictionary = defaults()
	for f: Variant in out.keys():
		var k: String = key(i, String(f))
		if not props.has(k):
			continue
		var v: Variant = plain(props[k])
		if v == null:
			continue
		out[String(f)] = v
	if not UNITS.has(String(out["units"])):
		out["units"] = "characters"
	if not SHAPES.has(String(out["shape"])):
		out["shape"] = "square"
	if not EASES.has(String(out["ease"])):
		out["ease"] = "linear"
	return out


static func list(props: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in count(props):
		var a: Dictionary = animator(props, i)
		if bool(a["on"]):
			out.append(a)
	return out


static func active(props: Dictionary) -> bool:
	return not list(props).is_empty()


static func is_space(ch: String) -> bool:
	return ch == " " or ch == "\t" or ch == "\n" or ch == "\r"


static func unit_map(text: String, units: String, line_of: PackedInt32Array) -> Dictionary:
	var idx: PackedInt32Array = PackedInt32Array()
	idx.resize(text.length())
	var n: int = 0
	if units == "lines":
		for i: int in text.length():
			idx[i] = line_of[i] if i < line_of.size() else 0
			n = maxi(n, idx[i] + 1)
		return {"index": idx, "count": maxi(n, 1)}
	if units == "words":
		var in_word: bool = false
		var w: int = -1
		for i2: int in text.length():
			var sp: bool = is_space(text[i2])
			if not sp and not in_word:
				w += 1
			in_word = not sp
			idx[i2] = maxi(w, 0) if not sp else -1
		return {"index": idx, "count": maxi(w + 1, 1)}
	var c: int = 0
	for i3: int in text.length():
		if units == "characters_no_spaces" and is_space(text[i3]):
			idx[i3] = -1
			continue
		idx[i3] = c
		c += 1
	return {"index": idx, "count": maxi(c, 1)}


static func eased(w: float, ease: String) -> float:
	var x: float = clampf(w, 0.0, 1.0)
	if ease == "ease_in":
		return x * x
	if ease == "ease_out":
		return 1.0 - (1.0 - x) * (1.0 - x)
	if ease == "ease_both":
		return x * x * (3.0 - 2.0 * x)
	return x


static func hash01(seed: int, unit: int) -> float:
	var h: int = (seed * 73856093) ^ (unit * 19349663) ^ 83492791
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


static func weight(a: Dictionary, unit: int, total: int) -> float:
	if unit < 0 or total <= 0:
		return 0.0
	var n: float = float(total)
	var u0: float = float(unit) / n
	var u1: float = float(unit + 1) / n
	var mid: float = (u0 + u1) * 0.5
	var off: float = float(a["offset"]) / 100.0
	var shape: String = String(a["shape"])
	var slide: float = 0.0 if shape == "wave" else off
	var lo: float = minf(float(a["start"]), float(a["end"])) / 100.0 + slide
	var hi: float = maxf(float(a["start"]), float(a["end"])) / 100.0 + slide
	var w: float = 0.0
	if shape == "wave":
		var inside: float = clampf((minf(u1, hi) - maxf(u0, lo)) * n, 0.0, 1.0)
		w = inside * (0.5 + 0.5 * sin(TAU * (float(a["frequency"]) * mid + off)))
	elif shape == "random":
		var inside2: float = clampf((minf(u1, hi) - maxf(u0, lo)) * n, 0.0, 1.0)
		w = inside2 * hash01(int(float(a["seed"])), unit)
	elif shape == "square" and bool(a.get("whole", false)):
		w = 1.0 if u0 >= lo - 0.0001 / n and u0 < hi - 0.0001 / n else 0.0
	elif shape == "square":
		w = clampf((minf(u1, hi) - maxf(u0, lo)) * n, 0.0, 1.0)
	else:
		if mid < lo or mid > hi or hi - lo <= 0.0:
			w = 0.0
		else:
			var t: float = (mid - lo) / (hi - lo)
			if shape == "ramp_up":
				w = t
			elif shape == "ramp_down":
				w = 1.0 - t
			elif shape == "triangle":
				w = 1.0 - absf(2.0 * t - 1.0)
			elif shape == "round":
				var x: float = 2.0 * t - 1.0
				w = sqrt(maxf(1.0 - x * x, 0.0))
			else:
				w = 0.5 - 0.5 * cos(TAU * t)
	return eased(w, String(a["ease"])) * clampf(float(a["amount"]), -100.0, 100.0) / 100.0


static func vec(v: Variant) -> Vector2:
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float((v as Array)[0]), float((v as Array)[1]))
	if v is Vector2:
		return v
	return Vector2.ZERO


static func colour(v: Variant) -> Color:
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
	return Color.WHITE


static func glyph_state(anims: Array[Dictionary], maps: Array[Dictionary], char_index: int) -> Dictionary:
	var pos: Vector2 = Vector2.ZERO
	var scale: float = 1.0
	var rot: float = 0.0
	var opacity: float = 1.0
	var tint: Color = Color(0, 0, 0, 0)
	var tint_w: float = 0.0
	var tracking: float = 0.0
	var blur: float = 0.0
	var skew: float = 0.0
	for i: int in anims.size():
		var a: Dictionary = anims[i]
		var m: Dictionary = maps[i]
		var idx: PackedInt32Array = m["index"]
		var unit: int = idx[char_index] if char_index >= 0 and char_index < idx.size() else -1
		var w: float = weight(a, unit, int(m["count"]))
		if absf(w) <= 0.0:
			continue
		pos += vec(a["pos"]) * w
		scale *= 1.0 + (float(a["scale"]) / 100.0 - 1.0) * w
		rot += float(a["rotation"]) * w
		opacity *= clampf(1.0 + (float(a["opacity"]) / 100.0 - 1.0) * w, 0.0, 1.0)
		tracking += float(a["tracking"]) * w
		blur += absf(float(a.get("blur", 0.0)) * w)
		skew += float(a.get("skew", 0.0)) * w
		if bool(a["colour_on"]):
			var cw: float = clampf(w, 0.0, 1.0)
			tint = colour(a["colour"]) if tint_w <= 0.0 else tint.lerp(colour(a["colour"]), cw)
			tint_w = maxf(tint_w, cw)
	return {"pos": pos, "scale": scale, "rot": rot, "opacity": opacity, "tint": tint, "tint_w": tint_w, "tracking": tracking, "blur": blur, "skew": skew}


static func with_added(props: Dictionary, preset: Dictionary = {}) -> Dictionary:
	var out: Dictionary = props.duplicate(true)
	var n: int = count(props)
	if n >= MAX_ANIMATORS:
		return out
	var d: Dictionary = defaults()
	for f: Variant in preset.keys():
		d[String(f)] = preset[f]
	if String(d["name"]).is_empty():
		d["name"] = "Animator " + str(n + 1)
	for f2: Variant in d.keys():
		out[key(n, String(f2))] = d[f2]
	out[COUNT_KEY] = n + 1
	return out


static func with_removed(props: Dictionary, at: int) -> Dictionary:
	var out: Dictionary = props.duplicate(true)
	var n: int = count(props)
	if at < 0 or at >= n:
		return out
	for i: int in range(at, n):
		for f: Variant in defaults().keys():
			var dst: String = key(i, String(f))
			var src: String = key(i + 1, String(f))
			if i + 1 < n and props.has(src):
				out[dst] = (props[src] as Variant)
			else:
				out.erase(dst)
	if n - 1 <= 0:
		out.erase(COUNT_KEY)
	else:
		out[COUNT_KEY] = n - 1
	return out


static func with_moved(props: Dictionary, at: int, step: int) -> Dictionary:
	var n: int = count(props)
	var to: int = at + step
	if at < 0 or at >= n or to < 0 or to >= n:
		return props.duplicate(true)
	var out: Dictionary = props.duplicate(true)
	for f: Variant in defaults().keys():
		var ka: String = key(at, String(f))
		var kb: String = key(to, String(f))
		var va: Variant = props.get(ka)
		var vb: Variant = props.get(kb)
		if vb == null:
			out.erase(ka)
		else:
			out[ka] = vb
		if va == null:
			out.erase(kb)
		else:
			out[kb] = va
	return out


static func without_run(props: Dictionary) -> Dictionary:
	var out: Dictionary = props.duplicate(true)
	for i: int in range(count(props) - 1, -1, -1):
		if bool(plain(out.get(key(i, "run"), false))):
			out = with_removed(out, i)
	return out


static func strip(props: Dictionary) -> Dictionary:
	var out: Dictionary = props.duplicate(true)
	for k: Variant in props.keys():
		var s: String = String(k)
		if s == COUNT_KEY or (s.begins_with("ta") and s.length() > 3 and s.substr(2, 1).is_valid_int() and s.contains("_")):
			out.erase(k)
	return out

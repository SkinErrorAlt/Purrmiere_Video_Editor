extends RefCounted
## The letter rig: every letter, word and line of a title is a bone with its own keyframes, posed like a rig in a
## 3D animator. A bone's values are ordinary title props named lr_<bone>_<field> (so every keyframe tool works on
## them), where <bone> is "all" (the whole text), "l<n>" (line n), "w<n>" (word n) or "c<n>" (character n of the
## shown text). A letter's final placement is whole * line * word * letter, each turned about its own pivot, so
## moving a word carries its letters and a letter's own keys ride on top.

const AnimProp := preload("res://doc/anim_prop.gd")

const PREFIX := "lr_"
const ROOT := "all"
const FIELDS: PackedStringArray = ["pos", "rot", "scale", "opacity", "skew", "tint", "blur", "pivot"]
const FIELD_LABELS: Dictionary = {"pos": "Position", "rot": "Rotation", "scale": "Scale", "opacity": "Opacity", "skew": "Skew", "tint": "Colour", "blur": "Blur", "pivot": "Pivot"}
const KINDS: PackedStringArray = ["all", "l", "w", "c"]
const STAGGER_ORDERS: PackedStringArray = ["forward", "backward", "from_centre", "to_centre", "random"]
const STAGGER_LABELS: PackedStringArray = ["First to last", "Last to first", "From the middle out", "From the ends in", "Random"]


static func defaults() -> Dictionary:
	return {"pos": [0.0, 0.0], "rot": 0.0, "scale": [100.0, 100.0], "opacity": 100.0, "skew": 0.0, "tint": [1.0, 1.0, 1.0, 0.0], "blur": 0.0, "pivot": [0.0, 0.0]}


static func default_of(field: String) -> Variant:
	return (defaults().get(field, 0.0) as Variant)


static func key(bone: String, field: String) -> String:
	return PREFIX + bone + "_" + field


## [bone, field] for a rig prop name, or [] when it isn't one.
static func parse(prop: String) -> PackedStringArray:
	if not prop.begins_with(PREFIX):
		return PackedStringArray()
	var rest: String = prop.substr(PREFIX.length())
	var cut: int = rest.find("_")
	if cut <= 0:
		return PackedStringArray()
	var bone: String = rest.substr(0, cut)
	var field: String = rest.substr(cut + 1)
	if not FIELDS.has(field) or not valid_bone(bone):
		return PackedStringArray()
	return PackedStringArray([bone, field])


static func is_rig_prop(prop: String) -> bool:
	return parse(prop).size() == 2


static func valid_bone(bone: String) -> bool:
	if bone == ROOT:
		return true
	if bone.length() < 2:
		return false
	var head: String = bone.substr(0, 1)
	return (head == "l" or head == "w" or head == "c") and bone.substr(1).is_valid_int() and int(bone.substr(1)) >= 0


static func kind_of(bone: String) -> String:
	return ROOT if bone == ROOT else bone.substr(0, 1)


static func index_of(bone: String) -> int:
	return -1 if bone == ROOT else int(bone.substr(1))


static func bone(kind: String, i: int) -> String:
	return ROOT if kind == ROOT else kind + str(i)


static func active(props: Dictionary) -> bool:
	for k: Variant in props.keys():
		if String(k).begins_with(PREFIX) and is_rig_prop(String(k)):
			return true
	return false


## Bones that have any value, whole text first, then lines, words and letters in order.
static func bones_in(props: Dictionary) -> PackedStringArray:
	var seen: Dictionary = {}
	for k: Variant in props.keys():
		var p: PackedStringArray = parse(String(k))
		if p.size() == 2:
			seen[p[0]] = true
	return sorted(PackedStringArray(seen.keys()))


static func sorted(bones: PackedStringArray) -> PackedStringArray:
	var arr: Array = Array(bones)
	arr.sort_custom(func(a: String, b: String) -> bool:
		var ka: int = KINDS.find(kind_of(a))
		var kb: int = KINDS.find(kind_of(b))
		if ka != kb:
			return ka < kb
		return index_of(a) < index_of(b))
	return PackedStringArray(arr)


static func plain(v: Variant) -> Variant:
	if v is Dictionary and AnimProp.is_animated(v):
		return AnimProp.static_value(v)
	if v is Dictionary and (v as Dictionary).has("v"):
		return (v as Dictionary)["v"]
	return v


static func value(props: Dictionary, bone_id: String, field: String) -> Variant:
	var v: Variant = props.get(key(bone_id, field), null)
	return default_of(field) if v == null else plain(v)


static func vec(v: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if v is Vector2:
		return v
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float((v as Array)[0]), float((v as Array)[1]))
	if v is float or v is int:
		return Vector2(float(v), float(v))
	return fallback


static func colour(v: Variant) -> Color:
	if v is Color:
		return v
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
	return Color(1, 1, 1, 0)


## Everything one bone says, already in the units drawing needs (scale as a factor, angles in radians).
static func pose(props: Dictionary, bone_id: String) -> Dictionary:
	return {
		"pos": vec(value(props, bone_id, "pos")),
		"rot": deg_to_rad(float(value(props, bone_id, "rot"))),
		"scale": vec(value(props, bone_id, "scale"), Vector2(100, 100)) / 100.0,
		"opacity": clampf(float(value(props, bone_id, "opacity")) / 100.0, 0.0, 1.0),
		"skew": deg_to_rad(clampf(float(value(props, bone_id, "skew")), -80.0, 80.0)),
		"tint": colour(value(props, bone_id, "tint")),
		"blur": maxf(float(value(props, bone_id, "blur")), 0.0),
		"pivot": vec(value(props, bone_id, "pivot")),
	}


static func is_rest(p: Dictionary) -> bool:
	return (p["pos"] as Vector2).is_zero_approx() and is_zero_approx(float(p["rot"])) and (p["scale"] as Vector2).is_equal_approx(Vector2.ONE) and is_zero_approx(float(p["skew"]))


## The bone's transform in canvas pixels, turning about rest_pivot plus the bone's own pivot offset.
## scale_f converts 1080-line units to the canvas.
static func xf(p: Dictionary, rest_pivot: Vector2, scale_f: float) -> Transform2D:
	if is_rest(p):
		return Transform2D.IDENTITY
	var pv: Vector2 = rest_pivot + (p["pivot"] as Vector2) * scale_f
	var moved: Vector2 = (p["pos"] as Vector2) * scale_f
	return Transform2D(float(p["rot"]), p["scale"] as Vector2, float(p["skew"]), pv + moved) * Transform2D(0.0, -pv)


## Word number of every character (-1 for whitespace), counting whitespace-separated words from 0.
static func word_map(text: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(text.length())
	var w: int = -1
	var in_word: bool = false
	for i: int in text.length():
		var ch: String = text.substr(i, 1)
		var space: bool = ch == " " or ch == "\t" or ch == "\n" or ch == "\r"
		if space:
			out[i] = -1
			in_word = false
			continue
		if not in_word:
			w += 1
			in_word = true
		out[i] = w
	return out


## The word (from, to) span in characters, or (-1, -1).
static func word_span(text: String, w: int) -> Vector2i:
	var m: PackedInt32Array = word_map(text)
	var a: int = -1
	var b: int = -1
	for i: int in m.size():
		if m[i] == w:
			if a < 0:
				a = i
			b = i + 1
	return Vector2i(a, b)


static func word_at(text: String, char_index: int) -> int:
	var m: PackedInt32Array = word_map(text)
	return m[char_index] if char_index >= 0 and char_index < m.size() else -1


## A name for the bone a person reads: "Whole text", "Line 2", "Word 3 \"Hello\"", "Letter \"e\" (5)".
static func label(text: String, bone_id: String) -> String:
	var k: String = kind_of(bone_id)
	var i: int = index_of(bone_id)
	if k == ROOT:
		return "Whole text"
	if k == "l":
		return "Line " + str(i + 1)
	if k == "w":
		var sp: Vector2i = word_span(text, i)
		var word: String = text.substr(sp.x, sp.y - sp.x) if sp.x >= 0 else ""
		return "Word " + str(i + 1) + (" \"" + word + "\"" if not word.is_empty() else "")
	var ch: String = text.substr(i, 1) if i < text.length() else ""
	if ch == " ":
		ch = "space"
	return "Letter \"" + ch + "\" (" + str(i + 1) + ")" if not ch.is_empty() else "Letter " + str(i + 1)


static func field_label(field: String) -> String:
	return String(FIELD_LABELS.get(field, field.capitalize()))


## Parent chain of a letter bone, outermost first: whole text, its line, its word, the letter.
static func chain(char_index: int, word: int, line: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray([ROOT, "l" + str(line)])
	if word >= 0:
		out.append("w" + str(word))
	out.append("c" + str(char_index))
	return out


## Props with the rig bones moved after a text edit that replaced `removed` characters at `at` with `added` new
## ones. Letters inside the replaced span lose their keys; letters after it move; words follow the letter they
## start with. Returns the whole new props dictionary (raw, keys and all), or {} when nothing changes.
static func remapped(props: Dictionary, before: String, after: String, at: int, removed: int, added: int) -> Dictionary:
	var bones: PackedStringArray = bones_in(props)
	var any: bool = false
	for b: String in bones:
		var k: String = kind_of(b)
		if k == "c" and index_of(b) >= at:
			any = true
		elif k == "w":
			any = true
	if not any:
		return {}
	var old_words: PackedInt32Array = word_map(before)
	var new_words: PackedInt32Array = word_map(after)
	var word_to: Dictionary = {}
	var start_of: Dictionary = {}
	for i: int in old_words.size():
		var w: int = old_words[i]
		if w >= 0 and not start_of.has(w):
			start_of[w] = i
	for w2: Variant in start_of.keys():
		var c0: int = int(start_of[w2])
		var nc: int = moved_char(c0, at, removed, added)
		word_to[int(w2)] = new_words[nc] if nc >= 0 and nc < new_words.size() else -1
	var out: Dictionary = {}
	var moves: Dictionary = {}
	for k2: Variant in props.keys():
		var name: String = String(k2)
		var p: PackedStringArray = parse(name)
		if p.size() != 2:
			out[name] = props[k2]
			continue
		var b2: String = p[0]
		var kind: String = kind_of(b2)
		var nb: String = b2
		if kind == "c":
			var ni: int = moved_char(index_of(b2), at, removed, added)
			nb = "" if ni < 0 else "c" + str(ni)
		elif kind == "w":
			var nw: int = int(word_to.get(index_of(b2), -1))
			nb = "" if nw < 0 else "w" + str(nw)
		if nb.is_empty():
			continue
		if nb == b2:
			out[name] = props[k2]
		else:
			moves[key(nb, p[1])] = props[k2]
	var changed: bool = moves.size() > 0 or out.size() != props.size()
	for m: Variant in moves.keys():
		out[m] = moves[m]
	return out if changed else {}


## Where character `i` lands after replacing `removed` characters at `at` with `added`; -1 when it was replaced.
static func moved_char(i: int, at: int, removed: int, added: int) -> int:
	if i < at:
		return i
	if i < at + removed:
		return -1
	return i - removed + added


## The common prefix and suffix of two strings as [at, removed, added].
static func edit_of(before: String, after: String) -> PackedInt32Array:
	var shortest: int = mini(before.length(), after.length())
	var pre: int = 0
	while pre < shortest and before.unicode_at(pre) == after.unicode_at(pre):
		pre += 1
	var suf: int = 0
	while suf < shortest - pre and before.unicode_at(before.length() - 1 - suf) == after.unicode_at(after.length() - 1 - suf):
		suf += 1
	return PackedInt32Array([pre, before.length() - pre - suf, after.length() - pre - suf])


## Every key time of a bone (all its fields), sorted, in clip seconds.
static func key_times(props: Dictionary, bone_id: String) -> PackedFloat32Array:
	var seen: Dictionary = {}
	for f: String in FIELDS:
		var v: Variant = props.get(key(bone_id, f), null)
		if v is Dictionary and AnimProp.is_animated(v):
			for kd: Dictionary in AnimProp.keys(v):
				seen[snappedf(float(kd.get("t", 0.0)), 0.0001)] = true
	var arr: Array = seen.keys()
	arr.sort()
	return PackedFloat32Array(arr)


## Props with each bone's keys shifted later by its place in the order times step seconds, so the same
## animation runs letter after letter. Bones with no keys are left alone.
static func staggered(props: Dictionary, bones: PackedStringArray, step: float, order: String = "forward", seed: int = 1) -> Dictionary:
	var out: Dictionary = props.duplicate(true)
	var n: int = bones.size()
	if n == 0 or is_zero_approx(step):
		return out
	var rank: PackedFloat32Array = stagger_ranks(n, order, seed)
	for i: int in n:
		var delta: float = step * rank[i]
		if is_zero_approx(delta):
			continue
		for f: String in FIELDS:
			var k: String = key(bones[i], f)
			var v: Variant = out.get(k, null)
			if v is Dictionary and AnimProp.is_animated(v):
				out[k] = AnimProp.shift_keys(v, delta)
	return out


static func stagger_ranks(n: int, order: String, seed: int = 1) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var mid: float = float(n - 1) * 0.5
	for i: int in n:
		match order:
			"backward":
				out[i] = float(n - 1 - i)
			"from_centre":
				out[i] = absf(float(i) - mid)
			"to_centre":
				out[i] = mid - absf(float(i) - mid)
			"random":
				out[i] = float(i)
			_:
				out[i] = float(i)
	if order == "random" and n > 1:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed
		for i2: int in range(n - 1, 0, -1):
			var j: int = rng.randi_range(0, i2)
			var t: float = out[i2]
			out[i2] = out[j]
			out[j] = t
	var lo: float = INF
	for r: float in out:
		lo = minf(lo, r)
	for i3: int in n:
		out[i3] -= lo
	return out


## A bone's values at this moment, for Copy pose.
static func pose_values(props: Dictionary, bone_id: String) -> Dictionary:
	var out: Dictionary = {}
	for f: String in FIELDS:
		if props.has(key(bone_id, f)):
			out[f] = value(props, bone_id, f)
	return out


## Props with every rig value removed (Reset the rig), or only those of the given bones.
static func without(props: Dictionary, bones: PackedStringArray = PackedStringArray()) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in props.keys():
		var p: PackedStringArray = parse(String(k))
		if p.size() == 2 and (bones.is_empty() or bones.has(p[0])):
			continue
		out[k] = props[k]
	return out


## The combined look a letter gets from its chain: opacity multiplies, blur adds, the innermost tint wins.
static func look(poses: Array) -> Dictionary:
	var opacity: float = 1.0
	var blur: float = 0.0
	var tint: Color = Color(1, 1, 1, 0)
	for p: Dictionary in poses:
		opacity *= float(p["opacity"])
		blur += float(p["blur"])
		var t: Color = p["tint"]
		if t.a > 0.0005:
			tint = t
	return {"opacity": opacity, "blur": blur, "tint": tint}


## Applies the rig to one laid-out line of glyphs (as TextGlyphs.place_line returns them, each with "ci", its
## character index). word_of maps characters to words, line is the line number, line_rect its rest box, root
## the whole block's rest centre.
static func apply_line(props: Dictionary, placed: Array, word_of: PackedInt32Array, line: int, line_rect: Rect2, root: Vector2, scale_f: float, cache: Dictionary) -> void:
	if placed.is_empty():
		return
	var word_box: Dictionary = {}
	for g: Dictionary in placed:
		var ci: int = int(g.get("ci", -1))
		var w: int = word_of[ci] if ci >= 0 and ci < word_of.size() else -1
		if w < 0:
			continue
		var at: Vector2 = g["at"]
		var r: Rect2 = Rect2(at.x, at.y - float(g.get("asc", 0.0)), float(g.get("adv", 0.0)), float(g.get("asc", 0.0)) + float(g.get("desc", 0.0)))
		word_box[w] = (word_box[w] as Rect2).merge(r) if word_box.has(w) else r
	var root_pose: Dictionary = _pose_cached(props, ROOT, cache)
	var root_xf: Transform2D = xf(root_pose, root, scale_f)
	var line_pose: Dictionary = _pose_cached(props, "l" + str(line), cache)
	var line_xf: Transform2D = xf(line_pose, line_rect.get_center(), scale_f)
	for g2: Dictionary in placed:
		var ci2: int = int(g2.get("ci", -1))
		var w2: int = word_of[ci2] if ci2 >= 0 and ci2 < word_of.size() else -1
		var poses: Array = [root_pose, line_pose]
		var m: Transform2D = root_xf * line_xf
		if w2 >= 0:
			var wp: Dictionary = _pose_cached(props, "w" + str(w2), cache)
			poses.append(wp)
			m = m * xf(wp, (word_box[w2] as Rect2).get_center(), scale_f)
		var cp: Dictionary = _pose_cached(props, "c" + str(ci2), cache)
		poses.append(cp)
		var gx: Transform2D = g2["xf"]
		var at2: Vector2 = g2["at"]
		var centre_local: Vector2 = at2 + Vector2(float(g2.get("adv", 0.0)) * 0.5, -(float(g2.get("asc", 0.0)) - float(g2.get("desc", 0.0))) * 0.5)
		m = m * xf(cp, gx * centre_local, scale_f)
		if m != Transform2D.IDENTITY:
			g2["xf"] = m * gx
		var lk: Dictionary = look(poses)
		g2["opacity"] = float(g2.get("opacity", 1.0)) * float(lk["opacity"])
		g2["blur"] = float(g2.get("blur", 0.0)) + float(lk["blur"]) * scale_f
		var tint: Color = lk["tint"]
		if tint.a > 0.0005:
			var tw: float = clampf(tint.a, 0.0, 1.0)
			var was: Color = g2.get("tint", Color(0, 0, 0, 0))
			var was_w: float = float(g2.get("tint_w", 0.0))
			g2["tint"] = Color(tint.r, tint.g, tint.b, 1.0) if was_w <= 0.0 else was.lerp(Color(tint.r, tint.g, tint.b, 1.0), tw)
			g2["tint_w"] = maxf(was_w, tw)


static func _pose_cached(props: Dictionary, bone_id: String, cache: Dictionary) -> Dictionary:
	if not cache.has(bone_id):
		cache[bone_id] = pose(props, bone_id)
	return cache[bone_id]

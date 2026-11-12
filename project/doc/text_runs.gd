extends RefCounted

const RUNS_KEY := "runs"
const KIND_TEXT := "text"
const STYLE_KEYS: PackedStringArray = ["font", "size", "bold", "italic", "colour", "letter_spacing", "outline", "outline_colour", "underline", "baseline", "script", "small_caps", "highlight", "text_opacity", "tsume"]
const NUMBER_KEYS: PackedStringArray = ["size", "letter_spacing", "outline", "baseline", "text_opacity", "tsume"]
const BOOL_KEYS: PackedStringArray = ["bold", "italic", "underline", "small_caps"]
const COLOUR_KEYS: PackedStringArray = ["colour", "outline_colour", "highlight"]
const STYLE_LABELS: PackedStringArray = ["Font", "Size", "Bold", "Italic", "Colour", "Letter spacing", "Outline", "Outline colour", "Underline", "Baseline shift", "Superscript or subscript", "Small caps", "Highlight", "Opacity", "Tsume"]
const SCRIPTS: PackedStringArray = ["", "super", "sub"]
const CACHE_CAP := 64

static var _cache: Dictionary = {}


static func forget() -> void:
	_cache.clear()


static func plain(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("v"):
			return plain(d["v"])
		if d.has("base"):
			return plain(d["base"])
		return null
	return v


static func decode(v: Variant) -> Array:
	if v is Array:
		return v
	if v is String:
		if String(v).strip_edges().is_empty():
			return []
		var parsed: Variant = JSON.parse_string(String(v))
		return parsed if parsed is Array else []
	return []


static func stored(props: Dictionary) -> Array:
	return decode(plain(props.get(RUNS_KEY, null)))


static func active(props: Dictionary) -> bool:
	for r: Variant in stored(props):
		if not run_style(r).is_empty():
			return true
	return false


static func colour_list(v: Variant) -> Array:
	if v is Color:
		var c: Color = v
		return [c.r, c.g, c.b, c.a]
	if v is Array:
		var a: Array = v
		if a.size() >= 3:
			return [float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0]
	if v is String:
		var h: Color = Color.html(String(v))
		return [h.r, h.g, h.b, h.a]
	return []


static func sanitise_style(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	var src: Dictionary = raw
	for k: String in STYLE_KEYS:
		if not src.has(k):
			continue
		var v: Variant = plain(src[k])
		if v == null:
			continue
		if NUMBER_KEYS.has(k):
			if v is float or v is int:
				out[k] = float(v)
		elif BOOL_KEYS.has(k):
			out[k] = bool(v)
		elif COLOUR_KEYS.has(k):
			var c: Array = colour_list(v)
			if not c.is_empty():
				out[k] = c
		elif k == "font":
			if v is String:
				out[k] = String(v)
		elif k == "script":
			if v is String and SCRIPTS.has(String(v)):
				out[k] = String(v)
	return out


static func style_id(style: Dictionary) -> String:
	return JSON.stringify(sanitise_style(style))


static func same_style(a: Dictionary, b: Dictionary) -> bool:
	return style_id(a) == style_id(b)


static func make(text: String, style: Dictionary) -> Dictionary:
	return {"kind": KIND_TEXT, "text": text, "style": sanitise_style(style)}


static func run_text(r: Variant) -> String:
	if not (r is Dictionary):
		return ""
	var v: Variant = plain((r as Dictionary).get("text", ""))
	return String(v) if v is String else ""


static func run_style(r: Variant) -> Dictionary:
	if not (r is Dictionary):
		return {}
	return sanitise_style((r as Dictionary).get("style", {}))


static func from_text(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not text.is_empty():
		out.append(make(text, {}))
	return out


static func text_of(runs: Array) -> String:
	var out: String = ""
	for r: Variant in runs:
		out += run_text(r)
	return out


static func length_of(runs: Array) -> int:
	var n: int = 0
	for r: Variant in runs:
		n += run_text(r).length()
	return n


static func canonical(runs: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Variant in runs:
		var t: String = run_text(r)
		if t.is_empty():
			continue
		var st: Dictionary = run_style(r)
		if not out.is_empty() and same_style(out[out.size() - 1]["style"], st):
			out[out.size() - 1]["text"] = String(out[out.size() - 1]["text"]) + t
			continue
		out.append(make(t, st))
	return out


static func style_at(runs: Array, index: int) -> Dictionary:
	if runs.is_empty():
		return {}
	var pos: int = 0
	for r: Variant in runs:
		var n: int = run_text(r).length()
		if index < pos + n:
			return run_style(r)
		pos += n
	return run_style(runs[runs.size() - 1])


static func styles_in(runs: Array, from: int, to: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var a: int = mini(from, to)
	var b: int = maxi(from, to)
	var pos: int = 0
	for r: Variant in runs:
		var n: int = run_text(r).length()
		if pos < b and pos + n > a:
			out.append(run_style(r))
		pos += n
	return out


static func common_value(runs: Array, from: int, to: int, key: String, fallback: Variant) -> Variant:
	var seen: Array[Dictionary] = styles_in(runs, from, to)
	if seen.is_empty():
		return fallback
	var first: Variant = seen[0].get(key, fallback)
	for st: Dictionary in seen:
		if JSON.stringify(st.get(key, fallback)) != JSON.stringify(first):
			return null
	return first


static func split(runs: Array, at: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pos: int = 0
	for r: Variant in runs:
		var t: String = run_text(r)
		var st: Dictionary = run_style(r)
		if at > pos and at < pos + t.length():
			out.append(make(t.substr(0, at - pos), st))
			out.append(make(t.substr(at - pos), st))
		else:
			out.append(make(t, st))
		pos += t.length()
	return out


static func merge_style(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = sanitise_style(base)
	for k: Variant in patch.keys():
		var name_: String = String(k)
		if not STYLE_KEYS.has(name_):
			continue
		if patch[k] == null:
			out.erase(name_)
		else:
			out[name_] = patch[k]
	return sanitise_style(out)


static func apply(runs: Array, from: int, to: int, patch: Dictionary) -> Array[Dictionary]:
	var total: int = length_of(runs)
	var a: int = clampi(mini(from, to), 0, total)
	var b: int = clampi(maxi(from, to), 0, total)
	if a == b or patch.is_empty():
		return canonical(runs)
	var work: Array[Dictionary] = split(split(runs, a), b)
	var out: Array[Dictionary] = []
	var pos: int = 0
	for r: Dictionary in work:
		var t: String = run_text(r)
		var st: Dictionary = run_style(r)
		if pos >= a and pos + t.length() <= b:
			st = merge_style(st, patch)
		out.append(make(t, st))
		pos += t.length()
	return canonical(out)


static func remove(runs: Array, from: int, to: int) -> Array[Dictionary]:
	var total: int = length_of(runs)
	var a: int = clampi(mini(from, to), 0, total)
	var b: int = clampi(maxi(from, to), 0, total)
	if a == b:
		return canonical(runs)
	var work: Array[Dictionary] = split(split(runs, a), b)
	var out: Array[Dictionary] = []
	var pos: int = 0
	for r: Dictionary in work:
		var t: String = run_text(r)
		if pos >= a and pos + t.length() <= b:
			pos += t.length()
			continue
		out.append(make(t, run_style(r)))
		pos += t.length()
	return canonical(out)


static func insert(runs: Array, at: int, text: String, style: Dictionary) -> Array[Dictionary]:
	if text.is_empty():
		return canonical(runs)
	var total: int = length_of(runs)
	var pt: int = clampi(at, 0, total)
	var work: Array[Dictionary] = split(runs, pt)
	var out: Array[Dictionary] = []
	var pos: int = 0
	var done: bool = false
	for r: Dictionary in work:
		if pos == pt and not done:
			out.append(make(text, style))
			done = true
		out.append(r)
		pos += run_text(r).length()
	if not done:
		out.append(make(text, style))
	return canonical(out)


static func sync_text(runs: Array, text: String) -> Array[Dictionary]:
	var cur: String = text_of(runs)
	if cur == text:
		return canonical(runs)
	if runs.is_empty() or text.is_empty():
		return from_text(text)
	var shortest: int = mini(cur.length(), text.length())
	var pre: int = 0
	while pre < shortest and cur.unicode_at(pre) == text.unicode_at(pre):
		pre += 1
	var suf: int = 0
	while suf < shortest - pre and cur.unicode_at(cur.length() - 1 - suf) == text.unicode_at(text.length() - 1 - suf):
		suf += 1
	var mid: String = text.substr(pre, text.length() - pre - suf)
	var cut: Array[Dictionary] = remove(runs, pre, cur.length() - suf)
	var st: Dictionary = style_at(runs, pre - 1) if pre > 0 else style_at(runs, pre)
	return insert(cut, pre, mid, st)


static func for_props(props: Dictionary, text: String) -> Array[Dictionary]:
	var held: Variant = plain(props.get(RUNS_KEY, null))
	if held is String:
		var ck: String = String(held) + "\n\u0001\n" + text
		if _cache.has(ck):
			return _cache[ck]
		var made: Array[Dictionary] = _read(decode(held), text)
		if _cache.size() >= CACHE_CAP:
			_cache.clear()
		_cache[ck] = made
		return made
	return _read(decode(held), text)


static func _read(raw: Array, text: String) -> Array[Dictionary]:
	if raw.is_empty():
		return from_text(text)
	return sync_text(raw, text)


static func to_store(runs: Array) -> Array:
	var out: Array = []
	for r: Dictionary in canonical(runs):
		out.append({"kind": KIND_TEXT, "text": String(r["text"]), "style": (r["style"] as Dictionary).duplicate(true)})
	return out


static func encode(runs: Array) -> String:
	return JSON.stringify(to_store(runs))


static func trivial(runs: Array) -> bool:
	for r: Variant in runs:
		if not run_style(r).is_empty():
			return false
	return true


static func upper_runs(runs: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Variant in runs:
		out.append(make(run_text(r).to_upper(), run_style(r)))
	return out


static func cut_runs(runs: Array, shown: int) -> Array[Dictionary]:
	if shown >= length_of(runs):
		return canonical(runs)
	return remove(runs, shown, length_of(runs))


static func char_runs(runs: Array) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in runs.size():
		var n: int = run_text(runs[i]).length()
		for c: int in n:
			out.append(i)
	return out

extends RefCounted

const KEY := "para_align"
const PATH := "props.para_align"
const ALIGNS: PackedStringArray = ["left", "center", "right", "justify", "justify_center", "justify_right", "justify_all"]


static func plain(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("v"):
			return plain(d["v"])
		if d.has("base"):
			return plain(d["base"])
		return null
	return v


static func decode(v: Variant) -> PackedStringArray:
	var raw: Variant = plain(v)
	var out: PackedStringArray = PackedStringArray()
	if raw is String:
		if String(raw).is_empty():
			return out
		for part: String in String(raw).split(","):
			out.append(part.strip_edges() if ALIGNS.has(part.strip_edges()) else "")
	elif raw is Array or raw is PackedStringArray:
		for part2: Variant in raw:
			var s: String = String(part2) if part2 is String else ""
			out.append(s if ALIGNS.has(s) else "")
	return out


static func encode(list: PackedStringArray) -> String:
	var trimmed: PackedStringArray = list.duplicate()
	while not trimmed.is_empty() and trimmed[trimmed.size() - 1].is_empty():
		trimmed.resize(trimmed.size() - 1)
	return ",".join(trimmed)


static func stored(props: Dictionary) -> PackedStringArray:
	return decode(props.get(KEY, null))


static func title_align(props: Dictionary) -> String:
	var a: Variant = plain(props.get("align", "center"))
	return String(a) if a is String and ALIGNS.has(String(a)) else "center"


static func active(props: Dictionary) -> bool:
	var base: String = title_align(props)
	for a: String in stored(props):
		if not a.is_empty() and a != base:
			return true
	return false


static func align_of(props: Dictionary, index: int) -> String:
	var list: PackedStringArray = stored(props)
	if index >= 0 and index < list.size() and not list[index].is_empty():
		return list[index]
	return title_align(props)


static func count(text: String) -> int:
	return text.count("\n") + 1


static func index_at(text: String, at: int) -> int:
	var cut: int = clampi(at, 0, text.length())
	return text.substr(0, cut).count("\n")


static func span_of(text: String, from: int, to: int) -> Vector2i:
	var a: int = index_at(text, mini(from, to))
	var b: int = index_at(text, maxi(from, to))
	return Vector2i(a, b)


static func with_align(props: Dictionary, text: String, from: int, to: int, align: String) -> String:
	var list: PackedStringArray = stored(props)
	var n: int = count(text)
	var base: String = title_align(props)
	while list.size() < n:
		list.append("")
	if list.size() > n:
		list.resize(n)
	var sp: Vector2i = span_of(text, from, to)
	for i: int in range(sp.x, sp.y + 1):
		list[i] = "" if align == base else align
	return encode(list)


static func remapped(value: Variant, before: String, after: String) -> Variant:
	var list: PackedStringArray = decode(value)
	if list.is_empty() or before == after:
		return null
	var shortest: int = mini(before.length(), after.length())
	var pre: int = 0
	while pre < shortest and before.unicode_at(pre) == after.unicode_at(pre):
		pre += 1
	var suf: int = 0
	while suf < shortest - pre and before.unicode_at(before.length() - 1 - suf) == after.unicode_at(after.length() - 1 - suf):
		suf += 1
	var gone: int = before.substr(pre, before.length() - pre - suf).count("\n")
	var came: int = after.substr(pre, after.length() - pre - suf).count("\n")
	if gone == 0 and came == 0:
		return null
	var at: int = index_at(before, pre)
	var n_before: int = count(before)
	while list.size() < n_before:
		list.append("")
	var out: PackedStringArray = PackedStringArray()
	for i: int in range(0, at):
		out.append(list[i])
	var whole: bool = gone > 0 and (pre == 0 or before.unicode_at(pre - 1) == 10)
	out.append(list[mini(at + gone, list.size() - 1)] if whole else list[at])
	for k: int in came:
		out.append(list[at])
	for j: int in range(at + 1 + gone, list.size()):
		out.append(list[j])
	var next: String = encode(out)
	return next if next != encode(list) else null


static func line_plan(para: TextParagraph, props: Dictionary, text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ts: TextServer = TextServerManager.get_primary_interface()
	var lines: int = maxi(para.get_line_count(), 1)
	var flags: int = TextServer.JUSTIFICATION_WORD_BOUND | TextServer.JUSTIFICATION_TRIM_EDGE_SPACES
	for i: int in lines:
		var span: Vector2i = para.get_line_range(i)
		var p: int = index_at(text, span.x)
		var next_p: int = index_at(text, para.get_line_range(i + 1).x) if i < lines - 1 else p + 1
		var last: bool = next_p > p
		var a: String = align_of(props, p)
		var rid: RID = para.get_line_rid(i)
		var w: float = para.get_line_width(i)
		if a.begins_with("justify") and para.width > 0.0 and (not last or a == "justify_all"):
			ts.shaped_text_fit_to_width(rid, para.width, flags)
			w = ts.shaped_text_get_width(rid)
		out.append({"align": a, "last": last, "w": w})
	return out


static func block_width(plan: Array[Dictionary], fallback: float) -> float:
	var w: float = 0.0
	for ln: Dictionary in plan:
		w = maxf(w, float(ln["w"]))
	return w if not plan.is_empty() else fallback

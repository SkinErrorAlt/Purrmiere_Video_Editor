extends RefCounted

const WORKS := "ok"
const NOTE := "note"
const ONE_WAY := "one_way"
const IDLE := "idle"
const FAIL := "fail"


static func num(p: Dictionary, key: String, fallback: float) -> float:
	var v: Variant = p.get(key, null)
	if v is float or v is int:
		return float(v)
	if v is bool:
		return 1.0 if bool(v) else 0.0
	if v is String and String(v).is_valid_float():
		return String(v).to_float()
	return fallback


static func whole(p: Dictionary, key: String, fallback: int) -> int:
	return int(roundf(num(p, key, float(fallback))))


static func txt(p: Dictionary, key: String, fallback: String = "") -> String:
	var v: Variant = p.get(key, null)
	if v == null:
		return fallback
	return String(v) if v is String else str(v)


static func flag(p: Dictionary, key: String, fallback: bool) -> bool:
	var v: Variant = p.get(key, null)
	if v == null:
		return fallback
	if v is bool:
		return bool(v)
	return num(p, key, 0.0) > 0.5


static func colour(p: Dictionary, key: String, fallback: Color) -> Array:
	var v: Variant = p.get(key, null)
	if v is Color:
		var c: Color = v
		return [c.r, c.g, c.b, c.a]
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return [float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0]
	return [fallback.r, fallback.g, fallback.b, fallback.a]


static func result(text: String, level: String, say: String) -> Dictionary:
	return {"text": text, "level": level, "say": say}


static func unchanged(text: String, say: String) -> Dictionary:
	return {"text": text, "level": FAIL, "say": say}


static func count(text: String) -> Dictionary:
	var letters: int = 0
	var digits: int = 0
	var spaces: int = 0
	var others: int = 0
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
			letters += 1
		elif c >= 48 and c <= 57:
			digits += 1
		elif c == 32 or c == 10 or c == 9 or c == 13:
			spaces += 1
		else:
			others += 1
	return {"letters": letters, "digits": digits, "spaces": spaces, "others": others}


static func blank(c: int) -> bool:
	return c == 32 or c == 10 or c == 9 or c == 13


## A well mixed hash of a few integers, always zero or above.
static func mix(a: int, b: int = 0, c: int = 0, d: int = 0) -> int:
	var h: int = a * -7046029254386353131 + b * 2654435761 + c * 2246822519 + d * 3266489917
	h = (h ^ (h >> 30)) * -4658895280553007687
	h = (h ^ (h >> 27)) * -7723592293110705685
	h = h ^ (h >> 31)
	return h & 0x7FFFFFFFFFFFFFFF

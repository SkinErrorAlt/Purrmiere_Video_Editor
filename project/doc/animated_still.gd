extends RefCounted

const SNIFF_BYTES := 1048576
const EXTS: PackedStringArray = ["png", "apng", "webp"]
const PLAYS_EXTS: PackedStringArray = ["png", "apng"]

static var _cache: Dictionary = {}
static var plant_never: bool = false


static func is_animated(path: String) -> bool:
	var ext: String = path.get_extension().to_lower()
	if plant_never or not EXTS.has(ext) or path.is_empty():
		return false
	var stamp: int = FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else -1
	var key: String = path + "|" + str(stamp)
	if _cache.has(key):
		return bool(_cache[key])
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var out: bool = false
	if f != null:
		var head: PackedByteArray = f.get_buffer(mini(int(f.get_length()), SNIFF_BYTES))
		f.close()
		out = animated_png(head) or animated_webp(head)
	_cache[key] = out
	return out


static func plays(path: String) -> bool:
	return PLAYS_EXTS.has(path.get_extension().to_lower()) and is_animated(path)


static func _u32be(b: PackedByteArray, at: int) -> int:
	return (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3]


static func _u32le(b: PackedByteArray, at: int) -> int:
	return b[at] | (b[at + 1] << 8) | (b[at + 2] << 16) | (b[at + 3] << 24)


static func animated_png(b: PackedByteArray) -> bool:
	if b.size() < 16 or b[0] != 0x89 or b[1] != 0x50 or b[2] != 0x4E or b[3] != 0x47:
		return false
	var at: int = 8
	while at + 8 <= b.size():
		var length: int = _u32be(b, at)
		var kind: String = b.slice(at + 4, at + 8).get_string_from_ascii()
		if kind == "acTL":
			return true
		if kind == "IDAT" or kind == "IEND":
			return false
		at += 12 + length
	return false


static func animated_webp(b: PackedByteArray) -> bool:
	if b.size() < 21 or b.slice(0, 4).get_string_from_ascii() != "RIFF" or b.slice(8, 12).get_string_from_ascii() != "WEBP":
		return false
	var at: int = 12
	while at + 8 <= b.size():
		var kind: String = b.slice(at, at + 4).get_string_from_ascii()
		var length: int = _u32le(b, at + 4)
		if kind == "VP8X" and at + 8 < b.size():
			return (b[at + 8] & 0x02) != 0
		if kind == "ANIM" or kind == "ANMF":
			return true
		at += 8 + length + (length & 1)
	return false

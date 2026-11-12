extends RefCounted

const AnimProp := preload("res://doc/anim_prop.gd")
const POOLS: PackedStringArray = ["text", "letters", "digits", "symbols", "custom"]
const POOL_LABELS: PackedStringArray = ["The title's own characters", "Letters", "Digits", "Symbols", "The characters below"]
const ORDERS: PackedStringArray = ["left", "random"]
const ORDER_LABELS: PackedStringArray = ["Left to right", "In a random order"]
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
const DIGITS := "0123456789"
const SYMBOLS := "!?@#$%&*+=/\\|<>[]{}()~^"
const RATE_MAX := 60.0
const SEED_MAX := 999999.0
const CLOCK_CODE := "t"
const BLANK_UPTO := 32
const MIX_A := -7046029254386353131
const MIX_B := -4658895280553007687
const MIX_C := -7723592293110705685
const SPREAD_SEED := 2654435761
const SPREAD_POS := 2246822519
const SPREAD_TICK := 3266489917
const SPREAD_LEN := 668265263
const POSITIVE := 0x7FFFFFFFFFFFFFFF


static func defaults() -> Dictionary:
	return {
		"decode_on": false,
		"decode_pool": "text",
		"decode_chars": "",
		"decode_order": "left",
		"decode_rate": 12.0,
		"decode_seed": 0.0,
		"decode_clock": 0.0,
	}


static func plain(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("v"):
			return plain(d["v"])
		if d.has("base"):
			return plain(d["base"])
		return null
	return v


static func get_value(props: Dictionary, key: String) -> Variant:
	var v: Variant = plain(props.get(key, null))
	return defaults()[key] if v == null else v


static func on(props: Dictionary) -> bool:
	return bool(get_value(props, "decode_on"))


static func pool_name(props: Dictionary) -> String:
	var s: String = String(get_value(props, "decode_pool"))
	return s if POOLS.has(s) else "text"


static func order_name(props: Dictionary) -> String:
	var s: String = String(get_value(props, "decode_order"))
	return s if ORDERS.has(s) else "left"


static func rate_of(props: Dictionary) -> float:
	return clampf(float(get_value(props, "decode_rate")), 0.0, RATE_MAX)


static func seed_of(props: Dictionary) -> int:
	return int(clampf(floorf(float(get_value(props, "decode_seed")) + 0.0001), 0.0, SEED_MAX))


static func clock_of(props: Dictionary) -> float:
	return float(get_value(props, "decode_clock"))


static func clock_prop() -> Dictionary:
	return AnimProp.add_layer(AnimProp.make(0.0), AnimProp.new_expr_layer(CLOCK_CODE))


static func clock_follows_time(v: Variant) -> bool:
	if not (v is Dictionary):
		return false
	var d: Dictionary = v
	for l: Variant in d.get("layers", []):
		if not (l is Dictionary):
			continue
		var layer: Dictionary = l
		if String(layer.get("type", "")) == "expr" and String(layer.get("code", "")).strip_edges() == CLOCK_CODE:
			return true
	return false


static func tick(props: Dictionary) -> int:
	var rate: float = rate_of(props)
	if rate <= 0.0:
		return 0
	return int(floor(clock_of(props) * rate))


static func mix(x: int) -> int:
	var h: int = x + MIX_A
	h = (h ^ (h >> 30)) * MIX_B
	h = (h ^ (h >> 27)) * MIX_C
	return h ^ (h >> 31)


static func pick(n: int, h: int) -> int:
	if n <= 1:
		return 0
	return (h & POSITIVE) % n


static func blank(ch: int) -> bool:
	return ch <= BLANK_UPTO


static func distinct_of(text: String) -> String:
	var out: String = ""
	for i: int in text.length():
		var ch: int = text.unicode_at(i)
		if blank(ch):
			continue
		var one: String = String.chr(ch)
		if not out.contains(one):
			out += one
	return out


static func pool_of(props: Dictionary, text: String) -> String:
	var which: String = pool_name(props)
	if which == "letters":
		return LETTERS
	if which == "digits":
		return DIGITS
	if which == "symbols":
		return SYMBOLS
	if which == "custom":
		var typed: String = String(get_value(props, "decode_chars"))
		return typed if not typed.is_empty() else LETTERS
	var own: String = distinct_of(text)
	return own if not own.is_empty() else LETTERS


static func ranks(props: Dictionary, length: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if length <= 0:
		return out
	out.resize(length)
	for i: int in length:
		out[i] = i
	if order_name(props) != "random":
		return out
	var order: PackedInt32Array = out.duplicate()
	var sd: int = seed_of(props)
	for i2: int in range(length - 1, 0, -1):
		var j: int = pick(i2 + 1, mix(sd * SPREAD_SEED + length * SPREAD_LEN + i2 * SPREAD_POS))
		var keep: int = order[i2]
		order[i2] = order[j]
		order[j] = keep
	for k: int in length:
		out[order[k]] = k
	return out


static func stand_in(pool: String, pos: int, tk: int, sd: int, real: int) -> int:
	var n: int = pool.length()
	if n <= 0:
		return -1
	var at: int = pick(n, mix(mix(sd * SPREAD_SEED + pos * SPREAD_POS) + tk * SPREAD_TICK))
	var ch: int = pool.unicode_at(at)
	if ch == real and n > 1:
		ch = pool.unicode_at((at + 1) % n)
	return ch


static func subs(props: Dictionary, text: String, shown: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var n: int = text.length()
	if n <= 0 or not on(props) or shown >= n:
		return out
	out.resize(n)
	for i: int in n:
		out[i] = -1
	var pool: String = pool_of(props, text)
	var rank: PackedInt32Array = ranks(props, n)
	var tk: int = tick(props)
	var sd: int = seed_of(props)
	for i2: int in n:
		var ch: int = text.unicode_at(i2)
		if blank(ch) or rank[i2] < shown:
			continue
		var pz: int = stand_in(pool, i2, tk, sd, ch)
		if pz > 0:
			out[i2] = pz
	return out


static func scrambled(props: Dictionary, text: String, shown: int) -> String:
	var map: PackedInt32Array = subs(props, text, shown)
	if map.is_empty():
		return text
	var out: String = ""
	for i: int in text.length():
		out += String.chr(map[i]) if map[i] > 0 else text[i]
	return out


static func unsettled(props: Dictionary, text: String, shown: int) -> int:
	var map: PackedInt32Array = subs(props, text, shown)
	var n: int = 0
	for v: int in map:
		if v > 0:
			n += 1
	return n

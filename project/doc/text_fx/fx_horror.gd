extends RefCounted

const P := preload("res://doc/text_fx/fx_params.gd")
const TextDecode := preload("res://doc/text_decode.gd")
const BLOCKS := "█▓▒░"
const GLITCH_SYMBOLS := "!@#$%^&*<>?/\\|{}[]~=+_"
const GLITCH_BLOCKS := "█▓▒░▌▐▀▄■□▪▫"
const ALNUM := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
const MIRROR_FROM := "ENRSZJKLPQabdekpqrsyz"
const MIRROR_TO := "ƎИЯƧƸႱꓘ⅃ꟼϘɒdbɘʞqpɿƨγƹ"
const ZALGO_UP: PackedInt32Array = [0x300, 0x301, 0x302, 0x303, 0x304, 0x305, 0x306, 0x307, 0x308, 0x309, 0x30A, 0x30B, 0x30C, 0x30D, 0x30E, 0x30F, 0x310, 0x311, 0x312, 0x313, 0x314, 0x315, 0x31A, 0x33D, 0x33E, 0x33F, 0x340, 0x341, 0x342, 0x343, 0x344, 0x346, 0x34A, 0x34B, 0x34C, 0x350, 0x351, 0x352, 0x357, 0x35B, 0x363, 0x364, 0x365, 0x366, 0x367, 0x368, 0x369, 0x36A, 0x36B, 0x36C, 0x36D, 0x36E, 0x36F]
const ZALGO_MID: PackedInt32Array = [0x334, 0x335, 0x336, 0x337, 0x338]
const ZALGO_DOWN: PackedInt32Array = [0x316, 0x317, 0x318, 0x319, 0x31C, 0x31D, 0x31E, 0x31F, 0x320, 0x321, 0x322, 0x323, 0x324, 0x325, 0x326, 0x327, 0x328, 0x329, 0x32A, 0x32B, 0x32C, 0x32D, 0x32E, 0x32F, 0x330, 0x331, 0x332, 0x333, 0x339, 0x33A, 0x33B, 0x33C, 0x347, 0x348, 0x349, 0x34D, 0x34E, 0x353, 0x354, 0x355, 0x356, 0x359, 0x35A]
const MONTHS: PackedStringArray = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
const VHS_MODES: PackedStringArray = ["● REC", "PLAY ►", "PAUSE ‖", "STOP ■", "FF ►►", "REW ◄◄"]
const TAPE_SPEEDS: PackedStringArray = ["SP", "LP", "EP"]

static var _patterns: Dictionary = {}


static func _styled(out: String, level: String, say: String, styles: Array) -> Dictionary:
	var r: Dictionary = P.result(out, level, say)
	r["styles"] = styles
	return r


static func _no_styles(n: int) -> Array:
	var a: Array = []
	a.resize(n)
	for i: int in n:
		a[i] = {}
	return a


static func _alnum(c: int) -> bool:
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c > 191


static func _t(ctx: Dictionary) -> float:
	return float(ctx.get("t", 0.0))


static func _fps(ctx: Dictionary) -> float:
	return maxf(float(ctx.get("fps", 30.0)), 1.0)


static func reveal_ranks(n: int, order: int, seed: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(n)
	if order == 1:
		for i: int in n:
			out[i] = n - 1 - i
		return out
	if order == 2:
		var mid: float = float(n - 1) * 0.5
		var idx: Array = []
		for i2: int in n:
			idx.append(i2)
		idx.sort_custom(func(a: int, b: int) -> bool: return absf(float(a) - mid) < absf(float(b) - mid) or (absf(float(a) - mid) == absf(float(b) - mid) and a < b))
		for k: int in n:
			out[int(idx[k])] = k
		return out
	if order == 3:
		var order_list: PackedInt32Array = PackedInt32Array()
		order_list.resize(n)
		for i3: int in n:
			order_list[i3] = i3
		for i4: int in range(n - 1, 0, -1):
			var j: int = TextDecode.pick(i4 + 1, TextDecode.mix(seed * TextDecode.SPREAD_SEED + n * TextDecode.SPREAD_LEN + i4 * TextDecode.SPREAD_POS))
			var keep: int = order_list[i4]
			order_list[i4] = order_list[j]
			order_list[j] = keep
		for k2: int in n:
			out[order_list[k2]] = k2
		return out
	for i5: int in n:
		out[i5] = i5
	return out


static func scramble_pool(p: Dictionary, text: String) -> String:
	var which: int = P.whole(p, "pool", 0)
	if which == 1:
		return TextDecode.DIGITS
	if which == 2:
		return TextDecode.SYMBOLS
	if which == 3:
		return BLOCKS
	if which == 4:
		var own: String = TextDecode.distinct_of(text)
		return own if own.length() > 1 else TextDecode.LETTERS
	if which == 5:
		var typed: String = P.txt(p, "chars", "")
		return typed if not typed.is_empty() else TextDecode.LETTERS
	return TextDecode.LETTERS


static func decode_reveal(text: String, p: Dictionary, ctx: Dictionary) -> Dictionary:
	var spots: PackedInt32Array = PackedInt32Array()
	for i: int in text.length():
		if not TextDecode.blank(text.unicode_at(i)):
			spots.append(i)
	var n: int = spots.size()
	if n == 0:
		return P.result(text, P.IDLE, "There are no letters to reveal")
	var start: float = P.num(p, "start", 0.0)
	var speed: float = maxf(P.num(p, "speed", 12.0), 0.0)
	var rate: float = maxf(P.num(p, "rate", 20.0), 0.0)
	var seed: int = P.whole(p, "seed", 0)
	var scramble_out: bool = P.whole(p, "direction", 0) == 1
	var t: float = _t(ctx)
	var done_count: int = n if speed <= 0.0 else clampi(int(floor((t - start) * speed + 0.0001)), 0, n)
	var ranks: PackedInt32Array = reveal_ranks(n, P.whole(p, "order", 0), seed)
	var pool: String = scramble_pool(p, text)
	var match_case: bool = P.whole(p, "pool", 0) == 0
	var tick: int = int(floor(t * rate)) if rate > 0.0 else 0
	var out: String = ""
	var at: int = 0
	var scrambled: int = 0
	for i2: int in text.length():
		var c: int = text.unicode_at(i2)
		if TextDecode.blank(c):
			out += String.chr(c)
			continue
		var r: int = ranks[at]
		at += 1
		var hide: bool = (r < done_count) if scramble_out else (r >= done_count)
		if hide:
			var stand: int = TextDecode.stand_in(pool, i2, tick, seed, c)
			var shown: String = String.chr(stand if stand > 0 else c)
			if match_case:
				shown = shown.to_upper() if (c >= 65 and c <= 90) else (shown.to_lower() if (c >= 97 and c <= 122) else shown)
			out += shown
			scrambled += 1
		else:
			out += String.chr(c)
	var finish: float = start + float(n) / speed if speed > 0.0 else start
	var say: String = ""
	if scramble_out:
		say = "Scrambling %d of %d letters; all scrambled at %.2f s" % [scrambled, n, finish]
	elif scrambled == 0:
		say = "Fully revealed (from %.2f s)" % finish
	else:
		say = "Revealed %d of %d letters; all revealed at %.2f s" % [n - scrambled, n, finish]
	return P.result(out, P.WORKS, say)


static func flash_visible(p: Dictionary, ctx: Dictionary) -> bool:
	var fps: float = _fps(ctx)
	var frame: int = int(floor(_t(ctx) * fps + 0.0001))
	var f0: int = int(roundf(P.num(p, "at", 1.0) * fps))
	var frames: int = maxi(P.whole(p, "frames", 1), 1)
	var rep: int = P.whole(p, "repeat", 0)
	var d: int = frame - f0
	if d < 0:
		return false
	if rep == 0:
		return d < frames
	var period: int = maxi(int(roundf(P.num(p, "every", 2.0) * fps)), frames + 1)
	if rep == 1:
		return d % period < frames
	var k: int = d / period
	var off: int = P.mix(P.whole(p, "seed", 0), k, 77) % (period - frames + 1)
	var r: int = d % period - off
	return r >= 0 and r < frames


static func subliminal(text: String, p: Dictionary, ctx: Dictionary) -> Dictionary:
	var mode: int = P.whole(p, "mode", 0)
	var message: String = P.txt(p, "message", "")
	var on: bool = flash_visible(p, ctx)
	var frames: int = maxi(P.whole(p, "frames", 1), 1)
	var when: String = "%d frame%s at %.2f s" % [frames, "" if frames == 1 else "s", P.num(p, "at", 1.0)]
	var rep: int = P.whole(p, "repeat", 0)
	if rep == 1:
		when += ", then every %.2f s" % P.num(p, "every", 2.0)
	elif rep == 2:
		when += ", then once at a random moment in every %.2f s" % P.num(p, "every", 2.0)
	if mode == 1:
		if message.is_empty():
			return P.unchanged(text, "Subliminal flash needs the hidden message typed in, so the text passes through unchanged")
		return P.result(message if on else text, P.WORKS, ("Flashing the message now. " if on else "") + "The message replaces the text for " + when)
	return P.result(text if on else "", P.WORKS, ("Showing now. " if on else "Hidden now. ") + "The text shows for " + when)


static func _regex(pattern: String) -> RegEx:
	if _patterns.has(pattern):
		return _patterns[pattern]
	var re: RegEx = RegEx.new()
	var ok: bool = re.compile(pattern) == OK and re.is_valid()
	if _patterns.size() > 64:
		_patterns.clear()
	_patterns[pattern] = re if ok else null
	return re if ok else null


static func redact_ranges(text: String, p: Dictionary) -> Dictionary:
	var spec: String = P.txt(p, "words", "")
	var how: int = P.whole(p, "match", 0)
	var exact_case: bool = P.flag(p, "case", false)
	var ranges: Array = []
	if spec.strip_edges().is_empty():
		return {"ok": false, "why": "Redaction needs the words to hide typed in (split them with commas)", "ranges": ranges}
	if how == 2:
		var re: RegEx = _regex(spec if exact_case else "(?i)" + spec)
		if re == null:
			return {"ok": false, "why": "That pattern isn't a valid regular expression", "ranges": ranges}
		for m: RegExMatch in re.search_all(text):
			if m.get_end() > m.get_start():
				ranges.append([m.get_start(), m.get_end()])
		return {"ok": true, "why": "", "ranges": ranges}
	var hay: String = text if exact_case else text.to_lower()
	for raw: String in spec.split(","):
		var word: String = raw.strip_edges()
		if word.is_empty():
			continue
		var needle: String = word if exact_case else word.to_lower()
		var from: int = 0
		while true:
			var at: int = hay.find(needle, from)
			if at < 0:
				break
			var end: int = at + needle.length()
			var whole_word: bool = (at == 0 or not _alnum(hay.unicode_at(at - 1))) and (end >= hay.length() or not _alnum(hay.unicode_at(end)))
			if how == 1 or whole_word:
				ranges.append([at, end])
			from = at + maxi(needle.length(), 1)
	ranges.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var merged: Array = []
	for r: Array in ranges:
		if not merged.is_empty() and int(r[0]) <= int((merged[merged.size() - 1] as Array)[1]):
			(merged[merged.size() - 1] as Array)[1] = maxi(int((merged[merged.size() - 1] as Array)[1]), int(r[1]))
		else:
			merged.append([int(r[0]), int(r[1])])
	return {"ok": true, "why": "", "ranges": merged}


static func redact(text: String, p: Dictionary, _ctx: Dictionary) -> Dictionary:
	var found: Dictionary = redact_ranges(text, p)
	if not bool(found["ok"]):
		return P.unchanged(text, String(found["why"]) + ", so nothing is hidden")
	var ranges: Array = found["ranges"]
	if ranges.is_empty():
		return P.result(text, P.IDLE, "None of those words are in the text, so nothing is hidden")
	var look: int = P.whole(p, "look", 0)
	var col: Array = P.colour(p, "colour", Color.BLACK)
	var count_say: String = "Hides %d match%s" % [ranges.size(), "" if ranges.size() == 1 else "es"]
	if look == 0:
		var styles: Array = _no_styles(text.length())
		for r: Array in ranges:
			for i: int in range(int(r[0]), int(r[1])):
				styles[i] = {"highlight": col, "colour": col, "outline_colour": col}
		return _styled(text, P.WORKS, count_say + " under bars", styles)
	var out: String = ""
	var map: PackedInt32Array = PackedInt32Array()
	var pos: int = 0
	for r2: Array in ranges:
		var a: int = int(r2[0])
		var b: int = int(r2[1])
		for i2: int in range(pos, a):
			out += text[i2]
			map.append(i2)
		if look == 1:
			for i3: int in range(a, b):
				var blank_char: bool = TextDecode.blank(text.unicode_at(i3))
				out += text[i3] if blank_char else "█"
				map.append(i3)
		else:
			for ch: String in "[REDACTED]":
				out += ch
				map.append(a)
		pos = b
	for i4: int in range(pos, text.length()):
		out += text[i4]
		map.append(i4)
	var r3: Dictionary = P.result(out, P.WORKS, count_say + (" with blocks" if look == 1 else " as [REDACTED]"))
	r3["map"] = map
	return r3


static func glitch(text: String, p: Dictionary, ctx: Dictionary) -> Dictionary:
	var amount: float = clampf(P.num(p, "amount", 25.0) / 100.0, 0.0, 1.0)
	var rate: float = maxf(P.num(p, "rate", 12.0), 0.0)
	var bursts: float = clampf(P.num(p, "bursts", 100.0), 0.0, 100.0)
	var seed: int = P.whole(p, "seed", 0)
	var which: int = P.whole(p, "pool", 0)
	var tint: bool = P.flag(p, "tint", false)
	var col: Array = P.colour(p, "colour", Color(1.0, 0.1, 0.25, 1.0))
	var t: float = _t(ctx)
	var tick: int = int(floor(t * rate)) if rate > 0.0 else 0
	var live: bool = float(P.mix(seed, tick, 7) % 10000) < bursts * 100.0
	var pool: String = GLITCH_SYMBOLS
	if which == 1:
		pool = GLITCH_BLOCKS
	elif which == 2:
		pool = ALNUM
	var out: String = ""
	var styles: Array = []
	var hit: int = 0
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		var ch: String = String.chr(c)
		var broken: bool = live and not TextDecode.blank(c) and float(P.mix(seed, i, tick, 3) % 10000) < amount * 10000.0
		if broken:
			if which == 3:
				var at: int = MIRROR_FROM.find(ch)
				if at < 0:
					at = MIRROR_FROM.find(ch.to_upper())
				ch = MIRROR_TO[at] if at >= 0 else ch
			else:
				ch = pool[P.mix(seed, i, tick, 11) % pool.length()]
			hit += 1
		out += ch
		styles.append({"colour": col} if broken and tint else {})
	var say: String = "Glitching about %d%% of the letters, %d now; it changes %d times a second" % [int(roundf(amount * 100.0)), hit, int(rate)]
	if bursts < 100.0:
		say += ", in bursts %d%% of the time" % int(bursts)
	return _styled(out, P.WORKS, say, styles)


static func zalgo(text: String, p: Dictionary, ctx: Dictionary) -> Dictionary:
	var amount: int = clampi(P.whole(p, "amount", 4), 0, 40)
	var where: int = P.whole(p, "where", 1)
	var rate: float = maxf(P.num(p, "rate", 0.0), 0.0)
	var seed: int = P.whole(p, "seed", 0)
	var tick: int = int(floor(_t(ctx) * rate)) if rate > 0.0 else 0
	if amount == 0:
		return P.result(text, P.IDLE, "Zalgo with 0 marks changes nothing")
	var out: String = ""
	var map: PackedInt32Array = PackedInt32Array()
	var marked: int = 0
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		out += String.chr(c)
		map.append(i)
		if TextDecode.blank(c):
			continue
		marked += 1
		var n: int = amount / 2 + P.mix(seed, i, tick, 1) % (amount - amount / 2 + 1)
		for k: int in n:
			var h: int = P.mix(seed, i, tick, 100 + k)
			var set_pick: int = 0 if where == 0 else (h % 2 if where == 1 else h % 3)
			var marks: PackedInt32Array = ZALGO_UP if set_pick == 0 else (ZALGO_DOWN if set_pick == 1 else ZALGO_MID)
			out += String.chr(marks[(h / 3) % marks.size()])
			map.append(i)
	if marked == 0:
		return P.result(text, P.IDLE, "There are no letters to put marks on")
	var r: Dictionary = P.result(out, P.WORKS, "Zalgo stacks marks on every letter; they stay on their letter, so styling and the letter rig follow")
	r["map"] = map
	return r


static func parse_date(s: String) -> Dictionary:
	var parts: PackedStringArray = s.strip_edges().replace("/", "-").replace(".", "-").split("-", false)
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return {}
	var y: int = parts[0].to_int()
	var m: int = parts[1].to_int()
	var d: int = parts[2].to_int()
	if y < 1900 or y > 2200 or m < 1 or m > 12 or d < 1 or d > 31:
		return {}
	return {"year": y, "month": m, "day": d}


static func parse_time(s: String) -> int:
	var parts: PackedStringArray = s.strip_edges().split(":", false)
	if parts.size() < 2 or parts.size() > 3:
		return -1
	var nums: PackedInt32Array = PackedInt32Array()
	for x: String in parts:
		if not x.is_valid_int():
			return -1
		nums.append(x.to_int())
	var sec: int = nums[2] if nums.size() == 3 else 0
	if nums[0] < 0 or nums[0] > 23 or nums[1] < 0 or nums[1] > 59 or sec < 0 or sec > 59:
		return -1
	return nums[0] * 3600 + nums[1] * 60 + sec


static func tape_counter(seconds: float) -> String:
	var s: int = maxi(int(floor(seconds)), 0)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


static func vhs_osd(text: String, p: Dictionary, ctx: Dictionary) -> Dictionary:
	var t: float = _t(ctx)
	var lines: PackedStringArray = PackedStringArray()
	var notes: PackedStringArray = PackedStringArray()
	var dot_line: int = -1
	var dot_on: bool = true
	if P.flag(p, "show_mode", true):
		var mode: int = clampi(P.whole(p, "mode", 0), 0, VHS_MODES.size() - 1)
		lines.append(VHS_MODES[mode])
		if mode == 0:
			dot_line = 0
			dot_on = not P.flag(p, "blink", true) or fposmod(t, 1.0) < 0.5
	if P.flag(p, "show_channel", false):
		lines.append("CH %02d" % clampi(P.whole(p, "channel", 3), 0, 999))
	if P.flag(p, "show_counter", true):
		var speed_word: String = (TAPE_SPEEDS[clampi(P.whole(p, "tape_speed", 0), 0, 2)] + " ") if P.flag(p, "show_speed", true) else ""
		lines.append(speed_word + tape_counter(P.num(p, "counter_start", 0.0) + t))
	var show_date: bool = P.flag(p, "show_date", true)
	var show_time: bool = P.flag(p, "show_time", true)
	if show_date or show_time:
		var date: Dictionary = parse_date(P.txt(p, "date", "1997-10-31"))
		var secs: int = parse_time(P.txt(p, "time", "23:57:00"))
		if date.is_empty():
			notes.append("the date should look like 1997-10-31")
			date = {"year": 1997, "month": 10, "day": 31}
		if secs < 0:
			notes.append("the time should look like 23:57:00")
			secs = 0
		var base: int = Time.get_unix_time_from_datetime_dict({"year": date["year"], "month": date["month"], "day": date["day"], "hour": 0, "minute": 0, "second": 0})
		var now: int = base + secs + int(floor(t * P.num(p, "clock_rate", 1.0)))
		var dt: Dictionary = Time.get_datetime_dict_from_unix_time(now)
		var y: int = int(dt["year"])
		var mo: int = int(dt["month"])
		var da: int = int(dt["day"])
		if show_date:
			match P.whole(p, "date_format", 0):
				1:
					lines.append("%02d.%02d.%04d" % [da, mo, y])
				2:
					lines.append("%02d/%02d/%02d" % [mo, da, y % 100])
				3:
					lines.append("%04d-%02d-%02d" % [y, mo, da])
				_:
					lines.append("%s %02d %04d" % [MONTHS[mo - 1], da, y])
		if show_time:
			var h: int = int(dt["hour"])
			var mi: int = int(dt["minute"])
			var se: int = int(dt["second"])
			if P.whole(p, "clock", 0) == 1:
				lines.append("%02d:%02d:%02d" % [h, mi, se])
			else:
				lines.append("%s %d:%02d:%02d" % ["AM" if h < 12 else "PM", 12 if h % 12 == 0 else h % 12, mi, se])
	var joiner: String = "   " if P.whole(p, "layout", 0) == 1 else "\n"
	var osd: String = joiner.join(lines)
	var keep: int = P.whole(p, "keep_text", 0)
	var out: String = osd
	var osd_at: int = 0
	if keep == 1 and not text.is_empty():
		out = text + "\n" + osd
		osd_at = text.length() + 1
	elif keep == 2 and not text.is_empty():
		out = osd + "\n" + text
	var styles: Array = _no_styles(out.length())
	if dot_line == 0:
		var dot_col: Array = P.colour(p, "dot_colour", Color(1.0, 0.1, 0.1, 1.0))
		styles[osd_at] = {"colour": dot_col, "text_opacity": 100.0 if dot_on else 0.0}
	if lines.is_empty():
		return _styled(out, P.IDLE, "Every part of the display is turned off", styles)
	var say: String = "A VHS display; the counter, date and time run with the clip"
	if not notes.is_empty():
		return _styled(out, P.NOTE, say + ", but " + " and ".join(notes), styles)
	return _styled(out, P.WORKS, say, styles)


static func _starts(text: String, by_line: bool) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var looking: bool = true
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		var gap: bool = c == 10 if by_line else TextDecode.blank(c)
		if gap:
			looking = true
			continue
		if looking and _alnum(c):
			out.append(i)
			looking = false
	return out


static func first_letters(text: String, p: Dictionary, _ctx: Dictionary) -> Dictionary:
	var mode: int = P.whole(p, "mode", 0)
	var by_line: bool = mode == 1 or mode == 3
	var picks: PackedInt32Array = _starts(text, by_line)
	if picks.is_empty():
		return P.result(text, P.IDLE, "There are no words here to take first letters from")
	var spelled: String = ""
	for i: int in picks:
		spelled += text[i]
	var unit: String = "line" if by_line else "word"
	if mode >= 2:
		var map: PackedInt32Array = PackedInt32Array()
		for i2: int in picks:
			map.append(i2)
		var r: Dictionary = P.result(spelled, P.WORKS, "Keeps the first letter of each " + unit + ": it spells " + spelled)
		r["map"] = map
		return r
	var col: Array = P.colour(p, "colour", Color(0.85, 0.05, 0.05, 1.0))
	var styles: Array = _no_styles(text.length())
	for i3: int in picks:
		styles[i3] = {"colour": col, "bold": P.flag(p, "bold", true)}
	return _styled(text, P.WORKS, "Marks the first letter of each " + unit + ": they spell " + spelled, styles)


static func every_nth(text: String, p: Dictionary, _ctx: Dictionary) -> Dictionary:
	var n: int = maxi(P.whole(p, "n", 3), 1)
	var first: int = maxi(P.whole(p, "first", 1), 1)
	var letters_only: bool = P.flag(p, "letters_only", true)
	var picks: PackedInt32Array = PackedInt32Array()
	var k: int = 0
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		if letters_only and not _alnum(c):
			continue
		k += 1
		if k >= first and (k - first) % n == 0:
			picks.append(i)
	if picks.is_empty():
		return P.result(text, P.IDLE, "There aren't enough characters to pick every %d" % n)
	var spelled: String = ""
	for i2: int in picks:
		spelled += text[i2]
	if P.whole(p, "mode", 0) == 0:
		var r: Dictionary = P.result(spelled, P.WORKS, "Keeps every %d%s character from number %d: it reads %s" % [n, _ordinal(n), first, spelled])
		r["map"] = picks
		return r
	var col: Array = P.colour(p, "colour", Color(0.85, 0.05, 0.05, 1.0))
	var styles: Array = _no_styles(text.length())
	for i3: int in picks:
		styles[i3] = {"colour": col}
	return _styled(text, P.WORKS, "Marks every %d%s character from number %d: they read %s" % [n, _ordinal(n), first, spelled], styles)


static func _ordinal(n: int) -> String:
	if n % 100 >= 11 and n % 100 <= 13:
		return "th"
	match n % 10:
		1:
			return "st"
		2:
			return "nd"
		3:
			return "rd"
	return "th"


static func units_of(text: String, unit: int) -> Dictionary:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(text.length())
	var idx: int = -1
	var in_word: bool = false
	var line: int = 0
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		if unit == 2:
			if c == 10:
				line += 1
			out[i] = line
			continue
		if TextDecode.blank(c):
			in_word = false
			out[i] = idx + 1
			continue
		if unit == 0 or not in_word:
			idx += 1
			in_word = true
		out[i] = idx
	var total: int = line + 1 if unit == 2 else idx + 1
	return {"units": out, "total": total}


static func timed_reveal(text: String, p: Dictionary, ctx: Dictionary) -> Dictionary:
	var unit: int = clampi(P.whole(p, "unit", 1), 0, 2)
	var made: Dictionary = units_of(text, unit)
	var units: PackedInt32Array = made["units"]
	var total: int = int(made["total"])
	if text.is_empty() or total == 0:
		return P.result(text, P.IDLE, "There's nothing to reveal")
	var start: float = P.num(p, "start", 0.5)
	var step: float = maxf(P.num(p, "interval", 0.4), 0.001)
	var t: float = _t(ctx)
	var shown: int = 0 if t < start else clampi(int(floor((t - start) / step + 0.0001)) + 1, 0, total)
	var vanish: bool = P.whole(p, "mode", 0) == 1
	var remove: bool = P.whole(p, "hidden", 0) == 1
	var unit_name: String = ["letters", "words", "lines"][unit]
	var visible_count: int = total - shown if vanish else shown
	var say: String = "%d of %d %s showing; the last one %s at %.2f s" % [visible_count, total, unit_name, "goes" if vanish else "comes", start + step * float(total - 1)]
	if remove:
		var out: String = ""
		var map: PackedInt32Array = PackedInt32Array()
		for i: int in text.length():
			var keep: bool = (units[i] >= shown) if vanish else (units[i] < shown)
			if keep:
				out += text[i]
				map.append(i)
		var r: Dictionary = P.result(out, P.WORKS, say)
		r["map"] = map
		return r
	var styles: Array = _no_styles(text.length())
	for i2: int in text.length():
		var keep2: bool = (units[i2] >= shown) if vanish else (units[i2] < shown)
		if not keep2:
			styles[i2] = {"text_opacity": 0.0}
	return _styled(text, P.WORKS, say + "; hidden ones keep their place", styles)

extends RefCounted

const P := preload("res://doc/text_fx/fx_params.gd")
const AFFINE_KEYS: PackedInt32Array = [1, 3, 5, 7, 9, 11, 15, 17, 19, 21, 23, 25]
const LEET_BASIC: Dictionary = {"a": "4", "e": "3", "i": "1", "o": "0", "s": "5", "t": "7"}
const LEET_STRONG: Dictionary = {"a": "4", "b": "8", "c": "(", "e": "3", "g": "9", "h": "#", "i": "!", "l": "1", "o": "0", "s": "5", "t": "7", "z": "2"}
const KEY_ROWS: PackedStringArray = ["`1234567890-=", "qwertyuiop[]\\", "asdfghjkl;'", "zxcvbnm,./", "~!@#$%^&*()_+", "QWERTYUIOP{}|", "ASDFGHJKL:\"", "ZXCVBNM<>?"]
const FLIP_FROM := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?'\"()[]{}<>&_;"
const FLIP_TO := "ɐqɔpǝɟƃɥᴉɾʞlɯuodbɹsʇnʌʍxʎz∀ꓭƆꓷƎℲ⅁HIſꓘ˥WNOԀῸꓤS⊥∩ΛMX⅄Z0ƖᄅƐㄣϛ9ㄥ86˙'¡¿,„)(][}{><⅋‾؛"


static func _mono(text: String, table: PackedInt32Array) -> String:
	var out: String = ""
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		if c >= 65 and c <= 90:
			out += String.chr(65 + table[c - 65])
		elif c >= 97 and c <= 122:
			out += String.chr(97 + table[c - 97])
		else:
			out += String.chr(c)
	return out


static func letters_verdict(name: String, text: String) -> Array:
	var k: Dictionary = P.count(text)
	if int(k["letters"]) == 0:
		return [P.IDLE, name + " changes letters only, and there are none here, so nothing changes"]
	if int(k["digits"]) + int(k["others"]) > 0:
		return [P.NOTE, name + " changes letters only; digits and symbols pass through"]
	return [P.WORKS, name + " works on every character here"]


static func _letters_result(name: String, text: String, out: String, extra: String = "") -> Dictionary:
	var v: Array = letters_verdict(name, text)
	return P.result(out, String(v[0]), String(v[1]) + ("." + extra if not extra.is_empty() else ""))


static func shift_table(shift: int) -> PackedInt32Array:
	var t: PackedInt32Array = PackedInt32Array()
	for i: int in 26:
		t.append(posmod(i + shift, 26))
	return t


static func caesar(text: String, p: Dictionary) -> Dictionary:
	var shift: int = P.whole(p, "shift", 3)
	var decode: bool = P.whole(p, "direction", 0) == 1
	var s: int = -shift if decode else shift
	var back: String = " Decode with the same shift to get it back." if not decode else ""
	return _letters_result("Caesar shift", text, _mono(text, shift_table(s)), back)


static func rot13(text: String, _p: Dictionary) -> Dictionary:
	return _letters_result("ROT13", text, _mono(text, shift_table(13)), " Running ROT13 again turns it back.")


static func atbash(text: String, _p: Dictionary) -> Dictionary:
	var t: PackedInt32Array = PackedInt32Array()
	for i: int in 26:
		t.append(25 - i)
	return _letters_result("Atbash", text, _mono(text, t), " Running Atbash again turns it back.")


static func rot47(text: String, _p: Dictionary) -> Dictionary:
	var out: String = ""
	var touched: int = 0
	var passed: int = 0
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		if c >= 33 and c <= 126:
			out += String.chr(33 + ((c - 33 + 47) % 94))
			touched += 1
		else:
			out += String.chr(c)
			if not P.blank(c):
				passed += 1
	if touched == 0:
		return P.result(out, P.IDLE, "ROT47 changes the printable ASCII characters only, and there are none here")
	if passed > 0:
		return P.result(out, P.NOTE, "ROT47 changes printable ASCII only; accented letters, emoji and other characters pass through")
	return P.result(out, P.WORKS, "ROT47 works on every character here. Running ROT47 again turns it back.")


static func key_letters(key: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in key.length():
		var c: int = key.unicode_at(i)
		if c >= 65 and c <= 90:
			out.append(c - 65)
		elif c >= 97 and c <= 122:
			out.append(c - 97)
	return out


static func vigenere(text: String, p: Dictionary) -> Dictionary:
	var key: PackedInt32Array = key_letters(P.txt(p, "key", ""))
	if key.is_empty():
		return P.unchanged(text, "Vigenère needs a key made of letters, so the text passes through unchanged")
	var decode: bool = P.whole(p, "direction", 0) == 1
	var out: String = ""
	var at: int = 0
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		var base: int = 65 if (c >= 65 and c <= 90) else (97 if (c >= 97 and c <= 122) else -1)
		if base < 0:
			out += String.chr(c)
			continue
		var k: int = key[at % key.size()]
		at += 1
		out += String.chr(base + posmod(c - base + (-k if decode else k), 26))
	return _letters_result("Vigenère", text, out, " The key only moves on letters." if not decode else "")


static func affine(text: String, p: Dictionary) -> Dictionary:
	var a: int = posmod(P.whole(p, "a", 5), 26)
	var b: int = posmod(P.whole(p, "b", 8), 26)
	if not AFFINE_KEYS.has(a):
		return P.unchanged(text, "Affine needs a that shares no factor with 26 (1, 3, 5, 7, 9, 11, 15, 17, 19, 21, 23 or 25); %d can't be undone, so the text passes through unchanged" % a)
	var decode: bool = P.whole(p, "direction", 0) == 1
	var inv: int = 1
	for x: int in 26:
		if (a * x) % 26 == 1:
			inv = x
	var t: PackedInt32Array = PackedInt32Array()
	for i: int in 26:
		t.append(posmod(inv * (i - b), 26) if decode else (a * i + b) % 26)
	return _letters_result("Affine", text, _mono(text, t))


static func rail_pattern(n: int, rails: int, offset: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var cycle: int = 2 * (rails - 1)
	for i: int in n:
		var k: int = (i + offset) % cycle
		out.append(k if k < rails else cycle - k)
	return out


static func rail_order(n: int, rails: int, offset: int) -> PackedInt32Array:
	var pattern: PackedInt32Array = rail_pattern(n, rails, offset)
	var order: PackedInt32Array = PackedInt32Array()
	for r: int in rails:
		for i: int in n:
			if pattern[i] == r:
				order.append(i)
	return order


static func rail_fence(text: String, p: Dictionary) -> Dictionary:
	var rails: int = clampi(P.whole(p, "rails", 3), 2, 64)
	var offset: int = maxi(P.whole(p, "offset", 0), 0)
	var decode: bool = P.whole(p, "direction", 0) == 1
	var n: int = text.length()
	if n <= 2 or rails >= n:
		return P.result(text, P.IDLE, "With %d rails and only %d characters the order can't change" % [rails, n])
	var order: PackedInt32Array = rail_order(n, rails, offset)
	var out: PackedStringArray = PackedStringArray()
	out.resize(n)
	var map: PackedInt32Array = PackedInt32Array()
	map.resize(n)
	for j: int in n:
		if decode:
			out[order[j]] = text[j]
			map[order[j]] = j
		else:
			out[j] = text[order[j]]
			map[j] = order[j]
	var say: String = "Rail fence moves every character, spaces too, along %d rails" % rails
	var r: Dictionary = P.result("".join(out), P.WORKS, say + (". Decode with the same rails to get it back." if not decode else ""))
	r["map"] = map
	return r


static func bacon_code(index: int) -> String:
	var s: String = ""
	for b: int in range(4, -1, -1):
		s += "B" if ((index >> b) & 1) == 1 else "A"
	return s


static func bacon_index(c: int, classic: bool) -> int:
	var i: int = c - 65
	if not classic:
		return i
	if i >= 21:
		return i - 2
	if i >= 9:
		return i - 1
	return i


static func bacon(text: String, p: Dictionary) -> Dictionary:
	var classic: bool = P.whole(p, "alphabet", 0) == 1
	var decode: bool = P.whole(p, "direction", 0) == 1
	if decode:
		return _bacon_decode(text, classic)
	var words: PackedStringArray = PackedStringArray()
	var dropped: int = 0
	for w: String in text.to_upper().split(" ", false):
		var groups: PackedStringArray = PackedStringArray()
		for i: int in w.length():
			var c: int = w.unicode_at(i)
			if c >= 65 and c <= 90:
				groups.append(bacon_code(bacon_index(c, classic)))
			elif not P.blank(c):
				dropped += 1
		if not groups.is_empty():
			words.append(" ".join(groups))
	if words.is_empty():
		return P.unchanged(text, "Bacon codes letters only, and there are none here, so the text passes through unchanged")
	var out: String = " / ".join(words)
	if dropped > 0:
		return P.result(out, P.NOTE, "Bacon codes letters only; digits and symbols are left out, and case is lost")
	return P.result(out, P.WORKS, "Bacon writes each letter as five A or B" + (" (I and J share a code, as do U and V)" if classic else "") + "; case is lost")


static func _bacon_decode(text: String, classic: bool) -> Dictionary:
	var letters: String = "ABCDEFGHIKLMNOPQRSTUWXYZ" if classic else "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var out: String = ""
	var bits: String = ""
	var stray: int = 0
	var any: bool = false
	for ch: String in text.to_upper():
		if ch == "A" or ch == "B":
			bits += ch
			any = true
			if bits.length() == 5:
				var v: int = 0
				for b: String in bits:
					v = v * 2 + (1 if b == "B" else 0)
				if v >= letters.length():
					return P.unchanged(text, "Bacon decode: %s isn't a letter in this alphabet, so the text passes through unchanged" % bits)
				out += letters[v]
				bits = ""
		elif ch == "/":
			out += " "
		elif ch != " " and ch != "\n":
			stray += 1
	if not any or stray > 0:
		return P.unchanged(text, "Bacon decode: this isn't Bacon code (it should be only A, B, spaces and /), so the text passes through unchanged")
	if not bits.is_empty():
		return P.result(out, P.NOTE, "Bacon decode: %d A or B left over at the end don't make a whole letter" % bits.length())
	return P.result(out, P.WORKS, "Bacon decode works on this text")


static func a1z26(text: String, p: Dictionary) -> Dictionary:
	var decode: bool = P.whole(p, "direction", 0) == 1
	if decode:
		return _a1z26_decode(text)
	var words: PackedStringArray = PackedStringArray()
	var kept: int = 0
	var letters: int = 0
	for w: String in text.split(" ", false):
		var parts: PackedStringArray = PackedStringArray()
		for i: int in w.length():
			var c: int = w.unicode_at(i)
			if c >= 65 and c <= 90:
				parts.append(str(c - 64))
				letters += 1
			elif c >= 97 and c <= 122:
				parts.append(str(c - 96))
				letters += 1
			else:
				parts.append(String.chr(c))
				kept += 1
		words.append("-".join(parts))
	if letters == 0:
		return P.result(text, P.IDLE, "A1Z26 turns letters into numbers, and there are none here, so nothing changes")
	var out: String = " ".join(words)
	if kept > 0:
		return P.result(out, P.NOTE, "A1Z26 changes letters only; digits and symbols stay as they are, so decoding may read digits as letters")
	return P.result(out, P.WORKS, "A1Z26 writes each letter as its place in the alphabet; case is lost")


static func _a1z26_decode(text: String) -> Dictionary:
	var words: PackedStringArray = PackedStringArray()
	var numbers: int = 0
	for w: String in text.strip_edges().split(" ", false):
		var word: String = ""
		for part: String in w.split("-", false):
			if part.is_valid_int():
				var v: int = part.to_int()
				if v < 1 or v > 26:
					return P.unchanged(text, "A1Z26 decode: %d is not between 1 and 26, so the text passes through unchanged" % v)
				word += String.chr(64 + v)
				numbers += 1
			else:
				word += part
		words.append(word)
	if numbers == 0:
		return P.unchanged(text, "A1Z26 decode: there are no numbers here, so the text passes through unchanged")
	return P.result(" ".join(words), P.WORKS, "A1Z26 decode works on this text")


static func reverse(text: String, p: Dictionary) -> Dictionary:
	var how: int = P.whole(p, "what", 0)
	var out: String = ""
	if how == 1:
		var words: PackedStringArray = PackedStringArray()
		for line: String in text.split("\n"):
			var ws: PackedStringArray = line.split(" ")
			ws.reverse()
			words.append(" ".join(ws))
		out = "\n".join(words)
	elif how == 2:
		var lines: PackedStringArray = text.split("\n")
		lines.reverse()
		out = "\n".join(lines)
	elif how == 3:
		var lines2: PackedStringArray = PackedStringArray()
		for line2: String in text.split("\n"):
			var ws2: PackedStringArray = PackedStringArray()
			for w: String in line2.split(" "):
				ws2.append(w.reverse())
			lines2.append(" ".join(ws2))
		out = "\n".join(lines2)
	else:
		out = text.reverse()
	if out == text:
		return P.result(out, P.IDLE, "Reversing this gives the same text back")
	var r: Dictionary = P.result(out, P.WORKS, "Reverse works on any text. Reverse again to get it back.")
	if how == 0:
		var map: PackedInt32Array = PackedInt32Array()
		for i: int in text.length():
			map.append(text.length() - 1 - i)
		r["map"] = map
	return r


static func upside_down(text: String, p: Dictionary) -> Dictionary:
	var back: bool = P.whole(p, "direction", 0) == 1
	var src: String = FLIP_TO if back else FLIP_FROM
	var dst: String = FLIP_FROM if back else FLIP_TO
	var out: String = ""
	var passed: int = 0
	var changed: int = 0
	for i: int in range(text.length() - 1, -1, -1):
		var ch: String = text[i]
		var at: int = src.find(ch)
		if at >= 0:
			out += dst[at]
			changed += 1
		else:
			out += ch
			if not P.blank(text.unicode_at(i)):
				passed += 1
	var map: PackedInt32Array = PackedInt32Array()
	for j: int in text.length():
		map.append(text.length() - 1 - j)
	var r: Dictionary = {}
	if changed == 0:
		r = P.result(out, P.NOTE, "Upside down: none of these characters have an upside down form, so they're only reversed")
	elif passed > 0:
		r = P.result(out, P.NOTE, "Upside down turns letters, digits and common marks; other characters are only reversed")
	else:
		r = P.result(out, P.WORKS, "Upside down works on every character here" + (". Flip back to read it." if not back else ""))
	r["map"] = map
	return r


static func leetspeak(text: String, p: Dictionary) -> Dictionary:
	var table: Dictionary = LEET_STRONG if P.whole(p, "level", 0) == 1 else LEET_BASIC
	var decode: bool = P.whole(p, "direction", 0) == 1
	var out: String = ""
	var changed: int = 0
	if decode:
		var back: Dictionary = {}
		for k: String in table.keys():
			if not back.has(table[k]):
				back[table[k]] = k
		for ch: String in text:
			if back.has(ch):
				out += String(back[ch])
				changed += 1
			else:
				out += ch
		if changed == 0:
			return P.result(out, P.IDLE, "There's no leetspeak here to turn back")
		return P.result(out, P.NOTE, "Leetspeak back to letters is a guess: digits that were really digits become letters too, and case is lost")
	for ch2: String in text:
		var low: String = ch2.to_lower()
		if table.has(low):
			out += String(table[low])
			changed += 1
		else:
			out += ch2
	if changed == 0:
		return P.result(out, P.IDLE, "None of these letters have a leetspeak form, so nothing changes")
	return P.result(out, P.NOTE, "Leetspeak swaps some letters for look-alike digits and symbols; turning it back is only a guess")


static func keyboard_shift(text: String, p: Dictionary) -> Dictionary:
	var shift: int = P.whole(p, "shift", 1)
	if shift == 0:
		return P.result(text, P.IDLE, "A shift of 0 keys changes nothing")
	var out: String = ""
	var changed: int = 0
	var passed: int = 0
	for ch: String in text:
		var done: bool = false
		for row: String in KEY_ROWS:
			var at: int = row.find(ch)
			if at >= 0:
				out += row[posmod(at + shift, row.length())]
				changed += 1
				done = true
				break
		if not done:
			out += ch
			if ch != " " and ch != "\n":
				passed += 1
	var back: String = " Shift by %d to get it back." % -shift
	if changed == 0:
		return P.result(out, P.IDLE, "None of these characters are on a QWERTY keyboard, so nothing changes")
	if passed > 0:
		return P.result(out, P.NOTE, "Keyboard shift moves each key along its QWERTY row; characters not on the keyboard pass through." + back)
	return P.result(out, P.WORKS, "Keyboard shift moves each key along its QWERTY row." + back)

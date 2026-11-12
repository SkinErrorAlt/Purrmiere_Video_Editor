extends RefCounted

const P := preload("res://doc/text_fx/fx_params.gd")
const B := preload("res://doc/text_fx/fx_bytes.gd")
const MORSE: Dictionary = {
	"A": ".-", "B": "-...", "C": "-.-.", "D": "-..", "E": ".", "F": "..-.", "G": "--.", "H": "....", "I": "..", "J": ".---",
	"K": "-.-", "L": ".-..", "M": "--", "N": "-.", "O": "---", "P": ".--.", "Q": "--.-", "R": ".-.", "S": "...", "T": "-",
	"U": "..-", "V": "...-", "W": ".--", "X": "-..-", "Y": "-.--", "Z": "--..",
	"0": "-----", "1": ".----", "2": "..---", "3": "...--", "4": "....-", "5": ".....", "6": "-....", "7": "--...", "8": "---..", "9": "----.",
	".": ".-.-.-", ",": "--..--", "?": "..--..", "'": ".----.", "!": "-.-.--", "/": "-..-.", "(": "-.--.", ")": "-.--.-", "&": ".-...",
	":": "---...", ";": "-.-.-.", "=": "-...-", "+": ".-.-.", "-": "-....-", "_": "..--.-", "\"": ".-..-.", "$": "...-..-", "@": ".--.-.",
}
const URL_SAFE := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()"
const HTML_NAMED: Dictionary = {
	"amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "copy": "©", "reg": "®", "trade": "™",
	"hellip": "…", "mdash": "—", "ndash": "–", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”", "deg": "°",
	"euro": "€", "pound": "£", "yen": "¥", "cent": "¢", "sect": "§", "para": "¶", "middot": "·", "bull": "•",
	"times": "×", "divide": "÷", "laquo": "«", "raquo": "»", "iexcl": "¡", "iquest": "¿", "shy": "­",
}

static var _morse_back: Dictionary = {}


static func _decoded_text(name: String, got: Dictionary, input: String, what: String) -> Dictionary:
	if not bool(got["ok"]):
		return P.unchanged(input, name + ": this isn't valid " + what + ", so the text passes through unchanged")
	var bytes: PackedByteArray = got["bytes"]
	if not B.readable(bytes):
		return P.unchanged(input, name + ": this is valid " + what + " but it decodes to bytes that aren't readable text (maybe it's encrypted or compressed), so the text passes through unchanged")
	return P.result(B.text_of(bytes), P.WORKS, name + " works on this text")


static func morse(text: String, p: Dictionary) -> Dictionary:
	if P.whole(p, "direction", 0) == 1:
		return _morse_decode(text)
	var words: PackedStringArray = PackedStringArray()
	var missing: String = ""
	for w: String in text.to_upper().split(" ", false):
		var codes: PackedStringArray = PackedStringArray()
		for ch: String in w:
			if MORSE.has(ch):
				codes.append(String(MORSE[ch]))
			elif ch != "\n" and not missing.contains(ch):
				missing += ch
		if not codes.is_empty():
			words.append(" ".join(codes))
	if words.is_empty():
		return P.unchanged(text, "Morse has codes for letters, digits and common marks, and there are none here, so the text passes through unchanged")
	var out: String = " / ".join(words)
	if not missing.is_empty():
		var listed: PackedStringArray = PackedStringArray()
		for m: String in missing:
			listed.append(m)
		return P.result(out, P.NOTE, "Morse has no code for " + " ".join(listed) + ", so those are left out; case is lost")
	return P.result(out, P.WORKS, "Morse works on this text; letters are split by spaces and words by /, and case is lost")


static func _morse_decode(text: String) -> Dictionary:
	if _morse_back.is_empty():
		for k: String in MORSE.keys():
			_morse_back[MORSE[k]] = k
	var clean: String = text.replace("·", ".").replace("•", ".").replace("−", "-").replace("–", "-").replace("—", "-").replace("_", "-").replace("|", "/").replace("\n", " / ")
	for ch: String in clean:
		if ch != "." and ch != "-" and ch != " " and ch != "/":
			return P.unchanged(text, "Morse decode: this isn't Morse code (it should be only dots, dashes, spaces and /), so the text passes through unchanged")
	var words: PackedStringArray = PackedStringArray()
	var unknown: int = 0
	for w: String in clean.split("/", false):
		var word: String = ""
		for code: String in w.strip_edges().split(" ", false):
			if _morse_back.has(code):
				word += String(_morse_back[code])
			else:
				word += "?"
				unknown += 1
		if not word.is_empty():
			words.append(word)
	if words.is_empty():
		return P.unchanged(text, "Morse decode: there's no Morse code here, so the text passes through unchanged")
	var out: String = " ".join(words)
	if unknown > 0:
		return P.result(out, P.NOTE, "Morse decode: %d code(s) aren't letters or digits and show as ?" % unknown)
	return P.result(out, P.WORKS, "Morse decode works on this text")


static func binary(text: String, p: Dictionary) -> Dictionary:
	var decode: bool = P.whole(p, "direction", 0) == 1
	var sep: String = "" if P.whole(p, "spacing", 0) == 1 else " "
	if not decode:
		var parts: PackedStringArray = PackedStringArray()
		for v: int in B.utf8(text):
			var s: String = ""
			for b: int in range(7, -1, -1):
				s += "1" if ((v >> b) & 1) == 1 else "0"
			parts.append(s)
		if parts.is_empty():
			return P.result("", P.IDLE, "There's no text to turn into binary")
		return P.result(sep.join(parts), P.WORKS, "Binary writes each byte of the text (UTF-8) as eight 0s and 1s")
	var clean: String = text.replace(" ", "").replace("\n", "").replace("\t", "")
	var bad: bool = clean.is_empty() or clean.length() % 8 != 0
	for ch: String in clean:
		if ch != "0" and ch != "1":
			bad = true
			break
	if bad:
		return P.unchanged(text, "Binary decode: this isn't binary (it should be groups of eight 0s and 1s), so the text passes through unchanged")
	var out: PackedByteArray = PackedByteArray()
	for i: int in range(0, clean.length(), 8):
		var v2: int = 0
		for k: int in 8:
			v2 = v2 * 2 + (1 if clean[i + k] == "1" else 0)
		out.append(v2)
	return _decoded_text("Binary decode", {"ok": true, "bytes": out}, text, "binary")


static func octal(text: String, p: Dictionary) -> Dictionary:
	var decode: bool = P.whole(p, "direction", 0) == 1
	if not decode:
		var parts: PackedStringArray = PackedStringArray()
		for v: int in B.utf8(text):
			parts.append("%03o" % v)
		if parts.is_empty():
			return P.result("", P.IDLE, "There's no text to turn into octal")
		return P.result(" ".join(parts), P.WORKS, "Octal writes each byte of the text (UTF-8) as three digits from 0 to 7")
	var tokens: PackedStringArray = text.strip_edges().replace("\n", " ").split(" ", false)
	if tokens.size() == 1 and tokens[0].length() > 3 and tokens[0].length() % 3 == 0:
		var joined: String = tokens[0]
		tokens = PackedStringArray()
		for i: int in range(0, joined.length(), 3):
			tokens.append(joined.substr(i, 3))
	var out: PackedByteArray = PackedByteArray()
	for t: String in tokens:
		var v2: int = 0
		if t.is_empty() or t.length() > 3:
			return P.unchanged(text, "Octal decode: this isn't octal (it should be groups of up to three digits from 0 to 7), so the text passes through unchanged")
		for ch: String in t:
			if not "01234567".contains(ch):
				return P.unchanged(text, "Octal decode: this isn't octal (it should be groups of up to three digits from 0 to 7), so the text passes through unchanged")
			v2 = v2 * 8 + ch.to_int()
		if v2 > 255:
			return P.unchanged(text, "Octal decode: %s is bigger than one byte (377), so the text passes through unchanged" % t)
		out.append(v2)
	return _decoded_text("Octal decode", {"ok": not out.is_empty(), "bytes": out}, text, "octal")


static func hex(text: String, p: Dictionary) -> Dictionary:
	var decode: bool = P.whole(p, "direction", 0) == 1
	if not decode:
		var b: PackedByteArray = B.utf8(text)
		if b.is_empty():
			return P.result("", P.IDLE, "There's no text to turn into hex")
		var upper: bool = P.flag(p, "upper", false)
		var sep: String = " " if P.whole(p, "spacing", 0) == 0 else ""
		return P.result(B.to_hex(b, upper, sep), P.WORKS, "Hex writes each byte of the text (UTF-8) as two digits from 0 to f")
	return _decoded_text("Hex decode", B.from_hex(text), text, "hex")


static func base32(text: String, p: Dictionary) -> Dictionary:
	if P.whole(p, "direction", 0) == 1:
		return _decoded_text("Base32 decode", B.from_base32(text), text, "base32")
	if text.is_empty():
		return P.result("", P.IDLE, "There's no text to encode")
	return P.result(B.base32(B.utf8(text)), P.WORKS, "Base32 works on any text (RFC 4648)")


static func base64(text: String, p: Dictionary) -> Dictionary:
	if P.whole(p, "direction", 0) == 1:
		return _decoded_text("Base64 decode", B.from_base64(text), text, "base64")
	if text.is_empty():
		return P.result("", P.IDLE, "There's no text to encode")
	var url: bool = P.whole(p, "variant", 0) == 1
	return P.result(B.base64(B.utf8(text), url), P.WORKS, "Base64 works on any text" + (" (URL safe: - and _ instead of + and /, no = padding)" if url else ""))


static func url(text: String, p: Dictionary) -> Dictionary:
	if P.whole(p, "direction", 0) == 1:
		return _url_decode(text)
	var out: String = ""
	var changed: int = 0
	for ch: String in text:
		if URL_SAFE.contains(ch):
			out += ch
		else:
			for v: int in B.utf8(ch):
				out += "%" + B.to_hex(PackedByteArray([v]), true)
			changed += 1
	if changed == 0:
		return P.result(out, P.IDLE, "Nothing here needs URL encoding, so nothing changes")
	return P.result(out, P.WORKS, "URL encoding works on any text (as encodeURIComponent)")


static func _url_decode(text: String) -> Dictionary:
	if not text.contains("%"):
		return P.result(text, P.IDLE, "There's nothing URL encoded here (no % codes), so nothing changes")
	var bytes: PackedByteArray = PackedByteArray()
	var i: int = 0
	while i < text.length():
		var ch: String = text[i]
		if ch == "%":
			var got: Dictionary = B.from_hex(text.substr(i + 1, 2)) if i + 2 < text.length() else {"ok": false}
			if not bool(got["ok"]):
				return P.unchanged(text, "URL decode: \"" + text.substr(i, 3) + "\" isn't a valid percent code, so the text passes through unchanged")
			bytes.append_array(got["bytes"] as PackedByteArray)
			i += 3
			continue
		bytes.append_array(B.utf8(ch))
		i += 1
	if not B.readable(bytes):
		return P.unchanged(text, "URL decode: the % codes don't make readable text, so the text passes through unchanged")
	return P.result(B.text_of(bytes), P.WORKS, "URL decode works on this text")


static func html_entities(text: String, p: Dictionary) -> Dictionary:
	if P.whole(p, "direction", 0) == 1:
		return _html_decode(text)
	var all: bool = P.flag(p, "all", false)
	var out: String = ""
	var changed: int = 0
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		var ch: String = String.chr(c)
		var rep: String = ""
		match ch:
			"&":
				rep = "&amp;"
			"<":
				rep = "&lt;"
			">":
				rep = "&gt;"
			"\"":
				rep = "&quot;"
			"'":
				rep = "&#39;"
		if rep.is_empty() and all and c > 126:
			rep = "&#%d;" % c
		if rep.is_empty():
			out += ch
		else:
			out += rep
			changed += 1
	if changed == 0:
		return P.result(out, P.IDLE, "Nothing here needs escaping as HTML, so nothing changes" + ("" if all else " (only & < > \" ' are escaped)"))
	return P.result(out, P.WORKS, "HTML entities work on any text")


static func _html_decode(text: String) -> Dictionary:
	var out: String = ""
	var i: int = 0
	var changed: int = 0
	var unknown: int = 0
	while i < text.length():
		var ch: String = text[i]
		var semi: int = text.find(";", i)
		if ch == "&" and semi > i and semi - i <= 12:
			var name: String = text.substr(i + 1, semi - i - 1)
			var rep: String = ""
			if name.begins_with("#x") or name.begins_with("#X"):
				var hx: String = name.substr(2)
				if hx.is_valid_hex_number(false) and not hx.is_empty():
					rep = String.chr(hx.hex_to_int())
			elif name.begins_with("#"):
				var dec: String = name.substr(1)
				if dec.is_valid_int():
					rep = String.chr(dec.to_int())
			elif HTML_NAMED.has(name):
				rep = String(HTML_NAMED[name])
			if not rep.is_empty():
				out += rep
				changed += 1
				i = semi + 1
				continue
			unknown += 1
		out += ch
		i += 1
	if changed == 0:
		return P.result(text, P.IDLE, "There are no HTML entities here (like &amp; or &#39;), so nothing changes")
	if unknown > 0:
		return P.result(out, P.NOTE, "HTML entities decode: %d entity name(s) aren't known and stay as they are" % unknown)
	return P.result(out, P.WORKS, "HTML entities decode works on this text")

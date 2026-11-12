extends RefCounted

const K512_HEX := "428a2f98d728ae22 7137449123ef65cd b5c0fbcfec4d3b2f e9b5dba58189dbbc 3956c25bf348b538 59f111f1b605d019 923f82a4af194f9b ab1c5ed5da6d8118 d807aa98a3030242 12835b0145706fbe 243185be4ee4b28c 550c7dc3d5ffb4e2 72be5d74f27b896f 80deb1fe3b1696b1 9bdc06a725c71235 c19bf174cf692694 e49b69c19ef14ad2 efbe4786384f25e3 0fc19dc68b8cd5b5 240ca1cc77ac9c65 2de92c6f592b0275 4a7484aa6ea6e483 5cb0a9dcbd41fbd4 76f988da831153b5 983e5152ee66dfab a831c66d2db43210 b00327c898fb213f bf597fc7beef0ee4 c6e00bf33da88fc2 d5a79147930aa725 06ca6351e003826f 142929670a0e6e70 27b70a8546d22ffc 2e1b21385c26c926 4d2c6dfc5ac42aed 53380d139d95b3df 650a73548baf63de 766a0abb3c77b2a8 81c2c92e47edaee6 92722c851482353b a2bfe8a14cf10364 a81a664bbc423001 c24b8b70d0f89791 c76c51a30654be30 d192e819d6ef5218 d69906245565a910 f40e35855771202a 106aa07032bbd1b8 19a4c116b8d2d0c8 1e376c085141ab53 2748774cdf8eeb99 34b0bcb5e19b48a8 391c0cb3c5c95a63 4ed8aa4ae3418acb 5b9cca4f7763e373 682e6ff3d6b2b8a3 748f82ee5defb2fc 78a5636f43172f60 84c87814a1f0ab72 8cc702081a6439ec 90befffa23631e28 a4506cebde82bde9 bef9a3f7b2c67915 c67178f2e372532b ca273eceea26619c d186b8c721c0c207 eada7dd6cde0eb1e f57d4f7fee6ed178 06f067aa72176fba 0a637dc5a2c898a6 113f9804bef90dae 1b710b35131c471b 28db77f523047d84 32caab7b40c72493 3c9ebe0a15c9bebc 431d67c49c100d4c 4cc5d4becb3e42b6 597f299cfc657e2a 5fcb6fab3ad6faec 6c44198c4a475817"
const H512_HEX := "6a09e667f3bcc908 bb67ae8584caa73b 3c6ef372fe94f82b a54ff53a5f1d36f1 510e527fade682d1 9b05688c2b3e6c1f 1f83d9abfb41bd6b 5be0cd19137e2179"
const B32 := "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
const B64 := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
const B64_URL := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
const HEX_DIGITS := "0123456789abcdef"
const HASHES: PackedStringArray = ["md5", "sha1", "sha256", "sha512"]
const OPENSSL_MAGIC := "Salted__"
const PBKDF2_ROUNDS := 10000
const KDF_CACHE_MAX := 32

static var _k512: PackedInt64Array = PackedInt64Array()
static var _crc_table: PackedInt64Array = PackedInt64Array()
static var _kdf_cache: Dictionary = {}


static func utf8(s: String) -> PackedByteArray:
	return s.to_utf8_buffer()


## True when the bytes are well formed UTF-8 that reads as text: no stray control bytes.
static func readable(b: PackedByteArray) -> bool:
	var i: int = 0
	var n: int = b.size()
	while i < n:
		var c: int = b[i]
		if c < 0x80:
			if c < 0x20 and c != 9 and c != 10 and c != 13:
				return false
			if c == 0x7F:
				return false
			i += 1
			continue
		var more: int = 0
		var lowest: int = 0
		if c >= 0xC2 and c <= 0xDF:
			more = 1
			lowest = 0x80
		elif c >= 0xE0 and c <= 0xEF:
			more = 2
			lowest = 0x800
		elif c >= 0xF0 and c <= 0xF4:
			more = 3
			lowest = 0x10000
		else:
			return false
		if i + more > n - 1:
			return false
		var cp: int = c & (0x3F >> more)
		for k: int in more:
			var cc: int = b[i + 1 + k]
			if (cc & 0xC0) != 0x80:
				return false
			cp = (cp << 6) | (cc & 0x3F)
		if cp < lowest or cp > 0x10FFFF or (cp >= 0xD800 and cp <= 0xDFFF):
			return false
		i += more + 1
	return true


static func text_of(b: PackedByteArray) -> String:
	if b.is_empty():
		return ""
	return b.get_string_from_utf8()


static func to_hex(b: PackedByteArray, upper: bool = false, sep: String = "") -> String:
	var parts: PackedStringArray = PackedStringArray()
	for v: int in b:
		var two: String = HEX_DIGITS[v >> 4] + HEX_DIGITS[v & 15]
		parts.append(two.to_upper() if upper else two)
	return sep.join(parts)


## Hex digits to bytes, ignoring spaces, colons, dashes and an optional 0x. Empty result and ok false when not hex.
static func from_hex(s: String) -> Dictionary:
	var clean: String = ""
	var body: String = s.strip_edges()
	var words: PackedStringArray = body.split(" ", false)
	for w: String in words:
		var x: String = w.strip_edges()
		if x.begins_with("0x") or x.begins_with("0X"):
			x = x.substr(2)
		clean += x
	clean = clean.replace(":", "").replace("-", "").replace("\n", "").replace("\t", "").replace("\r", "").to_lower()
	var out: PackedByteArray = PackedByteArray()
	if clean.is_empty() or clean.length() % 2 != 0:
		return {"ok": false, "bytes": out}
	for i: int in range(0, clean.length(), 2):
		var hi: int = HEX_DIGITS.find(clean[i])
		var lo: int = HEX_DIGITS.find(clean[i + 1])
		if hi < 0 or lo < 0:
			return {"ok": false, "bytes": PackedByteArray()}
		out.append(hi * 16 + lo)
	return {"ok": true, "bytes": out}


static func base64(b: PackedByteArray, url_safe: bool = false) -> String:
	var table: String = B64_URL if url_safe else B64
	var out: String = ""
	var i: int = 0
	var n: int = b.size()
	while i + 2 < n:
		var v: int = (b[i] << 16) | (b[i + 1] << 8) | b[i + 2]
		out += table[(v >> 18) & 63] + table[(v >> 12) & 63] + table[(v >> 6) & 63] + table[v & 63]
		i += 3
	var left: int = n - i
	if left == 1:
		var v1: int = b[i] << 16
		out += table[(v1 >> 18) & 63] + table[(v1 >> 12) & 63] + ("" if url_safe else "==")
	elif left == 2:
		var v2: int = (b[i] << 16) | (b[i + 1] << 8)
		out += table[(v2 >> 18) & 63] + table[(v2 >> 12) & 63] + table[(v2 >> 6) & 63] + ("" if url_safe else "=")
	return out


## Reads standard or URL safe base64, padded or not, ignoring line breaks and spaces at the ends.
static func from_base64(s: String) -> Dictionary:
	var clean: String = ""
	for ch: String in s.strip_edges():
		if ch == "\n" or ch == "\r":
			continue
		clean += ch
	var pad: int = 0
	while clean.ends_with("="):
		clean = clean.left(clean.length() - 1)
		pad += 1
	var bad: Dictionary = {"ok": false, "bytes": PackedByteArray()}
	if clean.is_empty() or pad > 2 or clean.length() % 4 == 1:
		return bad
	if pad > 0 and (clean.length() + pad) % 4 != 0:
		return bad
	var out: PackedByteArray = PackedByteArray()
	var acc: int = 0
	var bits: int = 0
	for ch2: String in clean:
		var v: int = B64.find(ch2)
		if v < 0:
			v = B64_URL.find(ch2)
		if v < 0:
			return bad
		acc = ((acc << 6) | v) & 0xFFFFFF
		bits += 6
		if bits >= 8:
			bits -= 8
			out.append((acc >> bits) & 0xFF)
	return {"ok": true, "bytes": out}


static func base32(b: PackedByteArray) -> String:
	var out: String = ""
	var acc: int = 0
	var bits: int = 0
	for v: int in b:
		acc = ((acc << 8) | v) & 0xFFFF
		bits += 8
		while bits >= 5:
			bits -= 5
			out += B32[(acc >> bits) & 31]
	if bits > 0:
		out += B32[(acc << (5 - bits)) & 31]
	while out.length() % 8 != 0:
		out += "="
	return out


static func from_base32(s: String) -> Dictionary:
	var clean: String = s.strip_edges().replace(" ", "").replace("\n", "").to_upper()
	while clean.ends_with("="):
		clean = clean.left(clean.length() - 1)
	var bad: Dictionary = {"ok": false, "bytes": PackedByteArray()}
	if clean.is_empty() or [1, 3, 6].has(clean.length() % 8):
		return bad
	var out: PackedByteArray = PackedByteArray()
	var acc: int = 0
	var bits: int = 0
	for ch: String in clean:
		var v: int = B32.find(ch)
		if v < 0:
			return bad
		acc = ((acc << 5) | v) & 0xFFFF
		bits += 5
		if bits >= 8:
			bits -= 8
			out.append((acc >> bits) & 0xFF)
	return {"ok": true, "bytes": out}


static func _shr(x: int, n: int) -> int:
	return (x >> n) & (0x7FFFFFFFFFFFFFFF >> (n - 1))


static func _rotr(x: int, n: int) -> int:
	return _shr(x, n) | (x << (64 - n))


static func _parse64(words: String) -> PackedInt64Array:
	var out: PackedInt64Array = PackedInt64Array()
	for w: String in words.split(" ", false):
		var hi: int = ("0x" + w.substr(0, 8)).hex_to_int()
		var lo: int = ("0x" + w.substr(8, 8)).hex_to_int()
		out.append((hi << 32) | lo)
	return out


static func sha512(data: PackedByteArray) -> PackedByteArray:
	if _k512.is_empty():
		_k512 = _parse64(K512_HEX)
	var h: PackedInt64Array = _parse64(H512_HEX)
	var msg: PackedByteArray = data.duplicate()
	var bit_len: int = data.size() * 8
	msg.append(0x80)
	while msg.size() % 128 != 112:
		msg.append(0)
	for z: int in 8:
		msg.append(0)
	for i: int in 8:
		msg.append((bit_len >> (56 - 8 * i)) & 0xFF)
	var w: PackedInt64Array = PackedInt64Array()
	w.resize(80)
	for off: int in range(0, msg.size(), 128):
		for t: int in 16:
			var v: int = 0
			for j: int in 8:
				v = (v << 8) | msg[off + t * 8 + j]
			w[t] = v
		for t2: int in range(16, 80):
			var x15: int = w[t2 - 15]
			var x2: int = w[t2 - 2]
			var s0: int = _rotr(x15, 1) ^ _rotr(x15, 8) ^ _shr(x15, 7)
			var s1: int = _rotr(x2, 19) ^ _rotr(x2, 61) ^ _shr(x2, 6)
			w[t2] = w[t2 - 16] + s0 + w[t2 - 7] + s1
		var a: int = h[0]
		var b: int = h[1]
		var c: int = h[2]
		var d: int = h[3]
		var e: int = h[4]
		var f: int = h[5]
		var g: int = h[6]
		var hh: int = h[7]
		for t3: int in 80:
			var big1: int = _rotr(e, 14) ^ _rotr(e, 18) ^ _rotr(e, 41)
			var ch: int = (e & f) ^ (~e & g)
			var t1: int = hh + big1 + ch + _k512[t3] + w[t3]
			var big0: int = _rotr(a, 28) ^ _rotr(a, 34) ^ _rotr(a, 39)
			var maj: int = (a & b) ^ (a & c) ^ (b & c)
			var t2v: int = big0 + maj
			hh = g
			g = f
			f = e
			e = d + t1
			d = c
			c = b
			b = a
			a = t1 + t2v
		h[0] += a
		h[1] += b
		h[2] += c
		h[3] += d
		h[4] += e
		h[5] += f
		h[6] += g
		h[7] += hh
	var out: PackedByteArray = PackedByteArray()
	for word: int in h:
		for k: int in 8:
			out.append((word >> (56 - 8 * k)) & 0xFF)
	return out


static func crc32(data: PackedByteArray) -> int:
	if _crc_table.is_empty():
		_crc_table.resize(256)
		for n: int in 256:
			var c: int = n
			for k: int in 8:
				c = (0xEDB88320 ^ (c >> 1)) if (c & 1) == 1 else (c >> 1)
			_crc_table[n] = c
	var crc: int = 0xFFFFFFFF
	for v: int in data:
		crc = _crc_table[(crc ^ v) & 0xFF] ^ (crc >> 8)
	return crc ^ 0xFFFFFFFF


static func crc32_bytes(data: PackedByteArray) -> PackedByteArray:
	var v: int = crc32(data)
	return PackedByteArray([(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF])


static func digest(kind: String, data: PackedByteArray) -> PackedByteArray:
	if kind == "sha512":
		return sha512(data)
	if kind == "crc32":
		return crc32_bytes(data)
	var ctx: HashingContext = HashingContext.new()
	var t: HashingContext.HashType = HashingContext.HASH_SHA256
	if kind == "md5":
		t = HashingContext.HASH_MD5
	elif kind == "sha1":
		t = HashingContext.HASH_SHA1
	ctx.start(t)
	if not data.is_empty():
		ctx.update(data)
	return ctx.finish()


static func block_size(kind: String) -> int:
	return 128 if kind == "sha512" else 64


static func hmac(kind: String, key: PackedByteArray, msg: PackedByteArray) -> PackedByteArray:
	var block: int = block_size(kind)
	var k: PackedByteArray = digest(kind, key) if key.size() > block else key.duplicate()
	k.resize(block)
	var ipad: PackedByteArray = PackedByteArray()
	var opad: PackedByteArray = PackedByteArray()
	ipad.resize(block)
	opad.resize(block)
	for i: int in block:
		ipad[i] = k[i] ^ 0x36
		opad[i] = k[i] ^ 0x5C
	return digest(kind, opad + digest(kind, ipad + msg))


static func pbkdf2_sha256(password: PackedByteArray, salt: PackedByteArray, rounds: int, length: int) -> PackedByteArray:
	var block: int = 64
	var k: PackedByteArray = digest("sha256", password) if password.size() > block else password.duplicate()
	k.resize(block)
	var ipad: PackedByteArray = PackedByteArray()
	var opad: PackedByteArray = PackedByteArray()
	ipad.resize(block)
	opad.resize(block)
	for i: int in block:
		ipad[i] = k[i] ^ 0x36
		opad[i] = k[i] ^ 0x5C
	var out: PackedByteArray = PackedByteArray()
	var index: int = 1
	while out.size() < length:
		var first: PackedByteArray = salt + PackedByteArray([(index >> 24) & 0xFF, (index >> 16) & 0xFF, (index >> 8) & 0xFF, index & 0xFF])
		var u: PackedByteArray = digest("sha256", opad + digest("sha256", ipad + first))
		var acc: PackedByteArray = u.duplicate()
		for r: int in range(1, rounds):
			u = digest("sha256", opad + digest("sha256", ipad + u))
			for j: int in acc.size():
				acc[j] = acc[j] ^ u[j]
		out.append_array(acc)
		index += 1
	return out.slice(0, length)


## OpenSSL's EVP_BytesToKey with MD5 and one round, as CryptoJS and "openssl enc -md md5" use.
static func evp_bytes_to_key(password: PackedByteArray, salt: PackedByteArray, key_len: int, iv_len: int) -> Dictionary:
	var total: PackedByteArray = PackedByteArray()
	var prev: PackedByteArray = PackedByteArray()
	while total.size() < key_len + iv_len:
		prev = digest("md5", prev + password + salt)
		total.append_array(prev)
	return {"key": total.slice(0, key_len), "iv": total.slice(key_len, key_len + iv_len)}


static func derive(kdf: String, password: PackedByteArray, salt: PackedByteArray) -> Dictionary:
	var ck: String = kdf + "|" + to_hex(password) + "|" + to_hex(salt)
	if _kdf_cache.has(ck):
		return _kdf_cache[ck]
	var got: Dictionary = {}
	if kdf == "pbkdf2":
		var raw: PackedByteArray = pbkdf2_sha256(password, salt, PBKDF2_ROUNDS, 48)
		got = {"key": raw.slice(0, 32), "iv": raw.slice(32, 48)}
	else:
		got = evp_bytes_to_key(password, salt, 32, 16)
	if _kdf_cache.size() >= KDF_CACHE_MAX:
		_kdf_cache.clear()
	_kdf_cache[ck] = got
	return got


static func pkcs7_pad(b: PackedByteArray) -> PackedByteArray:
	var n: int = 16 - (b.size() % 16)
	var out: PackedByteArray = b.duplicate()
	for i: int in n:
		out.append(n)
	return out


static func pkcs7_unpad(b: PackedByteArray) -> Dictionary:
	if b.is_empty() or b.size() % 16 != 0:
		return {"ok": false, "bytes": PackedByteArray()}
	var n: int = b[b.size() - 1]
	if n < 1 or n > 16:
		return {"ok": false, "bytes": PackedByteArray()}
	for i: int in n:
		if b[b.size() - 1 - i] != n:
			return {"ok": false, "bytes": PackedByteArray()}
	return {"ok": true, "bytes": b.slice(0, b.size() - n)}


## Raw AES in CBC mode. Data must be whole 16 byte blocks; the key 16 or 32 bytes; the IV 16 bytes.
static func aes_cbc(encrypt: bool, key: PackedByteArray, iv: PackedByteArray, data: PackedByteArray) -> PackedByteArray:
	if data.is_empty() or data.size() % 16 != 0 or iv.size() != 16 or not (key.size() == 16 or key.size() == 32):
		return PackedByteArray()
	var ctx: AESContext = AESContext.new()
	if ctx.start(AESContext.MODE_CBC_ENCRYPT if encrypt else AESContext.MODE_CBC_DECRYPT, key, iv) != OK:
		return PackedByteArray()
	var out: PackedByteArray = ctx.update(data)
	ctx.finish()
	return out


static func xor_bytes(data: PackedByteArray, key: PackedByteArray) -> PackedByteArray:
	var out: PackedByteArray = data.duplicate()
	if key.is_empty():
		return out
	for i: int in out.size():
		out[i] = out[i] ^ key[i % key.size()]
	return out

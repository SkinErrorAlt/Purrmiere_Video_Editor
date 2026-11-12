extends RefCounted

const P := preload("res://doc/text_fx/fx_params.gd")
const B := preload("res://doc/text_fx/fx_bytes.gd")
const HASH_IDS: PackedStringArray = ["md5", "sha1", "sha256", "sha512", "crc32"]
const HASH_NAMES: PackedStringArray = ["MD5", "SHA-1", "SHA-256", "SHA-512", "CRC32"]
const HMAC_IDS: PackedStringArray = ["md5", "sha1", "sha256", "sha512"]
const HMAC_NAMES: PackedStringArray = ["HMAC-MD5", "HMAC-SHA1", "HMAC-SHA256", "HMAC-SHA512"]
const KDF_OPENSSL := 0
const KDF_PBKDF2 := 1
const KDF_RAW := 2


static func _bytes_out(b: PackedByteArray, format: int) -> String:
	if format == 1:
		return B.to_hex(b)
	if format == 2:
		return B.to_hex(b, true)
	return B.base64(b)


static func _bytes_in(text: String, format: int) -> Dictionary:
	if format == 1 or format == 2:
		return B.from_hex(text)
	return B.from_base64(text)


static func _format_name(format: int) -> String:
	return "hex" if format == 1 or format == 2 else "base64"


static func digest_text(text: String, p: Dictionary) -> Dictionary:
	var which: int = clampi(P.whole(p, "algorithm", 2), 0, HASH_IDS.size() - 1)
	var out_format: int = P.whole(p, "output", 0)
	var raw: PackedByteArray = B.digest(HASH_IDS[which], B.utf8(text))
	var out: String = B.base64(raw) if out_format == 2 else B.to_hex(raw, out_format == 1)
	var name: String = HASH_NAMES[which]
	var say: String = name + " is one way: what comes out can't be turned back"
	if which == 4:
		say = "CRC32 is a checksum, not a secret: it's one way and easy to fake"
	elif which <= 1:
		say += " (" + name + " is broken for security; fine for puzzles)"
	if text.is_empty():
		say += ". The text is empty, so this is the " + name + " of nothing"
	return P.result(out, P.ONE_WAY, say)


static func hmac_text(text: String, p: Dictionary) -> Dictionary:
	var which: int = clampi(P.whole(p, "algorithm", 2), 0, HMAC_IDS.size() - 1)
	var key: String = P.txt(p, "key", "")
	if key.is_empty():
		return P.unchanged(text, HMAC_NAMES[which] + " needs a key, so the text passes through unchanged")
	var out_format: int = P.whole(p, "output", 0)
	var raw: PackedByteArray = B.hmac(HMAC_IDS[which], B.utf8(key), B.utf8(text))
	var out: String = B.base64(raw) if out_format == 2 else B.to_hex(raw, out_format == 1)
	return P.result(out, P.ONE_WAY, HMAC_NAMES[which] + " is one way: what comes out can't be turned back, only checked by someone with the same key")


static func xor_text(text: String, p: Dictionary) -> Dictionary:
	var key: String = P.txt(p, "key", "")
	if key.is_empty():
		return P.unchanged(text, "XOR needs a key, so the text passes through unchanged")
	var decrypt: bool = P.whole(p, "direction", 0) == 1
	var format: int = P.whole(p, "format", 0)
	var kb: PackedByteArray = B.utf8(key)
	if not decrypt:
		if text.is_empty():
			return P.result("", P.IDLE, "There's no text to XOR")
		return P.result(_bytes_out(B.xor_bytes(B.utf8(text), kb), format), P.WORKS, "XOR with the key works on any text. Decrypt with the same key to get it back.")
	var got: Dictionary = _bytes_in(text, format)
	if not bool(got["ok"]):
		return P.unchanged(text, "XOR decrypt: this isn't valid " + _format_name(format) + ", so the text passes through unchanged")
	var plain: PackedByteArray = B.xor_bytes(got["bytes"] as PackedByteArray, kb)
	if not B.readable(plain):
		return P.unchanged(text, "XOR decrypt: with this key it doesn't come out as readable text (wrong key?), so the text passes through unchanged")
	return P.result(B.text_of(plain), P.WORKS, "XOR decrypt works with this key")


static func _salt_for(p: Dictionary, passphrase: String, text: String) -> Dictionary:
	var typed: String = P.txt(p, "salt", "").strip_edges()
	if typed.is_empty():
		var h: PackedByteArray = B.digest("sha256", B.utf8("salt|" + passphrase + "|" + text))
		return {"ok": true, "bytes": h.slice(0, 8), "auto": true}
	var got: Dictionary = B.from_hex(typed)
	if not bool(got["ok"]) or (got["bytes"] as PackedByteArray).size() != 8:
		return {"ok": false, "bytes": PackedByteArray(), "auto": false}
	return {"ok": true, "bytes": got["bytes"], "auto": false}


static func _raw_key(p: Dictionary) -> Dictionary:
	var key: Dictionary = B.from_hex(P.txt(p, "key_hex", ""))
	var iv: Dictionary = B.from_hex(P.txt(p, "iv_hex", ""))
	if not bool(key["ok"]) or not [16, 32].has((key["bytes"] as PackedByteArray).size()):
		return {"ok": false, "why": "AES needs a key: type 32 hex digits (AES-128) or 64 (AES-256)"}
	if not bool(iv["ok"]) or (iv["bytes"] as PackedByteArray).size() != 16:
		return {"ok": false, "why": "AES needs an IV of 32 hex digits"}
	return {"ok": true, "key": key["bytes"], "iv": iv["bytes"]}


static func aes(text: String, p: Dictionary) -> Dictionary:
	var decrypt: bool = P.whole(p, "direction", 0) == 1
	var kdf: int = clampi(P.whole(p, "key_from", KDF_OPENSSL), 0, 2)
	var format: int = P.whole(p, "format", 0)
	var passphrase: String = P.txt(p, "passphrase", "")
	var key: PackedByteArray = PackedByteArray()
	var iv: PackedByteArray = PackedByteArray()
	var bits: int = 256
	if kdf == KDF_RAW:
		var rk: Dictionary = _raw_key(p)
		if not bool(rk["ok"]):
			return P.unchanged(text, String(rk["why"]) + ", so the text passes through unchanged")
		key = rk["key"]
		iv = rk["iv"]
		bits = key.size() * 8
	elif passphrase.is_empty():
		return P.unchanged(text, "AES needs a key: type a passphrase, so the text passes through unchanged")
	var kdf_name: String = "PBKDF2-SHA256, 10000 rounds" if kdf == KDF_PBKDF2 else "OpenSSL key from passphrase, as CryptoJS"
	if not decrypt:
		if text.is_empty():
			return P.result("", P.IDLE, "There's no text to encrypt")
		var head: PackedByteArray = PackedByteArray()
		if kdf != KDF_RAW:
			var salt: Dictionary = _salt_for(p, passphrase, text)
			if not bool(salt["ok"]):
				return P.unchanged(text, "AES: the salt must be 16 hex digits, or leave it empty, so the text passes through unchanged")
			var made: Dictionary = B.derive("pbkdf2" if kdf == KDF_PBKDF2 else "openssl", B.utf8(passphrase), salt["bytes"] as PackedByteArray)
			key = made["key"]
			iv = made["iv"]
			head = B.utf8(B.OPENSSL_MAGIC) + (salt["bytes"] as PackedByteArray)
		var ct: PackedByteArray = B.aes_cbc(true, key, iv, B.pkcs7_pad(B.utf8(text)))
		var say: String = "AES-%d-CBC" % bits
		if kdf == KDF_RAW:
			say += " with your key and IV. Decrypt with the same key and IV to get it back."
		else:
			say += " (" + kdf_name + "). Decrypt with the same passphrase to get it back; openssl enc -d -aes-256-cbc" + (" -pbkdf2" if kdf == KDF_PBKDF2 else " -md md5") + " reads it too."
		return P.result(_bytes_out(head + ct, format), P.WORKS, say)
	var got: Dictionary = _bytes_in(text, format)
	if not bool(got["ok"]):
		return P.unchanged(text, "AES decrypt: this isn't valid " + _format_name(format) + ", so the text passes through unchanged")
	var data: PackedByteArray = got["bytes"]
	if kdf != KDF_RAW:
		if data.size() < 32 or B.text_of(data.slice(0, 8)) != B.OPENSSL_MAGIC:
			return P.unchanged(text, "AES decrypt: this wasn't made with a passphrase (it has no Salted__ start), so the text passes through unchanged")
		var made2: Dictionary = B.derive("pbkdf2" if kdf == KDF_PBKDF2 else "openssl", B.utf8(passphrase), data.slice(8, 16))
		key = made2["key"]
		iv = made2["iv"]
		data = data.slice(16)
	if data.is_empty() or data.size() % 16 != 0:
		return P.unchanged(text, "AES decrypt: the data isn't whole 16 byte blocks, so it isn't AES output; the text passes through unchanged")
	var plain: Dictionary = B.pkcs7_unpad(B.aes_cbc(false, key, iv, data))
	if not bool(plain["ok"]) or not B.readable(plain["bytes"] as PackedByteArray):
		return P.unchanged(text, "AES decrypt: the " + ("key and IV don't" if kdf == KDF_RAW else "passphrase doesn't") + " fit, the result isn't readable, so the text passes through unchanged")
	return P.result(B.text_of(plain["bytes"] as PackedByteArray), P.WORKS, "AES decrypt works with this " + ("key" if kdf == KDF_RAW else "passphrase"))

extends RefCounted

const HEADER_MIN := 44


static func read_wav(path: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "rate": 48000, "channels": 2, "bits": 16, "data": PackedByteArray(), "why": ""}
	if not FileAccess.file_exists(path):
		out["why"] = "the file is not there: " + path
		return out
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		out["why"] = "the file could not be opened: " + path
		return out
	var size: int = int(f.get_length())
	if size < HEADER_MIN or f.get_buffer(4).get_string_from_ascii() != "RIFF":
		f.close()
		out["why"] = "not a RIFF file: " + path
		return out
	f.get_32()
	if f.get_buffer(4).get_string_from_ascii() != "WAVE":
		f.close()
		out["why"] = "not a WAVE file: " + path
		return out
	while f.get_position() + 8 <= size:
		var id: String = f.get_buffer(4).get_string_from_ascii()
		var length: int = int(f.get_32())
		if length < 0 or f.get_position() + length > size:
			length = size - int(f.get_position())
		if id == "fmt ":
			var here: int = int(f.get_position())
			f.get_16()
			out["channels"] = int(f.get_16())
			out["rate"] = int(f.get_32())
			f.get_32()
			f.get_16()
			out["bits"] = int(f.get_16())
			f.seek(here + length)
		elif id == "data":
			out["data"] = f.get_buffer(length)
			out["ok"] = true
			f.seek(f.get_position())
			break
		else:
			f.seek(f.get_position() + length + (length % 2))
	f.close()
	if not bool(out["ok"]):
		out["why"] = "no sound data in " + path
	return out


static func write_wav(path: String, data: PackedByteArray, rate: int, channels: int, bits: int) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var block: int = channels * (bits / 8)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(channels)
	f.store_32(rate)
	f.store_32(rate * block)
	f.store_16(block)
	f.store_16(bits)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()
	return true


static func join(paths: PackedStringArray, out_path: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "why": "", "seconds": 0.0, "bytes": 0}
	if paths.is_empty():
		out["why"] = "there is nothing to join"
		return out
	var data: PackedByteArray = PackedByteArray()
	var rate: int = 0
	var channels: int = 0
	var bits: int = 0
	for p: String in paths:
		var piece: Dictionary = read_wav(p)
		if not bool(piece["ok"]):
			out["why"] = String(piece["why"])
			return out
		if rate == 0:
			rate = int(piece["rate"])
			channels = int(piece["channels"])
			bits = int(piece["bits"])
		elif rate != int(piece["rate"]) or channels != int(piece["channels"]) or bits != int(piece["bits"]):
			out["why"] = "the pieces do not share one sound format"
			return out
		data.append_array(piece["data"])
	if rate <= 0 or channels <= 0 or bits <= 0:
		out["why"] = "the pieces have no usable sound format"
		return out
	if not write_wav(out_path, data, rate, channels, bits):
		out["why"] = "could not write " + out_path
		return out
	out["ok"] = true
	out["bytes"] = data.size()
	out["seconds"] = float(data.size()) / float(maxi(rate * channels * (bits / 8), 1))
	return out

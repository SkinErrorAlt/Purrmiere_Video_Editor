extends RefCounted

const MAX_FRAMES := 600
const MAX_SIDE := 4096
const MIN_DELAY := 0.02
const SLOW_DELAY := 0.1
const LZW_MAX := 4096


static func is_gif(bytes: PackedByteArray) -> bool:
	if bytes.size() < 13:
		return false
	return bytes[0] == 0x47 and bytes[1] == 0x49 and bytes[2] == 0x46 and bytes[3] == 0x38 and (bytes[4] == 0x37 or bytes[4] == 0x39) and bytes[5] == 0x61


static func read_file(path: String, max_frames: int = MAX_FRAMES) -> Dictionary:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	return decode(bytes, max_frames)


static func _u16(b: PackedByteArray, at: int) -> int:
	return int(b[at]) | (int(b[at + 1]) << 8)


static func _palette(b: PackedByteArray, at: int, count: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(256 * 4)
	for i: int in count:
		var p: int = at + i * 3
		if p + 2 >= b.size():
			break
		out[i * 4] = b[p]
		out[i * 4 + 1] = b[p + 1]
		out[i * 4 + 2] = b[p + 2]
		out[i * 4 + 3] = 255
	return out


static func _blocks(b: PackedByteArray, at: int) -> Dictionary:
	var data: PackedByteArray = PackedByteArray()
	var p: int = at
	while p < b.size():
		var n: int = int(b[p])
		p += 1
		if n == 0:
			break
		if p + n > b.size():
			data.append_array(b.slice(p, b.size()))
			p = b.size()
			break
		data.append_array(b.slice(p, p + n))
		p += n
	return {"data": data, "next": p}


static func _skip_blocks(b: PackedByteArray, at: int) -> int:
	var p: int = at
	while p < b.size():
		var n: int = int(b[p])
		p += 1
		if n == 0:
			break
		p += n
	return p


static func lzw(data: PackedByteArray, min_size: int, pixel_count: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(pixel_count)
	if min_size < 2 or min_size > 11:
		return out
	var clear: int = 1 << min_size
	var stop: int = clear + 1
	var prefix: PackedInt32Array = PackedInt32Array()
	prefix.resize(LZW_MAX)
	var suffix: PackedByteArray = PackedByteArray()
	suffix.resize(LZW_MAX)
	var first: PackedByteArray = PackedByteArray()
	first.resize(LZW_MAX)
	var length: PackedInt32Array = PackedInt32Array()
	length.resize(LZW_MAX)
	for i: int in clear:
		prefix[i] = -1
		suffix[i] = i
		first[i] = i
		length[i] = 1
	var size: int = min_size + 1
	var mask: int = (1 << size) - 1
	var next_code: int = clear + 2
	var old: int = -1
	var bits: int = 0
	var acc: int = 0
	var pos: int = 0
	var written: int = 0
	var n: int = data.size()
	while written < pixel_count:
		while bits < size and pos < n:
			acc |= int(data[pos]) << bits
			bits += 8
			pos += 1
		if bits < size:
			break
		var code: int = acc & mask
		acc >>= size
		bits -= size
		if code == clear:
			size = min_size + 1
			mask = (1 << size) - 1
			next_code = clear + 2
			old = -1
			continue
		if code == stop:
			break
		var emit: int = code
		var lead: int = 0
		if code < next_code:
			lead = first[code]
		elif old >= 0 and code == next_code:
			lead = first[old]
			emit = old
		else:
			break
		var len_out: int = length[emit] + (1 if emit != code else 0)
		var end: int = mini(written + len_out, pixel_count)
		var w: int = written + length[emit] - 1
		if emit != code:
			if written + length[emit] < pixel_count:
				out[written + length[emit]] = lead
		var walk: int = emit
		while walk >= 0:
			if w < pixel_count:
				out[w] = suffix[walk]
			w -= 1
			walk = prefix[walk]
		written = end
		if old >= 0 and next_code < LZW_MAX:
			prefix[next_code] = old
			suffix[next_code] = lead
			first[next_code] = first[old]
			length[next_code] = length[old] + 1
			next_code += 1
			if next_code > mask and size < 12:
				size += 1
				mask = (1 << size) - 1
		old = code
	return out


static func _deinterlace(idx: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(idx.size())
	var row: int = 0
	var starts: PackedInt32Array = PackedInt32Array([0, 4, 2, 1])
	var steps: PackedInt32Array = PackedInt32Array([8, 8, 4, 2])
	for pass_i: int in 4:
		var y: int = starts[pass_i]
		while y < h:
			var src: int = row * w
			var dst: int = y * w
			for x: int in w:
				out[dst + x] = idx[src + x]
			row += 1
			y += steps[pass_i]
	return out


static func decode(b: PackedByteArray, max_frames: int = MAX_FRAMES) -> Dictionary:
	var result: Dictionary = {"ok": false, "frames": [], "delays": PackedFloat64Array(), "size": Vector2i.ZERO, "loops": 0}
	if not is_gif(b):
		return result
	var sw: int = _u16(b, 6)
	var sh: int = _u16(b, 8)
	if sw <= 0 or sh <= 0 or sw > MAX_SIDE or sh > MAX_SIDE:
		return result
	var flags: int = int(b[10])
	var p: int = 13
	var global: PackedByteArray = PackedByteArray()
	if flags & 0x80:
		var gcount: int = 1 << ((flags & 7) + 1)
		global = _palette(b, p, gcount)
		p += gcount * 3
	var canvas: PackedByteArray = PackedByteArray()
	canvas.resize(sw * sh * 4)
	var frames: Array[Image] = []
	var delays: PackedFloat64Array = PackedFloat64Array()
	var disposal: int = 0
	var delay: float = 0.0
	var trans: int = -1
	while p < b.size() and frames.size() < max_frames:
		var tag: int = int(b[p])
		p += 1
		if tag == 0x3B:
			break
		if tag == 0x21:
			if p >= b.size():
				break
			var label: int = int(b[p])
			p += 1
			if label == 0xF9 and p + 5 < b.size() and int(b[p]) >= 4:
				var packed: int = int(b[p + 1])
				disposal = (packed >> 2) & 7
				delay = float(_u16(b, p + 2)) / 100.0
				trans = int(b[p + 4]) if packed & 1 else -1
				p = _skip_blocks(b, p)
			elif label == 0xFF and p + 12 < b.size() and int(b[p]) == 11:
				var app: String = b.slice(p + 1, p + 12).get_string_from_ascii()
				var sub: int = p + 12
				if app == "NETSCAPE2.0" and sub + 3 < b.size() and int(b[sub]) >= 3 and int(b[sub + 1]) == 1:
					result["loops"] = _u16(b, sub + 2)
				p = _skip_blocks(b, p + 12)
			else:
				p = _skip_blocks(b, p)
			continue
		if tag != 0x2C or p + 9 > b.size():
			break
		var fx: int = _u16(b, p)
		var fy: int = _u16(b, p + 2)
		var fw: int = _u16(b, p + 4)
		var fh: int = _u16(b, p + 6)
		var fflags: int = int(b[p + 8])
		p += 9
		var table: PackedByteArray = global
		if fflags & 0x80:
			var lcount: int = 1 << ((fflags & 7) + 1)
			table = _palette(b, p, lcount)
			p += lcount * 3
		if table.is_empty():
			table = PackedByteArray()
			table.resize(256 * 4)
		if p >= b.size():
			break
		var min_size: int = int(b[p])
		p += 1
		var got: Dictionary = _blocks(b, p)
		p = int(got["next"])
		if fw <= 0 or fh <= 0:
			continue
		var idx: PackedByteArray = lzw(got["data"], min_size, fw * fh)
		if fflags & 0x40:
			idx = _deinterlace(idx, fw, fh)
		var before: PackedByteArray = canvas.duplicate() if disposal == 3 else PackedByteArray()
		var x1: int = mini(fx + fw, sw)
		var y1: int = mini(fy + fh, sh)
		for y: int in range(fy, y1):
			var src_row: int = (y - fy) * fw
			var dst_row: int = y * sw
			for x: int in range(fx, x1):
				var ci: int = int(idx[src_row + x - fx])
				if ci == trans:
					continue
				var d: int = (dst_row + x) * 4
				var s: int = ci * 4
				canvas[d] = table[s]
				canvas[d + 1] = table[s + 1]
				canvas[d + 2] = table[s + 2]
				canvas[d + 3] = 255
		frames.append(Image.create_from_data(sw, sh, false, Image.FORMAT_RGBA8, canvas.duplicate()))
		delays.append(delay if delay >= MIN_DELAY else SLOW_DELAY)
		if disposal == 2:
			for y2: int in range(fy, y1):
				for x2: int in range(fx, x1):
					var d2: int = (y2 * sw + x2) * 4
					canvas[d2] = 0
					canvas[d2 + 1] = 0
					canvas[d2 + 2] = 0
					canvas[d2 + 3] = 0
		elif disposal == 3 and not before.is_empty():
			canvas = before
		disposal = 0
		delay = 0.0
		trans = -1
	result["frames"] = frames
	result["delays"] = delays
	result["size"] = Vector2i(sw, sh)
	result["ok"] = not frames.is_empty()
	return result

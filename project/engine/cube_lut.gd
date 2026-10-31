extends RefCounted

const RESAMPLE_SIZE := 33
const MAX_SIZE := 129


static func is_cube_path(path: String) -> bool:
	return path.get_extension().to_lower() == "cube"


static func parse(text: String) -> Dictionary:
	var size3: int = 0
	var size1: int = 0
	var dmin: Vector3 = Vector3.ZERO
	var dmax: Vector3 = Vector3.ONE
	var values: PackedFloat32Array = PackedFloat32Array()
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts: PackedStringArray = line.replace("\t", " ").split(" ", false)
		var head: String = parts[0].to_upper()
		if head == "TITLE":
			continue
		if head == "LUT_3D_SIZE" and parts.size() >= 2:
			size3 = int(parts[1])
			continue
		if head == "LUT_1D_SIZE" and parts.size() >= 2:
			size1 = int(parts[1])
			continue
		if head == "DOMAIN_MIN" and parts.size() >= 4:
			dmin = Vector3(float(parts[1]), float(parts[2]), float(parts[3]))
			continue
		if head == "DOMAIN_MAX" and parts.size() >= 4:
			dmax = Vector3(float(parts[1]), float(parts[2]), float(parts[3]))
			continue
		if head.begins_with("LUT_") or head.begins_with("DOMAIN_"):
			continue
		if parts.size() >= 3 and parts[0].is_valid_float() and parts[1].is_valid_float() and parts[2].is_valid_float():
			values.append(float(parts[0]))
			values.append(float(parts[1]))
			values.append(float(parts[2]))
	return {"size3": size3, "size1": size1, "min": dmin, "max": dmax, "values": values}


static func _fetch3(values: PackedFloat32Array, n: int, r: int, g: int, b: int) -> Vector3:
	var i: int = (clampi(r, 0, n - 1) + clampi(g, 0, n - 1) * n + clampi(b, 0, n - 1) * n * n) * 3
	return Vector3(values[i], values[i + 1], values[i + 2])


static func _sample3(values: PackedFloat32Array, n: int, c: Vector3) -> Vector3:
	var p: Vector3 = c.clamp(Vector3.ZERO, Vector3.ONE) * float(n - 1)
	var i0: Vector3i = Vector3i(int(floor(p.x)), int(floor(p.y)), int(floor(p.z)))
	var f: Vector3 = p - Vector3(i0)
	var c000: Vector3 = _fetch3(values, n, i0.x, i0.y, i0.z)
	var c100: Vector3 = _fetch3(values, n, i0.x + 1, i0.y, i0.z)
	var c010: Vector3 = _fetch3(values, n, i0.x, i0.y + 1, i0.z)
	var c110: Vector3 = _fetch3(values, n, i0.x + 1, i0.y + 1, i0.z)
	var c001: Vector3 = _fetch3(values, n, i0.x, i0.y, i0.z + 1)
	var c101: Vector3 = _fetch3(values, n, i0.x + 1, i0.y, i0.z + 1)
	var c011: Vector3 = _fetch3(values, n, i0.x, i0.y + 1, i0.z + 1)
	var c111: Vector3 = _fetch3(values, n, i0.x + 1, i0.y + 1, i0.z + 1)
	var x00: Vector3 = c000.lerp(c100, f.x)
	var x10: Vector3 = c010.lerp(c110, f.x)
	var x01: Vector3 = c001.lerp(c101, f.x)
	var x11: Vector3 = c011.lerp(c111, f.x)
	return x00.lerp(x10, f.y).lerp(x01.lerp(x11, f.y), f.z)


static func _sample1(values: PackedFloat32Array, n: int, x: float, channel: int) -> float:
	var p: float = clampf(x, 0.0, 1.0) * float(n - 1)
	var i0: int = int(floor(p))
	var i1: int = mini(i0 + 1, n - 1)
	var f: float = p - float(i0)
	return lerpf(values[i0 * 3 + channel], values[i1 * 3 + channel], f)


static func to_cube(parsed: Dictionary) -> Dictionary:
	var values: PackedFloat32Array = parsed["values"]
	var n3: int = int(parsed["size3"])
	var n1: int = int(parsed["size1"])
	var dmin: Vector3 = parsed["min"]
	var dmax: Vector3 = parsed["max"]
	var span: Vector3 = Vector3(maxf(dmax.x - dmin.x, 0.000001), maxf(dmax.y - dmin.y, 0.000001), maxf(dmax.z - dmin.z, 0.000001))
	var unit_domain: bool = dmin.is_equal_approx(Vector3.ZERO) and dmax.is_equal_approx(Vector3.ONE)
	if n3 >= 2 and n3 <= MAX_SIZE and values.size() >= n3 * n3 * n3 * 3:
		if unit_domain:
			return {"size": n3, "values": values.slice(0, n3 * n3 * n3 * 3)}
		var out3: PackedFloat32Array = PackedFloat32Array()
		out3.resize(RESAMPLE_SIZE * RESAMPLE_SIZE * RESAMPLE_SIZE * 3)
		var k3: int = 0
		for b: int in RESAMPLE_SIZE:
			for g: int in RESAMPLE_SIZE:
				for r: int in RESAMPLE_SIZE:
					var c: Vector3 = Vector3(r, g, b) / float(RESAMPLE_SIZE - 1)
					var v: Vector3 = _sample3(values, n3, (c - dmin) / span)
					out3[k3] = v.x
					out3[k3 + 1] = v.y
					out3[k3 + 2] = v.z
					k3 += 3
		return {"size": RESAMPLE_SIZE, "values": out3}
	if n1 >= 2 and values.size() >= n1 * 3:
		var out1: PackedFloat32Array = PackedFloat32Array()
		out1.resize(RESAMPLE_SIZE * RESAMPLE_SIZE * RESAMPLE_SIZE * 3)
		var k1: int = 0
		for b: int in RESAMPLE_SIZE:
			for g: int in RESAMPLE_SIZE:
				for r: int in RESAMPLE_SIZE:
					var c1: Vector3 = (Vector3(r, g, b) / float(RESAMPLE_SIZE - 1) - dmin) / span
					out1[k1] = _sample1(values, n1, c1.x, 0)
					out1[k1 + 1] = _sample1(values, n1, c1.y, 1)
					out1[k1 + 2] = _sample1(values, n1, c1.z, 2)
					k1 += 3
		return {"size": RESAMPLE_SIZE, "values": out1}
	return {}


static func strip_image(cube: Dictionary) -> Image:
	if cube.is_empty():
		return null
	var n: int = int(cube["size"])
	var values: PackedFloat32Array = cube["values"]
	var data: PackedFloat32Array = PackedFloat32Array()
	data.resize(n * n * n * 3)
	for b: int in n:
		for g: int in n:
			for r: int in n:
				var src: int = (r + g * n + b * n * n) * 3
				var dst: int = ((g * n * n) + (b * n) + r) * 3
				data[dst] = values[src]
				data[dst + 1] = values[src + 1]
				data[dst + 2] = values[src + 2]
	return Image.create_from_data(n * n, n, false, Image.FORMAT_RGBF, data.to_byte_array())


static func load_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var img: Image = strip_image(to_cube(parse(FileAccess.get_file_as_string(path))))
	if img == null:
		return null
	return ImageTexture.create_from_image(img)

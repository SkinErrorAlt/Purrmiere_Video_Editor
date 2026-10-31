extends RefCounted

const HUE_BINS := 12
const SAMPLE_W := 24
const SAMPLE_H := 14
const GREY_SAT := 0.2
const DARK_V := 0.12
const HUE_NAMES: PackedStringArray = ["red", "orange", "yellow", "yellow green", "green", "green", "cyan", "blue", "blue", "purple", "magenta", "pink"]
const SORT_BANDS := 18


static func from_image(src: Image) -> Dictionary:
	if src == null or src.is_empty():
		return {}
	var img: Image = src.duplicate()
	if img.is_compressed():
		if img.decompress() != OK:
			return {}
	img.convert(Image.FORMAT_RGB8)
	img.resize(SAMPLE_W, SAMPLE_H, Image.INTERPOLATE_TRILINEAR)
	var weight: PackedFloat32Array = PackedFloat32Array()
	weight.resize(HUE_BINS + 1)
	var sums: Array[Color] = []
	for i: int in HUE_BINS + 1:
		sums.append(Color(0, 0, 0, 0))
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			var bin: int = HUE_BINS
			var w: float = 1.0
			if c.s >= GREY_SAT and c.v >= DARK_V:
				bin = int(floor(c.h * float(HUE_BINS))) % HUE_BINS
				w = c.s * c.v + 0.05
			weight[bin] += w
			var acc: Color = sums[bin]
			sums[bin] = Color(acc.r + c.r * w, acc.g + c.g * w, acc.b + c.b * w, 0.0)
	var order: Array[int] = []
	for i: int in HUE_BINS + 1:
		if weight[i] > 0.0:
			order.append(i)
	if order.is_empty():
		return {}
	order.sort_custom(func(a: int, b: int) -> bool: return weight[a] > weight[b])
	var best_chroma: int = -1
	for i: int in order:
		if i < HUE_BINS:
			best_chroma = i
			break
	var main_bin: int = order[0]
	if main_bin == HUE_BINS and best_chroma >= 0 and weight[HUE_BINS] < weight[best_chroma] * 2.2:
		main_bin = best_chroma
	var palette: Array = [_mean(sums[main_bin], weight[main_bin])]
	for i: int in order:
		if i == main_bin:
			continue
		palette.append(_mean(sums[i], weight[i]))
		if palette.size() >= 3:
			break
	var main: Color = _as_colour(palette[0])
	return {"main": palette[0], "palette": palette, "grey": main_bin == HUE_BINS, "hue": main.h, "value": main.v}


static func _mean(acc: Color, w: float) -> Array:
	if w <= 0.0:
		return [0.0, 0.0, 0.0]
	return [snappedf(acc.r / w, 0.001), snappedf(acc.g / w, 0.001), snappedf(acc.b / w, 0.001)]


static func _as_colour(v: Variant) -> Color:
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return Color(0.5, 0.5, 0.5)


static func main_colour(sw: Dictionary) -> Color:
	return _as_colour(sw.get("main", [0.5, 0.5, 0.5]))


static func palette(sw: Dictionary) -> Array[Color]:
	var out: Array[Color] = []
	for v: Variant in sw.get("palette", []):
		out.append(_as_colour(v))
	if out.is_empty():
		out.append(main_colour(sw))
	return out


static func is_grey(sw: Dictionary) -> bool:
	return bool(sw.get("grey", false))


static func hue_word(sw: Dictionary) -> String:
	var c: Color = main_colour(sw)
	if is_grey(sw):
		if c.v < 0.2:
			return "black"
		if c.v > 0.8:
			return "white"
		return "grey"
	var i: int = int(floor(wrapf(c.h + 0.5 / float(HUE_BINS), 0.0, 1.0) * float(HUE_BINS))) % HUE_BINS
	return HUE_NAMES[i]


static func sort_key(sw: Dictionary) -> Vector3:
	if sw.is_empty():
		return Vector3(3.0, 0.0, 0.0)
	var c: Color = main_colour(sw)
	if is_grey(sw):
		return Vector3(1.0, c.v, 0.0)
	var h: float = c.h
	if h > 1.0 - 0.5 / float(SORT_BANDS):
		h -= 1.0
	var band: int = int(floor((h + 0.5 / float(SORT_BANDS)) * float(SORT_BANDS)))
	var v: float = c.v if band % 2 == 0 else 1.0 - c.v
	return Vector3(0.0, float(band), v)


static func less(a: Vector3, b: Vector3) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z

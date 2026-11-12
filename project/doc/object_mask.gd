extends RefCounted

const KIND := "object"
const MATTE_SIDE := 128
const EDIT_SIDE := 256
const GONE := "gone"
const CHECK := "check"
const GONE_AREA := 0.0008
const CHECK_SCORE := 0.55
const CHECK_JUMP := 2.2


static func make(id: String, label: String = "") -> Dictionary:
	var m: Dictionary = {"id": id, "kind": KIND, "mode": "add", "rotation": 0.0, "feather": 0.0, "expand": 0.0, "opacity": 1.0, "invert": false, "enabled": true, "side": MATTE_SIDE, "model": "", "edge_contrast": 1.6, "edge_shift": 0.0, "cuts": true, "mattes": {}, "clicks": {}, "flags": {}, "region": [0.0, 0.0, 1.0, 1.0]}
	if not label.is_empty():
		m["label"] = label
	return m


static func is_object(m: Dictionary) -> bool:
	return str(m.get("kind", "")) == KIND


static func region_of(m: Dictionary) -> Rect2:
	var r: Variant = m.get("region", null)
	if r is Array and (r as Array).size() >= 4:
		var a: Array = r
		return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return Rect2(0.0, 0.0, 1.0, 1.0)


static func set_region(m: Dictionary, r: Rect2) -> void:
	m["region"] = [r.position.x, r.position.y, r.size.x, r.size.y]


static func key_frames(m: Dictionary) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var mattes: Dictionary = m.get("mattes", {})
	for key: Variant in mattes.keys():
		out.append(int(String(key)))
	out.sort()
	return out


static func nearest_key(m: Dictionary, frame: int) -> int:
	var keys: PackedInt32Array = key_frames(m)
	if keys.is_empty():
		return -1
	var best: int = keys[0]
	for k: int in keys:
		if absi(k - frame) < absi(best - frame):
			best = k
	return best


static func has_matte(m: Dictionary, frame: int) -> bool:
	var mattes: Dictionary = m.get("mattes", {})
	return mattes.has(str(frame))


static func put_matte(m: Dictionary, frame: int, matte: Image) -> bool:
	if matte == null:
		return false
	var png: PackedByteArray = matte.save_png_to_buffer()
	if png.is_empty():
		return false
	var mattes: Dictionary = m.get("mattes", {})
	mattes[str(frame)] = Marshalls.raw_to_base64(png)
	m["mattes"] = mattes
	m["side"] = matte.get_width()
	return true


static func drop_matte(m: Dictionary, frame: int) -> void:
	var mattes: Dictionary = m.get("mattes", {})
	mattes.erase(str(frame))
	m["mattes"] = mattes


static func clear_mattes(m: Dictionary) -> void:
	m["mattes"] = {}


static func matte_at(m: Dictionary, frame: int) -> Image:
	var mattes: Dictionary = m.get("mattes", {})
	var text: String = String(mattes.get(str(frame), ""))
	if text.is_empty():
		var near: int = nearest_key(m, frame)
		if near < 0:
			return null
		text = String(mattes.get(str(near), ""))
	if text.is_empty():
		return null
	var png: PackedByteArray = Marshalls.base64_to_raw(text)
	if png.is_empty():
		return null
	var img: Image = Image.new()
	if img.load_png_from_buffer(png) != OK:
		return null
	return img


static func put_flag(m: Dictionary, frame: int, kind: String) -> void:
	var flags: Dictionary = m.get("flags", {})
	if kind.is_empty():
		flags.erase(str(frame))
	else:
		flags[str(frame)] = kind
	m["flags"] = flags


static func flag_at(m: Dictionary, frame: int) -> String:
	return str((m.get("flags", {}) as Dictionary).get(str(frame), ""))


static func flagged(m: Dictionary, kind: String = "") -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for k: Variant in (m.get("flags", {}) as Dictionary).keys():
		if kind.is_empty() or str((m.get("flags", {}) as Dictionary)[k]) == kind:
			out.append(int(String(k)))
	out.sort()
	return out


static func clear_flags(m: Dictionary, from: int = -1, to: int = -1) -> void:
	if from < 0 and to < 0:
		m["flags"] = {}
		return
	var flags: Dictionary = m.get("flags", {})
	for k: Variant in flags.keys():
		var f: int = int(String(k))
		if f >= mini(from, to) and f <= maxi(from, to):
			flags.erase(k)
	m["flags"] = flags


static func judge(area: float, score: float, last_area: float) -> String:
	if area <= GONE_AREA:
		return GONE
	if score < CHECK_SCORE:
		return CHECK
	if last_area > GONE_AREA:
		var jump: float = maxf(area, last_area) / maxf(minf(area, last_area), 0.00001)
		if jump >= CHECK_JUMP:
			return CHECK
	return ""


static func put_clicks(m: Dictionary, frame: int, points: Array, labels: Array, box: Rect2) -> void:
	var clicks: Dictionary = m.get("clicks", {})
	var flat: Array = []
	for p: Variant in points:
		var at: Vector2 = p
		flat.append(at.x)
		flat.append(at.y)
	var marks: Array = []
	for l: Variant in labels:
		marks.append(int(l))
	clicks[str(frame)] = {"points": flat, "labels": marks, "box": [box.position.x, box.position.y, box.size.x, box.size.y]}
	m["clicks"] = clicks


static func clicks_at(m: Dictionary, frame: int) -> Dictionary:
	var clicks: Dictionary = m.get("clicks", {})
	var one: Dictionary = clicks.get(str(frame), {})
	var points: Array = []
	var flat: Array = one.get("points", [])
	for i: int in int(flat.size() / 2):
		points.append(Vector2(float(flat[i * 2]), float(flat[i * 2 + 1])))
	var box_flat: Array = one.get("box", [0.0, 0.0, 0.0, 0.0])
	var box: Rect2 = Rect2(0, 0, 0, 0)
	if box_flat.size() >= 4:
		box = Rect2(float(box_flat[0]), float(box_flat[1]), float(box_flat[2]), float(box_flat[3]))
	return {"points": points, "labels": one.get("labels", []), "box": box}


static func has_edit(m: Dictionary, frame: int) -> bool:
	var edits: Dictionary = m.get("edits", {})
	return edits.has(str(frame))


static func set_holds(m: Dictionary, on: bool) -> void:
	m["edit_holds"] = on


static func holds_on(m: Dictionary) -> bool:
	return bool(m.get("edit_holds", true))


static func edited_frames(m: Dictionary) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for k: Variant in (m.get("edits", {}) as Dictionary).keys():
		out.append(int(String(k)))
	out.sort()
	return out


static func edit_stamp(m: Dictionary, frame: int) -> int:
	var holder: int = edit_holder(m, frame)
	if holder < 0:
		return 0
	return String((m.get("edits", {}) as Dictionary).get(str(holder), "")).hash()


static func blank_edit(side: int = EDIT_SIDE) -> Image:
	var img: Image = Image.create(side, side, false, Image.FORMAT_RG8)
	img.fill(Color(0.0, 0.0, 0.0, 1.0))
	return img


static func edit_bounds(edit: Image) -> Rect2i:
	if edit == null or edit.get_format() != Image.FORMAT_RG8:
		return Rect2i()
	var side: int = edit.get_width()
	var b: PackedByteArray = edit.get_data()
	if b.size() < side * side * 2:
		return Rect2i()
	var x0: int = side
	var y0: int = side
	var x1: int = -1
	var y1: int = -1
	for y: int in side:
		var row: int = y * side
		for x: int in side:
			var i: int = (row + x) * 2
			if b[i] == 0 and b[i + 1] == 0:
				continue
			if x < x0:
				x0 = x
			if x > x1:
				x1 = x
			if y < y0:
				y0 = y
			y1 = y
	if x1 < 0:
		return Rect2i()
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


static func edit_box(m: Dictionary, frame: int) -> Rect2i:
	var boxes: Dictionary = m.get("edit_boxes", {})
	var holder: int = edit_holder(m, frame)
	var held: Variant = boxes.get(str(holder), null) if holder >= 0 else null
	if held is Array and (held as Array).size() == 4:
		var a: Array = held
		return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))
	var side: int = maxi(int(m.get("edit_side", EDIT_SIDE)), 1)
	return Rect2i(0, 0, side, side)


static func put_edit(m: Dictionary, frame: int, edit: Image, box: Rect2i = Rect2i()) -> bool:
	if edit == null:
		return false
	var png: PackedByteArray = edit.save_png_to_buffer()
	if png.is_empty():
		return false
	var edits: Dictionary = m.get("edits", {})
	edits[str(frame)] = Marshalls.raw_to_base64(png)
	m["edits"] = edits
	m["edit_side"] = edit.get_width()
	var kept: Rect2i = box if box.size.x > 0 and box.size.y > 0 else edit_bounds(edit)
	var boxes: Dictionary = m.get("edit_boxes", {})
	if kept.size.x > 0 and kept.size.y > 0:
		boxes[str(frame)] = [kept.position.x, kept.position.y, kept.size.x, kept.size.y]
	else:
		boxes.erase(str(frame))
	m["edit_boxes"] = boxes
	return true


static func drop_edit(m: Dictionary, frame: int) -> void:
	var edits: Dictionary = m.get("edits", {})
	edits.erase(str(frame))
	m["edits"] = edits
	var boxes: Dictionary = m.get("edit_boxes", {})
	boxes.erase(str(frame))
	m["edit_boxes"] = boxes


static func clear_edits(m: Dictionary) -> void:
	m["edits"] = {}
	m["edit_boxes"] = {}
	m.erase("edit_side")


static func edit_holder(m: Dictionary, frame: int) -> int:
	var edits: Dictionary = m.get("edits", {})
	if edits.has(str(frame)):
		return frame
	if not bool(m.get("edit_holds", true)):
		return -1
	var best: int = -1
	for k: Variant in edits.keys():
		var at: int = int(String(k))
		if at <= frame and at > best:
			best = at
	return best


static func edit_held(m: Dictionary, frame: int) -> bool:
	var at: int = edit_holder(m, frame)
	return at >= 0 and at != frame


static func edit_at(m: Dictionary, frame: int) -> Image:
	var holder: int = edit_holder(m, frame)
	if holder < 0:
		return null
	var text: String = String((m.get("edits", {}) as Dictionary).get(str(holder), ""))
	if text.is_empty():
		return null
	var png: PackedByteArray = Marshalls.base64_to_raw(text)
	if png.is_empty():
		return null
	var img: Image = Image.new()
	if img.load_png_from_buffer(png) != OK:
		return null
	return img


static func _sized(img: Image, side: int, format: int) -> Image:
	var out: Image = img
	if out.get_format() != format:
		out = out.duplicate()
		out.convert(format)
	if out.get_width() != side or out.get_height() != side:
		if out == img:
			out = out.duplicate()
		out.resize(side, side, Image.INTERPOLATE_BILINEAR)
	return out


static func apply_edit(matte: Image, edit: Image, box: Rect2i = Rect2i()) -> Image:
	if matte == null:
		return null
	if edit == null:
		return matte
	var side: int = maxi(matte.get_width(), edit.get_width())
	var base: Image = _sized(matte, side, Image.FORMAT_R8)
	var layer: Image = _sized(edit, side, Image.FORMAT_RG8)
	var mb: PackedByteArray = base.get_data()
	var eb: PackedByteArray = layer.get_data()
	var count: int = side * side
	if mb.size() < count or eb.size() < count * 2:
		return matte
	var grow: float = float(side) / float(maxi(edit.get_width(), 1))
	var area: Rect2i = Rect2i(0, 0, side, side)
	if box.size.x > 0 and box.size.y > 0:
		area = Rect2i(int(floor(float(box.position.x) * grow)) - 1, int(floor(float(box.position.y) * grow)) - 1, int(ceil(float(box.size.x) * grow)) + 2, int(ceil(float(box.size.y) * grow)) + 2)
	var y0: int = maxi(area.position.y, 0)
	var y1: int = mini(area.end.y, side)
	var x0: int = maxi(area.position.x, 0)
	var x1: int = mini(area.end.x, side)
	for y: int in range(y0, y1):
		var row: int = y * side
		for x: int in range(x0, x1):
			var i: int = row + x
			var up: int = eb[i * 2]
			var down: int = eb[i * 2 + 1]
			if up == 0 and down == 0:
				continue
			var v: int = mb[i]
			if up > v:
				v = up
			mb[i] = v - down if v > down else 0
	return Image.create_from_data(side, side, false, Image.FORMAT_R8, mb)


static func matte_with_edits(m: Dictionary, frame: int) -> Image:
	var edit: Image = edit_at(m, frame)
	return apply_edit(matte_at(m, frame), edit, edit_box(m, frame) if edit != null else Rect2i())


static func is_tracked(m: Dictionary) -> bool:
	return not (m.get("clicks", {}) as Dictionary).is_empty()


static func stroke_into_edit(edit: Image, stroke: Image, wipe: bool, where: Rect2i) -> Image:
	if edit == null or stroke == null:
		return edit
	var side: int = edit.get_width()
	if stroke.get_width() != side or edit.get_format() != Image.FORMAT_RG8 or stroke.get_format() != Image.FORMAT_R8:
		return edit
	var eb: PackedByteArray = edit.get_data()
	var sb: PackedByteArray = stroke.get_data()
	if eb.size() < side * side * 2 or sb.size() < side * side:
		return edit
	var y0: int = maxi(where.position.y, 0)
	var y1: int = mini(where.end.y + 1, side)
	var x0: int = maxi(where.position.x, 0)
	var x1: int = mini(where.end.x + 1, side)
	for y: int in range(y0, y1):
		var row: int = y * side
		for x: int in range(x0, x1):
			var i: int = row + x
			var k: int = sb[i]
			if k == 0:
				continue
			var up: int = eb[i * 2]
			var down: int = eb[i * 2 + 1]
			if wipe:
				down = maxi(down, k)
				up = up - k if up > k else 0
			else:
				up = maxi(up, k)
				down = down - k if down > k else 0
			eb[i * 2] = up
			eb[i * 2 + 1] = down
	return Image.create_from_data(side, side, false, Image.FORMAT_RG8, eb)

extends RefCounted

const REGION_MAX := 8
const BORDER_PREFIX := "border"
const ZOOM_PREFIX := "border_zoom"
const INSET_PREFIX := "border_inset"
const WIN_PREFIX := "border_win"
const WIDTH_PREFIX := "label_w"
const ON_KEY := "border_on"
const SOLID_KEY := "border_solid"
const SHOW_KEY := "label_show"
const SIZE_KEY := "label_size"
const COLOUR_KEY := "label_colour"
const PLATE_KEY := "label_plate"
const STRIP_KEY := "label_tex"
const STRIP_PX_KEY := "label_px"
const STRIP_W := 384
const STRIP_H := 72
const STRIP_PAD := 6
const FONT_PX := 44
const FONT_MIN := 8
const SCAN_MAX := 160
const HOLE_ALPHA := 90
const HOLE_MIN := 0.03
const MAT := 0.11
const ZOOM_MIN := 0.1
const ZOOM_MAX := 6.0
const INSET_MIN := -0.3
const INSET_MAX := 0.45
const SIZE_MIN := 0.02
const SIZE_MAX := 0.4
const SHOW_NAMES: PackedStringArray = ["Off", "On the frame", "Under the frame"]
const CACHE_MAX := 48
const ATLAS_KEY := "border_atlas"
const CELL_PREFIX := "border_cell"
const ATLAS_CACHE_MAX := 6
const REEL_KEY := "border_reel"
const MOVING_KEY := "border_moving"
const LOOP_PREFIX := "border_loop"
const TIME_KEY := "reel_time"
const BorderReel := preload("res://doc/border_reel.gd")

static var _window_cache: Dictionary = {}
static var _path_cache: Dictionary = {}
static var _strip_cache: Dictionary = {}
static var _atlas_cache: Dictionary = {}


static func border_key(i: int) -> String:
	return BORDER_PREFIX + str(i)


static func cell_key(i: int) -> String:
	return CELL_PREFIX + str(i)


static func loop_key(i: int) -> String:
	return LOOP_PREFIX + str(i)


static func zoom_key(i: int) -> String:
	return ZOOM_PREFIX + str(i)


static func inset_key(i: int) -> String:
	return INSET_PREFIX + str(i)


static func win_key(i: int) -> String:
	return WIN_PREFIX + str(i)


static func width_key(i: int) -> String:
	return WIDTH_PREFIX + str(i)


static func default_window() -> Rect2:
	return Rect2(MAT, MAT, 1.0 - MAT * 2.0, 1.0 - MAT * 2.0)


static func blank() -> Dictionary:
	return {"win": default_window(), "solid": true, "size": Vector2.ZERO}


static func inset_window(win: Rect2, inset: float) -> Rect2:
	var k: float = minf(win.size.x, win.size.y) * clampf(inset, -0.4, INSET_MAX)
	return Rect2(win.position.x + k, win.position.y + k, maxf(win.size.x - k * 2.0, 0.01), maxf(win.size.y - k * 2.0, 0.01))


static func hole_of(img: Image) -> Dictionary:
	var out: Dictionary = blank()
	if img == null or img.get_width() <= 0 or img.get_height() <= 0:
		return out
	out["size"] = Vector2(float(img.get_width()), float(img.get_height()))
	var small: Image = img.duplicate()
	if small.is_compressed():
		small.decompress()
	if small.get_format() != Image.FORMAT_RGBA8:
		small.convert(Image.FORMAT_RGBA8)
	var w: int = small.get_width()
	var h: int = small.get_height()
	var longest: int = maxi(w, h)
	if longest > SCAN_MAX:
		w = maxi(int(round(float(w) * float(SCAN_MAX) / float(longest))), 1)
		h = maxi(int(round(float(h) * float(SCAN_MAX) / float(longest))), 1)
		small.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var box: Rect2i = _inner_hole(small.get_data(), w, h)
	if box.size.x <= 0 or box.size.y <= 0:
		return out
	var win: Rect2 = Rect2(float(box.position.x) / float(w), float(box.position.y) / float(h), float(box.size.x) / float(w), float(box.size.y) / float(h))
	if win.size.x < HOLE_MIN or win.size.y < HOLE_MIN:
		return out
	out["win"] = win
	out["solid"] = false
	return out


static func _inner_hole(data: PackedByteArray, w: int, h: int) -> Rect2i:
	var n: int = w * h
	if data.size() < n * 4:
		return Rect2i(0, 0, 0, 0)
	var clear: PackedByteArray = PackedByteArray()
	clear.resize(n)
	var any: bool = false
	for i: int in n:
		var c: int = 1 if data[i * 4 + 3] < HOLE_ALPHA else 0
		clear[i] = c
		if c == 1:
			any = true
	if not any:
		return Rect2i(0, 0, 0, 0)
	var queue: PackedInt32Array = PackedInt32Array()
	for x: int in w:
		if clear[x] == 1:
			clear[x] = 2
			queue.append(x)
		var low: int = (h - 1) * w + x
		if clear[low] == 1:
			clear[low] = 2
			queue.append(low)
	for y: int in h:
		var left: int = y * w
		if clear[left] == 1:
			clear[left] = 2
			queue.append(left)
		var right: int = y * w + w - 1
		if clear[right] == 1:
			clear[right] = 2
			queue.append(right)
	var head: int = 0
	while head < queue.size():
		var at: int = queue[head]
		head += 1
		var ax: int = at % w
		var ay: int = at / w
		for step: int in 4:
			var bx: int = ax + (1 if step == 0 else -1 if step == 1 else 0)
			var by: int = ay + (1 if step == 2 else -1 if step == 3 else 0)
			if bx < 0 or by < 0 or bx >= w or by >= h:
				continue
			var bi: int = by * w + bx
			if clear[bi] == 1:
				clear[bi] = 2
				queue.append(bi)
	var lo: Vector2i = Vector2i(w, h)
	var hi: Vector2i = Vector2i(-1, -1)
	for y2: int in h:
		var row: int = y2 * w
		for x2: int in w:
			if clear[row + x2] != 1:
				continue
			lo.x = mini(lo.x, x2)
			lo.y = mini(lo.y, y2)
			hi.x = maxi(hi.x, x2)
			hi.y = maxi(hi.y, y2)
	if hi.x < lo.x or hi.y < lo.y:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(lo, hi - lo + Vector2i.ONE)


static func window_of(tex: Texture2D) -> Dictionary:
	if tex == null:
		return blank()
	var key: int = int(tex.get_rid().get_id())
	if _window_cache.has(key):
		return _window_cache[key]
	var img: Image = tex.get_image()
	var out: Dictionary = hole_of(img)
	_smooth(tex, img)
	if _window_cache.size() > CACHE_MAX:
		_window_cache.clear()
	_window_cache[key] = out
	return out


static func window_for_path(path: String) -> Dictionary:
	var trimmed: String = path.strip_edges()
	if trimmed.is_empty():
		return blank()
	if _path_cache.has(trimmed):
		return _path_cache[trimmed]
	var img: Image = Image.new()
	var real: String = ProjectSettings.globalize_path(trimmed) if trimmed.begins_with("res://") or trimmed.begins_with("user://") else trimmed
	var out: Dictionary = blank()
	if BorderReel.is_moving(real):
		var first: Texture2D = BorderReel.poster(real)
		if first != null:
			out = hole_of(first.get_image())
	elif FileAccess.file_exists(real) and img.load(real) == OK:
		out = hole_of(img)
	if _path_cache.size() > CACHE_MAX:
		_path_cache.clear()
	_path_cache[trimmed] = out
	return out


static func _smooth(tex: Texture2D, img: Image) -> void:
	if not (tex is ImageTexture) or img == null or img.has_mipmaps() or img.is_compressed():
		return
	if mini(img.get_width(), img.get_height()) < 4:
		return
	var m: Image = img.duplicate()
	m.generate_mipmaps()
	(tex as ImageTexture).set_image(m)


static func atlas_of(textures: Array) -> Dictionary:
	var parts: PackedStringArray = PackedStringArray()
	for i: int in REGION_MAX:
		var t: Variant = textures[i] if i < textures.size() else null
		parts.append(str(int((t as Texture2D).get_rid().get_id())) if t is Texture2D else "0")
	var key: String = ",".join(parts)
	if _atlas_cache.has(key):
		return _atlas_cache[key]
	var made: Dictionary = _make_atlas(textures)
	if _atlas_cache.size() >= ATLAS_CACHE_MAX:
		_atlas_cache.clear()
	_atlas_cache[key] = made
	return made


static func _make_atlas(textures: Array) -> Dictionary:
	var cells: Array[Vector4] = []
	cells.resize(REGION_MAX)
	cells.fill(Vector4.ZERO)
	var layer_of: Dictionary = {}
	var pictures: Array[Image] = []
	var full: Vector2i = Vector2i.ZERO
	for i: int in REGION_MAX:
		var t: Variant = textures[i] if i < textures.size() else null
		if not (t is Texture2D):
			continue
		var id: int = int((t as Texture2D).get_rid().get_id())
		if not layer_of.has(id):
			var flat: Image = _flat((t as Texture2D).get_image())
			if flat == null:
				continue
			layer_of[id] = pictures.size()
			pictures.append(flat)
			full = full.max(flat.get_size())
		var layer: int = int(layer_of[id])
		var pic: Image = pictures[layer]
		cells[i] = Vector4(float(pic.get_width()), float(pic.get_height()), float(layer), 0.0)
	if pictures.is_empty():
		return {"tex": null, "cells": cells}
	var layers: Array[Image] = []
	for pic2: Image in pictures:
		layers.append(_padded(pic2, full))
	var arr: Texture2DArray = Texture2DArray.new()
	if arr.create_from_images(layers) != OK:
		cells.fill(Vector4.ZERO)
		return {"tex": null, "cells": cells}
	return {"tex": arr, "cells": cells}


static func _flat(img: Image) -> Image:
	if img == null or img.get_width() <= 0 or img.get_height() <= 0:
		return null
	var out: Image = img.duplicate()
	if out.is_compressed():
		out.decompress()
	if out.has_mipmaps():
		out.clear_mipmaps()
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	return out


static func _padded(pic: Image, full: Vector2i) -> Image:
	var w: int = pic.get_width()
	var h: int = pic.get_height()
	var out: Image = pic
	if w != full.x or h != full.y:
		out = Image.create_empty(full.x, full.y, false, Image.FORMAT_RGBA8)
		out.blit_rect(pic, Rect2i(0, 0, w, h), Vector2i.ZERO)
		if full.x > w:
			var side: Image = pic.get_region(Rect2i(w - 1, 0, 1, h))
			side.resize(full.x - w, h, Image.INTERPOLATE_NEAREST)
			out.blit_rect(side, Rect2i(0, 0, full.x - w, h), Vector2i(w, 0))
		if full.y > h:
			var low: Image = out.get_region(Rect2i(0, h - 1, full.x, 1))
			low.resize(full.x, full.y - h, Image.INTERPOLATE_NEAREST)
			out.blit_rect(low, Rect2i(0, 0, full.x, full.y - h), Vector2i(0, h))
	out.generate_mipmaps()
	return out


static func names_of(crops: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for v: Variant in crops:
		if v is Dictionary:
			out.append(String((v as Dictionary).get("name", "")))
	return out


static func strip(names: PackedStringArray) -> Dictionary:
	var key: String = "\n".join(names)
	if _strip_cache.has(key):
		return _strip_cache[key]
	var made: Dictionary = _make_strip(names)
	if _strip_cache.size() > CACHE_MAX:
		_strip_cache.clear()
	_strip_cache[key] = made
	return made


static func _blank_strip() -> Dictionary:
	var widths: PackedFloat32Array = PackedFloat32Array()
	widths.resize(REGION_MAX)
	return {"tex": null, "widths": widths, "cell": Vector2(float(STRIP_W), float(STRIP_H))}


static func _make_strip(names: PackedStringArray) -> Dictionary:
	var out: Dictionary = _blank_strip()
	var font: Font = ThemeDB.get_fallback_font()
	var ts: TextServer = TextServerManager.get_primary_interface()
	if font == null or ts == null:
		return out
	var rids: Array[RID] = font.get_rids()
	if rids.is_empty():
		return out
	var rid: RID = rids[0]
	var widths: PackedFloat32Array = out["widths"]
	var plan: Array[Dictionary] = []
	for i: int in REGION_MAX:
		var text: String = (names[i] if i < names.size() else "").strip_edges()
		if text.is_empty():
			continue
		var line: Dictionary = _plan_line(ts, rid, text, i)
		if (line["glyphs"] as Array).is_empty():
			continue
		widths[i] = float(line["used"])
		plan.append(line)
	if plan.is_empty():
		return out
	var img: Image = Image.create_empty(STRIP_W, STRIP_H * REGION_MAX, false, Image.FORMAT_L8)
	img.fill(Color(0.0, 0.0, 0.0, 1.0))
	var atlases: Dictionary = {}
	for line2: Dictionary in plan:
		var fs: int = int(line2["size"])
		for g: Variant in (line2["glyphs"] as Array):
			var gd: Dictionary = g
			var ti: int = int(gd["tex"])
			if ti < 0:
				continue
			var akey: String = str(fs) + ":" + str(ti)
			if not atlases.has(akey):
				atlases[akey] = _atlas(ts, rid, fs, ti)
			var atlas: Image = atlases[akey]
			if atlas == null:
				continue
			_blit(img, atlas, gd["area"], gd["at"], int(line2["slot"]))
	out["tex"] = ImageTexture.create_from_image(img)
	return out


static func _plan_line(ts: TextServer, rid: RID, text: String, slot: int) -> Dictionary:
	var room: float = float(STRIP_W - STRIP_PAD * 2)
	var fs: int = FONT_PX
	var span: float = _advance(ts, rid, text, fs)
	if span > room and span > 0.0:
		fs = maxi(int(floor(float(fs) * room / span)), FONT_MIN)
		span = _advance(ts, rid, text, fs)
	var glyphs: Array[Dictionary] = []
	if span <= 0.0:
		return {"slot": slot, "size": fs, "used": 0.0, "glyphs": glyphs}
	var ascent: float = ts.font_get_ascent(rid, fs)
	var descent: float = ts.font_get_descent(rid, fs)
	var base_y: float = float(slot * STRIP_H) + float(STRIP_H) * 0.5 + (ascent - descent) * 0.5
	var pen: float = float(STRIP_PAD)
	for ch: String in text:
		var g: int = ts.font_get_glyph_index(rid, fs, ch.unicode_at(0), 0)
		var uv: Rect2 = ts.font_get_glyph_uv_rect(rid, Vector2i(fs, 0), g)
		var off: Vector2 = ts.font_get_glyph_offset(rid, Vector2i(fs, 0), g)
		var ti: int = ts.font_get_glyph_texture_idx(rid, Vector2i(fs, 0), g)
		if uv.size.x >= 1.0 and uv.size.y >= 1.0:
			glyphs.append({"tex": ti, "area": Rect2i(uv.position.round(), uv.size.round()), "at": Vector2i(int(round(pen + off.x)), int(round(base_y + off.y)))})
		pen += ts.font_get_glyph_advance(rid, fs, g).x
	return {"slot": slot, "size": fs, "used": clampf((pen + float(STRIP_PAD)) / float(STRIP_W), 0.0, 1.0), "glyphs": glyphs}


static func _advance(ts: TextServer, rid: RID, text: String, fs: int) -> float:
	var total: float = 0.0
	for ch: String in text:
		total += ts.font_get_glyph_advance(rid, fs, ts.font_get_glyph_index(rid, fs, ch.unicode_at(0), 0)).x
	return total


static func _atlas(ts: TextServer, rid: RID, fs: int, ti: int) -> Image:
	var img: Image = ts.font_get_texture_image(rid, Vector2i(fs, 0), ti)
	if img == null:
		return null
	if img.is_compressed():
		img = img.duplicate()
		img.decompress()
	if img.get_format() == Image.FORMAT_L8:
		return img
	return _alpha_as_l8(img)


static func _alpha_as_l8(img: Image) -> Image:
	var c: Image = img.duplicate()
	if c.get_format() != Image.FORMAT_RGBA8:
		c.convert(Image.FORMAT_RGBA8)
	var src: PackedByteArray = c.get_data()
	var n: int = c.get_width() * c.get_height()
	if src.size() < n * 4:
		return null
	var out: PackedByteArray = PackedByteArray()
	out.resize(n)
	for i: int in n:
		out[i] = src[i * 4 + 3]
	return Image.create_from_data(c.get_width(), c.get_height(), false, Image.FORMAT_L8, out)


static func _blit(dst: Image, src: Image, area: Rect2i, at: Vector2i, slot: int) -> void:
	var band: Rect2i = Rect2i(0, slot * STRIP_H, STRIP_W, STRIP_H)
	var want: Rect2i = Rect2i(at, area.size)
	var keep: Rect2i = want.intersection(band)
	if keep.size.x <= 0 or keep.size.y <= 0:
		return
	dst.blit_rect(src, Rect2i(area.position + keep.position - want.position, keep.size), keep.position)


static func number_of(v: Variant, fallback: float) -> float:
	if v is bool:
		return 1.0 if v else 0.0
	if v is float or v is int:
		return float(v)
	return fallback


static func show_of(values: Dictionary) -> int:
	return clampi(int(round(number_of(values.get(SHOW_KEY, 0.0), 0.0))), 0, SHOW_NAMES.size() - 1)


static func fill(values: Dictionary, crops: Array) -> void:
	var on: int = 0
	var solid: int = 0
	var pictures: Array = []
	var reel_of_view: Dictionary = {}
	var reel_paths: PackedStringArray = PackedStringArray()
	for i: int in REGION_MAX:
		var tex: Variant = values.get(border_key(i), null)
		var win: Rect2 = default_window()
		var reel_path: String = BorderReel.reel_path_of(tex)
		if not reel_path.is_empty():
			reel_of_view[i] = reel_path
			if not reel_paths.has(reel_path):
				reel_paths.append(reel_path)
		pictures.append(tex if tex is Texture2D and reel_path.is_empty() else null)
		if tex is Texture2D:
			var d: Dictionary = window_of(tex)
			win = d["win"]
			if bool(d["solid"]):
				solid |= 1 << i
		values[win_key(i)] = Vector4(win.position.x, win.position.y, win.size.x, win.size.y)
		values.erase(border_key(i))
	var atlas: Dictionary = atlas_of(pictures)
	var cells: Array[Vector4] = atlas["cells"]
	for i4: int in REGION_MAX:
		values[cell_key(i4)] = cells[i4]
		if cells[i4].x > 0.0:
			on |= 1 << i4
	var moving: int = _fill_reels(values, reel_of_view, reel_paths)
	on |= moving
	solid &= on
	if atlas["tex"] != null:
		values[ATLAS_KEY] = atlas["tex"]
	else:
		values.erase(ATLAS_KEY)
	values[ON_KEY] = on
	values[SOLID_KEY] = solid
	if show_of(values) <= 0:
		values.erase(STRIP_KEY)
		for i2: int in REGION_MAX:
			values[width_key(i2)] = 0.0
		return
	var made: Dictionary = strip(names_of(crops))
	if made["tex"] == null:
		values.erase(STRIP_KEY)
	else:
		values[STRIP_KEY] = made["tex"]
	values[STRIP_PX_KEY] = made["cell"]
	var widths: PackedFloat32Array = made["widths"]
	for i3: int in REGION_MAX:
		values[width_key(i3)] = float(widths[i3]) if i3 < widths.size() else 0.0


static func _fill_reels(values: Dictionary, reel_of_view: Dictionary, reel_paths: PackedStringArray) -> int:
	values[MOVING_KEY] = 0
	if reel_paths.is_empty():
		values.erase(REEL_KEY)
		return 0
	var packed: Dictionary = BorderReel.pack(reel_paths)
	if packed["tex"] == null:
		values.erase(REEL_KEY)
		return 0
	var t: float = number_of(values.get(TIME_KEY, 0.0), 0.0)
	var bases: Dictionary = packed["bases"]
	var reels: Dictionary = packed["reels"]
	var moving: int = 0
	for i: Variant in reel_of_view.keys():
		var path: String = String(reel_of_view[i])
		if not bases.has(path):
			continue
		var reel: Dictionary = reels[path]
		var loop: bool = number_of(values.get(loop_key(int(i)), true), 1.0) > 0.5
		var frame: int = BorderReel.frame_at(reel, t, loop)
		var size: Vector2i = reel["size"]
		values[cell_key(int(i))] = Vector4(float(size.x), float(size.y), float(int(bases[path]) + frame), 0.0)
		moving |= 1 << int(i)
	values[REEL_KEY] = packed["tex"]
	values[MOVING_KEY] = moving
	return moving

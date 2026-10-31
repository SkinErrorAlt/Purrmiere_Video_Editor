extends RefCounted

const BODY_FONT := "res://fonts/body.ttf"
const FONT_LIBRARY := "res://doc/font_library.gd"
const ALIGNS: PackedStringArray = ["left", "center", "right"]
const VALIGNS: PackedStringArray = ["top", "center", "bottom"]

static var _fonts: Dictionary = {}
static var _system_names: PackedStringArray = PackedStringArray()
static var font_serial: int = 0


static func title_defaults() -> Dictionary:
	return {
		"text": "Title",
		"font": "",
		"size": 72.0,
		"colour": [1.0, 1.0, 1.0, 1.0],
		"bold": false,
		"italic": false,
		"align": "center",
		"valign": "center",
		"width": 0.9,
		"line_spacing": 0.0,
		"letter_spacing": 0.0,
		"outline": 0.0,
		"outline_colour": [0.0, 0.0, 0.0, 1.0],
		"shadow_on": false,
		"shadow_colour": [0.0, 0.0, 0.0, 0.6],
		"shadow_distance": 6.0,
		"shadow_angle": 135.0,
		"shadow_softness": 8.0,
		"box_colour": [0.0, 0.0, 0.0, 0.0],
		"box_pad": 12.0,
		"box_radius": 8.0,
		"uppercase": false,
		"reveal": 1.0,
		"cursor": "",
	}


static func shape_defaults() -> Dictionary:
	return {
		"shape": "rect",
		"colour": [0.5, 0.5, 0.5, 1.0],
		"width": 1.0,
		"height": 1.0,
		"radius": 0.0,
		"border": 0.0,
		"border_colour": [0.0, 0.0, 0.0, 1.0],
	}


static func matte_defaults() -> Dictionary:
	return {"colour": [0.5, 0.5, 0.5, 1.0]}


static func defaults_for(kind: String) -> Dictionary:
	if kind == "title":
		return title_defaults()
	if kind == "shape":
		return shape_defaults()
	if kind == "generator":
		return matte_defaults()
	return {}


static func style_keys() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in title_defaults().keys():
		if String(k) != "text":
			out.append(String(k))
	return out


static func style_subset(props: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in style_keys():
		if not props.has(k):
			continue
		var v: Variant = props[k]
		if v is Dictionary:
			out[k] = (v as Dictionary).duplicate(true)
		elif v is Array:
			out[k] = (v as Array).duplicate(true)
		else:
			out[k] = v
	return out


static func full_style(media_props: Dictionary, clip_props: Dictionary) -> Dictionary:
	return style_subset(merged("title", media_props, clip_props))


static func merged(kind: String, media_props: Dictionary, clip_props: Dictionary, fallback_text: String = "") -> Dictionary:
	var out: Dictionary = defaults_for(kind)
	if kind == "title" and not fallback_text.is_empty() and not media_props.has("text") and not clip_props.has("text"):
		out["text"] = fallback_text
	for k: Variant in media_props.keys():
		out[k] = media_props[k]
	for k2: Variant in clip_props.keys():
		out[k2] = clip_props[k2]
	if kind == "title":
		_migrate_shadow(out, media_props, clip_props)
	return out


static func _num(v: Variant, fallback: float) -> float:
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("v"):
			return _num(d["v"], fallback)
		if d.has("base"):
			return _num(d["base"], fallback)
		return fallback
	if v is float or v is int:
		return float(v)
	return fallback


static func _either(key: String, media_props: Dictionary, clip_props: Dictionary) -> bool:
	return media_props.has(key) or clip_props.has(key)


static func _migrate_shadow(out: Dictionary, media_props: Dictionary, clip_props: Dictionary) -> void:
	if _either("shadow_on", media_props, clip_props):
		return
	var legacy: float = _num(clip_props.get("shadow", media_props.get("shadow", null)), 0.0)
	if legacy <= 0.0:
		return
	out["shadow_on"] = true
	if not _either("shadow_softness", media_props, clip_props):
		out["shadow_softness"] = legacy
	if _either("shadow_distance", media_props, clip_props) or _either("shadow_angle", media_props, clip_props):
		return
	var off_raw: Variant = clip_props.get("shadow_offset", media_props.get("shadow_offset", [3.0, 3.0]))
	if off_raw is Dictionary:
		off_raw = (off_raw as Dictionary).get("v", (off_raw as Dictionary).get("base", [3.0, 3.0]))
	if off_raw is Array and (off_raw as Array).size() >= 2:
		var off: Vector2 = Vector2(float(off_raw[0]), float(off_raw[1]))
		out["shadow_distance"] = off.length()
		out["shadow_angle"] = shadow_angle_of(off)


static func shadow_angle_of(off: Vector2) -> float:
	if off.length() < 0.0001:
		return 135.0
	return fposmod(rad_to_deg(atan2(off.x, -off.y)), 360.0)


static func shadow_offset(distance: float, angle_deg: float) -> Vector2:
	var a: float = deg_to_rad(angle_deg)
	return Vector2(sin(a), -cos(a)) * distance


static func spaced(base: Font, spacing_px: int) -> Font:
	if spacing_px == 0 or base == null:
		return base
	var key: String = str(base.get_instance_id()) + "|spacing|" + str(spacing_px)
	if _fonts.has(key):
		return _fonts[key]
	var v: FontVariation = FontVariation.new()
	v.base_font = base
	v.set_spacing(TextServer.SPACING_GLYPH, spacing_px)
	_fonts[key] = v
	return v


static func colour_of(v: Variant, fallback: Color = Color.WHITE) -> Color:
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
	if v is Color:
		return v
	if v is String and not String(v).is_empty():
		return Color.html(String(v))
	return fallback


static func system_fonts() -> PackedStringArray:
	if _system_names.is_empty():
		_system_names = OS.get_system_fonts()
		_system_names.sort()
	var lib: GDScript = load(FONT_LIBRARY)
	var out: PackedStringArray = lib.call("tokens") if lib != null else PackedStringArray()
	out.append_array(_system_names)
	return out


static func forget_fonts() -> void:
	_fonts.clear()
	font_serial += 1


static func styled(base: Font, bold: bool, italic: bool) -> Font:
	if not bold and not italic:
		return base
	var v: FontVariation = FontVariation.new()
	v.base_font = base
	if bold:
		v.variation_embolden = 0.8
	if italic:
		v.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.25, 1.0), Vector2.ZERO)
	return v


static func font_for(name_: String, bold: bool, italic: bool) -> Font:
	var key: String = name_ + "|" + str(bold) + "|" + str(italic)
	if _fonts.has(key):
		return _fonts[key]
	var f: Font = null
	if name_.is_empty():
		var base: FontFile = load(BODY_FONT)
		if bold or italic:
			var v: FontVariation = FontVariation.new()
			v.base_font = base
			if bold:
				v.variation_embolden = 0.8
			if italic:
				v.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.25, 1.0), Vector2.ZERO)
			f = v
		else:
			f = base
	elif name_.begins_with("Imported font: "):
		var lib: GDScript = load(FONT_LIBRARY)
		var found: String = String(lib.call("path_of", name_)) if lib != null else ""
		if not found.is_empty():
			var imported: FontFile = FontFile.new()
			if imported.load_dynamic_font(found) == OK:
				f = styled(imported, bold, italic)
		if f == null:
			f = styled(load(BODY_FONT), bold, italic)
	elif FileAccess.file_exists(name_):
		var ff: FontFile = FontFile.new()
		if ff.load_dynamic_font(name_) == OK:
			f = ff
	if f == null:
		var sf: SystemFont = SystemFont.new()
		sf.font_names = PackedStringArray([name_])
		sf.font_weight = 700 if bold else 400
		sf.font_italic = italic
		f = sf
	_fonts[key] = f
	return f


static func stamp(p: Dictionary) -> String:
	return JSON.stringify(p) + "|fonts " + str(font_serial)

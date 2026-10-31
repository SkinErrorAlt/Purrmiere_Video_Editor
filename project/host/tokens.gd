extends Node

signal tokens_changed
signal theme_changed
signal icon_scale_changed(area: String)

const LABEL_NAMES: PackedStringArray = ["Violet", "Iris", "Caribbean", "Lavender", "Cerulean", "Forest", "Rose", "Mango", "Purple", "Blue", "Teal", "Magenta", "Tan", "Green", "Brown", "Yellow"]
const LABEL_HEX: PackedStringArray = ["#8D6FBF", "#5D6ABF", "#3E9E8F", "#B08FD0", "#3F7FBF", "#4E8A4E", "#C06A8A", "#D08A3A", "#6F4FA0", "#3A5FA0", "#2F7F7F", "#B04FA0", "#A08050", "#5FA03F", "#7A5A3A", "#C0B040"]
const LABEL_SATURATION := 0.35
const DUR_FAST := 0.18
const DUR_MEDIUM := 0.22
const DUR_PAGE := 0.52
const DUR_TAB := 0.38
const DUR_TOAST := 0.32
const DUR_SWITCH := 0.3
const ICON_SCALE_MIN := 0.6
const ICON_SCALE_MAX := 1.8
const THEMES: PackedStringArray = ["quiet", "quiet_light"]
const PREF_THEME := "ui.theme"

const QUIET: Dictionary = {
	"bg_app": "#0d0e10",
	"bg_shell": "#111316",
	"bg_panel": "#17191c",
	"bg_panel_alt": "#1e2125",
	"bg_panel_high": "#26292e",
	"bg_field": "#1e2125",
	"bg_lane_video": "#131518",
	"bg_lane_audio": "#111316",
	"bg_pinned": "#15171a",
	"bg_ruler": "#17191c",
	"border": "#25282d",
	"border_soft": "#32363c",
	"border_text": "#6b7179",
	"lane_line": "#1f2226",
	"text": "#dcdfe2",
	"text_dim": "#9ba0a7",
	"text_faint": "#676c73",
	"text_bright": "#f1f2f3",
	"accent": "#f1f2f3",
	"accent_dim": "#5b6169",
	"sol": "#f1f2f3",
	"inv": "#0d0e10",
	"clip_video": "#1e2125",
	"clip_audio": "#1b1e22",
	"clip_title": "#22252a",
	"clip_nest": "#1a1d21",
	"clip_adjust": "#1c1f23",
	"clip_stripe": "#26292e",
	"key_low": "#6d86a8",
	"key_high": "#f1f2f3",
	"key_negative": "#e58fc4",
	"key_over": "#e3a860",
	"zone_over": "#7a5fc0",
}

const QUIET_LIGHT: Dictionary = {
	"bg_app": "#f5f5f4",
	"bg_shell": "#efefee",
	"bg_panel": "#ffffff",
	"bg_panel_alt": "#f4f4f3",
	"bg_panel_high": "#e7e7e5",
	"bg_field": "#f4f4f3",
	"bg_lane_video": "#f3f3f1",
	"bg_lane_audio": "#eeeeec",
	"bg_pinned": "#f1f1ef",
	"bg_ruler": "#ffffff",
	"border": "#e2e2e0",
	"border_soft": "#cfcfcc",
	"border_text": "#8a8a87",
	"lane_line": "#e6e6e4",
	"text": "#2a2c2e",
	"text_dim": "#5a5d60",
	"text_faint": "#8b8e91",
	"text_bright": "#131414",
	"accent": "#131414",
	"accent_dim": "#a3a6a9",
	"sol": "#131414",
	"inv": "#ffffff",
	"clip_video": "#f4f4f3",
	"clip_audio": "#f0f0ee",
	"clip_title": "#ececea",
	"clip_nest": "#f2f2f0",
	"clip_adjust": "#efefed",
	"clip_stripe": "#e7e7e5",
	"key_low": "#5478a4",
	"key_high": "#131414",
	"key_negative": "#c2489a",
	"key_over": "#c5822e",
	"zone_over": "#7a5bd0",
}

var c: Dictionary = {}
var s: Dictionary = {}
var labels: Array[Color] = []
var ui_scale: float = 1.0
var density: float = 1.0
var theme_id: String = "quiet"
var _fonts: Dictionary = {}
var _icon_scales: Dictionary = {}
var _prefs_bound: bool = false


func _ready() -> void:
	_build_colours()
	_build_sizes()
	_build_labels()


func is_light() -> bool:
	return theme_id == "quiet_light"


func _build_colours() -> void:
	var src: Dictionary = QUIET_LIGHT if is_light() else QUIET
	c = {}
	for k: String in src.keys():
		c[k] = Color(String(src[k]))
	var glass_base: Color = Color(0, 0, 0) if is_light() else Color(1, 1, 1)
	c["glass"] = Color(glass_base, 0.045 if is_light() else 0.055)
	c["glass_strong"] = Color(glass_base, 0.08 if is_light() else 0.09)
	c["glass_deep"] = Color(glass_base, 0.13 if is_light() else 0.14)
	c["selection_fill"] = Color(glass_base, 0.08 if is_light() else 0.1)
	c["shadow"] = Color(0, 0, 0, 0.14 if is_light() else 0.34)
	c["veil"] = Color(0, 0, 0, 0.28 if is_light() else 0.45)
	c["hatch"] = Color(glass_base, 0.06)
	c["wave"] = Color(c["text_bright"], 0.55)
	c["wave_line"] = Color(glass_base, 0.22)
	c["zone_negative"] = c["key_negative"]


func _build_sizes() -> void:
	s = {
		"font_body": 12.0,
		"font_small": 11.0,
		"font_tiny": 10.0,
		"font_meta": 10.5,
		"font_head": 14.0,
		"font_title": 19.0,
		"font_display": 28.0,
		"row_h": 24.0,
		"field_h": 24.0,
		"button_h": 26.0,
		"tab_h": 28.0,
		"tool_button": 28.0,
		"tool_icon": 18.0,
		"pad": 6.0,
		"gap": 4.0,
		"radius": 7.0,
		"radius_field": 8.0,
		"radius_menu": 9.0,
		"radius_row": 6.0,
		"radius_chip": 5.0,
		"radius_clip": 5.0,
		"radius_panel": 8.0,
		"radius_dock": 0.0,
		"header_w": 160.0,
		"header_w_min": 34.0,
		"header_w_max": 320.0,
		"track_h_video": 54.0,
		"track_h_audio": 96.0,
		"track_h_min": 22.0,
		"track_h_max": 480.0,
		"ruler_h": 24.0,
		"pinned_min": 60.0,
		"pinned_default": 180.0,
		"split": 4.0,
		"split_reach": 2.0,
		"icon": 16.0,
		"icon_small": 14.0,
		"stroke": 1.6,
		"meta_spacing": 1.4,
	}


func _build_labels() -> void:
	labels.clear()
	for hex: String in LABEL_HEX:
		var col := Color(hex)
		var hue: float = col.h
		var val: float = col.v
		labels.append(Color.from_hsv(hue, LABEL_SATURATION, val))


func _prefs() -> Node:
	var prefs: Node = get_node_or_null("/root/Prefs")
	if prefs == null or not prefs.has_method("register"):
		return null
	if not _prefs_bound:
		_prefs_bound = true
		_bind_prefs(prefs)
	return prefs


func _bind_prefs(prefs: Node) -> void:
	prefs.register("ui.scale", 1.0, {"label": "UI scale", "type": "float", "min": 0.75, "max": 2.0})
	prefs.register("ui.reduce_motion", false, {"label": "Reduce motion", "type": "bool"})
	prefs.register("ui.mono_labels", false, {"label": "Label colours as brightness steps", "type": "bool"})
	prefs.register(PREF_THEME, "quiet", {"label": "Theme", "type": "enum", "choices": Array(THEMES)})
	ui_scale = clampf(float(prefs.get_value("ui.scale")), 0.75, 2.0)
	var want: String = String(prefs.get_value(PREF_THEME))
	if want in THEMES and want != theme_id:
		theme_id = want
		_build_colours()
	if not prefs.changed.is_connected(_on_pref_changed):
		prefs.changed.connect(_on_pref_changed)


func _on_pref_changed(key: String) -> void:
	if key == "ui.scale":
		var prefs: Node = _prefs()
		ui_scale = clampf(float(prefs.get_value("ui.scale")), 0.75, 2.0)
		tokens_changed.emit()
	elif key == "ui.mono_labels":
		tokens_changed.emit()
	elif key == PREF_THEME:
		var prefs: Node = _prefs()
		var want: String = String(prefs.get_value(PREF_THEME))
		if want in THEMES and want != theme_id:
			theme_id = want
			_build_colours()
			tokens_changed.emit()
			theme_changed.emit()


func set_theme(id: String) -> void:
	if not (id in THEMES):
		return
	var prefs: Node = _prefs()
	if prefs != null:
		prefs.set_value(PREF_THEME, id)
		return
	if id != theme_id:
		theme_id = id
		_build_colours()
		tokens_changed.emit()
		theme_changed.emit()


func px(v: float) -> int:
	return int(round(v * ui_scale * density))


func fs(v: float) -> int:
	return maxi(7, int(round(v * ui_scale)))


func dur(kind: String) -> float:
	var prefs: Node = _prefs()
	if prefs != null:
		if bool(prefs.get_value("ui.reduce_motion")):
			return 0.0
	if kind == "fast":
		return DUR_FAST
	if kind == "medium":
		return DUR_MEDIUM
	if kind == "page":
		return DUR_PAGE
	if kind == "tab":
		return DUR_TAB
	if kind == "toast":
		return DUR_TOAST
	if kind == "switch":
		return DUR_SWITCH
	return DUR_MEDIUM


func ease(tw: Tween) -> Tween:
	if tw != null:
		tw.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	return tw


func glass(strength: int = 0) -> Color:
	if strength >= 2:
		return c["glass_deep"]
	if strength == 1:
		return c["glass_strong"]
	return c["glass"]


func _load_font_file(kind: String) -> Font:
	if _fonts.has("file:" + kind):
		return _fonts["file:" + kind]
	for ext: String in ["ttf", "otf", "woff2"]:
		var path: String = "res://fonts/" + kind + "." + ext
		if ResourceLoader.exists(path):
			var file_font: Variant = load(path)
			if file_font is Font:
				_fonts["file:" + kind] = file_font
				return file_font
	return null


func _system_font(kind: String) -> Font:
	var f := SystemFont.new()
	if kind == "mono":
		f.font_names = PackedStringArray(["Geist Mono", "JetBrains Mono", "Cascadia Mono", "Consolas", "DejaVu Sans Mono", "monospace"])
	else:
		f.font_names = PackedStringArray(["Figtree", "Segoe UI", "Inter", "Noto Sans", "DejaVu Sans", "sans-serif"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var base_kind: String = "mono" if kind.begins_with("mono") else "body"
	var weight: int = 400
	if kind.ends_with("_medium"):
		weight = 500
	elif kind.ends_with("_semibold"):
		weight = 600
	elif kind.ends_with("_bold"):
		weight = 700
	var base: Font = _load_font_file(base_kind)
	if base == null:
		base = _system_font(base_kind)
	var out: Font = base
	if weight != 400:
		var v := FontVariation.new()
		v.base_font = base
		v.variation_opentype = {"wght": weight}
		out = v
	_fonts[kind] = out
	return out


func _icon_key(area: String) -> String:
	return "ui.icon_scale." + area


func icon_scale(area: String) -> float:
	if _icon_scales.has(area):
		return float(_icon_scales[area])
	var prefs: Node = _prefs()
	var v: float = 1.0
	if prefs != null:
		var key: String = _icon_key(area)
		if not (key in prefs.keys()):
			prefs.register(key, 1.0, {"label": "Icon scale: " + area, "type": "float", "min": ICON_SCALE_MIN, "max": ICON_SCALE_MAX})
		v = clampf(float(prefs.get_value(key)), ICON_SCALE_MIN, ICON_SCALE_MAX)
	_icon_scales[area] = v
	return v


func set_icon_scale(area: String, v: float) -> void:
	var clamped: float = clampf(snappedf(v, 0.1), ICON_SCALE_MIN, ICON_SCALE_MAX)
	_icon_scales[area] = clamped
	var prefs: Node = _prefs()
	if prefs != null:
		var key: String = _icon_key(area)
		if not (key in prefs.keys()):
			prefs.register(key, 1.0, {"label": "Icon scale: " + area, "type": "float", "min": ICON_SCALE_MIN, "max": ICON_SCALE_MAX})
		prefs.set_value(key, clamped)
	icon_scale_changed.emit(area)


func label_colour(index: int) -> Color:
	if labels.is_empty():
		_build_labels()
	var i: int = clampi(index, 0, labels.size() - 1)
	var prefs: Node = _prefs()
	if prefs != null and bool(prefs.get_value("ui.mono_labels")):
		var v: float = 0.3 + 0.55 * float(i) / float(maxi(1, labels.size() - 1))
		if is_light():
			v = 0.85 - 0.55 * float(i) / float(maxi(1, labels.size() - 1))
		return Color(v, v, v)
	return labels[i]


func label_name(index: int) -> String:
	var i: int = clampi(index, 0, LABEL_NAMES.size() - 1)
	return LABEL_NAMES[i]


func key_colour(v: float, lo: float, hi: float, over: bool) -> Color:
	if v < 0.0:
		return c["key_negative"]
	if over:
		return c["key_over"]
	var span: float = hi - lo
	var t: float = 0.5
	if span > 0.000001:
		t = clampf((v - lo) / span, 0.0, 1.0)
	return (c["key_low"] as Color).lerp(c["key_high"], t)


func col(name: String) -> Color:
	if c.has(name):
		return c[name]
	return Color.MAGENTA


func sz(name: String) -> float:
	if s.has(name):
		return float(s[name])
	return 0.0

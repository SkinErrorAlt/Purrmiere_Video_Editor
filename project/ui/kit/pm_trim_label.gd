extends Label

const PmTip := preload("res://ui/kit/pm_tip.gd")
const PmText := preload("res://ui/kit/pm_text.gd")

var _base_tip: String = ""
var _written: String = ""
var _elided: bool = false


func _init() -> void:
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	clip_text = true
	visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	visible_characters = 0
	resized.connect(sync_tip)


func is_elided() -> bool:
	return _elided


func needed_width() -> float:
	var font: Font = get_theme_font("font")
	if font == null:
		return 0.0
	var fs: int = get_theme_font_size("font_size")
	var w: float = 0.0
	for line: String in text.split("\n"):
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return w


func available_width() -> float:
	var sb: StyleBox = get_theme_stylebox("normal")
	var m: float = 0.0
	if sb != null:
		m = sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
	return maxf(size.x - m, 0.0)


func content_rect() -> Rect2:
	var sb: StyleBox = get_theme_stylebox("normal")
	if sb == null:
		return Rect2(Vector2.ZERO, size)
	return Rect2(sb.get_margin(SIDE_LEFT), sb.get_margin(SIDE_TOP), maxf(size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT), 0.0), maxf(size.y - sb.get_margin(SIDE_TOP) - sb.get_margin(SIDE_BOTTOM), 0.0))


func _draw() -> void:
	sync_tip()
	var font: Font = get_theme_font("font")
	if font == null or text.is_empty():
		return
	var fs: int = get_theme_font_size("font_size")
	var r: Rect2 = content_rect()
	var shown: String = text.replace("\n", " ")
	var base: float = PmText.baseline_in(font, fs, r)
	if vertical_alignment == VERTICAL_ALIGNMENT_TOP:
		base = r.position.y + font.get_ascent(fs)
	elif vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		base = r.end.y - font.get_descent(fs)
	var align: HorizontalAlignment = horizontal_alignment
	if align == HORIZONTAL_ALIGNMENT_FILL:
		align = HORIZONTAL_ALIGNMENT_LEFT
	PmText.draw_in(self, font, r, shown, fs, get_theme_color("font_color"), align, base, PmText.ELIDE_OWN_TIP)


func sync_tip() -> void:
	var current: String = PmTip.text_of(self)
	if current != _written:
		_base_tip = current
	_elided = not text.is_empty() and needed_width() > available_width() + 0.5
	var want: String = _base_tip
	if _elided and not _base_tip.contains(text):
		want = text if _base_tip.is_empty() else text + "\n" + _base_tip
	if want != current:
		_written = want
		PmTip.attach(self, want)
	else:
		_written = current

extends RefCounted

const PmTextKit := preload("res://ui/kit/pm_text.gd")


static func _base(text: String, size_token: String, colour_token: String, elide: bool = false) -> Label:
	var l: Label = (load("res://ui/kit/pm_trim_label.gd") as GDScript).new() if elide else Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_font_size_override("font_size", Tk.fs(Tk.sz(size_token)))
	l.add_theme_color_override("font_color", Tk.c[colour_token])
	return l


static func headline(text: String) -> Label:
	var l: Label = _base(text, "font_head", "text_bright")
	l.add_theme_font_override("font", Tk.font("body_semibold"))
	return l


static func title(text: String) -> Label:
	var l: Label = _base(text, "font_title", "text_bright")
	l.add_theme_font_override("font", Tk.font("body_semibold"))
	return l


static func display(text: String) -> Label:
	var l: Label = _base(text, "font_display", "text_bright")
	l.add_theme_font_override("font", Tk.font("body_semibold"))
	return l


static func meta(text: String, colour_token: String = "text_faint") -> Label:
	var l: Label = _base(text.to_upper(), "font_meta", colour_token)
	l.add_theme_font_override("font", Tk.font("mono"))
	return l


static func body(text: String, colour_token: String = "text") -> Label:
	return _base(text, "font_body", colour_token)


static func dim(text: String) -> Label:
	return _base(text, "font_small", "text_dim")


static func faint(text: String) -> Label:
	return _base(text, "font_small", "text_faint")


static func small(text: String) -> Label:
	return _base(text, "font_small", "text")


static func tiny(text: String) -> Label:
	return _base(text, "font_tiny", "text_dim")


static func trim(text: String, colour_token: String = "text") -> Label:
	var l: Label = _base(text, "font_body", colour_token, true)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(0, 0)
	return l


static func tight(text: String, colour_token: String = "text") -> Label:
	var l: Label = _base(text, "font_body", colour_token)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l


static func mono(text: String, colour_token: String = "text") -> Label:
	var l: Label = _base(text, "font_body", colour_token)
	l.add_theme_font_override("font", Tk.font("mono"))
	return l


static func wrap(text: String, colour_token: String = "text") -> Label:
	var l: Label = _base(text, "font_body", colour_token)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func draw_fit(ci: CanvasItem, font: Font, baseline: Vector2, text: String, width: float, fs: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Dictionary:
	var need: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var room: float = maxf(width, 0.0)
	var elided: bool = need > room + 0.5
	var shown: String = PmTextKit.elide(font, text, room, fs) if elided else text
	var drawn: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if elided else need
	var x: float = baseline.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x += (room - drawn) * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x += room - drawn
	if not shown.is_empty():
		ci.draw_string(font, Vector2(x, baseline.y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return {"x": x, "w": drawn, "need": need, "elided": elided, "text": text}


static func set_colour(l: Label, colour_token: String) -> void:
	l.add_theme_color_override("font_color", Tk.c[colour_token])

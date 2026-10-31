extends RefCounted

const BUTTON_STATES: PackedStringArray = ["normal", "hover", "pressed", "disabled"]
const VARIANTS: PackedStringArray = ["secondary", "primary", "ghost"]


static func flat(bg: Color, radius: float = 0.0, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = radius > 0.0
	sb.anti_aliasing_size = 0.8
	if border_w > 0 and border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	return sb


static func hairline(bg: Color, radius: float, border: Color) -> StyleBoxFlat:
	return flat(bg, radius, border, 1)


static func shadowed(sb: StyleBoxFlat, depth: float) -> StyleBoxFlat:
	sb.shadow_color = Tk.c["shadow"]
	sb.shadow_size = Tk.px(depth)
	sb.shadow_offset = Vector2(0.0, float(Tk.px(depth)) * 0.3)
	return sb


static func ring(sb: StyleBoxFlat, width: float, col: Color) -> StyleBoxFlat:
	sb.shadow_color = col
	sb.shadow_size = int(width)
	sb.shadow_offset = Vector2.ZERO
	return sb


static func with_margins(sb: StyleBox, left: float, top: float, right: float, bottom: float) -> StyleBox:
	sb.content_margin_left = left
	sb.content_margin_top = top
	sb.content_margin_right = right
	sb.content_margin_bottom = bottom
	return sb


static func empty(left: float = 0.0, top: float = 0.0, right: float = 0.0, bottom: float = 0.0) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	with_margins(sb, left, top, right, bottom)
	return sb


static func button_fill(state: String, variant: String = "secondary") -> Color:
	if variant == "primary":
		if state == "hover":
			return (Tk.c["sol"] as Color).lerp(Tk.c["bg_panel"], 0.08)
		if state == "pressed":
			return (Tk.c["sol"] as Color).lerp(Tk.c["bg_panel"], 0.16)
		if state == "disabled":
			return Tk.c["bg_panel_high"]
		return Tk.c["sol"]
	if state == "hover":
		return Tk.c["glass"]
	if state == "pressed":
		return Tk.c["glass_strong"]
	return Color(0, 0, 0, 0)


static func button_border(state: String, variant: String = "secondary") -> Color:
	if variant != "secondary":
		return Color(0, 0, 0, 0)
	if state == "hover" or state == "pressed":
		return Tk.c["text_faint"]
	if state == "disabled":
		return Tk.c["border"]
	return Tk.c["border_soft"]


static func button_text(state: String, variant: String = "secondary") -> Color:
	if variant == "primary":
		if state == "disabled":
			return Tk.c["text_faint"]
		return Tk.c["inv"]
	if state == "disabled":
		return Tk.c["text_faint"]
	if variant == "ghost":
		if state == "hover" or state == "pressed":
			return Tk.c["text_bright"]
		return Tk.c["text_dim"]
	if state == "hover" or state == "pressed":
		return Tk.c["text_bright"]
	return Tk.c["text"]


static func button_boxes(has_icon: bool, icon_gutter: float, pad_x: float, pad_y: float, radius: float, variant: String = "secondary") -> Dictionary:
	var out: Dictionary = {}
	var left: float = pad_x + (icon_gutter if has_icon else 0.0)
	for state: String in BUTTON_STATES:
		var border: Color = button_border(state, variant)
		var sb: StyleBoxFlat = flat(button_fill(state, variant), radius, border, 1 if border.a > 0.0 else 0)
		if border.a <= 0.0 and variant == "secondary":
			sb.set_border_width_all(1)
			sb.border_color = Color(0, 0, 0, 0)
		with_margins(sb, left, pad_y, pad_x, pad_y)
		out[state] = sb
	var focus: StyleBoxFlat = flat(Color(0, 0, 0, 0), radius)
	focus.draw_center = false
	ring(focus, 3.0, Tk.c["glass_strong"])
	with_margins(focus, left, pad_y, pad_x, pad_y)
	out["focus"] = focus
	return out


static func _plot(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, col)


static func _blend(img: Image, x: int, y: int, col: Color, a: float) -> void:
	if a <= 0.0 or x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var under: Color = img.get_pixel(x, y)
	var top := Color(col, col.a * clampf(a, 0.0, 1.0))
	img.set_pixel(x, y, under.blend(top))


static func _sd_round_box(p: Vector2, half: Vector2, r: float) -> float:
	var q := Vector2(absf(p.x) - half.x + r, absf(p.y) - half.y + r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


static func _raster_round_rect(img: Image, rect: Rect2, radius: float, fill: Color, stroke: Color, stroke_w: float) -> void:
	var centre: Vector2 = rect.get_center()
	var half: Vector2 = rect.size * 0.5
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) - centre
			var d: float = _sd_round_box(p, half, radius)
			if fill.a > 0.0:
				_blend(img, x, y, fill, clampf(0.5 - d, 0.0, 1.0))
			if stroke.a > 0.0 and stroke_w > 0.0:
				var ring_d: float = absf(d + stroke_w * 0.5) - stroke_w * 0.5
				_blend(img, x, y, stroke, clampf(0.5 - ring_d, 0.0, 1.0))


static func _raster_disc(img: Image, centre: Vector2, r: float, fill: Color, stroke: Color, stroke_w: float) -> void:
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var d: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(centre) - r
			if fill.a > 0.0:
				_blend(img, x, y, fill, clampf(0.5 - d, 0.0, 1.0))
			if stroke.a > 0.0 and stroke_w > 0.0:
				var ring_d: float = absf(d + stroke_w * 0.5) - stroke_w * 0.5
				_blend(img, x, y, stroke, clampf(0.5 - ring_d, 0.0, 1.0))


static func _raster_line(img: Image, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d: Vector2 = b - a
	var len2: float = maxf(d.length_squared(), 0.000001)
	var half: float = w * 0.5
	var x0: int = int(floor(minf(a.x, b.x) - half - 1.0))
	var x1: int = int(ceil(maxf(a.x, b.x) + half + 1.0))
	var y0: int = int(floor(minf(a.y, b.y) - half - 1.0))
	var y1: int = int(ceil(maxf(a.y, b.y) + half + 1.0))
	for y: int in range(y0, y1):
		for x: int in range(x0, x1):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var t: float = clampf((p - a).dot(d) / len2, 0.0, 1.0)
			var dist: float = p.distance_to(a + d * t) - half
			_blend(img, x, y, col, clampf(0.5 - dist, 0.0, 1.0))


static func check_icon(px: int, checked: bool, box: Color, tick: Color) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var k: float = float(px) / 17.0
	var inset: float = 1.0 * k
	var rect := Rect2(inset, inset, float(px) - inset * 2.0, float(px) - inset * 2.0)
	var radius: float = 5.0 * k
	if checked:
		_raster_round_rect(img, rect, radius, box, Color(0, 0, 0, 0), 0.0)
		_raster_line(img, Vector2(4.6, 8.8) * k, Vector2(7.3, 11.5) * k, tick, 1.7 * k)
		_raster_line(img, Vector2(7.3, 11.5) * k, Vector2(12.6, 5.9) * k, tick, 1.7 * k)
	else:
		_raster_round_rect(img, rect, radius, Color(0, 0, 0, 0), box, 1.4 * k)
	return ImageTexture.create_from_image(img)


static func radio_icon(px: int, checked: bool, box: Color, tick: Color) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var k: float = float(px) / 15.0
	var c := Vector2(float(px) * 0.5, float(px) * 0.5)
	var r: float = float(px) * 0.5 - 1.0 * k
	if checked:
		_raster_disc(img, c, r, Color(0, 0, 0, 0), box, 3.4 * k)
		_raster_disc(img, c, r - 3.4 * k, tick, Color(0, 0, 0, 0), 0.0)
	else:
		_raster_disc(img, c, r, Color(0, 0, 0, 0), box, 1.4 * k)
	return ImageTexture.create_from_image(img)


static func grabber_icon(px: int, col: Color, rim: Color = Color(0, 0, 0, 0)) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(float(px) * 0.5, float(px) * 0.5)
	_raster_disc(img, c, float(px) * 0.5 - 0.5, col, rim, 2.0 if rim.a > 0.0 else 0.0)
	return ImageTexture.create_from_image(img)


static func arrow_icon(px: int, col: Color) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var k: float = float(px) / 12.0
	_raster_line(img, Vector2(3.0, 4.5) * k, Vector2(6.0, 7.5) * k, col, 1.4 * k)
	_raster_line(img, Vector2(6.0, 7.5) * k, Vector2(9.0, 4.5) * k, col, 1.4 * k)
	return ImageTexture.create_from_image(img)


static func meta_font_size() -> int:
	return Tk.fs(Tk.sz("font_meta"))


static func build() -> Theme:
	var t := Theme.new()
	var c: Dictionary = Tk.c
	var radius: float = float(Tk.px(Tk.sz("radius")))
	var radius_field: float = float(Tk.px(Tk.sz("radius_field")))
	var radius_menu: float = float(Tk.px(Tk.sz("radius_menu")))
	var radius_row: float = float(Tk.px(Tk.sz("radius_row")))
	var radius_panel: float = float(Tk.px(Tk.sz("radius_panel")))
	var pad: float = float(Tk.px(Tk.sz("pad")))
	var gap: float = float(Tk.px(Tk.sz("gap")))
	var body_px: int = Tk.fs(Tk.sz("font_body"))
	var clear := Color(0, 0, 0, 0)
	t.default_font = Tk.font("body")
	t.default_font_size = body_px

	t.set_color("font_color", "Label", c["text"])
	t.set_font_size("font_size", "Label", body_px)
	t.set_stylebox("normal", "Label", empty(0, 0, 0, 0))

	var boxes: Dictionary = button_boxes(false, 0.0, pad + 4.0, gap, radius)
	for state: String in BUTTON_STATES:
		t.set_stylebox(state, "Button", boxes[state])
	t.set_stylebox("focus", "Button", boxes["focus"])
	t.set_color("font_color", "Button", c["text"])
	t.set_color("font_hover_color", "Button", c["text_bright"])
	t.set_color("font_pressed_color", "Button", c["text_bright"])
	t.set_color("font_hover_pressed_color", "Button", c["text_bright"])
	t.set_color("font_focus_color", "Button", c["text"])
	t.set_color("font_disabled_color", "Button", c["text_faint"])
	t.set_color("icon_normal_color", "Button", c["text"])
	t.set_color("icon_hover_color", "Button", c["text_bright"])
	t.set_color("icon_pressed_color", "Button", c["text_bright"])
	t.set_color("icon_disabled_color", "Button", c["text_faint"])
	t.set_constant("h_separation", "Button", int(gap))
	t.set_font("font", "Button", Tk.font("body_medium"))

	var check_px: int = Tk.px(17.0)
	var radio_px: int = Tk.px(15.0)
	t.set_icon("checked", "CheckBox", check_icon(check_px, true, c["sol"], c["inv"]))
	t.set_icon("unchecked", "CheckBox", check_icon(check_px, false, c["border_soft"], c["inv"]))
	t.set_icon("checked_disabled", "CheckBox", check_icon(check_px, true, c["bg_panel_high"], c["text_faint"]))
	t.set_icon("unchecked_disabled", "CheckBox", check_icon(check_px, false, c["border"], c["text_faint"]))
	t.set_icon("radio_checked", "CheckBox", radio_icon(radio_px, true, c["sol"], c["bg_panel"]))
	t.set_icon("radio_unchecked", "CheckBox", radio_icon(radio_px, false, c["border_soft"], c["bg_panel"]))
	t.set_icon("radio_checked_disabled", "CheckBox", radio_icon(radio_px, true, c["bg_panel_high"], c["bg_panel"]))
	t.set_icon("radio_unchecked_disabled", "CheckBox", radio_icon(radio_px, false, c["border"], c["bg_panel"]))
	for state: String in BUTTON_STATES:
		t.set_stylebox(state, "CheckBox", empty(2, 2, 2, 2))
	t.set_stylebox("focus", "CheckBox", empty(2, 2, 2, 2))
	t.set_stylebox("hover_pressed", "CheckBox", empty(2, 2, 2, 2))
	t.set_color("font_color", "CheckBox", c["text"])
	t.set_color("font_hover_color", "CheckBox", c["text_bright"])
	t.set_color("font_pressed_color", "CheckBox", c["text_bright"])
	t.set_color("font_hover_pressed_color", "CheckBox", c["text_bright"])
	t.set_color("font_disabled_color", "CheckBox", c["text_faint"])
	t.set_constant("h_separation", "CheckBox", int(gap) + 2)
	t.set_icon("arrow", "OptionButton", arrow_icon(Tk.px(12.0), c["text_dim"]))
	t.set_constant("arrow_margin", "OptionButton", int(pad))

	var field_normal: StyleBoxFlat = hairline(c["bg_field"], radius_field, c["border_soft"])
	with_margins(field_normal, pad + 2.0, 2.0, pad + 2.0, 2.0)
	var field_focus: StyleBoxFlat = hairline(c["bg_field"], radius_field, c["text_dim"])
	ring(field_focus, 3.0, c["glass_strong"])
	with_margins(field_focus, pad + 2.0, 2.0, pad + 2.0, 2.0)
	var field_ro: StyleBoxFlat = hairline(c["bg_panel"], radius_field, c["border"])
	with_margins(field_ro, pad + 2.0, 2.0, pad + 2.0, 2.0)
	t.set_stylebox("normal", "LineEdit", field_normal)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_stylebox("read_only", "LineEdit", field_ro)
	t.set_color("font_color", "LineEdit", c["text_bright"])
	t.set_color("font_uneditable_color", "LineEdit", c["text_dim"])
	t.set_color("font_placeholder_color", "LineEdit", c["text_faint"])
	t.set_color("caret_color", "LineEdit", c["text_bright"])
	t.set_color("selection_color", "LineEdit", c["glass_deep"])
	t.set_constant("minimum_character_width", "LineEdit", 1)
	t.set_stylebox("normal", "TextEdit", field_normal)
	t.set_stylebox("focus", "TextEdit", field_focus)
	t.set_stylebox("read_only", "TextEdit", field_ro)
	t.set_color("font_color", "TextEdit", c["text_bright"])
	t.set_color("font_placeholder_color", "TextEdit", c["text_faint"])
	t.set_color("caret_color", "TextEdit", c["text_bright"])
	t.set_color("selection_color", "TextEdit", c["glass_deep"])
	t.set_color("background_color", "TextEdit", Color(0.0, 0.0, 0.0, 0.0))

	t.set_stylebox("panel", "Panel", flat(c["bg_panel"], 0.0))
	t.set_stylebox("panel", "PanelContainer", with_margins(flat(c["bg_panel"], 0.0), pad, pad, pad, pad))
	t.set_stylebox("panel", "ScrollContainer", empty())
	t.set_stylebox("panel", "PopupPanel", shadowed(with_margins(hairline(c["bg_panel_alt"], radius_menu, c["border_soft"]), 5, 5, 5, 5), 10.0))
	t.set_stylebox("panel", "Window", hairline(c["bg_panel"], radius_panel, c["border_soft"]))
	t.set_stylebox("embedded_border", "Window", shadowed(hairline(c["bg_panel"], radius_panel, c["border_soft"]), 12.0))
	t.set_color("title_color", "Window", c["text_bright"])

	var bar_px: int = Tk.px(9.0)
	for bar: String in ["HScrollBar", "VScrollBar"]:
		var track: StyleBoxFlat = flat(clear, 0.0)
		var grab: StyleBoxFlat = flat(c["border_soft"], radius_menu)
		var grab_h: StyleBoxFlat = flat(c["text_faint"], radius_menu)
		var grab_p: StyleBoxFlat = flat(c["text_dim"], radius_menu)
		for g: StyleBoxFlat in [grab, grab_h, grab_p]:
			g.anti_aliasing = true
		if bar == "HScrollBar":
			with_margins(track, 0, bar_px, 0, 0)
			with_margins(grab, 0, bar_px, 0, 0)
			with_margins(grab_h, 0, bar_px, 0, 0)
			with_margins(grab_p, 0, bar_px, 0, 0)
		else:
			with_margins(track, bar_px, 0, 0, 0)
			with_margins(grab, bar_px, 0, 0, 0)
			with_margins(grab_h, bar_px, 0, 0, 0)
			with_margins(grab_p, bar_px, 0, 0, 0)
		t.set_stylebox("scroll", bar, track)
		t.set_stylebox("scroll_focus", bar, track)
		t.set_stylebox("grabber", bar, grab)
		t.set_stylebox("grabber_highlight", bar, grab_h)
		t.set_stylebox("grabber_pressed", bar, grab_p)
		t.set_icon("increment", bar, ImageTexture.new())
		t.set_icon("decrement", bar, ImageTexture.new())
		t.set_icon("increment_highlight", bar, ImageTexture.new())
		t.set_icon("decrement_highlight", bar, ImageTexture.new())
		t.set_icon("increment_pressed", bar, ImageTexture.new())
		t.set_icon("decrement_pressed", bar, ImageTexture.new())

	var slider_track: StyleBoxFlat = flat(c["bg_panel_high"], 999.0)
	var slider_fill: StyleBoxFlat = flat(c["sol"], 999.0)
	with_margins(slider_track, 0, 1.5, 0, 1.5)
	with_margins(slider_fill, 0, 1.5, 0, 1.5)
	var vtrack: StyleBoxFlat = flat(c["bg_panel_high"], 999.0)
	var vfill: StyleBoxFlat = flat(c["sol"], 999.0)
	with_margins(vtrack, 1.5, 0, 1.5, 0)
	with_margins(vfill, 1.5, 0, 1.5, 0)
	t.set_stylebox("slider", "HSlider", slider_track)
	t.set_stylebox("grabber_area", "HSlider", slider_fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	t.set_stylebox("slider", "VSlider", vtrack)
	t.set_stylebox("grabber_area", "VSlider", vfill)
	t.set_stylebox("grabber_area_highlight", "VSlider", vfill)
	var grab_px: int = Tk.px(12.0)
	for sl: String in ["HSlider", "VSlider"]:
		t.set_icon("grabber", sl, grabber_icon(grab_px, c["sol"], c["bg_panel"]))
		t.set_icon("grabber_highlight", sl, grabber_icon(grab_px, c["text_bright"], c["bg_panel"]))
		t.set_icon("grabber_disabled", sl, grabber_icon(grab_px, c["text_faint"], c["bg_panel"]))
		t.set_icon("tick", sl, ImageTexture.new())

	t.set_stylebox("panel", "PopupMenu", shadowed(with_margins(hairline(c["bg_panel_alt"], radius_menu, c["border_soft"]), 5, 5, 5, 5), 10.0))
	t.set_stylebox("hover", "PopupMenu", flat(c["glass"], radius_row))
	t.set_stylebox("separator", "PopupMenu", flat(c["border"], 0.0))
	t.set_color("font_color", "PopupMenu", c["text"])
	t.set_color("font_hover_color", "PopupMenu", c["text_bright"])
	t.set_color("font_disabled_color", "PopupMenu", c["text_faint"])
	t.set_color("font_accelerator_color", "PopupMenu", c["text_faint"])
	t.set_color("font_separator_color", "PopupMenu", c["text_dim"])
	t.set_constant("v_separation", "PopupMenu", int(gap) + 2)
	t.set_constant("item_start_padding", "PopupMenu", int(pad) + 3)
	t.set_constant("item_end_padding", "PopupMenu", int(pad) + 3)
	t.set_icon("checked", "PopupMenu", check_icon(check_px, true, c["sol"], c["inv"]))
	t.set_icon("unchecked", "PopupMenu", check_icon(check_px, false, c["border_soft"], c["inv"]))
	t.set_icon("radio_checked", "PopupMenu", radio_icon(radio_px, true, c["sol"], c["bg_panel_alt"]))
	t.set_icon("radio_unchecked", "PopupMenu", radio_icon(radio_px, false, c["border_soft"], c["bg_panel_alt"]))

	var tab_h: float = float(Tk.px(Tk.sz("tab_h")))
	var tab_sel: StyleBoxFlat = flat(clear, 0.0)
	with_margins(tab_sel, pad + 4.0, 4.0, pad + 4.0, 4.0)
	tab_sel.border_color = c["sol"]
	tab_sel.border_width_bottom = 2
	var tab_un: StyleBoxFlat = flat(clear, 0.0)
	with_margins(tab_un, pad + 4.0, 4.0, pad + 4.0, 4.0)
	var tab_hover: StyleBoxFlat = flat(c["glass"], radius_row)
	with_margins(tab_hover, pad + 4.0, 4.0, pad + 4.0, 4.0)
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_un)
	t.set_stylebox("tab_hovered", "TabContainer", tab_hover)
	t.set_stylebox("tab_disabled", "TabContainer", tab_un)
	t.set_stylebox("tab_focus", "TabContainer", empty())
	t.set_stylebox("panel", "TabContainer", flat(c["bg_panel"], 0.0))
	t.set_stylebox("tabbar_background", "TabContainer", flat(clear, 0.0))
	t.set_color("font_selected_color", "TabContainer", c["text_bright"])
	t.set_color("font_unselected_color", "TabContainer", c["text_dim"])
	t.set_color("font_hovered_color", "TabContainer", c["text"])
	t.set_color("font_disabled_color", "TabContainer", c["text_faint"])
	t.set_constant("side_margin", "TabContainer", 0)
	for key: String in ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled", "tab_focus"]:
		t.set_stylebox(key, "TabBar", t.get_stylebox(key, "TabContainer"))
	t.set_color("font_selected_color", "TabBar", c["text_bright"])
	t.set_color("font_unselected_color", "TabBar", c["text_dim"])
	t.set_color("font_hovered_color", "TabBar", c["text"])
	t.set_constant("tab_h", "TabBar", int(tab_h))

	t.set_stylebox("panel", "TooltipPanel", shadowed(with_margins(hairline(c["bg_panel_alt"], radius, c["border_soft"]), pad + 2.0, gap + 1.0, pad + 2.0, gap + 1.0), 6.0))
	t.set_color("font_color", "TooltipLabel", c["text"])
	t.set_font_size("font_size", "TooltipLabel", Tk.fs(Tk.sz("font_small")))

	t.set_stylebox("separator", "HSeparator", with_margins(flat(c["border"], 0.0), 0, 0, 0, 0))
	t.set_stylebox("separator", "VSeparator", with_margins(flat(c["border"], 0.0), 0, 0, 0, 0))
	t.set_constant("separation", "HSeparator", 1)
	t.set_constant("separation", "VSeparator", 1)

	var prog_bg: StyleBoxFlat = flat(c["bg_panel_high"], 999.0)
	var prog_fill: StyleBoxFlat = flat(c["sol"], 999.0)
	t.set_stylebox("background", "ProgressBar", prog_bg)
	t.set_stylebox("fill", "ProgressBar", prog_fill)
	t.set_color("font_color", "ProgressBar", c["text"])
	t.set_font_size("font_size", "ProgressBar", Tk.fs(Tk.sz("font_small")))

	t.set_stylebox("panel", "Tree", flat(c["bg_panel"], 0.0))
	t.set_stylebox("selected", "Tree", flat(c["glass_strong"], radius_row))
	t.set_stylebox("selected_focus", "Tree", flat(c["glass_strong"], radius_row))
	t.set_stylebox("hovered", "Tree", flat(c["glass"], radius_row))
	t.set_stylebox("focus", "Tree", empty())
	t.set_color("font_color", "Tree", c["text"])
	t.set_color("font_selected_color", "Tree", c["text_bright"])
	t.set_color("guide_color", "Tree", c["border"])
	t.set_stylebox("panel", "ItemList", flat(c["bg_panel"], 0.0))
	t.set_stylebox("selected", "ItemList", flat(c["glass_strong"], radius_row))
	t.set_stylebox("selected_focus", "ItemList", flat(c["glass_strong"], radius_row))
	t.set_stylebox("hovered", "ItemList", flat(c["glass"], radius_row))
	t.set_stylebox("focus", "ItemList", empty())
	t.set_color("font_color", "ItemList", c["text"])
	t.set_color("font_selected_color", "ItemList", c["text_bright"])
	t.set_color("guide_color", "ItemList", c["border"])

	t.set_constant("separation", "HBoxContainer", int(gap))
	t.set_constant("separation", "VBoxContainer", int(gap))
	t.set_constant("h_separation", "HFlowContainer", int(gap))
	t.set_constant("v_separation", "HFlowContainer", int(gap))
	t.set_constant("h_separation", "GridContainer", int(gap))
	t.set_constant("v_separation", "GridContainer", int(gap))
	t.set_stylebox("panel", "AcceptDialog", hairline(c["bg_panel"], radius_panel, c["border_soft"]))
	return t

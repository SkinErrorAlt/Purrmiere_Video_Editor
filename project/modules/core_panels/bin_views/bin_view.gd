extends RefCounted

const IconsKit := preload("res://ui/kit/icons.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const MarkerTicks := preload("res://ui/timeline/marker_ticks.gd")
const ELLIPSIS := "…"

static var _elide_cache: Dictionary = {}

var panel: RefCounted = null
var body: Control = null
var meta_text: String = ""


func id() -> String:
	return ""


func title() -> String:
	return ""


func glyph() -> String:
	return "views"


func setup(panel_: RefCounted, body_: Control) -> void:
	panel = panel_
	body = body_


func layout(width: float, _height: float) -> Vector2:
	return Vector2(width, 0.0)


func draw() -> void:
	pass


func input(_event: InputEvent) -> bool:
	return false


func tick(_dt: float) -> bool:
	return false


func zoom(_steps: float, _at: Vector2) -> bool:
	return false


func name_rect(i: int) -> Rect2:
	var r: Rect2 = screen_rect(i)
	var nh: float = float(Tk.px(18.0))
	return Rect2(r.position.x, r.end.y - nh, r.size.x, nh)


func tip_for(i: int) -> String:
	var e: Dictionary = entry(i)
	return String(e.get("label", ""))


func build_bar(_bar: Container) -> void:
	pass


func context_items(_entry_id: String) -> Array:
	return []


func on_context(_id: String, _entry_id: String) -> bool:
	return false


func empty_items(_at_local: Vector2) -> Array:
	return []


func on_empty(_id: String) -> bool:
	return false


func handle_key(_e: InputEventKey) -> bool:
	return false


func filter(list: Array[Dictionary]) -> Array[Dictionary]:
	return list


func leave() -> void:
	pass


func deactivate() -> void:
	pass


func doc_changed(_kind: String) -> void:
	pass


func uses_hover_scrub() -> bool:
	return false


func draws_scrollbar() -> bool:
	return true


func entries() -> Array[Dictionary]:
	return body.get("entries") if body != null else ([] as Array[Dictionary])


func entry(i: int) -> Dictionary:
	var list: Array[Dictionary] = entries()
	if i < 0 or i >= list.size():
		return {}
	return list[i]


func item_of(i: int) -> MediaItem:
	var e: Dictionary = entry(i)
	var it: Variant = e.get("item", null)
	return it as MediaItem if it is MediaItem else null


func is_folder(i: int) -> bool:
	return String(entry(i).get("kind", "")) == "folder"


func is_selected(i: int) -> bool:
	var e: Dictionary = entry(i)
	if e.is_empty():
		return false
	if String(e["kind"]) == "folder":
		return String(panel.get("selected_folder")) == String(e["path"])
	var sel: PackedStringArray = panel.get("selected_ids")
	return sel.has(String(e["id"]))


func hover_index() -> int:
	return int(body.get("hover"))


func rects() -> Array[Rect2]:
	return body.get("rects")


func scroll_pos() -> Vector2:
	var sc: Node = body.get("scroll")
	return Vector2(float(sc.get("scroll_x")), float(sc.get("scroll_y")))


func screen_rect(i: int) -> Rect2:
	var rs: Array[Rect2] = rects()
	if i < 0 or i >= rs.size():
		return Rect2()
	var r: Rect2 = rs[i]
	r.position -= scroll_pos()
	return r


func visible_rect() -> Rect2:
	return Rect2(Vector2.ZERO, body.size)


func draw_marker_ticks(r: Rect2, item: MediaItem) -> void:
	if item == null or item.markers.is_empty():
		return
	var d: Project = doc()
	MarkerTicks.draw_tile(body, r, item, d.media_duration(item) if d != null else item.duration)


func doc() -> Project:
	return Session.doc


func state(section: String, key: String, fallback: Variant) -> Variant:
	return panel.call("view_value", section, key, fallback)


func set_state(section: String, key: String, value: Variant) -> void:
	panel.call("set_view_value", section, key, value)


func px(v: float) -> float:
	return float(Tk.px(v))


func font() -> Font:
	return Tk.font("body")


func mono() -> Font:
	return Tk.font("mono")


func fs_small() -> int:
	return Tk.fs(Tk.sz("font_small"))


func fs_body() -> int:
	return Tk.fs(Tk.sz("font_body"))


func fs_meta() -> int:
	return Tk.fs(Tk.sz("font_meta"))


static func elide(f: Font, text: String, width: float, size: int) -> String:
	if width <= 0.0 or text.is_empty():
		return ""
	var key: String = text + "|" + str(int(width)) + "|" + str(size) + "|" + str(f.get_instance_id())
	if _elide_cache.has(key):
		return _elide_cache[key]
	var out: String = text
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		var lo: int = 0
		var hi: int = text.length()
		while lo < hi:
			var mid: int = (lo + hi + 1) / 2
			if f.get_string_size(text.substr(0, mid).strip_edges(false, true) + ELLIPSIS, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
				lo = mid
			else:
				hi = mid - 1
		out = text.substr(0, lo).strip_edges(false, true) + ELLIPSIS if lo > 0 else ""
	if _elide_cache.size() > 4000:
		_elide_cache.clear()
	_elide_cache[key] = out
	return out


static func is_elided(f: Font, text: String, width: float, size: int) -> bool:
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width


func text_at(pos_left: Vector2, box_h: float, text: String, width: float, size: int, colour: Color, f: Font = null, frame: Rect2 = Rect2()) -> void:
	var ff: Font = f if f != null else font()
	PmText.draw_in(body, ff, Rect2(pos_left.x, pos_left.y, width, box_h), text, size, colour, HORIZONTAL_ALIGNMENT_LEFT, NAN, PmText.ELIDE_OWN_TIP, frame)


func caption(tile: Rect2, y: float, h: float, text: String, size: int, colour: Color, f: Font = null) -> void:
	var p: float = PmText.pad()
	text_at(Vector2(tile.position.x + p, y), h, text, tile.size.x - p * 2.0, size, colour, f, Rect2(tile.position.x, y, tile.size.x, h))


func draw_picture(r: Rect2, item: MediaItem, t: float, radius: float, cover: bool = false) -> bool:
	Paint.rounded(body, r, Tk.c["bg_panel_alt"], radius, Tk.c["border"], 1)
	if item == null:
		return false
	var tex: Texture2D = panel.call("thumb_for", item, t)
	if tex == null:
		var side: float = minf(r.size.x, r.size.y) * 0.34
		if side >= 6.0:
			IconsKit.draw(body, String(panel.call("kind_icon", item.kind)), Rect2(r.position + (r.size - Vector2(side, side)) * 0.5, Vector2(side, side)), Tk.c["text_faint"])
		return false
	draw_texture_in(tex, r, cover)
	return true


func draw_texture_in(tex: Texture2D, r: Rect2, cover: bool) -> void:
	var ps: Vector2 = tex.get_size()
	if ps.x <= 0.0 or ps.y <= 0.0:
		return
	var inner: Rect2 = r.grow(-1.0)
	if cover:
		var k: float = maxf(inner.size.x / ps.x, inner.size.y / ps.y)
		var src_size: Vector2 = inner.size / k
		var src: Rect2 = Rect2((ps - src_size) * 0.5, src_size)
		body.draw_texture_rect_region(tex, inner, src)
		return
	var k2: float = minf(inner.size.x / ps.x, inner.size.y / ps.y)
	var ds: Vector2 = ps * k2
	body.draw_texture_rect(tex, Rect2(inner.position + (inner.size - ds) * 0.5, ds), false)


func draw_badge(pic: Rect2, text: String) -> void:
	if text.is_empty() or pic.size.x < px(44.0) or pic.size.y < px(24.0):
		return
	var m: Font = mono()
	var fs: int = fs_small()
	var tw: float = ceil(PmText.width_of(m, text, fs)) + PmText.chip_pad() * 2.0
	if tw > pic.size.x - px(8.0):
		return
	var h: float = ceil(m.get_height(fs)) + px(3.0)
	var br: Rect2 = Rect2(pic.end.x - tw - px(4.0), pic.end.y - h - px(4.0), tw, h)
	Paint.rounded(body, br, Color(Tk.c["bg_app"], 0.72), px(Tk.sz("radius_chip")))
	PmText.draw(body, m, br, text, fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, PmText.chip_pad(), NAN, PmText.WHOLE)


func draw_label_stripe(r: Rect2, item: MediaItem) -> void:
	if item != null and item.colour >= 0:
		body.draw_rect(Rect2(r.position.x, r.position.y, 3.0, r.size.y), Tk.label_colour(item.colour), true)


func draw_outline(r: Rect2, i: int, radius: float) -> void:
	if is_selected(i):
		Paint.rounded(body, r, Color(0, 0, 0, 0), radius, Tk.c["sol"], 1)
	elif i == hover_index():
		Paint.rounded(body, r, Color(0, 0, 0, 0), radius, Tk.c["text_faint"], 1)


func duration_text(item: MediaItem) -> String:
	if item == null or not item.is_timed():
		return ""
	var d: Project = doc()
	var dur: float = d.media_duration(item) if d != null else item.duration
	if dur <= 0.0:
		return ""
	return String(panel.call("tc", dur)).substr(3, 5)


func bar_add(bar: Container, c: Control, label: String = "") -> void:
	if bar.has_method("add_item"):
		bar.call("add_item", c, "", label)
	else:
		bar.add_child(c)


func bar_button(bar: Container, text: String, tip: String, handler: Callable, keys: String = "") -> Button:
	var b: Button = PmButton.make(text)
	PmUI.tip(b, tip, keys)
	b.pressed.connect(handler)
	bar_add(bar, b)
	return b


func bar_toggle(bar: Container, text: String, tip: String, on: bool, handler: Callable) -> Button:
	var b: Button = PmButton.make(text, "", true)
	b.set("quiet", true)
	b.button_pressed = on
	PmUI.tip(b, tip)
	b.toggled.connect(handler)
	bar_add(bar, b)
	return b


func fit_drop(drop: Button) -> void:
	var f: Font = Tk.font("body_medium")
	var fs: int = fs_body()
	var widest: float = 0.0
	for c: Variant in drop.get("choices"):
		widest = maxf(widest, f.get_string_size(String((c as Dictionary).get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var pad: float = px(Tk.sz("pad")) + 4.0
	drop.custom_minimum_size.x = ceil(widest + pad * 2.0 + px(14.0) + px(Tk.sz("gap")) * 2.0)


func set_meta_text(text: String) -> void:
	if meta_text == text:
		return
	meta_text = text
	if panel != null:
		panel.call("footer_changed")


func redraw() -> void:
	if body != null and is_instance_valid(body):
		body.queue_redraw()


func relayout() -> void:
	if body != null and is_instance_valid(body):
		body.call("relayout")

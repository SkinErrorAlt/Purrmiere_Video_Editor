extends VBoxContainer

signal open_project(path: String)
signal forget_project(path: String)

const Cards := preload("res://doc/project_cards.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const RatingSheet := preload("res://ui/editor/rating_sheet.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const CARD_W := 262.0
const CARD_H := 282.0
const THUMB_H := 147.0
const SHOW_ALL := "all"
const SHOW_UNFINISHED := "unfinished"
const SHOW_FINISHED := "finished"
const SORT_RECENT := "recent"
const SORT_RATING := "rating"

var paths: PackedStringArray = PackedStringArray()
var show: String = SHOW_ALL
var sort: String = SORT_RECENT
var cards: Array[Control] = []
var _flow: HFlowContainer = null
var _waiting: bool = false
var _thumbs: Dictionary = {}
var _filter_buttons: Dictionary = {}
var _serial: int = -1


func _init() -> void:
	name = "ProjectCards"
	add_theme_constant_override("separation", 8)
	var bar: HBoxContainer = PmUI.hbox()
	add_child(bar)
	for f: Array in [[SHOW_ALL, "All"], [SHOW_UNFINISHED, "Unfinished"], [SHOW_FINISHED, "Finished"]]:
		var b: Button = PmButton.make(String(f[1]), "", true)
		b.set("quiet", true)
		b.button_pressed = String(f[0]) == show
		b.pressed.connect(set_show.bind(String(f[0])))
		bar.add_child(b)
		_filter_buttons[String(f[0])] = b
	bar.add_child(PmUI.spacer())
	var sorter: Button = PmDrop.make_drop([PmDrop.choice(SORT_RECENT, "Last opened first"), PmDrop.choice(SORT_RATING, "Best rated first")], sort)
	sorter.connect("changed", func(id: String) -> void:
		sort = id
		rebuild()
	)
	bar.add_child(sorter)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(CARD_W * 3.0 + 24.0, CARD_H * 1.6)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(sc)
	_flow = HFlowContainer.new()
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.add_theme_constant_override("h_separation", 10)
	_flow.add_theme_constant_override("v_separation", 10)
	sc.add_child(_flow)
	set_process(false)


func set_paths(list: PackedStringArray) -> void:
	paths = list
	_waiting = not Cards.want(paths)
	set_process(_waiting)
	rebuild()


func set_show(id: String) -> void:
	show = id
	for k: Variant in _filter_buttons.keys():
		(_filter_buttons[k] as Button).set_pressed_no_signal(String(k) == id)
	rebuild()


func _process(_dt: float) -> void:
	if Cards.want(paths):
		_waiting = false
		set_process(false)
		rebuild()


func facts(path: String) -> Dictionary:
	var f: Dictionary = Cards.cached(path)
	if f.is_empty():
		return {"path": path, "name": path.get_file().get_basename(), "info": {}, "loading": true}
	return f


func finished(path: String) -> bool:
	return bool(Cards.value(path, Cards.INFO_FINISHED, facts(path), false))


func ordered() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for p: String in paths:
		var done: bool = finished(p)
		if show == SHOW_UNFINISHED and done:
			continue
		if show == SHOW_FINISHED and not done:
			continue
		out.append(p)
	if sort == SORT_RATING:
		var list: Array = Array(out)
		list.sort_custom(func(a: String, b: String) -> bool: return Cards.overall(Cards.rating_of(a, facts(a))) > Cards.overall(Cards.rating_of(b, facts(b))))
		out = PackedStringArray(list)
	return out


func rebuild() -> void:
	if _flow == null:
		return
	PmUI.clear(_flow)
	cards = []
	var list: PackedStringArray = ordered()
	if list.is_empty():
		_flow.add_child(PmLabel.faint("No projects here yet" if paths.is_empty() else "No projects match"))
		return
	for p: String in list:
		var c := Card.new()
		c.path = p
		c.view = self
		c.custom_minimum_size = Vector2(CARD_W, CARD_H)
		c.tooltip_text = p
		_flow.add_child(c)
		cards.append(c)


func thumb_for(path: String, f: Dictionary) -> Texture2D:
	var t: String = String(Cards.value(path, Cards.INFO_THUMB, f, ""))
	if t.is_empty():
		return null
	if _thumbs.has(t):
		return _thumbs[t]
	var tex: Texture2D = null
	var pre: int = Cards.premade_index(t)
	if pre >= 0:
		tex = ImageTexture.create_from_image(Cards.premade_image(pre, 256, 144))
	elif FileAccess.file_exists(t):
		var img: Image = Image.load_from_file(t)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_thumbs[t] = tex
	return tex


func menu_items(path: String) -> Array:
	var thumbs: Array = []
	for i: int in Cards.PREMADE_COUNT:
		thumbs.append(PmMenu.item("card_thumb:" + str(i), "Premade picture " + str(i + 1)))
	thumbs.append(PmMenu.item("card_thumb_none", "No picture"))
	return [
		PmMenu.item("card_open", "Open"),
		PmMenu.item("card_rate", "Rate..."),
		PmMenu.item("card_desc", "Description..."),
		PmMenu.sub_item("card_thumbs", "Picture", thumbs),
		PmMenu.check_item("card_finished", "Finished", finished(path)),
		PmMenu.separator(),
		PmMenu.item("card_forget", "Take off this list"),
	]


func open_menu(path: String, anchor: Control, at: Vector2) -> void:
	var m: Control = PmMenu.open(anchor, menu_items(path), at)
	if m != null and m.is_inside_tree():
		m.connect("picked", on_pick.bind(path))


func on_pick(id: String, path: String) -> void:
	if id == "card_open":
		open_project.emit(path)
	elif id == "card_rate":
		RatingSheet.open(self, path, facts(path), paths)
	elif id == "card_desc":
		var fields: Array[Dictionary] = [{"key": "description", "label": "Description", "default": String(Cards.value(path, "description", facts(path), ""))}]
		var answered: Signal = PmUI.form(self, "Description", fields, "Apply", "Cancel")
		answered.connect(func(r: Variant) -> void:
			if r is Dictionary:
				Cards.set_field(path, "description", String((r as Dictionary).get("description", "")).strip_edges())
				rebuild()
		)
	elif id.begins_with("card_thumb:"):
		Cards.set_field(path, Cards.INFO_THUMB, Cards.PREMADE + id.substr(11))
		rebuild()
	elif id == "card_thumb_none":
		Cards.set_field(path, Cards.INFO_THUMB, "")
		rebuild()
	elif id == "card_finished":
		Cards.set_field(path, Cards.INFO_FINISHED, not finished(path))
		rebuild()
	elif id == "card_forget":
		forget_project.emit(path)


class Card:
	extends Control

	var path: String = ""
	var view: Control = null
	var _hover: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		gui_input.connect(_on_input)
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw()
		)
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw()
		)

	func _on_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
			return
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			view.emit_signal("open_project", path)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			view.call("open_menu", path, self, mb.global_position)
		accept_event()

	func _draw() -> void:
		var f: Dictionary = view.call("facts", path)
		var box := StyleBoxFlat.new()
		box.bg_color = Tk.c["bg_panel_high"] if _hover else Tk.c["bg_panel_alt"]
		box.border_color = Tk.c["border_soft"] if not _hover else Tk.c["text_dim"]
		box.set_border_width_all(1)
		box.set_corner_radius_all(8)
		box.anti_aliasing = true
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		var thumb_rect: Rect2 = Rect2(6.0, 6.0, size.x - 12.0, THUMB_H)
		var tex: Texture2D = view.call("thumb_for", path, f)
		if tex != null:
			draw_texture_rect(tex, thumb_rect, false)
		else:
			draw_rect(thumb_rect, Tk.c["bg_app"], true)
			PmIconPaw.draw_mark(self, thumb_rect.get_center(), 22.0, Tk.c["text_faint"])
		var font: Font = Tk.font("body_semibold")
		var body: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_body"))
		var small: int = Tk.fs(Tk.sz("font_small"))
		var tiny: int = Tk.fs(Tk.sz("font_tiny"))
		var x: float = 10.0
		var w: float = size.x - 20.0
		var y: float = THUMB_H + 26.0
		PmText.draw_at(self, font, Vector2(x, y), String(f.get("name", path.get_file().get_basename())), fs, Tk.c["text_bright"], w)
		var done: bool = bool(view.call("finished", path))
		if not done:
			var badge: String = "Unfinished"
			var bw: float = body.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, tiny).x + 10.0
			var br: Rect2 = Rect2(thumb_rect.end.x - bw - 6.0, thumb_rect.position.y + 6.0, bw, 16.0)
			draw_rect(br, Color(Tk.c["bg_app"], 0.8), true)
			PmText.draw_at(self, body, br.position + Vector2(5.0, 12.0), badge, tiny, Color(0.95, 0.65, 0.3))
		var desc: String = String(Cards.value(path, "description", f, ""))
		y += 18.0
		if not desc.is_empty():
			PmText.draw_lines_at(self, body, Vector2(x, y), desc, small, Tk.c["text_dim"], w, 2)
		y += 32.0
		if bool(f.get("loading", false)):
			PmText.draw_at(self, body, Vector2(x, y), "Reading...", tiny, Tk.c["text_faint"], w)
		else:
			PmText.draw_at(self, body, Vector2(x, y), "%d clips · %d files · %d sequences" % [int(f.get("clips", 0)), int(f.get("media", 0)), int(f.get("sequences", 0))], tiny, Tk.c["text_faint"], w)
			var tags: PackedStringArray = (f.get("tags", PackedStringArray()) as PackedStringArray).duplicate()
			for n: String in Cards.region_names(f):
				if not tags.has(n):
					tags.append(n)
			if not tags.is_empty():
				PmText.draw_at(self, body, Vector2(x, y + 15.0), "#" + "  #".join(tags.slice(0, 6)), tiny, Tk.c["text_dim"], w)
		var score: float = Cards.overall(Cards.rating_of(path, f))
		_stars(Vector2(x, size.y - 12.0), score)

	func _stars(at: Vector2, score: float) -> void:
		for i: int in 5:
			var c: Vector2 = at + Vector2(float(i) * 15.0 + 6.0, -4.0)
			var fill: float = clampf(score / 2.0 - float(i), 0.0, 1.0) if score >= 0.0 else 0.0
			_star(c, 6.0, Tk.c["border_soft"])
			if fill > 0.0:
				_star(c, 6.0 * (0.5 + 0.5 * fill), Color(0.98, 0.78, 0.3))
		var text: String = ("%.1f" % score) if score >= 0.0 else "Not rated"
		PmText.draw_at(self, Tk.font("body"), at + Vector2(82.0, 0.0), text, Tk.fs(Tk.sz("font_tiny")), Tk.c["text_dim"])

	func _star(c: Vector2, r: float, col: Color) -> void:
		var pts: PackedVector2Array = PackedVector2Array()
		for k: int in 10:
			var ang: float = -PI * 0.5 + float(k) * PI / 5.0
			var rr: float = r if k % 2 == 0 else r * 0.45
			pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
		draw_colored_polygon(pts, col)


class PmIconPaw:
	static func draw_mark(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
		ci.draw_circle(c + Vector2(0.0, r * 0.25), r * 0.45, col)
		for k: int in 4:
			var ang: float = -PI * 0.5 + (float(k) - 1.5) * 0.55
			ci.draw_circle(c + Vector2(cos(ang), sin(ang)) * r * 0.62, r * 0.18, col)

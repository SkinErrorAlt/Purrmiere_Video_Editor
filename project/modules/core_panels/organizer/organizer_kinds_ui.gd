extends RefCounted

const Project := preload("res://doc/project.gd")
const Regions := preload("res://doc/media_regions.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const NEW_COLOURS: PackedStringArray = ["#e5484d", "#f08c3a", "#f2c84b", "#46a758", "#3fb6a8", "#4f8ff7", "#a874e8", "#e870b8"]


static func fill(row: Container, panel: Object, current: String, counts: Dictionary) -> void:
	PmUI.clear(row)
	for k: Dictionary in Kinds.kinds():
		if bool(k.get("hidden", false)):
			continue
		var id: String = String(k["id"])
		var n: int = int(counts.get(id, 0))
		var b: Button = PmButton.make(String(k["name"]) + ("  " + str(n) if n > 0 else ""), "", true)
		b.set("quiet", id != current)
		b.button_pressed = id == current
		b.icon = _dot(Color.from_string(String(k["rgb"]), Color.GRAY))
		PmUI.tip(b, "%s. %s. Right click to change it." % [String(k["name"]), Kinds.function_label(String(k["fn"]))])
		b.pressed.connect(func() -> void: panel.call("set_kind", id))
		b.gui_input.connect(_on_input.bind(b, panel, id))
		b.set_meta("kind_id", id)
		row.add_child(b)
	var add: Button = PmButton.make("New kind", "plus")
	add.set("quiet", true)
	add.pressed.connect(func() -> void: ask_new(add, panel))
	row.add_child(add)


static func _dot(col: Color) -> Texture2D:
	var img: Image = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in 10:
		for x: int in 10:
			var dx: float = float(x) - 4.5
			var dy: float = float(y) - 4.5
			var r: float = sqrt(dx * dx + dy * dy)
			if r <= 4.6:
				img.set_pixel(x, y, Color(col, clampf(4.6 - r + 0.4, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func _on_input(event: InputEvent, b: Button, panel: Object, id: String) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		open_kind_menu(b, panel, id, (event as InputEventMouseButton).global_position)
		b.accept_event()


static func kind_menu_items(id: String) -> Array:
	var k: Dictionary = Kinds.by_id(id)
	var fn_sub: Array = []
	for fn: String in Kinds.FUNCTIONS:
		fn_sub.append(PmMenu.check_item("kind_fn:" + fn, Kinds.function_label(fn), String(k.get("fn", "")) == fn))
	var col_sub: Array = []
	for i: int in NEW_COLOURS.size():
		col_sub.append(PmMenu.item("kind_rgb:" + NEW_COLOURS[i], NEW_COLOURS[i]))
	col_sub.append(PmMenu.item("kind_rgb_typed", "Type a colour..."))
	return [
		PmMenu.item("kind_use", "Colour with this kind"),
		PmMenu.item("kind_rename", "Rename..."),
		PmMenu.sub_item("kind_colours", "Colour", col_sub),
		PmMenu.sub_item("kind_fns", "What it does in the editor", fn_sub),
		PmMenu.item("kind_first", "Go to the first one"),
		PmMenu.separator(),
		PmMenu.item("kind_restore", "Bring back the premade kinds"),
		PmMenu.item("kind_delete", "Delete this kind", "", "trash"),
	]


static func open_kind_menu(anchor: Control, panel: Object, id: String, at: Vector2) -> void:
	var m: Control = PmMenu.open(anchor, kind_menu_items(id), at)
	if m != null and m.is_inside_tree():
		m.connect("picked", func(pick: String) -> void: on_kind_picked(anchor, panel, id, pick))


static func on_kind_picked(host: Node, panel: Object, id: String, pick: String) -> void:
	if pick == "kind_use":
		panel.call("set_kind", id)
	elif pick == "kind_rename":
		_ask(host, "Rename " + Kinds.name_of(id), [{"key": "name", "label": "Name", "default": Kinds.name_of(id)}], func(r: Dictionary) -> void:
			Kinds.change(id, {"name": String(r.get("name", ""))})
			panel.call("refresh")
		)
	elif pick.begins_with("kind_rgb:"):
		Kinds.change(id, {"rgb": pick.substr(9)})
		panel.call("refresh")
	elif pick == "kind_rgb_typed":
		_ask(host, "Colour of " + Kinds.name_of(id), [{"key": "rgb", "label": "Colour, like #ff8800", "default": String(Kinds.by_id(id).get("rgb", ""))}], func(r: Dictionary) -> void:
			var text: String = String(r.get("rgb", "")).strip_edges()
			if not text.begins_with("#"):
				text = "#" + text
			if Color.html_is_valid(text):
				Kinds.change(id, {"rgb": text})
				panel.call("refresh")
		)
	elif pick.begins_with("kind_fn:"):
		Kinds.change(id, {"fn": pick.substr(8)})
		panel.call("refresh")
	elif pick == "kind_first":
		panel.call("set_kind", id)
		panel.get("canvas").call("set_cursor", "", -1.0, false)
		panel.call("jump", 1)
	elif pick == "kind_restore":
		Kinds.restore_defaults()
		panel.call("refresh")
	elif pick == "kind_delete":
		Kinds.remove(id)
		if String(panel.call("current_kind")) == id and not Kinds.kinds().is_empty():
			panel.call("set_kind", String((Kinds.kinds()[0] as Dictionary)["id"]))
		panel.call("refresh")


static func ask_new(host: Node, panel: Object) -> void:
	var fns: Array = []
	for fn: String in Kinds.FUNCTIONS:
		fns.append(Kinds.function_label(fn))
	var pick: String = NEW_COLOURS[Kinds.kinds().size() % NEW_COLOURS.size()]
	_ask(host, "New kind of region", [
		{"key": "name", "label": "Name", "default": ""},
		{"key": "rgb", "label": "Colour", "default": pick},
		{"key": "fn", "label": "In the editor", "type": "enum", "choices": fns, "default": 0},
	], func(r: Dictionary) -> void:
		var fn_i: int = int(r.get("fn", 0))
		var rgb: String = String(r.get("rgb", pick)).strip_edges()
		if not rgb.begins_with("#"):
			rgb = "#" + rgb
		var made: Dictionary = Kinds.add(String(r.get("name", "")), rgb if Color.html_is_valid(rgb) else pick, Kinds.FUNCTIONS[clampi(fn_i, 0, Kinds.FUNCTIONS.size() - 1)])
		if not made.is_empty():
			panel.call("set_kind", String(made["id"]))
		panel.call("refresh")
	)


static func ask_area(host: Node, d: Project, media_id: String, r: Dictionary) -> void:
	var area: Array = r.get("area", [0.0, 0.0, 1.0, 1.0]) if r.get("area") is Array else [0.0, 0.0, 1.0, 1.0]
	_ask(host, "Part of the picture", [
		{"key": "x", "label": "Left, percent", "default": str(snappedf(float(area[0]) * 100.0, 0.1))},
		{"key": "y", "label": "Top, percent", "default": str(snappedf(float(area[1]) * 100.0, 0.1))},
		{"key": "w", "label": "Width, percent", "default": str(snappedf(float(area[2]) * 100.0, 0.1))},
		{"key": "h", "label": "Height, percent", "default": str(snappedf(float(area[3]) * 100.0, 0.1))},
		{"key": "note", "type": "note", "default": "Swear hides this part of the picture as well as the sound, and Blur this part hides it (blur, big pixels or a colour, Settings organizer.hide_picture_with). 0, 0, 100, 100 is the whole picture."},
	], func(res: Dictionary) -> void:
		var x: float = clampf(String(res.get("x", "0")).to_float() / 100.0, 0.0, 1.0)
		var y: float = clampf(String(res.get("y", "0")).to_float() / 100.0, 0.0, 1.0)
		var w: float = clampf(String(res.get("w", "100")).to_float() / 100.0, 0.0, 1.0 - x)
		var h: float = clampf(String(res.get("h", "100")).to_float() / 100.0, 0.0, 1.0 - y)
		var whole: bool = x <= 0.0001 and y <= 0.0001 and w >= 0.9999 and h >= 0.9999
		Regions.change(d, media_id, String(r["id"]), {"area": null if whole or w <= 0.0 or h <= 0.0 else [x, y, w, h]}, "Region picture area")
	)


static func ask_note(host: Node, d: Project, media_id: String, r: Dictionary) -> void:
	_ask(host, "Note", [{"key": "note", "label": "Note", "default": String(r.get("note", ""))}], func(res: Dictionary) -> void:
		var text: String = String(res.get("note", "")).strip_edges()
		Regions.change(d, media_id, String(r["id"]), {"note": text if not text.is_empty() else null}, "Region note")
	)


static func _ask(host: Node, title: String, fields: Array, done: Callable) -> void:
	if host == null or not host.is_inside_tree():
		return
	var typed: Array[Dictionary] = []
	for f: Variant in fields:
		typed.append(f)
	var answered: Signal = PmUI.form(host, title, typed, "Apply", "Cancel")
	answered.connect(func(result: Variant) -> void:
		if result is Dictionary:
			done.call(result)
	)

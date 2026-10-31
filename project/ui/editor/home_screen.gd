extends Control

signal new_project(spec: Dictionary)
signal open_project(path: String)

const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmIcon := preload("res://ui/kit/pm_icon.gd")
const Io := preload("res://doc/io.gd")
const CardsView := preload("res://ui/editor/project_cards_view.gd")
const PREF_RECENT := "app.recent"
const MAX_RECENT := 10
const FPS_CHOICES: Array = ["23.976", "24", "25", "29.97", "30", "50", "59.94", "60"]
const FPS_VALUES: Array = [23.976, 24.0, 25.0, 29.97, 30.0, 50.0, 59.94, 60.0]
const SIZE_CHOICES: Array = ["1920 x 1080", "3840 x 2160", "1280 x 720", "1080 x 1920 (vertical)", "1080 x 1080 (square)"]
const SIZE_VALUES: Array = [[1920, 1080], [3840, 2160], [1280, 720], [1080, 1920], [1080, 1080]]
const PROJECT_EXT := "purrmiere"

var _card: PanelContainer = null
var _recent_box: VBoxContainer = null
var _dialog: FileDialog = null
var cards_view: Control = null


static func register_prefs() -> void:
	if not Prefs.is_registered(PREF_RECENT):
		Prefs.register(PREF_RECENT, [], {"label": "Recent projects", "type": "list"})
	if not Prefs.is_registered("project.default_fps"):
		Prefs.register("project.default_fps", "60", {"label": "New project frame rate", "type": "enum", "choices": FPS_CHOICES})
		Prefs.register("project.default_size", "1920 x 1080", {"label": "New project frame size", "type": "enum", "choices": SIZE_CHOICES})
		Prefs.register("project.default_tracks", 3, {"label": "New project tracks (video and audio)", "type": "int", "min": 1, "max": 32})
		Prefs.register("project.folder", Prefs.data_path("Projects"), {"label": "Folder new projects are saved in", "type": "string"})
		Prefs.register("project.auto_create", false, {"label": "Create new projects with these defaults without asking", "type": "bool"})


static func default_spec(name_: String = "Untitled") -> Dictionary:
	register_prefs()
	var fps_i: int = maxi(0, FPS_CHOICES.find(String(Prefs.get_value("project.default_fps"))))
	var size_i: int = maxi(0, SIZE_CHOICES.find(String(Prefs.get_value("project.default_size"))))
	return spec_from_answer({"name": name_, "folder": String(Prefs.get_value("project.folder")), "fps": fps_i, "size": size_i, "tracks": int(Prefs.get_value("project.default_tracks"))})


static func auto_create() -> bool:
	register_prefs()
	return bool(Prefs.get_value("project.auto_create"))


static func recent() -> PackedStringArray:
	register_prefs()
	var out := PackedStringArray()
	for p: String in Io.recent_projects():
		if not p.is_empty() and FileAccess.file_exists(p):
			out.append(p)
	return out


static func remember(path: String) -> void:
	if path.is_empty():
		return
	register_prefs()
	Io.remember_recent(path)


static func forget(path: String) -> void:
	register_prefs()
	var prefs: Node = Engine.get_main_loop().root.get_node_or_null("/root/Prefs") if Engine.get_main_loop() is SceneTree else null
	if prefs == null:
		return
	var list: Array = []
	for p: String in Io.recent_projects():
		if p != path:
			list.append(p)
	prefs.call("set_value", Io.PREF_RECENT, list)


func _init() -> void:
	name = "HomeScreen"
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = PmUI.fill("bg_app")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_card = PmUI.panel("bg_panel")
	var sb: StyleBoxFlat = _card.get_theme_stylebox("panel")
	sb.border_color = Tk.c["border"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(Tk.px(Tk.sz("radius_panel")) + 2)
	sb.anti_aliasing = true
	sb.shadow_color = Tk.c["shadow"]
	sb.shadow_size = Tk.px(16.0)
	sb.shadow_offset = Vector2(0.0, float(Tk.px(5.0)))
	var pad: float = float(Tk.px(Tk.sz("pad"))) * 4.0
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	_card.custom_minimum_size = Vector2(float(Tk.px(440.0)), 0.0)
	_card.custom_minimum_size.x = maxf(_card.custom_minimum_size.x, CardsView.CARD_W * 3.0 + 60.0)
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_card)
	var col: VBoxContainer = PmUI.vbox(Tk.px(Tk.sz("pad")) * 2)
	_card.add_child(col)
	var head: HBoxContainer = PmUI.hbox(Tk.px(Tk.sz("pad")) * 2)
	var mark: Control = PmIcon.paw(float(Tk.px(38.0)), true)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(mark)
	var titles: VBoxContainer = PmUI.vbox(0)
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_child(PmLabel.display("Purrmiere"))
	titles.add_child(PmLabel.meta("Video editor"))
	head.add_child(titles)
	col.add_child(head)
	var lead: Label = PmLabel.body("Cuts, keyframes and exports in one quiet room.", "text_dim")
	col.add_child(lead)
	var row: HBoxContainer = PmUI.hbox(Tk.px(Tk.sz("gap")) * 2)
	var nb: Button = PmButton.primary("New project", "plus")
	nb.pressed.connect(_on_new)
	row.add_child(nb)
	var ob: Button = PmButton.make("Open", "folder")
	ob.pressed.connect(_on_open)
	row.add_child(ob)
	col.add_child(row)
	col.add_child(PmUI.divider())
	col.add_child(PmLabel.meta("Recent"))
	_recent_box = PmUI.vbox(2)
	col.add_child(_recent_box)
	refresh_recent()
	Prefs.changed.connect(_on_pref_changed)
	_card.modulate.a = 0.0
	(func() -> void: PmUI.pop_in(_card, Tk.dur("page"), 14.0, 0.99)).call_deferred()


func _on_pref_changed(key: String) -> void:
	if key == PREF_RECENT or key == Io.PREF_RECENT:
		refresh_recent()


func refresh_recent() -> void:
	var list: PackedStringArray = recent()
	if cards_view != null and is_instance_valid(cards_view) and cards_view.get_parent() == _recent_box:
		cards_view.call("set_paths", list)
		return
	PmUI.clear(_recent_box)
	if list.is_empty():
		_recent_box.add_child(PmLabel.faint("No recent projects"))
		return
	cards_view = CardsView.new()
	cards_view.connect("open_project", _on_recent)
	cards_view.connect("forget_project", func(p: String) -> void:
		forget(p)
		refresh_recent()
	)
	_recent_box.add_child(cards_view)
	cards_view.call("set_paths", list)


func _on_recent(path: String) -> void:
	open_project.emit(path)


static func form_fields() -> Array[Dictionary]:
	register_prefs()
	var out: Array[Dictionary] = []
	out.append({"key": "name", "label": "Name", "type": "string", "default": "Untitled"})
	out.append({"key": "folder", "label": "Folder", "type": "string", "default": String(Prefs.get_value("project.folder"))})
	out.append({"key": "fps", "label": "Frame rate", "type": "enum", "choices": FPS_CHOICES, "default": maxi(0, FPS_CHOICES.find(String(Prefs.get_value("project.default_fps"))))})
	out.append({"key": "size", "label": "Frame size", "type": "enum", "choices": SIZE_CHOICES, "default": maxi(0, SIZE_CHOICES.find(String(Prefs.get_value("project.default_size"))))})
	out.append({"key": "tracks", "label": "Tracks (video and audio)", "type": "int", "default": int(Prefs.get_value("project.default_tracks"))})
	return out


static func spec_from_answer(a: Dictionary) -> Dictionary:
	var fps_i: int = clampi(int(a.get("fps", 4)), 0, FPS_VALUES.size() - 1)
	var size_i: int = clampi(int(a.get("size", 0)), 0, SIZE_VALUES.size() - 1)
	var dims: Array = SIZE_VALUES[size_i]
	var name_: String = String(a.get("name", "")).strip_edges()
	if name_.is_empty():
		name_ = "Untitled"
	return {
		"name": name_,
		"folder": String(a.get("folder", "")),
		"fps": float(FPS_VALUES[fps_i]),
		"width": int(dims[0]),
		"height": int(dims[1]),
		"tracks": clampi(int(a.get("tracks", 3)), 1, 32),
	}


func _on_new() -> void:
	if auto_create():
		new_project.emit(default_spec())
		return
	var answered: Signal = PmUI.form(self, "New project", form_fields(), "Create", "Cancel")
	answered.connect(_on_form_answered)


func _on_form_answered(result: Variant) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	new_project.emit(spec_from_answer(result))


func _on_open() -> void:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.use_native_dialog = true
		_dialog.filters = PackedStringArray(["*." + PROJECT_EXT + " ; Purrmiere project"])
		_dialog.title = "Open project"
		_dialog.file_selected.connect(_on_file_selected)
		add_child(_dialog)
	_dialog.popup_centered(Vector2i(900, 600))


func _on_file_selected(path: String) -> void:
	open_project.emit(path)

extends Window

signal closed
signal action(id: String)
signal moved

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmDragLayer := preload("res://ui/kit/pm_drag_layer.gd")
const PmScreenWindow := preload("res://ui/kit/pm_screen_window.gd")
const GROUP := "pm_float_window"
const TIP_GROUP := "pm_tip"
const PREF_PREFIX := "ui.float."
const OLD_PREF_PREFIX := "ui.window."
const MIN_PX := Vector2i(220, 140)
const SAVE_DELAY := 0.5
const DRAG_SLOP := 6.0
const ACTION_DOCK := "dock"
const ACTION_CLOSE := "close"

var panel_id: String = ""
var key: String = ""
var key_router: Callable = Callable()
var focus_cb: Callable = Callable()
var close_guard: Callable = Callable()
var _back: ColorRect = null
var _strip: HBoxContainer = null
var _tab: Label = null
var _dock_btn: Button = null
var _more_btn: Button = null
var _body: Control = null
var _overlay: Control = null
var _tip: Control = null
var _last_rect: Rect2i = Rect2i()
var _save_wait: float = -1.0
var _closing: bool = false
var _tab_down: bool = false
var _tab_from: Vector2 = Vector2.ZERO


static func supported() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if not DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
		return false
	return true


static func make(title_: String, id: String) -> Window:
	var w: Window = load("res://ui/dock/dock_float_window.gd").new()
	w.visible = false
	w.title = title_
	w.set("panel_id", id)
	w.set("key", "panel." + id)
	w.force_native = true
	w.borderless = false
	w.exclusive = false
	w.transient = true
	w.unresizable = false
	w.unfocusable = false
	w.min_size = MIN_PX
	w.wrap_controls = false
	return w


static func screen_rects() -> Array[Rect2i]:
	return PmScreenWindow.screen_rects()


static func fit_on_screens(want: Rect2i, fallback_screen: int) -> Rect2i:
	var rects: Array[Rect2i] = screen_rects()
	var r: Rect2i = Rect2i(want.position, Vector2i(maxi(want.size.x, MIN_PX.x), maxi(want.size.y, MIN_PX.y)))
	for s: Rect2i in rects:
		var shown: Rect2i = s.intersection(r)
		if shown.size.x >= PmScreenWindow.MIN_SHOWN and shown.size.y >= PmScreenWindow.MIN_SHOWN:
			return r
	if rects.is_empty():
		return r
	var s2: Rect2i = rects[clampi(fallback_screen, 0, rects.size() - 1)]
	var sz: Vector2i = Vector2i(mini(r.size.x, s2.size.x), mini(r.size.y, s2.size.y))
	return Rect2i(s2.position + (s2.size - sz) / 2, sz)


func _init() -> void:
	add_to_group(GROUP)
	_back = ColorRect.new()
	_back.name = "Back"
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_back)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(col)
	_strip = HBoxContainer.new()
	_strip.name = "Strip"
	_strip.mouse_filter = Control.MOUSE_FILTER_STOP
	_strip.gui_input.connect(_on_strip_input)
	col.add_child(_strip)
	_tab = Label.new()
	_tab.name = "Tab"
	_tab.mouse_filter = Control.MOUSE_FILTER_STOP
	_tab.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_tab.gui_input.connect(_on_tab_input)
	_tab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_strip.add_child(_tab)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(gap)
	_dock_btn = PmButton.make("Dock back", "dock_panel")
	_dock_btn.set("quiet", true)
	_dock_btn.pressed.connect(_on_dock_pressed)
	_strip.add_child(_dock_btn)
	_more_btn = PmButton.make("", "more")
	_more_btn.set("quiet", true)
	_more_btn.pressed.connect(_open_menu.bind(Vector2(INF, INF)))
	_strip.add_child(_more_btn)
	_body = Control.new()
	_body.name = "Body"
	_body.clip_contents = true
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_body)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	set_meta(PmUI.WINDOW_OVERLAY_META, _overlay)
	close_requested.connect(_on_close_requested)
	window_input.connect(_on_window_input)
	focus_entered.connect(_on_focus_entered)


func _ready() -> void:
	_back.color = Tk.c["bg_panel"]
	_tab.text = title
	_tab.add_theme_font_override("font", Tk.font("body_semibold"))
	_tab.add_theme_color_override("font_color", Tk.c["text_bright"])
	var pad: int = Tk.px(Tk.sz("pad"))
	_tab.custom_minimum_size = Vector2(0.0, float(Tk.px(Tk.sz("tab_h"))))
	var tsb := StyleBoxEmpty.new()
	tsb.content_margin_left = float(pad) * 1.5
	tsb.content_margin_right = float(pad) * 1.5
	_tab.add_theme_stylebox_override("normal", tsb)
	_tab.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_body")))
	_strip.add_theme_constant_override("separation", Tk.px(Tk.sz("gap")))
	var lead: Control = Control.new()
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lead.custom_minimum_size = Vector2(float(pad), 0.0)
	_strip.add_child(lead)
	_strip.move_child(lead, 0)
	var tail: Control = Control.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.custom_minimum_size = Vector2(2.0, 0.0)
	_strip.add_child(tail)
	_strip.draw.connect(_draw_strip)
	_strip.resized.connect(_strip.queue_redraw)
	_more_btn.set("icon_px", 14.0)
	PmUI.tip(_dock_btn, "Put this panel back into the app, in the focused panel group")
	PmUI.tip(_more_btn, "Panel window menu")
	PmUI.tip(_tab, "Drag this tab back over the app to dock it where you drop it")
	var tip_script: GDScript = load("res://ui/kit/pm_tip.gd")
	_tip = tip_script.new()
	if _tip.is_in_group(TIP_GROUP):
		_tip.remove_from_group(TIP_GROUP)
	_overlay.add_child(_tip)
	set_meta(PmUI.WINDOW_TIP_META, _tip)
	_last_rect = rect()
	set_process(true)


func _draw_strip() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, _strip.size)
	_strip.draw_rect(r, Tk.c["bg_panel_alt"], true)
	_strip.draw_rect(Rect2(0.0, r.size.y - 1.0, r.size.x, 1.0), Tk.c["border"], true)
	var tr: Rect2 = _tab.get_rect()
	_strip.draw_rect(Rect2(tr.position.x, r.size.y - 2.0, tr.size.x, 2.0), Tk.c["accent"], true)


func set_content(c: Control) -> void:
	PmUI.clear(_body)
	if c.get_parent() != null:
		c.get_parent().remove_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.add_child(c)


func content() -> Control:
	if _body != null and _body.get_child_count() > 0:
		return _body.get_child(0)
	return null


func take_content() -> Control:
	var c: Control = content()
	if c != null:
		_body.remove_child(c)
	return c


func overlay() -> Control:
	return _overlay


func strip() -> Control:
	return _strip


func tab() -> Control:
	return _tab


func dock_button() -> Button:
	return _dock_btn


func rect() -> Rect2i:
	return Rect2i(position, size)


func place(r: Rect2i) -> void:
	position = r.position
	size = r.size
	_last_rect = r


func place_at(p: Vector2i) -> void:
	var r: Rect2i = fit_on_screens(Rect2i(p, size), current_screen)
	position = r.position
	size = r.size


func raise() -> void:
	if not visible:
		visible = true
	grab_focus()


func layout_entry() -> Dictionary:
	var r: Rect2i = rect()
	return {"id": panel_id, "x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y, "native": true}


func _pref_key() -> String:
	return PREF_PREFIX + key


static func saved_rect(key_: String) -> Rect2i:
	var pk: String = PREF_PREFIX + key_
	if not Prefs.is_registered(pk):
		Prefs.register(pk, {}, {"label": "Panel window place: " + key_, "type": "rect"})
	var d: Variant = Prefs.get_value(pk)
	if typeof(d) != TYPE_DICTIONARY:
		return Rect2i()
	var dd: Dictionary = d
	if not (dd.has("x") and dd.has("y") and dd.has("w") and dd.has("h")):
		return Rect2i()
	return Rect2i(int(dd["x"]), int(dd["y"]), int(dd["w"]), int(dd["h"]))


static func old_rect(key_: String) -> Rect2i:
	var pk: String = OLD_PREF_PREFIX + key_
	if not Prefs.is_registered(pk):
		return Rect2i()
	var d: Variant = Prefs.get_value(pk)
	if typeof(d) != TYPE_DICTIONARY:
		return Rect2i()
	var dd: Dictionary = d
	if not (dd.has("x") and dd.has("y") and dd.has("w") and dd.has("h")):
		return Rect2i()
	return Rect2i(int(float(dd["x"])), int(float(dd["y"])), int(float(dd["w"])), int(float(dd["h"])))


func persist() -> void:
	if key.is_empty():
		return
	var r: Rect2i = rect()
	if mode != Window.MODE_WINDOWED or r.size.x < MIN_PX.x or r.size.y < MIN_PX.y:
		return
	saved_rect(key)
	Prefs.set_value(_pref_key(), {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y})


func _process(dt: float) -> void:
	if _closing or mode != Window.MODE_WINDOWED:
		return
	var r: Rect2i = rect()
	if r != _last_rect:
		_last_rect = r
		_save_wait = SAVE_DELAY
		var loop: MainLoop = Engine.get_main_loop()
		var s: Node = (loop as SceneTree).root.get_node_or_null("Session") if loop is SceneTree else null
		if s != null and s.has_method("note_window_move"):
			s.call("note_window_move")
		return
	if _save_wait >= 0.0:
		_save_wait -= dt
		if _save_wait < 0.0:
			persist()
			moved.emit()


func close() -> void:
	if _closing:
		return
	_closing = true
	persist()
	closed.emit()
	PmUI.free_node(self)


func begin_close() -> void:
	_closing = true


func _on_close_requested() -> void:
	if close_guard.is_valid() and not bool(close_guard.call()):
		return
	close()


func _on_dock_pressed() -> void:
	action.emit(ACTION_DOCK)


func _on_focus_entered() -> void:
	if focus_cb.is_valid():
		focus_cb.call()


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and focus_cb.is_valid():
		focus_cb.call()


func _shortcut_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.keycode == KEY_ESCAPE and k.pressed:
		var owner: Control = gui_get_focus_owner()
		if owner != null:
			owner.release_focus()
			set_input_as_handled()
			return
	if key_router.is_valid() and bool(key_router.call(k)):
		set_input_as_handled()


func menu_items() -> Array:
	return [PmMenu.item(ACTION_DOCK, "Dock back", "", "dock_panel"), PmMenu.item(ACTION_CLOSE, "Close panel", "", "close")]


func _open_menu(at: Vector2) -> Control:
	var m: Control = PmMenu.open(_more_btn, menu_items(), at)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_menu_picked)
	return m


func _on_menu_picked(id: String) -> void:
	if id == ACTION_CLOSE:
		close()
	elif id == ACTION_DOCK:
		action.emit(ACTION_DOCK)


func _on_strip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_open_menu(_strip.get_global_transform() * mb.position)
			_strip.accept_event()


func _on_tab_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_open_menu(_tab.get_global_transform() * mb.position)
			_tab.accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_tab_down = mb.pressed
		_tab_from = mb.position
		if mb.pressed and mb.double_click:
			_tab_down = false
			action.emit(ACTION_DOCK)
		_tab.accept_event()
		return
	if event is InputEventMouseMotion and _tab_down:
		var mm: InputEventMouseMotion = event
		if mm.position.distance_to(_tab_from) < DRAG_SLOP:
			return
		_tab_down = false
		begin_dock_drag()
		_tab.accept_event()


func begin_dock_drag() -> bool:
	var layer: CanvasLayer = PmDragLayer.find(get_parent() if get_parent() != null else self)
	if layer == null:
		return false
	var card: PanelContainer = PmUI.panel("bg_panel_high")
	var l: Label = PmLabel.tight(title, "text_bright")
	card.add_child(l)
	layer.call("begin", {"kind": "panel", "id": panel_id, "from": -1, "window": true}, card, Vector2(24.0, 12.0))
	return true

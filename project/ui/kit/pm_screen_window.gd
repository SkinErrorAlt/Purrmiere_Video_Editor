extends Window

const VERSION := 2
const MIN_PX := Vector2i(320, 200)
const SAVE_DELAY := 0.6
const TIP_GROUP := "pm_tip"
const MIN_SHOWN := 64

signal closed
signal fullscreen_changed(on: bool)
signal key_unhandled(event: InputEventKey)

var slot: Control = null
var bar: Control = null
var rect_pref: String = ""
var screen_pref: String = ""
var fullscreen_on: bool = false
var mode_setter: Callable = Callable()
var _fill: ColorRect = null
var _column: VBoxContainer = null
var _bar_holder: Control = null
var _body: Control = null
var _overlay: Control = null
var _tip: Control = null
var _windowed_rect: Rect2i = Rect2i()
var _last_rect: Rect2i = Rect2i()
var _save_wait: float = -1.0
var _closing: bool = false


static func make(title_: String, screen: int) -> Window:
	var w: Window = load("res://ui/kit/pm_screen_window.gd").new()
	w.visible = false
	w.title = title_
	w.force_native = true
	w.borderless = false
	w.exclusive = false
	w.transient = false
	w.unresizable = false
	w.unfocusable = bool(ProjectSettings.get_setting("display/window/size/no_focus", false))
	w.min_size = MIN_PX
	w.set_meta("pm_screen", clampi(screen, 0, maxi(DisplayServer.get_screen_count() - 1, 0)))
	return w


static func other_screens() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var here: int = DisplayServer.window_get_current_screen(DisplayServer.MAIN_WINDOW_ID)
	for i: int in DisplayServer.get_screen_count():
		if i != here:
			out.append(i)
	return out


static func screen_label(i: int) -> String:
	var size_: Vector2i = DisplayServer.screen_get_size(i)
	return "Screen %d, %d by %d" % [i + 1, size_.x, size_.y]


static func screen_rects() -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for i: int in DisplayServer.get_screen_count():
		var r: Rect2i = DisplayServer.screen_get_usable_rect(i)
		if r.size.x <= 0 or r.size.y <= 0:
			r = Rect2i(DisplayServer.screen_get_position(i), DisplayServer.screen_get_size(i))
		out.append(r)
	return out


static func rect_text(r: Rect2i) -> String:
	return "%d,%d,%d,%d" % [r.position.x, r.position.y, r.size.x, r.size.y]


static func parse_rect(text: String) -> Rect2i:
	var parts: PackedStringArray = text.split(",")
	if parts.size() != 4:
		return Rect2i()
	for p: String in parts:
		if not p.strip_edges().is_valid_int():
			return Rect2i()
	return Rect2i(int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3]))


static func rect_for(saved: Rect2i, screen: int, screens: Array[Rect2i]) -> Rect2i:
	var saved_ok: bool = saved.size.x >= MIN_PX.x and saved.size.y >= MIN_PX.y
	var want: Rect2i = screens[clampi(screen, 0, screens.size() - 1)] if not screens.is_empty() else Rect2i()
	if want.size.x <= 0 or want.size.y <= 0:
		return saved if saved_ok else Rect2i(Vector2i(80, 80), Vector2i(960, 540))
	if saved_ok:
		var shown: Rect2i = want.intersection(saved)
		if shown.size.x >= MIN_SHOWN and shown.size.y >= MIN_SHOWN:
			return saved
	var sz: Vector2i = Vector2i(maxi(int(float(want.size.x) * 0.6), MIN_PX.x), maxi(int(float(want.size.y) * 0.6), MIN_PX.y))
	return Rect2i(want.position + (want.size - sz) / 2, sz)


static func screen_of(r: Rect2i, screens: Array[Rect2i]) -> int:
	var best: int = -1
	var best_area: int = 0
	for i: int in screens.size():
		var shown: Rect2i = screens[i].intersection(r)
		var area: int = shown.size.x * shown.size.y
		if area > best_area:
			best_area = area
			best = i
	return best


func place(r: Rect2i) -> void:
	position = r.position
	size = r.size
	_last_rect = r
	_windowed_rect = r


func _ready() -> void:
	_fill = ColorRect.new()
	_fill.name = "Fill"
	_fill.color = Tk.c["bg_app"]
	_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column.add_theme_constant_override("separation", 0)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	_bar_holder = VBoxContainer.new()
	_bar_holder.name = "Bar"
	_bar_holder.add_theme_constant_override("separation", 0)
	_bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_bar_holder)
	_body = Control.new()
	_body.name = "Body"
	_body.clip_contents = true
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_child(_body)
	if slot != null:
		_mount(slot)
	if bar != null:
		set_bar(bar)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var tip_script: GDScript = load("res://ui/kit/pm_tip.gd")
	_tip = tip_script.new()
	if _tip.is_in_group(TIP_GROUP):
		_tip.remove_from_group(TIP_GROUP)
	_overlay.add_child(_tip)
	close_requested.connect(_on_close_requested)
	set_process(true)
	visible = true


func _mount(c: Control) -> void:
	if c.get_parent() != null:
		c.get_parent().remove_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.add_child(c)


func set_slot(c: Control) -> void:
	slot = c
	if _body != null and c != null:
		_mount(c)


func set_bar(c: Control) -> void:
	bar = c
	if _bar_holder == null or c == null:
		return
	if c.get_parent() != _bar_holder:
		if c.get_parent() != null:
			c.get_parent().remove_child(c)
		_bar_holder.add_child(c)
	c.visible = not fullscreen_on


func overlay() -> Control:
	return _overlay


func is_native() -> bool:
	return is_inside_tree() and not is_embedded()


func take_back() -> Control:
	var c: Control = slot
	slot = null
	if c != null and c.get_parent() != null and (c.get_parent() == _body or c.get_parent() == self):
		c.get_parent().remove_child(c)
	return c


func set_fullscreen(on: bool) -> void:
	if on == fullscreen_on:
		return
	if on:
		_windowed_rect = Rect2i(position, size)
	fullscreen_on = on
	_apply_mode(Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED)
	if not on and _windowed_rect.size.x > 0 and _windowed_rect.size.y > 0:
		position = _windowed_rect.position
		size = _windowed_rect.size
	if bar != null:
		bar.visible = not on
	fullscreen_changed.emit(on)


func _apply_mode(m: Window.Mode) -> void:
	if mode_setter.is_valid():
		mode_setter.call(m)
		return
	mode = m


func open_menu(anchor: Control, items: Array, at: Vector2 = Vector2(INF, INF)) -> Control:
	var script: GDScript = load("res://ui/kit/pm_menu.gd")
	var m: Control = script.new()
	m.set("items", items)
	m.set("anchor", anchor)
	if _overlay == null:
		return m
	_overlay.add_child(m)
	if at.x != INF or anchor == null:
		m.set("follow_anchor", false)
		m.call("place_at", at if at.x != INF else Vector2.ZERO)
	else:
		m.set("anchor_offset", Vector2(0.0, anchor.size.y))
		m.call("place_at", anchor.global_position + Vector2(0.0, anchor.size.y))
	m.call("take_keys")
	return m


func menu_open() -> bool:
	if _overlay == null:
		return false
	for c: Node in _overlay.get_children():
		if c != _tip:
			return true
	return false


func tip(control: Control, text_: String, keys_: String = "") -> void:
	if control == null:
		return
	control.set_meta("pm_tip_text", text_)
	control.set_meta("pm_tip_keys", keys_)
	if control.has_meta("pm_window_tip"):
		return
	control.set_meta("pm_window_tip", true)
	control.mouse_entered.connect(_tip_enter.bind(control))
	control.mouse_exited.connect(_tip_exit.bind(control))


func _tip_enter(control: Control) -> void:
	if _tip != null:
		_tip.call("arm", control)


func _tip_exit(control: Control) -> void:
	if _tip != null:
		_tip.call("disarm", control)


func _shortcut_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed:
		return
	var plain: bool = not (k.ctrl_pressed or k.alt_pressed or k.shift_pressed or k.meta_pressed)
	if k.keycode == KEY_F11 and plain:
		if not k.echo:
			set_fullscreen(not fullscreen_on)
		set_input_as_handled()
		return
	if (k.keycode == KEY_ESCAPE or (k.keycode == KEY_QUOTELEFT and plain)) and fullscreen_on:
		if not k.echo:
			set_fullscreen(false)
		set_input_as_handled()
		return
	key_unhandled.emit(k)


func _process(dt: float) -> void:
	if fullscreen_on or mode != Window.MODE_WINDOWED or _closing:
		return
	var r: Rect2i = Rect2i(position, size)
	if r != _last_rect:
		_last_rect = r
		_save_wait = SAVE_DELAY
		return
	if _save_wait >= 0.0:
		_save_wait -= dt
		if _save_wait < 0.0:
			save_rect()


func windowed_rect() -> Rect2i:
	if fullscreen_on:
		return _windowed_rect
	return Rect2i(position, size)


func save_rect() -> void:
	var r: Rect2i = windowed_rect()
	if r.size.x < MIN_PX.x or r.size.y < MIN_PX.y:
		return
	if not rect_pref.is_empty() and Prefs.is_registered(rect_pref):
		Prefs.set_value(rect_pref, rect_text(r))
	if not screen_pref.is_empty() and Prefs.is_registered(screen_pref):
		var sc: int = screen_of(r, screen_rects())
		if sc >= 0:
			Prefs.set_value(screen_pref, sc)


func _on_close_requested() -> void:
	if _closing:
		return
	save_rect()
	closed.emit()


func begin_close() -> void:
	_closing = true

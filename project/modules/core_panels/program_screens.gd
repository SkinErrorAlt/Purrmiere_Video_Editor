extends RefCounted

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const PmScreenWindow := preload("res://ui/kit/pm_screen_window.gd")
const MonitorView := preload("res://modules/core_panels/monitor_view.gd")
const FullQuality := preload("res://engine/full_quality.gd")

const PREF_OUT_MODE := "program.outside.mode"
const PREF_OUT_AMOUNT := "program.outside.amount"
const PREF_OUT_TINT := "program.outside.tint"
const PREF_OUT_MOSTLY := "program.outside.only_mostly"
const PREF_OUT_SHARE := "program.outside.share"
const PREF_FULL_ZOOM := "program.fullscreen.zoom"
const PREF_POP_FULL_ZOOM := "program.popout.fullscreen_zoom"
const PREF_POP_RECT := "program.popout.rect"
const PREF_POP_SCREEN := "program.popout.screen"
const PREF_POP_SOUND := "program.popout.sound"
const PREF_POP_DEVICE := "program.popout.device"
const PREF_POP_HANDLES := "program.popout.handles"
const PREF_APP_DEVICE := "audio.output_device"
const PREF_SCREEN := "program.screen"
const CMD_POPOUT := "view.program_popout"
const CMD_FULL := "view.program_fullscreen"
const POPOUT_TITLE := "Program"
const OUT_MODES: PackedStringArray = ["hidden", "faded", "darkened", "lightened", "tinted"]
const OUT_LABELS: Dictionary = {"hidden": "Hidden", "faded": "Faded", "darkened": "Darkened", "lightened": "Lightened", "tinted": "Tinted"}
const AMOUNTS: Array = [0.25, 0.5, 0.75, 0.9]
const SHARES: Array = [[0.25, "More than a quarter"], [0.5, "More than half"], [0.75, "More than three quarters"]]
const TINTS: Array = [["Red", "#ff0000"], ["Orange", "#ff8000"], ["Yellow", "#ffe000"], ["Green", "#00c040"], ["Blue", "#2060ff"], ["Magenta", "#ff00c0"]]
const FULL_CHOICES: PackedStringArray = ["fit", "fill", "pixels", "keep"]
const FULL_LABELS: Dictionary = {"fit": "Fit", "fill": "Fill", "pixels": "100 percent pixels", "keep": "Keep my zoom and pan"}

var popout: Window = null
var window_mode_setter: Callable = Callable()
var popout_mode_setter: Callable = Callable()
var device_lister: Callable = Callable()
var device_getter: Callable = Callable()
var device_setter: Callable = Callable()
var _panel_ref: WeakRef = null
var _full: Control = null
var _full_prev_parent: Node = null
var _full_prev_index: int = 0
var _full_mode_before: int = -1
var _view_before: Dictionary = {}
var _pop_view_before: Dictionary = {}
var _strip: Control = null
var _pop_prev_parent: Node = null
var _pop_prev_index: int = 0
var _pop_zoom: Button = null
var _pop_sound: Button = null
var _pop_device: Button = null
var _pop_full: Button = null
var _pop_fq: Button = null
var _full_menu: Control = null
var _comp: Node = null
var _last_pic: Rect2 = Rect2()
var _last_size: Vector2 = Vector2.ZERO
var _last_quality: int = -1
var _last_seq_px: Vector2i = Vector2i.ZERO
var _pending_overscan: bool = true
var _reveal_need: Vector2 = Vector2.ZERO
var _reveal_count: int = 0
var _tint_window: Control = null


func _init(panel_: Object) -> void:
	_panel_ref = weakref(panel_)


static func ensure_prefs(prefs: Node) -> void:
	var specs: Array = [
		[PREF_OUT_MODE, "hidden", {"label": "Program: outside the frame (hidden, faded, darkened, lightened, tinted)", "type": "enum", "choices": Array(OUT_MODES)}],
		[PREF_OUT_AMOUNT, 0.5, {"label": "Program: how strong the outside look is", "type": "float", "min": 0.0, "max": 1.0}],
		[PREF_OUT_TINT, "#ff0000", {"label": "Program: tint colour for the outside", "type": "string"}],
		[PREF_OUT_MOSTLY, false, {"label": "Program: show the outside only when a clip is mostly outside", "type": "bool"}],
		[PREF_OUT_SHARE, 0.5, {"label": "Program: share of a clip outside the frame that counts as mostly", "type": "float", "min": 0.05, "max": 0.95}],
		[PREF_FULL_ZOOM, "fit", {"label": "Program fullscreen shows (fit, fill, pixels, keep)", "type": "enum", "choices": Array(FULL_CHOICES)}],
		[PREF_POP_FULL_ZOOM, "fit", {"label": "Pop out fullscreen shows (fit, fill, pixels, keep)", "type": "enum", "choices": Array(FULL_CHOICES)}],
		[PREF_POP_RECT, "", {"label": "Pop out window place and size", "type": "string"}],
		[PREF_POP_SCREEN, -1, {"label": "Pop out window screen", "type": "int", "min": -1, "max": 7}],
		[PREF_POP_SOUND, false, {"label": "Sound from the pop out", "type": "bool"}],
		[PREF_POP_DEVICE, "", {"label": "Pop out sound goes to this output device", "type": "string"}],
		[PREF_POP_HANDLES, false, {"label": "The pop out shows the transform handles and the selection outline", "type": "bool"}],
	]
	for spec: Array in specs:
		if not bool(prefs.call("is_registered", String(spec[0]))):
			prefs.call("register", String(spec[0]), spec[1], spec[2])


func panel() -> Object:
	if _panel_ref == null:
		return null
	return _panel_ref.get_ref()


func view() -> Control:
	var p: Object = panel()
	if p == null:
		return null
	var v: Variant = p.get("view")
	return v if v != null and is_instance_valid(v) and v is Control else null


func setup() -> void:
	ensure_prefs(Prefs)
	var v: Control = view()
	if v != null and not v.is_connected("picture_input", _on_picture_input):
		v.connect("picture_input", _on_picture_input)
	_apply_outside()


func _request_render() -> void:
	var p: Object = panel()
	if p != null and p.has_method("_request_render"):
		p.call("_request_render", false)


func on_pref(key: String) -> bool:
	if key.begins_with("program.outside."):
		_apply_outside()
		return true
	if key == PREF_POP_SOUND or key == PREF_POP_DEVICE:
		_apply_sound()
		_refresh_bar()
		return true
	if key == PREF_APP_DEVICE:
		_apply_sound()
		return true
	if key == PREF_POP_HANDLES:
		var v: Control = view()
		if v != null:
			v.call("redraw_overlay")
		return true
	if key == PREF_FULL_ZOOM or key == PREF_POP_FULL_ZOOM or key == PREF_POP_RECT or key == PREF_POP_SCREEN:
		return true
	return false


func tick(_dt: float) -> void:
	var comp: Node = Session.compositor
	if comp != _comp:
		_bind_comp(comp)
	var v: Control = view()
	if v == null:
		return
	var pic: Rect2 = v.call("picture_rect")
	var q: int = int(comp.get("quality")) if comp != null and is_instance_valid(comp) else 0
	var s: Object = Session.seq()
	var seq_px: Vector2i = Vector2i(int(s.get("width")), int(s.get("height"))) if s != null else Vector2i.ZERO
	if _pending_overscan or pic != _last_pic or v.size != _last_size or q != _last_quality or seq_px != _last_seq_px:
		_last_pic = pic
		_last_size = v.size
		_last_quality = q
		_last_seq_px = seq_px
		_pending_overscan = false
		update_overscan()
	if popout != null and not is_instance_valid(popout):
		popout = null


func _bind_comp(comp: Node) -> void:
	if _comp != null and is_instance_valid(_comp) and _comp.is_connected("rendered", _on_rendered):
		_comp.disconnect("rendered", _on_rendered)
	_comp = comp if comp != null and is_instance_valid(comp) else null
	if _comp != null and _comp.has_signal("rendered") and not _comp.is_connected("rendered", _on_rendered):
		_comp.connect("rendered", _on_rendered)
	_pending_overscan = true


func outside_mode() -> String:
	var m: String = String(Prefs.get_value(PREF_OUT_MODE))
	return m if OUT_MODES.has(m) else "hidden"


func only_mostly() -> bool:
	return bool(Prefs.get_value(PREF_OUT_MOSTLY))


func tint_colour() -> Color:
	return Color.from_string(String(Prefs.get_value(PREF_OUT_TINT)), Color(1.0, 0.0, 0.0, 1.0))


func _apply_outside() -> void:
	var v: Control = view()
	if v == null:
		return
	v.call("set_outside", OUT_MODES.find(outside_mode()), float(Prefs.get_value(PREF_OUT_AMOUNT)), tint_colour())
	_refresh_reveal()
	update_overscan()


func wanted_margin() -> Vector2:
	if outside_mode() == "hidden":
		return Vector2.ZERO
	var v: Control = view()
	if v == null or not v.is_visible_in_tree():
		return Vector2.ZERO
	var vis: Vector2 = v.call("visible_outside_seq")
	if only_mostly():
		vis = Vector2(minf(vis.x, _reveal_need.x), minf(vis.y, _reveal_need.y))
	return vis


func update_overscan() -> void:
	var v: Control = view()
	if v == null:
		return
	var comp: Node = Session.compositor
	if comp == null or not is_instance_valid(comp) or not comp.has_method("set_overscan"):
		v.call("set_canvas_rect", Rect2())
		return
	var changed: bool = bool(comp.call("set_overscan", wanted_margin()))
	v.call("set_canvas_rect", comp.call("canvas_rect_seq"))
	if changed:
		_request_render()


static func poly_area(p: PackedVector2Array) -> float:
	var a: float = 0.0
	for i: int in p.size():
		var j: int = (i + 1) % p.size()
		a += p[i].x * p[j].y - p[j].x * p[i].y
	return a * 0.5


static func share_outside(quad: PackedVector2Array, frame: Vector2) -> float:
	if quad.size() < 3:
		return 0.0
	var area: float = absf(poly_area(quad))
	if area < 0.0001:
		return 0.0
	var box: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(frame.x, 0.0), frame, Vector2(0.0, frame.y)])
	var inside: float = 0.0
	for part: PackedVector2Array in Geometry2D.intersect_polygons(quad, box):
		inside += absf(poly_area(part))
	return clampf(1.0 - inside / area, 0.0, 1.0)


static func need_for(quads: Array[PackedVector2Array], frame: Vector2) -> Vector2:
	var need: Vector2 = Vector2.ZERO
	for q: PackedVector2Array in quads:
		for p: Vector2 in q:
			need.x = maxf(need.x, maxf(-p.x, p.x - frame.x))
			need.y = maxf(need.y, maxf(-p.y, p.y - frame.y))
	return need


static func reveal_quads(comp: Node, frame: Vector2, share: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if comp == null or not comp.has_method("layer_ids"):
		return out
	for id: String in comp.call("layer_ids"):
		var q: PackedVector2Array = comp.call("layer_quad", id)
		if q.size() == 4 and share_outside(q, frame) > share:
			out.append(q)
	return out


func _on_rendered(_t: float) -> void:
	_refresh_reveal()


func _refresh_reveal() -> void:
	var v: Control = view()
	if v == null:
		return
	if outside_mode() == "hidden" or not only_mostly():
		if bool(v.get("reveal_only")) or _reveal_count > 0:
			var none: Array[PackedVector2Array] = []
			v.call("set_reveal", false, none)
			_reveal_count = 0
		if _reveal_need != Vector2.ZERO:
			_reveal_need = Vector2.ZERO
			_pending_overscan = true
		return
	var frame: Vector2 = v.get("frame_size")
	var quads: Array[PackedVector2Array] = reveal_quads(_comp if _comp != null else Session.compositor, frame, float(Prefs.get_value(PREF_OUT_SHARE)))
	_reveal_count = quads.size()
	v.call("set_reveal", true, quads)
	var need: Vector2 = need_for(quads, frame)
	if not need.is_equal_approx(_reveal_need):
		_reveal_need = need
		_pending_overscan = true


func outside_menu_items() -> Array:
	var mode: String = outside_mode()
	var items: Array = []
	for m: String in OUT_MODES:
		items.append(PmMenu.check_item("out:mode:" + m, String(OUT_LABELS[m]), mode == m))
	items.append(PmMenu.separator())
	var amt: float = float(Prefs.get_value(PREF_OUT_AMOUNT))
	var amounts: Array = []
	for a: float in AMOUNTS:
		amounts.append(PmMenu.check_item("out:amt:" + str(a), "%d percent" % int(round(a * 100.0)), absf(a - amt) < 0.01))
	items.append(PmMenu.sub_item("out:amt_menu", "Amount", amounts))
	var tint: Color = tint_colour()
	var tints: Array = []
	for t: Array in TINTS:
		tints.append(PmMenu.check_item("out:tint:" + String(t[1]), String(t[0]), Color.from_string(String(t[1]), Color.BLACK).is_equal_approx(tint)))
	tints.append(PmMenu.separator())
	tints.append(PmMenu.item("out:tint_pick", "Choose the colour..."))
	items.append(PmMenu.sub_item("out:tint_menu", "Tint colour", tints))
	items.append(PmMenu.separator())
	items.append(PmMenu.check_item("out:mostly", "Only when a clip is mostly outside", only_mostly()))
	var share: float = float(Prefs.get_value(PREF_OUT_SHARE))
	var shares: Array = []
	for s: Array in SHARES:
		shares.append(PmMenu.check_item("out:share:" + str(float(s[0])), String(s[1]), absf(float(s[0]) - share) < 0.01))
	items.append(PmMenu.sub_item("out:share_menu", "Mostly outside means", shares))
	return items


func _pick_outside(rest: String) -> void:
	if rest.begins_with("mode:"):
		var m: String = rest.substr(5)
		if OUT_MODES.has(m):
			Prefs.set_value(PREF_OUT_MODE, m)
	elif rest.begins_with("amt:"):
		Prefs.set_value(PREF_OUT_AMOUNT, clampf(float(rest.substr(4)), 0.0, 1.0))
	elif rest.begins_with("tint:"):
		Prefs.set_value(PREF_OUT_TINT, rest.substr(5))
		Prefs.set_value(PREF_OUT_MODE, "tinted")
	elif rest == "tint_pick":
		_open_tint_window()
	elif rest == "mostly":
		var on: bool = not only_mostly()
		Prefs.set_value(PREF_OUT_MOSTLY, on)
		if on and outside_mode() == "hidden":
			Prefs.set_value(PREF_OUT_MODE, "faded")
	elif rest.begins_with("share:"):
		Prefs.set_value(PREF_OUT_SHARE, clampf(float(rest.substr(6)), 0.05, 0.95))


func _open_tint_window() -> void:
	var p: Object = panel()
	var host: Control = p.call("root") if p != null else null
	if host == null:
		return
	if _tint_window != null and is_instance_valid(_tint_window):
		_tint_window.call("close")
	var picker: ColorPicker = ColorPicker.new()
	picker.color = tint_colour()
	picker.edit_alpha = false
	picker.color_changed.connect(_on_tint_picked)
	_tint_window = PmWindow.open(host, "Outside the frame tint", picker, Vector2(300.0, 420.0), "program.outside_tint")


func _on_tint_picked(col: Color) -> void:
	Prefs.set_value(PREF_OUT_TINT, "#" + col.to_html(false))
	if outside_mode() != "tinted":
		Prefs.set_value(PREF_OUT_MODE, "tinted")


func full_choice_items(prefix: String, pref: String) -> Array:
	var now: String = String(Prefs.get_value(pref))
	var out: Array = []
	for c: String in FULL_CHOICES:
		out.append(PmMenu.check_item(prefix + c, String(FULL_LABELS[c]), now == c))
	return out


func screen_menu_items() -> Array:
	var items: Array = [PmMenu.sub_item("fz_menu", "Fullscreen shows", full_choice_items("fz:", PREF_FULL_ZOOM))]
	if popped():
		items.append(PmMenu.item("screen_back", "Bring the Program back", Cmd.keys_text(CMD_POPOUT)))
	else:
		items.append(PmMenu.item("popout", "Pop out the Program", Cmd.keys_text(CMD_POPOUT)))
	var count: int = DisplayServer.get_screen_count()
	if count > 1:
		var here: int = on_screen()
		var screens: Array = []
		for i: int in count:
			screens.append(PmMenu.check_item("screen_" + str(i), PmScreenWindow.screen_label(i), here == i))
		items.append(PmMenu.sub_item("screen_menu", "Pop out on", screens))
	return items


func popout_menu_items() -> Array:
	var p: Object = panel()
	var v: Control = view()
	var zoom_now: String = String(v.get("zoom")) if v != null else "fit"
	var zooms: Array = []
	for z: Variant in MonitorView.zoom_choice_ids():
		zooms.append(PmMenu.check_item("pz:" + String(z), String(MonitorView.ZOOM_LABELS[z]), zoom_now == String(z)))
	var fs: bool = popout_fullscreen()
	var devs: Array = []
	var chosen: String = String(Prefs.get_value(PREF_POP_DEVICE))
	for d: String in devices():
		devs.append(PmMenu.check_item("pdev:" + d, d, d == chosen))
	var items: Array = [
		PmMenu.sub_item("pz_menu", "Zoom", zooms),
	]
	if p != null and p.has_method("_overlay_menu_items"):
		items.append(PmMenu.sub_item("overlays_menu", "Overlays", p.call("_overlay_menu_items")))
	items.append(PmMenu.sub_item("outside_menu", "Outside the frame", outside_menu_items()))
	var sel: Object = p.get("_select") if p != null else null
	if sel != null:
		items.append(PmMenu.sub_item("outline_menu", "Transform outline", sel.call("outline_menu_items")))
	items.append(PmMenu.check_item("po:handles", "Show the transform handles", bool(Prefs.get_value(PREF_POP_HANDLES))))
	if sel != null:
		items.append(PmMenu.separator())
		items.append_array(sel.call("top_menu_items"))
	items.append(PmMenu.separator())
	items.append(full_quality_item())
	items.append(PmMenu.item("po:full", "Leave fullscreen" if fs else "Fullscreen", "F11"))
	items.append(PmMenu.sub_item("pfz_menu", "Fullscreen shows", full_choice_items("pfz:", PREF_POP_FULL_ZOOM)))
	items.append(PmMenu.separator())
	items.append(PmMenu.check_item("po:sound", "Sound from the pop out", bool(Prefs.get_value(PREF_POP_SOUND))))
	if not devs.is_empty():
		items.append(PmMenu.sub_item("pdev_menu", "Pop out sound goes to", devs))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("po:back", "Bring it back into the app", Cmd.keys_text(CMD_POPOUT)))
	return items


func on_menu_picked(id: String) -> bool:
	if id.begins_with("out:"):
		_pick_outside(id.substr(4))
		return true
	if id.begins_with("sel:") or id.begins_with("ol:"):
		var p: Object = panel()
		var sel: Object = p.get("_select") if p != null else null
		return sel != null and bool(sel.call("on_menu_picked", id))
	if id == "fullscreen":
		toggle_fullscreen()
		return true
	if id == "full_quality":
		Cmd.run(FullQuality.COMMAND_ID)
		sync_full_quality()
		return true
	if id == "fs:leave":
		leave_full()
		return true
	if id.begins_with("fz:"):
		Prefs.set_value(PREF_FULL_ZOOM, id.substr(3))
		if full_on():
			apply_full_zoom(view(), id.substr(3))
		return true
	if id.begins_with("pfz:"):
		Prefs.set_value(PREF_POP_FULL_ZOOM, id.substr(4))
		if popout_fullscreen():
			apply_full_zoom(view(), id.substr(4))
		return true
	if id == "popout":
		toggle_popout()
		return true
	if id == "screen_back" or id == "po:back":
		close_popout()
		return true
	if id.begins_with("screen_") and id.substr(7).is_valid_int():
		open_popout(int(id.substr(7)))
		return true
	if id.begins_with("pz:"):
		set_view_zoom(id.substr(3))
		return true
	if id == "po:handles":
		Prefs.set_value(PREF_POP_HANDLES, not bool(Prefs.get_value(PREF_POP_HANDLES)))
		return true
	if id == "po:full":
		set_popout_fullscreen(not popout_fullscreen())
		return true
	if id == "po:sound":
		set_popout_sound(not bool(Prefs.get_value(PREF_POP_SOUND)))
		return true
	if id.begins_with("pdev:"):
		Prefs.set_value(PREF_POP_DEVICE, id.substr(5))
		if not bool(Prefs.get_value(PREF_POP_SOUND)):
			set_popout_sound(true)
		return true
	if id.begins_with("ov:"):
		var p: Object = panel()
		if p != null and p.has_method("_on_tools_picked"):
			p.call("_on_tools_picked", id)
		return true
	return false


func set_view_zoom(z: String) -> void:
	var v: Control = view()
	if v == null:
		return
	v.call("set_zoom", z)
	_sync_zoom_labels()


func _sync_zoom_labels() -> void:
	var v: Control = view()
	if v == null:
		return
	var z: String = String(v.get("zoom"))
	var p: Object = panel()
	if p != null and p.has_method("_on_view_zoom"):
		p.call("_on_view_zoom", z)
	if _pop_zoom != null and is_instance_valid(_pop_zoom):
		_pop_zoom.call("set_value", z, false)


static func zoom_for_choice(choice: String) -> String:
	if choice == "fill":
		return MonitorView.ZOOM_FILL
	if choice == "pixels":
		return "1"
	if choice == "keep":
		return ""
	return "fit"


func apply_full_zoom(v: Control, choice: String) -> void:
	if v == null:
		return
	var z: String = zoom_for_choice(choice)
	if not z.is_empty():
		v.call("set_zoom", z)
	_sync_zoom_labels()


static func view_state(v: Control) -> Dictionary:
	if v == null:
		return {}
	return {"zoom": String(v.get("zoom")), "pan": v.get("pan"), "pad": float(v.get("pad_px"))}


func restore_view(v: Control, st: Dictionary) -> void:
	if v == null or st.is_empty():
		return
	v.call("set_pad", float(st.get("pad", MonitorView.PAD)))
	v.call("set_zoom", String(st.get("zoom", "fit")))
	v.set("pan", st.get("pan", Vector2.ZERO))
	v.call("pan_by", Vector2.ZERO)
	_sync_zoom_labels()


func _set_mode(w: Window, m: int, setter: Callable) -> void:
	if setter.is_valid():
		setter.call(w, m)
		return
	if w != null:
		w.mode = m as Window.Mode


func full_on() -> bool:
	return _full != null and is_instance_valid(_full)


func toggle_fullscreen() -> void:
	if popped():
		set_popout_fullscreen(not popout_fullscreen())
		return
	if full_on():
		leave_full()
	else:
		enter_full()


func enter_full() -> bool:
	var p: Object = panel()
	var v: Control = view()
	if p == null or v == null:
		return false
	var root_: Control = p.call("root")
	if root_ == null or not root_.is_inside_tree():
		return false
	var overlay: Node = PmUI.overlay_for(root_)
	if overlay == null:
		return false
	_full = Control.new()
	_full.name = "ProgramFullscreen"
	_full.mouse_filter = Control.MOUSE_FILTER_STOP
	_full.focus_mode = Control.FOCUS_ALL
	_full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fill: ColorRect = PmUI.fill("bg_app")
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_full.add_child(fill)
	_full_prev_parent = v.get_parent()
	_full_prev_index = v.get_index()
	if _full_prev_parent != null:
		_full_prev_parent.remove_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_full.add_child(v)
	overlay.add_child(_full)
	_full.gui_input.connect(_on_full_input)
	_full.grab_focus()
	_view_before = view_state(v)
	v.call("set_pad", 0.0)
	apply_full_zoom(v, String(Prefs.get_value(PREF_FULL_ZOOM)))
	var w: Window = root_.get_window()
	_full_mode_before = int(w.mode) if w != null else -1
	_set_mode(w, Window.MODE_FULLSCREEN, window_mode_setter)
	_pending_overscan = true
	_request_render()
	return true


func leave_full() -> void:
	if not full_on():
		return
	var p: Object = panel()
	var v: Control = view()
	var holder: Control = _full
	_full = null
	if v != null and v.get_parent() == holder:
		holder.remove_child(v)
	if v != null and _full_prev_parent != null and is_instance_valid(_full_prev_parent):
		_full_prev_parent.add_child(v)
		_full_prev_parent.move_child(v, clampi(_full_prev_index, 0, _full_prev_parent.get_child_count() - 1))
		v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	PmUI.free_node(holder)
	restore_view(v, _view_before)
	_view_before = {}
	var root_: Control = p.call("root") if p != null else null
	if root_ != null and root_.is_inside_tree() and _full_mode_before >= 0:
		_set_mode(root_.get_window(), _full_mode_before, window_mode_setter)
	_full_mode_before = -1
	_pending_overscan = true
	_request_render()


func _on_full_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed:
		return
	var plain: bool = not (k.ctrl_pressed or k.alt_pressed or k.shift_pressed or k.meta_pressed)
	if k.keycode == KEY_ESCAPE or (plain and (k.keycode == KEY_F11 or k.keycode == KEY_QUOTELEFT)):
		if k.echo:
			if full_on():
				_full.accept_event()
			return
		leave_full()
		if _full_prev_parent != null and is_instance_valid(_full_prev_parent) and (_full_prev_parent as Node).is_inside_tree():
			(_full_prev_parent as Node).get_viewport().set_input_as_handled()


func _handle_under(pos: Vector2) -> String:
	var p: Object = panel()
	if p == null or not p.has_method("_handle_at"):
		return ""
	return String(p.call("_handle_at", pos))


func _on_picture_input(event: InputEvent, _pic: Rect2) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
		if not _handle_under(mb.position).is_empty():
			return
		if popped():
			set_popout_fullscreen(not popout_fullscreen())
		elif full_on():
			leave_full()
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT and popped():
		var v: Control = view()
		if v != null:
			open_popout_menu(null, v.global_position + mb.position)
	elif mb.button_index == MOUSE_BUTTON_RIGHT and full_on():
		var fv: Control = view()
		if fv != null:
			open_full_menu(fv.global_position + mb.position)


func full_quality_item() -> Dictionary:
	return PmMenu.check_item("full_quality", "Full quality playback", FullQuality.is_on(), Cmd.keys_text(FullQuality.COMMAND_ID))


func full_menu_items() -> Array:
	return [
		full_quality_item(),
		PmMenu.sub_item("fz_menu", "Fullscreen shows", full_choice_items("fz:", PREF_FULL_ZOOM)),
		PmMenu.separator(),
		PmMenu.item("fs:leave", "Leave fullscreen", "F11"),
	]


func open_full_menu(at: Vector2) -> Control:
	if not full_on():
		return null
	_full_menu = PmMenu.open(_full, full_menu_items(), at)
	if _full_menu != null and _full_menu.is_inside_tree():
		_full_menu.connect("picked", _on_full_menu_picked)
	return _full_menu


func _on_full_menu_picked(id: String) -> void:
	on_menu_picked(id)


func sync_full_quality() -> void:
	if _pop_fq != null and is_instance_valid(_pop_fq):
		_pop_fq.set_pressed_no_signal(FullQuality.is_on())


func popped() -> bool:
	return popout != null and is_instance_valid(popout)


func popout_fullscreen() -> bool:
	return popped() and bool(popout.get("fullscreen_on"))


func on_screen() -> int:
	if not popped():
		return -1
	if bool(popout.call("is_native")):
		var sc: int = PmScreenWindow.screen_of(Rect2i(popout.position, popout.size), PmScreenWindow.screen_rects())
		if sc >= 0:
			return sc
	return int(popout.get_meta("pm_screen", 0))


func toggle_popout() -> void:
	if popped():
		close_popout()
	else:
		open_popout(-1)


func open_popout(screen: int) -> bool:
	var p: Object = panel()
	var v: Control = view()
	if p == null or v == null:
		return false
	var root_: Control = p.call("root")
	if root_ == null or not root_.is_inside_tree():
		return false
	var count: int = DisplayServer.get_screen_count()
	if screen < -1 or screen >= count:
		return false
	if popped():
		close_popout()
	if full_on():
		leave_full()
	var want: int = screen
	if want < 0:
		want = int(Prefs.get_value(PREF_POP_SCREEN))
		if want < 0 or want >= count:
			var others: PackedInt32Array = PmScreenWindow.other_screens()
			want = others[0] if not others.is_empty() else DisplayServer.window_get_current_screen(DisplayServer.MAIN_WINDOW_ID)
	var saved: Rect2i = PmScreenWindow.parse_rect(String(Prefs.get_value(PREF_POP_RECT)))
	var r: Rect2i = PmScreenWindow.rect_for(saved, want, PmScreenWindow.screen_rects())
	_pop_prev_parent = v.get_parent()
	_pop_prev_index = v.get_index()
	if _pop_prev_parent == null:
		return false
	_pop_prev_parent.remove_child(v)
	_strip = _make_strip()
	_pop_prev_parent.add_child(_strip)
	_pop_prev_parent.move_child(_strip, clampi(_pop_prev_index, 0, _pop_prev_parent.get_child_count() - 1))
	var w: Window = PmScreenWindow.make(POPOUT_TITLE, want)
	w.set("rect_pref", PREF_POP_RECT)
	w.set("screen_pref", PREF_POP_SCREEN)
	if popout_mode_setter.is_valid():
		w.set("mode_setter", popout_mode_setter)
	var main_theme: Theme = root_.get_tree().root.theme
	if main_theme != null:
		w.theme = main_theme
	w.call("place", r)
	w.call("set_slot", v)
	w.connect("closed", close_popout)
	w.connect("key_unhandled", _on_popout_key)
	w.connect("fullscreen_changed", _on_popout_fullscreen)
	root_.get_tree().root.add_child(w)
	w.call("set_bar", _build_bar(w))
	popout = w
	Prefs.set_value(PREF_SCREEN, want)
	_apply_sound()
	v.call("redraw_overlay")
	_pending_overscan = true
	if p.has_method("_refresh_state"):
		p.call("_refresh_state")
	_request_render()
	return true


func close_popout() -> void:
	var p: Object = panel()
	var v: Control = view()
	var w: Window = popout if popped() else null
	popout = null
	if w == null and strip() == null:
		return
	var was_full: bool = w != null and bool(w.get("fullscreen_on"))
	if w != null:
		w.call("begin_close")
		w.call("save_rect")
		var taken: Control = w.call("take_back")
		if taken != null:
			v = taken
	if was_full:
		restore_view(v, _pop_view_before)
	_pop_view_before = {}
	var parent: Node = _pop_prev_parent
	var idx: int = _pop_prev_index
	if _strip != null and is_instance_valid(_strip):
		if _strip.get_parent() != null:
			parent = _strip.get_parent()
			idx = _strip.get_index()
		PmUI.free_node(_strip)
	_strip = null
	if v != null and parent != null and is_instance_valid(parent) and v.get_parent() != parent:
		if v.get_parent() != null:
			v.get_parent().remove_child(v)
		parent.add_child(v)
		parent.move_child(v, clampi(idx, 0, parent.get_child_count() - 1))
		v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pop_prev_parent = null
	_pop_zoom = null
	_pop_sound = null
	_pop_device = null
	_pop_full = null
	_pop_fq = null
	if w != null:
		PmUI.free_node(w)
		if Prefs.is_registered(PREF_SCREEN):
			Prefs.set_value(PREF_SCREEN, -1)
	_apply_sound()
	_pending_overscan = true
	if p != null and p.has_method("_refresh_state"):
		p.call("_refresh_state")
	if v != null:
		v.call("redraw_overlay")
	_request_render()


func set_popout_fullscreen(on: bool) -> void:
	if not popped():
		return
	popout.call("set_fullscreen", on)


func _on_popout_fullscreen(on: bool) -> void:
	var v: Control = view()
	if on:
		_pop_view_before = view_state(v)
		if v != null:
			v.call("set_pad", 0.0)
		apply_full_zoom(v, String(Prefs.get_value(PREF_POP_FULL_ZOOM)))
	else:
		restore_view(v, _pop_view_before)
		_pop_view_before = {}
	_pending_overscan = true
	_refresh_bar()


func _on_popout_key(k: InputEventKey) -> void:
	var p: Object = panel()
	var handled: bool = false
	if p != null and p.has_method("handle_key"):
		handled = bool(p.call("handle_key", k))
	if not handled:
		handled = Cmd.dispatch_key(k, "program") or Cmd.dispatch_key(k, "global")
	if handled and popped():
		popout.set_input_as_handled()


func hide_handles() -> bool:
	return popped() and not bool(Prefs.get_value(PREF_POP_HANDLES))


func _make_strip() -> Control:
	var strip: Control = Control.new()
	strip.name = "PopOutStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_STOP
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill: ColorRect = PmUI.fill("bg_app")
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strip.add_child(fill)
	var col: VBoxContainer = PmUI.vbox(Tk.px(10.0))
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strip.add_child(col)
	var label: Label = PmLabel.dim("Showing in the pop out")
	label.name = "Said"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(label)
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(row)
	var back: Button = PmButton.primary("Bring it back")
	back.name = "BringBack"
	back.pressed.connect(close_popout)
	PmUI.tip(back, "Put the picture back in this panel", Cmd.keys_text(CMD_POPOUT))
	row.add_child(back)
	var full: Button = PmButton.make("Fullscreen there")
	full.name = "FullThere"
	full.pressed.connect(set_popout_fullscreen.bind(true))
	PmUI.tip(full, "Make the pop out fill its screen", "F11")
	row.add_child(full)
	return strip


func strip() -> Control:
	return _strip if _strip != null and is_instance_valid(_strip) else null


func _build_bar(w: Window) -> Control:
	var col: VBoxContainer = PmUI.vbox(0)
	col.name = "PopOutBar"
	var holder: PanelContainer = PmUI.panel("bg_panel")
	col.add_child(holder)
	col.add_child(PmUI.divider())
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	holder.add_child(row)
	var v: Control = view()
	var zoom_choices: Array = []
	for zid: Variant in MonitorView.zoom_choice_ids():
		zoom_choices.append(PmDrop.choice(String(zid), String(MonitorView.ZOOM_LABELS[zid])))
	_pop_zoom = PmDrop.make_drop(zoom_choices, String(v.get("zoom")) if v != null else "fit")
	_pop_zoom.name = "Zoom"
	_rewire_drop(_pop_zoom, _open_zoom_menu)
	w.call("tip", _pop_zoom, "Zoom", "Ctrl+wheel")
	row.add_child(_pop_zoom)
	var out_b: Button = PmButton.make("", "minus")
	out_b.name = "ZoomOut"
	out_b.set("quiet", true)
	out_b.pressed.connect(_zoom_step.bind(-1))
	w.call("tip", out_b, "Zoom out", "Ctrl+wheel")
	row.add_child(out_b)
	var in_b: Button = PmButton.make("", "plus")
	in_b.name = "ZoomIn"
	in_b.set("quiet", true)
	in_b.pressed.connect(_zoom_step.bind(1))
	w.call("tip", in_b, "Zoom in", "Ctrl+wheel")
	row.add_child(in_b)
	_pop_full = PmButton.make("Fullscreen", "maximize")
	_pop_full.name = "Fullscreen"
	_pop_full.pressed.connect(_on_pop_full_pressed)
	w.call("tip", _pop_full, "Fill this screen with the picture, double click the picture does it too", "F11")
	row.add_child(_pop_full)
	_pop_fq = PmButton.make(FullQuality.LABEL, FullQuality.ICON, true)
	_pop_fq.name = "FullQuality"
	_pop_fq.button_pressed = FullQuality.is_on()
	_pop_fq.toggled.connect(_on_pop_fq_toggled)
	w.call("tip", _pop_fq, FullQuality.TIP, Cmd.keys_text(FullQuality.COMMAND_ID))
	row.add_child(_pop_fq)
	row.add_child(_pop_snap_button(w))
	row.add_child(PmUI.spacer())
	_pop_sound = PmButton.make("Sound from the pop out", "speaker", true)
	_pop_sound.name = "Sound"
	_pop_sound.button_pressed = bool(Prefs.get_value(PREF_POP_SOUND))
	_pop_sound.toggled.connect(set_popout_sound)
	w.call("tip", _pop_sound, "Play the program sound on the device chosen next to it while the pop out is open")
	row.add_child(_pop_sound)
	_pop_device = PmDrop.make_drop(_device_choices(), String(Prefs.get_value(PREF_POP_DEVICE)))
	_pop_device.name = "Device"
	_pop_device.set("placeholder", "Choose a device")
	_pop_device.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_pop_device.custom_minimum_size = Vector2(float(Tk.px(120.0)), 0.0)
	_pop_device.clip_text = true
	_rewire_drop(_pop_device, _open_device_menu)
	w.call("tip", _pop_device, "The output device the pop out's sound goes to")
	row.add_child(_pop_device)
	var back: Button = PmButton.make("Bring it back", "dock_panel")
	back.name = "BringBack"
	back.pressed.connect(close_popout)
	w.call("tip", back, "Put the picture back in the Program panel", Cmd.keys_text(CMD_POPOUT))
	row.add_child(back)
	var more: Button = PmButton.make("", "more")
	more.name = "More"
	more.set("quiet", true)
	more.pressed.connect(_open_more.bind(more))
	w.call("tip", more, "Pop out menu, right click the picture opens it too")
	row.add_child(more)
	_refresh_bar()
	return col


func _rewire_drop(d: Button, opener: Callable) -> void:
	var own: Callable = Callable(d, "_on_open")
	if d.pressed.is_connected(own):
		d.pressed.disconnect(own)
	d.pressed.connect(opener.bind(d))


func _device_choices() -> Array:
	var out: Array = []
	for d: String in devices():
		out.append(PmDrop.choice(d, d))
	return out


func _refresh_bar() -> void:
	if _pop_sound != null and is_instance_valid(_pop_sound):
		_pop_sound.set_pressed_no_signal(bool(Prefs.get_value(PREF_POP_SOUND)))
	if _pop_device != null and is_instance_valid(_pop_device):
		_pop_device.call("set_choices", _device_choices())
		_pop_device.call("set_value", String(Prefs.get_value(PREF_POP_DEVICE)), false)
	if _pop_full != null and is_instance_valid(_pop_full):
		_pop_full.text = "Leave fullscreen" if popout_fullscreen() else "Fullscreen"
	sync_full_quality()


func _zoom_step(steps: int) -> void:
	var v: Control = view()
	if v == null:
		return
	v.call("zoom_step", steps, Vector2(v.size) * 0.5)
	_sync_zoom_labels()


func _on_pop_full_pressed() -> void:
	set_popout_fullscreen(not popout_fullscreen())


func _on_pop_fq_toggled(on: bool) -> void:
	if on != FullQuality.is_on():
		Cmd.run(FullQuality.COMMAND_ID)
	sync_full_quality()


func _open_zoom_menu(anchor: Button) -> void:
	if not popped():
		return
	var v: Control = view()
	var now: String = String(v.get("zoom")) if v != null else "fit"
	var items: Array = []
	for z: Variant in MonitorView.zoom_choice_ids():
		items.append(PmMenu.check_item("pz:" + String(z), String(MonitorView.ZOOM_LABELS[z]), now == String(z)))
	var m: Control = popout.call("open_menu", anchor, items)
	m.connect("picked", _on_popout_menu_picked)


func _open_device_menu(anchor: Button) -> void:
	if not popped():
		return
	var chosen: String = String(Prefs.get_value(PREF_POP_DEVICE))
	var items: Array = []
	for d: String in devices():
		items.append(PmMenu.check_item("pdev:" + d, d, d == chosen))
	if items.is_empty():
		items.append(PmMenu.item("pdev_none", "No output devices found"))
	var m: Control = popout.call("open_menu", anchor, items)
	m.connect("picked", _on_popout_menu_picked)


func _open_more(anchor: Button) -> void:
	open_popout_menu(anchor, Vector2(INF, INF))


func open_popout_menu(anchor: Control, at: Vector2) -> Control:
	if not popped():
		return null
	var m: Control = popout.call("open_menu", anchor, popout_menu_items(), at)
	m.connect("picked", _on_popout_menu_picked)
	return m


func _on_popout_menu_picked(id: String) -> void:
	on_menu_picked(id)
	_refresh_bar()


func devices() -> PackedStringArray:
	if device_lister.is_valid():
		return device_lister.call()
	return AudioServer.get_output_device_list()


func current_device() -> String:
	if device_getter.is_valid():
		return String(device_getter.call())
	return AudioServer.output_device


func _set_device(name_: String) -> void:
	if device_setter.is_valid():
		device_setter.call(name_)
		return
	AudioServer.output_device = name_


func app_device() -> String:
	var d: String = String(Prefs.get_value(PREF_APP_DEVICE)) if Prefs.is_registered(PREF_APP_DEVICE) else "Default"
	return d if devices().has(d) else "Default"


func sound_target() -> String:
	if popped() and bool(Prefs.get_value(PREF_POP_SOUND)):
		var d: String = String(Prefs.get_value(PREF_POP_DEVICE))
		if devices().has(d):
			return d
	return app_device()


func _apply_sound() -> void:
	var want: String = sound_target()
	if current_device() != want:
		_set_device(want)


func set_popout_sound(on: bool) -> void:
	if on and not devices().has(String(Prefs.get_value(PREF_POP_DEVICE))):
		var pick: String = ""
		var app: String = app_device()
		for d: String in devices():
			if d != app and d != "Default":
				pick = d
				break
		if pick.is_empty():
			Events.toast("Choose the device the pop out's sound goes to")
		else:
			Prefs.set_value(PREF_POP_DEVICE, pick)
	Prefs.set_value(PREF_POP_SOUND, on)
	_apply_sound()
	_refresh_bar()
	if on and popped() and current_device() != app_device():
		Events.notice("The pop out's sound goes to " + current_device(), "It goes back to " + app_device() + " when the pop out closes or the switch goes off.")


func _pop_snap_button(w: Window) -> Button:
	var script: GDScript = load("res://modules/core_panels/monitor_snap_button.gd")
	var b: Button = script.call("make_snap", false)
	var consts: Dictionary = (load("res://modules/core_panels/monitor_snap.gd") as GDScript).get_script_constant_map()
	w.call("tip", b, String(consts["TIP"]), Cmd.keys_text(String(consts["CMD_ID"])))
	return b

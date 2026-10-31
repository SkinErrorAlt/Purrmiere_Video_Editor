extends RefCounted

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const OutlineStyles := preload("res://modules/core_panels/outline_styles.gd")
const OutlineWindow := preload("res://modules/core_panels/outline_window.gd")
const MonitorSnap := preload("res://modules/core_panels/monitor_snap.gd")
const PREF_CLICK := "program.select.click"
const PREF_EMPTY := "program.select.empty_clears"
const PREF_SHOW := "program.outline.show"
const PREF_STYLE := "program.outline.style"
const PREF_COLOUR := "program.outline.colour"
const PREF_THICKNESS := "program.outline.thickness"
const CMD_OUTLINE := "view.program_outline"
const COLOURS: Array = [["Theme ink", ""], ["White", "#ffffff"], ["Black", "#000000"], ["Red", "#ff3030"], ["Yellow", "#ffe000"], ["Green", "#00d060"], ["Cyan", "#00d0ff"], ["Magenta", "#ff40d0"]]
const THICKNESSES: Array = [0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0]
const DRAG_SLOP := 4.0

var _panel_ref: WeakRef = null
var _colour_window: Control = null
var _style_window: Control = null
var styled: Dictionary = {}
var previews: Dictionary = {}


func _init(panel_: Object) -> void:
	_panel_ref = weakref(panel_)
	if panel_ != null and not Tk.tokens_changed.is_connected(_on_tokens):
		Tk.tokens_changed.connect(_on_tokens)


func _on_tokens() -> void:
	if view() != null and colour_text().strip_edges().is_empty():
		apply_style()


static func registry() -> RefCounted:
	return OutlineStyles.shared()


static func ensure_prefs(prefs: Node) -> void:
	if prefs == null:
		return
	if not bool(prefs.call("is_registered", PREF_CLICK)):
		prefs.call("register", PREF_CLICK, true, {"label": "Click the picture to select clips", "type": "bool"})
	if not bool(prefs.call("is_registered", PREF_EMPTY)):
		prefs.call("register", PREF_EMPTY, true, {"label": "A click on empty picture clears the selection", "type": "bool"})
	registry().call("ensure_prefs", prefs)
	MonitorSnap.ensure_prefs(prefs)


static func plan_click(hits: PackedStringArray, selected: PackedStringArray, focus: String, alt: bool, shift: bool, ctrl: bool, empty_clears: bool) -> Dictionary:
	if hits.is_empty():
		if alt or shift or ctrl or not empty_clears or selected.is_empty():
			return {"mode": "none", "id": ""}
		return {"mode": "clear", "id": ""}
	var target: String = hits[0]
	if alt:
		var at: int = hits.find(focus) if not focus.is_empty() else -1
		if at < 0:
			for i: int in hits.size():
				if selected.has(hits[i]):
					at = i
					break
		if at >= 0:
			target = hits[(at + 1) % hits.size()]
		else:
			target = hits[1] if hits.size() > 1 else hits[0]
	var mode: String = "replace"
	if ctrl:
		mode = "toggle"
	elif shift:
		mode = "add"
	return {"mode": mode, "id": target}


func panel() -> Object:
	return _panel_ref.get_ref() if _panel_ref != null else null


func view() -> Control:
	var p: Object = panel()
	var v: Variant = p.get("view") if p != null else null
	return v if v != null and is_instance_valid(v) and v is Control else null


func click_on() -> bool:
	return Prefs.is_registered(PREF_CLICK) and bool(Prefs.get_value(PREF_CLICK))


func empty_clears() -> bool:
	return Prefs.is_registered(PREF_EMPTY) and bool(Prefs.get_value(PREF_EMPTY))


func outline_on() -> bool:
	return not Prefs.is_registered(PREF_SHOW) or bool(Prefs.get_value(PREF_SHOW))


func style_id() -> String:
	return String(Prefs.get_value(PREF_STYLE)) if Prefs.is_registered(PREF_STYLE) else OutlineStyles.FALLBACK


func colour_text() -> String:
	return String(Prefs.get_value(PREF_COLOUR)) if Prefs.is_registered(PREF_COLOUR) else ""


func outline_colour() -> Color:
	var text: String = colour_text().strip_edges()
	if text.is_empty():
		return Tk.c["accent"]
	return Color.from_string(text, Tk.c["accent"])


func thickness() -> float:
	var v: float = float(Prefs.get_value(PREF_THICKNESS)) if Prefs.is_registered(PREF_THICKNESS) else 1.0
	return clampf(v, OutlineStyles.THICK_MIN, OutlineStyles.THICK_MAX)


func apply_style(overrides: Dictionary = {}) -> void:
	var v: Control = view()
	if v == null or not v.has_method("outline_layer"):
		return
	var reg: RefCounted = registry()
	var got: Dictionary = reg.call("resolve", style_id())
	var used: String = String(got["id"])
	var values: Dictionary = reg.call("param_values", Prefs, used)
	for k: Variant in overrides.keys():
		if values.has(k):
			values[k] = overrides[k]
	var thick: float = float(overrides.get("__thickness", thickness()))
	styled = got
	var layer: Control = v.call("outline_layer")
	layer.call("set_style", got.get("shader", null), got.get("uniforms", {}), values, outline_colour(), thick, float(reg.call("reach_of", used, values)), bool(got.get("animated", false)))
	v.call("redraw_overlay")


func on_pref(key: String) -> bool:
	if key == PREF_CLICK or key == PREF_EMPTY:
		return true
	if key == PREF_SHOW:
		var v: Control = view()
		if v != null:
			v.call("redraw_overlay")
		_refresh_window()
		return true
	if key.begins_with(OutlineStyles.PREF_PARAM):
		apply_style()
		if key == PREF_STYLE or key == PREF_COLOUR:
			_refresh_window()
		return true
	return false


func tick(dt: float) -> void:
	var v: Control = view()
	var looking: bool = (_style_window != null and is_instance_valid(_style_window)) or (v != null and v.is_visible_in_tree() and v.has_method("outline_layer") and (v.call("outline_layer") as Control).visible)
	if not looking:
		return
	if bool(registry().call("tick", dt)):
		ensure_prefs(Prefs)
		apply_style()
		_refresh_window()


func look_again() -> bool:
	var changed: bool = bool(registry().call("refresh_if_changed"))
	if changed:
		ensure_prefs(Prefs)
		apply_style()
		_refresh_window()
	return changed


func reload_styles() -> void:
	registry().call("reload")
	ensure_prefs(Prefs)
	apply_style()
	_refresh_window()


func top_menu_items() -> Array:
	var click: bool = click_on()
	var empty: Dictionary = PmMenu.check_item("sel:empty", "A click on empty picture clears the selection", empty_clears())
	if not click:
		empty["disabled"] = true
	var items: Array = [
		PmMenu.check_item("sel:click", "Click the picture to select clips", click),
		empty,
		PmMenu.check_item("ol:show", "Show the transform outline", outline_on(), Cmd.keys_text(CMD_OUTLINE)),
	]
	items.append_array(MonitorSnap.menu_items())
	return items


func outline_menu_items() -> Array:
	look_again()
	var reg: RefCounted = registry()
	var now: String = style_id()
	var styles: Array = []
	for d: Dictionary in reg.call("list"):
		var label: String = String(d["label"])
		if String(d["source"]) == "user":
			label += " (your style)"
		styles.append(PmMenu.check_item("ol:style:" + String(d["id"]), label, now == String(d["id"])))
	styles.append(PmMenu.separator())
	styles.append(PmMenu.item("ol:folder", "Open the outlines folder"))
	styles.append(PmMenu.item("ol:reload", "Look for new styles"))
	var col: String = colour_text().strip_edges().to_lower()
	var colours: Array = []
	for pair: Array in COLOURS:
		var hex: String = String(pair[1])
		var same: bool = col == hex if hex.is_empty() else (not col.is_empty() and Color.from_string(col, Color(0, 0, 0, 0)).is_equal_approx(Color.from_string(hex, Color.WHITE)))
		colours.append(PmMenu.check_item("ol:col:" + (hex if not hex.is_empty() else "theme"), String(pair[0]), same))
	colours.append(PmMenu.separator())
	colours.append(PmMenu.item("ol:col_pick", "Choose the colour..."))
	var th: float = thickness()
	var thick: Array = []
	for t: float in THICKNESSES:
		thick.append(PmMenu.check_item("ol:thick:" + str(t), String.num(t, 1).trim_suffix(".0") + " px", absf(th - t) < 0.01))
	return [
		PmMenu.sub_item("ol:style_menu", "Style", styles),
		PmMenu.sub_item("ol:col_menu", "Colour", colours),
		PmMenu.sub_item("ol:thick_menu", "Thickness", thick),
		PmMenu.separator(),
		PmMenu.item("ol:window", "Outline settings..."),
	]


func on_menu_picked(id: String) -> bool:
	if MonitorSnap.on_menu_picked(id):
		return true
	if id == "sel:click":
		Prefs.set_value(PREF_CLICK, not click_on())
		return true
	if id == "sel:empty":
		Prefs.set_value(PREF_EMPTY, not empty_clears())
		return true
	if id == "ol:show":
		toggle_outline()
		return true
	if not id.begins_with("ol:"):
		return false
	var rest: String = id.substr(3)
	if rest.begins_with("style:"):
		set_style(rest.substr(6))
	elif rest.begins_with("col:"):
		var hex: String = rest.substr(4)
		Prefs.set_value(PREF_COLOUR, "" if hex == "theme" else hex)
	elif rest == "col_pick":
		open_colour_window()
	elif rest.begins_with("thick:"):
		Prefs.set_value(PREF_THICKNESS, clampf(float(rest.substr(6)), OutlineStyles.THICK_MIN, OutlineStyles.THICK_MAX))
	elif rest == "window":
		open_style_window()
	elif rest == "folder":
		open_folder()
	elif rest == "reload":
		reload_styles()
		Events.toast(str((registry().call("ids") as PackedStringArray).size()) + " outline styles found")
	return true


func toggle_outline() -> void:
	Prefs.set_value(PREF_SHOW, not outline_on())


func set_style(id: String) -> void:
	if not bool(registry().call("has", id)):
		return
	Prefs.set_value(PREF_STYLE, id)


func open_folder() -> void:
	var root: String = OutlineStyles.user_root()
	DirAccess.make_dir_recursive_absolute(root)
	OS.shell_open(ProjectSettings.globalize_path(root))
	Events.notice("Drop an outline style in here", "A folder with an outline.json and an outline.gdshader, or a single .gdshader file, becomes a style. Purrmiere picks it up without a restart.")


func _host() -> Control:
	var p: Object = panel()
	return p.call("root") if p != null else null


func open_colour_window() -> void:
	var host: Control = _host()
	if host == null:
		return
	if _colour_window != null and is_instance_valid(_colour_window):
		_colour_window.call("close")
	var picker: ColorPicker = ColorPicker.new()
	picker.color = outline_colour()
	picker.edit_alpha = true
	picker.color_changed.connect(_on_colour_picked)
	_colour_window = PmWindow.open(host, "Transform outline colour", picker, Vector2(300.0, 440.0), "program.outline_colour")


func _on_colour_picked(col: Color) -> void:
	Prefs.set_value(PREF_COLOUR, "#" + col.to_html(col.a < 0.999))


func open_style_window() -> Control:
	var host: Control = _host()
	if host == null:
		return null
	look_again()
	if _style_window != null and is_instance_valid(_style_window):
		_style_window.call("raise")
		_refresh_window()
		return _style_window
	_style_window = PmWindow.open(host, "Transform outline", OutlineWindow.build(self), Vector2(360.0, 690.0), "program.outline_window")
	return _style_window


func style_window() -> Control:
	return _style_window if _style_window != null and is_instance_valid(_style_window) else null


func _refresh_window() -> void:
	var w: Control = style_window()
	if w == null:
		return
	var old: Variant = w.call("content")
	var keep: int = (old as ScrollContainer).scroll_vertical if old is ScrollContainer else 0
	previews = {}
	var fresh: Control = OutlineWindow.build(self)
	w.call("set_content", fresh)
	if keep > 0 and fresh is ScrollContainer:
		PmUI.restore_scroll(fresh as ScrollContainer, keep)


func colours() -> Array:
	return COLOURS


func open_param_colour(pref: String, label: String) -> void:
	var host: Control = _host()
	if host == null or not Prefs.is_registered(pref):
		return
	var picker: ColorPicker = ColorPicker.new()
	picker.color = Color.from_string(String(Prefs.get_value(pref)), Color.WHITE)
	picker.edit_alpha = true
	picker.color_changed.connect(_on_param_colour.bind(pref))
	PmWindow.open(host, label, picker, Vector2(300.0, 440.0), "program.outline_param_colour")


func _on_param_colour(col: Color, pref: String) -> void:
	Prefs.set_value(pref, "#" + col.to_html(true))


func preview_value(key: String, v: Variant) -> void:
	var o: Dictionary = {}
	if key == PREF_THICKNESS:
		o["__thickness"] = v
	else:
		o[key] = v
	apply_style(o)


func commit_value(pref: String, v: Variant) -> void:
	if not Prefs.is_registered(pref):
		return
	Prefs.set_value(pref, v)

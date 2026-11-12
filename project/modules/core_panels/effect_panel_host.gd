extends Control

const SELF_PATH := "res://modules/core_panels/effect_panel_host.gd"
const Registry := preload("res://modules/core_panels/effect_panel_registry.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const CLICK_SLOP := 3.0
const GAP_TOP := 2.0
const GAP_BOTTOM := 6.0
const DIFFER_TEXT := "The selected clips differ here. Use the rows below, or select one clip."
const ANGLE_UNITS: PackedStringArray = ["deg", " deg", " degrees", "degrees", " °", "°"]
const PREF_LIVE := "panel_gizmos.live"
const PREF_PREFIX := "panel_gizmos."
const MENU_SHOW := "show"
const MENU_LIVE := "live"
const HIDDEN_ROW := 22.0
const LEVEL_FALL := 2.4

static var plant_no_live: bool = false
static var plant_no_sync: bool = false
static var plant_no_swap: bool = false
static var plant_flat: bool = false
static var plant_ignore_differ: bool = false

var panel: Object = null
var uid: String = ""
var kind_id: String = ""
var kind: RefCounted = null
var bind: Dictionary = {}
var options: Dictionary = {}
var fixed: Dictionary = {}
var differ: bool = false
var grab: String = ""
var hover: String = ""
var press_at: Vector2 = Vector2.ZERO
var frozen: Dictionary = {}
var draws: int = 0
var writes: int = 0
var asked: int = 0
var _specs: Dictionary = {}
var _specs_for: String = ""
var _values: Dictionary = {}
var _start: Dictionary = {}
var _animated: Dictionary = {}
var _keyed: bool = false
var _seen: String = ""
var _moved: bool = false
var _box: StyleBoxFlat = null
## Live state for Interactive Effect Panel Gizmos, filled only while playing, visible and switched on.
var live_on: bool = false
var live_clock: float = 0.0
var live_level: float = 0.0
var live_l: float = 0.0
var live_r: float = 0.0
var live_t: float = 0.0
var ticks: int = 0
## Suites set this to stand in for the audio meters (there is no sound playing in a suite).
var forced_level: float = -1.0
var _menu_hover: bool = false


static func plant(on: bool) -> void:
	plant_no_live = on
	plant_no_sync = on
	plant_no_swap = on
	plant_flat = on
	plant_ignore_differ = on
	Registry.plant_skip_check = on


static func add_for(ec: Object, body: Control, def: Dictionary, effect_uid: String, by_key: Dictionary = {}) -> Array[Control]:
	var out: Array[Control] = []
	for decl: Dictionary in Registry.panels_of(def):
		var host: Control = (load(SELF_PATH) as GDScript).new()
		var fixed_specs: Dictionary = {}
		if not by_key.is_empty():
			var b: Dictionary = decl["bind"]
			for r: Variant in b.keys():
				var item: Variant = by_key.get(String(b[r]), null)
				if item is Dictionary and (item as Dictionary).get("spec") is Dictionary:
					fixed_specs[String(r)] = (item as Dictionary)["spec"]
		host.call("setup", ec, effect_uid, decl, fixed_specs)
		body.add_child(host)
		if ec != null and ec.has_method("adopt_panel"):
			ec.call("adopt_panel", host)
		out.append(host)
	return out


func setup(ec: Object, effect_uid: String, decl: Dictionary, fixed_specs: Dictionary = {}) -> void:
	panel = ec
	uid = effect_uid
	kind_id = String(decl.get("kind", ""))
	bind = (decl.get("bind", {}) as Dictionary).duplicate()
	options = (decl.get("options", {}) as Dictionary).duplicate(true)
	fixed = fixed_specs
	kind = Registry.make(kind_id)
	name = "EffectPanel_" + kind_id
	register_prefs()
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	_size_to_state()
	if kind != null:
		tooltip_text = String(kind.call("tip", self, ""))
	set_process(false)


## Every gizmo kind's switches live in Settings under "Effect Panel Gizmos", so they hold across clips and runs.
func register_prefs() -> void:
	if not _has_prefs():
		return
	if not Prefs.is_registered(PREF_LIVE):
		Prefs.register(PREF_LIVE, true, {"label": "Interactive Effect Panel Gizmos react while playing", "type": "bool", "note": "The reverb's waves, the pan, the Doppler road and the 3D Panner move with the sound while it plays. Off uses nothing."})
	if kind == null:
		return
	var title_: String = String(kind.call("title"))
	_reg(_pref_key(MENU_SHOW), true, "Effect Panel Gizmos: show " + title_.to_lower())
	if is_live_kind():
		_reg(_pref_key(MENU_LIVE), true, "Effect Panel Gizmos: " + title_.to_lower() + " reacts while playing")
	for t: Array in toggles():
		_reg(_pref_key(String(t[0])), bool(t[2]), "Effect Panel Gizmos: " + title_.to_lower() + ", " + String(t[1]).to_lower())


func _has_prefs() -> bool:
	return Engine.get_main_loop() is SceneTree and (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/Prefs") != null


func _reg(key: String, default: bool, label_: String) -> void:
	if not Prefs.is_registered(key):
		Prefs.register(key, default, {"label": label_, "type": "bool"})


func _pref_key(id: String) -> String:
	return PREF_PREFIX + kind_id + "." + id


## The kind's own switches: [id, label, on by default].
func toggles() -> Array:
	if kind == null or not kind.has_method("toggles"):
		return []
	return kind.call("toggles") as Array


## Whether one of the kind's switches is on (kinds ask this while drawing).
func toggle(id: String) -> bool:
	if not _has_prefs():
		return true
	var key: String = _pref_key(id)
	return bool(Prefs.get_value(key)) if Prefs.is_registered(key) else true


func set_toggle(id: String, on: bool) -> void:
	if not _has_prefs():
		return
	var key: String = _pref_key(id)
	if not Prefs.is_registered(key):
		_reg(key, true, id)
	Prefs.set_value(key, on)
	_size_to_state()
	_update_live()
	queue_redraw()


func shown_gizmo() -> bool:
	return toggle(MENU_SHOW)


func is_live_kind() -> bool:
	return kind != null and kind.has_method("live") and bool(kind.call("live"))


func _size_to_state() -> void:
	var h: float = float(kind.call("height")) if kind != null else 120.0
	if kind != null and not shown_gizmo():
		h = HIDDEN_ROW
	custom_minimum_size = Vector2(0.0, float(Tk.px(h)) + GAP_TOP + GAP_BOTTOM)


func _ready() -> void:
	if not Tk.tokens_changed.is_connected(_on_tokens):
		Tk.tokens_changed.connect(_on_tokens)
	var sess: Node = _session()
	if sess != null and not sess.is_connected("playing_changed", _on_playing):
		sess.connect("playing_changed", _on_playing)
	if _has_prefs() and not Prefs.changed.is_connected(_on_pref):
		Prefs.changed.connect(_on_pref)
	sync()
	_update_live()


func _session() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("/root/Session") if loop is SceneTree else null


func _on_playing(_on: bool) -> void:
	_update_live()


func _on_pref(key: String) -> void:
	if key == PREF_LIVE or key.begins_with(PREF_PREFIX + kind_id + "."):
		_size_to_state()
		_update_live()
		queue_redraw()


## True only when it is worth spending anything: a live kind, switched on here and in Settings, shown, visible
## on screen, and the sequence playing.
func live_wanted() -> bool:
	if not is_live_kind() or not is_visible_in_tree() or not shown_gizmo() or differ:
		return false
	if _has_prefs() and Prefs.is_registered(PREF_LIVE) and not bool(Prefs.get_value(PREF_LIVE)):
		return false
	if not toggle(MENU_LIVE):
		return false
	var sess: Node = _session()
	return sess != null and bool(sess.get("playing"))


func _update_live() -> void:
	var want: bool = live_wanted()
	if want == is_processing():
		return
	set_process(want)
	if not want:
		live_on = false
		live_level = 0.0
		live_l = 0.0
		live_r = 0.0
		if kind != null and kind.has_method("live_stop"):
			kind.call("live_stop", self)
		queue_redraw()
	else:
		live_on = true
		live_clock = 0.0


func _process(dt: float) -> void:
	if not live_wanted():
		_update_live()
		return
	var lv: Vector2 = _levels()
	live_l = maxf(lv.x, live_l - dt * LEVEL_FALL)
	live_r = maxf(lv.y, live_r - dt * LEVEL_FALL)
	live_level = maxf(live_l, live_r)
	live_clock += dt
	live_t = float(panel.call("playhead")) if panel != null and panel.has_method("playhead") else 0.0
	ticks += 1
	if kind != null and kind.has_method("tick"):
		kind.call("tick", self, dt)
	queue_redraw()


## The live left and right level of the sound this effect is on: its clip's audio track when it has one, else the
## whole mix. Linear peaks from the audio engine's meters.
func _levels() -> Vector2:
	if forced_level >= 0.0:
		return Vector2(forced_level, forced_level * 0.6)
	var raw: PackedFloat32Array = PurrBridge.meters() if PurrBridge.available else PackedFloat32Array()
	if raw.size() < 2:
		return Vector2.ZERO
	var at: int = 0
	var c: Object = panel.call("target_clip") if panel != null and panel.has_method("target_clip") else null
	var sq: Object = panel.call("seq") if panel != null and panel.has_method("seq") else null
	if c != null and sq != null:
		var tracks: Array = sq.get("audio_tracks")
		for i: int in tracks.size():
			var tr: Object = tracks[i]
			if tr != null and (tr.get("clips") as Array).has(c):
				at = 2 + i * 2
				break
	if at + 1 >= raw.size():
		at = 0
	return Vector2(raw[at], raw[at + 1])


## Seconds into the clip this effect is on, at the live playhead.
func clip_time() -> float:
	var c: Object = panel.call("target_clip") if panel != null and panel.has_method("target_clip") else null
	if c == null:
		return live_t
	return live_t - float(c.get("start"))


func clip_length() -> float:
	var c: Object = panel.call("target_clip") if panel != null and panel.has_method("target_clip") else null
	return float(c.get("duration")) if c != null else 1.0


func _on_tokens() -> void:
	_box = null
	if kind != null:
		custom_minimum_size.y = float(Tk.px(float(kind.call("height")))) + GAP_TOP + GAP_BOTTOM
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree():
			sync()
		_update_live()
	elif what == NOTIFICATION_EXIT_TREE and not grab.is_empty():
		_finish()


func swap(table: Dictionary) -> void:
	if table.has(uid) and not plant_no_swap:
		uid = String(table[uid])
		_specs_for = ""


func stage() -> Rect2:
	var left: float = float(Tk.px(Tk.sz("button_h"))) + 4.0
	var right: float = float(Tk.px(Tk.sz("pad")))
	return Rect2(left, GAP_TOP, maxf(size.x - left - right, 10.0), maxf(size.y - GAP_TOP - GAP_BOTTOM, 10.0))


func spec(role: String) -> Dictionary:
	if not bind.has(role):
		return {}
	if fixed.has(role):
		return fixed[role]
	_resolve()
	return _specs.get(role, {})


func _resolve() -> void:
	if panel == null or not panel.has_method("target_clip"):
		return
	var c: Object = panel.call("target_clip")
	var want: String = (String(c.get("id")) if c != null else "") + "|" + uid
	if want == _specs_for:
		return
	_specs_for = want
	_specs = {}
	if c == null:
		return
	var by_key: Dictionary = {}
	for item: Dictionary in (panel.call("value_items", c, uid) as Array):
		by_key[String(item["key"])] = item["spec"]
	for r: Variant in bind.keys():
		var key: String = String(bind[r])
		if by_key.has(key):
			_specs[String(r)] = by_key[key]


func has(role: String) -> bool:
	return not spec(role).is_empty()


func value(role: String, fallback: float = 0.0) -> float:
	return float(_values.get(role, fallback))


func start_value(role: String, fallback: float = 0.0) -> float:
	return float(_start.get(role, _values.get(role, fallback)))


func low(role: String, fallback: float = 0.0) -> float:
	return float(spec(role).get("min", fallback))


func high(role: String, fallback: float = 1.0) -> float:
	return float(spec(role).get("max", fallback))


func norm(role: String, fallback: float = 0.5) -> float:
	if not has(role):
		return fallback
	var lo: float = low(role)
	var hi: float = high(role)
	return clampf((value(role) - lo) / (hi - lo), 0.0, 1.0) if hi > lo else 0.0


func denorm(role: String, t: float) -> float:
	return lerpf(low(role), high(role), clampf(t, 0.0, 1.0))


func label(role: String) -> String:
	return String(spec(role).get("label", role.capitalize()))


func choices(role: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for ch: Variant in (spec(role).get("choices", []) as Array):
		out.append(String((ch as Dictionary).get("label", "")) if ch is Dictionary else String(ch))
	return out


func option(key: String, fallback: Variant = null) -> Variant:
	return options.get(key, fallback)


func animated(role: String) -> bool:
	return bool(_animated.get(role, false))


func keyed_here() -> bool:
	return _keyed


func shown(role: String, v: float = NAN) -> String:
	var sp: Dictionary = spec(role)
	var x: float = value(role) if is_nan(v) else v
	var ch: PackedStringArray = choices(role)
	if not ch.is_empty():
		var i: int = clampi(int(round(x)), 0, ch.size() - 1)
		return ch[i]
	var step_: float = float(sp.get("step", 0.01))
	var places: int = 0
	if step_ > 0.0 and step_ < 1.0:
		places = clampi(int(ceil(-log(step_) / log(10.0) - 0.0001)), 0, 3)
	var unit: String = String(sp.get("suffix", ""))
	var mul: float = float(sp.get("display_mul", 1.0))
	var num: String = String.num(x * mul, places)
	if ANGLE_UNITS.has(unit):
		return num + "°"
	if unit.is_empty():
		return num
	return num + (unit if unit.begins_with(" ") else " " + unit)


func col(token: String, alpha: float = 1.0) -> Color:
	var c: Color = Tk.c.get(token, Color.WHITE)
	c.a *= alpha
	return c


func shadow(alpha: float) -> Color:
	return Color(0.0, 0.0, 0.0, alpha * (0.35 if Tk.is_light() else 1.0))


func fs(token: String = "font_tiny") -> int:
	return Tk.fs(Tk.sz(token))


func text(at: Vector2, words: String, token: String = "text_dim", size_token: String = "font_tiny", width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, alpha: float = 1.0) -> Rect2:
	return PmText.draw_at(self, Tk.font("body"), at, words, fs(size_token), col(token, alpha), width, align)


func text_in(area: Rect2, words: String, token: String = "text_dim", size_token: String = "font_tiny", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, alpha: float = 1.0) -> Rect2:
	return PmText.draw_in(self, Tk.font("body"), area, words, fs(size_token), col(token, alpha), align)


func text_width(words: String, size_token: String = "font_tiny") -> float:
	return PmText.width_of(Tk.font("body"), words, fs(size_token))


func text_height(size_token: String = "font_tiny") -> float:
	return Tk.font("body").get_height(fs(size_token))


func _read(sp: Dictionary) -> float:
	var v: Variant = panel.call("current_value", sp)
	if v is Array:
		return float((v as Array)[0]) if not (v as Array).is_empty() else 0.0
	if v is bool:
		return 1.0 if bool(v) else 0.0
	if v is float or v is int:
		return float(v)
	return float(sp.get("default", sp.get("min", 0.0)))


static func _all_same(vals: Array) -> bool:
	for i: int in range(1, vals.size()):
		var a: Variant = vals[0]
		var b: Variant = vals[i]
		if (a is float or a is int) and (b is float or b is int):
			if absf(float(a) - float(b)) > 0.000001 * maxf(1.0, absf(float(a))):
				return false
		elif str(a) != str(b):
			return false
	return true


func sync() -> void:
	if panel == null or kind == null or plant_no_sync:
		return
	var vals: Dictionary = {}
	var anim: Dictionary = {}
	var keyed: bool = false
	var parts: PackedStringArray = PackedStringArray()
	var mixed: bool = false
	var c: Object = panel.call("target_clip") if panel.has_method("target_clip") else null
	var t: float = float(panel.call("playhead")) if panel.has_method("playhead") else 0.0
	for r: Variant in bind.keys():
		var role: String = String(r)
		var sp: Dictionary = spec(role)
		if sp.is_empty():
			continue
		vals[role] = _read(sp)
		if sp.has("members"):
			if not _all_same(panel.call("many_values", sp) as Array):
				mixed = true
		elif c != null and c.has_method("get_param"):
			var path: String = String(sp.get("path", ""))
			var p: Dictionary = c.call("get_param", path)
			if AnimProp.is_animated(p):
				anim[role] = true
				if AnimProp.has_key_at(p, float(c.call("param_time", path, t - float(c.get("start"))))):
					keyed = true
		parts.append(role + "=" + str(vals[role]) + ("a" if anim.has(role) else ""))
	parts.append("m" if mixed else "")
	parts.append("k" if keyed else "")
	_values = vals
	_animated = anim
	_keyed = keyed
	differ = mixed and not plant_ignore_differ
	var sig: String = ",".join(parts)
	if sig != _seen:
		_seen = sig
		asked += 1
		queue_redraw()


func _menu_rect() -> Rect2:
	var s_: float = float(Tk.px(18.0))
	return Rect2(Vector2(float(Tk.px(3.0)), GAP_TOP + float(Tk.px(3.0))), Vector2(s_, s_))


func _draw_menu_button() -> void:
	var m: Rect2 = _menu_rect()
	if _menu_hover:
		draw_rect(m, col("bg_panel_high"), true)
	var c: Vector2 = m.get_center()
	var w: float = m.size.x * 0.32
	var ink: Color = col("text" if _menu_hover else "text_dim")
	var on: bool = shown_gizmo()
	draw_arc(c, w, PI * 0.15, PI * 0.85, 10, ink, 1.2, true)
	draw_arc(c, w, PI * 1.15, PI * 1.85, 10, ink, 1.2, true)
	draw_circle(c, w * 0.38, ink if on else Color(ink, 0.0))
	if not on:
		draw_line(c + Vector2(-w, w), c + Vector2(w, -w), ink, 1.2, true)


func open_menu() -> Control:
	var items: Array = [PmMenu.check_item(MENU_SHOW, "Show this gizmo", shown_gizmo())]
	if is_live_kind():
		items.append(PmMenu.check_item(MENU_LIVE, "React to the sound while playing", toggle(MENU_LIVE)))
	var own: Array = toggles()
	if not own.is_empty():
		items.append(PmMenu.separator())
		for t: Array in own:
			items.append(PmMenu.check_item(String(t[0]), String(t[1]), toggle(String(t[0]))))
	var m: Control = PmMenu.open(self, items, global_position + _menu_rect().end)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_menu_picked)
	return m


func _on_menu_picked(id: String) -> void:
	set_toggle(id, not toggle(id))


func _draw() -> void:
	draws += 1
	_draw_menu_button()
	var r: Rect2 = stage()
	if kind != null and not shown_gizmo():
		var bar: Rect2 = Rect2(r.position, Vector2(r.size.x, float(Tk.px(HIDDEN_ROW))))
		draw_rect(bar, col("bg_shell"), true)
		text_in(bar.grow_individual(-float(Tk.px(6.0)), 0, 0, 0), String(kind.call("title")) + " gizmo hidden. Use the eye to show it.", "text_dim", "font_small")
		return
	if _box == null:
		_box = StyleBoxFlat.new()
		_box.bg_color = col("bg_shell")
		_box.border_color = col("border")
		_box.set_border_width_all(1)
		_box.set_corner_radius_all(int(Tk.px(Tk.sz("radius_panel"))))
		_box.anti_aliasing = true
	draw_style_box(_box, r)
	if kind == null:
		return
	kind.call("draw", self)
	if not _animated.is_empty():
		var d: float = float(Tk.px(4.0))
		var at: Vector2 = Vector2(r.end.x - d * 2.6, r.position.y + d * 2.6)
		var pts := PackedVector2Array([at + Vector2(0, -d), at + Vector2(d, 0), at + Vector2(0, d), at + Vector2(-d, 0)])
		if _keyed:
			draw_colored_polygon(pts, col("text"))
		pts.append(pts[0])
		draw_polyline(pts, col("text_dim"), 1.0, true)
	if differ:
		draw_rect(r.grow(-1.0), col("bg_shell", 0.78), true)
		var pad: float = float(Tk.px(Tk.sz("pad"))) * 2.0
		PmText.draw_lines(self, Tk.font("body"), Rect2(r.position.x + pad, r.position.y + r.size.y * 0.5 - text_height("font_small") * 1.2, r.size.x - pad * 2.0, text_height("font_small") * 2.6), DIFFER_TEXT, fs("font_small"), col("text"), 2)


func _gui_input(event: InputEvent) -> void:
	if kind == null:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed and grab.is_empty() and _menu_rect().grow(2.0).has_point(mb.position):
			open_menu()
			accept_event()
			return
		if mb.pressed and not shown_gizmo():
			set_toggle(MENU_SHOW, true)
			accept_event()
			return
		if mb.pressed:
			if differ:
				accept_event()
				return
			var part: String = String(kind.call("press", self, mb.position))
			if part.is_empty():
				return
			grab = part
			press_at = mb.position
			_moved = false
			_start = _values.duplicate()
			if panel != null and panel.has_method("panel_begin") and not plant_no_live:
				panel.call("panel_begin")
			accept_event()
			queue_redraw()
		elif not grab.is_empty():
			if not _moved:
				_apply(kind.call("click", self, grab, mb.position) as Dictionary)
			_finish()
			accept_event()
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if not grab.is_empty():
			if not _moved and mm.position.distance_to(press_at) < CLICK_SLOP:
				accept_event()
				return
			_moved = true
			_apply(kind.call("drag", self, grab, mm.position) as Dictionary)
			accept_event()
			return
		var over_menu: bool = _menu_rect().grow(2.0).has_point(mm.position)
		if over_menu != _menu_hover:
			_menu_hover = over_menu
			tooltip_text = "Show, hide and choose what this gizmo draws" if over_menu else String(kind.call("tip", self, ""))
			queue_redraw()
		if over_menu or not shown_gizmo():
			return
		var h: String = "" if differ else String(kind.call("hover", self, mm.position))
		if h != hover:
			hover = h
			tooltip_text = String(kind.call("tip", self, h))
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not h.is_empty() else Control.CURSOR_ARROW
			queue_redraw()


func press(at: Vector2) -> bool:
	_gui_input(_button(at, true))
	return not grab.is_empty()


func move_to(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	_gui_input(mm)


func release(at: Vector2) -> void:
	_gui_input(_button(at, false))


static func _button(at: Vector2, down: bool) -> InputEventMouseButton:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = down
	mb.position = at
	return mb


func _apply(want: Dictionary) -> void:
	if want.is_empty() or panel == null:
		return
	var label_: String = String(kind.call("undo_label", grab))
	for r: Variant in want.keys():
		var role: String = String(r)
		var sp: Dictionary = spec(role)
		if sp.is_empty():
			continue
		var v: float = clampf(float(want[r]), float(sp.get("min", -INF)), float(sp.get("max", INF)))
		var step_: float = float(sp.get("step", 0.0))
		var kind_name: String = String(sp.get("kind", "float"))
		if kind_name == "int" or kind_name == "enum":
			v = round(v)
		elif step_ > 0.0:
			v = clampf(snappedf(v, step_ * 0.1), float(sp.get("min", -INF)), float(sp.get("max", INF)))
		if _values.has(role) and absf(float(_values[role]) - v) < 0.0000001:
			continue
		var out: Variant = int(v) if (kind_name == "int" or kind_name == "enum") else v
		if plant_flat and sp.has("uid"):
			var c: Object = panel.call("target_clip")
			Verbs.set_effect_param(panel.call("doc"), panel.call("seq"), String(c.get("id")), String(sp["uid"]), String(sp["key"]), out, -1.0, false)
		else:
			panel.call("panel_write", sp, out, label_)
		_values[role] = v
		writes += 1
	queue_redraw()


func _finish() -> void:
	var label_: String = String(kind.call("undo_label", grab)) if kind != null else ""
	grab = ""
	frozen = {}
	_start = {}
	if panel != null and panel.has_method("panel_end") and not plant_no_live:
		panel.call("panel_end", label_)
	queue_redraw()

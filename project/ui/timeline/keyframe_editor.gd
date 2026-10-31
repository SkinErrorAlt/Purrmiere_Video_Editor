extends Control

signal selection_changed
signal keys_edited
signal auto_key_changed(on: bool)
signal height_changed(h: float)

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const KeyDragCmds := preload("res://doc/commands/key_drag_cmds.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const Icons := preload("res://ui/kit/icons.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const EffectRegistry := preload("res://engine/effect_registry.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const PlayheadGlide := preload("res://ui/timeline/playhead_glide.gd")
const PREF_PLAYED := "keys.played_time"
const PLAYED_TIP := "Show keys at played time: where the animation speed makes them happen"
const REFUSE_TEXT := "The animation speed runs backwards somewhere on this clip, so a key cannot be moved at played time. Turn off Played time to move it."
const REPEAT_ALPHA := 0.35
const CURVE_STEP := 2.0
const FEW_KEYS := 16
const CURVE_STEP_DRAG := 4.0
const KEY_R := 4.5
const HIT_R := 7.0
const SLOP := 4.0
const KEY_SLOP := 2.0
const PAD_R := 8.0
const PAD_V := 6.0
const RULER_FULL := 18.0
const RULER_MINI := 13.0
const GUTTER_FULL := 46.0
const GUTTER_MINI := 34.0
const GRIP_H := 6.0
const MINI_DEFAULT_H := 72.0
const MINI_MIN_H := 48.0
const MINI_MAX_H := 640.0
const FULL_MIN_H := 160.0
const EDGE_PX := 10.0
const EDGE_SPEED := 8.0
const EDGE_MAX_PX := 200.0
const OVER_REACH := 2.0
const HANDLE_REACH := 4.0
const VZOOM_PER_PX := 0.01
const TIME_SPAN_MIN_FRAMES := 4.0
const TIME_SPAN_MAX_CLIPS := 20.0
const VALUE_SPAN_MIN := 0.000001
const VALUE_SPAN_MAX := 1.0e12
const DOPE_ROW := 20.0
const MODES: PackedStringArray = ["value", "velocity", "dope"]
const INTERPS: Array = [["linear", "Linear"], ["ease_in", "Ease in"], ["ease_out", "Ease out"], ["ease_both", "Ease both"], ["bezier", "Bezier"], ["continuous", "Continuous"], ["auto", "Auto"], ["hold", "Hold"]]
const PREF_WHEEL_NATURAL := "keys.wheel_natural"
const PREF_MINI_HEIGHTS := "keys.mini_heights"
const WHEEL_ZOOM := 1.18
const WHEEL_PAN := 0.1
const PEER_GROUP := "pm_key_editors"
const BOX_REPLACE := "replace"
const BOX_ADD := "add"
const BOX_TOGGLE := "toggle"

var clip_id: String = ""
var path: String = ""
var paths: PackedStringArray = PackedStringArray()
var mode: String = "value"
var mini: bool = false
var snap_frames: bool = true
var shift_is_value: bool = true
var auto_key: bool = false
var t0: float = 0.0
var t1: float = 10.0
var v0: float = -1.0
var v1: float = 1.0
var selected: PackedFloat64Array = PackedFloat64Array()
var doc_override: Project = null
var seq_override: Sequence = null
var range_lo: float = -INF
var range_hi: float = INF
var display_mul: float = 1.0
var suffix: String = ""
var paint_count: int = 0
var _scrubbing: bool = false
var _glide: PlayheadGlide = PlayheadGlide.new()
var _anchor_t: float = -1.0
var _press: Vector2 = Vector2.ZERO
var _press_t: float = 0.0
var _press_v: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _acc: Vector2 = Vector2.ZERO
var _acc_t: float = 0.0
var _acc_v: float = 0.0
var _last_mods: Dictionary = {}
var _drag: String = ""
var _drag_active: bool = false
var _drag_key_t: float = -1.0
var _moving_value: bool = false
var _moving_time: bool = false
var _origin_prop: Dictionary = {}
var _origin_sel: PackedFloat64Array = PackedFloat64Array()
var _origin_lo_v: float = 0.0
var _origin_hi_v: float = 0.0
var _handle_side: String = ""
var _handle_origin: Vector2 = Vector2.ZERO
var _handle_seg: float = 0.0
var _handle_reach: float = 1.0
var _handle_key_v: float = 0.0
var _grip_h0: float = 0.0
var _vzoom_anchor: float = 0.0
var _box: Rect2 = Rect2()
var _box_mode: String = BOX_REPLACE
var _box_base: PackedFloat64Array = PackedFloat64Array()
var _hover_key: float = -INF
var _hover_line: Vector2 = Vector2(INF, INF)
var _hover_zone: String = ""
var _hover_pos: Vector2 = Vector2.ZERO
var _fit_pending: bool = true
var _font: Font = null
var _fs: int = 11
var _panning: bool = false
var played_time: bool = false
var _hit_axis: float = 0.0
var _hover_axis: float = 0.0
var _drag_axis_t: float = 0.0
var _time_locked: bool = false
var _refused: bool = false
var _played_btn: Button = null
var _view_src: Array = []
var _view_keys: Array[Dictionary] = []
var _over_sig: Array = []
var _over_flags: PackedByteArray = PackedByteArray()
var _curve_cache: Dictionary = {}
var _key_cache: Dictionary = {}
static var _tri_cache: PackedInt32Array = PackedInt32Array()
var _span_hash: int = 0
var _rect_size: Vector2 = Vector2(-1.0, -1.0)
var _rect_unit: float = -1.0
var _rect_cached: Rect2 = Rect2()
var _span_hash_empty: bool = true
var _span_value: Vector2 = Vector2.ZERO


static func make(clip_id_: String, path_: String, mini_: bool) -> Control:
	var script: GDScript = load("res://ui/timeline/keyframe_editor.gd")
	var e: Control = script.new()
	e.set("clip_id", clip_id_)
	e.set("path", path_)
	e.set("mini", mini_)
	return e


static func ensure_prefs() -> void:
	if not Prefs.is_registered(PREF_WHEEL_NATURAL):
		Prefs.register(PREF_WHEEL_NATURAL, false, {"label": "Keyframe editor: natural (touchpad) scrolling", "type": "bool"})
	if not Prefs.is_registered(PREF_MINI_HEIGHTS):
		Prefs.register(PREF_MINI_HEIGHTS, {}, {"label": "Keyframe editor heights under Effect Controls (drag the bottom edge of an editor to change one)", "type": "heights"})
	if not Prefs.is_registered(PREF_PLAYED):
		Prefs.register(PREF_PLAYED, false, {"label": "Keyframe editor: show keys at played time (where the animation speed makes them happen)", "type": "bool"})


func _init() -> void:
	name = "KeyframeEditor"
	add_to_group(PEER_GROUP)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	clip_contents = true
	gui_input.connect(_on_input)
	mouse_exited.connect(_on_exit)
	resized.connect(queue_redraw)


func _ready() -> void:
	ensure_prefs()
	_font = Tk.font("body")
	_fs = Tk.fs(Tk.sz("font_tiny"))
	if mini:
		restore_mini_height()
	else:
		custom_minimum_size = Vector2(0.0, _px(FULL_MIN_H))
	if not Session.playhead_changed.is_connected(_on_playhead):
		Session.playhead_changed.connect(_on_playhead)
	played_time = bool(Prefs.get_value(PREF_PLAYED))
	if not Prefs.changed.is_connected(_on_played_pref):
		Prefs.changed.connect(_on_played_pref)
	if mini:
		_make_played_button()
	set_process(false)
	queue_redraw()


func _make_played_button() -> void:
	_played_btn = PmButton.make("", "rate", true)
	_played_btn.name = "PlayedTime"
	_played_btn.set("quiet", true)
	_played_btn.set("icon_px", 10.0)
	_played_btn.focus_mode = Control.FOCUS_NONE
	_played_btn.button_pressed = played_time
	PmUI.tip(_played_btn, PLAYED_TIP)
	_played_btn.toggled.connect(_on_played_toggled)
	_played_btn.visible = false
	add_child(_played_btn)
	resized.connect(_place_played_button)
	_place_played_button()


func _place_played_button() -> void:
	if _played_btn == null:
		return
	var h: float = ruler_h()
	var w: float = h + _px(8.0)
	_played_btn.custom_minimum_size = Vector2(w, h)
	_played_btn.size = Vector2(w, h)
	_played_btn.position = Vector2(maxf(size.x - w - 1.0, 0.0), 0.0)


func _on_played_toggled(on: bool) -> void:
	if on != bool(Prefs.get_value(PREF_PLAYED)):
		Prefs.set_value(PREF_PLAYED, on)


func _on_played_pref(key: String) -> void:
	if key != PREF_PLAYED:
		return
	played_time = bool(Prefs.get_value(PREF_PLAYED))
	if _played_btn != null and _played_btn.button_pressed != played_time:
		_played_btn.set_pressed_no_signal(played_time)
	_refused = false
	queue_redraw()


func set_played_time(on: bool) -> void:
	ensure_prefs()
	Prefs.set_value(PREF_PLAYED, on)
	played_time = on
	queue_redraw()


func sync_played_button() -> void:
	if _played_btn == null:
		return
	var want: bool = warp_available()
	if _played_btn.visible != want:
		_played_btn.visible = want
	_place_played_button()


func warp_available() -> bool:
	var c: Clip = clip()
	return c != null and c.path_warped(path)


func played_on(p_path: String = "") -> bool:
	if Clip.is_transition_path(path if p_path.is_empty() else p_path):
		return clip() != null
	if not played_time:
		return false
	var c: Clip = clip()
	if c == null:
		return false
	return c.path_warped(path if p_path.is_empty() else p_path)


func axis_times(kt: float, p_path: String = "") -> PackedFloat64Array:
	if not played_on(p_path):
		return PackedFloat64Array([kt])
	return clip().played_times_for(path if p_path.is_empty() else p_path, kt)


func key_t_of(axis_t: float, p_path: String = "") -> float:
	if not played_on(p_path):
		return axis_t
	return clip().param_time(path if p_path.is_empty() else p_path, axis_t)


func eval_axis(p: Dictionary, axis_t: float, dur: float, f: float, p_path: String = "") -> Variant:
	return AnimProp.evaluate(p, key_t_of(axis_t, p_path), dur, f)


func playhead_axis() -> float:
	var c: Clip = clip()
	var s: Sequence = seq()
	if c == null or s == null:
		return 0.0
	var local: float = s.playhead - c.start
	if played_on():
		return local
	return c.param_time(path, local)


func local_of_axis(axis_t: float) -> float:
	var c: Clip = clip()
	if c == null or played_on() or not c.path_warped(path):
		return axis_t
	for u: float in c.played_times_for(path, axis_t):
		if u >= 0.0 and u <= c.duration:
			return u
	return axis_t


func playhead_key_time() -> float:
	var c: Clip = clip()
	var s: Sequence = seq()
	if c == null or s == null:
		return 0.0
	var local: float = s.playhead - c.start
	if c.path_warped(path):
		return c.param_time(path, local)
	return snap_t(local)


func _axes_of(times: PackedFloat64Array) -> PackedFloat64Array:
	if not played_on():
		return times
	var out: PackedFloat64Array = PackedFloat64Array()
	for t: float in times:
		out.append_array(axis_times(t))
	out.sort()
	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _drag.is_empty():
		cancel_drag()


func _on_playhead(_t: float) -> void:
	queue_redraw()


func _px(v: float) -> float:
	return float(Tk.px(v))


func doc() -> Project:
	return doc_override if doc_override != null else Session.doc


func seq() -> Sequence:
	return seq_override if seq_override != null else Session.seq()


func clip() -> Clip:
	var s: Sequence = seq()
	if s == null or clip_id.is_empty():
		return null
	return s.clip_by_id(clip_id)


func set_target(clip_id_: String, path_: String) -> void:
	var changed: bool = clip_id != clip_id_ or path != path_
	if changed:
		selected = PackedFloat64Array()
		_fit_pending = true
	clip_id = clip_id_
	path = path_
	if changed and mini and is_inside_tree():
		restore_mini_height()
	queue_redraw()


func set_paths(list: PackedStringArray) -> void:
	paths = list
	queue_redraw()


func set_mode(m: String) -> void:
	if m in MODES:
		mode = m
		queue_redraw()


func prop() -> Dictionary:
	var c: Clip = clip()
	if c == null:
		return {}
	return c.get_param(path)


func keys() -> Array[Dictionary]:
	return AnimProp.keys(prop())


func keys_view() -> Array[Dictionary]:
	var p: Dictionary = prop()
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0:
		_view_src = []
		_view_keys = []
		return _view_keys
	var src: Variant = (p["layers"][li] as Dictionary).get("keys", [])
	if src is Array and is_same(src, _view_src) and (src as Array).size() == _view_keys.size():
		return _view_keys
	var fresh: Array[Dictionary] = []
	var plain: bool = src is Array
	if plain:
		for k: Variant in src:
			if not (k is Dictionary):
				plain = false
				break
	if plain:
		fresh.assign(src)
	else:
		fresh = AnimProp.keys(p)
	_view_keys = fresh
	_view_src = src if src is Array else []
	return _view_keys


static func sorted_times(times: PackedFloat64Array) -> PackedFloat64Array:
	var out: PackedFloat64Array = times.duplicate()
	out.sort()
	return out


static func has_near(sorted: PackedFloat64Array, t: float) -> bool:
	var i: int = sorted.bsearch(t - AnimProp.KEY_TOLERANCE, true)
	return i < sorted.size() and sorted[i] <= t + AnimProp.KEY_TOLERANCE


static func segment_of(times: PackedFloat64Array, t: float) -> int:
	var n: int = times.size()
	if n < 2:
		return -1
	var j: int = times.bsearch(t, true)
	var i: int = j - 1
	if j == 0 and t == times[0]:
		i = 0
	if i < 0 or i + 1 >= n:
		return -1
	if t >= times[i] and t <= times[i + 1]:
		return i
	return -1


static func plain_keys(p: Dictionary) -> bool:
	return AnimTime.plain_keys(p)


static func segment_stays_inside(k: Dictionary) -> bool:
	return AnimTime.segment_stays_inside(k)


func segment_overshoots(ks: Array[Dictionary], p: Dictionary, dur: float, f: float) -> PackedByteArray:
	var n: int = ks.size()
	var out: PackedByteArray = PackedByteArray()
	out.resize(maxi(n - 1, 0))
	var sig: Array = [p.hash(), dur, f]
	if sig == _over_sig and _over_flags.size() == out.size():
		return _over_flags
	var plain: bool = plain_keys(p)
	for i: int in range(n - 1):
		if plain and segment_stays_inside(ks[i]):
			out[i] = 0
			continue
		var ta: float = float(ks[i].get("t", 0.0))
		var tb: float = float(ks[i + 1].get("t", 0.0))
		out[i] = 1 if _overshoot_between(p, ta, tb, comp0(ks[i].get("v", 0.0)), comp0(ks[i + 1].get("v", 0.0)), dur, f) else 0
	_over_sig = sig
	_over_flags = out
	return out


func curve_step() -> float:
	if _drag_active and (_drag == "move" or _drag == "handle" or _drag == "scale"):
		return CURVE_STEP_DRAG
	return CURVE_STEP


func _warp_sig() -> Array:
	var c: Clip = clip()
	if c == null or not played_on():
		return []
	return [c.anim_speed.hash(), c.anim_start, c.duration, c.speed_sig(), path]


func fps() -> float:
	var s: Sequence = seq()
	return s.fps if s != null and s.fps > 0.0 else 30.0


func clip_duration() -> float:
	var c: Clip = clip()
	if c == null:
		return 10.0
	return maxf(c.duration, 1.0 / fps())


func ruler_h() -> float:
	return maxf(_px(RULER_MINI if mini else RULER_FULL), ceil(Tk.font("mono").get_height(Tk.fs(Tk.sz("font_tiny")))) + 1.0)


func gutter_w() -> float:
	return _px(GUTTER_MINI if mini else GUTTER_FULL)


func grip_h() -> float:
	return _px(GRIP_H) if mini else 0.0


func plot_rect() -> Rect2:
	var unit: float = Tk.ui_scale * Tk.density
	if size == _rect_size and unit == _rect_unit:
		return _rect_cached
	var left: float = gutter_w()
	var top: float = ruler_h() + _px(PAD_V)
	var bottom: float = grip_h() + _px(PAD_V)
	_rect_cached = Rect2(left, top, maxf(size.x - left - _px(PAD_R), 1.0), maxf(size.y - top - bottom, 1.0))
	_rect_size = size
	_rect_unit = unit
	return _rect_cached


func zone_at(pos: Vector2) -> String:
	if mini and pos.y >= size.y - grip_h():
		return "grip"
	if pos.y < ruler_h():
		return "corner" if pos.x < gutter_w() else "ruler"
	if pos.x < gutter_w() and mode != "dope":
		return "gutter"
	return "plot"


func x_of(t: float) -> float:
	var r: Rect2 = plot_rect()
	return r.position.x + (t - t0) / maxf(t1 - t0, 0.0001) * r.size.x


func t_of(x: float) -> float:
	var r: Rect2 = plot_rect()
	return t0 + (x - r.position.x) / maxf(r.size.x, 1.0) * (t1 - t0)


func y_of(v: float) -> float:
	var r: Rect2 = plot_rect()
	return r.end.y - (v - v0) / maxf(v1 - v0, VALUE_SPAN_MIN) * r.size.y


func v_of(y: float) -> float:
	var r: Rect2 = plot_rect()
	return v0 + (r.end.y - y) / maxf(r.size.y, 1.0) * (v1 - v0)


static func comp0(v: Variant) -> float:
	if v is Array and not (v as Array).is_empty():
		return float((v as Array)[0])
	if v is bool:
		return 1.0 if v else 0.0
	if v is float or v is int:
		return float(v)
	return 0.0


static func component_count(v: Variant) -> int:
	if v is Array:
		return (v as Array).size()
	return 1


static func comp(v: Variant, i: int) -> float:
	if v is Array:
		var a: Array = v
		if i < a.size():
			return float(a[i])
		return 0.0
	return comp0(v)


static func offset_value(v: Variant, dv: float) -> Variant:
	if v is Array:
		var out: Array = []
		for e: Variant in v:
			out.append(float(e) + dv)
		return out
	if v is bool:
		return v
	return float(v) + dv


func timeline_window(c: Clip) -> Vector2:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return Vector2(-1.0, -1.0)
	var host: Node = (loop as SceneTree).root.get_node_or_null("/root/Host")
	if host == null or not host.has_method("get_impl"):
		return Vector2(-1.0, -1.0)
	var tl: Object = host.call("get_impl", "IPanel", "timeline")
	if tl == null:
		return Vector2(-1.0, -1.0)
	var canvas: Object = tl.get("canvas")
	if canvas == null or not canvas.has_method("t_of"):
		return Vector2(-1.0, -1.0)
	var left: float = float(canvas.call("t_of", float(canvas.get("header_w")))) - c.start
	var right: float = float(canvas.call("t_of", float((canvas as Control).size.x))) - c.start
	if not (right > left):
		return Vector2(-1.0, -1.0)
	var lo: float = maxf(left, 0.0)
	var hi: float = minf(right, maxf(c.duration, 1.0 / fps()))
	if hi - lo < 1.0 / fps():
		return Vector2(-1.0, -1.0)
	return Vector2(lo, hi)


func fit() -> void:
	var c: Clip = clip()
	if c == null:
		t0 = 0.0
		t1 = 10.0
		v0 = -1.0
		v1 = 1.0
		queue_redraw()
		return
	t0 = 0.0
	t1 = maxf(c.duration, 1.0 / fps())
	if Clip.is_transition_path(path):
		var span: Vector2 = c.span_for_path(path)
		if span.y > span.x:
			t0 = span.x - c.start
			t1 = span.y - c.start
			fit_values()
			return
	if mini:
		var win: Vector2 = timeline_window(c)
		if win.x >= 0.0:
			t0 = win.x
			t1 = win.y
	fit_values()


func fit_values() -> void:
	var c: Clip = clip()
	if c == null:
		v0 = -1.0
		v1 = 1.0
		queue_redraw()
		return
	var lo: float = INF
	var hi: float = -INF
	var p: Dictionary = prop()
	var n: int = 40
	for i: int in n + 1:
		var tt: float = t0 + (t1 - t0) * float(i) / float(n)
		var v: Variant = eval_axis(p, tt, c.duration, fps())
		for k: int in component_count(v):
			var f: float = comp(v, k)
			lo = minf(lo, f)
			hi = maxf(hi, f)
	for k: Dictionary in AnimProp.keys(p):
		for ci: int in component_count(k.get("v", 0.0)):
			var f2: float = comp(k.get("v", 0.0), ci)
			lo = minf(lo, f2)
			hi = maxf(hi, f2)
	if lo == INF:
		lo = 0.0
		hi = 1.0
	var rng: Vector2 = declared_range(c, path)
	if rng.x > -INF and rng.y < INF and rng.y - rng.x > 0.0 and rng.y - rng.x < (hi - lo) * 6.0 + 1.0:
		lo = minf(lo, rng.x)
		hi = maxf(hi, rng.y)
	_set_value_view(lo, hi, 0.12 if mini else 0.2)
	_fit_pending = false
	queue_redraw()


func _set_value_view(lo: float, hi: float, margin_frac: float) -> void:
	var a: float = lo
	var b: float = hi
	if b - a < 0.0001:
		var pad: float = maxf(absf(b) * 0.5, 0.5)
		a -= pad
		b += pad
	var margin: float = (b - a) * margin_frac
	v0 = a - margin
	v1 = b + margin


func frame_keys() -> void:
	var c: Clip = clip()
	var ks: Array[Dictionary] = keys()
	if c == null or ks.is_empty():
		fit()
		return
	var times: PackedFloat64Array = selected_times()
	if times.is_empty():
		times = all_times()
	var axes: PackedFloat64Array = _axes_of(times)
	var lo_t: float = INF
	var hi_t: float = -INF
	for t: float in axes:
		lo_t = minf(lo_t, t)
		hi_t = maxf(hi_t, t)
	if axes.is_empty():
		fit()
		return
	var f: float = fps()
	var min_span: float = 10.0 / f
	if hi_t - lo_t < min_span:
		var mid: float = (lo_t + hi_t) * 0.5
		lo_t = mid - min_span * 0.5
		hi_t = mid + min_span * 0.5
	var pad_t: float = (hi_t - lo_t) * 0.1
	t0 = lo_t - pad_t
	t1 = hi_t + pad_t
	_clamp_time()
	if mode != "dope":
		var lo_v: float = INF
		var hi_v: float = -INF
		for k: Dictionary in ks:
			var kt: float = float(k.get("t", 0.0))
			if not _in_times(times, kt):
				continue
			for ci: int in component_count(k.get("v", 0.0)):
				var kv: float = comp(k.get("v", 0.0), ci)
				lo_v = minf(lo_v, kv)
				hi_v = maxf(hi_v, kv)
		if axes.size() >= 2:
			var p: Dictionary = prop()
			var from: float = axes[0]
			var to: float = axes[axes.size() - 1]
			for i: int in 41:
				var tt: float = from + (to - from) * float(i) / 40.0
				var v: Variant = eval_axis(p, tt, c.duration, f)
				for ci2: int in component_count(v):
					lo_v = minf(lo_v, comp(v, ci2))
					hi_v = maxf(hi_v, comp(v, ci2))
		if lo_v < INF:
			_set_value_view(lo_v, hi_v, 0.15)
	_fit_pending = false
	queue_redraw()


static func _in_times(times: PackedFloat64Array, t: float) -> bool:
	for s: float in times:
		if absf(s - t) <= AnimProp.KEY_TOLERANCE:
			return true
	return false


func _clamp_time() -> void:
	var span: float = t1 - t0
	var dur: float = clip_duration()
	var lo_span: float = TIME_SPAN_MIN_FRAMES / fps()
	var hi_span: float = maxf(dur, 1.0) * TIME_SPAN_MAX_CLIPS
	if span < lo_span or span > hi_span:
		var mid: float = (t0 + t1) * 0.5
		span = clampf(span, lo_span, hi_span)
		t0 = mid - span * 0.5
		t1 = mid + span * 0.5
	var lo: float = -span * 0.5
	var hi: float = dur + span * 0.5
	if t0 < lo:
		t0 = lo
		t1 = t0 + span
	if t1 > hi:
		t1 = hi
		t0 = t1 - span


func zoom_time(factor: float, at: float) -> void:
	var span: float = (t1 - t0) * factor
	var frac: float = (at - t0) / maxf(t1 - t0, 0.0001)
	t0 = at - span * frac
	t1 = t0 + span
	_clamp_time()
	queue_redraw()


func pan_time(dt: float) -> void:
	t0 += dt
	t1 += dt
	_clamp_time()
	queue_redraw()


func zoom_values(factor: float, at: float) -> void:
	var span: float = clampf((v1 - v0) * factor, VALUE_SPAN_MIN, VALUE_SPAN_MAX)
	var frac: float = (at - v0) / maxf(v1 - v0, VALUE_SPAN_MIN)
	v0 = at - span * frac
	v1 = v0 + span
	queue_redraw()


func pan_values(dv: float) -> void:
	v0 += dv
	v1 += dv
	queue_redraw()


func snap_t(t: float) -> float:
	if not snap_frames:
		return t
	var f: float = fps()
	return round(t * f) / f


func key_at_pos(pos: Vector2) -> float:
	var best: float = -INF
	var best_d: float = HIT_R
	if mode == "dope":
		var rows: PackedStringArray = _dope_rows()
		for i: int in rows.size():
			var c: Clip = clip()
			if c == null:
				break
			var row_y: float = plot_rect().position.y + DOPE_ROW * float(i) + DOPE_ROW * 0.5
			if absf(pos.y - row_y) > DOPE_ROW * 0.5:
				continue
			for k: Dictionary in AnimProp.keys(c.get_param(rows[i])):
				var kt: float = float(k.get("t", 0.0))
				for ax: float in axis_times(kt, rows[i]):
					var d: float = absf(x_of(ax) - pos.x)
					if d < best_d and rows[i] == path:
						best_d = d
						best = kt
						_hit_axis = ax
		return best
	for k: Dictionary in keys_view():
		var kt: float = float(k.get("t", 0.0))
		var kv: float = comp0(k.get("v", 0.0))
		for ax2: float in axis_times(kt):
			var d: float = Vector2(x_of(ax2), y_of(kv)).distance_to(pos)
			if d < best_d:
				best_d = d
				best = kt
				_hit_axis = ax2
	return best


func handle_of(k: Dictionary, side: String, seg: float) -> Vector2:
	var dt: float = seg / 3.0 if side == "ho" else -seg / 3.0
	var dv: float = 0.0
	if k.get(side) is Array and (k[side] as Array).size() >= 2:
		var h: Array = k[side]
		dt = float(h[0])
		dv = comp0(h[1])
	if side == "ho":
		dt = clampf(dt, 0.0, seg)
	else:
		dt = clampf(dt, -seg, 0.0)
	return Vector2(dt, dv)


func handle_points() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if mode != "value" or selected.is_empty() or played_on():
		return out
	var ks: Array[Dictionary] = keys_view()
	var picked: PackedFloat64Array = sorted_times(selected)
	for i: int in ks.size():
		var k: Dictionary = ks[i]
		var kt: float = float(k.get("t", 0.0))
		if not has_near(picked, kt):
			continue
		var kv: float = comp0(k.get("v", 0.0))
		if String(k.get("i", "")) == "bezier" and i + 1 < ks.size():
			var seg: float = float(ks[i + 1].get("t", 0.0)) - kt
			var h: Vector2 = handle_of(k, "ho", seg)
			out.append({"t": kt, "v": kv, "side": "ho", "seg": seg, "h": h, "pos": Vector2(x_of(kt + h.x), y_of(kv + h.y))})
		if i > 0 and String(ks[i - 1].get("i", "")) == "bezier":
			var seg2: float = kt - float(ks[i - 1].get("t", 0.0))
			var h2: Vector2 = handle_of(k, "hi", seg2)
			out.append({"t": kt, "v": kv, "side": "hi", "seg": seg2, "h": h2, "pos": Vector2(x_of(kt + h2.x), y_of(kv + h2.y))})
	return out


func handle_at_pos(pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = HIT_R
	for hp: Dictionary in handle_points():
		var d: float = (hp["pos"] as Vector2).distance_to(pos)
		if d < best_d:
			best_d = d
			best = hp
	return best


func _dope_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	if paths.is_empty():
		if not path.is_empty():
			rows.append(path)
	else:
		rows = paths.duplicate()
		if not path.is_empty() and not rows.has(path):
			rows.insert(0, path)
	return rows


func select_keys(times: PackedFloat64Array, add: bool) -> void:
	if not add:
		selected = PackedFloat64Array()
	for t: float in times:
		if not _has_selected(t):
			selected.append(t)
	selection_changed.emit()
	queue_redraw()


func _has_selected(t: float) -> bool:
	for s: float in selected:
		if absf(s - t) <= AnimProp.KEY_TOLERANCE:
			return true
	return false


func toggle_key(t: float) -> void:
	for i: int in selected.size():
		if absf(selected[i] - t) <= AnimProp.KEY_TOLERANCE:
			selected.remove_at(i)
			selection_changed.emit()
			queue_redraw()
			return
	selected.append(t)
	selection_changed.emit()
	queue_redraw()


func select_range(a: float, b: float) -> void:
	var lo: float = minf(a, b)
	var hi: float = maxf(a, b)
	var out: PackedFloat64Array = PackedFloat64Array()
	for k: Dictionary in keys():
		var kt: float = float(k.get("t", 0.0))
		if kt >= lo - AnimProp.KEY_TOLERANCE and kt <= hi + AnimProp.KEY_TOLERANCE:
			out.append(kt)
	select_keys(out, false)


static func box_select(ks: Array[Dictionary], ta: float, tb: float, va: float, vb: float) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var lo_t: float = minf(ta, tb)
	var hi_t: float = maxf(ta, tb)
	var lo_v: float = minf(va, vb)
	var hi_v: float = maxf(va, vb)
	for k: Dictionary in ks:
		var kt: float = float(k.get("t", 0.0))
		var kv: float = comp0(k.get("v", 0.0))
		if kt >= lo_t and kt <= hi_t and kv >= lo_v and kv <= hi_v:
			out.append(kt)
	return out


static func box_mode_for(shift: bool, ctrl: bool) -> String:
	if ctrl:
		return BOX_TOGGLE
	if shift:
		return BOX_ADD
	return BOX_REPLACE


static func index_near(list: PackedFloat64Array, t: float) -> int:
	for i: int in list.size():
		if absf(list[i] - t) <= AnimProp.KEY_TOLERANCE:
			return i
	return -1


static func unique_times(list: PackedFloat64Array) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	for t: float in list:
		if index_near(out, t) < 0:
			out.append(t)
	return out


static func merge_selection(base: PackedFloat64Array, found: PackedFloat64Array, box_mode: String) -> PackedFloat64Array:
	var picked: PackedFloat64Array = unique_times(found)
	if box_mode == BOX_REPLACE:
		return picked
	var out: PackedFloat64Array = unique_times(base)
	for t: float in picked:
		var i: int = index_near(out, t)
		if i < 0:
			out.append(t)
		elif box_mode == BOX_TOGGLE:
			out.remove_at(i)
	return out


func dope_band() -> Vector2:
	var rows: PackedStringArray = _dope_rows()
	var row: int = -1
	for i: int in rows.size():
		if rows[i] == path:
			row = i
			break
	if row < 0:
		return Vector2(INF, -INF)
	var top: float = plot_rect().position.y + DOPE_ROW * float(row)
	return Vector2(top, top + DOPE_ROW)


func key_screen_y(k: Dictionary, axis_t: float, p: Dictionary, dur: float, f: float) -> float:
	if mode == "value":
		return y_of(comp0(k.get("v", 0.0)))
	if played_on():
		return y_of(_velocity_axis(p, axis_t, dur, f))
	return y_of(_velocity_at(p, float(k.get("t", 0.0)), dur, f))


func box_hits(box: Rect2) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var c: Clip = clip()
	if c == null:
		return out
	var dope: bool = mode == "dope"
	var band: Vector2 = dope_band() if dope else Vector2.ZERO
	if dope and (band.y < box.position.y or band.x > box.end.y):
		return out
	var p: Dictionary = prop()
	var dur: float = c.duration
	var f: float = fps()
	for k: Dictionary in keys():
		var kt: float = float(k.get("t", 0.0))
		for ax: float in axis_times(kt):
			var x: float = x_of(ax)
			if x < box.position.x or x > box.end.x:
				continue
			if not dope:
				var y: float = key_screen_y(k, ax, p, dur, f)
				if y < box.position.y or y > box.end.y:
					continue
			out.append(kt)
			break
	return out


static func move_keys(p: Dictionary, times: PackedFloat64Array, dt: float, dv: float) -> Dictionary:
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0:
		return p.duplicate(true)
	var out: Dictionary = p.duplicate()
	var layers: Array = (p["layers"] as Array).duplicate()
	var layer: Dictionary = (layers[li] as Dictionary).duplicate()
	layers[li] = layer
	out["layers"] = layers
	var ks: Array = layer.get("keys", [])
	var picked: PackedFloat64Array = sorted_times(times)
	if picked.size() <= FEW_KEYS:
		var few: Array = _move_few(ks, picked, dt, dv)
		if not few.is_empty() or ks.is_empty():
			layer["keys"] = few
			return out
	var moved: Array = []
	var kept: Array = []
	for k: Variant in ks:
		var kd: Dictionary = k
		var kt: float = float(kd.get("t", 0.0))
		var hit: bool = has_near(picked, kt)
		if hit:
			kd = kd.duplicate(true)
			kd["t"] = maxf(kt + dt, 0.0)
			if dv != 0.0:
				kd["v"] = offset_value(kd.get("v", 0.0), dv)
			moved.append(kd)
		else:
			kept.append(kd)
	var landed: PackedFloat64Array = PackedFloat64Array()
	for md: Dictionary in moved:
		landed.append(float(md["t"]))
	landed.sort()
	var staying: Array = []
	for kd: Dictionary in kept:
		if not has_near(landed, float(kd["t"])):
			staying.append(kd)
	layer["keys"] = merge_by_time(staying, moved)
	return out


static func _lower_index(list: Array, t: float) -> int:
	var a: int = 0
	var b: int = list.size()
	while a < b:
		var mid: int = (a + b) >> 1
		if float((list[mid] as Dictionary).get("t", 0.0)) < t:
			a = mid + 1
		else:
			b = mid
	return a


static func _near_index(list: Array, t: float) -> int:
	var i: int = _lower_index(list, t - AnimProp.KEY_TOLERANCE)
	if i < list.size() and float((list[i] as Dictionary).get("t", 0.0)) <= t + AnimProp.KEY_TOLERANCE:
		return i
	return -1


static func _move_few(ks: Array, picked: PackedFloat64Array, dt: float, dv: float) -> Array:
	var idxs: PackedInt32Array = PackedInt32Array()
	for t: float in picked:
		var i: int = _near_index(ks, t)
		if i < 0:
			return []
		if i + 1 < ks.size() and float((ks[i + 1] as Dictionary).get("t", 0.0)) <= t + AnimProp.KEY_TOLERANCE:
			return []
		if idxs.is_empty() or idxs[idxs.size() - 1] != i:
			idxs.append(i)
	for j: int in range(1, idxs.size()):
		if idxs[j] <= idxs[j - 1]:
			return []
	var moved: Array = []
	for i2: int in idxs:
		var kd: Dictionary = (ks[i2] as Dictionary).duplicate(true)
		var kt: float = float(kd.get("t", 0.0))
		kd["t"] = maxf(kt + dt, 0.0)
		if dv != 0.0:
			kd["v"] = offset_value(kd.get("v", 0.0), dv)
		moved.append(kd)
	for q: int in range(1, moved.size()):
		if float((moved[q] as Dictionary)["t"]) <= float((moved[q - 1] as Dictionary)["t"]):
			return []
	var out: Array = ks.duplicate()
	for j2: int in range(idxs.size() - 1, -1, -1):
		out.remove_at(idxs[j2])
	for md: Dictionary in moved:
		var clash: int = _near_index(out, float(md["t"]))
		while clash >= 0:
			out.remove_at(clash)
			clash = _near_index(out, float(md["t"]))
	for md2: Dictionary in moved:
		out.insert(_lower_index(out, float(md2["t"])), md2)
	return out


static func _in_order(list: Array) -> bool:
	for i: int in range(1, list.size()):
		if float((list[i] as Dictionary).get("t", 0.0)) < float((list[i - 1] as Dictionary).get("t", 0.0)):
			return false
	return true


static func merge_by_time(a: Array, b: Array) -> Array:
	var merged: Array = []
	if not _in_order(a) or not _in_order(b):
		merged.append_array(a)
		merged.append_array(b)
		merged.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.get("t", 0.0)) < float(y.get("t", 0.0)))
		return merged
	var i: int = 0
	var j: int = 0
	while i < a.size() or j < b.size():
		if j >= b.size() or (i < a.size() and float((a[i] as Dictionary).get("t", 0.0)) <= float((b[j] as Dictionary).get("t", 0.0))):
			merged.append(a[i])
			i += 1
		else:
			merged.append(b[j])
			j += 1
	return merged


static func scale_keys(p: Dictionary, times: PackedFloat64Array, pivot: float, factor: float) -> Dictionary:
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0:
		return p.duplicate(true)
	var out: Dictionary = p.duplicate(true)
	var ks: Array = out["layers"][li].get("keys", [])
	for k: Variant in ks:
		var kd: Dictionary = k
		var kt: float = float(kd.get("t", 0.0))
		for t: float in times:
			if absf(t - kt) <= AnimProp.KEY_TOLERANCE:
				kd["t"] = maxf(pivot + (kt - pivot) * factor, 0.0)
				break
	ks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))
	out["layers"][li]["keys"] = ks
	return out


static func scale_values(p: Dictionary, times: PackedFloat64Array, offset: float, factor: float) -> Dictionary:
	var li: int = AnimProp.keys_layer_index(p)
	if li < 0:
		return p.duplicate(true)
	var out: Dictionary = p.duplicate(true)
	for k: Variant in out["layers"][li].get("keys", []):
		var kd: Dictionary = k
		var kt: float = float(kd.get("t", 0.0))
		for t: float in times:
			if absf(t - kt) <= AnimProp.KEY_TOLERANCE:
				var v: Variant = kd.get("v", 0.0)
				if v is Array:
					var arr: Array = []
					for e: Variant in v:
						arr.append(float(e) * factor + offset)
					kd["v"] = arr
				elif not (v is bool):
					kd["v"] = float(v) * factor + offset
				break
	return out


static func set_interp(p: Dictionary, times: PackedFloat64Array, interp: String, ease: String) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	for t: float in times:
		var fields: Dictionary = {"i": interp}
		if not ease.is_empty():
			fields["ease"] = ease
		out = AnimProp.set_key_fields(out, t, fields)
	return out


static func remove_keys(p: Dictionary, times: PackedFloat64Array) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	for t: float in times:
		out = AnimProp.remove_key(out, t)
	return out


func selected_times() -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var picked: PackedFloat64Array = sorted_times(selected)
	for k: Dictionary in keys_view():
		var kt: float = float(k.get("t", 0.0))
		if has_near(picked, kt):
			out.append(kt)
	return out


func all_times() -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	for k: Dictionary in keys_view():
		out.append(float(k.get("t", 0.0)))
	return out


func write_prop(p: Dictionary, label: String) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	var c: Clip = clip()
	if d == null or s == null or c == null:
		return false
	var cmd: Command = ClipCmds.SetClipParam.new(s.id, clip_id, path, p)
	cmd.label = label
	var ok: bool = Verbs.run(d, label, [cmd])
	if ok:
		keys_edited.emit()
	queue_redraw()
	return ok


func write_live(p: Dictionary) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var cmd: KeyDragCmds.SetKeysLive = KeyDragCmds.SetKeysLive.new(s.id, clip_id, path, p)
	if KeyDragCmds.apply_live(d, s, cmd, s.playhead, quiet_allowed(s)):
		redraw_peers()
	queue_redraw()


func quiet_allowed(s: Sequence) -> bool:
	if s == null or Session.doc != doc() or Session.seq_id != s.id:
		return false
	return Session.whole_target(s.id, s.playhead).is_empty()


func redraw_peers() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for n: Node in tree.get_nodes_in_group(PEER_GROUP):
		if n != self and n is CanvasItem and String(n.get("clip_id")) == clip_id:
			(n as CanvasItem).queue_redraw()


func add_key_at(t: float, v: Variant, snap: bool = true) -> bool:
	var c: Clip = clip()
	if c == null:
		return false
	var p: Dictionary = prop()
	var value: Variant = v
	if v == null:
		value = AnimProp.evaluate(p if not p.is_empty() else AnimProp.make(0.0), t, c.duration, fps())
	var next: Dictionary = AnimProp.set_key(p if not p.is_empty() else AnimProp.make(value), snap_t(t) if snap else t, value)
	return write_prop(next, "Add key")


func add_key_at_axis(axis_t: float, v: Variant) -> bool:
	if not played_on():
		return add_key_at(axis_t, v)
	return add_key_at(key_t_of(snap_t(axis_t)), v, false)


func add_key_at_playhead() -> bool:
	var c: Clip = clip()
	if c == null:
		return false
	var s: Sequence = seq()
	var warped: bool = c.path_warped(path)
	return add_key_at(c.param_time(path, s.playhead - c.start), null, not warped)


func delete_selected() -> bool:
	var times: PackedFloat64Array = selected_times()
	if times.is_empty():
		return false
	var ok: bool = write_prop(remove_keys(prop(), times), "Delete keys")
	selected = PackedFloat64Array()
	selection_changed.emit()
	return ok


func nudge_selected(frames: int, dv: float) -> bool:
	var times: PackedFloat64Array = selected_times()
	if times.is_empty():
		return false
	var dt: float = float(frames) / fps()
	var next: Dictionary = move_keys(prop(), times, dt, dv)
	var moved: PackedFloat64Array = PackedFloat64Array()
	for t: float in times:
		moved.append(maxf(t + dt, 0.0))
	var ok: bool = write_prop(next, "Nudge keys")
	if ok:
		selected = moved
	return ok


func apply_ease(interp: String, ease: String, all: bool) -> bool:
	var times: PackedFloat64Array = all_times() if all or selected.is_empty() else selected_times()
	if times.is_empty():
		return false
	return write_prop(set_interp(prop(), times, interp, ease), "Ease " + interp)


func adjust(offset_t: float, scale_t: float, offset_v: float, scale_v: float, all: bool) -> bool:
	var times: PackedFloat64Array = all_times() if all or selected.is_empty() else selected_times()
	if times.is_empty():
		return false
	var p: Dictionary = prop()
	var pivot: float = INF
	for t: float in times:
		pivot = minf(pivot, t)
	if scale_t != 1.0:
		p = scale_keys(p, times, pivot, scale_t)
		var scaled: PackedFloat64Array = PackedFloat64Array()
		for t: float in times:
			scaled.append(maxf(pivot + (t - pivot) * scale_t, 0.0))
		times = scaled
	if offset_t != 0.0:
		p = move_keys(p, times, offset_t, 0.0)
		var moved: PackedFloat64Array = PackedFloat64Array()
		for t: float in times:
			moved.append(maxf(t + offset_t, 0.0))
		times = moved
	if offset_v != 0.0 or scale_v != 1.0:
		p = scale_values(p, times, offset_v, scale_v)
	var ok: bool = write_prop(p, "Adjust keys")
	if ok:
		selected = times
	return ok


func copy_selected() -> Array:
	var times: PackedFloat64Array = selected_times()
	if times.is_empty():
		times = all_times()
	var out: Array = []
	var base: float = INF
	for t: float in times:
		base = minf(base, t)
	for k: Dictionary in keys():
		var kt: float = float(k.get("t", 0.0))
		for t: float in times:
			if absf(t - kt) <= AnimProp.KEY_TOLERANCE:
				var kd: Dictionary = k.duplicate(true)
				kd["t"] = kt - base
				out.append(kd)
				break
	_remember_speed(out)
	return out


static var copied_speed: Dictionary = {}
static var _copied_list: Array = []


func _remember_speed(list: Array) -> void:
	var c: Clip = clip()
	copied_speed = c.speed_entry(path).duplicate(true) if c != null and AnimTime.speed_able(path) else {}
	_copied_list = list


func paste_at_with_speed(at: float) -> float:
	var c: Clip = clip()
	if c == null or copied_speed.is_empty():
		return at
	var local_u: float = at
	var found: bool = false
	for u: float in c.played_times_for(path, at):
		if not found or (u >= 0.0 and u <= c.duration):
			local_u = u
			found = true
			if u >= 0.0 and u <= c.duration:
				break
	var tmp: Clip = c.copy()
	tmp.put_speed(path, AnimTime.entry_speed(copied_speed), AnimTime.entry_start(copied_speed))
	return tmp.param_time(path, local_u)


func speed_cmds_for_paste(list: Array) -> Array[Command]:
	var out: Array[Command] = []
	var s: Sequence = seq()
	if s == null or copied_speed.is_empty() or not is_same(list, _copied_list) or not AnimTime.speed_able(path):
		return out
	out.append(ClipCmds.SetClipParam.new(s.id, clip_id, AnimTime.speed_path(path), AnimTime.entry_speed(copied_speed)))
	out.append(ClipCmds.SetClipParam.new(s.id, clip_id, AnimTime.start_path(path), AnimProp.make(AnimTime.entry_start(copied_speed))))
	return out


func paste_keys(list: Array, at: float) -> bool:
	if list.is_empty():
		return false
	var p: Dictionary = prop()
	var c: Clip = clip()
	if c == null:
		return false
	if p.is_empty():
		p = AnimProp.make(comp0((list[0] as Dictionary).get("v", 0.0)))
	var extra: Array[Command] = speed_cmds_for_paste(list)
	var base_t: float = paste_at_with_speed(at) if not extra.is_empty() else at
	var snap: bool = extra.is_empty() and not c.path_warped(path)
	for k: Variant in list:
		var kd: Dictionary = k
		var t: float = snap_t(base_t + float(kd.get("t", 0.0))) if snap else base_t + float(kd.get("t", 0.0))
		p = AnimProp.set_key(p, t, kd.get("v", 0.0), String(kd.get("i", "ease_both")))
		var fields: Dictionary = {}
		for f: String in ["ease", "dir", "ho", "hi"]:
			if kd.has(f):
				fields[f] = kd[f]
		if not fields.is_empty():
			p = AnimProp.set_key_fields(p, t, fields)
	if extra.is_empty():
		return write_prop(p, "Paste keys")
	return write_prop_with(p, "Paste keys", extra)


func write_prop_with(p: Dictionary, label: String, extra: Array[Command]) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or clip() == null:
		return false
	var cmds: Array[Command] = [ClipCmds.SetClipParam.new(s.id, clip_id, path, p)]
	cmds.append_array(extra)
	var ok: bool = Verbs.run(d, label, cmds)
	if ok:
		keys_edited.emit()
	queue_redraw()
	return ok


func open_adjust_sheet() -> void:
	var fields: Array[Dictionary] = []
	fields.append({"key": "offset_t", "label": "Offset time (seconds)", "type": "float", "default": 0.0})
	fields.append({"key": "scale_t", "label": "Scale time", "type": "float", "default": 1.0})
	fields.append({"key": "offset_v", "label": "Offset value", "type": "float", "default": 0.0})
	fields.append({"key": "scale_v", "label": "Scale value", "type": "float", "default": 1.0})
	fields.append({"key": "all", "label": "Apply to every key", "type": "bool", "default": selected.is_empty()})
	var answered: Signal = PmUI.form(self, "Adjust keys", fields, "Apply", "Cancel")
	answered.connect(_on_adjust_answered)


func _on_adjust_answered(result: Variant) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var r: Dictionary = result
	adjust(float(r.get("offset_t", 0.0)), float(r.get("scale_t", 1.0)), float(r.get("offset_v", 0.0)), float(r.get("scale_v", 1.0)), bool(r.get("all", false)))


func ease_menu_items() -> Array:
	var items: Array = []
	for pair: Array in INTERPS:
		items.append(PmMenu.item("interp:" + String(pair[0]), String(pair[1])))
	var fam: Array = []
	for f: String in AnimProp.EASE_FAMILIES:
		fam.append(PmMenu.item("ease:" + f, f.capitalize()))
	items.append(PmMenu.sub_item("family", "Ease family", fam))
	items.append(PmMenu.item("same_as_previous", "Same type as the previous key"))
	return items


func same_as_previous() -> bool:
	var ks: Array[Dictionary] = keys()
	var times: PackedFloat64Array = selected_times()
	if times.is_empty() or ks.size() < 2:
		return false
	var p: Dictionary = prop()
	for t: float in times:
		var prev: Dictionary = {}
		for k: Dictionary in ks:
			var kt: float = float(k.get("t", 0.0))
			if kt < t - AnimProp.KEY_TOLERANCE:
				prev = k
			else:
				break
		if prev.is_empty():
			continue
		var fields: Dictionary = {"i": String(prev.get("i", "linear"))}
		if prev.has("ease"):
			fields["ease"] = prev["ease"]
		p = AnimProp.set_key_fields(p, t, fields)
	return write_prop(p, "Key type from previous")


func context_items() -> Array:
	var items: Array = ease_menu_items()
	items.append(PmMenu.separator())
	items.append(PmMenu.item("add_key", "Add key here"))
	items.append(PmMenu.item("set_default", "Set this value as the default"))
	items.append(PmMenu.item("reset", "Reset curve"))
	items.append(PmMenu.item("copy", "Copy keys", "Ctrl+C"))
	items.append(PmMenu.item("paste", "Paste keys", "Ctrl+V"))
	items.append(PmMenu.item("adjust", "Adjust"))
	items.append(PmMenu.item("delete", "Delete keys", "Delete", "trash"))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("select_all", "Select every key", "Ctrl+A"))
	items.append(PmMenu.item("frame", "Fit the keys in view", "F", "maximize"))
	items.append(PmMenu.item("fit_clip", "Show the whole clip"))
	return items


func handle_menu(id: String, at_t: float, at_v: float) -> void:
	if id.begins_with("interp:"):
		apply_ease(id.substr(7), "", false)
	elif id.begins_with("ease:"):
		apply_ease("ease_both", id.substr(5), false)
	elif id == "same_as_previous":
		same_as_previous()
	elif id == "add_key":
		add_key_at_axis(at_t, at_v)
	elif id == "set_default":
		var c: Clip = clip()
		if c != null:
			var v: Variant = AnimProp.evaluate(prop(), key_t_of(at_t), c.duration, fps())
			var p: Dictionary = prop().duplicate(true)
			if AnimProp.is_animated(p):
				p["base"] = AnimProp.norm(v)
				write_prop(p, "Set default")
	elif id == "reset":
		var c2: Clip = clip()
		if c2 != null:
			write_prop(AnimProp.make(AnimProp.static_value(prop())), "Reset curve")
			selected = PackedFloat64Array()
	elif id == "copy":
		_bus().key_clipboard = copy_selected()
	elif id == "paste":
		paste_keys(_bus().key_clipboard, key_t_of(at_t))
	elif id == "adjust":
		open_adjust_sheet()
	elif id == "delete":
		delete_selected()
	elif id == "select_all":
		select_keys(all_times(), false)
	elif id == "frame":
		frame_keys()
	elif id == "fit_clip":
		fit()


func _bus() -> RefCounted:
	var script: GDScript = load("res://modules/core_panels/panel_bus.gd")
	return script.call("instance")


func _on_exit() -> void:
	_refused = false
	_hover_key = -INF
	_hover_line = Vector2(INF, INF)
	_hover_zone = ""
	queue_redraw()


func _mods(e: InputEventWithModifiers) -> Dictionary:
	return {"ctrl": e.ctrl_pressed or e.meta_pressed, "shift": e.shift_pressed, "alt": e.alt_pressed}


static func wheel_natural() -> bool:
	ensure_prefs()
	return bool(Prefs.get_value(PREF_WHEEL_NATURAL))


static func is_wheel(mb: InputEventMouseButton) -> bool:
	return mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT


func handle_wheel(mb: InputEventMouseButton) -> bool:
	var tilt: bool = mb.button_index == MOUSE_BUTTON_WHEEL_LEFT or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT
	var notches: float = mb.factor if mb.factor > 0.0 else 1.0
	var steps: float = (-1.0 if (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT) else 1.0) * notches
	var zoom: bool = mb.ctrl_pressed or mb.meta_pressed or mb.alt_pressed
	if not zoom and not mb.shift_pressed and not tilt and mini:
		return false
	if _fit_pending:
		fit()
	var pan_sign: float = -1.0 if wheel_natural() else 1.0
	if zoom and not tilt:
		var factor: float = pow(WHEEL_ZOOM, steps)
		if mb.shift_pressed:
			zoom_values(factor, v_of(mb.position.y))
		else:
			zoom_time(factor, t_of(mb.position.x))
	elif mb.shift_pressed and not tilt:
		pan_values((v1 - v0) * WHEEL_PAN * -steps * pan_sign)
	else:
		pan_time((t1 - t0) * WHEEL_PAN * steps * pan_sign)
	return true


func _rel(mm: InputEventMouseMotion) -> Vector2:
	var r: Vector2 = mm.relative
	if r == Vector2.ZERO:
		r = mm.position - _last_pos
	_last_pos = mm.position
	return r


func _on_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if handle_key(event as InputEventKey):
			accept_event()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if is_wheel(mb):
			if mb.pressed and handle_wheel(mb):
				accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			_last_pos = mb.position
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if not _drag.is_empty():
				cancel_drag()
				accept_event()
				return
			var kt: float = key_at_pos(mb.position)
			if kt > -INF and not _has_selected(kt):
				select_keys(PackedFloat64Array([kt]), false)
			var m: Control = PmMenu.open(self, context_items(), get_global_mouse_position())
			if m != null and m.is_inside_tree():
				m.connect("picked", handle_menu.bind(snap_t(t_of(mb.position.x)), v_of(mb.position.y)))
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_left(mb)
		else:
			_release(mb.position, _mods(mb))
		accept_event()
		return
	if event is InputEventMouseMotion:
		_on_motion(event as InputEventMouseMotion)


func _press_left(mb: InputEventMouseButton) -> void:
	grab_focus()
	if _fit_pending and clip() != null:
		fit()
	_press = mb.position
	_last_pos = mb.position
	_hover_pos = mb.position
	_refused = false
	_time_locked = false
	_acc = Vector2.ZERO
	_acc_t = 0.0
	_acc_v = 0.0
	_press_t = t_of(mb.position.x)
	_press_v = v_of(mb.position.y)
	_drag_active = false
	_moving_value = false
	_moving_time = false
	_last_mods = _mods(mb)
	var mods: Dictionary = _last_mods
	var zone: String = zone_at(mb.position)
	_drag = ""
	if zone == "grip":
		_drag = "grip"
		_grip_h0 = maxf(custom_minimum_size.y, size.y)
		_drag_active = true
		return
	if zone == "corner":
		frame_keys()
		return
	if zone == "gutter":
		if mb.double_click:
			fit_values()
			return
		_drag = "vpan" if bool(mods["shift"]) else "vzoom"
		_vzoom_anchor = _press_v
		_drag_active = true
		return
	if zone == "ruler":
		_drag = "scrub"
		return
	var kt: float = key_at_pos(mb.position)
	if mb.double_click:
		if kt > -INF:
			_cycle_ease(kt)
		elif handle_at_pos(mb.position).is_empty():
			add_key_at_axis(_press_t, _press_v if mode == "value" else null)
		return
	var hd: Dictionary = handle_at_pos(mb.position)
	if not hd.is_empty():
		_begin_handle_drag(hd)
		return
	if kt > -INF:
		if bool(mods["ctrl"]):
			toggle_key(kt)
		elif bool(mods["shift"]) and _anchor_t >= 0.0 and not shift_is_value:
			select_range(_anchor_t, kt)
		else:
			if not _has_selected(kt):
				select_keys(PackedFloat64Array([kt]), bool(mods["shift"]) and not shift_is_value)
			_anchor_t = kt
			_drag_key_t = kt
			_drag_axis_t = _hit_axis
			_drag = "scale" if bool(mods["alt"]) and not played_on() else "move"
			_time_locked = played_on() and not clip().path_monotonic(path)
			_origin_prop = prop().duplicate(true)
			_origin_sel = selected_times()
			_origin_value_span()
		return
	if bool(mods["alt"]):
		_drag = "scrub"
		return
	_drag = "box"
	_box_mode = box_mode_for(bool(mods["shift"]), bool(mods["ctrl"]))
	_box_base = selected.duplicate()
	_box = Rect2(mb.position, Vector2.ZERO)


func _origin_value_span() -> void:
	_origin_lo_v = INF
	_origin_hi_v = -INF
	for k: Dictionary in AnimProp.keys(_origin_prop):
		if _in_times(_origin_sel, float(k.get("t", 0.0))):
			var kv: float = comp0(k.get("v", 0.0))
			_origin_lo_v = minf(_origin_lo_v, kv)
			_origin_hi_v = maxf(_origin_hi_v, kv)
	if _origin_lo_v == INF:
		_origin_lo_v = 0.0
		_origin_hi_v = 0.0


func _begin_handle_drag(hd: Dictionary) -> void:
	_drag = "handle"
	_drag_key_t = float(hd["t"])
	_handle_side = String(hd["side"])
	_handle_seg = float(hd["seg"])
	_handle_origin = hd["h"]
	_handle_key_v = float(hd["v"])
	_handle_reach = maxf(v1 - v0, VALUE_SPAN_MIN) * HANDLE_REACH
	_origin_prop = prop().duplicate(true)
	_origin_sel = selected_times()
	_origin_lo_v = _handle_key_v + _handle_origin.y
	_origin_hi_v = _origin_lo_v


func _on_motion(mm: InputEventMouseMotion) -> void:
	_hover_pos = mm.position
	var rel: Vector2 = _rel(mm)
	if _panning:
		var r0: Rect2 = plot_rect()
		pan_time(-rel.x / maxf(r0.size.x, 1.0) * (t1 - t0))
		pan_values(rel.y / maxf(r0.size.y, 1.0) * (v1 - v0))
		accept_event()
		return
	if _drag.is_empty():
		_hover(mm.position)
		return
	_acc += rel
	_last_mods = _mods(mm)
	if _drag == "grip":
		set_mini_height(_grip_h0 + _acc.y)
		accept_event()
		return
	if _drag == "vzoom":
		zoom_values(exp(rel.y * VZOOM_PER_PX), _vzoom_anchor)
		accept_event()
		return
	if _drag == "vpan":
		pan_values(rel.y / maxf(plot_rect().size.y, 1.0) * (v1 - v0))
		accept_event()
		return
	_accumulate(rel, _last_mods)
	if not _drag_active:
		var slop: float = KEY_SLOP if (_drag == "move" or _drag == "scale" or _drag == "handle") else SLOP
		if absf(_acc.x) < slop and absf(_acc.y) < slop:
			return
		_drag_active = true
		if _drag == "scrub":
			_scrubbing = true
		if _drag == "move" or _drag == "handle" or _drag == "scale":
			set_process(true)
	if _drag == "scrub":
		_scrub_to(mm.position.x)
		accept_event()
		return
	if _drag == "box":
		_box = Rect2(_press, Vector2.ZERO).expand(mm.position).abs()
		queue_redraw()
		accept_event()
		return
	_apply_drag()
	accept_event()


func _accumulate(rel: Vector2, mods: Dictionary) -> void:
	var r: Rect2 = plot_rect()
	var dt_i: float = rel.x / maxf(r.size.x, 1.0) * (t1 - t0)
	var dv_i: float = -rel.y / maxf(r.size.y, 1.0) * (v1 - v0)
	if _drag == "handle":
		_moving_time = true
		_moving_value = true
		_acc_t += dt_i
		_acc_v += dv_i
		return
	if _drag == "scale":
		_moving_time = true
		_moving_value = false
		_acc_t += dt_i
		return
	if _drag != "move":
		return
	var allow_t: bool = true
	var allow_v: bool = false
	var shift: bool = bool(mods.get("shift", false))
	if mode != "value":
		allow_v = false
	elif shift_is_value:
		allow_v = shift
	else:
		allow_v = true
		if shift:
			if absf(rel.x) >= absf(rel.y):
				allow_v = false
			else:
				allow_t = false
	_moving_time = allow_t
	_moving_value = allow_v
	if allow_t:
		_acc_t += dt_i
	if allow_v:
		_acc_v += dv_i


func value_cap() -> Vector2:
	var rng: Vector2 = declared_range(clip(), path)
	if rng.x > -INF and rng.y < INF and rng.y > rng.x:
		var reach: float = (rng.y - rng.x) * OVER_REACH
		return Vector2(rng.x - reach, rng.y + reach)
	return Vector2(-VALUE_SPAN_MAX, VALUE_SPAN_MAX)


func _capped_dv(dv: float) -> float:
	var cap: Vector2 = value_cap()
	var out: float = dv
	out = minf(out, maxf(cap.y - _origin_hi_v, 0.0))
	out = maxf(out, minf(cap.x - _origin_lo_v, 0.0))
	return out


func _apply_drag() -> void:
	if _drag == "handle":
		_apply_handle()
		return
	if _origin_sel.is_empty():
		return
	if _drag == "scale":
		_apply_scale()
		return
	if _drag != "move":
		return
	if _time_locked and _moving_time and _acc_t != 0.0 and not _refused:
		_refused = true
		queue_redraw()
	var dtt: float = _drag_dt()
	var lo_t: float = INF
	for t: float in _origin_sel:
		lo_t = minf(lo_t, t)
	dtt = maxf(dtt, -lo_t)
	var dv: float = _capped_dv(_acc_v)
	_acc_v = dv
	write_live(move_keys(_origin_prop, _origin_sel, dtt, dv))
	var sel2: PackedFloat64Array = PackedFloat64Array()
	for t: float in _origin_sel:
		sel2.append(maxf(t + dtt, 0.0))
	selected = sel2
	if dv != 0.0 or _moving_value:
		keep_values_in_view(_origin_lo_v + dv, _origin_hi_v + dv)
	keep_time_in_view(_dragged_axis(dtt))


func _drag_dt() -> float:
	if not played_on():
		return snap_t(_drag_key_t + _acc_t) - _drag_key_t
	if _time_locked or _acc_t == 0.0:
		return 0.0
	return clip().param_time(path, snap_t(_drag_axis_t + _acc_t)) - _drag_key_t


func _dragged_axis(dtt: float) -> float:
	if not played_on():
		return _drag_key_t + dtt
	if _time_locked:
		return _drag_axis_t
	return snap_t(_drag_axis_t + _acc_t)


func _apply_scale() -> void:
	var lo: float = INF
	var hi: float = -INF
	for t: float in _origin_sel:
		lo = minf(lo, t)
		hi = maxf(hi, t)
	if hi - lo < 0.0001:
		return
	var grabbed_end: bool = absf(_drag_key_t - hi) < absf(_drag_key_t - lo)
	var pivot: float = lo if grabbed_end else hi
	var moving: float = hi if grabbed_end else lo
	var want: float = snap_t(moving + _acc_t)
	var factor: float = (want - pivot) / (moving - pivot)
	if factor <= 0.01:
		factor = 0.01
	write_live(scale_keys(_origin_prop, _origin_sel, pivot, factor))
	var next_sel: PackedFloat64Array = PackedFloat64Array()
	for t: float in _origin_sel:
		next_sel.append(maxf(pivot + (t - pivot) * factor, 0.0))
	selected = next_sel


func _apply_handle() -> void:
	var hx: float = _handle_origin.x + _acc_t
	if _handle_side == "ho":
		hx = clampf(hx, 0.0, _handle_seg)
	else:
		hx = clampf(hx, -_handle_seg, 0.0)
	var hy: float = clampf(_handle_origin.y + _acc_v, -_handle_reach, _handle_reach)
	_acc_t = hx - _handle_origin.x
	_acc_v = hy - _handle_origin.y
	var hv: Variant = hy
	for k: Dictionary in AnimProp.keys(_origin_prop):
		if absf(float(k.get("t", 0.0)) - _drag_key_t) > AnimProp.KEY_TOLERANCE:
			continue
		var kv: Variant = k.get("v", 0.0)
		if kv is Array:
			var old: Variant = 0.0
			var side_v: Variant = k.get(_handle_side, null)
			if side_v is Array and (side_v as Array).size() >= 2:
				old = (side_v as Array)[1]
			var arr: Array = []
			for ci: int in (kv as Array).size():
				if ci == 0:
					arr.append(hy)
				elif old is Array:
					arr.append(comp(old, ci))
				else:
					arr.append(0.0)
			hv = arr
	write_live(AnimProp.set_key_fields(_origin_prop, _drag_key_t, {_handle_side: [hx, hv]}))
	keep_values_in_view(_handle_key_v + hy, _handle_key_v + hy)


func keep_values_in_view(lo: float, hi: float) -> void:
	var r: Rect2 = plot_rect()
	var span: float = v1 - v0
	if span <= 0.0 or r.size.y < 4.0:
		return
	var edge: float = minf(_px(EDGE_PX), r.size.y * 0.2)
	var f_hi: float = (r.size.y - edge) / r.size.y
	var f_lo: float = edge / r.size.y
	if (hi - v0) / span > f_hi:
		v1 = v0 + (hi - v0) / f_hi
		span = v1 - v0
	if (lo - v0) / span < f_lo:
		v0 = v1 - (v1 - lo) / (1.0 - f_lo)
	queue_redraw()


func keep_time_in_view(t: float) -> void:
	var r: Rect2 = plot_rect()
	var span: float = t1 - t0
	if span <= 0.0 or r.size.x < 8.0:
		return
	var edge: float = minf(_px(EDGE_PX), r.size.x * 0.1) / r.size.x * span
	if t > t1 - edge:
		pan_time(t - (t1 - edge))
	elif t < t0 + edge and t0 > -span * 0.5 + 0.0000001:
		pan_time(t - (t0 + edge))


func edge_tick(dt: float) -> bool:
	if not _drag_active or not (_drag == "move" or _drag == "handle"):
		return false
	var r: Rect2 = plot_rect()
	var over_y: float = 0.0
	if _hover_pos.y < r.position.y:
		over_y = r.position.y - _hover_pos.y
	elif _hover_pos.y > r.end.y:
		over_y = r.end.y - _hover_pos.y
	var over_x: float = 0.0
	if _hover_pos.x > r.end.x:
		over_x = _hover_pos.x - r.end.x
	elif _hover_pos.x < r.position.x:
		over_x = _hover_pos.x - r.position.x
	var moved: bool = false
	if over_y != 0.0 and _moving_value:
		var px_y: float = signf(over_y) * minf(absf(over_y), _px(EDGE_MAX_PX)) * EDGE_SPEED * dt
		_acc_v += px_y / maxf(r.size.y, 1.0) * (v1 - v0)
		moved = true
	if over_x != 0.0 and _moving_time and _drag == "move":
		var px_x: float = signf(over_x) * minf(absf(over_x), _px(EDGE_MAX_PX)) * EDGE_SPEED * dt
		_acc_t += px_x / maxf(r.size.x, 1.0) * (t1 - t0)
		moved = true
	if moved:
		_apply_drag()
	return moved


func ease_playhead_to(target: float) -> void:
	var s2: Sequence = seq()
	if s2 == null:
		return
	if PlayheadGlide.keyframes_on() and _glide.start(s2.playhead, target):
		set_process(true)
		return
	_glide.stop()
	Session.jump_to(target)
	Session.scrub_done()


func _process(dt: float) -> void:
	var busy: bool = false
	if _glide.active():
		Session.scrub_to(_glide.step(dt))
		if not _glide.active():
			Session.scrub_done()
		else:
			busy = true
	if _drag_active and (_drag == "move" or _drag == "handle" or _drag == "scale"):
		busy = true
		edge_tick(dt)
	if not busy:
		set_process(false)


func _scrub_to(x: float) -> void:
	var c: Clip = clip()
	if c == null or doc_override != null:
		return
	var t: float = clampf(local_of_axis(snap_t(t_of(x))), 0.0, c.duration)
	Session.scrub_to(c.start + t)
	queue_redraw()


func fmt_value(v: float) -> String:
	var shown: float = v * display_mul
	var text: String
	if absf(shown) >= 100.0:
		text = String.num(shown, 0)
	else:
		text = String.num(shown, 2).trim_suffix("0").trim_suffix("0").trim_suffix(".")
	if text == "-0":
		text = "0"
	return text + suffix


func fmt_axis(v: float, vstep: float) -> String:
	var shown_step: float = absf(vstep * display_mul)
	var d: int = 0
	if shown_step > 0.0 and shown_step < 1.0:
		d = clampi(int(ceil(-log(shown_step) / log(10.0) - 0.0001)), 0, 5)
	var shown: float = v * display_mul
	var text: String = String.num(shown, d)
	if absf(shown) >= 1000000.0:
		text = String.num(shown / 1000000.0, 1) + "M"
	elif absf(shown) >= 100000.0:
		text = String.num(shown / 1000.0, 0) + "k"
	if text.begins_with("-") and float(text.trim_suffix("k").trim_suffix("M")) == 0.0:
		text = text.substr(1)
	return text


func _cycle_ease(kt: float) -> void:
	var cur: String = "linear"
	for k: Dictionary in keys():
		if absf(float(k.get("t", 0.0)) - kt) <= AnimProp.KEY_TOLERANCE:
			cur = String(k.get("i", "linear"))
	var order: PackedStringArray = PackedStringArray(["linear", "ease_both", "ease_in", "ease_out", "hold", "auto"])
	var i: int = order.find(cur)
	var next: String = order[(i + 1) % order.size()] if i >= 0 else "ease_both"
	write_prop(set_interp(prop(), PackedFloat64Array([kt]), next, ""), "Ease " + next)


func _hover(pos: Vector2) -> void:
	var zone: String = zone_at(pos)
	if zone != _hover_zone:
		_hover_zone = zone
		if zone == "grip" or zone == "gutter":
			mouse_default_cursor_shape = Control.CURSOR_VSIZE
		elif zone == "corner":
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		queue_redraw()
	var kt: float = key_at_pos(pos) if zone == "plot" else -INF
	var line: Vector2 = Vector2(INF, INF)
	var c: Clip = clip()
	if kt == -INF and zone == "plot" and mode == "value" and c != null and handle_at_pos(pos).is_empty():
		var t: float = t_of(pos.x)
		var v: float = comp0(eval_axis(prop(), t, c.duration, fps()))
		if absf(y_of(v) - pos.y) <= HIT_R:
			line = Vector2(t, v)
	if kt > -INF:
		_hover_axis = _hit_axis
	if kt != _hover_key or line != _hover_line:
		_hover_key = kt
		_hover_line = line
		queue_redraw()
	elif kt > -INF:
		queue_redraw()


func _release(_pos: Vector2, mods: Dictionary) -> void:
	var d: Project = doc()
	var was: String = _drag
	var active: bool = _drag_active
	_drag = ""
	_drag_active = false
	_scrubbing = false
	_moving_value = false
	_moving_time = false
	if was == "grip":
		store_mini_height()
		return
	if was == "vzoom" or was == "vpan":
		return
	if was == "scrub":
		if not active:
			var c0: Clip = clip()
			if c0 != null:
				ease_playhead_to(c0.start + clampf(local_of_axis(snap_t(_press_t)), 0.0, c0.duration))
		return
	if was == "box":
		var box: Rect2 = _box
		var base: PackedFloat64Array = _box_base
		var box_mode: String = _box_mode
		if box_mode == BOX_REPLACE:
			box_mode = box_mode_for(bool(mods.get("shift", false)), bool(mods.get("ctrl", false)))
		_box = Rect2()
		_box_base = PackedFloat64Array()
		_box_mode = BOX_REPLACE
		if active:
			selected = merge_selection(base, box_hits(box), box_mode)
			selection_changed.emit()
		elif box_mode == BOX_REPLACE:
			select_keys(PackedFloat64Array(), false)
			var c1: Clip = clip()
			if c1 != null:
				ease_playhead_to(c1.start + clampf(local_of_axis(snap_t(_press_t)), 0.0, c1.duration))
		queue_redraw()
		return
	if (was == "move" or was == "scale" or was == "handle") and active and d != null:
		var final: Dictionary = prop().duplicate(true)
		d.undo.cancel_live()
		if final != _origin_prop:
			var label: String = "Move keys"
			if was == "scale":
				label = "Scale keys"
			elif was == "handle":
				label = "Adjust curve"
			write_prop(final, label)
	_origin_prop = {}
	_origin_sel = PackedFloat64Array()
	queue_redraw()


func cancel_drag() -> bool:
	if _drag.is_empty():
		return false
	var d: Project = doc()
	if d != null and _drag_active and (_drag == "move" or _drag == "scale" or _drag == "handle"):
		d.undo.cancel_live()
		selected = _origin_sel.duplicate()
	if _drag == "grip":
		custom_minimum_size.y = _grip_h0
	_drag = ""
	_drag_active = false
	_scrubbing = false
	_moving_value = false
	_moving_time = false
	_box = Rect2()
	_box_base = PackedFloat64Array()
	_box_mode = BOX_REPLACE
	_origin_prop = {}
	_origin_sel = PackedFloat64Array()
	queue_redraw()
	return true


func handle_key(e: InputEventKey) -> bool:
	if not e.pressed:
		return false
	if e.keycode == KEY_ESCAPE:
		return cancel_drag()
	var ctrl: bool = e.ctrl_pressed or e.meta_pressed
	if e.keycode == KEY_F and not ctrl and not e.alt_pressed and not e.shift_pressed:
		frame_keys()
		return true
	if e.keycode == KEY_DELETE or e.keycode == KEY_BACKSPACE:
		return delete_selected()
	if e.keycode == KEY_LEFT or e.keycode == KEY_RIGHT:
		if selected.is_empty():
			return false
		var n: int = (5 if e.shift_pressed else 1) * (1 if e.keycode == KEY_RIGHT else -1)
		return nudge_selected(n, 0.0)
	if e.keycode == KEY_UP or e.keycode == KEY_DOWN:
		if selected.is_empty():
			return false
		var dv: float = (v1 - v0) * (0.05 if e.shift_pressed else 0.01) * (1.0 if e.keycode == KEY_UP else -1.0)
		return nudge_selected(0, dv)
	if ctrl and e.keycode == KEY_C:
		_bus().key_clipboard = copy_selected()
		return true
	if ctrl and e.keycode == KEY_V:
		var c: Clip = clip()
		if c == null:
			return false
		return paste_keys(_bus().key_clipboard, playhead_key_time())
	if ctrl and e.keycode == KEY_A:
		select_keys(all_times(), false)
		return true
	return false


func mini_height_key() -> String:
	var parts: PackedStringArray = path.split(".")
	if parts.size() == 3 and parts[0] == "effects":
		var c: Clip = clip()
		if c != null:
			var eid: String = String(c.effect_by_uid(parts[1]).get("id", ""))
			if not eid.is_empty():
				return "effects." + eid + "." + parts[2]
	return path


static func mini_heights() -> Dictionary:
	ensure_prefs()
	var v: Variant = Prefs.get_value(PREF_MINI_HEIGHTS)
	return v if v is Dictionary else {}


func _unit() -> float:
	return maxf(float(Tk.px(1000.0)) / 1000.0, 0.01)


func restore_mini_height() -> void:
	if not mini:
		return
	var want: float = float(mini_heights().get(mini_height_key(), MINI_DEFAULT_H))
	custom_minimum_size = Vector2(0.0, clampf(want, MINI_MIN_H, MINI_MAX_H) * _unit())


func set_mini_height(h: float) -> void:
	var next: float = clampf(h, MINI_MIN_H * _unit(), MINI_MAX_H * _unit())
	if absf(next - custom_minimum_size.y) < 0.01:
		return
	custom_minimum_size = Vector2(custom_minimum_size.x, next)
	height_changed.emit(next)
	queue_redraw()


func store_mini_height() -> void:
	if not mini or path.is_empty():
		return
	var all: Dictionary = mini_heights().duplicate()
	all[mini_height_key()] = snappedf(custom_minimum_size.y / _unit(), 1.0)
	Prefs.set_value(PREF_MINI_HEIGHTS, all)


func declared_range(c: Clip, p_path: String) -> Vector2:
	if c == null or p_path.is_empty():
		return Vector2(-INF, INF)
	var parts: PackedStringArray = p_path.split(".")
	if range_lo > -INF or range_hi < INF:
		return Vector2(range_lo, range_hi)
	if p_path == "transform.opacity":
		return Vector2(0.0, 1.0)
	if p_path == "audio.pan":
		return Vector2(-1.0, 1.0)
	if p_path == "motion_blur.shutter_angle":
		return Vector2(0.0, 720.0)
	if p_path == "motion_blur.shutter_phase":
		return Vector2(-360.0, 360.0)
	if p_path == "motion_blur.samples":
		return Vector2(1.0, 64.0)
	if p_path == "audio.volume":
		return Vector2(0.0, 4.0)
	if p_path == "speed":
		return Vector2(-8.0, 8.0)
	if p_path == "transform.scale":
		return Vector2(0.0, INF)
	if parts.size() == 3 and parts[0] == "effects":
		var e: Dictionary = c.effect_by_uid(parts[1])
		var spec: Dictionary = EffectRegistry.shared().call("param_spec", String(e.get("id", "")), parts[2])
		if spec.is_empty():
			return Vector2(-INF, INF)
		return Vector2(float(spec.get("min", -INF)), float(spec.get("max", INF)))
	return Vector2(-INF, INF)


func value_span(p: Dictionary) -> Vector2:
	var h: int = p.hash()
	if h == _span_hash and not _span_hash_empty:
		return _span_value
	var out: Vector2 = _value_span_of(p)
	_span_hash = h
	_span_hash_empty = false
	_span_value = out
	return out


func _value_span_of(p: Dictionary) -> Vector2:
	var lo: float = INF
	var hi: float = -INF
	for k: Dictionary in (keys_view() if is_same(p, prop()) else AnimProp.keys(p)):
		var v: Variant = k.get("v", 0.0)
		for ci: int in component_count(v):
			var f: float = comp(v, ci)
			lo = minf(lo, f)
			hi = maxf(hi, f)
	if lo == INF:
		return Vector2(0.0, 1.0)
	return Vector2(lo, hi)


func _overshoot_between(p: Dictionary, ta: float, tb: float, a: float, b: float, dur: float, f: float) -> bool:
	if tb - ta <= 0.0001:
		return false
	var lo: float = minf(a, b)
	var hi: float = maxf(a, b)
	var tol: float = maxf(absf(hi - lo), 1.0) * 0.005
	for i: int in range(1, 10):
		var t: float = ta + (tb - ta) * float(i) / 10.0
		var v: float = comp0(AnimProp.evaluate(p, t, dur, f))
		if v > hi + tol or v < lo - tol:
			return true
	return false


func key_overshoots(ks: Array[Dictionary], i: int, p: Dictionary, dur: float, f: float) -> bool:
	if i < 0 or i >= ks.size():
		return false
	var kt: float = float(ks[i].get("t", 0.0))
	var kv: float = comp0(ks[i].get("v", 0.0))
	if i + 1 < ks.size():
		if _overshoot_between(p, kt, float(ks[i + 1].get("t", 0.0)), kv, comp0(ks[i + 1].get("v", 0.0)), dur, f):
			return true
	if i > 0:
		if _overshoot_between(p, float(ks[i - 1].get("t", 0.0)), kt, comp0(ks[i - 1].get("v", 0.0)), kv, dur, f):
			return true
	return false


func _ruler_room() -> float:
	return size.x - (_played_btn.size.x if _played_btn != null and _played_btn.visible else 0.0)


func ruler_labels() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r: Rect2 = plot_rect()
	var step: float = _nice(t1 - t0, r.size.x / (110.0 if mini else 80.0))
	var mono: Font = Tk.font("mono")
	var mfs: int = Tk.fs(Tk.sz("font_tiny"))
	var rh: float = ruler_h()
	var asc: float = mono.get_ascent(mfs)
	var desc: float = mono.get_descent(mfs)
	var base: float = floorf((rh - (asc + desc)) * 0.5 + asc)
	var right: float = _ruler_room() - PmText.pad()
	var last_end: float = -INF
	var t: float = ceil(t0 / step) * step
	var guard: int = 0
	while t <= t1 + step * 0.001 and guard < 400:
		guard += 1
		var x: float = x_of(t)
		if t >= -0.00001 and x >= r.position.x - 0.5 and x <= r.end.x + 0.5:
			var text: String = _tc_label(t) if step >= 1.0 else _secs_label(t)
			var w: float = mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs).x
			var lx: float = x + 3.0
			if lx + w > right:
				lx = minf(x - 3.0 - w, right - w)
			var shown: bool = lx >= last_end + 6.0 and lx >= gutter_w() + 2.0
			out.append({"x": x, "text": text, "rect": Rect2(lx, base - asc, w, asc + desc), "shown": shown})
			if shown:
				last_end = lx + w
		t += step
	return out


func value_labels() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if mode == "dope":
		return out
	var r: Rect2 = plot_rect()
	var mono: Font = Tk.font("mono")
	var mfs: int = Tk.fs(Tk.sz("font_tiny"))
	var asc: float = mono.get_ascent(mfs)
	var desc: float = mono.get_descent(mfs)
	var vstep: float = _nice(v1 - v0, r.size.y / (16.0 if mini else 40.0))
	var gw: float = gutter_w()
	var top_limit: float = ruler_h() + 1.0
	var bottom_limit: float = size.y - grip_h() - 1.0
	var last_y: float = INF
	var v: float = ceil(v0 / vstep) * vstep
	var guard: int = 0
	while v <= v1 + vstep * 0.001 and guard < 400:
		guard += 1
		var y: float = y_of(v)
		var text: String = fmt_axis(v, vstep)
		var w: float = mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs).x
		var by: float = floorf(y + (asc - desc) * 0.5)
		var rect: Rect2 = Rect2(maxf(gw - 5.0 - w, 1.0), by - asc, minf(w, gw - 6.0), asc + desc)
		var shown: bool = rect.position.y >= top_limit and rect.end.y <= bottom_limit and absf(last_y - y) >= asc + desc + 2.0
		out.append({"v": v, "y": y, "text": text, "rect": rect, "shown": shown})
		if shown:
			last_y = y
		v += vstep
	return out


func _draw_zones(r: Rect2, c: Clip) -> void:
	var rng: Vector2 = declared_range(c, path)
	var over: Color = Tk.c["zone_over"]
	var neg: Color = Tk.c["zone_negative"]
	if rng.y < INF:
		var top_y: float = y_of(rng.y)
		if top_y > r.position.y + 1.0:
			var h: float = minf(top_y, r.end.y) - r.position.y
			for band: int in 3:
				var a: float = 0.05 + float(band) * 0.035
				var inset: float = float(band) * 3.0
				if h - inset > 0.0:
					draw_rect(Rect2(r.position.x, r.position.y, r.size.x, h - inset), Color(over, a), true)
			draw_rect(Rect2(r.position.x, top_y, r.size.x, 1.0), Color(over, 0.45), true)
	if rng.x > -INF:
		var bot_y: float = y_of(rng.x)
		if bot_y < r.end.y - 1.0:
			var from: float = maxf(bot_y, r.position.y)
			for band: int in 3:
				var a: float = 0.05 + float(band) * 0.035
				var inset: float = float(band) * 3.0
				if r.end.y - from - inset > 0.0:
					draw_rect(Rect2(r.position.x, from + inset, r.size.x, r.end.y - from - inset), Color(over, a), true)
			draw_rect(Rect2(r.position.x, bot_y, r.size.x, 1.0), Color(over, 0.45), true)
	if v0 < 0.0 and v1 > 0.0:
		var zy: float = y_of(0.0)
		draw_rect(Rect2(r.position.x, zy, r.size.x, r.end.y - zy), Color(neg, 0.07), true)
		draw_rect(Rect2(r.position.x, zy, r.size.x, 1.0), Color(neg, 0.6), true)


func _draw() -> void:
	paint_count += 1
	var r: Rect2 = plot_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_field"], true)
	var c: Clip = clip()
	if c == null or path.is_empty() and paths.is_empty():
		PmText.draw(self, _font, Rect2(Vector2.ZERO, size), "Select a clip and a property", Tk.fs(Tk.sz("font_small")), Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, 8.0, size.y * 0.5 + 4.0)
		if mini:
			_draw_grip()
		return
	if _fit_pending:
		fit()
	if mode == "dope":
		_draw_dope(r, c)
	else:
		_draw_span_shade(r)
		_draw_curve(r, c)
		if keys_view().is_empty() and mini:
			var line_y: float = y_of(comp0(AnimProp.static_value(prop())))
			var hint_y: float = r.end.y - 3.0 if line_y < r.get_center().y else r.position.y + float(_fs) + 2.0
			PmText.draw(self, _font, r, "No keyframes yet, double click to add one, drag to scrub", _fs, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, PmText.pad(), hint_y)
	_draw_ruler(r)
	_draw_gutter()
	_draw_corner()
	var ph: float = playhead_axis()
	var px: float = x_of(ph)
	if px >= r.position.x and px <= r.end.x:
		draw_rect(Rect2(round(px), 0.0, 1.0, size.y - grip_h()), Tk.c["sol"], true)
		draw_colored_polygon(PackedVector2Array([Vector2(px - 4.0, 0.0), Vector2(px + 4.0, 0.0), Vector2(px, 6.0)]), Tk.c["sol"])
	if _drag == "box" and _drag_active:
		draw_rect(_box, Tk.c["selection_fill"], true)
		var pts := PackedVector2Array([_box.position, Vector2(_box.end.x, _box.position.y), _box.end, Vector2(_box.position.x, _box.end.y), _box.position])
		draw_polyline(pts, Tk.c["text_faint"], 1.0)
	if _drag.is_empty():
		if _hover_key > -INF:
			_draw_readout(c)
		elif _hover_line.x != INF and mode == "value":
			var lp: Vector2 = Vector2(x_of(_hover_line.x), y_of(_hover_line.y))
			draw_circle(lp, 2.5, Tk.c["text_bright"])
			_draw_bubble(lp + Vector2(0.0, 6.0), fmt_value(_hover_line.y))
	if _refused:
		_draw_note(_hover_pos, REFUSE_TEXT)
	if mini:
		_draw_grip()
	if _played_btn != null and _played_btn.visible != warp_available():
		sync_played_button.call_deferred()


func _draw_note(near: Vector2, text: String) -> void:
	var fs: int = Tk.fs(Tk.sz("font_tiny"))
	var font: Font = Tk.font("body")
	var pad: float = _px(6.0)
	var w: float = clampf(size.x - pad * 4.0, 60.0, _px(360.0))
	var text_size: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, fs)
	var rect: Rect2 = Rect2(near + Vector2(_px(14.0), _px(14.0)), Vector2(w, text_size.y + pad * 2.0))
	rect.position.x = clampf(rect.position.x, 0.0, maxf(size.x - rect.size.x, 0.0))
	rect.position.y = clampf(rect.position.y, 0.0, maxf(size.y - rect.size.y, 0.0))
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.8), true)
	draw_rect(rect, Tk.c["border_soft"], false, 1.0)
	PmText.draw_lines(self, font, rect, text, fs, Tk.c["text_bright"], -1, pad)


func _draw_ruler(r: Rect2) -> void:
	var rh: float = ruler_h()
	draw_rect(Rect2(0.0, 0.0, size.x, rh), Tk.c["bg_ruler"], true)
	draw_rect(Rect2(0.0, rh - 1.0, size.x, 1.0), Tk.c["border"], true)
	var c: Clip = clip()
	if c != null:
		var cx0: float = maxf(x_of(0.0), r.position.x)
		var cx1: float = minf(x_of(c.duration), r.end.x)
		if cx1 > cx0:
			draw_rect(Rect2(cx0, rh - 3.0, cx1 - cx0, 2.0), Color(Tk.c["text_faint"], 0.35), true)
	var mono: Font = Tk.font("mono")
	var mfs: int = Tk.fs(Tk.sz("font_tiny"))
	var asc: float = mono.get_ascent(mfs)
	for lab: Dictionary in ruler_labels():
		var x: float = round(float(lab["x"]))
		draw_rect(Rect2(x, rh - 5.0, 1.0, 4.0), Tk.c["text_faint"], true)
		if bool(lab["shown"]):
			var rect: Rect2 = lab["rect"]
			PmText.draw_in(self, mono, rect, String(lab["text"]), mfs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, rect.position.y + asc, PmText.WHOLE, Rect2(0.0, 0.0, _ruler_room(), rh))


func _draw_gutter() -> void:
	if mode == "dope":
		return
	var gw: float = gutter_w()
	var rh: float = ruler_h()
	var bottom: float = size.y - grip_h()
	var bg: Color = Tk.c["bg_ruler"]
	if _hover_zone == "gutter" or _drag == "vzoom" or _drag == "vpan":
		bg = bg.lerp(Tk.c["bg_panel_high"], 0.6)
	draw_rect(Rect2(0.0, rh, gw, bottom - rh), bg, true)
	draw_rect(Rect2(gw - 1.0, rh, 1.0, bottom - rh), Tk.c["border"], true)
	var mono: Font = Tk.font("mono")
	var mfs: int = Tk.fs(Tk.sz("font_tiny"))
	var asc: float = mono.get_ascent(mfs)
	for lab: Dictionary in value_labels():
		var y: float = round(float(lab["y"]))
		if y < rh or y > bottom:
			continue
		draw_rect(Rect2(gw - 4.0, y, 3.0, 1.0), Tk.c["text_faint"], true)
		if bool(lab["shown"]):
			var rect: Rect2 = lab["rect"]
			var inset: float = maxf(PmText.chip_pad(), 5.0)
			PmText.draw_in(self, mono, Rect2(inset, rect.position.y, gw - inset * 2.0, rect.size.y), String(lab["text"]), mfs, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_RIGHT, rect.position.y + asc, PmText.WHOLE, Rect2(0.0, rect.position.y, gw, rect.size.y), PmText.chip_pad())


func _draw_corner() -> void:
	var gw: float = gutter_w()
	var rh: float = ruler_h()
	var hot: bool = _hover_zone == "corner"
	draw_rect(Rect2(0.0, 0.0, gw, rh), Tk.c["bg_panel_high"] if hot else Tk.c["bg_ruler"], true)
	draw_rect(Rect2(0.0, rh - 1.0, gw, 1.0), Tk.c["border"], true)
	draw_rect(Rect2(gw - 1.0, 0.0, 1.0, rh), Tk.c["border"], true)
	var side: float = minf(rh - 4.0, 12.0)
	Icons.draw(self, "maximize", Rect2(Vector2((gw - side) * 0.5, (rh - side) * 0.5), Vector2(side, side)), Tk.c["text"] if hot else Tk.c["text_dim"])


func _draw_grip() -> void:
	var gh: float = grip_h()
	var y0: float = size.y - gh
	var hot: bool = _hover_zone == "grip" or _drag == "grip"
	draw_rect(Rect2(0.0, y0, size.x, gh), Tk.c["bg_panel_high"] if hot else Tk.c["bg_ruler"], true)
	draw_rect(Rect2(0.0, y0, size.x, 1.0), Tk.c["border"], true)
	var mid: float = size.x * 0.5
	var col: Color = Tk.c["text_dim"] if hot else Tk.c["text_faint"]
	for i: int in 3:
		draw_rect(Rect2(mid - 9.0 + float(i) * 7.0, y0 + gh * 0.5, 4.0, 1.0), col, true)


func _draw_span_shade(r: Rect2) -> void:
	var ks: Array[Dictionary] = keys_view()
	if ks.is_empty():
		return
	var first_x: float = x_of(float(ks[0].get("t", 0.0)))
	var last_x: float = x_of(float(ks[ks.size() - 1].get("t", 0.0)))
	if played_on():
		var axes: PackedFloat64Array = _axes_of(all_times())
		if axes.is_empty():
			return
		first_x = x_of(axes[0])
		last_x = x_of(axes[axes.size() - 1])
	if first_x > r.position.x + 1.0:
		draw_rect(Rect2(r.position.x, r.position.y, minf(first_x, r.end.x) - r.position.x, r.size.y), Color(0.0, 0.0, 0.0, 0.12), true)
	if last_x < r.end.x - 1.0:
		var from: float = maxf(last_x, r.position.x)
		draw_rect(Rect2(from, r.position.y, r.end.x - from, r.size.y), Color(0.0, 0.0, 0.0, 0.26), true)


func _draw_grid(r: Rect2) -> void:
	for lab: Dictionary in ruler_labels():
		var x: float = round(float(lab["x"]))
		draw_rect(Rect2(x, r.position.y, 1.0, r.size.y), Tk.c["border"], true)
	if mode == "value":
		for vl: Dictionary in value_labels():
			var y: float = round(float(vl["y"]))
			if y >= r.position.y - 0.5 and y <= r.end.y + 0.5:
				draw_rect(Rect2(r.position.x, y, r.size.x, 1.0), Tk.c["border"], true)


func _nice(span: float, divisions: float) -> float:
	var raw: float = maxf(span / maxf(divisions, 1.0), 0.000001)
	var mag: float = pow(10.0, floor(log(raw) / log(10.0)))
	for m: float in [1.0, 2.0, 5.0, 10.0]:
		if mag * m >= raw:
			return mag * m
	return mag * 10.0


func _secs_label(t: float) -> String:
	if t >= 60.0:
		return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]
	return "%.1fs" % t


func _tc_label(t: float) -> String:
	var total: int = int(floor(maxf(t, 0.0)))
	return "%02d:%02d" % [total / 60, total % 60]


func _draw_curve(r: Rect2, c: Clip) -> void:
	if mode == "value":
		_draw_zones(r, c)
	_draw_grid(r)
	var f: float = fps()
	var ghost: Color = Color(Tk.c["text_faint"], 0.5)
	for other: String in paths:
		if other == path:
			continue
		var op: Dictionary = c.get_param(other)
		if not AnimProp.is_animated(op):
			continue
		_draw_prop_curve(r, c, op, f, ghost, 1.0, false, other)
	var p: Dictionary = prop()
	var comps: int = component_count(AnimProp.static_value(p))
	var span: Vector2 = value_span(p)
	var rng: Vector2 = declared_range(c, path)
	for ci: int in comps:
		if mode == "value":
			_draw_value_curve(r, c, p, f, span, rng, ci)
		else:
			var col: Color = Tk.c["text_bright"] if ci == 0 else Tk.c["text_dim"]
			_draw_prop_curve_component(r, c, p, f, col, 1.5, ci)
	var ks: Array[Dictionary] = keys_view()
	for hp: Dictionary in handle_points():
		var kp: Vector2 = Vector2(x_of(float(hp["t"])), y_of(float(hp["v"])))
		var hpos: Vector2 = hp["pos"]
		var hcol: Color = Tk.c["text"]
		draw_line(kp, hpos, Color(hcol, 0.75), 1.0, true)
		draw_circle(hpos, 3.5, Tk.c["bg_field"])
		draw_arc(hpos, 3.5, 0.0, TAU, 20, hcol, 1.2, true)
	var shown_key: float = _drag_key_t if (_drag == "move" or _drag == "handle") and _drag_active else -INF
	var warp: bool = played_on()
	var sel_sorted: PackedFloat64Array = sorted_times(selected)
	var seg_over: PackedByteArray = segment_overshoots(ks, p, c.duration, f) if mode == "value" else PackedByteArray()
	var dragged_t: float = _dragged_time() if _drag_active and _drag == "move" and shown_key > -INF else INF
	if not warp and mode == "value":
		_draw_keys_fast(r, span, rng, ks, seg_over, sel_sorted, shown_key, dragged_t)
		ks = []
	var one: PackedFloat64Array = PackedFloat64Array([0.0])
	var tri_pts: PackedVector2Array = PackedVector2Array()
	var tri_cols: PackedColorArray = PackedColorArray()
	var tri_idx: PackedInt32Array = PackedInt32Array()
	var rings: Array = []
	var bubble_at: Vector2 = Vector2(INF, INF)
	var bubble_text: String = ""
	var tspan: float = maxf(t1 - t0, 0.0001)
	var vspan: float = maxf(v1 - v0, VALUE_SPAN_MIN)
	var left: float = r.position.x - 6.0
	var right: float = r.end.x + 6.0
	var bright: Color = Tk.c["text_bright"]
	var sol: Color = Tk.c["sol"]
	var plain_col: Color = Tk.c["text"]
	var value_mode: bool = mode == "value"
	for i: int in ks.size():
		var k: Dictionary = ks[i]
		var kt: float = float(k.get("t", 0.0))
		var raw: float = comp0(k.get("v", 0.0))
		var axes: PackedFloat64Array = one
		if warp:
			axes = axis_times(kt)
		else:
			one[0] = kt
		for ai: int in axes.size():
			var ax: float = r.position.x + (axes[ai] - t0) / tspan * r.size.x
			if ax < left or ax > right:
				continue
			var kv: float = raw if value_mode else (_velocity_axis(p, axes[ai], c.duration, f) if warp else _velocity_at(p, kt, c.duration, f))
			var pos: Vector2 = Vector2(ax, r.end.y - (kv - v0) / vspan * r.size.y)
			var sel: bool = has_near(sel_sorted, kt)
			var hollow: bool = String(k.get("i", "linear")) == "hold"
			var col2: Color = plain_col
			if value_mode:
				var over: bool = raw > rng.y or raw < rng.x or (i < seg_over.size() and seg_over[i] == 1) or (i > 0 and i - 1 < seg_over.size() and seg_over[i - 1] == 1)
				col2 = Tk.key_colour(raw, span.x, span.y, over)
			if absf(kt - _hover_key) <= AnimProp.KEY_TOLERANCE:
				col2 = col2.lerp(bright, 0.5)
			if ai > 0:
				col2 = Color(col2, col2.a * REPEAT_ALPHA)
			var side: float = KEY_R + (1.0 if sel else 0.0)
			if hollow:
				Paint.draw_diamond(self, pos, side, col2, false)
			else:
				var base_i: int = tri_pts.size()
				tri_pts.append(pos + Vector2(0.0, -side))
				tri_pts.append(pos + Vector2(side, 0.0))
				tri_pts.append(pos + Vector2(0.0, side))
				tri_pts.append(pos + Vector2(-side, 0.0))
				for q: int in 4:
					tri_cols.append(col2)
				tri_idx.append_array(PackedInt32Array([base_i, base_i + 1, base_i + 2, base_i, base_i + 2, base_i + 3]))
			if sel:
				rings.append([pos, 1.0 if ai == 0 else REPEAT_ALPHA])
			if ai == 0 and sel and _drag_active and _drag == "move" and value_mode and shown_key > -INF and absf(kt - dragged_t) <= AnimProp.KEY_TOLERANCE:
				bubble_at = pos + Vector2(0.0, KEY_R + 4.0)
				bubble_text = fmt_value(raw)
	if not tri_idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), tri_idx, tri_pts, tri_cols)
	for ring: Array in rings:
		draw_arc(ring[0], KEY_R + 3.5, 0.0, TAU, 24, Color(sol, float(ring[1])), 1.0, true)
	if bubble_at.x != INF:
		_draw_bubble(bubble_at, bubble_text)
	if _drag == "handle" and _drag_active:
		for hp2: Dictionary in handle_points():
			if absf(float(hp2["t"]) - _drag_key_t) <= AnimProp.KEY_TOLERANCE and String(hp2["side"]) == _handle_side:
				_draw_bubble((hp2["pos"] as Vector2) + Vector2(0.0, 6.0), fmt_value(float(hp2["v"]) + (hp2["h"] as Vector2).y))
	if mode == "velocity":
		PmText.draw(self, _font, r, "velocity", _fs, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, PmText.pad(), r.end.y - 3.0 - _font.get_descent(_fs), PmText.WHOLE)


func _xs_of(kt: float, p_path: String = "") -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	for ax: float in axis_times(kt, p_path):
		out.append(x_of(ax))
	return out


func _dragged_time() -> float:
	if _drag != "move" or _origin_sel.is_empty():
		return _drag_key_t
	var dtt: float = _drag_dt()
	var lo_t: float = INF
	for t: float in _origin_sel:
		lo_t = minf(lo_t, t)
	return maxf(_drag_key_t + maxf(dtt, -lo_t), 0.0)


func _velocity_at(p: Dictionary, t: float, dur: float, f: float) -> float:
	var h: float = 1.0 / maxf(f, 1.0)
	var a: float = AnimProp.evaluate_float(p, t - h, dur, f)
	var b: float = AnimProp.evaluate_float(p, t + h, dur, f)
	return (b - a) / (2.0 * h)


func _velocity_axis(p: Dictionary, axis_t: float, dur: float, f: float, p_path: String = "") -> float:
	var h: float = 1.0 / maxf(f, 1.0)
	var a: float = AnimProp.evaluate_float(p, key_t_of(axis_t - h, p_path), dur, f)
	var b: float = AnimProp.evaluate_float(p, key_t_of(axis_t + h, p_path), dur, f)
	return (b - a) / (2.0 * h)


func _draw_prop_curve(r: Rect2, c: Clip, p: Dictionary, f: float, col: Color, width: float, _dashed: bool, p_path: String = "") -> void:
	_draw_prop_curve_component(r, c, p, f, col, width, 0, p_path)


func _key_colours_sig() -> Array:
	return [Tk.c["key_low"], Tk.c["key_high"], Tk.c["key_negative"], Tk.c["key_over"], Tk.c["text_bright"], Tk.c["sol"]]


static func tri_pattern(n: int) -> PackedInt32Array:
	if _tri_cache.size() < n * 6:
		var out: PackedInt32Array = PackedInt32Array()
		var want: int = maxi(n, 256)
		out.resize(want * 6)
		for i: int in want:
			var b: int = i * 4
			out[i * 6] = b
			out[i * 6 + 1] = b + 1
			out[i * 6 + 2] = b + 2
			out[i * 6 + 3] = b
			out[i * 6 + 4] = b + 2
			out[i * 6 + 5] = b + 3
		_tri_cache = out
	return _tri_cache.slice(0, n * 6)


func _fill_key_slots(out: Dictionary, ks: Array[Dictionary], a: int, b: int, r: Rect2, span: Vector2, rng: Vector2, seg_over: PackedByteArray, sel_sorted: PackedFloat64Array) -> void:
	var pts: PackedVector2Array = out["pts"]
	var cols: PackedColorArray = out["cols"]
	var centres: PackedVector2Array = out["centres"]
	var ones: PackedColorArray = out["one"]
	var flags: PackedByteArray = out["flags"]
	var times: PackedFloat64Array = out["times"]
	var raws: PackedFloat64Array = out["raws"]
	var tspan: float = maxf(t1 - t0, 0.0001)
	var vspan: float = maxf(v1 - v0, VALUE_SPAN_MIN)
	var left: float = r.position.x - 6.0
	var right: float = r.end.x + 6.0
	var bright: Color = Tk.c["text_bright"]
	var n_over: int = seg_over.size()
	for i: int in range(a, b):
		var k: Dictionary = ks[i]
		var kt: float = float(k.get("t", 0.0))
		var raw: float = comp0(k.get("v", 0.0))
		var ax: float = r.position.x + (kt - t0) / tspan * r.size.x
		var pos: Vector2 = Vector2(ax, r.end.y - (raw - v0) / vspan * r.size.y)
		var visible: bool = ax >= left and ax <= right
		var sel: bool = has_near(sel_sorted, kt)
		var hollow: bool = String(k.get("i", "linear")) == "hold"
		var over: bool = raw > rng.y or raw < rng.x or (i < n_over and seg_over[i] == 1) or (i > 0 and i - 1 < n_over and seg_over[i - 1] == 1)
		var col: Color = Tk.key_colour(raw, span.x, span.y, over)
		if absf(kt - _hover_key) <= AnimProp.KEY_TOLERANCE:
			col = col.lerp(bright, 0.5)
		var side: float = KEY_R + (1.0 if sel else 0.0)
		if visible and not hollow:
			pts.append(pos + Vector2(0.0, -side))
			pts.append(pos + Vector2(side, 0.0))
			pts.append(pos + Vector2(0.0, side))
			pts.append(pos + Vector2(-side, 0.0))
		else:
			pts.append(pos)
			pts.append(pos)
			pts.append(pos)
			pts.append(pos)
		cols.append(col)
		cols.append(col)
		cols.append(col)
		cols.append(col)
		centres.append(pos)
		ones.append(col)
		flags.append((1 if visible else 0) | (2 if hollow else 0) | (4 if sel else 0))
		times.append(kt)
		raws.append(raw)
	out["pts"] = pts
	out["cols"] = cols
	out["centres"] = centres
	out["one"] = ones
	out["flags"] = flags
	out["times"] = times
	out["raws"] = raws


static func _new_slots() -> Dictionary:
	return {"pts": PackedVector2Array(), "cols": PackedColorArray(), "centres": PackedVector2Array(), "one": PackedColorArray(), "flags": PackedByteArray(), "times": PackedFloat64Array(), "raws": PackedFloat64Array()}


static func _append_slots(into: Dictionary, from: Dictionary, a: int, b: int) -> void:
	if b <= a:
		return
	var pts: PackedVector2Array = into["pts"]
	pts.append_array((from["pts"] as PackedVector2Array).slice(a * 4, b * 4))
	into["pts"] = pts
	var cols: PackedColorArray = into["cols"]
	cols.append_array((from["cols"] as PackedColorArray).slice(a * 4, b * 4))
	into["cols"] = cols
	var centres: PackedVector2Array = into["centres"]
	centres.append_array((from["centres"] as PackedVector2Array).slice(a, b))
	into["centres"] = centres
	var ones: PackedColorArray = into["one"]
	ones.append_array((from["one"] as PackedColorArray).slice(a, b))
	into["one"] = ones
	var flags: PackedByteArray = into["flags"]
	flags.append_array((from["flags"] as PackedByteArray).slice(a, b))
	into["flags"] = flags
	var times: PackedFloat64Array = into["times"]
	times.append_array((from["times"] as PackedFloat64Array).slice(a, b))
	into["times"] = times
	var raws: PackedFloat64Array = into["raws"]
	raws.append_array((from["raws"] as PackedFloat64Array).slice(a, b))
	into["raws"] = raws


func key_slots(r: Rect2, span: Vector2, rng: Vector2, ks: Array[Dictionary], seg_over: PackedByteArray, sel_sorted: PackedFloat64Array) -> Dictionary:
	var base: Array = [r, t0, t1, v0, v1, rng, span, _hover_key, _key_colours_sig()]
	var old: Dictionary = _key_cache
	var n: int = ks.size()
	if old.get("base", []) == base and old.has("keys"):
		var old_ks: Array = old["keys"]
		var no: int = old_ks.size()
		var same_sel: bool = old.get("sel", PackedFloat64Array()) == sel_sorted
		var lo: int = 0
		while lo < no and lo < n and (is_same(old_ks[lo], ks[lo]) or old_ks[lo] == ks[lo]):
			lo += 1
		if lo == no and lo == n and same_sel:
			return old
		var e: int = 0
		while e < no - lo and e < n - lo and (is_same(old_ks[no - 1 - e], ks[n - 1 - e]) or old_ks[no - 1 - e] == ks[n - 1 - e]):
			e += 1
		var a: int = maxi(lo - 3, 0)
		var b_new: int = mini(n - e + 3, n)
		var b_old: int = b_new - n + no
		var sel_ok: bool = same_sel
		if not same_sel:
			var t_lo: float = float(ks[a].get("t", 0.0)) if a < n else INF
			var t_hi: float = float(ks[b_new - 1].get("t", 0.0)) if b_new >= 1 else -INF
			sel_ok = _sel_changes_inside(old.get("sel", PackedFloat64Array()), sel_sorted, t_lo, t_hi, a == 0, b_new == n)
		if sel_ok and b_old >= a and b_old <= no:
			var out: Dictionary = _new_slots()
			_append_slots(out, old, 0, a)
			_fill_key_slots(out, ks, a, b_new, r, span, rng, seg_over, sel_sorted)
			_append_slots(out, old, b_old, no)
			out["base"] = base
			out["keys"] = ks
			out["sel"] = sel_sorted
			_key_cache = out
			return out
	var full: Dictionary = _new_slots()
	_fill_key_slots(full, ks, 0, n, r, span, rng, seg_over, sel_sorted)
	full["base"] = base
	full["keys"] = ks
	full["sel"] = sel_sorted
	_key_cache = full
	return full


static func _sel_changes_inside(old_sel: PackedFloat64Array, new_sel: PackedFloat64Array, t_lo: float, t_hi: float, open_lo: bool, open_hi: bool) -> bool:
	for t: float in old_sel:
		if not has_near(new_sel, t) and not _inside(t, t_lo, t_hi, open_lo, open_hi):
			return false
	for t2: float in new_sel:
		if not has_near(old_sel, t2) and not _inside(t2, t_lo, t_hi, open_lo, open_hi):
			return false
	return true


static func _inside(t: float, t_lo: float, t_hi: float, open_lo: bool, open_hi: bool) -> bool:
	var above: bool = open_lo or t >= t_lo - AnimProp.KEY_TOLERANCE
	var below: bool = open_hi or t <= t_hi + AnimProp.KEY_TOLERANCE
	return above and below


func _draw_keys_fast(r: Rect2, span: Vector2, rng: Vector2, ks: Array[Dictionary], seg_over: PackedByteArray, sel_sorted: PackedFloat64Array, shown_key: float, dragged_t: float) -> void:
	var slots: Dictionary = key_slots(r, span, rng, ks, seg_over, sel_sorted)
	var n: int = (slots["flags"] as PackedByteArray).size()
	if n > 0:
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), tri_pattern(n), slots["pts"], slots["cols"])
	var flags: PackedByteArray = slots["flags"]
	var centres: PackedVector2Array = slots["centres"]
	var ones: PackedColorArray = slots["one"]
	var times: PackedFloat64Array = slots["times"]
	var raws: PackedFloat64Array = slots["raws"]
	var sol: Color = Tk.c["sol"]
	var bubble: bool = _drag_active and _drag == "move" and shown_key > -INF
	for i: int in n:
		var fl: int = flags[i]
		if fl < 2 or (fl & 1) == 0:
			continue
		if (fl & 2) != 0:
			Paint.draw_diamond(self, centres[i], KEY_R + (1.0 if (fl & 4) != 0 else 0.0), ones[i], false)
		if (fl & 4) != 0:
			draw_arc(centres[i], KEY_R + 3.5, 0.0, TAU, 24, Color(sol, 1.0), 1.0, true)
			if bubble and absf(times[i] - dragged_t) <= AnimProp.KEY_TOLERANCE:
				_draw_bubble(centres[i] + Vector2(0.0, KEY_R + 4.0), fmt_value(raws[i]))


func _draw_value_curve(r: Rect2, c: Clip, p: Dictionary, f: float, span: Vector2, rng: Vector2, ci: int = 0) -> void:
	var step: float = curve_step()
	var base: Array = [r, t0, t1, v0, v1, c.duration, f, step, _warp_sig(), Tk.c["key_low"], Tk.c["key_high"], Tk.c["key_negative"], Tk.c["key_over"], layer_sig(p)]
	var h: int = p.hash()
	var cache_key: String = "value" + str(ci)
	var cached: Dictionary = _curve_cache.get(cache_key, {})
	var same_base: bool = cached.get("base", []) == base
	if same_base and int(cached.get("hash", 0)) == h and cached.get("span", Vector2.INF) == span and cached.get("rng", Vector2.INF) == rng:
		var cpts: PackedVector2Array = cached["pts"]
		if cpts.size() >= 2:
			draw_polyline_colors(cpts, cached["cols"], 1.6 if ci == 0 else 1.2, true)
		return
	var ks: Array[Dictionary] = keys_view()
	var sampled: Array
	if same_base and cached.has("keys") and plain_keys(p) and not played_on():
		sampled = resample_value_curve(cached, ks, r, c, p, f, span, rng, ci)
	else:
		sampled = sample_value_curve(r, c, p, f, span, rng, ci, step)
	_curve_cache[cache_key] = {"base": base, "hash": h, "span": span, "rng": rng, "pts": sampled[0], "cols": sampled[1], "ts": sampled[2], "vs": sampled[3], "keys": ks}
	var pts: PackedVector2Array = sampled[0]
	if pts.size() >= 2:
		draw_polyline_colors(pts, sampled[1], 1.6 if ci == 0 else 1.2, true)


static func layer_sig(p: Dictionary) -> Array:
	var out: Array = [str(p.get("base", 0.0)), bool(p.get("a", false))]
	for l: Variant in p.get("layers", []):
		if not (l is Dictionary):
			continue
		var ld: Dictionary = (l as Dictionary).duplicate()
		ld.erase("keys")
		out.append(ld.hash())
	return out


static func _key_time(ks: Array, i: int, fallback: float) -> float:
	if i < 0 or i >= ks.size():
		return fallback
	return float((ks[i] as Dictionary).get("t", 0.0))


static func changed_span(old_ks: Array, new_ks: Array) -> Vector2:
	var no: int = old_ks.size()
	var nn: int = new_ks.size()
	var lo: int = 0
	while lo < no and lo < nn and old_ks[lo] == new_ks[lo]:
		lo += 1
	if lo == no and lo == nn:
		return Vector2(INF, -INF)
	var e: int = 0
	while e < no - lo and e < nn - lo and old_ks[no - 1 - e] == new_ks[nn - 1 - e]:
		e += 1
	var hi_old: int = no - 1 - e
	var hi_new: int = nn - 1 - e
	var from: float = -INF
	if lo - 2 >= 0:
		from = minf(_key_time(old_ks, lo - 2, -INF), _key_time(new_ks, lo - 2, -INF))
	var to: float = INF
	if hi_old + 2 < no and hi_new + 2 < nn:
		to = maxf(_key_time(old_ks, hi_old + 2, INF), _key_time(new_ks, hi_new + 2, INF))
	return Vector2(from, to)


static func _segment_bounds(ks: Array, t: float, ci: int) -> Vector2:
	var n: int = ks.size()
	if n < 2:
		return Vector2(-INF, INF)
	var a: int = 0
	var b: int = n
	while a < b:
		var mid: int = (a + b) >> 1
		if float((ks[mid] as Dictionary).get("t", 0.0)) < t:
			a = mid + 1
		else:
			b = mid
	var j: int = a
	var i: int = j - 1
	if j == 0 and t == float((ks[0] as Dictionary).get("t", 0.0)):
		i = 0
	if i < 0 or i + 1 >= n:
		return Vector2(-INF, INF)
	var ta: float = float((ks[i] as Dictionary).get("t", 0.0))
	var tb: float = float((ks[i + 1] as Dictionary).get("t", 0.0))
	if t < ta or t > tb:
		return Vector2(-INF, INF)
	var va: float = comp((ks[i] as Dictionary).get("v", 0.0), ci)
	var vb: float = comp((ks[i + 1] as Dictionary).get("v", 0.0), ci)
	return Vector2(minf(va, vb), maxf(va, vb))


static func _sample_colour(v: float, t: float, ks: Array, span: Vector2, rng: Vector2, tol: float, ci: int, alpha: float) -> Color:
	var seg: Vector2 = _segment_bounds(ks, t, ci)
	var over: bool = v > rng.y + tol or v < rng.x - tol or v > seg.y + tol or v < seg.x - tol
	return Color(Tk.key_colour(v, span.x, span.y, over), alpha)


func resample_value_curve(cached: Dictionary, ks: Array[Dictionary], r: Rect2, c: Clip, p: Dictionary, f: float, span: Vector2, rng: Vector2, ci: int) -> Array:
	var pts: PackedVector2Array = (cached["pts"] as PackedVector2Array).duplicate()
	var cols: PackedColorArray = (cached["cols"] as PackedColorArray).duplicate()
	var ts: PackedFloat64Array = cached["ts"]
	var vs: PackedFloat64Array = (cached["vs"] as PackedFloat64Array).duplicate()
	var window: Vector2 = changed_span(cached["keys"], ks)
	var alpha: float = 1.0 if ci == 0 else 0.55
	var lo: float = minf(span.x, rng.x) if rng.x > -INF else span.x
	var hi: float = maxf(span.y, rng.y) if rng.y < INF else span.y
	var tol: float = maxf(absf(hi - lo), 1.0) * 0.005
	var vspan: float = maxf(v1 - v0, VALUE_SPAN_MIN)
	var top: float = r.position.y - 400.0
	var bottom: float = r.end.y + 400.0
	var picks: PackedInt32Array = PackedInt32Array()
	var sub: PackedFloat64Array = PackedFloat64Array()
	if window.x <= window.y:
		var first: int = ts.bsearch(window.x, true)
		var last: int = ts.bsearch(window.y, false)
		for i: int in range(first, last):
			picks.append(i)
			sub.append(ts[i])
	var fresh: PackedFloat64Array = curve_values(p, sub, c.duration, f, ci, true)
	for j: int in picks.size():
		var i: int = picks[j]
		vs[i] = fresh[j]
		pts[i] = Vector2(pts[i].x, clampf(r.end.y - (fresh[j] - v0) / vspan * r.size.y, top, bottom))
	var recolour_all: bool = cached.get("span", Vector2.INF) != span or cached.get("rng", Vector2.INF) != rng
	if recolour_all:
		for i: int in ts.size():
			cols[i] = _sample_colour(vs[i], ts[i], ks, span, rng, tol, ci, alpha)
	else:
		for i: int in picks:
			cols[i] = _sample_colour(vs[i], ts[i], ks, span, rng, tol, ci, alpha)
	return [pts, cols, ts, vs]


func sample_value_curve(r: Rect2, c: Clip, p: Dictionary, f: float, span: Vector2, rng: Vector2, ci: int, step: float) -> Array:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var x: float = r.position.x
	var alpha: float = 1.0 if ci == 0 else 0.55
	var lo: float = minf(span.x, rng.x) if rng.x > -INF else span.x
	var hi: float = maxf(span.y, rng.y) if rng.y < INF else span.y
	var tol: float = maxf(absf(hi - lo), 1.0) * 0.005
	var ks: Array[Dictionary] = keys_view() if is_same(p, prop()) else AnimProp.keys(p)
	var times: PackedFloat64Array = PackedFloat64Array()
	var vals: PackedFloat64Array = PackedFloat64Array()
	for k: Dictionary in ks:
		times.append(float(k.get("t", 0.0)))
		vals.append(comp(k.get("v", 0.0), ci))
	var warp: bool = played_on()
	var dur: float = c.duration
	var px0: float = r.position.x
	var pw: float = maxf(r.size.x, 1.0)
	var tspan: float = t1 - t0
	var vspan: float = maxf(v1 - v0, VALUE_SPAN_MIN)
	var top: float = r.position.y - 400.0
	var bottom: float = r.end.y + 400.0
	var xs: PackedFloat64Array = PackedFloat64Array()
	var ts: PackedFloat64Array = PackedFloat64Array()
	while x <= r.end.x:
		var tx: float = t0 + (x - px0) / pw * tspan
		xs.append(x)
		ts.append(c.param_time(path, tx) if warp else tx)
		x += step
	var vs: PackedFloat64Array = curve_values(p, ts, dur, f, ci, not warp)
	for i: int in xs.size():
		var t: float = ts[i]
		var v: float = vs[i]
		var seg_lo: float = -INF
		var seg_hi: float = INF
		var si: int = segment_of(times, t)
		if si >= 0:
			seg_lo = minf(vals[si], vals[si + 1])
			seg_hi = maxf(vals[si], vals[si + 1])
		var over: bool = v > rng.y + tol or v < rng.x - tol or v > seg_hi + tol or v < seg_lo - tol
		pts.append(Vector2(xs[i], clampf(r.end.y - (v - v0) / vspan * r.size.y, top, bottom)))
		cols.append(Color(Tk.key_colour(v, span.x, span.y, over), alpha))
	return [pts, cols, ts, vs]


static func curve_values(p: Dictionary, ts: PackedFloat64Array, dur: float, f: float, ci: int, rising: bool) -> PackedFloat64Array:
	return Paint.curve_values(p, ts, dur, f, ci, rising)


func _draw_prop_curve_component(r: Rect2, c: Clip, p: Dictionary, f: float, col: Color, width: float, ci: int, p_path: String = "") -> void:
	var step: float = curve_step()
	var sig: Array = [p.hash(), r, t0, t1, v0, v1, mode, c.duration, f, step, played_on(p_path), _warp_sig()]
	var cache_key: String = "line|" + p_path + "|" + str(ci)
	var cached: Dictionary = _curve_cache.get(cache_key, {})
	if cached.get("sig", []) == sig:
		var cpts: PackedVector2Array = cached["pts"]
		if cpts.size() >= 2:
			draw_polyline(cpts, col, width, true)
		return
	var pts := PackedVector2Array()
	var x: float = r.position.x
	var px0: float = r.position.x
	var pw: float = maxf(r.size.x, 1.0)
	var tspan: float = t1 - t0
	var vspan: float = maxf(v1 - v0, VALUE_SPAN_MIN)
	var top: float = r.position.y - 400.0
	var bottom: float = r.end.y + 400.0
	while x <= r.end.x:
		var t: float = t0 + (x - px0) / pw * tspan
		var v: float
		if mode == "velocity":
			v = _velocity_axis(p, t, c.duration, f, p_path)
		else:
			v = comp(eval_axis(p, t, c.duration, f, p_path), ci)
		pts.append(Vector2(x, clampf(r.end.y - (v - v0) / vspan * r.size.y, top, bottom)))
		x += step
	_curve_cache[cache_key] = {"sig": sig, "pts": pts}
	if pts.size() >= 2:
		draw_polyline(pts, col, width, true)


func _draw_dope(r: Rect2, c: Clip) -> void:
	_draw_grid(r)
	var rows: PackedStringArray = _dope_rows()
	for i: int in rows.size():
		var y: float = r.position.y + DOPE_ROW * float(i)
		if y > r.end.y:
			break
		var is_current: bool = rows[i] == path
		draw_rect(Rect2(r.position.x, y, r.size.x, DOPE_ROW), Tk.c["bg_panel"] if i % 2 == 0 else Tk.c["bg_panel_alt"], true)
		PmText.draw(self, _font, Rect2(r.position.x, y, 80.0 + PmText.chip_pad() * 2.0, DOPE_ROW), rows[i].get_slice(".", rows[i].get_slice_count(".") - 1), _fs, Tk.c["text_bright"] if is_current else Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, PmText.chip_pad())
		var p: Dictionary = c.get_param(rows[i])
		var dspan: Vector2 = value_span(p)
		for k: Dictionary in AnimProp.keys(p):
			var kt: float = float(k.get("t", 0.0))
			var xs: PackedFloat64Array = _xs_of(kt, rows[i])
			for xi: int in xs.size():
				var kx: float = xs[xi]
				if kx < r.position.x or kx > r.end.x:
					continue
				var sel: bool = is_current and _has_selected(kt)
				var dcol: Color = Tk.key_colour(comp0(k.get("v", 0.0)), dspan.x, dspan.y, false)
				if xi > 0:
					dcol = Color(dcol, dcol.a * REPEAT_ALPHA)
				Paint.draw_diamond(self, Vector2(kx, y + DOPE_ROW * 0.5), KEY_R, dcol, String(k.get("i", "")) != "hold")
				if sel:
					draw_arc(Vector2(kx, y + DOPE_ROW * 0.5), KEY_R + 3.0, 0.0, TAU, 24, Tk.c["sol"], 1.0, true)


func _draw_readout(c: Clip) -> void:
	var p: Dictionary = prop()
	var v: Variant = AnimProp.evaluate(p, _hover_key, c.duration, fps())
	var value_text: String = fmt_value(comp0(v)) if not (v is Array) else str(v)
	var at_axis: float = _hover_axis if played_on() else _hover_key
	if mini:
		_draw_bubble(Vector2(x_of(at_axis), y_of(comp0(v)) + KEY_R + 4.0), value_text)
		return
	var text: String = "t " + _tc_full(at_axis + c.start) + " · " + value_text
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var w: float = minf(ceil(PmText.width_of(Tk.font("mono"), text, fs)) + 10.0, size.x)
	var h: float = maxf(_px(18.0), ceil(Tk.font("mono").get_height(fs)) + 4.0)
	var pos: Vector2 = _hover_pos + Vector2(12.0, -24.0)
	pos.x = clampf(pos.x, 0.0, maxf(size.x - w, 0.0))
	pos.y = clampf(pos.y, 0.0, maxf(size.y - h, 0.0))
	Paint.rounded(self, Rect2(pos, Vector2(w, h)), Tk.c["bg_panel_alt"], 6.0, Tk.c["border_soft"], 1)
	PmText.draw(self, Tk.font("mono"), Rect2(pos, Vector2(w, h)), text, fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, 5.0)


func _draw_bubble(under: Vector2, text: String) -> void:
	var fs: int = Tk.fs(Tk.sz("font_tiny"))
	var mono: Font = Tk.font("mono")
	var w: float = minf(ceil(PmText.width_of(mono, text, fs)) + PmText.chip_pad() * 2.0, size.x)
	var h: float = maxf(float(fs) + 6.0, ceil(mono.get_height(fs)) + 4.0)
	var rect: Rect2 = Rect2(under.x - w * 0.5, under.y, w, h)
	rect.position.x = clampf(rect.position.x, 0.0, maxf(size.x - w, 0.0))
	rect.position.y = clampf(rect.position.y, 0.0, maxf(size.y - h, 0.0))
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.72), true)
	draw_rect(rect, Tk.c["border_soft"], false, 1.0)
	PmText.draw(self, mono, rect, text, fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, PmText.chip_pad())


func _tc_full(t: float) -> String:
	var Timecode: GDScript = load("res://doc/timecode.gd")
	return String(Timecode.call("format", t, fps(), false))

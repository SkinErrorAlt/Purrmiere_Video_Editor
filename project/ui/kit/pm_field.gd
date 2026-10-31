extends Control

signal value_changed(v: float)
signal edit_begun
signal edit_ended
signal typed(text: String)

const SLOP := 3.0
const ALLOWED := "0123456789.+-*/() "
const COARSE := 10.0
const FINE := 0.1
const PREF_CAPTURE := "ui.field_capture"
const PREF_BUDGET := "ui.drag_range_px"
const PREF_SHIFT_FINE := "ui.shift_is_fine"
const PREF_WHEEL := "ui.wheel_step_size"
const PmPointer := preload("res://ui/kit/pm_pointer.gd")
const TURN := 360.0
const MS_PER_PX := 1.0
const TIMES: PackedStringArray = ["x", "X", "×"]
const SMALL_RANGE_STEPS := 16.0
const SMALL_RANGE_PX := 6.0
const BUDGET_PX := 600.0
const BUDGET_MIN := 60.0
const BUDGET_MAX := 4000.0
const STEP_MULTS: PackedFloat64Array = [0.01, 0.1, 1.0, 10.0, 100.0]
const WHEEL_MODES: PackedStringArray = ["off", "alt", "wheel"]
const PREF_ROTATION_TYPING := "ui.rotation_typing"
const ROTATION_TYPINGS: PackedStringArray = ["premiere", "times"]

var value: float = 0.0:
	set(v):
		if v == value:
			return
		value = v
		queue_redraw()
var min_value: float = -INF
var max_value: float = INF
var step: float = 1.0
var precision: int = -1
var suffix: String = ""
var reach: bool = false
var editable: bool = true
var show_range: bool = false
var label_text: String = ""
var turns: bool = false
var per_px: float = 0.0
var step_mult: float = 1.0
var _budget: float = 0.0
var _pressed: bool = false
var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _last_pos: Vector2 = Vector2.ZERO
var _travel: Vector2 = Vector2.ZERO
var _accum: float = 0.0
var _hover: bool = false
var _captured: bool = false
var _anchor: Vector2i = Vector2i.ZERO
var _editor: LineEdit = null
static var plant_skip_round_guard: bool = false


static func set_plant_skip_round_guard(on: bool) -> void:
	plant_skip_round_guard = on


static func make(v: float, min_v: float = -INF, max_v: float = INF, step_: float = 1.0, suffix_: String = "") -> Control:
	var script: GDScript = load("res://ui/kit/pm_field.gd")
	var f: Control = script.new()
	f.set("value", v)
	f.set("min_value", min_v)
	f.set("max_value", max_v)
	f.set("step", step_)
	f.set("suffix", suffix_)
	if suffix_.strip_edges() == "ms":
		f.set("per_px", MS_PER_PX)
	return f


static func parse_expression(text: String) -> Dictionary:
	var t: String = text.strip_edges()
	for ch: String in t:
		if not (ch in ALLOWED):
			return {"ok": false, "value": 0.0}
	if t.is_empty():
		return {"ok": false, "value": 0.0}
	var ex := Expression.new()
	if ex.parse(t) != OK:
		return {"ok": false, "value": 0.0}
	var out: Variant = ex.execute([], null, false)
	if ex.has_execute_failed():
		return {"ok": false, "value": 0.0}
	if typeof(out) == TYPE_INT or typeof(out) == TYPE_FLOAT:
		return {"ok": true, "value": float(out)}
	return {"ok": false, "value": 0.0}


static func pref_rotation_typing() -> String:
	if not Prefs.is_registered(PREF_ROTATION_TYPING):
		Prefs.register(PREF_ROTATION_TYPING, "premiere", {"label": "Typing 2x45 into a rotation: premiere means two turns and 45 degrees, times means 2 times 45", "type": "enum", "choices": Array(ROTATION_TYPINGS)})
	var want: String = String(Prefs.get_value(PREF_ROTATION_TYPING))
	return want if want in ROTATION_TYPINGS else "premiere"


static func set_rotation_typing(mode: String) -> void:
	pref_rotation_typing()
	if mode in ROTATION_TYPINGS:
		Prefs.set_value(PREF_ROTATION_TYPING, mode)


static func parse_text(text: String, turns_on: bool, mode: String = "") -> Dictionary:
	var t: String = text.strip_edges().replace("°", "").replace("deg", "").strip_edges()
	for m: String in TIMES:
		t = t.replace(m, "x")
	var marks: int = t.count("x")
	if turns_on and marks == 1 and (t.strip_edges().ends_with("x") or t.strip_edges().begins_with("x")):
		var n: Dictionary = parse_expression(t.replace("x", ""))
		if not bool(n["ok"]):
			return n
		return {"ok": true, "value": float(n["value"]) * TURN}
	var how: String = mode if mode in ROTATION_TYPINGS else pref_rotation_typing()
	if turns_on and marks == 1 and how == "premiere":
		var whole: Dictionary = parse_expression(t.get_slice("x", 0))
		var rest: Dictionary = parse_expression(t.get_slice("x", 1))
		if not bool(whole["ok"]) or not bool(rest["ok"]):
			return {"ok": false, "value": 0.0}
		return {"ok": true, "value": float(whole["value"]) * TURN + float(rest["value"])}
	return parse_expression(t.replace("x", "*"))


static func turns_text(v: float, d: int, suffix_: String) -> String:
	if is_nan(v) or is_inf(v):
		return String.num(v, d) + suffix_
	var shown: float = snappedf(v, pow(10.0, -float(d)))
	if absf(shown) < TURN:
		return String.num(v, d) + suffix_
	var n: int = int(shown / TURN)
	var rest: float = snappedf(shown - float(n) * TURN, pow(10.0, -float(d)))
	return str(n) + "x " + String.num(rest, d) + suffix_


static func pref_precision() -> int:
	if not Prefs.is_registered("ui.precision"):
		Prefs.register("ui.precision", 1, {"label": "Decimals shown in fields", "type": "int", "min": 0, "max": 6})
	return int(Prefs.get_value("ui.precision"))


static func pref_rounding() -> bool:
	if not Prefs.is_registered("ui.rounding"):
		Prefs.register("ui.rounding", true, {"label": "Round typed values to the shown decimals", "type": "bool"})
	return bool(Prefs.get_value("ui.rounding"))


static func pref_capture() -> bool:
	if not Prefs.is_registered(PREF_CAPTURE):
		Prefs.register(PREF_CAPTURE, true, {"label": "Number fields: hide the pointer while dragging so a drag never runs out of screen", "type": "bool"})
	return bool(Prefs.get_value(PREF_CAPTURE))


static func round_to(v: float, decimals: int) -> float:
	var k: float = pow(10.0, float(maxi(0, decimals)))
	return round(v * k) / k


static func pref_budget() -> float:
	if not Prefs.is_registered(PREF_BUDGET):
		Prefs.register(PREF_BUDGET, BUDGET_PX, {"label": "Pixels of drag that cross a value's whole range", "type": "float", "min": BUDGET_MIN, "max": BUDGET_MAX})
	return clampf(float(Prefs.get_value(PREF_BUDGET)), BUDGET_MIN, BUDGET_MAX)


static func pref_shift_fine() -> bool:
	if not Prefs.is_registered(PREF_SHIFT_FINE):
		Prefs.register(PREF_SHIFT_FINE, true, {"label": "Value fields: Shift is the fine modifier and Ctrl the coarse one, off swaps them back", "type": "bool"})
	return bool(Prefs.get_value(PREF_SHIFT_FINE))


static func pref_wheel_mode() -> String:
	if not Prefs.is_registered(PREF_WHEEL):
		Prefs.register(PREF_WHEEL, "off", {"label": "Wheel over a value field sets the step size, never the value: off, alt for Alt+wheel only, wheel for any wheel, which stops the wheel scrolling the panel over a field", "type": "enum", "choices": Array(WHEEL_MODES)})
	var want: String = String(Prefs.get_value(PREF_WHEEL))
	return want if want in WHEEL_MODES else "off"


static func wheel_takes(alt: bool) -> bool:
	var mode: String = pref_wheel_mode()
	if mode == "wheel":
		return true
	if mode == "alt":
		return alt
	return false


static func fine_held(shift: bool, ctrl: bool) -> bool:
	return shift if pref_shift_fine() else ctrl


static func coarse_held(shift: bool, ctrl: bool) -> bool:
	return ctrl if pref_shift_fine() else shift


static func rate_for(fine: bool, coarse: bool) -> float:
	if fine:
		return FINE
	if coarse:
		return COARSE
	return 1.0


static func grid_for(step_: float, fine: bool, _coarse: bool) -> float:
	var s: float = step_ if step_ > 0.0 else 1.0
	if fine:
		return s * FINE
	return s


static func range_steps(step_: float, lo: float, hi: float) -> float:
	var s: float = step_ if step_ > 0.0 else 1.0
	if not is_finite(lo) or not is_finite(hi) or hi <= lo:
		return 0.0
	return (hi - lo) / s


static func range_mult(step_: float, lo: float, hi: float, budget: float) -> float:
	var steps: float = range_steps(step_, lo, hi)
	if steps <= 0.0 or budget <= 0.0:
		return 1.0
	return maxf(1.0, steps / budget)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_HSIZE
	gui_input.connect(_on_input)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)


func _ready() -> void:
	if turns:
		pref_rotation_typing()
	var want_w: float = custom_minimum_size.x if custom_minimum_size.x > 0.0 else float(Tk.px(64.0))
	custom_minimum_size = Vector2(want_w, float(Tk.px(Tk.sz("field_h"))))
	set_process_shortcut_input(false)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _dragging or _pressed:
			_finish_drag()


func decimals() -> int:
	if precision >= 0:
		return precision
	var d: int = pref_precision()
	if step > 0.0 and step < 1.0:
		var need: int = int(ceil(-log(step) / log(10.0) - 0.0001))
		d = maxi(d, mini(need, 4))
	return d


func display_text() -> String:
	var d: int = decimals()
	if turns:
		return turns_text(value, d, suffix)
	return String.num(value, d) + suffix


func commit(v: float, from_typing: bool) -> void:
	_apply(v, from_typing, min_value, max_value)


func _apply(v: float, from_typing: bool, lo: float, hi: float) -> void:
	var nv: float = v
	if not reach:
		nv = clampf(nv, lo, hi)
	if from_typing and pref_rounding():
		nv = round_to(nv, decimals())
		if not plant_skip_round_guard and nv == round_to(value, decimals()):
			queue_redraw()
			return
	if nv == value:
		queue_redraw()
		return
	value = nv
	value_changed.emit(value)


func budget() -> float:
	if _budget <= 0.0:
		_budget = pref_budget()
	return _budget


func drag_mult() -> float:
	if per_px > 0.0:
		return per_px / (step if step > 0.0 else 1.0) * maxf(step_mult, 0.0)
	return range_mult(step, min_value, max_value, budget()) * maxf(step_mult, 0.0)


func drag_rate(fine: bool, coarse: bool) -> float:
	var m: float = drag_mult()
	if fine:
		return m * FINE if per_px > 0.0 else minf(FINE, m)
	if coarse:
		return m * COARSE
	return m


func drag_grid(fine: bool, coarse: bool) -> float:
	var s: float = step if step > 0.0 else 1.0
	return grid_for(s * minf(1.0, maxf(step_mult, 0.000001)), fine, coarse)


func range_px() -> float:
	var steps: float = range_steps(step, min_value, max_value)
	if steps <= 0.0:
		return 0.0
	return steps * px_per_step() / drag_rate(false, false)


func drag_by(px: float, fine: bool, coarse: bool) -> void:
	var s: float = step if step > 0.0 else 1.0
	var grid: float = drag_grid(fine, coarse)
	_accum += px / px_per_step() * s * drag_rate(fine, coarse)
	var n: float = floor(absf(_accum) / grid + 0.000001)
	if n < 1.0:
		return
	var whole: float = n * grid * signf(_accum)
	_accum -= whole
	_apply(snappedf(value + whole, grid), false, minf(min_value, value), maxf(max_value, value))


func px_per_step() -> float:
	if step >= 1.0 and is_finite(min_value) and is_finite(max_value) and (max_value - min_value) / step <= SMALL_RANGE_STEPS:
		return SMALL_RANGE_PX
	return 1.0


func nudge(dir: int, fine: bool, coarse: bool) -> void:
	var s: float = (step if step > 0.0 else 1.0) * maxf(step_mult, 0.000001)
	var grid: float = drag_grid(fine, coarse)
	var target: float = snappedf(value + float(dir) * s * rate_for(fine, coarse), grid)
	if _editor != null:
		var parsed: Dictionary = parse_text(_editor.text.replace(suffix, ""), turns)
		var base: float = float(parsed["value"]) if bool(parsed["ok"]) else value
		target = snappedf(base + float(dir) * s * rate_for(fine, coarse), grid)
		_apply(target, false, minf(min_value, base), maxf(max_value, base))
		_editor.text = String.num(value, decimals())
		_editor.select_all()
		return
	edit_begun.emit()
	_apply(target, false, minf(min_value, value), maxf(max_value, value))
	edit_ended.emit()


func mult_index() -> int:
	for i: int in STEP_MULTS.size():
		if is_equal_approx(float(STEP_MULTS[i]), step_mult):
			return i
	return STEP_MULTS.size() / 2


func mult_label() -> String:
	if is_equal_approx(step_mult, 1.0):
		return ""
	if step_mult >= 1.0:
		return "x" + String.num(step_mult, 0)
	return "x" + String.num(step_mult, 2).trim_suffix("0")


func cycle_step_mult(dir: int) -> void:
	var at: int = mult_index()
	var next: int = clampi(at + dir, 0, STEP_MULTS.size() - 1)
	if next == at:
		return
	step_mult = float(STEP_MULTS[next])
	_accum = 0.0
	update_minimum_size()
	queue_redraw()


func _on_enter() -> void:
	_hover = true
	set_process_shortcut_input(editable)
	queue_redraw()


func _on_exit() -> void:
	_hover = false
	if not _dragging:
		set_process_shortcut_input(false)
	queue_redraw()


func _shortcut_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or not _hover or _editor != null or not editable or not is_visible_in_tree():
		return
	if k.alt_pressed or (k.keycode != KEY_UP and k.keycode != KEY_DOWN):
		return
	nudge(1 if k.keycode == KEY_UP else -1, fine_held(k.shift_pressed, k.ctrl_pressed or k.meta_pressed), coarse_held(k.shift_pressed, k.ctrl_pressed or k.meta_pressed))
	get_viewport().set_input_as_handled()


func _rel(mm: InputEventMouseMotion) -> Vector2:
	var r: Vector2 = mm.relative
	if not _captured and r == Vector2.ZERO:
		r = mm.position - _last_pos
	_last_pos = mm.position
	return r


func _on_input(event: InputEvent) -> void:
	if not editable:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed and not _dragging and _editor == null and wheel_takes(mb.alt_pressed):
				cycle_step_mult(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
				accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					_finish_drag()
					begin_typing()
					accept_event()
					return
				_pressed = true
				_dragging = false
				_press_pos = mb.position
				_last_pos = mb.position
				_travel = Vector2.ZERO
				_accum = 0.0
				_anchor = PmPointer.screen_pos() if PmPointer.live() else Vector2i.ZERO
				accept_event()
			else:
				var click: bool = _pressed and not _dragging
				_finish_drag()
				if click:
					begin_typing()
				accept_event()
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if not _pressed:
			_last_pos = mm.position
			return
		var rel: Vector2 = _held_rel() if _captured else _rel(mm)
		if not _dragging:
			_travel += rel
			if absf(_travel.x) < SLOP and absf(_travel.y) < SLOP:
				return
			_dragging = true
			_accum = 0.0
			_budget = pref_budget()
			edit_begun.emit()
			_capture()
			queue_redraw()
			accept_event()
			return
		var fine: bool = fine_held(mm.shift_pressed, mm.ctrl_pressed or mm.meta_pressed) or (per_px > 0.0 and mm.alt_pressed)
		drag_by(rel.x, fine, coarse_held(mm.shift_pressed, mm.ctrl_pressed or mm.meta_pressed))
		accept_event()


func _held_rel() -> Vector2:
	var now: Vector2i = PmPointer.screen_pos()
	var d: Vector2i = now - _anchor
	if d != Vector2i.ZERO:
		PmPointer.warp_screen(_anchor)
	return Vector2(d)


func _capture() -> void:
	_captured = false
	if not pref_capture() or not PmPointer.live():
		return
	PmPointer.hold(true)
	PmPointer.warp_screen(_anchor)
	_captured = true


func _release_capture() -> void:
	if not _captured:
		return
	_captured = false
	PmPointer.hold(false)
	PmPointer.warp_screen(_anchor)


func _finish_drag() -> void:
	var was: bool = _dragging
	_pressed = false
	_dragging = false
	_accum = 0.0
	_release_capture()
	if not _hover:
		set_process_shortcut_input(false)
	if was:
		edit_ended.emit()
	queue_redraw()


func begin_typing() -> void:
	if _editor != null:
		return
	edit_begun.emit()
	var le := LineEdit.new()
	le.text = String.num(value, decimals())
	le.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	le.context_menu_enabled = false
	le.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_body")))
	le.add_theme_font_override("font", Tk.font("mono"))
	add_child(le)
	_editor = le
	le.text_submitted.connect(_on_typed)
	le.focus_exited.connect(_on_editor_left)
	le.gui_input.connect(_on_editor_input)
	le.grab_focus()
	le.select_all()
	queue_redraw()


func _on_editor_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var k: InputEventKey = event
	if k.keycode == KEY_ESCAPE:
		_editor.accept_event()
		_close_editor()
		return
	if (k.keycode == KEY_UP or k.keycode == KEY_DOWN) and not k.alt_pressed:
		var le: LineEdit = _editor
		nudge(1 if k.keycode == KEY_UP else -1, fine_held(k.shift_pressed, k.ctrl_pressed or k.meta_pressed), coarse_held(k.shift_pressed, k.ctrl_pressed or k.meta_pressed))
		le.accept_event()


func _on_typed(text: String) -> void:
	var parsed: Dictionary = parse_text(text.replace(suffix, ""), turns)
	typed.emit(text)
	if bool(parsed["ok"]):
		commit(float(parsed["value"]), true)
	_close_editor()


func _on_editor_left() -> void:
	if _editor != null:
		_on_typed(_editor.text)


func _close_editor() -> void:
	if _editor == null:
		return
	var le: LineEdit = _editor
	_editor = null
	if le.focus_exited.is_connected(_on_editor_left):
		le.focus_exited.disconnect(_on_editor_left)
	remove_child(le)
	le.queue_free()
	edit_ended.emit()
	queue_redraw()


func _draw() -> void:
	var radius: float = float(Tk.px(Tk.sz("radius_field")))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tk.c["bg_field"]
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	sb.border_color = Tk.c["text_dim"] if (_editor != null or _dragging) else (Tk.c["text_faint"] if _hover else Tk.c["border_soft"])
	sb.set_border_width_all(1)
	if _editor != null or _dragging:
		sb.shadow_color = Tk.c["glass_strong"]
		sb.shadow_size = 3
		sb.shadow_offset = Vector2.ZERO
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	if _editor != null:
		return
	var line_h: float = 2.0
	var line_y: float = size.y - 1.0 - line_h
	var inset: float = 1.0
	if radius > 1.0:
		inset = 1.0 + radius - sqrt(2.0 * radius - 1.0)
	var track_x0: float = inset
	var track_w: float = maxf(size.x - inset * 2.0, 0.0)
	draw_rect(Rect2(track_x0, line_y, track_w, line_h), Tk.c["border_soft"], true)
	if show_range and min_value > -INF and max_value < INF and max_value > min_value:
		var frac: float = clampf((value - min_value) / (max_value - min_value), 0.0, 1.0)
		var fill_col: Color = Tk.c["sol"] if (_dragging or _hover) else Color(Tk.c["sol"], 0.8)
		draw_rect(Rect2(track_x0, line_y, track_w * frac, line_h), fill_col, true)
	var font: Font = Tk.font("mono")
	var fsz: int = Tk.fs(Tk.sz("font_body"))
	var pad: float = float(Tk.px(Tk.sz("pad")))
	var text: String = display_text()
	var col: Color = Tk.c["text_bright"] if (_dragging or _hover) else Tk.c["text"]
	if not editable:
		col = Tk.c["text_dim"]
	var asc: float = font.get_ascent(fsz)
	var desc: float = font.get_descent(fsz)
	var y: float = (size.y - (asc + desc)) * 0.5 + asc
	var mtext: String = mult_label()
	var mroom: float = 0.0 if mtext.is_empty() else _text_w(mtext) + float(Tk.px(Tk.sz("gap")))
	var room: float = maxf(size.x - pad * 2.0 - mroom, 0.0)
	if not label_text.is_empty():
		draw_string(font, Vector2(pad, y), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Tk.c["text_dim"])
		draw_string(font, Vector2(pad, y), text, HORIZONTAL_ALIGNMENT_RIGHT, room, fsz, col)
	else:
		draw_string(font, Vector2(pad, y), text, HORIZONTAL_ALIGNMENT_LEFT, room, fsz, col)
	if not mtext.is_empty():
		draw_string(font, Vector2(pad, y), mtext, HORIZONTAL_ALIGNMENT_RIGHT, size.x - pad * 2.0, fsz, Tk.c["text_faint"])
	_grow_for(text)


var _text_min_w: float = -1.0


func _text_w(t: String) -> float:
	return Tk.font("mono").get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, Tk.fs(Tk.sz("font_body"))).x


func widest_value_text() -> String:
	var d: int = decimals()
	var best: String = display_text()
	for v: float in [min_value, max_value]:
		if is_finite(v) and absf(v) < 1.0e9:
			var t: String = String.num(v, d) + suffix
			if t.length() > best.length():
				best = t
	return best


func text_need() -> float:
	var pad: float = float(Tk.px(Tk.sz("pad")))
	var need: float = pad * 2.0 + _text_w(widest_value_text())
	if not label_text.is_empty():
		need += _text_w(label_text) + float(Tk.px(Tk.sz("gap"))) * 2.0
	var mtext: String = mult_label()
	if not mtext.is_empty():
		need += _text_w(mtext) + float(Tk.px(Tk.sz("gap")))
	return ceil(need)


func _get_minimum_size() -> Vector2:
	_text_min_w = text_need()
	return Vector2(_text_min_w, 0.0)


func _grow_for(shown: String) -> void:
	var pad: float = float(Tk.px(Tk.sz("pad")))
	var need: float = pad * 2.0 + _text_w(shown)
	if not label_text.is_empty():
		need += _text_w(label_text) + float(Tk.px(Tk.sz("gap"))) * 2.0
	var mtext: String = mult_label()
	if not mtext.is_empty():
		need += _text_w(mtext) + float(Tk.px(Tk.sz("gap")))
	if need > _text_min_w + 0.5 and need > size.x + 0.5:
		update_minimum_size.call_deferred()


func fit_texts() -> Array:
	if _editor != null:
		return []
	var pad: float = float(Tk.px(Tk.sz("pad")))
	var shown: String = display_text()
	var mtext: String = mult_label()
	if not mtext.is_empty():
		shown += " " + mtext
	var value_w: float = _text_w(shown)
	var room: float = maxf(size.x - pad * 2.0, 0.0)
	if label_text.is_empty():
		return [{"text": shown, "rect": Rect2(pad, 0.0, minf(value_w, room), size.y), "need": value_w, "cut": value_w > room + 0.5}]
	var need: float = _text_w(label_text) + float(Tk.px(Tk.sz("gap"))) * 2.0 + value_w
	return [{"text": label_text + " " + shown, "rect": Rect2(pad, 0.0, minf(need, room), size.y), "need": need, "cut": need > room + 0.5}]

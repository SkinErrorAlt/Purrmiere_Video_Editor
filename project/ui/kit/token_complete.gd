extends Node

signal taken(token: String)

const DataText := preload("res://doc/data_text.gd")
const TextExtras := preload("res://doc/text_extras.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const PmTyping := preload("res://ui/kit/pm_typing.gd")
const SELF_PATH := "res://ui/kit/token_complete.gd"
const NODE_NAME := "TokenComplete"
const MAX_ROWS := 9
const MAX_INNER := 64
const MAX_GHOSTS := 256
const INSET := 5.0
const NAME_CHARS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
const DATE_TOKENS: PackedStringArray = ["date", "today"]
const TIME_TOKENS: PackedStringArray = ["time", "clock", "end"]
const SPAN_TOKENS: PackedStringArray = ["length", "into", "edit_time"]
const SPAN_STYLES: PackedStringArray = ["plain", "words", "long", "minutes"]
const LETTERS: PackedStringArray = ["YYYY", "MMMM", "MMM", "MM", "D", "Do", "DDDD", "h", "mm", "ss", "A"]
const SHORT_NAMES: Dictionary = {
	"date": "Date recorded",
	"today": "Today",
	"time": "Time it started",
	"clock": "Its clock now",
	"end": "Time it ended",
	"length": "Length",
	"into": "Time into it",
	"edit_time": "Editing time",
}
const STYLE_NAMES: Dictionary = {
	"short": "short",
	"long": "long",
	"day": "with the weekday",
	"ordinal": "ordinal day",
	"the": "written out",
	"shout": "month and day with a comma",
	"month_day": "month and day",
	"day_month": "day first",
	"iso": "year first numbers",
	"us": "US numbers",
	"eu": "European numbers",
	"year": "just the year",
	"clock": "12 hour",
	"clock_s": "12 hour with seconds",
	"24": "24 hour",
	"24s": "24 hour with seconds",
	"plain": "plain, like 1:05",
	"words": "in words",
	"minutes": "whole minutes",
}
const SPAN_LONG := "always with hours"
const COUNTER_LABELS: Dictionary = {
	"value": "The counter's number",
	"drive": "The counter's number, as a drive moves it",
}
const OWN_LABEL := "Your own pattern"
const NOTHING_UNDER := "Nothing is under this text here, so these show an example"
const NO_TIME := "When this was recorded is not known, so dates and times show an example"

var edit: Control = null
var provider: Callable = Callable()
var builds: int = 0
var _open: bool = false
var _quiet: bool = false
var _ctx: Dictionary = {}
var _all: Array[Dictionary] = []
var _rows: Array[Dictionary] = []
var _header: PackedStringArray = PackedStringArray()
var _at: Dictionary = {}
var _hi: int = -1
var _top: int = 0
var _typed: Dictionary = {}
var _ghosts: Dictionary = {}
var _last_caret: Vector2i = Vector2i(-1, -1)
var _seen_version: int = -1
var _pop: Control = null


static func attach(target: Control, ctx_provider: Callable = Callable()) -> Node:
	if target == null or not (target is TextEdit or target is LineEdit):
		return null
	var have: Node = helper_of(target)
	if have != null:
		have.set("provider", ctx_provider)
		return have
	var h: Node = (load(SELF_PATH) as GDScript).new()
	h.name = NODE_NAME
	h.set("provider", ctx_provider)
	h.call("bind", target)
	target.add_child(h, false, Node.INTERNAL_MODE_BACK)
	return h


static func helper_of(target: Control) -> Node:
	if target == null:
		return null
	for n: Node in target.get_children(true):
		if n.name == NODE_NAME and n.has_method("bind"):
			return n
	return null


static func title_context(doc: Object, seq: Object, clip: Object, t: float) -> Dictionary:
	var ctx: Dictionary = DataText.context(doc, seq, clip, t)
	if clip != null and clip.has_method("props_at"):
		var props: Variant = clip.call("props_at", t - float(clip.get("start")))
		if props is Dictionary:
			ctx["counter"] = TextExtras.number_text(props)
	return ctx


static func sample_start() -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 4, "day": 25, "hour": 15, "minute": 7, "second": 9}))


static func with_sample(ctx: Dictionary) -> Dictionary:
	var out: Dictionary = ctx.duplicate()
	if not out.has("today"):
		out["today"] = float(Time.get_unix_time_from_system()) + float(int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	if float(out.get("rec_start", -1.0)) < 0.0:
		out["note"] = NO_TIME if out.has("file") else NOTHING_UNDER
		out["rec_start"] = sample_start()
		out["rec_end"] = sample_start() + 754.0
	if not out.has("file"):
		out["file"] = "2026-04-25 15-07-09.mp4"
		out["name"] = "Holiday"
		out["length"] = 754.0
		out["into"] = 65.0
		out["fps"] = 30.0
		out["size"] = "1920 x 1080"
	if not out.has("project"):
		out["project"] = "Untitled"
	if not out.has("counter"):
		out["counter"] = "0"
	return out


static func inner_ok(inner: String) -> bool:
	var colon: int = inner.find(":")
	var name_part: String = inner if colon < 0 else inner.substr(0, colon)
	for k: int in name_part.length():
		if not NAME_CHARS.contains(name_part[k]):
			return false
	if colon >= 0:
		if name_part.is_empty():
			return false
		var arg: String = inner.substr(colon + 1)
		if arg.contains("{") or arg.contains("}") or arg.contains("\t"):
			return false
	return true


static func scan_line(s: String, col: int, line: int = 0) -> Dictionary:
	if col <= 0 or col > s.length():
		return {}
	var open: int = -1
	var i: int = col - 1
	var lowest: int = maxi(col - MAX_INNER - 1, 0)
	while i >= lowest:
		var ch: String = s[i]
		if ch == "}":
			return {}
		if ch == "{":
			open = i
			break
		i -= 1
	if open < 0:
		return {}
	var inner: String = s.substr(open + 1, col - open - 1)
	if not inner_ok(inner):
		return {}
	var tail: int = 0
	var j: int = col
	while j < s.length() and j - col <= MAX_INNER:
		var cj: String = s[j]
		if cj == "{":
			break
		if cj == "}":
			if inner_ok(s.substr(open + 1, j - open - 1)):
				tail = j - col + 1
			break
		j += 1
	return {"line": line, "open": open, "col": col, "tail": tail, "inner": inner}


static func span_default(name_: String) -> String:
	return "words" if name_ == "edit_time" else "plain"


static func make_row(name_: String, arg: String, ctx: Dictionary) -> Dictionary:
	var inner: String = name_ if arg.is_empty() else name_ + ":" + arg
	var token: String = "{" + inner + "}"
	var label: String = String(DataText.TOKEN_LABELS.get(name_, name_))
	if not arg.is_empty():
		var style: String = SPAN_LONG if (arg == "long" and SPAN_TOKENS.has(name_)) else String(STYLE_NAMES.get(arg, arg))
		label = String(SHORT_NAMES.get(name_, name_)) + ", " + style
	return {"inner": inner, "name": name_, "arg": arg, "token": token, "label": label, "preview": DataText.expand(token, ctx), "lower": inner.to_lower(), "label_lower": label.to_lower()}


static func all_rows(ctx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for name_: String in DataText.TOKENS:
		out.append(make_row(name_, "", ctx))
		if DATE_TOKENS.has(name_):
			for key: Variant in DataText.DATE_PRESETS.keys():
				out.append(make_row(name_, String(key), ctx))
		elif TIME_TOKENS.has(name_):
			for key2: Variant in DataText.TIME_PRESETS.keys():
				out.append(make_row(name_, String(key2), ctx))
		elif SPAN_TOKENS.has(name_):
			for style: String in SPAN_STYLES:
				if style != span_default(name_):
					out.append(make_row(name_, style, ctx))
	for tok: String in TextExtras.TOKENS:
		var bare: String = tok.trim_prefix("{").trim_suffix("}")
		var lab: String = String(COUNTER_LABELS.get(bare, bare))
		out.append({"inner": bare, "name": bare, "arg": "", "token": tok, "label": lab, "preview": String(ctx.get("counter", "0")), "lower": bare.to_lower(), "label_lower": lab.to_lower()})
	return out


static func is_preset(arg: String) -> bool:
	return DataText.DATE_PRESETS.has(arg) or DataText.TIME_PRESETS.has(arg)


static func own_help(name_: String, inner: String, ctx: Dictionary) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	for letter: String in LETTERS:
		parts.append(letter + " " + DataText.expand("{" + name_ + ":" + letter + "}", ctx))
	var out: PackedStringArray = PackedStringArray()
	out.append("Your own pattern reads: " + DataText.expand("{" + inner + "}", ctx))
	out.append("   ".join(parts.slice(0, 7)))
	out.append("   ".join(parts.slice(7)) + "   [words in brackets] stay as written")
	return out


static func filter(all: Array[Dictionary], inner: String, ctx: Dictionary) -> Dictionary:
	var first: Array[Dictionary] = []
	var second: Array[Dictionary] = []
	var third: Array[Dictionary] = []
	var header: PackedStringArray = PackedStringArray()
	var low: String = inner.to_lower()
	var colon: int = inner.find(":")
	if colon < 0:
		for r: Dictionary in all:
			if String(r["lower"]).begins_with(low):
				first.append(r)
			elif String(r["name"]).contains(low):
				second.append(r)
			elif low.length() >= 2 and String(r["arg"]).is_empty() and String(r["label_lower"]).contains(low):
				third.append(r)
	else:
		var name_: String = inner.substr(0, colon)
		var arg: String = inner.substr(colon + 1)
		var arg_low: String = arg.to_lower()
		for r2: Dictionary in all:
			if String(r2["name"]) != name_ or String(r2["arg"]).is_empty():
				continue
			if String(r2["arg"]).to_lower().begins_with(arg_low):
				first.append(r2)
		if (DATE_TOKENS.has(name_) or TIME_TOKENS.has(name_)) and not arg.is_empty() and not is_preset(arg):
			var token: String = "{" + inner + "}"
			second.append({"inner": inner, "name": name_, "arg": arg, "token": token, "label": OWN_LABEL, "preview": DataText.expand(token, ctx), "lower": inner.to_lower(), "label_lower": OWN_LABEL.to_lower(), "own": true})
			header = own_help(name_, inner, ctx)
	var rows: Array[Dictionary] = []
	rows.append_array(first)
	rows.append_array(second)
	rows.append_array(third)
	return {"rows": rows, "header": header}


func bind(target: Control) -> void:
	edit = target
	target.gui_input.connect(_on_input)
	target.focus_exited.connect(_on_focus_exited)
	if target is TextEdit:
		(target as TextEdit).text_changed.connect(_on_text_changed)
	else:
		(target as LineEdit).text_changed.connect(_on_line_changed)
	set_process(false)


func is_open() -> bool:
	return _open


func shown() -> bool:
	return _open and _pop != null and is_instance_valid(_pop) and _pop.visible


func rows() -> Array[Dictionary]:
	return _rows


func header() -> PackedStringArray:
	return _header


func highlighted() -> int:
	return _hi


func previewing() -> bool:
	return not _typed.is_empty()


func popup() -> Control:
	return _pop


func context_used() -> Dictionary:
	return _ctx


func row_rect(i: int) -> Rect2:
	if _pop == null or not is_instance_valid(_pop) or i < _top or i >= mini(_rows.size(), _top + MAX_ROWS):
		return Rect2()
	var y: float = _head_h() + float(i - _top) * _row_h()
	return Rect2(_pop.global_position + Vector2(0.0, y), Vector2(_pop.size.x, _row_h()))


func _exit_tree() -> void:
	close()


func _editable() -> bool:
	if edit is TextEdit:
		return (edit as TextEdit).editable
	if edit is LineEdit:
		return (edit as LineEdit).editable
	return false


func _caret_now() -> Vector2i:
	if edit is TextEdit:
		var te: TextEdit = edit
		return Vector2i(te.get_caret_line(), te.get_caret_column())
	return Vector2i(0, (edit as LineEdit).caret_column)


func _scan() -> Dictionary:
	if edit is TextEdit:
		var te: TextEdit = edit
		if te.has_selection() or te.get_caret_count() > 1:
			return {}
		var line: int = te.get_caret_line()
		return scan_line(te.get_line(line), te.get_caret_column(), line)
	var le: LineEdit = edit
	if le.has_selection():
		return {}
	return scan_line(le.text, le.caret_column, 0)


func _on_text_changed() -> void:
	_typed = {}
	_note_version()
	_quiet = false
	refresh()


func _on_line_changed(_t: String) -> void:
	_on_text_changed()


func _on_focus_exited() -> void:
	call_deferred("_after_focus_out")


func _after_focus_out() -> void:
	if edit != null and is_instance_valid(edit) and edit.has_focus():
		return
	close()


func refresh() -> void:
	if edit == null or not is_instance_valid(edit) or not edit.is_inside_tree():
		return
	var at: Dictionary = _scan() if (edit.has_focus() and _editable() and not _quiet) else {}
	if at.is_empty():
		close()
		return
	if not _open:
		_open = true
		_ctx = _context()
		_all = all_rows(_ctx)
		builds += 1
		set_process(true)
	_at = at
	_last_caret = Vector2i(int(at["line"]), int(at["col"]))
	var got: Dictionary = filter(_all, String(at["inner"]), _ctx)
	_rows = got["rows"]
	_header = got["header"]
	if _ctx.has("note"):
		var with_note: PackedStringArray = PackedStringArray([String(_ctx["note"])])
		with_note.append_array(_header)
		_header = with_note
	_hi = -1
	_top = 0
	_show_pop()


func _context() -> Dictionary:
	var ctx: Dictionary = {}
	if provider.is_valid():
		var v: Variant = provider.call()
		if v is Dictionary:
			ctx = v
	return with_sample(ctx)


func close() -> void:
	_restore()
	_open = false
	_rows = []
	_header = PackedStringArray()
	_hi = -1
	_top = 0
	set_process(false)
	if _pop != null and is_instance_valid(_pop):
		var p: Node = _pop.get_parent()
		if p != null:
			p.remove_child(_pop)
		_pop.queue_free()
	_pop = null


func dismiss() -> void:
	_quiet = true
	close()


func move(step: int) -> void:
	var n: int = _rows.size()
	if n == 0:
		return
	var next: int = _hi + step
	if next >= n:
		next = -1
	elif next < -1:
		next = n - 1
	set_highlight(next)


func set_highlight(i: int) -> void:
	if i >= _rows.size():
		i = -1
	if i == _hi:
		return
	_hi = i
	if i >= 0:
		if i < _top:
			_top = i
		elif i >= _top + MAX_ROWS:
			_top = i - MAX_ROWS + 1
		_preview(i)
	else:
		_restore()
	if _pop != null and is_instance_valid(_pop):
		_pop.queue_redraw()


func scroll_by(rows_: int) -> void:
	_top = clampi(_top + rows_, 0, maxi(_rows.size() - MAX_ROWS, 0))
	if _pop != null and is_instance_valid(_pop):
		_pop.queue_redraw()


func take(i: int) -> bool:
	if i < 0 or i >= _rows.size() or _at.is_empty() or edit == null or not is_instance_valid(edit):
		return false
	var token: String = String(_rows[i]["token"])
	var at: Dictionary = _at
	close()
	var line: int = int(at["line"])
	var open: int = int(at["open"])
	var to: int = int(at["col"]) + int(at["tail"])
	if edit is TextEdit:
		var te: TextEdit = edit
		te.begin_complex_operation()
		te.remove_text(line, open, line, to)
		te.set_caret_line(line)
		te.set_caret_column(open)
		te.insert_text_at_caret(token)
		te.end_complex_operation()
		_ghosts.erase(te.text)
	else:
		var le: LineEdit = edit
		var s: String = le.text
		le.text = s.substr(0, open) + token + s.substr(to)
		le.caret_column = open + token.length()
		le.text_changed.emit(le.text)
	if not edit.has_focus():
		edit.grab_focus()
	taken.emit(token)
	return true


func _snapshot() -> Dictionary:
	if edit is TextEdit:
		var te: TextEdit = edit
		return {"text": te.text, "line": te.get_caret_line(), "col": te.get_caret_column(), "vs": te.scroll_vertical, "hs": te.scroll_horizontal}
	var le: LineEdit = edit
	return {"text": le.text, "line": 0, "col": le.caret_column, "vs": 0.0, "hs": 0}


func _set_quiet(text: String, line: int, col: int, vs: float, hs: int) -> void:
	edit.set_block_signals(true)
	if edit is TextEdit:
		var te: TextEdit = edit
		te.text = text
		te.set_caret_line(line, false)
		te.set_caret_column(col, false)
		te.scroll_vertical = vs
		te.scroll_horizontal = hs
	else:
		var le: LineEdit = edit
		le.text = text
		le.caret_column = col
	edit.set_block_signals(false)


func _note_version() -> void:
	if edit is TextEdit:
		_seen_version = (edit as TextEdit).get_version()


func _change_pending() -> bool:
	return edit is TextEdit and (edit as TextEdit).get_version() != _seen_version


func _preview(i: int) -> void:
	if edit == null or not is_instance_valid(edit) or _at.is_empty():
		return
	if _typed.is_empty():
		if _change_pending():
			return
		_typed = _snapshot()
	var token: String = String(_rows[i]["token"])
	var line: int = int(_at["line"])
	var open: int = int(_at["open"])
	var to: int = int(_at["col"]) + int(_at["tail"])
	var lines: PackedStringArray = String(_typed["text"]).split("\n")
	if line < 0 or line >= lines.size():
		return
	var s: String = lines[line]
	lines[line] = s.substr(0, open) + token + s.substr(to)
	var full: String = "\n".join(lines)
	if _ghosts.size() >= MAX_GHOSTS:
		_ghosts.clear()
	_ghosts[full] = true
	_set_quiet(full, line, open + token.length(), float(_typed["vs"]), int(_typed["hs"]))
	_place()


func _restore() -> void:
	if _typed.is_empty() or edit == null or not is_instance_valid(edit):
		_typed = {}
		return
	var t: Dictionary = _typed
	_typed = {}
	_set_quiet(String(t["text"]), int(t["line"]), int(t["col"]), float(t["vs"]), int(t["hs"]))
	_note_version()


func _ghost_step(k: InputEventKey) -> bool:
	if _ghosts.is_empty() or not (edit is TextEdit):
		return false
	var redo: bool = k.is_action("ui_redo", true)
	var undo: bool = not redo and k.is_action("ui_undo", true)
	if not undo and not redo:
		return false
	var te: TextEdit = edit
	if not te.editable:
		return false
	_restore()
	var start: String = te.text
	var n: int = 0
	while n < 64:
		if undo:
			if not te.has_undo():
				break
			te.undo()
		else:
			if not te.has_redo():
				break
			te.redo()
		n += 1
		var now: String = te.text
		if now != start and not _ghosts.has(now):
			break
	return true


func _on_input(event: InputEvent) -> void:
	if edit == null:
		return
	if event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			_restore()
		return
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed:
		return
	if _ghost_step(k):
		edit.accept_event()
		return
	if not _open or _rows.is_empty():
		return
	var code: Key = k.keycode
	if code == KEY_SHIFT or code == KEY_CTRL or code == KEY_ALT or code == KEY_META:
		return
	var bare: bool = not (k.ctrl_pressed or k.alt_pressed or k.meta_pressed)
	if code == KEY_DOWN and bare:
		move(1)
		edit.accept_event()
		return
	if code == KEY_UP and bare:
		move(-1)
		edit.accept_event()
		return
	if code == KEY_TAB and bare and not k.shift_pressed:
		take(_hi if _hi >= 0 else 0)
		edit.accept_event()
		return
	if (code == KEY_ENTER or code == KEY_KP_ENTER) and bare and _hi >= 0:
		take(_hi)
		edit.accept_event()
		return
	if code == KEY_ESCAPE:
		dismiss()
		edit.accept_event()
		return
	_restore()


func _input(event: InputEvent) -> void:
	if not _open or not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed or not (mb.button_index in PmTyping.ENDING_BUTTONS):
		return
	if _pop != null and is_instance_valid(_pop) and _pop.visible and PmTyping.inside(_pop, mb.position):
		return
	if edit != null and is_instance_valid(edit) and PmTyping.inside(edit, mb.position):
		return
	close()


func _process(_dt: float) -> void:
	if not _open:
		set_process(false)
		return
	if edit == null or not is_instance_valid(edit) or not edit.is_visible_in_tree() or not edit.has_focus():
		close()
		return
	if _typed.is_empty() and _caret_now() != _last_caret:
		refresh()
		return
	_place()


func _row_h() -> float:
	return float(Tk.px(Tk.sz("row_h"))) + 4.0


func _line_h() -> float:
	return Tk.font("body").get_height(Tk.fs(Tk.sz("font_small"))) + 4.0


func _head_h() -> float:
	if _header.is_empty():
		return INSET
	return INSET + float(_header.size()) * _line_h() + 5.0


func _pad() -> float:
	return float(Tk.px(Tk.sz("pad"))) + 3.0


func columns() -> Vector3:
	var body: Font = Tk.font("body")
	var mono: Font = Tk.font("mono")
	var fs: int = Tk.fs(Tk.sz("font_body"))
	var tok_w: float = 0.0
	var lab_w: float = 0.0
	var pre_w: float = 0.0
	for r: Dictionary in _rows:
		tok_w = maxf(tok_w, PmText.width_of(mono, String(r["token"]), fs))
		lab_w = maxf(lab_w, PmText.width_of(body, String(r["label"]), fs))
		pre_w = maxf(pre_w, PmText.width_of(body, String(r["preview"]), fs))
	return Vector3(minf(tok_w, float(Tk.px(230.0))), minf(lab_w, float(Tk.px(250.0))), minf(pre_w, float(Tk.px(230.0))))


func _show_pop() -> void:
	if _rows.is_empty():
		if _pop != null and is_instance_valid(_pop):
			_pop.visible = false
		return
	if _pop == null or not is_instance_valid(_pop):
		var overlay: Node = PmUI.overlay_for(edit)
		if overlay == null:
			return
		var p: _Pop = _Pop.new()
		p.helper = self
		overlay.add_child(p)
		_pop = p
	_pop.visible = true
	var cols: Vector3 = columns()
	var gap: float = float(Tk.px(Tk.sz("gap"))) * 3.0
	var w: float = _pad() * 2.0 + cols.x + cols.y + cols.z + gap * 2.0
	w = maxf(w, float(Tk.px(260.0)))
	var vp: Rect2 = _pop.get_viewport_rect()
	w = minf(w, maxf(vp.size.x - 8.0, 120.0))
	var shown_rows: int = mini(_rows.size(), MAX_ROWS)
	_pop.size = Vector2(w, _head_h() + float(shown_rows) * _row_h() + INSET)
	_place()
	_pop.queue_redraw()


func _caret_point() -> Dictionary:
	if edit is TextEdit:
		var te: TextEdit = edit
		var p: Vector2 = te.get_caret_draw_pos()
		var lh: float = float(te.get_line_height())
		return {"below": te.global_position + Vector2(p.x, p.y + 4.0), "above": te.global_position.y + p.y - lh - 2.0}
	var le: LineEdit = edit
	var f: Font = le.get_theme_font("font")
	var fs: int = le.get_theme_font_size("font_size")
	var sb: StyleBox = le.get_theme_stylebox("normal")
	var x: float = (sb.get_margin(SIDE_LEFT) if sb != null else 4.0) + (f.get_string_size(le.text.substr(0, le.caret_column), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if f != null else 0.0) - le.get_scroll_offset()
	x = clampf(x, 0.0, le.size.x)
	return {"below": le.global_position + Vector2(x, le.size.y + 2.0), "above": le.global_position.y - 2.0}


func _place() -> void:
	if _pop == null or not is_instance_valid(_pop) or not _pop.visible:
		return
	var at: Dictionary = _caret_point()
	var vp: Rect2 = _pop.get_viewport_rect()
	var p: Vector2 = at["below"]
	p.x -= _pad()
	if p.x + _pop.size.x > vp.size.x - 2.0:
		p.x = vp.size.x - 2.0 - _pop.size.x
	if p.y + _pop.size.y > vp.size.y - 2.0:
		p.y = float(at["above"]) - _pop.size.y
	p.x = maxf(0.0, p.x)
	p.y = maxf(0.0, p.y)
	p = p.round()
	if (p - _pop.global_position).length() > 0.5:
		_pop.global_position = p


class _Pop:
	extends Control

	var helper: Node = null

	func _init() -> void:
		name = "TokenSuggestions"
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		add_to_group(PmTyping.KEEP_GROUP)
		gui_input.connect(_on_input)
		mouse_exited.connect(_on_exit)

	func row_at(local_y: float) -> int:
		if helper == null:
			return -1
		var head: float = float(helper.call("_head_h"))
		var rh: float = float(helper.call("_row_h"))
		if local_y < head:
			return -1
		var idx: int = int(floor((local_y - head) / rh)) + int(helper.get("_top"))
		var rows_: Array = helper.call("rows")
		if idx < int(helper.get("_top")) or idx >= mini(rows_.size(), int(helper.get("_top")) + MAX_ROWS):
			return -1
		return idx

	func _on_input(event: InputEvent) -> void:
		if helper == null:
			return
		if event is InputEventMouseMotion:
			helper.call("set_highlight", row_at((event as InputEventMouseMotion).position.y))
			accept_event()
			return
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			accept_event()
			if not mb.pressed:
				return
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				helper.call("scroll_by", 3)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				helper.call("scroll_by", -3)
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				var r: int = row_at(mb.position.y)
				if r >= 0:
					helper.call("take", r)

	func _on_exit() -> void:
		if helper != null and is_instance_valid(helper):
			helper.call("set_highlight", -1)

	func _draw() -> void:
		if helper == null:
			return
		var sb := StyleBoxFlat.new()
		sb.bg_color = Tk.c["bg_panel_alt"]
		sb.border_color = Tk.c["border_soft"]
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(Tk.px(Tk.sz("radius_menu")))
		sb.anti_aliasing = true
		sb.shadow_color = Tk.c["shadow"]
		sb.shadow_size = Tk.px(10.0)
		sb.shadow_offset = Vector2(0.0, float(Tk.px(3.0)))
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var body: Font = Tk.font("body")
		var mono: Font = Tk.font("mono")
		var fs: int = Tk.fs(Tk.sz("font_body"))
		var small: int = Tk.fs(Tk.sz("font_small"))
		var pad: float = float(helper.call("_pad"))
		var line_h: float = float(helper.call("_line_h"))
		var y: float = INSET
		var head: PackedStringArray = helper.call("header")
		for hl: String in head:
			var box := Rect2(pad, y, size.x - pad * 2.0, line_h)
			PmText.draw_in(self, body, box, hl, small, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, PmText.baseline_in(body, small, box), PmText.ELIDE, box, 0.0)
			y += line_h
		if not head.is_empty():
			draw_rect(Rect2(INSET + 4.0, y + 2.0, size.x - INSET * 2.0 - 8.0, 1.0), Tk.c["border"], true)
		y = float(helper.call("_head_h"))
		var rows_: Array = helper.call("rows")
		var top: int = int(helper.get("_top"))
		var hi: int = int(helper.call("highlighted"))
		var rh: float = float(helper.call("_row_h"))
		var cols: Vector3 = helper.call("columns")
		var gap: float = float(Tk.px(Tk.sz("gap"))) * 3.0
		var row_radius: int = int(Tk.px(Tk.sz("radius_row")))
		var right: float = size.x - pad
		for i: int in range(top, mini(rows_.size(), top + MAX_ROWS)):
			var r: Dictionary = rows_[i]
			var row_box := Rect2(0.0, y, size.x, rh)
			if i == hi:
				var hs := StyleBoxFlat.new()
				hs.bg_color = Tk.c["glass"]
				hs.set_corner_radius_all(row_radius)
				hs.anti_aliasing = true
				draw_style_box(hs, Rect2(INSET, y, size.x - INSET * 2.0, rh))
			var base: float = PmText.baseline_in(body, fs, row_box)
			var tok_box := Rect2(pad, y, cols.x, rh)
			PmText.draw_in(self, mono, tok_box, String(r["token"]), fs, Tk.c["accent"], HORIZONTAL_ALIGNMENT_LEFT, base, PmText.ELIDE, row_box)
			var pre_x: float = maxf(right - cols.z, pad + cols.x + gap)
			var pre_box := Rect2(pre_x, y, right - pre_x, rh)
			PmText.draw_in(self, body, pre_box, String(r["preview"]), fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_RIGHT, base, PmText.ELIDE, row_box)
			var lab_x: float = pad + cols.x + gap
			var lab_box := Rect2(lab_x, y, maxf(pre_x - gap - lab_x, 0.0), rh)
			PmText.draw_in(self, body, lab_box, String(r["label"]), fs, Tk.c["text"] if i == hi else Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, base, PmText.ELIDE, row_box)
			y += rh
		if rows_.size() > MAX_ROWS:
			var track_h: float = float(MAX_ROWS) * rh
			var head_h: float = float(helper.call("_head_h"))
			var bar_h: float = maxf(track_h * float(MAX_ROWS) / float(rows_.size()), 12.0)
			var bar_y: float = head_h + (track_h - bar_h) * float(top) / float(maxi(rows_.size() - MAX_ROWS, 1))
			draw_rect(Rect2(size.x - 4.0, bar_y, 2.0, bar_h), Tk.c["text_faint"], true)

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Verbs := preload("res://doc/verbs.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const TextExtras := preload("res://doc/text_extras.gd")
const TextFrame := preload("res://doc/text_frame.gd")
const TextGlyphs := preload("res://engine/text_glyphs.gd")
const MonitorPick := preload("res://modules/core_panels/monitor_pick.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const TEXT_PATH := "props.text"
const EDIT_LABEL := "Edit text"
const NEW_LABEL := "New title"
const FRAME_INK := Color(0.91, 0.23, 0.23, 1.0)
const DRAG_INK := Color(0.91, 0.23, 0.23, 0.9)
const PICK_FILL := Color(0.27, 0.52, 1.0, 0.45)
const CARET_INK := Color(1.0, 1.0, 1.0, 1.0)
const CARET_EDGE := Color(0.0, 0.0, 0.0, 0.55)
const BLINK_MS := 530
const SLOP := 4.0
const MULTI_MS := 450
const MULTI_PX := 5.0
const FRAME_PAD := 3.0
const NEW_SIZE := 100.0
const WORD_BREAKS := " \t\n.,;:!?\"'()[]{}<>/\\|-"

var clip_id: String = ""
var seq_id: String = ""
var caret: int = 0
var anchor: int = 0
var made_here: bool = false
var made_undo: int = -1
var selecting: bool = false
var press: Dictionary = {}
var keys_seen: int = 0
var commits: int = 0
var _blink_at: int = 0
var _blink_on: bool = true
var _text_before: String = ""
var _clicks: int = 0
var _click_ms: int = 0
var _click_at: Vector2 = Vector2.ZERO
var _word_from: int = -1
var _word_to: int = -1


func editing() -> bool:
	return not clip_id.is_empty()


func pending_new() -> bool:
	return not press.is_empty()


func selection() -> Vector2i:
	return Vector2i(mini(caret, anchor), maxi(caret, anchor))


func has_selection() -> bool:
	return caret != anchor


func _doc(panel: Object) -> Project:
	return panel.call("doc") as Project


func _seq(panel: Object) -> Sequence:
	return panel.call("seq") as Sequence


func clip(panel: Object) -> Clip:
	var s: Sequence = _seq(panel)
	if s == null or clip_id.is_empty():
		return null
	return s.clip_by_id(clip_id)


func live_props(panel: Object, c: Clip) -> Dictionary:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	if d == null or s == null or c == null:
		return {}
	var m: MediaItem = d.media_by_id(c.media_id)
	if m == null or m.kind != "title":
		return {}
	var base: Dictionary = m.props.duplicate(true)
	var now: Dictionary = c.props_at(s.playhead - c.start, s.fps)
	for k: Variant in now.keys():
		base[k] = now[k]
	return TitleStyle.merged("title", {}, base, m.label)


func text_now(panel: Object) -> String:
	var c: Clip = clip(panel)
	if c == null:
		return ""
	var raw: Variant = TextExtras.plain(live_props(panel, c).get("text", ""))
	return String(raw) if raw is String else ""


func can_edit(panel: Object, c: Clip) -> bool:
	var props: Dictionary = live_props(panel, c)
	if props.is_empty():
		return false
	return not TextExtras.path_on(props)


func target(panel: Object) -> Dictionary:
	var c: Clip = clip(panel)
	if c == null:
		return {}
	return target_of(panel, c)


func target_of(panel: Object, c: Clip) -> Dictionary:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var props: Dictionary = live_props(panel, c)
	if props.is_empty():
		return {}
	var m: MediaItem = d.media_by_id(c.media_id)
	var size: Vector2 = MonitorPick.layer_size(c, m, s, d)
	if size.x < 2.0 or size.y < 2.0:
		return {}
	var made: Dictionary = panel.call("quad_for", c)
	var q: Variant = made.get("quad", PackedVector2Array())
	if not (q is PackedVector2Array) or (q as PackedVector2Array).size() != 4:
		return {}
	var qq: PackedVector2Array = q
	var xf: Transform2D = Transform2D(qq[1] - qq[0], qq[3] - qq[0], qq[0])
	if absf(xf.determinant()) < 0.000001:
		return {}
	return {"clip": c, "xf": xf, "size": size, "props": props, "layout": TextGlyphs.caret_layout(props, size)}


func _screen(panel: Object, pic: Rect2, t: Dictionary, p: Vector2) -> Vector2:
	var xf: Transform2D = t["xf"]
	var size: Vector2 = t["size"]
	var w: Dictionary = (t.get("layout", {}) as Dictionary).get("warp", {})
	return panel.call("_to_picture", pic, xf * (TextGlyphs.warp_point(w, p) / size))


func _layer_at(panel: Object, pic: Rect2, t: Dictionary, at: Vector2) -> Vector2:
	var s: Sequence = _seq(panel)
	var xf: Transform2D = t["xf"]
	var size: Vector2 = t["size"]
	var k: float = pic.size.x / maxf(float(s.width), 1.0)
	var seq_p: Vector2 = (at - pic.position) / maxf(k, 0.0001)
	var w: Dictionary = (t.get("layout", {}) as Dictionary).get("warp", {})
	return TextGlyphs.unwarp_point(w, (xf.affine_inverse() * seq_p) * size)


func frame_rect(t: Dictionary) -> Rect2:
	var props: Dictionary = t["props"]
	var size: Vector2 = t["size"]
	if TextFrame.is_box(props):
		return TextFrame.box_rect(props, size)
	var have: bool = false
	var r: Rect2 = Rect2()
	for ln: Dictionary in (t["layout"] as Dictionary).get("lines", []):
		var w: float = maxf(float(ln["w"]), 1.0)
		var lr: Rect2 = Rect2(float(ln["x"]), float(ln["top"]), w, float(ln["h"]))
		if not have:
			r = lr
			have = true
		else:
			r = r.merge(lr)
	return r


func _hit_frame(panel: Object, pic: Rect2, t: Dictionary, at: Vector2) -> bool:
	var lp: Vector2 = _layer_at(panel, pic, t, at)
	var size: Vector2 = t["size"]
	var grow: float = FRAME_PAD * 3.0 * size.y / 1080.0 + 6.0
	return frame_rect(t).grow(grow).has_point(lp)


func begin(panel: Object, id: String, at_caret: int = -1, select_all: bool = false) -> bool:
	var s: Sequence = _seq(panel)
	var c: Clip = s.clip_by_id(id) if s != null else null
	if c == null or not can_edit(panel, c):
		return false
	if editing() and clip_id != id:
		finish(panel)
	clip_id = id
	seq_id = s.id
	var n: int = text_now(panel).length()
	caret = n if at_caret < 0 else clampi(at_caret, 0, n)
	anchor = 0 if select_all else caret
	selecting = false
	_text_before = text_now(panel)
	_wake()
	_take_keys(panel)
	_clear_field_pick()
	var d: Project = _doc(panel)
	if not s.selected_clip_ids.has(id) or s.selected_clip_ids.size() != 1:
		Verbs.select(d, s, PackedStringArray([id]), "replace")
	_redraw(panel)
	return true


func _clear_field_pick() -> void:
	var ec: Object = Bus.instance().call("panel", "effect_controls")
	if ec == null or not ec.has_method("_row_for"):
		return
	var r: Dictionary = ec.call("_row_for", "props.text")
	var eds: Array = r.get("editors", []) if not r.is_empty() else []
	if not eds.is_empty() and eds[0] is TextEdit and is_instance_valid(eds[0]):
		(eds[0] as TextEdit).deselect()


func _take_keys(panel: Object) -> void:
	var v: Variant = panel.get("view")
	if not (v is Control) or not (v as Control).is_inside_tree():
		return
	var vp: Viewport = (v as Control).get_viewport()
	if vp != null:
		vp.gui_release_focus()
	var editor: Node = (v as Control).get_tree().root.find_child("EditorScreen", true, false)
	var dock: Variant = editor.get("dock") if editor != null else null
	if dock is Object and (dock as Object).has_method("focus_panel"):
		(dock as Object).call("focus_panel", "program")


func finish(panel: Object) -> void:
	if not editing():
		return
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var c: Clip = clip(panel)
	var empty: bool = text_now(panel).strip_edges().is_empty()
	commit(panel)
	if c != null and empty and made_here and d != null and made_undo >= 0 and d.undo.current_index() == made_undo:
		d.undo.undo()
	clip_id = ""
	seq_id = ""
	made_here = false
	made_undo = -1
	selecting = false
	caret = 0
	anchor = 0
	if s != null:
		_redraw(panel)


func commit(panel: Object) -> void:
	var d: Project = _doc(panel)
	if d == null or not d.undo.has_live():
		return
	var s: Sequence = _seq(panel)
	var c: Clip = clip(panel)
	if c != null and s != null:
		var want: String = first_line(text_now(panel))
		if not want.is_empty() and want != c.label and _label_follows(d, c):
			d.undo.live(ClipCmds.SetClipField.new(s.id, c.id, "label", want))
	d.undo.commit_live(EDIT_LABEL)
	commits += 1
	_text_before = text_now(panel)


static func first_line(text: String) -> String:
	var cut: int = text.find("\n")
	var line: String = (text if cut < 0 else text.substr(0, cut)).strip_edges()
	return line.substr(0, 48)


func _label_follows(d: Project, c: Clip) -> bool:
	if c.label.is_empty() or made_here:
		return true
	if c.label == first_line(_text_before):
		return true
	var m: MediaItem = d.media_by_id(c.media_id)
	return m != null and c.label == m.label


func replace(panel: Object, text: String) -> void:
	var cur: String = text_now(panel)
	var sel: Vector2i = selection()
	sel.x = clampi(sel.x, 0, cur.length())
	sel.y = clampi(sel.y, 0, cur.length())
	var after: String = cur.substr(0, sel.x) + text + cur.substr(sel.y)
	_write(panel, cur, after)
	caret = sel.x + text.length()
	anchor = caret


func _write(panel: Object, before: String, after: String) -> void:
	if before == after:
		return
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var c: Clip = clip(panel)
	if d == null or s == null or c == null:
		return
	var key_at: float = Bus.instance().key_time_for(c, TEXT_PATH, s.playhead)
	Verbs.set_clip_param(d, s, c.id, TEXT_PATH, after, key_at, true)
	var pop: GDScript = load("res://modules/core_panels/text_popout.gd")
	pop.call("apply_typed", d, s.id, c.id, before, after)
	pop.call("shift_picks", d, s.id, c.id, before, after)
	_wake()
	_redraw(panel)


func _wake() -> void:
	_blink_at = Time.get_ticks_msec()
	_blink_on = true


func tick(panel: Object) -> void:
	if not editing():
		return
	var c: Clip = clip(panel)
	var s: Sequence = _seq(panel)
	if c == null or s == null or s.id != seq_id or s.playhead < c.start or s.playhead >= c.end() or not s.selected_clip_ids.has(clip_id):
		finish(panel)
		return
	var on: bool = ((Time.get_ticks_msec() - _blink_at) / BLINK_MS) % 2 == 0
	if on != _blink_on:
		_blink_on = on
		_redraw(panel)


func _redraw(panel: Object) -> void:
	var v: Variant = panel.get("view")
	if v is Object and (v as Object).has_method("redraw_overlay"):
		(v as Object).call("redraw_overlay")


static func _is_break(ch: String) -> bool:
	return WORD_BREAKS.contains(ch)


static func word_left(text: String, at: int) -> int:
	var i: int = clampi(at, 0, text.length())
	while i > 0 and _is_break(text[i - 1]):
		i -= 1
	while i > 0 and not _is_break(text[i - 1]):
		i -= 1
	return i


static func word_right(text: String, at: int) -> int:
	var i: int = clampi(at, 0, text.length())
	while i < text.length() and not _is_break(text[i]):
		i += 1
	while i < text.length() and _is_break(text[i]) and text[i] != "\n":
		i += 1
	return i


static func word_span(text: String, at: int) -> Vector2i:
	if text.is_empty():
		return Vector2i.ZERO
	var i: int = clampi(at, 0, text.length())
	if i == text.length() or (_is_break(text[i]) and i > 0 and not _is_break(text[i - 1])):
		i = maxi(i - 1, 0)
	if _is_break(text[i]):
		return Vector2i(i, i + 1)
	var a: int = i
	var b: int = i
	while a > 0 and not _is_break(text[a - 1]):
		a -= 1
	while b < text.length() and not _is_break(text[b]):
		b += 1
	return Vector2i(a, b)


static func line_span(text: String, at: int) -> Vector2i:
	var i: int = clampi(at, 0, text.length())
	var a: int = text.rfind("\n", i - 1) + 1 if i > 0 else 0
	var b: int = text.find("\n", i)
	if b < 0:
		b = text.length()
	return Vector2i(a, b)


func _move(panel: Object, to: int, extend: bool) -> void:
	var n: int = text_now(panel).length()
	caret = clampi(to, 0, n)
	if not extend:
		anchor = caret
	_wake()
	_redraw(panel)


func _vertical(panel: Object, dir: int) -> int:
	var t: Dictionary = target(panel)
	if t.is_empty():
		return caret
	var layout: Dictionary = t["layout"]
	var li: int = TextGlyphs.caret_line(layout, caret)
	var lines: Array = layout.get("lines", [])
	var nl: int = li + dir
	if nl < 0:
		return 0
	if nl >= lines.size():
		return text_now(panel).length()
	var r: Rect2 = TextGlyphs.caret_rect(layout, caret)
	var ln: Dictionary = lines[nl]
	return TextGlyphs.caret_at_point(layout, Vector2(r.position.x, float(ln["top"]) + float(ln["h"]) * 0.5))


func handle_key(e: InputEventKey, panel: Object) -> bool:
	if not editing() or not e.pressed:
		return false
	var c: Clip = clip(panel)
	if c == null:
		finish(panel)
		return false
	keys_seen += 1
	var ctrl: bool = e.ctrl_pressed or e.meta_pressed
	var shift: bool = e.shift_pressed
	var text: String = text_now(panel)
	match e.keycode:
		KEY_ESCAPE:
			finish(panel)
			var s: Sequence = _seq(panel)
			if s != null and s.clip_by_id(c.id) != null:
				Verbs.select(_doc(panel), s, PackedStringArray([c.id]), "replace")
			if Session.tool_id == "type":
				Session.set_tool("select")
			return true
		KEY_ENTER, KEY_KP_ENTER:
			if ctrl:
				finish(panel)
				return true
			replace(panel, "\n")
			return true
		KEY_TAB:
			replace(panel, "\t")
			return true
		KEY_BACKSPACE:
			if not has_selection():
				anchor = word_left(text, caret) if ctrl else maxi(caret - 1, 0)
			replace(panel, "")
			return true
		KEY_DELETE:
			if not has_selection():
				anchor = word_right(text, caret) if ctrl else mini(caret + 1, text.length())
			replace(panel, "")
			return true
		KEY_LEFT:
			if has_selection() and not shift:
				_move(panel, selection().x, false)
			else:
				_move(panel, word_left(text, caret) if ctrl else caret - 1, shift)
			return true
		KEY_RIGHT:
			if has_selection() and not shift:
				_move(panel, selection().y, false)
			else:
				_move(panel, word_right(text, caret) if ctrl else caret + 1, shift)
			return true
		KEY_UP:
			_move(panel, _vertical(panel, -1), shift)
			return true
		KEY_DOWN:
			_move(panel, _vertical(panel, 1), shift)
			return true
		KEY_HOME:
			_move(panel, 0 if ctrl else line_span(text, caret).x, shift)
			return true
		KEY_END:
			_move(panel, text.length() if ctrl else line_span(text, caret).y, shift)
			return true
	if ctrl and not e.alt_pressed:
		match e.keycode:
			KEY_A:
				anchor = 0
				caret = text.length()
				_wake()
				_redraw(panel)
				return true
			KEY_C:
				if has_selection():
					DisplayServer.clipboard_set(text.substr(selection().x, selection().y - selection().x))
				return true
			KEY_X:
				if has_selection():
					DisplayServer.clipboard_set(text.substr(selection().x, selection().y - selection().x))
					replace(panel, "")
				return true
			KEY_V:
				var got: String = DisplayServer.clipboard_get().replace("\r\n", "\n").replace("\r", "\n")
				if not got.is_empty():
					replace(panel, got)
				return true
		commit(panel)
		return false
	if e.alt_pressed:
		return false
	if e.unicode >= 32 and e.unicode != 127:
		replace(panel, String.chr(e.unicode))
		return true
	if e.keycode >= KEY_F1 and e.keycode <= KEY_F12:
		return false
	return true


func input(event: InputEvent, pic: Rect2, panel: Object) -> bool:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return editing() and mb.pressed and _over_frame(panel, pic, mb.position)
		if mb.pressed:
			return _press(panel, pic, mb)
		return _release(panel, pic, mb)
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if not press.is_empty():
			press["now"] = mm.position
			if mm.position.distance_to(press["at"]) > SLOP:
				press["dragged"] = true
			_redraw(panel)
			return true
		if editing() and selecting:
			var t: Dictionary = target(panel)
			if t.is_empty():
				return true
			var idx: int = TextGlyphs.caret_at_point(t["layout"], _layer_at(panel, pic, t, mm.position))
			if _word_from >= 0:
				var w: Vector2i = word_span(text_now(panel), idx)
				if idx < _word_from:
					anchor = _word_to
					caret = w.x
				else:
					anchor = _word_from
					caret = maxi(w.y, _word_to)
			else:
				caret = idx
			_wake()
			_redraw(panel)
			return true
	return false


func _over_frame(panel: Object, pic: Rect2, at: Vector2) -> bool:
	var t: Dictionary = target(panel)
	return not t.is_empty() and _hit_frame(panel, pic, t, at)


func _count_click(mb: InputEventMouseButton) -> int:
	var now: int = Time.get_ticks_msec()
	if now - _click_ms <= MULTI_MS and mb.position.distance_to(_click_at) <= MULTI_PX:
		_clicks += 1
	else:
		_clicks = 1
	if mb.double_click and _clicks < 2:
		_clicks = 2
	_click_ms = now
	_click_at = mb.position
	return _clicks


func _press(panel: Object, pic: Rect2, mb: InputEventMouseButton) -> bool:
	if editing():
		var t: Dictionary = target(panel)
		if not t.is_empty() and _hit_frame(panel, pic, t, mb.position):
			var n: int = _count_click(mb)
			var idx: int = TextGlyphs.caret_at_point(t["layout"], _layer_at(panel, pic, t, mb.position))
			var text: String = text_now(panel)
			_word_from = -1
			_word_to = -1
			if n >= 3:
				var ln: Vector2i = line_span(text, idx)
				anchor = ln.x
				caret = ln.y
				if n >= 4:
					anchor = 0
					caret = text.length()
			elif n == 2:
				var w: Vector2i = word_span(text, idx)
				anchor = w.x
				caret = w.y
				_word_from = w.x
				_word_to = w.y
			else:
				caret = idx
				if not mb.shift_pressed:
					anchor = idx
			selecting = true
			_wake()
			_redraw(panel)
			return true
		finish(panel)
	if Session.tool_id != "type":
		return false
	var hit: String = String(panel.call("title_at", mb.position, pic)) if panel.has_method("title_at") else ""
	var s: Sequence = _seq(panel)
	var hc: Clip = s.clip_by_id(hit) if s != null and not hit.is_empty() else null
	if hc != null and can_edit(panel, hc):
		var t2: Dictionary = target_of(panel, hc)
		var at_idx: int = -1
		if not t2.is_empty():
			at_idx = TextGlyphs.caret_at_point(t2["layout"], _layer_at(panel, pic, t2, mb.position))
		if begin(panel, hc.id, at_idx):
			_count_click(mb)
			selecting = true
			return true
	press = {"at": mb.position, "now": mb.position, "dragged": false, "pic": pic}
	return true


func _release(panel: Object, pic: Rect2, mb: InputEventMouseButton) -> bool:
	if not press.is_empty():
		var p: Dictionary = press
		press = {}
		_make_new(panel, pic, p["at"], mb.position, bool(p["dragged"]))
		return true
	if editing() and selecting:
		selecting = false
		_word_from = -1
		_word_to = -1
		return true
	return false


func _make_new(panel: Object, pic: Rect2, a: Vector2, b: Vector2, dragged: bool) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	if d == null or s == null or pic.size.x <= 0.0:
		return false
	var k: float = pic.size.x / maxf(float(s.width), 1.0)
	var pa: Vector2 = (a - pic.position) / k
	var pb: Vector2 = (b - pic.position) / k
	var target_track: String = ""
	for tr: Object in s.video_tracks:
		if bool(tr.get("targeted")) and not bool(tr.get("locked")):
			target_track = String(tr.get("id"))
			break
	var ref: float = 1080.0 / maxf(float(s.height), 1.0)
	var extra: Dictionary = {"text": "", "frame": TextFrame.POINT, "align": "left", "valign": "top", "size": NEW_SIZE}
	var origin: Vector2 = pa
	if dragged:
		var lo: Vector2 = Vector2(minf(pa.x, pb.x), minf(pa.y, pb.y))
		var hi: Vector2 = Vector2(maxf(pa.x, pb.x), maxf(pa.y, pb.y))
		var box: Vector2 = (hi - lo) * ref
		extra["frame"] = TextFrame.BOX
		extra["box_w"] = maxf(box.x, TextFrame.MIN_BOX * 4.0)
		extra["box_h"] = maxf(box.y, TextFrame.MIN_BOX * 4.0)
		origin = lo
	var pos: Vector2 = origin - Vector2(float(s.width), float(s.height)) * 0.5
	var made: String = Verbs.new_title_clip(d, s, target_track, s.playhead, "", 5.0, extra, {"pos": AnimProp.make([pos.x, pos.y])})
	if made.is_empty():
		Events.toast("No room for a title at the playhead")
		return false
	var c: Clip = s.clip_by_id(made)
	if c == null:
		return false
	var steps: int = d.undo.current_index()
	load("res://modules/core_panels/edit_commands.gd").call("show_panel", "effect_controls")
	if Session.tool_id == "type":
		Session.set_tool("select")
	if not begin(panel, made, 0):
		return false
	made_here = true
	made_undo = steps
	_text_before = ""
	return true


func draw(ci: CanvasItem, pic: Rect2, panel: Object) -> void:
	if not press.is_empty() and bool(press.get("dragged", false)):
		var a: Vector2 = press["at"]
		var b: Vector2 = press["now"]
		var r: Rect2 = Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())
		ci.draw_rect(r, DRAG_INK, false, 1.0)
	if not editing():
		return
	var t: Dictionary = target(panel)
	if t.is_empty():
		return
	var layout: Dictionary = t["layout"]
	var size: Vector2 = t["size"]
	var pad: float = FRAME_PAD * size.y / 1080.0
	var fr: Rect2 = frame_rect(t)
	if not TextFrame.is_box(t["props"]):
		fr = fr.grow(pad)
	_poly(ci, panel, pic, t, fr, FRAME_INK, false)
	var n: int = text_now(panel).length()
	caret = clampi(caret, 0, n)
	anchor = clampi(anchor, 0, n)
	for sr: Rect2 in TextGlyphs.selection_rects(layout, caret, anchor):
		_poly(ci, panel, pic, t, sr, PICK_FILL, true)
	if _blink_on and not has_selection():
		var cr: Rect2 = TextGlyphs.caret_rect(layout, caret)
		var top: Vector2 = _screen(panel, pic, t, cr.position)
		var bottom: Vector2 = _screen(panel, pic, t, cr.position + Vector2(0.0, cr.size.y))
		ci.draw_line(top + Vector2(1.0, 0.0), bottom + Vector2(1.0, 0.0), CARET_EDGE, 1.0)
		ci.draw_line(top, bottom, CARET_INK, 1.5)


func _poly(ci: CanvasItem, panel: Object, pic: Rect2, t: Dictionary, r: Rect2, col: Color, fill: bool) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		_screen(panel, pic, t, r.position),
		_screen(panel, pic, t, Vector2(r.end.x, r.position.y)),
		_screen(panel, pic, t, r.end),
		_screen(panel, pic, t, Vector2(r.position.x, r.end.y)),
	])
	if fill:
		ci.draw_colored_polygon(pts, col)
		return
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, col, 1.0, true)

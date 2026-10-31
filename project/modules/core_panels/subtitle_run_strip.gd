extends Control

signal box_picked(clip_id: String)
signal section_removed(count: int)

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Subtitles := preload("res://doc/subtitles.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const SNAP_PX := 6.0
const DRAG_MIN_PX := 3.0
const PAD_SECONDS := 0.04
const HEIGHT := 30.0
const TIP := "The boxes of this run. Drag across them to cut that part out: the run splits there and its animation follows. Click a box to edit it."

var seq_id: String = ""
var clip_id: String = ""
var _doc: Project = null
var _track_id: String = ""
var _boxes: Array[Clip] = []
var _lo: float = 0.0
var _hi: float = 1.0
var _dragging: bool = false
var _from_x: float = 0.0
var _to_x: float = 0.0


func _init() -> void:
	name = "SubtitleRunStrip"
	custom_minimum_size = Vector2(0.0, float(Tk.px(HEIGHT)))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_IBEAM
	focus_mode = Control.FOCUS_NONE
	PmUI.tip(self, TIP)
	gui_input.connect(_on_input)


func show_for(doc: Project, sequence_id: String, id: String) -> void:
	_doc = doc
	seq_id = sequence_id
	clip_id = id
	refresh()


func _seq() -> Sequence:
	if _doc == null or seq_id.is_empty():
		return null
	return _doc.sequence_by_id(seq_id)


func boxes() -> Array[Clip]:
	return _boxes


func refresh() -> void:
	_boxes = []
	_track_id = ""
	var s: Sequence = _seq()
	if s != null and not clip_id.is_empty():
		_boxes = Subtitles.strip_boxes(_doc, s, clip_id)
	if _boxes.is_empty():
		_dragging = false
		visible = false
		return
	var tr: Track = s.track_of(_boxes[0].id)
	_track_id = tr.id if tr != null else ""
	_lo = _boxes[0].start
	_hi = _boxes[0].end()
	for c: Clip in _boxes:
		_lo = minf(_lo, c.start)
		_hi = maxf(_hi, c.end())
	var pad: float = maxf(PAD_SECONDS, (_hi - _lo) * 0.02)
	_lo = maxf(_lo - pad, 0.0)
	_hi = _hi + pad
	visible = true
	queue_redraw()


func seconds_per_px() -> float:
	return (_hi - _lo) / maxf(size.x, 1.0)


func time_at(x: float) -> float:
	return _lo + clampf(x, 0.0, maxf(size.x, 1.0)) * seconds_per_px()


func x_at(t: float) -> float:
	return (t - _lo) / maxf(seconds_per_px(), 0.000001)


func box_at(x: float) -> Clip:
	var t: float = time_at(x)
	for c: Clip in _boxes:
		if t >= c.start and t < c.end():
			return c
	return null


func remove_between(from_t: float, to_t: float) -> bool:
	var s: Sequence = _seq()
	if s == null or _track_id.is_empty():
		return false
	var before: int = _boxes.size()
	var keep_id: String = clip_id
	if not Subtitles.remove_range(_doc, s, _track_id, from_t, to_t, SNAP_PX * seconds_per_px()):
		return false
	if s.clip_by_id(keep_id) == null:
		clip_id = nearest_survivor(s, minf(from_t, to_t), maxf(from_t, to_t))
	refresh()
	section_removed.emit(before - _boxes.size())
	return true


func nearest_survivor(s: Sequence, lo: float, hi: float) -> String:
	var before: String = ""
	var after: String = ""
	for c: Clip in Subtitles.lane_text_boxes(_doc, s.track_by_id(_track_id)):
		if c.end() <= lo + SNAP_PX * seconds_per_px():
			before = c.id
		elif after.is_empty() and c.start >= hi - SNAP_PX * seconds_per_px():
			after = c.id
	return before if not before.is_empty() else after


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and _dragging:
			_dragging = false
			queue_redraw()
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_dragging = true
			_from_x = mb.position.x
			_to_x = mb.position.x
			queue_redraw()
			accept_event()
			return
		if not _dragging:
			return
		_dragging = false
		_to_x = mb.position.x
		accept_event()
		if absf(_to_x - _from_x) >= DRAG_MIN_PX:
			remove_between(time_at(_from_x), time_at(_to_x))
		else:
			var hit: Clip = box_at(_to_x)
			if hit != null:
				clip_id = hit.id
				box_picked.emit(hit.id)
		queue_redraw()
		return
	if event is InputEventMouseMotion and _dragging:
		_to_x = (event as InputEventMouseMotion).position.x
		queue_redraw()
		accept_event()


func _draw() -> void:
	var h: float = size.y
	draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_field"], true)
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2(1.0, 1.0)), Tk.c["border_soft"], false, 1.0)
	var font: Font = Tk.font("body")
	var fsz: int = Tk.fs(Tk.sz("font_small"))
	for c: Clip in _boxes:
		var x0: float = x_at(c.start)
		var x1: float = x_at(c.end())
		var r: Rect2 = Rect2(Vector2(x0 + 1.0, 3.0), Vector2(maxf(x1 - x0 - 2.0, 1.0), h - 6.0))
		draw_rect(r, Tk.c["clip_title"], true)
		var current: bool = c.id == clip_id
		draw_rect(r, Tk.c["accent"] if current else Tk.c["border_text"], false, 2.0 if current else 1.0)
		var word: String = String(c.props.get("text", c.label)) if c.props.get("text", c.label) is String else c.label
		if r.size.x > 12.0 and font != null:
			PmText.draw(self, font, r, word, fsz, Tk.c["text_bright"] if current else Tk.c["text"], HORIZONTAL_ALIGNMENT_LEFT, 3.0)
	if _dragging and absf(_to_x - _from_x) >= DRAG_MIN_PX:
		var a: float = minf(_from_x, _to_x)
		var b: float = maxf(_from_x, _to_x)
		var cut: Color = Tk.c["key_negative"]
		draw_rect(Rect2(Vector2(a, 0.0), Vector2(b - a, h)), Color(cut.r, cut.g, cut.b, 0.35), true)
		draw_line(Vector2(a, 0.0), Vector2(a, h), cut, 1.0)
		draw_line(Vector2(b, 0.0), Vector2(b, h), cut, 1.0)

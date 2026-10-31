extends Control

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ViewMap := preload("res://doc/view_map.gd")
const Timecode := preload("res://doc/timecode.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const PairCmds := preload("res://doc/commands/pair_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const Verbs := preload("res://doc/verbs.gd")
const PairSyncState := preload("res://engine/pair_sync_state.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const Icons := preload("res://ui/kit/icons.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const WaveLook := preload("res://ui/timeline/wave_look.gd")
const WaveVolume := preload("res://ui/timeline/wave_volume.gd")
const WaveSheet := preload("res://ui/timeline/wave_look_sheet.gd")
const CONTROLLER_PATH := "res://modules/core_panels/pair_sync.gd"
const HEAD_W := 190.0
const BAR_H := 34.0
const RULER_H := 22.0
const PICTURE_H := 58.0
const SOUND_H := 36.0
const NONE_H := 26.0
const OVERLAP_H := 64.0
const PAD := 6.0
const DRAG_START_PX := 3.0
const CHUNK_PX := 512
const STRIP_H := 240.0
const TIER_RATES: Array[float] = [100.0, 12.5, 1.5625]
const PEAK_CHUNK_SECONDS := 120.0
const MAX_BPP := 4.0
const WAVE_FLOOR_DB := -48.0
const PREF_WAVE_LOG := "timeline.wave_log"
const TICK_STEPS: Array[float] = [0.0333, 0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0, 120.0, 300.0, 600.0, 1800.0, 3600.0]
const PASS_PREFIXES: PackedStringArray = ["play.", "nav.", "view.", "window.", "file.", "help.", "app.", "mark.", "tool."]
const PASS_IDS: PackedStringArray = ["edit.undo", "edit.redo", "clip.sync_regions", "edit.keyboard_shortcuts", "edit.preferences"]

var seq_id: String = ""
var clip_id: String = ""
var uid: String = ""
var pps: float = 40.0
var scroll_x: float = 0.0
var scroll_y: float = 0.0
var lanes: Array[Dictionary] = []
var peaks_provider: Callable = Callable()
var coverage_provider: Callable = Callable()
var last_view: int = -1
var draws: int = 0
var _heads: Array[Control] = []
var _lane_sig: String = ""
var _bar: HBoxContainer = null
var _title: Label = null
var _overlap_btn: Button = null
var _side_btn: Button = null
var _blend_btn: Button = null
var _overlay: Control = null
var _press: Dictionary = {}
var _drag: Dictionary = {}
var _scrubbing: bool = false
var _chunks: Dictionary = {}
var _chunk_looks: Dictionary = {}
var _loading: bool = false
var _retry: float = 0.0
var _warned: bool = false
var _font: Font = null
var _fs: int = 11
var _fitted: bool = false
var _wave_log: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	clip_contents = true
	gui_input.connect(_on_input)


func setup(p_seq_id: String, p_clip_id: String, p_uid: String) -> void:
	seq_id = p_seq_id
	clip_id = p_clip_id
	uid = p_uid
	_font = Tk.font("body")
	_fs = Tk.fs(Tk.sz("font_small"))
	_wave_log = bool(Prefs.get_value(PREF_WAVE_LOG)) if Prefs.is_registered(PREF_WAVE_LOG) else true
	WaveLook.listen(self)
	_build_bar()
	_overlay = _Overlay.new()
	_overlay.set("view", self)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	var st: RefCounted = PairSyncState.instance()
	if not st.is_connected("changed", _on_state_changed):
		st.connect("changed", _on_state_changed)
	if not Session.playhead_changed.is_connected(_on_playhead):
		Session.playhead_changed.connect(_on_playhead)
	if not Session.sequence_changed.is_connected(_on_sequence_changed):
		Session.sequence_changed.connect(_on_sequence_changed)
	if not Session.project_changed.is_connected(_on_project_changed):
		Session.project_changed.connect(_on_project_changed)
	var d: Project = doc()
	if d != null and not d.changed.is_connected(_on_doc_changed):
		d.changed.connect(_on_doc_changed)
	relayout()
	set_process(true)


func _exit_tree() -> void:
	var st: RefCounted = PairSyncState.instance()
	if st.is_connected("changed", _on_state_changed):
		st.disconnect("changed", _on_state_changed)
	if Session.playhead_changed.is_connected(_on_playhead):
		Session.playhead_changed.disconnect(_on_playhead)
	if Session.sequence_changed.is_connected(_on_sequence_changed):
		Session.sequence_changed.disconnect(_on_sequence_changed)
	if Session.project_changed.is_connected(_on_project_changed):
		Session.project_changed.disconnect(_on_project_changed)
	var d: Project = doc()
	if d != null and d.changed.is_connected(_on_doc_changed):
		d.changed.disconnect(_on_doc_changed)


func doc() -> Project:
	return Session.doc


func sequence() -> Sequence:
	var d: Project = doc()
	return d.sequence_by_id(seq_id) if d != null else null


func clip() -> Clip:
	var s: Sequence = sequence()
	return s.clip_by_id(clip_id) if s != null else null


func entry() -> Dictionary:
	var c: Clip = clip()
	return c.effect_by_uid(uid) if c != null else {}


func state() -> RefCounted:
	return PairSyncState.instance()


func controller() -> GDScript:
	return load(CONTROLLER_PATH)


func region_count() -> int:
	return mini(ViewMap.crop_count(entry()), ViewMap.REGION_MAX)


func lanes_top() -> float:
	return BAR_H + RULER_H


func x_of(t: float) -> float:
	return HEAD_W + (t - scroll_x) * pps


func t_of(x: float) -> float:
	return scroll_x + (x - HEAD_W) / maxf(pps, 0.000001)


func speed_abs(c: Clip) -> float:
	if c == null:
		return 1.0
	var sp: float = absf(c.static_speed())
	return sp if sp > 0.00001 else 1.0


func offset_now(view: int) -> float:
	var c: Clip = clip()
	if c == null:
		return 0.0
	return ViewMap.offset_at(entry(), view, c, Session.playhead() - c.start)


func shift_of(view: int) -> float:
	return offset_now(view) / speed_abs(clip())


func _build_bar() -> void:
	var wrap: MarginContainer = MarginContainer.new()
	wrap.name = "Bar"
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	for side: String in ["left", "right"]:
		wrap.add_theme_constant_override("margin_" + side, int(Tk.px(PAD)))
	wrap.add_theme_constant_override("margin_top", 4)
	wrap.add_theme_constant_override("margin_bottom", 4)
	add_child(wrap)
	_bar = PmUI.hbox(Tk.px(6.0))
	wrap.add_child(_bar)
	_title = PmLabel.trim("", "text_bright")
	_title.size_flags_stretch_ratio = 2.0
	_bar.add_child(_title)
	var hint: Label = PmLabel.trim("Drag a lane to move it in time. Arrows nudge a frame, Shift ten frames, Alt one millisecond.", "text_dim")
	PmUI.tip(hint, "Drag a lane to move it in time. Arrows nudge a frame, Shift ten frames, Alt one millisecond. Click a lane name to choose it, Ctrl click to choose more.")
	_bar.add_child(hint)
	_overlap_btn = PmButton.make("Overlap", "", true)
	_overlap_btn.set("quiet", true)
	PmUI.tip(_overlap_btn, "Draw the chosen lanes' sound over each other and show only those regions in the Program monitor. Choose two or more lanes first")
	_overlap_btn.pressed.connect(_on_overlap)
	_bar.add_child(_overlap_btn)
	var seg: HBoxContainer = PmUI.hbox(0)
	_side_btn = PmButton.make("Side by side", "", true)
	_side_btn.set("quiet", true)
	PmUI.tip(_side_btn, "Show the regions next to each other in the Program monitor")
	_side_btn.pressed.connect(_on_look.bind(PairSyncState.LOOK_SIDE))
	seg.add_child(_side_btn)
	_blend_btn = PmButton.make("Blended", "", true)
	_blend_btn.set("quiet", true)
	PmUI.tip(_blend_btn, "Show the overlapped regions half and half on top of each other, so a delay shows as a double picture")
	_blend_btn.pressed.connect(_on_look.bind(PairSyncState.LOOK_BLEND))
	seg.add_child(_blend_btn)
	_bar.add_child(seg)
	var fit: Button = PmButton.make("Fit")
	fit.set("quiet", true)
	PmUI.tip(fit, "Zoom to show the whole clip")
	fit.pressed.connect(fit_view)
	_bar.add_child(fit)
	var done: Button = PmButton.primary("Done")
	PmUI.tip(done, "Put the normal timeline back", "Esc")
	done.pressed.connect(_on_done)
	_bar.add_child(done)
	_sync_bar()


func _sync_bar() -> void:
	var c: Clip = clip()
	if _title != null:
		var name_: String = c.label if c != null and not c.label.is_empty() else clip_id
		_title.text = "Syncing " + name_
	var st: RefCounted = state()
	var enough: bool = (st.call("chosen_list") as PackedInt32Array).size() >= 2
	if _overlap_btn != null:
		_overlap_btn.disabled = not enough
		_overlap_btn.set_pressed_no_signal(bool(st.call("overlapping")))
	var blend: bool = int(st.get("look")) == PairSyncState.LOOK_BLEND
	if _side_btn != null:
		_side_btn.set_pressed_no_signal(not blend)
		_blend_btn.set_pressed_no_signal(blend)


func _on_overlap() -> void:
	state().call("set_overlap", _overlap_btn.button_pressed)


func _on_look(look: int) -> void:
	state().call("set_look", look)


func _on_done() -> void:
	controller().call("leave")


func _on_state_changed() -> void:
	_sync_bar()
	relayout()


func _on_playhead(_t: float) -> void:
	if _overlay != null:
		_overlay.queue_redraw()
	var any_keyed: bool = false
	var e: Dictionary = entry()
	for i: int in region_count():
		if AnimProp.is_animated(ViewMap.offset_prop(e, i)):
			any_keyed = true
	if any_keyed:
		_refresh_heads()
		queue_redraw()


func _on_sequence_changed(_id: String) -> void:
	if _id != seq_id:
		controller().call("leave")


func _on_project_changed() -> void:
	controller().call("leave")


func _on_doc_changed(kind: String) -> void:
	if kind.begins_with("live"):
		if not dragging():
			_refresh_heads()
		queue_redraw()
		return
	if clip() == null or entry().is_empty():
		controller().call("leave")
		return
	relayout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()
		if not _fitted and size.x > HEAD_W + 40.0:
			fit_view()


func fit_view() -> void:
	var c: Clip = clip()
	if c == null:
		return
	var span_w: float = maxf(size.x - HEAD_W - PAD * 4.0, 100.0)
	var most: float = 0.0
	for i: int in region_count():
		most = maxf(most, absf(shift_of(i)))
	var margin: float = maxf(0.5, most) + c.duration * 0.02
	pps = clampf(span_w / maxf(c.duration + margin * 2.0, 0.1), 0.0005, 4000.0)
	scroll_x = c.start - margin
	_fitted = size.x > HEAD_W + 40.0
	_chunks.clear()
	_chunk_looks.clear()
	_place()
	queue_redraw()


func relayout() -> void:
	var s: Sequence = sequence()
	var c: Clip = clip()
	var e: Dictionary = entry()
	lanes = []
	if s == null or c == null or e.is_empty():
		_rebuild_heads("")
		queue_redraw()
		return
	var map: Dictionary = ViewMap.of(e)
	var st: RefCounted = state()
	var y: float = 0.0
	var sig: PackedStringArray = PackedStringArray()
	if bool(st.call("overlapping")):
		lanes.append({"kind": "overlap", "view": -1, "y": y, "h": OVERLAP_H, "track": null, "clips": []})
		sig.append("o:" + str(st.call("chosen_list")))
		y += OVERLAP_H
	for i: int in region_count():
		lanes.append({"kind": "picture", "view": i, "y": y, "h": PICTURE_H, "track": null, "clips": []})
		sig.append("p" + str(i))
		y += PICTURE_H
		var sounds: Array[Dictionary] = ViewMap.view_sounds(map, s, c, i)
		if sounds.is_empty():
			lanes.append({"kind": "none", "view": i, "y": y, "h": NONE_H, "track": null, "clips": []})
			sig.append("n" + str(i))
			y += NONE_H
			continue
		for snd: Dictionary in sounds:
			var tr: Track = snd["track"]
			var clips: Array = snd["clips"]
			lanes.append({"kind": "sound", "view": i, "y": y, "h": SOUND_H, "track": tr, "clips": clips})
			var ids: PackedStringArray = PackedStringArray()
			for sc: Variant in clips:
				ids.append((sc as Clip).id)
			sig.append("s" + str(i) + ":" + tr.id + ":" + ",".join(ids))
			y += SOUND_H
	var names: PackedStringArray = ViewMap.region_names(e)
	sig.append("|".join(names))
	_rebuild_heads("#".join(sig))
	_clamp_scroll_y()
	_sync_bar()
	queue_redraw()


func content_h() -> float:
	if lanes.is_empty():
		return 0.0
	var last: Dictionary = lanes[lanes.size() - 1]
	return float(last["y"]) + float(last["h"])


func _clamp_scroll_y() -> void:
	var room: float = maxf(size.y - lanes_top(), 0.0)
	scroll_y = clampf(scroll_y, 0.0, maxf(content_h() - room, 0.0))


func lane_at(y: float) -> int:
	var cy: float = y - lanes_top() + scroll_y
	for i: int in lanes.size():
		var l: Dictionary = lanes[i]
		if cy >= float(l["y"]) and cy < float(l["y"]) + float(l["h"]):
			return i
	return -1


func lane_rect(index: int) -> Rect2:
	var l: Dictionary = lanes[index]
	return Rect2(HEAD_W, lanes_top() + float(l["y"]) - scroll_y, maxf(size.x - HEAD_W, 0.0), float(l["h"]))


func _rebuild_heads(sig: String) -> void:
	if sig == _lane_sig and _heads.size() == lanes.size():
		_refresh_heads()
		_place()
		return
	_lane_sig = sig
	for h: Control in _heads:
		PmUI.free_node(h)
	_heads = []
	var e: Dictionary = entry()
	var map: Dictionary = ViewMap.of(e)
	var names: PackedStringArray = ViewMap.region_names(e)
	for i: int in lanes.size():
		var l: Dictionary = lanes[i]
		var wrap: MarginContainer = MarginContainer.new()
		wrap.mouse_filter = Control.MOUSE_FILTER_PASS
		wrap.clip_contents = true
		wrap.add_theme_constant_override("margin_left", int(Tk.px(PAD)))
		wrap.add_theme_constant_override("margin_right", int(Tk.px(PAD)))
		var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		wrap.add_child(row)
		var kind: String = String(l["kind"])
		var view: int = int(l["view"])
		if kind == "picture":
			var eye: Button = PmButton.make("", "eye", true)
			eye.set("quiet", true)
			eye.name = "Eye"
			PmUI.tip(eye, "Hide this region from the picture and its sound from playback while syncing")
			eye.pressed.connect(_on_eye.bind(view, eye))
			row.add_child(eye)
			row.add_child(_chip(Tk.label_colour(ViewMap.colour_for(map, view))))
			var col: VBoxContainer = PmUI.vbox(0)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.alignment = BoxContainer.ALIGNMENT_CENTER
			col.mouse_filter = Control.MOUSE_FILTER_PASS
			var nm: Label = PmLabel.trim(names[view] if view < names.size() else "View " + str(view + 1), "text_bright")
			nm.mouse_filter = Control.MOUSE_FILTER_PASS
			PmUI.tip(nm, (names[view] if view < names.size() else "View " + str(view + 1)) + ". Click to choose this lane, Ctrl click to choose more")
			col.add_child(nm)
			var off: Label = PmLabel.mono("", "text_dim")
			off.name = "Offset"
			off.mouse_filter = Control.MOUSE_FILTER_PASS
			col.add_child(off)
			row.add_child(col)
		elif kind == "overlap":
			row.add_child(_chip(Tk.c["text_dim"]))
			var col2: VBoxContainer = PmUI.vbox(0)
			col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col2.alignment = BoxContainer.ALIGNMENT_CENTER
			col2.add_child(PmLabel.trim("Overlap", "text_bright"))
			var picked: PackedStringArray = PackedStringArray()
			for v: int in state().call("chosen_list"):
				picked.append(names[v] if v < names.size() else "View " + str(v + 1))
			var who: Label = PmLabel.trim(", ".join(picked), "text_dim")
			PmUI.tip(who, "Overlapping " + ", ".join(picked))
			col2.add_child(who)
			row.add_child(col2)
		elif kind == "sound":
			var tr: Track = l["track"]
			row.add_child(_gap(Tk.px(20.0)))
			var tl: Label = PmLabel.tight(tr.label, "text_dim")
			row.add_child(tl)
			var clip_names: PackedStringArray = PackedStringArray()
			for sc: Variant in l["clips"]:
				var sclip: Clip = sc
				clip_names.append(sclip.label if not sclip.label.is_empty() else sclip.id)
			var cl: Label = PmLabel.trim(", ".join(clip_names), "text_faint")
			PmUI.tip(cl, tr.label + ": " + ", ".join(clip_names))
			row.add_child(cl)
		else:
			row.add_child(_gap(Tk.px(20.0)))
			var none: Label = PmLabel.trim("No sound mapped to this view", "text_faint")
			PmUI.tip(none, "No sound mapped to this view. Tick a track under Hears in Effect Controls")
			row.add_child(none)
		add_child(wrap)
		_heads.append(wrap)
	if _overlay != null:
		move_child(_overlay, get_child_count() - 1)
	_refresh_heads()
	_place()


func _chip(col: Color) -> Control:
	var chip: ColorRect = ColorRect.new()
	chip.color = col
	chip.custom_minimum_size = Vector2(Tk.px(10.0), Tk.px(10.0))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip


func _gap(w: float) -> Control:
	var sp: Control = Control.new()
	sp.custom_minimum_size = Vector2(w, 0.0)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp


func _refresh_heads() -> void:
	var st: RefCounted = state()
	for i: int in mini(_heads.size(), lanes.size()):
		var l: Dictionary = lanes[i]
		if String(l["kind"]) != "picture":
			continue
		var view: int = int(l["view"])
		var hidden: bool = bool(st.call("is_hidden", view))
		var eye: Button = _heads[i].find_child("Eye", true, false) as Button
		if eye != null:
			eye.set_pressed_no_signal(hidden)
			eye.set("icon_name", "eye_off" if hidden else "eye")
		var off: Label = _heads[i].find_child("Offset", true, false) as Label
		if off != null:
			off.text = String(controller().call("format_offset", offset_now(view)))
		_heads[i].modulate.a = 0.45 if hidden else 1.0


func _place() -> void:
	var bar: Control = get_node_or_null("Bar")
	if bar != null:
		bar.position = Vector2.ZERO
		bar.size = Vector2(size.x, BAR_H)
	_clamp_scroll_y()
	for i: int in mini(_heads.size(), lanes.size()):
		var l: Dictionary = lanes[i]
		var y: float = lanes_top() + float(l["y"]) - scroll_y
		var h: Control = _heads[i]
		h.position = Vector2(0.0, y)
		h.size = Vector2(HEAD_W, float(l["h"]))
		h.visible = y + float(l["h"]) > lanes_top() and y < size.y
	if _overlay != null:
		_overlay.position = Vector2.ZERO
		_overlay.size = size
		_overlay.queue_redraw()


func _on_eye(view: int, eye: Button) -> void:
	state().call("set_hidden", view, eye.button_pressed)


func choose(view: int, add: bool) -> void:
	if view < 0:
		return
	last_view = view
	state().call("choose", view, add)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		_on_button(mb)
		accept_event()
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		_on_motion(mm.position)


func _on_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if not mb.pressed:
			return
		var dir: float = -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
		if mb.ctrl_pressed:
			zoom_at(mb.position.x, 1.25 if dir < 0.0 else 0.8)
		elif mb.shift_pressed or content_h() <= size.y - lanes_top():
			scroll_by_px(dir * 80.0)
		else:
			scroll_y += dir * 40.0
			_place()
			queue_redraw()
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and mb.position.y >= lanes_top() and mb.position.x >= HEAD_W:
		WaveSheet.open(self, get_global_mouse_position())
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		grab_focus()
		if mb.position.y >= BAR_H and mb.position.y < lanes_top() and mb.position.x >= HEAD_W:
			_scrubbing = true
			Session.scrub_to(maxf(t_of(mb.position.x), 0.0))
			return
		var li: int = lane_at(mb.position.y)
		if li < 0 or mb.position.y < lanes_top():
			return
		var l: Dictionary = lanes[li]
		var view: int = int(l["view"])
		if mb.position.x < HEAD_W:
			choose(view, mb.ctrl_pressed or mb.shift_pressed)
			return
		_press = {"x": mb.position.x, "view": view, "kind": String(l["kind"]), "add": mb.ctrl_pressed or mb.shift_pressed}
		return
	if _scrubbing:
		_scrubbing = false
		return
	if not _drag.is_empty():
		end_drag()
		return
	if not _press.is_empty():
		var pv: int = int(_press["view"])
		if String(_press["kind"]) != "overlap":
			choose(pv, bool(_press["add"]))
		_press = {}


func _on_motion(at: Vector2) -> void:
	if _scrubbing:
		Session.scrub_to(maxf(t_of(at.x), 0.0))
		return
	if not _drag.is_empty():
		drag_to(at.x)
		return
	if _press.is_empty():
		return
	if absf(at.x - float(_press["x"])) < DRAG_START_PX:
		return
	var view: int = int(_press["view"])
	var kind: String = String(_press["kind"])
	var start_x: float = float(_press["x"])
	_press = {}
	if kind == "overlap" or view < 0:
		return
	begin_drag(view, start_x)
	drag_to(at.x)


func begin_drag(view: int, x: float) -> void:
	var e: Dictionary = entry()
	if e.is_empty():
		return
	last_view = view
	_drag = {"view": view, "x0": x, "prop0": ViewMap.offset_prop(e, view).duplicate(true), "delta": 0.0, "sound": not ViewMap.of(e).is_empty()}


func drag_to(x: float) -> void:
	var d: Project = doc()
	var c: Clip = clip()
	if d == null or c == null or _drag.is_empty():
		return
	var view: int = int(_drag["view"])
	var delta: float = snappedf((x - float(_drag["x0"])) / maxf(pps, 0.000001) * speed_abs(c), 0.001)
	if is_equal_approx(delta, float(_drag["delta"])) and d.undo.has_live():
		return
	_drag["delta"] = delta
	var next: Dictionary = ViewMap.offset_plus(_drag["prop0"], delta)
	var cmd: Command = PairCmds.SetOffset.new(seq_id, clip_id, "effects." + uid + "." + ViewMap.offset_key(view), next, bool(_drag.get("sound", false)))
	d.undo.live(cmd)
	_refresh_heads()
	queue_redraw()


func end_drag() -> void:
	var d: Project = doc()
	var delta: float = float(_drag.get("delta", 0.0))
	_drag = {}
	if d == null or not d.undo.has_live():
		return
	if absf(delta) < 0.0000005:
		d.undo.cancel_live()
	else:
		d.undo.commit_live("Sync offset")
	_refresh_heads()
	queue_redraw()


func cancel_drag() -> void:
	var was: bool = not _drag.is_empty()
	_drag = {}
	_press = {}
	var d: Project = doc()
	if was and d != null and d.undo.has_live():
		d.undo.cancel_live()
	_refresh_heads()
	queue_redraw()


func dragging() -> bool:
	return not _drag.is_empty()


func nudge(views: PackedInt32Array, delta: float) -> bool:
	var d: Project = doc()
	var s: Sequence = sequence()
	var e: Dictionary = entry()
	if d == null or s == null or e.is_empty() or views.is_empty():
		return false
	var cmds: Array[Command] = []
	for v: int in views:
		var next: Dictionary = ViewMap.offset_plus(ViewMap.offset_prop(e, v), delta)
		cmds.append(ClipCmds.SetClipParam.new(seq_id, clip_id, "effects." + uid + "." + ViewMap.offset_key(v), next))
	var ok: bool = Verbs.run(d, "Nudge offset", cmds)
	_refresh_heads()
	queue_redraw()
	return ok


func nudge_targets() -> PackedInt32Array:
	var chosen: PackedInt32Array = state().call("chosen_list")
	if not chosen.is_empty():
		return chosen
	var out: PackedInt32Array = PackedInt32Array()
	if last_view >= 0 and last_view < region_count():
		out.append(last_view)
	return out


func handle_key(e: InputEventKey) -> bool:
	if not e.pressed:
		return false
	if e.keycode == KEY_ESCAPE:
		if dragging():
			cancel_drag()
		else:
			controller().call("leave")
		return true
	if e.keycode == KEY_LEFT or e.keycode == KEY_RIGHT:
		var targets: PackedInt32Array = nudge_targets()
		if targets.is_empty() or e.ctrl_pressed or e.meta_pressed:
			return false
		var s: Sequence = sequence()
		var frame: float = 1.0 / maxf(s.fps if s != null else 30.0, 1.0)
		var step: float = 0.001 if e.alt_pressed else (frame * 10.0 if e.shift_pressed else frame)
		nudge(targets, step if e.keycode == KEY_RIGHT else -step)
		return true
	var id: String = Cmd.find_for_key(Cmd.key_string(e), "timeline")
	if id.is_empty() or PASS_IDS.has(id):
		return false
	for prefix: String in PASS_PREFIXES:
		if id.begins_with(prefix):
			return false
	if not _warned:
		_warned = true
		Events.toast("Editing is off while syncing regions. Press Done or Escape to go back")
	return true


func zoom_at(x: float, factor: float) -> void:
	var at: float = t_of(x)
	pps = clampf(pps * factor, 0.0005, 4000.0)
	scroll_x = at - (x - HEAD_W) / pps
	_chunks.clear()
	_chunk_looks.clear()
	queue_redraw()
	_place()


func scroll_by_px(px: float) -> void:
	scroll_x += px / maxf(pps, 0.000001)
	queue_redraw()
	_place()


func _process(dt: float) -> void:
	if Session.playing and pps > 0.0:
		var ph_x: float = x_of(Session.playhead())
		if ph_x > size.x - 20.0 or ph_x < HEAD_W:
			scroll_x = Session.playhead() - 20.0 / pps
			queue_redraw()
	if _loading:
		_retry -= dt
		if _retry <= 0.0:
			_retry = 0.4
			queue_redraw()


func _draw() -> void:
	draws += 1
	_loading = false
	var full: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(full, Tk.c["bg_lane_video"], true)
	var bar_col: Color = Tk.c["bg_shell"].lerp(Color(0.62, 0.12, 0.12), 0.22)
	draw_rect(Rect2(0.0, 0.0, size.x, BAR_H), bar_col, true)
	draw_rect(Rect2(0.0, BAR_H - 1.0, size.x, 1.0), Tk.c["border"], true)
	_draw_ruler()
	var c: Clip = clip()
	var e: Dictionary = entry()
	if c == null or e.is_empty():
		return
	var map: Dictionary = ViewMap.of(e)
	var st: RefCounted = state()
	var body_clip: Rect2 = Rect2(HEAD_W, lanes_top(), maxf(size.x - HEAD_W, 0.0), maxf(size.y - lanes_top(), 0.0))
	for i: int in lanes.size():
		var r: Rect2 = lane_rect(i)
		if r.end.y < lanes_top() or r.position.y > size.y:
			continue
		var l: Dictionary = lanes[i]
		var kind: String = String(l["kind"])
		var view: int = int(l["view"])
		draw_rect(Rect2(0.0, r.position.y, HEAD_W, r.size.y), Tk.c["bg_panel"], true)
		draw_rect(r, Tk.c["bg_lane_audio"] if kind == "sound" or kind == "none" else Tk.c["bg_lane_video"], true)
		if kind == "picture" and bool(st.call("is_chosen", view)):
			draw_rect(Rect2(0.0, r.position.y, HEAD_W, r.size.y), Tk.c["glass_strong"], true)
			draw_rect(Rect2(0.0, r.position.y, 3.0, r.size.y), Tk.c["sol"], true)
		var hidden: bool = view >= 0 and bool(st.call("is_hidden", view))
		if kind == "picture":
			_draw_picture_lane(c, e, map, view, r, body_clip, hidden)
		elif kind == "sound":
			_draw_sound_lane(c, e, map, l, r, body_clip, hidden)
		elif kind == "overlap":
			_draw_overlap_lane(c, e, map, r, body_clip)
		draw_rect(Rect2(0.0, r.end.y - 1.0, size.x, 1.0), Tk.c["lane_line"], true)
	draw_rect(Rect2(HEAD_W - 1.0, lanes_top(), 1.0, size.y - lanes_top()), Tk.c["border"], true)


func _draw_ruler() -> void:
	var r: Rect2 = Rect2(HEAD_W, BAR_H, maxf(size.x - HEAD_W, 0.0), RULER_H)
	draw_rect(Rect2(0.0, BAR_H, size.x, RULER_H), Tk.c["bg_ruler"], true)
	draw_rect(Rect2(0.0, BAR_H + RULER_H - 1.0, size.x, 1.0), Tk.c["border"], true)
	var s: Sequence = sequence()
	var fps: float = s.fps if s != null else 30.0
	var step: float = TICK_STEPS[TICK_STEPS.size() - 1]
	for cand: float in TICK_STEPS:
		if cand * pps >= 90.0:
			step = cand
			break
	var t: float = floor(t_of(HEAD_W) / step) * step
	var guard: int = 0
	while guard < 400:
		guard += 1
		var x: float = x_of(t)
		if x > size.x:
			break
		if x >= HEAD_W and t >= 0.0:
			draw_rect(Rect2(x, BAR_H + RULER_H * 0.45, 1.0, RULER_H * 0.55), Tk.c["text_faint"], true)
			PmText.draw(self, _font, Rect2(x, BAR_H, minf(step * pps, r.end.x - x), RULER_H), Timecode.format(t, fps), _fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, PmText.chip_pad(), BAR_H + RULER_H * 0.5 + float(_fs) * 0.35, PmText.WHOLE)
		t += step


func _draw_block(r: Rect2, x0: float, x1: float, clip_rect: Rect2, fill: Color) -> Rect2:
	var block: Rect2 = Rect2(x0, r.position.y + 3.0, maxf(x1 - x0, 1.0), r.size.y - 6.0)
	var shown: Rect2 = block.intersection(clip_rect)
	if shown.size.x <= 0.0 or shown.size.y <= 0.0:
		return Rect2()
	draw_rect(shown, fill, true)
	return block


func _veil_outside(block: Rect2, keep0: float, keep1: float, clip_rect: Rect2) -> void:
	var left: Rect2 = Rect2(block.position.x, block.position.y, maxf(minf(keep0, block.end.x) - block.position.x, 0.0), block.size.y).intersection(clip_rect)
	if left.size.x > 0.0:
		draw_rect(left, Tk.c["veil"], true)
	var right: Rect2 = Rect2(maxf(keep1, block.position.x), block.position.y, maxf(block.end.x - maxf(keep1, block.position.x), 0.0), block.size.y).intersection(clip_rect)
	if right.size.x > 0.0:
		draw_rect(right, Tk.c["veil"], true)


func _media_handle(m: MediaItem) -> int:
	if m == null:
		return -1
	var h: Variant = Session.media_handles.get(m.id, -1)
	if typeof(h) == TYPE_INT and int(h) >= 0:
		return int(h)
	return m.handle


func _region_rect(view: int) -> Rect2:
	var raw: Variant = (entry().get("params", {}) as Dictionary).get("crops", null)
	if raw is Dictionary:
		var parsed: Variant = JSON.parse_string(String(AnimProp.static_value(raw)).strip_edges())
		if parsed is Array and view < (parsed as Array).size():
			var cr: Variant = (parsed as Array)[view]
			if cr is Dictionary and (cr as Dictionary).get("rect") is Array and ((cr as Dictionary)["rect"] as Array).size() >= 4:
				var a: Array = (cr as Dictionary)["rect"]
				return Rect2(float(a[0]), float(a[1]), maxf(float(a[2]), 0.001), maxf(float(a[3]), 0.001))
	return Rect2(0.0, 0.0, 1.0, 1.0)


func _draw_picture_lane(c: Clip, e: Dictionary, map: Dictionary, view: int, r: Rect2, clip_rect: Rect2, hidden: bool) -> void:
	var shift: float = shift_of(view)
	var tint: Color = Tk.label_colour(ViewMap.colour_for(map, view))
	var block: Rect2 = _draw_block(r, x_of(c.start + shift), x_of(c.end() + shift), clip_rect, Tk.c["clip_video"].lerp(tint, 0.18))
	if block.size.x <= 0.0:
		return
	var m: MediaItem = doc().media_by_id(c.media_id)
	var handle: int = _media_handle(m)
	var region: Rect2 = _region_rect(view)
	var can: bool = PurrBridge.available and handle >= 0 and m != null and m.kind == "video" and m.width > 0 and m.height > 0
	if can:
		var strip_w: float = float(maxi(2, int(round(float(m.width) * STRIP_H / float(m.height))) & ~1))
		var src: Rect2 = Rect2(region.position.x * strip_w, region.position.y * STRIP_H, region.size.x * strip_w, region.size.y * STRIP_H)
		var aspect: float = (region.size.x * float(m.width)) / maxf(region.size.y * float(m.height), 1.0)
		var fh: float = block.size.y - 2.0
		var fw: float = maxf(fh * aspect, 16.0)
		var rid: RID = get_canvas_item()
		var x: float = block.position.x
		if x < clip_rect.position.x - fw:
			x = block.position.x + floor((clip_rect.position.x - block.position.x) / fw) * fw
		var n: int = 0
		while x < minf(block.end.x, clip_rect.end.x) and n < 300:
			var x_end: float = minf(x + fw, block.end.x)
			var t_rel: float = (x - block.position.x) / maxf(pps, 0.000001)
			var media_t: float = c.source_time(c.start + t_rel)
			var tex: RID = PurrBridge.strip_frame(handle, media_t)
			var dst: Rect2 = Rect2(x, block.position.y + 1.0, x_end - x, fh).intersection(clip_rect)
			if tex.is_valid() and dst.size.x > 0.0:
				var frac: float = (dst.size.x / maxf(x_end - x, 0.0001))
				var src_part: Rect2 = Rect2(src.position.x + src.size.x * ((dst.position.x - x) / fw), src.position.y, src.size.x * frac * ((x_end - x) / fw), src.size.y)
				RenderingServer.canvas_item_add_texture_rect_region(rid, dst, tex, src_part)
			elif not tex.is_valid():
				_loading = true
			if x > block.position.x:
				draw_rect(Rect2(x, block.position.y + 1.0, 1.0, fh), Color(0.0, 0.0, 0.0, 0.35), true)
			x += fw
			n += 1
	else:
		var label_at: Vector2 = Vector2(maxf(block.position.x, clip_rect.position.x) + PAD, block.position.y + block.size.y * 0.5 + float(_fs) * 0.35)
		var names: PackedStringArray = ViewMap.region_names(e)
		PmText.draw(self, _font, block.intersection(clip_rect), names[view] if view < names.size() else "View " + str(view + 1), _fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, float(Tk.px(PAD)), label_at.y)
	_veil_outside(block, x_of(c.start), x_of(c.end()), clip_rect)
	draw_rect(block.intersection(clip_rect), tint if bool(state().call("is_chosen", view)) else Tk.c["border_soft"], false, 1.0)
	if hidden:
		draw_rect(block.intersection(clip_rect), Tk.c["veil"], true)


func _sound_offset(e: Dictionary, map: Dictionary, tr: Track, a: Clip) -> float:
	var views: PackedInt32Array = ViewMap.views_hearing(map, tr.id, a.id)
	if views.is_empty():
		return 0.0
	return offset_now(views[0])


func _draw_sound_lane(c: Clip, e: Dictionary, map: Dictionary, l: Dictionary, r: Rect2, clip_rect: Rect2, hidden: bool) -> void:
	var tr: Track = l["track"]
	for sc: Variant in l["clips"]:
		var a: Clip = sc
		var sp: float = speed_abs(a)
		var shift: float = _sound_offset(e, map, tr, a) / sp
		var block: Rect2 = _draw_block(r, x_of(a.start + shift), x_of(a.end() + shift), clip_rect, Tk.c["clip_audio"])
		if block.size.x <= 0.0:
			continue
		_draw_wave(a, block, clip_rect, _wave_base(a, tr), 1.0, tr)
		var name_x: float = maxf(block.position.x, clip_rect.position.x) + PAD
		if block.end.x - name_x > 40.0:
			PmText.draw(self, _font, block.intersection(clip_rect), a.label if not a.label.is_empty() else a.id, _fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, float(Tk.px(PAD)), block.position.y + float(_fs) + 1.0)
		_veil_outside(block, x_of(a.start), x_of(a.end()), clip_rect)
		draw_rect(block.intersection(clip_rect), Tk.c["border_soft"], false, 1.0)
		if hidden:
			draw_rect(block.intersection(clip_rect), Tk.c["veil"], true)


func _draw_overlap_lane(c: Clip, e: Dictionary, map: Dictionary, r: Rect2, clip_rect: Rect2) -> void:
	var s: Sequence = sequence()
	var inner: Rect2 = Rect2(r.position.x, r.position.y + 3.0, r.size.x, r.size.y - 6.0).intersection(clip_rect)
	if inner.size.x <= 0.0:
		return
	draw_rect(inner, Tk.c["clip_audio"], true)
	for v: int in state().call("chosen_list"):
		var col: Color = Tk.label_colour(ViewMap.colour_for(map, v))
		for snd: Dictionary in ViewMap.view_sounds(map, s, c, v):
			var tr: Track = snd["track"]
			for sc: Variant in snd["clips"]:
				var a: Clip = sc
				var shift: float = _sound_offset(e, map, tr, a) / speed_abs(a)
				var block: Rect2 = Rect2(x_of(a.start + shift), inner.position.y, x_of(a.end() + shift) - x_of(a.start + shift), inner.size.y)
				_draw_wave(a, block, clip_rect, Color(col, 0.85), 1.0, tr)


func _tier_for(a: Clip) -> int:
	var eff: float = pps / speed_abs(a)
	for tier: int in TIER_RATES.size():
		if TIER_RATES[tier] / maxf(eff, 0.000001) <= MAX_BPP:
			return tier
	return TIER_RATES.size() - 1


func _peaks(h: int, stream: int, tier: int, from_bucket: int, count: int) -> PackedByteArray:
	if peaks_provider.is_valid():
		return peaks_provider.call(h, stream, tier, from_bucket, count)
	if not PurrBridge.available or h < 0:
		return PackedByteArray()
	return PurrBridge.peaks_read(h, stream, tier, from_bucket, count)


func _covered(h: int, stream: int, media0: float, media1: float) -> bool:
	if coverage_provider.is_valid():
		return bool(coverage_provider.call(h, stream, media0, media1))
	if not PurrBridge.available or h < 0:
		return false
	var cov: PackedByteArray = PurrBridge.peaks_coverage(h, stream)
	var k0: int = int(floor(maxf(media0, 0.0) / PEAK_CHUNK_SECONDS))
	var k1: int = int(floor(maxf(media1 - 0.0001, 0.0) / PEAK_CHUNK_SECONDS))
	for k: int in range(k0, k1 + 1):
		if k >= cov.size() or cov[k] == 0:
			Session.want_peaks(h, stream, float(k) * PEAK_CHUNK_SECONDS)
			return false
	return true


func wave_chunk(a: Clip, k: int) -> PackedFloat32Array:
	var key: String = a.id + "|" + String.num(pps, 6) + "|" + str(k) + "|" + String.num(a.in_offset, 4) + "|" + String.num(a.duration, 4)
	if _chunks.has(key):
		return _chunks[key]
	var out: PackedFloat32Array = PackedFloat32Array()
	var m: MediaItem = doc().media_by_id(a.media_id)
	var h: int = _media_handle(m)
	if not peaks_provider.is_valid() and (h < 0 or not PurrBridge.available):
		return out
	var stream: int = int(a.audio.get("stream", 0.0))
	var sp: float = speed_abs(a)
	var tier: int = _tier_for(a)
	var rate: float = TIER_RATES[tier]
	var px0: float = float(k * CHUNK_PX)
	var media_lo: float = a.in_offset
	var media_hi: float = a.in_offset + a.duration * sp
	var media0: float = clampf(a.in_offset + px0 / pps * sp, media_lo, media_hi)
	var media1: float = clampf(a.in_offset + (px0 + float(CHUNK_PX)) / pps * sp, media_lo, media_hi)
	if media1 <= media0:
		_chunks[key] = out
		return out
	if not _covered(h, stream, media0, media1):
		_loading = true
		return PackedFloat32Array()
	var from_bucket: int = int(floor(media0 * rate))
	var count: int = mini(int(ceil(media1 * rate)) - from_bucket + 1, 65536)
	var bytes: PackedByteArray = _peaks(h, stream, tier, from_bucket, count)
	var n: int = bytes.size() / 2
	out.resize(CHUNK_PX * 2)
	for j: int in CHUNK_PX:
		var m0: float = a.in_offset + (px0 + float(j)) / pps * sp
		var m1: float = m0 + sp / pps
		var b0: int = int(floor(m0 * rate)) - from_bucket
		var b1: int = maxi(b0 + 1, int(ceil(m1 * rate)) - from_bucket)
		var lo: int = 0
		var hi: int = 0
		for b: int in range(maxi(b0, 0), mini(b1, n)):
			var lo_b: int = bytes[b * 2]
			var hi_b: int = bytes[b * 2 + 1]
			if lo_b == 0 and hi_b == 0:
				continue
			lo = maxi(lo, 128 - lo_b)
			hi = maxi(hi, hi_b - 128)
		out[j * 2] = _amp(lo)
		out[j * 2 + 1] = _amp(hi)
	_chunks[key] = out
	if _chunks.size() > 600:
		_chunks.clear()
		_chunk_looks.clear()
		_chunks[key] = out
	return out


func _amp(v: int) -> float:
	if v <= 0:
		return 0.0
	var lin: float = float(v) / 127.0
	if not _wave_log:
		return clampf(lin, 0.0, 1.0)
	var db: float = 20.0 * log(maxf(lin, 0.00001)) / log(10.0)
	return clampf(1.0 - db / WAVE_FLOOR_DB, 0.0, 1.0)


func _wave_base(a: Clip, tr: Track) -> Color:
	var m: MediaItem = doc().media_by_id(a.media_id) if doc() != null else null
	return WaveLook.base_colour(WaveLook.look(), a.colour, m.colour if m != null else -1, tr.colour if tr != null else -1)


func _chunk_look(a: Clip, k: int, amps: PackedFloat32Array, col: Color, sc: Dictionary, half: float, vol: Dictionary = {}) -> Dictionary:
	var key: String = a.id + "|" + String.num(pps, 6) + "|" + str(k) + "|" + String.num(a.in_offset, 4) + "|" + String.num(a.duration, 4) + "#" + WaveLook.mesh_key(WaveLook.look(), col, sc, 1.0, half) + "|" + str(WaveLook.vsig_of(vol))
	var hit: Variant = _chunk_looks.get(key, null)
	if hit is Dictionary:
		return hit
	var n: int = amps.size() / 2
	var pairs: PackedVector2Array = PackedVector2Array()
	pairs.resize(n * 2)
	for j: int in n:
		pairs[j * 2] = Vector2(float(j) + 0.5, -amps[j * 2 + 1])
		pairs[j * 2 + 1] = Vector2(float(j) + 0.5, amps[j * 2])
	var cols: Dictionary = WaveLook.columns_heard(pairs, vol, WaveLook.look(), col, sc, 1.0, half)
	if _chunk_looks.size() > 600:
		_chunk_looks.clear()
	_chunk_looks[key] = cols
	return cols


func _draw_wave(a: Clip, block: Rect2, clip_rect: Rect2, col: Color, gain: float, tr: Track = null) -> void:
	var vis0: float = maxf(block.position.x, clip_rect.position.x)
	var vis1: float = minf(block.end.x, clip_rect.end.x)
	if vis1 <= vis0:
		return
	var mid: float = block.position.y + block.size.y * 0.5
	var half: float = block.size.y * 0.5 - 3.0
	if half <= 0.0:
		return
	if WaveLook.anchor_of(WaveLook.look()) == WaveLook.GROW_MIDDLE:
		draw_line(Vector2(vis0, mid), Vector2(vis1, mid), Tk.c["wave_line"], 1.0)
	var sc: Dictionary = WaveLook.scale(_wave_log, gain, WAVE_FLOOR_DB)
	var k0: int = int(floor((vis0 - block.position.x) / float(CHUNK_PX)))
	var k1: int = int(floor((vis1 - block.position.x) / float(CHUNK_PX)))
	var env: Dictionary = WaveVolume.for_clip(doc(), sequence(), a, tr) if WaveLook.volume_on() else {}
	for k: int in range(maxi(k0, 0), k1 + 1):
		var amps: PackedFloat32Array = wave_chunk(a, k)
		if amps.is_empty():
			continue
		var base_x: float = block.position.x + float(k * CHUNK_PX)
		var styled: Dictionary = _chunk_look(a, k, amps, col, sc, half, WaveVolume.window(env, float(k * CHUNK_PX) / maxf(pps, 0.000001), 1.0 / maxf(pps, 0.000001)))
		var j0: int = clampi(int(ceil(vis0 - base_x - 0.5)), 0, CHUNK_PX)
		var j1: int = clampi(int(floor(vis1 - base_x - 0.5)) + 1, j0, CHUNK_PX)
		draw_set_transform(Vector2(base_x, mid), 0.0, Vector2(1.0, half))
		WaveLook.draw_columns(self, styled, j0, j1)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _can_drop_data(_at: Vector2, _data: Variant) -> bool:
	return false


class _Overlay:
	extends Control

	var view: Control = null

	func _draw() -> void:
		if view == null or not is_instance_valid(view):
			return
		var top: float = float(view.call("lanes_top"))
		var ph: float = Session.playhead()
		var x: float = float(view.call("x_of", ph))
		if x >= HEAD_W and x <= size.x:
			draw_rect(Rect2(x, top - 22.0, 1.0, size.y - top + 22.0), Tk.c["sol"], true)
			var head: PackedVector2Array = PackedVector2Array([Vector2(x - 5.0, top - 22.0), Vector2(x + 6.0, top - 22.0), Vector2(x + 6.0, top - 12.0), Vector2(x + 0.5, top - 6.0), Vector2(x - 5.0, top - 12.0)])
			draw_colored_polygon(head, Tk.c["sol"])
		var tint: Color = Color(0.85, 0.1, 0.1, 0.1) if Tk.is_light() else Color(0.86, 0.14, 0.14, 0.14)
		draw_rect(Rect2(Vector2.ZERO, size), tint, true)

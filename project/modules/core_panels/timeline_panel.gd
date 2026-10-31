extends "res://modules/core_panels/panel_base.gd"

const Canvas := preload("res://ui/timeline/timeline_canvas.gd")
const TimecodeField := preload("res://ui/timeline/timecode_field.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const TrackCmds := preload("res://doc/commands/track_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const TrimAnim := preload("res://ui/timeline/timeline_trim_anim.gd")
const ViewFilter := preload("res://ui/timeline/timeline_filter.gd")
const TOOLS: Array = [
	["select", "select", "Selection", "tool.select"],
	["track_select", "track_fwd", "Track select", "tool.track_fwd"],
	["ripple", "ripple", "Ripple edit", "tool.ripple"],
	["roll", "roll", "Rolling edit", "tool.roll"],
	["rate", "rate", "Rate stretch", "tool.rate"],
	["razor", "razor", "Razor", "tool.razor"],
	["slip", "slip", "Slip", "tool.slip"],
	["slide", "slide", "Slide", "tool.slide"],
	["realign", "realign", "Realign", "tool.realign"],
	["pen", "pen", "Pen", "tool.pen"],
	["hand", "hand", "Hand", "tool.hand"],
	["zoom", "zoom", "Zoom", "tool.zoom"],
	["type", "type", "Type", "tool.type"],
	["censor", "bleep", "Censor", "tool.censor"],
	["track_area", "region", "Track area", "tool.track_area"],
]
const VIEW_KEY := "timeline_view"

var canvas: Control = null
var _tabs: Control = null
var _name: Label = null
var _tc: LineEdit = null
var _tool_buttons: Dictionary = {}
var _snap_btn: Button = null
var _linked_btn: Button = null
var _inside_btn: Button = null
var _mode_btn: Button = null
var _wave_btn: Button = null
var _filter_btn: Button = null
var _hidden_btn: Button = null
var _open_ids: PackedStringArray = PackedStringArray()
var _nest_parent: Dictionary = {}
var _nest_clip: Dictionary = {}
var _nest_box: HBoxContainer = null
var _outside_btn: Button = null
var _whole_btn: Button = null
var _tab_refresh_queued: bool = false
var _speed_mode: String = "ripple"


func _build(root_: Control) -> void:
	TrimAnim.register_prefs()
	var col: VBoxContainer = column(root_)
	_tabs = PmTabs.make(true)
	_tabs.connect("tab_changed", _on_tab_changed)
	_tabs.connect("tab_closed", _on_tab_closed)
	_tabs.connect("tab_menu", _on_tab_menu)
	col.add_child(_tabs)
	var bar: HBoxContainer = header_row(col)
	_name = PmLabel.tight("", "text_bright")
	bar.add_child(_name)
	_tc = TimecodeField.make(fps())
	_tc.connect("time_entered", _on_tc_entered)
	bar.add_child(_tc)
	var tools: Container = PmToolbar.make()
	tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for spec: Array in TOOLS:
		var b: Button = PmButton.tool(String(spec[1]), "tools", true)
		b.set("icon_px", 16.0)
		b.custom_minimum_size = Vector2(float(Tk.px(26.0)), float(Tk.px(26.0)))
		PmUI.tip(b, String(spec[2]), Cmd.keys_text(String(spec[3])))
		b.pressed.connect(_on_tool_pressed.bind(String(spec[0])))
		tools.call("add_item", b, String(spec[0]), String(spec[2]))
		_tool_buttons[String(spec[0])] = b
	var sep: Control = PmUI.divider(true)
	sep.custom_minimum_size = Vector2(1.0, 18.0)
	tools.call("add_item", sep, "sep1", "")
	_snap_btn = toggle_icon("snap", "Snap", true, Cmd.keys_text("seq.snap"))
	_snap_btn.pressed.connect(_on_snap)
	tools.call("add_item", _snap_btn, "snap", "Snap")
	_linked_btn = toggle_icon("link", "Linked selection", true)
	_linked_btn.pressed.connect(_on_linked)
	tools.call("add_item", _linked_btn, "linked", "Linked selection")
	_inside_btn = quiet_icon("inside", "See inside the selected nests", Cmd.keys_text("clip.see_inside"))
	_inside_btn.pressed.connect(_on_see_inside)
	tools.call("add_item", _inside_btn, "inside", "See inside")
	_mode_btn = toggle_icon("region", "Insert mode for drops (off means overwrite)", false)
	_mode_btn.pressed.connect(_on_mode)
	tools.call("add_item", _mode_btn, "mode", "Insert mode")
	_wave_btn = quiet_icon("audio", "Waveform display")
	_wave_btn.pressed.connect(_on_wave_menu)
	tools.call("add_item", _wave_btn, "wave", "Waveforms")
	_filter_btn = toggle_icon("eye", "Timeline view: filter clips by kind, colour, name or tag, and darken", false)
	_filter_btn.pressed.connect(func() -> void: ViewFilter.open_menu(canvas, _filter_btn))
	tools.call("add_item", _filter_btn, "view_filter", "Timeline view")
	bar.add_child(tools)
	_build_nest_chips(bar)
	_hidden_btn = PmButton.make("")
	_hidden_btn.set("quiet", true)
	_hidden_btn.visible = false
	_hidden_btn.pressed.connect(_on_hidden_menu)
	bar.add_child(_hidden_btn)
	var wrench: Button = quiet_icon("wrench", "Timeline settings")
	wrench.pressed.connect(_on_settings_menu.bind(wrench))
	bar.add_child(wrench)
	col.add_child(load("res://modules/core_panels/censor_bar.gd").call("make"))
	load("res://modules/core_panels/realign_bar.gd").call("attach", _tool_buttons.get("realign", null))
	col.add_child(load("res://modules/core_panels/realign_bar.gd").call("make"))
	canvas = Canvas.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.connect("clip_double_clicked", _on_clip_double_clicked)
	canvas.connect("nest_open_requested", _on_nest_open)
	canvas.connect("view_changed", _on_view_changed)
	col.add_child(canvas)
	_sync_toggles()
	_refresh_tabs()
	_refresh_header()
	_restore_view()


func _sync_toggles() -> void:
	if canvas == null:
		return
	_snap_btn.button_pressed = bool(canvas.get("snapping"))
	_linked_btn.button_pressed = bool(canvas.get("linked_selection"))
	_mode_btn.button_pressed = bool(canvas.get("insert_mode"))
	ViewFilter.sync_button(_filter_btn, canvas)
	for id: String in _tool_buttons.keys():
		(_tool_buttons[id] as Button).button_pressed = Session.tool_id == id


func refresh_toolbar() -> void:
	_sync_toggles()


func _on_tool_pressed(id: String) -> void:
	Session.set_tool(id)
	_sync_toggles()


func _on_tool(_tool_id: String) -> void:
	_sync_toggles()


func _on_snap() -> void:
	canvas.set("snapping", _snap_btn.button_pressed)
	Prefs.set_value("timeline.snap", _snap_btn.button_pressed)


func _on_linked() -> void:
	canvas.set("linked_selection", _linked_btn.button_pressed)
	Prefs.set_value("timeline.linked_selection", _linked_btn.button_pressed)


func _on_see_inside() -> void:
	Cmd.run("clip.see_inside")


func _on_mode() -> void:
	canvas.set("insert_mode", _mode_btn.button_pressed)


func _on_wave_menu() -> void:
	var items: Array = [
		PmMenu.check_item("log", "Log dB", bool(canvas.get("wave_log"))),
		PmMenu.check_item("linear", "Linear", not bool(canvas.get("wave_log"))),
		PmMenu.separator(),
	]
	for g: float in [1.0, 1.5, 2.0, 3.0, 4.0]:
		items.append(PmMenu.check_item("gain:" + String.num(g, 1), "Gain " + str(int(g * 100.0)) + "%", absf(float(canvas.get("wave_gain")) - g) < 0.01))
	var m: Control = PmMenu.open(_wave_btn, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_wave_picked)


func _on_wave_picked(id: String) -> void:
	if id == "log":
		canvas.set("wave_log", true)
		Prefs.set_value("timeline.wave_log", true)
	elif id == "linear":
		canvas.set("wave_log", false)
		Prefs.set_value("timeline.wave_log", false)
	elif id.begins_with("gain:"):
		canvas.set("wave_gain", float(id.substr(5)))
		Prefs.set_value("timeline.wave_gain", float(id.substr(5)))
	canvas.call("invalidate_all")


func _on_hidden_menu() -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var items: Array = []
	for t: Track in s.all_tracks():
		if t.hidden:
			items.append(PmMenu.item("show:" + t.id, "Show " + t.label))
	if items.is_empty():
		return
	items.append(PmMenu.separator())
	items.append(PmMenu.item("show_all", "Show every hidden track"))
	var m: Control = PmMenu.open(_hidden_btn, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_hidden_picked)


func _on_hidden_picked(id: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var cmds: Array[Command] = []
	for t: Track in s.all_tracks():
		if t.hidden and (id == "show_all" or id == "show:" + t.id):
			cmds.append(TrackCmds.SetTrackField.new(s.id, t.id, "hidden", false))
	Verbs.run(d, "Show tracks", cmds)


func _on_settings_menu(anchor: Control) -> void:
	var follow: String = String(Prefs.get_value("timeline.follow_playhead"))
	var items: Array = [
		PmMenu.check_item("follow:page", "Follow the playhead by page", follow == "page"),
		PmMenu.check_item("follow:smooth", "Follow the playhead smoothly", follow == "smooth"),
		PmMenu.check_item("follow:off", "Do not follow the playhead", follow == "off"),
		PmMenu.separator(),
		PmMenu.check_item("animate_trims", "Animate trims to the playhead", bool(Prefs.get_value(TrimAnim.PREF_ON))),
		PmMenu.separator(),
		PmMenu.check_item("band_bottom", "Pinned band at the bottom", canvas.call("band_at_bottom")),
		PmMenu.check_item("band_top", "Pinned band at the top", not canvas.call("band_at_bottom")),
		PmMenu.separator(),
		PmMenu.check_item("pictures:strip", "Clips show a filmstrip", String(canvas.call("clip_pictures")) == "strip"),
		PmMenu.check_item("pictures:head", "Clips show the first frame only", String(canvas.call("clip_pictures")) == "head"),
		PmMenu.check_item("pictures:none", "Clips show no pictures", String(canvas.call("clip_pictures")) == "none"),
		PmMenu.separator(),
		PmMenu.item("add_video", "Add video track"),
		PmMenu.item("add_audio", "Add audio track"),
		PmMenu.item("reset_heights", "Reset every track height"),
		PmMenu.item("fit", "Zoom to the sequence", Cmd.keys_text("view.zoom_sequence")),
		PmMenu.separator(),
		PmMenu.item("seq_settings", "Sequence settings", Cmd.keys_text("seq.settings")),
		PmMenu.item("close_all_gaps", "Close all gaps", Cmd.keys_text("edit.close_all_gaps")),
	]
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_settings_picked)


func _on_settings_picked(id: String) -> void:
	if id.begins_with("follow:"):
		Prefs.set_value("timeline.follow_playhead", id.substr(7))
	elif id == "animate_trims":
		_toggle_trim_animation()
	elif id.begins_with("pictures:"):
		Prefs.set_value("timeline.clip_pictures", id.substr(9))
		canvas.queue_redraw()
	elif id == "band_bottom":
		canvas.call("set_pinned_field", "position", "bottom")
	elif id == "band_top":
		canvas.call("set_pinned_field", "position", "top")
	elif id == "add_video":
		canvas.call("add_track", "video")
	elif id == "add_audio":
		canvas.call("add_track", "audio")
	elif id == "reset_heights":
		canvas.call("_on_header_menu", "reset_all_heights", "")
	elif id == "fit":
		canvas.call("zoom_fit")
	elif id == "seq_settings":
		Cmd.run("seq.settings")
	elif id == "close_all_gaps":
		Cmd.run("edit.close_all_gaps")


func _toggle_trim_animation() -> void:
	TrimAnim.register_prefs()
	var on: bool = not bool(Prefs.get_value(TrimAnim.PREF_ON))
	Prefs.set_value(TrimAnim.PREF_ON, on)
	if not on:
		TrimAnim.finish_on(canvas)
	elif Prefs.is_registered(TrimAnim.PREF_REDUCE) and bool(Prefs.get_value(TrimAnim.PREF_REDUCE)):
		Events.toast("Reduce motion is on in Settings, so trims still jump straight to the playhead")


func _on_tc_entered(t: float) -> void:
	Session.set_playhead(t)


func _on_clip_double_clicked(clip_id: String) -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var c: Clip = s.clip_by_id(clip_id)
	if c == null:
		return
	if open_title_editor(s, c):
		return
	load("res://modules/core_panels/source_reveal.gd").call("open", _root, c.media_id, c.in_offset, c.in_offset + c.duration * maxf(c.static_speed(), 0.01))


func open_title_editor(s: Sequence, c: Clip) -> bool:
	var d: Project = doc()
	if d == null:
		return false
	var m: MediaItem = d.media_by_id(c.media_id)
	if m == null or m.kind != "title":
		return false
	var src: Object = bus().panel("source")
	if src == null or not src.has_method("open_title"):
		return false
	if not bool(src.call("open_title", s.id, c.id)):
		return false
	load("res://modules/core_panels/edit_commands.gd").call("show_panel", "source")
	return true


func _on_nest_open(sequence_id: String, clip_id: String) -> void:
	var s: Sequence = seq()
	if s != null and s.id != sequence_id:
		_nest_parent[sequence_id] = s.id
		if not clip_id.is_empty():
			_nest_clip[sequence_id] = clip_id
			Session.set_nest_context(sequence_id, s.id, clip_id)
	Session.set_sequence(sequence_id)
	_sync_nest_chips()


func open_speed_dialog() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	var c: Clip = Bus.selected_clip(s)
	if d == null or c == null:
		Events.toast("Select a clip first")
		return
	var SpeedCmds: GDScript = load("res://doc/commands/speed_cmds.gd")
	var sp: float = c.static_speed()
	var span: float = Verbs.source_span_of(s, c.id)
	var fields: Array[Dictionary] = []
	fields.append({"key": "speed", "label": "Speed (percent)", "type": "float", "default": absf(sp) * 100.0})
	fields.append({"key": "duration", "label": "Or a length to fit (seconds)", "type": "float", "default": c.duration})
	fields.append({"key": "reverse", "label": "Play it backwards", "type": "bool", "default": sp < 0.0})
	fields.append({"key": "keep_pitch", "label": "Keep pitch", "type": "bool", "default": bool(c.audio.get("keep_pitch", false))})
	fields.append({"key": "collide", "label": "When it runs into the next clip", "type": "enum", "choices": SpeedCmds.MODE_LABELS, "default": SpeedCmds.mode_index(_speed_mode)})
	fields.append({"key": "note", "type": "note", "default": _speed_note(c, span)})
	var answered: Signal = PmUI.form(_root, "Speed and duration", fields, "Apply", "Cancel")
	answered.connect(_on_speed_form.bind(c.id, c.duration, span))


func _speed_note(c: Clip, span: float) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var many: String = Verbs.speed_many_note(seq(), c.id)
	if not many.is_empty():
		parts.append(many)
	parts.append("%.2f seconds of footage in a %.2f second clip" % [span, c.duration])
	var family: int = 0
	var s: Sequence = seq()
	if s != null and not c.link_id.is_empty():
		family = s.linked(c).size() - 1
	if family > 0:
		parts.append("1 linked clip comes with it" if family == 1 else "%d linked clips come with it" % family)
	if AnimProp.is_animated(c.speed):
		parts.append("this clip's speed is keyframed and applying a flat speed here replaces that curve")
	return ", ".join(parts)


func _on_speed_form(result: Variant, clip_id: String, was_dur: float, span: float) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or s.clip_by_id(clip_id) == null:
		return
	var SpeedCmds: GDScript = load("res://doc/commands/speed_cmds.gd")
	var r: Dictionary = result
	var pct: float = absf(float(r.get("speed", 100.0)))
	var want: float = float(r.get("duration", was_dur))
	var mag: float = pct / 100.0
	if absf(want - was_dur) > 0.0005 and want > 0.0005 and span > 0.0:
		mag = span / want
	if mag < SpeedCmds.MIN_SPEED:
		mag = SpeedCmds.MIN_SPEED
	_speed_mode = SpeedCmds.mode_at(int(r.get("collide", 0)))
	var signed: float = -mag if bool(r.get("reverse", false)) else mag
	if not Verbs.set_clips_speed(d, s, Verbs.speed_targets(s, clip_id), signed, bool(r.get("keep_pitch", false)), _speed_mode, want if absf(want - was_dur) > 0.0005 and want > 0.0005 else -1.0):
		Events.toast("Nothing to change, the clip already runs at that speed")


func _refresh_header() -> void:
	var s: Sequence = seq()
	if s == null:
		_name.text = "No sequence"
		_hidden_btn.visible = false
		return
	var crumbs: String = s.label
	var parent_id: String = String(_nest_parent.get(s.id, ""))
	var d: Project = doc()
	if not parent_id.is_empty() and d != null:
		var p: Sequence = d.sequence_by_id(parent_id)
		if p != null:
			crumbs = p.label + " > " + s.label
	_name.text = crumbs
	_tc.call("set_rate", s.fps, s.drop_frame)
	_tc.call("set_time", s.playhead)
	var hidden: int = 0
	for t: Track in s.all_tracks():
		if t.hidden:
			hidden += 1
	_hidden_btn.visible = hidden > 0
	_hidden_btn.text = str(hidden) + " hidden"


func _refresh_tabs() -> void:
	_tab_refresh_queued = false
	var d: Project = doc()
	if d == null:
		_tabs.call("clear_tabs")
		_open_ids = PackedStringArray()
		return
	var s: Sequence = seq()
	if s != null and not _open_ids.has(s.id):
		_open_ids.append(s.id)
	var keep: PackedStringArray = PackedStringArray()
	for id: String in _open_ids:
		if d.sequence_by_id(id) != null:
			keep.append(id)
	_open_ids = keep
	for id: String in (_tabs.call("ids") as PackedStringArray):
		if not _open_ids.has(id):
			_tabs.call("remove_tab", id)
	for id: String in _open_ids:
		var sq: Sequence = d.sequence_by_id(id)
		var label: String = sq.label
		var parent_id: String = String(_nest_parent.get(id, ""))
		if not parent_id.is_empty():
			var p: Sequence = d.sequence_by_id(parent_id)
			if p != null:
				label = p.label + " > " + sq.label
		_tabs.call("add_tab", id, label, 1)
	if s != null:
		_tabs.call("set_active", s.id, false)


func _on_tab_changed(id: String) -> void:
	Session.set_sequence(id)


func _on_tab_menu(id: String, at: Vector2) -> void:
	load("res://modules/core_panels/sub_project_menu.gd").call("open", _tabs, doc(), id, at)


func _on_tab_closed(id: String) -> void:
	var i: int = _open_ids.find(id)
	if i >= 0:
		_open_ids.remove_at(i)
	if _open_ids.is_empty():
		var s: Sequence = seq()
		if s != null:
			_open_ids.append(s.id)
	var d: Project = doc()
	if d != null and Session.seq_id == id and not _open_ids.is_empty():
		Session.set_sequence(_open_ids[0])
	_refresh_tabs()


func _on_project_changed() -> void:
	_open_ids = PackedStringArray()
	_nest_parent = {}
	_nest_clip = {}
	Session.clear_nest_contexts()
	canvas.call("invalidate_all")
	_refresh_tabs()
	_refresh_header()
	_restore_view()
	_sync_toggles()


func _on_sequence_changed(_seq_id: String) -> void:
	canvas.call("invalidate_all")
	canvas.call("cancel_gesture")
	_refresh_tabs()
	_refresh_header()
	_restore_view()
	_sync_nest_chips()


func _on_doc_changed(kind: String) -> void:
	if kind.begins_with("live"):
		return
	canvas.call("on_doc_changed", kind)
	if kind == "timeline_view":
		ViewFilter.sync_button(_filter_btn, canvas)
	if kind == "structure" or kind == "meta":
		_refresh_header()
		if kind == "structure" and not _tab_refresh_queued:
			_tab_refresh_queued = true
			_root.get_tree().process_frame.connect(_refresh_tabs, CONNECT_ONE_SHOT)


func _on_history() -> void:
	canvas.call("on_doc_changed", "structure")


func _on_playhead(t: float) -> void:
	_tc.call("set_time", t)


func _on_view_changed() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or canvas == null or bool(canvas.get("_auto_fit")):
		return
	var raw: Variant = d.view.get(VIEW_KEY, {})
	var all: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	all[s.id] = {"pps": float(canvas.get("pps")), "scroll_x": float(canvas.get("scroll_x")), "scroll_y": float(canvas.get("scroll_y"))}
	d.view[VIEW_KEY] = all


func _restore_view() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or canvas == null:
		return
	var raw: Variant = d.view.get(VIEW_KEY, {})
	if typeof(raw) == TYPE_DICTIONARY and (raw as Dictionary).has(s.id):
		var v: Dictionary = (raw as Dictionary)[s.id]
		canvas.set("pps", clampf(float(v.get("pps", 40.0)), 0.00005, 2000.0))
		var sc: Node = canvas.get("_scroll")
		canvas.call("_sync_scroll_content")
		sc.call("scroll_to", float(v.get("scroll_x", 0.0)), float(v.get("scroll_y", 0.0)), false)
		canvas.set("scroll_x", float(sc.get("scroll_x")))
		canvas.set("scroll_y", float(sc.get("scroll_y")))
		canvas.call("user_touched_view")
		canvas.queue_redraw()
	else:
		canvas.set("_auto_fit", true)
		canvas.call("zoom_fit")


func handle_key(e: InputEventKey) -> bool:
	if not e.pressed:
		return false
	if _pair_sync_key(e):
		return true
	if e.keycode == KEY_ESCAPE:
		return bool(canvas.call("cancel_gesture"))
	return false


func accepts_global(global_pos: Vector2) -> bool:
	if _pair_sync_blocks():
		return false
	return canvas != null and bool(canvas.call("accepts_global", global_pos))


func local_drop_pos(w: Window, pos: Vector2) -> Vector2:
	if canvas == null:
		return pos
	var own: Window = canvas.get_window()
	if own == w or own == null:
		return pos
	if own.get_embedder() == w:
		return pos - Vector2(own.position)
	return Vector2(-INF, -INF)


func accepts_in(w: Window, pos: Vector2) -> bool:
	if canvas == null or w == null:
		return false
	var at: Vector2 = local_drop_pos(w, pos)
	if not is_finite(at.x):
		return false
	return accepts_global(at)


func drop_media_at(ids: PackedStringArray, global_pos: Vector2) -> void:
	if _pair_sync_blocks(true):
		return
	if canvas != null:
		canvas.call("drop_media_at", ids, global_pos)


func place_at_playhead(ids: PackedStringArray, mode: String, part: String = "both", in_t: float = -1.0, out_t: float = -1.0) -> bool:
	if _pair_sync_blocks(true):
		return false
	if canvas == null:
		return false
	return bool(canvas.call("place_at_playhead", ids, mode, part, in_t, out_t))


func on_focus(has: bool) -> void:
	super(has)
	if canvas != null:
		canvas.set("focused", has)
		canvas.queue_redraw()


func save_state() -> Dictionary:
	return {"open": Array(_open_ids), "nest_parent": _nest_parent.duplicate(), "nest_clip": _nest_clip.duplicate(), "speed_mode": _speed_mode}


func restore_state(d: Dictionary) -> void:
	var raw: Variant = d.get("open", [])
	if typeof(raw) == TYPE_ARRAY:
		_open_ids = PackedStringArray()
		for v: Variant in raw:
			_open_ids.append(String(v))
	var np: Variant = d.get("nest_parent", {})
	if typeof(np) == TYPE_DICTIONARY:
		_nest_parent = np
	_restore_nest_clips(d.get("nest_clip", {}))
	_speed_mode = String(d.get("speed_mode", _speed_mode))
	if _alive():
		_refresh_tabs()
		_refresh_header()


func _build_nest_chips(bar: HBoxContainer) -> void:
	_nest_box = PmUI.hbox(Tk.px(2.0))
	_nest_box.visible = false
	_outside_btn = PmButton.make("Hear outside", "speaker", true)
	_outside_btn.set("quiet", true)
	PmUI.tip(_outside_btn, "Hear the tracks of the sequence around this nest while you play", Cmd.keys_text("nest.hear_outside"))
	_outside_btn.pressed.connect(_on_hear_outside)
	_nest_box.add_child(_outside_btn)
	_whole_btn = PmButton.make("Show whole", "eye", true)
	_whole_btn.set("quiet", true)
	PmUI.tip(_whole_btn, "Show the sequence around this nest in the Program monitor at the same moment", Cmd.keys_text("nest.show_whole"))
	_whole_btn.pressed.connect(_on_show_whole)
	_nest_box.add_child(_whole_btn)
	bar.add_child(_nest_box)
	if not Session.nest_view_changed.is_connected(_sync_nest_chips):
		Session.nest_view_changed.connect(_sync_nest_chips)


func _sync_nest_chips() -> void:
	if _nest_box == null or not is_instance_valid(_nest_box):
		return
	var s: Sequence = seq()
	var ctx: Dictionary = Session.nest_context(s.id) if s != null else {}
	_nest_box.visible = not ctx.is_empty()
	_outside_btn.button_pressed = Session.hear_outside()
	_whole_btn.button_pressed = Session.show_whole()
	if not ctx.is_empty():
		var d: Project = doc()
		var parent: Sequence = d.sequence_by_id(String(ctx["parent"])) if d != null else null
		var where: String = parent.label if parent != null else "the parent sequence"
		PmUI.tip(_outside_btn, "Hear the other tracks of " + where + " around this nest while you play", Cmd.keys_text("nest.hear_outside"))
		PmUI.tip(_whole_btn, "Show " + where + " in the Program monitor at the same moment", Cmd.keys_text("nest.show_whole"))


func _on_hear_outside() -> void:
	Session.set_hear_outside(_outside_btn.button_pressed)


func _on_show_whole() -> void:
	Session.set_show_whole(_whole_btn.button_pressed)


func _restore_nest_clips(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	_nest_clip = (raw as Dictionary).duplicate()
	for sid: Variant in _nest_clip.keys():
		var parent_id: String = String(_nest_parent.get(String(sid), ""))
		if not parent_id.is_empty():
			Session.set_nest_context(String(sid), parent_id, String(_nest_clip[sid]))


func nest_context_ids() -> Dictionary:
	return {"parent": _nest_parent.duplicate(), "clip": _nest_clip.duplicate()}


const PairSync := preload("res://modules/core_panels/pair_sync.gd")


func _pair_sync_key(e: InputEventKey) -> bool:
	return PairSync.handle_key(e)


func _pair_sync_blocks(say: bool = false) -> bool:
	if not PairSync.blocks_drops():
		return false
	if say:
		Events.toast("Nothing can be dropped while syncing regions")
	return true

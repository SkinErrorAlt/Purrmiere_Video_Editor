extends "res://modules/core_panels/panel_base.gd"

const FrameJobs := preload("res://host/frame_jobs.gd")
const MonitorView := preload("res://modules/core_panels/monitor_view.gd")
const TimecodeField := preload("res://ui/timeline/timecode_field.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const PREF_BUTTONS := "program.transport_buttons"
const PREF_SAFE := "program.safe_margins"
const PREF_FRAME := "program.show_frame"
const PREF_APPROX := "program.approx_dot"
const PREF_QUALITY := "program.quality"
const PREF_FRAME_DIR := "program.export_frame_dir"
const PREF_SHOT_CLICK := "screenshot.click"
const PREF_SHOT_BIN := "screenshot.bin"
const SHOT_BIN := "Project_Shots"
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const MediaLoader := preload("res://modules/core_panels/media_loader.gd")
const LayerChain := preload("res://engine/layer_chain.gd")
const PmScreenWindow := preload("res://ui/kit/pm_screen_window.gd")
const ProgramScreens := preload("res://modules/core_panels/program_screens.gd")
const ProgramSelect := preload("res://modules/core_panels/program_select.gd")
const MonitorPick := preload("res://modules/core_panels/monitor_pick.gd")
const Parenting := preload("res://doc/parenting.gd")
const ParentUi := preload("res://modules/core_panels/parent_ui.gd")
const PuppetUi := preload("res://modules/core_panels/puppet_ui.gd")
const OnionSkin := preload("res://modules/core_panels/onion_skin.gd")
const MonitorPieces := preload("res://modules/core_panels/monitor_pieces.gd")
const PREF_SCREEN := "program.screen"
const PREF_DEVICE := "audio.output_device"
const PREF_SCREEN_GUIDES := "program.screen_guides"
const Backdrop := preload("res://engine/backdrop.gd")
const PREF_OVERLAY := "program.overlay."
const PREF_SHOT_FORMAT := "screenshot.format"
const FullQuality := preload("res://engine/full_quality.gd")
const PREF_OFFERED := "program.transport_offered"
const NEW_BUTTONS: PackedStringArray = ["full_quality"]
const BUTTONS: Array = [
	["add_marker", "marker", "Add marker", "marker.add"],
	["mark_in", "mark_in", "Mark in", "mark.in"],
	["mark_out", "mark_out", "Mark out", "mark.out"],
	["go_in", "to_start", "Go to in", "nav.to_in"],
	["step_back", "step_back", "Step back", "nav.step_back"],
	["play", "play", "Play or stop", "play.toggle"],
	["step_fwd", "step_fwd", "Step forward", "nav.step_fwd"],
	["go_out", "to_end", "Go to out", "nav.to_out"],
	["lift", "lift", "Lift", "edit.lift"],
	["extract", "extract", "Extract", "edit.extract"],
	["export_frame", "camera", "Screenshot (right click for options)", "file.export_frame"],
	["loop", "loop", "Loop playback", "play.loop"],
	["full_quality", FullQuality.ICON, "Full quality playback", FullQuality.COMMAND_ID],
]
const QUALITIES: Array = ["Full", "1/2", "1/4", "1/8"]
const HANDLE := 7.0
const ROTATE_REACH := 14.0
const SETTLE_SECONDS := 0.25

var view: Control = null
var _head_label: Label = null
var _tc: LineEdit = null
var _zoom: Button = null
var _quality: Button = null
var _proxy: Label = null
var _approx: Label = null
var _proxy_tag: Label = null
var _full_tag: Label = null
var _duration: Label = null
var _transport: Container = null
var _tc_row: Control = null
var _transport_row: Control = null
var _buttons: Dictionary = {}
var _settle: float = -1.0
var _gizmo: Dictionary = {}
var _gizmo_drag: Dictionary = {}
var _shot_dialog: FileDialog = null
var _region: Dictionary = {}
var _region_bar: HBoxContainer = null
var _tex_stamp: int = 0
var _space_down: bool = false
var _space_pans: int = 0
var _backdrop_dialog: FileDialog = null
var _backdrop_dialog_kind: String = ""
var _backdrop_colour_window: Control = null
var _screens: RefCounted = null
var _select: RefCounted = null
var _focus_id: String = ""


func _build(root_: Control) -> void:
	for spec: Array in [[PREF_BUTTONS, "add_marker,mark_in,mark_out,go_in,step_back,play,step_fwd,go_out,lift,extract,export_frame,loop,full_quality", {"label": "Program transport buttons", "type": "string"}], [PREF_SAFE, false, {"label": "Program safe margins", "type": "bool"}], [PREF_FRAME, true, {"label": "Program shows outside the frame", "type": "bool"}], [PREF_APPROX, true, {"label": "Program says when the picture is not the real frame yet", "type": "bool"}], [PREF_QUALITY, 0, {"label": "Program quality (0 full, 3 eighth)", "type": "int", "min": 0, "max": 3}], [PREF_FRAME_DIR, OS.get_system_dir(OS.SYSTEM_DIR_PICTURES), {"label": "Screenshot pictures folder", "type": "string"}], [PREF_SHOT_CLICK, "bin", {"label": "Screenshot button click (bin, file, clipboard)", "type": "enum", "choices": ["bin", "file", "clipboard"]}], [PREF_SHOT_BIN, "project_shots", {"label": "Screenshots go into (project_shots, current)", "type": "enum", "choices": ["project_shots", "current"]}], [PREF_SCREEN, -1, {"label": "Program sits on this screen (-1 in the app)", "type": "int", "min": -1, "max": 7}], [PREF_DEVICE, "Default", {"label": "Sound goes to this output device", "type": "string"}], [PREF_SCREEN_GUIDES, false, {"label": "Program keeps its guides when it is on a screen of its own", "type": "bool"}]]:
		if not Prefs.is_registered(String(spec[0])):
			Prefs.register(String(spec[0]), spec[1], spec[2])
	FullQuality.register(Prefs)
	var want_dev: String = String(Prefs.get_value(PREF_DEVICE))
	if not want_dev.is_empty() and want_dev != AudioServer.output_device and AudioServer.get_output_device_list().has(want_dev):
		AudioServer.output_device = want_dev
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_head_label = PmLabel.trim("Program", "text_bright")
	head.add_child(_head_label)
	head.add_child(PmUI.spacer())
	_region_bar = PmUI.hbox(Tk.px(4.0))
	_region_bar.visible = false
	var keep: Button = PmButton.primary("Keep region")
	keep.pressed.connect(end_region_placement.bind(true))
	_region_bar.add_child(keep)
	var cancel: Button = PmButton.make("Cancel")
	cancel.set("quiet", true)
	cancel.pressed.connect(end_region_placement.bind(false))
	_region_bar.add_child(cancel)
	var full: Button = quiet_icon("maximize", "Full screen while placing", "F11")
	full.pressed.connect(toggle_fullscreen)
	_region_bar.add_child(full)
	head.add_child(_region_bar)
	head.add_child(MonitorSnapButton.make_snap())
	head.add_child(RecordButton.make_record())
	var more: Button = quiet_icon("more", "Program menu")
	more.pressed.connect(_on_menu.bind(more))
	head.add_child(more)
	PmWrapRow.adopt(head, 2, 2)
	view = MonitorView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.set("empty_text", "No engine")
	view.set("safe_margins", bool(Prefs.get_value(PREF_SAFE)))
	view.set("show_frame", bool(Prefs.get_value(PREF_FRAME)))
	view.set("overlay_draw", _draw_overlay)
	view.connect("picture_input", _on_picture_input)
	_setup_tools()
	col.add_child(view)
	col.add_child(load("res://modules/core_panels/object_bar.gd").call("make"))
	load("res://modules/core_panels/effect_drop.gd").call("attach", view, Callable(self, "effect_drop_pick"), Callable(self, "effect_drop_region"))
	var bar: HBoxContainer = header_row(col)
	_tc_row = bar.get_parent()
	_tc = TimecodeField.make(fps())
	_tc.connect("time_entered", _on_tc)
	bar.add_child(_tc)
	bar.add_child(load("res://modules/core_panels/space_hold.gd").call("program_readout"))
	var zoom_choices: Array = []
	for zid: Variant in MonitorView.zoom_choice_ids():
		zoom_choices.append(PmDrop.choice(String(zid), String(MonitorView.ZOOM_LABELS[zid])))
	_zoom = PmDrop.make_drop(zoom_choices, "fit")
	_zoom.connect("changed", _on_zoom)
	bar.add_child(_zoom)
	var q_choices: Array = []
	for i: int in QUALITIES.size():
		q_choices.append(PmDrop.choice(str(i), String(QUALITIES[i])))
	_quality = PmDrop.make_drop(q_choices, str(int(Prefs.get_value(PREF_QUALITY))))
	_quality.connect("changed", _on_quality)
	bar.add_child(_quality)
	_proxy = PmLabel.dim("reduced")
	_proxy.visible = shown_quality() > 0
	bar.add_child(_proxy)
	_full_tag = PmLabel.trim(FullQuality.LABEL, "accent")
	_full_tag.name = "FullQualityTag"
	_full_tag.tooltip_text = FullQuality.TAG_TIP
	_full_tag.mouse_filter = Control.MOUSE_FILTER_PASS
	_full_tag.visible = FullQuality.is_on()
	bar.add_child(_full_tag)
	_proxy_tag = PmLabel.dim("proxy")
	_proxy_tag.tooltip_text = "Playing from proxies, the small copies. Export always reads the original. Settings, Playback to turn off."
	_proxy_tag.visible = false
	bar.add_child(_proxy_tag)
	_approx = PmLabel.trim("", "text_dim")
	_approx.visible = false
	bar.add_child(_approx)
	bar.add_child(PmUI.spacer())
	_duration = PmLabel.mono("00:00:00:00", "text_dim")
	bar.add_child(_duration)
	PmWrapRow.adopt(bar, 2, 2)
	var trow: HBoxContainer = header_row(col)
	_transport = PmToolbar.make()
	_transport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(_transport)
	_transport_row = trow.get_parent()
	Session.hold_changed.connect(_on_hold_changed)
	_offer_new_buttons()
	_rebuild_transport()
	_refresh_title()
	_apply_compositor()
	_setup_screens()
	_setup_select()
	_bind_whole_view()
	_setup_scrub()


func _on_pref_changed(key: String) -> void:
	if _screens != null and bool(_screens.call("on_pref", key)):
		return
	if _select != null and bool(_select.call("on_pref", key)):
		return
	if key.begins_with(PREF_OVERLAY) or key == PREF_SAFE:
		_sync_overlays()
		return
	if key == PREF_BUTTONS:
		_rebuild_transport()
	elif key == PREF_SAFE:
		view.set("safe_margins", bool(Prefs.get_value(PREF_SAFE)))
		view.call("redraw_overlay")
	elif key == PREF_FRAME:
		view.set("show_frame", bool(Prefs.get_value(PREF_FRAME)))
		view.call("redraw_overlay")
	elif key == PREF_APPROX:
		_refresh_state()
	elif key == PREF_QUALITY:
		var q: int = int(Prefs.get_value(PREF_QUALITY))
		if _quality != null:
			_quality.call("set_value", str(q), false)
		_apply_quality()
		_request_render(false)
	elif key == FullQuality.PREF:
		_apply_quality()
		_request_render(false)
		if fullscreen_on() and view != null:
			FullQuality.announce(view)


func _rebuild_transport() -> void:
	clear_toolbar(_transport)
	_buttons.clear()
	var shown: PackedStringArray = _shown_buttons()
	for spec: Array in BUTTONS:
		var id: String = String(spec[0])
		if not shown.has(id):
			continue
		var toggle: bool = id == "loop" or id == "full_quality"
		var b: Button = PmButton.make("", String(spec[1]), toggle)
		b.set("quiet", true)
		PmUI.tip(b, String(spec[2]), Cmd.keys_text(String(spec[3])))
		b.pressed.connect(_on_transport.bind(id))
		if id == "export_frame":
			b.gui_input.connect(_on_shot_input.bind(b))
		_transport.call("add_item", b, id, String(spec[2]))
		_buttons[id] = b
	var plus: Button = quiet_icon("plus", "Choose which buttons show")
	plus.pressed.connect(_on_button_editor.bind(plus))
	_transport.call("add_item", plus, "plus", "Buttons")
	_sync_transport()


func _shown_buttons() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for s: String in String(Prefs.get_value(PREF_BUTTONS)).split(","):
		var id: String = s.strip_edges()
		if not id.is_empty():
			out.append(id)
	return out


func _live_button(id: String) -> Button:
	var b: Variant = _buttons.get(id, null)
	if b == null or not is_instance_valid(b) or not (b is Button):
		return null
	return b


func _sync_transport() -> void:
	var play_b: Button = _live_button("play")
	if play_b != null:
		play_b.set("icon_name", "pause" if Session.playing else "play")
	var loop_b: Button = _live_button("loop")
	if loop_b != null:
		loop_b.button_pressed = Session.loop
	var fq_b: Button = _live_button("full_quality")
	if fq_b != null:
		fq_b.set_pressed_no_signal(FullQuality.is_on())


func _on_transport(id: String) -> void:
	for spec: Array in BUTTONS:
		if String(spec[0]) == id:
			Cmd.run(String(spec[3]))
			break
	_sync_transport()


func _on_button_editor(anchor: Control) -> void:
	var shown: PackedStringArray = _shown_buttons()
	var items: Array = []
	for spec: Array in BUTTONS:
		items.append(PmMenu.check_item("btn:" + String(spec[0]), String(spec[2]), shown.has(String(spec[0]))))
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_button_editor_picked)


func _on_button_editor_picked(id: String) -> void:
	if not id.begins_with("btn:"):
		return
	var bid: String = id.substr(4)
	var shown: PackedStringArray = _shown_buttons()
	var i: int = shown.find(bid)
	if i >= 0:
		shown.remove_at(i)
	else:
		var ordered: PackedStringArray = PackedStringArray()
		for spec: Array in BUTTONS:
			var sid: String = String(spec[0])
			if shown.has(sid) or sid == bid:
				ordered.append(sid)
		shown = ordered
	Prefs.set_value(PREF_BUTTONS, ",".join(shown))
	_rebuild_transport()


func _on_menu(anchor: Control) -> void:
	var items: Array = [
		PmMenu.sub_item("overlays_menu", "Overlays", _overlay_menu_items()),
		PmMenu.sub_item("backdrop_menu", "Backdrop", _backdrop_menu_items()),
		PmMenu.sub_item("onion_menu", "Onion skin", OnionSkin.menu_items()),
		PmMenu.sub_item("motion_path_menu", "Motion paths", MotionPathUi.look_items()),
		EffectHandlesUi.menu_item(),
		PmMenu.sub_item("outside_menu", "Outside the frame", _screens.call("outside_menu_items") if _screens != null else []),
		PmMenu.sub_item("outline_menu", "Transform outline", _select.call("outline_menu_items") if _select != null else []),
		PmMenu.sub_item("penshape_menu", "Shape the Pen draws", monitor_mask().call("menu_items")),
		PmMenu.sub_item("maskarm_menu", "Animate a mask shape", monitor_mask().call("arm_items", self)),
		PmMenu.check_item("approx", "Say when the picture is not the real frame yet", bool(Prefs.get_value(PREF_APPROX))),
		full_quality_item(),
		load("res://modules/core_panels/space_hold.gd").call("pitch_menu_item"),
		_whole_item(),
		PmMenu.separator(),
	]
	if _select != null:
		items.append_array(_select.call("top_menu_items"))
		items.append(PmMenu.separator())
	items.append(PmMenu.item("fullscreen", "Fullscreen", Cmd.keys_text("view.program_fullscreen")))
	if _screens != null:
		items.append_array(_screens.call("screen_menu_items"))
	var devices: PackedStringArray = output_devices()
	if devices.size() > 1:
		var picks: Array = []
		var now: String = AudioServer.output_device
		for d: String in devices:
			picks.append(PmMenu.check_item("dev_" + d, d, d == now))
		items.append(PmMenu.sub_item("device_menu", "Send the sound to", picks))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("export_frame", "Screenshot", Cmd.keys_text("file.export_frame")))
	items.append(PmMenu.item("shot_menu", "Screenshot options"))
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_menu_picked)


func _on_menu_picked(id: String) -> void:
	if id.begins_with("penshape:") or id.begins_with("maskarm:"):
		monitor_mask().call("on_menu_picked", id, self)
		return
	if _on_tools_picked(id):
		return
	if OnionSkin.on_menu(id):
		return
	if MotionPathUi.on_look_menu(id):
		return
	if EffectHandlesUi.on_menu(id):
		return
	if _select != null and bool(_select.call("on_menu_picked", id)):
		return
	if _screens != null and bool(_screens.call("on_menu_picked", id)):
		return
	if bool(load("res://modules/core_panels/space_hold.gd").call("pitch_menu_picked", id)):
		return
	if id == "show_whole":
		Session.set_show_whole(not Session.show_whole())
		return
	if id == "safe":
		view.set("safe_margins", not bool(view.get("safe_margins")))
		Prefs.set_value(PREF_SAFE, bool(view.get("safe_margins")))
		view.call("redraw_overlay")
	elif id == "frame":
		view.set("show_frame", not bool(view.get("show_frame")))
		Prefs.set_value(PREF_FRAME, bool(view.get("show_frame")))
		view.call("redraw_overlay")
	elif id == "approx":
		Prefs.set_value(PREF_APPROX, not bool(Prefs.get_value(PREF_APPROX)))
		_refresh_state()
	elif id == "fullscreen":
		toggle_fullscreen()
	elif id == "screen_back":
		bring_back()
	elif id == "screen_guides":
		Prefs.set_value(PREF_SCREEN_GUIDES, not bool(Prefs.get_value(PREF_SCREEN_GUIDES)))
		view.call("redraw_overlay")
	elif id.begins_with("screen_") and id.substr(7).is_valid_int():
		send_to_screen(int(id.substr(7)))
	elif id.begins_with("dev_"):
		set_output_device(id.substr(4))
	elif id == "export_frame":
		export_frame()
	elif id == "shot_menu":
		var b: Variant = _buttons.get("export_frame", null)
		open_shot_menu(b if b is Control else _head_label)


func _on_tc(t: float) -> void:
	Session.set_playhead(t)


func _on_zoom(id: String) -> void:
	view.call("set_zoom", id)


func _on_quality(id: String) -> void:
	var q: int = int(id)
	Prefs.set_value(PREF_QUALITY, q)
	_apply_quality()


func shown_quality() -> int:
	return FullQuality.quality_for(int(Prefs.get_value(PREF_QUALITY)))


func full_quality_item() -> Dictionary:
	return PmMenu.check_item("full_quality", "Full quality playback", FullQuality.is_on(), Cmd.keys_text(FullQuality.COMMAND_ID))


func _apply_quality() -> void:
	var comp: Node = Session.compositor
	if comp != null and comp.has_method("set_quality"):
		comp.call("set_quality", shown_quality())
	Session.set_playback_quality(int(Prefs.get_value(PREF_QUALITY)))
	_sync_quality_tags()


func _sync_quality_tags() -> void:
	var full: bool = FullQuality.is_on()
	if _proxy != null:
		_proxy.visible = shown_quality() > 0
	if _full_tag != null:
		_full_tag.visible = full
	if _quality != null:
		_quality.disabled = full
		_quality.tooltip_text = "Full quality playback is on, so the Program draws at full size" if full else ""
	if _buttons.has("full_quality"):
		(_buttons["full_quality"] as Button).set_pressed_no_signal(full)
	if _screens != null:
		_screens.call("sync_full_quality")


func _offer_new_buttons() -> void:
	if not Prefs.is_registered(PREF_OFFERED):
		Prefs.register(PREF_OFFERED, "", {"label": "Program transport buttons already offered", "type": "string"})
	var offered: PackedStringArray = String(Prefs.get_value(PREF_OFFERED)).split(",", false)
	var shown: PackedStringArray = _shown_buttons()
	var changed: bool = false
	for id: String in NEW_BUTTONS:
		if offered.has(id):
			continue
		offered.append(id)
		changed = true
		if not shown.has(id):
			shown.append(id)
			Prefs.set_value(PREF_BUTTONS, ",".join(shown))
	if changed:
		Prefs.set_value(PREF_OFFERED, ",".join(offered))


func _refresh_title() -> void:
	var s: Sequence = seq()
	_head_label.text = "Program: " + s.label if s != null else "Program"
	if s != null:
		var shown: Sequence = frame_sequence(s)
		view.call("set_frame_size", float(shown.width), float(shown.height))
		_tc.call("set_rate", s.fps, s.drop_frame)
		_tc.call("set_time", s.playhead)
		_duration.text = tc(s.duration())
	else:
		_duration.text = "00:00:00:00"
	_sync_still()


func _on_hold_changed(_id: String) -> void:
	_sync_still()


func _sync_still() -> void:
	var still: bool = Session.is_still(Session.seq_id)
	for row: Control in [_tc_row, _transport_row]:
		if row != null and is_instance_valid(row):
			row.visible = not still


func _apply_compositor() -> void:
	var comp: Node = Session.compositor
	_watch_renders(comp)
	if comp == null or not comp.has_method("texture"):
		view.call("set_texture", null)
		view.set("empty_text", "No engine")
		return
	var t: Variant = comp.call("texture")
	view.call("set_texture", t if t is Texture2D else null)
	_apply_quality()
	_request_render(false)


func _request_render(exact: bool) -> void:
	var comp: Node = Session.compositor
	if comp == null or not comp.has_method("render_time"):
		return
	_live_pending = false
	comp.call("render_time", RealignPeek.shown_time(playhead()), exact)
	_refresh_state()
	view.call("redraw_overlay")


func _refresh_state() -> void:
	var comp: Node = Session.compositor
	var approx: bool = false
	if comp != null and comp.has_method("frame_state"):
		var st: Variant = comp.call("frame_state")
		if typeof(st) == TYPE_DICTIONARY:
			approx = int((st as Dictionary).get("approx_layers", 0)) > 0 or int((st as Dictionary).get("pending", 0)) > 0
			if _proxy_tag != null:
				_proxy_tag.visible = int((st as Dictionary).get("proxy_layers", 0)) > 0
	var now: int = Time.get_ticks_msec()
	if not approx:
		_rough_since = 0
	elif _rough_since == 0:
		_rough_since = now
	var names: String = ""
	if approx and comp != null and comp.has_method("unsettled_text"):
		names = String(comp.call("unsettled_text"))
	var text: String = rough_text(approx, _rough_since, now, names)
	_approx.text = text
	_approx.visible = not text.is_empty() and bool(Prefs.get_value(PREF_APPROX))


func _on_compositor() -> void:
	_apply_compositor()


func _on_project_changed() -> void:
	_refresh_title()
	_apply_compositor()


func _on_sequence_changed(_seq_id: String) -> void:
	_refresh_title()
	_request_render(true)


func _on_doc_changed(kind: String) -> void:
	if kind.begins_with("live"):
		_on_live_edit()
		return
	if kind == "meta" or kind == "structure":
		_refresh_title()
		_settle = SETTLE_SECONDS
		_render_after = Engine.get_process_frames()
	if kind == "selection" or kind == "meta" or kind == "structure":
		view.call("redraw_overlay")


func _on_playhead(t: float) -> void:
	_tc.call("set_time", t)
	_settle = SETTLE_SECONDS
	_request_render(false)


func _on_playing(_on: bool) -> void:
	_sync_transport()
	if not Session.playing:
		_settle = SETTLE_SECONDS


func on_focus(has: bool) -> void:
	super(has)


var _render_after: int = -1


func tick(dt: float) -> void:
	if _render_after >= 0 and Engine.get_process_frames() > _render_after:
		_render_after = -1
		if _alive():
			var t0: int = Time.get_ticks_usec()
			_request_render(false)
			FrameJobs.note("program render", Time.get_ticks_usec() - t0)
	_flush_live_edit()
	_tools_tick()
	if _monitor_text_edit != null:
		_monitor_text_edit.call("tick", self)
	if _screens != null:
		_screens.call("tick", dt)
	if _select != null:
		_select.call("tick", dt)
	if _scrub != null:
		_scrub.call("tick")
	if _settle >= 0.0:
		_settle -= dt
		if _settle < 0.0 and not Session.playing:
			_request_render(true)
	_sync_transport()


func on_screen() -> int:
	return int(_screens.call("on_screen")) if _screens != null else -1


func send_to_screen(index: int) -> bool:
	if index < 0 or _screens == null:
		return false
	return bool(_screens.call("open_popout", index))


func bring_back() -> void:
	if _screens != null:
		_screens.call("close_popout")


func toggle_popout() -> void:
	if _screens != null:
		_screens.call("toggle_popout")


func popped_out() -> bool:
	return _screens != null and bool(_screens.call("popped"))


func _setup_screens() -> void:
	if _screens == null:
		_screens = ProgramScreens.new(self)
	_screens.call("setup")


const RealignPeek := preload("res://doc/realign.gd")
const ProgramScrub := preload("res://modules/core_panels/program_scrub.gd")

var _scrub: RefCounted = null


func _setup_scrub() -> void:
	if _scrub == null:
		_scrub = ProgramScrub.new()
		_scrub.set("render", _scrub_render)
	_scrub.call("attach")


func _scrub_render(exact: bool) -> void:
	if not _alive():
		return
	if exact:
		_settle = -1.0
	_request_render(exact)


var _state_comp: Node = null


func _watch_renders(comp: Node) -> void:
	if comp == _state_comp:
		return
	if _state_comp != null and is_instance_valid(_state_comp) and _state_comp.is_connected("rendered", _on_comp_rendered):
		_state_comp.disconnect("rendered", _on_comp_rendered)
	_state_comp = comp
	if comp != null and comp.has_signal("rendered") and not comp.is_connected("rendered", _on_comp_rendered):
		comp.connect("rendered", _on_comp_rendered)


func _on_comp_rendered(_t: float) -> void:
	if _alive() and _approx != null:
		_refresh_state()


func _setup_select() -> void:
	ProgramSelect.ensure_prefs(Prefs)
	if _select == null:
		_select = ProgramSelect.new(self)
	_select.call("apply_style")


func output_devices() -> PackedStringArray:
	return AudioServer.get_output_device_list()


func set_output_device(name_: String) -> bool:
	if not output_devices().has(name_):
		return false
	AudioServer.output_device = name_
	Prefs.set_value(PREF_DEVICE, name_)
	Events.notice("Program audio goes to " + name_, "Every sound this app makes uses this device until it is changed back.")
	return true


func toggle_fullscreen() -> void:
	if _screens != null:
		_screens.call("toggle_fullscreen")


func fullscreen_on() -> bool:
	return _screens != null and (bool(_screens.call("full_on")) or bool(_screens.call("popout_fullscreen")))


func export_frame() -> void:
	take_screenshot(String(Prefs.get_value(PREF_SHOT_CLICK)))


func screenshot_folder() -> String:
	var d: Project = doc()
	if d == null:
		return Prefs.data_path("Projects").path_join("Project_Shots")
	if not d.path.is_empty():
		return d.path.get_base_dir().path_join(SHOT_BIN)
	return Prefs.data_path("Projects").path_join(_safe_name(d.name)).path_join(SHOT_BIN)


static func _safe_name(text: String) -> String:
	var out: String = ""
	for ch: String in text:
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "-" or ch == "_" or ch == " ":
			out += ch
		else:
			out += "_"
	out = out.strip_edges()
	return out if not out.is_empty() else "project"


func _grab_frame() -> Image:
	var comp: Node = Session.compositor
	if comp == null or not comp.has_method("read_frame"):
		Events.warn("Screenshot needs the engine", "No compositor is attached to this session")
		return null
	var q: int = shown_quality()
	var hold: bool = comp.has_method("set_backdrop_hidden") and bool(comp.call("has_backdrop"))
	var was_hidden: bool = bool(comp.get("backdrop_hidden")) if hold else false
	var hide_now: bool = hold and not bool(Backdrop.spec_from_prefs(Prefs).get("in_export", false))
	var rerender: bool = q > 0 or (hold and hide_now != was_hidden)
	if q > 0 and comp.has_method("set_quality"):
		comp.call("set_quality", 0)
		Session.set_playback_quality(0)
	if hold:
		comp.call("set_backdrop_hidden", hide_now)
	if rerender:
		if comp.has_method("render_time"):
			comp.call("render_time", playhead(), true)
		for _i: int in 3:
			await _root.get_tree().process_frame
	var img: Variant = await comp.call("read_frame")
	if q > 0 and comp.has_method("set_quality"):
		comp.call("set_quality", q)
		Session.set_playback_quality(int(Prefs.get_value(PREF_QUALITY)))
	if hold:
		comp.call("set_backdrop_hidden", was_hidden)
	if rerender and comp.has_method("render_time"):
		comp.call("render_time", playhead(), true)
	if not (img is Image) or (img as Image).is_empty():
		Events.warn("Screenshot", "The compositor returned no picture")
		return null
	(img as Image).convert(Image.FORMAT_RGB8)
	return img


func _shot_name() -> String:
	var s: Sequence = seq()
	var stamp: String = tc(playhead()).replace(":", "-").replace(";", "-")
	return _safe_name(s.label if s != null else "frame") + "_" + stamp + "." + shot_format()


func take_screenshot(mode: String, explicit_path: String = "") -> void:
	var img: Image = await _grab_frame()
	if img == null:
		return
	if mode == "clipboard":
		copy_frame_to_clipboard(img)
		return
	var path: String = explicit_path
	if path.is_empty():
		var dir: String = screenshot_folder() if mode == "bin" else String(Prefs.get_value(PREF_FRAME_DIR))
		if dir.is_empty():
			dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
		DirAccess.make_dir_recursive_absolute(dir)
		path = dir.path_join(_shot_name())
		var n: int = 1
		while FileAccess.file_exists(path):
			n += 1
			path = dir.path_join(_shot_name().get_basename() + "_" + str(n) + "." + shot_format())
	var err: Error = save_frame_image(img, path)
	if err != OK:
		Events.error("Could not save the screenshot", path)
		return
	var actions: Array = [{"label": "Show file", "icon": "folder", "call": _show_in_explorer.bind(path)}]
	if mode == "bin":
		var media_id: String = _add_shot_to_bin(path)
		if not media_id.is_empty():
			actions.append({"label": "Show in bin", "icon": "grid", "primary": true, "call": _reveal_in_bin.bind(media_id)})
	Events.notice("Screenshot saved " + path.get_file(), path.get_base_dir(), actions, 3.0)


func _add_shot_to_bin(path: String) -> String:
	var d: Project = doc()
	if d == null:
		return ""
	var bin_path: String = ""
	if String(Prefs.get_value(PREF_SHOT_BIN)) == "project_shots":
		bin_path = SHOT_BIN
		if not d.bins.has(bin_path):
			Verbs.run(d, "New bin", [MediaCmds.AddBin.new(bin_path)])
	else:
		var bp: Object = bus().panel("bin")
		if bp != null:
			bin_path = String(bp.get("folder"))
	var ids: PackedStringArray = MediaLoader.instance().import_paths(d, PackedStringArray([path]), bin_path)
	return ids[0] if not ids.is_empty() else ""


func _show_in_explorer(path: String) -> void:
	if FileAccess.file_exists(path):
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path(path), true)
	else:
		OS.shell_open(ProjectSettings.globalize_path(path.get_base_dir()))


func _reveal_in_bin(media_id: String) -> void:
	Cmd.run("window.focus_bin")
	var bp: Object = bus().panel("bin")
	if bp != null and bp.has_method("reveal"):
		bp.call("reveal", media_id)


func _on_shot_input(event: InputEvent, anchor: Control) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		anchor.accept_event()
		open_shot_menu(anchor)


func open_shot_menu(anchor: Control) -> void:
	var click: String = String(Prefs.get_value(PREF_SHOT_CLICK))
	var where: String = String(Prefs.get_value(PREF_SHOT_BIN))
	var items: Array = [
		PmMenu.item("shot:bin", "Screenshot into the bin"),
		PmMenu.item("shot:file", "Screenshot to the pictures folder"),
		PmMenu.item("shot:clipboard", "Copy frame to the clipboard"),
		PmMenu.item("shot:as", "Screenshot as..."),
		PmMenu.separator(),
		PmMenu.check_item("fmt:png", "Save as PNG", shot_format() == "png"),
		PmMenu.check_item("fmt:jpg", "Save as JPG", shot_format() == "jpg"),
		PmMenu.separator(),
		PmMenu.item("open_folder", "Open the screenshots folder"),
		PmMenu.separator(),
		PmMenu.check_item("click:bin", "Click puts it in the bin", click == "bin"),
		PmMenu.check_item("click:file", "Click saves to the pictures folder", click == "file"),
		PmMenu.check_item("click:clipboard", "Click copies to the clipboard", click == "clipboard"),
		PmMenu.separator(),
		PmMenu.check_item("bin:project_shots", "Bin: " + SHOT_BIN, where == "project_shots"),
		PmMenu.check_item("bin:current", "Bin: the one that is open", where == "current"),
	]
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_shot_menu_picked)


func _on_shot_menu_picked(id: String) -> void:
	if id == "shot:as":
		if _shot_dialog == null:
			_shot_dialog = FileDialog.new()
			_shot_dialog.access = FileDialog.ACCESS_FILESYSTEM
			_shot_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			_shot_dialog.use_native_dialog = true
			_shot_dialog.file_selected.connect(_on_shot_dialog)
			_root.add_child(_shot_dialog)
		_shot_dialog.filters = PackedStringArray(["*.jpg,*.jpeg ; JPG picture", "*.png ; PNG picture"]) if shot_format() == "jpg" else PackedStringArray(["*.png ; PNG picture", "*.jpg,*.jpeg ; JPG picture"])
		_shot_dialog.current_dir = String(Prefs.get_value(PREF_FRAME_DIR))
		_shot_dialog.current_file = _shot_name()
		_shot_dialog.popup_centered(Vector2i(900, 600))
	elif id.begins_with("shot:"):
		take_screenshot(id.substr(5))
	elif id == "open_folder":
		var dir: String = screenshot_folder()
		DirAccess.make_dir_recursive_absolute(dir)
		OS.shell_open(ProjectSettings.globalize_path(dir))
	elif id.begins_with("fmt:"):
		Prefs.set_value(PREF_SHOT_FORMAT, id.substr(4))
	elif id.begins_with("click:"):
		Prefs.set_value(PREF_SHOT_CLICK, id.substr(6))
	elif id.begins_with("bin:"):
		Prefs.set_value(PREF_SHOT_BIN, id.substr(4))


func _on_shot_dialog(path: String) -> void:
	var ext: String = path.get_extension().to_lower()
	var p: String = path if ext == "png" or ext == "jpg" or ext == "jpeg" else path + "." + shot_format()
	Prefs.set_value(PREF_FRAME_DIR, p.get_base_dir())
	take_screenshot("file", p)


func shot_format() -> String:
	if not Prefs.is_registered(PREF_SHOT_FORMAT):
		return "png"
	return "jpg" if String(Prefs.get_value(PREF_SHOT_FORMAT)) == "jpg" else "png"


static func save_frame_image(img: Image, path: String) -> Error:
	var ext: String = path.get_extension().to_lower()
	if ext == "jpg" or ext == "jpeg":
		return img.save_jpg(path, 0.92)
	return img.save_png(path)


static func image_clipboard_command(path: String, os_name: String) -> Dictionary:
	if os_name != "Windows" or path.is_empty():
		return {}
	var quoted: String = "'" + path.replace("/", "\\").replace("'", "''") + "'"
	var script: String = "Add-Type -AssemblyName System.Windows.Forms, System.Drawing; $pic = [System.Drawing.Image]::FromFile(" + quoted + "); [System.Windows.Forms.Clipboard]::SetImage($pic); $pic.Dispose()"
	return {"exe": "powershell", "args": PackedStringArray(["-NoProfile", "-NonInteractive", "-STA", "-WindowStyle", "Hidden", "-Command", script])}


func copy_frame_to_clipboard(img: Image) -> bool:
	var dir: String = OS.get_cache_dir()
	var old: DirAccess = DirAccess.open(dir)
	if old != null:
		for f: String in old.get_files():
			if f.begins_with("purrmiere_frame_") and f.ends_with(".png"):
				old.remove(f)
	var tmp: String = dir.path_join("purrmiere_frame_" + str(Time.get_ticks_msec()) + ".png")
	if img.save_png(tmp) != OK:
		Events.error("Could not copy the frame to the clipboard", "The picture could not be written to " + tmp)
		return false
	var cmd: Dictionary = image_clipboard_command(ProjectSettings.globalize_path(tmp), OS.get_name())
	var actions: Array = [{"label": "Show file", "icon": "folder", "call": _show_in_explorer.bind(tmp)}]
	if DisplayServer.has_method("clipboard_set_image"):
		DisplayServer.call("clipboard_set_image", img)
		Events.notice("Frame copied to the clipboard", tc(playhead()), actions, 3.0)
		return true
	if not cmd.is_empty() and OS.create_process(String(cmd["exe"]), cmd["args"], false) > 0:
		Events.notice("Frame copied to the clipboard", tc(playhead()), actions, 3.0)
		return true
	Events.notice("This system cannot take a picture on the clipboard, so the frame was saved instead", tmp, actions, 4.0)
	return false


func _setup_tools() -> void:
	for id: String in MonitorView.OVERLAY_IDS:
		if id != "safe" and not Prefs.is_registered(PREF_OVERLAY + id):
			Prefs.register(PREF_OVERLAY + id, false, {"label": "Program overlay: " + String(MonitorView.OVERLAY_LABELS[id]), "type": "bool"})
	if not Prefs.is_registered(PREF_SHOT_FORMAT):
		Prefs.register(PREF_SHOT_FORMAT, "png", {"label": "Screenshot file type (png, jpg)", "type": "enum", "choices": ["png", "jpg"]})
	Backdrop.ensure_prefs(Prefs)
	MonitorMask.ensure_prefs(Prefs)
	PuppetUi.register_command()
	TrackerUi.register_commands()
	ObjectUi.register_commands()
	MaskBrush.register_commands()
	var run: Node = TrackerUi.runner()
	if run != null and not run.is_connected("changed", _on_tracker_changed):
		run.connect("changed", _on_tracker_changed)
	OnionSkin.ensure_prefs()
	MotionPathUi.ensure_prefs()
	EffectHandlesUi.ensure_prefs()
	view.set("wheel_zoom", true)
	view.connect("zoom_changed", _on_view_zoom)
	_sync_overlays()


func _on_view_zoom(z: String) -> void:
	if _zoom != null:
		_zoom.call("set_value", z, false)


func overlay_pref(id: String) -> String:
	return PREF_SAFE if id == "safe" else PREF_OVERLAY + id


func _sync_overlays() -> void:
	if view == null:
		return
	for id: String in MonitorView.OVERLAY_IDS:
		var key: String = overlay_pref(id)
		view.call("set_overlay", id, Prefs.is_registered(key) and bool(Prefs.get_value(key)))
	view.call("redraw_overlay")


func toggle_overlay(id: String) -> void:
	if not MonitorView.OVERLAY_IDS.has(id):
		return
	var key: String = overlay_pref(id)
	Prefs.set_value(key, not bool(Prefs.get_value(key)))
	_sync_overlays()


func _overlay_menu_items() -> Array:
	var items: Array = []
	for id: String in MonitorView.OVERLAY_IDS:
		if id == "crop_1x1" or id == "shorts":
			items.append(PmMenu.separator())
		items.append(PmMenu.check_item("ov:" + id, String(MonitorView.OVERLAY_LABELS[id]), bool(Prefs.get_value(overlay_pref(id)))))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("ov:none", "Hide every overlay"))
	return items


func _backdrop_menu_items() -> Array:
	var spec: Dictionary = Backdrop.spec_from_prefs(Prefs)
	var now: String = String(spec.get("type", "black"))
	var items: Array = []
	for t: String in Backdrop.TYPES:
		items.append(PmMenu.check_item("bd:type:" + t, String(Backdrop.TYPE_LABELS[t]), now == t))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("bd:colour", "Choose the colour..."))
	var pic: String = String(spec.get("picture", ""))
	items.append(PmMenu.item("bd:picture", "Choose a picture..." if pic.is_empty() else "Picture: " + pic.get_file()))
	var vid: String = String(spec.get("video", ""))
	items.append(PmMenu.item("bd:video", "Choose a video..." if vid.is_empty() else "Video: " + vid.get_file()))
	var gens: Array = []
	var reg: RefCounted = _effect_registry()
	for gid: String in Backdrop.generator_ids(reg):
		var def: Dictionary = reg.call("get_def", gid) if reg != null else {}
		gens.append(PmMenu.check_item("bd:gen:" + gid, String(def.get("label", gid)), String(spec.get("generator", "")) == gid))
	if not gens.is_empty():
		items.append(PmMenu.sub_item("bd:gen_menu", "Generator effect", gens))
	var fits: Array = []
	for f: String in Backdrop.FITS:
		fits.append(PmMenu.check_item("bd:fit:" + f, String(Backdrop.FIT_LABELS[f]), String(spec.get("fit", "fill")) == f))
	items.append(PmMenu.sub_item("bd:fit_menu", "Picture and video fit", fits))
	items.append(PmMenu.separator())
	items.append(PmMenu.check_item("bd:export", "Render the backdrop into exports", bool(spec.get("in_export", false))))
	return items


func _effect_registry() -> RefCounted:
	var script: GDScript = load("res://engine/effect_registry.gd")
	return script.call("shared")


func set_backdrop_type(t: String) -> void:
	if not Backdrop.TYPES.has(t):
		return
	if t == "picture" and String(Prefs.get_value(Backdrop.PREF_PICTURE)).is_empty():
		_choose_backdrop_file("picture")
		return
	if t == "video" and String(Prefs.get_value(Backdrop.PREF_VIDEO)).is_empty():
		_choose_backdrop_file("video")
		return
	Prefs.set_value(Backdrop.PREF_TYPE, t)
	_request_render(true)


func _on_tools_picked(id: String) -> bool:
	if id.begins_with("ov:"):
		var oid: String = id.substr(3)
		if oid == "none":
			for o: String in MonitorView.OVERLAY_IDS:
				Prefs.set_value(overlay_pref(o), false)
			_sync_overlays()
		else:
			toggle_overlay(oid)
		return true
	if not id.begins_with("bd:"):
		return false
	var rest: String = id.substr(3)
	if rest.begins_with("type:"):
		set_backdrop_type(rest.substr(5))
	elif rest == "colour":
		_open_backdrop_colour()
	elif rest == "picture" or rest == "video":
		_choose_backdrop_file(rest)
	elif rest.begins_with("gen:"):
		Prefs.set_value(Backdrop.PREF_GENERATOR, rest.substr(4))
		Prefs.set_value(Backdrop.PREF_TYPE, "generator")
		_request_render(true)
	elif rest.begins_with("fit:"):
		Prefs.set_value(Backdrop.PREF_FIT, rest.substr(4))
		_request_render(true)
	elif rest == "export":
		Prefs.set_value(Backdrop.PREF_IN_EXPORT, not bool(Prefs.get_value(Backdrop.PREF_IN_EXPORT)))
	return true


func _choose_backdrop_file(kind: String) -> void:
	if _backdrop_dialog == null:
		_backdrop_dialog = FileDialog.new()
		_backdrop_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_backdrop_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_backdrop_dialog.use_native_dialog = true
		_backdrop_dialog.file_selected.connect(_on_backdrop_file)
		_root.add_child(_backdrop_dialog)
	_backdrop_dialog_kind = kind
	if kind == "picture":
		_backdrop_dialog.title = "Choose the backdrop picture"
		_backdrop_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.bmp,*.tga ; Pictures"])
	else:
		_backdrop_dialog.title = "Choose the backdrop video"
		_backdrop_dialog.filters = PackedStringArray(["*.mp4,*.mov,*.mkv,*.webm,*.avi,*.m4v,*.gif ; Videos"])
	_backdrop_dialog.popup_centered(Vector2i(900, 600))


func _on_backdrop_file(path: String) -> void:
	set_backdrop_file(_backdrop_dialog_kind, path)


func set_backdrop_file(kind: String, path: String) -> void:
	if kind == "picture":
		Prefs.set_value(Backdrop.PREF_PICTURE, path)
	elif kind == "video":
		Prefs.set_value(Backdrop.PREF_VIDEO, path)
	else:
		return
	Prefs.set_value(Backdrop.PREF_TYPE, kind)
	_request_render(true)


func _open_backdrop_colour() -> void:
	if _backdrop_colour_window != null and is_instance_valid(_backdrop_colour_window):
		_backdrop_colour_window.call("close")
	var picker: ColorPicker = ColorPicker.new()
	picker.color = Backdrop.parse_colour(String(Prefs.get_value(Backdrop.PREF_COLOUR)))
	picker.edit_alpha = false
	picker.color_changed.connect(_on_backdrop_colour)
	_backdrop_colour_window = PmWindow.open(_root, "Backdrop colour", picker, Vector2(300.0, 420.0), "program.backdrop_colour")
	if String(Prefs.get_value(Backdrop.PREF_TYPE)) != "colour":
		Prefs.set_value(Backdrop.PREF_TYPE, "colour")


func _on_backdrop_colour(col: Color) -> void:
	Prefs.set_value(Backdrop.PREF_COLOUR, "#" + col.to_html(false))
	_request_render(true)


func _pointer_over_view() -> bool:
	if view == null or not view.is_inside_tree():
		return false
	return view.get_global_rect().has_point(view.get_global_mouse_position())


func _space_key(e: InputEventKey) -> bool:
	if e.keycode != KEY_SPACE or e.ctrl_pressed or e.alt_pressed or e.shift_pressed or e.meta_pressed:
		return false
	if _space_down:
		return true
	if view == null or not bool(view.call("can_pan")) or not _pointer_over_view():
		return false
	_space_down = true
	_space_pans = int(view.get("pan_count"))
	return true


func _tools_tick() -> void:
	if view == null:
		return
	var hand: bool = Session.tool_id == "hand"
	if bool(view.get("left_pans")) != hand:
		view.set("left_pans", hand)
	if _space_down and not Input.is_key_pressed(KEY_SPACE):
		_space_down = false
		if int(view.get("pan_count")) == _space_pans and not bool(view.call("panning")):
			Cmd.run("play.toggle")


func handle_key(e: InputEventKey) -> bool:
	if not e.pressed:
		return false
	if bool(monitor_text_edit().call("handle_key", e, self)):
		return true
	if not text_editing() and bool(letter_pose().call("handle_key", e, self)):
		return true
	if _space_key(e):
		return true
	if bool(mask_brush().call("handle_key", e, self)):
		return true
	if bool(object_ui().call("handle_key", e, self)):
		return true
	if bool(tracker_ui().call("handle_key", e, self)):
		return true
	if bool(motion_path().call("handle_key", e, self)):
		return true
	if bool(monitor_handles().call("handle_key", e, self)):
		return true
	if ParentUi.whip_key(e):
		return true
	if PuppetUi.key_input(e, self):
		return true
	if bool(monitor_mask().call("handle_key", e, self)):
		return true
	if bool(monitor_text_path().call("handle_key", e, self)):
		return true
	if e.keycode == KEY_F11 and not (e.ctrl_pressed or e.alt_pressed or e.shift_pressed or e.meta_pressed):
		if not e.echo:
			toggle_fullscreen()
		return true
	if not _region.is_empty():
		if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
			end_region_placement(true)
			return true
		if e.keycode == KEY_ESCAPE:
			end_region_placement(false)
			return true
	if e.keycode == KEY_QUOTELEFT and not (e.ctrl_pressed or e.meta_pressed) and not e.shift_pressed:
		if not e.echo:
			toggle_fullscreen()
		return true
	if e.keycode == KEY_ESCAPE and fullscreen_on():
		toggle_fullscreen()
		return true
	return false


func begin_region_placement(clip_id: String, uid: String, rect: Rect2, label: String, on_done: Callable, angle: float = 0.0) -> void:
	if not _region.is_empty():
		end_region_placement(false)
	_region = {"clip_id": clip_id, "uid": uid, "rect": rect, "angle": angle, "label": label, "on_done": on_done, "drag": {}}
	LayerChain.placing_uid = uid
	if _region_bar != null:
		_region_bar.visible = true
	Events.toast("Drag on the picture to place " + label + ", Enter keeps it, Esc cancels, F11 goes full screen")
	_request_render(true)


func end_region_placement(commit: bool) -> void:
	if _region.is_empty():
		return
	var r: Dictionary = _region
	_region = {}
	LayerChain.placing_uid = ""
	if _region_bar != null:
		_region_bar.visible = false
	if commit:
		var cb: Callable = r["on_done"]
		if cb.is_valid():
			cb.call(r["rect"], float(r.get("angle", 0.0)))
	_request_render(true)
	view.call("redraw_overlay")


func placing_region() -> bool:
	return not _region.is_empty()


func _region_layer_rect() -> Rect2:
	var s: Sequence = seq()
	if s == null:
		return Rect2()
	var c: Clip = s.clip_by_id(String(_region.get("clip_id", "")))
	if c == null:
		return Rect2(0.0, 0.0, float(s.width), float(s.height))
	var lr: Rect2 = layer_rect_for(c)
	if lr.size.x <= 0.0 or lr.size.y <= 0.0:
		return Rect2(0.0, 0.0, float(s.width), float(s.height))
	return PairPlace.source_part(doc(), s, c, lr)


func _region_to_pic(pic: Rect2, rect: Rect2) -> Rect2:
	var lr: Rect2 = _region_layer_rect()
	var a: Vector2 = _to_picture(pic, lr.position + rect.position * lr.size)
	var b: Vector2 = _to_picture(pic, lr.position + rect.end * lr.size)
	return Rect2(a, b - a).abs()


func _pic_to_region(pic: Rect2, p: Vector2) -> Vector2:
	var s: Sequence = seq()
	var lr: Rect2 = _region_layer_rect()
	var k: float = pic.size.x / maxf(float(s.width), 1.0)
	var seq_p: Vector2 = (p - pic.position) / maxf(k, 0.0001)
	return Vector2(clampf((seq_p.x - lr.position.x) / maxf(lr.size.x, 1.0), 0.0, 1.0), clampf((seq_p.y - lr.position.y) / maxf(lr.size.y, 1.0), 0.0, 1.0))


func _region_angle() -> float:
	return float(_region.get("angle", 0.0))


func _region_points(pic: Rect2) -> PackedVector2Array:
	var rr: Rect2 = _region_to_pic(pic, _region["rect"])
	var mid: Vector2 = rr.get_center()
	var half: Vector2 = rr.size * 0.5
	var ang: float = deg_to_rad(_region_angle())
	var out: PackedVector2Array = PackedVector2Array()
	for sgn: Vector2 in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0), Vector2(1.0, 0.0)]:
		out.append(mid + (half * sgn).rotated(ang))
	return out


func _region_spin_point(pic: Rect2) -> Vector2:
	var pts: PackedVector2Array = _region_points(pic)
	var rr: Rect2 = _region_to_pic(pic, _region["rect"])
	var mid: Vector2 = rr.get_center()
	var up: Vector2 = (pts[4] - mid)
	if up.length() < 0.001:
		up = Vector2(0.0, -1.0)
	return pts[4] + up.normalized() * ROTATE_REACH


func _draw_region(ci: CanvasItem, pic: Rect2) -> void:
	var rr: Rect2 = _region_to_pic(pic, _region["rect"])
	var pts: PackedVector2Array = _region_points(pic)
	var dim: Color = Color(0.0, 0.0, 0.0, 0.55)
	var outer: Rect2 = Rect2(Vector2.ZERO, (ci as Control).size) if ci is Control else pic
	if absf(_region_angle()) < 0.01:
		ci.draw_rect(Rect2(outer.position, Vector2(outer.size.x, rr.position.y - outer.position.y)), dim, true)
		ci.draw_rect(Rect2(Vector2(outer.position.x, rr.end.y), Vector2(outer.size.x, outer.end.y - rr.end.y)), dim, true)
		ci.draw_rect(Rect2(Vector2(outer.position.x, rr.position.y), Vector2(rr.position.x - outer.position.x, rr.size.y)), dim, true)
		ci.draw_rect(Rect2(Vector2(rr.end.x, rr.position.y), Vector2(outer.end.x - rr.end.x, rr.size.y)), dim, true)
	else:
		ci.draw_rect(outer, Color(0.0, 0.0, 0.0, 0.35), true)
	var outline: PackedVector2Array = PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
	ci.draw_polyline(outline, Tk.c["accent"], 1.5, true)
	var h: float = HANDLE
	for i: int in 8:
		ci.draw_rect(Rect2(pts[i] - Vector2(h, h) * 0.5, Vector2(h, h)), Tk.c["accent"], true)
	var spin: Vector2 = _region_spin_point(pic)
	ci.draw_line(pts[4], spin, Tk.c["accent"], 1.0, true)
	ci.draw_arc(spin, 3.5, 0.0, TAU, 12, Tk.c["accent"], 1.5, true)
	var font: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	_draw_region_label(ci, outer, pts[0], String(_region["label"]), font, fs)


const PmText := preload("res://ui/kit/pm_text.gd")


func _draw_region_label(ci: CanvasItem, outer: Rect2, corner: Vector2, label: String, font: Font, fs: int) -> void:
	var pad: float = PmText.pad()
	var lw: float = PmText.width_of(font, label, fs)
	var lh: float = font.get_height(fs)
	var lx: float = clampf(corner.x + pad, outer.position.x + pad, maxf(outer.end.x - pad - lw, outer.position.x + pad))
	var ly: float = corner.y - pad - lh
	if ly < outer.position.y + 2.0:
		ly = corner.y + pad
	PmText.draw_in(ci, font, Rect2(lx, ly, outer.end.x - pad - lx, lh), label, fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, NAN, PmText.ELIDE, Rect2(outer.position.x, ly, outer.size.x, lh))


func _region_handle_at(pic: Rect2, p: Vector2) -> String:
	if p.distance_to(_region_spin_point(pic)) <= HANDLE + 2.0:
		return "spin"
	var pts: PackedVector2Array = _region_points(pic)
	var names: Array = ["tl", "tr", "br", "bl", "t", "b", "l", "r"]
	for i: int in names.size():
		if p.distance_to(pts[i]) <= HANDLE + 2.0:
			return String(names[i])
	var quad: PackedVector2Array = PackedVector2Array([pts[0], pts[1], pts[2], pts[3]])
	if Geometry2D.is_point_in_polygon(p, quad):
		return "move"
	return "new"


func _region_input(event: InputEvent, pic: Rect2) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			var handle: String = _region_handle_at(pic, mb.position)
			var start: Vector2 = _pic_to_region(pic, mb.position)
			_region["drag"] = {"handle": handle, "press": mb.position, "start": start, "rect": _region["rect"], "angle": _region_angle()}
			if handle == "new":
				_region["rect"] = Rect2(start, Vector2.ZERO)
		else:
			var was: Dictionary = _region["drag"]
			_region["drag"] = {}
			var r: Rect2 = (_region["rect"] as Rect2).abs()
			if r.size.x < 0.005 or r.size.y < 0.005:
				r = was.get("rect", Rect2(0.0, 0.0, 0.5, 0.5)) if String(was.get("handle", "")) == "new" else Rect2(r.position, Vector2(maxf(r.size.x, 0.05), maxf(r.size.y, 0.05)))
			_region["rect"] = r
		view.call("redraw_overlay")
		view.accept_event()
		return
	if event is InputEventMouseMotion and not (_region["drag"] as Dictionary).is_empty():
		var mm: InputEventMouseMotion = event
		var drag: Dictionary = _region["drag"]
		var handle: String = String(drag["handle"])
		var now: Vector2 = _pic_to_region(pic, mm.position)
		var start: Vector2 = drag["start"]
		var base: Rect2 = drag["rect"]
		var r: Rect2 = base
		if handle == "spin":
			var mid_pic: Vector2 = _region_to_pic(pic, base).get_center()
			var deg: float = rad_to_deg((mm.position - mid_pic).angle()) + 90.0
			if mm.ctrl_pressed:
				deg = round(deg / 15.0) * 15.0
			_region["angle"] = wrapf(deg, -180.0, 180.0)
			view.call("redraw_overlay")
			view.accept_event()
			return
		if handle == "new":
			r = Rect2(start, now - start).abs()
		elif handle == "move":
			var delta: Vector2 = now - start
			r.position = Vector2(clampf(base.position.x + delta.x, 0.0, 1.0 - base.size.x), clampf(base.position.y + delta.y, 0.0, 1.0 - base.size.y))
		else:
			var ang: float = deg_to_rad(float(drag.get("angle", 0.0)))
			var mid: Vector2 = base.get_center()
			var local_now: Vector2 = mid + (now - mid).rotated(-ang)
			var a: Vector2 = base.position
			var b: Vector2 = base.end
			if handle.contains("l"):
				a.x = local_now.x
			if handle.contains("r"):
				b.x = local_now.x
			if handle.contains("t"):
				a.y = local_now.y
			if handle.contains("b"):
				b.y = local_now.y
			r = Rect2(a, b - a).abs()
			if absf(ang) > 0.0001:
				var shift: Vector2 = (r.get_center() - mid)
				r.position += shift.rotated(ang) - shift
		if mm.shift_pressed and handle != "move":
			var side: float = maxf(r.size.x, r.size.y)
			r.size = Vector2(side, side)
		_region["rect"] = Rect2(r.position.clamp(Vector2.ZERO, Vector2.ONE), r.size.clamp(Vector2.ZERO, Vector2.ONE - r.position))
		view.call("redraw_overlay")
		view.accept_event()


func gizmo_clip() -> Clip:
	var s: Sequence = seq()
	if s == null:
		return null
	if not _focus_id.is_empty() and s.selected_clip_ids.has(_focus_id):
		var f: Clip = s.clip_by_id(_focus_id)
		if _picture_now(s, f):
			return f
	for id: String in s.selected_clip_ids:
		var c: Clip = s.clip_by_id(id)
		if _picture_now(s, c):
			return c
	return null


func _picture_now(s: Sequence, c: Clip) -> bool:
	if c == null or s.playhead < c.start or s.playhead >= c.end():
		return false
	var t: Track = s.track_of(c.id)
	return t != null and t.is_picture(c)


func layer_rect_for(c: Clip) -> Rect2:
	var s: Sequence = seq()
	if s == null or c == null:
		return Rect2()
	var comp: Node = Session.compositor
	if comp != null and comp.has_method("layer_rect") and _gizmo_drag.is_empty():
		var r: Variant = comp.call("layer_rect", c.id)
		if r is Rect2 and (r as Rect2).size.x > 0.0:
			return r
	var made: Dictionary = quad_for(c)
	var q: PackedVector2Array = made.get("quad", PackedVector2Array())
	if q.size() != 4:
		return Rect2()
	var lo: Vector2 = q[0]
	var hi: Vector2 = q[0]
	for p: Vector2 in q:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return Rect2(lo, hi - lo)


func quad_for(c: Clip) -> Dictionary:
	var s: Sequence = seq()
	if s == null or c == null:
		return {}
	var comp: Node = Session.compositor
	if comp != null and comp.has_method("layer_quad") and _gizmo_drag.is_empty():
		var q: Variant = comp.call("layer_quad", c.id)
		if q is PackedVector2Array and (q as PackedVector2Array).size() == 4:
			return {"quad": q, "pivot": comp.call("layer_pivot", c.id)}
	var d: Project = doc()
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	var base: Vector2 = PairPlace.PairLayout.picture_size(c, MonitorPick.layer_size(c, m, s, d), Vector2(float(s.width), float(s.height)))
	var wtf: Dictionary = Parenting.world_tf(c, s, s.playhead, s.fps, Parenting.token_of(d))
	var centre: Vector2 = Vector2(float(s.width), float(s.height)) * 0.5 + (wtf["pos"] as Vector2)
	return {"quad": MonitorPick.quad_from_tf(wtf, base, s), "pivot": centre}


func _to_picture(pic: Rect2, p: Vector2) -> Vector2:
	var s: Sequence = seq()
	var k: float = pic.size.x / maxf(float(s.width), 1.0)
	return pic.position + p * k


const ROUGH_AFTER_MS := 600

var _rough_since: int = 0


static func rough_text(rough: bool, since_ms: int, now_ms: int, names: String) -> String:
	if not rough:
		return ""
	if since_ms <= 0 or now_ms - since_ms < ROUGH_AFTER_MS:
		return "rough picture"
	if names.is_empty():
		return "still loading, this is not the real picture yet"
	return "still loading " + names + ", this is not the real picture yet"



func popout_handles_on() -> bool:
	return not (_screens != null and bool(_screens.call("hide_handles")))


func _clean_screen() -> bool:
	return on_screen() >= 0 and not popout_handles_on()


func _draw_overlay(ci: CanvasItem, pic: Rect2) -> void:
	if _clean_screen():
		_gizmo = {}
		view.call("hide_outline")
		return
	if not _region.is_empty():
		_gizmo = {}
		view.call("hide_outline")
		if pic.size.x > 0.0:
			_draw_region(ci, pic)
		return
	OnionSkin.draw(ci, pic, self)
	motion_path().call("draw", ci, pic, self)
	_draw_snap(ci, pic)
	monitor_handles().call("draw", ci, pic, self)
	MonitorPieces.draw(ci, pic, self)
	monitor_mask().call("draw", ci, pic, self)
	monitor_text_path().call("draw", ci, pic, self)
	ParentUi.draw(ci, pic, self)
	PuppetUi.draw(ci, pic, self)
	tracker_ui().call("draw", ci, pic, self)
	object_ui().call("draw", ci, pic, self)
	mask_brush().call("draw", ci, pic, self)
	monitor_text_edit().call("draw", ci, pic, self)
	var c: Clip = gizmo_clip()
	_gizmo = {}
	if text_editing():
		view.call("hide_outline")
		return
	if MonitorLetterPose.on and MonitorLetterPose.is_title(doc(), c):
		letter_pose().call("draw", ci, pic, self)
		view.call("hide_outline")
		return
	if c == null or pic.size.x <= 0.0:
		view.call("hide_outline")
		return
	var made: Dictionary = quad_for(c)
	var src: PackedVector2Array = made.get("quad", PackedVector2Array())
	var words: bool = _is_title(c)
	if words:
		var wq: PackedVector2Array = MonitorPick.words_quad_of_clip(c, seq(), doc(), seq().playhead)
		if wq.size() == 4:
			src = wq
	if src.size() != 4:
		view.call("hide_outline")
		return
	var corners: PackedVector2Array = PackedVector2Array()
	var middle: Vector2 = Vector2.ZERO
	for p0: Vector2 in src:
		var p1: Vector2 = _to_picture(pic, p0)
		corners.append(p1)
		middle += p1 * 0.25
	var centre: Vector2 = _to_picture(pic, made.get("pivot", Vector2.ZERO))
	var axis_x: Vector2 = (corners[1] - corners[0]).normalized()
	var axis_y: Vector2 = (corners[3] - corners[0]).normalized()
	if not outline_shown():
		view.call("hide_outline")
		_gizmo = {"clip_id": c.id, "centre": centre, "corners": corners, "rotate": PackedVector2Array(), "pic": pic, "axis_x": axis_x, "axis_y": axis_y, "shown": false}
		return
	var ink: Color = _select.call("outline_colour") if _select != null else Tk.c["accent"]
	if words:
		ink = TEXT_BOX_INK
	_draw_outlines(ci, pic, c, corners, ink)
	var rot_handles: PackedVector2Array = PackedVector2Array()
	var edges: PackedVector2Array = PackedVector2Array()
	for i: int in corners.size():
		var p: Vector2 = corners[i]
		var dir: Vector2 = (p - middle).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		rot_handles.append(p + dir * ROTATE_REACH)
		edges.append((corners[i] + corners[(i + 1) % 4]) * 0.5)
	for p2: Vector2 in corners:
		_draw_handle(ci, p2, ink)
	for p3: Vector2 in edges:
		_draw_handle(ci, p3, ink)
	_draw_anchor(ci, centre, ink)
	_gizmo = {"clip_id": c.id, "centre": centre, "corners": corners, "edges": edges, "rotate": rot_handles, "pic": pic, "axis_x": axis_x, "axis_y": axis_y, "shown": true, "words": words, "box": words and _is_box_title(c)}
	if _hover_handle == "rotate":
		_draw_rotate_cue(ci, _hover_at)
	pair_place().call("draw", ci, pic, self)


const TEXT_BOX_INK := Color(0.2, 0.56, 1.0, 1.0)
const HANDLE_FILL := Color(1.0, 1.0, 1.0, 1.0)
const ROTATE_ZONE := 22.0

var _hover_handle: String = ""
var _hover_at: Vector2 = Vector2.ZERO


func _draw_handle(ci: CanvasItem, p: Vector2, ink: Color) -> void:
	var h: float = HANDLE
	var r: Rect2 = Rect2((p - Vector2(h, h) * 0.5).round(), Vector2(h, h))
	ci.draw_rect(r, HANDLE_FILL, true)
	ci.draw_rect(r, ink, false, 1.0)


func _draw_rotate_cue(ci: CanvasItem, at: Vector2) -> void:
	var c0: Vector2 = at + Vector2(12.0, 12.0)
	ci.draw_arc(c0, 6.0, -PI * 0.95, PI * 0.35, 14, Color(0.0, 0.0, 0.0, 0.6), 3.0, true)
	ci.draw_arc(c0, 6.0, -PI * 0.95, PI * 0.35, 14, Color.WHITE, 1.5, true)
	var tip: Vector2 = c0 + Vector2(cos(PI * 0.35), sin(PI * 0.35)) * 6.0
	ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-4.0, -1.0), tip + Vector2(3.0, -3.0), tip + Vector2(0.0, 4.0)]), Color.WHITE)


func _is_title(c: Clip) -> bool:
	var d: Project = doc()
	if d == null or c == null or c.is_nest():
		return false
	var m: MediaItem = d.media_by_id(c.media_id)
	return m != null and m.kind == "title"


func title_props_now(c: Clip) -> Dictionary:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or c == null:
		return {}
	var m: MediaItem = d.media_by_id(c.media_id)
	if m == null or m.kind != "title":
		return {}
	var props: Dictionary = m.props.duplicate(true)
	var now: Dictionary = c.props_at(s.playhead - c.start, s.fps)
	for k: Variant in now.keys():
		props[k] = now[k]
	return TitleStyle.merged("title", {}, props, m.label)


func _is_box_title(c: Clip) -> bool:
	return TextFrame.is_box(title_props_now(c))


func _cursor_for(handle: String, p: Vector2) -> Control.CursorShape:
	if handle == "move":
		return Control.CURSOR_MOVE
	if handle == "rotate":
		return Control.CURSOR_CROSS
	if handle.begins_with("scale") and not _gizmo.is_empty():
		var centre: Vector2 = _gizmo["centre"]
		var v: Vector2 = p - centre
		if handle == "scale_x":
			v = _gizmo["axis_x"]
		elif handle == "scale_y":
			v = _gizmo["axis_y"]
		var a: float = fposmod(rad_to_deg(v.angle()), 180.0)
		if a < 22.5 or a >= 157.5:
			return Control.CURSOR_HSIZE
		if a < 67.5:
			return Control.CURSOR_FDIAGSIZE
		if a < 112.5:
			return Control.CURSOR_VSIZE
		return Control.CURSOR_BDIAGSIZE
	return Control.CURSOR_ARROW


func _hover(p: Vector2) -> void:
	if view == null:
		return
	var h: String = "" if text_editing() else _handle_at(p)
	if Session.tool_id == "type":
		h = ""
		view.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	elif Session.tool_id == "select" or Session.tool_id.is_empty():
		view.mouse_default_cursor_shape = _cursor_for(h, p)
	var redraw: bool = (h == "rotate") != (_hover_handle == "rotate") or (h == "rotate" and p.distance_to(_hover_at) > 0.5)
	_hover_handle = h
	_hover_at = p
	if redraw:
		view.call("redraw_overlay")


func outline_shown() -> bool:
	if bool(monitor_handles().call("hides_motion", self)):
		return false
	if _select != null and not bool(_select.call("outline_on")):
		return false
	return not (_screens != null and bool(_screens.call("hide_handles")))


func _draw_outlines(ci: CanvasItem, pic: Rect2, focus: Clip, corners: PackedVector2Array, ink: Color) -> void:
	var quads: Array[PackedVector2Array] = [corners]
	var s: Sequence = seq()
	for id: String in s.selected_clip_ids:
		if quads.size() >= OUTLINE_MAX or id == focus.id:
			continue
		var other: Clip = s.clip_by_id(id)
		if not _picture_now(s, other):
			continue
		var q: PackedVector2Array = _pick_quad(other)
		if q.size() != 4:
			continue
		var mapped: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in q:
			mapped.append(_to_picture(pic, p))
		quads.append(mapped)
	var layer: Control = view.call("outline_layer")
	if layer != null and bool(layer.call("has_style")):
		view.call("show_outline", quads)
		return
	view.call("hide_outline")
	for q: PackedVector2Array in quads:
		var closed: PackedVector2Array = q.duplicate()
		closed.append(q[0])
		ci.draw_polyline(closed, ink, 1.0, true)


func _pull(now: float, was: float) -> float:
	if absf(was) < 1.0:
		return 1.0
	return now / was


func _handle_at(p: Vector2) -> String:
	if _gizmo.is_empty():
		return ""
	var corners: PackedVector2Array = _gizmo["corners"]
	var rots: PackedVector2Array = _gizmo["rotate"]
	var edges: PackedVector2Array = _gizmo.get("edges", PackedVector2Array())
	var inside: bool = Geometry2D.is_point_in_polygon(p, corners)
	if bool(_gizmo.get("shown", true)):
		for i: int in corners.size():
			if p.distance_to(corners[i]) <= HANDLE:
				return "scale"
		for i: int in edges.size():
			if p.distance_to(edges[i]) <= HANDLE:
				return "scale_x" if i % 2 == 1 else "scale_y"
		for i: int in rots.size():
			if p.distance_to(rots[i]) <= 8.0:
				return "rotate"
		if not inside:
			for i: int in corners.size():
				if p.distance_to(corners[i]) <= ROTATE_ZONE:
					return "rotate"
	if inside:
		return "move"
	return ""


func _grab_handle_at(p: Vector2) -> bool:
	var h: String = _handle_at(p)
	return h.begins_with("scale") or h == "rotate"


func open_sample_menu(at: Vector2) -> Control:
	var take: GDScript = load("res://modules/core_panels/organizer/sample_take.gd")
	var target: Dictionary = take.call("program_target", doc(), seq())
	if target.is_empty():
		return null
	return take.call("open_menu", view, at, func(id: String) -> void:
		take.call("take", String(target["path"]), float(target["t"]), String(take.call("kind_of_pick", id)), String(target["kind"]))
	)


func _on_picture_input(event: InputEvent, pic: Rect2) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	if not _region.is_empty():
		_region_input(event, pic)
		return
	if _gizmo_drag.is_empty() and not text_editing() and bool(letter_pose().call("input", event, pic, self)):
		view.accept_event()
		return
	if _gizmo_drag.is_empty() and bool(monitor_text_edit().call("input", event, pic, self)):
		view.accept_event()
		return
	if _gizmo_drag.is_empty() and bool(mask_brush().call("input", event, pic, self)):
		return
	if _gizmo_drag.is_empty() and bool(object_ui().call("input", event, pic, self)):
		return
	if _gizmo_drag.is_empty() and bool(tracker_ui().call("input", event, pic, self)):
		return
	if _gizmo_drag.is_empty() and _motion_path_input(event, pic):
		return
	if _gizmo_drag.is_empty() and ParentUi.whip_input(event, pic, self):
		return
	if _gizmo_drag.is_empty() and PuppetUi.input(event, pic, self):
		return
	if _gizmo_drag.is_empty() and bool(monitor_mask().call("pen_input", event, pic, self)):
		return
	if _gizmo_drag.is_empty() and MonitorPieces.input(event, pic, self):
		return
	if _gizmo_drag.is_empty() and bool(monitor_handles().call("input", event, pic, self)):
		return
	if _gizmo_drag.is_empty() and bool(monitor_mask().call("input", event, pic, self)):
		return
	if _gizmo_drag.is_empty() and bool(monitor_text_path().call("input", event, pic, self)):
		return
	if _gizmo_drag.is_empty() and bool(pair_place().call("input", event, pic, self)):
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and _gizmo_drag.is_empty():
			if open_sample_menu(mb.global_position) != null:
				view.accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed and Session.tool_id == "type":
			return
		if mb.pressed and mb.double_click and not _grab_handle_at(mb.position) and _title_double_click(mb, pic):
			return
		if mb.pressed:
			var handle: String = _handle_at(mb.position)
			if mb.alt_pressed and _on_anchor(mb.position):
				handle = "anchor"
			if handle.is_empty():
				_press_pick(mb, pic)
				return
			if not _start_gizmo_drag(String(_gizmo["clip_id"]), handle, mb.position, pic):
				return
			if handle.begins_with("scale") and bool(_gizmo.get("box", false)):
				_begin_box_resize(mb.position, pic)
			if handle == "move" and _clicking():
				_gizmo_drag["click"] = _click_info(mb)
			view.accept_event()
		else:
			if _gizmo_drag.is_empty():
				return
			var click: Dictionary = _gizmo_drag.get("click", {})
			var opened: bool = bool(_gizmo_drag.get("open", false))
			_end_gizmo_drag(d)
			if not click.is_empty() and not opened:
				_click_select(click, pic)
			view.call("redraw_overlay")
		return
	if event is InputEventMouseMotion and _gizmo_drag.is_empty():
		_hover((event as InputEventMouseMotion).position)
		_warm_pick()
		return
	if event is InputEventMouseMotion and not _gizmo_drag.is_empty():
		var mm: InputEventMouseMotion = event
		var handle: String = String(_gizmo_drag["handle"])
		var c: Clip = s.clip_by_id(String(_gizmo_drag["clip_id"]))
		if c == null:
			return
		if handle == "move" and not bool(_gizmo_drag.get("open", false)):
			if mm.position.distance_to(_gizmo_drag["press"]) < ProgramSelect.DRAG_SLOP:
				view.accept_event()
				return
			_gizmo_drag["open"] = true
		var press: Vector2 = _gizmo_drag["press"]
		var centre: Vector2 = _gizmo_drag["centre"]
		var k: float = float(_gizmo_drag["k"])
		var path: String = ""
		var value: Variant = null
		var key_at: float = -1.0
		if handle == "move":
			var p0: Vector2 = _gizmo_drag["pos"]
			var into: Transform2D = _gizmo_drag["into"]
			var np: Vector2 = p0 + into.basis_xform((mm.position - press) / maxf(k, 0.0001))
			if mm.shift_pressed:
				if absf(mm.position.x - press.x) > absf(mm.position.y - press.y):
					np.y = p0.y
				else:
					np.x = p0.x
			if not bool(_gizmo_drag["parented"]):
				np = _snap_move(np, p0, mm)
			path = "transform.pos"
			value = [np.x, np.y]
			key_at = float(_gizmo_drag["key_pos"])
		elif handle.begins_with("scale") and _gizmo_drag.has("box_drag"):
			_drag_box(d, s, c, mm.position, pic)
			view.call("redraw_overlay")
			view.accept_event()
			return
		elif handle.begins_with("scale"):
			var s0: Vector2 = _gizmo_drag["scale"]
			var ax: Vector2 = _gizmo_drag["axis_x"]
			var ay: Vector2 = _gizmo_drag["axis_y"]
			var from_pivot: Vector2 = press - centre
			var to_pivot: Vector2 = mm.position - centre
			var fx: float = _pull(to_pivot.dot(ax), from_pivot.dot(ax))
			var fy: float = _pull(to_pivot.dot(ay), from_pivot.dot(ay))
			var linked: bool = bool(c.transform.get("scale_linked", true))
			var lead: float = fx if absf(from_pivot.dot(ax)) >= absf(from_pivot.dot(ay)) else fy
			if handle == "scale_x":
				lead = fx
			elif handle == "scale_y":
				lead = fy
			var ns: Vector2 = Vector2(s0.x * fx, s0.y * fy)
			if linked:
				ns = s0 * lead
			elif handle == "scale_x":
				ns = Vector2(s0.x * fx, s0.y)
			elif handle == "scale_y":
				ns = Vector2(s0.x, s0.y * fy)
			elif mm.shift_pressed:
				ns = Vector2(s0.x * lead, s0.y)
			ns = _snap_scale(ns, s0, linked, mm)
			path = "transform.scale"
			value = [ns.x, ns.y]
			key_at = float(_gizmo_drag["key_scale"])
		elif handle == "rotate":
			var a0: float = float(_gizmo_drag.get("spin_last", (press - centre).angle()))
			var a1: float = (mm.position - centre).angle()
			var spun: float = float(_gizmo_drag.get("spin", 0.0)) + wrapf(a1 - a0, -PI, PI)
			_gizmo_drag["spin_last"] = a1
			_gizmo_drag["spin"] = spun
			var nr: float = float(_gizmo_drag["rotation"]) + rad_to_deg(spun) * float(_gizmo_drag["turn"])
			if mm.shift_pressed:
				nr = round(nr / 15.0) * 15.0
			nr = _snap_rotate(nr, mm)
			path = "transform.rotation"
			value = nr
			key_at = float(_gizmo_drag["key_rot"])
		elif handle == "anchor":
			_drag_anchor(d, s, c, (mm.position - press) / maxf(k, 0.0001))
			view.call("redraw_overlay")
			view.accept_event()
			return
		if path.is_empty():
			return
		_gizmo_drag["path"] = path
		_gizmo_drag["value"] = value
		_gizmo_drag["key_at"] = key_at
		if RecordCmds.write(d, s, c.id, path, value, true):
			view.call("redraw_overlay")
			view.accept_event()
			return
		var current: Dictionary = c.get_param(path)
		var next: Dictionary = AnimProp.make(value) if key_at < 0.0 else AnimProp.set_key(current if not current.is_empty() else AnimProp.make(value), c.param_time(path, key_at - c.start), value)
		d.undo.live(ClipCmds.SetClipParam.new(s.id, c.id, path, next))
		view.call("redraw_overlay")
		view.accept_event()


func save_state() -> Dictionary:
	return {"zoom": String(view.get("zoom")) if view != null else "fit", "screen": on_screen()}


func restore_state(d: Dictionary) -> void:
	if view != null:
		view.call("set_zoom", String(d.get("zoom", "fit")))
		_zoom.call("set_value", String(view.get("zoom")), false)
	var screen: int = int(d.get("screen", -1))
	if screen >= 0 and screen < DisplayServer.get_screen_count() and _alive():
		Callable(self, "send_to_screen").call_deferred(screen)


func _whole_item() -> Dictionary:
	var s: Sequence = seq()
	var inside: bool = s != null and not Session.nest_context(s.id).is_empty()
	var it: Dictionary = PmMenu.check_item("show_whole", "Show the whole sequence around this nest", Session.show_whole() and inside, Cmd.keys_text("nest.show_whole"))
	if not inside:
		it["disabled"] = true
	return it


func frame_sequence(s: Sequence) -> Sequence:
	if s == null or not Session.has_method("whole_target"):
		return s
	var w: Dictionary = Session.whole_target(s.id, s.playhead)
	if w.get("seq") is Sequence:
		return w["seq"]
	return s


func _bind_whole_view() -> void:
	if not Session.nest_view_changed.is_connected(_on_whole_view):
		Session.nest_view_changed.connect(_on_whole_view)


func _on_whole_view() -> void:
	if not _alive():
		return
	_refresh_title()
	_request_render(false)


const RecordCmds := preload("res://doc/commands/record_cmds.gd")
const RecordButton := preload("res://modules/core_panels/record_button.gd")
const GIZMO_LABELS: Dictionary = {"transform.pos": "Move", "transform.scale": "Scale", "transform.rotation": "Rotate", "transform.anchor": "Move anchor point", "props.box_w": "Resize text box"}


func _begin_box_resize(press: Vector2, pic: Rect2) -> void:
	var s: Sequence = seq()
	var c: Clip = s.clip_by_id(String(_gizmo_drag.get("clip_id", ""))) if s != null else null
	if c == null:
		return
	var props: Dictionary = title_props_now(c)
	var d: Project = doc()
	var m: MediaItem = d.media_by_id(c.media_id)
	var size: Vector2 = MonitorPick.layer_size(c, m, s, d)
	var made: Dictionary = quad_for(c)
	var q: Variant = made.get("quad", PackedVector2Array())
	if not (q is PackedVector2Array) or (q as PackedVector2Array).size() != 4 or size.x < 2.0:
		return
	var qq: PackedVector2Array = q
	var xf: Transform2D = Transform2D(qq[1] - qq[0], qq[3] - qq[0], qq[0])
	if absf(xf.determinant()) < 0.000001:
		return
	var box: Rect2 = TextFrame.box_rect(props, size)
	var lp: Vector2 = _seq_to_layer(xf, size, press, pic)
	var side: Vector2i = Vector2i.ZERO
	var rel: Vector2 = (lp - box.get_center()) / (box.size * 0.5)
	var handle: String = String(_gizmo_drag["handle"])
	if handle != "scale_y":
		side.x = 1 if rel.x >= 0.0 else -1
	if handle != "scale_x":
		side.y = 1 if rel.y >= 0.0 else -1
	var lt: float = c.anim_time(s.playhead - c.start)
	_gizmo_drag["box_drag"] = {
		"xf": xf, "size": size, "box": box, "press": lp, "side": side,
		"k": TextFrame.scale_of(size),
		"key_w": bus().key_time_for(c, "props.box_w", s.playhead),
		"key_h": bus().key_time_for(c, "props.box_h", s.playhead),
		"pos": AnimProp.evaluate_vec2(c.transform["pos"], c.inner_time("transform.pos", lt), c.duration, s.fps),
	}


func _seq_to_layer(xf: Transform2D, size: Vector2, at: Vector2, pic: Rect2) -> Vector2:
	var s: Sequence = seq()
	var k: float = pic.size.x / maxf(float(s.width), 1.0)
	var seq_p: Vector2 = (at - pic.position) / maxf(k, 0.0001)
	return (xf.affine_inverse() * seq_p) * size


func _drag_box(d: Project, s: Sequence, c: Clip, at: Vector2, pic: Rect2) -> void:
	var bd: Dictionary = _gizmo_drag["box_drag"]
	var xf: Transform2D = bd["xf"]
	var size: Vector2 = bd["size"]
	var box: Rect2 = bd["box"]
	var side: Vector2i = bd["side"]
	var delta: Vector2 = _seq_to_layer(xf, size, at, pic) - (bd["press"] as Vector2)
	var lo: Vector2 = box.position
	var hi: Vector2 = box.end
	var floor_px: float = TextFrame.MIN_BOX * 2.0 * float(bd["k"])
	if side.x > 0:
		hi.x = maxf(box.end.x + delta.x, lo.x + floor_px)
	elif side.x < 0:
		lo.x = minf(box.position.x + delta.x, hi.x - floor_px)
	if side.y > 0:
		hi.y = maxf(box.end.y + delta.y, lo.y + floor_px)
	elif side.y < 0:
		lo.y = minf(box.position.y + delta.y, hi.y - floor_px)
	var k: float = maxf(float(bd["k"]), 0.0001)
	var shift: Vector2 = lo - box.position
	var into: Transform2D = _gizmo_drag["into"]
	var world: Vector2 = xf.basis_xform(shift / size)
	var np: Vector2 = (bd["pos"] as Vector2) + into.basis_xform(world)
	_gizmo_drag["path"] = "props.box_w"
	var writes: Array = [["props.box_w", (hi.x - lo.x) / k, float(bd["key_w"])], ["props.box_h", (hi.y - lo.y) / k, float(bd["key_h"])]]
	if not shift.is_zero_approx():
		writes.append(["transform.pos", [np.x, np.y], float(_gizmo_drag["key_pos"])])
	for w: Array in writes:
		var path: String = w[0]
		var key_at: float = w[2]
		var current: Dictionary = c.get_param(path)
		var next: Dictionary = AnimProp.make(w[1]) if key_at < 0.0 else AnimProp.set_key(current if not current.is_empty() else AnimProp.make(w[1]), c.param_time(path, key_at - c.start), w[1])
		d.undo.live(ClipCmds.SetClipParam.new(s.id, c.id, path, next))
const ANCHOR_REACH := 5.0
const ANCHOR_ARM := 6.0


func _on_anchor(p: Vector2) -> bool:
	return not _gizmo.is_empty() and bool(_gizmo.get("shown", true)) and p.distance_to(_gizmo["centre"]) <= ANCHOR_REACH


func _draw_anchor(ci: CanvasItem, centre: Vector2, ink: Color) -> void:
	ci.draw_arc(centre, ANCHOR_ARM * 0.6, 0.0, TAU, 16, ink, 1.0, true)
	ci.draw_line(centre - Vector2(ANCHOR_ARM, 0.0), centre + Vector2(ANCHOR_ARM, 0.0), ink, 1.0)
	ci.draw_line(centre - Vector2(0.0, ANCHOR_ARM), centre + Vector2(0.0, ANCHOR_ARM), ink, 1.0)


func _drag_anchor(d: Project, s: Sequence, c: Clip, world_delta: Vector2) -> void:
	var into: Transform2D = _gizmo_drag["into"]
	var local_delta: Vector2 = into.basis_xform(world_delta)
	var sc: Vector2 = _gizmo_drag["scale"]
	if bool(c.transform.get("scale_linked", true)):
		sc.y = sc.x
	var own: Transform2D = Transform2D(deg_to_rad(float(_gizmo_drag["rotation"])), sc, 0.0, Vector2.ZERO)
	if absf(own.determinant()) < 0.000001:
		return
	var na: Vector2 = (_gizmo_drag["anchor"] as Vector2) + own.affine_inverse().basis_xform(local_delta)
	var np: Vector2 = (_gizmo_drag["pos"] as Vector2) + local_delta
	_gizmo_drag["path"] = "transform.anchor"
	for pair: Array in [["transform.anchor", [na.x, na.y], float(_gizmo_drag["key_anchor"])], ["transform.pos", [np.x, np.y], float(_gizmo_drag["key_pos"])]]:
		var path: String = pair[0]
		var key_at: float = pair[2]
		var current: Dictionary = c.get_param(path)
		var next: Dictionary = AnimProp.make(pair[1]) if key_at < 0.0 else AnimProp.set_key(current if not current.is_empty() else AnimProp.make(pair[1]), c.param_time(path, key_at - c.start), pair[1])
		d.undo.live(ClipCmds.SetClipParam.new(s.id, c.id, path, next))

var _live_pending: bool = false


func _end_gizmo_drag(d: Project) -> void:
	var path: String = String(_gizmo_drag.get("path", ""))
	_gizmo_drag = {}
	_snap_end()
	if d == null:
		return
	RecordCmds.finish(d)
	d.undo.commit_live(RecordCmds.commit_label(d, String(GIZMO_LABELS.get(path, "Set value"))))


func _on_live_edit() -> void:
	_settle = SETTLE_SECONDS
	_live_pending = true
	if not Session.playing:
		Callable(self, "_flush_live_edit").call_deferred()


func _flush_live_edit() -> void:
	if _live_pending and _alive():
		_request_render(false)


const OUTLINE_MAX := 8
const PREF_LINKED := "timeline.linked_selection"

var _warm_key: String = ""


func _warm_pick() -> void:
	if not _clicking():
		return
	var s: Sequence = seq()
	var d: Project = doc()
	var key: String = s.id + ":" + str(s.playhead) + ":" + str(d.serial)
	if key == _warm_key:
		return
	_warm_key = key
	MonitorPick.warm(s, d, s.playhead)


func _start_gizmo_drag(clip_id: String, handle: String, press: Vector2, pic: Rect2) -> bool:
	var s: Sequence = seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c == null:
		return false
	var mine: bool = not _gizmo.is_empty() and String(_gizmo.get("clip_id", "")) == clip_id
	var centre: Vector2 = _gizmo["centre"] if mine else _to_picture(pic, quad_for(c).get("pivot", Vector2.ZERO))
	var lt: float = c.anim_time(s.playhead - c.start)
	_gizmo_drag = {
		"clip_id": c.id, "handle": handle, "press": press, "centre": centre,
		"pos": AnimProp.evaluate_vec2(c.transform["pos"], c.inner_time("transform.pos", lt), c.duration, s.fps),
		"scale": AnimProp.evaluate_vec2(c.transform["scale"], c.inner_time("transform.scale", lt), c.duration, s.fps),
		"rotation": AnimProp.evaluate_float(c.transform["rotation"], c.inner_time("transform.rotation", lt), c.duration, s.fps),
		"k": pic.size.x / maxf(float(s.width), 1.0),
		"key_pos": bus().key_time_for(c, "transform.pos", s.playhead),
		"key_scale": bus().key_time_for(c, "transform.scale", s.playhead),
		"key_rot": bus().key_time_for(c, "transform.rotation", s.playhead),
		"axis_x": _gizmo.get("axis_x", Vector2.RIGHT) if mine else Vector2.RIGHT,
		"axis_y": _gizmo.get("axis_y", Vector2.DOWN) if mine else Vector2.DOWN,
		"value": null, "path": "",
	}
	var pxf: Transform2D = Parenting.parent_xf(c, s, s.playhead, s.fps)
	var lin: Transform2D = Transform2D(pxf.x, pxf.y, Vector2.ZERO)
	_gizmo_drag["parented"] = Parenting.is_parented(c)
	_gizmo_drag["into"] = lin.affine_inverse() if absf(lin.determinant()) > 0.000001 else Transform2D.IDENTITY
	_gizmo_drag["turn"] = -1.0 if lin.determinant() < 0.0 else 1.0
	_gizmo_drag["anchor"] = AnimProp.evaluate_vec2(c.transform["anchor"], c.inner_time("transform.anchor", lt), c.duration, s.fps)
	_gizmo_drag["key_anchor"] = bus().key_time_for(c, "transform.anchor", s.playhead)
	_focus_id = clip_id
	_snap_begin(c, pic)
	return true


func _pick_allowed() -> bool:
	if Session.tool_id == "type" or Session.tool_id == "hand":
		return false
	var s: Sequence = seq()
	return s != null and frame_sequence(s) == s


func _clicking() -> bool:
	return _select != null and bool(_select.call("click_on")) and _pick_allowed()


static func _click_info(mb: InputEventMouseButton) -> Dictionary:
	return {"pos": mb.position, "alt": mb.alt_pressed, "shift": mb.shift_pressed, "ctrl": mb.ctrl_pressed or mb.meta_pressed}


func _pick_quad(c: Clip) -> PackedVector2Array:
	var comp: Node = Session.compositor
	if comp != null and comp.has_method("layer_quad") and String(_gizmo_drag.get("clip_id", "")) != c.id:
		var q: Variant = comp.call("layer_quad", c.id)
		if q is PackedVector2Array and (q as PackedVector2Array).size() == 4:
			return q
	return MonitorPick.quad_of_clip(c, seq(), doc(), seq().playhead)


func effect_drop_pick(local_pos: Vector2) -> String:
	if view == null:
		return ""
	var hits: PackedStringArray = hits_at(local_pos, view.call("picture_rect"))
	return hits[0] if not hits.is_empty() else ""


func effect_drop_region(local_pos: Vector2) -> Dictionary:
	var s: Sequence = seq()
	if view == null or s == null:
		return {}
	var pic: Rect2 = view.call("picture_rect")
	var hits: PackedStringArray = hits_at(local_pos, pic)
	var c: Clip = s.clip_by_id(hits[0]) if not hits.is_empty() else null
	if c == null:
		return {}
	return load("res://modules/core_panels/effect_drop.gd").call("region_under", c, s, doc(), local_pos, pic, _pick_quad(c))


func hits_at(pos: Vector2, pic: Rect2) -> PackedStringArray:
	var s: Sequence = seq()
	if s == null or pic.size.x <= 0.0:
		return PackedStringArray()
	var k: float = pic.size.x / maxf(float(s.width), 1.0)
	return MonitorPick.hits(s, doc(), s.playhead, (pos - pic.position) / maxf(k, 0.0001), _pick_quad)


func title_at(pos: Vector2, pic: Rect2) -> String:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or pic.size.x <= 0.0:
		return ""
	var hits: PackedStringArray = hits_at(pos, pic)
	if hits.is_empty():
		return ""
	var c: Clip = s.clip_by_id(hits[0])
	if c == null:
		return ""
	var m: MediaItem = d.media_by_id(c.media_id)
	if m == null or m.kind != "title":
		return ""
	return c.id


func edit_title_in_place(clip_id: String, at: Vector2, pic: Rect2) -> bool:
	var s: Sequence = seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	var te: RefCounted = monitor_text_edit()
	if c == null or not bool(te.call("can_edit", self, c)):
		return false
	var t: Dictionary = te.call("target_of", self, c)
	var idx: int = -1
	if not t.is_empty():
		idx = TextGlyphs.caret_at_point(t["layout"], te.call("_layer_at", self, pic, t, at))
	if not bool(te.call("begin", self, clip_id, idx)):
		return false
	_gizmo_drag = {}
	return true


func open_title_editor(clip_id: String) -> bool:
	var s: Sequence = seq()
	if s == null or clip_id.is_empty():
		return false
	var src: Object = bus().panel("source")
	if src == null or not src.has_method("open_title"):
		return false
	if not bool(src.call("open_title", s.id, clip_id)):
		return false
	load("res://modules/core_panels/edit_commands.gd").call("show_panel", "source")
	return true


func _title_double_click(mb: InputEventMouseButton, pic: Rect2) -> bool:
	if not _pick_allowed() or not _gizmo_drag.is_empty():
		return false
	if fullscreen_on() or popped_out():
		return false
	var id: String = title_at(mb.position, pic)
	if id.is_empty():
		return false
	if not edit_title_in_place(id, mb.position, pic) and not open_title_editor(id):
		return false
	if view != null:
		view.accept_event()
		view.call("redraw_overlay")
	return true


func _current_focus() -> String:
	var g: Clip = gizmo_clip()
	return g.id if g != null else ""


func _plan_at(info: Dictionary, pic: Rect2) -> Dictionary:
	var s: Sequence = seq()
	var hits: PackedStringArray = hits_at(info["pos"], pic)
	return ProgramSelect.plan_click(hits, s.selected_clip_ids, _current_focus(), bool(info["alt"]), bool(info["shift"]), bool(info["ctrl"]), bool(_select.call("empty_clears")))


func _press_pick(mb: InputEventMouseButton, pic: Rect2) -> void:
	if not _pick_allowed():
		return
	var s: Sequence = seq()
	if not _clicking():
		for id: String in hits_at(mb.position, pic):
			if s.selected_clip_ids.has(id):
				if _start_gizmo_drag(id, "move", mb.position, pic):
					view.accept_event()
					view.call("redraw_overlay")
				return
		return
	var info: Dictionary = _click_info(mb)
	var plan: Dictionary = _plan_at(info, pic)
	var mode: String = String(plan["mode"])
	var id: String = String(plan["id"])
	if mode == "replace" and not bool(info["alt"]) and s.selected_clip_ids.has(id):
		if _start_gizmo_drag(id, "move", mb.position, pic):
			_gizmo_drag["click"] = info
			view.accept_event()
		view.call("redraw_overlay")
		return
	apply_plan(plan)
	if mode == "replace" and s.selected_clip_ids.has(id) and _start_gizmo_drag(id, "move", mb.position, pic):
		view.accept_event()
	view.call("redraw_overlay")


func _click_select(info: Dictionary, pic: Rect2) -> void:
	if not _clicking():
		return
	apply_plan(_plan_at(info, pic))


func _linked_on() -> bool:
	return not Prefs.is_registered(PREF_LINKED) or bool(Prefs.get_value(PREF_LINKED))


func apply_plan(plan: Dictionary) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	var mode: String = String(plan.get("mode", "none"))
	var id: String = String(plan.get("id", ""))
	if d == null or s == null or mode == "none":
		return false
	Verbs.select_tracks(d, s, PackedStringArray(), "replace")
	if mode == "clear":
		_focus_id = ""
		return Verbs.select(d, s, PackedStringArray(), "replace")
	var picked: PackedStringArray = PackedStringArray([id])
	var family: PackedStringArray = Verbs.MoveRule.pick(s, picked, _linked_on())
	if mode == "toggle" and s.selected_clip_ids.has(id):
		var keep: PackedStringArray = PackedStringArray()
		for sid: String in s.selected_clip_ids:
			if not family.has(sid):
				keep.append(sid)
		if _focus_id == id:
			_focus_id = ""
		return Verbs.select(d, s, keep, "replace")
	if mode == "toggle" or mode == "add":
		var kept: PackedStringArray = s.picked_clip_ids.duplicate()
		if not kept.has(id):
			kept.append(id)
		_focus_id = id
		return Verbs.select(d, s, family, "add", kept)
	_focus_id = id
	return Verbs.select(d, s, family, "replace", picked)


const MonitorSnap := preload("res://modules/core_panels/monitor_snap.gd")
const MonitorSnapButton := preload("res://modules/core_panels/monitor_snap_button.gd")

var _snap: RefCounted = null


func snapper() -> RefCounted:
	if _snap == null:
		MonitorSnap.ensure_prefs(Prefs)
		_snap = MonitorSnap.new()
	return _snap


func _snap_begin(c: Clip, pic: Rect2) -> void:
	snapper().call("begin", c, seq(), doc(), pic, _gizmo_drag, Callable(self, "_pick_quad"), Callable(self, "quad_for"), view)


func _snap_end() -> void:
	if _snap != null:
		_snap.call("end")


func _snap_move(np: Vector2, p0: Vector2, mm: InputEventMouseMotion) -> Vector2:
	var press: Vector2 = _gizmo_drag["press"]
	var along_x: bool = absf(mm.position.x - press.x) > absf(mm.position.y - press.y)
	return snapper().call("move", np, p0, not mm.shift_pressed or along_x, not mm.shift_pressed or not along_x, float(_gizmo_drag["k"]), MonitorSnap.bypass(mm))


func _snap_scale(ns: Vector2, s0: Vector2, linked: bool, mm: InputEventMouseMotion) -> Vector2:
	return snapper().call("scale", ns, s0, linked, not linked and mm.shift_pressed, mm.position, MonitorSnap.bypass(mm))


func _snap_rotate(nr: float, mm: InputEventMouseMotion) -> float:
	var centre: Vector2 = _gizmo_drag["centre"]
	return snapper().call("rotate", nr, mm.shift_pressed, mm.position.distance_to(centre), mm.position, MonitorSnap.bypass(mm))


func _draw_snap(ci: CanvasItem, pic: Rect2) -> void:
	if _snap != null and not _gizmo_drag.is_empty():
		_snap.call("draw", ci, pic)


const PairPlace := preload("res://modules/core_panels/pair_place.gd")

var _pair_place: RefCounted = null


func pair_place() -> RefCounted:
	if _pair_place == null:
		_pair_place = PairPlace.new()
	return _pair_place


const MonitorHandles := preload("res://modules/core_panels/monitor_handles.gd")
const EffectHandlesUi := preload("res://modules/core_panels/effect_handles_ui.gd")

var _monitor_handles: RefCounted = null


func monitor_handles() -> RefCounted:
	if _monitor_handles == null:
		_monitor_handles = MonitorHandles.new()
	return _monitor_handles


const MonitorMask := preload("res://modules/core_panels/monitor_mask.gd")

var _monitor_mask: RefCounted = null


func monitor_mask() -> RefCounted:
	if _monitor_mask == null:
		MonitorMask.ensure_prefs(Prefs)
		_monitor_mask = MonitorMask.new()
	return _monitor_mask


const MonitorTextPath := preload("res://modules/core_panels/monitor_text_path.gd")

var _monitor_text_path: RefCounted = null


const MonitorTextEdit := preload("res://modules/core_panels/monitor_text_edit.gd")
const TextGlyphs := preload("res://engine/text_glyphs.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const TextFrame := preload("res://doc/text_frame.gd")

var _monitor_text_edit: RefCounted = null


func monitor_text_edit() -> RefCounted:
	if _monitor_text_edit == null:
		_monitor_text_edit = MonitorTextEdit.new()
	return _monitor_text_edit


const MonitorLetterPose := preload("res://modules/core_panels/monitor_letter_pose.gd")

var _letter_pose: RefCounted = null


func letter_pose() -> RefCounted:
	if _letter_pose == null:
		_letter_pose = MonitorLetterPose.new()
	return _letter_pose


func text_editing() -> bool:
	return _monitor_text_edit != null and bool(_monitor_text_edit.call("editing"))


func monitor_text_path() -> RefCounted:
	if _monitor_text_path == null:
		_monitor_text_path = MonitorTextPath.new()
	return _monitor_text_path


const TrackerUi := preload("res://modules/core_panels/tracker_ui.gd")
const ObjectUi := preload("res://modules/core_panels/object_ui.gd")
const MaskBrush := preload("res://modules/core_panels/mask_brush.gd")

var _tracker_ui: RefCounted = null
var _object_ui: RefCounted = null
var _mask_brush: RefCounted = null


func object_ui() -> RefCounted:
	if _object_ui == null:
		_object_ui = ObjectUi.new()
	return _object_ui


func mask_brush() -> RefCounted:
	if _mask_brush == null:
		_mask_brush = MaskBrush.new()
	return _mask_brush


func tracker_ui() -> RefCounted:
	if _tracker_ui == null:
		_tracker_ui = TrackerUi.new()
	return _tracker_ui


func _on_tracker_changed() -> void:
	if view != null and is_instance_valid(view):
		view.call("redraw_overlay")


func _on_tool(_tool_id: String) -> void:
	if view != null and is_instance_valid(view):
		view.call("redraw_overlay")


const MotionPathUi := preload("res://modules/core_panels/motion_path_ui.gd")

var _motion_path: RefCounted = null


func motion_path() -> RefCounted:
	if _motion_path == null:
		_motion_path = MotionPathUi.new()
	return _motion_path


func _motion_path_input(event: InputEvent, pic: Rect2) -> bool:
	var mp: RefCounted = motion_path()
	var busy: bool = not (mp.get("drag") as Dictionary).is_empty() or not (mp.get("pending") as Dictionary).is_empty()
	if not busy and (Session.tool_id == "type" or Session.tool_id == "hand" or Session.tool_id == "pen" or _clean_screen()):
		return false
	return bool(mp.call("input", event, pic, self))

extends Control

signal clip_double_clicked(clip_id: String)
signal nest_open_requested(sequence_id: String, clip_id: String)
signal view_changed
signal drop_done

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const FreeTransition := preload("res://doc/free_transition.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Marker := preload("res://doc/marker.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const TrackCmds := preload("res://doc/commands/track_cmds.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const SequenceCmds := preload("res://doc/commands/sequence_cmds.gd")
const MarkerCmds := preload("res://doc/commands/marker_cmds.gd")
const MarkerFollow := preload("res://doc/marker_follow.gd")
const Subtitles := preload("res://doc/subtitles.gd")
const SubtitleForms := preload("res://modules/core_panels/subtitle_forms.gd")
const CharMenu := preload("res://modules/core_panels/subtitle_char_menu.gd")
const LinkAsOne := preload("res://doc/link_as_one.gd")
const Presets := preload("res://doc/presets.gd")
const StreamRoles := preload("res://doc/stream_roles.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const Waves := preload("res://ui/timeline/timeline_wave.gd")
const WaveLook := preload("res://ui/timeline/wave_look.gd")
const WaveVolume := preload("res://ui/timeline/wave_volume.gd")
const WaveSheet := preload("res://ui/timeline/wave_look_sheet.gd")
const WAVE_CAP := 8.0
const Hit := preload("res://ui/timeline/timeline_hit.gd")
const Drag := preload("res://ui/timeline/timeline_drag.gd")
const Tracks := preload("res://ui/timeline/timeline_tracks.gd")
const PmScroll := preload("res://ui/kit/pm_scroll.gd")
const PmSlot := preload("res://ui/kit/pm_slot.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmDragLayer := preload("res://ui/kit/pm_drag_layer.gd")
const SOUND_WELL := "res://modules/core_panels/sound_well.gd"
const Icons := preload("res://ui/kit/icons.gd")
const Edit := preload("res://ui/timeline/timeline_edit.gd")
const Groups := preload("res://ui/timeline/timeline_groups.gd")
const Stacks := preload("res://ui/timeline/timeline_stacks.gd")
const Censor := preload("res://ui/timeline/timeline_censor.gd")
const RealignTool := preload("res://ui/timeline/timeline_realign.gd")
const ViewCuts := preload("res://ui/timeline/timeline_view_cuts.gd")
const ObjectSnap := preload("res://ui/timeline/timeline_object_snap.gd")
const Razor := preload("res://ui/timeline/timeline_razor.gd")
const Keys := preload("res://ui/timeline/timeline_keys.gd")
const SpeedBand := preload("res://ui/timeline/timeline_speed_band.gd")
const MoveTool := preload("res://ui/timeline/timeline_move_tool.gd")
const SlideTool := preload("res://ui/timeline/timeline_slide_tool.gd")
const TrackerBand := preload("res://ui/timeline/timeline_tracker_band.gd")
const ObjectBand := preload("res://ui/timeline/timeline_object_band.gd")
const Marquee := preload("res://ui/timeline/timeline_marquee.gd")
const Warn := preload("res://ui/timeline/timeline_warnings.gd")
const MarkerLanes := preload("res://ui/timeline/timeline_marker_lanes.gd")
const Filter := preload("res://ui/timeline/timeline_filter.gd")
const Solo := preload("res://ui/timeline/timeline_view_solo.gd")
const Fold := preload("res://ui/timeline/timeline_fold.gd")
const Dup := preload("res://ui/timeline/timeline_dup.gd")
const ToolCursors := preload("res://ui/kit/tool_cursors.gd")
const Minimap := preload("res://ui/timeline/timeline_minimap.gd")
const FenceLook := preload("res://ui/timeline/timeline_fences.gd")
const TOOL_POINTER_SHAPES: Array[Control.CursorShape] = [Control.CURSOR_ARROW, Control.CURSOR_POINTING_HAND, Control.CURSOR_HSPLIT, Control.CURSOR_CROSS, Control.CURSOR_DRAG, Control.CURSOR_IBEAM]
const HSCROLL_H := 11.0
const DIVIDER_H := 14.0
const VSCROLL_W := 8.0
const PPS_MAX := 2000.0
const ZOOM_STEP := 1.4
const WHEEL_ZOOM := 1.18
const DENSE_LIMIT := 80
const WAVE_BUDGET := 6000
const SLIM_WAVE_BUDGET := 32
const WAVE_MIN_H := 16.0
const THUMB_MIN_H := 32.0
const AUTOSCROLL_BAND := 34.0
const AUTOSCROLL_MAX := 1800.0
const STILL_SECONDS := 5.0
const RENDER_BAR_H := 4.0
const PREF_HEADER_W := "timeline.header_w"
const PREF_WAVE_LOG := "timeline.wave_log"
const PREF_WAVE_GAIN := "timeline.wave_gain"
const PREF_FOLLOW := "timeline.follow_playhead"
const PREF_SNAP := "timeline.snap"
const PREF_LINKED := "timeline.linked_selection"
const PREF_PICTURES := "timeline.clip_pictures"
const PREF_TRANSITION_SECONDS := "edit.default_transition_seconds"
const PREF_MONO := "ui.mono_labels"
const VIEW_KEY := "timeline_view"

var scroll_x: float = 0.0
var scroll_y: float = 0.0
var band_scroll_y: float = 0.0
var pps: float = 40.0
var header_w: float = 160.0
var snapping: bool = true
var linked_selection: bool = true
var insert_mode: bool = false
var wave_log: bool = true
var wave_gain: float = 1.5
var peaks_provider: Callable = Callable()
var coverage_provider: Callable = Callable()
var doc_override: Project = null
var seq_override: Sequence = null
var paint_count: int = 0
var decorated_clips: int = 0
var thumbs_waiting: int = 0
var _strip_state: Dictionary = {}
var _strip_state_at: Dictionary = {}
var drawn_headers: int = 0
var overlay_paint_count: int = 0
var lanes_builds: int = 0
var last_draw_usec: int = 0
var profile: Dictionary = {}
var _duration_cache: float = 0.0
var _duration_key: String = ""
var focused: bool = false
var drag: RefCounted = null
var hover: Dictionary = {}
var drop_preview: Dictionary = {}
var meters: PackedFloat32Array = PackedFloat32Array()
var _scroll: Node = null
var _band_scroll: Node = null
var _overlay: Control = null
var _slot: Control = null
var _lanes: Dictionary = {}
var _lanes_key: String = ""
var _geom: Dictionary = {}
var _wave_cache: Dictionary = {}
var _wave_points_spent: int = 0
var _slim_waves: int = 0
var _wave_more: bool = false
var wave_stats: Dictionary = {"loading": 0, "deferred": 0, "drawn": 0, "built": 0, "points": 0}
var _dense_cache: Dictionary = {}
var _deferred_moves: Array[Dictionary] = []
var _loading: Dictionary = {}
var _loading_dirty: bool = true
var _loading_at: int = -1000000
var loading_sweeps: int = 0
var _wave_waiting: Dictionary = {}
var _waiting_last: Dictionary = {}
var _grow_pending: bool = false
var _grow_at: int = -1000000
var growth_repaints: int = 0
var _height_preview: Dictionary = {}
var _band_h_preview: float = -1.0
var _rename: LineEdit = null
var _rename_track: String = ""
var _font: Font = null
var _fs: int = 12
var _fs_small: int = 11
var _pin_anim: Dictionary = {}
var _ghost_hidden: Control = null
var _last_scrub: float = -1.0
var _follow_pending: bool = false
var _pressed_button: String = ""
var _hover_serial: int = 0
var _fit_pending: bool = false
var _auto_fit: bool = true
var selected_gap: Dictionary = {}
var selected_marker_ids: PackedStringArray = PackedStringArray()
var trim_anim: Node = null
var _fold: Dictionary = {}
var _fold_serial: int = -1
var _fold_pps: float = -1.0
var _fold_seq: int = 0
var _fold_holding: bool = false
var fold_builds: int = 0
var _paint_fold: Dictionary = {}
var _in_paint: bool = false


func _init() -> void:
	name = "TimelineCanvas"
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	_scroll = PmScroll.make(true)
	_scroll.set("ctrl_wheel_zooms", false)
	_scroll.set("alt_wheel_zooms", false)
	_scroll.connect("changed", _on_scroll_changed)
	add_child(_scroll)
	_band_scroll = PmScroll.make(false)
	_band_scroll.connect("changed", _on_band_scroll_changed)
	add_child(_band_scroll)
	drag = Drag.new()
	drag.host = self
	_overlay = _Overlay.new()
	_overlay.canvas = self
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_slot = PmSlot.make(PackedStringArray(["media", "effect", "preset", "transition", "files"]))
	_slot.name = "TimelineSlot"
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.set("draw_highlight", false)
	_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot.connect("hover_changed", _on_slot_hover_changed)
	_slot.connect("hover_moved", _on_slot_hover_moved)
	_slot.connect("dropped", _on_slot_dropped)
	add_child(_slot)
	gui_input.connect(_on_input)
	mouse_exited.connect(_on_mouse_exit)
	resized.connect(_on_resized)
	set_process(true)


func _ready() -> void:
	_font = Tk.font("body")
	_fs = Tk.fs(Tk.sz("font_body"))
	_fs_small = Tk.fs(Tk.sz("font_small"))
	for spec: Array in [[PREF_HEADER_W, 160.0, {"label": "Timeline header width", "type": "float", "min": 34.0, "max": 320.0}], [PREF_WAVE_LOG, false, {"label": "Waveforms in log dB", "type": "bool"}], [PREF_WAVE_GAIN, 1.0, {"label": "Waveform gain", "type": "float", "min": 0.25, "max": 4.0}], [PREF_FOLLOW, "page", {"label": "Follow the playhead while playing", "type": "enum", "choices": ["page", "smooth", "off"]}], [PREF_SNAP, true, {"label": "Snap on the timeline", "type": "bool"}], [PREF_LINKED, true, {"label": "Linked selection", "type": "bool"}], [PREF_TRANSITION_SECONDS, 1.0, {"label": "Default transition length (seconds)", "type": "float", "min": 0.04, "max": 10.0}]]:
		if not Prefs.is_registered(String(spec[0])):
			Prefs.register(String(spec[0]), spec[1], spec[2])
	PlayheadGlide.register_prefs()
	load("res://ui/timeline/playhead_look.gd").call("register_prefs")
	MarkerFollow.register_prefs()
	WaveLook.register_prefs()
	Minimap.register_prefs()
	header_w = float(Tk.px(float(Prefs.get_value(PREF_HEADER_W))))
	wave_log = bool(Prefs.get_value(PREF_WAVE_LOG))
	wave_gain = float(Prefs.get_value(PREF_WAVE_GAIN))
	snapping = bool(Prefs.get_value(PREF_SNAP))
	linked_selection = bool(Prefs.get_value(PREF_LINKED))
	if not Session.playhead_changed.is_connected(_on_playhead):
		Session.playhead_changed.connect(_on_playhead)
	if not Session.playing_changed.is_connected(_on_playing):
		Session.playing_changed.connect(_on_playing)
	if not Session.tool_changed.is_connected(_on_tool):
		Session.tool_changed.connect(_on_tool)
	if not Jobs.changed.is_connected(_on_jobs):
		Jobs.changed.connect(_on_jobs)
	if PurrBridge.has_signal("strip_ready") and not PurrBridge.strip_ready.is_connected(_on_strip_ready):
		PurrBridge.strip_ready.connect(_on_strip_ready)
	if PurrBridge.has_signal("peaks_progress") and not PurrBridge.peaks_progress.is_connected(_on_peaks_progress):
		PurrBridge.peaks_progress.connect(_on_peaks_progress)
	Waves.listen_fine(self)
	if not Prefs.changed.is_connected(_on_pref_changed):
		Prefs.changed.connect(_on_pref_changed)
	queue_redraw()


func _on_strip_ready(_h: int) -> void:
	queue_redraw()


func clip_pictures() -> String:
	if not Prefs.is_registered(PREF_PICTURES):
		Prefs.register(PREF_PICTURES, "strip", {"label": "Pictures on video clips (strip, head frame only, none)", "type": "enum", "choices": ["strip", "head", "none"]})
	return String(Prefs.get_value(PREF_PICTURES))


func _on_jobs() -> void:
	_loading_dirty = true


func _on_peaks_progress(h: int, _stream: int) -> void:
	if _waiting_last.has(h) or _wave_waiting.has(h):
		_grow_pending = true


func _tick_loading() -> void:
	if Project.change_frame == Engine.get_process_frames():
		return
	var now: int = Time.get_ticks_msec()
	if _grow_pending and now - _grow_at >= GROW_REPAINT_MS:
		_grow_pending = false
		_grow_at = now
		growth_repaints += 1
		queue_redraw()
	if not _loading_dirty or now - _loading_at < LOADING_REFRESH_MS:
		return
	_loading_dirty = false
	_loading_at = now
	var d: Project = doc()
	var fresh: Dictionary = _loading_media(d) if d != null else {}
	if fresh != _loading:
		_loading = fresh
		queue_redraw()


func _exit_tree() -> void:
	if Jobs.changed.is_connected(_on_jobs):
		Jobs.changed.disconnect(_on_jobs)
	if PurrBridge.has_signal("strip_ready") and PurrBridge.strip_ready.is_connected(_on_strip_ready):
		PurrBridge.strip_ready.disconnect(_on_strip_ready)
	if PurrBridge.has_signal("peaks_progress") and PurrBridge.peaks_progress.is_connected(_on_peaks_progress):
		PurrBridge.peaks_progress.disconnect(_on_peaks_progress)


func doc() -> Project:
	if doc_override != null:
		return doc_override
	return Session.doc


func doc_tracking_empty() -> bool:
	var d: Project = doc()
	return d == null or d.tracking.is_empty()


func seq() -> Sequence:
	if seq_override != null:
		return seq_override
	return Session.seq()


func set_document(d: Project, s: Sequence) -> void:
	doc_override = d
	seq_override = s
	invalidate_all()


func _on_pref_changed(key: String) -> void:
	if not is_inside_tree():
		return
	if key == PREF_HEADER_W:
		var want: float = float(Tk.px(float(Prefs.get_value(PREF_HEADER_W))))
		if absf(want - header_w) > 0.5:
			header_w = want
			_lanes_key = ""
			queue_redraw()
	elif key == PREF_WAVE_LOG or key == PREF_WAVE_GAIN:
		wave_log = bool(Prefs.get_value(PREF_WAVE_LOG))
		wave_gain = float(Prefs.get_value(PREF_WAVE_GAIN))
		_wave_cache.clear()
		queue_redraw()
	elif key.begins_with("waves."):
		queue_redraw()
	elif key == PREF_SNAP:
		snapping = bool(Prefs.get_value(PREF_SNAP))
		_notify_toolbar()
	elif key == PREF_LINKED:
		linked_selection = bool(Prefs.get_value(PREF_LINKED))
		_notify_toolbar()
	elif key == PREF_PICTURES or key == "playback.low_res_pictures":
		queue_redraw()
	elif key == "edit.drag_step" or key == "edit.drag_step_px":
		queue_redraw()
	elif key.begins_with("ui.fold.") or key.begins_with("timeline."):
		_lanes_key = ""
		queue_redraw()


func _notify_toolbar() -> void:
	var owner_panel: Node = get_parent()
	while owner_panel != null:
		if owner_panel.has_method("refresh_toolbar"):
			owner_panel.call("refresh_toolbar")
			return
		owner_panel = owner_panel.get_parent()
	var tl: Object = _bus_panel("timeline")
	if tl != null and tl.has_method("refresh_toolbar"):
		tl.call("refresh_toolbar")


func invalidate_all() -> void:
	_lanes_key = ""
	_wave_cache.clear()
	_dense_cache.clear()
	queue_redraw()


func on_doc_changed(kind: String) -> void:
	if kind == "structure" or kind == "media" or kind == "meta":
		_dense_cache.clear()
		_loading_dirty = true
	if kind == "structure" or (kind == "selection" and seq() != null and not seq().selected_clip_ids.is_empty()):
		selected_gap = {}
	if (kind == "markers" or kind == "structure") and not selected_marker_ids.is_empty():
		var keep: PackedStringArray = marker_selection()
		if keep != selected_marker_ids:
			selected_marker_ids = keep
	_lanes_key = ""
	queue_redraw()
	_overlay.queue_redraw()


func fps() -> float:
	var s: Sequence = seq()
	if s == null or s.fps <= 0.0:
		return 30.0
	return s.fps


func playhead() -> float:
	var s: Sequence = seq()
	return s.playhead if s != null else 0.0


func x_of(t: float) -> float:
	var f: Dictionary = _paint_fold if _in_paint else fold()
	if f.is_empty():
		return header_w + t * pps - scroll_x
	return header_w + Fold.shown(f, t) * pps - scroll_x


func t_of(x: float) -> float:
	var f: Dictionary = _paint_fold if _in_paint else fold()
	if f.is_empty():
		return (x - header_w + scroll_x) / pps
	return Fold.real(f, (x - header_w + scroll_x) / pps)


func fold() -> Dictionary:
	if drag != null and bool(drag.get("active")):
		if not _fold_holding:
			_fold_holding = true
			if _fold_serial < 0 or _fold_pps != pps:
				_refresh_fold()
		elif _fold_pps != pps:
			_refresh_fold()
		return _fold
	_fold_holding = false
	var d: Project = doc()
	var s: Sequence = seq()
	var serial: int = d.serial if d != null else 0
	var sid: int = s.get_instance_id() if s != null else 0
	if serial != _fold_serial or pps != _fold_pps or sid != _fold_seq:
		_refresh_fold()
	return _fold


func _refresh_fold() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	var was: float = Fold.hidden_time(_fold)
	_fold_serial = d.serial if d != null else 0
	_fold_pps = pps
	_fold_seq = s.get_instance_id() if s != null else 0
	_fold = Fold.for_pps(Solo.fold_spans(d, s), pps) if s != null and Solo.folds(s) else {}
	fold_builds += 1
	if Fold.hidden_time(_fold) != was:
		_sync_scroll_content.call_deferred()
		view_changed.emit.call_deferred()


func shown_duration() -> float:
	return Fold.shown(fold(), duration())


func px_between(t0: float, t1: float) -> float:
	return Fold.px_between(fold(), t0, t1, pps)


func snap_near(targets: PackedFloat64Array, t: float) -> float:
	var f: Dictionary = fold()
	var best: float = t
	if f.is_empty():
		var best_d: float = Drag.SNAP_PX / pps
		for v: float in targets:
			if absf(v - t) < best_d:
				best_d = absf(v - t)
				best = v
		return best
	var best_px: float = Drag.SNAP_PX
	for v: float in targets:
		var dpx: float = absf(Fold.px_between(f, t, v, pps))
		if dpx < best_px:
			best_px = dpx
			best = v
	return best


func ruler_h() -> float:
	return float(Tk.px(Tk.sz("ruler_h")))


func view_w() -> float:
	return maxf(size.x - header_w, 1.0)


func duration() -> float:
	var s: Sequence = seq()
	if s == null:
		return 0.0
	var d: Project = doc()
	var key: String = s.id + "|" + str(d.serial if d != null else 0)
	if key == _duration_key:
		return _duration_cache
	_duration_cache = s.duration()
	_duration_key = key
	return _duration_cache


func band_at_bottom() -> bool:
	var s: Sequence = seq()
	return s == null or String(s.pinned.get("position", "bottom")) != "top"


func band_height() -> float:
	if _band_h_preview >= 0.0:
		return _band_h_preview
	var s: Sequence = seq()
	if s == null:
		return float(Tk.px(Tk.sz("pinned_default")))
	var h: float = float(s.pinned.get("height", 0.0))
	if h <= 0.0:
		h = band_fit_height()
	return maxf(h, float(Tk.px(Tk.sz("pinned_min"))))


func band_fit_height() -> float:
	var ln: Dictionary = lanes()
	if (ln["band"] as Array).is_empty():
		return float(Tk.px(Tk.sz("pinned_default")))
	var fit: float = float(ln["band_h"]) + Lanes.default_height("video") + Lanes.LANE_GAP
	return minf(fit, maxf(size.y * 0.5, float(Tk.px(Tk.sz("pinned_min")))))


func band_collapsed() -> bool:
	var s: Sequence = seq()
	return s != null and bool(s.pinned.get("collapsed", false))


func lanes() -> Dictionary:
	var d: Project = doc()
	var s: Sequence = seq()
	if s == null:
		var no_main: Array[Dictionary] = []
		var no_band: Array[Dictionary] = []
		return {"main": no_main, "band": no_band, "main_h": 0.0, "band_h": 0.0, "hidden": 0, "nested_audio_y": -1.0}
	var key: String = s.id + "|" + str(d.serial if d != null else 0) + "|" + str(Tk.ui_scale) + "|" + JSON.stringify(_height_preview)
	if key != _lanes_key or _lanes.is_empty():
		_lanes = Lanes.build(d, s, 0.0, INF)
		if not _height_preview.is_empty():
			for set_name: String in ["main", "band"]:
				var y: float = 0.0
				for l: Dictionary in _lanes[set_name]:
					var t: Track = l["track"]
					if _height_preview.has(t.id) and not bool(l["nest"]):
						l["h"] = Lanes.clamp_height(float(_height_preview[t.id]))
					l["y"] = y
					y += float(l["h"]) + Lanes.LANE_GAP
				_lanes[set_name + "_h"] = y
		_lanes_key = key
		lanes_builds += 1
	return _lanes


func lane_height_of(track_id: String) -> float:
	var l: Dictionary = Lanes.lane_for_track(lanes(), track_id)
	if l.is_empty():
		return Lanes.default_height("video")
	return float(l["h"])


func geometry() -> Dictionary:
	var rh: float = ruler_h()
	var marker_rows: Array[Dictionary] = MarkerLanes.rows(seq(), rh)
	var top: float = MarkerLanes.rows_end(marker_rows, rh)
	var w: float = size.x
	var h: float = size.y
	var ln: Dictionary = lanes()
	var has_band: bool = not (ln["band"] as Array).is_empty()
	var div_h: float = float(Tk.px(DIVIDER_H)) if has_band else 0.0
	var band_h: float = 0.0
	if has_band and not band_collapsed():
		band_h = minf(band_height(), maxf(h - top - div_h - Minimap.strip_h(HSCROLL_H) - 40.0, 0.0))
	var hsh: float = Minimap.strip_h(HSCROLL_H)
	var hs: Rect2 = Rect2(header_w, h - hsh, maxf(w - header_w, 0.0), hsh)
	var main_rect: Rect2
	var band_rect: Rect2
	var div_rect: Rect2
	if band_at_bottom():
		main_rect = Rect2(0.0, top, w, maxf(h - top - hsh - div_h - band_h, 0.0))
		div_rect = Rect2(0.0, main_rect.end.y, w, div_h)
		band_rect = Rect2(0.0, div_rect.end.y, w, band_h)
	else:
		band_rect = Rect2(0.0, top, w, band_h)
		div_rect = Rect2(0.0, band_rect.end.y, w, div_h)
		main_rect = Rect2(0.0, div_rect.end.y, w, maxf(h - div_rect.end.y - hsh, 0.0))
	_geom = {
		"header_w": header_w, "ruler_h": rh, "marker_rows": marker_rows, "scroll_x": scroll_x, "scroll_y": scroll_y, "band_scroll_y": band_scroll_y,
		"pps": pps, "width": w, "height": h, "main_rect": main_rect, "band_rect": band_rect, "divider_rect": div_rect,
		"hscroll_rect": hs, "main_h": float(ln["main_h"]), "band_h": float(ln["band_h"]), "has_band": has_band,
		"fold": fold(),
	}
	return _geom


func hit_at(pos: Vector2) -> Dictionary:
	return Filter.hit(self, Hit.test(geometry(), lanes(), seq(), pos, playhead()))


func accepts_global(global_pos: Vector2) -> bool:
	if not is_visible_in_tree():
		return false
	return get_global_rect().has_point(global_pos)


func min_pps() -> float:
	var d: float = maxf(Fold.shown(_fold, duration()), 1.0)
	return maxf(view_w() / (d * 1.04 + 0.5), 0.00005)


func set_pps(v: float, about_x: float = -INF) -> void:
	_auto_fit = false
	var t_at: float = t_of(about_x if about_x > -INF else header_w)
	var ax: float = about_x if about_x > -INF else header_w
	pps = clampf(v, min_pps(), PPS_MAX)
	var want: float = Fold.shown(fold(), t_at) * pps - (ax - header_w)
	_sync_scroll_content()
	_scroll.call("scroll_to", maxf(want, 0.0), scroll_y, false)
	scroll_x = float(_scroll.get("scroll_x"))
	_dense_cache.clear()
	view_changed.emit()
	queue_redraw()
	_overlay.queue_redraw()


func zoom_in(about_x: float = -INF) -> void:
	set_pps(pps * ZOOM_STEP, about_x if about_x > -INF else header_w + view_w() * 0.5)


func zoom_out(about_x: float = -INF) -> void:
	set_pps(pps / ZOOM_STEP, about_x if about_x > -INF else header_w + view_w() * 0.5)


func zoom_fit() -> void:
	var d: float = maxf(shown_duration(), 1.0)
	_fit_pending = size.x <= header_w + 2.0
	pps = clampf(view_w() / (d * 1.04 + 0.5), 0.00005, PPS_MAX)
	_sync_scroll_content()
	_scroll.call("scroll_to", 0.0, scroll_y, false)
	scroll_x = 0.0
	_dense_cache.clear()
	view_changed.emit()
	queue_redraw()


func zoom_to_selection() -> void:
	_auto_fit = false
	var s: Sequence = seq()
	if s == null or s.selected_clip_ids.is_empty():
		zoom_fit()
		return
	var t0: float = INF
	var t1: float = -INF
	for id: String in s.selected_clip_ids:
		var c: Clip = s.clip_by_id(id)
		if c != null:
			t0 = minf(t0, c.start)
			t1 = maxf(t1, c.end())
	if t1 <= t0:
		return
	var f0: Dictionary = fold()
	pps = clampf(view_w() / ((Fold.shown(f0, t1) - Fold.shown(f0, t0)) * 1.1), min_pps(), PPS_MAX)
	_sync_scroll_content()
	_scroll.call("scroll_to", maxf(Fold.shown(fold(), t0) * pps - view_w() * 0.05, 0.0), scroll_y, false)
	scroll_x = float(_scroll.get("scroll_x"))
	_dense_cache.clear()
	view_changed.emit()
	queue_redraw()


func reveal_time(t: float, page: bool) -> void:
	var x: float = Fold.shown(fold(), t) * pps
	var left: float = scroll_x
	var right: float = scroll_x + view_w()
	if x >= left + 4.0 and x <= right - view_w() * 0.08:
		return
	var target: float = maxf(x - view_w() * 0.15, 0.0) if page else maxf(x - view_w() * 0.5, 0.0)
	_scroll.call("scroll_to", target, scroll_y, not page)
	if page:
		scroll_x = float(_scroll.get("scroll_x"))
		queue_redraw()
		_overlay.queue_redraw()


func _sync_scroll_content() -> void:
	var g: Dictionary = geometry()
	var main_rect: Rect2 = g["main_rect"]
	_scroll.call("set_view", view_w(), main_rect.size.y)
	_scroll.set("tail_x", view_w() * 0.5)
	_scroll.set("tail_y", 0.0)
	_scroll.call("set_content", Fold.shown(g["fold"], duration()) * pps, float(g["main_h"]))
	var band_rect: Rect2 = g["band_rect"]
	_band_scroll.call("set_view", 1.0, band_rect.size.y)
	_band_scroll.call("set_content", 1.0, float(g["band_h"]))


func _on_scroll_changed() -> void:
	scroll_x = float(_scroll.get("scroll_x"))
	scroll_y = float(_scroll.get("scroll_y"))
	view_changed.emit()
	queue_redraw()
	_overlay.queue_redraw()


func _on_band_scroll_changed() -> void:
	band_scroll_y = float(_band_scroll.get("scroll_y"))
	queue_redraw()
	_overlay.queue_redraw()


func _on_resized() -> void:
	_sync_scroll_content()
	if (_fit_pending or _auto_fit) and size.x > header_w + 2.0:
		zoom_fit()
	queue_redraw()


func user_touched_view() -> void:
	_auto_fit = false


func _on_playhead(_t: float) -> void:
	_overlay.queue_redraw()
	if Session.playing:
		_follow_pending = true


func _on_playing(_on: bool) -> void:
	_overlay.queue_redraw()


func _on_tool(_id: String) -> void:
	_update_cursor()


func set_header_w(w: float) -> void:
	header_w = clampf(w, float(Tk.px(Tk.sz("header_w_min"))), float(Tk.px(Tk.sz("header_w_max"))))
	_sync_scroll_content()
	queue_redraw()
	_overlay.queue_redraw()


func persist_header_w() -> void:
	Prefs.set_value(PREF_HEADER_W, header_w / maxf(Tk.ui_scale, 0.01))


func set_band_height_preview(h: float) -> void:
	_band_h_preview = h if h < 0.0 else maxf(h, float(Tk.px(Tk.sz("pinned_min"))))
	_sync_scroll_content()
	queue_redraw()
	_overlay.queue_redraw()


func commit_band_height() -> void:
	var h: float = _band_h_preview
	_band_h_preview = -1.0
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or h < 0.0:
		return
	var p: Dictionary = s.pinned.duplicate(true)
	p["height"] = maxf(h, float(Tk.px(Tk.sz("pinned_min"))))
	Verbs.run(d, "Pinned band height", [SequenceCmds.SetPinnedBand.new(s.id, p)])


func set_pinned_field(key: String, value: Variant) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var p: Dictionary = s.pinned.duplicate(true)
	p[key] = value
	Verbs.run(d, "Pinned band", [SequenceCmds.SetPinnedBand.new(s.id, p)])


func set_track_height_preview(track_id: String, h: float) -> void:
	if h < 0.0:
		_height_preview.erase(track_id)
	else:
		_height_preview[track_id] = h
	_lanes_key = ""
	queue_redraw()
	_overlay.queue_redraw()


func commit_track_height(track_id: String) -> void:
	var h: float = float(_height_preview.get(track_id, -1.0))
	_height_preview.erase(track_id)
	_lanes_key = ""
	if h < 0.0:
		return
	set_track_field(track_id, "height", Lanes.clamp_height(h) / maxf(Tk.ui_scale, 0.01))


func set_track_field(track_id: String, field: String, value: Variant) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return false
	var t: Track = s.track_by_id(track_id)
	if t == null or t.get(field) == value:
		return false
	return Verbs.run(d, "Track " + field, [TrackCmds.SetTrackField.new(s.id, track_id, field, value)])


func pin_track(track_id: String, on: bool) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return false
	var from: Dictionary = Lanes.lane_for_track(lanes(), track_id)
	var from_y: float = Hit.lane_screen_y(geometry(), from) if not from.is_empty() else 0.0
	var from_h: float = float(from["h"]) if not from.is_empty() else 0.0
	var ok: bool = Verbs.pin_track(d, s, track_id, on)
	if ok and Tk.dur("medium") > 0.0 and not from.is_empty():
		_lanes_key = ""
		var to: Dictionary = Lanes.lane_for_track(lanes(), track_id)
		if not to.is_empty():
			_pin_anim = {"from": Rect2(0.0, from_y, size.x, from_h), "to": Rect2(0.0, Hit.lane_screen_y(geometry(), to), size.x, float(to["h"])), "t0": Time.get_ticks_msec(), "dur": Tk.dur("medium")}
	return ok


func reorder_band(track_id: String, pos: Vector2) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return false
	var ln: Dictionary = lanes()
	var band_list: Array = ln["band"]
	if band_list.size() < 2:
		return false
	var g: Dictionary = geometry()
	var band_rect: Rect2 = g["band_rect"]
	var content_y: float = pos.y - band_rect.position.y + band_scroll_y
	var order: PackedStringArray = PackedStringArray()
	for l: Dictionary in band_list:
		order.append((l["track"] as Track).id)
	var from: int = order.find(track_id)
	if from < 0:
		return false
	var to: int = band_list.size() - 1
	for i: int in band_list.size():
		var l: Dictionary = band_list[i]
		if content_y < float(l["y"]) + float(l["h"]) * 0.5:
			to = i
			break
	if to == from:
		return false
	order.remove_at(from)
	order.insert(clampi(to if to < from else to - 1, 0, order.size()), track_id)
	Lanes.set_pinned_order(d, s, order)
	_lanes_key = ""
	queue_redraw()
	return true


func pan_by(delta: Vector2, origin: Dictionary) -> void:
	_scroll.call("scroll_to", float(origin.get("scroll_x", 0.0)) + delta.x, float(origin.get("scroll_y", 0.0)) + delta.y, false)


func band_scroll_thumb(dy: float, origin: Dictionary) -> void:
	var g: Dictionary = geometry()
	var band_rect: Rect2 = g["band_rect"]
	var ratio: float = float(g["band_h"]) / maxf(band_rect.size.y, 1.0)
	_band_scroll.call("scroll_to", 0.0, float(origin.get("band_scroll_y", 0.0)) + dy * ratio, false)


## A click on the minimap outside the window centres the view there; a click on the window just grabs it.
func minimap_jump(x: float) -> bool:
	if not Minimap.on():
		return false
	var g: Dictionary = geometry()
	var win: Rect2 = Minimap.window_rect(self, g, g["hscroll_rect"])
	if x >= win.position.x and x <= win.end.x:
		return false
	_auto_fit = false
	_scroll.call("scroll_to", Minimap.scroll_for(self, g, g["hscroll_rect"], x), scroll_y, false)
	scroll_x = float(_scroll.get("scroll_x"))
	_dense_cache.clear()
	view_changed.emit()
	queue_redraw()
	return true


var _nest_uses: Dictionary = {}
var _nest_uses_paint: int = -1


## How many nest clips in the whole project show the sequence `seq_id`, counted once a paint. Shown on a nest as
## "nest ×3" so it is clear that changing inside it changes every copy.
func nest_uses(seq_id: String) -> int:
	if _nest_uses_paint != paint_count:
		_nest_uses_paint = paint_count
		_nest_uses = {}
		var d: Project = doc()
		if d != null:
			for sq: Sequence in d.sequences:
				for tr: Track in sq.all_tracks():
					for c: Clip in tr.clips:
						if not c.sequence_id.is_empty():
							_nest_uses[c.sequence_id] = int(_nest_uses.get(c.sequence_id, 0)) + 1
	return int(_nest_uses.get(seq_id, 0))


func hscroll_thumb(dx: float, origin: Dictionary) -> void:
	var ratio: float = (shown_duration() * pps + view_w() * 0.5) / maxf(view_w(), 1.0)
	_scroll.call("scroll_to", float(origin.get("scroll_x", 0.0)) + dx * ratio, scroll_y, false)


func snap_targets(exclude: PackedStringArray) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var s: Sequence = seq()
	if s == null:
		return out
	var span: float = view_w() / pps
	var f: Dictionary = fold()
	var t0: float = maxf(Fold.real(f, scroll_x / pps - span), 0.0)
	var t1: float = Fold.real(f, scroll_x / pps + span * 2.0)
	out.append(0.0)
	out.append(s.playhead)
	if s.in_point >= 0.0:
		out.append(s.in_point)
	if s.out_point >= 0.0:
		out.append(s.out_point)
	out.append_array(MarkerLanes.snap_times(self, s, t0, t1))
	var excluded: Dictionary = {}
	for id: String in exclude:
		excluded[id] = true
	for t: Track in s.all_tracks():
		if t.hidden:
			continue
		var i: int = t.index_of_first_visible(t0)
		var n: int = 0
		while i < t.clips.size() and t.clips[i].start < t1 and n < 400:
			var c: Clip = t.clips[i]
			if not excluded.has(c.id):
				out.append(c.start)
				out.append(c.end())
			i += 1
			n += 1
	out.append_array(ViewCuts.snap_times(self, s, t0, t1, excluded))
	out.append_array(ObjectSnap.snap_times(self, s, t0, t1, excluded))
	out.sort()
	return out


func clips_in_marquee(r: Rect2) -> PackedStringArray:
	var s: Sequence = seq()
	if s == null:
		return PackedStringArray()
	var boxed: PackedStringArray = Filter.keep_shown(self, Hit.marquee_clips(geometry(), lanes(), r))
	return Verbs.MoveRule.pick(s, boxed) if linked_selection else boxed


func _track_selected(track_id: String) -> bool:
	var s: Sequence = seq()
	return s != null and s.selected_track_ids.has(track_id)


func click_select_track(track_id: String, mods: Dictionary) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or s.track_by_id(track_id) == null:
		return
	var mode: String = "replace"
	if bool(mods.get("ctrl", false)) or bool(mods.get("shift", false)):
		mode = "toggle"
	if mode == "replace":
		Verbs.select(d, s, PackedStringArray(), "replace")
	Verbs.select_tracks(d, s, PackedStringArray([track_id]), mode)


func click_select(clip_id: String, mods: Dictionary) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var c: Clip = s.clip_by_id(clip_id)
	if c == null:
		return
	var ids: PackedStringArray = PackedStringArray([clip_id])
	var ctrl: bool = bool(mods.get("ctrl", false))
	var shift: bool = bool(mods.get("shift", false))
	var alt: bool = bool(mods.get("alt", false))
	Verbs.select_tracks(d, s, PackedStringArray(), "replace")
	var family: bool = (linked_selection or LinkAsOne.acts_as_one(s, c)) and not alt and not (ctrl and shift)
	var picked: PackedStringArray = ids.duplicate()
	if family:
		ids = Verbs.MoveRule.pick(s, ids)
	if shift:
		var keep: PackedStringArray = s.picked_clip_ids.duplicate()
		for id: String in picked:
			if not keep.has(id):
				keep.append(id)
		Verbs.select(d, s, ids, "toggle", keep)
	else:
		Verbs.select(d, s, ids, "replace", picked)
	Verbs.MoveRule.mark_lone(s, picked if alt or (ctrl and shift) else PackedStringArray())


func gesture_ended() -> void:
	_pressed_button = ""
	Solo.after_gesture(self, doc(), seq())
	_update_cursor()
	queue_redraw()
	_overlay.queue_redraw()


func _on_mouse_exit() -> void:
	if not drag.in_progress():
		hover = {}
		_overlay.queue_redraw()


func _cursor_for_tool(tool: String, h: Dictionary) -> Control.CursorShape:
	if not doc_tracking_empty() and not TrackerBand.hit(self, get_local_mouse_position()).is_empty():
		return Control.CURSOR_HSIZE
	if Censor.claims_cursor(self, tool, h):
		return Censor.cursor_shape(self, tool, h)
	if tool == RealignTool.DRAG_MODE and h.get("clip", null) != null:
		return RealignTool.cursor_shape()
	if tool == "hand":
		return Control.CURSOR_DRAG
	if tool == "zoom":
		return Control.CURSOR_CROSS
	if tool == "razor":
		return Razor.cursor(self)
	if tool == "type":
		return Control.CURSOR_IBEAM
	if tool == "pen":
		return Control.CURSOR_CROSS
	var zone: String = String(h.get("zone", ""))
	if zone == "ruler" and not String(h.get("marker_edge", "")).is_empty() and Input.is_key_pressed(KEY_ALT):
		return Control.CURSOR_HSIZE
	if zone == "ruler" and h.get("marker", null) != null:
		return Control.CURSOR_POINTING_HAND
	if zone == "header_edge" or zone == "hscroll":
		return Control.CURSOR_HSIZE
	if zone == "divider" or bool(h.get("grip", false)):
		return Control.CURSOR_VSIZE
	if zone == "lane":
		if String(h.get("fade", "")) != "":
			return Control.CURSOR_HSIZE
		if bool(h.get("level", false)):
			return Control.CURSOR_HSIZE if bool(h.get("band_key", false)) else Control.CURSOR_VSIZE
		if String(h.get("tr_edge", "")) != "" or String(h.get("free_edge", "")) != "":
			return Control.CURSOR_HSIZE
		if not (h.get("free", {}) as Dictionary).is_empty():
			return Control.CURSOR_POINTING_HAND
		if String(h.get("edge", "")) != "":
			return Control.CURSOR_HSPLIT
		if h.get("clip", null) != null:
			return Control.CURSOR_POINTING_HAND
	return Control.CURSOR_ARROW


func _update_cursor() -> void:
	var tool: String = TrackerBand.timeline_tool(Session.tool_id)
	var shape: Control.CursorShape = _cursor_for_tool(tool, hover)
	if ToolCursors.wants(tool, String(hover.get("zone", ""))) and TOOL_POINTER_SHAPES.has(shape):
		shape = ToolCursors.claim(tool)
	mouse_default_cursor_shape = shape


func _mods(e: InputEventWithModifiers) -> Dictionary:
	return Drag.mods_of(e)


const PARENT_UI := "res://modules/core_panels/parent_ui.gd"


func _on_input(event: InputEvent) -> void:
	if trim_anim != null and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		trim_anim.call("finish")
	if bool(load(PARENT_UI).call("timeline_input", self, event)):
		accept_event()
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if drag.in_progress():
			if String(drag.get("mode")) == "move" and not get_global_rect().has_point(mm.global_position) and bool(load(SOUND_WELL).call("hand_off", self, drag, mm.global_position)):
				accept_event()
				return
			if bool(drag.call("motion", mm.position, _mods(mm))):
				queue_redraw()
				_overlay.queue_redraw()
			accept_event()
			return
		Censor.hover(self, mm.position)
		RealignTool.hover(self, mm.position)
		var h: Dictionary = hit_at(mm.position)
		var changed: bool = String(h.get("zone", "")) != String(hover.get("zone", "")) or h.get("clip", null) != hover.get("clip", null) or String(h.get("edge", "")) != String(hover.get("edge", "")) or String(h.get("button", "")) != String(hover.get("button", "")) or h.get("track", null) != hover.get("track", null) or bool(h.get("level", false)) != bool(hover.get("level", false)) or bool(h.get("band_key", false)) != bool(hover.get("band_key", false)) or bool(h.get("transition", false)) != bool(hover.get("transition", false)) or String(h.get("tr_edge", "")) != String(hover.get("tr_edge", "")) or FreeTransition.id_of(h.get("free", {})) != FreeTransition.id_of(hover.get("free", {})) or String(h.get("free_edge", "")) != String(hover.get("free_edge", "")) or String(h.get("fade", "")) != String(hover.get("fade", "")) or h.get("marker", null) != hover.get("marker", null) or String(h.get("marker_edge", "")) != String(hover.get("marker_edge", ""))
		hover = h
		if changed:
			_update_cursor()
			_overlay.queue_redraw()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			if mb.pressed:
				_on_wheel(mb)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				drag.call("begin", "pan", hit_at(mb.position), mb.position, _mods(mb))
			else:
				drag.call("release", mb.position, _mods(mb))
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_press(mb)
			else:
				if drag.in_progress():
					Edit.release_left(self, mb.position, _mods(mb))
				elif not _pressed_button.is_empty():
					_pressed_button = ""
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_on_right(mb)
			accept_event()


func _on_wheel(mb: InputEventMouseButton) -> void:
	var h: Dictionary = hit_at(mb.position)
	var zone: String = String(h.get("zone", ""))
	var steps: float = -1.0 if (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT) else 1.0
	var ctrl: bool = mb.ctrl_pressed or mb.meta_pressed
	if ctrl and zone == "header":
		var t: Track = h.get("track", null)
		if t != null and not bool(h.get("nest", false)):
			var delta: float = -steps * 10.0
			if mb.shift_pressed:
				_bump_kind_heights(t.kind, delta * 3.0)
			else:
				var cur: float = lane_height_of(t.id)
				set_track_field(t.id, "height", Lanes.clamp_height(cur + delta) / maxf(Tk.ui_scale, 0.01))
		return
	if ctrl or mb.alt_pressed:
		if zone == "lane" or zone == "ruler" or zone == "empty" or zone == "new_track":
			set_pps(pps * (WHEEL_ZOOM if steps < 0.0 else 1.0 / WHEEL_ZOOM), mb.position.x)
		return
	var vertical: bool = mb.shift_pressed
	if zone == "header" or zone == "corner":
		vertical = not vertical
	if mb.button_index == MOUSE_BUTTON_WHEEL_LEFT or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
		vertical = false
	var step_px: float = float(Tk.px(48.0)) * steps
	_auto_fit = false
	if String(h.get("set", "")) == "band" and vertical:
		_band_scroll.call("scroll_by", 0.0, step_px)
		return
	if vertical:
		_scroll.call("scroll_by", 0.0, step_px)
	else:
		_scroll.call("scroll_by", step_px, 0.0)


func _bump_kind_heights(kind: String, delta: float) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var cmds: Array[Command] = []
	for t: Track in s.tracks_of_kind(kind):
		var cur: float = lane_height_of(t.id)
		cmds.append(TrackCmds.SetTrackField.new(s.id, t.id, "height", Lanes.clamp_height(cur + delta) / maxf(Tk.ui_scale, 0.01)))
	Verbs.run(d, "Track heights", cmds)


func _on_press(mb: InputEventMouseButton) -> void:
	end_rename(true)
	selected_gap = {}
	var h: Dictionary = hit_at(mb.position)
	var zone: String = String(h.get("zone", ""))
	var mods: Dictionary = _mods(mb)
	var d: Project = doc()
	var s: Sequence = seq()
	var tool: String = TrackerBand.timeline_tool(Session.tool_id)
	if zone == "lane" and bool(load(PARENT_UI).call("timeline_press", self, h, mods, mb.position)):
		return
	if zone == "lane" and not (bool(mods.get("alt", false)) and not String(h.get("edge", "")).is_empty()) and Groups.press(self, mb.position, mods):
		return
	if zone == "lane" and TrackerBand.press(self, mb.position, mods):
		return
	if zone == "lane" and Censor.press(self, mb.position, mods):
		return
	if zone == "lane" and RealignTool.press(self, mb.position, mods):
		return
	if zone == "lane" and SpeedBand.press(self, mb.position, mods):
		return
	if zone == "lane" and Keys.press(self, mb.position, mods):
		return
	if zone == "header_edge":
		drag.call("begin", "header_w", h, mb.position, mods)
		return
	if zone == "divider":
		drag.call("begin", "divider", h, mb.position, mods)
		return
	if zone == "hscroll":
		minimap_jump(mb.position.x)
		drag.call("begin", "hscroll", h, mb.position, mods)
		return
	if zone == "marker_lane" and MarkerLanes.press(self, h, mb):
		return
	if zone == "ruler" or zone == "marker_lane":
		var m: Marker = h.get("marker", null)
		if m != null:
			if mb.double_click:
				open_marker_editor(m.id)
				return
			if bool(mods.get("alt", false)) and not String(h.get("marker_edge", "")).is_empty():
				set_marker_selection(PackedStringArray([m.id]), false)
				drag.call("begin", "marker_len", h, mb.position, mods)
				return
			if bool(mods.get("shift", false)):
				set_marker_selection(PackedStringArray([m.id]), true)
			elif not selected_marker_ids.has(m.id):
				set_marker_selection(PackedStringArray([m.id]), false)
			drag.call("begin", "marker", h, mb.position, mods)
			return
		if s != null and (not s.markers.is_empty() or bool(mods.get("ctrl", false))) and bool(h.get("marker_band", false)):
			drag.call("begin", "marker_range", h, mb.position, mods)
			return
		drag.call("begin", "scrub", h, mb.position, mods)
		return
	if zone == "header":
		var t: Track = h.get("track", null)
		if t == null or bool(h.get("nest", false)):
			return
		if bool(h.get("grip", false)):
			drag.call("begin", "track_h", h, mb.position, mods)
			return
		var button: String = String(h.get("button", ""))
		if not button.is_empty():
			_pressed_button = button
			_toggle_header_button(t, button)
			return
		if mb.double_click:
			begin_rename(t.id)
			return
		click_select_track(t.id, mods)
		if String(h.get("set", "")) == "band":
			drag.call("begin", "band_reorder", h, mb.position, mods)
		else:
			drag.call("begin", "track_reorder", h, mb.position, mods)
		focused = true
		queue_redraw()
		return
	if zone == "new_track" or zone == "empty" or zone == "outside" or zone == "corner":
		if zone == "empty" or zone == "new_track":
			if d != null and s != null and not mods.get("shift", false):
				Verbs.select(d, s, PackedStringArray(), "replace")
			drag.call("begin", "range", h, mb.position, mods)
		return
	if zone != "lane" or d == null or s == null:
		return
	var c: Clip = h.get("clip", null)
	var t2: Track = h.get("track", null)
	if bool(h.get("nest", false)):
		if c != null and mb.double_click:
			var owner: Clip = (h["lane"] as Dictionary).get("owner", null)
			if owner != null:
				nest_open_requested.emit(owner.sequence_id, owner.id)
		return
	if tool == "hand":
		drag.call("begin", "pan", h, mb.position, mods)
		return
	if tool == "zoom":
		if bool(mods.get("alt", false)):
			set_pps(pps / 1.45, mb.position.x)
		else:
			set_pps(pps * 1.45, mb.position.x)
		return
	if tool == "razor":
		Razor.click(self, h, mods)
		return
	if tool == "type":
		if mb.double_click:
			return
		var tt: float = _snapped_click_time(h)
		var track_id: String = t2.id if t2 != null else ""
		var made: String = Verbs.new_title_clip(d, s, track_id, tt)
		if made.is_empty():
			Events.toast("No room for a title there")
		else:
			var ec: Object = _bus_panel("effect_controls")
			if ec != null and ec.has_method("focus_text"):
				ec.call("focus_text")
		return
	if tool == "track_select":
		MoveTool.press(self, h, mb.position, mods)
		return
	var ft_hit: Dictionary = h.get("free", {})
	if not ft_hit.is_empty() and tool == "select" and t2 != null and not t2.locked:
		if mb.double_click:
			open_free_picker(t2.id, FreeTransition.id_of(ft_hit))
			return
		TrOps.select_free(d, s, t2.id, FreeTransition.id_of(ft_hit))
		var fe: String = String(h.get("free_edge", ""))
		h["edge"] = fe if not fe.is_empty() else "body"
		drag.call("begin", "free_tr", h, mb.position, mods)
		return
	if c == null:
		if bool(h.get("playhead", false)):
			drag.call("begin", "scrub", h, mb.position, mods)
			return
		if not bool(mods.get("shift", false)):
			Verbs.select(d, s, PackedStringArray(), "replace")
		drag.call("begin", "range", h, mb.position, mods)
		return
	if bool(h.get("transition", false)) and tool == "select" and t2 != null and not t2.locked:
		if mb.double_click:
			TrOps.open_picker(self, c.id, String(h.get("tr_side", "in")))
			return
		var tr_edge: String = String(h.get("tr_edge", ""))
		if not tr_edge.is_empty():
			h["edge"] = tr_edge
			drag.call("begin", "transition", h, mb.position, mods)
			return
		Verbs.select_transition(d, s, c.id, String(h.get("tr_side", "in")))
		load("res://modules/core_panels/monitor_handles.gd").call("focus_transition", c.id, s)
		h["edge"] = "body"
		drag.call("begin", "transition", h, mb.position, mods)
		return
	if tool == "select" and not String(h.get("fade", "")).is_empty() and t2 != null and not t2.locked and not mb.double_click:
		h["edge"] = String(h.get("fade", ""))
		drag.call("begin", "fade", h, mb.position, mods)
		return
	if mb.double_click:
		if c.is_nest():
			nest_open_requested.emit(c.sequence_id, c.id)
		else:
			clip_double_clicked.emit(c.id)
		return
	var edge: String = String(h.get("edge", ""))
	if tool == "pen" or (bool(mods.get("ctrl", false)) and bool(h.get("level", false))):
		_pen_click(c, t2, h, mods)
		return
	if bool(h.get("level", false)) and tool == "select" and (t2.is_sound(c) or t2.is_picture(c)):
		_begin_level_drag(c, t2, h, mb.position, mods)
		return
	if s.group_locked(c):
		click_select(c.id, mods)
		if not edge.is_empty() or tool != "select":
			Events.toast("This clip is in a locked group, unlock the group to move or trim it")
		return
	if tool == "slip":
		drag.call("begin", "slip", h, mb.position, mods)
		return
	if tool == "slide":
		SlideTool.press(self, h, mb.position, mods)
		return
	if not edge.is_empty() and t2 != null and not t2.locked:
		if tool == "roll":
			drag.call("begin", "roll", h, mb.position, mods)
			return
		if tool == "ripple" or bool(mods.get("ctrl", false)):
			drag.call("begin", "ripple", h, mb.position, mods)
			return
		if tool == "rate":
			drag.call("begin", "rate", h, mb.position, mods)
			return
		drag.call("begin", "trim", h, mb.position, mods)
		return
	if t2 != null and t2.locked:
		click_select(c.id, mods)
		return
	if Solo.locks_clip(d, s, c):
		click_select(c.id, mods)
		Events.toast(Solo.LOCK_TEXT)
		return
	drag.call("begin", "move", h, mb.position, mods)


func _snapped_click_time(h: Dictionary) -> float:
	var t: float = float(h.get("t", 0.0))
	if not snapping:
		return t
	return snap_near(snap_targets(PackedStringArray()), t)


func _pen_click(c: Clip, t: Track, h: Dictionary, mods: Dictionary) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or t == null:
		return
	var path: String = "audio.volume" if t.is_sound(c) else "transform.opacity"
	var time: float = float(h.get("t", 0.0))
	var frame_t: float = round(time * fps()) / fps()
	if bool(mods.get("alt", false)):
		return
	Verbs.toggle_keyframe(d, s, c.id, path, frame_t)


func _begin_level_drag(c: Clip, t: Track, h: Dictionary, at: Vector2, mods: Dictionary) -> void:
	var lane: Dictionary = h["lane"]
	var inner_h: float = float(lane["h"]) - Paint.name_row_h() - 4.0
	h["inner_h"] = inner_h
	drag.call("begin", "level", h, at, mods)
	if t.is_sound(c):
		drag.call("begin_level", c, "audio.volume", 0.0, 2.0, inner_h)
	else:
		drag.call("begin_level", c, "transform.opacity", 0.0, 1.0, inner_h)


func _toggle_header_button(t: Track, button: String) -> void:
	if button == "mute":
		set_track_field(t.id, "muted", not t.muted)
	elif button == "solo":
		set_track_field(t.id, "solo", not t.solo)
	elif button == "lock":
		set_track_field(t.id, "locked", not t.locked)
	elif button == "target":
		set_track_field(t.id, "targeted", not t.targeted)
	elif button == "sync":
		set_track_field(t.id, "sync_lock", not t.sync_lock)
	elif button == "pin":
		pin_track(t.id, not t.pinned)
	elif button == "view":
		set_track_field(t.id, "view_hidden", not t.view_hidden)


func _on_right(mb: InputEventMouseButton) -> void:
	var h: Dictionary = hit_at(mb.position)
	var zone: String = String(h.get("zone", ""))
	var at: Vector2 = get_global_mouse_position()
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	if zone == "lane" and Groups.right(self, mb.position):
		return
	if zone == "lane" and Censor.right(self, mb.position):
		return
	if zone == "lane" and SpeedBand.right(self, mb.position):
		return
	if zone == "lane" and Keys.right(self, mb.position):
		return
	if zone == "header":
		var t: Track = h.get("track", null)
		if t == null or bool(h.get("nest", false)):
			return
		var m: Control = PmMenu.open(self, header_items(t, String(h.get("set", "")) == "band"), at)
		if m != null and m.is_inside_tree():
			m.connect("picked", _on_header_menu.bind(t.id))
		return
	if zone == "divider":
		var items: Array = [PmMenu.item("band_top", "Send the pinned band to the top") if band_at_bottom() else PmMenu.item("band_bottom", "Send the pinned band to the bottom"), PmMenu.check_item("band_collapsed", "Collapsed", band_collapsed())]
		var m2: Control = PmMenu.open(self, items, at)
		if m2 != null and m2.is_inside_tree():
			m2.connect("picked", _on_band_menu)
		return
	if (zone == "marker_lane" or zone == "corner") and MarkerLanes.right(self, h, at):
		return
	if zone == "ruler" or zone == "marker_lane":
		var mk: Marker = h.get("marker", null)
		if mk != null:
			if not selected_marker_ids.has(mk.id):
				set_marker_selection(PackedStringArray([mk.id]), false)
			var items2: Array = marker_menu_items(mk)
			var m3: Control = PmMenu.open(self, items2, at)
			if m3 != null and m3.is_inside_tree():
				m3.connect("picked", _on_marker_menu.bind(mk.id))
			return
		var items3: Array = [PmMenu.item("add_marker", "Add marker here", Cmd.keys_text("marker.add")), PmMenu.item("mark_in", "Mark in here", Cmd.keys_text("mark.in")), PmMenu.item("mark_out", "Mark out here", Cmd.keys_text("mark.out")), PmMenu.item("clear_in_out", "Clear in and out", Cmd.keys_text("mark.clear_both")), PmMenu.separator(), PmMenu.item("tag_range", "Tag in to out..."), PmMenu.item("new_marker_lane", "New marker lane", "", "marker"), PmMenu.separator()]
		items3.append_array(FenceLook.menu_items(seq(), float(h.get("t", 0.0))))
		var m4: Control = PmMenu.open(self, items3, at)
		if m4 != null and m4.is_inside_tree():
			m4.connect("picked", _on_ruler_menu.bind(float(h.get("t", 0.0))))
		return
	if zone == "lane" and not bool(h.get("nest", false)):
		var c: Clip = h.get("clip", null)
		var ctrl: bool = mb.ctrl_pressed or mb.meta_pressed
		if c != null:
			if not s.selected_clip_ids.has(c.id):
				Verbs.select(d, s, Verbs.MoveRule.pick(s, PackedStringArray([c.id]), linked_selection and not ctrl), "replace", PackedStringArray([c.id]))
			if not String(h.get("fade", "")).is_empty():
				Edit.open_fade_menu(self, c, String(h.get("fade", "")), at)
				return
			var m5: Control = PmMenu.open(self, Edit.clip_items(self, c, float(h.get("t", 0.0)), _clip_menu_items(c, ctrl)), at)
			if m5 != null and m5.is_inside_tree():
				m5.connect("picked", _on_clip_menu.bind(c.id, float(h.get("t", 0.0))))
				Stacks.open_card(self, m5, h, at)
		else:
			var t3: Track = h.get("track", null)
			var pictures: String = clip_pictures()
			var pic_sub: Array = [PmMenu.check_item("pictures:strip", "Filmstrip", pictures == "strip"), PmMenu.check_item("pictures:head", "First frame only", pictures == "head"), PmMenu.check_item("pictures:none", "None", pictures == "none")]
			var items4: Array = []
			if not s.markers.is_empty():
				items4.append(PmMenu.item("text_from_marks", "Text boxes from marks", "", "type"))
				items4.append(PmMenu.separator())
			items4.append_array([PmMenu.item("paste", "Paste here", Cmd.keys_text("edit.paste")), PmMenu.item("add_marker", "Add marker here", Cmd.keys_text("marker.add")), PmMenu.separator(), PmMenu.item("add_track", "Add " + (t3.kind if t3 != null else "video") + " track"), PmMenu.item("close_gap", "Close gap"), PmMenu.separator(), PmMenu.sub_item("pictures", "Clip pictures", pic_sub)])
			var m6: Control = PmMenu.open(self, items4, at)
			if m6 != null and m6.is_inside_tree():
				m6.connect("picked", _on_empty_menu.bind(t3.id if t3 != null else "", float(h.get("t", 0.0))))


func _clip_menu_items(c: Clip, lane_only: bool) -> Array:
	var d: Project = doc()
	var items: Array = []
	if lane_only:
		var only: Dictionary = PmMenu.item("scope", "This lane only")
		only["disabled"] = true
		items.append(only)
		items.append(PmMenu.separator())
	var s_sub: Sequence = seq()
	if d != null and s_sub != null and Subtitles.is_text_clip(d, c):
		items.append(PmMenu.sub_item("sub_character", "Subtitle: character", CharMenu.items(d, CharMenu.Library.current_of(d, s_sub, Verbs.selection(s_sub)), true)))
		items.append(PmMenu.item("sub_phrase", "Subtitle: type the phrase", "", "type"))
		items.append(PmMenu.item("sub_pop_in", "Subtitle: pop in"))
		items.append(PmMenu.item("sub_pop_out", "Subtitle: pop out"))
		items.append(PmMenu.item("sub_pop_where", "Subtitle: pop in or out on a chosen box"))
		items.append(PmMenu.item("sub_pop_clear", "Subtitle: clear the animation"))
		items.append(PmMenu.item("sub_anim_library", "Subtitle: animation presets"))
		items.append(PmMenu.item("sub_travel", "Subtitle: how it moves up for another speaker"))
		items.append(PmMenu.item("sub_style", "Subtitle: text style"))
		items.append(PmMenu.separator())
	elif s_sub != null and not s_sub.markers.is_empty():
		items.append(PmMenu.item("text_from_marks", "Text boxes from marks", "", "type"))
		items.append(PmMenu.separator())
	items.append(PmMenu.item("cut", "Cut", Cmd.keys_text("edit.cut")))
	items.append(PmMenu.item("copy", "Copy", Cmd.keys_text("edit.copy")))
	items.append(PmMenu.item("paste_attributes", "Paste attributes", Cmd.keys_text("edit.paste_attributes")))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("add_edit", "Add edit here", Cmd.keys_text("edit.add_edit")))
	items.append(PmMenu.check_item("enable", "Enabled", c.enabled, Cmd.keys_text("clip.enable")))
	items.append(PmMenu.item("link", "Unlink" if not c.link_id.is_empty() else "Link", Cmd.keys_text("clip.link")))
	if s_sub != null and not c.link_id.is_empty():
		var one: bool = LinkAsOne.is_on(s_sub, c.link_id)
		items.append(PmMenu.check_item("as_one", LinkAsOne.AS_ONE_LABEL, one))
		if one:
			items.append(PmMenu.check_item("as_one_fill", LinkAsOne.FILL_LABEL, LinkAsOne.fills(s_sub, c.link_id)))
	items.append(PmMenu.item("group", "Ungroup" if not c.group_id.is_empty() else "Group", Cmd.keys_text("clip.group")))
	items.append_array(Groups.group_items(seq(), c))
	items.append(PmMenu.item("nest", "Nest selection", Cmd.keys_text("clip.nest")))
	if c.is_nest():
		items.append(PmMenu.separator())
		items.append_array(Groups.nest_items(d, c))
	items.append(PmMenu.separator())
	var sub: Array = [PmMenu.check_item("colour:-1", "None", c.colour < 0)]
	for i: int in Tk.LABEL_NAMES.size():
		sub.append(PmMenu.check_item("colour:" + str(i), Tk.label_name(i), c.colour == i))
	items.append(PmMenu.sub_item("colour", "Label colour", sub))
	items.append_array(Warn.menu_items(self, c))
	items.append_array(Filter.clip_menu_items(self, c))
	items.append(PmMenu.item("transition", "Remove transition" if not c.transition_in.is_empty() else "Add default transition", Cmd.keys_text("seq.default_video_transition")))
	items.append_array(transition_menu_items(c))
	items.append_array(load("res://modules/core_panels/pair_sync.gd").call("clip_menu_items", c))
	items.append_array(load(PARENT_UI).call("clip_menu_items", c))
	items.append_array(load("res://modules/core_panels/view_hide_ui.gd").call("clip_menu_items", c))
	items.append(PmMenu.item("rename", "Rename"))
	items.append(PmMenu.item("speed", "Speed and duration", Cmd.keys_text("clip.speed")))
	items.append(SpeedBand.menu_item(c))
	var s_menu: Sequence = seq()
	var tr_kind: Track = s_menu.track_of(c.id) if s_menu != null else null
	if s_menu != null and ((tr_kind != null and tr_kind.is_sound(c)) or s_menu.linked(c).size() > 1):
		items.append(PmMenu.item("edit_audio", "Edit audio", "", "audio"))
		items.append(PmMenu.item("wave_look", "Wave look..."))
	items.append_array(load("res://modules/core_panels/bin_views/made_items.gd").call("clip_menu_items", c))
	items.append(PmMenu.item("reveal", "Reveal in bin"))
	for sys_id: String in ["file.reveal", "file.edit_original", "file.properties"]:
		if Cmd.has(sys_id):
			items.append(PmMenu.item("cmd:" + sys_id, Cmd.label(sys_id), Cmd.keys_text(sys_id)))
	items.append_array(Stacks.menu_items(self, c))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("delete", "Delete", Cmd.keys_text("edit.delete"), "trash"))
	items.append(PmMenu.item("ripple_delete", "Ripple delete", Cmd.keys_text("edit.ripple_delete")))
	if d == null:
		return items
	return items


func _on_clip_menu(id: String, clip_id: String, t: float) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var c: Clip = s.clip_by_id(clip_id)
	if c == null:
		return
	if Edit.on_clip_menu(self, id, clip_id, t):
		return
	if SpeedBand.on_clip_menu(self, id, clip_id):
		return
	if CharMenu.on_pick(self, d, s, Verbs.selection(s) if s.selected_clip_ids.has(clip_id) else PackedStringArray([clip_id]), id):
		return
	if bool(load("res://modules/core_panels/pair_sync.gd").call("on_clip_menu", id, clip_id)):
		return
	if bool(load("res://modules/core_panels/parent_ui.gd").call("on_clip_menu", id, clip_id)):
		return
	if bool(load("res://modules/core_panels/view_hide_ui.gd").call("on_clip_menu", id, clip_id)):
		return
	if bool(load("res://modules/core_panels/bin_views/made_items.gd").call("on_clip_menu", self, id, clip_id)):
		return
	if Stacks.on_clip_menu(self, id, clip_id):
		return
	if Filter.on_clip_menu(self, id, clip_id):
		return
	if Warn.on_clip_menu(self, id, clip_id, t):
		return
	if id.begins_with("cmd:"):
		Cmd.run(id.substr(4))
		return
	if id == "cut":
		Cmd.run("edit.cut")
	elif id == "copy":
		Cmd.run("edit.copy")
	elif id == "text_from_marks":
		text_boxes_from_marks()
	elif id == "sub_phrase":
		subtitle_phrase_form()
	elif id == "sub_pop_in" or id == "sub_pop_out":
		Subtitles.apply_pop(d, s, Verbs.selection(s), "in" if id == "sub_pop_in" else "out")
	elif id == "sub_style":
		subtitle_style_form()
	elif id == "sub_pop_where":
		subtitle_pop_form()
	elif id == "sub_pop_clear":
		Subtitles.clear_pops(d, s, Verbs.selection(s))
	elif id == "sub_anim_library":
		subtitle_anim_library_form()
	elif id == "sub_travel":
		subtitle_travel_form()
	elif id == "paste_attributes":
		Cmd.run("edit.paste_attributes")
	elif id == "add_edit":
		Verbs.razor(d, s, t, true, false)
	elif id == "enable":
		Verbs.enable_selection(d, s, not c.enabled)
	elif id == "link":
		if c.link_id.is_empty():
			Verbs.link_selection(d, s)
		else:
			Verbs.unlink_selection(d, s)
	elif id == "as_one":
		Verbs.set_link_as_one(d, s, clip_id, not LinkAsOne.is_on(s, c.link_id))
	elif id == "as_one_fill":
		Verbs.set_link_fill(d, s, clip_id, not LinkAsOne.fills(s, c.link_id))
	elif id == "group":
		if c.group_id.is_empty():
			Verbs.group_selection(d, s)
		else:
			Verbs.ungroup_selection(d, s)
	elif id == "nest":
		Verbs.nest_selection(d, s, "Nested sequence")
	elif id == "see_inside" or id == "hear_audio" or id == "show_audio_below":
		Verbs.set_nest_option(d, s, clip_id, id, not bool(c.nest.get(id, id == "hear_audio")))
	elif Groups.owns_clip_menu_id(id):
		Groups.on_clip_menu(self, d, s, c, id)
	elif id == "open_nest":
		nest_open_requested.emit(c.sequence_id, c.id)
	elif id == "unnest":
		Verbs.unnest_selection(d, s)
	elif id.begins_with("colour:"):
		var cmds: Array[Command] = []
		for sid: String in Verbs.selection(s):
			cmds.append(ClipCmds.SetClipField.new(s.id, sid, "colour", int(id.substr(7))))
		Verbs.run(d, "Label colour", cmds)
	elif id == TR_PICK_ID:
		var spot: Dictionary = transition_spot(s.track_of(c.id), t, c)
		if not spot.is_empty():
			TrOps.open_picker(self, (spot["clip"] as Clip).id, String(spot["side"]))
	elif id == "transition":
		if c.transition_in.is_empty():
			var tr_c: Track = s.track_of(clip_id)
			Verbs.set_transition(d, s, clip_id, TrRegistry.shared().call("default_spec", c.duration) if tr_c != null and tr_c.is_picture(c) else {"kind": "dissolve", "duration": minf(1.0, c.duration * 0.5), "align": "centre"})
		else:
			Verbs.set_transition(d, s, clip_id, {})
	elif id == "rename":
		_rename_clip(c)
	elif id == "speed":
		Cmd.run("clip.speed")
	elif id == "reveal":
		var bin: Object = _bus_panel("bin")
		if bin != null:
			bin.call("reveal", c.media_id)
	elif id == "wave_look":
		WaveSheet.open(self, get_global_mouse_position())
	elif id == "edit_audio":
		var editor: Node = get_tree().root.find_child("EditorScreen", true, false)
		if editor != null and editor.get("dock") != null:
			(editor.get("dock") as Node).call("show_panel", "audio_editor")
		var ae: Object = _bus_panel("audio_editor")
		if ae != null and ae.has_method("refresh"):
			ae.call("refresh")
	elif id == "delete":
		Verbs.delete_selection(d, s, false)
	elif id == "ripple_delete":
		Verbs.delete_selection(d, s, true)


func text_boxes_from_marks() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var spans: Array[Dictionary] = Subtitles.spans_from_markers(s)
	if spans.is_empty():
		Events.notice("No marks to use", "Add markers on the ruler first. Each marker becomes one text box that runs until the next marker.")
		return
	var fields: Array[Dictionary] = SubtitleForms.marks_fields(_style_choices(), doc())
	MarkerLanes.text_length_default(s, marker_selection(), fields)
	var answered: Signal = PmUI.form(self, "Text boxes from " + str(spans.size()) + " marks", fields, "Make boxes", "Cancel")
	answered.connect(_on_text_from_marks_answered.bind(spans))


func _on_text_from_marks_answered(result: Variant, _spans: Array[Dictionary]) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var r: Dictionary = result
	var style: Dictionary = _style_props(int(r.get("style", 0)))
	var ids: PackedStringArray = SubtitleForms.make_from_marks(d, s, r, style)
	if not ids.is_empty():
		Verbs.select(d, s, ids, "replace")


func _style_presets() -> Array[Dictionary]:
	var d: Project = doc()
	var out: Array[Dictionary] = []
	if d != null:
		out.append_array(Presets.list_project(d, "text_style"))
	out.append_array(Presets.list_user("text_style"))
	return out


func _style_choices() -> Array:
	var out: Array = ["Subtitle default"]
	for p: Dictionary in _style_presets():
		out.append(String(p.get("label", "Style")))
	return out


func _style_props(index: int) -> Dictionary:
	if index <= 0:
		return {}
	var presets: Array[Dictionary] = _style_presets()
	if index - 1 >= presets.size():
		return {}
	var payload: Dictionary = presets[index - 1].get("payload", {})
	return (payload.get("props", {}) as Dictionary).duplicate(true)


func subtitle_phrase_form() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var ids: PackedStringArray = Verbs.selection(s)
	var count: int = Subtitles.sorted_text_clips(d, s, ids).size()
	if count == 0:
		return
	var fields: Array[Dictionary] = [{"key": "phrase", "label": "Phrase", "type": "string", "default": ""}, {"key": "one_word", "label": "One word per box", "type": "bool", "default": false}, {"key": "alternate", "label": "Alternate two colours", "type": "bool", "default": false}, {"key": "colour_a", "label": "Colour A", "type": "string", "default": "#ffffff"}, {"key": "colour_b", "label": "Colour B", "type": "string", "default": "#ffd200"}]
	fields.append_array(SubtitleForms.split_fields())
	var answered: Signal = PmUI.form(self, "Type the phrase for " + str(count) + " boxes", fields, "Apply", "Cancel")
	answered.connect(_on_phrase_answered.bind(ids))


func _on_phrase_answered(result: Variant, ids: PackedStringArray) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var r: Dictionary = result
	var phrase: String = String(r.get("phrase", "")).strip_edges()
	if phrase.is_empty():
		return
	var ca: Color = Color.html(String(r.get("colour_a", "#ffffff"))) if Color.html_is_valid(String(r.get("colour_a", ""))) else Color.WHITE
	var cb: Color = Color.html(String(r.get("colour_b", "#ffd200"))) if Color.html_is_valid(String(r.get("colour_b", ""))) else Color(1.0, 0.82, 0.0)
	Subtitles.map_phrase(d, s, ids, phrase, bool(r.get("one_word", false)), bool(r.get("alternate", false)), [ca.r, ca.g, ca.b, ca.a], [cb.r, cb.g, cb.b, cb.a], SubtitleForms.answer_split(r))
	if bool(r.get("one_word", false)) and Subtitles.sorted_text_clips(d, s, s.selected_clip_ids).is_empty():
		var sel: PackedStringArray = PackedStringArray()
		for tr: Track in s.video_tracks:
			if not tr.subtitle:
				continue
			for c: Clip in tr.clips:
				sel.append(c.id)
		if not sel.is_empty():
			Verbs.select(d, s, sel, "replace")


func subtitle_pop_form() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var ids: PackedStringArray = Verbs.selection(s)
	var count: int = Subtitles.sorted_text_clips(d, s, ids).size()
	if count == 0:
		return
	var answered: Signal = PmUI.form(self, "Animation for " + str(count) + " boxes", SubtitleForms.pop_fields(), "Apply", "Cancel")
	answered.connect(_on_pop_answered.bind(ids))


func _on_pop_answered(result: Variant, ids: PackedStringArray) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var d: Project = doc()
	var s: Sequence = seq()
	if d != null and s != null:
		SubtitleForms.apply_pop_answer(d, s, ids, result)


func subtitle_travel_form() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var ids: PackedStringArray = Verbs.selection(s)
	if Subtitles.sorted_text_clips(d, s, ids).is_empty():
		return
	var answered: Signal = PmUI.form(self, "Moving up for another speaker", SubtitleForms.travel_fields(d, s, ids), "Apply", "Cancel")
	answered.connect(_on_travel_answered.bind(ids))


func _on_travel_answered(result: Variant, ids: PackedStringArray) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var d: Project = doc()
	var s: Sequence = seq()
	if d != null and s != null:
		SubtitleForms.apply_travel_answer(d, s, ids, result)


func subtitle_anim_library_form() -> void:
	var answered: Signal = PmUI.form(self, "Subtitle animation presets", SubtitleForms.manage_fields(), "Do it", "Close")
	answered.connect(_on_anim_library_answered)


func _on_anim_library_answered(result: Variant) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	Events.notice("Subtitle animations", SubtitleForms.apply_manage(result))


func subtitle_style_form() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var ids: PackedStringArray = Verbs.selection(s)
	var boxes: Array[Clip] = Subtitles.sorted_text_clips(d, s, ids)
	if boxes.is_empty():
		return
	var choices: Array = _style_choices()
	choices.append("Save this box as a new style")
	var fields: Array[Dictionary] = [{"key": "style", "label": "Style", "type": "enum", "choices": choices, "default": 0}, {"key": "name", "label": "New style name", "type": "string", "default": ""}]
	var answered: Signal = PmUI.form(self, "Text style for " + str(boxes.size()) + " boxes", fields, "Apply", "Cancel")
	answered.connect(_on_style_answered.bind(ids, boxes[0].id))


func _on_style_answered(result: Variant, ids: PackedStringArray, first_id: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var r: Dictionary = result
	var index: int = int(r.get("style", 0))
	var presets: Array[Dictionary] = _style_presets()
	if index == presets.size() + 1:
		var c: Clip = s.clip_by_id(first_id)
		if c == null:
			return
		var name_: String = String(r.get("name", "")).strip_edges()
		if name_.is_empty():
			name_ = "Style " + str(presets.size() + 1)
		Presets.save_to_project(d, Subtitles.style_from_clip(d, c, name_))
		Events.notice("Style saved", name_ + " is in this project's presets under Text style.")
		return
	var style: Dictionary = Subtitles.subtitle_style() if index == 0 else _style_props(index)
	Subtitles.apply_style(d, s, ids, style)


const TRANSITION_KIND_LABELS: Dictionary = {"dissolve": "Cross dissolve", "dip_black": "Dip to black", "dip_white": "Dip to white", "wipe_left": "Wipe left", "wipe_right": "Wipe right", "wipe_up": "Wipe up", "wipe_down": "Wipe down", "push_left": "Push left", "push_right": "Push right", "push_up": "Push up", "push_down": "Push down", "slide_left": "Slide left", "slide_right": "Slide right", "slide_up": "Slide up", "slide_down": "Slide down"}
const AUDIO_TRANSITION_KIND_LABELS: Dictionary = {"crossfade": "Crossfade"}


func open_transition_editor(clip_id: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var c: Clip = s.clip_by_id(clip_id)
	var tr: Track = s.track_of(clip_id)
	if c == null or tr == null:
		return
	var labels: Dictionary = AUDIO_TRANSITION_KIND_LABELS if tr.is_sound(c) else TRANSITION_KIND_LABELS
	var kinds: Array = labels.keys()
	var names: Array = []
	for k: String in kinds:
		names.append(String(labels[k]))
	var cur: int = maxi(kinds.find(String(c.transition_in.get("kind", ""))), 0)
	var offset: float = Clip.transition_offset(c.transition_in) if c.has_transition() else 0.5
	var align_idx: int = 1
	if offset <= 0.001:
		align_idx = 0
	elif offset >= 0.999:
		align_idx = 2
	var fields: Array[Dictionary] = [{"key": "kind", "label": "Kind", "type": "enum", "choices": names, "default": cur}, {"key": "duration", "label": "Duration (seconds)", "type": "float", "default": float(c.transition_in.get("duration", 1.0))}, {"key": "align", "label": "Sits", "type": "enum", "choices": ["After the cut", "Centred on the cut", "Before the cut"], "default": align_idx}]
	var answered: Signal = PmUI.form(self, "Transition", fields, "Apply", "Cancel")
	answered.connect(_on_transition_form.bind(clip_id, kinds))


func _on_transition_form(result: Variant, clip_id: String, kinds: Array) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var c: Clip = s.clip_by_id(clip_id)
	if c == null:
		return
	var r: Dictionary = result
	var kind: String = String(kinds[clampi(int(r.get("kind", 0)), 0, kinds.size() - 1)])
	var dur: float = clampf(float(r.get("duration", 1.0)), Clip.MIN_TRANSITION, maxf(c.duration * 2.0, Clip.MIN_TRANSITION))
	var offsets: Array = [0.0, 0.5, 1.0]
	var next: Dictionary = c.transition_in.duplicate(true)
	next["kind"] = kind
	next["duration"] = dur
	next["offset"] = float(offsets[clampi(int(r.get("align", 1)), 0, 2)])
	next.erase("align")
	Verbs.set_transition(d, s, clip_id, next)


func open_free_picker(track_id: String, ft_id: String) -> Control:
	var s: Sequence = seq()
	var tr: Track = s.track_by_id(track_id) if s != null else null
	if tr == null or tr.locked:
		return null
	var ft: Dictionary = FreeTransition.by_id(tr.free_transitions, ft_id)
	if ft.is_empty():
		return null
	return TrPicker.open(self, "Change transition", TrOps.kind_of_free(ft), Callable(self, "_free_picked").bind(track_id, ft_id))


func _free_picked(id: String, track_id: String, ft_id: String) -> void:
	TrOps.change_free(doc(), seq(), track_id, ft_id, id)


func default_transition_length() -> float:
	return float(Prefs.get_value(PREF_TRANSITION_SECONDS)) if Prefs.is_registered(PREF_TRANSITION_SECONDS) else 1.0


func free_drop_wanted(tr: Track, t: float, dur: float) -> bool:
	if tr == null or tr.locked or not tr.makes_picture():
		return false
	if not FreeTransition.at_point(tr.free_transitions, t).is_empty():
		return false
	var reach: float = maxf(dur * 0.5, Clip.MIN_TRANSITION)
	var i: int = tr.index_of_last_starting_before(t)
	for k: int in [i, i + 1]:
		if k < 0 or k >= tr.clips.size():
			continue
		var c: Clip = tr.clips[k]
		if absf(t - c.start) <= reach or absf(t - c.end()) <= reach:
			return false
	return true


func transition_spot(tr: Track, t: float, clip_hint: Clip = null) -> Dictionary:
	if tr == null:
		return {}
	var target: Clip = clip_hint
	if target == null:
		target = tr.clip_at(t)
	if target == null:
		var i: int = tr.index_of_last_starting_before(t) + 1
		if i < tr.clips.size():
			target = tr.clips[i]
	if target == null:
		return {}
	var mid: float = target.start + target.duration * 0.5
	if t > mid:
		var nxt: Clip = tr.next_clip(target)
		if nxt != null and absf(nxt.start - target.end()) <= 0.002:
			return {"clip": nxt, "side": "in", "at": nxt.start}
		if not tr.is_sound(target):
			return {"clip": target, "side": "out", "at": target.end()}
		if nxt != null:
			return {"clip": nxt, "side": "in", "at": nxt.start}
	return {"clip": target, "side": "in", "at": target.start}


func apply_transition_at(kind: String, track_id: String, t: float, clip_hint: Clip = null, preset_id: String = "") -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return false
	var tr: Track = s.track_by_id(track_id)
	if tr == null or tr.locked:
		return false
	var want: float = default_transition_length()
	if free_drop_wanted(tr, t, want):
		return not TrOps.place_free(d, s, tr.id, kind, maxf(t - want * 0.5, 0.0), want, preset_id).is_empty()
	var spot: Dictionary = transition_spot(tr, t, clip_hint)
	if spot.is_empty():
		return false
	var target: Clip = spot["clip"]
	var preset: Dictionary = TrOps.preset_by_id(preset_id) if not preset_id.is_empty() else {}
	if not preset.is_empty():
		kind = String(((preset.get("payload", {}) as Dictionary).get("transition", {}) as Dictionary).get("kind", kind))
	if String(spot["side"]) == "out":
		return TrOps.put_out(d, s, target, kind, preset, float(Prefs.get_value(PREF_TRANSITION_SECONDS)) if Prefs.is_registered(PREF_TRANSITION_SECONDS) else 1.0)
	var is_audio: bool = tr.is_sound(target)
	if is_audio and kind != "crossfade":
		kind = "crossfade"
	elif not is_audio and kind == "crossfade":
		kind = "dissolve"
	var dur: float = float(Prefs.get_value(PREF_TRANSITION_SECONDS)) if Prefs.is_registered(PREF_TRANSITION_SECONDS) else 1.0
	dur = clampf(dur, Clip.MIN_TRANSITION, maxf(target.duration, Clip.MIN_TRANSITION))
	var prev: Clip = tr.prev_clip(target)
	var offset: float = 0.5
	if prev == null or absf(prev.end() - target.start) > 0.002:
		offset = 0.0
	if dur > target.duration:
		dur = target.duration
	if not preset.is_empty():
		var plen: float = clampf(float((preset.get("payload", {}) as Dictionary).get("length", dur)), Clip.MIN_TRANSITION, maxf(target.duration, Clip.MIN_TRANSITION))
		return Verbs.set_transition(d, s, target.id, TrOps.spec_from_preset(preset, plen, offset))
	return Verbs.set_transition(d, s, target.id, TrRegistry.shared().call("make_spec", kind, dur, offset))


const TrRegistry := preload("res://engine/transition_registry.gd")
const TrOps := preload("res://modules/core_panels/transition_ops.gd")
const TrPicker := preload("res://modules/core_panels/transition_picker.gd")
const TR_PICK_ID := "transition_pick"


func transition_target(c: Clip, t: float) -> Clip:
	var s: Sequence = seq()
	var tr: Track = s.track_of(c.id) if s != null else null
	if tr == null or t <= c.start + c.duration * 0.5:
		return c
	var nxt: Clip = tr.next_clip(c)
	if nxt != null and absf(nxt.start - c.end()) <= 0.002:
		return nxt
	return c


func transition_menu_items(c: Clip) -> Array:
	var s: Sequence = seq()
	var tr: Track = s.track_of(c.id) if s != null else null
	if tr == null or tr.locked or not tr.is_picture(c):
		return []
	var spot: Dictionary = transition_spot(tr, float(hover.get("t", c.start)) if hover.get("clip", null) == c else c.start, c)
	if spot.is_empty():
		return []
	var target: Clip = spot["clip"]
	var has: bool = target.has_transition_out() if String(spot["side"]) == "out" else (target.has_transition() and str(target.transition_in.get("kind", "")) != TrRegistry.AUDIO_KIND)
	return [PmMenu.item(TR_PICK_ID, "Change transition..." if has else "Add transition...")]


func _bus_panel(id: String) -> Object:
	var script: GDScript = load("res://modules/core_panels/panel_bus.gd")
	var bus: RefCounted = script.call("instance")
	return bus.call("panel", id)


func _rename_clip(c: Clip) -> void:
	var fields: Array[Dictionary] = [{"key": "label", "label": "Name", "type": "string", "default": c.label}]
	var answered: Signal = PmUI.form(self, "Rename clip", fields, "Rename", "Cancel")
	answered.connect(_on_rename_clip_answered.bind(c.id))


func _on_rename_clip_answered(result: Variant, clip_id: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var label: String = String((result as Dictionary).get("label", "")).strip_edges()
	if label.is_empty():
		return
	Verbs.run(d, "Rename clip", [ClipCmds.SetClipField.new(s.id, clip_id, "label", label)])


func set_nest_option(clip_id: String, key: String, value: bool) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return false
	return Verbs.run(d, "Nest " + key, [ClipCmds.SetNestOption.new(s.id, clip_id, key, value)])


func header_items(t: Track, in_band: bool) -> Array:
	var items: Array = Tracks.menu_items(t, in_band)
	items.append_array(Filter.header_items(self, t))
	if t.subtitle and doc() != null and seq() != null:
		items.insert(0, PmMenu.sub_item("lane_character", "Character for every box on this lane", CharMenu.lane_items(doc(), seq(), t.id)))
		items.insert(1, PmMenu.separator())
	return items


func _on_header_menu(id: String, track_id: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	if CharMenu.on_lane_pick(self, d, s, track_id, id):
		return
	if Stacks.on_header_menu(self, id) or Tracks.Locks.on_header_menu(self, id, track_id) or Filter.on_header_menu(self, id, track_id):
		return
	var t: Track = s.track_by_id(track_id)
	if t == null:
		return
	if id == "rename":
		begin_rename(track_id)
	elif id == "target":
		set_track_field(track_id, "targeted", not t.targeted)
	elif id == "sync":
		set_track_field(track_id, "sync_lock", not t.sync_lock)
	elif id == "mute":
		set_track_field(track_id, "muted", not t.muted)
	elif id == "solo":
		set_track_field(track_id, "solo", not t.solo)
	elif id == "lock":
		set_track_field(track_id, "locked", not t.locked)
	elif id == "pin":
		pin_track(track_id, not t.pinned)
	elif id.begins_with("colour:"):
		set_track_field(track_id, "colour", int(id.substr(7)))
	elif id == "reset_height":
		set_track_field(track_id, "height", 0.0)
	elif id == "reset_all_heights":
		var cmds: Array[Command] = []
		for tr: Track in s.all_tracks():
			if tr.height != 0.0:
				cmds.append(TrackCmds.SetTrackField.new(s.id, tr.id, "height", 0.0))
		Verbs.run(d, "Reset track heights", cmds)
	elif id == "all_this_height":
		var h: float = t.height
		var cmds2: Array[Command] = []
		for tr: Track in (s.all_tracks() if s.free_tracks else s.tracks_of_kind(t.kind)):
			if tr.height != h:
				cmds2.append(TrackCmds.SetTrackField.new(s.id, tr.id, "height", h))
		Verbs.run(d, "Track heights", cmds2)
	elif id == "hide":
		set_track_field(track_id, "hidden", true)
	elif id == "select_all_on_track":
		var ids: PackedStringArray = PackedStringArray()
		for c: Clip in t.clips:
			ids.append(c.id)
		Verbs.select(d, s, ids, "replace")
	elif id == "add_track":
		add_track(t.kind, s.track_index(track_id) + 1)
	elif id == "remove_track":
		Verbs.run(d, "Remove track", [TrackCmds.RemoveTrack.new(s.id, track_id)])
	elif id == "band_top":
		set_pinned_field("position", "top")
	elif id == "subtitle":
		set_track_field(track_id, "subtitle", not t.subtitle)
	elif id == "push_back":
		set_track_field(track_id, "push_back", not t.push_back)
	elif id == "speaker":
		var fields: Array[Dictionary] = [{"key": "speaker", "label": "Speaker", "type": "string", "default": t.speaker}]
		var answered: Signal = PmUI.form(self, "Speaker for " + t.label, fields, "Apply", "Cancel")
		answered.connect(_on_speaker_answered.bind(track_id))
	elif id == "push_up":
		var fields2: Array[Dictionary] = [{"key": "push_up", "label": "Push up (px)", "type": "float", "default": t.push_up}]
		var answered2: Signal = PmUI.form(self, "Push up amount for " + t.label, fields2, "Apply", "Cancel")
		answered2.connect(_on_push_up_answered.bind(track_id))


func _on_speaker_answered(result: Variant, track_id: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	set_track_field(track_id, "speaker", String((result as Dictionary).get("speaker", "")).strip_edges())


func _on_push_up_answered(result: Variant, track_id: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	set_track_field(track_id, "push_up", maxf(float((result as Dictionary).get("push_up", 90.0)), 0.0))


func add_track(kind: String, index: int = -1) -> String:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return ""
	var n: int = s.tracks_of_kind(kind).size() + 1
	var t: Track = d.make_track(kind, ("V" if kind == "video" else "A") + str(n))
	if Verbs.run(d, "Add track", [TrackCmds.AddTrack.new(s.id, kind, index, t.to_dict())]):
		return t.id
	return ""


func _on_band_menu(id: String) -> void:
	if id == "band_top":
		set_pinned_field("position", "top")
	elif id == "band_bottom":
		set_pinned_field("position", "bottom")
	elif id == "band_collapsed":
		set_pinned_field("collapsed", not band_collapsed())


func marker_selection() -> PackedStringArray:
	var s: Sequence = seq()
	if s == null:
		return PackedStringArray()
	var out: PackedStringArray = PackedStringArray()
	for id: String in selected_marker_ids:
		if s.marker_by_id(id) != null and not out.has(id):
			out.append(id)
	return out


func set_marker_selection(ids: PackedStringArray, add: bool) -> void:
	var next: PackedStringArray = marker_selection() if add else PackedStringArray()
	for id: String in ids:
		if not next.has(id):
			next.append(id)
	if next == selected_marker_ids:
		return
	selected_marker_ids = next
	queue_redraw()
	_overlay.queue_redraw()
	var panel: Object = _bus_panel("markers")
	if panel != null and panel.has_method("marker_selection_changed"):
		panel.call("marker_selection_changed")


func select_markers_in(r: Rect2, add: bool) -> void:
	var s: Sequence = seq()
	if s == null:
		return
	set_marker_selection(Hit.markers_in(geometry(), s, r), add)


func marker_band_click(at: Vector2, mods: Dictionary) -> void:
	if not bool(mods.get("shift", false)):
		set_marker_selection(PackedStringArray(), false)
	_click_to(maxf(t_of(at.x), 0.0))


func markers_for_edit(marker_id: String) -> PackedStringArray:
	var sel: PackedStringArray = marker_selection()
	if sel.has(marker_id):
		return sel
	return PackedStringArray([marker_id])


func marker_fields_apply(marker_id: String, fields: Dictionary, label: String) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or fields.is_empty():
		return false
	var cmds: Array[Command] = []
	for id: String in markers_for_edit(marker_id):
		if s.marker_by_id(id) != null:
			cmds.append(MarkerCmds.SetMarker.new(s.id, "", id, fields))
	if cmds.is_empty():
		return false
	return Verbs.run(d, label, cmds)


func set_markers_kind(marker_id: String, kind: String) -> bool:
	var s: Sequence = seq()
	if s == null:
		return false
	var cmds: Array[Command] = []
	for id: String in markers_for_edit(marker_id):
		var mk: Marker = s.marker_by_id(id)
		if mk != null and mk.kind != kind:
			cmds.append(MarkerCmds.SetMarker.new(s.id, "", id, {"kind": kind}))
	if cmds.is_empty():
		return false
	return Verbs.run(doc(), "Marker kind" if cmds.size() == 1 else "Marker kinds", cmds)


func set_markers_anchor(marker_id: String, track_id: String) -> bool:
	var s: Sequence = seq()
	if s == null:
		return false
	var cmds: Array[Command] = []
	for id: String in markers_for_edit(marker_id):
		var mk: Marker = s.marker_by_id(id)
		if mk == null:
			continue
		var fields: Dictionary = MarkerFollow.anchor_fields(s, track_id, mk.time)
		if mk.anchor == track_id and String(fields.get("anchor_clip", "")) == mk.anchor_clip:
			continue
		cmds.append(MarkerCmds.SetMarker.new(s.id, "", id, fields))
	if cmds.is_empty():
		return false
	return Verbs.run(doc(), "Marker follows" if cmds.size() == 1 else "Markers follow", cmds)


func remove_markers(marker_id: String) -> bool:
	var s: Sequence = seq()
	if s == null:
		return false
	var cmds: Array[Command] = []
	for id: String in markers_for_edit(marker_id):
		if s.marker_by_id(id) != null:
			cmds.append(MarkerCmds.RemoveMarker.new(s.id, "", id))
	if cmds.is_empty():
		return false
	var done: bool = Verbs.run(doc(), "Remove marker" if cmds.size() == 1 else "Remove markers", cmds)
	if done:
		set_marker_selection(PackedStringArray(), false)
	return done


func marker_menu_items(mk: Marker) -> Array:
	var s: Sequence = seq()
	var many: int = markers_for_edit(mk.id).size()
	var tail: String = "" if many < 2 else " (" + str(many) + " markers)"
	var kind_sub: Array = []
	for i: int in Marker.KINDS.size():
		kind_sub.append(PmMenu.check_item("kind:" + Marker.KINDS[i], Marker.KIND_LABELS[i], mk.kind == Marker.KINDS[i]))
	var follow_sub: Array = [PmMenu.check_item("follow:", "Nothing", mk.anchor.is_empty())]
	if s != null:
		for t: Track in s.all_tracks():
			follow_sub.append(PmMenu.check_item("follow:" + t.id, t.label, mk.anchor == t.id))
	return [PmMenu.item("edit", "Edit marker" + tail), PmMenu.sub_item("kind", "Kind" + tail, kind_sub), PmMenu.sub_item("follow", "Follows" + tail, follow_sub)] + MarkerLanes.marker_items(self, mk, tail) + [PmMenu.separator(), PmMenu.item("remove", "Remove marker" + tail, "", "trash")]


func _on_marker_menu(id: String, marker_id: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	if id == "edit":
		open_marker_editor(marker_id)
	elif id == "remove":
		remove_markers(marker_id)
	elif id.begins_with("kind:"):
		set_markers_kind(marker_id, id.substr(5))
	elif id.begins_with("follow:"):
		set_markers_anchor(marker_id, id.substr(7))
	else:
		MarkerLanes.on_marker_menu(self, id, marker_id)


func open_marker_editor(marker_id: String) -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var m: Marker = s.marker_by_id(marker_id)
	if m == null:
		return
	var fields: Array[Dictionary] = []
	fields.append({"key": "label", "label": "Name", "type": "string", "default": m.label})
	fields.append({"key": "comment", "label": "Comment", "type": "string", "default": m.comment})
	fields.append({"key": "duration", "label": "Duration (seconds)", "type": "float", "default": m.duration})
	fields.append({"key": "kind", "label": "Kind", "type": "enum", "choices": Marker.kind_choices(), "default": Marker.kind_index(m.kind)})
	var colours: Array = ["None"]
	for i: int in Tk.LABEL_NAMES.size():
		colours.append(Tk.label_name(i))
	fields.append({"key": "colour", "label": "Colour", "type": "enum", "choices": colours, "default": m.colour + 1})
	fields.append_array(MarkerLanes.editor_fields(s, m))
	var title: String = "Marker"
	var many: int = markers_for_edit(marker_id).size()
	if many > 1:
		title = str(many) + " markers, what you change is applied to all of them"
	var answered: Signal = PmUI.form(self, title, fields, "Apply", "Cancel")
	answered.connect(_on_marker_form.bind(marker_id))


func _on_marker_form(result: Variant, marker_id: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var m: Marker = s.marker_by_id(marker_id)
	if m == null:
		return
	var r: Dictionary = result
	var was: Dictionary = {"label": m.label, "comment": m.comment, "duration": m.duration, "kind": m.kind, "colour": m.colour}
	var next: Dictionary = {"label": String(r.get("label", "")), "comment": String(r.get("comment", "")), "duration": maxf(float(r.get("duration", 0.0)), 0.0), "kind": Marker.kind_at(int(r.get("kind", 0))), "colour": int(r.get("colour", 0)) - 1}
	MarkerLanes.editor_answer(s, m, r, was, next)
	var fields: Dictionary = {}
	for key: String in next.keys():
		if next[key] != was[key]:
			fields[key] = next[key]
	if fields.is_empty():
		return
	marker_fields_apply(marker_id, fields, "Edit marker" if markers_for_edit(marker_id).size() == 1 else "Edit markers")


func _on_ruler_menu(id: String, t: float) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	if id == "add_marker":
		Verbs.add_marker_at(d, s, t)
	elif id == "mark_in":
		Verbs.set_in(d, s, t)
	elif id == "mark_out":
		Verbs.set_out(d, s, t)
	elif id == "clear_in_out":
		Verbs.clear_in_out(d, s)
	elif id == "new_marker_lane":
		MarkerLanes.open_lane_form(self, "")
	elif id == "tag_range":
		MarkerLanes.open_tag_form(self, "")
	elif id.begins_with("fence_"):
		FenceLook.on_menu(id, d, s, t)


func _on_empty_menu(id: String, track_id: String, t: float) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	if id == "paste":
		Session.set_playhead(t)
		Cmd.run("edit.paste")
	elif id.begins_with("pictures:"):
		Prefs.set_value(PREF_PICTURES, id.substr(9))
		queue_redraw()
	elif id == "add_marker":
		Verbs.add_marker_at(d, s, t)
	elif id == "add_track":
		var tr: Track = s.track_by_id(track_id)
		add_track(tr.kind if tr != null else "video")
	elif id == "close_gap":
		var EditCmds: GDScript = load("res://doc/commands/edit_cmds.gd")
		if not track_id.is_empty():
			Verbs.run(d, "Close gap", [EditCmds.CloseGap.new(s.id, track_id, t)])
	elif id == "text_from_marks":
		text_boxes_from_marks()


func begin_rename(track_id: String) -> void:
	end_rename(false)
	var s: Sequence = seq()
	if s == null:
		return
	var t: Track = s.track_by_id(track_id)
	var l: Dictionary = Lanes.lane_for_track(lanes(), track_id)
	if t == null or l.is_empty():
		return
	var g: Dictionary = geometry()
	var y: float = Hit.lane_screen_y(g, l)
	var r: Rect2 = Tracks.name_rect(Rect2(0.0, y, header_w, float(l["h"])), String(l["set"]) == "band")
	_rename_track = track_id
	_rename = PmUI.line_edit("", t.label)
	_rename.position = r.position - Vector2(2.0, 1.0)
	_rename.size = Vector2(r.size.x + 4.0, r.size.y + 4.0)
	_rename.text_submitted.connect(_on_rename_submitted)
	_rename.focus_exited.connect(_on_rename_focus_out)
	_rename.gui_input.connect(_on_rename_input)
	add_child(_rename)
	_rename.grab_focus()
	_rename.select_all()
	queue_redraw()


func _on_rename_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_rename.accept_event()
		end_rename(false)


func _on_rename_submitted(_text: String) -> void:
	end_rename(true)


func _on_rename_focus_out() -> void:
	end_rename(true)


func end_rename(commit: bool) -> void:
	if _rename == null:
		return
	var le: LineEdit = _rename
	var track_id: String = _rename_track
	_rename = null
	_rename_track = ""
	var text: String = le.text.strip_edges()
	if le.focus_exited.is_connected(_on_rename_focus_out):
		le.focus_exited.disconnect(_on_rename_focus_out)
	PmUI.free_node(le)
	queue_redraw()
	if commit and not text.is_empty():
		set_track_field(track_id, "label", text)


func cancel_gesture() -> bool:
	if drag.in_progress():
		drag.call("cancel")
		return true
	if not drop_preview.is_empty():
		_clear_drop_preview()
		return true
	return false


const PlayheadGlide := preload("res://ui/timeline/playhead_glide.gd")
const StreamWaves := preload("res://ui/timeline/stream_waves.gd")
const StreamOff := preload("res://doc/stream_off.gd")
const LOADING_REFRESH_MS := 250
const GROW_REPAINT_MS := 250
const ScrubPress := preload("res://ui/timeline/timeline_scrub_press.gd")
const Far := preload("res://ui/timeline/timeline_far.gd")

var _glide: PlayheadGlide = PlayheadGlide.new()


func _scrub_step(t: float) -> void:
	if drag.last == drag.press:
		_click_to(t)
		return
	_glide.stop()
	Session.scrub_to(t)


func _click_to(t: float) -> void:
	if PlayheadGlide.timeline_on() and _glide.start(playhead(), t):
		return
	_glide.stop()
	Session.jump_to(t)


func scrub_pressed() -> void:
	ScrubPress.press(self)


func scrub_release(t: float, moved: bool) -> void:
	ScrubPress.release(self, t, moved)


func gliding() -> bool:
	return _glide.active()


func _glide_tick(dt: float) -> void:
	if not _glide.active():
		return
	Session.scrub_to(_glide.step(dt))
	if not _glide.active() and not (drag.in_progress() and String(drag.mode) == "scrub"):
		Session.scrub_done()


func _process(dt: float) -> void:
	_heard_watch()
	_volume_watch()
	_tick_loading()
	if drag.in_progress() and drag.active:
		var m: String = String(drag.mode)
		if m == "scrub":
			var t: float = float(drag.scrub_t)
			if t >= 0.0 and t != _last_scrub:
				_last_scrub = t
				_scrub_step(t)
		if m in Drag.MOVING or (m == "scrub" and ScrubPress.may_autoscroll(drag)):
			_autoscroll(dt)
		if m == "move" and bool(drag.call("modifier_changed")):
			queue_redraw()
			_overlay.queue_redraw()
	_glide_tick(dt)
	if _follow_pending and Session.playing and ScrubPress.may_follow(self):
		_follow_pending = false
		var mode: String = String(Prefs.get_value(PREF_FOLLOW))
		if mode != "off":
			reveal_time(playhead(), mode == "page")
	if not _pin_anim.is_empty():
		_overlay.queue_redraw()
		if Time.get_ticks_msec() - int(_pin_anim["t0"]) > int(float(_pin_anim["dur"]) * 1000.0):
			_pin_anim = {}
	if not meters.is_empty() or Session.playing:
		if PurrBridge.available:
			meters = PurrBridge.meters()
			_overlay.queue_redraw()
		elif not meters.is_empty():
			meters = PackedFloat32Array()
			_overlay.queue_redraw()


func _band_autoscroll(step: float) -> bool:
	var before: float = band_scroll_y
	_band_scroll.call("scroll_by", 0.0, step, false)
	band_scroll_y = float(_band_scroll.get("scroll_y"))
	return band_scroll_y != before


func _autoscroll(dt: float) -> void:
	var pos: Vector2 = drag.last
	var g: Dictionary = geometry()
	var main_rect: Rect2 = g["main_rect"]
	var band: float = float(Tk.px(AUTOSCROLL_BAND))
	var dx: float = 0.0
	var dy: float = 0.0
	var left: float = header_w + band
	var right: float = size.x - band
	if pos.x < left:
		dx = -minf(240.0 + 6.0 * (left - pos.x), AUTOSCROLL_MAX)
	elif pos.x > right:
		dx = minf(240.0 + 6.0 * (pos.x - right), AUTOSCROLL_MAX)
	var m: String = String(drag.mode)
	if m == "move":
		if pos.y < main_rect.position.y + band:
			dy = -minf(240.0 + 6.0 * (main_rect.position.y + band - pos.y), AUTOSCROLL_MAX)
		elif pos.y > main_rect.end.y - band:
			dy = minf(240.0 + 6.0 * (pos.y - main_rect.end.y + band), AUTOSCROLL_MAX)
	var band_moved: bool = false
	if m == "range":
		var ay: Dictionary = Marquee.autoscroll_y(g, pos, band, AUTOSCROLL_MAX)
		dy = float(ay["dy"])
		if String(ay["set"]) == Marquee.BAND:
			band_moved = _band_autoscroll(dy * dt)
			dy = 0.0
	if dx == 0.0 and dy == 0.0 and not band_moved:
		return
	var before_x: float = scroll_x
	var before_y: float = scroll_y
	_scroll.call("scroll_by", dx * dt, dy * dt, false)
	scroll_x = float(_scroll.get("scroll_x"))
	scroll_y = float(_scroll.get("scroll_y"))
	if scroll_x != before_x or scroll_y != before_y or band_moved:
		var mm := InputEventMouseMotion.new()
		mm.position = pos
		mm.relative = Vector2.ZERO
		mm.shift_pressed = bool(drag.mods.get("shift", false))
		mm.ctrl_pressed = bool(drag.mods.get("ctrl", false))
		mm.alt_pressed = bool(drag.mods.get("alt", false))
		drag.call("motion", pos, Drag.mods_of(mm))
		queue_redraw()
		_overlay.queue_redraw()


func _on_slot_hover_changed(on: bool) -> void:
	if not on:
		_clear_drop_preview()


func _clear_drop_preview() -> void:
	drop_preview = {}
	if _ghost_hidden != null and is_instance_valid(_ghost_hidden):
		_ghost_hidden.visible = true
	_ghost_hidden = null
	_overlay.queue_redraw()


func _layer_payload() -> Dictionary:
	var layer: CanvasLayer = PmDragLayer.find(self)
	if layer == null:
		return {}
	return layer.get("payload")


func _on_slot_hover_moved(local: Vector2) -> void:
	var payload: Dictionary = _layer_payload()
	var kind: String = String(payload.get("kind", ""))
	var h: Dictionary = hit_at(local)
	if kind == "media":
		if not Edit.replace_preview(self, payload, h):
			_update_media_preview(payload, h, local)
	elif kind == "effect" or kind == "preset" or kind == "transition":
		var c: Clip = h.get("clip", null)
		drop_preview = {"kind": kind, "clip_id": c.id if c != null else "", "lane": h.get("lane", {}), "t": float(h.get("t", 0.0)), "id": String(payload.get("id", ""))}
		_overlay.queue_redraw()


func _update_media_preview(payload: Dictionary, h: Dictionary, local: Vector2) -> void:
	payload = Edit.Tools.subclip_payload(doc(), payload)
	var d: Project = doc()
	var s: Sequence = seq()
	var zone: String = String(h.get("zone", ""))
	if d == null or s == null or not (zone == "lane" or zone == "new_track" or zone == "empty"):
		_clear_drop_preview()
		return
	var ids: PackedStringArray = PackedStringArray()
	for v: Variant in payload.get("ids", []):
		ids.append(String(v))
	if ids.is_empty():
		_clear_drop_preview()
		return
	var item: MediaItem = d.media_by_id(ids[0])
	if item == null:
		_clear_drop_preview()
		return
	var layer: CanvasLayer = PmDragLayer.find(self)
	if layer != null and _ghost_hidden == null:
		var g: Variant = layer.get("_ghost")
		if g is Control:
			_ghost_hidden = g
			(g as Control).visible = false
	var t: float = float(h.get("t", 0.0))
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
		pass
	var raw_t: float = t
	if snapping:
		t = snap_near(snap_targets(PackedStringArray()), raw_t)
	t = maxf(t, 0.0)
	var total: float = 0.0
	var spans: Array[float] = []
	for id: String in ids:
		var m: MediaItem = d.media_by_id(id)
		var dur: float = d.media_duration(m) if m != null else 0.0
		if dur <= 0.0:
			dur = STILL_SECONDS
		spans.append(dur)
		total += dur
	var part: String = String(payload.get("part", "both"))
	var in_t: float = float(payload.get("in", -1.0))
	var out_t: float = float(payload.get("out", -1.0))
	if in_t >= 0.0 and out_t > in_t and ids.size() == 1:
		spans[0] = out_t - in_t
		total = spans[0]
	var lane: Dictionary = h.get("lane", {})
	var new_track: bool = zone == "new_track" or zone == "empty"
	var track: Track = h.get("track", null)
	var wants_video: bool = item.has_picture() and part != "audio"
	var wants_audio: bool = (item.has_audio or item.kind == "audio" or item.audio_only or Verbs.sequence_has_sound(d, item)) and part != "video" and not StreamOff.all_off(item)
	if Verbs.SoundAdjust.drops_on(item, track):
		wants_audio = true
	var video_lane: Dictionary = {}
	var audio_lane: Dictionary = {}
	if not new_track and track != null and not bool(lane.get("nest", false)):
		if track.kind == "video" and wants_video:
			video_lane = lane
			if wants_audio:
				for a: Track in s.audio_tracks:
					if a.targeted and not a.locked:
						audio_lane = Lanes.lane_for_track(lanes(), a.id)
						break
				if audio_lane.is_empty() and not s.audio_tracks.is_empty():
					audio_lane = Lanes.lane_for_track(lanes(), s.audio_tracks[0].id)
		elif track.kind == "audio" and wants_audio:
			audio_lane = lane
		elif track.kind == "video" and not wants_video:
			new_track = false
		if s.free_tracks:
			var free_lanes: Dictionary = Stacks.free_lanes(self, s, track, lane, wants_video, wants_audio)
			video_lane = free_lanes["video"]
			audio_lane = free_lanes["audio"]
	drop_preview = {"kind": "media", "ids": ids, "t": t, "spans": spans, "total": total, "video_lane": video_lane, "audio_lane": audio_lane, "new_track": new_track, "track_id": track.id if track != null else "", "insert": insert_mode or Input.is_key_pressed(KEY_CTRL), "label": item.label, "y": local.y}
	drop_preview["overlap"] = Stacks.drop_overlap(s)
	drop_preview["refused"] = Tracks.Locks.drop_refusal(d, s, drop_preview)
	_overlay.queue_redraw()


func _on_slot_dropped(payload: Dictionary, local: Vector2) -> void:
	var kind: String = String(payload.get("kind", ""))
	var preview: Dictionary = drop_preview.duplicate(true)
	_clear_drop_preview()
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var h: Dictionary = hit_at(local)
	if kind == "media" and MarkerLanes.drop_media_on_tag(self, payload, h):
		drop_done.emit()
		return
	if kind == "media" and Edit.replace_drop(self, payload, h):
		drop_done.emit()
		return
	if kind == "media":
		if preview.is_empty():
			_update_media_preview(payload, h, local)
			preview = drop_preview.duplicate(true)
			_clear_drop_preview()
		if preview.is_empty():
			return
		_place_preview(preview, payload)
		drop_done.emit()
		return
	var c: Clip = h.get("clip", null)
	if kind == "files":
		var bin_panel: Object = _bus_panel("bin")
		var paths: PackedStringArray = PackedStringArray()
		for v: Variant in payload.get("paths", []):
			paths.append(String(v))
		if bin_panel == null or paths.is_empty():
			return
		var ids: PackedStringArray = bin_panel.call("import_paths", paths)
		if not ids.is_empty():
			drop_media_at(ids, global_position + local)
			drop_done.emit()
		return
	if kind == "transition":
		var tr_drop: Track = h.get("track", null)
		if tr_drop == null or bool(h.get("nest", false)):
			Events.toast("Drop a transition onto a cut")
			return
		if apply_transition_at(String(payload.get("id", "")), tr_drop.id, float(h.get("t", 0.0)), c, String(payload.get("preset", ""))):
			drop_done.emit()
		else:
			Events.toast("No clip there to take the transition")
		return
	if kind == "effect":
		var effects_panel: Object = _bus_panel("effects")
		var def: Dictionary = {}
		if effects_panel != null and effects_panel.has_method("def_for"):
			def = effects_panel.call("def_for", String(payload.get("id", "")))
		if MarkerLanes.drop_effect_on_tag(self, h, def):
			drop_done.emit()
			return
		if def.is_empty() or c == null:
			Events.toast("Drop an effect onto a clip")
			return
		var targets: PackedStringArray = Verbs.drop_targets(s, c.id)
		if Verbs.drop_effect(d, s, targets, def, float(h.get("t", -1.0))) == 0:
			Events.toast("Sound effects go on clips that have sound" if bool(def.get("audio", false)) else "Picture effects go on clips that have a picture")
		drop_done.emit()
		return
	if kind == "preset":
		var presets_panel: Object = _bus_panel("presets")
		if presets_panel != null and presets_panel.has_method("preset_by_id") and MarkerLanes.drop_preset_on_tag(self, presets_panel.call("preset_by_id", String(payload.get("id", ""))), h):
			drop_done.emit()
			return
		if presets_panel != null and presets_panel.has_method("apply_preset_id"):
			var targets2: PackedStringArray = PackedStringArray()
			if c != null:
				targets2 = Verbs.selection(s) if s.selected_clip_ids.has(c.id) else PackedStringArray([c.id])
			presets_panel.call("apply_preset_id", String(payload.get("id", "")), targets2, float(h.get("t", 0.0)), h.get("track", null))
		drop_done.emit()


func _place_preview(preview: Dictionary, payload: Dictionary) -> void:
	payload = Edit.Tools.subclip_payload(doc(), payload)
	var d: Project = doc()
	var s: Sequence = seq()
	var ids: PackedStringArray = preview["ids"]
	var t: float = float(preview["t"])
	var mode: String = "insert" if bool(preview.get("insert", false)) else (Verbs.MODE_OVERLAP if bool(preview.get("overlap", false)) else "overwrite")
	var part: String = String(payload.get("part", "both"))
	var in_t: float = float(payload.get("in", -1.0))
	var out_t: float = float(payload.get("out", -1.0))
	var tx: RefCounted = d.undo.begin("Place " + String(preview.get("label", "media")))
	var track_id: String = String(preview.get("track_id", ""))
	var first: MediaItem = d.media_by_id(ids[0])
	if bool(preview.get("new_track", false)) or track_id.is_empty():
		var kind: String = "video" if (first != null and first.has_picture() and part != "audio") else "audio"
		track_id = add_track(kind)
	if track_id.is_empty():
		tx.abandon()
		return
	var cursor: float = t
	var placed: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var m: MediaItem = d.media_by_id(id)
		if m == null:
			continue
		var ok: bool = false
		if in_t >= 0.0 and out_t > in_t and ids.size() == 1:
			ok = place_range(id, track_id, cursor, in_t, out_t, part, mode)
		elif part != "both":
			ok = place_range(id, track_id, cursor, 0.0, maxf(d.media_duration(m), 0.0), part, mode)
		else:
			ok = Verbs.place_media(d, s, id, track_id, cursor, mode)
		if ok:
			placed.append_array(Verbs.selection(s))
			var dur: float = d.media_duration(m)
			cursor += dur if dur > 0.0 else STILL_SECONDS
	tx.commit()
	if not placed.is_empty():
		Verbs.select(d, s, placed, "replace")


func place_range(media_id: String, track_id: String, t: float, in_t: float, out_t: float, part: String, mode: String) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return false
	var item: MediaItem = d.media_by_id(media_id)
	var target: Track = s.track_by_id(track_id)
	if item == null or target == null or target.locked:
		return false
	var total: float = d.media_duration(item)
	var i0: float = maxf(in_t, 0.0)
	var i1: float = out_t if out_t > i0 else (total if total > 0.0 else STILL_SECONDS)
	if total > 0.0:
		i1 = minf(i1, total)
	var dur: float = i1 - i0
	if dur <= 0.0:
		return false
	var wants_video: bool = item.has_picture() and part != "audio" and target.accepts("video")
	var wants_audio: bool = (item.has_audio or item.kind == "audio" or item.audio_only or Verbs.sequence_has_sound(d, item)) and part != "video" and not StreamOff.all_off(item)
	var cmds: Array[Command] = []
	var audio_track: Track = Verbs.sound_target(d, s, target, wants_video, cmds) if wants_audio else null
	if not wants_video and audio_track == null:
		return false
	var streams: PackedInt32Array = Verbs.selected_streams(item) if item.kind != "sequence" else PackedInt32Array([0])
	var audio_tracks: Array[Track] = Verbs.audio_tracks_from(d, s, audio_track, streams.size(), cmds) if audio_track != null else ([] as Array[Track])
	var seeds: PackedStringArray = PackedStringArray()
	if wants_video:
		seeds.append(target.id)
	for at: Track in audio_tracks:
		if not seeds.has(at.id):
			seeds.append(at.id)
	Verbs.clear_for_place(s, mode, t, dur, seeds, cmds)
	var link_id: String = d.mint_id("l") if (wants_video and not audio_tracks.is_empty()) or audio_tracks.size() > 1 else ""
	var new_ids: PackedStringArray = PackedStringArray()
	if wants_video:
		var vid: String = d.mint_id("c")
		var vd: Dictionary = {"id": vid, "media_id": media_id, "label": item.label, "start": t, "duration": dur, "in_offset": i0}
		if item.kind == "sequence":
			vd["sequence_id"] = item.sequence_id
		if not link_id.is_empty():
			vd["link_id"] = link_id
		Clip.stamp_auto_loop(item.path, vd)
		Verbs.stamp_place(target, vd, "video", mode)
		cmds.append(ClipCmds.PlaceClip.new(s.id, target.id, vd))
		new_ids.append(vid)
	for k: int in audio_tracks.size():
		var aid: String = d.mint_id("c")
		var stream: int = streams[mini(k, streams.size() - 1)]
		var label: String = item.label if streams.size() == 1 else item.label + " " + Verbs.stream_label(item, stream)
		var ad: Dictionary = {"id": aid, "media_id": media_id, "label": label, "start": t, "duration": dur, "in_offset": i0, "audio": {"stream": float(stream)}}
		if item.kind == "sequence":
			ad["sequence_id"] = item.sequence_id
		if not link_id.is_empty():
			ad["link_id"] = link_id
		Clip.stamp_auto_loop(item.path, ad)
		Verbs.stamp_place(audio_tracks[k], ad, "audio", mode)
		cmds.append(ClipCmds.PlaceClip.new(s.id, audio_tracks[k].id, ad))
		new_ids.append(aid)
	if not Verbs.run(d, "Place " + item.label, cmds):
		return false
	Verbs.select(d, s, new_ids, "replace")
	return true


func drop_media_at(ids: PackedStringArray, global_pos: Vector2) -> void:
	var local: Vector2 = global_pos - global_position
	var payload: Dictionary = {"kind": "media", "ids": Array(ids), "part": "both", "in": -1.0, "out": -1.0}
	_update_media_preview(payload, hit_at(local), local)
	var preview: Dictionary = drop_preview.duplicate(true)
	_clear_drop_preview()
	if preview.is_empty():
		return
	_place_preview(preview, payload)
	drop_done.emit()


func place_at_playhead(ids: PackedStringArray, mode: String, part: String = "both", in_t: float = -1.0, out_t: float = -1.0) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or ids.is_empty():
		return false
	var first: MediaItem = d.media_by_id(ids[0])
	if first == null:
		return false
	var wants_video: bool = first.has_picture() and part != "audio"
	var target: Track = null
	var list: Array[Track] = s.top_down_tracks() if s.free_tracks else (s.video_tracks if wants_video else s.audio_tracks)
	for t: Track in list:
		if t.targeted and not t.locked:
			target = t
			break
	if target == null:
		for t: Track in list:
			if not t.locked:
				target = t
				break
	if target == null:
		return false
	var preview: Dictionary = {"ids": ids, "t": s.playhead, "track_id": target.id, "insert": mode == "insert", "new_track": false, "label": first.label}
	_place_preview(preview, {"kind": "media", "ids": Array(ids), "part": part, "in": in_t, "out": out_t})
	return true


func wave_tier() -> int:
	return Lanes.tier_for_pps(pps)


func _peaks(h: int, stream: int, tier: int, from_bucket: int, count: int) -> PackedByteArray:
	if peaks_provider.is_valid():
		return peaks_provider.call(h, stream, tier, from_bucket, count)
	if not PurrBridge.available or h < 0:
		return PackedByteArray()
	return PurrBridge.peaks_read(h, stream, tier, from_bucket, count)


func _coverage(h: int, stream: int) -> PackedByteArray:
	if coverage_provider.is_valid():
		return coverage_provider.call(h, stream)
	if not PurrBridge.available or h < 0:
		return PackedByteArray()
	return PurrBridge.peaks_coverage(h, stream)


func _has_peaks_source(item: MediaItem) -> bool:
	if peaks_provider.is_valid():
		return true
	return PurrBridge.available and _handle_of(item) >= 0


func strip_building(handle: int) -> bool:
	if handle < 0 or not PurrBridge.available:
		return false
	if _strip_state_at.has(handle) and Time.get_ticks_msec() - int(_strip_state_at[handle]) < 500:
		return bool(_strip_state[handle])
	var st: String = String((PurrBridge.media_info(handle) as Dictionary).get("strip_state", "none"))
	var busy: bool = st == "building"
	_strip_state[handle] = busy
	_strip_state_at[handle] = Time.get_ticks_msec()
	return busy


func _handle_of(item: MediaItem) -> int:
	if item == null:
		return -1
	var h: Variant = Session.media_handles.get(item.id, -1)
	if typeof(h) == TYPE_INT and int(h) >= 0:
		return int(h)
	return item.handle


const LoopDraw := preload("res://ui/timeline/timeline_loop.gd")


func _draw_wave(c: Clip, item: MediaItem, r: Rect2, clip_x0: float, lane_h: float, lane_y: float) -> void:
	if item != null and item.kind != "sequence" and StreamOff.is_off(item, StreamOff.clip_stream(c)):
		_draw_stream_off(c, item, r, lane_h, lane_y)
		return
	if lane_h < float(Tk.px(WAVE_MIN_H)) or item == null or not _has_peaks_source(item):
		return
	if not _wave_piece:
		var vq: int = Time.get_ticks_usec()
		if _volume_paint != paint_count:
			_volume_paint = paint_count
			_volume_on = WaveLook.volume_on()
			if _volume_on:
				WaveVolume.prepare(doc())
		_wave_env = WaveVolume.cached(seq(), c) if _volume_on else {}
		_wave_x0 = clip_x0
		volume_usec += Time.get_ticks_usec() - vq
	if c.loop:
		_wave_piece = true
		var pieces_drawn: bool = LoopDraw.draw_wave_pieces(self, c, item, r, clip_x0, lane_h, lane_y, LoopDraw.media_length(doc(), c, item))
		_wave_piece = false
		if pieces_drawn:
			return
	var tier: int = wave_tier()
	var rate: float = Lanes.tier_rate(tier)
	if Lanes.CHUNK_SECONDS * pps < 8.0:
		return
	var speed: float = c.static_speed()
	if speed == 0.0:
		speed = 1.0
	var stride: int = maxi(1, int(ceil(rate / (2.0 * pps))))
	var stream: int = int(c.audio.get("stream", 0.0))
	var handle: int = _handle_of(item)
	var render: String = str(c.audio.get("render", ""))
	if not render.is_empty() and not peaks_provider.is_valid():
		var rh: int = Session.render_handle(render)
		if rh >= 0:
			handle = rh
			stream = 0
	var src_in: float = c.source_in()
	var src_out: float = c.source_out()
	var name_h: float = Paint.name_row_h() if lane_h >= 34.0 else 0.0
	var top: float = lane_y + name_h + 1.0
	var h: float = lane_h - name_h - 2.0
	var centre_y: float = top + h * 0.5
	var half: float = h * 0.5
	var scale_x: float = pps / speed
	var origin_x: float = clip_x0 - c.in_offset * scale_x
	_wave_look_for(c, item)
	if WaveLook.anchor_of(WaveLook.look()) == WaveLook.GROW_MIDDLE:
		draw_line(Vector2(r.position.x, centre_y), Vector2(r.end.x, centre_y), Tk.c["wave_line"], 1.0)
	if _draw_heard_wave(c, handle, stream, tier, stride, r, clip_x0, Rect2(r.position.x, top, r.size.x, h)):
		return
	if _draw_ramp_wave(c, handle, stream, tier, stride, r, clip_x0, Rect2(r.position.x, top, r.size.x, h)):
		return
	var fine: float = Waves.fine_wave_rate(handle, stream, r, origin_x, scale_x, src_in, src_out, peaks_provider.is_valid())
	_draw_wave_windows(c.id, handle, stream, tier, 1 if fine > 0.0 else stride, r, origin_x, scale_x, Rect2(r.position.x, top, r.size.x, h), src_in, src_out, fine)


var streams_off_drawn: int = 0
var _wave_base: Color = Color.WHITE
var _wave_scale: Dictionary = {}
var _wave_env: Dictionary = {}
var _wave_x0: float = 0.0
var _wave_piece: bool = false


var volume_usec: int = 0
var _volume_paint: int = -1
var _volume_on: bool = true


func _wave_vol(origin_x: float, scale_x: float, ws0: float) -> Dictionary:
	if _wave_env.is_empty() or bool(_wave_env["unity"]):
		return {}
	var vq: int = Time.get_ticks_usec()
	var vol: Dictionary = WaveVolume.window(_wave_env, (origin_x + ws0 * scale_x - _wave_x0) / pps, scale_x / pps)
	volume_usec += Time.get_ticks_usec() - vq
	return vol


func _wave_look_for(c: Clip, item: MediaItem) -> void:
	var lk: Dictionary = WaveLook.look()
	var from: String = String(lk.get("colour_from", WaveLook.COLOUR_THEME))
	var tc: int = -1
	if from == WaveLook.COLOUR_CLIP or from == WaveLook.COLOUR_TRACK:
		var s0: Sequence = seq()
		var tr0: Track = s0.track_of(c.id) if s0 != null else null
		tc = tr0.colour if tr0 != null else -1
	_wave_base = WaveLook.base_colour(lk, c.colour, item.colour if item != null else -1, tc)
	if _wave_scale.is_empty() or bool(_wave_scale["log"]) != wave_log or float(_wave_scale["gain"]) != maxf(wave_gain, 0.0001):
		_wave_scale = WaveLook.scale(wave_log, wave_gain)


func _draw_stream_off(c: Clip, item: MediaItem, r: Rect2, lane_h: float, lane_y: float) -> void:
	streams_off_drawn += 1
	var name_h: float = Paint.name_row_h() if lane_h >= 34.0 else 0.0
	var band: Rect2 = Rect2(r.position.x, lane_y + name_h + 1.0, r.size.x, maxf(lane_h - name_h - 2.0, 2.0))
	draw_rect(band, Color(Tk.c["bg_panel"], 0.55), true)
	Paint.hatch(self, band, Tk.c["hatch"])
	if band.size.x < 60.0 or band.size.y < float(_fs_small) + 4.0:
		return
	var text: String = StreamOff.StreamOrdinals.label(item, StreamOff.clip_stream(c)) + " switched off"
	var w: float = minf(_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs_small).x + 8.0, band.size.x - 4.0)
	var box: Rect2 = Rect2(band.position.x + 2.0, band.get_center().y - (float(_fs_small) + 3.0) * 0.5, w, float(_fs_small) + 3.0)
	draw_rect(box, Color(Tk.c["bg_shell"], 0.8), true)
	PmText.draw(self, _font, box, text, _fs_small, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, 4.0)


func _wave_begin_frame() -> void:
	for k: String in ["loading", "deferred", "drawn", "built", "points"]:
		wave_stats[k] = 0
	volume_usec = 0
	_slim_waves = 0
	_wave_waiting = {}


func _wave_end_frame() -> void:
	_waiting_last = _wave_waiting
	_wave_waiting = {}


func waiting_handles() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for h: Variant in _waiting_last.keys():
		out.append(int(h))
	return out


func _slim_wave_ok(x0: float, x1: float) -> bool:
	var w: float = x1 - x0
	if w >= Far.SLIM_PX:
		return true
	if Far.wave_too_slim(x0, x1) or _slim_waves >= SLIM_WAVE_BUDGET:
		return false
	_slim_waves += 1
	return true


func _wave_block(x0: float, x1: float, band: Rect2, loading: bool) -> void:
	var a: float = maxf(x0, band.position.x)
	var b: float = minf(x1, band.end.x)
	if b <= a:
		return
	if loading:
		Paint.draw_loading(self, Rect2(a, band.position.y, b - a, band.size.y), _font, _fs_small)
	else:
		draw_rect(Rect2(a, band.position.y, b - a, band.size.y), Color(Tk.c["bg_panel_high"], 0.6), true)


func _chunk_ready(coverage: PackedByteArray, k: int) -> bool:
	if coverage.is_empty():
		return coverage_provider.is_valid()
	return k >= coverage.size() or coverage[k] != 0


func _draw_wave_windows(clip_id: String, handle: int, stream: int, tier: int, stride: int, r: Rect2, origin_x: float, scale_x: float, band: Rect2, src_in: float, src_out: float, fine_rate: float = 0.0) -> void:
	var rate: float = fine_rate if fine_rate > 0.0 else Lanes.tier_rate(tier)
	var vis: Vector2 = Waves.visible_span(r, origin_x, scale_x, src_in, src_out)
	if vis.y <= vis.x:
		return
	var coverage: PackedByteArray = _coverage(handle, stream)
	var smooth: int = Paint.wave_smooth_steps(float(stride) / rate * absf(scale_x))
	var win_b: int = Waves.window_buckets(stride, smooth)
	var mode_key: String = ("L" if wave_log else "N") + String.num(wave_gain, 1)
	var head: String = clip_id + "|" + str(handle) + "|" + str(stream) + "|" + (str(tier) if fine_rate <= 0.0 else "f" + str(int(fine_rate))) + "|" + str(stride) + "|" + str(smooth) + "|" + str(win_b) + "|" + mode_key + "|"
	var centre_y: float = band.get_center().y
	var half: float = band.size.y * 0.5
	var k0: int = int(floor(vis.x / Lanes.CHUNK_SECONDS))
	var k1: int = int(floor(maxf(vis.y - 0.000001, vis.x) / Lanes.CHUNK_SECONDS))
	for k: int in range(k0, k1 + 1):
		var cs0: float = maxf(float(k) * Lanes.CHUNK_SECONDS, src_in)
		var cs1: float = minf(float(k + 1) * Lanes.CHUNK_SECONDS, src_out)
		var v0: float = maxf(cs0, vis.x)
		var v1: float = minf(cs1, vis.y)
		if v1 <= v0:
			continue
		if fine_rate <= 0.0 and not _chunk_ready(coverage, k):
			if not peaks_provider.is_valid():
				Session.want_peaks(handle, stream, v0)
			_wave_waiting[handle] = true
			wave_stats["loading"] = int(wave_stats["loading"]) + 1
			_wave_block(minf(origin_x + v0 * scale_x, origin_x + v1 * scale_x), maxf(origin_x + v0 * scale_x, origin_x + v1 * scale_x), band, true)
			continue
		var j0: int = int(floor(v0 * rate / float(win_b)))
		var j1: int = int(floor((v1 * rate - 0.000001) / float(win_b)))
		for j: int in range(j0, maxi(j0, j1) + 1):
			var ws0: float = maxf(float(j * win_b) / rate, cs0)
			var ws1: float = minf(float((j + 1) * win_b) / rate, cs1)
			if ws1 <= ws0:
				continue
			var key: String = head + str(j) + ("<" if ws0 > src_in + 0.000001 else "=") + (">" if ws1 < src_out - 0.000001 else "=") + "|" + String.num(ws0, 9) + "|" + String.num(ws1, 9)
			var pts: PackedVector2Array
			if _wave_cache.has(key):
				pts = _wave_cache[key]
			else:
				var from_bucket: int = Waves.aligned_from(int(floor(ws0 * rate)), j * win_b, stride)
				var end_bucket: int = mini((j + 1) * win_b, int(ceil(ws1 * rate)))
				if ws0 > src_in + 0.000001:
					from_bucket = maxi(from_bucket - stride, 0)
				if ws1 < src_out - 0.000001:
					end_bucket += stride
				var count: int = end_bucket - from_bucket
				if count <= 0:
					continue
				var est: int = Waves.estimate_points(count, stride, smooth)
				if _wave_points_spent > 0 and _wave_points_spent + est > WAVE_BUDGET:
					_wave_more = true
					wave_stats["deferred"] = int(wave_stats["deferred"]) + 1
					_wave_block(minf(origin_x + ws0 * scale_x, origin_x + ws1 * scale_x), maxf(origin_x + ws0 * scale_x, origin_x + ws1 * scale_x), band, false)
					continue
				var bytes: PackedByteArray = Waves.fine_read(handle, stream, from_bucket, count, rate) if fine_rate > 0.0 else _peaks(handle, stream, tier, from_bucket, count)
				if fine_rate > 0.0 and bytes.is_empty():
					_wave_more = true
					_wave_block(minf(origin_x + ws0 * scale_x, origin_x + ws1 * scale_x), maxf(origin_x + ws0 * scale_x, origin_x + ws1 * scale_x), band, false)
					continue
				pts = Waves.trim_ribbon(Paint.build_wave_ribbon(bytes, from_bucket, rate, stride, wave_log, wave_gain, smooth, -1.0e30, 1.0e30, ws0, WAVE_CAP), 0.0, ws1 - ws0)
				_wave_points_spent += pts.size() / 2
				wave_stats["built"] = int(wave_stats["built"]) + 1
				wave_stats["points"] = int(wave_stats["points"]) + pts.size() / 2
				_wave_cache[key] = pts
				if _wave_cache.size() > 4000:
					_wave_cache.clear()
					_wave_cache[key] = pts
			if pts.size() < 6:
				continue
			wave_stats["drawn"] = int(wave_stats["drawn"]) + 1
			draw_set_transform(Vector2(origin_x + ws0 * scale_x, centre_y), 0.0, Vector2(scale_x, half))
			var vol: Dictionary = _wave_vol(origin_x, scale_x, ws0)
			WaveLook.draw(self, pts, _wave_base, _wave_scale, scale_x, half, key, vol)
			if wave_record: _wave_rec(clip_id, origin_x, scale_x, ws0, centre_y, half, pts, vol)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


var heard_drawn: Dictionary = {}
var heard_redraws: int = 0
var _heard_seen: int = -1
var _heard_paint: int = -1
var _heard_any: bool = false


func _draw_heard_wave(c: Clip, handle: int, stream: int, tier: int, stride: int, r: Rect2, clip_x0: float, band: Rect2) -> bool:
	if _heard_paint != paint_count:
		_heard_paint = paint_count
		var d: Project = doc()
		var s: Sequence = seq()
		_heard_any = d != null and s != null and not (Waves.heard_sources(d, s)["sources"] as Array).is_empty()
	if not _heard_any:
		return false
	var streamed: Variant = StreamWaves.spans(doc(), seq(), c)
	if streamed is Array:
		heard_drawn[c.id] = {"paint": paint_count, "spans": _draw_spans(c, streamed, handle, stream, tier, stride, r, clip_x0, band)}
		StreamWaves.draw_tags(self, doc(), c, streamed, clip_x0, pps, band, _font, _fs_small)
		return true
	var plan: Dictionary = Waves.heard_plan(doc(), seq(), c)
	if plan.is_empty():
		return false
	var drawn: Array[Dictionary] = _draw_spans(c, plan["spans"], handle, stream, tier, stride, r, clip_x0, band)
	if heard_drawn.size() > 256:
		heard_drawn.clear()
	heard_drawn[c.id] = {"paint": paint_count, "spans": drawn}
	return true


func _draw_ramp_wave(c: Clip, handle: int, stream: int, tier: int, stride: int, r: Rect2, clip_x0: float, band: Rect2) -> bool:
	if not AnimProp.is_animated(c.speed):
		return false
	var spans: Array = Waves.ramp_spans(c)
	if spans.is_empty():
		return false
	_draw_spans(c, spans, handle, stream, tier, stride, r, clip_x0, band)
	return true


func _draw_spans(c: Clip, spans: Array, handle: int, stream: int, tier: int, stride: int, r: Rect2, clip_x0: float, band: Rect2) -> Array[Dictionary]:
	var drawn: Array[Dictionary] = []
	var d0: Project = doc()
	var owner_item: MediaItem = d0.media_by_id(c.media_id) if d0 != null else null
	for sp: Dictionary in spans:
		var v: float = float(sp["v"])
		var xa: float = clip_x0 + (float(sp["t0"]) - c.start) * pps
		var xb: float = clip_x0 + (float(sp["t1"]) - c.start) * pps
		var a: float = maxf(xa, r.position.x)
		var b: float = minf(xb, r.end.x)
		if b <= a or absf(v) <= Waves.HEARD_SPEED_EPS:
			continue
		var scale_x: float = pps / v
		var origin_x: float = xa - float(sp["s0"]) * scale_x
		var lo: float = minf(float(sp["s0"]), float(sp["s1"]))
		var hi: float = maxf(float(sp["s0"]), float(sp["s1"]))
		var sub: Rect2 = Rect2(a, r.position.y, b - a, r.size.y)
		var st: int = int(sp.get("stream", stream))
		if StreamOff.is_off(owner_item, st):
			continue
		var fine: float = Waves.fine_wave_rate(handle, st, sub, origin_x, scale_x, lo, hi, peaks_provider.is_valid())
		_draw_heard_windows(c.id, handle, st, tier, 1 if fine > 0.0 else stride, sub, origin_x, scale_x, Rect2(a, band.position.y, b - a, band.size.y), lo, hi, fine)
		drawn.append({"t0": c.start + (a - clip_x0) / pps, "t1": c.start + (b - clip_x0) / pps, "s0": (a - origin_x) / scale_x, "s1": (b - origin_x) / scale_x, "stream": st})
	return drawn


func _draw_heard_windows(clip_id: String, handle: int, stream: int, tier: int, stride: int, r: Rect2, origin_x: float, scale_x: float, band: Rect2, lo: float, hi: float, fine_rate: float) -> void:
	var rate: float = fine_rate if fine_rate > 0.0 else Lanes.tier_rate(tier)
	var vis: Vector2 = Waves.visible_span(r, origin_x, scale_x, lo, hi)
	if vis.y <= vis.x:
		return
	var coverage: PackedByteArray = _coverage(handle, stream)
	var smooth: int = Paint.wave_smooth_steps(float(stride) / rate * absf(scale_x))
	var win_b: int = Waves.window_buckets(stride, smooth)
	var head: String = "heard|" + clip_id + "|" + str(handle) + "|" + str(stream) + "|" + (str(tier) if fine_rate <= 0.0 else "f" + str(int(fine_rate))) + "|" + str(stride) + "|" + str(smooth) + "|" + str(win_b) + "|" + ("L" if wave_log else "N") + String.num(wave_gain, 1) + "|"
	var centre_y: float = band.get_center().y
	var half: float = band.size.y * 0.5
	var k0: int = int(floor(vis.x / Lanes.CHUNK_SECONDS))
	var k1: int = int(floor(maxf(vis.y - 0.000001, vis.x) / Lanes.CHUNK_SECONDS))
	for k: int in range(k0, k1 + 1):
		var cs0: float = maxf(float(k) * Lanes.CHUNK_SECONDS, 0.0)
		var cs1: float = float(k + 1) * Lanes.CHUNK_SECONDS
		var v0: float = maxf(cs0, vis.x)
		var v1: float = minf(cs1, vis.y)
		if v1 <= v0:
			continue
		if fine_rate <= 0.0 and not _chunk_ready(coverage, k):
			if not peaks_provider.is_valid():
				Session.want_peaks(handle, stream, v0)
			_wave_waiting[handle] = true
			wave_stats["loading"] = int(wave_stats["loading"]) + 1
			_wave_block(minf(origin_x + v0 * scale_x, origin_x + v1 * scale_x), maxf(origin_x + v0 * scale_x, origin_x + v1 * scale_x), band, true)
			continue
		var j0: int = int(floor(v0 * rate / float(win_b)))
		var j1: int = int(floor((v1 * rate - 0.000001) / float(win_b)))
		for j: int in range(j0, maxi(j0, j1) + 1):
			var ws0: float = maxf(float(j * win_b) / rate, cs0)
			var ws1: float = minf(float((j + 1) * win_b) / rate, cs1)
			if ws1 <= ws0:
				continue
			var key: String = head + str(j) + "|" + String.num(ws0, 4) + "|" + String.num(ws1, 4)
			var pts: PackedVector2Array
			if _wave_cache.has(key):
				pts = _wave_cache[key]
			else:
				var from_bucket: int = Waves.aligned_from(int(floor(ws0 * rate)), j * win_b, stride)
				var end_bucket: int = mini((j + 1) * win_b, int(ceil(ws1 * rate))) + stride
				if ws0 > 0.000001:
					from_bucket = maxi(from_bucket - stride, 0)
				var count: int = end_bucket - from_bucket
				if count <= 0:
					continue
				var est: int = Waves.estimate_points(count, stride, smooth)
				if _wave_points_spent > 0 and _wave_points_spent + est > WAVE_BUDGET:
					_wave_more = true
					wave_stats["deferred"] = int(wave_stats["deferred"]) + 1
					_wave_block(minf(origin_x + ws0 * scale_x, origin_x + ws1 * scale_x), maxf(origin_x + ws0 * scale_x, origin_x + ws1 * scale_x), band, false)
					continue
				var bytes: PackedByteArray = Waves.fine_read(handle, stream, from_bucket, count, rate) if fine_rate > 0.0 else _peaks(handle, stream, tier, from_bucket, count)
				if fine_rate > 0.0 and bytes.is_empty():
					_wave_more = true
					_wave_block(minf(origin_x + ws0 * scale_x, origin_x + ws1 * scale_x), maxf(origin_x + ws0 * scale_x, origin_x + ws1 * scale_x), band, false)
					continue
				pts = Waves.trim_ribbon(Paint.build_wave_ribbon(bytes, from_bucket, rate, stride, wave_log, wave_gain, smooth, -1.0e30, 1.0e30, ws0, WAVE_CAP), 0.0, ws1 - ws0)
				_wave_points_spent += pts.size() / 2
				wave_stats["built"] = int(wave_stats["built"]) + 1
				wave_stats["points"] = int(wave_stats["points"]) + pts.size() / 2
				_wave_cache[key] = pts
				if _wave_cache.size() > 4000:
					_wave_cache.clear()
					_wave_cache[key] = pts
			var look_key: String = key
			if ws0 < lo or ws1 > hi:
				pts = Waves.trim_sorted(pts, maxf(ws0, lo) - ws0, minf(ws1, hi) - ws0)
				look_key += "|" + String.num(lo, 5) + "|" + String.num(hi, 5)
			if pts.size() < 6:
				continue
			wave_stats["drawn"] = int(wave_stats["drawn"]) + 1
			draw_set_transform(Vector2(origin_x + ws0 * scale_x, centre_y), 0.0, Vector2(scale_x, half))
			var vol: Dictionary = _wave_vol(origin_x, scale_x, ws0)
			WaveLook.draw(self, pts, _wave_base, _wave_scale, scale_x, half, look_key, vol)
			if wave_record: _wave_rec(clip_id, origin_x, scale_x, ws0, centre_y, half, pts, vol)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _heard_watch() -> void:
	var d: Project = doc()
	if d == null or d.serial == _heard_seen:
		return
	_heard_seen = d.serial
	if d.undo.has_live() and Waves.heard_moved(d, seq(), d.undo.live_commands()):
		heard_redraws += 1
		queue_redraw()


const VOLUME_FOLLOW_BUDGET_US := 5000

var volume_redraws: int = 0
var volume_follow_waits: int = 0
var _volume_seen: int = -1
var _volume_pending: bool = false
var _painted_frame: int = -1000000


func volume_follow_gap() -> int:
	return maxi(1, ceili(float(last_draw_usec) / float(VOLUME_FOLLOW_BUDGET_US)))


func _volume_follow_due() -> bool:
	return Engine.get_process_frames() - _painted_frame >= volume_follow_gap()


func _volume_follow() -> void:
	if _volume_follow_due():
		_volume_pending = false
		volume_redraws += 1
		queue_redraw()
	else:
		_volume_pending = true
		volume_follow_waits += 1


func _volume_watch() -> void:
	var d: Project = doc()
	if d == null or d.undo == null:
		return
	if d.undo.live_serial == _volume_seen:
		if _volume_pending:
			_volume_follow()
		return
	_volume_seen = d.undo.live_serial
	if d.undo.has_live() and WaveLook.volume_on() and WaveVolume.live_touches(d.undo.live_commands()):
		_volume_follow()


var wave_record: bool = false
var wave_drawn: Dictionary = {}


func _wave_rec(clip_id: String, origin_x: float, scale_x: float, ws0: float, centre_y: float, half: float, pts: PackedVector2Array, vol: Dictionary = {}) -> void:
	var rec: Dictionary = wave_drawn.get(clip_id, {})
	if rec.is_empty() or int(rec["paint"]) != paint_count:
		if wave_drawn.size() > 512:
			wave_drawn.clear()
		rec = {"paint": paint_count, "windows": []}
		wave_drawn[clip_id] = rec
	(rec["windows"] as Array).append({"origin_x": origin_x, "scale_x": scale_x, "ws0": ws0, "centre_y": centre_y, "half": half, "pts": pts, "vol": vol})


func _draw_thumbs(c: Clip, item: MediaItem, r: Rect2, clip_x0: float, lane_h: float, lane_y: float) -> void:
	if lane_h < float(Tk.px(THUMB_MIN_H)) or item == null:
		return
	var name_h: float = Paint.name_row_h() if lane_h >= 34.0 else 0.0
	var top: float = lane_y + name_h + 1.0
	var h: float = lane_h - name_h - 2.0
	var aspect: float = 16.0 / 9.0
	if item.width > 0 and item.height > 0:
		aspect = float(item.width) / float(item.height)
	var step: float = maxf(h * aspect, 24.0)
	var handle: int = _handle_of(item)
	var can: bool = PurrBridge.available and handle >= 0 and item.kind == "video"
	var pictures: String = clip_pictures()
	if pictures == "none":
		return
	var building: bool = can and strip_building(handle)
	var x: float = clip_x0
	if x < r.position.x - step:
		x = clip_x0 + floor((r.position.x - clip_x0) / step) * step
	var n: int = 0
	var rid: RID = get_canvas_item()
	var still_t: float = float(item.props.get("still_time", -1.0)) if item.props.has("still_time") else -1.0
	if pictures == "head" or still_t >= 0.0:
		if can and clip_x0 + step > r.position.x:
			var head_tex: RID = PurrBridge.strip_frame(handle, still_t if still_t >= 0.0 else c.media_time(t_of(clip_x0), item.duration))
			var hx0: float = maxf(clip_x0, r.position.x)
			var hx1: float = minf(clip_x0 + step, r.end.x)
			if hx1 > hx0:
				if head_tex.is_valid():
					RenderingServer.canvas_item_add_texture_rect(rid, Rect2(hx0, top, hx1 - hx0, h), head_tex)
				elif building:
					Paint.draw_loading(self, Rect2(hx0, top, hx1 - hx0, h), _font, _fs_small)
					thumbs_waiting += 1
		return
	while x < r.end.x and n < 400:
		var x_end: float = minf(x + step, r.end.x)
		if x_end > r.position.x:
			if can:
				var src_t: float = c.media_time(t_of(x), item.duration)
				var tex: RID = PurrBridge.strip_frame(handle, src_t)
				var tx0: float = maxf(x, r.position.x)
				if tex.is_valid():
					RenderingServer.canvas_item_add_texture_rect(rid, Rect2(tx0, top, x_end - tx0, h), tex)
				elif building:
					Paint.draw_loading(self, Rect2(tx0, top, x_end - tx0, h), _font, _fs_small)
					thumbs_waiting += 1
			if x > r.position.x:
				draw_rect(Rect2(x, top, 1.0, h), Color(0.0, 0.0, 0.0, 0.35), true)
		x += step
		n += 1


func _dense_points(t: Track, lane_h: float) -> PackedVector2Array:
	var d: Project = doc()
	var key: String = t.id
	var stamp: String = String.num(pps, 6) + "|" + str(lane_h) + "|" + str(d.serial if d != null else 0)
	if _dense_cache.has(key):
		var rec: Dictionary = _dense_cache[key]
		if String(rec["stamp"]) == stamp:
			return rec["pts"]
	var pts := PackedVector2Array()
	pts.resize(t.clips.size() * 2)
	var yc: float = lane_h * 0.5
	var i: int = 0
	for c: Clip in t.clips:
		pts[i] = Vector2(c.start * pps, yc)
		pts[i + 1] = Vector2(maxf(c.end() * pps, c.start * pps + 1.0), yc)
		i += 2
	_dense_cache[key] = {"stamp": stamp, "pts": pts}
	return pts


func _draw_lane_clips(l: Dictionary, region: Rect2, set_scroll: float) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	var t: Track = l["track"]
	var lane_y: float = region.position.y + float(l["y"]) - set_scroll
	var lane_h: float = float(l["h"])
	if lane_y + lane_h < region.position.y or lane_y > region.end.y:
		return
	var vis_y0: float = maxf(lane_y, region.position.y)
	var vis_y1: float = minf(lane_y + lane_h, region.end.y)
	var is_nest_lane: bool = bool(l["nest"])
	var lane_rect: Rect2 = Rect2(header_w, vis_y0, size.x - header_w, vis_y1 - vis_y0)
	draw_rect(lane_rect, Paint.lane_fill(t.kind, String(l["set"]) == "band", is_nest_lane), true)
	if t.locked:
		Paint.hatch(self, lane_rect, Tk.c["hatch"], 22.0)
	if is_nest_lane:
		Paint.hatch(self, Rect2(header_w, vis_y0, 24.0, vis_y1 - vis_y0), Tk.c["hatch"], 6.0)
	var filt: Filter.State = Filter.begin_lane(self, d, s, l, lane_rect, lane_y, lane_h)
	if filt != null and filt.lane_done:
		return
	var owner: Clip = l.get("owner", null)
	var t0: float = t_of(header_w)
	var t1: float = t_of(size.x)
	var offset_t: float = 0.0
	var scale_t: float = 1.0
	if is_nest_lane and owner != null:
		var sp: float = owner.static_speed()
		if sp == 0.0:
			sp = 1.0
		scale_t = 1.0 / sp
		offset_t = owner.start - owner.in_offset * scale_t
		t0 = (t0 - offset_t) / scale_t
		t1 = (t1 - offset_t) / scale_t
	var i: int = t.index_of_first_visible(t0)
	var j: int = t.index_of_last_starting_before(t1)
	if j < i:
		if not is_nest_lane:
			_draw_free_transitions(s, t, lane_y, lane_h, scale_t, offset_t)
		return
	var far_lane: bool = Far.dense(self, j - i + 1, DENSE_LIMIT) and not is_nest_lane
	var far_wide: PackedInt32Array = Far.draw_dense(self, t, lane_y, lane_h) if far_lane else PackedInt32Array()
	if far_lane and far_wide.is_empty():
		return
	var selected: PackedStringArray = s.selected_clip_ids
	var hover_clip: Clip = hover.get("clip", null)
	var move_ids: PackedStringArray = drag.ids if String(drag.mode) == "move" and drag.active else PackedStringArray()
	var move_steps: int = 0
	if not move_ids.is_empty() and drag.track_delta != 0:
		var anchor_t: Track = s.track_of(String(drag.clip_id))
		move_steps = s.visual_track_delta(anchor_t.kind if anchor_t != null else "video", drag.track_delta)
	var transitions: Array[Dictionary] = []
	var view_cuts: bool = ViewCuts.any(self)
	for idx: int in (far_wide if far_lane else (Stacks.draw_order(t, i, j) if t.has_stack() else range(i, j + 1))):
		var c: Clip = t.clips[idx]
		var cs: float = c.start * scale_t + offset_t
		var ce: float = c.end() * scale_t + offset_t
		var x0: float = x_of(cs)
		var x1: float = x_of(ce)
		if x1 <= header_w or x0 >= size.x:
			continue
		var moving: bool = move_ids.has(c.id)
		var body_y: float = lane_y
		var own_steps: int = 0
		if moving and drag.duplicate:
			_deferred_moves.append(Dup.ghost(self, s, t, c, x0, x1, lane_y, lane_h, move_steps))
			moving = false
		if moving:
			if _fold.is_empty():
				x0 += drag.delta_t * pps
				x1 += drag.delta_t * pps
			else:
				x0 = x_of(cs + drag.delta_t)
				x1 = x_of(ce + drag.delta_t)
			if move_steps != 0 and s.was_picked(c.id):
				own_steps = s.visual_track_delta(t.kind, move_steps)
			if own_steps != 0:
				var dest: Track = s.track_at_offset(t, own_steps)
				var dl: Dictionary = Lanes.lane_for_track(lanes(), dest.id)
				if not dl.is_empty():
					body_y = Hit.lane_screen_y(geometry(), dl)
		var r: Rect2 = Rect2(maxf(x0, header_w), body_y + 1.0, minf(x1, size.x) - maxf(x0, header_w), lane_h - 2.0)
		if r.size.x < 1.0:
			r.size.x = 1.0
		if filt != null and Filter.skip(filt, self, t, c, r):
			continue
		if Far.slim_fast(self, t, c, r, x0, x1, hover_clip == c and not drag.in_progress(), view_cuts, is_nest_lane or (moving and own_steps != 0)):
			if t.is_sound(c) and not moving and _slim_wave_ok(x0, x1):
				_draw_wave(c, d.media_by_id(c.media_id) if d != null else null, r, x0, lane_h, body_y)
			continue
		var item: MediaItem = d.media_by_id(c.media_id) if d != null else null
		if is_nest_lane:
			Paint.draw_body(self, r, Paint.clip_colour(c, item, t), false, false, c.enabled)
			_draw_wave(c, item, r, x0, lane_h, body_y)
			Paint.draw_name(self, r, StreamRoles.shown_label(item, c, t.is_sound(c)), "", _font, _fs_small)
			decorated_clips += 1
			continue
		var is_sel: bool = selected.has(c.id)
		var col: Color = Paint.clip_colour(c, item, t)
		if moving and own_steps != 0:
			_deferred_moves.append({"r": r, "col": col, "sel": is_sel, "enabled": c.enabled, "label": StreamRoles.shown_label(item, c, t.is_sound(c))})
			continue
		var lit: bool = c.enabled and not (t.is_sound(c) and StreamOff.is_off(item, StreamOff.clip_stream(c)))
		if not view_cuts or not ViewCuts.draw_body(self, t, c, r, x0, col, is_sel, hover_clip == c and not drag.in_progress()):
			Paint.draw_body(self, r, col, is_sel, hover_clip == c and not drag.in_progress(), lit)
		decorated_clips += 1
		if c.is_nest():
			Paint.draw_nest_border(self, r)
		if c.view_hidden or t.view_hidden:
			load("res://modules/core_panels/view_hide_ui.gd").call("draw_mark", self, r)
		if item != null and (item.missing or c.placeholder):
			Paint.hatch(self, r, Tk.c["hatch"])
		if item != null and item.kind == "adjust":
			Paint.hatch(self, r, Tk.c["hatch"], 10.0)
		if t.is_sound(c) and r.size.x > 2.0 and not moving:
			_draw_wave(c, item, r, x0, lane_h, body_y)
		elif t.is_picture(c) and item != null and item.kind == "video" and r.size.x > 12.0 and not moving:
			_draw_thumbs(c, item, r, x0, lane_h, body_y)
		if c.is_nest() and bool(c.nest.get("see_inside", false)) and r.size.x > 20.0 and lane_h > 30.0:
			_draw_nest_rows(c, r, x0, lane_y, lane_h)
		Edit.draw_fades(self, s, c, t.clip_kind(c), r, x0, x1, pps)
		if c.loop:
			LoopDraw.draw_seams(self, c, LoopDraw.media_length(d, c, item), r, x0, pps)
		Warn.draw_badge(self, c, r, lane_h)
		if not c.parent.is_empty():
			load(PARENT_UI).call("draw_badge", self, c, r)
		if lane_h >= 34.0:
			var right: String = ""
			if not c.effects.is_empty():
				right = "fx"
			var sp: float = c.static_speed()
			if sp == 0.0:
				right += (" " if not right.is_empty() else "") + Edit.speed_badge(c)
			elif absf(sp - 1.0) > 0.001:
				right += (" " if not right.is_empty() else "") + str(int(round(sp * 100.0))) + "%"
			if c.is_nest():
				var uses: int = nest_uses(c.sequence_id)
				right += (" " if not right.is_empty() else "") + ("nest" if uses <= 1 else "nest ×" + str(uses))
			if not c.link_id.is_empty() and r.size.x > 40.0:
				Icons.draw(self, "link", Rect2(r.position.x + 3.0, r.end.y - 13.0, 10.0, 10.0), Tk.c["text_faint"])
			if c.is_nest() and r.size.x > 24.0:
				Icons.draw(self, "chev_d" if bool(c.nest.get("see_inside", false)) else "chev_r", Rect2(r.position.x + 2.0, r.position.y + 2.0, 10.0, 10.0), Tk.c["text"])
			var name_r: Rect2 = Rect2(r.position + Vector2(10.0 if c.is_nest() else 0.0, 0.0), r.size)
			name_r = Stacks.name_room(self, t, c, name_r)
			if view_cuts:
				name_r = ViewCuts.name_room(self, c, x0, name_r)
			Paint.draw_name(self, name_r, StreamRoles.shown_label(item, c, t.is_sound(c)), right, _font, _fs_small)
		if view_cuts:
			ViewCuts.draw_marks(self, l, t, c, r, x0, lane_h)
		Edit.draw_clip_markers(self, c, r, x0, pps, item)
		if not c.props.is_empty() and SpeedBand.shown(c):
			SpeedBand.draw_clip(self, r, c, pps, x0)
		elif t.is_sound(c):
			Paint.draw_level_line(self, r, c, c.audio.get("volume", AnimProp.make(1.0)), 0.0, 2.0, pps, true, x0)
		else:
			Paint.draw_opacity_line(self, r, c, pps, x0)
			Paint.draw_key_diamonds(self, Rect2(x0, r.position.y, x1 - x0, r.size.y), c, pps, Vector2(header_w, size.x))
		if c.has_transition() and not moving:
			transitions.append({"clip": c, "y": r.position.y, "h": r.size.y, "side": "in"})
		if c.has_transition_out() and not moving:
			transitions.append({"clip": c, "y": r.position.y, "h": r.size.y, "side": "out"})
	if not is_nest_lane:
		Stacks.draw_lane_marks(self, s, t, lane_y, lane_h, t0, t1)
		Solo.draw_lane(self, d, s, t, lane_y, lane_h)
	for tdef: Dictionary in transitions:
		var tc: Clip = tdef["clip"]
		var out_side: bool = String(tdef.get("side", "in")) == "out"
		var span: Vector2 = tc.transition_out_span() if out_side else tc.transition_span()
		_draw_transition_limits(tc, out_side, float(tdef["y"]), float(tdef["h"]), scale_t, offset_t)
		var tx0: float = x_of(span.x * scale_t + offset_t)
		var tx1: float = x_of(span.y * scale_t + offset_t)
		var tr_rect: Rect2 = Rect2(maxf(tx0, header_w), float(tdef["y"]), minf(tx1, size.x) - maxf(tx0, header_w), float(tdef["h"]))
		if tr_rect.size.x < 1.0:
			continue
		var hot: bool = hover_clip == tc and bool(hover.get("transition", false)) and String(hover.get("tr_side", "in")) == String(tdef.get("side", "in")) and not drag.in_progress()
		var picked_tr: Dictionary = Verbs.selected_transition(s)
		var chosen: bool = String(picked_tr.get("clip_id", "")) == tc.id and String(picked_tr.get("side", "in")) == String(tdef.get("side", "in"))
		Paint.draw_transition(self, tr_rect, tx1 - tx0, hot, String(TrRegistry.shared().call("label_for", tc.transition_out if out_side else tc.transition_in)), _font, _fs_small, chosen)
	if not is_nest_lane:
		_draw_free_transitions(s, t, lane_y, lane_h, scale_t, offset_t)


func _draw_free_transitions(s: Sequence, t: Track, lane_y: float, lane_h: float, scale_t: float, offset_t: float) -> void:
	if t.free_transitions.is_empty():
		return
	var hover_free: String = FreeTransition.id_of(hover.get("free", {}))
	var held: Dictionary = s.held_free()
	var picked: String = String(held.get("id", "")) if String(held.get("track_id", "")) == t.id else ""
	var dragging: bool = drag.in_progress() and String(drag.get("mode")) == "free_tr"
	for ft: Dictionary in t.free_transitions:
		var span: Vector2 = FreeTransition.span(ft)
		var fx0: float = x_of(span.x * scale_t + offset_t)
		var fx1: float = x_of(span.y * scale_t + offset_t)
		var r: Rect2 = Rect2(maxf(fx0, header_w), lane_y, minf(fx1, size.x) - maxf(fx0, header_w), lane_h)
		if r.size.x < 1.0:
			continue
		var ft_id: String = FreeTransition.id_of(ft)
		var hot: bool = hover_free == ft_id and not dragging
		Paint.draw_free_transition(self, r, fx1 - fx0, hot, String(TrRegistry.shared().call("label_for", FreeTransition.spec_of(ft))), _font, _fs_small, picked == ft_id)


func _draw_transition_limits(tc: Clip, out_side: bool, y: float, h: float, scale_t: float, offset_t: float) -> void:
	if not drag.in_progress() or String(drag.get("mode")) != "transition" or String(drag.get("clip_id")) != tc.id:
		return
	if (String(drag.get("tr_field")) == "transition_out") != out_side:
		return
	var o: Dictionary = drag.get("origin")
	var lo: float = float(o.get("lo", -INF))
	var hi: float = float(o.get("hi", INF))
	var ink: Color = Color(Tk.c["key_negative"], 0.85)
	for at: float in [lo, hi]:
		if absf(at) > 3000.0:
			continue
		var x: float = x_of(at * scale_t + offset_t)
		if x < header_w or x > size.x:
			continue
		draw_rect(Rect2(x - 1.0, y, 2.0, h), ink, true)
		for k: int in 4:
			var yy: float = y + h * (0.2 + 0.2 * float(k))
			draw_line(Vector2(x, yy), Vector2(x + (6.0 if at == lo else -6.0), yy - 4.0), ink, 1.0)


const PmText := preload("res://ui/kit/pm_text.gd")


func _draw_nest_rows(c: Clip, r: Rect2, x0: float, lane_y: float, lane_h: float) -> void:
	var d: Project = doc()
	if d == null:
		return
	var sub: Sequence = d.sequence_by_id(c.sequence_id)
	if sub == null:
		return
	var y: float = lane_y + Paint.NAME_ROW + 3.0
	var sp: float = c.static_speed()
	if sp == 0.0:
		sp = 1.0
	var origin_x: float = x0 - c.in_offset / sp * pps
	var label_w: float = 26.0
	var rows: Array[Track] = []
	for i: int in range(sub.video_tracks.size() - 1, -1, -1):
		rows.append(sub.video_tracks[i])
	rows.append_array(sub.audio_tracks)
	var bottom: float = lane_y + lane_h - 3.0
	for st: Track in rows:
		if st.hidden:
			continue
		var rh: float = Lanes.default_height(st.kind) * Lanes.NEST_SCALE * 0.5
		if y + rh > bottom:
			break
		var row_rect: Rect2 = Rect2(r.position.x + 2.0, y, r.size.x - 4.0, rh)
		draw_rect(row_rect, Paint.lane_fill(st.kind, false, false), true)
		PmText.draw(self, _font, Rect2(row_rect.position.x, y, label_w, rh), st.label, Tk.fs(Tk.sz("font_tiny")), Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, PmText.chip_pad())
		var lt0: float = (t_of(row_rect.position.x + label_w) - c.start) * sp + c.in_offset
		var lt1: float = (t_of(row_rect.end.x) - c.start) * sp + c.in_offset
		var i: int = st.index_of_first_visible(lt0)
		var n: int = 0
		while i < st.clips.size() and st.clips[i].start < lt1 and n < 200:
			var sc: Clip = st.clips[i]
			var sx0: float = maxf(origin_x + sc.start / sp * pps, row_rect.position.x + label_w)
			var sx1: float = minf(origin_x + sc.end() / sp * pps, row_rect.end.x)
			if sx1 > sx0:
				var sr: Rect2 = Rect2(sx0, y + 1.0, sx1 - sx0, rh - 2.0)
				var item: MediaItem = d.media_by_id(sc.media_id)
				Paint.draw_body(self, sr, Paint.clip_colour(sc, item, st), false, false, sc.enabled)
				if sr.size.x > 40.0:
					PmText.draw(self, _font, sr, StreamRoles.shown_label(item, sc, st.is_sound(sc)), Tk.fs(Tk.sz("font_tiny")), Tk.c["text"], HORIZONTAL_ALIGNMENT_LEFT, PmText.chip_pad())
			i += 1
			n += 1
		y += rh + 2.0


func _draw_set(set_name: String, region: Rect2, set_scroll: float, lane_list: Array[Dictionary], ground: Color) -> void:
	if region.size.y <= 0.0:
		return
	draw_rect(region, ground, true)
	PmText.cover(self, region)
	for l: Dictionary in lane_list:
		_draw_lane_clips(l, region, set_scroll)
		Filter.after_lane(self, l, region, set_scroll)
		var ly: float = region.position.y + float(l["y"]) + float(l["h"]) - set_scroll
		if ly >= region.position.y and ly <= region.end.y:
			draw_rect(Rect2(header_w, ly, size.x - header_w, 1.0), Tk.c["lane_line"], true)
	var ln: Dictionary = lanes()
	if set_name == "main" and float(ln["nested_audio_y"]) >= 0.0:
		var ny: float = region.position.y + float(ln["nested_audio_y"]) - set_scroll
		if ny >= region.position.y and ny < region.end.y:
			draw_rect(Rect2(0.0, ny, size.x, Paint.NAME_ROW + 2.0), Tk.c["bg_panel_alt"], true)
			PmText.draw(self, _font, Rect2(0.0, ny, size.x, Paint.NAME_ROW + 2.0), "NESTED AUDIO", Tk.fs(Tk.sz("font_tiny")), Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, PmText.pad(), ny + Paint.NAME_ROW - 2.0)
	for l: Dictionary in lane_list:
		var lane_y: float = region.position.y + float(l["y"]) - set_scroll
		var lane_h: float = float(l["h"])
		if lane_y + lane_h < region.position.y or lane_y > region.end.y:
			continue
		var hr: Rect2 = Rect2(0.0, maxf(lane_y, region.position.y), header_w, minf(lane_y + lane_h, region.end.y) - maxf(lane_y, region.position.y))
		if bool(l["nest"]):
			draw_rect(hr, Tk.c["bg_panel_alt"], true)
			Paint.hatch(self, hr, Tk.c["hatch"], 8.0)
			var st: Track = l["track"]
			var owner: Clip = l["owner"]
			PmText.draw_in(self, _font, Rect2(8.0, hr.position.y, header_w - 8.0 - PmText.pad(), hr.size.y), st.label + " (" + (owner.label if owner != null else "nest") + ")", _fs_small, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, hr.position.y + 4.0 + _font.get_ascent(_fs_small), PmText.ELIDE, hr)
			continue
		Tracks.draw(self, l["track"], Rect2(0.0, lane_y, header_w, lane_h), set_name == "band", focused and hover.get("track", null) == l["track"], _font, _fs, _rename != null and _rename_track == (l["track"] as Track).id, _track_selected((l["track"] as Track).id))
		drawn_headers += 1
	draw_rect(Rect2(header_w - 1.0, region.position.y, 1.0, region.size.y), Tk.c["border"], true)


func _draw() -> void:
	var t0: int = Time.get_ticks_usec()
	paint_count += 1
	_painted_frame = Engine.get_process_frames()
	_volume_pending = false
	_wave_points_spent = 0
	_wave_more = false
	_wave_begin_frame()
	decorated_clips = 0
	drawn_headers = 0
	thumbs_waiting = 0
	var s: Sequence = seq()
	draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_panel"], true)
	if s == null:
		PmText.draw(self, _font, Rect2(header_w, ruler_h(), size.x - header_w, 48.0), "No sequence is open", _fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, 12.0, ruler_h() + 24.0)
		last_draw_usec = Time.get_ticks_usec() - t0
		return
	var g: Dictionary = geometry()
	var ln: Dictionary = lanes()
	_paint_fold = g["fold"]
	_in_paint = true
	profile["geometry"] = Time.get_ticks_usec() - t0
	if trim_anim != null:
		trim_anim.call("pose")
	ViewCuts.begin_paint(self)
	var main_rect: Rect2 = g["main_rect"]
	var band_rect: Rect2 = g["band_rect"]
	var div_rect: Rect2 = g["divider_rect"]
	var t_sets: int = Time.get_ticks_usec()
	_deferred_moves.clear()
	PmText.keep_out(self, Groups.tag_rects(self))
	_draw_set("main", main_rect, scroll_y, ln["main"], Tk.c["bg_lane_video"])
	Paint.draw_fold_seams(self, g["fold"], header_w, pps, scroll_x, main_rect.position.y, main_rect.end.y, size.x)
	profile["main_set"] = Time.get_ticks_usec() - t_sets
	profile["before_sets"] = t_sets - t0
	if band_rect.size.y > 0.0:
		_draw_set("band", band_rect, band_scroll_y, ln["band"], Tk.c["bg_pinned"])
		Paint.draw_fold_seams(self, g["fold"], header_w, pps, scroll_x, band_rect.position.y, band_rect.end.y, size.x)
		var vs: Rect2 = Rect2(size.x - VSCROLL_W, band_rect.position.y, VSCROLL_W, band_rect.size.y)
		Paint.draw_scrollbar(self, vs, band_scroll_y, float(ln["band_h"]), band_rect.size.y, true)
	for dm: Dictionary in _deferred_moves:
		var mr: Rect2 = dm["r"]
		Paint.draw_body(self, mr, dm["col"], bool(dm["sel"]), false, bool(dm["enabled"]))
		Paint.draw_name(self, mr, String(dm["label"]), "", _font, _fs_small)
		if bool(dm.get("dup", false)):
			Dup.draw_mark(self, mr)
	_deferred_moves.clear()
	Groups.draw(self)
	FenceLook.draw(self, self, g)
	Censor.draw(self)
	TrackerBand.draw(self)
	ObjectBand.draw(self)
	Keys.draw(self)
	SpeedBand.draw_drag(self)
	var top_of_sets: float = main_rect.position.y
	if band_rect.size.y > 0.0:
		top_of_sets = minf(top_of_sets, band_rect.position.y)
	if top_of_sets > 0.0:
		draw_rect(Rect2(0.0, 0.0, size.x, top_of_sets), Tk.c["bg_panel"], true)
		PmText.cover(self, Rect2(0.0, 0.0, size.x, top_of_sets))
	if div_rect.size.y > 0.0:
		draw_rect(div_rect, Tk.c["bg_panel"], true)
		PmText.cover(self, div_rect)
		Paint.draw_grip(self, div_rect, String(hover.get("zone", "")) == "divider")
		var text: String = "PINNED · " + str((ln["band"] as Array).size()) + " · " + ("bottom" if band_at_bottom() else "top")
		draw_rect(Rect2(0.0, div_rect.position.y, header_w, div_rect.size.y), Tk.c["bg_panel_alt"], true)
		Icons.draw(self, "chev_r" if band_collapsed() else "chev_d", Rect2(4.0, div_rect.position.y + 2.0, 10.0, 10.0), Tk.c["text_dim"])
		PmText.draw_in(self, _font, Rect2(18.0, div_rect.position.y, header_w - 18.0 - PmText.pad(), div_rect.size.y), text, PmText.size_for(_font, Tk.fs(Tk.sz("font_tiny")), div_rect.size.y), Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, NAN, PmText.ELIDE, Rect2(0.0, div_rect.position.y, header_w, div_rect.size.y))
	if float(ln["main_h"]) > main_rect.size.y:
		var vs2: Rect2 = Rect2(size.x - VSCROLL_W, main_rect.position.y, VSCROLL_W, main_rect.size.y)
		Paint.draw_scrollbar(self, vs2, scroll_y, float(ln["main_h"]), main_rect.size.y, true)
	var rh: float = ruler_h()
	var ruler: Rect2 = Rect2(header_w, 0.0, size.x - header_w, rh)
	var t_ruler: int = Time.get_ticks_usec()
	Paint.draw_ruler(self, ruler, scroll_x, pps, fps(), _font, Tk.fs(Tk.sz("font_tiny")), g["fold"])
	profile["ruler"] = Time.get_ticks_usec() - t_ruler
	_draw_render_bar(ruler)
	_draw_loading_bar(ruler)
	Paint.draw_in_out(self, ruler, x_of(s.in_point) if s.in_point >= 0.0 else -INF, x_of(s.out_point) if s.out_point >= 0.0 else -INF)
	var t_marks: int = Time.get_ticks_usec()
	MarkerLanes.draw_ruler_markers(self, s, rh)
	MarkerLanes.draw(self)
	profile["markers"] = Time.get_ticks_usec() - t_marks
	draw_rect(Rect2(0.0, 0.0, header_w, rh), Tk.c["bg_panel_alt"], true)
	PmText.draw(self, _font, Rect2(0.0, 0.0, header_w, rh), "RENDER", Tk.fs(Tk.sz("font_tiny")), Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, 8.0, rh - 8.0, PmText.WHOLE)
	draw_rect(Rect2(0.0, rh - 1.0, size.x, 1.0), Tk.c["border"], true)
	var hs: Rect2 = g["hscroll_rect"]
	profile["ruler_extras"] = Time.get_ticks_usec() - t_ruler
	if Minimap.on():
		Minimap.draw(self, self, g)
	else:
		Paint.draw_scrollbar(self, hs, scroll_x, Fold.shown(g["fold"], duration()) * pps + view_w() * 0.5, view_w(), false)
	_wave_end_frame()
	if _wave_more:
		queue_redraw()
	profile["tail"] = Time.get_ticks_usec() - t_ruler
	if trim_anim != null:
		trim_anim.call("unpose")
	_in_paint = false
	last_draw_usec = Time.get_ticks_usec() - t0


func _draw_render_bar(ruler: Rect2) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var y: float = ruler.end.y - RENDER_BAR_H - 1.0
	var raw: Variant = d.view.get("render_regions", [])
	if typeof(raw) != TYPE_ARRAY:
		return
	for r: Variant in raw:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var rd: Dictionary = r
		if String(rd.get("seq_id", s.id)) != s.id:
			continue
		var a: float = x_of(float(rd.get("start", 0.0)))
		var b: float = x_of(float(rd.get("end", 0.0)))
		if b < ruler.position.x or a > ruler.end.x:
			continue
		draw_rect(Rect2(maxf(a, ruler.position.x), y, minf(b, ruler.end.x) - maxf(a, ruler.position.x), RENDER_BAR_H), Tk.c["border_soft"], true)


func _loading_media(d: Project) -> Dictionary:
	var out: Dictionary = {}
	loading_sweeps += 1
	if d == null or not PurrBridge.available:
		return out
	var jobs: Array[Dictionary] = Jobs.list()
	if jobs.is_empty():
		return out
	var by_file: Dictionary = {}
	for j: Dictionary in jobs:
		var kind: String = String(j.get("kind", ""))
		if kind != "index" and kind != "strip":
			continue
		var label: String = String(j.get("label", ""))
		var space: int = label.find(" ")
		if space < 0:
			continue
		var file: String = label.substr(space + 1)
		var rec: Dictionary = by_file.get(file, {})
		if not rec.has(kind):
			rec[kind] = clampf(float(j.get("progress", 0.0)), 0.0, 0.99)
		by_file[file] = rec
	if by_file.is_empty():
		return out
	var s: Sequence = seq()
	var used: Dictionary = {}
	if s != null:
		for tr: Track in s.video_tracks:
			for c: Clip in tr.clips:
				used[c.media_id] = true
	for media_id: Variant in used.keys():
		var item: MediaItem = d.media_by_id(String(media_id))
		if item == null:
			continue
		var rec2: Variant = by_file.get(item.path.get_file(), null)
		if rec2 == null:
			continue
		var h: int = int(Session.media_handles.get(String(media_id), -1))
		if h < 0:
			continue
		var info: Dictionary = PurrBridge.media_info(h)
		var kinds: Dictionary = rec2
		if String(info.get("index_state", "ready")) == "building" and kinds.has("index"):
			out[String(media_id)] = float(kinds["index"])
		elif String(info.get("strip_state", "ready")) == "building" and kinds.has("strip"):
			out[String(media_id)] = float(kinds["strip"])
		elif String(info.get("index_state", "ready")) == "building" or String(info.get("strip_state", "ready")) == "building":
			out[String(media_id)] = 0.0
	return out


func _draw_loading_bar(ruler: Rect2) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var loading: Dictionary = _loading
	if loading.is_empty():
		return
	var y: float = ruler.end.y - RENDER_BAR_H - 1.0
	var t0: float = t_of(ruler.position.x)
	var t1: float = t_of(ruler.end.x)
	for tr: Track in s.video_tracks:
		var i: int = tr.index_of_first_visible(t0)
		var j: int = tr.index_of_last_starting_before(t1)
		if j - i > 4000:
			continue
		for idx: int in range(i, j + 1):
			if idx < 0 or idx >= tr.clips.size():
				continue
			var c: Clip = tr.clips[idx]
			if not loading.has(c.media_id):
				continue
			var frac: float = float(loading[c.media_id])
			var a: float = maxf(x_of(c.start), ruler.position.x)
			var b: float = minf(x_of(c.end()), ruler.end.x)
			if b <= a:
				continue
			draw_rect(Rect2(a, y, b - a, RENDER_BAR_H), Color(Tk.c["key_over"], 0.25), true)
			draw_rect(Rect2(a, y, (b - a) * frac, RENDER_BAR_H), Tk.c["key_over"], true)


func overlay() -> Control:
	return _overlay


func close_selected_gap() -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or selected_gap.is_empty():
		return false
	var gap: Dictionary = selected_gap
	selected_gap = {}
	_overlay.queue_redraw()
	if Edit.Tools.close_gap(d, s, String(gap["track_id"]), (float(gap["t0"]) + float(gap["t1"])) * 0.5):
		return true
	Events.notice("The gap is held open", "A sync locked track has a clip across it. Turn that track's sync lock off to close the gap on this track alone.")
	return true


func reorder_track_at(track_id: String, pos: Vector2) -> bool:
	return Edit.reorder_at(self, track_id, pos)


class _Overlay:
	extends Control

	const PaintKit := preload("res://ui/timeline/timeline_paint.gd")
	const MarkerLanesKit := preload("res://ui/timeline/timeline_marker_lanes.gd")
	const HitKit := preload("res://ui/timeline/timeline_hit.gd")
	const LanesKit := preload("res://ui/timeline/timeline_lanes.gd")
	const TracksKit := preload("res://ui/timeline/timeline_tracks.gd")
	const EditKit := preload("res://ui/timeline/timeline_edit.gd")
	const StacksKit := preload("res://ui/timeline/timeline_stacks.gd")
	const FxDropKit := preload("res://ui/timeline/timeline_fx_drop.gd")
	const RealignKit := preload("res://ui/timeline/timeline_realign.gd")

	var canvas: Control = null

	func _init() -> void:
		name = "Overlay"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if canvas == null:
			return
		canvas.overlay_paint_count += 1
		var s: RefCounted = canvas.call("seq")
		if s == null:
			return
		var g: Dictionary = canvas.call("geometry")
		var header_w: float = float(g["header_w"])
		var rh: float = float(g["ruler_h"])
		var main_rect: Rect2 = g["main_rect"]
		var band_rect: Rect2 = g["band_rect"]
		var ph: float = float(canvas.call("playhead"))
		var trim_anim: Node = canvas.get("trim_anim")
		if trim_anim != null:
			ph = float(trim_anim.call("pose_and_playhead", ph))
		var px: float = float(canvas.call("x_of", ph))
		var drag: RefCounted = canvas.get("drag")
		var f: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_small"))
		if not (canvas.get("meters") as PackedFloat32Array).is_empty():
			var lanes: Dictionary = canvas.call("lanes")
			var m: PackedFloat32Array = canvas.get("meters")
			var audio_index: int = 0
			for key: String in ["main", "band"]:
				for l: Dictionary in lanes[key]:
					var t: RefCounted = l["track"]
					if not bool(t.call("makes_sound")) or bool(l["nest"]):
						continue
					var y: float = HitKit.lane_screen_y(g, l)
					var region: Rect2 = main_rect if key == "main" else band_rect
					if y >= region.position.y and y + float(l["h"]) <= region.end.y:
						var level: float = StacksKit.meter_level(canvas, t, m)
						TracksKit.draw_meter(self, Rect2(0.0, y, header_w, float(l["h"])), level)
					audio_index += 1
		if px >= header_w - 1.0 and px <= size.x:
			MarkerLanesKit.draw_playhead(self, canvas, px, 0.0, size.y - float((g["hscroll_rect"] as Rect2).size.y), ph)
		if Minimap.on():
			var mhs: Rect2 = g["hscroll_rect"]
			var mpx: float = Minimap.x_of(canvas, g, mhs, ph)
			draw_rect(Rect2(mpx, mhs.position.y + 1.0, 1.0, mhs.size.y - 2.0), Tk.c["accent"], true)
		var snap_x: float = float(drag.get("snap_x"))
		if snap_x > -INF and drag.get("active"):
			draw_rect(Rect2(snap_x, rh, 1.0, size.y - rh), Tk.c["accent_dim"], true)
		if String(drag.get("mode")) == "range" and bool(drag.get("active")):
			var r: Rect2 = drag.call("marquee_rect")
			draw_rect(r, Tk.c["selection_fill"], true)
			draw_rect(r, Tk.c["accent"], false, 1.0)
		if String(drag.get("mode")) == "marker_range" and bool(drag.get("active")):
			var mr: Rect2 = drag.call("marker_rect")
			draw_rect(mr, Tk.c["selection_fill"], true)
			draw_rect(mr, Tk.c["accent"], false, 1.0)
		for dr: Rect2 in (drag.get("doomed") as Array):
			PaintKit.hatch(self, dr, Tk.c["hatch"], 6.0)
		var dp: Dictionary = canvas.get("drop_preview")
		if not dp.is_empty() and String(dp.get("kind", "")) != "replace":
			_draw_drop_preview(dp, g, f, fs)
		var anim: Dictionary = canvas.get("_pin_anim")
		if not anim.is_empty():
			var u: float = clampf(float(Time.get_ticks_msec() - int(anim["t0"])) / (float(anim["dur"]) * 1000.0), 0.0, 1.0)
			var e: float = 1.0 - pow(1.0 - u, 3.0)
			var from: Rect2 = anim["from"]
			var to: Rect2 = anim["to"]
			var r2: Rect2 = Rect2(from.position.lerp(to.position, e), from.size.lerp(to.size, e))
			draw_rect(r2, Color(Tk.c["bg_pinned"], 0.6 * (1.0 - u) + 0.2), true)
			draw_rect(r2, Color(Tk.c["accent_dim"], 1.0 - u), false, 1.0)
		var hov: Dictionary = canvas.get("hover")
		if String(hov.get("zone", "")) == "lane" and bool(hov.get("level", false)) and hov.get("clip", null) != null:
			draw_rect(Rect2(header_w, float(hov.get("y", 0.0)) - 1.0, 0.0, 0.0), Tk.c["accent"], true)
		EditKit.draw_overlay(canvas, self)
		StacksKit.draw_overlay(canvas, self)
		RealignKit.draw_overlay(canvas, self)
		if trim_anim != null:
			trim_anim.call("unpose")

	func _draw_drop_preview(dp: Dictionary, g: Dictionary, f: Font, fs: int) -> void:
		var header_w: float = float(g["header_w"])
		var pps: float = float(g["pps"])
		var kind: String = String(dp.get("kind", ""))
		if kind == "effect" or kind == "preset" or kind == "transition":
			var lane: Dictionary = dp.get("lane", {})
			if lane.is_empty():
				return
			var y: float = HitKit.lane_screen_y(g, lane)
			if kind == "transition":
				var seq_p: Sequence = canvas.call("seq")
				var track_p: Track = lane.get("track", null)
				var cid: String = String(dp.get("clip_id", ""))
				var target: Clip = seq_p.clip_by_id(cid) if seq_p != null and not cid.is_empty() else null
				var want_len: float = float(canvas.call("default_transition_length"))
				if track_p != null and bool(canvas.call("free_drop_wanted", track_p, float(dp.get("t", 0.0)), want_len)):
					var ft0: float = maxf(float(dp.get("t", 0.0)) - want_len * 0.5, 0.0)
					var fx: float = float(canvas.call("x_of", ft0))
					var fw: float = float(canvas.call("px_between", ft0, ft0 + want_len))
					draw_rect(Rect2(fx, y, fw, float(lane["h"])), Color(Tk.c["accent"], 0.25), true)
					draw_rect(Rect2(fx, y, fw, float(lane["h"])), Tk.c["accent"], false, 1.0)
					return
				if target != null and track_p != null:
					var spot: Dictionary = canvas.call("transition_spot", track_p, float(dp.get("t", 0.0)), target)
					var sc: Clip = spot.get("clip", target)
					var at: float = float(spot.get("at", target.start))
					var cx: float = float(canvas.call("x_of", at))
					var wide: float = pps
					var band: Rect2 = Rect2(cx - wide * 0.5, y, wide, float(lane["h"]))
					if String(spot.get("side", "in")) == "out":
						band = Rect2(cx - wide, y, wide, float(lane["h"]))
					elif track_p.prev_clip(sc) == null or absf(track_p.prev_clip(sc).end() - sc.start) > 0.002:
						band = Rect2(cx, y, wide, float(lane["h"]))
					draw_rect(Rect2(cx - 2.0, y, 4.0, float(lane["h"])), Tk.c["accent"], true)
					draw_rect(band, Color(Tk.c["accent"], 0.25), true)
				return
			if kind == "effect" and FxDropKit.draw(self, canvas, dp, g, f, fs):
				return
			draw_rect(Rect2(header_w, y, size.x - header_w, float(lane["h"])), Tk.c["selection_fill"], true)
			return
		var t: float = float(dp.get("t", 0.0))
		var x: float = float(canvas.call("x_of", t))
		var spans: Array = dp.get("spans", [])
		var total: float = float(dp.get("total", 0.0))
		var w: float = maxf(float(canvas.call("px_between", t, t + total)), 4.0)
		var col: Color = Color(Tk.c["accent"], 0.28)
		var video_lane: Dictionary = dp.get("video_lane", {})
		var audio_lane: Dictionary = dp.get("audio_lane", {})
		var new_track: bool = bool(dp.get("new_track", false))
		var insert: bool = bool(dp.get("insert", false)) or bool(dp.get("overlap", false))
		var refused: String = String(dp.get("refused", ""))
		if not refused.is_empty():
			col = Color(Tk.c["bg_panel_high"], 0.92)
			insert = false
		var rects: Array[Rect2] = []
		if not video_lane.is_empty():
			rects.append(Rect2(x, HitKit.lane_screen_y(g, video_lane) + 1.0, w, float(video_lane["h"]) - 2.0))
		if not audio_lane.is_empty():
			rects.append(Rect2(x, HitKit.lane_screen_y(g, audio_lane) + 1.0, w, float(audio_lane["h"]) - 2.0))
		if new_track or rects.is_empty():
			var main_rect: Rect2 = g["main_rect"]
			var ny: float = main_rect.position.y + float(g["main_h"]) - float(g["scroll_y"])
			var nh: float = LanesKit.default_height("video") * 0.6
			if ny + nh <= main_rect.end.y + nh:
				draw_rect(Rect2(0.0, ny, size.x, nh), Tk.c["bg_panel_alt"], true)
				PmText.draw(self, f, Rect2(0.0, ny, header_w, nh), "new track", fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, 8.0, ny + nh * 0.5 + 4.0)
				if new_track or rects.is_empty():
					rects.append(Rect2(x, ny + 1.0, w, nh - 2.0))
		for r: Rect2 in rects:
			draw_rect(r, col, true)
			if not insert:
				PaintKit.hatch(self, r, Tk.c["hatch"], 6.0)
			draw_rect(r, Tk.c["accent"], false, 1.5)
			var st: float = t
			for sp: Variant in spans:
				st += float(sp)
				var sx: float = r.position.x + float(canvas.call("px_between", t, st))
				if sx < r.end.x - 1.0:
					draw_rect(Rect2(sx, r.position.y, 1.0, r.size.y), Tk.c["accent"], true)
			PmText.draw(self, f, r, String(dp.get("label", "")), fs, Tk.c["text_dim"] if not refused.is_empty() else Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, PmText.pad(), r.position.y + 2.0 + f.get_ascent(fs))

extends VBoxContainer

const Project := preload("res://doc/project.gd")
const WaveLook := preload("res://ui/timeline/wave_look.gd")
const WaveVolume := preload("res://ui/timeline/wave_volume.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ViewMap := preload("res://doc/view_map.gd")
const ViewOffsets := preload("res://doc/view_offsets.gd")
const ViewStreams := preload("res://doc/view_streams.gd")
const Timecode := preload("res://doc/timecode.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const PairCmds := preload("res://doc/commands/pair_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const Verbs := preload("res://doc/verbs.gd")
const Waves := preload("res://ui/timeline/timeline_wave.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const StreamListen := preload("res://modules/core_panels/stream_listen.gd")
const OffsetMarks := preload("res://modules/core_panels/offset_marks.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const ZOOM_SETTLE_MS := 140
const PLAY_TAIL := 0.05
const SELF_PATH := "res://modules/core_panels/offset_editor.gd"
const PAIR_VIEW_ID := "pair_view"
const WINDOW_KEY := "controls.offset_editor"
const MENU_ID := "pair_offset_editor"
const HEAD_W := 262.0
const LANE_H := 64.0
const RULER_H := 20.0
const SPANS: Array[float] = [1.0, 4.0, 10.0]
const NUDGES: Array[float] = [-0.01, -0.001, 0.001, 0.01]
const LISTEN_SECONDS := 3.0
const TIER_RATE := 100.0
const PEAK_CHUNK_SECONDS := 120.0
const FLOOR_DB := -48.0
const DRAG_SNAP := 0.001
const DRAG_FINE := 0.0001
const DRAG_START_PX := 3.0
const EPS := 0.0000005
const GROW_SECONDS := 0.25

static var _open: Dictionary = {}

var seq_id: String = ""
var clip_id: String = ""
var uid: String = ""
var span: float = 4.0
var cut_only: bool = false
var peaks_provider: Callable = Callable()
var coverage_provider: Callable = Callable()
var growth_repaints: int = 0
var _wave_waiting: Dictionary = {}
var _grow_armed: bool = false
var lanes: Array[Control] = []
var fields: Array[Control] = []
var drag: Dictionary = {}
var draws: int = 0
var _heads: Array[Label] = []
var _around: Label = null
var _ruler: Control = null
var _span_btns: Array[Button] = []
var _listen_btns: Dictionary = {}
var _together: Button = null
var _cut_btn: Button = null
var _cut_note: Label = null
var _hint: Label = null
var _sig: String = ""
var _watched: WeakRef = null
var together: bool = true
var focus_view: int = 0
var playing: bool = false
var play_views: PackedInt32Array = PackedInt32Array()
var play_from: float = 0.0
var play_ms: int = 0
var head: float = 0.0
var computed_columns: int = 0
var _gen: int = 0
var _col_cache: Dictionary = {}
var _sound_cache: Dictionary = {}
var _last_drawn: Dictionary = {}
var _zoom_ms: int = -100000
var _settle_armed: bool = false
var _play_btn: Button = null
var _marks_note: Label = null
var _follow_btn: Button = null


static func key_of(p_clip_id: String, p_uid: String) -> String:
	return p_clip_id + "|" + p_uid


static func pair_uid(c: Clip) -> String:
	if c == null:
		return ""
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) == PAIR_VIEW_ID:
			return String(e.get("uid", ""))
	return ""


static func window_for(p_clip_id: String, p_uid: String) -> Control:
	var wr: Variant = _open.get(key_of(p_clip_id, p_uid), null)
	if wr is WeakRef:
		var w: Variant = (wr as WeakRef).get_ref()
		if w is Control and is_instance_valid(w) and (w as Control).is_inside_tree():
			return w
	_open.erase(key_of(p_clip_id, p_uid))
	return null


static func open_for(host: Node, p_clip_id: String, p_uid: String) -> Control:
	var have: Control = window_for(p_clip_id, p_uid)
	if have != null:
		have.call("raise")
		return have
	var s: Sequence = Session.seq()
	var d: Project = Session.doc
	if s == null or d == null:
		return null
	var c: Clip = s.clip_by_id(p_clip_id)
	if c == null or c.effect_by_uid(p_uid).is_empty():
		return null
	var script: GDScript = load(SELF_PATH)
	var ed: Control = script.new()
	ed.call("setup", s.id, p_clip_id, p_uid)
	var n: int = maxi(ViewMap.crop_count(c.effect_by_uid(p_uid)), 1)
	var row: float = float(Tk.px(Tk.sz("row_h")))
	var h: float = row * 3.0 + float(Tk.px(Tk.sz("gap"))) * 2.0 + 6.0 + float(Tk.px(RULER_H)) + float(Tk.px(LANE_H)) * float(n) + 12.0
	var root: Node = host if host != null and host.is_inside_tree() else (Engine.get_main_loop() as SceneTree).root
	var w: Control = PmWindow.open(root, "Offsets: " + (c.label if not c.label.is_empty() else c.id), ed, Vector2(float(Tk.px(840.0)), h), WINDOW_KEY)
	_open[key_of(p_clip_id, p_uid)] = weakref(w)
	w.connect("closed", func() -> void:
		StreamListen.instance().call("stop")
		_open.erase(key_of(p_clip_id, p_uid)))
	return w


static func button(panel: Object, p_uid: String) -> Button:
	var b: Button = PmButton.make("Offset", "slip")
	b.name = "OffsetEditorButton"
	b.set("quiet", true)
	PmUI.tip(b, "Open the offset editor: each region's sound lined up against the others, to drag or nudge into sync")
	b.pressed.connect(func() -> void:
		var c: Clip = panel.call("target_clip")
		if c != null:
			open_for(panel.get("_root"), c.id, p_uid))
	return b


static func clip_menu_items(c: Clip) -> Array:
	if pair_uid(c).is_empty():
		return []
	return [PmMenu.item(MENU_ID, "Offset editor")]


static func on_clip_menu(id: String, p_clip_id: String) -> bool:
	if id != MENU_ID:
		return false
	var s: Sequence = Session.seq()
	var c: Clip = s.clip_by_id(p_clip_id) if s != null else null
	var u: String = pair_uid(c)
	if not u.is_empty():
		open_for(null, p_clip_id, u)
	return true


func setup(p_seq_id: String, p_clip_id: String, p_uid: String) -> void:
	seq_id = p_seq_id
	clip_id = p_clip_id
	uid = p_uid


func _ready() -> void:
	name = "OffsetEditor"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)
	span = _saved_span()
	cut_only = _saved_cut_only()
	together = _saved_together()
	focus_mode = Control.FOCUS_ALL
	set_process(false)
	gui_input.connect(_on_input)
	_build()
	Session.playhead_changed.connect(_on_playhead)
	Session.project_changed.connect(_on_project)
	_watch_doc()
	var st: RefCounted = StreamListen.instance()
	st.connect("changed", _sync_listen)
	if PurrBridge.has_signal("peaks_progress") and not PurrBridge.peaks_progress.is_connected(_on_peaks_progress):
		PurrBridge.peaks_progress.connect(_on_peaks_progress)


func _exit_tree() -> void:
	if Session.playhead_changed.is_connected(_on_playhead):
		Session.playhead_changed.disconnect(_on_playhead)
	if Session.project_changed.is_connected(_on_project):
		Session.project_changed.disconnect(_on_project)
	var st: RefCounted = StreamListen.instance()
	if st.is_connected("changed", _sync_listen):
		st.disconnect("changed", _sync_listen)
	var d: Object = _watched.get_ref() if _watched != null else null
	if d != null and (d as Project).changed.is_connected(_on_doc_changed):
		(d as Project).changed.disconnect(_on_doc_changed)
	if PurrBridge.has_signal("peaks_progress") and PurrBridge.peaks_progress.is_connected(_on_peaks_progress):
		PurrBridge.peaks_progress.disconnect(_on_peaks_progress)


func _saved_together() -> bool:
	if not Prefs.is_registered("controls.offset_together"):
		Prefs.register("controls.offset_together", true, {"label": "Offset editor: Play plays every view together (off: only the lane you clicked)", "type": "bool"})
	return bool(Prefs.get_value("controls.offset_together"))


func set_together(on: bool) -> void:
	together = on
	if Prefs.is_registered("controls.offset_together"):
		Prefs.set_value("controls.offset_together", on)
	if _together != null and is_instance_valid(_together):
		_together.set_pressed_no_signal(on)
	if playing:
		var at: float = head
		stop_play(false)
		start_play(at)


func _process(_delta: float) -> void:
	if not playing:
		set_process(false)
		return
	var st: RefCounted = StreamListen.instance()
	var c: Clip = clip()
	head = play_from + float(Time.get_ticks_msec() - play_ms) / 1000.0
	if c == null or head >= c.end() - PLAY_TAIL or not bool(st.call("on_views", clip_id, play_views)):
		stop_play(true)
		return
	if _around != null and is_instance_valid(_around):
		var s: Sequence = sequence()
		_around.text = Timecode.format(head, s.fps if s != null else 30.0)
	_redraw_all()


func centre() -> float:
	return head if playing else Session.playhead()


func start_play(at: float = NAN) -> bool:
	var c: Clip = clip()
	if c == null:
		return false
	var from_t: float = clampf(Session.playhead() if is_nan(at) else at, c.start, c.end())
	var views: PackedInt32Array = PackedInt32Array() if together else PackedInt32Array([clampi(focus_view, 0, maxi(region_count() - 1, 0))])
	var st: RefCounted = StreamListen.instance()
	var ok: bool = bool(st.call("play_views", doc(), sequence(), c, uid, views, from_t, maxf(c.end() - from_t, 0.1)))
	if not ok:
		Events.toast("The sound engine is not available, so nothing can be played")
		_sync_listen()
		return false
	playing = true
	play_views = views
	play_from = from_t
	play_ms = Time.get_ticks_msec()
	head = from_t
	set_process(true)
	_sync_listen()
	return true


func stop_play(move_playhead: bool) -> void:
	if not playing:
		return
	playing = false
	set_process(false)
	var st: RefCounted = StreamListen.instance()
	if bool(st.call("on_views", clip_id, play_views)):
		st.call("stop")
	if move_playhead:
		Session.set_playhead(maxf(head, 0.0))
	_sync_listen()
	_refresh()


func toggle_play() -> bool:
	if playing:
		stop_play(true)
		return false
	return start_play()


func marks() -> Array[Dictionary]:
	return OffsetMarks.marks_of(entry())


func _write_marks(list: Array[Dictionary], label: String) -> bool:
	var d: Project = doc()
	if d == null or clip() == null:
		return false
	var cmd: Command = EffectCmds.SetEffectParam.new(seq_id, clip_id, uid, OffsetMarks.MARKS_KEY, OffsetMarks.marks_text(list))
	cmd.label = label
	return Verbs.run(d, label, [cmd])


func mark(v: int = -1) -> bool:
	var c: Clip = clip()
	if c == null or region_count() <= 0:
		return false
	var view: int = clampi(focus_view if v < 0 else v, 0, region_count() - 1)
	var t: float = clampf(centre(), c.start, c.end())
	var o: float = ViewMap.offset_at(entry(), view, c, t - c.start)
	var before: int = OffsetMarks.of_view(marks(), view).size()
	var list: Array[Dictionary] = OffsetMarks.with_mark(marks(), view, t, o)
	var ok: bool = _write_marks(list, "Sync mark")
	if ok and OffsetMarks.of_view(list, view).size() < before:
		Events.toast("Mark removed")
	return ok


func clear_marks() -> bool:
	if marks().is_empty():
		return false
	return _write_marks([] as Array[Dictionary], "Clear sync marks")


func set_follow(on: bool) -> void:
	var d: Project = doc()
	if d == null or clip() == null:
		return
	var cmd: Command = EffectCmds.SetEffectParam.new(seq_id, clip_id, uid, OffsetMarks.FOLLOW_KEY, on)
	cmd.label = "Carry the offset across cuts"
	Verbs.run(d, cmd.label, [cmd])


func line_up() -> int:
	var c: Clip = clip()
	var e: Dictionary = entry()
	var d: Project = doc()
	var list: Array[Dictionary] = marks()
	if c == null or e.is_empty() or d == null:
		return 0
	var ref: int = OffsetMarks.reference_view(list)
	if ref < 0:
		Events.toast("Press M on two lanes at the same moment first, then Line up")
		return 0
	var sound: bool = not ViewMap.of(e).is_empty()
	var cmds: Array[Command] = []
	var most: int = 0
	for v: int in region_count():
		if v == ref:
			continue
		var pl: Array[Dictionary] = OffsetMarks.pairs(list, e, c, speed_abs(), ref, v)
		if pl.is_empty():
			continue
		var next: Dictionary = OffsetMarks.lined_prop(e, c, pl)
		if pl.size() == 1 and cut_only:
			next = ViewOffsets.cut_set(e, c, v, ViewOffsets.cut_at(e, c, float(pl[0]["t"]) - c.start), float(pl[0]["need"]), float(pl[0]["t"]) - c.start)
		elif pl.size() == 1 and keyed(v):
			next = ViewMap.offset_plus(ViewMap.offset_prop(e, v), float(pl[0]["need"]) - ViewMap.offset_at(e, v, c, float(pl[0]["t"]) - c.start))
		cmds.append(PairCmds.SetOffset.new(seq_id, clip_id, offset_path(v), next, sound))
		most = maxi(most, pl.size())
	if cmds.is_empty():
		Events.toast("Mark the same moment on another lane too, then Line up")
		return 0
	Verbs.run(d, "Line up marks", cmds)
	Events.toast("Lined up from " + str(most) + (" mark" if most == 1 else " marks") + (", the offset eases between them" if most > 1 else ""))
	return cmds.size()


func match_sound(v: int = -1) -> float:
	var c: Clip = clip()
	var e: Dictionary = entry()
	if c == null or e.is_empty() or region_count() < 2:
		return NAN
	var ref: int = OffsetMarks.reference_view(marks())
	if ref < 0:
		ref = 0
	var view: int = clampi(focus_view if v < 0 else v, 0, region_count() - 1)
	if view == ref:
		view = 1 if ref == 0 else 0
	var mid: float = clampf(centre(), c.start, c.end())
	var rate: float = OffsetMarks.MATCH_RATE
	var room: float = minf(mid - c.start, c.end() - mid)
	var reach_s: float = minf(OffsetMarks.MATCH_REACH, room * 0.5)
	var half_s: float = minf(OffsetMarks.MATCH_HALF, room - reach_s)
	if half_s < 0.25 or reach_s < 0.05:
		Events.toast("Move the playhead further into the clip to match by sound")
		return NAN
	var n: int = int(half_s * 2.0 * rate)
	var reach: int = int(reach_s * rate)
	var a: PackedFloat32Array = _compute(ref, _times(mid - half_s, 1.0 / rate, n))["amps"]
	var b: PackedFloat32Array = _compute(view, _times(mid - half_s - float(reach) / rate, 1.0 / rate, n + reach * 2))["amps"]
	var got: Dictionary = OffsetMarks.best_lag(a, b, reach)
	if float(got["score"]) < 0.2:
		Events.toast("The sounds here do not match well enough, try a louder moment or use marks")
		return NAN
	var delta: float = -float(got["lag"]) / rate * speed_abs()
	if absf(delta) < EPS:
		Events.toast("Already lined up here")
		return 0.0
	nudge(view, delta)
	Events.toast("Matched by sound: " + ("+" if delta > 0.0 else "") + str(snappedf(delta * 1000.0, 0.1)) + " ms")
	return delta


func _wait_key(h: int, st: int) -> String:
	return str(h) + "|" + str(st)


func _coverage(h: int, st: int) -> PackedByteArray:
	if coverage_provider.is_valid():
		return coverage_provider.call(h, st)
	if h < 0 or not PurrBridge.available:
		return PackedByteArray()
	return PurrBridge.peaks_coverage(h, st)


func _chunks_ready(h: int, st: int, lo: float, hi: float) -> bool:
	var cov: PackedByteArray = _coverage(h, st)
	var k0: int = int(floor(lo / PEAK_CHUNK_SECONDS))
	var k1: int = int(floor(hi / PEAK_CHUNK_SECONDS))
	for k: int in range(k0, k1 + 1):
		if k >= cov.size() or cov[k] == 0:
			_wave_waiting[_wait_key(h, st)] = true
			if not peaks_provider.is_valid():
				Session.want_peaks(h, st, float(k) * PEAK_CHUNK_SECONDS)
			return false
	return true


func _on_peaks_progress(h: int, st: int) -> void:
	if _grow_armed or not _wave_waiting.has(_wait_key(h, st)) or not is_inside_tree() or not is_visible_in_tree():
		return
	_grow_armed = true
	get_tree().create_timer(GROW_SECONDS).timeout.connect(_grow_redraw)


func _grow_redraw() -> void:
	_grow_armed = false
	if not is_inside_tree():
		return
	_wave_waiting.clear()
	growth_repaints += 1
	_bump()
	_redraw_all()


func _watch_doc() -> void:
	var d: Project = doc()
	if d != null and not d.changed.is_connected(_on_doc_changed):
		d.changed.connect(_on_doc_changed)
	_watched = weakref(d) if d != null else null


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


func region_count() -> int:
	var e: Dictionary = entry()
	return 0 if e.is_empty() else mini(ViewMap.crop_count(e), ViewMap.REGION_MAX)


func _saved_span() -> float:
	if not Prefs.is_registered("controls.offset_span"):
		Prefs.register("controls.offset_span", 4.0, {"label": "Offset editor shows (seconds)", "type": "float", "min": 0.25, "max": 30.0})
	return clampf(float(Prefs.get_value("controls.offset_span")), 0.25, 30.0)


func _saved_cut_only() -> bool:
	if not Prefs.is_registered("controls.offset_cut_only"):
		Prefs.register("controls.offset_cut_only", false, {"label": "Offset editor changes only the cut at the playhead", "type": "bool"})
	return bool(Prefs.get_value("controls.offset_cut_only"))


func set_cut_only(on: bool) -> void:
	cut_only = on
	if Prefs.is_registered("controls.offset_cut_only"):
		Prefs.set_value("controls.offset_cut_only", on)
	if _cut_btn != null and is_instance_valid(_cut_btn):
		_cut_btn.set_pressed_no_signal(on)
	_refresh()


func cuts() -> Array[Dictionary]:
	var c: Clip = clip()
	if c == null:
		return [] as Array[Dictionary]
	return ViewOffsets.cuts_of(entry(), c)


func cut_now() -> Dictionary:
	var c: Clip = clip()
	if c == null:
		return {}
	return ViewOffsets.cut_at(entry(), c, Session.playhead() - c.start)


func cut_text() -> String:
	var list: Array[Dictionary] = cuts()
	var c: Clip = clip()
	if c == null or list.is_empty():
		return ""
	if list.size() <= 1:
		return "one cut only"
	return "cut " + str(ViewOffsets.cut_index_at(list, Session.playhead() - c.start) + 1) + " of " + str(list.size())


func set_span(v: float) -> void:
	span = clampf(v, 0.25, 30.0)
	if Prefs.is_registered("controls.offset_span"):
		Prefs.set_value("controls.offset_span", span)
	for b: Button in _span_btns:
		b.set_pressed_no_signal(is_equal_approx(float(b.get_meta("span", 0.0)), span))
	_redraw_all()


func window_start() -> float:
	return centre() - span * 0.5


func speed_abs() -> float:
	var c: Clip = clip()
	if c == null:
		return 1.0
	var sp: float = absf(c.static_speed())
	return sp if sp > 0.00001 else 1.0


func offset_now(view: int) -> float:
	var c: Clip = clip()
	if c == null:
		return 0.0
	return ViewMap.offset_at(entry(), view, c, Session.playhead() - c.start)


func keyed(view: int) -> bool:
	return AnimProp.is_animated(ViewMap.offset_prop(entry(), view))


func offset_path(view: int) -> String:
	return "effects." + uid + "." + ViewMap.offset_key(view)


func _signature() -> String:
	var e: Dictionary = entry()
	if e.is_empty():
		return ""
	return ",".join(ViewMap.region_names(e)) + "|" + str(region_count())


func _build() -> void:
	PmUI.clear(self)
	lanes = []
	fields = []
	_heads = []
	_span_btns = []
	_listen_btns = {}
	_sig = _signature()
	_cut_btn = null
	_cut_note = null
	_hint = null
	var bar: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	bar.custom_minimum_size.y = float(Tk.px(Tk.sz("row_h"))) + 6.0
	var pad: Control = Control.new()
	pad.custom_minimum_size.x = float(Tk.px(4.0))
	bar.add_child(pad)
	bar.add_child(PmLabel.dim("Around"))
	_around = PmLabel.mono("", "text")
	bar.add_child(_around)
	_cut_btn = PmButton.make("Only this cut", "razor", true)
	_cut_btn.set("quiet", true)
	_cut_btn.set_pressed_no_signal(cut_only)
	PmUI.tip(_cut_btn, "Change only the cut the playhead is in, so the other cuts of this clip keep their own offsets")
	_cut_btn.toggled.connect(set_cut_only)
	bar.add_child(_cut_btn)
	_cut_note = PmLabel.dim("")
	bar.add_child(_cut_note)
	bar.add_child(PmUI.spacer())
	bar.add_child(PmLabel.dim("Show"))
	for sv: float in SPANS:
		var sb: Button = PmButton.make(str(int(sv)) + " s", "", true)
		sb.set("quiet", true)
		sb.set_meta("span", sv)
		sb.set_pressed_no_signal(is_equal_approx(sv, span))
		PmUI.tip(sb, "Show " + str(int(sv)) + (" second" if sv == 1.0 else " seconds") + " around the playhead. The wheel zooms")
		sb.pressed.connect(set_span.bind(sv))
		_span_btns.append(sb)
		bar.add_child(sb)
	_play_btn = PmButton.make("Play", "play", true)
	_play_btn.name = "PlayButton"
	_play_btn.set("quiet", true)
	PmUI.tip(_play_btn, "Play from the playhead, the waves scroll along. Space plays and stops while this window has the pointer. Stopping leaves the playhead there")
	_play_btn.pressed.connect(toggle_play)
	bar.add_child(_play_btn)
	_together = PmButton.make("Listen together", "", true)
	_together.name = "TogetherButton"
	_together.set("quiet", true)
	_together.set_pressed_no_signal(together)
	PmUI.tip(_together, "On: Play plays every view's sound at its offset at once. Off: only the lane you clicked last")
	_together.toggled.connect(set_together)
	bar.add_child(_together)
	var sync: Button = PmButton.make("Sync timeline", "slide")
	sync.set("quiet", true)
	PmUI.tip(sync, "Open the sync timeline: the regions' pictures and sounds as long lanes in place of the timeline")
	sync.pressed.connect(_on_sync_timeline)
	bar.add_child(sync)
	var done: Button = PmButton.make("Done")
	done.set("quiet", true)
	done.pressed.connect(_on_done)
	bar.add_child(done)
	add_child(bar)
	var ruler_row: HBoxContainer = PmUI.hbox(0)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(float(Tk.px(HEAD_W)), float(Tk.px(RULER_H)))
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ruler_row.add_child(gap)
	_ruler = _Ruler.new()
	_ruler.set("editor", self)
	_ruler.custom_minimum_size.y = float(Tk.px(RULER_H))
	_ruler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ruler_row.add_child(_ruler)
	add_child(ruler_row)
	var e: Dictionary = entry()
	var map: Dictionary = ViewMap.of(e)
	var names: PackedStringArray = ViewMap.region_names(e) if not e.is_empty() else PackedStringArray()
	for v: int in region_count():
		add_child(_lane_row(v, names[v] if v < names.size() else "View " + str(v + 1), map))
	var foot: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	foot.custom_minimum_size.y = float(Tk.px(Tk.sz("row_h")))
	var fpad: Control = Control.new()
	fpad.custom_minimum_size.x = float(Tk.px(4.0))
	foot.add_child(fpad)
	var mark_btn: Button = PmButton.make("Mark", "marker")
	mark_btn.set("quiet", true)
	PmUI.tip(mark_btn, "Put a sync mark on the lane you clicked last, at the playhead (or where it is playing). Key: M. Mark the same moment on two lanes, then Line up")
	mark_btn.pressed.connect(func() -> void: mark())
	foot.add_child(mark_btn)
	var line_btn: Button = PmButton.make("Line up", "slip")
	line_btn.name = "LineUpButton"
	line_btn.set("quiet", true)
	PmUI.tip(line_btn, "Move each lane so its marks meet the first marked lane's marks. One pair sets the offset; several pairs key it so it eases from mark to mark. Key: L")
	line_btn.pressed.connect(func() -> void: line_up())
	foot.add_child(line_btn)
	var match_btn: Button = PmButton.make("Match by sound", "wave")
	match_btn.set("quiet", true)
	PmUI.tip(match_btn, "Listen for where the lane you clicked sounds most like the first lane, within two seconds either way of the playhead, and move it there")
	match_btn.pressed.connect(func() -> void: match_sound())
	foot.add_child(match_btn)
	_follow_btn = PmButton.make("Carry across cuts", "", true)
	_follow_btn.set("quiet", true)
	_follow_btn.set_pressed_no_signal(OffsetMarks.follows(entry()))
	PmUI.tip(_follow_btn, "Off: at a view cut a lined up offset snaps straight to that cut's marks. On: it carries on from the cut before and eases to them")
	_follow_btn.toggled.connect(set_follow)
	foot.add_child(_follow_btn)
	var clear_btn: Button = PmButton.make("Clear marks")
	clear_btn.set("quiet", true)
	clear_btn.pressed.connect(func() -> void: clear_marks())
	foot.add_child(clear_btn)
	_marks_note = PmLabel.dim("")
	foot.add_child(_marks_note)
	_hint = PmLabel.trim("", "text_faint")
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_hint)
	add_child(foot)
	_refresh()


func marks_text() -> String:
	var n: int = marks().size()
	if n == 0:
		return ""
	return str(n) + (" mark" if n == 1 else " marks")


func hint_text() -> String:
	if cut_only:
		return "Only this cut: a change lands on the cut the playhead is in and leaves the other cuts alone. Drag a wave sideways, Alt drag for 0.1 ms steps."
	if ViewMap.of(entry()).is_empty():
		return "This Pair View has no sound map yet, so its views move only the picture. Each lane shows the clip's linked sound at the view's offset."
	return "Drag a wave sideways to line it up, the offset follows. Alt drag for 0.1 ms steps."


func _lane_row(v: int, region: String, map: Dictionary) -> Control:
	var row: HBoxContainer = PmUI.hbox(0)
	row.name = "Lane" + str(v)
	row.custom_minimum_size.y = float(Tk.px(LANE_H))
	var head: VBoxContainer = PmUI.vbox(Tk.px(4.0))
	head.custom_minimum_size.x = float(Tk.px(HEAD_W))
	var top: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	var chip: ColorRect = ColorRect.new()
	chip.custom_minimum_size = Vector2(float(Tk.px(10.0)), float(Tk.px(10.0)))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.color = Tk.label_colour(ViewMap.colour_for(map, v))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lead: Control = Control.new()
	lead.custom_minimum_size.x = float(Tk.px(4.0))
	top.add_child(lead)
	top.add_child(chip)
	top.add_child(PmLabel.body(region))
	var heard: Label = PmLabel.trim("", "text_faint")
	heard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heard)
	_heads.append(heard)
	var solo: Button = PmButton.make("", "play", true)
	solo.set("quiet", true)
	PmUI.tip(solo, "Play " + region + "'s sound alone around the playhead")
	solo.pressed.connect(listen.bind(PackedInt32Array([v])))
	_listen_btns[v] = solo
	top.add_child(solo)
	head.add_child(top)
	var tools: HBoxContainer = PmUI.hbox(Tk.px(2.0))
	var lead2: Control = Control.new()
	lead2.custom_minimum_size.x = float(Tk.px(4.0))
	tools.add_child(lead2)
	var f: Control = PmField.make(0.0, -ViewMap.OFFSET_MAX * 1000.0, ViewMap.OFFSET_MAX * 1000.0, 0.1, " ms")
	f.name = "Offset"
	f.set("precision", 1)
	f.custom_minimum_size.x = float(Tk.px(84.0))
	PmUI.tip(f, "This region's offset at the playhead. Positive plays it later, negative earlier")
	f.connect("value_changed", _on_field.bind(v))
	fields.append(f)
	tools.add_child(f)
	for dv: float in NUDGES:
		var nb: Button = PmButton.make(("+" if dv > 0.0 else "-") + str(int(round(absf(dv) * 1000.0))))
		nb.set("quiet", true)
		PmUI.tip(nb, ("Later" if dv > 0.0 else "Earlier") + " by " + str(int(round(absf(dv) * 1000.0))) + " ms")
		nb.pressed.connect(func() -> void: nudge(v, dv))
		tools.add_child(nb)
	var zero: Button = PmButton.make("0")
	zero.set("quiet", true)
	PmUI.tip(zero, "Set this region's offset back to 0 (a keyed offset loses its keys). With Only this cut on, just this cut goes back to 0")
	zero.pressed.connect(func() -> void: reset(v))
	tools.add_child(zero)
	head.add_child(tools)
	var head_bg: PanelContainer = PmUI.panel("bg_panel_alt")
	head_bg.custom_minimum_size.x = float(Tk.px(HEAD_W))
	head_bg.add_child(head)
	row.add_child(head_bg)
	var lane: Control = _Lane.new()
	lane.name = "Wave"
	lane.set("editor", self)
	lane.set("view", v)
	lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane.focus_mode = Control.FOCUS_CLICK
	lane.clip_contents = true
	lanes.append(lane)
	row.add_child(lane)
	return row


func heard_text(v: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var d: Project = doc()
	for snd: Dictionary in sounds_of(v):
		var tr: Track = snd["track"]
		var label: String = tr.shown_label()
		if bool(snd["by_stream"]):
			label += " " + ViewStreams.name_of(d.media_by_id((snd["clip"] as Clip).media_id), int(snd["stream"]))
		if not parts.has(label):
			parts.append(label)
	if parts.is_empty():
		return "hears nothing"
	return "hears " + ", ".join(parts)


func sounds_of(v: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s: Sequence = sequence()
	var c: Clip = clip()
	var e: Dictionary = entry()
	if s == null or c == null or e.is_empty():
		return out
	var map: Dictionary = ViewMap.of(e)
	if map.is_empty():
		for tr: Track in s.sound_carriers():
			for a: Clip in tr.clips:
				if a != c and tr.is_sound(a) and ViewMap.in_family(c, a) and a.end() > c.start and a.start < c.end():
					out.append({"clip": a, "track": tr, "stream": ViewStreams.own(a), "by_stream": false})
		return out
	for snd: Dictionary in ViewMap.view_sounds(map, s, c, v):
		var tr2: Track = snd["track"]
		for a2: Clip in snd["clips"]:
			var st: int = ViewStreams.played(map, v, tr2.id, a2, c)
			if st >= 0:
				out.append({"clip": a2, "track": tr2, "stream": st, "by_stream": ViewStreams.applies(map, a2, c)})
	return out


func _times(t0: float, dt: float, n: int) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(maxi(n, 0))
	for x: int in n:
		out[x] = t0 + (float(x) + 0.5) * dt
	return out


func _sounds_cached(v: int) -> Array[Dictionary]:
	var key: String = str(v) + "|" + str(_gen)
	var got: Variant = _sound_cache.get(key, null)
	if got is Array:
		var typed: Array[Dictionary] = []
		typed.assign(got)
		return typed
	var list: Array[Dictionary] = sounds_of(v)
	if _sound_cache.size() > 64:
		_sound_cache.clear()
	_sound_cache[key] = list
	return list


func _compute(v: int, times_in: PackedFloat64Array) -> Dictionary:
	var n: int = times_in.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(maxi(n, 0))
	var c: Clip = clip()
	var e: Dictionary = entry()
	var d: Project = doc()
	if c == null or e.is_empty() or d == null or n <= 0:
		return {"amps": out, "complete": true}
	computed_columns += n
	var complete: bool = true
	var dt: float = absf(times_in[n - 1] - times_in[0]) / float(n - 1) if n > 1 else span / 400.0
	var fixed: bool = not keyed(v)
	var still: float = ViewMap.offset_at(e, v, c, centre() - c.start)
	for snd: Dictionary in _sounds_cached(v):
		var a: Clip = snd["clip"]
		var st: int = int(snd["stream"])
		var item: MediaItem = d.media_by_id(a.media_id)
		var h: int = StreamListen.handle_of(item)
		var times: PackedFloat64Array = PackedFloat64Array()
		times.resize(n)
		var lo: float = INF
		var hi: float = -INF
		for x: int in n:
			var t: float = times_in[x]
			if t < a.start or t >= a.end():
				times[x] = NAN
				continue
			var o: float = still if fixed else ViewMap.offset_at(e, v, c, t - c.start)
			var ft: float = a.source_time(t) - o
			if ft < 0.0:
				times[x] = NAN
				continue
			times[x] = ft
			lo = minf(lo, ft)
			hi = maxf(hi, ft)
		if lo > hi:
			continue
		var half: float = dt * absf(a.static_speed()) * 0.5
		var got: Dictionary = _read(h, st, lo - half, hi + half, 1.0 / maxf(dt, 0.000001))
		if got.is_empty():
			complete = false
			continue
		var bytes: PackedByteArray = got["bytes"]
		var rate: float = float(got["rate"])
		var first: int = int(got["first"])
		var count: int = bytes.size() / 2
		var gs: PackedFloat32Array = _sound_gains(a, snd.get("track", null), times_in)
		for x2: int in n:
			var ft2: float = times[x2]
			if is_nan(ft2):
				continue
			var b0: int = int(floor((ft2 - half) * rate)) - first
			var b1: int = maxi(b0 + 1, int(ceil((ft2 + half) * rate)) - first)
			var peak: int = 0
			for b: int in range(maxi(b0, 0), mini(b1, count)):
				var lo_b: int = bytes[b * 2]
				var hi_b: int = bytes[b * 2 + 1]
				if lo_b == 0 and hi_b == 0:
					continue
				peak = maxi(peak, maxi(128 - lo_b, hi_b - 128))
			var heard_amp: float = _amp(peak) if gs.is_empty() else minf(WaveVolume.scale_amp(_amp(peak), gs[x2], true, FLOOR_DB), 1.0)
			out[x2] = maxf(out[x2], heard_amp)
	return {"amps": out, "complete": complete}


func _sound_gains(a: Clip, tr: Variant, times_in: PackedFloat64Array) -> PackedFloat32Array:
	if not WaveLook.volume_on():
		return PackedFloat32Array()
	var env: Dictionary = WaveVolume.for_clip(doc(), sequence(), a, tr as Track if tr is Track else null)
	if env.is_empty() or bool(env["unity"]):
		return PackedFloat32Array()
	var locals: PackedFloat64Array = PackedFloat64Array()
	locals.resize(times_in.size())
	for i: int in times_in.size():
		locals[i] = times_in[i] - a.start
	return WaveVolume.gains(env, locals)


func _volume_sig(v: int) -> int:
	if not WaveLook.volume_on():
		return 0
	var parts: Array = []
	for snd: Dictionary in _sounds_cached(v):
		var a: Clip = snd["clip"]
		var tr: Variant = snd.get("track", null)
		var env: Dictionary = WaveVolume.for_clip(doc(), sequence(), a, tr as Track if tr is Track else null)
		if not env.is_empty() and not bool(env["unity"]):
			parts.append(a.start)
			parts.append(int(env["sig"]))
	return 0 if parts.is_empty() else hash(parts)


func _cache_sig(v: int, dt: float) -> String:
	var sig: String = str(_gen) + "|" + str(dt) + "|" + var_to_str(ViewMap.offset_prop(entry(), v)) + "|" + str(_volume_sig(v))
	if not keyed(v):
		var c: Clip = clip()
		sig += "|" + str(ViewMap.offset_at(entry(), v, c, centre() - c.start) if c != null else 0.0)
	return sig


func columns(v: int, n: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(maxi(n, 0))
	if n <= 0:
		return out
	var dt: float = span / float(n)
	var k0: int = int(floor(window_start() / dt + 0.5))
	var sig: String = _cache_sig(v, dt)
	var cache: Dictionary = _col_cache.get(v, {})
	if String(cache.get("sig", "")) != sig:
		cache = {"sig": sig, "amps": {}}
		_col_cache[v] = cache
	var known: Dictionary = cache["amps"]
	var missing: PackedInt32Array = PackedInt32Array()
	var times: PackedFloat64Array = PackedFloat64Array()
	for x: int in n:
		var k: int = k0 + x
		if known.has(k):
			out[x] = float(known[k])
		else:
			missing.append(x)
			times.append((float(k) + 0.5) * dt)
	if missing.is_empty():
		return out
	var got: Dictionary = _compute(v, times)
	var amps: PackedFloat32Array = got["amps"]
	var keep: bool = bool(got["complete"])
	if known.size() > n * 8:
		known.clear()
	for i: int in missing.size():
		out[missing[i]] = amps[i]
		if keep:
			known[k0 + missing[i]] = amps[i]
	return out


func _amp(peak: int) -> float:
	if peak <= 0:
		return 0.0
	var db: float = 20.0 * log(float(peak) / 127.0) / log(10.0)
	return clampf(1.0 - db / FLOOR_DB, 0.0, 1.0)


func _read(h: int, st: int, a: float, b: float, px_per_second: float) -> Dictionary:
	var lo: float = maxf(a, 0.0)
	var hi: float = maxf(b, lo)
	if peaks_provider.is_valid():
		if coverage_provider.is_valid() and not _chunks_ready(h, st, lo, hi):
			return {}
		var first_p: int = int(floor(lo * TIER_RATE))
		var count_p: int = int(ceil(hi * TIER_RATE)) - first_p + 1
		return {"bytes": peaks_provider.call(h, st, 0, first_p, count_p), "rate": TIER_RATE, "first": first_p}
	if h < 0 or not PurrBridge.available:
		return {}
	var fine: float = Waves.fine_rate_for(px_per_second)
	if fine > 0.0 and Waves.fine_available(h) and hi - lo <= Waves.FINE_MAX_SPAN:
		if Waves.fine_request(h, st, lo, hi) == Waves.FINE_READY:
			var first_f: int = int(floor(lo * fine))
			var count_f: int = mini(int(ceil(hi * fine)) - first_f + 1, 1 << 20)
			var bytes_f: PackedByteArray = Waves.fine_read(h, st, first_f, count_f, fine)
			if not bytes_f.is_empty():
				return {"bytes": bytes_f, "rate": fine, "first": first_f}
		else:
			Waves.listen_fine(lanes[0] if not lanes.is_empty() else self)
	if not _chunks_ready(h, st, lo, hi):
		return {}
	var first: int = int(floor(lo * TIER_RATE))
	var count: int = mini(int(ceil(hi * TIER_RATE)) - first + 1, 65536)
	return {"bytes": PurrBridge.peaks_read(h, st, 0, first, count), "rate": TIER_RATE, "first": first}


func key_times(v: int) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var c: Clip = clip()
	if c == null:
		return out
	for k: Dictionary in AnimProp.keys(ViewMap.offset_prop(entry(), v)):
		out.append(c.start + float(k.get("t", 0.0)))
	return out


func _refresh() -> void:
	if _signature() != _sig:
		_build()
		return
	var c: Clip = clip()
	var s: Sequence = sequence()
	if _around != null:
		_around.text = Timecode.format(Session.playhead(), s.fps if s != null else 30.0)
	if _cut_note != null and is_instance_valid(_cut_note):
		var note: String = cut_text()
		_cut_note.text = note
		_cut_note.visible = cut_only and not note.is_empty()
	if _marks_note != null and is_instance_valid(_marks_note):
		_marks_note.text = marks_text()
	if _follow_btn != null and is_instance_valid(_follow_btn):
		_follow_btn.set_pressed_no_signal(OffsetMarks.follows(entry()))
	if _hint != null and is_instance_valid(_hint):
		var hint: String = hint_text()
		_hint.text = hint
		PmUI.tip(_hint, hint)
	for v: int in fields.size():
		var f: Control = fields[v]
		if not bool(f.get("_dragging")) and not (f.get("_editor") != null):
			f.set("value", offset_now(v) * 1000.0)
		if v < _heads.size():
			var keyed_text: String = ", keyed: a change moves this cut's keys" if cut_only else ", keyed: a change moves every key"
			var text: String = heard_text(v) + (keyed_text if keyed(v) else "")
			if c != null and (Session.playhead() < c.start or Session.playhead() >= c.end()):
				text = "Move the playhead over this clip"
			_heads[v].text = text
			PmUI.tip(_heads[v], text)
	_sync_listen()
	_redraw_all()


func _bump() -> void:
	_gen += 1
	_col_cache.clear()
	_sound_cache.clear()


func _redraw_all() -> void:
	draws += 1
	for l: Control in lanes:
		if is_instance_valid(l):
			l.queue_redraw()
	if _ruler != null and is_instance_valid(_ruler):
		_ruler.queue_redraw()


func _on_playhead(_t: float) -> void:
	if playing:
		return
	_refresh()


func _on_project() -> void:
	_bump()
	_watch_doc()
	if clip() == null:
		_close()
		return
	_build()


func _on_doc_changed(_kind: String) -> void:
	if not is_inside_tree():
		return
	if clip() == null or entry().is_empty():
		_close()
		return
	_bump()
	_refresh()


func _close() -> void:
	var w: Node = get_parent()
	while w != null and not w.has_method("close"):
		w = w.get_parent()
	if w != null:
		w.call("close")


func _on_done() -> void:
	_close()


func _on_sync_timeline() -> void:
	var sync: GDScript = load("res://modules/core_panels/pair_sync.gd")
	sync.call("toggle", clip_id, uid)


func _sync_listen() -> void:
	var st: RefCounted = StreamListen.instance()
	if playing and not bool(st.call("on_views", clip_id, play_views)):
		playing = false
		set_process(false)
	if _together != null and is_instance_valid(_together):
		_together.set_pressed_no_signal(together)
	if _play_btn != null and is_instance_valid(_play_btn):
		_play_btn.set_pressed_no_signal(playing)
		_play_btn.text = "Stop" if playing else "Play"
	for v: Variant in _listen_btns.keys():
		var b: Button = _listen_btns[v]
		if is_instance_valid(b):
			b.set_pressed_no_signal(bool(st.call("on_views", clip_id, PackedInt32Array([int(v)]))))


func listen(views: PackedInt32Array) -> bool:
	var st: RefCounted = StreamListen.instance()
	if playing:
		stop_play(false)
	if bool(st.call("on_views", clip_id, views)):
		st.call("stop")
		_sync_listen()
		return false
	var c: Clip = clip()
	if c == null:
		return false
	var ok: bool = bool(st.call("play_views", doc(), sequence(), c, uid, views, Session.playhead() - LISTEN_SECONDS * 0.5, LISTEN_SECONDS))
	if not ok:
		Events.toast("The sound engine is not available, so nothing can be played")
	_sync_listen()
	return ok


func _write(v: int, next: Dictionary, label: String) -> bool:
	var d: Project = doc()
	if d == null or clip() == null:
		return false
	var cmds: Array[Command] = [ClipCmds.SetClipParam.new(seq_id, clip_id, offset_path(v), next)]
	return Verbs.run(d, label, cmds)


func _plus(v: int, from: Dictionary, delta: float) -> Dictionary:
	if not cut_only:
		return ViewMap.offset_plus(from, delta)
	return ViewOffsets.cut_plus(entry(), clip(), v, cut_now(), delta, from)


func local_now() -> float:
	var c: Clip = clip()
	return 0.0 if c == null else clampf(Session.playhead() - c.start, 0.0, maxf(c.duration, 0.0))


func nudge(v: int, delta: float) -> bool:
	var e: Dictionary = entry()
	if e.is_empty():
		return false
	var label: String = "Nudge this cut" if cut_only else "Nudge offset"
	return _write(v, _plus(v, ViewMap.offset_prop(e, v), delta), label)


func set_offset_to(v: int, seconds: float) -> bool:
	var e: Dictionary = entry()
	if e.is_empty():
		return false
	var delta: float = ViewMap.clamp_offset(seconds) - offset_now(v)
	if absf(delta) < EPS:
		return false
	if cut_only:
		return _write(v, ViewOffsets.cut_set(e, clip(), v, cut_now(), seconds, local_now()), "Offset this cut")
	return _write(v, ViewMap.offset_plus(ViewMap.offset_prop(e, v), delta), "Offset")


func reset(v: int) -> bool:
	var e: Dictionary = entry()
	if e.is_empty():
		return false
	if cut_only:
		var now: float = offset_now(v)
		if absf(now) < EPS:
			return false
		return _write(v, _plus(v, ViewMap.offset_prop(e, v), -now), "This cut back to 0")
	if not keyed(v) and absf(offset_now(v)) < EPS:
		return false
	return _write(v, AnimProp.make(0.0), "Offset to 0")


func _on_field(ms: float, v: int) -> void:
	set_offset_to(v, ms / 1000.0)


func px_per_second(v: int) -> float:
	if v < 0 or v >= lanes.size() or not is_instance_valid(lanes[v]):
		return 100.0
	return maxf(lanes[v].size.x, 1.0) / maxf(span, 0.0001)


func begin_drag(v: int, x: float) -> void:
	var e: Dictionary = entry()
	if e.is_empty():
		return
	drag = {"view": v, "x0": x, "prop0": ViewMap.offset_prop(e, v).duplicate(true), "delta": 0.0, "sound": not ViewMap.of(e).is_empty(), "cut": cut_now() if cut_only else {}}


func drag_to(x: float, fine: bool = false) -> void:
	var d: Project = doc()
	if d == null or drag.is_empty() or clip() == null:
		return
	var v: int = int(drag["view"])
	var snap: float = DRAG_FINE if fine else DRAG_SNAP
	var delta: float = snappedf((x - float(drag["x0"])) / px_per_second(v) * speed_abs(), snap)
	if is_equal_approx(delta, float(drag["delta"])) and d.undo.has_live():
		return
	drag["delta"] = delta
	var cut: Dictionary = drag["cut"]
	var next: Dictionary = ViewOffsets.cut_plus(entry(), clip(), v, cut, delta, drag["prop0"]) if not cut.is_empty() else ViewMap.offset_plus(drag["prop0"], delta)
	d.undo.live(PairCmds.SetOffset.new(seq_id, clip_id, offset_path(v), next, bool(drag["sound"])))
	_refresh()


func end_drag() -> void:
	var d: Project = doc()
	var delta: float = float(drag.get("delta", 0.0))
	drag = {}
	if d == null or not d.undo.has_live():
		return
	if absf(delta) < EPS:
		d.undo.cancel_live()
	else:
		d.undo.commit_live("Offset")
	_refresh()


func cancel_drag() -> void:
	var was: bool = not drag.is_empty()
	drag = {}
	var d: Project = doc()
	if was and d != null and d.undo.has_live():
		d.undo.cancel_live()
	_refresh()


func zoom(factor: float) -> void:
	_zoom_ms = Time.get_ticks_msec()
	set_span(span * factor)
	if not _settle_armed and is_inside_tree():
		_settle_armed = true
		get_tree().create_timer(float(ZOOM_SETTLE_MS) / 1000.0 + 0.02).timeout.connect(_settle)


func _settle() -> void:
	_settle_armed = false
	if not is_inside_tree():
		return
	if zooming():
		_settle_armed = true
		get_tree().create_timer(float(ZOOM_SETTLE_MS) / 1000.0).timeout.connect(_settle)
		return
	_redraw_all()


func zooming() -> bool:
	return Time.get_ticks_msec() - _zoom_ms < ZOOM_SETTLE_MS


func _quick_columns(v: int, n: int) -> PackedFloat32Array:
	var last: Dictionary = _last_drawn.get(v, {})
	if last.is_empty() or n <= 0:
		return PackedFloat32Array()
	var old: PackedFloat32Array = last["amps"]
	var ot0: float = float(last["t0"])
	var odt: float = float(last["dt"])
	var m: int = old.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	if m <= 0 or odt <= 0.0:
		return out
	var t0: float = window_start()
	var dt: float = span / float(n)
	for x: int in n:
		var a: float = (t0 + float(x) * dt - ot0) / odt
		var b: float = (t0 + float(x + 1) * dt - ot0) / odt
		if b < 0.0 or a >= float(m):
			continue
		var i0: int = clampi(int(floor(a)), 0, m - 1)
		var i1: int = clampi(int(ceil(b)), i0 + 1, m)
		var best: float = 0.0
		for i: int in range(i0, i1):
			best = maxf(best, old[i])
		out[x] = best
	return out


func draw_lane(ci: Control, v: int) -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, ci.size)
	ci.draw_rect(r, Tk.c["bg_lane_audio"], true)
	var c: Clip = clip()
	var map: Dictionary = ViewMap.of(entry())
	var col: Color = Tk.label_colour(ViewMap.colour_for(map, v))
	var mid: float = r.size.y * 0.5
	var half: float = r.size.y * 0.5 - 4.0
	ci.draw_line(Vector2(0.0, mid), Vector2(r.size.x, mid), Tk.c["wave_line"], 1.0)
	var n: int = int(r.size.x)
	if c != null and n > 0:
		var t0: float = window_start()
		var pps: float = r.size.x / maxf(span, 0.0001)
		var x_in: float = (c.start - t0) * pps
		var x_out: float = (c.end() - t0) * pps
		var amps: PackedFloat32Array = _quick_columns(v, n) if zooming() and _last_drawn.has(v) else PackedFloat32Array()
		if amps.is_empty():
			amps = columns(v, n)
			_last_drawn[v] = {"amps": amps, "t0": t0, "dt": span / float(n)}
		WaveLook.draw_amp_columns(ci, amps, mid, half, col, WaveLook.scale(true, 1.0, FLOOR_DB))
		if x_in > 0.0:
			ci.draw_rect(Rect2(0.0, 0.0, minf(x_in, r.size.x), r.size.y), Tk.c["veil"], true)
		if x_out < r.size.x:
			ci.draw_rect(Rect2(maxf(x_out, 0.0), 0.0, r.size.x - maxf(x_out, 0.0), r.size.y), Tk.c["veil"], true)
		for m: Dictionary in OffsetMarks.of_view(marks(), v):
			var mx: float = (OffsetMarks.shown_at(m, entry(), c, speed_abs()) - t0) * pps
			if mx < 0.0 or mx > r.size.x:
				continue
			ci.draw_rect(Rect2(mx - 0.5, 0.0, 2.0, r.size.y), Tk.c["accent"], true)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(mx - 5.0, r.size.y), Vector2(mx + 5.0, r.size.y), Vector2(mx, r.size.y - 7.0)]), Tk.c["accent"])
		for kt: float in key_times(v):
			var kx: float = (kt - t0) * pps
			if kx < 0.0 or kx > r.size.x:
				continue
			var dm: PackedVector2Array = PackedVector2Array([Vector2(kx, 2.0), Vector2(kx + 4.0, 6.0), Vector2(kx, 10.0), Vector2(kx - 4.0, 6.0)])
			ci.draw_colored_polygon(dm, Tk.c["text_bright"])
	var px: float = floor(r.size.x * 0.5)
	ci.draw_rect(Rect2(px, 0.0, 1.0, r.size.y), Tk.c["sol"], true)
	ci.draw_rect(Rect2(0.0, r.size.y - 1.0, r.size.x, 1.0), Tk.c["lane_line"], true)
	if not drag.is_empty() and int(drag["view"]) == v:
		ci.draw_rect(r, col, false, 1.0)
	elif v == focus_view and region_count() > 1:
		ci.draw_rect(Rect2(0.0, 0.0, 3.0, r.size.y), col, true)


func draw_ruler(ci: Control) -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, ci.size)
	ci.draw_rect(r, Tk.c["bg_ruler"], true)
	ci.draw_rect(Rect2(0.0, r.size.y - 1.0, r.size.x, 1.0), Tk.c["border"], true)
	var font: Font = Tk.font("mono")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var step: float = 0.1 if span <= 1.5 else (0.5 if span <= 5.0 else 1.0)
	var pps: float = r.size.x / maxf(span, 0.0001)
	var k: float = -floor(span * 0.5 / step) * step
	var guard: int = 0
	while k <= span * 0.5 + 0.00001 and guard < 400:
		guard += 1
		var x: float = r.size.x * 0.5 + k * pps
		ci.draw_rect(Rect2(x, r.size.y * 0.55, 1.0, r.size.y * 0.45), Tk.c["text_faint"], true)
		var label: String = "0" if absf(k) < 0.00001 else (("+" if k > 0.0 else "-") + String.num(absf(k), 1) + " s")
		if font != null and x + 4.0 < r.size.x - 20.0:
			PmText.draw(ci, font, Rect2(x, 0.0, minf(step * pps, r.size.x - x), r.size.y * 0.6), label, fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, 3.0, NAN, PmText.WHOLE)
		k += step


func handle_key(k: InputEventKey) -> bool:
	if not k.pressed or k.echo or k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return false
	if k.keycode == KEY_SPACE:
		toggle_play()
		return true
	if k.keycode == KEY_M:
		mark()
		return true
	if k.keycode == KEY_L:
		line_up()
		return true
	return false


func _on_input(event: InputEvent) -> void:
	if event is InputEventKey and handle_key(event as InputEventKey):
		accept_event()


func ruler_click(x: float, width: float) -> void:
	var t: float = window_start() + x / maxf(width, 1.0) * span
	Session.set_playhead(maxf(t, 0.0))


class _Lane:
	extends Control

	var editor: Control = null
	var view: int = 0
	var _press: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_HSPLIT
		gui_input.connect(_on_input)

	func _draw() -> void:
		if editor != null and is_instance_valid(editor):
			editor.call("draw_lane", self, view)

	func _on_input(event: InputEvent) -> void:
		if editor == null:
			return
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				editor.call("zoom", 0.8)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				editor.call("zoom", 1.25)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					grab_focus()
					editor.set("focus_view", view)
					editor.call("_redraw_all")
					_press = {"x": mb.position.x}
				else:
					_press = {}
					if not (editor.get("drag") as Dictionary).is_empty():
						editor.call("end_drag")
				accept_event()
		elif event is InputEventMouseMotion:
			var mm: InputEventMouseMotion = event
			if not _press.is_empty() and (editor.get("drag") as Dictionary).is_empty():
				if absf(mm.position.x - float(_press["x"])) >= DRAG_START_PX:
					editor.call("begin_drag", view, float(_press["x"]))
			if not (editor.get("drag") as Dictionary).is_empty():
				editor.call("drag_to", mm.position.x, mm.alt_pressed)
				accept_event()
		elif event is InputEventKey:
			var k: InputEventKey = event
			if k.pressed and k.keycode == KEY_ESCAPE and not (editor.get("drag") as Dictionary).is_empty():
				_press = {}
				editor.call("cancel_drag")
				accept_event()
			elif bool(editor.call("handle_key", k)):
				accept_event()


class _Ruler:
	extends Control

	var editor: Control = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)

	func _draw() -> void:
		if editor != null and is_instance_valid(editor):
			editor.call("draw_ruler", self)

	func _on_input(event: InputEvent) -> void:
		if editor == null:
			return
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			editor.call("ruler_click", (event as InputEventMouseButton).position.x, size.x)
			accept_event()

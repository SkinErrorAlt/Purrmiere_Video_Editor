extends "res://modules/core_panels/panel_base.gd"

const AudioOps := preload("res://modules/core_panels/audio_ops.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const Waves := preload("res://ui/timeline/timeline_wave.gd")
const RULER_H := 18.0
const MIN_SPAN := 0.02
const PREF_LOG := "audio_editor.log_wave"

var clip_id: String = ""
var sel_a: float = -1.0
var sel_b: float = -1.0
var t0: float = 0.0
var t1: float = 10.0
var noise_floor: float = NAN
var _head: Label = null
var _wave: Control = null
var _edits_box: VBoxContainer = null
var _status: Label = null
var _progress: ProgressBar = null
var _sel_label: Label = null
var _filters: PackedStringArray = PackedStringArray()
var _filters_asked: bool = false
var _pending_output: String = ""
var _pending_job: int = -1
var _pending_op: Dictionary = {}
var _stats_tag: String = ""
var _wave_cache: Dictionary = {}
var _fit_pending: bool = true
var _built_stamp: String = ""
var peaks_provider: Callable = Callable()
var coverage_provider: Callable = Callable()


func _build(root_: Control) -> void:
	if not Prefs.is_registered(PREF_LOG):
		Prefs.register(PREF_LOG, true, {"label": "Audio editor draws the waveform on a log scale", "type": "bool"})
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_head = PmLabel.trim("No audio clip selected", "text_bright")
	head.add_child(_head)
	var fx: Button = PmButton.make("Effects", "fx")
	fx.set("quiet", true)
	fx.pressed.connect(_on_effects.bind(fx))
	head.add_child(fx)
	var cut: Button = PmButton.make("Cut", "razor")
	cut.set("quiet", true)
	cut.pressed.connect(_on_cut_menu.bind(cut))
	head.add_child(cut)
	var profile: Button = PmButton.make("Noise profile", "audio")
	profile.set("quiet", true)
	PmUI.tip(profile, "Select a piece of pure noise, then press this. Noise reduction uses it.")
	profile.pressed.connect(_on_noise_profile)
	head.add_child(profile)
	var play: Button = quiet_icon("play", "Play the selection", Cmd.keys_text("play.toggle"))
	play.pressed.connect(_on_play_selection)
	head.add_child(play)
	var fit: Button = quiet_icon("maximize", "Fit the clip")
	fit.pressed.connect(_fit_clip)
	head.add_child(fit)
	var zin: Button = quiet_icon("plus", "Zoom in")
	zin.pressed.connect(_zoom.bind(0.5))
	head.add_child(zin)
	var zout: Button = quiet_icon("minus", "Zoom out")
	zout.pressed.connect(_zoom.bind(2.0))
	head.add_child(zout)
	head.add_child(PmUI.spacer())
	_sel_label = PmLabel.mono("", "text_dim")
	head.add_child(_sel_label)
	_wave = _Wave.new()
	_wave.panel = self
	_wave.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wave.custom_minimum_size = Vector2(0.0, float(Tk.px(120.0)))
	col.add_child(_wave)
	var foot: HBoxContainer = header_row(col)
	_status = PmLabel.trim("Select an audio clip on the timeline to edit its sound.", "text_dim")
	_status.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_small")))
	foot.add_child(_status)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(float(Tk.px(140.0)), float(Tk.px(8.0)))
	_progress.show_percentage = false
	_progress.visible = false
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_progress)
	var scroll: ScrollContainer = vscroll_area(col)
	scroll.custom_minimum_size = Vector2(0.0, float(Tk.px(70.0)))
	scroll.size_flags_vertical = Control.SIZE_FILL
	_edits_box = PmUI.vbox(0)
	_edits_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_edits_box)
	if PurrBridge.available:
		if not PurrBridge.audio_edit_done.is_connected(_on_edit_done):
			PurrBridge.audio_edit_done.connect(_on_edit_done)
		if not PurrBridge.audio_stats_ready.is_connected(_on_stats):
			PurrBridge.audio_stats_ready.connect(_on_stats)
		if not PurrBridge.job_progress.is_connected(_on_job_progress):
			PurrBridge.job_progress.connect(_on_job_progress)
	refresh()


func _on_doc_changed(kind: String) -> void:
	_heard_live(kind)
	if kind == "selection" or kind == "structure" or kind == "meta" or kind == "media":
		refresh()


func _on_history() -> void:
	refresh()


func _on_project_changed() -> void:
	clip_id = ""
	sel_a = -1.0
	sel_b = -1.0
	_wave_cache.clear()
	refresh()


func _on_sequence_changed(_id: String) -> void:
	refresh()


func _on_playhead(_t: float) -> void:
	if _wave != null:
		_wave.queue_redraw()


func target() -> Clip:
	var s: Sequence = seq()
	var d: Project = doc()
	if s == null or d == null:
		return null
	if not clip_id.is_empty():
		var kept: Clip = s.clip_by_id(clip_id)
		if kept != null and s.selected_clip_ids.has(clip_id):
			return kept
	for id: String in Verbs.selection(s):
		var c: Clip = s.clip_by_id(id)
		if c == null:
			continue
		var t: Track = s.track_of(c.id)
		if t != null and t.is_sound(c):
			return c
	for id: String in Verbs.selection(s):
		var c2: Clip = s.clip_by_id(id)
		if c2 == null:
			continue
		for other: Clip in s.linked(c2):
			var ot: Track = s.track_of(other.id)
			if ot != null and ot.is_sound(other):
				return other
	if not clip_id.is_empty():
		return s.clip_by_id(clip_id)
	return null


func media_of(c: Clip) -> MediaItem:
	var d: Project = doc()
	if d == null or c == null:
		return null
	return d.media_by_id(c.media_id)


func source_stream(c: Clip) -> int:
	return int(c.audio.get("stream", 0.0)) if c != null else 0


func render_path(c: Clip) -> String:
	if c == null:
		return ""
	return str(c.audio.get("render", ""))


func edits_of(c: Clip) -> Array:
	if c == null:
		return []
	var raw: Variant = c.audio.get("edits", [])
	return raw if raw is Array else []


func stream_rate(c: Clip) -> int:
	var m: MediaItem = media_of(c)
	if m == null:
		return 48000
	var si: int = source_stream(c)
	if si >= 0 and si < m.audio_streams.size():
		return int(m.audio_streams[si].get("sample_rate", 48000))
	return 48000


func wave_handle(c: Clip) -> Array:
	var rp: String = render_path(c)
	if not rp.is_empty() and FileAccess.file_exists(rp):
		var rh: int = Session.render_handle(rp)
		if rh >= 0:
			return [rh, 0]
	var m: MediaItem = media_of(c)
	return [media_handle(m), source_stream(c)]


func stream_length(c: Clip) -> float:
	var m: MediaItem = media_of(c)
	var rp: String = render_path(c)
	if not rp.is_empty() and PurrBridge.available:
		var rh: int = Session.render_handle(rp)
		if rh >= 0:
			var info: Dictionary = PurrBridge.media_info(rh)
			var d: float = float(info.get("duration", 0.0))
			if d > 0.0:
				return d
	if m != null and m.duration > 0.0:
		return m.duration
	return maxf(c.source_out(), 1.0) if c != null else 1.0


func clip_window(c: Clip) -> Vector2:
	var w: PackedFloat64Array = clip_span(c)
	return Vector2(w[0], w[1])


func clip_span(c: Clip) -> PackedFloat64Array:
	if c == null:
		return PackedFloat64Array([0.0, 0.0])
	var a: float = c.source_time_exact(c.start)
	var b: float = c.source_time_exact(c.end())
	return PackedFloat64Array([minf(a, b), maxf(a, b)])


func heard_plan(c: Clip) -> Dictionary:
	if c == null:
		return {}
	return Waves.heard_plan(doc(), seq(), c)


func heard_spans(c: Clip) -> Array:
	var plan: Dictionary = heard_plan(c)
	return plan["spans"] if not plan.is_empty() else []


func heard_window(c: Clip) -> Vector2:
	var w: PackedFloat64Array = heard_span(c)
	return Vector2(w[0], w[1])


func heard_span(c: Clip) -> PackedFloat64Array:
	var plan: Dictionary = heard_plan(c)
	if plan.is_empty():
		return clip_span(c)
	var w: PackedFloat64Array = Waves.heard_bounds(plan["spans"])
	if is_nan(w[0]):
		var at: float = clip_span(c)[0]
		return PackedFloat64Array([at, at])
	return w


func _heard_live(kind: String) -> void:
	if not kind.begins_with("live") or _wave == null or not _alive():
		return
	var d: Project = doc()
	if d != null and Waves.heard_moved(d, seq(), d.undo.live_commands()):
		_wave_cache.clear()
		_wave.queue_redraw()


func has_selection() -> bool:
	return sel_a >= 0.0 and sel_b > sel_a + 0.0005


func edit_range(c: Clip) -> Vector2:
	var w: PackedFloat64Array = edit_span(c)
	return Vector2(w[0], w[1])


func edit_span(c: Clip) -> PackedFloat64Array:
	if has_selection():
		return PackedFloat64Array([sel_a, sel_b])
	return clip_span(c)


func set_selection(a: float, b: float) -> void:
	sel_a = minf(a, b)
	sel_b = maxf(a, b)
	_refresh_labels()
	if _wave != null:
		_wave.queue_redraw()


func clear_selection() -> void:
	sel_a = -1.0
	sel_b = -1.0
	_refresh_labels()
	if _wave != null:
		_wave.queue_redraw()


func timeline_time(c: Clip, src_t: float) -> float:
	if c == null:
		return 0.0
	var heard: float = Waves.heard_time_of(heard_spans(c), src_t)
	if not is_nan(heard):
		return heard
	var sp: float = c.static_speed()
	if absf(sp) < 0.0001:
		sp = 1.0
	return c.start + (src_t - c.in_offset) / sp


func source_of_timeline(c: Clip, t: float) -> float:
	if c == null:
		return 0.0
	var spans: Array = heard_spans(c)
	if not spans.is_empty():
		return Waves.heard_source_at(spans, t)
	return c.source_time(t)


func _stamp(c: Clip) -> String:
	if c == null:
		return ""
	return c.id + "|" + str(edits_of(c).size()) + "|" + render_path(c) + "|" + String.num(c.in_offset, 4) + "|" + String.num(c.duration, 4)


func live_prefs() -> PackedStringArray:
	return PackedStringArray(["audio_editor."])


func refresh() -> void:
	if not _alive():
		return
	var c: Clip = target()
	var stamp: String = _stamp(c)
	_show_hint(c)
	if c == null:
		clip_id = ""
		_head.text = "No audio clip selected"
		_built_stamp = ""
		PmUI.clear(_edits_box)
		_refresh_labels()
		_wave.queue_redraw()
		return
	if c.id != clip_id:
		load("res://modules/core_panels/panel_place.gd").call("wave_leave", self)
		clip_id = c.id
		sel_a = -1.0
		sel_b = -1.0
		_fit_pending = true
		_wave_cache.clear()
		load("res://modules/core_panels/panel_place.gd").call("wave_turn", self, c)
	if stamp != _built_stamp:
		_built_stamp = stamp
		_wave_cache.clear()
		_rebuild_edits(c)
	var m: MediaItem = media_of(c)
	var label: String = c.label if not c.label.is_empty() else (m.label if m != null else c.id)
	var n: int = edits_of(c).size()
	_head.text = label + ("" if n == 0 else "  (" + str(n) + (" edit" if n == 1 else " edits") + ")")
	_refresh_labels()
	_wave.queue_redraw()


func status_hint(c: Clip) -> String:
	if c == null:
		return "Select an audio clip on the timeline to edit its sound."
	var state: String = wave_state(c)
	if state == "missing":
		return "This clip's file is missing. Use File, Relink missing media to find it, then edit its sound here."
	if state == "no_engine":
		return "Audio editing needs the engine, which did not load."
	return "Drag on the wave to select a piece, then pick an effect or a cut."


func _show_hint(c: Clip) -> void:
	if _status == null or _pending_job >= 0 or not _stats_tag.is_empty():
		return
	_status.text = status_hint(c)


func _refresh_labels() -> void:
	if _sel_label == null:
		return
	if has_selection():
		_sel_label.text = _secs(sel_a) + " to " + _secs(sel_b) + "  (" + _secs(sel_b - sel_a) + ")"
	else:
		_sel_label.text = ""


func _secs(t: float) -> String:
	if t >= 60.0:
		return "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]
	return "%.2fs" % t


func _rebuild_edits(c: Clip) -> void:
	PmUI.clear(_edits_box)
	var edits: Array = edits_of(c)
	if edits.is_empty():
		_edits_box.add_child(PmLabel.dim("No edits on this clip. Edits never touch the original file."))
		return
	for i: int in edits.size():
		var e: Dictionary = edits[i]
		var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
		row.add_child(PmLabel.mono(str(i + 1) + ".", "text_faint"))
		var text: String = AudioOps.describe(e)
		var a: float = float(e.get("from", 0.0))
		var b: float = float(e.get("to", -1.0))
		if b >= 0.0:
			text += "   " + _secs(a) + " to " + _secs(b)
		var lbl: Label = PmLabel.trim(text)
		row.add_child(lbl)
		if i == edits.size() - 1:
			var rm: Button = quiet_icon("trash", "Remove this edit")
			rm.pressed.connect(_remove_last)
			row.add_child(rm)
		_edits_box.add_child(row)
	var tail: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	tail.add_child(PmUI.spacer())
	var clear: Button = PmButton.make("Remove every edit")
	clear.set("quiet", true)
	clear.pressed.connect(_clear_edits)
	tail.add_child(clear)
	_edits_box.add_child(tail)


func filters() -> PackedStringArray:
	if not _filters_asked and PurrBridge.available and PurrBridge.has_method("audio_filters"):
		_filters_asked = true
		_filters = PurrBridge.audio_filters()
	return _filters


func _on_effects(anchor: Control) -> void:
	var c: Clip = target()
	if c == null:
		Events.toast("Select an audio clip first")
		return
	var items: Array = []
	var f: PackedStringArray = filters()
	for g: Dictionary in AudioOps.GROUPS:
		if String(g["id"]) == "edit":
			continue
		var subs: Array = []
		for o: Dictionary in AudioOps.OPS:
			if String(o["group"]) != String(g["id"]):
				continue
			var it: Dictionary = PmMenu.item("op:" + String(o["id"]), String(o["label"]))
			if not AudioOps.available(o, f):
				it["disabled"] = true
			subs.append(it)
		items.append(PmMenu.sub_item("group:" + String(g["id"]), String(g["label"]), subs))
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_op_picked)


func _on_cut_menu(anchor: Control) -> void:
	var items: Array = [
		PmMenu.item("op:delete", "Delete the selection", "Del"),
		PmMenu.item("op:keep", "Trim to the selection"),
		PmMenu.item("op:silence", "Silence the selection"),
		PmMenu.separator(),
		PmMenu.item("select_clip", "Select the part on the timeline", "Ctrl+A"),
		PmMenu.item("select_none", "Clear the selection", "Esc"),
	]
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_op_picked)


func _on_op_picked(id: String) -> void:
	if id == "select_clip":
		var c0: Clip = target()
		if c0 != null:
			var w: PackedFloat64Array = clip_span(c0)
			set_selection(w[0], w[1])
		return
	if id == "select_none":
		clear_selection()
		return
	if not id.begins_with("op:"):
		return
	begin_op(id.substr(3))


func begin_op(op_id: String) -> void:
	var c: Clip = target()
	var o: Dictionary = AudioOps.op(op_id)
	if c == null or o.is_empty():
		return
	if bool(o.get("needs_selection", false)) and not has_selection():
		Events.toast("Select a piece of the wave first")
		return
	var fields: Array[Dictionary] = []
	for fv: Variant in o.get("fields", []):
		var fd: Dictionary = (fv as Dictionary).duplicate(true)
		if op_id == "noise_reduction" and String(fd.get("key", "")) == "floor" and not is_nan(noise_floor):
			fd["default"] = noise_floor
		fields.append(fd)
	if fields.is_empty():
		apply_op(op_id, {})
		return
	var answered: Signal = PmUI.form(_root, String(o["label"]), fields, "Apply", "Cancel")
	answered.connect(_on_form_answered.bind(op_id))


func _on_form_answered(result: Variant, op_id: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	apply_op(op_id, result)


func apply_op(op_id: String, params: Dictionary) -> void:
	var c: Clip = target()
	var o: Dictionary = AudioOps.op(op_id)
	if c == null or o.is_empty():
		return
	if not PurrBridge.available or not PurrBridge.has_method("audio_edit"):
		Events.warn("Audio editing needs the engine", "Rebuild purrcore with native\\purrcore\\build.bat")
		return
	if String(o.get("measure", "")) == "peak":
		var m: MediaItem = media_of(c)
		var input: String = render_path(c) if not render_path(c).is_empty() and FileAccess.file_exists(render_path(c)) else (m.path if m != null else "")
		var stream: int = 0 if input == render_path(c) else source_stream(c)
		var rng: PackedFloat64Array = edit_span(c)
		_stats_tag = "normalize:" + str(Time.get_ticks_msec())
		_pending_op = {"op": op_id, "params": params, "clip": c.id}
		PurrBridge.audio_stats({"input": input, "stream": stream, "from": rng[0], "to": rng[1], "tag": _stats_tag})
		_status.text = "Measuring the selection"
		return
	_commit_edit(c, op_id, params)


func _on_stats(result: Dictionary) -> void:
	if String(result.get("tag", "")) != _stats_tag:
		return
	_stats_tag = ""
	if _pending_op.is_empty():
		if not bool(result.get("ok", false)):
			return
		noise_floor = clampf(float(result.get("rms_db", -50.0)) + 6.0, -80.0, -20.0)
		_status.text = "Noise profile taken, floor " + String.num(noise_floor, 1) + " dB. Now select what to clean and use Noise reduction."
		return
	var pend: Dictionary = _pending_op
	_pending_op = {}
	var c: Clip = target()
	if c == null or c.id != String(pend.get("clip", "")):
		return
	var params: Dictionary = pend.get("params", {})
	var peak_db: float = float(result.get("peak_db", 0.0))
	params["gain"] = float(params.get("target", -1.0)) - peak_db
	_commit_edit(c, String(pend.get("op", "")), params)


func _on_noise_profile() -> void:
	var c: Clip = target()
	if c == null or not has_selection():
		Events.toast("Select a stretch of pure noise first")
		return
	if not PurrBridge.available:
		return
	var m: MediaItem = media_of(c)
	var input: String = render_path(c) if not render_path(c).is_empty() and FileAccess.file_exists(render_path(c)) else (m.path if m != null else "")
	var stream: int = 0 if input == render_path(c) else source_stream(c)
	_stats_tag = "noise:" + str(Time.get_ticks_msec())
	_pending_op = {}
	PurrBridge.audio_stats({"input": input, "stream": stream, "from": sel_a, "to": sel_b, "tag": _stats_tag})
	_status.text = "Measuring the noise"


func render_root() -> String:
	return Prefs.cache_dir().path_join("audio_edits")


func render_key(m: MediaItem, stream: int, edits: Array) -> String:
	var text: String = (m.path if m != null else "") + "|" + str(stream) + "|" + JSON.stringify(edits)
	return text.md5_text()


func _commit_edit(c: Clip, op_id: String, params: Dictionary) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	var m: MediaItem = media_of(c)
	var o: Dictionary = AudioOps.op(op_id)
	if d == null or s == null or m == null:
		return
	var rng: PackedFloat64Array = edit_span(c)
	var length: float = stream_length(c)
	var whole: bool = rng[0] <= 0.0005 and rng[1] >= length - 0.0005
	var entry: Dictionary = {"op": op_id, "params": params.duplicate(true), "from": rng[0], "to": rng[1], "timing_before": {"start": c.start, "duration": c.duration, "in_offset": c.in_offset}}
	if whole:
		entry["from"] = 0.0
		entry["to"] = -1.0
	var kind: String = String(o.get("kind", "filter"))
	entry["kind"] = kind
	if kind == "filter":
		entry["graph"] = AudioOps.graph(op_id, params, rng[1] - rng[0], stream_rate(c))
	var edits: Array = edits_of(c).duplicate(true)
	edits.append(entry)
	var audio: Dictionary = c.audio.duplicate(true)
	audio["edits"] = edits
	var key: String = render_key(m, source_stream(c), edits)
	var out_path: String = render_root().path_join(key + ".wav")
	audio["render"] = out_path
	var cmds: Array[Command] = [ClipCmds.SetClipField.new(s.id, c.id, "audio", audio)]
	var timing: Dictionary = _timing_after(c, entry, o)
	if not timing.is_empty():
		cmds.append(EditCmds.SetTiming.new(s.id, c.id, float(timing["start"]), float(timing["duration"]), float(timing["in_offset"])))
	if not Verbs.run(d, "Audio " + String(o["label"]), cmds):
		return
	if kind == "delete":
		clear_selection()
	elif kind == "keep":
		set_selection(0.0, rng[1] - rng[0])
	_start_render(c.id, m.path, source_stream(c), edits, out_path, String(o["label"]))


func _timing_after(c: Clip, entry: Dictionary, o: Dictionary) -> Dictionary:
	var mode: String = String(o.get("duration", ""))
	if mode.is_empty():
		return {}
	var w: PackedFloat64Array = clip_span(c)
	var a: float = float(entry["from"])
	var b: float = float(entry["to"])
	if b < 0.0:
		b = stream_length(c)
	var sp: float = absf(c.static_speed())
	if sp < 0.0001:
		sp = 1.0
	if mode == "keep":
		return {"start": c.start, "duration": (b - a) / sp, "in_offset": 0.0}
	if mode == "delete":
		var before: float = maxf(0.0, minf(b, w[0]) - a)
		var inside: float = maxf(0.0, minf(b, w[1]) - maxf(a, w[0]))
		return {"start": c.start, "duration": maxf(c.duration - inside / sp, 1.0 / fps()), "in_offset": maxf(c.in_offset - before, 0.0)}
	var factor: float = AudioOps.duration_factor(String(o["id"]), entry.get("params", {}))
	var before2: float = maxf(0.0, minf(b, w[0]) - a)
	var inside2: float = maxf(0.0, minf(b, w[1]) - maxf(a, w[0]))
	return {"start": c.start, "duration": maxf(c.duration + inside2 * (factor - 1.0) / sp, 1.0 / fps()), "in_offset": maxf(c.in_offset + before2 * (factor - 1.0), 0.0)}


func _start_render(target_clip: String, input: String, stream: int, edits: Array, out_path: String, label: String) -> void:
	if FileAccess.file_exists(out_path):
		_on_render_ready(out_path)
		return
	DirAccess.make_dir_recursive_absolute(render_root())
	var steps: Array = []
	for e: Variant in edits:
		var ed: Dictionary = e
		steps.append({"kind": String(ed.get("kind", "filter")), "graph": String(ed.get("graph", "anull")), "from": float(ed.get("from", 0.0)), "to": float(ed.get("to", -1.0))})
	_pending_output = out_path
	_pending_job = PurrBridge.audio_edit({"input": input, "stream": stream, "output": out_path, "steps": steps, "channels": 2, "label": "Audio edit: " + label})
	if _pending_job < 0:
		Events.error("The audio edit could not start", input)
		_pending_output = ""
		return
	_progress.value = 0.0
	_progress.visible = true
	_status.text = "Rendering " + label


func _on_job_progress(id: int, progress: float, _message: String) -> void:
	if id == _pending_job and _progress != null:
		_progress.value = progress * 100.0


func _on_edit_done(result: Dictionary) -> void:
	var out: String = String(result.get("output", ""))
	if out != _pending_output:
		return
	_pending_output = ""
	_pending_job = -1
	_progress.visible = false
	if not bool(result.get("ok", false)):
		Events.error("Audio edit failed", String(result.get("error", "")))
		_status.text = "The edit failed: " + String(result.get("error", ""))
		return
	_status.text = "Edit rendered"
	_on_render_ready(out)


func _on_render_ready(path: String) -> void:
	Session.forget_render(path)
	Session.render_handle(path)
	_wave_cache.clear()
	var d: Project = doc()
	if d != null:
		d.touch("media")
	_fit_pending = false
	if _wave != null:
		_wave.queue_redraw()


func _remove_last() -> void:
	var c: Clip = target()
	var d: Project = doc()
	var s: Sequence = seq()
	var m: MediaItem = media_of(c)
	if c == null or d == null or s == null or m == null:
		return
	var edits: Array = edits_of(c).duplicate(true)
	if edits.is_empty():
		return
	var last: Dictionary = edits.pop_back()
	var audio: Dictionary = c.audio.duplicate(true)
	audio["edits"] = edits
	var out_path: String = ""
	if not edits.is_empty():
		out_path = render_root().path_join(render_key(m, source_stream(c), edits) + ".wav")
	audio["render"] = out_path
	var cmds: Array[Command] = [ClipCmds.SetClipField.new(s.id, c.id, "audio", audio)]
	var tb: Variant = last.get("timing_before", null)
	if tb is Dictionary:
		cmds.append(EditCmds.SetTiming.new(s.id, c.id, float(tb.get("start", c.start)), float(tb.get("duration", c.duration)), float(tb.get("in_offset", c.in_offset))))
	Verbs.run(d, "Remove audio edit", cmds)
	if not out_path.is_empty():
		_start_render(c.id, m.path, source_stream(c), edits, out_path, "previous edits")


func _clear_edits() -> void:
	var c: Clip = target()
	var d: Project = doc()
	var s: Sequence = seq()
	if c == null or d == null or s == null:
		return
	var edits: Array = edits_of(c)
	if edits.is_empty():
		return
	var audio: Dictionary = c.audio.duplicate(true)
	audio["edits"] = []
	audio["render"] = ""
	var cmds: Array[Command] = [ClipCmds.SetClipField.new(s.id, c.id, "audio", audio)]
	var first: Dictionary = edits[0]
	var tb: Variant = first.get("timing_before", null)
	if tb is Dictionary:
		cmds.append(EditCmds.SetTiming.new(s.id, c.id, float(tb.get("start", c.start)), float(tb.get("duration", c.duration)), float(tb.get("in_offset", c.in_offset))))
	Verbs.run(d, "Remove audio edits", cmds)


func _on_play_selection() -> void:
	var c: Clip = target()
	if c == null:
		return
	if Session.playing:
		Session.set_playing(false)
		return
	var rng: PackedFloat64Array = edit_span(c)
	Session.set_playhead(timeline_time(c, rng[0]))
	Session.set_playing(true)


func _fit_clip() -> void:
	var c: Clip = target()
	if c == null:
		return
	var w: PackedFloat64Array = heard_span(c)
	var pad: float = maxf((w[1] - w[0]) * 0.05, 0.05)
	t0 = maxf(w[0] - pad, 0.0)
	t1 = minf(w[1] + pad, stream_length(c))
	if t1 - t0 < MIN_SPAN:
		t1 = t0 + MIN_SPAN
	_fit_pending = false
	_wave_cache.clear()
	_wave.queue_redraw()


func _zoom(factor: float, anchor_t: float = -1.0) -> void:
	var c: Clip = target()
	if c == null:
		return
	var span: float = (t1 - t0) * factor
	var length: float = stream_length(c)
	span = clampf(span, MIN_SPAN, maxf(length, MIN_SPAN))
	var pivot: float = anchor_t if anchor_t >= 0.0 else (t0 + t1) * 0.5
	var frac: float = (pivot - t0) / maxf(t1 - t0, 0.0001)
	t0 = pivot - span * frac
	t1 = t0 + span
	if t0 < 0.0:
		t1 -= t0
		t0 = 0.0
	if t1 > length:
		t0 = maxf(length - span, 0.0)
		t1 = t0 + span
	_wave_cache.clear()
	_wave.queue_redraw()


func _pan(dt: float) -> void:
	var c: Clip = target()
	if c == null:
		return
	var span: float = t1 - t0
	var length: float = stream_length(c)
	t0 = clampf(t0 + dt, 0.0, maxf(length - span, 0.0))
	t1 = t0 + span
	_wave_cache.clear()
	_wave.queue_redraw()


func wave_state(c: Clip) -> String:
	if c == null:
		return "none"
	var hs: Array = wave_handle(c)
	if int(hs[0]) >= 0 and (PurrBridge.available or peaks_provider.is_valid()):
		return "ok"
	var m: MediaItem = media_of(c)
	if m == null or m.missing or (not m.path.is_empty() and not FileAccess.file_exists(m.path)):
		return "missing"
	if not PurrBridge.available and not peaks_provider.is_valid():
		return "no_engine"
	return "opening"


func wave_message(c: Clip, state: String) -> String:
	var m: MediaItem = media_of(c)
	var name_: String = m.path.get_file() if m != null and not m.path.is_empty() else (m.label if m != null else "this clip")
	if state == "missing":
		return "The file is missing: " + name_
	if state == "no_engine":
		return "Waveforms need the engine, which did not load"
	if state == "opening":
		return "Opening " + name_
	if state == "loading":
		return "Reading the waveform"
	return ""


func _read_peaks(h: int, stream: int, tier: int, from_bucket: int, count: int) -> PackedByteArray:
	if peaks_provider.is_valid():
		return peaks_provider.call(h, stream, tier, from_bucket, count)
	return PurrBridge.peaks_read(h, stream, tier, from_bucket, count)


func _read_coverage(h: int, stream: int) -> PackedByteArray:
	if coverage_provider.is_valid():
		return coverage_provider.call(h, stream)
	return PurrBridge.peaks_coverage(h, stream)


func wave_points(c: Clip, width: float) -> Dictionary:
	var state: String = wave_state(c)
	if state != "ok":
		return {"pts": PackedVector2Array(), "rate": 100.0, "ready": false, "state": state, "origin": 0.0}
	var hs: Array = wave_handle(c)
	var h: int = int(hs[0])
	var stream: int = int(hs[1])
	var pps: float = width / maxf(t1 - t0, 0.0001)
	var fine: Dictionary = fine_wave_points(c, h, stream, pps)
	if not fine.is_empty():
		return fine
	var tier: int = Lanes.tier_for_pps(pps)
	var rate: float = Lanes.tier_rate(tier)
	var stride: int = maxi(1, int(floor(rate / maxf(pps, 0.0001))))
	var from_bucket: int = int(floor(t0 * rate / float(stride))) * stride
	var count: int = int(ceil(t1 * rate)) - from_bucket + 1
	var smooth: int = Paint.wave_smooth_steps(float(stride) / rate * pps)
	var win: PackedFloat64Array = heard_span(c)
	var key: String = str(h) + "|" + str(stream) + "|" + str(tier) + "|" + str(from_bucket) + "|" + str(count) + "|" + str(stride) + "|" + str(smooth) + "|" + String.num(win[0], 9) + "|" + String.num(win[1], 9)
	if _wave_cache.has(key):
		return _wave_cache[key]
	var coverage: PackedByteArray = _read_coverage(h, stream)
	var k0: int = int(floor(t0 / Lanes.CHUNK_SECONDS))
	var k1: int = int(floor(t1 / Lanes.CHUNK_SECONDS))
	var ready: bool = not coverage.is_empty()
	for k: int in range(k0, k1 + 1):
		if k >= coverage.size() or coverage[k] == 0:
			ready = false
	if not ready and not peaks_provider.is_valid():
		Session.want_peaks(h, stream, t0)
	var origin: float = float(from_bucket) / rate
	var bytes: PackedByteArray = _read_peaks(h, stream, tier, from_bucket, count)
	var log_mode: bool = bool(Prefs.get_value(PREF_LOG))
	var clip_from: float = win[0]
	var clip_to: float = maxf(win[1], win[0])
	var pts: PackedVector2Array = Paint.build_wave_ribbon(bytes, from_bucket, rate, stride, log_mode, 1.0, smooth, clip_from, clip_to, origin)
	var out: Dictionary = {"pts": pts, "rate": rate, "ready": ready, "state": "ok" if ready else "loading", "origin": origin}
	if ready:
		_wave_cache[key] = out
	return out


func fine_wave_points(c: Clip, h: int, stream: int, pps: float) -> Dictionary:
	if peaks_provider.is_valid() and not Waves.hooked():
		return {}
	var rate: float = Waves.fine_rate_for(pps)
	if rate <= 0.0 or not Waves.fine_available(h) or t1 - t0 > Waves.FINE_MAX_SPAN:
		return {}
	if Waves.fine_request(h, stream, maxf(t0, 0.0), t1) != Waves.FINE_READY:
		return {}
	var from_bucket: int = maxi(int(floor(t0 * rate)), 0)
	var count: int = int(ceil(t1 * rate)) - from_bucket + 1
	if count <= 0:
		return {}
	var win: PackedFloat64Array = heard_span(c)
	var key: String = "fine|" + str(h) + "|" + str(stream) + "|" + str(int(rate)) + "|" + str(from_bucket) + "|" + str(count) + "|" + String.num(win[0], 9) + "|" + String.num(win[1], 9)
	if _wave_cache.has(key):
		return _wave_cache[key]
	var bytes: PackedByteArray = Waves.fine_read(h, stream, from_bucket, count, rate)
	if bytes.is_empty():
		return {}
	var origin: float = float(from_bucket) / rate
	var pts: PackedVector2Array = Paint.build_wave_ribbon(bytes, from_bucket, rate, 1, bool(Prefs.get_value(PREF_LOG)), 1.0, Paint.wave_smooth_steps(pps / rate), win[0], maxf(win[1], win[0]), origin)
	var out: Dictionary = {"pts": pts, "rate": rate, "ready": true, "state": "ok", "origin": origin, "fine": true}
	_wave_cache[key] = out
	return out


func handle_key(e: InputEventKey) -> bool:
	if not e.pressed:
		return false
	var c: Clip = target()
	if c == null:
		return false
	var ctrl: bool = e.ctrl_pressed or e.meta_pressed
	if e.keycode == KEY_ESCAPE and has_selection():
		clear_selection()
		return true
	if ctrl and e.keycode == KEY_A:
		var w: PackedFloat64Array = clip_span(c)
		set_selection(w[0], w[1])
		return true
	if (e.keycode == KEY_DELETE or e.keycode == KEY_BACKSPACE) and has_selection():
		begin_op("delete")
		return true
	return false


func save_state() -> Dictionary:
	return {}


func restore_state(_d: Dictionary) -> void:
	pass


class _Wave:
	extends Control

	const PmTextKit := preload("res://ui/kit/pm_text.gd")
	const WaveLookKit := preload("res://ui/timeline/wave_look.gd")
	const WaveVolumeKit := preload("res://ui/timeline/wave_volume.gd")
	const WaveSheetKit := preload("res://ui/timeline/wave_look_sheet.gd")
	const LOG_PREF := "audio_editor.log_wave"

	var panel: RefCounted = null
	var _press_t: float = -1.0
	var _press_x: float = 0.0
	var _dragging: bool = false
	var _hover_t: float = -1.0
	var _font: Font = null
	var _fs: int = 11
	var last_state: String = ""
	var last_note: String = ""
	var _poll: float = 0.0

	func _process(dt: float) -> void:
		_poll += dt
		if _poll >= 0.25:
			_poll = 0.0
			queue_redraw()

	func _draw_hover_time(hx: float, text: String) -> void:
		var mono: Font = Tk.font("mono")
		var pad: float = PmTextKit.pad()
		var w: float = PmTextKit.width_of(mono, text, _fs)
		var x: float = hx + 6.0 if hx + 6.0 + w <= size.x - pad else hx - 6.0 - w
		var h: float = mono.get_height(_fs)
		var row := Rect2(0.0, size.y - 6.0 - mono.get_ascent(_fs), size.x, h)
		PmTextKit.draw_in(self, mono, Rect2(maxf(x, pad), row.position.y, w, h), text, _fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, size.y - 6.0, PmTextKit.WHOLE, row)

	func _draw_state_note(c: Clip, plot: Rect2) -> void:
		last_note = ""
		if last_state == "ok":
			return
		if last_state == "missing":
			Paint.hatch(self, plot, Tk.c["hatch"])
		var text: String = String(panel.call("wave_message", c, last_state))
		if text.is_empty():
			return
		last_note = text
		var pad: float = float(Tk.px(Tk.sz("pad"))) + 2.0
		var fs: int = Tk.fs(Tk.sz("font_small"))
		var col: Color = Tk.c["text"] if last_state == "missing" else Tk.c["text_faint"]
		PmTextKit.draw(self, _font, Rect2(plot.position.x, plot.position.y, plot.size.x, _font.get_height(fs) + pad * 2.0), text, fs, col, HORIZONTAL_ALIGNMENT_LEFT, pad, plot.position.y + pad + _font.get_ascent(fs))

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_CLICK
		clip_contents = true
		set_process(false)
		gui_input.connect(_on_input)
		mouse_exited.connect(func() -> void:
			_hover_t = -1.0
			queue_redraw())
		resized.connect(queue_redraw)

	func _ready() -> void:
		_font = Tk.font("body")
		_fs = Tk.fs(Tk.sz("font_tiny"))
		Waves.listen_fine(self)
		WaveLookKit.register_prefs()
		WaveLookKit.listen(self)

	func heard_volume(c: Clip, origin: float) -> Dictionary:
		if not WaveLookKit.volume_on():
			return {}
		var sp: float = c.static_speed()
		if absf(sp) < 0.0001:
			sp = 1.0
		var env: Dictionary = WaveVolumeKit.for_clip(panel.call("doc"), panel.call("seq"), c)
		return WaveVolumeKit.window(env, (origin - c.in_offset) / sp, 1.0 / sp)

	func _t_of(x: float) -> float:
		var t0: float = float(panel.get("t0"))
		var t1: float = float(panel.get("t1"))
		return t0 + clampf(x / maxf(size.x, 1.0), 0.0, 1.0) * (t1 - t0)

	func _x_of(t: float) -> float:
		var t0: float = float(panel.get("t0"))
		var t1: float = float(panel.get("t1"))
		return (t - t0) / maxf(t1 - t0, 0.0001) * size.x

	func _on_input(event: InputEvent) -> void:
		var c: Clip = panel.call("target")
		if c == null:
			return
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if not mb.pressed:
					return
				var up: bool = mb.button_index == MOUSE_BUTTON_WHEEL_UP
				if mb.ctrl_pressed or mb.meta_pressed:
					panel.call("_zoom", 0.8 if up else 1.25, _t_of(mb.position.x))
				else:
					var span: float = float(panel.get("t1")) - float(panel.get("t0"))
					panel.call("_pan", span * (-0.1 if up else 0.1))
				accept_event()
				return
			if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				WaveSheetKit.open(self, get_global_mouse_position())
				accept_event()
				return
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return
			if mb.pressed:
				grab_focus()
				var t: float = _t_of(mb.position.x)
				if mb.double_click:
					var w: PackedFloat64Array = panel.call("clip_span", c)
					panel.call("set_selection", w[0], w[1])
					_press_t = -1.0
					accept_event()
					return
				if mb.shift_pressed and bool(panel.call("has_selection")):
					var a: float = float(panel.get("sel_a"))
					var b: float = float(panel.get("sel_b"))
					if absf(t - a) < absf(t - b):
						panel.call("set_selection", t, b)
					else:
						panel.call("set_selection", a, t)
					_press_t = -1.0
					accept_event()
					return
				_press_t = t
				_press_x = mb.position.x
				_dragging = false
			else:
				if _press_t >= 0.0 and not _dragging:
					panel.call("clear_selection")
					Session.scrub_to(float(panel.call("timeline_time", c, _press_t)))
				_press_t = -1.0
				_dragging = false
			accept_event()
			return
		if event is InputEventMouseMotion:
			var mm: InputEventMouseMotion = event
			_hover_t = _t_of(mm.position.x)
			if _press_t >= 0.0:
				if not _dragging and absf(mm.position.x - _press_x) < 3.0:
					queue_redraw()
					return
				_dragging = true
				panel.call("set_selection", _press_t, _t_of(mm.position.x))
				accept_event()
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_field"], true)
		var c: Clip = panel.call("target")
		if c == null:
			last_state = "none"
			set_process(false)
			PmTextKit.draw(self, _font, Rect2(Vector2.ZERO, size), "Select an audio clip on the timeline", Tk.fs(Tk.sz("font_small")), Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, 8.0, size.y * 0.5 + 4.0)
			return
		if bool(panel.get("_fit_pending")):
			panel.call("_fit_clip")
		var rh: float = float(Tk.px(RULER_H))
		var plot: Rect2 = Rect2(0.0, rh, size.x, maxf(size.y - rh, 1.0))
		var w: PackedFloat64Array = panel.call("heard_span", c)
		var wx0: float = _x_of(w[0])
		var wx1: float = _x_of(w[1])
		draw_rect(plot, Color(0.0, 0.0, 0.0, 0.25), true)
		if wx1 > wx0:
			draw_rect(Rect2(maxf(wx0, 0.0), plot.position.y, minf(wx1, size.x) - maxf(wx0, 0.0), plot.size.y), Tk.c["bg_lane_audio"], true)
		var sel_a: float = float(panel.get("sel_a"))
		var sel_b: float = float(panel.get("sel_b"))
		if bool(panel.call("has_selection")):
			var sx0: float = _x_of(sel_a)
			var sx1: float = _x_of(sel_b)
			draw_rect(Rect2(sx0, plot.position.y, maxf(sx1 - sx0, 1.0), plot.size.y), Tk.c["selection_fill"], true)
			draw_rect(Rect2(sx0, plot.position.y, 1.0, plot.size.y), Tk.c["sol"], true)
			draw_rect(Rect2(sx1, plot.position.y, 1.0, plot.size.y), Tk.c["sol"], true)
		var centre_y: float = plot.position.y + plot.size.y * 0.5
		var half: float = plot.size.y * 0.5 - 4.0
		var lk: Dictionary = WaveLookKit.look()
		if WaveLookKit.anchor_of(lk) == WaveLookKit.GROW_MIDDLE:
			draw_line(Vector2(0.0, centre_y), Vector2(size.x, centre_y), Tk.c["wave_line"], 1.0)
		var wave: Dictionary = panel.call("wave_points", c, size.x)
		var pts: PackedVector2Array = wave["pts"]
		var t0: float = float(panel.get("t0"))
		var t1: float = float(panel.get("t1"))
		last_state = String(wave.get("state", "ok"))
		if pts.size() >= 6:
			var sx: float = size.x / maxf(t1 - t0, 0.0001)
			draw_set_transform(Vector2((float(wave.get("origin", 0.0)) - t0) * sx, centre_y), 0.0, Vector2(sx, half))
			var log_on: bool = bool(Prefs.get_value(LOG_PREF)) if Prefs.is_registered(LOG_PREF) else true
			WaveLookKit.draw_in(self, wave, pts, WaveLookKit.base_colour(lk, c.colour), WaveLookKit.scale(log_on, 1.0), sx, half, heard_volume(c, float(wave.get("origin", 0.0))))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_state_note(c, plot)
		set_process(last_state == "loading" or last_state == "opening")
		_draw_ruler(rh)
		var ph_src: float = float(panel.call("source_of_timeline", c, Session.playhead()))
		if Session.playhead() >= c.start and Session.playhead() <= c.end():
			var px: float = _x_of(ph_src)
			if px >= 0.0 and px <= size.x:
				draw_rect(Rect2(round(px), 0.0, 1.0, size.y), Tk.c["sol"], true)
		if _hover_t >= 0.0 and _press_t < 0.0:
			var hx: float = _x_of(_hover_t)
			draw_rect(Rect2(round(hx), plot.position.y, 1.0, plot.size.y), Color(Tk.c["text_faint"], 0.5), true)
			var text: String = String(panel.call("_secs", _hover_t))
			_draw_hover_time(hx, text)

	func _draw_ruler(rh: float) -> void:
		draw_rect(Rect2(0.0, 0.0, size.x, rh), Tk.c["bg_ruler"], true)
		var t0: float = float(panel.get("t0"))
		var t1: float = float(panel.get("t1"))
		var pps: float = size.x / maxf(t1 - t0, 0.0001)
		var step: float = Lanes.nice_tick(pps, 70.0)
		var t: float = ceil(t0 / step) * step
		var mono: Font = Tk.font("mono")
		while t <= t1:
			var x: float = _x_of(t)
			draw_rect(Rect2(x, rh - 5.0, 1.0, 5.0), Tk.c["text_faint"], true)
			var label: String = String(panel.call("_secs", t))
			var w: float = PmTextKit.width_of(mono, label, _fs)
			var lx: float = x + 3.0
			if lx + w > size.x - PmTextKit.chip_pad():
				lx = x - w - 3.0
			if lx >= PmTextKit.chip_pad():
				PmTextKit.draw_in(self, mono, Rect2(lx, 0.0, w, rh), label, _fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, rh - 6.0, PmTextKit.WHOLE, Rect2(0.0, 0.0, size.x, rh), PmTextKit.chip_pad())
			t += step
		draw_rect(Rect2(0.0, rh - 1.0, size.x, 1.0), Tk.c["border"], true)

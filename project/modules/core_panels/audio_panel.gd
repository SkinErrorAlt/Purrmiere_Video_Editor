extends "res://modules/core_panels/panel_base.gd"

const FrameJobs := preload("res://host/frame_jobs.gd")
const TrackCmds := preload("res://doc/commands/track_cmds.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const SequenceCmds := preload("res://doc/commands/sequence_cmds.gd")
const PREF_RANGE := "audio.meter_range"
const PREF_HOLD := "audio.meter_hold"
const PREF_CF_FORCE := "audio.crossfeed_force"
const AudioGraph := preload("res://engine/audio_graph.gd")
const TABS: Array = [["meters", "Meters"], ["mix", "Mix"], ["field", "Field"], ["voice", "Voice over"]]
const BANDS := 22
const TRAIL_SECONDS := 2.0
const SQUASH := 0.42
const POSITION_IDS: PackedStringArray = ["audio_position", "position", "panner"]
const PREF_TARGET := "audio.loudness_target"
const LOUDNESS_TARGETS: Array = [["YouTube, -14 LUFS", -14.0], ["Spotify, -14 LUFS", -14.0], ["Apple Podcasts, -16 LUFS", -16.0], ["EBU R128, -23 LUFS", -23.0], ["ATSC, -24 LUFS", -24.0], ["Netflix, -27 LUFS", -27.0]]
const LOUDNESS_TOLERANCE := 1.0
const LOUDNESS_FLOOR := -70.0
const LOUDNESS_TICK := 0.1
const REBUILD_NOTE := "Rebuild the engine for loudness"
const MASTER_ARM := "master"
const MASTER_FIELD := "master_volume"

var tab: String = "meters"
var _tabs: Control = null
var _pages: Dictionary = {}
var _meters: Control = null
var _mix: VBoxContainer = null
var _field: Control = null
var _mix_rows: Array[Dictionary] = []
var _mix_stamp: String = ""
var _held_at: float = -1.0
var _moved_since_hold: bool = false
var _loud_values: Dictionary = {}
var _loud_note: Label = null
var _loud_target: Button = null
var _loud_reset: Button = null
var _loud_clock: float = 0.0
var _master_fader: Control = null
var _master_sw: Button = null
var _master_dragging: bool = false
var _track_dragging: bool = false
var _track_live_label: String = ""


var _voice: VBoxContainer = null
var _voice_drop: Button = null
var _voice_status: Label = null
var _voice_button: Button = null
var _voice_meter: ProgressBar = null


func _build(root_: Control) -> void:
	for spec: Array in [[PREF_RANGE, 60, {"label": "Meter range (dB)", "type": "enum", "choices": ["60", "48", "36", "24"]}], [PREF_HOLD, 1.5, {"label": "Meter peak hold (seconds)", "type": "float", "min": 0.0, "max": 10.0}]]:
		if not Prefs.is_registered(String(spec[0])):
			Prefs.register(String(spec[0]), spec[1], spec[2])
	AudioGraph.register_crossfeed_prefs()
	if not Prefs.is_registered(PREF_TARGET):
		Prefs.register(PREF_TARGET, String(LOUDNESS_TARGETS[0][0]), {"label": "Loudness target", "type": "enum", "choices": target_labels()})
	if not Prefs.is_registered(PREF_CF_FORCE):
		Prefs.register(PREF_CF_FORCE, false, {"label": "Crossfeed, put it on every clip now", "type": "action", "button": "Apply to every clip", "note": "Crossfeed already follows the setting above on every clip that has none of its own. This writes it onto every clip as its own effect, in one undo step, which overwrites any clip you have set by hand.", "run": Callable(self, "_on_force_crossfeed")})
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = PmUI.hbox(0)
	_tabs = PmTabs.make(false)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t: Array in TABS:
		_tabs.call("add_tab", String(t[0]), String(t[1]), 0)
	_tabs.connect("tab_changed", show_tab)
	head.add_child(_tabs)
	var more: Button = quiet_icon("more", "Audio menu")
	more.pressed.connect(_on_menu.bind(more))
	head.add_child(more)
	col.add_child(head)
	var meters_page: VBoxContainer = PmUI.vbox(0)
	meters_page.name = "MetersPage"
	meters_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_meters = _Meters.new()
	_meters.panel = self
	_meters.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meters_page.add_child(_meters)
	meters_page.add_child(_build_loudness())
	col.add_child(meters_page)
	_pages["meters"] = meters_page
	var mix_scroll: ScrollContainer = vscroll_area(col)
	_mix = PmUI.vbox()
	_mix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mix_scroll.add_child(_mix)
	_pages["mix"] = mix_scroll
	_field = _Field.new()
	_field.panel = self
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_field)
	_pages["field"] = _field
	var voice_scroll: ScrollContainer = vscroll_area(col)
	_voice = PmUI.vbox(Tk.px(6.0))
	_voice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	voice_scroll.add_child(_voice)
	_pages["voice"] = voice_scroll
	_build_voice()
	show_tab(tab)
	rebuild_mix()
	refresh_loudness()


static func target_labels() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for t: Array in LOUDNESS_TARGETS:
		out.append(String(t[0]))
	return out


static func target_lufs_for(label: String) -> float:
	for t: Array in LOUDNESS_TARGETS:
		if String(t[0]) == label:
			return float(t[1])
	return float(LOUDNESS_TARGETS[0][1])


static func loudness_text(v: float, unit: String) -> String:
	if v <= LOUDNESS_FLOOR:
		return "-inf" + unit
	return String.num(v, 1) + unit


static func loudness_tint(integrated: float, target: float) -> String:
	if integrated <= LOUDNESS_FLOOR:
		return "text_dim"
	if integrated > target + LOUDNESS_TOLERANCE:
		return "key_over"
	if integrated < target - LOUDNESS_TOLERANCE:
		return "key_low"
	return "text"


static func loudness_verdict(integrated: float, target: float, seconds: float) -> String:
	if integrated <= LOUDNESS_FLOOR:
		return "Play the sequence to measure it."
	var diff: float = integrated - target
	var minutes: int = floori(seconds / 60.0)
	var length: String = "%d:%02d" % [minutes, int(seconds) - minutes * 60]
	if absf(diff) <= LOUDNESS_TOLERANCE:
		return "On target. Measured for " + length + "."
	var side: String = "over" if diff > 0.0 else "under"
	return String.num(absf(diff), 1) + " LU " + side + " the target. Measured for " + length + "."


func target_lufs() -> float:
	return target_lufs_for(String(Prefs.get_value(PREF_TARGET)))


func _build_loudness() -> Control:
	var pad: MarginContainer = MarginContainer.new()
	pad.name = "Loudness"
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, Tk.px(6.0))
	var box: VBoxContainer = PmUI.vbox(Tk.px(4.0))
	pad.add_child(box)
	box.add_child(PmUI.divider())
	var cells: HFlowContainer = PmUI.flow(Tk.px(6.0), Tk.px(4.0))
	_loud_values.clear()
	var tips: Dictionary = {
		"momentary": "Momentary loudness, the last 0.4 seconds",
		"short_term": "Short term loudness, the last 3 seconds",
		"integrated": "Integrated loudness, everything played since the last reset, with quiet gaps left out",
		"true_peak": "True peak, the highest point since the last reset, including peaks between samples",
	}
	for spec: Array in [["momentary", "M", "-00.0"], ["short_term", "S", "-00.0"], ["integrated", "I", "-00.0 LUFS"], ["true_peak", "TP", "-00.0 dBTP"]]:
		var cell: VBoxContainer = PmUI.vbox(0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size.x = ceil(Tk.font("mono").get_string_size(String(spec[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, Tk.fs(Tk.sz("font_body"))).x)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.add_child(PmLabel.tiny(String(spec[1])))
		var value: Label = PmLabel.mono("--", "text_dim")
		value.name = "Loud_" + String(spec[0])
		cell.add_child(value)
		PmUI.tip(cell, String(tips[String(spec[0])]))
		cells.add_child(cell)
		_loud_values[String(spec[0])] = value
	box.add_child(cells)
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.add_child(PmLabel.dim("Target"))
	var choices: Array = []
	for label: String in target_labels():
		choices.append(PmDrop.choice(label, label))
	_loud_target = PmDrop.make_drop(choices, String(Prefs.get_value(PREF_TARGET)))
	_loud_target.name = "LoudTarget"
	_loud_target.set("elide_w", 80.0)
	_loud_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loud_target.connect("changed", _on_loud_target)
	PmUI.tip(_loud_target, "The loudness the platform plays at. The I reading turns orange when it is louder than this and blue when it is quieter.")
	row.add_child(_loud_target)
	_loud_reset = PmButton.ghost("Reset")
	_loud_reset.name = "LoudReset"
	_loud_reset.pressed.connect(_on_loud_reset)
	PmUI.tip(_loud_reset, "Start measuring again from now")
	row.add_child(_loud_reset)
	box.add_child(row)
	_loud_note = PmLabel.dim(REBUILD_NOTE)
	_loud_note.name = "LoudNote"
	box.add_child(_loud_note)
	return pad


func refresh_loudness() -> void:
	if _loud_note == null or not is_instance_valid(_loud_note):
		return
	var has: bool = PurrBridge.has_loudness()
	_loud_reset.disabled = not has
	if not has:
		for k: String in _loud_values.keys():
			var dead: Label = _loud_values[k]
			dead.text = "--"
			PmLabel.set_colour(dead, "text_dim")
		_loud_note.text = REBUILD_NOTE
		return
	var r: Dictionary = PurrBridge.loudness()
	var target: float = target_lufs()
	var units: Dictionary = {"momentary": "", "short_term": "", "integrated": " LUFS", "true_peak": " dBTP"}
	for k: String in _loud_values.keys():
		var l: Label = _loud_values[k]
		var v: float = float(r.get(k, -200.0))
		if k == "true_peak":
			l.text = "-inf dBTP" if v <= -199.0 else String.num(v, 1) + " dBTP"
		else:
			l.text = loudness_text(v, String(units[k]))
		PmLabel.set_colour(l, loudness_tint(v, target) if k == "integrated" else ("text" if v > LOUDNESS_FLOOR else "text_dim"))
	_loud_note.text = loudness_verdict(float(r.get("integrated", -200.0)), target, float(r.get("seconds", 0.0)))


func _on_loud_target(id: String) -> void:
	Prefs.set_value(PREF_TARGET, id)
	refresh_loudness()


func _on_loud_reset() -> void:
	PurrBridge.loudness_reset()
	refresh_loudness()


func _vo() -> Node:
	if _root == null or not _root.is_inside_tree():
		return null
	return _root.get_tree().root.get_node_or_null("/root/VoiceOver")


func _build_voice() -> void:
	PmUI.clear(_voice)
	var vo: Node = _vo()
	if vo == null:
		_voice.add_child(PmLabel.dim("Voice over is not available"))
		return
	var devices: PackedStringArray = vo.call("input_devices")
	var choices: Array = []
	for d: String in devices:
		choices.append(PmDrop.choice(d, d))
	if choices.is_empty():
		choices.append(PmDrop.choice("Default", "No microphone found"))
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.add_child(PmLabel.trim("Microphone"))
	_voice_drop = PmDrop.make_drop(choices, String(vo.call("wanted_device")))
	_voice_drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_voice_drop.connect("changed", _on_voice_device)
	row.add_child(_voice_drop)
	var refresh: Button = quiet_icon("loop", "Look for microphones again")
	refresh.pressed.connect(_build_voice)
	row.add_child(refresh)
	_voice.add_child(row)
	var pin: CheckBox = CheckBox.new()
	pin.text = "Always use this microphone, never follow the system default"
	pin.button_pressed = bool(vo.call("device_pinned"))
	pin.toggled.connect(_on_voice_pin)
	PmUI.wrap_button(pin)
	_voice.add_child(pin)
	var clean: CheckBox = CheckBox.new()
	clean.text = "Delete voice over recordings no clip is using when a project is opened"
	clean.button_pressed = bool(vo.call("cleanup_enabled"))
	clean.toggled.connect(_on_voice_cleanup)
	PmUI.wrap_button(clean)
	_voice.add_child(clean)
	_voice_status = PmLabel.wrap("", "text_dim")
	_voice_status.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_small")))
	_voice.add_child(_voice_status)
	var bar: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	_voice_button = PmButton.primary("Record")
	_voice_button.pressed.connect(_on_voice_record)
	bar.add_child(_voice_button)
	var drop_it: Button = PmButton.ghost("Discard")
	drop_it.pressed.connect(_on_voice_discard)
	bar.add_child(drop_it)
	_voice.add_child(bar)
	_voice_meter = ProgressBar.new()
	_voice_meter.max_value = 1.0
	_voice_meter.show_percentage = false
	_voice_meter.custom_minimum_size.y = float(Tk.px(8.0))
	_voice.add_child(_voice_meter)
	if not vo.is_connected("level_changed", _on_voice_level):
		vo.connect("level_changed", _on_voice_level)
	if not vo.is_connected("state_changed", _on_voice_state):
		vo.connect("state_changed", _on_voice_state)
	_refresh_voice()


func _refresh_voice() -> void:
	var vo: Node = _vo()
	if vo == null or _voice_status == null:
		return
	var busy: bool = bool(vo.call("recording"))
	_voice_button.text = "Stop and place" if busy else "Record"
	var err: String = String(vo.call("last_error"))
	var seq_: Sequence = Session.seq()
	var target: String = "no audio track selected"
	if seq_ != null:
		var t: Track = load("res://modules/core_panels/commands.gd").call("voiceover_track", seq_)
		if t != null:
			target = t.label
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Recording goes onto: " + target)
	lines.append("Using: " + String(vo.call("current_device")))
	if not err.is_empty():
		lines.append(err)
	_voice_status.text = "
".join(lines)


func _on_voice_device(id: String) -> void:
	var vo: Node = _vo()
	if vo != null:
		vo.call("set_device", id)
	_refresh_voice()


func _on_voice_pin(on: bool) -> void:
	Prefs.set_value("audio.input_device_pinned", on)
	var vo: Node = _vo()
	if on and vo != null:
		vo.call("apply_device")
	_refresh_voice()


func _on_voice_cleanup(on: bool) -> void:
	Prefs.set_value("audio.voiceover_cleanup", on)


func _on_voice_record() -> void:
	Cmd.run("audio.voiceover")
	_refresh_voice()


func _on_voice_discard() -> void:
	Cmd.run("audio.voiceover_cancel")
	_refresh_voice()


func _on_voice_level(v: float) -> void:
	if _voice_meter != null:
		_voice_meter.value = clampf(v, 0.0, 1.0)


func _on_voice_state(_on: bool) -> void:
	_refresh_voice()


func show_tab(id: String) -> void:
	tab = id
	for k: String in _pages.keys():
		(_pages[k] as Control).visible = k == id
	_tabs.call("set_active", id, false)


func _on_force_crossfeed() -> void:
	var d: Project = doc()
	if d == null:
		Events.toast("Open a project first")
		return
	var n: int = Verbs.apply_crossfeed_everywhere(d, AudioGraph.crossfeed_settings())
	if n == 0:
		Events.toast("Nothing to change, every clip already matches")
	else:
		Events.notice("Crossfeed written onto " + str(n) + " clips", "One undo step puts them all back the way they were.")


func _on_menu(anchor: Control) -> void:
	var cur: String = str(Prefs.get_value(PREF_RANGE))
	var items: Array = []
	for r: String in ["60", "48", "36", "24"]:
		items.append(PmMenu.check_item("range:" + r, r + " dB range", cur == r))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("reset_leds", "Reset the clip LEDs"))
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_menu_picked)


func _on_pref_changed(key: String) -> void:
	if key == PREF_RANGE or key == PREF_HOLD:
		if _meters != null:
			_meters.queue_redraw()
	elif key == PREF_TARGET:
		if _loud_target != null and is_instance_valid(_loud_target):
			_loud_target.call("set_value", String(Prefs.get_value(PREF_TARGET)), false)
		refresh_loudness()


func _on_menu_picked(id: String) -> void:
	if id.begins_with("range:"):
		Prefs.set_value(PREF_RANGE, int(id.substr(6)))
		_meters.queue_redraw()
	elif id == "reset_leds":
		_meters.call("reset_leds")


func audio_tracks() -> Array[Track]:
	var s: Sequence = seq()
	var out: Array[Track] = []
	if s == null:
		return out
	for t: Track in sound_track_list(s):
		if not t.hidden:
			out.append(t)
	return out


func sound_track_list(s: Sequence) -> Array[Track]:
	var out: Array[Track] = []
	if s.free_tracks:
		for t: Track in s.top_down_tracks():
			if t.makes_sound():
				out.append(t)
		return out
	out.append_array(s.audio_tracks)
	for t: Track in s.extra_sound_tracks():
		if AudioGraph.has_sound(doc(), t):
			out.append(t)
	return out


var _slot_key: String = ""
var _slots: Dictionary = {}


func strip_meters(raw: PackedFloat32Array) -> PackedFloat32Array:
	var tracks: Array[Track] = audio_tracks()
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(tracks.size() * 2 + 2)
	out.fill(0.0)
	for i: int in mini(2, raw.size()):
		out[i] = raw[i]
	var s: Sequence = seq()
	var d: Project = doc()
	if s == null or d == null:
		return out
	var key: String = s.id + "|" + str(d.serial)
	if key != _slot_key:
		_slot_key = key
		_slots = AudioGraph.meter_slots(d, s)
	for i: int in tracks.size():
		var slots: PackedInt32Array = _slots.get(tracks[i].id, PackedInt32Array())
		for ch: int in 2:
			out[2 + i * 2 + ch] = AudioGraph.slot_level(raw, slots, ch)
	return out


func meter_range() -> float:
	return float(int(Prefs.get_value(PREF_RANGE)))


func tick(dt: float) -> void:
	if not _alive() or not _root.is_visible_in_tree():
		return
	if tab == "meters":
		_meters.call("advance", dt)
		_loud_clock += dt
		if _loud_clock >= LOUDNESS_TICK:
			_loud_clock = 0.0
			refresh_loudness()
	elif tab == "field":
		_field.call("advance", dt)


func _on_playing(on: bool) -> void:
	if on:
		_held_at = -1.0
		_moved_since_hold = false
	else:
		_held_at = playhead()
		_moved_since_hold = false
	_field.queue_redraw()


func _on_playhead(t: float) -> void:
	if _held_at >= 0.0 and absf(t - _held_at) > 0.0001:
		_moved_since_hold = true
	_field.queue_redraw()
	if tab == "mix" and _alive() and _root.is_visible_in_tree():
		refresh_mix()


func held_text() -> String:
	if Session.playing or _held_at < 0.0:
		return ""
	var text: String = "HELD AT " + tc(_held_at)
	if _moved_since_hold:
		text += "   PLAYHEAD HAS MOVED"
	return text


func _mix_stamp_now() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for t: Track in audio_tracks():
		parts.append(t.id + ":" + t.shown_label())
	return "|".join(parts)


func rebuild_mix() -> void:
	if not _alive():
		return
	PmUI.clear(_mix)
	_mix_rows.clear()
	_mix_stamp = _mix_stamp_now()
	_master_fader = null
	_master_sw = null
	if seq() != null:
		_mix.add_child(_build_master_strip())
	var tracks: Array[Track] = audio_tracks()
	if tracks.is_empty():
		_mix.add_child(PmLabel.dim("No audio tracks"))
		return
	for t: Track in tracks:
		var box: VBoxContainer = PmUI.vbox(2)
		var top: HBoxContainer = PmUI.hbox()
		top.add_child(PmLabel.small(t.shown_label()))
		top.add_child(PmUI.spacer())
		var mute: Button = toggle_icon("speaker_off", "Mute", t.muted)
		mute.set("icon_px", 12.0)
		mute.pressed.connect(_on_track_toggle.bind(t.id, "muted", mute))
		top.add_child(mute)
		var solo: Button = PmButton.make("S", "", true)
		solo.set("quiet", true)
		solo.button_pressed = t.solo
		solo.pressed.connect(_on_track_toggle.bind(t.id, "solo", solo))
		top.add_child(solo)
		box.add_child(top)
		var vrow: HBoxContainer = PmUI.hbox(2)
		var vsw: Button = quiet_icon("stopwatch", "Animate volume")
		vsw.set("icon_px", 12.0)
		vsw.pressed.connect(_on_track_stopwatch.bind(t.id, "volume"))
		vrow.add_child(vsw)
		var fader: Control = PmField.make(0.0, -60.0, 12.0, 0.5, " dB")
		fader.set("show_range", true)
		fader.set("label_text", "Vol")
		fader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fader.connect("value_changed", _on_fader.bind(t.id))
		fader.connect("edit_begun", _on_track_edit_begun)
		fader.connect("edit_ended", _on_track_edit_ended)
		vrow.add_child(fader)
		box.add_child(vrow)
		var prow: HBoxContainer = PmUI.hbox(2)
		var psw: Button = quiet_icon("stopwatch", "Animate pan")
		psw.set("icon_px", 12.0)
		psw.pressed.connect(_on_track_stopwatch.bind(t.id, "pan"))
		prow.add_child(psw)
		var pan: Control = PmField.make(0.0, -1.0, 1.0, 0.01, "")
		pan.set("show_range", true)
		pan.set("label_text", "Pan")
		pan.set("precision", 2)
		pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pan.connect("value_changed", _on_pan.bind(t.id))
		pan.connect("edit_begun", _on_track_edit_begun)
		pan.connect("edit_ended", _on_track_edit_ended)
		prow.add_child(pan)
		box.add_child(prow)
		box.add_child(PmUI.divider())
		_mix.add_child(box)
		_mix_rows.append({"track_id": t.id, "fader": fader, "pan": pan, "vsw": vsw, "psw": psw, "mute": mute, "solo": solo})
	refresh_mix()


func refresh_mix() -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var ph: float = s.playhead
	if _master_fader != null and is_instance_valid(_master_fader):
		if not bool(_master_fader.get("_dragging")) and _master_fader.get("_editor") == null:
			var mv: float = AnimProp.evaluate_float(s.master_volume, ph, s.duration())
			_master_fader.set("value", 20.0 * log(maxf(mv, 0.001)) / log(10.0) if mv > 0.001 else -60.0)
		_master_sw.set("active", AnimProp.is_animated(s.master_volume) or bus().is_armed(MASTER_ARM, MASTER_FIELD))
	for r: Dictionary in _mix_rows:
		var t: Track = s.track_by_id(String(r["track_id"]))
		if t == null:
			continue
		var fader: Control = r["fader"]
		if not bool(fader.get("_dragging")) and fader.get("_editor") == null:
			var v: float = AnimProp.evaluate_float(t.volume, ph, s.duration())
			fader.set("value", 20.0 * log(maxf(v, 0.001)) / log(10.0) if v > 0.001 else -60.0)
		var pan: Control = r["pan"]
		if not bool(pan.get("_dragging")) and pan.get("_editor") == null:
			pan.set("value", AnimProp.evaluate_float(t.pan, ph, s.duration()))
		(r["vsw"] as Button).set("active", AnimProp.is_animated(t.volume) or bus().is_armed(t.id, "volume"))
		(r["psw"] as Button).set("active", AnimProp.is_animated(t.pan) or bus().is_armed(t.id, "pan"))
		(r["mute"] as Button).button_pressed = t.muted
		(r["solo"] as Button).button_pressed = t.solo


func _write_track_anim(track_id: String, field: String, value: float) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var t: Track = s.track_by_id(track_id)
	if t == null:
		return
	if _record_track(d, s, track_id, field, value):
		return
	var prop: Dictionary = t.get(field)
	var next: Dictionary
	if AnimProp.is_animated(prop) or bus().is_armed(track_id, field):
		next = AnimProp.set_key(prop, s.playhead, value)
	else:
		next = AnimProp.make(value)
	if next == prop:
		return
	if _track_dragging:
		var step: Command = RecordCmds.SetTrackValue.new(s.id, track_id, field, next)
		step.label = "Track " + field
		d.undo.live(step)
		_track_live_label = "Track " + field
		return
	Verbs.run(d, "Track " + field, [TrackCmds.SetTrackField.new(s.id, track_id, field, next)])


func _on_track_edit_begun() -> void:
	_track_dragging = true
	_track_live_label = ""


func _on_track_edit_ended() -> void:
	_track_dragging = false
	var d: Project = doc()
	_finish_record(d)
	if d != null and d.undo.has_live():
		d.undo.commit_live(RecordCmds.commit_label(d, _track_live_label if not _track_live_label.is_empty() else "Track volume"))
	_track_live_label = ""


func _build_master_strip() -> Control:
	var box: VBoxContainer = PmUI.vbox(2)
	box.name = "MasterStrip"
	var top: HBoxContainer = PmUI.hbox()
	top.add_child(PmLabel.small("Master"))
	top.add_child(PmUI.spacer())
	top.add_child(PmLabel.tiny("whole sequence"))
	box.add_child(top)
	var row: HBoxContainer = PmUI.hbox(2)
	_master_sw = quiet_icon("stopwatch", "Animate the master volume")
	_master_sw.name = "MasterStopwatch"
	_master_sw.set("icon_px", 12.0)
	_master_sw.pressed.connect(_on_master_stopwatch)
	row.add_child(_master_sw)
	_master_fader = PmField.make(0.0, -60.0, 12.0, 0.5, " dB")
	_master_fader.name = "MasterFader"
	_master_fader.set("show_range", true)
	_master_fader.set("label_text", "Master")
	_master_fader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_master_fader.connect("value_changed", _on_master_fader)
	_master_fader.connect("edit_begun", _on_master_edit_begun)
	_master_fader.connect("edit_ended", _on_master_edit_ended)
	PmUI.tip(_master_fader, "Master volume for the whole sequence, after every track. Drag it, or click to type a value.")
	row.add_child(_master_fader)
	box.add_child(row)
	box.add_child(PmUI.divider())
	return box


func write_master(value: float, live: bool = false) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return false
	if RecordCmds.write_master(d, s, value, live):
		return true
	var prop: Dictionary = s.master_volume
	var next: Dictionary
	if AnimProp.is_animated(prop) or bus().is_armed(MASTER_ARM, MASTER_FIELD):
		next = AnimProp.set_key(prop, s.playhead, maxf(value, 0.0))
	else:
		next = AnimProp.make(maxf(value, 0.0))
	if next == prop:
		return false
	if live:
		var step: Command = RecordCmds.SetMasterValue.new(s.id, next)
		step.label = "Master volume"
		d.undo.live(step)
		return true
	return Verbs.run(d, "Master volume", [SequenceCmds.SetSequenceField.new(s.id, MASTER_FIELD, next)])


func _on_master_fader(db: float) -> void:
	write_master(pow(10.0, db / 20.0) if db > -60.0 else 0.0, _master_dragging)


func _on_master_edit_begun() -> void:
	_master_dragging = true


func _on_master_edit_ended() -> void:
	_master_dragging = false
	var d: Project = doc()
	_finish_record(d)
	if d != null and d.undo.has_live():
		d.undo.commit_live(RecordCmds.commit_label(d, "Master volume"))
	refresh_mix()


func _on_master_stopwatch() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var prop: Dictionary = s.master_volume
	if AnimProp.is_animated(prop):
		var v: float = AnimProp.evaluate_float(prop, s.playhead, s.duration())
		Verbs.run(d, "Master volume", [SequenceCmds.SetSequenceField.new(s.id, MASTER_FIELD, AnimProp.make(v))])
		bus().set_armed(MASTER_ARM, MASTER_FIELD, false)
	else:
		Verbs.run(d, "Master volume", [SequenceCmds.SetSequenceField.new(s.id, MASTER_FIELD, AnimProp.set_key(prop, s.playhead, AnimProp.static_value(prop)))])
		bus().set_armed(MASTER_ARM, MASTER_FIELD, true)
	refresh_mix()


func _on_fader(db: float, track_id: String) -> void:
	_write_track_anim(track_id, "volume", pow(10.0, db / 20.0) if db > -60.0 else 0.0)


func _on_pan(v: float, track_id: String) -> void:
	_write_track_anim(track_id, "pan", v)


func _on_track_stopwatch(track_id: String, field: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var t: Track = s.track_by_id(track_id)
	if t == null:
		return
	var prop: Dictionary = t.get(field)
	if AnimProp.is_animated(prop):
		var v: float = AnimProp.evaluate_float(prop, s.playhead, s.duration())
		Verbs.run(d, "Track " + field, [TrackCmds.SetTrackField.new(s.id, track_id, field, AnimProp.make(v))])
		bus().set_armed(track_id, field, false)
	else:
		Verbs.run(d, "Track " + field, [TrackCmds.SetTrackField.new(s.id, track_id, field, AnimProp.set_key(prop, s.playhead, AnimProp.static_value(prop)))])
		bus().set_armed(track_id, field, true)
	refresh_mix()


func _on_track_toggle(track_id: String, field: String, b: Button) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	Verbs.run(d, "Track " + field, [TrackCmds.SetTrackField.new(s.id, track_id, field, b.button_pressed)])


func _on_doc_changed(kind: String) -> void:
	if kind == "structure":
		_queue_mix_check()
		_meters.queue_redraw()
	elif kind == "meta" or kind == "selection":
		refresh_mix()
		_field.queue_redraw()


func _on_history() -> void:
	_queue_mix_check()


func _queue_mix_check() -> void:
	FrameJobs.add("audio_mix|" + str(get_instance_id()), _mix_check)


func _mix_check() -> void:
	if not _alive():
		return
	if _mix_stamp_now() != _mix_stamp:
		rebuild_mix()
	else:
		refresh_mix()


func _on_project_changed() -> void:
	rebuild_mix()
	load("res://modules/core_panels/panel_place.gd").call("mix_turn", self)
	_meters.queue_redraw()
	_field.queue_redraw()


func _on_sequence_changed(_id: String) -> void:
	rebuild_mix()
	load("res://modules/core_panels/panel_place.gd").call("mix_turn", self)
	_meters.queue_redraw()


func position_effect(c: Clip) -> Dictionary:
	if c == null:
		return {}
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) in POSITION_IDS:
			return {"entry": e, "audio": false}
	for ae: Variant in c.audio.get("effects", []):
		if ae is Dictionary and String((ae as Dictionary).get("id", "")) in POSITION_IDS:
			return {"entry": ae, "audio": true}
	return {}


func write_position(angle: float, distance: float) -> void:
	var s: Sequence = seq()
	var d: Project = doc()
	var c: Clip = Bus.selected_clip(s)
	var pe: Dictionary = position_effect(c)
	if pe.is_empty() or d == null:
		return
	var entry: Dictionary = pe["entry"]
	var uid: String = String(entry.get("uid", ""))
	var is_audio: bool = bool(pe["audio"])
	var prefix: String = "audio_effects." if is_audio else "effects."
	var key_a: float = bus().key_time_for(c, prefix + uid + ".angle", s.playhead)
	var key_d: float = bus().key_time_for(c, prefix + uid + ".distance", s.playhead)
	var tx: RefCounted = d.undo.begin("Audio position")
	Verbs.run(d, "Angle", [EffectCmds.SetEffectParam.new(s.id, c.id, uid, "angle", angle, c.param_time(prefix + uid + ".angle", key_a - c.start) if key_a >= 0.0 else -1.0, is_audio)])
	Verbs.run(d, "Distance", [EffectCmds.SetEffectParam.new(s.id, c.id, uid, "distance", distance, c.param_time(prefix + uid + ".distance", key_d - c.start) if key_d >= 0.0 else -1.0, is_audio)])
	tx.commit()


func write_height(h: float) -> void:
	var s: Sequence = seq()
	var d: Project = doc()
	var c: Clip = Bus.selected_clip(s)
	var pe: Dictionary = position_effect(c)
	if pe.is_empty() or d == null:
		return
	var entry: Dictionary = pe["entry"]
	Verbs.run(d, "Height", [EffectCmds.SetEffectParam.new(s.id, c.id, String(entry.get("uid", "")), "height", h, -1.0, bool(pe["audio"]))])


func position_values() -> Dictionary:
	var s: Sequence = seq()
	var c: Clip = Bus.selected_clip(s)
	var pe: Dictionary = position_effect(c)
	if pe.is_empty():
		return {}
	var entry: Dictionary = pe["entry"]
	var params: Dictionary = entry.get("params", {})
	var lt: float = s.playhead - c.start
	var out: Dictionary = {"label": c.label, "angle": 0.0, "distance": 0.5, "height": 0.0}
	for k: String in ["angle", "distance", "height"]:
		var p: Variant = params.get(k, null)
		if p is Dictionary:
			out[k] = AnimProp.evaluate_float(p, c.fx_time(entry, k, lt), c.duration, s.fps)
	return out


func save_state() -> Dictionary:
	return {"tab": tab}


func restore_state(d: Dictionary) -> void:
	var t: String = String(d.get("tab", "meters"))
	if _alive() and _pages.has(t):
		show_tab(t)


const RecordCmds := preload("res://doc/commands/record_cmds.gd")


func _record_track(d: Project, s: Sequence, track_id: String, field: String, value: float) -> bool:
	if not RecordCmds.write_track(d, s, track_id, field, value, _track_dragging):
		return false
	if _track_dragging:
		_track_live_label = "Record track " + field
	return true


func _finish_record(d: Project) -> void:
	if d != null:
		RecordCmds.finish(d)


class _Meters:
	extends Control

	const IconsKit := preload("res://ui/kit/icons.gd")
	const PmLabelKit := preload("res://ui/kit/pm_label.gd")

	var panel: RefCounted = null
	var levels: PackedFloat32Array = PackedFloat32Array()
	var holds: PackedFloat32Array = PackedFloat32Array()
	var hold_age: PackedFloat32Array = PackedFloat32Array()
	var latched: PackedByteArray = PackedByteArray()
	var peaks: PackedFloat32Array = PackedFloat32Array()
	var _tip_name: String = ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)

	func reset_leds() -> void:
		latched.fill(0)
		peaks.fill(0.0)
		queue_redraw()

	func _on_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			reset_leds()
		elif event is InputEventMouseMotion:
			_tip_for((event as InputEventMouseMotion).position)

	func _tip_for(at: Vector2) -> void:
		var PmTip: GDScript = load("res://ui/kit/pm_tip.gd")
		var tip: Control = PmTip.call("instance_for", self)
		if tip == null:
			return
		var g: Dictionary = geometry()
		var i: int = int(floor((at.x - float(g["scale_w"])) / float(g["strip_w"])))
		var names: PackedStringArray = g["names"]
		var hit: bool = i >= 0 and i < names.size() and at.y < float(g["top"]) - float(Tk.px(12.0))
		var want: String = names[i] if hit and _name_elided(g, i) else ""
		if want == _tip_name:
			return
		_tip_name = want
		PmTip.call("attach", self, want)
		if want.is_empty():
			tip.call("disarm", self)
		else:
			tip.call("arm", self)

	func geometry() -> Dictionary:
		var names: PackedStringArray = PackedStringArray(["SEQ"])
		for t: RefCounted in (panel.call("audio_tracks") as Array):
			names.append(String(t.call("shown_label")))
		var f: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_tiny"))
		var pad: float = float(Tk.px(Tk.sz("pad")))
		var chip: float = float(Tk.px(4.0))
		var range_db: float = float(panel.call("meter_range"))
		var scale_text_w: float = ceil(f.get_string_size("-" + str(int(range_db)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var scale_w: float = pad + scale_text_w + chip
		var top: float = float(Tk.px(34.0))
		var bottom: float = size.y - float(Tk.px(34.0))
		var avail: float = size.x - scale_w - pad
		var strip_w: float = clampf(avail / float(maxi(names.size(), 1)), float(Tk.px(22.0)), float(Tk.px(44.0)))
		return {"names": names, "font": f, "fs": fs, "pad": pad, "chip": chip, "range": range_db, "scale_w": scale_w, "scale_text_w": scale_text_w, "top": top, "bottom": bottom, "h": maxf(bottom - top, 10.0), "strip_w": strip_w, "name_y": float(Tk.px(12.0)), "hint_y": size.y - float(Tk.px(6.0))}

	func _name_elided(g: Dictionary, i: int) -> bool:
		var f: Font = g["font"]
		var w: float = f.get_string_size((g["names"] as PackedStringArray)[i], HORIZONTAL_ALIGNMENT_LEFT, -1, int(g["fs"])).x
		return w > float(g["strip_w"]) - float(g["chip"]) * 2.0 + 0.5

	func peak_text(v: float, room: float, f: Font, fs: int) -> String:
		if v <= 0.00001:
			return "-inf"
		var db: float = _db(v)
		for t: String in [String.num(db, 1), str(int(round(db)))]:
			if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= room + 0.5:
				return t
		return ""

	func fit_texts() -> Array:
		var g: Dictionary = geometry()
		var out: Array = []
		var f: Font = g["font"]
		var fs: int = int(g["fs"])
		var chip: float = float(g["chip"])
		var strip_w: float = float(g["strip_w"])
		var scale_box := Rect2(0.0, 0.0, float(g["scale_w"]), size.y)
		var step: float = 6.0 if float(g["range"]) <= 36.0 else 12.0
		var db: float = 0.0
		while db >= -float(g["range"]):
			var t: String = str(int(db))
			var w: float = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			out.append({"text": t, "rect": Rect2(float(g["scale_w"]) - chip - w, 0.0, w, 10.0), "need": w, "box": scale_box, "pad": chip})
			db -= step
		var names: PackedStringArray = g["names"]
		for i: int in names.size():
			var x: float = float(g["scale_w"]) + float(i) * strip_w
			var room: float = strip_w - chip * 2.0
			var need: float = f.get_string_size(names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var drawn: float = minf(need, room)
			out.append({"text": names[i], "rect": Rect2(x + (strip_w - drawn) * 0.5, 0.0, drawn, 12.0), "need": need, "box": Rect2(x, 0.0, strip_w, 12.0), "pad": chip, "elided": need > room + 0.5, "tip": true})
			var peak_pair: float = 0.0
			for ch: int in 2:
				var idx: int = i * 2 + ch
				if idx < peaks.size():
					peak_pair = maxf(peak_pair, peaks[idx])
			var pt: String = peak_text(peak_pair, room, f, fs)
			var pw: float = f.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			out.append({"text": pt, "rect": Rect2(x + (strip_w - pw) * 0.5, 0.0, pw, 12.0), "need": pw, "box": Rect2(x, 0.0, strip_w, 12.0), "pad": chip})
		var hint: String = "Click the LEDs to reset"
		var hw: float = f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var hroom: float = size.x - float(g["pad"]) * 2.0
		out.append({"text": hint, "rect": Rect2(float(g["pad"]), 0.0, minf(hw, hroom), 12.0), "need": hw, "elided": hw > hroom + 0.5, "tip": true})
		return out

	func advance(dt: float) -> void:
		var raw: PackedFloat32Array = PurrBridge.meters() if PurrBridge.available else PackedFloat32Array()
		raw = panel.call("strip_meters", raw)
		var n: int = (panel.call("audio_tracks") as Array).size() * 2 + 2
		if levels.size() != n:
			levels.resize(n)
			levels.fill(0.0)
			holds.resize(n)
			holds.fill(0.0)
			hold_age.resize(n)
			hold_age.fill(0.0)
			latched.resize(n)
			latched.fill(0)
			peaks.resize(n)
			peaks.fill(0.0)
		var hold_s: float = float(Prefs.get_value("audio.meter_hold"))
		for i: int in n:
			var v: float = raw[i] if i < raw.size() else 0.0
			levels[i] = maxf(v, levels[i] - dt * 3.0)
			if v >= holds[i]:
				holds[i] = v
				hold_age[i] = 0.0
			else:
				hold_age[i] += dt
				if hold_age[i] > hold_s:
					holds[i] = maxf(holds[i] - dt * 0.5, v)
			if v > peaks[i]:
				peaks[i] = v
			if v >= 0.999:
				latched[i] = 1
		queue_redraw()

	func _db(v: float) -> float:
		if v <= 0.00001:
			return -120.0
		return 20.0 * log(v) / log(10.0)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_panel"], true)
		var g: Dictionary = geometry()
		var names: PackedStringArray = g["names"]
		var f: Font = g["font"]
		var fs: int = int(g["fs"])
		var range_db: float = float(g["range"])
		var scale_w: float = float(g["scale_w"])
		var top: float = float(g["top"])
		var bottom: float = float(g["bottom"])
		var hint_y: float = float(g["hint_y"])
		var h: float = float(g["h"])
		var count: int = names.size()
		var strip_w: float = float(g["strip_w"])
		var chip: float = float(g["chip"])
		var scale_x: float = scale_w - chip - float(g["scale_text_w"])
		PmLabelKit.draw_fit(self, f, Vector2(scale_x, top + fs * 0.4), "0", float(g["scale_text_w"]), fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_RIGHT)
		var step: float = 6.0 if range_db <= 36.0 else 12.0
		var db: float = -step
		while db >= -range_db:
			var y: float = top + (-db / range_db) * h
			PmLabelKit.draw_fit(self, f, Vector2(scale_x, y + fs * 0.4), str(int(db)), float(g["scale_text_w"]), fs, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_RIGHT)
			db -= step
		for i: int in count:
			var x: float = scale_w + float(i) * strip_w
			var bar_w: float = maxf((strip_w - 8.0) * 0.5 - 1.0, 3.0)
			var col_name: Color = Tk.c["text"]
			PmLabelKit.draw_fit(self, f, Vector2(x + chip, float(g["name_y"])), names[i], strip_w - chip * 2.0, fs, col_name, HORIZONTAL_ALIGNMENT_CENTER)
			var peak_pair: float = 0.0
			for ch: int in 2:
				var idx: int = i * 2 + ch
				var bx: float = x + 3.0 + float(ch) * (bar_w + 2.0)
				draw_rect(Rect2(bx, top, bar_w, h), Tk.c["bg_field"], true)
				var v: float = levels[idx] if idx < levels.size() else 0.0
				var frac: float = clampf(1.0 + _db(v) / range_db, 0.0, 1.0)
				if frac > 0.0:
					draw_rect(Rect2(bx, top + h * (1.0 - frac), bar_w, h * frac), Tk.c["text"], true)
				var hv: float = holds[idx] if idx < holds.size() else 0.0
				var hf: float = clampf(1.0 + _db(hv) / range_db, 0.0, 1.0)
				if hf > 0.0:
					draw_rect(Rect2(bx, top + h * (1.0 - hf) - 1.0, bar_w, 2.0), Tk.c["text_bright"], true)
				var led: bool = idx < latched.size() and latched[idx] == 1
				draw_rect(Rect2(bx + bar_w * 0.5 - 2.5, top - 11.0, 5.0, 5.0), Tk.c["text_bright"] if led else Tk.c["text_faint"], led)
				if idx < peaks.size():
					peak_pair = maxf(peak_pair, peaks[idx])
			var pt: String = peak_text(peak_pair, strip_w - chip * 2.0, f, fs)
			PmLabelKit.draw_fit(self, f, Vector2(x + chip, bottom + fs + float(Tk.px(2.0))), pt, strip_w - chip * 2.0, fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_CENTER)
		PmLabelKit.draw_fit(self, f, Vector2(float(g["pad"]), hint_y), "Click the LEDs to reset", size.x - float(g["pad"]) * 2.0, fs, Tk.c["text_faint"])


class _Field:
	extends Control

	const PmLabelKit := preload("res://ui/kit/pm_label.gd")

	var panel: RefCounted = null
	var lines: Array = []
	var _tip_text: String = ""
	var bands: PackedFloat32Array = PackedFloat32Array()
	var trail: Array = []
	var centroid: Vector2 = Vector2.ZERO
	var centroid_history: Array = []
	var _drag_handle: bool = false
	var _slider: HSlider = null
	var _height_label: Label = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)
		_slider = HSlider.new()
		_slider.min_value = -1.0
		_slider.max_value = 1.0
		_slider.step = 0.01
		_slider.focus_mode = Control.FOCUS_NONE
		_slider.value_changed.connect(_on_slider)
		add_child(_slider)
		resized.connect(_layout)

	func _layout() -> void:
		_slider.position = Vector2(60.0, size.y - 46.0)
		_slider.size = Vector2(maxf(size.x - 120.0, 40.0), 16.0)

	func _on_slider(v: float) -> void:
		panel.call("write_height", v)

	func ring() -> Dictionary:
		var cx: float = size.x * 0.5
		var cy: float = size.y * 0.45
		var r: float = maxf(minf(size.x * 0.4, size.y * 0.3), 20.0)
		return {"centre": Vector2(cx, cy), "radius": r}

	func point_for(angle_deg: float, dist: float) -> Vector2:
		var rg: Dictionary = ring()
		var c: Vector2 = rg["centre"]
		var r: float = float(rg["radius"])
		var a: float = deg_to_rad(angle_deg)
		return c + Vector2(sin(a) * dist * r, -cos(a) * dist * r * SQUASH)

	func angle_dist_for(p: Vector2) -> Vector2:
		var rg: Dictionary = ring()
		var c: Vector2 = rg["centre"]
		var r: float = float(rg["radius"])
		var dx: float = (p.x - c.x) / r
		var dy: float = -(p.y - c.y) / (r * SQUASH)
		var dist: float = clampf(Vector2(dx, dy).length(), 0.0, 1.0)
		var ang: float = fposmod(rad_to_deg(atan2(dx, dy)), 360.0)
		return Vector2(ang, dist)

	func advance(dt: float) -> void:
		if not PurrBridge.available:
			return
		var raw: PackedFloat32Array = PurrBridge.spectrum(BANDS)
		if raw.size() < BANDS * 2:
			return
		bands = raw
		var sum_w: float = 0.0
		var acc: Vector2 = Vector2.ZERO
		var rg: Dictionary = ring()
		var r: float = float(rg["radius"])
		var c: Vector2 = rg["centre"]
		var pts: Array = []
		for i: int in BANDS:
			var l: float = raw[i * 2]
			var rr: float = raw[i * 2 + 1]
			var level: float = clampf(maxf(l, rr), 0.0, 1.0)
			var balance: float = 0.0
			if l + rr > 0.0001:
				balance = (rr - l) / (l + rr)
			var angle: float = balance * PI * 0.5
			var out: float = (0.18 + 0.82 * level) * r
			var p: Vector2 = c + Vector2(sin(angle) * out, -cos(angle) * out * SQUASH)
			pts.append({"p": p, "level": level})
			acc += p * level * level
			sum_w += level * level
		if sum_w > 0.0001:
			centroid = acc / sum_w
		else:
			centroid = c
		trail.append({"pts": pts, "age": 0.0})
		for e: Dictionary in trail:
			e["age"] = float(e["age"]) + dt
		while not trail.is_empty() and float(trail[0]["age"]) > TRAIL_SECONDS:
			trail.pop_front()
		var width: float = 0.0
		if not pts.is_empty():
			var lo: float = INF
			var hi: float = -INF
			for e: Dictionary in pts:
				lo = minf(lo, (e["p"] as Vector2).x)
				hi = maxf(hi, (e["p"] as Vector2).x)
			width = (hi - lo) / maxf(r * 2.0, 1.0)
		centroid_history.append({"x": (centroid.x - c.x) / maxf(r, 1.0), "w": width, "age": 0.0})
		for e: Dictionary in centroid_history:
			e["age"] = float(e["age"]) + dt
		while not centroid_history.is_empty() and float(centroid_history[0]["age"]) > 4.0:
			centroid_history.pop_front()
		queue_redraw()

	func verdict() -> String:
		if not PurrBridge.available:
			return "The Field needs the engine's spectrum. Nothing is playing through it."
		var swing: float = 0.0
		var lo: float = INF
		var hi: float = -INF
		var widest: float = 0.0
		for e: Dictionary in centroid_history:
			lo = minf(lo, float(e["x"]))
			hi = maxf(hi, float(e["x"]))
			widest = maxf(widest, float(e["w"]))
		if lo < hi:
			swing = hi - lo
		if swing >= 0.22 or widest >= 0.18:
			return "Spatial. The image swings " + String.num(swing, 2) + " across the front over the last 4 s."
		return "Centred. Nothing here is moving round."

	func _on_input(event: InputEvent) -> void:
		var pv: Dictionary = panel.call("position_values")
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return
			if mb.pressed and not pv.is_empty():
				var hp: Vector2 = point_for(float(pv["angle"]), float(pv["distance"]))
				if hp.distance_to(mb.position) <= 12.0:
					_drag_handle = true
			else:
				_drag_handle = false
			accept_event()
			return
		if event is InputEventMouseMotion and _drag_handle:
			var ad: Vector2 = angle_dist_for((event as InputEventMouseMotion).position)
			panel.call("write_position", ad.x, ad.y)
			accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_panel"], true)
		var rg: Dictionary = ring()
		var c: Vector2 = rg["centre"]
		var r: float = float(rg["radius"])
		var f: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_tiny"))
		for k: float in [1.0, 0.66, 0.33]:
			var pts := PackedVector2Array()
			for i: int in 65:
				var a: float = TAU * float(i) / 64.0
				pts.append(c + Vector2(cos(a) * r * k, sin(a) * r * k * SQUASH))
			draw_polyline(pts, Tk.c["border_soft"] if k < 1.0 else Tk.c["accent_dim"], 1.0, true)
		draw_line(c - Vector2(r, 0.0), c + Vector2(r, 0.0), Tk.c["border_soft"], 1.0)
		draw_line(c - Vector2(0.0, r * SQUASH), c + Vector2(0.0, r * SQUASH), Tk.c["border_soft"], 1.0)
		var front_w: float = f.get_string_size("FRONT", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var behind_w: float = f.get_string_size("BEHIND", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(c.x - front_w * 0.5, c.y - r * SQUASH - 6.0), "FRONT", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tk.c["text_dim"])
		draw_string(f, Vector2(c.x - behind_w * 0.5, c.y + r * SQUASH + 14.0), "BEHIND", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tk.c["text_dim"])
		draw_string(f, Vector2(c.x - r - 12.0, c.y + 4.0), "L", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tk.c["text_dim"])
		draw_string(f, Vector2(c.x + r + 5.0, c.y + 4.0), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tk.c["text_dim"])
		for e: Dictionary in trail:
			var age: float = float(e["age"])
			var alpha: float = lerpf(0.56, 0.06, clampf(age / TRAIL_SECONDS, 0.0, 1.0))
			for d: Dictionary in e["pts"]:
				var level: float = float(d["level"])
				draw_circle(d["p"], 2.0 + 5.0 * level, Color(Tk.c["text"], alpha * (0.25 + 0.7 * level)))
		if not trail.is_empty():
			draw_line(c, centroid, Tk.c["text"], 1.0)
			draw_circle(centroid, 3.0, Tk.c["text_bright"])
		draw_circle(c, 2.5, Tk.c["text_bright"])
		var pv: Dictionary = panel.call("position_values")
		if not pv.is_empty():
			var hp: Vector2 = point_for(float(pv["angle"]), float(pv["distance"]))
			draw_arc(hp, 6.0, 0.0, TAU, 24, Tk.c["accent"], 1.5, true)
			draw_circle(hp, 2.0, Tk.c["accent"])
			_slider.visible = true
			_slider.set_value_no_signal(float(pv["height"]))
		else:
			_slider.visible = false
		var y: float = c.y + r * SQUASH + 34.0
		var body_fs: int = Tk.fs(Tk.sz("font_small"))
		var pad: float = float(Tk.px(Tk.sz("pad")))
		var room: float = size.x - pad * 2.0
		lines = []
		lines.append(PmLabelKit.draw_fit(self, f, Vector2(pad, y), verdict(), room, body_fs, Tk.c["text"]))
		y += body_fs + 6.0
		if not pv.is_empty():
			lines.append(PmLabelKit.draw_fit(self, f, Vector2(pad, y), "Selected: " + String(pv["label"]) + " · Audio Position " + str(int(round(float(pv["angle"])))) + " ° " + String.num(float(pv["distance"]), 2), room, body_fs, Tk.c["text_dim"]))
			y += body_fs + 6.0
			draw_string(f, Vector2(pad, size.y - 34.0), "Height", HORIZONTAL_ALIGNMENT_LEFT, -1, body_fs, Tk.c["text_dim"])
			PmLabelKit.draw_fit(self, f, Vector2(pad, size.y - 34.0), ("+" if float(pv["height"]) >= 0.0 else "") + String.num(float(pv["height"]), 2), room, body_fs, Tk.c["text"], HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			lines.append(PmLabelKit.draw_fit(self, f, Vector2(pad, y), "Select a clip with Audio Position to place it", room, body_fs, Tk.c["text_faint"]))
		var held: String = String(panel.call("held_text"))
		if not held.is_empty():
			lines.append(PmLabelKit.draw_fit(self, Tk.font("mono"), Vector2(pad, size.y - 10.0), held, room, fs, Tk.c["text_dim"]))
		_tip_elided()

	func _tip_elided() -> void:
		var full: PackedStringArray = PackedStringArray()
		for d: Dictionary in lines:
			if bool(d["elided"]):
				full.append(String(d["text"]))
		var want: String = "\n".join(full)
		if want == _tip_text:
			return
		_tip_text = want
		var PmTip: GDScript = load("res://ui/kit/pm_tip.gd")
		PmTip.call("attach", self, want)

	func fit_texts() -> Array:
		var out: Array = []
		for d: Dictionary in lines:
			out.append({"text": "field line", "rect": Rect2(float(d["x"]), 0.0, float(d["w"]), 12.0), "need": float(d["need"]), "elided": bool(d["elided"]), "tip": bool(d["elided"]) and not _tip_text.is_empty()})
		return out

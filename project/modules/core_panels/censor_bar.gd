extends PanelContainer

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Censor := preload("res://doc/censor.gd")
const SELF_PATH := "res://modules/core_panels/censor_bar.gd"
const SHEET_PATH := "res://modules/core_panels/censor_sheet.gd"
const FILE_FILTERS: PackedStringArray = ["*.wav, *.mp3, *.ogg, *.flac, *.m4a, *.aac, *.opus ; Sound files"]

var sound_drop: Button = null
var volume_field: Control = null
var cut_drop: Button = null
var duck_box: Control = null
var duck_field: Control = null
var fade_box: Control = null
var fade_field: Control = null
var fit_drop: Button = null
var snap_timeline_box: CheckBox = null
var snap_sound_box: CheckBox = null
var snap_from_drop: Button = null
var overlap_box: CheckBox = null
var in_out_button: Button = null
var _syncing: bool = false
var _dragging: Dictionary = {}


static func make() -> Control:
	var script: GDScript = load(SELF_PATH)
	var bar: PanelContainer = script.new()
	bar.call("build")
	return bar


static func sound_choices(doc: Project, file_id: String, file_label: String) -> Array:
	var out: Array = []
	for k: String in Censor.BUILT_IN:
		out.append(PmDrop.choice(k, String(Censor.SOUNDS[k]["label"])))
	if doc != null:
		for m: MediaItem in doc.media:
			if m.kind == "audio":
				out.append(PmDrop.choice("media:" + m.id, m.label))
	if not file_id.is_empty():
		out.append(PmDrop.choice(file_id, file_label))
	out.append(PmDrop.choice("choose", "Choose a file"))
	return out


static func labelled(ids: PackedStringArray, labels: Dictionary) -> Array:
	var out: Array = []
	for k: String in ids:
		out.append(PmDrop.choice(k, String(labels[k])))
	return out


static func choose_file(host: Node, on_chosen: Callable) -> void:
	if host == null or not host.is_inside_tree():
		return
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.use_native_dialog = true
	dialog.title = "Choose a censor sound"
	dialog.filters = FILE_FILTERS
	dialog.file_selected.connect(on_chosen)
	dialog.file_selected.connect(func(_p: String) -> void: PmUI.free_node(dialog))
	dialog.canceled.connect(func() -> void: PmUI.free_node(dialog))
	host.add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))


static func use_as_defaults(doc: Project, settings: Dictionary) -> void:
	var clean: Dictionary = Censor.normalised_settings(settings)
	var sound: String = String(clean["sound"])
	if Censor.BUILT_IN.has(sound):
		Censor.set_pref(Censor.PREF_SOUND, sound)
	elif sound.begins_with("media:"):
		var m: MediaItem = doc.media_by_id(sound.substr(6)) if doc != null else null
		if m != null:
			Censor.set_pref(Censor.PREF_CUSTOM, m.path)
			Censor.set_pref(Censor.PREF_SOUND, "custom")
	elif sound.begins_with("file:"):
		Censor.set_pref(Censor.PREF_CUSTOM, sound.substr(5))
		Censor.set_pref(Censor.PREF_SOUND, "custom")
	Censor.set_pref(Censor.PREF_VOLUME, float(clean["volume_db"]))
	Censor.set_pref(Censor.PREF_CUT, String(clean["cut"]))
	Censor.set_pref(Censor.PREF_DUCK, float(clean["duck_db"]))
	Censor.set_pref(Censor.PREF_FADE, float(clean["fade_ms"]))
	Censor.set_pref(Censor.PREF_FIT, String(clean["fit"]))


static func open_sheet(host: Node, doc: Project, seq: Sequence, clip_id: String, region_id: String) -> Node:
	return load(SHEET_PATH).call("open", host, doc, seq, clip_id, region_id)


static func pref_sound_value(doc: Project) -> String:
	var sound: String = String(Censor.pref(Censor.PREF_SOUND))
	if sound != "custom":
		return sound if Censor.BUILT_IN.has(sound) else "bleep"
	var resolved: String = Censor.custom_sound(doc, String(Censor.pref(Censor.PREF_CUSTOM)))
	if resolved.begins_with("file:"):
		return "file"
	return resolved


func build() -> void:
	name = "CensorBar"
	Censor.register_prefs()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tk.c["bg_panel_alt"]
	sb.border_color = Tk.c["border"]
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	var pad: float = float(Tk.px(Tk.sz("pad")))
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = float(Tk.px(3.0))
	sb.content_margin_bottom = float(Tk.px(3.0))
	add_theme_stylebox_override("panel", sb)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", Tk.px(Tk.sz("pad")))
	flow.add_theme_constant_override("v_separation", Tk.px(Tk.sz("gap")))
	add_child(flow)
	var title: Label = PmLabel.meta("Censor")
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flow.add_child(title)
	sound_drop = PmDrop.make_drop(sound_choices(Session.doc, "", ""), "bleep")
	sound_drop.connect("changed", _on_sound)
	_pair(flow, "Sound", sound_drop, "The sound that plays over new censors")
	volume_field = PmField.make(0.0, Censor.VOLUME_MIN, Censor.VOLUME_MAX, 0.5, " dB")
	volume_field.custom_minimum_size.x = float(Tk.px(72.0))
	_field_signals(volume_field, Censor.PREF_VOLUME)
	_pair(flow, "Volume", volume_field, "How loud the censor sound plays, 0 dB is as made")
	cut_drop = PmDrop.make_drop(labelled(Censor.CUTS, Censor.CUT_LABELS), "mute")
	cut_drop.connect("changed", _on_choice.bind(Censor.PREF_CUT))
	_pair(flow, "Cut", cut_drop, "What happens to the words under a censor")
	duck_field = PmField.make(18.0, Censor.DUCK_MIN, Censor.DUCK_MAX, 1.0, " dB")
	duck_field.custom_minimum_size.x = float(Tk.px(64.0))
	_field_signals(duck_field, Censor.PREF_DUCK)
	duck_box = _pair(flow, "Duck by", duck_field, "How far the words are turned down")
	fade_field = PmField.make(60.0, Censor.FADE_MIN, Censor.FADE_MAX, 5.0, " ms")
	fade_field.custom_minimum_size.x = float(Tk.px(72.0))
	_field_signals(fade_field, Censor.PREF_FADE)
	fade_box = _pair(flow, "Fade over", fade_field, "How long the words take to fade out, and back in at the end")
	fit_drop = PmDrop.make_drop(labelled(Censor.FITS, Censor.FIT_LABELS), "cut")
	fit_drop.connect("changed", _on_choice.bind(Censor.PREF_FIT))
	_pair(flow, "Fit", fit_drop, "Cut the sound to the censor, loop it to fill the censor, or play it once whole")
	snap_timeline_box = _switch(flow, "Snap to the timeline", "Censor edges snap as the rest of the timeline does: edits, markers, the playhead, in and out, view change lines and frame steps. S turns all snapping off", Censor.PREF_SNAP_TIMELINE)
	snap_sound_box = _switch(flow, "Snap to the sound", "Censor edges settle in the quiet gaps around a word, read from the sound picked beside it", Censor.PREF_SNAP_SOUND)
	snap_from_drop = PmDrop.make_drop(snap_from_choices(Session.seq()), Censor.SNAP_FROM_CLIP)
	snap_from_drop.connect("changed", _on_choice.bind(Censor.PREF_SNAP_FROM))
	PmUI.tip(snap_from_drop, "Which sound the edges snap to: the clip you censor, or whatever clip is on the chosen audio track")
	flow.add_child(snap_from_drop)
	overlap_box = CheckBox.new()
	overlap_box.text = "Overlap"
	overlap_box.focus_mode = Control.FOCUS_NONE
	overlap_box.toggled.connect(_on_overlap)
	PmUI.tip(overlap_box, "Let censors overlap; when off, a new censor that touches another joins it")
	flow.add_child(overlap_box)
	in_out_button = PmButton.ghost("Censor in to out")
	PmUI.tip(in_out_button, "Censor the sound clips on the targeted tracks between the in and out points", Cmd.keys_text("seq.censor_in_out"))
	in_out_button.pressed.connect(_on_in_out)
	flow.add_child(in_out_button)
	visible = Session.tool_id == Censor.TOOL_ID
	if not Session.tool_changed.is_connected(_on_tool):
		Session.tool_changed.connect(_on_tool)
	if not Session.project_changed.is_connected(sync):
		Session.project_changed.connect(sync)
	if not Prefs.changed.is_connected(_on_pref):
		Prefs.changed.connect(_on_pref)
	sync()


func _exit_tree() -> void:
	if Session.tool_changed.is_connected(_on_tool):
		Session.tool_changed.disconnect(_on_tool)
	if Session.project_changed.is_connected(sync):
		Session.project_changed.disconnect(sync)
	if Prefs.changed.is_connected(_on_pref):
		Prefs.changed.disconnect(_on_pref)


func _enter_tree() -> void:
	if sound_drop == null:
		return
	if not Session.tool_changed.is_connected(_on_tool):
		Session.tool_changed.connect(_on_tool)
	if not Session.project_changed.is_connected(sync):
		Session.project_changed.connect(sync)
	if not Prefs.changed.is_connected(_on_pref):
		Prefs.changed.connect(_on_pref)


static func snap_from_choices(seq: Sequence) -> Array:
	var out: Array = [PmDrop.choice(Censor.SNAP_FROM_CLIP, Censor.SNAP_FROM_CLIP_LABEL)]
	var count: int = mini(seq.audio_tracks.size(), Censor.SNAP_FROM_TRACKS) if seq != null else 0
	var current: String = Censor.snap_from()
	for i: int in count:
		out.append(PmDrop.choice("A" + str(i + 1), Censor.snap_from_label(seq, "A" + str(i + 1))))
	if current != Censor.SNAP_FROM_CLIP and (Censor.snap_track(seq, current) == null):
		out.append(PmDrop.choice(current, current))
	return out


func _switch(flow: Container, text: String, tip: String, key: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.focus_mode = Control.FOCUS_NONE
	box.toggled.connect(_on_switch.bind(key))
	PmUI.tip(box, tip)
	flow.add_child(box)
	return box


func _on_switch(on: bool, key: String) -> void:
	if _syncing:
		return
	Censor.set_pref(key, on)


func _pair(flow: Container, label: String, control: Control, tip: String) -> Control:
	var box: HBoxContainer = PmUI.hbox(Tk.px(Tk.sz("gap")))
	var l: Label = PmLabel.dim(label)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(l)
	box.add_child(control)
	PmUI.tip(l, tip)
	PmUI.tip(control, tip)
	flow.add_child(box)
	return box


func _field_signals(f: Control, key: String) -> void:
	f.connect("value_changed", _on_number.bind(key))
	f.connect("edit_begun", _on_edit_begun.bind(key))
	f.connect("edit_ended", _on_edit_ended.bind(key, f))


func sync() -> void:
	if sound_drop == null:
		return
	_syncing = true
	var doc: Project = Session.doc
	var custom: String = String(Censor.pref(Censor.PREF_CUSTOM))
	var file_label: String = ""
	if not custom.is_empty() and Censor.custom_sound(doc, custom).begins_with("file:"):
		file_label = custom.get_file()
	sound_drop.call("set_choices", sound_choices(doc, "file" if not file_label.is_empty() else "", file_label))
	sound_drop.call("set_value", pref_sound_value(doc), false)
	if not bool(_dragging.get(Censor.PREF_VOLUME, false)):
		volume_field.set("value", float(Censor.pref(Censor.PREF_VOLUME)))
		volume_field.queue_redraw()
	if not bool(_dragging.get(Censor.PREF_DUCK, false)):
		duck_field.set("value", float(Censor.pref(Censor.PREF_DUCK)))
		duck_field.queue_redraw()
	if not bool(_dragging.get(Censor.PREF_FADE, false)):
		fade_field.set("value", float(Censor.pref(Censor.PREF_FADE)))
		fade_field.queue_redraw()
	var cut: String = Censor.pick(String(Censor.pref(Censor.PREF_CUT)), Censor.CUTS, "mute")
	cut_drop.call("set_value", cut, false)
	duck_box.visible = cut == "duck"
	fade_box.visible = cut == "fade"
	fit_drop.call("set_value", Censor.pick(String(Censor.pref(Censor.PREF_FIT)), Censor.FITS, "cut"), false)
	snap_timeline_box.set_pressed_no_signal(Censor.snaps_timeline())
	snap_sound_box.set_pressed_no_signal(Censor.snaps_sound())
	snap_from_drop.call("set_choices", snap_from_choices(Session.seq()))
	snap_from_drop.call("set_value", Censor.snap_from(), false)
	snap_from_drop.disabled = not Censor.snaps_sound()
	overlap_box.set_pressed_no_signal(Censor.overlap_allowed())
	_syncing = false


func _on_tool(tool_id: String) -> void:
	var on: bool = tool_id == Censor.TOOL_ID
	if on:
		sync()
	if on != visible:
		PmUI.set_shown(self, on)


func _on_pref(key: String) -> void:
	if key.begins_with("censor.") and not _syncing:
		sync()


func _on_sound(id: String) -> void:
	if _syncing:
		return
	var doc: Project = Session.doc
	if id == "choose":
		sync()
		choose_file(self, _on_file_chosen)
		return
	if id == "file":
		Censor.set_pref(Censor.PREF_SOUND, "custom")
		return
	if id.begins_with("media:"):
		var m: MediaItem = doc.media_by_id(id.substr(6)) if doc != null else null
		if m != null:
			Censor.set_pref(Censor.PREF_CUSTOM, m.path)
			Censor.set_pref(Censor.PREF_SOUND, "custom")
		return
	Censor.set_pref(Censor.PREF_SOUND, id)


func _on_file_chosen(path: String) -> void:
	if path.is_empty():
		return
	Censor.set_pref(Censor.PREF_CUSTOM, path)
	Censor.set_pref(Censor.PREF_SOUND, "custom")


func _on_choice(id: String, key: String) -> void:
	if _syncing:
		return
	Censor.set_pref(key, id)


func _on_number(v: float, key: String) -> void:
	if _syncing or bool(_dragging.get(key, false)):
		return
	Censor.set_pref(key, v)


func _on_edit_begun(key: String) -> void:
	_dragging[key] = true


func _on_edit_ended(key: String, f: Control) -> void:
	_dragging[key] = false
	Censor.set_pref(key, float(f.get("value")))


func _on_overlap(on: bool) -> void:
	if _syncing:
		return
	Censor.set_pref(Censor.PREF_OVERLAP, on)


func _on_in_out() -> void:
	Cmd.run("seq.censor_in_out")

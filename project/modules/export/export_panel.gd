extends "res://host/interfaces/i_panel.gd"

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmFold := preload("res://ui/kit/pm_fold.gd")
const PmTabs := preload("res://ui/kit/pm_tabs.gd")
const ExportPresets := preload("res://modules/export/export_presets.gd")
const ExportProbe := preload("res://modules/export/export_probe.gd")
const Places := preload("res://modules/export/export_places.gd")
const ExportJob := preload("res://modules/export/export_job.gd")
const MarkerTagsKit := preload("res://doc/marker_tags.gd")
const ClipCut := preload("res://modules/export/clipcut_panel.gd")
const ThumbPicker := preload("res://modules/export/thumbnail_picker.gd")
const ViewFold := preload("res://modules/export/view_export_fold.gd")
const ViewExport := preload("res://modules/export/view_export.gd")
const ExportSequences := preload("res://modules/export/export_sequences.gd")
const ExportQueueState := preload("res://modules/export/export_queue_state.gd")
const AudioVisualiser := preload("res://modules/export/audio_visualiser.gd")
const Sequence := preload("res://doc/sequence.gd")
const Project := preload("res://doc/project.gd")
const PANEL_ID := "export"
const LABEL_W := 118.0

var settings: Dictionary = ExportPresets.default_settings()
var clipcut: RefCounted = ClipCut.new()
var _root: Control = null
var _tabs: Control = null
var _pages: Dictionary = {}
var _controls: Dictionary = {}
var _rows: Dictionary = {}
var _encoders: Array[Dictionary] = []
var _containers: Array[Dictionary] = []
var _estimate: Label = null
var _plan: Label = null
var _warnings: Label = null
var _preview: TextureRect = null
var _picker: Control = null
var _progress: ProgressBar = null
var _progress_label: Label = null
var _progress_row: Control = null
var _queue_box: VBoxContainer = null
var _export_button: Button = null
var _queue: Array[Dictionary] = []
var _running: Dictionary = {}
var _job: Node = null
var _focused: bool = false
var _preset_row: HFlowContainer = null
var _alpha_note: Label = null
var _max_quality_note: Label = null
var _parts_label: Label = null
var _parts_box: VBoxContainer = null
var _tags_label: Label = null
var _tags_button: Button = null
var _passes_box: VBoxContainer = null
var _measure_button: Button = null
var _measured: Dictionary = {}
var _measuring: bool = false
var _watched_doc: RefCounted = null
var view_fold: RefCounted = ViewFold.new()


func id() -> String:
	return PANEL_ID


func title() -> String:
	return "Export"


func scope() -> String:
	return "global"


func save_state() -> Dictionary:
	var out: Dictionary = {"settings": settings.duplicate(true), "clipcut": clipcut.settings.duplicate(true)}
	out[ExportQueueState.STATE_KEY] = ExportQueueState.save(_queue, _running, _doc())
	return out


func restore_state(d: Dictionary) -> void:
	if d.get("settings") is Dictionary:
		settings = ExportPresets.normalise(d["settings"])
	if d.get("clipcut") is Dictionary:
		for k: Variant in (d["clipcut"] as Dictionary).keys():
			clipcut.settings[k] = d["clipcut"][k]
	_queue = ExportQueueState.restore(d.get(ExportQueueState.STATE_KEY, null))
	var note: String = ExportQueueState.restore_note(_queue, _doc())
	var ev: Node = _events()
	if ev != null and not note.is_empty():
		ev.info(note)
	_rebuild_queue_rows()
	if _root != null:
		_refresh()


func on_focus(has: bool) -> void:
	_focused = has


func handle_key(_e: InputEventKey) -> bool:
	return false


func _session() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Session")
	return null


func _bridge() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("PurrBridge")
	return null


func _events() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Events")
	return null


func _seq() -> Sequence:
	var s: Node = _session()
	if s == null:
		return null
	return s.call("seq")


func _doc() -> Project:
	var s: Node = _session()
	if s == null:
		return null
	return s.get("doc")


func _pick_seq() -> Sequence:
	var c: Dictionary = ExportSequences.panel_choice(settings)
	if String(c["mode"]) != ExportSequences.MODE_ONE:
		return _seq()
	var d: Project = _doc()
	var one: Sequence = d.sequence_by_id(String(c["id"])) if d != null else null
	return one if one != null else _seq()


func _seq_of(entry: Dictionary) -> Sequence:
	return ExportSequences.sequence_of(entry, _doc(), _seq())


func _label_col(text: String) -> Label:
	var l: Label = PmLabel.dim(text)
	l.custom_minimum_size.x = float(Tk.px(LABEL_W))
	return l


func _row(parent: Control, key: String, label: String) -> HBoxContainer:
	var row: HBoxContainer = PmUI.hbox()
	row.add_child(_label_col(label))
	parent.add_child(row)
	_rows[key] = row
	return row


func _dropdown(parent: Control, key: String, label: String, on_pick: Callable) -> Button:
	var row: HBoxContainer = _row(parent, key, label)
	var b: Button = PmButton.make("")
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.set("elide", true)
	b.pressed.connect(_open_dropdown.bind(key, b, on_pick))
	row.add_child(b)
	_controls[key] = b
	return b


func _choices_for(key: String) -> Array:
	var out: Array = []
	if key == "sequence":
		return ExportSequences.choices(_doc(), _seq())
	if key == "range":
		return ExportPresets.RANGE_CHOICES
	if key == "tag_mode":
		return ExportPresets.TAG_MODE_CHOICES
	if key == "container":
		for c: Dictionary in _containers:
			out.append([String(c["id"]), String(c["label"])])
		return out
	if key == "video_codec":
		var container: Dictionary = ExportPresets.container_by_id(_containers, String(settings["container"]))
		for e: Dictionary in ExportPresets.encoders_for_container(_encoders, container):
			out.append([String(e["id"]), String(e["label"]) + (" (hardware)" if bool(e.get("hw", false)) else "")])
		return out
	if key == "size":
		for p: Array in ExportPresets.SIZE_PRESETS:
			out.append([String(p[0]), String(p[1])])
		return out
	if key == "fps":
		for p: Array in ExportPresets.FPS_PRESETS:
			out.append([String(p[0]), String(p[1])])
		return out
	if key == "rate_mode":
		return ExportPresets.RATE_CHOICES
	if key == "prefer":
		return ExportPresets.PREFER_CHOICES
	if key == "audio_codec":
		var container2: Dictionary = ExportPresets.container_by_id(_containers, String(settings["container"]))
		for a: Variant in container2.get("audio_codecs", []):
			out.append([String(a), String(a)])
		return out
	if key == "sample_rate":
		for r: int in ExportPresets.AUDIO_RATES:
			out.append([str(r), str(r) + " Hz"])
		return out
	if key == "channels":
		return [["1", "Mono"], ["2", "Stereo"]]
	if key == "audio_layout":
		return [["mix", "Everything mixed together"], ["tracks", "One stream per audio track"], ["custom", "Custom groups"]]
	if key == "audio_bitrate":
		for b: int in ExportPresets.AUDIO_BITRATES:
			out.append([str(b), str(b) + " kbit/s"])
		return out
	if key == "thumb_source":
		return ExportPresets.THUMB_CHOICES
	if key == "place":
		for pl: Dictionary in Places.list():
			out.append([String(pl["id"]), String(pl["name"]), String(pl["dir"])])
		out.append(["__folder", "This folder only..."])
		out.append(["__manage", "Manage places..."])
		return out
	if key == "place_colour":
		for c: Array in Places.COLOURS:
			out.append([String(c[0]), String(c[1])])
		return out
	if key == "place_border":
		for b: String in Places.BORDERS:
			out.append([b, b.capitalize()])
		return out
	return out


func _open_dropdown(key: String, anchor: Button, on_pick: Callable) -> void:
	var items: Array = []
	for c: Array in _choices_for(key):
		items.append(PmMenu.item(String(c[0]), String(c[1]), String(c[2]) if c.size() > 2 else ""))
	if items.is_empty():
		items.append(PmMenu.item("none", "Nothing available"))
	var menu: Control = PmMenu.open(anchor, items)
	menu.connect("picked", on_pick)


func _label_of(key: String, id: String) -> String:
	for c: Array in _choices_for(key):
		if String(c[0]) == id:
			return String(c[1])
	return id


func _field(parent: Control, key: String, label: String, value: float, min_v: float, max_v: float, step: float, suffix: String, on_change: Callable) -> Control:
	var row: HBoxContainer = _row(parent, key, label)
	var f: Control = PmField.make(value, min_v, max_v, step, suffix)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.connect("value_changed", on_change)
	row.add_child(f)
	_controls[key] = f
	return f


func _check(parent: Control, key: String, label: String, on: bool, on_change: Callable) -> CheckBox:
	var row: HBoxContainer = _row(parent, key, label)
	var cb := CheckBox.new()
	cb.button_pressed = on
	cb.focus_mode = Control.FOCUS_NONE
	cb.toggled.connect(on_change)
	row.add_child(cb)
	_controls[key] = cb
	return cb


func _text(parent: Control, key: String, label: String, value: String, placeholder: String, on_change: Callable) -> LineEdit:
	var row: HBoxContainer = _row(parent, key, label)
	var le: LineEdit = PmUI.line_edit(placeholder, value)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(on_change)
	row.add_child(le)
	_controls[key] = le
	return le


func _fold(parent: Control, title_: String, key: String) -> VBoxContainer:
	var f: VBoxContainer = PmFold.make(title_, "export." + key, true)
	var style: GDScript = load("res://modules/core_panels/section_style.gd")
	if style != null:
		parent.add_child(style.call("wrap", f, null))
	else:
		parent.add_child(f)
	return f.get("body")


func build(parent: Control) -> Control:
	_encoders = ExportPresets.encoders_available(_bridge())
	_containers = ExportPresets.containers_available(_bridge())
	_root = PmUI.vbox()
	_root.name = "ExportPanel"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fill: ColorRect = PmUI.fill("bg_panel")
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(fill)
	_tabs = PmTabs.make(false)
	_tabs.call("add_tab", "export", "Export")
	_tabs.call("add_tab", "clipcut", "Clip cut")
	_tabs.custom_minimum_size.y = float(Tk.px(Tk.sz("tab_h")))
	_tabs.connect("tab_changed", _on_tab)
	_root.add_child(_tabs)
	var export_page: Control = _build_export_page()
	export_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(export_page)
	_pages["export"] = export_page
	var cut_page: ScrollContainer = ScrollContainer.new()
	cut_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cut_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cut_holder: MarginContainer = MarginContainer.new()
	cut_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cut_holder.add_theme_constant_override("margin_left", Tk.px(Tk.sz("pad")))
	cut_holder.add_theme_constant_override("margin_right", Tk.px(Tk.sz("pad")))
	cut_page.add_child(cut_holder)
	clipcut.call("build", cut_holder)
	cut_page.visible = false
	_root.add_child(cut_page)
	_pages["clipcut"] = cut_page
	parent.add_child(_root)
	var s: Node = _session()
	if s != null:
		if not s.is_connected("project_changed", _on_project_changed):
			s.connect("project_changed", _on_project_changed)
		if not s.is_connected("sequence_changed", _on_sequence_changed):
			s.connect("sequence_changed", _on_sequence_changed)
		if not s.is_connected("compositor_changed", _on_compositor_changed):
			s.connect("compositor_changed", _on_compositor_changed)
	_on_project_changed()
	_refresh()
	return _root


func _build_export_page() -> Control:
	var page: VBoxContainer = PmUI.vbox()
	_preset_row = HFlowContainer.new()
	_preset_row.add_theme_constant_override("h_separation", Tk.px(Tk.sz("gap")))
	_preset_row.add_theme_constant_override("v_separation", Tk.px(Tk.sz("gap")))
	page.add_child(PmUI.inset(_preset_row, 4.0, 0.0))
	_build_preset_chips()
	var split: HBoxContainer = PmUI.hbox()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(split)
	var scroll: ScrollContainer = (load("res://ui/kit/pm_scroll_keep.gd") as GDScript).new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 3.0
	split.add_child(scroll)
	var groups: VBoxContainer = PmUI.vbox()
	groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(groups)
	_build_groups(groups)
	var right: VBoxContainer = PmUI.vbox()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 2.0
	right.custom_minimum_size.x = float(Tk.px(200.0))
	split.add_child(PmUI.inset(right))
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.custom_minimum_size = Vector2(float(Tk.px(200.0)), float(Tk.px(112.0)))
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_preview)
	_estimate = PmLabel.wrap("")
	right.add_child(_estimate)
	_plan = PmLabel.wrap("", "text_dim")
	right.add_child(_plan)
	_warnings = PmLabel.wrap("", "text_dim")
	right.add_child(_warnings)
	var buttons: HFlowContainer = HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", Tk.px(Tk.sz("gap")))
	var queue_b: Button = PmButton.make("Add to queue")
	queue_b.pressed.connect(_on_add_to_queue)
	buttons.add_child(queue_b)
	_export_button = PmButton.primary("Export now")
	_export_button.pressed.connect(_on_export_now)
	buttons.add_child(_export_button)
	var save_b: Button = PmButton.make("Save preset")
	save_b.pressed.connect(_on_save_preset)
	buttons.add_child(save_b)
	_measure_button = PmButton.make("Check size")
	PmUI.tip(_measure_button, "Encodes about a second of the real footage from three places in the range and measures it, instead of guessing from the quality number. Takes a moment and writes nothing but a temporary file.")
	_measure_button.pressed.connect(_on_measure_size)
	buttons.add_child(_measure_button)
	right.add_child(buttons)
	_progress_row = PmUI.vbox()
	AudioVisualiser.attach(_progress_row)
	_progress_label = PmLabel.small("")
	_progress_row.add_child(_progress_label)
	var prow: HBoxContainer = PmUI.hbox()
	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.custom_minimum_size.y = float(Tk.px(Tk.sz("field_h")))
	prow.add_child(_progress)
	var cancel: Button = PmButton.make("Cancel")
	cancel.pressed.connect(_on_cancel)
	prow.add_child(cancel)
	_progress_row.add_child(prow)
	_progress_row.visible = false
	right.add_child(_progress_row)
	right.add_child(PmLabel.dim("Queue"))
	_queue_box = PmUI.vbox()
	right.add_child(_queue_box)
	return page


func _build_preset_chips() -> void:
	PmUI.clear(_preset_row)
	for l: Dictionary in ExportPresets.lossless_presets(_encoders, _containers):
		var lb: Button = PmButton.make(String(l["label"]))
		PmUI.tip(lb, _lossless_tip(String(l["id"])))
		lb.pressed.connect(_on_lossless.bind(String(l["id"])))
		_preset_row.add_child(lb)
	for d: Dictionary in ExportPresets.destinations():
		var b: Button = PmButton.make(String(d["label"]))
		b.set("quiet", true)
		b.pressed.connect(_on_destination.bind(String(d["id"])))
		_preset_row.add_child(b)
	for p: Dictionary in ExportPresets.list_user_presets():
		var ub: Button = PmButton.make(String(p["label"]))
		ub.pressed.connect(_on_user_preset.bind(p))
		_preset_row.add_child(ub)


func _build_groups(groups: VBoxContainer) -> void:
	var src: VBoxContainer = _fold(groups, "Source and range", "range")
	var seq_pick: Button = _dropdown(src, "sequence", "Sequence", _on_sequence_pick)
	PmUI.tip(seq_pick, "Which sequence is exported. The one on screen by default, or a named one, or every sequence in the project as one file each. The sequence is remembered by each queued job, so switching sequence after queueing does not change what is written.")
	_dropdown(src, "range", "Range", _on_range)
	var parts_row: HBoxContainer = _row(src, "parts", "Parts")
	_parts_label = PmLabel.wrap("", "text_dim")
	_parts_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts_row.add_child(_parts_label)
	var add_part: Button = PmButton.make("Add in to out")
	PmUI.tip(add_part, "Add what is between the in and out points on the timeline as one part. Set in and out again and press this to add another. Parts that touch are joined.")
	add_part.pressed.connect(_on_add_part)
	parts_row.add_child(add_part)
	var clear_parts: Button = PmButton.make("Clear")
	PmUI.tip(clear_parts, "Forget the parts that were picked. The range goes back to the whole sequence.")
	clear_parts.pressed.connect(_on_clear_parts)
	parts_row.add_child(clear_parts)
	_parts_box = PmUI.vbox(0)
	_parts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	src.add_child(_parts_box)
	var tags_row: HBoxContainer = _row(src, "tags", "Tags")
	_tags_label = PmLabel.wrap("", "text_dim")
	_tags_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tags_row.add_child(_tags_label)
	_tags_button = PmButton.make("Pick tags", "chev_d")
	PmUI.tip(_tags_button, "Which tag names are exported. With none ticked, every tag is.")
	_tags_button.pressed.connect(_on_pick_tags)
	tags_row.add_child(_tags_button)
	var tag_mode: Button = _dropdown(src, "tag_mode", "Tagged ranges", _on_tag_mode)
	PmUI.tip(tag_mode, "Stitched writes every tagged range into one file in time order. One file per tagged range names each file after its tag and its number.")
	view_fold.call("build", groups, self)
	var fmt: VBoxContainer = _fold(groups, "Format", "format")
	var mq: CheckBox = _check(fmt, "max_quality", "Exactly as viewed", bool(settings.get("max_quality", false)), _on_max_quality)
	PmUI.tip(mq, "One switch for no quality loss: the sequence size and frame rate, nothing resampled, and the picture and sound written losslessly where the format can. Size, frame rate and quality are set for you while it is on.")
	var mq_row: HBoxContainer = _row(fmt, "max_quality_note", "")
	_max_quality_note = PmLabel.wrap("", "text_dim")
	_max_quality_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mq_row.add_child(_max_quality_note)
	_dropdown(fmt, "container", "Container", _on_container)
	_dropdown(fmt, "video_codec", "Video codec", _on_video_codec)
	var vid: VBoxContainer = _fold(groups, "Video", "video")
	_dropdown(vid, "size", "Size", _on_size)
	_field(vid, "width", "Width", float(settings["size"]["width"]), 2.0, 16384.0, 2.0, " px", _on_width)
	_field(vid, "height", "Height", float(settings["size"]["height"]), 2.0, 16384.0, 2.0, " px", _on_height)
	_check(vid, "lock_aspect", "Lock aspect", bool(settings["size"]["lock_aspect"]), _on_lock_aspect)
	_dropdown(vid, "fps", "Frame rate", _on_fps)
	_field(vid, "fps_custom", "Custom fps", float(settings["fps"]["custom"]), 1.0, 240.0, 0.001, "", _on_fps_custom)
	var tcb: CheckBox = _check(vid, "transparent", "Transparent background", bool(settings.get("transparent", false)), _on_transparent)
	PmUI.tip(tcb, "The parts of the frame no clip covers stay see-through in the file, and the backdrop is not drawn. Needs PNG sequence, MOV ProRes 4444, MOV PNG, WebM VP9, MKV FFV1 or GIF.")
	var note_row: HBoxContainer = _row(vid, "transparent_note", "")
	_alpha_note = PmLabel.wrap("", "text_dim")
	_alpha_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_row.add_child(_alpha_note)
	var rate: VBoxContainer = _fold(groups, "Rate control", "rate")
	_dropdown(rate, "rate_mode", "Mode", _on_rate_mode)
	_field(rate, "crf", "Quality (CRF)", float(settings["rate_control"]["crf"]), 0.0, 51.0, 1.0, "", _on_crf)
	_field(rate, "bitrate", "Bitrate", float(settings["rate_control"]["bitrate_kbps"]), 50.0, 400000.0, 100.0, " kbit/s", _on_bitrate)
	_field(rate, "max_kbps", "Max bitrate", float(settings["rate_control"]["max_kbps"]), 0.0, 400000.0, 100.0, " kbit/s", _on_max_kbps)
	_field(rate, "target_mb", "Target size", float(settings["rate_control"]["target_mb"]), 0.1, 100000.0, 0.5, " MB", _on_target_mb)
	_dropdown(rate, "prefer", "Prefer", _on_prefer)
	var aud: VBoxContainer = _fold(groups, "Audio", "audio")
	_check(aud, "audio_enabled", "Include audio", bool(settings["audio"]["enabled"]), _on_audio_enabled)
	_dropdown(aud, "audio_codec", "Audio codec", _on_audio_codec)
	_dropdown(aud, "audio_bitrate", "Bitrate", _on_audio_bitrate)
	_dropdown(aud, "sample_rate", "Sample rate", _on_sample_rate)
	_dropdown(aud, "channels", "Channels", _on_channels)
	_dropdown(aud, "audio_layout", "Streams", _on_audio_layout)
	var gt: LineEdit = _text(aud, "audio_groups", "Groups", String(settings["audio"].get("groups", "")), "A1+A2, A3", _on_audio_groups)
	PmUI.tip(gt, "One output stream per group, tracks joined with +, groups split by commas. Empty groups use every track.")
	var thumb: VBoxContainer = _fold(groups, "Thumbnail", "thumb")
	_dropdown(thumb, "thumb_source", "Frame", _on_thumb_source)
	_picker = ThumbPicker.make()
	_picker.connect("time_changed", _on_thumb_time)
	var prow: HBoxContainer = _row(thumb, "thumb_pick", "Pick")
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prow.add_child(_picker)
	_check(thumb, "thumb_embed", "Embed as cover art", bool(settings["thumbnail"]["embed"]), _on_thumb_embed)
	_check(thumb, "thumb_sidecar", "Write a PNG beside the file", bool(settings["thumbnail"]["sidecar"]), _on_thumb_sidecar)
	var meta: VBoxContainer = _fold(groups, "Metadata", "meta")
	_text(meta, "title", "Title", String(settings["metadata"]["title"]), "", _on_title)
	_text(meta, "comment", "Comment", String(settings["metadata"]["comment"]), "", _on_comment)
	_check(meta, "chapters", "Chapters from markers", bool(settings["chapters_from_markers"]), _on_chapters)
	_check(meta, "captions_sidecar", "Write captions beside the file (.srt)", bool(settings.get("captions", {}).get("sidecar", false)), _on_captions_sidecar)
	var copy_ch: Button = PmButton.make("Copy YouTube chapters")
	copy_ch.set("quiet", true)
	copy_ch.name = "CopyYoutubeChapters"
	PmUI.tip(copy_ch, "Copies the chapter markers inside this export's range as a list you can paste straight into a YouTube description. Times count from the start of the exported file, and anything YouTube would reject is fixed in the copy, never in your markers.")
	copy_ch.pressed.connect(_on_copy_youtube)
	((_controls["chapters"] as Control).get_parent() as Control).add_child(copy_ch)
	var interp: VBoxContainer = _fold(groups, "Interpolation", "interp")
	var icb: CheckBox = _check(interp, "interpolation", "Purrframes", false, _on_interpolation)
	icb.disabled = true
	PmUI.tip(icb, "Frame interpolation arrives in stage 3")
	var passes: VBoxContainer = _fold(groups, "Passes", "passes")
	_passes_box = PmUI.vbox(0)
	_passes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	passes.add_child(_passes_box)
	var pass_buttons: HBoxContainer = PmUI.hbox()
	var add_pass: Button = PmButton.make("Add a pass")
	PmUI.tip(add_pass, "A pass is one more file: its own parts and its own changed settings, run after the ones above it. Anything a pass does not change comes from the settings here.")
	add_pass.pressed.connect(_on_add_pass)
	pass_buttons.add_child(add_pass)
	var use_picked: Button = PmButton.make("Use what is picked")
	PmUI.tip(use_picked, "Give the last pass the parts currently picked on the timeline.")
	use_picked.pressed.connect(_on_pass_use_picked)
	pass_buttons.add_child(use_picked)
	passes.add_child(pass_buttons)
	var dest: VBoxContainer = _fold(groups, "Destination", "dest")
	_dropdown(dest, "place", "Where", _on_place)
	_text(dest, "dest_dir", "Folder", String(settings["destination"]["dir"]), "Movies folder", _on_dest_dir)
	_text(dest, "dest_name", "File name", String(settings["destination"]["name"]), _default_name_hint(), _on_dest_name)


func _on_tab(id: String) -> void:
	for k: Variant in _pages.keys():
		(_pages[k] as Control).visible = String(k) == id


func _on_project_changed() -> void:
	var s: Node = _session()
	if s != null:
		clipcut.call("attach", s.get("doc"), _seq())
		var d: RefCounted = s.get("doc")
		if _watched_doc != d:
			if _watched_doc != null and is_instance_valid(_watched_doc) and _watched_doc.is_connected("changed", _on_doc_changed):
				_watched_doc.disconnect("changed", _on_doc_changed)
			_watched_doc = d
			if d != null and d.has_signal("changed") and not d.is_connected("changed", _on_doc_changed):
				d.connect("changed", _on_doc_changed)
	_on_compositor_changed()
	_refresh()


func _on_sequence_changed(_id: String) -> void:
	_on_project_changed()


func _on_compositor_changed() -> void:
	var s: Node = _session()
	if s == null or _preview == null:
		return
	var comp: Node = s.get("compositor")
	if comp != null and comp.has_method("texture"):
		_preview.texture = comp.call("texture")
		if _picker != null:
			_picker.call("set_preview", _preview.texture)
	else:
		_preview.texture = null


func _put(key: String, value: Variant) -> void:
	var parts: PackedStringArray = key.split(".")
	if parts.size() == 1:
		settings[key] = value
	else:
		if not (settings.get(parts[0]) is Dictionary):
			settings[parts[0]] = {}
		var d: Dictionary = settings[parts[0]]
		d[parts[1]] = value
	_update_estimate()


func _on_sequence_pick(v: String) -> void:
	ExportSequences.set_pick(settings, v)
	_refresh()


func _on_range(v: String) -> void:
	_put("range", v)
	_refresh()


func _on_tag_mode(v: String) -> void:
	ExportPresets.set_tags(settings, ExportPresets.tag_names(settings), v)
	_refresh()


func _on_pick_tags() -> void:
	var picked: PackedStringArray = ExportPresets.tag_names(settings)
	var items: Array = [PmMenu.check_item("*every", "Every tag", picked.is_empty()), PmMenu.separator()]
	for n: String in MarkerTagsKit.names(_pick_seq()):
		items.append(PmMenu.check_item("t:" + n, n, picked.has(n)))
	var menu: Control = PmMenu.open(_tags_button, items)
	menu.connect("picked", _on_tag_picked)


func _on_tag_picked(id: String) -> void:
	toggle_tag(id.substr(2) if id.begins_with("t:") else "")


func toggle_tag(name: String) -> void:
	var picked: PackedStringArray = ExportPresets.tag_names(settings)
	if name.is_empty():
		picked = PackedStringArray()
	elif picked.has(name):
		picked.remove_at(picked.find(name))
	else:
		picked.append(name)
	ExportPresets.set_tags(settings, picked, ExportPresets.tag_mode(settings))
	_refresh()


func _on_container(v: String) -> void:
	_put("container", v)
	_ensure_codecs()
	_refresh()


func _ensure_codecs() -> void:
	var container: Dictionary = ExportPresets.container_by_id(_containers, String(settings["container"]))
	if container.is_empty():
		return
	if not ExportPresets.is_audio_only(container):
		var encs: Array[Dictionary] = ExportPresets.encoders_for_container(_encoders, container)
		var current: String = String(settings["video_codec"])
		var ok: bool = false
		for e: Dictionary in encs:
			if String(e["id"]) == current:
				ok = true
		if not ok:
			settings["video_codec"] = ExportPresets.nearest_encoder(_encoders, encs, current)
	var acodecs: Array = container.get("audio_codecs", [])
	if not acodecs.has(String(settings["audio"]["codec"])):
		settings["audio"]["codec"] = String(acodecs[0]) if not acodecs.is_empty() else ""


func _on_video_codec(v: String) -> void:
	_put("video_codec", v)
	_refresh()


func _on_size(v: String) -> void:
	_put("size.preset", v)
	for p: Array in ExportPresets.SIZE_PRESETS:
		if String(p[0]) == v and int(p[2]) > 0:
			settings["size"]["width"] = int(p[2])
			settings["size"]["height"] = int(p[3])
	if v == "sequence":
		var sq: Sequence = _pick_seq()
		if sq != null:
			settings["size"]["width"] = sq.width
			settings["size"]["height"] = sq.height
	_refresh()


func _aspect() -> float:
	var sq: Sequence = _pick_seq()
	if sq != null and sq.height > 0:
		return float(sq.width) / float(sq.height)
	return 16.0 / 9.0


func _on_width(v: float) -> void:
	settings["size"]["preset"] = "custom"
	settings["size"]["width"] = ExportPresets.even_dim(v)
	if bool(settings["size"]["lock_aspect"]):
		settings["size"]["height"] = ExportPresets.even_dim(v / _aspect())
	_update_estimate()
	_refresh()


func _on_height(v: float) -> void:
	settings["size"]["preset"] = "custom"
	settings["size"]["height"] = ExportPresets.even_dim(v)
	if bool(settings["size"]["lock_aspect"]):
		settings["size"]["width"] = ExportPresets.even_dim(v * _aspect())
	_update_estimate()
	_refresh()


func _on_lock_aspect(on: bool) -> void:
	_put("size.lock_aspect", on)


func _on_fps(v: String) -> void:
	_put("fps.mode", v)
	_refresh()


func _on_fps_custom(v: float) -> void:
	settings["fps"]["mode"] = "custom"
	_put("fps.custom", v)
	_refresh()


func _on_rate_mode(v: String) -> void:
	_put("rate_control.mode", v)
	_refresh()


func _on_crf(v: float) -> void:
	_put("rate_control.crf", int(v))


func _on_bitrate(v: float) -> void:
	_put("rate_control.bitrate_kbps", int(v))


func _on_max_kbps(v: float) -> void:
	_put("rate_control.max_kbps", int(v))


func _on_target_mb(v: float) -> void:
	_put("rate_control.target_mb", v)


func _on_prefer(v: String) -> void:
	_put("rate_control.prefer", v)
	_refresh()


func _on_audio_enabled(on: bool) -> void:
	_put("audio.enabled", on)
	_refresh()


func _on_audio_codec(v: String) -> void:
	_put("audio.codec", v)
	_refresh()


func _on_audio_bitrate(v: String) -> void:
	_put("audio.bitrate_kbps", int(v))
	_refresh()


func _on_sample_rate(v: String) -> void:
	_put("audio.sample_rate", int(v))
	_refresh()


func _on_channels(v: String) -> void:
	_put("audio.channels", int(v))
	_refresh()


func _on_audio_layout(v: String) -> void:
	_put("audio.layout", v)
	_refresh()


func _on_audio_groups(t: String) -> void:
	settings["audio"]["groups"] = t


func _on_thumb_source(v: String) -> void:
	_put("thumbnail.source", v)
	_refresh()


func _on_thumb_time(t: float) -> void:
	settings["thumbnail"]["time"] = t
	var s: Node = _session()
	if s != null and (_job == null or not is_instance_valid(_job)):
		var comp: Node = s.get("compositor")
		if comp != null and comp.has_method("render_time"):
			comp.call("render_time", t, false)


func _on_thumb_embed(on: bool) -> void:
	_put("thumbnail.embed", on)


func _on_captions_sidecar(on: bool) -> void:
	_put("captions.sidecar", on)


func _on_thumb_sidecar(on: bool) -> void:
	_put("thumbnail.sidecar", on)


func _on_title(t: String) -> void:
	settings["metadata"]["title"] = t


func _on_comment(t: String) -> void:
	settings["metadata"]["comment"] = t


func _on_chapters(on: bool) -> void:
	_put("chapters_from_markers", on)
	_update_warnings()


func youtube_chapters() -> Array:
	var sq: Sequence = _pick_seq()
	if sq == null:
		return []
	var r: Vector2 = ExportPresets.resolve_range(settings, sq)
	return load("res://doc/commands/edit_tools.gd").call("chapter_list", sq, r.x, r.y)


func _on_copy_youtube() -> void:
	load("res://modules/core_panels/markers_panel.gd").call("copy_youtube", youtube_chapters(), " in the exported range")


func _on_transparent(on: bool) -> void:
	_put("transparent", on)
	_refresh()


func _on_max_quality(on: bool) -> void:
	_put("max_quality", on)
	_refresh()


func _refresh_max_quality() -> void:
	if _max_quality_note == null or not _rows.has("max_quality_note"):
		return
	var on: bool = bool(settings.get("max_quality", false))
	var note: String = ExportPresets.max_quality_note(settings, _containers)
	_max_quality_note.text = note
	(_rows["max_quality_note"] as Control).visible = on and not note.is_empty()
	for key: String in ["size", "width", "height", "fps", "fps_custom", "rate_mode", "crf", "bitrate", "max_kbps", "target_mb", "prefer"]:
		var c: Control = _controls.get(key, null)
		if c != null and "disabled" in c:
			c.set("disabled", on)


func export_caps() -> Dictionary:
	var b: Node = _bridge()
	if b == null or not b.has_method("export_caps"):
		return {"known": false, "alpha": false, "alpha_codecs": PackedStringArray()}
	return b.call("export_caps")


func alpha_status() -> Dictionary:
	return ExportPresets.alpha_status(export_caps(), String(settings["container"]), String(settings["video_codec"]))


func chapter_warnings() -> PackedStringArray:
	var sq: Sequence = _pick_seq()
	if sq == null or not bool(settings.get("chapters_from_markers", true)):
		return PackedStringArray()
	return ExportPresets.chapter_problems(ExportPresets.chapters_from(sq, ExportPresets.resolve_range(settings, sq)))


func _refresh_alpha(audio_only: bool) -> void:
	var cb: CheckBox = _controls.get("transparent", null)
	if cb == null or _alpha_note == null:
		return
	var st: Dictionary = alpha_status()
	var ok: bool = bool(st.get("ok", false))
	cb.disabled = not ok
	cb.set_pressed_no_signal(ok and bool(settings.get("transparent", false)))
	(_rows["transparent"] as Control).visible = not audio_only
	var note: String = String(st.get("reason", ""))
	if ok and bool(settings.get("transparent", false)):
		note = "The empty parts of the frame stay see-through, and the backdrop is not drawn."
	_alpha_note.text = note
	(_rows["transparent_note"] as Control).visible = not audio_only and not note.is_empty()


func _on_doc_changed(kind: String) -> void:
	if kind == "markers" or kind == "structure":
		_update_warnings()
	if (kind == "structure" or kind == "meta" or kind == "markers") and _root != null and _root.is_visible_in_tree():
		view_fold.call("refresh", settings, _pick_seq())


func _on_interpolation(on: bool) -> void:
	settings["interpolation"] = on


func _on_dest_dir(t: String) -> void:
	settings["destination"]["dir"] = t


func _on_dest_name(t: String) -> void:
	settings["destination"]["name"] = t


func _on_destination(id: String) -> void:
	settings = ExportPresets.apply_destination(settings, id)
	_refresh()


func _lossless_tip(id: String) -> String:
	var sq: Sequence = _pick_seq()
	var w: int = sq.width if sq != null else 0
	var h: int = sq.height if sq != null else 0
	var fps: float = sq.fps if sq != null else 0.0
	var seconds: float = 0.0
	if sq != null:
		var range_v: Vector2 = ExportPresets.resolve_range(settings, sq)
		seconds = maxf(range_v.y - range_v.x, 0.0)
	return ExportPresets.lossless_note(id, w, h, fps, seconds)


func _on_lossless(id: String) -> void:
	settings = ExportPresets.apply_lossless(settings, id, _containers)
	_refresh()


func _on_user_preset(p: Dictionary) -> void:
	settings = ExportPresets.settings_of(p)
	_refresh()


func _on_save_preset() -> void:
	var answered: Signal = PmUI.form(_root, "Save export preset", [{"key": "label", "label": "Name", "type": "string", "default": "My export"}], "Save", "Cancel")
	var result: Variant = await answered
	if result is Dictionary and not (result as Dictionary).is_empty():
		var label: String = String((result as Dictionary).get("label", "")).strip_edges()
		if label.is_empty():
			return
		var keep: Dictionary = settings.duplicate(true)
		keep.erase(ExportSequences.PANEL_KEY)
		keep.erase(ExportSequences.JOB_KEY)
		if ExportPresets.save_user_preset(label, keep):
			var ev: Node = _events()
			if ev != null:
				ev.info("Export preset saved: " + label)
			_build_preset_chips()


func _refresh() -> void:
	if _root == null:
		return
	_ensure_codecs()
	var sq: Sequence = _pick_seq()
	if sq != null and String(settings["size"]["preset"]) == "sequence":
		settings["size"]["width"] = sq.width
		settings["size"]["height"] = sq.height
	var container: Dictionary = ExportPresets.container_by_id(_containers, String(settings["container"]))
	var audio_only: bool = not container.is_empty() and ExportPresets.is_audio_only(container)
	var has_audio_codecs: bool = not (container.get("audio_codecs", []) as Array).is_empty()
	var rc_mode: String = String(settings["rate_control"]["mode"])
	var doc_now: Project = _doc()
	(_controls["sequence"] as Button).text = ExportSequences.pick_label(settings, doc_now, _seq())
	(_rows["sequence"] as Control).visible = doc_now != null and doc_now.sequences.size() > 1
	(_controls["range"] as Button).text = _label_of("range", String(settings["range"]))
	(_controls["container"] as Button).text = _label_of("container", String(settings["container"]))
	(_controls["video_codec"] as Button).text = _label_of("video_codec", String(settings["video_codec"])) if not audio_only else "none (audio only)"
	(_controls["size"] as Button).text = _label_of("size", String(settings["size"]["preset"]))
	(_controls["width"] as Control).set("value", float(settings["size"]["width"]))
	(_controls["height"] as Control).set("value", float(settings["size"]["height"]))
	(_controls["lock_aspect"] as CheckBox).button_pressed = bool(settings["size"]["lock_aspect"])
	(_controls["fps"] as Button).text = _label_of("fps", String(settings["fps"]["mode"]))
	(_controls["fps_custom"] as Control).set("value", float(settings["fps"]["custom"]))
	(_controls["rate_mode"] as Button).text = _label_of("rate_mode", rc_mode)
	(_controls["crf"] as Control).set("value", float(settings["rate_control"]["crf"]))
	(_controls["bitrate"] as Control).set("value", float(settings["rate_control"]["bitrate_kbps"]))
	(_controls["max_kbps"] as Control).set("value", float(settings["rate_control"]["max_kbps"]))
	(_controls["target_mb"] as Control).set("value", float(settings["rate_control"]["target_mb"]))
	(_controls["prefer"] as Button).text = _label_of("prefer", String(settings["rate_control"]["prefer"]))
	(_controls["audio_enabled"] as CheckBox).button_pressed = bool(settings["audio"]["enabled"])
	(_controls["audio_codec"] as Button).text = String(settings["audio"]["codec"]) if has_audio_codecs else "none in this container"
	(_controls["audio_bitrate"] as Button).text = str(int(settings["audio"]["bitrate_kbps"])) + " kbit/s"
	(_controls["sample_rate"] as Button).text = str(int(settings["audio"]["sample_rate"])) + " Hz"
	(_controls["channels"] as Button).text = _label_of("channels", str(int(settings["audio"]["channels"])))
	(_controls["audio_layout"] as Button).text = _label_of("audio_layout", String(settings["audio"].get("layout", "mix")))
	(_controls["audio_groups"] as LineEdit).get_parent().visible = String(settings["audio"].get("layout", "mix")) == "custom"
	(_controls["audio_groups"] as LineEdit).text = String(settings["audio"].get("groups", ""))
	(_controls["thumb_source"] as Button).text = _label_of("thumb_source", String(settings["thumbnail"]["source"]))
	(_controls["thumb_embed"] as CheckBox).button_pressed = bool(settings["thumbnail"]["embed"])
	(_controls["thumb_sidecar"] as CheckBox).button_pressed = bool(settings["thumbnail"]["sidecar"])
	(_controls["chapters"] as CheckBox).button_pressed = bool(settings["chapters_from_markers"])
	_refresh_alpha(audio_only)
	(_controls["max_quality"] as CheckBox).button_pressed = bool(settings.get("max_quality", false))
	_refresh_max_quality()
	(_controls["title"] as LineEdit).text = String(settings["metadata"]["title"])
	(_controls["comment"] as LineEdit).text = String(settings["metadata"]["comment"])
	(_controls["dest_dir"] as LineEdit).text = String(settings["destination"]["dir"])
	(_controls["dest_name"] as LineEdit).text = String(settings["destination"]["name"])
	(_controls["dest_name"] as LineEdit).placeholder_text = _default_name_hint()
	(_controls["place"] as Button).text = _place_label()
	if _parts_label != null:
		_parts_label.text = ExportPresets.parts_summary(settings, _pick_seq())
		(_rows["parts"] as Control).visible = ExportPresets.spans_held(settings) or String(settings.get("range", "")) == ExportPresets.RANGE_PARTS
	if _tags_label != null:
		var tags_on: bool = String(settings.get("range", "")) == ExportPresets.RANGE_TAGS
		_tags_label.text = ExportPresets.tags_summary(settings, _pick_seq())
		(_rows["tags"] as Control).visible = tags_on
		(_rows["tag_mode"] as Control).visible = tags_on
		(_controls["tag_mode"] as Button).text = _label_of("tag_mode", ExportPresets.tag_mode(settings))
	_rebuild_parts()
	_rebuild_passes()
	if _export_button != null:
		var pid: String = Places.place_of(settings)
		_export_button.text = "Export now to " + _place_label() if not pid.is_empty() else "Export now"
	var custom_size: bool = String(settings["size"]["preset"]) == "custom"
	(_rows["width"] as Control).visible = custom_size and not audio_only
	(_rows["height"] as Control).visible = custom_size and not audio_only
	(_rows["lock_aspect"] as Control).visible = custom_size and not audio_only
	(_rows["fps_custom"] as Control).visible = String(settings["fps"]["mode"]) == "custom" and not audio_only
	(_rows["video_codec"] as Control).visible = not audio_only
	(_rows["size"] as Control).visible = not audio_only
	(_rows["fps"] as Control).visible = not audio_only
	(_rows["rate_mode"] as Control).visible = not audio_only
	(_rows["crf"] as Control).visible = rc_mode == "crf" and not audio_only
	(_rows["bitrate"] as Control).visible = rc_mode == "bitrate" and not audio_only
	(_rows["max_kbps"] as Control).visible = rc_mode == "bitrate" and not audio_only
	(_rows["target_mb"] as Control).visible = rc_mode == "size" and not audio_only
	(_rows["prefer"] as Control).visible = rc_mode == "size" and not audio_only
	var audio_on: bool = bool(settings["audio"]["enabled"]) and has_audio_codecs
	(_rows["audio_codec"] as Control).visible = has_audio_codecs
	(_rows["audio_bitrate"] as Control).visible = audio_on
	(_rows["sample_rate"] as Control).visible = audio_on
	(_rows["channels"] as Control).visible = audio_on
	(_rows["thumb_pick"] as Control).visible = String(settings["thumbnail"]["source"]) == "pick" and not audio_only
	(_rows["thumb_embed"] as Control).visible = not audio_only
	(_rows["thumb_sidecar"] as Control).visible = not audio_only
	if sq != null and _picker != null:
		var r: Vector2 = ExportPresets.resolve_range(settings, sq)
		_picker.call("set_range", r.x, r.y)
	_update_estimate()
	_update_warnings()
	view_fold.call("refresh", settings, sq)


func _settings_fingerprint() -> String:
	return JSON.stringify({"s": settings, "r": ExportPresets.resolve_range(settings, _pick_seq())})


func _update_estimate() -> void:
	if _estimate == null:
		return
	var est: Dictionary = ExportPresets.estimate(settings, _pick_seq(), _encoders, _containers)
	var text: String = String(est["text"])
	if _measuring:
		text = "Measuring, encoding a little of the real footage. " + text
	elif not _measured.is_empty() and String(_measured.get("for", "")) == _settings_fingerprint():
		text = String(_measured.get("text", "")) + "
" + text
	_estimate.text = text
	if _measure_button != null:
		_measure_button.disabled = _measuring or _pick_seq() == null


func _project_name() -> String:
	var s: Node = _session()
	var doc: Variant = s.get("doc") if s != null else null
	if doc == null:
		return ""
	var nm: Variant = doc.get("name")
	return String(nm) if nm != null else ""


func _default_name_hint() -> String:
	var nm: String = _project_name()
	if not nm.is_empty():
		return nm
	var sq: Sequence = _seq()
	return sq.label if sq != null and not sq.label.is_empty() else "sequence name"


func _place_label() -> String:
	var id: String = Places.place_of(settings)
	if id.is_empty():
		return "This folder only"
	var pl: Dictionary = Places.by_id(id)
	return String(pl.get("name", "This folder only")) if not pl.is_empty() else "This folder only"


func _on_place(id: String) -> void:
	if id == "__manage":
		_open_places_sheet()
		return
	if id == "__folder":
		var dest: Dictionary = settings.get("destination", {})
		dest["place"] = ""
		settings["destination"] = dest
		_refresh()
		return
	var pl: Dictionary = Places.by_id(id)
	if pl.is_empty():
		return
	var sq: Sequence = _seq()
	settings = Places.apply(settings, pl, _project_name(), sq.label if sq != null else "", sq.height if sq != null else 0, sq.fps if sq != null else 0.0)
	_refresh()


func _open_places_sheet() -> void:
	var sheet: Object = load("res://modules/export/places_sheet.gd").new()
	sheet.call("open", _root, settings, _refresh_after_places)


func _refresh_after_places() -> void:
	_refresh()


func _on_add_part() -> void:
	var sq: Sequence = _pick_seq()
	if sq == null:
		return
	if sq.in_point < 0.0 or sq.out_point <= sq.in_point:
		_warn_user("There is no in to out to add", "Set an in point and an out point on the timeline first, then press Add in to out")
		return
	var list: Array = settings.get("spans", []) if settings.get("spans") is Array else []
	list = list.duplicate(true)
	list.append({"from": sq.in_point, "to": sq.out_point})
	settings["spans"] = list
	settings["range"] = ExportPresets.RANGE_PARTS
	_refresh()


func _on_remove_part(index: int) -> void:
	var list: Array = settings.get("spans", []) if settings.get("spans") is Array else []
	if index < 0 or index >= list.size():
		return
	list = list.duplicate(true)
	list.remove_at(index)
	settings["spans"] = list
	if list.is_empty() and String(settings.get("range", "")) == ExportPresets.RANGE_PARTS:
		settings["range"] = "sequence"
	_refresh()


func _rebuild_parts() -> void:
	if _parts_box == null:
		return
	PmUI.clear(_parts_box)
	if not ExportPresets.spans_held(settings):
		return
	var sq: Sequence = _pick_seq()
	var fps: float = ExportPresets.resolve_fps(settings, sq.fps) if sq != null else 30.0
	var raw: Array = settings.get("spans", [])
	for i: int in raw.size():
		var d: Dictionary = raw[i] if raw[i] is Dictionary else {}
		var from_v: float = float(d.get("from", 0.0))
		var to_v: float = float(d.get("to", 0.0))
		var row: HBoxContainer = PmUI.hbox()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n: Label = PmLabel.dim(str(i + 1))
		n.custom_minimum_size.x = 18.0
		row.add_child(n)
		var text: Label = PmLabel.trim(ExportPresets.fmt_span(from_v, fps) + " to " + ExportPresets.fmt_span(to_v, fps), "text_dim")
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var del_b: Button = PmButton.make("Remove")
		del_b.pressed.connect(_on_remove_part.bind(i))
		row.add_child(del_b)
		_parts_box.add_child(row)


func _on_clear_parts() -> void:
	settings["spans"] = []
	if String(settings.get("range", "")) == ExportPresets.RANGE_PARTS:
		settings["range"] = "sequence"
	_refresh()


func _on_add_pass() -> void:
	var list: Array = settings.get("passes", []) if settings.get("passes") is Array else []
	list = list.duplicate(true)
	list.append({"name": "", "spans": [], "settings": {}})
	settings["passes"] = list
	_refresh()


func _on_remove_pass(index: int) -> void:
	var list: Array = settings.get("passes", []) if settings.get("passes") is Array else []
	if index < 0 or index >= list.size():
		return
	list = list.duplicate(true)
	list.remove_at(index)
	settings["passes"] = list
	_refresh()


func _on_pass_use_picked() -> void:
	var list: Array = settings.get("passes", []) if settings.get("passes") is Array else []
	if list.is_empty():
		_warn_user("There is no pass to give them to", "Add a pass first, then hand it the parts you picked")
		return
	if not ExportPresets.spans_held(settings):
		_warn_user("Nothing is picked", "Drag across the timeline ruler to pick the parts first")
		return
	list = list.duplicate(true)
	var last: Dictionary = list[list.size() - 1]
	last["spans"] = (settings.get("spans", []) as Array).duplicate(true)
	list[list.size() - 1] = last
	settings["passes"] = list
	_refresh()


func _on_pass_name(index: int, text: String) -> void:
	var list: Array = settings.get("passes", []) if settings.get("passes") is Array else []
	if index < 0 or index >= list.size():
		return
	list = list.duplicate(true)
	var one: Dictionary = list[index]
	one["name"] = text
	list[index] = one
	settings["passes"] = list


func _rebuild_passes() -> void:
	if _passes_box == null:
		return
	PmUI.clear(_passes_box)
	var list: Array[Dictionary] = ExportPresets.pass_list(settings)
	if list.is_empty():
		_passes_box.add_child(PmLabel.dim("No passes. The export writes one file from the settings here."))
		return
	var sq: Sequence = _pick_seq()
	for one: Dictionary in list:
		var row: HBoxContainer = PmUI.hbox()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n: Label = PmLabel.dim(str(int(one["index"])))
		n.custom_minimum_size.x = 18.0
		row.add_child(n)
		var name_f: LineEdit = PmUI.line_edit(String(one["name"]))
		name_f.text = String(one["name"]) if not String(one["name"]).begins_with("Pass ") else ""
		name_f.custom_minimum_size.x = 120.0
		name_f.text_changed.connect(_on_pass_name.bind(int(one["index"]) - 1))
		row.add_child(name_f)
		var sum_l: Label = PmLabel.trim(ExportPresets.pass_summary(settings, one, sq), "text_dim")
		sum_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sum_l)
		var del_b: Button = PmButton.make("Remove")
		del_b.pressed.connect(_on_remove_pass.bind(int(one["index"]) - 1))
		row.add_child(del_b)
		_passes_box.add_child(row)


func _warn_user(title: String, detail: String) -> void:
	var ev: Node = _events()
	if ev != null:
		ev.call("warn", title, detail)


func _on_measure_size() -> void:
	if _measuring:
		return
	var s: Node = _session()
	var comp: Node = s.get("compositor") if s != null else null
	if comp == null or not comp.has_method("read_frame"):
		_warn_user("There is nothing to measure yet", "The compositor is not running for this sequence")
		return
	if not bool(comp.call("has_gpu")):
		_warn_user("The size cannot be measured here", "There is no GPU renderer in this process")
		return
	_measuring = true
	_measured = {}
	_update_estimate()
	var handles: Dictionary = s.get("media_handles") if s != null else {}
	var doc_v: Variant = s.get("doc") if s != null else null
	var out: Dictionary = await ExportProbe.run(_root, settings, _pick_seq(), doc_v, comp, handles, _containers)
	_measuring = false
	if bool(out.get("ok", false)):
		out["for"] = _settings_fingerprint()
		_measured = out
	else:
		_measured = {}
		_warn_user("The size could not be measured", String(out.get("why", "")))
	_update_estimate()


func _update_warnings() -> void:
	if _warnings == null:
		return
	var lines: PackedStringArray = PackedStringArray()
	var b: Node = _bridge()
	if b == null or not bool(b.get("available")):
		lines.append("The native engine (purrcore) is missing: the estimate works, exporting does not.")
	var s: Node = _session()
	if s != null and s.get("compositor") == null:
		lines.append("No compositor is running for this sequence.")
	if bool(settings["interpolation"]):
		lines.append("Frame interpolation is a stage 3 feature and is ignored.")
	var sq: Sequence = _pick_seq()
	if sq != null and not is_equal_approx(ExportPresets.resolve_fps(settings, sq.fps), sq.fps):
		lines.append("The frame rate differs from the sequence: frames are sampled at the export rate, without blending.")
	var risk: String = ExportPresets.artifact_risk(String(settings.get("container", "")), String(settings.get("video_codec", "")))
	if not risk.is_empty():
		lines.append(risk)
	lines.append_array(chapter_warnings())
	if ExportPresets.is_share_fit(settings):
		lines.append("When a size targeted export finishes, the file is put on the clipboard so it can be pasted into Discord.")
	_warnings.text = "\n".join(lines)


func _set_progress(frac: float, message: String) -> void:
	if _progress == null:
		return
	_progress.value = frac
	var head: String = "%d%% done" % int(round(frac * 100.0))
	var detail: String = ""
	if _job != null and is_instance_valid(_job) and _job.has_method("stats"):
		detail = ExportJob.stats_text(_job.call("stats"))
	_progress_label.text = head + (", " + detail if not detail.is_empty() else "")
	if _plan != null and not message.is_empty():
		_plan.text = message


func _on_add_to_queue() -> void:
	if bool(load("res://modules/export/export_warnings.gd").call("hold", _root, _pick_seq(), _on_add_to_queue)):
		return
	ViewFold.queue_back(_queue, settings, _seq(), _doc())
	_rebuild_queue_rows()
	_run_next()


func _on_export_now() -> void:
	if bool(load("res://modules/export/export_warnings.gd").call("hold", _root, _pick_seq(), _on_export_now)):
		return
	ViewFold.queue_front(_queue, settings, _seq(), _doc())
	_rebuild_queue_rows()
	_run_next()


func _on_cancel() -> void:
	if _job != null and is_instance_valid(_job):
		_job.call("cancel")


func _rebuild_queue_rows() -> void:
	if _queue_box == null:
		return
	PmUI.clear(_queue_box)
	var doc_now: Project = _doc()
	if not _queue.is_empty():
		var top: HBoxContainer = PmUI.hbox()
		var run_b: Button = PmButton.make("Run the queue (" + str(_queue.size()) + ")")
		run_b.disabled = _job != null and is_instance_valid(_job)
		run_b.pressed.connect(_run_next)
		top.add_child(run_b)
		_queue_box.add_child(top)
	for i: int in _queue.size():
		var qs: Dictionary = _queue[i]
		var row: HBoxContainer = PmUI.hbox()
		row.add_child(PmLabel.small(str(i + 1) + ". " + ExportPresets.output_path(qs, _seq_of(qs), _containers).get_file() + ViewExport.queue_note(qs) + ExportSequences.queue_note(qs, doc_now) + ExportQueueState.row_note(qs, doc_now)))
		var rm: Button = PmButton.make("Remove")
		rm.set("quiet", true)
		rm.pressed.connect(_on_remove_queued.bind(i))
		row.add_child(rm)
		_queue_box.add_child(row)


func _on_remove_queued(i: int) -> void:
	if i >= 0 and i < _queue.size():
		_queue.remove_at(i)
	_rebuild_queue_rows()


func _run_next() -> void:
	if _job != null and is_instance_valid(_job):
		return
	if _queue.is_empty():
		_progress_row.visible = false
		return
	var s: Node = _session()
	var ev: Node = _events()
	if s == null or s.get("doc") == null:
		if ev != null:
			ev.warn("Nothing to export: no project is open")
		return
	var doc_now: Project = s.get("doc")
	var at: int = ExportQueueState.first_runnable(_queue, doc_now)
	if at < 0:
		_progress_row.visible = false
		if ev != null:
			ev.warn("The export queue was built against another project, so it was left as it is", "Open that project to run these jobs, or remove them from the queue")
		return
	var next: Dictionary = _queue[at]
	_queue.remove_at(at)
	_running = next
	if ExportQueueState.sequence_gone(next, doc_now) and ev != null:
		ev.warn("That job's sequence is gone, exporting the one you are looking at instead")
	var comp: Node = s.get("compositor")
	var job: Node = ExportJob.new()
	job.name = "ExportJob"
	job.call("setup", next, _seq_of(next), s.get("doc"), comp, s.get("media_handles"))
	job.set("share_to_clipboard", true)
	job.connect("progress", _set_progress)
	job.connect("finished", _on_job_finished.bind(job))
	var loop: MainLoop = Engine.get_main_loop()
	(loop as SceneTree).root.add_child(job)
	_job = job
	_rebuild_queue_rows()
	_progress_row.visible = true
	_set_progress(0.0, "Starting")
	_export_button.disabled = true
	job.call("start")


func _on_job_finished(ok: bool, message: String, job: Node) -> void:
	_export_button.disabled = false
	_set_progress(1.0 if ok else 0.0, message)
	if _plan != null:
		_plan.text = String(job.get("plan_text")) + ("\n" + message if not message.is_empty() else "")
	var parent: Node = job.get_parent()
	if parent != null:
		parent.remove_child(job)
	job.queue_free()
	_job = null
	_running = {}
	_rebuild_queue_rows()
	_run_next()

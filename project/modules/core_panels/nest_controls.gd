extends VBoxContainer

const SELF := preload("res://modules/core_panels/nest_controls.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Verbs := preload("res://doc/verbs.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const LABEL_W := 110.0
const KEYS: PackedStringArray = ["hear_audio", "show_audio_below", "see_inside"]

var clip_id: String = ""
var checks: Dictionary = {}
var chips: Dictionary = {}
var _watched: Project = null


static func build(panel: Object, c: Clip) -> VBoxContainer:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if panel == null or c == null or not c.is_nest() or d == null or s == null:
		return null
	var f: VBoxContainer = panel.call("_fold", "Nest", "nest")
	var body: VBoxContainer = f.get("body")
	var section: VBoxContainer = SELF.new()
	section.name = "NestSection"
	section.call("setup", d, c)
	body.add_child(section)
	return section


func setup(d: Project, c: Clip) -> void:
	clip_id = c.id
	add_theme_constant_override("separation", 0)
	var inner: Sequence = d.sequence_by_id(c.sequence_id)
	add_child(_check_row("Hear audio", "hear_audio", "Play the nest's sound in this sequence and in exports"))
	if inner != null and not inner.audio_tracks.is_empty():
		var row: HBoxContainer = _row()
		var lab: Label = PmLabel.dim("Tracks")
		lab.custom_minimum_size = Vector2(float(Tk.px(LABEL_W)) * 0.5, 0.0)
		row.add_child(lab)
		for t: Track in inner.audio_tracks:
			var chip: Button = PmButton.make(t.label, "audio")
			chip.set("quiet", true)
			chip.toggle_mode = true
			chip.name = "Track_" + t.id
			PmUI.tip(chip, "Hear " + t.label + " of " + inner.label + " through this nest")
			chip.toggled.connect(_on_track.bind(t.id))
			row.add_child(chip)
			chips[t.id] = chip
		add_child(row)
	add_child(_check_row("Show audio below", "show_audio_below", "Draw the nest's audio tracks under this sequence's own"))
	add_child(_check_row("See inside", "see_inside", "Draw the nest's tracks inside the clip"))
	var open_row: HBoxContainer = _row()
	var open: Button = PmButton.make("Open the nested sequence", "seq")
	open.set("quiet", true)
	open.name = "OpenNest"
	PmUI.tip(open, "Open it in a timeline tab that remembers this clip, so you can hear and see what is around it")
	open.pressed.connect(_on_open)
	open_row.add_child(open)
	add_child(open_row)
	if inner != null:
		var info: HBoxContainer = _row()
		info.add_child(PmLabel.faint(summary(inner)))
		add_child(info)
	sync()


static func summary(inner: Sequence) -> String:
	var v: int = inner.video_tracks.size()
	var a: int = inner.audio_tracks.size()
	return "%s, %d video and %d audio track%s" % [inner.label, v, a, "" if a == 1 else "s"]


func _enter_tree() -> void:
	_watch(Session.doc)


func _exit_tree() -> void:
	_watch(null)


func _watch(d: Project) -> void:
	if _watched != null and _watched.changed.is_connected(_on_doc_changed):
		_watched.changed.disconnect(_on_doc_changed)
	_watched = d
	if _watched != null and not _watched.changed.is_connected(_on_doc_changed):
		_watched.changed.connect(_on_doc_changed)


func _on_doc_changed(kind: String) -> void:
	if kind == "meta" or kind == "structure":
		sync()


func clip() -> Clip:
	var s: Sequence = Session.seq()
	return s.clip_by_id(clip_id) if s != null else null


func sync() -> void:
	var c: Clip = clip()
	if c == null or not c.is_nest():
		return
	for key: String in KEYS:
		if checks.has(key):
			(checks[key] as CheckBox).set_pressed_no_signal(bool(c.nest.get(key, key == "hear_audio")))
	var heard: PackedStringArray = Verbs.nest_heard_tracks(Session.doc, c)
	for tid: Variant in chips.keys():
		(chips[tid] as Button).set_pressed_no_signal(heard.has(String(tid)))


func _row() -> HBoxContainer:
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.custom_minimum_size = Vector2(0.0, float(Tk.px(Tk.sz("row_h"))) + 2.0)
	var pad: Control = Control.new()
	pad.custom_minimum_size = Vector2(float(Tk.px(8.0)), 0.0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pad)
	return row


func _check_row(text: String, key: String, tip: String) -> HBoxContainer:
	var row: HBoxContainer = _row()
	var cb: CheckBox = CheckBox.new()
	cb.focus_mode = Control.FOCUS_NONE
	cb.name = "Check_" + key
	cb.toggled.connect(_on_check.bind(key))
	PmUI.tip(cb, tip)
	row.add_child(cb)
	row.add_child(PmLabel.body(text))
	checks[key] = cb
	return row


func _on_check(on: bool, key: String) -> void:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null or s == null:
		return
	Verbs.set_nest_option(d, s, clip_id, key, on)


func _on_track(on: bool, track_id: String) -> void:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null or s == null:
		return
	Verbs.set_nest_track_heard(d, s, clip_id, track_id, on)
	sync()


func _on_open() -> void:
	open_nest(clip_id)


static func open_nest(id: String) -> bool:
	var s: Sequence = Session.seq()
	var c: Clip = s.clip_by_id(id) if s != null else null
	if c == null or not c.is_nest():
		return false
	var tl: Object = Bus.instance().panel("timeline")
	var cv: Variant = tl.get("canvas") if tl != null else null
	if cv is Control and (cv as Control).has_signal("nest_open_requested"):
		(cv as Control).emit_signal("nest_open_requested", c.sequence_id, c.id)
		return true
	Session.set_nest_context(c.sequence_id, s.id, c.id)
	Session.set_sequence(c.sequence_id)
	return true

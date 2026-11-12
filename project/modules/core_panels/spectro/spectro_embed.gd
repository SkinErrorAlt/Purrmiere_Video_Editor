extends RefCounted
## The Audio Editor's spectrogram view: a button swaps the waveform for a spectrogram of the same clip, sharing
## the editor's time range, selection and playhead.

const PmUI := preload("res://ui/kit/pm_ui.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const SpectroView := preload("res://modules/core_panels/spectro/spectro_view.gd")
const SpectroBar := preload("res://modules/core_panels/spectro/spectro_bar.gd")
const SpectroTarget := preload("res://modules/core_panels/spectro/spectro_target.gd")
const PREF := "audio_editor.spectrogram"
const META_VIEW := "spectro_view"
const META_BAR := "spectro_bar"
const META_WAVE := "spectro_wave"


static func attach(panel: Object, col: VBoxContainer, wave: Control, head: HBoxContainer) -> Control:
	if not Prefs.is_registered(PREF):
		Prefs.register(PREF, false, {"label": "Audio editor shows the spectrogram instead of the waveform", "type": "bool"})
	var view: Control = SpectroView.new()
	view.name = "SpectroView"
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = wave.custom_minimum_size
	SpectroBar.apply_shared(view)
	col.add_child(view)
	col.move_child(view, wave.get_index() + 1)
	var bar_box: PanelContainer = PmUI.panel("bg_panel_alt")
	bar_box.name = "SpectroSettingsBox"
	bar_box.add_child(SpectroBar.build(view))
	col.add_child(bar_box)
	col.move_child(bar_box, wave.get_index() + 1)
	panel.set_meta(META_VIEW, view)
	panel.set_meta(META_BAR, bar_box)
	panel.set_meta(META_WAVE, wave)
	var b: Button = PmButton.make("Spectrogram", "grid", true)
	b.name = "SpectrogramToggle"
	b.set("quiet", true)
	b.button_pressed = bool(Prefs.get_value(PREF))
	PmUI.tip(b, "Show the clip's frequencies over time instead of its waveform. Hidden pictures show up here")
	b.toggled.connect(func(on: bool) -> void:
		Prefs.set_value(PREF, on)
		show(panel, on))
	head.add_child(b)
	view.connect("view_changed", func() -> void:
		panel.set("t0", float(view.get("t0")))
		panel.set("t1", float(view.get("t1"))))
	view.set("drag_selects", true)
	view.connect("selection_dragged", func(a: float, b: float) -> void: panel.call("set_selection", a, b))
	view.connect("seek_requested", func(src: float) -> void:
		var c: Clip = panel.call("target")
		if c != null:
			panel.call("clear_selection")
			Session.scrub_to(float(panel.call("timeline_time", c, src))))
	var follow := _Follow.new()
	follow.name = "Follow"
	follow.panel = panel
	view.add_child(follow)
	show(panel, bool(Prefs.get_value(PREF)))
	return view


static func view_of(panel: Object) -> Control:
	return panel.get_meta(META_VIEW, null) if panel.has_meta(META_VIEW) else null


static func showing(panel: Object) -> bool:
	var v: Control = view_of(panel)
	return v != null and v.visible


static func show(panel: Object, on: bool) -> void:
	var v: Control = view_of(panel)
	if v == null:
		return
	(panel.get_meta(META_WAVE) as Control).visible = not on
	(panel.get_meta(META_BAR) as Control).visible = on
	v.visible = on
	sync(panel)


## Points the spectrogram at the editor's clip and time range. Cheap: it only recomputes when something changed.
static func sync(panel: Object) -> void:
	var v: Control = view_of(panel)
	if v == null or not v.visible:
		return
	var c: Clip = panel.call("target")
	if c == null:
		v.call("clear_source")
		return
	var t: Dictionary = SpectroTarget.for_clip(panel.call("doc"), panel.call("seq"), c)
	if t.is_empty():
		v.call("clear_source")
		return
	v.set("span_from", float(t["from"]))
	v.set("span_to", float(t["to"]))
	v.call("set_source", String(t["path"]), int(t["stream"]))
	v.set("_fit_on_load", false)
	var a: float = float(panel.get("t0"))
	var b: float = float(panel.get("t1"))
	if absf(a - float(v.get("t0"))) > 1e-9 or absf(b - float(v.get("t1"))) > 1e-9:
		v.call("set_view", a, b, float(v.get("f0")), float(v.get("f1")) if bool(v.call("has_sound")) else 1e9, false)
	var has_sel: bool = bool(panel.call("has_selection"))
	v.set("sel_from", float(panel.get("sel_a")) if has_sel else NAN)
	v.set("sel_to", float(panel.get("sel_b")) if has_sel else NAN)
	playhead(panel)


static func playhead(panel: Object) -> void:
	var v: Control = view_of(panel)
	if v == null or not v.visible:
		return
	var c: Clip = panel.call("target")
	var src: float = NAN
	if c != null and Session.playhead() >= c.start and Session.playhead() <= c.end():
		src = float(panel.call("source_of_timeline", c, Session.playhead()))
	var before: float = float(v.get("playhead_src"))
	if before == src or (is_nan(before) and is_nan(src)):
		return
	v.set("playhead_src", src)
	var over: Variant = v.get("_over")
	if over is Control:
		(over as Control).queue_redraw()


class _Follow:
	extends Node

	const Embed := preload("res://modules/core_panels/spectro/spectro_embed.gd")

	var panel: Object = null
	var _seen: Array = []

	func _process(_dt: float) -> void:
		var v: Control = get_parent() as Control
		if v == null or not v.is_visible_in_tree() or panel == null:
			return
		var now: Array = [String(panel.get("_built_stamp")), float(panel.get("t0")), float(panel.get("t1")), float(panel.get("sel_a")), float(panel.get("sel_b"))]
		if now != _seen:
			_seen = now
			Embed.sync(panel)
		else:
			Embed.playhead(panel)

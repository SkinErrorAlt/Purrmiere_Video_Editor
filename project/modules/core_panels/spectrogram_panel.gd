extends "res://modules/core_panels/panel_base.gd"
## The Spectrogram panel: the selected audio clip (or the sound selected in the bin) as frequencies over time,
## following the playhead. It also makes sounds that hide a picture or words.

const SpectroView := preload("res://modules/core_panels/spectro/spectro_view.gd")
const SpectroBar := preload("res://modules/core_panels/spectro/spectro_bar.gd")
const SpectroTarget := preload("res://modules/core_panels/spectro/spectro_target.gd")
const HiddenSoundUi := preload("res://modules/core_panels/spectro/hidden_sound_ui.gd")

var view: Control = null
var _title_label: Label = null
var _source_label: String = ""
var _target: Dictionary = {}


func _build(root_: Control) -> void:
	var col: VBoxContainer = column(root_)
	var head_row: HBoxContainer = header_row(col)
	var head: HFlowContainer = PmUI.flow(Tk.px(4.0), Tk.px(2.0))
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(head)
	_title_label = PmLabel.trim("No sound selected", "text_bright")
	_title_label.name = "Title"
	_title_label.custom_minimum_size.x = float(Tk.px(140.0))
	head.add_child(_title_label)
	view = SpectroView.new()
	view.name = "SpectroView"
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SpectroBar.apply_shared(view)
	SpectroBar.view_buttons(head, view)
	var hide_b: Button = PmButton.make("Hide a picture", "image")
	hide_b.name = "HidePicture"
	hide_b.set("quiet", true)
	PmUI.tip(hide_b, "Make a sound whose spectrogram shows a picture or words, and put it on the timeline")
	hide_b.pressed.connect(func() -> void: HiddenSoundUi.open(_root))
	head.add_child(hide_b)
	var bar_box: PanelContainer = PmUI.panel("bg_panel_alt")
	bar_box.add_child(SpectroBar.build(view))
	col.add_child(bar_box)
	col.add_child(view)
	var foot: HBoxContainer = header_row(col)
	var hint: Label = PmLabel.dim(SpectroBar.HINT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_small")))
	foot.add_child(hint)
	view.connect("seek_requested", _on_seek)
	refresh()


func _on_doc_changed(kind: String) -> void:
	if kind == "selection" or kind == "structure" or kind == "meta" or kind == "media":
		refresh()


func _on_history() -> void:
	refresh()


func _on_project_changed() -> void:
	refresh()


func _on_sequence_changed(_id: String) -> void:
	refresh()


func _on_playhead(_t: float) -> void:
	_update_playhead(true)


func on_focus(has: bool) -> void:
	super.on_focus(has)
	if has:
		refresh()


func refresh() -> void:
	if not _alive() or view == null:
		return
	var bin: Object = bus().panel("bin")
	var bin_sel: PackedStringArray = bin.get("selected_ids") if bin != null else PackedStringArray()
	_target = SpectroTarget.find(doc(), seq(), bin_sel)
	if _target.is_empty():
		_title_label.text = "No sound selected"
		view.call("clear_source")
		return
	_title_label.text = String(_target.get("label", ""))
	view.set("span_from", float(_target.get("from", NAN)))
	view.set("span_to", float(_target.get("to", NAN)))
	view.call("set_source", String(_target["path"]), int(_target.get("stream", 0)))
	_update_playhead(false)


## Shows a file directly, such as a sound just made by Hide a picture.
func show_file(path: String) -> void:
	if view == null:
		return
	_target = {"path": path, "stream": 0, "label": path.get_file()}
	_title_label.text = path.get_file()
	view.set("span_from", NAN)
	view.set("span_to", NAN)
	view.call("set_source", path, 0)


func _update_playhead(follow: bool) -> void:
	if view == null or _target.is_empty():
		return
	var src: float = SpectroTarget.source_time(doc(), seq(), _target, Session.playhead())
	view.set("playhead_src", src)
	if follow and Session.playing and not is_nan(src) and bool(view.call("has_sound")):
		var a: float = float(view.get("t0"))
		var b: float = float(view.get("t1"))
		if src < a or src > b:
			var span: float = b - a
			view.call("fit_time", src - span * 0.1, src + span * 0.9)
	var over: Variant = view.get("_over")
	if over is Control:
		(over as Control).queue_redraw()


func _on_seek(source_time: float) -> void:
	var t: float = SpectroTarget.timeline_time(seq(), _target, source_time)
	if not is_nan(t):
		Session.scrub_to(t)


func handle_key(e: InputEventKey) -> bool:
	return view != null and bool(view.call("handle_key", e))


func save_state() -> Dictionary:
	return view.call("settings") if view != null else {}


func restore_state(d: Dictionary) -> void:
	if view != null and not d.is_empty():
		view.call("set_settings", d)

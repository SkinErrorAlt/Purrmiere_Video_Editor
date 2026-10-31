extends RefCounted

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmFold := preload("res://ui/kit/pm_fold.gd")
const Sequence := preload("res://doc/sequence.gd")
const Project := preload("res://doc/project.gd")
const ExportPresets := preload("res://modules/export/export_presets.gd")
const ViewExport := preload("res://modules/export/view_export.gd")
const ExportSequences := preload("res://modules/export/export_sequences.gd")
const LABEL_W := 118.0
const SWATCH := 10.0
const TIP_ONLY := "Each file has only the parts where its view is on screen (where a Pair View shows it as its View), joined in order, with that view's sound."
const TIP_WHOLE := "Each file is the whole range with every Pair View switched to its view the whole time, and that view's sound map."

var panel: Object = null
var fold: VBoxContainer = null
var body: VBoxContainer = null
var on_box: CheckBox = null
var mode_button: Button = null
var plain_box: CheckBox = null
var note: Label = null
var view_boxes: Dictionary = {}
var view_times: Dictionary = {}
var _rows: Dictionary = {}
var _views_holder: VBoxContainer = null
var _views_sig: String = ""
var _seq: Sequence = null


static func expand_all(settings: Dictionary, seq: Sequence, doc: Project) -> Array[Dictionary]:
	if doc == null:
		return _expand_views(expand_tags(settings, seq), seq)
	var out: Array[Dictionary] = []
	for one: Dictionary in ExportSequences.expand(settings, doc, seq):
		var target: Sequence = ExportSequences.sequence_of(one, doc, seq)
		out.append_array(_expand_views(expand_tags(one, target), target))
	return out


static func _expand_views(list: Array[Dictionary], seq: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for one: Dictionary in list:
		out.append_array(ViewExport.expand(one, seq))
	return out


static func expand_tags(settings: Dictionary, seq: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if String(settings.get("range", "")) != ExportPresets.RANGE_TAGS:
		out.append(settings)
		return out
	if ExportPresets.tag_spans(settings, seq).is_empty():
		_say_no_tags()
		return out
	if ExportPresets.tag_mode(settings) == ExportPresets.TAG_SECTIONS:
		return ExportPresets.tag_sections(settings, seq)
	out.append(settings)
	return out


static func _say_no_tags() -> void:
	var loop: MainLoop = Engine.get_main_loop()
	var ev: Node = (loop as SceneTree).root.get_node_or_null("Events") if loop is SceneTree else null
	if ev != null:
		ev.warn("Nothing to export: no tagged ranges", "Tag a range on the timeline, or pick tag names that exist in this sequence")


static func queue_back(queue: Array[Dictionary], settings: Dictionary, seq: Sequence, doc: Project = null) -> int:
	var list: Array[Dictionary] = expand_all(settings, seq, doc)
	queue.append_array(list)
	if String(settings.get("range", "")) != ExportPresets.RANGE_TAGS:
		_say_none(list)
	return list.size()


static func queue_front(queue: Array[Dictionary], settings: Dictionary, seq: Sequence, doc: Project = null) -> int:
	var list: Array[Dictionary] = expand_all(settings, seq, doc)
	for i: int in range(list.size() - 1, -1, -1):
		queue.insert(0, list[i])
	if String(settings.get("range", "")) != ExportPresets.RANGE_TAGS:
		_say_none(list)
	return list.size()


static func _say_none(list: Array[Dictionary]) -> void:
	if not list.is_empty():
		return
	var loop: MainLoop = Engine.get_main_loop()
	var ev: Node = (loop as SceneTree).root.get_node_or_null("Events") if loop is SceneTree else null
	if ev != null:
		ev.warn("Nothing to export: tick at least one view that is on screen in the range", "")


func _label_col(text: String) -> Label:
	var l: Label = PmLabel.dim(text)
	l.custom_minimum_size.x = float(Tk.px(LABEL_W))
	return l


func _row(key: String, label: String) -> HBoxContainer:
	var row: HBoxContainer = PmUI.hbox()
	row.add_child(_label_col(label))
	body.add_child(row)
	_rows[key] = row
	return row


func build(parent: Control, panel_: Object) -> VBoxContainer:
	panel = panel_
	fold = PmFold.make("Pair View", "export.pair_view", true)
	fold.name = "PairViewExport"
	parent.add_child(fold)
	body = fold.get("body")
	var on_row: HBoxContainer = _row("on", "Per view")
	on_box = CheckBox.new()
	on_box.text = "One video per view"
	on_box.focus_mode = Control.FOCUS_NONE
	on_box.toggled.connect(_on_toggled)
	on_row.add_child(on_box)
	PmUI.tip(on_box, "Write one file for each ticked Pair View view instead of one file. Files are named after the view.")
	var mode_row: HBoxContainer = _row("mode", "Mode")
	mode_button = PmButton.make("")
	mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	mode_button.set("elide", true)
	mode_button.pressed.connect(_open_modes)
	mode_row.add_child(mode_button)
	_views_holder = PmUI.vbox()
	_views_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_views_holder)
	var plain_row: HBoxContainer = _row("plain", "No Pair View")
	plain_box = CheckBox.new()
	plain_box.text = "Keep the parts with no Pair View"
	plain_box.focus_mode = Control.FOCUS_NONE
	plain_box.toggled.connect(_on_plain)
	plain_row.add_child(plain_box)
	PmUI.tip(plain_box, "Also keep the parts of the range where no Pair View is on screen (titles, other clips, gaps) in every file.")
	var note_row: HBoxContainer = _row("note", "")
	note = PmLabel.wrap("", "text_dim")
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_row.add_child(note)
	fold.visible = false
	return fold


func _settings() -> Dictionary:
	return panel.get("settings") if panel != null else {}


func _store(key: String, value: Variant) -> void:
	var s: Dictionary = _settings()
	var d: Dictionary = ViewExport.panel_choice(s)
	d[key] = value
	s[ViewExport.PANEL_KEY] = d
	refresh(s, _seq)


func _on_toggled(on: bool) -> void:
	_store("on", on)


func _on_plain(on: bool) -> void:
	_store("keep_plain", on)


func _open_modes() -> void:
	var cur: String = String(ViewExport.panel_choice(_settings())["mode"])
	var items: Array = []
	for m: Array in ViewExport.MODES:
		items.append(PmMenu.check_item(String(m[0]), String(m[1]), String(m[0]) == cur))
	var menu: Control = PmMenu.open(mode_button, items)
	menu.connect("picked", _on_mode)


func _on_mode(id: String) -> void:
	_store("mode", ViewExport.MODE_WHOLE if id == ViewExport.MODE_WHOLE else ViewExport.MODE_ONLY)


func _on_view(on: bool, index: int) -> void:
	var skip: Array = ViewExport.panel_choice(_settings())["skip"]
	skip.erase(index)
	if not on:
		skip.append(index)
	skip.sort()
	_store("skip", skip)


static func clock(t: float) -> String:
	var s: int = int(round(maxf(t, 0.0)))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


func _rebuild_views(views: Array[Dictionary]) -> void:
	PmUI.clear(_views_holder)
	view_boxes = {}
	view_times = {}
	for v: Dictionary in views:
		var i: int = int(v["index"])
		var row: HBoxContainer = PmUI.hbox()
		row.add_child(_label_col("Views" if i == 0 else ""))
		var cb := CheckBox.new()
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(_on_view.bind(i))
		row.add_child(cb)
		var sw := ColorRect.new()
		sw.color = Tk.label_colour(int(v["colour"]))
		sw.custom_minimum_size = Vector2(float(Tk.px(SWATCH)), float(Tk.px(SWATCH)))
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sw)
		var nm: Label = PmLabel.trim(String(v["name"]))
		PmUI.tip(nm, String(v["name"]))
		row.add_child(nm)
		var tl: Label = PmLabel.faint("")
		row.add_child(tl)
		var pad := Control.new()
		pad.custom_minimum_size.x = float(Tk.px(Tk.sz("pad")))
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pad)
		_views_holder.add_child(row)
		view_boxes[i] = cb
		view_times[i] = tl


func refresh(settings: Dictionary, seq: Sequence) -> void:
	_seq = seq
	if fold == null:
		return
	var views: Array[Dictionary] = ViewExport.views_of(seq)
	fold.visible = not views.is_empty()
	if views.is_empty():
		return
	var sig: String = JSON.stringify(views)
	if sig != _views_sig:
		_views_sig = sig
		_rebuild_views(views)
	var c: Dictionary = ViewExport.panel_choice(settings)
	var on: bool = bool(c["on"])
	var only: bool = String(c["mode"]) == ViewExport.MODE_ONLY
	on_box.set_pressed_no_signal(on)
	mode_button.text = String(ViewExport.MODES[0][1]) if only else String(ViewExport.MODES[1][1])
	PmUI.tip(mode_button, TIP_ONLY if only else TIP_WHOLE)
	plain_box.set_pressed_no_signal(bool(c["keep_plain"]))
	(_rows["mode"] as Control).visible = on
	(_rows["plain"] as Control).visible = on and only
	(_rows["note"] as Control).visible = on
	_views_holder.visible = on
	if not on:
		return
	var range_v: Vector2 = ExportPresets.resolve_range(settings, seq)
	var whole: float = range_v.y - range_v.x
	var skip: Array = c["skip"]
	var never: PackedStringArray = PackedStringArray()
	for v: Dictionary in views:
		var i: int = int(v["index"])
		(view_boxes[i] as CheckBox).set_pressed_no_signal(not skip.has(i))
		var tl: Label = view_times[i]
		if only:
			var shown: float = ViewExport.total(ViewExport.spans_for(seq, i, range_v, bool(c["keep_plain"])))
			tl.text = "never on screen" if shown <= 0.0 else "on screen " + clock(shown) + " of " + clock(whole)
			if shown <= 0.0 and not skip.has(i):
				never.append(String(v["name"]))
		else:
			tl.text = "whole range " + clock(whole)
	var files: PackedStringArray = PackedStringArray()
	var list: Array[Dictionary] = ViewExport.expand(settings, seq)
	for s: Dictionary in list:
		if s.has(ViewExport.JOB_KEY):
			files.append(ExportPresets.output_path(s, seq, []).get_file())
	var lines: PackedStringArray = PackedStringArray()
	if files.is_empty():
		lines.append("Tick at least one view that is on screen in the range.")
	else:
		lines.append(("1 file: " if files.size() == 1 else str(files.size()) + " files: ") + ", ".join(files) + ".")
	for nm2: String in never:
		lines.append(nm2 + " is never on screen in this range, so it gets no file.")
	if not only:
		var without: int = 0
		for v2: Dictionary in views:
			if not skip.has(int(v2["index"])):
				without = maxi(without, ViewExport.pieces_without(seq, int(v2["index"])))
		if without > 0:
			lines.append(str(without) + " Pair View" + ("s have" if without != 1 else " has") + " fewer regions than a ticked view, they keep their own view.")
	note.text = " ".join(lines)

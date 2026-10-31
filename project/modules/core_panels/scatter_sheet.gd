extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const SheetList := preload("res://modules/core_panels/sheet_list.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Scatter := preload("res://doc/scatter_sounds.gd")
const SELF_PATH := "res://modules/core_panels/scatter_sheet.gd"
const WIDTH := 560.0
const LABEL_W := 160.0
const LIST_H := 150.0
const YES := "In use"
const NO := "No"
const ALLOWED := "Allowed"
const REFUSED := "No"

static var remembered: Dictionary = {}

var sheet: Control = null
var doc_ref: WeakRef = null
var seq_id: String = ""
var opts: Dictionary = {}
var sound_ids: PackedStringArray = PackedStringArray()
var lane_ids: PackedStringArray = PackedStringArray()
var picked: Dictionary = {}
var allowed: Dictionary = {}
var sound_list: Control = null
var lane_list: Control = null
var note: Label = null
var seed_field: Control = null
var count_field: Control = null
var gap_field: Control = null
var gap_random_field: Control = null
var mode_drop: Button = null
var spacing_drop: Button = null
var rule_drop: Button = null
var overlap_button: Button = null
var place_button: Button = null
var spacing_row: Node = null
var count_row: Node = null
var gap_row: Node = null
var gap_random_row: Node = null
var rule_row: Node = null


static func open(host: Node) -> Node:
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	if d == null or s == null:
		return null
	var script: GDScript = load(SELF_PATH)
	var u: Node = script.new()
	u.call("build", host, d, s)
	return u


static func start_options(d: Project, s: Sequence) -> Dictionary:
	var o: Dictionary = Scatter.normalise(remembered)
	if (o["lanes"] as PackedStringArray).is_empty():
		var lanes: PackedStringArray = Scatter.lanes_of(s)
		if not lanes.is_empty():
			o["lanes"] = PackedStringArray([lanes[lanes.size() - 1]])
	if (o["sounds"] as Array).is_empty():
		var sounds: Array[MediaItem] = Scatter.sound_media(d)
		if not sounds.is_empty():
			var first: Array[Dictionary] = [Scatter.sound_row(sounds[0].id, sounds[0].label, d.media_duration(sounds[0]))]
			o["sounds"] = first
	return o


func doc() -> Project:
	return doc_ref.get_ref() if doc_ref != null else null


func seq() -> Sequence:
	var d: Project = doc()
	return d.sequence_by_id(seq_id) if d != null else null


func build(host: Node, d: Project, s: Sequence) -> void:
	name = "ScatterSheet"
	doc_ref = weakref(d)
	seq_id = s.id
	opts = start_options(d, s)
	for lane_id: String in (opts["lanes"] as PackedStringArray):
		allowed[lane_id] = true
	for row: Variant in (opts["sounds"] as Array):
		if row is Dictionary:
			picked[String((row as Dictionary).get("media_id", ""))] = true
	for m: MediaItem in Scatter.sound_media(d):
		sound_ids.append(m.id)
	lane_ids = Scatter.lanes_of(s)
	sheet = Sheet.open(host, "Scatter sounds", WIDTH, 0.0, 40.0)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	var span: Dictionary = Scatter.span_of(s)
	sheet.call("add_note", "Copies of the sounds you pick are laid across %s, from %s to %s. The same seed with the same options places exactly the same clips every time." % [Scatter.span_source(s), _time_text(float(span["from"])), _time_text(float(span["to"]))])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", Tk.px(10.0))
	grid.add_theme_constant_override("v_separation", Tk.px(Tk.sz("pad")))
	col.add_child(grid)
	var seed_box: HBoxContainer = PmUI.hbox()
	seed_field = PmField.make(float(int(opts["seed"])), 0.0, 999999999.0, 1.0)
	seed_field.set("precision", 0)
	seed_field.connect("value_changed", _on_seed)
	seed_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_box.add_child(seed_field)
	var next_seed: Button = PmButton.make("Next seed")
	next_seed.pressed.connect(_on_next_seed)
	seed_box.add_child(next_seed)
	_row(grid, "Seed", seed_box)
	mode_drop = PmDrop.make_drop(_choices(Scatter.MODES, Scatter.MODE_LABELS), String(opts["mode"]))
	mode_drop.connect("changed", _on_mode)
	_row(grid, "Place them", mode_drop)
	spacing_drop = PmDrop.make_drop(_choices(Scatter.SPACINGS, Scatter.SPACING_LABELS), String(opts["spacing"]))
	spacing_drop.connect("changed", _on_spacing)
	spacing_row = _row(grid, "Spread them by", spacing_drop)
	count_field = PmField.make(float(int(opts["count"])), 0.0, float(Scatter.COUNT_MAX), 1.0)
	count_field.set("precision", 0)
	count_field.connect("value_changed", _on_count)
	count_row = _row(grid, "How many", count_field)
	gap_field = PmField.make(float(opts["gap"]), Scatter.MIN_GAP, Scatter.GAP_MAX, 0.05, " s")
	gap_field.connect("value_changed", _on_number.bind("gap"))
	gap_row = _row(grid, "Average gap", gap_field)
	gap_random_field = PmField.make(float(opts["gap_random"]) * 100.0, 0.0, 100.0, 1.0, " %")
	gap_random_field.connect("value_changed", _on_percent.bind("gap_random"))
	gap_random_row = _row(grid, "Gap randomness", gap_random_field)
	var gain_field: Control = PmField.make(float(opts["gain_db"]), Scatter.GAIN_MIN, Scatter.GAIN_MAX, 0.5, " dB")
	gain_field.connect("value_changed", _on_number.bind("gain_db"))
	_row(grid, "Gain", gain_field)
	var gain_random: Control = PmField.make(float(opts["gain_random_db"]), 0.0, Scatter.GAIN_RANDOM_MAX, 0.5, " dB")
	gain_random.connect("value_changed", _on_number.bind("gain_random_db"))
	_row(grid, "Gain randomness", gain_random)
	var pitch_field: Control = PmField.make(float(opts["pitch"]), Scatter.PITCH_MIN, Scatter.PITCH_MAX, 0.01)
	pitch_field.connect("value_changed", _on_number.bind("pitch"))
	_row(grid, "Pitch", pitch_field)
	var pitch_random: Control = PmField.make(float(opts["pitch_random"]) * 100.0, 0.0, Scatter.PITCH_RANDOM_MAX * 100.0, 1.0, " %")
	pitch_random.connect("value_changed", _on_percent.bind("pitch_random"))
	_row(grid, "Pitch randomness", pitch_random)
	overlap_button = PmButton.make("Allow overlap", "", true)
	overlap_button.button_pressed = bool(opts["allow_overlap"])
	overlap_button.toggled.connect(_on_overlap)
	_row(grid, "Overlap", overlap_button)
	rule_drop = PmDrop.make_drop(_choices(Scatter.RULES, Scatter.RULE_LABELS), String(opts["on_overlap"]))
	rule_drop.connect("changed", _on_rule)
	rule_row = _row(grid, "When two would overlap", rule_drop)
	col.add_child(PmLabel.body("Sounds to place"))
	sound_list = SheetList.make(32.0, false, 60.0)
	sound_list.set("click_activates", false)
	sound_list.set("auto_cursor", false)
	sound_list.set("empty_text", "The project has no sound files yet")
	sound_list.custom_minimum_size.y = float(Tk.px(LIST_H))
	sound_list.connect("pressed_row", _on_sound_row)
	col.add_child(sound_list)
	col.add_child(PmLabel.body("Tracks it may use"))
	lane_list = SheetList.make(32.0, false, 0.0)
	lane_list.set("click_activates", false)
	lane_list.set("auto_cursor", false)
	lane_list.set("empty_text", "This sequence has no unlocked sound track")
	lane_list.custom_minimum_size.y = float(Tk.px(LIST_H))
	lane_list.connect("pressed_row", _on_lane_row)
	col.add_child(lane_list)
	note = sheet.call("add_note", "", "text")
	var cancel: Button = sheet.call("add_button", "Cancel")
	cancel.pressed.connect(_on_cancel)
	place_button = sheet.call("add_button", "Place them", true)
	place_button.pressed.connect(_on_place)
	_sync()


func _time_text(t: float) -> String:
	return "%.2f s" % t


func _choices(ids: PackedStringArray, labels: Dictionary) -> Array:
	var out: Array = []
	for choice_id: String in ids:
		out.append(PmDrop.choice(choice_id, String(labels.get(choice_id, choice_id))))
	return out


func _row(grid: GridContainer, label: String, control: Control) -> Node:
	var l: Label = PmLabel.body(label)
	l.custom_minimum_size.x = float(Tk.px(LABEL_W))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)
	var pair := _RowPair.new()
	pair.label = l
	pair.control = control
	add_child(pair)
	return pair


func _chosen(ids: PackedStringArray, flags: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for one: String in ids:
		if flags.has(one):
			out.append(one)
	return out


func current() -> Dictionary:
	var raw: Dictionary = opts.duplicate(true)
	raw["lanes"] = _chosen(lane_ids, allowed)
	var sounds: Array = []
	for media_id: String in _chosen(sound_ids, picked):
		sounds.append({"media_id": media_id})
	raw["sounds"] = sounds
	return Scatter.options_for(doc(), seq(), raw)


func sound_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d: Project = doc()
	if d == null:
		return out
	for media_id: String in sound_ids:
		var m: MediaItem = d.media_by_id(media_id)
		if m == null:
			continue
		var on: bool = picked.has(media_id)
		out.append({"lead": m.kind, "title": m.label, "detail": "%.2f s" % d.media_duration(m), "right": YES if on else NO, "chip": true, "ink": on, "strong": on, "rule": true})
	return out


func lane_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s: Sequence = seq()
	if s == null:
		return out
	for lane_id: String in lane_ids:
		var t: Track = s.track_by_id(lane_id)
		if t == null:
			continue
		var on: bool = allowed.has(lane_id)
		out.append({"title": t.shown_label(), "detail": "%d clips on it now" % t.clips.size(), "right": ALLOWED if on else REFUSED, "chip": true, "ink": on, "strong": on, "rule": true})
	return out


func _sync() -> void:
	var markers: bool = String(opts["mode"]) == Scatter.MODE_MARKERS
	var by_count: bool = String(opts["spacing"]) == Scatter.BY_COUNT
	(spacing_row as _RowPair).set_row_shown(not markers)
	(count_row as _RowPair).set_row_shown(not markers and by_count)
	(gap_row as _RowPair).set_row_shown(not markers and not by_count)
	(gap_random_row as _RowPair).set_row_shown(not markers)
	(rule_row as _RowPair).set_row_shown(not bool(opts["allow_overlap"]))
	if sound_list != null:
		sound_list.call("set_rows", sound_rows(), true)
		sound_list.queue_redraw()
	if lane_list != null:
		lane_list.call("set_rows", lane_rows(), true)
		lane_list.queue_redraw()
	var raw: Dictionary = current()
	if note != null:
		note.text = Scatter.summary(raw)
	if place_button != null:
		place_button.disabled = Scatter.plan(raw).is_empty()


func _on_seed(v: float) -> void:
	opts["seed"] = int(roundf(v))
	_sync()


func _on_next_seed() -> void:
	opts["seed"] = int(opts["seed"]) + 1
	if seed_field != null:
		seed_field.set("value", float(int(opts["seed"])))
	_sync()


func _on_count(v: float) -> void:
	opts["count"] = int(roundf(v))
	_sync()


func _on_number(v: float, key: String) -> void:
	opts[key] = v
	_sync()


func _on_percent(v: float, key: String) -> void:
	opts[key] = v / 100.0
	_sync()


func _on_mode(choice_id: String) -> void:
	opts["mode"] = choice_id
	_sync()


func _on_spacing(choice_id: String) -> void:
	opts["spacing"] = choice_id
	_sync()


func _on_rule(choice_id: String) -> void:
	opts["on_overlap"] = choice_id
	_sync()


func _on_overlap(on: bool) -> void:
	opts["allow_overlap"] = on
	_sync()


func _on_sound_row(index: int, _on_right: bool) -> void:
	if index < 0 or index >= sound_ids.size():
		return
	var media_id: String = sound_ids[index]
	if picked.has(media_id):
		picked.erase(media_id)
	else:
		picked[media_id] = true
	_sync()


func _on_lane_row(index: int, _on_right: bool) -> void:
	if index < 0 or index >= lane_ids.size():
		return
	var lane_id: String = lane_ids[index]
	if allowed.has(lane_id):
		allowed.erase(lane_id)
	else:
		allowed[lane_id] = true
	_sync()


func place_now() -> int:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return 0
	var raw: Dictionary = current()
	var n: int = Scatter.run(d, s, raw)
	remembered = raw
	return n


func _on_place() -> void:
	var n: int = place_now()
	if n > 0:
		Events.toast("Placed %d sounds" % n)
	else:
		Events.toast("Nothing was placed")
	sheet.call("close")


func _on_cancel() -> void:
	sheet.call("close")


class _RowPair extends Node:
	var label: Label = null
	var control: Control = null

	func set_row_shown(on: bool) -> void:
		if label != null:
			label.visible = on
		if control != null:
			control.visible = on

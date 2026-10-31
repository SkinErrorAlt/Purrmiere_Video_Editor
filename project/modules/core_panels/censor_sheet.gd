extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Censor := preload("res://doc/censor.gd")
const CensorCmds := preload("res://doc/commands/censor_cmds.gd")
const SELF_PATH := "res://modules/core_panels/censor_sheet.gd"
const BAR_PATH := "res://modules/core_panels/censor_bar.gd"
const WIDTH := 440.0
const LABEL_W := 110.0

var sheet: Control = null
var doc: Project = null
var seq: Sequence = null
var clip_id: String = ""
var region_id: String = ""
var settings: Dictionary = {}
var sound_drop: Button = null
var volume_field: Control = null
var cut_drop: Button = null
var duck_row: Node = null
var duck_field: Control = null
var fade_row: Node = null
var fade_field: Control = null
var fit_drop: Button = null
var apply_button: Button = null


static func open(host: Node, p_doc: Project, p_seq: Sequence, p_clip_id: String, p_region_id: String) -> Node:
	var c: Clip = p_seq.clip_by_id(p_clip_id) if p_seq != null else null
	var r: Dictionary = Censor.region_by_id(c, p_region_id)
	if r.is_empty():
		return null
	var script: GDScript = load(SELF_PATH)
	var s: Node = script.new()
	s.call("build", host, p_doc, p_seq, p_clip_id, p_region_id, r)
	return s


func build(host: Node, p_doc: Project, p_seq: Sequence, p_clip_id: String, p_region_id: String, r: Dictionary) -> void:
	name = "CensorSheet"
	doc = p_doc
	seq = p_seq
	clip_id = p_clip_id
	region_id = p_region_id
	settings = Censor.settings_of(r)
	sheet = Sheet.open(host, "Censor settings", WIDTH)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", Tk.px(10.0))
	grid.add_theme_constant_override("v_separation", Tk.px(Tk.sz("pad")))
	col.add_child(grid)
	sound_drop = PmDrop.make_drop(_sound_choices(), String(settings["sound"]))
	sound_drop.connect("changed", _on_sound)
	_row(grid, "Sound", sound_drop)
	volume_field = PmField.make(float(settings["volume_db"]), Censor.VOLUME_MIN, Censor.VOLUME_MAX, 0.5, " dB")
	volume_field.connect("value_changed", _on_number.bind("volume_db"))
	_row(grid, "Volume", volume_field)
	cut_drop = PmDrop.make_drop(load(BAR_PATH).call("labelled", Censor.CUTS, Censor.CUT_LABELS), String(settings["cut"]))
	cut_drop.connect("changed", _on_choice.bind("cut"))
	_row(grid, "Cut", cut_drop)
	duck_field = PmField.make(float(settings["duck_db"]), Censor.DUCK_MIN, Censor.DUCK_MAX, 1.0, " dB")
	duck_field.connect("value_changed", _on_number.bind("duck_db"))
	duck_row = _row(grid, "Duck by", duck_field)
	fade_field = PmField.make(float(settings["fade_ms"]), Censor.FADE_MIN, Censor.FADE_MAX, 5.0, " ms")
	fade_field.connect("value_changed", _on_number.bind("fade_ms"))
	fade_row = _row(grid, "Fade over", fade_field)
	fit_drop = PmDrop.make_drop(load(BAR_PATH).call("labelled", Censor.FITS, Censor.FIT_LABELS), String(settings["fit"]))
	fit_drop.connect("changed", _on_choice.bind("fit"))
	_row(grid, "Fit", fit_drop)
	sheet.call("add_note", "Changes this censor only. New censors use the settings in the tool strip and in Settings, Censor.")
	var cancel: Button = sheet.call("add_button", "Cancel")
	cancel.pressed.connect(_on_cancel)
	apply_button = sheet.call("add_button", "Apply", true)
	apply_button.pressed.connect(_on_apply)
	_sync_rows()


func _sound_choices() -> Array:
	var sound: String = String(settings.get("sound", "bleep"))
	var file_id: String = sound if sound.begins_with("file:") else ""
	return load(BAR_PATH).call("sound_choices", doc, file_id, sound.substr(5).get_file() if not file_id.is_empty() else "")


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


func _sync_rows() -> void:
	var cut: String = String(settings.get("cut", "mute"))
	(duck_row as _RowPair).set_row_shown(cut == "duck")
	(fade_row as _RowPair).set_row_shown(cut == "fade")


func _on_sound(id: String) -> void:
	if id == "choose":
		sound_drop.call("set_value", String(settings["sound"]), false)
		load(BAR_PATH).call("choose_file", sheet, _on_file_chosen)
		return
	settings["sound"] = id


func _on_file_chosen(path: String) -> void:
	if path.is_empty() or sheet == null or not is_instance_valid(sheet):
		return
	settings["sound"] = Censor.custom_sound(doc, path)
	sound_drop.call("set_choices", _sound_choices())
	sound_drop.call("set_value", String(settings["sound"]), false)


func _on_number(v: float, key: String) -> void:
	settings[key] = v


func _on_choice(id: String, key: String) -> void:
	settings[key] = id
	_sync_rows()


func apply_now() -> bool:
	return CensorCmds.restyle(doc, seq, clip_id, region_id, settings)


func _on_apply() -> void:
	apply_now()
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

extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const StreamRoles := preload("res://doc/stream_roles.gd")
const ViewStreams := preload("res://doc/view_streams.gd")
const Presets := preload("res://doc/presets.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const SELF_PATH := "res://modules/core_panels/stream_roles_sheet.gd"
const NO_PRESET := ""

var sheet: Control = null
var media_id: String = ""
var edits: Array[LineEdit] = []
var preset_name: LineEdit = null
var preset_drop: Button = null
var preset_row: Control = null


static func open(host: Node, doc: Project, m: MediaItem) -> Node:
	var script: GDScript = load(SELF_PATH)
	var p: Node = script.new()
	p.call("build", host, doc, m)
	return p


static func preset_list(doc: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc != null:
		out.append_array(Presets.list_project(doc, StreamRoles.KIND))
	out.append_array(Presets.list_user(StreamRoles.KIND))
	return out


static func preset_choices(doc: Project) -> Array:
	var out: Array = []
	for p: Dictionary in preset_list(doc):
		var label: String = String(p.get("label", "")).strip_edges()
		if label.is_empty():
			label = "Unnamed"
		var text: String = StreamRoles.preset_summary(p)
		out.append(PmDrop.choice(String(p.get("id", "")), label if text.is_empty() else label + ": " + text))
	return out


func doc() -> Project:
	return Session.doc


func item() -> MediaItem:
	var d: Project = doc()
	return d.media_by_id(media_id) if d != null else null


func build(host: Node, d: Project, m: MediaItem) -> void:
	name = "StreamRolesSheet"
	media_id = m.id
	sheet = Sheet.open(host, "Audio track names", 460.0)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	sheet.call("add_note", m.label + ": name each sound stream in this file. The names show in the bin, in every stream list and on the audio clips in the timeline.")
	var n: int = StreamRoles.count(m)
	if n <= 0:
		col.add_child(PmLabel.wrap("This file has no sound streams to name.", "text_dim"))
	var grid: GridContainer = GridContainer.new()
	grid.name = "Streams"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", Tk.px(8.0))
	grid.add_theme_constant_override("v_separation", Tk.px(5.0))
	for o: int in n:
		var num: Label = PmLabel.mono(str(o + 1), "text_faint")
		num.custom_minimum_size.x = float(Tk.px(16.0))
		num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(num)
		var box: LineEdit = PmUI.line_edit(StreamRoles.name_of(m, o), StreamRoles.given(m, o))
		box.name = "Name" + str(o)
		box.custom_minimum_size.x = float(Tk.px(180.0))
		PmUI.tip(box, "What this stream is, for example Mic, Game or Discord")
		edits.append(box)
		grid.add_child(box)
		var info: String = ViewStreams.info_of(m, o)
		grid.add_child(PmLabel.mono(info if not info.is_empty() else " ", "text_faint"))
	col.add_child(grid)
	if n > 0:
		col.add_child(_usual_row())
		col.add_child(_preset_row(d))
		col.add_child(_save_row(m))
	var cb: Button = sheet.call("add_button", "Close")
	cb.name = "Close"
	cb.pressed.connect(_on_close)
	var ok: Button = sheet.call("add_button", "Save names", true)
	ok.name = "Save"
	ok.disabled = n <= 0
	ok.pressed.connect(_on_save)


func _usual_row() -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	var b: Button = PmButton.make("Use the usual names")
	b.name = "Usual"
	PmUI.tip(b, "Fill the empty boxes with Mic, Game and Discord, in stream order")
	b.pressed.connect(_on_usual)
	row.add_child(b)
	row.add_child(PmUI.spacer())
	return row


func _preset_row(d: Project) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	preset_row = row
	row.add_child(PmLabel.dim("Preset"))
	preset_drop = PmDrop.make_drop(preset_choices(d), NO_PRESET)
	preset_drop.name = "Presets"
	preset_drop.set("placeholder", "Pick a saved set of names")
	preset_drop.call("set_value", NO_PRESET, false)
	preset_drop.custom_minimum_size.x = float(Tk.px(230.0))
	PmUI.tip(preset_drop, "Fill the boxes from a set of names you saved before")
	preset_drop.connect("changed", _on_preset_picked)
	row.add_child(preset_drop)
	row.add_child(PmUI.spacer())
	row.visible = not preset_list(d).is_empty()
	return row


func _save_row(m: MediaItem) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	preset_name = PmUI.line_edit("Preset name", m.label.get_basename())
	preset_name.name = "PresetName"
	preset_name.custom_minimum_size.x = float(Tk.px(180.0))
	PmUI.tip(preset_name, "A name for this set of track names, so you can use it on another file")
	row.add_child(preset_name)
	var b: Button = PmButton.make("Save as preset")
	b.name = "SavePreset"
	PmUI.tip(b, "Keep these names as a preset you can use on any other video")
	b.pressed.connect(_on_save_preset)
	row.add_child(b)
	row.add_child(PmUI.spacer())
	return row


func typed_names() -> Dictionary:
	var out: Dictionary = {}
	for o: int in edits.size():
		var text: String = edits[o].text.strip_edges()
		if not text.is_empty():
			out[str(o)] = text
	return out


func show_names(names: Dictionary) -> void:
	for o: int in edits.size():
		edits[o].text = String(names.get(str(o), ""))


func _on_usual() -> void:
	var names: Dictionary = typed_names()
	for o: int in edits.size():
		if String(names.get(str(o), "")).is_empty():
			var usual: String = StreamRoles.usual_name(o)
			if not usual.is_empty():
				names[str(o)] = usual
	show_names(names)


func _on_preset_picked(id: String) -> void:
	if id == NO_PRESET:
		return
	for p: Dictionary in preset_list(doc()):
		if String(p.get("id", "")) == id:
			show_names(StreamRoles.names_from_preset(p))
			return
	Events.toast("That preset could not be read")


func _on_save_preset() -> void:
	var names: Dictionary = typed_names()
	if names.is_empty():
		Events.toast("Name at least one stream before saving a preset")
		return
	var label: String = preset_name.text.strip_edges()
	if label.is_empty():
		Events.toast("Give the preset a name first")
		return
	if not Presets.save_to_user(Presets.make(StreamRoles.KIND, label, StreamRoles.to_payload(names))):
		Events.toast("The preset could not be saved")
		return
	if preset_drop != null and is_instance_valid(preset_drop):
		preset_drop.call("set_choices", preset_choices(doc()))
		preset_drop.call("set_value", NO_PRESET, false)
	if preset_row != null and is_instance_valid(preset_row):
		preset_row.visible = true
	refresh_bin()
	Events.toast(label + " is in the bin now, drag it onto a file or a sound clip")


func refresh_bin() -> void:
	var bin: Object = Bus.instance().panel("bin")
	if bin != null and bin.has_method("queue_refresh"):
		bin.call("queue_refresh")


func _on_save() -> void:
	var d: Project = doc()
	var m: MediaItem = item()
	if d == null or m == null:
		sheet.call("close")
		return
	if StreamRoles.set_names(d, PackedStringArray([media_id]), typed_names(), "Name audio tracks of " + m.label):
		Events.toast("Audio track names saved")
	sheet.call("close")


func _on_close() -> void:
	sheet.call("close")

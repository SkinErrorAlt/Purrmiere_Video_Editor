extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const TextGlyphs := preload("res://engine/text_glyphs.gd")
const TextAnimators := preload("res://doc/text_animators.gd")
const TextPresets := preload("res://doc/text_presets.gd")
const TextPresetStore := preload("res://doc/text_preset_store.gd")
const SELF_PATH := "res://modules/core_panels/text_presets_sheet.gd"
const WIDTH := 780.0
const HEIGHT := 620.0
const LIST_H := 404.0
const CELL_W := 232.0
const CELL_H := 66.0
const ALL_GROUP := "Everything"
const FRAME_DARK := Color(0.082, 0.086, 0.098, 1.0)
const FRAME_LIGHT := Color(0.145, 0.153, 0.173, 1.0)

static var last_group: String = ALL_GROUP
static var last_save_group: String = ""
static var replace_motion: bool = false
static var draws: int = 0
static var last_fill_usec: int = 0

var sheet: Control = null
var seq_id: String = ""
var clip_id: String = ""
var rows: Array[Dictionary] = []
var group: String = ALL_GROUP
var query: String = ""
var _doc: Project = null
var _list: VBoxContainer = null
var _chips: HFlowContainer = null
var _foot: Label = null
var _search: LineEdit = null
var _replace_chip: Button = null
var _hover: int = -1
var _clock: float = 0.0
var _mine: Array[Dictionary] = []
var _known: PackedStringArray = PackedStringArray()
var _stale: bool = true


static func open(host: Node, doc: Project, sequence_id: String, id: String) -> Node:
	var script: GDScript = load(SELF_PATH)
	var n: Node = script.new()
	n.call("build", host, doc, sequence_id, id)
	return n


func _init() -> void:
	name = "TextPresetsSheet"
	set_process(false)


func build(host: Node, doc: Project, sequence_id: String, id: String) -> void:
	_doc = doc
	seq_id = sequence_id
	clip_id = id
	group = last_group
	sheet = Sheet.open(host, "Text presets", WIDTH, HEIGHT, 70.0)
	sheet.set("close_on_veil", true)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	_search = PmUI.line_edit("Search the presets")
	_search.name = "PresetSearch"
	_search.text_changed.connect(_on_search)
	col.add_child(_search)
	_chips = PmUI.flow(Tk.px(4.0), Tk.px(4.0))
	_chips.name = "PresetGroups"
	col.add_child(_chips)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "PresetScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(float(sheet.get("inner_w")), float(Tk.px(LIST_H)))
	_list = PmUI.vbox(Tk.px(6.0))
	_list.name = "PresetList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	col.add_child(scroll)
	col.add_child(PmUI.divider())
	_foot = PmLabel.faint("")
	col.add_child(_foot)
	_replace_chip = PmButton.make("Replace the letter animation", "", true)
	_replace_chip.name = "ReplaceMotion"
	_replace_chip.button_pressed = replace_motion
	_replace_chip.focus_mode = Control.FOCUS_NONE
	PmUI.tip(_replace_chip, "Off, a preset adds its animation on top of the ones already there")
	_replace_chip.pressed.connect(_on_replace)
	var save_btn: Button = PmButton.primary("Save this title as a preset", "plus")
	save_btn.name = "SavePreset"
	save_btn.pressed.connect(_on_save)
	var group_btn: Button = PmButton.make("New group", "folder_new")
	group_btn.name = "NewGroup"
	group_btn.pressed.connect(_on_new_group)
	var row: HBoxContainer = sheet.call("add_buttons")
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(_replace_chip)
	row.add_child(PmUI.spacer())
	row.add_child(group_btn)
	row.add_child(save_btn)
	var close_btn: Button = PmButton.make("Close")
	close_btn.pressed.connect(sheet.close)
	row.add_child(close_btn)
	refill()
	_focus_search.call_deferred()


func _focus_search() -> void:
	if _search != null and is_instance_valid(_search) and _search.is_inside_tree():
		_search.grab_focus()


func target() -> Clip:
	if _doc == null or seq_id.is_empty() or clip_id.is_empty():
		return null
	var s: Sequence = _doc.sequence_by_id(seq_id)
	return s.clip_by_id(clip_id) if s != null else null


func seq() -> Sequence:
	return _doc.sequence_by_id(seq_id) if _doc != null else null


func clip_text() -> String:
	var c: Clip = target()
	if c == null:
		return ""
	var m: MediaItem = _doc.media_by_id(c.media_id)
	var merged: Dictionary = TitleStyle.merged("title", m.props if m != null else {}, c.props, m.label if m != null else "")
	var t: Variant = merged.get("text", "")
	if t is Dictionary:
		return ""
	return String(t)


func refresh() -> void:
	_stale = true
	refill()


func reread() -> void:
	_mine = TextPresetStore.mine(_doc)
	_known = TextPresetStore.load_groups()
	_stale = false


func listing() -> Array[Dictionary]:
	if _stale:
		reread()
	var out: Array[Dictionary] = []
	for p: Dictionary in TextPresets.looks():
		out.append({"id": String(p["id"]), "kind": "built", "label": String(p["label"]), "detail": String(p.get("detail", "")), "group": String(p.get("group", "")), "preset": {}})
	for q: Dictionary in _mine:
		out.append({"id": String(q.get("id", "")), "kind": "mine", "label": String(q.get("label", "Text preset")), "detail": _mine_detail(q), "group": TextPresetStore.group_label(q), "preset": q})
	for r: Dictionary in TextPresets.motion_only():
		out.append({"id": String(r["id"]), "kind": "built", "label": String(r["label"]), "detail": String(r.get("detail", "")), "group": String(r.get("group", "")), "preset": {}})
	return out


func _mine_detail(p: Dictionary) -> String:
	var props: Dictionary = TextPresetStore.props_of(p)
	var n: int = TextAnimators.count(props)
	var out: String = "Your preset, " + str(props.size()) + " values of the look"
	if n == 1:
		return out + " and its letter animation"
	if n > 1:
		return out + " and " + str(n) + " letter animations"
	return out


func groups() -> PackedStringArray:
	if _stale:
		reread()
	var out: PackedStringArray = PackedStringArray([ALL_GROUP])
	out.append_array(TextPresets.groups())
	for g: String in _known:
		if not out.has(g):
			out.append(g)
	for p: Dictionary in _mine:
		var g2: String = TextPresetStore.group_label(p)
		if not out.has(g2):
			out.append(g2)
	return out


func matches(r: Dictionary) -> bool:
	if query.is_empty():
		return true
	return String(r["label"]).to_lower().contains(query) or String(r["detail"]).to_lower().contains(query)


func refill() -> void:
	var t0: int = Time.get_ticks_usec()
	last_group = group
	_hover = -1
	set_process(false)
	_fill_chips()
	PmUI.clear(_list)
	rows = []
	var text: String = clip_text()
	var all: Array[Dictionary] = listing()
	for g: String in groups():
		if g == ALL_GROUP or (group != ALL_GROUP and g != group):
			continue
		var here: Array[Dictionary] = []
		for r: Dictionary in all:
			if String(r["group"]) == g and matches(r):
				here.append(r)
		if here.is_empty():
			continue
		_list.add_child(PmLabel.meta(g + "  (" + str(here.size()) + ")", "text_dim"))
		for r2: Dictionary in here:
			var row: Dictionary = r2.duplicate(true)
			row["clip"] = TextPresets.preview_clip(String(r2["id"]), text) if String(r2["kind"]) == "built" else _mine_clip(r2, text)
			rows.append(row)
			_list.add_child(_row_box(rows.size() - 1))
	if rows.is_empty():
		_list.add_child(PmLabel.dim("No preset matches that"))
	last_fill_usec = Time.get_ticks_usec() - t0
	_sync_foot(rows.size(), all.size())


func _mine_clip(r: Dictionary, text: String) -> Clip:
	var c: Clip = Clip.new()
	c.id = "textpreview"
	c.media_id = String(r["id"])
	c.duration = TextPresets.LOOP_SECONDS
	var props: Dictionary = TitleStyle.title_defaults()
	props["text"] = TextPresets.sample_text(text)
	c.props = TextPresetStore.applied_to(props, r["preset"], {"replace_motion": true})
	return c


func _sync_foot(shown: int, total: int) -> void:
	if _foot == null:
		return
	var c: Clip = target()
	if c == null:
		_foot.text = "Select a title to put a preset on it"
		return
	_foot.text = "%d of %d presets. Click one to put it on this title. Hover a picture to watch it move." % [shown, total]


func _fill_chips() -> void:
	PmUI.clear(_chips)
	for g: String in groups():
		var b: Button = PmButton.make(g, "", true)
		b.name = ("Chip_" + g).validate_node_name()
		b.button_pressed = g == group
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_group.bind(g))
		b.gui_input.connect(_on_chip_input.bind(g, b))
		if _known.has(g):
			PmUI.tip(b, "Right click to rename or remove this group")
		_chips.add_child(b)


func _row_box(i: int) -> Control:
	var r: Dictionary = rows[i]
	var holder: PanelContainer = PmUI.panel("bg_panel_alt")
	holder.name = "Row_" + String(r["id"])
	var sb: StyleBoxFlat = holder.get_theme_stylebox("panel")
	sb.set_corner_radius_all(Tk.px(Tk.sz("radius_row")))
	sb.border_color = Tk.c["border"]
	sb.set_border_width_all(1)
	sb.content_margin_left = float(Tk.px(6.0))
	sb.content_margin_right = float(Tk.px(6.0))
	sb.content_margin_top = float(Tk.px(5.0))
	sb.content_margin_bottom = float(Tk.px(5.0))
	var line: HBoxContainer = PmUI.hbox(Tk.px(8.0))
	var cell: Control = Control.new()
	cell.name = "Cell_" + String(r["id"])
	cell.custom_minimum_size = Vector2(float(Tk.px(CELL_W)), float(Tk.px(CELL_H)))
	cell.clip_contents = true
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.draw.connect(_on_cell_draw.bind(i, cell))
	cell.mouse_entered.connect(_on_cell_in.bind(i))
	cell.mouse_exited.connect(_on_cell_out.bind(i))
	cell.gui_input.connect(_on_input.bind(i))
	rows[i]["cell"] = cell
	line.add_child(cell)
	var words: VBoxContainer = PmUI.vbox(Tk.px(1.0))
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title: Label = PmLabel.trim(String(r["label"]), "text_bright")
	words.add_child(title)
	var detail: Label = PmLabel.small(String(r["detail"]))
	PmLabel.set_colour(detail, "text_faint")
	words.add_child(detail)
	line.add_child(words)
	var use: Button = PmButton.make("Use")
	use.name = "Use_" + String(r["id"])
	use.pressed.connect(_on_use.bind(i))
	line.add_child(use)
	if String(r["kind"]) == "mine":
		var more: Button = PmButton.make("", "more")
		more.name = "More_" + String(r["id"])
		more.set("quiet", true)
		PmUI.tip(more, "Rename this preset, move it to another group or remove it")
		more.pressed.connect(_on_more.bind(i, more))
		line.add_child(more)
	holder.add_child(line)
	return holder


func _on_cell_draw(i: int, cell: Control) -> void:
	if i < 0 or i >= rows.size():
		return
	var size: Vector2 = cell.size
	if size.x < 8.0 or size.y < 8.0:
		return
	var bands: int = 12
	var band_h: float = size.y / float(bands)
	for b: int in bands:
		var k: float = float(b) / float(bands - 1)
		cell.draw_rect(Rect2(0.0, float(b) * band_h, size.x, band_h + 1.0), FRAME_LIGHT.lerp(FRAME_DARK, k * k))
	var c: Clip = rows[i]["clip"]
	if c == null:
		return
	var resolved: Dictionary = c.props_at(_time_for(i))
	var vis: Dictionary = TextPresets.scaled(resolved, 1080.0 / TextPresets.PREVIEW_FRAME)
	var shade: Dictionary = TextPresets.shadow_pass(vis)
	TextGlyphs.draw(cell, vis, size, "box")
	if not shade.is_empty():
		TextGlyphs.draw(cell, shade, size, "text")
	TextGlyphs.draw(cell, vis, size, "text")
	draws += 1


func _time_for(i: int) -> float:
	if i == _hover:
		return fposmod(_clock, TextPresets.LOOP_SECONDS)
	return TextPresets.moment(String(rows[i]["id"]))


func _on_cell_in(i: int) -> void:
	_hover = i
	_clock = 0.0
	set_process(true)


func _on_cell_out(i: int) -> void:
	if _hover != i:
		return
	_hover = -1
	set_process(false)
	_redraw(i)


func _redraw(i: int) -> void:
	if i < 0 or i >= rows.size():
		return
	var cell: Variant = rows[i].get("cell", null)
	if cell is Control and is_instance_valid(cell):
		(cell as Control).queue_redraw()


func _process(delta: float) -> void:
	if _hover < 0:
		set_process(false)
		return
	_clock += delta
	_redraw(_hover)


func apply_row(i: int) -> bool:
	if i < 0 or i >= rows.size():
		return false
	var r: Dictionary = rows[i]
	var c: Clip = target()
	var s: Sequence = seq()
	if c == null or s == null or _doc == null:
		return false
	var opts: Dictionary = {"replace_motion": replace_motion}
	var next: Dictionary = {}
	if String(r["kind"]) == "built":
		next = TextPresets.full(c.props, String(r["id"]), c, s.fps, opts)
	else:
		next = TextPresetStore.applied_to(c.props, r["preset"], opts)
	if next.is_empty():
		return false
	var cmd: Command = ClipCmds.SetClipField.new(seq_id, clip_id, "props", next)
	return Verbs.run(_doc, "Apply " + String(r["label"]), [cmd] as Array[Command])


func save_current(label: String, group_name: String) -> bool:
	var c: Clip = target()
	if c == null:
		return false
	var preset: Dictionary = TextPresetStore.made(_doc, c, label, group_name)
	if preset.is_empty() or not TextPresetStore.save(preset):
		Events.toast("That preset could not be saved: " + TextPresetStore.last_refusal)
		return false
	var g: String = TextPresetStore.clean_name(group_name)
	if not g.is_empty() and not TextPresetStore.load_groups().has(g):
		TextPresetStore.add_group(g)
	last_save_group = g
	Events.notice("Preset saved", String(preset["label"]) + " is in " + TextPresetStore.group_label(preset) + ".")
	refresh()
	return true


func _on_use(i: int) -> void:
	if apply_row(i):
		Events.toast(String(rows[i]["label"]) + " is on this title")


func _on_input(event: InputEvent, i: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_on_use(i)


func _on_group(g: String) -> void:
	group = g
	query = ""
	if _search != null:
		_search.text = ""
	refill()


func _on_search(text: String) -> void:
	query = text.strip_edges().to_lower()
	refill()


func _on_replace() -> void:
	replace_motion = _replace_chip.button_pressed


func _on_chip_input(event: InputEvent, g: String, chip: Button) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	if not _known.has(g):
		return
	chip.accept_event()
	var menu: Control = PmMenu.open(chip, [PmMenu.item("rename", "Rename this group"), PmMenu.item("remove", "Remove this group")])
	if menu != null and menu.is_inside_tree():
		menu.connect("picked", _on_group_menu.bind(g))


func _on_group_menu(id: String, g: String) -> void:
	if id == "rename":
		var answer: Variant = await PmUI.form(sheet, "Rename the group", [{"key": "name", "label": "Name", "type": "string", "default": g}] as Array[Dictionary], "Rename")
		if answer is Dictionary and not (answer as Dictionary).is_empty():
			if not TextPresetStore.rename_group(g, String((answer as Dictionary)["name"])):
				Events.toast(TextPresetStore.last_refusal)
			elif group == g:
				group = TextPresetStore.clean_name(String((answer as Dictionary)["name"]))
			refresh()
		return
	if id == "remove":
		var ok: Variant = await PmUI.confirm(sheet, "Remove the group", "The presets in " + g + " are kept, they move to " + TextPresetStore.DEFAULT_GROUP + ".", "Remove")
		if ok is bool and bool(ok):
			TextPresetStore.remove_group(g)
			if group == g:
				group = ALL_GROUP
			refresh()


func _on_new_group() -> void:
	var answer: Variant = await PmUI.form(sheet, "New group", [{"key": "name", "label": "Name", "type": "string", "default": ""}] as Array[Dictionary], "Make the group")
	if not (answer is Dictionary) or (answer as Dictionary).is_empty():
		return
	var name_: String = String((answer as Dictionary).get("name", ""))
	if not TextPresetStore.add_group(name_):
		Events.toast(TextPresetStore.last_refusal)
		return
	group = TextPresetStore.clean_name(name_)
	refresh()


func _on_save() -> void:
	var c: Clip = target()
	if c == null:
		Events.toast("Select a title first")
		return
	var known: String = ", ".join(TextPresetStore.load_groups())
	var fields: Array[Dictionary] = [
		{"key": "label", "label": "Name", "type": "string", "default": _suggest_label()},
		{"key": "group", "label": "Group", "type": "string", "default": last_save_group if not last_save_group.is_empty() else TextPresetStore.DEFAULT_GROUP},
		{"key": "note", "type": "note", "default": "Groups you have: " + known + ". A new name here makes a new group."},
	]
	var answer: Variant = await PmUI.form(sheet, "Save this title as a preset", fields, "Save")
	if not (answer is Dictionary) or (answer as Dictionary).is_empty():
		return
	var a: Dictionary = answer
	save_current(String(a.get("label", "")), String(a.get("group", "")))


func _suggest_label() -> String:
	var line: String = TextPresets.sample_text(clip_text())
	if line == TextPresets.SAMPLE:
		return "Text preset"
	return line


func _on_more(i: int, anchor: Button) -> void:
	var items: Array = [PmMenu.item("rename", "Rename"), PmMenu.separator()]
	var where: PackedStringArray = _known.duplicate()
	if not where.has(TextPresetStore.DEFAULT_GROUP):
		where.append(TextPresetStore.DEFAULT_GROUP)
	for g: String in where:
		items.append(PmMenu.item("to:" + g, "Move to " + g))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("remove", "Remove this preset"))
	var menu: Control = PmMenu.open(anchor, items)
	if menu != null and menu.is_inside_tree():
		menu.connect("picked", _on_more_picked.bind(i))


func _on_more_picked(id: String, i: int) -> void:
	if i < 0 or i >= rows.size():
		return
	var preset: Dictionary = rows[i]["preset"]
	if id.begins_with("to:"):
		move_to_group(preset, id.substr(3))
		return
	if id == "remove":
		var ok: Variant = await PmUI.confirm(sheet, "Remove the preset", "Remove " + String(preset.get("label", "")) + " from your presets?", "Remove")
		if ok is bool and bool(ok):
			if not TextPresetStore.forget(preset):
				Events.toast(TextPresetStore.last_refusal)
			refresh()
		return
	if id == "rename":
		var answer: Variant = await PmUI.form(sheet, "Rename the preset", [{"key": "label", "label": "Name", "type": "string", "default": String(preset.get("label", ""))}] as Array[Dictionary], "Rename")
		if answer is Dictionary and not (answer as Dictionary).is_empty():
			rename_preset(preset, String((answer as Dictionary)["label"]))


func rename_preset(preset: Dictionary, label: String) -> bool:
	var next: Dictionary = TextPresetStore.renamed(preset, label)
	if next.is_empty() or not TextPresetStore.save(next):
		Events.toast("That name could not be used")
		return false
	refresh()
	return true


func move_to_group(preset: Dictionary, g: String) -> bool:
	if not TextPresetStore.save(TextPresetStore.with_group(preset, g)):
		Events.toast("That preset could not be moved")
		return false
	refresh()
	return true

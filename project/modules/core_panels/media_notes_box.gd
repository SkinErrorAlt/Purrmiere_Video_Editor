extends RefCounted

const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const UsageBadges := preload("res://modules/core_panels/bin_views/usage_badges.gd")
const EDIT_NAME := "MediaNotes"
const WHERE_NAME := "MediaWhereUsed"
const HINT := "Notes that stay with this file, like hums at 2:10"
const ROWS_TALL := 3


static func add(grid: GridContainer, doc: Project, m: MediaItem) -> TextEdit:
	if grid == null or doc == null or m == null:
		return null
	grid.add_child(PmLabel.dim("Notes"))
	var edit: TextEdit = TextEdit.new()
	edit.name = EDIT_NAME
	edit.text = m.notes
	edit.placeholder_text = HINT
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size.y = float(Tk.px(20.0)) * float(ROWS_TALL)
	edit.set_meta("media_id", m.id)
	edit.focus_exited.connect(commit.bind(edit))
	edit.gui_input.connect(_on_input.bind(edit))
	grid.add_child(edit)
	var uses: int = UsageBadges.uses_of(doc, m.id).size()
	grid.add_child(PmLabel.dim(""))
	var where: Button = PmButton.make(UsageBadges.USED_LABEL + " (" + str(uses) + ")", "")
	where.name = WHERE_NAME
	where.set("quiet", true)
	where.disabled = uses == 0
	where.pressed.connect(func() -> void: UsageBadges.open_menu(where, Session.doc, m.id, where.get_global_rect().end))
	grid.add_child(where)
	return edit


static func _on_input(event: InputEvent, edit: TextEdit) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ENTER and (event as InputEventKey).ctrl_pressed:
		edit.accept_event()
		commit(edit)


static func commit(edit: TextEdit) -> bool:
	if edit == null or not is_instance_valid(edit):
		return false
	var doc: Project = Session.doc
	var id: String = String(edit.get_meta("media_id", ""))
	if doc == null or id.is_empty():
		return false
	return UsageBadges.set_notes(doc, PackedStringArray([id]), edit.text)


static func editing(grid: Control) -> bool:
	if grid == null or not is_instance_valid(grid):
		return false
	var edit: Node = grid.find_child(EDIT_NAME, false, false)
	return edit is TextEdit and (edit as TextEdit).has_focus()

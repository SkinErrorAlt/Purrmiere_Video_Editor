extends "res://modules/core_panels/panel_base.gd"

var _list: VBoxContainer = null
var _scroll: ScrollContainer = null
var _queued: bool = false


func _build(root_: Control) -> void:
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	head.add_child(PmLabel.tight("History", "text_bright"))
	head.add_child(PmUI.spacer())
	var undo: Button = quiet_icon("undo", "Undo", Cmd.keys_text("edit.undo"))
	undo.pressed.connect(_on_undo)
	head.add_child(undo)
	var redo: Button = quiet_icon("redo", "Redo", Cmd.keys_text("edit.redo"))
	redo.pressed.connect(_on_redo)
	head.add_child(redo)
	_scroll = vscroll_area(col)
	_list = PmUI.vbox(0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	rebuild()


func _on_undo() -> void:
	Cmd.run("edit.undo")


func _on_redo() -> void:
	Cmd.run("edit.redo")


func entries() -> Array[Dictionary]:
	var d: Project = doc()
	if d == null:
		return []
	return d.undo.history()


func rebuild() -> void:
	if not _alive():
		return
	_queued = false
	PmUI.keep_scroll(_list)
	PmUI.clear(_list)
	var d: Project = doc()
	if d == null:
		_list.add_child(PmLabel.dim("No project"))
		return
	var start: Button = PmButton.make("Opened " + d.name)
	start.set("quiet", true)
	start.alignment = HORIZONTAL_ALIGNMENT_LEFT
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(_on_jump.bind(-1))
	_list.add_child(start)
	var current: int = d.undo.current_index()
	for e: Dictionary in entries():
		var i: int = int(e["index"])
		var b: Button = PmButton.make(String(e["label"]))
		b.set("quiet", true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set("active", bool(e["current"]))
		if i > current:
			b.add_theme_color_override("font_color", Tk.c["text_faint"])
		b.pressed.connect(_on_jump.bind(i))
		_list.add_child(b)


func _on_jump(index: int) -> void:
	var d: Project = doc()
	if d != null:
		d.undo.jump(index)


func _queue() -> void:
	if _queued or not _alive():
		return
	_queued = true
	_root.get_tree().process_frame.connect(rebuild, CONNECT_ONE_SHOT)


func _on_history() -> void:
	_queue()


func _on_project_changed() -> void:
	rebuild()

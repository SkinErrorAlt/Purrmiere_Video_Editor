extends "res://modules/core_panels/panel_base.gd"

const CW := preload("res://doc/clip_warnings.gd")
const Warn := preload("res://ui/timeline/timeline_warnings.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const FILTERS: PackedStringArray = ["open", "done", "all"]
const TEXT_MAX_W := 260.0

var filter_mode: String = "open"
var rows: Array[Dictionary] = []
var _drop: Button = null
var _where: Label = null
var _list: VBoxContainer = null
var _count: Label = null
var _queued: bool = false
var rebuilds: int = 0


func _build(root_: Control) -> void:
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_drop = PmDrop.make_drop([PmDrop.choice("open", "Open"), PmDrop.choice("done", "Done"), PmDrop.choice("all", "All")], filter_mode)
	_drop.connect("changed", _on_filter)
	PmUI.tip(_drop, "Which warnings to list")
	head.add_child(_drop)
	_where = PmLabel.trim("", "text_dim")
	_where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_where)
	var more: Button = quiet_icon("more", "More")
	more.pressed.connect(_on_more.bind(more))
	head.add_child(more)
	var scroll: ScrollContainer = vscroll_area(col)
	_list = PmUI.vbox(0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	col.add_child(PmUI.divider())
	_count = PmLabel.dim("")
	_count.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_count.clip_text = true
	_count.custom_minimum_size = Vector2(0, 0)
	col.add_child(PmUI.inset(_count))
	rebuild()


func set_filter(id: String) -> void:
	if not FILTERS.has(id):
		return
	filter_mode = id
	if _drop != null:
		_drop.call("set_value", id, false)
	rebuild()


func _on_filter(id: String) -> void:
	set_filter(id)


func entries() -> Array[Dictionary]:
	return CW.entries(doc(), seq(), filter_mode)


func rebuild() -> void:
	if not _alive():
		return
	_queued = false
	rebuilds += 1
	PmUI.keep_scroll(_list)
	PmUI.clear(_list)
	var s: Sequence = seq()
	_where.text = s.label if s != null else ""
	rows = entries()
	for i: int in rows.size():
		_list.add_child(_row(rows[i], i))
		_list.add_child(PmUI.divider())
	if rows.is_empty():
		var empty: Label = PmLabel.dim(_empty_text())
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(PmUI.inset(empty))
	var all: Array[Dictionary] = CW.entries(doc(), s, "all")
	var open_n: int = 0
	for e: Dictionary in all:
		if not bool(e["done"]):
			open_n += 1
	_count.text = str(open_n) + " open, " + str(all.size() - open_n) + " done"


func _empty_text() -> String:
	if filter_mode == "done":
		return "No warnings are done yet"
	if filter_mode == "all":
		return "No warnings. Right click a clip, Warning, to add one."
	return "No open warnings. Right click a clip, Warning, to add one."


func _row(e: Dictionary, i: int) -> Control:
	var done: bool = bool(e["done"])
	var row: HBoxContainer = PmUI.hbox()
	row.name = "WarningRow" + str(i)
	row.custom_minimum_size = Vector2(0.0, float(Tk.px(Tk.sz("row_h"))) + 6.0)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(_on_row_input.bind(i))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(float(Tk.px(2.0)), 0.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var badge := Warn.Badge.new()
	badge.done = done
	row.add_child(badge)
	var tcb: Button = PmButton.make(tc(CW.shown_time(e)))
	tcb.set("quiet", true)
	tcb.add_theme_font_override("font", Tk.font("mono"))
	tcb.pressed.connect(_on_jump.bind(i))
	PmUI.tip(tcb, "Go to this clip")
	row.add_child(tcb)
	var track: Label = PmLabel.faint(CW.shown_track(e))
	track.custom_minimum_size = Vector2(float(Tk.px(24.0)), 0.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(track)
	var where: String = String(e["clip_label"])
	if not String(e.get("nest_label", "")).is_empty():
		where = "in " + String(e["nest_label"]) + ", " + where
	var text: Label = PmLabel.trim(String(e["text"]), "text_faint" if done else "text")
	text.size_flags_horizontal = Control.SIZE_FILL
	text.custom_minimum_size.x = minf(ceilf(PmText.width_of(Tk.font("body"), text.text, Tk.fs(Tk.sz("font_body")))) + 2.0, float(Tk.px(TEXT_MAX_W)))
	text.mouse_filter = Control.MOUSE_FILTER_PASS
	PmUI.tip(text, String(e["text"]) + "\n" + where)
	row.add_child(text)
	var clip_l: Label = PmLabel.trim(where, "text_faint")
	clip_l.mouse_filter = Control.MOUSE_FILTER_PASS
	PmUI.tip(clip_l, where)
	row.add_child(clip_l)
	var tick: Button = quiet_icon("undo" if done else "check", "Open again" if done else "Mark done")
	tick.pressed.connect(_on_tick.bind(i))
	row.add_child(tick)
	var del: Button = quiet_icon("trash", "Remove warning")
	del.pressed.connect(_on_remove.bind(i))
	row.add_child(del)
	return row


func _entry(i: int) -> Dictionary:
	return rows[i] if i >= 0 and i < rows.size() else {}


func _on_row_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_jump(i)


func _on_jump(i: int) -> void:
	Warn.jump(_entry(i))


func _target_seq(e: Dictionary) -> Sequence:
	var d: Project = doc()
	if d == null or e.is_empty():
		return null
	return d.sequence_by_id(String(e["seq_id"]))


func _on_tick(i: int) -> void:
	var e: Dictionary = _entry(i)
	var s: Sequence = _target_seq(e)
	if s != null:
		CW.set_done(doc(), s, String(e["clip_id"]), String(e["id"]), not bool(e["done"]))


func _on_remove(i: int) -> void:
	var e: Dictionary = _entry(i)
	var s: Sequence = _target_seq(e)
	if s != null:
		CW.remove(doc(), s, String(e["clip_id"]), String(e["id"]))


func more_items() -> Array:
	var items: Array = []
	var forget: Array = []
	for p: String in Warn.own_presets():
		forget.append(PmMenu.item("forget:" + p, p))
	var sub: Dictionary = PmMenu.sub_item("forget", "Forget a preset", forget)
	if forget.is_empty():
		sub = PmMenu.item("forget", "Forget a preset")
		sub["disabled"] = true
	items.append(sub)
	return items


func _on_more(anchor: Button) -> void:
	var m: Control = PmMenu.open(anchor, more_items())
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_more_picked)


func _on_more_picked(id: String) -> void:
	if id.begins_with("forget:"):
		if Warn.forget_preset(id.substr(7)):
			Events.toast("Preset forgotten")


func _queue() -> void:
	if _queued or not _alive():
		return
	_queued = true
	_root.get_tree().process_frame.connect(rebuild, CONNECT_ONE_SHOT)


func _on_doc_changed(kind: String) -> void:
	if kind == "warnings" or kind == "structure" or kind == "meta":
		_queue()


func _on_history() -> void:
	_queue()


func _on_project_changed() -> void:
	rebuild()


func _on_sequence_changed(_id: String) -> void:
	rebuild()


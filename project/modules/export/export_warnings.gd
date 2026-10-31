extends RefCounted

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Timecode := preload("res://doc/timecode.gd")
const CW := preload("res://doc/clip_warnings.gd")
const Warn := preload("res://ui/timeline/timeline_warnings.gd")
const SHEET_PATH := "res://modules/core_panels/sheet.gd"
const SELF_PATH := "res://modules/export/export_warnings.gd"
const SHEET_W := 540.0
const LIST_MAX_H := 300.0
const ROW_H := 31.0
const TEXT_MAX_W := 220.0

static var passing: bool = false
static var sheet: Control = null
static var shown: Array[Dictionary] = []


static func hold(host: Node, seq: Sequence, go: Callable) -> bool:
	if passing:
		passing = false
		return false
	var d: Project = Session.doc
	if d == null or seq == null:
		return false
	var open: Array[Dictionary] = CW.entries(d, seq, "open")
	if open.is_empty():
		return false
	if sheet != null and is_instance_valid(sheet) and not bool(sheet.call("is_closing")):
		return true
	_open(host if host != null and host.is_inside_tree() else _tree_root(), seq, open, go)
	return true


static func _tree_root() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	return (loop as SceneTree).root if loop is SceneTree else null


static func headline(n: int, seq: Sequence) -> String:
	return (str(n) + " warning is" if n == 1 else str(n) + " warnings are") + " open in " + seq.label + ". Go to one to fix it, or export anyway."


static func _open(host: Node, seq: Sequence, open: Array[Dictionary], go: Callable) -> void:
	shown = open
	var script: GDScript = load(SHEET_PATH)
	if script == null or host == null:
		return
	sheet = script.call("open", host, "Clip warnings are still open", SHEET_W, 0.0)
	sheet.name = "ExportWarningsSheet"
	sheet.call("add_note", headline(open.size(), seq))
	var col: VBoxContainer = sheet.get("col")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = float(Tk.px(minf(ROW_H * float(open.size()), LIST_MAX_H)))
	col.add_child(scroll)
	var list: VBoxContainer = PmUI.vbox(0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var fps: float = seq.fps if seq.fps > 0.0 else 30.0
	var self_script: GDScript = load(SELF_PATH)
	for i: int in open.size():
		var e: Dictionary = open[i]
		var row: HBoxContainer = PmUI.hbox()
		row.name = "WarningRow" + str(i)
		row.custom_minimum_size = Vector2(0.0, float(Tk.px(ROW_H - 1.0)))
		var badge := Warn.Badge.new()
		row.add_child(badge)
		var tcl: Label = PmLabel.dim(Timecode.format(CW.shown_time(e), fps, seq.drop_frame))
		tcl.add_theme_font_override("font", Tk.font("mono"))
		row.add_child(tcl)
		var tr: Label = PmLabel.faint(CW.shown_track(e))
		tr.custom_minimum_size = Vector2(float(Tk.px(24.0)), 0.0)
		row.add_child(tr)
		var where: String = String(e["clip_label"])
		if not String(e.get("nest_label", "")).is_empty():
			where = "in " + String(e["nest_label"]) + ", " + where
		var text: Label = PmLabel.trim(String(e["text"]))
		text.size_flags_horizontal = Control.SIZE_FILL
		text.custom_minimum_size.x = minf(ceilf(PmText.width_of(Tk.font("body"), text.text, Tk.fs(Tk.sz("font_body")))) + 2.0, float(Tk.px(TEXT_MAX_W)))
		PmUI.tip(text, String(e["text"]) + "\n" + where)
		row.add_child(text)
		var clip_l: Label = PmLabel.trim(where, "text_faint")
		PmUI.tip(clip_l, where)
		row.add_child(clip_l)
		var goto: Button = PmButton.make("Go to")
		goto.name = "GoTo"
		goto.pressed.connect(Callable(self_script, "go_to").bind(i))
		row.add_child(goto)
		var edge: Control = Control.new()
		edge.custom_minimum_size = Vector2(float(Tk.px(6.0)), 0.0)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(edge)
		list.add_child(row)
		list.add_child(PmUI.divider())
	var cancel: Button = sheet.call("add_button", "Cancel")
	cancel.name = "Cancel"
	cancel.pressed.connect(Callable(self_script, "close"))
	var anyway: Button = sheet.call("add_button", "Export anyway", true)
	anyway.name = "ExportAnyway"
	anyway.pressed.connect(Callable(self_script, "go_on").bind(go))


static func close() -> void:
	if sheet != null and is_instance_valid(sheet):
		sheet.call("close")
	sheet = null


static func go_to(i: int) -> bool:
	var e: Dictionary = shown[i] if i >= 0 and i < shown.size() else {}
	close()
	Warn.show_panel_of("timeline")
	return Warn.jump(e)


static func go_on(go: Callable) -> void:
	close()
	passing = true
	if go.is_valid():
		go.call()
	passing = false


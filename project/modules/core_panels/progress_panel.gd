extends "res://modules/core_panels/panel_base.gd"

const PREF_BUDGET := "jobs.budget"

var _list: VBoxContainer = null
var _budget: HSlider = null
var _budget_label: Label = null
var _queued: bool = false


func _build(root_: Control) -> void:
	if not Prefs.is_registered(PREF_BUDGET):
		Prefs.register(PREF_BUDGET, 60, {"label": "Background job budget (percent of the machine)", "type": "int", "min": 10, "max": 100})
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	head.add_child(PmLabel.tight("Progress", "text_bright"))
	head.add_child(PmUI.spacer())
	head.add_child(PmLabel.dim("Budget"))
	_budget = HSlider.new()
	_budget.min_value = 10.0
	_budget.max_value = 100.0
	_budget.step = 5.0
	_budget.value = float(int(Prefs.get_value(PREF_BUDGET)))
	_budget.custom_minimum_size = Vector2(float(Tk.px(90.0)), 0.0)
	_budget.focus_mode = Control.FOCUS_NONE
	_budget.value_changed.connect(_on_budget)
	head.add_child(_budget)
	_budget_label = PmLabel.mono(str(int(_budget.value)) + "%", "text_dim")
	head.add_child(_budget_label)
	var scroll: ScrollContainer = vscroll_area(col)
	_list = PmUI.vbox()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	if not Jobs.changed.is_connected(_queue):
		Jobs.changed.connect(_queue)
	PurrBridge.set_job_budget(int(_budget.value))
	rebuild()


func _on_budget(v: float) -> void:
	Prefs.set_value(PREF_BUDGET, int(v))
	_budget_label.text = str(int(v)) + "%"
	PurrBridge.set_job_budget(int(v))


func _queue() -> void:
	if _queued or not _alive():
		return
	_queued = true
	_root.get_tree().process_frame.connect(rebuild, CONNECT_ONE_SHOT)


func live_prefs() -> PackedStringArray:
	return PackedStringArray(["jobs."])


func rebuild() -> void:
	if not _alive():
		return
	_queued = false
	PmUI.keep_scroll(_list)
	PmUI.clear(_list)
	var jobs: Array[Dictionary] = Jobs.list()
	if jobs.is_empty():
		_list.add_child(PmLabel.dim("No jobs are running"))
		return
	for j: Dictionary in jobs:
		var row: VBoxContainer = PmUI.vbox(2)
		var top: HBoxContainer = PmUI.hbox()
		top.add_child(PmLabel.trim(String(j["label"]) if not String(j["label"]).is_empty() else String(j["kind"])))
		top.add_child(PmLabel.dim(String(j["state"])))
		var cancel: Button = quiet_icon("close", "Cancel this job")
		cancel.pressed.connect(_on_cancel.bind(int(j["id"])))
		top.add_child(cancel)
		row.add_child(top)
		var bar: ProgressBar = ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = float(j["progress"])
		bar.show_percentage = true
		bar.custom_minimum_size = Vector2(0.0, 14.0)
		row.add_child(bar)
		_list.add_child(row)


func _on_cancel(id: int) -> void:
	Jobs.cancel(id)

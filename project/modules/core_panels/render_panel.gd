extends "res://modules/core_panels/panel_base.gd"

const VIEW_KEY := "render_regions"
const VIEW_SETTINGS := "render_settings"
const PREF_BUDGET := "render.budget"

var _list: VBoxContainer = null
var _order: Button = null
var _budget: HSlider = null
var _pause: Button = null
var _queued: bool = false


func _build(root_: Control) -> void:
	if not Prefs.is_registered(PREF_BUDGET):
		Prefs.register(PREF_BUDGET, 50, {"label": "Background render budget (percent)", "type": "int", "min": 10, "max": 100})
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	head.add_child(PmLabel.tight("Render regions", "text_bright"))
	head.add_child(PmUI.spacer())
	var add: Button = quiet_icon("plus", "Add a region from the in and out points")
	add.pressed.connect(_on_add)
	head.add_child(add)
	var save: Button = quiet_icon("export", "Save these regions as a preset")
	save.set("icon_px", 14.0)
	save.pressed.connect(_on_save_preset)
	head.add_child(save)
	var bar: HBoxContainer = header_row(col)
	bar.add_child(PmLabel.dim("Order"))
	_order = PmDrop.make_drop([PmDrop.choice("playhead", "Playhead outward"), PmDrop.choice("start", "From the start"), PmDrop.choice("regions", "Regions first")], "playhead")
	_order.connect("changed", _on_order)
	bar.add_child(_order)
	bar.add_child(PmLabel.dim("Budget"))
	_budget = HSlider.new()
	_budget.min_value = 10.0
	_budget.max_value = 100.0
	_budget.step = 5.0
	_budget.value = float(int(Prefs.get_value(PREF_BUDGET)))
	_budget.focus_mode = Control.FOCUS_NONE
	_budget.custom_minimum_size = Vector2(float(Tk.px(80.0)), 0.0)
	_budget.value_changed.connect(_on_budget)
	bar.add_child(_budget)
	_pause = PmButton.make("Pause", "pause", true)
	_pause.set("quiet", true)
	_pause.pressed.connect(_on_pause)
	bar.add_child(_pause)
	var note: Label = PmLabel.wrap("The background render itself lands in stage 3. Regions are kept with the project and drawn on the render bar over the ruler.", "text_dim")
	col.add_child(PmUI.inset(note))
	var scroll: ScrollContainer = vscroll_area(col)
	_list = PmUI.vbox(0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	rebuild()


func regions() -> Array:
	var d: Project = doc()
	if d == null:
		return []
	var raw: Variant = d.view.get(VIEW_KEY, [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	return raw


func settings() -> Dictionary:
	var d: Project = doc()
	if d == null:
		return {}
	var raw: Variant = d.view.get(VIEW_SETTINGS, {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func _set_regions(list: Array) -> void:
	var d: Project = doc()
	if d == null:
		return
	d.view[VIEW_KEY] = list
	rebuild()
	var tl: Object = bus().panel("timeline")
	if tl != null and tl.get("canvas") != null:
		(tl.get("canvas") as Control).queue_redraw()


func _on_add() -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var a: float = s.in_point if s.in_point >= 0.0 else 0.0
	var b: float = s.out_point if s.out_point >= 0.0 else s.duration()
	if b <= a:
		Events.toast("Set in and out first")
		return
	var list: Array = regions().duplicate(true)
	list.append({"id": d.mint_id("r"), "seq_id": s.id, "name": "Region " + str(list.size() + 1), "start": a, "end": b, "settings": "default", "progress": 0.0})
	_set_regions(list)


func _on_remove(id: String) -> void:
	var list: Array = []
	for r: Variant in regions():
		if String((r as Dictionary).get("id", "")) != id:
			list.append(r)
	_set_regions(list)


func _on_go(t: float) -> void:
	Session.set_playhead(t)


func _on_order(id: String) -> void:
	var d: Project = doc()
	if d == null:
		return
	var st: Dictionary = settings().duplicate(true)
	st["order"] = id
	d.view[VIEW_SETTINGS] = st


func _on_budget(v: float) -> void:
	Prefs.set_value(PREF_BUDGET, int(v))


func _on_pause() -> void:
	var d: Project = doc()
	if d == null:
		return
	var st: Dictionary = settings().duplicate(true)
	st["paused"] = _pause.button_pressed
	d.view[VIEW_SETTINGS] = st


func _on_save_preset() -> void:
	var d: Project = doc()
	if d == null or regions().is_empty():
		Events.toast("Add a region first")
		return
	var preset: Dictionary = Presets.make("composition", "Render regions", {"regions": regions().duplicate(true), "settings": settings()})
	preset["kind"] = "export"
	if Presets.save_to_user(preset):
		Events.toast("Saved the regions as a preset")


func rebuild() -> void:
	if not _alive():
		return
	_queued = false
	PmUI.keep_scroll(_list)
	PmUI.clear(_list)
	var s: Sequence = seq()
	var st: Dictionary = settings()
	_order.call("set_value", String(st.get("order", "playhead")), false)
	_pause.button_pressed = bool(st.get("paused", false))
	var shown: int = 0
	for r: Variant in regions():
		var rd: Dictionary = r
		if s != null and String(rd.get("seq_id", s.id)) != s.id:
			continue
		shown += 1
		var row: HBoxContainer = PmUI.hbox()
		row.custom_minimum_size = Vector2(0.0, float(Tk.px(Tk.sz("row_h"))) + 4.0)
		var go: Button = PmButton.make(String(rd.get("name", "Region")))
		go.set("quiet", true)
		go.pressed.connect(_on_go.bind(float(rd.get("start", 0.0))))
		row.add_child(go)
		row.add_child(PmLabel.mono(tc(float(rd.get("start", 0.0))) + " to " + tc(float(rd.get("end", 0.0))), "text_dim"))
		row.add_child(PmLabel.faint(String(rd.get("settings", "default"))))
		var bar: ProgressBar = ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = float(rd.get("progress", 0.0))
		bar.custom_minimum_size = Vector2(float(Tk.px(60.0)), 10.0)
		bar.show_percentage = false
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var del: Button = quiet_icon("trash", "Remove region")
		del.pressed.connect(_on_remove.bind(String(rd.get("id", ""))))
		row.add_child(del)
		_list.add_child(row)
		_list.add_child(PmUI.divider())
	if shown == 0:
		_list.add_child(PmLabel.wrap("No regions on this sequence. Mark in and out, then press plus.", "text_dim"))


func _queue() -> void:
	if _queued or not _alive():
		return
	_queued = true
	_root.get_tree().process_frame.connect(rebuild, CONNECT_ONE_SHOT)


func _on_project_changed() -> void:
	rebuild()


func _on_sequence_changed(_id: String) -> void:
	rebuild()

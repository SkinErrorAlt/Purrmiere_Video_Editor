extends Node

signal found(total: int)

const Project := preload("res://doc/project.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const Find := preload("res://doc/picture_find.gd")
const Found := preload("res://doc/found_regions.gd")
const FindJob := preload("res://engine/picture_find_job.gd")
const SampleTake := preload("res://modules/core_panels/organizer/sample_take.gd")
const Sheet := preload("res://modules/core_panels/sheet.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const SELF_PATH := "res://modules/core_panels/organizer/find_sheet.gd"
const WIDTH := 640.0
const LABEL_W := 150.0
const THUMB := Vector2(144.0, 84.0)
const MARK_DROP := "drop"
const MARK_FOCUS := "focus"
const MARK_ONE := "one"

var panel: Object = null
var doc: Project = null
var kind: String = ""
var spec: Dictionary = {}
var sheet: Control = null
var mark_mode: String = MARK_DROP
var _samples_row: Container = null
var _kind_drop: Button = null
var _note: Label = null
var _cut_box: CheckBox = null
var _auto_box: CheckBox = null
var _both_box: CheckBox = null
var _view_box: CheckBox = null
var _layout_b: Button = null
var _capture: Dictionary = {}
var _jobs: Array = []
var _found_total: int = 0
var _serial: int = -1


static func open(host: Node, p_panel: Object, p_doc: Project, p_kind: String) -> Node:
	var script: GDScript = load(SELF_PATH)
	var s: Node = script.new()
	s.call("build", host, p_panel, p_doc, p_kind)
	return s


func build(host: Node, p_panel: Object, p_doc: Project, p_kind: String) -> void:
	name = "FindPictureSheet"
	panel = p_panel
	doc = p_doc
	kind = p_kind
	spec = Found.spec_of(kind)
	sheet = Sheet.open(host, "Find a picture", WIDTH)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", Tk.px(10.0))
	grid.add_theme_constant_override("v_separation", Tk.px(Tk.sz("pad")))
	col.add_child(grid)
	var choices: Array = []
	for k: Dictionary in Kinds.kinds():
		choices.append(PmDrop.choice(String(k["id"]), String(k["name"])))
	_kind_drop = PmDrop.make_drop(choices, kind)
	_kind_drop.connect("changed", _on_kind)
	_row(grid, "Mark what is found as", _kind_drop)
	var near: Control = PmField.make(float(spec["threshold"]) * 100.0, 30.0, 99.5, 0.5, " %")
	near.connect("value_changed", func(v: float) -> void: _set_spec("threshold", v / 100.0))
	_row(grid, "How close it must look", near)
	var shortest: Control = PmField.make(float(spec["min_len"]), 0.0, 600.0, 0.1, " s")
	shortest.connect("value_changed", func(v: float) -> void: _set_spec("min_len", v))
	_row(grid, "Shortest part", shortest)
	var join: Control = PmField.make(float(spec["gap"]), 0.0, 600.0, 0.1, " s")
	join.connect("value_changed", func(v: float) -> void: _set_spec("gap", v))
	_row(grid, "Join parts closer than", join)
	col.add_child(PmLabel.dim("Sample pictures. Drag on one to leave out a part, right click to remove it."))
	var modes: HBoxContainer = PmUI.hbox()
	col.add_child(modes)
	for m: Array in [[MARK_DROP, "Leave out a part of every sample"], [MARK_ONE, "Leave out a part of this sample"], [MARK_FOCUS, "Only look at a part"]]:
		var b: Button = PmButton.make(String(m[1]), "", true)
		b.set("quiet", true)
		b.button_pressed = String(m[0]) == mark_mode
		b.pressed.connect(_on_mark_mode.bind(String(m[0]), modes))
		b.set_meta("mode", String(m[0]))
		modes.add_child(b)
	_samples_row = PmUI.flow(Tk.px(6.0), Tk.px(6.0))
	col.add_child(_samples_row)
	var add_row: HBoxContainer = PmUI.hbox()
	col.add_child(add_row)
	var add_b: Button = PmButton.make("Add the frame at the organizer cursor", "plus")
	add_b.pressed.connect(add_from_cursor)
	add_row.add_child(add_b)
	var file_b: Button = PmButton.make("Add a picture file...", "image")
	file_b.set("quiet", true)
	PmUI.tip(file_b, "Use a screenshot or any picture as a sample. Right click the Source or Program picture to use the frame shown there.")
	file_b.pressed.connect(func() -> void: SampleTake.choose_image(sheet, kind))
	add_row.add_child(file_b)
	var clear_b: Button = PmButton.make("Clear the parts left out")
	clear_b.set("quiet", true)
	clear_b.pressed.connect(_on_clear_marks)
	add_row.add_child(clear_b)
	_cut_box = _check(col, "The parts found are cuts in the editor", bool(spec["cut"]), "cut")
	_view_box = _check(col, "Look in each Pair View view on its own", true, "")
	_both_box = _check(col, "With Pair View, cut only where every view shows it", bool(spec["both"]), "both")
	_layout_b = PmButton.make("Pair View layout to look in...", "film")
	_layout_b.set("quiet", true)
	PmUI.tip(_layout_b, "A video used by several clips whose Pair View views differ: pick which clip's views are looked in")
	_layout_b.pressed.connect(open_layout_menu)
	col.add_child(_layout_b)
	_layout_b.visible = not layout_choices().is_empty()
	_auto_box = _check(col, "Look for these in every video added from now on", bool(spec["auto"]), "auto")
	_note = sheet.call("add_note", "")
	var switch_b: Button = sheet.call("add_button", "Find scene switches")
	switch_b.pressed.connect(find_switches)
	var close_b: Button = sheet.call("add_button", "Close")
	close_b.pressed.connect(func() -> void: sheet.call("close"))
	var go: Button = sheet.call("add_button", "Find", true)
	go.pressed.connect(find_now)
	rebuild_samples()
	_update_note()
	_serial = Kinds.serial
	set_process(true)


func _row(grid: GridContainer, label: String, control: Control) -> void:
	var l: Label = PmLabel.body(label)
	l.custom_minimum_size.x = float(Tk.px(LABEL_W))
	grid.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _check(col: VBoxContainer, text: String, on: bool, key: String) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = on
	cb.focus_mode = Control.FOCUS_NONE
	if not key.is_empty():
		cb.toggled.connect(func(v: bool) -> void: _set_spec(key, v))
	col.add_child(cb)
	return cb


func _set_spec(key: String, v: Variant) -> void:
	spec = Found.spec_of(kind)
	spec[key] = v
	Found.save_spec(kind, spec)


func _on_kind(id: String) -> void:
	kind = id
	spec = Found.spec_of(kind)
	_cut_box.set_pressed_no_signal(bool(spec["cut"]))
	_auto_box.set_pressed_no_signal(bool(spec["auto"]))
	_both_box.set_pressed_no_signal(bool(spec["both"]))
	rebuild_samples()
	_update_note()


func _on_mark_mode(m: String, row: HBoxContainer) -> void:
	mark_mode = m
	for b: Node in row.get_children():
		if b is Button:
			(b as Button).set_pressed_no_signal(String(b.get_meta("mode", "")) == m)


func _on_clear_marks() -> void:
	spec["drop"] = []
	spec["focus"] = []
	for f: Variant in spec["frames"]:
		(f as Dictionary)["drop"] = []
	Found.save_spec(kind, spec)
	rebuild_samples()


func rebuild_samples() -> void:
	if _samples_row == null:
		return
	PmUI.clear(_samples_row)
	var frames: Array = spec.get("frames", [])
	for i: int in frames.size():
		var s: Dictionary = Find.sample_from_dict(frames[i])
		if s.is_empty():
			continue
		var v := SampleView.new()
		v.custom_minimum_size = THUMB
		v.texture = ImageTexture.create_from_image(Find.sample_image(s))
		v.own_drop = Find.rects(s.get("drop", []))
		v.all_drop = Find.rects(spec.get("drop", []))
		v.focus = Find.rects(spec.get("focus", []))
		v.index = i
		v.connect("marked", _on_marked)
		v.connect("remove_asked", _on_remove)
		_samples_row.add_child(v)
	if frames.is_empty():
		_samples_row.add_child(PmLabel.dim("No samples yet. Park the organizer cursor on the picture and add it, add a picture file, or right click the Source or Program picture."))


func _on_marked(index: int, r: Rect2) -> void:
	if r.size.x < 0.02 or r.size.y < 0.02:
		return
	if mark_mode == MARK_ONE:
		var f: Dictionary = (spec["frames"] as Array)[index]
		var own: Array = f.get("drop", []) if f.get("drop") is Array else []
		own.append(Find.rect_array(r))
		f["drop"] = own
	elif mark_mode == MARK_FOCUS:
		(spec["focus"] as Array).append(Find.rect_array(r))
	else:
		(spec["drop"] as Array).append(Find.rect_array(r))
	Found.save_spec(kind, spec)
	rebuild_samples()


func _on_remove(index: int) -> void:
	var frames: Array = spec["frames"]
	if index >= 0 and index < frames.size():
		frames.remove_at(index)
		Found.save_spec(kind, spec)
		rebuild_samples()
		_update_note()


func add_from_cursor() -> bool:
	var canvas: Object = panel.get("canvas") if panel != null else null
	if canvas == null or doc == null:
		return false
	var mid: String = String(canvas.get("cursor_media"))
	var item: MediaItem = doc.media_by_id(mid)
	if item == null or item.path.is_empty():
		_say("Click a video in the organizer first, on the frame you want.")
		return false
	if not FindJob.available():
		_say("The picture engine is not loaded, so no frames can be read.")
		return false
	_capture = FindJob.capture(item.path, float(canvas.get("cursor_t")))
	if _capture.is_empty():
		_say("That frame could not be read.")
		return false
	_say("Reading the frame...")
	return true


func _process(_dt: float) -> void:
	if Kinds.serial != _serial:
		_serial = Kinds.serial
		spec = Found.spec_of(kind)
		rebuild_samples()
		_update_note()
	if _capture.is_empty():
		return
	if not FindJob.capture_ready(_capture):
		return
	var s: Dictionary = FindJob.capture_take(_capture)
	_capture = {}
	if s.is_empty():
		_say("That frame could not be read yet. Try again in a moment.")
		return
	Found.add_sample(kind, s)
	spec = Found.spec_of(kind)
	rebuild_samples()
	_update_note()


func _say(text: String) -> void:
	if _note != null and is_instance_valid(_note):
		_note.text = text


func _update_note() -> void:
	var n: int = (spec.get("frames", []) as Array).size()
	_say("%d sample%s. Found parts are marked as %s in each video the organizer shows." % [n, "" if n == 1 else "s", Kinds.name_of(kind)])


func targets() -> Array[MediaItem]:
	var out: Array[MediaItem] = []
	if doc == null or panel == null:
		return out
	for id: String in (panel.call("shown_ids") as PackedStringArray):
		var m: MediaItem = doc.media_by_id(id)
		if m != null and m.kind == "video" and not m.path.is_empty():
			out.append(m)
	return out


func layout_choices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: MediaItem in targets():
		var list: Array[Dictionary] = Found.pair_layouts(doc, m.id)
		if list.size() > 1:
			out.append({"media": m, "layouts": list})
	return out


func layout_menu_items() -> Array:
	var items: Array = []
	var choices: Array[Dictionary] = layout_choices()
	for ch: Dictionary in choices:
		var m: MediaItem = ch["media"]
		var want: String = Found.chosen_layout(m)
		var sub: Array = []
		var layouts: Array[Dictionary] = ch["layouts"]
		for i: int in layouts.size():
			var l: Dictionary = layouts[i]
			var on: bool = String(l["key"]) == want or (i == 0 and want.is_empty())
			var text: String = String(l["label"]) + (" (and %d more clips)" % (int(l["clips"]) - 1) if int(l["clips"]) > 1 else "")
			sub.append(PmMenu.check_item("pl:" + m.id + "|" + String(l["key"]), text, on))
		if choices.size() == 1:
			items.append_array(sub)
		else:
			items.append(PmMenu.sub_item("pl_media:" + m.id, m.label, sub))
	return items


func open_layout_menu() -> Control:
	var items: Array = layout_menu_items()
	if items.is_empty() or _layout_b == null:
		return null
	var menu: Control = PmMenu.open(_layout_b, items)
	if menu != null and menu.is_inside_tree():
		menu.connect("picked", on_layout_picked)
	return menu


func on_layout_picked(id: String) -> bool:
	if not id.begins_with("pl:"):
		return false
	var rest: String = id.substr(3)
	var bar: int = rest.find("|")
	if bar < 0:
		return false
	return Found.choose_layout(doc, rest.substr(0, bar), rest.substr(bar + 1))


func find_now() -> int:
	if Found.samples(spec).is_empty():
		_say("Add at least one sample picture first.")
		return 0
	return _start(false)


func find_switches() -> int:
	return _start(true)


func _start(switching: bool) -> int:
	var list: Array[MediaItem] = targets()
	if list.is_empty():
		_say("The organizer shows no videos to look through.")
		return 0
	_found_total = 0
	for m: MediaItem in list:
		var js: Dictionary = Found.switch_spec(m) if switching else Found.job_spec(doc, m, kind, _view_box.button_pressed)
		var job: RefCounted = FindJob.start(js)
		_jobs.append(job)
		job.connect("finished", _on_job_finished.bind(js, job))
	_say("Looking through %d video%s, watch the Progress panel." % [list.size(), "" if list.size() == 1 else "s"])
	return list.size()


func _on_job_finished(result: Dictionary, js: Dictionary, job: RefCounted) -> void:
	_jobs.erase(job)
	var n: int = Found.apply_result(doc, js, result)
	if n > 0:
		_found_total += n
	if not bool(result.get("ok", false)) and String(result.get("error", "")) != "cancelled":
		Events.toast("Find stopped: " + String(result.get("error", "")))
	if _jobs.is_empty():
		Events.toast("Found %d part%s" % [_found_total, "" if _found_total == 1 else "s"])
		found.emit(_found_total)
		if is_inside_tree():
			_say("Found %d part%s." % [_found_total, "" if _found_total == 1 else "s"])


class SampleView:
	extends Control

	signal marked(index: int, r: Rect2)
	signal remove_asked(index: int)

	var texture: Texture2D = null
	var index: int = 0
	var own_drop: Array[Rect2] = []
	var all_drop: Array[Rect2] = []
	var focus: Array[Rect2] = []
	var _from: Vector2 = Vector2(-1.0, -1.0)
	var _to: Vector2 = Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)

	func _norm(p: Vector2) -> Vector2:
		return Vector2(clampf(p.x / maxf(size.x, 1.0), 0.0, 1.0), clampf(p.y / maxf(size.y, 1.0), 0.0, 1.0))

	func _on_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				remove_asked.emit(index)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_from = _norm(mb.position)
					_to = _from
				elif _from.x >= 0.0:
					var r: Rect2 = Rect2(_from, Vector2.ZERO).expand(_norm(mb.position))
					_from = Vector2(-1.0, -1.0)
					marked.emit(index, r)
				accept_event()
				queue_redraw()
		elif event is InputEventMouseMotion and _from.x >= 0.0:
			_to = _norm((event as InputEventMouseMotion).position)
			queue_redraw()

	func _box(r: Rect2) -> Rect2:
		return Rect2(r.position * size, r.size * size)

	func _draw() -> void:
		if texture != null:
			draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
		for r: Rect2 in focus:
			draw_rect(_box(r), Color(0.3, 0.9, 0.4, 0.9), false, 2.0)
		for r: Rect2 in all_drop:
			draw_rect(_box(r), Color(0.9, 0.2, 0.2, 0.45), true)
		for r: Rect2 in own_drop:
			draw_rect(_box(r), Color(0.95, 0.5, 0.2, 0.45), true)
		if _from.x >= 0.0:
			draw_rect(_box(Rect2(_from, Vector2.ZERO).expand(_to)), Color(1, 1, 1, 0.9), false, 1.5)
		draw_rect(Rect2(Vector2.ZERO, size), Tk.c["border_soft"], false, 1.0)

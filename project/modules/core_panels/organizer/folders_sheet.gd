extends Node

const Project := preload("res://doc/project.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const Smart := preload("res://doc/smart_folders.gd")
const RegionExport := preload("res://doc/region_export.gd")
const FramesJob := preload("res://engine/region_frames_job.gd")
const Sheet := preload("res://modules/core_panels/sheet.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const SELF_PATH := "res://modules/core_panels/organizer/folders_sheet.gd"
const WIDTH := 680.0
const ROW_H := 30.0

var panel: Object = null
var doc: Project = null
var kind: String = ""
var sheet: Control = null
var list_view: Control = null
var _folder_drop: Button = null
var _order_drop: Button = null
var _note: Label = null
var _cut_jobs: Dictionary = {}
var last_sequence: String = ""


static func open(host: Node, p_panel: Object, p_doc: Project, p_kind: String = "") -> Node:
	var s: Node = (load(SELF_PATH) as GDScript).new()
	s.call("build", host, p_panel, p_doc, p_kind)
	return s


func build(host: Node, p_panel: Object, p_doc: Project, p_kind: String) -> void:
	name = "SmartFoldersSheet"
	panel = p_panel
	doc = p_doc
	var folders: Array[Dictionary] = Smart.folders(doc)
	kind = p_kind
	var known: bool = false
	for f: Dictionary in folders:
		if String(f["kind"]) == kind:
			known = true
	if not known:
		kind = String(folders[0]["kind"]) if not folders.is_empty() else ""
	sheet = Sheet.open(host, "Smart folders", WIDTH)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	if folders.is_empty():
		col.add_child(PmLabel.wrap("No regions yet. Each kind of region you mark in the organizer becomes a folder here, across every video and project.", "text_dim"))
		var close0: Button = sheet.call("add_button", "Close", true)
		close0.pressed.connect(func() -> void: sheet.call("close"))
		return
	var head: HBoxContainer = PmUI.hbox()
	col.add_child(head)
	var choices: Array = []
	for f: Dictionary in folders:
		choices.append(PmDrop.choice(String(f["kind"]), "%s  (%d videos, %d parts)" % [String(f["name"]), int(f["files"]), int(f["parts"])]))
	_folder_drop = PmDrop.make_drop(choices, kind)
	_folder_drop.connect("changed", _on_folder)
	_folder_drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_folder_drop)
	_order_drop = PmDrop.make_drop([PmDrop.choice(Smart.BY_RECORDED, "In the order recorded"), PmDrop.choice(Smart.BY_HAND, "In my own order")], Smart.mode(kind))
	_order_drop.connect("changed", _on_order)
	head.add_child(_order_drop)
	col.add_child(PmLabel.dim("Drag a video up or down to put it in your own order."))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0.0, 260.0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	list_view = OrderList.new()
	list_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_view.connect("moved", _on_moved)
	sc.add_child(list_view)
	_note = sheet.call("add_note", "")
	var to_org: Button = sheet.call("add_button", "Show in the organizer")
	to_org.pressed.connect(show_in_organizer)
	var to_seq: Button = sheet.call("add_button", "New sequence of the parts")
	to_seq.pressed.connect(make_sequence)
	var as_files: Button = sheet.call("add_button", "Export as files...")
	as_files.pressed.connect(ask_files)
	var as_frames: Button = sheet.call("add_button", "Export as frames...")
	as_frames.pressed.connect(ask_frames)
	var close_b: Button = sheet.call("add_button", "Close", true)
	close_b.pressed.connect(func() -> void: sheet.call("close"))
	refresh()


func refresh() -> void:
	if list_view == null:
		return
	var rows: Array[Dictionary] = Smart.entries(kind, doc)
	list_view.set("rows", rows)
	list_view.call("relayout")
	var secs: float = 0.0
	var parts: int = 0
	for e: Dictionary in rows:
		for r: Variant in e["regions"]:
			parts += 1
			secs += float((r as Dictionary).get("to", 0.0)) - float((r as Dictionary).get("from", 0.0))
	_say("%d video%s, %d part%s, %s in all." % [rows.size(), "" if rows.size() == 1 else "s", parts, "" if parts == 1 else "s", RegionExport.clock_name(secs)])


func _say(text: String) -> void:
	if _note != null and is_instance_valid(_note):
		_note.text = text


func _on_folder(id: String) -> void:
	kind = id
	_order_drop.call("set_value", Smart.mode(kind), false)
	refresh()


func _on_order(id: String) -> void:
	Smart.set_mode(kind, id)
	refresh()


func _on_moved(key: String, to_index: int) -> void:
	Smart.move(kind, key, to_index, doc)
	_order_drop.call("set_value", Smart.BY_HAND, false)
	refresh()


func paths() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for e: Dictionary in Smart.entries(kind, doc):
		out.append(String(e["path"]))
	return out


func show_in_organizer() -> int:
	var ids: PackedStringArray = RegionExport.ensure_media(doc, paths(), "Bring in the " + Kinds.name_of(kind) + " videos")
	if panel != null and panel.has_method("show_media"):
		panel.call("show_media", ids)
		panel.call("set_kind", kind)
	sheet.call("close")
	return ids.size()


func make_sequence() -> String:
	last_sequence = RegionExport.parts_sequence(doc, kind)
	if last_sequence.is_empty():
		_say("There are no parts to put in a sequence.")
		return ""
	var session: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/Session") if Engine.get_main_loop() is SceneTree else null
	if session != null:
		session.call("set_sequence", last_sequence)
	Events.toast("Made a sequence of the " + Kinds.name_of(kind) + " parts")
	sheet.call("close")
	return last_sequence


func _default_root() -> String:
	var p: PackedStringArray = paths()
	return p[0].get_base_dir() if not p.is_empty() else OS.get_system_dir(OS.SYSTEM_DIR_MOVIES)


func ask_files() -> void:
	var fields: Array[Dictionary] = [
		{"key": "root", "label": "Into the folder", "default": _default_root()},
		{"key": "folder", "label": "New folder name", "default": Kinds.name_of(kind) + " parts"},
		{"key": "prefix", "label": "Start each file name with", "default": Kinds.name_of(kind)},
		{"key": "note", "type": "note", "default": "Each part is copied out of its video without re-encoding, cut on the nearest keyframe."},
	]
	var answered: Signal = PmUI.form(sheet, "Export the parts as files", fields, "Export", "Cancel")
	answered.connect(func(r: Variant) -> void:
		if r is Dictionary:
			export_files(String((r as Dictionary).get("root", "")), String((r as Dictionary).get("folder", "")), String((r as Dictionary).get("prefix", "")))
	)


func export_files(root: String, folder: String, prefix: String) -> int:
	var bridge: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("PurrBridge") if Engine.get_main_loop() is SceneTree else null
	if bridge == null or not bool(bridge.get("available")):
		_say("Exporting needs the native engine.")
		return 0
	var jobs: Array[Dictionary] = RegionExport.clipcut_jobs(kind, root, folder, prefix, doc)
	var n: int = 0
	for j: Dictionary in jobs:
		DirAccess.make_dir_recursive_absolute(String(j["out_dir"]))
		var id: int = int(bridge.call("clipcut", j))
		if id >= 0:
			_cut_jobs[id] = j
			n += (j["ranges"] as Array).size()
	_say("Writing %d part%s, watch the Progress panel." % [n, "" if n == 1 else "s"])
	return n


func ask_frames() -> void:
	var fields: Array[Dictionary] = [
		{"key": "root", "label": "Into the folder", "default": _default_root()},
		{"key": "rate", "label": "Frames each second", "default": "1"},
		{"key": "width", "label": "Width in pixels", "default": "1280"},
		{"key": "names", "label": "Folder names, by commas", "default": ""},
		{"key": "note", "type": "note", "default": "Every part gets its own folder. Leave the names empty to name them after the kind, the video and the time."},
	]
	var answered: Signal = PmUI.form(sheet, "Export the parts as frames", fields, "Export", "Cancel")
	answered.connect(func(r: Variant) -> void:
		if r is Dictionary:
			var rd: Dictionary = r
			var names: PackedStringArray = PackedStringArray()
			for n: String in String(rd.get("names", "")).split(",", false):
				names.append(n.strip_edges())
			export_frames(String(rd.get("root", "")), String(rd.get("rate", "1")).to_float(), int(String(rd.get("width", "1280")).to_int()), names)
	)


func export_frames(root: String, per_second: float, width: int, names: PackedStringArray) -> RefCounted:
	var plan: Array[Dictionary] = RegionExport.frame_plan(kind, root, per_second, names, doc)
	if plan.is_empty():
		_say("There are no parts to export.")
		return null
	var job: RefCounted = FramesJob.start(plan, width, "Frames of the " + Kinds.name_of(kind) + " parts")
	job.connect("finished", func(res: Dictionary) -> void: Events.toast("Wrote %d frames" % int(res.get("written", 0))))
	_say("Writing frames into %d folders, watch the Progress panel." % plan.size())
	return job


class OrderList:
	extends Control

	signal moved(key: String, to_index: int)

	var rows: Array[Dictionary] = []
	var _drag: int = -1
	var _drop: int = -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)

	func relayout() -> void:
		custom_minimum_size = Vector2(0.0, float(rows.size()) * 30.0 + 4.0)
		queue_redraw()

	func index_at(y: float) -> int:
		return clampi(int(floor(y / 30.0)), 0, maxi(rows.size() - 1, 0))

	func _on_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb: InputEventMouseButton = event
			if mb.pressed and not rows.is_empty():
				_drag = index_at(mb.position.y)
				_drop = _drag
			elif not mb.pressed and _drag >= 0:
				var from: int = _drag
				var to: int = _drop
				_drag = -1
				if to != from:
					moved.emit(String(rows[from]["key"]), to)
			accept_event()
			queue_redraw()
		elif event is InputEventMouseMotion and _drag >= 0:
			_drop = index_at((event as InputEventMouseMotion).position.y)
			queue_redraw()

	func _draw() -> void:
		var font: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_small"))
		for i: int in rows.size():
			var e: Dictionary = rows[i]
			var y: float = float(i) * 30.0
			var r: Rect2 = Rect2(0.0, y + 1.0, size.x, 28.0)
			draw_rect(r, Tk.c["bg_panel_high"] if i == _drag else Tk.c["bg_panel_alt"], true)
			var rec: float = float(e.get("recorded", -1.0))
			var when: String = Time.get_datetime_string_from_unix_time(int(rec), true) if rec >= 0.0 else "date unknown"
			var parts: int = (e["regions"] as Array).size()
			PmText.draw_at(self, font, Vector2(10.0, y + 19.0), "%d.  %s" % [i + 1, String(e.get("label", ""))], fs, Tk.c["text"], size.x * 0.6)
			PmText.draw_at(self, font, Vector2(size.x * 0.62, y + 19.0), "%d part%s · %s" % [parts, "" if parts == 1 else "s", when], fs, Tk.c["text_dim"], size.x * 0.37)
		if _drag >= 0 and _drop != _drag:
			var ly: float = float(_drop) * 30.0 + (28.0 if _drop > _drag else 0.0)
			draw_rect(Rect2(0.0, ly, size.x, 2.0), Tk.c["accent"], true)

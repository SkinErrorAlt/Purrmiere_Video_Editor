extends "res://modules/core_panels/panel_base.gd"

const Tags := preload("res://doc/marker_tags.gd")
const TagApply := preload("res://doc/tag_apply.gd")
const LaneKind := preload("res://ui/timeline/marker_lane_kind.gd")
const MarkerLanes := preload("res://ui/timeline/timeline_marker_lanes.gd")
const ExportPresets := preload("res://modules/export/export_presets.gd")
const EditCommands := preload("res://modules/core_panels/edit_commands.gd")
const SORTS: PackedStringArray = ["name", "count", "length", "first"]
const SORT_LABELS: PackedStringArray = ["By name", "Most used first", "Longest first", "In time order"]

var filter: String = ""
var sort_by: String = "first"
var _search: LineEdit = null
var _sort: Button = null
var _list: VBoxContainer = null
var _count: Label = null
var _queued: bool = false
var rows_built: int = 0


static func summary(s: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s == null:
		return out
	var by: Dictionary = {}
	var order: PackedStringArray = PackedStringArray()
	for r: Dictionary in Tags.ranges(s):
		var n: String = String(r["name"])
		if not by.has(n):
			by[n] = {"name": n, "count": 0, "seconds": 0.0, "first": float(r["from"])}
			order.append(n)
		var row: Dictionary = by[n]
		row["count"] = int(row["count"]) + 1
		row["seconds"] = float(row["seconds"]) + float(r["to"]) - float(r["from"])
		row["first"] = minf(float(row["first"]), float(r["from"]))
	for n2: String in order:
		var row2: Dictionary = by[n2]
		var look: Dictionary = Tags.colour_for(s, n2)
		row2["colour"] = int(look["colour"])
		row2["rgb"] = String(look["rgb"])
		out.append(row2)
	return out


static func sorted(list: Array[Dictionary], how: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = list.duplicate()
	if how == "name":
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	elif how == "count":
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["count"]) > int(b["count"]) or (int(a["count"]) == int(b["count"]) and String(a["name"]) < String(b["name"])))
	elif how == "length":
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["seconds"]) > float(b["seconds"]))
	else:
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["first"]) < float(b["first"]))
	return out


static func swatch_colour(row: Dictionary) -> Color:
	var rgb: String = String(row.get("rgb", ""))
	if not rgb.is_empty():
		return Color.from_string(rgb, Tk.c["text"])
	var idx: int = int(row.get("colour", -1))
	return Tk.label_colour(idx) if idx >= 0 else Tk.c["text"]


func _build(root_: Control) -> void:
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_search = PmUI.line_edit("Filter tags")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_on_filter)
	head.add_child(_search)
	var choices: Array = []
	for i: int in SORTS.size():
		choices.append(PmDrop.choice(SORTS[i], SORT_LABELS[i]))
	_sort = PmDrop.make_drop(choices, sort_by)
	_sort.connect("changed", _on_sort)
	head.add_child(_sort)
	var add: Button = quiet_icon("plus", "Tag the range from in to out")
	add.pressed.connect(_on_add)
	head.add_child(add)
	var scroll: ScrollContainer = vscroll_area(col)
	_list = PmUI.vbox(0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	col.add_child(PmUI.divider())
	_count = PmLabel.dim("")
	_count.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_count.clip_text = true
	col.add_child(PmUI.inset(_count))
	rebuild()


func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in sorted(summary(seq()), sort_by):
		if filter.is_empty() or String(r["name"]).to_lower().contains(filter):
			out.append(r)
	return out


func rebuild() -> void:
	if not _alive():
		return
	_queued = false
	PmUI.keep_scroll(_list)
	PmUI.clear(_list)
	var list: Array[Dictionary] = rows()
	var total: int = 0
	for r: Dictionary in list:
		total += int(r["count"])
		_list.add_child(_row(r))
		_list.add_child(PmUI.divider())
	rows_built = list.size()
	if list.is_empty():
		var hint: String = "No tags yet. Ctrl drag across the ruler or a marker lane, or mark in and out and press the plus button, to tag a range." if filter.is_empty() else "No tags match"
		var l: Label = PmLabel.wrap(hint, "text_dim")
		_list.add_child(PmUI.inset(l))
	_count.text = str(list.size()) + (" tag name, " if list.size() == 1 else " tag names, ") + str(total) + (" range" if total == 1 else " ranges")


func _row(r: Dictionary) -> Control:
	var name: String = String(r["name"])
	var row: HBoxContainer = PmUI.hbox()
	row.name = "Tag_" + name.validate_node_name()
	row.custom_minimum_size = Vector2(0.0, float(Tk.px(Tk.sz("row_h"))) + 4.0)
	var swatch: ColorRect = ColorRect.new()
	swatch.color = swatch_colour(r)
	swatch.custom_minimum_size = Vector2(4.0, 0.0)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)
	var pick: Button = PmButton.make(name)
	pick.set("quiet", true)
	pick.name = "Pick"
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pick.pressed.connect(select_all.bind(name))
	PmUI.tip(pick, "Pick every " + name + " tag on the timeline")
	row.add_child(pick)
	var count: Label = PmLabel.faint(str(int(r["count"])) + " x  " + tc(float(r["seconds"])))
	count.name = "Count"
	PmUI.tip(count, "How many times this tag is used, and their total length")
	row.add_child(count)
	var prev: Button = quiet_icon("chev_l", "Go to the previous " + name + " tag")
	prev.pressed.connect(step.bind(name, -1))
	row.add_child(prev)
	var nxt: Button = quiet_icon("chev_r", "Go to the next " + name + " tag")
	nxt.pressed.connect(step.bind(name, 1))
	row.add_child(nxt)
	var more: Button = quiet_icon("more", "Rename, colour, apply effects, export or remove every " + name + " tag")
	more.name = "More"
	more.pressed.connect(_on_more.bind(name, more))
	row.add_child(more)
	return row


static func menu_items(name: String) -> Array:
	var col_sub: Array = []
	for i: int in Tk.LABEL_NAMES.size():
		col_sub.append(PmMenu.item("col:" + str(i), Tk.label_name(i)))
	return [
		PmMenu.item("select", "Pick them all"),
		PmMenu.item("apply", "Apply to every one...", "", "fx"),
		PmMenu.item("export", "Export only these", "", "export"),
		PmMenu.separator(),
		PmMenu.item("rename", "Rename all..."),
		PmMenu.sub_item("col", "Colour all", col_sub),
		PmMenu.separator(),
		PmMenu.item("remove", "Remove every " + name + " tag", "", "trash"),
	]


func _on_more(name: String, from: Control) -> void:
	var m: Control = PmMenu.open(from, menu_items(name))
	if m != null and m.is_inside_tree():
		m.connect("picked", on_menu.bind(name))


func on_menu(id: String, name: String) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return false
	if id == "select":
		return select_all(name)
	if id == "apply":
		var c: Control = canvas()
		if c == null:
			return false
		return MarkerLanes.open_apply_form(c, TagApply.regions_of_tag(s, name), TagApply.key_for(name), "every " + name + " tag")
	if id == "export":
		return export_only(name)
	if id == "rename":
		var fields: Array[Dictionary] = [{"key": "name", "label": "New name", "type": "string", "default": name}]
		var answered: Signal = PmUI.form(_root, "Rename every " + name + " tag", fields, "Rename", "Cancel")
		answered.connect(_on_rename.bind(name))
		return true
	if id.begins_with("col:"):
		return Tags.recolour_all(d, s, name, int(id.substr(4)), "") > 0
	if id == "remove":
		return Tags.remove_all(d, s, name) > 0
	return false


func _on_rename(result: Variant, name: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	Tags.rename_all(doc(), seq(), name, String((result as Dictionary).get("name", "")))


func canvas() -> Control:
	var tl: Object = bus().panel("timeline")
	if tl == null or tl.get("canvas") == null:
		return null
	return tl.get("canvas") as Control


func select_all(name: String) -> bool:
	var s: Sequence = seq()
	var c: Control = canvas()
	if s == null or c == null:
		return false
	var ids: PackedStringArray = PackedStringArray()
	for m: Marker in Tags.of_name(s, name):
		ids.append(m.id)
	c.call("set_marker_selection", ids, false)
	return not ids.is_empty()


func step(name: String, dir: int) -> bool:
	var s: Sequence = seq()
	if s == null:
		return false
	var t: float = Tags.next_time(s, name, s.playhead, dir)
	if t < 0.0:
		return false
	Session.set_playhead(t)
	return true


func export_only(name: String) -> bool:
	var ex: Object = bus().panel("export")
	if ex == null:
		Events.toast("Open the Export panel first")
		return false
	var settings: Dictionary = ex.get("settings")
	ExportPresets.set_tags(settings, PackedStringArray([name]), ExportPresets.tag_mode(settings))
	settings["range"] = ExportPresets.RANGE_TAGS
	if ex.has_method("_refresh"):
		ex.call("_refresh")
	EditCommands.show_panel("export")
	return true


func _on_add() -> void:
	var c: Control = canvas()
	if c != null:
		MarkerLanes.open_tag_form(c, "")


func _on_filter(text: String) -> void:
	filter = text.strip_edges().to_lower()
	rebuild()


func _on_sort(id: String) -> void:
	sort_by = id if SORTS.has(id) else "first"
	rebuild()


func _queue() -> void:
	if _queued or not _alive():
		return
	_queued = true
	_root.get_tree().process_frame.connect(rebuild, CONNECT_ONE_SHOT)


func _on_doc_changed(kind: String) -> void:
	if kind == "markers" or kind == "structure":
		_queue()


func _on_history() -> void:
	_queue()


func _on_project_changed() -> void:
	rebuild()


func _on_sequence_changed(_id: String) -> void:
	rebuild()

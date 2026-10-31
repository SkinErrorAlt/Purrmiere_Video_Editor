extends "res://modules/core_panels/panel_base.gd"

const MarkerCmds := preload("res://doc/commands/marker_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const EditTools := preload("res://doc/commands/edit_tools.gd")
const MarkerLayers := preload("res://doc/marker_layers.gd")
const LaneKind := preload("res://ui/timeline/marker_lane_kind.gd")
const LANE_ALL := "*all"
const LANE_RULER := "*ruler"
const SourceMarks := preload("res://doc/source_marks.gd")

var filter: String = ""
var kind_filter: String = ""
var lane_filter: String = LANE_ALL
var _lane: Button = null
var _lane_sig: String = ""
var _search: LineEdit = null
var _kind: Button = null
var _list: VBoxContainer = null
var _count: Label = null
var _queued: bool = false
var show_source: bool = false
var _source_btn: Button = null


func _build(root_: Control) -> void:
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_search = PmUI.line_edit("Filter markers")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_on_filter)
	head.add_child(_search)
	var kind_choices: Array = [PmDrop.choice("all", "All kinds")]
	for i: int in Marker.KINDS.size():
		kind_choices.append(PmDrop.choice(Marker.KINDS[i], Marker.KIND_LABELS[i]))
	_kind = PmDrop.make_drop(kind_choices, "all")
	_kind.connect("changed", _on_kind)
	head.add_child(_kind)
	_lane = PmDrop.make_drop([PmDrop.choice(LANE_ALL, "All lanes")], LANE_ALL)
	_lane.connect("changed", _on_lane)
	_lane.visible = false
	PmUI.tip(_lane, "Show the markers of one lane")
	head.add_child(_lane)
	_source_btn = toggle_icon("film", "Show the markers of the clip in the Source monitor, or of the item picked in the bin", show_source)
	_source_btn.toggled.connect(_on_source_toggled)
	head.add_child(_source_btn)
	var add: Button = quiet_icon("marker", "Add a marker at the playhead", Cmd.keys_text("marker.add"))
	add.pressed.connect(_on_add)
	head.add_child(add)
	var chapters: Button = quiet_icon("export", "Copy the chapter markers to the clipboard as a YouTube chapter list")
	chapters.set("icon_px", 14.0)
	chapters.pressed.connect(_on_copy_chapters)
	head.add_child(chapters)
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
	if not bus().source_requested.is_connected(_on_source_changed):
		bus().source_requested.connect(_on_source_changed)
	if not bus().focus_changed.is_connected(_on_focus_moved):
		bus().focus_changed.connect(_on_focus_moved)
	rebuild()


func _on_source_toggled(on: bool) -> void:
	show_source = on
	rebuild()


func _on_source_changed(_id: String, _in_t: float, _out_t: float) -> void:
	if show_source:
		_queue()


func _on_focus_moved(_panel_id: String) -> void:
	if show_source:
		_queue()


func source_item() -> MediaItem:
	var d: Project = doc()
	if d == null:
		return null
	var src: Object = bus().panel("source")
	if src != null:
		var id: String = String(src.get("media_id"))
		if not id.is_empty() and d.media_by_id(id) != null:
			return d.media_by_id(id)
	var bin: Object = bus().panel("bin")
	if bin != null:
		var raw: Variant = bin.get("selected_ids")
		if raw is PackedStringArray and not (raw as PackedStringArray).is_empty():
			return d.media_by_id((raw as PackedStringArray)[0])
	return null


func source_markers() -> Array[Marker]:
	var out: Array[Marker] = []
	var item: MediaItem = source_item()
	if item == null:
		return out
	for m: Marker in item.markers:
		if not kind_filter.is_empty() and m.kind != kind_filter:
			continue
		if not filter.is_empty() and not (m.label.to_lower().contains(filter) or m.comment.to_lower().contains(filter)):
			continue
		out.append(m)
	return out


func _rebuild_source() -> void:
	var item: MediaItem = source_item()
	var list: Array[Marker] = source_markers()
	for m: Marker in list:
		var row: HBoxContainer = PmUI.hbox()
		row.custom_minimum_size = Vector2(0.0, float(Tk.px(Tk.sz("row_h"))) + 4.0)
		var swatch: ColorRect = ColorRect.new()
		swatch.color = LaneKind.colour_of(m, {})
		swatch.custom_minimum_size = Vector2(3.0, 0.0)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(swatch)
		var tcb: Button = PmButton.make(tc(m.time))
		tcb.set("quiet", true)
		tcb.add_theme_font_override("font", Tk.font("mono"))
		tcb.pressed.connect(_on_source_jump.bind(item.id, m.time))
		PmUI.tip(tcb, "Show this moment in the Source monitor")
		row.add_child(tcb)
		var label: Label = PmLabel.trim(m.label if not m.label.is_empty() else "(unnamed)" + ("  " + m.comment if not m.comment.is_empty() else ""))
		if m.label.is_empty() and m.comment.is_empty():
			PmLabel.set_colour(label, "text_dim")
		row.add_child(label)
		var edit: Button = quiet_icon("more", "Edit source marker")
		edit.pressed.connect(_on_source_edit.bind(item.id, m.id))
		row.add_child(edit)
		var del: Button = quiet_icon("trash", "Remove source marker")
		del.pressed.connect(_on_source_remove.bind(item.id, m.id))
		row.add_child(del)
		_list.add_child(row)
		_list.add_child(PmUI.divider())
	if item == null:
		_list.add_child(PmLabel.dim("Open a clip in the Source monitor or pick one in the bin"))
	elif list.is_empty():
		_list.add_child(PmLabel.dim("No markers on " + item.label if filter.is_empty() and kind_filter.is_empty() else "No markers match"))
	_count.text = (item.label + ": " if item != null else "") + str(list.size()) + (" source marker" if list.size() == 1 else " source markers")


func _on_source_jump(media_id: String, t: float) -> void:
	var src: Object = bus().panel("source")
	if src == null:
		return
	if String(src.get("media_id")) != media_id:
		bus().request_source(media_id)
	src.call("set_time", t)


func _on_source_edit(media_id: String, marker_id: String) -> void:
	var src: Object = bus().panel("source")
	if src == null:
		return
	if String(src.get("media_id")) != media_id:
		bus().request_source(media_id)
	src.call("open_source_marker", marker_id)


func _on_source_remove(media_id: String, marker_id: String) -> void:
	SourceMarks.remove(doc(), media_id, marker_id)


func _on_filter(text: String) -> void:
	filter = text.strip_edges().to_lower()
	rebuild()


func _on_kind(id: String) -> void:
	kind_filter = "" if id == "all" else id
	rebuild()


func _on_lane(id: String) -> void:
	lane_filter = id
	rebuild()


static func lane_choice(lane: String) -> String:
	return LANE_RULER if lane.is_empty() else lane


func _sync_lanes(s: Sequence) -> void:
	if _lane == null:
		return
	var list: Array[Dictionary] = MarkerLayers.layers(s) if s != null else ([] as Array[Dictionary])
	var choices: Array = [PmDrop.choice(LANE_ALL, "All lanes"), PmDrop.choice(LANE_RULER, MarkerLayers.RULER_NAME)]
	var sig: String = ""
	for l: Dictionary in list:
		choices.append(PmDrop.choice(String(l["id"]), String(l["name"])))
		sig += String(l["id"]) + "=" + String(l["name"]) + ";"
	_lane.visible = not list.is_empty()
	if sig != _lane_sig:
		_lane_sig = sig
		_lane.call("set_choices", choices)
	if not bool(_lane.call("has_choice", lane_filter)):
		lane_filter = LANE_ALL
	_lane.call("set_value", lane_filter, false)


func _on_add() -> void:
	Cmd.run("marker.add")


func markers() -> Array[Marker]:
	var out: Array[Marker] = []
	var s: Sequence = seq()
	if s == null:
		return out
	var idx: Dictionary = MarkerLayers.index(s)
	for m: Marker in s.markers:
		if not kind_filter.is_empty() and m.kind != kind_filter:
			continue
		if lane_filter != LANE_ALL and lane_choice(MarkerLayers.lane_in(idx, m)) != lane_filter:
			continue
		if not filter.is_empty() and not (m.label.to_lower().contains(filter) or m.comment.to_lower().contains(filter)):
			continue
		out.append(m)
	return out


func rebuild() -> void:
	if not _alive():
		return
	_queued = false
	PmUI.keep_scroll(_list)
	PmUI.clear(_list)
	if _lane != null:
		_lane.visible = false
	if show_source:
		_rebuild_source()
		return
	var s_now: Sequence = seq()
	_sync_lanes(s_now)
	var idx: Dictionary = MarkerLayers.index(s_now) if s_now != null else {}
	var list: Array[Marker] = markers()
	var picked: PackedStringArray = selected_ids()
	for m: Marker in list:
		var row: HBoxContainer = PmUI.hbox()
		row.custom_minimum_size = Vector2(0.0, float(Tk.px(Tk.sz("row_h"))) + 4.0)
		var on: bool = picked.has(m.id)
		var swatch: ColorRect = ColorRect.new()
		var lane: String = MarkerLayers.lane_in(idx, m)
		swatch.color = Tk.c["accent"] if on else (LaneKind.colour_of(m, idx.get(lane, {})) if (m.colour >= 0 or m.has_free_colour() or not lane.is_empty()) else Tk.c["text_dim"])
		swatch.custom_minimum_size = Vector2(5.0 if on else 3.0, 0.0)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(swatch)
		var tcb: Button = PmButton.make(tc(m.time))
		tcb.set("quiet", true)
		tcb.add_theme_font_override("font", Tk.font("mono"))
		tcb.pressed.connect(_on_jump.bind(m.time))
		PmUI.tip(tcb, "Go to this marker")
		row.add_child(tcb)
		var label: Label = PmLabel.trim(m.label if not m.label.is_empty() else "(unnamed)" + ("  " + m.comment if not m.comment.is_empty() else ""))
		if m.label.is_empty() and m.comment.is_empty():
			PmLabel.set_colour(label, "text_dim")
		row.add_child(label)
		var kind: Label = PmLabel.faint(Marker.kind_label(m.kind) + (" follows" if m.follows() else "") + ("" if idx.is_empty() else "  " + MarkerLayers.name_of(s_now, lane)))
		row.add_child(kind)
		var edit: Button = quiet_icon("more", "Edit marker")
		edit.pressed.connect(_on_edit.bind(m.id))
		row.add_child(edit)
		var del: Button = quiet_icon("trash", "Remove marker")
		del.pressed.connect(_on_remove.bind(m.id))
		row.add_child(del)
		_list.add_child(row)
		_list.add_child(PmUI.divider())
	if list.is_empty():
		_list.add_child(PmLabel.dim("No markers" if filter.is_empty() and kind_filter.is_empty() and lane_filter == LANE_ALL else "No markers match"))
	_count.text = str(list.size()) + (" marker" if list.size() == 1 else " markers")
	if picked.size() > 1:
		_count.text += ". " + str(picked.size()) + " picked, editing one edits them all"
	var s_chk: Sequence = seq()
	if s_chk != null and not EditTools.chapter_markers(s_chk).is_empty():
		var problems: PackedStringArray = chapter_warnings(s_chk)
		if not problems.is_empty():
			_count.text += ". Chapters: " + problems[0]


func _on_jump(t: float) -> void:
	Session.set_playhead(t)


func canvas() -> Control:
	var tl: Object = bus().panel("timeline")
	if tl == null or tl.get("canvas") == null:
		return null
	return tl.get("canvas") as Control


func selected_ids() -> PackedStringArray:
	var c: Control = canvas()
	if c == null or not c.has_method("marker_selection"):
		return PackedStringArray()
	return c.call("marker_selection")


func marker_selection_changed() -> void:
	_queue()


func _on_edit(id: String) -> void:
	var c: Control = canvas()
	if c != null:
		c.call("open_marker_editor", id)


func _on_remove(id: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d != null and s != null:
		Verbs.run(d, "Remove marker", [MarkerCmds.RemoveMarker.new(s.id, "", id)])


static func chapter_text(s: Sequence) -> String:
	return String(EditTools.youtube_list(EditTools.chapter_list(s))["text"])


static func chapter_warnings(s: Sequence) -> PackedStringArray:
	return EditTools.youtube_list(EditTools.chapter_list(s))["problems"]


static func copy_youtube(chapters: Array, what: String) -> bool:
	if chapters.is_empty():
		Events.notice("No chapter markers" + what, "Set a marker's kind to Chapter in its editor, then copy again. Other markers are not chapters.")
		return false
	var made: Dictionary = EditTools.youtube_list(chapters)
	DisplayServer.clipboard_set(String(made["text"]))
	var n: int = (made["chapters"] as Array).size()
	var notes: PackedStringArray = made["notes"]
	var problems: PackedStringArray = made["problems"]
	if not problems.is_empty():
		Events.warn("Copied " + str(n) + " chapters, but YouTube will not show them", "; ".join(problems) + "." + ("" if notes.is_empty() else " Also " + "; ".join(notes) + "."))
		return true
	if notes.is_empty():
		Events.toast("Copied " + str(n) + " YouTube chapters, ready to paste into the description")
		return true
	Events.notice("Copied " + str(n) + " YouTube chapters, ready to paste", "To make YouTube accept them I " + "; ".join(notes) + ". Your markers were not changed.")
	return true


func _on_copy_chapters() -> void:
	var s: Sequence = seq()
	if s == null:
		return
	copy_youtube(EditTools.chapter_list(s), "")


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

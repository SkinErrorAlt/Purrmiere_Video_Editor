extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Marker := preload("res://doc/marker.gd")
const MarkerKinds := preload("res://doc/marker_kinds.gd")
const MarkerRuns := preload("res://doc/marker_runs.gd")
const MarkerCmds := preload("res://doc/commands/marker_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const Verbs := preload("res://doc/verbs.gd")
const SubtitleForms := preload("res://modules/core_panels/subtitle_forms.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const SELF_PATH := "res://ui/timeline/marker_menu_extra.gd"
const KIND_SHAPE := "kind"

static var last_opened_link: String = ""
static var open_links: bool = true


static func _seq(canvas: Control) -> Sequence:
	return canvas.call("seq")


static func _doc(canvas: Control) -> Project:
	return canvas.call("doc")


static func picked_of(canvas: Control, marker_id: String) -> PackedStringArray:
	return canvas.call("markers_for_edit", marker_id)


static func items(canvas: Control, mk: Marker, tail: String) -> Array:
	var s: Sequence = _seq(canvas)
	var out: Array = []
	if s == null or mk == null:
		return out
	var picked: PackedStringArray = picked_of(canvas, mk.id)
	var textable: int = 0
	for id: String in picked:
		if MarkerKinds.makes_text(s.marker_by_id(id)):
			textable += 1
	var text_item: Dictionary = PmMenu.item("mx:text", "Make text from this marker" if picked.size() < 2 else "Make text from these " + str(picked.size()) + " markers", "", "type")
	if textable == 0:
		text_item["disabled"] = true
	out.append(text_item)
	var link: String = MarkerKinds.link_of(mk)
	if not link.is_empty():
		out.append(PmMenu.item("mx:link", "Open the link"))
	if MarkerKinds.is_task(mk) or not MarkerKinds.tasks(s).is_empty():
		out.append(PmMenu.item("mx:task_prev", "Go to the previous to do or warning"))
		out.append(PmMenu.item("mx:task_next", "Go to the next to do or warning"))
	var shape_sub: Array = [PmMenu.check_item("mx:shape:" + KIND_SHAPE, "As its kind (" + String(MarkerKinds.entry(mk.kind)["shape"]) + ")", mk.shape.is_empty())]
	for i: int in Marker.SHAPES.size():
		shape_sub.append(PmMenu.check_item("mx:shape:" + Marker.SHAPES[i], Marker.SHAPE_LABELS[i], mk.shape == Marker.SHAPES[i]))
	out.append(PmMenu.sub_item("mx:shape", "Shape" + tail, shape_sub))
	var icon_sub: Array = [PmMenu.check_item("mx:icon:", "As its kind", mk.icon.is_empty())]
	for j: int in MarkerKinds.ICONS.size():
		var name: String = MarkerKinds.ICONS[j]
		var stored: String = "none" if name.is_empty() else name
		icon_sub.append(PmMenu.check_item("mx:icon:" + stored, MarkerKinds.ICON_LABELS[j], mk.icon == stored))
	out.append(PmMenu.sub_item("mx:icon", "Icon" + tail, icon_sub))
	var run_sub: Array = []
	if picked.size() >= 2:
		run_sub.append(PmMenu.item("mx:run_group", "Group the " + str(picked.size()) + " picked markers into a run"))
	if not mk.run.is_empty():
		run_sub.append(PmMenu.item("mx:run_pick", "Pick the whole run (" + str(MarkerRuns.members(s, mk.run).size()) + ")"))
		run_sub.append(PmMenu.item("mx:run_rename", "Rename the run..."))
		run_sub.append(PmMenu.item("mx:run_ungroup", "Ungroup the run"))
	if not run_sub.is_empty():
		out.append(PmMenu.sub_item("mx:run", "Run" + ("" if mk.run.is_empty() else ": " + mk.run), run_sub))
	return out


static func set_fields(canvas: Control, marker_id: String, fields: Dictionary, label: String) -> bool:
	var s: Sequence = _seq(canvas)
	var d: Project = _doc(canvas)
	if s == null or d == null:
		return false
	var cmds: Array[Command] = []
	for id: String in picked_of(canvas, marker_id):
		var m: Marker = s.marker_by_id(id)
		if m == null:
			continue
		var differs: bool = false
		for k: String in fields.keys():
			if str(m.to_dict().get(k, "")) != str(fields[k]):
				differs = true
		if differs:
			cmds.append(MarkerCmds.SetMarker.new(s.id, "", id, fields))
	if cmds.is_empty():
		return false
	return Verbs.run(d, label if cmds.size() == 1 else label + "s", cmds)


static func on_pick(canvas: Control, id: String, marker_id: String) -> bool:
	if not id.begins_with("mx:"):
		return false
	var s: Sequence = _seq(canvas)
	var d: Project = _doc(canvas)
	var mk: Marker = s.marker_by_id(marker_id) if s != null else null
	if mk == null or d == null:
		return true
	var what: String = id.substr(3)
	if what == "text":
		open_text_form(canvas, picked_of(canvas, marker_id))
	elif what == "link":
		var link: String = MarkerKinds.link_of(mk)
		last_opened_link = link
		if open_links and not link.is_empty():
			OS.shell_open(link)
	elif what == "task_next" or what == "task_prev":
		var t: float = MarkerKinds.next_task_time(s, s.playhead, 1 if what == "task_next" else -1)
		if t >= 0.0:
			Session.set_playhead(t)
	elif what.begins_with("shape:"):
		var shape: String = what.substr(6)
		set_fields(canvas, marker_id, {"shape": "" if shape == KIND_SHAPE else shape}, "Marker shape")
	elif what.begins_with("icon:"):
		set_fields(canvas, marker_id, {"icon": what.substr(5)}, "Marker icon")
	elif what == "run_group":
		var run: String = MarkerRuns.group(d, s, picked_of(canvas, marker_id))
		if not run.is_empty():
			canvas.call("set_marker_selection", MarkerRuns.member_ids(s, run), false)
	elif what == "run_pick":
		canvas.call("set_marker_selection", MarkerRuns.member_ids(s, mk.run), false)
	elif what == "run_ungroup":
		MarkerRuns.ungroup(d, s, PackedStringArray([marker_id]))
	elif what == "run_rename":
		var fields: Array[Dictionary] = [{"key": "name", "label": "New name", "type": "string", "default": mk.run}]
		var answered: Signal = PmUI.form(canvas, "Rename " + mk.run, fields, "Rename", "Cancel")
		answered.connect(Callable(load(SELF_PATH), "on_rename").bind(canvas, mk.run))
	return true


static func on_rename(result: Variant, canvas: Control, run: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	MarkerRuns.rename(_doc(canvas), _seq(canvas), run, String((result as Dictionary).get("name", "")))


static func open_text_form(canvas: Control, picked: PackedStringArray) -> Signal:
	var s: Sequence = _seq(canvas)
	var d: Project = _doc(canvas)
	var fields: Array[Dictionary] = SubtitleForms.marks_fields(canvas.call("_style_choices"), d)
	load("res://ui/timeline/timeline_marker_lanes.gd").call("text_length_default", s, picked, fields)
	var title: String = "Text box from this marker" if picked.size() == 1 else "Text boxes from " + str(picked.size()) + " markers"
	var answered: Signal = PmUI.form(canvas, title, fields, "Make boxes", "Cancel")
	answered.connect(Callable(load(SELF_PATH), "on_text").bind(canvas, picked))
	return answered


static func on_text(result: Variant, canvas: Control, picked: PackedStringArray) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	make_text(canvas, result, picked)


static func make_text(canvas: Control, r: Dictionary, picked: PackedStringArray) -> PackedStringArray:
	var s: Sequence = _seq(canvas)
	var d: Project = _doc(canvas)
	if s == null or d == null:
		return PackedStringArray()
	var style: Dictionary = canvas.call("_style_props", int(r.get("style", 0)))
	var ids: PackedStringArray = SubtitleForms.make_from_marks(d, s, r, style, picked)
	if not ids.is_empty():
		Verbs.select(d, s, ids, "replace")
	return ids

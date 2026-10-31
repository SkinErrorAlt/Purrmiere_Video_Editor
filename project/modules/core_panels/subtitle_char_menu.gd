extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const SubtitleChars := preload("res://doc/subtitle_chars.gd")
const Library := preload("res://doc/subtitle_char_library.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PREFIX := "char:"
const APPLY := "char:apply:"
const CLEAR := "char:clear"
const SAVE := "char:save"
const RENAME := "char:rename"
const DUPLICATE := "char:duplicate"
const DELETE := "char:delete"
const UP := "char:up"
const DOWN := "char:down"
const TO_USER := "char:to_user"
const TO_PROJECT := "char:to_project"
const DEFAULT_USER := "char:default_user"
const DEFAULT_PROJECT := "char:default_project"
const NONE_LABEL := "No character"
const EFFECTS_REGISTRY := "res://engine/effect_registry.gd"

static var last_note: String = ""


static func owns(id: String) -> bool:
	return id.begins_with(PREFIX)


static func shown_name(doc: Project, id: String) -> String:
	if id.is_empty():
		return NONE_LABEL
	var row: Dictionary = Library.entry(doc, id)
	return SubtitleChars.label_of(row) if not row.is_empty() else "Missing character"


static func items(doc: Project, current: String, can_save: bool) -> Array:
	var out: Array = []
	var rows: Array[Dictionary] = Library.entries(doc)
	out.append(PmMenu.check_item(CLEAR, NONE_LABEL, current.is_empty()))
	for row: Dictionary in rows:
		var id: String = str(row.get("id", ""))
		var tag: String = "" if str(row.get("scope", "")) == Library.SCOPE_USER else "  (this project)"
		out.append(PmMenu.check_item(APPLY + id, SubtitleChars.label_of(row) + tag, id == current))
	out.append(PmMenu.separator())
	var save: Dictionary = PmMenu.item(SAVE, "Save this box as a character")
	save["disabled"] = not can_save
	out.append(save)
	var have: bool = not current.is_empty() and not Library.entry(doc, current).is_empty()
	var at: int = Library.ids(doc).find(current)
	for pair: Array in [[RENAME, "Rename this character"], [DUPLICATE, "Duplicate this character"], [DELETE, "Delete this character"], [UP, "Move it up the list"], [DOWN, "Move it down the list"]]:
		var it: Dictionary = PmMenu.item(String(pair[0]), String(pair[1]))
		it["disabled"] = not have or (String(pair[0]) == UP and at <= 0) or (String(pair[0]) == DOWN and at >= rows.size() - 1)
		out.append(it)
	if have:
		var in_project: bool = str(Library.entry(doc, current).get("scope", "")) == Library.SCOPE_PROJECT
		out.append(PmMenu.item(TO_USER if in_project else TO_PROJECT, "Keep it in every project" if in_project else "Keep it in this project only"))
	out.append(PmMenu.separator())
	var user_default: bool = SubtitleChars.default_scope() == SubtitleChars.SCOPE_USER
	out.append(PmMenu.check_item(DEFAULT_USER, "New characters go in every project", user_default))
	out.append(PmMenu.check_item(DEFAULT_PROJECT, "New characters go in this project only", not user_default))
	return out


static func effect_labels(doc: Project, id: String) -> Dictionary:
	var out: Dictionary = {}
	var row: Dictionary = Library.entry(doc, id)
	var reg_script: GDScript = load(EFFECTS_REGISTRY) if ResourceLoader.exists(EFFECTS_REGISTRY) else null
	var reg: RefCounted = reg_script.call("shared") if reg_script != null else null
	if reg == null:
		return out
	for e: Variant in SubtitleChars.effects_of(row):
		if not (e is Dictionary):
			continue
		var eid: String = str((e as Dictionary).get("id", ""))
		var def: Dictionary = reg.call("get_def", eid)
		if not def.is_empty() and not str(def.get("label", "")).is_empty():
			out[eid] = str(def["label"])
	return out


static func apply_with_check(host: Control, doc: Project, seq: Sequence, id: String, clip_ids: PackedStringArray) -> bool:
	var summary: Dictionary = Library.summary_for(doc, seq, id, clip_ids, effect_labels(doc, id))
	if summary.is_empty() or not bool(summary.get("ok", false)):
		return false
	if not Library.needs_confirm(summary):
		return Library.apply_by_id(doc, seq, id, clip_ids)
	if host == null or not host.is_inside_tree():
		return false
	var answered: Signal = PmUI.confirm(host, "Put " + str(summary.get("name", "the character")) + " on", Library.confirm_text(summary), "Apply", "Cancel")
	answered.connect(func(ok: Variant) -> void: _confirmed(ok, doc, seq, id, clip_ids))
	return true


static func _confirmed(ok: Variant, doc: Project, seq: Sequence, id: String, clip_ids: PackedStringArray) -> void:
	if ok is bool and bool(ok):
		Library.apply_by_id(doc, seq, id, clip_ids)


static func ask_name(host: Control, title: String, start: String, done: Callable) -> void:
	if host == null or not host.is_inside_tree():
		return
	var fields: Array[Dictionary] = [{"key": "name", "label": "Name", "type": "string", "default": start}]
	var answered: Signal = PmUI.form(host, title, fields, "OK", "Cancel")
	answered.connect(func(result: Variant) -> void: _named(result, done))


static func _named(result: Variant, done: Callable) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var name_: String = String((result as Dictionary).get("name", "")).strip_edges()
	if not name_.is_empty():
		done.call(name_)


static func on_pick(host: Control, doc: Project, seq: Sequence, clip_ids: PackedStringArray, picked: String) -> bool:
	if not owns(picked) or doc == null or seq == null:
		return false
	var boxes: PackedStringArray = Library.ids_of_boxes(doc, seq, clip_ids)
	var current: String = Library.current_of(doc, seq, boxes)
	if picked.begins_with(APPLY):
		apply_with_check(host, doc, seq, picked.substr(APPLY.length()), boxes)
	elif picked == CLEAR:
		SubtitleChars.clear_from(doc, seq, boxes)
	elif picked == SAVE:
		if boxes.is_empty():
			return true
		var first: String = boxes[0]
		ask_name(host, "Save this box as a character", "", func(name_: String) -> void: _save_named(doc, seq, first, boxes, name_))
	elif picked == RENAME:
		ask_name(host, "Rename the character", shown_name(doc, current), func(name_: String) -> void: Library.rename(doc, current, name_))
	elif picked == DUPLICATE:
		Library.duplicate_of(doc, current)
	elif picked == DELETE:
		if host != null and host.is_inside_tree():
			var answered: Signal = PmUI.confirm(host, "Delete " + shown_name(doc, current), "The boxes that use it keep their look. It just leaves the list.", "Delete", "Cancel")
			answered.connect(func(ok: Variant) -> void: _delete_confirmed(ok, doc, current))
	elif picked == UP:
		Library.move(doc, current, -1)
	elif picked == DOWN:
		Library.move(doc, current, 1)
	elif picked == TO_USER:
		Library.move_scope(doc, current, Library.SCOPE_USER)
	elif picked == TO_PROJECT:
		Library.move_scope(doc, current, Library.SCOPE_PROJECT)
	elif picked == DEFAULT_USER:
		SubtitleChars.set_default_scope(SubtitleChars.SCOPE_USER)
	elif picked == DEFAULT_PROJECT:
		SubtitleChars.set_default_scope(SubtitleChars.SCOPE_PROJECT)
	return true


static func _save_named(doc: Project, seq: Sequence, first: String, boxes: PackedStringArray, name_: String) -> void:
	var row: Dictionary = Library.save_from_box(doc, seq, first, name_)
	if row.is_empty():
		return
	Library.apply_by_id(doc, seq, str(row["id"]), boxes, false)


static func _delete_confirmed(ok: Variant, doc: Project, id: String) -> void:
	if ok is bool and bool(ok):
		Library.remove(doc, id)


static func lane_items(doc: Project, seq: Sequence, track_id: String) -> Array:
	var out: Array = []
	var boxes: PackedStringArray = Library.lane_box_ids(doc, seq, track_id)
	var current: String = Library.current_of(doc, seq, boxes)
	for row: Dictionary in Library.entries(doc):
		var id: String = str(row.get("id", ""))
		out.append(PmMenu.check_item("lanechar:" + id, SubtitleChars.label_of(row), id == current and not boxes.is_empty()))
	if out.is_empty():
		var none: Dictionary = PmMenu.item("lanechar:", "No characters saved yet")
		none["disabled"] = true
		out.append(none)
	return out


static func on_lane_pick(host: Control, doc: Project, seq: Sequence, track_id: String, picked: String) -> bool:
	if not picked.begins_with("lanechar:") or doc == null or seq == null:
		return false
	var id: String = picked.substr("lanechar:".length())
	if id.is_empty():
		return true
	var boxes: PackedStringArray = Library.lane_box_ids(doc, seq, track_id)
	if boxes.is_empty():
		last_note = "There are no text boxes on this lane yet."
		return true
	apply_with_check(host, doc, seq, id, boxes)
	return true

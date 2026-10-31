extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Subtitles := preload("res://doc/subtitles.gd")
const SubtitleAnims := preload("res://doc/subtitle_anims.gd")
const SubtitleChars := preload("res://doc/subtitle_chars.gd")
const CharLibrary := preload("res://doc/subtitle_char_library.gd")
const NO_CHARACTER := "No character"
const MarkerLayers := preload("res://doc/marker_layers.gd")
const OTHER_SPLIT := "Another character, typed below"
const RUN_NOTE := "Boxes with no gap between them are one run and share one animation. To split a run later, drag across it in the text editor."
const WHICH_CHOICES: Array = ["Pop in", "Pop out"]
const ACTIONS: Array = ["Make a new one", "Rename", "Duplicate", "Delete", "Move up", "Move down"]
const MANAGE_NOTE := "The built in ones cannot be renamed, moved or deleted, but they can be duplicated. A new one is made from the numbers below: it starts at the size and opacity given, overshoots, then settles. Saved animations are in every project."


static func target_choices() -> Array:
	var out: Array = []
	for t: String in Subtitles.POP_TARGETS:
		out.append(String(Subtitles.POP_TARGET_LABELS.get(t, t)))
	return out


static func target_at(index: int) -> String:
	if index < 0 or index >= Subtitles.POP_TARGETS.size():
		return Subtitles.TARGET_AUTO
	return Subtitles.POP_TARGETS[index]


static func character_choices(doc: Project) -> Array:
	var out: Array = [NO_CHARACTER]
	for row: Dictionary in CharLibrary.entries(doc):
		var adds: PackedStringArray = PackedStringArray()
		for e: Variant in SubtitleChars.effects_of(row):
			if e is Dictionary:
				adds.append(SubtitleChars.effect_label(e))
		var tail: String = "" if adds.is_empty() else "  (adds %d %s: %s)" % [adds.size(), "effect" if adds.size() == 1 else "effects", ", ".join(adds)]
		out.append(SubtitleChars.label_of(row) + tail)
	return out


static func character_at(doc: Project, index: int) -> String:
	var rows: Array[Dictionary] = CharLibrary.entries(doc)
	if index <= 0 or index > rows.size():
		return ""
	return str(rows[index - 1].get("id", ""))


static func marks_fields(style_choices: Array, doc: Project = null) -> Array[Dictionary]:
	return [
		{"key": "character", "label": "Character", "type": "enum", "choices": character_choices(doc), "default": 0},
		{"key": "length", "label": "Length of a box made from a point marker (seconds)", "type": "string", "default": "%.2f" % Subtitles.box_seconds()},
		{"key": "link", "label": "Link the boxes together", "type": "bool", "default": Subtitles.link_new_boxes()},
		{"key": "pop_in", "label": "Pop in", "type": "bool", "default": true},
		{"key": "target", "label": "The pop in goes on", "type": "enum", "choices": target_choices(), "default": 0},
		{"key": "anim", "label": "Pop in animation", "type": "enum", "choices": anim_labels("in"), "default": 0},
		{"key": "style", "label": "Style", "type": "enum", "choices": style_choices, "default": 0},
		{"key": "note", "type": "note", "default": RUN_NOTE},
	]


static func answer_length(r: Dictionary) -> float:
	var raw: String = String(r.get("length", "")).strip_edges()
	if not raw.is_valid_float():
		return Subtitles.box_seconds()
	return clampf(raw.to_float(), Subtitles.MIN_BOX_SECONDS, Subtitles.MAX_BOX_SECONDS)


static func mark_groups(seq: Sequence, picked: PackedStringArray, length: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Dictionary in MarkerLayers.groups_for_text(seq, picked):
		var lane_len: float = float(g.get("length", 0.0))
		var want: float = clampf(lane_len, Subtitles.MIN_BOX_SECONDS, Subtitles.MAX_BOX_SECONDS) if lane_len > 0.0 else length
		var spans: Array[Dictionary] = Subtitles.spans_from_markers(seq, g["ids"], want)
		if not spans.is_empty():
			out.append({"layer": String(g.get("layer", "")), "length": want, "spans": spans})
	return out


static func make_from_marks(doc: Project, seq: Sequence, r: Dictionary, style: Dictionary, picked: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var length: float = answer_length(r)
	var link: bool = bool(r.get("link", true))
	Subtitles.set_box_seconds(length)
	Subtitles.set_link_new_boxes(link)
	var groups: Array[Dictionary] = mark_groups(seq, picked, length)
	if groups.is_empty():
		return PackedStringArray()
	var who: String = character_at(doc, int(r.get("character", 0)))
	var tx: Variant = doc.undo.begin("Text boxes from marks") if not who.is_empty() or groups.size() > 1 else null
	var ids: PackedStringArray = PackedStringArray()
	for g: Dictionary in groups:
		ids.append_array(Subtitles.boxes_from_marks(doc, seq, g["spans"], bool(r.get("pop_in", true)), style, target_at(int(r.get("target", 0))), link, anim_at("in", int(r.get("anim", 0)))))
	if tx == null:
		return ids
	if ids.is_empty():
		tx.call("abandon")
		return ids
	if not who.is_empty():
		CharLibrary.apply_by_id(doc, seq, who, ids)
	tx.call("commit")
	return ids


static func split_choices() -> Array:
	var out: Array = []
	for choice: Dictionary in Subtitles.SPLIT_CHOICES:
		out.append(String(choice["label"]))
	out.append(OTHER_SPLIT)
	return out


static func split_index(sep: String) -> int:
	for i: int in Subtitles.SPLIT_CHOICES.size():
		if String((Subtitles.SPLIT_CHOICES[i] as Dictionary)["value"]) == sep:
			return i
	return Subtitles.SPLIT_CHOICES.size()


static func split_fields() -> Array[Dictionary]:
	var sep: String = Subtitles.split_char()
	var custom: String = "" if split_index(sep) < Subtitles.SPLIT_CHOICES.size() else sep
	return [
		{"key": "split", "label": "Split the phrase on", "type": "enum", "choices": split_choices(), "default": split_index(sep)},
		{"key": "split_other", "label": "Other character", "type": "string", "default": custom},
	]


static func answer_split(r: Dictionary) -> String:
	var index: int = int(r.get("split", 0))
	if index >= 0 and index < Subtitles.SPLIT_CHOICES.size():
		return String((Subtitles.SPLIT_CHOICES[index] as Dictionary)["value"])
	var typed: String = String(r.get("split_other", ""))
	return typed if not typed.is_empty() else Subtitles.SPLIT_SPACE


static func anim_labels(slot: String) -> Array:
	var out: Array = []
	for p: Dictionary in SubtitleAnims.listing(slot):
		out.append(String(p["label"]) + (" (saved)" if bool(p.get("user", false)) else ""))
	return out


static func anim_at(slot: String, index: int) -> Dictionary:
	var list: Array[Dictionary] = SubtitleAnims.listing(slot)
	if index < 0 or index >= list.size():
		return {}
	return list[index]


static func all_anims() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(SubtitleAnims.listing("in"))
	out.append_array(SubtitleAnims.listing("out"))
	return out


static func all_anim_labels() -> Array:
	var out: Array = []
	for p: Dictionary in all_anims():
		out.append(("Pop in: " if String(p["slot"]) == "in" else "Pop out: ") + String(p["label"]) + (" (saved)" if bool(p.get("user", false)) else ""))
	return out


static func pop_fields() -> Array[Dictionary]:
	return [
		{"key": "anim", "label": "Animation", "type": "enum", "choices": all_anim_labels(), "default": 0},
		{"key": "target", "label": "It goes on", "type": "enum", "choices": target_choices(), "default": 0},
	]


static func apply_pop_answer(doc: Project, seq: Sequence, ids: PackedStringArray, r: Dictionary) -> bool:
	var list: Array[Dictionary] = all_anims()
	var index: int = int(r.get("anim", 0))
	if index < 0 or index >= list.size():
		return false
	var chosen: Dictionary = list[index]
	var which: String = String(chosen["slot"])
	var style: Dictionary = {} if SubtitleAnims.is_default(chosen) else chosen
	return Subtitles.apply_pop(doc, seq, ids, which, target_at(int(r.get("target", 0))), style)


static func manage_fields() -> Array[Dictionary]:
	return [
		{"key": "action", "label": "What to do", "type": "enum", "choices": ACTIONS, "default": 0},
		{"key": "preset", "label": "Which animation", "type": "enum", "choices": all_anim_labels(), "default": 0},
		{"key": "name", "label": "Name", "type": "string", "default": ""},
		{"key": "slot", "label": "A new one is a", "type": "enum", "choices": WHICH_CHOICES, "default": 0},
		{"key": "seconds", "label": "How long it takes (seconds)", "type": "string", "default": "0.30"},
		{"key": "start_scale", "label": "Size at the hidden end (1 is normal)", "type": "string", "default": "0.6"},
		{"key": "overshoot", "label": "Size at the overshoot", "type": "string", "default": "1.08"},
		{"key": "start_opacity", "label": "Opacity at the hidden end (0 to 1)", "type": "string", "default": "0"},
		{"key": "note", "type": "note", "default": MANAGE_NOTE},
	]


static func _num(r: Dictionary, key: String, fallback: float) -> float:
	var raw: String = String(r.get(key, "")).strip_edges()
	return raw.to_float() if raw.is_valid_float() else fallback


static func apply_manage(r: Dictionary) -> String:
	var action: int = int(r.get("action", 0))
	var name_: String = String(r.get("name", "")).strip_edges()
	if action == 0:
		var slot: String = "out" if int(r.get("slot", 0)) == 1 else "in"
		var made: Dictionary = SubtitleAnims.from_numbers(name_ if not name_.is_empty() else "My animation", slot, _num(r, "seconds", 0.3), _num(r, "start_scale", 0.6), _num(r, "overshoot", 1.08), clampf(_num(r, "start_opacity", 0.0), 0.0, 1.0))
		return ("Saved " + String(made["label"]) + ".") if SubtitleAnims.add(made) else "Could not save the animation."
	var list: Array[Dictionary] = all_anims()
	var index: int = int(r.get("preset", 0))
	if index < 0 or index >= list.size():
		return "Pick an animation first."
	var chosen: Dictionary = list[index]
	var is_user: bool = bool(chosen.get("user", false))
	if action == 2:
		var copy: Dictionary = SubtitleAnims.duplicate_of(String(chosen["slot"]), String(chosen["id"]), name_)
		return ("Saved " + String(copy["label"]) + ".") if not copy.is_empty() else "Could not duplicate it."
	if not is_user:
		return String(chosen["label"]) + " is built in. Duplicate it to make one you can change."
	if action == 1:
		return "Renamed." if SubtitleAnims.rename(String(chosen["id"]), name_) else "Give it a name first."
	if action == 3:
		return "Deleted." if SubtitleAnims.remove(String(chosen["id"])) else "Could not delete it."
	return "Moved." if SubtitleAnims.move(String(chosen["id"]), -1 if action == 4 else 1) else "It is already at that end."


static func travel_fields(doc: Project, seq: Sequence, ids: PackedStringArray) -> Array[Dictionary]:
	var boxes: Array = Subtitles.sorted_text_clips(doc, seq, ids)
	var now: Dictionary = Subtitles.travel_of(boxes[0]) if not boxes.is_empty() else Subtitles.travel_of(null)
	return [
		{"key": "seconds", "label": "Time to move up or back down (seconds, 0 jumps)", "type": "string", "default": "%.2f" % float(now["seconds"])},
		{"key": "curve", "label": "How it moves", "type": "enum", "choices": Array(Subtitles.TRAVEL_CURVE_LABELS), "default": maxi(Subtitles.TRAVEL_CURVES.find(String(now["curve"])), 0)},
		{"key": "note", "type": "note", "default": "When a box starts on another subtitle lane, the earlier box moves up out of its way (Home, Up one, Up two). This sets how it gets there."},
	]


static func apply_travel_answer(doc: Project, seq: Sequence, ids: PackedStringArray, r: Dictionary) -> bool:
	var index: int = clampi(int(r.get("curve", 0)), 0, Subtitles.TRAVEL_CURVES.size() - 1)
	return Subtitles.set_travel(doc, seq, ids, _num(r, "seconds", 0.0), Subtitles.TRAVEL_CURVES[index])

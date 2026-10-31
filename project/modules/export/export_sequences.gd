extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Project := preload("res://doc/project.gd")
const SubProjects := preload("res://doc/sub_projects.gd")
const PANEL_KEY := "sequence_pick"
const JOB_KEY := "sequence_id"
const MODE_ACTIVE := "active"
const MODE_ONE := "one"
const MODE_ALL := "all"
const MODE_SUB := "sub"
const SUB_PREFIX := "__sub:"
const ACTIVE_ID := "__active"
const ALL_ID := "__all"
const ACTIVE_LABEL := "The one I am looking at"
const ALL_LABEL := "Every sequence, one file each"


static func panel_choice(settings: Dictionary) -> Dictionary:
	var raw: Variant = settings.get(PANEL_KEY, null)
	var d: Dictionary = raw if raw is Dictionary else {}
	var mode: String = String(d.get("mode", MODE_ACTIVE))
	if mode != MODE_ONE and mode != MODE_ALL and mode != MODE_SUB:
		mode = MODE_ACTIVE
	var id: String = String(d.get("id", ""))
	if mode != MODE_ONE and mode != MODE_SUB:
		id = ""
	return {"mode": mode, "id": id}


static func pick_id(settings: Dictionary) -> String:
	var c: Dictionary = panel_choice(settings)
	if String(c["mode"]) == MODE_ALL:
		return ALL_ID
	if String(c["mode"]) == MODE_SUB:
		return SUB_PREFIX + String(c["id"])
	if String(c["mode"]) == MODE_ONE and not String(c["id"]).is_empty():
		return String(c["id"])
	return ACTIVE_ID


static func set_pick(settings: Dictionary, id: String) -> void:
	if id == ALL_ID:
		settings[PANEL_KEY] = {"mode": MODE_ALL, "id": ""}
	elif id.begins_with(SUB_PREFIX):
		settings[PANEL_KEY] = {"mode": MODE_SUB, "id": id.substr(SUB_PREFIX.length())}
	elif id == ACTIVE_ID or id.is_empty():
		settings[PANEL_KEY] = {"mode": MODE_ACTIVE, "id": ""}
	else:
		settings[PANEL_KEY] = {"mode": MODE_ONE, "id": id}


static func all_of(doc: Project) -> Array[Sequence]:
	var out: Array[Sequence] = []
	if doc == null:
		return out
	for s: Sequence in doc.sequences:
		if s != null:
			out.append(s)
	return out


static func chosen(settings: Dictionary, doc: Project, active: Sequence) -> Array[Sequence]:
	var c: Dictionary = panel_choice(settings)
	var mode: String = String(c["mode"])
	var out: Array[Sequence] = []
	if mode == MODE_ALL:
		out = all_of(doc)
		if out.is_empty() and active != null:
			out.append(active)
		return out
	if mode == MODE_ONE and doc != null:
		var one: Sequence = doc.sequence_by_id(String(c["id"]))
		if one != null:
			out.append(one)
			return out
	if mode == MODE_SUB and _group_exists(doc, String(c["id"])):
		out = SubProjects.members(doc, String(c["id"]))
		if not out.is_empty():
			return out
	if active != null:
		out.append(active)
	return out


static func sequence_of(settings: Dictionary, doc: Project, fallback: Sequence) -> Sequence:
	var id: String = String(settings.get(JOB_KEY, ""))
	if id.is_empty() or doc == null:
		return fallback
	var s: Sequence = doc.sequence_by_id(id)
	return s if s != null else fallback


static func label_of(seq: Sequence) -> String:
	if seq == null:
		return "sequence"
	var l: String = seq.label.strip_edges()
	return l if not l.is_empty() else "sequence"


static func file_name_for(settings: Dictionary, seq: Sequence) -> String:
	var dest: Dictionary = settings.get("destination", {})
	var base: String = String(dest.get("name", "")).strip_edges()
	var label: String = label_of(seq)
	return label if base.is_empty() else base + " - " + label


static func expand(settings: Dictionary, doc: Project, active: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list: Array[Sequence] = chosen(settings, doc, active)
	if list.is_empty():
		var bare: Dictionary = settings.duplicate(true)
		bare.erase(PANEL_KEY)
		out.append(bare)
		return out
	var used: Dictionary = {}
	for s: Sequence in list:
		var d: Dictionary = settings.duplicate(true)
		d.erase(PANEL_KEY)
		d[JOB_KEY] = s.id
		if list.size() > 1:
			var wanted: String = file_name_for(settings, s)
			var nm: String = wanted
			var k: int = 2
			while used.has(nm.to_lower()):
				nm = wanted + " " + str(k)
				k += 1
			used[nm.to_lower()] = true
			var dest: Dictionary = d.get("destination", {})
			dest["name"] = nm
			d["destination"] = dest
		out.append(d)
	return out


static func choices(doc: Project, active: Sequence) -> Array:
	var out: Array = []
	out.append([ACTIVE_ID, ACTIVE_LABEL, label_of(active)])
	for s: Sequence in all_of(doc):
		out.append([s.id, label_of(s), ""])
	if all_of(doc).size() > 1:
		out.append([ALL_ID, ALL_LABEL, ""])
	if doc != null and not doc.sub_projects.is_empty():
		for g: Dictionary in SubProjects.ordered(doc):
			var n: int = (g["sequences"] as Array).size()
			out.append([SUB_PREFIX + String(g["id"]), sub_label(String(g["name"])), str(n) + (" sequence" if n == 1 else " sequences")])
	return out


static func sub_label(name_: String) -> String:
	return "Sub project " + name_ + ", one file each"


static func _group_exists(doc: Project, gid: String) -> bool:
	if doc == null:
		return false
	if gid.is_empty():
		return true
	return not SubProjects.group_by_id(doc, gid).is_empty()


static func pick_label(settings: Dictionary, doc: Project, active: Sequence) -> String:
	var c: Dictionary = panel_choice(settings)
	var mode: String = String(c["mode"])
	if mode == MODE_ALL:
		var n: int = all_of(doc).size()
		return ALL_LABEL + " (" + str(n) + ")"
	if mode == MODE_SUB:
		var gid: String = String(c["id"])
		if _group_exists(doc, gid):
			return sub_label(SubProjects.name_of(doc, gid)) + " (" + str(SubProjects.members(doc, gid).size()) + ")"
		return "That sub project is gone, using the one I am looking at"
	if mode == MODE_ONE:
		var one: Sequence = doc.sequence_by_id(String(c["id"])) if doc != null else null
		if one != null:
			return label_of(one)
		return "That sequence is gone, using the one I am looking at"
	return ACTIVE_LABEL + " (" + label_of(active) + ")"


static func queue_note(settings: Dictionary, doc: Project) -> String:
	var id: String = String(settings.get(JOB_KEY, ""))
	if id.is_empty() or doc == null or doc.sequences.size() < 2:
		return ""
	var s: Sequence = doc.sequence_by_id(id)
	return " [" + (label_of(s) if s != null else id) + "]"

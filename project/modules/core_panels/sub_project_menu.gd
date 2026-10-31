extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const SubProjects := preload("res://doc/sub_projects.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PREFIX := "sub:"


static func owns(id: String) -> bool:
	return id.begins_with(PREFIX)


static func listing(doc: Project) -> Dictionary:
	var groups_out: Array = []
	for g: Dictionary in SubProjects.ordered(doc):
		var rows: Array = []
		for s: Sequence in g["sequences"]:
			rows.append(PmMenu.check_item(PREFIX + "open:" + s.id, s.label, s.id == doc.active_sequence_id))
		if rows.is_empty():
			var none_row: Dictionary = PmMenu.item(PREFIX + "none", "No sequences yet")
			none_row["disabled"] = true
			rows.append(none_row)
		groups_out.append(PmMenu.sub_item(PREFIX + "list:" + String(g["id"]), String(g["name"]), rows))
	return PmMenu.sub_item(PREFIX + "list", "Sub projects", groups_out)


static func items(doc: Project, seq_id: String) -> Array:
	var out: Array = []
	if doc == null or doc.sequence_by_id(seq_id) == null:
		return out
	var here: String = SubProjects.group_of(doc, seq_id)
	out.append(listing(doc))
	var moves: Array = [PmMenu.check_item(PREFIX + "assign:", SubProjects.TOP_NAME, here.is_empty())]
	for g2: Dictionary in doc.sub_projects:
		var gid: String = String(g2.get("id", ""))
		moves.append(PmMenu.check_item(PREFIX + "assign:" + gid, String(g2.get("name", "")), gid == here))
	moves.append(PmMenu.separator())
	moves.append(PmMenu.item(PREFIX + "new", "New sub project with this sequence"))
	out.append(PmMenu.sub_item(PREFIX + "move", "Put this sequence in", moves))
	if not here.is_empty():
		var name_: String = SubProjects.name_of(doc, here)
		out.append(PmMenu.item(PREFIX + "rename:" + here, "Rename sub project " + name_))
		out.append(PmMenu.item(PREFIX + "up:" + here, "Move sub project " + name_ + " earlier"))
		out.append(PmMenu.item(PREFIX + "down:" + here, "Move sub project " + name_ + " later"))
		out.append(PmMenu.item(PREFIX + "sup:" + seq_id, "Move this sequence earlier in its sub project"))
		out.append(PmMenu.item(PREFIX + "sdown:" + seq_id, "Move this sequence later in its sub project"))
		out.append(PmMenu.item(PREFIX + "remove:" + here, "Remove sub project " + name_ + ", its sequences go to the top level"))
	return out


static func open(anchor: Control, doc: Project, seq_id: String, at: Vector2) -> Control:
	var list: Array = items(doc, seq_id)
	if list.is_empty() or anchor == null or not anchor.is_inside_tree():
		return null
	var m: Control = PmMenu.open(anchor, list, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", func(id: String) -> void: on_pick(anchor, doc, seq_id, id))
	return m


static func on_pick(host: Control, doc: Project, seq_id: String, picked: String) -> bool:
	if not owns(picked) or doc == null:
		return false
	var rest: String = picked.substr(PREFIX.length())
	var colon: int = rest.find(":")
	var verb: String = rest if colon < 0 else rest.substr(0, colon)
	var arg: String = "" if colon < 0 else rest.substr(colon + 1)
	if verb == "open":
		Session.set_sequence(arg)
	elif verb == "assign":
		SubProjects.assign(doc, seq_id, arg)
	elif verb == "new":
		var s: Sequence = doc.sequence_by_id(seq_id)
		var start: String = SubProjects.unique_name(doc, s.label if s != null else "")
		_ask(host, "New sub project", start, func(name_: String) -> void: SubProjects.add(doc, name_, PackedStringArray([seq_id])))
	elif verb == "rename":
		_ask(host, "Rename sub project", SubProjects.name_of(doc, arg), func(name_: String) -> void: SubProjects.rename(doc, arg, name_))
	elif verb == "up":
		SubProjects.move(doc, arg, -1)
	elif verb == "down":
		SubProjects.move(doc, arg, 1)
	elif verb == "sup":
		SubProjects.move_sequence(doc, arg, -1)
	elif verb == "sdown":
		SubProjects.move_sequence(doc, arg, 1)
	elif verb == "remove":
		SubProjects.remove(doc, arg)
	return true


static func _ask(host: Control, title: String, start: String, done: Callable) -> void:
	if host == null or not host.is_inside_tree():
		done.call(start)
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

extends RefCounted

const PmUI := preload("res://ui/kit/pm_ui.gd")
const FOLDER := "rework_requests"
const MENU_ID := "rework"
const LABEL := "Ask for a rework..."

static var plant_skip_frame: bool = false


static func folder() -> String:
	var root: String = String(Prefs.data_dir()) if Prefs.has_method("data_dir") else OS.get_user_data_dir()
	return root.path_join(FOLDER)


static func slug(s: String) -> String:
	var out: String = ""
	for ch: String in s.to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	return out.strip_edges()


static func compose(def: Dictionary, answers: Dictionary, frame_file: String, stamp: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# Rework request: " + String(def.get("label", def.get("id", ""))))
	lines.append("")
	lines.append("Transition id: `" + String(def.get("id", "")) + "`  ")
	lines.append("Written: " + stamp)
	lines.append("")
	lines.append("## What is wrong with it now")
	lines.append("")
	lines.append(String(answers.get("wrong", "")).strip_edges() if not String(answers.get("wrong", "")).strip_edges().is_empty() else "(left empty)")
	lines.append("")
	lines.append("## What it should do instead")
	lines.append("")
	lines.append(String(answers.get("want", "")).strip_edges() if not String(answers.get("want", "")).strip_edges().is_empty() else "(left empty)")
	if not String(answers.get("like", "")).strip_edges().is_empty():
		lines.append("")
		lines.append("## Looks like")
		lines.append("")
		lines.append(String(answers.get("like", "")).strip_edges())
	if not frame_file.is_empty():
		lines.append("")
		lines.append("## The Program monitor when this was written")
		lines.append("")
		lines.append("![frame](" + frame_file + ")")
	lines.append("")
	lines.append("## The transition as it ships")
	lines.append("")
	lines.append(String(def.get("blurb", "")))
	lines.append("")
	for p: Variant in def.get("params", []):
		if p is Dictionary:
			var pd: Dictionary = p
			lines.append("- " + String(pd.get("label", pd.get("key", ""))) + " (`" + String(pd.get("key", "")) + "`): default " + JSON.stringify(pd.get("default", "")))
	lines.append("")
	return "\n".join(lines)


static func write(def: Dictionary, answers: Dictionary, frame: Image, dir: String = "") -> String:
	var where: String = dir if not dir.is_empty() else folder()
	DirAccess.make_dir_recursive_absolute(where)
	var stamp: String = Time.get_datetime_string_from_system(false, true)
	var base: String = slug(String(def.get("id", "transition"))) + "_" + stamp.replace(":", "").replace(" ", "_").replace("-", "")
	var frame_file: String = ""
	if frame != null and not plant_skip_frame:
		frame_file = base + ".png"
		if frame.save_png(where.path_join(frame_file)) != OK:
			frame_file = ""
	var path: String = where.path_join(base + ".md")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(compose(def, answers, frame_file, stamp))
	f.close()
	return path


static func ask(anchor: Control, def: Dictionary) -> void:
	var fields: Array[Dictionary] = [
		{"key": "note", "type": "note", "default": "Write what you want changed. It is saved as a file with a picture of the Program monitor, ready to hand over."},
		{"key": "wrong", "label": "What is wrong now", "type": "string", "default": ""},
		{"key": "want", "label": "What it should do", "type": "string", "default": ""},
		{"key": "like", "label": "Looks like (a film, a video, an app)", "type": "string", "default": ""},
		{"key": "frame", "label": "Add a picture of the Program monitor", "type": "bool", "default": true},
	]
	var answered: Signal = PmUI.form(anchor, "Rework " + String(def.get("label", "")), fields, "Save", "Cancel")
	answered.connect(func(result: Variant) -> void:
		if result is Dictionary and not (result as Dictionary).is_empty():
			_save(def, result)
	)


static func _save(def: Dictionary, answers: Dictionary) -> void:
	var frame: Image = null
	var comp: Object = Session.compositor
	if bool(answers.get("frame", true)) and comp != null and is_instance_valid(comp) and comp.has_method("read_frame"):
		var got: Variant = await comp.call("read_frame")
		if got is Image:
			frame = got
	var path: String = write(def, answers, frame)
	if path.is_empty():
		Events.toast("The rework request could not be saved")
	else:
		Events.toast("Rework request saved in " + folder())

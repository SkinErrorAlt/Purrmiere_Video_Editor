extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const SheetList := preload("res://modules/core_panels/sheet_list.gd")
const Io := preload("res://doc/io.gd")
const Project := preload("res://doc/project.gd")
const SELF_PATH := "res://modules/core_panels/restore_sheet.gd"
const MONTHS: PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var sheet: Control = null
var list: Control = null
var open_button: Button = null
var snapshots: Array[Dictionary] = []


static func open(host: Node) -> Node:
	var script: GDScript = load(SELF_PATH)
	var r: Node = script.new()
	r.call("build", host)
	return r


static func local_unix(t: int) -> int:
	var tz: Dictionary = Time.get_time_zone_from_system()
	return t + int(tz.get("bias", 0)) * 60


static func when_text(t: int, now: int) -> String:
	if t <= 0:
		return "unknown time"
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(local_unix(t))
	var n: Dictionary = Time.get_datetime_dict_from_unix_time(local_unix(now))
	var hm: String = "%02d:%02d" % [int(d["hour"]), int(d["minute"])]
	if int(d["year"]) == int(n["year"]) and int(d["month"]) == int(n["month"]) and int(d["day"]) == int(n["day"]):
		return "Today " + hm
	var month: String = MONTHS[clampi(int(d["month"]) - 1, 0, 11)]
	if int(d["year"]) == int(n["year"]):
		return str(int(d["day"])) + " " + month + " " + hm
	return str(int(d["day"])) + " " + month + " " + str(int(d["year"])) + " " + hm


static func list_for(doc: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null:
		return out
	for s: Dictionary in Io.list_snapshots(doc):
		var info: Dictionary = Io.snapshot_info(String(s["path"]))
		if bool(info["ok"]):
			out.append(info)
	return out


static func restore(doc: Project, path: String) -> Project:
	var copy: Project = Io.load_snapshot(path)
	if copy == null:
		Events.error("Could not open the snapshot", Io.last_error)
		return null
	var when: int = FileAccess.get_modified_time(path)
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(local_unix(when))
	var base: String = copy.name if not copy.name.is_empty() else "Project"
	copy.name = base + " (restored %02d:%02d)" % [int(d["hour"]), int(d["minute"])]
	if doc != null:
		if doc.dirty:
			var kept: String = Io.snapshot(doc)
			if not kept.is_empty():
				Events.info("Kept a snapshot of " + doc.name + " before restoring", kept)
		Io.unlock(doc)
	Session.set_project(copy, "")
	Events.notice("Opened " + copy.name, "This is an unsaved copy. Save it under a new name to keep it; the original project file was not touched.")
	if not Io.last_warning.is_empty():
		Events.warn("This snapshot is from a newer Purrmiere", Io.last_warning)
	return copy


func build(host: Node) -> void:
	name = "RestoreSheet"
	sheet = Sheet.open(host, "Restore from a snapshot", 560.0, 430.0)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	var doc: Project = Session.doc
	var file_name: String = doc.path.get_file() if doc != null and not doc.path.is_empty() else "the project file"
	sheet.call("add_note", "Snapshots of " + (doc.name if doc != null else "this project") + ", newest first. The one you pick opens as an unsaved copy; " + file_name + " is never touched.")
	list = SheetList.make(38.0, true, 0.0)
	list.set("click_activates", false)
	list.set("empty_text", "No snapshots yet. One is written every two minutes while the project changes.")
	list.connect("activated", _on_activated)
	col.add_child(list)
	var cancel: Button = sheet.call("add_button", "Cancel")
	cancel.pressed.connect(_on_cancel)
	open_button = sheet.call("add_button", "Open as a copy", true)
	open_button.pressed.connect(_on_open)
	reload()


func reload() -> void:
	snapshots = list_for(Session.doc)
	var now: int = int(Time.get_unix_time_from_system())
	var rows: Array[Dictionary] = []
	for s: Dictionary in snapshots:
		var clips: int = int(s["clips"])
		rows.append({"title": when_text(int(s["modified"]), now), "detail": String(s["name"]), "right": str(clips) + (" clip" if clips == 1 else " clips")})
	list.call("set_rows", rows)
	open_button.disabled = snapshots.is_empty()


func open_index(i: int) -> Project:
	if i < 0 or i >= snapshots.size():
		return null
	var path: String = String(snapshots[i]["path"])
	sheet.call("close")
	return restore(Session.doc, path)


func _on_activated(index: int) -> void:
	open_index(index)


func _on_open() -> void:
	open_index(int(list.get("cursor")))


func _on_cancel() -> void:
	sheet.call("close")

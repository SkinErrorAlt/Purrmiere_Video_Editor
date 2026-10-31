extends Node

const FRAME_CAP_PATH := "res://host/frame_cap.gd"
const ACTIVE_MS := 60000
const FLUSH_S := 30.0
const PREF_DAYS := "stats.days"
const PREF_PROJECTS := "stats.projects"
const DAYS_KEPT := 800

var counted: float = 0.0
var _pending: float = 0.0
var _since_flush: float = 0.0
var focused: bool = true
static var plant_never_counts: bool = false


func _ready() -> void:
	name = "EditClock"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register()


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("/root/Prefs") if loop is SceneTree else null


static func _register() -> void:
	var prefs: Node = _prefs()
	if prefs == null:
		return
	if not bool(prefs.call("is_registered", PREF_DAYS)):
		prefs.call("register", PREF_DAYS, {}, {"label": "Editing time per day (seconds), shown in Help, Statistics", "type": "dict"})
	if not bool(prefs.call("is_registered", PREF_PROJECTS)):
		prefs.call("register", PREF_PROJECTS, {}, {"label": "Editing time and exports per project, shown in Help, Statistics", "type": "dict"})


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true


static func active(now_ms: int) -> bool:
	var cap: GDScript = load(FRAME_CAP_PATH)
	if cap == null:
		return false
	return now_ms - int(cap.get("active_ms")) < ACTIVE_MS


func _process(delta: float) -> void:
	var session: Node = get_node_or_null("/root/Session")
	if session == null or plant_never_counts:
		return
	var doc: Object = session.get("doc")
	if doc == null or not focused:
		return
	var playing: bool = bool(session.get("playing"))
	if not playing and not active(Time.get_ticks_msec()):
		return
	var dt: float = minf(delta, 1.0)
	doc.call("add_edit_seconds", dt)
	counted += dt
	_pending += dt
	_since_flush += dt
	if _since_flush >= FLUSH_S:
		flush(doc)


func flush(doc: Object) -> void:
	_since_flush = 0.0
	if _pending <= 0.0:
		return
	add_time(doc, _pending)
	_pending = 0.0


static func today_key() -> String:
	return Time.get_date_string_from_system()


static func add_time(doc: Object, seconds: float) -> void:
	_register()
	var prefs: Node = _prefs()
	if prefs == null or doc == null:
		return
	var days: Dictionary = (prefs.call("get_value", PREF_DAYS) as Dictionary).duplicate()
	var key: String = today_key()
	days[key] = float(days.get(key, 0.0)) + seconds
	if days.size() > DAYS_KEPT:
		var keys: Array = days.keys()
		keys.sort()
		for k: Variant in keys.slice(0, keys.size() - DAYS_KEPT):
			days.erase(k)
	prefs.call("set_value", PREF_DAYS, days)
	var projects: Dictionary = (prefs.call("get_value", PREF_PROJECTS) as Dictionary).duplicate(true)
	var pid: String = String(doc.get("id"))
	var rec: Dictionary = projects.get(pid, {}) if projects.get(pid) is Dictionary else {}
	rec["name"] = String(doc.get("name"))
	rec["path"] = String(doc.get("path"))
	rec["seconds"] = float(doc.call("edit_seconds")) if doc.has_method("edit_seconds") else float(rec.get("seconds", 0.0)) + seconds
	rec["last"] = key
	if not rec.has("first"):
		rec["first"] = key
	projects[pid] = rec
	prefs.call("set_value", PREF_PROJECTS, projects)


static func note_export(doc: Object, seconds_taken: float) -> void:
	_register()
	var prefs: Node = _prefs()
	if prefs == null or doc == null:
		return
	var projects: Dictionary = (prefs.call("get_value", PREF_PROJECTS) as Dictionary).duplicate(true)
	var pid: String = String(doc.get("id"))
	var rec: Dictionary = projects.get(pid, {}) if projects.get(pid) is Dictionary else {}
	rec["name"] = String(doc.get("name"))
	rec["exports"] = int(rec.get("exports", 0)) + 1
	rec["export_seconds"] = float(rec.get("export_seconds", 0.0)) + maxf(seconds_taken, 0.0)
	rec["finished"] = today_key()
	projects[pid] = rec
	prefs.call("set_value", PREF_PROJECTS, projects)


static func project_record(doc: Object) -> Dictionary:
	_register()
	var prefs: Node = _prefs()
	if prefs == null or doc == null:
		return {}
	var projects: Dictionary = prefs.call("get_value", PREF_PROJECTS)
	var rec: Variant = projects.get(String(doc.get("id")), {})
	return rec if rec is Dictionary else {}


static func summary(now_key: String = "") -> Dictionary:
	_register()
	var prefs: Node = _prefs()
	var days: Dictionary = prefs.call("get_value", PREF_DAYS) if prefs != null else {}
	var projects: Dictionary = prefs.call("get_value", PREF_PROJECTS) if prefs != null else {}
	var today: String = now_key if not now_key.is_empty() else today_key()
	var t_unix: int = Time.get_unix_time_from_datetime_string(today + "T00:00:00")
	var week: float = 0.0
	var month: float = 0.0
	var year: float = 0.0
	var all: float = 0.0
	var active_days: int = 0
	for k: Variant in days.keys():
		var secs: float = float(days[k])
		all += secs
		if secs > 0.0:
			active_days += 1
		var d_unix: int = Time.get_unix_time_from_datetime_string(String(k) + "T00:00:00")
		var age: int = (t_unix - d_unix) / 86400
		if age >= 0 and age < 7:
			week += secs
		if String(k).substr(0, 7) == today.substr(0, 7):
			month += secs
		if String(k).substr(0, 4) == today.substr(0, 4):
			year += secs
	var finished: int = 0
	var unfinished: int = 0
	var finished_time: float = 0.0
	var most: String = ""
	var most_s: float = -1.0
	for pid: Variant in projects.keys():
		var rec: Dictionary = projects[pid]
		var secs2: float = float(rec.get("seconds", 0.0))
		if int(rec.get("exports", 0)) > 0:
			finished += 1
			finished_time += secs2
		else:
			unfinished += 1
		if secs2 > most_s:
			most_s = secs2
			most = String(rec.get("name", ""))
	return {
		"today": float(days.get(today, 0.0)),
		"week": week,
		"month": month,
		"year": year,
		"all": all,
		"days": active_days,
		"per_day": all / float(maxi(active_days, 1)),
		"finished": finished,
		"unfinished": unfinished,
		"to_finish": finished_time / float(maxi(finished, 1)) if finished > 0 else 0.0,
		"most": most,
		"most_seconds": maxf(most_s, 0.0),
		"projects": projects.size(),
	}

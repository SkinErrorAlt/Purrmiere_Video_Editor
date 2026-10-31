extends Node

const Project := preload("res://doc/project.gd")
const Io := preload("res://doc/io.gd")
const SaveWalk := preload("res://doc/save_walk.gd")
const PREF_ON := "project.save_after_edit"
const QUIET_S := 0.25
const MAX_WAIT_S := 0.75
const BUDGET_USEC := 4000
const BUDGET_PLAYING_USEC := 2000
const RETRY_S := 5.0
const HINT := "Saves the project file about a second after each change, without holding up the app. An untitled project keeps a recovery file until it is saved."

static var in_suites: bool = false

var source: Callable = Callable()
var doc: Project = null
var walk: SaveWalk = null
var recovery_path: String = ""
var saved_serial: int = -1
var writing: bool = false
var saves: int = 0
var failures: int = 0
var max_frame_usec: int = 0
var last_frame_usec: int = 0
var last_latency_ms: float = -1.0
var last_write_ms: float = 0.0
var last_error: String = ""
var _last_serial: int = -1
var _changed_at: float = -1.0
var _pending_since: float = -1.0
var _write_from: float = -1.0
var _retry_at: float = 0.0
var _warned: bool = false
var _trash: Array = []
var _discarded: int = 0
var _adopt: Dictionary = {}


static func register_pref() -> void:
	if not Prefs.is_registered(PREF_ON):
		Prefs.register(PREF_ON, true, {"label": "Save after every change", "type": "bool", "hint": HINT})


func _ready() -> void:
	name = "SaveAfterEdit"
	register_pref()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		Io.wait_background()
		_poll_write()


func enabled() -> bool:
	if Prefs.running_suite() and not in_suites:
		return false
	return bool(Prefs.get_value(PREF_ON))


func _now() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0


func _current() -> Project:
	if source.is_valid():
		return source.call()
	return Session.doc


func _process(_dt: float) -> void:
	var t0: int = Time.get_ticks_usec()
	var switched: bool = _tick()
	last_frame_usec = Time.get_ticks_usec() - t0
	if not switched:
		max_frame_usec = maxi(max_frame_usec, last_frame_usec)


func _tick() -> bool:
	_poll_write()
	var cur: Project = _current()
	if cur != doc:
		_switch(cur)
		return true
	if doc == null or not enabled():
		return false
	var now: float = _now()
	if doc.serial != _last_serial:
		_last_serial = doc.serial
		_changed_at = now
	if not pending():
		_pending_since = -1.0
	elif _pending_since < 0.0:
		_pending_since = _changed_at
	_tidy_recovery()
	if doc.undo.has_live() or doc.undo.in_transaction():
		return false
	if walk.running:
		if walk.step(budget()):
			_walk_done()
		return false
	if writing or not pending() or now < _retry_at:
		return false
	if now - _changed_at >= QUIET_S or now - _pending_since >= MAX_WAIT_S:
		if _write_from < 0.0:
			_write_from = _pending_since
		walk.begin()
		if walk.step(budget()):
			_walk_done()
	return false


func budget() -> int:
	return BUDGET_PLAYING_USEC if bool(Session.get("playing")) else BUDGET_USEC


func pending() -> bool:
	return doc != null and doc.dirty and doc.serial != saved_serial and _discarded != doc.get_instance_id()


func target_path() -> String:
	if doc == null:
		return ""
	if not doc.path.is_empty():
		return doc.path
	if recovery_path.is_empty():
		recovery_path = Io.new_recovery_path(doc)
		Io.own_recovery(recovery_path)
	return recovery_path


func _walk_done() -> void:
	_trash.append_array(walk.take_old())
	var d: Dictionary = walk.take_result()
	if not pending() or walk.serial != doc.serial:
		_trash.append(d)
		return
	var trash: Array = _trash
	_trash = []
	if Io.save_background(d, doc.view.duplicate(true), target_path(), [doc.get_instance_id(), walk.serial], trash):
		writing = true
	else:
		_trash.append_array(trash)
		_trash.append(d)


func _poll_write() -> void:
	if not writing or Io.background_busy():
		return
	writing = false
	var r: Dictionary = Io.take_background_result()
	if r.is_empty():
		return
	var tag: Array = r.get("tag", [0, -1])
	var same: bool = doc != null and int(tag[0]) == doc.get_instance_id()
	if bool(r["ok"]):
		saves += 1
		last_write_ms = float(r["ms"])
		last_error = ""
		_warned = false
		if same:
			saved_serial = int(tag[1])
			if doc.serial == saved_serial and not doc.path.is_empty() and String(r["path"]) == doc.path:
				doc.dirty = false
			if _write_from >= 0.0:
				last_latency_ms = (_now() - _write_from) * 1000.0
			_write_from = -1.0
		return
	failures += 1
	last_error = String(r["error"])
	_retry_at = _now() + RETRY_S
	if not _warned:
		_warned = true
		Events.warn("Could not save " + (doc.name if doc != null else "the project"), last_error + ". The next try is in a few seconds; Save still works.")


func _tidy_recovery() -> void:
	if recovery_path.is_empty() or doc == null or doc.path.is_empty() or writing:
		return
	Io.remove_recovery(recovery_path)
	recovery_path = ""


func _switch(cur: Project) -> void:
	if doc != null:
		_leave()
	doc = cur
	walk = SaveWalk.new(cur) if cur != null else null
	recovery_path = ""
	saved_serial = -1
	_write_from = -1.0
	_pending_since = -1.0
	_retry_at = 0.0
	_trash = []
	if cur == null:
		return
	var iid: int = cur.get_instance_id()
	if _adopt.has(iid):
		recovery_path = String(_adopt[iid])
		_adopt.erase(iid)
	if not cur.dirty:
		saved_serial = cur.serial
	_last_serial = cur.serial
	_changed_at = _now()
	if enabled():
		walk.begin()


func _leave() -> void:
	flush()
	if _discarded == doc.get_instance_id():
		Io.remove_recovery(recovery_path)
		recovery_path = ""
	_discarded = 0


func flush() -> bool:
	if doc == null or not enabled():
		return false
	Io.wait_background()
	_poll_write()
	_tidy_recovery()
	if not pending():
		return true
	if not doc.path.is_empty():
		var err: Error = Io.save_quiet(doc, doc.path)
		if err != OK:
			last_error = Io.last_error
			return false
		saved_serial = doc.serial
		doc.dirty = false
		saves += 1
		return true
	var text: String = JSON.stringify(Io.project_dict(doc), "\t", false, true)
	var r: Array = Io.write_atomic_core(target_path(), text, true)
	if not String(r[1]).is_empty():
		last_error = String(r[1])
		return false
	saved_serial = doc.serial
	saves += 1
	return true


func discard(project: Project) -> void:
	if project == null:
		return
	_discarded = project.get_instance_id()
	if project == doc:
		Io.wait_background()
		_poll_write()
		Io.remove_recovery(recovery_path)
		recovery_path = ""


func after_save() -> void:
	if doc == null or doc.path.is_empty():
		return
	Io.wait_background()
	_poll_write()
	saved_serial = doc.serial if not doc.dirty else saved_serial
	_tidy_recovery()


func adopt_recovery(project: Project, path: String) -> void:
	if project == null:
		return
	var claimed: String = Io.claim_recovery(path, project)
	if project == doc:
		recovery_path = claimed
	else:
		_adopt[project.get_instance_id()] = claimed


func open_recovery(path: String) -> Project:
	var p: Project = Io.load(path)
	if p == null:
		return null
	p.path = ""
	p.dirty = true
	adopt_recovery(p, path)
	return p


static func recovery_text(info: Dictionary) -> String:
	var clips: int = int(info.get("clips", 0))
	var name_: String = String(info.get("project_name", ""))
	var when: Dictionary = Time.get_datetime_dict_from_unix_time(int(info.get("modified", 0)) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	return "An untitled project%s was not saved when the app last closed. Its last change is in a recovery file (%d %s, %02d:%02d on %04d-%02d-%02d). Open it?" % [
		(" (" + name_ + ")") if not name_.is_empty() else "",
		clips, "clip" if clips == 1 else "clips",
		int(when["hour"]), int(when["minute"]), int(when["year"]), int(when["month"]), int(when["day"])]

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const ExportPresets := preload("res://modules/export/export_presets.gd")
const ExportSequences := preload("res://modules/export/export_sequences.gd")
const STATE_KEY := "queue"
const ENTRIES_KEY := "entries"
const VERSION_KEY := "version"
const VERSION := 1
const STAMP_KEY := "queue_project"
const STATUS_KEY := "queue_status"
const STOPPED_KEY := "queue_was_running"
const STATUS_QUEUED := "queued"
const STATUS_RUNNING := "running"
const PROBE_NAME := ".purrmiere_export_write_probe"
const MARK_STOPPED := "stopped when the app closed, queued again"
const MARK_SEQUENCE_GONE := "that sequence is gone, this would export the one I am looking at"
const MARK_OTHER_PROJECT := "from another project"
const MARK_OTHER_PROJECT_TAIL := ", it will not run until that project is open"
const MARK_FOLDER_GONE := "that folder is gone"
const MARK_FOLDER_LOCKED := "that folder cannot be written to"


static func stamp_of(doc: Project) -> Dictionary:
	if doc == null:
		return {}
	return {"id": doc.id, "created": doc.created, "name": doc.name, "path": doc.path}


static func stamp_in(entry: Dictionary) -> Dictionary:
	var raw: Variant = entry.get(STAMP_KEY, null)
	return raw if raw is Dictionary else {}


static func stamped(entry: Dictionary, doc: Project, status: String) -> Dictionary:
	var out: Dictionary = entry.duplicate(true)
	if stamp_in(out).is_empty() and doc != null:
		out[STAMP_KEY] = stamp_of(doc)
	out[STATUS_KEY] = status
	return out


static func save(queue: Array[Dictionary], running: Dictionary, doc: Project) -> Dictionary:
	var rows: Array = []
	if not running.is_empty():
		rows.append(stamped(running, doc, STATUS_RUNNING))
	for e: Dictionary in queue:
		rows.append(stamped(e, doc, STATUS_QUEUED))
	var out: Dictionary = {}
	out[VERSION_KEY] = VERSION
	out[ENTRIES_KEY] = rows
	return out


static func rows_of(state: Variant) -> Array:
	if state is Array:
		return state
	if state is Dictionary:
		var raw: Variant = (state as Dictionary).get(ENTRIES_KEY, [])
		if raw is Array:
			return raw
	return []


static func entry_of(raw: Dictionary) -> Dictionary:
	var e: Dictionary = ExportPresets.normalise(raw)
	if String(e.get(STATUS_KEY, STATUS_QUEUED)) == STATUS_RUNNING:
		e[STOPPED_KEY] = true
	e[STATUS_KEY] = STATUS_QUEUED
	return e


static func restore(state: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: Variant in rows_of(state):
		if raw is Dictionary:
			out.append(entry_of(raw))
	return out


static func was_running(entry: Dictionary) -> bool:
	return bool(entry.get(STOPPED_KEY, false))


static func is_running(entry: Dictionary) -> bool:
	return String(entry.get(STATUS_KEY, STATUS_QUEUED)) == STATUS_RUNNING


static func same_project(entry: Dictionary, doc: Project) -> bool:
	var st: Dictionary = stamp_in(entry)
	if st.is_empty():
		return true
	if doc == null:
		return false
	var p: String = String(st.get("path", ""))
	if not p.is_empty() and not doc.path.is_empty():
		if p == doc.path:
			return true
	return String(st.get("id", "")) == doc.id and String(st.get("created", "")) == doc.created


static func project_name_of(entry: Dictionary) -> String:
	var st: Dictionary = stamp_in(entry)
	var nm: String = String(st.get("name", "")).strip_edges()
	if not nm.is_empty():
		return nm
	var p: String = String(st.get("path", "")).strip_edges()
	return p.get_file() if not p.is_empty() else ""


static func sequence_gone(entry: Dictionary, doc: Project) -> bool:
	var id: String = String(entry.get(ExportSequences.JOB_KEY, ""))
	if id.is_empty() or doc == null:
		return false
	return doc.sequence_by_id(id) == null


static func folder_of(entry: Dictionary) -> String:
	var dest: Variant = entry.get("destination", {})
	var d: Dictionary = dest if dest is Dictionary else {}
	return String(d.get("dir", "")).strip_edges()


static func folder_writable(dir: String) -> bool:
	var probe: String = dir.path_join(PROBE_NAME + str(OS.get_process_id()))
	var f: FileAccess = FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


static func folder_problem(entry: Dictionary) -> String:
	var dir: String = folder_of(entry)
	if dir.is_empty():
		return ""
	if not DirAccess.dir_exists_absolute(dir):
		return MARK_FOLDER_GONE + ": " + dir
	if not folder_writable(dir):
		return MARK_FOLDER_LOCKED + ": " + dir
	return ""


static func marks(entry: Dictionary, doc: Project) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if was_running(entry):
		out.append(MARK_STOPPED)
	if not same_project(entry, doc):
		var nm: String = project_name_of(entry)
		var who: String = MARK_OTHER_PROJECT if nm.is_empty() else MARK_OTHER_PROJECT + ", " + nm
		out.append(who + MARK_OTHER_PROJECT_TAIL)
	elif sequence_gone(entry, doc):
		out.append(MARK_SEQUENCE_GONE)
	var folder: String = folder_problem(entry)
	if not folder.is_empty():
		out.append(folder)
	return out


static func row_note(entry: Dictionary, doc: Project) -> String:
	var m: PackedStringArray = marks(entry, doc)
	if m.is_empty():
		return ""
	return " [" + ", ".join(m) + "]"


static func is_runnable(entry: Dictionary, doc: Project) -> bool:
	return doc != null and same_project(entry, doc)


static func first_runnable(queue: Array[Dictionary], doc: Project) -> int:
	for i: int in queue.size():
		if is_runnable(queue[i], doc):
			return i
	return -1


static func marked_count(queue: Array[Dictionary], doc: Project) -> int:
	var n: int = 0
	for e: Dictionary in queue:
		if not marks(e, doc).is_empty():
			n += 1
	return n


static func restore_note(queue: Array[Dictionary], doc: Project) -> String:
	if queue.is_empty():
		return ""
	var n: int = marked_count(queue, doc)
	var head: String = "The export queue was kept: " + str(queue.size()) + " job" + ("" if queue.size() == 1 else "s") + " waiting."
	if n == 0:
		return head + " Press Run the queue when you want them."
	return head + " " + str(n) + " need looking at, the reason is written beside each one."

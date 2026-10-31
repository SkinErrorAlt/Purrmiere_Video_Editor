extends Node

signal added(entry: Dictionary)
signal toasted(text: String)
signal noticed(entry: Dictionary)

const MAX_ENTRIES := 500

var _entries: Array[Dictionary] = []


func _entry(kind: String, text: String, detail: String, fixes: PackedStringArray) -> Dictionary:
	return {
		"t": Time.get_unix_time_from_system(),
		"kind": kind,
		"text": text,
		"detail": detail,
		"fixes": fixes,
	}


func _push(e: Dictionary) -> void:
	_entries.append(e)
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	print("[", String(e["kind"]), "] ", String(e["text"]), "" if String(e["detail"]).is_empty() else ": " + String(e["detail"]))
	added.emit(e)


func info(text: String, detail: String = "") -> void:
	_push(_entry("info", text, detail, PackedStringArray()))


func warn(text: String, detail: String = "", fixes: PackedStringArray = PackedStringArray()) -> void:
	_push(_entry("warn", text, detail, fixes))


func error(text: String, detail: String = "", fixes: PackedStringArray = PackedStringArray()) -> void:
	_push(_entry("error", text, detail, fixes))


func toast(text: String) -> void:
	_push(_entry("toast", text, "", PackedStringArray()))
	toasted.emit(text)


func notice(text: String, detail: String = "", actions: Array = [], seconds: float = 3.0) -> void:
	var e: Dictionary = _entry("info", text, detail, PackedStringArray())
	_push(e)
	var n: Dictionary = {"text": text, "detail": detail, "actions": actions, "seconds": seconds}
	noticed.emit(n)
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var script: GDScript = load("res://ui/kit/pm_notice.gd")
		script.call("post", (loop as SceneTree).root, n)


func list() -> Array[Dictionary]:
	return _entries.duplicate()


func clear() -> void:
	_entries.clear()

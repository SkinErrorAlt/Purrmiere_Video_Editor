extends RefCounted

const SELF := preload("res://doc/undo.gd")
const Project := preload("res://doc/project.gd")
const Command := preload("res://doc/commands/command.gd")
const TrackGuard := preload("res://doc/track_guard.gd")
const DEFAULT_DEPTH := 200
const PREF_KEY := "undo_depth"
const LIVE := "live"
const LIVE_SOUND := "live_audio"
const VALUE_KEY_CLIP := "clip_param|"
const VALUE_KEY_EFFECT := "effect_param|"
const SPEED_LENGTH := "res://doc/speed_length.gd"
const MARKER_FOLLOW := "res://doc/marker_follow.gd"
const SUBTITLE_FOLLOW := "res://doc/subtitle_follow.gd"
const PARENT_FOLLOW := "res://doc/parent_follow.gd"
const KEY_ANCHOR := "res://doc/key_anchor.gd"

static var _nesting_reported: bool = false


class Transaction extends RefCounted:
	var label: String = ""
	var commands: Array[Command] = []
	var open: bool = true
	var _owner: SELF = null
	var _nested_from: Array[int] = []
	var guards: Array[Dictionary] = []

	func _init(p_owner: SELF, p_label: String) -> void:
		_owner = p_owner
		label = p_label

	func apply(cmd: Command) -> void:
		if not open:
			print("Undo: apply on a closed transaction was ignored")
			return
		cmd.do(_owner.doc)
		if cmd.ok:
			commands.append(cmd)

	func commit() -> bool:
		if not open:
			return false
		if _nested_from.is_empty():
			commands.append_array(load(SPEED_LENGTH).call("fix", _owner.doc, commands))
			commands.append_array(load(MARKER_FOLLOW).call("fix", _owner.doc, commands))
			commands.append_array(load(SUBTITLE_FOLLOW).call("fix", _owner.doc, commands))
			commands.append_array(load(PARENT_FOLLOW).call("fix", _owner.doc, commands))
			var pinned: Array = load(KEY_ANCHOR).call("fix", _owner.doc, commands)
			if not pinned.is_empty():
				commands.append_array(pinned)
				commands.append_array(load(SPEED_LENGTH).call("fix", _owner.doc, pinned))
		if not TrackGuard.passes(_owner.doc, commands.slice(_nested_from.back() if not _nested_from.is_empty() else 0), guards.back() if not guards.is_empty() else {}):
			abandon()
			return false
		if not _nested_from.is_empty():
			_nested_from.pop_back()
			guards.pop_back()
			return true
		open = false
		_owner._finish(self)
		return true

	func abandon() -> void:
		if not open:
			return
		if not guards.is_empty():
			guards.pop_back()
		var back_to: int = 0
		var nested: bool = not _nested_from.is_empty()
		if nested:
			back_to = _nested_from.pop_back()
		for i: int in range(commands.size() - 1, back_to - 1, -1):
			commands[i].undo(_owner.doc)
		commands.resize(back_to)
		if nested:
			return
		open = false
		_owner._drop(self)

	func is_empty() -> bool:
		return commands.is_empty()


var doc: Project:
	get:
		return _doc_ref.get_ref() if _doc_ref != null else null
var _doc_ref: WeakRef = null
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _open: Transaction = null
var _live: Array[Command] = []
var _depth: int = -1
var live_serial: int = 0
var _quiet_pending: bool = false
var _live_guard: Dictionary = {}


func _init(p_doc: Project) -> void:
	_doc_ref = weakref(p_doc)


func depth() -> int:
	if _depth > 0:
		return _depth
	_depth = DEFAULT_DEPTH
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var prefs: Node = (loop as SceneTree).root.get_node_or_null("Prefs")
		if prefs != null:
			if not bool(prefs.call("is_registered", PREF_KEY)):
				prefs.call("register", PREF_KEY, DEFAULT_DEPTH, {"label": "Undo depth", "type": "int", "min": 10, "max": 5000})
			var v: Variant = prefs.call("get_value", PREF_KEY)
			if v is int or v is float:
				_depth = maxi(int(v), 1)
	return _depth


func set_depth(n: int) -> void:
	_depth = maxi(n, 1)
	_trim()


func begin(label: String) -> Transaction:
	if _open != null and _open.open:
		if not _nesting_reported:
			_nesting_reported = true
			print("Undo: begin(\"" + label + "\") inside \"" + _open.label + "\", the open transaction is reused and the nested commit folds into it")
		_open._nested_from.append(_open.commands.size())
		_open.guards.append(TrackGuard.snapshot(doc))
		return _open
	_open = Transaction.new(self, label)
	_open.guards.append(TrackGuard.snapshot(doc))
	if doc != null:
		doc.hold_changes()
	return _open


func in_transaction() -> bool:
	return _open != null and _open.open


func _finish(tx: Transaction) -> void:
	if tx == _open:
		_open = null
		if doc != null:
			doc.release_changes()
	if tx.commands.is_empty():
		return
	_redo_stack = []
	_undo_stack.append({"label": tx.label, "commands": tx.commands})
	_trim()
	_emit()


func _drop(tx: Transaction) -> void:
	if tx == _open:
		_open = null
		if doc != null:
			doc.release_changes()


func _trim() -> void:
	var limit: int = depth()
	while _undo_stack.size() > limit:
		_undo_stack.pop_front()


func _emit() -> void:
	var d: Project = doc
	if d != null:
		d.history_changed.emit()


func can_undo() -> bool:
	return not _undo_stack.is_empty() and not in_transaction()


func can_redo() -> bool:
	return not _redo_stack.is_empty() and not in_transaction()


func undo() -> bool:
	if in_transaction():
		print("Undo: undo was refused while \"" + _open.label + "\" is open")
		return false
	if not _live.is_empty():
		cancel_live()
	if _undo_stack.is_empty():
		return false
	var entry: Dictionary = _undo_stack.pop_back()
	var cmds: Array[Command] = entry["commands"]
	var d: Project = doc
	if d != null:
		d.hold_changes()
	for i: int in range(cmds.size() - 1, -1, -1):
		cmds[i].undo(d)
	if d != null:
		d.release_changes()
	_redo_stack.append(entry)
	_emit()
	return true


func redo() -> bool:
	if in_transaction():
		print("Undo: redo was refused while \"" + _open.label + "\" is open")
		return false
	if not _live.is_empty():
		cancel_live()
	if _redo_stack.is_empty():
		return false
	var entry: Dictionary = _redo_stack.pop_back()
	var cmds: Array[Command] = entry["commands"]
	var d2: Project = doc
	if d2 != null:
		d2.hold_changes()
	for c: Command in cmds:
		c.do(d2)
	if d2 != null:
		d2.release_changes()
	_undo_stack.append(entry)
	_emit()
	return true


func history() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in _undo_stack.size():
		out.append({"label": str(_undo_stack[i]["label"]), "index": i, "current": i == _undo_stack.size() - 1})
	for j: int in range(_redo_stack.size() - 1, -1, -1):
		out.append({"label": str(_redo_stack[j]["label"]), "index": out.size(), "current": false})
	return out


func current_index() -> int:
	return _undo_stack.size() - 1


func jump(index: int) -> bool:
	if in_transaction():
		return false
	var target: int = clampi(index, -1, _undo_stack.size() + _redo_stack.size() - 1)
	while _undo_stack.size() - 1 > target:
		if not undo():
			return false
	while _undo_stack.size() - 1 < target:
		if not redo():
			return false
	return true


func undo_label() -> String:
	if _undo_stack.is_empty():
		return ""
	return str(_undo_stack[_undo_stack.size() - 1]["label"])


func redo_label() -> String:
	if _redo_stack.is_empty():
		return ""
	return str(_redo_stack[_redo_stack.size() - 1]["label"])


static func is_value_edit(cmd: Command) -> bool:
	var k: String = cmd.live_key()
	return k.begins_with(VALUE_KEY_CLIP) or k.begins_with(VALUE_KEY_EFFECT)


static func touches_sound(cmd: Command) -> bool:
	var p: Variant = cmd.get("path")
	if p is String and String(p).begins_with("audio"):
		return true
	var a: Variant = cmd.get("audio")
	return a is bool and bool(a)


func live(cmd: Command) -> void:
	var d: Project = doc
	var quiet: bool = d != null and is_value_edit(cmd)
	if not quiet:
		if d != null:
			d.hold_changes()
		_live_apply(cmd)
		if d != null:
			d.release_changes()
		return
	var was_blocked: bool = d.is_blocking_signals()
	d.set_block_signals(true)
	_live_apply(cmd)
	d.set_block_signals(was_blocked)
	live_serial += 1
	_quiet_pending = true
	if not was_blocked:
		d.changed.emit(LIVE_SOUND if touches_sound(cmd) else LIVE)


func _live_apply(cmd: Command) -> void:
	if _live.is_empty():
		_live_guard = TrackGuard.snapshot(doc)
	var k: String = cmd.live_key()
	var at: int = -1
	for i: int in _live.size():
		if _live[i].live_key() == k:
			at = i
			break
	if at < 0:
		cmd.do(doc)
		if cmd.ok:
			_live.append(cmd)
		return
	if _swap_alone(at, cmd):
		return
	for i: int in range(_live.size() - 1, at - 1, -1):
		_live[i].undo(doc)
	cmd.do(doc)
	if cmd.ok:
		_live[at] = cmd
	else:
		_live.remove_at(at)
	for i: int in range(at + 1, _live.size()):
		_live[i].do(doc)


const VALUE_KEY_MANY := "clip_param|many|"


static func single_target(cmd: Command) -> bool:
	var k: String = cmd.live_key()
	return k.begins_with(VALUE_KEY_CLIP) and not k.begins_with(VALUE_KEY_MANY)


func _swap_alone(at: int, cmd: Command) -> bool:
	if not single_target(cmd):
		return false
	for i: int in range(at, _live.size()):
		if not single_target(_live[i]):
			return false
	_live[at].undo(doc)
	cmd.do(doc)
	if cmd.ok:
		_live[at] = cmd
	else:
		_live.remove_at(at)
	return true


func live_commands() -> Array[Command]:
	return _live.duplicate()


func live_baseline(key: String) -> Variant:
	for cmd: Command in _live:
		if cmd.live_key() == key and "old" in cmd and cmd.get("old") is Dictionary:
			return cmd.get("old")
	return null


func has_live() -> bool:
	return not _live.is_empty()


func commit_live(label: String) -> void:
	if _live.is_empty():
		return
	var d: Project = doc
	if d != null:
		d.hold_changes()
	_live.append_array(load(SPEED_LENGTH).call("fix", doc, _live))
	_live.append_array(load(MARKER_FOLLOW).call("fix", doc, _live))
	_live.append_array(load(SUBTITLE_FOLLOW).call("fix", doc, _live))
	_live.append_array(load(PARENT_FOLLOW).call("fix", doc, _live))
	var pinned_live: Array = load(KEY_ANCHOR).call("fix", doc, _live)
	if not pinned_live.is_empty():
		_live.append_array(pinned_live)
		_live.append_array(load(SPEED_LENGTH).call("fix", doc, pinned_live))
	if not TrackGuard.passes(doc, _live, _live_guard):
		cancel_live()
		if d != null:
			d.release_changes()
		return
	if d != null:
		d.release_changes()
	var cmds: Array[Command] = _live
	_live = []
	_redo_stack = []
	_undo_stack.append({"label": label, "commands": cmds})
	_trim()
	_catch_up()
	_emit()


func _catch_up() -> void:
	if not _quiet_pending:
		return
	_quiet_pending = false
	var d: Project = doc
	if d != null and not d.is_blocking_signals():
		d.changed.emit("meta")


func cancel_live() -> void:
	var d: Project = doc
	if d != null:
		d.hold_changes()
	for i: int in range(_live.size() - 1, -1, -1):
		_live[i].undo(doc)
	if d != null:
		d.release_changes()
	_live = []
	_quiet_pending = false


func clear() -> void:
	_undo_stack = []
	_redo_stack = []
	_live = []
	_open = null
	_quiet_pending = false
	_emit()

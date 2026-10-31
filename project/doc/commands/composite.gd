extends "res://doc/commands/command.gd"

const Command := preload("res://doc/commands/command.gd")
const EditMath := preload("res://doc/commands/edit_math.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const TrackCmds := preload("res://doc/commands/track_cmds.gd")
const SequenceCmds := preload("res://doc/commands/sequence_cmds.gd")

var steps: Array[Command] = []
var _built: bool = false


func do(doc: Project) -> void:
	if not _built:
		_built = true
		ok = _plan(doc)
		if not ok:
			for i: int in range(steps.size() - 1, -1, -1):
				steps[i].undo(doc)
			steps = []
		return
	for s: Command in steps:
		s.do(doc)


func undo(doc: Project) -> void:
	for i: int in range(steps.size() - 1, -1, -1):
		steps[i].undo(doc)


func apply(doc: Project, cmd: Command) -> Command:
	cmd.do(doc)
	if cmd.ok:
		steps.append(cmd)
	return cmd


func _plan(_doc: Project) -> bool:
	return true

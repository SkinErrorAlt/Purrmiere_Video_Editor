extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Parenting := preload("res://doc/parenting.gd")
const LABEL := "Unparent from a removed clip"

static var enabled: bool = true
static var fixes: int = 0
static var scans: int = 0
static var replays: int = 0
static var last_us: int = 0


static func dangling(doc: Project) -> Dictionary:
	var out: Dictionary = {}
	for s: Sequence in doc.sequences:
		for c: Clip in s.all_clips():
			if c.parent.is_empty():
				continue
			var pid: String = Parenting.parent_id(c)
			var p: Clip = s.clip_by_id(pid)
			if p == null or p == c:
				out[c.id] = s.id
	return out


static func fix(doc: Project, cmds: Array) -> Array[Command]:
	var out: Array[Command] = []
	if not enabled or not Clip.parent_seen or doc == null or cmds.is_empty():
		return out
	var t0: int = Time.get_ticks_usec()
	scans += 1
	var lost: Dictionary = dangling(doc)
	if lost.is_empty():
		last_us = Time.get_ticks_usec() - t0
		return out
	var held: Dictionary = {}
	replays += 1
	for i: int in range(cmds.size() - 1, -1, -1):
		(cmds[i] as Command).undo(doc)
	Parenting.forget()
	for cid: Variant in lost.keys():
		var s: Sequence = doc.sequence_by_id(String(lost[cid]))
		var c: Clip = s.clip_by_id(String(cid)) if s != null else null
		if c != null and Parenting.parent_of(c, s) != null:
			held[cid] = Parenting.parent_xf(c, s, s.playhead, s.fps)
	for cmd: Variant in cmds:
		(cmd as Command).do(doc)
	Parenting.forget()
	for cid2: Variant in lost.keys():
		var s2: Sequence = doc.sequence_by_id(String(lost[cid2]))
		var c2: Clip = s2.clip_by_id(String(cid2)) if s2 != null else null
		if c2 == null or c2.parent.is_empty():
			continue
		var step: Array[Command] = []
		if held.has(cid2) and not Parenting.is_identity(held[cid2]):
			step.append(ClipCmds.SetClipField.new(s2.id, c2.id, "transform", Parenting.baked_transform(c2, held[cid2])))
		step.append(ClipCmds.SetClipField.new(s2.id, c2.id, Parenting.FIELD, {}))
		for sc: Command in step:
			sc.label = LABEL
			sc.do(doc)
			if sc.ok:
				out.append(sc)
		fixes += 1
	last_us = Time.get_ticks_usec() - t0
	return out

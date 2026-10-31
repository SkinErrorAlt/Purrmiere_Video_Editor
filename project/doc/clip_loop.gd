extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const EditMath := preload("res://doc/commands/edit_math.gd")
const MENU_ID := "loop"
const MENU_LABEL := "Loop"
const ON_LABEL := "Loop on"
const OFF_LABEL := "Loop off"
const RULE := "A looping clip repeats its media from its in point for as long as the clip runs, so its edges can be dragged past the end of the media. Each repeat point shows as a coloured seam. Effects, keyframes and transforms run across the whole clip without restarting. Turning Loop off trims the clip back to where its media ends."


static func media_length(doc: Project, c: Clip) -> float:
	if doc == null or c == null:
		return 0.0
	return EditMath.media_duration(doc, c)


static func targets(seq: Sequence, clicked_id: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if seq == null:
		return out
	var seeds: PackedStringArray = Verbs.selection(seq)
	if not clicked_id.is_empty() and seq.clip_by_id(clicked_id) != null and not seeds.has(clicked_id):
		seeds.append(clicked_id)
	for id: String in seeds:
		for c: Clip in seq.linked(seq.clip_by_id(id)):
			if not out.has(c.id):
				out.append(c.id)
	return Verbs.unlocked(seq, out)


static func off_cmds(doc: Project, seq: Sequence, c: Clip) -> Array[Command]:
	var cmds: Array[Command] = []
	cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "loop", false))
	var md: float = media_length(doc, c)
	if md <= Clip.LOOP_MIN:
		return cmds
	var win: Vector2 = c.loop_window(md)
	var new_in: float = Clip.wrap_in(c.in_offset, win, c.loop_forward())
	var probe: Clip = c.copy()
	probe.in_offset = new_in
	var seams: PackedFloat64Array = probe.loop_seams_in(win)
	var new_dur: float = seams[0] if not seams.is_empty() else c.duration
	new_dur = maxf(new_dur, EditMath.min_duration(seq))
	if absf(new_in - c.in_offset) > Clip.LOOP_EPS or new_dur < c.duration - Clip.LOOP_EPS:
		cmds.append(EditCmds.SetTiming.new(seq.id, c.id, c.start, minf(new_dur, c.duration), new_in, 0.0))
	return cmds


static func set_loop(doc: Project, seq: Sequence, ids: PackedStringArray, on: bool) -> bool:
	if doc == null or seq == null:
		return false
	var cmds: Array[Command] = []
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		if c == null or c.loop == on:
			continue
		if on:
			cmds.append(ClipCmds.SetClipField.new(seq.id, id, "loop_in", c.in_offset))
			cmds.append(ClipCmds.SetClipField.new(seq.id, id, "loop", true))
		else:
			cmds.append_array(off_cmds(doc, seq, c))
	return Verbs.run(doc, ON_LABEL if on else OFF_LABEL, cmds)


static func toggle(doc: Project, seq: Sequence, clicked_id: String) -> bool:
	var c: Clip = seq.clip_by_id(clicked_id) if seq != null else null
	if c == null:
		return false
	return set_loop(doc, seq, targets(seq, clicked_id), not c.loop)

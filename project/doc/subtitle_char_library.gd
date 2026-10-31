extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const SubtitleChars := preload("res://doc/subtitle_chars.gd")
const Presets := preload("res://doc/presets.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const SCOPE_USER := "user"
const SCOPE_PROJECT := "project"


static func entries(doc: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for p: Dictionary in SubtitleChars.list_user():
		seen[str(p.get("id", ""))] = true
		var row: Dictionary = p.duplicate(true)
		row["scope"] = SCOPE_USER
		out.append(row)
	for p2: Dictionary in SubtitleChars.list_project(doc):
		if seen.has(str(p2.get("id", ""))):
			continue
		var row2: Dictionary = p2.duplicate(true)
		row2["scope"] = SCOPE_PROJECT
		out.append(row2)
	return Presets.order(out)


static func ids(doc: Project) -> PackedStringArray:
	return Presets.ids_of(entries(doc))


static func entry(doc: Project, id: String) -> Dictionary:
	for p: Dictionary in entries(doc):
		if str(p.get("id", "")) == id:
			return p
	return {}


static func stored(row: Dictionary) -> Dictionary:
	var p: Dictionary = row.duplicate(true)
	p.erase("scope")
	return SubtitleChars.normalize(p)


static func write_user(row: Dictionary) -> bool:
	return SubtitleChars.save_to_user(stored(row))


static func replace_cmds(doc: Project, row: Dictionary) -> Array[Command]:
	var p: Dictionary = stored(row)
	var cmds: Array[Command] = []
	var id: String = str(p.get("id", ""))
	for have: Dictionary in doc.presets:
		if str(have.get("id", "")) == id:
			cmds.append(EffectCmds.RemovePreset.new(id))
			break
	cmds.append(EffectCmds.AddPreset.new(p))
	return cmds


static func write(doc: Project, row: Dictionary, what: String) -> bool:
	if str(row.get("scope", SCOPE_USER)) == SCOPE_PROJECT:
		if doc == null:
			return false
		return Verbs.run(doc, what, replace_cmds(doc, row))
	return write_user(row)


static func next_sort(doc: Project) -> int:
	var top: int = 0
	for p: Dictionary in entries(doc):
		top = maxi(top, Presets.sort_of(p))
	return top + Presets.SORT_STEP


static func save_from_box(doc: Project, seq: Sequence, clip_id: String, label: String, scope: String = "") -> Dictionary:
	if doc == null or seq == null:
		return {}
	var c: Clip = seq.clip_by_id(clip_id)
	if c == null or label.strip_edges().is_empty():
		return {}
	var p: Dictionary = SubtitleChars.from_clip(doc, c, label.strip_edges())
	if p.is_empty():
		return {}
	p["sort"] = next_sort(doc)
	var want: String = scope if scope == SCOPE_PROJECT or scope == SCOPE_USER else SubtitleChars.default_scope()
	if not SubtitleChars.save(doc, p, want):
		return {}
	var row: Dictionary = p.duplicate(true)
	row["scope"] = want
	return row


static func rename(doc: Project, id: String, label: String) -> bool:
	var row: Dictionary = entry(doc, id)
	if row.is_empty() or label.strip_edges().is_empty():
		return false
	var p: Dictionary = SubtitleChars.renamed(stored(row), label)
	p["scope"] = row["scope"]
	return write(doc, p, "Rename character")


static func duplicate_of(doc: Project, id: String, label: String = "") -> Dictionary:
	var row: Dictionary = entry(doc, id)
	if row.is_empty():
		return {}
	var copy: Dictionary = SubtitleChars.copy_of(stored(row), label)
	if copy.is_empty():
		return {}
	copy["scope"] = row["scope"]
	if not write(doc, copy, "Duplicate character"):
		return {}
	var order: PackedStringArray = ids(doc)
	var at: int = order.find(id)
	if at >= 0:
		reorder(doc, Presets.moved_order(order, str(copy["id"]), at + 1))
	return entry(doc, str(copy["id"]))


static func remove(doc: Project, id: String) -> bool:
	var row: Dictionary = entry(doc, id)
	if row.is_empty():
		return false
	if str(row["scope"]) == SCOPE_PROJECT:
		return SubtitleChars.remove_from_project(doc, id)
	return SubtitleChars.delete_user(id)


static func reorder(doc: Project, order: PackedStringArray) -> bool:
	var nums: Dictionary = Presets.numbered(order)
	var wrote: bool = false
	var cmds: Array[Command] = []
	for row: Dictionary in entries(doc):
		var id: String = str(row.get("id", ""))
		if not nums.has(id) or Presets.sort_of(row) == int(nums[id]):
			continue
		var fresh: Dictionary = row.duplicate(true)
		fresh["sort"] = int(nums[id])
		if str(row["scope"]) == SCOPE_PROJECT:
			if doc != null:
				cmds.append_array(replace_cmds(doc, fresh))
		elif write_user(fresh):
			wrote = true
	if not cmds.is_empty() and Verbs.run(doc, "Reorder characters", cmds):
		wrote = true
	return wrote


static func move(doc: Project, id: String, step: int) -> bool:
	var order: PackedStringArray = ids(doc)
	var at: int = order.find(id)
	if at < 0 or step == 0:
		return false
	var to: int = clampi(at + step, 0, order.size() - 1)
	if to == at:
		return false
	return reorder(doc, Presets.moved_order(order, id, to))


static func move_scope(doc: Project, id: String, scope: String) -> bool:
	var row: Dictionary = entry(doc, id)
	if row.is_empty() or str(row["scope"]) == scope or doc == null:
		return false
	var p: Dictionary = stored(row)
	if scope == SCOPE_PROJECT:
		if not SubtitleChars.save_to_project(doc, p):
			return false
		return SubtitleChars.delete_user(id)
	if not SubtitleChars.save_to_user(p):
		return false
	return SubtitleChars.remove_from_project(doc, id)


static func needs_confirm(summary: Dictionary) -> bool:
	return not (summary.get("adds", PackedStringArray()) as PackedStringArray).is_empty() or not (summary.get("removes", PackedStringArray()) as PackedStringArray).is_empty()


static func confirm_text(summary: Dictionary) -> String:
	return str(summary.get("text", ""))


static func apply_by_id(doc: Project, seq: Sequence, id: String, clip_ids: PackedStringArray, with_effects: bool = true) -> bool:
	var row: Dictionary = entry(doc, id)
	if row.is_empty():
		return false
	return SubtitleChars.apply(doc, seq, stored(row), clip_ids, with_effects)


static func summary_for(doc: Project, seq: Sequence, id: String, clip_ids: PackedStringArray, labels: Dictionary = {}) -> Dictionary:
	var row: Dictionary = entry(doc, id)
	if row.is_empty():
		return {}
	return SubtitleChars.preview(doc, seq, stored(row), clip_ids, labels)


static func current_of(doc: Project, seq: Sequence, clip_ids: PackedStringArray) -> String:
	var found: String = ""
	for c: Clip in SubtitleChars.text_boxes(doc, seq, clip_ids):
		var id: String = SubtitleChars.character_of(c)
		if found.is_empty():
			found = id
		elif id != found:
			return ""
	return found


static func lane_box_ids(doc: Project, seq: Sequence, track_id: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var tr: Track = seq.track_by_id(track_id) if seq != null else null
	if tr == null:
		return out
	for c: Clip in tr.clips:
		out.append(c.id)
	return ids_of_boxes(doc, seq, out)


static func ids_of_boxes(doc: Project, seq: Sequence, clip_ids: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for c: Clip in SubtitleChars.text_boxes(doc, seq, clip_ids):
		out.append(c.id)
	return out

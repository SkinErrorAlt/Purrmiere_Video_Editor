extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const ROW_SLOP := 4.0


static func step(entries: Array[Dictionary], rects: Array[Rect2], current: String, keycode: int, grid: bool) -> String:
	if entries.is_empty():
		return ""
	var cur: int = -1
	for i: int in entries.size():
		if String(entries[i]["id"]) == current:
			cur = i
	if cur < 0:
		return String(entries[0]["id"])
	var forward: bool = keycode == KEY_DOWN or keycode == KEY_RIGHT
	if not grid or keycode == KEY_LEFT or keycode == KEY_RIGHT or rects.size() != entries.size():
		return String(entries[clampi(cur + (1 if forward else -1), 0, entries.size() - 1)]["id"])
	var here: Rect2 = rects[cur]
	var row_y: float = INF if forward else -INF
	for i2: int in rects.size():
		var y: float = rects[i2].position.y
		if forward and y > here.position.y + ROW_SLOP and y < row_y:
			row_y = y
		elif not forward and y < here.position.y - ROW_SLOP and y > row_y:
			row_y = y
	if is_inf(row_y):
		return current
	var best: int = cur
	var best_d: float = INF
	var cx: float = here.get_center().x
	for i3: int in rects.size():
		if absf(rects[i3].position.y - row_y) > ROW_SLOP:
			continue
		var d: float = absf(rects[i3].get_center().x - cx)
		if d < best_d:
			best_d = d
			best = i3
	return String(entries[best]["id"])


static func users(doc: Project, ids: PackedStringArray) -> Dictionary:
	var per_seq: Dictionary = {}
	var total: int = 0
	if doc == null:
		return {"total": 0, "per_seq": per_seq}
	var seq_of_item: Dictionary = {}
	for id: String in ids:
		var m: MediaItem = doc.media_by_id(id)
		if m != null and m.kind == "sequence":
			seq_of_item[m.sequence_id] = true
	for s: Sequence in doc.sequences:
		if seq_of_item.has(s.id):
			continue
		var n: int = 0
		for t: Track in s.all_tracks():
			for c: Clip in t.clips:
				if ids.has(c.media_id) or (not c.sequence_id.is_empty() and seq_of_item.has(c.sequence_id)):
					n += 1
		if n > 0:
			per_seq[s.label] = n
			total += n
	return {"total": total, "per_seq": per_seq}


static func remove_text(doc: Project, ids: PackedStringArray) -> Dictionary:
	var u: Dictionary = users(doc, ids)
	var count: int = ids.size()
	var first: MediaItem = doc.media_by_id(ids[0]) if doc != null and not ids.is_empty() else null
	var what: String = (first.label if first != null else "this item") if count == 1 else str(count) + " items"
	var title: String = "Remove " + what + " from the bin"
	var total: int = int(u["total"])
	if total <= 0:
		return {"title": title, "text": "", "clips": 0}
	var parts: PackedStringArray = PackedStringArray()
	var per: Dictionary = u["per_seq"]
	for k: Variant in per.keys():
		parts.append(String(k) + " has " + str(int(per[k])))
	var them: String = "it" if count == 1 else "them"
	var lines: PackedStringArray = PackedStringArray()
	lines.append(("1 clip" if total == 1 else str(total) + " clips") + " on the timeline " + ("uses " if total == 1 else "use ") + them + " and " + ("goes" if total == 1 else "go") + " too: " + ", ".join(parts) + ".")
	var others: int = (doc.media.size() - count) if doc != null else 0
	lines.append("What stays: the files on your disk, the other " + str(maxi(others, 0)) + (" item" if others == 1 else " items") + " in the bin, and every clip that uses something else.")
	lines.append("Undo puts it all back.")
	return {"title": title, "text": "\n".join(lines), "clips": total}


static func ask_remove(panel: Object, host: Node, entry_id: String) -> bool:
	var doc: Project = Session.doc
	if doc == null or panel == null:
		return false
	if entry_id.begins_with("bin:") or not panel.has_method("drag_ids_for"):
		panel.call("remove_entry", entry_id)
		return true
	var ids: PackedStringArray = panel.call("drag_ids_for", entry_id)
	var plan: Dictionary = remove_text(doc, ids)
	if int(plan["clips"]) <= 0 or host == null:
		panel.call("remove_entry", entry_id)
		return true
	var answered: Signal = PmUI.confirm(host, String(plan["title"]), String(plan["text"]), "Remove", "Keep them")
	answered.connect(func(result: Variant) -> void:
		if result == true:
			panel.call("remove_entry", entry_id))
	return false

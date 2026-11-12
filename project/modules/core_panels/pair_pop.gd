extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const LayoutCmds := preload("res://doc/commands/pair_layout_cmds.gd")
const PairLayout := preload("res://engine/pair_layout.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const POP_ID := "pv_pop_cam"
const POP_PREFIX := "pv_pop_region:"
const POP_SUB := "pv_pop_sub"
const POP_LABEL := "Pop the webcam onto its own track"
const POP_NAMED := "Pop %s onto its own track"
const POP_MANY := "Pop the webcam onto its own track, on %d clips"
const SUB_LABEL := "Pop a region onto its own track"
const UNDO_LABEL := "Pop the webcam onto its own track"
const REGION_LABEL := "Pop a region onto its own track"
const CAM_WORDS: PackedStringArray = ["webcam", "facecam", "face cam", "cam", "camera", "face"]
const SMALL_SHARE := 0.5


static func _session() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Session")
	return null


static func _where() -> Dictionary:
	var s: Node = _session()
	if s == null:
		return {}
	var d: Variant = s.get("doc")
	var sq: Variant = s.call("seq")
	if not (d is Project) or not (sq is Sequence):
		return {}
	return {"doc": d, "seq": sq}


static func source_size(d: Project, s: Sequence, c: Clip) -> Vector2:
	return Vector2(LayoutCmds.source_px(d, s, c))


static func open_regions(s: Sequence, c: Clip, e: Dictionary) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if c == null or e.is_empty() or PairLayout.solo_of(e) >= 0 or c.is_nest():
		return out
	var crops: Array = PairLayout.parse(PairLayout.crops_text(e))
	var taken: Dictionary = LayoutCmds.own_track_clips(s, c, String(e.get("uid", "")))
	for i: int in mini(crops.size(), PairLayout.REGION_MAX):
		if taken.has(i) or bool((crops[i] as Dictionary).get(PairLayout.OUT_KEY, false)):
			continue
		out.append(i)
	return out


static func webcam_of(e: Dictionary, src: Vector2, open: PackedInt32Array) -> int:
	if open.size() < 2:
		return -1
	var crops: Array = PairLayout.parse(PairLayout.crops_text(e))
	for word: String in CAM_WORDS:
		for i: int in open:
			var name_: String = String((crops[i] as Dictionary).get("name", "")).to_lower()
			if name_.contains(word):
				return i
	var smallest: int = -1
	var small_area: float = INF
	var big_area: float = 0.0
	for i2: int in open:
		var r: Rect2 = (crops[i2] as Dictionary)["rect"]
		var area: float = r.size.x * src.x * r.size.y * src.y
		big_area = maxf(big_area, area)
		if area < small_area:
			small_area = area
			smallest = i2
	if smallest >= 0 and small_area <= big_area * SMALL_SHARE:
		return smallest
	return -1


static func _name_of(e: Dictionary, index: int) -> String:
	var crops: Array = PairLayout.parse(PairLayout.crops_text(e))
	var n: String = String((crops[index] as Dictionary).get("name", "")).strip_edges() if index < crops.size() else ""
	return n if not n.is_empty() else "View " + str(index + 1)


static func _targets(s: Sequence, clip_id: String) -> PackedStringArray:
	if s != null and s.selected_clip_ids.has(clip_id):
		return Verbs.selection(s)
	return PackedStringArray([clip_id])


static func plan(d: Project, s: Sequence, clip_ids: PackedStringArray, region: int) -> Array[Command]:
	var out: Array[Command] = []
	if d == null or s == null:
		return out
	var seen: Dictionary = {}
	for cid: String in clip_ids:
		var c: Clip = s.clip_by_id(cid)
		if c == null or seen.has(c.id):
			continue
		var e: Dictionary = PairLayout.pair_entry(c)
		if e.is_empty():
			continue
		var tr: Variant = s.track_of(c.id)
		if tr == null or bool((tr as Object).get("locked")):
			continue
		var open: PackedInt32Array = open_regions(s, c, e)
		var pick: int = region if region >= 0 else webcam_of(e, source_size(d, s, c), open)
		if pick < 0 or not open.has(pick):
			continue
		seen[c.id] = true
		for other: Clip in s.linked(c):
			seen[other.id] = true
		out.append(LayoutCmds.RegionOwnTrack.new(s.id, c.id, String(e.get("uid", "")), pick, "", clampf(s.playhead, c.start, maxf(c.end() - 0.0001, c.start))))
	return out


static func pop_in(d: Project, s: Sequence, clip_ids: PackedStringArray, region: int = -1) -> PackedStringArray:
	var made: PackedStringArray = PackedStringArray()
	var cmds: Array[Command] = plan(d, s, clip_ids, region)
	if cmds.is_empty():
		return made
	if not Verbs.run(d, UNDO_LABEL if region < 0 else REGION_LABEL, cmds):
		return made
	for cmd: Command in cmds:
		var id: String = String(cmd.get("made_clip"))
		if not id.is_empty():
			made.append(id)
	return made


static func clip_menu_items(c: Clip) -> Array:
	var w: Dictionary = _where()
	if w.is_empty() or c == null:
		return []
	var d: Project = w["doc"]
	var s: Sequence = w["seq"]
	var e: Dictionary = PairLayout.pair_entry(c)
	var open: PackedInt32Array = open_regions(s, c, e)
	if open.size() < 2:
		return []
	var items: Array = []
	var cam: int = webcam_of(e, source_size(d, s, c), open)
	var targets: PackedStringArray = _targets(s, c.id)
	var many: int = plan(d, s, targets, -1).size() if targets.size() > 1 else 0
	if many > 1:
		items.append(PmMenu.item(POP_ID, POP_MANY % many))
	elif cam >= 0:
		var name_: String = _name_of(e, cam)
		items.append(PmMenu.item(POP_ID, POP_LABEL if CAM_WORDS.has(name_.to_lower()) else POP_NAMED % name_))
	var sub: Array = []
	for i: int in open:
		sub.append(PmMenu.item(POP_PREFIX + str(i), _name_of(e, i)))
	items.append(PmMenu.sub_item(POP_SUB, SUB_LABEL, sub))
	return items


static func on_clip_menu(id: String, clip_id: String) -> bool:
	if id != POP_ID and not id.begins_with(POP_PREFIX):
		return false
	var w: Dictionary = _where()
	if w.is_empty():
		return true
	var s: Sequence = w["seq"]
	var region: int = -1 if id == POP_ID else int(id.substr(POP_PREFIX.length()))
	var ids: PackedStringArray = _targets(s, clip_id) if region < 0 else PackedStringArray([clip_id])
	if pop_in(w["doc"], s, ids, region).is_empty():
		var events: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Events")
		if events != null:
			events.call("toast", "Nothing to pop: the track above has a clip in the way, or the region is already on its own track")
	return true

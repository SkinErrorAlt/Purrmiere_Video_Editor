extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Timecode := preload("res://doc/timecode.gd")
const Verbs := preload("res://doc/verbs.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const Usage := preload("res://modules/core_panels/bin_views/usage.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmTextKit := preload("res://ui/kit/pm_text.gd")
const IconsKit := preload("res://ui/kit/icons.gd")
const MENU_USED := "used_at"
const USED_PREFIX := "used_at:"
const MENU_NOTES := "notes"
const NOTES_LABEL := "Notes..."
const USED_LABEL := "Where is this used"
const NOTHING_LABEL := "Not used in any sequence"
const MENU_CAP := 40
const NOTES_MAX := 2000

static var _counts: Dictionary = {}
static var _stamp: String = ""


static func counts(doc: Project) -> Dictionary:
	if doc == null:
		return {}
	var stamp: String = str(doc.get_instance_id()) + "|" + str(doc.serial)
	if stamp == _stamp:
		return _counts
	if doc.undo != null and doc.undo.has_live() and not _stamp.is_empty() and _stamp.begins_with(str(doc.get_instance_id()) + "|"):
		return _counts
	_counts = {}
	var raw: Dictionary = Usage.collect(doc, PackedStringArray())
	for id: Variant in raw.keys():
		_counts[String(id)] = int((raw[id] as Dictionary).get("count", 0))
	_stamp = stamp
	return _counts


static func count_of(doc: Project, media_id: String) -> int:
	return int(counts(doc).get(media_id, 0))


static func badge_text(n: int) -> String:
	return "Used " + str(n)


static func badge_rect(pic: Rect2, n: int) -> Rect2:
	if n <= 0:
		return Rect2()
	var f: Font = Tk.font("mono")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var w: float = ceil(PmTextKit.width_of(f, badge_text(n), fs)) + PmTextKit.chip_pad() * 2.0
	var h: float = ceil(f.get_height(fs)) + 3.0
	if w > pic.size.x - 10.0 or h > pic.size.y - 6.0:
		return Rect2()
	return Rect2(pic.position.x + 6.0, pic.position.y + 4.0, w, h)


static func draw_tile(ci: CanvasItem, pic: Rect2, doc: Project, item: MediaItem) -> void:
	if doc == null or item == null:
		return
	var n: int = count_of(doc, item.id)
	var r: Rect2 = badge_rect(pic, n)
	if r.size.x > 0.0:
		var f: Font = Tk.font("mono")
		var fs: int = Tk.fs(Tk.sz("font_small"))
		ci.draw_rect(r, Color(Tk.c["bg_app"], 0.78), true)
		ci.draw_rect(r, Tk.c["accent_dim"], false, 1.0)
		PmTextKit.draw(ci, f, r, badge_text(n), fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, PmTextKit.chip_pad(), NAN, PmTextKit.WHOLE)
	if not item.notes.strip_edges().is_empty():
		var s: float = minf(float(Tk.px(14.0)), pic.size.y * 0.3)
		var nr: Rect2 = Rect2(pic.end.x - s - 5.0, pic.position.y + 4.0, s, s)
		ci.draw_rect(nr.grow(2.0), Color(Tk.c["bg_app"], 0.72), true)
		IconsKit.draw(ci, "more", nr, Tk.c["text_bright"])


static func hit(pic: Rect2, doc: Project, item: MediaItem, at: Vector2) -> bool:
	if doc == null or item == null:
		return false
	var r: Rect2 = badge_rect(pic, count_of(doc, item.id))
	return r.size.x > 0.0 and r.grow(2.0).has_point(at)


static func uses_of(doc: Project, media_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null:
		return out
	var m: MediaItem = doc.media_by_id(media_id)
	var nested: String = m.sequence_id if m != null and m.kind == "sequence" else ""
	for s: Sequence in doc.sequences:
		var seen: Dictionary = {}
		for t: Track in s.all_tracks():
			for c: Clip in t.clips:
				if c.media_id != media_id and (nested.is_empty() or c.sequence_id != nested):
					continue
				var family: String = c.link_id if not c.link_id.is_empty() else c.id
				if seen.has(family):
					continue
				seen[family] = true
				out.append({"seq_id": s.id, "seq_label": s.label, "clip_id": c.id, "track": t.shown_label(), "start": c.start, "fps": s.fps})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if String(a["seq_label"]) != String(b["seq_label"]):
			return String(a["seq_label"]) < String(b["seq_label"])
		return float(a["start"]) < float(b["start"]))
	return out


static func use_label(u: Dictionary) -> String:
	return String(u["seq_label"]) + ", " + String(u["track"]) + " at " + Timecode.format(float(u["start"]), float(u["fps"]))


static func menu_items(doc: Project, media_id: String) -> Array:
	var items: Array = []
	var uses: Array[Dictionary] = uses_of(doc, media_id)
	var sub: Array = []
	for i: int in mini(uses.size(), MENU_CAP):
		var u: Dictionary = uses[i]
		sub.append(PmMenu.item(USED_PREFIX + String(u["seq_id"]) + "|" + String(u["clip_id"]), use_label(u)))
	if uses.size() > MENU_CAP:
		var more: Dictionary = PmMenu.item("used_more", "and " + str(uses.size() - MENU_CAP) + " more")
		more["disabled"] = true
		sub.append(more)
	if sub.is_empty():
		var none: Dictionary = PmMenu.item(MENU_USED, NOTHING_LABEL)
		none["disabled"] = true
		items.append(none)
	else:
		items.append(PmMenu.sub_item(MENU_USED, USED_LABEL + " (" + str(uses.size()) + ")", sub))
	items.append(PmMenu.item(MENU_NOTES, NOTES_LABEL))
	return items


static func jump(doc: Project, seq_id: String, clip_id: String) -> bool:
	if doc == null:
		return false
	var s: Sequence = doc.sequence_by_id(seq_id)
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c == null:
		return false
	if Session.seq() != s:
		Session.set_sequence(seq_id)
	Session.set_playhead(c.start)
	Verbs.select(doc, s, PackedStringArray([clip_id]), "replace")
	var warn: GDScript = load("res://ui/timeline/timeline_warnings.gd")
	var cv: Control = warn.call("canvas")
	if cv != null and cv.is_inside_tree():
		warn.call("reveal", cv, s, clip_id, c.start)
	return true


static func on_pick(host: Node, doc: Project, id: String, ids: PackedStringArray) -> bool:
	if id.begins_with(USED_PREFIX):
		var parts: PackedStringArray = id.substr(USED_PREFIX.length()).split("|")
		if parts.size() == 2:
			jump(doc, parts[0], parts[1])
		return true
	if id == MENU_NOTES:
		ask_notes(host, doc, ids)
		return true
	return false


static func open_menu(anchor: Control, doc: Project, media_id: String, at: Vector2) -> Control:
	var uses: Array[Dictionary] = uses_of(doc, media_id)
	var items: Array = []
	for i: int in mini(uses.size(), MENU_CAP):
		var u: Dictionary = uses[i]
		items.append(PmMenu.item(USED_PREFIX + String(u["seq_id"]) + "|" + String(u["clip_id"]), use_label(u)))
	if items.is_empty():
		return null
	var m: Control = PmMenu.open(anchor, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", func(pid: String) -> void: on_pick(anchor, doc, pid, PackedStringArray([media_id])))
	return m


static func notes_of(doc: Project, ids: PackedStringArray) -> String:
	var shared: String = ""
	for i: int in ids.size():
		var m: MediaItem = doc.media_by_id(ids[i]) if doc != null else null
		var n: String = m.notes if m != null else ""
		if i == 0:
			shared = n
		elif n != shared:
			return ""
	return shared


static func notes_cmds(doc: Project, ids: PackedStringArray, text: String) -> Array[Command]:
	var out: Array[Command] = []
	var clean: String = text.strip_edges().substr(0, NOTES_MAX)
	for id: String in ids:
		var m: MediaItem = doc.media_by_id(id) if doc != null else null
		if m != null and m.notes != clean:
			out.append(MediaCmds.SetMediaField.new(id, "notes", clean))
	return out


static func set_notes(doc: Project, ids: PackedStringArray, text: String) -> bool:
	var cmds: Array[Command] = notes_cmds(doc, ids, text)
	if cmds.is_empty():
		return false
	var label: String = "Clear notes" if text.strip_edges().is_empty() else "Edit notes"
	return Verbs.run(doc, label, cmds)


static func ask_notes(host: Node, doc: Project, ids: PackedStringArray) -> bool:
	if host == null or doc == null or ids.is_empty():
		return false
	var title: String = "Notes for " + (str(ids.size()) + " items" if ids.size() > 1 else (doc.media_by_id(ids[0]).label if doc.media_by_id(ids[0]) != null else "this item"))
	var fields: Array[Dictionary] = [{"key": "notes", "label": "Notes", "type": "string", "default": notes_of(doc, ids)}]
	if ids.size() > 1:
		fields.append({"key": "note", "label": "", "type": "note", "default": "The text goes on every selected item."})
	var answered: Signal = PmUI.form(host, title, fields, "Save", "Cancel")
	answered.connect(func(result: Variant) -> void:
		if result is Dictionary and (result as Dictionary).has("notes"):
			set_notes(doc, ids, String((result as Dictionary)["notes"])))
	return true

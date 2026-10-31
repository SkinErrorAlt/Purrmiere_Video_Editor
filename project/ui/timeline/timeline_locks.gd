extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const Icons := preload("res://ui/kit/icons.gd")
const TrackGuard := preload("res://doc/track_guard.gd")
const LockCmds := preload("res://doc/commands/lock_cmds.gd")
const SHEET_PATH := "res://modules/core_panels/track_lock_sheet.gd"
const MENU_ID := "lock_menu"
const FULL_ID := "lock"
const KIND_PREFIX := "lock_kind:"
const FILES_ID := "lock_files"
const TAG_ID := "lock_tag"
const GAP := 6.0
const NAME_ROOM := 40.0
const BADGE := 9.0


static func menu_item(t: Track) -> Dictionary:
	var k: String = TrackGuard.kind_of(t)
	var sub: Array = []
	sub.append(PmMenu.check_item(FULL_ID, "Full lock", t.locked))
	sub.append(PmMenu.separator())
	sub.append(PmMenu.check_item(KIND_PREFIX, TrackGuard.kind_name(""), k.is_empty()))
	sub.append(PmMenu.check_item(KIND_PREFIX + TrackGuard.CUT, TrackGuard.kind_name(TrackGuard.CUT), k == TrackGuard.CUT))
	sub.append(PmMenu.check_item(KIND_PREFIX + TrackGuard.FILES, TrackGuard.kind_name(TrackGuard.FILES) + "...", k == TrackGuard.FILES))
	sub.append(PmMenu.check_item(KIND_PREFIX + TrackGuard.KEEP, TrackGuard.kind_name(TrackGuard.KEEP), k == TrackGuard.KEEP))
	if k == TrackGuard.FILES:
		sub.append(PmMenu.separator())
		sub.append(PmMenu.item(FILES_ID, "Choose files..."))
	return PmMenu.sub_item(MENU_ID, "Lock", sub, "lock")


static func on_header_menu(canvas: Control, id: String, track_id: String) -> bool:
	if not id.begins_with(KIND_PREFIX) and id != FILES_ID:
		return false
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	var t: Track = s.track_by_id(track_id) if s != null else null
	if d == null or t == null:
		return true
	var kind: String = id.substr(KIND_PREFIX.length()) if id.begins_with(KIND_PREFIX) else TrackGuard.FILES
	if kind == TrackGuard.FILES:
		open_sheet(canvas, track_id)
		return true
	LockCmds.set_lock(d, s, track_id, kind)
	return true


static func open_sheet(host: Node, track_id: String) -> Node:
	var script: GDScript = load(SHEET_PATH)
	if script == null:
		return null
	return script.call("open", host, track_id)


static func badge(t: Track) -> String:
	var k: String = TrackGuard.kind_of(t)
	if k == TrackGuard.CUT:
		return "C"
	if k == TrackGuard.FILES:
		return "F"
	if k == TrackGuard.KEEP:
		return "N"
	return ""


static func tag_font() -> Font:
	return Tk.font("mono")


static func tag_fs() -> int:
	return Tk.fs(Tk.sz("font_tiny"))


static func tag_width(text: String) -> float:
	return PmText.width_of(tag_font(), text, tag_fs()) + PmText.chip_pad() * 2.0 + 2.0


static func dress(out: Array[Dictionary], t: Track, r: Rect2, tall: bool, name_x: float) -> void:
	if t.lock_kind.is_empty():
		return
	var text: String = TrackGuard.tag(t)
	for b: Dictionary in out:
		if String(b["id"]) == FULL_ID:
			b["on"] = t.locked or not text.is_empty()
			b["icon"] = "lock" if bool(b["on"]) else "unlock"
			b["tip"] = TrackGuard.tip(t)
			if not t.locked and not text.is_empty():
				b["badge"] = badge(t)
	if text.is_empty() or t.locked or out.is_empty():
		return
	var w: float = tag_width(text)
	var ic: float = float(Tk.px(15.0))
	var rect: Rect2 = Rect2()
	if tall:
		var right: float = -INF
		var y: float = 0.0
		for b2: Dictionary in out:
			var br: Rect2 = b2["rect"]
			if String(b2["id"]) != "pin" and br.end.x > right:
				right = br.end.x
				y = br.position.y
		rect = Rect2(right + GAP, y, w, ic)
	else:
		var left: float = INF
		var y2: float = 0.0
		for b3: Dictionary in out:
			var br2: Rect2 = b3["rect"]
			if String(b3["id"]) != "pin" and br2.position.x < left:
				left = br2.position.x
				y2 = br2.position.y
		rect = Rect2(left - GAP - w, y2, w, ic)
		if rect.position.x < name_x + NAME_ROOM:
			return
	if rect.end.x > r.end.x - GAP:
		return
	out.append({"id": TAG_ID, "rect": rect, "icon": "", "on": true, "tip": TrackGuard.tip(t), "chip": text})


static func draw_chip(ci: CanvasItem, b: Dictionary, tint: Color) -> void:
	var r: Rect2 = b["rect"]
	var f: Font = tag_font()
	var fs: int = tag_fs()
	if b.has("badge"):
		Icons.draw(ci, String(b["icon"]), r, tint)
		var side: float = maxf(float(Tk.px(BADGE)), ceil(f.get_height(fs)) - 2.0)
		var br: Rect2 = Rect2(r.end.x - side * 0.7, r.end.y - side * 0.6, side, side)
		Paint.rounded(ci, br, Tk.c["sol"], float(Tk.px(2.0)), Tk.c["bg_panel_alt"], 1)
		PmText.draw(ci, f, br, String(b["badge"]), fs, Tk.c["inv"], HORIZONTAL_ALIGNMENT_CENTER, 0.0, PmText.baseline_in(f, fs, br), PmText.WHOLE)
		return
	Paint.rounded(ci, r, Color(0, 0, 0, 0), float(Tk.px(Tk.sz("radius_chip"))), Tk.c["border_soft"], 1)
	PmText.draw(ci, f, r, String(b["chip"]).to_upper(), fs, Tk.c["text"], HORIZONTAL_ALIGNMENT_CENTER, PmText.chip_pad(), PmText.baseline_in(f, fs, r), PmText.WHOLE)


static func drop_refusal(d: Project, s: Sequence, dp: Dictionary) -> String:
	if d == null or s == null or dp.is_empty():
		return ""
	var ids: PackedStringArray = PackedStringArray()
	var raw: Variant = dp.get("ids", [])
	if raw is Array or raw is PackedStringArray:
		for v: Variant in raw:
			ids.append(String(v))
	var t0: float = float(dp.get("t", 0.0))
	var t1: float = t0 + float(dp.get("total", 0.0))
	var clears: bool = not bool(dp.get("insert", false)) and not bool(dp.get("overlap", false))
	for key: String in ["video_lane", "audio_lane"]:
		var lane: Dictionary = dp.get(key, {})
		var tr: Track = lane.get("track", null) if not lane.is_empty() else null
		if tr == null:
			continue
		for id: String in ids:
			var why: String = TrackGuard.refusal(d, s, tr, TrackGuard.PLACE, id)
			if not why.is_empty():
				return why
		if not clears or ids.is_empty():
			continue
		for c: Clip in tr.clips_in_range(t0, t1):
			if c.end() > t0 + TrackGuard.EPS and c.start < t1 - TrackGuard.EPS:
				var hit: String = TrackGuard.refusal(d, s, tr, TrackGuard.REPLACE, ids[0], c.label)
				if not hit.is_empty():
					return hit
				break
	return ""

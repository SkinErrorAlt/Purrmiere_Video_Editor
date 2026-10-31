extends RefCounted

const Track := preload("res://doc/track.gd")
const Icons := preload("res://ui/kit/icons.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const Locks := preload("res://ui/timeline/timeline_locks.gd")
const ICON := 15.0
const GAP := 6.0
const TALL_MIN := 38.0
const SWATCH_W := 3.0
const METER_W := 3.0
const PIN_W := 16.0
const NAME_X := 26.0
const FREE_ITEM := "free_tracks"
const FREE_CMD := "seq.free_tracks"
const FREE_ICON := "combo"
const VIEW_TIP_OFF := "View only hide: hide this track from the Program monitor and playback, never from exports (the eye is the one that changes the output)"
const VIEW_TIP_ON := "Hidden from view only, exports still include it. Click to show it in the Program monitor again"


static func is_tall(h: float) -> bool:
	return h >= float(Tk.px(TALL_MIN))


static func name_rect(r: Rect2, pinned: bool) -> Rect2:
	var right: float = r.end.x - (float(Tk.px(PIN_W)) + GAP) - (METER_W + GAP)
	var x: float = r.position.x + float(Tk.px(NAME_X))
	var h: float = 18.0
	var y: float = r.position.y + 4.0
	if not is_tall(r.size.y):
		right = r.end.x - 2.0 * (float(Tk.px(ICON)) + GAP) - GAP - (float(Tk.px(PIN_W)) if pinned else 0.0)
		y = r.position.y + (r.size.y - h) * 0.5
	return Rect2(x, y, maxf(20.0, right - x), h)


static func buttons(t: Track, r: Rect2, in_band: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ic: float = float(Tk.px(ICON))
	var tall: bool = is_tall(r.size.y)
	var mute_icon: String
	if t.kind == "video" or t.free:
		mute_icon = "eye_off" if t.muted else "eye"
	else:
		mute_icon = "speaker_off" if t.muted else "speaker"
	var pin_rect: Rect2 = Rect2(r.end.x - float(Tk.px(PIN_W)) - GAP, r.position.y + 4.0, float(Tk.px(PIN_W)), ic)
	if not tall:
		pin_rect.position.y = r.position.y + (r.size.y - ic) * 0.5
	if tall or in_band:
		out.append({"id": "pin", "rect": pin_rect, "icon": "pin", "on": t.pinned, "tip": "Unpin track" if t.pinned else "Pin track"})
	if tall:
		var y2: float = r.end.y - ic - 5.0
		var x: float = r.position.x + float(Tk.px(NAME_X)) - 16.0
		out.append({"id": "mute", "rect": Rect2(x, y2, ic, ic), "icon": mute_icon, "on": not t.muted, "tip": mute_tip(t)})
		x += ic + GAP
		if t.kind == "audio" or t.free:
			out.append({"id": "solo", "rect": Rect2(x, y2, ic, ic), "icon": "", "on": t.solo, "tip": "Solo track", "text": "S"})
			x += ic + GAP
		out.append({"id": "lock", "rect": Rect2(x, y2, ic, ic), "icon": "lock" if t.locked else "unlock", "on": t.locked, "tip": "Lock track"})
		x += ic + GAP
		out.append({"id": "target", "rect": Rect2(x, y2, ic, ic), "icon": "target" if t.targeted else "target_off", "on": t.targeted, "tip": "Target track"})
		x += ic + GAP
		out.append({"id": "sync", "rect": Rect2(x, y2, ic, ic), "icon": "chain", "on": t.sync_lock, "tip": "Sync lock"})
		if t.kind == "video" or t.free:
			x += ic + GAP
			out.append(view_button(t, Rect2(x, y2, ic, ic)))
	else:
		var y1: float = r.position.y + (r.size.y - ic) * 0.5
		var x1: float = r.end.x - ic - GAP - (float(Tk.px(PIN_W)) + GAP if in_band else 0.0)
		out.append({"id": "lock", "rect": Rect2(x1, y1, ic, ic), "icon": "lock" if t.locked else "unlock", "on": t.locked, "tip": "Lock track"})
		x1 -= ic + GAP
		out.append({"id": "mute", "rect": Rect2(x1, y1, ic, ic), "icon": mute_icon, "on": not t.muted, "tip": mute_tip(t)})
		if (t.kind == "video" or t.free) and t.view_hidden:
			x1 -= ic + GAP
			out.append(view_button(t, Rect2(x1, y1, ic, ic)))
	Locks.dress(out, t, r, tall, r.position.x + float(Tk.px(NAME_X)))
	return out


static func view_button(t: Track, r: Rect2) -> Dictionary:
	return {"id": "view", "rect": r, "icon": "", "text": "V", "on": t.view_hidden, "tip": VIEW_TIP_ON if t.view_hidden else VIEW_TIP_OFF}


static func button_at(t: Track, r: Rect2, in_band: bool, pos: Vector2) -> String:
	for b: Dictionary in buttons(t, r, in_band):
		if (b["rect"] as Rect2).grow(2.0).has_point(pos):
			return String(b["id"])
	return ""


static func draw(ci: CanvasItem, t: Track, r: Rect2, in_band: bool, focused: bool, font: Font, fs: int, rename_open: bool, selected: bool = false) -> void:
	ci.draw_rect(r, Tk.c["bg_panel_alt"], true)
	if selected:
		ci.draw_rect(r, Tk.c["accent"] * Color(1.0, 1.0, 1.0, 0.22), true)
		ci.draw_rect(r, Tk.c["accent"], false, 1.0)
	if t.targeted:
		ci.draw_rect(Rect2(r.position.x, r.position.y, 3.0, r.size.y), Tk.c["accent"], true)
	elif t.colour >= 0:
		ci.draw_rect(Rect2(r.position.x, r.position.y, SWATCH_W, r.size.y), Tk.label_colour(t.colour), true)
	if t.locked:
		ci.draw_rect(r, Color(0.0, 0.0, 0.0, 0.25), true)
	var ic: float = float(Tk.px(ICON))
	var tall: bool = is_tall(r.size.y)
	var icon_y: float = r.position.y + 5.0 if tall else r.position.y + (r.size.y - ic) * 0.5
	Icons.draw(ci, header_icon(t), Rect2(r.position.x + 7.0, icon_y, ic, ic), Tk.c["accent"] if t.subtitle else Tk.c["text_dim"])
	var btns: Array[Dictionary] = buttons(t, r, in_band)
	if not rename_open:
		var nr: Rect2 = name_rect(r, in_band)
		var col: Color = Tk.c["text_bright"] if focused else Tk.c["text"]
		if t.muted:
			col = Tk.c["text_dim"]
		var shown: String = t.shown_label()
		if t.subtitle and not t.speaker.is_empty():
			shown = shown + "  " + t.speaker
		PmText.draw_in(ci, font, Rect2(nr.position.x, nr.position.y, name_right(nr, r, btns) - nr.position.x, nr.size.y), shown, fs, col, HORIZONTAL_ALIGNMENT_LEFT, nr.position.y + font.get_ascent(fs) + 1.0, PmText.ELIDE, r)
	for b: Dictionary in btns:
		var br: Rect2 = b["rect"]
		var on: bool = bool(b["on"])
		var tint: Color = Tk.c["text"] if on else Tk.c["text_faint"]
		if String(b["id"]) == "pin":
			tint = Tk.c["text_bright"] if on else Tk.c["text_faint"]
		if String(b["id"]) == "target" and on:
			tint = Tk.c["text_bright"]
		if String(b["id"]) == "view" and on:
			tint = Tk.c["accent"]
		if b.has("chip") or b.has("badge"):
			Locks.draw_chip(ci, b, tint)
		elif b.has("text"):
			PmText.draw(ci, font, br, String(b["text"]), mini(fs, Tk.fs(Tk.sz("font_small"))), tint, HORIZONTAL_ALIGNMENT_CENTER, 0.0, NAN, PmText.WHOLE)
		else:
			Icons.draw(ci, String(b["icon"]), br, tint)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), Tk.c["border"], true)
	ci.draw_rect(Rect2(r.end.x - 1.0, r.position.y, 1.0, r.size.y), Tk.c["border"], true)


static func name_right(nr: Rect2, r: Rect2, btns: Array[Dictionary]) -> float:
	var right: float = minf(nr.end.x, r.end.x - PmText.pad())
	for b: Dictionary in btns:
		var br: Rect2 = b["rect"]
		if br.position.x >= nr.position.x and br.position.y < nr.end.y and br.end.y > nr.position.y:
			right = minf(right, br.position.x - float(Tk.px(Tk.sz("gap"))))
	return right


static func meter_rect(r: Rect2) -> Rect2:
	return Rect2(r.end.x - METER_W - 3.0, r.position.y + 3.0, METER_W, r.size.y - 6.0)


static func draw_meter(ci: CanvasItem, r: Rect2, level: float) -> void:
	var mr: Rect2 = meter_rect(r)
	ci.draw_rect(mr, Tk.c["bg_field"], true)
	var h: float = clampf(level, 0.0, 1.0) * mr.size.y
	if h > 0.5:
		ci.draw_rect(Rect2(mr.position.x, mr.end.y - h, mr.size.x, h), Tk.c["text"], true)


static func menu_items(t: Track, in_band: bool) -> Array:
	var items: Array = []
	items.append(PmMenu.item("rename", "Rename track", "double click"))
	items.append(PmMenu.check_item("target", "Targeted", t.targeted))
	items.append(PmMenu.check_item("sync", "Sync lock", t.sync_lock))
	items.append(PmMenu.check_item("mute", mute_label(t), t.muted))
	if t.kind == "audio" or t.free:
		items.append(PmMenu.check_item("solo", "Solo", t.solo))
	items.append(Locks.menu_item(t))
	items.append(PmMenu.check_item("pin", "Pinned", t.pinned, Cmd.keys_text("seq.pin_track")))
	items.append(PmMenu.separator())
	if t.kind == "video":
		var sub_items: Array = [PmMenu.check_item("subtitle", "Subtitle lane", t.subtitle), PmMenu.item("speaker", "Speaker name" + ("  " + t.speaker if not t.speaker.is_empty() else "")), PmMenu.item("push_up", "Push up amount  " + str(int(t.push_up)) + " px"), PmMenu.check_item("push_back", "Push back down when the other line ends", t.push_back)]
		items.append(PmMenu.sub_item("subtitles", "Subtitles", sub_items))
		items.append(PmMenu.separator())
	var sub: Array = [PmMenu.check_item("colour:-1", "None", t.colour < 0)]
	for i: int in Tk.LABEL_NAMES.size():
		sub.append(PmMenu.check_item("colour:" + str(i), Tk.label_name(i), t.colour == i))
	items.append(PmMenu.sub_item("colour", "Colour", sub))
	items.append(PmMenu.item("reset_height", "Reset height"))
	items.append(PmMenu.item("reset_all_heights", "Reset every track height"))
	items.append(PmMenu.item("all_this_height", "Make every track this height" if t.free else "Make every " + t.kind + " track this height"))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("hide", "Hide track"))
	items.append(PmMenu.item("select_all_on_track", "Select every clip on this track"))
	items.append(PmMenu.item("add_track", "Add track" if t.free else "Add " + t.kind + " track"))
	items.append(PmMenu.item("remove_track", "Remove track", "", "trash"))
	if in_band:
		items.append(PmMenu.separator())
		items.append(PmMenu.item("band_top", "Send the pinned band to the top"))
	items.append(PmMenu.separator())
	items.append(PmMenu.check_item(FREE_ITEM, "Free tracks", t.free, Cmd.keys_text(FREE_CMD)))
	return items


static func mute_label(t: Track) -> String:
	if t.free:
		return "Hidden and muted"
	return "Hidden" if t.kind == "video" else "Muted"


static func mute_tip(t: Track) -> String:
	if t.free:
		return "Hide and mute track"
	return "Hide track" if t.kind == "video" else "Mute track"


static func header_icon(t: Track) -> String:
	if t.subtitle:
		return "type"
	if t.free:
		return FREE_ICON
	return "film" if t.kind == "video" else "audio"

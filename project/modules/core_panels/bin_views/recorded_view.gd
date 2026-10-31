extends "res://modules/core_panels/bin_views/bin_view.gd"

const CaptureTime := preload("res://modules/core_panels/bin_views/capture_time.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const BAR_H := 34.0
const LANE_GAP := 4.0
const DAY_H := 26.0
const SESSION_H := 22.0
const TICK_H := 16.0
const MIN_BAR := 34.0
const TILE := Vector2(96.0, 44.0)
const CHIP := Vector2(150.0, 28.0)
const TICK_SPACING := 80.0
const TICK_STEPS: Array[float] = [60.0, 120.0, 300.0, 600.0, 900.0, 1800.0, 3600.0, 7200.0, 10800.0, 21600.0]

var heads: Array[Dictionary] = []
var axes: Array[Dictionary] = []
var records: Dictionary = {}
var summary: String = ""


func id() -> String:
	return "recorded"


func title() -> String:
	return "When recorded"


func glyph() -> String:
	return "recorded"


func gap() -> float:
	return float(state("recorded", "gap", CaptureTime.DEFAULT_GAP))


func layout(width: float, _height: float) -> Vector2:
	var list: Array[Dictionary] = entries()
	var rs: Array[Rect2] = rects()
	rs.resize(list.size())
	heads.clear()
	axes.clear()
	records.clear()
	var pad: float = px(6.0)
	var inner_w: float = maxf(width - pad * 2.0, px(120.0))
	var y: float = pad
	var folders: Array[int] = []
	var timed: Array[Dictionary] = []
	var untimed: Array[int] = []
	for i: int in list.size():
		var e: Dictionary = list[i]
		if String(e["kind"]) == "folder":
			folders.append(i)
			continue
		var item: MediaItem = item_of(i)
		var rec: Dictionary = panel.call("recorded_for", item)
		records[String(e["id"])] = rec
		if float(rec.get("start", -1.0)) >= 0.0:
			timed.append({"i": i, "id": String(e["id"]), "start": float(rec["start"]), "end": float(rec["end"])})
		else:
			untimed.append(i)
	if not folders.is_empty():
		var cw: float = px(CHIP.x)
		var ch: float = px(CHIP.y)
		var cols: int = maxi(1, int(floor((inner_w + px(4.0)) / (cw + px(4.0)))))
		for n: int in folders.size():
			rs[folders[n]] = Rect2(pad + float(n % cols) * (cw + px(4.0)), y + float(n / cols) * (ch + px(4.0)), cw, ch)
		y += float((folders.size() + cols - 1) / cols) * (ch + px(4.0)) + px(6.0)
	var sessions: Array[Dictionary] = CaptureTime.sessions(timed, gap())
	var day: int = -999999
	var day_head: Dictionary = {}
	var days: int = 0
	var short: bool = width < px(560.0)
	for s: Dictionary in sessions:
		var sd: int = CaptureTime.day_of(float(s["start"]))
		if sd != day:
			day = sd
			days += 1
			day_head = {"kind": "day", "y": y, "text": CaptureTime.day_text(float(s["start"]), short), "sessions": 0}
			heads.append(day_head)
			y += px(DAY_H)
		day_head["sessions"] = int(day_head["sessions"]) + 1
		var items: Array[Dictionary] = s["items"]
		var count_word: String = str(items.size()) + (" recording" if items.size() == 1 else " recordings")
		var text: String = CaptureTime.clock(float(s["start"])) + " to " + CaptureTime.clock(float(s["end"])) + " · " + count_word
		if not short:
			text += " · " + CaptureTime.span_text(float(s["recorded"])) + " recorded"
		heads.append({"kind": "session", "y": y, "text": text})
		y += px(SESSION_H)
		var t0: float = float(s["start"])
		var span: float = maxf(float(s["end"]) - t0, 1.0)
		var scale: float = inner_w / span
		var lane_ends: Array[float] = []
		var bh: float = px(BAR_H)
		var lg: float = px(LANE_GAP)
		for it: Dictionary in items:
			var x: float = pad + (float(it["start"]) - t0) * scale
			var w: float = maxf((float(it["end"]) - float(it["start"])) * scale, px(MIN_BAR))
			if x + w > pad + inner_w:
				x = maxf(pad, pad + inner_w - w)
			var lane: int = -1
			for l: int in lane_ends.size():
				if lane_ends[l] + px(4.0) <= x:
					lane = l
					break
			if lane < 0:
				lane = lane_ends.size()
				lane_ends.append(0.0)
			lane_ends[lane] = x + w
			rs[int(it["i"])] = Rect2(x, y + float(lane) * (bh + lg), w, bh)
		var lanes_h: float = float(maxi(lane_ends.size(), 1)) * (bh + lg)
		y += lanes_h
		axes.append({"y": y, "t0": t0, "t1": float(s["end"]), "x0": pad, "w": inner_w})
		y += px(TICK_H) + px(8.0)
	if not untimed.is_empty():
		heads.append({"kind": "day", "y": y, "text": "No recorded time", "sessions": -untimed.size()})
		y += px(DAY_H) + px(4.0)
		var tw: float = px(TILE.x)
		var th: float = px(TILE.y)
		var tcols: int = maxi(1, int(floor((inner_w + px(4.0)) / (tw + px(4.0)))))
		for n2: int in untimed.size():
			rs[untimed[n2]] = Rect2(pad + float(n2 % tcols) * (tw + px(4.0)), y + float(n2 / tcols) * (th + px(4.0)), tw, th)
		y += float((untimed.size() + tcols - 1) / tcols) * (th + px(4.0))
	var rec_count: int = timed.size()
	summary = str(days) + (" day" if days == 1 else " days") + " · " + str(sessions.size()) + (" session" if sessions.size() == 1 else " sessions") + " · " + str(rec_count) + (" recording" if rec_count == 1 else " recordings")
	set_meta_text(summary if rec_count > 0 else "")
	return Vector2(width, y + pad)


func name_rect(i: int) -> Rect2:
	var r: Rect2 = screen_rect(i)
	return Rect2(r.position.x, r.position.y, maxf(r.size.x, px(160.0)), minf(r.size.y, px(24.0)))


func tip_for(i: int) -> String:
	var e: Dictionary = entry(i)
	var label: String = String(e.get("label", ""))
	var rec: Dictionary = records.get(String(e.get("id", "")), {})
	if float(rec.get("start", -1.0)) < 0.0:
		return label
	var src: String = String(rec.get("source", ""))
	var from: String = "time recorded in the file" if src == "own" else ("time from the file name" if src == "name" else "time from the file date")
	var s: float = float(rec["start"])
	var en: float = float(rec["end"])
	if en > s:
		return label + "  " + CaptureTime.clock(s, true) + " to " + CaptureTime.clock(en, true) + ", " + from
	return label + "  " + CaptureTime.clock(s, true) + ", " + from


func draw() -> void:
	var vis: Rect2 = visible_rect()
	var sp: Vector2 = scroll_pos()
	var f: Font = font()
	var fb: Font = Tk.font("body_semibold")
	var m: Font = mono()
	var fsb: int = fs_body()
	var fss: int = fs_small()
	var fsm: int = fs_meta()
	var pad: float = px(6.0)
	for h: Dictionary in heads:
		var hy: float = float(h["y"]) - sp.y
		if hy > vis.end.y or hy < -px(DAY_H):
			continue
		if String(h["kind"]) == "day":
			var dh: float = px(DAY_H)
			body.draw_rect(Rect2(pad, hy + dh - 1.0, body.size.x - pad * 2.0, 1.0), Tk.c["border"], true)
			var n: int = int(h["sessions"])
			var meta: String = (str(n) + (" session" if n == 1 else " sessions")) if n > 0 else (str(-n) + (" item" if n == -1 else " items"))
			var mw: float = PmText.width_of(m, meta.to_upper(), fsm)
			var row: Rect2 = Rect2(0.0, hy, body.size.x, dh)
			PmText.draw_in(body, m, Rect2(body.size.x - pad - px(2.0) - mw, hy, mw, dh), meta.to_upper(), fsm, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, NAN, PmText.WHOLE, row)
			text_at(Vector2(pad + px(2.0), hy), dh, String(h["text"]), body.size.x - pad * 2.0 - mw - px(14.0), fsb, Tk.c["text_bright"], fb, row)
		else:
			text_at(Vector2(pad + px(2.0), hy), px(SESSION_H), String(h["text"]), body.size.x - pad * 2.0 - px(4.0), fss, Tk.c["text_dim"], null, Rect2(0.0, hy, body.size.x, px(SESSION_H)))
	for a: Dictionary in axes:
		var ay: float = float(a["y"]) - sp.y
		if ay > vis.end.y or ay < -px(TICK_H):
			continue
		_draw_ticks(a, ay, m, fsm)
	var list: Array[Dictionary] = entries()
	for i: int in list.size():
		var r: Rect2 = screen_rect(i)
		if not r.intersects(vis):
			continue
		_draw_entry(i, r, f, fss)


func _draw_ticks(a: Dictionary, ay: float, m: Font, fsm: int) -> void:
	var x0: float = float(a["x0"])
	var w: float = float(a["w"])
	var t0: float = float(a["t0"])
	var t1: float = maxf(float(a["t1"]), t0 + 1.0)
	body.draw_rect(Rect2(x0, ay + 1.0, w, 1.0), Tk.c["lane_line"], true)
	var per_px: float = (t1 - t0) / maxf(w, 1.0)
	var step: float = TICK_STEPS[TICK_STEPS.size() - 1]
	for s: float in TICK_STEPS:
		if s / per_px >= px(TICK_SPACING):
			step = s
			break
	var first: float = ceil(t0 / step) * step
	var labels: Array[float] = [t0]
	var t: float = first
	while t < t1:
		if (t - t0) / per_px >= px(TICK_SPACING) * 0.75:
			labels.append(t)
		t += step
	for lt: float in labels:
		var lx: float = x0 + (lt - t0) / per_px
		var text: String = CaptureTime.clock(lt)
		var tw: float = PmText.width_of(m, text, fsm)
		var tx: float = clampf(lx - (0.0 if lt == t0 else tw * 0.5), x0, x0 + w - tw)
		body.draw_rect(Rect2(lx, ay + 1.0, 1.0, px(3.0)), Tk.c["text_faint"], true)
		PmText.draw_in(body, m, Rect2(tx, ay + px(3.0), tw, m.get_height(fsm)), text, fsm, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, ay + px(3.0) + m.get_ascent(fsm), PmText.WHOLE, Rect2(0.0, ay + px(3.0), body.size.x, m.get_height(fsm)))


func _draw_entry(i: int, r: Rect2, f: Font, fss: int) -> void:
	var e: Dictionary = entry(i)
	var item: MediaItem = item_of(i)
	var radius: float = px(Tk.sz("radius_chip"))
	var selected: bool = is_selected(i)
	var name_col: Color = Tk.c["text_bright"] if selected else Tk.c["text"]
	if String(e["kind"]) == "folder":
		Paint.rounded(body, r, Tk.c["bg_panel_alt"], radius, Tk.c["border_soft"], 1)
		var ic: float = px(14.0)
		IconsKit.draw(body, "folder", Rect2(r.position.x + px(6.0), r.position.y + (r.size.y - ic) * 0.5, ic, ic), Tk.c["text_dim"])
		text_at(Vector2(r.position.x + px(6.0) + ic + px(6.0), r.position.y), r.size.y, String(e.get("label", "")), r.size.x - ic - px(20.0), fss, name_col, null, r)
		draw_outline(r, i, radius)
		return
	var rec: Dictionary = records.get(String(e["id"]), {})
	var timed: bool = float(rec.get("start", -1.0)) >= 0.0
	Paint.rounded(body, r, Tk.c["bg_panel_alt"], radius, Tk.c["border_soft"], 1)
	if timed:
		var th_w: float = minf(r.size.x - 2.0, px(44.0))
		var pic: Rect2 = Rect2(r.position + Vector2(1.0, 1.0), Vector2(th_w, r.size.y - 2.0))
		_draw_thumb(pic, item)
		var left: float = pic.end.x + px(6.0)
		var avail: float = r.end.x - left - px(6.0)
		if avail >= px(24.0):
			text_at(Vector2(left, r.position.y), r.size.y, String(e.get("label", "")), avail, fss, name_col, null, r)
	else:
		var nh: float = px(16.0)
		var pic2: Rect2 = Rect2(r.position + Vector2(1.0, 1.0), Vector2(r.size.x - 2.0, r.size.y - nh - 2.0))
		_draw_thumb(pic2, item)
		caption(r, r.end.y - nh, nh, String(e.get("label", "")), fss, name_col)
	draw_label_stripe(r, item)
	draw_outline(r, i, radius)


func _draw_thumb(pic: Rect2, item: MediaItem) -> void:
	if item == null or pic.size.x < 4.0 or pic.size.y < 4.0:
		return
	if item.has_picture() and (item.kind == "video" or item.kind == "image"):
		var tex: Texture2D = panel.call("thumb_for", item, -1.0)
		if tex != null:
			draw_texture_in(tex, pic, true)
			return
	var side: float = minf(pic.size.x, pic.size.y) * 0.5
	IconsKit.draw(body, String(panel.call("kind_icon", item.kind)), Rect2(pic.position + (pic.size - Vector2(side, side)) * 0.5, Vector2(side, side)), Tk.c["text_faint"])


func build_bar(bar: Container) -> void:
	var choices: Array = []
	for n: int in CaptureTime.GAPS.size():
		choices.append(PmDrop.choice(str(int(CaptureTime.GAPS[n])), "New session after " + CaptureTime.GAP_LABELS[n]))
	var drop: Button = PmDrop.make_drop(choices, str(int(CaptureTime.GAPS[CaptureTime.gap_index(gap())])))
	PmUI.tip(drop, "A new session starts when nothing was recorded for longer than this")
	drop.connect("changed", _on_gap)
	drop.set_meta("recorded_gap", true)
	fit_drop(drop)
	bar_add(bar, drop, "Session gap")


func _on_gap(value: String) -> void:
	set_state("recorded", "gap", float(value))
	relayout()

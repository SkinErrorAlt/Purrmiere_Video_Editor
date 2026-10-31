extends Control

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Tools := preload("res://doc/commands/edit_tools.gd")
const CutLinks := preload("res://doc/cut_links.gd")
const Timecode := preload("res://doc/timecode.gd")
const Hit := preload("res://ui/timeline/timeline_hit.gd")
const Drag := preload("res://ui/timeline/timeline_drag.gd")
const Groups := preload("res://ui/timeline/timeline_groups.gd")
const Censor := preload("res://ui/timeline/timeline_censor.gd")
const Paint := preload("res://ui/timeline/timeline_paint.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const SELF_PATH := "res://ui/timeline/timeline_razor.gd"
const TOOL_ID := "razor"
const NODE_NAME := "RazorPreview"
const NOTCH := 4.0
const STUB_H := 6.0
const PILL_GAP := 7.0
const HEAD_REACH := 7.0
const MARK := 4.0
const HEAD_H := 9.0
const ALL_TRACKS_TEXT := "all tracks"
const LANE_ONLY_TEXT := "lane only"

static var plans_made: int = 0
static var paints: int = 0
static var wakes: int = 0
static var last_plan_usec: int = 0
static var last_draw_usec: int = 0

var canvas: Control = null
var mods_source: Callable = Callable()
var shown: Dictionary = {}
var plan: Dictionary = {}
var _key: Array = []


static func empty_plan() -> Dictionary:
	return {"ok": false, "t": 0.0, "raw": 0.0, "snapped": false, "all": false, "lane_only": false, "clip_id": "", "ids": PackedStringArray(), "select": PackedStringArray()}


static func live_mods() -> Dictionary:
	return {"shift": Input.is_key_pressed(KEY_SHIFT), "ctrl": Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META), "alt": Input.is_key_pressed(KEY_ALT)}


static func cut_time(cv: Control, h: Dictionary) -> Dictionary:
	var raw: float = maxf(float(h.get("t", 0.0)), 0.0)
	if bool(cv.get("snapping")):
		var targets: PackedFloat64Array = cv.call("snap_targets", PackedStringArray())
		var reach: float = Drag.SNAP_PX / maxf(float(cv.get("pps")), 0.000001)
		var lo: int = 0
		var hi: int = targets.size()
		while lo < hi:
			var mid: int = (lo + hi) >> 1
			if targets[mid] < raw:
				lo = mid + 1
			else:
				hi = mid
		var best: float = raw
		var best_d: float = reach
		var found: bool = false
		for i: int in [lo - 1, lo]:
			if i < 0 or i >= targets.size():
				continue
			var dist: float = absf(targets[i] - raw)
			if dist < best_d:
				best_d = dist
				best = targets[i]
				found = true
		if found:
			return {"t": best, "raw": raw, "snapped": true}
	var fps: float = float(cv.call("fps"))
	return {"t": maxf(round(raw * fps) / fps, 0.0), "raw": raw, "snapped": false}


static func plan_for_hit(cv: Control, h: Dictionary, mods: Dictionary) -> Dictionary:
	var out: Dictionary = empty_plan()
	var d: Project = cv.call("doc")
	var s: Sequence = cv.call("seq")
	if d == null or s == null or String(h.get("zone", "")) != "lane" or bool(h.get("nest", false)):
		return out
	var time: Dictionary = cut_time(cv, h)
	var t: float = float(time["t"])
	out["t"] = t
	out["raw"] = float(time["raw"])
	out["snapped"] = bool(time["snapped"])
	var all: bool = bool(mods.get("shift", false))
	var c: Clip = h.get("clip", null)
	if not all and c == null:
		return out
	out["all"] = all
	out["lane_only"] = not all and bool(mods.get("ctrl", false))
	out["clip_id"] = c.id if c != null else ""
	var targets: Dictionary = CutLinks.razor_targets(Tools, s, String(out["clip_id"]), t, bool(out["lane_only"]), all, bool(cv.get("linked_selection")))
	out["ids"] = targets["ids"]
	out["select"] = targets["select"]
	out["ok"] = not (targets["ids"] as PackedStringArray).is_empty()
	return out


static func claimed(cv: Control, pos: Vector2) -> bool:
	if not Groups.tag_at(cv, pos).is_empty():
		return true
	if not Censor.any_regions(cv):
		return false
	var hr: Dictionary = Censor.hit(cv, pos)
	return not hr.is_empty() and (not String(hr.get("edge", "")).is_empty() or bool(hr.get("tag", false)))


static func preview_plan(cv: Control, pos: Vector2, mods: Dictionary) -> Dictionary:
	var h: Dictionary = cv.call("hit_at", pos)
	if String(h.get("zone", "")) != "lane" or claimed(cv, pos):
		return empty_plan()
	return plan_for_hit(cv, h, mods)


static func click(cv: Control, h: Dictionary, mods: Dictionary) -> bool:
	var p: Dictionary = plan_for_hit(cv, h, mods)
	return Tools.razor_apply(cv.call("doc"), cv.call("seq"), p, float(p["t"]))


static func cursor(cv: Control) -> Control.CursorShape:
	attach(cv)
	return Control.CURSOR_IBEAM


static func attach(cv: Control) -> Control:
	var node: Control = cv.get_node_or_null(NODE_NAME)
	if node == null:
		var script: GDScript = load(SELF_PATH)
		node = script.new()
		node.set("canvas", cv)
		cv.add_child(node)
	node.call("wake")
	return node


static func of(cv: Control) -> Control:
	return cv.get_node_or_null(NODE_NAME) if cv != null else null


static func readout(s: Sequence, fps: float, p: Dictionary) -> String:
	var text: String = Timecode.format(float(p["t"]), fps, s != null and s.drop_frame)
	if bool(p.get("all", false)):
		return text + "  " + ALL_TRACKS_TEXT
	if bool(p.get("lane_only", false)):
		return text + "  " + LANE_ONLY_TEXT
	return text


static func widths() -> Vector2:
	var half: float = maxf(float(Tk.px(1.0)), 1.0)
	return Vector2(half * 2.0, half)


static func layout(cv: Control, p: Dictionary) -> Dictionary:
	if not bool(p.get("ok", false)):
		return {}
	var s: Sequence = cv.call("seq")
	var g: Dictionary = cv.call("geometry")
	var ln: Dictionary = cv.call("lanes")
	var header_w: float = float(g["header_w"])
	var width: float = float(g["width"])
	var rh: float = float(g["ruler_h"])
	var bottom: float = (g["hscroll_rect"] as Rect2).position.y
	var x: float = round(float(cv.call("x_of", float(p["t"]))))
	var w: Vector2 = widths()
	var reach: float = w.x * 0.5 + w.y + float(Tk.px(NOTCH)) + 1.0
	if x < header_w or x > width:
		return {}
	var cut_tracks: Dictionary = {}
	for id: String in (p["ids"] as PackedStringArray):
		var tr: Track = s.track_of(id)
		if tr != null:
			cut_tracks[tr.id] = true
	var segs: Array[Dictionary] = []
	for set_name: String in ["main", "band"]:
		var region: Rect2 = g["main_rect"] if set_name == "main" else g["band_rect"]
		if region.size.y <= 0.0:
			continue
		for l: Dictionary in ln[set_name]:
			if bool(l["nest"]):
				continue
			var tr2: Track = l["track"]
			if not cut_tracks.has(tr2.id):
				continue
			var y: float = Hit.lane_screen_y(g, l)
			var top: float = y + 1.0
			var end: float = y + float(l["h"]) - 1.0
			var y0: float = maxf(top, region.position.y)
			var y1: float = minf(end, region.end.y)
			if y1 - y0 < 1.0:
				continue
			segs.append({"y0": y0, "y1": y1, "top": is_equal_approx(y0, top), "bottom": is_equal_approx(y1, end)})
	var font: Font = Tk.font("mono")
	var fs: int = Tk.fs(Tk.sz("font_meta"))
	var text: String = readout(s, float(cv.call("fps")), p)
	var pad: float = PmText.chip_pad()
	var ph: float = minf(ceil(font.get_height(fs)) + 2.0, rh - 4.0)
	var pw: float = ceil(PmText.width_of(font, text, fs)) + pad * 2.0
	var gap: float = float(Tk.px(PILL_GAP))
	var pill: Rect2 = Rect2(x + gap, maxf(floor((rh - ph) * 0.5) - 1.0, 1.0), pw, ph)
	var head_x: float = round(float(cv.call("x_of", float(cv.call("playhead")))))
	var head: Vector2 = Vector2(head_x - float(Tk.px(HEAD_REACH)), head_x + float(Tk.px(HEAD_REACH)))
	var right_ok: bool = pill.end.x <= width - 2.0 and not (pill.position.x < head.y and pill.end.x > head.x)
	if not right_ok:
		var left: Rect2 = Rect2(x - gap - pw, pill.position.y, pw, ph)
		if left.position.x >= header_w + 2.0:
			pill = left
	if not bool(Tools.pref(Tools.PREF_RAZOR_TIME, true)):
		pill = Rect2(x, 0.0, 0.0, 0.0)
	var x0: float = minf(x - reach, pill.position.x) - 1.0
	var x1: float = maxf(x + reach, pill.end.x) + 1.0
	return {"x": x, "rh": rh, "bottom": bottom, "segs": segs, "snapped": bool(p["snapped"]), "text": text, "pill": pill, "font": font, "fs": fs, "bounds": Rect2(x0, 0.0, x1 - x0, bottom)}


func _init() -> void:
	name = NODE_NAME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	set_process(false)


func wake() -> void:
	if not is_processing():
		wakes += 1
		_key = []
		set_process(true)


func sleep() -> void:
	set_process(false)
	_key = []
	if visible or not shown.is_empty():
		shown = {}
		plan = {}
		visible = false


func active() -> bool:
	if canvas == null or not is_instance_valid(canvas) or not canvas.is_visible_in_tree():
		return false
	if Session.tool_id != TOOL_ID:
		return false
	var hov: Dictionary = canvas.get("hover")
	if hov.is_empty() or String(hov.get("zone", "")) != "lane":
		return false
	var dr: RefCounted = canvas.get("drag")
	return dr == null or not bool(dr.call("in_progress"))


func mods() -> Dictionary:
	if mods_source.is_valid():
		return mods_source.call()
	return live_mods()


func _process(_dt: float) -> void:
	if not active():
		sleep()
		return
	var key: Array = _key_now()
	if key == _key:
		return
	_key = key
	refresh()


func _key_now() -> Array:
	var hov: Dictionary = canvas.get("hover")
	var m: Dictionary = mods()
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	return [float(hov.get("x", 0.0)), float(hov.get("y", 0.0)), bool(m.get("shift", false)), bool(m.get("ctrl", false)), d.serial if d != null else -1, s.id if s != null else "", s.playhead if s != null else 0.0, s.selected_clip_ids if s != null else PackedStringArray(), canvas.get("scroll_x"), canvas.get("scroll_y"), canvas.get("band_scroll_y"), canvas.get("pps"), canvas.get("header_w"), canvas.size, canvas.get("snapping"), canvas.get("linked_selection"), Tk.ui_scale, Tk.theme_id]


func refresh() -> void:
	var t0: int = Time.get_ticks_usec()
	var hov: Dictionary = canvas.get("hover")
	plan = preview_plan(canvas, Vector2(float(hov.get("x", 0.0)), float(hov.get("y", 0.0))), mods())
	plans_made += 1
	var next: Dictionary = layout(canvas, plan)
	last_plan_usec = Time.get_ticks_usec() - t0
	if next.is_empty():
		if visible:
			visible = false
		shown = {}
		return
	shown = next
	var b: Rect2 = shown["bounds"]
	position = b.position
	size = b.size
	visible = true
	queue_redraw()


func _draw() -> void:
	if shown.is_empty():
		return
	var t0: int = Time.get_ticks_usec()
	paints += 1
	var o: float = position.x
	var x: float = float(shown["x"]) - o
	var rh: float = float(shown["rh"])
	var w: Vector2 = widths()
	var sol: Color = Tk.c["sol"]
	var inv: Color = Tk.c["inv"]
	if bool(shown["snapped"]):
		draw_rect(Rect2(x, rh, 1.0, float(shown["bottom"]) - rh), Tk.c["accent_dim"], true)
	var n: float = float(Tk.px(NOTCH))
	for seg: Dictionary in (shown["segs"] as Array):
		var y0: float = float(seg["y0"])
		var y1: float = float(seg["y1"])
		_line(x, y0, y1, w, sol, inv)
		if y1 - y0 >= n * 3.0:
			if bool(seg["top"]):
				_notch(x, y0, n, w.y, 1.0, sol, inv)
			if bool(seg["bottom"]):
				_notch(x, y1, n, w.y, -1.0, sol, inv)
	if bool(shown["snapped"]):
		_line(x, 0.0, rh, w, sol, inv)
		var m: float = float(Tk.px(MARK))
		var c: Vector2 = Vector2(x, minf(float(Tk.px(HEAD_H)) + m + w.y + 1.0, rh - m - w.y - 1.0))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -m - w.y), c + Vector2(m + w.y, 0.0), c + Vector2(0.0, m + w.y), c + Vector2(-m - w.y, 0.0)]), inv)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -m), c + Vector2(m, 0.0), c + Vector2(0.0, m), c + Vector2(-m, 0.0)]), sol)
	else:
		var stub: float = float(Tk.px(STUB_H))
		_line(x, rh - stub, rh, w, sol, inv)
	var pill: Rect2 = shown["pill"]
	pill.position.x -= o
	if pill.has_area():
		_draw_pill(pill)
	last_draw_usec = Time.get_ticks_usec() - t0


func _draw_pill(pill: Rect2) -> void:
	Paint.rounded(self, pill, Tk.c["bg_panel_alt"], float(Tk.px(Tk.sz("radius_chip"))), Tk.c["border_soft"], 1)
	var font: Font = shown["font"]
	var fs: int = int(shown["fs"])
	var text: String = String(shown["text"])
	var split: int = text.find("  ")
	var main_text: String = text if split < 0 else text.substr(0, split)
	var base: float = PmText.baseline_in(font, fs, pill)
	var drawn: Rect2 = PmText.draw(self, font, pill, main_text, fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, PmText.chip_pad(), base, PmText.WHOLE)
	if split >= 0 and drawn.has_area():
		var rest: Rect2 = Rect2(drawn.end.x, pill.position.y, pill.end.x - drawn.end.x, pill.size.y)
		PmText.draw_in(self, font, rest, text.substr(split), fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, base, PmText.WHOLE, pill, PmText.chip_pad())


func _line(x: float, y0: float, y1: float, w: Vector2, sol: Color, inv: Color) -> void:
	var half: float = w.x * 0.5
	draw_rect(Rect2(x - half - w.y, y0, w.x + w.y * 2.0, y1 - y0), inv, true)
	draw_rect(Rect2(x - half, y0, w.x, y1 - y0), sol, true)


func _notch(x: float, y: float, n: float, edge: float, dir: float, sol: Color, inv: Color) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(x - n - edge, y), Vector2(x + n + edge, y), Vector2(x, y + dir * (n + edge * 1.5))]), inv)
	draw_colored_polygon(PackedVector2Array([Vector2(x - n, y), Vector2(x + n, y), Vector2(x, y + dir * n)]), sol)


func fit_texts() -> Array:
	return PmText.report(self)

extends RefCounted
## The timeline minimap (C-032): the bottom scroll strip grows into a picture of the whole sequence. Each track is a
## thin row with its clips in their colours, markers are ticks, the in and out are shaded, the playhead is a line,
## (drawn on the overlay so it moves without a repaint) and the part on screen is the window you drag. Click outside the window to jump there.
## Drawing walks the clips once per paint; with the pref off the strip is the plain scroll bar again.

const Paint := preload("res://ui/timeline/timeline_paint.gd")
const Fold := preload("res://ui/timeline/timeline_fold.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Marker := preload("res://doc/marker.gd")
const PREF := "timeline.minimap"
const HEIGHT := 26.0
const ROW_MAX := 4.0
const PAD := 2.0
const MIN_CLIP_PX := 1.0


static func register_prefs() -> void:
	if not Prefs.is_registered(PREF):
		Prefs.register(PREF, true, {"label": "Timeline minimap in the scroll strip (the whole sequence at a glance)", "type": "bool"})


static func on() -> bool:
	return Prefs.is_registered(PREF) and bool(Prefs.get_value(PREF))


## Height of the bottom strip: the minimap when it is on, else the slim scroll bar.
static func strip_h(plain: float) -> float:
	return float(Tk.px(HEIGHT)) if on() else plain


## The strip's mapping: x for a time and the inverse, matching the scroll thumb exactly.
static func content_of(canvas: Object, g: Dictionary) -> float:
	return Fold.shown(g["fold"], float(canvas.call("duration"))) * float(g["pps"]) + float(canvas.call("view_w")) * 0.5


static func x_of(canvas: Object, g: Dictionary, r: Rect2, t: float) -> float:
	var content: float = maxf(content_of(canvas, g), 1.0)
	return r.position.x + PAD + (r.size.x - PAD * 2.0) * Fold.shown(g["fold"], t) * float(g["pps"]) / content


static func scroll_for(canvas: Object, g: Dictionary, r: Rect2, x: float) -> float:
	var content: float = maxf(content_of(canvas, g), 1.0)
	var at: float = (x - r.position.x - PAD) / maxf(r.size.x - PAD * 2.0, 1.0) * content
	return maxf(at - float(canvas.call("view_w")) * 0.5, 0.0)


## The window on screen, in strip pixels.
static func window_rect(canvas: Object, g: Dictionary, r: Rect2) -> Rect2:
	var content: float = maxf(content_of(canvas, g), 1.0)
	var track: float = r.size.x - PAD * 2.0
	var w: float = clampf(track * float(canvas.call("view_w")) / content, 6.0, track)
	var x: float = r.position.x + PAD + track * float(g["scroll_x"]) / content
	return Rect2(x, r.position.y + 1.0, w, r.size.y - 2.0)


static func draw(ci: CanvasItem, canvas: Object, g: Dictionary) -> void:
	var r: Rect2 = g["hscroll_rect"]
	ci.draw_rect(r, Tk.c["bg_panel"], true)
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), Tk.c["border"], true)
	var s: Sequence = canvas.call("seq")
	var d: Project = canvas.call("doc")
	if s == null:
		return
	var in_t: float = s.in_point
	var out_t: float = s.out_point
	if in_t >= 0.0 or out_t >= 0.0:
		var a: float = x_of(canvas, g, r, maxf(in_t, 0.0))
		var b: float = x_of(canvas, g, r, out_t if out_t >= 0.0 else float(canvas.call("duration")))
		ci.draw_rect(Rect2(a, r.position.y + 1.0, maxf(b - a, 1.0), r.size.y - 2.0), Color(Tk.c["accent"], 0.10), true)
	var runs: Array = _time_runs(canvas, g, r, s, d)
	var k_px: float = (r.size.x - PAD * 2.0) * float(g["pps"]) / maxf(content_of(canvas, g), 1.0)
	var x_base: float = r.position.x + PAD
	for run: Array in runs:
		var x0: float = floorf(x_base + k_px * float(run[0]))
		var x1: float = maxf(ceilf(x_base + k_px * float(run[1])), x0 + 1.0)
		ci.draw_rect(Rect2(x0, float(run[2]), x1 - x0, float(run[3])), run[4], true)
	var win: Rect2 = window_rect(canvas, g, r)
	ci.draw_rect(win, Color(Tk.c["text_bright"], 0.06), true)
	ci.draw_rect(win, Color(Tk.c["text_bright"], 0.55), false, 1.0)


static var _cache: Dictionary = {}


## The clip rows and marker ticks as runs in time ([t0, t1, row y, height, colour]), neighbouring clips of one colour
## merged when they would touch on the strip, built only when the project, the sequence or the strip's size
## changes. Zooming only rescales them, so a zoom step costs a few hundred rectangles, not a walk over every clip.
static func _time_runs(canvas: Object, g: Dictionary, r: Rect2, s: Sequence, d: Project) -> Array:
	var serial: int = d.serial if d != null else 0
	var dur: float = float(canvas.call("duration"))
	var fold: Dictionary = g["fold"]
	var key: String = "%s|%d|%.1f|%.1f|%.1f|%d" % [s.id, serial, r.size.x, r.size.y, dur, fold.size()]
	var cid: int = canvas.get_instance_id()
	var held: Dictionary = _cache.get(cid, {})
	if String(held.get("key", "")) == key:
		return held["runs"]
	var runs: Array = []
	var tracks: Array[Track] = []
	for t: Track in s.video_tracks:
		tracks.append(t)
	var vcount: int = tracks.size()
	for t2: Track in s.audio_tracks:
		tracks.append(t2)
	var media: Dictionary = {}
	if d != null:
		for m: MediaItem in d.media:
			media[m.id] = m
	var plain: bool = fold.is_empty()
	var tol: float = maxf(Fold.shown(fold, dur) if not plain else dur, 0.001) / maxf(r.size.x - PAD * 2.0, 1.0)
	if not tracks.is_empty():
		var inner_h: float = r.size.y - PAD * 2.0
		var row_h: float = clampf((inner_h - 2.0) / float(tracks.size()), 1.0, float(Tk.px(ROW_MAX)))
		var used: float = row_h * float(tracks.size()) + 2.0
		var y: float = r.position.y + PAD + maxf((inner_h - used) * 0.5, 0.0)
		var bar_h: float = maxf(row_h - (1.0 if row_h >= 3.0 else 0.0), 1.0)
		var order: Array[Track] = []
		for i: int in range(vcount - 1, -1, -1):
			order.append(tracks[i])
		for j: int in range(vcount, tracks.size()):
			order.append(tracks[j])
		var colours: Dictionary = {}
		for k: int in order.size():
			var tr: Track = order[k]
			var ry: float = y + float(k) * row_h + (2.0 if k >= vcount else 0.0)
			var run_t0: float = 0.0
			var run_t1: float = -1.0
			var run_col: Color = Color.TRANSPARENT
			for cl: Clip in tr.clips:
				var st: float = cl.start if plain else Fold.shown(fold, cl.start)
				var en: float = cl.end() if plain else Fold.shown(fold, cl.end())
				var ckey: String = cl.media_id + "|" + str(cl.colour) + "|" + str(cl.enabled) + "|" + str(cl.is_nest())
				var col: Color
				if colours.has(ckey):
					col = colours[ckey]
				else:
					col = Paint.clip_colour(cl, media.get(cl.media_id, null), tr).lightened(0.25)
					if not cl.enabled:
						col = Color(col, 0.35)
					colours[ckey] = col
				if run_t1 >= 0.0 and st <= run_t1 + tol and col == run_col:
					run_t1 = maxf(run_t1, en)
					continue
				if run_t1 >= 0.0:
					runs.append([run_t0, run_t1, ry, bar_h, run_col])
				run_t0 = st
				run_t1 = en
				run_col = col
			if run_t1 >= 0.0:
				runs.append([run_t0, run_t1, ry, bar_h, run_col])
	var ticks: Dictionary = {}
	for mk: Marker in s.markers:
		var mt: float = mk.time if plain else Fold.shown(fold, mk.time)
		ticks[int(floor(mt / tol))] = mt
	for tk: Variant in ticks.keys():
		runs.append([float(ticks[tk]), float(ticks[tk]), r.position.y + 1.0, 3.0, Tk.c["text_dim"]])
	_cache[cid] = {"key": key, "runs": runs}
	if _cache.size() > 16:
		_cache = {cid: _cache[cid]}
	return runs

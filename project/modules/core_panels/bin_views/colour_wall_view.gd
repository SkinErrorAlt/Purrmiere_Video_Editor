extends "res://modules/core_panels/bin_views/bin_view.gd"

const Swatch := preload("res://modules/core_panels/bin_views/swatch.gd")
const TILE_W := 70.0
const TILE_RATIO := 0.69
const SCALE_MIN := 0.6
const SCALE_MAX := 2.4
const BAND_H := 20.0
const SMOOTH := 14.0
const RESORT_MS := 900

var targets: Dictionary = {}
var shown: Dictionary = {}
var index_of_id: Dictionary = {}
var bands: Array[Dictionary] = []
var order_ids: PackedStringArray = PackedStringArray()
var _resort_due: bool = false
var _last_sort_ms: int = 0
var _first: bool = true


func id() -> String:
	return "colours"


func title() -> String:
	return "Colour wall"


func glyph() -> String:
	return "colours"


func mode() -> String:
	return String(state("wall", "mode", "pictures"))


func tile_scale() -> float:
	return clampf(float(state("wall", "scale", 1.0)), SCALE_MIN, SCALE_MAX)


func tile_size() -> Vector2:
	var w: float = px(TILE_W) * tile_scale()
	return Vector2(w, round(w * TILE_RATIO))


func picture_item(item: MediaItem) -> bool:
	return item != null and item.has_picture() and (item.kind == "video" or item.kind == "image")


func colour_time(item: MediaItem) -> float:
	return float(panel.call("colour_time", item))


func layout(width: float, _height: float) -> Vector2:
	var list: Array[Dictionary] = entries()
	var folders: Array[int] = []
	var pictures: Array[Dictionary] = []
	var sound: Array[int] = []
	var reading: Array[int] = []
	for i: int in list.size():
		var e: Dictionary = list[i]
		if String(e["kind"]) == "folder":
			folders.append(i)
			continue
		var item: MediaItem = item_of(i)
		if not picture_item(item):
			sound.append(i)
			continue
		var sw: Dictionary = panel.call("swatch_for", item)
		if sw.is_empty():
			reading.append(i)
		else:
			pictures.append({"i": i, "key": Swatch.sort_key(sw)})
	pictures.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Swatch.less(a["key"] as Vector3, b["key"] as Vector3) or ((a["key"] as Vector3) == (b["key"] as Vector3) and int(a["i"]) < int(b["i"])))
	var ts: Vector2 = tile_size()
	var gap: float = 2.0
	var pad: float = px(6.0)
	var cols: int = maxi(1, int(floor((width - pad * 2.0 + gap) / (ts.x + gap))))
	var rs: Array[Rect2] = rects()
	rs.resize(list.size())
	index_of_id.clear()
	targets.clear()
	bands.clear()
	order_ids = PackedStringArray()
	var y: float = pad
	var runs: Array = [["", folders], ["", _indices(pictures)], ["Sound", sound], ["Reading", reading]]
	for run: Variant in runs:
		var label: String = String((run as Array)[0])
		var idx: Array = (run as Array)[1]
		if idx.is_empty():
			continue
		if not label.is_empty():
			bands.append({"label": label.to_upper(), "y": y})
			y += px(BAND_H)
		var c: int = 0
		for iv: Variant in idx:
			var i: int = int(iv)
			var pos: Vector2 = Vector2(pad + float(c % cols) * (ts.x + gap), y + float(c / cols) * (ts.y + gap))
			var eid: String = String(list[i]["id"])
			targets[eid] = pos
			index_of_id[eid] = i
			order_ids.append(eid)
			c += 1
		y += float((c + cols - 1) / cols) * (ts.y + gap) + px(4.0)
	for eid2: Variant in targets.keys():
		if _first or not shown.has(eid2):
			shown[eid2] = targets[eid2]
	for sid: Variant in shown.keys():
		if not targets.has(sid):
			shown.erase(sid)
	_first = false
	_apply_rects()
	_last_sort_ms = Time.get_ticks_msec()
	_resort_due = false
	_update_meta()
	return Vector2(width, y + pad)


func _indices(list: Array[Dictionary]) -> Array:
	var out: Array = []
	for d: Dictionary in list:
		out.append(int(d["i"]))
	return out


func _apply_rects() -> void:
	var rs: Array[Rect2] = rects()
	var n: int = entries().size()
	if rs.size() != n:
		rs.resize(n)
	var ts: Vector2 = tile_size()
	for eid: Variant in index_of_id.keys():
		rs[int(index_of_id[eid])] = Rect2(shown.get(eid, targets[eid]) as Vector2, ts)


func swatches_changed() -> void:
	_resort_due = true


func tick(dt: float) -> bool:
	if _resort_due and Time.get_ticks_msec() - _last_sort_ms >= RESORT_MS and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		relayout()
	var moving: bool = false
	var f: float = 1.0 - exp(-SMOOTH * dt)
	for eid: Variant in targets.keys():
		var t: Vector2 = targets[eid]
		var s: Vector2 = shown.get(eid, t)
		if s.distance_squared_to(t) > 0.04:
			shown[eid] = s.lerp(t, f)
			moving = true
		elif s != t:
			shown[eid] = t
			moving = true
	if moving:
		_apply_rects()
		redraw()
	return moving or _resort_due


func zoom(steps: float, _at: Vector2) -> bool:
	var cur: float = tile_scale()
	var next: float = clampf(cur * pow(1.12, signf(steps)), SCALE_MIN, SCALE_MAX)
	if absf(next - cur) > 0.001:
		set_state("wall", "scale", snappedf(next, 0.01))
		relayout()
	return true


func name_rect(i: int) -> Rect2:
	var r: Rect2 = screen_rect(i)
	return Rect2(r.position.x, r.end.y - px(22.0), maxf(r.size.x, px(160.0)), px(22.0))


func tip_for(i: int) -> String:
	var e: Dictionary = entry(i)
	var label: String = String(e.get("label", ""))
	var item: MediaItem = item_of(i)
	if item == null:
		return label
	if not picture_item(item):
		return label
	var sw: Dictionary = panel.call("swatch_for", item)
	if sw.is_empty():
		return label + "  reading its colour"
	return label + "  mostly " + Swatch.hue_word(sw)


func draw() -> void:
	var vis: Rect2 = visible_rect()
	var sp: Vector2 = scroll_pos()
	var m: Font = mono()
	var fsm: int = fs_meta()
	for b: Dictionary in bands:
		var by: float = float(b["y"]) - sp.y
		if by > -px(BAND_H) and by < vis.end.y:
			PmText.draw(body, m, Rect2(0.0, by, body.size.x, px(BAND_H)), String(b["label"]), fsm, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, px(8.0))
	var colours_only: bool = mode() == "colours"
	var list: Array[Dictionary] = entries()
	var radius: float = px(Tk.sz("radius_chip"))
	for i: int in list.size():
		var r: Rect2 = screen_rect(i)
		if not r.intersects(vis):
			continue
		var e: Dictionary = list[i]
		var item: MediaItem = item_of(i)
		if String(e["kind"]) == "folder":
			Paint.rounded(body, r, Tk.c["bg_panel_alt"], radius, Tk.c["border"], 1)
			var side: float = minf(r.size.x, r.size.y) * 0.4
			IconsKit.draw(body, "folder", Rect2(r.position + (r.size - Vector2(side, side)) * 0.5, Vector2(side, side)), Tk.c["text_faint"])
		elif not picture_item(item):
			Paint.rounded(body, r, Tk.c["bg_panel_alt"], radius, Tk.c["border"], 1)
			var side2: float = minf(r.size.x, r.size.y) * 0.4
			IconsKit.draw(body, String(panel.call("kind_icon", item.kind if item != null else "")), Rect2(r.position + (r.size - Vector2(side2, side2)) * 0.5, Vector2(side2, side2)), Tk.c["text_faint"])
		else:
			var sw: Dictionary = panel.call("swatch_for", item)
			if sw.is_empty():
				_draw_reading(r, radius)
			elif colours_only:
				_draw_palette(r, sw)
			else:
				_draw_picture_tile(r, item, sw)
		draw_label_stripe(r, item)
		draw_outline(r, i, radius)


func _draw_reading(r: Rect2, radius: float) -> void:
	Paint.rounded(body, r, Tk.c["bg_panel"], radius, Tk.c["border"], 1)
	var step: float = px(8.0)
	var x: float = r.position.x - r.size.y
	var c: Color = Tk.c["hatch"]
	while x < r.end.x:
		var a: Vector2 = Vector2(x, r.end.y)
		var b: Vector2 = Vector2(x + r.size.y, r.position.y)
		var ca: Vector2 = a
		var cb: Vector2 = b
		if ca.x < r.position.x:
			ca = Vector2(r.position.x, r.end.y - (r.position.x - a.x))
		if cb.x > r.end.x:
			cb = Vector2(r.end.x, r.position.y + (b.x - r.end.x))
		if cb.x > ca.x:
			body.draw_line(ca, cb, c, 2.0)
		x += step


func _draw_palette(r: Rect2, sw: Dictionary) -> void:
	var pal: Array[Color] = Swatch.palette(sw)
	var weights: Array[float] = [3.0, 1.0, 1.0]
	var total: float = 0.0
	for j: int in pal.size():
		total += weights[mini(j, 2)]
	var x: float = r.position.x
	for j2: int in pal.size():
		var w: float = r.size.x * weights[mini(j2, 2)] / total
		body.draw_rect(Rect2(x, r.position.y, w + 0.5, r.size.y), pal[j2], true)
		x += w


func _draw_picture_tile(r: Rect2, item: MediaItem, sw: Dictionary) -> void:
	var t: float = colour_time(item)
	var tex: Texture2D = panel.call("thumb_for", item, t, true)
	if tex != null:
		body.draw_rect(r, Tk.c["bg_panel_alt"], true)
		draw_texture_in(tex, r, true)
	else:
		body.draw_rect(r, Swatch.main_colour(sw).darkened(0.35), true)
	var sh: float = maxf(3.0, px(6.0) * minf(tile_scale(), 1.4))
	body.draw_rect(Rect2(r.position.x, r.end.y - sh, r.size.x, sh), Swatch.main_colour(sw), true)


func _update_meta() -> void:
	var p: Vector2i = panel.call("colour_progress")
	if p.y <= 0:
		set_meta_text("")
	elif p.x < p.y:
		set_meta_text("Reading colours " + str(p.x) + " of " + str(p.y))
	else:
		set_meta_text(str(p.y) + " read")


func build_bar(bar: Container) -> void:
	var pics: Button = bar_toggle(bar, "Pictures", "Each tile shows its picture with a strip of its main colour", mode() == "pictures", _on_mode.bind("pictures"))
	var cols: Button = bar_toggle(bar, "Colours", "Each tile shows only its colours, as one gradient", mode() == "colours", _on_mode.bind("colours"))
	pics.set_meta("wall_mode", "pictures")
	cols.set_meta("wall_mode", "colours")
	_update_meta()


func _on_mode(on: bool, which: String) -> void:
	if not on and mode() == which:
		panel.call("rebuild_view_bar")
		return
	if on:
		set_state("wall", "mode", which)
		panel.call("rebuild_view_bar")
		redraw()

extends "res://modules/core_panels/bin_views/bin_view.gd"

const Usage := preload("res://modules/core_panels/bin_views/usage.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const TILE_W := 128.0
const SCALE_MIN := 0.7
const SCALE_MAX := 1.8
const FILTERS: PackedStringArray = ["all", "unused", "used"]
const FILTER_LABELS: PackedStringArray = ["All", "Not used", "Used"]


func id() -> String:
	return "used"


func title() -> String:
	return "Used parts"


func glyph() -> String:
	return "used"


func uses_hover_scrub() -> bool:
	return true


func filter_mode() -> String:
	var f: String = String(state("used", "filter", "all"))
	return f if f in FILTERS else "all"


func scope() -> String:
	return "every" if String(state("used", "scope", "sequence")) == "every" else "sequence"


func tile_scale() -> float:
	return clampf(float(state("used", "scale", 1.0)), SCALE_MIN, SCALE_MAX)


func filter(list: Array[Dictionary]) -> Array[Dictionary]:
	var mode: String = filter_mode()
	if mode == "all":
		return list
	var out: Array[Dictionary] = []
	for e: Dictionary in list:
		if String(e.get("kind", "")) != "item":
			out.append(e)
			continue
		var used: bool = not (panel.call("usage_for", String(e["id"])) as Dictionary).is_empty()
		if (mode == "used") == used:
			out.append(e)
	return out


func sizes() -> Dictionary:
	var w: float = px(TILE_W) * tile_scale()
	var pic_h: float = round(w * 0.5625)
	var bar_h: float = px(4.0)
	var name_h: float = px(16.0)
	var stat_h: float = px(15.0)
	return {"w": w, "pic": pic_h, "bar": bar_h, "name": name_h, "stat": stat_h, "h": pic_h + px(5.0) + bar_h + px(3.0) + name_h + stat_h + px(4.0)}


func layout(width: float, _height: float) -> Vector2:
	var list: Array[Dictionary] = entries()
	var rs: Array[Rect2] = rects()
	rs.resize(list.size())
	var sz: Dictionary = sizes()
	var tw: float = float(sz["w"])
	var th: float = float(sz["h"])
	var gap: float = px(4.0)
	var pad: float = px(6.0)
	var cols: int = maxi(1, int(floor((width - pad * 2.0 + gap) / (tw + gap))))
	for i: int in list.size():
		rs[i] = Rect2(pad + float(i % cols) * (tw + gap), pad + float(i / cols) * (th + gap), tw, th)
	var rows: int = (list.size() + cols - 1) / cols
	_update_meta()
	return Vector2(width, pad * 2.0 + float(rows) * (th + gap))


func zoom(steps: float, _at: Vector2) -> bool:
	var cur: float = tile_scale()
	var next: float = clampf(cur * pow(1.1, signf(steps)), SCALE_MIN, SCALE_MAX)
	if absf(next - cur) > 0.001:
		set_state("used", "scale", snappedf(next, 0.01))
		relayout()
	return true


func name_rect(i: int) -> Rect2:
	var r: Rect2 = screen_rect(i)
	var sz: Dictionary = sizes()
	var y: float = r.position.y + float(sz["pic"]) + px(5.0) + float(sz["bar"]) + px(3.0)
	return Rect2(r.position.x, y - px(3.0), maxf(r.size.x, px(140.0)), px(22.0))


func tip_for(i: int) -> String:
	var e: Dictionary = entry(i)
	var item: MediaItem = item_of(i)
	var label: String = String(e.get("label", ""))
	if item == null:
		return label
	var rec: Dictionary = panel.call("usage_for", item.id)
	return label + "  " + Usage.status_text(rec, _length(item), item.is_timed())


func _length(item: MediaItem) -> float:
	var d: Project = doc()
	return d.media_duration(item) if d != null else item.duration


func draw() -> void:
	var vis: Rect2 = visible_rect()
	var list: Array[Dictionary] = entries()
	var sz: Dictionary = sizes()
	var f: Font = font()
	var m: Font = mono()
	var fss: int = fs_small()
	var fsm: int = fs_meta()
	var radius: float = px(Tk.sz("radius"))
	for i: int in list.size():
		var r: Rect2 = screen_rect(i)
		if not r.intersects(vis):
			continue
		var e: Dictionary = list[i]
		var item: MediaItem = item_of(i)
		var pic: Rect2 = Rect2(r.position, Vector2(r.size.x, float(sz["pic"])))
		var selected: bool = is_selected(i)
		if String(e["kind"]) == "folder":
			Paint.rounded(body, pic, Tk.c["bg_panel_alt"], radius, Tk.c["border"], 1)
			var side: float = minf(pic.size.x, pic.size.y) * 0.34
			IconsKit.draw(body, "folder", Rect2(pic.position + (pic.size - Vector2(side, side)) * 0.5, Vector2(side, side)), Tk.c["text_faint"])
		else:
			var t: float = -1.0
			if i == hover_index() and item != null and item.kind == "video":
				t = float(panel.call("scrub_time", item, float(body.get("hover_frac"))))
			draw_picture(pic, item, t, radius)
			draw_label_stripe(pic, item)
			draw_badge(pic, duration_text(item))
			if t >= 0.0:
				body.draw_rect(Rect2(pic.position.x + pic.size.x * float(body.get("hover_frac")), pic.position.y, 1.0, pic.size.y), Tk.c["accent_dim"], true)
		draw_outline(pic, i, radius)
		var y: float = pic.end.y + px(5.0)
		var bar: Rect2 = Rect2(r.position.x, y, r.size.x, float(sz["bar"]))
		var name_y: float = bar.end.y + px(3.0)
		var col: Color = Tk.c["text_bright"] if selected else Tk.c["text"]
		if String(e["kind"]) == "folder":
			caption(r, name_y, float(sz["name"]), String(e.get("label", "")), fss, col)
			caption(r, name_y + float(sz["name"]), float(sz["stat"]), String(e.get("meta", "")).to_upper(), fsm, Tk.c["text_faint"], m)
			continue
		var rec: Dictionary = panel.call("usage_for", item.id) if item != null else {}
		_draw_bar(bar, item, rec)
		caption(r, name_y, float(sz["name"]), String(e.get("label", "")), fss, col)
		var stat: String = Usage.status_text(rec, _length(item), item.is_timed()).to_upper() if item != null else ""
		caption(r, name_y + float(sz["name"]), float(sz["stat"]), stat, fsm, Tk.c["text_faint"], m)


func _draw_bar(bar: Rect2, item: MediaItem, rec: Dictionary) -> void:
	var radius: float = float(bar.size.y) * 0.5
	Paint.rounded(body, bar, Tk.c["bg_panel_high"], radius)
	if item == null or rec.is_empty():
		return
	var dur: float = _length(item)
	if not item.is_timed() or dur <= 0.0:
		Paint.rounded(body, bar, Tk.c["sol"], radius)
		return
	for v: Vector2 in (rec.get("spans", PackedVector2Array()) as PackedVector2Array):
		var a: float = clampf(v.x / dur, 0.0, 1.0)
		var b: float = clampf(v.y / dur, 0.0, 1.0)
		if b > a:
			body.draw_rect(Rect2(bar.position.x + bar.size.x * a, bar.position.y, maxf(bar.size.x * (b - a), 1.5), bar.size.y), Tk.c["sol"], true)


func _update_meta() -> void:
	var n: int = int(panel.call("unused_count"))
	var where: String = "in this sequence" if scope() == "sequence" else "in any sequence"
	set_meta_text(str(n) + " not used " + where)


func build_bar(bar: Container) -> void:
	for n: int in FILTERS.size():
		var b: Button = bar_toggle(bar, FILTER_LABELS[n], "Show " + FILTER_LABELS[n].to_lower() + " media" if n > 0 else "Show every item", filter_mode() == FILTERS[n], _on_filter.bind(FILTERS[n]))
		b.set_meta("used_filter", FILTERS[n])
	var drop: Button = PmDrop.make_drop([PmDrop.choice("sequence", "This sequence"), PmDrop.choice("every", "Every sequence")], scope())
	PmUI.tip(drop, "What counts as used: the open sequence, or every sequence in the project")
	drop.connect("changed", _on_scope)
	drop.set_meta("used_scope", true)
	fit_drop(drop)
	bar_add(bar, drop, "What counts")
	_update_meta()


func _on_filter(on: bool, which: String) -> void:
	if on:
		set_state("used", "filter", which)
	panel.call("rebuild_view_bar")
	panel.call("refresh")


func _on_scope(value: String) -> void:
	set_state("used", "scope", value)
	panel.call("usage_dirty")
	panel.call("refresh")

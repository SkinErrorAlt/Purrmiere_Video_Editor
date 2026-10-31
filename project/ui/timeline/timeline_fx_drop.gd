extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Verbs := preload("res://doc/verbs.gd")
const DropRule := preload("res://doc/drop_rule.gd")
const LinkAsOne := preload("res://doc/link_as_one.gd")
const HitKit := preload("res://ui/timeline/timeline_hit.gd")
const LanesKit := preload("res://ui/timeline/timeline_lanes.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const EFFECT_SOURCE := "res://modules/core_panels/effect_source.gd"
const OUTLINE_PX := 2.0
const NAME_ROW_PX := 19.0


static func receivers(seq: Sequence, clip_id: String, effect_id: String) -> PackedStringArray:
	if seq == null or clip_id.is_empty():
		return PackedStringArray()
	var def: Dictionary = {}
	if not effect_id.is_empty() and ResourceLoader.exists(EFFECT_SOURCE):
		def = load(EFFECT_SOURCE).call("get_def", effect_id)
	var ids: PackedStringArray = DropRule.targets(seq, clip_id)
	if def.is_empty():
		return ids
	return Verbs.effect_targets(seq, ids, def)


static func draw(node: Control, canvas: Control, dp: Dictionary, g: Dictionary, f: Font, fs: int) -> bool:
	var seq: Sequence = canvas.call("seq")
	var clip_id: String = String(dp.get("clip_id", ""))
	if seq == null or clip_id.is_empty() or String(dp.get("kind", "")) != "effect":
		return false
	var ids: PackedStringArray = receivers(seq, clip_id, String(dp.get("id", "")))
	if ids.is_empty():
		return false
	var lanes: Dictionary = canvas.call("lanes")
	var under: Rect2 = Rect2()
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		var tr: Track = seq.track_of(id)
		if c == null or tr == null:
			continue
		var l: Dictionary = LanesKit.lane_for_track(lanes, tr.id)
		if l.is_empty():
			continue
		var r: Rect2 = HitKit.clip_rect(g, l, c)
		r.position.x = maxf(r.position.x, float(g["header_w"]))
		r.size.x = maxf(r.size.x, 2.0)
		node.draw_rect(r, Tk.c["selection_fill"], true)
		node.draw_rect(r.grow(-OUTLINE_PX * 0.5), Tk.c["accent"], false, OUTLINE_PX)
		if id == clip_id or under.size.x <= 0.0:
			under = r
	draw_fill(node, seq, seq.clip_by_id(clip_id), lanes, g)
	var text: String = DropRule.hint(seq, clip_id, ids)
	if under.size.x <= 0.0:
		return true
	draw_chip(node, under.position + Vector2(OUTLINE_PX * 2.0, NAME_ROW_PX), text, f, fs)
	return true


static func draw_fill(node: Control, seq: Sequence, c: Clip, lanes: Dictionary, g: Dictionary) -> void:
	for sp: Dictionary in LinkAsOne.fill_spans(seq, c):
		var l: Dictionary = LanesKit.lane_for_track(lanes, String(sp["track"]))
		if l.is_empty():
			continue
		var x0: float = maxf(HitKit.x_of(g, float(sp["from"])), float(g["header_w"]))
		var x1: float = HitKit.x_of(g, float(sp["to"]))
		if x1 <= x0:
			continue
		var r: Rect2 = Rect2(x0, HitKit.lane_screen_y(g, l), x1 - x0, float(l["h"]))
		node.draw_rect(r.grow(-OUTLINE_PX), Tk.c["selection_fill"], false, OUTLINE_PX)


static func draw_chip(node: Control, at: Vector2, text: String, f: Font, fs: int) -> void:
	if text.is_empty():
		return
	var h: float = f.get_height(fs) + PmText.chip_pad() * 2.0
	var w: float = PmText.width_of(f, text, fs) + PmText.pad() * 2.0
	var box: Rect2 = Rect2(at, Vector2(minf(w, maxf(node.size.x - at.x - 4.0, 24.0)), h))
	node.draw_rect(box, Tk.c["bg_panel_high"], true)
	node.draw_rect(Rect2(box.position + Vector2(0.5, 0.5), box.size - Vector2(1.0, 1.0)), Tk.c["border_soft"], false, 1.0)
	PmText.draw(node, f, box, text, fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, PmText.pad(), PmText.baseline_in(f, fs, box))


static func monitor_hint(seq: Sequence, clip_id: String) -> String:
	if seq == null or clip_id.is_empty() or seq.clip_by_id(clip_id) == null:
		return ""
	return DropRule.hint(seq, clip_id, DropRule.targets(seq, clip_id))

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Regions := preload("res://doc/media_regions.gd")
const Kinds := preload("res://doc/region_kinds.gd")
const RegionApply := preload("res://doc/region_apply.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const SourceReveal := preload("res://modules/core_panels/source_reveal.gd")
const PREFIX := "org_"
const BAND_H := 4.0
const MAX_IN_MENU := 6

static var drawn: int = 0


static func draw_on_clip(ci: CanvasItem, c: Clip, r: Rect2, clip_x0: float, pps: float, item: MediaItem) -> void:
	if item == null or c == null or r.size.y < 8.0 or not Regions.enabled:
		return
	var list: Array[Dictionary] = Regions.on_clip(c, item)
	if list.is_empty():
		return
	var y: float = r.end.y - BAND_H - 1.0
	for e: Dictionary in list:
		var x0: float = maxf(clip_x0 + float(e["from"]) * pps, r.position.x)
		var x1: float = minf(clip_x0 + float(e["to"]) * pps, r.end.x)
		if x1 - x0 < 0.5:
			continue
		var reg: Dictionary = e["region"]
		var col: Color = Regions.colour_of(reg)
		if Regions.acts_as_cut(reg):
			ci.draw_rect(Rect2(x0, r.position.y, x1 - x0, r.size.y), Color(col, 0.16), true)
		ci.draw_rect(Rect2(x0, y, x1 - x0, BAND_H), col, true)
		drawn += 1


static func clip_items(d: Project, c: Clip, t: float) -> Array:
	var out: Array = []
	if d == null or c == null:
		return out
	var item: MediaItem = d.media_by_id(c.media_id)
	if item == null:
		return out
	var here: Array = Regions.at_clip_time(c, item, t - c.start)
	for i: int in mini(here.size(), MAX_IN_MENU):
		var reg: Dictionary = here[i]
		var rid: String = String(reg.get("id", ""))
		var sub: Array = [
			PmMenu.item("org_hide:" + rid, "Remove from this project"),
			PmMenu.sub_item("org_kill_sub:" + rid, "Remove from the organizer too", [PmMenu.item("org_kill:" + rid, "Remove it from the video everywhere")]),
			PmMenu.item("org_show:" + rid, "Show in the Organizer"),
		]
		out.append(PmMenu.sub_item("org_rg:" + rid, "Region: " + Kinds.name_of(String(reg.get("kind", ""))), sub))
	if not Regions.list(item).is_empty():
		out.append(PmMenu.item("org_apply", "Use the organizer regions on this clip"))
	if not Regions.hidden(item).is_empty():
		out.append(PmMenu.item("org_unhide", "Show the regions removed from this project"))
	if not out.is_empty():
		out.append(PmMenu.separator())
	return out


static func on_clip_menu(from: Node, d: Project, s: Sequence, id: String, clip_id: String) -> bool:
	if not id.begins_with(PREFIX) or d == null or s == null:
		return false
	var c: Clip = s.clip_by_id(clip_id)
	if c == null:
		return true
	if id.begins_with("org_hide:"):
		Regions.hide_in_project(d, c.media_id, PackedStringArray([id.substr(9)]))
	elif id.begins_with("org_kill:"):
		Regions.remove(d, c.media_id, PackedStringArray([id.substr(9)]))
	elif id.begins_with("org_show:"):
		reveal(from, c.media_id, id.substr(9))
	elif id == "org_apply":
		var ids: PackedStringArray = PackedStringArray([clip_id])
		for f: Clip in s.linked(c):
			if not ids.has(f.id):
				ids.append(f.id)
		RegionApply.apply(d, s, RegionApply.EDITOR_FNS, ids, "Use the organizer regions on " + c.label)
	elif id == "org_unhide":
		var item: MediaItem = d.media_by_id(c.media_id)
		Regions.hide_in_project(d, c.media_id, Regions.hidden(item), false)
	return true


static func reveal(from: Node, media_id: String, region_id: String) -> void:
	var dock: Node = SourceReveal.dock_for(from) if from != null else null
	if dock != null:
		dock.call("show_panel", "organizer")
	var panel: Object = Bus.instance().panel("organizer")
	if panel != null and panel.has_method("reveal"):
		panel.call("reveal", media_id, region_id)

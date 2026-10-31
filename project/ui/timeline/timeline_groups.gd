extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Lanes := preload("res://ui/timeline/timeline_lanes.gd")
const Hit := preload("res://ui/timeline/timeline_hit.gd")
const Icons := preload("res://ui/kit/icons.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const GroupVerbs := preload("res://doc/group_verbs.gd")
const GroupTree := preload("res://doc/group_tree.gd")
const Glow := preload("res://ui/timeline/group_glow.gd")
const GroupsMenu := preload("res://ui/timeline/group_menu_extra.gd")
const Verbs := preload("res://doc/verbs.gd")
const SELF_PATH := "res://ui/timeline/timeline_groups.gd"
const TAG_H := 14.0
const TAG_PAD := 6.0
const TAG_MIN_W := 24.0
const LOCK_W := 12.0
const LINE := 2.0
const DASH := 4.0

static var _buckets_cache: Dictionary = {}


static func _script() -> GDScript:
	return load(SELF_PATH)


static func serial_of(canvas: Control) -> int:
	var d: Project = canvas.call("doc") if canvas != null else null
	return d.serial if d != null else -1


static func buckets(canvas: Control, s: Sequence) -> Dictionary:
	var d: Project = canvas.call("doc")
	var key: String = str(canvas.get_instance_id()) + "|" + s.id + "|" + str(d.serial if d != null else 0)
	var hit: Variant = _buckets_cache.get(str(canvas.get_instance_id()), null)
	if hit is Dictionary and String((hit as Dictionary).get("key", "")) == key:
		return (hit as Dictionary)["groups"]
	var groups: Dictionary = {}
	for tr: Track in s.all_tracks():
		for c: Clip in tr.clips:
			if c.group_id.is_empty():
				continue
			if not groups.has(c.group_id):
				groups[c.group_id] = []
			(groups[c.group_id] as Array).append([tr, c])
	_buckets_cache[str(canvas.get_instance_id())] = {"key": key, "groups": groups}
	return groups


static func tags(canvas: Control) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s: Sequence = canvas.call("seq")
	if s == null:
		return out
	var groups: Dictionary = buckets(canvas, s)
	if groups.is_empty():
		return out
	var geom: Dictionary = canvas.call("geometry")
	var ln: Dictionary = canvas.call("lanes")
	var header_w: float = float(geom["header_w"])
	var width: float = float(geom["width"])
	var font: Font = canvas.get("_font")
	var fs: int = Tk.fs(Tk.sz("font_tiny"))
	var tag_h: float = float(Tk.px(TAG_H))
	for gid: Variant in groups.keys():
		var per_set: Dictionary = {}
		for pair: Variant in groups[gid]:
			var tr: Track = (pair as Array)[0]
			var c: Clip = (pair as Array)[1]
			var l: Dictionary = Lanes.lane_for_track(ln, tr.id)
			if l.is_empty():
				continue
			var set_name: String = String(l["set"])
			var y: float = Hit.lane_screen_y(geom, l)
			var box: Dictionary = per_set.get(set_name, {"x0": INF, "x1": -INF, "y0": INF, "y1": -INF})
			box["x0"] = minf(float(box["x0"]), float(canvas.call("x_of", c.start)))
			box["x1"] = maxf(float(box["x1"]), float(canvas.call("x_of", c.end())))
			box["y0"] = minf(float(box["y0"]), y)
			box["y1"] = maxf(float(box["y1"]), y + float(l["h"]))
			per_set[set_name] = box
		var rec: Dictionary = GroupTree.display_record(s, String(gid), serial_of(canvas))
		var name_: String = String(rec.get("name", Sequence.GROUP_NAME))
		var locked: bool = bool(rec.get("locked", false))
		for set_name: Variant in per_set.keys():
			var b: Dictionary = per_set[set_name]
			var region: Rect2 = geom["main_rect"] if String(set_name) == "main" else geom["band_rect"]
			var bracket: Rect2 = Rect2(float(b["x0"]), float(b["y0"]), float(b["x1"]) - float(b["x0"]), float(b["y1"]) - float(b["y0"]))
			var view: Rect2 = Rect2(header_w, region.position.y, width - header_w, region.size.y)
			if not bracket.intersects(view):
				continue
			var tw: float = font.get_string_size(name_, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if font != null else 40.0
			var left: float = maxf(bracket.position.x, header_w) + LINE
			var room: float = maxf(minf(bracket.end.x, width) - left - LINE, TAG_MIN_W)
			var tag_w: float = minf(tw + TAG_PAD * 2.0 + (LOCK_W if locked else 0.0), room)
			var top: float = maxf(bracket.position.y, region.position.y) + 1.0
			out.append({"id": String(gid), "record": rec, "bracket": bracket, "tag": Rect2(left, top, tag_w, tag_h), "region": region, "set": String(set_name)})
	return out


static func tag_rects(canvas: Control) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for t: Dictionary in tags(canvas):
		out.append(t["tag"])
	return out


static func tag_at(canvas: Control, pos: Vector2) -> Dictionary:
	var list: Array[Dictionary] = tags(canvas)
	for i: int in range(list.size() - 1, -1, -1):
		var t: Dictionary = list[i]
		var r: Rect2 = t["tag"]
		var region: Rect2 = t["region"]
		if r.has_point(pos) and region.has_point(pos):
			return t
	return {}


static func colour_of(rec: Dictionary) -> Color:
	var ci: int = int(rec.get("colour", -1))
	if ci < 0:
		return Tk.c["text_dim"]
	return Tk.label_colour(ci)


static func draw(canvas: Control) -> void:
	Glow.draw(canvas)
	var list: Array[Dictionary] = tags(canvas)
	if list.is_empty():
		return
	var geom: Dictionary = canvas.call("geometry")
	var header_w: float = float(geom["header_w"])
	var width: float = float(geom["width"])
	var font: Font = canvas.get("_font")
	var fs: int = Tk.fs(Tk.sz("font_tiny"))
	var ink: Color = Tk.c["bg_panel"]
	for t: Dictionary in list:
		var rec: Dictionary = t["record"]
		var col: Color = colour_of(rec)
		var br: Rect2 = t["bracket"]
		var region: Rect2 = t["region"]
		var locked: bool = bool(rec.get("locked", false))
		var muted: bool = bool(rec.get("muted", false))
		var x0: float = maxf(br.position.x, header_w)
		var x1: float = minf(br.end.x, width)
		var y0: float = maxf(br.position.y, region.position.y)
		var y1: float = minf(br.end.y, region.end.y)
		if x1 <= x0 or y1 <= y0:
			continue
		if br.position.y >= region.position.y:
			_line(canvas, Vector2(x0, br.position.y), Vector2(x1, br.position.y), col, locked)
		if br.position.x >= header_w:
			_line(canvas, Vector2(br.position.x + LINE * 0.5, y0), Vector2(br.position.x + LINE * 0.5, y1), col, locked)
		if br.end.x <= width:
			_line(canvas, Vector2(br.end.x - LINE * 0.5, y0), Vector2(br.end.x - LINE * 0.5, y1), col, locked)
		var tag: Rect2 = t["tag"]
		if tag.position.y + tag.size.y > region.end.y:
			continue
		canvas.draw_rect(tag, col, true)
		var text_w: float = tag.size.x - TAG_PAD * 2.0 - (LOCK_W if locked else 0.0)
		if font != null and text_w > 6.0:
			var drawn: Rect2 = Glow.tag_text(canvas, font, Rect2(tag.position.x + TAG_PAD, tag.position.y, text_w, tag.size.y), String(rec.get("name", "")), fs, ink)
			if muted and drawn.has_area():
				canvas.draw_line(Vector2(drawn.position.x, tag.get_center().y), Vector2(drawn.end.x, tag.get_center().y), ink, 1.0)
		if locked:
			Icons.draw(canvas, "lock", Rect2(tag.end.x - LOCK_W - 1.0, tag.position.y + 2.0, LOCK_W - 2.0, LOCK_W - 2.0), ink)


static func _line(canvas: Control, a: Vector2, b: Vector2, col: Color, dashed: bool) -> void:
	if dashed:
		canvas.draw_dashed_line(a, b, col, LINE, DASH)
	else:
		canvas.draw_line(a, b, col, LINE)


static func press(canvas: Control, pos: Vector2, mods: Dictionary) -> bool:
	var t: Dictionary = tag_at(canvas, pos)
	if t.is_empty():
		return false
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return true
	var ids: PackedStringArray = PackedStringArray()
	for c: Clip in s.group_clips(String(t["id"])):
		ids.append(c.id)
	Verbs.select(d, s, Verbs.MoveRule.pick(s, ids, bool(canvas.get("linked_selection"))), "add" if bool(mods.get("shift", false)) else "replace", Verbs.MoveRule.picked_after(s, ids, bool(mods.get("shift", false))))
	canvas.queue_redraw()
	return true


static func menu_items(s: Sequence, gid: String) -> Array:
	var rec: Dictionary = s.group_record(gid)
	var colours: Array = [PmMenu.check_item("colour:-1", "None", int(rec.get("colour", -1)) < 0)]
	for i: int in Tk.LABEL_NAMES.size():
		colours.append(PmMenu.check_item("colour:" + str(i), Tk.label_name(i), int(rec.get("colour", -1)) == i))
	var out: Array = [
		PmMenu.item("select", "Select this slice" if GroupTree.is_slice(s, gid) else "Select the group"),
		PmMenu.item("rename", "Rename"),
		PmMenu.sub_item("colour", "Colour", colours),
		PmMenu.separator(),
		PmMenu.check_item("lock", "Lock", bool(rec.get("locked", false)), Cmd.keys_text("group.lock")),
		PmMenu.check_item("mute", "Mute", bool(rec.get("muted", false)), Cmd.keys_text("group.mute")),
		PmMenu.separator(),
		PmMenu.item("add", "Add the selection to this group", Cmd.keys_text("group.add_selection")),
		PmMenu.item("remove", "Remove the selection from this group", Cmd.keys_text("group.remove_selection")),
		PmMenu.separator(),
		PmMenu.item("nest", "Turn the group into a nest", Cmd.keys_text("group.to_nest")),
		PmMenu.item("ungroup", "Ungroup", Cmd.keys_text("clip.ungroup")),
	]
	return GroupsMenu.extend_tag_menu(s, gid, out)


static func right(canvas: Control, pos: Vector2) -> bool:
	var t: Dictionary = tag_at(canvas, pos)
	if t.is_empty():
		return false
	var s: Sequence = canvas.call("seq")
	if s == null:
		return true
	var m: Control = PmMenu.open(canvas, menu_items(s, String(t["id"])), canvas.get_global_mouse_position())
	if m != null and m.is_inside_tree():
		m.connect("picked", Callable(_script(), "on_menu").bind(canvas, String(t["id"])))
	return true


static func on_menu(id: String, canvas: Control, gid: String) -> void:
	if canvas == null or not is_instance_valid(canvas):
		return
	var d: Project = canvas.call("doc")
	var s: Sequence = canvas.call("seq")
	if d == null or s == null:
		return
	apply(d, s, gid, id, canvas)


static func apply(d: Project, s: Sequence, gid: String, id: String, host: Control = null) -> bool:
	var rec: Dictionary = s.group_record(gid)
	var extra: int = GroupsMenu.apply(d, s, gid, id)
	if extra >= 0:
		return extra == 1
	if id == "select":
		return GroupVerbs.select_group(d, s, gid)
	if id == "rename":
		if host != null:
			var fields: Array[Dictionary] = [{"key": "name", "label": "Name", "type": "string", "default": GroupTree.title(s, gid)}]
			var answered: Signal = PmUI.form(host, "Rename group", fields, "Rename", "Cancel")
			answered.connect(Callable(_script(), "on_rename").bind(d, s, gid))
		return true
	if id.begins_with("colour:"):
		return GroupVerbs.recolour(d, s, gid, int(id.substr(7)))
	if id == "lock":
		return GroupVerbs.set_locked(d, s, gid, not bool(rec.get("locked", false)))
	if id == "mute":
		return GroupVerbs.set_muted(d, s, gid, not bool(rec.get("muted", false)))
	if id == "add":
		return GroupVerbs.add_to_group(d, s, gid, GroupTree.picked(s))
	if id == "remove":
		return GroupVerbs.remove_from_group(d, s, Verbs.selection(s))
	if id == "nest":
		return not GroupVerbs.group_to_nest(d, s, gid).is_empty()
	if id == "ungroup":
		return GroupVerbs.ungroup(d, s, gid)
	return false


static func on_rename(result: Variant, d: Project, s: Sequence, gid: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	GroupVerbs.rename(d, s, gid, String((result as Dictionary).get("name", "")))


static func group_items(s: Sequence, c: Clip) -> Array:
	if s == null or c == null:
		return []
	var sub: Array = []
	var in_group: bool = not c.group_id.is_empty()
	if in_group:
		var rec: Dictionary = s.group_record(c.group_id)
		sub.append(PmMenu.item("grp_select", "Select this slice" if GroupTree.is_slice(s, c.group_id) else "Select the group"))
		sub.append_array(GroupsMenu.clip_items(s, c.group_id))
		sub.append(PmMenu.item("grp_rename", "Rename the slice" if GroupTree.is_slice(s, c.group_id) else "Rename the group"))
		sub.append(PmMenu.check_item("grp_lock", "Lock the group", bool(rec.get("locked", false)), Cmd.keys_text("group.lock")))
		sub.append(PmMenu.check_item("grp_mute", "Mute the group", bool(rec.get("muted", false)), Cmd.keys_text("group.mute")))
		sub.append(PmMenu.item("grp_remove", "Remove the selection from its group", Cmd.keys_text("group.remove_selection")))
		sub.append(PmMenu.item("grp_nest", "Turn the group into a nest", Cmd.keys_text("group.to_nest")))
	for gid: String in s.group_ids_in_use():
		if gid == c.group_id:
			continue
		sub.append(PmMenu.item("grp_add:" + gid, "Add the selection to " + GroupTree.title(s, gid)))
	if sub.is_empty():
		return []
	var title: String = "Group" if not in_group else "Group: " + GroupTree.title(s, c.group_id)
	return [PmMenu.sub_item("grp", title, sub)]


static func nest_items(d: Project, c: Clip) -> Array:
	var out: Array = []
	if c == null or not c.is_nest():
		return out
	out.append(PmMenu.check_item("see_inside", "See inside", bool(c.nest.get("see_inside", false)), Cmd.keys_text("clip.see_inside")))
	out.append(PmMenu.check_item("hear_audio", "Hear audio", bool(c.nest.get("hear_audio", true)), Cmd.keys_text("nest.hear_audio")))
	var inner: Sequence = d.sequence_by_id(c.sequence_id) if d != null else null
	if inner != null and not inner.audio_tracks.is_empty():
		var heard: PackedStringArray = Verbs.nest_heard_tracks(d, c)
		var sub: Array = [PmMenu.check_item("nest_track_all", "Every track", heard.size() == inner.audio_tracks.size())]
		for t: Track in inner.audio_tracks:
			sub.append(PmMenu.check_item("nest_track:" + t.id, t.label, heard.has(t.id)))
		out.append(PmMenu.sub_item("nest_tracks", "Hear these tracks", sub))
	out.append(PmMenu.check_item("show_audio_below", "Show audio below", bool(c.nest.get("show_audio_below", false))))
	out.append(PmMenu.item("open_nest", "Open the nested sequence"))
	out.append(PmMenu.item("unnest", "Unnest"))
	out.append(PmMenu.item("unnest_group", "Unnest to a group", Cmd.keys_text("nest.unnest_to_group")))
	return out


static func owns_clip_menu_id(id: String) -> bool:
	return id.begins_with("grp_") or id.begins_with("nest_track") or id == "unnest_group"


static func on_clip_menu(host: Control, d: Project, s: Sequence, c: Clip, id: String) -> bool:
	if d == null or s == null or c == null:
		return false
	if id == "nest_track_all":
		return Verbs.set_nest_options(d, s, c.id, {"hear_audio": true, "audio_allow": []}, "Nest tracks heard")
	if id.begins_with("nest_track:"):
		var tid: String = id.substr(11)
		return Verbs.set_nest_track_heard(d, s, c.id, tid, not Verbs.nest_heard_tracks(d, c).has(tid))
	if id == "unnest_group":
		var ids: PackedStringArray = Verbs.selection(s)
		if not ids.has(c.id):
			ids = PackedStringArray([c.id])
		return not GroupVerbs.unnest_to_group(d, s, ids).is_empty()
	if id.begins_with("grp_add:"):
		return GroupVerbs.add_to_group(d, s, id.substr(8), GroupTree.picked(s))
	var map: Dictionary = {"grp_select_whole": "select_whole", "grp_panel": "panel", "grp_select": "select", "grp_rename": "rename", "grp_lock": "lock", "grp_mute": "mute", "grp_remove": "remove", "grp_nest": "nest"}
	if map.has(id) and not c.group_id.is_empty():
		return apply(d, s, c.group_id, String(map[id]), host)
	return false

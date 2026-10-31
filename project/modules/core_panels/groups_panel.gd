extends "res://modules/core_panels/panel_base.gd"

const GroupTree := preload("res://doc/group_tree.gd")
const Glow := preload("res://ui/timeline/group_glow.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const GLOW_OWNER := "groups_panel"
const ROW_H := 28.0
const CLIP_ROW_H := 24.0
const HINT := "Drop an effect on a row to put it on every clip there."
const QUIET_KINDS: PackedStringArray = ["playhead", "live", "live_audio"]

var filter: String = ""
var open: Dictionary = {}
var rows: Array[Dictionary] = []
var hover_key: String = ""
var drop_key: String = ""
var drop_note: String = ""
var flash_key: String = ""
var drop_payload: Dictionary = {}
var _search: LineEdit = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _foot: Label = null
var _queued: bool = false
var _dirty: bool = false
var _row_nodes: Dictionary = {}


func _build(root_: Control) -> void:
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_search = PmUI.line_edit("Filter groups")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.custom_minimum_size = Vector2(60.0, 0.0)
	_search.text_changed.connect(_on_filter)
	head.add_child(_search)
	var make: Button = PmButton.make("Group the picked clips")
	make.set("quiet", true)
	PmUI.tip(make, "Group the clips you picked", Cmd.keys_text("clip.group"))
	make.pressed.connect(_on_make)
	head.add_child(make)
	_scroll = vscroll_area(col)
	_list = PmUI.vbox(0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	col.add_child(PmUI.divider())
	_foot = PmLabel.dim("")
	_foot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_foot.clip_text = true
	_foot.custom_minimum_size = Vector2(0, 0)
	col.add_child(PmUI.inset(_foot))
	root_.visibility_changed.connect(_on_visibility)
	rebuild()


func _on_make() -> void:
	Cmd.run("clip.group")


func _on_filter(text: String) -> void:
	filter = text.strip_edges().to_lower()
	rebuild()


func _on_visibility() -> void:
	if _dirty and _alive() and _root.is_visible_in_tree():
		rebuild()


static func short_time(t: float) -> String:
	var whole: int = int(floor(maxf(t, 0.0) + 0.0005))
	var h: int = whole / 3600
	var m: int = (whole % 3600) / 60
	var sec: int = whole % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, sec]
	return "%d:%02d" % [m, sec]


static func row_key(kind: String, id: String) -> String:
	return kind + ":" + id


func _matches(s: Sequence, gid: String) -> bool:
	if filter.is_empty():
		return true
	if GroupTree.title(s, gid).to_lower().contains(filter):
		return true
	for c: Clip in GroupTree.members(s, gid):
		if c.label.to_lower().contains(filter):
			return true
	if not GroupTree.is_slice(s, gid):
		for sid: String in GroupTree.child_ids(s, gid):
			if GroupTree.title(s, sid).to_lower().contains(filter):
				return true
	return false


func is_open(key: String, default_open: bool) -> bool:
	return bool(open.get(key, default_open))


func plan(s: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s == null:
		return out
	var serial: int = doc().serial if doc() != null else -1
	var chosen: Dictionary = {}
	for id: String in s.selected_clip_ids:
		chosen[id] = true
	for root: String in GroupTree.roots(s):
		if not _matches(s, root):
			continue
		var rec: Dictionary = s.group_record(root)
		var slices: PackedStringArray = GroupTree.slices_of(s, root, serial)
		var all: Array[Clip] = GroupTree.members(s, root)
		var meta: String = ("%d slices · %d clips" % [slices.size(), all.size()]) if not slices.is_empty() else ("%d clip" % all.size() if all.size() == 1 else "%d clips" % all.size())
		var key: String = row_key("group", root)
		out.append({"key": key, "kind": "group", "gid": root, "depth": 0, "title": GroupTree.title(s, root, serial), "meta": meta, "colour": int(rec.get("colour", -1)), "fold": true, "open": is_open(key, true), "sel": _all_in(all, chosen)})
		if not is_open(key, true):
			continue
		if slices.is_empty():
			_clip_rows(s, all, 1, out, chosen)
			continue
		for sid: String in slices:
			var srec: Dictionary = s.group_record(sid)
			var sm: Array[Clip] = GroupTree.members(s, sid)
			var sp: Vector2 = GroupTree.span(s, sid)
			var skey: String = row_key("slice", sid)
			out.append({"key": skey, "kind": "slice", "gid": sid, "depth": 1, "title": GroupTree.title(s, sid, serial), "meta": "%s to %s · %d" % [short_time(sp.x), short_time(sp.y), sm.size()], "colour": int(srec.get("colour", -1)), "fold": true, "open": is_open(skey, false), "sel": _all_in(sm, chosen)})
			if is_open(skey, false):
				_clip_rows(s, sm, 2, out, chosen)
	return out


func _all_in(list: Array[Clip], chosen: Dictionary) -> bool:
	if list.is_empty():
		return false
	for c: Clip in list:
		if not chosen.has(c.id):
			return false
	return true


func _clip_rows(s: Sequence, list: Array[Clip], depth: int, out: Array[Dictionary], chosen: Dictionary) -> void:
	var sorted: Array[Clip] = list.duplicate()
	sorted.sort_custom(func(a: Clip, b: Clip) -> bool: return a.start < b.start or (is_equal_approx(a.start, b.start) and s.track_index(s.track_of(a.id).id) < s.track_index(s.track_of(b.id).id)))
	for c: Clip in sorted:
		var tr: Track = s.track_of(c.id)
		out.append({"key": row_key("clip", c.id), "kind": "clip", "gid": c.group_id, "clip": c.id, "depth": depth, "title": c.label if not c.label.is_empty() else "(unnamed)", "track": tr.label if tr != null else "", "meta": short_time(c.start), "colour": -2, "fold": false, "open": false, "sel": chosen.has(c.id)})


func rebuild() -> void:
	if not _alive():
		return
	_queued = false
	if not _root.is_visible_in_tree() and _list.get_child_count() > 0:
		_dirty = true
		return
	_dirty = false
	var s: Sequence = seq()
	rows = plan(s)
	PmUI.keep_scroll(_list)
	PmUI.clear(_list)
	_row_nodes = {}
	for r: Dictionary in rows:
		var node: Control = _Row.new()
		node.set("panel", self)
		node.set("data", r)
		node.custom_minimum_size = Vector2(0.0, float(Tk.px(CLIP_ROW_H if String(r["kind"]) == "clip" else ROW_H)))
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PmUI.tip(node, _row_tip(r))
		if String(r["kind"]) != "clip":
			var slot: Control = PmSlot.make(PackedStringArray(["effect"]))
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.set("draw_highlight", false)
			slot.set("can_accept_cb", _accepts.bind(String(r["key"])))
			slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			slot.connect("hover_changed", _on_drop_hover.bind(String(r["key"]), String(r["gid"])))
			slot.connect("dropped", _on_dropped.bind(String(r["gid"])))
			node.add_child(slot)
		_list.add_child(node)
		_row_nodes[String(r["key"])] = node
	if rows.is_empty():
		var msg: String = "Open a sequence to see its groups" if s == null else ("No groups match" if not filter.is_empty() else "No groups in this sequence")
		var box: VBoxContainer = PmUI.vbox(6)
		box.add_child(PmLabel.dim(msg))
		if s != null and filter.is_empty():
			var more: Label = PmLabel.faint("Pick two or more clips and press " + Cmd.keys_text("clip.group") + ". A cut through a group makes each side a slice of it.")
			more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			more.custom_minimum_size = Vector2(60.0, 0.0)
			box.add_child(more)
		_list.add_child(PmUI.inset(box, 12.0))
	_update_foot()
	if not flash_key.is_empty() and _row_nodes.has(flash_key):
		call_deferred("_show_flash")


func _show_flash() -> void:
	if not _alive() or not _row_nodes.has(flash_key):
		return
	var target: Control = _row_nodes[flash_key]
	if is_instance_valid(target) and target.is_inside_tree() and _scroll.is_ancestor_of(target):
		_scroll.ensure_control_visible(target)


func _row_tip(r: Dictionary) -> String:
	var kind: String = String(r["kind"])
	if kind == "group":
		return String(r["title"]) + ". Click to pick the whole group, double click to rename, right click for more. " + HINT
	if kind == "slice":
		return String(r["title"]) + ". Click to pick this slice, double click to rename, right click for more. Drop an effect here to put it on every clip of the slice."
	return String(r["title"]) + " on " + String(r.get("track", "")) + ". Click to pick it."


func _update_foot() -> void:
	if _foot == null:
		return
	if not drop_note.is_empty():
		_foot.text = drop_note
		PmLabel.set_colour(_foot, "text")
		return
	PmLabel.set_colour(_foot, "text_dim")
	var s: Sequence = seq()
	if s == null:
		_foot.text = ""
		return
	var groups: int = GroupTree.roots(s).size()
	var slices: int = 0
	for root: String in GroupTree.roots(s):
		slices += GroupTree.slices_of(s, root).size()
	if groups == 0:
		_foot.text = ""
		return
	_foot.text = ("%d group" % groups if groups == 1 else "%d groups" % groups) + (", %d slices. " % slices if slices > 0 else ". ") + HINT


func _queue() -> void:
	if _queued or not _alive():
		return
	_queued = true
	if not _root.get_tree().process_frame.is_connected(rebuild):
		_root.get_tree().process_frame.connect(rebuild, CONNECT_ONE_SHOT)


func _on_doc_changed(kind: String) -> void:
	if not QUIET_KINDS.has(kind):
		_queue()


func _on_history() -> void:
	_queue()


func _on_project_changed() -> void:
	_glow_off()
	rebuild()


func _on_sequence_changed(_id: String) -> void:
	_glow_off()
	rebuild()


func row_by_key(key: String) -> Dictionary:
	for r: Dictionary in rows:
		if String(r["key"]) == key:
			return r
	return {}


func ids_of_row(r: Dictionary) -> PackedStringArray:
	var s: Sequence = seq()
	if s == null or r.is_empty():
		return PackedStringArray()
	if String(r["kind"]) == "clip":
		return PackedStringArray([String(r["clip"])])
	return GroupTree.member_ids(s, String(r["gid"]))


func colour_of_row(r: Dictionary) -> Color:
	var s: Sequence = seq()
	var ci: int = int(r.get("colour", -1))
	if ci == -2 and s != null:
		ci = int(s.group_record(String(r["gid"])).get("colour", -1))
	return Tk.label_colour(ci) if ci >= 0 else Tk.c["text_dim"]


func _canvas() -> Control:
	var tl: Object = bus().panel("timeline")
	if tl == null:
		return null
	var cv: Variant = tl.get("canvas")
	return cv as Control if cv is Control else null


func _redraw_timeline() -> void:
	var cv: Control = _canvas()
	if cv != null and is_instance_valid(cv):
		cv.queue_redraw()


func hover_row(key: String, on: bool) -> void:
	if on:
		hover_key = key
		var r: Dictionary = row_by_key(key)
		Glow.light(ids_of_row(r), colour_of_row(r), GLOW_OWNER)
	elif hover_key == key:
		hover_key = ""
		Glow.clear(GLOW_OWNER)
	_redraw_timeline()
	_redraw_rows()


func _glow_off() -> void:
	hover_key = ""
	drop_key = ""
	drop_note = ""
	Glow.clear(GLOW_OWNER)
	_redraw_timeline()


func _redraw_rows() -> void:
	for n: Variant in _row_nodes.values():
		if n is Control and is_instance_valid(n):
			(n as Control).queue_redraw()


func toggle(key: String) -> void:
	var r: Dictionary = row_by_key(key)
	if r.is_empty() or not bool(r["fold"]):
		return
	open[key] = not bool(r["open"])
	rebuild()


func click_row(key: String, add: bool) -> bool:
	var r: Dictionary = row_by_key(key)
	var d: Project = doc()
	var s: Sequence = seq()
	if r.is_empty() or d == null or s == null:
		return false
	if String(r["kind"]) == "clip":
		var one: PackedStringArray = PackedStringArray([String(r["clip"])])
		return Verbs.select(d, s, Verbs.MoveRule.pick(s, one, Verbs.MoveRule.linked_on()), "add" if add else "replace", Verbs.MoveRule.picked_after(s, one, add))
	return GroupTree.select(d, s, String(r["gid"]), add)


func menu_for(key: String) -> Array:
	var r: Dictionary = row_by_key(key)
	var s: Sequence = seq()
	if r.is_empty() or s == null:
		return []
	var kind: String = String(r["kind"])
	if kind == "clip":
		return [PmMenu.item("select", "Select this clip"), PmMenu.item("goto", "Go to it")]
	var gid: String = String(r["gid"])
	var cur: int = int(s.group_record(gid).get("colour", -1))
	var colours: Array = [PmMenu.check_item("colour:-1", "None", cur < 0)]
	var with_clips: Array = [PmMenu.item("colour_all:-1", "None")]
	for i: int in Tk.LABEL_NAMES.size():
		colours.append(PmMenu.check_item("colour:" + str(i), Tk.label_name(i), cur == i))
		with_clips.append(PmMenu.item("colour_all:" + str(i), Tk.label_name(i)))
	if kind == "slice":
		return [
			PmMenu.item("select", "Select this slice"),
			PmMenu.item("select_whole", "Select the whole group"),
			PmMenu.item("rename", "Rename this slice"),
			PmMenu.sub_item("colour", "Colour this slice", colours),
			PmMenu.sub_item("colour_all", "Colour this slice and its clips", with_clips),
			PmMenu.item("goto", "Go to its start"),
			PmMenu.separator(),
			PmMenu.item("ungroup", "Ungroup this slice"),
		]
	var sliced: bool = not GroupTree.slices_of(s, gid).is_empty()
	return [
		PmMenu.item("select_whole", "Select the whole group"),
		PmMenu.item("rename", "Rename"),
		PmMenu.sub_item("colour", "Colour", colours),
		PmMenu.sub_item("colour_all", "Colour the group and its clips", with_clips),
		PmMenu.item("goto", "Go to its start"),
		PmMenu.separator(),
		PmMenu.item("ungroup", "Ungroup (every slice)" if sliced else "Ungroup"),
	]


func open_menu(key: String, at: Vector2) -> void:
	var items: Array = menu_for(key)
	if items.is_empty() or not _alive():
		return
	var m: Control = PmMenu.open(_root, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", on_menu.bind(key))


func on_menu(id: String, key: String) -> bool:
	var r: Dictionary = row_by_key(key)
	var d: Project = doc()
	var s: Sequence = seq()
	if r.is_empty() or d == null or s == null:
		return false
	var gid: String = String(r["gid"])
	if id == "select":
		return click_row(key, false)
	if id == "select_whole":
		return GroupTree.select(d, s, GroupTree.root_of(s, gid))
	if id == "goto":
		var ids: PackedStringArray = ids_of_row(r)
		var t0: float = INF
		for cid: String in ids:
			var c: Clip = s.clip_by_id(cid)
			if c != null:
				t0 = minf(t0, c.start)
		if t0 < INF:
			Session.set_playhead(t0)
		return t0 < INF
	if id == "rename":
		ask_rename(gid)
		return true
	if id.begins_with("colour_all:"):
		return GroupTree.recolour(d, s, gid, int(id.substr(11)), true)
	if id.begins_with("colour:"):
		return GroupTree.recolour(d, s, gid, int(id.substr(7)), false)
	if id == "ungroup":
		return GroupTree.ungroup(d, s, gid)
	return false


func ask_rename(gid: String) -> void:
	var s: Sequence = seq()
	if s == null or not _alive():
		return
	var slice: bool = GroupTree.is_slice(s, gid)
	var fields: Array[Dictionary] = [{"key": "name", "label": "Name", "type": "string", "default": GroupTree.title(s, gid)}]
	var answered: Signal = PmUI.form(_root, "Rename slice" if slice else "Rename group", fields, "Rename", "Cancel")
	answered.connect(_on_renamed.bind(gid))


func _on_renamed(result: Variant, gid: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	GroupTree.rename(doc(), seq(), gid, String((result as Dictionary).get("name", "")))


func reveal(gid: String) -> void:
	var s: Sequence = seq()
	if s == null:
		return
	var root: String = GroupTree.root_of(s, gid)
	open[row_key("group", root)] = true
	if GroupTree.is_slice(s, gid):
		open[row_key("slice", gid)] = true
		flash_key = row_key("slice", gid)
	else:
		flash_key = row_key("group", root)
	rebuild()


func _accepts(payload: Dictionary, key: String) -> bool:
	drop_payload = payload
	return String(payload.get("kind", "")) == "effect" and not row_by_key(key).is_empty()


func effect_def(payload: Dictionary) -> Dictionary:
	var fx: Object = bus().panel("effects")
	if fx == null or not fx.has_method("def_for"):
		return {}
	return fx.call("def_for", String(payload.get("id", "")))


func drop_hint(gid: String, def: Dictionary) -> String:
	var s: Sequence = seq()
	if s == null or def.is_empty():
		return ""
	var n: int = GroupTree.effect_targets(s, gid, def).size()
	var name_: String = GroupTree.title(s, gid)
	var fx_name: String = String(def.get("label", def.get("id", "the effect")))
	if n == 0:
		return "Nothing in %s can take a %s effect" % [name_, "sound" if bool(def.get("audio", false)) else "picture"]
	return "Drop to put %s on %s of %s" % [fx_name, "1 clip" if n == 1 else "%d clips" % n, name_]


func _on_drop_hover(on: bool, key: String, gid: String) -> void:
	var s: Sequence = seq()
	if on and s != null:
		drop_key = key
		var def: Dictionary = effect_def(drop_payload)
		drop_note = drop_hint(gid, def)
		var r: Dictionary = row_by_key(key)
		Glow.light(GroupTree.effect_targets(s, gid, def) if not def.is_empty() else ids_of_row(r), colour_of_row(r), GLOW_OWNER)
	elif drop_key == key:
		drop_key = ""
		drop_note = ""
		Glow.clear(GLOW_OWNER)
	_update_foot()
	_redraw_rows()
	_redraw_timeline()


func _on_dropped(payload: Dictionary, _local: Vector2, gid: String) -> void:
	_glow_off()
	_update_foot()
	drop_effect_def(gid, effect_def(payload))


func drop_effect_def(gid: String, def: Dictionary) -> int:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or def.is_empty():
		return 0
	var n: int = GroupTree.apply_effect(d, s, gid, def)
	if n == 0:
		Events.toast("Nothing in %s can take a %s effect" % [GroupTree.title(s, gid), "sound" if bool(def.get("audio", false)) else "picture"])
	else:
		Events.toast("Put %s on %s of %s" % [String(def.get("label", "the effect")), "1 clip" if n == 1 else "%d clips" % n, GroupTree.title(s, gid)])
	return n


func handle_key(e: InputEventKey) -> bool:
	if e.pressed and e.keycode == KEY_ESCAPE and not filter.is_empty():
		_search.text = ""
		_on_filter("")
		return true
	return false


class _Row:
	extends Control

	var panel: Object = null
	var data: Dictionary = {}
	var _hover: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_leave)

	func _key() -> String:
		return String(data.get("key", ""))

	func _on_enter() -> void:
		_hover = true
		if panel != null:
			panel.call("hover_row", _key(), true)
		queue_redraw()

	func _on_leave() -> void:
		_hover = false
		if panel != null:
			panel.call("hover_row", _key(), false)
		queue_redraw()

	func _indent() -> float:
		return float(Tk.px(6.0)) + float(int(data.get("depth", 0))) * float(Tk.px(18.0))

	func _chev_rect() -> Rect2:
		var s: float = float(Tk.px(12.0))
		return Rect2(_indent(), (size.y - s) * 0.5, s, s)

	func _on_input(event: InputEvent) -> void:
		if panel == null:
			return
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if not mb.pressed:
				return
			if mb.button_index == MOUSE_BUTTON_LEFT:
				accept_event()
				if bool(data.get("fold", false)) and _chev_rect().grow(float(Tk.px(4.0))).has_point(mb.position):
					panel.call("toggle", _key())
					return
				if mb.double_click and String(data.get("kind", "")) != "clip":
					panel.call("ask_rename", String(data.get("gid", "")))
					return
				panel.call("click_row", _key(), mb.shift_pressed or mb.ctrl_pressed)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				accept_event()
				panel.call("open_menu", _key(), mb.global_position)

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var key: String = _key()
		var dropping: bool = panel != null and String(panel.get("drop_key")) == key
		if dropping:
			draw_rect(r, Color(Tk.c["accent"], 0.12), true)
			draw_rect(r.grow(-1.0), Tk.c["accent"], false, 1.0)
		elif bool(data.get("sel", false)):
			draw_rect(r, Tk.c["selection_fill"], true)
		if _hover and not dropping:
			draw_rect(r, Tk.c["glass"], true)
		if panel != null and String(panel.get("flash_key")) == key:
			draw_rect(Rect2(0.0, 0.0, float(Tk.px(2.0)), size.y), Tk.c["accent"], true)
		var font: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_small" if String(data.get("kind", "")) == "clip" else "font_body"))
		var x: float = _indent()
		var mid: float = size.y * 0.5
		if bool(data.get("fold", false)):
			Icons.draw(self, "chev_d" if bool(data.get("open", false)) else "chev_r", _chev_rect(), Tk.c["text_faint"])
		x += float(Tk.px(16.0))
		var kind: String = String(data.get("kind", ""))
		var col: Color = panel.call("colour_of_row", data) if panel != null else Tk.c["text_dim"]
		var sw: float = float(Tk.px(10.0))
		if kind == "group":
			draw_rect(Rect2(x, mid - sw * 0.5, sw, sw), col, true)
			x += sw + float(Tk.px(6.0))
		elif kind == "slice":
			draw_rect(Rect2(x + 1.0, mid - sw * 0.5 + 1.0, sw - 2.0, sw - 2.0), col, false, 2.0)
			x += sw + float(Tk.px(6.0))
		else:
			var tw: float = float(Tk.px(24.0))
			PmText.draw_in(self, Tk.font("mono"), Rect2(x, 0.0, tw, size.y), String(data.get("track", "")), Tk.fs(Tk.sz("font_tiny")), Tk.c["text_faint"])
			x += tw + float(Tk.px(4.0))
		var pad: float = PmText.pad()
		var meta: String = String(data.get("meta", ""))
		var meta_fs: int = Tk.fs(Tk.sz("font_tiny"))
		var mono: Font = Tk.font("mono")
		var meta_w: float = PmText.width_of(mono, meta, meta_fs) if not meta.is_empty() else 0.0
		var name_room: float = size.x - x - pad
		var show_meta: bool = meta_w > 0.0 and name_room - meta_w - pad * 2.0 > float(Tk.px(60.0))
		if show_meta:
			name_room -= meta_w + pad * 2.0
			PmText.draw_in(self, mono, Rect2(size.x - pad - meta_w, 0.0, meta_w, size.y), meta, meta_fs, Tk.c["text_faint"])
		var ink: Color = Tk.c["text_bright"] if kind == "group" else (Tk.c["text"] if kind == "slice" else Tk.c["text_dim"])
		PmText.draw_in(self, font, Rect2(x, 0.0, maxf(name_room, 0.0), size.y), String(data.get("title", "")), fs, ink)

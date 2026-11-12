extends RefCounted

const Clip := preload("res://doc/clip.gd")
const EffectGroups := preload("res://doc/effect_groups.gd")
const PanelBase := preload("res://modules/core_panels/panel_base.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const META_GROUP := "fx_group"
const M_RENAME := "group_rename"
const M_UNGROUP := "group_ungroup"
const M_REMOVE := "group_remove"

static var closed: Dictionary = {}


static func before(panel: Object, list: Control, c: Clip, entries: Array, index: int, sound: bool) -> Control:
	if not EffectGroups.starts_run(entries, index):
		return null
	var e: Dictionary = entries[index]
	var gid: String = EffectGroups.group_of(e)
	var count: int = EffectGroups.run_at(entries, index).size()
	var head: PanelContainer = header(panel, c, gid, EffectGroups.label_of(e), count, sound)
	list.add_child(head)
	return head


static func key(c: Clip, entries: Array, index: int, sound: bool) -> String:
	if not EffectGroups.in_shown_group(entries, index):
		return "g:-"
	var gid: String = EffectGroups.group_of(entries[index])
	var out: String = "g:" + gid + ":" + str(closed.has(gid))
	if EffectGroups.starts_run(entries, index):
		out += ":head:" + (c.id if c != null else "") + ":" + EffectGroups.label_of(entries[index]) + ":" + str(EffectGroups.run_at(entries, index).size()) + ":" + str(EffectGroups.all_on(c, gid, sound))
	return out


static func refold(list: Control) -> void:
	if list == null:
		return
	for child: Node in list.get_children():
		if child.has_meta(META_GROUP) and child is CanvasItem and closed.has(String(child.get_meta(META_GROUP))):
			(child as CanvasItem).visible = false


static func after(list: Control, entries: Array, index: int, at: int) -> void:
	if not EffectGroups.in_shown_group(entries, index) or at < 0 or at >= list.get_child_count():
		return
	var bar: Control = list.get_child(at) as Control
	if bar == null:
		return
	var gid: String = EffectGroups.group_of(entries[index])
	bar.set_meta(META_GROUP, gid)
	if bar is PanelContainer:
		var sb: StyleBox = (bar as PanelContainer).get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			var own: StyleBoxFlat = (sb as StyleBoxFlat).duplicate()
			own.border_width_left = 3
			own.border_color = Tk.c["sol"]
			own.content_margin_left = float(Tk.px(10.0))
			(bar as PanelContainer).add_theme_stylebox_override("panel", own)
	bar.visible = not closed.has(gid)


static func header(panel: Object, c: Clip, gid: String, label: String, count: int, sound: bool) -> PanelContainer:
	var bar: PanelContainer = PmUI.panel("bg_panel")
	bar.name = "EffectGroup"
	bar.set_meta(META_GROUP + "_head", gid)
	var sb: StyleBox = bar.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		var own: StyleBoxFlat = (sb as StyleBoxFlat).duplicate()
		own.border_width_left = 3
		own.border_color = Tk.c["sol"]
		own.content_margin_left = float(Tk.px(4.0))
		own.content_margin_top = float(Tk.px(2.0))
		own.content_margin_bottom = float(Tk.px(2.0))
		bar.add_theme_stylebox_override("panel", own)
	var row: HBoxContainer = PmUI.hbox()
	bar.add_child(row)
	var fold: Button = PanelBase.quiet_icon("chev_r" if closed.has(gid) else "chev_d", "Fold the group away, or open it")
	fold.name = "GroupFold"
	fold.pressed.connect(func() -> void: toggle_fold(panel, gid))
	row.add_child(fold)
	var name_l: Label = PmLabel.trim(label)
	name_l.name = "GroupName"
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.mouse_filter = Control.MOUSE_FILTER_STOP
	name_l.tooltip_text = "Effects applied together from a preset. Right click to rename or ungroup them."
	name_l.gui_input.connect(func(ev: InputEvent) -> void: _on_input(ev, panel, name_l, c.id, gid, sound))
	row.add_child(name_l)
	var n_l: Label = PmLabel.dim(str(count) + " effects")
	row.add_child(n_l)
	var on: bool = EffectGroups.all_on(c, gid, sound)
	var bypass: Button = PanelBase.toggle_icon("check", "Every effect in the group on or off together", on)
	bypass.name = "GroupBypass"
	bypass.pressed.connect(func() -> void: EffectGroups.toggle(panel.call("doc"), panel.call("seq"), c.id, gid, sound))
	row.add_child(bypass)
	var ungroup: Button = PanelBase.quiet_icon("link", "Ungroup: keep the effects, drop the group")
	ungroup.name = "GroupUngroup"
	ungroup.pressed.connect(func() -> void: EffectGroups.ungroup(panel.call("doc"), panel.call("seq"), c.id, gid, sound))
	row.add_child(ungroup)
	var trash: Button = PanelBase.quiet_icon("trash", "Remove every effect in the group")
	trash.name = "GroupTrash"
	trash.pressed.connect(func() -> void: EffectGroups.remove(panel.call("doc"), panel.call("seq"), c.id, gid, sound))
	row.add_child(trash)
	return bar


static func toggle_fold(panel: Object, gid: String) -> void:
	if closed.has(gid):
		closed.erase(gid)
	else:
		closed[gid] = true
	if panel != null and panel.has_method("rebuild"):
		panel.call("rebuild")


static func _on_input(ev: InputEvent, panel: Object, anchor: Control, clip_id: String, gid: String, sound: bool) -> void:
	if not (ev is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = ev
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
		toggle_fold(panel, gid)
		anchor.accept_event()
		return
	if mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	anchor.accept_event()
	var items: Array = [PmMenu.item(M_RENAME, "Rename the group..."), PmMenu.item(M_UNGROUP, "Ungroup"), PmMenu.separator(), PmMenu.item(M_REMOVE, "Remove the group")]
	var m: Control = PmMenu.open(anchor, items, mb.global_position)
	if m != null and m.is_inside_tree():
		m.connect("picked", func(id: String) -> void: on_menu(panel, anchor, id, clip_id, gid, sound))


static func on_menu(panel: Object, anchor: Control, id: String, clip_id: String, gid: String, sound: bool) -> void:
	if id == M_UNGROUP:
		EffectGroups.ungroup(panel.call("doc"), panel.call("seq"), clip_id, gid, sound)
	elif id == M_REMOVE:
		EffectGroups.remove(panel.call("doc"), panel.call("seq"), clip_id, gid, sound)
	elif id == M_RENAME:
		var fields: Array[Dictionary] = [{"key": "label", "label": "Name", "type": "string", "default": anchor.get("text") if anchor is Label else ""}]
		var answered: Signal = PmUI.form(anchor, "Rename the group", fields, "Rename", "Cancel")
		answered.connect(func(result: Variant) -> void:
			if result is Dictionary and not (result as Dictionary).is_empty():
				EffectGroups.rename(panel.call("doc"), panel.call("seq"), clip_id, gid, sound, String((result as Dictionary).get("label", "")))
		)

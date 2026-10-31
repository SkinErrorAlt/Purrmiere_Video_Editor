extends RefCounted

const Clip := preload("res://doc/clip.gd")
const ViewMap := preload("res://doc/view_map.gd")
const RegionFx := preload("res://doc/region_fx.gd")
const RegionFxCmds := preload("res://doc/commands/region_fx_cmds.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const WHOLE := "Whole clip"
const WHOLE_TIP := "Move this effect back to the whole picture, after the Pair View"
const REMOVE_TIP := "Remove this effect"
const OFF_SUFFIX := " (off)"
const ROW_META := "region_fx_uid"
const WHOLE_ID := "region:whole"
const WHOLE_ITEM := "Apply to the whole clip"
const DOT_PX := 7.0
const NAME_PX := 150.0


static func hides_mask(c: Clip, mask: Dictionary) -> bool:
	return c != null and not RegionFx.mask_link(mask).is_empty()


static func chip_text(c: Clip, e: Dictionary) -> String:
	var link: Dictionary = RegionFx.link_of(c, e)
	if link.is_empty():
		return ""
	return "Region: " + RegionFx.region_name(RegionFx.live_pair(c, String(link["pv"])), int(link["index"]))


static func menu_items(c: Clip, uid: String) -> Array:
	if c == null or RegionFx.link_of(c, c.effect_by_uid(uid)).is_empty():
		return []
	return [PmMenu.item(WHOLE_ID, WHOLE_ITEM), PmMenu.separator()]


static func picked(id: String, clip_id: String, uid: String) -> bool:
	if id != WHOLE_ID:
		return false
	RegionFxCmds.to_whole(Session.doc, Session.seq(), clip_id, uid)
	return true


static func view_colour(c: Clip, pv_uid: String, index: int) -> Color:
	return Tk.label_colour(ViewMap.colour_for(ViewMap.of(RegionFx.live_pair(c, pv_uid)), index))


static func make(c: Clip, pv_uid: String, index: int, indent: float) -> Control:
	var box: VBoxContainer = PmUI.vbox(0)
	box.name = "RegionFx" + str(index)
	var list: Array[Dictionary] = RegionFx.effects_on(c, pv_uid, index)
	if list.is_empty():
		box.visible = false
		return box
	var colour: Color = view_colour(c, pv_uid, index)
	var clip_id: String = c.id
	for fx: Dictionary in list:
		var uid: String = String(fx.get("uid", ""))
		var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		row.set_meta(ROW_META, uid)
		var lead: Control = Control.new()
		lead.custom_minimum_size = Vector2(indent, 0.0)
		lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lead)
		var dot: ColorRect = ColorRect.new()
		dot.color = colour
		dot.custom_minimum_size = Vector2(float(Tk.px(DOT_PX)), float(Tk.px(DOT_PX)))
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
		var def: Dictionary = EffectSource.get_def(String(fx.get("id", "")))
		var on: bool = bool(fx.get("enabled", true))
		var name: Label = PmLabel.trim(String(def.get("label", fx.get("id", ""))) + ("" if on else OFF_SUFFIX), "text" if on else "text_dim")
		name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		name.custom_minimum_size.x = float(Tk.px(NAME_PX))
		row.add_child(name)
		var whole: Button = PmButton.make(WHOLE)
		PmUI.tip(whole, WHOLE_TIP)
		whole.pressed.connect(func() -> void: RegionFxCmds.to_whole(Session.doc, Session.seq(), clip_id, uid))
		row.add_child(whole)
		var del: Button = PmButton.make("", "trash")
		del.set("quiet", true)
		PmUI.tip(del, REMOVE_TIP)
		del.pressed.connect(func() -> void: RegionFxCmds.remove(Session.doc, Session.seq(), clip_id, uid))
		row.add_child(del)
		row.add_child(PmUI.spacer())
		box.add_child(row)
	return box

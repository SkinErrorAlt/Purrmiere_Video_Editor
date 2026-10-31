extends RefCounted

const SELF := preload("res://modules/core_panels/many_buttons.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmSlot := preload("res://ui/kit/pm_slot.gd")
const PmDragLayer := preload("res://ui/kit/pm_drag_layer.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const PvCmds := preload("res://doc/commands/pair_cmds.gd")
const StreamRoles := preload("res://doc/stream_roles.gd")
const MaskShape := preload("res://doc/mask_shape.gd")
const ViewMap := preload("res://doc/view_map.gd")
const ViewSwitch := preload("res://doc/view_switch.gd")
const PairCmds := preload("res://doc/commands/pair_cmds.gd")
const LayerChain := preload("res://engine/layer_chain.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const EffectOps := preload("res://modules/core_panels/effect_ops.gd")
const PvCuts := preload("res://modules/core_panels/pair_view_cuts.gd")
const PvSync := preload("res://modules/core_panels/pair_sync.gd")
const PairLayouts := preload("res://modules/core_panels/pair_layouts.gd")
const NestControls := preload("res://modules/core_panels/nest_controls.gd")
const KeyEditor := preload("res://ui/timeline/keyframe_editor.gd")
const RegionFx := preload("res://doc/region_fx.gd")
const RegionFxCmds := preload("res://doc/commands/region_fx_cmds.gd")
const PvStreamRows := preload("res://modules/core_panels/view_stream_rows.gd")
const PvCropRows := preload("res://modules/core_panels/pv_crop_rows.gd")
const PvGroups := preload("res://modules/core_panels/pv_groups.gd")
const PvAudio := preload("res://modules/core_panels/pv_audio.gd")
const MonitorHandles := preload("res://modules/core_panels/monitor_handles.gd")
const REGION_MAX := 8
const ONE_REGION_NOTE := "Names, sizes, Place and Hears: select one clip"
const SYNC_TIP := "Select one clip to line up its regions on their own timeline"
const NEST_CHECKS: Array = [["hear_audio", "Hear audio", "Play the nests' sound in this sequence and in exports"], ["show_audio_below", "Show audio below", "Draw the nests' audio tracks under this sequence's own"], ["see_inside", "See inside", "Draw the nests' tracks inside the clips"]]


static func _doc(panel: Object) -> Project:
	return panel.call("doc")


static func _seq(panel: Object) -> Sequence:
	return panel.call("seq")


static func _gap(w: float) -> Control:
	var sp: Control = Control.new()
	sp.custom_minimum_size = Vector2(w, 0.0)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp


static func _lead_w() -> float:
	return float(Tk.px(Tk.sz("button_h")))


static func _quiet(text: String, icon: String, tip: String) -> Button:
	var b: Button = PmButton.make(text, icon)
	b.set("quiet", true)
	if not tip.is_empty():
		PmUI.tip(b, tip)
	return b


static func _icon(icon: String, tip: String) -> Button:
	var b: Button = PmButton.make("", icon)
	b.set("quiet", true)
	PmUI.tip(b, tip)
	return b


static func _clips_of(s: Sequence, uids: Dictionary) -> Array[Clip]:
	var out: Array[Clip] = []
	if s == null:
		return out
	for cid: Variant in uids.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c != null:
			out.append(c)
	return out


static func _index_of(c: Clip, uid: String, sound: bool) -> int:
	var list: Array = c.audio_effects() if sound else c.effects
	for i: int in list.size():
		if String((list[i] as Dictionary).get("uid", "")) == uid:
			return i
	return -1


static func _run_each(d: Project, label: String, work: Callable) -> bool:
	if d == null:
		return false
	var tx: RefCounted = d.undo.begin(label)
	var before: int = (tx.get("commands") as Array).size()
	work.call()
	var any: bool = (tx.get("commands") as Array).size() > before
	tx.call("commit")
	return any


static func effect_header(panel: Object, f: VBoxContainer, g: Dictionary, sound: bool) -> void:
	var s: Sequence = _seq(panel)
	var uids: Dictionary = (g["uids"] as Dictionary).duplicate()
	var header: Button = f.get("header")
	header.gui_input.connect(Callable(SELF, "_on_header_input").bind(panel, uids, sound, header))
	PmUI.tip(header, "Right click for copy, paste, duplicate and reset, for every selected clip that has it")
	if not sound:
		MonitorHandles.add_switch_many(f, _clips_of(s, uids), uids)
	var can_up: bool = false
	var can_down: bool = false
	for c: Clip in _clips_of(s, uids):
		var at: int = _index_of(c, String(uids[c.id]), sound)
		var n: int = (c.audio_effects() if sound else c.effects).size()
		can_up = can_up or at > 0
		can_down = can_down or (at >= 0 and at < n - 1)
	var up: Button = _icon("chev_u", "Move it earlier in every clip that has it, so it runs before the ones above it")
	up.name = "ManyUp"
	up.disabled = not can_up
	up.pressed.connect(Callable(SELF, "step").bind(panel, uids, sound, -1))
	f.call("add_right", up)
	var down: Button = _icon("chev_d", "Move it later in every clip that has it, so it runs after the ones below it")
	down.name = "ManyDown"
	down.disabled = not can_down
	down.pressed.connect(Callable(SELF, "step").bind(panel, uids, sound, 1))
	f.call("add_right", down)
	var grip: Button = _icon("list", "Drag onto another effect to move it there in every clip that has both")
	grip.name = "ManyGrip"
	grip.set("icon_px", 12.0)
	grip.mouse_default_cursor_shape = Control.CURSOR_MOVE
	grip.gui_input.connect(Callable(SELF, "_on_grip_input").bind(panel, uids, sound, grip))
	f.call("add_right", grip)
	if not sound:
		var chip: Button = _quiet(mask_chip_text(s, uids), "", "Which mask this effect works inside, by its place in each clip's masks")
		chip.name = "ManyMaskChip"
		chip.pressed.connect(Callable(SELF, "_on_mask_chip").bind(panel, uids, chip))
		f.call("add_right", chip)
	var slot: Control = PmSlot.make(PackedStringArray(["effect_reorder"]))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.connect("dropped", Callable(SELF, "_on_reorder_drop").bind(panel, uids, sound))
	header.add_child(slot)


static func step(panel: Object, uids: Dictionary, sound: bool, dir: int) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var cmds: Array[Command] = []
	for c: Clip in _clips_of(s, uids):
		var uid: String = String(uids[c.id])
		var at: int = _index_of(c, uid, sound)
		var to: int = at + dir
		var n: int = (c.audio_effects() if sound else c.effects).size()
		if at < 0 or to < 0 or to >= n:
			continue
		cmds.append(EffectCmds.ReorderEffect.new(s.id, c.id, uid, to, sound))
	return Verbs.run(d, "Move effect " + ("up" if dir < 0 else "down"), cmds)


static func _on_grip_input(event: InputEvent, panel: Object, uids: Dictionary, sound: bool, grip: Control) -> void:
	if not (event is InputEventMouseMotion) or (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
		return
	var layer: CanvasLayer = PmDragLayer.find(panel.call("root"))
	if layer == null or bool(layer.get("active")):
		return
	var ghost: Label = PmLabel.tight("Move effect", "text_bright")
	layer.call("begin", {"kind": "effect_reorder", "many_uids": uids, "sound": sound}, ghost, Vector2(8.0, 8.0))
	grip.accept_event()


static func _on_reorder_drop(payload: Dictionary, _local: Vector2, panel: Object, target: Dictionary, sound: bool) -> void:
	var moving: Variant = payload.get("many_uids", null)
	if not (moving is Dictionary):
		return
	reorder_onto(panel, moving, target, sound)


static func reorder_onto(panel: Object, moving: Dictionary, target: Dictionary, sound: bool) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var cmds: Array[Command] = []
	for c: Clip in _clips_of(s, moving):
		if not target.has(c.id) or String(target[c.id]) == String(moving[c.id]):
			continue
		var to: int = _index_of(c, String(target[c.id]), sound)
		if to >= 0:
			cmds.append(EffectCmds.ReorderEffect.new(s.id, c.id, String(moving[c.id]), to, sound))
	return Verbs.run(d, "Reorder effect", cmds)


static func mask_chip_text(s: Sequence, uids: Dictionary) -> String:
	var seen: PackedStringArray = PackedStringArray()
	for c: Clip in _clips_of(s, uids):
		var mid: String = String(c.effect_by_uid(String(uids[c.id])).get("mask", ""))
		var at: int = MaskShape.index_of(c.masks, mid) if not mid.is_empty() else -1
		var text: String = "none" if at < 0 else "Mask " + str(at + 1)
		if not seen.has(text):
			seen.append(text)
	if seen.size() == 1:
		return "Mask: " + seen[0]
	return "Mask: mixed"


static func mask_menu_items(s: Sequence, uids: Dictionary) -> Array:
	var most: int = 0
	var none_all: bool = true
	var at_all: Dictionary = {}
	for c: Clip in _clips_of(s, uids):
		most = maxi(most, c.masks.size())
		var mid: String = String(c.effect_by_uid(String(uids[c.id])).get("mask", ""))
		var at: int = MaskShape.index_of(c.masks, mid) if not mid.is_empty() else -1
		none_all = none_all and at < 0
		at_all[at] = true
	var items: Array = [PmMenu.check_item("many_mask:", "None", none_all)]
	for n: int in most:
		items.append(PmMenu.check_item("many_mask:" + str(n), "Mask " + str(n + 1), at_all.size() == 1 and at_all.has(n)))
	return items


static func _on_mask_chip(panel: Object, uids: Dictionary, anchor: Control) -> void:
	var m: Control = PmMenu.open(anchor, mask_menu_items(_seq(panel), uids))
	if m != null and m.is_inside_tree():
		m.connect("picked", Callable(SELF, "set_mask").bind(panel, uids))


static func set_mask(id: String, panel: Object, uids: Dictionary) -> bool:
	if not id.begins_with("many_mask:"):
		return false
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var want: String = id.substr(10)
	var cmds: Array[Command] = []
	for c: Clip in _clips_of(s, uids):
		var mid: String = ""
		if not want.is_empty():
			var n: int = int(want)
			if n >= c.masks.size():
				continue
			mid = String(c.masks[n].get("id", ""))
		if String(c.effect_by_uid(String(uids[c.id])).get("mask", "")) == mid:
			continue
		cmds.append(EffectCmds.SetMask.new(s.id, c.id, String(uids[c.id]), mid))
	return Verbs.run(d, "Set mask", cmds)


static func _on_header_input(event: InputEvent, panel: Object, uids: Dictionary, sound: bool, header: Control) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			header.accept_event()
			var m: Control = PmMenu.open(header, header_menu_items(), header.get_global_mouse_position())
			if m != null and m.is_inside_tree():
				m.connect("picked", Callable(SELF, "header_menu_picked").bind(panel, uids, sound))


static func header_menu_items() -> Array:
	var items: Array = [PmMenu.item("fx_copy", "Copy effect (from the first selected clip)")]
	var paste: Dictionary = PmMenu.item("fx_paste", "Paste " + EffectOps.copied_label() + " onto the selected clips" if EffectOps.has_copied() else "Paste effect onto the selected clips")
	if not EffectOps.has_copied():
		paste["disabled"] = true
	items.append(paste)
	items.append(PmMenu.item("fx_duplicate", "Duplicate effect, on every clip"))
	items.append(PmMenu.item("fx_reset", "Reset effect, on every clip"))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("fx_remove", "Remove effect, from every clip", "", "trash"))
	return items


static func header_menu_picked(id: String, panel: Object, uids: Dictionary, sound: bool) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	if d == null or s == null:
		return false
	var clips: Array[Clip] = _clips_of(s, uids)
	if id == "fx_copy":
		if not clips.is_empty() and EffectOps.copy_effect(clips[0], String(uids[clips[0].id])):
			Events.toast("Copied " + EffectOps.copied_label() + " from " + (clips[0].label if not clips[0].label.is_empty() else clips[0].id))
			return true
		return false
	if id == "fx_paste":
		if EffectOps.paste_effect(d, s, Verbs.selection(s)) == 0:
			Events.toast("Select clips that can take this effect")
			return false
		return true
	if id == "fx_duplicate":
		return _run_each(d, "Duplicate effect", func() -> void:
			for c: Clip in clips:
				EffectOps.duplicate_effect(d, s, c.id, String(uids[c.id])))
	if id == "fx_reset":
		var done: bool = _run_each(d, "Reset effect", func() -> void:
			for c: Clip in clips:
				EffectOps.reset_effect(d, s, c.id, String(uids[c.id])))
		if not done:
			Events.toast("The effects already have their default values")
		return done
	if id == "fx_remove":
		var cmds: Array[Command] = []
		for c: Clip in clips:
			cmds.append(EffectCmds.RemoveEffect.new(s.id, c.id, String(uids[c.id]), sound))
		return Verbs.run(d, "Remove effect", cmds)
	return false


static func pair_note(panel: Object, body: VBoxContainer, g: Dictionary, sound: bool) -> void:
	var def: Dictionary = EffectSource.get_def(String(g["eid"]))
	var pairs: PackedStringArray = def.get("pairs_with", PackedStringArray())
	if sound or pairs.is_empty():
		return
	var s: Sequence = _seq(panel)
	var uids: Dictionary = g["uids"]
	var lacking: Dictionary = {}
	for c: Clip in _clips_of(s, uids):
		if partner_of(c, String(uids[c.id]), pairs).is_empty():
			lacking[c.id] = uids[c.id]
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row.name = "ManyPairNote"
	row.add_child(_gap(_lead_w()))
	var names: PackedStringArray = PackedStringArray()
	for pid: String in pairs:
		names.append(String(EffectSource.get_def(pid).get("label", pid)))
	if lacking.is_empty():
		row.add_child(PmLabel.dim("Paired with " + names[0] + " in every clip"))
		body.add_child(row)
		return
	row.add_child(PmLabel.dim(str(lacking.size()) + " of " + str(uids.size()) + " clips need " + ", ".join(names) + " above this effect"))
	var add: Button = _quiet("Add " + names[0], "", "Adds " + names[0] + " above this effect in every clip that has none")
	add.name = "ManyAddPartner"
	add.pressed.connect(Callable(SELF, "add_partner").bind(panel, lacking, pairs[0]))
	row.add_child(add)
	body.add_child(row)


static func partner_of(c: Clip, uid: String, pairs: PackedStringArray) -> Dictionary:
	var idx: int = c.effect_index(uid)
	for k: int in range(idx - 1, -1, -1):
		var other: Dictionary = c.effects[k]
		if bool(other.get("enabled", true)) and pairs.has(String(other.get("id", ""))):
			return other
	return {}


static func add_partner(panel: Object, lacking: Dictionary, partner_id: String) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var def: Dictionary = EffectSource.get_def(partner_id)
	if d == null or s == null or def.is_empty():
		return false
	return _run_each(d, "Add " + String(def.get("label", partner_id)), func() -> void:
		for c: Clip in _clips_of(s, lacking):
			Verbs.add_effect(d, s, PackedStringArray([c.id]), def, c.effect_index(String(lacking[c.id]))))


static func _crops_cmds(panel: Object, c: Clip, uid: String, crops: Array, remap: Dictionary) -> Array[Command]:
	var s: Sequence = _seq(panel)
	var cmds: Array[Command] = []
	var cmd: Command = EffectCmds.SetEffectParam.new(s.id, c.id, uid, "crops", JSON.stringify(crops), -1.0)
	cmds.append(cmd)
	var masks: Array[Dictionary] = panel.call("_synced_masks", c, uid, crops, remap)
	if masks != c.masks:
		cmds.append(ClipCmds.SetClipField.new(s.id, c.id, "masks", masks))
	var moved: Array[Command] = panel.call("_offset_remap", c, uid, remap)
	cmds.append_array(moved)
	cmds.append_array(PvGroups.remap_cmds(s, c, uid, crops.size(), remap))
	return cmds


static func _crops(panel: Object, c: Clip, uid: String) -> Array:
	return panel.call("_crops_of", c.effect_by_uid(uid))


static func _view_names(panel: Object, c: Clip, uid: String) -> PackedStringArray:
	var e: Dictionary = c.effect_by_uid(uid)
	var names: PackedStringArray = ViewMap.region_names(e)
	var n: int = _crops(panel, c, uid).size()
	while names.size() < n:
		names.append("View " + str(names.size() + 1))
	if names.size() > n:
		names = names.slice(0, n)
	return names


static func _switch_labels(panel: Object, clips: Array[Clip], uids: Dictionary, most: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for i: int in most:
		var seen: String = ""
		var same: bool = true
		for c: Clip in clips:
			var names: PackedStringArray = _view_names(panel, c, String(uids[c.id]))
			if i >= names.size():
				continue
			if seen.is_empty():
				seen = names[i]
			elif seen != names[i]:
				same = false
		out.append(seen if same and not seen.is_empty() else str(i + 1))
	return out


static func _shown_view(panel: Object, c: Clip, uid: String) -> int:
	var s: Sequence = _seq(panel)
	if s == null:
		return -1
	return ViewSwitch.shown_view(s, c, c.effect_by_uid(uid), s.playhead)


static func switch_view(panel: Object, uids: Dictionary, index: int) -> void:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	if d == null or s == null:
		return
	var cmds: Array[Command] = []
	var names: PackedStringArray = PackedStringArray()
	for cid: Variant in uids.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var uid: String = String(uids[cid])
		if index >= _crops(panel, c, uid).size():
			continue
		var cmd: Command = PairCmds.SwitchView.new(s.id, c.id, uid, index, s.playhead, bool(Session.recording))
		cmds.append(cmd)
		var got: PackedStringArray = _view_names(panel, c, uid)
		if index < got.size() and not names.has(got[index]):
			names.append(got[index])
	if cmds.is_empty():
		return
	var label: String = "Switch view to " + (names[0] if names.size() == 1 else str(index + 1))
	if not Verbs.run(d, label, cmds):
		Events.toast(ViewSwitch.why_text(String((cmds[0] as Object).get("why")), names[0] if not names.is_empty() else str(index + 1)))


static func toggle_switch_keys(panel: Object) -> void:
	ViewSwitch.set_key_on_switch(not ViewSwitch.key_on_switch())
	Events.toast("Switching a view " + ("adds a keyframe" if ViewSwitch.key_on_switch() else "no longer adds a keyframe") + ", for every Pair View")
	if panel != null and panel.has_method("refresh"):
		panel.call("refresh")


static func _switch_row(panel: Object, clips: Array[Clip], uids: Dictionary, most: int) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row.add_child(_gap(_lead_w()))
	var cap: Label = PmLabel.dim("Switch to")
	cap.custom_minimum_size.x = float(Tk.px(52.0))
	row.add_child(cap)
	var labels: PackedStringArray = _switch_labels(panel, clips, uids, most)
	var live: PackedInt32Array = PackedInt32Array()
	for c: Clip in clips:
		var now: int = _shown_view(panel, c, String(uids[c.id]))
		if now >= 0 and not live.has(now):
			live.append(now)
	for i: int in most:
		var b: Button = _quiet(labels[i] if i < labels.size() else str(i + 1), "", "")
		b.name = "ViewSwitch" + str(i)
		b.set("active", live.size() == 1 and live[0] == i)
		b.set("elide", true)
		PmUI.tip(b, "Shows this view on every selected Pair View from the playhead on")
		b.pressed.connect(Callable(SELF, "switch_view").bind(panel, uids, i))
		row.add_child(b)
	row.add_child(PmUI.spacer())
	var keyb: Button = _quiet("Key on switch", "stopwatch", ViewSwitch.PREF_KEY_ON_SWITCH_HINT)
	keyb.name = "ViewSwitchKeys"
	keyb.set("active", ViewSwitch.key_on_switch())
	keyb.pressed.connect(Callable(SELF, "toggle_switch_keys").bind(panel))
	row.add_child(keyb)
	return row


static func pair_view(panel: Object, body: VBoxContainer, g: Dictionary) -> void:
	var s: Sequence = _seq(panel)
	var uids: Dictionary = (g["uids"] as Dictionary).duplicate()
	var clips: Array[Clip] = _clips_of(s, uids)
	if clips.is_empty() or s == null:
		return
	body.add_child(_layout_row(panel, clips, uids))
	var counts: PackedInt32Array = PackedInt32Array()
	var most: int = 0
	var least: int = REGION_MAX
	for c: Clip in clips:
		var n: int = _crops(panel, c, String(uids[c.id])).size()
		counts.append(n)
		most = maxi(most, n)
		least = mini(least, n)
	var head: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	head.add_child(_gap(_lead_w()))
	head.add_child(PmLabel.dim("Regions: " + (str(most) if most == least else str(least) + " to " + str(most)) + " per clip"))
	head.add_child(PmUI.spacer())
	var add: Button = PmButton.make("Add region", "plus")
	add.set("quiet", true)
	add.name = "ManyAddRegion"
	PmUI.tip(add, "Adds one region to every selected Pair View")
	add.disabled = least >= REGION_MAX
	add.pressed.connect(Callable(SELF, "add_region").bind(panel, uids))
	head.add_child(add)
	var lead: Clip = panel.call("target_clip")
	var save: Button = _quiet("Save as preset", "", "")
	save.name = "ManySavePreset"
	if lead != null and uids.has(lead.id):
		PmUI.tip(save, "Saves the Pair View of " + (lead.label if not lead.label.is_empty() else lead.id) + ", the first selected clip, as an effect preset")
		save.pressed.connect(Callable(panel, "_on_save_regions").bind(String(uids[lead.id])))
	else:
		save.disabled = true
		PmUI.tip(save, "The first selected clip has no Pair View to save")
	head.add_child(save)
	body.add_child(head)
	body.add_child(_switch_row(panel, clips, uids, most))
	body.add_child(PvGroups.row(uids, _lead_w()))
	for i: int in most:
		_region_row(panel, body, g, clips, uids, i, most)
	var note: HBoxContainer = PmUI.hbox(0)
	note.add_child(_gap(_lead_w()))
	note.add_child(PmLabel.dim(ONE_REGION_NOTE))
	body.add_child(note)
	body.add_child(PvStreamRows.many_row(panel, clips, uids))
	body.add_child(PvAudio.always_row(uids, _lead_w()))
	_shared_sound_row(panel, body, clips, uids)
	body.add_child(_tools_row(panel, clips, uids))


static func _layout_row(panel: Object, clips: Array[Clip], uids: Dictionary) -> Control:
	var s: Sequence = _seq(panel)
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row.add_child(_gap(_lead_w()))
	var cap: Label = PmLabel.dim("Layout")
	cap.custom_minimum_size.x = float(Tk.px(52.0))
	row.add_child(cap)
	var choices: Array = []
	for p: Dictionary in PairLayouts.presets():
		choices.append(PmDrop.choice(String(p["id"]), String(p["label"])))
	var lit: PackedStringArray = PackedStringArray()
	for c: Clip in clips:
		var e: Dictionary = c.effect_by_uid(String(uids[c.id]))
		var now: String = PairLayouts.lit(c, e, PairLayouts.time_in(c, s), s.fps)
		if not lit.has(now):
			lit.append(now)
	var drop: Button = PmDrop.make_drop(choices, lit[0] if lit.size() == 1 else "")
	drop.name = "ManyLayout"
	drop.custom_minimum_size.x = float(Tk.px(140.0))
	if lit.size() != 1:
		drop.set("placeholder", "mixed")
		drop.call("set_value", "", false)
	PmUI.tip(drop, "Lay out the regions the same way in every selected Pair View")
	drop.connect("changed", Callable(SELF, "set_layout").bind(panel, uids))
	row.add_child(drop)
	return row


static func set_layout(preset_id: String, panel: Object, uids: Dictionary) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	return _run_each(d, "Layout: " + PairLayouts.preset_label(preset_id), func() -> void:
		for c: Clip in _clips_of(s, uids):
			PairLayouts.apply_in(d, s, c.id, String(uids[c.id]), preset_id))


static func add_region(panel: Object, uids: Dictionary) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var cmds: Array[Command] = []
	for c: Clip in _clips_of(s, uids):
		var uid: String = String(uids[c.id])
		var crops: Array = _crops(panel, c, uid)
		if crops.size() >= REGION_MAX:
			continue
		cmds.append_array(_crops_cmds(panel, c, uid, LayerChain.resplit(crops, crops.size() + 1), {}))
	return Verbs.run(d, "Views", cmds)


static func _region_row(panel: Object, body: VBoxContainer, g: Dictionary, clips: Array[Clip], uids: Dictionary, i: int, most: int) -> void:
	var holders: Array[Clip] = []
	var names: PackedStringArray = PackedStringArray()
	var removable: bool = false
	var down_ok: bool = false
	for c: Clip in clips:
		var crops: Array = _crops(panel, c, String(uids[c.id]))
		if crops.size() <= i:
			continue
		holders.append(c)
		var nm: String = String((crops[i] as Dictionary).get("name", ""))
		if not names.has(nm):
			names.append(nm)
		removable = removable or crops.size() > 1
		down_ok = down_ok or crops.size() > i + 1
	if holders.is_empty():
		return
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.name = "ManyRegion" + str(i)
	row.add_child(_gap(_lead_w()))
	row.add_child(PmLabel.mono(str(i), "text_faint"))
	var nm_label: Label = PmLabel.trim(names[0] if names.size() == 1 else "mixed names", "text" if names.size() == 1 else "text_dim")
	nm_label.custom_minimum_size.x = float(Tk.px(110.0))
	row.add_child(nm_label)
	if holders.size() < clips.size():
		row.add_child(PmLabel.dim(str(holders.size()) + " of " + str(clips.size()) + " clips"))
	row.add_child(PmUI.spacer())
	var up: Button = _icon("chev_u", "Move this region up in every clip that has it")
	up.disabled = i == 0
	up.pressed.connect(Callable(SELF, "move_region").bind(panel, uids, i, -1))
	row.add_child(up)
	var dn: Button = _icon("chev_d", "Move this region down in every clip that has one after it")
	dn.disabled = not down_ok
	dn.pressed.connect(Callable(SELF, "move_region").bind(panel, uids, i, 1))
	row.add_child(dn)
	var del: Button = _icon("trash", "Remove this region from every clip that has it (each Pair View keeps at least one)")
	del.disabled = not removable
	del.pressed.connect(Callable(SELF, "remove_region").bind(panel, uids, i))
	row.add_child(del)
	var wrap: MarginContainer = MarginContainer.new()
	wrap.add_child(row)
	var slot: Control = PmSlot.make(PackedStringArray(["effect"]))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set("priority", 1)
	slot.connect("dropped", Callable(SELF, "_on_region_drop").bind(panel, uids, i))
	wrap.add_child(slot)
	body.add_child(wrap)
	body.add_child(PvCropRows.make_many(holders, uids, i, _lead_w()))
	_region_fx_rows(panel, body, holders, uids, i)
	var canon: String = "effects.@" + String(g["key"])
	var offs: Dictionary = {}
	for h: Clip in holders:
		offs[h.id] = "effects." + String(uids[h.id]) + "." + ViewMap.offset_key(i)
	var ms: bool = PvSync.unit() == "ms"
	panel.call("_add_row", body, {"path": canon + "." + ViewMap.offset_key(i), "label": "Offset", "kind": "float", "keyable": true, "min": -ViewMap.OFFSET_MAX, "max": ViewMap.OFFSET_MAX, "step": 0.001 if ms else 0.01, "suffix": " ms" if ms else " s", "display_mul": 1000.0 if ms else 1.0, "indent": 1, "members": offs})
	_unit_buttons(panel)
	var places: Dictionary = {}
	var sizes: Dictionary = {}
	for h2: Clip in holders:
		var e: Dictionary = h2.effect_by_uid(String(uids[h2.id]))
		var solo: int = PairLayouts.PairLayout.solo_of(e)
		if not PairLayouts.shows_place(h2, e) or (solo >= 0 and solo != i):
			continue
		places[h2.id] = "effects." + String(uids[h2.id]) + "." + PairLayouts.PairLayout.place_key(i)
		sizes[h2.id] = "effects." + String(uids[h2.id]) + "." + PairLayouts.PairLayout.size_key(i)
	if places.is_empty():
		return
	panel.call("_add_row", body, {"path": canon + "." + PairLayouts.PairLayout.place_key(i), "label": "On screen at", "kind": "vec2", "keyable": true, "min": PairLayouts.PairLayout.PLACE_MIN, "max": PairLayouts.PairLayout.PLACE_MAX, "step": 0.001, "display_mul": 100.0, "suffix": " %", "indent": 1, "members": places})
	panel.call("_add_row", body, {"path": canon + "." + PairLayouts.PairLayout.size_key(i), "label": "On screen size", "kind": "float", "keyable": true, "min": PairLayouts.PairLayout.SIZE_MIN, "max": PairLayouts.PairLayout.SIZE_MAX, "step": 0.001, "display_mul": 100.0, "suffix": " %", "indent": 1, "members": sizes})


static func _on_region_drop(payload: Dictionary, _local: Vector2, panel: Object, uids: Dictionary, index: int) -> void:
	if String(payload.get("kind", "")) != "effect":
		return
	var def: Dictionary = EffectSource.get_def(String(payload.get("id", "")))
	if not add_region_effect(panel, uids, index, def):
		Events.toast(RegionFx.refusal(def) if not RegionFx.refusal(def).is_empty() else "No selected clip has that region")


static func add_region_effect(panel: Object, uids: Dictionary, index: int, def: Dictionary) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	if d == null or s == null or def.is_empty():
		return false
	var cmds: Array[Command] = []
	for c: Clip in _clips_of(s, uids):
		if _crops(panel, c, String(uids[c.id])).size() > index:
			cmds.append_array(RegionFxCmds.add_commands(d, s, c, String(uids[c.id]), index, def))
	return Verbs.run(d, "Effect on a region", cmds)


static func _region_fx_rows(panel: Object, body: VBoxContainer, holders: Array[Clip], uids: Dictionary, index: int) -> void:
	var groups: Dictionary = {}
	var order: PackedStringArray = PackedStringArray()
	for c: Clip in holders:
		for fx: Dictionary in RegionFx.effects_on(c, String(uids[c.id]), index):
			var eid: String = String(fx.get("id", ""))
			if not groups.has(eid):
				groups[eid] = {}
				order.append(eid)
			(groups[eid] as Dictionary)[c.id] = String(fx.get("uid", ""))
	for eid2: String in order:
		var found: Dictionary = groups[eid2]
		var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		row.name = "ManyRegionFx" + str(index)
		row.add_child(_gap(_lead_w() * 2.0))
		var def: Dictionary = EffectSource.get_def(eid2)
		var name_label: Label = PmLabel.trim(String(def.get("label", eid2)), "text")
		name_label.custom_minimum_size.x = float(Tk.px(150.0))
		row.add_child(name_label)
		row.add_child(PmLabel.dim(str(found.size()) + " of " + str(holders.size()) + " clips"))
		var whole: Button = _quiet("Whole clip", "", "Move this effect back to the whole picture, after the Pair View, in every clip that has it on this region")
		whole.pressed.connect(Callable(SELF, "region_fx_whole").bind(panel, found))
		row.add_child(whole)
		var del: Button = _icon("trash", "Remove this effect from this region in every clip that has it")
		del.pressed.connect(Callable(SELF, "region_fx_remove").bind(panel, found))
		row.add_child(del)
		row.add_child(PmUI.spacer())
		body.add_child(row)


static func region_fx_whole(panel: Object, found: Dictionary) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var cmds: Array[Command] = []
	for c: Clip in _clips_of(s, found):
		cmds.append_array(RegionFxCmds.whole_commands(s, c, String(found[c.id])))
	return Verbs.run(d, "Effect on the whole clip", cmds)


static func region_fx_remove(panel: Object, found: Dictionary) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	return _run_each(d, "Remove effect", func() -> void:
		for c: Clip in _clips_of(s, found):
			RegionFxCmds.remove(d, s, c.id, String(found[c.id])))


static func _unit_buttons(panel: Object) -> void:
	var rows: Array = panel.get("_rows")
	if rows.is_empty():
		return
	var rec: Dictionary = rows[rows.size() - 1]
	var editors: Array = rec["editors"]
	if editors.is_empty() or (editors[0] as Control).get_parent() == null:
		return
	var ms: bool = PvSync.unit() == "ms"
	var extra: HBoxContainer = PmUI.hbox(0)
	for u: String in ["ms", "s"]:
		var b: Button = PmButton.make(u, "", true)
		b.set("quiet", true)
		b.set_pressed_no_signal((u == "ms") == ms)
		PmUI.tip(b, "Show offsets in milliseconds" if u == "ms" else "Show offsets in seconds")
		b.pressed.connect(Callable(PvSync, "set_unit").bind(u))
		extra.add_child(b)
	(editors[0] as Control).get_parent().add_child(extra)


static func move_region(panel: Object, uids: Dictionary, i: int, dir: int) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var j: int = i + dir
	var cmds: Array[Command] = []
	for c: Clip in _clips_of(s, uids):
		var uid: String = String(uids[c.id])
		var crops: Array = _crops(panel, c, uid)
		if i < 0 or i >= crops.size() or j < 0 or j >= crops.size():
			continue
		var tmp: Variant = crops[i]
		crops[i] = crops[j]
		crops[j] = tmp
		cmds.append_array(_crops_cmds(panel, c, uid, crops, {i: j, j: i}))
	return Verbs.run(d, "Reorder regions", cmds)


static func remove_region(panel: Object, uids: Dictionary, i: int) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var cmds: Array[Command] = []
	for c: Clip in _clips_of(s, uids):
		var uid: String = String(uids[c.id])
		var crops: Array = _crops(panel, c, uid)
		if crops.size() <= 1 or i >= crops.size():
			continue
		crops.remove_at(i)
		var remap: Dictionary = {i: -1}
		for k: int in range(i + 1, i + 1 + crops.size()):
			remap[k] = k - 1
		cmds.append_array(_crops_cmds(panel, c, uid, crops, remap))
	return Verbs.run(d, "Remove region", cmds)


static func _shared_sound_row(panel: Object, body: VBoxContainer, clips: Array[Clip], uids: Dictionary) -> void:
	var s: Sequence = _seq(panel)
	var holders: Dictionary = {}
	for c: Clip in clips:
		var map: Dictionary = ViewMap.of(c.effect_by_uid(String(uids[c.id])))
		if not map.is_empty() and not ViewMap.shared_sounds(map, s, c).is_empty():
			holders[c.id] = uids[c.id]
	if holders.is_empty():
		return
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row.add_child(_gap(_lead_w()))
	row.add_child(PmLabel.dim(str(holders.size()) + " of " + str(clips.size()) + " clips share a sound between views"))
	row.add_child(PmUI.spacer())
	var split: Button = PmButton.make("Give each view its own copy of this sound", "plus")
	split.set("quiet", true)
	split.name = "ManySplitSound"
	PmUI.tip(split, "Copies each shared sound onto a new track for every other view that hears it, in every clip that shares one")
	split.pressed.connect(Callable(SELF, "split_sounds").bind(panel, holders))
	row.add_child(split)
	body.add_child(row)


static func split_sounds(panel: Object, holders: Dictionary) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var cmds: Array[Command] = []
	for c: Clip in _clips_of(s, holders):
		cmds.append(PvCmds.SplitSharedSound.new(s.id, c.id, String(holders[c.id])))
	var ok: bool = Verbs.run(d, "Give each view its own sound", cmds)
	if not ok:
		Events.toast("Nothing to copy, or the tracks are locked")
	return ok


static func _tools_row(panel: Object, clips: Array[Clip], uids: Dictionary) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row.name = "ManyViewTools"
	row.add_child(_gap(_lead_w()))
	row.add_child(PmUI.spacer())
	row.add_child(panel.call("_views_panel_button"))
	var tidy: Button = PmButton.make("Rearrange tracks", "list")
	tidy.set("quiet", true)
	tidy.name = "ManyRearrange"
	PmUI.tip(tidy, "Move each clip's audio so the views read top to bottom in view order")
	tidy.pressed.connect(Callable(SELF, "rearrange").bind(panel, uids))
	row.add_child(tidy)
	var all_on: bool = true
	var ids: PackedStringArray = PackedStringArray()
	for c: Clip in clips:
		ids.append(c.id)
		all_on = all_on and PvCuts.is_on(c)
	var cuts: Button = PmButton.make(PvCuts.LABEL, "razor", true)
	cuts.set("quiet", true)
	cuts.name = "ManyViewCuts"
	cuts.set_pressed_no_signal(all_on)
	PmUI.tip(cuts, PvCuts.TIP + " For every selected Pair View.", Cmd.keys_text(PvCuts.TOGGLE_ID))
	cuts.toggled.connect(Callable(SELF, "set_cuts").bind(panel, ids))
	row.add_child(cuts)
	row.add_child(_scope_button(panel, clips, uids))
	row.add_child(PvStreamRows.many_offset(panel, clips, uids))
	var sync: Button = PmButton.make("Sync regions", "slide")
	sync.set("quiet", true)
	sync.name = "ManySync"
	sync.disabled = true
	PmUI.tip(sync, SYNC_TIP)
	row.add_child(sync)
	return row


static func scope_of(e: Dictionary) -> String:
	var map: Dictionary = ViewMap.of(e)
	return String(map.get("scope", "group")) if not map.is_empty() else "group"


static func _scope_button(panel: Object, clips: Array[Clip], uids: Dictionary) -> Button:
	var seen: PackedStringArray = PackedStringArray()
	for c: Clip in clips:
		var sc: String = scope_of(c.effect_by_uid(String(uids[c.id])))
		if not seen.has(sc):
			seen.append(sc)
	var text: String = "Reach: mixed"
	if seen.size() == 1:
		text = "Only this group" if seen[0] == "group" else "Every track"
	var b: Button = PmButton.make(text, "link")
	b.set("quiet", true)
	b.name = "ManyScope"
	PmUI.tip(b, "Whether the views reach only the audio linked to each clip, or every audio track, for every selected Pair View")
	b.pressed.connect(Callable(SELF, "set_scope").bind(panel, uids, "all" if seen.size() == 1 and seen[0] == "group" else "group"))
	return b


static func set_scope(panel: Object, uids: Dictionary, want: String) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var cmds: Array[Command] = []
	for c: Clip in _clips_of(s, uids):
		var uid: String = String(uids[c.id])
		var e: Dictionary = c.effect_by_uid(uid)
		var map: Dictionary = ViewMap.of(e)
		if map.is_empty():
			map = {"v": 1, "scope": "group", "views": []}
		if String(map.get("scope", "group")) == want:
			continue
		map["scope"] = want
		cmds.append(EffectCmds.SetEffectParam.new(s.id, c.id, uid, "view_audio", JSON.stringify(map), -1.0))
	return Verbs.run(d, "View audio reach", cmds)


static func set_cuts(on: bool, panel: Object, ids: PackedStringArray) -> bool:
	return PvCuts.set_on(_doc(panel), _seq(panel), ids, on)


static func rearrange(panel: Object, uids: Dictionary) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var done: bool = _run_each(d, "Rearrange tracks", func() -> void:
		for c: Clip in _clips_of(s, uids):
			Verbs.rearrange_view_audio(d, s, c.id, String(uids[c.id])))
	if not done:
		Events.toast("Nothing to rearrange, or a clip is in the way of the move")
	return done


static func nest_many(panel: Object, body: VBoxContainer, nests: Array[Clip]) -> void:
	var ids: PackedStringArray = PackedStringArray()
	for n: Clip in nests:
		ids.append(n.id)
	for spec: Array in NEST_CHECKS:
		var key: String = String(spec[0])
		var on_all: bool = true
		var on_any: bool = false
		for n2: Clip in nests:
			var v: bool = bool(n2.nest.get(key, key == "hear_audio"))
			on_all = on_all and v
			on_any = on_any or v
		var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		row.add_child(_gap(float(Tk.px(8.0))))
		var cb: CheckBox = CheckBox.new()
		cb.focus_mode = Control.FOCUS_NONE
		cb.name = "ManyNest_" + key
		cb.set_pressed_no_signal(on_all)
		PmUI.tip(cb, String(spec[2]))
		cb.toggled.connect(Callable(SELF, "set_nest_option").bind(panel, ids, key))
		row.add_child(cb)
		row.add_child(PmLabel.body(String(spec[1])))
		if on_any and not on_all:
			row.add_child(PmLabel.dim("mixed"))
		body.add_child(row)
		if key == "hear_audio":
			_nest_tracks(panel, body, nests, ids)
	var open_row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	open_row.add_child(_gap(float(Tk.px(8.0))))
	var open: Button = PmButton.make("Open the nested sequence", "seq")
	open.set("quiet", true)
	open.name = "ManyOpenNest"
	PmUI.tip(open, "Opens " + (nests[0].label if not nests[0].label.is_empty() else nests[0].id) + ", the first selected nest, in a timeline tab")
	open.pressed.connect(Callable(NestControls, "open_nest").bind(nests[0].id))
	open_row.add_child(open)
	body.add_child(open_row)


static func _nest_tracks(panel: Object, body: VBoxContainer, nests: Array[Clip], ids: PackedStringArray) -> void:
	var d: Project = _doc(panel)
	var inner_id: String = nests[0].sequence_id
	for n: Clip in nests:
		if n.sequence_id != inner_id:
			var note: HBoxContainer = PmUI.hbox(Tk.px(4.0))
			note.add_child(_gap(float(Tk.px(8.0))))
			note.add_child(PmLabel.dim("Tracks: the selected nests hold different sequences, select one to pick its tracks"))
			body.add_child(note)
			return
	var inner: Sequence = d.sequence_by_id(inner_id) if d != null else null
	if inner == null or inner.audio_tracks.is_empty():
		return
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.add_child(_gap(float(Tk.px(8.0))))
	var lab: Label = PmLabel.dim("Tracks")
	lab.custom_minimum_size = Vector2(float(Tk.px(55.0)), 0.0)
	row.add_child(lab)
	for t: Track in inner.audio_tracks:
		var all: bool = true
		for n2: Clip in nests:
			all = all and Verbs.nest_heard_tracks(d, n2).has(t.id)
		var chip: Button = PmButton.make(t.label, "audio")
		chip.set("quiet", true)
		chip.toggle_mode = true
		chip.name = "ManyNestTrack_" + t.id
		chip.set_pressed_no_signal(all)
		PmUI.tip(chip, "Hear " + t.label + " of " + inner.label + " through every selected nest")
		chip.toggled.connect(Callable(SELF, "set_nest_track").bind(panel, ids, t.id))
		row.add_child(chip)
	body.add_child(row)


static func set_nest_option(on: bool, panel: Object, ids: PackedStringArray, key: String) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	return _run_each(d, "Nest option", func() -> void:
		for id: String in ids:
			Verbs.set_nest_option(d, s, id, key, on))


static func set_nest_track(on: bool, panel: Object, ids: PackedStringArray, track_id: String) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	return _run_each(d, "Nest tracks heard", func() -> void:
		for id: String in ids:
			Verbs.set_nest_track_heard(d, s, id, track_id, on))


static func text_presets(panel: Object) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.name = "ManyTyping"
	row.add_child(_gap(_lead_w()))
	row.add_child(PmLabel.dim("Typing"))
	var ids: PackedStringArray = panel.get("_many_style")
	for p: Dictionary in Verbs.text_presets():
		var b: Button = PmButton.make(String(p["label"]), "type")
		b.set("quiet", true)
		PmUI.tip(b, String(p["tip"]) + ", for every selected title")
		b.pressed.connect(Callable(SELF, "apply_typing").bind(panel, ids.duplicate(), String(p["id"])))
		row.add_child(b)
	return row


static func apply_typing(panel: Object, ids: PackedStringArray, kind: String) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var done: bool = _run_each(d, "Typing", func() -> void:
		for id: String in ids:
			Verbs.apply_text_preset(d, s, id, kind))
	if not done:
		Events.toast("The texts already type that way")
	return done


static func own_values(panel: Object, body: VBoxContainer, kind: String) -> void:
	var members: Array[Clip] = panel.get("_many_members")
	var own: Array[Clip] = []
	for c: Clip in members:
		if not c.props.is_empty():
			own.append(c)
	if own.is_empty():
		return
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	row.name = "ManyOwnValues"
	row.add_child(_gap(_lead_w()))
	row.add_child(PmLabel.dim(("1 clip has" if own.size() == 1 else str(own.size()) + " clips have") + " their own values"))
	var ids: PackedStringArray = PackedStringArray()
	for c2: Clip in own:
		ids.append(c2.id)
	var what: String = "title" if kind == "title" else kind
	var push: Button = _quiet("Apply to every clip of this " + what, "", "")
	push.name = "ManyPushProps"
	var clash: String = props_clash(own)
	push.disabled = not clash.is_empty()
	PmUI.tip(push, clash if not clash.is_empty() else "Each clip's own values become its " + what + "'s shared values, for every clip of it")
	push.pressed.connect(Callable(SELF, "push_props").bind(panel, ids))
	row.add_child(push)
	var drop: Button = _quiet("Use the shared values", "", "Every selected clip with its own values goes back to its " + what + "'s shared values")
	drop.name = "ManyDropProps"
	drop.pressed.connect(Callable(SELF, "drop_props").bind(panel, ids))
	row.add_child(drop)
	body.add_child(row)


static func props_clash(own: Array[Clip]) -> String:
	var by_media: Dictionary = {}
	for c: Clip in own:
		var seen: Dictionary = by_media.get(c.media_id, {})
		for k: Variant in c.props.keys():
			if seen.has(k) and seen[k] != c.props[k]:
				return "Two selected clips of the same title have different values; select one to apply its values"
			seen[k] = c.props[k]
		by_media[c.media_id] = seen
	return ""


static func push_props(panel: Object, ids: PackedStringArray) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	if d == null or s == null:
		return false
	var merged: Dictionary = {}
	var cmds: Array[Command] = []
	for id: String in ids:
		var c: Clip = s.clip_by_id(id)
		var m: MediaItem = d.media_by_id(c.media_id) if c != null else null
		if m == null:
			continue
		var into: Dictionary = merged.get(m.id, m.props.duplicate(true))
		for k: Variant in c.props.keys():
			into[k] = c.props[k]
		merged[m.id] = into
		cmds.append(ClipCmds.SetClipField.new(s.id, c.id, "props", {}))
	for mid: Variant in merged.keys():
		cmds.push_front(MediaCmds.SetMediaField.new(String(mid), "props", merged[mid]))
	return Verbs.run(d, "Apply to every clip", cmds)


static func drop_props(panel: Object, ids: PackedStringArray) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var cmds: Array[Command] = []
	for id: String in ids:
		cmds.append(ClipCmds.SetClipField.new(s.id, id, "props", {}))
	return Verbs.run(d, "Use the shared values", cmds)


static func stream_row(panel: Object, body: VBoxContainer) -> void:
	var d: Project = _doc(panel)
	var members: Array[Clip] = panel.get("_many_members")
	var mem: Dictionary = {}
	var least: int = 0
	var items: Array = []
	for c: Clip in members:
		var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
		if m == null or m.audio_streams.size() < 2:
			continue
		mem[c.id] = "audio.stream"
		least = m.audio_streams.size() if least == 0 else mini(least, m.audio_streams.size())
		if not items.has(m):
			items.append(m)
	if mem.is_empty():
		return
	var choices: Array = []
	for i: int in least:
		choices.append(PmDrop.choice(str(i), StreamRoles.shared_menu_label(items, i)))
	panel.call("_add_row", body, {"path": "audio.stream", "label": "Stream", "kind": "enum", "field": "audio", "key": "stream", "choices": choices, "numeric": true, "members": mem})


static func row_menu_items(panel: Object, r: Dictionary) -> Array:
	var spec: Dictionary = r["spec"]
	if not bool(spec.get("keyable", false)):
		return []
	var s: Sequence = _seq(panel)
	var any_mod: bool = false
	var members: Dictionary = spec.get("members", {})
	for cid: Variant in members.keys():
		var c: Clip = s.clip_by_id(String(cid)) if s != null else null
		if c != null and AnimProp.has_modifiers(c.get_param(String(members[cid]))):
			any_mod = true
	var items: Array = [
		PmMenu.item("many_open_keys", "Open in the Keyframes panel (first selected clip)"),
		PmMenu.item("many_adjust", "Adjust keys, on every clip"),
		PmMenu.separator(),
		PmMenu.item("many_add_noise", "Add noise, on every clip"),
		PmMenu.item("many_add_wave", "Add wave, on every clip"),
	]
	if any_mod:
		items.append(PmMenu.item("many_bake", "Bake modifiers to keyframes, on every clip"))
	return items


static func row_menu_picked(panel: Object, id: String, spec: Dictionary) -> bool:
	if not id.begins_with("many_"):
		return false
	var members: Dictionary = spec.get("members", {})
	if id == "many_open_keys":
		open_keys(panel, members)
	elif id == "many_adjust":
		var fields: Array[Dictionary] = [
			{"key": "offset_t", "label": "Offset time (seconds)", "type": "float", "default": 0.0},
			{"key": "scale_t", "label": "Scale time", "type": "float", "default": 1.0},
			{"key": "offset_v", "label": "Offset value", "type": "float", "default": 0.0},
			{"key": "scale_v", "label": "Scale value", "type": "float", "default": 1.0},
			{"key": "note", "label": "", "type": "note", "default": "Applies to every key of this value on every selected clip"},
		]
		var answered: Signal = PmUI.form(panel.call("root"), "Adjust keys", fields, "Apply", "Cancel")
		answered.connect(Callable(SELF, "_on_adjust").bind(panel, members, String(spec.get("label", "keys"))))
	elif id == "many_add_noise" or id == "many_add_wave":
		add_modifier(panel, members, spec, "noise" if id == "many_add_noise" else "wave")
	elif id == "many_bake":
		bake(panel, members)
	return true


static func open_keys(panel: Object, members: Dictionary) -> bool:
	if members.is_empty():
		return false
	var cid: String = String(members.keys()[0])
	var real: String = String(members[cid])
	var b: RefCounted = panel.call("bus")
	b.emit_signal("property_picked", cid, real)
	Cmd.run("window.focus_effect_controls")
	var kp: Object = b.call("panel", "keyframes")
	if kp != null and kp.has_method("show_property"):
		kp.call("show_property", cid, real)
	return true


static func _on_adjust(result: Variant, panel: Object, members: Dictionary, label: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var r: Dictionary = result
	adjust(panel, members, float(r.get("offset_t", 0.0)), float(r.get("scale_t", 1.0)), float(r.get("offset_v", 0.0)), float(r.get("scale_v", 1.0)), label)


static func adjusted(p: Dictionary, offset_t: float, scale_t: float, offset_v: float, scale_v: float) -> Dictionary:
	var times: PackedFloat64Array = PackedFloat64Array()
	for k: Dictionary in AnimProp.keys(p):
		times.append(float(k.get("t", 0.0)))
	if times.is_empty():
		return p
	var out: Dictionary = p
	var pivot: float = INF
	for t: float in times:
		pivot = minf(pivot, t)
	if scale_t != 1.0:
		out = KeyEditor.scale_keys(out, times, pivot, scale_t)
		var scaled: PackedFloat64Array = PackedFloat64Array()
		for t2: float in times:
			scaled.append(maxf(pivot + (t2 - pivot) * scale_t, 0.0))
		times = scaled
	if offset_t != 0.0:
		out = KeyEditor.move_keys(out, times, offset_t, 0.0)
		var moved: PackedFloat64Array = PackedFloat64Array()
		for t3: float in times:
			moved.append(maxf(t3 + offset_t, 0.0))
		times = moved
	if offset_v != 0.0 or scale_v != 1.0:
		out = KeyEditor.scale_values(out, times, offset_v, scale_v)
	return out


static func adjust(panel: Object, members: Dictionary, offset_t: float, scale_t: float, offset_v: float, scale_v: float, label: String) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var cmds: Array[Command] = []
	for cid: Variant in members.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var real: String = String(members[cid])
		var p: Dictionary = c.get_param(real)
		if not AnimProp.is_animated(p):
			continue
		var next: Dictionary = adjusted(p, offset_t, scale_t, offset_v, scale_v)
		if next != p:
			cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, real, next))
	return Verbs.run(d, "Adjust keys: " + label, cmds)


static func add_modifier(panel: Object, members: Dictionary, spec: Dictionary, kind: String) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var lo: float = float(spec.get("min", -INF))
	var hi: float = float(spec.get("max", INF))
	var cmds: Array[Command] = []
	for cid: Variant in members.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var real: String = String(members[cid])
		var p: Dictionary = c.get_param(real)
		if p.is_empty():
			continue
		var amp: float = 1.0
		if lo > -INF and hi < INF:
			amp = (hi - lo) * 0.1
		else:
			var cur: float = AnimProp.evaluate_float(p, c.param_time(real, s.playhead - c.start), c.duration, s.fps)
			amp = maxf(absf(cur) * 0.1, 1.0)
		var layer: Dictionary = AnimProp.new_noise_layer(amp, 2.0) if kind == "noise" else AnimProp.new_wave_layer(amp, 1.0)
		cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, real, AnimProp.add_layer(p, layer)))
	return Verbs.run(d, "Add " + kind, cmds)


static func bake(panel: Object, members: Dictionary) -> bool:
	var d: Project = _doc(panel)
	var s: Sequence = _seq(panel)
	var cmds: Array[Command] = []
	for cid: Variant in members.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var real: String = String(members[cid])
		var p: Dictionary = c.get_param(real)
		if AnimProp.has_modifiers(p):
			cmds.append(ClipCmds.SetClipParam.new(s.id, c.id, real, AnimProp.bake(p, c.duration, s.fps)))
	return Verbs.run(d, "Bake modifiers", cmds)

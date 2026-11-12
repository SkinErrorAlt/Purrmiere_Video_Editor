extends RefCounted

const SELF := preload("res://modules/core_panels/sound_well.gd")
const AudioReact := preload("res://engine/audio_react.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmSlot := preload("res://ui/kit/pm_slot.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmDragLayer := preload("res://ui/kit/pm_drag_layer.gd")
const EditTools := preload("res://doc/commands/edit_tools.gd")
const GROUP := "purr_sound_well"
const KINDS: PackedStringArray = ["media", "clip"]
const WELL_W := 150.0
const ID_OWN := "own"
const ID_NONE := "none"
const ID_MIX := "mix"
const ID_VIEWS := "views"
const CLIP_PREFIX := "clip:"
const VIEW_PREFIX := "view:"
const ReactFeed := preload("res://engine/react_feed.gd")
const SoundWellMore := preload("res://modules/core_panels/sound_well_more.gd")
const TIP := "The sound this effect follows. Drag a clip from the timeline, a file from the bin or the Source monitor's drag handle onto it, or click for a menu"


static func add(panel: Object, editors: HBoxContainer, spec: Dictionary) -> Array:
	var path: String = String(spec.get("path", ""))
	var well: Button = PmButton.make("This clip's own sound", "audio")
	well.name = "SoundWell"
	well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	well.custom_minimum_size.x = float(Tk.px(WELL_W))
	well.clip_text = true
	well.alignment = HORIZONTAL_ALIGNMENT_LEFT
	well.set_meta("path", path)
	well.add_to_group(GROUP)
	PmUI.tip(well, TIP)
	var slot: Control = PmSlot.make(KINDS)
	slot.name = "SoundSlot"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set("priority", 10)
	slot.set("can_accept_cb", Callable(AudioReact, "accepts_payload"))
	slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.connect("dropped", Callable(SELF, "_on_drop").bind(panel, path))
	well.add_child(slot)
	well.pressed.connect(Callable(SELF, "_open_menu").bind(panel, path, well))
	editors.add_child(well)
	return [well]


static func refresh(well: Control, value: Variant, panel: Object) -> void:
	if well == null or not is_instance_valid(well):
		return
	var text: String = String(value) if value != null else ""
	var c: Object = panel.call("target_clip")
	var d: Object = panel.call("doc")
	var label: String = AudioReact.label_of(d, c, text)
	if well is Button and (well as Button).text != label:
		(well as Button).text = label
	well.set_meta("value", text)


static func slot_of(well: Control) -> Control:
	return well.get_node_or_null("SoundSlot") as Control


static func apply(panel: Object, path: String, text: String) -> void:
	panel.call("_on_text", text, path)


static func _on_drop(payload: Dictionary, _at: Vector2, panel: Object, path: String) -> void:
	drop(panel, path, payload)


static func drop(panel: Object, path: String, payload: Dictionary) -> bool:
	if not AudioReact.accepts_payload(payload):
		return false
	var d: Object = panel.call("doc")
	var p: Dictionary = payload
	if String(payload.get("kind", "")) == "media" and d != null:
		p = EditTools.subclip_payload(d, payload)
	var text: String = AudioReact.source_from_payload(d, p)
	if text.is_empty():
		return false
	apply(panel, path, text)
	return true


static func menu_items(panel: Object) -> Array:
	var items: Array = [PmMenu.item(ID_OWN, "This clip's own sound")]
	var s: Object = panel.call("seq")
	var d: Object = panel.call("doc")
	var own: Object = panel.call("target_clip")
	var t: float = float(panel.call("playhead"))
	var listed: Array = []
	if s != null and d != null:
		var tracks: Array = []
		tracks.append_array(s.get("audio_tracks"))
		tracks.append_array(s.get("video_tracks"))
		for tr: Variant in tracks:
			var track: Object = tr
			var c: Object = track.call("clip_at", t)
			if c == null or c == own:
				continue
			var m: Object = d.call("media_by_id", String(c.get("media_id")))
			if m == null or not bool(m.get("has_audio")) or String(m.get("kind")) == "sequence":
				continue
			var name: String = String(c.get("label")) if not String(c.get("label")).is_empty() else String(m.get("label"))
			listed.append(PmMenu.item(CLIP_PREFIX + String(c.get("id")), String(track.call("shown_label")) + ": " + name))
	listed.append_array(SoundWellMore.items(panel, Callable(PmMenu, "item")))
	if not listed.is_empty():
		items.append(PmMenu.separator())
		items.append_array(listed)
	items.append(PmMenu.separator())
	items.append(PmMenu.item(ID_MIX, "Everything you hear here"))
	if s != null and not ReactFeed.pair_clips(s).is_empty():
		items.append(PmMenu.item(ID_VIEWS, "Pair View: the view on screen"))
		for v: Variant in ReactFeed.view_choices(d, s, own):
			var vd: Dictionary = v
			items.append(PmMenu.item(VIEW_PREFIX + String(vd["clip"]) + ":" + str(int(vd["view"])), "Pair View: " + String(vd["label"]) + ("" if bool(vd["own"]) else " (" + String(vd["clip_label"]) + ")")))
	items.append(PmMenu.separator())
	items.append(PmMenu.item(ID_NONE, "No sound"))
	return items


static func _open_menu(panel: Object, path: String, anchor: Control) -> void:
	var m: Control = PmMenu.open(anchor, menu_items(panel))
	if m != null and m.is_inside_tree():
		m.connect("picked", Callable(SELF, "picked").bind(panel, path))


static func picked(id: String, panel: Object, path: String) -> void:
	if id == ID_OWN:
		apply(panel, path, "")
	elif id == ID_NONE:
		apply(panel, path, AudioReact.encode({"kind": AudioReact.KIND_NONE}))
	elif id.begins_with(CLIP_PREFIX):
		apply(panel, path, AudioReact.encode({"kind": AudioReact.KIND_CLIP, "clip": id.substr(CLIP_PREFIX.length())}))
	elif id == ID_MIX:
		apply(panel, path, AudioReact.encode({"kind": AudioReact.KIND_MIX}))
	elif id == ID_VIEWS:
		apply(panel, path, AudioReact.encode({"kind": AudioReact.KIND_VIEWS}))
	elif not SoundWellMore.text_for(id, panel).is_empty():
		apply(panel, path, SoundWellMore.text_for(id, panel))
	elif id.begins_with(VIEW_PREFIX):
		var rest: String = id.substr(VIEW_PREFIX.length())
		var cut: int = rest.rfind(":")
		if cut > 0:
			apply(panel, path, AudioReact.encode({"kind": AudioReact.KIND_VIEW, "clip": rest.substr(0, cut), "view": int(rest.substr(cut + 1))}))


static func well_at(tree: SceneTree, global_pos: Vector2) -> Control:
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group(GROUP):
		var w: Control = n as Control
		if w == null or not w.is_visible_in_tree():
			continue
		if w.get_global_rect().has_point(global_pos) and PmDragLayer.shown_at(w, global_pos):
			return w
	return null


static func hand_off(canvas: Control, drag: Object, global_pos: Vector2) -> bool:
	if canvas == null or drag == null or String(drag.get("mode")) != "move":
		return false
	if canvas.get_global_rect().has_point(global_pos):
		return false
	var well: Control = well_at(canvas.get_tree(), global_pos)
	if well == null:
		return false
	var clip_id: String = String(drag.get("clip_id"))
	if clip_id.is_empty():
		return false
	var layer: CanvasLayer = PmDragLayer.find(canvas)
	if layer == null:
		return false
	drag.call("cancel")
	var ghost: Label = Label.new()
	ghost.text = "Sound from this clip"
	layer.call("begin", {"kind": "clip", "ids": [clip_id], "from": "timeline"}, ghost, Vector2(12.0, 12.0))
	return true

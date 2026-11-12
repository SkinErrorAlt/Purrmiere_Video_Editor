extends "res://modules/core_panels/panel_base.gd"

const KeyframeEditor := preload("res://ui/timeline/keyframe_editor.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const TransitionRegistry := preload("res://engine/transition_registry.gd")
const MaskShape := preload("res://doc/mask_shape.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const AnimLayerUi := preload("res://modules/core_panels/anim_layer_ui.gd")
const KeyframeGroups := preload("res://doc/keyframe_groups.gd")
const TextEcRows := preload("res://modules/core_panels/text_ec_rows.gd")
const TextAnimators := preload("res://doc/text_animators.gd")
const LetterRig := preload("res://doc/letter_rig.gd")
const FreeKeys := preload("res://doc/free_keys.gd")
const MASK_KEYS: Array = [["centre", "Position"], ["size", "Size"], ["rotation", "Rotation"], ["feather", "Feather"], ["expand", "Expand"], ["opacity", "Opacity"]]
const SKIP_PROPS: PackedStringArray = ["path_points", "runs"]
const PREF_AUTO := "keys.auto_key"
const PREF_SHIFT := "keys.shift_is_value"
const PREF_SNAP := "keys.snap_frames"
const PREF_DIR := "keys.preset_dir"

var editor: Control = null
var list: Control = null
var property_path: String = ""
var _clip_id: String = ""
var _split: Container = null
var _mode: Button = null
var _dope: Button = null
var _ease: Button = null
var _auto: Button = null
var _shift_btn: Button = null
var _snap_btn: Button = null
var _played_btn: Button = null
var _items: Array[Dictionary] = []
var _rows: Array[Dictionary] = []
var _open: Dictionary = {}
var _rebuild_queued: bool = false
var _list_stamp: String = ""


func _build(root_: Control) -> void:
	for spec: Array in [[PREF_AUTO, false, {"label": "Auto key", "type": "bool"}], [PREF_SHIFT, true, {"label": "Shift drag changes values in the keyframe editor", "type": "bool"}], [PREF_SNAP, true, {"label": "Snap keys to frames", "type": "bool"}], [PREF_DIR, OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), {"label": "Keyframe preset folder", "type": "string"}]]:
		if not Prefs.is_registered(String(spec[0])):
			Prefs.register(String(spec[0]), spec[1], spec[2])
	KeyframeEditor.ensure_prefs()
	var col: VBoxContainer = column(root_)
	var bar: HBoxContainer = header_row(col)
	var tools: Container = PmToolbar.make()
	tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode = PmDrop.make_drop([PmDrop.choice("value", "Value"), PmDrop.choice("velocity", "Velocity")], "value")
	_mode.connect("changed", _on_mode)
	tools.call("add_item", _mode, "mode", "View")
	_dope = toggle_icon("list", "Dope sheet", false)
	_dope.pressed.connect(_on_dope)
	tools.call("add_item", _dope, "dope", "Dope sheet")
	var prev: Button = quiet_icon("prev_key", "Previous key", Cmd.keys_text("nav.prev_key"))
	prev.pressed.connect(_on_nav.bind(-1))
	tools.call("add_item", prev, "prev", "Previous key")
	var add: Button = quiet_icon("diamond", "Add key at the playhead")
	add.pressed.connect(_on_add_key)
	tools.call("add_item", add, "add", "Add key")
	var next: Button = quiet_icon("next_key", "Next key", Cmd.keys_text("nav.next_key"))
	next.pressed.connect(_on_nav.bind(1))
	tools.call("add_item", next, "next", "Next key")
	_ease = PmButton.make("Ease", "chev_d")
	_ease.set("quiet", true)
	_ease.pressed.connect(_on_ease_menu)
	tools.call("add_item", _ease, "ease", "Ease")
	var fit: Button = quiet_icon("maximize", "Fit the keys in view (the selected ones, or all)", "F")
	fit.pressed.connect(_on_fit)
	tools.call("add_item", fit, "fit", "Fit")
	var copy: Button = quiet_icon("export", "Copy keys")
	copy.set("icon_px", 14.0)
	copy.pressed.connect(_on_copy)
	tools.call("add_item", copy, "copy", "Copy keys")
	var paste: Button = quiet_icon("extract", "Paste keys at the playhead")
	paste.pressed.connect(_on_paste)
	tools.call("add_item", paste, "paste", "Paste keys")
	var save: Button = PmButton.make("Save keys")
	save.set("quiet", true)
	save.pressed.connect(_on_save_keys)
	tools.call("add_item", save, "save", "Save keys")
	var presets: Button = PmButton.make("Presets", "chev_d")
	presets.set("quiet", true)
	presets.pressed.connect(_on_presets_menu.bind(presets))
	tools.call("add_item", presets, "presets", "Presets")
	_auto = PmButton.make("Auto-key", "", true)
	_auto.set("quiet", true)
	_auto.button_pressed = bool(Prefs.get_value(PREF_AUTO))
	_auto.pressed.connect(_on_auto)
	tools.call("add_item", _auto, "auto", "Auto key")
	_shift_btn = PmButton.make("Shift = value", "", true)
	_shift_btn.set("quiet", true)
	_shift_btn.button_pressed = bool(Prefs.get_value(PREF_SHIFT))
	_shift_btn.pressed.connect(_on_shift)
	tools.call("add_item", _shift_btn, "shift", "Shift is value")
	_snap_btn = PmButton.make("Snap frames", "", true)
	_snap_btn.set("quiet", true)
	_snap_btn.button_pressed = bool(Prefs.get_value(PREF_SNAP))
	_snap_btn.pressed.connect(_on_snap)
	tools.call("add_item", _snap_btn, "snap", "Snap frames")
	_played_btn = PmButton.make("Played time", "", true)
	_played_btn.set("quiet", true)
	_played_btn.button_pressed = bool(Prefs.get_value(KeyframeEditor.PREF_PLAYED))
	PmUI.tip(_played_btn, KeyframeEditor.PLAYED_TIP)
	_played_btn.pressed.connect(_on_played)
	tools.call("add_item", _played_btn, "played", "Played time")
	bar.add_child(tools)
	_split = PmSplit.make(false, 0.28, "keys.list")
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_split)
	list = _PropList.new()
	list.panel = self
	editor = KeyframeEditor.make("", "", false)
	_apply_key_prefs()
	_split.call("set_pair", list, editor)
	if not bus().property_picked.is_connected(_on_property_picked):
		bus().property_picked.connect(_on_property_picked)
	rebuild()


func _apply_key_prefs() -> void:
	editor.set("snap_frames", bool(Prefs.get_value(PREF_SNAP)))
	editor.set("shift_is_value", bool(Prefs.get_value(PREF_SHIFT)))
	editor.set("auto_key", bool(Prefs.get_value(PREF_AUTO)))
	if _auto != null:
		_auto.button_pressed = bool(Prefs.get_value(PREF_AUTO))
	if _shift_btn != null:
		_shift_btn.button_pressed = bool(Prefs.get_value(PREF_SHIFT))
	if _snap_btn != null:
		_snap_btn.button_pressed = bool(Prefs.get_value(PREF_SNAP))
	if _played_btn != null:
		_played_btn.button_pressed = bool(Prefs.get_value(KeyframeEditor.PREF_PLAYED))


func _on_pref_changed(key: String) -> void:
	if key == PREF_SNAP or key == PREF_SHIFT or key == PREF_AUTO or key == KeyframeEditor.PREF_PLAYED:
		_apply_key_prefs()
		if editor != null:
			editor.queue_redraw()


func target_clip() -> Clip:
	var s: Sequence = seq()
	if s == null:
		return null
	if not _clip_id.is_empty():
		var c: Clip = s.clip_by_id(_clip_id)
		if c != null and s.selected_clip_ids.has(c.id):
			return c
	var picked: Clip = Bus.selected_clip(s)
	return picked if picked != null else FreeKeys.held_stand_in(s)


func show_property(clip_id: String, path: String) -> void:
	_clip_id = clip_id
	property_path = path
	rebuild()


func _on_property_picked(clip_id: String, path: String) -> void:
	show_property(clip_id, path)


func properties_of(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null:
		return out
	if FreeKeys.is_free(c.id):
		var treg0: RefCounted = TransitionRegistry.shared()
		return FreeKeys.properties(c, String(treg0.call("label_for", c.transition_in)) if treg0 != null else "Transition")
	for pair: Array in [["transform.pos", "Position"], ["transform.scale", "Scale"], ["transform.rotation", "Rotation"], ["transform.anchor", "Anchor"], ["transform.opacity", "Opacity"], ["speed", "Speed"], [AnimTime.SPEED_PATH, "Animation speed"], ["audio.volume", "Volume"]]:
		out.append({"path": String(pair[0]), "label": String(pair[1]), "animated": AnimProp.is_animated(c.get_param(String(pair[0])))})
	out.append_array(prop_items(c))
	for e: Dictionary in c.effects:
		var uid: String = String(e.get("uid", ""))
		var def: Dictionary = EffectSource.get_def(String(e.get("id", "")))
		var ename: String = String(def.get("label", String(e.get("id", ""))))
		var params: Dictionary = e.get("params", {})
		for key: String in params.keys():
			var plabel: String = key
			for p: Dictionary in EffectSource.param_specs(def):
				if String(p.get("key", "")) == key:
					plabel = String(p.get("label", key))
			var path: String = "effects." + uid + "." + key
			out.append({"path": path, "label": ename + " · " + plabel, "animated": AnimProp.is_animated(c.get_param(path))})
	for mi: int in c.masks.size():
		var mask: Dictionary = c.masks[mi]
		var mlabel: String = MaskShape.label_of(mask, mi)
		for pair2: Array in MASK_KEYS:
			var mpath: String = "masks." + str(mask.get("id", "")) + "." + String(pair2[0])
			out.append({"path": mpath, "label": mlabel + " · " + String(pair2[1]), "animated": AnimProp.is_animated(c.get_param(mpath))})
	var treg: RefCounted = TransitionRegistry.shared()
	for tfield: Array in [[Clip.TRANSITION_PATH, c.transition_in, c.has_transition()], [Clip.TRANSITION_OUT_PATH, c.transition_out, c.has_transition_out()]]:
		if not bool(tfield[2]):
			continue
		var tr: Dictionary = tfield[1]
		var tlabel: String = String(treg.call("label_for", tr)) if treg != null else "Transition"
		var prefix: String = String(tfield[0])
		out.append({"path": prefix + "progress", "label": tlabel + " · Progress", "animated": AnimProp.is_animated(c.get_param(prefix + "progress"))})
		var tparams: Dictionary = tr.get("params", {}) if tr.get("params", null) is Dictionary else {}
		for pkey: String in tparams.keys():
			if String(pkey) == "progress":
				continue
			if not AnimProp.is_animated(c.get_param(prefix + String(pkey))):
				continue
			out.append({"path": prefix + String(pkey), "label": tlabel + " · " + String(pkey).capitalize(), "animated": true})
	return with_speeds(c, out)


static func prop_label(key: String) -> String:
	if KeyframeGroups.is_animator_prop(key):
		var field: String = KeyframeGroups.animator_field(key)
		for row: Array in TextEcRows.ANIM_ROWS:
			if String(row[0]) == field:
				return String(row[1])
		return field.capitalize()
	for row2: Array in TextEcRows.EXTRA_ROWS:
		if String(row2[0]) == key:
			return String(row2[1])
	return key.capitalize()


static func group_titles(c: Clip) -> Dictionary:
	var out: Dictionary = {}
	if c == null:
		return out
	for i: int in TextAnimators.MAX_ANIMATORS:
		var raw: Variant = TextAnimators.plain(c.props.get(TextAnimators.key(i, "name"), ""))
		var text: String = String(raw).strip_edges() if raw is String else ""
		if not text.is_empty():
			out[KeyframeGroups.ANIM_PREFIX + str(i)] = text
	return out


func prop_items(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null or c.props.is_empty():
		return out
	var keys: PackedStringArray = PackedStringArray()
	for k: Variant in c.props.keys():
		if not SKIP_PROPS.has(String(k)):
			keys.append(String(k))
	keys.sort()
	var titles: Dictionary = group_titles(c)
	var plain: Array[Dictionary] = []
	var animators: Array[Dictionary] = []
	var extras: Array[Dictionary] = []
	var rig_text: String = String(LetterRig.plain(c.props.get("text", "")))
	var rig: Array[Dictionary] = rig_items(c, rig_text)
	for key: String in keys:
		if LetterRig.is_rig_prop(key):
			continue
		var path: String = "props." + key
		var group: String = KeyframeGroups.prop_group(key)
		var head: String = String(titles.get(group, KeyframeGroups.title_of(group, "")))
		var item: Dictionary = {"path": path, "label": head + KeyframeGroups.SEPARATOR + prop_label(key), "animated": AnimProp.is_animated(c.get_param(path))}
		if group == KeyframeGroups.TEXT:
			plain.append(item)
		elif group == KeyframeGroups.EXTRAS:
			extras.append(item)
		else:
			animators.append(item)
	out.append_array(plain)
	out.append_array(animators)
	out.append_array(rig)
	out.append_array(extras)
	return out


## Letter rig rows in rig-tree order: whole text, lines, then each word followed by its letters.
func rig_items(c: Clip, text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bones: PackedStringArray = LetterRig.bones_in(c.props)
	if bones.is_empty():
		return out
	var words: PackedInt32Array = LetterRig.word_map(text)
	var order: Array = []
	for b: String in bones:
		var k: String = LetterRig.kind_of(b)
		var i: int = LetterRig.index_of(b)
		var w: int = -1
		var rank: float = 0.0
		if k == LetterRig.ROOT:
			rank = -2.0
		elif k == "l":
			rank = -1.0 + float(i) * 0.0001
		elif k == "w":
			rank = float(i) * 2.0
		else:
			w = words[i] if i < words.size() else -1
			rank = (float(w) * 2.0 + 1.0) if w >= 0 else 1.0e6 + float(i)
		order.append([rank, i, b])
	order.sort_custom(func(a: Array, b2: Array) -> bool: return float(a[0]) < float(b2[0]) or (float(a[0]) == float(b2[0]) and int(a[1]) < int(b2[1])))
	for o: Array in order:
		var bone_id: String = String(o[2])
		var head: String = LetterRig.label(text, bone_id)
		var parent: String = ""
		if LetterRig.kind_of(bone_id) == "c":
			var wi: int = words[LetterRig.index_of(bone_id)] if LetterRig.index_of(bone_id) < words.size() else -1
			if wi >= 0:
				parent = "w" + str(wi)
		for f: String in LetterRig.FIELDS:
			var key: String = LetterRig.key(bone_id, f)
			if not c.props.has(key):
				continue
			var path: String = "props." + key
			var item: Dictionary = {"path": path, "label": head + KeyframeGroups.SEPARATOR + LetterRig.field_label(f), "animated": AnimProp.is_animated(c.get_param(path))}
			if not parent.is_empty():
				item["rig_parent"] = KeyframeGroups.RIG_PREFIX + parent
				item["rig_parent_label"] = LetterRig.label(text, parent)
			out.append(item)
	return out


static func group_label(c: Clip, g: String) -> String:
	if g == "motion":
		return "Motion"
	if g == "audio":
		return "Audio"
	if g == "props":
		return "Text"
	var parts: PackedStringArray = g.split(".")
	if parts.size() < 2:
		return g
	var e: Dictionary = c.audio_effect_by_uid(parts[1]) if parts[0] == "audio_effects" else c.effect_by_uid(parts[1])
	var def: Dictionary = EffectSource.get_def(String(e.get("id", "")))
	return String(def.get("label", String(e.get("id", "Effect"))))


static func _speed_item(c: Clip, target: String, label: String) -> Dictionary:
	var path: String = AnimTime.speed_path(target)
	return {"path": path, "label": label, "animated": AnimProp.is_animated(c.get_param(path))}


static func with_speeds(c: Clip, list: Array[Dictionary]) -> Array[Dictionary]:
	var used: PackedStringArray = c.speed_targets()
	if used.is_empty():
		return list
	var out: Array[Dictionary] = []
	var placed: Dictionary = {}
	for it: Dictionary in list:
		var path: String = String(it["path"])
		var g: String = AnimTime.group_of(path)
		if not g.is_empty() and used.has(g) and not placed.has(g):
			placed[g] = true
			out.append(_speed_item(c, g, group_label(c, g) + " · Animation speed"))
		out.append(it)
		if used.has(path) and not placed.has(path):
			placed[path] = true
			out.append(_speed_item(c, path, String(it["label"]) + " · Speed"))
	for t: String in used:
		if placed.has(t):
			continue
		if AnimTime.is_group(t):
			out.append(_speed_item(c, t, group_label(c, t) + " · Animation speed"))
		else:
			var g2: String = AnimTime.group_of(t)
			var head: String = group_label(c, g2) + " · " if not g2.is_empty() else ""
			out.append(_speed_item(c, t, head + t.get_slice(".", t.get_slice_count(".") - 1).capitalize() + " · Speed"))
	return out


func _stamp() -> String:
	var c: Clip = target_clip()
	if c == null:
		return ""
	var parts: PackedStringArray = PackedStringArray([c.id])
	for p: Dictionary in properties_of(c):
		parts.append(String(p["path"]) + ("*" if bool(p["animated"]) else ""))
	var titles: Dictionary = group_titles(c)
	for key: Variant in titles.keys():
		parts.append(String(key) + "=" + String(titles[key]))
	return "|".join(parts)


func rebuild() -> void:
	if not _alive():
		return
	load("res://modules/core_panels/panel_place.gd").call("keys_turn", self)
	var c: Clip = target_clip()
	_items = properties_of(c)
	_list_stamp = _stamp()
	if c == null:
		_rows = []
		editor.call("set_target", "", "")
		list.queue_redraw()
		return
	var have: bool = false
	for it: Dictionary in _items:
		if String(it["path"]) == property_path:
			have = true
	if not have:
		property_path = ""
		for it: Dictionary in _items:
			if bool(it["animated"]):
				property_path = String(it["path"])
				break
		if property_path.is_empty() and not _items.is_empty():
			property_path = String(_items[0]["path"])
	editor.call("set_target", c.id, property_path)
	var paths: PackedStringArray = PackedStringArray()
	for it: Dictionary in _items:
		if bool(it["animated"]):
			paths.append(String(it["path"]))
	editor.call("set_paths", paths)
	regroup(c)
	list.queue_redraw()


func regroup(c: Clip) -> void:
	if not property_path.is_empty():
		_open[KeyframeGroups.key_of(property_path)] = true
		for it: Dictionary in _items:
			if String(it.get("path", "")) == property_path and not String(it.get("rig_parent", "")).is_empty():
				_open[String(it["rig_parent"])] = true
	_rows =KeyframeGroups.with_marks(c, KeyframeGroups.build(_items, _open, group_titles(c)))


func rows() -> Array[Dictionary]:
	return _rows


func row_count() -> int:
	return _rows.size()


func group_open(key: String) -> bool:
	return bool(_open.get(key, false))


func toggle_group(key: String) -> void:
	if key.is_empty():
		return
	_open[key] = not bool(_open.get(key, false))
	regroup(target_clip())
	if list != null:
		list.queue_redraw()


func pick(path: String) -> void:
	property_path = path
	var c: Clip = target_clip()
	if c != null:
		editor.call("set_target", c.id, path)
	regroup(c)
	list.queue_redraw()


func row_menu_items(path: String) -> Array:
	var c: Clip = target_clip()
	return AnimLayerUi.menu_items(c.get_param(path) if c != null else {})


func open_row_menu(path: String, anchor: Control, at: Vector2) -> Control:
	pick(path)
	var m: Control = PmMenu.open(anchor, row_menu_items(path), anchor.global_position + at)
	if m != null and m.is_inside_tree():
		m.connect("picked", row_menu_picked.bind(path))
	return m


func row_menu_picked(id: String, path: String) -> void:
	if not AnimLayerUi.owns_menu(id):
		return
	var c: Clip = target_clip()
	if c == null:
		return
	Cmd.run("window.focus_effect_controls")
	var ec: Object = bus().panel("effect_controls")
	if ec != null and ec.has_method("open_anim_sheet"):
		ec.call("open_anim_sheet", path, AnimLayerUi.kind_of_menu(id))


func queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	var tree: SceneTree = _root.get_tree()
	if tree == null:
		_rebuild_queued = false
		rebuild()
		return
	tree.process_frame.connect(_deferred, CONNECT_ONE_SHOT)


func _deferred() -> void:
	_rebuild_queued = false
	if not _alive():
		return
	if _stamp() != _list_stamp:
		rebuild()
	else:
		editor.queue_redraw()
		list.queue_redraw()


func _on_doc_changed(kind: String) -> void:
	if kind.begins_with("live"):
		editor.queue_redraw()
	elif kind == "selection" or kind == "structure" or kind == "meta":
		queue_rebuild()


func _on_history() -> void:
	queue_rebuild()


func _on_project_changed() -> void:
	_clip_id = ""
	property_path = ""
	rebuild()


func _on_sequence_changed(_id: String) -> void:
	rebuild()


func _on_mode(id: String) -> void:
	_dope.button_pressed = false
	editor.call("set_mode", id)


func _on_dope() -> void:
	editor.call("set_mode", "dope" if _dope.button_pressed else String(_mode.get("value")))


func _on_nav(dir: int) -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	var lt: float = playhead() - c.start
	var best: float = 0.0
	var found: bool = false
	for kt: float in AnimTime.played_list(c, property_path):
		if dir > 0 and kt > lt + 0.0001 and (not found or kt < best):
			best = kt
			found = true
		if dir < 0 and kt < lt - 0.0001 and (not found or kt > best):
			best = kt
			found = true
	if found:
		Session.set_playhead(c.start + best)


func _on_add_key() -> void:
	editor.call("add_key_at_playhead")


func _on_ease_menu() -> void:
	var m: Control = PmMenu.open(_ease, editor.call("ease_menu_items"))
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_ease_picked)


func _on_ease_picked(id: String) -> void:
	editor.call("handle_menu", id, 0.0, 0.0)


func _on_fit() -> void:
	editor.call("frame_keys")


func _on_copy() -> void:
	bus().key_clipboard = editor.call("copy_selected")
	Events.toast("Copied " + str((bus().key_clipboard as Array).size()) + " keys")


func _on_paste() -> void:
	var c: Clip = target_clip()
	if c == null:
		return
	editor.call("paste_keys", bus().key_clipboard, editor.call("playhead_key_time"))


func _on_save_keys() -> void:
	var keys: Array = editor.call("copy_selected")
	if keys.is_empty():
		Events.toast("No keys to save")
		return
	var fields: Array[Dictionary] = [{"key": "name", "label": "Name", "type": "string", "default": property_path.get_slice(".", property_path.get_slice_count(".") - 1)}]
	var answered: Signal = PmUI.form(_root, "Save keys as a preset", fields, "Save", "Cancel")
	answered.connect(_on_save_keys_form.bind(keys))


func _on_save_keys_form(result: Variant, keys: Array) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var name_: String = String((result as Dictionary).get("name", "keys")).strip_edges()
	if name_.is_empty():
		name_ = "keys"
	var dir: String = Prefs.data_path("presets/keys")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path: String = dir.path_join(name_.validate_filename() + ".purrkeys")
	var err: Error = Io.write_atomic(path, JSON.stringify({"name": name_, "keys": keys}, "\t"), false)
	if err == OK:
		Events.toast("Saved " + path.get_file())
	else:
		Events.error("Could not save the keys", Io.last_error)


func _on_presets_menu(anchor: Control) -> void:
	var items: Array = []
	var dir: DirAccess = DirAccess.open(Prefs.data_path("presets/keys"))
	if dir != null:
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while not entry.is_empty():
			if entry.ends_with(".purrkeys"):
				items.append(PmMenu.item("keys:" + entry, entry.get_basename()))
			entry = dir.get_next()
		dir.list_dir_end()
	if items.is_empty():
		var none: Dictionary = PmMenu.item("none", "No saved keys yet")
		none["disabled"] = true
		items.append(none)
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_preset_picked)


func _on_preset_picked(id: String) -> void:
	if not id.begins_with("keys:"):
		return
	var d: Dictionary = Io.read_json(Prefs.data_path("presets/keys").path_join(id.substr(5)))
	var keys: Variant = d.get("keys", [])
	var c: Clip = target_clip()
	if typeof(keys) == TYPE_ARRAY and c != null:
		editor.call("paste_keys", keys, editor.call("playhead_key_time"))


func _on_auto() -> void:
	Prefs.set_value(PREF_AUTO, _auto.button_pressed)
	editor.set("auto_key", _auto.button_pressed)
	var c: Clip = target_clip()
	if c != null and not property_path.is_empty():
		bus().set_armed(c.id, property_path, _auto.button_pressed)


func _on_shift() -> void:
	Prefs.set_value(PREF_SHIFT, _shift_btn.button_pressed)
	editor.set("shift_is_value", _shift_btn.button_pressed)


func _on_snap() -> void:
	Prefs.set_value(PREF_SNAP, _snap_btn.button_pressed)
	editor.set("snap_frames", _snap_btn.button_pressed)


func _on_played() -> void:
	editor.call("set_played_time", _played_btn.button_pressed)


func handle_key(e: InputEventKey) -> bool:
	if not e.pressed:
		return false
	if editor != null and bool(editor.call("handle_key", e)):
		return true
	if e.keycode == KEY_ESCAPE:
		return bool(editor.call("cancel_drag"))
	return false


func save_state() -> Dictionary:
	var open_keys: PackedStringArray = PackedStringArray()
	for k: Variant in _open.keys():
		if bool(_open[k]):
			open_keys.append(String(k))
	return {"path": property_path, "mode": String(editor.get("mode")) if editor != null else "value", "open": open_keys}


func restore_state(d: Dictionary) -> void:
	property_path = String(d.get("path", ""))
	_open = {}
	if d.get("open") is PackedStringArray or d.get("open") is Array:
		for k: Variant in d["open"]:
			_open[String(k)] = true
	if _alive():
		editor.call("set_mode", String(d.get("mode", "value")))
		rebuild()


class _PropList:
	extends Control

	const PaintKit := preload("res://ui/timeline/timeline_paint.gd")
	const PmTextKit := preload("res://ui/kit/pm_text.gd")
	const ROW := 22.0
	const CHEVRON := 16.0
	const STRIP_MAX := 110.0
	const STRIP_PART := 0.4

	var panel: RefCounted = null
	var scroll: float = 0.0
	var hover: int = -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		custom_minimum_size = Vector2(80.0, 0.0)
		gui_input.connect(_on_input)
		mouse_exited.connect(_on_exit)

	func _on_exit() -> void:
		hover = -1
		queue_redraw()

	func rows() -> Array:
		return panel.call("rows")

	func top_limit(count: int) -> float:
		return maxf(float(count) * ROW - size.y, 0.0)

	func clamp_scroll() -> void:
		scroll = clampf(scroll, 0.0, top_limit(rows().size()))

	func row_at(y: float, count: int) -> int:
		var i: int = int(floor((y + scroll) / ROW))
		return i if i >= 0 and i < count else -1

	func _on_input(event: InputEvent) -> void:
		var list_rows: Array = rows()
		if event is InputEventMouseMotion:
			hover = row_at((event as InputEventMouseMotion).position.y, list_rows.size())
			queue_redraw()
			return
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					scroll = clampf(scroll + (ROW * 3.0 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -ROW * 3.0), 0.0, top_limit(list_rows.size()))
					queue_redraw()
				accept_event()
				return
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				var i: int = row_at(mb.position.y, list_rows.size())
				if i >= 0:
					var it: Dictionary = list_rows[i]
					if String(it.get("kind", "")) == "group":
						panel.call("toggle_group", String(it.get("key", "")))
					else:
						panel.call("pick", String(it.get("path", "")))
				accept_event()
			if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				var j: int = row_at(mb.position.y, list_rows.size())
				if j >= 0:
					var jt: Dictionary = list_rows[j]
					if String(jt.get("kind", "")) == "group":
						panel.call("toggle_group", String(jt.get("key", "")))
					else:
						panel.call("open_row_menu", String(jt.get("path", "")), self, mb.position)
				accept_event()

	func _draw_chevron(at: Vector2, open: bool, col: Color) -> void:
		var pts: PackedVector2Array = PackedVector2Array()
		if open:
			pts.append(at + Vector2(-4.0, -2.0))
			pts.append(at + Vector2(4.0, -2.0))
			pts.append(at + Vector2(0.0, 3.0))
		else:
			pts.append(at + Vector2(-2.0, -4.0))
			pts.append(at + Vector2(3.0, 0.0))
			pts.append(at + Vector2(-2.0, 4.0))
		draw_colored_polygon(pts, col)

	func _draw_strip(it: Dictionary, y: float) -> float:
		var marks: PackedFloat32Array = it.get("marks", PackedFloat32Array())
		var width: float = minf(STRIP_MAX, size.x * STRIP_PART)
		if marks.is_empty() or width < 24.0:
			return 0.0
		var box := Rect2(size.x - width - PmTextKit.pad(), y + 5.0, width, ROW - 10.0)
		draw_rect(box, Tk.c["bg_panel_alt"], true)
		for u: float in marks:
			var x: float = box.position.x + 1.0 + clampf(u, 0.0, 1.0) * maxf(box.size.x - 3.0, 1.0)
			draw_rect(Rect2(x, box.position.y, 2.0, box.size.y), Tk.c["accent"], true)
		return width + PmTextKit.pad()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_panel"], true)
		var list_rows: Array = rows()
		var current: String = String(panel.get("property_path"))
		var f: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_body"))
		if list_rows.is_empty():
			PmTextKit.draw(self, f, Rect2(0.0, 0.0, size.x, ROW + 4.0), "Select a clip", fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, 8.0, 18.0)
			return
		clamp_scroll()
		for i: int in list_rows.size():
			var it: Dictionary = list_rows[i]
			var y: float = float(i) * ROW - scroll
			if y + ROW < 0.0 or y > size.y:
				continue
			var row_box := Rect2(0.0, y, size.x, ROW)
			var group: bool = String(it.get("kind", "")) == "group"
			var is_cur: bool = not group and String(it.get("path", "")) == current
			if is_cur:
				draw_rect(row_box, Tk.c["selection_fill"], true)
			elif group:
				draw_rect(row_box, Tk.c["bg_panel_high"] if i == hover else Tk.c["bg_panel_alt"], true)
			elif i == hover:
				draw_rect(row_box, Tk.c["bg_panel_high"], true)
			var animated: bool = bool(it.get("animated", false))
			var tree: float = float(int(it.get("indent", 0))) * 12.0
			var indent: float = (CHEVRON if int(it.get("depth", 0)) > 0 else 0.0) + tree
			var right: float = 0.0
			if group:
				_draw_chevron(Vector2(10.0 + tree, y + ROW * 0.5), bool(it.get("open", false)), Tk.c["text"] if animated else Tk.c["text_dim"])
				right = _draw_strip(it, y)
				if right == 0.0:
					var tally: String = str(int(it.get("keyed", 0))) + "/" + str(int(it.get("count", 0)))
					var tally_box := Rect2(size.x - 48.0 - PmTextKit.pad(), y, 48.0, ROW)
					PmTextKit.draw_in(self, f, tally_box, tally, fs, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_RIGHT, y + ROW * 0.5 + fs * 0.35, PmTextKit.ELIDE, row_box)
					right = 48.0 + PmTextKit.pad()
			else:
				PaintKit.draw_diamond(self, Vector2(12.0 + indent, y + ROW * 0.5), 3.5, Tk.c["text_bright"] if animated else Tk.c["text_faint"], animated)
			var text_x: float = (22.0 + tree) if group else 24.0 + indent
			var col: Color = Tk.c["text_bright"] if (is_cur or group) else (Tk.c["text"] if animated else Tk.c["text_dim"])
			PmTextKit.draw_in(self, f, Rect2(text_x, y, maxf(size.x - text_x - right - PmTextKit.pad(), 8.0), ROW), String(it.get("label", "")), fs, col, HORIZONTAL_ALIGNMENT_LEFT, y + ROW * 0.5 + fs * 0.35, PmTextKit.ELIDE, row_box)

extends "res://modules/core_panels/panel_base.gd"

const PresetFavs := preload("res://modules/core_panels/effect_folders.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const Subtitles := preload("res://doc/subtitles.gd")
const ExportPresets := preload("res://modules/export/export_presets.gd")
const Places := preload("res://modules/export/export_places.gd")
const AssetPacks := preload("res://doc/asset_packs.gd")
const StreamRoles := preload("res://doc/stream_roles.gd")
const SystemsPath := "res://modules/core_panels/systems.gd"
const KIND_LABELS: Dictionary = {"effect": "Effects", "effect_stack": "Effects", "transform": "Keyframes", "sequence": "Sequences", "export": "Export", "export_place": "Export places", "audio_fx": "Audio", "sfx_combo": "SFX combos", "composition": "Compositions", "text_style": "Text styles", "stream_roles": "Track names", "asset_pack": "Packages", "driver": "Drivers", "transition": "Transitions"}
const KIND_ICONS: Dictionary = {"effect": "fx", "effect_stack": "fx", "transform": "diamond", "sequence": "seq", "export": "export", "export_place": "folder", "audio_fx": "audio", "sfx_combo": "combo", "composition": "film", "text_style": "type", "stream_roles": "speaker", "asset_pack": "import", "driver": "follow", "transition": "slide"}
const SAVE_ITEMS: Array = [
	["effects", "Effect stack of the selected clip"],
	["effect", "One effect of the selected clip"],
	["transform", "Transform of the selected clip"],
	["audio_fx", "Audio effects of the selected clip"],
	["text_style", "Text style of the selected title"],
	["stream_roles", "Track names of the selected clip's file"],
	["composition", "Composition of the selected clips"],
	["sfx_combo", "SFX combo of the selected sound clips"],
	["sequence", "Sequence settings"],
	["export", "Export settings"],
	["export_place", "Export place from the export folder"],
	["asset_pack", "Package of the marked bin items"],
	["driver", "Drivers of the value picked in Effect Controls"],
	["transition", "Transition of the selected clip"],
]
const TILE_W := 130.0

var scope_tab: String = "library"
var kind_filter: String = ""
var tag_filter: String = ""
var search: String = ""
var _tabs: Control = null
var _search: LineEdit = null
var _kinds: HFlowContainer = null
var _tags: HFlowContainer = null
var _grid: Control = null
var _presets: Array[Dictionary] = []
var _press_pos: Vector2 = Vector2.ZERO
var _press_id: String = ""


func _build(root_: Control) -> void:
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = PmUI.hbox(0)
	_tabs = PmTabs.make(false)
	_tabs.set("fit_to_content", true)
	_tabs.call("add_tab", "library", "Library", 0)
	_tabs.call("add_tab", "project", "Project", 0)
	_tabs.connect("tab_changed", _on_scope)
	head.add_child(_tabs)
	_search = PmUI.line_edit("Search presets")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_on_search)
	head.add_child(_search)
	var save: Button = quiet_icon("plus", "Save the selection as a preset")
	save.pressed.connect(_on_save_menu.bind(save))
	head.add_child(save)
	col.add_child(head)
	_kinds = HFlowContainer.new()
	_kinds.add_theme_constant_override("h_separation", Tk.px(4.0))
	col.add_child(_kinds)
	_tags = HFlowContainer.new()
	_tags.add_theme_constant_override("h_separation", Tk.px(4.0))
	col.add_child(_tags)
	var scroll: ScrollContainer = vscroll_area(col)
	_grid = _Grid.new()
	_grid.panel = self
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	rebuild()


func _on_scope(id: String) -> void:
	scope_tab = id
	rebuild()


func _on_search(text: String) -> void:
	search = text.strip_edges().to_lower()
	rebuild()


static func kind_group(kind: String) -> String:
	if KIND_LABELS.has(kind):
		return String(KIND_LABELS[kind])
	return kind.replace("_", " ").capitalize()


func all_presets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d: Project = doc()
	if scope_tab == "project":
		if d != null:
			out = Presets.list_project(d)
	else:
		out = Presets.list_user_all()
	return out


func filtered() -> Array[Dictionary]:
	var picked: Array[Dictionary] = unsorted_filtered()
	var favs: PackedStringArray = PresetFavs.preset_favourites()
	var first: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for p: Dictionary in picked:
		if favs.has(String(p.get("id", ""))):
			first.append(p)
		else:
			rest.append(p)
	first.append_array(rest)
	return first


func is_favourite(id: String) -> bool:
	return PresetFavs.is_preset_favourite(id)


func set_favourite(id: String, on: bool) -> void:
	PresetFavs.set_preset_favourite(id, on)
	rebuild()


func unsorted_filtered() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in all_presets():
		var kind: String = String(p.get("kind", ""))
		if not kind_filter.is_empty() and kind_group(kind) != kind_filter:
			continue
		if not tag_filter.is_empty() and not (tag_filter in (p.get("tags", []) as Array)):
			continue
		if not search.is_empty() and not String(p.get("label", "")).to_lower().contains(search):
			continue
		out.append(p)
	return out


func rebuild() -> void:
	if not _alive():
		return
	PmUI.clear(_kinds)
	PmUI.clear(_tags)
	var all: Array[Dictionary] = all_presets()
	var kinds: PackedStringArray = PackedStringArray()
	var tags: PackedStringArray = PackedStringArray()
	for p: Dictionary in all:
		var kl: String = kind_group(String(p.get("kind", "")))
		if not kinds.has(kl):
			kinds.append(kl)
		for t: Variant in p.get("tags", []):
			if not tags.has(String(t)):
				tags.append(String(t))
	kinds.sort()
	tags.sort()
	var all_btn: Button = PmButton.make("All", "", true)
	all_btn.set("quiet", true)
	all_btn.button_pressed = kind_filter.is_empty()
	all_btn.pressed.connect(_on_kind.bind(""))
	_kinds.add_child(all_btn)
	for k: String in kinds:
		var b: Button = PmButton.make(k, "", true)
		b.set("quiet", true)
		b.button_pressed = kind_filter == k
		b.pressed.connect(_on_kind.bind(k))
		_kinds.add_child(b)
	for t: String in tags:
		var tb: Button = PmButton.make(t, "", true)
		tb.set("quiet", true)
		tb.button_pressed = tag_filter == t
		tb.pressed.connect(_on_tag.bind(t))
		_tags.add_child(tb)
	_tags.visible = not tags.is_empty()
	_presets = filtered()
	_grid.call("set_items", _presets)


func _on_kind(k: String) -> void:
	kind_filter = k
	rebuild()


func _on_tag(t: String) -> void:
	tag_filter = "" if tag_filter == t else t
	rebuild()


func preset_by_id(id: String) -> Dictionary:
	for p: Dictionary in all_presets():
		if String(p.get("id", "")) == id:
			return p
	var d: Project = doc()
	if d != null:
		var pp: Dictionary = Presets.find_project(d, id)
		if not pp.is_empty():
			return pp
	for p: Dictionary in Presets.list_user_all():
		if String(p.get("id", "")) == id:
			return p
	return {}


func apply_preset_id(id: String, clip_ids: PackedStringArray, t: float, track: Track) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	var p: Dictionary = preset_by_id(id)
	if d == null or s == null or p.is_empty():
		return false
	var kind: String = String(p.get("kind", ""))
	if kind == "composition" or kind == "sfx_combo":
		return _place_composition(p, t, track)
	if kind == "transition":
		return bool(load("res://modules/core_panels/transition_ops.gd").call("apply_preset", p, clip_ids, t, track))
	if Presets.ELSEWHERE.has(kind):
		Events.toast(Presets.why_not_applied(kind))
		return false
	if kind == "sequence":
		return Presets.apply(d, s, p)
	var ids: PackedStringArray = clip_ids if not clip_ids.is_empty() else Verbs.selection(s)
	if ids.is_empty():
		Events.toast("Select a clip first")
		return false
	Presets.last_refusal = ""
	if Presets.apply(d, s, p, ids):
		return true
	if not Presets.last_refusal.is_empty():
		Events.toast(Presets.last_refusal)
	return false


func _place_composition(p: Dictionary, t: float, track: Track) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	var payload: Dictionary = p.get("payload", {})
	var clips: Array = payload.get("clips", [])
	if clips.is_empty():
		Events.toast("This preset holds no clips")
		return false
	var clipboard: Dictionary = {"clips": clips, "span": float(payload.get("span", 0.0)), "seq_id": s.id, "fps": s.fps}
	if payload.get("groups") is Dictionary:
		clipboard["groups"] = payload["groups"]
	return Verbs.paste(d, s, clipboard, maxf(t, 0.0), false)


func begin_drag(id: String) -> void:
	var layer: CanvasLayer = PmDragLayer.find(_root)
	if layer == null:
		return
	var p: Dictionary = preset_by_id(id)
	var card: PanelContainer = PmUI.panel("bg_panel_high")
	card.add_child(PmLabel.tight(String(p.get("label", id)), "text_bright"))
	layer.call("begin", {"kind": "preset", "id": id}, card, Vector2(10.0, 10.0))


func open_context(id: String, at: Vector2) -> void:
	var items: Array = [
		PmMenu.item("apply", "Apply to the selection"),
		PmMenu.item("fav", "Remove from Favourites" if is_favourite(id) else "Add to Favourites"),
		PmMenu.item("edit", "Rename and tags"),
		PmMenu.item("duplicate", "Duplicate"),
		PmMenu.separator(),
		PmMenu.item("up", "Move up"),
		PmMenu.item("down", "Move down"),
		PmMenu.separator(),
		PmMenu.item("delete", "Delete", "", "trash"),
	]
	var m: Control = PmMenu.open(_grid, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_context.bind(id))


func _on_context(action: String, id: String) -> void:
	var s: Sequence = seq()
	if action == "apply":
		apply_preset_id(id, PackedStringArray(), s.playhead if s != null else 0.0, null)
	elif action == "edit":
		var p: Dictionary = preset_by_id(id)
		var fields: Array[Dictionary] = [{"key": "label", "label": "Name", "type": "string", "default": String(p.get("label", ""))}, {"key": "tags", "label": "Tags (comma separated)", "type": "string", "default": ", ".join(PackedStringArray(p.get("tags", [])))}]
		fields.append_array(_anchor_fields(p))
		var answered: Signal = PmUI.form(_root, "Edit preset", fields, "Save", "Cancel")
		answered.connect(_on_edit_form.bind(id))
	elif action == "fav":
		set_favourite(id, not is_favourite(id))
	elif action == "duplicate":
		duplicate_preset(id)
	elif action == "up":
		move_preset(id, -1)
	elif action == "down":
		move_preset(id, 1)
	elif action == "delete":
		delete_preset(id)


func _on_edit_form(result: Variant, id: String) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var r: Dictionary = result
	var tags: Array = []
	for t: String in String(r.get("tags", "")).split(","):
		if not t.strip_edges().is_empty():
			tags.append(t.strip_edges())
	rename_preset(id, String(r.get("label", "")), tags, r)


func rename_preset(id: String, label: String, tags: Array, anchor_answer: Dictionary = {}) -> bool:
	var p: Dictionary = preset_by_id(id)
	if p.is_empty():
		return false
	var clean: String = label.strip_edges()
	if clean.is_empty():
		Events.toast("Give the preset a name")
		return false
	p["label"] = clean
	p["tags"] = tags
	if not anchor_answer.is_empty():
		_apply_anchor_answer(p, anchor_answer)
	var ok: bool = _write(p, "Rename preset")
	rebuild()
	return ok


func duplicate_preset(id: String) -> String:
	var p: Dictionary = preset_by_id(id)
	if p.is_empty():
		return ""
	var taken: PackedStringArray = PackedStringArray()
	for other: Dictionary in all_presets():
		taken.append(String(other.get("label", "")))
	var copy: Dictionary = Presets.duplicate_of(p, taken)
	if copy.is_empty():
		Events.toast("That preset could not be copied")
		return ""
	if not _write(copy, "Duplicate preset"):
		Events.toast("That preset could not be copied")
		return ""
	rebuild()
	return String(copy["id"])


func delete_preset(id: String) -> void:
	var p: Dictionary = preset_by_id(id)
	if p.is_empty():
		return
	var d: Project = doc()
	if scope_tab == "project" and d != null and not Presets.find_project(d, id).is_empty():
		Presets.remove_from_project(d, id)
	else:
		Presets.delete_user(String(p.get("kind", "")), id)
	rebuild()


func _write(p: Dictionary, what: String) -> bool:
	var d: Project = doc()
	if scope_tab == "project" and d != null:
		return Presets.replace_in_project(d, p, what)
	return Presets.save_user(p)


func shown_ids() -> PackedStringArray:
	return Presets.ids_of(_presets)


func move_preset(id: String, by: int) -> bool:
	var ids: PackedStringArray = shown_ids()
	var at: int = ids.find(id)
	if at < 0:
		return false
	return reorder_to(id, clampi(at + by, 0, ids.size() - 1))


func reorder_to(id: String, to_index: int) -> bool:
	var ids: PackedStringArray = shown_ids()
	if ids.find(id) < 0:
		return false
	var wanted: PackedStringArray = Presets.moved_order(ids, id, to_index)
	var d: Project = doc()
	var ok: bool = false
	if scope_tab == "project" and d != null:
		ok = Presets.reorder_project(d, wanted)
	else:
		ok = Presets.reorder_user(wanted)
	rebuild()
	return ok


func _on_save_menu(anchor: Control) -> void:
	var items: Array = []
	for row: Array in SAVE_ITEMS:
		items.append(PmMenu.item(String(row[0]), String(row[1])))
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_save_picked)


func export_settings() -> Dictionary:
	var panel: Object = Bus.instance().panel("export")
	if panel != null and panel.get("settings") is Dictionary:
		return (panel.get("settings") as Dictionary).duplicate(true)
	return ExportPresets.default_settings()


func bin_media_ids() -> PackedStringArray:
	var panel: Object = Bus.instance().panel("bin")
	if panel == null:
		return PackedStringArray()
	var ids: Variant = panel.get("selected_ids")
	return (ids as PackedStringArray).duplicate() if ids is PackedStringArray else PackedStringArray()


func _on_save_picked(what: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	if what == "effect":
		_pick_effect()
		return
	if what == "asset_pack":
		var ids: PackedStringArray = bin_media_ids()
		if ids.is_empty():
			Events.toast("Mark the bin items you want in the package first")
			return
		load(SystemsPath).call("open_asset_pack_save", ids)
		return
	var c: Clip = Bus.selected_clip(s)
	var preset: Dictionary = {}
	if what == "effects":
		if c == null:
			Events.toast("Select a clip first")
			return
		preset = Presets.effect_stack_from_clip(c, c.label + " effects")
	elif what.begins_with("effect:"):
		preset = _effect_preset(c, what.substr(7))
	elif what == "transform":
		if c == null:
			Events.toast("Select a clip first")
			return
		preset = Presets.transform_from_clip(c, c.label + " transform")
	elif what == "audio_fx":
		if c == null:
			Events.toast("Select a clip first")
			return
		if c.audio_effects().is_empty():
			Events.toast("That clip has no audio effects to save")
			return
		preset = Presets.audio_fx_from_clip(c, c.label + " audio")
	elif what == "text_style":
		if c == null:
			Events.toast("Select a clip first")
			return
		var tm: MediaItem = d.media_by_id(c.media_id)
		if tm == null or tm.kind != "title":
			Events.toast("Select a title clip first")
			return
		preset = Subtitles.style_from_clip(d, c, c.label + " style")
	elif what == "stream_roles":
		if c == null:
			Events.toast("Select a clip first")
			return
		var rm: MediaItem = d.media_by_id(c.media_id)
		if rm == null:
			Events.toast("That clip has no file behind it")
			return
		if not StreamRoles.any_named(rm):
			Events.toast("Name the tracks of that file first")
			return
		preset = Presets.stream_roles_from(rm, rm.label + " track names")
	elif what == "composition":
		var cb: Dictionary = Verbs.copy(d, s)
		if (cb["clips"] as Array).is_empty():
			Events.toast("Select some clips first")
			return
		var payload: Dictionary = {"clips": cb["clips"], "span": cb["span"]}
		if cb.get("groups") is Dictionary:
			payload["groups"] = cb["groups"]
		preset = Presets.make("composition", "Composition", payload)
	elif what == "sfx_combo":
		var scb: Dictionary = Verbs.copy(d, s)
		preset = Presets.combo_from_clipboard(scb, "SFX combo")
		if preset.is_empty():
			Events.toast("Select some sound clips first")
			return
	elif what == "transition":
		var tc: Clip = Bus.selected_clip(s)
		var side: String = "in" if tc != null and tc.has_transition() else "out"
		if tc == null or (not tc.has_transition() and not tc.has_transition_out()):
			Events.toast("Select a clip with a transition first")
			return
		var tr_d: Dictionary = tc.transition_field("transition_out" if side == "out" else "transition_in")
		var Timing: GDScript = load("res://doc/transition_timing.gd")
		preset = Presets.make("transition", String(load("res://engine/transition_registry.gd").call("shared").call("label_for", tr_d)) + " preset", Timing.call("preset_payload", Timing.call("with_progress", tr_d)))
	elif what == "driver":
		var ec: Object = Bus.instance().panel("effect_controls")
		preset = ec.call("drive_preset_of_picked") if ec != null and ec.has_method("drive_preset_of_picked") else {}
		if preset.is_empty():
			Events.toast("Pick a value with drivers in Effect Controls first")
			return
	elif what == "sequence":
		preset = Presets.sequence_from(s, s.label + " settings")
	elif what == "export":
		preset = ExportPresets.make_preset(s.label + " export", export_settings())
	elif what == "export_place":
		var dest: Variant = export_settings().get("destination", {})
		var dir: String = String((dest as Dictionary).get("dir", "")) if dest is Dictionary else ""
		if dir.strip_edges().is_empty():
			Events.toast("Choose an export folder in the Export panel first")
			return
		preset = Places.to_preset(Places.make(dir.get_file() if not dir.get_file().is_empty() else "Export place", dir))
	if preset.is_empty():
		return
	var fields: Array[Dictionary] = [{"key": "label", "label": "Name", "type": "string", "default": String(preset["label"])}, {"key": "scope", "label": "Where", "type": "enum", "choices": ["Library", "This project"], "default": 0 if scope_tab == "library" else 1}]
	if String(preset.get("kind", "")) in ["effect", "effect_stack", "transform"]:
		fields.append_array(_anchor_fields(preset))
	var answered: Signal = PmUI.form(_root, "Save preset", fields, "Save", "Cancel")
	answered.connect(_on_save_form.bind(preset))


func effect_label(entry: Dictionary) -> String:
	var id: String = String(entry.get("id", ""))
	var reg: RefCounted = load("res://engine/effect_registry.gd").call("shared")
	if reg != null and bool(reg.call("has", id)):
		var def: Dictionary = reg.call("get_def", id)
		var named: String = String(def.get("label", ""))
		if not named.is_empty():
			return named
	return id.replace("_", " ").capitalize()


func _effect_preset(c: Clip, uid: String) -> Dictionary:
	if c == null:
		Events.toast("Select a clip first")
		return {}
	var entry: Dictionary = c.effect_by_uid(uid)
	if entry.is_empty():
		entry = c.audio_effect_by_uid(uid)
	if entry.is_empty():
		Events.toast("That effect is no longer on the clip")
		return {}
	return Presets.effect_from_entry(entry, effect_label(entry))


func _pick_effect() -> void:
	var s: Sequence = seq()
	var c: Clip = Bus.selected_clip(s) if s != null else null
	if c == null:
		Events.toast("Select a clip first")
		return
	var entries: Array = []
	entries.append_array(c.effects)
	entries.append_array(c.audio_effects())
	if entries.is_empty():
		Events.toast("That clip has no effects to save")
		return
	if entries.size() == 1:
		_on_save_picked("effect:" + String((entries[0] as Dictionary).get("uid", "")))
		return
	var items: Array = []
	for e: Variant in entries:
		if not (e is Dictionary):
			continue
		var ed: Dictionary = e
		items.append(PmMenu.item("effect:" + String(ed.get("uid", "")), effect_label(ed)))
	var m: Control = PmMenu.open(_grid, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_save_picked)


func _anchor_fields(p: Dictionary) -> Array[Dictionary]:
	var anchor: String = String(p.get("anchor", "start"))
	var idx: int = maxi(Presets.ANCHORS.find(anchor), 0)
	return [
		{"key": "anchor", "label": "Keys land at", "type": "enum", "choices": ["The clip start", "The clip end", "A percentage into the clip", "The playhead"], "default": idx},
		{"key": "percent", "label": "Percentage (0 to 100)", "type": "float", "default": float(p.get("percent", 0.0)) * 100.0},
		{"key": "max_length", "label": "Longest the keys may take (seconds, 0 keeps them)", "type": "float", "default": float(p.get("max_length", 0.0))},
	]


func _apply_anchor_answer(p: Dictionary, r: Dictionary) -> void:
	if r.has("anchor"):
		p["anchor"] = Presets.ANCHORS[clampi(int(r.get("anchor", 0)), 0, Presets.ANCHORS.size() - 1)]
	if r.has("percent"):
		p["percent"] = clampf(float(r.get("percent", 0.0)) / 100.0, 0.0, 1.0)
	if r.has("max_length"):
		p["max_length"] = maxf(float(r.get("max_length", 0.0)), 0.0)


func _on_save_form(result: Variant, preset: Dictionary) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	var r: Dictionary = result
	preset["label"] = String(r.get("label", preset["label"])).strip_edges()
	_apply_anchor_answer(preset, r)
	var d: Project = doc()
	if int(r.get("scope", 0)) == 1 and d != null:
		Presets.save_to_project(d, preset)
		scope_tab = "project"
	else:
		Presets.save_user(preset)
		scope_tab = "library"
	_tabs.call("set_active", scope_tab, false)
	rebuild()


func _on_doc_changed(kind: String) -> void:
	if kind == "meta" and scope_tab == "project":
		rebuild()


func _on_project_changed() -> void:
	rebuild()


func save_state() -> Dictionary:
	return {"scope": scope_tab, "kind": kind_filter}


func restore_state(d: Dictionary) -> void:
	scope_tab = String(d.get("scope", "library"))
	kind_filter = String(d.get("kind", ""))
	if _alive():
		_tabs.call("set_active", scope_tab, false)
		rebuild()


class _Grid:
	extends Control

	const IconsKit := preload("res://ui/kit/icons.gd")
	const PaintKit := preload("res://ui/timeline/timeline_paint.gd")
	const PmTextKit := preload("res://ui/kit/pm_text.gd")

	var panel: RefCounted = null
	var items: Array[Dictionary] = []
	var rects: Array[Rect2] = []
	var hover: int = -1
	var _press: Vector2 = Vector2.ZERO
	var _press_i: int = -1
	var _drag_i: int = -1
	var _drop_at: int = -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)
		mouse_exited.connect(_on_exit)
		resized.connect(_layout)

	func set_items(list: Array[Dictionary]) -> void:
		items = list
		_clear_drag()
		_layout()

	func _clear_drag() -> void:
		_press_i = -1
		_drag_i = -1
		_drop_at = -1

	func inside(p: Vector2) -> bool:
		return Rect2(Vector2.ZERO, size).has_point(p)

	func drop_index_at(p: Vector2) -> int:
		var i: int = _index_at(p)
		if i >= 0:
			return i
		if items.is_empty():
			return -1
		if p.y < 0.0:
			return 0
		return items.size() - 1

	func reorder_drop() -> bool:
		if _drag_i < 0 or _drop_at < 0 or _drag_i == _drop_at or _drag_i >= items.size():
			return false
		return bool(panel.call("reorder_to", String(items[_drag_i].get("id", "")), _drop_at))

	func _layout() -> void:
		rects.clear()
		var tw: float = float(Tk.px(TILE_W))
		var th: float = tw * 0.62 + 20.0
		var gap: float = float(Tk.px(6.0))
		var cols: int = maxi(1, int(floor((size.x - gap) / (tw + gap))))
		for i: int in items.size():
			rects.append(Rect2(gap + float(i % cols) * (tw + gap), gap + float(i / cols) * (th + gap), tw, th))
		var rows: int = (items.size() + cols - 1) / cols
		custom_minimum_size = Vector2(0.0, gap + float(rows) * (th + gap))
		queue_redraw()

	func _on_exit() -> void:
		hover = -1
		queue_redraw()

	func _on_motion(at: Vector2) -> void:
		var i: int = _index_at(at)
		if i != hover:
			hover = i
			queue_redraw()
		if _press_i < 0 or (at - _press).length() < float(Tk.px(4.0)):
			return
		if not inside(at):
			var id: String = String(items[_press_i].get("id", ""))
			_clear_drag()
			queue_redraw()
			panel.call("begin_drag", id)
			return
		_drag_i = _press_i
		var want: int = drop_index_at(at)
		if want != _drop_at:
			_drop_at = want
			queue_redraw()

	func _index_at(p: Vector2) -> int:
		for i: int in rects.size():
			if rects[i].has_point(p):
				return i
		return -1

	func _on_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			_on_motion((event as InputEventMouseMotion).position)
			return
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			var i: int = _index_at(mb.position)
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed and i >= 0 and star_rect(rects[i]).has_point(mb.position):
					var sid: String = String(items[i].get("id", ""))
					panel.call("set_favourite", sid, not bool(panel.call("is_favourite", sid)))
					_clear_drag()
					accept_event()
					return
				if mb.pressed:
					if mb.double_click and i >= 0:
						panel.call("apply_preset_id", String(items[i].get("id", "")), PackedStringArray(), 0.0, null)
						_clear_drag()
						return
					_press_i = i
					_press = mb.position
					_drag_i = -1
					_drop_at = -1
				else:
					var moved: bool = reorder_drop()
					_clear_drag()
					if not moved:
						queue_redraw()
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and i >= 0:
				panel.call("open_context", String(items[i].get("id", "")), get_global_mouse_position())
				accept_event()

	static func star_rect(r: Rect2) -> Rect2:
		var side: float = 16.0
		return Rect2(r.position.x + r.size.x - side - 3.0, r.position.y + 3.0, side, side)

	static func star_points(c: Vector2, outer: float) -> PackedVector2Array:
		var pts: PackedVector2Array = PackedVector2Array()
		for k: int in 10:
			var rad: float = outer if k % 2 == 0 else outer * 0.45
			var a: float = -PI * 0.5 + TAU * float(k) / 10.0
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		return pts

	func _draw_star(r: Rect2, on: bool, hot: bool) -> void:
		if not on and not hot:
			return
		var sr: Rect2 = star_rect(r)
		var pts: PackedVector2Array = star_points(sr.get_center(), sr.size.x * 0.45)
		if on:
			draw_colored_polygon(pts, Tk.c["text_bright"])
		else:
			pts.append(pts[0])
			draw_polyline(pts, Tk.c["text_dim"], 1.0, true)

	func _draw() -> void:
		var f: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_small"))
		if items.is_empty():
			PmTextKit.draw(self, f, Rect2(0.0, 0.0, size.x, 28.0), "No presets here yet. Save one with the plus button.", fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, 8.0, 20.0)
			return
		for i: int in items.size():
			var r: Rect2 = rects[i]
			var p: Dictionary = items[i]
			var pic: Rect2 = Rect2(r.position, Vector2(r.size.x, r.size.y - 20.0))
			draw_rect(pic, Tk.c["bg_field"], true)
			var kind: String = String(p.get("kind", ""))
			_draw_preview(pic, kind, p)
			var icon: String = String(KIND_ICONS.get(kind, "fx"))
			IconsKit.draw(self, icon, Rect2(pic.position.x + 4.0, pic.end.y - 16.0, 12.0, 12.0), Tk.c["text_dim"])
			var edge: Color = Tk.c["accent_dim"] if i == hover else Tk.c["border_soft"]
			if _drag_i >= 0 and i == _drop_at:
				edge = Tk.c["accent"]
			draw_rect(Rect2(pic.position + Vector2(0.5, 0.5), pic.size - Vector2(1.0, 1.0)), edge, false, 1.0)
			if _drag_i == i:
				draw_rect(pic, Color(Tk.c["bg_panel_high"], 0.55), true)
			_draw_star(r, bool(panel.call("is_favourite", String(p.get("id", "")))) if panel != null else false, i == hover)
			PmTextKit.draw(self, f, Rect2(r.position.x, pic.end.y, r.size.x, r.end.y - pic.end.y), String(p.get("label", "")), fs, Tk.c["text"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, r.end.y - 5.0)

	func _draw_preview(pic: Rect2, kind: String, p: Dictionary) -> void:
		var inner: Rect2 = pic.grow(-8.0)
		if kind == "composition":
			var n: int = 5
			for i: int in n:
				var w: float = inner.size.x / float(n)
				draw_rect(Rect2(inner.position.x + float(i) * w + 1.0, inner.position.y, w - 2.0, inner.size.y * 0.6), Tk.c["clip_video"], true)
			draw_rect(Rect2(inner.position.x, inner.end.y - inner.size.y * 0.3, inner.size.x, inner.size.y * 0.3), Tk.c["clip_audio"], true)
		elif kind == "sfx_combo" or kind == "audio_fx":
			var pts := PackedVector2Array()
			var seed_v: int = String(p.get("id", "")).hash()
			for i: int in 24:
				var a: float = 0.2 + 0.8 * float((seed_v + i * 7919) % 97) / 97.0
				pts.append(Vector2(inner.position.x + inner.size.x * float(i) / 23.0, inner.get_center().y - a * inner.size.y * 0.5))
			for i: int in range(23, -1, -1):
				var a2: float = 0.2 + 0.8 * float((seed_v + i * 7919) % 97) / 97.0
				pts.append(Vector2(inner.position.x + inner.size.x * float(i) / 23.0, inner.get_center().y + a2 * inner.size.y * 0.5))
			draw_colored_polygon(pts, Tk.c["wave"])
		elif kind == "transform":
			var pts2 := PackedVector2Array()
			for i: int in 20:
				var u: float = float(i) / 19.0
				pts2.append(Vector2(inner.position.x + inner.size.x * u, inner.end.y - inner.size.y * (0.5 - 0.5 * cos(u * PI))))
			draw_polyline(pts2, Tk.c["text"], 1.5, true)
			PaintKit.draw_diamond(self, pts2[0], 3.0, Tk.c["text_bright"], true)
			PaintKit.draw_diamond(self, pts2[19], 3.0, Tk.c["text_bright"], true)
		elif kind == "export":
			var f: Font = Tk.font("body")
			var fs: int = Tk.fs(Tk.sz("font_tiny"))
			var payload: Dictionary = p.get("payload", {})
			var y: float = inner.position.y + fs
			for k: Variant in payload.keys():
				if y > inner.end.y:
					break
				PmTextKit.draw_in(self, f, Rect2(inner.position.x, y - f.get_ascent(fs), inner.size.x, f.get_height(fs)), String(k) + " " + str(payload[k]), fs, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, y, PmTextKit.ELIDE, Rect2(pic.position.x, y - f.get_ascent(fs), pic.size.x, f.get_height(fs)), 8.0)
				y += fs + 2.0
		elif kind == "sequence":
			draw_rect(Rect2(inner.position + inner.size * 0.2, inner.size * 0.6), Tk.c["border_soft"], false, 1.0)
		else:
			draw_rect(Rect2(inner.position + inner.size * 0.25, inner.size * 0.5), Tk.c["bg_panel_high"], true)
			var f2: Font = Tk.font("body")
			PmTextKit.draw(self, f2, Rect2(inner.position.x - 6.0, inner.position.y, inner.size.x + 12.0, inner.size.y), "FX", Tk.fs(Tk.sz("font_tiny")), Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, 8.0, inner.end.y - 2.0 - f2.get_descent(Tk.fs(Tk.sz("font_tiny"))), PmTextKit.WHOLE)

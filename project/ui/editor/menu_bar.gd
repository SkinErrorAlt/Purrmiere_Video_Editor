extends HBoxContainer

signal picked(id: String)

const PmButton := preload("res://ui/kit/pm_button.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmIcon := preload("res://ui/kit/pm_icon.gd")
const SEP := "sep"
const MENUS: Array[Dictionary] = [
	{"id": "file", "label": "File", "items": [
		"file.new_project", "file.new_sequence", "file.new_bin", "file.new_title", SEP,
		"file.open", "file.close", SEP,
		"file.save", "file.save_as", "file.save_copy", "file.restore", "file.project_card", SEP,
		"file.import", "file.import_folder", "file.export", "file.export_frame", SEP,
		"file.import_captions", "file.export_captions", SEP,
		"file.properties", "file.reveal", "file.edit_original", SEP,
		"file.relink", "file.remove_unused", SEP,
		"file.quit"]},
	{"id": "edit", "label": "Edit", "items": [
		"edit.undo", "edit.redo", SEP,
		"edit.cut", "edit.copy", "edit.paste", "edit.paste_insert", "edit.paste_overlap", "edit.paste_attributes", "edit.duplicate", SEP,
		"edit.delete", "edit.ripple_delete", "edit.clear_selection", SEP,
		"edit.select_all", "edit.deselect_all", SEP,
		"edit.find", "app.palette", SEP,
		"edit.keyboard_shortcuts", "edit.preferences"]},
	{"id": "clip", "label": "Clip", "items": [
		"clip.enable", "clip.speed", SEP,
		"clip.remove_all_effects", "clip.toggle_all_effects", "clip.sync_regions", "clip.view_cuts", "clip.split_view_changes", "clip.offset_selected", "clip.views_panel", SEP,
		"clip.link", "clip.group", "clip.ungroup", "group.select", "group.rename", "group.lock", "group.mute", "group.add_selection", "group.remove_selection", "group.panel", SEP,
		"tracker.panel", "tool.track_area", "tracker.forward", "tracker.backward", "tracker.stop", SEP,
		"clip.bring_to_front", "clip.send_to_back", SEP,
		"clip.nest", "clip.see_inside", "clip.see_inside_all", "clip.reveal_nested", "nest.hear_audio", "group.to_nest", "nest.unnest_to_group", SEP,
		"clip.subclip", "clip.subsequence", SEP,
		"clip.audio_gain", "clip.audio_channels", SEP,
		"clip.match_frame", "clip.reverse_match_frame", "clip.freeze_frame", "clip.hold_to_end", "clip.replace_footage", SEP,
		"nav.prev_key", "nav.next_key", "keys.record"]},
	{"id": "sequence", "label": "Sequence", "items": [
		"seq.settings", "seq.new_from_clip", "seq.duplicate", SEP,
		"play.around", "play.in_to_out", "play.in_to_out_roll", "play.to_out", "play.full_quality", SEP,
		"edit.add_edit", "edit.add_edit_all", "edit.cut_at_markers", "edit.close_all_gaps", SEP,
		"edit.lift", "edit.extract", SEP,
		"tool.censor", "seq.censor_in_out", "tool.realign", SEP,
		"seq.lock_in_out", "seq.unlock_all", SEP,
		"edit.ripple_trim_prev", "edit.ripple_trim_next", "edit.extend_selected", SEP,
		"seq.default_video_transition", "seq.default_audio_transition", "seq.default_transitions", SEP,
		"seq.snap", "view.program_snap", "view.motion_paths", "seq.linked_selection", "seq.pin_track", SEP,
		"seq.overlap_clips", "seq.free_tracks", SEP,
		"nest.hear_outside", "nest.show_whole", SEP,
		"seq.render_in_to_out", "seq.render_regions", SEP,
		"view.zoom_in", "view.zoom_out", "view.zoom_sequence", "view.zoom_selection"]},
	{"id": "markers", "label": "Markers", "items": [
		"marker.add", "marker.add_clip", "marker.edit", SEP,
		"marker.clear_current", "marker.clear_all", SEP,
		"nav.next_marker", "nav.prev_marker", SEP,
		"nav.next_warning", "nav.prev_warning", SEP,
		"mark.in", "mark.out", "mark.clear_both"]},
	{"id": "window", "label": "Window", "items": []},
	{"id": "help", "label": "Help", "items": [
		"help.catalogue", "help.health", SEP,
		"help.stats", "help.about"]},
]

var window_items: Callable = Callable()
var _titles: Array[Button] = []
var _open_index: int = -1
var _menu: Control = null
var _brand: Label = null


func _init() -> void:
	name = "MenuBar"
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var lead: Control = PmUI.spacer()
	lead.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lead.custom_minimum_size = Vector2(float(Tk.px(Tk.sz("pad"))) + 2.0, 0.0)
	add_child(lead)
	var mark: Control = PmIcon.paw(float(Tk.px(18.0)), false)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(mark)
	var mark_gap: Control = PmUI.spacer()
	mark_gap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mark_gap.custom_minimum_size = Vector2(float(Tk.px(Tk.sz("gap"))) + 3.0, 0.0)
	add_child(mark_gap)
	_brand = PmLabel.headline("Purrmiere")
	_brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_brand)
	var pad: Control = PmUI.spacer()
	pad.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pad.custom_minimum_size = Vector2(float(Tk.px(Tk.sz("pad"))) * 2.0, 0.0)
	add_child(pad)
	for i: int in range(MENUS.size()):
		var m: Dictionary = MENUS[i]
		var b: Button = PmButton.make(String(m["label"]))
		b.set("quiet", true)
		b.name = "Menu_" + String(m["id"])
		b.pressed.connect(_on_title_pressed.bind(i))
		b.mouse_entered.connect(_on_title_entered.bind(i))
		add_child(b)
		_titles.append(b)


func menu_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for m: Dictionary in MENUS:
		out.append(String(m["id"]))
	return out


func command_item(id: String) -> Dictionary:
	var label: String = Cmd.label(id)
	var keys: String = Cmd.keys_text(id)
	var it: Dictionary
	if Cmd.has_toggle(id):
		it = PmMenu.check_item(id, label, Cmd.is_toggled(id), keys)
	else:
		it = PmMenu.item(id, label, keys)
	it["disabled"] = not Cmd.has(id) or not Cmd.is_enabled(id)
	return it


func items_for(index: int) -> Array:
	var m: Dictionary = MENUS[index]
	var out: Array = []
	if String(m["id"]) == "window" and window_items.is_valid():
		var extra: Variant = window_items.call()
		if typeof(extra) == TYPE_ARRAY:
			for e: Variant in extra:
				if typeof(e) == TYPE_DICTIONARY:
					out.append(e)
		var win_ids: PackedStringArray = (load("res://host/module_extras.gd").call("shared") as Object).call("menu_items", "window")
		if not win_ids.is_empty():
			out.append(PmMenu.separator())
			for wid: String in win_ids:
				out.append(command_item(wid))
		return out
	var last_sep: bool = true
	for raw: Variant in (m["items"] as Array):
		var id: String = String(raw)
		if id == SEP:
			if not last_sep:
				out.append(PmMenu.separator())
				last_sep = true
			continue
		out.append(command_item(id))
		last_sep = false
		if id == "file.open":
			out.append(_recent_item())
	var extra_ids: PackedStringArray = (load("res://host/module_extras.gd").call("shared") as Object).call("menu_items", String(m["id"]))
	if not extra_ids.is_empty():
		if out.size() > 0 and not bool((out[out.size() - 1] as Dictionary).get("sep", false)):
			out.append(PmMenu.separator())
		for xid: String in extra_ids:
			out.append(command_item(xid))
	if out.size() > 0 and bool((out[out.size() - 1] as Dictionary).get("sep", false)):
		out.remove_at(out.size() - 1)
	return out


func _recent_item() -> Dictionary:
	var HomeScreen: GDScript = load("res://ui/editor/home_screen.gd")
	var list: PackedStringArray = HomeScreen.call("recent")
	var sub: Array = []
	for p: String in list:
		sub.append(PmMenu.item("recent:" + p, p.get_file().get_basename()))
	if sub.is_empty():
		var none: Dictionary = PmMenu.item("recent:none", "Nothing yet")
		none["disabled"] = true
		sub.append(none)
	return PmMenu.sub_item("recent", "Open recent", sub, "folder")


func is_open() -> bool:
	return _open_index >= 0 and _menu != null and is_instance_valid(_menu)


func open_index(index: int) -> void:
	if index < 0 or index >= _titles.size():
		return
	if _open_index == index and is_open():
		return
	close_menu()
	var b: Button = _titles[index]
	var items: Array = items_for(index)
	if items.is_empty():
		return
	_open_index = index
	_menu = PmMenu.open(b, items)
	if _menu == null or not _menu.is_inside_tree():
		_menu = null
		_open_index = -1
		return
	b.set("active", true)
	_menu.connect("picked", _on_picked)
	_menu.connect("closed", _on_closed.bind(index))


func close_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		var m: Control = _menu
		_menu = null
		m.call("close")
	if _open_index >= 0 and _open_index < _titles.size():
		_titles[_open_index].set("active", false)
	_open_index = -1


func _on_title_pressed(index: int) -> void:
	if _open_index == index and is_open():
		close_menu()
	else:
		open_index(index)


func _on_title_entered(index: int) -> void:
	if is_open() and _open_index != index:
		open_index(index)


func _process(_dt: float) -> void:
	if not is_open():
		return
	var mouse: Vector2 = get_global_mouse_position()
	for i: int in range(_titles.size()):
		if i != _open_index and _titles[i].get_global_rect().has_point(mouse):
			open_index(i)
			return


func _on_picked(id: String) -> void:
	picked.emit(id)


func _on_closed(index: int) -> void:
	if _open_index == index:
		_menu = null
		_open_index = -1
		if index < _titles.size():
			_titles[index].set("active", false)

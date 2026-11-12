extends "res://modules/core_panels/panel_base.gd"

const ViewMap := preload("res://doc/view_map.gd")
const ViewsCommands := preload("res://modules/core_panels/views_commands.gd")
const ViewSwitch := preload("res://doc/view_switch.gd")
const PairCmds := preload("res://doc/commands/pair_cmds.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const Command := preload("res://doc/commands/command.gd")
const PvAudio := preload("res://modules/core_panels/pv_audio.gd")
const Solo := preload("res://ui/timeline/timeline_view_solo.gd")
const PANEL_ID := "views"
const VIEW_PREFIX := "clip.view_"
const VIEW_KEYS := 8
const NARROW_W := 260.0
const MENU_SWITCH := "switch"
const MENU_SHOW := "show_ec"
const MENU_COLOUR := "view_colour:"
const COLOUR_COUNT := 16
const PROVIDER_LAYOUT_ITEMS := "views_layout_items"
const PROVIDER_LAYOUT_PICKED := "views_layout_picked"
const PROVIDER_REGION_ITEMS := "views_region_items"
const PROVIDER_REGION_PICKED := "views_region_picked"
const TEXT_NO_SEQ := "Open a sequence to switch views"
const TEXT_NO_CLIP := "No clip at the playhead"
const TEXT_NO_CLIP_DETAIL := "Move the playhead over a clip with a Pair View, or select one."
const TEXT_NO_PV := "This clip has no Pair View"
const TEXT_NO_PV_DETAIL := "A Pair View shows named regions of one recording, one at a time or all at once. Add one to switch between its views here."

static var _providers: Array[Object] = []

var _name_label: Label = null
var _meta_label: Label = null
var _layout_btn: Button = null
var _more_btn: Button = null
var _scroll: ScrollContainer = null
var _grid: Container = null
var _empty: VBoxContainer = null
var _empty_head: Label = null
var _empty_detail: Label = null
var _empty_add: Button = null
var _foot: Label = null
var _foot_line: Control = null
var _head: HBoxContainer = null
var _buttons: Array[Control] = []
var _clip_id: String = ""
var _uid: String = ""
var _names: PackedStringArray = PackedStringArray()
var _sig: String = ""
var _active: int = -1
var _empty_clip_id: String = ""
var _changes_key: String = ""
var _changes: Array[Dictionary] = []
var _queued: bool = false
var _thumbs_on: bool = false
var _refreshes: int = 0
var _rebuilds: int = 0
var _sound: VBoxContainer = null
var _sound_box: Control = null
var _sound_sig: String = ""
var _groups_strip: Control = null
const GroupStrip := preload("res://modules/core_panels/views_group_strip.gd")


static func add_menu_provider(provider: Object) -> void:
	if provider != null and not _providers.has(provider):
		_providers.append(provider)


static func remove_menu_provider(provider: Object) -> void:
	_providers.erase(provider)


static func providers() -> Array[Object]:
	return _providers


func _build(root_: Control) -> void:
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_head = head
	_name_label = PmLabel.trim("", "text")
	_name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_name_label.size_flags_horizontal = Control.SIZE_FILL
	head.add_child(_name_label)
	_meta_label = PmLabel.meta("")
	head.add_child(_meta_label)
	head.add_child(PmUI.spacer())
	_layout_btn = PmButton.make("Layout", "chev_d")
	_layout_btn.set("quiet", true)
	PmUI.tip(_layout_btn, "Layout presets for this Pair View")
	_layout_btn.pressed.connect(_on_layout)
	_layout_btn.visible = false
	head.add_child(_layout_btn)
	head.add_child(load("res://modules/core_panels/record_button.gd").call("make_record"))
	_more_btn = quiet_icon("more", "More")
	_more_btn.pressed.connect(_on_more)
	head.add_child(_more_btn)
	_groups_strip = GroupStrip.new()
	col.add_child(PmUI.inset(_groups_strip, float(Tk.px(6.0)), 2.0))
	_scroll = vscroll_area(col)
	_grid = _ViewGrid.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)
	_empty = PmUI.vbox(Tk.px(8.0))
	_empty.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_head = PmLabel.body("", "text")
	_empty_head.add_theme_font_override("font", Tk.font("body_semibold"))
	_empty_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty.add_child(_empty_head)
	_empty_detail = PmLabel.wrap("", "text_dim")
	_empty_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_child(_empty_detail)
	var add_row: HBoxContainer = PmUI.hbox(0)
	add_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty_add = PmButton.make("Add Pair View", "plus")
	PmUI.tip(_empty_add, "Adds a Pair View to the clip at the playhead")
	_empty_add.pressed.connect(_on_add_pair_view)
	add_row.add_child(_empty_add)
	_empty.add_child(add_row)
	col.add_child(PmUI.inset(_empty, float(Tk.px(6.0)), float(Tk.px(6.0))))
	(_empty.get_parent() as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sound = PmUI.vbox(Tk.px(2.0))
	_sound_box = PmUI.inset(_sound, float(Tk.px(6.0)), 2.0)
	_sound_box.visible = false
	col.add_child(_sound_box)
	_foot_line = PmUI.divider()
	col.add_child(_foot_line)
	_foot = PmLabel.trim("", "text_dim")
	_foot.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_small")))
	_foot.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(PmUI.inset(_foot, 2.0, 2.0))
	head.resized.connect(_fit_name)
	if not Session.recording_changed.is_connected(_on_recording):
		Session.recording_changed.connect(_on_recording)
	if not Cmd.registry_changed.is_connected(_on_keys_changed):
		Cmd.registry_changed.connect(_on_keys_changed)
	if Cmd.has_signal("keymap_changed") and not Cmd.is_connected("keymap_changed", _on_keymap_changed):
		Cmd.connect("keymap_changed", _on_keymap_changed)
	if not Tk.tokens_changed.is_connected(_on_tokens):
		Tk.tokens_changed.connect(_on_tokens)
	root_.visibility_changed.connect(_on_visibility)
	load("res://modules/core_panels/effect_drop.gd").call("attach_views", root_, Callable(self, "view_at"), Callable(self, "target"), Callable(self, "button"))
	refresh()


func stats() -> Dictionary:
	return {"refreshes": _refreshes, "rebuilds": _rebuilds}


func target() -> Dictionary:
	return {"clip_id": _clip_id, "uid": _uid}


func target_clip() -> Clip:
	var s: Sequence = seq()
	if s == null or _clip_id.is_empty():
		return null
	return s.clip_by_id(_clip_id)


func view_names() -> PackedStringArray:
	return _names


func active_view() -> int:
	return _active


func buttons() -> Array[Control]:
	return _buttons


func button(index: int) -> Control:
	if index < 0 or index >= _buttons.size():
		return null
	return _buttons[index]


func view_at(local_pos: Vector2) -> int:
	if not _alive():
		return -1
	return view_at_global(_root.get_global_transform() * local_pos)


func view_at_global(global_pos: Vector2) -> int:
	if _grid == null or not _grid.is_visible_in_tree():
		return -1
	for b: Control in _buttons:
		if is_instance_valid(b) and b.visible and b.get_global_rect().has_point(global_pos):
			return int(b.get("index"))
	return -1


func is_open() -> bool:
	return _alive() and _root.is_inside_tree() and _root.is_visible_in_tree()


func handle_key(e: InputEventKey) -> bool:
	if not e.pressed or e.echo:
		return false
	var index: int = key_view(e)
	if index < 0:
		return false
	switch_to(index)
	return true


static func key_view(e: InputEventKey) -> int:
	var key: String = Cmd.key_string(e)
	if key.is_empty():
		return -1
	for i: int in VIEW_KEYS:
		if key in Cmd.keys_for(VIEW_PREFIX + str(i + 1)):
			return i
	return -1


static func key_text(index: int) -> String:
	if index < 0 or index >= VIEW_KEYS:
		return ""
	return Cmd.keys_text(VIEW_PREFIX + str(index + 1))


func switch_to(index: int) -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return false
	_refresh_now()
	var c: Clip = target_clip()
	if c == null or _uid.is_empty():
		Events.toast(TEXT_NO_CLIP if _empty_clip_id.is_empty() else TEXT_NO_PV)
		return false
	var name_: String = _names[index] if index >= 0 and index < _names.size() else "View " + str(index + 1)
	if index < 0 or index >= _names.size():
		Events.toast(ViewSwitch.why_text(ViewSwitch.WHY_RANGE, str(index + 1)))
		return false
	var cmd: Command = PairCmds.SwitchView.new(s.id, c.id, _uid, index, playhead(), bool(Session.recording))
	var label: String = "Switch view to " + name_
	cmd.label = label
	if not Verbs.run(d, label, [cmd]):
		var why: String = String(cmd.get("why"))
		if why != ViewSwitch.WHY_SAME:
			Events.toast(ViewSwitch.why_text(why, name_))
		return false
	_refresh_now()
	return true


func refresh() -> void:
	_refresh_now()


func _queue() -> void:
	if _queued or not _alive() or not _root.is_inside_tree():
		return
	_queued = true
	_root.get_tree().process_frame.connect(_on_queued, CONNECT_ONE_SHOT)


func _on_queued() -> void:
	_queued = false
	if _alive() and _root.is_visible_in_tree():
		_refresh_now()


func _refresh_now() -> void:
	if not _alive():
		return
	_refreshes += 1
	var s: Sequence = seq()
	if s == null:
		_show_empty(TEXT_NO_SEQ, "", "")
		return
	var t: float = playhead()
	var c: Clip = ViewSwitch.pick_clip(s, t)
	var e: Dictionary = ViewSwitch.pair_entry(c)
	if c == null or e.is_empty():
		var under: Clip = ViewSwitch.under_playhead(s, t)
		if under == null:
			_show_empty(TEXT_NO_CLIP, TEXT_NO_CLIP_DETAIL, "")
		else:
			_show_empty(TEXT_NO_PV, TEXT_NO_PV_DETAIL, under.id)
		return
	_empty_clip_id = ""
	var names: PackedStringArray = ViewMap.region_names(e)
	var count: int = maxi(ViewMap.crop_count(e), 1)
	while names.size() < count:
		names.append("View " + str(names.size() + 1))
	if names.size() > count:
		names = names.slice(0, count)
	var map: Dictionary = ViewMap.of(e)
	var colours: PackedInt32Array = PackedInt32Array()
	for i: int in count:
		colours.append(ViewMap.colour_for(map, i))
	var keys: PackedStringArray = PackedStringArray()
	for i2: int in count:
		keys.append(key_text(i2))
	var uid: String = String(e.get("uid", ""))
	var sig: String = "%s|%s|%s|%s|%s|%s|%s" % [c.id, uid, "\t".join(names), str(colours), "\t".join(keys), Tk.theme_id, str(Prefs.get_value("ui.mono_labels")) if Prefs.is_registered("ui.mono_labels") else ""]
	_clip_id = c.id
	_uid = uid
	_names = names
	if sig != _sig or _buttons.size() != count:
		_sig = sig
		_rebuild_buttons(c, e, names, colours, keys)
	_scroll.visible = true
	_empty.visible = false
	_update_head(c, t)
	_groups_strip.call("show_for", s, c, e)
	(_groups_strip.get_parent() as Control).visible = _groups_strip.visible
	var now: int = _view_now(c, e, t)
	if now != _active:
		_active = now
		for b: Control in _buttons:
			b.set("lit", int(b.get("index")) == _active)
	_update_foot(c, e, t)
	_update_tips(c, e)
	_refresh_sound(c, e)
	_thumbs_on = false
	for b2: Control in _buttons:
		if bool(b2.call("thumb_room")):
			_thumbs_on = true
			b2.queue_redraw()


func _refresh_sound(c: Clip, e: Dictionary) -> void:
	if _sound == null:
		return
	var sig: String = PvAudio.strip_sig(seq(), c, e)
	if sig == _sound_sig:
		return
	_sound_sig = sig
	PmUI.clear(_sound)
	if sig.is_empty():
		_sound_box.visible = false
		return
	var made: Control = PvAudio.strip(c, e, 0.0)
	_sound.add_child(made)
	_sound_box.visible = made.visible


func _show_empty(head: String, detail: String, clip_id: String) -> void:
	if _groups_strip != null:
		_groups_strip.call("clear_strip")
		(_groups_strip.get_parent() as Control).visible = false
	_clip_id = ""
	_uid = ""
	_names = PackedStringArray()
	_active = -1
	_empty_clip_id = clip_id
	if not _buttons.is_empty():
		PmUI.clear(_grid)
		_buttons.clear()
		_sig = ""
	_scroll.visible = false
	_empty.visible = true
	_empty_head.text = head
	_empty_detail.text = detail
	_empty_detail.visible = not detail.is_empty()
	(_empty_add.get_parent() as Control).visible = not clip_id.is_empty()
	var s: Sequence = seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null and not clip_id.is_empty() else null
	_name_label.text = _clip_label(c) if c != null else ("No clip" if s != null else "No sequence")
	PmLabel.set_colour(_name_label, "text" if c != null else "text_dim")
	_meta_label.text = "AT THE PLAYHEAD" if c != null else ""
	_meta_label.visible = c != null
	_layout_btn.visible = false
	_foot.text = ""
	PmUI.tip(_foot, "")
	_foot.visible = false
	_foot_line.visible = false
	_refresh_sound(null, {})
	_fit_name()


func _clip_label(c: Clip) -> String:
	if c == null:
		return ""
	if not c.label.is_empty():
		return c.label
	var d: Project = doc()
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	if m != null:
		var shown: String = m.label if not m.label.is_empty() else m.path.get_file()
		if not shown.is_empty():
			return shown
	return "Clip"


func _update_head(c: Clip, t: float) -> void:
	var text: String = _clip_label(c)
	_name_label.text = text
	PmLabel.set_colour(_name_label, "text")
	PmUI.tip(_name_label, text)
	var meta: String = "AT THE PLAYHEAD" if ViewSwitch.covers(c, t) else "SELECTED CLIP"
	_meta_label.text = meta
	var narrow: bool = _root.size.x < float(Tk.px(NARROW_W))
	_meta_label.visible = not narrow
	_layout_btn.visible = not narrow and _has_layouts()
	_fit_name()


func _fit_name() -> void:
	if _name_label == null or _head == null or not is_instance_valid(_head):
		return
	var font: Font = _name_label.get_theme_font("font")
	var fs: int = _name_label.get_theme_font_size("font_size")
	var pad: float = float(Tk.px(Tk.sz("pad")))
	var need: float = (font.get_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if font != null else 0.0) + pad
	var others: float = 0.0
	var shown: int = 0
	for ch: Node in _head.get_children():
		if not (ch is Control) or not (ch as Control).visible:
			continue
		shown += 1
		if ch != _name_label:
			others += (ch as Control).get_combined_minimum_size().x
	var sep: float = float(_head.get_theme_constant("separation")) * float(maxi(shown - 1, 0))
	var room: float = _head.size.x - others - sep
	var want: float = floorf(clampf(need, 0.0, maxf(room, 0.0)))
	if absf(_name_label.custom_minimum_size.x - want) >= 1.0:
		_name_label.custom_minimum_size.x = want


func _update_foot(c: Clip, e: Dictionary, t: float) -> void:
	var keyed: bool = AnimProp.is_animated(ViewMap.prop_of(e, ViewSwitch.VIEW_KEY))
	var rec: bool = bool(Session.recording)
	var text: String = ""
	if (rec or keyed) and not ViewSwitch.covers(c, t):
		text = "Move the playhead onto the clip to key its view."
	elif rec:
		text = "Record on: a click keys that view at the playhead."
	elif keyed:
		text = "View is keyed: a click keys that view at the playhead."
	else:
		text = "Record off: a click sets the view."
	var first: String = key_text(0)
	var last: String = key_text(maxi(_names.size() - 1, 0))
	if not first.is_empty() and _names.size() > 1:
		text += " Keys " + first + (" and " if _names.size() == 2 else " to ") + last + " work here and in the Program monitor."
	elif not first.is_empty():
		text += " Key " + first + " works here and in the Program monitor."
	_foot.text = text
	_foot.visible = true
	_foot_line.visible = true
	var tip: String = text
	if rec:
		tip += " Each click writes a hold key that switches to exactly that view, one undo step each."
	PmUI.tip(_foot, tip)


func _update_tips(_c: Clip, e: Dictionary) -> void:
	var keyed: bool = AnimProp.is_animated(ViewMap.prop_of(e, ViewSwitch.VIEW_KEY))
	var rec: bool = bool(Session.recording)
	for b: Control in _buttons:
		var i: int = int(b.get("index"))
		var name_: String = _names[i] if i < _names.size() else ""
		var tip: String = "Switch to " + name_
		if rec:
			tip += ". Record is on: writes a key at the playhead that switches to " + name_
		elif keyed:
			tip += ". View is keyed: writes a key at the playhead"
		PmUI.tip(b, tip, key_text(i))


func _view_now(c: Clip, e: Dictionary, t: float) -> int:
	var d: Project = doc()
	var ck: String = c.id + "|" + String(e.get("uid", "")) + "|" + (str(d.serial) + "|" + str(d.undo.live_serial) if d != null else "")
	if ck != _changes_key:
		_changes_key = ck
		_changes = ViewMap.changes(e, c)
	var u: float = clampf(t - c.start, 0.0, maxf(c.duration, 0.0))
	return view_in(_changes, u)


static func view_in(changes: Array[Dictionary], u: float) -> int:
	var n: int = changes.size()
	if n == 0:
		return -1
	var lo: int = 0
	var hi: int = n - 1
	if float(changes[0]["u"]) > u + ViewMap.HEARD_EPS:
		return int(changes[0]["view"])
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if float(changes[mid]["u"]) <= u + ViewMap.HEARD_EPS:
			lo = mid
		else:
			hi = mid - 1
	return int(changes[lo]["view"])


func _rebuild_buttons(c: Clip, e: Dictionary, names: PackedStringArray, colours: PackedInt32Array, keys: PackedStringArray) -> void:
	_rebuilds += 1
	PmUI.clear(_grid)
	_buttons.clear()
	_active = -1
	var crops: Array = _crop_rects(e)
	for i: int in names.size():
		var b: Control = _ViewButton.new()
		b.set("index", i)
		b.set("view_name", names[i])
		b.set("colour_index", colours[i] if i < colours.size() else -1)
		b.set("key", keys[i] if i < keys.size() else "")
		b.set("clip_id", c.id)
		b.set("region", crops[i] if i < crops.size() else Rect2(0.0, 0.0, 1.0, 1.0))
		b.name = "View_" + str(i)
		b.connect("clicked", _on_button_clicked)
		b.connect("menu_asked", _on_button_menu)
		_grid.add_child(b)
		_buttons.append(b)
	_grid.queue_sort()


func _crop_rects(e: Dictionary) -> Array:
	var out: Array = []
	var params: Dictionary = e.get("params", {})
	var raw: Variant = params.get("crops", null)
	if not (raw is Dictionary):
		return out
	var parsed: Variant = JSON.parse_string(String(AnimProp.static_value(raw)).strip_edges())
	if not (parsed is Array):
		return out
	for cr: Variant in parsed:
		var r: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
		if cr is Dictionary and (cr as Dictionary).get("rect") is Array and ((cr as Dictionary)["rect"] as Array).size() >= 4:
			var a: Array = (cr as Dictionary)["rect"]
			r = Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
		out.append(r)
	return out


func _on_button_clicked(index: int) -> void:
	switch_to(index)


func _on_button_menu(index: int, at: Vector2) -> void:
	var c: Clip = target_clip()
	if c == null or index < 0 or index >= _names.size():
		return
	var items: Array = [PmMenu.item(MENU_SWITCH, "Switch to " + _names[index], key_text(index)), PmMenu.item(MENU_SHOW, "Show in Effect Controls")]
	items.append(PmMenu.check_item(Solo.MENU_SOLO + _names[index], "Solo " + _names[index] + " on the timeline", Solo.view_name(seq()) == _names[index]))
	items.append(PmMenu.sub_item("view_colour_menu", "Colour", colour_items(index)))
	var extra: Array = []
	for p: Object in _providers:
		if is_instance_valid(p) and p.has_method(PROVIDER_REGION_ITEMS):
			var got: Variant = p.call(PROVIDER_REGION_ITEMS, c, _uid, index)
			if got is Array:
				extra.append_array(got)
	if not extra.is_empty():
		items.append(PmMenu.separator())
		items.append_array(extra)
	var anchor: Control = button(index)
	var m: Control = PmMenu.open(anchor if anchor != null else _root, items, at)
	if m != null:
		m.connect("picked", _on_region_menu_picked.bind(index, c.id, _uid))


func colour_items(index: int) -> Array:
	var e: Dictionary = ViewSwitch.pair_entry(target_clip())
	var picked: int = ViewMap.picked_colour(ViewMap.of(e), index) if not e.is_empty() else -1
	var out: Array = [PmMenu.check_item(MENU_COLOUR + "-1", "Pick its own", picked < 0)]
	out.append(PmMenu.separator())
	for i: int in COLOUR_COUNT:
		out.append(PmMenu.check_item(MENU_COLOUR + str(i), Tk.label_name(i), picked == i))
	return out


func _on_region_menu_picked(id: String, index: int, clip_id: String, uid: String) -> void:
	if id.begins_with(MENU_COLOUR):
		ViewsCommands.set_view_colour(clip_id, uid, index, int(id.substr(MENU_COLOUR.length())))
		return
	if id == MENU_SWITCH:
		switch_to(index)
		return
	if id == MENU_SHOW:
		show_in_effect_controls(clip_id)
		return
	if Solo.on_menu(doc(), seq(), id):
		return
	for p: Object in _providers:
		if is_instance_valid(p) and p.has_method(PROVIDER_REGION_PICKED) and bool(p.call(PROVIDER_REGION_PICKED, id, clip_id, uid, index)):
			return


func _has_layouts() -> bool:
	for p: Object in _providers:
		if is_instance_valid(p) and p.has_method(PROVIDER_LAYOUT_ITEMS):
			return true
	return false


func layout_items() -> Array:
	var out: Array = []
	var c: Clip = target_clip()
	if c == null:
		return out
	for p: Object in _providers:
		if is_instance_valid(p) and p.has_method(PROVIDER_LAYOUT_ITEMS):
			var got: Variant = p.call(PROVIDER_LAYOUT_ITEMS, c, _uid)
			if got is Array:
				out.append_array(got)
	return out


func _on_layout() -> void:
	var items: Array = layout_items()
	if items.is_empty():
		Events.toast("No layout presets are installed")
		return
	var m: Control = PmMenu.open(_layout_btn, items)
	if m != null:
		m.connect("picked", _on_layout_picked.bind(_clip_id, _uid))


func _on_layout_picked(id: String, clip_id: String, uid: String) -> void:
	for p: Object in _providers:
		if is_instance_valid(p) and p.has_method(PROVIDER_LAYOUT_PICKED) and bool(p.call(PROVIDER_LAYOUT_PICKED, id, clip_id, uid)):
			return


func _on_more() -> void:
	var items: Array = []
	var show: Dictionary = PmMenu.item(MENU_SHOW, "Show in Effect Controls")
	show["disabled"] = target_clip() == null
	items.append(show)
	var tc: Clip = target_clip()
	items.append_array(GroupStrip.more_items(tc, ViewSwitch.pair_entry(tc) if tc != null else {}))
	var solo_items: Array = Solo.menu_items(seq(), Solo.overlap_count(doc(), seq()))
	if not solo_items.is_empty():
		items.append(PmMenu.separator())
		items.append_array(solo_items)
	var m: Control = PmMenu.open(_more_btn, items)
	if m != null:
		m.connect("picked", _on_more_picked)


func _on_more_picked(id: String) -> void:
	if id == MENU_SHOW:
		show_in_effect_controls(_clip_id)
		return
	if GroupStrip.more_picked(id, _clip_id, _uid):
		return
	Solo.on_menu(doc(), seq(), id)


func show_in_effect_controls(clip_id: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or s.clip_by_id(clip_id) == null:
		return
	Verbs.select(d, s, PackedStringArray([clip_id]))
	var EditCommands: GDScript = load("res://modules/core_panels/edit_commands.gd")
	EditCommands.call("show_panel", "effect_controls")


func add_pair_view() -> bool:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null or _empty_clip_id.is_empty():
		return false
	var c: Clip = s.clip_by_id(_empty_clip_id)
	var def: Dictionary = EffectSource.get_def(ViewMap.PAIR_VIEW_ID)
	if c == null or def.is_empty():
		Events.toast("The Pair View effect is not installed")
		return false
	var ok: bool = Verbs.add_effect(d, s, PackedStringArray([c.id]), def)
	_refresh_now()
	return ok


func _on_add_pair_view() -> void:
	add_pair_view()


func _on_playhead(_t: float) -> void:
	_queue()


func _on_doc_changed(_kind: String) -> void:
	_queue()


func _on_history() -> void:
	_queue()


func _on_project_changed() -> void:
	_sig = ""
	_changes_key = ""
	_queue()


func _on_sequence_changed(_id: String) -> void:
	_sig = ""
	_changes_key = ""
	_queue()


func _on_compositor() -> void:
	_queue()


func _on_recording(_on: bool) -> void:
	_queue()


func _on_keys_changed() -> void:
	_queue()


func _on_keymap_changed(_name: Variant = null) -> void:
	_queue()


func _on_tokens() -> void:
	_sig = ""
	_queue()


func _on_visibility() -> void:
	if _alive() and _root.is_visible_in_tree():
		_queue()


func _on_pref_changed(key: String) -> void:
	if key == "ui.mono_labels":
		_sig = ""
		_queue()


class _ViewGrid:
	extends Container

	const NARROW := 260.0
	const MIN_W := 120.0
	const MIN_H := 40.0
	const MAX_H := 260.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func columns_for(n: int, w: float) -> int:
		if n <= 1:
			return 1
		var gap: float = float(Tk.px(Tk.sz("pad")))
		var pad: float = gap
		if w < float(Tk.px(NARROW)):
			return 1
		var want: int = n
		if n >= 3 and n <= 4:
			want = 2
		elif n >= 5 and n <= 6:
			want = 3
		elif n >= 7:
			want = 4
		var fit: int = maxi(int(floor((w - pad * 2.0 + gap) / (float(Tk.px(MIN_W)) + gap))), 1)
		return clampi(mini(want, fit), 1, n)

	func _get_minimum_size() -> Vector2:
		var n: int = get_child_count()
		if n == 0:
			return Vector2.ZERO
		var gap: float = float(Tk.px(Tk.sz("pad")))
		var cols: int = columns_for(n, size.x)
		var rows: int = int(ceil(float(n) / float(cols)))
		return Vector2(0.0, gap * 2.0 + float(rows) * float(Tk.px(MIN_H)) + float(rows - 1) * gap)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			_lay_out()
		elif what == NOTIFICATION_RESIZED:
			update_minimum_size()

	func _lay_out() -> void:
		var kids: Array[Control] = []
		for ch: Node in get_children():
			if ch is Control and (ch as Control).visible:
				kids.append(ch as Control)
		var n: int = kids.size()
		if n == 0:
			return
		var gap: float = float(Tk.px(Tk.sz("pad")))
		var cols: int = columns_for(n, size.x)
		var rows: int = int(ceil(float(n) / float(cols)))
		var w: float = maxf((size.x - gap * 2.0 - float(cols - 1) * gap) / float(cols), 1.0)
		var room_h: float = size.y - gap * 2.0 - float(rows - 1) * gap
		var h: float = clampf(room_h / float(rows), float(Tk.px(MIN_H)), float(Tk.px(MAX_H)))
		for i: int in n:
			var r: int = i / cols
			var cidx: int = i % cols
			fit_child_in_rect(kids[i], Rect2(gap + float(cidx) * (w + gap), gap + float(r) * (h + gap), w, h))


class _ViewButton:
	extends Control

	signal clicked(index: int)
	signal menu_asked(index: int, at: Vector2)

	const PmTextKit := preload("res://ui/kit/pm_text.gd")
	const PRESS_SCALE := 0.985
	const THUMB_MIN_H := 64.0
	const ROW_H := 28.0

	var index: int = 0
	var view_name: String = "":
		set(v):
			view_name = v
			queue_redraw()
	var colour_index: int = -1:
		set(v):
			colour_index = v
			queue_redraw()
	var key: String = "":
		set(v):
			key = v
			queue_redraw()
	var lit: bool = false:
		set(v):
			if v == lit:
				return
			lit = v
			queue_redraw()
	var clip_id: String = ""
	var region: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
	var hover: bool = false
	var press: float = 0.0
	var _press_tween: Tween = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		clip_contents = true
		gui_input.connect(_on_input)
		mouse_entered.connect(_on_hover.bind(true))
		mouse_exited.connect(_on_hover.bind(false))

	func _on_hover(on: bool) -> void:
		hover = on
		queue_redraw()

	func _on_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton):
			return
		var mb: InputEventMouseButton = event
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			_pulse()
			clicked.emit(index)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			menu_asked.emit(index, mb.global_position)

	func _pulse() -> void:
		if _press_tween != null and _press_tween.is_valid():
			_press_tween.kill()
		press = 1.0
		queue_redraw()
		var d: float = Tk.dur("fast")
		if d <= 0.0 or not is_inside_tree():
			press = 0.0
			return
		_press_tween = create_tween()
		Tk.ease(_press_tween)
		_press_tween.tween_method(_set_press, 1.0, 0.0, d)

	func _set_press(v: float) -> void:
		press = v
		queue_redraw()

	func body_colour() -> Color:
		if colour_index < 0:
			return Tk.c["bg_panel_high"]
		return Tk.label_colour(colour_index).darkened(0.45)

	func swatch_colour() -> Color:
		if colour_index < 0:
			return Tk.c["text_dim"]
		return Tk.label_colour(colour_index)

	func ink() -> Color:
		var body: Color = body_colour()
		var a: Color = Tk.c["text_bright"]
		var b: Color = Tk.c["inv"]
		var light: Color = a if a.get_luminance() > b.get_luminance() else b
		var dark: Color = b if a.get_luminance() > b.get_luminance() else a
		return light if body.get_luminance() < 0.5 else dark

	func thumb_room() -> bool:
		return size.y >= float(Tk.px(THUMB_MIN_H))

	func name_font() -> Font:
		return Tk.font("body_semibold")

	func name_size() -> int:
		return Tk.fs(13.0)

	func _source_texture() -> Texture2D:
		var comp: Node = Session.compositor
		if comp == null or clip_id.is_empty():
			return null
		var layers: Variant = comp.get("layers")
		if not (layers is Dictionary) or not (layers as Dictionary).has(clip_id):
			return null
		var l: Variant = (layers as Dictionary)[clip_id]
		if not (l is Object) or not is_instance_valid(l):
			return null
		var src: Variant = (l as Object).get("source")
		if not (src is Object) or not is_instance_valid(src) or not (src as Object).has_method("texture"):
			return null
		var tex: Variant = (src as Object).call("texture")
		return tex if tex is Texture2D else null

	func thumb_rect() -> Rect2:
		var pad: float = float(Tk.px(Tk.sz("pad")))
		var row_h: float = float(Tk.px(ROW_H))
		return Rect2(pad, pad, maxf(size.x - pad * 2.0, 0.0), maxf(size.y - pad - row_h, 0.0))

	func row_rect() -> Rect2:
		var row_h: float = float(Tk.px(ROW_H))
		if thumb_room():
			return Rect2(0.0, size.y - row_h, size.x, row_h)
		return Rect2(0.0, (size.y - row_h) * 0.5, size.x, row_h)

	func key_rect() -> Rect2:
		if key.is_empty():
			return Rect2()
		var pad: float = float(Tk.px(Tk.sz("pad")))
		var f: Font = Tk.font("mono")
		var fs: int = Tk.fs(11.0)
		var side: float = float(Tk.px(18.0))
		var w: float = maxf(side, PmTextKit.width_of(f, key, fs) + PmTextKit.chip_pad() * 2.0)
		var rr: Rect2 = row_rect()
		return Rect2(size.x - pad - w, rr.position.y + (rr.size.y - side) * 0.5, w, side)

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		if r.size.x < 2.0 or r.size.y < 2.0:
			return
		if press > 0.0:
			var sc: float = lerpf(1.0, PRESS_SCALE, press)
			var mid: Vector2 = size * 0.5
			draw_set_transform(mid - mid * sc, 0.0, Vector2(sc, sc))
		var radius: int = Tk.px(Tk.sz("radius"))
		var sb := StyleBoxFlat.new()
		sb.bg_color = body_colour()
		sb.set_corner_radius_all(radius)
		var ring: int = 2 if lit else 1
		sb.set_border_width_all(ring)
		sb.border_color = Tk.c["sol"] if lit else Tk.c["border_soft"]
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		var pad: float = float(Tk.px(Tk.sz("pad")))
		if thumb_room():
			var tr: Rect2 = thumb_rect()
			if tr.size.x > 4.0 and tr.size.y > 4.0:
				draw_rect(tr, Tk.c["bg_app"], true)
				_draw_thumb(tr)
		var ink_col: Color = ink()
		var rr: Rect2 = row_rect()
		var sw_side: float = float(Tk.px(10.0))
		var sw: Rect2 = Rect2(pad, rr.position.y + (rr.size.y - sw_side) * 0.5, sw_side, sw_side)
		var swb := StyleBoxFlat.new()
		swb.bg_color = swatch_colour()
		swb.set_corner_radius_all(Tk.px(3.0))
		draw_style_box(swb, sw)
		var right: float = size.x - pad
		var kr: Rect2 = key_rect()
		if kr.has_area():
			var kb := StyleBoxFlat.new()
			kb.bg_color = Color(0, 0, 0, 0)
			kb.set_border_width_all(1)
			kb.border_color = Color(ink_col.r, ink_col.g, ink_col.b, 0.4)
			kb.set_corner_radius_all(Tk.px(5.0))
			draw_style_box(kb, kr)
			PmTextKit.draw(self, Tk.font("mono"), kr, key, Tk.fs(11.0), ink_col, HORIZONTAL_ALIGNMENT_CENTER, 0.0, NAN, PmTextKit.WHOLE)
			right = kr.position.x - float(Tk.px(Tk.sz("gap")))
		var name_x: float = sw.end.x + float(Tk.px(Tk.sz("gap")))
		if lit:
			var mf: Font = Tk.font("mono")
			var mfs: int = Tk.fs(Tk.sz("font_meta"))
			var live_text: String = "ON SCREEN"
			var lw: float = PmTextKit.width_of(mf, live_text, mfs)
			if right - lw - name_x >= float(Tk.px(48.0)):
				var lr: Rect2 = Rect2(right - lw, rr.position.y, lw, rr.size.y)
				PmTextKit.draw_in(self, mf, lr, live_text, mfs, ink_col, HORIZONTAL_ALIGNMENT_RIGHT, NAN, PmTextKit.WHOLE)
				right = lr.position.x - float(Tk.px(Tk.sz("gap")))
		var nr: Rect2 = Rect2(name_x, rr.position.y, maxf(right - name_x, 0.0), rr.size.y)
		PmTextKit.draw_in(self, name_font(), nr, view_name, name_size(), ink_col)
		if hover:
			var hb := StyleBoxFlat.new()
			hb.bg_color = Tk.c["glass"]
			hb.set_corner_radius_all(radius)
			draw_style_box(hb, r)
		if press > 0.0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_thumb(tr: Rect2) -> void:
		var tex: Texture2D = _source_texture()
		if tex == null:
			return
		var ts: Vector2 = tex.get_size()
		var src: Rect2 = Rect2(region.position * ts, region.size * ts)
		if src.size.x < 1.0 or src.size.y < 1.0:
			return
		var aspect: float = src.size.x / src.size.y
		var dst: Rect2 = tr
		if tr.size.x / tr.size.y > aspect:
			dst.size.x = tr.size.y * aspect
			dst.position.x = tr.position.x + (tr.size.x - dst.size.x) * 0.5
		else:
			dst.size.y = tr.size.x / aspect
			dst.position.y = tr.position.y + (tr.size.y - dst.size.y) * 0.5
		draw_texture_rect_region(tex, dst, src)

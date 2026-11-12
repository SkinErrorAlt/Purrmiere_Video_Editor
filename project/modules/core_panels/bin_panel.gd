extends "res://modules/core_panels/panel_base.gd"

const MediaLoader := preload("res://modules/core_panels/media_loader.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const Instances := preload("res://doc/instances.gd")
const StreamRoles := preload("res://doc/stream_roles.gd")
const StreamOff := preload("res://doc/stream_off.gd")
const FileDropRouter := preload("res://modules/core_panels/file_drop_router.gd")
const RoleDrop := preload("res://doc/role_drop.gd")
const RolePresetDrop := preload("res://modules/core_panels/role_preset_drop.gd")
const AssetPacks := preload("res://doc/asset_packs.gd")
const AssetPackWatch := preload("res://doc/asset_pack_watch.gd")
const SequenceCmds := preload("res://doc/commands/sequence_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const PmScroll := preload("res://ui/kit/pm_scroll.gd")
const ViewButton := preload("res://modules/core_panels/bin_views/view_button.gd")
const ThumbJobs := preload("res://modules/core_panels/bin_views/thumb_jobs.gd")
const Swatch := preload("res://modules/core_panels/bin_views/swatch.gd")
const CaptureTime := preload("res://modules/core_panels/bin_views/capture_time.gd")
const Usage := preload("res://modules/core_panels/bin_views/usage.gd")
const BoardCmds := preload("res://doc/commands/board_cmds.gd")
const MadeItems := preload("res://modules/core_panels/bin_views/made_items.gd")
const BinKeys := preload("res://modules/core_panels/bin_views/bin_keys.gd")
const UsageBadges := preload("res://modules/core_panels/bin_views/usage_badges.gd")
const MediaTags := preload("res://doc/media_tags.gd")
const BinTagsMenu := preload("res://modules/core_panels/bin_views/bin_tags_menu.gd")
const EAR_PATH := "res://engine/ear_safety.gd"
const SourceReveal := preload("res://modules/core_panels/source_reveal.gd")
const SubProjects := preload("res://doc/sub_projects.gd")
const SubProjectMenu := preload("res://modules/core_panels/sub_project_menu.gd")
const ShelfView := preload("res://modules/core_panels/bin_shelf_view.gd")
const PREF_SCOPE := "bin.sub_project_only"
const AREA := "bin"
const VIEWS: PackedStringArray = ["list", "grid", "big", "board", "strips", "colours", "recorded", "used"]
const CLASSIC_VIEWS: PackedStringArray = ["list", "grid", "big"]
const VIEW_LABELS: Dictionary = {"list": "List", "grid": "Grid", "big": "Big grid", "board": "Board", "strips": "Strips", "colours": "Colour wall", "recorded": "When recorded", "used": "Used parts"}
const VIEW_SCRIPTS: Dictionary = {
	"board": "res://modules/core_panels/bin_views/board_view.gd",
	"strips": "res://modules/core_panels/bin_views/strips_view.gd",
	"colours": "res://modules/core_panels/bin_views/colour_wall_view.gd",
	"recorded": "res://modules/core_panels/bin_views/recorded_view.gd",
	"used": "res://modules/core_panels/bin_views/used_view.gd",
}
const VIEW_KEY := "bin"
const OWNER := "bin_views"
const MAX_COLOUR_SNAPS := 4
const COLOUR_SNAP_TIMEOUT_MS := 20000
const ROW_H := 34.0
const TILE_GRID := 104.0
const TILE_BIG := 168.0
const NAME_ROW := 18.0
const SLOP := 4.0
const GHOST_W := 150.0
const SCRUB_STEPS := 10
const THUMB_W := 240
const PREF_VIEW := "bin.view"
const PREF_SORT := "bin.sort"
const PREF_SORT_DESC := "bin.sort_desc"
const SORT_IMPORT := "import"
const SYSTEMS_PATH := "res://modules/core_panels/systems.gd"
const PROXY_QUEUE_PATH := "res://engine/proxy_queue.gd"
const HEADER_H := 22.0
const NAME_MIN := 150.0
const COLUMNS: Array[Dictionary] = [
	{"id": "name", "label": "Name", "w": NAME_MIN},
	{"id": "duration", "label": "Duration", "w": 78.0},
	{"id": "fps", "label": "Frame rate", "w": 94.0},
	{"id": "size", "label": "Size", "w": 88.0},
	{"id": "streams", "label": "Streams", "w": 112.0},
	{"id": "date", "label": "Date", "w": 118.0},
	{"id": "label", "label": "Label", "w": 78.0},
]
const MADE_KIND_WORDS: Dictionary = {"title": "title", "shape": "shape", "adjust": "adjustment layer", "generator": "colour matte", "sequence": "sequence"}
const MAX_PACKS_IN_MENU := 12

var view: String = "list"
var folder: String = ""
var search: String = ""
var selected_ids: PackedStringArray = PackedStringArray()
var selected_folder: String = ""
var selected_role: String = ""
var _anchor: String = ""
var _name_label: Label = null
var _search: LineEdit = null
var _view_buttons: Dictionary = {}
var _crumbs: HBoxContainer = null
var _crumb_bar: Control = null
var _body: Control = null
var _shelf: Control = null
var _shelf_button: Button = null
var _shelf_divider: Control = null
var _shelf_dialog: FileDialog = null
var _shelf_dir: String = ""
var _footer: Label = null
var _dialog: FileDialog = null
var _folder_dialog: FileDialog = null
var _thumbs: Dictionary = {}
var _thumb_requests: Dictionary = {}
var _hover_jobs: Dictionary = {}
var _refresh_queued: bool = false
var _dragging: bool = false
var _rename_edit: LineEdit = null
var _rename_id: String = ""
var sort_by: String = ""
var sort_desc: bool = false
var _dates: Dictionary = {}
var impl: RefCounted = null
var _view_switch: Button = null
var _view_bar_holder: PanelContainer = null
var _view_bar: Container = null
var _jobs: RefCounted = ThumbJobs.new()
var _usage: Dictionary = {}
var _usage_stamp: String = ""
var _colour_waiting: Dictionary = {}
var _colour_queue: Array[String] = []
var _recorded_cache: Dictionary = {}
var _packs_cache: Array[Dictionary] = []
var _packs_stamp: int = -1
var _sort_writing: bool = false


func _build(root_: Control) -> void:
	if not Prefs.is_registered(PREF_VIEW):
		Prefs.register(PREF_VIEW, "list", {"label": "Bin view", "type": "enum", "choices": VIEWS})
	view = String(Prefs.get_value(PREF_VIEW))
	if not Prefs.is_registered(PREF_SCOPE):
		Prefs.register(PREF_SCOPE, true, {"label": "Bin shows only the active sub project's media", "type": "bool"})
	MadeItems.register_prefs()
	_watch_ear()
	if not (view in VIEWS):
		view = "list"
	_load_sort()
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_name_label = PmLabel.headline("")
	_name_label.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_body")))
	head.add_child(_name_label)
	_search = PmUI.line_edit("Search")
	PmUI.tip(_search, "Search names and tags. Start with # to search tags only.")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_on_search)
	head.add_child(_search)
	for v: String in CLASSIC_VIEWS:
		var icon: String = "list" if v == "list" else "grid"
		var b: Button = toggle_icon(icon, "List view" if v == "list" else ("Grid view" if v == "grid" else "Big grid view"), view == v, Cmd.keys_text("bin.view_" + v))
		if v == "big":
			b.set("icon_px", 20.0)
		b.pressed.connect(_on_view_pressed.bind(v))
		head.add_child(b)
		_view_buttons[v] = b
	_add_view_switch(head)
	_shelf_button = toggle_icon("pin", "Pinned folders and files, down the side", ShelfView.stored_open())
	_shelf_button.toggled.connect(_on_shelf_toggled)
	head.add_child(_shelf_button)
	var nb: Button = quiet_icon("folder_new", "New bin", Cmd.keys_text("file.new_bin"))
	nb.pressed.connect(_on_new_bin)
	head.add_child(nb)
	var ni: Button = quiet_icon("plus", "New item")
	ni.pressed.connect(_on_new_item.bind(ni))
	head.add_child(ni)
	var ib: Button = PmButton.make("Import", "import")
	ib.set("icon_px", 14.0)
	PmUI.tip(ib, "Import media files into this bin, right click for a folder", Cmd.keys_text("file.import"))
	ib.pressed.connect(_on_import)
	ib.gui_input.connect(_on_import_input.bind(ib))
	head.add_child(ib)
	_crumb_bar = PmUI.panel("bg_panel")
	var csb: StyleBoxFlat = _crumb_bar.get_theme_stylebox("panel")
	csb.content_margin_top = 1.0
	csb.content_margin_bottom = 1.0
	_crumbs = PmUI.hbox(0)
	_crumb_bar.add_child(_crumbs)
	_crumb_bar.visible = false
	col.add_child(_crumb_bar)
	_add_view_bar(col)
	var middle: HBoxContainer = PmUI.hbox(0)
	middle.name = "BinMiddle"
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(middle)
	_shelf = ShelfView.new()
	_shelf.set("panel", self)
	middle.add_child(_shelf)
	_shelf.call("begin")
	_shelf_divider = PmUI.divider(true)
	_shelf_divider.visible = _shelf.visible
	middle.add_child(_shelf_divider)
	_body = _Body.new()
	_body.panel = self
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(_body)
	var files_slot: Control = PmSlot.make(PackedStringArray(["files"]))
	files_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	files_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	files_slot.connect("dropped", _on_files_payload)
	_body.add_child(files_slot)
	RolePresetDrop.attach_bin(_body, self)
	col.add_child(PmUI.divider())
	var foot: HBoxContainer = PmUI.hbox()
	foot.custom_minimum_size = Vector2(0, float(Tk.px(Tk.sz("row_h"))))
	_footer = PmLabel.dim("")
	_footer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.clip_text = true
	_footer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	foot.add_child(PmUI.inset(_footer))
	col.add_child(foot)
	if not Tk.icon_scale_changed.is_connected(_on_icon_scale):
		Tk.icon_scale_changed.connect(_on_icon_scale)
	register_commands()
	_apply_project_view()
	_install_view()
	refresh()


func _on_icon_scale(area: String) -> void:
	if area == AREA and _alive():
		_body.relayout()


func _on_project_changed() -> void:
	folder = ""
	selected_ids = PackedStringArray()
	_thumbs.clear()
	_apply_project_view()
	_reset_view_caches()
	forget_pack_cache()
	if shelf_open():
		_shelf.call("recheck")
		_shelf.call("rebuild")
	refresh()
	call_deferred("refresh_watched_packs")


func _on_doc_changed(kind: String) -> void:
	if impl != null:
		impl.call("doc_changed", kind)
	if kind == "structure":
		_usage_stamp = ""
		_queue_structure_refresh()
	elif kind == "media" or kind == "meta" or kind == BoardCmds.CHANGE_KIND:
		queue_refresh()


func _on_history() -> void:
	queue_refresh()


func _queue_structure_refresh() -> void:
	var d: Project = doc()
	if d != null and d.undo != null and d.undo.has_live():
		return
	queue_refresh()


func queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	var tree: SceneTree = _root.get_tree()
	if tree == null:
		_refresh_queued = false
		refresh()
		return
	if not tree.process_frame.is_connected(_deferred_refresh):
		tree.process_frame.connect(_deferred_refresh, CONNECT_ONE_SHOT)


func _deferred_refresh() -> void:
	_refresh_queued = false
	if _dragging:
		queue_refresh.call_deferred()
		return
	if _alive():
		refresh()


func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d: Project = doc()
	if d == null:
		return out
	var searching: bool = not search.strip_edges().is_empty()
	var needle: String = search.strip_edges().to_lower()
	if not searching:
		for b: String in d.bins:
			var parent: String = b.get_base_dir() if b.contains("/") else ""
			if parent != folder:
				continue
			var count: int = 0
			for m: MediaItem in d.media:
				if m.bin == b or m.bin.begins_with(b + "/"):
					count += 1
			out.append({"kind": "folder", "id": "bin:" + b, "path": b, "label": b.get_file(), "meta": "folder · " + str(count) + (" item" if count == 1 else " items"), "count": count, "item": null, "cols": {}})
	if impl == null:
		for p: Dictionary in RoleDrop.listed(d):
			var plabel: String = RoleDrop.label_of(p)
			if searching and not plabel.to_lower().contains(needle):
				continue
			out.append({"kind": RoleDrop.ENTRY_KIND, "id": RoleDrop.entry_id_for(String(p.get("id", ""))), "path": folder, "label": plabel, "meta": RoleDrop.meta_of(p), "count": 0, "item": null, "cols": {}})
	var away: Dictionary = scope_hidden(d)
	for m: MediaItem in d.media:
		if away.has(m.id):
			continue
		if searching:
			if not MediaTags.search_hit(d, m, search):
				continue
		elif m.bin != folder:
			continue
		out.append({"kind": "item", "id": m.id, "path": m.bin, "label": m.label, "meta": meta_line(d, m), "count": 0, "item": m, "cols": column_values(d, m)})
	return view_filter(sort_entries(out))


func _load_sort() -> void:
	if not Prefs.is_registered(PREF_SORT):
		var ids: Array = [SORT_IMPORT]
		for c: Dictionary in COLUMNS:
			ids.append(String(c["id"]))
		Prefs.register(PREF_SORT, SORT_IMPORT, {"label": "Bin sort column", "type": "enum", "choices": ids})
		if String(Prefs.get_value(PREF_SORT)).is_empty():
			Prefs.set_value(PREF_SORT, SORT_IMPORT)
	if not Prefs.is_registered(PREF_SORT_DESC):
		Prefs.register(PREF_SORT_DESC, false, {"label": "Bin sort reversed", "type": "bool"})
	sort_by = String(Prefs.get_value(PREF_SORT))
	if column_index(sort_by) < 0:
		sort_by = ""
	sort_desc = bool(Prefs.get_value(PREF_SORT_DESC))


static func column_index(id: String) -> int:
	for i: int in COLUMNS.size():
		if String(COLUMNS[i]["id"]) == id:
			return i
	return -1


static func column_label(id: String) -> String:
	var i: int = column_index(id)
	return String(COLUMNS[i]["label"]) if i >= 0 else "Import order"


func set_sort(id: String, desc: bool) -> void:
	sort_by = id if column_index(id) >= 0 else ""
	sort_desc = desc and not sort_by.is_empty()
	if Prefs.is_registered(PREF_SORT):
		_sort_writing = true
		Prefs.set_value(PREF_SORT, sort_by if not sort_by.is_empty() else SORT_IMPORT)
		Prefs.set_value(PREF_SORT_DESC, sort_desc)
		_sort_writing = false
	if _alive():
		refresh()


func click_sort(id: String) -> void:
	if id == sort_by:
		set_sort(id, not sort_desc)
	else:
		set_sort(id, false)


func file_date(m: MediaItem) -> int:
	if m.path.is_empty():
		return 0
	var key: String = m.id + "|" + m.path
	if _dates.has(key):
		return int(_dates[key])
	var t: int = int(FileAccess.get_modified_time(m.path)) if FileAccess.file_exists(m.path) else 0
	_dates[key] = t
	return t


static func date_text(t: int) -> String:
	if t <= 0:
		return ""
	var tz: Dictionary = Time.get_time_zone_from_system()
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(t + int(tz.get("bias", 0)) * 60)
	return "%04d-%02d-%02d %02d:%02d" % [int(d["year"]), int(d["month"]), int(d["day"]), int(d["hour"]), int(d["minute"])]


static func streams_text(m: MediaItem) -> String:
	if MADE_KIND_WORDS.has(m.kind):
		return MadeItems.kind_word(m).to_lower() if m.kind == "generator" else String(MADE_KIND_WORDS[m.kind])
	if m.kind == "image":
		return "picture"
	var parts: PackedStringArray = PackedStringArray()
	if m.kind == "video" and not m.audio_only:
		parts.append("video")
	var audio: int = m.audio_streams.size()
	if audio == 0 and (m.has_audio or m.kind == "audio"):
		audio = 1
	if audio > 0:
		parts.append(str(audio) + " audio")
	return ", ".join(parts)


func column_values(d: Project, m: MediaItem) -> Dictionary:
	var w: int = m.width
	var h: int = m.height
	var rate: float = m.fps
	if m.kind == "sequence":
		var s: Sequence = d.sequence_by_id(m.sequence_id)
		if s != null:
			w = s.width
			h = s.height
			rate = s.fps
	var dur: float = d.media_duration(m) if m.is_timed() else m.duration
	var date: int = file_date(m)
	return {
		"duration": Timecode.format(dur, rate if rate > 0.0 else fps(), false).substr(0, 8) if dur > 0.0 else "",
		"fps": _fps_text(rate) if rate > 0.0 else "",
		"size": (str(w) + "x" + str(h)) if w > 0 and h > 0 else "",
		"streams": streams_text(m),
		"date": date_text(date),
		"label": Tk.label_name(m.colour) if m.colour >= 0 else "",
		"_duration": dur,
		"_fps": rate,
		"_size": w * h,
		"_date": date,
		"_label": m.colour if m.colour >= 0 else 999,
	}


func sort_key(e: Dictionary, id: String) -> Variant:
	var cols: Dictionary = e.get("cols", {})
	if id == "name":
		return String(e["label"]).to_lower()
	if id == "duration" or id == "fps" or id == "size" or id == "date" or id == "label":
		return cols.get("_" + id, 0)
	return String(cols.get(id, "")).to_lower()


func sort_entries(list: Array[Dictionary]) -> Array[Dictionary]:
	if sort_by.is_empty():
		return list
	var folders: Array[Dictionary] = []
	var roles: Array[Dictionary] = []
	var items: Array[Dictionary] = []
	for e: Dictionary in list:
		if String(e["kind"]) == "folder":
			folders.append(e)
		elif String(e["kind"]) == RoleDrop.ENTRY_KIND:
			roles.append(e)
		else:
			e["sort"] = sort_key(e, sort_by)
			items.append(e)
	folders.sort_custom(_folder_less)
	roles.sort_custom(_folder_less)
	items.sort_custom(_item_less)
	if sort_desc:
		items.reverse()
	var out: Array[Dictionary] = folders
	out.append_array(roles)
	out.append_array(items)
	return out


static func _folder_less(a: Dictionary, b: Dictionary) -> bool:
	return String(a["label"]).naturalnocasecmp_to(String(b["label"])) < 0


static func _item_less(a: Dictionary, b: Dictionary) -> bool:
	var ka: Variant = a["sort"]
	var kb: Variant = b["sort"]
	if typeof(ka) == TYPE_STRING and typeof(kb) == TYPE_STRING:
		var c: int = String(ka).naturalnocasecmp_to(String(kb))
		if c != 0:
			return c < 0
	elif ka != kb:
		return float(ka) < float(kb)
	return String(a["label"]).naturalnocasecmp_to(String(b["label"])) < 0


func list_columns(width: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var used: float = float(Tk.px(NAME_MIN))
	var shown: Array[Dictionary] = []
	for i: int in range(1, COLUMNS.size()):
		var cw: float = float(Tk.px(float(COLUMNS[i]["w"])))
		if used + cw > width:
			break
		used += cw
		shown.append(COLUMNS[i])
	var right: float = width
	var placed: Array[Dictionary] = []
	for i: int in range(shown.size() - 1, -1, -1):
		var cw2: float = float(Tk.px(float(shown[i]["w"])))
		right -= cw2
		placed.push_front({"id": String(shown[i]["id"]), "label": String(shown[i]["label"]), "x": right, "w": cw2})
	out.append({"id": "name", "label": "Name", "x": 0.0, "w": right})
	out.append_array(placed)
	return out


func hidden_facts(e: Dictionary, cols: Array[Dictionary]) -> String:
	if String(e["kind"]) == "folder" or String(e["kind"]) == RoleDrop.ENTRY_KIND:
		return String(e["meta"])
	var shown: Dictionary = {}
	for c: Dictionary in cols:
		shown[String(c["id"])] = true
	var values: Dictionary = e.get("cols", {})
	var parts: PackedStringArray = PackedStringArray()
	for c: Dictionary in COLUMNS:
		var id: String = String(c["id"])
		if id == "name" or shown.has(id):
			continue
		var v: String = String(values.get(id, ""))
		if id == "date" and not v.is_empty():
			v = v.substr(0, 10)
		if not v.is_empty():
			parts.append(v)
	var item: Variant = e.get("item")
	if item is MediaItem:
		var mi: MediaItem = item
		if mi.audio_only:
			parts.insert(0, "AUDIO ONLY")
		if mi.missing:
			parts.insert(0, "MISSING")
		var ear: String = ear_note(mi)
		if not ear.is_empty():
			parts.insert(0, ear)
	return " · ".join(parts)


func meta_line(d: Project, m: MediaItem) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if m.kind == "sequence":
		var s: Sequence = d.sequence_by_id(m.sequence_id)
		if s != null:
			parts.append(Timecode.format(s.duration(), s.fps, s.drop_frame).substr(0, 8))
			parts.append(str(s.width) + "x" + str(s.height))
			parts.append(_fps_text(s.fps))
		else:
			parts.append("sequence")
	else:
		if m.kind == "title":
			parts.append("title")
		elif m.kind == "adjust":
			parts.append("adjustment layer")
		elif m.kind == "shape":
			parts.append("shape")
		elif m.kind == "generator":
			parts.append(MadeItems.kind_word(m).to_lower())
		if m.is_timed():
			if m.probed:
				parts.append(Timecode.format(m.duration, m.fps if m.fps > 0.0 else fps(), false).substr(0, 8))
			else:
				parts.append("reading")
		if m.width > 0 and m.height > 0:
			parts.append(str(m.width) + "x" + str(m.height))
		if m.fps > 0.0:
			parts.append(_fps_text(m.fps))
		if m.kind == "audio" and not m.audio_streams.is_empty():
			parts.append(str(int(m.audio_streams[0].get("sample_rate", 48000)) / 1000) + " kHz")
			parts.append("stereo" if int(m.audio_streams[0].get("channels", 2)) == 2 else str(int(m.audio_streams[0].get("channels", 1))) + " ch")
		elif m.audio_streams.size() > 1:
			var roles: String = StreamRoles.summary(m)
			parts.append(roles if not roles.is_empty() else str(m.audio_streams.size()) + " streams")
		if m.kind == "image" and m.path.get_extension().to_lower() == "png":
			parts.append("alpha")
		if m.audio_only:
			parts.append("AUDIO ONLY")
		if m.missing:
			parts.append("MISSING")
		var ear: String = ear_note(m)
		if not ear.is_empty():
			parts.append(ear)
	var tagged: PackedStringArray = MediaTags.effective(d, m)
	if not tagged.is_empty():
		parts.append(MediaTags.TAG_PREFIX + (" " + MediaTags.TAG_PREFIX).join(tagged))
	return " · ".join(parts)


static func _fps_text(v: float) -> String:
	var s: String = "%.2f" % v
	if s.ends_with(".00"):
		return s.substr(0, s.length() - 3)
	if s.ends_with("0"):
		return s.substr(0, s.length() - 1)
	return s


func refresh() -> void:
	if not _alive():
		return
	var d: Project = doc()
	_name_label.text = d.name if d != null else "No project"
	var list: Array[Dictionary] = entries()
	var keep: PackedStringArray = PackedStringArray()
	for id: String in selected_ids:
		for e: Dictionary in list:
			if String(e["id"]) == id:
				keep.append(id)
				break
	selected_ids = keep
	_body.set_entries(list, view)
	_rebuild_crumbs()
	_update_footer(list)
	load("res://modules/core_panels/panel_place.gd").call("bin_turn", self)


func _rebuild_crumbs() -> void:
	PmUI.clear(_crumbs)
	var d: Project = doc()
	var show: bool = d != null and not folder.is_empty() and search.strip_edges().is_empty()
	_crumb_bar.visible = show
	if not show:
		return
	var rb: Button = PmButton.make(d.name)
	rb.set("quiet", true)
	rb.pressed.connect(_on_crumb.bind(""))
	_crumbs.add_child(rb)
	_attach_folder_slot(rb, "")
	var acc: String = ""
	for part: String in folder.split("/"):
		acc = part if acc.is_empty() else acc + "/" + part
		var chev: Control = PmIcon.make("chev_r", 12.0)
		chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_crumbs.add_child(chev)
		var b: Button = PmButton.make(part)
		b.set("quiet", true)
		b.pressed.connect(_on_crumb.bind(acc))
		_crumbs.add_child(b)
		if acc != folder:
			_attach_folder_slot(b, acc)


func _attach_folder_slot(anchor: Control, path: String) -> void:
	var slot: Control = PmSlot.make(PackedStringArray(["media"]))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.connect("dropped", _on_folder_drop.bind(path))
	anchor.add_child(slot)


func _on_folder_drop(payload: Dictionary, _local: Vector2, path: String) -> void:
	move_to_folder(_ids_of(payload), path)


static func _ids_of(payload: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var raw: Variant = payload.get("ids", [])
	if typeof(raw) == TYPE_ARRAY or typeof(raw) == TYPE_PACKED_STRING_ARRAY:
		for v: Variant in raw:
			out.append(String(v))
	return out


func move_to_folder(ids: PackedStringArray, path: String) -> bool:
	var d: Project = doc()
	if d == null or ids.is_empty():
		return false
	var cmds: Array[Command] = []
	for id: String in ids:
		var m: MediaItem = d.media_by_id(id)
		if m != null and m.bin != path:
			cmds.append(MediaCmds.MoveMediaToBin.new(id, path))
	if cmds.is_empty():
		return false
	return Verbs.run(d, "Move to " + (path.get_file() if not path.is_empty() else d.name), cmds)


func _update_footer(list: Array[Dictionary]) -> void:
	var d: Project = doc()
	if d == null:
		_footer.text = "Open or create a project to see its media"
		return
	var items: int = 0
	for e: Dictionary in list:
		if String(e["kind"]) == "item":
			items += 1
	var text: String = str(items) + (" item" if items == 1 else " items")
	if not selected_ids.is_empty():
		var total: float = 0.0
		for id: String in selected_ids:
			var m: MediaItem = d.media_by_id(id)
			if m != null:
				total += d.media_duration(m)
		text += " · " + str(selected_ids.size()) + " selected · " + Timecode.format(total, fps(), false).substr(0, 8)
	if impl != null:
		var mt: String = String(impl.get("meta_text"))
		if not mt.is_empty():
			text += " · " + mt
	_footer.text = text
	PmUI.tip(_footer, text)


func _on_search(text: String) -> void:
	search = text
	refresh()


func search_for(text: String) -> void:
	if _search != null:
		_search.text = text
	_on_search(text)


func _on_view_pressed(v: String) -> void:
	set_view(v)


func _on_pref_changed(key: String) -> void:
	if key == PREF_VIEW:
		var v: String = String(Prefs.get_value(PREF_VIEW))
		if v != view:
			set_view(v)
	elif (key == PREF_SORT or key == PREF_SORT_DESC) and not _sort_writing:
		var by: String = String(Prefs.get_value(PREF_SORT))
		var want: String = by if column_index(by) >= 0 else ""
		var desc: bool = bool(Prefs.get_value(PREF_SORT_DESC)) and not want.is_empty()
		if want != sort_by or desc != sort_desc:
			set_sort(want, desc)
	elif key == MediaLoader.PREF_STILL or key == "media.prepare_on_import":
		refresh()


func set_view(v: String) -> void:
	if not (v in VIEWS):
		return
	var changed: bool = v != view or (impl == null) != (v in CLASSIC_VIEWS)
	view = v
	Prefs.set_value(PREF_VIEW, v)
	set_view_value("", "view", v)
	for k: String in _view_buttons.keys():
		(_view_buttons[k] as Button).button_pressed = k == v
	if _alive():
		if changed:
			_install_view()
		_body.set_entries(entries(), view)
		_update_footer(_body.entries)
		load("res://modules/core_panels/panel_place.gd").call("bin_turn", self)


func _on_crumb(path: String) -> void:
	open_folder(path)


func open_folder(path: String) -> void:
	folder = path
	selected_ids = PackedStringArray()
	selected_folder = ""
	refresh()


func _on_new_bin() -> void:
	var d: Project = doc()
	if d == null:
		return
	var n: int = 1
	var base: String = "Bin"
	var path: String = base if folder.is_empty() else folder + "/" + base
	while d.bins.has(path):
		n += 1
		path = (base + " " + str(n)) if folder.is_empty() else folder + "/" + base + " " + str(n)
	if Verbs.run(d, "New bin", [MediaCmds.AddBin.new(path)]):
		refresh()
		begin_rename("bin:" + path)


func new_bin_from_selection() -> void:
	var d: Project = doc()
	if d == null or selected_ids.is_empty():
		return
	var n: int = 1
	var path: String = "Bin" if folder.is_empty() else folder + "/Bin"
	while d.bins.has(path):
		n += 1
		path = ("Bin " + str(n)) if folder.is_empty() else folder + "/Bin " + str(n)
	var cmds: Array[Command] = [MediaCmds.AddBin.new(path)]
	for id: String in selected_ids:
		cmds.append(MediaCmds.MoveMediaToBin.new(id, path))
	Verbs.run(d, "New bin from selection", cmds)


func _on_new_item(anchor: Control) -> void:
	var m: Control = PmMenu.open(anchor, MadeItems.menu_items(true))
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_new_item_picked)


func _on_new_item_picked(id: String) -> void:
	if id == "new.sequence":
		Cmd.run("file.new_sequence")
		return
	if id == "audio.hide_picture":
		Cmd.run(id)
		return
	spawn(id)


func spawn(spawn_id: String) -> String:
	var d: Project = doc()
	if d == null or not MadeItems.is_spawn(spawn_id):
		return ""
	if not MadeItems.like_premiere():
		MadeItems.ask_new(_root, d, seq(), spawn_id, folder, _on_spawned_asked)
		return ""
	var made: String = MadeItems.spawn_now(d, seq(), spawn_id, folder)
	if not made.is_empty():
		selected_ids = PackedStringArray([made])
		refresh()
		begin_rename(made)
	return made


func _watch_ear() -> void:
	var ear: Node = load(EAR_PATH).call("ensure")
	if ear != null and not ear.is_connected("measured", _on_ear_measured):
		ear.connect("measured", _on_ear_measured)


func _on_ear_measured(_media_id: String) -> void:
	if _alive():
		queue_refresh()


func ear_note(m: MediaItem) -> String:
	return String(load(EAR_PATH).call("bin_note", m))


func _on_spawned_asked(media_id: String) -> void:
	if not _alive():
		return
	selected_ids = PackedStringArray([media_id])
	refresh()


func open_made_settings(media_id: String) -> bool:
	return MadeItems.open_settings(_root, doc(), media_id)


func _on_import() -> void:
	if doc() == null:
		Cmd.run("file.import")
		return
	if _dialog == null or not is_instance_valid(_dialog):
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
		_dialog.use_native_dialog = true
		_dialog.title = "Import media"
		_dialog.filters = MediaLoader.filters()
		_dialog.files_selected.connect(import_paths)
		_dialog.file_selected.connect(_on_one_file)
		_root.add_child(_dialog)
	_dialog.popup_centered(Vector2i(900, 600))


func _on_one_file(path: String) -> void:
	import_paths(PackedStringArray([path]))


func _on_import_input(event: InputEvent, anchor: Control) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		anchor.accept_event()
		var items: Array = [
			PmMenu.item("import", "Import files", Cmd.keys_text("file.import"), "import"),
			PmMenu.item("import_folder", "Import a folder and its subfolders", "", "folder"),
		]
		items.append_array(instance_menu_items())
		var m: Control = PmMenu.open(anchor, items)
		if m != null and m.is_inside_tree():
			m.connect("picked", _on_empty_context_picked)


func instance_menu_items() -> Array:
	var items: Array = []
	var tags: PackedStringArray = Instances.all_tags()
	var groups: Array = Instances.groups()
	if tags.is_empty() and groups.is_empty():
		return items
	items.append(PmMenu.separator())
	if not tags.is_empty():
		var tag_sub: Array = []
		for t: String in tags:
			tag_sub.append(PmMenu.item("inst_tag:" + t, t + "  (" + str(Instances.by_tag(t).size()) + ")"))
		items.append(PmMenu.sub_item("inst_tags", "Import everything tagged", tag_sub, "type"))
	if not groups.is_empty():
		var group_sub: Array = []
		for g: Dictionary in groups:
			var gid: String = String(g["id"])
			group_sub.append(PmMenu.item("inst_group:" + gid, Instances.group_path(gid) + "  (" + str(Instances.by_group(gid, true).size()) + ")"))
		items.append(PmMenu.sub_item("inst_groups", "Import an instance group", group_sub, "folder"))
	return items


func _on_instance_pick(id: String) -> bool:
	var panel: Object = bus().panel("instances")
	if panel == null:
		return false
	var out: PackedStringArray = PackedStringArray()
	if id.begins_with("inst_tag:"):
		out = panel.call("import_tag", id.substr(9))
	elif id.begins_with("inst_group:"):
		out = panel.call("import_group", id.substr(11))
	else:
		return false
	Events.toast("Imported " + str(out.size()) + (" item" if out.size() == 1 else " items") + " from the library")
	refresh()
	return true


func _on_import_folder() -> void:
	if doc() == null:
		Cmd.run("file.import")
		return
	if _folder_dialog == null or not is_instance_valid(_folder_dialog):
		_folder_dialog = FileDialog.new()
		_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_folder_dialog.use_native_dialog = true
		_folder_dialog.title = "Import a folder"
		_folder_dialog.dir_selected.connect(_on_folder_picked)
		_root.add_child(_folder_dialog)
	_folder_dialog.popup_centered(Vector2i(900, 600))


func _on_folder_picked(path: String) -> void:
	var d: Project = doc()
	if d == null:
		return
	var ids: PackedStringArray = MediaLoader.instance().import_folder(d, path, folder)
	if not ids.is_empty():
		Events.toast("Imported " + str(ids.size()) + (" item" if ids.size() == 1 else " items") + " from " + path.get_file())
		refresh()


func shelf() -> Control:
	return _shelf


func shelf_open() -> bool:
	return _shelf != null and is_instance_valid(_shelf) and _shelf.visible


func _on_shelf_toggled(on: bool) -> void:
	if _shelf == null or not is_instance_valid(_shelf):
		return
	_shelf.call("set_open", on)
	if _shelf_divider != null and is_instance_valid(_shelf_divider):
		_shelf_divider.visible = on


func shelf_sync_button() -> void:
	if _shelf_button != null and is_instance_valid(_shelf_button):
		_shelf_button.button_pressed = shelf_open()
	if _shelf_divider != null and is_instance_valid(_shelf_divider):
		_shelf_divider.visible = shelf_open()


func toggle_shelf() -> void:
	if _shelf_button != null and is_instance_valid(_shelf_button):
		_shelf_button.button_pressed = not _shelf_button.button_pressed


func shelf_import_file(path: String) -> void:
	var ids: PackedStringArray = import_paths(PackedStringArray([path]))
	if ids.is_empty():
		Events.toast("Nothing in " + path.get_file() + " could be imported")


func shelf_import_folder(path: String) -> void:
	_on_folder_picked(path)


func shelf_browse_folder(path: String) -> void:
	if doc() == null:
		Events.toast("Open a project first")
		return
	_shelf_dir = path
	if _shelf_dialog == null or not is_instance_valid(_shelf_dialog):
		_shelf_dialog = FileDialog.new()
		_shelf_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_shelf_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
		_shelf_dialog.use_native_dialog = true
		_shelf_dialog.title = "Import from " + path.get_file()
		_shelf_dialog.filters = MediaLoader.filters()
		_shelf_dialog.files_selected.connect(import_paths)
		_shelf_dialog.file_selected.connect(_on_one_file)
		_root.add_child(_shelf_dialog)
	_shelf_dialog.title = "Import from " + path.get_file()
	_shelf_dialog.current_dir = path
	_shelf_dialog.current_path = path if path.ends_with("/") else path + "/"
	_shelf_dialog.popup_centered(Vector2i(900, 600))


func shelf_picker_dir() -> String:
	return _shelf_dir


func shelf_picker() -> FileDialog:
	return _shelf_dialog


func _shelf_drop_pos(w: Window, pos: Vector2) -> Vector2:
	if not shelf_open():
		return Vector2(-INF, -INF)
	var own: Window = _shelf.get_window()
	if own == null or own == w:
		return pos
	if own.get_embedder() == w:
		return pos - Vector2(own.position)
	return Vector2(-INF, -INF)


func shelf_takes_in(w: Window, pos: Vector2) -> bool:
	var at: Vector2 = _shelf_drop_pos(w, pos)
	return is_finite(at.x) and bool(_shelf.call("takes_global", at))


func shelf_pin_in(files: PackedStringArray, w: Window, pos: Vector2) -> int:
	return int(_shelf.call("pin_global", files, _shelf_drop_pos(w, pos)))


func import_paths(paths: PackedStringArray) -> PackedStringArray:
	var d: Project = doc()
	if d == null:
		return PackedStringArray()
	var ids: PackedStringArray = MediaLoader.instance().import_paths(d, paths, folder)
	if not ids.is_empty():
		selected_ids = ids.duplicate()
		refresh()
	return ids


static func payload_paths(payload: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for v: Variant in payload.get("paths", []):
		out.append(String(v))
	return out


func _on_files_payload(payload: Dictionary, _local: Vector2) -> void:
	var paths: PackedStringArray = payload_paths(payload)
	if paths.is_empty():
		return
	var ids: PackedStringArray = import_paths(paths)
	if not ids.is_empty():
		Events.toast("Imported " + str(ids.size()) + (" item" if ids.size() == 1 else " items") + " from the library")


func on_files_dropped_in(files: PackedStringArray, w: Window, pos: Vector2) -> void:
	if shelf_takes_in(w, pos):
		shelf_pin_in(files, w, pos)
		return
	var tl: Object = bus().panel("timeline")
	var on_tl: bool = tl != null and tl.has_method("accepts_in") and bool(tl.call("accepts_in", w, pos))
	_drop_files(files, tl if on_tl else null, tl.call("local_drop_pos", w, pos) if on_tl else pos)


func on_files_dropped(files: PackedStringArray, global_pos: Vector2) -> void:
	if shelf_open() and bool(_shelf.call("takes_global", global_pos)):
		_shelf.call("pin_global", files, global_pos)
		return
	var tl: Object = bus().panel("timeline")
	var on_tl: bool = tl != null and tl.has_method("accepts_global") and bool(tl.call("accepts_global", global_pos))
	_drop_files(files, tl if on_tl else null, global_pos)


func _drop_files(files: PackedStringArray, tl: Object, global_pos: Vector2) -> void:
	files = load("res://modules/core_panels/shader_import.gd").call("without_shaders", files)
	if files.is_empty():
		return
	if tl != null:
		var ids: PackedStringArray = import_paths(files)
		if not ids.is_empty():
			tl.call("drop_media_at", ids, global_pos)
		return
	var ids2: PackedStringArray = import_paths(files)
	var folders: int = 0
	for f: String in files:
		if MediaLoader.is_folder(f):
			folders += 1
	if folders > 0 and not ids2.is_empty():
		Events.toast("Imported " + str(ids2.size()) + (" item" if ids2.size() == 1 else " items") + " from " + str(folders) + (" folder" if folders == 1 else " folders"))


func activate(entry_id: String) -> void:
	var d: Project = doc()
	if d == null:
		return
	if entry_id.begins_with("bin:"):
		open_folder(entry_id.substr(4))
		return
	if RoleDrop.is_entry(entry_id):
		apply_role_preset(entry_id, selected_ids)
		return
	var m: MediaItem = d.media_by_id(entry_id)
	if m == null:
		return
	if m.kind == "sequence":
		Session.set_sequence(m.sequence_id)
		return
	SourceReveal.open(_root, m.id)


func open_in_source_at(media_id: String, at: float, in_t: float = -1.0, out_t: float = -1.0) -> void:
	var d: Project = doc()
	var m: MediaItem = d.media_by_id(media_id) if d != null else null
	if m == null:
		return
	if m.kind == "sequence":
		Session.set_sequence(m.sequence_id)
		return
	SourceReveal.open(_root, m.id, in_t, out_t, at)


func reveal(entry_id: String) -> void:
	var d: Project = doc()
	if d == null:
		return
	var m: MediaItem = d.media_by_id(entry_id)
	if m == null:
		return
	if m.bin != folder:
		open_folder(m.bin)
	select_entry(entry_id, "replace")
	if _body != null and _body.has_method("ensure_visible"):
		_body.call("ensure_visible", entry_id)


func select_entry(entry_id: String, mode: String) -> void:
	if entry_id.begins_with("bin:"):
		selected_folder = entry_id.substr(4)
		selected_role = ""
		if mode == "replace":
			selected_ids = PackedStringArray()
		_body.queue_redraw()
		_update_footer(_body.entries)
		return
	if RoleDrop.is_entry(entry_id):
		selected_role = entry_id
		selected_folder = ""
		if mode == "replace":
			selected_ids = PackedStringArray()
		_body.queue_redraw()
		_update_footer(_body.entries)
		return
	selected_folder = ""
	selected_role = ""
	if mode == "replace":
		selected_ids = PackedStringArray([entry_id])
		_anchor = entry_id
	elif mode == "toggle":
		var i: int = selected_ids.find(entry_id)
		if i >= 0:
			selected_ids.remove_at(i)
		else:
			selected_ids.append(entry_id)
		_anchor = entry_id
	elif mode == "range":
		var order: PackedStringArray = PackedStringArray()
		for e: Dictionary in _body.entries:
			if String(e["kind"]) == "item":
				order.append(String(e["id"]))
		var a: int = order.find(_anchor)
		var b: int = order.find(entry_id)
		if a < 0:
			a = b
		if b >= 0:
			var lo: int = mini(a, b)
			var hi: int = maxi(a, b)
			selected_ids = PackedStringArray()
			for i: int in range(lo, hi + 1):
				selected_ids.append(order[i])
	_body.queue_redraw()
	_update_footer(_body.entries)


func clear_selection() -> void:
	selected_ids = PackedStringArray()
	selected_folder = ""
	selected_role = ""
	_body.queue_redraw()
	_update_footer(_body.entries)


func drag_ids_for(entry_id: String) -> PackedStringArray:
	if entry_id.begins_with("bin:") or RoleDrop.is_entry(entry_id):
		return PackedStringArray()
	if selected_ids.has(entry_id):
		return selected_ids.duplicate()
	return PackedStringArray([entry_id])


func begin_drag(entry_id: String, grab: Vector2) -> void:
	if RoleDrop.is_entry(entry_id):
		start_role_drag(entry_id, grab)
		return
	_start_drag(drag_ids_for(entry_id), grab, -1.0, -1.0)


func start_role_drag(entry_id: String, grab: Vector2) -> bool:
	var p: Dictionary = RoleDrop.by_id(doc(), RoleDrop.preset_id_of(entry_id))
	if p.is_empty() or not _alive():
		return false
	var layer: CanvasLayer = PmDragLayer.find(_root)
	if layer == null:
		return false
	RolePresetDrop.attach_bin(_body, self)
	RolePresetDrop.ensure_timeline()
	var ghost: Control = _Ghost.new()
	ghost.label = RoleDrop.label_of(p)
	ghost.icon = RoleDrop.ENTRY_ICON
	ghost.count = 1
	var w: float = float(Tk.px(GHOST_W))
	ghost.size = Vector2(w, w * 0.6 + float(Tk.px(NAME_ROW)))
	_dragging = true
	if not layer.drag_ended.is_connected(_on_drag_ended):
		layer.drag_ended.connect(_on_drag_ended)
	layer.call("begin", {"kind": RoleDrop.DRAG_KIND, "id": String(p.get("id", ""))}, ghost, grab.clamp(Vector2.ZERO, ghost.size))
	return true


func apply_role_preset(entry_id: String, media_ids: PackedStringArray) -> bool:
	var d: Project = doc()
	var p: Dictionary = RoleDrop.by_id(d, RoleDrop.preset_id_of(entry_id))
	if d == null or p.is_empty():
		Events.toast(RoleDrop.UNREADABLE)
		return false
	if media_ids.is_empty():
		Events.toast("Mark the files you want named first, or drag these names onto one")
		return false
	var res: Dictionary = RoleDrop.drop_on_media(d, media_ids, p)
	Events.toast(String(res["why"]) if not bool(res["ok"]) else String(res["note"]))
	return bool(res["changed"])


func role_drop_pick(local: Vector2) -> Dictionary:
	if not _alive():
		return {}
	var i: int = int(_body.call("index_at", local))
	if i < 0 or i >= _body.entries.size():
		return {}
	var e: Dictionary = _body.entries[i]
	if String(e["kind"]) != "item":
		return {}
	return {"kind": "media", "id": String(e["id"]), "index": i}


func role_drop_targets(entry_id: String, whole: bool) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not _alive():
		return out
	if not whole:
		if not entry_id.is_empty():
			out.append(entry_id)
		return out
	for e: Dictionary in _body.entries:
		if String(e["kind"]) == "item":
			out.append(String(e["id"]))
	return out


func role_drop_rects(entry_id: String, whole: bool) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not _alive():
		return out
	var ids: PackedStringArray = role_drop_targets(entry_id, whole)
	for id: String in ids:
		var r: Rect2 = _body.call("screen_rect", _body.call("index_of", id))
		if r.size.x > 0.0 and r.size.y > 0.0:
			out.append(r)
	return out


func _start_drag(ids: PackedStringArray, grab: Vector2, in_t: float, out_t: float) -> void:
	if ids.is_empty():
		return
	var layer: CanvasLayer = PmDragLayer.find(_root)
	if layer == null:
		return
	var d: Project = doc()
	var first: MediaItem = d.media_by_id(ids[0]) if d != null else null
	var ghost: Control = _Ghost.new()
	ghost.label = first.label if first != null else ids[0]
	ghost.icon = kind_icon(first.kind) if first != null else "film"
	ghost.picture = thumb_for(first, -1.0) if first != null else null
	ghost.count = ids.size()
	var w: float = float(Tk.px(GHOST_W))
	ghost.size = Vector2(w, w * 0.6 + float(Tk.px(NAME_ROW)))
	var payload: Dictionary = {"kind": "media", "ids": Array(ids), "part": "both", "in": in_t, "out": out_t}
	_dragging = true
	if not layer.drag_ended.is_connected(_on_drag_ended):
		layer.drag_ended.connect(_on_drag_ended)
	layer.call("begin", payload, ghost, grab.clamp(Vector2.ZERO, ghost.size))


func _on_drag_ended(_payload: Dictionary, _dropped: bool) -> void:
	_dragging = false
	if _refresh_queued and _alive():
		refresh()


func thumb_for(m: MediaItem, t: float, keep: bool = false) -> Texture2D:
	if m == null:
		return null
	var key: String = m.id + "|" + (String.num(t, 2) if t >= 0.0 else "poster" + String.num(m.poster_time, 3))
	if m.kind == "generator":
		key += "|" + str(m.props.hash()) + "|" + str(m.width) + "x" + str(m.height)
	if _thumbs.has(key):
		return _thumbs[key]
	var tex: Texture2D = null
	if m.kind == "image" and not m.path.is_empty():
		if _jobs.call("is_waiting", key, "load"):
			return null
		if FileAccess.file_exists(m.path):
			_jobs.call("request_load", key, m.path, THUMB_W, true)
			_wake_body()
			return null
	elif m.kind == "generator":
		tex = MadeItems.thumb(m, THUMB_W)
	elif m.kind == "video" and PurrBridge.available:
		var h: int = media_handle(m)
		if h >= 0:
			var at: float = maxf(t, m.poster_time) if t >= 0.0 else m.poster_time
			if PurrBridge.has_async_snapshots():
				var req: String = str(h) + "|" + String.num(at, 3)
				if not _thumb_requests.has(req):
					_thumb_requests[req] = key
					if not PurrBridge.snapshot_ready.is_connected(_on_snapshot_ready):
						PurrBridge.snapshot_ready.connect(_on_snapshot_ready)
					var job: int = PurrBridge.request_snapshot(h, at, THUMB_W)
					if t >= 0.0 and job >= 0 and not keep:
						_hover_jobs[req] = job
				return null
			var img2: Image = PurrBridge.snapshot(h, at, THUMB_W)
			if img2 != null:
				tex = ImageTexture.create_from_image(img2)
	_store_thumb(key, tex)
	return tex


func _store_thumb(key: String, tex: Texture2D) -> void:
	_thumbs[key] = tex
	if _thumbs.size() > 700:
		var drop: int = 250
		for k: Variant in _thumbs.keys():
			if drop <= 0:
				break
			_thumbs.erase(k)
			drop -= 1


func cancel_hover_thumbs() -> void:
	for req: String in _hover_jobs.keys():
		PurrBridge.cancel_job(int(_hover_jobs[req]))
		_thumb_requests.erase(req)
	_hover_jobs.clear()


func _on_snapshot_ready(h: int, seconds: float, width: int, image: Image) -> void:
	if width != THUMB_W:
		return
	var req: String = str(h) + "|" + String.num(seconds, 3)
	_hover_jobs.erase(req)
	if not _thumb_requests.has(req):
		return
	var key: String = String(_thumb_requests[req])
	_thumb_requests.erase(req)
	if image != null:
		_store_thumb(key, ImageTexture.create_from_image(image))
	if _colour_waiting.has(key):
		var mid: String = String((_colour_waiting[key] as Dictionary).get("id", ""))
		_colour_waiting.erase(key)
		if image != null:
			_jobs.call("request_swatch", mid + "|" + key, image)
			_wake_body()
		else:
			_store_swatch(mid, {"none": true})
		_pump_colours()
	if _body != null and is_instance_valid(_body):
		_body.queue_redraw()


func scrub_time(m: MediaItem, frac: float) -> float:
	var d: Project = doc()
	var dur: float = d.media_duration(m) if d != null else m.duration
	if dur <= 0.5:
		return -1.0
	var step: int = clampi(int(floor(frac * float(SCRUB_STEPS))), 0, SCRUB_STEPS - 1)
	return minf(float(step) / float(SCRUB_STEPS) * dur, dur - 0.25)


func open_context(entry_id: String, at: Vector2) -> void:
	var d: Project = doc()
	if d == null:
		return
	if RoleDrop.is_entry(entry_id):
		open_role_context(entry_id, at)
		return
	var items: Array = []
	var is_folder: bool = entry_id.begins_with("bin:")
	if not is_folder:
		var m: MediaItem = d.media_by_id(entry_id)
		if m != null and m.kind == "sequence":
			items.append(PmMenu.item("open_sequence", "Open in timeline", "", "seq"))
		else:
			items.append(PmMenu.item("open_source", "Open in Source", "", "film"))
		items.append(PmMenu.item("insert", "Insert at playhead", Cmd.keys_text("edit.insert")))
		items.append(PmMenu.item("overwrite", "Overwrite at playhead", Cmd.keys_text("edit.overwrite")))
		items.append(PmMenu.separator())
	items.append(PmMenu.item("rename", "Rename", "F2"))
	if not is_folder:
		items.append(PmMenu.item("new_bin_from_selection", "New bin from selection"))
		var sub: Array = [PmMenu.check_item("colour:-1", "None", false)]
		for i: int in Tk.LABEL_NAMES.size():
			sub.append(PmMenu.check_item("colour:" + str(i), Tk.label_name(i), false))
		items.append(PmMenu.sub_item("colour", "Label colour", sub))
	items.append(BinTagsMenu.menu_item(d, entry_id, drag_ids_for(entry_id)))
	items.append(PmMenu.sub_item("packs", "Asset packages", pack_menu_items(pack_ids_for(entry_id), is_folder)))
	if not is_folder:
		items.append_array(file_menu_items(d.media_by_id(entry_id)))
	items.append_array(_view_context_items(entry_id))
	items.append(PmMenu.separator())
	if not is_folder:
		var mm: MediaItem = d.media_by_id(entry_id)
		if mm != null and mm.kind == "video" and not mm.props.has("still_time"):
			items.append(PmMenu.sub_item("stills", "Frames as stills", [PmMenu.item("stills:1", "Every frame"), PmMenu.item("stills:2", "Every 2nd frame"), PmMenu.item("stills:5", "Every 5th frame"), PmMenu.item("stills:10", "Every 10th frame"), PmMenu.item("stills:30", "Every 30th frame")]))
		items.append(PmMenu.item("prepare", "Prepare (waveforms, filmstrip, seek index)"))
		items.append(PmMenu.item("rebuild_cache", "Rebuild caches for this media"))
		if mm != null and mm.kind == "video" and not mm.path.is_empty():
			items.append(PmMenu.sub_item("proxies", _proxy_menu_label(d, mm), [PmMenu.item("proxies:used", "Make proxies for the parts in the timeline"), PmMenu.item("proxies:all", "Make proxies for the whole file"), PmMenu.item("proxies:forget", "Throw away this file's proxies"), PmMenu.item("proxies:auto", "Stop building this file's proxies automatically" if not bool(load(AUTO_PROXIES_PATH).call("file_off", mm)) else "Build this file's proxies automatically (slow drives)")]))
	items.append(PmMenu.item("import", "Import files", Cmd.keys_text("file.import"), "import"))
	items.append(PmMenu.item("remove_unused", Cmd.label("file.remove_unused")))
	items.append(PmMenu.item("remove", "Remove", "Delete", "trash"))
	var m: Control = PmMenu.open(_body, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_context_picked.bind(entry_id))


func open_role_context(entry_id: String, at: Vector2) -> void:
	var d: Project = doc()
	var p: Dictionary = RoleDrop.by_id(d, RoleDrop.preset_id_of(entry_id))
	if d == null or p.is_empty() or not _alive():
		return
	var items: Array = []
	var one: MediaItem = d.media_by_id(selected_ids[0]) if selected_ids.size() == 1 else null
	var marked: Dictionary = PmMenu.item("role_apply", "Name the tracks on " + one.label if one != null else "Name the tracks on the marked files")
	marked["disabled"] = selected_ids.is_empty()
	items.append(marked)
	var every: Dictionary = PmMenu.item("role_apply_all", "Name the tracks on every file here")
	every["disabled"] = _body.entries.is_empty()
	items.append(every)
	items.append(PmMenu.separator())
	var ren: Dictionary = PmMenu.item("role_rename", "Rename", "F2")
	ren["disabled"] = RoleDrop.in_project(d, RoleDrop.preset_id_of(entry_id))
	items.append(ren)
	items.append(PmMenu.item("role_forget", "Remove these names", "Delete", "trash"))
	var m: Control = PmMenu.open(_body, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_role_context_picked.bind(entry_id))


func _on_role_context_picked(id: String, entry_id: String) -> void:
	if id == "role_apply":
		apply_role_preset(entry_id, selected_ids)
	elif id == "role_apply_all":
		apply_role_preset(entry_id, role_drop_targets("", true))
	elif id == "role_rename":
		begin_rename(entry_id)
	elif id == "role_forget":
		remove_entry(entry_id)


func pack_ids_for(entry_id: String) -> PackedStringArray:
	if not entry_id.begins_with("bin:"):
		return drag_ids_for(entry_id)
	return media_ids_in_bin(entry_id.substr(4))


func media_ids_in_bin(bin_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var d: Project = doc()
	var root: String = AssetPacks.clean_bin(bin_path)
	if d == null or root.is_empty():
		return out
	for m: MediaItem in d.media:
		if m.kind == "sequence" or m.path.strip_edges().is_empty():
			continue
		var b: String = AssetPacks.clean_bin(m.bin)
		if b == root or b.begins_with(root + "/"):
			out.append(m.id)
	return out


func cached_packs() -> Array[Dictionary]:
	var stamp: int = AssetPacks.library_version()
	if stamp != _packs_stamp:
		_packs_stamp = stamp
		_packs_cache = Presets.list_asset_packs(doc())
	return _packs_cache


func forget_pack_cache() -> void:
	_packs_stamp = -1
	_packs_cache = []


func refresh_watched_packs() -> void:
	if not _alive() or doc() == null:
		return
	AssetPackWatch.forget()
	AssetPackWatch.refresh_all(cached_packs())


func pack_menu_items(ids: PackedStringArray, from_folder: bool = false) -> Array:
	var items: Array = []
	var what: String = "Save this item as a package"
	if from_folder:
		what = "Save this folder as a package"
	elif ids.size() > 1:
		what = "Save the marked items as a package"
	var save: Dictionary = PmMenu.item("pack_save", what)
	save["disabled"] = ids.is_empty()
	items.append(save)
	var packs: Array[Dictionary] = cached_packs()
	items.append(PmMenu.item("pack_open", "All packages" + ((" (" + str(packs.size()) + ")") if not packs.is_empty() else "")))
	if packs.is_empty():
		return items
	items.append(PmMenu.separator())
	var shown: int = 0
	for p: Dictionary in packs:
		if shown >= MAX_PACKS_IN_MENU:
			break
		shown += 1
		var v: Dictionary = AssetPackWatch.view_now(p)
		var tail: String = " (" + str(AssetPacks.items_for(p, v).size()) + ")"
		if AssetPacks.follows(p):
			tail += " follows a folder"
		items.append(PmMenu.item("pack:" + String(p.get("id", "")), AssetPacks.label_of(p) + tail))
	return items


func open_asset_packs() -> void:
	_run_system("open_asset_packs")


func open_asset_pack(pack_id: String) -> void:
	var d: Project = doc()
	if d == null:
		return
	for p: Dictionary in cached_packs():
		if String(p.get("id", "")) != pack_id:
			continue
		if not AssetPacks.import_at_once_of(p):
			open_asset_packs()
			return
		AssetPackWatch.with_view(p, func(v: Dictionary) -> void: _import_pack_now(p, v))
		return
	Events.toast("That package could not be read")


func _import_pack_now(pack: Dictionary, v: Dictionary) -> void:
	var d: Project = doc()
	if d == null:
		return
	var result: Dictionary = AssetPacks.import_chosen(d, pack, AssetPacks.every_path(pack, v), "", v)
	var text: String = AssetPacks.result_note(result)
	Events.toast(text if not text.is_empty() else "Nothing came in from " + AssetPacks.label_of(pack))
	if bool(result["ok"]) and _alive():
		queue_refresh()


func save_asset_pack_from_ids(ids: PackedStringArray) -> void:
	if ids.is_empty():
		Events.toast("Mark the bin items you want in the package first, or right click a bin folder")
		return
	_run_system("open_asset_pack_save", ids)


func file_menu_items(m: MediaItem) -> Array:
	var items: Array = []
	if m == null:
		return items
	var has_file: bool = not m.path.is_empty()
	var reveal: Dictionary = PmMenu.item("reveal", "Reveal in Explorer", Cmd.keys_text("file.reveal"))
	reveal["disabled"] = not has_file
	items.append(reveal)
	var edit: Dictionary = PmMenu.item("edit_original", "Edit original", Cmd.keys_text("file.edit_original"))
	edit["disabled"] = not has_file
	items.append(edit)
	if MadeItems.is_editable(m):
		items.append(PmMenu.item(MadeItems.MENU_SETTINGS, MadeItems.settings_label(m)))
	items.append(PmMenu.item("properties", "Properties", Cmd.keys_text("file.properties")))
	items.append_array(UsageBadges.menu_items(doc(), m.id))
	if StreamRoles.count(m) > 0:
		items.append(PmMenu.item("stream_roles", "Name the audio tracks"))
	var switches: Array[Dictionary] = StreamOff.menu_items(m)
	if not switches.is_empty():
		var sub: Array = []
		for e: Dictionary in switches:
			sub.append(PmMenu.check_item(String(e["id"]), String(e["label"]), bool(e["checked"])))
		items.append(PmMenu.sub_item("audio_streams", "Audio tracks to use", sub))
	if m.missing:
		items.append(PmMenu.item("relink", "Relink missing media"))
	if m.kind == "video" and not m.props.has("still_time"):
		var poster: Dictionary = PmMenu.item("poster", "Set poster frame from the Source monitor")
		poster["disabled"] = source_time_for(m.id) < 0.0
		items.append(poster)
		if m.poster_time > 0.0:
			items.append(PmMenu.item("poster_reset", "Reset poster frame"))
	return items


func toggle_stream(entry_id: String, ordinal: int) -> bool:
	var d: Project = doc()
	var m: MediaItem = d.media_by_id(entry_id) if d != null else null
	if m == null or ordinal < 0:
		return false
	var off: bool = not StreamOff.is_off(m, ordinal)
	var ids: PackedStringArray = drag_ids_for(entry_id)
	if not ids.has(entry_id):
		ids = PackedStringArray([entry_id])
	if not StreamOff.set_off(d, ids, ordinal, off):
		return false
	if off:
		Events.toast(StreamOff.StreamOrdinals.label(m, ordinal) + " is switched off: no waveform, not heard, not exported, and not placed when the file is dropped")
	return true


func source_time_for(media_id: String) -> float:
	var src: Object = bus().panel("source")
	if src == null or String(src.get("media_id")) != media_id:
		return -1.0
	return maxf(float(src.get("time")), 0.0)


func set_poster_frame(media_id: String, t: float) -> bool:
	var d: Project = doc()
	if d == null or t < 0.0:
		return false
	var m: MediaItem = d.media_by_id(media_id)
	if m == null or absf(m.poster_time - t) < 0.0001:
		return false
	var dur: float = d.media_duration(m)
	var clamped: float = clampf(t, 0.0, maxf(dur - 0.001, 0.0)) if dur > 0.0 else maxf(t, 0.0)
	return Verbs.run(d, "Set poster frame" if clamped > 0.0 else "Reset poster frame", [MediaCmds.SetMediaField.new(media_id, "poster_time", clamped)])


func open_sort_menu(at: Vector2) -> void:
	var items: Array = [PmMenu.check_item("sort:", "Import order", sort_by.is_empty())]
	for c: Dictionary in COLUMNS:
		items.append(PmMenu.check_item("sort:" + String(c["id"]), "Sort by " + String(c["label"]).to_lower(), sort_by == String(c["id"])))
	items.append(PmMenu.separator())
	var rev: Dictionary = PmMenu.check_item("sort_desc", "Reverse order", sort_desc)
	rev["disabled"] = sort_by.is_empty()
	items.append(rev)
	var m: Control = PmMenu.open(_body, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_sort_picked)


func _on_sort_picked(id: String) -> void:
	if id == "sort_desc":
		set_sort(sort_by, not sort_desc)
	elif id.begins_with("sort:"):
		set_sort(id.substr(5), false)


func _systems() -> GDScript:
	var s: Variant = load(SYSTEMS_PATH)
	if s is GDScript and (s as GDScript).can_instantiate():
		return s
	return null


func _run_system(fn: String, arg: Variant = null) -> Variant:
	var s: GDScript = _systems()
	if s == null:
		Events.toast("This part of the app did not load")
		return null
	if arg == null:
		return s.call(fn)
	return s.call(fn, arg)


func open_empty_context(at: Vector2) -> void:
	var items: Array = []
	if impl != null and _alive():
		items.append_array(impl.call("empty_items", _body.get_local_mouse_position()))
	items.append(PmMenu.item("import", "Import files", Cmd.keys_text("file.import"), "import"))
	items.append(PmMenu.item("import_folder", "Import a folder and its subfolders", "", "folder"))
	items.append(PmMenu.item("new_bin", "New bin", Cmd.keys_text("file.new_bin"), "folder_new"))
	items.append(PmMenu.sub_item("new", "New item", MadeItems.menu_items(true), "plus"))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("remove_unused", Cmd.label("file.remove_unused")))
	items.append(PmMenu.item("relink", Cmd.label("file.relink")))
	items.append(PmMenu.sub_item("packs", "Asset packages", pack_menu_items(selected_ids)))
	items.append_array(instance_menu_items())
	items.append(PmMenu.separator())
	items.append(PmMenu.sub_item("view", "View", view_menu_items()))
	var m: Control = PmMenu.open(_body, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_empty_context_picked)


func _on_empty_context_picked(id: String) -> void:
	if impl != null and bool(impl.call("on_empty", id)):
		return
	if id.begins_with("view:"):
		set_view(id.substr(5))
		return
	if id.begins_with("pack:"):
		open_asset_pack(id.substr(5))
		return
	if _on_instance_pick(id):
		return
	if id == "pack_save":
		save_asset_pack_from_ids(selected_ids)
	elif id == "pack_open":
		open_asset_packs()
	elif id == "import":
		_on_import()
	elif id == "import_folder":
		_on_import_folder()
	elif id == "new_bin":
		_on_new_bin()
	elif id.begins_with("new."):
		_on_new_item_picked(id)
	elif id == "remove_unused":
		_run_system("open_unused")
	elif id == "relink":
		_run_system("open_relink")


func _on_context_picked(id: String, entry_id: String) -> void:
	var d: Project = doc()
	if d == null:
		return
	if impl != null and bool(impl.call("on_context", id, entry_id)):
		return
	if BinTagsMenu.on_pick(self, _body, d, id, entry_id, drag_ids_for(entry_id)):
		return
	if UsageBadges.on_pick(_root, d, id, drag_ids_for(entry_id)):
		return
	if id.begins_with(StreamOff.MENU_PREFIX):
		toggle_stream(entry_id, StreamOff.ordinal_of_menu(id))
		return
	if id.begins_with("view:"):
		set_view(id.substr(5))
		return
	if id.begins_with("pack:"):
		open_asset_pack(id.substr(5))
		return
	if id.begins_with("stills:"):
		var mi: MediaItem = d.media_by_id(entry_id)
		if mi != null:
			if not mi.probed or mi.fps <= 0.0:
				Events.toast("Wait for " + mi.label + " to finish reading")
				return
			var made: PackedStringArray = MediaLoader.instance().make_stills(d, mi, int(id.substr(7)), folder)
			if made.is_empty():
				Events.toast("No frames could be made from " + mi.label)
			else:
				Events.toast(str(made.size()) + " stills in " + mi.label.get_basename() + " frames")
				refresh()
		return
	if id == "rename":
		begin_rename(entry_id)
	elif id == "import":
		_on_import()
	elif id == "prepare" or id == "rebuild_cache":
		for mid: String in drag_ids_for(entry_id):
			var mi: MediaItem = d.media_by_id(mid)
			if mi == null:
				continue
			var hh: Variant = Session.media_handles.get(mid, -1)
			if id == "rebuild_cache" and typeof(hh) == TYPE_INT and int(hh) >= 0:
				PurrBridge.clear_cache(int(hh))
				PurrBridge.close_media(int(hh))
				Session.media_handles.erase(mid)
				mi.handle = -1
				MediaLoader.instance().open_item(d, mi)
			Session.prepare_media(mi)
		Events.toast("Preparing " + str(drag_ids_for(entry_id).size()) + " item(s), watch the Progress panel")
	elif id == "open_source" or id == "open_sequence":
		activate(entry_id)
	elif id == "insert" or id == "overwrite":
		var tl: Object = bus().panel("timeline")
		if tl != null and tl.has_method("place_at_playhead"):
			tl.call("place_at_playhead", drag_ids_for(entry_id), id)
	elif id == "new_bin_from_selection":
		if not selected_ids.has(entry_id):
			selected_ids = PackedStringArray([entry_id])
		new_bin_from_selection()
	elif id.begins_with("colour:"):
		var colour: int = int(id.substr(7))
		var cmds: Array[Command] = []
		for mid: String in drag_ids_for(entry_id):
			cmds.append(MediaCmds.SetMediaField.new(mid, "colour", colour))
		Verbs.run(d, "Label colour", cmds)
	elif id == "reveal":
		_run_system("reveal_media", entry_id)
	elif id == "edit_original":
		_run_system("edit_media", entry_id)
	elif id == MadeItems.MENU_SETTINGS:
		open_made_settings(entry_id)
	elif id == "properties":
		_run_system("open_properties_for", d.media_by_id(entry_id))
	elif id == "stream_roles":
		_run_system("open_stream_roles_for", d.media_by_id(entry_id))
	elif id == "pack_save":
		save_asset_pack_from_ids(pack_ids_for(entry_id))
	elif id == "pack_open":
		open_asset_packs()
	elif id == "relink":
		_run_system("open_relink")
	elif id == "remove_unused":
		_run_system("open_unused")
	elif id == "poster":
		if not set_poster_frame(entry_id, source_time_for(entry_id)):
			Events.toast("Open this clip in the Source monitor and park on the frame first")
	elif id == "poster_reset":
		set_poster_frame(entry_id, 0.0)
	elif id.begins_with("proxies:"):
		_run_proxies(id.substr(8), drag_ids_for(entry_id))
	elif id == "remove":
		BinKeys.ask_remove(self, _root, entry_id)


const AUTO_PROXIES_PATH := "res://engine/auto_proxies.gd"


func _proxy_menu_label(d: Project, m: MediaItem) -> String:
	var info: Dictionary = load(PROXY_QUEUE_PATH).call("describe", d, m)
	return "Proxies (%d of %d parts built)" % [int(info.get("built", 0)), int(info.get("count", 0))]


func _run_proxies(what: String, ids: PackedStringArray) -> void:
	var d: Project = doc()
	var q: Node = load(PROXY_QUEUE_PATH).call("instance")
	if d == null or q == null:
		return
	if what == "forget":
		Events.toast("Threw away %d proxy part(s)" % int(q.call("forget_for", d, ids)))
		return
	if what == "auto":
		var auto: GDScript = load(AUTO_PROXIES_PATH)
		var first: MediaItem = d.media_by_id(ids[0]) if not ids.is_empty() else null
		var turn_off: bool = first != null and not bool(auto.call("file_off", first))
		var changed: int = 0
		for id: String in ids:
			if bool(auto.call("set_file_off", d, id, turn_off)):
				changed += 1
		Events.toast(("Proxies will not be built automatically for %d file(s)" if turn_off else "Proxies will be built automatically for %d file(s) on slow drives") % changed)
		if not turn_off:
			var node: Node = auto.call("instance")
			if node != null:
				node.call("scan")
		return
	var added: int = int(q.call("make_for", d, ids, what == "used"))
	Events.toast("Making %d proxy part(s), watch the Progress panel" % added if added > 0 else "Those proxies are already built")


func remove_entry(entry_id: String) -> void:
	var d: Project = doc()
	if d == null:
		return
	if entry_id.begins_with("bin:"):
		Verbs.run(d, "Remove bin", [MediaCmds.RemoveBin.new(entry_id.substr(4))])
		return
	if RoleDrop.is_entry(entry_id):
		var gone: Dictionary = RoleDrop.by_id(d, RoleDrop.preset_id_of(entry_id))
		if RoleDrop.forget(d, RoleDrop.preset_id_of(entry_id)):
			if selected_role == entry_id:
				selected_role = ""
			Events.toast(RoleDrop.label_of(gone) + " is no longer in the bin")
			queue_refresh()
		else:
			Events.toast("That set of track names could not be removed")
		return
	var ids: PackedStringArray = drag_ids_for(entry_id)
	var cmds: Array[Command] = []
	for mid: String in ids:
		var m: MediaItem = d.media_by_id(mid)
		if m == null:
			continue
		if m.kind == "sequence":
			cmds.append(SequenceCmds.RemoveSequence.new(m.sequence_id, true))
		else:
			cmds.append(MediaCmds.RemoveMedia.new(mid, true))
	if Verbs.run(d, "Remove " + (str(ids.size()) + " items" if ids.size() > 1 else "item"), cmds):
		for mid: String in ids:
			var h: Variant = Session.media_handles.get(mid, -1)
			if typeof(h) == TYPE_INT and int(h) >= 0:
				Session.media_handles.erase(mid)
				if not Session.media_handles.values().has(int(h)):
					PurrBridge.close_media(int(h))
		selected_ids = PackedStringArray()


func begin_rename(entry_id: String) -> void:
	if not _alive():
		return
	end_rename(false)
	var r: Rect2 = _body.name_rect(entry_id)
	if r.size.x <= 0.0:
		return
	var label: String = ""
	var d: Project = doc()
	if entry_id.begins_with("bin:"):
		label = entry_id.substr(4).get_file()
	elif RoleDrop.is_entry(entry_id):
		var p: Dictionary = RoleDrop.by_id(d, RoleDrop.preset_id_of(entry_id))
		if p.is_empty() or RoleDrop.in_project(d, RoleDrop.preset_id_of(entry_id)):
			return
		label = RoleDrop.label_of(p)
	else:
		var m: MediaItem = d.media_by_id(entry_id) if d != null else null
		if m == null:
			return
		label = m.label
	_rename_id = entry_id
	_rename_edit = PmUI.line_edit("", label)
	_rename_edit.position = r.position
	_rename_edit.size = r.size
	_rename_edit.text_submitted.connect(_on_rename_submitted)
	_rename_edit.focus_exited.connect(_on_rename_focus_out)
	_rename_edit.gui_input.connect(_on_rename_input)
	_body.add_child(_rename_edit)
	_rename_edit.grab_focus()
	_rename_edit.select_all()


func _on_rename_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_rename_edit.accept_event()
		end_rename(false)


func _on_rename_submitted(_text: String) -> void:
	end_rename(true)


func _on_rename_focus_out() -> void:
	end_rename(true)


func end_rename(commit: bool) -> void:
	if _rename_edit == null:
		return
	if not is_instance_valid(_rename_edit):
		_rename_edit = null
		_rename_id = ""
		return
	var le: LineEdit = _rename_edit
	var id: String = _rename_id
	_rename_edit = null
	_rename_id = ""
	var text: String = le.text.strip_edges()
	if le.focus_exited.is_connected(_on_rename_focus_out):
		le.focus_exited.disconnect(_on_rename_focus_out)
	PmUI.free_node(le)
	if not commit or text.is_empty():
		return
	var d: Project = doc()
	if d == null:
		return
	if id.begins_with("bin:"):
		var old: String = id.substr(4)
		var parent: String = old.get_base_dir() if old.contains("/") else ""
		var fresh: String = text if parent.is_empty() else parent + "/" + text
		Verbs.run(d, "Rename bin", [MediaCmds.RenameBin.new(old, fresh)])
	elif RoleDrop.is_entry(id):
		if RoleDrop.rename(d, RoleDrop.preset_id_of(id), text):
			queue_refresh()
	else:
		var m: MediaItem = d.media_by_id(id)
		if m != null and m.label != text:
			var cmds: Array[Command] = [MediaCmds.SetMediaField.new(id, "label", text)]
			if m.kind == "sequence":
				cmds.append(SequenceCmds.SetSequenceField.new(m.sequence_id, "label", text))
			Verbs.run(d, "Rename", cmds)


func handle_key(e: InputEventKey) -> bool:
	if _rename_edit != null and not is_instance_valid(_rename_edit):
		_rename_edit = null
	if not e.pressed or _rename_edit != null:
		return false
	if impl != null and impl.has_method("editing") and bool(impl.call("editing")):
		return false
	if impl != null and bool(impl.call("handle_key", e)):
		return true
	if e.keycode == KEY_F2 and not selected_role.is_empty():
		begin_rename(selected_role)
		return true
	if e.keycode == KEY_F2 and not selected_ids.is_empty():
		begin_rename(selected_ids[0])
		return true
	if e.keycode == KEY_DELETE or e.keycode == KEY_BACKSPACE:
		if not selected_role.is_empty():
			remove_entry(selected_role)
			return true
		if not selected_ids.is_empty():
			BinKeys.ask_remove(self, _root, selected_ids[0])
			return true
		if not selected_folder.is_empty():
			remove_entry("bin:" + selected_folder)
			return true
		return false
	if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
		if not selected_role.is_empty():
			activate(selected_role)
			return true
		if not selected_ids.is_empty():
			activate(selected_ids[0])
			return true
		return false
	if key_is(e, KEY_A, true):
		selected_ids = PackedStringArray()
		for en: Dictionary in _body.entries:
			if String(en["kind"]) == "item":
				selected_ids.append(String(en["id"]))
		_body.queue_redraw()
		_update_footer(_body.entries)
		return true
	var grid: bool = impl == null and view != "list"
	if e.keycode == KEY_UP or e.keycode == KEY_DOWN or (grid and (e.keycode == KEY_LEFT or e.keycode == KEY_RIGHT)):
		if _body.entries.is_empty():
			return true
		var nxt_id: String = BinKeys.step(_body.entries, _body.rects, selected_ids[0] if not selected_ids.is_empty() else "", e.keycode, grid)
		if nxt_id.is_empty():
			return true
		select_entry(nxt_id, "range" if e.shift_pressed else "replace")
		_body.ensure_visible(nxt_id)
		return true
	return false


func save_state() -> Dictionary:
	return {"view": view, "folder": folder, "scroll": _body.scroll.target_y if _alive() else 0.0}


func restore_state(d: Dictionary) -> void:
	var v: String = String(d.get("view", view))
	if v in VIEWS:
		set_view(v)
	folder = String(d.get("folder", ""))
	if _alive():
		refresh()
		_body.scroll.scroll_to(0.0, float(d.get("scroll", 0.0)), false)


static func register_commands() -> void:
	if Cmd.has("bin.view_board") and Cmd.has("bin.board_to_timeline"):
		return
	var me: GDScript = load("res://modules/core_panels/bin_panel.gd")
	for v: String in VIEWS:
		_reg_cmd("bin.view_" + v, Callable(me, "_cmd_view").bind(v))
	_reg_cmd("bin.board_note", Callable(me, "_cmd_board").bind("note"))
	_reg_cmd("bin.board_group", Callable(me, "_cmd_board").bind("group"))
	_reg_cmd("bin.board_to_timeline", Callable(me, "_cmd_board").bind("to_timeline"))


static func _reg_cmd(id: String, handler: Callable) -> void:
	var cat: Dictionary = Cmd.catalogue()
	var label: String = id
	var category: String = "Bin"
	if cat.has(id):
		label = String((cat[id] as Dictionary).get("label", id))
		category = String((cat[id] as Dictionary).get("category", "Bin"))
	Cmd.register(id, {"label": label, "category": category, "scope": "bin", "handler": handler, "owner": OWNER, "enabled": Callable(Bus, "has_doc_static")})


static func _bin_panel() -> Object:
	return Bus.instance().panel("bin")


static func _cmd_view(v: String) -> void:
	var b: Object = _bin_panel()
	if b != null:
		b.call("set_view", v)


static func _cmd_board(what: String) -> void:
	var b: Object = _bin_panel()
	if b != null:
		b.call("board_action", what)


func board_action(what: String) -> void:
	if view != "board":
		set_view("board")
	if impl == null or String(impl.call("id")) != "board":
		return
	if what == "note":
		impl.call("add_note_here")
	elif what == "group":
		impl.call("add_group_here")
	elif what == "to_timeline":
		impl.call("send_to_timeline")


func _add_view_switch(head: HBoxContainer) -> void:
	_view_switch = ViewButton.make_switch("views")
	_view_switch.name = "ViewSwitch"
	_view_switch.pressed.connect(_on_view_switch)
	head.add_child(_view_switch)
	_sync_switch()


static func glyph_for(v: String) -> String:
	if v == "board" or v == "strips" or v == "colours" or v == "recorded" or v == "used":
		return v
	return "views"


func _sync_switch() -> void:
	if _view_switch == null or not is_instance_valid(_view_switch):
		return
	var special: bool = not (view in CLASSIC_VIEWS)
	_view_switch.set("glyph", glyph_for(view))
	_view_switch.set_pressed_no_signal(special)
	_view_switch.call("_restyle")
	if special:
		PmUI.tip(_view_switch, "View: " + String(VIEW_LABELS.get(view, view)) + ", click for more views", Cmd.keys_text("bin.view_" + view))
	else:
		PmUI.tip(_view_switch, "More views: Board, Strips, Colour wall, When recorded, Used parts")


func view_menu_items() -> Array:
	var items: Array = []
	for v: String in VIEWS:
		if v == "board":
			items.append(PmMenu.separator())
		items.append(PmMenu.check_item("view:" + v, String(VIEW_LABELS[v]), v == view, Cmd.keys_text("bin.view_" + v)))
	var d: Project = doc()
	if d != null and not d.sub_projects.is_empty():
		items.append(PmMenu.separator())
		if SubProjects.is_scoped(d):
			items.append(PmMenu.check_item("scope:only", "Only " + SubProjects.name_of(d, SubProjects.active_group(d)) + " media", scope_only()))
		items.append(SubProjectMenu.listing(d))
		items.append(PmMenu.item(SubProjectMenu.PREFIX + "new", "New sub project with the current sequence"))
	return items


static func scope_only() -> bool:
	return not Prefs.is_registered(PREF_SCOPE) or bool(Prefs.get_value(PREF_SCOPE))


static func scope_hidden(d: Project) -> Dictionary:
	if d == null or not scope_only():
		return {}
	var sc: Dictionary = SubProjects.scope(d)
	if not bool(sc["scoped"]):
		return {}
	return sc["elsewhere"]


func _on_sequence_changed(_seq_id: String) -> void:
	var d: Project = doc()
	if d != null and SubProjects.is_scoped(d):
		queue_refresh()


func _on_view_switch() -> void:
	_sync_switch()
	var m: Control = PmMenu.open(_view_switch, view_menu_items())
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_view_menu_picked)


func _on_view_menu_picked(id: String) -> void:
	if id.begins_with("view:"):
		set_view(id.substr(5))
	elif id == "scope:only":
		Prefs.set_value(PREF_SCOPE, not scope_only())
		queue_refresh()
	elif SubProjectMenu.owns(id):
		var d: Project = doc()
		if d != null:
			SubProjectMenu.on_pick(_root, d, d.active_sequence_id, id)


func _add_view_bar(col: VBoxContainer) -> void:
	var wrap: VBoxContainer = PmUI.vbox(0)
	wrap.name = "ViewBar"
	_view_bar_holder = PmUI.panel("bg_panel")
	var sb: StyleBoxFlat = _view_bar_holder.get_theme_stylebox("panel")
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	sb.content_margin_left = float(Tk.px(Tk.sz("pad")))
	sb.content_margin_right = float(Tk.px(Tk.sz("pad")))
	_view_bar = PmToolbar.make()
	_view_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_bar_holder.add_child(_view_bar)
	wrap.add_child(_view_bar_holder)
	wrap.add_child(PmUI.divider())
	wrap.visible = false
	col.add_child(wrap)


func rebuild_view_bar() -> void:
	if _view_bar == null or not is_instance_valid(_view_bar):
		return
	_view_bar.call("clear")
	var show: bool = impl != null
	if show:
		impl.call("build_bar", _view_bar)
	(_view_bar_holder.get_parent() as Control).visible = show
	footer_changed()


func _install_view() -> void:
	if impl != null:
		impl.call("deactivate")
		impl = null
	if VIEW_SCRIPTS.has(view) and _body != null:
		var script: Variant = load(String(VIEW_SCRIPTS[view]))
		if script is GDScript and (script as GDScript).can_instantiate():
			impl = (script as GDScript).new()
			impl.call("setup", self, _body)
	if _body != null:
		_body.set("impl", impl)
		_body.call("reset_view_state")
	rebuild_view_bar()
	_sync_switch()


func _apply_project_view() -> void:
	if doc() == null:
		return
	var v: String = String(view_value("", "view", ""))
	if v in VIEWS and v != view:
		view = v
		for k: String in _view_buttons.keys():
			(_view_buttons[k] as Button).button_pressed = k == v


func _reset_view_caches() -> void:
	_usage = {}
	_usage_stamp = ""
	_colour_waiting.clear()
	_colour_queue.clear()
	_recorded_cache.clear()
	_jobs.call("drop_queue")
	if _alive():
		_install_view()


func view_store() -> Dictionary:
	var d: Project = doc()
	if d == null:
		return {}
	var raw: Variant = d.view.get(VIEW_KEY, null)
	if raw is Dictionary:
		return raw
	var fresh: Dictionary = {}
	d.view[VIEW_KEY] = fresh
	return fresh


func view_value(section: String, key: String, fallback: Variant) -> Variant:
	var st: Dictionary = view_store()
	if section.is_empty():
		return st.get(key, fallback)
	var sec: Variant = st.get(section, null)
	if sec is Dictionary:
		return (sec as Dictionary).get(key, fallback)
	return fallback


func set_view_value(section: String, key: String, value: Variant) -> void:
	if doc() == null:
		return
	var st: Dictionary = view_store()
	if section.is_empty():
		st[key] = value
		return
	var sec: Variant = st.get(section, null)
	if not (sec is Dictionary):
		sec = {}
		st[section] = sec
	if value == null:
		(sec as Dictionary).erase(key)
	else:
		(sec as Dictionary)[key] = value


func select_changed() -> void:
	if _alive():
		_body.queue_redraw()
		_update_footer(_body.entries)


func footer_changed() -> void:
	if _alive() and _footer != null:
		_update_footer(_body.entries)


func _wake_body() -> void:
	if _alive():
		_body.set_process(true)


func poll_jobs() -> bool:
	var changed: bool = false
	var d: Project = doc()
	for r: Dictionary in _jobs.call("poll"):
		var key: String = String(r["key"])
		var sw: Dictionary = r.get("swatch", {}) if r.get("swatch", {}) is Dictionary else {}
		if String(r["kind"]) == "load":
			if key.begins_with("sw|"):
				_store_swatch(key.substr(3), sw)
			else:
				var img: Variant = r.get("image")
				_store_thumb(key, ImageTexture.create_from_image(img as Image) if img is Image else null)
				var mid: String = key.get_slice("|", 0)
				var m: MediaItem = d.media_by_id(mid) if d != null else null
				if m != null and m.kind == "image" and key == m.id + "|poster" + String.num(m.poster_time, 3):
					_store_swatch(mid, sw)
		else:
			_store_swatch(key.get_slice("|", 0), sw)
		changed = true
	if not _colour_waiting.is_empty() or not _colour_queue.is_empty():
		_pump_colours()
	return changed


func jobs_pending() -> bool:
	return bool(_jobs.call("pending")) or not _colour_waiting.is_empty() or not _colour_queue.is_empty()


func colour_time(m: MediaItem) -> float:
	if m == null or m.kind != "video" or m.props.has("still_time"):
		return -1.0
	if m.poster_time > 0.0:
		return m.poster_time
	var d: Project = doc()
	var dur: float = d.media_duration(m) if d != null else m.duration
	if dur <= 1.0:
		return -1.0
	return snappedf(dur * 0.3, 0.01)


func _swatch_source(m: MediaItem) -> String:
	return m.path + "|" + String.num(colour_time(m), 2) + "|" + String.num(m.poster_time, 3)


func _swatch_cache() -> Dictionary:
	var st: Dictionary = view_store()
	var raw: Variant = st.get("swatches", null)
	if raw is Dictionary:
		return raw
	var fresh: Dictionary = {}
	if doc() != null:
		st["swatches"] = fresh
	return fresh


func swatch_for(m: MediaItem) -> Dictionary:
	if m == null or not m.has_picture() or not (m.kind == "video" or m.kind == "image"):
		return {}
	var rec: Variant = _swatch_cache().get(m.id, null)
	if rec is Dictionary and String((rec as Dictionary).get("src", "")) == _swatch_source(m):
		return rec
	_want_swatch(m)
	return {}


func _want_swatch(m: MediaItem) -> void:
	if m.kind == "image":
		if m.path.is_empty() or not FileAccess.file_exists(m.path):
			_store_swatch(m.id, {})
			return
		var tkey: String = m.id + "|poster" + String.num(m.poster_time, 3)
		if bool(_jobs.call("is_waiting", tkey, "load")) or bool(_jobs.call("is_waiting", "sw|" + m.id, "load")):
			return
		if _thumbs.has(tkey):
			_jobs.call("request_load", "sw|" + m.id, m.path, 96, false)
		else:
			_jobs.call("request_load", tkey, m.path, THUMB_W, false)
		_wake_body()
		return
	if _colour_queue.has(m.id):
		return
	for w: Variant in _colour_waiting.values():
		if String((w as Dictionary).get("id", "")) == m.id:
			return
	_colour_queue.append(m.id)
	_pump_colours()


func _pump_colours() -> void:
	var now: int = Time.get_ticks_msec()
	for k: Variant in _colour_waiting.keys():
		var w: Dictionary = _colour_waiting[k]
		if now - int(w.get("at", now)) > COLOUR_SNAP_TIMEOUT_MS:
			_colour_waiting.erase(k)
			_store_swatch(String(w.get("id", "")), {})
	var d: Project = doc()
	while _colour_waiting.size() < MAX_COLOUR_SNAPS and not _colour_queue.is_empty():
		var mid: String = _colour_queue.pop_front()
		var m: MediaItem = d.media_by_id(mid) if d != null else null
		if m == null:
			continue
		var h: int = media_handle(m)
		if h < 0 or not PurrBridge.available or not PurrBridge.has_async_snapshots():
			_store_swatch(mid, {})
			continue
		var t: float = colour_time(m)
		var at: float = t if t >= 0.0 else m.poster_time
		var key: String = m.id + "|" + (String.num(t, 2) if t >= 0.0 else "poster" + String.num(m.poster_time, 3))
		var req: String = str(h) + "|" + String.num(at, 3)
		_colour_waiting[key] = {"id": mid, "at": now}
		var pending: bool = _thumb_requests.has(req)
		_thumb_requests[req] = key
		_hover_jobs.erase(req)
		if not pending:
			if not PurrBridge.snapshot_ready.is_connected(_on_snapshot_ready):
				PurrBridge.snapshot_ready.connect(_on_snapshot_ready)
			PurrBridge.request_snapshot(h, at, THUMB_W)
	if not _colour_waiting.is_empty() or not _colour_queue.is_empty():
		_wake_body()


func _store_swatch(media_id: String, sw: Dictionary) -> void:
	var d: Project = doc()
	var m: MediaItem = d.media_by_id(media_id) if d != null else null
	if m == null:
		return
	var rec: Dictionary = sw.duplicate(true)
	if rec.is_empty() or not rec.has("main"):
		rec = {"main": [0.32, 0.32, 0.32], "palette": [[0.32, 0.32, 0.32]], "grey": true, "none": true}
	rec["src"] = _swatch_source(m)
	_swatch_cache()[media_id] = rec
	if impl != null and impl.has_method("swatches_changed"):
		impl.call("swatches_changed")
	_wake_body()


func colour_progress() -> Vector2i:
	var done: int = 0
	var total: int = 0
	if not _alive():
		return Vector2i.ZERO
	var cache: Dictionary = _swatch_cache()
	for e: Dictionary in _body.entries:
		var it: Variant = e.get("item", null)
		if not (it is MediaItem):
			continue
		var m: MediaItem = it
		if not m.has_picture() or not (m.kind == "video" or m.kind == "image"):
			continue
		total += 1
		var rec: Variant = cache.get(m.id, null)
		if rec is Dictionary and String((rec as Dictionary).get("src", "")) == _swatch_source(m):
			done += 1
	return Vector2i(done, total)


func usage_all() -> Dictionary:
	var d: Project = doc()
	if d == null:
		return {}
	var every: bool = String(view_value("used", "scope", "sequence")) == "every"
	var s: Sequence = seq()
	var stamp: String = str(d.serial) + "|" + ("every" if every else (s.id if s != null else ""))
	if stamp == _usage_stamp:
		return _usage
	if d.undo != null and d.undo.has_live() and not _usage_stamp.is_empty():
		return _usage
	var ids: PackedStringArray = PackedStringArray()
	if not every:
		ids.append(s.id if s != null else "none")
	_usage = Usage.collect(d, ids)
	_usage_stamp = stamp
	return _usage


func usage_for(media_id: String) -> Dictionary:
	return usage_all().get(media_id, {})


func usage_dirty() -> void:
	_usage_stamp = ""


func unused_count() -> int:
	var d: Project = doc()
	if d == null:
		return 0
	var used: Dictionary = usage_all()
	var searching: bool = not search.strip_edges().is_empty()
	var needle: String = search.strip_edges().to_lower()
	var n: int = 0
	for m: MediaItem in d.media:
		if searching and needle.length() > 0:
			if not MediaTags.search_hit(d, m, search):
				continue
		elif m.bin != folder:
			continue
		if not used.has(m.id):
			n += 1
	return n


func _view_context_items(entry_id: String) -> Array:
	if impl == null:
		return []
	return impl.call("context_items", entry_id)


func view_filter(list: Array[Dictionary]) -> Array[Dictionary]:
	if impl == null:
		return list
	return impl.call("filter", list)


func recorded_for(m: MediaItem) -> Dictionary:
	if m == null or MADE_KIND_WORDS.has(m.kind):
		return {"start": -1.0, "end": -1.0, "source": ""}
	var d: Project = doc()
	var dur: float = d.media_duration(m) if d != null else m.duration
	var key: String = m.id + "|" + m.path + "|" + String.num(dur, 3) + "|" + String.num(m.recorded_at, 3)
	if _recorded_cache.has(key):
		return _recorded_cache[key]
	var rec: Dictionary = CaptureTime.recorded(m.label, m.path, file_date(m), dur, m.is_timed(), m.recorded_at)
	if _recorded_cache.size() > 4000:
		_recorded_cache.clear()
	_recorded_cache[key] = rec
	return rec


func item_range(media_id: String) -> Vector2:
	var raw: Variant = view_value("ranges", media_id, null)
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float((raw as Array)[0]), float((raw as Array)[1]))
	return Vector2(-1.0, -1.0)


func set_item_range(media_id: String, in_t: float, out_t: float) -> void:
	if out_t <= in_t:
		set_view_value("ranges", media_id, null)
	else:
		set_view_value("ranges", media_id, [snappedf(maxf(in_t, 0.0), 0.001), snappedf(out_t, 0.001)])
	if _alive():
		_body.queue_redraw()


func begin_range_drag(media_id: String, in_t: float, out_t: float, grab: Vector2) -> void:
	_start_drag(PackedStringArray([media_id]), grab, in_t, out_t)


func rough_cut(ids: PackedStringArray) -> int:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or ids.is_empty():
		return 0
	if s == null:
		Events.toast("Open a sequence first")
		return 0
	var video: Track = _target_track(s, "video")
	var audio: Track = _target_track(s, "audio")
	var t: float = maxf(Session.playhead(), 0.0)
	var placed: int = 0
	var fresh: PackedStringArray = PackedStringArray()
	var tx: RefCounted = d.undo.begin("Send to the timeline in board order")
	for id: String in ids:
		var m: MediaItem = d.media_by_id(id)
		if m == null or m.kind == "sequence" and m.sequence_id == s.id:
			continue
		var track: Track = video if (m.has_picture() and video != null) else audio
		if track == null:
			continue
		if not Verbs.place_media(d, s, id, track.id, t, "insert"):
			continue
		var made: PackedStringArray = Verbs.selection(s)
		var end_t: float = t
		for cid: String in made:
			var c: Clip = s.clip_by_id(cid)
			if c != null:
				end_t = maxf(end_t, c.end())
		fresh.append_array(made)
		t = maxf(t, end_t)
		placed += 1
	tx.call("commit")
	if placed > 0:
		Verbs.select(d, s, fresh, "replace")
		Session.set_playhead(t)
		Events.toast("Sent " + str(placed) + (" clip" if placed == 1 else " clips") + " to the timeline")
	return placed


static func _target_track(s: Sequence, kind: String) -> Track:
	var list: Array[Track] = s.video_tracks if kind == "video" else s.audio_tracks
	for t: Track in list:
		if t.targeted and not t.locked:
			return t
	for t2: Track in list:
		if not t2.locked:
			return t2
	return null


class _Ghost:
	extends Control

	const IconsKit := preload("res://ui/kit/icons.gd")
	const PmTextKit := preload("res://ui/kit/pm_text.gd")

	var label: String = ""
	var icon: String = "film"
	var picture: Texture2D = null
	var count: int = 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var name_h: float = float(Tk.px(18.0))
		var pic: Rect2 = Rect2(0.0, 0.0, size.x, size.y - name_h)
		draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_panel_high"], true)
		draw_rect(pic, Tk.c["bg_field"], true)
		if picture != null:
			var ps: Vector2 = picture.get_size()
			if ps.x > 0.0 and ps.y > 0.0:
				var k: float = minf(pic.size.x / ps.x, pic.size.y / ps.y)
				var ds: Vector2 = ps * k
				draw_texture_rect(picture, Rect2(pic.position + (pic.size - ds) * 0.5, ds), false)
		else:
			var side: float = minf(pic.size.x, pic.size.y) * 0.4
			IconsKit.draw(self, icon, Rect2(pic.position + (pic.size - Vector2(side, side)) * 0.5, Vector2(side, side)), Tk.c["text_faint"])
		var f: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_small"))
		PmTextKit.draw(self, f, Rect2(0.0, size.y - name_h, size.x, name_h), label, fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, PmTextKit.chip_pad(), NAN, PmTextKit.ELIDE_OWN_TIP)
		if count > 1:
			var badge: String = str(count) + " items"
			var bw: float = ceil(PmTextKit.width_of(f, badge, fs)) + PmTextKit.chip_pad() * 2.0
			var br: Rect2 = Rect2(size.x - bw - 4.0, 4.0, bw, ceil(f.get_height(fs)) + 4.0)
			draw_rect(br, Tk.c["bg_panel_alt"], true)
			draw_rect(br, Tk.c["accent_dim"], false, 1.0)
			PmTextKit.draw(self, f, br, badge, fs, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, PmTextKit.chip_pad(), NAN, PmTextKit.WHOLE)
		draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2(1.0, 1.0)), Tk.c["bg_panel_high"].lightened(0.18), false, 1.0)


class _Body:
	extends Control

	const PmScrollDriver := preload("res://ui/kit/pm_scroll.gd")
	const PmSlotKit := preload("res://ui/kit/pm_slot.gd")
	const IconsKit := preload("res://ui/kit/icons.gd")
	const Paint := preload("res://ui/timeline/timeline_paint.gd")
	const PmTipKit := preload("res://ui/kit/pm_tip.gd")
	const PmTextKit := preload("res://ui/kit/pm_text.gd")
	const BinView := preload("res://modules/core_panels/bin_views/bin_view.gd")
	const RoleDropKit := preload("res://doc/role_drop.gd")
	const MarkerTicksKit := preload("res://ui/timeline/marker_ticks.gd")
	const UsageBadgesKit := preload("res://modules/core_panels/bin_views/usage_badges.gd")
	const MediaItemKit := preload("res://doc/media_item.gd")

	var panel: RefCounted = null
	var entries: Array[Dictionary] = []
	var view: String = "list"
	var scroll: Node = null
	var rects: Array[Rect2] = []
	var hover: int = -1
	var hover_col: String = ""
	var hover_frac: float = 0.0
	var press_index: int = -1
	var press_pos: Vector2 = Vector2.ZERO
	var press_mods: Dictionary = {}
	var drag_armed: bool = false
	var content_h: float = 0.0
	var content_w: float = 0.0
	var impl: RefCounted = null
	var draw_usec: int = 0
	var draws: int = 0
	var _slots: Array[Control] = []
	var _scrub_tex: Texture2D = null
	var _scrub_key: String = ""
	var _window: Window = null
	var _tip_proxy: Control = null
	var _tip_index: int = -1

	func _init() -> void:
		name = "BinBody"
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		clip_contents = true
		_tip_proxy = Control.new()
		_tip_proxy.name = "TipProxy"
		_tip_proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tip_proxy)
		scroll = PmScrollDriver.make(false)
		scroll.set("ctrl_wheel_zooms", true)
		scroll.set("alt_wheel_zooms", false)
		scroll.connect("changed", queue_redraw)
		scroll.connect("zoom_requested", _on_zoom)
		add_child(scroll)
		gui_input.connect(_on_input)
		mouse_exited.connect(_on_exit)
		resized.connect(relayout)
		tree_entered.connect(_on_tree_entered)
		tree_exiting.connect(_on_tree_exiting)

	func _on_tree_entered() -> void:
		if panel != null:
			FileDropRouter.attach(get_tree(), panel)

	func _on_tree_exiting() -> void:
		_window = null

	func _on_zoom(steps: float, at: Vector2) -> void:
		if impl != null and bool(impl.call("zoom", steps, at)):
			return
		if view == "list":
			return
		Tk.set_icon_scale("bin", Tk.icon_scale("bin") + 0.1 * signf(steps))

	func reset_view_state() -> void:
		hover = -1
		press_index = -1
		drag_armed = false
		_set_tip(-1)
		scroll.call("scroll_to", 0.0, 0.0, false)
		set_process(true)

	func _process(dt: float) -> void:
		var busy: bool = false
		if panel != null:
			if bool(panel.call("poll_jobs")):
				queue_redraw()
			busy = bool(panel.call("jobs_pending"))
		if impl != null and is_visible_in_tree() and bool(impl.call("tick", dt)):
			busy = true
		if not busy:
			set_process(false)

	func _set_tip(i: int) -> void:
		if i == _tip_index:
			return
		_tip_index = i
		var tip: Control = PmTipKit.instance_for(self) if is_inside_tree() else null
		if i < 0 or i >= rects.size():
			if tip != null:
				tip.call("disarm", _tip_proxy)
			return
		var text: String = String(impl.call("tip_for", i)) if impl != null else _classic_tip(i)
		if text.is_empty():
			if tip != null:
				tip.call("disarm", _tip_proxy)
			return
		var r: Rect2 = screen_rect(i)
		_tip_proxy.position = r.position
		_tip_proxy.size = r.size
		PmTipKit.attach(_tip_proxy, text)
		if tip != null:
			tip.call("arm", _tip_proxy)

	func _badge_press(i: int, at: Vector2) -> bool:
		if view == "list" or i >= entries.size() or String(entries[i].get("kind", "")) != "item":
			return false
		var item: Variant = entries[i].get("item", null)
		if not (item is MediaItemKit):
			return false
		var r: Rect2 = screen_rect(i)
		var pic: Rect2 = Rect2(r.position, Vector2(r.size.x, r.size.y - float(Tk.px(NAME_ROW))))
		if not UsageBadgesKit.hit(pic, Session.doc, item, at):
			return false
		UsageBadgesKit.open_menu(self, Session.doc, (item as MediaItemKit).id, get_global_transform() * at)
		return true

	func _classic_tip(i: int) -> String:
		var extra: String = _notes_tip(i)
		var plain: String = _plain_tip(i)
		if extra.is_empty():
			return plain
		return (plain if not plain.is_empty() else String(entries[i].get("label", ""))) + "
" + extra

	func _notes_tip(i: int) -> String:
		var item: Variant = entries[i].get("item", null)
		if not (item is MediaItemKit):
			return ""
		var lines: PackedStringArray = PackedStringArray()
		var n: int = UsageBadgesKit.count_of(Session.doc, (item as MediaItemKit).id)
		if n > 0:
			lines.append(UsageBadgesKit.badge_text(n) + (" time, right click for where" if n == 1 else " times, right click for where"))
		var note: String = (item as MediaItemKit).notes.strip_edges()
		if not note.is_empty():
			lines.append("Notes: " + note)
		return "
".join(lines)

	func _plain_tip(i: int) -> String:
		var e: Dictionary = entries[i]
		var label: String = String(e.get("label", ""))
		var f: Font = Tk.font("body")
		var r: Rect2 = rects[i]
		var width: float = r.size.x - 4.0
		var fs: int = Tk.fs(Tk.sz("font_small"))
		if view == "list":
			width = maxf(float((columns()[0] as Dictionary)["w"]) - float(Tk.px(48.0)), 20.0)
			fs = Tk.fs(Tk.sz("font_body"))
		if f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			return label
		return ""

	func screen_rect(i: int) -> Rect2:
		if i < 0 or i >= rects.size():
			return Rect2()
		var r: Rect2 = rects[i]
		r.position -= Vector2(float(scroll.get("scroll_x")), float(scroll.get("scroll_y")))
		return r

	func set_entries(list: Array[Dictionary], view_: String) -> void:
		entries = list
		view = view_
		relayout()

	func tile_w() -> float:
		var base: float = TILE_BIG if view == "big" else TILE_GRID
		return float(Tk.px(base)) * Tk.icon_scale("bin")

	func relayout() -> void:
		rects.clear()
		var w: float = maxf(size.x, 1.0)
		content_w = w
		if impl != null:
			var content: Vector2 = impl.call("layout", w, maxf(size.y, 1.0))
			content_w = maxf(content.x, w)
			content_h = content.y
			scroll.call("set_view", size.x, size.y)
			scroll.call("set_content", content_w, content_h)
			if impl.has_method("post_layout"):
				impl.call("post_layout")
			_rebuild_slots()
			_tip_index = -1
			queue_redraw()
			set_process(true)
			return
		if view == "list":
			var rh: float = float(Tk.px(ROW_H))
			var hh: float = header_h()
			for i: int in entries.size():
				rects.append(Rect2(0.0, hh + float(i) * rh, w, rh))
			content_h = hh + float(entries.size()) * rh
		else:
			var tw: float = tile_w()
			var th: float = tw * 0.73 + float(Tk.px(NAME_ROW))
			var gap: float = float(Tk.px(Tk.sz("gap")))
			var pad: float = float(Tk.px(Tk.sz("pad")))
			var cols: int = maxi(1, int(floor((w - pad) / (tw + gap))))
			for i: int in entries.size():
				var cx: int = i % cols
				var cy: int = i / cols
				rects.append(Rect2(pad + float(cx) * (tw + gap), pad + float(cy) * (th + gap), tw, th))
			var rows: int = (entries.size() + cols - 1) / cols
			content_h = pad + float(rows) * (th + gap)
		scroll.call("set_view", size.x, size.y)
		scroll.call("set_content", w, content_h)
		_rebuild_slots()
		queue_redraw()

	func _rebuild_slots() -> void:
		for s: Control in _slots:
			remove_child(s)
			s.queue_free()
		_slots.clear()
		for i: int in entries.size():
			if String(entries[i]["kind"]) != "folder":
				continue
			var slot: Control = PmSlotKit.make(PackedStringArray(["media"]))
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.connect("dropped", _on_slot_drop.bind(String(entries[i]["path"])))
			add_child(slot)
			_slots.append(slot)
			slot.set_meta("index", i)
		_place_slots()

	func _place_slots() -> void:
		var sp: Vector2 = Vector2(float(scroll.get("scroll_x")), float(scroll.get("scroll_y")))
		for s: Control in _slots:
			var i: int = int(s.get_meta("index"))
			if i < rects.size():
				s.position = rects[i].position - sp
				s.size = rects[i].size

	func _on_slot_drop(payload: Dictionary, _local: Vector2, path: String) -> void:
		panel.call("move_to_folder", _ids_of(payload), path)

	static func _ids_of(payload: Dictionary) -> PackedStringArray:
		var out: PackedStringArray = PackedStringArray()
		var raw: Variant = payload.get("ids", [])
		if typeof(raw) == TYPE_ARRAY or typeof(raw) == TYPE_PACKED_STRING_ARRAY:
			for v: Variant in raw:
				out.append(String(v))
		return out

	func header_h() -> float:
		return float(Tk.px(HEADER_H)) if view == "list" else 0.0

	func columns() -> Array[Dictionary]:
		return panel.call("list_columns", maxf(size.x - 6.0, 1.0))

	func header_column_at(local: Vector2) -> String:
		if view != "list" or local.y < 0.0 or local.y >= header_h():
			return ""
		for c: Dictionary in columns():
			if local.x >= float(c["x"]) and local.x < float(c["x"]) + float(c["w"]):
				return String(c["id"])
		return ""

	func index_at(local: Vector2) -> int:
		if view == "list" and local.y < header_h():
			return -1
		var p: Vector2 = local + Vector2(float(scroll.get("scroll_x")), float(scroll.get("scroll_y")))
		for i: int in range(rects.size() - 1, -1, -1):
			if rects[i].has_point(p):
				return i
		return -1

	func index_of(entry_id: String) -> int:
		for i: int in entries.size():
			if String(entries[i]["id"]) == entry_id:
				return i
		return -1

	func name_rect(entry_id: String) -> Rect2:
		var i: int = index_of(entry_id)
		if i < 0 or i >= rects.size():
			return Rect2()
		if impl != null:
			return impl.call("name_rect", i)
		var r: Rect2 = rects[i]
		r.position.y -= float(scroll.get("scroll_y"))
		if view == "list":
			var left: float = float(Tk.px(44.0))
			var cols: Array[Dictionary] = columns()
			var name_w: float = float(cols[0]["w"]) if not cols.is_empty() else r.size.x
			return Rect2(left, r.position.y + 2.0, maxf(name_w - left - 4.0, 40.0), r.size.y * 0.5)
		var nh: float = float(Tk.px(NAME_ROW))
		return Rect2(r.position.x, r.end.y - nh, r.size.x, nh)

	func ensure_visible(entry_id: String) -> void:
		var i: int = index_of(entry_id)
		if i < 0:
			return
		var r: Rect2 = rects[i]
		var sx: float = float(scroll.get("target_x"))
		var sy: float = float(scroll.get("target_y"))
		var hh: float = header_h()
		if r.position.x < sx:
			sx = r.position.x
		elif r.end.x > sx + size.x:
			sx = r.end.x - size.x
		if r.position.y < sy + hh:
			sy = r.position.y - hh
		elif r.end.y > sy + size.y:
			sy = r.end.y - size.y
		scroll.call("scroll_to", sx, sy)

	func _on_exit() -> void:
		hover = -1
		hover_col = ""
		_scrub_tex = null
		_scrub_key = ""
		_set_tip(-1)
		if panel != null:
			panel.call("cancel_hover_thumbs")
		if impl != null:
			impl.call("leave")
		queue_redraw()

	func _on_input(event: InputEvent) -> void:
		if impl != null and bool(impl.call("input", event)):
			accept_event()
			if event is InputEventMouseButton:
				_set_tip(-1)
			return
		if bool(scroll.call("handle", event)):
			accept_event()
			_place_slots()
			return
		if event is InputEventMouseMotion:
			var mm: InputEventMouseMotion = event
			var col_hover: String = header_column_at(mm.position)
			if col_hover != hover_col:
				hover_col = col_hover
				queue_redraw()
			var i: int = index_at(mm.position)
			var changed: bool = i != hover
			if changed and panel != null:
				panel.call("cancel_hover_thumbs")
			hover = i
			_set_tip(i)
			if i >= 0 and view != "list":
				var r: Rect2 = screen_rect(i)
				var frac: float = clampf((mm.position.x - r.position.x) / maxf(r.size.x, 1.0), 0.0, 1.0)
				if absf(frac - hover_frac) > 0.001:
					hover_frac = frac
					changed = true
			if press_index >= 0 and not drag_armed and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
				if (mm.position - press_pos).length() >= float(Tk.px(SLOP)):
					drag_armed = true
					var r2: Rect2 = screen_rect(press_index)
					var grab: Vector2 = press_pos - r2.position
					var idx: int = press_index
					press_index = -1
					panel.call("begin_drag", String(entries[idx]["id"]), grab)
			if changed:
				queue_redraw()
			return
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			var head_col: String = header_column_at(mb.position)
			if view == "list" and mb.position.y < header_h():
				if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not head_col.is_empty():
					panel.call("click_sort", head_col)
				elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
					panel.call("open_sort_menu", get_global_mouse_position())
				accept_event()
				return
			if mb.button_index == MOUSE_BUTTON_LEFT:
				var i: int = index_at(mb.position)
				if mb.pressed:
					if mb.double_click:
						press_index = -1
						drag_armed = false
						if i >= 0:
							panel.call("activate", String(entries[i]["id"]))
						accept_event()
						return
					if i >= 0 and _badge_press(i, mb.position):
						accept_event()
						return
					press_index = i
					press_pos = mb.position
					press_mods = {"ctrl": mb.ctrl_pressed or mb.meta_pressed, "shift": mb.shift_pressed}
					drag_armed = false
					if i >= 0 and not bool(press_mods["ctrl"]) and not bool(press_mods["shift"]):
						var id: String = String(entries[i]["id"])
						var sel: PackedStringArray = panel.get("selected_ids")
						if not sel.has(id):
							panel.call("select_entry", id, "replace")
					accept_event()
				else:
					if press_index >= 0 and not drag_armed and i == press_index:
						var id2: String = String(entries[i]["id"])
						var mode: String = "replace"
						if bool(press_mods.get("ctrl", false)):
							mode = "toggle"
						elif bool(press_mods.get("shift", false)):
							mode = "range"
						panel.call("select_entry", id2, mode)
					elif press_index >= 0 and not drag_armed and i < 0:
						panel.call("clear_selection")
					press_index = -1
					drag_armed = false
					accept_event()
				return
			if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				var i2: int = index_at(mb.position)
				if i2 >= 0:
					var id3: String = String(entries[i2]["id"])
					var sel2: PackedStringArray = panel.get("selected_ids")
					if not sel2.has(id3):
						panel.call("select_entry", id3, "replace")
					panel.call("open_context", id3, get_global_mouse_position())
				else:
					panel.call("open_empty_context", get_global_mouse_position())
				accept_event()

	func _draw() -> void:
		var t0: int = Time.get_ticks_usec()
		if impl != null:
			_draw_view()
		else:
			_draw_classic()
		draw_usec = Time.get_ticks_usec() - t0
		draws += 1

	func _draw_view() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_panel"], true)
		_place_slots()
		impl.call("draw")
		if entries.is_empty():
			var f: Font = Tk.font("body")
			var fs_body: int = Tk.fs(Tk.sz("font_body"))
			var msg: String = "Drop files here or press Import" if Session.doc != null else "No project is open"
			PmTextKit.draw(self, f, Rect2(Vector2.ZERO, size), msg, fs_body, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_CENTER, -1.0, size.y * 0.5)
		if bool(impl.call("draws_scrollbar")) and content_h > size.y:
			var sy: float = float(scroll.get("scroll_y"))
			var bar_h: float = maxf(20.0, size.y * size.y / content_h)
			var bar_y: float = (size.y - bar_h) * (sy / maxf(1.0, content_h - size.y))
			draw_rect(Rect2(size.x - 5.0, bar_y, 3.0, bar_h), Tk.c["accent_dim"], true)

	func _draw_classic() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_panel"], true)
		_place_slots()
		var sy: float = float(scroll.get("scroll_y"))
		var f: Font = Tk.font("body")
		var fs_body: int = Tk.fs(Tk.sz("font_body"))
		var fs_small: int = Tk.fs(Tk.sz("font_small"))
		var sel: PackedStringArray = panel.get("selected_ids")
		var sel_folder: String = String(panel.get("selected_folder"))
		var sel_role: String = String(panel.get("selected_role"))
		var doc_: RefCounted = Session.doc
		var mono_f: Font = Tk.font("mono")
		var list_cols: Array[Dictionary] = []
		if view == "list":
			list_cols = columns()
		for i: int in entries.size():
			var r: Rect2 = rects[i]
			r.position.y -= sy
			if r.end.y < 0.0 or r.position.y > size.y:
				continue
			var e: Dictionary = entries[i]
			var id: String = String(e["id"])
			var is_folder: bool = String(e["kind"]) == "folder"
			var is_role: bool = String(e["kind"]) == RoleDropKit.ENTRY_KIND
			var item: RefCounted = e["item"]
			var selected: bool = (is_folder and sel_folder == String(e["path"])) or (is_role and sel_role == id) or (not is_folder and not is_role and sel.has(id))
			if view == "list":
				if selected:
					Paint.rounded(self, r.grow_individual(-2.0, 0.0, -2.0, -1.0), Tk.c["glass_strong"], float(Tk.px(Tk.sz("radius_row"))))
				elif i == hover:
					Paint.rounded(self, r.grow_individual(-2.0, 0.0, -2.0, -1.0), Tk.c["glass"], float(Tk.px(Tk.sz("radius_row"))))
				draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), Tk.c["lane_line"], true)
				var colour: int = int(item.get("colour")) if item != null else -1
				if colour >= 0:
					draw_rect(Rect2(r.position.x, r.position.y + 2.0, 3.0, r.size.y - 4.0), Tk.label_colour(colour), true)
				var icon: String = RoleDropKit.ENTRY_ICON if is_role else ("folder" if is_folder else String(panel.call("kind_icon", String(item.get("kind")))))
				var ic: float = float(Tk.px(16.0))
				IconsKit.draw(self, icon, Rect2(r.position.x + float(Tk.px(14.0)), r.position.y + (r.size.y - ic) * 0.5, ic, ic), Tk.c["text_dim"])
				var left: float = r.position.x + float(Tk.px(44.0))
				var name_col: Color = Tk.c["text_bright"] if selected else Tk.c["text"]
				var name_w: float = maxf(float(list_cols[0]["w"]) - left - 4.0, 20.0)
				var meta: String = String(panel.call("hidden_facts", e, list_cols))
				var meta_col: Color = Tk.c["text_dim"]
				if item != null and bool(item.get("missing")):
					meta_col = Tk.c["text"]
				var name_cell: Rect2 = Rect2(r.position.x, r.position.y, float(list_cols[0]["w"]), r.size.y)
				name_w = minf(name_w, name_cell.end.x - PmTextKit.pad() - left)
				if meta.is_empty():
					PmTextKit.draw_in(self, f, Rect2(left, r.position.y, name_w, r.size.y), String(e["label"]), fs_body, name_col, HORIZONTAL_ALIGNMENT_LEFT, NAN, PmTextKit.ELIDE_OWN_TIP, name_cell)
				else:
					PmTextKit.draw_in(self, f, Rect2(left, r.position.y, name_w, r.size.y), String(e["label"]), fs_body, name_col, HORIZONTAL_ALIGNMENT_LEFT, r.position.y + 3.0 + f.get_ascent(fs_body), PmTextKit.ELIDE_OWN_TIP, name_cell)
					PmTextKit.draw_in(self, f, Rect2(left, r.position.y, name_w, r.size.y), meta, fs_small, meta_col, HORIZONTAL_ALIGNMENT_LEFT, r.position.y + r.size.y * 0.5 + 1.0 + f.get_ascent(fs_small), PmTextKit.ELIDE_OWN_TIP, name_cell)
				var values: Dictionary = e.get("cols", {})
				for ci: int in range(1, list_cols.size()):
					var cdef: Dictionary = list_cols[ci]
					var v: String = String(values.get(String(cdef["id"]), ""))
					if v.is_empty():
						continue
					PmTextKit.draw(self, mono_f, Rect2(float(cdef["x"]), r.position.y, float(cdef["w"]), r.size.y), v, fs_small, Tk.c["text_dim"], HORIZONTAL_ALIGNMENT_LEFT, float(Tk.px(6.0)), NAN, PmTextKit.ELIDE_OWN_TIP)
				if item != null and not String(item.get("notes")).is_empty():
					IconsKit.draw(self, "more", Rect2(left + name_w - ic, r.position.y + (r.size.y - ic) * 0.5, ic, ic), Tk.c["text_faint"])
			else:
				var nh: float = float(Tk.px(NAME_ROW))
				var pic: Rect2 = Rect2(r.position, Vector2(r.size.x, r.size.y - nh))
				var tile_r: float = float(Tk.px(Tk.sz("radius")))
				Paint.rounded(self, pic, Tk.c["bg_panel_alt"], tile_r, Tk.c["border"], 1)
				var tex: Texture2D = null
				if item != null:
					var t: float = -1.0
					if i == hover and String(item.get("kind")) == "video":
						t = float(panel.call("scrub_time", item, hover_frac))
					tex = panel.call("thumb_for", item, t)
				if tex != null:
					var ps: Vector2 = tex.get_size()
					if ps.x > 0.0 and ps.y > 0.0:
						var k: float = minf(pic.size.x / ps.x, pic.size.y / ps.y)
						var ds: Vector2 = ps * k
						draw_texture_rect(tex, Rect2(pic.position + (pic.size - ds) * 0.5, ds), false)
				else:
					var side: float = minf(pic.size.x, pic.size.y) * 0.34
					var gicon: String = RoleDropKit.ENTRY_ICON if is_role else ("folder" if is_folder else String(panel.call("kind_icon", String(item.get("kind")))))
					IconsKit.draw(self, gicon, Rect2(pic.position + (pic.size - Vector2(side, side)) * 0.5, Vector2(side, side)), Tk.c["text_faint"])
				if item != null and doc_ != null and bool(item.call("is_timed")):
					var dur: float = float(doc_.call("media_duration", item))
					var tct: String = String(panel.call("tc", dur)).substr(3, 5)
					var mono: Font = Tk.font("mono")
					var tw2: float = ceil(PmTextKit.width_of(mono, tct, fs_small)) + PmTextKit.chip_pad() * 2.0
					var bh: float = ceil(mono.get_height(fs_small)) + 3.0
					var br: Rect2 = Rect2(pic.end.x - tw2 - 4.0, pic.end.y - bh - 3.0, tw2, bh)
					if tw2 <= pic.size.x - 8.0:
						Paint.rounded(self, br, Color(Tk.c["bg_app"], 0.72), float(Tk.px(Tk.sz("radius_chip"))))
						PmTextKit.draw(self, mono, br, tct, fs_small, Tk.c["text_bright"], HORIZONTAL_ALIGNMENT_LEFT, PmTextKit.chip_pad(), NAN, PmTextKit.WHOLE)
				if item != null and int(item.get("colour")) >= 0:
					draw_rect(Rect2(pic.position.x, pic.position.y, 3.0, pic.size.y), Tk.label_colour(int(item.get("colour"))), true)
				if item != null and doc_ != null and not (item.get("markers") as Array).is_empty():
					MarkerTicksKit.draw_tile(self, pic, item, float(doc_.call("media_duration", item)))
				if item != null and not is_role:
					UsageBadgesKit.draw_tile(self, pic, doc_, item)
				if i == hover and view != "list" and item != null and String(item.get("kind")) == "video":
					draw_rect(Rect2(pic.position.x + pic.size.x * hover_frac, pic.position.y, 1.0, pic.size.y), Tk.c["accent_dim"], true)
				var ncol: Color = Tk.c["text_bright"] if selected else Tk.c["text"]
				PmTextKit.draw(self, f, Rect2(r.position.x, r.end.y - nh, r.size.x, nh), String(e["label"]), fs_small, ncol, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NAN, PmTextKit.ELIDE_OWN_TIP)
				if selected:
					Paint.rounded(self, pic, Color(0, 0, 0, 0), tile_r, Tk.c["sol"], 1)
				elif i == hover:
					Paint.rounded(self, pic, Color(0, 0, 0, 0), tile_r, Tk.c["text_faint"], 1)
		if view == "list":
			_draw_header(list_cols, mono_f)
		if entries.is_empty():
			var msg: String = "Drop files here or press Import" if Session.doc != null else "No project is open"
			PmTextKit.draw(self, f, Rect2(Vector2.ZERO, size), msg, fs_body, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_CENTER, -1.0, size.y * 0.5)
		if content_h > size.y:
			var frac: float = size.y / content_h
			var bar_h: float = maxf(20.0, size.y * frac)
			var bar_y: float = (size.y - bar_h) * (sy / maxf(1.0, content_h - size.y))
			draw_rect(Rect2(size.x - 5.0, bar_y, 3.0, bar_h), Tk.c["accent_dim"], true)

	func _draw_header(cols: Array[Dictionary], mono_f: Font) -> void:
		var hh: float = header_h()
		draw_rect(Rect2(0.0, 0.0, size.x, hh), Tk.c["bg_panel"], true)
		draw_rect(Rect2(0.0, hh - 1.0, size.x, 1.0), Tk.c["border"], true)
		var fs_meta: int = Tk.fs(Tk.sz("font_meta"))
		var sort_by: String = String(panel.get("sort_by"))
		var desc: bool = bool(panel.get("sort_desc"))
		for c: Dictionary in cols:
			var id: String = String(c["id"])
			var x: float = float(c["x"])
			var w: float = float(c["w"])
			if id == hover_col:
				Paint.rounded(self, Rect2(x + 1.0, 1.0, w - 2.0, hh - 3.0), Tk.c["glass"], float(Tk.px(Tk.sz("radius_row"))))
			var tx: float = x + (float(Tk.px(44.0)) if id == "name" else float(Tk.px(6.0)))
			var text: String = String(c["label"]).to_upper()
			var on: bool = id == sort_by
			var col: Color = Tk.c["text_bright"] if on else Tk.c["text_faint"]
			var ty: float = (hh - mono_f.get_height(fs_meta)) * 0.5 + mono_f.get_ascent(fs_meta)
			var drawn: Rect2 = PmTextKit.draw_in(self, mono_f, Rect2(tx, 0.0, maxf(w - (tx - x) - 12.0, 8.0), hh), text, fs_meta, col, HORIZONTAL_ALIGNMENT_LEFT, ty, PmTextKit.ELIDE, Rect2(x, 0.0, w, hh))
			if on:
				var tw: float = drawn.size.x
				var ax: float = tx + tw + float(Tk.px(5.0))
				var ay: float = hh * 0.5
				var s3: float = float(Tk.px(3.0))
				var tri: PackedVector2Array = PackedVector2Array([Vector2(ax - s3, ay + s3 * 0.6), Vector2(ax + s3, ay + s3 * 0.6), Vector2(ax, ay - s3 * 0.8)]) if not desc else PackedVector2Array([Vector2(ax - s3, ay - s3 * 0.6), Vector2(ax + s3, ay - s3 * 0.6), Vector2(ax, ay + s3 * 0.8)])
				draw_colored_polygon(tri, col)

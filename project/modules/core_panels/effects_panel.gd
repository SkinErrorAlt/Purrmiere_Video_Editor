extends "res://modules/core_panels/panel_base.gd"

const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const Folders := preload("res://modules/core_panels/effect_folders.gd")
const COMPACT_ROW_H := 22.0
const EffectPreview := preload("res://modules/core_panels/effect_preview.gd")
const ICON_W := 32.0
const ROW_H := 30.0
const STAR_W := 22.0
const PREVIEW_DELAY := 0.45
const CARD_GAP := 18.0
const THUMBS_PER_TICK := 2
const THUMB_CACHE_MAX := 120
const TILE_GRID := 104.0
const TILE_BIG := 176.0
const SCALE_MIN := 0.7
const SCALE_MAX := 1.8
const SCALE_STEP := 0.15
const VIEWS: PackedStringArray = ["list", "compact", "grid", "big"]
const CLASSIC_VIEWS: PackedStringArray = ["list"]
const VIEW_LABELS: Dictionary = {"list": "List", "compact": "Compact list", "grid": "Grid", "big": "Big tiles"}
const VIEW_SCRIPTS: Dictionary = {
	"grid": "res://modules/core_panels/effect_views/tile_view.gd",
	"big": "res://modules/core_panels/effect_views/tile_view.gd",
}
const SORTS: PackedStringArray = ["", "name", "category", "recent", "favourite", "mine"]
const SORT_LABELS: Dictionary = {"": "Library order", "name": "Name", "category": "Category", "recent": "Recently used", "favourite": "Favourites first", "mine": "My order (drag to arrange)"}
const KINDS: PackedStringArray = ["", "video", "audio"]
const KIND_LABELS: Dictionary = {"": "Picture and sound", "video": "Picture only", "audio": "Sound only"}
const PREF_VIEW := "effects.view"
const PREF_SORT := "effects.sort"
const PREF_SORT_DESC := "effects.sort_desc"
const PREF_TAG := "effects.filter_tag"
const PREF_KIND := "effects.filter_kind"
const PREF_SORTS: PackedStringArray = ["default", "name", "category", "recent", "favourite", "mine"]
const PREF_KINDS: PackedStringArray = ["all", "video", "audio"]
const PREF_HANDLES := "effects.filter_handles"
const PREF_USER := "effects.filter_user"
const PREF_SCALE := "effects.tile_scale"
const CATEGORY_ICONS: Dictionary = {
	"Audio": "audio",
	"Audio Transitions": "bleep",
	"Audio Reactive": "speaker",
	"Blur & Sharpen": "combo",
	"Channel": "chain",
	"Colour Correction": "image",
	"Distort": "rate",
	"Generate": "diamond_o",
	"Image Control": "restore",
	"Immersive Video": "eye",
	"Keying": "target_off",
	"Light & Shadow": "sun",
	"Noise & Grain": "more",
	"Purrmiere": "paw",
	"Stylize": "fx",
	"Time": "stopwatch",
	"Transform": "roll",
	"Transition": "slip",
	"User": "pen",
	"Utility": "wrench",
	"VHS & Analogue": "film",
	"Video Transitions": "slide",
	"YouTube": "play",
	"Colour": "image",
	"Color": "image",
	"Stylise": "fx",
	"Perspective": "sun",
}
const FALLBACK_ICON := "region"
const VIDEO_TRANSITIONS: Array = [["dissolve", "Cross dissolve"], ["dip_black", "Dip to black"], ["dip_white", "Dip to white"], ["wipe_left", "Wipe left"], ["wipe_right", "Wipe right"], ["wipe_up", "Wipe up"], ["wipe_down", "Wipe down"], ["push_left", "Push left"], ["push_right", "Push right"], ["push_up", "Push up"], ["push_down", "Push down"], ["slide_left", "Slide left"], ["slide_right", "Slide right"], ["slide_up", "Slide up"], ["slide_down", "Slide down"]]
const AUDIO_TRANSITIONS: Array = [["crossfade", "Crossfade"]]
const AUDIO_GROUP_ORDER: PackedStringArray = ["EQ and Filters", "Dynamics", "Stereo", "Delay and Reverb", "Modulation", "Character", "Voice", "Repair", "Presets", "Mastering", "Sound Design", "Rhythm", "Utility"]

var search: String = ""
var view: String = "list"
var sort_by: String = ""
var sort_desc: bool = false
var filter_tag: String = ""
var filter_kind: String = ""
var filter_handles: bool = false
var filter_user: bool = false
var impl: RefCounted = null
var _search: LineEdit = null
var _list: VBoxContainer = null
var _status: Label = null
var _rows: Array[Control] = []
var _view_buttons: Dictionary = {}
var _sort_button: Button = null
var _filter_button: Button = null
var _view_bar_holder: PanelContainer = null
var _view_bar: Container = null
var _press_pos: Vector2 = Vector2.ZERO
var _press_id: String = ""
var _folder_stamp: String = ""
var _since_look: float = 0.0
var _hover_id: String = ""
var _hover_for: float = 0.0
var _card: PanelContainer = null
var _card_tex: TextureRect = null
var _card_label: Label = null
var _preview: Node = null
var _frame_key: String = ""
var _lists_dirty: bool = false
var _thumbs: Dictionary = {}
var _thumb_key: String = ""
var _thumb_preview: Node = null
var _thumb_rows: Array[Control] = []
var sections: PackedStringArray = PackedStringArray()


func _build(root_: Control) -> void:
	_register_prefs()
	_load_prefs()
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_search = PmUI.line_edit("Search effects")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_on_search)
	head.add_child(_search)
	for v: String in VIEWS:
		var b: Button = toggle_icon("list" if v == "list" or v == "compact" else "grid", String(VIEW_LABELS[v]) + " view", view == v)
		if v == "compact":
			b.set("icon_px", 12.0)
		if v == "big":
			b.set("icon_px", 20.0)
		b.pressed.connect(_on_view_pressed.bind(v))
		head.add_child(b)
		_view_buttons[v] = b
	_sort_button = quiet_icon("realign", "Sort the effects")
	_sort_button.pressed.connect(_on_sort_button)
	head.add_child(_sort_button)
	_filter_button = quiet_icon("select", "Narrow the list down")
	_filter_button.pressed.connect(_on_filter_button)
	head.add_child(_filter_button)
	var reload: Button = quiet_icon("loop", "Reload the effect folders")
	reload.pressed.connect(_on_reload)
	head.add_child(reload)
	var new_folder_btn: Button = quiet_icon("folder_new", "New folder: drag effects into it, it stays where you put it")
	new_folder_btn.name = "NewEffectFolder"
	new_folder_btn.pressed.connect(_on_new_folder)
	head.add_child(new_folder_btn)
	var open_folder: Button = quiet_icon("folder", "Open the folder to drop your own shaders into")
	open_folder.pressed.connect(_on_open_folder)
	head.add_child(open_folder)
	load("res://modules/core_panels/shader_import.gd").call("add_menu_button", self, head)
	_add_view_bar(col)
	var scroll: ScrollContainer = vscroll_area(col)
	_list = PmUI.vbox(0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	col.add_child(PmUI.divider())
	_status = PmLabel.dim("")
	col.add_child(PmUI.inset(_status))
	_install_view()
	rebuild()


func _register_prefs() -> void:
	if not Prefs.is_registered(PREF_VIEW):
		Prefs.register(PREF_VIEW, "list", {"label": "Effects view", "type": "enum", "choices": VIEWS})
	if not Prefs.is_registered(PREF_SORT):
		Prefs.register(PREF_SORT, PREF_SORTS[0], {"label": "Effects sort", "type": "enum", "choices": PREF_SORTS})
		if String(Prefs.get_value(PREF_SORT)).is_empty():
			Prefs.set_value(PREF_SORT, PREF_SORTS[0])
	if not Prefs.is_registered(PREF_SORT_DESC):
		Prefs.register(PREF_SORT_DESC, false, {"label": "Effects sort reversed", "type": "bool"})
	if not Prefs.is_registered(PREF_TAG):
		Prefs.register(PREF_TAG, "", {"label": "Effects tag filter", "type": "string"})
	if not Prefs.is_registered(PREF_KIND):
		Prefs.register(PREF_KIND, PREF_KINDS[0], {"label": "Effects kind filter", "type": "enum", "choices": PREF_KINDS})
		if String(Prefs.get_value(PREF_KIND)).is_empty():
			Prefs.set_value(PREF_KIND, PREF_KINDS[0])
	if not Prefs.is_registered(PREF_HANDLES):
		Prefs.register(PREF_HANDLES, false, {"label": "Effects with handles only", "type": "bool"})
	if not Prefs.is_registered(PREF_USER):
		Prefs.register(PREF_USER, false, {"label": "Effects you made only", "type": "bool"})
	if not Prefs.is_registered(PREF_SCALE):
		Prefs.register(PREF_SCALE, 1.0, {"label": "Effect tile size", "type": "float", "min": SCALE_MIN, "max": SCALE_MAX, "step": SCALE_STEP})


func _load_prefs() -> void:
	view = String(Prefs.get_value(PREF_VIEW))
	if not (view in VIEWS):
		view = "list"
	sort_by = from_pref(String(Prefs.get_value(PREF_SORT)), PREF_SORTS)
	if not (sort_by in SORTS):
		sort_by = ""
	sort_desc = bool(Prefs.get_value(PREF_SORT_DESC)) and not sort_by.is_empty()
	filter_tag = String(Prefs.get_value(PREF_TAG))
	filter_kind = from_pref(String(Prefs.get_value(PREF_KIND)), PREF_KINDS)
	if not (filter_kind in KINDS):
		filter_kind = ""
	filter_handles = bool(Prefs.get_value(PREF_HANDLES))
	filter_user = bool(Prefs.get_value(PREF_USER))


func tile_scale() -> float:
	return clampf(float(Prefs.get_value(PREF_SCALE)), SCALE_MIN, SCALE_MAX)


func set_tile_scale(v: float) -> void:
	Prefs.set_value(PREF_SCALE, clampf(v, SCALE_MIN, SCALE_MAX))
	rebuild_view_bar()
	rebuild()


func def_for(id: String) -> Dictionary:
	if id.begins_with("transition:"):
		return transition_def(id.substr(11))
	return EffectSource.get_def(id)


static func transition_def(kind: String) -> Dictionary:
	for pair: Array in VIDEO_TRANSITIONS:
		if String(pair[0]) == kind:
			return {"id": "transition:" + kind, "label": String(pair[1]), "category": "Video Transitions", "transition": kind, "track": "video"}
	for pair2: Array in AUDIO_TRANSITIONS:
		if String(pair2[0]) == kind:
			return {"id": "transition:" + kind, "label": String(pair2[1]), "category": "Audio Transitions", "transition": kind, "track": "audio"}
	return {}


static func transition_defs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pair: Array in VIDEO_TRANSITIONS:
		out.append(transition_def(String(pair[0])))
	for pair2: Array in AUDIO_TRANSITIONS:
		out.append(transition_def(String(pair2[0])))
	return out


func _on_search(text: String) -> void:
	search = text.strip_edges().to_lower()
	rebuild()


const FOLDER_LOOK_EVERY := 2.0


func _on_open_folder() -> void:
	var root: String = ProjectSettings.globalize_path(EffectSource.user_root())
	DirAccess.make_dir_recursive_absolute(root)
	OS.shell_open(root)
	Events.notice("Drop a shader in here", "A .gdshader file becomes an effect on its own, and a folder with an effect.json can hold several passes and nicer names. Purrmiere picks it up within a couple of seconds, with no restart.")


func tick(dt: float) -> void:
	if not _alive() or not _root.is_visible_in_tree():
		if _card != null and _card.visible:
			_hide_card()
		_drop_thumb_preview()
		return
	_tick_hover(dt)
	_tick_thumbs()
	if _lists_dirty and not _root.get_global_rect().has_point(_root.get_global_mouse_position()):
		_lists_dirty = false
		rebuild()
	_since_look += dt
	if _since_look < FOLDER_LOOK_EVERY:
		return
	_since_look = 0.0
	var now: String = EffectSource.user_stamp()
	if now == _folder_stamp:
		return
	var first: bool = _folder_stamp.is_empty()
	_folder_stamp = now
	if first:
		return
	EffectSource.reload_effects()
	rebuild()
	Events.toast("The effects folder changed, " + str(EffectSource.list().size()) + " effects loaded")


func _on_reload() -> void:
	_folder_stamp = EffectSource.user_stamp()
	EffectSource.reload_effects()
	forget_thumbs()
	rebuild()
	Events.toast("Effects reloaded, " + str(EffectSource.list().size()) + " found")


func forget_thumbs() -> void:
	_thumbs.clear()
	_thumb_key = ""
	_drop_thumb_preview()


func _drop_thumb_preview() -> void:
	if _thumb_preview != null and is_instance_valid(_thumb_preview):
		PmUI.free_node(_thumb_preview)
	_thumb_preview = null


func _ensure_thumb_preview() -> Node:
	if _thumb_preview != null and is_instance_valid(_thumb_preview):
		return _thumb_preview
	if not EffectPreview.available() or not _alive():
		return null
	var p: Node = EffectPreview.new()
	_root.get_tree().root.add_child(p)
	if not bool(p.call("set_frame", _current_frame())):
		PmUI.free_node(p)
		return null
	_thumb_preview = p
	return _thumb_preview


func _render_thumb(id: String) -> Texture2D:
	if not can_preview(id):
		return null
	var p: Node = _ensure_thumb_preview()
	if p == null or not bool(p.call("show_effect", id)):
		return null
	var tex: Variant = p.call("texture")
	if not (tex is Texture2D):
		return null
	var img: Image = (tex as Texture2D).get_image()
	if img == null or img.is_empty():
		return null
	var out: ImageTexture = ImageTexture.create_from_image(img)
	if _thumbs.size() >= THUMB_CACHE_MAX:
		_thumbs.clear()
	_thumbs[id] = out
	return out


func _tick_thumbs() -> void:
	if _thumb_rows.is_empty():
		_drop_thumb_preview()
		return
	if not EffectPreview.available():
		return
	var key: String = _frame_stamp()
	if key != _thumb_key:
		_thumb_key = key
		_thumbs.clear()
		_drop_thumb_preview()
		for t: Control in _thumb_rows:
			if is_instance_valid(t):
				t.set("texture", null)
	var scroll: ScrollContainer = PmUI.scroll_of(_list)
	if scroll == null or not scroll.is_inside_tree():
		return
	var seen: Rect2 = scroll.get_global_rect().grow(float(Tk.px(48.0)))
	var made: int = 0
	for t2: Control in _thumb_rows:
		if not is_instance_valid(t2):
			continue
		var id: String = String(t2.get("effect_id"))
		if _thumbs.has(id):
			if t2.get("texture") == null:
				t2.set("texture", _thumbs[id])
			continue
		if made >= THUMBS_PER_TICK or not seen.intersects(t2.get_global_rect()):
			continue
		if _render_thumb(id) == null:
			continue
		t2.set("texture", _thumbs[id])
		made += 1


func _matches(d: Dictionary) -> bool:
	if search.is_empty():
		return true
	if String(d.get("label", d.get("id", ""))).to_lower().contains(search):
		return true
	for key: String in ["id", "group", "blurb", "category"]:
		if String(d.get(key, "")).to_lower().contains(search):
			return true
	for tag: String in EffectSource.tags_of(d):
		if tag.contains(search):
			return true
	return false


func passes_filters(d: Dictionary) -> bool:
	if not filter_tag.is_empty() and not EffectSource.has_tag(d, filter_tag):
		return false
	if not filter_kind.is_empty() and EffectSource.media_kind(d) != filter_kind:
		return false
	if filter_handles and not EffectSource.has_handles(d):
		return false
	if filter_user and not EffectSource.is_user_made(d):
		return false
	return true


func any_filter() -> bool:
	return not filter_tag.is_empty() or not filter_kind.is_empty() or filter_handles or filter_user


func narrowed() -> bool:
	return not search.is_empty() or any_filter()


func all_defs() -> Array[Dictionary]:
	var defs: Array[Dictionary] = EffectSource.list()
	defs.append_array(transition_defs())
	return defs


func visible_defs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in all_defs():
		if _matches(d) and passes_filters(d):
			out.append(d)
	return view_filter(out)


func view_filter(list: Array[Dictionary]) -> Array[Dictionary]:
	if impl == null or not impl.has_method("filter"):
		return list
	return impl.call("filter", list)


static func sort_key(d: Dictionary, mode: String, recents: PackedStringArray, favs: PackedStringArray) -> String:
	var id: String = String(d.get("id", ""))
	var label: String = String(d.get("label", id)).to_lower()
	var tail: String = "|" + label + "|" + id
	if mode == "name":
		return tail
	if mode == "category":
		return String(d.get("category", "Other")).to_lower() + tail
	if mode == "recent":
		var at: int = recents.find(id)
		return "%04d" % (at if at >= 0 else 9999) + tail
	if mode == "favourite":
		return ("0" if favs.has(id) else "1") + tail
	return tail


func library_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for d: Dictionary in all_defs():
		out.append(String(d.get("id", "")))
	return out


func sort_defs(list: Array[Dictionary]) -> Array[Dictionary]:
	if sort_by.is_empty():
		return list
	var out: Array[Dictionary] = list.duplicate()
	var mode: String = sort_by
	if mode == "mine":
		var order: PackedStringArray = Folders.my_order(library_ids())
		var rank: Dictionary = {}
		for i: int in order.size():
			rank[order[i]] = i
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(rank.get(String(a.get("id", "")), 999999)) < int(rank.get(String(b.get("id", "")), 999999)))
		if sort_desc:
			out.reverse()
		return out
	var recents: PackedStringArray = EffectSource.recent()
	var favs: PackedStringArray = EffectSource.favourites()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return sort_key(a, mode, recents, favs) < sort_key(b, mode, recents, favs))
	if sort_desc:
		out.reverse()
	return out


func _defs_for(ids: PackedStringArray, by_id: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in ids:
		if by_id.has(id) and _matches(by_id[id]) and passes_filters(by_id[id]):
			out.append(by_id[id])
	return out


func sections_for(pool: Array[Dictionary], by_id: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var favs: Array[Dictionary] = _defs_for(EffectSource.favourites(), by_id)
	if not favs.is_empty() or not narrowed():
		out.append({"title": "Favourites", "key": "effects.favourites", "defs": sort_defs(favs), "hint": "Star an effect to keep it here", "category": false})
	for f: Dictionary in Folders.folders():
		var inside: Array[Dictionary] = _defs_for(f["items"], by_id)
		if inside.is_empty() and narrowed():
			continue
		out.append({"title": String(f["name"]), "key": "effects.folder." + String(f["id"]), "defs": inside, "hint": "Drag effects here", "category": false, "folder": String(f["id"])})
	if sort_by == "mine":
		out.append({"title": "My order", "key": "effects.my_order", "defs": sort_defs(pool), "hint": "", "category": false})
		return out
	var recents: Array[Dictionary] = _defs_for(EffectSource.recent(), by_id)
	if not recents.is_empty():
		out.append({"title": "Recently used", "key": "effects.recent", "defs": sort_defs(recents), "hint": "", "category": false})
	var by_cat: Dictionary = {}
	for d: Dictionary in pool:
		var cat: String = String(d.get("category", "Other"))
		if not by_cat.has(cat):
			by_cat[cat] = [] as Array[Dictionary]
		(by_cat[cat] as Array[Dictionary]).append(d)
	var cats: Array = by_cat.keys()
	cats.sort()
	for cat2: String in cats:
		out.append({"title": cat2, "key": "effects." + cat2.to_lower().replace(" ", "_"), "defs": sort_defs(by_cat[cat2]), "hint": "", "category": true})
	return out


func rebuild() -> void:
	if not _alive():
		return
	_hide_card()
	_lists_dirty = false
	PmUI.keep_scroll(_list)
	PmUI.clear(_list)
	_rows.clear()
	_thumb_rows.clear()
	sections = PackedStringArray()
	var defs: Array[Dictionary] = all_defs()
	if EffectSource.list().is_empty():
		_list.add_child(PmLabel.dim("No effects are installed" if EffectSource.available() else "The effect registry is not loaded (engine/ is missing)"))
	var by_id: Dictionary = {}
	for d: Dictionary in defs:
		by_id[String(d.get("id", ""))] = d
	var pool: Array[Dictionary] = visible_defs()
	var secs: Array[Dictionary] = sections_for(pool, by_id)
	if impl != null:
		impl.call("build", _list, secs)
	else:
		_build_folds(secs)
	var shown: int = pool.size()
	var text: String = str(shown) + (" effect" if shown == 1 else " effects") + (" match" if narrowed() else "")
	if impl != null and impl.has_method("meta"):
		var mt: String = String(impl.call("meta"))
		if not mt.is_empty():
			text += " · " + mt
	var summary: String = filter_summary()
	if not summary.is_empty():
		text += " · " + summary
	_status.text = text
	PmUI.tip(_status, text)
	_sync_buttons()


func _build_folds(secs: Array[Dictionary]) -> void:
	for sec: Dictionary in secs:
		var defs: Array = sec["defs"]
		var fold: VBoxContainer = _section(String(sec["title"]), defs.size(), String(sec["key"]), true)
		var body: VBoxContainer = fold.get("body")
		var folder_id: String = String(sec.get("folder", ""))
		if not folder_id.is_empty():
			_dress_folder(fold, folder_id)
			if defs.is_empty():
				body.add_child(hint_row(String(sec.get("hint", ""))))
				continue
			for fd: Dictionary in defs:
				var frow: Control = _make_row(fd, String(fd.get("category", "Other")))
				frow.set_meta("folder_id", folder_id)
				_add_row_slot(frow, folder_id)
				body.add_child(frow)
			continue
		if defs.is_empty():
			var hint_text: String = String(sec.get("hint", ""))
			if not hint_text.is_empty():
				body.add_child(hint_row(hint_text))
			continue
		if String(sec["title"]) == "Audio" and bool(sec.get("category", false)):
			_build_audio_groups(body, defs)
			continue
		for d: Dictionary in defs:
			var row: Control = _make_row(d, String(d.get("category", "Other")))
			if sort_by == "mine":
				_add_row_slot(row, "")
			body.add_child(row)


func _dress_folder(fold: VBoxContainer, folder_id: String) -> void:
	fold.set_meta("folder_id", folder_id)
	var more: Button = quiet_icon("more", "Folder: rename, move or delete")
	more.name = "FolderMenu_" + folder_id
	more.pressed.connect(_open_folder_menu.bind(folder_id, more))
	fold.call("add_right", more)
	var header: Variant = fold.get("header")
	if header is Control:
		var slot: Control = PmSlot.make(PackedStringArray(["effect"]))
		slot.name = "FolderDrop_" + folder_id
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.set("priority", 2)
		slot.connect("dropped", _on_folder_drop.bind(folder_id))
		(header as Control).add_child(slot)


func _add_row_slot(row: Control, folder_id: String) -> void:
	var slot: Control = PmSlot.make(PackedStringArray(["effect"]))
	slot.name = "RowDrop"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.set("priority", 3)
	slot.connect("dropped", _on_row_drop.bind(String(row.get_meta("effect_id", "")), folder_id))
	row.add_child(slot)


func _on_folder_drop(payload: Dictionary, _local: Vector2, folder_id: String) -> void:
	drop_into_folder(String(payload.get("id", "")), folder_id)


func _on_row_drop(payload: Dictionary, _local: Vector2, before_id: String, folder_id: String) -> void:
	drop_before(String(payload.get("id", "")), before_id, folder_id)


func drop_into_folder(effect_id: String, folder_id: String) -> bool:
	if effect_id.is_empty() or effect_id.begins_with("transition:"):
		return false
	var ok: bool = Folders.add(folder_id, effect_id)
	if ok:
		rebuild()
	return ok


func drop_before(effect_id: String, before_id: String, folder_id: String) -> bool:
	if effect_id.is_empty() or effect_id == before_id:
		return false
	var ok: bool = false
	if not folder_id.is_empty():
		ok = Folders.add(folder_id, effect_id, before_id)
	else:
		ok = Folders.place(effect_id, before_id, library_ids())
	if ok:
		rebuild()
	return ok


func new_folder(name_: String = "") -> String:
	var id: String = Folders.create(name_)
	rebuild()
	return id


func _on_new_folder() -> void:
	_ask_name("New folder", Folders.NEW_NAME, func(n: String) -> void: new_folder(n))


func _ask_name(title: String, start: String, done: Callable) -> void:
	if _root == null or not _root.is_inside_tree():
		done.call(start)
		return
	var fields: Array[Dictionary] = [{"key": "name", "label": "Name", "type": "string", "default": start}]
	var answered: Signal = PmUI.form(_root, title, fields, "OK", "Cancel")
	answered.connect(func(r: Variant) -> void: _named(r, done))


func _named(r: Variant, done: Callable) -> void:
	if typeof(r) != TYPE_DICTIONARY or (r as Dictionary).is_empty():
		return
	var n: String = String((r as Dictionary).get("name", "")).strip_edges()
	if not n.is_empty():
		done.call(n)


func folder_menu_items(folder_id: String) -> Array:
	var list: Array[Dictionary] = Folders.folders()
	var at: int = -1
	for i: int in list.size():
		if String(list[i]["id"]) == folder_id:
			at = i
	var up: Dictionary = PmMenu.item("folder_up", "Move the folder up")
	up["disabled"] = at <= 0
	var down: Dictionary = PmMenu.item("folder_down", "Move the folder down")
	down["disabled"] = at < 0 or at >= list.size() - 1
	return [PmMenu.item("folder_rename", "Rename"), up, down, PmMenu.separator(), PmMenu.item("folder_delete", "Delete the folder, the effects stay", "", "trash")]


func _open_folder_menu(folder_id: String, anchor: Control) -> void:
	var m: Control = PmMenu.open(anchor, folder_menu_items(folder_id))
	if m != null and m.is_inside_tree():
		m.connect("picked", on_folder_menu.bind(folder_id))


func on_folder_menu(pick: String, folder_id: String) -> void:
	if pick == "folder_rename":
		var f: Dictionary = Folders.find(folder_id)
		_ask_name("Rename the folder", String(f.get("name", "")), func(n: String) -> void: _renamed(folder_id, n))
	elif pick == "folder_up":
		if Folders.move(folder_id, -1):
			rebuild()
	elif pick == "folder_down":
		if Folders.move(folder_id, 1):
			rebuild()
	elif pick == "folder_delete":
		if Folders.remove(folder_id):
			rebuild()


func _renamed(folder_id: String, n: String) -> void:
	if Folders.rename(folder_id, n):
		rebuild()


static func group_order(names: Array) -> Array:
	var out: Array = []
	for g: String in AUDIO_GROUP_ORDER:
		if names.has(g):
			out.append(g)
	var rest: Array = []
	for n: Variant in names:
		if not out.has(n) and String(n) != "Other":
			rest.append(n)
	rest.sort()
	out.append_array(rest)
	if names.has("Other"):
		out.append("Other")
	return out


func _build_audio_groups(body: VBoxContainer, items: Array) -> void:
	var groups: Dictionary = {}
	for d: Variant in items:
		var g: String = EffectSource.audio_group(d)
		if not groups.has(g):
			groups[g] = [] as Array[Dictionary]
		(groups[g] as Array[Dictionary]).append(d)
	for g2: Variant in group_order(groups.keys()):
		var list: Array = sort_defs(groups[g2])
		var sub: VBoxContainer = PmFold.make(String(g2) + "  (" + str(list.size()) + ")", "effects.audio." + String(g2).to_lower().replace(" ", "_"), not search.is_empty())
		if not search.is_empty():
			sub.set("open", true)
		sections.append("Audio/" + String(g2))
		var inner: VBoxContainer = sub.get("body")
		for d2: Variant in list:
			inner.add_child(_make_row(d2, "Audio"))
		var pad: MarginContainer = MarginContainer.new()
		pad.add_theme_constant_override("margin_left", Tk.px(10.0))
		pad.add_child(sub)
		body.add_child(pad)


func _section(title: String, count: int, key: String, open_default: bool) -> VBoxContainer:
	var fold: VBoxContainer = PmFold.make(title + "  (" + str(count) + ")", key, open_default)
	if narrowed():
		fold.set("open", true)
	sections.append(title)
	_list.add_child(fold)
	return fold


func section_fold(title: String, count: int, key: String) -> VBoxContainer:
	return _section(title, count, key, true)


static func icon_for(cat: String) -> String:
	return String(CATEGORY_ICONS.get(cat, FALLBACK_ICON))


func _gap(w: float) -> Control:
	var sp: Control = Control.new()
	sp.custom_minimum_size = Vector2(w, 0.0)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp


func row_tip(d: Dictionary) -> String:
	var blurb: String = String(d.get("blurb", ""))
	return (blurb + " " if not blurb.is_empty() else "") + "Double click to add to the selected clips. Drag onto a clip to put it on that clip only, or on every clip you picked when it is one of them. Right click to star it"


func _make_row(d: Dictionary, cat: String) -> Control:
	var id: String = String(d.get("id", ""))
	var row: HBoxContainer = PmUI.hbox()
	var row_h: float = COMPACT_ROW_H if view == "compact" else ROW_H
	row.custom_minimum_size = Vector2(0.0, float(Tk.px(row_h)))
	row.set_meta("effect_id", id)
	row.set_meta("row_kind", "row")
	var icon: Control = _Icon.new()
	icon.set("icon", icon_for(cat))
	icon.custom_minimum_size = Vector2(float(Tk.px(ICON_W * (0.6 if view == "compact" else 1.0))), float(Tk.px(row_h)) - 4.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var b: Button = PmButton.make(String(d.get("label", id)))
	b.set("quiet", true)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta("effect_id", id)
	b.gui_input.connect(_on_row_input.bind(id, b))
	b.mouse_entered.connect(_on_row_hover.bind(id, true))
	b.mouse_exited.connect(_on_row_hover.bind(id, false))
	PmUI.tip(b, row_tip(d))
	row.add_child(b)
	if not id.begins_with("transition:"):
		var star: Control = _Star.new()
		star.set("on", EffectSource.is_favourite(id))
		star.custom_minimum_size = Vector2(float(Tk.px(STAR_W)), float(Tk.px(row_h)) - 4.0)
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		star.connect("toggled", _on_star.bind(id))
		PmUI.tip(star, "Keep it in Favourites")
		row.add_child(star)
	_rows.append(row)
	return row


func make_tile(d: Dictionary, side: float) -> Control:
	var id: String = String(d.get("id", ""))
	var cat: String = String(d.get("category", "Other"))
	var tile: VBoxContainer = PmUI.vbox(Tk.px(2.0))
	tile.custom_minimum_size = Vector2(side, 0.0)
	tile.set_meta("effect_id", id)
	tile.set_meta("row_kind", "tile")
	var thumb: Control = _Thumb.new()
	thumb.set("icon", icon_for(cat))
	thumb.set("effect_id", id)
	thumb.custom_minimum_size = Vector2(side, round(side * 0.5625))
	thumb.gui_input.connect(_on_row_input.bind(id, thumb))
	thumb.mouse_entered.connect(_on_row_hover.bind(id, true))
	thumb.mouse_exited.connect(_on_row_hover.bind(id, false))
	PmUI.tip(thumb, row_tip(d))
	tile.add_child(thumb)
	if can_preview(id):
		thumb.set("texture", _thumbs.get(id, null))
		_thumb_rows.append(thumb)
	var foot: HBoxContainer = PmUI.hbox(0)
	var name_label: Label = PmLabel.trim(String(d.get("label", id)))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(name_label)
	if not id.begins_with("transition:"):
		var star: Control = _Star.new()
		star.set("on", EffectSource.is_favourite(id))
		star.custom_minimum_size = Vector2(float(Tk.px(STAR_W)), float(Tk.px(16.0)))
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		star.connect("toggled", _on_star.bind(id))
		PmUI.tip(star, "Keep it in Favourites")
		foot.add_child(star)
	tile.add_child(foot)
	_rows.append(tile)
	return tile


func hint_row(text: String) -> Control:
	var hint: HBoxContainer = PmUI.hbox(0)
	hint.add_child(_gap(float(Tk.px(ICON_W))))
	hint.add_child(PmLabel.dim(text))
	hint.set_meta("row_kind", "hint")
	return hint


func _on_view_pressed(v: String) -> void:
	set_view(v)


func set_view(v: String) -> void:
	if not (v in VIEWS):
		return
	var changed: bool = v != view
	view = v
	Prefs.set_value(PREF_VIEW, v)
	if changed:
		_install_view()
	_sync_buttons()
	rebuild()


func _install_view() -> void:
	if impl != null:
		if impl.has_method("deactivate"):
			impl.call("deactivate")
		impl = null
	if VIEW_SCRIPTS.has(view):
		var script: Variant = load(String(VIEW_SCRIPTS[view]))
		if script is GDScript and (script as GDScript).can_instantiate():
			impl = (script as GDScript).new()
			impl.call("setup", self, _list)
	rebuild_view_bar()


func _add_view_bar(col: VBoxContainer) -> void:
	var wrap: VBoxContainer = PmUI.vbox(0)
	wrap.visible = false
	_view_bar_holder = PmUI.panel("bg_panel")
	var sb: StyleBoxFlat = _view_bar_holder.get_theme_stylebox("panel")
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	_view_bar = PmToolbar.make()
	_view_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_bar_holder.add_child(_view_bar)
	wrap.add_child(_view_bar_holder)
	col.add_child(wrap)


func rebuild_view_bar() -> void:
	if _view_bar == null or not is_instance_valid(_view_bar):
		return
	_view_bar.call("clear")
	var show: bool = impl != null and impl.has_method("build_bar")
	if show:
		impl.call("build_bar", _view_bar)
	(_view_bar_holder.get_parent() as Control).visible = show


func view_menu_items() -> Array:
	var items: Array = []
	for v: String in VIEWS:
		items.append(PmMenu.check_item("view:" + v, String(VIEW_LABELS[v]), v == view))
	return items


func sort_menu_items() -> Array:
	var items: Array = []
	for s: String in SORTS:
		items.append(PmMenu.check_item("sort:" + s, String(SORT_LABELS[s]), s == sort_by))
	items.append(PmMenu.separator())
	items.append(PmMenu.check_item("sort_desc", "Reversed", sort_desc))
	return items


func filter_menu_items() -> Array:
	var items: Array = [PmMenu.check_item("tag:", "Any tag", filter_tag.is_empty())]
	for t: String in EffectSource.all_tags():
		items.append(PmMenu.check_item("tag:" + t, t.capitalize(), filter_tag == t))
	items.append(PmMenu.separator())
	for k: String in KINDS:
		items.append(PmMenu.check_item("kind:" + k, String(KIND_LABELS[k]), filter_kind == k))
	items.append(PmMenu.separator())
	items.append(PmMenu.check_item("handles", "Has handles on the monitor", filter_handles))
	items.append(PmMenu.check_item("user", "Ones you made", filter_user))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("clear", "Clear every filter"))
	return items


func _on_sort_button() -> void:
	var m: Control = PmMenu.open(_sort_button, sort_menu_items())
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_panel_menu)


func _on_filter_button() -> void:
	var m: Control = PmMenu.open(_filter_button, filter_menu_items())
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_panel_menu)


func _on_panel_menu(id: String) -> void:
	if id.begins_with("view:"):
		set_view(id.substr(5))
	elif id.begins_with("sort:"):
		set_sort(id.substr(5), sort_desc)
	elif id == "sort_desc":
		set_sort(sort_by, not sort_desc)
	elif id.begins_with("tag:"):
		set_filter("tag", id.substr(4))
	elif id.begins_with("kind:"):
		set_filter("kind", id.substr(5))
	elif id == "handles":
		set_filter("handles", not filter_handles)
	elif id == "user":
		set_filter("user", not filter_user)
	elif id == "clear":
		clear_filters()


func set_sort(mode: String, desc: bool) -> void:
	sort_by = mode if mode in SORTS else ""
	sort_desc = desc and not sort_by.is_empty()
	Prefs.set_value(PREF_SORT, to_pref(sort_by, PREF_SORTS))
	Prefs.set_value(PREF_SORT_DESC, sort_desc)
	rebuild()


func set_filter(which: String, value: Variant) -> void:
	if which == "tag":
		filter_tag = str(value).strip_edges().to_lower()
		Prefs.set_value(PREF_TAG, filter_tag)
	elif which == "kind":
		filter_kind = str(value) if str(value) in KINDS else ""
		Prefs.set_value(PREF_KIND, to_pref(filter_kind, PREF_KINDS))
	elif which == "handles":
		filter_handles = bool(value)
		Prefs.set_value(PREF_HANDLES, filter_handles)
	elif which == "user":
		filter_user = bool(value)
		Prefs.set_value(PREF_USER, filter_user)
	rebuild()


func clear_filters() -> void:
	filter_tag = ""
	filter_kind = ""
	filter_handles = false
	filter_user = false
	Prefs.set_value(PREF_TAG, "")
	Prefs.set_value(PREF_KIND, PREF_KINDS[0])
	Prefs.set_value(PREF_HANDLES, false)
	Prefs.set_value(PREF_USER, false)
	rebuild()


func filter_summary() -> String:
	var parts: PackedStringArray = PackedStringArray()
	if not filter_tag.is_empty():
		parts.append(filter_tag.capitalize())
	if not filter_kind.is_empty():
		parts.append(String(KIND_LABELS[filter_kind]))
	if filter_handles:
		parts.append("has handles")
	if filter_user:
		parts.append("yours")
	return ", ".join(parts)


func _sync_buttons() -> void:
	if not _alive():
		return
	for k: String in _view_buttons.keys():
		(_view_buttons[k] as Button).button_pressed = k == view
	if _sort_button != null and is_instance_valid(_sort_button):
		PmUI.tip(_sort_button, "Sort: " + String(SORT_LABELS.get(sort_by, "Library order")) + (", reversed" if sort_desc else ""))
	if _filter_button != null and is_instance_valid(_filter_button):
		var summary: String = filter_summary()
		PmUI.tip(_filter_button, "Showing " + (summary if not summary.is_empty() else "everything") + ", click to narrow it down")


func _on_star(on: bool, id: String) -> void:
	set_favourite(id, on)


func set_favourite(id: String, on: bool) -> void:
	EffectSource.set_favourite(id, on)
	_lists_dirty = true


func _on_row_input(event: InputEvent, id: String, anchor: Control) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			anchor.accept_event()
			_open_row_menu(id, anchor)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_hide_card()
				if mb.double_click:
					add_to_selection(id)
					return
				_press_pos = mb.position
				_press_id = id
				load("res://modules/core_panels/effect_handles_ui.gd").call("pick_from_browser", id)
			else:
				_press_id = ""
		return
	if event is InputEventMouseMotion and _press_id == id:
		if ((event as InputEventMouseMotion).position - _press_pos).length() >= float(Tk.px(4.0)):
			_press_id = ""
			begin_drag(id)


func row_menu_items(id: String) -> Array:
	var items: Array = [PmMenu.item("add", "Add to the selected clips")]
	if not id.begins_with("transition:"):
		items.append(PmMenu.item("fav_off" if EffectSource.is_favourite(id) else "fav_on", "Remove from Favourites" if EffectSource.is_favourite(id) else "Add to Favourites"))
		items.append(PmMenu.sub_item("folders", "Add to a folder", folder_pick_items(id)))
		items.append_array(load("res://modules/core_panels/shader_import.gd").call("row_menu_items", id))
	items.append(PmMenu.separator())
	items.append(PmMenu.sub_item("view", "View", view_menu_items()))
	items.append(PmMenu.sub_item("sort", "Sort", sort_menu_items()))
	items.append(PmMenu.sub_item("show", "Show", filter_menu_items()))
	return items


func folder_pick_items(id: String) -> Array:
	var out: Array = []
	var inside: PackedStringArray = Folders.folders_with(id)
	for f: Dictionary in Folders.folders():
		out.append(PmMenu.check_item("folder_add:" + String(f["id"]), String(f["name"]), inside.has(String(f["id"]))))
	if not out.is_empty():
		out.append(PmMenu.separator())
	out.append(PmMenu.item("folder_new_with", "New folder with this effect"))
	return out


func _open_row_menu(id: String, anchor: Control) -> void:
	var items: Array = row_menu_items(id)
	var host: Node = anchor.get_parent()
	var folder_id: String = String(host.get_meta("folder_id", "")) if host != null else ""
	if not folder_id.is_empty():
		items.insert(1, PmMenu.item("folder_take_out:" + folder_id, "Remove from this folder"))
	var m: Control = PmMenu.open(anchor, items, anchor.get_global_mouse_position())
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_row_menu.bind(id))


func _on_row_menu(pick: String, id: String) -> void:
	if pick.begins_with("view:") or pick.begins_with("sort:") or pick.begins_with("tag:") or pick.begins_with("kind:") or pick == "sort_desc" or pick == "handles" or pick == "user" or pick == "clear":
		_on_panel_menu(pick)
		return
	if bool(load("res://modules/core_panels/shader_import.gd").call("row_menu_picked", self, pick, id)):
		return
	if pick.begins_with("folder_add:"):
		var fid: String = pick.substr(11)
		if Folders.folders_with(id).has(fid):
			Folders.take_out(fid, id)
		else:
			Folders.add(fid, id)
		rebuild()
		return
	if pick.begins_with("folder_take_out:"):
		Folders.take_out(pick.substr(16), id)
		rebuild()
		return
	if pick == "folder_new_with":
		_ask_name("New folder", Folders.NEW_NAME, func(n: String) -> void: _new_folder_with(n, id))
		return
	if pick == "add":
		add_to_selection(id)
	elif pick == "fav_on":
		set_favourite(id, true)
	elif pick == "fav_off":
		set_favourite(id, false)


func _new_folder_with(n: String, id: String) -> void:
	var fid: String = Folders.create(n)
	Folders.add(fid, id)
	rebuild()


func add_to_selection(id: String) -> void:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return
	var def: Dictionary = def_for(id)
	var ids: PackedStringArray = Verbs.selection(s)
	if ids.is_empty():
		Events.toast("Select a clip first")
		return
	if def.has("transition"):
		var canvas: Control = _timeline_canvas()
		var kind: String = String(def["transition"])
		var done: int = 0
		for cid: String in ids:
			var tr: Track = s.track_of(cid)
			var c: Clip = s.clip_by_id(cid)
			if tr == null or c == null or tr.kind != String(def.get("track", tr.kind)):
				continue
			if canvas != null and bool(canvas.call("apply_transition_at", kind, tr.id, c.start, c)):
				done += 1
		if done == 0:
			Events.toast("Select " + String(def.get("track", "video")) + " clips for this transition")
		return
	if Verbs.drop_effect(d, s, ids, def) == 0:
		if bool(def.get("audio", false)):
			Events.toast("Select a clip that has sound, or one linked to its audio")
		else:
			Events.toast("Select a clip first")
		return
	note_used(id)


func note_used(id: String) -> void:
	if id.begins_with("transition:"):
		return
	EffectSource.note_used(id)
	_lists_dirty = true


func _timeline_canvas() -> Control:
	var tl: Object = bus().call("panel", "timeline")
	if tl == null:
		return null
	return tl.get("canvas")


func begin_drag(id: String) -> void:
	_hide_card()
	var layer: CanvasLayer = PmDragLayer.find(_root)
	if layer == null:
		return
	var def: Dictionary = def_for(id)
	var ghost: Label = PmLabel.tight(String(def.get("label", id)), "text_bright")
	var card: PanelContainer = PmUI.panel("bg_panel_high")
	card.add_child(ghost)
	layer.call("begin", {"kind": "transition" if def.has("transition") else "effect", "id": String(def["transition"]) if def.has("transition") else id}, card, Vector2(10.0, 10.0))
	if not def.has("transition"):
		EffectSource.note_used(id)
		_lists_dirty = true


func _on_row_hover(id: String, on: bool) -> void:
	if on:
		if _hover_id != id:
			_hide_card()
		_hover_id = id
		_hover_for = 0.0
	elif _hover_id == id:
		_hover_id = ""
		_hide_card()


func _tick_hover(dt: float) -> void:
	if _hover_id.is_empty():
		return
	_hover_for += dt
	if _card != null and _card.visible:
		_place_card()
		return
	if _hover_for >= PREVIEW_DELAY and _press_id.is_empty():
		if not show_preview(_hover_id):
			_hover_id = ""


func can_preview(id: String) -> bool:
	var def: Dictionary = def_for(id)
	return not def.is_empty() and not def.has("transition") and not bool(def.get("audio", false)) and EffectPreview.available()


func _current_frame() -> Image:
	var comp: Node = Session.compositor
	if comp == null or not comp.has_method("texture"):
		return null
	var tex: Variant = comp.call("texture")
	if not (tex is Texture2D):
		return null
	var img: Image = (tex as Texture2D).get_image()
	if img != null and comp.has_method("crop_to_frame"):
		return comp.call("crop_to_frame", img)
	return img


func _frame_stamp() -> String:
	var d: Project = doc()
	return str(playhead()) + "|" + (str(d.serial) if d != null else "-") + "|" + str(Session.compositor.get_instance_id() if Session.compositor != null else 0)


func _ensure_preview() -> Node:
	if _preview != null and is_instance_valid(_preview):
		return _preview
	_preview = EffectPreview.new()
	_root.get_tree().root.add_child(_preview)
	_frame_key = ""
	return _preview


func show_preview(id: String) -> bool:
	if not _alive() or not can_preview(id):
		return false
	var p: Node = _ensure_preview()
	var key: String = _frame_stamp()
	if key != _frame_key:
		if not bool(p.call("set_frame", _current_frame())):
			return false
		_frame_key = key
	if not bool(p.call("show_effect", id)):
		return false
	_ensure_card()
	var px: Vector2i = p.call("size_px")
	_card_tex.texture = p.call("texture")
	_card_tex.custom_minimum_size = Vector2(px)
	_card_label.text = String(def_for(id).get("label", id)) + " on the current frame"
	_card.reset_size()
	_card.visible = true
	_place_card()
	return true


func _ensure_card() -> void:
	if _card != null and is_instance_valid(_card):
		return
	_card = PmUI.panel("bg_panel_alt")
	_card.name = "EffectPreviewCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = _card.get_theme_stylebox("panel")
	sb.border_color = Tk.c["border_soft"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(Tk.px(Tk.sz("radius_menu")))
	sb.content_margin_left = float(Tk.px(6.0))
	sb.content_margin_right = float(Tk.px(6.0))
	sb.content_margin_top = float(Tk.px(6.0))
	sb.content_margin_bottom = float(Tk.px(4.0))
	var col: VBoxContainer = PmUI.vbox(Tk.px(4.0))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)
	_card_tex = TextureRect.new()
	_card_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_card_tex)
	_card_label = PmLabel.dim("")
	_card_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_card_label)
	_card.visible = false
	var overlay: Node = PmUI.overlay_for(_root)
	if overlay != null:
		overlay.add_child(_card)


func _place_card() -> void:
	if _card == null or not _card.is_inside_tree():
		return
	var vp: Rect2 = _card.get_viewport_rect()
	var at: Vector2 = _card.get_global_mouse_position() + Vector2(CARD_GAP, CARD_GAP)
	var sz: Vector2 = _card.get_combined_minimum_size()
	if at.x + sz.x > vp.end.x - 4.0:
		at.x = _card.get_global_mouse_position().x - CARD_GAP - sz.x
	if at.y + sz.y > vp.end.y - 4.0:
		at.y = vp.end.y - 4.0 - sz.y
	_card.global_position = Vector2(maxf(at.x, 4.0), maxf(at.y, 4.0))


func card_visible() -> bool:
	return _card != null and is_instance_valid(_card) and _card.visible


func _hide_card() -> void:
	if _card != null and is_instance_valid(_card):
		_card.visible = false
		if _card_tex != null:
			_card_tex.texture = null
	if _preview != null and is_instance_valid(_preview):
		PmUI.free_node(_preview)
	_preview = null
	_frame_key = ""


func _on_compositor() -> void:
	_hide_card()
	forget_thumbs()
	rebuild()


func save_state() -> Dictionary:
	return {"search": search, "view": view, "sort": sort_by, "sort_desc": sort_desc, "tag": filter_tag, "kind": filter_kind, "handles": filter_handles, "user": filter_user}


func restore_state(d: Dictionary) -> void:
	search = String(d.get("search", ""))
	var v: String = String(d.get("view", view))
	if v in VIEWS:
		view = v
		Prefs.set_value(PREF_VIEW, v)
	var s: String = String(d.get("sort", sort_by))
	if s in SORTS:
		sort_by = s
	sort_desc = bool(d.get("sort_desc", sort_desc)) and not sort_by.is_empty()
	filter_tag = String(d.get("tag", filter_tag))
	var k: String = String(d.get("kind", filter_kind))
	filter_kind = k if k in KINDS else ""
	filter_handles = bool(d.get("handles", filter_handles))
	filter_user = bool(d.get("user", filter_user))
	if _alive():
		_search.text = search
		_install_view()
		rebuild()


class _Icon:
	extends Control

	const IconsKit := preload("res://ui/kit/icons.gd")

	var icon: String = "fx"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_field"], true)
		var side: float = minf(size.x, size.y) * 0.7
		IconsKit.draw(self, icon, Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side)), Tk.c["text_dim"])


class _Thumb:
	extends Control

	const IconsKit := preload("res://ui/kit/icons.gd")

	var icon: String = "fx"
	var effect_id: String = ""
	var texture: Texture2D = null:
		set(v):
			texture = v
			queue_redraw()
	var _hover: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_on_thumb_hover.bind(true))
		mouse_exited.connect(_on_thumb_hover.bind(false))

	func _on_thumb_hover(inside: bool) -> void:
		_hover = inside
		queue_redraw()

	func _draw() -> void:
		var box: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(box, Tk.c["bg_field"], true)
		if texture != null:
			var ts: Vector2 = texture.get_size()
			if ts.x > 0.0 and ts.y > 0.0:
				var k: float = minf(size.x / ts.x, size.y / ts.y)
				var at: Vector2 = ((size - ts * k) * 0.5).round()
				draw_texture_rect(texture, Rect2(at, (ts * k).round()), false)
		else:
			var side: float = minf(size.x, size.y) * 0.42
			IconsKit.draw(self, icon, Rect2(((size - Vector2(side, side)) * 0.5).round(), Vector2(side, side)), Tk.c["text_dim"])
		draw_rect(box, Tk.c["text_dim"] if _hover else Tk.c["border_soft"], false, 1.0)


class _Star:
	extends Control

	signal toggled(on: bool)

	var on: bool = false
	var _hover: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		gui_input.connect(_on_input)
		mouse_entered.connect(_on_hover.bind(true))
		mouse_exited.connect(_on_hover.bind(false))

	func _on_hover(inside: bool) -> void:
		_hover = inside
		queue_redraw()

	func _on_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				on = not on
				queue_redraw()
				accept_event()
				toggled.emit(on)

	static func points(centre: Vector2, outer: float) -> PackedVector2Array:
		var pts: PackedVector2Array = PackedVector2Array()
		var inner: float = outer * 0.45
		for i: int in 10:
			var a: float = -PI * 0.5 + PI * float(i) / 5.0
			var r: float = outer if i % 2 == 0 else inner
			pts.append(centre + Vector2(cos(a), sin(a)) * r)
		return pts

	func _draw() -> void:
		var r: float = minf(size.x, size.y) * 0.34
		var pts: PackedVector2Array = points(size * 0.5, r)
		var col: Color = Tk.c["text_bright"] if on or _hover else Tk.c["text_faint"]
		if on:
			draw_colored_polygon(pts, col)
		var ring: PackedVector2Array = pts.duplicate()
		ring.append(pts[0])
		draw_polyline(ring, col, 1.2, true)


static func from_pref(v: String, ids: PackedStringArray) -> String:
	if v.is_empty() or v == ids[0]:
		return ""
	return v


static func to_pref(v: String, ids: PackedStringArray) -> String:
	return ids[0] if v.is_empty() else v


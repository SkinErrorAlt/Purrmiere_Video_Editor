extends "res://host/interfaces/i_panel.gd"

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmIcon := preload("res://ui/kit/pm_icon.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmTabs := preload("res://ui/kit/pm_tabs.gd")
const PmFold := preload("res://ui/kit/pm_fold.gd")
const PmSplit := preload("res://ui/kit/pm_split.gd")
const PmSlot := preload("res://ui/kit/pm_slot.gd")
const PmToolbar := preload("res://ui/kit/pm_toolbar.gd")
const PmWrapRow := preload("res://ui/kit/pm_wrap_row.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const PmDragLayer := preload("res://ui/kit/pm_drag_layer.gd")
const Icons := preload("res://ui/kit/icons.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Marker := preload("res://doc/marker.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const Timecode := preload("res://doc/timecode.gd")
const Presets := preload("res://doc/presets.gd")
const Io := preload("res://doc/io.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const SCOPES: Dictionary = {
	"timeline": "timeline",
	"program": "program",
	"source": "source",
	"bin": "bin",
	"keyframes": "keys",
	"effect_controls": "controls",
}

var _id: String = ""
var _title: String = ""
var _root: Control = null
var _focused: bool = false
var _bound_doc: Project = null
var _built: bool = false


func setup(id_: String, title_: String) -> void:
	_id = id_
	_title = title_ if not title_.is_empty() else id_.capitalize()
	var bus: RefCounted = Bus.instance()
	bus.panels[_id] = self


func id() -> String:
	return _id


func title() -> String:
	return _title


func scope() -> String:
	return String(SCOPES.get(_id, "global"))


func bus() -> RefCounted:
	return Bus.instance()


func doc() -> Project:
	return Session.doc


func seq() -> Sequence:
	return Session.seq()


func has_doc() -> bool:
	return Session.doc != null


func playhead() -> float:
	return Session.playhead()


func fps() -> float:
	var s: Sequence = seq()
	if s == null or s.fps <= 0.0:
		return 30.0
	return s.fps


func tc(t: float) -> String:
	var s: Sequence = seq()
	return Timecode.format(t, fps(), s != null and s.drop_frame)


func build(parent: Control) -> Control:
	_root = Control.new()
	_root.name = "Panel_" + _id
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: ColorRect = PmUI.fill("bg_panel")
	fill.name = "Fill"
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(fill)
	parent.add_child(_root)
	_bind_session()
	_build(_root)
	_built = true
	_bind_doc()
	return _root


func _build(_root_: Control) -> void:
	pass


func root() -> Control:
	return _root


func _bind_session() -> void:
	if not Session.project_changed.is_connected(_on_project_changed_base):
		Session.project_changed.connect(_on_project_changed_base)
	if not Session.sequence_changed.is_connected(_on_sequence_changed_base):
		Session.sequence_changed.connect(_on_sequence_changed_base)
	if not Session.playhead_changed.is_connected(_on_playhead_base):
		Session.playhead_changed.connect(_on_playhead_base)
	if not Session.playing_changed.is_connected(_on_playing_base):
		Session.playing_changed.connect(_on_playing_base)
	if not Session.tool_changed.is_connected(_on_tool_base):
		Session.tool_changed.connect(_on_tool_base)
	if not Session.compositor_changed.is_connected(_on_compositor_base):
		Session.compositor_changed.connect(_on_compositor_base)
	if not Prefs.changed.is_connected(_on_pref_changed_base):
		Prefs.changed.connect(_on_pref_changed_base)


func live_prefs() -> PackedStringArray:
	return PackedStringArray()


func watches_pref(key: String) -> bool:
	for want: String in live_prefs():
		if key == want or (want.ends_with(".") and key.begins_with(want)):
			return true
	return false


func _on_pref_changed_base(key: String) -> void:
	if not _alive():
		return
	_on_pref_changed(key)
	if watches_pref(key):
		redraw_for_pref()


func redraw_for_pref() -> void:
	if has_method("refresh"):
		call("refresh")
	elif has_method("rebuild"):
		call("rebuild")


func _on_pref_changed(_key: String) -> void:
	pass


func _bind_doc() -> void:
	var d: Project = doc()
	if _bound_doc == d:
		return
	if _bound_doc != null:
		if _bound_doc.changed.is_connected(_on_doc_changed_base):
			_bound_doc.changed.disconnect(_on_doc_changed_base)
		if _bound_doc.history_changed.is_connected(_on_history_base):
			_bound_doc.history_changed.disconnect(_on_history_base)
	_bound_doc = d
	if d != null:
		d.changed.connect(_on_doc_changed_base)
		d.history_changed.connect(_on_history_base)


func _alive() -> bool:
	return _root != null and is_instance_valid(_root)


func _on_project_changed_base() -> void:
	_bind_doc()
	if _alive():
		_on_project_changed()


func _on_sequence_changed_base(seq_id: String) -> void:
	if _alive():
		_on_sequence_changed(seq_id)


func _on_playhead_base(t: float) -> void:
	if _alive():
		_on_playhead(t)


func _on_playing_base(on: bool) -> void:
	if _alive():
		_on_playing(on)


func _on_tool_base(tool_id: String) -> void:
	if _alive():
		_on_tool(tool_id)


func _on_compositor_base() -> void:
	if _alive():
		_on_compositor()


func _on_doc_changed_base(kind: String) -> void:
	if _alive():
		_on_doc_changed(kind)


func _on_history_base() -> void:
	if _alive():
		_on_history()


func _on_project_changed() -> void:
	pass


func _on_sequence_changed(_seq_id: String) -> void:
	pass


func _on_playhead(_t: float) -> void:
	pass


func _on_playing(_on: bool) -> void:
	pass


func _on_tool(_tool_id: String) -> void:
	pass


func _on_compositor() -> void:
	pass


func _on_doc_changed(_kind: String) -> void:
	pass


func _on_history() -> void:
	pass


func handle_key(_e: InputEventKey) -> bool:
	return false


func save_state() -> Dictionary:
	return {}


func restore_state(_d: Dictionary) -> void:
	pass


func on_focus(has: bool) -> void:
	_focused = has
	if has:
		bus().set_focused(_id)


func is_focused() -> bool:
	return _focused


static func key_is(e: InputEventKey, code: Key, ctrl: bool = false, shift: bool = false, alt: bool = false) -> bool:
	if e.keycode != code:
		return false
	return (e.ctrl_pressed or e.meta_pressed) == ctrl and e.shift_pressed == shift and e.alt_pressed == alt


static func kind_icon(kind: String) -> String:
	if kind == "video":
		return "film"
	if kind == "audio":
		return "audio"
	if kind == "image":
		return "image"
	if kind == "sequence":
		return "seq"
	if kind == "title":
		return "type"
	if kind == "adjust":
		return "fx"
	if kind == "generator":
		return "combo"
	return "grid"


static func header_row(parent: Control) -> HBoxContainer:
	var bar: PanelContainer = PmUI.panel("bg_panel_alt")
	var sb: StyleBoxFlat = bar.get_theme_stylebox("panel")
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	var row: HBoxContainer = PmUI.hbox()
	bar.add_child(row)
	parent.add_child(bar)
	return row


static func quiet_icon(icon: String, tip: String, keys: String = "") -> Button:
	var b: Button = PmButton.make("", icon)
	b.set("quiet", true)
	if not tip.is_empty():
		PmUI.tip(b, tip, keys)
	return b


static func toggle_icon(icon: String, tip: String, on: bool, keys: String = "") -> Button:
	var b: Button = PmButton.make("", icon, true)
	b.set("quiet", true)
	b.button_pressed = on
	if not tip.is_empty():
		PmUI.tip(b, tip, keys)
	return b


static func clear_toolbar(tb: Container) -> void:
	for c: Control in (tb.call("items") as Array):
		tb.remove_child(c)
		c.queue_free()


static func vscroll_area(parent: Control) -> ScrollContainer:
	var sc: ScrollContainer = load("res://ui/kit/pm_scroll_keep.gd").new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sc)
	return sc


static func column(parent: Control) -> VBoxContainer:
	var col: VBoxContainer = PmUI.vbox(0)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(col)
	return col


static func find_media(d: Project, media_id: String) -> MediaItem:
	if d == null:
		return null
	return d.media_by_id(media_id)


const MEDIA_LOADER_PATH := "res://modules/core_panels/media_loader.gd"


static func media_handle(item: MediaItem) -> int:
	if item == null:
		return -1
	var h: Variant = Session.media_handles.get(item.id, -1)
	if typeof(h) == TYPE_INT and int(h) >= 0:
		return int(h)
	if item.handle < 0 and item.kind != "sequence":
		var loader: GDScript = load(MEDIA_LOADER_PATH)
		if loader != null and bool(loader.call("is_deferred", item.id)):
			return int(loader.call("claim", item))
	return item.handle

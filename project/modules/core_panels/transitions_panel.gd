extends "res://modules/core_panels/panel_base.gd"

const ReworkRequest := preload("res://modules/core_panels/rework_request.gd")
const TransitionRegistry := preload("res://engine/transition_registry.gd")
const Tiles := preload("res://modules/core_panels/transition_tiles.gd")
const Ops := preload("res://modules/core_panels/transition_ops.gd")
const Picker := preload("res://modules/core_panels/transition_picker.gd")
const FOLD_PREFIX := "transitions."
const DRAG_MIN := 4.0

var search: String = ""
var built_groups: PackedStringArray = PackedStringArray()
var tiles: Dictionary = {}
var _reg: RefCounted = null
var _search: LineEdit = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _status: Label = null
var _press_id: String = ""
var _press_pos: Vector2 = Vector2.ZERO
var _dirty: bool = false
var _current: String = ""
static var plant_wrong_payload: bool = false


func _build(root_: Control) -> void:
	_reg = TransitionRegistry.shared()
	_reg.call("ensure_prefs")
	if not _reg.is_connected("changed", _on_registry_changed):
		_reg.connect("changed", _on_registry_changed)
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	_search = PmUI.line_edit("Search transitions")
	_search.name = "TransitionSearch"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_on_search)
	head.add_child(_search)
	var folder: Button = quiet_icon("folder", "Open your own transitions folder. A folder with a transition.json and a transition.gdshader in there becomes a transition, with no restart")
	folder.name = "OpenFolder"
	folder.pressed.connect(_on_open_folder)
	head.add_child(folder)
	var again: Button = quiet_icon("loop", "Load the transitions again")
	again.name = "Reload"
	again.pressed.connect(_on_reload)
	head.add_child(again)
	_scroll = vscroll_area(col)
	_list = PmUI.vbox(0)
	_list.name = "TransitionList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	var foot: HBoxContainer = header_row(col)
	_status = PmLabel.trim("", "text_dim")
	_status.name = "TransitionStatus"
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_status)
	rebuild()


func sections() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mine: Array[Dictionary] = []
	for p: Dictionary in Ops.presets():
		var pd: Dictionary = Ops.preset_def(p)
		if TransitionRegistry.matches(pd, search):
			mine.append(pd)
	if not mine.is_empty():
		out.append({"title": Ops.PRESETS_GROUP, "defs": mine})
	out.append_array(Picker.sections(search))
	return out


func preset_of(id: String) -> String:
	return id.substr(Ops.PRESET_PREFIX.length()) if id.begins_with(Ops.PRESET_PREFIX) else ""


func rebuild() -> void:
	if not _alive():
		return
	_dirty = false
	var y: int = _scroll.scroll_vertical
	PmUI.clear(_list)
	tiles = {}
	built_groups = PackedStringArray()
	_current = Ops.selected_kind(seq())
	var default_id: String = String(_reg.call("default_kind"))
	var count: int = 0
	var secs: Array[Dictionary] = sections()
	for sec: Dictionary in secs:
		var title: String = String(sec["title"])
		var defs: Array = sec["defs"]
		var fold: VBoxContainer = PmFold.make(title + "  (" + str(defs.size()) + ")", FOLD_PREFIX + title.to_lower().replace(" ", "_"), title != TransitionRegistry.CLASSIC_GROUP)
		fold.name = "Group_" + title.replace(" ", "_")
		if not search.is_empty():
			fold.set("open", true)
		_list.add_child(fold)
		built_groups.append(title)
		var body: VBoxContainer = fold.get("body")
		var flow: HFlowContainer = PmUI.flow(Tk.px(6.0), Tk.px(8.0))
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for d: Variant in defs:
			var def: Dictionary = d
			var id: String = String(def["id"])
			var tile: Control = Tiles.make_tile(def, id == _current, id == default_id)
			var thumb: Control = Tiles.thumb_of(tile)
			thumb.gui_input.connect(_on_tile_input.bind(id, thumb))
			flow.add_child(tile)
			tiles[id] = tile
			count += 1
		var pad: MarginContainer = MarginContainer.new()
		pad.add_theme_constant_override("margin_left", Tk.px(6.0))
		pad.add_theme_constant_override("margin_right", Tk.px(6.0))
		pad.add_theme_constant_override("margin_bottom", Tk.px(6.0))
		pad.add_child(flow)
		body.add_child(pad)
	if count == 0:
		_list.add_child(PmUI.empty_state("No transition matches", "Try another word, for example cube, wipe, zoom or keynote"))
	_status.text = status_text(count)
	if y > 0:
		PmUI.restore_scroll(_scroll, y)


func status_text(count: int) -> String:
	var lead: String = str(count) + (" transition" if count == 1 else " transitions")
	return lead + ". Default: " + String(_reg.call("label_of", String(_reg.call("default_kind")))) + ". Drag one onto a cut, double click for the selected clips"


func _on_search(text: String) -> void:
	search = text.strip_edges()
	rebuild()


func _on_open_folder() -> void:
	var root_path: String = ProjectSettings.globalize_path(TransitionRegistry.user_root())
	DirAccess.make_dir_recursive_absolute(root_path)
	OS.shell_open(root_path)
	Events.notice("Your transitions folder", "Copy a folder from the library, change its transition.json and transition.gdshader, and Purrmiere picks it up within a couple of seconds.")


func _on_reload() -> void:
	_reg.call("reload")
	Events.toast("Transitions loaded again, " + str((_reg.call("ids") as PackedStringArray).size()) + " found")


func _on_registry_changed() -> void:
	_dirty = true


func tick(dt: float) -> void:
	if not _alive():
		return
	if _root.is_visible_in_tree():
		_reg.call("tick", dt)
	if _dirty and not _root.get_global_rect().has_point(_root.get_global_mouse_position()):
		rebuild()


func _on_tile_input(event: InputEvent, id: String, anchor: Control) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			anchor.accept_event()
			open_menu(id, anchor)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					_press_id = ""
					add_to_selection(id)
					return
				_press_pos = mb.position
				_press_id = id
			else:
				_press_id = ""
		return
	if event is InputEventMouseMotion and _press_id == id:
		if ((event as InputEventMouseMotion).position - _press_pos).length() >= float(Tk.px(DRAG_MIN)):
			_press_id = ""
			begin_drag(id)


func drag_payload(id: String) -> Dictionary:
	var pid: String = preset_of(id)
	if not pid.is_empty():
		var p: Dictionary = Ops.preset_by_id(pid)
		var base: String = str(((p.get("payload", {}) as Dictionary).get("transition", {}) as Dictionary).get("kind", "fade"))
		return {"kind": "transition", "id": base, "preset": "" if plant_wrong_payload else pid}
	return {"kind": "transition", "id": "dissolve" if plant_wrong_payload else id}


func begin_drag(id: String) -> void:
	var layer: CanvasLayer = PmDragLayer.find(_root)
	if layer == null:
		return
	var shown: String = String(Ops.preset_by_id(preset_of(id)).get("label", "")) if not preset_of(id).is_empty() else String(_reg.call("label_of", id))
	var ghost: Label = PmLabel.tight(shown, "text_bright")
	var card: PanelContainer = PmUI.panel("bg_panel_high")
	card.add_child(ghost)
	layer.call("begin", drag_payload(id), card, Vector2(10.0, 10.0))


func add_to_selection(id: String) -> int:
	var d: Project = doc()
	var s: Sequence = seq()
	if d == null or s == null:
		return 0
	if Verbs.selection(s).is_empty():
		Events.toast("Select a clip first, or drag the transition onto a cut")
		return 0
	if not preset_of(id).is_empty():
		return 1 if Ops.apply_preset(Ops.preset_by_id(preset_of(id)), Verbs.selection(s), 0.0, null) else 0
	var done: int = Ops.put_on_selection(d, s, id)
	if done == 0:
		Events.toast("Select video clips for this transition")
	return done


func menu_items(id: String) -> Array:
	var items: Array = []
	items.append(PmMenu.item("add", "Put on the selected clips"))
	if not preset_of(id).is_empty():
		items.append(PmMenu.item("rename", "Rename"))
		items.append(PmMenu.item("delete", "Delete"))
		return items
	items.append(PmMenu.check_item("default", "Use as the default transition", String(_reg.call("default_kind")) == id))
	var def: Dictionary = _reg.call("get_def", id)
	if String(def.get("source", "")) == "user":
		items.append(PmMenu.item("show", "Show its folder"))
	items.append(PmMenu.separator())
	items.append(PmMenu.item(ReworkRequest.MENU_ID, ReworkRequest.LABEL))
	return items


func open_menu(id: String, anchor: Control) -> void:
	var m: Control = PmMenu.open(anchor, menu_items(id), anchor.get_global_mouse_position())
	if m != null and m.is_inside_tree():
		m.connect("picked", menu_picked.bind(id))


func menu_picked(pick: String, id: String) -> void:
	if pick == "add":
		add_to_selection(id)
	elif pick == "default":
		set_default(id)
	elif pick == "rename":
		var fields: Array[Dictionary] = [{"key": "name", "label": "Name", "type": "string", "default": String(Ops.preset_by_id(preset_of(id)).get("label", ""))}]
		var answered: Signal = PmUI.form(_root, "Rename preset", fields, "Rename", "Cancel")
		answered.connect(_on_renamed.bind(preset_of(id)))
	elif pick == "delete":
		delete_preset(preset_of(id))
	elif pick == ReworkRequest.MENU_ID:
		ReworkRequest.ask(_root, _reg.call("get_def", id))
	elif pick == "show":
		OS.shell_open(ProjectSettings.globalize_path(String((_reg.call("get_def", id) as Dictionary).get("folder", TransitionRegistry.user_root()))))


func _on_renamed(result: Variant, pid: String) -> void:
	if result is Dictionary and not (result as Dictionary).is_empty():
		rename_preset(pid, String((result as Dictionary).get("name", "")))


func rename_preset(pid: String, label: String) -> bool:
	var ok: bool = Ops.rename_preset(pid, label)
	if ok:
		rebuild()
	return ok


func delete_preset(pid: String) -> bool:
	var ok: bool = Ops.delete_preset(pid)
	if ok:
		Events.toast("Preset deleted")
		rebuild()
	return ok


func set_default(id: String) -> bool:
	if not bool(_reg.call("set_default_kind", id)):
		return false
	Events.toast(String(_reg.call("label_of", id)) + " is now the default transition")
	rebuild()
	return true


func _on_pref_changed(key: String) -> void:
	if key == TransitionRegistry.PREF_DEFAULT:
		_dirty = true


func _on_doc_changed(kind: String) -> void:
	if kind == "selection" or kind == "structure":
		_mark_current()


func _on_sequence_changed(_seq_id: String) -> void:
	_mark_current()


func _on_project_changed() -> void:
	_mark_current()


func _mark_current() -> void:
	var now: String = Ops.selected_kind(seq())
	if now == _current:
		return
	_current = now
	for id: Variant in tiles.keys():
		var tile: Control = tiles[id]
		if not is_instance_valid(tile):
			continue
		var th: Control = Tiles.thumb_of(tile)
		if th != null:
			th.set("current", String(id) == now)
			th.queue_redraw()


func save_state() -> Dictionary:
	return {"search": search}


func restore_state(d: Dictionary) -> void:
	var s: String = String(d.get("search", ""))
	if s != search and _search != null:
		_search.text = s
		_on_search(s)

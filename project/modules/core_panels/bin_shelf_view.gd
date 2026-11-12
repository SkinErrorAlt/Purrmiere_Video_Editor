extends Control

const Shelf := preload("res://doc/bin_shelf.gd")
const PmUIKit := preload("res://ui/kit/pm_ui.gd")
const PmLabelKit := preload("res://ui/kit/pm_label.gd")
const PmButtonKit := preload("res://ui/kit/pm_button.gd")
const PmMenuKit := preload("res://ui/kit/pm_menu.gd")
const PmSlotKit := preload("res://ui/kit/pm_slot.gd")
const PmScrollKit := preload("res://ui/kit/pm_scroll.gd")
const PmTextKit := preload("res://ui/kit/pm_text.gd")
const IconsKit := preload("res://ui/kit/icons.gd")
const HEAD_H := 24.0
const TAB_H := 22.0
const ROW_H := 20.0
const GRAB_W := 5.0
const CHIP_W := 3.0
const INDENT := 12.0
const PAD := 4.0
const TITLE := "Pinned"
const EMPTY_HINT := "Drag folders or files here"
const KIND_TAB := "tab"
const KIND_ITEM := "item"
const DRAG_SLOP := 4.0
const ShelfDragOut := preload("res://modules/core_panels/shelf_drag_out.gd")

var panel: RefCounted = null
var tabs: Array = []
var rows: Array[Dictionary] = []
var hover: int = -1
var rows_usec: int = 0
var check_usec: int = 0
var draw_usec: int = 0
var checks: int = 0
var _head: PanelContainer = null
var _fold_button: Button = null
var _add_button: Button = null
var _count: Label = null
var _slot: Control = null
var _grab: Control = null
var _scroll: Node = null
var _there: Dictionary = {}
var _rename_edit: LineEdit = null
var _rename_tab: String = ""
var _menu_tab: String = ""
var _menu_path: String = ""
var drag: Dictionary = {}
var drops: int = 0
var handed_out: int = 0
var _pending_use: Dictionary = {}
var _content_h: float = 0.0
var _grabbing: bool = false


static func register_prefs() -> void:
	if not Prefs.is_registered(Shelf.PREF_KEY):
		Prefs.register(Shelf.PREF_KEY, "", {"label": "Bin pinned sidebar, what is on it", "type": "json"})
	if not Prefs.is_registered(Shelf.PREF_OPEN):
		Prefs.register(Shelf.PREF_OPEN, false, {"label": "Bin shows the pinned sidebar", "type": "bool"})
	if not Prefs.is_registered(Shelf.PREF_WIDTH):
		Prefs.register(Shelf.PREF_WIDTH, Shelf.WIDTH_DEFAULT, {"label": "Bin pinned sidebar width", "type": "float", "min": Shelf.WIDTH_LEAST, "max": Shelf.WIDTH_MOST})


static func stored_tabs() -> Array:
	register_prefs()
	return Shelf.read(String(Prefs.get_value(Shelf.PREF_KEY)))


static func stored_open() -> bool:
	register_prefs()
	return bool(Prefs.get_value(Shelf.PREF_OPEN))


static func stored_width() -> float:
	register_prefs()
	return Shelf.width_of(Prefs.get_value(Shelf.PREF_WIDTH))


func _init() -> void:
	name = "BinShelf"
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_head = PmUIKit.panel("bg_panel_alt")
	var hsb: StyleBoxFlat = _head.get_theme_stylebox("panel")
	hsb.content_margin_top = 1.0
	hsb.content_margin_bottom = 1.0
	hsb.content_margin_left = 2.0
	hsb.content_margin_right = 2.0
	_head.anchor_right = 1.0
	_head.offset_bottom = head_h()
	var row: HBoxContainer = PmUIKit.hbox(Tk.px(2.0))
	_head.add_child(row)
	_fold_button = PmButtonKit.make("", "chev_l")
	_fold_button.set("quiet", true)
	_fold_button.set("icon_px", 12.0)
	PmUIKit.tip(_fold_button, "Hide the pinned sidebar")
	_fold_button.pressed.connect(_on_fold_pressed)
	row.add_child(_fold_button)
	var title: Label = PmLabelKit.small(TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.clip_text = true
	row.add_child(title)
	_count = PmLabelKit.faint("")
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_count)
	_add_button = PmButtonKit.make("", "plus")
	_add_button.set("quiet", true)
	_add_button.set("icon_px", 12.0)
	PmUIKit.tip(_add_button, "New tab")
	_add_button.pressed.connect(new_tab)
	row.add_child(_add_button)
	add_child(_head)
	_slot = PmSlotKit.make(PackedStringArray(["files"]))
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.anchor_right = 1.0
	_slot.anchor_bottom = 1.0
	_slot.offset_top = head_h()
	_slot.connect("dropped", _on_payload)
	add_child(_slot)
	_grab = Control.new()
	_grab.name = "Grab"
	_grab.anchor_left = 1.0
	_grab.anchor_right = 1.0
	_grab.anchor_bottom = 1.0
	_grab.offset_left = -float(Tk.px(GRAB_W))
	_grab.offset_top = head_h()
	_grab.mouse_filter = Control.MOUSE_FILTER_STOP
	_grab.mouse_default_cursor_shape = Control.CURSOR_HSPLIT
	_grab.gui_input.connect(_on_grab_input)
	add_child(_grab)
	_scroll = PmScrollKit.make(false)
	_scroll.set("ctrl_wheel_zooms", false)
	_scroll.set("alt_wheel_zooms", false)
	_scroll.connect("changed", queue_redraw)
	add_child(_scroll)
	gui_input.connect(_on_input)
	mouse_exited.connect(_on_exit)
	resized.connect(_on_resized)


func head_h() -> float:
	return float(Tk.px(HEAD_H))


func tab_h() -> float:
	return float(Tk.px(TAB_H))


func row_h() -> float:
	return float(Tk.px(ROW_H))


func begin() -> void:
	register_prefs()
	custom_minimum_size.x = stored_width()
	tabs = stored_tabs()
	visible = stored_open()
	if visible:
		recheck()
	rebuild()


func set_open(on: bool) -> void:
	Prefs.set_value(Shelf.PREF_OPEN, on)
	visible = on
	if on:
		recheck()
		rebuild()
	else:
		end_rename(false)


func is_open() -> bool:
	return visible


func set_width(w: float) -> void:
	var v: float = Shelf.width_of(w)
	custom_minimum_size.x = v
	Prefs.set_value(Shelf.PREF_WIDTH, v)


func width() -> float:
	return custom_minimum_size.x


func set_tabs(next: Array) -> void:
	if next == tabs:
		return
	tabs = next
	Prefs.set_value(Shelf.PREF_KEY, Shelf.write(tabs))
	rebuild()


func recheck() -> void:
	var t0: int = Time.get_ticks_usec()
	var hits: int = 0
	_there.clear()
	for one: Variant in tabs:
		for it: Variant in ((one as Dictionary).get("items", []) as Array):
			var item: Dictionary = it
			_there[Shelf.tidy(String(item.get("path", "")))] = Shelf.there(item)
			hits += 1
	checks = hits
	check_usec = Time.get_ticks_usec() - t0


func _exists(item: Dictionary) -> bool:
	return bool(_there.get(Shelf.tidy(String(item.get("path", ""))), true))


func _label_for(path: String, shared: Dictionary) -> String:
	var leaf: String = Shelf.leaf(path)
	if int(shared.get(leaf.to_lower(), 0)) < 2:
		return leaf
	var parent: String = Shelf.tidy(path).get_base_dir().get_file()
	return (parent + "/" + leaf) if not parent.is_empty() else leaf


func rebuild() -> void:
	var t0: int = Time.get_ticks_usec()
	rows.clear()
	var y: float = 0.0
	var th: float = tab_h()
	var rh: float = row_h()
	for one: Variant in tabs:
		var tab: Dictionary = one
		var tid: String = String(tab.get("id", ""))
		var items: Array = tab.get("items", []) as Array
		var open: bool = bool(tab.get("open", true))
		rows.append({
			"kind": KIND_TAB,
			"tab": tid,
			"path": "",
			"label": String(tab.get("name", "")),
			"colour": int(tab.get("colour", -1)),
			"open": open,
			"count": items.size(),
			"folder": false,
			"gone": false,
			"y": y,
			"h": th,
		})
		y += th
		if not open:
			continue
		var shared: Dictionary = {}
		for it: Variant in items:
			var one_leaf: String = Shelf.leaf(String((it as Dictionary).get("path", ""))).to_lower()
			shared[one_leaf] = int(shared.get(one_leaf, 0)) + 1
		for it: Variant in items:
			var item: Dictionary = it
			var path: String = String(item.get("path", ""))
			rows.append({
				"kind": KIND_ITEM,
				"tab": tid,
				"path": path,
				"label": _label_for(path, shared),
				"colour": int(tab.get("colour", -1)),
				"open": true,
				"count": 0,
				"folder": String(item.get("kind", Shelf.FILE)) == Shelf.FOLDER,
				"gone": not _exists(item),
				"y": y,
				"h": rh,
			})
			y += rh
	_content_h = y
	rows_usec = Time.get_ticks_usec() - t0
	_sync_count()
	_sync_scroll()
	queue_redraw()


func tally() -> Dictionary:
	var folders: int = 0
	var files: int = 0
	var gone: int = 0
	for one: Variant in tabs:
		for it: Variant in ((one as Dictionary).get("items", []) as Array):
			var item: Dictionary = it
			if String(item.get("kind", Shelf.FILE)) == Shelf.FOLDER:
				folders += 1
			else:
				files += 1
			if not _exists(item):
				gone += 1
	return {"tabs": tabs.size(), "folders": folders, "files": files, "missing": gone}


func _sync_count() -> void:
	if _count == null or not is_instance_valid(_count):
		return
	var t: Dictionary = tally()
	var total: int = int(t["folders"]) + int(t["files"])
	var text: String = str(total)
	if int(t["missing"]) > 0:
		text += ", " + str(int(t["missing"])) + " gone"
	_count.text = text
	PmUIKit.tip(_count, "%d tabs, %d folders, %d files, %d missing" % [int(t["tabs"]), int(t["folders"]), int(t["files"]), int(t["missing"])])


func _sync_scroll() -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		return
	_scroll.call("set_content", size.x, _content_h)
	_scroll.call("set_view", size.x, maxf(size.y - head_h(), 0.0))


func _on_resized() -> void:
	_sync_scroll()
	queue_redraw()


func _on_exit() -> void:
	if hover < 0:
		return
	hover = -1
	queue_redraw()


func _on_fold_pressed() -> void:
	set_open(false)
	if panel != null:
		panel.call("shelf_sync_button")


func scroll_y() -> float:
	return float(_scroll.get("scroll_y")) if _scroll != null and is_instance_valid(_scroll) else 0.0


func drop_spot(local: Vector2) -> Dictionary:
	if rows.is_empty():
		return {}
	var y: float = local.y - head_h() + scroll_y()
	for i: int in rows.size():
		var r: Dictionary = rows[i]
		var top: float = float(r["y"])
		var tall: float = float(r["h"])
		if y < top or y >= top + tall:
			continue
		var below: bool = y >= top + tall * 0.5
		if String(r["kind"]) == KIND_TAB:
			if not below:
				return {"kind": KIND_TAB, "tab": String(r["tab"]), "index": Shelf.index_of(tabs, String(r["tab"])), "line": top}
			return {"kind": KIND_ITEM, "tab": String(r["tab"]), "index": 0, "line": top + tall}
		var at: int = Shelf.item_index(tabs, String(r["tab"]), String(r["path"]))
		return {"kind": KIND_ITEM, "tab": String(r["tab"]), "index": at + (1 if below else 0), "line": top + (tall if below else 0.0)}
	var last: Dictionary = rows[rows.size() - 1]
	var tail_tab: String = String(last["tab"])
	return {"kind": KIND_ITEM, "tab": tail_tab, "index": Shelf.items_of(tabs, tail_tab).size(), "line": float(last["y"]) + float(last["h"])}


func dragging() -> bool:
	return not drag.is_empty() and bool(drag.get("open", false))


func begin_drag(index: int, at: Vector2) -> void:
	if index < 0 or index >= rows.size():
		return
	var r: Dictionary = rows[index]
	drag = {"kind": String(r["kind"]), "tab": String(r["tab"]), "path": String(r["path"]), "press": at, "open": false, "spot": {}}


func drag_motion(at: Vector2) -> void:
	if drag.is_empty():
		return
	if not bool(drag["open"]):
		if at.distance_to(Vector2(drag["press"])) < DRAG_SLOP:
			return
		drag["open"] = true
	if String(drag["kind"]) == KIND_ITEM and not Rect2(Vector2.ZERO, size).has_point(at) and hand_out(at):
		return
	drag["spot"] = drop_spot(at)
	queue_redraw()


func hand_out(_at: Vector2) -> bool:
	var path: String = String(drag.get("path", ""))
	if not ShelfDragOut.can_leave(kind_in(String(drag.get("tab", "")), path), path):
		return false
	if not ShelfDragOut.begin(self, panel, path, Vector2(10.0, 10.0)):
		return false
	drag = {}
	_pending_use = {}
	handed_out += 1
	queue_redraw()
	return true


func drop_now() -> bool:
	if not dragging():
		drag = {}
		return false
	var spot: Dictionary = drag.get("spot", {})
	var took: bool = false
	if not spot.is_empty():
		if String(drag["kind"]) == KIND_TAB:
			took = apply_tabs(Shelf.tab_moved_to(tabs, String(drag["tab"]), int(spot.get("index", 0))))
		else:
			took = apply_tabs(Shelf.item_dropped(tabs, String(drag["tab"]), String(drag["path"]), String(spot.get("tab", "")), int(spot.get("index", 0))))
	if took:
		drops += 1
	drag = {}
	queue_redraw()
	return took


func apply_tabs(next: Array) -> bool:
	if next == tabs:
		return false
	set_tabs(next)
	return true


func cancel_drag() -> void:
	if drag.is_empty():
		return
	drag = {}
	queue_redraw()


func index_at(local: Vector2) -> int:
	if local.y < head_h():
		return -1
	var y: float = local.y - head_h() + scroll_y()
	for i: int in rows.size():
		var r: Dictionary = rows[i]
		if y >= float(r["y"]) and y < float(r["y"]) + float(r["h"]):
			return i
	return -1


func rect_at(index: int) -> Rect2:
	if index < 0 or index >= rows.size():
		return Rect2()
	var r: Dictionary = rows[index]
	return Rect2(0.0, head_h() + float(r["y"]) - scroll_y(), maxf(size.x - float(Tk.px(GRAB_W)), 0.0), float(r["h"]))


func row_of_tab(tab_id: String) -> int:
	for i: int in rows.size():
		var r: Dictionary = rows[i]
		if String(r["kind"]) == KIND_TAB and String(r["tab"]) == tab_id:
			return i
	return -1


func tab_at(local: Vector2) -> String:
	var i: int = index_at(local)
	return String((rows[i] as Dictionary)["tab"]) if i >= 0 else ""


func first_tab() -> String:
	return String((tabs[0] as Dictionary).get("id", "")) if not tabs.is_empty() else ""


func name_of(tab_id: String) -> String:
	var at: int = Shelf.index_of(tabs, tab_id)
	return String((tabs[at] as Dictionary).get("name", "")) if at >= 0 else ""


func kind_in(tab_id: String, path: String) -> String:
	for it: Variant in Shelf.items_of(tabs, tab_id):
		if Shelf.same(String((it as Dictionary).get("path", "")), path):
			return String((it as Dictionary).get("kind", Shelf.FILE))
	return Shelf.kind_of(path)


func takes_global(at: Vector2) -> bool:
	return visible and is_visible_in_tree() and get_global_rect().has_point(at)


func pin(paths: PackedStringArray, tab_id: String) -> int:
	var tid: String = tab_id if Shelf.index_of(tabs, tab_id) >= 0 else first_tab()
	if tid.is_empty():
		return 0
	var before: int = Shelf.items_of(tabs, tid).size()
	var out: Array = tabs
	for p: String in paths:
		var kind: String = Shelf.kind_of(p)
		out = Shelf.with_item(out, tid, p, kind)
		_there[Shelf.tidy(p)] = Shelf.there(Shelf.make_item(kind, p))
	var added: int = Shelf.items_of(out, tid).size() - before
	if added > 0:
		set_tabs(out)
	return added


func pin_at(paths: PackedStringArray, local: Vector2) -> int:
	var tid: String = tab_at(local)
	if tid.is_empty():
		tid = first_tab()
	var added: int = pin(paths, tid)
	if added > 0:
		Events.toast("Pinned " + str(added) + (" item to " if added == 1 else " items to ") + name_of(tid))
	elif not paths.is_empty():
		Events.toast("Already pinned to " + name_of(tid))
	return added


func pin_global(paths: PackedStringArray, at: Vector2) -> int:
	return pin_at(paths, at - global_position)


func _on_payload(payload: Dictionary, local: Vector2) -> void:
	var paths: PackedStringArray = PackedStringArray()
	for v: Variant in payload.get("paths", []):
		paths.append(String(v))
	if paths.is_empty():
		return
	pin_at(paths, local + Vector2(0.0, head_h()))


func use_item(tab_id: String, path: String) -> bool:
	var kind: String = kind_in(tab_id, path)
	var ok: bool = Shelf.there(Shelf.make_item(kind, path))
	_there[Shelf.tidy(path)] = ok
	if not ok:
		rebuild()
		Events.toast(Shelf.leaf(path) + " is not there any more")
		return false
	if panel == null:
		return false
	if kind == Shelf.FOLDER:
		panel.call("shelf_browse_folder", path)
	else:
		panel.call("shelf_import_file", path)
	return true


func new_tab() -> void:
	var before: int = tabs.size()
	var out: Array = Shelf.with_tab(tabs, "Tab " + str(before + 1))
	if out.size() == before:
		Events.toast("The sidebar holds at most " + str(Shelf.TABS_MOST) + " tabs")
		return
	set_tabs(out)
	begin_rename(String((tabs[tabs.size() - 1] as Dictionary)["id"]))


func scroll_to_row(index: int) -> void:
	if index < 0 or index >= rows.size():
		return
	var r: Dictionary = rows[index]
	var view_h: float = maxf(size.y - head_h(), 0.0)
	var high: float = float(r["y"])
	var low: float = high + float(r["h"])
	var y: float = scroll_y()
	if high < y:
		y = high
	elif low > y + view_h:
		y = low - view_h
	_scroll.call("scroll_to", 0.0, maxf(y, 0.0), false)


func begin_rename(tab_id: String) -> void:
	end_rename(false)
	var at: int = row_of_tab(tab_id)
	scroll_to_row(at)
	var r: Rect2 = rect_at(at)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	_rename_tab = tab_id
	_rename_edit = PmUIKit.line_edit("", name_of(tab_id))
	_rename_edit.position = r.position
	_rename_edit.size = r.size
	_rename_edit.text_submitted.connect(_on_rename_submitted)
	_rename_edit.focus_exited.connect(_on_rename_focus_out)
	_rename_edit.gui_input.connect(_on_rename_input)
	add_child(_rename_edit)
	_rename_edit.grab_focus()
	_rename_edit.select_all()


func renaming() -> String:
	return _rename_tab if _rename_edit != null and is_instance_valid(_rename_edit) else ""


func rename_text(text: String) -> void:
	if _rename_edit != null and is_instance_valid(_rename_edit):
		_rename_edit.text = text


func end_rename(apply: bool) -> void:
	var e: LineEdit = _rename_edit
	var tid: String = _rename_tab
	_rename_edit = null
	_rename_tab = ""
	if e == null or not is_instance_valid(e):
		return
	var text: String = e.text
	remove_child(e)
	e.queue_free()
	if apply and not tid.is_empty():
		set_tabs(Shelf.renamed(tabs, tid, text))


func _on_rename_submitted(_text: String) -> void:
	end_rename(true)


func _on_rename_focus_out() -> void:
	end_rename(true)


func _on_rename_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_rename_edit.accept_event()
		end_rename(false)


func _on_grab_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_grabbing = mb.pressed
		_grab.accept_event()
		return
	if event is InputEventMouseMotion and _grabbing:
		set_width(width() + (event as InputEventMouseMotion).relative.x)
		_grab.accept_event()


func _on_input(event: InputEvent) -> void:
	if bool(_scroll.call("handle", event)):
		accept_event()
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if not drag.is_empty():
			drag_motion(mm.position)
			accept_event()
			return
		var i: int = index_at(mm.position)
		if i != hover:
			hover = i
			queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		if mb.button_index == MOUSE_BUTTON_LEFT and not drag.is_empty():
			accept_event()
			var moved: bool = dragging()
			var use: Dictionary = _pending_use
			_pending_use = {}
			drop_now()
			if not moved and not use.is_empty():
				use_item(String(use["tab"]), String(use["path"]))
		return
	var at: int = index_at(mb.position)
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		open_menu(at, get_global_transform() * mb.position)
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	end_rename(true)
	if at < 0 or at >= rows.size():
		return
	var r: Dictionary = rows[at]
	if String(r["kind"]) == KIND_TAB:
		if mb.double_click:
			begin_rename(String(r["tab"]))
			return
		begin_drag(at, mb.position)
		set_tabs(Shelf.folded(tabs, String(r["tab"]), not bool(r["open"])))
		return
	begin_drag(at, mb.position)
	_pending_use = {"tab": String(r["tab"]), "path": String(r["path"])}


func colour_items(current: int) -> Array:
	var out: Array = [PmMenuKit.check_item("colour:-1", "None", current < 0)]
	for i: int in 16:
		out.append(PmMenuKit.check_item("colour:" + str(i), Tk.label_name(i), current == i))
	return out


func tab_menu(tab_id: String) -> Array:
	var at: int = Shelf.index_of(tabs, tab_id)
	var colour: int = int((tabs[at] as Dictionary).get("colour", -1)) if at >= 0 else -1
	var out: Array = []
	out.append(PmMenuKit.item("rename", "Rename", "", "pen"))
	out.append(PmMenuKit.sub_item("colour", "Colour", colour_items(colour), "label"))
	out.append(PmMenuKit.separator())
	out.append(PmMenuKit.item("up", "Move up", "", "chev_u"))
	out.append(PmMenuKit.item("down", "Move down", "", "chev_d"))
	out.append(PmMenuKit.separator())
	out.append(PmMenuKit.item("new_tab", "New tab", "", "plus"))
	out.append(PmMenuKit.item("remove", "Remove this tab", "", "trash"))
	out.append(PmMenuKit.item("check", "Check the pinned paths again"))
	return out


func item_menu(tab_id: String, path: String) -> Array:
	var out: Array = []
	if kind_in(tab_id, path) == Shelf.FOLDER:
		out.append(PmMenuKit.item("use", "Import from this folder", "", "import"))
		out.append(PmMenuKit.item("import_all", "Import everything here", "", "folder"))
	else:
		out.append(PmMenuKit.item("use", "Import this file", "", "import"))
	var moves: Array = []
	for one: Variant in tabs:
		var tid: String = String((one as Dictionary).get("id", ""))
		if tid != tab_id:
			moves.append(PmMenuKit.item("move:" + tid, String((one as Dictionary).get("name", ""))))
	if not moves.is_empty():
		out.append(PmMenuKit.sub_item("move", "Move to another tab", moves, "folder"))
	out.append(PmMenuKit.separator())
	out.append(PmMenuKit.item("remove", "Take off the sidebar", "", "trash"))
	return out


func empty_menu() -> Array:
	return [PmMenuKit.item("new_tab", "New tab", "", "plus"), PmMenuKit.item("check", "Check the pinned paths again")]


func open_menu(index: int, at: Vector2) -> Control:
	_menu_tab = ""
	_menu_path = ""
	var items: Array = []
	if index < 0 or index >= rows.size():
		items = empty_menu()
	else:
		var r: Dictionary = rows[index]
		_menu_tab = String(r["tab"])
		if String(r["kind"]) == KIND_TAB:
			items = tab_menu(_menu_tab)
		else:
			_menu_path = String(r["path"])
			items = item_menu(_menu_tab, _menu_path)
	var m: Control = PmMenuKit.open(self, items, at)
	if m != null and m.is_inside_tree():
		m.connect("picked", on_menu_picked)
	return m


func on_menu_picked(id: String) -> void:
	if id.begins_with("colour:"):
		set_tabs(Shelf.coloured(tabs, _menu_tab, int(id.substr(7))))
		return
	if id.begins_with("move:"):
		set_tabs(Shelf.item_moved_to(tabs, _menu_tab, _menu_path, id.substr(5)))
		return
	if id == "new_tab":
		new_tab()
	elif id == "check":
		recheck()
		rebuild()
	elif id == "rename":
		begin_rename(_menu_tab)
	elif id == "up":
		set_tabs(Shelf.tab_moved(tabs, _menu_tab, -1))
	elif id == "down":
		set_tabs(Shelf.tab_moved(tabs, _menu_tab, 1))
	elif id == "use":
		use_item(_menu_tab, _menu_path)
	elif id == "import_all":
		if panel != null:
			panel.call("shelf_import_folder", _menu_path)
	elif id == "remove":
		if _menu_path.is_empty():
			var before: int = tabs.size()
			set_tabs(Shelf.without_tab(tabs, _menu_tab))
			if tabs.size() == before:
				Events.toast("The sidebar keeps at least one tab")
		else:
			set_tabs(Shelf.without_item(tabs, _menu_tab, _menu_path))


func _draw() -> void:
	var t0: int = Time.get_ticks_usec()
	draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_panel_alt"], true)
	var right: float = maxf(size.x - float(Tk.px(GRAB_W)), 0.0)
	var top: float = head_h()
	var font: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var pad: float = float(Tk.px(PAD))
	var chip: float = float(Tk.px(CHIP_W))
	var indent: float = float(Tk.px(INDENT))
	var sy: float = scroll_y()
	if rows.size() <= 1 and _content_h <= tab_h():
		PmTextKit.draw(self, font, Rect2(0.0, top + tab_h(), right, row_h() * 2.0), EMPTY_HINT, fs, Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_LEFT, pad, NAN, PmTextKit.ELIDE)
	for i: int in rows.size():
		var r: Dictionary = rows[i]
		var h: float = float(r["h"])
		var y: float = top + float(r["y"]) - sy
		if y + h <= top or y >= size.y:
			continue
		var is_tab: bool = String(r["kind"]) == KIND_TAB
		var colour: int = int(r["colour"])
		var icon_side: float = minf(h - 4.0, float(Tk.px(13.0)))
		var x: float = pad + chip if is_tab else indent
		if is_tab:
			draw_rect(Rect2(0.0, y, right, h), Tk.c["bg_panel_high"], true)
			if colour >= 0:
				draw_rect(Rect2(0.0, y, chip, h), Tk.label_colour(colour), true)
		elif i == hover:
			draw_rect(Rect2(0.0, y, right, h), Tk.c["bg_panel_high"], true)
		var gone: bool = bool(r["gone"])
		var icon: String = ("chev_d" if bool(r["open"]) else "chev_r") if is_tab else ("folder" if bool(r["folder"]) else "film")
		var icon_rect: Rect2 = Rect2(x, y + (h - icon_side) * 0.5, icon_side, icon_side)
		var tint: Color = Tk.c["key_negative"] if gone else (Tk.c["text_dim"] if is_tab else Tk.c["text_faint"])
		IconsKit.draw(self, icon, icon_rect, tint)
		var text_x: float = icon_rect.position.x + icon_side + pad
		var tail: String = str(int(r["count"])) if is_tab else ("missing" if gone else "")
		var tail_w: float = (ceil(PmTextKit.width_of(font, tail, fs)) + pad * 2.0) if not tail.is_empty() else 0.0
		var text_w: float = maxf(right - text_x - tail_w - pad, 1.0)
		var label_colour: Color = Tk.c["key_negative"] if gone else (Tk.c["text_bright"] if is_tab else Tk.c["text"])
		PmTextKit.draw(self, font, Rect2(text_x, y, text_w, h), String(r["label"]), fs, label_colour, HORIZONTAL_ALIGNMENT_LEFT, 0.0, NAN, PmTextKit.ELIDE_OWN_TIP)
		if not tail.is_empty():
			PmTextKit.draw(self, font, Rect2(right - tail_w, y, tail_w, h), tail, fs, Tk.c["key_negative"] if gone else Tk.c["text_faint"], HORIZONTAL_ALIGNMENT_RIGHT, pad, NAN, PmTextKit.WHOLE)
	draw_drop_line()
	draw_rect(Rect2(Vector2(size.x - 1.0, 0.0), Vector2(1.0, size.y)), Tk.c["border"], true)
	draw_usec = Time.get_ticks_usec() - t0


func draw_drop_line() -> void:
	if not dragging():
		return
	var spot: Dictionary = drag.get("spot", {})
	if spot.is_empty():
		return
	var y: float = head_h() + float(spot.get("line", 0.0)) - scroll_y()
	if y < head_h() - 1.0 or y > size.y + 1.0:
		return
	var left: float = float(Tk.px(INDENT)) if String(spot.get("kind", "")) == KIND_ITEM else 0.0
	var thick: float = maxf(2.0, float(Tk.px(2.0)))
	draw_rect(Rect2(left, y - thick * 0.5, maxf(size.x - 1.0 - left, 1.0), thick), Tk.c["sol"], true)
	draw_rect(Rect2(left, y - thick * 1.5, thick, thick * 3.0), Tk.c["sol"], true)

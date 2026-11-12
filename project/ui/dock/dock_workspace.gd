extends Control

signal focus_changed(id: String)
signal layout_changed
signal layout_loaded(name: String)
signal panel_shown(id: String)
signal panel_hidden(id: String)
signal lock_changed(on: bool)

const Io := preload("res://doc/io.gd")
const Frame := preload("res://ui/dock/dock_panel_frame.gd")
const PmSplit := preload("res://ui/kit/pm_split.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const DockFloat := preload("res://ui/dock/dock_float_window.gd")
const PmDragLayer := preload("res://ui/kit/pm_drag_layer.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const DockHistory := preload("res://ui/dock/dock_history.gd")
const PREF_LOCK := "ui.layout_locked"
const FLOAT_MOVE_MIN := 4.0
const OWN_PREFIX := "own_"
const LOCK_NOTE := "The layout is locked. Window, Lock layout turns it off so panels can be moved and closed again."
const SIDE_WORDS: Dictionary = {"l": "left of", "r": "right of", "t": "above", "b": "below"}
const SHIPPED_DIR := "res://ui/dock/layouts/"
const LAYOUT_VERSION := 1
const PREF_WORKSPACE := "ui.workspace"
const FLOAT_SIZE := Vector2(420.0, 320.0)

var layout_name: String = ""
var focused_id: String = ""
var maximised_id: String = ""
var _tree: Dictionary = {}
var _panels: Dictionary = {}
var _frames: Dictionary = {}
var _floats: Dictionary = {}
var _park: Control = null
var _root_holder: Control = null
var _next_uid: int = 1
var _was_down: bool = false
var _building: bool = false
var locked: bool = false
var workspace_switcher: Callable = Callable()
var _last_snap: Dictionary = {}
var _last_key: String = ""
var _pending_label: String = ""
var _flush_queued: bool = false
var _restoring: bool = false
var _lock_pass: bool = false

static var _history: RefCounted = null


func _init() -> void:
	name = "DockWorkspace"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_park = Control.new()
	_park.name = "Park"
	_park.visible = false
	_park.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_park)
	_root_holder = Control.new()
	_root_holder.name = "Root"
	_root_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root_holder)
	set_process(true)


func _ready() -> void:
	if not Prefs.is_registered(PREF_WORKSPACE):
		Prefs.register(PREF_WORKSPACE, "editing", {"label": "Workspace", "type": "string"})
	if not Prefs.is_registered(PREF_LOCK):
		Prefs.register(PREF_LOCK, false, {"label": "Lock layout (panels cannot be moved or closed by accident)", "type": "bool"})
	if bool(Prefs.get_value(PREF_LOCK)) != locked:
		set_locked(bool(Prefs.get_value(PREF_LOCK)))
	if not Prefs.changed.is_connected(_on_pref_changed):
		Prefs.changed.connect(_on_pref_changed)
	if Host.has_signal("registry_changed") and not Host.registry_changed.is_connected(_on_registry_changed):
		Host.registry_changed.connect(_on_registry_changed)
	var layer: CanvasLayer = PmDragLayer.find(self)
	if layer != null and not layer.dropped_outside.is_connected(_on_dropped_outside):
		layer.dropped_outside.connect(_on_dropped_outside)


func _process(_dt: float) -> void:
	if not is_visible_in_tree():
		return
	var down: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if down and not _was_down:
		var f: Control = frame_at(get_global_mouse_position())
		if f != null:
			var id: String = f.call("active_id")
			if not id.is_empty():
				focus_panel(id)
	_was_down = down


func new_node_split(dir: String, ratio: float, a: Dictionary, b: Dictionary) -> Dictionary:
	var n: Dictionary = {"t": "s", "dir": dir, "ratio": clampf(ratio, 0.05, 0.95), "a": a, "b": b, "uid": _next_uid}
	_next_uid += 1
	return n


func new_node_group(tabs: PackedStringArray, active: String) -> Dictionary:
	var arr: Array = []
	for t: String in tabs:
		arr.append(t)
	var act: String = active
	if not (act in tabs) and tabs.size() > 0:
		act = tabs[0]
	var n: Dictionary = {"t": "g", "tabs": arr, "active": act, "uid": _next_uid}
	_next_uid += 1
	return n


func _normalise(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = raw
	var t: String = String(d.get("t", ""))
	if t == "s":
		var a: Dictionary = _normalise(d.get("a", {}))
		var b: Dictionary = _normalise(d.get("b", {}))
		if a.is_empty() and b.is_empty():
			return {}
		if a.is_empty():
			return b
		if b.is_empty():
			return a
		var dir: String = String(d.get("dir", "h"))
		if dir != "h" and dir != "v":
			dir = "h"
		return new_node_split(dir, float(d.get("ratio", 0.5)), a, b)
	if t == "g":
		var tabs := PackedStringArray()
		var raw_tabs: Variant = d.get("tabs", [])
		if typeof(raw_tabs) == TYPE_ARRAY:
			for item: Variant in raw_tabs:
				if typeof(item) == TYPE_STRING and not String(item).is_empty() and not (String(item) in tabs):
					tabs.append(String(item))
		if tabs.is_empty():
			return {}
		return new_node_group(tabs, String(d.get("active", "")))
	return {}


func _strip(n: Dictionary) -> Dictionary:
	if n.is_empty():
		return {"t": "g", "tabs": [], "active": ""}
	if String(n["t"]) == "s":
		return {"t": "s", "dir": String(n["dir"]), "ratio": snappedf(float(n["ratio"]), 0.001), "a": _strip(n["a"]), "b": _strip(n["b"])}
	return {"t": "g", "tabs": (n["tabs"] as Array).duplicate(), "active": String(n["active"])}


func tree() -> Dictionary:
	return _strip(_tree)


func load_tree(raw: Dictionary) -> void:
	_tree = _normalise(raw)
	if _tree.is_empty():
		_tree = new_node_group(PackedStringArray(), "")
	maximised_id = ""
	_rebuild()
	if focused_id.is_empty() or not is_shown(focused_id):
		var first: PackedStringArray = visible_ids()
		if first.size() > 0:
			focus_panel(first[0])


func _walk(n: Dictionary, out: Array[Dictionary]) -> void:
	if n.is_empty():
		return
	out.append(n)
	if String(n["t"]) == "s":
		_walk(n["a"], out)
		_walk(n["b"], out)


func groups() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	_walk(_tree, all)
	var out: Array[Dictionary] = []
	for n: Dictionary in all:
		if String(n["t"]) == "g":
			out.append(n)
	return out


func group_of(id: String) -> Dictionary:
	for g: Dictionary in groups():
		if id in (g["tabs"] as Array):
			return g
	return {}


func _node_by_uid(uid: int) -> Dictionary:
	var all: Array[Dictionary] = []
	_walk(_tree, all)
	for n: Dictionary in all:
		if int(n["uid"]) == uid:
			return n
	return {}


func _parent_of(uid: int) -> Dictionary:
	var all: Array[Dictionary] = []
	_walk(_tree, all)
	for n: Dictionary in all:
		if String(n["t"]) != "s":
			continue
		if int((n["a"] as Dictionary)["uid"]) == uid or int((n["b"] as Dictionary)["uid"]) == uid:
			return n
	return {}


func _replace_node(old_uid: int, fresh: Dictionary) -> void:
	if int(_tree["uid"]) == old_uid:
		_tree = fresh
		return
	var parent: Dictionary = _parent_of(old_uid)
	if parent.is_empty():
		return
	if int((parent["a"] as Dictionary)["uid"]) == old_uid:
		parent["a"] = fresh
	else:
		parent["b"] = fresh


func all_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for g: Dictionary in groups():
		for t: Variant in (g["tabs"] as Array):
			out.append(String(t))
	return out


func visible_ids() -> PackedStringArray:
	var out := PackedStringArray()
	if not maximised_id.is_empty():
		out.append(maximised_id)
		return out
	for g: Dictionary in groups():
		var act: String = String(g["active"])
		if not act.is_empty():
			out.append(act)
	for id: String in _floats.keys():
		out.append(id)
	return out


func is_shown(id: String) -> bool:
	return id in visible_ids()


func is_docked(id: String) -> bool:
	return not group_of(id).is_empty()


func is_floating(id: String) -> bool:
	return _floats.has(id)


func panel_title(id: String) -> String:
	var impl: Object = Host.get_impl("IPanel", id)
	if impl != null and impl.has_method("title"):
		return String(impl.call("title"))
	return id.capitalize()


func panel_impl(id: String) -> Object:
	var impl: Object = Host.get_impl("IPanel", id)
	return impl


func registered_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for e: Dictionary in Host.list("IPanel"):
		out.append(String(e["id"]))
	return out


func _ensure_panel(id: String) -> Control:
	if _panels.has(id):
		var rec: Dictionary = _panels[id]
		var c: Control = rec["control"]
		if is_instance_valid(c):
			return c
		_panels.erase(id)
	var impl: Object = panel_impl(id)
	var control: Control = null
	if impl != null and impl.has_method("build"):
		var t_build: int = Time.get_ticks_usec()
		var built: Variant = impl.call("build", _park)
		if OS.get_environment("PURR_TIME_PANELS") == "1":
			print("panel build %s %.1f ms" % [id, float(Time.get_ticks_usec() - t_build) / 1000.0])
		if built is Control:
			control = built
	if control == null:
		control = load("res://ui/editor/modules_list.gd").call("missing_panel", id)
		_park.add_child(control)
	control.name = "Panel_" + id
	_panels[id] = {"impl": impl, "control": control}
	return control


func _park_control(c: Control) -> void:
	if c == null or not is_instance_valid(c):
		return
	var p: Node = c.get_parent()
	if p == _park:
		return
	if p != null:
		p.remove_child(c)
	_park.add_child(c)


func _park_all() -> void:
	for uid: int in _frames.keys():
		var f: Control = _frames[uid]
		if is_instance_valid(f):
			var c: Control = f.call("release_content")
			_park_control(c)


func _rebuild() -> void:
	_building = true
	_park_all()
	PmUI.clear(_root_holder)
	_frames.clear()
	var node: Dictionary = _tree
	if not maximised_id.is_empty():
		node = {"t": "g", "tabs": [maximised_id], "active": maximised_id, "uid": 0}
	var built: Control = _build_node(node)
	if built != null:
		built.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_root_holder.add_child(built)
	_building = false
	_apply_focus()
	layout_changed.emit()


func _build_node(n: Dictionary) -> Control:
	if n.is_empty():
		return null
	if String(n["t"]) == "s":
		var split: Container = PmSplit.make(String(n["dir"]) == "v", float(n["ratio"]))
		split.connect("ratio_changed", _on_ratio_changed.bind(int(n["uid"])))
		var a: Control = _build_node(n["a"])
		var b: Control = _build_node(n["b"])
		if a != null:
			split.add_child(a)
		if b != null:
			split.add_child(b)
		split.call("move_child", split.get("_handle"), -1)
		return split
	var frame: Control = Frame.new()
	frame.set("uid", int(n["uid"]))
	var entries: Array[Dictionary] = []
	for t: Variant in (n["tabs"] as Array):
		entries.append({"id": String(t), "label": panel_title(String(t))})
	frame.call("set_tabs", entries, String(n["active"]))
	frame.set("locked", locked)
	if locked:
		_lock_tabs(frame.get("tabs"))
	frame.connect("tab_activated", _on_tab_activated)
	frame.connect("tab_close_requested", _on_tab_close_requested)
	frame.connect("tab_dragged_out", _on_tab_dragged_out)
	frame.connect("tab_reordered", _on_tab_reordered)
	frame.connect("menu_action", _on_menu_action)
	frame.connect("panel_dropped", _on_panel_dropped)
	frame.connect("maximise_requested", _on_maximise_requested)
	_frames[int(n["uid"])] = frame
	var active: String = String(n["active"])
	if not active.is_empty():
		var c: Control = _ensure_panel(active)
		frame.call("show_content", c)
		panel_shown.emit(active)
	return frame


func frame_for(id: String) -> Control:
	for uid: int in _frames.keys():
		var f: Control = _frames[uid]
		if is_instance_valid(f) and bool(f.call("has_panel", id)):
			return f
	return null


func frame_at(global: Vector2) -> Control:
	for uid: int in _frames.keys():
		var f: Control = _frames[uid]
		if is_instance_valid(f) and f.is_visible_in_tree() and f.get_global_rect().has_point(global):
			return f
	return null


func panel_at(global: Vector2) -> String:
	var f: Control = frame_at(global)
	if f == null:
		return ""
	return String(f.call("active_id"))


func _apply_focus() -> void:
	for uid: int in _frames.keys():
		var f: Control = _frames[uid]
		if is_instance_valid(f):
			f.set("focused", not focused_id.is_empty() and String(f.call("active_id")) == focused_id)


func focus_panel(id: String) -> void:
	if id.is_empty():
		return
	if focused_id == id:
		_apply_focus()
		return
	var old: String = focused_id
	focused_id = id
	if _panels.has(old):
		var old_impl: Object = (_panels[old] as Dictionary)["impl"]
		if old_impl != null and old_impl.has_method("on_focus"):
			old_impl.call("on_focus", false)
	if _panels.has(id):
		var impl: Object = (_panels[id] as Dictionary)["impl"]
		if impl != null and impl.has_method("on_focus"):
			impl.call("on_focus", true)
	_apply_focus()
	focus_changed.emit(id)


func focused_impl() -> Object:
	if focused_id.is_empty() or not _panels.has(focused_id):
		return null
	return (_panels[focused_id] as Dictionary)["impl"]


func focus_next(step: int) -> void:
	var ids: PackedStringArray = visible_ids()
	if ids.is_empty():
		return
	var i: int = ids.find(focused_id)
	var j: int = wrapi(i + step, 0, ids.size())
	var id: String = ids[j]
	if is_floating(id):
		focus_panel(id)
	else:
		show_panel(id)


func _on_ratio_changed(r: float, uid: int) -> void:
	var n: Dictionary = _node_by_uid(uid)
	if not n.is_empty():
		n["ratio"] = r
		_mark("resized panels")
		layout_changed.emit()


func _on_tab_activated(frame: Control, id: String) -> void:
	var n: Dictionary = _node_by_uid(int(frame.get("uid")))
	var old: String = ""
	if not n.is_empty():
		old = String(n["active"])
		n["active"] = id
	var prev: Control = frame.call("release_content")
	_park_control(prev)
	if not old.is_empty() and old != id:
		panel_hidden.emit(old)
	var c: Control = _ensure_panel(id)
	frame.call("show_content", c)
	panel_shown.emit(id)
	focus_panel(id)
	_mark("")
	layout_changed.emit()


func _on_tab_close_requested(_frame: Control, id: String) -> void:
	close_panel(id)


func _on_tab_reordered(frame: Control, ids: PackedStringArray) -> void:
	if _lock_stops():
		_rebuild.call_deferred()
		return
	var n: Dictionary = _node_by_uid(int(frame.get("uid")))
	if n.is_empty():
		return
	var arr: Array = []
	for id: String in ids:
		arr.append(id)
	n["tabs"] = arr
	_mark("reordered tabs")
	layout_changed.emit()


func _on_maximise_requested(_frame: Control, id: String) -> void:
	toggle_maximise(id)


func _on_menu_action(frame: Control, action: String, id: String) -> void:
	if action == "close":
		close_panel(id)
	elif action == "undock":
		undock(id)
	elif action == "maximise":
		toggle_maximise(id)
	elif action == "close_others":
		if _lock_stops():
			return
		var n: Dictionary = _node_by_uid(int(frame.get("uid")))
		if n.is_empty():
			return
		_mark("closed other tabs")
		for other: Variant in (n["tabs"] as Array).duplicate():
			if String(other) != id:
				remove_tab(String(other))
		_rebuild()
	elif action == "panel_list":
		_open_panel_list(frame)


func _open_panel_list(frame: Control) -> void:
	var PmMenu: GDScript = load("res://ui/kit/pm_menu.gd")
	var items: Array = []
	var shown: PackedStringArray = visible_ids()
	var docked: PackedStringArray = all_ids()
	for id: String in registered_ids():
		items.append(PmMenu.check_item("panel:" + id, panel_title(id), id in shown or id in docked))
	if items.is_empty():
		items.append(PmMenu.item("none", "No panels are installed"))
		items[0]["disabled"] = true
	var anchor: Control = frame.get("tabs")
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_panel_list_picked.bind(int(frame.get("uid"))))


func _on_panel_list_picked(id: String, group_uid: int) -> void:
	if not id.begins_with("panel:"):
		return
	var pid: String = id.substr(6)
	if is_docked(pid) or is_floating(pid):
		show_panel(pid)
	else:
		_mark("opened " + panel_title(pid))
		add_tab(pid, group_uid, -1, true)
		_rebuild()
		focus_panel(pid)


func remove_tab(id: String) -> bool:
	var g: Dictionary = group_of(id)
	if g.is_empty():
		return false
	var tabs: Array = g["tabs"]
	var i: int = tabs.find(id)
	tabs.remove_at(i)
	if String(g["active"]) == id:
		g["active"] = ""
		if not tabs.is_empty():
			g["active"] = String(tabs[clampi(i, 0, tabs.size() - 1)])
	if tabs.is_empty():
		_collapse(g)
	return true


func _collapse(g: Dictionary) -> void:
	var uid: int = int(g["uid"])
	if int(_tree["uid"]) == uid:
		return
	var parent: Dictionary = _parent_of(uid)
	if parent.is_empty():
		return
	var other: Dictionary = parent["b"] if int((parent["a"] as Dictionary)["uid"]) == uid else parent["a"]
	_replace_node(int(parent["uid"]), other)


func add_tab(id: String, group_uid: int, index: int = -1, activate: bool = true) -> bool:
	var g: Dictionary = _node_by_uid(group_uid)
	if g.is_empty() or String(g["t"]) != "g":
		return false
	var current: Dictionary = group_of(id)
	if not current.is_empty() and int(current["uid"]) == group_uid:
		var tabs0: Array = g["tabs"]
		var from: int = tabs0.find(id)
		var to: int = index if index >= 0 else tabs0.size()
		if to > from:
			to -= 1
		tabs0.remove_at(from)
		tabs0.insert(clampi(to, 0, tabs0.size()), id)
		if activate:
			g["active"] = id
		return true
	if _floats.has(id):
		_close_float(id, false)
	remove_tab(id)
	g = _node_by_uid(group_uid)
	if g.is_empty():
		return false
	var tabs: Array = g["tabs"]
	if index < 0 or index > tabs.size():
		tabs.append(id)
	else:
		tabs.insert(index, id)
	if activate or String(g["active"]).is_empty():
		g["active"] = id
	return true


func split_group(group_uid: int, side: String, id: String) -> bool:
	var g: Dictionary = _node_by_uid(group_uid)
	if g.is_empty() or String(g["t"]) != "g":
		return false
	var current: Dictionary = group_of(id)
	if not current.is_empty() and int(current["uid"]) == group_uid and (current["tabs"] as Array).size() == 1:
		return false
	if _floats.has(id):
		_close_float(id, false)
	remove_tab(id)
	g = _node_by_uid(group_uid)
	if g.is_empty():
		return false
	var fresh: Dictionary = new_node_group(PackedStringArray([id]), id)
	var dir: String = "h" if (side == "l" or side == "r") else "v"
	var first: bool = side == "l" or side == "t"
	var split: Dictionary = new_node_split(dir, 0.5, fresh if first else g, g if first else fresh)
	_replace_node(group_uid, split)
	return true


func show_panel(id: String) -> void:
	if _floats.has(id):
		var w: Node = _floats[id]
		if is_instance_valid(w):
			w.call("raise")
		focus_panel(id)
		return
	if not maximised_id.is_empty() and maximised_id != id:
		maximised_id = ""
		_rebuild()
	var g: Dictionary = group_of(id)
	if g.is_empty():
		_mark("opened " + panel_title(id))
		var target: Dictionary = group_of(focused_id)
		if target.is_empty():
			var gs: Array[Dictionary] = groups()
			if gs.is_empty():
				_tree = new_node_group(PackedStringArray([id]), id)
				_rebuild()
				focus_panel(id)
				return
			target = gs[0]
		add_tab(id, int(target["uid"]), -1, true)
		_rebuild()
		focus_panel(id)
		return
	if String(g["active"]) != id:
		var frame: Control = _frames.get(int(g["uid"]), null)
		if frame != null and is_instance_valid(frame):
			(frame.get("tabs") as Control).call("set_active", id, false)
			_on_tab_activated(frame, id)
			return
		g["active"] = id
		_rebuild()
	focus_panel(id)


func toggle_panel(id: String) -> void:
	if is_docked(id) or is_floating(id):
		close_panel(id)
	else:
		show_panel(id)


func close_panel(id: String) -> void:
	var known: bool = _floats.has(id) or is_docked(id)
	if known and _lock_stops():
		return
	if known:
		_mark("closed " + panel_title(id))
		_remember_closed(id)
	if _floats.has(id):
		_close_float(id, true)
		return
	if maximised_id == id:
		maximised_id = ""
	if remove_tab(id):
		var rec: Variant = _panels.get(id, null)
		if rec != null:
			_park_control((rec as Dictionary)["control"])
		panel_hidden.emit(id)
		_rebuild()
		if focused_id == id:
			focused_id = ""
			var ids: PackedStringArray = visible_ids()
			if ids.size() > 0:
				focus_panel(ids[0])


func toggle_maximise(id: String) -> void:
	_mark(("restored " if maximised_id == id else "maximised ") + panel_title(id))
	if maximised_id == id:
		maximised_id = ""
	else:
		if not is_docked(id):
			return
		maximised_id = id
	_rebuild()
	focus_panel(id)


func maximise_under_cursor() -> void:
	var id: String = panel_at(get_global_mouse_position())
	if id.is_empty():
		id = focused_id
	if not id.is_empty():
		toggle_maximise(id)


func undock(id: String, at: Vector2 = Vector2(INF, INF)) -> void:
	if _floats.has(id):
		_move_float(id, at)
		return
	if _lock_stops():
		return
	_mark("floated " + panel_title(id))
	if maximised_id == id:
		maximised_id = ""
	var was: Rect2 = _panel_rect(id)
	remove_tab(id)
	var c: Control = _ensure_panel(id)
	_park_control(c)
	_park.remove_child(c)
	if native_floats():
		_undock_native(id, c, at, was)
		return
	var w: Control = PmWindow.open(self, panel_title(id), c, FLOAT_SIZE, "panel." + id)
	w.call("add_action", "dock", "dock_panel", "Dock panel")
	w.connect("action", _on_float_action.bind(id))
	var closed_cb: Callable = _on_float_closed.bind(id)
	w.set_meta("closed_cb", closed_cb)
	w.connect("closed", closed_cb)
	w.set("close_guard", _float_may_close)
	w.connect("moved", _on_float_moved.bind(id))
	if at.x != INF:
		w.call("place_at", at - Vector2(40.0, 12.0))
	_floats[id] = w
	_rebuild()
	focus_panel(id)


func _on_float_action(action: String, id: String) -> void:
	if action == "dock":
		dock_back(id)


func _close_float(id: String, hide: bool) -> void:
	var w: Variant = _floats.get(id, null)
	_floats.erase(id)
	if w == null or not is_instance_valid(w):
		return
	var win: Node = w
	if win.has_meta("closed_cb"):
		var cb: Callable = win.get_meta("closed_cb")
		if win.is_connected("closed", cb):
			win.disconnect("closed", cb)
	var c: Control = win.call("take_content")
	_park_control(c)
	win.call("close")
	if hide:
		panel_hidden.emit(id)


func _on_float_closed(id: String) -> void:
	if not _restoring and not locked and _floats.has(id):
		_mark("closed " + panel_title(id))
		_remember_closed(id)
	var w: Variant = _floats.get(id, null)
	_floats.erase(id)
	if w != null and is_instance_valid(w):
		var c: Control = (w as Node).call("take_content")
		_park_control(c)
	panel_hidden.emit(id)
	if focused_id == id:
		focused_id = ""
		var ids: PackedStringArray = visible_ids()
		if ids.size() > 0:
			focus_panel(ids[0])
	if locked and not _restoring:
		Events.toast(LOCK_NOTE)
		_refloat.call_deferred(id)


func dock_back(id: String) -> void:
	if not _floats.has(id):
		return
	if _lock_stops():
		return
	_mark("docked " + panel_title(id))
	_close_float(id, false)
	var target: Dictionary = group_of(focused_id)
	if target.is_empty():
		var gs: Array[Dictionary] = groups()
		if gs.is_empty():
			_tree = new_node_group(PackedStringArray([id]), id)
			_rebuild()
			focus_panel(id)
			return
		target = gs[0]
	add_tab(id, int(target["uid"]), -1, true)
	_rebuild()
	focus_panel(id)


func _on_tab_dragged_out(frame: Control, id: String, at: Vector2) -> void:
	if _lock_stops():
		return
	var layer: CanvasLayer = PmDragLayer.find(self)
	if layer == null:
		return
	var ghost: Control = _make_ghost(panel_title(id))
	var uid: int = int(frame.get("uid"))
	layer.call("begin", {"kind": "panel", "id": id, "from": uid}, ghost, Vector2(24.0, 12.0))
	layer.call("update", at)


func _make_ghost(title: String) -> Control:
	var card: PanelContainer = PmUI.panel("bg_panel_high")
	var sb: StyleBoxFlat = card.get_theme_stylebox("panel")
	sb.border_color = Tk.c["accent_dim"]
	sb.set_border_width_all(1)
	var l: Label = PmLabel.tight(title, "text_bright")
	card.add_child(l)
	card.modulate.a = 0.0
	return card


func _on_panel_dropped(frame: Control, payload: Dictionary, zone: String, index: int) -> void:
	if String(payload.get("kind", "")) != "panel":
		return
	var id: String = String(payload.get("id", ""))
	if id.is_empty():
		return
	if _lock_stops():
		return
	_mark("moved " + panel_title(id))
	var uid: int = int(frame.get("uid"))
	if not maximised_id.is_empty():
		maximised_id = ""
	var changed: bool = false
	if zone == "c" or zone == "tabs":
		changed = add_tab(id, uid, index, true)
	else:
		changed = split_group(uid, zone, id)
	if changed:
		_rebuild()
		focus_panel(id)


func _on_dropped_outside(payload: Dictionary, at: Vector2) -> void:
	if String(payload.get("kind", "")) != "panel":
		return
	var id: String = String(payload.get("id", ""))
	if id.is_empty():
		return
	if not is_inside_tree():
		return
	undock(id, at)


func _on_registry_changed(iface: String) -> void:
	if iface != "IPanel" or _building:
		return
	var stale: bool = false
	for id: String in _panels.keys():
		var rec: Dictionary = _panels[id]
		var impl: Object = panel_impl(id)
		if impl != rec["impl"]:
			stale = true
			var c: Control = rec["control"]
			_park_control(c)
			PmUI.free_node(c)
			_panels.erase(id)
	if stale:
		_rebuild()


func shipped_names() -> PackedStringArray:
	return _names_in(SHIPPED_DIR)


static func user_dir() -> String:
	return Io.data_path("layouts") + "/"


func user_names() -> PackedStringArray:
	return _names_in(user_dir())


func _names_in(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.ends_with(".json"):
			out.append(entry.get_basename())
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _read_layout_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func layout_dict() -> Dictionary:
	var floats: Array = []
	for id: String in _floats.keys():
		var w: Node = _floats[id]
		if is_instance_valid(w):
			floats.append(_float_entry(id, w))
	var state: Dictionary = {}
	for id: String in _panels.keys():
		var impl: Object = (_panels[id] as Dictionary)["impl"]
		if impl != null and impl.has_method("save_state"):
			var s: Variant = impl.call("save_state")
			if typeof(s) == TYPE_DICTIONARY and not (s as Dictionary).is_empty():
				state[id] = s
	return {"version": LAYOUT_VERSION, "name": layout_name, "tree": tree(), "floats": floats, "state": state}


func apply_layout_dict(d: Dictionary) -> void:
	_restoring = true
	for id: String in _floats.keys().duplicate():
		_close_float(id, false)
	load_tree(d.get("tree", {}))
	var raw_floats: Variant = d.get("floats", [])
	if typeof(raw_floats) == TYPE_ARRAY:
		for item: Variant in raw_floats:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var fd: Dictionary = item
			var id: String = String(fd.get("id", ""))
			if id.is_empty() or is_docked(id):
				continue
			undock(id)
			_apply_float_entry(id, fd)
	var raw_state: Variant = d.get("state", {})
	if typeof(raw_state) == TYPE_DICTIONARY:
		for id: String in (raw_state as Dictionary).keys():
			if _panels.has(id):
				var impl: Object = (_panels[id] as Dictionary)["impl"]
				if impl != null and impl.has_method("restore_state") and typeof(raw_state[id]) == TYPE_DICTIONARY:
					impl.call("restore_state", raw_state[id])
	_restoring = false
	_reset_baseline()


static func _tree_groups(node: Variant, out: Array) -> void:
	if typeof(node) != TYPE_DICTIONARY:
		return
	var nd: Dictionary = node
	if String(nd.get("t", "")) == "g":
		out.append(nd)
		return
	_tree_groups(nd.get("a", {}), out)
	_tree_groups(nd.get("b", {}), out)


static func _tree_panel_ids(d: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var groups: Array = []
	_tree_groups(d.get("tree", {}), groups)
	for g: Dictionary in groups:
		for t: Variant in g.get("tabs", []):
			out.append(String(t))
	var raw_floats: Variant = d.get("floats", [])
	if typeof(raw_floats) == TYPE_ARRAY:
		for fd: Variant in raw_floats:
			if typeof(fd) == TYPE_DICTIONARY:
				out.append(String((fd as Dictionary).get("id", "")))
	return out


static func merge_new_panels(user: Dictionary, shipped: Dictionary) -> int:
	var have: PackedStringArray = _tree_panel_ids(user)
	var user_groups: Array = []
	_tree_groups(user.get("tree", {}), user_groups)
	if user_groups.is_empty():
		return 0
	var shipped_groups: Array = []
	_tree_groups(shipped.get("tree", {}), shipped_groups)
	var added: int = 0
	var placed: Dictionary = {}
	for sg: Dictionary in shipped_groups:
		var tabs: Array = sg.get("tabs", [])
		for i: int in tabs.size():
			var id: String = String(tabs[i])
			if have.has(id):
				continue
			var best: Dictionary = user_groups[0]
			var best_score: int = -1
			for ug: Dictionary in user_groups:
				var score: int = 0
				for t: Variant in ug.get("tabs", []):
					if tabs.has(String(t)):
						score += 1
				if score > best_score:
					best_score = score
					best = ug
			var dest: Array = best.get("tabs", [])
			var at: int = dest.size()
			for j: int in range(i - 1, -1, -1):
				var prev_index: int = dest.find(String(tabs[j]))
				if prev_index >= 0:
					at = prev_index + 1
					break
			dest.insert(at, id)
			best["tabs"] = dest
			have.append(id)
			placed[id] = best
			added += 1
	for sg2: Dictionary in shipped_groups:
		var want: String = String(sg2.get("active", ""))
		if placed.has(want):
			(placed[want] as Dictionary)["active"] = want
	return added


func load_layout(name: String) -> bool:
	flush_history()
	var d: Dictionary = _read_layout_file(user_dir() + name + ".json")
	var shipped: Dictionary = _read_layout_file(SHIPPED_DIR + name + ".json")
	if shipped.is_empty():
		shipped = (load("res://host/module_extras.gd").call("shared") as Object).call("layout", name)
	if d.is_empty():
		d = shipped
	elif not shipped.is_empty():
		var added: int = merge_new_panels(d, shipped)
		if added > 0:
			print("DockWorkspace: added " + str(added) + " new panel tabs to the saved layout \"" + name + "\"")
	if d.is_empty():
		print("DockWorkspace: no layout named \"" + name + "\"")
		return false
	layout_name = name
	apply_layout_dict(d)
	Prefs.set_value(PREF_WORKSPACE, name)
	layout_loaded.emit(name)
	return true


func load_shipped_layout(name: String) -> bool:
	var d: Dictionary = _read_layout_file(SHIPPED_DIR + name + ".json")
	if d.is_empty():
		return false
	layout_name = name
	apply_layout_dict(d)
	layout_loaded.emit(name)
	return true


func save_layout(name: String = "", label: String = "") -> bool:
	var n: String = name if not name.is_empty() else layout_name
	if n.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(user_dir()))
	var d: Dictionary = layout_dict()
	d["name"] = n
	var path: String = user_dir() + n + ".json"
	if not label.is_empty():
		d["label"] = label
	elif is_own(n):
		var old: Dictionary = _read_layout_file(path)
		if old.has("label"):
			d["label"] = String(old["label"])
	return _write_layout_file(path, d)


func _write_layout_file(path: String, d: Dictionary) -> bool:
	var text: String = JSON.stringify(d, "  ")
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK


func reset_layout(name: String = "") -> bool:
	var n: String = name if not name.is_empty() else layout_name
	if n.is_empty():
		return false
	flush_history()
	var before: Dictionary = _last_snap
	var user_path: String = ProjectSettings.globalize_path(user_dir() + n + ".json")
	if FileAccess.file_exists(user_path):
		DirAccess.remove_absolute(user_path)
	var d: Dictionary = _read_layout_file(SHIPPED_DIR + n + ".json")
	if d.is_empty():
		return false
	layout_name = n
	apply_layout_dict(d)
	_record_after("reset the workspace", before)
	layout_loaded.emit(n)
	return true


func save_current() -> void:
	if not layout_name.is_empty():
		save_layout(layout_name)


var force_in_app: bool = false


func native_floats() -> bool:
	return not force_in_app and DockFloat.supported()


func float_window(id: String) -> Node:
	var w: Variant = _floats.get(id, null)
	if w == null or not is_instance_valid(w):
		return null
	return w


func _home_pos() -> Vector2i:
	var home: Window = get_window() if is_inside_tree() else null
	return home.position if home != null else Vector2i.ZERO


func _panel_rect(id: String) -> Rect2:
	var f: Control = frame_for(id)
	if f == null or not f.is_visible_in_tree() or String(f.call("active_id")) != id:
		return Rect2()
	return Rect2(f.get_screen_position(), f.size)


func _float_start_rect(id: String, at: Vector2, was: Rect2) -> Rect2i:
	var home: Window = get_window()
	var home_pos: Vector2i = _home_pos()
	var screen: int = home.current_screen if home != null else 0
	var saved: Rect2i = DockFloat.saved_rect("panel." + id)
	var fallback: Vector2i = Vector2i(was.size) if was.size.x >= 1.0 else Vector2i(FLOAT_SIZE)
	var r: Rect2i = Rect2i()
	if at.x != INF:
		r = Rect2i(home_pos + Vector2i(at.round()) - Vector2i(40, 12), saved.size if saved.size.x > 0 else fallback)
	elif saved.size.x > 0:
		r = saved
	elif was.size.x >= 1.0:
		r = Rect2i(Vector2i(was.position) + Vector2i(24, 24), Vector2i(was.size))
	else:
		var old: Rect2i = DockFloat.old_rect("panel." + id)
		if old.size.x > 0:
			r = Rect2i(home_pos + old.position, old.size)
		else:
			var hs: Vector2i = home.size if home != null else Vector2i(FLOAT_SIZE) * 2
			r = Rect2i(home_pos + (hs - Vector2i(FLOAT_SIZE)) / 2, Vector2i(FLOAT_SIZE))
	return DockFloat.fit_on_screens(r, screen)


func _undock_native(id: String, c: Control, at: Vector2, was: Rect2) -> void:
	var w: Window = DockFloat.make(panel_title(id), id)
	w.call("set_content", c)
	w.set("key_router", _route_float_key)
	w.set("focus_cb", focus_panel.bind(id))
	w.connect("action", _on_float_action.bind(id))
	var closed_cb: Callable = _on_float_closed.bind(id)
	w.set_meta("closed_cb", closed_cb)
	w.connect("closed", closed_cb)
	w.set("close_guard", _float_may_close)
	w.connect("moved", _on_float_moved.bind(id))
	add_child(w)
	w.call("place", _float_start_rect(id, at, was))
	w.visible = true
	_floats[id] = w
	_rebuild()
	focus_panel(id)


func _move_float(id: String, at: Vector2) -> void:
	var w: Node = float_window(id)
	if w == null or at.x == INF:
		return
	if w is Window:
		w.call("place_at", _home_pos() + Vector2i(at.round()) - Vector2i(40, 12))
	else:
		w.call("place_at", at - Vector2(40.0, 12.0))


func _route_float_key(k: InputEventKey) -> bool:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("route_key"):
			return bool(n.call("route_key", k))
		n = n.get_parent()
	return false


func _float_may_close() -> bool:
	return not _lock_stops()


func _on_float_moved(id: String) -> void:
	if _restoring or layout_name.is_empty() or _last_snap.is_empty() or String(_last_snap.get("ws", "")) != layout_name:
		return
	var w: Variant = _floats.get(id, null)
	if w == null or not is_instance_valid(w):
		return
	var was: Dictionary = {}
	var raw: Variant = _last_snap.get("floats", [])
	if typeof(raw) == TYPE_ARRAY:
		for fd: Variant in (raw as Array):
			if typeof(fd) == TYPE_DICTIONARY and String((fd as Dictionary).get("id", "")) == id:
				was = fd
	if was.is_empty():
		_reset_baseline()
		return
	var now: Dictionary = _float_entry(id, w)
	var shift: float = 0.0
	for k: String in ["x", "y", "w", "h"]:
		shift = maxf(shift, absf(float(now.get(k, 0.0)) - float(was.get(k, 0.0))))
	if shift < FLOAT_MOVE_MIN:
		return
	history().call("push_undo", layout_name, {"kind": "snap", "label": "moved the " + panel_title(id) + " window", "snap": _last_snap})
	_reset_baseline()


func _float_entry(id: String, w: Node) -> Dictionary:
	if w is Window:
		return w.call("layout_entry")
	var c: Control = w
	return {"id": id, "x": c.position.x, "y": c.position.y, "w": c.size.x, "h": c.size.y}


func _apply_float_entry(id: String, fd: Dictionary) -> void:
	var w: Node = float_window(id)
	if w == null or not fd.has("w"):
		return
	if w is Window:
		var p: Vector2i = Vector2i(int(float(fd.get("x", 0.0))), int(float(fd.get("y", 0.0))))
		if not bool(fd.get("native", false)):
			p += _home_pos()
		var r: Rect2i = Rect2i(p, Vector2i(int(float(fd.get("w", FLOAT_SIZE.x))), int(float(fd.get("h", FLOAT_SIZE.y)))))
		var home: Window = get_window()
		w.call("place", DockFloat.fit_on_screens(r, home.current_screen if home != null else 0))
		return
	var c: Control = w
	c.size = Vector2(float(fd.get("w", FLOAT_SIZE.x)), float(fd.get("h", FLOAT_SIZE.y)))
	c.call("place_at", Vector2(float(fd.get("x", 0.0)), float(fd.get("y", 0.0))))


static func history() -> RefCounted:
	if _history == null:
		_history = DockHistory.new()
	return _history


func layout_snap() -> Dictionary:
	var floats: Array = []
	for id: String in _floats.keys():
		var w: Node = _floats[id]
		if is_instance_valid(w):
			floats.append(_float_entry(id, w))
	return {"ws": layout_name, "tree": tree(), "floats": floats, "max": maximised_id, "focus": focused_id}


static func snap_key(s: Dictionary) -> String:
	var ids: Array = []
	var raw: Variant = s.get("floats", [])
	if typeof(raw) == TYPE_ARRAY:
		for fd: Variant in (raw as Array):
			if typeof(fd) == TYPE_DICTIONARY:
				ids.append(String((fd as Dictionary).get("id", "")))
	ids.sort()
	return JSON.stringify({"tree": s.get("tree", {}), "floats": ids, "max": String(s.get("max", ""))}, "", true)


func _mark(label: String) -> void:
	if _restoring:
		return
	if _pending_label.is_empty():
		_pending_label = label
	if not _flush_queued:
		_flush_queued = true
		flush_history.call_deferred()


func flush_history() -> void:
	_flush_queued = false
	var label: String = _pending_label
	_pending_label = ""
	if _restoring or layout_name.is_empty():
		return
	var now: Dictionary = layout_snap()
	var key: String = snap_key(now)
	if key != _last_key and not label.is_empty() and not _last_snap.is_empty() and String(_last_snap.get("ws", "")) == layout_name:
		history().call("push_undo", layout_name, {"kind": "snap", "label": label, "snap": _last_snap})
	_last_snap = now
	_last_key = key


func _reset_baseline() -> void:
	_pending_label = ""
	_last_snap = layout_snap()
	_last_key = snap_key(_last_snap)


func _record_after(label: String, before: Dictionary) -> void:
	var now: Dictionary = layout_snap()
	if not before.is_empty() and String(before.get("ws", "")) == layout_name and snap_key(before) != snap_key(now):
		history().call("push_undo", layout_name, {"kind": "snap", "label": label, "snap": before})
	_reset_baseline()


func _lock_stops() -> bool:
	if not locked or _restoring or _lock_pass:
		return false
	Events.toast(LOCK_NOTE)
	return true


func _lock_tabs(t: Control) -> void:
	if t == null:
		return
	t.set("allow_reorder", false)
	t.set("allow_drag_out", false)
	var list: Array = t.get("tabs")
	for d: Variant in list:
		(d as Dictionary)["closable"] = false
	t.call("_layout")


func set_locked(on: bool) -> void:
	if locked == on:
		return
	locked = on
	if Prefs.is_registered(PREF_LOCK):
		Prefs.set_value(PREF_LOCK, on)
	if not layout_name.is_empty():
		_rebuild()
	lock_changed.emit(on)


func _on_pref_changed(key: String) -> void:
	if key == PREF_LOCK and bool(Prefs.get_value(PREF_LOCK)) != locked:
		set_locked(bool(Prefs.get_value(PREF_LOCK)))


func can_undo_layout() -> bool:
	flush_history()
	return bool(history().call("can_undo", layout_name))


func can_redo_layout() -> bool:
	flush_history()
	return bool(history().call("can_redo", layout_name))


func undo_label() -> String:
	flush_history()
	return String(history().call("undo_label", layout_name))


func redo_label() -> String:
	flush_history()
	return String(history().call("redo_label", layout_name))


func history_labels() -> PackedStringArray:
	flush_history()
	return history().call("labels", layout_name)


func undo_layout() -> String:
	flush_history()
	var ws: String = layout_name
	var e: Dictionary = history().call("pop_undo", ws)
	if e.is_empty():
		return ""
	var label: String = String(e.get("label", ""))
	if String(e.get("kind", "")) == "ws":
		var other: String = String(e.get("other", ""))
		if not _switch_to(other):
			return ""
		history().call("push_redo", other, {"kind": "ws", "label": label, "other": ws})
		return label
	var cur: Dictionary = layout_snap()
	_apply_snap(e.get("snap", {}))
	history().call("push_redo", ws, {"kind": "snap", "label": label, "snap": cur})
	return label


func redo_layout() -> String:
	flush_history()
	var ws: String = layout_name
	var e: Dictionary = history().call("pop_redo", ws)
	if e.is_empty():
		return ""
	var label: String = String(e.get("label", ""))
	if String(e.get("kind", "")) == "ws":
		var other: String = String(e.get("other", ""))
		if not _switch_to(other):
			return ""
		history().call("push_undo", other, {"kind": "ws", "label": label, "other": ws}, false)
		return label
	var cur: Dictionary = layout_snap()
	_apply_snap(e.get("snap", {}))
	history().call("push_undo", ws, {"kind": "snap", "label": label, "snap": cur}, false)
	return label


func go_back(steps: int) -> String:
	var last: String = ""
	for i: int in range(steps):
		var l: String = undo_layout()
		if l.is_empty():
			break
		last = l
	return last


func note_workspace_switch(from: String, to: String, label: String) -> void:
	if from.is_empty() or from == to:
		return
	history().call("push_undo", to, {"kind": "ws", "label": label, "other": from})


func has_layout(name: String) -> bool:
	if name.is_empty():
		return false
	return FileAccess.file_exists(user_dir() + name + ".json") or FileAccess.file_exists(SHIPPED_DIR + name + ".json")


func _switch_to(name: String) -> bool:
	if not has_layout(name):
		return false
	save_current()
	if workspace_switcher.is_valid():
		return bool(workspace_switcher.call(name))
	return load_layout(name)


func _apply_snap(s: Dictionary) -> void:
	if s.is_empty():
		return
	var was: PackedStringArray = all_ids()
	for fid: String in _floats.keys():
		was.append(fid)
	_restoring = true
	var want: Dictionary = {}
	var raw: Variant = s.get("floats", [])
	if typeof(raw) == TYPE_ARRAY:
		for fd: Variant in (raw as Array):
			if typeof(fd) == TYPE_DICTIONARY and not String((fd as Dictionary).get("id", "")).is_empty():
				want[String((fd as Dictionary)["id"])] = fd
	for id: String in _floats.keys().duplicate():
		if not want.has(id):
			_close_float(id, true)
	var tree_d: Variant = s.get("tree", {})
	load_tree(tree_d if typeof(tree_d) == TYPE_DICTIONARY else {})
	for id: String in want.keys():
		if is_docked(id):
			continue
		if not _floats.has(id):
			undock(id)
		_apply_float_entry(id, want[id])
	var mx: String = String(s.get("max", ""))
	if not mx.is_empty() and is_docked(mx):
		maximised_id = mx
		_rebuild()
	var f: String = String(s.get("focus", ""))
	if not f.is_empty() and is_shown(f):
		focus_panel(f)
	_restoring = false
	_reset_baseline()
	for old: String in was:
		if not is_docked(old) and not is_floating(old):
			panel_hidden.emit(old)


func _anchor_title(n: Dictionary) -> String:
	var nodes: Array[Dictionary] = []
	_walk(n, nodes)
	for g: Dictionary in nodes:
		if String(g["t"]) != "g":
			continue
		var act: String = String(g["active"])
		if act.is_empty() and not (g["tabs"] as Array).is_empty():
			act = String((g["tabs"] as Array)[0])
		if not act.is_empty():
			return panel_title(act)
	return ""


func _tabs_under(n: Dictionary) -> Array:
	var out: Array = []
	var nodes: Array[Dictionary] = []
	_walk(n, nodes)
	for g: Dictionary in nodes:
		if String(g["t"]) == "g":
			for t: Variant in (g["tabs"] as Array):
				out.append(String(t))
	return out


func _remember_closed(id: String) -> void:
	var e: Dictionary = {"id": id, "title": panel_title(id), "ws": layout_name, "kind": "dock", "where": ""}
	if _floats.has(id):
		e["kind"] = "float"
		e["where"] = "in its own window"
		history().call("add_closed", e)
		return
	var g: Dictionary = group_of(id)
	if g.is_empty():
		return
	var tabs: Array = g["tabs"]
	var others: Array = []
	for t: Variant in tabs:
		if String(t) != id:
			others.append(String(t))
	e["index"] = tabs.find(id)
	e["with"] = others
	if not others.is_empty():
		e["where"] = "with " + panel_title(String(others[0]))
	else:
		var parent: Dictionary = _parent_of(int(g["uid"]))
		if not parent.is_empty():
			var first: bool = int((parent["a"] as Dictionary)["uid"]) == int(g["uid"])
			var sib: Dictionary = parent["b"] if first else parent["a"]
			var horizontal: bool = String(parent["dir"]) == "h"
			var side: String = ("l" if first else "r") if horizontal else ("t" if first else "b")
			e["side"] = side
			e["ratio"] = float(parent["ratio"])
			e["next_to"] = _tabs_under(sib)
			var anchor: String = _anchor_title(sib)
			if not anchor.is_empty():
				e["where"] = String(SIDE_WORDS[side]) + " " + anchor
	history().call("add_closed", e)


func closed_panels() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list: Array[Dictionary] = history().call("closed_list")
	for c: Dictionary in list:
		var id: String = String(c.get("id", ""))
		if is_docked(id) or is_floating(id):
			continue
		out.append(c)
	return out


func closed_text(c: Dictionary) -> String:
	var out: String = String(c.get("title", c.get("id", "")))
	var where: String = String(c.get("where", ""))
	var ws: String = String(c.get("ws", ""))
	if not where.is_empty():
		out += ", " + where
	if not ws.is_empty() and ws != layout_name:
		out += ", " + workspace_label(ws)
	return out


func reopen_closed(id: String = "") -> String:
	var list: Array[Dictionary] = closed_panels()
	if list.is_empty():
		return ""
	var pid: String = id if not id.is_empty() else String(list[0].get("id", ""))
	var e: Dictionary = history().call("take_closed", pid)
	if e.is_empty():
		return ""
	var title: String = panel_title(pid)
	if is_docked(pid) or is_floating(pid):
		show_panel(pid)
		return title
	_lock_pass = true
	_mark("reopened " + title)
	if String(e.get("kind", "")) == "float":
		undock(pid)
		_lock_pass = false
		return title
	if not maximised_id.is_empty():
		maximised_id = ""
	var placed: bool = false
	var with_raw: Variant = e.get("with", [])
	if typeof(with_raw) == TYPE_ARRAY:
		for n: Variant in (with_raw as Array):
			var g: Dictionary = group_of(String(n))
			if not g.is_empty():
				placed = add_tab(pid, int(g["uid"]), int(e.get("index", -1)), true)
				break
	var near_raw: Variant = e.get("next_to", [])
	if not placed and typeof(near_raw) == TYPE_ARRAY:
		var near: Array = []
		for n2: Variant in (near_raw as Array):
			if is_docked(String(n2)):
				near.append(String(n2))
		if not near.is_empty():
			var node: Dictionary = _common_node(near)
			if not node.is_empty():
				placed = _wrap_node(int(node["uid"]), String(e.get("side", "r")), pid, float(e.get("ratio", 0.5)))
	if placed:
		_rebuild()
		focus_panel(pid)
	else:
		show_panel(pid)
	_lock_pass = false
	return title


func _common_node(ids: Array) -> Dictionary:
	var node: Dictionary = group_of(String(ids[0]))
	while not node.is_empty():
		var have: Array = _tabs_under(node)
		var all_in: bool = true
		for id: Variant in ids:
			if not have.has(String(id)):
				all_in = false
				break
		if all_in:
			return node
		node = _parent_of(int(node["uid"]))
	return {}


func _wrap_node(uid: int, side: String, id: String, ratio: float) -> bool:
	var node: Dictionary = _node_by_uid(uid)
	if node.is_empty():
		return false
	var fresh: Dictionary = new_node_group(PackedStringArray([id]), id)
	var dir: String = "h" if (side == "l" or side == "r") else "v"
	var first: bool = side == "l" or side == "t"
	var split: Dictionary = new_node_split(dir, ratio, fresh if first else node, node if first else fresh)
	_replace_node(uid, split)
	return true


func _refloat(id: String) -> void:
	if not is_inside_tree() or is_docked(id) or _floats.has(id):
		return
	_restoring = true
	undock(id)
	_restoring = false
	_reset_baseline()


func is_own(name: String) -> bool:
	return name.begins_with(OWN_PREFIX)


func own_workspaces() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: String in user_names():
		if is_own(n):
			out.append({"id": n, "label": workspace_label(n)})
	return out


func workspace_label(name: String) -> String:
	var mw: Dictionary = (load("res://host/module_extras.gd").call("shared") as Object).call("workspace", name)
	if not mw.is_empty():
		return String(mw["label"])
	if is_own(name):
		var d: Dictionary = _read_layout_file(user_dir() + name + ".json")
		var l: String = String(d.get("label", ""))
		if not l.is_empty():
			return l
		return name.substr(OWN_PREFIX.length()).capitalize()
	return name.capitalize()


static func slug_for(label: String) -> String:
	var slug: String = ""
	for ch: String in label.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			slug += ch
		elif not slug.ends_with("_"):
			slug += "_"
	slug = slug.trim_prefix("_").trim_suffix("_")
	if slug.is_empty():
		slug = "workspace"
	return slug


func save_as_own(label: String) -> String:
	var clean: String = label.strip_edges()
	if clean.is_empty():
		return ""
	var slug: String = slug_for(clean)
	var id: String = OWN_PREFIX + slug
	var n: int = 2
	while FileAccess.file_exists(user_dir() + id + ".json"):
		id = OWN_PREFIX + slug + "_" + str(n)
		n += 1
	if not save_layout(id, clean):
		return ""
	return id


func rename_own(name: String, label: String) -> bool:
	var clean: String = label.strip_edges()
	if not is_own(name) or clean.is_empty():
		return false
	var path: String = user_dir() + name + ".json"
	var d: Dictionary = _read_layout_file(path)
	if d.is_empty():
		return false
	d["label"] = clean
	return _write_layout_file(path, d)


func delete_own(name: String) -> bool:
	if not is_own(name):
		return false
	var path: String = ProjectSettings.globalize_path(user_dir() + name + ".json")
	if not FileAccess.file_exists(path):
		return false
	if DirAccess.remove_absolute(path) != OK:
		return false
	history().call("forget", name)
	return true


func reset_to_saved() -> bool:
	if layout_name.is_empty():
		return false
	flush_history()
	var d: Dictionary = _read_layout_file(user_dir() + layout_name + ".json")
	if d.is_empty():
		d = _read_layout_file(SHIPPED_DIR + layout_name + ".json")
	if d.is_empty():
		return false
	var before: Dictionary = _last_snap
	apply_layout_dict(d)
	_record_after("reset to the saved layout", before)
	return true

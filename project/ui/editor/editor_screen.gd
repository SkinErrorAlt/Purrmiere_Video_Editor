extends Control

signal quit_requested
signal home_requested
signal new_project_requested
signal open_project_requested

const PmMenuBar := preload("res://ui/editor/menu_bar.gd")
const PmStatusBar := preload("res://ui/editor/status_bar.gd")
const DockWorkspace := preload("res://ui/dock/dock_workspace.gd")
const PmTabs := preload("res://ui/kit/pm_tabs.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmRoom := preload("res://ui/kit/pm_room.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const ModulesList := preload("res://ui/editor/modules_list.gd")
const OWNER := "editor"
const SYSTEMS_PATH := "res://modules/core_panels/systems.gd"
const MODAL_GROUP := "pm_modal"
const WORKSPACES: Array[Dictionary] = [
	{"id": "editing", "label": "Editing"},
	{"id": "assembly", "label": "Assembly"},
	{"id": "effects", "label": "Effects"},
	{"id": "audio", "label": "Audio"},
	{"id": "colour", "label": "Colour"},
	{"id": "animate", "label": "Animate"},
	{"id": "export", "label": "Export"},
	{"id": "organize", "label": "Organize"},
]
const FOCUS_COMMANDS: Dictionary = {
	"window.focus_bin": "bin",
	"window.focus_source": "source",
	"window.focus_timeline": "timeline",
	"window.focus_program": "program",
	"window.focus_effect_controls": "effect_controls",
	"window.focus_audio": "audio",
	"window.focus_effects": "effects",
	"window.focus_media_browser": "bin",
	"window.focus_audio_clip_mixer": "audio",
}

var menu_bar: HBoxContainer = null
var ws_tabs: Control = null
var dock: Control = null
var status: Control = null
var project_name: String = ""
var layout_focus: bool = false
var _col: VBoxContainer = null
var _top: HBoxContainer = null
var _lock_btn: Button = null
var _layout_note: Label = null


func _init() -> void:
	name = "EditorScreen"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = PmUI.fill("bg_app")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_col = PmUI.vbox(0)
	_col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_col)
	var top: HBoxContainer = PmUI.hbox(0)
	top.name = "TopBar"
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	top.gui_input.connect(_on_input)
	top.draw.connect(_draw_top)
	_top = top
	var top_bg: ColorRect = PmUI.fill("bg_shell")
	top_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_bg.show_behind_parent = true
	top.add_child(top_bg)
	menu_bar = PmMenuBar.new()
	menu_bar.set("window_items", _window_items)
	menu_bar.connect("picked", _on_menu_picked)
	top.add_child(menu_bar)
	top.add_child(PmUI.spacer())
	_layout_note = PmLabel.tight("", "accent")
	_layout_note.name = "LayoutUndoNote"
	_layout_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_layout_note.visible = false
	top.add_child(_layout_note)
	_lock_btn = PmButton.make("", "unlock")
	_lock_btn.name = "LayoutLock"
	_lock_btn.set("quiet", true)
	_lock_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lock_btn.pressed.connect(_on_lock_pressed)
	top.add_child(_lock_btn)
	_lock_btn.set("icon_px", 14.0)
	ws_tabs = PmTabs.make(false)
	ws_tabs.set("fit_to_content", true)
	ws_tabs.set("allow_reorder", false)
	for w: Dictionary in WORKSPACES:
		ws_tabs.call("add_tab", String(w["id"]), String(w["label"]), 0)
	ws_tabs.connect("tab_changed", _on_workspace_tab)
	top.add_child(ws_tabs)
	_col.add_child(top)
	dock = DockWorkspace.new()
	dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock.connect("focus_changed", _on_focus_changed)
	dock.connect("layout_changed", _on_layout_changed)
	dock.connect("lock_changed", _on_lock_changed)
	dock.set("workspace_switcher", _switch_quiet)
	_col.add_child(dock)
	status = PmStatusBar.new()
	_col.add_child(status)
	_register_commands()
	_refresh_ws_tabs()
	_sync_lock()
	switch_workspace("editing")


func _exit_tree() -> void:
	Cmd.unregister_owner(OWNER)


func workspace_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for w: Dictionary in WORKSPACES:
		out.append(String(w["id"]))
	for o: Dictionary in _own():
		out.append(String(o["id"]))
	return out


func _own() -> Array[Dictionary]:
	var list: Array[Dictionary] = dock.call("own_workspaces")
	return list


func workspace_label(id: String) -> String:
	for w: Dictionary in WORKSPACES:
		if String(w["id"]) == id:
			return String(w["label"])
	return String(dock.call("workspace_label", id))


func _refresh_ws_tabs() -> void:
	var want: PackedStringArray = PackedStringArray()
	for o: Dictionary in _own():
		var id: String = String(o["id"])
		want.append(id)
		if bool(ws_tabs.call("has_tab", id)):
			ws_tabs.call("set_label", id, String(o["label"]))
		else:
			ws_tabs.call("add_tab", id, String(o["label"]), 0)
	var have: PackedStringArray = ws_tabs.call("ids")
	for id: String in have:
		if bool(dock.call("is_own", id)) and not (id in want):
			ws_tabs.call("remove_tab", id)


func _switch_quiet(name_: String) -> bool:
	return switch_workspace(name_, false)


func switch_workspace(name_: String, record: bool = true) -> bool:
	if dock.get("layout_name") == name_:
		return true
	var from: String = String(dock.get("layout_name"))
	var had_layout: bool = not from.is_empty()
	var veil: Control = null
	if had_layout:
		veil = PmRoom.leave(dock, PmUI.overlay_for(self))
	if not bool(dock.call("load_layout", name_)):
		if veil != null:
			veil.queue_free()
		if name_ != "editing":
			return switch_workspace("editing", record)
		return false
	if veil != null:
		PmRoom.enter(dock)
	if record and had_layout:
		dock.call("note_workspace_switch", from, name_, "switched to " + workspace_label(name_))
	if not bool(ws_tabs.call("has_tab", name_)):
		_refresh_ws_tabs()
	ws_tabs.call("set_active", name_, false)
	status.call("set_hint", "Workspace: " + workspace_label(name_))
	return true


func _on_workspace_tab(id: String) -> void:
	dock.call("save_current")
	switch_workspace(id)


func _on_focus_changed(id: String) -> void:
	status.call("set_hint", dock.call("panel_title", id))
	if not bool(dock.get("_restoring")):
		set_layout_focus(false)


func _on_layout_changed() -> void:
	pass


func _window_items() -> Array:
	var out: Array = []
	var current: String = String(dock.get("layout_name"))
	for w: Dictionary in WORKSPACES:
		var id: String = String(w["id"])
		out.append(PmMenu.check_item("workspace:" + id, String(w["label"]), id == current))
	for o: Dictionary in _own():
		var oid: String = String(o["id"])
		out.append(PmMenu.check_item("workspace:" + oid, String(o["label"]), oid == current))
	out.append(PmMenu.separator())
	out.append(PmMenu.item("workspace:save", "Save workspace layout"))
	out.append(menu_bar.call("command_item", "window.workspace_save_as"))
	out.append(menu_bar.call("command_item", "window.workspace_rename"))
	out.append(menu_bar.call("command_item", "window.workspace_delete"))
	out.append(menu_bar.call("command_item", "window.workspace_reset_saved"))
	out.append(menu_bar.call("command_item", "window.workspace_reset"))
	out.append(PmMenu.separator())
	out.append_array(layout_items())
	out.append(PmMenu.separator())
	var shown: PackedStringArray = dock.call("visible_ids")
	var docked: PackedStringArray = dock.call("all_ids")
	var ids: PackedStringArray = dock.call("registered_ids")
	if ids.is_empty():
		var none: Dictionary = PmMenu.item("panel:none", "No panels are installed")
		none["disabled"] = true
		out.append(none)
	for id: String in ids:
		out.append(PmMenu.check_item("panel:" + id, String(dock.call("panel_title", id)), id in shown or id in docked))
	out.append(PmMenu.separator())
	out.append(menu_bar.call("command_item", "window.maximize_active"))
	out.append(menu_bar.call("command_item", "window.next_panel"))
	out.append(menu_bar.call("command_item", "window.prev_panel"))
	return out


func layout_items() -> Array:
	var out: Array = []
	var undo_it: Dictionary = menu_bar.call("command_item", "window.layout_undo")
	var ul: String = String(dock.call("undo_label"))
	undo_it["disabled"] = ul.is_empty()
	if not ul.is_empty():
		undo_it["label"] = Cmd.label("window.layout_undo") + " (" + ul + ")"
	out.append(undo_it)
	var redo_it: Dictionary = menu_bar.call("command_item", "window.layout_redo")
	var rl: String = String(dock.call("redo_label"))
	redo_it["disabled"] = rl.is_empty()
	if not rl.is_empty():
		redo_it["label"] = Cmd.label("window.layout_redo") + " (" + rl + ")"
	out.append(redo_it)
	out.append(PmMenu.sub_item("layout_back", "Layout history", _history_sub()))
	out.append(PmMenu.sub_item("reopen", "Reopen closed panel", _reopen_sub()))
	out.append(menu_bar.call("command_item", "window.layout_lock"))
	return out


static func _sentence(text: String) -> String:
	if text.is_empty():
		return text
	return text.substr(0, 1).to_upper() + text.substr(1)


func _history_sub() -> Array:
	var sub: Array = []
	var labels: PackedStringArray = dock.call("history_labels")
	var head: Dictionary = PmMenu.item("layout_back:none", "No layout changes yet" if labels.is_empty() else "Pick a change to go back to before it")
	head["disabled"] = true
	sub.append(head)
	for i: int in range(labels.size()):
		sub.append(PmMenu.item("layout_back:" + str(i + 1), _sentence(labels[i])))
	return sub


func _reopen_sub() -> Array:
	var sub: Array = []
	var list: Array[Dictionary] = dock.call("closed_panels")
	if list.is_empty():
		var none: Dictionary = PmMenu.item("reopen:none", "No closed panels")
		none["disabled"] = true
		sub.append(none)
		return sub
	for i: int in range(list.size()):
		var c: Dictionary = list[i]
		var keys: String = Cmd.keys_text("window.reopen_last_panel") if i == 0 else ""
		sub.append(PmMenu.item("reopen:" + String(c.get("id", "")), String(dock.call("closed_text", c)), keys))
	return sub


func _on_menu_picked(id: String) -> void:
	if id.begins_with("layout_back:"):
		var steps: String = id.substr(12)
		if steps.is_valid_int():
			go_back(int(steps))
		return
	if id.begins_with("reopen:"):
		var pid: String = id.substr(7)
		if pid != "none":
			_reopen(pid)
		return
	if id.begins_with("workspace:"):
		var ws: String = id.substr(10)
		if ws == "save":
			dock.call("save_current")
			Events.toast("Layout saved")
		else:
			dock.call("save_current")
			switch_workspace(ws)
		return
	if id.begins_with("recent:"):
		var path: String = id.substr(7)
		if path != "none":
			var shell: Node = get_tree().root.get_node_or_null("CorePanelsShell")
			if shell != null and shell.has_method("open_project_path"):
				shell.call("open_project_path", path)
			else:
				Events.warn("Cannot open " + path.get_file(), "the shell is not loaded")
		return
	if id.begins_with("panel:"):
		var pid: String = id.substr(6)
		if pid != "none":
			dock.call("toggle_panel", pid)
		return
	if not Cmd.run(id):
		Events.toast(Cmd.label(id) + " is not available yet")


func _cmd(id: String, handler: Callable, scope: String = "global", enabled: Callable = Callable(), toggle: Callable = Callable()) -> void:
	var cat: Dictionary = Cmd.catalogue()
	var label: String = id
	var category: String = "Window"
	if cat.has(id):
		label = String(cat[id]["label"])
		category = String(cat[id]["category"])
	var spec: Dictionary = {"label": label, "category": category, "scope": scope, "handler": handler, "owner": OWNER}
	if enabled.is_valid():
		spec["enabled"] = enabled
	if toggle.is_valid():
		spec["toggle"] = toggle
	Cmd.register(id, spec)


func _register_commands() -> void:
	for i: int in range(WORKSPACES.size()):
		_cmd("window.workspace_" + str(i + 1), _on_cmd_workspace.bind(String(WORKSPACES[i]["id"])))
	_cmd("window.workspace_reset", _on_cmd_workspace_reset)
	_cmd("window.workspace_reset_saved", _on_cmd_reset_saved)
	_cmd("window.workspace_save_as", _on_cmd_save_as)
	_cmd("window.workspace_rename", _on_cmd_rename, "global", _is_own_current)
	_cmd("window.workspace_delete", _on_cmd_delete, "global", _is_own_current)
	_cmd("window.layout_undo", _on_cmd_layout_step.bind(true))
	_cmd("window.layout_redo", _on_cmd_layout_step.bind(false))
	_cmd("window.layout_lock", _on_cmd_lock, "global", Callable(), _is_locked)
	_cmd("window.reopen_last_panel", _reopen.bind(""))
	_cmd("window.maximize_active", _on_cmd_maximise_active)
	_cmd("window.maximize_under_cursor", _on_cmd_maximise_under_cursor)
	_cmd("window.next_panel", _on_cmd_next_panel.bind(1))
	_cmd("window.prev_panel", _on_cmd_next_panel.bind(-1))
	for cid: String in FOCUS_COMMANDS.keys():
		_cmd(cid, _on_cmd_focus.bind(String(FOCUS_COMMANDS[cid])))
	_cmd("view.fullscreen", _on_cmd_fullscreen)
	_cmd("edit.preferences", _on_cmd_preferences)
	_cmd("help.catalogue", _on_cmd_help)
	_cmd("help.about", _on_cmd_about)
	_cmd("help.stats", _on_cmd_stats)
	_cmd("file.quit", _on_cmd_quit)
	_cmd("file.new_project", _on_cmd_new_project)
	_cmd("file.open", _on_cmd_open_project)
	_cmd("file.close", _on_cmd_close_project)
	_cmd("file.export", _on_cmd_focus.bind("export"))
	_register_system_commands()


func _register_system_commands() -> void:
	if not ResourceLoader.exists(SYSTEMS_PATH):
		return
	var systems: Variant = load(SYSTEMS_PATH)
	if systems is GDScript and (systems as GDScript).can_instantiate():
		(systems as GDScript).call("register_all", OWNER)


static func modal_open() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	return (loop as SceneTree).get_first_node_in_group(MODAL_GROUP) != null


func _on_cmd_workspace(id: String) -> void:
	dock.call("save_current")
	switch_workspace(id)


func _on_cmd_workspace_reset() -> void:
	var name_: String = String(dock.get("layout_name"))
	if name_.is_empty():
		name_ = "editing"
	if bool(dock.call("is_own", name_)):
		dock.call("reset_to_saved")
		Events.toast("Workspace reset to its saved layout")
		return
	dock.call("reset_layout", name_)
	Events.toast("Workspace reset")


func _on_cmd_reset_saved() -> void:
	if bool(dock.call("reset_to_saved")):
		Events.toast("Workspace reset to its saved layout")


func _is_own_current() -> bool:
	return bool(dock.call("is_own", String(dock.get("layout_name"))))


func _is_locked() -> bool:
	return bool(dock.get("locked"))


func _on_cmd_lock() -> void:
	var on: bool = not _is_locked()
	dock.call("set_locked", on)
	Events.toast("Layout locked: panels cannot be moved or closed" if on else "Layout unlocked")


func _on_lock_pressed() -> void:
	_on_cmd_lock()


func _on_lock_changed(_on: bool) -> void:
	_sync_lock()


func _sync_lock() -> void:
	if _lock_btn == null:
		return
	var on: bool = _is_locked()
	_lock_btn.set("icon_name", "lock" if on else "unlock")
	_lock_btn.set("active", on)
	var tip: String = "The layout is locked, so panels cannot be moved or closed. Click to unlock." if on else "Lock the layout, so panels cannot be moved or closed by accident"
	PmUI.tip(_lock_btn, tip, Cmd.keys_text("window.layout_lock"))


func _on_cmd_layout_step(undo: bool) -> void:
	layout_step(undo)


func layout_step(undo: bool) -> String:
	var l: String = String(dock.call("undo_layout" if undo else "redo_layout"))
	if l.is_empty():
		Events.toast("No layout change to undo" if undo else "No layout change to redo")
		return ""
	Events.toast(("Undid: " if undo else "Redid: ") + l)
	return l


func go_back(steps: int) -> String:
	var l: String = String(dock.call("go_back", steps))
	if not l.is_empty():
		Events.toast("Went back to before: " + l)
	return l


func _reopen(id: String) -> void:
	var t: String = String(dock.call("reopen_closed", id))
	if t.is_empty():
		Events.toast("No closed panel to reopen")
	else:
		Events.toast("Reopened " + t)


func save_as_workspace(label: String) -> String:
	dock.call("save_current")
	var id: String = String(dock.call("save_as_own", label))
	if id.is_empty():
		Events.toast("The workspace could not be saved")
		return ""
	_refresh_ws_tabs()
	switch_workspace(id)
	Events.toast("Saved the new workspace " + label.strip_edges())
	return id


func rename_workspace(id: String, label: String) -> bool:
	if not bool(dock.call("rename_own", id, label)):
		return false
	_refresh_ws_tabs()
	if String(dock.get("layout_name")) == id:
		status.call("set_hint", "Workspace: " + workspace_label(id))
	Events.toast("Renamed the workspace to " + label.strip_edges())
	return true


func delete_workspace(id: String) -> bool:
	if not bool(dock.call("is_own", id)):
		return false
	var label: String = workspace_label(id)
	if String(dock.get("layout_name")) == id:
		switch_workspace("editing", false)
	var ok: bool = bool(dock.call("delete_own", id))
	_refresh_ws_tabs()
	if ok:
		Events.toast("Deleted the workspace " + label)
	return ok


func _on_cmd_save_as() -> void:
	_ask_name("Save as new workspace", "", _save_as_named)


func _save_as_named(label: String) -> void:
	save_as_workspace(label)


func _on_cmd_rename() -> void:
	var id: String = String(dock.get("layout_name"))
	_ask_name("Rename this workspace", workspace_label(id), _rename_named.bind(id))


func _rename_named(label: String, id: String) -> void:
	rename_workspace(id, label)


func _on_cmd_delete() -> void:
	var id: String = String(dock.get("layout_name"))
	if not bool(dock.call("is_own", id)):
		return
	var answered: Signal = PmUI.confirm(self, "Delete this workspace", "Delete the workspace " + workspace_label(id) + "? Its saved layout is removed and this cannot be undone.", "Delete", "Cancel")
	answered.connect(_on_delete_answer.bind(id))


func _on_delete_answer(result: Variant, id: String) -> void:
	if result is bool and bool(result):
		delete_workspace(id)


func _ask_name(title: String, start: String, done: Callable) -> void:
	var fields: Array[Dictionary] = [{"key": "name", "label": "Name", "type": "string", "default": start}]
	var answered: Signal = PmUI.form(self, title, fields, "Save", "Cancel")
	answered.connect(_on_named.bind(done))


func _on_named(result: Variant, done: Callable) -> void:
	if typeof(result) != TYPE_DICTIONARY:
		return
	var n: String = String((result as Dictionary).get("name", "")).strip_edges()
	if not n.is_empty():
		done.call(n)


func _on_cmd_maximise_active() -> void:
	var id: String = String(dock.get("focused_id"))
	if not id.is_empty():
		dock.call("toggle_maximise", id)


func _on_cmd_maximise_under_cursor() -> void:
	dock.call("maximise_under_cursor")


func _on_cmd_next_panel(step: int) -> void:
	dock.call("focus_next", step)


func _on_cmd_focus(id: String) -> void:
	dock.call("show_panel", id)


func _on_cmd_preferences() -> void:
	ModulesList.open_preferences(self, _on_cmd_focus.bind("settings"))


func _on_cmd_fullscreen() -> void:
	var w: Window = get_window()
	if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		w.mode = Window.MODE_MAXIMIZED
	else:
		w.mode = Window.MODE_FULLSCREEN


func _on_cmd_help() -> void:
	dock.call("show_panel", "events")
	Events.info("Help", "The feature catalogue panel arrives with its module. Every command and its keys is listed in Edit, Keyboard shortcuts.")


func _on_cmd_about() -> void:
	Events.info("Purrmiere Video Editor", "Host " + String(Host.get("version")) + ", Godot " + Engine.get_version_info()["string"] + ". Help, Statistics shows your editing time and projects.")


func _on_cmd_stats() -> void:
	load("res://ui/editor/stats_window.gd").call("open", self)


func _on_cmd_quit() -> void:
	quit_requested.emit()


func _on_cmd_new_project() -> void:
	new_project_requested.emit()


func _on_cmd_open_project() -> void:
	open_project_requested.emit()


func _on_cmd_close_project() -> void:
	home_requested.emit()


func route_key(event: InputEventKey) -> bool:
	if not event.pressed or modal_open():
		return false
	if layout_focus and _layout_key(event):
		return true
	var impl: Object = dock.call("focused_impl")
	var scope: String = "global"
	if impl != null:
		if impl.has_method("handle_key") and bool(impl.call("handle_key", event)):
			return true
		if impl.has_method("scope"):
			scope = String(impl.call("scope"))
	if scope != "global" and Cmd.dispatch_key(event, scope):
		return true
	return Cmd.dispatch_key(event, "global")


func _layout_key(event: InputEventKey) -> bool:
	var key: String = Cmd.key_string(event)
	if key.is_empty():
		return false
	if key in Cmd.keys_for("edit.undo"):
		layout_step(true)
		return true
	if key in Cmd.keys_for("edit.redo"):
		layout_step(false)
		return true
	if key == "Escape":
		set_layout_focus(false)
		return true
	return false


func set_layout_focus(on: bool) -> void:
	if layout_focus == on:
		return
	layout_focus = on
	if _layout_note != null:
		_layout_note.text = Cmd.keys_text("edit.undo") + " undoes layout changes"
		_layout_note.visible = on
	if _top != null:
		_top.queue_redraw()


func _on_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.gui_release_focus()
	set_layout_focus(true)
	_top.accept_event()


func _input(event: InputEvent) -> void:
	if not layout_focus or not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.pressed and dock.call("frame_at", mb.position) != null:
		set_layout_focus(false)


func _draw_top() -> void:
	if not layout_focus or _top == null:
		return
	var r: Rect2 = Rect2(Vector2.ZERO, _top.size)
	_top.draw_rect(r, Tk.c["selection_fill"], true)
	var line: float = maxf(1.0, float(Tk.px(2.0)))
	_top.draw_rect(Rect2(0.0, r.size.y - line, r.size.x, line), Tk.c["accent"], true)


func _shortcut_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if modal_open():
		return
	if k.keycode == KEY_ESCAPE and k.pressed:
		var owner: Control = get_viewport().gui_get_focus_owner()
		if owner != null:
			owner.release_focus()
			get_viewport().set_input_as_handled()
			return
	if route_key(k):
		get_viewport().set_input_as_handled()


func layout_dump() -> String:
	var LayoutDump: GDScript = load("res://tools/layout_dump.gd")
	return String(LayoutDump.call("dump", self))

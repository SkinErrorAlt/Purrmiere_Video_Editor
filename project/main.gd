extends Control

const PmTheme := preload("res://ui/kit/pm_theme.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmRoom := preload("res://ui/kit/pm_room.gd")
const PmTyping := preload("res://ui/kit/pm_typing.gd")
const EditorScreen := preload("res://ui/editor/editor_screen.gd")
const HomeScreen := preload("res://ui/editor/home_screen.gd")
const HARNESS_PATH := "res://tools/harness.gd"
const SHOT_PATH := "res://tools/shot.gd"
const DUMP_PATH := "res://tools/layout_dump.gd"
const FRAME_CAP_PATH := "res://host/frame_cap.gd"
const EAR_SAFETY_PATH := "res://engine/ear_safety.gd"
const SCRIPT_WARM_PATH := "res://host/script_warm.gd"
const FLAGS_WITH_VALUE: PackedStringArray = ["--shot", "--route", "--project", "--theme", "--probe-import"]
const FLAGS_BARE: PackedStringArray = ["--layout-dump", "--no-modules", "--headless-tests"]

var args: Dictionary = {}
var overlay: Control = null
var editor: Control = null
var home: Control = null
var project_name: String = ""
var _frame_cap: GDScript = null


static func parse_args(list: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var i: int = 0
	while i < list.size():
		var a: String = list[i]
		var matched: bool = false
		for f: String in FLAGS_WITH_VALUE:
			if a == f and i + 1 < list.size():
				out[f.substr(2)] = list[i + 1]
				i += 2
				matched = true
				break
			if a.begins_with(f + "="):
				out[f.substr(2)] = a.substr(f.length() + 1)
				i += 1
				matched = true
				break
		if matched:
			continue
		if a in FLAGS_BARE:
			out[a.substr(2)] = true
		i += 1
	return out


func _ready() -> void:
	name = "Main"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var all_args: PackedStringArray = OS.get_cmdline_args()
	all_args.append_array(OS.get_cmdline_user_args())
	args = parse_args(all_args)
	theme = PmTheme.build()
	Tk.tokens_changed.connect(_on_tokens_changed)
	Tk.theme_changed.connect(_on_theme_changed)
	if args.has("headless-tests"):
		call_deferred("_run_headless_tests")
		return
	PmTyping.watch_tree(get_tree())
	_frame_cap = load(FRAME_CAP_PATH)
	_frame_cap.call("watch")
	load(EAR_SAFETY_PATH).call("ensure")
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_to_group(PmUI.OVERLAY_GROUP)
	add_child(overlay)
	Host.load_modules()
	if args.has("theme"):
		Tk.set_theme(String(args["theme"]))
	var straight_in: bool = (args.has("route") and String(args["route"]) != "home") or args.has("layout-dump") or args.has("project") or (args.has("shot") and not args.has("route"))
	if args.has("route") and String(args["route"]) == "home":
		show_home()
		if args.has("shot"):
			call_deferred("_take_shot", String(args["shot"]))
	elif straight_in:
		show_editor(String(args.get("project", "")))
		if args.has("route"):
			call_deferred("_apply_route", String(args["route"]))
		if args.has("shot"):
			call_deferred("_take_shot", String(args["shot"]))
		if args.has("layout-dump"):
			call_deferred("_dump_layout")
		if args.has("probe-import"):
			call_deferred("_probe_import", String(args["probe-import"]))
	else:
		show_home()


func _input(_event: InputEvent) -> void:
	if _frame_cap != null:
		_frame_cap.call("touch")


func _process(_delta: float) -> void:
	if _frame_cap != null:
		_frame_cap.call("tick", bool(Session.playing))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and not args.has("headless-tests"):
		load(FRAME_CAP_PATH).call("apply")


func _on_tokens_changed() -> void:
	theme = PmTheme.build()


func _on_theme_changed() -> void:
	if editor != null and is_instance_valid(editor):
		(editor.get("dock") as Control).call("save_current")
		show_editor(project_name)
	elif home != null and is_instance_valid(home):
		show_home()


func _clear_screens() -> void:
	if editor != null and is_instance_valid(editor):
		PmUI.free_node(editor)
	if home != null and is_instance_valid(home):
		PmUI.free_node(home)
	editor = null
	home = null


func _leave_screen() -> Control:
	var current: Control = editor if editor != null else home
	if current == null or not is_instance_valid(current) or overlay == null:
		return null
	return PmRoom.leave(current, overlay)


func _enter_screen(screen: Control, veil: Control) -> void:
	if veil == null:
		return
	screen.modulate.a = 0.0
	(func() -> void: PmRoom.enter(screen)).call_deferred()


func show_home() -> void:
	var veil: Control = _leave_screen()
	_clear_screens()
	home = HomeScreen.new()
	home.connect("new_project", _on_new_project)
	home.connect("open_project", _on_open_project)
	add_child(home)
	move_child(overlay, get_child_count() - 1)
	_enter_screen(home, veil)
	load(SCRIPT_WARM_PATH).call("start")


func show_editor(project_label: String) -> void:
	var veil: Control = _leave_screen()
	_clear_screens()
	project_name = project_label
	editor = EditorScreen.new()
	editor.set("project_name", project_label)
	editor.connect("quit_requested", _on_quit)
	editor.connect("home_requested", show_home)
	editor.connect("new_project_requested", _on_new_from_editor)
	editor.connect("open_project_requested", _on_open_from_editor)
	add_child(editor)
	if get_node_or_null("ScriptWarmer") == null:
		add_child(load("res://host/script_warmer.gd").new())
	if get_node_or_null("EditClock") == null:
		add_child(load("res://host/edit_clock.gd").new())
	if get_node_or_null("SpeedFollow") == null:
		add_child(load("res://host/speed_follow.gd").new())
	move_child(overlay, get_child_count() - 1)
	_enter_screen(editor, veil)
	if not project_label.is_empty():
		(editor.get("status") as Control).call("set_tool", String(load("res://ui/editor/status_bar.gd").call("tool_name", Session.tool_id)), project_label)


func _on_new_project(spec: Dictionary) -> void:
	var label: String = String(spec.get("name", "Untitled"))
	Events.info("New project", label + ", " + str(int(spec.get("width", 0))) + " x " + str(int(spec.get("height", 0))) + " at " + str(float(spec.get("fps", 0.0))) + " fps. The document model wires in when doc/ lands.")
	show_editor(label)


func _on_open_project(path: String) -> void:
	HomeScreen.remember(path)
	Events.info("Open project", path + ". The document model wires in when doc/ lands.")
	show_editor(path.get_file().get_basename())


func _on_new_from_editor() -> void:
	var answered: Signal = PmUI.form(self, "New project", HomeScreen.form_fields(), "Create", "Cancel")
	answered.connect(_on_editor_form)


func _on_editor_form(result: Variant) -> void:
	if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
		return
	_on_new_project(HomeScreen.spec_from_answer(result))


func _on_open_from_editor() -> void:
	show_home()
	home.call("_on_open")


func _on_quit() -> void:
	get_tree().quit()


func _apply_route(route: String) -> void:
	if editor == null:
		return
	var dock: Control = editor.get("dock")
	if route in (editor.call("workspace_ids") as PackedStringArray):
		editor.call("switch_workspace", route)
		return
	dock.call("show_panel", route)
	dock.call("toggle_maximise", route)


func _take_shot(path: String) -> void:
	var Shot: GDScript = load(SHOT_PATH)
	Shot.call("capture", self, path)


func _dump_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var Dump: GDScript = load(DUMP_PATH)
	print(String(Dump.call("dump", self)))
	get_tree().quit()


func _probe_import(path: String) -> void:
	var Probe: GDScript = load("res://tools/import_probe.gd")
	var node: Node = Probe.new()
	node.set("path", path)
	add_child(node)


func _run_headless_tests() -> void:
	var Harness: GDScript = load(HARNESS_PATH)
	var code: int = int(Harness.call("run_all", OS.get_cmdline_user_args()))
	get_tree().quit(code)

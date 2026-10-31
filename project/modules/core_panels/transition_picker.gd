extends RefCounted

const Sheet := preload("res://modules/core_panels/sheet.gd")
const Tiles := preload("res://modules/core_panels/transition_tiles.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const TransitionRegistry := preload("res://engine/transition_registry.gd")
const SELF_PATH := "res://modules/core_panels/transition_picker.gd"
const WIDTH := 780.0
const HEIGHT := 600.0
const LIST_H := 450.0

static var last_sheet: Control = null
static var last_state: Dictionary = {}


static func sections(text: String) -> Array[Dictionary]:
	var reg: RefCounted = TransitionRegistry.shared()
	var out: Array[Dictionary] = []
	for g: String in reg.call("groups"):
		var defs: Array[Dictionary] = []
		for d: Dictionary in reg.call("in_group", g):
			if TransitionRegistry.matches(d, text):
				defs.append(d)
		if not defs.is_empty():
			out.append({"title": g, "defs": defs})
	var classic: Array[Dictionary] = []
	for d2: Dictionary in reg.call("classic_defs"):
		if TransitionRegistry.matches(d2, text):
			classic.append(d2)
	if not classic.is_empty():
		out.append({"title": TransitionRegistry.CLASSIC_GROUP, "defs": classic})
	return out


static func open(host: Node, title: String, current: String, on_pick: Callable) -> Control:
	var sh: Control = Sheet.open(host, title, WIDTH, HEIGHT)
	sh.set("close_on_veil", true)
	var col: VBoxContainer = sh.get("col")
	var search: LineEdit = PmUI.line_edit("Search, for example cube, wipe or keynote")
	search.name = "PickerSearch"
	col.add_child(search)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "PickerScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(float(sh.get("inner_w")), float(Tk.px(LIST_H)))
	var list: VBoxContainer = PmUI.vbox(Tk.px(6.0))
	list.name = "PickerList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	col.add_child(scroll)
	var status: Label = PmLabel.dim("")
	status.name = "PickerStatus"
	col.add_child(status)
	var cancel: Button = sh.call("add_button", "Cancel")
	cancel.pressed.connect(sh.close)
	var state: Dictionary = {"sheet": sh, "list": list, "status": status, "current": current, "pick": on_pick, "first": ""}
	var me: GDScript = load(SELF_PATH)
	search.text_changed.connect(Callable(me, "fill").bind(state))
	search.text_submitted.connect(Callable(me, "_on_submit").bind(state))
	fill("", state)
	search.grab_focus.call_deferred()
	last_sheet = sh
	last_state = state
	return sh


static func fill(text: String, state: Dictionary) -> void:
	var list: VBoxContainer = state["list"]
	PmUI.clear(list)
	var secs: Array[Dictionary] = sections(text)
	var reg: RefCounted = TransitionRegistry.shared()
	var default_id: String = String(reg.call("default_kind"))
	var count: int = 0
	state["first"] = ""
	var shown: PackedStringArray = PackedStringArray()
	for sec: Dictionary in secs:
		var defs: Array = sec["defs"]
		list.add_child(PmLabel.meta(String(sec["title"]) + "  (" + str(defs.size()) + ")", "text_dim"))
		var flow: HFlowContainer = PmUI.flow(Tk.px(6.0), Tk.px(8.0))
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for d: Variant in defs:
			var id: String = String((d as Dictionary)["id"])
			var tile: Control = Tiles.make_tile(d, id == String(state["current"]), id == default_id)
			Tiles.thumb_of(tile).gui_input.connect(Callable(load(SELF_PATH), "_on_tile_input").bind(id, state))
			flow.add_child(tile)
			shown.append(id)
			if String(state["first"]).is_empty():
				state["first"] = id
			count += 1
		list.add_child(flow)
	state["shown"] = shown
	if count == 0:
		list.add_child(PmLabel.dim("No transition matches \"" + text + "\""))
	(state["status"] as Label).text = str(count) + (" transition" if count == 1 else " transitions") + ". Click one to use it, hover to watch it."


static func _on_tile_input(event: InputEvent, id: String, state: Dictionary) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pick(state, id)


static func _on_submit(_text: String, state: Dictionary) -> void:
	var first: String = String(state.get("first", ""))
	if not first.is_empty():
		pick(state, first)


static func pick(state: Dictionary, id: String) -> void:
	var sh: Variant = state.get("sheet", null)
	var cb: Callable = state["pick"]
	if cb.is_valid():
		cb.call(id)
	if sh is Control and is_instance_valid(sh):
		(sh as Control).call("close")

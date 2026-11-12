extends PanelContainer

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmWrapRow := preload("res://ui/kit/pm_wrap_row.gd")
const ObjectMask := preload("res://doc/object_mask.gd")
const ObjectMatte := preload("res://engine/object_matte.gd")
const ObjectFx := preload("res://doc/object_fx.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const SELF_PATH := "res://modules/core_panels/object_bar.gd"
const UI_PATH := "res://modules/core_panels/object_ui.gd"

var state_label: Label = null
var back_button: Button = null
var forward_button: Button = null
var again_button: Button = null
var clear_button: Button = null
var brush_down: Button = null
var brush_up: Button = null
var brush_label: Label = null
var dim_button: Button = null
var kind_button: Button = null
var fx_button: Button = null


static func make() -> Control:
	var bar: Control = (load(SELF_PATH) as GDScript).new()
	bar.name = "ObjectBar"
	return bar


static func ui() -> GDScript:
	return load(UI_PATH)


func _ready() -> void:
	var flow: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	add_child(flow)
	state_label = PmLabel.small("Paint over the thing you want")
	flow.add_child(state_label)
	flow.add_child(PmUI.spacer())
	brush_down = PmButton.ghost("Smaller brush")
	PmUI.tip(brush_down, "Make the brush smaller", "[")
	brush_down.pressed.connect(_on_brush.bind(-1))
	flow.add_child(brush_down)
	brush_label = PmLabel.small("36 px")
	flow.add_child(brush_label)
	brush_up = PmButton.ghost("Bigger brush")
	PmUI.tip(brush_up, "Make the brush bigger", "]")
	brush_up.pressed.connect(_on_brush.bind(1))
	flow.add_child(brush_up)
	dim_button = PmButton.ghost("Dim the rest")
	PmUI.tip(dim_button, "How far the part outside the object is darkened while you work, so you can still see it")
	dim_button.pressed.connect(_on_dim)
	flow.add_child(dim_button)
	kind_button = PmButton.ghost("Brush: Soft")
	PmUI.tip(kind_button, "The kind of brush: hard, soft, square or airbrush", Cmd.keys_text("mask_brush.kind"))
	kind_button.pressed.connect(_on_kind)
	flow.add_child(kind_button)
	back_button = PmButton.ghost("Track back")
	PmUI.tip(back_button, "Track the object backward through the clip from this frame", Cmd.keys_text("object.track_backward"))
	back_button.pressed.connect(_on_track.bind("backward"))
	flow.add_child(back_button)
	forward_button = PmButton.ghost("Track the object")
	PmUI.tip(forward_button, "Track the object forward through the clip from this frame", Cmd.keys_text("object.track_forward"))
	forward_button.pressed.connect(_on_track.bind("forward"))
	flow.add_child(forward_button)
	again_button = PmButton.ghost("Work out again")
	PmUI.tip(again_button, "Work the object out again on this frame from the clicks that made it", Cmd.keys_text("object.again"))
	again_button.pressed.connect(_on_again)
	flow.add_child(again_button)
	fx_button = PmButton.ghost("Hold it as an effect")
	PmUI.tip(fx_button, "Put the Object Select effect on this clip, so the object has a row in Effect Controls and other effects can be pointed at it")
	fx_button.pressed.connect(_on_as_effect)
	flow.add_child(fx_button)
	clear_button = PmButton.ghost("Clear")
	PmUI.tip(clear_button, "Take the object off this clip", Cmd.keys_text("object.clear"))
	clear_button.pressed.connect(_on_clear)
	flow.add_child(clear_button)
	PmWrapRow.adopt(flow, 2, 2)
	visible = String(Session.tool_id) == String(ui().get_script_constant_map()["TOOL_ID"]) or painting()
	_listen()
	sync()


func _listen() -> void:
	if not Session.tool_changed.is_connected(_on_tool):
		Session.tool_changed.connect(_on_tool)
	if not Session.project_changed.is_connected(sync):
		Session.project_changed.connect(sync)


func _enter_tree() -> void:
	if state_label != null:
		_listen()


func _exit_tree() -> void:
	if Session.tool_changed.is_connected(_on_tool):
		Session.tool_changed.disconnect(_on_tool)
	if Session.project_changed.is_connected(sync):
		Session.project_changed.disconnect(sync)


func brush_ui() -> GDScript:
	return load("res://modules/core_panels/mask_brush.gd")


func painting() -> bool:
	return String(Session.tool_id) == String(brush_ui().get_script_constant_map()["TOOL_ID"])


func _on_tool(id: String) -> void:
	visible = id == String(ui().get_script_constant_map()["TOOL_ID"]) or id == String(brush_ui().get_script_constant_map()["TOOL_ID"])
	sync()


func _process(_delta: float) -> void:
	if visible:
		sync()


func clip_now() -> Clip:
	var doc: Project = Session.doc
	var seq: Sequence = Session.seq()
	if doc == null or seq == null:
		return null
	for id: String in seq.selected_clip_ids:
		var picked: Clip = seq.clip_by_id(id)
		if picked != null:
			return picked
	var t: float = Session.playhead()
	for track: Variant in seq.video_tracks:
		for c: Clip in track.clips:
			if t >= c.start and t < c.start + c.duration:
				return c
	return null


func state_text() -> String:
	var me: GDScript = ui()
	if bool(me.call("tracking")):
		return String(me.call("banner_text"))
	var c: Clip = clip_now()
	if c == null:
		return "No clip under the playhead"
	var mask: Dictionary = me.call("mask_on", c)
	if mask.is_empty():
		return "Paint over the thing you want and it works the object out. Shift paints more in, Alt paints a part out, Ctrl+drag boxes it"
	var keys: int = ObjectMask.key_frames(mask).size()
	var tracked: int = int(ObjectMatte.frames_of_mask(mask))
	var told: String = str(mask.get("label", "Object")) + ": " + str(keys) + (" frame picked" if keys == 1 else " frames picked")
	if tracked > 0:
		told += ", " + str(tracked) + " tracked"
	return told


func sync() -> void:
	if state_label == null:
		return
	var me: GDScript = ui()
	var paint: bool = painting()
	var c: Clip = clip_now()
	var has_object: bool = c != null and not (me.call("mask_on", c) as Dictionary).is_empty()
	var running: bool = bool(me.call("tracking"))
	state_label.text = state_text()
	back_button.disabled = not has_object
	again_button.disabled = not has_object or running
	clear_button.disabled = not has_object or running
	fx_button.disabled = c == null or running or not ObjectFx.entry_of(c).is_empty()
	forward_button.text = "Stop" if running else "Track the object"
	forward_button.disabled = not has_object and not running
	if brush_label != null:
		brush_label.text = str(int(round(float(me.get("brush_px"))))) + " px"
	if dim_button != null:
		dim_button.text = "Dim the rest: " + dim_text()
		dim_button.disabled = running
	if kind_button != null:
		kind_button.text = "Brush: " + String(brush_ui().call("kind_name"))
		kind_button.visible = paint
	back_button.visible = not paint
	forward_button.visible = not paint
	again_button.visible = not paint
	fx_button.visible = not paint
	if paint:
		state_label.text = "Paint the mask on by hand. Alt wipes it off"
		clear_button.disabled = not has_object


func _on_brush(way: int) -> void:
	ui().call("step_brush", way)
	sync()


func _on_kind() -> void:
	brush_ui().call("next_kind")
	sync()


func _on_dim() -> void:
	var steps: PackedFloat32Array = PackedFloat32Array([0.0, 0.25, 0.45, 0.7])
	var now: float = float(ui().get("dim_back"))
	var at: int = 0
	for i: int in steps.size():
		if absf(steps[i] - now) < 0.02:
			at = i
			break
	ui().set("dim_back", steps[(at + 1) % steps.size()])
	ui().call("dim_forget")
	sync()


func dim_text() -> String:
	var now: float = float(ui().get("dim_back"))
	if now <= 0.01:
		return "off"
	if now < 0.35:
		return "light"
	if now < 0.6:
		return "medium"
	return "strong"


func _on_track(direction: String) -> void:
	var me: GDScript = ui()
	if bool(me.call("tracking")):
		me.call("stop_track")
		return
	me.call("track", direction, 0)


func _on_again() -> void:
	ui().call("again")


func _on_clear() -> void:
	ui().call("clear_object")


func _on_as_effect() -> void:
	ui().call("hold_as_effect")

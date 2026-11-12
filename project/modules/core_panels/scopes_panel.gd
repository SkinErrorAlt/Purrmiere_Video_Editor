extends "res://modules/core_panels/panel_base.gd"
## Scopes: a waveform (brightness or red, green and blue), the parade, the vectorscope and the histogram of the
## Program monitor's picture, drawn on the GPU and updated each time the picture changes.

const ScopeRenderer := preload("res://modules/core_panels/scopes/scope_renderer.gd")
const ScopeView := preload("res://modules/core_panels/scopes/scope_view.gd")
const DETAIL_LABELS: PackedStringArray = ["Fast", "Balanced", "Fine"]
const MODE_TIPS: Dictionary = {
	"luma": "How bright each part of the picture is, left to right: 0 is black, 100 is white",
	"rgb": "The same, with red, green and blue drawn over each other",
	"parade": "Red, green and blue side by side, to see colour casts and balance",
	"vector": "Colour: how saturated (out from the middle) and which hue (around). The line is where skin sits",
	"histogram": "How much of the picture sits at each brightness, for red, green and blue",
}

var renderer: Node = null
var view: Control = null
var _mode_drop: Button = null
var _hint: Label = null
var _detail: Button = null
var _queued: bool = false
var _source_id: int = 0


func _build(root_: Control) -> void:
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	var modes: Array = []
	for i: int in ScopeRenderer.MODES.size():
		modes.append(PmDrop.choice(ScopeRenderer.MODES[i], ScopeRenderer.MODE_LABELS[i]))
	_mode_drop = PmDrop.make_drop(modes, "luma")
	_mode_drop.name = "Mode"
	_mode_drop.connect("changed", set_mode)
	PmUI.tip(_mode_drop, "Which scope to show")
	head.add_child(_mode_drop)
	_hint = PmLabel.dim(String(MODE_TIPS["luma"]))
	_hint.name = "Hint"
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.clip_text = true
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_hint)
	var choices: Array = []
	for i2: int in DETAIL_LABELS.size():
		choices.append(PmDrop.choice(str(i2), DETAIL_LABELS[i2]))
	_detail = PmDrop.make_drop(choices, "1")
	_detail.name = "Detail"
	_detail.connect("changed", _on_detail)
	PmUI.tip(_detail, "How many points of the picture are read: Fine is sharper, Fast is lighter")
	head.add_child(_detail)
	renderer = ScopeRenderer.new()
	renderer.name = "ScopeRenderer"
	root_.add_child(renderer)
	view = ScopeView.new()
	view.name = "ScopeView"
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(view)
	view.call("attach", renderer)
	_sync_buttons()
	_hook()


func _hook() -> void:
	var comp: Node = Session.compositor
	if comp == null:
		return
	if not comp.is_connected("rendered", _on_rendered):
		comp.connect("rendered", _on_rendered)
	var tex: Texture2D = comp.call("texture")
	renderer.call("set_source", tex)
	_source_id = comp.get_instance_id()
	request()


func _on_compositor() -> void:
	if renderer != null:
		_hook()


func _on_rendered(_t: float) -> void:
	request()


## Draws the scope again once this frame, if the panel can be seen.
func request() -> void:
	if _queued or renderer == null or not _alive():
		return
	_queued = true
	_draw_now.call_deferred()


func _draw_now() -> void:
	_queued = false
	if not _alive() or view == null or not view.is_visible_in_tree():
		return
	var comp: Node = Session.compositor
	if comp != null and comp.get_instance_id() != _source_id:
		_hook()
	renderer.call("render")


func set_mode(m: String) -> void:
	renderer.call("set_mode", m)
	view.call("refresh")
	_sync_buttons()
	request()


func _on_detail(id: String) -> void:
	renderer.call("set_detail", int(id))
	request()


func _sync_buttons() -> void:
	var m: String = String(renderer.get("mode"))
	_mode_drop.call("set_value", m, false)
	_hint.text = String(MODE_TIPS.get(m, ""))
	PmUI.tip(_hint, _hint.text)


func on_focus(has: bool) -> void:
	super.on_focus(has)
	request()


func save_state() -> Dictionary:
	if renderer == null:
		return {}
	return {"mode": String(renderer.get("mode")), "detail": int(renderer.get("detail"))}


func restore_state(d: Dictionary) -> void:
	if renderer == null:
		return
	renderer.call("set_mode", String(d.get("mode", "luma")))
	renderer.call("set_detail", int(d.get("detail", 1)))
	_detail.call("set_value", str(int(d.get("detail", 1))), false)
	view.call("refresh")
	_sync_buttons()
	request()

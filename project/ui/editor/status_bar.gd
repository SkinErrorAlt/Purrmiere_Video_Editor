extends Control

const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmIcon := preload("res://ui/kit/pm_icon.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const TOAST_HOLD := 3.0
const TOOL_NAMES: Dictionary = {"select": "Selection", "track_select": "Track Select", "ripple": "Ripple Edit", "roll": "Rolling Edit", "rate": "Rate Stretch", "razor": "Razor", "slip": "Slip", "slide": "Slide", "pen": "Pen", "hand": "Hand", "zoom": "Zoom", "type": "Type", "realign": "Realign", "object_select": "Object Select", "mask_brush": "Mask Brush"}

var _row: HBoxContainer = null
var _tool: Label = null
var _hint: Label = null
var _toast: Label = null
var _jobs: Label = null
var _purr_icon: Control = null
var _purr: Label = null
var _scale: Label = null
var _toast_serial: int = 0
var _pill: PanelContainer = null
var _pill_label: Label = null


func _init() -> void:
	name = "StatusBar"
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, float(Tk.px(Tk.sz("row_h"))) + 2.0)
	_row = PmUI.hbox(Tk.px(Tk.sz("pad")) * 2)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.offset_left = float(Tk.px(Tk.sz("pad")))
	_row.offset_right = -float(Tk.px(Tk.sz("pad")))
	_row.offset_top = 1.0
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_tool = PmLabel.small("Selection")
	_tool.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_tool)
	_hint = PmLabel.dim("")
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_hint)
	_toast = PmLabel.trim("", "text_bright")
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_toast.visible = false
	_row.add_child(_toast)
	var mid: Control = PmUI.spacer()
	_row.add_child(mid)
	_jobs = PmLabel.dim("No jobs")
	_jobs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_jobs)
	_purr_icon = PmIcon.make("warn", 12.0)
	_purr_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_purr_icon)
	_purr = PmLabel.dim("")
	_purr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_purr)
	_scale = PmLabel.dim("")
	_scale.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_scale)
	PmUI.tip(_scale, "UI scale, change it in Settings")
	Events.toasted.connect(_on_toast)
	Jobs.changed.connect(_on_jobs)
	Tk.tokens_changed.connect(_on_tokens)
	Session.tool_changed.connect(_on_tool_changed)
	_on_tool_changed(Session.tool_id)
	_on_jobs()
	_on_tokens()
	_refresh_purr()


func set_tool(name_: String, hint: String = "") -> void:
	_tool.text = name_
	_hint.text = hint


static func tool_name(id: String) -> String:
	if id.is_empty():
		return "Selection"
	return String(TOOL_NAMES.get(id, id.capitalize()))


func _on_tool_changed(id: String) -> void:
	_tool.text = tool_name(id)


func set_hint(hint: String) -> void:
	_hint.text = hint


func _refresh_purr() -> void:
	var ok: bool = bool(PurrBridge.get("available"))
	_purr_icon.visible = not ok
	_purr.text = "purrcore ready" if ok else "purrcore missing"
	if not ok:
		PmUI.tip(_purr, String(PurrBridge.get("reason")))
	else:
		PmUI.tip(_purr, "The native engine loaded")


func _on_jobs() -> void:
	_jobs.text = Jobs.summary()


func _on_tokens() -> void:
	_scale.text = str(int(round(Tk.ui_scale * 100.0))) + "%"
	queue_redraw()


func _ensure_pill() -> bool:
	if _pill != null and is_instance_valid(_pill):
		return true
	var overlay: Node = PmUI.overlay_for(self)
	if overlay == null:
		return false
	_pill = PanelContainer.new()
	_pill.name = "Toast"
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tk.c["bg_panel_alt"]
	sb.border_color = Tk.c["border_soft"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(999)
	sb.anti_aliasing = true
	sb.shadow_color = Tk.c["shadow"]
	sb.shadow_size = Tk.px(10.0)
	sb.shadow_offset = Vector2(0.0, float(Tk.px(3.0)))
	var pad: float = float(Tk.px(Tk.sz("pad")))
	sb.content_margin_left = pad * 2.5
	sb.content_margin_right = pad * 2.5
	sb.content_margin_top = pad * 1.4
	sb.content_margin_bottom = pad * 1.4
	_pill.add_theme_stylebox_override("panel", sb)
	_pill_label = PmLabel.body("", "text_bright")
	_pill_label.add_theme_font_override("font", Tk.font("body_medium"))
	_pill.add_child(_pill_label)
	_pill.visible = false
	overlay.add_child(_pill)
	return true


func _place_pill() -> void:
	if _pill == null:
		return
	var vp: Rect2 = get_viewport_rect()
	var w: float = _pill.get_combined_minimum_size().x
	var h: float = _pill.get_combined_minimum_size().y
	_pill.size = Vector2(w, h)
	_pill.global_position = Vector2((vp.size.x - w) * 0.5, global_position.y - h - float(Tk.px(14.0))).round()
	_pill.pivot_offset = Vector2(w * 0.5, h)


func _on_toast(text: String) -> void:
	_toast_serial += 1
	var serial: int = _toast_serial
	_toast.text = text
	if _ensure_pill():
		_pill_label.text = text
		_pill.visible = true
		_pill.modulate.a = 0.0
		_place_pill()
		PmUI.set_shown(_pill, true, Tk.dur("toast"), float(Tk.px(18.0)))
	else:
		PmUI.set_shown(_toast, true)
	var t: SceneTreeTimer = get_tree().create_timer(TOAST_HOLD)
	t.timeout.connect(_on_toast_timeout.bind(serial))


func _on_toast_timeout(serial: int) -> void:
	if serial != _toast_serial:
		return
	if _pill != null and is_instance_valid(_pill):
		PmUI.set_shown(_pill, false, Tk.dur("toast"))
	PmUI.set_shown(_toast, false)


func _exit_tree() -> void:
	if _pill != null and is_instance_valid(_pill):
		PmUI.free_node(_pill)
	_pill = null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Tk.c["bg_shell"], true)
	draw_rect(Rect2(0.0, 0.0, size.x, 1.0), Tk.c["border"], true)

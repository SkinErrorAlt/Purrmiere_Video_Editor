extends RefCounted

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmTheme := preload("res://ui/kit/pm_theme.gd")
const SELF_PATH := "res://modules/export/export_done_notice.gd"
const GROUP := "pm_export_done"
const MARGIN := 16.0
const CARD_W := 380.0
const MAX_CARDS := 3


static func kind_of(ok: bool, cancelled: bool) -> String:
	if ok:
		return "done"
	if cancelled:
		return "cancelled"
	return "failed"


static func head_of(kind: String, path: String) -> String:
	var file_name: String = path.get_file()
	var lead: String = "Export finished"
	if kind == "cancelled":
		lead = "Export cancelled"
	elif kind == "failed":
		lead = "Export failed"
	if file_name.is_empty():
		return lead
	return lead + ": " + file_name


static func entry(ok: bool, cancelled: bool, path: String, message: String, file_exists: bool) -> Dictionary:
	var kind: String = kind_of(ok, cancelled)
	var bits: PackedStringArray = PackedStringArray()
	if not path.is_empty():
		bits.append(path.get_base_dir())
	if not message.is_empty():
		bits.append(message)
	var actions: Array = []
	if kind == "done" and file_exists:
		actions.append({"id": "open", "label": "Open", "icon": "play", "primary": true, "keep": true})
	if not path.is_empty():
		actions.append({"id": "reveal", "label": "Show in folder", "icon": "folder", "keep": true})
	actions.append({"id": "close", "label": "Close", "icon": "close", "keep": false})
	return {
		"kind": kind,
		"text": head_of(kind, path),
		"detail": "\n".join(bits),
		"path": path,
		"exists": file_exists,
		"actions": actions,
		"sticky": true,
	}


static func action_plan(id: String, path: String, file_exists: bool) -> Dictionary:
	if id == "close":
		return {"what": "close", "target": ""}
	if path.is_empty():
		return {"what": "", "target": ""}
	var full: String = ProjectSettings.globalize_path(path)
	if id == "open":
		if file_exists:
			return {"what": "open", "target": full}
		return {"what": "reveal_dir", "target": full.get_base_dir()}
	if id == "reveal":
		if file_exists:
			return {"what": "reveal", "target": full}
		return {"what": "reveal_dir", "target": full.get_base_dir()}
	return {"what": "", "target": ""}


static func run_plan(plan: Dictionary) -> bool:
	var what: String = String(plan.get("what", ""))
	var target: String = String(plan.get("target", ""))
	if what == "open":
		return OS.shell_open(target) == OK
	if what == "reveal":
		OS.shell_show_in_file_manager(target, true)
		return true
	if what == "reveal_dir":
		return OS.shell_open(target) == OK
	return false


static func host_for(node: Node) -> Control:
	if node == null or not node.is_inside_tree():
		return null
	var found: Node = node.get_tree().get_first_node_in_group(GROUP)
	if found is Control:
		return found as Control
	var overlay: Node = PmUI.overlay_for(node)
	if overlay == null:
		return null
	var host: Control = Holder.new()
	overlay.add_child(host)
	return host


static func post(node: Node, e: Dictionary) -> Control:
	var host: Control = host_for(node)
	if host == null:
		return null
	var stack: Node = host.get_node_or_null("Stack")
	if stack == null:
		return null
	while stack.get_child_count() >= MAX_CARDS:
		PmUI.free_node(stack.get_child(0))
	var card: Control = Card.new()
	stack.add_child(card)
	card.call("setup", e)
	return card


static func show_result(node: Node, ok: bool, cancelled: bool, path: String, message: String) -> Control:
	var exists: bool = not path.is_empty() and FileAccess.file_exists(path)
	return post(node, entry(ok, cancelled, path, message, exists))


class Holder:
	extends Control

	func _init() -> void:
		name = "PmExportDone"
		add_to_group(GROUP)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var stack: VBoxContainer = PmUI.vbox(Tk.px(8.0))
		stack.name = "Stack"
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.alignment = BoxContainer.ALIGNMENT_BEGIN
		stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		stack.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		stack.grow_vertical = Control.GROW_DIRECTION_END
		stack.offset_left = -float(Tk.px(CARD_W)) - MARGIN
		stack.offset_right = -MARGIN
		stack.offset_top = MARGIN
		stack.offset_bottom = MARGIN
		add_child(stack)


class Card:
	extends PanelContainer

	var _entry: Dictionary = {}

	func setup(e: Dictionary) -> void:
		_entry = e
		name = "ExportDoneCard"
		mouse_filter = Control.MOUSE_FILTER_STOP
		var sb := StyleBoxFlat.new()
		sb.bg_color = Tk.c["bg_panel_high"]
		sb.border_color = Tk.c["accent"] if String(e.get("kind", "")) == "done" else Tk.c["border"]
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(Tk.px(Tk.sz("radius_menu")))
		var pad: float = float(Tk.px(Tk.sz("pad")))
		sb.content_margin_left = pad + 4.0
		sb.content_margin_right = pad + 4.0
		sb.content_margin_top = pad
		sb.content_margin_bottom = pad
		add_theme_stylebox_override("panel", PmTheme.shadowed(sb, 1.0))
		custom_minimum_size.x = float(Tk.px(CARD_W))
		var col: VBoxContainer = PmUI.vbox(Tk.px(6.0))
		add_child(col)
		var head: Label = PmLabel.wrap(String(e.get("text", "")), "text_bright")
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(head)
		var detail: String = String(e.get("detail", ""))
		if not detail.is_empty():
			var d: Label = PmLabel.wrap(detail, "text_dim")
			d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(d)
		var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
		row.alignment = BoxContainer.ALIGNMENT_END
		col.add_child(row)
		for a: Variant in (e.get("actions", []) as Array):
			if not (a is Dictionary):
				continue
			var ad: Dictionary = a
			var b: Button = PmButton.make(String(ad.get("label", "")), String(ad.get("icon", "")))
			b.name = "Action_" + String(ad.get("id", ""))
			b.set("quiet", not bool(ad.get("primary", false)))
			b.pressed.connect(press.bind(String(ad.get("id", ""))))
			row.add_child(b)
		modulate.a = 0.0
		if is_inside_tree():
			var tw: Tween = create_tween()
			tw.tween_property(self, "modulate:a", 1.0, maxf(Tk.dur("toast"), 0.01))
		else:
			modulate.a = 1.0

	func press(id: String) -> void:
		var script: GDScript = load(SELF_PATH)
		var path: String = String(_entry.get("path", ""))
		var exists: bool = not path.is_empty() and FileAccess.file_exists(path)
		var plan: Dictionary = script.call("action_plan", id, path, exists)
		script.call("run_plan", plan)
		if not keeps(id):
			dismiss()

	func keeps(id: String) -> bool:
		for a: Variant in (_entry.get("actions", []) as Array):
			if a is Dictionary and String((a as Dictionary).get("id", "")) == id:
				return bool((a as Dictionary).get("keep", false))
		return false

	func dismiss() -> void:
		if not is_inside_tree():
			return
		var parent: Node = get_parent()
		if parent != null:
			parent.remove_child(self)
		queue_free()

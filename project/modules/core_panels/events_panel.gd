extends "res://modules/core_panels/panel_base.gd"

const SYSTEMS_PATH := "res://modules/core_panels/systems.gd"

var _list: VBoxContainer = null
var _scroll: ScrollContainer = null
var _kind_filter: String = ""
var _queued: bool = false


func _build(root_: Control) -> void:
	var col: VBoxContainer = column(root_)
	var head: HBoxContainer = header_row(col)
	head.add_child(PmLabel.tight("Events", "text_bright"))
	var drop: Button = PmDrop.make_drop([PmDrop.choice("all", "Everything"), PmDrop.choice("error", "Errors"), PmDrop.choice("warn", "Warnings"), PmDrop.choice("info", "Info")], "all")
	drop.connect("changed", _on_kind)
	head.add_child(drop)
	head.add_child(PmUI.spacer())
	var clear: Button = quiet_icon("trash", "Clear the log")
	clear.pressed.connect(_on_clear)
	head.add_child(clear)
	_scroll = vscroll_area(col)
	_list = PmUI.vbox(0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	if not Events.added.is_connected(_on_added):
		Events.added.connect(_on_added)
	rebuild()


func _on_kind(id: String) -> void:
	_kind_filter = "" if id == "all" else id
	rebuild()


func _on_clear() -> void:
	Events.clear()
	rebuild()


func _on_added(_e: Dictionary) -> void:
	_queue()


func _queue() -> void:
	if _queued or not _alive():
		return
	_queued = true
	_root.get_tree().process_frame.connect(rebuild, CONNECT_ONE_SHOT)


func rebuild() -> void:
	if not _alive():
		return
	_queued = false
	PmUI.keep_scroll(_list)
	PmUI.clear(_list)
	var entries: Array[Dictionary] = Events.list()
	var shown: int = 0
	for i: int in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		var kind: String = String(e["kind"])
		if kind == "toast":
			continue
		if not _kind_filter.is_empty() and kind != _kind_filter:
			continue
		shown += 1
		var row: HBoxContainer = PmUI.hbox()
		var icon: String = "error" if kind == "error" else ("warn" if kind == "warn" else "more")
		var ic: Control = PmIcon.make(icon, 14.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(ic)
		var body: VBoxContainer = PmUI.vbox(2)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var text: String = String(e["text"])
		var stamp: String = Time.get_time_string_from_unix_time(int(e["t"]))
		body.add_child(PmLabel.trim(stamp + "  " + text, "text_bright" if kind == "error" else "text"))
		var detail: String = String(e["detail"])
		if not detail.is_empty():
			body.add_child(PmLabel.wrap(detail, "text_dim"))
		var fixes: PackedStringArray = e["fixes"]
		if not fixes.is_empty():
			var frow: HBoxContainer = PmUI.hbox()
			for f: String in fixes:
				var b: Button = PmButton.make(fix_label(f))
				b.pressed.connect(_on_fix.bind(f))
				frow.add_child(b)
			body.add_child(frow)
		row.add_child(body)
		_list.add_child(row)
		_list.add_child(PmUI.divider())
		if shown >= 200:
			break
	if shown == 0:
		_list.add_child(PmLabel.dim("Nothing to report"))


static func _systems() -> GDScript:
	var s: Variant = load(SYSTEMS_PATH)
	if s is GDScript and (s as GDScript).can_instantiate():
		return s
	return null


static func fix_label(fix: String) -> String:
	var systems: GDScript = _systems()
	if systems != null and bool(systems.call("is_fix", fix)):
		return String(systems.call("fix_label", fix))
	if fix == "file.relink":
		return "Relink"
	return Cmd.label(fix) if Cmd.has(fix) else fix


func _on_fix(fix: String) -> void:
	var systems: GDScript = _systems()
	if systems != null and bool(systems.call("is_fix", fix)):
		systems.call("run_fix", fix)
		return
	if Cmd.has(fix):
		Cmd.run(fix)
	else:
		Events.toast(fix)

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Puppet := preload("res://doc/puppet.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const SELF_PATH := "res://modules/core_panels/puppet_pin_rows.gd"
const UI_PATH := "res://modules/core_panels/puppet_ui.gd"
const PIN_META := "puppet_pin"
const LIMIT := 100000.0
const SYNC_SECONDS := 0.2
const UNDO_LABEL := "Move pin"
const X_TIP := "Where this pin is across the picture at the playhead, in the picture's own pixels. With Animate pins on, a change writes a key here"
const Y_TIP := "Where this pin is down the picture at the playhead, in the picture's own pixels. With Animate pins on, a change writes a key here"


static func _where() -> Dictionary:
	var loop: MainLoop = Engine.get_main_loop()
	var ses: Node = (loop as SceneTree).root.get_node_or_null("Session") if loop is SceneTree else null
	if ses == null:
		return {}
	var d: Variant = ses.get("doc")
	var s: Variant = ses.call("seq")
	if not (d is Project) or not (s is Sequence):
		return {}
	return {"doc": d, "seq": s}


static func pins_now(c: Clip, e: Dictionary, s: Sequence) -> PackedVector2Array:
	if c == null or e.is_empty():
		return PackedVector2Array()
	return Puppet.keyed_pins_at(c, e, s.playhead if s != null else c.start, s.fps if s != null else 30.0)


static func add(box: VBoxContainer, c: Clip, e: Dictionary, lead: float, label_w: float) -> int:
	var w: Dictionary = _where()
	var s: Sequence = w.get("seq", null)
	var pins: PackedVector2Array = pins_now(c, e, s)
	if pins.is_empty():
		return 0
	var kinds: PackedInt32Array = Puppet.kinds_of(e)
	var fields: Array[Control] = []
	for i: int in pins.size():
		var line: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		line.name = "PinRow" + str(i)
		var gap: Control = Control.new()
		gap.custom_minimum_size = Vector2(lead, 0.0)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(gap)
		var label: Label = PmLabel.trim("Pin " + str(i + 1))
		label.custom_minimum_size = Vector2(label_w, 0.0)
		line.add_child(label)
		var kind: int = kinds[i] if i < kinds.size() else Puppet.KIND_POSITION
		if kind != Puppet.KIND_POSITION and kind < Puppet.KIND_NAMES.size():
			line.add_child(PmLabel.dim(String(Puppet.KIND_NAMES[kind])))
		for axis: int in 2:
			line.add_child(PmLabel.dim("X" if axis == 0 else "Y"))
			var f: Control = PmField.make(pins[i].x if axis == 0 else pins[i].y, -LIMIT, LIMIT, 1.0, " px")
			f.name = "Pin" + str(i) + ("X" if axis == 0 else "Y")
			f.custom_minimum_size = Vector2(float(Tk.px(64.0)), 0.0)
			f.set_meta(PIN_META, Vector2i(i, axis))
			PmUI.tip(f, X_TIP if axis == 0 else Y_TIP)
			f.connect("value_changed", Callable(load(SELF_PATH), "_on_value").bind(c.id, i, axis))
			f.connect("edit_ended", Callable(load(SELF_PATH), "_on_done"))
			line.add_child(f)
			fields.append(f)
		line.add_child(PmUI.spacer())
		box.add_child(line)
	var timer: Timer = Timer.new()
	timer.wait_time = SYNC_SECONDS
	timer.autostart = true
	timer.timeout.connect(Callable(load(SELF_PATH), "sync").bind(c.id, fields))
	box.add_child(timer)
	return pins.size()


static func move_pin(d: Project, s: Sequence, c: Clip, index: int, axis: int, v: float) -> bool:
	var e: Dictionary = Puppet.any_effect_of(c)
	var pins: PackedVector2Array = pins_now(c, e, s)
	if d == null or s == null or index < 0 or index >= pins.size():
		return false
	var at: Vector2 = pins[index]
	if axis == 0:
		at.x = v
	else:
		at.y = v
	var animated: bool = AnimProp.is_animated(c.get_param("effects." + String(e.get("uid", "")) + "." + Puppet.KEY_PINS))
	load(UI_PATH).call("move_pin_live", d, s, c, index, at, s.playhead if animated else -1.0)
	return true


static func _on_value(v: float, clip_id: String, index: int, axis: int) -> void:
	var w: Dictionary = _where()
	if w.is_empty():
		return
	var s: Sequence = w["seq"]
	var c: Clip = s.clip_by_id(clip_id)
	if c != null:
		move_pin(w["doc"], s, c, index, axis, v)


static func _on_done() -> void:
	var w: Dictionary = _where()
	if not w.is_empty():
		(w["doc"] as Project).undo.commit_live(UNDO_LABEL)


static func set_pin(d: Project, s: Sequence, c: Clip, index: int, at: Vector2) -> bool:
	if not move_pin(d, s, c, index, 0, at.x):
		return false
	move_pin(d, s, c, index, 1, at.y)
	d.undo.commit_live(UNDO_LABEL)
	return true


static func sync(clip_id: String, fields: Array[Control]) -> void:
	var w: Dictionary = _where()
	if w.is_empty():
		return
	var s: Sequence = w["seq"]
	var c: Clip = s.clip_by_id(clip_id)
	if c == null:
		return
	var pins: PackedVector2Array = pins_now(c, Puppet.any_effect_of(c), s)
	for f: Control in fields:
		if not is_instance_valid(f) or bool(f.get("_dragging")) or bool(f.get("_pressed")) or f.get("_editor") != null:
			continue
		var which: Vector2i = f.get_meta(PIN_META)
		if which.x >= pins.size():
			continue
		var v: float = pins[which.x].x if which.y == 0 else pins[which.x].y
		if absf(float(f.get("value")) - v) > 0.0001:
			f.set("value", v)

extends RefCounted

const SELF := preload("res://modules/core_panels/many_keys.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PREF := "controls.many_each"
const LABEL := "Each clip keeps its own value"
const TIP := "On: a change moves every selected clip by the same amount, so each keeps its own value and gets its own keyframes, and the Keyframes panel draws a line for each. Off: the value is copied to every clip."
const NUMERIC: PackedStringArray = ["float", "int", "vec2"]
const SKIP_PATHS: PackedStringArray = ["speed", "anim_speed"]

static var _snap: Dictionary = {}
static var plant_copy: bool = false


static func ensure_pref() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs") if loop is SceneTree else null
	if prefs != null and not bool(prefs.call("is_registered", PREF)):
		prefs.call("register", PREF, true, {"label": LABEL, "type": "bool", "hint": TIP})
	return prefs


static func each_on() -> bool:
	if plant_copy:
		return false
	var prefs: Node = ensure_pref()
	return prefs == null or bool(prefs.call("get_value", PREF))


static func set_each(on: bool) -> void:
	var prefs: Node = ensure_pref()
	if prefs != null:
		prefs.call("set_value", PREF, on)


static func applies(spec: Dictionary) -> bool:
	if not spec.has("members") or not bool(spec.get("keyable", false)) or spec.has("special") or spec.has("field"):
		return false
	if not NUMERIC.has(String(spec.get("kind", ""))) or SKIP_PATHS.has(String(spec.get("path", ""))):
		return false
	return each_on()


static func _originals(panel: Object, spec: Dictionary) -> Dictionary:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	var path: String = String(spec.get("path", ""))
	var live: bool = d != null and d.undo.has_live()
	if live and String(_snap.get("path", "")) == path and int(_snap.get("serial", -1)) == d.undo.current_index():
		return _snap["vals"]
	var vals: Dictionary = {}
	var order: PackedStringArray = PackedStringArray()
	var members: Dictionary = spec["members"]
	for cid: Variant in members.keys():
		var c: Clip = s.clip_by_id(String(cid)) if s != null else null
		if c == null:
			continue
		var v: Variant = panel.call("_value_at", c, spec, String(members[cid]))
		vals[String(cid)] = (v as Array).duplicate() if v is Array else v
		order.append(String(cid))
	_snap = {"path": path, "vals": vals, "order": order, "serial": d.undo.current_index() if d != null else -1}
	return vals


static func _lead(vals: Dictionary) -> String:
	var order: PackedStringArray = _snap.get("order", PackedStringArray())
	for cid: String in order:
		if vals.has(cid):
			return cid
	return ""


static func relative(panel: Object, spec: Dictionary, value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not applies(spec) or spec.has("component") or not (value is float or value is int):
		return out
	var vals: Dictionary = _originals(panel, spec)
	var lead: String = _lead(vals)
	if lead.is_empty() or not (vals[lead] is float or vals[lead] is int):
		return out
	var shift: float = float(value) - float(vals[lead])
	for cid: Variant in vals.keys():
		var own: Variant = vals[cid]
		if not (own is float or own is int):
			continue
		var next: float = float(own) + shift
		out[cid] = int(round(next)) if String(spec.get("kind", "")) == "int" else next
	return out


static func components(panel: Object, spec: Dictionary, real: float, idx: int, per: Dictionary) -> Dictionary:
	if not applies(spec) or bool(spec.get("scale_link", false)):
		return per
	var vals: Dictionary = _originals(panel, spec)
	var lead: String = _lead(vals)
	if lead.is_empty() or not (vals[lead] is Array) or (vals[lead] as Array).size() <= idx:
		return per
	var shift: float = real - float((vals[lead] as Array)[idx])
	var out: Dictionary = per.duplicate()
	for cid: Variant in per.keys():
		var own: Variant = vals.get(cid, null)
		if not (own is Array) or (own as Array).size() <= idx:
			continue
		var arr: Array = (per[cid] as Array).duplicate()
		arr[idx] = float((own as Array)[idx]) + shift
		out[cid] = arr
	return out


static func toggle_row(panel: Object) -> Control:
	var row: HBoxContainer = PmUI.hbox(0)
	row.name = "ManyEachRow"
	var box: CheckBox = CheckBox.new()
	box.name = "ManyEach"
	box.text = LABEL
	box.button_pressed = each_on()
	box.tooltip_text = TIP
	box.focus_mode = Control.FOCUS_NONE
	box.toggled.connect(Callable(SELF, "_on_toggled").bind(panel))
	row.add_child(box)
	return row


static func _on_toggled(on: bool, panel: Object) -> void:
	set_each(on)
	_snap = {}
	if panel != null and panel.has_method("refresh_values"):
		panel.call("refresh_values")

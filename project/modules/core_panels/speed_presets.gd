extends RefCounted

const SELF_PATH := "res://modules/core_panels/speed_presets.gd"
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const LENGTH_PATH := "res://doc/speed_length.gd"
const VERBS_PATH := "res://doc/verbs.gd"
const PRESETS: Array[Dictionary] = [
	{"id": "nightcore", "label": "Nightcore", "speed": 1.25},
	{"id": "daycore", "label": "Daycore", "speed": 0.85},
]
const CUSTOM_ID := "custom"
const MIN_PCT := 1.0
const MAX_PCT := 1000.0


static func button(panel: Object) -> Button:
	var b: Button = PmButton.make("Presets")
	b.set("quiet", true)
	PmUI.tip(b, "Nightcore, Daycore or your own speed, with the pitch following the speed. One undo step.")
	b.name = "SpeedPresets"
	var ref: WeakRef = weakref(panel)
	b.pressed.connect(func() -> void: open_menu(b, ref.get_ref()))
	return b


static func menu_items() -> Array:
	var items: Array = []
	for p: Dictionary in PRESETS:
		items.append(PmMenu.item(String(p["id"]), "%s (%s %%)" % [String(p["label"]), String.num(float(p["speed"]) * 100.0, 0)]))
	items.append(PmMenu.separator())
	items.append(PmMenu.item(CUSTOM_ID, "Custom speed..."))
	return items


static func open_menu(anchor: Control, panel: Object) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	var m: Control = PmMenu.open(anchor, menu_items())
	if m != null and m.is_inside_tree():
		m.connect("picked", func(id: String) -> void: picked(id, anchor, panel))


static func speed_of(id: String) -> float:
	for p: Dictionary in PRESETS:
		if String(p["id"]) == id:
			return float(p["speed"])
	return -1.0


static func picked(id: String, anchor: Control, panel: Object) -> void:
	var s: Sequence = _session_seq()
	var ids: PackedStringArray = _targets(panel, s)
	if id == CUSTOM_ID:
		var fields: Array[Dictionary] = [
			{"key": "speed", "label": "Speed (percent)", "type": "float", "default": 100.0},
			{"key": "note", "type": "note", "default": "The pitch follows the speed, like Nightcore and Daycore."},
		]
		var answered: Signal = PmUI.form(anchor, "Custom speed", fields, "Apply", "Cancel")
		answered.connect(func(result: Variant) -> void:
			if typeof(result) != TYPE_DICTIONARY or (result as Dictionary).is_empty():
				return
			apply_now(ids, clampf(absf(float((result as Dictionary).get("speed", 100.0))), MIN_PCT, MAX_PCT) / 100.0))
		return
	var sp: float = speed_of(id)
	if sp > 0.0:
		apply_now(ids, sp)


static func _session() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null("Session")


static func _session_seq() -> Sequence:
	var s: Node = _session()
	return s.call("seq") if s != null else null


static func _targets(panel: Object, s: Sequence) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if panel != null and panel.has_method("target_clip"):
		var c: Clip = panel.call("target_clip")
		if c != null and s != null:
			out = load(VERBS_PATH).call("speed_targets", s, c.id)
	return out


static func apply_now(ids: PackedStringArray, speed: float) -> bool:
	var sn: Node = _session()
	if sn == null:
		return false
	return apply(sn.get("doc"), sn.call("seq"), ids, speed)


static func commands(s: Sequence, ids: PackedStringArray, speed: float) -> Array[Command]:
	var out: Array[Command] = []
	if s == null or ids.is_empty() or speed <= 0.0:
		return out
	out.append_array(load(LENGTH_PATH).call("typed_speed_commands", s, ids, speed))
	var seen: Dictionary = {}
	for id: String in ids:
		var c: Clip = s.clip_by_id(id)
		if c == null:
			continue
		for f: Clip in s.linked(c):
			if seen.has(f.id):
				continue
			seen[f.id] = true
			if AnimProp.is_animated(f.pitch_keep_prop()) or float(AnimProp.static_value(f.pitch_keep_prop())) != 0.0:
				out.append(ClipCmds.SetClipParam.new(s.id, f.id, "audio.pitch_keep", AnimProp.make(0.0)))
	return out


static func apply(doc: Project, s: Sequence, ids: PackedStringArray, speed: float) -> bool:
	if doc == null or s == null:
		return false
	var cmds: Array[Command] = commands(s, ids, speed)
	if cmds.is_empty():
		return false
	var label: String = "Speed %s %%" % String.num(speed * 100.0, 0)
	for p: Dictionary in PRESETS:
		if is_equal_approx(float(p["speed"]), speed):
			label = String(p["label"])
	return bool(load(VERBS_PATH).call("run", doc, label, cmds))

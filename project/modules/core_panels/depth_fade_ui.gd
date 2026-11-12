extends RefCounted

const SELF_PATH := "res://modules/core_panels/depth_fade_ui.gd"
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Command := preload("res://doc/commands/command.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const DepthFade := preload("res://doc/depth_fade.gd")
const DepthFadeEval := preload("res://doc/depth_fade_eval.gd")
const PlaneDepth := preload("res://doc/plane_depth.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const TITLE := "Depth fade"
const SWITCH_TIP := "Changes how strong this effect is with the depth of the tilted picture: full where the picture is near the camera, fading out where it is far. Reverse swaps them. Near and Far are distances from the camera in frame heights."
const NONE_NOTE := "No effect above this one tilts the picture in 3D, so Depth fade does nothing yet. Add Transform (Skew and 3D) above it."
const DEPTH_MAX := 20.0
const SOFT_MAX := 5.0


static func _script() -> GDScript:
	return load(SELF_PATH)


static func source_label(c: Clip, uid: String, registry: Object) -> String:
	var k: int = DepthFade.source_index(c.effects, c.effect_index(uid), registry)
	if k < 0:
		return ""
	var id: String = str((c.effects[k] as Dictionary).get("id", ""))
	var def: Variant = registry.call("get_def", id)
	return String((def as Dictionary).get("label", id)) if def is Dictionary else id


static func note_text(c: Clip, uid: String, registry: Object) -> String:
	var src: String = source_label(c, uid, registry)
	if src.is_empty():
		return NONE_NOTE
	return "Reads the depth of " + src + " above it."


static func key(c: Clip, e: Dictionary) -> String:
	var uid: String = str(e.get("uid", ""))
	return "df:" + str(DepthFade.is_on(e)) + "/" + source_label(c, uid, EffectSource.registry())


static func row(c: Clip, e: Dictionary, label_w: float) -> Control:
	var uid: String = str(e.get("uid", ""))
	var on: bool = DepthFade.is_on(e)
	var box: VBoxContainer = PmUI.vbox()
	box.name = "DepthFade"
	var line: HBoxContainer = PmUI.hbox()
	var l: Label = PmLabel.trim(TITLE)
	l.custom_minimum_size.x = label_w
	line.add_child(l)
	var sw: Button = PmButton.make("On" if on else "Off", "", true)
	sw.name = "DepthFadeSwitch"
	sw.set_meta("uid", uid)
	sw.button_pressed = on
	var note: String = note_text(c, uid, EffectSource.registry())
	PmUI.tip(sw, SWITCH_TIP + " " + note)
	sw.toggled.connect(_script()._on_switch.bind(c.id, uid))
	line.add_child(sw)
	box.add_child(PmUI.inset(line))
	if on:
		var tip: Label = PmLabel.wrap(note, "text_dim")
		tip.name = "DepthFadeSource"
		tip.set_meta("uid", uid)
		box.add_child(PmUI.inset(tip))
	return box


static func specs(e: Dictionary, uid: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DepthFade.is_on(e):
		return out
	out.append(_spec(uid, DepthFade.NEAR, "Near", "float", DEPTH_MAX))
	out.append(_spec(uid, DepthFade.FAR, "Far", "float", DEPTH_MAX))
	out.append(_spec(uid, DepthFade.SOFTNESS, "Softness", "float", SOFT_MAX))
	out.append(_spec(uid, DepthFade.REVERSE, "Reverse", "bool", 1.0))
	return out


static func _spec(uid: String, k: String, label: String, kind: String, top: float) -> Dictionary:
	var spec: Dictionary = {"path": DepthFade.path_of(uid, k), "label": label, "kind": kind, "keyable": true, "fx_uid": uid, "fx_key": DepthFade.KEY + "." + k}
	if kind == "float":
		spec["min"] = 0.0
		spec["max"] = top
		spec["step"] = 0.01
	return spec


static func aspect_of(d: Project, s: Sequence, c: Clip) -> float:
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	if m != null and m.width > 0 and m.height > 0:
		return float(m.width) / float(m.height)
	return float(s.width) / float(maxi(s.height, 1))


static func switch_cmd(s: Sequence, c: Clip, uid: String, on: bool, playhead: float, aspect: float, registry: Object) -> Command:
	var e: Dictionary = c.effect_by_uid(uid)
	if e.is_empty() or DepthFade.is_on(e) == on:
		return null
	var fit: Vector2 = Vector2(DepthFade.DEFAULT_NEAR, DepthFade.DEFAULT_FAR)
	if on and DepthFade.of(e).is_empty():
		var plane: Dictionary = DepthFadeEval.plane_for(c, c.effect_index(uid), registry, playhead - c.start, s.fps)
		if not plane.is_empty():
			var span: Vector2 = PlaneDepth.depth_range(plane, aspect)
			if span.x >= 0.0 and span.y > span.x + 0.001:
				fit = span
	var fields: Dictionary = {DepthFade.KEY: DepthFade.switched(e, on, snappedf(fit.x, 0.01), snappedf(fit.y, 0.01))}
	return EffectCmds.SetEffectEntry.new(s.id, c.id, uid, fields, false, "Depth fade on" if on else "Depth fade off")


static func _session() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("Session") if loop is SceneTree else null


static func _on_switch(on: bool, clip_id: String, uid: String) -> void:
	var host: Node = _session()
	if host == null:
		return
	var d: Project = host.get("doc") as Project
	var s: Sequence = host.call("seq") as Sequence
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null:
		return
	var cmd: Command = switch_cmd(s, c, uid, on, s.playhead, aspect_of(d, s, c), EffectSource.registry())
	if cmd != null:
		Verbs.run(d, cmd.label, [cmd])


## The Depth fade row for several selected clips that share an effect: one switch for all of them. It shows on
## only when every one of them has the fade on.
static func many_row(uids: Dictionary, label_w: float) -> Control:
	var s: Sequence = _session().call("seq") as Sequence if _session() != null else null
	var all_on: bool = s != null and not uids.is_empty()
	for cid: Variant in uids.keys():
		var c: Clip = s.clip_by_id(String(cid)) if s != null else null
		all_on = all_on and c != null and DepthFade.is_on(c.effect_by_uid(String(uids[cid])))
	var box: VBoxContainer = PmUI.vbox()
	box.name = "DepthFade"
	var line: HBoxContainer = PmUI.hbox()
	var l: Label = PmLabel.trim(TITLE)
	l.custom_minimum_size.x = label_w
	line.add_child(l)
	var sw: Button = PmButton.make("On" if all_on else "Off", "", true)
	sw.name = "DepthFadeSwitch"
	sw.button_pressed = all_on
	PmUI.tip(sw, SWITCH_TIP + " For every selected clip with this effect.")
	sw.toggled.connect(_script()._on_switch_many.bind(uids.duplicate()))
	line.add_child(sw)
	box.add_child(PmUI.inset(line))
	return box


static func many_on(uids: Dictionary) -> bool:
	var s: Sequence = _session().call("seq") as Sequence if _session() != null else null
	if s == null or uids.is_empty():
		return false
	for cid: Variant in uids.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null or not DepthFade.is_on(c.effect_by_uid(String(uids[cid]))):
			return false
	return true


## The fade's value rows for several clips, each writing to every member.
static func many_specs(uids: Dictionary, lead_e: Dictionary, lead_uid: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not many_on(uids):
		return out
	for spec: Dictionary in specs(lead_e, lead_uid):
		var k: String = String(spec["fx_key"]).trim_prefix(DepthFade.KEY + ".")
		var members: Dictionary = {}
		for cid: Variant in uids.keys():
			members[String(cid)] = DepthFade.path_of(String(uids[cid]), k)
		var sp: Dictionary = spec.duplicate()
		sp["members"] = members
		out.append(sp)
	return out


static func _on_switch_many(on: bool, uids: Dictionary) -> void:
	var host: Node = _session()
	if host == null:
		return
	var d: Project = host.get("doc") as Project
	var s: Sequence = host.call("seq") as Sequence
	if d == null or s == null:
		return
	var cmds: Array[Command] = []
	for cid: Variant in uids.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var cmd: Command = switch_cmd(s, c, String(uids[cid]), on, s.playhead, aspect_of(d, s, c), EffectSource.registry())
		if cmd != null:
			cmds.append(cmd)
	if not cmds.is_empty():
		Verbs.run(d, "Depth fade on" if on else "Depth fade off", cmds)

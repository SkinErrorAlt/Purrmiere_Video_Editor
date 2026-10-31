extends RefCounted

const Clip := preload("res://doc/clip.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Verbs := preload("res://doc/verbs.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const TransitionRegistry := preload("res://engine/transition_registry.gd")
const Timing := preload("res://doc/transition_timing.gd")
const Ops := preload("res://modules/core_panels/transition_ops.gd")
const SELF_PATH := "res://modules/core_panels/transition_ec_rows.gd"
const SPECIAL := "transition"
const FOLD_KEY := "transition"
const LENGTH_PATH := "transition_length"
const ALIGN_PATH := "transition_align"
const OUT_PREFIX := "transition_out"
const ALIGNS: Array = [["centre", "Centred on the cut", 0.5], ["start", "Starts at the cut", 0.0], ["end", "Ends at the cut", 1.0]]
const OUT_ALIGNS: Array = [["end", "Ends at the clip's end", 1.0], ["centre", "Centred on the clip's end", 0.5], ["start", "Starts at the clip's end", 0.0]]
const SECTION_ID := "fit:section"
const SAVE_ID := "save_preset"


static func shown(c: Clip, t: Track) -> bool:
	if c == null or t == null or not t.is_picture(c) or not c.has_transition():
		return false
	return str(c.transition_in.get("kind", "")) != TransitionRegistry.AUDIO_KIND


static func shown_out(c: Clip, t: Track) -> bool:
	return c != null and t != null and t.is_picture(c) and c.has_transition_out()


static func _key_of(tr: Dictionary) -> String:
	var params: Variant = tr.get("params", {})
	var names: PackedStringArray = PackedStringArray()
	if params is Dictionary:
		for k: Variant in (params as Dictionary).keys():
			names.append(String(k))
	names.sort()
	return str(tr.get("kind", "")) + "/" + str(bool(tr.get("lib", false))) + "/" + ",".join(names)


static func key(c: Clip) -> String:
	if c == null:
		return ""
	return _key_of(c.transition_in) + "/" + str(c.duration)


static func key_out(c: Clip) -> String:
	if c == null:
		return ""
	return "out:" + _key_of(c.transition_out) + "/" + str(c.duration)


static func prefix_of(side: String) -> String:
	return Clip.TRANSITION_OUT_PATH if side == "out" else Clip.TRANSITION_PATH


static func tr_of(c: Clip, side: String) -> Dictionary:
	return c.transition_out if side == "out" else c.transition_in


static func param_specs(c: Clip, side: String = "in") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tr: Dictionary = tr_of(c, side)
	var prefix: String = prefix_of(side)
	out.append({"path": prefix + Timing.PROGRESS, "label": "Progress", "kind": "float", "min": 0.0, "max": 1.0, "step": 0.01, "suffix": " %", "display_mul": 100.0, "keyable": true, "key": Timing.PROGRESS, "eid": "transition_progress"})
	var lib: String = TransitionRegistry.library_id(tr)
	if lib.is_empty():
		return out
	var def: Dictionary = TransitionRegistry.shared().call("get_def", lib)
	for p: Variant in def.get("params", []):
		var pd: Dictionary = p
		if bool(pd.get("hidden", false)):
			continue
		var k: String = String(pd["key"])
		var type: String = String(pd.get("type", "float"))
		var spec: Dictionary = {"path": prefix + k, "label": String(pd.get("label", k)), "kind": type, "keyable": bool(pd.get("keyable", true)), "key": k, "eid": "transition_" + lib}
		if type == "float" or type == "int":
			spec["min"] = float(pd.get("min", 0.0))
			spec["max"] = float(pd.get("max", 1.0))
			spec["step"] = float(pd.get("step", 0.01 if type == "float" else 1.0))
		elif type == "vec2":
			spec["step"] = float(pd.get("step", 0.01))
		var unit: String = String(pd.get("unit", ""))
		if not unit.is_empty():
			spec["suffix"] = unit
		if type == "enum":
			var choices: Array = []
			var raw: Array = pd.get("choices", [])
			for i: int in raw.size():
				choices.append(PmDrop.choice(str(i), String(raw[i])))
			spec["choices"] = choices
			spec["numeric"] = true
		out.append(spec)
	return out


static func build(panel: Object, c: Clip) -> void:
	build_side(panel, c, "in")


static func build_out(panel: Object, c: Clip) -> void:
	build_side(panel, c, "out")


static func build_side(panel: Object, c: Clip, side: String) -> void:
	if c == null:
		return
	var reg: RefCounted = TransitionRegistry.shared()
	var tr: Dictionary = tr_of(c, side)
	var lib: String = TransitionRegistry.library_id(tr)
	var title: String = ("Transition at the end: " if side == "out" else "Transition: ") + String(reg.call("label_for", tr))
	var f: VBoxContainer = panel.call("_fold", title, FOLD_KEY + ("_out" if side == "out" else ""))
	f.name = "TransitionOutFold" if side == "out" else "TransitionFold"
	var keys_btn: Button = PmButton.make("Keys")
	keys_btn.name = "TransitionKeys"
	keys_btn.set("quiet", true)
	PmUI.tip(keys_btn, "Timing curves, fit the keys into part of the transition, save it as a preset")
	keys_btn.pressed.connect(Callable(load(SELF_PATH), "_on_keys_menu").bind(panel, c.id, side, keys_btn))
	f.call("add_right", keys_btn)
	var change: Button = PmButton.make("Change")
	change.name = "ChangeTransition"
	change.set("quiet", true)
	PmUI.tip(change, "Pick another transition here, it keeps its length and timing")
	change.pressed.connect(Callable(load(SELF_PATH), "_on_change").bind(panel, c.id, side))
	f.call("add_right", change)
	if side == "in":
		var hb: Button = load("res://modules/core_panels/monitor_handles.gd").call("transition_switch", c)
		if hb != null:
			f.call("add_right", hb)
	var trash: Button = PmButton.make("", "trash")
	trash.name = "RemoveTransitionOut" if side == "out" else "RemoveTransition"
	trash.set("quiet", true)
	PmUI.tip(trash, "Remove the transition")
	trash.pressed.connect(Callable(load(SELF_PATH), "_on_remove").bind(c.id, side))
	f.call("add_right", trash)
	var body: VBoxContainer = f.get("body")
	var max_len: float = maxf(c.duration * 2.0, Clip.MIN_TRANSITION)
	var lp: String = OUT_PREFIX + "_length" if side == "out" else LENGTH_PATH
	var ap: String = OUT_PREFIX + "_align" if side == "out" else ALIGN_PATH
	panel.call("_add_row", body, {"path": lp, "label": "Length", "kind": "float", "min": Clip.MIN_TRANSITION, "max": max_len, "step": 0.01, "suffix": " s", "special": SPECIAL, "key": "duration", "side": side})
	var choices: Array = []
	for a: Array in (OUT_ALIGNS if side == "out" else ALIGNS):
		choices.append(PmDrop.choice(String(a[0]), String(a[1])))
	panel.call("_add_row", body, {"path": ap, "label": "Sits", "kind": "enum", "choices": choices, "special": SPECIAL, "key": "align", "side": side})
	var def: Dictionary = reg.call("get_def", lib) if not lib.is_empty() else {}
	for spec: Dictionary in param_specs(c, side):
		panel.call("_add_row", body, spec)
	if lib.is_empty():
		body.add_child(_note("A classic transition: its Progress curve sets its timing, it has no other settings."))
		return
	if def.is_empty():
		body.add_child(_note("\"" + lib + "\" is not in the transitions folders, so a plain dissolve is drawn. Its values are kept."))
		return
	var blurb: String = String(def.get("blurb", ""))
	if not blurb.is_empty():
		body.add_child(_note(blurb))


static func _note(text: String) -> Control:
	var l: Label = PmLabel.wrap(text, "text_dim")
	l.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_small")))
	var m: MarginContainer = MarginContainer.new()
	m.add_theme_constant_override("margin_left", Tk.px(Tk.sz("button_h")) + Tk.px(4.0))
	m.add_theme_constant_override("margin_right", Tk.px(4.0))
	m.add_theme_constant_override("margin_bottom", Tk.px(4.0))
	m.add_child(l)
	return m


static func align_of(tr: Dictionary) -> String:
	var off: float = Clip.transition_offset(tr)
	if off <= 0.001:
		return "start"
	if off >= 0.999:
		return "end"
	return "centre"


static func value(c: Clip, spec: Dictionary) -> Variant:
	var tr: Dictionary = tr_of(c, String(spec.get("side", "in")))
	var k: String = String(spec.get("key", ""))
	if k == "duration":
		return float(tr.get("duration", 0.5))
	if k == "align":
		return align_of(tr)
	return null


static func write(panel: Object, c: Clip, spec: Dictionary, v: Variant) -> void:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	var side: String = String(spec.get("side", "in"))
	if c == null or d == null or s == null:
		return
	var tr: Dictionary = tr_of(c, side)
	if tr.is_empty():
		return
	var next: Dictionary = tr.duplicate(true)
	var k: String = String(spec.get("key", ""))
	var label: String = "Set transition"
	if k == "duration":
		next = Timing.stretched(tr, clampf(float(v), Clip.MIN_TRANSITION, maxf(c.duration * 2.0, Clip.MIN_TRANSITION)))
		label = "Set transition length"
	elif k == "align":
		for a: Array in (OUT_ALIGNS if side == "out" else ALIGNS):
			if String(a[0]) == String(v):
				next["offset"] = float(a[2])
		next.erase("align")
		label = "Set where the transition sits"
	else:
		return
	if next == tr:
		return
	var cmd: Command = ClipCmds.SetClipField.new(s.id, c.id, Timing.OUT_FIELD, next) if side == "out" else ClipCmds.SetTransition.new(s.id, c.id, next)
	cmd.label = label
	if bool(panel.get("_dragging_field")):
		d.undo.live(cmd)
		panel.set("_live_label", label)
		return
	Verbs.run(d, label, [cmd])


static func menu_items(c: Clip, side: String) -> Array:
	var items: Array = []
	var timings: Array = []
	for tm: Array in Timing.TIMINGS:
		timings.append(PmMenu.item("timing:" + String(tm[0]), String(tm[1])))
	items.append(PmMenu.sub_item("timing", "Timing", timings))
	items.append(PmMenu.separator())
	for fit: Array in Timing.FITS:
		items.append(PmMenu.item("fit:" + String(fit[0]), String(fit[1])))
	items.append(PmMenu.item(SECTION_ID, "Fit keys to a section..."))
	items.append(PmMenu.separator())
	items.append(PmMenu.item(SAVE_ID, "Save as preset..."))
	return items


static func _on_keys_menu(panel: Object, clip_id: String, side: String, anchor: Control) -> void:
	var s: Sequence = panel.call("seq")
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c == null:
		return
	var m: Control = PmMenu.open(anchor, menu_items(c, side), anchor.get_global_mouse_position())
	if m != null and m.is_inside_tree():
		m.connect("picked", Callable(load(SELF_PATH), "menu_picked").bind(panel, clip_id, side))


static func menu_picked(id: String, panel: Object, clip_id: String, side: String) -> bool:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	if d == null or s == null:
		return false
	if id.begins_with("timing:"):
		return Ops.timing(d, s, clip_id, side, id.substr(7))
	if id == SECTION_ID:
		var host: Variant = panel.call("root")
		var fields: Array[Dictionary] = [{"key": "from", "label": "From (percent of its length)", "type": "float", "default": 25.0}, {"key": "to", "label": "To (percent of its length)", "type": "float", "default": 75.0}]
		var answered: Signal = PmUI.form(host, "Fit keys to a section", fields, "Fit", "Cancel")
		answered.connect(Callable(load(SELF_PATH), "_on_section").bind(clip_id, side))
		return true
	if id.begins_with("fit:"):
		var r: Vector2 = Timing.fit_range(id.substr(4))
		return Ops.fit(d, s, clip_id, side, r.x, r.y)
	if id == SAVE_ID:
		var c: Clip = s.clip_by_id(clip_id)
		var fields2: Array[Dictionary] = [{"key": "name", "label": "Name", "type": "string", "default": String(TransitionRegistry.shared().call("label_for", tr_of(c, side))) + " preset"}]
		var answered2: Signal = PmUI.form(panel.call("root"), "Save transition preset", fields2, "Save", "Cancel")
		answered2.connect(Callable(load(SELF_PATH), "_on_save").bind(clip_id, side))
		return true
	return false


static func _on_section(result: Variant, clip_id: String, side: String) -> void:
	if not (result is Dictionary) or (result as Dictionary).is_empty():
		return
	var r: Dictionary = result
	Ops.fit(Session.doc, Session.seq(), clip_id, side, clampf(float(r.get("from", 0.0)) / 100.0, 0.0, 1.0), clampf(float(r.get("to", 100.0)) / 100.0, 0.0, 1.0))


static func _on_save(result: Variant, clip_id: String, side: String) -> void:
	if not (result is Dictionary) or (result as Dictionary).is_empty():
		return
	var s: Sequence = Session.seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	var label: String = String((result as Dictionary).get("name", "")).strip_edges()
	if c == null or label.is_empty():
		return
	if not Ops.save_preset(c, side, label).is_empty():
		Events.toast("Saved the preset " + label + ", it is in the Transitions panel under My presets")


static func _on_change(panel: Object, clip_id: String, side: String) -> void:
	var r: Variant = panel.call("root")
	Ops.open_picker(r if r is Node else null, clip_id, side)


static func _on_remove(clip_id: String, side: String) -> void:
	Ops.remove(Session.doc, Session.seq(), clip_id, side)

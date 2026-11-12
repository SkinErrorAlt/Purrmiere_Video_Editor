extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const StreamOrdinals := preload("res://doc/stream_ordinals.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const SELF_PATH := "res://modules/core_panels/linked_sound.gd"
const TITLE := "Linked sound: "
const FOLD_KEY := "linked_sound"
const AnimProp := preload("res://doc/anim_prop.gd")
const StreamRoles := preload("res://doc/stream_roles.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const LINKED_TAG := "@linked."


static func sounds(s: Sequence, c: Clip) -> Array[Clip]:
	var out: Array[Clip] = []
	if s == null or c == null or c.link_id.is_empty():
		return out
	for o: Clip in s.linked(c):
		if o == c:
			continue
		var tr: Track = s.track_of(o.id)
		if tr != null and tr.is_sound(o):
			out.append(o)
	return out


static func stream_of(c: Clip) -> int:
	var v: Variant = c.audio.get("stream", 0.0)
	return int(v) if (v is float or v is int) else 0


static func name_of(d: Project, c: Clip) -> String:
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	return StreamOrdinals.label(m, stream_of(c))


static func key(d: Project, s: Sequence, c: Clip) -> String:
	var parts: PackedStringArray = PackedStringArray([c.id, name_of(d, c), s.display_label(s.track_of(c.id))])
	for e: Variant in c.audio_effects():
		var ed: Dictionary = e
		parts.append(String(ed.get("uid", "")) + "/" + String(ed.get("id", "")) + "/" + str(bool(ed.get("enabled", true))))
	return "|".join(parts)


static func build(panel: Object, c: Clip) -> void:
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	if d == null or s == null:
		return
	var name: String = name_of(d, c)
	var track_name: String = s.display_label(s.track_of(c.id))
	var f: VBoxContainer = panel.call("_fold", TITLE + name, FOLD_KEY)
	var body: VBoxContainer = f.get("body")
	var line: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(float(Tk.px(Tk.sz("button_h"))), 0.0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(gap)
	line.add_child(PmLabel.dim("Track " + track_name + ", stream " + name))
	var pick: Button = PmButton.make("Show its own controls", "audio")
	pick.set("quiet", true)
	PmUI.tip(pick, "Select only this sound clip, to see everything about it on its own")
	pick.pressed.connect(Callable(load(SELF_PATH), "select_only").bind(c.id))
	line.add_child(pick)
	body.add_child(line)
	for spec: Dictionary in row_specs(d, c):
		panel.call("_add_row", body, spec)
	var groups: Array[Dictionary] = panel.call("effect_groups", [c] as Array[Clip], true)
	if groups.is_empty():
		var none: HBoxContainer = PmUI.hbox(Tk.px(6.0))
		var gap2: Control = Control.new()
		gap2.custom_minimum_size = gap.custom_minimum_size
		gap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		none.add_child(gap2)
		none.add_child(PmLabel.dim("No sound effects on this clip"))
		body.add_child(none)
		return
	var reg: GDScript = load("res://modules/core_panels/effect_source.gd")
	for g: Dictionary in groups:
		var def: Dictionary = reg.call("get_def", String(g["eid"]))
		g["key"] = "linked." + c.id + "." + String(g["key"])
		g["title"] = String(def.get("label", g["eid"])) + " (" + name + ", linked sound)"
		panel.call("_build_group_many", g, true)


static func select_only(clip_id: String) -> void:
	var s: Sequence = Session.seq()
	if s == null or s.clip_by_id(clip_id) == null:
		return
	var verbs: GDScript = load("res://doc/verbs.gd")
	verbs.call("select", Session.doc, s, PackedStringArray([clip_id]), "replace", PackedStringArray([clip_id]))


static func row_specs(d: Project, c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null:
		return out
	var tag: String = LINKED_TAG + c.id
	out.append({"path": "audio.volume" + tag, "label": "Volume", "kind": "float", "min": 0.0, "max": 2.0, "step": 0.01, "suffix": " dB", "keyable": true, "db": true, "members": {c.id: "audio.volume"}})
	out.append({"path": "audio.pan" + tag, "label": "Pan", "kind": "float", "min": -1.0, "max": 1.0, "step": 0.01, "keyable": true, "members": {c.id: "audio.pan"}})
	var m: MediaItem = d.media_by_id(c.media_id) if d != null else null
	if m != null and m.audio_streams.size() > 1:
		var choices: Array = []
		for i: int in m.audio_streams.size():
			choices.append(PmDrop.choice(str(i), StreamRoles.menu_label(m, i)))
		out.append({"path": "audio.stream" + tag, "label": "Stream", "kind": "enum", "field": "audio", "key": "stream", "choices": choices, "numeric": true, "members": {c.id: "audio.stream"}})
	return out


static func refresh_keys(panel: Object, r: Dictionary, ph: float) -> void:
	var s: Sequence = panel.call("seq")
	if s == null:
		return
	var members: Dictionary = (r["spec"] as Dictionary).get("members", {})
	var bus: Object = panel.call("bus")
	var animated: bool = false
	var armed: bool = false
	var keyed: bool = true
	for cid: Variant in members.keys():
		var c: Clip = s.clip_by_id(String(cid))
		if c == null:
			continue
		var real: String = String(members[cid])
		var p: Dictionary = c.get_param(real)
		if AnimProp.is_animated(p):
			animated = true
			if not AnimProp.has_key_at(p, c.param_time(real, ph - c.start)):
				keyed = false
		if bus != null and bool(bus.call("is_armed", c.id, real)):
			armed = true
	(r["stopwatch"] as Button).set("active", animated or armed)
	(r["nav"] as Control).modulate.a = 1.0 if animated else 0.35
	if animated:
		(r["diamond"] as Button).set("icon_name", "diamond" if keyed else "diamond_o")

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
	PmUI.tip(pick, "Select only this sound clip, to see its volume, pan and stream too")
	pick.pressed.connect(Callable(load(SELF_PATH), "select_only").bind(c.id))
	line.add_child(pick)
	body.add_child(line)
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

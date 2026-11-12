extends RefCounted

const SoundAdjust := preload("res://engine/sound_adjust.gd")
const Clip := preload("res://doc/clip.gd")
const Track := preload("res://doc/track.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const PM_DROP := "res://ui/kit/pm_drop.gd"
const PM_UI := "res://ui/kit/pm_ui.gd"
const PM_LABEL := "res://ui/kit/pm_label.gd"

const TITLE := "Sound adjustment"
const FOLD_KEY := "sound_adjust"
const HOW := "Drop sound effects on this clip. Over its length they change the sound of the tracks it covers. Fade its ends to ease the change in and out; its Volume turns that sound up or down."


static func shown(panel: Object, c: Clip) -> bool:
	var d: Object = panel.call("doc")
	var s: Object = panel.call("seq")
	if d == null or s == null or c == null:
		return false
	var tr: Track = s.call("track_of", c.id)
	return SoundAdjust.is_sound_adjust(d, tr, c)


static func key(panel: Object, c: Clip) -> String:
	var s: Object = panel.call("seq")
	var tr: Track = s.call("track_of", c.id) if s != null else null
	var at: int = (s.get("audio_tracks") as Array).find(tr) if s != null else -1
	return FOLD_KEY + "|" + c.id + "|" + SoundAdjust.covers_of(c) + "|" + str(at) + "|" + str((s.get("audio_tracks") as Array).size() if s != null else 0)


static func covered_text(panel: Object, c: Clip) -> String:
	var names: PackedStringArray = SoundAdjust.covered_tracks(panel.call("doc"), panel.call("seq"), c)
	if SoundAdjust.covers_of(c) == SoundAdjust.COVERS_ABOVE:
		if names.is_empty():
			return "Changes: the sound of picture tracks only. Move it down a track to cover sound tracks."
		return "Changes: " + ", ".join(names) + " and the sound of picture tracks."
	return "Changes: every track, " + ", ".join(names) + ", and the sound of picture tracks."


static func build(panel: Object, c: Clip) -> void:
	var drop_kit: GDScript = load(PM_DROP)
	var ui_kit: GDScript = load(PM_UI)
	var label_kit: GDScript = load(PM_LABEL)
	var f: VBoxContainer = panel.call("_fold", TITLE, FOLD_KEY)
	var body: VBoxContainer = f.get("body")
	var col: VBoxContainer = ui_kit.call("vbox", 4)
	body.add_child(ui_kit.call("inset", col, 4.0, 6.0))
	var row: HBoxContainer = ui_kit.call("hbox")
	var lab: Label = label_kit.call("dim", "Covers")
	lab.custom_minimum_size.x = 90.0
	row.add_child(lab)
	var choices: Array = []
	for id: String in SoundAdjust.COVERS:
		choices.append(drop_kit.call("choice", id, String(SoundAdjust.COVERS_LABELS[id])))
	var drop: Button = drop_kit.call("make_drop", choices, SoundAdjust.covers_of(c))
	drop.name = "CoversDrop"
	drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_kit.call("tip", drop, String(SoundAdjust.COVERS_HINTS[SoundAdjust.covers_of(c)]))
	drop.connect("changed", func(id: String) -> void: set_covers(panel, c.id, id))
	row.add_child(drop)
	col.add_child(row)
	var reach: Label = label_kit.call("small", covered_text(panel, c))
	reach.name = "CoversText"
	reach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(reach)
	var how: Label = label_kit.call("faint", HOW)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(how)


static func set_covers(panel: Object, clip_id: String, covers: String) -> bool:
	var d: Object = panel.call("doc")
	var s: Object = panel.call("seq")
	return apply_covers(d, s, clip_id, covers)


static func apply_covers(d: Object, s: Object, clip_id: String, covers: String) -> bool:
	if d == null or s == null or not SoundAdjust.COVERS.has(covers):
		return false
	var c: Clip = s.call("clip_by_id", clip_id)
	if c == null or SoundAdjust.covers_of(c) == covers:
		return false
	var audio: Dictionary = c.audio.duplicate(true)
	audio[SoundAdjust.COVERS_KEY] = covers
	return Verbs.run(d, "Sound adjustment covers " + String(SoundAdjust.COVERS_LABELS[covers]).to_lower(), [ClipCmds.SetClipField.new(s.id, c.id, "audio", audio)])

extends RefCounted

const TimeInterp := preload("res://engine/time_interp.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const LABEL := "Time interpolation"


static func spec() -> Dictionary:
	var choices: Array = []
	for ch: Dictionary in TimeInterp.choices():
		choices.append(PmDrop.choice(String(ch["id"]), String(ch["label"])))
	return {"path": TimeInterp.PATH, "label": LABEL, "kind": "enum", "field": "props", "key": TimeInterp.FIELD, "default": TimeInterp.SAMPLE, "choices": choices}


static func wanted(panel: Object, c: Clip) -> bool:
	var d: Object = panel.call("doc")
	if d == null:
		return false
	var clips: Array = []
	if bool(panel.get("_many_on")):
		clips = panel.get("_many_members")
	else:
		clips = [c]
	for x: Variant in clips:
		var xc: Clip = x as Clip
		if xc != null and TimeInterp.shows_row(d.call("media_by_id", xc.media_id) as MediaItem, xc):
			return true
	return false


static func key(panel: Object, c: Clip) -> String:
	return "|ti" + str(TimeInterp.choices().size()) + ("|pf" if TimeInterp.mode_of(c) == TimeInterp.RIFE else "") if wanted(panel, c) else ""


static func add(panel: Object, body: VBoxContainer, c: Clip) -> void:
	if not wanted(panel, c):
		return
	panel.call("_add_row", body, spec())
	var rows: Array = panel.get("_rows")
	if not rows.is_empty():
		var lc: Variant = (rows.back() as Dictionary).get("label_ctrl", null)
		if lc is Control:
			PmUI.tip(lc as Control, TimeInterp.TIP)
	load("res://modules/core_panels/purrframes_row.gd").call("add", panel, body, c)

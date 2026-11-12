extends RefCounted

const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ViewBorder := preload("res://doc/view_border.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const EFFECT_ID := "pair_view"
const PICTURE_LABEL := "Frame picture"
const ZOOM_LABEL := "Zoom in the frame"
const OPENING_LABEL := "Frame opening"
const FOUND_NOTE := "Opening found in the picture: %d%% wide by %d%% tall"
const SOLID_NOTE := "No see-through middle in this picture, so it is drawn around the view instead"
const MISSING_NOTE := "That picture could not be read"
const EMPTY_NOTE := "A PNG or GIF with a see-through middle works best: the view sits in the see-through part. A video works too and plays around the view"
const LOOP_LABEL := "Loop the moving frame"
const MOVING_NOTE := "Moving frame, %d pictures over %s s. "
const VIDEO_NOTE := "Videos have no see-through parts, so a video frame plays around the view. "
const BorderReel := preload("res://doc/border_reel.gd")


static func path_of(c: Clip, uid: String, index: int) -> String:
	if c == null:
		return ""
	var raw: Variant = (c.effect_by_uid(uid).get("params", {}) as Dictionary).get(ViewBorder.border_key(index), null)
	if not (raw is Dictionary):
		return ""
	var v: Variant = AnimProp.static_value(raw)
	return String(v).strip_edges() if v is String else ""


static func note_for(path: String) -> String:
	var d: Dictionary = ViewBorder.window_for_path(path)
	if (d["size"] as Vector2).x < 1.0:
		return MISSING_NOTE
	if BorderReel.is_moving(path):
		var reel: Dictionary = BorderReel.reel_of(path)
		var head: String = MOVING_NOTE % [int(reel.get("count", 0)), String.num(float(reel.get("duration", 0.0)), 1)]
		if String(reel.get("source", "")) == "video":
			head += VIDEO_NOTE
		return head + still_note(d)
	return still_note(d)


static func still_note(d: Dictionary) -> String:
	if bool(d["solid"]):
		return SOLID_NOTE
	var win: Rect2 = d["win"]
	return FOUND_NOTE % [int(round(win.size.x * 100.0)), int(round(win.size.y * 100.0))]


static func add_rows(panel: Object, body: VBoxContainer, c: Clip, uid: String, index: int) -> void:
	if panel == null or body == null or c == null:
		return
	var key: String = ViewBorder.border_key(index)
	panel.call("_add_row", body, {"path": "effects." + uid + "." + key, "label": PICTURE_LABEL, "kind": "texture", "uid": uid, "key": key, "eid": EFFECT_ID, "keyable": false, "indent": 1})
	var path: String = path_of(c, uid, index)
	var note: HBoxContainer = PmUI.hbox(0)
	note.name = "BorderNote" + str(index)
	note.add_child(panel.call("_spacer", float(Tk.px(Tk.sz("button_h"))) * 2.0))
	note.add_child(PmLabel.dim(EMPTY_NOTE if path.is_empty() else note_for(path)))
	body.add_child(note)
	if path.is_empty():
		return
	if BorderReel.is_moving(path):
		var lk: String = ViewBorder.loop_key(index)
		panel.call("_add_row", body, {"path": "effects." + uid + "." + lk, "label": LOOP_LABEL, "kind": "bool", "uid": uid, "key": lk, "eid": EFFECT_ID, "keyable": true, "indent": 1})
	var zk: String = ViewBorder.zoom_key(index)
	panel.call("_add_row", body, {"path": "effects." + uid + "." + zk, "label": ZOOM_LABEL, "kind": "float", "uid": uid, "key": zk, "eid": EFFECT_ID, "keyable": true, "min": ViewBorder.ZOOM_MIN, "max": ViewBorder.ZOOM_MAX, "step": 0.01, "indent": 1})
	var ik: String = ViewBorder.inset_key(index)
	panel.call("_add_row", body, {"path": "effects." + uid + "." + ik, "label": OPENING_LABEL, "kind": "float", "uid": uid, "key": ik, "eid": EFFECT_ID, "keyable": true, "min": ViewBorder.INSET_MIN, "max": ViewBorder.INSET_MAX, "step": 0.001, "display_mul": 100.0, "suffix": " %", "indent": 1})

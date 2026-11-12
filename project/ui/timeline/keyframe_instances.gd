extends RefCounted

const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ManyKeys := preload("res://modules/core_panels/many_keys.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const MAX_LINES := 8
const COLOURS: Array[Color] = [Color(0.369, 0.784, 1.0), Color(1.0, 0.85, 0.3), Color(1.0, 0.45, 0.75), Color(0.45, 0.95, 0.55), Color(0.75, 0.6, 1.0), Color(1.0, 0.6, 0.35), Color(0.4, 0.95, 0.95), Color(0.95, 0.95, 0.6)]

static var drawn: int = 0


static func path_in(c: Clip, other: Clip, path: String) -> String:
	var parts: PackedStringArray = path.split(".")
	if parts.size() == 3 and (parts[0] == "effects" or parts[0] == "audio_effects"):
		var mine: Dictionary = c.audio_effect_by_uid(parts[1]) if parts[0] == "audio_effects" else c.effect_by_uid(parts[1])
		var eid: String = String(mine.get("id", ""))
		if eid.is_empty():
			return ""
		var list: Array = other.audio_effects() if parts[0] == "audio_effects" else other.effects
		for e: Variant in list:
			if e is Dictionary and String((e as Dictionary).get("id", "")) == eid:
				return parts[0] + "." + String((e as Dictionary).get("uid", "")) + "." + parts[2]
		return ""
	if parts.size() >= 1 and (parts[0] == "transition" or parts[0] == "transition_out" or parts[0] == "masks"):
		return ""
	return path


static func lines(s: Sequence, c: Clip, path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s == null or c == null or path.is_empty() or not ManyKeys.each_on():
		return out
	var ids: PackedStringArray = s.selected_clip_ids
	if ids.size() < 2:
		return out
	var n: int = 0
	for id: String in ids:
		if id == c.id or (not c.link_id.is_empty() and s.clip_by_id(id) != null and s.clip_by_id(id).link_id == c.link_id):
			continue
		var o: Clip = s.clip_by_id(id)
		if o == null:
			continue
		var op: String = path_in(c, o, path)
		if op.is_empty() or o.get_param(op).is_empty():
			continue
		out.append({"clip": o, "path": op, "colour": COLOURS[n % COLOURS.size()]})
		n += 1
		if n >= MAX_LINES:
			break
	return out


static func draw(editor: Control, r: Rect2, c: Clip) -> void:
	if String(editor.get("mode")) != "value" or bool(editor.get("mini")):
		return
	var s: Sequence = editor.call("seq")
	var list: Array[Dictionary] = lines(s, c, String(editor.get("path")))
	if list.is_empty():
		return
	var t0: float = float(editor.get("t0"))
	var t1: float = float(editor.get("t1"))
	var v0: float = float(editor.get("v0"))
	var v1: float = maxf(float(editor.get("v1")) - v0, 0.000001)
	var step: float = maxf(float(editor.call("curve_step")), 1.0)
	var f: float = float(editor.call("fps"))
	var font: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var row: int = 0
	for line: Dictionary in list:
		var o: Clip = line["clip"]
		var op: String = String(line["path"])
		var p: Dictionary = o.get_param(op)
		var col: Color = line["colour"]
		var pts: PackedVector2Array = PackedVector2Array()
		var x: float = r.position.x
		while x <= r.end.x:
			var t: float = t0 + (x - r.position.x) / maxf(r.size.x, 1.0) * (t1 - t0)
			var u: float = c.start + t - o.start
			if u >= 0.0 and u <= o.duration:
				var v: float = editor.call("comp", AnimProp.evaluate(p, o.param_time(op, u), o.duration, f), 0)
				pts.append(Vector2(x, clampf(r.end.y - (v - v0) / v1 * r.size.y, r.position.y - 400.0, r.end.y + 400.0)))
			elif pts.size() >= 2:
				editor.draw_polyline(pts, col, 1.2, true)
				pts = PackedVector2Array()
			else:
				pts = PackedVector2Array()
			x += step
		if pts.size() >= 2:
			editor.draw_polyline(pts, col, 1.2, true)
		var name_: String = o.label if not o.label.is_empty() else o.id
		PmText.draw_at(editor, font, Vector2(r.position.x + 4.0, r.position.y + float(fs) + 2.0 + float(row) * (float(fs) + 3.0)), name_, fs, col)
		row += 1
		drawn += 1

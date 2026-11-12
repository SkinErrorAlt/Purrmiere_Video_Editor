extends RefCounted
## Posing letters on the Program monitor, like posing a rig in a 3D animator. With posing on, click a letter (or
## word, line, or the whole text, by the Pick setting) to select its bone, Shift to add more, double-click for its
## word and triple-click for its line. Drag a selected letter to move it, the round knob to turn it and the
## corners or sides to scale it. Every change keys the bone at the playhead.

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Verbs := preload("res://doc/verbs.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const TextGlyphs := preload("res://engine/text_glyphs.gd")
const TextExtras := preload("res://doc/text_extras.gd")
const LetterRig := preload("res://doc/letter_rig.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const PmText := preload("res://ui/kit/pm_text.gd")

const PICKS: PackedStringArray = ["letters", "words", "lines", "all"]
const PICK_LABELS: PackedStringArray = ["Letters", "Words", "Lines", "Whole text"]
const POSE_LABEL := "Pose letters"
const HANDLE := 7.0
const KNOB_GAP := 26.0
const KNOB_R := 5.5
const SLOP := 3.0
const MULTI_MS := 450
const ROT_SNAP := 15.0
const NUDGE := 1.0
const NUDGE_BIG := 10.0

static var on: bool = false
static var pick: String = "letters"
static var selected: PackedStringArray = PackedStringArray()
static var clip_id: String = ""
static var serial: int = 0
static var clipboard: Dictionary = {}

var drag: Dictionary = {}
var hover: String = ""
var _clicks: int = 0
var _click_ms: int = 0
var _click_at: Vector2 = Vector2.ZERO


static func set_on(v: bool) -> void:
	if on == v:
		return
	on = v
	if not v:
		selected = PackedStringArray()
	changed()


static func set_pick(p: String) -> void:
	if not PICKS.has(p) or pick == p:
		return
	pick = p
	changed()


static func select(bones: PackedStringArray, for_clip: String) -> void:
	selected = LetterRig.sorted(bones)
	clip_id = for_clip
	changed()


static func changed() -> void:
	serial += 1
	var bus: Object = Bus.instance()
	var pp: Object = bus.call("panel", "program") if bus != null else null
	if pp != null and is_instance_valid(pp):
		var v: Variant = pp.get("view")
		if v is Object and is_instance_valid(v):
			(v as Object).call("redraw_overlay")


static func is_title(d: Project, c: Clip) -> bool:
	if d == null or c == null:
		return false
	var m: MediaItem = d.media_by_id(c.media_id)
	return m != null and m.kind == "title"


## The title being posed, its layer transform and every glyph's box, or {} when posing doesn't apply.
func target(panel: Object) -> Dictionary:
	if not on or panel == null:
		return {}
	var d: Project = panel.call("doc")
	var c: Clip = panel.call("gizmo_clip")
	if not is_title(d, c):
		return {}
	if c.id != clip_id:
		clip_id = c.id
		selected = PackedStringArray()
	var te: RefCounted = panel.call("monitor_text_edit")
	var t: Dictionary = te.call("target_of", panel, c)
	if t.is_empty() or TextExtras.path_on(t["props"]):
		return {}
	var raw: Variant = TextExtras.plain((t["props"] as Dictionary).get("text", ""))
	t["text"] = String(raw) if raw is String else ""
	t["words"] = LetterRig.word_map(String(t["text"]))
	t["quads"] = TextGlyphs.glyph_quads(t["props"], t["size"])
	return t


func bone_for(t: Dictionary, g: Dictionary, how: String = "") -> String:
	var mode: String = how if not how.is_empty() else pick
	var ci: int = int(g.get("ci", -1))
	match mode:
		"all":
			return LetterRig.ROOT
		"lines":
			return "l" + str(int(g.get("line", 0)))
		"words":
			var words: PackedInt32Array = t["words"]
			var w: int = words[ci] if ci >= 0 and ci < words.size() else -1
			return "w" + str(w) if w >= 0 else "c" + str(ci)
	return "c" + str(ci)


func glyphs_of(t: Dictionary, bone_id: String) -> Array:
	var out: Array = []
	var kind: String = LetterRig.kind_of(bone_id)
	var idx: int = LetterRig.index_of(bone_id)
	var words: PackedInt32Array = t["words"]
	for g: Dictionary in t["quads"]:
		var ci: int = int(g["ci"])
		var hit: bool = false
		match kind:
			LetterRig.ROOT:
				hit = true
			"l":
				hit = int(g["line"]) == idx
			"w":
				hit = ci >= 0 and ci < words.size() and words[ci] == idx
			_:
				hit = ci == idx
		if hit:
			out.append(g)
	return out


func screen_quad(panel: Object, pic: Rect2, t: Dictionary, q: PackedVector2Array) -> PackedVector2Array:
	var xf: Transform2D = t["xf"]
	var size: Vector2 = t["size"]
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in q:
		out.append(panel.call("_to_picture", pic, xf * (p / size)))
	return out


func layer_point(panel: Object, pic: Rect2, t: Dictionary, at: Vector2) -> Vector2:
	var s: Sequence = panel.call("seq")
	var xf: Transform2D = t["xf"]
	var size: Vector2 = t["size"]
	var k: float = pic.size.x / maxf(float(s.width), 1.0)
	return (xf.affine_inverse() * ((at - pic.position) / maxf(k, 0.0001))) * size


func glyph_at(panel: Object, pic: Rect2, t: Dictionary, at: Vector2) -> Dictionary:
	var lp: Vector2 = layer_point(panel, pic, t, at)
	var quads: Array = t["quads"]
	for i: int in range(quads.size() - 1, -1, -1):
		var g: Dictionary = quads[i]
		if Geometry2D.is_point_in_polygon(lp, g["quad"]):
			return g
	return {}


## The screen box around everything selected.
func selection_box(panel: Object, pic: Rect2, t: Dictionary) -> Rect2:
	var have: bool = false
	var r: Rect2 = Rect2()
	for b: String in selected:
		for g: Dictionary in glyphs_of(t, b):
			for p: Vector2 in screen_quad(panel, pic, t, g["quad"]):
				if not have:
					r = Rect2(p, Vector2.ZERO)
					have = true
				else:
					r = r.expand(p)
	return r if have else Rect2(0, 0, -1, -1)


func handles(box: Rect2) -> Dictionary:
	if box.size.x < 0.0:
		return {}
	var g: Rect2 = box.grow(4.0)
	var c: Vector2 = g.get_center()
	return {
		"scale_tl": g.position, "scale_tr": Vector2(g.end.x, g.position.y), "scale_br": g.end, "scale_bl": Vector2(g.position.x, g.end.y),
		"scale_l": Vector2(g.position.x, c.y), "scale_r": Vector2(g.end.x, c.y), "scale_t": Vector2(c.x, g.position.y), "scale_b": Vector2(c.x, g.end.y),
		"rotate": Vector2(c.x, g.position.y - KNOB_GAP),
	}


func handle_at(panel: Object, pic: Rect2, t: Dictionary, at: Vector2) -> String:
	if selected.is_empty():
		return ""
	var hs: Dictionary = handles(selection_box(panel, pic, t))
	if hs.has("rotate") and at.distance_to(hs["rotate"]) <= KNOB_R + 4.0:
		return "rotate"
	for k: String in hs.keys():
		if k != "rotate" and at.distance_to(hs[k]) <= HANDLE:
			return k
	return ""


## The parents' turn and scale above a bone, so a drag on screen moves a child the way the mouse went.
func parent_basis(t: Dictionary, bone_id: String) -> Transform2D:
	var props: Dictionary = t["props"]
	var chain: PackedStringArray = PackedStringArray()
	var kind: String = LetterRig.kind_of(bone_id)
	if kind == LetterRig.ROOT:
		return Transform2D.IDENTITY
	chain.append(LetterRig.ROOT)
	var gs: Array = glyphs_of(t, bone_id)
	var line: int = int((gs[0] as Dictionary)["line"]) if not gs.is_empty() else 0
	if kind == "w" or kind == "c":
		chain.append("l" + str(line))
	if kind == "c":
		var words: PackedInt32Array = t["words"]
		var ci: int = LetterRig.index_of(bone_id)
		if ci < words.size() and words[ci] >= 0:
			chain.append("w" + str(words[ci]))
	var m: Transform2D = Transform2D.IDENTITY
	for b: String in chain:
		var p: Dictionary = LetterRig.pose(props, b)
		m = m * Transform2D(float(p["rot"]), p["scale"] as Vector2, float(p["skew"]), Vector2.ZERO)
	return m


func input(event: InputEvent, pic: Rect2, panel: Object) -> bool:
	var t: Dictionary = target(panel)
	if t.is_empty():
		if not drag.is_empty():
			drag = {}
		return false
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if not drag.is_empty():
			_drag_to(panel, pic, t, mm.position, mm.shift_pressed)
			return true
		var g: Dictionary = glyph_at(panel, pic, t, mm.position)
		var hv: String = bone_for(t, g) if not g.is_empty() else ""
		if hv != hover:
			hover = hv
			changed()
		return false
	if not (event is InputEventMouseButton):
		return false
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return false
	if not mb.pressed:
		if drag.is_empty():
			return false
		var moved: bool = bool(drag.get("moved", false))
		drag = {}
		var d: Project = panel.call("doc")
		if moved and d != null and d.undo.has_live():
			d.undo.commit_live(POSE_LABEL)
		changed()
		return true
	var h: String = handle_at(panel, pic, t, mb.position)
	if not h.is_empty():
		_begin(panel, pic, t, h, mb.position)
		return true
	var g2: Dictionary = glyph_at(panel, pic, t, mb.position)
	if g2.is_empty():
		if not selected.is_empty() and not mb.shift_pressed:
			select(PackedStringArray(), clip_id)
		return false
	var now: int = Time.get_ticks_msec()
	if now - _click_ms <= MULTI_MS and mb.position.distance_to(_click_at) <= 6.0:
		_clicks += 1
	else:
		_clicks = 1
	_click_ms = now
	_click_at = mb.position
	var how: String = ""
	if mb.shift_pressed:
		_clicks = 1
	elif _clicks == 2:
		how = "words"
	elif _clicks >= 3:
		how = "lines"
	var b: String = bone_for(t, g2, how)
	var next: PackedStringArray = selected.duplicate()
	if mb.shift_pressed:
		if next.has(b):
			next.remove_at(next.find(b))
		else:
			next.append(b)
		select(next, clip_id)
		return true
	if not next.has(b) or _clicks >= 2:
		select(PackedStringArray([b]), clip_id)
	_begin(panel, pic, t, "move", mb.position)
	return true


func _begin(panel: Object, pic: Rect2, t: Dictionary, mode: String, at: Vector2) -> void:
	var props: Dictionary = t["props"]
	var starts: Dictionary = {}
	for b: String in selected:
		starts[b] = {"pos": LetterRig.vec(LetterRig.value(props, b, "pos")), "rot": float(LetterRig.value(props, b, "rot")), "scale": LetterRig.vec(LetterRig.value(props, b, "scale"), Vector2(100, 100)), "basis": parent_basis(t, b)}
	var box: Rect2 = selection_box(panel, pic, t)
	drag = {"mode": mode, "at": at, "layer_at": layer_point(panel, pic, t, at), "starts": starts, "centre": box.get_center(), "moved": false}


func _drag_to(panel: Object, pic: Rect2, t: Dictionary, at: Vector2, shift: bool) -> void:
	if not bool(drag["moved"]) and at.distance_to(drag["at"]) < SLOP:
		return
	drag["moved"] = true
	var mode: String = drag["mode"]
	var size: Vector2 = t["size"]
	var unit: float = 1080.0 / maxf(size.y, 1.0)
	var centre: Vector2 = drag["centre"]
	var writes: Dictionary = {}
	for b: String in (drag["starts"] as Dictionary).keys():
		var st: Dictionary = drag["starts"][b]
		if mode == "move":
			var dl: Vector2 = (layer_point(panel, pic, t, at) - (drag["layer_at"] as Vector2)) * unit
			if shift:
				dl = Vector2(dl.x, 0.0) if absf(dl.x) >= absf(dl.y) else Vector2(0.0, dl.y)
			var local: Vector2 = (st["basis"] as Transform2D).affine_inverse().basis_xform(dl)
			var p: Vector2 = (st["pos"] as Vector2) + local
			writes[LetterRig.key(b, "pos")] = [snappedf(p.x, 0.01), snappedf(p.y, 0.01)]
		elif mode == "rotate":
			var a0: float = ((drag["at"] as Vector2) - centre).angle()
			var a1: float = (at - centre).angle()
			var deg: float = rad_to_deg(wrapf(a1 - a0, -PI, PI))
			var r: float = float(st["rot"]) + deg
			if shift:
				r = snappedf(r, ROT_SNAP)
			writes[LetterRig.key(b, "rot")] = snappedf(r, 0.01)
		else:
			var d0: Vector2 = (drag["at"] as Vector2) - centre
			var d1: Vector2 = at - centre
			var f: Vector2 = Vector2.ONE
			var side: String = mode.substr(6)
			if side == "l" or side == "r":
				f.x = d1.x / d0.x if absf(d0.x) > 0.5 else 1.0
			elif side == "t" or side == "b":
				f.y = d1.y / d0.y if absf(d0.y) > 0.5 else 1.0
			else:
				var k: float = d1.length() / maxf(d0.length(), 0.5)
				f = Vector2(k, k)
				if shift:
					f = Vector2(d1.x / d0.x if absf(d0.x) > 0.5 else 1.0, d1.y / d0.y if absf(d0.y) > 0.5 else 1.0)
			var sc: Vector2 = (st["scale"] as Vector2) * f
			writes[LetterRig.key(b, "scale")] = [snappedf(sc.x, 0.01), snappedf(sc.y, 0.01)]
	write_keys(panel, writes, true)


## Keys each prop at the playhead. Live writes join one undo step that ends when the drag does.
static func write_keys(panel: Object, writes: Dictionary, live: bool, label: String = POSE_LABEL) -> bool:
	var d: Project = panel.call("doc") if panel != null else null
	var s: Sequence = panel.call("seq") if panel != null else null
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or s == null or c == null or writes.is_empty():
		return false
	var any: bool = false
	for k: Variant in writes.keys():
		if Verbs.set_clip_param(d, s, c.id, "props." + String(k), writes[k], s.playhead, true):
			any = true
	if not live and d.undo.has_live():
		d.undo.commit_live(label)
	return any


func handle_key(e: InputEventKey, panel: Object) -> bool:
	if not on or not e.pressed:
		return false
	var t: Dictionary = target(panel)
	if t.is_empty():
		return false
	if e.keycode == KEY_ESCAPE:
		if not selected.is_empty():
			select(PackedStringArray(), clip_id)
		else:
			set_on(false)
		return true
	if e.keycode == KEY_A and e.ctrl_pressed:
		var all: PackedStringArray = PackedStringArray()
		for g: Dictionary in t["quads"]:
			var b: String = bone_for(t, g)
			if not all.has(b):
				all.append(b)
		select(all, clip_id)
		return true
	if selected.is_empty():
		return false
	if e.ctrl_pressed and e.keycode == KEY_C:
		copy_pose(t["props"])
		return true
	if e.ctrl_pressed and e.keycode == KEY_V:
		return paste_pose(panel)
	var step: float = NUDGE_BIG if e.shift_pressed else NUDGE
	var dir: Vector2 = Vector2.ZERO
	match e.keycode:
		KEY_LEFT:
			dir = Vector2(-step, 0.0)
		KEY_RIGHT:
			dir = Vector2(step, 0.0)
		KEY_UP:
			dir = Vector2(0.0, -step)
		KEY_DOWN:
			dir = Vector2(0.0, step)
	if dir == Vector2.ZERO:
		return false
	var writes: Dictionary = {}
	for b2: String in selected:
		var p: Vector2 = LetterRig.vec(LetterRig.value(t["props"], b2, "pos")) + parent_basis(t, b2).affine_inverse().basis_xform(dir)
		writes[LetterRig.key(b2, "pos")] = [p.x, p.y]
	write_keys(panel, writes, false, "Nudge letters")
	return true


static func copy_pose(props: Dictionary) -> void:
	clipboard = {}
	for b: String in selected:
		clipboard[b] = LetterRig.pose_values(props, b)


## Pastes the copied pose onto the same bones, or, when other bones are selected, the first copied pose onto each.
static func paste_pose(panel: Object) -> bool:
	if clipboard.is_empty() or selected.is_empty():
		return false
	var writes: Dictionary = {}
	var first: Dictionary = clipboard[clipboard.keys()[0]]
	for b: String in selected:
		var src: Dictionary = clipboard.get(b, first)
		for f: Variant in src.keys():
			writes[LetterRig.key(b, String(f))] = src[f]
	return write_keys(panel, writes, false, "Paste pose")


func draw(ci: CanvasItem, pic: Rect2, panel: Object) -> void:
	var t: Dictionary = target(panel)
	if t.is_empty():
		return
	var ink: Color = Tk.c["accent"]
	var faint: Color = Color(1.0, 1.0, 1.0, 0.22)
	for g: Dictionary in t["quads"]:
		var sq: PackedVector2Array = screen_quad(panel, pic, t, g["quad"])
		sq.append(sq[0])
		ci.draw_polyline(sq, faint, 1.0, true)
	if not hover.is_empty() and not selected.has(hover):
		for gh: Dictionary in glyphs_of(t, hover):
			var hq: PackedVector2Array = screen_quad(panel, pic, t, gh["quad"])
			hq.append(hq[0])
			ci.draw_polyline(hq, Color(ink.r, ink.g, ink.b, 0.7), 1.5, true)
	for b: String in selected:
		for gs: Dictionary in glyphs_of(t, b):
			var q: PackedVector2Array = screen_quad(panel, pic, t, gs["quad"])
			ci.draw_colored_polygon(q, Color(ink.r, ink.g, ink.b, 0.18))
			q.append(q[0])
			ci.draw_polyline(q, ink, 1.5, true)
	if selected.is_empty():
		return
	var box: Rect2 = selection_box(panel, pic, t)
	if box.size.x < 0.0:
		return
	var hs: Dictionary = handles(box)
	var g4: Rect2 = box.grow(4.0)
	ci.draw_rect(g4, Color(ink.r, ink.g, ink.b, 0.8), false, 1.0)
	var top: Vector2 = Vector2(g4.get_center().x, g4.position.y)
	ci.draw_line(top, hs["rotate"], ink, 1.0, true)
	ci.draw_circle(hs["rotate"], KNOB_R, Color(0.08, 0.08, 0.1, 1.0))
	ci.draw_arc(hs["rotate"], KNOB_R, 0.0, TAU, 20, ink, 1.5, true)
	for k: String in hs.keys():
		if k == "rotate":
			continue
		var p: Vector2 = hs[k]
		var hr: Rect2 = Rect2(p - Vector2(HANDLE, HANDLE) * 0.5, Vector2(HANDLE, HANDLE))
		ci.draw_rect(hr, Color(0.08, 0.08, 0.1, 1.0), true)
		ci.draw_rect(hr, ink, false, 1.0)
	var c: Vector2 = g4.get_center()
	ci.draw_line(c - Vector2(5, 0), c + Vector2(5, 0), ink, 1.0)
	ci.draw_line(c - Vector2(0, 5), c + Vector2(0, 5), ink, 1.0)
	var name: String = selection_name(String(t["text"]))
	var f: Font = Tk.font("body")
	var fs: int = Tk.fs(Tk.sz("font_small"))
	var w: float = PmText.width_of(f, name, fs)
	var chip: Rect2 = Rect2(Vector2(g4.position.x, g4.end.y + 6.0), Vector2(w + PmText.pad() * 2.0, float(fs) + 8.0))
	ci.draw_rect(chip, Color(0.08, 0.08, 0.1, 0.85), true)
	PmText.draw(ci, f, chip, name, fs, Color(1, 1, 1, 0.95))


static func selection_name(text: String) -> String:
	if selected.is_empty():
		return "Nothing selected"
	if selected.size() == 1:
		return LetterRig.label(text, selected[0])
	var kinds: Dictionary = {}
	for b: String in selected:
		kinds[LetterRig.kind_of(b)] = true
	if kinds.size() == 1:
		var k: String = String(kinds.keys()[0])
		var noun: String = {"c": "letters", "w": "words", "l": "lines"}.get(k, "parts")
		return str(selected.size()) + " " + noun
	return str(selected.size()) + " parts"

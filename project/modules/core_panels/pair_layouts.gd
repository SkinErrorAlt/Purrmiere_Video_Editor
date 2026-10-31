extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const RecordCmds := preload("res://doc/commands/record_cmds.gd")
const LayoutCmds := preload("res://doc/commands/pair_layout_cmds.gd")
const PairLayout := preload("res://engine/pair_layout.gd")
const ViewMap := preload("res://doc/view_map.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const MENU_PREFIX := "pv_layout:"
const REGION_OWN := "pv_region_own"
const REGION_SHOW := "pv_region_show"
const PICK_PREFIX := "pv_own_on:"
const PICK_TITLE := "pv_own_title"
const FULL := "full"
const SIDE := "side"
const STACK := "stack"
const GRID := "grid"
const PIP_PREFIX := "pip_"
const PRESETS: Array[Dictionary] = [
	{"id": "full", "label": "Full view", "tip": "Full view: the view on screen fills the frame, as before"},
	{"id": "side", "label": "Side by side", "tip": "Side by side: every region in its own column: 50/50 for two, in any frame size"},
	{"id": "stack", "label": "Top and bottom", "tip": "Top and bottom: every region in its own row: 50/50 for two, in any frame size"},
	{"id": "grid", "label": "Grid", "tip": "Grid: every region at once, as Show every region does"},
	{"id": "pip_tl", "label": "Picture in picture, top left", "tip": "Picture in picture, top left: the view on screen fills the frame. Every other region sits in this corner at the size beside, stacked down the side when there are several. Drag them on the Program monitor to place them anywhere"},
	{"id": "pip_tr", "label": "Picture in picture, top right", "tip": "Picture in picture, top right: the view on screen fills the frame. Every other region sits in this corner at the size beside, stacked down the side when there are several. Drag them on the Program monitor to place them anywhere"},
	{"id": "pip_bl", "label": "Picture in picture, bottom left", "tip": "Picture in picture, bottom left: the view on screen fills the frame. Every other region sits in this corner at the size beside, stacked up the side when there are several. Drag them on the Program monitor to place them anywhere"},
	{"id": "pip_br", "label": "Picture in picture, bottom right", "tip": "Picture in picture, bottom right: the view on screen fills the frame. Every other region sits in this corner at the size beside, stacked up the side when there are several. Drag them on the Program monitor to place them anywhere"},
]
const SIZE_TIP := "How big the picture in picture regions are, as a share of the size they would have filling the frame. Changing it resizes them in their corner"
const SOLO_NOTE := "Shows only %s, on its own track. It moves, trims and cuts with %s, and its sound follows that clip's views."
const SOLO_NOTE_ALONE := "Shows only %s, at its place on screen."


const VIEWS_PANEL := "res://modules/core_panels/views_panel.gd"

static var _provider: RefCounted = null


static func register_all() -> void:
	if _provider == null:
		_provider = Provider.new()
	if not ResourceLoader.exists(VIEWS_PANEL):
		return
	var vp: GDScript = load(VIEWS_PANEL)
	if vp != null and vp.can_instantiate():
		vp.call("add_menu_provider", _provider)


class Provider:
	extends RefCounted

	const Outer := preload("res://modules/core_panels/pair_layouts.gd")

	func views_layout_items(c: Clip, uid: String) -> Array:
		return Outer.menu_items(c.id, uid) if c != null else []

	func views_layout_picked(id: String, clip_id: String, uid: String) -> bool:
		return Outer.menu_picked(id, clip_id, uid)

	func views_region_items(c: Clip, uid: String, index: int) -> Array:
		return Outer.region_menu_items(c.id, uid, index) if c != null else []

	func views_region_picked(id: String, clip_id: String, uid: String, index: int) -> bool:
		return Outer.region_menu_picked(id, clip_id, uid, index)


static func presets() -> Array[Dictionary]:
	return PRESETS.duplicate(true)


static func preset_label(preset_id: String) -> String:
	for p: Dictionary in PRESETS:
		if String(p["id"]) == preset_id:
			return String(p["label"])
	return ""


static func _doc() -> Project:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var s: Node = (loop as SceneTree).root.get_node_or_null("Session")
		if s != null:
			return s.get("doc")
	return null


static func _seq() -> Sequence:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var s: Node = (loop as SceneTree).root.get_node_or_null("Session")
		if s != null and s.has_method("seq"):
			return s.call("seq")
	return null


static func _toast(text: String) -> void:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var ev: Node = (loop as SceneTree).root.get_node_or_null("Events")
		if ev != null and ev.has_method("toast"):
			ev.call("toast", text)


static func time_in(c: Clip, s: Sequence) -> float:
	return clampf(s.playhead, c.start, maxf(c.end() - 0.0001, c.start))


static func apply(clip_id: String, uid: String, preset_id: String, size: float = -1.0) -> bool:
	return apply_in(_doc(), _seq(), clip_id, uid, preset_id, size)


static func apply_in(d: Project, s: Sequence, clip_id: String, uid: String, preset_id: String, size: float = -1.0) -> bool:
	if d == null or s == null:
		return false
	var c: Clip = s.clip_by_id(clip_id)
	var e: Dictionary = c.effect_by_uid(uid) if c != null else {}
	if e.is_empty():
		return false
	var t: float = time_in(c, s)
	var writes: Array = writes_for(d, s, c, e, preset_id, t, size)
	if writes.is_empty():
		return false
	var cmds: Array[Command] = commands_for(s, c, uid, writes, t, RecordCmds.recording())
	if cmds.is_empty():
		return false
	var label: String = preset_label(preset_id)
	return Verbs.run(d, "Layout: " + (label if not label.is_empty() else "Picture in picture"), cmds)


static func writes_for(d: Project, s: Sequence, c: Clip, e: Dictionary, preset_id: String, t: float, size: float) -> Array:
	var out: Array = []
	if preset_id == GRID:
		out.append(["grid", true])
		return out
	if preset_id == FULL or preset_id == SIDE or preset_id == STACK:
		out.append([PairLayout.LAYOUT_KEY, float({FULL: PairLayout.FULL, SIDE: PairLayout.SIDE, STACK: PairLayout.STACK}[preset_id])])
		out.append(["grid", false])
		return out
	if not preset_id.begins_with(PIP_PREFIX):
		return out
	var corner: String = preset_id.substr(PIP_PREFIX.length())
	if not PairLayout.CORNERS.has(corner):
		return out
	out.append([PairLayout.LAYOUT_KEY, float(PairLayout.PIP)])
	out.append(["grid", false])
	var st: Dictionary = PairLayout.state_at(c, e, t, s.fps)
	var crops: Array = st["crops"]
	var n: int = int(st["n"])
	var active: int = int(st["active"])
	var order: Array[int] = []
	for i: int in n:
		if i != active and not bool((crops[i] as Dictionary).get(PairLayout.OUT_KEY, false)):
			order.append(i)
	if order.is_empty():
		return out
	var local: float = t - c.start
	var want: float = size if size > 0.0 else PairLayout.size_at(c, e, order[0], local, s.fps)
	want = clampf(want, PairLayout.SIZE_MIN, PairLayout.SIZE_MAX)
	var src: Vector2i = LayoutCmds.source_px(d, s, c)
	var canvas: Vector2 = Vector2(PairLayout.canvas_for(src, LayoutCmds.frame_px(s)))
	var ca: float = canvas.x / maxf(canvas.y, 1.0)
	var sizes: Array[Vector2] = []
	for j: int in order:
		sizes.append(PairLayout.fitted(PairLayout.region_aspect((crops[j] as Dictionary)["rect"], Vector2(src)), ca) * want)
	var centres: Array[Vector2] = PairLayout.corner_centres(sizes, corner, canvas)
	for k: int in order.size():
		out.append([PairLayout.place_key(order[k]), [centres[k].x, centres[k].y]])
		out.append([PairLayout.size_key(order[k]), want])
	if active >= 0 and active < n and not bool((crops[active] as Dictionary).get(PairLayout.OUT_KEY, false)):
		var own: Array[Vector2] = [PairLayout.fitted(PairLayout.region_aspect((crops[active] as Dictionary)["rect"], Vector2(src)), ca) * want]
		var at: Vector2 = PairLayout.corner_centres(own, corner, canvas)[0]
		out.append([PairLayout.place_key(active), [at.x, at.y]])
		out.append([PairLayout.size_key(active), want])
	return out


static func commands_for(s: Sequence, c: Clip, uid: String, writes: Array, t: float, recording: bool) -> Array[Command]:
	var cmds: Array[Command] = []
	var e: Dictionary = c.effect_by_uid(uid)
	for w: Variant in writes:
		var key: String = String((w as Array)[0])
		var value: Variant = (w as Array)[1]
		var path: String = LayoutCmds.path_of(uid, key)
		var cur: Dictionary = c.get_param(path)
		var next: Dictionary = {}
		if recording or AnimProp.is_animated(cur):
			var was: Variant = PairLayout.value_at(c, e, key, t - c.start, s.fps, PairLayout.default_of(key))
			var base: Dictionary = cur if not cur.is_empty() else AnimProp.make(was)
			var kt: float = RecordCmds.key_time(c, s, t, path)
			if not AnimProp.is_animated(base):
				var k0: float = c.param_time(path, 0.0)
				base = AnimProp.set_key(base, k0, AnimProp.static_value(base), "hold")
			next = AnimProp.set_key(base, kt, value, "hold")
		else:
			next = AnimProp.make(value)
		if next == cur:
			continue
		var cmd: Command = ClipCmds.SetClipParam.new(s.id, c.id, path, next)
		cmd.label = "Layout"
		cmds.append(cmd)
	return cmds


static func lit(c: Clip, e: Dictionary, t: float, fps: float) -> String:
	var st: Dictionary = PairLayout.state_at(c, e, t, fps)
	if bool(st["grid"]):
		return GRID
	var layout: int = int(st["layout"])
	if layout == PairLayout.SIDE:
		return SIDE
	if layout == PairLayout.STACK:
		return STACK
	if layout != PairLayout.PIP:
		return FULL
	var first: int = first_inset(st)
	if first < 0:
		return PIP_PREFIX + "br"
	return PIP_PREFIX + PairLayout.corner_of(PairLayout.place_at(c, e, first, float(st["local"]), fps))


static func first_inset(st: Dictionary) -> int:
	var crops: Array = st["crops"]
	for i: int in int(st["n"]):
		if i != int(st["active"]) and not bool((crops[i] as Dictionary).get(PairLayout.OUT_KEY, false)):
			return i
	return -1


static func inset_size(c: Clip, e: Dictionary, t: float, fps: float) -> float:
	var st: Dictionary = PairLayout.state_at(c, e, t, fps)
	var first: int = first_inset(st)
	return PairLayout.size_at(c, e, maxi(first, 0), float(st["local"]), fps)


static func set_inset_size(clip_id: String, uid: String, size: float) -> bool:
	var s: Sequence = _seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c == null:
		return false
	var e: Dictionary = c.effect_by_uid(uid)
	var corner: String = lit(c, e, time_in(c, s), s.fps)
	if not corner.begins_with(PIP_PREFIX):
		corner = PIP_PREFIX + "br"
	return apply(clip_id, uid, corner, size)


static func shows_place(c: Clip, e: Dictionary) -> bool:
	if PairLayout.solo_of(e) >= 0:
		return true
	var p: Variant = (e.get("params", {}) as Dictionary).get(PairLayout.LAYOUT_KEY, null)
	if not (p is Dictionary):
		return false
	if not AnimProp.is_animated(p):
		return int(round(float(AnimProp.static_value(p)))) == PairLayout.PIP
	if int(round(float((p as Dictionary).get("base", 0.0)))) == PairLayout.PIP:
		return true
	for k: Dictionary in AnimProp.keys(p):
		if int(round(float(AnimProp.norm(k.get("v", 0.0))))) == PairLayout.PIP:
			return true
	return false


static func stamp(e: Dictionary) -> String:
	return ":pl" + ("1" if shows_place(null, e) else "0") + str(PairLayout.solo_of(e))


static func menu_items(clip_id: String, uid: String) -> Array:
	var s: Sequence = _seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	var e: Dictionary = c.effect_by_uid(uid) if c != null else {}
	var now: String = lit(c, e, time_in(c, s), s.fps) if not e.is_empty() else ""
	var items: Array = []
	for p: Dictionary in PRESETS:
		var it: Dictionary = PmMenu.check_item(MENU_PREFIX + String(p["id"]), String(p["label"]), now == String(p["id"]))
		if e.is_empty() or PairLayout.solo_of(e) >= 0:
			it["disabled"] = true
		items.append(it)
	return items


static func menu_picked(id: String, clip_id: String, uid: String) -> bool:
	if not id.begins_with(MENU_PREFIX):
		return false
	apply(clip_id, uid, id.substr(MENU_PREFIX.length()))
	return true


static func region_menu_items(clip_id: String, uid: String, index: int) -> Array:
	var s: Sequence = _seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	var e: Dictionary = c.effect_by_uid(uid) if c != null else {}
	var items: Array = []
	if e.is_empty():
		return items
	var crops: Array = PairLayout.parse(PairLayout.crops_text(e))
	if index < 0 or index >= crops.size():
		return items
	var region_name: String = _name_of(crops, index)
	var picks: Array = [PmMenu.item(PICK_TITLE, "Put " + region_name + " on")]
	(picks[0] as Dictionary)["disabled"] = true
	var first: bool = true
	for r: Dictionary in LayoutCmds.track_choices(s, c):
		var free: bool = bool(r["free"])
		var text: String = String(r["label"]) + (", free above" if free and bool(r["above"]) and first else (", free" if free else ", in use here"))
		var it: Dictionary = PmMenu.item(PICK_PREFIX + String(r["id"]), text)
		if not free:
			it["disabled"] = true
		if free and bool(r["above"]):
			first = false
		picks.append(it)
	picks.append(PmMenu.separator())
	var own: Track = s.track_of(c.id)
	picks.append(PmMenu.item(PICK_PREFIX + LayoutCmds.NEW_TRACK, "A new track above " + (own.shown_label() if own != null else "this clip")))
	var sub: Dictionary = PmMenu.sub_item(REGION_OWN, "Put this region on its own track", picks)
	if PairLayout.solo_of(e) >= 0 or c.is_nest():
		sub["disabled"] = true
	items.append(sub)
	var show: Dictionary = PmMenu.check_item(REGION_SHOW, "Show in the layout", not bool((crops[index] as Dictionary).get(PairLayout.OUT_KEY, false)))
	if PairLayout.solo_of(e) >= 0:
		show["disabled"] = true
	items.append(show)
	return items


static func region_menu_picked(id: String, clip_id: String, uid: String, index: int) -> bool:
	if id == REGION_SHOW:
		var s: Sequence = _seq()
		var c: Clip = s.clip_by_id(clip_id) if s != null else null
		if c == null:
			return true
		var crops: Array = PairLayout.parse(PairLayout.crops_text(c.effect_by_uid(uid)))
		if index >= 0 and index < crops.size():
			show_in_layout(clip_id, uid, index, bool((crops[index] as Dictionary).get(PairLayout.OUT_KEY, false)))
		return true
	if id.begins_with(PICK_PREFIX):
		put_on_own_track(clip_id, uid, index, id.substr(PICK_PREFIX.length()))
		return true
	return id == REGION_OWN or id == PICK_TITLE


static func open_region_menu(anchor: Control, clip_id: String, uid: String, index: int, at: Vector2 = Vector2(INF, INF)) -> void:
	var items: Array = region_menu_items(clip_id, uid, index)
	if items.is_empty() or anchor == null or not anchor.is_inside_tree():
		return
	var m: Control = PmMenu.open(anchor, items, at if at.x < INF else anchor.get_global_mouse_position())
	if m != null and m.is_inside_tree():
		m.connect("picked", func(id: String) -> void: region_menu_picked(id, clip_id, uid, index))


static func show_in_layout(clip_id: String, uid: String, index: int, on: bool) -> bool:
	var d: Project = _doc()
	var s: Sequence = _seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d == null or c == null:
		return false
	var e: Dictionary = c.effect_by_uid(uid)
	var text: String = LayoutCmds.crops_with(e, index, PairLayout.OUT_KEY, not on)
	if text == PairLayout.crops_text(e):
		return false
	var cmd: Command = ClipCmds.SetClipParam.new(s.id, c.id, LayoutCmds.path_of(uid, "crops"), AnimProp.make(text))
	cmd.label = "Show in the layout" if on else "Leave out of the layout"
	return Verbs.run(d, cmd.label, [cmd])


static func put_on_own_track(clip_id: String, uid: String, index: int, track_id: String = "") -> String:
	return put_on_own_track_in(_doc(), _seq(), clip_id, uid, index, track_id)


static func put_on_own_track_in(d: Project, s: Sequence, clip_id: String, uid: String, index: int, track_id: String = "") -> String:
	if d == null or s == null:
		return ""
	var c: Clip = s.clip_by_id(clip_id)
	if c == null or c.effect_by_uid(uid).is_empty():
		return ""
	var own: Track = s.track_of(c.id)
	if own != null and own.locked:
		_toast("The clip's track is locked")
		return ""
	var cmd: Command = LayoutCmds.RegionOwnTrack.new(s.id, clip_id, uid, index, track_id, s.playhead)
	if not Verbs.run(d, LayoutCmds.OWN_LABEL, [cmd]):
		_toast("That track has a clip in the way, pick another or a new track")
		return ""
	return String(cmd.get("made_clip"))


static func decorate_row(row: HBoxContainer, c: Clip, uid: String, index: int, after: Control) -> void:
	var s: Sequence = _seq()
	var e: Dictionary = c.effect_by_uid(uid)
	var mine: Dictionary = LayoutCmds.own_track_clips(s, c, uid) if PairLayout.solo_of(e) < 0 else {}
	var more: Button = PmButton.make("", "more")
	more.set("quiet", true)
	PmUI.tip(more, "Region menu: put it on its own track, show it in the layout")
	more.pressed.connect(func() -> void: open_region_menu(more, c.id, uid, index))
	row.add_child(more)
	if after != null and after.get_parent() == row:
		row.move_child(more, after.get_index() + 1)
	if mine.has(index):
		var other: Clip = mine[index]
		var tr: Track = s.track_of(other.id)
		var tag: Tag = Tag.new()
		tag.text = "On " + (tr.shown_label() if tr != null else "its own track")
		tag.colour = Tk.label_colour(ViewMap.colour_for(ViewMap.of(e), index))
		var crops: Array = PairLayout.parse(PairLayout.crops_text(e))
		PmUI.tip(tag, _name_of(crops, index) + " is shown by " + other.label + (" on " + tr.shown_label() if tr != null else ""))
		row.add_child(tag)
		if after != null and after.get_parent() == row:
			row.move_child(tag, after.get_index() + 1)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			row.accept_event()
			open_region_menu(row, c.id, uid, index))


class Tag:
	extends Control

	const PmText := preload("res://ui/kit/pm_text.gd")

	var text: String = "":
		set(v):
			text = v
			update_minimum_size()
			queue_redraw()
	var colour: Color = Color(0.9, 0.65, 0.37)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _get_minimum_size() -> Vector2:
		var font: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_small"))
		return Vector2(PmText.width_of(font, text, fs) + PmText.chip_pad() * 2.0 + 1.0, font.get_height(fs) + 2.0)

	func _draw() -> void:
		var font: Font = Tk.font("body")
		var fs: int = Tk.fs(Tk.sz("font_small"))
		var box: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(box, colour, true)
		PmText.draw(self, font, box, text, fs, Tk.c["bg_app"] if Tk.c.has("bg_app") else Color(0.05, 0.05, 0.06), HORIZONTAL_ALIGNMENT_CENTER, PmText.chip_pad(), NAN, PmText.WHOLE)


static func _name_of(crops: Array, index: int) -> String:
	var n: String = String((crops[index] as Dictionary).get("name", "")).strip_edges()
	return n if not n.is_empty() else "View " + str(index + 1)


static func source_of(s: Sequence, c: Clip, uid: String) -> Clip:
	if s == null or c == null or c.link_id.is_empty():
		return null
	for other: Clip in s.linked(c):
		if other == c or other.media_id != c.media_id:
			continue
		var oe: Dictionary = other.effect_by_uid(uid)
		if not oe.is_empty() and PairLayout.solo_of(oe) < 0:
			return other
	return null


static func header_row(c: Clip, e: Dictionary, spacer_w: float) -> Control:
	var uid: String = String(e.get("uid", ""))
	var solo: int = PairLayout.solo_of(e)
	if solo >= 0:
		return _solo_row(c, e, uid, solo, spacer_w)
	return _strip(c, e, uid, spacer_w)


static func _solo_row(c: Clip, e: Dictionary, uid: String, solo: int, spacer_w: float) -> Control:
	var row: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	var sp: Control = Control.new()
	sp.custom_minimum_size.x = spacer_w
	row.add_child(sp)
	var crops: Array = PairLayout.parse(PairLayout.crops_text(e))
	var region_name: String = _name_of(crops, clampi(solo, 0, crops.size() - 1))
	var s: Sequence = _seq()
	var src: Clip = source_of(s, c, uid)
	var text: String = SOLO_NOTE_ALONE % region_name
	if src != null:
		var tr: Track = s.track_of(src.id)
		text = SOLO_NOTE % [region_name, src.label + (" on " + tr.shown_label() if tr != null else "")]
	var l: Label = PmLabel.wrap(text, "text_dim")
	l.custom_minimum_size.x = float(Tk.px(160.0))
	row.add_child(l)
	var box: VBoxContainer = PmUI.vbox(0)
	box.add_child(row)
	var under: HBoxContainer = PmUI.hbox(Tk.px(6.0))
	var sp2: Control = Control.new()
	sp2.custom_minimum_size.x = spacer_w
	under.add_child(sp2)
	box.add_child(under)
	var all: Button = PmButton.make("Show all regions")
	all.set("quiet", true)
	PmUI.tip(all, "Make this an ordinary Pair View again, showing every region")
	all.pressed.connect(func() -> void:
		var d: Project = _doc()
		var sq: Sequence = _seq()
		if d != null and sq != null:
			Verbs.run(d, "Show all regions", [LayoutCmds.SetSolo.new(sq.id, c.id, uid, -1)]))
	under.add_child(all)
	return box


static func _strip(c: Clip, e: Dictionary, uid: String, spacer_w: float) -> Control:
	var row: Strip = Strip.new()
	row.name = "PairLayoutStrip"
	row.clip_id = c.id
	row.uid = uid
	row.add_theme_constant_override("separation", Tk.px(2.0))
	var sp: Control = Control.new()
	sp.custom_minimum_size.x = spacer_w
	row.add_child(sp)
	var cap: Label = PmLabel.dim("Layout")
	cap.custom_minimum_size.x = float(Tk.px(52.0))
	row.add_child(cap)
	for p: Dictionary in PRESETS:
		var pid: String = String(p["id"])
		if pid == "pip_tl":
			row.add_child(PmUI.divider(true))
		var b: Button = PmButton.make("", "", true)
		b.set("quiet", true)
		b.custom_minimum_size = Vector2(float(Tk.px(30.0)), float(Tk.px(24.0)))
		b.set_meta("preset", pid)
		PmUI.tip(b, String(p["tip"]))
		var pic: Control = Pictogram.new()
		pic.set("kind", pid)
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(pic)
		b.pressed.connect(row.pick.bind(pid))
		row.add_child(b)
		row.buttons.append(b)
	var size_cap: Label = PmLabel.dim("Size")
	row.add_child(size_cap)
	var f: Control = PmField.make(PairLayout.SIZE_DEFAULT * 100.0, PairLayout.SIZE_MIN * 100.0, PairLayout.SIZE_MAX * 100.0, 0.5, " %")
	f.set("precision", 1)
	f.custom_minimum_size.x = float(Tk.px(64.0))
	PmUI.tip(f, SIZE_TIP)
	f.connect("edit_ended", row.sized)
	row.add_child(f)
	row.size_field = f
	row.refresh()
	return row


class Strip:
	extends HBoxContainer

	const Outer := preload("res://modules/core_panels/pair_layouts.gd")

	var clip_id: String = ""
	var uid: String = ""
	var buttons: Array[Button] = []
	var size_field: Control = null
	var _seen: String = ""

	func _ready() -> void:
		set_process(true)

	func _process(_dt: float) -> void:
		refresh()

	func pick(pid: String) -> void:
		_seen = ""
		refresh()
		Outer.apply(clip_id, uid, pid)

	func sized() -> void:
		if size_field == null:
			return
		Outer.set_inset_size(clip_id, uid, float(size_field.get("value")) / 100.0)

	func refresh() -> void:
		var s: Sequence = Outer._seq()
		var d: Project = Outer._doc()
		if s == null or d == null:
			return
		var key: String = str(d.serial) + "|" + str(s.playhead)
		if key == _seen:
			return
		_seen = key
		var c: Clip = s.clip_by_id(clip_id)
		var e: Dictionary = c.effect_by_uid(uid) if c != null else {}
		if e.is_empty():
			return
		var t: float = Outer.time_in(c, s)
		var now: String = Outer.lit(c, e, t, s.fps)
		for b: Button in buttons:
			if is_instance_valid(b):
				var want: bool = String(b.get_meta("preset", "")) == now
				if b.button_pressed != want:
					b.set_pressed_no_signal(want)
					if b.has_method("_restyle"):
						b.call("_restyle")
				b.queue_redraw()
				for ch: Node in b.get_children():
					if ch is Control:
						(ch as Control).queue_redraw()
		if size_field != null and is_instance_valid(size_field) and not bool(size_field.get("_dragging")) and not bool(size_field.get("_pressed")) and size_field.get("_editor") == null:
			size_field.set("value", Outer.inset_size(c, e, t, s.fps) * 100.0)


class Pictogram:
	extends Control

	var kind: String = "full"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _blocks() -> Array[Rect2]:
		if kind == "side":
			return [Rect2(0.06, 0.12, 0.42, 0.76), Rect2(0.52, 0.12, 0.42, 0.76)]
		if kind == "stack":
			return [Rect2(0.06, 0.1, 0.88, 0.36), Rect2(0.06, 0.54, 0.88, 0.36)]
		if kind == "grid":
			return [Rect2(0.06, 0.1, 0.27, 0.36), Rect2(0.37, 0.1, 0.27, 0.36), Rect2(0.68, 0.1, 0.26, 0.36), Rect2(0.06, 0.54, 0.27, 0.36), Rect2(0.37, 0.54, 0.27, 0.36)]
		if kind.begins_with("pip_"):
			var right: bool = kind.ends_with("r")
			var bottom: bool = kind.contains("_b")
			return [Rect2(0.62 if right else 0.06, 0.54 if bottom else 0.1, 0.32, 0.36)]
		return [Rect2(0.22, 0.1, 0.56, 0.8)]

	func _draw() -> void:
		var b: Button = get_parent() as Button
		var ink: Color = Tk.c["text_dim"]
		if b != null and b.has_method("_icon_tint"):
			ink = b.call("_icon_tint")
		elif b != null and b.button_pressed:
			ink = Tk.c["text_bright"]
		var w: float = float(Tk.px(20.0))
		var h: float = float(Tk.px(13.0))
		var frame: Rect2 = Rect2((size - Vector2(w, h)) * 0.5, Vector2(w, h)).abs()
		draw_rect(frame, ink, false, 1.0)
		var inner: Rect2 = frame.grow(-1.5)
		for r: Rect2 in _blocks():
			draw_rect(Rect2(inner.position + r.position * inner.size, r.size * inner.size), ink, true)

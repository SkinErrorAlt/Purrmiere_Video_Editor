extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const Verbs := preload("res://doc/verbs.gd")
const Timecode := preload("res://doc/timecode.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const MediaLoader := preload("res://modules/core_panels/media_loader.gd")
const PREF_LIKE_PREMIERE := "bin.like_premiere"
const MENU_SETTINGS := "made_settings"
const EAR_MENU_PATH := "res://modules/core_panels/ear_safety_menu.gd"
const EDITABLE: PackedStringArray = ["adjust", "generator", "title", "shape"]
const SIZED: PackedStringArray = ["generator"]
const TIMED: PackedStringArray = ["adjust", "generator"]
const KIND_WORDS: Dictionary = {"adjust": "Adjustment layer", "generator": "Colour matte", "title": "Title", "shape": "Shape"}
const SPAWNS: Array[Dictionary] = [
	{"id": "new.adjust", "kind": "adjust", "label": "Adjustment layer", "icon": "fx"},
	{"id": "new.colour", "kind": "generator", "label": "Colour matte", "icon": "image", "colour": [0.5, 0.5, 0.5, 1.0]},
	{"id": "new.black", "kind": "generator", "label": "Black video", "icon": "image", "colour": [0.0, 0.0, 0.0, 1.0]},
	{"id": "new.title", "kind": "title", "label": "Title", "icon": "type"},
	{"id": "new.shape", "kind": "shape", "label": "Shape", "icon": "grid"},
]
const MIN_SIDE := 16
const MAX_SIDE := 16384
const MIN_FPS := 1.0
const MAX_FPS := 240.0
const MAX_SECONDS := 86400.0
const FALLBACK_W := 1920
const FALLBACK_H := 1080
const FALLBACK_FPS := 30.0
const ADJUST_NOTE := "An adjustment layer always covers the whole frame of the sequence it sits in."


static func register_prefs() -> void:
	if not Prefs.is_registered(PREF_LIKE_PREMIERE):
		Prefs.register(PREF_LIKE_PREMIERE, true, {"label": "Behave more like Premiere when making bin items", "type": "bool", "hint": "On: a new adjustment layer, matte, title or shape takes the active sequence's size, frame rate and the default still length straight away. Off: a small form asks for them first."})


static func like_premiere() -> bool:
	register_prefs()
	return bool(Prefs.get_value(PREF_LIKE_PREMIERE))


static func spawn_of(spawn_id: String) -> Dictionary:
	for sp: Dictionary in SPAWNS:
		if String(sp["id"]) == spawn_id:
			return sp
	return {}


static func is_spawn(spawn_id: String) -> bool:
	return not spawn_of(spawn_id).is_empty()


static func menu_items(with_sequence: bool) -> Array:
	var items: Array = []
	if with_sequence:
		items.append(PmMenu.item("new.sequence", "Sequence", Cmd.keys_text("file.new_sequence"), "seq"))
		items.append(PmMenu.separator())
	for sp: Dictionary in SPAWNS:
		var keys: String = Cmd.keys_text("file.new_title") if String(sp["id"]) == "new.title" else ""
		items.append(PmMenu.item(String(sp["id"]), String(sp["label"]), keys, String(sp["icon"])))
	return items


static func is_editable(m: MediaItem) -> bool:
	return m != null and m.kind in EDITABLE


static func settings_label(m: MediaItem) -> String:
	return String(KIND_WORDS.get(m.kind if m != null else "", "Item")) + " settings"


static func sequence_base(seq: Sequence) -> Dictionary:
	var w: int = seq.width if seq != null and seq.width > 0 else FALLBACK_W
	var h: int = seq.height if seq != null and seq.height > 0 else FALLBACK_H
	var r: float = seq.fps if seq != null and seq.fps > 0.0 else FALLBACK_FPS
	return {"width": w, "height": h, "fps": r, "duration": MediaLoader.still_seconds()}


static func defaults_for(spawn_id: String, seq: Sequence) -> Dictionary:
	var sp: Dictionary = spawn_of(spawn_id)
	if sp.is_empty():
		return {}
	var base: Dictionary = sequence_base(seq)
	var kind: String = String(sp["kind"])
	var out: Dictionary = {"label": String(sp["label"]), "duration": float(base["duration"])}
	if kind in TIMED:
		out["width"] = int(base["width"])
		out["height"] = int(base["height"])
		out["fps"] = float(base["fps"])
	if sp.has("colour"):
		out["colour"] = (sp["colour"] as Array).duplicate()
	return out


static func make_dict(d: Project, spawn_id: String, bin: String, values: Dictionary) -> Dictionary:
	var sp: Dictionary = spawn_of(spawn_id)
	if d == null or sp.is_empty():
		return {}
	var kind: String = String(sp["kind"])
	var label: String = String(values.get("label", sp["label"]))
	var md: Dictionary = {"id": d.mint_id("m"), "kind": kind, "label": label, "bin": bin, "probed": true, "duration": float(values.get("duration", MediaLoader.still_seconds()))}
	if kind in TIMED:
		md["width"] = int(values.get("width", FALLBACK_W))
		md["height"] = int(values.get("height", FALLBACK_H))
		md["fps"] = float(values.get("fps", FALLBACK_FPS))
	if kind == "generator":
		md["props"] = {"colour": (values.get("colour", TitleStyle.matte_defaults()["colour"]) as Array).duplicate()}
	elif kind == "title":
		md["props"] = {"text": label}
	return md


static func spawn_now(d: Project, seq: Sequence, spawn_id: String, bin: String, values: Dictionary = {}) -> String:
	var merged: Dictionary = defaults_for(spawn_id, seq)
	for k: Variant in values.keys():
		merged[k] = values[k]
	var md: Dictionary = make_dict(d, spawn_id, bin, merged)
	if md.is_empty():
		return ""
	if not Verbs.run(d, "New " + String(md["label"]).to_lower(), [MediaCmds.AddMedia.new(md)]):
		return ""
	return String(md["id"])


static func colour_hex(v: Variant) -> String:
	return "#" + TitleStyle.colour_of(v, Color(0.5, 0.5, 0.5, 1.0)).to_html(false)


static func fps_text(r: float) -> String:
	var t: String = "%.3f" % r
	while t.ends_with("0"):
		t = t.substr(0, t.length() - 1)
	return t.trim_suffix(".")


static func fields_for(kind: String, values: Dictionary) -> Array[Dictionary]:
	var r: float = float(values.get("fps", FALLBACK_FPS))
	var out: Array[Dictionary] = [{"key": "label", "label": "Name", "type": "string", "default": String(values.get("label", ""))}]
	if kind in SIZED:
		out.append({"key": "width", "label": "Width", "type": "string", "default": str(int(values.get("width", FALLBACK_W)))})
		out.append({"key": "height", "label": "Height", "type": "string", "default": str(int(values.get("height", FALLBACK_H)))})
	if kind in TIMED:
		out.append({"key": "fps", "label": "Frame rate", "type": "string", "default": fps_text(r)})
	out.append({"key": "duration", "label": "Duration", "type": "string", "default": Timecode.format(float(values.get("duration", MediaLoader.still_seconds())), r if r > 0.0 else FALLBACK_FPS)})
	if kind == "generator":
		out.append({"key": "colour", "label": "Colour", "type": "string", "default": colour_hex(values.get("colour", null))})
	if kind == "adjust":
		out.append({"key": "note", "label": "", "type": "note", "default": ADJUST_NOTE})
	return out


static func read_answer(kind: String, answer: Dictionary, current: Dictionary) -> Dictionary:
	var out: Dictionary = current.duplicate(true)
	var name: String = String(answer.get("label", "")).strip_edges()
	if not name.is_empty():
		out["label"] = name
	if kind in SIZED:
		for k: String in ["width", "height"]:
			var t: String = String(answer.get(k, "")).strip_edges()
			if t.is_valid_int():
				out[k] = clampi(int(t), MIN_SIDE, MAX_SIDE)
	var r: float = float(out.get("fps", FALLBACK_FPS))
	if kind in TIMED:
		var ft: String = String(answer.get("fps", "")).strip_edges()
		if ft.is_valid_float():
			r = clampf(float(ft), MIN_FPS, MAX_FPS)
			out["fps"] = r
	var secs: float = Timecode.parse(String(answer.get("duration", "")), r if r > 0.0 else FALLBACK_FPS)
	if not is_nan(secs) and secs > 0.0:
		out["duration"] = clampf(secs, 1.0 / (r if r > 0.0 else FALLBACK_FPS), MAX_SECONDS)
	if kind == "generator":
		var hex: String = String(answer.get("colour", "")).strip_edges()
		if Color.html_is_valid(hex):
			var c: Color = Color.html(hex)
			out["colour"] = [c.r, c.g, c.b, 1.0]
	return out


static func values_of(m: MediaItem) -> Dictionary:
	var out: Dictionary = {"label": m.label, "duration": m.duration}
	if m.kind in TIMED:
		out["width"] = m.width
		out["height"] = m.height
		out["fps"] = m.fps if m.fps > 0.0 else FALLBACK_FPS
	if m.kind == "generator":
		out["colour"] = m.props.get("colour", TitleStyle.matte_defaults()["colour"])
	return out


static func edit_cmds(m: MediaItem, values: Dictionary) -> Array[Command]:
	var cmds: Array[Command] = []
	if m == null:
		return cmds
	var label: String = String(values.get("label", m.label))
	if label != m.label:
		cmds.append(MediaCmds.SetMediaField.new(m.id, "label", label))
	var dur: float = float(values.get("duration", m.duration))
	if absf(dur - m.duration) > 0.0001:
		cmds.append(MediaCmds.SetMediaField.new(m.id, "duration", dur))
	if m.kind in TIMED:
		for k: String in ["width", "height"]:
			var v: int = int(values.get(k, m.get(k)))
			if v != int(m.get(k)):
				cmds.append(MediaCmds.SetMediaField.new(m.id, k, v))
		var r: float = float(values.get("fps", m.fps))
		if absf(r - m.fps) > 0.0001:
			cmds.append(MediaCmds.SetMediaField.new(m.id, "fps", r))
	if m.kind == "generator" and values.has("colour"):
		var now: Color = TitleStyle.colour_of(m.props.get("colour", null), Color(0.5, 0.5, 0.5, 1.0))
		var want: Color = TitleStyle.colour_of(values["colour"], now)
		if not now.is_equal_approx(want):
			var props: Dictionary = m.props.duplicate(true)
			props["colour"] = [want.r, want.g, want.b, want.a]
			cmds.append(MediaCmds.SetMediaField.new(m.id, "props", props))
	return cmds


static func apply_values(d: Project, media_id: String, values: Dictionary) -> bool:
	var m: MediaItem = d.media_by_id(media_id) if d != null else null
	if m == null:
		return false
	var cmds: Array[Command] = edit_cmds(m, values)
	if cmds.is_empty():
		return false
	return Verbs.run(d, settings_label(m), cmds)


static func open_settings(host: Node, d: Project, media_id: String) -> bool:
	var m: MediaItem = d.media_by_id(media_id) if d != null else null
	if host == null or not is_editable(m):
		return false
	var kind: String = m.kind
	var current: Dictionary = values_of(m)
	var answered: Signal = PmUI.form(host, settings_label(m), fields_for(kind, current), "Apply", "Cancel")
	answered.connect(func(result: Variant) -> void:
		if result is Dictionary and not (result as Dictionary).is_empty():
			apply_values(d, media_id, read_answer(kind, result, current)))
	return true


static func ask_new(host: Node, d: Project, seq: Sequence, spawn_id: String, bin: String, done: Callable) -> bool:
	var sp: Dictionary = spawn_of(spawn_id)
	if host == null or d == null or sp.is_empty():
		return false
	var kind: String = String(sp["kind"])
	var current: Dictionary = defaults_for(spawn_id, seq)
	var answered: Signal = PmUI.form(host, "New " + String(sp["label"]).to_lower(), fields_for(kind, current), "Make", "Cancel")
	answered.connect(func(result: Variant) -> void:
		if not (result is Dictionary) or (result as Dictionary).is_empty():
			return
		var made: String = spawn_now(d, seq, spawn_id, bin, read_answer(kind, result, current))
		if not made.is_empty() and done.is_valid():
			done.call(made))
	return true


static func clip_menu_items(c: Clip) -> Array:
	var d: Project = Session.doc
	var m: MediaItem = d.media_by_id(c.media_id) if d != null and c != null else null
	var out: Array = []
	if is_editable(m):
		out.append(PmMenu.item(MENU_SETTINGS, settings_label(m)))
	out.append_array(load(EAR_MENU_PATH).call("clip_menu_items", c))
	return out


static func on_clip_menu(host: Node, id: String, clip_id: String) -> bool:
	if bool(load(EAR_MENU_PATH).call("on_clip_menu", id, clip_id)):
		return true
	if id != MENU_SETTINGS:
		return false
	var d: Project = Session.doc
	var s: Sequence = Session.seq()
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if d != null and c != null:
		open_settings(host, d, c.media_id)
	return true

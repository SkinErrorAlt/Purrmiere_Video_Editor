extends Node

const Sheet := preload("res://modules/core_panels/sheet.gd")
const SheetList := preload("res://modules/core_panels/sheet_list.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Marker := preload("res://doc/marker.gd")
const Verbs := preload("res://doc/verbs.gd")
const Timecode := preload("res://doc/timecode.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const SELF_PATH := "res://modules/core_panels/find_sheet.gd"
const SCOPES: Array[Dictionary] = [
	{"id": "all", "label": "Everything"},
	{"id": "clip", "label": "Clips"},
	{"id": "marker", "label": "Markers"},
	{"id": "bin", "label": "Bin"},
	{"id": "effect", "label": "Effects"},
]
const KIND_LABELS: Dictionary = {"clip": "Clip", "marker": "Marker", "clip_marker": "Clip mark", "bin": "Bin", "effect": "Effect"}
const MAX_RESULTS := 400

static var last_query: String = ""

var sheet: Control = null
var field: LineEdit = null
var list: Control = null
var foot: Label = null
var scope: String = "all"
var results: Array[Dictionary] = []
var _chips: Dictionary = {}


static func open(host: Node) -> Node:
	var script: GDScript = load(SELF_PATH)
	var f: Node = script.new()
	f.call("build", host)
	return f


static func _hit(text: String, needle: String) -> bool:
	return not needle.is_empty() and text.to_lower().contains(needle)


static func effect_label(id: String) -> String:
	var Registry: GDScript = load("res://engine/effect_registry.gd")
	if Registry != null:
		var reg: RefCounted = Registry.call("shared")
		if reg != null:
			var def: Dictionary = reg.call("get_def", id)
			if not def.is_empty() and not String(def.get("label", "")).is_empty():
				return String(def["label"])
	var Audio: GDScript = load("res://engine/audio_effects.gd")
	if Audio != null and bool(Audio.call("has", id)):
		var adef: Dictionary = Audio.call("get_def", id)
		if not String(adef.get("label", "")).is_empty():
			return String(adef["label"])
	return id.capitalize()


static func clip_name(doc: Project, c: Clip) -> String:
	if not c.label.is_empty():
		return c.label
	var m: MediaItem = doc.media_by_id(c.media_id)
	return m.label if m != null else c.id


static func search(doc: Project, s: Sequence, query: String, kind: String = "all") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var needle: String = query.strip_edges().to_lower()
	if doc == null or needle.is_empty():
		return out
	var want_all: bool = kind == "all"
	if s != null:
		for t: Track in s.all_tracks():
			for c: Clip in t.clips:
				var cname: String = clip_name(doc, c)
				if (want_all or kind == "clip") and _hit(cname, needle):
					out.append({"kind": "clip", "title": cname, "detail": t.label + " in " + s.label, "time": c.start, "clip_id": c.id, "media_id": c.media_id})
				if want_all or kind == "marker":
					for m: Marker in c.markers:
						if _hit(m.label, needle) or _hit(m.comment, needle):
							out.append({"kind": "clip_marker", "title": m.label if not m.label.is_empty() else m.comment, "detail": "on " + cname, "time": c.start + m.time, "clip_id": c.id, "media_id": c.media_id})
				if want_all or kind == "effect":
					var fx: Array = []
					fx.append_array(c.effects)
					var aud: Variant = c.audio.get("effects", [])
					if aud is Array:
						fx.append_array(aud)
					for e: Variant in fx:
						if not (e is Dictionary):
							continue
						var ename: String = effect_label(String((e as Dictionary).get("id", "")))
						if _hit(ename, needle):
							out.append({"kind": "effect", "title": ename, "detail": "on " + cname + ", " + t.label, "time": c.start, "clip_id": c.id, "media_id": c.media_id})
				if out.size() >= MAX_RESULTS:
					return out
		if want_all or kind == "marker":
			for m: Marker in s.markers:
				if _hit(m.label, needle) or _hit(m.comment, needle):
					var mdetail: String = m.kind + " marker"
					if not m.label.is_empty() and not m.comment.is_empty():
						mdetail += ", " + m.comment
					out.append({"kind": "marker", "title": m.label if not m.label.is_empty() else m.comment, "detail": mdetail, "time": m.time, "clip_id": "", "media_id": ""})
	if want_all or kind == "bin":
		for m: MediaItem in doc.media:
			if _hit(m.label, needle):
				out.append({"kind": "bin", "title": m.label, "detail": m.bin if not m.bin.is_empty() else "Bin", "time": -1.0, "clip_id": "", "media_id": m.id})
	out.sort_custom(_before)
	if out.size() > MAX_RESULTS:
		out.resize(MAX_RESULTS)
	return out


static func _before(a: Dictionary, b: Dictionary) -> bool:
	var ta: float = float(a["time"])
	var tb: float = float(b["time"])
	if (ta < 0.0) != (tb < 0.0):
		return tb < 0.0
	if not is_equal_approx(ta, tb):
		return ta < tb
	return String(a["title"]).naturalnocasecmp_to(String(b["title"])) < 0


static func jump(doc: Project, s: Sequence, r: Dictionary) -> bool:
	if doc == null or r.is_empty():
		return false
	var kind: String = String(r.get("kind", ""))
	if kind == "bin":
		var bin: Object = Bus.instance().panel("bin")
		_show_panel("bin")
		if bin != null and bin.has_method("reveal"):
			bin.call("reveal", String(r["media_id"]))
			return true
		return false
	if s == null:
		return false
	var t: float = float(r.get("time", 0.0))
	if t >= 0.0:
		Session.set_playhead(t)
	var cid: String = String(r.get("clip_id", ""))
	if not cid.is_empty() and s.clip_by_id(cid) != null:
		Verbs.select(doc, s, PackedStringArray([cid]), "replace")
	if kind == "effect":
		_show_panel("effect_controls")
	return true


static func _show_panel(id: String) -> void:
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var editor: Node = (loop as SceneTree).root.find_child("EditorScreen", true, false)
	if editor == null:
		return
	var dock: Variant = editor.get("dock")
	if dock is Node and (dock as Node).has_method("show_panel"):
		(dock as Node).call("show_panel", id)


func build(host: Node) -> void:
	name = "FindSheet"
	sheet = Sheet.open(host, "Find", 560.0, 450.0, 120.0)
	sheet.set("close_on_veil", true)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	field = PmUI.line_edit("Clip names, markers, bin items, effects")
	field.text = last_query
	field.gui_input.connect(_on_field_input)
	field.text_changed.connect(_on_text)
	col.add_child(field)
	var chips: HBoxContainer = PmUI.hbox()
	for sc: Dictionary in SCOPES:
		var b: Button = PmButton.make(String(sc["label"]), "", true)
		b.button_pressed = String(sc["id"]) == scope
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_scope.bind(String(sc["id"])))
		chips.add_child(b)
		_chips[String(sc["id"])] = b
	col.add_child(chips)
	list = SheetList.make(36.0, true, 76.0)
	list.set("empty_text", "Type to search the open sequence and the bin")
	list.connect("activated", _on_activated)
	col.add_child(list)
	col.add_child(PmUI.divider())
	foot = PmLabel.faint("")
	col.add_child(foot)
	refresh()
	field.grab_focus.call_deferred()
	field.select_all.call_deferred()


func set_query(text: String) -> void:
	field.text = text
	refresh()


func set_scope(id: String) -> void:
	scope = id
	for k: String in _chips.keys():
		(_chips[k] as Button).set_pressed_no_signal(k == id)
	refresh()


func refresh() -> void:
	var doc: Project = Session.doc
	var s: Sequence = Session.seq()
	var q: String = field.text
	last_query = q
	results = search(doc, s, q, scope)
	var fps: float = s.fps if s != null and s.fps > 0.0 else 30.0
	var rows: Array[Dictionary] = []
	for r: Dictionary in results:
		var t: float = float(r["time"])
		rows.append({"lead": String(KIND_LABELS.get(String(r["kind"]), "")), "title": String(r["title"]), "detail": String(r["detail"]), "right": Timecode.format(t, fps, s != null and s.drop_frame) if t >= 0.0 else ""})
	list.call("set_rows", rows)
	if q.strip_edges().is_empty():
		foot.text = "Enter jumps the playhead and selects it"
	else:
		var n: int = results.size()
		foot.text = ("Nothing found" if n == 0 else (str(n) + " found")) + "    Enter jumps the playhead and selects it"


func _on_scope(id: String) -> void:
	set_scope(id)
	field.grab_focus()


func _on_text(_t: String) -> void:
	refresh()


func _on_field_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed:
		return
	if k.keycode == KEY_ESCAPE:
		field.accept_event()
		sheet.call("close")
		return
	if bool(list.call("handle_nav_key", k)):
		field.accept_event()


func _on_activated(index: int) -> void:
	if index < 0 or index >= results.size():
		return
	var r: Dictionary = results[index]
	sheet.call("close")
	jump(Session.doc, Session.seq(), r)

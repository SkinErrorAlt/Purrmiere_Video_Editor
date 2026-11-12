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
const TextFind := preload("res://doc/text_find.gd")
const SELF_PATH := "res://modules/core_panels/find_sheet.gd"
const SCOPES: Array[Dictionary] = [
	{"id": "all", "label": "Everything"},
	{"id": "clip", "label": "Clips"},
	{"id": "title", "label": "Text"},
	{"id": "marker", "label": "Markers"},
	{"id": "bin", "label": "Bin"},
	{"id": "effect", "label": "Effects"},
]
const KIND_LABELS: Dictionary = {"clip": "Clip", "marker": "Marker", "clip_marker": "Clip mark", "bin": "Bin", "effect": "Effect", "title": "Text"}
const MAX_RESULTS := 400

static var last_query: String = ""
static var last_replace: String = ""
static var match_case: bool = false
static var whole_word: bool = false
static var each_match: bool = false
static var in_selection: bool = false

var sheet: Control = null
var field: LineEdit = null
var replace_field: LineEdit = null
var list: Control = null
var foot: Label = null
var scope: String = "all"
var results: Array[Dictionary] = []
var _chips: Dictionary = {}
var _case_chip: Button = null
var _word_chip: Button = null
var _replace_one: Button = null
var _replace_all: Button = null
var _each_chip: Button = null
var _sel_chip: Button = null
var within: Dictionary = {}
var within_note: String = ""


static func open(host: Node) -> Node:
	var script: GDScript = load(SELF_PATH)
	var f: Node = script.new()
	f.call("build", host)
	return f


static func _hit(text: String, needle: String, opts: Dictionary = {}) -> bool:
	return TextFind.has_match(text, needle, bool(opts.get("case", false)), bool(opts.get("word", false)))


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


static func search(doc: Project, s: Sequence, query: String, kind: String = "all", opts: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var needle: String = query.strip_edges()
	if doc == null or needle.is_empty():
		return out
	var want_all: bool = kind == "all"
	if s != null:
		for t: Track in s.all_tracks():
			for c: Clip in t.clips:
				var cname: String = clip_name(doc, c)
				if (want_all or kind == "clip") and _hit(cname, needle, opts):
					out.append({"kind": "clip", "title": cname, "detail": t.label + " in " + s.label, "time": c.start, "clip_id": c.id, "media_id": c.media_id})
				if want_all or kind == "marker":
					for m: Marker in c.markers:
						if _hit(m.label, needle, opts) or _hit(m.comment, needle, opts):
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
						if _hit(ename, needle, opts):
							out.append({"kind": "effect", "title": ename, "detail": "on " + cname + ", " + t.label, "time": c.start, "clip_id": c.id, "media_id": c.media_id})
				if out.size() >= MAX_RESULTS:
					return out
		if want_all or kind == "marker":
			for m: Marker in s.markers:
				if _hit(m.label, needle, opts) or _hit(m.comment, needle, opts):
					var mdetail: String = m.kind + " marker"
					if not m.label.is_empty() and not m.comment.is_empty():
						mdetail += ", " + m.comment
					out.append({"kind": "marker", "title": m.label if not m.label.is_empty() else m.comment, "detail": mdetail, "time": m.time, "clip_id": "", "media_id": ""})
	if want_all or kind == "title":
		out.append_array(TextFind.search(doc, needle, opts))
	if want_all or kind == "bin":
		for m: MediaItem in doc.media:
			if _hit(m.label, needle, opts):
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
	var want_seq: String = String(r.get("seq_id", ""))
	if not want_seq.is_empty() and (s == null or s.id != want_seq) and doc.sequence_by_id(want_seq) != null:
		Session.set_sequence(want_seq)
		s = doc.sequence_by_id(want_seq)
	if s == null:
		return false
	var t: float = float(r.get("time", 0.0))
	if t >= 0.0:
		Session.set_playhead(t)
	var cid: String = String(r.get("clip_id", ""))
	if not cid.is_empty() and s.clip_by_id(cid) != null:
		Verbs.select(doc, s, PackedStringArray([cid]), "replace")
		if kind == "title":
			_open_title(s, cid)
	if kind == "effect":
		_show_panel("effect_controls")
	return true


static func _open_title(s: Sequence, clip_id: String) -> void:
	_show_panel("source")
	var src: Object = Bus.instance().panel("source")
	if src != null and src.has_method("open_title"):
		src.call("open_title", s.id, clip_id)


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
	var picked: Dictionary = selection_scope(Session.doc, Session.seq())
	within = picked.get("within", {})
	within_note = String(picked.get("note", ""))
	sheet = Sheet.open(host, "Find", 620.0, 500.0, 120.0)
	sheet.set("close_on_veil", true)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	field = PmUI.line_edit("Clip names, title text, markers, bin items, effects")
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var how: HBoxContainer = PmUI.hbox()
	_case_chip = PmButton.make("Match case", "", true)
	_case_chip.button_pressed = match_case
	_case_chip.focus_mode = Control.FOCUS_NONE
	_case_chip.pressed.connect(_on_case)
	PmUI.tip(_case_chip, "Off, a search for cat finds Cat and CAT")
	how.add_child(_case_chip)
	_word_chip = PmButton.make("Whole word", "", true)
	_word_chip.button_pressed = whole_word
	_word_chip.focus_mode = Control.FOCUS_NONE
	_word_chip.pressed.connect(_on_word)
	PmUI.tip(_word_chip, "On, a search for cat skips cats and concat")
	how.add_child(_word_chip)
	_each_chip = PmButton.make("Each match", "", true)
	_each_chip.name = "EachMatch"
	_each_chip.button_pressed = each_match
	_each_chip.focus_mode = Control.FOCUS_NONE
	_each_chip.pressed.connect(_on_each)
	PmUI.tip(_each_chip, "On, every match in a title is its own row, so Replace changes just that one")
	how.add_child(_each_chip)
	_sel_chip = PmButton.make("In selection", "", true)
	_sel_chip.name = "InSelection"
	_sel_chip.button_pressed = in_selection
	_sel_chip.focus_mode = Control.FOCUS_NONE
	_sel_chip.pressed.connect(_on_sel)
	PmUI.tip(_sel_chip, "On, title text is only searched and replaced inside what was selected when Find opened: the selected letters of a text, or else the selected clips")
	how.add_child(_sel_chip)
	how.add_child(PmUI.spacer())
	col.add_child(how)
	var swap: HBoxContainer = PmUI.hbox()
	replace_field = PmUI.line_edit("Replace the text with")
	replace_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replace_field.text = last_replace
	replace_field.text_changed.connect(_on_replace_text)
	swap.add_child(replace_field)
	_replace_one = PmButton.make("Replace", "", false)
	_replace_one.pressed.connect(_on_replace_one)
	swap.add_child(_replace_one)
	_replace_all = PmButton.make("Replace all", "", false)
	_replace_all.pressed.connect(_on_replace_all)
	swap.add_child(_replace_all)
	col.add_child(swap)
	list = SheetList.make(36.0, true, 76.0)
	list.set("empty_text", "Type to search the open sequence, every title's text and the bin")
	list.connect("activated", _on_activated)
	list.connect("cursor_moved", _on_cursor)
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


func how_opts() -> Dictionary:
	var out: Dictionary = {"case": match_case, "word": whole_word, "each": each_match}
	if in_selection:
		out["within"] = within if not within.is_empty() else {"": Vector2i(-1, -1)}
	return out


static func selection_scope(doc: Project, s: Sequence) -> Dictionary:
	if doc == null or s == null:
		return {}
	var bus: Object = Bus.instance()
	var pp: Object = bus.call("panel", "program") if bus != null else null
	if pp != null and pp.has_method("monitor_text_edit"):
		var te: RefCounted = pp.call("monitor_text_edit")
		if te != null and bool(te.call("editing")) and bool(te.call("has_selection")):
			return {"within": {String(te.get("clip_id")): te.call("selection")}, "note": "the selected letters"}
	var pop: GDScript = load("res://modules/core_panels/text_popout.gd")
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		for n: Node in (loop as SceneTree).root.find_children("TitleEditor", "", true, false):
			var ed: Variant = n.get("_edit")
			var cid: String = String(n.get("clip_id")) if n.get("clip_id") != null else ""
			if ed is TextEdit and (ed as TextEdit).has_selection() and not cid.is_empty() and s.clip_by_id(cid) != null:
				return {"within": {cid: pop.call("selection_of", ed)}, "note": "the selected letters"}
	var ec: Object = bus.call("panel", "effect_controls") if bus != null else null
	var picked_clip: Clip = Bus.selected_clip(s)
	if ec != null and ec.has_method("_row_for") and picked_clip != null:
		var r: Dictionary = ec.call("_row_for", "props.text")
		var eds: Array = r.get("editors", []) if not r.is_empty() else []
		if not eds.is_empty() and eds[0] is TextEdit and is_instance_valid(eds[0]) and (eds[0] as TextEdit).has_selection():
			return {"within": {picked_clip.id: pop.call("selection_of", eds[0])}, "note": "the selected letters"}
	var ids: Dictionary = {}
	for id: String in s.selected_clip_ids:
		var c: Clip = s.clip_by_id(id)
		var m: MediaItem = doc.media_by_id(c.media_id) if c != null else null
		if m != null and m.kind == TextFind.KIND:
			ids[id] = Vector2i(-1, -1)
	if ids.is_empty():
		return {}
	return {"within": ids, "note": "the selected clip" if ids.size() == 1 else "the %d selected clips" % ids.size()}


func _on_each() -> void:
	each_match = _each_chip.button_pressed
	refresh()
	field.grab_focus()


func _on_sel() -> void:
	in_selection = _sel_chip.button_pressed
	refresh()
	field.grab_focus()


func refresh(keep: bool = false) -> void:
	var doc: Project = Session.doc
	var s: Sequence = Session.seq()
	var q: String = field.text
	last_query = q
	results = search(doc, s, q, scope, how_opts())
	var fps: float = s.fps if s != null and s.fps > 0.0 else 30.0
	var rows: Array[Dictionary] = []
	var text_hits: int = 0
	for r: Dictionary in results:
		var t: float = float(r["time"])
		if String(r["kind"]) == TextFind.KIND:
			text_hits += 1
		rows.append({"lead": String(KIND_LABELS.get(String(r["kind"]), "")), "title": String(r["title"]), "detail": String(r["detail"]), "right": Timecode.format(t, fps, s != null and s.drop_frame) if t >= 0.0 else ""})
	list.call("set_rows", rows, keep)
	_sync_replace(text_hits)
	var where: String = ""
	if in_selection:
		where = ("    Text only in " + within_note) if not within.is_empty() else "    Nothing was selected when Find opened"
	if q.strip_edges().is_empty():
		foot.text = "Enter jumps the playhead and selects it" + where
	else:
		var n: int = results.size()
		foot.text = ("Nothing found" if n == 0 else (str(n) + " found")) + "    Enter jumps the playhead and selects it" + where


func _sync_replace(text_hits: int) -> void:
	if _replace_all == null or _replace_one == null:
		return
	_replace_all.text = "Replace all" if text_hits == 0 else "Replace all (%d)" % text_hits
	_replace_all.disabled = text_hits == 0
	_replace_one.disabled = _cursor_hit().is_empty()


func _cursor_hit() -> Dictionary:
	if list == null:
		return {}
	var i: int = int(list.get("cursor"))
	if i < 0 or i >= results.size():
		return {}
	var r: Dictionary = results[i]
	return r if String(r.get("kind", "")) == TextFind.KIND else {}


func _on_cursor(_index: int) -> void:
	if _replace_one != null:
		_replace_one.disabled = _cursor_hit().is_empty()


func _on_case() -> void:
	match_case = _case_chip.button_pressed
	refresh()
	field.grab_focus()


func _on_word() -> void:
	whole_word = _word_chip.button_pressed
	refresh()
	field.grab_focus()


func _on_replace_text(t: String) -> void:
	last_replace = t


func replace_one() -> bool:
	var r: Dictionary = _cursor_hit()
	if r.is_empty():
		return false
	var needle: String = field.text.strip_edges()
	var done: bool = TextFind.replace_one(Session.doc, r, needle, replace_field.text, how_opts())
	if done:
		var n: int = 1 if r.get("only") is Vector2i else (r.get("ranges", []) as Array).size()
		_grow_span(String(r.get("clip_id", "")), n * (replace_field.text.length() - needle.length()))
	refresh(true)
	return done


func replace_all() -> bool:
	var needle: String = field.text.strip_edges()
	var counts: Dictionary = {}
	if in_selection:
		for r: Dictionary in results:
			if String(r.get("kind", "")) == TextFind.KIND and String(r.get("slot", "")) != TextFind.SLOT_KEY:
				var cid: String = String(r.get("clip_id", ""))
				counts[cid] = int(counts.get(cid, 0)) + (r.get("ranges", []) as Array).size()
	var done: bool = TextFind.replace_all(Session.doc, needle, replace_field.text, how_opts())
	if done:
		for cid2: String in counts.keys():
			_grow_span(cid2, int(counts[cid2]) * (replace_field.text.length() - needle.length()))
	refresh()
	return done


func _grow_span(clip_id: String, delta: int) -> void:
	if delta == 0 or not within.has(clip_id):
		return
	var sp: Vector2i = within[clip_id]
	if sp.x >= 0:
		within[clip_id] = Vector2i(sp.x, maxi(sp.x, sp.y + delta))


func _on_replace_one() -> void:
	replace_one()
	field.grab_focus()


func _on_replace_all() -> void:
	replace_all()
	field.grab_focus()


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

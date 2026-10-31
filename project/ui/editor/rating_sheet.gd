extends Node

signal changed

const Cards := preload("res://doc/project_cards.gd")
const Project := preload("res://doc/project.gd")
const Sheet := preload("res://modules/core_panels/sheet.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const SELF_PATH := "res://ui/editor/rating_sheet.gd"
const WIDTH := 560.0

var path: String = ""
var facts: Dictionary = {}
var others: PackedStringArray = PackedStringArray()
var doc: Project = null
var rating: Dictionary = {}
var sheet: Control = null
var _rows: VBoxContainer = null
var _preset_drop: Button = null
var _overall: Label = null
var _view: Control = null


static func open(host: Node, p_path: String, p_facts: Dictionary, p_others: PackedStringArray = PackedStringArray(), p_doc: Project = null) -> Node:
	var s: Node = (load(SELF_PATH) as GDScript).new()
	s.call("build", host, p_path, p_facts, p_others, p_doc)
	return s


func build(host: Node, p_path: String, p_facts: Dictionary, p_others: PackedStringArray, p_doc: Project) -> void:
	name = "RatingSheet"
	path = p_path
	facts = p_facts
	others = p_others
	doc = p_doc
	_view = host as Control if host is Control and host.has_method("rebuild") else null
	rating = Cards.rating_of(path, facts)
	sheet = Sheet.open(host, "Rate " + String(facts.get("name", path.get_file().get_basename())), WIDTH)
	sheet.add_child(self)
	var col: VBoxContainer = sheet.get("col")
	var head: HBoxContainer = PmUI.hbox()
	col.add_child(head)
	head.add_child(PmLabel.body("Sections from"))
	_preset_drop = PmDrop.make_drop(_preset_choices(), String(rating["preset"]))
	_preset_drop.connect("changed", _on_preset)
	_preset_drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_preset_drop)
	_overall = PmLabel.headline("")
	col.add_child(_overall)
	_rows = PmUI.vbox(4)
	col.add_child(_rows)
	var add_row: HBoxContainer = PmUI.hbox()
	col.add_child(add_row)
	var own: LineEdit = PmUI.line_edit("A section of my own")
	own.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(own)
	var add_own: Button = PmButton.make("Add to this project", "plus")
	add_own.pressed.connect(func() -> void:
		add_own_section(own.text)
		own.text = ""
	)
	add_row.add_child(add_own)
	var add_preset_b: Button = PmButton.make("Add to the preset")
	add_preset_b.set("quiet", true)
	add_preset_b.pressed.connect(func() -> void:
		Cards.add_section(String(rating["preset"]), own.text)
		own.text = ""
		rebuild()
	)
	add_row.add_child(add_preset_b)
	var preset_row: HBoxContainer = PmUI.hbox()
	col.add_child(preset_row)
	var new_preset: LineEdit = PmUI.line_edit("New preset name")
	new_preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_row.add_child(new_preset)
	var make_b: Button = PmButton.make("Save as a new preset")
	make_b.pressed.connect(func() -> void:
		var p: Dictionary = save_as_preset(new_preset.text)
		if not p.is_empty():
			new_preset.text = ""
			_preset_drop.call("set_choices", _preset_choices())
			_preset_drop.call("set_value", String(p["id"]), false)
			_save()
			rebuild()
	)
	preset_row.add_child(make_b)
	if not others.is_empty():
		var apply_b: Button = sheet.call("add_button", "Use this preset on every listed project")
		apply_b.pressed.connect(func() -> void:
			Cards.apply_preset(others, String(rating["preset"]), _facts_of_all(), doc)
			_refresh_view()
		)
	var done_b: Button = sheet.call("add_button", "Done", true)
	done_b.pressed.connect(func() -> void: sheet.call("close"))
	rebuild()


func save_as_preset(name_text: String) -> Dictionary:
	var p: Dictionary = Cards.add_preset(name_text, String(rating["preset"]))
	if p.is_empty():
		return p
	var pid: String = String(p["id"])
	var remap: Dictionary = {}
	for s: Variant in rating["own"]:
		var sd: Dictionary = s
		var nid: String = Cards.add_section(pid, String(sd.get("name", "")))
		if not nid.is_empty():
			remap[String(sd["id"])] = nid
	for id: Variant in rating["off"]:
		Cards.set_section_on(pid, String(id), false)
	var scores: Dictionary = {}
	for k: Variant in (rating["scores"] as Dictionary).keys():
		scores[String(remap.get(String(k), String(k)))] = rating["scores"][k]
	rating = {"preset": pid, "scores": scores, "off": [], "own": []}
	return p


func _facts_of_all() -> Dictionary:
	var out: Dictionary = {}
	for p: String in others:
		out[Cards.key_of(p)] = Cards.cached(p)
	return out


func _preset_choices() -> Array:
	var out: Array = []
	for p: Variant in Cards.presets():
		out.append(PmDrop.choice(String((p as Dictionary)["id"]), String((p as Dictionary)["name"])))
	return out


func _on_preset(id: String) -> void:
	rating["preset"] = id
	_save()
	rebuild()


func _save() -> void:
	Cards.save_rating(path, rating, doc)
	changed.emit()
	_refresh_view()


func _refresh_view() -> void:
	if _view != null and is_instance_valid(_view):
		_view.call("rebuild")


func add_own_section(text: String) -> String:
	var n: String = text.strip_edges()
	if n.is_empty():
		return ""
	var id: String = "own" + str(Time.get_ticks_usec())
	(rating["own"] as Array).append({"id": id, "name": n, "on": true})
	_save()
	rebuild()
	return id


func set_score(section_id: String, score: float) -> void:
	rating = Cards.set_score(rating, section_id, score)
	_save()
	rebuild()


func toggle_off(section_id: String) -> void:
	var off: Array = rating["off"]
	if off.has(section_id):
		off.erase(section_id)
	else:
		off.append(section_id)
	_save()
	rebuild()


func rebuild() -> void:
	if _rows == null:
		return
	PmUI.clear(_rows)
	var all: Array = []
	for s: Variant in Cards.preset(String(rating["preset"]))["sections"]:
		if bool((s as Dictionary).get("on", true)):
			all.append(s)
	all.append_array(rating["own"])
	var off: Array = rating["off"]
	var scores: Dictionary = rating["scores"]
	for s: Variant in all:
		var sd: Dictionary = s
		var id: String = String(sd["id"])
		var row: HBoxContainer = PmUI.hbox()
		_rows.add_child(row)
		var on := CheckBox.new()
		on.button_pressed = not off.has(id)
		on.focus_mode = Control.FOCUS_NONE
		on.toggled.connect(func(_v: bool) -> void: toggle_off(id))
		row.add_child(on)
		var l: Label = PmLabel.body(String(sd["name"]), "text" if not off.has(id) else "text_faint")
		l.custom_minimum_size.x = 160.0
		row.add_child(l)
		var stars := StarRow.new()
		stars.score = float(scores.get(id, -1.0))
		stars.custom_minimum_size = Vector2(200.0, 24.0)
		stars.connect("picked", func(v: float) -> void: set_score(id, v))
		row.add_child(stars)
		var clear_b: Button = PmButton.make("Clear")
		clear_b.set("quiet", true)
		clear_b.pressed.connect(func() -> void: set_score(id, -1.0))
		row.add_child(clear_b)
	var o: float = Cards.overall(rating)
	_overall.text = ("Overall %.1f out of 10" % o) if o >= 0.0 else "Not rated yet"


class StarRow:
	extends Control

	signal picked(v: float)

	var score: float = -1.0
	var _hover: float = -1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_input)
		mouse_exited.connect(func() -> void:
			_hover = -1.0
			queue_redraw()
		)

	func value_at(x: float) -> float:
		return clampf(ceil(x / 20.0 * 2.0) / 2.0 * 2.0, 1.0, 10.0)

	func _on_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			_hover = value_at((event as InputEventMouseMotion).position.x)
			queue_redraw()
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			picked.emit(value_at((event as InputEventMouseButton).position.x))
			accept_event()

	func _draw() -> void:
		var show: float = _hover if _hover >= 0.0 else score
		for i: int in 5:
			var c: Vector2 = Vector2(float(i) * 20.0 + 10.0, size.y * 0.5)
			var fill: float = clampf(show / 2.0 - float(i), 0.0, 1.0) if show >= 0.0 else 0.0
			_star(c, 8.0, Tk.c["border_soft"])
			if fill > 0.0:
				_star(c, 8.0 * (0.45 + 0.55 * fill), Color(0.98, 0.78, 0.3))
		var text: String = ("%.1f" % show) if show >= 0.0 else "-"
		PmText.draw_at(self, Tk.font("body"), Vector2(108.0, size.y * 0.5 + 5.0), text, Tk.fs(Tk.sz("font_small")), Tk.c["text_dim"])

	func _star(c: Vector2, r: float, col: Color) -> void:
		var pts: PackedVector2Array = PackedVector2Array()
		for k: int in 10:
			var ang: float = -PI * 0.5 + float(k) * PI / 5.0
			var rr: float = r if k % 2 == 0 else r * 0.45
			pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
		draw_colored_polygon(pts, col)

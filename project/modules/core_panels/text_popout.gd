extends RefCounted

const SELF_PATH := "res://modules/core_panels/text_popout.gd"
const TitleEditor := preload("res://modules/core_panels/title_editor.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const TextRuns := preload("res://doc/text_runs.gd")
const Verbs := preload("res://doc/verbs.gd")
const TextAnimators := preload("res://doc/text_animators.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const LetterRig := preload("res://doc/letter_rig.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const FontMenu := preload("res://modules/core_panels/font_menu.gd")
const OWNER := "core_panels"
const CMD_ID := "view.text_popout"
const PREF_OPEN := "ui.text_popout_open"
const WINDOW_KEY := "text_popout"
const WINDOW_TITLE := "Text"
const WINDOW_SIZE := Vector2(420.0, 320.0)
const RUNS_PATH := "props.runs"
const EDIT_NAME := "TitleText"
const BAR_NAME := "RunStyleBar"
const PENDING_NOTE := "Nothing picked: this changes what you type next"
const PICKED_NOTE := "%d letters picked"
const NO_TEXT_NOTE := "Pick part of the text to change only that part"

static var _window: Control = null
static var _editor: Control = null
static var _pending: Dictionary = {}


static func ensure_prefs(prefs: Node) -> void:
	if prefs == null:
		return
	if not bool(prefs.call("is_registered", PREF_OPEN)):
		prefs.call("register", PREF_OPEN, false, {"label": "Keep the text editor popped out", "type": "bool"})


static func register_all() -> void:
	ensure_prefs(Prefs)
	if Cmd == null:
		return
	var script: GDScript = load(SELF_PATH)
	var cat: Dictionary = Cmd.catalogue()
	var label: String = "Pop out the text editor"
	var category: String = "View"
	if cat.has(CMD_ID):
		label = String(cat[CMD_ID]["label"])
		category = String(cat[CMD_ID]["category"])
	Cmd.register(CMD_ID, {"label": label, "category": category, "scope": "global", "handler": Callable(script, "toggle"), "owner": OWNER, "toggle": Callable(script, "is_open")})


static func is_open() -> bool:
	return _window != null and is_instance_valid(_window) and _window.is_inside_tree()


static func editor() -> Control:
	if is_open():
		return _editor
	return null


static func wants_open() -> bool:
	return Prefs.is_registered(PREF_OPEN) and bool(Prefs.get_value(PREF_OPEN))


static func host_node() -> Node:
	var p: Object = Bus.instance().panel("source")
	if p != null and p.has_method("root"):
		var r: Variant = p.call("root")
		if r is Control and (r as Control).is_inside_tree():
			return r
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root
	return null


static func toggle() -> void:
	if is_open():
		close()
		return
	open(host_node())


static func restore(host: Node) -> void:
	if wants_open() and not is_open():
		open(host)


static func open(host: Node) -> Control:
	ensure_prefs(Prefs)
	if is_open():
		_window.call("raise")
		return _window
	if host == null or not host.is_inside_tree():
		return null
	_editor = TitleEditor.new()
	_editor.set("follow_selection", true)
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var edit: TextEdit = _editor.find_child(EDIT_NAME, true, false) as TextEdit
	if edit != null:
		var bar: Control = selection_bar(edit, _editor)
		bar.visible = false
		_editor.add_child(bar)
		_editor.move_child(bar, edit.get_index() + 1)
	var body: MarginContainer = PmUI.inset(_editor, 4.0, 6.0)
	_window = PmWindow.open(host, WINDOW_TITLE, body, WINDOW_SIZE, WINDOW_KEY)
	if _window == null:
		_editor = null
		return null
	_window.connect("closed", Callable(load(SELF_PATH), "_on_closed"))
	Prefs.set_value(PREF_OPEN, true)
	return _window


static func close() -> void:
	if not is_open():
		_clear()
		return
	_window.call("close")
	_clear()


static func _on_closed() -> void:
	ensure_prefs(Prefs)
	Prefs.set_value(PREF_OPEN, false)
	_clear()


static func _clear() -> void:
	_window = null
	_editor = null


static func bind_clip(sequence_id: String, clip_id: String) -> void:
	if _editor != null and is_instance_valid(_editor):
		_editor.call("set_target", sequence_id, clip_id)


static func pending() -> Dictionary:
	return _pending.duplicate(true)


static func set_pending(patch: Dictionary) -> void:
	for k: Variant in patch.keys():
		var name_: String = String(k)
		if not TextRuns.STYLE_KEYS.has(name_):
			continue
		if patch[k] == null:
			_pending.erase(name_)
		else:
			_pending[name_] = patch[k]


static func clear_pending() -> void:
	_pending.clear()


static func offset_of(edit: TextEdit, line: int, col: int) -> int:
	if edit == null:
		return 0
	var n: int = 0
	var upto: int = clampi(line, 0, maxi(edit.get_line_count() - 1, 0))
	for i: int in upto:
		n += edit.get_line(i).length() + 1
	return n + maxi(col, 0)


static func selection_of(edit: TextEdit) -> Vector2i:
	if edit == null or not edit.has_selection():
		return Vector2i(-1, -1)
	var a: int = offset_of(edit, edit.get_selection_from_line(), edit.get_selection_from_column())
	var b: int = offset_of(edit, edit.get_selection_to_line(), edit.get_selection_to_column())
	return Vector2i(mini(a, b), maxi(a, b))


static func title_props(doc: Project, c: Clip) -> Dictionary:
	if c == null:
		return {}
	var m: MediaItem = doc.media_by_id(c.media_id) if doc != null else null
	return TitleStyle.merged("title", m.props if m != null else {}, c.props)


static func runs_of(doc: Project, c: Clip) -> Array[Dictionary]:
	return TextRuns.for_props(title_props(doc, c), TitleEditor.text_of(doc, c))


static func write_runs(doc: Project, seq: Sequence, clip_id: String, runs: Array, at: float) -> bool:
	if doc == null or seq == null:
		return false
	return Verbs.set_clip_param(doc, seq, clip_id, RUNS_PATH, TextRuns.encode(runs), at, false)


static func apply_range(doc: Project, seq_id: String, clip_id: String, from: int, to: int, patch: Dictionary, at: float = -1.0) -> bool:
	if doc == null or patch.is_empty():
		return false
	var seq: Sequence = doc.sequence_by_id(seq_id)
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if c == null:
		return false
	if mini(from, to) == maxi(from, to):
		set_pending(patch)
		return false
	return write_runs(doc, seq, clip_id, TextRuns.apply(runs_of(doc, c), from, to, patch), at)


static func apply_selection(doc: Project, seq_id: String, clip_id: String, edit: TextEdit, patch: Dictionary, at: float = -1.0) -> bool:
	var sel: Vector2i = selection_of(edit)
	if sel.x < 0 or sel.x == sel.y:
		set_pending(patch)
		return false
	return apply_range(doc, seq_id, clip_id, sel.x, sel.y, patch, at)


static func typed_span(before: String, after: String) -> Vector2i:
	if before == after:
		return Vector2i(-1, -1)
	var shortest: int = mini(before.length(), after.length())
	var pre: int = 0
	while pre < shortest and before.unicode_at(pre) == after.unicode_at(pre):
		pre += 1
	var suf: int = 0
	while suf < shortest - pre and before.unicode_at(before.length() - 1 - suf) == after.unicode_at(after.length() - 1 - suf):
		suf += 1
	var to: int = after.length() - suf
	if to <= pre:
		return Vector2i(-1, -1)
	return Vector2i(pre, to)


static func apply_typed(doc: Project, seq_id: String, clip_id: String, before: String, after: String, at: float = -1.0) -> bool:
	if _pending.is_empty() or doc == null:
		return false
	var span: Vector2i = typed_span(before, after)
	if span.x < 0:
		return false
	var seq: Sequence = doc.sequence_by_id(seq_id)
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if c == null:
		return false
	var runs: Array[Dictionary] = TextRuns.for_props(title_props(doc, c), after)
	return write_runs(doc, seq, clip_id, TextRuns.apply(runs, span.x, span.y, _pending), at)


static func shift_picks(doc: Project, seq_id: String, clip_id: String, before: String, after: String) -> int:
	if doc == null or before == after:
		return 0
	var seq: Sequence = doc.sequence_by_id(seq_id)
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if c == null:
		return 0
	var shortest: int = mini(before.length(), after.length())
	var pre: int = 0
	while pre < shortest and before.unicode_at(pre) == after.unicode_at(pre):
		pre += 1
	var suf: int = 0
	while suf < shortest - pre and before.unicode_at(before.length() - 1 - suf) == after.unicode_at(after.length() - 1 - suf):
		suf += 1
	var removed: int = before.length() - pre - suf
	var added: int = after.length() - pre - suf
	var moves: Dictionary = TextAnimators.shifted_picks(title_props(doc, c), pre, removed, added)
	for k: Variant in moves.keys():
		var path: String = "props." + String(k)
		var cur: Variant = c.props.get(String(k))
		var keyed: bool = cur is Dictionary and AnimProp.is_animated(cur)
		Verbs.set_clip_param(doc, seq, clip_id, path, moves[k], seq.playhead if keyed else -1.0, true)
	var rig: Dictionary = LetterRig.remapped(c.props, before, after, pre, removed, added)
	if not rig.is_empty():
		doc.undo.live(ClipCmds.SetClipField.new(seq.id, clip_id, "props", rig))
	var paras: Variant = (load("res://doc/text_paragraphs.gd") as GDScript).call("remapped", c.props.get("para_align", null), before, after)
	if paras != null:
		Verbs.set_clip_param(doc, seq, clip_id, "props.para_align", paras, -1.0, true)
	return moves.size() + (1 if not rig.is_empty() else 0) + (1 if paras != null else 0)


static func value_in(doc: Project, seq_id: String, clip_id: String, from: int, to: int, key: String) -> Variant:
	var seq: Sequence = doc.sequence_by_id(seq_id) if doc != null else null
	var c: Clip = seq.clip_by_id(clip_id) if seq != null else null
	if c == null:
		return null
	var props: Dictionary = title_props(doc, c)
	var fallback: Variant = TextRuns.plain(props.get(key, null))
	if mini(from, to) == maxi(from, to):
		return _pending.get(key, fallback)
	return TextRuns.common_value(runs_of(doc, c), from, to, key, fallback)


static func selection_bar(edit: TextEdit, editor: Control = null) -> Control:
	var bar: Control = _RunBar.new()
	bar.name = BAR_NAME
	bar.set("edit", edit)
	bar.set("editor", editor)
	return bar


static func bar_in(host: Control) -> Control:
	if host == null:
		return null
	return host.find_child(BAR_NAME, true, false) as Control


class _RunBar:
	extends VBoxContainer

	var edit: TextEdit = null
	var editor: Control = null
	var doc: Project = null
	var seq_id: String = ""
	var clip_id: String = ""

	var _note: Label = null
	var _bold: Button = null
	var _italic: Button = null
	var _colour: ColorPickerButton = null
	var _size: Control = null
	var _font: Button = null
	var _clear: Button = null
	var _quiet: bool = false

	static var _api: GDScript = null

	func api() -> GDScript:
		if _api == null:
			_api = load(SELF_PATH)
		return _api

	func _init() -> void:
		_build()

	func _build() -> void:
		add_theme_constant_override("separation", int(Tk.px(2.0)))
		_note = PmLabel.trim(NO_TEXT_NOTE, "text_faint")
		_note.name = "RunNote"
		add_child(_note)
		var row: HBoxContainer = PmUI.hbox(Tk.px(2.0))
		_bold = PmButton.ghost("B", "", true)
		_bold.name = "RunBold"
		PmUI.tip(_bold, "Bold, on the part you picked")
		_bold.toggled.connect(_on_bold)
		row.add_child(_bold)
		_italic = PmButton.ghost("I", "", true)
		_italic.name = "RunItalic"
		PmUI.tip(_italic, "Italic, on the part you picked")
		_italic.toggled.connect(_on_italic)
		row.add_child(_italic)
		_colour = ColorPickerButton.new()
		_colour.name = "RunColour"
		_colour.custom_minimum_size = Vector2(float(Tk.px(48.0)), float(Tk.px(20.0)))
		PmUI.tip(_colour, "The colour of the part you picked")
		_colour.popup_closed.connect(_on_colour)
		row.add_child(_colour)
		_size = PmField.make(72.0, 4.0, 2000.0, 1.0)
		_size.name = "RunSize"
		_size.custom_minimum_size = Vector2(float(Tk.px(64.0)), 0.0)
		PmUI.tip(_size, "The size of the part you picked")
		_size.connect("value_changed", _on_size)
		row.add_child(_size)
		_font = PmButton.make("Font", "chev_d")
		_font.name = "RunFont"
		_font.set("quiet", true)
		PmUI.tip(_font, "The font of the part you picked")
		_font.pressed.connect(_on_font)
		row.add_child(_font)
		_clear = PmButton.make("Back to the title's look", "")
		_clear.name = "RunClear"
		_clear.set("quiet", true)
		PmUI.tip(_clear, "Drop the separate look from the part you picked")
		_clear.pressed.connect(_on_clear)
		row.add_child(_clear)
		row.add_child(PmUI.spacer())
		add_child(row)

	func _ready() -> void:
		if edit != null and not edit.caret_changed.is_connected(refresh):
			edit.caret_changed.connect(refresh)
		refresh()

	func show_for(d: Project, sequence_id: String, id: String) -> void:
		doc = d
		seq_id = sequence_id
		clip_id = id
		visible = d != null and not id.is_empty()
		refresh()

	func _target() -> Clip:
		if editor != null and is_instance_valid(editor):
			seq_id = String(editor.get("seq_id"))
			clip_id = String(editor.get("clip_id"))
			doc = Session.doc
		var seq: Sequence = doc.sequence_by_id(seq_id) if doc != null else null
		return seq.clip_by_id(clip_id) if seq != null else null

	func span() -> Vector2i:
		var sel: Vector2i = api().call("selection_of", edit)
		return sel if sel.x >= 0 else Vector2i(0, 0)

	func value(sel: Vector2i, key: String) -> Variant:
		return api().call("value_in", doc, seq_id, clip_id, sel.x, sel.y, key)

	func refresh() -> void:
		if _note == null:
			return
		var c: Clip = _target()
		var sel: Vector2i = span()
		var picked: int = sel.y - sel.x
		if editor != null and is_instance_valid(editor):
			visible = c != null
		if c == null:
			_note.text = NO_TEXT_NOTE
		elif picked > 0:
			_note.text = PICKED_NOTE % picked
		else:
			_note.text = PENDING_NOTE
		for b: Button in [_bold, _italic, _colour, _font, _clear]:
			if b != null:
				b.disabled = c == null
		if c == null:
			return
		_quiet = true
		_bold.set_pressed_no_signal(value(sel, "bold") == true)
		_italic.set_pressed_no_signal(value(sel, "italic") == true)
		var col: Variant = value(sel, "colour")
		if col != null and not _colour.get_popup().visible:
			_colour.color = TitleStyle.colour_of(col, Color.WHITE)
		var sz: Variant = value(sel, "size")
		if (sz is float or sz is int) and _size.get("_editor") == null:
			_size.set("value", float(sz))
		var fn: Variant = value(sel, "font")
		_font.text = FontMenu.shown_name(String(fn)) if fn is String else "Mixed"
		_quiet = false

	func _write(patch: Dictionary) -> bool:
		if _quiet:
			return false
		var c: Clip = _target()
		if c == null:
			return false
		var sel: Vector2i = span()
		var at: float = Bus.instance().key_time_for(c, RUNS_PATH, Session.playhead())
		var ok: bool = bool(api().call("apply_range", doc, seq_id, clip_id, sel.x, sel.y, patch, at))
		refresh()
		return ok

	func _on_bold(on: bool) -> void:
		_write({"bold": on})

	func _on_italic(on: bool) -> void:
		_write({"italic": on})

	func _on_colour() -> void:
		var c: Color = _colour.color
		_write({"colour": [c.r, c.g, c.b, c.a]})

	func _on_size(v: float) -> void:
		_write({"size": v})

	func _on_clear() -> void:
		var patch: Dictionary = {}
		for k: String in TextRuns.STYLE_KEYS:
			patch[k] = null
		var c: Clip = _target()
		if c == null:
			return
		var sel: Vector2i = span()
		if sel.x == sel.y:
			api().call("clear_pending")
			refresh()
			return
		var at: float = Bus.instance().key_time_for(c, RUNS_PATH, Session.playhead())
		api().call("apply_range", doc, seq_id, clip_id, sel.x, sel.y, patch, at)
		refresh()

	func _on_font() -> void:
		var c: Clip = _target()
		if c == null:
			return
		var items: Array = FontMenu.items(doc, FontMenu.font_of(doc, c))
		var menu: Control = PmMenu.open(_font, items)
		if menu != null and menu.is_inside_tree():
			menu.connect("picked", _on_font_pick)

	func _on_font_pick(id: String) -> void:
		if FontMenu.owns(id):
			return
		_write({"font": id})

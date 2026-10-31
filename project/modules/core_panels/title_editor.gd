extends VBoxContainer

signal popout_asked
signal target_changed(clip_id: String)

const Bus := preload("res://modules/core_panels/panel_bus.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Verbs := preload("res://doc/verbs.gd")
const Presets := preload("res://doc/presets.gd")
const Subtitles := preload("res://doc/subtitles.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const RunStrip := preload("res://modules/core_panels/subtitle_run_strip.gd")
const CharMenu := preload("res://modules/core_panels/subtitle_char_menu.gd")
const AnimatorUI := preload("res://modules/core_panels/text_animator_ui.gd")
const FontMenu := preload("res://modules/core_panels/font_menu.gd")
const DataText := preload("res://doc/data_text.gd")
const TokenComplete := preload("res://ui/kit/token_complete.gd")
const DATA_MENU := "data_tok:"
const ExtrasUI := preload("res://modules/core_panels/text_extras_ui.gd")
const FontLibrary := preload("res://doc/font_library.gd")
const TEXT_PATH := "props.text"
const MIN_LINES := 6
const LABEL_CAP := 48
const EDIT_LABEL := "Edit text"
const EMPTY_NOTE := "No text on this clip"
const ALIGNS: Array = [["left", "Left"], ["center", "Centre"], ["right", "Right"]]

var follow_selection: bool = false
var seq_id: String = ""
var clip_id: String = ""

var _edit: TextEdit = null
var _name_label: Label = null
var _count_label: Label = null
var _note_label: Label = null
var _popout_btn: Button = null
var _style_btn: Button = null
var _align_drop: Button = null
var _bold: Button = null
var _italic: Button = null
var _upper: Button = null
var _tools: HBoxContainer = null
var _strip: Control = null
var _char_btn: Button = null
var _animators: Control = null
var _font_btn: Button = null
var _extras: Control = null
var _font_row: HBoxContainer = null
var _font_note: Label = null
var _inert: bool = true
var _inert_painted: bool = false
var _updating: bool = false
var _live: bool = false
var _text_before: String = ""
var _bound_doc: Project = null


static func plain(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("v"):
			return plain(d["v"])
		if d.has("base"):
			return plain(d["base"])
		return null
	return v


static func text_of(doc: Project, c: Clip) -> String:
	if doc == null or c == null:
		return ""
	if c.props.has("text"):
		var own: Variant = plain(c.props["text"])
		if own != null:
			return String(own)
	var m: MediaItem = doc.media_by_id(c.media_id)
	if m != null and m.props.has("text"):
		var shared: Variant = plain(m.props["text"])
		if shared != null:
			return String(shared)
	return m.label if m != null else ""


static func is_title(doc: Project, c: Clip) -> bool:
	if doc == null or c == null:
		return false
	var m: MediaItem = doc.media_by_id(c.media_id)
	return m != null and m.kind == "title"


static func first_line(text: String) -> String:
	var line: String = text.split("\n")[0].strip_edges()
	if line.length() > LABEL_CAP:
		line = line.substr(0, LABEL_CAP).strip_edges()
	return line


static func counts_text(text: String) -> String:
	var chars: int = text.length()
	var lines: int = text.split("\n").size()
	var words: int = 0
	for raw: String in text.replace("\n", " ").replace("\t", " ").split(" "):
		if not raw.strip_edges().is_empty():
			words += 1
	return "%d characters, %d words, %d lines" % [chars, words, lines]


static func shared_count(doc: Project, seq: Sequence, media_id: String) -> int:
	if doc == null or seq == null or media_id.is_empty():
		return 0
	var n: int = 0
	for tr: Track in seq.all_tracks():
		for c: Clip in tr.clips:
			if c.media_id == media_id:
				n += 1
	return n


func _init() -> void:
	name = "TitleEditor"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", Tk.px(Tk.sz("gap")))
	_build()
	_apply_inert(true)


func _build() -> void:
	var head: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	_name_label = PmLabel.trim("Text", "text_bright")
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_name_label)
	_char_btn = PmButton.make(CharMenu.NONE_LABEL, "chev_d")
	_char_btn.name = "CharacterButton"
	_char_btn.set("quiet", true)
	PmUI.tip(_char_btn, "Who is speaking: put a saved character on this text, or save this look as one")
	_char_btn.pressed.connect(_on_char_pressed)
	head.add_child(_char_btn)
	_popout_btn = PmButton.make("", "float_panel")
	_popout_btn.set("quiet", true)
	PmUI.tip(_popout_btn, "Pop the text editor out so it stays open")
	_popout_btn.pressed.connect(_on_popout_pressed)
	head.add_child(_popout_btn)
	add_child(head)
	_edit = TextEdit.new()
	_edit.name = "TitleText"
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_edit.custom_minimum_size = Vector2(0.0, float(Tk.px(Tk.sz("row_h"))) * float(MIN_LINES))
	_edit.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_body")))
	_edit.text_changed.connect(_on_text_changed)
	_edit.focus_exited.connect(_on_focus_exited)
	TokenComplete.attach(_edit, _token_context)
	add_child(_edit)
	_count_label = PmLabel.trim("", "text_faint")
	add_child(_count_label)
	_tools = PmUI.hbox(Tk.px(2.0))
	_style_btn = PmButton.make("Style", "chev_d")
	_style_btn.set("quiet", true)
	PmUI.tip(_style_btn, "Put a saved text style on this text, or save this look as one")
	_style_btn.pressed.connect(_on_style_pressed)
	_tools.add_child(_style_btn)
	var data_btn: Button = PmButton.make("Data", "chev_d")
	data_btn.name = "DataButton"
	data_btn.set("quiet", true)
	PmUI.tip(data_btn, "Put live information in the text: when the clip under it was recorded (many date styles), its clock, its length, the file, and project facts such as editing time, clips and cuts")
	data_btn.pressed.connect(_on_data_pressed.bind(data_btn))
	_tools.add_child(data_btn)
	_bold = PmButton.ghost("B", "", true)
	PmUI.tip(_bold, "Bold")
	_bold.toggled.connect(_on_prop_toggled.bind("bold"))
	_tools.add_child(_bold)
	_italic = PmButton.ghost("I", "", true)
	PmUI.tip(_italic, "Italic")
	_italic.toggled.connect(_on_prop_toggled.bind("italic"))
	_tools.add_child(_italic)
	_upper = PmButton.ghost("AA", "", true)
	PmUI.tip(_upper, "Capitals")
	_upper.toggled.connect(_on_prop_toggled.bind("uppercase"))
	_tools.add_child(_upper)
	var align_choices: Array = []
	for pair: Array in ALIGNS:
		align_choices.append(PmDrop.choice(String(pair[0]), String(pair[1])))
	_align_drop = PmDrop.make_drop(align_choices, "center")
	PmUI.tip(_align_drop, "Which way the lines line up")
	_align_drop.connect("changed", _on_align_pick)
	_tools.add_child(_align_drop)
	_font_btn = PmButton.make(FontMenu.BUILT_IN, "chev_d")
	_font_btn.name = "FontButton"
	_font_btn.set("quiet", true)
	PmUI.tip(_font_btn, "The font: pick one, or import a font file for every project or this one")
	_font_btn.pressed.connect(_on_font_pressed)
	_tools.add_child(_font_btn)
	_tools.add_child(PmUI.spacer())
	add_child(_tools)
	_font_row = PmUI.hbox(Tk.px(4.0))
	_font_row.visible = false
	_font_note = PmLabel.wrap("", "text_faint")
	_font_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font_row.add_child(_font_note)
	var find_btn: Button = PmButton.make("Find the font file", "folder")
	find_btn.set("quiet", true)
	find_btn.pressed.connect(_on_find_font)
	_font_row.add_child(find_btn)
	add_child(_font_row)
	_note_label = PmLabel.wrap("", "text_faint")
	_note_label.visible = false
	add_child(_note_label)
	_strip = RunStrip.new()
	_strip.visible = false
	_strip.connect("box_picked", _on_strip_box_picked)
	add_child(_strip)
	_animators = AnimatorUI.new()
	_animators.visible = false
	add_child(_animators)
	_extras = ExtrasUI.new()
	_extras.visible = false
	add_child(_extras)


func _ready() -> void:
	if not Session.project_changed.is_connected(_on_project_changed):
		Session.project_changed.connect(_on_project_changed)
	if not Session.sequence_changed.is_connected(_on_sequence_changed):
		Session.sequence_changed.connect(_on_sequence_changed)
	_bind_doc()
	refresh()


func _exit_tree() -> void:
	finish_edit()


func _doc() -> Project:
	return Session.doc


func _bind_doc() -> void:
	var d: Project = _doc()
	if _bound_doc == d:
		return
	if _bound_doc != null and _bound_doc.changed.is_connected(_on_doc_changed):
		_bound_doc.changed.disconnect(_on_doc_changed)
	_bound_doc = d
	if d != null and not d.changed.is_connected(_on_doc_changed):
		d.changed.connect(_on_doc_changed)
	FontLibrary.use_project(d)


func _on_project_changed() -> void:
	_live = false
	seq_id = ""
	clip_id = ""
	_bind_doc()
	refresh()


func _on_sequence_changed(_id: String) -> void:
	refresh()


func _on_doc_changed(_kind: String) -> void:
	refresh()


func set_target(sequence_id: String, id: String) -> void:
	if seq_id == sequence_id and clip_id == id:
		refresh()
		return
	finish_edit()
	seq_id = sequence_id
	clip_id = id
	refresh()
	target_changed.emit(clip_id)


func _follow() -> void:
	if not follow_selection:
		return
	var d: Project = _doc()
	var live: Sequence = Session.seq()
	var want_seq: String = live.id if live != null else ""
	var want_clip: String = ""
	if d != null and live != null:
		var picked: Clip = Bus.selected_clip(live)
		if picked != null and is_title(d, picked):
			want_clip = picked.id
	if want_seq == seq_id and want_clip == clip_id:
		return
	finish_edit()
	seq_id = want_seq
	clip_id = want_clip
	target_changed.emit(clip_id)


func target_clip() -> Clip:
	var d: Project = _doc()
	if d == null or seq_id.is_empty() or clip_id.is_empty():
		return null
	var s: Sequence = d.sequence_by_id(seq_id)
	if s == null:
		return null
	var c: Clip = s.clip_by_id(clip_id)
	if c == null or not is_title(d, c):
		return null
	return c


func is_inert() -> bool:
	return _inert


func shown_text() -> String:
	return _edit.text


func focus_text() -> void:
	if _inert or _edit == null:
		return
	_edit.grab_focus()
	var last: int = maxi(_edit.get_line_count() - 1, 0)
	_edit.set_caret_line(last)
	_edit.set_caret_column(_edit.get_line(last).length())


func refresh() -> void:
	_follow()
	var d: Project = _doc()
	var c: Clip = target_clip()
	if d == null or c == null:
		_apply_inert(true)
		_name_label.text = "Text"
		if not _edit.has_focus() and not _edit.text.is_empty():
			_updating = true
			_edit.text = ""
			_updating = false
		_count_label.text = EMPTY_NOTE
		_note_label.visible = false
		_strip.call("show_for", d, seq_id, "")
		_animators.call("show_for", d, seq_id, "")
		_extras.call("show_for", d, seq_id, "")
		return
	_apply_inert(false)
	var want: String = text_of(d, c)
	_name_label.text = "Text: " + (c.label if not c.label.is_empty() else "Title")
	if not _edit.has_focus() and _edit.text != want:
		_updating = true
		var caret_line: int = _edit.get_caret_line()
		var caret_col: int = _edit.get_caret_column()
		_edit.text = want
		_edit.set_caret_line(mini(caret_line, maxi(_edit.get_line_count() - 1, 0)))
		_edit.set_caret_column(mini(caret_col, _edit.get_line(_edit.get_caret_line()).length()))
		_updating = false
	_count_label.text = counts_text(_edit.text)
	_refresh_tools(d, c)
	_refresh_note(d, c)
	_char_btn.text = CharMenu.shown_name(d, String(c.props.get("character", "")))
	_font_btn.text = FontMenu.shown_name(FontMenu.font_of(d, c))
	var missing: String = FontMenu.missing_note(d, c)
	_font_note.text = missing
	_font_row.visible = not missing.is_empty()
	_strip.call("show_for", d, seq_id, c.id)
	_animators.call("show_for", d, seq_id, c.id)
	_extras.call("show_for", d, seq_id, c.id)


func _refresh_note(d: Project, c: Clip) -> void:
	var shared: int = shared_count(d, d.sequence_by_id(seq_id), c.media_id)
	if shared > 1:
		_note_label.text = "%d boxes share this title's look. Typing here changes this box only." % shared
		_note_label.visible = true
	else:
		_note_label.visible = false


func _refresh_tools(d: Project, c: Clip) -> void:
	var m: MediaItem = d.media_by_id(c.media_id)
	var merged: Dictionary = TitleStyle.merged("title", m.props if m != null else {}, c.props)
	_bold.set_pressed_no_signal(bool(plain(merged.get("bold", false))))
	_italic.set_pressed_no_signal(bool(plain(merged.get("italic", false))))
	_upper.set_pressed_no_signal(bool(plain(merged.get("uppercase", false))))
	var align: String = String(plain(merged.get("align", "center")))
	if not TitleStyle.ALIGNS.has(align):
		align = "center"
	_align_drop.call("set_value", align, false)


func _presets(d: Project) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if d != null:
		out.append_array(Presets.list_project(d, "text_style"))
	out.append_array(Presets.list_user("text_style"))
	return out


func _apply_inert(on: bool) -> void:
	if _inert_painted and _inert == on:
		return
	_inert = on
	_inert_painted = true
	if _edit != null:
		_edit.editable = not on
		_edit.add_theme_stylebox_override("normal", _box(on, false))
		_edit.add_theme_stylebox_override("focus", _box(on, true))
		_edit.add_theme_stylebox_override("read_only", _box(on, false))
		_edit.add_theme_color_override("font_color", Tk.c["text_faint"] if on else Tk.c["text_bright"])
		_edit.add_theme_color_override("font_readonly_color", Tk.c["text_faint"])
		_edit.add_theme_color_override("background_color", Color(0.0, 0.0, 0.0, 0.0))
		_edit.placeholder_text = "" if on else "Type the title here"
	for b: Button in [_style_btn, _bold, _italic, _upper, _align_drop, _char_btn, _font_btn]:
		if b != null:
			b.disabled = on
	if _name_label != null:
		PmLabel.set_colour(_name_label, "text_faint" if on else "text_bright")


func _box(dim: bool, focused: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tk.c["bg_app"] if dim else Tk.c["bg_field"]
	if dim:
		sb.border_color = Tk.c["border"]
	elif focused:
		sb.border_color = Tk.c["accent"]
	else:
		sb.border_color = Tk.c["text_faint"]
	sb.set_border_width_all(1 if dim else 2)
	sb.set_corner_radius_all(int(Tk.px(Tk.sz("radius_field"))))
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


func font_items() -> Array:
	var d: Project = _doc()
	var c: Clip = target_clip()
	if d == null or c == null:
		return []
	return FontMenu.items(d, FontMenu.font_of(d, c))


func pick_font(id: String) -> bool:
	var d: Project = _doc()
	var s: Sequence = d.sequence_by_id(seq_id) if d != null else null
	if s == null or target_clip() == null:
		return false
	return FontMenu.on_pick(self, d, s, clip_id, id)


func _on_font_pressed() -> void:
	var items: Array = font_items()
	if items.is_empty():
		return
	var menu: Control = PmMenu.open(_font_btn, items)
	if menu != null and menu.is_inside_tree():
		menu.connect("picked", pick_font)


func _on_find_font() -> void:
	var d: Project = _doc()
	var c: Clip = target_clip()
	if d == null or c == null:
		return
	FontMenu.ask_file(self, "Find the font file", func(path: String) -> void: _relinked(path))


func _relinked(path: String) -> void:
	var d: Project = _doc()
	var c: Clip = target_clip()
	if d != null and c != null:
		FontMenu.relink_with(d, c, path)
		refresh()


func extras_ui() -> Control:
	return _extras


func animator_ui() -> Control:
	return _animators


func run_strip() -> Control:
	return _strip


func _on_strip_box_picked(id: String) -> void:
	var d: Project = _doc()
	var s: Sequence = d.sequence_by_id(seq_id) if d != null else null
	if s == null:
		return
	Verbs.select(d, s, PackedStringArray([id]), "replace")
	set_target(seq_id, id)


func _on_popout_pressed() -> void:
	popout_asked.emit()


func _token_context() -> Dictionary:
	var d: Project = _doc()
	var s: Sequence = d.sequence_by_id(seq_id) if d != null else null
	return TokenComplete.title_context(d, s, target_clip(), s.playhead if s != null else 0.0)


func _on_text_changed() -> void:
	if _updating or _inert:
		return
	write_text(_edit.text)
	_count_label.text = counts_text(_edit.text)


func type_text(value: String) -> void:
	if _inert:
		return
	_updating = true
	_edit.text = value
	_updating = false
	_on_text_changed()


func write_text(value: String) -> void:
	var d: Project = _doc()
	var c: Clip = target_clip()
	if d == null or c == null:
		return
	var s: Sequence = d.sequence_by_id(seq_id)
	if s == null:
		return
	if not _live:
		_live = true
		_text_before = text_of(d, c)
	var key_at: float = Bus.instance().key_time_for(c, TEXT_PATH, Session.playhead())
	Verbs.set_clip_param(d, s, c.id, TEXT_PATH, value, key_at, true)


func _on_focus_exited() -> void:
	finish_edit()


func finish_edit() -> void:
	if not _live:
		return
	_live = false
	var d: Project = _doc()
	if d == null:
		return
	if not d.undo.has_live():
		_text_before = ""
		return
	var s: Sequence = d.sequence_by_id(seq_id)
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c != null:
		var want: String = first_line(text_of(d, c))
		if not want.is_empty() and want != c.label and _label_follows_text(d, c):
			d.undo.live(ClipCmds.SetClipField.new(s.id, c.id, "label", want))
	d.undo.commit_live(EDIT_LABEL)
	_text_before = ""


func _label_follows_text(d: Project, c: Clip) -> bool:
	if c.label.is_empty():
		return true
	if c.label == first_line(_text_before):
		return true
	var m: MediaItem = d.media_by_id(c.media_id)
	return m != null and c.label == m.label


func _on_prop_toggled(on: bool, key: String) -> void:
	_write_prop(key, on)


func _on_align_pick(id: String) -> void:
	if TitleStyle.ALIGNS.has(id):
		_write_prop("align", id)


func _write_prop(key: String, value: Variant) -> void:
	var d: Project = _doc()
	var c: Clip = target_clip()
	if d == null or c == null:
		return
	var s: Sequence = d.sequence_by_id(seq_id)
	if s == null:
		return
	var path: String = "props." + key
	var key_at: float = Bus.instance().key_time_for(c, path, Session.playhead())
	Verbs.set_clip_param(d, s, c.id, path, value, key_at, false)


func character_ids() -> PackedStringArray:
	var d: Project = _doc()
	var c: Clip = target_clip()
	if d == null or c == null:
		return PackedStringArray()
	var s: Sequence = d.sequence_by_id(seq_id)
	if s != null and s.selected_clip_ids.has(c.id):
		var picked: Array[Clip] = Subtitles.sorted_text_clips(d, s, Verbs.selection(s))
		if picked.size() > 1:
			var out: PackedStringArray = PackedStringArray()
			for b: Clip in picked:
				out.append(b.id)
			return out
	return PackedStringArray([c.id])


func character_items() -> Array:
	var d: Project = _doc()
	var c: Clip = target_clip()
	if d == null or c == null:
		return []
	var s: Sequence = d.sequence_by_id(seq_id)
	return CharMenu.items(d, CharMenu.Library.current_of(d, s, character_ids()), true)


func _on_char_pressed() -> void:
	var items: Array = character_items()
	if items.is_empty():
		return
	var menu: Control = PmMenu.open(_char_btn, items)
	if menu != null and menu.is_inside_tree():
		menu.connect("picked", pick_character)


func pick_character(id: String) -> bool:
	var d: Project = _doc()
	var s: Sequence = d.sequence_by_id(seq_id) if d != null else null
	if s == null:
		return false
	return CharMenu.on_pick(self, d, s, character_ids(), id)


func _on_style_pressed() -> void:
	var d: Project = _doc()
	if d == null or target_clip() == null:
		return
	var items: Array = [PmMenu.item("subtitle", "Subtitle default")]
	for p: Dictionary in _presets(d):
		items.append(PmMenu.item("preset:" + String(p.get("id", "")), String(p.get("label", "Style"))))
	items.append(PmMenu.separator())
	items.append(PmMenu.item("save", "Save this look as a style"))
	var menu: Control = PmMenu.open(_style_btn, items)
	if menu != null and menu.is_inside_tree():
		menu.connect("picked", _on_style_pick)


func _on_style_pick(id: String) -> void:
	var d: Project = _doc()
	var c: Clip = target_clip()
	if d == null or c == null:
		return
	var s: Sequence = d.sequence_by_id(seq_id)
	if s == null:
		return
	var ids: PackedStringArray = PackedStringArray([c.id])
	if id == "subtitle":
		Subtitles.apply_style(d, s, ids, Subtitles.subtitle_style())
	elif id == "save":
		save_style(first_line(text_of(d, c)))
	elif id.begins_with("preset:"):
		var pid: String = id.substr(7)
		for p: Dictionary in _presets(d):
			if String(p.get("id", "")) == pid:
				var payload: Dictionary = p.get("payload", {})
				Subtitles.apply_style(d, s, ids, payload.get("props", {}))
				break


func save_style(name_: String) -> bool:
	var d: Project = _doc()
	var c: Clip = target_clip()
	if d == null or c == null:
		return false
	var label: String = name_.strip_edges()
	if label.is_empty():
		label = "Style " + str(_presets(d).size() + 1)
	if not Presets.save_to_project(d, Subtitles.style_from_clip(d, c, label)):
		return false
	Events.notice("Style saved", label + " is in this project's presets under Text style.")
	return true


static func data_menu_items() -> Array:
	var dates: Array = []
	for key: Variant in DataText.DATE_PRESETS.keys():
		dates.append(PmMenu.item(DATA_MENU + "{date:" + String(key) + "}", String(DataText.PRESET_LABELS.get(key, key))))
	var times: Array = []
	for key2: Variant in DataText.TIME_PRESETS.keys():
		times.append(PmMenu.item(DATA_MENU + "{time:" + String(key2) + "}", String(DataText.PRESET_LABELS.get(key2, key2))))
	var clocks: Array = []
	for key3: Variant in DataText.TIME_PRESETS.keys():
		clocks.append(PmMenu.item(DATA_MENU + "{clock:" + String(key3) + "}", String(DataText.PRESET_LABELS.get(key3, key3))))
	var ends: Array = []
	for key4: Variant in DataText.TIME_PRESETS.keys():
		ends.append(PmMenu.item(DATA_MENU + "{end:" + String(key4) + "}", String(DataText.PRESET_LABELS.get(key4, key4))))
	var out: Array = [
		PmMenu.sub_item("data_dates", "Date it was recorded", dates),
		PmMenu.sub_item("data_times", "Time recording started", times),
		PmMenu.sub_item("data_clock", "Its clock at this frame", clocks),
		PmMenu.sub_item("data_ends", "Time recording ended", ends),
		PmMenu.separator(),
	]
	for tok: String in ["length", "into", "file", "name", "fps", "size", "today"]:
		out.append(PmMenu.item(DATA_MENU + "{" + tok + "}", String(DataText.TOKEN_LABELS.get(tok, tok))))
	out.append(PmMenu.separator())
	for tok2: String in ["edit_time", "clips", "cuts", "project"]:
		out.append(PmMenu.item(DATA_MENU + "{" + tok2 + "}", String(DataText.TOKEN_LABELS.get(tok2, tok2))))
	out.append(PmMenu.separator())
	out.append(PmMenu.item(DATA_MENU + "{date:DDDD [the] Do}", "Your own: write {date:...} with YYYY MMMM MMM MM D Do DDDD h mm ss A, words in [ ]"))
	return out


func _on_data_pressed(anchor: Control) -> void:
	var m: Control = PmMenu.open(anchor, data_menu_items())
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_data_picked)


func _on_data_picked(id: String) -> void:
	if not id.begins_with(DATA_MENU) or _edit == null:
		return
	_edit.insert_text_at_caret(id.substr(DATA_MENU.length()))
	_edit.grab_focus()

extends PanelContainer

signal closed

const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")
const PmDrop := preload("res://ui/kit/pm_drop.gd")
const PmField := preload("res://ui/kit/pm_field.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PmSlot := preload("res://ui/kit/pm_slot.gd")
const PmWindow := preload("res://ui/kit/pm_window.gd")
const Clip := preload("res://doc/clip.gd")
const Sequence := preload("res://doc/sequence.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const AnimDriver := preload("res://doc/anim_driver.gd")
const Drive := preload("res://doc/drive.gd")
const Presets := preload("res://doc/presets.gd")
const EditTools := preload("res://doc/commands/edit_tools.gd")
const AudioReact := preload("res://engine/audio_react.gd")
const DriveSources := preload("res://engine/drive_sources.gd")
const AnimLayerUi := preload("res://modules/core_panels/anim_layer_ui.gd")
const SoundWell := preload("res://modules/core_panels/sound_well.gd")
const SELF_PATH := "res://modules/core_panels/drive_sheet.gd"
const KIND_CHOICES: Array = [["sound", "Sound"], ["picture", "Picture"], ["value", "Another value"]]
const MEASURE_CHOICES: Array = [["colour", "Amount of a colour"], ["bright", "Brightness"], ["sat", "Saturation"], ["hue", "Hue of the main colour"], ["red", "Red"], ["green", "Green"], ["blue", "Blue"], ["motion", "Motion"], ["cx", "Centre of a colour, across"], ["cy", "Centre of a colour, down"]]
const COLOUR_MEASURES: PackedStringArray = ["colour", "cx", "cy"]
const STEP_UNITS: Array = [["frames", "frames"], ["seconds", "seconds"]]
const PIC_KINDS: PackedStringArray = ["media", "clip"]
const PIC_OWN := "own"
const PIC_SCREEN := "screen"
const PIC_NONE := "none"
const CLIP_PREFIX := "clip:"
const PRESET_PREFIX := "preset:"
const AXES: Array = [["-1", "Every part"], ["0", "Only x"], ["1", "Only y"]]
const PIC_TIP := "The picture this reads. Drag a clip from the timeline, a file from the bin or the Source monitor's drag handle onto it, or click for a menu"
const HOLD_NOTE := "Share of the In range the source has to move before the value follows it. 0 follows every change."
const AUTO_WAIT := "Still reading the source. Auto fills in as soon as it is read."
const COLOUR_DELAY := 0.3
const FIELD_W := 64.0

var panel: Object = null
var path: String = ""
var label_text: String = ""
var nth: int = 0
var more: bool = false
var _sig: int = 0
var _auto_wait: bool = false
var _writing: bool = false
var _colour_pending: Variant = null
var _colour_left: float = 0.0
var _colour_window: Control = null
var col: VBoxContainer = null
var now_label: Label = null
var note_label: Label = null
var parts: Dictionary = {}


static func make(panel_: Object, path_: String, label_: String, nth_: int = 0) -> Control:
	var script: GDScript = load(SELF_PATH)
	var made: PanelContainer = script.new()
	made.set("panel", panel_)
	made.set("path", path_)
	made.set("label_text", label_)
	made.set("nth", nth_)
	made.call("rebuild")
	return made


func _init() -> void:
	name = "DriveSheet"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Tk.c["bg_panel_alt"]
	sb.border_color = Tk.c["accent"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(Tk.px(Tk.sz("radius_panel"))))
	var pad: float = float(Tk.px(Tk.sz("pad")))
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	add_theme_stylebox_override("panel", sb)
	set_process(false)


func doc() -> Object:
	return panel.call("doc") if panel != null else null


func seq() -> Sequence:
	return panel.call("seq") as Sequence if panel != null else null


func target_clip() -> Clip:
	if panel == null:
		return null
	if panel.has_method("drive_target"):
		return panel.call("drive_target", path) as Clip
	return panel.call("target_clip") as Clip


func playhead() -> float:
	return float(panel.call("playhead")) if panel != null else 0.0


func prop() -> Dictionary:
	if panel == null:
		return {}
	var got: Variant = panel.call("drive_prop", path)
	return got if got is Dictionary else {}


func info() -> Dictionary:
	if panel == null:
		return Drive.info(-INF, INF, 1, "", label_text)
	var got: Variant = panel.call("drive_info", path)
	return got if got is Dictionary else Drive.info(-INF, INF, 1, "", label_text)


func comps() -> int:
	return maxi(int(info().get("comps", 1)), 1)


func indices() -> PackedInt32Array:
	return Drive.indices(prop())


func layer_index() -> int:
	var idx: PackedInt32Array = indices()
	if idx.is_empty():
		return -1
	nth = clampi(nth, 0, idx.size() - 1)
	return idx[nth]


func layer() -> Dictionary:
	return AnimLayerUi.layer_at(prop(), layer_index())


func source() -> Dictionary:
	return AnimProp.driven_source(layer())


func kind() -> String:
	return String(source().get("kind", "value"))


func _put(p: Dictionary, label: String) -> void:
	if panel == null:
		return
	_writing = true
	panel.call("drive_write", path, p, label)
	_writing = false
	_sig = prop().hash()
	update_now()


func _field(key: String, value: Variant, label: String) -> void:
	var i: int = layer_index()
	if i < 0:
		return
	_put(Drive.set_field(prop(), i, key, value), label)


func _src(key: String, value: Variant, label: String) -> void:
	var i: int = layer_index()
	if i < 0:
		return
	_put(Drive.set_src(prop(), i, key, value), label)


func _on_text(text: String, key: String) -> void:
	_src(key, text, "Driver source")
	rebuild()


func refresh() -> void:
	if _writing:
		return
	if prop().hash() != _sig:
		rebuild()
	else:
		update_now()


func rebuild() -> void:
	for child: Node in get_children():
		PmUI.free_node(child)
	parts = {}
	_sig = prop().hash()
	col = PmUI.vbox(Tk.px(4.0))
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(col)
	col.add_child(_head())
	var idx: PackedInt32Array = indices()
	if idx.is_empty():
		col.add_child(_empty_row())
		return
	nth = clampi(nth, 0, idx.size() - 1)
	col.add_child(_stack_row(idx))
	col.add_child(_source_row())
	var detail: Control = _source_detail()
	if detail != null:
		col.add_child(detail)
	now_label = PmLabel.dim("")
	now_label.name = "Now"
	col.add_child(now_label)
	col.add_child(_range_row(true))
	col.add_child(_range_row(false))
	var more_btn: Button = PmButton.make("Less" if more else "More", "chev_d" if more else "chev_r")
	more_btn.name = "More"
	more_btn.set("quiet", true)
	more_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	more_btn.pressed.connect(_on_more)
	parts["more"] = more_btn
	col.add_child(more_btn)
	if more:
		_more_rows()
	note_label = PmLabel.wrap("", "text_dim")
	note_label.name = "Note"
	note_label.visible = false
	col.add_child(note_label)
	col.add_child(_buttons())
	update_now()


func _head() -> HBoxContainer:
	var head: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	head.add_child(PmLabel.body("Drive " + label_text))
	head.add_child(PmUI.spacer())
	var copy: Button = PmButton.make("Copy", "")
	copy.name = "Copy"
	copy.set("quiet", true)
	PmUI.tip(copy, "Copy this driver, or every driver on this value, to paste onto another value")
	copy.pressed.connect(_on_copy_menu.bind(copy))
	head.add_child(copy)
	var paste: Button = PmButton.make("Paste", "")
	paste.name = "Paste"
	paste.set("quiet", true)
	paste.disabled = not Drive.has_clip()
	PmUI.tip(paste, "Add the copied drivers to this value")
	paste.pressed.connect(paste_drivers)
	head.add_child(paste)
	var pre: Button = PmButton.make("Presets", "chev_d")
	pre.name = "Presets"
	pre.set("quiet", true)
	pre.pressed.connect(_on_presets_menu.bind(pre))
	head.add_child(pre)
	var shut: Button = PmButton.make("", "close")
	shut.set("quiet", true)
	shut.set("icon_px", 11.0)
	PmUI.tip(shut, "Close")
	shut.pressed.connect(_on_done)
	head.add_child(shut)
	return head


func _empty_row() -> HBoxContainer:
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.add_child(PmLabel.dim("Nothing drives this yet. Add:"))
	for kc: Array in KIND_CHOICES:
		var b: Button = PmButton.make(String(kc[1]), "plus")
		b.name = "Add_" + String(kc[0])
		b.set("quiet", true)
		b.pressed.connect(add_driver.bind(String(kc[0])))
		row.add_child(b)
	return row


func _stack_row(idx: PackedInt32Array) -> HBoxContainer:
	var row: HBoxContainer = PmUI.hbox(Tk.px(2.0))
	row.name = "Stack"
	var layers: Array = prop().get("layers", [])
	for i: int in idx.size():
		var l: Dictionary = layers[idx[i]]
		var on: CheckBox = CheckBox.new()
		on.focus_mode = Control.FOCUS_NONE
		on.button_pressed = bool(l.get("on", true))
		PmUI.tip(on, "Turn this driver on or off")
		on.toggled.connect(_on_flip.bind(i))
		row.add_child(on)
		var chip: Button = PmButton.make(Drive.label_of(l, i), "", true)
		chip.name = "Driver%d" % i
		chip.set("quiet", true)
		chip.button_pressed = i == nth
		chip.pressed.connect(select_driver.bind(i))
		row.add_child(chip)
	if idx.size() > 1:
		var up: Button = PmButton.make("", "chev_l")
		up.set("quiet", true)
		up.disabled = nth <= 0
		PmUI.tip(up, "Run this driver earlier")
		up.pressed.connect(move_driver.bind(-1))
		row.add_child(up)
		var down: Button = PmButton.make("", "chev_r")
		down.set("quiet", true)
		down.disabled = nth >= idx.size() - 1
		PmUI.tip(down, "Run this driver later, on top of the ones before it")
		down.pressed.connect(move_driver.bind(1))
		row.add_child(down)
	var add: Button = PmButton.make("Add", "plus")
	add.name = "AddDriver"
	add.set("quiet", true)
	PmUI.tip(add, "Stack another driver on this value")
	add.pressed.connect(_on_add_menu.bind(add))
	row.add_child(add)
	return row


func _source_row() -> HBoxContainer:
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.add_child(PmLabel.dim("From"))
	if kind() == "tracker":
		var tl: Label = PmLabel.trim("A tracker: change, bake or detach it in the Tracker panel", "text")
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tl)
		return row
	var choices: Array = []
	for kc: Array in KIND_CHOICES:
		choices.append(PmDrop.choice(String(kc[0]), String(kc[1])))
	var kd: Button = PmDrop.make_drop(choices, kind())
	kd.name = "Kind"
	kd.custom_minimum_size.x = float(Tk.px(96.0))
	kd.connect("changed", _on_kind)
	parts["kind"] = kd
	row.add_child(kd)
	var k: String = kind()
	if k == "sound":
		var editors: HBoxContainer = PmUI.hbox(Tk.px(2.0))
		editors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var made: Array = SoundWell.add(self, editors, {"path": "sound"})
		var well: Button = made[0]
		SoundWell.refresh(well, String(source().get("sound", "")), self)
		parts["sound_well"] = well
		row.add_child(editors)
	elif k == "picture":
		row.add_child(_picture_well())
	else:
		row.add_child(_value_picker())
	return row


func _picture_well() -> Button:
	var well: Button = PmButton.make(pic_label(), "image")
	well.name = "PictureWell"
	well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	well.custom_minimum_size.x = float(Tk.px(150.0))
	well.clip_text = true
	well.alignment = HORIZONTAL_ALIGNMENT_LEFT
	well.add_to_group(SoundWell.GROUP)
	PmUI.tip(well, PIC_TIP)
	var slot: Control = PmSlot.make(PIC_KINDS)
	slot.name = "PictureSlot"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set("priority", 10)
	slot.set("can_accept_cb", Callable(self, "accepts_picture"))
	slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.connect("dropped", _on_picture_drop)
	well.add_child(slot)
	well.pressed.connect(_on_picture_menu.bind(well))
	parts["picture_well"] = well
	return well


func pic_label() -> String:
	var c: Clip = target_clip()
	var r: Dictionary = DriveSources.pic_resolve(doc(), c, String(source().get("pic", "")), c.start if c != null else 0.0)
	return String(r["label"])


func accepts_picture(payload: Dictionary) -> bool:
	var k: String = String(payload.get("kind", ""))
	if k == "clip":
		return not (payload.get("ids", []) as Array).is_empty() or not String(payload.get("id", "")).is_empty()
	if k == "media":
		return String(payload.get("part", "both")) != "audio"
	return false


func _on_picture_drop(payload: Dictionary, _at: Vector2) -> void:
	drop_picture(payload)


func drop_picture(payload: Dictionary) -> bool:
	if not accepts_picture(payload):
		return false
	var p: Dictionary = payload
	if String(payload.get("kind", "")) == "media" and doc() != null:
		p = EditTools.subclip_payload(doc(), payload)
	var text: String = DriveSources.pic_from_payload(doc(), p)
	if text.is_empty():
		return false
	_on_text(text, "pic")
	return true


func picture_menu_items() -> Array:
	var items: Array = [PmMenu.item(PIC_OWN, "This clip's own picture"), PmMenu.item(PIC_SCREEN, "The screen under this clip")]
	var s: Sequence = seq()
	var d: Object = doc()
	var own: Clip = target_clip()
	var listed: Array = []
	if s != null and d != null:
		for tr: Variant in s.picture_tracks():
			var c: Clip = (tr as Object).call("clip_at", playhead())
			if c == null or c == own:
				continue
			var m: Object = d.call("media_by_id", c.media_id)
			if m == null or not (String(m.get("kind")) == "video" or String(m.get("kind")) == "image"):
				continue
			listed.append(PmMenu.item(CLIP_PREFIX + c.id, String((tr as Object).call("shown_label")) + ": " + (c.label if not c.label.is_empty() else String(m.get("label")))))
	if not listed.is_empty():
		items.append(PmMenu.separator())
		items.append_array(listed)
	items.append(PmMenu.separator())
	items.append(PmMenu.item(PIC_NONE, "No picture"))
	return items


func _on_picture_menu(anchor: Control) -> void:
	var m: Control = PmMenu.open(anchor, picture_menu_items())
	if m != null and m.is_inside_tree():
		m.connect("picked", picture_picked)


func picture_picked(id: String) -> void:
	if id == PIC_OWN:
		_on_text("", "pic")
	elif id == PIC_SCREEN or id == PIC_NONE:
		_on_text(DriveSources.pic_encode({"kind": id}), "pic")
	elif id.begins_with(CLIP_PREFIX):
		_on_text(DriveSources.pic_encode({"kind": "clip", "clip": id.substr(CLIP_PREFIX.length())}), "pic")


func _value_picker() -> HBoxContainer:
	var box: HBoxContainer = PmUI.hbox(Tk.px(2.0))
	var choices: Array = []
	for one: Dictionary in AnimLayerUi.source_clips(target_clip(), seq()):
		choices.append(PmDrop.choice(str(one["id"]), str(one["label"])))
	var cd: Button = PmDrop.make_drop(choices, String(source().get("clip", "")))
	cd.name = "ClipPicker"
	cd.custom_minimum_size.x = float(Tk.px(100.0))
	cd.connect("changed", _on_value_clip)
	box.add_child(cd)
	var sp: String = String(source().get("path", ""))
	var s: Sequence = seq()
	var from: Clip = s.clip_by_id(String(source().get("clip", ""))) if s != null else null
	var vb: Button = PmButton.make(AnimLayerUi.path_label(from if from != null else target_clip(), sp) if not sp.is_empty() else "Pick a value", "chev_d")
	vb.name = "ValuePicker"
	vb.set("quiet", true)
	vb.pressed.connect(_on_value_menu.bind(vb))
	box.add_child(vb)
	return box


func _on_value_clip(id: String) -> void:
	pick_value(id, "")


func _on_value_menu(anchor: Control) -> void:
	var s: Sequence = seq()
	var from: Clip = s.clip_by_id(String(source().get("clip", ""))) if s != null else null
	var out: Array = []
	for group: Dictionary in AnimLayerUi.value_groups(from if from != null else target_clip()):
		var subs: Array = []
		for one: Variant in group["values"]:
			subs.append(PmMenu.item(str((one as Dictionary)["path"]), str((one as Dictionary)["label"])))
		if not subs.is_empty():
			out.append(PmMenu.sub_item("group_" + str(group["group"]), str(group["group"]), subs))
	var m: Control = PmMenu.open(anchor, out)
	if m != null and m.is_inside_tree():
		m.connect("picked", _on_value_picked)


func _on_value_picked(id: String) -> void:
	pick_value("", id)


func pick_value(clip_id: String, value_path: String) -> void:
	var i: int = layer_index()
	var c: Clip = target_clip()
	var s: Sequence = seq()
	if i < 0 or c == null or s == null:
		return
	var src: Dictionary = source()
	if not clip_id.is_empty():
		src["clip"] = clip_id
		src["path"] = ""
	if not value_path.is_empty():
		src["path"] = value_path
		if String(src.get("clip", "")).is_empty():
			src["clip"] = c.id
	var picked: Clip = s.clip_by_id(String(src.get("clip", "")))
	src["src_start"] = picked.start if picked != null else 0.0
	src["dst_start"] = c.start
	src["owner"] = c.id
	_put(Drive.set_field(prop(), i, "src", src), "Driver source")
	rebuild()


func _source_detail() -> Control:
	var k: String = kind()
	var src: Dictionary = source()
	if k == "tracker":
		return PmUI.hbox(Tk.px(4.0))
	if k == "sound":
		var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		row.add_child(PmLabel.dim("Band"))
		var bands: Array = []
		for i: int in AudioReact.BANDS.size():
			bands.append(PmDrop.choice(str(i), AudioReact.BANDS[i]))
		var bd: Button = PmDrop.make_drop(bands, str(int(src.get("band", 0))))
		bd.name = "Band"
		bd.custom_minimum_size.x = float(Tk.px(84.0))
		bd.connect("changed", _on_band)
		row.add_child(bd)
		if int(src.get("band", 0)) == AudioReact.BAND_CUSTOM:
			row.add_child(_num_field("low", float(src.get("low", 80.0)), 20.0, 20000.0, 1.0, " Hz", _on_src_number.bind("low")))
			row.add_child(_num_field("high", float(src.get("high", 2000.0)), 20.0, 20000.0, 1.0, " Hz", _on_src_number.bind("high")))
		return row
	if k == "picture":
		var prow: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		prow.add_child(PmLabel.dim("Measure"))
		var ms: Array = []
		for mc: Array in MEASURE_CHOICES:
			ms.append(PmDrop.choice(String(mc[0]), String(mc[1])))
		var md: Button = PmDrop.make_drop(ms, String(src.get("measure", "colour")))
		md.name = "Measure"
		md.custom_minimum_size.x = float(Tk.px(130.0))
		md.connect("changed", _on_measure)
		prow.add_child(md)
		if COLOUR_MEASURES.has(String(src.get("measure", "colour"))):
			var sw: Button = PmButton.make("", "")
			sw.name = "Colour"
			sw.custom_minimum_size = Vector2(float(Tk.px(28.0)), float(Tk.px(Tk.sz("button_h"))))
			PmUI.tip(sw, "The colour to look for. Click for a picker with an eyedropper that picks from anywhere on screen, the Program monitor included")
			var chip: ColorRect = ColorRect.new()
			chip.name = "Swatch"
			chip.color = colour_now()
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			chip.offset_left = 4.0
			chip.offset_top = 4.0
			chip.offset_right = -4.0
			chip.offset_bottom = -4.0
			sw.add_child(chip)
			sw.pressed.connect(_on_colour.bind(sw))
			prow.add_child(sw)
			prow.add_child(PmLabel.dim("Tolerance"))
			prow.add_child(_num_field("tol", float(src.get("tol", 0.3)) * 100.0, 0.0, 100.0, 1.0, " %", _on_tolerance))
		return prow
	return null


func colour_now() -> Color:
	var raw: Variant = source().get("colour", [0.0, 1.0, 0.0])
	if raw is Array and (raw as Array).size() >= 3:
		return Color(float(raw[0]), float(raw[1]), float(raw[2]))
	return Color(0.0, 1.0, 0.0)


func _num_field(key: String, v: float, lo: float, hi: float, step: float, suffix: String, cb: Callable) -> Control:
	var f: Control = PmField.make(v, lo, hi, step, suffix)
	f.name = key
	f.custom_minimum_size.x = float(Tk.px(FIELD_W))
	f.connect("value_changed", cb)
	parts[key] = f
	return f


func _range_row(is_in: bool) -> HBoxContainer:
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	var l: Dictionary = layer()
	var unit: String = DriveSources.unit_of(l) if is_in else String(info().get("unit", ""))
	row.add_child(PmLabel.dim("In" if is_in else "Out"))
	if is_in:
		row.add_child(_num_field("in_min", AnimProp.driven_in(l, "in_min", 0.0), -INF, INF, 0.1, unit, _on_range.bind("in_min", -1)))
		row.add_child(PmLabel.dim("to"))
		row.add_child(_num_field("in_max", AnimProp.driven_in(l, "in_max", 1.0), -INF, INF, 0.1, unit, _on_range.bind("in_max", -1)))
		var auto: Button = PmButton.make("Auto")
		auto.name = "Auto"
		auto.set("quiet", true)
		PmUI.tip(auto, "Read the source across this clip and use its lowest and highest")
		auto.pressed.connect(auto_range)
		parts["auto"] = auto
		row.add_child(auto)
		return row
	var n: int = comps()
	var t: Dictionary = _time()
	for key: String in ["out_min", "out_max"]:
		if key == "out_max":
			row.add_child(PmLabel.dim("to"))
		for c: int in n:
			var v: float = AnimProp.driven_out(l, key, 0.0 if key == "out_min" else 1.0, c if n > 1 else -1, float(t.get("t", 0.0)), float(t.get("dur", 0.0)), float(t.get("fps", 0.0)))
			var mul: float = float(info().get("mul", 1.0))
			var f: Control = _num_field(key + ("_%d" % c if n > 1 else ""), v * mul, -INF, INF, 0.1, unit, _on_range.bind(key, c if n > 1 else -1))
			row.add_child(f)
		var dia: Button = PmButton.make("", "diamond" if l.get(key, 0.0) is Dictionary else "diamond_o")
		dia.name = "Key_" + key
		dia.set("quiet", true)
		dia.set("icon_px", 10.0)
		PmUI.tip(dia, "Key this end of the range at the playhead, so the output range can change over time")
		dia.pressed.connect(key_range.bind(key))
		row.add_child(dia)
	return row


func _time() -> Dictionary:
	if panel == null:
		return {}
	var got: Variant = panel.call("drive_time", path) if panel.has_method("drive_time") else panel.call("anim_sheet_time", path)
	return got if got is Dictionary else {}


func _more_rows() -> void:
	var l: Dictionary = layer()
	var r1: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	var inv: CheckBox = CheckBox.new()
	inv.name = "Invert"
	inv.text = "Invert"
	inv.focus_mode = Control.FOCUS_NONE
	inv.button_pressed = bool(l.get("invert", false))
	inv.toggled.connect(func(on: bool) -> void: _field("invert", on, "Driver invert"))
	r1.add_child(inv)
	var over: CheckBox = CheckBox.new()
	over.name = "Overshoot"
	over.text = "Let it overshoot"
	over.focus_mode = Control.FOCUS_NONE
	over.button_pressed = bool(l.get("overshoot", false))
	over.toggled.connect(func(on: bool) -> void: _field("overshoot", on, "Driver overshoot"))
	r1.add_child(over)
	r1.add_child(PmLabel.dim("Response"))
	var curves: Array = []
	for cv: Array in AnimLayerUi.CURVES:
		curves.append(PmDrop.choice(String(cv[0]), String(cv[1])))
	var cd: Button = PmDrop.make_drop(curves, String(l.get("curve", "linear")))
	cd.name = "Response"
	cd.custom_minimum_size.x = float(Tk.px(90.0))
	cd.connect("changed", func(id: String) -> void: _field("curve", id, "Driver response"))
	r1.add_child(cd)
	col.add_child(r1)
	var r2: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	r2.add_child(PmLabel.dim("Smoothing, rise"))
	r2.add_child(_num_field("attack", float(l.get("attack", 0.0)), 0.0, 10000.0, 1.0, " ms", _on_number.bind("attack")))
	r2.add_child(PmLabel.dim("fall"))
	r2.add_child(_num_field("release", float(l.get("release", 0.0)), 0.0, 10000.0, 1.0, " ms", _on_number.bind("release")))
	col.add_child(r2)
	var r3: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	r3.add_child(PmLabel.dim("Only change when it moves more than"))
	r3.add_child(_num_field("hold", float(l.get("hold", 0.0)), 0.0, 1.0, 0.01, "", _on_number.bind("hold")))
	col.add_child(r3)
	var hn: Label = PmLabel.wrap(HOLD_NOTE, "text_dim")
	hn.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_small")))
	col.add_child(hn)
	var r4: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	r4.add_child(PmLabel.dim("Change every"))
	r4.add_child(_num_field("step", float(l.get("step", 0.0)), 0.0, 10000.0, 1.0, "", _on_number.bind("step")))
	var units: Array = []
	for su: Array in STEP_UNITS:
		units.append(PmDrop.choice(String(su[0]), String(su[1])))
	var ud: Button = PmDrop.make_drop(units, String(l.get("step_unit", "frames")))
	ud.name = "StepUnit"
	ud.custom_minimum_size.x = float(Tk.px(76.0))
	ud.connect("changed", func(id: String) -> void: _field("step_unit", id, "Driver steps"))
	r4.add_child(ud)
	r4.add_child(PmLabel.dim("Offset"))
	r4.add_child(_num_field("lead", float(source().get("lead", 0.0)), -600.0, 600.0, 0.01, " s", _on_src_number.bind("lead")))
	col.add_child(r4)
	var r5: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	r5.add_child(PmLabel.dim("Blend"))
	var blends: Array = []
	for b: Array in AnimLayerUi.BLENDS:
		blends.append(PmDrop.choice(String(b[0]), String(b[1])))
	var bd: Button = PmDrop.make_drop(blends, String(l.get("blend", "over")))
	bd.name = "Blend"
	bd.custom_minimum_size.x = float(Tk.px(84.0))
	bd.connect("changed", func(id: String) -> void: _field("blend", id, "Driver blend"))
	r5.add_child(bd)
	r5.add_child(PmLabel.dim("Weight"))
	r5.add_child(_num_field("weight", AnimProp.driven_in(l, "weight", 1.0), 0.0, 1.0, 0.05, "", _on_number.bind("weight")))
	if comps() > 1:
		r5.add_child(PmLabel.dim("Moves"))
		var axes: Array = []
		for a: Array in AXES:
			axes.append(PmDrop.choice(String(a[0]), String(a[1])))
		var ad: Button = PmDrop.make_drop(axes, str(int(l.get("axis", -1))))
		ad.name = "Axis"
		ad.custom_minimum_size.x = float(Tk.px(84.0))
		ad.connect("changed", func(id: String) -> void: _field("axis", int(id), "Driver axis"))
		r5.add_child(ad)
	col.add_child(r5)
	if kind() == "picture":
		var r6: HBoxContainer = PmUI.hbox(Tk.px(4.0))
		r6.add_child(PmLabel.dim("Only look at"))
		var reg: Rect2 = DriveSources.measure_spec(source())["region"]
		r6.add_child(_num_field("rx", reg.position.x * 100.0, 0.0, 100.0, 1.0, " %", _on_region.bind(0)))
		r6.add_child(_num_field("ry", reg.position.y * 100.0, 0.0, 100.0, 1.0, " %", _on_region.bind(1)))
		r6.add_child(PmLabel.dim("size"))
		r6.add_child(_num_field("rw", reg.size.x * 100.0, 1.0, 100.0, 1.0, " %", _on_region.bind(2)))
		r6.add_child(_num_field("rh", reg.size.y * 100.0, 1.0, 100.0, 1.0, " %", _on_region.bind(3)))
		col.add_child(r6)
	var r7: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	r7.add_child(PmLabel.dim("Name"))
	var ne: LineEdit = LineEdit.new()
	ne.name = "DriverName"
	ne.text = String(l.get("name", ""))
	ne.placeholder_text = Drive.label_of(l, nth) if String(l.get("name", "")).is_empty() else ""
	ne.custom_minimum_size.x = float(Tk.px(140.0))
	ne.text_submitted.connect(func(text: String) -> void: _field("name", text.strip_edges(), "Driver name"))
	ne.focus_exited.connect(func() -> void: _field("name", ne.text.strip_edges(), "Driver name"))
	r7.add_child(ne)
	col.add_child(r7)


func _buttons() -> HBoxContainer:
	var row: HBoxContainer = PmUI.hbox(Tk.px(4.0))
	row.add_child(PmUI.spacer())
	var l: Dictionary = layer()
	var rec: Button = PmButton.make("Stop recording" if not String(l.get("rec_id", "")).is_empty() else "Record while playing")
	rec.name = "RecordWhilePlaying"
	rec.set("quiet", true)
	PmUI.tip(rec, "Keep exactly what you see while it plays. Press play, and when you stop, the played part is kept as it was and no longer follows the source")
	rec.pressed.connect(toggle_record)
	row.add_child(rec)
	if l.get("recorded", null) is Dictionary and not ((l["recorded"] as Dictionary).get("spans", []) as Array).is_empty():
		var clear: Button = PmButton.make("Forget recording")
		clear.name = "ForgetRecording"
		clear.set("quiet", true)
		PmUI.tip(clear, "Go back to following the source live everywhere")
		clear.pressed.connect(forget_recording)
		row.add_child(clear)
	var bake: Button = PmButton.make("Bake to keys")
	bake.set("quiet", true)
	PmUI.tip(bake, "Only if you want plain keys: it works the driver out at every frame and leaves keys behind. Drivers already work live without it")
	bake.pressed.connect(_on_bake)
	row.add_child(bake)
	var drop: Button = PmButton.make("Remove")
	drop.name = "Remove"
	drop.set("quiet", true)
	PmUI.tip(drop, "Remove this driver")
	drop.pressed.connect(remove_driver)
	row.add_child(drop)
	var done: Button = PmButton.primary("Done")
	done.pressed.connect(_on_done)
	row.add_child(done)
	return row


func raw_now() -> Dictionary:
	var l: Dictionary = layer()
	if l.is_empty():
		return {"ok": false, "v": 0.0}
	var t: Dictionary = _time()
	var got: Dictionary = AnimDriver.driven_raw(l, float(t.get("t", 0.0)), float(t.get("fps", 0.0)))
	if not bool(got.get("ok", false)):
		return {"ok": false, "v": 0.0}
	return {"ok": true, "v": float(got.get("raw", got.get("v", 0.0))), "out": AnimProp.driven_map(l, float(got.get("raw", got.get("v", 0.0))), -1, float(t.get("t", 0.0)), float(t.get("dur", 0.0)), float(t.get("fps", 0.0)))}


func update_now() -> void:
	if now_label == null or not is_instance_valid(now_label):
		return
	var r: Dictionary = raw_now()
	var unit: String = DriveSources.unit_of(layer())
	var waiting: String = "" if DriveSources.ready(doc(), layer()) else ", still reading the source"
	if not bool(r["ok"]):
		now_label.text = "Nothing to read here" + waiting
		return
	now_label.text = "Reads " + AnimLayerUi.number_text(float(r["v"])) + unit + " now, which gives " + AnimLayerUi.number_text(float(r["out"]) * float(info().get("mul", 1.0))) + String(info().get("unit", "")) + waiting


func say(text: String) -> void:
	if note_label != null and is_instance_valid(note_label):
		note_label.text = text
		note_label.visible = not text.is_empty()
	if not text.is_empty() and panel != null and panel.has_method("drive_note"):
		panel.call("drive_note", text)


func add_driver(k: String) -> void:
	if panel == null:
		return
	nth = int(panel.call("add_drive_layer", path, k))
	rebuild()


func select_driver(i: int) -> void:
	nth = i
	rebuild()


func move_driver(dir: int) -> void:
	var p: Dictionary = Drive.move_driver(prop(), nth, dir)
	nth = clampi(nth + dir, 0, maxi(indices().size() - 1, 0))
	_put(p, "Reorder drivers")
	rebuild()


func remove_driver() -> void:
	var i: int = layer_index()
	if i < 0:
		return
	_put(Drive.remove(prop(), i), "Remove driver")
	nth = maxi(nth - 1, 0)
	if indices().is_empty():
		_on_done()
		return
	rebuild()


func _on_flip(on: bool, i: int) -> void:
	var idx: PackedInt32Array = indices()
	if i < 0 or i >= idx.size():
		return
	_put(Drive.set_field(prop(), idx[i], "on", on), "Driver on")


func _on_add_menu(anchor: Control) -> void:
	var items: Array = []
	for kc: Array in KIND_CHOICES:
		items.append(PmMenu.item(String(kc[0]), String(kc[1])))
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", add_driver)


func _on_kind(id: String) -> void:
	var i: int = layer_index()
	var c: Clip = target_clip()
	if i < 0 or c == null:
		return
	_put(Drive.set_kind(prop(), i, id, c.id, c.start), "Driver source")
	rebuild()


func _on_band(id: String) -> void:
	_src("band", int(id), "Driver band")
	rebuild()


func _on_measure(id: String) -> void:
	var i: int = layer_index()
	if i < 0:
		return
	var p: Dictionary = Drive.set_src(prop(), i, "measure", id)
	var top: float = 360.0 if id == "hue" else 100.0
	p = Drive.set_field(p, i, "in_min", 0.0)
	p = Drive.set_field(p, i, "in_max", top)
	_put(p, "Driver measure")
	rebuild()


func _on_src_number(v: float, key: String) -> void:
	_src(key, v, "Driver " + key)


func _on_tolerance(v: float) -> void:
	_src("tol", clampf(v / 100.0, 0.0, 1.0), "Driver tolerance")


func _on_region(v: float, k: int) -> void:
	var reg: Rect2 = DriveSources.measure_spec(source())["region"]
	var a: Array = [reg.position.x, reg.position.y, reg.size.x, reg.size.y]
	a[k] = clampf(v / 100.0, 0.0, 1.0)
	_src("region", a, "Driver region")


func _on_number(v: float, key: String) -> void:
	var value: Variant = v
	if key == "step":
		value = maxf(roundf(v * 1000.0) / 1000.0, 0.0)
	_field(key, value, "Driver " + key)


func _on_range(v: float, key: String, c: int) -> void:
	var i: int = layer_index()
	if i < 0:
		return
	var l: Dictionary = layer()
	var real: float = v
	if key.begins_with("out"):
		real = v / maxf(float(info().get("mul", 1.0)), 0.000001) if float(info().get("mul", 1.0)) != 0.0 else v
	var cur: Variant = l.get(key, 0.0)
	var t: Dictionary = _time()
	if cur is Dictionary:
		var keyed: Dictionary = AnimProp.set_key(cur, float(t.get("t", 0.0)), _with_comp(AnimProp.evaluate(cur, float(t.get("t", 0.0)), float(t.get("dur", 0.0)), float(t.get("fps", 0.0))), c, real))
		_field(key, keyed, "Driver range")
		return
	_field(key, _with_comp(cur, c, real), "Driver range")


func _with_comp(cur: Variant, c: int, v: float) -> Variant:
	var n: int = comps()
	if c < 0 or n <= 1:
		return v
	var out: Array = []
	for k: int in n:
		out.append(v if k == c else Drive._num(cur, k))
	return out


func key_range(key: String) -> void:
	var l: Dictionary = layer()
	var cur: Variant = l.get(key, 0.0)
	var t: Dictionary = _time()
	var at: float = float(t.get("t", 0.0))
	if cur is Dictionary:
		var now: Variant = AnimProp.evaluate(cur, at, float(t.get("dur", 0.0)), float(t.get("fps", 0.0)))
		if AnimProp.has_key_at(cur, at):
			var less: Dictionary = AnimProp.simplify(AnimProp.remove_key(cur, at))
			_field(key, less if AnimProp.is_animated(less) else AnimProp.static_value(less), "Driver range key")
		else:
			_field(key, AnimProp.set_key(cur, at, now), "Driver range key")
	else:
		_field(key, AnimProp.set_key(AnimProp.make(cur), at, cur), "Driver range key")
	rebuild()


func auto_range() -> bool:
	var l: Dictionary = layer()
	if l.is_empty():
		return false
	if not DriveSources.ready(doc(), l):
		_auto_wait = true
		say(AUTO_WAIT)
		set_process(true)
		return false
	var s: Sequence = seq()
	var got: Dictionary = DriveSources.scan(doc(), l, s.fps if s != null else 30.0)
	if not bool(got["ok"]):
		say("There was nothing to read across this clip")
		return false
	var i: int = layer_index()
	var p: Dictionary = Drive.set_field(prop(), i, "in_min", float(got["lo"]))
	p = Drive.set_field(p, i, "in_max", float(got["hi"]))
	_put(p, "Driver Auto range")
	rebuild()
	say("Lowest %s, highest %s across the clip" % [AnimLayerUi.number_text(float(got["lo"])), AnimLayerUi.number_text(float(got["hi"]))])
	return true


func _process(dt: float) -> void:
	if _auto_wait and DriveSources.ready(doc(), layer()):
		_auto_wait = false
		auto_range()
	if _colour_pending != null:
		_colour_left -= dt
		if _colour_left <= 0.0:
			var c: Color = _colour_pending
			_colour_pending = null
			_src("colour", [c.r, c.g, c.b], "Driver colour")
	if not _auto_wait and _colour_pending == null:
		set_process(false)
		update_now()


func _on_colour(anchor: Control) -> void:
	if _colour_window != null and is_instance_valid(_colour_window):
		_colour_window.call("close")
	var picker: ColorPicker = ColorPicker.new()
	picker.color = colour_now()
	picker.edit_alpha = false
	picker.sampler_visible = true
	picker.color_changed.connect(set_colour)
	var host: Node = get_tree().root if is_inside_tree() else self
	_colour_window = PmWindow.open(host, "Colour to look for", picker, Vector2(300.0, 440.0), "drive.colour")
	if _colour_window != null:
		_colour_window.call("place_at", anchor.global_position + Vector2(0.0, anchor.size.y))


func set_colour(c: Color) -> void:
	_colour_pending = c
	_colour_left = COLOUR_DELAY
	set_process(true)


func _on_more() -> void:
	more = not more
	rebuild()


func _on_copy_menu(anchor: Control) -> void:
	var items: Array = [PmMenu.item("one", "Copy this driver"), PmMenu.item("all", "Copy every driver on this value")]
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", func(id: String) -> void: copy_drivers(id == "all"))


func copy_drivers(all: bool) -> bool:
	var c: Clip = target_clip()
	var cb: Dictionary = Drive.copy(prop(), -1 if all else nth, info(), c.id if c != null else "")
	if cb.is_empty():
		return false
	say("Copied %d driver%s. Open Drive on another value and press Paste" % [(cb["layers"] as Array).size(), "" if (cb["layers"] as Array).size() == 1 else "s"])
	return true


func paste_drivers() -> bool:
	if panel == null or not Drive.has_clip():
		return false
	var note: String = String(panel.call("paste_drivers", path))
	nth = maxi(indices().size() - 1, 0)
	rebuild()
	say("Pasted. " + note if not note.is_empty() else "Pasted")
	return true


func preset_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d: Object = doc()
	if d != null:
		out.append_array(Presets.list_project(d, Drive.PRESET_KIND))
	out.append_array(Presets.list_user(Drive.PRESET_KIND))
	return out


func _on_presets_menu(anchor: Control) -> void:
	var items: Array = [PmMenu.item("save_one", "Save this driver as a preset"), PmMenu.item("save_all", "Save every driver on this value as a preset")]
	var list: Array[Dictionary] = preset_list()
	if not list.is_empty():
		items.append(PmMenu.separator())
		for p: Dictionary in list:
			items.append(PmMenu.item(PRESET_PREFIX + String(p.get("id", "")), "Apply " + String(p.get("label", "preset"))))
	var m: Control = PmMenu.open(anchor, items)
	if m != null and m.is_inside_tree():
		m.connect("picked", preset_picked)


func preset_picked(id: String) -> void:
	if id == "save_one" or id == "save_all":
		var fields: Array[Dictionary] = [{"key": "name", "label": "Preset name", "type": "string", "default": ""}]
		var host: Node = get_tree().root if is_inside_tree() else self
		var answered: Signal = PmUI.form(host, "Save driver preset", fields, "Save", "Cancel")
		answered.connect(func(result: Variant) -> void:
			if typeof(result) == TYPE_DICTIONARY and not (result as Dictionary).is_empty():
				save_preset(String((result as Dictionary).get("name", "")), id == "save_all"))
		return
	if id.begins_with(PRESET_PREFIX):
		var pid: String = id.substr(PRESET_PREFIX.length())
		for p: Dictionary in preset_list():
			if String(p.get("id", "")) == pid:
				apply_preset(p, "")
				return


func make_preset(label: String, all: bool) -> Dictionary:
	var layers: Array = []
	var ls: Array = prop().get("layers", []) if AnimProp.is_animated(prop()) else []
	var idx: PackedInt32Array = indices()
	for i: int in idx.size():
		if all or i == nth:
			layers.append(ls[idx[i]])
	if layers.is_empty():
		return {}
	var named: String = label.strip_edges()
	if named.is_empty():
		named = "Driver for " + label_text
	return Presets.make(Drive.PRESET_KIND, named, Drive.preset_payload(layers, info()))


func save_preset(label: String, all: bool) -> bool:
	var preset: Dictionary = make_preset(label, all)
	if preset.is_empty():
		return false
	var ok: bool = Presets.save_user(preset)
	say(("Saved " + String(preset["label"]) + " in the preset library") if ok else "The preset could not be saved")
	return ok


func apply_preset(preset: Dictionary, source_text: String) -> bool:
	if panel == null:
		return false
	var note: String = String(panel.call("apply_drive_preset", path, preset, source_text))
	nth = maxi(indices().size() - 1, 0)
	rebuild()
	say("Applied " + String(preset.get("label", "the preset")) + ". It reads this clip's own " + ("sound" if kind() == "sound" else ("picture" if kind() == "picture" else "values")) + " until you pick another source above" + (". " + note if not note.is_empty() else ""))
	return true


func toggle_record() -> bool:
	var l: Dictionary = layer()
	if l.is_empty():
		return false
	if not String(l.get("rec_id", "")).is_empty():
		_field("rec_id", "", "Stop recording the driver")
		say("Recording stopped")
	else:
		_field("rec_id", "r" + str(Time.get_ticks_usec()) + str(randi() % 1000), "Record the driver while playing")
		say("Press play: what you see is kept when you stop")
	rebuild()
	return true


func forget_recording() -> void:
	_field("recorded", {}, "Forget the driver recording")
	rebuild()


func _on_bake() -> void:
	if panel != null:
		panel.call("bake_anim_layers", path)
	_on_done()


func _on_done() -> void:
	closed.emit()
	if _colour_window != null and is_instance_valid(_colour_window):
		_colour_window.call("close")
	if panel != null:
		panel.call("close_drive", path)

extends VBoxContainer

## The "what it gets, what it gives, does it work" box at the top of a text effect in
## Effect Controls. It follows the playhead, so a chain of ciphers can be read step by step.

const TextFx := preload("res://doc/text_fx/text_fx.gd")
const PmLabel := preload("res://ui/kit/pm_label.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Clip := preload("res://doc/clip.gd")
const DataText := preload("res://doc/data_text.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const NODE_NAME := "TextFxBox"
const REFRESH := 0.12

var panel: Object = null
var uid: String = ""
var shown_in: String = ""
var shown_out: String = ""
var shown_say: String = ""
var shown_level: String = ""
var _in_label: Label = null
var _out_label: Label = null
var _say_label: Label = null
var _wait: float = 0.0
var _stamp: String = ""


static func applies(def: Dictionary) -> bool:
	return TextFx.text_only(def)


static func add_for(ec: Object, body: Control, def: Dictionary, effect_uid: String) -> Control:
	if not TextFx.text_only(def):
		return null
	var box: VBoxContainer = (load("res://modules/core_panels/text_fx_box.gd") as GDScript).new()
	box.set("panel", ec)
	box.set("uid", effect_uid)
	body.add_child(box)
	if ec != null and ec.has_method("adopt_panel"):
		ec.call("adopt_panel", box)
	box.call("refresh")
	return box


static func find_in(root: Node, effect_uid: String) -> Control:
	if root == null:
		return null
	for n: Node in root.find_children(NODE_NAME + "*", "", true, false):
		if String(n.get("uid")) == effect_uid:
			return n as Control
	return null


func _init() -> void:
	name = NODE_NAME
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 1)
	_in_label = _line("Gets")
	_out_label = _line("Gives")
	_say_label = PmLabel.wrap("")
	_say_label.add_theme_font_size_override("font_size", Tk.fs(Tk.sz("font_small")))
	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", int(Tk.px(Tk.sz("pad"))))
	pad.add_theme_constant_override("margin_right", int(Tk.px(Tk.sz("pad"))))
	pad.add_child(_say_label)
	add_child(pad)


func _line(caption: String) -> Label:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(Tk.px(6.0)))
	var pad: MarginContainer = MarginContainer.new()
	pad.add_theme_constant_override("margin_left", int(Tk.px(Tk.sz("pad"))))
	pad.add_theme_constant_override("margin_right", int(Tk.px(Tk.sz("pad"))))
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cap: Label = PmLabel.meta(caption)
	cap.custom_minimum_size = Vector2(Tk.px(44.0), 0.0)
	row.add_child(cap)
	var value: Label = PmLabel.trim("", "text")
	value.add_theme_font_override("font", Tk.font("mono"))
	value.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(value)
	pad.add_child(row)
	add_child(pad)
	return value


func _process(dt: float) -> void:
	_wait -= dt
	if _wait > 0.0 or not is_visible_in_tree():
		return
	_wait = REFRESH
	refresh()


func target_clip() -> Clip:
	if panel == null or not is_instance_valid(panel) or not panel.has_method("target_clip"):
		return null
	var c: Variant = panel.call("target_clip")
	return c as Clip if c is Clip else null


func swap(table: Dictionary) -> void:
	if table.has(uid):
		uid = String(table[uid])
		_stamp = ""


func sync() -> void:
	refresh()


func refresh() -> void:
	var c: Clip = target_clip()
	var s: Variant = Session.seq() if Session != null else null
	var d: Variant = Session.doc if Session != null else null
	if c == null or s == null or d == null:
		return
	var m: MediaItem = d.call("media_by_id", c.media_id)
	if m == null:
		return
	var playhead: float = float(s.get("playhead"))
	var fps: float = float(s.get("fps"))
	var local_t: float = playhead - c.start
	var props: Dictionary = m.props.duplicate(true)
	var now: Dictionary = c.props_at(local_t, fps)
	for k: Variant in now.keys():
		props[k] = now[k]
	var base: String = TextFx.base_text(props, m.label)
	if DataText.has_tokens(base):
		base = DataText.expand(base, DataText.context(d, s, c, playhead))
	var run: Dictionary = TextFx.run_clip(c, EffectSource.registry(), base, local_t, fps)
	for row: Dictionary in run["rows"]:
		if String(row["uid"]) == uid:
			show_row(row)
			return
	show_row({"in": "", "out": "", "level": "", "say": "This effect isn't in the clip's stack"})


func show_row(row: Dictionary) -> void:
	var stamp: String = JSON.stringify([row.get("in", ""), row.get("out", ""), row.get("level", ""), row.get("say", "")])
	if stamp == _stamp:
		return
	_stamp = stamp
	shown_in = String(row.get("in", ""))
	shown_out = String(row.get("out", ""))
	shown_level = String(row.get("level", ""))
	shown_say = String(row.get("say", ""))
	_in_label.text = TextFx.preview(shown_in) if not shown_in.is_empty() else "(nothing)"
	_in_label.tooltip_text = shown_in
	_out_label.text = TextFx.preview(shown_out) if not shown_out.is_empty() else "(nothing)"
	_out_label.tooltip_text = shown_out
	var word: String = TextFx.level_word(shown_level)
	_say_label.text = (word + ". " if not word.is_empty() else "") + shown_say
	_say_label.add_theme_color_override("font_color", TextFx.level_colour(shown_level))

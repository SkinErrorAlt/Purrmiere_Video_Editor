extends "res://ui/kit/pm_field.gd"

const MIXED_TEXT := "mixed"

var mixed: bool = false:
	set(v):
		if v == mixed:
			return
		mixed = v
		queue_redraw()


static func make_multi(min_v: float, max_v: float, step_: float, suffix_: String) -> Control:
	var script: GDScript = load("res://modules/core_panels/multi_field.gd")
	var f: Control = script.new()
	f.set("value", 0.0)
	f.set("min_value", min_v)
	f.set("max_value", max_v)
	f.set("step", step_)
	f.set("suffix", suffix_)
	return f


func shows_mixed() -> bool:
	return mixed and not _dragging and _editor == null


func display_text() -> String:
	if shows_mixed():
		return MIXED_TEXT
	return super()


func begin_typing() -> void:
	var was_mixed: bool = shows_mixed()
	super()
	if was_mixed and _editor != null:
		_editor.text = ""
		_editor.placeholder_text = MIXED_TEXT

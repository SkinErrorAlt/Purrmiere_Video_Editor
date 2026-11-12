extends RefCounted

const SpeedBlur := preload("res://doc/speed_blur.gd")
const PanelBase := preload("res://modules/core_panels/panel_base.gd")
const PmUI := preload("res://ui/kit/pm_ui.gd")
const PmButton := preload("res://ui/kit/pm_button.gd")


static func row(panel: Object, label_w: float) -> Control:
	var r: HBoxContainer = PmUI.hbox()
	r.name = "SpeedBlurRow"
	var pad := Control.new()
	pad.custom_minimum_size.x = label_w
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(pad)
	var b: Button = PmButton.make("Match the blur to the speed", "follow")
	b.name = "SpeedBlurBake"
	PmUI.tip(b, "Keys the shutter angle from the clip's speed: faster parts blur more, slower parts less (180 degrees at normal speed). The keys are ordinary keyframes you can edit, and they stay put if the speed changes later.")
	b.pressed.connect(func() -> void:
		var c: Object = panel.call("target_clip")
		if c != null:
			SpeedBlur.bake(panel.call("doc"), panel.call("seq"), String(c.get("id")))
	)
	r.add_child(b)
	return r

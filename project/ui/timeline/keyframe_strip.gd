extends RefCounted

const KeyframeEditor := preload("res://ui/timeline/keyframe_editor.gd")


static func make(clip_id: String, path: String) -> Control:
	var e: Control = KeyframeEditor.make(clip_id, path, true)
	e.name = "KeyframeStrip"
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return e


static func retarget(strip: Control, clip_id: String, path: String) -> void:
	if strip != null and strip.has_method("set_target"):
		strip.call("set_target", clip_id, path)

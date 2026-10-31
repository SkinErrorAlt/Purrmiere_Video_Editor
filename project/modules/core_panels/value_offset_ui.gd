extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Verbs := preload("res://doc/verbs.gd")
const ValueOffsets := preload("res://doc/value_offsets.gd")
const ValueClipboard := preload("res://modules/core_panels/value_clipboard.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")
const PASTE_ID := "paste_offset"
const REMOVE_PREFIX := "offset_remove:"
const TOGGLE_PREFIX := "offset_toggle:"
const BASE_ID := "offset_base"
const FAMILIES: PackedStringArray = ["number", "point", "colour"]
const KEYS_HINT := "Ctrl+Alt+V"


static func offsettable(spec: Dictionary) -> bool:
	if spec.is_empty() or spec.has("field") or spec.has("members") or not bool(spec.get("keyable", false)):
		return false
	return FAMILIES.has(ValueClipboard.family(String(spec.get("kind", ""))))


static func refusal(cb: Dictionary, spec: Dictionary) -> String:
	if cb.is_empty():
		return "Copy a value first, then paste it as an offset"
	if not offsettable(spec):
		return ValueClipboard.plain_label(spec) + " cannot take an offset"
	if not FAMILIES.has(String(cb.get("family", ""))):
		return "Only numbers, points and colours can be added as an offset"
	return ValueClipboard.refusal(cb, spec)


static func offset_value(spec: Dictionary, v: Variant, like: Variant) -> Variant:
	if spec.has("component"):
		return ValueOffsets.part_offset(v, int(spec["component"]), like)
	return AnimProp.norm(v)


static func offset_cmds(seq: Sequence, c: Clip, spec: Dictionary, cb: Dictionary, current: Variant) -> Array[Command]:
	var out: Array[Command] = []
	if seq == null or c == null or not refusal(cb, spec).is_empty():
		return out
	var path: String = String(spec.get("path", ""))
	var prop: Dictionary = c.get_param(path)
	if prop.is_empty():
		prop = AnimProp.make(AnimProp.norm(current))
	var like: Variant = AnimProp.static_value(prop)
	var keys: Array = []
	var base: float = float(cb.get("base", 0.0))
	for item: Variant in cb.get("keys", []):
		var kd: Dictionary = (item as Dictionary).duplicate(true)
		kd["t"] = maxf(base + float(kd.get("t", 0.0)), 0.0)
		kd["v"] = offset_value(spec, kd.get("v", 0.0), like)
		keys.append(kd)
	var next: Dictionary = ValueOffsets.with_offset(prop, offset_value(spec, cb.get("value", 0.0), like), keys, ValueClipboard.plain_name(cb))
	out.append(ClipCmds.SetClipParam.new(seq.id, c.id, path, next))
	return out


static func paste_offset(doc: Project, seq: Sequence, c: Clip, spec: Dictionary, cb: Dictionary, current: Variant) -> bool:
	var cmds: Array[Command] = offset_cmds(seq, c, spec, cb, current)
	if cmds.is_empty():
		return false
	return Verbs.run(doc, "Paste " + ValueClipboard.plain_name(cb) + " as an offset", cmds)


static func remove_cmds(seq: Sequence, c: Clip, path: String, nth: int) -> Array[Command]:
	var out: Array[Command] = []
	var prop: Dictionary = c.get_param(path) if c != null else {}
	if prop.is_empty() or nth < 0 or nth >= ValueOffsets.count(prop):
		return out
	out.append(ClipCmds.SetClipParam.new(seq.id, c.id, path, ValueOffsets.without_offset(prop, nth)))
	return out


static func menu_items(panel: Object, path: String) -> Array:
	var out: Array = []
	var r: Dictionary = panel.call("_row_for", path)
	if r.is_empty():
		return out
	var spec: Dictionary = r["spec"]
	if not offsettable(spec):
		return out
	var paste: Dictionary = PmMenu.item(PASTE_ID, "Paste as an offset", KEYS_HINT)
	paste["disabled"] = not refusal(ValueClipboard.held, spec).is_empty()
	out.append(paste)
	var c: Clip = panel.call("target_clip")
	var prop: Dictionary = c.get_param(path) if c != null else {}
	var stack: Array[Dictionary] = ValueOffsets.stack(prop)
	if stack.size() <= 1:
		return out
	var sub: Array = []
	for entry: Dictionary in stack:
		if String(entry["kind"]) == "base":
			var base: Dictionary = PmMenu.item(BASE_ID, "Base value, it stays")
			base["disabled"] = true
			sub.append(base)
			continue
		var n: int = int(entry["index"])
		sub.append(PmMenu.check_item(TOGGLE_PREFIX + str(n), String(entry["label"]), bool(entry.get("on", true))))
		sub.append(PmMenu.item(REMOVE_PREFIX + str(n), "Remove " + String(entry["label"]).split(",")[0], "", "trash"))
	out.append(PmMenu.sub_item("offsets", "Offsets (%d)" % (stack.size() - 1), sub))
	return out


static func picked(panel: Object, id: String, path: String) -> bool:
	if id != PASTE_ID and not id.begins_with(REMOVE_PREFIX) and not id.begins_with(TOGGLE_PREFIX) and id != BASE_ID:
		return false
	var d: Project = panel.call("doc")
	var s: Sequence = panel.call("seq")
	var c: Clip = panel.call("target_clip")
	var r: Dictionary = panel.call("_row_for", path)
	if d == null or s == null or c == null or r.is_empty():
		return true
	var spec: Dictionary = r["spec"]
	if id == PASTE_ID:
		var why: String = refusal(ValueClipboard.held, spec)
		if not why.is_empty():
			Events.toast(why)
			return true
		paste_offset(d, s, c, spec, ValueClipboard.held, panel.call("current_value", spec))
		return true
	if id == BASE_ID:
		Events.toast(ValueOffsets.BASE_REFUSAL)
		return true
	if id.begins_with(REMOVE_PREFIX):
		var cmds: Array[Command] = remove_cmds(s, c, path, int(id.substr(REMOVE_PREFIX.length())))
		if not cmds.is_empty():
			Verbs.run(d, "Remove offset", cmds)
		return true
	var nth: int = int(id.substr(TOGGLE_PREFIX.length()))
	var prop: Dictionary = c.get_param(path)
	var entries: Array[Dictionary] = ValueOffsets.stack(prop)
	if nth + 1 < entries.size():
		var on: bool = not bool(entries[nth + 1].get("on", true))
		Verbs.run(d, "Offset on" if on else "Offset off", [ClipCmds.SetClipParam.new(s.id, c.id, path, ValueOffsets.toggled(prop, nth, on))] as Array[Command])
	return true


static func paste_picked_offset(panel: Object) -> bool:
	var cb: Dictionary = ValueClipboard.held
	if cb.is_empty():
		Events.toast("Copy a value first, then paste it as an offset")
		return true
	var picked_id: String = String(panel.get("_picked"))
	var r: Dictionary = panel.call("_row_by_pick", picked_id) if not picked_id.is_empty() else {}
	if r.is_empty():
		r = panel.call("_row_by_match", cb)
	if r.is_empty():
		Events.toast("Pick a value to paste the offset onto")
		return true
	return picked(panel, PASTE_ID, String(r["path"]))

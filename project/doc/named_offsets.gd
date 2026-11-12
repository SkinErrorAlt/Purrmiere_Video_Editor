extends RefCounted

const Clip := preload("res://doc/clip.gd")
const Sequence := preload("res://doc/sequence.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ViewMap := preload("res://doc/view_map.gd")
const ViewOffsets := preload("res://doc/view_offsets.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const PairCmds := preload("res://doc/commands/pair_cmds.gd")
const KEY := "named_offsets"
const AUTO_KEY := "match_cuts"
const NAME_MAX := 60
const LIST_MAX := 32
const MS_MAX := 60000.0


static func _text(e: Dictionary, key: String) -> String:
	var params: Dictionary = e.get("params", {})
	var raw: Variant = params.get(key, null)
	if raw is Dictionary:
		var v: Variant = AnimProp.static_value(raw)
		return String(v) if v is String else ""
	return String(raw) if raw is String else ""


static func sanitise(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (raw is Array):
		return out
	for item: Variant in raw:
		if out.size() >= LIST_MAX:
			break
		if not (item is Dictionary):
			continue
		var d: Dictionary = item
		var from_v: int = int(d.get("from", -1)) if (d.get("from") is float or d.get("from") is int) else -1
		var into_v: int = int(d.get("into", -1)) if (d.get("into") is float or d.get("into") is int) else -1
		if from_v < 0 or into_v < 0 or from_v >= ViewMap.REGION_MAX or into_v >= ViewMap.REGION_MAX or from_v == into_v:
			continue
		var ms: float = float(d.get("ms", 0.0)) if (d.get("ms") is float or d.get("ms") is int) else 0.0
		var name_: String = String(d.get("name", "")).strip_edges().substr(0, NAME_MAX) if d.get("name") is String else ""
		out.append({"name": name_, "from": from_v, "into": into_v, "ms": clampf(ms, -MS_MAX, MS_MAX)})
	return out


static func list_of(e: Dictionary) -> Array[Dictionary]:
	var text: String = _text(e, KEY).strip_edges()
	if text.is_empty():
		return []
	return sanitise(JSON.parse_string(text))


static func encode(list: Array) -> String:
	var clean: Array[Dictionary] = sanitise(list)
	if clean.is_empty():
		return ""
	return JSON.stringify(clean)


static func auto_on(e: Dictionary) -> bool:
	var params: Dictionary = e.get("params", {})
	var raw: Variant = params.get(AUTO_KEY, null)
	if raw is Dictionary:
		return bool(AnimProp.static_value(raw))
	return bool(raw) if raw is bool else false


static func find(list: Array, from_v: int, into_v: int) -> Dictionary:
	for d: Variant in list:
		var dd: Dictionary = d
		if int(dd["from"]) == from_v and int(dd["into"]) == into_v:
			return dd
	return {}


static func label_for(e: Dictionary, d: Dictionary) -> String:
	if not String(d.get("name", "")).is_empty():
		return String(d["name"])
	var names: PackedStringArray = ViewMap.region_names(e)
	var a: int = int(d.get("from", 0))
	var b: int = int(d.get("into", 0))
	var an: String = names[a] if a < names.size() else "View " + str(a + 1)
	var bn: String = names[b] if b < names.size() else "View " + str(b + 1)
	return an + " into " + bn


static func _value(p: Dictionary, e: Dictionary, index: int, video: Clip, local: float) -> float:
	if p.is_empty():
		return 0.0
	if not AnimProp.is_animated(p):
		return ViewMap.clamp_offset(float(AnimProp.static_value(p)))
	var dur: float = video.duration if video != null else 0.0
	return ViewMap.clamp_offset(AnimProp.evaluate_float(p, video.fx_time(e, ViewMap.offset_key(index), local) if video != null else local, dur))


static func plan(e: Dictionary, video: Clip, only_cut: int = -1) -> Dictionary:
	var list: Array[Dictionary] = list_of(e)
	var cuts: Array[Dictionary] = ViewOffsets.cuts_of(e, video)
	var props: Dictionary = {}
	var matched: Array[Dictionary] = []
	if list.is_empty() or cuts.size() < 2 or video == null:
		return {"props": props, "matched": matched, "cuts": cuts}
	for k: int in range(1, cuts.size()):
		if only_cut >= 0 and k != only_cut:
			continue
		var a: int = int(cuts[k - 1]["view"])
		var b: int = int(cuts[k]["view"])
		if a == b:
			continue
		var named: Dictionary = find(list, a, b)
		if named.is_empty():
			continue
		if not props.has(a):
			props[a] = ViewMap.offset_prop(e, a)
		if not props.has(b):
			props[b] = ViewMap.offset_prop(e, b)
		var base: float = base_of(e, a, video, cuts)
		var want: float = ViewMap.clamp_offset(base + float(named["ms"]) / 1000.0)
		var mid: float = (float(cuts[k]["u0"]) + float(cuts[k]["u1"])) * 0.5
		var now: float = _value(props[b], e, b, video, mid)
		var delta: float = want - now
		if absf(delta) > ViewMap.OFFSET_EPS:
			props[b] = ViewOffsets.cut_plus(e, video, b, cuts[k], delta, props[b] if not (props[b] as Dictionary).is_empty() else AnimProp.make(0.0))
		matched.append({"cut": k, "from": a, "into": b, "seconds": want, "name": label_for(e, named)})
	return {"props": props, "matched": matched, "cuts": cuts}


static func match_commands(s: Sequence, c: Clip, e: Dictionary, only_cut: int = -1) -> Array[Command]:
	var out: Array[Command] = []
	if s == null or c == null or e.is_empty():
		return out
	var made: Dictionary = plan(e, c, only_cut)
	var props: Dictionary = made["props"]
	for idx: Variant in props.keys():
		var next: Dictionary = props[idx]
		var old: Dictionary = ViewMap.offset_prop(e, int(idx))
		if next.is_empty() or JSON.stringify(next) == JSON.stringify(old):
			continue
		out.append(PairCmds.SetOffset.new(s.id, c.id, ViewMap.param_path(e, ViewMap.offset_key(int(idx))), next, not ViewMap.of(e).is_empty()))
	return out


static func base_of(e: Dictionary, index: int, video: Clip, cuts: Array) -> float:
	if not cuts.is_empty() and int((cuts[0] as Dictionary)["view"]) == index:
		var c0: Dictionary = cuts[0]
		return ViewMap.offset_at(e, index, video, (float(c0["u0"]) + float(c0["u1"])) * 0.5)
	var p: Dictionary = ViewMap.offset_prop(e, index)
	if p.is_empty():
		return 0.0
	if not AnimProp.is_animated(p):
		return ViewMap.clamp_offset(float(AnimProp.static_value(p)))
	return ViewMap.clamp_offset(float(p.get("base", 0.0)))


static func measured_ms(e: Dictionary, video: Clip, cut_index: int) -> float:
	var cuts: Array[Dictionary] = ViewOffsets.cuts_of(e, video)
	if cut_index < 1 or cut_index >= cuts.size() or video == null:
		return 0.0
	var a: int = int(cuts[cut_index - 1]["view"])
	var b: int = int(cuts[cut_index]["view"])
	var mid: float = (float(cuts[cut_index]["u0"]) + float(cuts[cut_index]["u1"])) * 0.5
	return (ViewMap.offset_at(e, b, video, mid) - base_of(e, a, video, cuts)) * 1000.0


static func list_command(s: Sequence, c: Clip, e: Dictionary, list: Array) -> Command:
	return ClipCmds.SetClipParam.new(s.id, c.id, ViewMap.param_path(e, KEY), AnimProp.make(encode(list)))


static func auto_command(s: Sequence, c: Clip, e: Dictionary, on: bool) -> Command:
	return ClipCmds.SetClipParam.new(s.id, c.id, ViewMap.param_path(e, AUTO_KEY), AnimProp.make(on))

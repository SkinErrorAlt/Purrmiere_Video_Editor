extends RefCounted

const VERSION := 1
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const Track := preload("res://doc/track.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const AnimTime := preload("res://doc/anim_time.gd")
const LIMIT_EFFECT_ID := "time_fps_limit"
const PAIR_VIEW_ID := "pair_view"
const MARGIN_FRAMES := 4.0
const ADJACENT := 0.002
const NOTHING := Vector2(INF, -INF)
const EVERYWHERE := Vector2(-INF, INF)

static var quiet_total: int = 0


class SetKeysLive extends "res://doc/commands/command.gd":
	var clip_id: String = ""
	var path: String = ""
	var anim: Dictionary = {}
	var old: Dictionary = {}

	func _init(p_seq_id: String, p_clip_id: String, p_path: String, p_anim: Dictionary) -> void:
		label = "Keys " + p_path
		seq_id = p_seq_id
		clip_id = p_clip_id
		path = p_path
		anim = p_anim

	func live_key() -> String:
		return "clip_param|" + clip_id + "|" + path

	func do(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		if c == null:
			ok = false
			return
		old = c.get_param(path)
		ok = c.adopt_param(path, anim)
		doc.touch("meta")

	func undo(doc: Project) -> void:
		var c: Clip = clip(doc, clip_id)
		if c == null:
			return
		if old.is_empty():
			c.erase_param(path)
		else:
			c.adopt_param(path, old)
		doc.touch("meta")


static func _same(a: Variant, b: Variant) -> bool:
	return is_same(a, b) or a == b


static func common_prefix(a: Array, b: Array, most: int) -> int:
	var f: int = 0
	while f < most and (is_same(a[f], b[f]) or a[f] == b[f]):
		f += 1
	return f


static func common_suffix(a: Array, b: Array, most: int) -> int:
	var na: int = a.size() - 1
	var nb: int = b.size() - 1
	var k: int = 0
	while k < most and (is_same(a[na - k], b[nb - k]) or a[na - k] == b[nb - k]):
		k += 1
	return k


static func _key_t(ks: Array, i: int) -> float:
	return float((ks[i] as Dictionary).get("t", 0.0))


static func changed_span(old: Dictionary, new: Dictionary) -> Vector2:
	if is_same(old, new):
		return NOTHING
	if not AnimProp.is_animated(old) or not AnimProp.is_animated(new):
		return NOTHING if old == new else EVERYWHERE
	for key: Variant in old.keys():
		if String(key) != "layers" and (not new.has(key) or not _same(old[key], new[key])):
			return EVERYWHERE
	for key2: Variant in new.keys():
		if not old.has(key2):
			return EVERYWHERE
	var li: int = AnimProp.keys_layer_index(old)
	if li < 0 or li != AnimProp.keys_layer_index(new):
		return NOTHING if old == new else EVERYWHERE
	var ol: Array = old.get("layers", [])
	var nl: Array = new.get("layers", [])
	if ol.size() != nl.size():
		return EVERYWHERE
	for i: int in ol.size():
		if i != li and not _same(ol[i], nl[i]):
			return EVERYWHERE
	var lo_layer: Dictionary = ol[li]
	var ln_layer: Dictionary = nl[li]
	for key3: Variant in lo_layer.keys():
		if String(key3) != "keys" and (not ln_layer.has(key3) or not _same(lo_layer[key3], ln_layer[key3])):
			return EVERYWHERE
	for key4: Variant in ln_layer.keys():
		if not lo_layer.has(key4):
			return EVERYWHERE
	var raw_o: Variant = lo_layer.get("keys", [])
	var raw_n: Variant = ln_layer.get("keys", [])
	if not (raw_o is Array) or not (raw_n is Array):
		return EVERYWHERE
	var loop: String = str(lo_layer.get("loop", "once"))
	var ko: Array = AnimProp._prepared_keys(raw_o)
	var kn: Array = AnimProp._prepared_keys(raw_n)
	var no: int = ko.size()
	var nn: int = kn.size()
	var both: int = mini(no, nn)
	var f: int = common_prefix(ko, kn, both)
	if f == no and f == nn:
		return NOTHING
	if loop != "once" and loop != "continue":
		return EVERYWHERE
	if no == 0 or nn == 0:
		return EVERYWHERE
	var k: int = common_suffix(ko, kn, both - f)
	var lo_i: int = f - 2
	var lo: float = -INF
	if lo_i >= 0:
		lo = minf(_key_t(ko, lo_i), _key_t(kn, lo_i))
	var hi_o: int = no - 1 - k + 2
	var hi_n: int = nn - 1 - k + 2
	var hi: float = INF
	if hi_o <= no - 1 and hi_n <= nn - 1:
		hi = maxf(_key_t(ko, hi_o), _key_t(kn, hi_n))
	return Vector2(lo, hi)


static func picture_only(c: Clip, path: String) -> bool:
	if path.begins_with("audio") or AnimTime.exempt(path) or path == AnimTime.START_FIELD or AnimTime.is_inner(path):
		return false
	for e: Dictionary in c.effects:
		if String(e.get("id", "")) == LIMIT_EFFECT_ID and bool(e.get("enabled", true)):
			return false
	var parts: PackedStringArray = path.split(".")
	if parts.size() == 3 and parts[0] == "effects":
		if String(c.effect_by_uid(parts[1]).get("id", "")) == PAIR_VIEW_ID:
			return false
	return true


static func shown_span(seq: Sequence, c: Clip) -> Vector2:
	var first: float = c.start
	if c.has_transition():
		first = minf(first, c.transition_span().x)
	var last: float = c.end()
	var tr: Track = seq.track_of(c.id)
	if tr != null:
		var nxt: Clip = tr.next_clip(c)
		if nxt != null and nxt.has_transition() and absf(c.end() - nxt.start) <= ADJACENT:
			last = maxf(last, nxt.transition_span().y)
	return Vector2(first, last)


static func picture_same(seq: Sequence, c: Clip, path: String, old: Dictionary, new: Dictionary, playhead: float) -> bool:
	if seq == null or c == null or not picture_only(c, path):
		return false
	var span: Vector2 = changed_span(old, new)
	if span.x > span.y:
		return true
	var fps: float = seq.fps if seq.fps > 0.0 else 30.0
	var m: float = MARGIN_FRAMES / fps
	var shown: Vector2 = shown_span(seq, c)
	if playhead < shown.x - m or playhead > shown.y + m:
		return true
	var a: float = playhead - c.start - m
	var b: float = playhead - c.start + m
	if c.path_warped(path):
		if not c.path_monotonic(path):
			return false
		var pa: float = c.param_time(path, a)
		var pb: float = c.param_time(path, b)
		a = minf(pa, pb)
		b = maxf(pa, pb)
	return b < span.x or a > span.y


static func apply_live(doc: Project, seq: Sequence, cmd: SetKeysLive, playhead: float, may_skip: bool) -> bool:
	var c: Clip = seq.clip_by_id(cmd.clip_id) if seq != null else null
	var quiet: bool = may_skip and c != null and picture_same(seq, c, cmd.path, c.get_param(cmd.path), cmd.anim, playhead)
	if not quiet:
		doc.undo.live(cmd)
		return false
	var was: bool = doc.is_blocking_signals()
	doc.set_block_signals(true)
	doc.undo.live(cmd)
	doc.set_block_signals(was)
	quiet_total += 1
	return true

extends RefCounted

const Clip := preload("res://doc/clip.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const AnimDriver := preload("res://doc/anim_driver.gd")
const DerivedSource := preload("res://doc/derived_source.gd")
const GEOMETRY_GROUP := "Geometry"
const AnimTime := preload("res://doc/anim_time.gd")
const MaskShape := preload("res://doc/mask_shape.gd")
const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const PmMenu := preload("res://ui/kit/pm_menu.gd")

const EXPR_ID := "anim_add_expr"
const DRIVEN_ID := "anim_add_driven"
const EXPR_ADD := "Add an expression"
const EXPR_EDIT := "Edit the expression"
const DRIVEN_ADD := "Drive this from another value"
const DRIVEN_EDIT := "Edit what drives this"
const EXPR_MARK_TIP := "This value has an expression. Click to open it"
const DRIVEN_MARK_TIP := "This value is driven by another value. Click to open it"
const CYCLE_TIP := "This link is part of a loop, so it is switched off"
const OVERSHOOT_NOTE := "When off, the value never leaves the To range however far the source goes."
const SMOOTH_NOTE := "Each sample is one more reading of the source, so nine samples is nine times the work."
const LEAD_NOTE := "Read the source this far ahead. Negative reads behind."
const RANGE_BUTTON := "Use the source's range"
const BLENDS: Array = [["over", "Over"], ["add", "Add"], ["multiply", "Multiply"]]
const CURVES: Array = [["linear", "Straight"], ["ease_in", "Ease in"], ["ease_out", "Ease out"], ["ease_both", "Ease both"]]
const SMOOTH_CHOICES: Array = [["off", "Off"], ["average", "Average"], ["gauss", "Gaussian"]]
const NAME_CHIPS: Array = [
	["value", "What the layers below this one worked out"],
	["t", "Seconds into this value's own time"],
	["dur", "How long the clip is, in seconds"],
	["fps", "The frame rate it is being read at"],
	["frame", "t times fps, so the frame number"],
	["comp", "0 for x, 1 for y, and so on"],
	["pi", "3.14159265"],
]
const PRESETS: Array = [
	["Wobble", "value + sin(t * 8) * 0.02"],
	["Limit", "clamp(value, 0.2, 0.8)"],
	["Ramp", "lerp(0, 1, t / dur)"],
	["Step at a second", "t < 1 ? 0 : 1"],
	["Frame counter", "frame"],
]
const GRAPH_W := 160.0
const GRAPH_H := 80.0
const GRAPH_SAMPLES := 48
const GROUP_ORDER: PackedStringArray = ["Motion", "Time", "Audio", "Masks"]
const MOTION_LABELS: Dictionary = {
	"transform.pos": "Position", "transform.scale": "Scale", "transform.rotation": "Rotation",
	"transform.anchor": "Anchor", "transform.opacity": "Opacity",
	"motion_blur.amount": "Motion blur amount", "motion_blur.samples": "Motion blur samples",
	"motion_blur.shutter": "Motion blur shutter",
}
const TIME_LABELS: Dictionary = {"speed": "Speed", "anim_speed": "Animation speed"}
const AUDIO_LABELS: Dictionary = {"audio.volume": "Volume", "audio.pan": "Pan", "audio.pitch_keep": "Keep pitch"}


static func layer_index(p: Dictionary, type_: String) -> int:
	if not AnimProp.is_animated(p):
		return -1
	var layers: Array = p.get("layers", [])
	for i: int in layers.size():
		if str((layers[i] as Dictionary).get("type", "")) == type_:
			return i
	return -1


static func has_layer(p: Dictionary, type_: String) -> bool:
	return layer_index(p, type_) >= 0


static func layer_at(p: Dictionary, index: int) -> Dictionary:
	if not AnimProp.is_animated(p):
		return {}
	var layers: Array = p.get("layers", [])
	if index < 0 or index >= layers.size():
		return {}
	return layers[index]


static func menu_items(p: Dictionary) -> Array:
	return [
		PmMenu.item(EXPR_ID, EXPR_EDIT if has_layer(p, "expr") else EXPR_ADD),
		PmMenu.item(DRIVEN_ID, DRIVEN_EDIT if has_layer(p, "driven") else DRIVEN_ADD),
	]


static func owns_menu(id: String) -> bool:
	return id == EXPR_ID or id == DRIVEN_ID


static func kind_of_menu(id: String) -> String:
	if id == EXPR_ID:
		return "expr"
	if id == DRIVEN_ID:
		return "driven"
	return ""


static func struck(layer: Dictionary) -> bool:
	if str(layer.get("type", "")) != "driven":
		return false
	var src: Dictionary = AnimProp.driven_source(layer)
	if str(src.get("clip", "")).is_empty() or str(src.get("path", "")).is_empty():
		return false
	return AnimDriver.cycles().has(AnimProp.driven_key(src))


static func marks(p: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ei: int = layer_index(p, "expr")
	if ei >= 0:
		out.append({"kind": "expr", "icon": "fx", "index": ei, "struck": false, "tip": EXPR_MARK_TIP})
	var di: int = layer_index(p, "driven")
	if di >= 0:
		var bad: bool = struck(layer_at(p, di))
		out.append({"kind": "driven", "icon": "link", "index": di, "struck": bad, "tip": CYCLE_TIP if bad else DRIVEN_MARK_TIP})
	return out


static func expr_env(t: float, dur: float, value: float, fps: float, comp: int) -> Dictionary:
	return {
		"t": t, "dur": dur, "value": value, "fps": fps, "frame": t * fps, "comp": float(maxi(comp, 0)),
		"pi": PI, "e": 2.718281828459045, "tau": TAU,
	}


static func number_text(v: float) -> String:
	if absf(v) >= 100000.0 or (absf(v) < 0.001 and v != 0.0):
		return "%.4e" % v
	var out: String = "%.4f" % v
	while out.ends_with("0"):
		out = out.substr(0, out.length() - 1)
	if out.ends_with("."):
		out = out.substr(0, out.length() - 1)
	return out


static func result_text(code: String, t: float, dur: float, value: float, fps: float, comp: int) -> String:
	if code.strip_edges().is_empty():
		return "Nothing typed yet"
	var prog: Dictionary = AnimProp.expr_program(code)
	if not bool(prog.get("ok", false)):
		return "Cannot read that: " + str(prog.get("error", "bad expression"))
	if not bool(prog.get("fast", false)):
		return "That uses a name a keyframe does not know, so the value is left alone"
	var got: Dictionary = AnimProp.eval_expr(code, expr_env(t, dur, value, fps, comp))
	if not bool(got.get("ok", false)):
		return "Cannot read that: " + str(got.get("error", "bad expression"))
	return "Now: " + number_text(float(got.get("value", 0.0)))


static func move_layer(p: Dictionary, from: int, to: int) -> Dictionary:
	var out: Dictionary = p.duplicate(true)
	if not AnimProp.is_animated(out):
		return out
	var layers: Array = out["layers"]
	if from < 0 or from >= layers.size():
		return out
	var want: int = clampi(to, 0, layers.size() - 1)
	if want == from:
		return out
	var one: Variant = layers[from]
	layers.remove_at(from)
	layers.insert(want, one)
	return out


static func layers_below(p: Dictionary, index: int) -> Dictionary:
	if not AnimProp.is_animated(p):
		return p.duplicate(true)
	var layers: Array = p.get("layers", [])
	var want: int = clampi(index, 0, layers.size())
	return {"a": true, "base": p.get("base", 0.0), "layers": layers.slice(0, want)}


static func source_value(src_clip: Clip, src: Dictionary, t: float, fps: float) -> Dictionary:
	if src_clip == null:
		return {"ok": false, "v": 0.0}
	var path: String = str(src.get("path", ""))
	if path.is_empty():
		return {"ok": false, "v": 0.0}
	if DerivedSource.is_derived(path):
		var dshift: float = float(src.get("dst_start", 0.0)) - float(src.get("src_start", 0.0)) + float(src.get("lead", 0.0))
		return DerivedSource.sample(AnimDriver.bound(), src_clip, path, clampf(t + dshift, 0.0, maxf(src_clip.duration, 0.0)), fps)
	var p: Dictionary = src_clip.get_param(path)
	if p.is_empty():
		return {"ok": false, "v": 0.0}
	var shift: float = float(src.get("dst_start", 0.0)) - float(src.get("src_start", 0.0)) + float(src.get("lead", 0.0))
	var dur: float = maxf(src_clip.duration, 0.0)
	var at: float = clampf(t + shift, 0.0, dur)
	var pt: float = src_clip.param_time(path, at)
	var raw: Variant = AnimProp.evaluate(p, pt, dur, fps)
	var comp: int = int(src.get("comp", -1))
	if raw is Array:
		var a: Array = raw
		if a.is_empty():
			return {"ok": false, "v": 0.0}
		var pick: int = comp if comp >= 0 and comp < a.size() else 0
		return {"ok": true, "v": float(a[pick])}
	return {"ok": true, "v": scalar_of(raw)}


static func layer_title(layer: Dictionary) -> String:
	var kind: String = str(layer.get("type", ""))
	if kind == "keys":
		return "Keys"
	if kind == "noise":
		return "Noise, " + str(layer.get("kind", "perlin"))
	if kind == "wave":
		return "Wave, " + str(layer.get("shape", "sine"))
	if kind == "expr":
		return "Expression"
	if kind == "driven":
		return "Driven"
	return kind.capitalize()


static func stack_rows(p: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not AnimProp.is_animated(p):
		return out
	var layers: Array = p.get("layers", [])
	for i: int in layers.size():
		var layer: Dictionary = layers[i]
		out.append({
			"index": i,
			"type": str(layer.get("type", "")),
			"title": layer_title(layer),
			"on": bool(layer.get("on", true)),
			"blend": str(layer.get("blend", "over")),
			"weight": float(layer.get("weight", 1.0)),
		})
	return out


static func drop_index(local_y: float, row_h: float, count: int) -> int:
	if count <= 0 or row_h <= 0.0:
		return 0
	return clampi(int(floor(local_y / row_h)), 0, count - 1)


static func group_of(path: String) -> String:
	if path.begins_with("transform.") or path.begins_with("motion_blur."):
		return "Motion"
	if path == "speed" or path == AnimTime.SPEED_PATH or path.begins_with(AnimTime.SPEED_PATH + "."):
		return "Time"
	if path.ends_with(AnimTime.SPEED_TAIL) or path.ends_with(AnimTime.START_TAIL):
		return "Time"
	if path.begins_with("audio.") or path.begins_with("audio_effects."):
		return "Audio"
	if path.begins_with("masks."):
		return "Masks"
	if path.begins_with("effects."):
		return "Effects"
	if path.begins_with("props."):
		return "Motion"
	return "Motion"


static func effect_label(c: Clip, uid: String, sound: bool) -> String:
	var list: Array = c.audio_effects() if sound else c.effects
	for e: Variant in list:
		var ed: Dictionary = e
		if str(ed.get("uid", "")) != uid:
			continue
		var def: Dictionary = EffectSource.get_def(str(ed.get("id", "")))
		var named: String = str(def.get("label", ""))
		return named if not named.is_empty() else str(ed.get("id", uid))
	return uid


static func param_label(c: Clip, uid: String, key: String, sound: bool) -> String:
	var list: Array = c.audio_effects() if sound else c.effects
	for e: Variant in list:
		var ed: Dictionary = e
		if str(ed.get("uid", "")) != uid:
			continue
		var def: Dictionary = EffectSource.get_def(str(ed.get("id", "")))
		for spec: Dictionary in EffectSource.param_specs(def):
			if str(spec.get("key", "")) == key:
				var named: String = str(spec.get("label", ""))
				return named if not named.is_empty() else key.replace("_", " ").capitalize()
	if key == "mix":
		return "Mix"
	return key.replace("_", " ").capitalize()


static func mask_label(c: Clip, mask_id: String, key: String) -> String:
	for i: int in c.masks.size():
		var m: Dictionary = c.masks[i]
		if str(m.get("id", "")) != mask_id:
			continue
		return MaskShape.label_of(m, i) + " " + key.replace("_", " ")
	return mask_id + " " + key.replace("_", " ")


static func derived_range(c: Clip, path: String, fps: float, samples: int) -> Vector2:
	var lo: float = INF
	var hi: float = -INF
	for i: int in samples:
		var got: Dictionary = DerivedSource.sample(AnimDriver.bound(), c, path, maxf(c.duration, 0.0) * float(i) / float(samples - 1), fps)
		if bool(got["ok"]):
			lo = minf(lo, float(got["v"]))
			hi = maxf(hi, float(got["v"]))
	if is_inf(lo) or is_inf(hi):
		return Vector2(0.0, 1.0)
	if absf(hi - lo) < 0.000001:
		return Vector2(lo, lo + 1.0)
	return Vector2(lo, hi)


static func path_label(c: Clip, path: String) -> String:
	if DerivedSource.is_derived(path):
		return DerivedSource.label_of(path, AnimDriver.bound())
	if MOTION_LABELS.has(path):
		return String(MOTION_LABELS[path])
	if TIME_LABELS.has(path):
		return String(TIME_LABELS[path])
	if AUDIO_LABELS.has(path):
		return String(AUDIO_LABELS[path])
	var parts: PackedStringArray = path.split(".")
	if c != null and parts.size() >= 3 and (parts[0] == "effects" or parts[0] == "audio_effects"):
		var sound: bool = parts[0] == "audio_effects"
		return effect_label(c, parts[1], sound) + ": " + param_label(c, parts[1], parts[2], sound)
	if c != null and parts.size() >= 3 and parts[0] == "masks":
		return mask_label(c, parts[1], parts[2])
	if parts.size() >= 2 and parts[0] == "props":
		return parts[1].replace("_", " ").capitalize()
	if path.ends_with(AnimTime.SPEED_TAIL):
		return "Speed of " + path.substr(0, path.length() - AnimTime.SPEED_TAIL.length())
	return parts[parts.size() - 1].replace("_", " ").capitalize()


static func value_groups(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null:
		return out
	var buckets: Dictionary = {}
	var order: Array[String] = []
	for path: String in c.param_paths():
		var group: String = group_of(path)
		if group == "Effects":
			var parts: PackedStringArray = path.split(".")
			group = effect_label(c, parts[1], false) if parts.size() >= 3 else "Effects"
		elif path.begins_with("audio_effects."):
			var ap: PackedStringArray = path.split(".")
			group = effect_label(c, ap[1], true) if ap.size() >= 3 else "Audio"
		if not buckets.has(group):
			buckets[group] = []
			order.append(group)
		(buckets[group] as Array).append({"path": path, "label": path_label(c, path)})
	var named: Array[String] = []
	for want: String in GROUP_ORDER:
		if buckets.has(want):
			named.append(want)
	for rest: String in order:
		if not named.has(rest):
			named.append(rest)
	for group2: String in named:
		out.append({"group": group2, "values": buckets[group2]})
	var geo: Array[Dictionary] = DerivedSource.paths_for(AnimDriver.bound(), c)
	if not geo.is_empty():
		out.append({"group": GEOMETRY_GROUP, "values": geo})
	return out


static func source_clips(c: Clip, s: Sequence) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null:
		return out
	out.append({"id": c.id, "label": "This clip"})
	if s == null:
		return out
	var seen: Dictionary = {c.id: true}
	for other: Clip in s.linked(c):
		if other == null or seen.has(other.id):
			continue
		seen[other.id] = true
		out.append({"id": other.id, "label": clip_label(other) + ", linked"})
	for track: Track in s.all_tracks():
		if track == null:
			continue
		for oc: Clip in track.clips:
			if oc == null or seen.has(oc.id):
				continue
			seen[oc.id] = true
			out.append({"id": oc.id, "label": clip_label(oc) + ", " + track_label(track) + " at " + time_text(oc.start)})
	return out


static func track_label(tr: Track) -> String:
	if tr == null:
		return ""
	return tr.label if not tr.label.is_empty() else tr.id


static func clip_label(c: Clip) -> String:
	if c == null:
		return ""
	return c.label if not c.label.is_empty() else c.id


static func time_text(t: float) -> String:
	var whole: int = int(floor(maxf(t, 0.0)))
	return "%d:%02d" % [whole / 60, whole % 60]


static func source_range(c: Clip, path: String, fps: float, samples: int = 64) -> Vector2:
	if c == null or path.is_empty() or samples < 2:
		return Vector2(0.0, 1.0)
	if DerivedSource.is_derived(path):
		return derived_range(c, path, fps, samples)
	var p: Dictionary = c.get_param(path)
	if p.is_empty():
		return Vector2(0.0, 1.0)
	var dur: float = maxf(c.duration, 0.0)
	var lo: float = INF
	var hi: float = -INF
	for i: int in samples:
		var at: float = dur * float(i) / float(samples - 1)
		var pt: float = c.param_time(path, at)
		var raw: Variant = AnimProp.evaluate(p, pt, dur, fps)
		var v: float = scalar_of(raw)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	if is_inf(lo) or is_inf(hi):
		return Vector2(0.0, 1.0)
	if absf(hi - lo) < 0.000001:
		return Vector2(lo, lo + 1.0)
	return Vector2(lo, hi)


static func scalar_of(raw: Variant) -> float:
	if raw is Array:
		var a: Array = raw
		return float(a[0]) if not a.is_empty() else 0.0
	if raw is bool:
		return 1.0 if raw else 0.0
	if raw is float or raw is int:
		return float(raw)
	return 0.0


static func graph_span(layer: Dictionary) -> Vector2:
	var in_min: float = float(layer.get("in_min", 0.0))
	var in_max: float = float(layer.get("in_max", 1.0))
	var lo: float = minf(in_min, in_max)
	var hi: float = maxf(in_min, in_max)
	if absf(hi - lo) < 0.000001:
		hi = lo + 1.0
	var pad: float = (hi - lo) * 0.35
	return Vector2(lo - pad, hi + pad)


static func graph_out_span(layer: Dictionary) -> Vector2:
	var span: Vector2 = graph_span(layer)
	var lo: float = INF
	var hi: float = -INF
	for i: int in GRAPH_SAMPLES:
		var raw: float = lerpf(span.x, span.y, float(i) / float(GRAPH_SAMPLES - 1))
		var v: float = AnimProp.driven_map(layer, raw)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	if is_inf(lo) or is_inf(hi):
		return Vector2(0.0, 1.0)
	if absf(hi - lo) < 0.000001:
		hi = lo + 1.0
	return Vector2(lo, hi)


static func graph_points(layer: Dictionary, w: float, h: float, samples: int = GRAPH_SAMPLES) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if samples < 2 or w <= 0.0 or h <= 0.0:
		return out
	var inx: Vector2 = graph_span(layer)
	var outy: Vector2 = graph_out_span(layer)
	for i: int in samples:
		var u: float = float(i) / float(samples - 1)
		var raw: float = lerpf(inx.x, inx.y, u)
		var v: float = AnimProp.driven_map(layer, raw)
		var ny: float = (v - outy.x) / (outy.y - outy.x)
		out.append(Vector2(u * w, h - clampf(ny, 0.0, 1.0) * h))
	return out


static func graph_dot(layer: Dictionary, raw: float, w: float, h: float) -> Vector2:
	var inx: Vector2 = graph_span(layer)
	var outy: Vector2 = graph_out_span(layer)
	var nx: float = clampf((raw - inx.x) / (inx.y - inx.x), 0.0, 1.0)
	var ny: float = clampf((AnimProp.driven_map(layer, raw) - outy.x) / (outy.y - outy.x), 0.0, 1.0)
	return Vector2(nx * w, h - ny * h)


static func sentence_head(label: String) -> String:
	return "Drive " + label + " from"


static func smooth_of(layer: Dictionary) -> Dictionary:
	var raw: Variant = layer.get("smooth", null)
	if raw is Dictionary:
		var s: Dictionary = raw
		return {
			"mode": str(s.get("mode", "off")),
			"window": float(s.get("window", 0.2)),
			"taps": int(s.get("taps", 5)),
			"centre": bool(s.get("centre", true)),
		}
	return AnimProp.new_smooth()


static func with_smooth(layer: Dictionary, key: String, value: Variant) -> Dictionary:
	var s: Dictionary = smooth_of(layer)
	s[key] = value
	return s

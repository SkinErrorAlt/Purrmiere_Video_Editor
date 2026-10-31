extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Marker := preload("res://doc/marker.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const TitleStyle := preload("res://doc/title_style.gd")
const Verbs := preload("res://doc/verbs.gd")
const Presets := preload("res://doc/presets.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const MediaCmds := preload("res://doc/commands/media_cmds.gd")
const TrackCmds := preload("res://doc/commands/track_cmds.gd")
const EditCmds := preload("res://doc/commands/edit_cmds.gd")
const Undo := preload("res://doc/undo.gd")
const SubtitleAnims := preload("res://doc/subtitle_anims.gd")
const MarkerLayers := preload("res://doc/marker_layers.gd")
const TextAnimators := preload("res://doc/text_animators.gd")
const SUBTITLE_MEDIA_LABEL := "Subtitle"
const TAG_KIND := "tag"
const MIN_BOX := 0.25
const POP_SECONDS := 0.28
const RUN_GAP := 0.001
const DEFAULT_BOX_SECONDS := 0.8
const MIN_BOX_SECONDS := 0.05
const MAX_BOX_SECONDS := 30.0
const SPLIT_SPACE := " "
const SPLIT_CUSTOM := "custom"
const SPLIT_CHOICES := [
	{"id": "space", "label": "Space", "value": " "},
	{"id": "comma", "label": "Comma", "value": ","},
	{"id": "pipe", "label": "Pipe", "value": "|"},
	{"id": "newline", "label": "New line", "value": "\n"},
]
const TARGET_AUTO := "auto"
const TARGET_FIRST := "first"
const TARGET_LAST := "last"
const TARGET_EVERY := "every"
const TARGET_SELECTION := "selection"
const POP_TARGETS: PackedStringArray = ["auto", "first", "last", "every", "selection"]
const POP_TARGET_LABELS := {
	"auto": "Where it normally goes",
	"first": "The first box",
	"last": "The last box",
	"every": "Every box on its own",
	"selection": "The whole selection as one",
}
const ANIM_KEYS: PackedStringArray = ["scale", "opacity"]
const PROP_ANIM_IN := "anim_in"
const PROP_ANIM_OUT := "anim_out"
const PROP_ANIM_FIT := "anim_fit"
const KEY_TAG := "run"
const FIT_VERSION := 2
const PROP_STYLE_IN := "anim_in_style"
const PROP_STYLE_OUT := "anim_out_style"
const PROP_TRAVEL := "travel"
const TRAVEL_CURVES: PackedStringArray = ["ease_both", "ease_out", "ease_in", "linear"]
const TRAVEL_CURVE_LABELS: PackedStringArray = ["Ease in and out", "Ease out", "Ease in", "Straight"]
const MAX_TRAVEL_SECONDS := 2.0
const POSITION_NAMES: PackedStringArray = ["Home", "Up one", "Up two", "Up three"]

static var keep_hand_keys: bool = true
const FIT_EPS := 0.000001
const RESERVED_PROPS: PackedStringArray = ["anim_in", "anim_out", "anim_fit", "anim_in_style", "anim_out_style", "character", "travel"]
const PREF_SPLIT := "subtitles.split_character"
const PREF_BOX_SECONDS := "subtitles.box_seconds"
const PREF_LINK := "subtitles.link_new_boxes"


static func prefs_node() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var prefs: Node = (loop as SceneTree).root.get_node_or_null("/root/Prefs")
		if prefs != null and prefs.has_method("register"):
			return prefs
	return null


static func pref_specs() -> Array:
	return [
		[PREF_SPLIT, SPLIT_SPACE, {"label": "The character a typed phrase is split on when it is spread over text boxes", "type": "string"}],
		[PREF_BOX_SECONDS, DEFAULT_BOX_SECONDS, {"label": "How long a text box is when a point marker becomes text (seconds)", "type": "float", "min": MIN_BOX_SECONDS, "max": MAX_BOX_SECONDS}],
		[PREF_LINK, true, {"label": "Link the text boxes made in one go so they select and cut together", "type": "bool"}],
	]


static func register_prefs() -> Node:
	var prefs: Node = prefs_node()
	if prefs == null:
		return null
	for spec: Array in pref_specs():
		if not bool(prefs.call("is_registered", String(spec[0]))):
			prefs.call("register", String(spec[0]), spec[1], spec[2])
	return prefs


static func split_char() -> String:
	var prefs: Node = register_prefs()
	if prefs == null:
		return SPLIT_SPACE
	var v: String = String(prefs.call("get_value", PREF_SPLIT))
	return SPLIT_SPACE if v.is_empty() else v


static func set_split_char(sep: String) -> void:
	var prefs: Node = register_prefs()
	if prefs != null:
		prefs.call("set_value", PREF_SPLIT, SPLIT_SPACE if sep.is_empty() else sep)


static func split_choice_id(sep: String) -> String:
	for choice: Dictionary in SPLIT_CHOICES:
		if String(choice["value"]) == sep:
			return String(choice["id"])
	return SPLIT_CUSTOM


static func split_choice_value(id: String) -> String:
	for choice: Dictionary in SPLIT_CHOICES:
		if String(choice["id"]) == id:
			return String(choice["value"])
	return SPLIT_SPACE


static func box_seconds() -> float:
	var prefs: Node = register_prefs()
	if prefs == null:
		return DEFAULT_BOX_SECONDS
	return clampf(float(prefs.call("get_value", PREF_BOX_SECONDS)), MIN_BOX_SECONDS, MAX_BOX_SECONDS)


static func set_box_seconds(seconds: float) -> void:
	var prefs: Node = register_prefs()
	if prefs != null:
		prefs.call("set_value", PREF_BOX_SECONDS, clampf(seconds, MIN_BOX_SECONDS, MAX_BOX_SECONDS))


static func link_new_boxes() -> bool:
	var prefs: Node = register_prefs()
	if prefs == null:
		return true
	return bool(prefs.call("get_value", PREF_LINK))


static func set_link_new_boxes(on: bool) -> void:
	var prefs: Node = register_prefs()
	if prefs != null:
		prefs.call("set_value", PREF_LINK, on)


static func subtitle_style() -> Dictionary:
	return {"text": "", "size": 56.0, "colour": [1.0, 1.0, 1.0, 1.0], "valign": "bottom", "outline": 6.0, "outline_colour": [0.0, 0.0, 0.0, 1.0], "shadow": 4.0, "bold": true}


static func subtitle_media(doc: Project) -> MediaItem:
	for m: MediaItem in doc.media:
		if m.kind == "title" and m.label == SUBTITLE_MEDIA_LABEL:
			return m
	return null


static func ensure_subtitle_media(doc: Project, cmds: Array[Command]) -> String:
	var m: MediaItem = subtitle_media(doc)
	if m != null:
		return m.id
	var id: String = doc.mint_id("m")
	var d: Dictionary = {"id": id, "kind": "title", "label": SUBTITLE_MEDIA_LABEL, "bin": "", "probed": true, "duration": 5.0, "props": subtitle_style()}
	cmds.append(MediaCmds.AddMedia.new(d))
	return id


static func is_text_clip(doc: Project, c: Clip) -> bool:
	if doc == null or c == null:
		return false
	var m: MediaItem = doc.media_by_id(c.media_id)
	return m != null and m.kind == "title"


static func spans_from_markers(seq: Sequence, only_selected: PackedStringArray = PackedStringArray(), length: float = 0.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var want: float = clampf(length, MIN_BOX_SECONDS, MAX_BOX_SECONDS) if length > 0.0 else box_seconds()
	var list: Array[Marker] = []
	for mk: Marker in MarkerLayers.usable(seq):
		if mk.kind == TAG_KIND:
			continue
		if only_selected.is_empty() or only_selected.has(mk.id):
			list.append(mk)
	list.sort_custom(func(a: Marker, b: Marker) -> bool: return a.time < b.time)
	for i: int in list.size():
		var mk: Marker = list[i]
		var a: float = mk.time
		var b: float = mk.end()
		if mk.duration <= 0.0:
			b = a + want
			if i + 1 < list.size():
				b = minf(b, list[i + 1].time)
		if seq.in_point >= 0.0 and seq.out_point >= 0.0 and (b <= seq.in_point or a >= seq.out_point):
			continue
		if b - a < MIN_BOX_SECONDS:
			continue
		out.append({"start": a, "duration": b - a, "text": mk.label, "marker": mk.id})
	return out


static func track_is_free(tr: Track, start: float, end: float) -> bool:
	for c: Clip in tr.clips:
		if c.start < end and c.end() > start:
			return false
	return true


static func pick_text_track(doc: Project, seq: Sequence, spans: Array[Dictionary], cmds: Array[Command]) -> String:
	var lo: float = INF
	var hi: float = -INF
	for sp: Dictionary in spans:
		lo = minf(lo, float(sp["start"]))
		hi = maxf(hi, float(sp["start"]) + float(sp["duration"]))
	var base: int = -1
	for i: int in seq.video_tracks.size():
		if seq.selected_clip_ids.size() > 0 and seq.track_of(seq.selected_clip_ids[0]) == seq.video_tracks[i]:
			base = i
	if base < 0:
		for i: int in seq.video_tracks.size():
			if seq.video_tracks[i].targeted:
				base = i
	if base < 0:
		base = 0
	for i: int in range(base, seq.video_tracks.size()):
		var tr: Track = seq.video_tracks[i]
		if tr.subtitle and Verbs.track_accepts(doc, seq, tr, "place") and track_is_free(tr, lo, hi):
			return tr.id
	var id: String = doc.mint_id("t")
	cmds.append(TrackCmds.AddTrack.new(seq.id, "video", -1, {"id": id, "label": "Text " + str(seq.video_tracks.size() + 1), "subtitle": true}))
	return id


static func boxes_from_marks(doc: Project, seq: Sequence, spans: Array[Dictionary], pop_in: bool, style: Dictionary = {}, target: String = "auto", link: bool = true, anim_style: Dictionary = {}) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null or seq == null or spans.is_empty():
		return out
	var want: String = target if POP_TARGETS.has(target) else TARGET_AUTO
	var cmds: Array[Command] = []
	var media_id: String = ensure_subtitle_media(doc, cmds)
	var track_id: String = pick_text_track(doc, seq, spans, cmds)
	for run: Array in group_runs(spans):
		var anims: Array[Dictionary] = run_anim_boxes_for("in", run, want, anim_style) if pop_in else ([] as Array[Dictionary])
		for i: int in run.size():
			var sp: Dictionary = run[i]
			var id: String = doc.mint_id("c")
			var props: Dictionary = style.duplicate(true)
			props["text"] = String(sp.get("text", ""))
			if pop_in:
				props[PROP_ANIM_IN] = want
				if not SubtitleAnims.is_default(anim_style):
					props[PROP_STYLE_IN] = SubtitleAnims.snapshot(anim_style)
			var cd: Dictionary = {"id": id, "media_id": media_id, "label": String(sp.get("text", "Text")), "start": float(sp["start"]), "duration": float(sp["duration"]), "in_offset": 0.0, "props": props}
			if i < anims.size() and not anims[i].is_empty():
				cd["transform"] = anims[i].duplicate(true)
			cmds.append(ClipCmds.PlaceClip.new(seq.id, track_id, cd))
			out.append(id)
	if link and out.size() > 1 and link_new_boxes():
		cmds.append(ClipCmds.Link.new(seq.id, out, doc.mint_id("l")))
	if not Verbs.run(doc, "Text boxes from marks", cmds):
		return PackedStringArray()
	return out


static func group_runs(items: Array) -> Array[Array]:
	var sorted: Array = []
	for it: Variant in items:
		sorted.append(it)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	var out: Array[Array] = []
	var cur: Array[Dictionary] = []
	var prev_end: float = -INF
	for it2: Dictionary in sorted:
		var s: float = float(it2["start"])
		if not cur.is_empty() and s - prev_end > RUN_GAP:
			out.append(cur)
			cur = []
		cur.append(it2)
		prev_end = maxf(prev_end, s + float(it2["duration"]))
	if not cur.is_empty():
		out.append(cur)
	return out


static func run_span(run: Array) -> PackedFloat64Array:
	if run.is_empty():
		return PackedFloat64Array([0.0, 0.0])
	var lo: float = float((run[0] as Dictionary)["start"])
	var hi: float = lo
	for it: Variant in run:
		var d: Dictionary = it
		lo = minf(lo, float(d["start"]))
		hi = maxf(hi, float(d["start"]) + float(d["duration"]))
	return PackedFloat64Array([lo, hi])


static func run_anim(which: String, run_duration: float, style: Dictionary = {}) -> Dictionary:
	if SubtitleAnims.per_char(style):
		return {}
	if not SubtitleAnims.is_default(style):
		return SubtitleAnims.curves_for(style, "in" if which == "in" else "out", run_duration)
	if which == "in":
		return {"scale": pop_in_scale(run_duration), "opacity": pop_in_opacity(run_duration)}
	return {"scale": pop_out_scale(run_duration), "opacity": pop_out_opacity(run_duration)}


static func curve_window(curve: Dictionary) -> PackedFloat64Array:
	var ks: Array[Dictionary] = AnimProp.keys(curve)
	if ks.is_empty():
		return PackedFloat64Array()
	return PackedFloat64Array([float(ks[0].get("t", 0.0)), float(ks[ks.size() - 1].get("t", 0.0))])


static func curve_for_box(curve: Dictionary, box_offset: float, box_duration: float) -> Dictionary:
	var window: PackedFloat64Array = curve_window(curve)
	if window.is_empty():
		return {}
	if box_offset + box_duration <= window[0] + RUN_GAP:
		return {}
	if box_offset >= window[1] - RUN_GAP:
		return {}
	return tagged(AnimProp.shift_keys(curve, -box_offset))


static func tagged(curve: Dictionary) -> Dictionary:
	var out: Dictionary = curve.duplicate(true)
	var li: int = AnimProp.keys_layer_index(out)
	if li < 0:
		return out
	for k: Variant in (out["layers"][li] as Dictionary).get("keys", []):
		(k as Dictionary)[KEY_TAG] = true
	return out


static func has_run_keys(p: Variant) -> bool:
	if not (p is Dictionary):
		return false
	for k: Dictionary in AnimProp.keys(p):
		if bool(k.get(KEY_TAG, false)):
			return true
	return false


static func strip_run_keys(p: Variant, fallback: Dictionary) -> Dictionary:
	if not (p is Dictionary) or not keep_hand_keys:
		return fallback.duplicate(true)
	var out: Dictionary = (p as Dictionary).duplicate(true)
	var li: int = AnimProp.keys_layer_index(out)
	if li < 0:
		return out
	var layer: Dictionary = out["layers"][li]
	var kept: Array = []
	for k: Variant in layer.get("keys", []):
		if not bool((k as Dictionary).get(KEY_TAG, false)):
			kept.append(k)
	layer["keys"] = kept
	if kept.is_empty() and (out["layers"] as Array).size() == 1:
		return AnimProp.make(out.get("base", AnimProp.static_value(fallback)))
	return out


static func is_legacy_box(c: Clip) -> bool:
	var fit: Variant = c.props.get(PROP_ANIM_FIT)
	if fit is Array and (fit as Array).size() >= 10 and int((fit as Array)[9]) >= FIT_VERSION:
		return false
	for k: String in ANIM_KEYS:
		if has_run_keys(c.transform.get(k)):
			return false
	return true


static func cleared_transform(c: Clip) -> Dictionary:
	var blank: Dictionary = Clip.default_transform()
	var tf: Dictionary = c.transform.duplicate(true)
	var legacy: bool = is_legacy_box(c)
	for k: String in ANIM_KEYS:
		tf[k] = (blank[k] as Dictionary).duplicate(true) if legacy else strip_run_keys(tf.get(k), blank[k])
	return tf


static func run_anim_boxes(which: String, run: Array) -> Array[Dictionary]:
	return run_anim_boxes_for(which, run, TARGET_AUTO)


static func anchor_index(which: String, run: Array, target: String) -> int:
	if run.is_empty():
		return 0
	if target == TARGET_FIRST:
		return 0
	if target == TARGET_LAST:
		return run.size() - 1
	return 0 if which == "in" else run.size() - 1


static func anim_window(which: String, run: Array, target: String) -> PackedFloat64Array:
	var span: PackedFloat64Array = run_span(run)
	if run.is_empty():
		return span
	var at: int = anchor_index(which, run, target)
	var box: Dictionary = run[at]
	var lo: float = span[0]
	var hi: float = span[1]
	if which == "in":
		lo = float(box["start"])
	else:
		hi = float(box["start"]) + float(box["duration"])
	if hi - lo < RUN_GAP:
		hi = lo + RUN_GAP
	return PackedFloat64Array([lo, hi])


static func slice_run(which: String, run: Array, from_t: float, to_t: float, style: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var curves: Dictionary = run_anim(which, to_t - from_t, style)
	for it: Variant in run:
		var box: Dictionary = it
		var frag: Dictionary = {}
		for k: Variant in curves.keys():
			var sliced: Dictionary = curve_for_box(curves[k], float(box["start"]) - from_t, float(box["duration"]))
			if not sliced.is_empty():
				frag[String(k)] = sliced
		out.append(frag)
	return out


static func run_anim_boxes_for(which: String, run: Array, target: String, style: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if run.is_empty():
		return out
	var want: String = target if POP_TARGETS.has(target) else TARGET_AUTO
	if want == TARGET_EVERY:
		for it: Variant in run:
			var box: Dictionary = it
			var one: Array[Dictionary] = slice_run(which, [box], float(box["start"]), float(box["start"]) + float(box["duration"]), style)
			out.append(one[0] if not one.is_empty() else {})
		return out
	var window: PackedFloat64Array = anim_window(which, run, want)
	return slice_run(which, run, window[0], window[1], style)


static func merge_curves(into: Dictionary, extra: Dictionary) -> Dictionary:
	var out: Dictionary = into.duplicate(true)
	for k: Dictionary in AnimProp.keys(extra):
		var t: float = float(k.get("t", 0.0))
		out = AnimProp.set_key(out, t, k.get("v", 0.0), String(k.get("i", "")))
		if bool(k.get(KEY_TAG, false)):
			out = AnimProp.set_key_fields(out, t, {KEY_TAG: true})
	return out


static func pop_window(duration: float) -> float:
	if duration <= 0.0:
		return POP_SECONDS
	return minf(POP_SECONDS, duration)


static func pop_in_scale(duration: float, offset: float = 0.0) -> Dictionary:
	var w: float = pop_window(duration)
	var p: Dictionary = AnimProp.make([1.0, 1.0])
	p = AnimProp.set_key(p, 0.0 + offset, [0.6, 0.6], "ease_out")
	p = AnimProp.set_key(p, w * 0.6 + offset, [1.08, 1.08], "ease_both")
	p = AnimProp.set_key(p, w + offset, [1.0, 1.0], "ease_both")
	return p


static func pop_in_opacity(duration: float, offset: float = 0.0) -> Dictionary:
	var w: float = pop_window(duration)
	var p: Dictionary = AnimProp.make(1.0)
	p = AnimProp.set_key(p, 0.0 + offset, 0.0, "ease_out")
	p = AnimProp.set_key(p, w * 0.6 + offset, 1.0, "ease_both")
	return p


static func pop_out_scale(duration: float) -> Dictionary:
	var w: float = pop_window(duration)
	var p: Dictionary = AnimProp.make([1.0, 1.0])
	p = AnimProp.set_key(p, maxf(duration - w, 0.0), [1.0, 1.0], "ease_in")
	p = AnimProp.set_key(p, maxf(duration - w * 0.4, 0.0), [1.06, 1.06], "ease_both")
	p = AnimProp.set_key(p, duration, [0.5, 0.5], "ease_in")
	return p


static func pop_out_opacity(duration: float) -> Dictionary:
	var w: float = pop_window(duration)
	var p: Dictionary = AnimProp.make(1.0)
	p = AnimProp.set_key(p, maxf(duration - w * 0.6, 0.0), 1.0, "ease_in")
	p = AnimProp.set_key(p, duration, 0.0, "ease_in")
	return p


static func sorted_text_clips(doc: Project, seq: Sequence, ids: PackedStringArray) -> Array[Clip]:
	var out: Array[Clip] = []
	for id: String in ids:
		var c: Clip = seq.clip_by_id(id)
		if c != null and is_text_clip(doc, c):
			out.append(c)
	out.sort_custom(func(a: Clip, b: Clip) -> bool: return a.start < b.start)
	return out


static func glue_for(sep: String) -> String:
	if sep.is_empty() or sep == SPLIT_SPACE:
		return " "
	if sep == "\n":
		return "\n"
	return sep + " "


static func split_words(phrase: String, sep: String = " ") -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var cut: String = sep if not sep.is_empty() else SPLIT_SPACE
	var text: String = phrase.replace("\r\n", "\n").replace("\r", "\n")
	var parts: PackedStringArray = PackedStringArray()
	if cut == SPLIT_SPACE:
		parts = text.replace("\n", " ").replace("\t", " ").split(" ", false)
	else:
		parts = text.split(cut, false)
	for w: String in parts:
		var t: String = w.strip_edges()
		if not t.is_empty():
			out.append(t)
	return out


static func chunks(words: PackedStringArray, n: int, glue: String = " ") -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if n <= 0:
		return out
	var per: float = float(words.size()) / float(n)
	for i: int in n:
		var a: int = int(round(per * float(i)))
		var b: int = int(round(per * float(i + 1)))
		var parts: PackedStringArray = PackedStringArray()
		for k: int in range(a, mini(b, words.size())):
			parts.append(words[k])
		out.append(glue.join(parts))
	return out


static func map_phrase(doc: Project, seq: Sequence, ids: PackedStringArray, phrase: String, one_word_per_box: bool, alternate: bool, colour_a: Array, colour_b: Array, sep: String = "") -> bool:
	var cut: String = sep if not sep.is_empty() else split_char()
	if not sep.is_empty():
		set_split_char(sep)
	var boxes: Array[Clip] = sorted_text_clips(doc, seq, ids)
	var words: PackedStringArray = split_words(phrase, cut)
	if boxes.is_empty() or words.is_empty():
		return false
	var cmds: Array[Command] = []
	var targets: Array[Dictionary] = []
	if one_word_per_box and words.size() != boxes.size():
		var total: float = 0.0
		for b: Clip in boxes:
			total += b.duration
		var per_word: float = total / float(words.size())
		var track: Track = seq.track_of(boxes[0].id)
		var media_id: String = boxes[0].media_id
		var base_props: Dictionary = boxes[0].props.duplicate(true)
		var t: float = boxes[0].start
		var remove: PackedStringArray = PackedStringArray()
		for b2: Clip in boxes:
			remove.append(b2.id)
		cmds.append(ClipCmds.RemoveClips.new(seq.id, remove))
		for i: int in words.size():
			var id: String = doc.mint_id("c")
			var props: Dictionary = base_props.duplicate(true)
			props["text"] = words[i]
			var cd: Dictionary = {"id": id, "media_id": media_id, "label": words[i], "start": t, "duration": per_word, "in_offset": 0.0, "props": props}
			targets.append({"new": cd, "text": words[i], "index": i})
			t += per_word
		for tg: Dictionary in targets:
			var cd2: Dictionary = tg["new"]
			if alternate:
				(cd2["props"] as Dictionary)["colour"] = colour_a if int(tg["index"]) % 2 == 0 else colour_b
			cmds.append(ClipCmds.PlaceClip.new(seq.id, track.id, cd2))
		return Verbs.run(doc, "Phrase across boxes", cmds)
	var texts: PackedStringArray = chunks(words, boxes.size(), glue_for(cut)) if not one_word_per_box else words
	for i: int in boxes.size():
		var b3: Clip = boxes[i]
		var props2: Dictionary = b3.props.duplicate(true)
		props2["text"] = texts[i] if i < texts.size() else ""
		if alternate:
			props2["colour"] = colour_a if i % 2 == 0 else colour_b
		cmds.append(ClipCmds.SetClipField.new(seq.id, b3.id, "props", props2))
		if String(b3.label) != String(props2["text"]):
			cmds.append(ClipCmds.SetClipField.new(seq.id, b3.id, "label", String(props2["text"])))
	return Verbs.run(doc, "Phrase across boxes", cmds)


static func items_of(boxes: Array[Clip]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Clip in boxes:
		out.append({"start": b.start, "duration": b.duration, "clip": b})
	return out


static func mark_key(which: String) -> String:
	return PROP_ANIM_IN if which == "in" else PROP_ANIM_OUT


static func style_key(which: String) -> String:
	return PROP_STYLE_IN if which == "in" else PROP_STYLE_OUT


static func style_of(c: Clip, which: String) -> Dictionary:
	var v: Variant = c.props.get(style_key(which))
	return v if v is Dictionary else {}


static func style_id(c: Clip, which: String) -> String:
	var st: Dictionary = style_of(c, which)
	return "" if SubtitleAnims.is_default(st) else String(st.get("id", "")) + "|" + str(st.get("seconds", 0.0)) + "|" + str(st.get("curves", {}).hash())


static func apply_pop(doc: Project, seq: Sequence, ids: PackedStringArray, which: String, target: String = "auto", anim_style: Dictionary = {}) -> bool:
	var boxes: Array[Clip] = sorted_text_clips(doc, seq, ids)
	if boxes.is_empty():
		return false
	var want: String = target if POP_TARGETS.has(target) else TARGET_AUTO
	var items: Array[Dictionary] = items_of(boxes)
	var runs: Array[Array] = []
	if want == TARGET_SELECTION:
		runs.append(items)
	else:
		runs = group_runs(items)
	var inner: String = TARGET_AUTO if want == TARGET_SELECTION else want
	var cmds: Array[Command] = []
	for run: Array in runs:
		var anims: Array[Dictionary] = run_anim_boxes_for(which, run, inner, anim_style)
		for i: int in run.size():
			var c: Clip = (run[i] as Dictionary)["clip"]
			var props: Dictionary = c.props.duplicate(true)
			props[mark_key(which)] = want
			props.erase(PROP_ANIM_FIT)
			if SubtitleAnims.is_default(anim_style):
				props.erase(style_key(which))
			else:
				props[style_key(which)] = SubtitleAnims.snapshot(anim_style)
			cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "props", props))
			if i >= anims.size() or anims[i].is_empty():
				continue
			var tf: Dictionary = c.transform.duplicate(true)
			for k: Variant in anims[i].keys():
				var key: String = String(k)
				var base: Dictionary = tf[key] if tf.get(key) is Dictionary else AnimProp.make(0.0)
				tf[key] = merge_curves(base, anims[i][k])
			cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "transform", tf))
	if cmds.is_empty():
		return false
	return Verbs.run(doc, "Pop " + which, cmds)


static func clear_pops(doc: Project, seq: Sequence, ids: PackedStringArray) -> bool:
	var boxes: Array[Clip] = sorted_text_clips(doc, seq, ids)
	if boxes.is_empty():
		return false
	var cmds: Array[Command] = []
	for c: Clip in boxes:
		if not c.props.has(PROP_ANIM_IN) and not c.props.has(PROP_ANIM_OUT):
			continue
		var props: Dictionary = TextAnimators.without_run(c.props)
		props.erase(PROP_ANIM_IN)
		props.erase(PROP_ANIM_OUT)
		props.erase(PROP_ANIM_FIT)
		props.erase(PROP_STYLE_IN)
		props.erase(PROP_STYLE_OUT)
		cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "props", props))
		cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "transform", cleared_transform(c)))
	if cmds.is_empty():
		return false
	return Verbs.run(doc, "Clear text animation", cmds)


static func lane_items(doc: Project, seq: Sequence, tr: Track) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if tr == null:
		return out
	var boxes: Array[Clip] = []
	for c: Clip in tr.clips:
		if is_text_clip(doc, c):
			boxes.append(c)
	boxes.sort_custom(func(a: Clip, b: Clip) -> bool: return a.start < b.start)
	return items_of(boxes)


static func tracks_of(seq: Sequence, boxes: Array[Clip]) -> Array[Track]:
	var out: Array[Track] = []
	for c: Clip in boxes:
		var tr: Track = seq.track_of(c.id)
		if tr != null and not out.has(tr):
			out.append(tr)
	return out


static func runs_touching(doc: Project, seq: Sequence, boxes: Array[Clip], dropped: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	var wanted: Dictionary = {}
	for c: Clip in boxes:
		wanted[c.id] = true
	for tr: Track in tracks_of(seq, boxes):
		for run: Array in group_runs(lane_items(doc, seq, tr)):
			var hit: bool = false
			var left: Array[Dictionary] = []
			for it: Variant in run:
				var d: Dictionary = it
				var id: String = (d["clip"] as Clip).id
				if wanted.has(id):
					hit = true
				if dropped.has(id):
					continue
				left.append(d)
			if not hit or left.is_empty():
				continue
			for sub: Array in group_runs(left):
				out.append(sub)
	return out


static func respread_cmds(seq: Sequence, runs: Array[Array]) -> Array[Command]:
	var cmds: Array[Command] = []
	for run: Array in runs:
		for it: Variant in run:
			var c: Clip = (it as Dictionary)["clip"]
			if not c.props.has(PROP_ANIM_IN) and not c.props.has(PROP_ANIM_OUT):
				continue
			var props: Dictionary = c.props.duplicate(true)
			props[PROP_ANIM_FIT] = []
			cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "props", props))
	return cmds


static func respread(doc: Project, seq: Sequence, ids: PackedStringArray) -> bool:
	var boxes: Array[Clip] = sorted_text_clips(doc, seq, ids)
	if boxes.is_empty():
		return false
	var cmds: Array[Command] = respread_cmds(seq, runs_touching(doc, seq, boxes, {}))
	if cmds.is_empty():
		return false
	return Verbs.run(doc, "Update text animation", cmds)


static func remove_section(doc: Project, seq: Sequence, ids: PackedStringArray) -> bool:
	var gone: Array[Clip] = sorted_text_clips(doc, seq, ids)
	if gone.is_empty():
		return false
	var remove: PackedStringArray = PackedStringArray()
	for c: Clip in gone:
		remove.append(c.id)
	var cmds: Array[Command] = []
	cmds.append(ClipCmds.RemoveClips.new(seq.id, remove))
	return Verbs.run(doc, "Remove text section", cmds)


static func box_order(a: Clip, b: Clip) -> bool:
	if a.start != b.start:
		return a.start < b.start
	return a.id < b.id


static func title_ids(doc: Project) -> Dictionary:
	var out: Dictionary = {}
	for m: MediaItem in doc.media:
		if m.kind == "title":
			out[m.id] = true
	return out


static func marked_boxes(doc: Project, tr: Track, titles: Dictionary = {}) -> Array[Clip]:
	var out: Array[Clip] = []
	var known: Dictionary = titles if not titles.is_empty() else title_ids(doc)
	var sorted: bool = true
	for c: Clip in tr.clips:
		if (c.props.has(PROP_ANIM_IN) or c.props.has(PROP_ANIM_OUT)) and known.has(c.media_id):
			if not out.is_empty() and not box_order(out[out.size() - 1], c):
				sorted = false
			out.append(c)
	if not sorted:
		out.sort_custom(box_order)
	return out


static func mark_of(c: Clip, which: String) -> String:
	var v: Variant = c.props.get(mark_key(which), "")
	if not (v is String) or String(v).is_empty():
		return ""
	return String(v) if POP_TARGETS.has(String(v)) else TARGET_AUTO


static func which_runs(boxes: Array[Clip], which: String) -> Array[Array]:
	var out: Array[Array] = []
	var cur: Array[Dictionary] = []
	var cur_mark: String = ""
	var cur_style: String = ""
	var prev_end: float = -INF
	for c: Clip in boxes:
		var m: String = mark_of(c, which)
		var sid: String = style_id(c, which) if not m.is_empty() else ""
		if m.is_empty():
			if not cur.is_empty():
				out.append(cur)
				cur = []
			prev_end = maxf(prev_end, c.end())
			continue
		var gap_break: bool = m != TARGET_SELECTION and c.start - prev_end > RUN_GAP
		if not cur.is_empty() and (m != cur_mark or sid != cur_style or gap_break or m == TARGET_EVERY):
			out.append(cur)
			cur = []
		cur_mark = m
		cur_style = sid
		cur.append({"start": c.start, "duration": c.duration, "clip": c})
		prev_end = maxf(prev_end, c.end())
	if not cur.is_empty():
		out.append(cur)
	return out


static func run_window(which: String, run: Array, mark: String) -> PackedFloat64Array:
	if mark == TARGET_EVERY:
		var box: Dictionary = run[0]
		return PackedFloat64Array([float(box["start"]), float(box["start"]) + maxf(float(box["duration"]), RUN_GAP)])
	return anim_window(which, run, TARGET_AUTO if mark == TARGET_SELECTION else mark)


static func plan_fits(boxes: Array[Clip]) -> Dictionary:
	var fits: Dictionary = {}
	for c: Clip in boxes:
		fits[c.id] = ["", 0.0, 0.0, "", 0.0, 0.0, c.duration, style_id(c, "in"), style_id(c, "out"), FIT_VERSION, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for which: String in ["in", "out"]:
		var slot: int = 0 if which == "in" else 3
		for run: Array in which_runs(boxes, which):
			var mark: String = mark_of((run[0] as Dictionary)["clip"], which)
			var w: PackedFloat64Array = run_window(which, run, mark)
			var letters: bool = SubtitleAnims.per_char(style_of((run[0] as Dictionary)["clip"], which))
			var total: int = 0
			if letters:
				for it0: Variant in run:
					var c0: Clip = (it0 as Dictionary)["clip"]
					if c0.start >= w[0] - RUN_GAP and c0.start < w[1] - RUN_GAP:
						total += letters_of(c0)
			var seen: int = 0
			var lslot: int = 10 if which == "in" else 13
			for it: Variant in run:
				var c2: Clip = (it as Dictionary)["clip"]
				var fit: Array = fits[c2.id]
				fit[slot] = mark
				fit[slot + 1] = c2.start - w[0]
				fit[slot + 2] = w[1] - w[0]
				if letters and total > 0 and c2.start >= w[0] - RUN_GAP and c2.start < w[1] - RUN_GAP:
					var n: int = letters_of(c2)
					fit[lslot] = float(seen)
					fit[lslot + 1] = float(seen + n)
					fit[lslot + 2] = float(total)
					seen += n
	return fits


static func letters_of(c: Clip) -> int:
	var t: Variant = TextAnimators.plain(c.props.get("text", ""))
	return String(t).length() if t is String else 0


static func letter_props(c: Clip, props: Dictionary, fit: Array) -> Dictionary:
	var out: Dictionary = TextAnimators.without_run(props)
	for which: String in ["in", "out"]:
		var slot: int = 0 if which == "in" else 3
		var lslot: int = 10 if which == "in" else 13
		var style: Dictionary = style_of(c, which)
		if String(fit[slot]).is_empty() or not SubtitleAnims.per_char(style) or fit.size() < 16 or float(fit[lslot + 2]) <= 0.0:
			continue
		var length: float = float(fit[slot + 2])
		var secs: float = minf(float(style.get("seconds", POP_SECONDS)), length)
		var off: float = float(fit[slot + 1])
		var begin: float = 0.0 if which == "in" else maxf(length - secs, 0.0)
		var n: float = float(fit[lslot + 2])
		var t0: float = begin + float(fit[lslot]) / n * secs - off
		var t1: float = begin + float(fit[lslot + 1]) / n * secs - off
		if t1 - t0 < 0.0001:
			t1 = t0 + 0.0001
		var settings: Dictionary = {"name": "Run letters " + which, "run": true, "opacity": 0.0, "scale": 40.0, "ease": "ease_out"}
		out = TextAnimators.with_added(out, settings)
		var i: int = TextAnimators.count(out) - 1
		var field: String = "start" if which == "in" else "end"
		if which == "out":
			out[TextAnimators.key(i, "end")] = 0.0
		var sweep: Dictionary = AnimProp.set_key(AnimProp.set_key(AnimProp.make(0.0), t0, 0.0, "linear"), t1, 100.0, "linear")
		out[TextAnimators.key(i, field)] = sweep
	return out


static func fit_same(stored: Variant, fit: Array) -> bool:
	if not (stored is Array):
		return false
	var a: Array = stored
	if a.size() != fit.size():
		return false
	for i: int in fit.size():
		if fit[i] is String:
			if not (a[i] is String) or String(a[i]) != String(fit[i]):
				return false
		elif not (a[i] is float or a[i] is int) or absf(float(a[i]) - float(fit[i])) > FIT_EPS:
			return false
	return true


static func box_frag(which: String, offset: float, box_duration: float, length: float, style: Dictionary = {}) -> Dictionary:
	var frag: Dictionary = {}
	var curves: Dictionary = run_anim(which, length, style)
	for k: Variant in curves.keys():
		var sliced: Dictionary = curve_for_box(curves[k], offset, box_duration)
		if not sliced.is_empty():
			frag[String(k)] = sliced
	return frag


static func fitted_transform(c: Clip, fit: Array) -> Dictionary:
	var tf: Dictionary = cleared_transform(c)
	for slot: int in [0, 3]:
		if String(fit[slot]).is_empty():
			continue
		var which: String = "in" if slot == 0 else "out"
		var frag: Dictionary = box_frag(which, float(fit[slot + 1]), c.duration, float(fit[slot + 2]), style_of(c, which))
		for k2: Variant in frag.keys():
			tf[String(k2)] = merge_curves(tf[String(k2)], frag[k2])
	return tf


static func follow_cmds(doc: Project, seq: Sequence, lanes: Array[Track]) -> Array[Command]:
	var cmds: Array[Command] = []
	var titles: Dictionary = title_ids(doc)
	for tr: Track in lanes:
		var boxes: Array[Clip] = marked_boxes(doc, tr, titles)
		if boxes.is_empty():
			continue
		var fits: Dictionary = plan_fits(boxes)
		for c: Clip in boxes:
			var fit: Array = fits[c.id]
			if fit_same(c.props.get(PROP_ANIM_FIT), fit):
				continue
			cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "transform", fitted_transform(c, fit)))
			var props: Dictionary = letter_props(c, c.props, fit)
			props[PROP_ANIM_FIT] = fit.duplicate()
			cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "props", props))
	return cmds


static func lane_text_boxes(doc: Project, tr: Track) -> Array[Clip]:
	var out: Array[Clip] = []
	if tr == null:
		return out
	var titles: Dictionary = title_ids(doc)
	for c: Clip in tr.clips:
		if titles.has(c.media_id):
			out.append(c)
	out.sort_custom(box_order)
	return out


static func strip_boxes(doc: Project, seq: Sequence, clip_id: String) -> Array[Clip]:
	var out: Array[Clip] = []
	if doc == null or seq == null:
		return out
	var c: Clip = seq.clip_by_id(clip_id)
	if c == null or not is_text_clip(doc, c):
		return out
	var tr: Track = seq.track_of(c.id)
	var boxes: Array[Clip] = lane_text_boxes(doc, tr)
	var keep: Dictionary = {}
	for run: Array in group_runs(items_of(boxes)):
		var hit: bool = false
		for it: Variant in run:
			if ((it as Dictionary)["clip"] as Clip).id == c.id:
				hit = true
		if hit:
			for it2: Variant in run:
				keep[((it2 as Dictionary)["clip"] as Clip).id] = true
	if not c.link_id.is_empty():
		for b: Clip in boxes:
			if b.link_id == c.link_id:
				keep[b.id] = true
	for b2: Clip in boxes:
		if keep.has(b2.id):
			out.append(b2)
	return out


static func snap_range(boxes: Array[Clip], from_t: float, to_t: float, tolerance: float) -> PackedFloat64Array:
	var lo: float = minf(from_t, to_t)
	var hi: float = maxf(from_t, to_t)
	var best_lo: float = tolerance
	var best_hi: float = tolerance
	var snap_lo: float = lo
	var snap_hi: float = hi
	for c: Clip in boxes:
		for e: float in [c.start, c.end()]:
			if absf(e - lo) < best_lo:
				best_lo = absf(e - lo)
				snap_lo = e
			if absf(e - hi) < best_hi:
				best_hi = absf(e - hi)
				snap_hi = e
	return PackedFloat64Array([snap_lo, snap_hi])


static func range_hits(doc: Project, tr: Track, lo: float, hi: float) -> Array[Clip]:
	var out: Array[Clip] = []
	for c: Clip in lane_text_boxes(doc, tr):
		if c.end() > lo + RUN_GAP and c.start < hi - RUN_GAP:
			out.append(c)
	return out


static func remove_range(doc: Project, seq: Sequence, track_id: String, from_t: float, to_t: float, snap: float = 0.0) -> bool:
	if doc == null or seq == null:
		return false
	var tr: Track = seq.track_by_id(track_id)
	if tr == null or tr.locked:
		return false
	var span: PackedFloat64Array = snap_range(lane_text_boxes(doc, tr), from_t, to_t, maxf(snap, 0.0))
	var lo: float = span[0]
	var hi: float = span[1]
	if hi - lo < RUN_GAP * 10.0 or range_hits(doc, tr, lo, hi).is_empty():
		return false
	var links: Dictionary = {}
	for c: Clip in range_hits(doc, tr, lo, hi):
		if not c.link_id.is_empty():
			links[c.link_id] = true
	var tx: Undo.Transaction = doc.undo.begin("Remove text section")
	for edge: float in [lo, hi]:
		var cut: PackedStringArray = PackedStringArray()
		for c2: Clip in lane_text_boxes(doc, tr):
			if edge > c2.start + RUN_GAP and edge < c2.end() - RUN_GAP:
				cut.append(c2.id)
		if not cut.is_empty():
			tx.apply(EditCmds.SplitClips.new(seq.id, cut, edge, false))
	var gone: PackedStringArray = PackedStringArray()
	for c3: Clip in lane_text_boxes(doc, tr):
		if c3.start >= lo - RUN_GAP and c3.end() <= hi + RUN_GAP:
			gone.append(c3.id)
	if not gone.is_empty():
		tx.apply(ClipCmds.RemoveClips.new(seq.id, gone))
	for link: Variant in links.keys():
		var right: PackedStringArray = PackedStringArray()
		var left: int = 0
		for c4: Clip in lane_text_boxes(doc, tr):
			if c4.link_id != String(link):
				continue
			if c4.start >= hi - RUN_GAP:
				right.append(c4.id)
			else:
				left += 1
		if left == 0 or right.is_empty():
			continue
		tx.apply(ClipCmds.Unlink.new(seq.id, right) if right.size() == 1 else ClipCmds.Link.new(seq.id, right, doc.mint_id("l")))
	for link2: Variant in links.keys():
		var lone: PackedStringArray = PackedStringArray()
		for c5: Clip in lane_text_boxes(doc, tr):
			if c5.link_id == String(link2):
				lone.append(c5.id)
		if lone.size() == 1:
			tx.apply(ClipCmds.Unlink.new(seq.id, lone))
	if tx.commands.is_empty():
		tx.abandon()
		return false
	return tx.commit()


static func apply_style(doc: Project, seq: Sequence, ids: PackedStringArray, style: Dictionary) -> bool:
	var cmds: Array[Command] = []
	for c: Clip in sorted_text_clips(doc, seq, ids):
		var props: Dictionary = c.props.duplicate(true)
		for k: Variant in style.keys():
			if String(k) != "text" and not RESERVED_PROPS.has(String(k)):
				props[k] = style[k]
		cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "props", props))
	if cmds.is_empty():
		return false
	return Verbs.run(doc, "Text style", cmds)


static func style_from_clip(doc: Project, c: Clip, label: String) -> Dictionary:
	var m: MediaItem = doc.media_by_id(c.media_id)
	var props: Dictionary = (m.props.duplicate(true) if m != null else {})
	for k: Variant in c.props.keys():
		props[k] = c.props[k]
	props.erase("text")
	for r: String in RESERVED_PROPS:
		props.erase(r)
	return Presets.make("text_style", label, {"props": props})


static func position_name(slot: int) -> String:
	if slot >= 0 and slot < POSITION_NAMES.size():
		return POSITION_NAMES[slot]
	return "Up " + str(slot)


static func position_offset(tr: Track, slot: float) -> float:
	if tr == null:
		return 0.0
	return slot * tr.push_up


static func travel_of(c: Clip) -> Dictionary:
	var v: Variant = c.props.get(PROP_TRAVEL) if c != null else null
	if not (v is Dictionary):
		return {"seconds": 0.0, "curve": TRAVEL_CURVES[0]}
	var d: Dictionary = v
	var curve: String = String(d.get("curve", TRAVEL_CURVES[0]))
	return {"seconds": clampf(float(d.get("seconds", 0.0)), 0.0, MAX_TRAVEL_SECONDS), "curve": curve if TRAVEL_CURVES.has(curve) else TRAVEL_CURVES[0]}


static func travel_ease(u: float, curve: String) -> float:
	var x: float = clampf(u, 0.0, 1.0)
	if curve == "linear":
		return x
	if curve == "ease_in":
		return x * x
	if curve == "ease_out":
		return 1.0 - (1.0 - x) * (1.0 - x)
	return x * x * (3.0 - 2.0 * x)


static func travel_step(t: float, at: float, seconds: float, curve: String) -> float:
	if t < at:
		return 0.0
	if seconds <= 0.0:
		return 1.0
	return travel_ease((t - at) / seconds, curve)


static func slot_at(seq: Sequence, tr: Track, c: Clip, t: float) -> float:
	if tr == null or not tr.subtitle:
		return 0.0
	var travel: Dictionary = travel_of(c)
	var secs: float = float(travel["seconds"])
	var curve: String = String(travel["curve"])
	var slot: float = 0.0
	for other: Track in seq.video_tracks:
		if other == tr or not other.subtitle:
			continue
		for oc: Clip in other.clips:
			if oc.start <= c.start or oc.start > t:
				continue
			if not oc.enabled:
				continue
			if oc.start >= c.end():
				continue
			var up: float = travel_step(t, oc.start, secs, curve)
			if tr.push_back:
				up -= travel_step(t, oc.end(), secs, curve)
			slot += up
	return slot


static func set_travel(doc: Project, seq: Sequence, ids: PackedStringArray, seconds: float, curve: String) -> bool:
	var want: Dictionary = {"seconds": clampf(seconds, 0.0, MAX_TRAVEL_SECONDS), "curve": curve if TRAVEL_CURVES.has(curve) else TRAVEL_CURVES[0]}
	var cmds: Array[Command] = []
	for c: Clip in sorted_text_clips(doc, seq, ids):
		var props: Dictionary = c.props.duplicate(true)
		if float(want["seconds"]) <= 0.0:
			if not props.has(PROP_TRAVEL):
				continue
			props.erase(PROP_TRAVEL)
		else:
			props[PROP_TRAVEL] = want.duplicate()
		cmds.append(ClipCmds.SetClipField.new(seq.id, c.id, "props", props))
	if cmds.is_empty():
		return false
	return Verbs.run(doc, "Text travel", cmds)


static func push_offset(seq: Sequence, tr: Track, c: Clip, t: float) -> float:
	return position_offset(tr, slot_at(seq, tr, c, t))

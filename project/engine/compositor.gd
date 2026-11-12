extends Node

signal rendered(t: float)

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const LayerChain := preload("res://engine/layer_chain.gd")
const Subtitles := preload("res://doc/subtitles.gd")
const FrameSource := preload("res://engine/frame_source.gd")
const EffectRegistry := preload("res://engine/effect_registry.gd")
const Backdrop := preload("res://engine/backdrop.gd")
const PlaybackClock := preload("res://engine/playback_clock.gd")
const DataText := preload("res://doc/data_text.gd")
const TextFx := preload("res://doc/text_fx/text_fx.gd")
const AnimDriver := preload("res://doc/anim_driver.gd")
const DriveSources := preload("res://engine/drive_sources.gd")
const ViewHide := preload("res://engine/view_hide.gd")
const Proxies := preload("res://engine/proxies.gd")
const TransitionRegistry := preload("res://engine/transition_registry.gd")
const TransitionUnit := preload("res://engine/transition_unit.gd")
const TransitionTiming := preload("res://doc/transition_timing.gd")
const FreeTransition := preload("res://doc/free_transition.gd")
const OUT_CUT := "|out"
const FREE_CUT := "|free|"
const EXPORT_CHECK_MS := 250
const MAX_NEST_DEPTH := 4
const MIN_TRANSITION := 0.04
const HINT_SCRUB := 0
const HINT_PLAY := 1
const HINT_STEP := 2
const HINT_EXPORT := 3

var seq: Sequence = null
var doc: Project = null
var registry: RefCounted = null
var quality: int = 0
var px_scale_bias: float = 1.0
var target: SubViewport = null
var playing: bool = false
var force_pattern: bool = false
var media_handles: Dictionary = {}
var depth: int = 0
var ancestry: PackedStringArray = PackedStringArray()
var last_time: float = 0.0
var last_exact: bool = false
var layers: Dictionary = {}
var nests: Dictionary = {}
var dips: Dictionary = {}
var cuts: Dictionary = {}
var freed_purged: int = 0
var restaged: bool = false
var restage_rereads: int = 0
static var plant_no_rescue: bool = false
static var plant_no_below: bool = false
var stages: Array[SubViewport] = []
var _pending: int = 0
var _approx: int = 0
var _reported_disabled: Dictionary = {}
var backdrop: Control = null
var backdrop_hidden: bool = false
var proxy_layers: int = 0
var proxy_renders: int = 0
var _use_proxies: bool = false
var _export_seen: bool = false
var _export_ms: int = -1000000
static var _plant_exact_proxies: bool = false
static var export_ahead: bool = true
static var async_readback: bool = true
var export_reads: int = 0
var async_reads: int = 0
const IDLE_PREF := "playback.rest_when_paused"
const REST_AFTER_MS := 300
const REST_AFTER_FRAMES := 4
const REST_PREF_MS := 500
var resting: bool = false
var rests: int = 0
var wakes: int = 0
var _rested: Array[SubViewport] = []
var _woke_ms: int = 0
var _woke_frame: int = 0
var _rest_pref: bool = true
var _rest_pref_ms: int = -1000000
var _watched_doc: Object = null
static var _plant_rest_now: bool = false
static var one_ahead: bool = false


static func has_gpu() -> bool:
	return not RenderingServer.get_video_adapter_name().is_empty()


func _init() -> void:
	name = "Compositor"
	target = SubViewport.new()
	target.name = "Target"
	target.transparent_bg = true
	target.disable_3d = true
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	target.size = Vector2i(1920, 1080)
	add_child(target)
	registry = EffectRegistry.shared()
	_watch_registry()
	var trs: RefCounted = TransitionRegistry.shared()
	if not trs.is_connected("changed", _on_transitions_changed):
		trs.connect("changed", _on_transitions_changed)
	rest_allowed()


func set_registry(r: RefCounted) -> void:
	if registry != null and registry.has_signal("changed") and registry.is_connected("changed", _on_registry_changed):
		registry.disconnect("changed", _on_registry_changed)
	registry = r
	_watch_registry()
	_warm_registry()


func _watch_registry() -> void:
	if registry != null and registry.has_signal("changed") and not registry.is_connected("changed", _on_registry_changed):
		registry.connect("changed", _on_registry_changed)


func _warm_registry() -> void:
	var warm: Node = get_tree().root.get_node_or_null("/root/ShaderWarm") if is_inside_tree() else null
	if warm != null:
		warm.call_deferred("warm_all")


func _on_registry_changed() -> void:
	_warm_registry()
	for k: Variant in layers.keys():
		var l: LayerChain = layers[k]
		if l != null and is_instance_valid(l):
			l.forget_structure()
	if seq != null and doc != null:
		render_time(last_time, last_exact)


func _on_transitions_changed() -> void:
	for k: Variant in cuts.keys():
		var u: Variant = cuts[k]
		if u is Node and is_instance_valid(u):
			(u as Node).set("shader", null)
	if seq != null and doc != null and is_inside_tree():
		render_time(last_time, last_exact)


func set_sequence(s: Sequence, d: Project) -> void:
	wake()
	_caps = {}
	if s != seq:
		_clear_layers()
	seq = s
	doc = d
	_watch_doc(d)
	AnimDriver.bind(d)
	if seq != null:
		_ensure_target_size()


func set_quality(q: int) -> void:
	wake()
	var nq: int = clampi(q, 0, 3)
	if nq == quality:
		return
	quality = nq
	_ensure_target_size()
	for id: Variant in nests.keys():
		(nests[id] as Node).call("set_quality", quality)


func set_px_scale_bias(v: float) -> void:
	wake()
	var nv: float = clampf(v, 0.001, 100.0)
	if is_equal_approx(nv, px_scale_bias):
		return
	px_scale_bias = nv
	for id: Variant in nests.keys():
		(nests[id] as Node).call("set_px_scale_bias", px_scale_bias)


func quality_scale() -> float:
	return 1.0 / pow(2.0, float(quality))


func stage_size() -> Vector2i:
	if seq == null:
		return Vector2i(2, 2)
	var s: Vector2 = Vector2(float(seq.width), float(seq.height)) * quality_scale()
	return Vector2i(maxi(int(round(s.x)), 2), maxi(int(round(s.y)), 2))


func _ensure_target_size() -> void:
	wake()
	overscan_px = _overscan_now()
	var sz: Vector2i = canvas_px()
	if target.size != sz:
		target.size = sz
	for st: SubViewport in stages:
		if st.size != sz:
			st.size = sz
	_apply_canvas_offset()


func texture() -> Texture2D:
	return target.get_texture()


func frame_state() -> Dictionary:
	return {"approx_layers": _approx, "pending": _pending, "proxy_layers": proxy_layers}


func proxies_in_use() -> bool:
	return _use_proxies


func _exporting_now() -> bool:
	var now: int = Time.get_ticks_msec()
	if now - _export_ms < EXPORT_CHECK_MS:
		return _export_seen
	_export_ms = now
	var s: Node = _session()
	_export_seen = s != null and s.has_method("exporting") and bool(s.call("exporting"))
	return _export_seen


func set_export_reads(on: bool) -> void:
	export_reads = maxi(export_reads + (1 if on else -1), 0)
	for id: Variant in nests.keys():
		var n: Node = nests[id]
		if n != null and is_instance_valid(n):
			n.call("set_export_reads", on)


func export_ahead_on() -> bool:
	return export_reads > 0 and export_ahead


func hint_for(exact: bool) -> int:
	if exact:
		return HINT_EXPORT if export_ahead_on() else HINT_STEP
	return HINT_PLAY if playing else HINT_SCRUB


func proxies_wanted(exact: bool) -> bool:
	if (exact and not _plant_exact_proxies) or force_pattern:
		return false
	if not Proxies.playing_from_proxies():
		return false
	return not _exporting_now()


func unsettled_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: Variant in layers.keys():
		var l: LayerChain = layers[id]
		if l == null or not is_instance_valid(l):
			continue
		var st: String = l.state()
		if st != "pending" and st != "approx" and st != "near" and not l.waiting:
			continue
		var label: String = ""
		if l.media != null:
			label = l.media.label
		if label.is_empty() and l.clip != null:
			label = l.clip.label
		out.append({"clip": String(id), "label": label, "state": "waiting" if l.waiting else st, "track": l.track_index})
	return out


func unsettled_text() -> String:
	var list: Array[Dictionary] = unsettled_list()
	if list.is_empty():
		return ""
	var names: PackedStringArray = PackedStringArray()
	for e: Dictionary in list:
		var nm: String = String(e["label"])
		names.append((nm if not nm.is_empty() else String(e["clip"])) + " (" + String(e["state"]) + ")")
		if names.size() >= 4:
			break
	var text: String = ", ".join(names)
	if list.size() > names.size():
		text += " and " + str(list.size() - names.size()) + " more"
	return text


func _shown_layer(clip_id: String) -> LayerChain:
	if not layers.has(clip_id):
		return null
	var l: LayerChain = layers[clip_id]
	if l == null or not is_instance_valid(l) or l.waiting:
		return null
	return l


func layer_rect(clip_id: String) -> Rect2:
	var l: LayerChain = _shown_layer(clip_id)
	if l != null:
		return l.layer_rect()
	return Rect2()


func layer_quad(clip_id: String) -> PackedVector2Array:
	var l: LayerChain = _shown_layer(clip_id)
	if l != null:
		return l.layer_quad()
	return PackedVector2Array()


func layer_pivot(clip_id: String) -> Vector2:
	var l: LayerChain = _shown_layer(clip_id)
	if l != null:
		return l.layer_pivot()
	return Vector2.ZERO


func layer_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in layers.keys():
		if _shown_layer(String(k)) != null:
			out.append(String(k))
	return out


func set_media_handles(h: Dictionary) -> void:
	media_handles = h


func set_force_pattern(on: bool) -> void:
	wake()
	if on == force_pattern:
		return
	force_pattern = on
	_clear_layers()


func _session() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Session")
	return null


func _bridge_available() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var b: Node = (loop as SceneTree).root.get_node_or_null("PurrBridge")
		if b != null:
			return bool(b.get("available"))
	return false


func _handle_for(m: MediaItem) -> int:
	if m == null:
		return -1
	if media_handles.has(m.id):
		return int(media_handles[m.id])
	var s: Node = _session()
	if s != null:
		var mh: Variant = s.get("media_handles")
		if mh is Dictionary and (mh as Dictionary).has(m.id):
			return int((mh as Dictionary)[m.id])
	return m.handle


func _clear_layers() -> void:
	wake()
	for id: Variant in layers.keys():
		_free_node(layers[id])
	layers = {}
	for id: Variant in nests.keys():
		_free_node(nests[id])
	nests = {}
	for id: Variant in dips.keys():
		_free_node(dips[id])
	dips = {}
	for id: Variant in cuts.keys():
		_free_node(cuts[id])
	cuts = {}
	for st: SubViewport in stages:
		_free_node(st)
	stages = []
	_ahead_of = {}
	_holding = {}
	if pair_regions != null and is_instance_valid(pair_regions):
		pair_regions.forget_records()


func _free_node(v: Variant) -> void:
	if v == null or not is_instance_valid(v) or not (v is Node):
		return
	var n: Node = v
	var p: Node = n.get_parent()
	if p != null:
		p.remove_child(n)
	n.queue_free()


static func transition_window(b: Clip) -> Vector2:
	return b.transition_span()


static func _adjacent(a: Clip, b: Clip) -> bool:
	return a != null and b != null and absf(a.end() - b.start) <= 0.002


static func push_offsets(kind: int, p: float, size: Vector2) -> Array[Vector2]:
	var dir: Vector2 = Vector2.ZERO
	if kind == 8 or kind == 12:
		dir = Vector2(1.0, 0.0)
	elif kind == 9 or kind == 13:
		dir = Vector2(-1.0, 0.0)
	elif kind == 10 or kind == 14:
		dir = Vector2(0.0, 1.0)
	elif kind == 11 or kind == 15:
		dir = Vector2(0.0, -1.0)
	var incoming: Vector2 = dir * size * (1.0 - p)
	var outgoing: Vector2 = Vector2.ZERO
	if kind >= 8 and kind <= 11:
		outgoing = -dir * size * p
	return [incoming, outgoing]


func _lone_out(tr: Track, t: float, main: Clip) -> Clip:
	var cands: Array[Clip] = []
	if main != null:
		cands.append(main)
	else:
		var i: int = tr.index_of_last_starting_before(t)
		if i >= 0 and i < tr.clips.size():
			cands.append(tr.clips[i])
	for c: Clip in cands:
		if c == null or not c.enabled or not c.has_transition_out():
			continue
		if TransitionRegistry.library_id(c.transition_out).is_empty():
			continue
		var m: MediaItem = doc.media_by_id(c.media_id) if doc != null else null
		if m != null and (m.kind == "adjust" or m.kind == "audio"):
			continue
		var w: Vector2 = c.transition_out_span()
		if t >= w.x and t < w.y:
			return c
	return null


func _library_kind(incoming: Clip, outgoing: Clip) -> String:
	var lib: String = TransitionRegistry.library_id(incoming.transition_in)
	if lib.is_empty() or doc == null:
		return lib
	for c: Clip in [incoming, outgoing]:
		var m: MediaItem = doc.media_by_id(c.media_id) if c != null else null
		if m != null and m.kind == "adjust":
			return ""
	return lib


func _plan(t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var any_solo: bool = false
	var picture_list: Array[Track] = seq.picture_tracks()
	for tr: Track in picture_list:
		if tr.solo:
			any_solo = true
	var stage: int = 0
	for ti: int in picture_list.size():
		var tr: Track = picture_list[ti]
		if tr.muted or (any_solo and not tr.solo):
			continue
		if tr.kind != "video" or tr.foreign or tr.has_stack():
			stage = _plan_stack(tr, ti, t, out, stage)
			continue
		var main: Clip = tr.clip_at(t)
		var incoming: Clip = null
		var outgoing: Clip = null
		var window: Vector2 = Vector2(-1.0, -1.0)
		if main != null and main.enabled:
			var w: Vector2 = transition_window(main)
			if w.x >= 0.0 and t < w.y:
				incoming = main
				outgoing = tr.prev_clip(main)
				if not _adjacent(outgoing, incoming):
					outgoing = null
				window = w
		if incoming == null:
			var i: int = tr.index_of_last_starting_before(t) + 1
			if i < tr.clips.size():
				var nxt: Clip = tr.clips[i]
				var w2: Vector2 = transition_window(nxt)
				if nxt.enabled and w2.x >= 0.0 and t >= w2.x and t < nxt.start:
					incoming = nxt
					outgoing = main if _adjacent(main, nxt) else null
					window = w2
		var seq_px: Vector2 = Vector2(float(seq.width), float(seq.height))
		var lone: Clip = _lone_out(tr, t, main) if incoming == null else null
		if incoming != null:
			var p: float = clampf(TransitionTiming.progress_at(incoming.transition_in, t - window.x, window.y - window.x, seq.fps), 0.0, 1.0)
			var kind: int = int(LayerChain.TRANSITION_KINDS.get(str(incoming.transition_in.get("kind", "")), 0))
			var lib: String = _library_kind(incoming, outgoing)
			if not lib.is_empty():
				kind = 0
			elif not TransitionRegistry.library_id(incoming.transition_in).is_empty():
				kind = 1
			var offs: Array[Vector2] = push_offsets(kind, p, seq_px)
			if outgoing != null:
				out.append({"clip": outgoing, "track": ti, "stage": stage, "role": "outgoing", "progress": 0.0, "kind": 0, "offset": offs[1], "dip": {}, "lib": lib, "cut": incoming.id, "window": window})
			var dip: Dictionary = {}
			if kind == 2 or kind == 3:
				dip = {"colour": Color.BLACK if kind == 2 else Color.WHITE, "alpha": clampf(p * 2.0, 0.0, 1.0)}
			var m_in: MediaItem = doc.media_by_id(incoming.media_id) if doc != null else null
			if m_in != null and m_in.kind == "adjust":
				stage += 1
			out.append({"clip": incoming, "track": ti, "stage": stage, "role": "incoming", "progress": p, "kind": kind, "offset": offs[0], "dip": dip, "lib": lib, "cut": incoming.id, "window": window})
		elif lone != null:
			out.append({"clip": lone, "track": ti, "stage": stage, "role": "outgoing", "progress": 0.0, "kind": 0, "offset": Vector2.ZERO, "dip": {}, "lib": TransitionRegistry.library_id(lone.transition_out), "cut": lone.id + OUT_CUT, "window": lone.transition_out_span(), "owner": lone.id, "field": Clip.TRANSITION_OUT_FIELD})
		elif main != null and main.enabled:
			var m: MediaItem = doc.media_by_id(main.media_id) if doc != null else null
			if m != null and m.kind == "audio":
				continue
			if m != null and m.kind == "adjust":
				stage += 1
			var push: Vector2 = Vector2.ZERO
			if tr.subtitle and m != null and m.kind == "title":
				push = Vector2(0.0, -Subtitles.push_offset(seq, tr, main, t))
			out.append({"clip": main, "track": ti, "stage": stage, "role": "main", "progress": 0.0, "kind": 0, "offset": push, "dip": {}})
	_plan_free(t, picture_list, any_solo, out)
	return out


static func _plain_media_kind(m: MediaItem) -> String:
	return m.kind if m != null else ""


func _free_usable(e: Dictionary) -> bool:
	if String(e.get("role", "")) != "main":
		return false
	if not String(e.get("lib", "")).is_empty():
		return false
	var c: Clip = e.get("clip", null)
	if c == null:
		return false
	var m: MediaItem = doc.media_by_id(c.media_id) if doc != null else null
	var kind: String = _plain_media_kind(m)
	return kind != "adjust" and kind != "audio"


func _plan_free(t: float, picture_list: Array[Track], any_solo: bool, out: Array[Dictionary]) -> void:
	if seq == null or not seq.any_free_transition():
		return
	for ti: int in picture_list.size():
		var tr: Track = picture_list[ti]
		if tr.free_transitions.is_empty():
			continue
		if tr.muted or (any_solo and not tr.solo):
			continue
		var ft: Dictionary = FreeTransition.active(tr.free_transitions, t)
		if ft.is_empty():
			continue
		var spec: Dictionary = FreeTransition.spec_of(ft)
		var lib: String = TransitionRegistry.library_id(spec)
		if lib.is_empty():
			continue
		var own: int = -1
		var below: int = -1
		for i: int in out.size():
			var e: Dictionary = out[i]
			var at: int = int(e.get("track", -1))
			if at < 0 or at > ti or not _free_usable(e):
				continue
			if own >= 0 and at != int((out[own] as Dictionary).get("track", -1)):
				below = own
			own = i
		if plant_no_below:
			below = -1
		if own < 0:
			continue
		var key: String = tr.id + FREE_CUT + FreeTransition.id_of(ft)
		var window: Vector2 = FreeTransition.span(ft)
		var stage: int = int((out[own] as Dictionary).get("stage", 0))
		if below >= 0 and int((out[below] as Dictionary).get("stage", 0)) != stage:
			below = -1
		if below >= 0:
			_free_mark(out[below], "incoming", key, lib, window, spec, stage)
		_free_mark(out[own], "outgoing", key, lib, window, spec, stage)
		if below >= 0 and own != below + 1:
			var moved: Dictionary = out[own]
			out.remove_at(own)
			var seat: int = below if own > below else below - 1
			out.insert(seat + 1, moved)


static func _free_mark(e: Dictionary, role: String, key: String, lib: String, window: Vector2, spec: Dictionary, stage: int) -> void:
	e["role"] = role
	e["cut"] = key
	e["lib"] = lib
	e["window"] = window
	e["spec"] = spec
	e["stage"] = stage
	e["progress"] = 0.0
	e["kind"] = 0
	e["offset"] = Vector2.ZERO
	e["dip"] = {}


const DRAW_SLOT := 64


func _order_draw(list: Array) -> void:
	for i: int in list.size():
		var n: Node = list[i]
		if n is CanvasItem:
			RenderingServer.canvas_item_set_draw_index((n as CanvasItem).get_canvas_item(), i * DRAW_SLOT)
			continue
		for ch: Node in n.get_children():
			if ch is CanvasItem:
				RenderingServer.canvas_item_set_draw_index((ch as CanvasItem).get_canvas_item(), i * DRAW_SLOT + mini(ch.get_index(), DRAW_SLOT - 1))


func _plan_stack(tr: Track, ti: int, t: float, out: Array[Dictionary], stage: int) -> int:
	for c: Clip in tr.clips_at(t):
		if not c.enabled or not tr.is_picture(c):
			continue
		var m: MediaItem = doc.media_by_id(c.media_id) if doc != null else null
		if m != null and m.kind == "audio":
			continue
		if m != null and m.kind == "adjust":
			stage += 1
		var push: Vector2 = Vector2.ZERO
		if tr.subtitle and m != null and m.kind == "title":
			push = Vector2(0.0, -Subtitles.push_offset(seq, tr, c, t))
		out.append({"clip": c, "track": ti, "stage": stage, "role": "main", "progress": 0.0, "kind": 0, "offset": push, "dip": {}})
	return stage


func _ensure_stages(count: int) -> void:
	if stages.size() != count:
		restaged = true
	while stages.size() < count:
		var st := SubViewport.new()
		st.name = "Stage" + str(stages.size())
		st.transparent_bg = true
		st.disable_3d = true
		st.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_size_stage(st)
		var parent: Node = target if stages.is_empty() else stages[stages.size() - 1]
		if stages.is_empty():
			target.add_child(st)
		else:
			parent.add_child(st)
		stages.append(st)
	while stages.size() > count:
		var last: SubViewport = stages[stages.size() - 1]
		stages.remove_at(stages.size() - 1)
		_rescue_children(last)
		_free_node(last)
	_relink_stages()


func _kept_nodes() -> Dictionary:
	var keep: Dictionary = {}
	for group: Dictionary in [layers, nests, dips, cuts]:
		for v: Variant in group.values():
			if v is Node and is_instance_valid(v):
				keep[v] = true
	return keep


func _rescue_children(n: Node) -> void:
	if n == null or not is_instance_valid(n) or plant_no_rescue:
		return
	var keep: Dictionary = _kept_nodes()
	for ch: Node in n.get_children():
		if keep.has(ch):
			n.remove_child(ch)


func purge_freed() -> int:
	var gone: int = 0
	for group: Dictionary in [layers, nests, dips, cuts]:
		for k: Variant in group.keys():
			var v: Variant = group[k]
			if v == null or not is_instance_valid(v):
				group.erase(k)
				_ahead_of.erase(k)
				gone += 1
	return gone


func _relink_stages() -> void:
	for i: int in stages.size():
		var st: SubViewport = stages[i]
		var want_parent: Node = _stage_parent(i)
		if st.get_parent() != want_parent:
			if st.get_parent() != null:
				st.get_parent().remove_child(st)
			want_parent.add_child(st)


func _stage_node(index: int, count: int) -> Node:
	if index >= count:
		return target
	return stages[count - 1 - index]


func _source_kind_for(m: MediaItem, c: Clip) -> String:
	if c.is_nest() or (m != null and m.kind == "sequence"):
		return FrameSource.KIND_NEST
	if m == null:
		return FrameSource.KIND_PATTERN if force_pattern else FrameSource.KIND_MISSING
	if m.kind == "adjust":
		return FrameSource.KIND_NEST
	if force_pattern:
		return FrameSource.KIND_PATTERN
	if m.kind == "video":
		if _bridge_available() and _handle_for(m) >= 0:
			return FrameSource.KIND_NATIVE
		return FrameSource.KIND_PATTERN
	if m.kind == "image":
		return FrameSource.KIND_IMAGE
	if m.kind == "title":
		return FrameSource.KIND_TITLE
	if m.kind == "shape":
		return FrameSource.KIND_SHAPE
	return FrameSource.KIND_SOLID


func _source_size_for(m: MediaItem, c: Clip) -> Vector2i:
	if c.is_nest() or (m != null and m.kind == "sequence"):
		var ns: Sequence = doc.sequence_by_id(c.sequence_id if c.is_nest() else m.sequence_id) if doc != null else null
		if ns != null:
			return Vector2i(ns.width, ns.height)
	if m != null and m.width > 0 and m.height > 0 and m.kind != "adjust":
		return Vector2i(m.width, m.height)
	return Vector2i(seq.width, seq.height)


var _lane_of: Dictionary = {}


func _assign_lanes(plan: Array[Dictionary]) -> void:
	_lane_of = {}
	var claimed: Dictionary = {}
	var counts: Dictionary = {}
	var s: Node = _session()
	for e: Dictionary in plan:
		var c: Clip = e["clip"]
		var m: MediaItem = doc.media_by_id(c.media_id) if doc != null else null
		if m == null or m.kind != "video":
			continue
		var h: int = int(_ahead_of.get(c.id, _handle_for(m)))
		if h < 0:
			continue
		if not claimed.has(h):
			claimed[h] = c.id
			continue
		var n: int = int(counts.get(h, 0)) + 1
		counts[h] = n
		if s == null or not s.has_method("lane_handle"):
			continue
		var lane: int = int(s.call("lane_handle", m.path, "lane" + str(n)))
		if lane >= 0:
			_lane_of[c.id] = lane


func _layer_for(c: Clip, track_index: int = -1, allow_hand: bool = true) -> LayerChain:
	var m: MediaItem = doc.media_by_id(c.media_id) if doc != null else null
	var kind: String = _source_kind_for(m, c)
	var size: Vector2i = _source_size_for(m, c)
	if allow_hand and _handing and not layers.has(c.id) and kind == FrameSource.KIND_NATIVE:
		_hand_over(c, m, track_index)
	var handle: int = int(_lane_of.get(c.id, _ahead_of.get(c.id, _handle_for(m))))
	var l: LayerChain = null
	if layers.has(c.id):
		(layers[c.id] as LayerChain).source.use_proxy = _use_proxies
		(layers[c.id] as LayerChain).source.warm_for_play = false
	if layers.has(c.id):
		l = layers[c.id]
		l.clip = c
		if l.source.kind != kind or l.media != m or (l.source.kind == FrameSource.KIND_NATIVE and l.source.handle != handle) or (kind != FrameSource.KIND_NEST and l.source.native_size != size):
			l.setup(c, m, registry, kind, size, handle)
	else:
		l = LayerChain.new()
		l.name = "Layer_" + c.id
		if _handing and kind == FrameSource.KIND_NATIVE:
			l.set_waiting(true)
		l.setup(c, m, registry, kind, size, handle)
		layers[c.id] = l
	l.source.use_proxy = _use_proxies
	l.source.warm_for_play = false
	l.seq_size = Vector2i(seq.width, seq.height)
	l.seq_fps = seq.fps
	l.quality_scale = quality_scale()
	l.px_scale_bias = px_scale_bias
	l.overscan_px = overscan_px
	if m != null and (m.kind == "title" or m.kind == "shape" or m.kind == "generator") and l.source.has_method("set_props"):
		var merged: Dictionary = m.props.duplicate(true)
		var now: Dictionary = c.props_at(last_time - c.start, seq.fps)
		for k: Variant in now.keys():
			merged[k] = now[k]
		if not merged.has("decode_clock"):
			merged["decode_clock"] = last_time - c.start
		if m.kind == "generator" and merged.has(MadePicture.PATTERN_PROP):
			merged[MadePicture.CLOCK_PROP] = l.source_time(last_time)
			merged[MadePicture.FPS_PROP] = m.fps if m.fps > 0.0 else seq.fps
		if m.kind == "title" and merged.get("text") is String and DataText.has_tokens(String(merged["text"])):
			merged["text"] = DataText.expand(String(merged["text"]), DataText.context(doc, seq, c, last_time))
		if m.kind == "title":
			TextFx.apply_to_props(c, registry, merged, m.label, last_time - c.start, seq.fps)
		l.source.call("set_props", merged)
	return l


func _nest_for(c: Clip, l: LayerChain) -> Node:
	var nested_id: String = c.sequence_id
	if nested_id.is_empty():
		var m: MediaItem = doc.media_by_id(c.media_id)
		if m != null:
			nested_id = m.sequence_id
	var ns: Sequence = doc.sequence_by_id(nested_id)
	if ns == null or depth >= MAX_NEST_DEPTH or ancestry.has(nested_id):
		return null
	var child: Node = null
	if nests.has(c.id):
		child = nests[c.id]
	else:
		var script: GDScript = get_script()
		child = script.new()
		child.name = "Nest_" + c.id
		child.set("depth", depth + 1)
		var anc: PackedStringArray = ancestry.duplicate()
		anc.append(seq.id)
		child.set("ancestry", anc)
		child.set("force_pattern", force_pattern)
		child.set("media_handles", media_handles)
		child.set("registry", registry)
		nests[c.id] = child
	if child.get_parent() != l:
		if child.get_parent() != null:
			child.get_parent().remove_child(child)
		l.add_child(child)
	child.call("set_sequence", ns, doc)
	child.call("set_quality", quality)
	child.call("set_px_scale_bias", px_scale_bias)
	child.set("export_reads", export_reads)
	return child


var _in_render: bool = false
var _reentries: int = 0


func reentries() -> int:
	return _reentries


func _window_moving() -> bool:
	var loop: MainLoop = Engine.get_main_loop()
	var s: Node = (loop as SceneTree).root.get_node_or_null("Session") if loop is SceneTree else null
	return s != null and s.has_method("window_moving") and bool(s.call("window_moving"))


func render_time(t: float, exact: bool) -> void:
	wake()
	if seq == null or doc == null:
		return
	if _in_render:
		_reentries += 1
		return
	if not exact and depth == 0 and _window_moving():
		return
	_in_render = true
	_render_time_inner(t, exact)
	_in_render = false


func _render_time_inner(t: float, exact: bool) -> void:
	if depth == 0 and not _self_render:
		_settle_until_ms = Time.get_ticks_msec() + SETTLE_RENDER_MS
	if depth == 0:
		DriveSources.reading(self)
	if depth == 0 and not _whole_busy and _render_whole(t, exact):
		return
	last_time = t
	last_exact = exact
	_use_proxies = proxies_wanted(exact)
	if depth == 0:
		PlayPace.transport_rate = _play_rate() if playing else 1.0
		PlayPace.playing = playing and not exact
	_warm = depth == 0 and warm_allowed() and not _exporting_now()
	_primed_here = false
	_ensure_target_size()
	if depth == 0:
		ViewHide.filtered_last = false
	freed_purged += purge_freed()
	var plan: Array[Dictionary] = ViewHide.filter(self, seq, _plan(t))
	_assign_lanes(plan)
	var stage_count: int = 0
	for e: Dictionary in plan:
		stage_count = maxi(stage_count, int(e["stage"]))
	_ensure_stages(stage_count)
	var hint: int = hint_for(exact)
	var wanted: Dictionary = {}
	var wanted_dips: Dictionary = {}
	var wanted_cuts: Dictionary = {}
	var order: Dictionary = {}
	_pending = 0
	_approx = 0
	_pair_begin()
	_begin_cuts(plan, exact)
	for e: Dictionary in plan:
		var c: Clip = e["clip"]
		wanted[c.id] = true
		var l: LayerChain = _layer_for(c, int(e["track"]))
		var stage_node: Node = _stage_node(int(e["stage"]), stage_count)
		var unit: Node = _cut_unit(e, stage_node, order, wanted_cuts)
		if unit != null:
			stage_node = unit.call("side", String(e["role"]) == "outgoing")
			l.overscan_px = unit.call("drawn_margin")
		if l.get_parent() != stage_node:
			if l.get_parent() != null:
				l.get_parent().remove_child(l)
			stage_node.add_child(l)
		var m: MediaItem = doc.media_by_id(c.media_id)
		l.loop_length = doc.media_duration(m) if c.loop and m != null else 0.0
		if l.source.kind == FrameSource.KIND_NEST:
			if m != null and m.kind == "adjust":
				var below: int = int(e["stage"]) - 1
				var below_node: Node = _stage_node(below, stage_count) if below >= 0 else null
				if below_node is SubViewport:
					_feed_adjust(l, below_node as SubViewport)
			else:
				var child: Node = _nest_for(c, l)
				if child != null:
					child.call("render_time", l.source_time(l.history_lead(t, hint)), exact)
					l.set_nest_texture(child.call("texture"), child.call("stage_size_native"))
		l.ensure_structure()
		l.request_source(t, quality, hint)
		l.track_index = int(e["track"])
		if l.waiting:
			_settle_waiting(l, l.track_index)
		l.update_passes(t)
		l.update_masks(t)
		_pair_update(l, t, hint)
		l.update_transition(float(e["progress"]) if int(e["kind"]) > 0 else 1.0, int(e["kind"]))
		l.update_transform(t, e["offset"], c.video_fade_mul(t) if c != null else 1.0)
		var st: String = l.state()
		if st == "pending":
			_pending += 1
		elif st == "approx" or st == "near":
			_approx += 1
		_report_disabled(l)
		var dip: Dictionary = e["dip"]
		if not order.has(stage_node):
			order[stage_node] = []
		if not dip.is_empty():
			var rect: ColorRect = _dip_for(c.id, stage_node)
			rect.color = Color(dip["colour"].r, dip["colour"].g, dip["colour"].b, float(dip["alpha"]))
			rect.size = Vector2(stage_size())
			wanted_dips[c.id] = true
			(order[stage_node] as Array).append(rect)
		(order[stage_node] as Array).append(l)
	_end_cuts(t, plan, wanted)
	var on_proxy: int = 0
	for e2: Dictionary in plan:
		var pl: LayerChain = layers.get((e2["clip"] as Clip).id, null)
		if pl != null and is_instance_valid(pl) and pl.source.proxy_on:
			on_proxy += 1
	proxy_layers = on_proxy
	if on_proxy > 0:
		proxy_renders += 1
	for id: Variant in layers.keys():
		if not wanted.has(id):
			var gone: LayerChain = layers[id]
			if gone != null and is_instance_valid(gone):
				gone.keep_regions()
			_free_node(gone)
			layers.erase(id)
			if nests.has(id):
				_free_node(nests[id])
				nests.erase(id)
	_forget_ahead()
	for id: Variant in dips.keys():
		if not wanted_dips.has(id):
			_free_node(dips[id])
			dips.erase(id)
	_drive_cuts(t, wanted_cuts)
	for stage_node: Variant in order.keys():
		var list: Array = order[stage_node]
		var sn: Node = stage_node
		for i: int in list.size():
			var n: Node = list[i]
			if n.get_parent() == sn:
				sn.move_child(n, i)
		_order_draw(list)
	_pair_sweep()
	_update_backdrop(t, exact)
	rendered.emit(t)


func stage_size_native() -> Vector2i:
	if seq == null:
		return Vector2i(2, 2)
	return Vector2i(seq.width, seq.height)


var _whole_busy: bool = false
var whole_seq_id: String = ""
var whole_time: float = -1.0


func _render_whole(t: float, exact: bool) -> bool:
	var s: Node = _session()
	if s == null or not s.has_method("whole_target"):
		whole_seq_id = ""
		return false
	var w: Dictionary = s.call("whole_target", seq.id, t)
	if w.is_empty() or not (w.get("seq") is Sequence):
		whole_seq_id = ""
		return false
	var own: Sequence = seq
	var parent: Sequence = w["seq"]
	whole_seq_id = parent.id
	whole_time = float(w.get("t", t))
	_whole_busy = true
	seq = parent
	render_time(whole_time, exact)
	seq = own
	_whole_busy = false
	last_time = t
	last_exact = exact
	return true


func set_backdrop(spec: Dictionary) -> void:
	wake()
	if depth > 0:
		return
	if spec.is_empty():
		_free_node(backdrop)
		backdrop = null
		return
	if backdrop == null or not is_instance_valid(backdrop):
		backdrop = Backdrop.new()
		target.add_child(backdrop)
	backdrop.call("apply", spec, registry)
	backdrop.visible = not backdrop_hidden
	if seq != null and doc != null:
		_update_backdrop(last_time, last_exact)


func set_backdrop_hidden(on: bool) -> void:
	wake()
	backdrop_hidden = on
	if backdrop != null and is_instance_valid(backdrop):
		backdrop.visible = not on


func has_backdrop() -> bool:
	return backdrop != null and is_instance_valid(backdrop)


func backdrop_state() -> Dictionary:
	var present: bool = has_backdrop()
	return {
		"present": present,
		"shown": present and not backdrop_hidden,
		"type": String(backdrop.get("drawn_type")) if present else "none",
		"requested": String(backdrop.call("requested_type")) if present else "none",
		"reason": String(backdrop.get("fallback_reason")) if present else "",
	}


func _update_backdrop(t: float, exact: bool) -> void:
	if not has_backdrop() or seq == null:
		return
	backdrop.call("update", t, exact, playing, stage_size(), Vector2i(seq.width, seq.height), quality_scale())
	if backdrop.visible and bool(backdrop.get("pending")):
		_pending += 1


func _cut_unit(e: Dictionary, stage_node: Node, order: Dictionary, wanted_cuts: Dictionary) -> Node:
	var lib: String = String(e.get("lib", ""))
	if lib.is_empty():
		return null
	var key: String = String(e.get("cut", ""))
	var unit: Node = cuts.get(key, null)
	if unit == null or not is_instance_valid(unit):
		unit = TransitionUnit.new()
		unit.name = "Cut_" + key
		unit.set("cut_id", key)
		cuts[key] = unit
	if unit.get_parent() != stage_node:
		if unit.get_parent() != null:
			unit.get_parent().remove_child(unit)
		stage_node.add_child(unit)
	unit.call("fit", stage_size(), overscan_px)
	if not wanted_cuts.has(key):
		wanted_cuts[key] = {"lib": lib, "window": e.get("window", Vector2(-1.0, -1.0))}
		if not order.has(stage_node):
			order[stage_node] = []
		(order[stage_node] as Array).append(unit)
	var info: Dictionary = wanted_cuts[key]
	info["incoming" if String(e["role"]) == "incoming" else "outgoing"] = e["clip"]
	info["owner"] = String(e.get("owner", key))
	info["field"] = String(e.get("field", Clip.TRANSITION_FIELD + "_in"))
	if e.get("spec") is Dictionary:
		info["spec"] = e["spec"]
	return unit


func _cut_blend(info: Dictionary) -> int:
	var a: Clip = info.get("incoming", null)
	var b: Clip = info.get("outgoing", null)
	var ba: int = int(LayerChain.BLEND_MODES.get(str(a.transform.get("blend", "normal")), 0)) if a != null else 0
	var bb: int = int(LayerChain.BLEND_MODES.get(str(b.transform.get("blend", "normal")), 0)) if b != null else 0
	if a == null:
		return bb
	if b == null or ba == bb:
		return ba
	return 0


func _drive_cuts(t: float, wanted_cuts: Dictionary) -> void:
	var reg: RefCounted = TransitionRegistry.shared()
	for key: Variant in cuts.keys():
		var unit: Node = cuts[key]
		if not wanted_cuts.has(key):
			if unit != null and is_instance_valid(unit):
				_rescue_children(unit.get("from_vp"))
				_rescue_children(unit.get("to_vp"))
			_free_node(unit)
			cuts.erase(key)
			continue
		var info: Dictionary = wanted_cuts[key]
		var free_spec: bool = info.get("spec") is Dictionary
		var owner: Clip = null if free_spec else seq.clip_by_id(String(info.get("owner", key)))
		var tr_d: Dictionary = info["spec"] if free_spec else (owner.transition_field(String(info.get("field", ""))) if owner != null else {})
		var w: Vector2 = info["window"]
		var dur: float = maxf(w.y - w.x, 0.0001)
		var p: float = TransitionTiming.progress_at(tr_d, t - w.x, dur, seq.fps)
		var lib: String = String(info["lib"])
		var res: Dictionary = reg.call("resolve", lib)
		unit.call("use", res)
		unit.call("set_pyramid", bool(res.get("pyramid", false)))
		var values: Dictionary = {}
		if (owner != null or free_spec) and not bool(res.get("fell_back", false)):
			values = reg.call("values_at", lib, tr_d, t - w.x, dur, seq.fps)
		unit.call("set_blend", _cut_blend(info))
		unit.call("apply", p, quality_scale() * px_scale_bias, TransitionRegistry.seed_for(String(key)), dur, t, values)


func cut_units() -> Dictionary:
	return cuts.duplicate()


func _dip_for(clip_id: String, stage_node: Node) -> ColorRect:
	var rect: ColorRect = null
	if dips.has(clip_id):
		rect = dips[clip_id]
	else:
		rect = ColorRect.new()
		rect.name = "Dip_" + clip_id
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dips[clip_id] = rect
	if rect.get_parent() != stage_node:
		if rect.get_parent() != null:
			rect.get_parent().remove_child(rect)
		stage_node.add_child(rect)
	rect.position = Vector2.ZERO
	return rect


func _report_disabled(l: LayerChain) -> void:
	if l.disabled_effects.is_empty():
		return
	var events: Node = get_node_or_null("/root/Events")
	for uid: String in l.disabled_effects:
		var key: String = l.clip_id + "/" + uid
		if _reported_disabled.has(key):
			continue
		_reported_disabled[key] = true
		if events != null:
			events.warn("An effect on clip " + l.clip_id + " is disabled because its shader did not compile", uid)


func read_frame() -> Image:
	if not has_gpu():
		return null
	if ViewHide.filtered_last:
		return await _read_unhidden()
	await RenderingServer.frame_post_draw
	if restaged and not plant_no_rescue:
		restaged = false
		restage_rereads += 1
		render_time(last_time, last_exact)
		await RenderingServer.frame_post_draw
	var tex: ViewportTexture = target.get_texture()
	if tex == null:
		return null
	return _frame_only(tex.get_image())


class Readback extends RefCounted:
	var done: bool = false
	var failed: bool = false
	var image: Image = null
	var data: PackedByteArray = PackedByteArray()
	var size: Vector2i = Vector2i.ZERO
	var crop: Rect2i = Rect2i()
	var async: bool = false

	func take(bytes: PackedByteArray) -> void:
		data = bytes
		failed = bytes.size() < size.x * size.y * 4
		done = true

	func result() -> Image:
		if image != null or not async or failed or not done:
			return image
		var img: Image = Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, data)
		data = PackedByteArray()
		if crop.size.x > 0 and crop.size.y > 0 and img.get_width() >= crop.end.x and img.get_height() >= crop.end.y:
			img = img.get_region(crop)
		image = img
		return image


func read_frame_begin() -> Readback:
	if not has_gpu():
		return null
	var rb: Readback = Readback.new()
	if ViewHide.filtered_last or not async_readback:
		rb.image = await read_frame()
		rb.done = true
		return rb if rb.image != null else null
	await RenderingServer.frame_post_draw
	if restaged and not plant_no_rescue:
		restaged = false
		restage_rereads += 1
		render_time(last_time, last_exact)
		await RenderingServer.frame_post_draw
	var tex: ViewportTexture = target.get_texture()
	if tex == null:
		return null
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	var rd_tex: RID = RenderingServer.texture_get_rd_texture(tex.get_rid()) if rd != null else RID()
	var fmt: RDTextureFormat = rd.texture_get_format(rd_tex) if rd_tex.is_valid() else null
	if fmt == null or fmt.format != RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM or fmt.array_layers != 1:
		rb.image = _frame_only(tex.get_image())
		rb.done = true
		return rb if rb.image != null else null
	rb.async = true
	rb.size = Vector2i(int(fmt.width), int(fmt.height))
	if overscan_px != Vector2i.ZERO:
		rb.crop = Rect2i(overscan_px, stage_size())
	if rd.texture_get_data_async(rd_tex, 0, rb.take) != OK:
		rb.async = false
		rb.image = _frame_only(tex.get_image())
		rb.done = true
		return rb if rb.image != null else null
	async_reads += 1
	return rb


func _read_unhidden() -> Image:
	ViewHide.suspended += 1
	render_time(last_time, true)
	await RenderingServer.frame_post_draw
	var tex: ViewportTexture = target.get_texture()
	var img: Image = _frame_only(tex.get_image()) if tex != null else null
	ViewHide.suspended -= 1
	render_time(last_time, last_exact)
	return img


func settle_frames() -> int:
	return _pending


func crop_to_frame(img: Image) -> Image:
	return _frame_only(img)


const OVERSCAN_COST := 2.0
const OVERSCAN_STEP := 16
const RING_SHADER := "res://engine/overscan_ring.gdshader"
const CROP_SHADER := "res://engine/copy.gdshader"

var overscan_seq: Vector2 = Vector2.ZERO
var overscan_px: Vector2i = Vector2i.ZERO
var _crops: Dictionary = {}


func set_overscan(margin_seq: Vector2) -> bool:
	wake()
	overscan_seq = Vector2(maxf(margin_seq.x, 0.0), maxf(margin_seq.y, 0.0)) if depth == 0 else Vector2.ZERO
	var before: Vector2i = overscan_px
	_ensure_target_size()
	return overscan_px != before


func _overscan_now() -> Vector2i:
	if depth > 0 or seq == null or overscan_seq == Vector2.ZERO:
		return Vector2i.ZERO
	var st: Vector2i = stage_size()
	var k: Vector2 = Vector2(float(st.x) / maxf(float(seq.width), 1.0), float(st.y) / maxf(float(seq.height), 1.0))
	return overscan_pixels(st, overscan_seq * k, OVERSCAN_COST, OVERSCAN_STEP)


static func overscan_fit(w: float, h: float, mx: float, my: float, cost: float) -> float:
	if (w + 2.0 * mx) * (h + 2.0 * my) <= cost * w * h + 0.001:
		return 1.0
	var a: float = 4.0 * mx * my
	var b: float = 2.0 * (w * my + h * mx)
	var c: float = w * h * (1.0 - cost)
	if a < 0.000001:
		return clampf(-c / maxf(b, 0.000001), 0.0, 1.0)
	return clampf((-b + sqrt(b * b - 4.0 * a * c)) / (2.0 * a), 0.0, 1.0)


static func overscan_pixels(stage: Vector2i, margin: Vector2, cost: float, step: int) -> Vector2i:
	var w: float = float(stage.x)
	var h: float = float(stage.y)
	var mx: float = maxf(margin.x, 0.0)
	var my: float = maxf(margin.y, 0.0)
	if mx < 0.5 and my < 0.5:
		return Vector2i.ZERO
	var s: float = overscan_fit(w, h, mx, my, cost)
	mx *= s
	my *= s
	var st: float = float(maxi(step, 1))
	var up: Vector2i = Vector2i(int(ceil(mx / st) * st) if mx >= 0.5 else 0, int(ceil(my / st) * st) if my >= 0.5 else 0)
	if (w + 2.0 * float(up.x)) * (h + 2.0 * float(up.y)) <= cost * w * h + 0.001:
		return up
	return Vector2i(int(floor(mx / st) * st), int(floor(my / st) * st))


func canvas_px() -> Vector2i:
	return stage_size() + overscan_px * 2


func canvas_rect_seq() -> Rect2:
	if seq == null:
		return Rect2()
	var st: Vector2i = stage_size()
	var k: Vector2 = Vector2(float(seq.width) / float(maxi(st.x, 1)), float(seq.height) / float(maxi(st.y, 1)))
	if overscan_px == Vector2i.ZERO:
		return Rect2(Vector2.ZERO, Vector2(float(seq.width), float(seq.height)))
	return Rect2(-Vector2(overscan_px) * k, Vector2(canvas_px()) * k)


func _canvas_xf() -> Transform2D:
	return Transform2D(0.0, Vector2(overscan_px))


func _size_stage(st: SubViewport) -> void:
	st.size = canvas_px()
	if st.is_inside_tree():
		st.canvas_transform = _canvas_xf()


func _feed_adjust(l: LayerChain, below: SubViewport) -> void:
	var full: Texture2D = _stage_texture(below)
	AdjustSize.under(l, full, seq)
	var tex: Texture2D = AdjustSize.region_of(l, full, seq)
	var was: Texture2D = l.source.texture()
	l.set_nest_texture(tex, AdjustSize.size_of(l.media, seq))
	if was != tex:
		l.forget_structure()


func _apply_canvas_offset() -> void:
	var xf: Transform2D = _canvas_xf()
	if target.is_inside_tree() and target.canvas_transform != xf:
		target.canvas_transform = xf
	for st: SubViewport in stages:
		if st.is_inside_tree() and st.canvas_transform != xf:
			st.canvas_transform = xf
	for key: Variant in _crops.keys():
		var entry: Dictionary = _crops[key]
		var stage_vp: Variant = entry.get("stage", null)
		if overscan_px == Vector2i.ZERO or not is_instance_valid(stage_vp) or not stages.has(stage_vp):
			_drop_crop(key)
			continue
		_fit_crop(entry)


func _frame_only(img: Image) -> Image:
	if img == null or overscan_px == Vector2i.ZERO:
		return img
	var st: Vector2i = stage_size()
	if img.get_width() < st.x + overscan_px.x or img.get_height() < st.y + overscan_px.y:
		return img
	return img.get_region(Rect2i(overscan_px, st))


func _stage_parent(i: int) -> Node:
	var base: Node = target if i == 0 else stages[i - 1]
	var stage_vp: SubViewport = stages[i]
	if stage_vp.is_inside_tree() and stage_vp.canvas_transform != _canvas_xf():
		stage_vp.canvas_transform = _canvas_xf()
	if overscan_px == Vector2i.ZERO:
		if _crops.has(stage_vp):
			_drop_crop(stage_vp)
		return base
	var entry: Dictionary = _crop_for(stage_vp)
	var crop: SubViewport = entry["crop"]
	var ring: Control = entry["ring"]
	if crop.get_parent() != base:
		if crop.get_parent() != null:
			crop.get_parent().remove_child(crop)
		base.add_child(crop)
	if ring.get_parent() != base:
		if ring.get_parent() != null:
			ring.get_parent().remove_child(ring)
		base.add_child(ring)
	_fit_crop(entry)
	return crop


func _crop_for(stage_vp: SubViewport) -> Dictionary:
	if _crops.has(stage_vp):
		return _crops[stage_vp]
	var crop: SubViewport = SubViewport.new()
	crop.name = "Crop_" + String(stage_vp.name)
	crop.transparent_bg = true
	crop.disable_3d = true
	crop.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var pic: TextureRect = TextureRect.new()
	pic.name = "Frame"
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.material = LayerChain.material_for(CROP_SHADER)
	pic.texture = stage_vp.get_texture()
	crop.add_child(pic)
	var ring: Control = _Ring.new()
	ring.name = "Ring_" + String(stage_vp.name)
	ring.material = LayerChain.material_for(RING_SHADER)
	ring.set("tex", stage_vp.get_texture())
	var entry: Dictionary = {"stage": stage_vp, "crop": crop, "pic": pic, "ring": ring}
	_crops[stage_vp] = entry
	return entry


func _fit_crop(entry: Dictionary) -> void:
	var crop: SubViewport = entry["crop"]
	var pic: TextureRect = entry["pic"]
	var ring: Control = entry["ring"]
	var st: Vector2i = stage_size()
	if crop.size != st:
		crop.size = st
	pic.position = -Vector2(overscan_px)
	pic.size = Vector2(canvas_px())
	ring.set("frame_px", Vector2(st))
	ring.set("margin_px", Vector2(overscan_px))
	ring.queue_redraw()


func _drop_crop(key: Variant) -> void:
	if not _crops.has(key):
		return
	var entry: Dictionary = _crops[key]
	_crops.erase(key)
	var crop: SubViewport = entry["crop"]
	var base: Node = crop.get_parent()
	var stage_vp: Variant = entry.get("stage", null)
	if is_instance_valid(stage_vp) and (stage_vp as Node).get_parent() == crop:
		crop.remove_child(stage_vp)
		if base != null:
			base.add_child(stage_vp)
	_free_node(entry["ring"])
	_free_node(crop)


func _stage_texture(stage_vp: SubViewport) -> Texture2D:
	if stage_vp == null:
		return null
	if overscan_px != Vector2i.ZERO and _crops.has(stage_vp):
		return ((_crops[stage_vp] as Dictionary)["crop"] as SubViewport).get_texture()
	return stage_vp.get_texture()


class _Ring:
	extends Control

	var tex: Texture2D = null
	var frame_px: Vector2 = Vector2.ZERO
	var margin_px: Vector2 = Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = -1
		position = Vector2.ZERO

	func _draw() -> void:
		if tex == null or margin_px == Vector2.ZERO:
			return
		var m: Vector2 = margin_px
		var f: Vector2 = frame_px
		var full: Vector2 = f + m * 2.0
		if m.y > 0.0:
			draw_texture_rect_region(tex, Rect2(-m, Vector2(full.x, m.y)), Rect2(Vector2.ZERO, Vector2(full.x, m.y)))
			draw_texture_rect_region(tex, Rect2(Vector2(-m.x, f.y), Vector2(full.x, m.y)), Rect2(Vector2(0.0, m.y + f.y), Vector2(full.x, m.y)))
		if m.x > 0.0:
			draw_texture_rect_region(tex, Rect2(Vector2(-m.x, 0.0), Vector2(m.x, f.y)), Rect2(Vector2(0.0, m.y), Vector2(m.x, f.y)))
			draw_texture_rect_region(tex, Rect2(Vector2(f.x, 0.0), Vector2(m.x, f.y)), Rect2(Vector2(m.x + f.x, m.y), Vector2(m.x, f.y)))


const PairRegions := preload("res://engine/pair_regions.gd")
const MadePicture := preload("res://engine/made_picture.gd")
const AdjustSize := preload("res://engine/adjust_size.gd")
const PlayPace := preload("res://engine/play_pace.gd")

var pair_regions: PairRegions = null


func _pair_begin() -> void:
	if pair_regions != null and is_instance_valid(pair_regions):
		pair_regions.use_proxy = _use_proxies
		pair_regions.warm_for_play = _warm
		pair_regions.playing = playing
		pair_regions.export_ahead = export_ahead_on()
		pair_regions.seq = seq
		pair_regions.begin_frame()


func _pairs() -> PairRegions:
	if pair_regions == null or not is_instance_valid(pair_regions):
		pair_regions = PairRegions.new()
		add_child(pair_regions)
		pair_regions.use_proxy = _use_proxies
		pair_regions.warm_for_play = _warm
		pair_regions.playing = playing
		pair_regions.export_ahead = export_ahead_on()
		pair_regions.seq = seq
		pair_regions.begin_frame()
	return pair_regions


func _pair_update(l: LayerChain, t: float, hint: int) -> void:
	if PairRegions.pair_entries(l.clip).is_empty():
		return
	var counts: Vector2i = _pairs().update_layer(l, t, quality, hint)
	_pending += counts.x
	_approx += counts.y


func _pair_ahead(c: Clip, prev: Clip, m: MediaItem, track_index: int, at: float, like: LayerChain, warm: bool = true) -> void:
	if PairRegions.pair_entries(c).is_empty():
		return
	var kind: String = _source_kind_for(m, c)
	_pairs().prepare(c, prev, m, kind, _source_size_for(m, c), registry, at, quality, track_index, like, warm)


func _pairs_ready(l: LayerChain) -> bool:
	if pair_regions == null or not is_instance_valid(pair_regions) or PairRegions.pair_entries(l.clip).is_empty():
		return true
	return pair_regions.ready_for(l.clip, last_time)


func _pair_sweep() -> void:
	if pair_regions != null and is_instance_valid(pair_regions):
		pair_regions.sweep(seq)


const LOOK_AHEAD := 2.0
const LookAhead := preload("res://engine/look_ahead.gd")

var _ahead_seconds: float = LOOK_AHEAD
var _ahead_checked_ms: int = 0


func _look_ahead_seconds() -> float:
	var now: int = Time.get_ticks_msec()
	if now - _ahead_checked_ms < 1000:
		return _ahead_seconds
	_ahead_checked_ms = now
	var loop: MainLoop = Engine.get_main_loop()
	var prefs: Node = (loop as SceneTree).root.get_node_or_null("Prefs") if loop is SceneTree else null
	_ahead_seconds = LookAhead.current_seconds(prefs) if prefs != null else LOOK_AHEAD
	return _ahead_seconds
const AHEAD_LANES := 3
const AHEAD_CLIPS := 3
const AHEAD_SCAN := 16
const WARM_AHEAD := 1
const HOLD_LIMIT_MS := 500
const HOLD_LIMIT_PAUSED_MS := 4000
const SETTLE_RENDER_MS := 6000
const SOURCE_GAP_FRAMES := 0.5
const LANE_IDLE_MS := 15000
const LANE_CHECK_MS := 1000
const LANE_KEEP_CLIPS := 6

var smooth_cuts: bool = true
var _ahead_of: Dictionary = {}
var _holding: Dictionary = {}
var _lane_use: Dictionary = {}
var _lane_check_ms: int = 0
var _plan_ids: Dictionary = {}
var _handing: bool = false
var _ready_handles: Dictionary = {}
var handovers: int = 0
var prebuilt: int = 0
var held_cuts: int = 0
var lanes_parked: int = 0
var self_renders: int = 0
var _settle_until_ms: int = 0
var _self_render: bool = false


func cut_stats() -> Dictionary:
	var waiting: int = 0
	for k: Variant in layers.keys():
		var l: LayerChain = layers[k]
		if l != null and is_instance_valid(l) and l.waiting:
			waiting += 1
	var pr: bool = pair_regions != null and is_instance_valid(pair_regions)
	return {"handovers": handovers, "prebuilt": prebuilt, "held": held_cuts, "waiting": waiting, "holding": _holding.size(), "ahead": _ahead_of.duplicate(), "misses": ahead_misses.duplicate(), "entries": cut_log.size(), "lanes_parked": lanes_parked, "region_handovers": pair_regions.handovers if pr else 0, "region_made": pair_regions.prepared if pr else 0, "region_held": pair_regions.held_cuts if pr else 0, "region_decoders": pair_regions.live_count() if pr else 0, "region_opened": pair_regions.opened_total if pr else 0}


const CUT_LOG_KEEP := 512

var cut_log: Array[Dictionary] = []
var ahead_misses: Dictionary = {}
var _ahead_log: Dictionary = {}
var _miss_of: Dictionary = {}


func _begin_cuts(plan: Array[Dictionary], exact: bool) -> void:
	_handing = smooth_cuts and not exact and depth == 0
	_holding = {}
	var was: Dictionary = _plan_ids
	_plan_ids = {}
	for e: Dictionary in plan:
		var c: Clip = e["clip"]
		_plan_ids[c.id] = true
		if _handing and playing and not was.is_empty() and not was.has(c.id):
			_note_entry(c, int(e["track"]))


func _note_entry(c: Clip, track_index: int) -> void:
	var l: LayerChain = layers.get(c.id, null)
	if l != null and not is_instance_valid(l):
		l = null
	var rec: Dictionary = _ahead_log.get(c.id, {})
	var primed_t: float = float(rec.get("primed_t", -1.0))
	var entry: Dictionary = {"clip": c.id, "t": last_time, "track": track_index, "built": l != null, "primed": l != null and l.source.ready_now(), "handle": l.source.handle if l != null else -1, "lead": last_time - float(rec["t"]) if rec.has("t") else -1.0, "primed_lead": last_time - primed_t if primed_t >= 0.0 else -1.0, "regions": l != null and _pairs_ready(l), "regions_asked_ms": pair_regions.asked_age_ms(c) if pair_regions != null and is_instance_valid(pair_regions) else -1, "miss": String(_miss_of.get(c.id, ""))}
	cut_log.append(entry)
	while cut_log.size() > CUT_LOG_KEEP:
		cut_log.pop_front()


func _note_miss(c: Clip, why: String) -> void:
	_miss_of[c.id] = why
	ahead_misses[why] = int(ahead_misses.get(why, 0)) + 1


static func continues(a: Clip, b: Clip, fps: float) -> bool:
	if a == null or b == null or a == b or a.media_id.is_empty() or a.media_id != b.media_id:
		return false
	if not _adjacent(a, b):
		return false
	var step: float = 1.0 / (fps if fps > 0.0 else 30.0)
	return absf(a.source_time(a.end()) - b.source_time(b.start)) <= step * SOURCE_GAP_FRAMES


func _hand_over(c: Clip, m: MediaItem, track_index: int) -> void:
	if m == null:
		return
	for k: Variant in layers.keys():
		if _plan_ids.has(k):
			continue
		var l: LayerChain = layers[k]
		if l == null or not is_instance_valid(l) or l.waiting or l.media != m or l.source.kind != FrameSource.KIND_NATIVE:
			continue
		if track_index >= 0 and l.track_index != track_index:
			continue
		var lc: Clip = seq.clip_by_id(l.clip_id)
		if lc == null:
			lc = l.clip
		if not continues(lc, c, m.fps) and not continues(c, lc, m.fps) and not _same_frame(l, c, m):
			continue
		layers.erase(k)
		l.hand_to(c)
		layers[c.id] = l
		_ahead_of[c.id] = l.source.handle
		handovers += 1
		return


func _process(_delta: float) -> void:
	if depth == 0 and not _primed_here and may_prime():
		prime_for_play()
	if depth == 0 and may_rest():
		rest()
	if depth > 0 or playing or _self_render or seq == null or doc == null:
		return
	if Time.get_ticks_msec() > _settle_until_ms or not unsettled():
		return
	_self_render = true
	self_renders += 1
	render_time(last_time, last_exact)
	_self_render = false


func unsettled() -> bool:
	if _pending > 0 or _approx > 0 or not _holding.is_empty():
		return true
	var ahead_only: bool = export_ahead_on()
	for k: Variant in layers.keys():
		var l: LayerChain = layers[k]
		if l == null or not is_instance_valid(l):
			continue
		if ahead_only and l.waiting and not _plan_ids.has(k):
			continue
		if l.waiting or l.source.proxy_waiting:
			return true
	return false


func _can_hold(waiter: LayerChain, track_index: int) -> bool:
	for k: Variant in layers.keys():
		var l: LayerChain = layers[k]
		if l == null or not is_instance_valid(l) or l == waiter or l.waiting or _plan_ids.has(k):
			continue
		if l.track_index == track_index:
			return true
	return false


func _same_frame(l: LayerChain, c: Clip, m: MediaItem) -> bool:
	if not l.source.primed or l.clip == null or l.clip.id == c.id:
		return false
	var fps: float = m.fps if m.fps > 0.0 else 30.0
	var src: float = c.loop_source(PlaybackClock.source_time_for(c, PlayPace.shown_time(c, last_time, seq.fps, playing), fps, seq.fps), m.duration)
	if m.duration > 0.0:
		src = clampf(src, 0.0, m.duration)
	return absf(maxf(src, 0.0) - l.source.last_time) <= 0.5 / fps


func _settle_waiting(l: LayerChain, track_index: int) -> void:
	if l.source.kind != FrameSource.KIND_NATIVE or not smooth_cuts or depth > 0:
		l.set_waiting(false)
		return
	var now: int = Time.get_ticks_msec()
	var ready: bool = (l.source.ready_now() and _pairs_ready(l)) or not _can_hold(l, track_index)
	if l.due_ms < 0:
		l.due_ms = now
		if not ready:
			held_cuts += 1
	if ready or now - l.due_ms > (HOLD_LIMIT_MS if playing else HOLD_LIMIT_PAUSED_MS):
		l.set_waiting(false)
		return
	_holding[track_index] = true


func _end_cuts(t: float, plan: Array[Dictionary], wanted: Dictionary) -> void:
	var now: int = Time.get_ticks_msec()
	var busy: Dictionary = {}
	for k: Variant in layers.keys():
		var l: LayerChain = layers[k]
		if l == null or not is_instance_valid(l):
			continue
		if not wanted.has(k) and not l.waiting and _holding.has(l.track_index):
			wanted[k] = true
			_pending += 1
			l.source.hold_picture()
		if wanted.has(k) and l.source.kind == FrameSource.KIND_NATIVE and l.source.handle >= 0:
			busy[l.source.handle] = true
			if _lane_use.has(l.source.handle):
				(_lane_use[l.source.handle] as Dictionary)["ms"] = now
				(_lane_use[l.source.handle] as Dictionary)["parked"] = false
	if _handing and playing:
		_look_ahead(t, plan, wanted, busy, _play_rate())
	elif last_exact and depth == 0 and export_ahead_on():
		_look_ahead(t, plan, wanted, busy, 1.0)
	_prune_lanes(now, busy)


func _prune_lanes(now: int, busy: Dictionary) -> void:
	if playing or _lane_use.is_empty() or now - _lane_check_ms < LANE_CHECK_MS:
		return
	_lane_check_ms = now
	var s: Node = _session()
	var cut_counts: Dictionary = {}
	for h: Variant in _lane_use.keys():
		var use: Dictionary = _lane_use[h]
		if busy.has(h) or now - int(use["ms"]) < LANE_IDLE_MS:
			continue
		var path: String = String(use["path"])
		var open_lanes: Variant = s.get("lane_handles") if s != null else null
		if not (open_lanes is Dictionary) or int((open_lanes as Dictionary).get(path + "|" + String(use["lane"]), -1)) != int(h):
			_lane_use.erase(h)
			_ready_handles.erase(h)
			continue
		if not cut_counts.has(path):
			cut_counts[path] = _clips_of(path)
		if int(cut_counts[path]) >= LANE_KEEP_CLIPS:
			if not bool(use.get("parked", false)):
				use["parked"] = true
				lanes_parked += 1
				var b: Node = _root_node_named("PurrBridge")
				if b != null and bool(b.get("available")):
					b.call("park_media", int(h))
			continue
		_lane_use.erase(h)
		_ready_handles.erase(h)
		if s != null and s.has_method("forget_lane"):
			s.call("forget_lane", String(use["path"]), String(use["lane"]))


func _clips_of(path: String) -> int:
	if seq == null or doc == null or path.is_empty():
		return 0
	var n: int = 0
	for tr: Track in seq.picture_tracks():
		for c: Clip in tr.clips:
			var m: MediaItem = doc.media_by_id(c.media_id)
			if m != null and m.path == path:
				n += 1
	return n


func _play_rate() -> float:
	var s: Node = _session()
	if s == null:
		return 1.0
	return float(s.get("rate"))


func _look_ahead(t: float, plan: Array[Dictionary], wanted: Dictionary, busy: Dictionary, rate: float) -> void:
	var dir: float = -1.0 if rate < 0.0 else 1.0
	var reach: float = _look_ahead_seconds() * maxf(absf(rate), 1.0)
	var shown_on: Dictionary = {}
	for e: Dictionary in plan:
		shown_on[int(e["track"])] = e["clip"]
	var picture_list: Array[Track] = seq.picture_tracks()
	var any_solo: bool = false
	for tr: Track in picture_list:
		if tr.solo:
			any_solo = true
	for ti: int in picture_list.size():
		var tr: Track = picture_list[ti]
		if tr.muted or (any_solo and not tr.solo):
			continue
		var cur: Clip = shown_on.get(ti, null)
		var cur_layer: LayerChain = layers.get(cur.id, null) if cur != null else null
		var parent: Node = cur_layer.get_parent() if cur_layer != null and cur_layer.get_parent() != null else target
		var before: Clip = cur
		var before_layer: LayerChain = cur_layer
		var warmed: int = 0
		for nxt: Clip in upcoming_list(tr, t, dir, reach):
			if wanted.has(nxt.id):
				before = nxt
				before_layer = layers.get(nxt.id, null)
				continue
			var m: MediaItem = doc.media_by_id(nxt.media_id)
			if m == null or m.kind != "video" or not tr.is_picture(nxt) or _source_kind_for(m, nxt) != FrameSource.KIND_NATIVE:
				before = nxt
				before_layer = null
				continue
			var first: float = _first_shown(nxt, dir)
			var prev: Clip = before if dir >= 0.0 else null
			if before_layer != null and before != null and (continues(before, nxt, m.fps) or continues(nxt, before, m.fps)):
				_pair_ahead(nxt, prev, m, ti, first, before_layer)
				before = nxt
				continue
			if warmed >= ahead_cap(m.path):
				break
			var h: int = _pick_ahead(nxt, m, busy)
			var warm: bool = warmed < WARM_AHEAD
			if h < 0:
				_note_miss(nxt, _pick_why)
				_pair_ahead(nxt, prev, m, ti, first, layers.get(nxt.id, null), warm)
				break
			busy[h] = true
			warmed += 1
			_prepare(nxt, ti, parent, first, warm)
			var l: LayerChain = layers.get(nxt.id, null)
			_pair_ahead(nxt, prev, m, ti, first, l, warm)
			wanted[nxt.id] = true
			before = nxt
			before_layer = l


var _caps: Dictionary = {}


func ahead_cap(path: String) -> int:
	if one_ahead:
		return 1
	if _caps.has(path):
		return int(_caps[path])
	var cap: int = AHEAD_CLIPS
	var b: Node = _root_node_named("PurrBridge")
	if b != null and b.has_method("has_drives") and bool(b.call("has_drives")) and not path.is_empty():
		var v: Dictionary = b.call("volume_for_path", path)
		cap = 1 if bool(v.get("seek_penalty", true)) else clampi(int(v.get("limit", 1)) - 1, 1, AHEAD_CLIPS)
	_caps[path] = cap
	return cap


func upcoming_list(tr: Track, t: float, dir: float, reach: float) -> Array[Clip]:
	var out: Array[Clip] = []
	var cap: int = 1 if one_ahead else AHEAD_CLIPS
	if dir >= 0.0:
		var i: int = tr.index_of_last_starting_before(t) + 1
		var tries: int = 0
		while i < tr.clips.size() and tries < AHEAD_SCAN and out.size() < cap:
			var c: Clip = tr.clips[i]
			var appear: float = _first_shown(c, 1.0)
			if appear - t > reach:
				break
			if c.enabled and appear > t:
				out.append(c)
			i += 1
			tries += 1
		return out
	var j: int = tr.index_of_last_starting_before(t)
	var tries_back: int = 0
	while j >= 0 and tries_back < AHEAD_SCAN and out.size() < cap:
		var b: Clip = tr.clips[j]
		if b.end() <= t:
			if t - b.end() > reach:
				break
			if b.enabled:
				out.append(b)
		j -= 1
		tries_back += 1
	return out


func _first_shown(c: Clip, dir: float) -> float:
	if dir < 0.0:
		return c.end() - 0.5 / maxf(seq.fps, 1.0)
	var w: Vector2 = transition_window(c)
	if w.x >= 0.0 and w.x < c.start:
		return w.x
	return c.start


var _pick_why: String = ""


func _pick_ahead(c: Clip, m: MediaItem, busy: Dictionary) -> int:
	_pick_why = ""
	var have: int = int(_ahead_of.get(c.id, -1))
	if have >= 0 and not busy.has(have):
		return have
	_ahead_of.erase(c.id)
	var base: int = _handle_for(m)
	if base >= 0 and not busy.has(base):
		_ahead_of[c.id] = base
		return base
	var s: Node = _session()
	if s == null or not s.has_method("lane_handle") or m.path.is_empty():
		_pick_why = "no lanes"
		return -1
	for n: int in range(1, AHEAD_LANES + 1):
		var lane: String = "ahead" + str(n)
		var h: int = int(s.call("lane_handle", m.path, lane))
		if h < 0:
			_pick_why = "lane did not open"
			return -1
		_lane_use[h] = {"path": m.path, "lane": lane, "ms": Time.get_ticks_msec()}
		if busy.has(h):
			continue
		if not _handle_ready(h) and not _proxy_covers(c, m):
			_pick_why = "lane opening"
			return -1
		_ahead_of[c.id] = h
		return h
	_pick_why = "lanes busy"
	return -1


func _proxy_covers(c: Clip, m: MediaItem) -> bool:
	if not _use_proxies or m == null or m.path.is_empty() or m.fps <= 0.0:
		return false
	return not Proxies.playback_segment(m.path, m.fps, maxf(c.source_time(_first_shown(c, 1.0)), 0.0), m.width).is_empty()


func _handle_ready(h: int) -> bool:
	if _ready_handles.has(h):
		return true
	var loop: MainLoop = Engine.get_main_loop()
	var b: Node = (loop as SceneTree).root.get_node_or_null("PurrBridge") if loop is SceneTree else null
	if b == null or not bool(b.get("available")):
		return false
	var info: Dictionary = b.call("media_info", h)
	if bool(info.get("ok", false)) and bool(info.get("has_video", false)):
		_ready_handles[h] = true
		return true
	return false


func _prepare(c: Clip, track_index: int, parent: Node, at: float, warm: bool = true) -> void:
	var fresh: bool = not layers.has(c.id)
	var l: LayerChain = _layer_for(c, track_index, false)
	if not l.waiting:
		l.set_waiting(true)
	if l.get_parent() == null:
		parent.add_child(l)
	l.track_index = track_index
	if fresh:
		prebuilt += 1
	if not l.has_structure():
		l.ensure_structure()
	l.request_source(at, quality, HINT_EXPORT if export_ahead_on() else (HINT_PLAY if warm and (l.source.primed or l.source.proxy_on) else HINT_STEP))
	if not _ahead_log.has(c.id):
		_ahead_log[c.id] = {"t": last_time, "primed_t": -1.0}
	var rec: Dictionary = _ahead_log[c.id]
	if l.source.primed and float(rec["primed_t"]) < 0.0:
		rec["primed_t"] = last_time


func _forget_ahead() -> void:
	for id: Variant in _ahead_of.keys():
		if not layers.has(id):
			_ahead_of.erase(id)
	for id2: Variant in _ahead_log.keys():
		if not layers.has(id2):
			_ahead_log.erase(id2)
	if _miss_of.size() > CUT_LOG_KEEP:
		_miss_of = {}


func _watch_doc(d: Object) -> void:
	if d == _watched_doc:
		return
	if _watched_doc != null and is_instance_valid(_watched_doc) and _watched_doc.has_signal("changed") and _watched_doc.is_connected("changed", _on_doc_changed_wake):
		_watched_doc.disconnect("changed", _on_doc_changed_wake)
	_watched_doc = d
	if d != null and d.has_signal("changed") and not d.is_connected("changed", _on_doc_changed_wake):
		d.connect("changed", _on_doc_changed_wake)


func _on_doc_changed_wake(_kind: String) -> void:
	wake()


func wake() -> void:
	_woke_ms = Time.get_ticks_msec()
	_woke_frame = Engine.get_frames_drawn()
	if not resting:
		return
	resting = false
	wakes += 1
	for vp: SubViewport in _rested:
		if is_instance_valid(vp) and vp.render_target_update_mode == SubViewport.UPDATE_DISABLED:
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_rested = []


func rest() -> void:
	_rested = []
	for n: Node in find_children("*", "SubViewport", true, false):
		var vp: SubViewport = n as SubViewport
		if vp != null and vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_rested.append(vp)
	resting = true
	rests += 1


func rest_allowed() -> bool:
	var now: int = Time.get_ticks_msec()
	if now - _rest_pref_ms >= REST_PREF_MS:
		_rest_pref_ms = now
		var prefs: Node = _root_node_named("Prefs")
		_rest_pref = true
		if prefs != null and prefs.has_method("is_registered"):
			if not bool(prefs.call("is_registered", IDLE_PREF)):
				prefs.call("register", IDLE_PREF, true, {"label": "Stop redrawing the picture while paused and nothing changes (saves power, any change draws it again)", "type": "bool"})
			_rest_pref = bool(prefs.call("get_value", IDLE_PREF))
	return _rest_pref


func _root_node_named(node_name: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(node_name)
	return null


func may_rest() -> bool:
	if resting or depth > 0 or playing or _in_render:
		return false
	if not rest_allowed():
		return false
	if not _plant_rest_now:
		if Engine.get_frames_drawn() - _woke_frame < REST_AFTER_FRAMES or Time.get_ticks_msec() - _woke_ms < REST_AFTER_MS:
			return false
		if unsettled():
			return false
	var s: Node = _session()
	if s != null and (bool(s.get("playing")) or (s.has_method("scrub_live") and bool(s.call("scrub_live")))):
		return false
	return not _exporting_now()


const PRIME_AFTER_MS := 60
const PRIME_AFTER_FRAMES := 2
var _warm: bool = false
var _primed_here: bool = false
var prime_rounds: int = 0


const WARM_PREF := "playback.warm_offset_regions"


func warm_allowed() -> bool:
	var prefs: Node = _root_node_named("Prefs")
	if prefs == null or not prefs.has_method("is_registered"):
		return false
	if not bool(prefs.call("is_registered", WARM_PREF)):
		prefs.call("register", WARM_PREF, false, {"label": "Keep offset Pair View regions ready to play while paused (experimental)", "type": "bool"})
	return bool(prefs.call("get_value", WARM_PREF))


func may_prime() -> bool:
	if depth > 0 or playing or _in_render or seq == null or not warm_allowed():
		return false
	if Engine.get_frames_drawn() - _woke_frame < PRIME_AFTER_FRAMES or Time.get_ticks_msec() - _woke_ms < PRIME_AFTER_MS:
		return false
	if unsettled():
		return false
	var s: Node = _session()
	if s != null and (bool(s.get("playing")) or (s.has_method("scrub_live") and bool(s.call("scrub_live")))):
		return false
	return not _exporting_now()


func prime_for_play() -> int:
	_primed_here = true
	var n: int = 0
	for k: Variant in layers.keys():
		var l: LayerChain = layers[k]
		if l != null and is_instance_valid(l) and not l.waiting and l.source.kind == FrameSource.KIND_NATIVE:
			if l.source.prime_for_play(quality):
				n += 1
	if pair_regions != null and is_instance_valid(pair_regions):
		n += pair_regions.prime_all(quality)
	if n > 0:
		prime_rounds += 1
	return n


func rest_stats() -> Dictionary:
	return {"resting": resting, "rests": rests, "wakes": wakes, "rested": _rested.size()}

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Verbs := preload("res://doc/verbs.gd")
const TransitionRegistry := preload("res://engine/transition_registry.gd")
const Picker := preload("res://modules/core_panels/transition_picker.gd")
const Bus := preload("res://modules/core_panels/panel_bus.gd")
const SELF_PATH := "res://modules/core_panels/transition_ops.gd"
const Timing := preload("res://doc/transition_timing.gd")
const FreeTransition := preload("res://doc/free_transition.gd")
const TrackCmds := preload("res://doc/commands/track_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const Presets := preload("res://doc/presets.gd")
const PRESET_KIND := "transition"
const PRESET_PREFIX := "preset:"
const PRESETS_GROUP := "My presets"


static func registry() -> RefCounted:
	return TransitionRegistry.shared()


static func canvas() -> Control:
	var tl: Object = Bus.instance().call("panel", "timeline")
	if tl == null:
		return null
	var c: Variant = tl.get("canvas")
	return c if c is Control else null


static func kind_of(c: Clip) -> String:
	if c == null or not c.has_transition():
		return ""
	var lib: String = TransitionRegistry.library_id(c.transition_in)
	return lib if not lib.is_empty() else str(c.transition_in.get("kind", ""))


static func selected_kind(s: Sequence) -> String:
	if s == null:
		return ""
	return kind_of(Bus.selected_clip(s))


static func picture_clip(s: Sequence, clip_id: String) -> Clip:
	if s == null:
		return null
	var c: Clip = s.clip_by_id(clip_id)
	var t: Track = s.track_of(clip_id)
	if c == null or t == null or not t.is_picture(c) or t.locked:
		return null
	return c


static func field_of(side: String) -> String:
	return Timing.OUT_FIELD if side == "out" else Timing.IN_FIELD


static func kind_on(c: Clip, side: String) -> String:
	if side != "out":
		return kind_of(c)
	if c == null or not c.has_transition_out():
		return ""
	return TransitionRegistry.library_id(c.transition_out)


static func out_kind(id: String) -> String:
	if not TransitionRegistry.is_classic(id) or bool(registry().call("has", id)):
		return id
	return "fade"


static func set_field(d: Project, s: Sequence, clip_id: String, side: String, tr: Dictionary) -> bool:
	if side == "out":
		return Verbs.set_transition_out(d, s, clip_id, tr)
	return Verbs.set_transition(d, s, clip_id, tr)


static func put_out(d: Project, s: Sequence, c: Clip, id: String, preset: Dictionary, length: float) -> bool:
	if d == null or s == null or c == null:
		return false
	var kind: String = out_kind(id)
	var dur: float = clampf(length, Clip.MIN_TRANSITION, maxf(c.duration, Clip.MIN_TRANSITION))
	if not preset.is_empty():
		dur = clampf(float((preset.get("payload", {}) as Dictionary).get("length", dur)), Clip.MIN_TRANSITION, maxf(c.duration, Clip.MIN_TRANSITION))
		var ps: Dictionary = spec_from_preset(preset, dur, 1.0)
		ps["kind"] = out_kind(String(ps.get("kind", kind)))
		if not ps.has(TransitionRegistry.LIB_KEY):
			ps[TransitionRegistry.LIB_KEY] = true
		return Verbs.set_transition_out(d, s, c.id, ps)
	if c.has_transition_out():
		return Verbs.set_transition_out(d, s, c.id, registry().call("changed_spec", c.transition_out, kind))
	return Verbs.set_transition_out(d, s, c.id, registry().call("make_spec", kind, dur, 1.0))


static func put_on(d: Project, s: Sequence, clip_id: String, id: String, side: String = "in") -> bool:
	if d == null or s == null:
		return false
	var c: Clip = picture_clip(s, clip_id)
	if c == null:
		return false
	if side == "out":
		if kind_on(c, "out") == out_kind(id):
			return false
		return put_out(d, s, c, id, {}, 1.0)
	if c.has_transition() and str(c.transition_in.get("kind", "")) != TransitionRegistry.AUDIO_KIND:
		if kind_of(c) == id:
			return false
		return Verbs.set_transition(d, s, clip_id, registry().call("changed_spec", c.transition_in, id))
	var cv: Control = canvas()
	if cv != null and cv.has_method("apply_transition_at"):
		return bool(cv.call("apply_transition_at", id, s.track_of(clip_id).id, c.start, c))
	var spec: Dictionary = registry().call("make_spec", id, minf(1.0, c.duration), 0.5 if s.track_of(clip_id).prev_clip(c) != null else 0.0)
	return Verbs.set_transition(d, s, clip_id, spec)


static func put_on_selection(d: Project, s: Sequence, id: String) -> int:
	if d == null or s == null:
		return 0
	var done: int = 0
	for cid: String in Verbs.selection(s):
		if picture_clip(s, cid) != null and put_on(d, s, cid, id):
			done += 1
	return done


static func remove(d: Project, s: Sequence, clip_id: String, side: String = "in") -> bool:
	if d == null or s == null:
		return false
	return set_field(d, s, clip_id, side, {})


static func open_picker(host: Node, clip_id: String, side: String = "in") -> Control:
	var s: Sequence = Session.seq()
	var c: Clip = picture_clip(s, clip_id)
	if c == null:
		return null
	var has: bool = c.has_transition_out() if side == "out" else c.has_transition()
	var title: String = ("Change transition" if has else "Add transition") + (" at the end" if side == "out" else "")
	return Picker.open(host, title, kind_on(c, side), Callable(load(SELF_PATH), "_picked").bind(clip_id, side))


static func _picked(id: String, clip_id: String, side: String) -> void:
	put_on(Session.doc, Session.seq(), clip_id, id, side)


static func timing(d: Project, s: Sequence, clip_id: String, side: String, name: String) -> bool:
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c == null:
		return false
	var tr: Dictionary = c.transition_field(field_of(side))
	if tr.is_empty():
		return false
	return set_field(d, s, clip_id, side, Timing.with_timing(tr, name))


static func fit(d: Project, s: Sequence, clip_id: String, side: String, from_frac: float, to_frac: float) -> bool:
	var c: Clip = s.clip_by_id(clip_id) if s != null else null
	if c == null:
		return false
	var tr: Dictionary = c.transition_field(field_of(side))
	if tr.is_empty():
		return false
	return set_field(d, s, clip_id, side, Timing.fitted(Timing.with_progress(tr), from_frac, to_frac))


static func free_kind(id: String) -> String:
	if id == TransitionRegistry.AUDIO_KIND:
		return "fade"
	if TransitionRegistry.is_classic(id) and not bool(registry().call("has", id)):
		return "fade"
	return id


static func free_spec(id: String, length: float, preset: Dictionary) -> Dictionary:
	var dur: float = maxf(length, FreeTransition.MIN_DURATION)
	if not preset.is_empty():
		var plen: float = maxf(float((preset.get("payload", {}) as Dictionary).get("length", dur)), FreeTransition.MIN_DURATION)
		var ps: Dictionary = spec_from_preset(preset, plen, 0.0)
		ps["kind"] = free_kind(String(ps.get("kind", id)))
		if not ps.has(TransitionRegistry.LIB_KEY):
			ps[TransitionRegistry.LIB_KEY] = true
		ps["offset"] = 0.0
		return ps
	var spec: Dictionary = registry().call("make_spec", free_kind(id), dur, 0.0)
	spec["offset"] = 0.0
	return spec


static func _write_free(d: Project, s: Sequence, tr: Track, list: Array[Dictionary], label: String) -> bool:
	if d == null or s == null or tr == null:
		return false
	var cmd: Command = TrackCmds.SetTrackField.new(s.id, tr.id, FreeTransition.FIELD, list)
	cmd.label = label
	var cmds: Array[Command] = [cmd]
	return Verbs.run(d, label, cmds)


static func free_track(s: Sequence, track_id: String) -> Track:
	if s == null:
		return null
	var tr: Track = s.track_by_id(track_id)
	if tr == null or tr.locked or not tr.makes_picture():
		return null
	return tr


static func place_free(d: Project, s: Sequence, track_id: String, id: String, t: float, length: float, preset_id: String = "") -> String:
	var tr: Track = free_track(s, track_id)
	if tr == null:
		return ""
	var preset: Dictionary = preset_by_id(preset_id) if not preset_id.is_empty() else {}
	var spec: Dictionary = free_spec(id, length, preset)
	var dur: float = maxf(float(spec.get("duration", length)), FreeTransition.MIN_DURATION)
	var want: float = FreeTransition.free_room(tr.free_transitions, maxf(t, 0.0), dur)
	if want < 0.0:
		return ""
	var ft_id: String = FreeTransition.fresh_id(tr.free_transitions, tr.id)
	var list: Array[Dictionary] = FreeTransition.put(tr.free_transitions, FreeTransition.make(ft_id, want, dur, spec))
	if not _write_free(d, s, tr, list, "Place transition"):
		return ""
	return ft_id


static func span_free(d: Project, s: Sequence, track_id: String, ft_id: String, start: float, duration: float, label: String = "Move transition") -> bool:
	var tr: Track = free_track(s, track_id)
	if tr == null:
		return false
	var ft: Dictionary = FreeTransition.by_id(tr.free_transitions, ft_id)
	if ft.is_empty():
		return false
	var dur: float = maxf(duration, FreeTransition.MIN_DURATION)
	var at: float = maxf(start, 0.0)
	if FreeTransition.overlaps(tr.free_transitions, at, dur, ft_id):
		return false
	var next: Dictionary = FreeTransition.with_span(ft, at, dur)
	if float(next[FreeTransition.KEY_DURATION]) != FreeTransition.duration_of(ft):
		next[FreeTransition.KEY_SPEC] = Timing.stretched(FreeTransition.spec_of(ft), dur)
	if next == ft:
		return false
	return _write_free(d, s, tr, FreeTransition.put(tr.free_transitions, next), label)


static func move_free(d: Project, s: Sequence, track_id: String, ft_id: String, start: float) -> bool:
	var tr: Track = free_track(s, track_id)
	if tr == null:
		return false
	var ft: Dictionary = FreeTransition.by_id(tr.free_transitions, ft_id)
	if ft.is_empty():
		return false
	return span_free(d, s, track_id, ft_id, start, FreeTransition.duration_of(ft))


static func remove_free(d: Project, s: Sequence, track_id: String, ft_id: String) -> bool:
	var tr: Track = free_track(s, track_id)
	if tr == null or FreeTransition.by_id(tr.free_transitions, ft_id).is_empty():
		return false
	return _write_free(d, s, tr, FreeTransition.without(tr.free_transitions, ft_id), "Remove transition")


static func change_free(d: Project, s: Sequence, track_id: String, ft_id: String, id: String) -> bool:
	var tr: Track = free_track(s, track_id)
	if tr == null:
		return false
	var ft: Dictionary = FreeTransition.by_id(tr.free_transitions, ft_id)
	if ft.is_empty():
		return false
	var next: Dictionary = ft.duplicate(true)
	next[FreeTransition.KEY_SPEC] = registry().call("changed_spec", FreeTransition.spec_of(ft), free_kind(id))
	if next == ft:
		return false
	return _write_free(d, s, tr, FreeTransition.put(tr.free_transitions, next), "Change transition")


static func kind_of_free(ft: Dictionary) -> String:
	var spec: Dictionary = FreeTransition.spec_of(ft)
	var lib: String = TransitionRegistry.library_id(spec)
	return lib if not lib.is_empty() else String(spec.get("kind", ""))


static func select_free(d: Project, s: Sequence, track_id: String, ft_id: String) -> bool:
	if d == null or s == null:
		return false
	var tr: Track = s.track_by_id(track_id)
	if tr == null or FreeTransition.by_id(tr.free_transitions, ft_id).is_empty():
		return false
	if String(s.selected_free.get("id", "")) == ft_id and s.selected_clip_ids.is_empty():
		return false
	s.hold_free(track_id, ft_id)
	d.changed.emit("selection")
	return true


static func clear_free(d: Project, s: Sequence) -> bool:
	if d == null or s == null or s.selected_free.is_empty():
		return false
	s.selected_free = {}
	d.changed.emit("selection")
	return true


static func remove_selected_free(d: Project, s: Sequence) -> bool:
	if s == null:
		return false
	var held: Dictionary = s.held_free()
	if held.is_empty():
		return false
	var took: bool = remove_free(d, s, String(held.get("track_id", "")), String(held.get("id", "")))
	if took:
		s.selected_free = {}
		d.changed.emit("selection")
	return took


static func presets() -> Array[Dictionary]:
	return Presets.list_user(PRESET_KIND)


static func preset_by_id(id: String) -> Dictionary:
	for p: Dictionary in presets():
		if String(p.get("id", "")) == id:
			return p
	return {}


static func save_preset(c: Clip, side: String, label: String) -> Dictionary:
	if c == null:
		return {}
	var tr: Dictionary = c.transition_field(field_of(side))
	if tr.is_empty():
		return {}
	var p: Dictionary = Presets.make(PRESET_KIND, label, Timing.preset_payload(Timing.with_progress(tr)))
	if p.is_empty() or not Presets.save_user(p):
		return {}
	return p


static func rename_preset(id: String, label: String) -> bool:
	var p: Dictionary = preset_by_id(id)
	if p.is_empty() or label.strip_edges().is_empty():
		return false
	p["label"] = label.strip_edges()
	return Presets.save_user(p)


static func delete_preset(id: String) -> bool:
	return Presets.delete_user(PRESET_KIND, id)


static func spec_from_preset(preset: Dictionary, dur: float, offset: float) -> Dictionary:
	return Timing.with_progress(Timing.from_preset(preset.get("payload", {}), dur, offset))


static func preset_def(p: Dictionary) -> Dictionary:
	var tr: Dictionary = (p.get("payload", {}) as Dictionary).get("transition", {})
	var base: String = TransitionRegistry.library_id(tr)
	if base.is_empty():
		base = str(tr.get("kind", "fade"))
	var def: Dictionary = (registry().call("get_def", base) as Dictionary).duplicate()
	if def.is_empty():
		def = {"id": base, "params": [], "space": "2D", "classic": TransitionRegistry.is_classic(base)}
	def["preview_id"] = base
	def["id"] = PRESET_PREFIX + String(p.get("id", ""))
	def["label"] = String(p.get("label", base))
	def["group"] = PRESETS_GROUP
	def["blurb"] = "Your preset of " + String(registry().call("label_of", base)) + ", " + str(snappedf(float((p.get("payload", {}) as Dictionary).get("length", 1.0)), 0.01)) + " s"
	def["from"] = []
	def["preset"] = String(p.get("id", ""))
	return def


static func apply_preset(p: Dictionary, clip_ids: PackedStringArray, t: float, track: Track) -> bool:
	var cv: Control = canvas()
	var s: Sequence = Session.seq()
	if cv == null or s == null or p.is_empty():
		return false
	var kind: String = str(((p.get("payload", {}) as Dictionary).get("transition", {}) as Dictionary).get("kind", "fade"))
	var pid: String = String(p.get("id", ""))
	if track != null and clip_ids.size() <= 1:
		return bool(cv.call("apply_transition_at", kind, track.id, t, null, pid))
	var done: int = 0
	for cid: String in (clip_ids if not clip_ids.is_empty() else Verbs.selection(s)):
		var c: Clip = picture_clip(s, cid)
		if c != null and bool(cv.call("apply_transition_at", kind, s.track_of(cid).id, c.start, c, pid)):
			done += 1
	return done > 0

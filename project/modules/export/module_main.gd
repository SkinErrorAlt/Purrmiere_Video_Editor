extends RefCounted

const ExportPanel := preload("res://modules/export/export_panel.gd")
const ExportJob := preload("res://modules/export/export_job.gd")
const ExportPresets := preload("res://modules/export/export_presets.gd")
const ExportSequences := preload("res://modules/export/export_sequences.gd")
const AudioVisualiser := preload("res://modules/export/audio_visualiser.gd")
const ClipCut := preload("res://modules/export/clipcut_panel.gd")
const PmCompositor := preload("res://engine/compositor.gd")
const EffectRegistry := preload("res://engine/effect_registry.gd")
const AudioGraph := preload("res://engine/audio_graph.gd")
const Backdrop := preload("res://engine/backdrop.gd")
const IExporter := preload("res://host/interfaces/i_exporter.gd")
const Sequence := preload("res://doc/sequence.gd")
const PANEL_ID := "export"
const CMD_RELOAD := "effects.reload"
const CMD_EXPORT := "export.now"
const LIVE_CLIP_KEY := "clip_param|"
const LIVE_MANY_KEY := "clip_param|many|"
const LIVE_PATCH_KEYS: Dictionary = {"audio.volume": "volume", "audio.pan": "pan"}

var _host: Node = null
var _panel: RefCounted = null
var _compositor: Node = null
var _registered_panel: bool = false
var _graph_queued: bool = false
var graph_deferrals: int = 0
var graph_requests: int = 0
const GRAPH_POLL_S := 0.05
const GRAPH_FIRST_SLICE_US := 6000
const GRAPH_SLICE_US := 6000
const FrameJobs := preload("res://host/frame_jobs.gd")
var _slices: Dictionary = {}
var graph_slices: int = 0
var _live_queued: bool = false
var _live_base_ok: bool = false
var _live_base_doc: int = 0
var _live_base_seq: String = ""
var _live_ids: Dictionary = {}
var _live_driven: Dictionary = {}
var live_stats: Dictionary = {"full": 0, "patched": 0, "fallback": 0}


class FrameExporter extends IExporter:
	func id() -> String:
		return "frames"

	func label() -> String:
		return "Video and audio through purrcore"

	func options_spec() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		out.append({"key": "settings", "label": "Export settings", "type": "dictionary", "default": ExportPresets.default_settings()})
		return out

	func run(job: Dictionary) -> int:
		var loop: MainLoop = Engine.get_main_loop()
		if not (loop is SceneTree):
			return -1
		var root: Node = (loop as SceneTree).root
		var session: Node = root.get_node_or_null("Session")
		if session == null or session.get("doc") == null:
			return -1
		var j: Node = ExportJob.new()
		j.name = "ExportJob"
		var settings: Dictionary = job.get("settings", {}) if job.get("settings") is Dictionary else job
		var target: Sequence = ExportSequences.sequence_of(settings, session.get("doc"), session.call("seq"))
		j.call("setup", settings, target, session.get("doc"), session.get("compositor"), session.get("media_handles"))
		root.add_child(j)
		j.call("start")
		return int(j.get("local_job_id"))


class ClipCutExporter extends IExporter:
	func id() -> String:
		return "clipcut"

	func label() -> String:
		return "Clip cut without re-encode"

	func options_spec() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		out.append({"key": "settings", "label": "Clip cut settings", "type": "dictionary", "default": ClipCut.default_settings()})
		return out

	func run(job: Dictionary) -> int:
		var loop: MainLoop = Engine.get_main_loop()
		if not (loop is SceneTree):
			return -1
		var bridge: Node = (loop as SceneTree).root.get_node_or_null("PurrBridge")
		if bridge == null or not bool(bridge.get("available")):
			return -1
		return int(bridge.call("clipcut", job))


func _root() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root
	return null


func _session() -> Node:
	var r: Node = _root()
	return r.get_node_or_null("Session") if r != null else null


func _prefs() -> Node:
	var r: Node = _root()
	return r.get_node_or_null("Prefs") if r != null else null


func apply_backdrop() -> void:
	if _compositor == null or not is_instance_valid(_compositor) or not _compositor.has_method("set_backdrop"):
		return
	_compositor.call("set_backdrop", Backdrop.spec_from_prefs(_prefs()))


func register(host: Node) -> void:
	_host = host
	EffectRegistry.shared()
	_panel = ExportPanel.new()
	host.register("IPanel", PANEL_ID, _panel, {"title": "Export", "official": true})
	_registered_panel = host.get_impl("IPanel", PANEL_ID) == _panel
	if not _registered_panel:
		print("export module: the IPanel id \"export\" is still owned by core_panels, remove it from core_panels/module.json so the real export panel shows")
	host.register("IExporter", "frames", FrameExporter.new(), {"label": "Video and audio through purrcore", "official": true})
	host.register("IExporter", "clipcut", ClipCutExporter.new(), {"label": "Clip cut without re-encode", "official": true})
	var cmd: Node = _root().get_node_or_null("Cmd") if _root() != null else null
	if cmd != null:
		cmd.register(CMD_RELOAD, {"label": "Reload Effects", "category": "Effects", "scope": "global", "keys": {}, "handler": _reload_effects, "owner": "export"})
		cmd.register(CMD_EXPORT, {"label": "Export Now", "category": "File", "scope": "global", "keys": {"premiere": ["Ctrl+M"], "classic": ["Ctrl+M"]}, "handler": _export_now, "owner": "export"})
	Backdrop.ensure_prefs(_prefs(), EffectRegistry.shared())
	AudioVisualiser.register()
	AudioGraph.VeryLoud.register_prefs()
	var p: Node = _prefs()
	if p != null and not bool(p.call("is_registered", ExportJob.PREF_SETTLE_SECONDS)):
		p.call("register", ExportJob.PREF_SETTLE_SECONDS, ExportJob.SETTLE_SECONDS, {
			"label": "Export: how long to wait for one frame to be the real picture (seconds)",
			"type": "float", "min": 1.0, "max": 300.0,
		})
	if p != null and not bool(p.call("is_registered", ExportJob.PREF_BUDGET_MS)):
		p.call("register", ExportJob.PREF_BUDGET_MS, ExportJob.BUDGET_MS, {
			"label": "Export: milliseconds of export work the editor carries per frame (lower keeps editing smoother, the export takes longer)",
			"type": "int", "min": ExportJob.BUDGET_MIN_MS, "max": ExportJob.BUDGET_MAX_MS,
		})
	if p != null and not bool(p.call("is_registered", ExportJob.PREF_PNG_VERIFY)):
		p.call("register", ExportJob.PREF_PNG_VERIFY, ExportJob.PNG_VERIFY, {
			"label": ExportJob.PNG_VERIFY_LABEL,
			"type": "bool",
			"hint": ExportJob.PNG_VERIFY_HINT,
		})
	var s: Node = _session()
	if s != null:
		s.connect("project_changed", _on_project_changed)
		s.connect("sequence_changed", _on_sequence_changed)
		s.connect("playing_changed", _on_playing_changed)
		if s.has_signal("about_to_play"):
			s.connect("about_to_play", _on_about_to_play)
		if s.has_signal("audio_owner_changed"):
			s.connect("audio_owner_changed", _on_audio_owner_changed)
		var prefs: Node = _root().get_node_or_null("/root/Prefs") if _root() != null else null
		if prefs != null and not prefs.is_connected("changed", _on_pref_changed):
			prefs.connect("changed", _on_pref_changed)
		_on_project_changed()


func unregister() -> void:
	var s: Node = _session()
	if s != null:
		if s.is_connected("project_changed", _on_project_changed):
			s.disconnect("project_changed", _on_project_changed)
		if s.is_connected("sequence_changed", _on_sequence_changed):
			s.disconnect("sequence_changed", _on_sequence_changed)
		if s.is_connected("playing_changed", _on_playing_changed):
			s.disconnect("playing_changed", _on_playing_changed)
		if s.has_signal("about_to_play") and s.is_connected("about_to_play", _on_about_to_play):
			s.disconnect("about_to_play", _on_about_to_play)
		if s.has_signal("audio_owner_changed") and s.is_connected("audio_owner_changed", _on_audio_owner_changed):
			s.disconnect("audio_owner_changed", _on_audio_owner_changed)
		if s.get("compositor") == _compositor:
			s.call("set_compositor", null)
	if _compositor != null and is_instance_valid(_compositor):
		var p: Node = _compositor.get_parent()
		if p != null:
			p.remove_child(_compositor)
		_compositor.queue_free()
	_compositor = null
	if _host != null:
		if _registered_panel:
			_host.unregister("IPanel", PANEL_ID)
		_host.unregister("IExporter", "frames")
		_host.unregister("IExporter", "clipcut")
	var cmd: Node = _root().get_node_or_null("Cmd") if _root() != null else null
	if cmd != null:
		cmd.unregister(CMD_RELOAD)
		cmd.unregister(CMD_EXPORT)


func _reload_effects() -> void:
	var reg: RefCounted = EffectRegistry.shared()
	reg.reload()
	var events: Node = _root().get_node_or_null("Events") if _root() != null else null
	if events != null:
		events.info("Effects reloaded: %d effects" % reg.list().size())


func _export_now() -> void:
	if _panel != null and _panel.has_method("_on_export_now"):
		_panel.call("_on_export_now")


func compositor() -> Node:
	return _compositor


func _ensure_compositor() -> Node:
	if _compositor != null and is_instance_valid(_compositor):
		return _compositor
	_compositor = PmCompositor.new()
	_compositor.name = "SequenceCompositor"
	var r: Node = _root()
	if r != null:
		r.add_child(_compositor)
	return _compositor


func _on_project_changed() -> void:
	var s: Node = _session()
	if s == null:
		return
	var doc: RefCounted = s.get("doc")
	if doc == null:
		if s.get("compositor") == _compositor and _compositor != null:
			_compositor.call("set_sequence", null, null)
		return
	var comp: Node = _ensure_compositor()
	comp.set("media_handles", s.get("media_handles"))
	if ExportJob.compositor_holders == 0:
		comp.call("set_sequence", s.call("seq"), doc)
	comp.set("playing", bool(s.get("playing")))
	apply_backdrop()
	if s.get("compositor") != comp:
		s.call("set_compositor", comp)
	if doc.has_signal("changed") and not doc.is_connected("changed", _on_doc_changed):
		doc.connect("changed", _on_doc_changed)
	_queue_audio_graph(false)


func _on_sequence_changed(_id: String) -> void:
	_on_project_changed()


func _on_playing_changed(on: bool) -> void:
	if _compositor != null and is_instance_valid(_compositor):
		_compositor.set("playing", on)


func _on_doc_changed(kind: String) -> void:
	if kind == "live_audio":
		_queue_live_audio()
	elif kind == "structure" or kind == "meta" or kind == "media":
		_queue_audio_graph()


func _on_pref_changed(key: String) -> void:
	if key.begins_with("audio.crossfeed") or key.begins_with("waves.loud_") or key == AudioGraph.VeryLoud.PREF_DB:
		_queue_audio_graph()
	elif key.begins_with("program.backdrop."):
		apply_backdrop()


func _on_audio_owner_changed(owner: String) -> void:
	if owner.is_empty():
		_push_audio_graph()


func _queue_audio_graph(may_wait: bool = true) -> void:
	_live_base_ok = false
	graph_requests += 1
	_slices = {}
	if _graph_queued:
		return
	_graph_queued = true
	var s: Node = _session()
	if not may_wait or s == null or bool(s.get("playing")) or Input.get_mouse_button_mask() == 0 or not (Engine.get_main_loop() is SceneTree):
		FrameJobs.add("sound_graph", _push_sliced)
		return
	graph_deferrals += 1
	(Engine.get_main_loop() as SceneTree).create_timer(GRAPH_POLL_S).timeout.connect(_idle_push)


func _idle_push() -> void:
	if not _graph_queued:
		return
	var s: Node = _session()
	if s != null and not bool(s.get("playing")) and Input.get_mouse_button_mask() != 0 and Engine.get_main_loop() is SceneTree:
		(Engine.get_main_loop() as SceneTree).create_timer(GRAPH_POLL_S).timeout.connect(_idle_push)
		return
	_push_sliced()


func _push_sliced() -> void:
	if not _graph_queued:
		return
	_push_graph(GRAPH_FIRST_SLICE_US if _slices.is_empty() else GRAPH_SLICE_US)


func _next_slice() -> void:
	if not _graph_queued:
		return
	var s: Node = _session()
	if s != null and not bool(s.get("playing")) and Input.get_mouse_button_mask() != 0 and Engine.get_main_loop() is SceneTree:
		(Engine.get_main_loop() as SceneTree).create_timer(GRAPH_POLL_S).timeout.connect(_idle_push)
		return
	_push_graph(GRAPH_SLICE_US)


func _on_about_to_play() -> void:
	if _graph_queued:
		_push_audio_graph()


func _queue_live_audio() -> void:
	if _graph_queued or _live_queued:
		return
	if not _live_base_ok:
		_queue_audio_graph()
		return
	_live_queued = true
	Callable(self, "_push_live_audio").call_deferred()


func _push_live_audio() -> void:
	_live_queued = false
	if _graph_queued:
		return
	var s: Node = _session()
	var r: Node = _root()
	if s == null or r == null:
		return
	if not String(s.get("audio_owner")).is_empty():
		return
	var bridge: Node = r.get_node_or_null("PurrBridge")
	if bridge == null or not bool(bridge.get("available")):
		return
	var doc: RefCounted = s.get("doc")
	var seq: Sequence = s.call("seq")
	if doc == null or seq == null:
		return
	var patches: Array = live_patches(doc, seq, s.get("media_handles"))
	if patches.is_empty():
		live_stats["fallback"] = int(live_stats["fallback"]) + 1
		_queue_audio_graph()
		return
	for one: Variant in patches:
		var pa: Array = one
		bridge.call("patch_audio_param", String(pa[0]), String(pa[1]), pa[2])
	live_stats["patched"] = int(live_stats["patched"]) + 1


func live_patches(doc: RefCounted, seq: Sequence, handles: Dictionary) -> Array:
	var out: Array = []
	if not _live_base_ok or doc.get_instance_id() != _live_base_doc or seq.id != _live_base_seq or ExportJob.compositor_holders > 0:
		return out
	var undo: Object = doc.get("undo")
	if undo == null:
		return out
	var cmds: Array = undo.call("live_commands")
	if cmds.is_empty():
		return out
	for cmd: Variant in cmds:
		var k: String = String((cmd as Object).call("live_key"))
		if not k.begins_with(LIVE_CLIP_KEY) or k.begins_with(LIVE_MANY_KEY):
			return []
		var key: String = String(LIVE_PATCH_KEYS.get(String((cmd as Object).get("path")), ""))
		var cid: String = String((cmd as Object).get("clip_id"))
		if key.is_empty() or _live_driven.has(cid):
			return []
		var got: Dictionary = AudioGraph.live_entries(doc, seq, handles, cid)
		if not bool(got["ok"]):
			return []
		var entries: Dictionary = got["entries"]
		if entries.has(cid) != _live_ids.has(cid):
			return []
		for eid: Variant in entries.keys():
			if int(_live_ids.get(String(eid), 0)) != 1:
				return []
			out.append([String(eid), key, (entries[eid] as Dictionary)[key]])
	return out


func _push_audio_graph() -> void:
	_push_graph(-1)


func _push_graph(budget_usec: int) -> void:
	var s: Node = _session()
	var r: Node = _root()
	var bridge: Node = r.get_node_or_null("PurrBridge") if r != null else null
	var doc: RefCounted = s.get("doc") if s != null else null
	if s == null or r == null or not String(s.get("audio_owner")).is_empty() or bridge == null or not bool(bridge.get("available")) or doc == null:
		_graph_queued = false
		_slices = {}
		return
	var seq: Sequence = s.call("seq")
	var handles: Dictionary = s.get("media_handles")
	if not AudioGraph.build_still_good(_slices, doc, seq, handles):
		_slices = AudioGraph.build_begin(doc, seq, handles)
	graph_slices += 1
	if not AudioGraph.build_step(_slices, budget_usec):
		_graph_queued = true
		FrameJobs.add("sound_graph", _next_slice)
		return
	var graph: Dictionary = _slices["graph"]
	_slices = {}
	_graph_queued = false
	bridge.call("set_audio_graph", graph)
	live_stats["full"] = int(live_stats["full"]) + 1
	_live_ids = AudioGraph.entry_ids_in(graph)
	_live_driven = AudioGraph.driven_sources_in(graph)
	_live_base_doc = doc.get_instance_id()
	_live_base_seq = seq.id if seq != null else ""
	_live_base_ok = seq != null

extends RefCounted

const Tracking := preload("res://doc/tracking.gd")
const TrackingEval := preload("res://engine/tracking_eval.gd")
const TrackingCmds := preload("res://doc/commands/tracking_cmds.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const Command := preload("res://doc/commands/command.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Verbs := preload("res://doc/verbs.gd")
const MaskPass := preload("res://engine/mask_pass.gd")
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const DRIVER := "res://doc/anim_driver.gd"
const LINK_KEY := "tracker_link"
const TRACK_KEY := "track"
const STAB_KEY := "stabilise"
const BAKE_TOLERANCE := 0.01


static func media_of(doc: Project, c: Clip) -> MediaItem:
	return doc.media_by_id(c.media_id) if doc != null and c != null else null


static func can_track(doc: Project, c: Clip) -> String:
	if c == null:
		return "Select a clip with a picture"
	var m: MediaItem = media_of(doc, c)
	if m == null or m.path.is_empty():
		return "This clip has no file to track"
	if m.kind != "video":
		return "Only video clips can be tracked"
	if m.width <= 0 or m.height <= 0:
		return "The file has not been read yet"
	return ""


static func media_time_at(c: Clip, t_seq: float) -> float:
	return c.source_time(clampf(t_seq, c.start, maxf(c.start, c.end() - 0.000001)))


static func new_set(doc: Project, seq: Sequence, c: Clip, points: int) -> String:
	if not can_track(doc, c).is_empty():
		return ""
	var sid: String = Tracking.new_id(doc, "trk")
	var mt: float = media_time_at(c, seq.playhead)
	var s: Dictionary = Tracking.make_set(sid, c, media_of(doc, c), points, mt)
	var label: String = "Track two points" if points >= 2 else "Track a point"
	if not Verbs.run(doc, label, [TrackingCmds.SetSet.new(label, sid, s)] as Array[Command]):
		return ""
	return sid


static func write(doc: Project, set_id: String, s: Dictionary, label: String) -> bool:
	return Verbs.run(doc, label, [TrackingCmds.SetSet.new(label, set_id, s)] as Array[Command])


static func write_live(doc: Project, set_id: String, s: Dictionary, label: String) -> void:
	doc.undo.live(TrackingCmds.SetSet.new(label, set_id, s, "live"))


static func remove_set(doc: Project, set_id: String) -> bool:
	var cmds: Array[Command] = []
	for link: Dictionary in links(doc, set_id):
		var cmd: Command = _detach_cmd(doc, link)
		if cmd != null:
			cmds.append(cmd)
	cmds.append(TrackingCmds.SetSet.new("Remove tracker", set_id, {}))
	return Verbs.run(doc, "Remove tracker", cmds)


static func set_range(doc: Project, set_id: String, a: float, b: float, label: String = "Set track range") -> bool:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	if s.is_empty() or b <= a:
		return false
	var out: Dictionary = s.duplicate(true)
	out["range"] = [a, b]
	return write(doc, set_id, out, label)


static func range_to_clip(doc: Project, set_id: String) -> bool:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	var c: Clip = doc.clip_by_id(String(s.get("clip", ""))) if not s.is_empty() else null
	if c == null:
		return false
	var m: MediaItem = media_of(doc, c)
	var r: Array = Tracking.default_range(c, m.duration if m != null else 0.0)
	return set_range(doc, set_id, float(r[0]), float(r[1]), "Track range: the clip")


static func range_to_in_out(doc: Project, seq: Sequence, set_id: String) -> bool:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	var c: Clip = doc.clip_by_id(String(s.get("clip", ""))) if not s.is_empty() else null
	if c == null or seq.in_point < 0.0 or seq.out_point < 0.0:
		return false
	var a: float = clampf(seq.in_point, c.start, c.end())
	var b: float = clampf(seq.out_point, c.start, c.end())
	if b <= a:
		return false
	return set_range(doc, set_id, c.source_time(a), c.source_time(b), "Track range: In to Out")


static func add_area(doc: Project, set_id: String, kind: String, mt: float, pts: PackedVector2Array, leave_out: bool) -> String:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	if s.is_empty() or pts.size() < 3:
		return ""
	var out: Dictionary = s.duplicate(true)
	var aid: String = Tracking.new_area_id(out)
	(out["areas"] as Array).append(Tracking.make_area(aid, kind, mt, pts, leave_out))
	return aid if write(doc, set_id, out, "Leave out an area" if leave_out else "Draw a track area") else ""


static func area_index(s: Dictionary, aid: String) -> int:
	var areas: Array = s.get("areas", [])
	for i: int in areas.size():
		if String((areas[i] as Dictionary).get("id", "")) == aid:
			return i
	return -1


static func with_area(s: Dictionary, area: Dictionary) -> Dictionary:
	var out: Dictionary = s.duplicate(true)
	var i: int = area_index(out, String(area.get("id", "")))
	if i >= 0:
		(out["areas"] as Array)[i] = area
	return out


static func remove_area(doc: Project, set_id: String, aid: String) -> bool:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	var i: int = area_index(s, aid)
	if i < 0:
		return false
	var out: Dictionary = s.duplicate(true)
	(out["areas"] as Array).remove_at(i)
	return write(doc, set_id, out, "Remove track area")


static func toggle_leave_out(doc: Project, set_id: String, aid: String) -> bool:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	var i: int = area_index(s, aid)
	if i < 0:
		return false
	var out: Dictionary = s.duplicate(true)
	var a: Dictionary = (out["areas"] as Array)[i]
	a["leave_out"] = not bool(a.get("leave_out", false))
	return write(doc, set_id, out, "Leave out an area" if bool(a["leave_out"]) else "Track inside an area")


static func key_area(doc: Project, set_id: String, aid: String, mt: float) -> bool:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	var i: int = area_index(s, aid)
	if i < 0:
		return false
	var a: Dictionary = (s["areas"] as Array)[i]
	var pts: PackedVector2Array = Tracking.area_points_at(a, mt)
	var keyed: Dictionary = Tracking.with_area_points(a, mt, pts, true)
	keyed["keyed"] = true
	return write(doc, set_id, with_area(s, keyed), "Key the track area")


static func half_area(doc: Project, set_id: String, side: String, mt: float) -> String:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	if s.is_empty():
		return ""
	var w: float = float((s["size"] as Array)[0])
	var h: float = float((s["size"] as Array)[1])
	var r: Rect2 = Rect2(0.0, 0.0, w * 0.5, h) if side == "left" else Rect2(w * 0.5, 0.0, w * 0.5, h)
	var out: Dictionary = s.duplicate(true)
	var kept: Array = []
	for a: Variant in out["areas"]:
		if bool((a as Dictionary).get("leave_out", false)):
			kept.append(a)
	out["areas"] = kept
	var aid: String = Tracking.new_area_id(out)
	(out["areas"] as Array).append(Tracking.make_area(aid, Tracking.KIND_BOX, mt, Tracking.box_points(r), false))
	return aid if write(doc, set_id, out, "Track the left half" if side == "left" else "Track the right half") else ""


static func add_tracker(doc: Project, set_id: String, mt: float) -> String:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	if s.is_empty() or (s["trackers"] as Array).size() >= 2:
		return ""
	var w: float = float((s["size"] as Array)[0])
	var h: float = float((s["size"] as Array)[1])
	var tid: String = "t2" if Tracking.tracker_index(s, "t2") < 0 else "t1"
	var out: Dictionary = s.duplicate(true)
	(out["trackers"] as Array).append(Tracking.make_tracker(tid, "Tracker " + tid.substr(1), mt, Vector2(w * 0.6, h * 0.5)))
	return tid if write(doc, set_id, out, "Add a second tracker") else ""


static func move_tracker(doc: Project, set_id: String, tid: String, mt: float, p: Vector2, live: bool) -> bool:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	var tr: Dictionary = Tracking.tracker_by_id(s, tid)
	if tr.is_empty():
		return false
	var out: Dictionary = Tracking.with_tracker(s, Tracking.with_hand(tr, mt, float(s.get("fps", 30.0)), p))
	if live:
		write_live(doc, set_id, out, "Move tracker")
		return true
	return write(doc, set_id, out, "Move tracker")


static func set_stop_below(doc: Project, set_id: String, v: float) -> bool:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	if s.is_empty():
		return false
	var out: Dictionary = s.duplicate(true)
	out["stop_below"] = clampf(v, 0.3, 0.99)
	return write(doc, set_id, out, "Tracker: stop below match")


static func clear_tracking(doc: Project, set_id: String) -> bool:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	if s.is_empty():
		return false
	var out: Dictionary = s.duplicate(true)
	var trs: Array = []
	for t: Variant in out["trackers"]:
		var tr: Dictionary = (t as Dictionary).duplicate(true)
		var p: Dictionary = Tracking.position_at(tr, float((tr.get("at", [0.0]) as Array)[0]), float(s.get("fps", 30.0)))
		var at: Array = tr.get("at", [0.0, 0.0, 0.0])
		tr["at"] = [float(at[0]), (p["p"] as Vector2).x, (p["p"] as Vector2).y]
		tr["data"] = {}
		tr["rev"] = ""
		trs.append(tr)
	out["trackers"] = trs
	return write(doc, set_id, out, "Clear tracked frames")


static func tracker_ids(s: Dictionary) -> Array:
	var ids: Array = []
	for t: Variant in s.get("trackers", []):
		ids.append(String((t as Dictionary).get("id", "")))
	return ids


static func link_src(doc: Project, seq: Sequence, set_id: String, owner: Clip) -> Dictionary:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	var tracked: Clip = doc.clip_by_id(String(s.get("clip", "")))
	if tracked == null:
		return {}
	var at: float = clampf(seq.playhead, tracked.start, maxf(tracked.start, tracked.end() - 0.000001))
	return {"kind": TrackingEval.KIND, "set": set_id, "trackers": tracker_ids(s), "footage": tracked.id, "owner": owner.id if owner != null else "", "t0": tracked.source_time(at), "clip": "", "path": ""}


static func _driven(src: Dictionary, out: String, axis: int, blend: String, name: String) -> Dictionary:
	var layer: Dictionary = AnimProp.new_driven_layer()
	var s: Dictionary = src.duplicate(true)
	s["out"] = out
	layer["src"] = s
	layer["axis"] = axis
	layer["blend"] = blend
	layer["name"] = name
	layer[LINK_KEY] = String(src.get("set", ""))
	return layer


static func _without_links(p: Dictionary, set_id: String) -> Dictionary:
	if not AnimProp.is_animated(p):
		return p.duplicate(true)
	var out: Dictionary = p.duplicate(true)
	var keep: Array = []
	for l: Variant in out.get("layers", []):
		if (l as Dictionary).has(LINK_KEY) and (set_id.is_empty() or String((l as Dictionary)[LINK_KEY]) == set_id):
			continue
		keep.append(l)
	out["layers"] = keep
	return AnimProp.simplify(out)


static func attach_layer(doc: Project, seq: Sequence, set_id: String, target: Clip, follow_all: bool) -> bool:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	if s.is_empty() or target == null or target.id == String(s.get("clip", "")):
		return false
	var src: Dictionary = link_src(doc, seq, set_id, target)
	if src.is_empty():
		return false
	var at: float = clampf(seq.playhead, target.start, maxf(target.start, target.end() - 0.000001))
	var tf: Dictionary = TrackingEval.world_tf(target, seq, at, seq.fps)
	var base: Vector2 = Vector2(float(seq.width), float(seq.height)) * 0.5 + (tf["pos"] as Vector2)
	src["base"] = [base.x, base.y]
	var two: bool = (s["trackers"] as Array).size() >= 2 and follow_all
	var cmds: Array[Command] = []
	var pos: Dictionary = _without_links(target.get_param("transform.pos"), set_id)
	pos = AnimProp.add_layer(pos, _driven(src, "x", 0, "add", "Tracker: across"))
	pos = AnimProp.add_layer(pos, _driven(src, "y", 1, "add", "Tracker: down"))
	cmds.append(_param_cmd(seq, target, "transform.pos", pos, "Attach to tracker"))
	if two:
		var rot: Dictionary = AnimProp.add_layer(_without_links(target.get_param("transform.rotation"), set_id), _driven(src, "angle", -1, "add", "Tracker: turn"))
		cmds.append(_param_cmd(seq, target, "transform.rotation", rot, "Attach to tracker"))
		var sc: Dictionary = AnimProp.add_layer(_without_links(target.get_param("transform.scale"), set_id), _driven(src, "scale", -1, "multiply", "Tracker: size"))
		cmds.append(_param_cmd(seq, target, "transform.scale", sc, "Attach to tracker"))
	return Verbs.run(doc, "Attach to tracker", cmds)


static func _param_cmd(seq: Sequence, c: Clip, path: String, p: Dictionary, label: String) -> Command:
	var cmd: Command = ClipCmds.SetClipParam.new(seq.id, c.id, path, p)
	cmd.label = label
	return cmd


static func effect_points(c: Clip) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null:
		return out
	var reg: Object = load("res://engine/effect_registry.gd").call("shared")
	var handles: GDScript = load("res://modules/core_panels/effect_handles_ui.gd")
	for e: Dictionary in c.effects:
		var def: Dictionary = reg.call("get_def", String(e.get("id", ""))) if reg != null else {}
		for p: Variant in def.get("params", []):
			var pd: Dictionary = p
			if String(pd.get("type", "")) != "vec2":
				continue
			if not bool(handles.call("_is_place", pd)):
				continue
			var name: String = String(def.get("name", def.get("label", e.get("id", ""))))
			out.append({"uid": String(e.get("uid", "")), "key": String(pd.get("key", "")), "label": name + ": " + String(pd.get("label", pd.get("key", "")))})
	return out


static func attach_effect_point(doc: Project, seq: Sequence, set_id: String, target: Clip, uid: String, key: String) -> bool:
	if target == null:
		return false
	var src: Dictionary = link_src(doc, seq, set_id, target)
	if src.is_empty():
		return false
	var path: String = "effects." + uid + "." + key
	var p: Dictionary = target.get_param(path)
	if p.is_empty():
		return false
	var at: float = clampf(seq.playhead, target.start, maxf(target.start, target.end() - 0.000001))
	var uv: Vector2 = AnimProp.evaluate_vec2(p, target.param_time(path, at - target.start), target.duration, seq.fps)
	var tf: Dictionary = TrackingEval.world_tf(target, seq, at, seq.fps)
	var lp: Vector2 = TrackingEval.layer_size(doc, target, seq)
	var base: Vector2 = TrackingEval.media_to_seq(tf, lp, Vector2(float(seq.width), float(seq.height)), uv * lp)
	src["base"] = [base.x, base.y]
	var out: Dictionary = _without_links(p, set_id)
	out = AnimProp.add_layer(out, _driven(src, "ux", 0, "add", "Tracker: across"))
	out = AnimProp.add_layer(out, _driven(src, "uy", 1, "add", "Tracker: down"))
	return Verbs.run(doc, "Attach effect point to tracker", [_param_cmd(seq, target, path, out, "Attach effect point to tracker")] as Array[Command])


static func attach_mask(doc: Project, seq: Sequence, set_id: String, target: Clip, mask_id: String) -> bool:
	if target == null:
		return false
	var src: Dictionary = link_src(doc, seq, set_id, target)
	if src.is_empty():
		return false
	var masks: Array[Dictionary] = target.masks.duplicate(true)
	var found: bool = false
	for m: Dictionary in masks:
		if String(m.get("id", "")) == mask_id:
			m[TRACK_KEY] = {"set": set_id, "trackers": src["trackers"], "footage": src["footage"], "t0": src["t0"]}
			found = true
	if not found:
		return false
	return Verbs.run(doc, "Attach mask to tracker", [ClipCmds.SetClipField.new(seq.id, target.id, "masks", masks)] as Array[Command])


static func _linked(p: Variant, set_id: String) -> bool:
	if not (p is Dictionary) or not AnimProp.is_animated(p):
		return false
	for l: Variant in (p as Dictionary).get("layers", []):
		if l is Dictionary and String((l as Dictionary).get(LINK_KEY, "")) == set_id:
			return true
	return false


static func links(doc: Project, set_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null:
		return out
	var st: Dictionary = Tracking.set_by_id(doc, set_id)
	var home: Sequence = doc.sequence_of_clip(String(st.get("clip", ""))) if not st.is_empty() else null
	for s: Sequence in doc.sequences:
		if home != null and s != home:
			continue
		for tr: Variant in s.all_tracks():
			for cv: Variant in (tr as Object).get("clips"):
				var c: Clip = cv
				for key: String in ["pos", "rotation", "scale"]:
					if _linked(c.transform.get(key), set_id):
						out.append({"kind": "layer", "seq": s.id, "clip": c.id, "path": "transform." + key, "label": c.label})
				for e: Dictionary in c.effects:
					var params: Dictionary = e.get("params", {}) if e.get("params") is Dictionary else {}
					for pk: Variant in params.keys():
						if _linked(params[pk], set_id):
							out.append({"kind": "effect", "seq": s.id, "clip": c.id, "path": "effects.%s.%s" % [String(e.get("uid", "")), String(pk)], "label": c.label})
				for m: Dictionary in c.masks:
					var tk: Variant = m.get(TRACK_KEY)
					if tk is Dictionary and String((tk as Dictionary).get("set", "")) == set_id:
						out.append({"kind": "mask", "seq": s.id, "clip": c.id, "mask": String(m.get("id", "")), "label": c.label})
				var stb: Variant = c.props.get(STAB_KEY)
				if stb is Dictionary and String((stb as Dictionary).get("set", "")) == set_id:
					out.append({"kind": "stabilise", "seq": s.id, "clip": c.id, "label": c.label})
	return out


static func _detach_cmd(doc: Project, link: Dictionary) -> Command:
	var s: Sequence = doc.sequence_by_id(String(link.get("seq", "")))
	var c: Clip = s.clip_by_id(String(link.get("clip", ""))) if s != null else null
	if c == null:
		return null
	var kind: String = String(link.get("kind", ""))
	if kind == "mask":
		var masks: Array[Dictionary] = c.masks.duplicate(true)
		for m: Dictionary in masks:
			if String(m.get("id", "")) == String(link.get("mask", "")):
				m.erase(TRACK_KEY)
		return ClipCmds.SetClipField.new(s.id, c.id, "masks", masks)
	if kind == "stabilise":
		var props: Dictionary = c.props.duplicate(true)
		props.erase(STAB_KEY)
		return ClipCmds.SetClipField.new(s.id, c.id, "props", props)
	var path: String = String(link.get("path", ""))
	var set_id: String = ""
	for l: Variant in c.get_param(path).get("layers", []):
		if (l as Dictionary).has(LINK_KEY):
			set_id = String((l as Dictionary)[LINK_KEY])
	return _param_cmd(s, c, path, _without_links(c.get_param(path), set_id), "Detach from tracker")


static func detach(doc: Project, link: Dictionary) -> bool:
	var cmds: Array[Command] = []
	for l: Dictionary in _same_clip_links(doc, link):
		var cmd: Command = _detach_cmd(doc, l)
		if cmd != null:
			cmds.append(cmd)
	return not cmds.is_empty() and Verbs.run(doc, "Detach from tracker", cmds)


static func _same_clip_links(doc: Project, link: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = [link]
	if String(link.get("kind", "")) != "layer":
		return out
	var c: Clip = doc.clip_by_id(String(link.get("clip", "")))
	if c == null:
		return out
	for path: String in ["transform.pos", "transform.rotation", "transform.scale"]:
		if path == String(link.get("path", "")):
			continue
		for l: Variant in c.get_param(path).get("layers", []) if AnimProp.is_animated(c.get_param(path)) else []:
			if (l as Dictionary).has(LINK_KEY):
				out.append({"kind": "layer", "seq": link["seq"], "clip": c.id, "path": path})
				break
	return out


static func bake(doc: Project, link: Dictionary) -> bool:
	var s: Sequence = doc.sequence_by_id(String(link.get("seq", "")))
	var c: Clip = s.clip_by_id(String(link.get("clip", ""))) if s != null else null
	if c == null:
		return false
	load(DRIVER).call("bind", doc)
	var kind: String = String(link.get("kind", ""))
	var cmds: Array[Command] = []
	if kind == "mask":
		var masks: Array[Dictionary] = c.masks.duplicate(true)
		for i: int in masks.size():
			if String(masks[i].get("id", "")) == String(link.get("mask", "")):
				masks[i] = baked_mask(doc, s, c, masks[i])
		cmds.append(ClipCmds.SetClipField.new(s.id, c.id, "masks", masks))
	elif kind == "stabilise":
		return false
	else:
		for l: Dictionary in _same_clip_links(doc, link):
			var path: String = String(l["path"])
			cmds.append(_param_cmd(s, c, path, AnimProp.bake(c.get_param(path), c.duration, s.fps, BAKE_TOLERANCE), "Bake tracker to keyframes"))
	return Verbs.run(doc, "Bake tracker to keyframes", cmds)


static func baked_mask(doc: Project, s: Sequence, c: Clip, m: Dictionary) -> Dictionary:
	var lp: Vector2 = TrackingEval.layer_size(doc, c, s)
	var aspect: float = lp.x / maxf(lp.y, 1.0)
	var n: int = int(ceil(c.duration * s.fps)) + 1
	var keys: Array = []
	for i: int in n:
		var local: float = minf(float(i) / s.fps, c.duration)
		var at: float = c.start + local
		var one: Array = TrackingEval.masks_at(doc, c, [m], at, s.fps)
		var mt: float = c.anim_time(local)
		var pts: PackedVector2Array = MaskPass.shape_points(one[0], mt, c.duration, s.fps, aspect)
		var flat: Array = []
		for p: Vector2 in pts:
			flat.append(p.x)
			flat.append(p.y)
		keys.append({"t": mt, "v": flat, "i": "linear"})
	var out: Dictionary = m.duplicate(true)
	out.erase(TRACK_KEY)
	for k: String in ["centre", "size", "offset", "scale"]:
		out.erase(k)
	out["rotation"] = 0.0
	out["kind"] = "polygon"
	var layer: Dictionary = {"type": "keys", "on": true, "weight": 1.0, "blend": "over", "loop": "once", "keys": keys}
	out["points"] = {"a": true, "base": keys[0]["v"] if not keys.is_empty() else [], "layers": [layer]}
	return out


static func stabilise(doc: Project, seq: Sequence, set_id: String, opts: Dictionary) -> bool:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	var c: Clip = doc.clip_by_id(String(s.get("clip", ""))) if not s.is_empty() else null
	if c == null:
		return false
	var at: float = clampf(seq.playhead, c.start, maxf(c.start, c.end() - 0.000001))
	var st: Dictionary = {
		"on": true,
		"set": set_id,
		"trackers": tracker_ids(s),
		"mode": String(opts.get("mode", "lock")),
		"smooth": float(opts.get("smooth", 1.0)),
		"position": bool(opts.get("position", true)),
		"rotation": bool(opts.get("rotation", true)),
		"scale": bool(opts.get("scale", true)),
		"edges": String(opts.get("edges", "crop")),
		"ref": float(opts.get("ref", c.source_time(at))),
	}
	var props: Dictionary = c.props.duplicate(true)
	props[STAB_KEY] = st
	var sq: Sequence = doc.sequence_of_clip(c.id)
	return Verbs.run(doc, "Stabilise", [ClipCmds.SetClipField.new(sq.id, c.id, "props", props)] as Array[Command])


static func stab_settings(doc: Project, set_id: String) -> Dictionary:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	var c: Clip = doc.clip_by_id(String(s.get("clip", ""))) if not s.is_empty() else null
	if c == null:
		return {}
	var st: Variant = c.props.get(STAB_KEY)
	if st is Dictionary and String((st as Dictionary).get("set", "")) == set_id:
		return st
	return {}


static func set_stab(doc: Project, set_id: String, changes: Dictionary, live: bool) -> bool:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	var c: Clip = doc.clip_by_id(String(s.get("clip", ""))) if not s.is_empty() else null
	if c == null:
		return false
	var st: Dictionary = stab_settings(doc, set_id)
	if st.is_empty():
		return false
	var next: Dictionary = st.duplicate(true)
	for k: Variant in changes.keys():
		next[k] = changes[k]
	var props: Dictionary = c.props.duplicate(true)
	props[STAB_KEY] = next
	var sq: Sequence = doc.sequence_of_clip(c.id)
	var cmd: Command = ClipCmds.SetClipField.new(sq.id, c.id, "props", props)
	cmd.label = "Stabilise settings"
	if live:
		doc.undo.live(cmd)
		return true
	return Verbs.run(doc, "Stabilise settings", [cmd] as Array[Command])


static func unstabilise(doc: Project, set_id: String) -> bool:
	var s: Dictionary = Tracking.set_by_id(doc, set_id)
	var c: Clip = doc.clip_by_id(String(s.get("clip", ""))) if not s.is_empty() else null
	if c == null or stab_settings(doc, set_id).is_empty():
		return false
	var props: Dictionary = c.props.duplicate(true)
	props.erase(STAB_KEY)
	var sq: Sequence = doc.sequence_of_clip(c.id)
	return Verbs.run(doc, "Remove stabilise", [ClipCmds.SetClipField.new(sq.id, c.id, "props", props)] as Array[Command])

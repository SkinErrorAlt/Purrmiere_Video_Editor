extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const Marker := preload("res://doc/marker.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Tags := preload("res://doc/marker_tags.gd")
const Censor := preload("res://doc/censor.gd")
const Command := preload("res://doc/commands/command.gd")
const Verbs := preload("res://doc/verbs.gd")
const APPLY_CMDS := "res://doc/commands/tag_apply_cmds.gd"
const SCOPE_AUDIO := "audio"
const SCOPE_VIDEO := "video"
const SCOPE_BOTH := "both"
const SCOPES: PackedStringArray = ["audio", "video", "both"]
const SCOPE_LABELS: PackedStringArray = ["Sound only", "Picture only", "Sound and picture"]
const PROP_KEY := "tag_apply"
const UID_PREFIX := "tagfx_"
const PRESET_PREFIX := "tagpre_"
const PRESET_KINDS: PackedStringArray = ["effect_stack", "effect", "transform", "audio_fx"]
const VALUES: Array = [
	["transform.opacity", "Opacity, 0 to 1", "picture", 1],
	["transform.rotation", "Rotation, degrees", "picture", 1],
	["transform.scale", "Scale, 1 is full size", "picture", 2],
	["transform.pos", "Position, x and y in pixels", "picture", 2],
	["audio.pan", "Pan, -1 left to 1 right", "sound", 1],
]
const VOLUME_PATH := "audio.volume"
const EPS := 0.0005
const BUILT_IN_SOUNDS: PackedStringArray = ["bleep", "low_bleep", "beep_pair"]

static var enabled: bool = true


static func key_for(name: String) -> String:
	return name.strip_edges().to_lower().validate_node_name().replace(" ", "_")


static func regions_of_tag(seq: Sequence, name: String) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for r: Dictionary in Tags.ranges(seq, PackedStringArray([name])):
		out.append(Vector2(float(r["from"]), float(r["to"])))
	return out


static func regions_of_markers(seq: Sequence, ids: PackedStringArray) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if seq == null:
		return out
	var list: Array[Vector2] = []
	for id: String in ids:
		var m: Marker = seq.marker_by_id(id)
		if m != null and m.duration > EPS:
			list.append(Vector2(m.time, m.end()))
	list.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for v: Vector2 in list:
		out.append(v)
	return out


static func merged(regions: PackedVector2Array) -> PackedVector2Array:
	var list: Array[Vector2] = []
	for v: Vector2 in regions:
		if v.y - v.x > EPS:
			list.append(Vector2(maxf(v.x, 0.0), v.y))
	list.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in list:
		var n: int = out.size()
		if n > 0 and v.x <= out[n - 1].y + EPS:
			out[n - 1] = Vector2(out[n - 1].x, maxf(out[n - 1].y, v.y))
		else:
			out.append(v)
	return out


static func in_scope(t: Track, c: Clip, scope: String) -> bool:
	if scope == SCOPE_AUDIO:
		return t.is_sound(c)
	if scope == SCOPE_VIDEO:
		return t.is_picture(c)
	return true


static func scope_tracks(seq: Sequence, scope: String, track_ids: PackedStringArray) -> Array[Track]:
	var out: Array[Track] = []
	if seq == null:
		return out
	for t: Track in seq.all_tracks():
		if t.locked:
			continue
		if not track_ids.is_empty() and not track_ids.has(t.id):
			continue
		if scope == SCOPE_AUDIO and not t.makes_sound():
			continue
		if scope == SCOPE_VIDEO and not t.makes_picture():
			continue
		out.append(t)
	return out


static func placed_by_tag(c: Clip) -> String:
	var v: Variant = c.props.get(PROP_KEY, "")
	return String(v)


static func pieces(seq: Sequence, regions: PackedVector2Array, scope: String, track_ids: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for t: Track in scope_tracks(seq, scope, track_ids):
		for v: Vector2 in regions:
			for c: Clip in t.clips_in_range(v.x, v.y):
				if c.start >= v.x - EPS and c.end() <= v.y + EPS and in_scope(t, c, scope) and placed_by_tag(c).is_empty() and not out.has(c.id):
					out.append(c.id)
	return out


static func db_to_gain(db: float) -> float:
	return pow(10.0, db / 20.0)


static func sound_media_id(doc: Project, sound: String) -> String:
	if doc == null:
		return ""
	if not BUILT_IN_SOUNDS.has(sound):
		var m: MediaItem = doc.media_by_id(sound)
		return m.id if m != null else ""
	var path: String = Censor.builtin_path(sound)
	if path.is_empty():
		return ""
	for item: MediaItem in doc.media:
		if item.path == path:
			return item.id
	return ""


static func sound_media_dict(doc: Project, sound: String) -> Dictionary:
	var path: String = Censor.builtin_path(sound)
	if path.is_empty():
		return {}
	var length: float = Censor.wav_length(path)
	var spec: Dictionary = Censor.SOUNDS.get(sound, {})
	return {"id": doc.mint_id("m"), "kind": "audio", "label": String(spec.get("label", sound)), "path": path, "probed": true, "duration": length if length > 0.0 else float(spec.get("length", 1.0)), "has_audio": true, "audio_only": true}


static func apply(doc: Project, seq: Sequence, regions: PackedVector2Array, key: String, scope: String, track_ids: PackedStringArray, ops: Dictionary, label: String = "") -> Dictionary:
	var out: Dictionary = {"ok": false, "cuts": 0, "reused": 0, "pieces": PackedStringArray(), "placed": PackedStringArray()}
	if doc == null or seq == null or regions.is_empty() or ops.is_empty():
		return out
	var Cmds: GDScript = load(APPLY_CMDS)
	var cmd: Command = Cmds.new(seq.id, regions, key, scope, track_ids, ops)
	var arr: Array[Command] = [cmd]
	if not Verbs.run(doc, label if not label.is_empty() else "Apply to " + str((cmd.get("regions") as PackedVector2Array).size()) + " regions", arr):
		return out
	out["ok"] = true
	out["cuts"] = int(cmd.get("cuts"))
	out["reused"] = int(cmd.get("reused"))
	out["pieces"] = cmd.get("touched")
	out["placed"] = cmd.get("placed")
	return out


static func apply_to_tag(doc: Project, seq: Sequence, name: String, scope: String, track_ids: PackedStringArray, ops: Dictionary) -> Dictionary:
	return apply(doc, seq, regions_of_tag(seq, name), key_for(name), scope, track_ids, ops, "Apply to every " + name + " tag")


static func value_of(path: String, text: String) -> Variant:
	var parts: PackedStringArray = text.replace(";", ",").split(",", false)
	var nums: Array[float] = []
	for p: String in parts:
		if not p.strip_edges().is_valid_float():
			return null
		nums.append(p.strip_edges().to_float())
	if nums.is_empty():
		return null
	var width: int = 1
	for v: Array in VALUES:
		if String(v[0]) == path:
			width = int(v[3])
	if width == 2:
		return [nums[0], nums[1] if nums.size() > 1 else nums[0]]
	return nums[0]


static func preset_scope(preset: Dictionary) -> String:
	return SCOPE_AUDIO if String(preset.get("kind", "")) == "audio_fx" else SCOPE_VIDEO


static func preset_ok(preset: Dictionary) -> bool:
	return PRESET_KINDS.has(String(preset.get("kind", "")))

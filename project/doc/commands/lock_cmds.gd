extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const Command := preload("res://doc/commands/command.gd")
const TrackCmds := preload("res://doc/commands/track_cmds.gd")
const EffectCmds := preload("res://doc/commands/effect_cmds.gd")
const ViewMap := preload("res://doc/view_map.gd")
const TrackGuard := preload("res://doc/track_guard.gd")
const MAP_KEY := "view_audio"

static var last_stripped: int = 0


static func files_on(t: Track) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if t == null:
		return out
	for c: Clip in t.clips:
		if not c.media_id.is_empty() and not out.has(c.media_id):
			out.append(c.media_id)
	return out


static func label_for(kind: String) -> String:
	return "Lock kind: " + TrackGuard.kind_name(kind)


static func commands_for(s: Sequence, t: Track, kind: String, files: PackedStringArray) -> Array[Command]:
	var cmds: Array[Command] = []
	if s == null or t == null:
		return cmds
	var k: String = kind if TrackGuard.KINDS.has(kind) else ""
	if t.lock_kind != k:
		cmds.append(TrackCmds.SetTrackField.new(s.id, t.id, "lock_kind", k))
	if k == TrackGuard.FILES and t.lock_files != files:
		cmds.append(TrackCmds.SetTrackField.new(s.id, t.id, "lock_files", files))
	if k == TrackGuard.CUT or k == TrackGuard.KEEP:
		cmds.append_array(strip_commands(s, t))
	return cmds


static func set_lock(doc: Project, s: Sequence, track_id: String, kind: String, files: PackedStringArray = PackedStringArray()) -> bool:
	last_stripped = 0
	if doc == null or s == null:
		return false
	var t: Track = s.track_by_id(track_id)
	var cmds: Array[Command] = commands_for(s, t, kind, files)
	if cmds.is_empty():
		return false
	var stripped: int = 0
	for c: Command in cmds:
		if c is EffectCmds.SetEffectParam:
			stripped += 1
	var tx: RefCounted = doc.undo.begin(label_for(kind))
	for c2: Command in cmds:
		tx.call("apply", c2)
	if not bool(tx.call("commit")):
		return false
	last_stripped = stripped
	if stripped > 0:
		TrackGuard.say(t.shown_label() + " now plays under every Pair View view")
	return true


static func strip_commands(s: Sequence, t: Track) -> Array[Command]:
	var cmds: Array[Command] = []
	var drop: Dictionary = {t.id: true}
	for c: Clip in t.clips:
		drop[c.id] = true
	for tr: Track in s.all_tracks():
		for c2: Clip in tr.clips:
			for e: Dictionary in c2.effects:
				if String(e.get("id", "")) != ViewMap.PAIR_VIEW_ID:
					continue
				var map: Dictionary = ViewMap.of(e)
				if map.is_empty():
					continue
				var fixed: Dictionary = map.duplicate(true)
				fixed["views"] = strip(map.get("views", []), drop)
				if JSON.stringify(fixed) == JSON.stringify(map):
					continue
				cmds.append(EffectCmds.SetEffectParam.new(s.id, c2.id, String(e.get("uid", "")), MAP_KEY, JSON.stringify(fixed), -1.0))
	return cmds


static func strip(v: Variant, drop: Dictionary) -> Variant:
	if v is Array:
		var out: Array = []
		for x: Variant in v:
			if x is String and drop.has(String(x)):
				continue
			out.append(strip(x, drop))
		return out
	if v is Dictionary:
		var out2: Dictionary = {}
		var d: Dictionary = v
		for k: Variant in d.keys():
			if k is String and drop.has(String(k)):
				continue
			out2[k] = strip(d[k], drop)
		return out2
	return v

extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const StreamOrdinals := preload("res://doc/stream_ordinals.gd")
const Tags := preload("res://doc/marker_tags.gd")

const VIDEO := 1
const AUDIO := 2
const SFX := 4
const MUSIC := 8
const VOICE := 16
const TITLES := 32
const IMAGES := 64
const SHAPES := 128
const ADJUST := 256
const NESTS := 512
const KINDS: Array = [
	["video", VIDEO, "Video"],
	["audio", AUDIO, "Audio, every sound clip"],
	["sfx", SFX, "Sound effects"],
	["music", MUSIC, "Music"],
	["voice", VOICE, "Voice"],
	["titles", TITLES, "Titles and subtitles"],
	["images", IMAGES, "Images"],
	["shapes", SHAPES, "Shapes"],
	["adjust", ADJUST, "Adjustment layers"],
	["nests", NESTS, "Nests"],
]
const ROLE_SFX := "sfx"
const ROLE_MUSIC := "music"
const ROLE_VOICE := "voice"
const ROLE_OTHER := "other"
const ROLES: PackedStringArray = [ROLE_SFX, ROLE_MUSIC, ROLE_VOICE, ROLE_OTHER]
const ROLE_NAMES: Dictionary = {"sfx": "Sound effect", "music": "Music", "voice": "Voice", "other": "Other sound"}
const SFX_MAX_SECONDS := 15.0
const MUSIC_MIN_SECONDS := 60.0
const SFX_WORDS: PackedStringArray = ["sfx", "fx", "foley", "whoosh", "swoosh", "impact", "boom", "ding", "effect", "effects"]
const MUSIC_WORDS: PackedStringArray = ["music", "song", "ost", "soundtrack", "bgm", "theme", "instrumental", "remix", "beat", "score"]
const VOICE_WORDS: PackedStringArray = ["voice", "vo", "voiceover", "dialogue", "dialog", "narration", "narrator", "mic", "microphone", "discord", "speech", "commentary", "podcast"]
const K_ON := "on"
const K_KINDS := "kinds"
const K_COLOURS := "colours"
const K_TEXT := "text"
const K_TAGS := "tags"
const K_DARKEN := "darken"
const EPS := 0.00001

static var use_roles: bool = true


class Matcher extends RefCounted:
	var kinds: int = 0
	var colours: Dictionary = {}
	var text: String = ""
	var tag_names: Dictionary = {}
	var spans: PackedVector2Array = PackedVector2Array()
	var use_tags: bool = false
	var active: bool = false


static func clean(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (v is Dictionary):
		return out
	var src: Dictionary = v
	var kinds: Array = []
	var raw_kinds: Variant = src.get(K_KINDS, [])
	if raw_kinds is Array or raw_kinds is PackedStringArray:
		for k: Variant in raw_kinds:
			var ks: String = str(k)
			if kind_bit(ks) != 0 and not kinds.has(ks):
				kinds.append(ks)
	var colours: Array = []
	var raw_cols: Variant = src.get(K_COLOURS, [])
	if raw_cols is Array:
		for c: Variant in raw_cols:
			var ci: int = int(c)
			if ci >= -1 and not colours.has(ci):
				colours.append(ci)
	var tags: Array = []
	var raw_tags: Variant = src.get(K_TAGS, [])
	if raw_tags is Array or raw_tags is PackedStringArray:
		for t: Variant in raw_tags:
			var ts: String = str(t).strip_edges()
			if not ts.is_empty() and not tags.has(ts):
				tags.append(ts)
	var text: String = str(src.get(K_TEXT, "")).strip_edges()
	if not kinds.is_empty():
		out[K_KINDS] = kinds
	if not colours.is_empty():
		out[K_COLOURS] = colours
	if not tags.is_empty():
		out[K_TAGS] = tags
	if not text.is_empty():
		out[K_TEXT] = text
	if not kinds.is_empty() or not colours.is_empty() or not tags.is_empty() or not text.is_empty():
		out[K_ON] = bool(src.get(K_ON, true))
	if bool(src.get(K_DARKEN, false)):
		out[K_DARKEN] = true
	return out


static func has_rules(view: Dictionary) -> bool:
	return view.has(K_KINDS) or view.has(K_COLOURS) or view.has(K_TAGS) or view.has(K_TEXT)


static func is_active(view: Dictionary) -> bool:
	return has_rules(view) and bool(view.get(K_ON, true))


static func darken_on(view: Dictionary) -> bool:
	return bool(view.get(K_DARKEN, false))


static func with(view: Dictionary, key: String, value: Variant) -> Dictionary:
	var next: Dictionary = view.duplicate(true)
	if value == null:
		next.erase(key)
	else:
		next[key] = value
	if key != K_ON and key != K_DARKEN and not has_rules(view):
		next[K_ON] = true
	return clean(next)


static func toggled_in(view: Dictionary, key: String, value: Variant) -> Dictionary:
	var list: Array = (view.get(key, []) as Array).duplicate() if view.get(key, []) is Array else []
	if list.has(value):
		list.erase(value)
	else:
		list.append(value)
	return with(view, key, list if not list.is_empty() else null)


static func cleared_rules(view: Dictionary) -> Dictionary:
	var next: Dictionary = {}
	if darken_on(view):
		next[K_DARKEN] = true
	return next


static func kind_bit(kind: String) -> int:
	for e: Array in KINDS:
		if String(e[0]) == kind:
			return int(e[1])
	return 0


static func kind_label(kind: String) -> String:
	for e: Array in KINDS:
		if String(e[0]) == kind:
			return String(e[2])
	return kind


static func role_bit(role: String) -> int:
	if role == ROLE_SFX:
		return SFX
	if role == ROLE_MUSIC:
		return MUSIC
	if role == ROLE_VOICE:
		return VOICE
	return 0


static func _words(text: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var cur: String = ""
	for ch: String in text.to_lower():
		var code: int = ch.unicode_at(0)
		var keep: bool = (code >= 97 and code <= 122) or (code >= 48 and code <= 57)
		if keep:
			cur += ch
		elif not cur.is_empty():
			out.append(cur)
			cur = ""
	if not cur.is_empty():
		out.append(cur)
	return out


static func role_in_text(text: String) -> String:
	if text.is_empty():
		return ""
	var words: PackedStringArray = _words(text)
	var lower: String = text.to_lower()
	if lower.contains("sound effect"):
		return ROLE_SFX
	for w: String in words:
		if VOICE_WORDS.has(w):
			return ROLE_VOICE
	for w: String in words:
		if MUSIC_WORDS.has(w):
			return ROLE_MUSIC
	for w: String in words:
		if SFX_WORDS.has(w):
			return ROLE_SFX
	return ""


static func stream_of(c: Clip) -> int:
	return int(float(c.audio.get("stream", 0.0)))


static func derived_role(item: MediaItem, t: Track, c: Clip) -> String:
	if not use_roles:
		return ROLE_OTHER
	if t != null and ROLES.has(t.role):
		return t.role
	var by_track: String = role_in_text(t.label) if t != null and not Track.is_classic_label(t.label) else ""
	if not by_track.is_empty():
		return by_track
	if item == null:
		return ROLE_OTHER
	if item.kind == "audio":
		var by_name: String = role_in_text(item.label + " " + item.path.get_file())
		if not by_name.is_empty():
			return by_name
		var length: float = item.duration if item.duration > 0.0 else c.duration
		if length <= SFX_MAX_SECONDS:
			return ROLE_SFX
		if length >= MUSIC_MIN_SECONDS:
			return ROLE_MUSIC
		return ROLE_OTHER
	var ordinal: int = stream_of(c)
	var stream_name: String = StreamOrdinals.given(item, ordinal)
	if stream_name.is_empty() and ordinal >= 0 and ordinal < item.audio_streams.size():
		stream_name = String(item.audio_streams[ordinal].get("title", "")).strip_edges()
	var by_stream: String = role_in_text(stream_name)
	return by_stream if not by_stream.is_empty() else ROLE_OTHER


static func role_of(item: MediaItem, t: Track, c: Clip) -> String:
	if ROLES.has(c.role):
		return c.role
	return derived_role(item, t, c)


static func kinds_of(item: MediaItem, t: Track, c: Clip, role: String = "") -> int:
	var m: int = 0
	var mk: String = item.kind if item != null else ""
	if c.is_nest() or mk == "sequence":
		m |= NESTS
	if t.is_sound(c):
		m |= AUDIO | role_bit(role if not role.is_empty() else role_of(item, t, c))
		return m
	if mk == "title" or (t.subtitle and mk != "video" and mk != "image"):
		m |= TITLES
	elif mk == "shape" or mk == "generator":
		m |= SHAPES
	elif mk == "adjust":
		m |= ADJUST
	elif mk == "image":
		m |= IMAGES
	elif mk == "video":
		m |= VIDEO
	return m


static func colour_of(item: MediaItem, c: Clip) -> int:
	if c.colour >= 0:
		return c.colour
	if item != null and item.colour >= 0:
		return item.colour
	return -1


static func compile(seq: Sequence, view: Dictionary) -> Matcher:
	var m: Matcher = Matcher.new()
	m.active = is_active(view)
	if not m.active:
		return m
	for k: Variant in view.get(K_KINDS, []):
		m.kinds |= kind_bit(str(k))
	for c: Variant in view.get(K_COLOURS, []):
		m.colours[int(c)] = true
	m.text = str(view.get(K_TEXT, "")).to_lower()
	var names: PackedStringArray = PackedStringArray()
	for t: Variant in view.get(K_TAGS, []):
		names.append(str(t))
		m.tag_names[str(t)] = true
	if not names.is_empty():
		m.use_tags = true
		m.spans = Tags.spans(seq, names)
	return m


static func in_spans(spans: PackedVector2Array, a: float, b: float) -> bool:
	var lo: int = 0
	var hi: int = spans.size()
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if spans[mid].y <= a + EPS:
			lo = mid + 1
		else:
			hi = mid
	return lo < spans.size() and spans[lo].x < b - EPS


static func wants_role(m: Matcher) -> bool:
	return (m.kinds & (SFX | MUSIC | VOICE)) != 0


static func matches(m: Matcher, item: MediaItem, t: Track, c: Clip, role: String = "") -> bool:
	if not m.active:
		return true
	if m.kinds != 0 and (kinds_of(item, t, c, role) & m.kinds) == 0:
		return false
	if not m.colours.is_empty() and not m.colours.has(colour_of(item, c)):
		return false
	if not m.text.is_empty():
		var hay: String = c.label.to_lower()
		if not hay.contains(m.text) and (item == null or not item.label.to_lower().contains(m.text)):
			return false
	if m.use_tags:
		var tagged: bool = in_spans(m.spans, c.start, c.end())
		if not tagged:
			for tg: String in c.tags:
				if m.tag_names.has(tg):
					tagged = true
					break
		if not tagged:
			return false
	return true


static func matching_ids(doc: Project, seq: Sequence, view: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if doc == null or seq == null:
		return out
	var m: Matcher = compile(seq, view)
	if not m.active:
		return out
	for t: Track in seq.all_tracks():
		for c: Clip in t.clips:
			if matches(m, doc.media_by_id(c.media_id), t, c):
				out.append(c.id)
	return out


static func colours_in_use(doc: Project, seq: Sequence) -> PackedInt32Array:
	var seen: Dictionary = {}
	if doc != null and seq != null:
		for t: Track in seq.all_tracks():
			for c: Clip in t.clips:
				seen[colour_of(doc.media_by_id(c.media_id), c)] = true
	var out: PackedInt32Array = PackedInt32Array()
	for k: Variant in seen.keys():
		out.append(int(k))
	out.sort()
	return out


static func counted(n: int, one: String, many: String) -> String:
	return str(n) + " " + (one if n == 1 else many)


static func summary(view: Dictionary) -> String:
	if not has_rules(view):
		return "No filter"
	var parts: PackedStringArray = PackedStringArray()
	for k: Variant in view.get(K_KINDS, []):
		parts.append(kind_label(str(k)))
	if view.has(K_COLOURS):
		parts.append(str((view[K_COLOURS] as Array).size()) + " colour labels")
	if view.has(K_TEXT):
		parts.append("name has \"" + str(view[K_TEXT]) + "\"")
	for t: Variant in view.get(K_TAGS, []):
		parts.append("tag " + str(t))
	return ", ".join(parts)

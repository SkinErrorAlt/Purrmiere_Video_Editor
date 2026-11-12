extends RefCounted
## Caption files in and out: SubRip (.srt), WebVTT (.vtt) and Advanced SubStation Alpha (.ass and .ssa).
## A cue is {start, duration, text} in seconds, text with "\n" between lines. Import places the cues as subtitle
## boxes on a text track (doc/subtitles.gd); export writes the boxes on the sequence's subtitle tracks.

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const Subtitles := preload("res://doc/subtitles.gd")

const EXTS: PackedStringArray = ["srt", "vtt", "ass", "ssa"]
const FILTERS: PackedStringArray = ["*.srt ; SubRip captions", "*.vtt ; WebVTT captions", "*.ass, *.ssa ; SubStation captions"]


static func is_caption_file(path: String) -> bool:
	return EXTS.has(path.get_extension().to_lower())


# Reading ---------------------------------------------------------------------------------------------------------

## Cues from a file's text, by its extension (or by looking, when the extension says nothing).
static func parse(text: String, ext: String = "") -> Array[Dictionary]:
	var t: String = text.trim_prefix(char(0xFEFF)).replace("\r\n", "\n").replace("\r", "\n")
	var e: String = ext.to_lower()
	if e == "vtt" or t.strip_edges().begins_with("WEBVTT"):
		return parse_vtt(t)
	if e == "ass" or e == "ssa" or t.contains("[Events]"):
		return parse_ass(t)
	return parse_srt(t)


## "01:02:03,456", "02:03.456", "1:02:03.45" (ASS centiseconds) -> seconds, or -1 when it isn't a time.
static func time_of(s: String) -> float:
	var t: String = s.strip_edges().replace(",", ".")
	var parts: PackedStringArray = t.split(":")
	if parts.size() < 2 or parts.size() > 3:
		return -1.0
	var total: float = 0.0
	for i: int in parts.size():
		var p: String = parts[i]
		if not p.is_valid_float():
			return -1.0
		total = total * 60.0 + float(p)
	return total


static func parse_srt(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for block: String in _blocks(text):
		var lines: PackedStringArray = block.split("\n")
		var at: int = -1
		for i: int in lines.size():
			if lines[i].contains("-->"):
				at = i
				break
		if at < 0:
			continue
		var span: Vector2 = _span(lines[at])
		if span.x < 0.0:
			continue
		var body: PackedStringArray = lines.slice(at + 1)
		_add(out, span, "\n".join(body))
	return out


static func parse_vtt(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for block: String in _blocks(text):
		var b: String = block.strip_edges()
		if b.begins_with("WEBVTT") or b.begins_with("NOTE") or b.begins_with("STYLE") or b.begins_with("REGION"):
			continue
		var lines: PackedStringArray = block.split("\n")
		var at: int = -1
		for i: int in lines.size():
			if lines[i].contains("-->"):
				at = i
				break
		if at < 0:
			continue
		var span: Vector2 = _span(lines[at])
		if span.x < 0.0:
			continue
		_add(out, span, "\n".join(lines.slice(at + 1)))
	return out


static func parse_ass(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var in_events: bool = false
	var fields: PackedStringArray = PackedStringArray(["Layer", "Start", "End", "Style", "Name", "MarginL", "MarginR", "MarginV", "Effect", "Text"])
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("["):
			in_events = line.to_lower() == "[events]"
			continue
		if not in_events:
			continue
		if line.begins_with("Format:"):
			fields = PackedStringArray()
			for f: String in line.substr(7).split(","):
				fields.append(f.strip_edges())
			continue
		if not line.begins_with("Dialogue:"):
			continue
		var values: PackedStringArray = line.substr(9).strip_edges().split(",", true, fields.size() - 1)
		var si: int = fields.find("Start")
		var ei: int = fields.find("End")
		var ti: int = fields.find("Text")
		if si < 0 or ei < 0 or ti < 0 or values.size() <= ti:
			continue
		var a: float = time_of(values[si])
		var b: float = time_of(values[ei])
		if a < 0.0 or b <= a:
			continue
		var words: String = values[ti]
		words = _strip_ass(words)
		_add(out, Vector2(a, b), words)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["start"]) < float(y["start"]))
	return out


static func _blocks(text: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var cur: PackedStringArray = PackedStringArray()
	for line: String in text.split("\n"):
		if line.strip_edges().is_empty():
			if not cur.is_empty():
				out.append("\n".join(cur))
				cur = PackedStringArray()
		else:
			cur.append(line)
	if not cur.is_empty():
		out.append("\n".join(cur))
	return out


static func _span(line: String) -> Vector2:
	var halves: PackedStringArray = line.split("-->")
	if halves.size() != 2:
		return Vector2(-1, -1)
	var a: float = time_of(halves[0])
	var right: String = halves[1].strip_edges()
	var cut: int = right.find(" ")
	var b: float = time_of(right.substr(0, cut) if cut > 0 else right)
	if a < 0.0 or b <= a:
		return Vector2(-1, -1)
	return Vector2(a, b)


static func _add(out: Array[Dictionary], span: Vector2, body: String) -> void:
	var words: String = _strip_tags(body).strip_edges()
	if words.is_empty():
		return
	out.append({"start": span.x, "duration": span.y - span.x, "text": words})


static func _strip_tags(s: String) -> String:
	var rx: RegEx = RegEx.create_from_string("<[^>]*>")
	var t: String = rx.sub(s, "", true)
	return t.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&nbsp;", " ")


static func _strip_ass(s: String) -> String:
	var rx: RegEx = RegEx.create_from_string("\\{[^}]*\\}")
	return rx.sub(s, "", true).replace("\\N", "\n").replace("\\n", "\n").replace("\\h", " ")


# Writing ---------------------------------------------------------------------------------------------------------

static func write(cues: Array[Dictionary], ext: String) -> String:
	match ext.to_lower():
		"vtt":
			return to_vtt(cues)
		"ass", "ssa":
			return to_ass(cues)
	return to_srt(cues)


static func stamp(t: float, sep: String, hours_always: bool = true) -> String:
	var ms: int = int(round(maxf(t, 0.0) * 1000.0))
	var h: int = ms / 3600000
	var m: int = (ms / 60000) % 60
	var s: int = (ms / 1000) % 60
	var f: int = ms % 1000
	if not hours_always and h == 0:
		return "%02d:%02d%s%03d" % [m, s, sep, f]
	return "%02d:%02d:%02d%s%03d" % [h, m, s, sep, f]


static func to_srt(cues: Array[Dictionary]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for i: int in cues.size():
		var c: Dictionary = cues[i]
		var a: float = float(c["start"])
		parts.append(str(i + 1) + "\n" + stamp(a, ",") + " --> " + stamp(a + float(c["duration"]), ",") + "\n" + String(c["text"]) + "\n")
	return "\n".join(parts)


static func to_vtt(cues: Array[Dictionary]) -> String:
	var parts: PackedStringArray = PackedStringArray(["WEBVTT\n"])
	for c: Dictionary in cues:
		var a: float = float(c["start"])
		var words: String = String(c["text"]).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
		parts.append(stamp(a, ".") + " --> " + stamp(a + float(c["duration"]), ".") + "\n" + words + "\n")
	return "\n".join(parts)


static func ass_stamp(t: float) -> String:
	var cs: int = int(round(maxf(t, 0.0) * 100.0))
	return "%d:%02d:%02d.%02d" % [cs / 360000, (cs / 6000) % 60, (cs / 100) % 60, cs % 100]


static func to_ass(cues: Array[Dictionary], width: int = 1920, height: int = 1080) -> String:
	var lines: PackedStringArray = PackedStringArray([
		"[Script Info]", "Title: Purrmiere captions", "ScriptType: v4.00+", "PlayResX: " + str(width), "PlayResY: " + str(height), "",
		"[V4+ Styles]",
		"Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding",
		"Style: Default,Arial,56,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,-1,0,0,0,100,100,0,0,1,3,2,2,60,60,60,1", "",
		"[Events]",
		"Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text",
	])
	for c: Dictionary in cues:
		var a: float = float(c["start"])
		var words: String = String(c["text"]).replace("\n", "\\N")
		lines.append("Dialogue: 0," + ass_stamp(a) + "," + ass_stamp(a + float(c["duration"])) + ",Default,,0,0,0,," + words)
	return "\n".join(lines) + "\n"


# The project -----------------------------------------------------------------------------------------------------

static func _plain(v: Variant) -> String:
	if v is Dictionary and AnimProp.is_animated(v):
		v = AnimProp.static_value(v)
	elif v is Dictionary and (v as Dictionary).has("v"):
		v = (v as Dictionary)["v"]
	return String(v) if v is String else ""


## The text boxes to export, in time order: the sequence's subtitle tracks, or every text clip when it has none.
## Times are from the sequence start, or from the in point when there is one and from_in is true.
static func cues_from(doc: Project, seq: Sequence, from_in: bool = true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null or seq == null:
		return out
	var tracks: Array[Track] = []
	for tr: Track in seq.video_tracks:
		if tr.subtitle:
			tracks.append(tr)
	if tracks.is_empty():
		tracks = seq.video_tracks.duplicate()
	var zero: float = seq.in_point if from_in and seq.in_point >= 0.0 else 0.0
	var end_at: float = seq.out_point if from_in and seq.out_point > zero else INF
	for tr2: Track in tracks:
		for c: Clip in tr2.clips:
			if not c.enabled or not Subtitles.is_text_clip(doc, c):
				continue
			var m: MediaItem = doc.media_by_id(c.media_id)
			var words: String = _plain(c.props.get("text", null))
			if words.is_empty() and m != null:
				words = _plain(m.props.get("text", ""))
			words = words.strip_edges()
			if words.is_empty():
				continue
			var a: float = maxf(c.start, zero)
			var b: float = minf(c.end(), end_at)
			if b <= a:
				continue
			out.append({"start": a - zero, "duration": b - a, "text": words})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["start"]) < float(y["start"]))
	return out


static func export_file(doc: Project, seq: Sequence, path: String) -> int:
	var cues: Array[Dictionary] = cues_from(doc, seq)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return -1
	f.store_string(write(cues, path.get_extension()))
	f.close()
	return cues.size()


## Places a caption file's cues as subtitle boxes starting at `at` (seconds on the sequence), one undo step.
## Returns the new box ids.
static func import_file(doc: Project, seq: Sequence, path: String, at: float = 0.0) -> PackedStringArray:
	if doc == null or seq == null or not FileAccess.file_exists(path):
		return PackedStringArray()
	var cues: Array[Dictionary] = parse(FileAccess.get_file_as_string(path), path.get_extension())
	return place(doc, seq, cues, at)


static func place(doc: Project, seq: Sequence, cues: Array[Dictionary], at: float = 0.0) -> PackedStringArray:
	if cues.is_empty():
		return PackedStringArray()
	var spans: Array[Dictionary] = []
	for c: Dictionary in cues:
		var d: float = clampf(float(c["duration"]), Subtitles.MIN_BOX_SECONDS, Subtitles.MAX_BOX_SECONDS)
		spans.append({"start": at + float(c["start"]), "duration": d, "text": String(c["text"])})
	return Subtitles.boxes_from_marks(doc, seq, spans, false, Subtitles.subtitle_style(), "auto", false)

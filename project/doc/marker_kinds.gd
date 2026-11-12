extends RefCounted

const Marker := preload("res://doc/marker.gd")
const Sequence := preload("res://doc/sequence.gd")
const DOES_TEXT := "text"
const DOES_CHAPTER := "chapter"
const DOES_CUT := "cut"
const DOES_SOUND := "sound"
const DOES_TASK := "task"
const DOES_LINK := "link"
const DOES_RANGE := "range"
const DOES_SPAN := "span"
const TASK_KINDS: PackedStringArray = ["todo", "warning"]
const LINK_STARTS: PackedStringArray = ["https://", "http://", "www."]
const ICONS: PackedStringArray = ["", "check", "warn", "error", "paw", "camera", "audio", "type", "link", "pin", "film", "sun", "moon", "marker"]
const ICON_LABELS: PackedStringArray = ["No icon", "Tick", "Warning", "Stop", "Paw", "Camera", "Sound", "Text", "Link", "Pin", "Film", "Sun", "Moon", "Marker"]

const REGISTRY: Dictionary = {
	"comment": {"does": ["text", "cut", "sound"], "shape": "pennant", "icon": "", "blurb": "A note. Becomes a text box, a cut point and a place for a scattered sound."},
	"chapter": {"does": ["chapter", "text", "cut", "sound"], "shape": "flag", "icon": "", "blurb": "Starts a chapter in exports that carry chapters."},
	"segment": {"does": ["text", "cut", "sound", "span"], "shape": "bar", "icon": "", "blurb": "Marks a part of the edit. With a length it is one span for clip cut."},
	"web": {"does": ["text", "cut", "link"], "shape": "pennant", "icon": "link", "blurb": "Holds a web address in its name or comment. Right click it to open the link."},
	"todo": {"does": ["task", "cut"], "shape": "pennant", "icon": "check", "blurb": "Something to come back to. Listed and stepped through with Go to the next to do."},
	"warning": {"does": ["task", "cut"], "shape": "diamond", "icon": "warn", "blurb": "A problem to look at. Stepped through with Go to the next to do."},
	"tag": {"does": ["range", "cut"], "shape": "bar", "icon": "", "blurb": "A named range for exporting and applying effects by tag."},
	"sync": {"does": ["text", "cut", "sound"], "shape": "dot", "icon": "", "blurb": "A sync point."},
}


static func entry(kind: String) -> Dictionary:
	return REGISTRY.get(kind, REGISTRY[Marker.DEFAULT_KIND])


static func does(kind: String, what: String) -> bool:
	return (entry(kind)["does"] as Array).has(what)


static func marker_does(m: Marker, what: String) -> bool:
	return m != null and does(m.kind, what)


static func makes_text(m: Marker) -> bool:
	return marker_does(m, DOES_TEXT)


static func makes_chapter(m: Marker) -> bool:
	return marker_does(m, DOES_CHAPTER)


static func cuts(m: Marker) -> bool:
	return marker_does(m, DOES_CUT)


static func scatters(m: Marker) -> bool:
	return marker_does(m, DOES_SOUND)


static func is_task(m: Marker) -> bool:
	return marker_does(m, DOES_TASK)


static func blurb(kind: String) -> String:
	return String(entry(kind)["blurb"])


static func shape_of(m: Marker) -> String:
	if m == null:
		return "pennant"
	if not m.shape.is_empty():
		return m.shape
	return String(entry(m.kind)["shape"])


static func icon_of(m: Marker) -> String:
	if m == null:
		return ""
	if not m.icon.is_empty():
		return "" if m.icon == "none" else m.icon
	return String(entry(m.kind)["icon"])


static func link_of(m: Marker) -> String:
	if m == null or not marker_does(m, DOES_LINK):
		return ""
	for text: String in [m.comment, m.label]:
		for word: String in text.split(" ", false):
			var w: String = word.strip_edges()
			for start: String in LINK_STARTS:
				if w.to_lower().begins_with(start):
					return w if not w.to_lower().begins_with("www.") else "https://" + w
	return ""


static func tasks(seq: Sequence) -> Array[Marker]:
	var out: Array[Marker] = []
	if seq == null:
		return out
	for m: Marker in seq.markers:
		if is_task(m):
			out.append(m)
	out.sort_custom(func(a: Marker, b: Marker) -> bool: return a.time < b.time)
	return out


static func next_task_time(seq: Sequence, t: float, dir: int) -> float:
	var best: float = -1.0
	for m: Marker in tasks(seq):
		if dir > 0 and m.time > t + 0.0005:
			return m.time
		if dir < 0 and m.time < t - 0.0005:
			best = m.time
	return best

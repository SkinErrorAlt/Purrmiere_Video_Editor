extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const ViewStreams := preload("res://doc/view_streams.gd")
const StreamLanes := preload("res://engine/stream_lanes.gd")
const Waves := preload("res://ui/timeline/timeline_wave.gd")
const PmText := preload("res://ui/kit/pm_text.gd")
const CACHE_MAX := 512
const TAG_MIN_PX := 44.0
const ANY_KEY := "stream_any"

static var _plans: Dictionary = {}
static var _sign: String = ""
static var stats: Dictionary = {"plans": 0, "hits": 0}


static func _sign_of(d: Project, s: Sequence) -> String:
	return str(d.get_instance_id()) + "|" + str(s.get_instance_id()) + "|" + str(d.serial) + "|" + Waves.heard_sync_sign()


static func spans(d: Project, s: Sequence, c: Clip) -> Variant:
	if d == null or s == null or c == null:
		return null
	var rec: Dictionary = Waves.heard_sources(d, s)
	var list: Array = rec["sources"]
	if list.is_empty():
		return null
	if not rec.has(ANY_KEY):
		rec[ANY_KEY] = StreamLanes.any_streams(list)
	if not bool(rec[ANY_KEY]):
		return null
	var sign: String = _sign_of(d, s)
	if sign != _sign:
		_sign = sign
		_plans = {}
	if _plans.has(c.id):
		stats["hits"] = int(stats["hits"]) + 1
		return _plans[c.id]
	var out: Variant = _build(d, s, c, Waves.family_sources(rec, c))
	if _plans.size() >= CACHE_MAX:
		_plans = {}
	_plans[c.id] = out
	return out


static func _build(d: Project, s: Sequence, c: Clip, fam: Array) -> Variant:
	var tr: Track = s.track_of(c.id)
	if tr == null or s.clip_by_id(c.id) != c:
		return null
	var sources: Array[Dictionary] = []
	for src: Variant in fam:
		var sd: Dictionary = src
		var v: Clip = sd["clip"]
		var e: Dictionary = v.effect_by_uid(String(sd["uid"]))
		if e.is_empty() or not bool(e.get("enabled", true)):
			continue
		sources.append({"clip": v, "entry": e, "map": sd["map"]})
	if not StreamLanes.governed_by_streams(sources, c, tr.id):
		return null
	stats["plans"] = int(stats["plans"]) + 1
	return StreamLanes.plan_spans(d, s, tr, c, sources)


static func draw_tags(ci: CanvasItem, d: Project, c: Clip, list: Array, clip_x0: float, pps: float, band: Rect2, font: Font, fs: int) -> void:
	if d == null or font == null or band.size.y < float(fs) + 4.0:
		return
	var item: MediaItem = d.media_by_id(c.media_id)
	var last: int = -2
	var last_end: float = -INF
	for sp: Variant in list:
		var sd: Dictionary = sp
		var st: int = int(sd.get("stream", -1))
		var t0: float = float(sd["t0"])
		var fresh: bool = st != last or absf(t0 - last_end) > 0.000001
		last = st
		last_end = float(sd["t1"])
		if not fresh:
			continue
		var x0: float = maxf(clip_x0 + (t0 - c.start) * pps, band.position.x)
		var x1: float = minf(clip_x0 + (float(sd["t1"]) - c.start) * pps, band.end.x)
		if x1 - x0 < TAG_MIN_PX:
			continue
		var text: String = ViewStreams.name_of(item, st)
		var w: float = minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8.0, x1 - x0 - 2.0)
		var box: Rect2 = Rect2(x0 + 2.0, band.position.y + 1.0, w, float(fs) + 3.0)
		ci.draw_rect(box, Color(Tk.c["bg_shell"], 0.72), true)
		PmText.draw(ci, font, box, text, fs, Tk.c["text"], HORIZONTAL_ALIGNMENT_LEFT, 4.0)

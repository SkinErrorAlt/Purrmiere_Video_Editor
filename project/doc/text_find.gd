extends RefCounted

const VERSION := 1
const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const MediaItem := preload("res://doc/media_item.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const DataText := preload("res://doc/data_text.gd")
const Verbs := preload("res://doc/verbs.gd")
const Command := preload("res://doc/commands/command.gd")
const ClipCmds := preload("res://doc/commands/clip_cmds.gd")
const OrganizerCmds := preload("res://doc/commands/organizer_cmds.gd")
const KIND := "title"
const TEXT_KEY := "text"
const TEXT_PATH := "props.text"
const SLOT_VALUE := "value"
const SLOT_BASE := "base"
const SLOT_KEY := "key"
const WHERE_CLIP := "clip"
const WHERE_MEDIA := "media"
const SNIPPET_CAP := 56
const REPLACE_LABEL := "Replace text"
const REPLACE_ONE_LABEL := "Replace text once"

static var plant_flat_keys: bool = false
static var plant_every: bool = false


static func word_char(code: int) -> bool:
	if code >= 48 and code <= 57:
		return true
	if code >= 65 and code <= 90:
		return true
	if code >= 97 and code <= 122:
		return true
	return code == 95 or code >= 128


static func _bounded(hay: String, at: int, n: int) -> bool:
	if at > 0 and word_char(hay.unicode_at(at - 1)):
		return false
	var after: int = at + n
	if after < hay.length() and word_char(hay.unicode_at(after)):
		return false
	return true


static func ranges(text: String, needle: String, case_sensitive: bool = false, whole_word: bool = false) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if text.is_empty() or needle.is_empty():
		return out
	var n: int = needle.length()
	if n > text.length():
		return out
	var at: int = text.find(needle) if case_sensitive else text.findn(needle)
	while at >= 0:
		var from: int = at + 1
		if not whole_word or _bounded(text, at, n):
			out.append(Vector2i(at, n))
			from = at + n
		at = text.find(needle, from) if case_sensitive else text.findn(needle, from)
	return out


static func has_match(text: String, needle: String, case_sensitive: bool = false, whole_word: bool = false) -> bool:
	if text.is_empty() or needle.is_empty():
		return false
	if whole_word:
		return not ranges(text, needle, case_sensitive, whole_word).is_empty()
	return (text.find(needle) if case_sensitive else text.findn(needle)) >= 0


static func cased(found: String, repl: String) -> String:
	if repl.is_empty() or found.is_empty():
		return repl
	var lower: String = found.to_lower()
	if found == found.to_upper() and found != lower and found.length() > 1:
		return repl.to_upper()
	var head: String = found.substr(0, 1)
	if head == head.to_upper() and head != head.to_lower():
		return repl.substr(0, 1).to_upper() + repl.substr(1)
	return repl


static func replaced(text: String, needle: String, repl: String, case_sensitive: bool = false, whole_word: bool = false) -> String:
	var rs: Array[Vector2i] = ranges(text, needle, case_sensitive, whole_word)
	if rs.is_empty():
		return text
	var out: String = ""
	var i: int = 0
	for r: Vector2i in rs:
		var found: String = text.substr(r.x, r.y)
		out += text.substr(i, r.x - i) + (repl if case_sensitive else cased(found, repl))
		i = r.x + r.y
	out += text.substr(i)
	return out


static func replaced_only(text: String, keep: Array[Vector2i], needle: String, repl: String, case_sensitive: bool = false) -> String:
	if keep.is_empty():
		return text
	var rs: Array[Vector2i] = keep.duplicate()
	rs.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var out: String = ""
	var i: int = 0
	for r: Vector2i in rs:
		if r.x < i or r.x + r.y > text.length():
			continue
		var found: String = text.substr(r.x, r.y)
		var same: bool = found == needle if case_sensitive else found.to_lower() == needle.to_lower()
		if not same:
			continue
		out += text.substr(i, r.x - i) + (repl if case_sensitive else cased(found, repl))
		i = r.x + r.y
	out += text.substr(i)
	return out


static func one(r: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [r]
	return out


static func inside(rs: Array[Vector2i], span: Vector2i) -> Array[Vector2i]:
	if span.x < 0:
		return rs
	var out: Array[Vector2i] = []
	for r: Vector2i in rs:
		if r.x >= span.x and r.x + r.y <= span.y:
			out.append(r)
	return out


static func within_of(opts: Dictionary) -> Dictionary:
	var w: Variant = opts.get("within", null)
	return w if w is Dictionary else {}


static func span_for(within: Dictionary, clip_id: String) -> Vector2i:
	var v: Variant = within.get(clip_id, Vector2i(-1, -1))
	return v if v is Vector2i else Vector2i(-1, -1)


static func _split_each(base: Dictionary, text: String, rs: Array[Vector2i], where: PackedStringArray, slot: String, key_t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: int in rs.size():
		var h: Dictionary = base.duplicate()
		var parts: PackedStringArray = where.duplicate()
		parts.append("match %d of %d" % [n + 1, rs.size()])
		h["title"] = marked(text, rs[n])
		h["detail"] = _detail(parts, text, slot, key_t, 1)
		h["ranges"] = one(rs[n])
		h["only"] = rs[n]
		h["nth"] = n
		out.append(h)
	return out


static func marked(text: String, r: Vector2i) -> String:
	var line_start: int = text.rfind("\n", r.x) + 1 if r.x > 0 else 0
	var line_end: int = text.find("\n", r.x + r.y)
	if line_end < 0:
		line_end = text.length()
	var before: String = text.substr(line_start, r.x - line_start)
	var after: String = text.substr(r.x + r.y, line_end - r.x - r.y)
	var room: int = maxi((SNIPPET_CAP - r.y) / 2, 8)
	if before.length() > room:
		before = "..." + before.substr(before.length() - room)
	if after.length() > room:
		after = after.substr(0, room) + "..."
	return (before + "[" + text.substr(r.x, r.y) + "]" + after).strip_edges()


static func snippet(text: String, at: int) -> String:
	var line_start: int = text.rfind("\n", at) + 1
	var line_end: int = text.find("\n", at)
	if line_end < 0:
		line_end = text.length()
	var line: String = text.substr(line_start, line_end - line_start).strip_edges()
	if line.length() > SNIPPET_CAP:
		line = line.substr(0, SNIPPET_CAP).strip_edges() + "..."
	if line.is_empty():
		line = "(blank line)"
	return line


static func prop_of(props: Dictionary) -> Dictionary:
	var v: Variant = props.get(TEXT_KEY, null)
	if v is String:
		return {"v": v}
	if v is Dictionary:
		return v
	return {}


static func slots(p: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if p.is_empty():
		return out
	if not AnimProp.is_animated(p):
		var v: Variant = p.get("v", null)
		if v is String:
			out.append({"slot": SLOT_VALUE, "t": 0.0, "text": String(v)})
		return out
	var ks: Array[Dictionary] = AnimProp.keys(p)
	if ks.is_empty():
		var b: Variant = p.get("base", null)
		if b is String:
			out.append({"slot": SLOT_BASE, "t": 0.0, "text": String(b)})
		return out
	for k: Dictionary in ks:
		var kv: Variant = k.get("v", null)
		if kv is String:
			out.append({"slot": SLOT_KEY, "t": float(k.get("t", 0.0)), "text": String(kv)})
	return out


static func every_string(p: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if p.is_empty():
		return out
	if not AnimProp.is_animated(p):
		return slots(p)
	var b: Variant = p.get("base", null)
	if b is String:
		out.append({"slot": SLOT_BASE, "t": 0.0, "text": String(b)})
	for k: Dictionary in AnimProp.keys(p):
		var kv: Variant = k.get("v", null)
		if kv is String:
			out.append({"slot": SLOT_KEY, "t": float(k.get("t", 0.0)), "text": String(kv)})
	return out


static func write_slot(p: Dictionary, slot: String, t: float, text: String) -> Dictionary:
	if p.is_empty():
		return {"v": text}
	if slot == SLOT_KEY:
		return AnimProp.set_key_fields(p, t, {"v": text})
	var out: Dictionary = p.duplicate(true)
	if slot == SLOT_BASE:
		out["base"] = text
	else:
		out["v"] = text
	return out


static func write_every(p: Dictionary, needle: String, repl: String, case_sensitive: bool = false, whole_word: bool = false) -> Dictionary:
	if p.is_empty():
		return p
	var out: Dictionary = p.duplicate(true)
	if not AnimProp.is_animated(out):
		if out.get("v") is String:
			out["v"] = replaced(String(out["v"]), needle, repl, case_sensitive, whole_word)
		return out
	if out.get("base") is String:
		out["base"] = replaced(String(out["base"]), needle, repl, case_sensitive, whole_word)
	if plant_flat_keys:
		return {"v": String(out.get("base", ""))}
	var li: int = AnimProp.keys_layer_index(out)
	if li < 0:
		return out
	for k: Variant in ((out["layers"] as Array)[li] as Dictionary).get("keys", []):
		var kd: Dictionary = k
		if kd.get("v") is String:
			kd["v"] = replaced(String(kd["v"]), needle, repl, case_sensitive, whole_word)
	return out


static func clip_name(doc: Project, c: Clip) -> String:
	if not c.label.is_empty():
		return c.label
	var m: MediaItem = doc.media_by_id(c.media_id) if doc != null else null
	if m != null and not m.label.is_empty():
		return m.label
	return c.id


static func slot_time(c: Clip, slot: String, key_t: float) -> float:
	if slot != SLOT_KEY:
		return c.start
	var span: float = maxf(c.duration, 0.0)
	return c.start + clampf(key_t, 0.0, span)


static func _detail(parts: PackedStringArray, text: String, slot: String, key_t: float, count: int) -> String:
	if slot == SLOT_KEY:
		parts.append("keyed text at %.2f s in" % key_t)
	elif slot == SLOT_BASE:
		parts.append("start value")
	if count > 1:
		parts.append("%d matches" % count)
	if DataText.has_tokens(text):
		parts.append("has {tokens}")
	return ", ".join(parts)


static func quick_skip(raw: Variant, needle: String, case_sensitive: bool, whole_word: bool) -> bool:
	if raw is String:
		return not has_match(String(raw), needle, case_sensitive, whole_word)
	if raw is Dictionary:
		var d: Dictionary = raw
		if bool(d.get("a", false)):
			return false
		var v: Variant = d.get("v", null)
		return not (v is String) or not has_match(String(v), needle, case_sensitive, whole_word)
	return true


static func clip_hits(doc: Project, s: Sequence, tr: Track, c: Clip, needle: String, opts: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var case_sensitive: bool = bool(opts.get("case", false))
	var whole_word: bool = bool(opts.get("word", false))
	var within: Dictionary = within_of(opts)
	if not within.is_empty() and not within.has(c.id):
		return out
	var span: Vector2i = span_for(within, c.id)
	if quick_skip(c.props.get(TEXT_KEY, null), needle, case_sensitive, whole_word):
		return out
	var p: Dictionary = prop_of(c.props)
	if p.is_empty():
		return out
	var cname: String = clip_name(doc, c)
	for sl: Dictionary in slots(p):
		var text: String = String(sl["text"])
		if not has_match(text, needle, case_sensitive, whole_word):
			continue
		var rs: Array[Vector2i] = inside(ranges(text, needle, case_sensitive, whole_word), span)
		if rs.is_empty():
			continue
		var slot: String = String(sl["slot"])
		var key_t: float = float(sl["t"])
		var where: PackedStringArray = PackedStringArray([cname])
		if tr != null:
			where.append(tr.label)
		if s != null:
			where.append("in " + s.label)
		var hit: Dictionary = {
			"kind": KIND,
			"title": snippet(text, rs[0].x),
			"detail": _detail(where.duplicate(), text, slot, key_t, rs.size()),
			"time": slot_time(c, slot, key_t),
			"clip_id": c.id,
			"media_id": c.media_id,
			"seq_id": s.id if s != null else "",
			"where": WHERE_CLIP,
			"slot": slot,
			"key_t": key_t,
			"text": text,
			"ranges": rs,
		}
		if span.x >= 0:
			hit["within"] = span
		if bool(opts.get("each", false)):
			out.append_array(_split_each(hit, text, rs, where, slot, key_t))
			continue
		out.append(hit)
	return out


static func _media_use(doc: Project, media_id: String) -> Dictionary:
	var uses: int = 0
	var first: Dictionary = {}
	for s: Sequence in doc.sequences:
		for tr: Track in s.all_tracks():
			for c: Clip in tr.clips:
				if c.media_id != media_id or not prop_of(c.props).is_empty():
					continue
				uses += 1
				if first.is_empty():
					first = {"seq_id": s.id, "clip_id": c.id, "time": c.start, "seq_label": s.label}
	first["uses"] = uses
	return first


static func media_hits(doc: Project, needle: String, opts: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null:
		return out
	var case_sensitive: bool = bool(opts.get("case", false))
	var whole_word: bool = bool(opts.get("word", false))
	var within: Dictionary = within_of(opts)
	for m: MediaItem in doc.media:
		if quick_skip(m.props.get(TEXT_KEY, null), needle, case_sensitive, whole_word):
			continue
		var p: Dictionary = prop_of(m.props)
		if p.is_empty():
			continue
		var span: Vector2i = Vector2i(-1, -1)
		if not within.is_empty():
			var user: String = _within_user(doc, within, m.id)
			if user.is_empty():
				continue
			span = span_for(within, user)
		var use: Dictionary = {}
		for sl: Dictionary in slots(p):
			var text: String = String(sl["text"])
			if not has_match(text, needle, case_sensitive, whole_word):
				continue
			var rs: Array[Vector2i] = inside(ranges(text, needle, case_sensitive, whole_word), span)
			if rs.is_empty():
				continue
			if use.is_empty():
				use = _media_use(doc, m.id)
			var uses: int = int(use.get("uses", 0))
			var slot: String = String(sl["slot"])
			var key_t: float = float(sl["t"])
			var where: PackedStringArray = PackedStringArray([m.label if not m.label.is_empty() else "Title"])
			if uses == 1:
				where.append("shared text on 1 clip")
			else:
				where.append("shared text on %d clips" % uses)
			if not String(use.get("seq_label", "")).is_empty():
				where.append("in " + String(use["seq_label"]))
			var hit: Dictionary = {
				"kind": KIND,
				"title": snippet(text, rs[0].x),
				"detail": _detail(where.duplicate(), text, slot, key_t, rs.size()),
				"time": float(use.get("time", -1.0)) if uses > 0 else -1.0,
				"clip_id": String(use.get("clip_id", "")),
				"media_id": m.id,
				"seq_id": String(use.get("seq_id", "")),
				"where": WHERE_MEDIA,
				"slot": slot,
				"key_t": key_t,
				"text": text,
				"ranges": rs,
			}
			if span.x >= 0:
				hit["within"] = span
			if bool(opts.get("each", false)):
				out.append_array(_split_each(hit, text, rs, where, slot, key_t))
				continue
			out.append(hit)
	return out


static func _within_user(doc: Project, within: Dictionary, media_id: String) -> String:
	for s: Sequence in doc.sequences:
		for tr: Track in s.all_tracks():
			for c: Clip in tr.clips:
				if c.media_id == media_id and within.has(c.id) and prop_of(c.props).is_empty():
					return c.id
	return ""


static func search(doc: Project, query: String, opts: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var needle: String = query.strip_edges()
	if doc == null or needle.is_empty():
		return out
	for s: Sequence in doc.sequences:
		for tr: Track in s.all_tracks():
			for c: Clip in tr.clips:
				out.append_array(clip_hits(doc, s, tr, c, needle, opts))
	out.append_array(media_hits(doc, needle, opts))
	return out


static func count(doc: Project, query: String, opts: Dictionary = {}) -> int:
	var n: int = 0
	for h: Dictionary in search(doc, query, opts):
		var rs: Array[Vector2i] = h["ranges"]
		n += rs.size()
	return n


static func _entry_clip(seq_id: String, clip_id: String, anim: Dictionary) -> Dictionary:
	return {"where": WHERE_CLIP, "seq_id": seq_id, "clip_id": clip_id, "media_id": "", "anim": anim, "value": null}


static func _media_value(m: MediaItem, p: Dictionary) -> Variant:
	if m.props.get(TEXT_KEY) is String and not AnimProp.is_animated(p):
		return String(p.get("v", ""))
	return p


static func hit_text(hit: Dictionary, needle: String, repl: String, case_sensitive: bool, whole_word: bool) -> String:
	var text: String = String(hit.get("text", ""))
	if plant_every:
		return replaced(text, needle, repl, case_sensitive, whole_word)
	if hit.get("only") is Vector2i:
		return replaced_only(text, one(hit["only"]), needle, repl, case_sensitive)
	if hit.get("within") is Vector2i:
		var rs: Array[Vector2i] = []
		for r: Variant in hit.get("ranges", []):
			if r is Vector2i:
				rs.append(r)
		return replaced_only(text, rs, needle, repl, case_sensitive)
	return replaced(text, needle, repl, case_sensitive, whole_word)


static func plan_within(doc: Project, needle: String, repl: String, opts: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var case_sensitive: bool = bool(opts.get("case", false))
	var whole_word: bool = bool(opts.get("word", false))
	var whole_opts: Dictionary = opts.duplicate()
	whole_opts.erase("each")
	var order: PackedStringArray = PackedStringArray()
	var work: Dictionary = {}
	for h: Dictionary in search(doc, needle, whole_opts):
		var media: bool = String(h.get("where", WHERE_CLIP)) == WHERE_MEDIA
		var id: String = ("m|" + String(h.get("media_id", ""))) if media else ("c|" + String(h.get("seq_id", "")) + "|" + String(h.get("clip_id", "")))
		if not work.has(id):
			var start: Dictionary = {}
			if media:
				var m: MediaItem = doc.media_by_id(String(h.get("media_id", "")))
				if m == null:
					continue
				start = prop_of(m.props)
			else:
				var s: Sequence = doc.sequence_by_id(String(h.get("seq_id", "")))
				var c: Clip = s.clip_by_id(String(h.get("clip_id", ""))) if s != null else null
				if c == null:
					continue
				start = prop_of(c.props)
			work[id] = {"hit": h, "prop": start}
			order.append(id)
		var entry: Dictionary = work[id]
		var next_text: String = hit_text(h, needle, repl, case_sensitive, whole_word)
		if next_text != String(h.get("text", "")):
			entry["prop"] = write_slot(entry["prop"], String(h.get("slot", SLOT_VALUE)), float(h.get("key_t", 0.0)), next_text)
	for id2: String in order:
		var e: Dictionary = work[id2]
		var h2: Dictionary = e["hit"]
		if String(h2.get("where", WHERE_CLIP)) == WHERE_MEDIA:
			var m2: MediaItem = doc.media_by_id(String(h2.get("media_id", "")))
			if prop_of(m2.props) == e["prop"]:
				continue
			out.append({"where": WHERE_MEDIA, "seq_id": "", "clip_id": "", "media_id": m2.id, "anim": {}, "value": _media_value(m2, e["prop"])})
		else:
			var s2: Sequence = doc.sequence_by_id(String(h2.get("seq_id", "")))
			var c2: Clip = s2.clip_by_id(String(h2.get("clip_id", "")))
			if prop_of(c2.props) == e["prop"]:
				continue
			out.append(_entry_clip(s2.id, c2.id, e["prop"]))
	return out


static func plan_one(doc: Project, hit: Dictionary, needle: String, repl: String, opts: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if doc == null or hit.is_empty() or needle.is_empty():
		return out
	var case_sensitive: bool = bool(opts.get("case", false))
	var whole_word: bool = bool(opts.get("word", false))
	var slot: String = String(hit.get("slot", SLOT_VALUE))
	var key_t: float = float(hit.get("key_t", 0.0))
	var next_text: String = hit_text(hit, needle, repl, case_sensitive, whole_word)
	if next_text == String(hit.get("text", "")):
		return out
	if String(hit.get("where", WHERE_CLIP)) == WHERE_MEDIA:
		var m: MediaItem = doc.media_by_id(String(hit.get("media_id", "")))
		if m == null:
			return out
		var mp: Dictionary = write_slot(prop_of(m.props), slot, key_t, next_text)
		out.append({"where": WHERE_MEDIA, "seq_id": "", "clip_id": "", "media_id": m.id, "anim": {}, "value": _media_value(m, mp)})
		return out
	var s: Sequence = doc.sequence_by_id(String(hit.get("seq_id", "")))
	if s == null:
		return out
	var c: Clip = s.clip_by_id(String(hit.get("clip_id", "")))
	if c == null:
		return out
	out.append(_entry_clip(s.id, c.id, write_slot(prop_of(c.props), slot, key_t, next_text)))
	return out


static func plan_all(doc: Project, needle_query: String, repl: String, opts: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var needle: String = needle_query.strip_edges()
	if doc == null or needle.is_empty():
		return out
	if not within_of(opts).is_empty():
		return plan_within(doc, needle, repl, opts)
	var case_sensitive: bool = bool(opts.get("case", false))
	var whole_word: bool = bool(opts.get("word", false))
	var seen_clips: Dictionary = {}
	var seen_media: Dictionary = {}
	for h: Dictionary in search(doc, needle, opts):
		if String(h.get("where", WHERE_CLIP)) == WHERE_MEDIA:
			var mid: String = String(h.get("media_id", ""))
			if seen_media.has(mid):
				continue
			seen_media[mid] = true
			var m: MediaItem = doc.media_by_id(mid)
			if m == null:
				continue
			var mp: Dictionary = write_every(prop_of(m.props), needle, repl, case_sensitive, whole_word)
			out.append({"where": WHERE_MEDIA, "seq_id": "", "clip_id": "", "media_id": mid, "anim": {}, "value": _media_value(m, mp)})
			continue
		var cid: String = String(h.get("clip_id", ""))
		if seen_clips.has(cid):
			continue
		seen_clips[cid] = true
		var s: Sequence = doc.sequence_by_id(String(h.get("seq_id", "")))
		if s == null:
			continue
		var c: Clip = s.clip_by_id(cid)
		if c == null:
			continue
		out.append(_entry_clip(s.id, cid, write_every(prop_of(c.props), needle, repl, case_sensitive, whole_word)))
	return out


static func commands(plan: Array[Dictionary]) -> Array[Command]:
	var out: Array[Command] = []
	for e: Dictionary in plan:
		if String(e.get("where", WHERE_CLIP)) == WHERE_MEDIA:
			out.append(OrganizerCmds.SetMediaProp.new(String(e["media_id"]), TEXT_KEY, e.get("value"), REPLACE_LABEL))
		else:
			out.append(ClipCmds.SetClipParam.new(String(e["seq_id"]), String(e["clip_id"]), TEXT_PATH, e.get("anim", {})))
	return out


static func apply(doc: Project, plan: Array[Dictionary], label: String = REPLACE_LABEL) -> bool:
	if doc == null or plan.is_empty():
		return false
	return Verbs.run(doc, label, commands(plan))


static func replace_one(doc: Project, hit: Dictionary, needle: String, repl: String, opts: Dictionary = {}) -> bool:
	return apply(doc, plan_one(doc, hit, needle, repl, opts), REPLACE_ONE_LABEL)


static func replace_all(doc: Project, needle: String, repl: String, opts: Dictionary = {}) -> bool:
	return apply(doc, plan_all(doc, needle, repl, opts), REPLACE_LABEL)


static func all_text(doc: Project) -> Dictionary:
	var out: Dictionary = {}
	if doc == null:
		return out
	for s: Sequence in doc.sequences:
		for tr: Track in s.all_tracks():
			for c: Clip in tr.clips:
				for sl: Dictionary in every_string(prop_of(c.props)):
					out["%s|%s|%s|%.4f" % [s.id, c.id, String(sl["slot"]), float(sl["t"])]] = String(sl["text"])
	for m: MediaItem in doc.media:
		for sl2: Dictionary in every_string(prop_of(m.props)):
			out["media|%s|%s|%.4f" % [m.id, String(sl2["slot"]), float(sl2["t"])]] = String(sl2["text"])
	return out

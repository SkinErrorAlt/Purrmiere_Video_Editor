extends RefCounted

const Project := preload("res://doc/project.gd")
const Sequence := preload("res://doc/sequence.gd")
const Track := preload("res://doc/track.gd")
const Clip := preload("res://doc/clip.gd")
const EPS := 0.00001
const PREF_RAZOR_LINKS := "timeline.razor_links"
const PREF_LINKED := "timeline.linked_selection"
const RAZOR_LINKS_LABEL := "Razor and Add edit cut linked clips together (Ctrl with the Razor cuts one lane)"
const CHAIN_KIND := "chained_links"


static func _prefs() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/Prefs")
	return null


static func register_prefs() -> void:
	var prefs: Node = _prefs()
	if prefs != null and prefs.has_method("is_registered") and not bool(prefs.call("is_registered", PREF_RAZOR_LINKS)):
		prefs.call("register", PREF_RAZOR_LINKS, true, {"label": RAZOR_LINKS_LABEL, "type": "bool"})


static func links_always() -> bool:
	var prefs: Node = _prefs()
	if prefs == null or not prefs.has_method("is_registered") or not bool(prefs.call("is_registered", PREF_RAZOR_LINKS)):
		return true
	return bool(prefs.call("get_value", PREF_RAZOR_LINKS))


static func razor_linked(linked_selection: bool) -> bool:
	return linked_selection or links_always()


static func razor_targets(tools: GDScript, seq: Sequence, clip_id: String, t: float, lane_only: bool, all_tracks: bool, linked_selection: bool) -> Dictionary:
	var out: Dictionary = tools.call("razor_targets", seq, clip_id, t, lane_only, all_tracks, razor_linked(linked_selection))
	var select: PackedStringArray = out.get("select", PackedStringArray())
	if not linked_selection and not select.is_empty():
		out["select"] = PackedStringArray([clip_id])
	return out


static func crosses(c: Clip, t: float) -> bool:
	return c != null and t > c.start + EPS and t < c.end() - EPS


static func still_crossed(s: Sequence, c: Clip, cut: Dictionary, t: float) -> bool:
	if s == null or c == null or c.link_id.is_empty():
		return false
	for m: Clip in s.linked(c):
		if m == c or cut.has(m.id):
			continue
		if crosses(m, t):
			return true
	return false


static func later_members(s: Sequence, c: Clip, cut: Dictionary, t: float) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if s == null or c == null or c.link_id.is_empty():
		return out
	for m: Clip in s.linked(c):
		if m == c or cut.has(m.id):
			continue
		if m.start >= t - EPS:
			out.append(m.id)
	return out


static func components(s: Sequence, members: Array[Clip]) -> Array[Array]:
	var sorted: Array[Clip] = members.duplicate()
	sorted.sort_custom(func(a: Clip, b: Clip) -> bool: return a.start < b.start)
	var out: Array[Array] = []
	var reach: float = -INF
	for m: Clip in sorted:
		if out.is_empty() or m.start >= reach - EPS:
			out.append([m])
			reach = m.end()
		else:
			(out[out.size() - 1] as Array).append(m)
			reach = maxf(reach, m.end())
	return out


static func _signature(s: Sequence, comp: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for v: Variant in comp:
		var c: Clip = v
		var tr: Track = s.track_of(c.id)
		parts.append((tr.id if tr != null else "?") + "|" + c.media_id)
	parts.sort()
	return ",".join(parts)


static func chains(s: Sequence) -> Array[Array]:
	var families: Dictionary = {}
	for c: Clip in s.all_clips():
		if c.link_id.is_empty():
			continue
		if not families.has(c.link_id):
			families[c.link_id] = [] as Array[Clip]
		(families[c.link_id] as Array[Clip]).append(c)
	var out: Array[Array] = []
	for link: Variant in families.keys():
		var members: Array[Clip] = families[link]
		if members.size() < 4 or bool(s.link_rule(String(link)).get("as_one", false)):
			continue
		var comps: Array[Array] = components(s, members)
		if comps.size() < 2:
			continue
		var sig: String = _signature(s, comps[0])
		var same: bool = true
		for comp: Array in comps:
			if comp.size() < 2 or _signature(s, comp) != sig:
				same = false
				break
		if same:
			out.append([String(link), comps])
	return out


static func repair_chains(project: Project, only_link: String = "") -> int:
	if project == null:
		return 0
	var pieces: int = 0
	for s: Sequence in project.sequences:
		for row: Array in chains(s):
			if not only_link.is_empty() and String(row[0]) != only_link:
				continue
			var comps: Array[Array] = row[1]
			for i: int in range(1, comps.size()):
				var link: String = project.mint_id("l")
				for v: Variant in comps[i]:
					(v as Clip).link_id = link
				pieces += 1
	if pieces > 0:
		project.touch("structure")
	return pieces


static func check(project: Project, out: Array[Dictionary]) -> void:
	if project == null:
		return
	for s: Sequence in project.sequences:
		for row: Array in chains(s):
			var comps: Array[Array] = row[1]
			var first: Clip = (comps[0] as Array)[0]
			var link: String = String(row[0])
			var text: String = "%d pieces of \"%s\" are linked as one (link \"%s\"), so selecting or cutting one reaches them all" % [comps.size(), first.label, link]
			out.append({"kind": CHAIN_KIND, "text": text, "fix": func() -> void: repair_chains(project, link)})

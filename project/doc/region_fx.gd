extends RefCounted

const Clip := preload("res://doc/clip.gd")
const AnimProp := preload("res://doc/anim_prop.gd")
const ViewMap := preload("res://doc/view_map.gd")
const PAIR_VIEW_ID := "pair_view"
const REGION_MAX := 8
const LINK_KEY := "region_of"
const INDEX_KEY := "region_index"
const WHOLE := "works on the whole clip, not on one region"

static var _crop_cache: Dictionary = {}


static func is_pair_view(e: Dictionary) -> bool:
	return String(e.get("id", "")) == PAIR_VIEW_ID


static func live_pair(c: Clip, uid: String) -> Dictionary:
	if c == null or uid.is_empty():
		return {}
	for e: Dictionary in c.effects:
		if String(e.get("uid", "")) == uid and is_pair_view(e) and bool(e.get("enabled", true)):
			return e
	return {}


static func first_pair(c: Clip) -> Dictionary:
	if c == null:
		return {}
	for e: Dictionary in c.effects:
		if is_pair_view(e) and bool(e.get("enabled", true)):
			return e
	return {}


static func solo_of(c: Clip) -> Dictionary:
	var e: Dictionary = first_pair(c)
	if e.is_empty():
		return {}
	var raw: Variant = (e.get("params", {}) as Dictionary).get("solo", null)
	if not (raw is Dictionary):
		return {}
	var index: int = int(round(float(AnimProp.static_value(raw))))
	if index < 0 or index >= region_count(e):
		return {}
	return {"pv": String(e.get("uid", "")), "index": index}


static func crops(e: Dictionary) -> Array[Dictionary]:
	var params: Dictionary = e.get("params", {})
	var raw: Variant = params.get("crops", null)
	var text: String = String(AnimProp.static_value(raw)) if raw is Dictionary else ""
	if _crop_cache.has(text):
		return _crop_cache[text]
	var out: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(text.strip_edges()) if not text.strip_edges().is_empty() else null
	if parsed is Array:
		for v: Variant in parsed:
			if not (v is Dictionary):
				continue
			var d: Dictionary = v
			if not (d.get("rect") is Array) or (d["rect"] as Array).size() < 4:
				continue
			var r: Array = d["rect"]
			out.append({"name": String(d.get("name", "")), "rect": Rect2(float(r[0]), float(r[1]), maxf(float(r[2]), 0.001), maxf(float(r[3]), 0.001)), "rot": float(d.get("rot", 0.0))})
	if out.is_empty():
		out.append({"name": "Full", "rect": Rect2(0.0, 0.0, 1.0, 1.0), "rot": 0.0})
	if _crop_cache.size() > 256:
		_crop_cache.clear()
	_crop_cache[text] = out
	return out


static func region_count(e: Dictionary) -> int:
	return mini(crops(e).size(), REGION_MAX)


static func crop(e: Dictionary, index: int) -> Dictionary:
	var list: Array[Dictionary] = crops(e)
	if index < 0 or index >= list.size():
		return {}
	return list[index]


static func region_name(e: Dictionary, index: int) -> String:
	var names: PackedStringArray = ViewMap.region_names(e)
	if index >= 0 and index < names.size():
		return names[index]
	return "View " + str(index + 1)


static func region_points(cr: Dictionary) -> Array:
	var box: Rect2 = cr.get("rect", Rect2(0.0, 0.0, 1.0, 1.0))
	var ang: float = deg_to_rad(float(cr.get("rot", 0.0)))
	var mid: Vector2 = box.get_center()
	var half: Vector2 = box.size * 0.5
	var out: Array = []
	for sgn: Vector2 in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]:
		var p: Vector2 = mid + (half * sgn).rotated(ang)
		out.append([p.x, p.y])
	return out


static func mask_link(m: Dictionary) -> Dictionary:
	var of: String = String(m.get(LINK_KEY, ""))
	var index: int = int(m.get(INDEX_KEY, -1))
	if of.is_empty() or index < 0:
		return {}
	return {"pv": of, "index": index}


static func mask_by_id(c: Clip, mid: String) -> Dictionary:
	if c == null or mid.is_empty():
		return {}
	for m: Dictionary in c.masks:
		if String(m.get("id", "")) == mid:
			return m
	return {}


static func region_mask_id(c: Clip, pv_uid: String, index: int) -> String:
	if c == null:
		return ""
	for m: Dictionary in c.masks:
		if String(m.get(LINK_KEY, "")) == pv_uid and int(m.get(INDEX_KEY, -1)) == index:
			return String(m.get("id", ""))
	return ""


static func link_of(c: Clip, e: Dictionary) -> Dictionary:
	if c == null or c.masks.is_empty() or is_pair_view(e):
		return {}
	var mid: String = String(e.get("mask", ""))
	if mid.is_empty():
		return {}
	var link: Dictionary = mask_link(mask_by_id(c, mid))
	if link.is_empty():
		return {}
	var pv: Dictionary = live_pair(c, String(link["pv"]))
	if pv.is_empty() or int(link["index"]) >= region_count(pv):
		return {}
	link["mask"] = mid
	return link


static func links(c: Clip) -> Dictionary:
	var out: Dictionary = {}
	if c == null or c.masks.is_empty():
		return out
	var linked: Dictionary = {}
	for m: Dictionary in c.masks:
		var of: String = String(m.get(LINK_KEY, ""))
		if not of.is_empty() and int(m.get(INDEX_KEY, -1)) >= 0:
			linked[String(m.get("id", ""))] = m
	if linked.is_empty():
		return out
	var counts: Dictionary = {}
	for pe: Dictionary in c.effects:
		if is_pair_view(pe) and bool(pe.get("enabled", true)):
			counts[String(pe.get("uid", ""))] = region_count(pe)
	if counts.is_empty():
		return out
	for e: Dictionary in c.effects:
		var mid: String = String(e.get("mask", ""))
		if mid.is_empty() or not linked.has(mid) or is_pair_view(e):
			continue
		var m2: Dictionary = linked[mid]
		var pv: String = String(m2[LINK_KEY])
		var index: int = int(m2[INDEX_KEY])
		if counts.has(pv) and index < int(counts[pv]):
			out[String(e.get("uid", ""))] = {"pv": pv, "index": index, "mask": mid}
	return out


static func linked_mask_ids(c: Clip) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for link: Variant in links(c).values():
		var mid: String = String((link as Dictionary)["mask"])
		if not out.has(mid):
			out.append(mid)
	return out


static func effects_on(c: Clip, pv_uid: String, index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null:
		return out
	for e: Dictionary in c.effects:
		var link: Dictionary = link_of(c, e)
		if not link.is_empty() and String(link["pv"]) == pv_uid and int(link["index"]) == index:
			out.append(e)
	return out


static func is_region_effect(c: Clip, uid: String) -> bool:
	if c == null:
		return false
	return not link_of(c, c.effect_by_uid(uid)).is_empty()


static func region_label(c: Clip, uid: String) -> String:
	var link: Dictionary = link_of(c, c.effect_by_uid(uid)) if c != null else {}
	if link.is_empty():
		return ""
	return region_name(live_pair(c, String(link["pv"])), int(link["index"]))


static func refusal(def: Dictionary) -> String:
	if def.is_empty():
		return "That effect is not installed"
	var label: String = String(def.get("label", def.get("id", "This effect")))
	if bool(def.get("audio", false)):
		return "Sound effects go on the clip's sound, not on a region"
	if is_pair_view(def):
		return "A Pair View cannot go inside one of its own regions"
	var pairs: Variant = def.get("pairs_with", null)
	if (pairs is PackedStringArray and not (pairs as PackedStringArray).is_empty()) or (pairs is Array and not (pairs as Array).is_empty()):
		return label + " " + WHOLE
	var passes: Variant = def.get("passes", null)
	if not (passes is Array) or (passes as Array).is_empty():
		return label + " " + WHOLE
	return ""


static func match_region(c: Clip, name: String, index: int) -> Dictionary:
	var e: Dictionary = first_pair(c)
	if e.is_empty():
		return {}
	var names: PackedStringArray = ViewMap.region_names(e)
	var n: int = region_count(e)
	for i: int in n:
		if not name.is_empty() and names[i] == name:
			return {"pv": String(e.get("uid", "")), "index": i}
	if index >= 0 and index < n:
		return {"pv": String(e.get("uid", "")), "index": index}
	return {}


static func _value(c: Clip, e: Dictionary, key: String, fallback: float, local_t: float, fps: float) -> float:
	var params: Dictionary = e.get("params", {})
	var p: Variant = params.get(key, null)
	if not (p is Dictionary):
		return fallback
	var at: float = c.fx_time(e, key, local_t) if e.has(Clip.AnimTime.SPEEDS_FIELD) else c.anim_time(local_t)
	var v: Variant = AnimProp.evaluate(p, at, c.duration, fps)
	if v is bool:
		return 1.0 if v else 0.0
	if v is float or v is int:
		return float(v)
	return fallback


static func shown_rect(cr: Dictionary, box: Rect2, dst_px: Vector2, src_px: Vector2, fit: int, zoom: float, pan: Vector2) -> Rect2:
	var r: Rect2 = cr.get("rect", Rect2(0.0, 0.0, 1.0, 1.0))
	var src_aspect: float = maxf(r.size.x * src_px.x, 1.0) / maxf(r.size.y * src_px.y, 1.0)
	var dst_aspect: float = maxf(dst_px.x, 1.0) / maxf(dst_px.y, 1.0)
	var scale: Vector2 = Vector2.ONE
	if fit == 0:
		scale = Vector2(1.0, dst_aspect / src_aspect) if src_aspect > dst_aspect else Vector2(src_aspect / dst_aspect, 1.0)
	elif fit == 1:
		scale = Vector2(src_aspect / dst_aspect, 1.0) if src_aspect > dst_aspect else Vector2(1.0, dst_aspect / src_aspect)
	var z: float = maxf(zoom, 0.01)
	var half: Vector2 = scale * z * 0.5
	var centre: Vector2 = Vector2(0.5, 0.5) - scale * z * Vector2(pan.x, -pan.y) * 0.5
	var local: Rect2 = Rect2(centre - half, half * 2.0).intersection(Rect2(0.0, 0.0, 1.0, 1.0))
	return Rect2(box.position + local.position * box.size, local.size * box.size)


static func region_at(c: Clip, e: Dictionary, uv: Vector2, local_t: float, fps: float, out_px: Vector2, src_px: Vector2) -> Dictionary:
	if c == null or e.is_empty():
		return {}
	var list: Array[Dictionary] = crops(e)
	var n: int = clampi(list.size(), 1, REGION_MAX)
	var fit: int = int(round(_value(c, e, "fit", 0.0, local_t, fps)))
	var zoom: float = _value(c, e, "zoom", 1.0, local_t, fps)
	var pan: Vector2 = Vector2(_value(c, e, "pan_x", 0.0, local_t, fps), _value(c, e, "pan_y", 0.0, local_t, fps))
	if _value(c, e, "grid", 0.0, local_t, fps) < 0.5:
		var active: int = ViewMap.index_at(_value(c, e, "view", 0.0, local_t, fps), int(round(_value(c, e, "view_mode", 0.0, local_t, fps))), n)
		if ViewMap.grouped(e):
			var vals: Dictionary = {ViewMap.GROUPS_KEY: ViewMap.groups_text(e), ViewMap.MODE_KEY: _value(c, e, "view_mode", 0.0, local_t, fps), ViewMap.GROUP_KEY: _value(c, e, ViewMap.GROUP_KEY, 0.0, local_t, fps)}
			for g: int in ViewMap.GROUP_MAX:
				vals[ViewMap.view_key_for(g)] = _value(c, e, ViewMap.view_key_for(g), 0.0, local_t, fps)
			active = ViewMap.resolve_values(vals, n)
		var rect: Rect2 = shown_rect(list[active], Rect2(0.0, 0.0, 1.0, 1.0), out_px, src_px, fit, zoom, pan)
		if rect.has_point(uv):
			return {"index": active, "rect": rect}
		return {}
	var cols: int = int(ceil(sqrt(float(n))))
	var rows: int = int(ceil(float(n) / float(cols)))
	var cell: Vector2 = Vector2(1.0 / float(cols), 1.0 / float(rows))
	var cx: int = clampi(int(floor(uv.x / cell.x)), 0, cols - 1)
	var cy: int = clampi(int(floor(uv.y / cell.y)), 0, rows - 1)
	var slot: int = cy * cols + cx
	if slot >= n:
		return {}
	var gap: float = _value(c, e, "grid_gap", 0.01, local_t, fps)
	var inner: Rect2 = Rect2(Vector2(float(cx), float(cy)) * cell + cell * gap, cell * maxf(1.0 - gap * 2.0, 0.0001))
	var cell_rect: Rect2 = shown_rect(list[slot], inner, cell * out_px * (1.0 - gap * 2.0), src_px, fit, zoom, pan)
	if cell_rect.has_point(uv):
		return {"index": slot, "rect": cell_rect}
	return {}

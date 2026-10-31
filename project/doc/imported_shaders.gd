extends RefCounted

const REGISTRY_PATH := "res://engine/effect_registry.gd"
const FIELD := "imported_shaders"
const CATEGORY := "In this project"
const PREFIX := "gds_"
const SLUG_MAX := 40
const FIELDS: PackedStringArray = ["id", "label", "category", "blurb", "source", "original", "code", "params", "library_id", "library_label", "library_category"]


static func slug(name: String) -> String:
	var out: String = ""
	var last_us: bool = true
	for ch: String in name.strip_edges().to_lower():
		if ch in "abcdefghijklmnopqrstuvwxyz0123456789":
			out += ch
			last_us = false
		elif not last_us:
			out += "_"
			last_us = true
	out = out.trim_suffix("_")
	if out.length() > SLUG_MAX:
		out = out.substr(0, SLUG_MAX).trim_suffix("_")
	return out if not out.is_empty() else "shader"


static func make_id(name: String, code: String) -> String:
	return PREFIX + slug(name) + "_" + code.sha256_text().substr(0, 8)


static func make_entry(name: String, source: String, original: String, converted: Dictionary) -> Dictionary:
	var code: String = String(converted.get("code", ""))
	var label: String = name.strip_edges() if not name.strip_edges().is_empty() else "Imported shader"
	return {
		"id": make_id(label, code),
		"label": label,
		"category": CATEGORY,
		"blurb": "Imported from " + source if not source.is_empty() else "",
		"source": source,
		"original": original,
		"code": code,
		"params": (converted.get("params", []) as Array).duplicate(true),
		"library_id": "",
		"library_label": "",
		"library_category": "",
	}


static func clean_entry(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var r: Dictionary = raw
	var id: String = String(r.get("id", ""))
	var code: String = String(r.get("code", ""))
	if id.is_empty() or code.is_empty():
		return {}
	var out: Dictionary = {}
	for f: String in FIELDS:
		if f == "params":
			out[f] = (r.get(f, []) as Array).duplicate(true) if r.get(f, []) is Array else []
		else:
			out[f] = String(r.get(f, ""))
	if String(out["category"]).is_empty():
		out["category"] = CATEGORY
	return out


static func store(doc: Object) -> Dictionary:
	var raw: Variant = doc.get(FIELD)
	if raw is Dictionary:
		return raw
	return {}


static func read(doc: Object, d: Dictionary) -> void:
	var out: Dictionary = {}
	var raw: Variant = d.get(FIELD, {})
	if raw is Dictionary:
		for k: Variant in (raw as Dictionary).keys():
			var e: Dictionary = clean_entry(raw[k])
			if not e.is_empty():
				out[String(e["id"])] = e
	doc.set(FIELD, out)
	if not out.is_empty():
		refresh(doc)


static func write(doc: Object, d: Dictionary) -> void:
	var st: Dictionary = store(doc).duplicate(true)
	for e: Dictionary in _used_but_missing(doc, st):
		st[String(e["id"])] = e
	if not st.is_empty():
		d[FIELD] = st


static func registry() -> RefCounted:
	var script: GDScript = load(REGISTRY_PATH)
	return script.call("shared")


static func _def_raw(e: Dictionary, as_library: bool) -> Dictionary:
	var label: String = String(e["label"])
	var category: String = String(e["category"])
	if as_library:
		if not String(e.get("library_label", "")).is_empty():
			label = String(e["library_label"])
		category = String(e.get("library_category", "")) if not String(e.get("library_category", "")).is_empty() else "User"
	return {"label": label, "category": category, "blurb": String(e.get("blurb", "")), "params": (e.get("params", []) as Array).duplicate(true)}


static func register_entry(reg: RefCounted, e: Dictionary) -> void:
	var id: String = String(e["id"])
	var code: String = String(e["code"])
	if not _registered_as(reg, id, code):
		reg.call("add_embedded", id, code, _def_raw(e, false))
	var lib: String = String(e.get("library_id", ""))
	if lib.is_empty():
		return
	var have: Dictionary = reg.call("get_def", lib)
	if have.is_empty() or bool(have.get("embedded", false)):
		if not _registered_as(reg, lib, code):
			reg.call("add_embedded", lib, code, _def_raw(e, true))


static func _registered_as(reg: RefCounted, id: String, code: String) -> bool:
	var have: Dictionary = reg.call("get_def", id)
	if have.is_empty() or not bool(have.get("embedded", false)):
		return false
	return String(have.get("path", "")).contains("/" + code.sha256_text().substr(0, 12) + "/")


static func refresh(doc: Object) -> void:
	var reg: RefCounted = registry()
	if reg == null:
		return
	var shown: PackedStringArray = PackedStringArray()
	for e: Variant in store(doc).values():
		var ed: Dictionary = e
		register_entry(reg, ed)
		var lib: String = String(ed.get("library_id", ""))
		if lib.is_empty():
			shown.append(String(ed["id"]))
		else:
			shown.append(lib)
			if used_count(doc, String(ed["id"])) > 0:
				shown.append(String(ed["id"]))
	reg.call("set_embedded_shown", shown)


static func is_imported(id: String) -> bool:
	if id.is_empty():
		return false
	var reg: RefCounted = registry()
	if reg == null:
		return false
	var def: Dictionary = reg.call("get_def", id)
	return bool(def.get("embedded", false))


static func entry_for(doc: Object, id: String) -> Dictionary:
	var st: Dictionary = store(doc)
	if st.has(id):
		return st[id]
	for e: Variant in st.values():
		if String((e as Dictionary).get("library_id", "")) == id:
			return e
	return {}


static func clips_using(doc: Object, id: String) -> Array:
	var out: Array = []
	var seqs: Variant = doc.get("sequences")
	if not (seqs is Array):
		return out
	for s: Object in seqs:
		for t: Object in s.call("all_tracks"):
			for c: Object in t.get("clips"):
				for fx: Variant in c.get("effects"):
					if String((fx as Dictionary).get("id", "")) == id:
						out.append({"seq": String(s.get("id")), "clip": c, "uid": String((fx as Dictionary).get("uid", ""))})
	return out


static func used_count(doc: Object, id: String) -> int:
	return clips_using(doc, id).size()


static func _used_but_missing(doc: Object, st: Dictionary) -> Array:
	var out: Array = []
	var seqs: Variant = doc.get("sequences")
	if not (seqs is Array):
		return out
	var want: Dictionary = {}
	for s: Object in seqs:
		for t: Object in s.call("all_tracks"):
			for c: Object in t.get("clips"):
				for fx: Variant in c.get("effects"):
					var id: String = String((fx as Dictionary).get("id", ""))
					if id.begins_with(PREFIX) and not st.has(id):
						want[id] = true
	if want.is_empty():
		return out
	var reg: RefCounted = registry()
	for id: Variant in want.keys():
		var def: Dictionary = reg.call("get_def", String(id))
		if def.is_empty() or not bool(def.get("embedded", false)):
			continue
		var passes: Array = def.get("passes", [])
		if passes.is_empty():
			continue
		var script: GDScript = load(REGISTRY_PATH)
		var code: String = String(script.call("_read_text", String(passes[0]["shader"])))
		if code.is_empty():
			continue
		out.append(clean_entry({"id": String(id), "label": String(def.get("label", id)), "category": CATEGORY, "blurb": String(def.get("blurb", "")), "code": code, "original": code, "params": (def.get("params", []) as Array).duplicate(true)}))
	return out

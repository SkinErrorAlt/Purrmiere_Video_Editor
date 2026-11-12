extends RefCounted

const PREF_KEY := "bin.shelf"
const PREF_OPEN := "bin.shelf_open"
const PREF_WIDTH := "bin.shelf_width"
const VERSION := 1
const TABS_MOST := 24
const ITEMS_MOST := 200
const NAME_LONGEST := 48
const WIDTH_LEAST := 120.0
const WIDTH_MOST := 480.0
const WIDTH_DEFAULT := 190.0
const FOLDER := "folder"
const FILE := "file"
const FIRST_TAB := "Pinned"


static func tidy(path: String) -> String:
	var out: String = path.strip_edges().replace("\\", "/").simplify_path()
	while out.length() > 1 and out.ends_with("/"):
		out = out.substr(0, out.length() - 1)
	return out


static func same(a: String, b: String) -> bool:
	return tidy(a).to_lower() == tidy(b).to_lower()


static func leaf(path: String) -> String:
	var clean: String = tidy(path)
	var name: String = clean.get_file()
	return name if not name.is_empty() else clean


static func clean_name(text: String) -> String:
	var out: String = text.strip_edges()
	if out.length() > NAME_LONGEST:
		out = out.substr(0, NAME_LONGEST).strip_edges()
	return out


static func make_tab(id: String, name: String, colour: int = -1) -> Dictionary:
	return {"id": id, "name": clean_name(name), "colour": clampi(colour, -1, 15), "open": true, "items": []}


static func make_item(kind: String, path: String) -> Dictionary:
	return {"kind": FOLDER if kind == FOLDER else FILE, "path": tidy(path)}


static func kind_of(path: String) -> String:
	return FOLDER if DirAccess.dir_exists_absolute(tidy(path)) else FILE


static func empty() -> Array:
	return [make_tab("t1", FIRST_TAB)]


static func quiet_parse(text: String) -> Variant:
	var clean: String = text.strip_edges()
	if clean.is_empty():
		return null
	var reader: JSON = JSON.new()
	return reader.data if reader.parse(clean) == OK else null


static func read(text: String) -> Array:
	var parsed: Variant = quiet_parse(text)
	if not (parsed is Dictionary):
		return empty()
	var raw: Variant = (parsed as Dictionary).get("tabs", null)
	if not (raw is Array):
		return empty()
	var out: Array = []
	for one: Variant in (raw as Array):
		if not (one is Dictionary):
			continue
		var t: Dictionary = one
		var id: String = String(t.get("id", "")).strip_edges()
		if id.is_empty() or out.size() >= TABS_MOST:
			continue
		var tab: Dictionary = make_tab(id, String(t.get("name", "")), int(t.get("colour", -1)))
		tab["open"] = bool(t.get("open", true))
		var items: Array = []
		for it: Variant in (t.get("items", []) as Array):
			if not (it is Dictionary) or items.size() >= ITEMS_MOST:
				continue
			var path: String = tidy(String((it as Dictionary).get("path", "")))
			if path.is_empty():
				continue
			var seen: bool = false
			for had: Variant in items:
				if same(String((had as Dictionary)["path"]), path):
					seen = true
					break
			if not seen:
				items.append(make_item(String((it as Dictionary).get("kind", FILE)), path))
		tab["items"] = items
		out.append(tab)
	return out if not out.is_empty() else empty()


static func write(tabs: Array) -> String:
	return JSON.stringify({"version": VERSION, "tabs": tabs})


static func index_of(tabs: Array, tab_id: String) -> int:
	for i: int in tabs.size():
		if String((tabs[i] as Dictionary).get("id", "")) == tab_id:
			return i
	return -1


static func next_id(tabs: Array) -> String:
	var n: int = tabs.size() + 1
	while index_of(tabs, "t" + str(n)) >= 0:
		n += 1
	return "t" + str(n)


static func with_tab(tabs: Array, name: String, colour: int = -1) -> Array:
	if tabs.size() >= TABS_MOST:
		return tabs
	var out: Array = tabs.duplicate(true)
	out.append(make_tab(next_id(out), name if not clean_name(name).is_empty() else "Tab " + str(out.size() + 1), colour))
	return out


static func without_tab(tabs: Array, tab_id: String) -> Array:
	if tabs.size() <= 1:
		return tabs
	var at: int = index_of(tabs, tab_id)
	if at < 0:
		return tabs
	var out: Array = tabs.duplicate(true)
	out.remove_at(at)
	return out


static func renamed(tabs: Array, tab_id: String, name: String) -> Array:
	var at: int = index_of(tabs, tab_id)
	var want: String = clean_name(name)
	if at < 0 or want.is_empty() or String((tabs[at] as Dictionary).get("name", "")) == want:
		return tabs
	var out: Array = tabs.duplicate(true)
	(out[at] as Dictionary)["name"] = want
	return out


static func coloured(tabs: Array, tab_id: String, colour: int) -> Array:
	var at: int = index_of(tabs, tab_id)
	var want: int = clampi(colour, -1, 15)
	if at < 0 or int((tabs[at] as Dictionary).get("colour", -1)) == want:
		return tabs
	var out: Array = tabs.duplicate(true)
	(out[at] as Dictionary)["colour"] = want
	return out


static func folded(tabs: Array, tab_id: String, open: bool) -> Array:
	var at: int = index_of(tabs, tab_id)
	if at < 0 or bool((tabs[at] as Dictionary).get("open", true)) == open:
		return tabs
	var out: Array = tabs.duplicate(true)
	(out[at] as Dictionary)["open"] = open
	return out


static func tab_moved(tabs: Array, tab_id: String, by: int) -> Array:
	var at: int = index_of(tabs, tab_id)
	if at < 0:
		return tabs
	var to: int = clampi(at + by, 0, tabs.size() - 1)
	if to == at:
		return tabs
	var out: Array = tabs.duplicate(true)
	var held: Variant = out[at]
	out.remove_at(at)
	out.insert(to, held)
	return out


static func holds(tabs: Array, tab_id: String, path: String) -> bool:
	var at: int = index_of(tabs, tab_id)
	if at < 0:
		return false
	for it: Variant in ((tabs[at] as Dictionary).get("items", []) as Array):
		if same(String((it as Dictionary).get("path", "")), path):
			return true
	return false


static func anywhere(tabs: Array, path: String) -> String:
	for t: Variant in tabs:
		if holds(tabs, String((t as Dictionary)["id"]), path):
			return String((t as Dictionary)["id"])
	return ""


static func with_item(tabs: Array, tab_id: String, path: String, kind: String = "") -> Array:
	var at: int = index_of(tabs, tab_id)
	var clean: String = tidy(path)
	if at < 0 or clean.is_empty() or holds(tabs, tab_id, clean):
		return tabs
	var items: Array = ((tabs[at] as Dictionary).get("items", []) as Array)
	if items.size() >= ITEMS_MOST:
		return tabs
	var out: Array = tabs.duplicate(true)
	((out[at] as Dictionary)["items"] as Array).append(make_item(kind if kind == FOLDER or kind == FILE else kind_of(clean), clean))
	return out


static func with_items(tabs: Array, tab_id: String, paths: PackedStringArray) -> Array:
	var out: Array = tabs
	for p: String in paths:
		out = with_item(out, tab_id, p)
	return out


static func without_item(tabs: Array, tab_id: String, path: String) -> Array:
	var at: int = index_of(tabs, tab_id)
	if at < 0:
		return tabs
	var out: Array = tabs.duplicate(true)
	var items: Array = (out[at] as Dictionary)["items"]
	for i: int in items.size():
		if same(String((items[i] as Dictionary).get("path", "")), path):
			items.remove_at(i)
			return out
	return tabs


static func item_moved_to(tabs: Array, from_tab: String, path: String, to_tab: String) -> Array:
	if from_tab == to_tab or index_of(tabs, to_tab) < 0 or not holds(tabs, from_tab, path):
		return tabs
	var kind: String = FILE
	var at: int = index_of(tabs, from_tab)
	for it: Variant in ((tabs[at] as Dictionary).get("items", []) as Array):
		if same(String((it as Dictionary).get("path", "")), path):
			kind = String((it as Dictionary).get("kind", FILE))
			break
	return with_item(without_item(tabs, from_tab, path), to_tab, path, kind)


static func item_index(tabs: Array, tab_id: String, path: String) -> int:
	var at: int = index_of(tabs, tab_id)
	if at < 0:
		return -1
	var items: Array = (tabs[at] as Dictionary).get("items", [])
	for i: int in items.size():
		if same(String((items[i] as Dictionary).get("path", "")), path):
			return i
	return -1


static func item_dropped(tabs: Array, from_tab: String, path: String, to_tab: String, to_index: int) -> Array:
	var from_at: int = item_index(tabs, from_tab, path)
	if from_at < 0 or index_of(tabs, to_tab) < 0:
		return tabs
	var out: Array = tabs.duplicate(true)
	var from_items: Array = (out[index_of(out, from_tab)] as Dictionary)["items"]
	var held: Variant = from_items[from_at]
	from_items.remove_at(from_at)
	var to_items: Array = (out[index_of(out, to_tab)] as Dictionary)["items"]
	var want: int = clampi(to_index, 0, to_items.size())
	if from_tab == to_tab and want == from_at:
		return tabs
	if to_items.size() >= ITEMS_MOST:
		return tabs
	to_items.insert(want, held)
	return out


static func tab_moved_to(tabs: Array, tab_id: String, to_index: int) -> Array:
	var at: int = index_of(tabs, tab_id)
	if at < 0:
		return tabs
	var want: int = clampi(to_index, 0, tabs.size() - 1)
	if want == at:
		return tabs
	var out: Array = tabs.duplicate(true)
	var held: Variant = out[at]
	out.remove_at(at)
	out.insert(want, held)
	return out


static func items_of(tabs: Array, tab_id: String) -> Array:
	var at: int = index_of(tabs, tab_id)
	return ((tabs[at] as Dictionary).get("items", []) as Array) if at >= 0 else []


static func there(item: Dictionary) -> bool:
	var path: String = tidy(String(item.get("path", "")))
	if path.is_empty():
		return false
	if String(item.get("kind", FILE)) == FOLDER:
		return DirAccess.dir_exists_absolute(path)
	return FileAccess.file_exists(path)


static func label_of(tabs: Array, tab_id: String, path: String) -> String:
	var mine: String = leaf(path)
	for it: Variant in items_of(tabs, tab_id):
		var other: String = String((it as Dictionary).get("path", ""))
		if not same(other, path) and leaf(other).to_lower() == mine.to_lower():
			var parent: String = tidy(path).get_base_dir().get_file()
			return (parent + "/" + mine) if not parent.is_empty() else mine
	return mine


static func width_of(value: Variant) -> float:
	return clampf(float(value) if value is float or value is int else WIDTH_DEFAULT, WIDTH_LEAST, WIDTH_MOST)


static func counts(tabs: Array) -> Dictionary:
	var folders: int = 0
	var files: int = 0
	var gone: int = 0
	for t: Variant in tabs:
		for it: Variant in ((t as Dictionary).get("items", []) as Array):
			var item: Dictionary = it
			if String(item.get("kind", FILE)) == FOLDER:
				folders += 1
			else:
				files += 1
			if not there(item):
				gone += 1
	return {"tabs": tabs.size(), "folders": folders, "files": files, "missing": gone}

extends RefCounted

const EffectSource := preload("res://modules/core_panels/effect_source.gd")
const FOLDERS := "folders"
const ORDER := "order"
const PRESET_FAVS := "preset_favourites"
## Preset folders live beside the effect folders under their own key; every folder call takes the key.
const PRESET_FOLDERS := "preset_folders"
const NEW_NAME := "New folder"

static var _counter: int = 0


static func data() -> Dictionary:
	return EffectSource.lists()


static func save() -> void:
	EffectSource._save_lists()


static func folders(key: String = FOLDERS) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Variant = data().get(key, [])
	if not (raw is Array):
		return out
	for f: Variant in raw:
		if not (f is Dictionary):
			continue
		var fd: Dictionary = f
		var items: PackedStringArray = PackedStringArray()
		for v: Variant in fd.get("items", []):
			items.append(str(v))
		out.append({"id": str(fd.get("id", "")), "name": str(fd.get("name", NEW_NAME)), "items": items})
	return out


static func _write(list: Array[Dictionary], key: String = FOLDERS) -> void:
	var rows: Array = []
	for f: Dictionary in list:
		rows.append({"id": String(f["id"]), "name": String(f["name"]), "items": Array(f["items"] as PackedStringArray)})
	data()[key] = rows
	save()


static func _index(list: Array[Dictionary], id: String) -> int:
	for i: int in list.size():
		if String(list[i]["id"]) == id:
			return i
	return -1


static func find(id: String, key: String = FOLDERS) -> Dictionary:
	var list: Array[Dictionary] = folders(key)
	var at: int = _index(list, id)
	return list[at] if at >= 0 else {}


static func mint_id() -> String:
	_counter += 1
	return "folder_" + str(Time.get_unix_time_from_system()).replace(".", "") + "_" + str(_counter)


static func create(name: String = "", key: String = FOLDERS) -> String:
	var list: Array[Dictionary] = folders(key)
	var id: String = mint_id()
	list.append({"id": id, "name": name.strip_edges() if not name.strip_edges().is_empty() else NEW_NAME, "items": PackedStringArray()})
	_write(list, key)
	return id


static func rename(id: String, name: String, key: String = FOLDERS) -> bool:
	var list: Array[Dictionary] = folders(key)
	var at: int = _index(list, id)
	if at < 0 or name.strip_edges().is_empty():
		return false
	list[at]["name"] = name.strip_edges()
	_write(list, key)
	return true


static func remove(id: String, key: String = FOLDERS) -> bool:
	var list: Array[Dictionary] = folders(key)
	var at: int = _index(list, id)
	if at < 0:
		return false
	list.remove_at(at)
	_write(list, key)
	return true


static func move(id: String, step: int, key: String = FOLDERS) -> bool:
	var list: Array[Dictionary] = folders(key)
	var at: int = _index(list, id)
	var to: int = at + step
	if at < 0 or to < 0 or to >= list.size():
		return false
	var f: Dictionary = list[at]
	list.remove_at(at)
	list.insert(to, f)
	_write(list, key)
	return true


static func add(folder_id: String, effect_id: String, before_id: String = "", key: String = FOLDERS) -> bool:
	var list: Array[Dictionary] = folders(key)
	var at: int = _index(list, folder_id)
	if at < 0 or effect_id.is_empty():
		return false
	var items: PackedStringArray = list[at]["items"]
	var had: int = items.find(effect_id)
	if had >= 0 and before_id.is_empty():
		return false
	if had >= 0:
		items.remove_at(had)
	var spot: int = items.find(before_id) if not before_id.is_empty() else -1
	if spot < 0:
		items.append(effect_id)
	else:
		items.insert(spot, effect_id)
	if had >= 0 and items.find(effect_id) == had:
		return false
	list[at]["items"] = items
	_write(list, key)
	return true


static func take_out(folder_id: String, effect_id: String, key: String = FOLDERS) -> bool:
	var list: Array[Dictionary] = folders(key)
	var at: int = _index(list, folder_id)
	if at < 0:
		return false
	var items: PackedStringArray = list[at]["items"]
	var had: int = items.find(effect_id)
	if had < 0:
		return false
	items.remove_at(had)
	list[at]["items"] = items
	_write(list, key)
	return true


static func folders_with(effect_id: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for f: Dictionary in folders():
		if (f["items"] as PackedStringArray).has(effect_id):
			out.append(String(f["id"]))
	return out


static func stored_order() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var raw: Variant = data().get(ORDER, [])
	if raw is Array:
		for v: Variant in raw:
			out.append(str(v))
	return out


static func my_order(library: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id: String in stored_order():
		if library.has(id) and not out.has(id):
			out.append(id)
	for id2: String in library:
		if not out.has(id2):
			out.append(id2)
	return out


static func place(effect_id: String, before_id: String, library: PackedStringArray) -> bool:
	var order: PackedStringArray = my_order(library)
	var had: int = order.find(effect_id)
	if had < 0 or effect_id == before_id:
		return false
	order.remove_at(had)
	var spot: int = order.find(before_id) if not before_id.is_empty() else -1
	if spot < 0:
		order.append(effect_id)
	else:
		order.insert(spot, effect_id)
	if order.find(effect_id) == had:
		return false
	data()[ORDER] = Array(order)
	save()
	return true


static func preset_favourites() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var raw: Variant = data().get(PRESET_FAVS, [])
	if raw is Array:
		for v: Variant in raw:
			out.append(str(v))
	return out


static func is_preset_favourite(id: String) -> bool:
	return preset_favourites().has(id)


static func set_preset_favourite(id: String, on: bool) -> void:
	var favs: PackedStringArray = preset_favourites()
	var at: int = favs.find(id)
	if on and at < 0:
		favs.append(id)
	elif not on and at >= 0:
		favs.remove_at(at)
	else:
		return
	data()[PRESET_FAVS] = Array(favs)
	save()

extends RefCounted

const Project := preload("res://doc/project.gd")
const BoardCmds := preload("res://doc/commands/board_cmds.gd")
const CARD_W := 150.0
const CARD_H := 112.0
const PIC_H := 84.0
const NOTE_W := 170.0
const NOTE_H := 96.0
const GAP := 24.0
const GROUP_PAD := 28.0
const NOTE_COLOUR := 15
const GROUP_COLOUR := 0


static func key_for(folder: String) -> String:
	return "bin:" + folder


static func empty_board() -> Dictionary:
	return {"cards": {}, "notes": [], "groups": [], "arrows": [], "next": 1}


static func normalise(raw: Variant) -> Dictionary:
	var out: Dictionary = empty_board()
	if not (raw is Dictionary):
		return out
	var d: Dictionary = raw
	var cards: Variant = d.get("cards", {})
	if cards is Dictionary:
		for k: Variant in (cards as Dictionary).keys():
			var v: Variant = (cards as Dictionary)[k]
			if v is Array and (v as Array).size() >= 2:
				(out["cards"] as Dictionary)[String(k)] = [float((v as Array)[0]), float((v as Array)[1])]
	for key: String in ["notes", "groups", "arrows"]:
		var list: Variant = d.get(key, [])
		if list is Array:
			for e: Variant in (list as Array):
				if e is Dictionary and not String((e as Dictionary).get("id", "")).is_empty():
					(out[key] as Array).append((e as Dictionary).duplicate(true))
	out["next"] = maxi(1, int(d.get("next", 1)))
	return out


static func read(doc: Project, folder: String) -> Dictionary:
	if doc == null:
		return empty_board()
	var st: Dictionary = BoardCmds.store(doc)
	return normalise(st.get(key_for(folder), {}))


static func card_pos(board: Dictionary, id: String) -> Variant:
	var cards: Dictionary = board.get("cards", {})
	if not cards.has(id):
		return null
	var v: Array = cards[id]
	return Vector2(float(v[0]), float(v[1]))


static func set_card(board: Dictionary, id: String, pos: Vector2) -> void:
	(board["cards"] as Dictionary)[id] = [snappedf(pos.x, 0.5), snappedf(pos.y, 0.5)]


static func mint(board: Dictionary, prefix: String) -> String:
	var n: int = int(board.get("next", 1))
	board["next"] = n + 1
	return prefix + str(n)


static func find(board: Dictionary, list_key: String, id: String) -> int:
	var list: Array = board.get(list_key, [])
	for i: int in list.size():
		if String((list[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


static func add_note(board: Dictionary, at: Vector2, text: String = "", colour: int = NOTE_COLOUR) -> String:
	var id: String = mint(board, "n")
	(board["notes"] as Array).append({"id": id, "x": snappedf(at.x, 0.5), "y": snappedf(at.y, 0.5), "w": NOTE_W, "h": NOTE_H, "text": text, "colour": colour})
	return id


static func add_group(board: Dictionary, rect: Rect2, label: String, colour: int = GROUP_COLOUR) -> String:
	var id: String = mint(board, "g")
	(board["groups"] as Array).append({"id": id, "x": snappedf(rect.position.x, 0.5), "y": snappedf(rect.position.y, 0.5), "w": snappedf(maxf(rect.size.x, 120.0), 0.5), "h": snappedf(maxf(rect.size.y, 80.0), 0.5), "label": label, "colour": colour})
	return id


static func add_arrow(board: Dictionary, from_id: String, to_id: String) -> String:
	if from_id.is_empty() or to_id.is_empty() or from_id == to_id:
		return ""
	for a: Variant in board.get("arrows", []):
		var ad: Dictionary = a
		if String(ad.get("from", "")) == from_id and String(ad.get("to", "")) == to_id:
			return ""
	var id: String = mint(board, "a")
	(board["arrows"] as Array).append({"id": id, "from": from_id, "to": to_id})
	return id


static func remove_thing(board: Dictionary, id: String) -> bool:
	for key: String in ["notes", "groups", "arrows"]:
		var i: int = find(board, key, id)
		if i >= 0:
			(board[key] as Array).remove_at(i)
			if key == "notes":
				drop_arrows_of(board, id)
			return true
	return false


static func drop_arrows_of(board: Dictionary, id: String) -> void:
	var kept: Array = []
	for a: Variant in board.get("arrows", []):
		var ad: Dictionary = a
		if String(ad.get("from", "")) != id and String(ad.get("to", "")) != id:
			kept.append(ad)
	board["arrows"] = kept


static func board_order(positions: Dictionary, column_w: float) -> PackedStringArray:
	var list: Array[Dictionary] = []
	for k: Variant in positions.keys():
		var p: Vector2 = positions[k]
		list.append({"id": String(k), "x": p.x, "y": p.y})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["x"]) < float(b["x"]) or (float(a["x"]) == float(b["x"]) and float(a["y"]) < float(b["y"])))
	var columns: Array = []
	var col_x: float = -INF
	for e: Dictionary in list:
		if columns.is_empty() or float(e["x"]) - col_x > column_w * 0.4:
			columns.append([])
			col_x = float(e["x"])
		(columns[columns.size() - 1] as Array).append(e)
	var out: PackedStringArray = PackedStringArray()
	for col: Variant in columns:
		var c: Array = col
		c.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
		for e: Variant in c:
			out.append(String((e as Dictionary)["id"]))
	return out


static func tidy(ids: PackedStringArray, origin: Vector2, cols: int) -> Dictionary:
	var out: Dictionary = {}
	var n: int = maxi(1, cols)
	for i: int in ids.size():
		var cx: int = i % n
		var cy: int = i / n
		out[ids[i]] = origin + Vector2(float(cx) * (CARD_W + GAP), float(cy) * (CARD_H + GAP))
	return out


static func flow_positions(ids: PackedStringArray, start: Vector2, cols: int) -> Dictionary:
	return tidy(ids, start, cols)

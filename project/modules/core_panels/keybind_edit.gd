extends RefCounted

const SCOPE_WORDS: Dictionary = {
	"global": "everywhere",
	"timeline": "timeline",
	"program": "Program monitor",
	"source": "Source monitor",
	"bin": "Bin",
	"keys": "Keyframes panel",
	"controls": "Effect Controls",
}
const MODIFIER_KEYS: Array[Key] = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]
const IDLE_TEXT := "Click a key, or press Enter on a row, then press the new key."
const NO_KEY := "None"
const SECTION_WORDS := "shortcuts keyboard keys keybinds key binds bindings"
const RESET_TITLE := "Reset keyboard shortcuts"
const RESET_TEXT := "Every key you changed goes back to the Premiere keymap."
const RESET_OK := "Reset"
const RESET_DONE := "Keyboard shortcuts are back to the Premiere defaults"


static func scope_word(scope: String) -> String:
	return String(SCOPE_WORDS.get(scope, scope))


static func category_of(id: String) -> String:
	var c: String = Cmd.category(id)
	if not c.is_empty():
		return c
	var cat: Dictionary = Cmd.catalogue()
	if cat.has(id):
		return String(cat[id]["category"])
	return "Other"


static func entries(query: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var words: PackedStringArray = query.strip_edges().to_lower().split(" ", false)
	for id: String in Cmd.command_ids():
		var label: String = Cmd.label(id)
		var cat: String = category_of(id)
		var keys: Array[String] = Cmd.keys_for(id)
		var hay: String = (label + " " + cat + " " + id + " " + " ".join(PackedStringArray(keys))).to_lower()
		var ok: bool = true
		for w: String in words:
			if not hay.contains(w):
				ok = false
				break
		if not ok:
			continue
		out.append({"id": id, "label": label, "category": cat, "scope": Cmd.scope_of(id), "keys": keys, "user": Cmd.has_user_keys(id)})
	out.sort_custom(_before)
	return out


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if String(a["category"]) != String(b["category"]):
		return String(a["category"]) < String(b["category"])
	return String(a["label"]).naturalnocasecmp_to(String(b["label"])) < 0


static func section_matches(query: String) -> bool:
	var s: String = query.strip_edges().to_lower()
	if s.is_empty() or SECTION_WORDS.contains(s):
		return true
	return not entries(s).is_empty()


static func keys_text(id: String) -> String:
	var keys: Array[String] = Cmd.keys_for(id)
	if keys.is_empty():
		return NO_KEY
	return ", ".join(PackedStringArray(keys))


static func changed_note(id: String) -> String:
	if not Cmd.has_user_keys(id):
		return ""
	var was: Array[String] = Cmd.default_keys_for(id)
	if was.is_empty():
		return "You set this one; it had no key before."
	return "You changed this one; it was " + ", ".join(PackedStringArray(was)) + "."


static func key_event_text(k: InputEventKey) -> String:
	if k.keycode in MODIFIER_KEYS:
		return ""
	return Cmd.key_string(k)


static func is_cancel(k: InputEventKey) -> bool:
	return k.keycode == KEY_ESCAPE and not k.ctrl_pressed and not k.shift_pressed and not k.alt_pressed


static func clashes_for(id: String, key: String) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	if id.is_empty() or key.is_empty():
		return none
	return Cmd.clashes(key, Cmd.scope_of(id), id)


static func clash_text(key: String, list: Array[Dictionary]) -> String:
	if list.is_empty():
		return ""
	var names: PackedStringArray = PackedStringArray()
	for c: Dictionary in list:
		names.append(String(c["label"]) + " (" + scope_word(String(c["scope"])) + ")")
	return key + " is already used by " + ", ".join(names) + ". Assign it here and take it off there?"


static func status_text(id: String, key: String, list: Array[Dictionary]) -> String:
	if id.is_empty():
		return IDLE_TEXT
	if not list.is_empty():
		return clash_text(key, list)
	return "Press the new key for " + Cmd.label(id) + ". Escape cancels."


static func assign(id: String, key: String, list: Array[Dictionary]) -> void:
	if id.is_empty() or key.is_empty():
		return
	for c: Dictionary in list:
		var other: String = String(c["id"])
		var kept: Array[String] = []
		for k: String in Cmd.keys_for(other):
			if k != key:
				kept.append(k)
		Cmd.set_user_keys(other, kept)
	var mine: Array[String] = [key]
	Cmd.set_user_keys(id, mine)
	Events.toast(Cmd.label(id) + " is now " + key)


static func clear_keys(id: String) -> void:
	if id.is_empty():
		return
	var none: Array[String] = []
	Cmd.set_user_keys(id, none)


static func reset_all() -> void:
	Cmd.reset_user_keymap()
	Events.toast(RESET_DONE)

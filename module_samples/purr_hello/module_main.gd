extends RefCounted
## Hello Module: the living example of a Purrmiere module. Everything goes through the api object Purrmiere hands
## to register(); nothing here loads Purrmiere's own scripts. See docs/MODULE_GUIDE.md.

var api: RefCounted = null
var panel_id: String = ""
var notes_opened: PackedStringArray = PackedStringArray()


func register(p_api: RefCounted) -> void:
	api = p_api
	panel_id = api.add_panel("hello", "hello_panel.gd", "Hello")
	api.add_workspace("hello", "Hello", workspace_layout())
	var say: String = api.add_command("say_hello", "Say Hello", say_hello)
	api.add_menu_item("help", say)
	api.add_setting("greeting", "Hello from a module", "Greeting", "What Say Hello shows. It proves a module can keep its own settings.")
	api.add_effects_folder("effects")
	api.add_format("note", "Hello note", PackedStringArray(["hellonote"]), open_note)
	api.add_document_kind("card", "Hello card", "hellocard", new_card, open_note)


func unregister() -> void:
	api = null


func say_hello() -> void:
	api.toast(String(api.setting("greeting")))


func open_note(path: String) -> bool:
	notes_opened.append(path)
	api.toast("Hello note opened: " + path.get_file())
	return true


func new_card() -> Dictionary:
	return {"kind": "card", "text": String(api.setting("greeting"))}


func workspace_layout() -> Dictionary:
	return {
		"version": 1,
		"tree": {"t": "s", "dir": "h", "ratio": 0.3,
			"a": {"t": "g", "tabs": [panel_id], "active": panel_id},
			"b": {"t": "s", "dir": "v", "ratio": 0.6,
				"a": {"t": "g", "tabs": ["program"], "active": "program"},
				"b": {"t": "g", "tabs": ["timeline"], "active": "timeline"}}},
		"floats": [],
		"state": {},
	}

extends RefCounted

## The contract every effect panel kind follows. A kind is one script in a
## module's effect_panels folder that extends this file; its file name is its
## kind name. See docs/66_EFFECT_PANELS.md.
##
## The view handed to every call is the panel host (a Control). Draw on it with
## the usual CanvasItem calls and read values through it:
##   view.has(role), view.value(role), view.low(role), view.high(role),
##   view.norm(role), view.denorm(role, t), view.shown(role), view.choices(role),
##   view.option(name, fallback), view.text(...), view.col(token), view.grab,
##   view.hover, view.start_value(role), view.press_at, view.frozen

const PanelView := preload("res://modules/core_panels/effect_panel_host.gd")
const TYPES_NUMBER: PackedStringArray = ["float", "int"]
const TYPES_CHOICE: PackedStringArray = ["enum", "int"]


func title() -> String:
	return ""


## role name -> {"label": String, "need": bool, "types": PackedStringArray}
func roles() -> Dictionary:
	return {}


## Preferred height in unscaled pixels; the host scales it with the UI.
func height() -> float:
	return 180.0


func draw(_view: PanelView) -> void:
	pass


## Returns what the press took hold of, or "" to leave the press alone.
func press(_view: PanelView, _at: Vector2) -> String:
	return ""


## Returns role -> new value for the roles the drag moves.
func drag(_view: PanelView, _grab: String, _at: Vector2) -> Dictionary:
	return {}


## A press that never moved. Returns role -> new value, if a click means something.
func click(_view: PanelView, _grab: String, _at: Vector2) -> Dictionary:
	return {}


func hover(_view: PanelView, _at: Vector2) -> String:
	return ""


func tip(_view: PanelView, _part: String) -> String:
	return ""


## The undo step's name for a drag of this part.
func undo_label(_part: String) -> String:
	return "Move " + title().to_lower()


static func role(label: String, need: bool, types: PackedStringArray = TYPES_NUMBER) -> Dictionary:
	return {"label": label, "need": need, "types": types}

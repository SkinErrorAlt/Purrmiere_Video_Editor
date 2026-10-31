shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

void fragment() {
	COLOR = mix(from_at(UV), to_at(UV), progress);
}

shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int curve = 0;

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	return mix(from_at(uv), to_at(uv), p);
}

void fragment() {
	COLOR = transition(UV);
}

shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int columns : hint_range(2, 80) = 10;
uniform int rows : hint_range(2, 80) = 10;
uniform float smoothness : hint_range(0.0, 1.0) = 0.5;

vec4 transition(vec2 uv) {
	vec2 dims = vec2(float(max(columns, 1)), float(max(rows, 1)));
	vec2 cell = min(floor(uv * dims), dims - 1.0);
	float r = tr_hash(cell + vec2(0.5, 41.5));
	float s = max(smoothness, 0.0001);
	float m = 1.0 - smoothstep(-s, 0.0, r - progress * (1.0 + s));
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}

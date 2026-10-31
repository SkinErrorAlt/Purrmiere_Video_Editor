shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int lines : hint_range(4, 240) = 50;
uniform int orientation = 0;
uniform float lead : hint_range(1.0, 3.0) = 1.5;

vec4 transition(vec2 uv) {
	float c = orientation == 0 ? uv.y : uv.x;
	float n = float(max(lines, 1));
	float idx = min(floor(c * n), n - 1.0);
	bool ahead = mod(idx, 2.0) < 0.5;
	float t = ahead ? min(progress * max(lead, 1.0), 1.0) : progress;
	return mix(from_at(uv), to_at(uv), t);
}

void fragment() {
	COLOR = transition(UV);
}

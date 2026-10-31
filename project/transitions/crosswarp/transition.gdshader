shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float width : hint_range(0.05, 2.0) = 1.0;
uniform vec2 centre = vec2(0.5, 0.5);

vec4 transition(vec2 uv) {
	float p = progress;
	float u = uv.x;
	if (direction == 1) {
		u = 1.0 - uv.x;
	} else if (direction == 2) {
		u = 1.0 - uv.y;
	} else if (direction == 3) {
		u = uv.y;
	}
	float x = (p * (1.0 + width) - (1.0 - u)) / width;
	x = clamp(x, 0.0, 1.0);
	x = x * x * (3.0 - 2.0 * x);
	vec4 a = from_at((uv - centre) * (1.0 - x) + centre);
	vec4 b = to_at((uv - centre) * x + centre);
	return mix(a, b, x);
}

void fragment() {
	COLOR = transition(UV);
}

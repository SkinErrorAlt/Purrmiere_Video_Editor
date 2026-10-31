shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float zoom : hint_range(0.0, 4.0) = 1.0;
uniform float softness : hint_range(0.0, 0.5) = 0.06;
uniform int timing = 1;

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float e = tr_ease(p, timing == 1 ? 3 : (timing == 2 ? 4 : 0));
	float along = 1.0 - uv.x;
	vec2 anchor = vec2(0.0, 0.5);
	if (direction == 1) {
		along = uv.x;
		anchor = vec2(1.0, 0.5);
	} else if (direction == 2) {
		along = 1.0 - uv.y;
		anchor = vec2(0.5, 0.0);
	} else if (direction == 3) {
		along = uv.y;
		anchor = vec2(0.5, 1.0);
	}
	float s = max(softness, 0.0001);
	float front = e * (1.0 + s);
	float m = 1.0 - smoothstep(front - s, front, along);
	vec2 fp = anchor + (uv - anchor) / (1.0 + zoom * e);
	vec4 a = texture(from_tex, fp);
	vec4 b = texture(to_tex, uv);
	return mix(a, b, m);
}

void fragment() {
	COLOR = transition(UV);
}

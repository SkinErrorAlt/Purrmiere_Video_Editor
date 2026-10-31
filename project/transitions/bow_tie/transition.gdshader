shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int orientation = 0;
uniform float softness : hint_range(0.0, 0.3) = 0.02;
uniform int curve = 0;

float w_sweep(float v, float p, float soft) {
	float s = max(soft, 0.0001);
	float e = mix(-s, 1.0, p);
	return 1.0 - smoothstep(e, e + s, v);
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	float a = orientation == 0 ? uv.x : uv.y;
	float b = orientation == 0 ? uv.y : uv.x;
	float g = min(a, 1.0 - a) + abs(b - 0.5);
	float px = 1.0 / min(frame_px.x, frame_px.y);
	float m = w_sweep(g, p, max(softness, px));
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}

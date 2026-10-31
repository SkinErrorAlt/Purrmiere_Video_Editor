shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int orientation = 0;
uniform int motion = 0;
uniform float softness : hint_range(0.0, 0.5) = 0.1;
uniform int curve = 1;

float w_sweep(float v, float p, float soft) {
	float s = max(soft, 0.0001);
	float e = mix(-s, 1.0, p);
	return 1.0 - smoothstep(e, e + s, v);
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	float c = orientation == 0 ? uv.x : uv.y;
	float px = orientation == 0 ? 2.0 / frame_px.x : 2.0 / frame_px.y;
	float v = abs(c - 0.5) * 2.0;
	if (motion == 1) {
		v = 1.0 - v;
	}
	float m = w_sweep(v, p, max(softness, px));
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}

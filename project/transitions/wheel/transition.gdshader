shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int spokes : hint_range(1, 8) = 1;
uniform int direction = 0;
uniform float softness : hint_range(0.0, 0.25) = 0.02;
uniform int curve = 1;

float w_sweep(float v, float p, float soft) {
	float s = max(soft, 0.0001);
	float e = mix(-s, 1.0, p);
	return 1.0 - smoothstep(e, e + s, v);
}

float clock_angle(vec2 w) {
	if (dot(w, w) < 0.000000000001) {
		w = vec2(0.0, 0.000001);
	}
	return atan(w.x, w.y);
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	vec2 w = tr_world(uv);
	float a = clock_angle(w);
	float n = float(max(spokes, 1));
	float turn = 2.0 * TR_PI;
	float f = direction == 1 ? fract(-a / turn * n) : fract(a / turn * n);
	float r = length(w) * frame_px.y;
	float px = min(n / max(turn * r, 1.0), 0.25);
	float m = w_sweep(f, p, max(softness, px));
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}

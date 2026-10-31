shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int blades : hint_range(2, 16) = 8;
uniform float turn : hint_range(-1.0, 1.0) = 0.32;
uniform float softness : hint_range(0.0, 0.3) = 0.0;
uniform int curve = 0;

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
	float a = -clock_angle(w) / (2.0 * TR_PI);
	float n = float(max(blades, 1));
	float f = fract((a + turn * p) * n);
	float r = length(w) * frame_px.y;
	float px = min(n / max(2.0 * TR_PI * r, 1.0), 0.25);
	float m = w_sweep(f, p, max(softness, px));
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}

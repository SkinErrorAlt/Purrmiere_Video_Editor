shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float start_angle : hint_range(0.0, 360.0) = 0.0;
uniform int direction = 0;
uniform float softness : hint_range(0.0, 0.25) = 0.0;
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
	vec2 c = vec2(uv.x - 0.5, 0.5 - uv.y);
	float a = clock_angle(c);
	float turn = 2.0 * TR_PI;
	float rel = (a - radians(start_angle)) / turn;
	float f = direction == 1 ? fract(rel) : fract(-rel);
	float r = length(c * frame_px);
	float px = min(1.0 / max(turn * r, 1.0), 0.25);
	float m = w_sweep(f, p, max(softness, px));
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}

shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float split : hint_range(0.0, 300.0) = 70.0;
uniform float blend : hint_range(0.05, 1.0) = 0.3;
uniform float shake : hint_range(0.0, 1.0) = 0.25;
uniform float zoom : hint_range(0.0, 0.5) = 0.08;

vec4 both(vec2 uv, float m) {
	return mix(from_clamped(uv), to_clamped(uv), m);
}

vec4 transition(vec2 uv) {
	float p = progress;
	float env = sin(TR_PI * p);
	env = env * env;
	float a = radians(angle);
	vec2 dir = vec2(cos(a), sin(a)) * split * px_scale / frame_px * env;
	vec2 jig = (vec2(tr_noise(vec2(p * 14.0, 1.5)), tr_noise(vec2(p * 14.0, 8.5))) - 0.5) * shake * 0.06 * env;
	vec2 base = (uv - 0.5) / (1.0 + zoom * env) + 0.5 + jig;
	float m = clamp((p - 0.5) / blend + 0.5, 0.0, 1.0);
	m = m * m * (3.0 - 2.0 * m);
	vec4 r = both(base + dir, m);
	vec4 g = both(base, m);
	vec4 b = both(base - dir, m);
	return vec4(r.r, g.g, b.b, max(g.a, max(r.a, b.a)));
}

void fragment() {
	COLOR = transition(UV);
}

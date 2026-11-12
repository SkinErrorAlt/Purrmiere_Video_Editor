shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform int direction = 0;
uniform float amount : hint_range(0.1, 1.5) = 0.6;
vec2 dir_of(int d) {
	if (d == 1) { return vec2(-1.0, 0.0); }
	else if (d == 2) { return vec2(0.0, 1.0); }
	else if (d == 3) { return vec2(0.0, -1.0); }
	return vec2(1.0, 0.0);
}
vec4 transition(vec2 uv) {
	float e = clamp(progress, 0.0, 1.0);
	float peak = sin(e * TR_PI);
	vec2 d = dir_of(direction);
	float m = smoothstep(0.4, 0.6, e);
	vec3 col = vec3(0.0);
	float aa = 0.0;
	const int N = 12;
	for (int i = 0; i < N; i++) {
		float t = (float(i) / float(N - 1) - 0.5) * 2.0;
		vec2 off = d * t * amount * peak;
		vec4 s = mix(from_clamped(uv + off), to_clamped(uv + off), m);
		col += s.rgb;
		aa += s.a;
	}
	return vec4(col / float(N), aa / float(N));
}
void fragment() { COLOR = transition(UV); }

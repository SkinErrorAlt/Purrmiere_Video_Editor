shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec2 center = vec2(0.5, 0.5);
uniform float streak : hint_range(0.3, 2.5) = 1.3;
uniform float flash : hint_range(0.0, 1.0) = 0.6;

vec4 transition(vec2 uv) {
	float e = clamp(progress, 0.0, 1.0);
	float peak = sin(e * TR_PI);
	vec2 q = uv - center;

	vec3 acol = vec3(0.0);
	vec3 bcol = vec3(0.0);
	const int N = 10;
	for (int i = 0; i < N; i++) {
		float t = float(i) / float(N - 1);
		acol += from_clamped(center + q * (1.0 + t * peak * streak)).rgb;
		bcol += to_clamped(center + q * (1.0 - t * peak * streak * 0.5)).rgb;
	}
	acol /= float(N);
	bcol /= float(N);

	float ang = atan(q.y, q.x);
	float rad = length(q * vec2(tr_ratio(), 1.0));
	float sv = tr_fbm(vec2(ang * 9.0, rad * 3.0 - e * 5.0));
	vec3 stars = vec3(smoothstep(0.62, 0.92, sv)) * peak * smoothstep(0.05, 0.4, rad);

	float m = smoothstep(0.42, 0.58, e);
	vec3 base = mix(acol, bcol, m) + stars * 0.6;
	base = mix(base, vec3(1.0), smoothstep(0.42, 0.5, e) * (1.0 - smoothstep(0.5, 0.58, e)) * peak * flash);
	return vec4(clamp(base, 0.0, 1.0), 1.0);
}

void fragment() {
	COLOR = transition(UV);
}

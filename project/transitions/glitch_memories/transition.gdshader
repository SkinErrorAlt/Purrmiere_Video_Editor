shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float block : hint_range(4.0, 96.0) = 16.0;
uniform float strength : hint_range(0.0, 1.0) = 0.3;
uniform float rate : hint_range(4.0, 120.0) = 60.0;
uniform float separation : hint_range(0.0, 1.0) = 0.5;

vec4 transition(vec2 uv) {
	float p = progress;
	float env = (1.0 - p) * smoothstep(0.0, 0.12, p) * 1.25;
	vec2 cell = floor(uv * frame_px / max(block * px_scale, 1.0));
	float q = floor(p * rate);
	vec2 n = tr_hash2(cell * 0.71 + vec2(q * 1.31, q * 2.77));
	vec2 dist = (n - 0.5) * strength * env;
	float s = separation;
	vec2 ur = uv + dist * (0.3 - 0.1 * s);
	vec2 ug = uv + dist * 0.3;
	vec2 ub = uv + dist * (0.3 + 0.2 * s);
	vec4 r = mix(from_clamped(ur), to_clamped(ur), p);
	vec4 g = mix(from_clamped(ug), to_clamped(ug), p);
	vec4 b = mix(from_clamped(ub), to_clamped(ub), p);
	return vec4(r.r, g.g, b.b, g.a);
}

void fragment() {
	COLOR = transition(UV);
}

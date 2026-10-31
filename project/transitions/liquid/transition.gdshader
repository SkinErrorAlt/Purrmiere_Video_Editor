shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float strength : hint_range(0.0, 0.5) = 0.12;
uniform float scale : hint_range(0.5, 10.0) = 2.5;
uniform float flow : hint_range(0.0, 3.0) = 1.0;
uniform float softness : hint_range(0.01, 0.5) = 0.12;
uniform float shine : hint_range(0.0, 1.0) = 0.25;

float n3(vec2 q) {
	return (tr_noise(q) * 0.6 + tr_noise(q * 2.07 + vec2(5.3, 1.7)) * 0.3 + tr_noise(q * 4.13 + vec2(2.1, 8.9)) * 0.1);
}

vec4 transition(vec2 uv) {
	float p = progress;
	float env = sin(TR_PI * p);
	vec2 w = tr_world(uv) * scale;
	float t = p * flow * 2.0;
	vec2 f1 = vec2(n3(w + vec2(0.0, t)), n3(w + vec2(5.2, 1.3) - vec2(t, 0.0)));
	vec2 f2 = vec2(n3(w + 3.0 * f1 + vec2(1.7, 9.2) + t * 0.5), n3(w + 3.0 * f1 + vec2(8.3, 2.8) - t * 0.5));
	vec2 disp = (f2 - 0.5) * 2.0 * strength * env * vec2(1.0 / tr_ratio(), 1.0);
	vec2 src = uv + disp;
	float n = clamp((n3(w * 0.8 + 2.0 * f2) - 0.5) * 1.8 + 0.5, 0.0, 1.0);
	float s = max(softness, 0.005);
	float edge = mix(-s, 1.0 + s, p);
	float keep = smoothstep(edge - s, edge + s, n);
	vec4 col = mix(from_mirrored(src), to_mirrored(src), 1.0 - keep);
	float slope = (f2.x - f2.y) * env;
	return tr_shade(col, 1.0 + shine * slope);
}

void fragment() {
	COLOR = transition(UV);
}

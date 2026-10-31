shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float lenses : hint_range(2.0, 40.0) = 8.0;
uniform float strength : hint_range(0.0, 0.2) = 0.05;
uniform float colour_split : hint_range(0.0, 1.0) = 0.3;
uniform int curve = 0;

vec4 transition(vec2 uv) {
	float p = curve == 1 ? tr_ease(progress, 3) : progress;
	vec2 w = tr_world(uv) * lenses;
	vec2 disp = strength * vec2(sin(2.0 * TR_PI * w.x), sin(2.0 * TR_PI * w.y)) * vec2(1.0 / tr_ratio(), 1.0);
	vec4 into = to_clamped(uv + (1.0 - p) * disp);
	vec2 df = p * disp;
	vec4 r = from_clamped(uv + df * (1.0 - colour_split));
	vec4 g = from_clamped(uv + df);
	vec4 bl = from_clamped(uv + df * (1.0 + colour_split));
	vec4 outof = vec4(r.r, g.g, bl.b, g.a);
	return into * p + outof * (1.0 - p);
}

void fragment() {
	COLOR = transition(UV);
}

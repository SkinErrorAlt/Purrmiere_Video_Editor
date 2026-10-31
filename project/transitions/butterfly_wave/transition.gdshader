shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float amplitude : hint_range(0.0, 3.0) = 1.0;
uniform float waves : hint_range(1.0, 60.0) = 30.0;
uniform float colour_split : hint_range(0.0, 1.0) = 0.3;
uniform float strength : hint_range(0.0, 2.0) = 1.0;

float butterfly(float th) {
	float s = sin((2.0 * th - TR_PI) / 24.0);
	return (exp(cos(th)) - 2.0 * cos(4.0 * th) + s * s * s * s * s) * 0.1;
}

vec4 transition(vec2 uv) {
	float p = progress;
	vec2 o = (uv - 0.5) * sin(p * amplitude + 0.0001) * 2.0;
	float th = acos(clamp(o.x / (length(o) + 0.35), -1.0, 1.0)) * waves;
	vec2 disp = vec2(butterfly(th)) * strength;
	vec4 b = to_clamped(uv + (1.0 - p) * disp);
	vec2 df = p * disp;
	vec4 r = from_clamped(uv + df * (1.0 - colour_split));
	vec4 g = from_clamped(uv + df);
	vec4 bl = from_clamped(uv + df * (1.0 + colour_split));
	vec4 a = vec4(r.r, g.g, bl.b, g.a);
	return b * p + a * (1.0 - p);
}

void fragment() {
	COLOR = transition(UV);
}

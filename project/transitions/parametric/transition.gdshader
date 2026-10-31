shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float a : hint_range(1.0, 10.0) = 4.0;
uniform float b : hint_range(0.1, 5.0) = 1.0;
uniform float rings : hint_range(1.0, 300.0) = 120.0;
uniform float strength : hint_range(0.0, 0.3) = 0.06;
uniform float blend_start : hint_range(0.0, 0.9) = 0.2;
uniform vec2 centre = vec2(0.5, 0.5);

vec4 transition(vec2 uv) {
	float p = progress;
	float ang = p * 2.0 * TR_PI;
	float ratio = a / max(b, 0.001) - 1.0;
	float x = (a - b) * cos(ang) + b * cos(ang * ratio);
	float y = (a - b) * sin(ang) - b * sin(ang * ratio);
	vec2 rel = uv - centre;
	float d = length(rel);
	float env = sin(TR_PI * p);
	vec2 offset = rel * (sin(p * d * rings + x) + sin(p * d * rings + y)) * strength / max(d + 0.05, 0.05) * env;
	vec4 from_c = from_clamped(uv + offset);
	float m = smoothstep(blend_start, 1.0, p);
	return mix(from_c, to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}

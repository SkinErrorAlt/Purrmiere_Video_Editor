shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform float punch : hint_range(0.05, 0.8) = 0.32;
vec4 transition(vec2 uv) {
	float e = clamp(progress, 0.0, 1.0);
	float s = 1.0 + sin(e * TR_PI) * punch;
	vec2 p = (uv - vec2(0.5)) / s + vec2(0.5);
	float m = smoothstep(0.42, 0.58, e);
	return mix(from_clamped(p), to_clamped(p), m);
}
void fragment() { COLOR = transition(UV); }

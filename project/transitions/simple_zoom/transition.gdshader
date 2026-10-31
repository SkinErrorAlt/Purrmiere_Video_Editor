shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float quickness : hint_range(0.2, 1.0) = 0.8;
uniform vec2 centre = vec2(0.5, 0.5);

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float q = clamp(quickness, 0.2, 1.0);
	float a = smoothstep(0.0, q, p);
	vec2 s = centre + (uv - centre) * (1.0 - a);
	float m = smoothstep(q - 0.2, 1.0, p);
	return mix(from_clamped(s), texture(to_tex, uv), m);
}

void fragment() {
	COLOR = transition(UV);
}

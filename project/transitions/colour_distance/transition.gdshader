shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int order = 0;
uniform float softness : hint_range(0.01, 1.0) = 0.1;
uniform float power : hint_range(1.0, 10.0) = 5.0;

vec4 transition(vec2 uv) {
	vec4 f = from_at(uv);
	vec4 t = to_at(uv);
	float d = clamp(distance(f, t), 0.0, 1.0);
	if (order == 1) {
		d = 1.0 - d;
	}
	float s = softness;
	float w = clamp((progress * (1.0 + s) - d) / s, 0.0, 1.0);
	return mix(mix(f, t, w), t, pow(progress, power));
}

void fragment() {
	COLOR = transition(UV);
}

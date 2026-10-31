shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int order = 0;
uniform float spread : hint_range(0.0, 0.9) = 0.4;

vec3 ranks() {
	if (order == 1) {
		return vec3(2.0, 1.0, 0.0);
	} else if (order == 2) {
		return vec3(1.0, 0.0, 2.0);
	} else if (order == 3) {
		return vec3(2.0, 0.0, 1.0);
	} else if (order == 4) {
		return vec3(0.0, 2.0, 1.0);
	} else if (order == 5) {
		return vec3(1.0, 2.0, 0.0);
	}
	return vec3(0.0, 1.0, 2.0);
}

vec4 transition(vec2 uv) {
	vec4 f = from_at(uv);
	vec4 t = to_at(uv);
	float span = 1.0 - spread;
	vec3 start = ranks() * 0.5 * spread;
	vec3 w = smoothstep(start, start + span, vec3(progress));
	float wa = smoothstep(0.0, 1.0, progress);
	float a = mix(f.a, t.a, wa);
	vec3 rgb = mix(f.rgb, t.rgb, w);
	return vec4(min(rgb, vec3(a)), a);
}

void fragment() {
	COLOR = transition(UV);
}

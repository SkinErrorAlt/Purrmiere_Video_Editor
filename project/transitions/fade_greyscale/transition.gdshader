shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float intensity : hint_range(0.05, 0.95) = 0.3;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int curve = 0;

vec4 grey_of(vec4 c) {
	float g = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 tinted = g * mix(vec3(1.0), tint.rgb, tint.a);
	return vec4(min(tinted, vec3(c.a)), c.a);
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	vec4 f = from_at(uv);
	vec4 t = to_at(uv);
	float drain = smoothstep(0.0, 1.0 - intensity, progress);
	float fill = smoothstep(intensity, 1.0, progress);
	vec4 fg = mix(f, grey_of(f), drain);
	vec4 tg = mix(grey_of(t), t, fill);
	return mix(fg, tg, p);
}

void fragment() {
	COLOR = transition(UV);
}

shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec4 colour : source_color = vec4(0.9, 0.4, 0.2, 1.0);
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform int curve = 0;

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	vec4 f = from_at(uv);
	vec4 t = to_at(uv);
	vec3 heat = colour.rgb * colour.a * strength;
	vec3 fr = f.rgb + heat * p;
	vec3 tr = t.rgb + heat * (1.0 - p);
	float fa = mix(f.a, 1.0, clamp(p * strength, 0.0, 1.0) * colour.a);
	float ta = mix(t.a, 1.0, clamp((1.0 - p) * strength, 0.0, 1.0) * colour.a);
	vec4 c = mix(vec4(fr, fa), vec4(tr, ta), p);
	return vec4(min(c.rgb, vec3(c.a)), c.a);
}

void fragment() {
	COLOR = transition(UV);
}

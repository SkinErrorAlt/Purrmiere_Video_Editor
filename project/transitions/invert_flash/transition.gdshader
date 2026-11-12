shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform float flash : hint_range(0.0, 1.0) = 0.7;
vec4 transition(vec2 uv) {
	float e = clamp(progress, 0.0, 1.0);
	float fl = exp(-pow((e - 0.5) / 0.13, 2.0));
	vec4 a = from_at(uv);
	vec4 b = to_at(uv);
	vec4 base = e < 0.5 ? a : b;
	vec3 inv = vec3(base.a) - base.rgb;
	base.rgb = mix(base.rgb, inv, fl * flash * 0.85);
	base.rgb = mix(base.rgb, vec3(base.a), fl * flash * 0.6);
	return vec4(clamp(base.rgb, 0.0, 1.0), base.a);
}
void fragment() { COLOR = transition(UV); }

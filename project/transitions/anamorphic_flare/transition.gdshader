shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform float intensity : hint_range(0.0, 2.5) = 1.2;
uniform vec4 flare_color : source_color = vec4(0.42, 0.62, 1.0, 1.0);
vec4 transition(vec2 uv) {
	float e = clamp(progress, 0.0, 1.0);
	float peak = sin(e * TR_PI);
	vec4 base = mix(from_at(uv), to_at(uv), smoothstep(0.35, 0.65, e));
	float fx = mix(0.12, 0.88, e);
	float dy = uv.y - 0.5;
	float dx = (uv.x - fx) * tr_ratio();
	float core = exp(-dy * dy * 320.0) * exp(-dx * dx * 7.0);
	float halo = exp(-dy * dy * 42.0) * exp(-dx * dx * 2.5) * 0.4;
	float glow = (core + halo) * peak * intensity;
	base.rgb += flare_color.rgb * flare_color.a * glow;
	base.rgb = mix(base.rgb, vec3(base.a), clamp(core * peak * intensity - 0.3, 0.0, 1.0) * 0.5);
	return vec4(clamp(base.rgb, 0.0, 1.0), base.a);
}
void fragment() { COLOR = transition(UV); }

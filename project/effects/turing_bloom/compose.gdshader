shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/turing_bloom/sim.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D grid_tex : filter_nearest, repeat_disable;
uniform float clip_time = 0.0;
uniform float growth : hint_range(0.0, 1.0) = 0.7;
uniform float grow_time : hint_range(0.0, 30.0) = 6.0;
uniform int look : hint_range(0, 2) = 0;
uniform vec4 ink : source_color = vec4(0.12, 0.06, 0.03, 1.0);
uniform vec4 paper : source_color = vec4(0.96, 0.9, 0.78, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.75;
uniform float relief : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	vec4 src = texture(effect_tex, UV);
	float alpha = src.a;
	vec3 pic = src.rgb / max(alpha, 0.0001);
	float l = sim_luma(pic);
	float p = texture(TEXTURE, UV).b;
	float d = sim_field(grid_tex, UV) * 2.0;
	float g = growth;
	if (grow_time > 0.0) {
		g *= clamp(clip_time / grow_time, 0.0, 1.0);
	}
	float r_now = g * 1.1;
	float inside = (1.0 - smoothstep(r_now - 0.03, r_now + 0.01, d)) * smoothstep(0.0, 0.02, r_now);
	float aa = fwidth(p) * 1.2 + 0.01;
	float m = smoothstep(0.5 - aa, 0.5 + aa, p) * inside;
	float fresh = smoothstep(r_now - 0.08, r_now - 0.01, d) * inside;

	vec3 col = pic;
	if (look == 0) {
		vec3 dark = pic * mix(vec3(1.0), ink.rgb * 2.4, 0.85) * 0.75;
		vec3 light = pic * 1.04 + 0.01;
		col = mix(light, dark, m);
		col = mix(pic, col, strength * inside);
	} else if (look == 1) {
		vec3 a = ink.rgb * (0.4 + 0.9 * l);
		vec3 b = paper.rgb * (0.55 + 0.6 * l);
		col = mix(pic, mix(b, a, m), strength * inside);
	} else {
		vec3 coral = mix(pic * 0.45, mix(pic, paper.rgb, 0.35) * 1.1, m);
		col = mix(pic, coral, strength * inside);
	}
	float hx = dFdx(m);
	float hy = dFdy(m);
	float lit = clamp(-(hx * 0.6 + hy * 0.8) * 6.0, -1.0, 1.0);
	col += lit * relief * 0.18 * inside;
	col = mix(col, col * vec3(1.08, 1.05, 0.95) + 0.04, fresh * 0.5);
	col = clamp(col, 0.0, 1.0);
	COLOR = vec4(col * alpha, alpha);
}

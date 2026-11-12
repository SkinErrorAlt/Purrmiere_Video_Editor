shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/stirred_smoke/sim.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float clip_time = 0.0;
uniform int source : hint_range(0, 2) = 0;
uniform float rise : hint_range(-1.0, 1.0) = 0.35;
uniform float colourful : hint_range(0.0, 1.0) = 0.35;
uniform vec4 tint : source_color = vec4(0.82, 0.82, 0.84, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.85;
uniform int seed : hint_range(0, 9999) = 0;

void fragment() {
	vec4 src = texture(effect_tex, UV);
	float alpha = src.a;
	vec3 pic = src.rgb / max(alpha, 0.0001);
	vec2 tsz = vec2(textureSize(effect_tex, 0));
	vec2 q = UV * vec2(tsz.x / max(tsz.y, 1.0), 1.0);
	float sd = float(seed) * 0.53;

	vec4 sm = texture(TEXTURE, UV);
	float a = sm.a;
	vec3 carried = sm.rgb / max(a, 0.0001);
	float t = clip_time;
	vec2 drift = vec2(0.0, t * rise * 0.6);
	float b1 = sim_fbm(q * 9.0 + drift + sd, 4);
	float b2 = sim_fbm(q * 23.0 + drift * 1.4 + vec2(b1 * 0.6) + sd, 3);
	float detail = 0.45 + 0.75 * b1 * (0.7 + 0.6 * b2);
	float d = clamp(a * detail * 1.25, 0.0, 1.0);
	d = smoothstep(0.02, 0.9, d);
	float lit = clamp(-dFdy(d) * 18.0 + 0.5, 0.0, 1.0);

	vec3 col = pic;
	if (source == 2) {
		vec3 ink = mix(tint.rgb, carried * 0.6, colourful);
		col = mix(col, col * ink, d * opacity);
		col *= 1.0 - 0.25 * d * opacity;
	} else {
		vec3 smoke = mix(tint.rgb * (0.6 + 0.4 * sim_luma(carried) + 0.2), carried, colourful);
		smoke *= 0.78 + 0.35 * lit;
		col = mix(col, smoke, d * opacity);
	}
	col = clamp(col, 0.0, 1.0);
	COLOR = vec4(col * alpha, alpha);
}

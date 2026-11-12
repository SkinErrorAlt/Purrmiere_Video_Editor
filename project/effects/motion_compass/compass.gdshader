shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_motion_kit/kit.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D flow_tex : filter_nearest, repeat_disable;
uniform sampler2D global_tex : filter_nearest, repeat_disable;
uniform vec2 tex_size = vec2(2.0);
uniform float px_scale = 1.0;
uniform int look = 0;
uniform float full_speed = 6.0;
uniform float ignore_under = 0.7;
uniform bool camera = true;
uniform float turn = 0.0;
uniform float colour_strength = 0.85;
uniform float keep_still = 0.6;

void fragment() {
	vec2 out_size = vec2(textureSize(effect_tex, 0));
	float ps = max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
	vec4 src = texture(effect_tex, UV);
	float a = src.a;
	vec3 pic = a > 0.0001 ? src.rgb / a : vec3(0.0);
	vec2 v = motion_guided(flow_tex, effect_tex, UV, 60.0);
	if (camera) {
		v -= kit_global(global_tex, UV);
	}
	float speed = length(v) / ps;
	float s = sqrt(smoothstep(ignore_under, max(full_speed, ignore_under + 0.01), speed));
	float s_soft = smoothstep(ignore_under, ignore_under + 0.35 * max(full_speed - ignore_under, 0.01), speed);
	float ang = atan(v.y, v.x) + radians(turn);
	vec3 lab = kit_srgb_to_oklab(pic);
	vec3 outc;
	if (look == 1) {
		vec3 hue = kit_heading_colour(ang, 0.80, 0.16 * colour_strength + 0.02);
		outc = hue * (0.08 + 0.92 * s) * step(0.0001, s_soft) * s_soft;
	} else if (look == 2) {
		vec2 px = ps / out_size;
		float gx = 0.0;
		float gy = 0.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				float l = kit_luma(texture(effect_tex, UV + vec2(float(i), float(j)) * px).rgb);
				float wx = float(i) * (j == 0 ? 2.0 : 1.0);
				float wy = float(j) * (i == 0 ? 2.0 : 1.0);
				gx += l * wx;
				gy += l * wy;
			}
		}
		float edge = clamp(length(vec2(gx, gy)) * 1.6, 0.0, 1.0);
		vec3 hue = kit_heading_colour(ang, 0.82, 0.17 * colour_strength + 0.02);
		vec3 base = pic * pic * keep_still * 0.45;
		outc = base + hue * (edge * 1.6 + 0.18) * s_soft * (0.35 + 0.65 * s);
		outc = 1.0 - exp(-outc * 1.15);
	} else {
		float lit = mix(lab.x * mix(1.0, 0.82, 1.0 - keep_still), mix(lab.x, 0.5 + 0.42 * lab.x, 0.55), s_soft);
		float chroma = (0.04 + 0.17 * s) * s_soft * colour_strength;
		vec3 moving = kit_oklab_to_srgb(vec3(lit, chroma * cos(ang), chroma * sin(ang)));
		vec3 still = kit_oklab_to_srgb(vec3(lab.x * mix(1.0, 0.82, 1.0 - keep_still), 0.0, 0.0));
		outc = mix(still, moving, s_soft);
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}

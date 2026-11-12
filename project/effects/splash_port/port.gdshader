shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float level = 0.56;
uniform float strength = 1.0;
uniform float murk = 0.45;
uniform vec4 water : source_color = vec4(0.07, 0.33, 0.36, 1.0);
uniform float magnify = 1.12;
uniform float clip_time = 0.0;

float surface(float x, vec2 m1, vec2 m2, vec2 bob, float chop) {
	float a1 = clamp(-m1.x * 3.2, -0.35, 0.35);
	float a2 = clamp(m2.x * 1.4, -0.15, 0.15);
	float y = level + bob.y * 0.9 - a1 * cos(3.14159 * x) - a2 * cos(6.28318 * x);
	float t = clip_time;
	y += chop * (0.006 * sin(x * 31.0 - t * 5.3) + 0.004 * sin(x * 57.0 + t * 7.1) + 0.0025 * sin(x * 103.0 - t * 11.0));
	return y;
}

vec3 under(vec2 uv, float ys, float depth, float chop, vec2 px) {
	vec2 c = vec2(0.5 + (uv.x - 0.5) / magnify, ys + (uv.y - ys) / magnify);
	float t = clip_time;
	c += vec2(sin(uv.y * 40.0 + t * 2.1), cos(uv.x * 33.0 - t * 1.7)) * (0.005 * chop);
	vec3 acc = vec3(0.0);
	float r = (1.5 + 5.0 * murk * depth) ;
	for (int i = 0; i < 6; i++) {
		float an = float(i) * 1.0472;
		acc += texture(effect_tex, clamp(c + vec2(cos(an), sin(an)) * r * px, vec2(0.0), vec2(1.0))).rgb;
	}
	acc = acc / 6.0;
	vec3 lin = acc * acc;
	lin *= vec3(0.62, 0.9, 1.0);
	vec3 w = water.rgb * water.rgb;
	float haze = clamp(murk * (0.35 + 0.9 * depth), 0.0, 0.95);
	lin = mix(lin, w * (0.6 + 0.6 * dot(lin, vec3(0.33))), haze);
	return sqrt(max(lin, vec3(0.0)));
}

void fragment() {
	vec2 sz = vec2(textureSize(effect_tex, 0));
	vec2 px = 1.0 / sz;
	vec2 m1 = fp_x(TEXTURE, 16) * strength;
	vec2 m2 = fp_x(TEXTURE, 17) * strength;
	vec2 bob = fp_x(TEXTURE, 18) * strength;
	float chop = clamp(length(fp_v(TEXTURE, 16)) * strength * 2.0, 0.0, 1.0);
	float ys = surface(UV.x, m1, m2, bob, chop);
	float slope = (surface(UV.x + px.x * 4.0, m1, m2, bob, chop) - surface(UV.x - px.x * 4.0, m1, m2, bob, chop)) / (8.0 * px.x) * (sz.y / sz.x);
	float d = UV.y - ys;
	float th = 2.5 * px.y;
	vec4 src = texture(effect_tex, UV);
	vec3 col;
	if (d < 0.0) {
		float men = 1.0 - smoothstep(0.0, 0.018 + 0.01 * chop, -d);
		vec2 bent = UV + vec2(0.0, men * men * 0.012);
		col = texture(effect_tex, bent).rgb;
		col = mix(col, col * 0.86 + 0.14, men * men * 0.35);
		col *= 1.0 - 0.25 * smoothstep(0.004, 0.0, -d);
	} else {
		float depth = clamp(d / max(1.0 - ys, 0.05), 0.0, 1.0);
		col = under(UV, ys, depth, chop, px);
		float tir = 1.0 - smoothstep(0.0, 0.03 + 0.03 * chop, d);
		vec2 mir = vec2(UV.x + slope * d, ys + d * 2.5 + 0.01);
		vec3 refl = under(mir, ys, clamp(depth + 0.2, 0.0, 1.0), chop, px);
		col = mix(col, refl * 1.15 + 0.06, tir * 0.55);
	}
	float line = exp(-pow(d / th, 2.0));
	float lip = exp(-pow((d + th * 1.6) / (th * 0.8), 2.0));
	col = mix(col, col * 0.35, line * 0.7);
	col += vec3(0.85, 0.95, 1.0) * lip * 0.45;
	COLOR = vec4(clamp(col, 0.0, 1.0) * src.a, src.a);
}

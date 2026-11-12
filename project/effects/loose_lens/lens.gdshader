shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float strength = 1.2;
uniform float soften = 14.0;
uniform float fringe = 0.5;
uniform float shift = 0.25;
uniform float px_scale = 1.0;

void fragment() {
	vec2 x = fp_x(TEXTURE, 0) * strength;
	vec4 src = texture(effect_tex, UV);
	if (x == vec2(0.0)) {
		COLOR = src;
	} else {
		vec2 sz = vec2(textureSize(effect_tex, 0));
		float asp = sz.x / sz.y;
		vec2 e = x / 0.02;
		float el = length(e);
		float k = el / (1.0 + 0.35 * el);
		vec2 dir = e / max(el, 1e-6);
		vec2 p = (UV - 0.5) * vec2(asp, 1.0);
		float side = dot(p / (0.5 * vec2(asp, 1.0)), dir);
		float blur = soften * px_scale * k * smoothstep(-0.6, 1.0, side) * (0.35 + 0.65 * clamp(length(p) * 1.6, 0.0, 1.0));
		vec2 base = UV - x * shift;
		vec2 pxs = 1.0 / sz;
		vec2 ca = dir * k * fringe * 4.0 * px_scale * pxs * (0.3 + length(p));
		vec3 acc = vec3(0.0);
		float wsum = 0.0;
		for (int i = 0; i < 24; i++) {
			float fi = float(i);
			float rr = sqrt((fi + 0.5) / 24.0);
			float an = fi * 2.39996;
			vec2 o = vec2(cos(an), sin(an)) * rr * blur * pxs;
			vec2 q = base + o;
			float r = texture(effect_tex, clamp(q + ca, vec2(0.0), vec2(1.0))).r;
			float g = texture(effect_tex, clamp(q, vec2(0.0), vec2(1.0))).g;
			float b = texture(effect_tex, clamp(q - ca, vec2(0.0), vec2(1.0))).b;
			acc += vec3(r, g, b);
			wsum += 1.0;
		}
		vec3 col = acc / wsum;
		col *= 1.0 - 0.28 * k * smoothstep(0.2, 1.2, side) * clamp(length(p) * 1.5, 0.0, 1.0);
		COLOR = vec4(clamp(col, 0.0, 1.0) * src.a, src.a);
	}
}

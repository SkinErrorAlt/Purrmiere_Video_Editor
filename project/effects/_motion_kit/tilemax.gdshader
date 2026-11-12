shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_motion_kit/kit.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D flow_tex : filter_nearest, repeat_disable;
uniform sampler2D global_tex : filter_nearest, repeat_disable;
uniform vec2 tex_size = vec2(2.0);
uniform float px_scale = 1.0;
uniform bool camera = true;
uniform float ignore_under = 1.0;

void fragment() {
	vec2 fsz = vec2(textureSize(flow_tex, 0));
	vec2 osz = 1.0 / max(fwidth(UV), vec2(1e-6));
	float ps = max(px_scale * float(textureSize(effect_tex, 0).x) / max(tex_size.x, 1.0), 0.0001);
	vec2 per = fsz / osz;
	vec2 lo = floor(UV * osz) * per;
	float gate = max(ignore_under, 0.3) * ps;
	vec2 vs[64];
	vec2 best = vec2(0.0);
	float bl = 0.0;
	for (int j = 0; j < 8; j++) {
		for (int i = 0; i < 8; i++) {
			vec2 p = lo + (vec2(float(i), float(j)) + 0.5) * per / 8.0;
			vec2 v = -flow_fetch(flow_tex, ivec2(floor(p))) - (camera ? kit_global(global_tex, p / fsz) : vec2(0.0));
			vs[j * 8 + i] = v;
			float l = length(v);
			if (l > bl) {
				bl = l;
				best = v;
			}
		}
	}
	vec2 acc = vec2(0.0);
	float n = 0.0;
	if (bl > gate) {
		for (int k = 0; k < 64; k++) {
			vec2 v = vs[k];
			float l = length(v);
			if (l > gate && dot(v, best) > 0.8 * l * bl && l > 0.4 * bl) {
				acc += v;
				n += 1.0;
			}
		}
	}
	vec2 outv = n >= 16.0 ? acc / n : vec2(0.0);
	COLOR = flow_encode(-outv);
}

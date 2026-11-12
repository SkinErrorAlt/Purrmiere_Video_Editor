shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_motion_kit/kit.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D flow_tex : filter_nearest, repeat_disable;
uniform sampler2D global_tex : filter_nearest, repeat_disable;
uniform vec2 tex_size = vec2(2.0);
uniform float px_scale = 1.0;
uniform float ignore_under = 0.6;
uniform float full_at = 3.0;
uniform bool camera = true;

void fragment() {
	float ps = max(px_scale * float(textureSize(effect_tex, 0).x) / max(tex_size.x, 1.0), 0.0001);
	vec2 g = camera ? kit_global(global_tex, UV) : vec2(0.0);
	vec2 fsz = vec2(textureSize(flow_tex, 0));
	vec2 osz = 1.0 / max(fwidth(UV), vec2(1e-6));
	vec2 per = fsz / osz;
	vec2 lo = floor(UV * osz) * per;
	float best = 0.0;
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			vec2 p = lo + (vec2(float(i), float(j)) + 0.5) * per / 2.0;
			best = max(best, length(-flow_fetch(flow_tex, ivec2(floor(p))) - g));
		}
	}
	float m = smoothstep(ignore_under, max(full_at, ignore_under + 0.01), best / ps);
	COLOR = vec4(m, m, m, 1.0);
}

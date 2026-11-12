shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/pixel_motion_blur/flow.gdshaderinc"

uniform sampler2D flow_tex : filter_nearest, repeat_disable;
uniform sampler2D luma_tex : filter_linear, repeat_disable;
uniform sampler2D global_tex : filter_nearest, repeat_disable;

float patch_cost(vec2 size, vec2 c, vec2 d) {
	float s = 0.0;
	for (int oy = -2; oy <= 2; oy++) {
		for (int ox = -2; ox <= 2; ox++) {
			vec2 o = vec2(float(ox), float(oy)) * 1.5;
			s += abs(texture(luma_tex, (c + o) / size).r - texture(luma_tex, (c + d + o) / size).g);
		}
	}
	return s / 25.0;
}

void fragment() {
	vec2 size = vec2(textureSize(luma_tex, 0));
	vec2 fsz = vec2(textureSize(flow_tex, 0));
	ivec2 q = ivec2(floor(UV * fsz));
	vec2 f = flow_fetch(flow_tex, q);
	vec2 g = flow_at(global_tex, UV);
	float k = 0.5;
	vec2 c = floor(UV * size) + 0.5;
	float cv = patch_cost(size, c, f * k);
	float cg = patch_cost(size, c, g * k);
	float keep = 1.0 - smoothstep(0.85, 1.0, cv / max(cg, 1e-4) + 0.0);
	keep *= smoothstep(0.010, 0.022, cg);
	COLOR = flow_encode(mix(g, f, keep));
}

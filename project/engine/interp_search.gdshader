shader_type canvas_item;
render_mode blend_disabled;

#include "res://engine/interp_flow.gdshaderinc"

uniform sampler2D luma_tex : filter_linear, repeat_disable;
uniform vec2 size = vec2(2.0);
uniform float w = 0.5;
uniform int radius = 6;
uniform float lambda = 0.004;
uniform float scale = 8.0;
uniform int patch = 2;

void fragment() {
	vec2 c = floor(UV * size) + 0.5;
	float best = 1e9;
	vec2 bd = vec2(0.0);
	for (int dy = -radius; dy <= radius; dy++) {
		for (int dx = -radius; dx <= radius; dx++) {
			vec2 d = vec2(float(dx), float(dy));
			float cost = flow_cost(luma_tex, size, c, d, w, lambda, patch);
			if (cost < best) {
				best = cost;
				bd = d;
			}
		}
	}
	COLOR = flow_encode(bd * scale);
}

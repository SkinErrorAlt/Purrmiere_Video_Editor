shader_type canvas_item;
render_mode blend_disabled;

#include "res://engine/interp_flow.gdshaderinc"

uniform sampler2D luma_tex : filter_linear, repeat_disable;
uniform sampler2D prev_tex : filter_nearest, repeat_disable;
uniform vec2 size = vec2(2.0);
uniform vec2 prev_size = vec2(2.0);
uniform float w = 0.5;
uniform float lambda = 0.004;
uniform float scale = 4.0;
uniform bool half_step = false;
uniform int patch = 1;

void fragment() {
	vec2 c = floor(UV * size) + 0.5;
	ivec2 qi = ivec2(floor(c * prev_size / size));
	ivec2 hi = ivec2(prev_size) - ivec2(1);
	float best = 1e9;
	vec2 bd = vec2(0.0);
	for (int ny = -1; ny <= 1; ny++) {
		for (int nx = -1; nx <= 1; nx++) {
			ivec2 q = clamp(qi + ivec2(nx, ny), ivec2(0), hi);
			vec2 d = flow_decode(texelFetch(prev_tex, q, 0)) / scale;
			float cost = flow_cost(luma_tex, size, c, d, w, lambda, patch);
			if (cost < best) {
				best = cost;
				bd = d;
			}
		}
	}
	float cz = flow_cost(luma_tex, size, c, vec2(0.0), w, lambda, patch);
	if (cz < best) {
		best = cz;
		bd = vec2(0.0);
	}
	vec2 base = bd;
	for (int sy = -1; sy <= 1; sy++) {
		for (int sx = -1; sx <= 1; sx++) {
			if (sx == 0 && sy == 0) {
				continue;
			}
			vec2 d = base + vec2(float(sx), float(sy));
			float cost = flow_cost(luma_tex, size, c, d, w, lambda, patch);
			if (cost < best) {
				best = cost;
				bd = d;
			}
		}
	}
	if (half_step) {
		base = bd;
		for (int sy = -1; sy <= 1; sy++) {
			for (int sx = -1; sx <= 1; sx++) {
				if (sx == 0 && sy == 0) {
					continue;
				}
				vec2 d = base + 0.5 * vec2(float(sx), float(sy));
				float cost = flow_cost(luma_tex, size, c, d, w, lambda, patch);
				if (cost < best) {
					best = cost;
					bd = d;
				}
			}
		}
	}
	COLOR = flow_encode(bd * scale);
}

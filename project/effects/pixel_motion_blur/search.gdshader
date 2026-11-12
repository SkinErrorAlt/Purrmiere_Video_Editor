shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/pixel_motion_blur/flow.gdshaderinc"

uniform int radius = 6;
uniform float lambda = 0.004;
uniform float level_scale = 16.0;
uniform int patch = 2;

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 c = floor(UV * size) + 0.5;
	float best = flow_cost(TEXTURE, size, c, vec2(0.0), lambda, patch) - 0.02;
	vec2 bd = vec2(0.0);
	for (int dy = -radius; dy <= radius; dy++) {
		for (int dx = -radius; dx <= radius; dx++) {
			vec2 d = vec2(float(dx), float(dy));
			float cost = flow_cost(TEXTURE, size, c, d, lambda, patch);
			if (cost < best) {
				best = cost;
				bd = d;
			}
		}
	}
	COLOR = flow_encode(bd * level_scale);
}

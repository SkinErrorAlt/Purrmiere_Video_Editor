shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_motion_kit/kit.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float px_scale = 1.0;
uniform vec2 tex_size = vec2(2.0);
uniform float reach_px = 120.0;
uniform float length_gain = 8.0;

void fragment() {
	vec2 tsz = vec2(textureSize(TEXTURE, 0));
	float full_w = float(textureSize(effect_tex, 0).x);
	float ps = max(px_scale * full_w / max(tex_size.x, 1.0), 0.0001);
	float tile_px = full_w / tsz.x;
	int r = clamp(int(ceil(reach_px * ps / tile_px)), 1, 6);
	ivec2 c = ivec2(floor(UV * tsz));
	vec2 best = vec2(0.0);
	float bl = 0.0;
	for (int j = -6; j <= 6; j++) {
		for (int i = -6; i <= 6; i++) {
			if (abs(i) > r || abs(j) > r) {
				continue;
			}
			vec2 v = -flow_fetch(TEXTURE, c + ivec2(i, j));
			float l = length(v);
			float dist = length(vec2(float(i), float(j))) * tile_px;
			if (dist > min(l * length_gain, reach_px * ps) + tile_px * 1.5) {
				continue;
			}
			if (l > bl) {
				bl = l;
				best = v;
			}
		}
	}
	COLOR = flow_encode(-best);
}

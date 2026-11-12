shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D atlas_tex : filter_nearest, repeat_disable;
uniform sampler2D glob_tex : filter_nearest, repeat_disable;

void fragment() {
	vec2 osz = fp_out_size(UV);
	ivec2 p = ivec2(floor(UV * osz));
	int pairs = fp_pairs(glob_tex);
	if (p.y == 1 && p.x == 0) {
		COLOR = vec4(float(pairs) / 255.0, 0.0, 0.0, 1.0);
	} else if (p.y != 0 || p.x >= pairs) {
		COLOR = fp_pack2(vec2(0.0), FP_DRANGE);
	} else {
		ivec2 fs = fp_flow_size(textureSize(atlas_tex, 0));
		int a = p.x;
		int sx = max(1, fs.x / 32);
		int sy = max(1, fs.y / 18);
		vec2 m = vec2(0.0);
		for (int it = 0; it < 3; it++) {
			vec2 acc = vec2(0.0);
			float wsum = 0.0;
			for (int y = 0; y < 64; y++) {
				if (y * sy >= fs.y) {
					break;
				}
				for (int x = 0; x < 64; x++) {
					if (x * sx >= fs.x) {
						break;
					}
					vec3 f = fp_flow(TEXTURE, a, ivec2(x * sx, y * sy), fs);
					float d = length(f.xy - m) / FP_FRANGE;
					float w = (it == 0 ? 1.0 : 1.0 / (1.0 + d * d * 400.0)) * fp_flow_trust(TEXTURE, a, ivec2(x * sx, y * sy), fs);
					acc += f.xy * w;
					wsum += w;
				}
			}
			m = acc / max(wsum, 1e-6);
		}
		COLOR = fp_pack2(m, FP_DRANGE);
	}
}

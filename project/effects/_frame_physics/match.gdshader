shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D atlas_tex : filter_nearest, repeat_disable;
uniform sampler2D prof_tex : filter_nearest, repeat_disable;

void fragment() {
	vec2 osz = fp_out_size(UV);
	ivec2 p = ivec2(floor(UV * osz));
	int pairs = min(history_count, FP_MAX_PAIRS);
	int a = p.y / 2;
	bool cols = p.y % 2 == 0;
	int s = p.x - FP_SMAX;
	if (p.x > 2 * FP_SMAX || a >= pairs) {
		COLOR = vec4(fp_pack(1.0), 0.0, 1.0);
	} else {
		ivec2 ts = fp_tile_size(textureSize(atlas_tex, 0));
		int n = cols ? ts.x / ((ts.x + FP_NX - 1) / FP_NX) : ts.y / ((ts.y + FP_NY - 1) / FP_NY);
		int smax = clamp(int(ceil(float(n) * 0.16)), 1, FP_SMAX);
		if (abs(s) > smax) {
			COLOR = vec4(fp_pack(1.0), 0.0, 1.0);
		} else {
			int lo = max(0, s);
			int hi = min(n, n + s);
			float ma = 0.0;
			float mb = 0.0;
			for (int b = 0; b < FP_NX; b++) {
				if (b < lo || b >= hi) {
					continue;
				}
				ma += fp_prof(prof_tex, a, b, cols);
				mb += fp_prof(prof_tex, a + 1, b - s, cols);
			}
			float cnt = float(max(hi - lo, 1));
			ma /= cnt;
			mb /= cnt;
			float ssd = 0.0;
			for (int b = 0; b < FP_NX; b++) {
				if (b < lo || b >= hi) {
					continue;
				}
				float d = (fp_prof(prof_tex, a, b, cols) - ma) - (fp_prof(prof_tex, a + 1, b - s, cols) - mb);
				ssd += d * d;
			}
			float c = ssd / cnt + 0.0004 * abs(float(s)) / float(n);
			COLOR = vec4(fp_pack(sqrt(min(c, 1.0))), 0.0, 1.0);
		}
	}
}

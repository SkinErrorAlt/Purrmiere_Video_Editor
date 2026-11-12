shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_frame_physics/fp.gdshaderinc"

uniform sampler2D atlas_tex : filter_nearest, repeat_disable;

void fragment() {
	vec2 osz = fp_out_size(UV);
	ivec2 p = ivec2(floor(UV * osz));
	ivec2 ts = fp_tile_size(textureSize(atlas_tex, 0));
	int top = min(history_count, FP_MAX_PAIRS);
	int bx = (ts.x + FP_NX - 1) / FP_NX;
	int nx = ts.x / bx;
	int by = (ts.y + FP_NY - 1) / FP_NY;
	int ny = ts.y / by;
	bool cols = p.y < 64;
	int age = cols ? p.y : p.y - 64;
	int i = p.x;
	if (age > top || p.y >= 128 || (cols && i >= nx) || (!cols && i >= ny)) {
		COLOR = vec4(0.0);
	} else {
		float sum = 0.0;
		float k = 0.0;
		if (cols) {
			int rstep = max(1, ts.y / 64);
			for (int x = i * bx; x < i * bx + bx; x++) {
				for (int y = 0; y < 1024; y += rstep) {
					if (y >= ts.y) {
						break;
					}
					sum += fp_luma(atlas_tex, age, ivec2(x, y), ts);
					k += 1.0;
				}
			}
		} else {
			int cstep = max(1, ts.x / 128);
			for (int y = i * by; y < i * by + by; y++) {
				for (int x = 0; x < 2048; x += cstep) {
					if (x >= ts.x) {
						break;
					}
					sum += fp_luma(atlas_tex, age, ivec2(x, y), ts);
					k += 1.0;
				}
			}
		}
		COLOR = vec4(fp_pack(sum / max(k, 1.0)), 0.0, 1.0);
	}
}

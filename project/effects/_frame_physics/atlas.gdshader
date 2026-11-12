shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/_frame_physics/fp.gdshaderinc"

float luma(vec4 c) {
	return dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 osz = fp_out_size(UV);
	ivec2 ts = fp_tile_size(ivec2(osz));
	ivec2 p = ivec2(floor(UV * osz));
	ivec2 tile = p / ts;
	int age = tile.y * FP_GRID + tile.x;
	int top = min(history_count, FP_MAX_PAIRS);
	if (tile.x >= FP_GRID || tile.y >= FP_GRID || age > top) {
		COLOR = vec4(0.0);
	} else {
		ivec2 l = p - tile * ts;
		vec2 cell = 1.0 / vec2(ts);
		vec2 c = (vec2(l) + 0.5) * cell;
		float acc = 0.0;
		for (int j = 0; j < 4; j++) {
			for (int i = 0; i < 4; i++) {
				vec2 uv = c + ((vec2(float(i), float(j)) + 0.5) * 0.25 - 0.5) * cell;
				vec4 now = texture(TEXTURE, uv);
				acc += luma(age == 0 ? now : history_frame(age, uv, now));
			}
		}
		bool ok = age == 0 || history_has(age);
		COLOR = vec4(fp_pack(acc / 16.0), ok ? 1.0 : 0.0, 1.0);
	}
}

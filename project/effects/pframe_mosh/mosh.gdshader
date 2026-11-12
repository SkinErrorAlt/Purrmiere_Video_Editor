shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"
#include "res://effects/pframe_mosh/mosh.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int kind = 0;

vec4 frame_at(int k, vec2 uv) {
	vec4 n = texture(effect_tex, uv);
	return k <= 0 ? n : history_frame(k, uv, n);
}

void fragment() {
	vec2 size = vec2(textureSize(effect_tex, 0));
	vec4 now_c = texture(effect_tex, UV);
	int age = mosh_age();
	if (age <= 0) {
		COLOR = now_c;
	} else {
		ivec2 isz = ivec2(textureSize(TEXTURE, 0));
		ivec2 tile = isz / TILES;
		float bp = block_px(size);
		ivec2 nb = ivec2(ceil(size / bp));
		float r = mv_range();
		vec2 p = FRAGCOORD.xy;
		bool done = false;
		vec4 result = now_c;
		for (int k = 0; k < 62; k++) {
			if (k >= age) {
				break;
			}
			int tk = kind == 1 ? 0 : k;
			ivec2 b = clamp(ivec2(floor(p / bp)), ivec2(0), nb - ivec2(1));
			ivec2 tc = ivec2(tk % TILES, tk / TILES);
			vec4 v = texelFetch(TEXTURE, tc * tile + b, 0);
			if (kind == 0 && v.b > 0.5) {
				result = frame_at(k, clamp(p / size, vec2(0.0), vec2(1.0)));
				done = true;
				break;
			}
			vec2 d = (v.rg - 0.5) * 2.0 * r;
			p = clamp(p + d, vec2(0.5), size - 0.5);
		}
		if (!done) {
			result = frame_at(age, p / size);
		}
		COLOR = result;
	}
}

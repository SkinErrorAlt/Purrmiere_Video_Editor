shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform float window : hint_range(0.1, 2.0) = 0.5;

vec3 lin(vec3 c) {
	return c * c;
}

vec3 region(sampler2D tex, int k, vec2 uv, vec2 cell) {
	vec3 acc = vec3(0.0);
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 4; i++) {
			vec2 q = uv + (vec2(float(i), float(j)) - 1.5) * 0.25 * cell;
			vec4 n = texture(tex, q);
			vec4 c = k == 0 ? n : history_frame(k, q, n);
			acc += lin(c.rgb);
		}
	}
	return acc / 16.0 + vec3(0.0004);
}

void fragment() {
	vec2 cell = SCREEN_PIXEL_SIZE;
	vec3 m0 = region(TEXTURE, 0, UV, cell);
	int n = clamp(int(round(window * history_fps)), 1, 62);
	n = min(n, history_count);
	vec3 lr = vec3(0.0);
	float wsum = 0.0;
	for (int k = 1; k <= 62; k++) {
		if (k > n) {
			break;
		}
		vec3 mk = region(TEXTURE, k, UV, cell);
		lr += log2(mk / m0);
		wsum += 1.0;
	}
	vec3 g = wsum > 0.0 ? lr / wsum : vec3(0.0);
	COLOR = vec4(clamp(0.5 + g / 4.0, 0.0, 1.0), 1.0);
}

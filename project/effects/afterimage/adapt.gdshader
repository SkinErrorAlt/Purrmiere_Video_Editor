shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform float memory : hint_range(0.2, 2.0) = 1.6;
uniform vec2 tex_size = vec2(2.0);

vec3 soft(sampler2D tex, int k, vec2 uv, vec2 px) {
	vec3 acc = vec3(0.0);
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			vec2 q = uv + (vec2(float(i), float(j)) - 0.5) * 2.0 * px;
			vec4 n = texture(tex, q);
			vec4 c = k == 0 ? n : history_frame(k, q, n);
			acc += c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
		}
	}
	return acc * 0.25;
}

void fragment() {
	vec2 px = 1.0 / tex_size;
	vec3 now = soft(TEXTURE, 0, UV, px);
	float reach = min(memory * history_fps, float(history_count));
	float tau = max(reach / 3.0, 1.0);
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	if (reach >= 2.0) {
		for (int i = 0; i < 24; i++) {
			float age = 2.0 + (reach - 2.0) * float(i) / 23.0;
			int k = int(round(age));
			float w = exp(-(age - 2.0) / tau);
			acc += soft(TEXTURE, k, UV, px) * w;
			wsum += w;
		}
	}
	vec3 adapted = wsum > 0.0 ? acc / wsum : now;
	vec3 f = max(adapted - now, vec3(0.0));
	COLOR = vec4(clamp(f, 0.0, 1.0), 1.0);
}

shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform float span : hint_range(0.2, 2.0) = 2.0;
uniform int samples : hint_range(4, 40) = 24;
uniform float threshold : hint_range(0.0, 0.3) = 0.03;
uniform float sensitivity : hint_range(0.1, 10.0) = 2.5;
uniform float memory : hint_range(0.0, 1.0) = 0.5;
uniform vec2 tex_size = vec2(2.0);

vec3 soft(sampler2D tex, int k, vec2 uv, vec2 px, vec4 now) {
	vec3 acc = vec3(0.0);
	for (int j = 0; j < 2; j++) {
		for (int i = 0; i < 2; i++) {
			vec2 q = uv + (vec2(float(i), float(j)) - 0.5) * 2.0 * px;
			acc += (k == 0 ? texture(tex, q) : history_frame(k, q, now)).rgb;
		}
	}
	return acc * 0.25;
}

void fragment() {
	vec2 px = 1.0 / tex_size;
	vec4 now = texture(TEXTURE, UV);
	float reach = min(span * history_fps, float(history_count) - 1.0);
	int n = clamp(samples, 4, 40);
	float acc = 0.0;
	float wsum = 0.0;
	if (reach >= 1.0) {
		for (int i = 0; i < 40; i++) {
			if (i >= n) {
				break;
			}
			int a = int(round(reach * float(i) / float(n - 1)));
			vec3 x = soft(TEXTURE, a, UV, px, now);
			vec3 y = soft(TEXTURE, a + 1, UV, px, now);
			vec3 d = abs(x - y);
			float e = max(max(d.r, d.g), d.b);
			e = max(e - threshold, 0.0) / max(1.0 - threshold, 0.01);
			float age01 = float(i) / float(n - 1);
			float w = mix(1.0, exp(-age01 * 3.0), 1.0 - memory);
			acc += e * w;
			wsum += w;
		}
	}
	float heat = wsum > 0.0 ? acc / wsum : 0.0;
	heat = 1.0 - exp(-heat * sensitivity * 12.0);
	COLOR = vec4(heat, heat, heat, 1.0);
}

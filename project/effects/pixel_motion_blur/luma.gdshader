shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform int stage = 0;
uniform vec2 tex_size = vec2(2.0);
uniform float age = 1.0;

float luma(vec4 c) {
	return dot(c.rgb, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	if (stage == 0) {
		vec2 px = 1.0 / tex_size;
		vec2 acc = vec2(0.0);
		for (int j = 0; j < 2; j++) {
			for (int i = 0; i < 2; i++) {
				vec2 uv = UV + (vec2(float(i), float(j)) - 0.5) * px;
				vec4 n = texture(TEXTURE, uv);
				acc += vec2(luma(n), luma(history_between(age, uv, n)));
			}
		}
		COLOR = vec4(acc * 0.25, 0.0, 1.0);
	} else {
		COLOR = vec4(texture(TEXTURE, UV).rg, 0.0, 1.0);
	}
}

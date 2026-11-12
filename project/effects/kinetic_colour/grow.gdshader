shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(2.0);
uniform float grow : hint_range(0.0, 4.0) = 1.5;
uniform int stage = 0;

void fragment() {
	vec2 px = 1.0 / tex_size;
	float v = 0.0;
	if (stage == 0) {
		for (int j = -2; j <= 2; j++) {
			for (int i = -2; i <= 2; i++) {
				vec2 o = vec2(float(i), float(j));
				if (length(o) > 2.3) {
					continue;
				}
				v = max(v, texture(TEXTURE, UV + o * px * grow * 0.5).r);
			}
		}
	} else {
		float wsum = 0.0;
		for (int j = -3; j <= 3; j++) {
			for (int i = -3; i <= 3; i++) {
				float w = exp(-float(i * i + j * j) / 5.0);
				v += texture(TEXTURE, UV + vec2(float(i), float(j)) * px).r * w;
				wsum += w;
			}
		}
		v /= wsum;
	}
	COLOR = vec4(v, v, v, 1.0);
}

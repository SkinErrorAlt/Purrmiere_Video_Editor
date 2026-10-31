shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D sign_tex : filter_nearest, repeat_disable;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float acc = 0.0;
	for (int j = 0; j < 16; j++) {
		for (int i = 0; i < 16; i++) {
			vec2 q = (vec2(float(i), float(j)) + 0.5) / 16.0;
			vec2 s = texture(sign_tex, q).rg;
			float v = floor(s.r * 255.0 + 0.5) * 256.0 + floor(s.g * 255.0 + 0.5);
			acc = fract(acc + hash12(vec2(v + 0.5, float(j * 16 + i) + 0.5)));
		}
	}
	float bits = floor(clamp(acc, 0.0, 0.999985) * 65536.0);
	float hi = floor(bits / 256.0);
	float lo = bits - hi * 256.0;
	COLOR = vec4(hi / 255.0, lo / 255.0, 0.0, 1.0);
}

shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_nearest, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float cut_scale : hint_range(4.0, 120.0) = 26.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float ps = max(px_scale, 0.0001);
	vec2 src = max(max(tex_size, vec2(1.0)) / ps, vec2(1.0));
	float cs = max(cut_scale, 3.0 / ps);
	vec2 p = UV * src;
	vec2 node = floor(p / cs + 0.5) * cs;
	float lo = 0.0;
	float hi = 0.0;
	for (int j = 0; j < 6; j++) {
		for (int i = 0; i < 6; i++) {
			vec2 o = ((vec2(float(i), float(j)) + 0.5) / 6.0 - 0.5) * 1.3;
			vec2 q = (node + o * cs) / src;
			float a = texture(effect_tex, clamp(q, vec2(0.0), vec2(1.0))).a;
			float bit = a > 0.5 ? 1.0 : 0.0;
			if (j < 3) {
				lo = lo * 2.0 + bit;
			} else {
				hi = hi * 2.0 + bit;
			}
		}
	}
	float bits = floor(clamp(hash12(vec2(lo + 0.5, hi + 0.5)), 0.0, 0.999985) * 65536.0);
	float byte_hi = floor(bits / 256.0);
	float byte_lo = bits - byte_hi * 256.0;
	COLOR = vec4(byte_hi / 255.0, byte_lo / 255.0, 0.0, 1.0);
}

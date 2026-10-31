shader_type canvas_item;
render_mode blend_disabled;

uniform int mode = 0;
uniform float spread : hint_range(0.0, 50.0) = 4.0;
uniform float rate : hint_range(0.0, 1.0) = 1.0;
uniform float lower : hint_range(0.0, 1.0) = 0.0;
uniform float upper : hint_range(0.0, 1.0) = 1.0;
uniform bool to_left = true;
uniform bool to_right = true;
uniform bool to_top = true;
uniform bool to_bottom = true;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float value_of(vec4 c) {
	if (mode >= 2) {
		return c.a;
	}
	return c.a > 0.0001 ? dot(c.rgb / c.a, vec3(0.2126, 0.7152, 0.0722)) : 0.0;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	vec4 c = texture(TEXTURE, UV);
	float r = max(spread, 0.0) * max(px_scale, 0.0001);
	int n = int(clamp(ceil(r - 0.001), 0.0, 8.0));
	if (n == 0 || rate <= 0.0) {
		COLOR = c;
	} else {
		float stride = r / float(n);
		bool bigger = mode == 0 || mode == 2;
		vec4 best = c;
		float best_v = value_of(c);
		float lim = float(n * n) + 0.5;
		for (int j = -8; j <= 8; j++) {
			if (abs(j) > n) {
				continue;
			}
			if ((j > 0 && !to_bottom) || (j < 0 && !to_top)) {
				continue;
			}
			for (int i = -8; i <= 8; i++) {
				if (abs(i) > n || (i == 0 && j == 0)) {
					continue;
				}
				if ((i > 0 && !to_right) || (i < 0 && !to_left)) {
					continue;
				}
				if (float(i * i + j * j) > lim) {
					continue;
				}
				vec2 off = vec2(float(i), float(j)) * stride;
				vec2 uv = UV - off / dims;
				if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
					continue;
				}
				vec4 s = texture(TEXTURE, uv);
				float v = value_of(s);
				float l = s.a > 0.0001 ? dot(s.rgb / s.a, vec3(0.2126, 0.7152, 0.0722)) : 0.0;
				if (l < lower - 0.0001 || l > upper + 0.0001) {
					continue;
				}
				if ((bigger && v > best_v) || (!bigger && v < best_v)) {
					best = s;
					best_v = v;
				}
			}
		}
		COLOR = mix(c, best, clamp(rate, 0.0, 1.0));
	}
}

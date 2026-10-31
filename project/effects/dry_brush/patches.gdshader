shader_type canvas_item;
render_mode blend_disabled;

uniform float brush_size : hint_range(1.0, 20.0) = 6.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float r = max(brush_size * max(px_scale, 0.0001), 0.75);
	vec2 s = vec2(r * 0.5) / dims;
	vec4 m0 = vec4(0.0);
	vec4 m1 = vec4(0.0);
	vec4 m2 = vec4(0.0);
	vec4 m3 = vec4(0.0);
	vec4 sl = vec4(0.0);
	vec4 sq = vec4(0.0);
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec4 c = texture(TEXTURE, UV + vec2(float(x), float(y)) * s);
			float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722)) + c.a * 0.25;
			if (x <= 0 && y <= 0) {
				m0 += c;
				sl.x += l;
				sq.x += l * l;
			}
			if (x >= 0 && y <= 0) {
				m1 += c;
				sl.y += l;
				sq.y += l * l;
			}
			if (x <= 0 && y >= 0) {
				m2 += c;
				sl.z += l;
				sq.z += l * l;
			}
			if (x >= 0 && y >= 0) {
				m3 += c;
				sl.w += l;
				sq.w += l * l;
			}
		}
	}
	vec4 mean_l = sl / 9.0;
	vec4 sigma = sqrt(max(sq / 9.0 - mean_l * mean_l, vec4(0.0)));
	float smin = min(min(sigma.x, sigma.y), min(sigma.z, sigma.w));
	vec4 w = exp(-(sigma - smin) * 80.0);
	COLOR = (m0 * w.x + m1 * w.y + m2 * w.z + m3 * w.w) / (9.0 * max(w.x + w.y + w.z + w.w, 0.0001));
}

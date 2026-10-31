shader_type canvas_item;
render_mode blend_disabled;

uniform float brush_size : hint_range(1.0, 24.0) = 5.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float bp = max(brush_size, 0.5);
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec2 P = UV * dims / ps + so;
	vec2 np = P / (bp * 1.3);
	vec2 wob = vec2(vn(np), vn(np + 31.7)) - 0.5;
	vec2 uv = UV + wob * bp * 1.1 * ps / dims;
	float sp = bp * 0.5;
	vec4 m0 = vec4(0.0);
	vec4 m1 = vec4(0.0);
	vec4 m2 = vec4(0.0);
	vec4 m3 = vec4(0.0);
	vec4 sl = vec4(0.0);
	vec4 sq = vec4(0.0);
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 o = vec2(float(x), float(y)) * sp * ps / dims;
			vec4 s = texture(TEXTURE, clamp(uv + o, vec2(0.0), vec2(1.0)));
			float l = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722)) + s.a * 0.25;
			if (x <= 0 && y <= 0) {
				m0 += s;
				sl.x += l;
				sq.x += l * l;
			}
			if (x >= 0 && y <= 0) {
				m1 += s;
				sl.y += l;
				sq.y += l * l;
			}
			if (x <= 0 && y >= 0) {
				m2 += s;
				sl.z += l;
				sq.z += l * l;
			}
			if (x >= 0 && y >= 0) {
				m3 += s;
				sl.w += l;
				sq.w += l * l;
			}
		}
	}
	vec4 mean_l = sl / 9.0;
	vec4 sigma = sqrt(max(sq / 9.0 - mean_l * mean_l, vec4(0.0)));
	float smin = min(min(sigma.x, sigma.y), min(sigma.z, sigma.w));
	vec4 w = exp(-(sigma - smin) * 80.0);
	vec4 total = (m0 * w.x + m1 * w.y + m2 * w.z + m3 * w.w) / 9.0;
	COLOR = total / max(w.x + w.y + w.z + w.w, 0.0001);
}

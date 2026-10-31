shader_type canvas_item;
render_mode blend_disabled;

uniform float brush_size : hint_range(1.0, 16.0) = 5.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float brush_px = max(brush_size * ps, 1.0);
	vec2 so = seed_offset(seed);
	vec2 np = UV * dims / (brush_px * 4.0) + so;
	vec2 wob = vec2(value_noise(np) * 0.7 + value_noise(np * 2.3 + 7.1) * 0.3, value_noise(np + 19.7) * 0.7 + value_noise(np * 2.3 + 29.3) * 0.3) - 0.5;
	vec2 uv = UV + wob * 2.0 * wetness * brush_px / dims;
	float sp = brush_px * mix(0.4, 0.6, wetness);
	vec4 m0 = vec4(0.0);
	vec4 m1 = vec4(0.0);
	vec4 m2 = vec4(0.0);
	vec4 m3 = vec4(0.0);
	vec4 sq = vec4(0.0);
	vec4 sl = vec4(0.0);
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 o = vec2(float(x), float(y)) * sp / dims;
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
	vec4 w = exp(-(sigma - smin) * 60.0);
	vec4 total = (m0 * w.x + m1 * w.y + m2 * w.z + m3 * w.w) / 9.0;
	COLOR = total / max(w.x + w.y + w.z + w.w, 0.0001);
}

shader_type canvas_item;
render_mode blend_disabled;

uniform float drops : hint_range(0.5, 60.0) = 24.0;
uniform float ring_size : hint_range(10.0, 600.0) = 150.0;
uniform float ring_speed : hint_range(10.0, 1000.0) = 150.0;
uniform float strength : hint_range(0.0, 40.0) = 9.0;
uniform int rings : hint_range(1, 6) = 3;
uniform float crest : hint_range(0.0, 1.0) = 0.45;
uniform float perspective : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float time = 0.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec2 h22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

vec2 mirror_uv(vec2 uv) {
	return vec2(1.0) - abs(vec2(1.0) - mod(uv, vec2(2.0)));
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 S = dims / ps;
	float x = UV.x * S.x;
	float v = UV.y;
	float h0 = 0.22 / max(perspective, 0.0002);
	float sc = (v + h0) / (1.0 + h0);
	vec2 W = vec2((x - 0.5 * S.x) / sc, S.y * (1.0 + h0) * (1.0 - v) / (v + h0));
	float cs = max(ring_size, 4.0);
	float rate = max(drops, 0.01) * cs * cs / (S.x * S.y);
	float P = 1.0 / max(rate, 0.00001);
	float spd = max(ring_speed, 1.0);
	float lam = max(cs * 0.09, 4.0);
	float nr = float(clamp(rings, 1, 6));
	float life_cap = 5.0 * P;
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec2 cell = floor(W / cs);
	float t = time;
	float cur = floor(t / P);
	vec2 g = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cell + vec2(float(i), float(j));
			for (int k = 0; k < 6; k++) {
				float n = cur - float(k);
				if (float(k - 1) * P > life_cap) {
					break;
				}
				vec2 key = c + so + vec2(mod(n * 0.6180339, 1.0) * 517.0, mod(n * 0.4142135, 1.0) * 389.0);
				float t0 = (n + h12(key)) * P;
				float rmax = cs * mix(0.6, 1.0, h12(key + 5.3));
				float life = min((rmax + nr * lam) / spd, life_cap);
				float age = t - t0;
				if (age <= 0.0 || age >= life) {
					continue;
				}
				vec2 pos = (c + 0.08 + 0.84 * h22(key + 11.7)) * cs;
				vec2 d = W - pos;
				float r = length(d);
				float front = spd * age;
				float ph = (front - r) / lam;
				if (ph <= 0.0 || ph >= nr) {
					continue;
				}
				float x01 = age / life;
				float fade = (1.0 - x01) * (1.0 - 0.5 * x01) * smoothstep(0.0, 0.1, x01);
				float amp = fade / sqrt(1.0 + r / (8.0 * lam)) * smoothstep(0.0, lam, r);
				float wa = sin(3.14159265 * ph / nr);
				float w = wa * wa;
				float wd = 2.0 * wa * cos(3.14159265 * ph / nr) * 3.14159265 / nr;
				float slope = amp * (w * cos(6.2831853 * ph) + wd * sin(6.2831853 * ph) / 6.2831853);
				g += slope * d / max(r, 0.0001);
			}
		}
	}
	vec2 Dp = g * strength;
	float dv = -Dp.y * sc * sc / S.y;
	float dx = sc * Dp.x + (x - 0.5 * S.x) / ((1.0 + h0) * sc) * dv * S.y;
	vec2 uv = mirror_uv(UV + vec2(dx / S.x, dv));
	vec4 c0 = texture(TEXTURE, UV);
	vec4 cs4 = texture(TEXTURE, uv);
	float a = c0.a;
	vec3 col = cs4.a > 0.0001 ? clamp(cs4.rgb / cs4.a, 0.0, 1.0) : (a > 0.0001 ? clamp(c0.rgb / a, 0.0, 1.0) : vec3(0.0));
	float face = dot(g, normalize(vec2(0.25, 1.0)));
	float hl = crest * smoothstep(0.12, 0.85, face) * 0.6;
	col *= 1.0 - crest * 0.3 * smoothstep(0.15, 0.9, -face);
	col += (vec3(1.0) - col) * hl;
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}

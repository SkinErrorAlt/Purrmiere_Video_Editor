shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int pattern : hint_range(0, 4) = 0;
uniform float size : hint_range(4.0, 400.0) = 36.0;
uniform float refraction : hint_range(0.0, 2.0) = 1.0;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float highlight : hint_range(0.0, 1.0) = 0.4;
uniform vec4 tint : source_color = vec4(0.96, 0.99, 1.0, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

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

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec2 mirror_uv(vec2 uv) {
	return vec2(1.0) - abs(vec2(1.0) - mod(uv, vec2(2.0)));
}

vec3 fetch(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, mirror_uv(uv));
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

vec2 rib(float t, int pat, float refr) {
	if (pat == 1) {
		float d = clamp(t / sqrt(max(0.2601 - t * t, 0.0004)), -3.2, 3.2);
		return vec2(t - refr * (0.9 * t + 0.32 * d), d / 3.2);
	}
	float d = 3.0 * t + 4.0 * t * t * t;
	return vec2(t - refr * d, d / 2.0);
}

vec3 rib_colour(sampler2D tex, float ci, float t, vec2 C, vec2 ax, vec2 ay, float qy, float wob, float s, float ps, vec2 dims, float refr, int taps) {
	vec2 m = rib(t, pattern, refr);
	float slope = abs(1.0 - refr * (pattern == 1 ? 2.0 : 3.0 + 12.0 * t * t));
	float foot = clamp(slope / (s * ps), 0.0, 0.5);
	vec2 base = C + ax * ((ci + 0.5) * s - wob) + ay * qy;
	vec3 col = vec3(0.0);
	if (taps == 1) {
		col = fetch(tex, (base + ax * m.x * s) * ps / dims);
	} else {
		for (int k = -1; k <= 1; k++) {
			col += fetch(tex, (base + ax * (m.x + foot * float(k) * 0.6) * s) * ps / dims);
		}
		col /= 3.0;
	}
	float nx = m.y;
	float band = pattern == 1 ? 0.5 : 0.42;
	float spec = exp(-pow((nx + band) / 0.16, 2.0)) * 0.55;
	spec += exp(-pow((nx - 0.75) / 0.2, 2.0)) * 0.12;
	float left = (t + 0.5) * s * ps;
	float right = (0.5 - t) * s * ps;
	spec += exp(-left / max(0.9 * ps, 0.6)) * 0.9;
	float shade = 1.0 - highlight * 0.9 * exp(-right / max(1.4 * ps, 0.8));
	shade *= 1.0 - highlight * (pattern == 1 ? 0.45 : 0.2) * nx * nx;
	col *= tint.rgb * shade;
	col += (vec3(1.0) - col) * spec * highlight;
	return col;
}

vec3 dome_field(vec2 q0, float k, int pat, vec2 so) {
	float best = -1e9;
	float hs[18];
	vec2 gs[18];
	int n = 0;
	int layers = pat == 3 ? 1 : 2;
	for (int l = 0; l < 2; l++) {
		float ls = l == 0 ? 1.0 : 1.9;
		vec2 q = q0 * ls + float(l) * vec2(17.31, 9.73);
		vec2 cell = floor(q);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 c = cell + vec2(float(i), float(j));
				vec2 r2 = h22(c + so + float(l) * 31.7);
				vec2 ctr = c + 0.08 + r2 * 0.84;
				float rad = pat == 3 ? mix(0.42, 0.62, h12(c + so + 7.7)) : mix(0.55, 1.05, h12(c + so + 7.7 + float(l) * 3.3));
				vec2 dlt = q - ctr;
				float dd = dot(dlt, dlt) / (rad * rad);
				float h;
				vec2 g;
				if (pat == 3) {
					h = 1.0 - dd;
					g = -2.0 * dlt / (rad * rad);
				} else {
					h = 1.0 - dd;
					g = -2.0 * dlt / (rad * rad) * ls;
					if (l == 1) {
						h = h * 0.9 - 0.05;
						g *= 0.9;
					}
				}
				if (l >= layers) {
					h = -1e9;
				}
				hs[n] = h;
				gs[n] = g;
				best = max(best, h);
				n++;
			}
		}
	}
	float ws = 0.0;
	float hsum = 0.0;
	vec2 gsum = vec2(0.0);
	for (int m = 0; m < 18; m++) {
		float w = exp(max(k * (hs[m] - best), -80.0));
		ws += w;
		hsum += w * max(hs[m], -10.0);
		gsum += w * gs[m];
	}
	return vec3(gsum / ws, hsum / ws);
}

float rain_h(vec2 q, vec2 so) {
	float wob = vn(vec2(q.y * 0.07, 3.1) + so) * 1.6;
	float a = vn(vec2(q.x * 1.0 + wob, q.y * 0.09) + so);
	float b = vn(vec2(q.x * 2.3 + wob * 1.7, q.y * 0.2) + so + 17.0);
	float c = vn(vec2(q.x * 5.1 + wob, q.y * 0.5) + so + 41.0);
	return a * 0.6 + b * 0.3 + c * 0.1;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 P = UV * dims / ps;
	vec2 C = 0.5 * dims / ps;
	float an = radians(angle);
	vec2 ax = vec2(cos(an), sin(an));
	vec2 ay = vec2(-ax.y, ax.x);
	vec2 D = P - C;
	vec2 Q = vec2(dot(D, ax), dot(D, ay));
	float s = max(size, 1.0);
	float refr = max(refraction, 0.0);
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec4 src = texture(effect_tex, UV);
	float a = src.a;
	vec3 col;
	if (pattern <= 1) {
		float wob = (vn(vec2(Q.y / (s * 7.0), 1.3) + so) - 0.5) * 0.08 * s;
		float u = (Q.x + wob) / s;
		float ci = floor(u);
		float t = u - ci - 0.5;
		col = rib_colour(TEXTURE, ci, t, C, ax, ay, Q.y, wob, s, ps, dims, refr, 3);
		float dpx = (0.5 - abs(t)) * s * ps;
		if (dpx < 0.5) {
			float sg = t < 0.0 ? -1.0 : 1.0;
			vec3 cn = rib_colour(TEXTURE, ci + sg, -sg * 0.5, C, ax, ay, Q.y, wob, s, ps, dims, refr, 1);
			col = mix(col, cn, clamp(0.5 - dpx, 0.0, 0.5));
		}
		col = clamp(col, 0.0, 1.0);
	} else {
		vec2 g;
		if (pattern == 4) {
			vec2 q = Q / s;
			float e = 0.6 / s;
			float h0 = rain_h(q, so);
			g = vec2(rain_h(q + vec2(e, 0.0), so) - h0, rain_h(q + vec2(0.0, e), so) - h0) / e;
			g *= 0.35;
		} else {
			float sz = pattern == 3 ? s * 0.45 : s * 1.5;
			float k = clamp(sz * ps / 2.5, 3.0, 40.0);
			vec3 f = dome_field(Q / sz, k, pattern, so);
			g = f.xy * (pattern == 3 ? 0.11 : 0.3);
		}
		vec2 disp = -refr * g * s * 0.9;
		vec2 Ps = P + ax * disp.x + ay * disp.y;
		col = fetch(TEXTURE, Ps * ps / dims);
		vec3 N = normalize(vec3(-g * 1.4, 1.0));
		vec3 L = normalize(vec3(-0.55, -0.65, 0.9));
		vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
		float spec = pow(max(dot(N, H), 0.0), pattern == 3 ? 40.0 : 32.0) * (pattern == 3 ? 0.55 : 0.75);
		float shade = 1.0 + highlight * 0.5 * (dot(N, L) - 0.66);
		col *= tint.rgb * shade;
		col += (vec3(1.0) - col) * spec * highlight;
	}
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}

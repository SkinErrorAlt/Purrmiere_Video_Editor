shader_type canvas_item;
render_mode blend_disabled;

uniform int palette : hint_range(0, 4) = 0;
uniform float density : hint_range(0.0, 1.0) = 0.6;
uniform float band_angle : hint_range(-180.0, 180.0) = 28.0;
uniform float band : hint_range(0.0, 1.0) = 0.7;
uniform float stars : hint_range(0.0, 1.0) = 0.5;
uniform float bright : hint_range(0.0, 1.0) = 0.4;
uniform float drift : hint_range(0.0, 2.0) = 0.15;
uniform float drift_angle : hint_range(-180.0, 180.0) = 160.0;
uniform float twinkle : hint_range(0.0, 1.0) = 0.3;
uniform int placement : hint_range(0, 2) = 2;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec4 h42(vec2 p) {
	vec4 q = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	q += dot(q, q.wzxy + 33.33);
	return fract((q.xxyz + q.yzzw) * q.zywx);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = h12(i);
	float b = h12(i + vec2(1.0, 0.0));
	float c = h12(i + vec2(0.0, 1.0));
	float d = h12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	float n = 0.0;
	mat2 r = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 7; i++) {
		if (i >= oct) {
			break;
		}
		s += a * vnoise(p);
		n += a;
		p = r * p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return s / n;
}

float ridge(vec2 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	float n = 0.0;
	mat2 r = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 7; i++) {
		if (i >= oct) {
			break;
		}
		float v = 1.0 - abs(vnoise(p) * 2.0 - 1.0);
		s += a * v * v;
		n += a;
		p = r * p * 2.11 + vec2(5.7, 21.3);
		a *= 0.5;
	}
	return s / n;
}

void pal(int k, out vec3 a, out vec3 b, out vec3 hot) {
	if (k == 1) { a = vec3(0.75, 0.12, 0.1); b = vec3(0.95, 0.62, 0.2); hot = vec3(1.0, 0.88, 0.7); return; }
	if (k == 2) { a = vec3(0.12, 0.25, 0.85); b = vec3(0.78, 0.15, 0.62); hot = vec3(0.85, 0.85, 1.0); return; }
	if (k == 3) { a = vec3(0.08, 0.6, 0.38); b = vec3(0.12, 0.35, 0.85); hot = vec3(0.8, 1.0, 0.95); return; }
	if (k == 4) { a = vec3(0.9, 0.42, 0.12); b = vec3(0.1, 0.55, 0.65); hot = vec3(1.0, 0.95, 0.85); return; }
	a = vec3(0.42, 0.12, 0.72); b = vec3(0.08, 0.52, 0.68); hot = vec3(0.92, 0.85, 1.0);
}

vec3 star_tint(float h) {
	if (h < 0.18) { return mix(vec3(1.0, 0.62, 0.38), vec3(1.0, 0.8, 0.6), h / 0.18); }
	if (h < 0.55) { return mix(vec3(1.0, 0.8, 0.6), vec3(1.0, 0.97, 0.92), (h - 0.18) / 0.37); }
	return mix(vec3(1.0, 0.97, 0.92), vec3(0.7, 0.8, 1.0), (h - 0.55) / 0.45);
}

vec3 star_layer(vec2 px, float cell, float prob, float rad, float t, float sd, float tw) {
	vec2 g = px / cell;
	vec2 id = floor(g);
	vec4 h = h42(id + sd * 0.37);
	if (h.x > prob) {
		return vec3(0.0);
	}
	vec2 c = (id + 0.25 + 0.5 * h.yz) * cell;
	float d = length(px - c);
	float mag = pow(h.w, 5.0);
	float r = rad * (0.6 + 1.2 * mag);
	float tws = 1.0 - tw * 0.5 * (0.5 + 0.5 * sin(t * (1.5 + 4.0 * h.y) + h.z * 40.0));
	float core = exp(-d * d / (2.0 * r * r));
	float halo = exp(-d / (r * 2.5)) * 0.12 * mag;
	return star_tint(fract(h.y * 7.3 + h.w)) * (0.05 + 1.8 * mag) * (core + halo) * tws;
}

void fragment() {
	vec4 pic = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float t = clip_time;
	float sd = mod(float(seed), 9973.0);
	vec2 px = UV * sz;
	float hgt = sz.y;
	vec2 dv = vec2(cos(radians(drift_angle)), sin(radians(drift_angle))) * drift * 0.02 * t;
	vec2 q = (px - sz * 0.5) / hgt;
	vec2 qn = q + dv * 0.7 + vec2(sd * 0.131, sd * 0.071);
	vec3 ca;
	vec3 cb;
	vec3 hot;
	pal(palette, ca, cb, hot);
	float ba = radians(band_angle);
	vec2 bn = vec2(-sin(ba), cos(ba));
	vec2 qb = q + dv * 0.7;
	float wob = (fbm(qb * 1.3 + 3.0 + sd, 3) - 0.5) * 0.35;
	float bd = dot(qb, bn) + wob;
	float bmask = exp(-bd * bd / 0.05) * band;
	vec2 w1 = vec2(fbm(qn * 1.1, 4), fbm(qn * 1.1 + vec2(5.2, 1.3), 4));
	vec2 qw = qn + (w1 - 0.5) * 0.9;
	float g1 = fbm(qw * 1.4, 6);
	float g2 = fbm(qw * 2.6 + vec2(11.0, 3.0), 6);
	float dn = clamp(density, 0.0, 1.0);
	float th = mix(0.72, 0.38, dn);
	float gas = smoothstep(th, th + 0.3, g1);
	float gas2 = smoothstep(th + 0.05, th + 0.32, g2) * (0.4 + 0.6 * gas);
	float fil = pow(ridge(qw * 3.2 + vec2(2.0, 7.0), 5), 3.0) * gas;
	vec3 emit = ca * gas * 0.85 + cb * gas2 * 0.8 + hot * fil * 0.9 + hot * pow(gas * gas2, 2.0) * 0.5;
	emit += mix(vec3(0.85, 0.78, 0.7), hot, 0.3) * bmask * (0.1 + 0.32 * fbm(qb * 6.0 + 9.0, 5)) * (0.6 + 0.8 * fbm(qb * 2.2 + 4.0, 4));
	emit *= 0.6 + 0.6 * dn;
	vec2 qd = qn * 1.7 + vec2(31.0, 17.0) + (w1 - 0.5) * 0.5;
	float dust = smoothstep(0.42, 0.78, ridge(qd, 6)) * smoothstep(0.25, 0.65, fbm(qd * 0.6 + 4.0, 4));
	dust *= clamp(0.35 + 0.9 * (gas + bmask), 0.0, 1.4) * (0.4 + 0.8 * dn);
	float trans = exp(-dust * 3.6);
	vec3 deep = vec3(0.004, 0.005, 0.014) + ca * 0.012 * fbm(qn * 0.7 + 2.0, 3);
	float tw = clamp(twinkle, 0.0, 1.0);
	vec2 sp1 = px + dv * hgt * 0.9;
	vec2 sp2 = px + dv * hgt * 1.15;
	float sdn = clamp(stars, 0.0, 1.0);
	vec3 bg = star_layer(sp1, 5.0 * ps, sdn * (0.18 + 0.55 * bmask), 0.55 * ps, t, sd, tw);
	bg += star_layer(sp1 + 1.7 * ps, 9.0 * ps, sdn * (0.22 + 0.4 * bmask), 0.7 * ps, t, sd + 3.0, tw);
	vec3 mid = star_layer(sp2, 26.0 * ps, sdn * 0.4, 0.95 * ps, t, sd + 7.0, tw);
	vec3 col = (deep + emit + bg * (0.6 + 0.4 * bmask)) * trans + mid * mix(trans, 1.0, 0.6);
	vec2 sp3 = px + dv * hgt * 1.4;
	float cell = 210.0 * ps;
	vec2 gid = floor(sp3 / cell);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = gid + vec2(float(x), float(y));
			vec4 h = h42(id + sd * 0.53 + 101.0);
			if (h.x > bright * 0.6) {
				continue;
			}
			vec2 c = (id + 0.2 + 0.6 * h.yz) * cell;
			vec2 d = sp3 - c;
			float r = mix(1.2, 2.4, h.w) * ps;
			float len = mix(35.0, 110.0, h.w * h.w) * ps;
			float dd = length(d);
			vec2 dr = mat2(vec2(0.996, 0.087), vec2(-0.087, 0.996)) * d;
			float sx = exp(-abs(dr.y) / (0.6 * ps)) * exp(-abs(dr.x) / (len * 0.3));
			float sy = exp(-abs(dr.x) / (0.6 * ps)) * exp(-abs(dr.y) / (len * 0.3));
			float tws = 1.0 - tw * 0.25 * (0.5 + 0.5 * sin(t * (2.0 + 3.0 * h.y) + h.z * 30.0));
			float core = exp(-dd * dd / (2.0 * r * r)) * 3.0 + exp(-dd / (r * 3.5)) * 0.5 + exp(-dd / (r * 14.0)) * 0.08;
			col += star_tint(fract(h.z * 3.7 + h.y)) * (core + (sx + sy) * 0.7) * tws * mix(0.6, 1.2, h.w);
		}
	}
	col = vec3(1.0) - exp(-col * 1.25);
	col += (h12(px + fract(t * 3.17) * 57.0) - 0.5) / 255.0;
	col = clamp(col, 0.0, 1.0);
	if (placement == 0) {
		COLOR = vec4(pic.rgb + col * (1.0 - pic.a), 1.0);
	} else if (placement == 1) {
		vec3 base = pic.a > 0.0001 ? pic.rgb / pic.a : vec3(0.0);
		vec3 o = 1.0 - (1.0 - base) * (1.0 - col);
		COLOR = vec4(o * pic.a, pic.a);
	} else {
		COLOR = vec4(col, 1.0);
	}
}

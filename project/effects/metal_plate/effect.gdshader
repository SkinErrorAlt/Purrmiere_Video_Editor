shader_type canvas_item;
render_mode blend_disabled;

uniform int kind : hint_range(0, 4) = 0;
uniform int metal : hint_range(0, 3) = 0;
uniform float scale : hint_range(4.0, 600.0) = 48.0;
uniform float brush_angle : hint_range(-180.0, 180.0) = 0.0;
uniform vec2 highlight = vec2(0.38, 0.3);
uniform float roughness : hint_range(0.0, 1.0) = 0.4;
uniform float wear : hint_range(0.0, 1.0) = 0.2;
uniform int placement : hint_range(0, 2) = 2;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

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
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	float n = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= oct) {
			break;
		}
		s += a * vnoise(p);
		n += a;
		p = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * p * 2.05 + vec2(7.3, 3.1);
		a *= 0.5;
	}
	return s / n;
}

vec3 metal_f0(int m) {
	if (m == 1) { return vec3(0.91, 0.92, 0.93); }
	if (m == 2) { return vec3(1.0, 0.76, 0.33); }
	if (m == 3) { return vec3(0.96, 0.6, 0.48); }
	return vec3(0.6, 0.61, 0.63);
}

float tread_h(vec2 p, float s) {
	vec2 cell = floor(p / s);
	vec2 f = p / s - cell - 0.5;
	float par = mod(cell.x + cell.y, 2.0);
	float a = par < 0.5 ? 0.785398 : -0.785398;
	vec2 r = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * f;
	float ax = abs(r.x) / 0.46;
	float wid = 0.14 * sqrt(max(1.0 - ax * ax, 0.0)) + 0.001;
	float e = ax * ax + pow(r.y / max(wid, 0.001), 2.0);
	float dome = sqrt(max(1.0 - e, 0.0));
	return pow(dome, 0.7);
}

void fragment() {
	vec4 pic = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float sd = float(seed);
	vec2 p = UV * sz;
	vec2 pw = p + vec2(sd * 41.0, sd * 17.0);
	float s = max(scale * ps, 2.0);
	float rough = clamp(roughness, 0.0, 1.0);
	float wr = clamp(wear, 0.0, 1.0);
	vec3 f0 = metal_f0(metal);
	vec3 n = vec3(0.0, 0.0, 1.0);
	vec2 tangent = vec2(cos(radians(brush_angle)), sin(radians(brush_angle)));
	float groove = 0.5;
	float hole = 0.0;
	float aniso = 0.0;
	float cavity = 1.0;
	vec2 centre = sz * 0.5;
	if (kind == 0 || kind == 2) {
		vec2 bn = vec2(-tangent.y, tangent.x);
		float b = dot(pw, bn);
		float a = dot(pw, tangent);
		groove = fbm(vec2(b / (0.6 * ps), a / (90.0 * ps)), 3) * 0.6 + vnoise(vec2(b / (2.5 * ps), a / (300.0 * ps))) * 0.4;
		aniso = kind == 0 ? 1.0 : 0.35;
		if (kind == 2) {
			float e = max(1.0 * ps, 0.5);
			float h0 = tread_h(pw, s);
			float hx = tread_h(pw + vec2(e, 0.0), s);
			float hy = tread_h(pw + vec2(0.0, e), s);
			float k = s * 0.07;
			n = normalize(vec3(-(hx - h0) / e * k, -(hy - h0) / e * k, 1.0));
			aniso *= 1.0 - step(0.05, h0);
		}
	} else if (kind == 1) {
		vec2 d = p - centre;
		float r = length(d);
		tangent = r > 0.001 ? vec2(-d.y, d.x) / r : vec2(1.0, 0.0);
				vec2 dr = r > 0.001 ? d / r : vec2(1.0, 0.0);
		groove = fbm(vec2(r / (0.6 * ps), sd) + dr * 2.5, 3) * 0.6 + vnoise(vec2(r / (2.5 * ps), 3.0) + dr * 1.5) * 0.4;
		aniso = 1.0;
	} else if (kind == 3) {
		vec2 g = pw / s;
		vec2 id = floor(g);
		float best = 9.0;
		vec2 bc = vec2(0.0);
		float r2 = 9.0;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 c = id + vec2(float(x), float(y));
				vec2 o = c + 0.15 + 0.7 * h42(c + sd).xy;
				float dd = dot(g - o, g - o);
				if (dd < best) {
					r2 = best;
					best = dd;
					bc = o;
				} else if (dd < r2) {
					r2 = dd;
				}
			}
		}
		vec2 grad = (g - bc) * 2.0 * 0.24;
		grad += (vec2(vnoise(pw / (4.0 * ps)), vnoise(pw / (4.0 * ps) + 9.0)) - 0.5) * 0.12 * rough;
		n = normalize(vec3(-grad, 1.0));
		cavity = 0.75 + 0.25 * smoothstep(0.0, 0.25, sqrt(r2) - sqrt(best));
		groove = vnoise(pw / (1.5 * ps));
	} else {
		float hs = s;
		vec2 g = pw / vec2(hs, hs * 0.8660254);
		float row = floor(g.y);
		vec2 gg = vec2(g.x + mod(row, 2.0) * 0.5, g.y);
		vec2 c1 = vec2((floor(gg.x) + 0.5 - mod(row, 2.0) * 0.5) * hs, (row + 0.5) * hs * 0.8660254);
		float best = 1e9;
		vec2 bc = c1;
		for (int y = -1; y <= 1; y++) {
			float rr = row + float(y);
			float off = mod(rr, 2.0) * 0.5;
			float cx = floor(g.x + off);
			for (int x = -1; x <= 1; x++) {
				vec2 c = vec2((cx + float(x) + 0.5 - off) * hs, (rr + 0.5) * hs * 0.8660254);
				float dd = dot(pw - c, pw - c);
				if (dd < best) {
					best = dd;
					bc = c;
				}
			}
		}
		float d = sqrt(best);
		float rad = hs * 0.3;
		float bev = max(2.0 * ps, hs * 0.06);
		hole = 1.0 - smoothstep(rad - 0.75 * ps, rad + 0.75 * ps, d);
		float rim = smoothstep(rad + bev, rad, d) * (1.0 - hole);
		vec2 dir = d > 0.001 ? (pw - bc) / d : vec2(0.0);
		n = normalize(vec3(dir * rim * 0.9, 1.0));
		vec2 bn = vec2(-tangent.y, tangent.x);
		groove = fbm(vec2(dot(pw, bn) / (0.8 * ps), dot(pw, tangent) / (120.0 * ps)), 3);
		aniso = 0.5;
	}
	vec3 lp = vec3(highlight * sz, sz.y * 0.55);
	vec3 P = vec3(p, 0.0);
	vec3 L = normalize(lp - P);
	vec3 V = vec3(0.0, 0.0, 1.0);
	vec3 H = normalize(L + V);
	vec3 T3 = normalize(vec3(tangent, 0.0) - n * dot(vec3(tangent, 0.0), n));
	vec3 B3 = cross(n, T3);
	float nh = max(dot(n, H), 0.001);
	float ax = mix(0.06, 0.3, rough);
	float ay = mix(ax, mix(0.5, 0.9, rough), aniso);
	float ht = dot(H, T3) / ax;
	float hb = dot(H, B3) / ay;
	float spec = exp(-(ht * ht + hb * hb) / (nh * nh)) / (ax * ay * 12.0 + 0.4);
	float broad = exp(-(1.0 - nh) * mix(14.0, 5.0, rough));
	vec3 R = reflect(-V, n);
	float env = 0.24 + 0.22 * (0.5 - 0.5 * R.y) + 0.1 * R.x;
	float gm = 0.8 + 0.4 * groove;
	float smudge = fbm(pw / (160.0 * ps) + 3.0, 4);
	float dull = 1.0 - wr * 0.5 * smoothstep(0.45, 0.8, smudge);
	vec2 toward = highlight - vec2(0.5);
	vec3 ld = normalize(vec3(length(toward) > 0.001 ? normalize(toward) * 0.8 : vec2(0.0), 0.6));
	float relief = clamp(1.0 + (kind == 3 ? 1.1 : 2.6) * (dot(n, ld) - ld.z), 0.25, 2.2);
	vec3 col = f0 * (env * gm + broad * 0.55 * dull + spec * 0.9 * gm * gm * dull) * cavity * relief;
	if (wr > 0.0) {
		vec2 sc = pw / (s * 3.0);
		vec2 cid = floor(sc);
		float scr = 0.0;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 c = cid + vec2(float(x), float(y));
				vec4 h = h42(c * 1.7 + sd + 5.0);
				if (h.x > wr * 0.9) {
					continue;
				}
				vec2 o = (c + h.yz) * s * 3.0;
				float a = h.w * 6.2831853;
				vec2 dir = vec2(cos(a), sin(a));
				float len = s * mix(1.0, 6.0, h12(c + 3.0));
				vec2 q = pw - o;
				float along = dot(q, dir);
				float side = abs(dot(q, vec2(-dir.y, dir.x)));
				float on = step(abs(along), len) * (1.0 - smoothstep(0.3 * ps, 1.0 * ps, side));
				scr = max(scr, on * (0.6 + 0.4 * vnoise(vec2(along / (3.0 * ps), c.x))));
			}
		}
		col = mix(col, f0 * (env * 1.8 + 0.2), scr * 0.6);
		if (metal == 3) {
			float tar = smoothstep(0.5, 0.85, fbm(pw / (70.0 * ps) + 11.0, 5)) * wr;
			col = mix(col, col * vec3(0.55, 0.42, 0.36), tar);
		} else if (metal != 2) {
			col *= 1.0 - wr * 0.15 * smoothstep(0.55, 0.9, fbm(pw / (40.0 * ps) + 23.0, 5));
		}
	}
	col = clamp(col, 0.0, 1.0);
	col += (h12(p * 1.3 + 7.0) - 0.5) / 255.0;
	float a = 1.0 - hole;
	vec3 voidc = f0 * 0.03;
	if (placement == 0) {
		COLOR = vec4(pic.rgb + mix(voidc, col, a) * (1.0 - pic.a), 1.0);
	} else if (placement == 1) {
		COLOR = vec4(col * a + pic.rgb * (1.0 - a), a + pic.a * (1.0 - a));
	} else {
		COLOR = vec4(mix(voidc, col, a), 1.0);
	}
}

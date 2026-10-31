shader_type canvas_item;
render_mode blend_disabled;

uniform int kind : hint_range(0, 3) = 0;
uniform vec4 colour : source_color = vec4(0.62, 0.58, 0.56, 1.0);
uniform float scale : hint_range(10.0, 2000.0) = 120.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float pores : hint_range(0.0, 1.0) = 0.4;
uniform float light_angle : hint_range(-180.0, 180.0) = -130.0;
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
	for (int i = 0; i < 7; i++) {
		if (i >= oct) {
			break;
		}
		s += a * vnoise(p);
		n += a;
		p = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * p * 2.03 + vec2(9.1, 2.7);
		a *= 0.5;
	}
	return s / n;
}

float ridged(vec2 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	float n = 0.0;
	for (int i = 0; i < 7; i++) {
		if (i >= oct) {
			break;
		}
		float v = 1.0 - abs(vnoise(p) * 2.0 - 1.0);
		s += a * v * v;
		n += a;
		p = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * p * 2.07 + vec2(3.3, 8.1);
		a *= 0.52;
	}
	return s / n;
}

vec3 vor(vec2 g, float sd) {
	vec2 id = floor(g);
	float f1 = 9.0;
	float f2 = 9.0;
	vec2 cid = id;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = id + vec2(float(x), float(y));
			vec2 o = c + 0.1 + 0.8 * h42(c + sd).xy;
			float d = length(g - o);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				cid = c;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec3(f2 - f1, h12(cid * 1.37 + sd), f1);
}

float pits(vec2 p, float r0, float density, float sd) {
	float cell = r0 * 4.0;
	vec2 g = p / cell;
	vec2 id = floor(g);
	float h = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = id + vec2(float(x), float(y));
			vec4 r = h42(c * 1.91 + sd + 13.0);
			if (r.x > density) {
				continue;
			}
			vec2 o = (c + 0.2 + 0.6 * r.yz) * cell;
			float rad = r0 * mix(0.35, 1.2, r.w * r.w);
			float d = length(p - o) / rad;
			h = min(h, -(1.0 - smoothstep(0.75, 1.0, d)) * sqrt(max(1.0 - d * d * 0.8, 0.0)));
		}
	}
	return h;
}

float height(vec2 p, float s, float ps, float sd) {
	float rough = clamp(roughness, 0.0, 1.0);
	float pr = clamp(pores, 0.0, 1.0);
	if (kind == 1) {
		vec2 w = vec2(fbm(p / s + sd, 4), fbm(p / s + sd + 7.0, 4)) - 0.5;
		float h = ridged(p / s + w * 1.2, 7) * (0.6 + 0.8 * rough);
		vec3 v = vor(p / (s * 1.6) + w * 0.6, sd + 3.0);
		float crack = 1.0 - smoothstep(0.0, 0.05 + 0.02 * rough, v.x);
		h -= crack * 0.8 * pr;
		h += (vnoise(p / (1.5 * ps)) - 0.5) * 0.04 * rough;
		return h * s * 0.35;
	}
	if (kind == 2) {
		float h = fbm(p / (s * 0.6) + sd, 5) * 0.25 + (vnoise(p / (2.0 * ps) + sd) - 0.5) * 0.18 * rough;
		h += (fbm(p / (4.0 * ps) + sd * 1.7, 3) - 0.5) * 0.3 * rough;
		float pt = pits(p + sd * 31.0, 3.2 * ps * (0.7 + 0.6 * rough), 0.18 + 0.62 * pr, sd);
		pt = min(pt, pits(p + sd * 17.0, 1.4 * ps, 0.2 + 0.7 * pr, sd + 5.0) * 0.7);
		h += pt * 1.4;
		return h * 6.0 * ps;
	}
	if (kind == 3) {
		vec2 q = p / s;
		float warp = fbm(q * vec2(0.4, 1.2) + sd, 4) * 1.4;
		float layer = q.y * 2.6 + warp + q.x * 0.08;
		float step_h = floor(layer) + smoothstep(0.82, 1.0, fract(layer));
		float h = step_h * 0.12 + fbm(q * vec2(1.0, 6.0) + sd + 3.0, 5) * 0.12 * (0.5 + rough);
		h += (vnoise(p / (1.8 * ps) + sd) - 0.5) * 0.02;
		vec3 v = vor(q * vec2(0.8, 2.0) + warp * 0.3, sd + 11.0);
		h -= (1.0 - smoothstep(0.0, 0.03, v.x)) * 0.15 * pr * smoothstep(0.55, 0.7, fbm(q * 0.6 + sd + 40.0, 4));
		return h * s * 0.25;
	}
	float h = (vnoise(p / (1.2 * ps) + sd) - 0.5) * 0.25 * rough;
	h += pits(p + sd * 7.0, 1.8 * ps, 0.08 + 0.3 * pr, sd + 9.0) * 0.8;
	return h * 2.5 * ps;
}

vec3 albedo(vec2 p, float s, float ps, float sd) {
	vec3 c = colour.rgb;
	float rough = clamp(roughness, 0.0, 1.0);
	if (kind == 0) {
		vec3 big = vor(p / (s * 0.09) + sd, sd + 1.0);
		vec3 mid = vor(p / (s * 0.04) + sd * 0.7, sd + 2.0);
		vec3 small = vor(p / (s * 0.016) + sd * 0.3, sd + 3.0);
		vec3 feld = c * vec3(1.18, 1.05, 1.0);
		vec3 quartz = mix(c, vec3(0.75, 0.76, 0.78), 0.5) * 0.82;
		vec3 dark = vec3(0.07, 0.07, 0.075);
		vec3 o = big.y < 0.55 ? feld * (0.9 + 0.2 * big.z) : (big.y < 0.92 ? quartz : dark);
		if (mid.y < 0.1) { o = mix(o, dark, 0.9); }
		else if (mid.y > 0.8) { o = mix(o, feld * 1.08, 0.7); }
		if (small.y < 0.09) { o = mix(o, dark * 1.3, 0.85); }
		else if (small.y > 0.9) { o = mix(o, vec3(0.92), 0.5); }
		o *= 0.92 + 0.16 * fbm(p / (s * 1.5) + sd, 4);
		return o;
	}
	if (kind == 1) {
		float band = fbm(p / (s * 2.5) + sd + 4.0, 5);
		vec3 o = c * (0.7 + 0.6 * band) * mix(vec3(1.0), vec3(1.08, 0.98, 0.9), fbm(p / (s * 0.8) + 12.0, 4));
		o *= 0.88 + 0.24 * vnoise(p / (1.6 * ps) + sd);
		o = mix(o, o * 0.55, smoothstep(0.6, 0.85, fbm(p / (s * 0.5) + 30.0, 5)) * 0.6);
		return o;
	}
	if (kind == 2) {
		vec3 o = c * (0.88 + 0.22 * fbm(p / (s * 1.2) + sd, 5));
		o *= 0.94 + 0.12 * vnoise(p / (0.9 * ps) + sd * 3.0);
		vec3 ag = vor(p / (3.5 * ps * (0.6 + rough)) + sd, sd + 4.0);
		if (ag.y < 0.08) { o *= 0.72; }
		else if (ag.y > 0.95) { o = mix(o, vec3(0.85), 0.35); }
		o *= 1.0 - 0.18 * smoothstep(0.55, 0.85, fbm(p / (s * 3.0) + 50.0, 5));
		return o;
	}
	vec2 q = p / s;
	float warp = fbm(q * vec2(0.4, 1.2) + sd, 4) * 1.4;
	float layer = q.y * 2.6 + warp + q.x * 0.08;
	float tone = h12(vec2(floor(layer), sd));
	vec3 o = c * (0.82 + 0.3 * tone) * (0.9 + 0.2 * fbm(q * vec2(1.0, 8.0) + 5.0, 5));
	o = mix(o, o * vec3(0.95, 1.05, 1.0), fbm(q * 0.7 + 20.0, 4) - 0.3);
	o *= 0.95 + 0.1 * vnoise(p / (1.2 * ps) + sd);
	return o;
}

void fragment() {
	vec4 pic = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float sd = mod(float(seed), 9973.0) * 0.37;
	vec2 p = UV * sz + vec2(sd * 113.0, sd * 71.0);
	float s = max(scale * ps, 2.0);
	float e = max(ps, 0.5);
	float h0 = height(p, s, ps, sd);
	float hx = height(p + vec2(e, 0.0), s, ps, sd);
	float hy = height(p + vec2(0.0, e), s, ps, sd);
	vec3 n = normalize(vec3(-(hx - h0) / e, -(hy - h0) / e, 1.0));
	float la = radians(light_angle);
	vec3 L = normalize(vec3(cos(la) * 0.75, sin(la) * 0.75, 0.62));
	float diff = max(dot(n, L), 0.0);
	float lit = 0.32 + 0.68 * diff / 0.62 * 0.9;
	vec3 a = albedo(p, s, ps, sd);
	vec3 o = a * lit;
	if (kind == 0) {
		vec3 hv = normalize(L + vec3(0.0, 0.0, 1.0));
		o += vec3(0.08) * pow(max(dot(n, hv), 0.0), 40.0);
	}
	o = clamp(o, 0.0, 1.0);
	o += (h12(UV * sz * 1.7 + 3.0) - 0.5) / 255.0;
	if (placement == 0) {
		COLOR = vec4(pic.rgb + o * (1.0 - pic.a), 1.0);
	} else if (placement == 1) {
		vec3 base = pic.a > 0.0001 ? pic.rgb / pic.a : vec3(0.0);
		vec3 rel = o / max(dot(colour.rgb, vec3(0.3333)), 0.05);
		vec3 tex = mix(vec3(1.0), rel, 0.7);
		COLOR = vec4(clamp(base * tex, 0.0, 1.0) * pic.a, pic.a);
	} else {
		COLOR = vec4(o, 1.0);
	}
}

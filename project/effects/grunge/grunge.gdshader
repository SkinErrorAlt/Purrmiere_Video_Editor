shader_type canvas_item;
render_mode blend_disabled;

uniform int style : hint_range(0, 4) = 0;
uniform float strength : hint_range(0.0, 1.0) = 0.75;
uniform float scale : hint_range(0.25, 4.0) = 1.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform float edge_burn : hint_range(0.0, 1.0) = 0.35;
uniform int colour_style : hint_range(0, 2) = 0;
uniform int blend : hint_range(0, 3) = 0;
uniform int seed : hint_range(0, 9999) = 0;
uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform bool composite = false;
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

float gn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 ga = h22(i) * 2.0 - 1.0;
	vec2 gb = h22(i + vec2(1.0, 0.0)) * 2.0 - 1.0;
	vec2 gc = h22(i + vec2(0.0, 1.0)) * 2.0 - 1.0;
	vec2 gd = h22(i + vec2(1.0, 1.0)) * 2.0 - 1.0;
	float va = dot(ga, f);
	float vb = dot(gb, f - vec2(1.0, 0.0));
	float vc = dot(gc, f - vec2(0.0, 1.0));
	float vd = dot(gd, f - vec2(1.0, 1.0));
	return 0.5 + 0.9 * mix(mix(va, vb, u.x), mix(vc, vd, u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		s += a * gn(p);
		p = r * p * 2.03 + vec2(17.1, 9.4);
		a *= 0.5;
	}
	return s / 0.96875;
}

float fine(float freq, float pxq) {
	return 1.0 - smoothstep(0.3, 0.6, freq * pxq);
}

float fbm3(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 3; i++) {
		s += a * gn(p);
		p = r * p * 2.03 + vec2(17.1, 9.4);
		a *= 0.5;
	}
	return s / 0.875;
}

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 tone(vec3 c) {
	if (colour_style == 1) {
		float l = lum(c);
		return clamp(vec3(l * 0.86, l * 0.98, l * 1.16), 0.0, 1.0);
	}
	if (colour_style == 2) {
		return vec3(lum(c));
	}
	return c;
}

vec2 scratches(vec2 P, float cell, int per, float unit, float ps, vec2 so, float lmin, float lmax, float wmin, float wmax, float light_share) {
	vec2 cid = floor(P / cell + 0.5) - 1.0;
	float dark = 0.0;
	float light = 0.0;
	for (int j = 0; j <= 1; j++) {
		for (int i = 0; i <= 1; i++) {
			vec2 c = cid + vec2(float(i), float(j));
			for (int k = 0; k < 4; k++) {
				if (k >= per) {
					break;
				}
				vec2 key = c + so + float(k) * vec2(37.1, 11.9);
				vec2 ctr = (c + h22(key)) * cell;
				float ang = h12(key + 3.1) * 6.2831853;
				float hl = cell * 0.5 * mix(lmin, lmax, pow(h12(key + 5.7), 2.2));
				vec2 dir = vec2(cos(ang), sin(ang));
				vec2 d = P - ctr;
				float along = dot(d, dir);
				if (abs(along) > hl) {
					continue;
				}
				float bend = (h12(key + 21.7) - 0.5) * 0.08;
				float across = abs(dot(d, vec2(-dir.y, dir.x)) + bend * along * along / hl);
				float u = abs(along) / hl;
				float taper = 1.0 - u * u;
				float w = mix(wmin, wmax, h12(key + 9.1)) * unit * taper;
				float wr = w * ps;
				float cov = clamp(max(wr, 0.5) + 0.5 - across * ps, 0.0, 1.0) * min(1.0, 2.0 * wr);
				float depth = mix(0.25, 1.0, h12(key + 13.3)) * sqrt(taper);
				depth *= smoothstep(0.08, 0.3, vn(vec2(along / (cell * 0.12), key.x * 0.37)));
				float v = cov * depth;
				if (h12(key + 17.9) < light_share) {
					light = max(light, v);
				} else {
					dark = max(dark, v);
				}
			}
		}
	}
	return vec2(dark, light);
}

float specks(vec2 p, float density, float rmin, float rmax, float aa, float soft) {
	vec2 cid = floor(p + 0.5) - 1.0;
	float best = 0.0;
	for (int j = 0; j <= 1; j++) {
		for (int i = 0; i <= 1; i++) {
			vec2 c = cid + vec2(float(i), float(j));
			if (h12(c + 0.37) > density) {
				continue;
			}
			vec2 ctr = c + 0.15 + 0.7 * h22(c + 5.1);
			float r = mix(rmin, rmax, pow(h12(c + 9.3), 2.5));
			vec2 d = p - ctr;
			if (dot(d, d) > (r * 1.5 + aa + soft * r) * (r * 1.5 + aa + soft * r)) {
				continue;
			}
			float l = length(d) * (1.0 + 0.35 * (vn(d / max(r, 0.001) * 1.3 + c * 7.1) - 0.5));
			float w = aa + soft * r;
			best = max(best, (1.0 - smoothstep(r - w, r + w, l)) * mix(0.55, 1.0, h12(c + 2.2)));
		}
	}
	return best;
}

vec2 stains(vec2 q, float thr, float rimw, float pxq) {
	vec2 w = vec2(fbm3(q * 1.7 + vec2(3.3, 1.1)), fbm3(q * 1.7 + vec2(8.2, 5.9)));
	float n = fbm(q + (w - 0.5) * 0.7);
	float e = n - thr;
	float aa = pxq * 3.0;
	float fill = smoothstep(-aa, aa, e);
	float rim = fill * exp(-max(e, 0.0) / rimw);
	return vec2(fill, rim);
}

float coffee(vec2 q, vec2 so, float pxq) {
	float cell = 0.8;
	vec2 cid = floor(q / cell);
	float g = 0.0;
	float tex = 0.6 + 0.8 * fbm3(q * 9.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cid + vec2(float(i), float(j));
			vec2 key = c + so;
			if (h12(key + 0.7) < 0.35) {
				continue;
			}
			vec2 ctr = (c + 0.2 + 0.6 * h22(key)) * cell;
			float R = mix(0.11, 0.27, h12(key + 1.9));
			vec2 d = q - ctr;
			float r = length(d);
			vec2 dir = d / max(r, 0.00001);
			float Rr = R * (1.0 + (vn(dir * 2.2 + key * 3.1) - 0.5) * 0.06 + (vn(dir * 7.0 + key * 1.7) - 0.5) * 0.015);
			float e = Rr - r;
			float ca = h12(key + 4.4) * 6.2831853;
			float cres = 0.5 + 0.5 * dot(dir, vec2(cos(ca), sin(ca)));
			float wdt = R * mix(0.012, 0.06, cres * cres);
			float arc = mix(0.25, 1.0, smoothstep(0.25, 0.6, vn(dir * 3.0 + key * 5.3)));
			float edge = smoothstep(-pxq * 1.5, pxq * 1.5, e);
			float rim = edge * exp(-max(e, 0.0) / wdt) * arc;
			float fill = edge * 0.12 * tex;
			float e2 = Rr * 1.035 - r;
			float rim2 = smoothstep(-pxq * 1.5, pxq * 1.5, e2) * exp(-max(e2, 0.0) / (R * 0.008)) * 0.45 * smoothstep(0.5, 0.75, vn(dir * 2.0 + key * 9.1));
			g = max(g, rim * 0.9 + fill);
			g = max(g, rim2);
		}
	}
	return g;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 S = dims / ps;
	vec2 P = UV * S;
	float ro = composite ? ps * 2.0 : ps * 0.5;
	float sc = max(scale, 0.05);
	float unit = S.y / 1080.0;
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec2 q = P / (S.y * sc) + so * 0.013 + vec2(0.37, 0.71);
	float pxq = 1.0 / (S.y * sc * ro);
	vec2 Ps = P / sc;
	float ct = max(contrast, 0.0);
	if (!composite) {
		vec3 L = vec3(0.5);
		float aux = 1.0;
		if (style == 0) {
			vec3 dirt = tone(vec3(0.3, 0.22, 0.14));
			float blot = smoothstep(0.5, 0.82, fbm(q * 1.5)) * 0.45;
			float splot = smoothstep(0.58, 0.76, fbm(q * 7.0 + 4.0)) * 0.35;
			vec2 st = stains(q * 2.1 + 30.0, 0.66, 0.018, pxq * 2.1);
			L = mix(L, dirt, clamp((blot + splot + st.x * 0.12 + st.y * 0.45) * ct, 0.0, 1.0));
			L += vec3((vn(q * 40.0) - 0.5) * 0.1 * ct);
		} else if (style == 1) {
			vec2 wq = q + (vec2(fbm3(q * 2.0 + 5.0), fbm3(q * 2.0 + 11.0)) - 0.5) * 0.5;
			float n = fbm(wq * 2.2);
			float rust = smoothstep(0.47, 0.53, n + (vn(q * 40.0) - 0.5) * 0.08);
			float streak = smoothstep(0.5, 0.75, fbm(vec2(q.x * 9.0, q.y * 1.1) + 2.0)) * smoothstep(0.3, 0.55, n) * 0.6;
			float body = clamp(rust * (0.55 + 0.45 * fbm(q * 9.0)) + streak, 0.0, 1.0);
			vec3 rc = mix(vec3(0.24, 0.11, 0.05), vec3(0.66, 0.31, 0.1), smoothstep(0.3, 0.75, vn(q * 14.0) * 0.6 + fbm(q * 5.0) * 0.4));
			L = mix(L, tone(rc), clamp(body * ct, 0.0, 1.0));
			aux = rust;
		} else if (style == 2) {
			vec3 paper = tone(vec3(0.8, 0.68, 0.46));
			vec3 stain = tone(vec3(0.42, 0.29, 0.12));
			L = mix(L, paper, 0.22 * min(ct, 1.0) + 0.1 * smoothstep(0.3, 0.8, fbm(q * 1.2 + 7.0)) * ct);
			vec2 st = stains(q * 1.5 + 50.0, 0.6, 0.014, pxq * 1.5);
			vec2 st2 = stains(q * 3.1 + 90.0, 0.68, 0.01, pxq * 3.1);
			L = mix(L, stain, clamp((st.x * 0.22 + st.y * 0.7 + st2.x * 0.12 + st2.y * 0.5) * ct, 0.0, 1.0));
			aux = smoothstep(0.45, 0.65, fbm(q * 3.0 + 12.0));
		} else if (style == 3) {
			vec3 metal = tone(vec3(0.3, 0.31, 0.34));
			float ox = smoothstep(0.52, 0.8, fbm(q * 2.5 + 3.0)) * 0.35;
			L = mix(L, metal, clamp(ox * ct, 0.0, 1.0));
			aux = clamp((0.5 + fbm(q * 3.0 + 20.0)) * 0.5, 0.0, 1.0);
		} else {
			vec2 st = stains(q * 2.6 + 70.0, 0.7, 0.012, pxq * 2.6);
			L = mix(L, tone(vec3(0.82, 0.72, 0.52)), 0.12 * min(ct, 1.0));
			L = mix(L, tone(vec3(0.42, 0.25, 0.1)), clamp((st.x * 0.1 + st.y * 0.4) * ct, 0.0, 1.0));
		}
		vec2 cq = (UV - 0.5) * vec2(S.x / S.y, 1.0);
		float md = length(vec2(S.x / S.y, 1.0) * 0.5);
		float rd = length(cq) / md + (fbm3(q * 2.5 + 40.0) - 0.5) * 0.3 + (vn(q * 30.0) - 0.5) * 0.05;
		float burn = smoothstep(0.55, 1.05, rd);
		L = mix(clamp(L, 0.0, 1.0), tone(vec3(0.16, 0.09, 0.04)), clamp(edge_burn * burn * burn * 1.3, 0.0, 1.0));
		COLOR = vec4(clamp(L, 0.0, 1.0), aux);
	} else {
		vec4 low = texture(TEXTURE, UV);
		vec3 L = low.rgb;
		float aux = low.a;
		float sig = 0.0;
		if (style == 0) {
			vec3 dirt = tone(vec3(0.3, 0.22, 0.14));
			float speck = specks(q * 140.0, 0.3, 0.06, 0.32, pxq * 140.0, 0.15) * 0.75;
			vec2 sx = scratches(Ps, 420.0 * unit, 2, unit, ro * sc, so, 0.12, 1.0, 0.5, 1.6, 0.45);
			L = mix(L, dirt * 0.6, clamp((speck + sx.x * 0.7) * ct, 0.0, 1.0));
			L = mix(L, vec3(0.92), clamp((specks(q * 170.0 + 50.0, 0.12, 0.05, 0.25, pxq * 170.0, 0.2) * 0.5 + sx.y * 0.6) * ct, 0.0, 1.0));
			sig = (vn(q * 420.0) - 0.5) * 0.12 * fine(420.0, pxq);
		} else if (style == 1) {
			float pit = specks(q * 90.0, 0.55, 0.08, 0.42, pxq * 90.0, 0.1) * aux;
			float crust = smoothstep(0.35, 0.75, vn(q * 55.0) * 0.6 + vn(q * 130.0) * 0.4 * fine(130.0, pxq)) * aux;
			L = mix(L, L * vec3(0.62, 0.55, 0.5), clamp(crust * 0.6 * ct, 0.0, 1.0));
			vec2 sx = scratches(Ps, 420.0 * unit, 2, unit, ro * sc, so, 0.12, 0.9, 0.5, 1.4, 0.3);
			L = mix(L, tone(vec3(0.12, 0.06, 0.03)), clamp((pit * 0.7 + sx.x * 0.5) * ct, 0.0, 1.0));
			L = mix(L, tone(vec3(0.85, 0.6, 0.4)), clamp(sx.y * 0.4 * ct, 0.0, 1.0));
			sig = (vn(q * 500.0) - 0.5) * 0.15 * aux * fine(500.0, pxq);
		} else if (style == 2) {
			vec3 stain = tone(vec3(0.42, 0.29, 0.12));
			float fox = specks(q * 28.0 + 12.0, 0.3, 0.06, 0.4, pxq * 28.0, 0.5) * aux;
			L = mix(L, stain * 0.8, clamp(fox * 0.6 * ct, 0.0, 1.0));
			sig = (vn(vec2(q.x * 380.0, q.y * 90.0)) - 0.5) * 0.14 * fine(380.0, pxq) + (vn(q * 230.0) - 0.5) * 0.1 * fine(230.0, pxq);
		} else if (style == 3) {
			vec3 metal = tone(vec3(0.3, 0.31, 0.34));
			vec2 big = scratches(Ps, 380.0 * unit, 4, unit, ro * sc, so, 0.15, 1.0, 0.45, 1.5, 0.6);
			vec2 small = scratches(Ps, 110.0 * unit, 3, unit, ro * sc, so + 71.0, 0.2, 1.0, 0.35, 0.9, 0.6);
			L = mix(L, metal, clamp((big.x * 0.8 + small.x * 0.45) * ct, 0.0, 1.0));
			L = mix(L, vec3(0.95), clamp((big.y * 0.75 + small.y * 0.45) * ct, 0.0, 1.0));
			sig = ((vn(vec2(q.x * 2.0, q.y * 420.0)) - 0.5) * 0.09 * fine(420.0, pxq) + (vn(vec2(q.x * 9.0, q.y * 1100.0)) - 0.5) * 0.05 * fine(1100.0, pxq)) * aux * 2.0;
		} else {
			float g = coffee(q, so, pxq);
			L = mix(L, tone(vec3(0.42, 0.25, 0.1)), clamp(g * ct, 0.0, 1.0));
			sig = (vn(q * 300.0) - 0.5) * 0.08 * fine(300.0, pxq);
		}
		L += vec3(sig * ct);
		float k = clamp(strength, 0.0, 1.0);
		L = mix(vec3(0.5), clamp(L, 0.0, 1.0), k);
		if (colour_style == 0) {
			L += vec3(0.03, 0.01, -0.035) * k;
		} else if (colour_style == 1) {
			L += vec3(-0.025, 0.0, 0.035) * k;
		}
		vec4 c = texture(effect_tex, UV);
		float a = c.a;
		vec3 b = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
		vec3 o;
		if (blend == 1) {
			o = b * 2.0 * L;
		} else if (blend == 2) {
			o = (1.0 - 2.0 * L) * b * b + 2.0 * L * b;
		} else if (blend == 3) {
			o = 1.0 - (1.0 - b) * (1.0 - max(2.0 * L - 1.0, 0.0));
		} else {
			o = mix(2.0 * b * L, 1.0 - 2.0 * (1.0 - b) * (1.0 - L), step(0.5, b));
		}
		COLOR = vec4(clamp(o, 0.0, 1.0) * a, a);
	}
}

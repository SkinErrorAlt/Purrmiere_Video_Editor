shader_type canvas_item;
render_mode blend_disabled;

uniform float growth : hint_range(0.0, 1.0) = 0.55;
uniform float grow_time : hint_range(0.0, 30.0) = 0.0;
uniform int kind : hint_range(0, 3) = 0;
uniform float colony_size : hint_range(20.0, 600.0) = 150.0;
uniform float density : hint_range(0.0, 1.0) = 0.6;
uniform float prefer_dark : hint_range(0.0, 1.0) = 0.6;
uniform float relief : hint_range(0.0, 1.0) = 0.6;
uniform float stain : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 w = mod(i, 289.0);
	return mix(mix(hash12(w), hash12(w + vec2(1.0, 0.0)), f.x), mix(hash12(w + vec2(0.0, 1.0)), hash12(w + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += vnoise(p) * a;
		p = mat2(vec2(1.6, -1.2), vec2(1.2, 1.6)) * p + vec2(5.1, 1.7);
		a *= 0.5;
	}
	return s / 0.9375;
}

float cell_edge(vec2 p, out float id) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash22(mod(i + g, 289.0)) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = hash12(mod(i + g, 289.0) + 3.7);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return d2 - d1;
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pix = UV * sz;
	float sk = mod(float(seed), 997.0);
	vec2 so = vec2(sk * 0.913 + 17.0, sk * 0.531 + 5.0);
	float cs = max(colony_size * ps, 4.0);
	float g = clamp(growth, 0.0, 1.0);
	if (grow_time > 0.0001) {
		g *= clamp(max(clip_time, 0.0) / grow_time, 0.0, 1.0);
	}
	vec4 base = texture(TEXTURE, UV);
	float a = base.a;
	vec3 rgb = a > 0.0001 ? base.rgb / a : vec3(0.0);
	vec2 p = pix / cs;
	vec2 warp = vec2(fbm(p * 1.3 + so), fbm(p * 1.3 + so + vec2(9.2, 3.4))) - 0.5;
	vec2 pw = p + warp * (kind == 1 ? 0.55 : 0.4);
	float fine = fbm(pix / max(cs * 0.09, 1.0) + so * 2.0);
	vec2 ci = floor(pw);
	float best = -9.0;
	float second = -9.0;
	float age = 0.0;
	float cid = 0.0;
	float dist_c = 9.0;
	float halo = 0.0;
	float lobe_px = kind <= 1 ? 9.0 : 5.0;
	float rough = fbm(pix / max(lobe_px * ps, 1.0) + so * 1.7) - 0.5;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 cell = ci + vec2(float(x), float(y));
			vec2 hk = mod(cell + so, 289.0);
			float h0 = hash12(hk);
			if (h0 > density * 0.85 + 0.1) {
				continue;
			}
			vec2 ctr = cell + hash22(hk + 1.3);
			float birth = hash12(hk + 2.9) * 0.8;
			float hr = hash12(hk + 4.1);
			float rate = 0.35 + 1.25 * hr * hr;
			vec2 cuv = (ctr * cs) / sz;
			vec4 t0 = texture(TEXTURE, clamp(cuv, vec2(0.0), vec2(1.0)));
			vec4 t1 = texture(TEXTURE, clamp(cuv + vec2(0.01, 0.0), vec2(0.0), vec2(1.0)));
			vec4 t2 = texture(TEXTURE, clamp(cuv - vec2(0.0, 0.01), vec2(0.0), vec2(1.0)));
			float l0 = t0.a > 0.0001 ? dot(t0.rgb / t0.a, LUMA) : 0.5;
			float l1 = t1.a > 0.0001 ? dot(t1.rgb / t1.a, LUMA) : 0.5;
			float l2 = t2.a > 0.0001 ? dot(t2.rgb / t2.a, LUMA) : 0.5;
			float damp = 1.0 - (l0 * 0.5 + l1 * 0.25 + l2 * 0.25);
			rate *= mix(1.0, 0.3 + 1.5 * damp, prefer_dark);
			float life = clamp((g - birth) / max(1.0 - birth, 0.05), 0.0, 1.0);
			float R = 1.5 * rate * pow(life, 0.8);
			if (R <= 0.0) {
				continue;
			}
			float d = length(pw - ctr);
			float s = R - d + rough * min(R, 0.6) * (kind <= 1 ? 0.45 : 0.3);
			halo = max(halo, smoothstep(-0.45 * R - 0.15, 0.0, s) * smoothstep(0.0, 0.2, R));
			if (s > best) {
				second = best;
				best = s;
				age = clamp(s / max(R, 0.001), 0.0, 1.0);
				cid = h0;
				dist_c = d;
			} else if (s > second) {
				second = s;
			}
		}
	}
	float edge_soft = kind >= 2 ? 0.05 + 0.04 * fine : 0.012;
	float cover = smoothstep(-edge_soft, edge_soft * 0.5, best);
	float lum = dot(rgb, LUMA);
	float light = 0.45 + 0.75 * smoothstep(0.0, 0.85, lum);
	vec3 stained = rgb;
	if (kind == 3) {
		stained = mix(rgb, rgb * vec3(0.8, 0.72, 0.52), halo * stain * 0.85);
	} else if (kind == 2) {
		stained = mix(rgb, rgb * vec3(0.86, 0.88, 0.7), halo * stain * 0.7);
	} else {
		stained = mix(rgb, rgb * vec3(0.8, 0.84, 0.74), halo * stain * 0.5);
	}
	vec3 col = stained;
	float height = 0.0;
	if (kind <= 1) {
		float aid;
		float ce = cell_edge(pix / max(cs * 0.07, 1.0) + so + warp * 2.0, aid);
		float crack = 1.0 - smoothstep(0.02, 0.1, ce + (fine - 0.5) * 0.06);
		crack *= smoothstep(0.1, 0.35, age);
		vec3 body;
		vec3 rim;
		if (kind == 0) {
			body = mix(vec3(0.6, 0.66, 0.52), vec3(0.74, 0.76, 0.5), cid);
			body = mix(body, vec3(0.7, 0.7, 0.64), step(0.75, cid));
			rim = body * 1.12 + 0.05;
		} else {
			body = mix(vec3(0.92, 0.5, 0.1), vec3(0.96, 0.66, 0.15), cid);
			rim = vec3(0.98, 0.78, 0.3);
		}
		float tone = 0.82 + 0.3 * aid + 0.35 * (fine - 0.5);
		body *= tone;
		col = mix(body, rim, smoothstep(0.14, 0.0, age));
		col *= 1.0 - crack * 0.6;
		vec2 ap = pix / max(cs * 0.045, 1.0) + so * 3.0;
		vec2 apc = floor(ap);
		vec2 apo = hash22(mod(apc, 289.0) + 7.7);
		float apr = 0.14 + 0.2 * hash12(mod(apc, 289.0) + 1.1);
		float apd = length(fract(ap) - apo * 0.6 - 0.2);
		float has_ap = step(0.66, hash12(mod(apc, 289.0) + 9.3)) * smoothstep(0.4, 0.7, age);
		float disc = (1.0 - smoothstep(apr - 0.04, apr, apd)) * has_ap;
		vec3 disc_col = kind == 0 ? vec3(0.3, 0.22, 0.15) : vec3(0.82, 0.34, 0.05);
		vec3 disc_rim = kind == 0 ? body * 1.12 : vec3(0.98, 0.7, 0.2);
		col = mix(col, mix(disc_col, disc_rim, smoothstep(apr * 0.55, apr, apd)), disc);
		float meet = smoothstep(0.06, 0.0, best - second) * step(-0.02, second);
		col = mix(col, vec3(0.12, 0.12, 0.1), meet * 0.85);
		col *= light;
		height = (1.0 - crack) * (0.5 + 0.3 * aid) + disc * 0.6 - meet * 0.4;
	} else if (kind == 2) {
		float ring = 0.5 + 0.5 * sin(dist_c * 24.0 + cid * 12.0 + (fine - 0.5) * 5.0);
		vec3 white = vec3(0.92, 0.93, 0.88) * (0.88 + 0.18 * fine);
		vec3 spore = mix(vec3(0.26, 0.47, 0.4), vec3(0.42, 0.52, 0.3), cid);
		spore *= 0.88 + 0.16 * ring + 0.3 * (fine - 0.5);
		float sporing = smoothstep(0.3, 0.7, age + (fine - 0.5) * 0.2);
		col = mix(white, spore, sporing);
		col *= mix(1.0, light, 0.25);
		height = 0.55 + 0.35 * fine + 0.08 * ring;
	} else {
		float dens = clamp(best * 2.4 + 0.6, 0.0, 1.0);
		float m = 0.0;
		for (int l = 0; l < 2; l++) {
			float cell_px = l == 0 ? 3.2 : 8.5;
			vec2 dp = pix / max(cell_px * ps, 1.0) + so * (1.0 + float(l));
			vec2 dc = floor(dp);
			for (int yy = -1; yy <= 1; yy++) {
				for (int xx = -1; xx <= 1; xx++) {
					vec2 gc = dc + vec2(float(xx), float(yy));
					vec2 hk = mod(gc, 289.0);
					float on = step(hash12(hk + 0.7), dens * (l == 0 ? 1.0 : 0.7));
					vec2 o = hash22(hk + 2.3);
					float rr = 0.25 + 0.4 * hash12(hk + 5.1) * (0.6 + 0.6 * dens);
					float dd = length(dp - gc - o);
					m = max(m, on * (1.0 - smoothstep(rr * 0.6, rr, dd)));
				}
			}
		}
		m = max(m, smoothstep(0.55, 0.9, dens + (fine - 0.5) * 0.3));
		vec3 dark = mix(vec3(0.06, 0.065, 0.05), vec3(0.18, 0.17, 0.12), fine);
		col = mix(stained, dark * mix(1.0, light, 0.4), m * 0.95);
		cover = smoothstep(-0.6, -0.2, best);
		height = m * 0.4;
	}
	float hx = dFdx(height * cover);
	float hy2 = dFdy(height * cover);
	float shade = clamp(1.0 + (-hx - hy2) * 2.5 * relief, 0.6, 1.4);
	col *= shade;
	float rimshadow = kind == 3 ? 0.0 : smoothstep(0.0, -0.1, best) * smoothstep(-0.25, -0.03, best) * relief * 0.3;
	vec3 under = stained * (1.0 - rimshadow);
	vec3 outc = mix(under, clamp(col, 0.0, 1.0), cover);
	COLOR = vec4(outc * a, a);
}

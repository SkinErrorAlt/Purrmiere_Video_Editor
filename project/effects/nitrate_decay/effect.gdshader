shader_type canvas_item;
render_mode blend_disabled;

uniform float decay : hint_range(0.0, 1.0) = 0.4;
uniform float boil : hint_range(0.0, 1.0) = 0.55;
uniform float frame_rate : hint_range(1.0, 60.0) = 24.0;
uniform float blob_size : hint_range(20.0, 800.0) = 260.0;
uniform float bubbling : hint_range(0.0, 1.0) = 0.6;
uniform float crust : hint_range(0.0, 1.0) = 0.7;
uniform float melt : hint_range(0.0, 1.0) = 0.5;
uniform float sludge : hint_range(0.0, 1.0) = 0.3;
uniform int tone : hint_range(0, 2) = 0;
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
	for (int i = 0; i < 5; i++) {
		s += vnoise(p) * a;
		p = mat2(vec2(1.6, -1.2), vec2(1.2, 1.6)) * p + vec2(5.1, 1.7);
		a *= 0.5;
	}
	return s / 0.96875;
}

float fbm3(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		s += vnoise(p) * a;
		p = mat2(vec2(1.6, -1.2), vec2(1.2, 1.6)) * p + vec2(5.1, 1.7);
		a *= 0.5;
	}
	return s / 0.875;
}

float bubbles(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float best = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 hk = mod(i + g, 289.0);
			vec2 o = hash22(hk);
			float r = 0.35 + 0.5 * hash12(hk + 3.1);
			float d = length(g + o - f) / r;
			best = max(best, 1.0 - d);
		}
	}
	return clamp(best, 0.0, 1.0);
}

float field(vec2 p, float fr, float bo, vec2 so) {
	vec2 jit = (hash22(vec2(fr, 7.0) + so) - 0.5) * bo * 0.35;
	vec2 fresh = (hash22(vec2(fr, 3.0) + so) - 0.5) * 40.0;
	float keep = fbm3(p + so + jit);
	float frame_own = fbm3(p * 1.1 + fresh);
	float f = mix(keep, frame_own, bo * 0.4);
	return (f - 0.5) * 2.2 + 0.5;
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pix = UV * sz;
	float sk = mod(float(seed), 997.0);
	vec2 so = vec2(sk * 0.419 + 23.0, sk * 0.787 + 3.0);
	float fr = floor(max(clip_time, 0.0) * max(frame_rate, 1.0) + 0.0001);
	float bs = max(blob_size * ps, 4.0);
	vec2 p = pix / bs;
	float bo = clamp(boil, 0.0, 1.0);
	float f0 = field(p, fr, bo, so);
	vec2 bj = (hash22(vec2(fr, 11.0) + so) - 0.5) * bo * 3.0;
	float bub = bubbles(pix / max(bs * 0.06, 1.0) + bj + so);
	float bub2 = bubbles(pix / max(bs * 0.022, 1.0) + bj * 2.0 + so * 1.7);
	float fe = f0 + (bub * 0.7 + bub2 * 0.3 - 0.35) * bubbling * 0.12 + (fbm(p * 4.0 + so) - 0.5) * 0.12;
	float thr = mix(1.35, 0.05, clamp(decay, 0.0, 1.0));
	float inside = smoothstep(thr, thr + 0.02, fe) * step(0.001, decay);
	float near = smoothstep(thr - 0.2, thr, fe) * step(0.001, decay);
	vec2 g = vec2(dFdx(f0), dFdy(f0));
	vec2 dir = g / max(length(g), 1e-6);
	float m = melt * near * (1.0 - inside * 0.5);
	vec2 off = dir * m * 22.0 * ps * (0.6 + 0.4 * vnoise(p * 6.0 + so));
	vec4 base = texture(TEXTURE, UV);
	float a = base.a;
	vec3 rgb = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		float t = float(i) / 3.0;
		vec4 c = texture(TEXTURE, clamp((pix - off * t) / sz, vec2(0.0), vec2(1.0)));
		rgb += c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	}
	rgb *= 0.25;
	float l = dot(rgb, LUMA);
	if (tone == 1) {
		rgb = mix(rgb, vec3(l) * vec3(1.08, 0.88, 0.98) + vec3(0.04, 0.0, 0.03), 0.55);
	} else if (tone == 2) {
		rgb = vec3(l);
	}
	rgb = mix(rgb, rgb * vec3(1.02, 0.94, 0.78), near * 0.6);
	float which = fbm(p * 0.6 + so * 2.0 + vec2(fr * bo * 0.13, 0.0));
	float dark = smoothstep(0.62 - sludge * 0.3, 0.68 - sludge * 0.3, which) * step(0.001, sludge);
	float mott = fbm(pix / max(bs * 0.04, 1.0) + so + bj);
	vec3 hollow = vec3(0.96, 0.88, 0.66) * (0.86 + 0.2 * mott);
	hollow = mix(hollow, hollow * (0.7 + 0.45 * l), 0.35);
	vec3 rot = vec3(0.2, 0.13, 0.07) * (0.7 + 0.6 * mott);
	vec3 inner = mix(hollow, rot, dark);
	float edge = smoothstep(thr - 0.06, thr, fe) * (1.0 - smoothstep(thr + 0.01, thr + 0.06, fe));
	float crystals = pow(bub2, 2.0);
	vec3 crust_col = mix(vec3(0.36, 0.2, 0.08), vec3(0.7, 0.45, 0.16), crystals);
	vec3 col = mix(rgb, inner, inside);
	col = mix(col, crust_col, clamp(edge * crust * (0.7 + 0.5 * crystals), 0.0, 1.0));
	float halo = smoothstep(thr - 0.18, thr - 0.06, fe) * (1.0 - smoothstep(thr - 0.06, thr, fe));
	col = mix(col, col * 0.8 + vec3(0.18, 0.15, 0.1), halo * 0.35 * crust);
	float flick = 1.0 + (hash12(vec2(fr, 19.0) + so) - 0.5) * 0.06 * bo * step(0.001, decay);
	col *= flick;
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}

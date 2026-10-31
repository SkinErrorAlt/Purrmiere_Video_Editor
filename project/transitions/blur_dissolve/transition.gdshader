shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float amount : hint_range(0.0, 200.0) = 60.0;
uniform int kind = 0;
uniform int curve = 1;
uniform float highlights : hint_range(0.0, 1.0) = 0.8;
uniform float cats_eye : hint_range(0.0, 1.0) = 0.3;
const float LENS_FOOTPRINT = 0.95;

const int TAPS = 20;

float jitter(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

vec4 both_at(vec2 uv, float w) {
	vec4 c = vec4(0.0);
	if (w < 1.0) {
		c += from_clamped(uv) * (1.0 - w);
	}
	if (w > 0.0) {
		c += to_clamped(uv) * w;
	}
	return c;
}

vec3 lens_expand(vec3 s, float h) {
	vec3 l = s * s;
	return l / max(vec3(1.0) - h * l, vec3(0.05));
}

vec3 lens_compress(vec3 e, float h) {
	vec3 l = e / (vec3(1.0) + h * e);
	return sqrt(max(l, vec3(0.0)));
}

vec2 disc_point(vec2 u) {
	vec2 a = u * 2.0 - 1.0;
	if (abs(a.x) < 0.000001 && abs(a.y) < 0.000001) {
		return vec2(0.0);
	}
	float r;
	float phi;
	if (abs(a.x) > abs(a.y)) {
		r = a.x;
		phi = TR_PI * 0.25 * (a.y / a.x);
	} else {
		r = a.y;
		phi = TR_PI * 0.5 - TR_PI * 0.25 * (a.x / a.y);
	}
	return r * vec2(cos(phi), sin(phi));
}

vec4 lens_blur(vec2 uv, float radius, float w) {
	const int N = 128;
	float h = clamp(highlights, 0.0, 1.0) * 0.75;
	vec2 cell = floor(uv * frame_px);
	vec2 par = mod(cell, 2.0);
	float qi = par.x + 2.0 * par.y;
	bool split = w > 0.0 && w < 1.0;
	float spacing = radius * sqrt(TR_PI / float(N * 4)) * (split ? 1.41421356 : 1.0);
	float lod = clamp(log2(max(spacing * LENS_FOOTPRINT, 1.0)), 0.0, float(max(tr_pyr_levels - 1, 0)));
	float lod_i = floor(lod);
	float lod_t = lod - lod_i;
	int l0 = int(lod_i);
	vec2 org[4];
	vec2 siz[4];
	for (int j = 0; j < 4; j++) {
		int lv = min(l0 + j, max(tr_pyr_levels, 0));
		siz[j] = lv <= 0 ? frame_px : tr_level_px(lv);
		org[j] = lv <= 0 ? vec2(-1.0) : tr_level_origin(lv);
	}
	vec3 lift_top = lens_expand(vec3(1.0), h);
	float r2 = tr_ratio();
	vec2 v = (uv - 0.5) * vec2(r2, 1.0) / (0.5 * sqrt(r2 * r2 + 1.0));
	vec2 eye = v * cats_eye * 0.9;
	vec4 ef = vec4(0.0);
	vec4 et = vec4(0.0);
	float nf = 0.0;
	float nt = 0.0;
	for (int i = 0; i < N; i++) {
		float k = float(i) * 4.0 + qi + 1.0;
		vec2 o = disc_point(fract(vec2(k) * vec2(0.7548776662, 0.5698402910) + 0.5));
		vec2 oe = o - eye;
		if (dot(oe, oe) > 1.0) {
			continue;
		}
		vec2 at = clamp(uv + o * radius / frame_px, vec2(0.0), vec2(1.0));
		bool use_to = split ? (i >= N / 2) : (w >= 1.0);
		int j = fract(k * 0.6180339887 + 0.31) < lod_t - 0.00001 ? 1 : 0;
		vec4 c;
		if (org[j].x < 0.0) {
			c = use_to ? to_clamped(at) : from_clamped(at);
		} else {
			c = tr_pyr_tap(!use_to, org[j], siz[j], at * siz[j]);
		}
		vec4 bc = tr_pyr_levels <= 0 ? c : tr_pyr_tap(!use_to, org[j + 2], siz[j + 2], at * siz[j + 2]);
		vec3 s = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
		vec3 sb = bc.a > 0.0001 ? clamp(bc.rgb / bc.a, 0.0, 1.0) : vec3(0.0);
		vec3 lb = lens_expand(sb, h);
		vec3 frac = clamp((s - sb) / max(vec3(1.0) - sb, vec3(0.05)), 0.0, 1.0);
		vec3 lifted = mix(lens_expand(s, h), mix(lb, lift_top, frac), step(sb, s));
		vec4 e = vec4(lifted * c.a, c.a);
		if (use_to) {
			et += e;
			nt += 1.0;
		} else {
			ef += e;
			nf += 1.0;
		}
	}
	vec4 sum;
	if (nf > 0.0 && nt > 0.0) {
		sum = mix(ef / nf, et / nt, w);
	} else if (nt > 0.0) {
		sum = et / nt;
	} else {
		sum = ef / max(nf, 1.0);
	}
	vec3 s = sum.a > 0.0001 ? sum.rgb / sum.a : vec3(0.0);
	vec4 res = vec4(lens_compress(s, h) * sum.a, sum.a);
	vec2 dpar = vec2(dFdx(par.x), dFdy(par.y));
	float sx = ((par.x < 0.5) == (dpar.x > 0.0)) ? 1.0 : -1.0;
	float sy = ((par.y < 0.5) == (dpar.y > 0.0)) ? 1.0 : -1.0;
	vec4 nx = res + sx * dFdx(res);
	vec4 ny = res + sy * dFdy(res);
	vec4 nxy = ny + sx * dFdx(ny);
	vec4 quad = (res + nx + ny + nxy) * 0.25;
	return mix(res, quad, smoothstep(0.5, 3.0, radius));
}

vec4 transition(vec2 uv) {
	float p = progress;
	float w = tr_ease(p, curve == 1 ? 3 : 0);
	float env = sin(TR_PI * clamp(p, 0.0, 1.0));
	float radius = amount * px_scale * env;
	if (kind == 4 && radius >= 0.01) {
		vec4 lensed = lens_blur(uv, radius, w);
		return tr_inside(uv) ? lensed : vec4(0.0);
	}
	if (radius < 0.01 || !tr_inside(uv)) {
		return mix(from_at(uv), to_at(uv), w);
	}
	vec2 px = 1.0 / frame_px;
	float spin = jitter(uv * frame_px) * TR_PI * 2.0;
	vec4 acc = vec4(0.0);
	float total = 0.0;
	for (int i = 0; i < TAPS; i++) {
		float fi = (float(i) + 0.5) / float(TAPS);
		vec2 off;
		if (kind == 0) {
			float a = float(i) * 2.39996323 + spin;
			off = vec2(cos(a), sin(a)) * sqrt(fi) * radius * px;
		} else if (kind == 1) {
			off = vec2((fi - 0.5) * 2.0 + (jitter(uv * frame_px + 7.0) - 0.5) / float(TAPS), 0.0) * radius * px;
		} else if (kind == 2) {
			off = vec2(0.0, (fi - 0.5) * 2.0 + (jitter(uv * frame_px + 7.0) - 0.5) / float(TAPS)) * radius * px;
		} else {
			float z = (fi + (jitter(uv * frame_px + 3.0) - 0.5) / float(TAPS)) * radius / max(frame_px.y, 1.0) * 2.0;
			off = (vec2(0.5) - uv) * z;
		}
		float g = kind == 0 ? exp(-2.0 * fi) : exp(-3.0 * pow(abs(fi - 0.5) * 2.0, 2.0));
		if (kind == 3) {
			g = 1.0;
		}
		acc += both_at(uv + off, w) * g;
		total += g;
	}
	return acc / total;
}

void fragment() {
	COLOR = transition(UV);
}

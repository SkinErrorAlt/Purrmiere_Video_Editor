shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform int way = 0;
uniform float spin : hint_range(-360.0, 360.0) = 35.0;
uniform float zoom : hint_range(0.2, 1.5) = 0.5;
uniform float blur : hint_range(0.0, 2.0) = 0.6;
uniform vec2 centre = vec2(0.5, 0.5);
uniform int curve = 1;

const int MAX_SAMPLES = 64;
const float STEP_PX = 1.25;
const float SEAM = 0.7;

float pw_curve(float t) {
	t = clamp(t, 0.0, 1.0);
	if (curve == 2) {
		return t;
	}
	float k = curve == 1 ? 2.0 : 3.0;
	return t < 0.5 ? 0.5 * pow(2.0 * t, k) : 1.0 - 0.5 * pow(2.0 - 2.0 * t, k);
}

vec4 pw_pick(bool use_from, vec2 q) {
	return use_from ? from_mirrored(q) : to_mirrored(q);
}

vec4 pw_ring(bool use_from, float alpha, float r0, float vy) {
	float ratio = tr_ratio();
	vec4 col = pw_pick(use_from, vec2(alpha * r0 / ratio + 0.5, vy));
	float sw = 0.5 * smoothstep(TR_PI - SEAM, TR_PI, abs(alpha));
	if (sw > 0.0) {
		float alt = alpha - sign(alpha) * 2.0 * TR_PI;
		vec4 other = pw_pick(use_from, vec2(alt * r0 / ratio + 0.5, vy));
		col = mix(col, other, sw);
	}
	return col;
}

vec4 pw_side(vec2 uv, float s, float dir_sign, bool use_from) {
	float ratio = tr_ratio();
	float a = amount * smoothstep(0.0, 0.75, s);
	float phi = radians(spin) * 0.5 * s * s * dir_sign;
	vec2 cp = tr_world(centre);
	float zz = mix(1.0, zoom, a);
	vec2 p = cp + tr_rotate(tr_world(uv) - cp, -phi) / zz;
	if (a < 0.001) {
		return pw_pick(use_from, tr_frame_uv(p));
	}
	float r0 = ratio / (2.0 * TR_PI * a);
	float rb = r0 * (1.0 - a);
	float flip = way == 1 ? -1.0 : 1.0;
	vec2 q = mix(vec2(0.0, -0.5 * flip), cp, a);
	vec2 c = q - vec2(0.0, rb * flip);
	vec2 v = p - c;
	float rho = length(v);
	float alpha = atan(v.x, v.y * flip);
	float h = rho - rb;
	float vy = way == 1 ? h : 1.0 - h;
	float pix = 1.0 / (frame_px.y * zz);
	float da = pix / max(rho, pix);
	if (da < 0.06) {
		return pw_ring(use_from, alpha, r0, vy);
	}
	vec4 acc = vec4(0.0);
	for (int i = 0; i < 4; i++) {
		acc += pw_ring(use_from, alpha + da * (float(i) - 1.5) * 0.25, r0, vy);
	}
	return acc * 0.25;
}

vec4 pw_at(vec2 uv, float t) {
	float e = pw_curve(t);
	float hb = 1.5 / (50.0 * max(duration, 0.05));
	float wgt = smoothstep(0.5 - hb, 0.5 + hb, t);
	vec4 c = vec4(0.0);
	if (wgt < 1.0) {
		c += pw_side(uv, 2.0 * e, 1.0, true) * (1.0 - wgt);
	}
	if (wgt > 0.0) {
		c += pw_side(uv, 2.0 - 2.0 * e, -1.0, false) * wgt;
	}
	return c;
}

vec2 pw_pos(vec2 uv, float t) {
	float e = pw_curve(t);
	float s = t < 0.5 ? 2.0 * e : 2.0 - 2.0 * e;
	float sg = t < 0.5 ? 1.0 : -1.0;
	float ratio = tr_ratio();
	float a = amount * smoothstep(0.0, 0.75, s);
	float phi = radians(spin) * 0.5 * s * s * sg;
	vec2 cp = tr_world(centre);
	float zz = mix(1.0, zoom, a);
	vec2 pp = cp + tr_rotate(tr_world(uv) - cp, -phi) / zz;
	if (a < 0.001) {
		return tr_frame_uv(pp);
	}
	float r0 = ratio / (2.0 * TR_PI * a);
	float rb = r0 * (1.0 - a);
	float flip = way == 1 ? -1.0 : 1.0;
	vec2 q = mix(vec2(0.0, -0.5 * flip), cp, a);
	vec2 c = q - vec2(0.0, rb * flip);
	vec2 v = pp - c;
	return vec2(atan(v.x, v.y * flip) * r0 / ratio, length(v) - rb);
}

float pw_noise(vec2 uv) {
	vec2 p = floor(uv * frame_px);
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	if (p <= 0.0) {
		return texture(from_tex, uv);
	}
	if (p >= 1.0) {
		return texture(to_tex, uv);
	}
	float win = blur / (25.0 * max(duration, 0.05));
	win *= 1.0 + 2.0 * (1.0 - smoothstep(0.0, 0.05, abs(p - 0.5)));
	win = min(win, 2.0 * min(p, 1.0 - p));
	if (win < 0.0005) {
		return pw_at(uv, p);
	}
	float t0 = p - 0.5 * win;
	float t1 = p + 0.5 * win;
	int n = MAX_SAMPLES;
	if (t1 < 0.5 || t0 > 0.5) {
		vec2 a = pw_pos(uv, t0);
		vec2 m = pw_pos(uv, p);
		vec2 b = pw_pos(uv, t1);
		float len_px = length((m - a) * frame_px) + length((b - m) * frame_px);
		if (abs(m.x - a.x) > 0.5 || abs(b.x - m.x) > 0.5) {
			len_px = 1000.0;
		}
		n = clamp(int(ceil(len_px / STEP_PX)), 3, MAX_SAMPLES);
	}
	float j = pw_noise(uv);
	vec4 acc = vec4(0.0);
	for (int i = 0; i < MAX_SAMPLES; i++) {
		if (i >= n) {
			break;
		}
		float t = t0 + (float(i) + j) / float(n) * win;
		acc += pw_at(uv, t);
	}
	return acc / float(n);
}

void fragment() {
	COLOR = transition(UV);
}

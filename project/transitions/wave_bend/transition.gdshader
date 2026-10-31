shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float waves : hint_range(0.5, 6.0) = 1.5;
uniform float amplitude : hint_range(0.0, 0.3) = 0.15;
uniform float travel : hint_range(0.0, 1.0) = 0.3;
uniform float speed : hint_range(0.0, 4.0) = 1.5;
uniform float blur : hint_range(0.0, 2.0) = 0.6;
uniform int curve = 0;

const int MAX_SAMPLES = 40;
const float STEP_PX = 1.25;

float wb_curve(float t) {
	t = clamp(t, 0.0, 1.0);
	if (curve == 2) {
		return t;
	}
	float k = curve == 1 ? 2.0 : 3.0;
	return t < 0.5 ? 0.5 * pow(2.0 * t, k) : 1.0 - 0.5 * pow(2.0 - 2.0 * t, k);
}

vec2 wb_dir() {
	if (direction == 1) {
		return vec2(1.0, 0.0);
	} else if (direction == 2) {
		return vec2(0.0, 1.0);
	} else if (direction == 3) {
		return vec2(0.0, -1.0);
	}
	return vec2(-1.0, 0.0);
}

vec2 wb_src(vec2 uv, float t, float e, float mu) {
	float ratio = tr_ratio();
	vec2 w = tr_world(uv);
	vec2 d = wb_dir();
	vec2 n = vec2(-d.y, d.x);
	bool level = abs(d.x) > 0.5;
	float len = level ? ratio : 1.0;
	float across = level ? 1.0 : ratio;
	float along = dot(w, d) / len;
	float side = dot(w, n) / across;
	float env = pow(sin(TR_PI * e), 1.5);
	float pin = cos(TR_PI * clamp(side, -0.5, 0.5));
	float phase = 2.0 * TR_PI * (waves * along - speed * t);
	float bend = amplitude * env * pin * sin(phase);
	float push = sign(mu) * pow(max(abs(mu) - 0.45, 0.0) / 0.55, 3.0);
	return tr_frame_uv(w - d * travel * len * push - n * bend);
}

float wb_wb(float t) {
	float hb = 1.5 / (50.0 * max(duration, 0.05));
	return smoothstep(0.5 - hb, 0.5 + hb, t);
}

vec4 wb_at(vec2 uv, float t) {
	float e = wb_curve(t);
	float wgt = wb_wb(t);
	vec4 c = vec4(0.0);
	if (wgt < 1.0) {
		c += from_mirrored(wb_src(uv, t, e, 2.0 * e)) * (1.0 - wgt);
	}
	if (wgt > 0.0) {
		c += to_mirrored(wb_src(uv, t, e, 2.0 * e - 2.0)) * wgt;
	}
	return c;
}

vec2 wb_pos(vec2 uv, float t) {
	float e = wb_curve(t);
	return wb_src(uv, t, e, t < 0.5 ? 2.0 * e : 2.0 * e - 2.0);
}

float wb_noise(vec2 uv) {
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
	win = min(win, 2.0 * min(p, 1.0 - p));
	if (win < 0.0005) {
		return wb_at(uv, p);
	}
	float t0 = p - 0.5 * win;
	float t1 = p + 0.5 * win;
	int n = MAX_SAMPLES;
	if (t1 < 0.5 || t0 > 0.5) {
		vec2 a = wb_pos(uv, t0);
		vec2 m = wb_pos(uv, p);
		vec2 b = wb_pos(uv, t1);
		float len_px = length((m - a) * frame_px) + length((b - m) * frame_px);
		n = clamp(int(ceil(len_px / STEP_PX)), 3, MAX_SAMPLES);
	}
	float j = wb_noise(uv);
	vec4 acc = vec4(0.0);
	for (int i = 0; i < MAX_SAMPLES; i++) {
		if (i >= n) {
			break;
		}
		float t = t0 + (float(i) + j) / float(n) * win;
		acc += wb_at(uv, t);
	}
	return acc / float(n);
}

void fragment() {
	COLOR = transition(UV);
}

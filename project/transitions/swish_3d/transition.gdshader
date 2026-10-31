shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int axis = 0;
uniform int turn = 0;
uniform int direction = 0;
uniform float lens : hint_range(10.0, 90.0) = 45.0;
uniform float pivot : hint_range(0.0, 3.0) = 1.0;
uniform bool seamless = true;
uniform float blur : hint_range(0.0, 2.0) = 1.0;
uniform float shutter : hint_range(0.0, 720.0) = 360.0;
uniform float shading : hint_range(0.0, 1.0) = 0.4;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int curve = 0;

const int MAX_SAMPLES = 40;
const float STEP_PX = 1.25;

float sw_curve(float t) {
	t = clamp(t, 0.0, 1.0);
	if (curve == 2) {
		return t;
	}
	float k = curve == 1 ? 2.0 : 4.0;
	return t < 0.5 ? 0.5 * pow(2.0 * t, k) : 1.0 - 0.5 * pow(2.0 - 2.0 * t, k);
}

vec3 sw_axis() {
	vec3 a = vec3(0.0, 1.0, 0.0);
	if (axis == 1) {
		a = vec3(1.0, 0.0, 0.0);
	} else if (axis == 2) {
		a = normalize(vec3(1.0, 1.0, 0.0));
	}
	return direction == 1 ? -a : a;
}

float sw_turn() {
	if (turn == 1) {
		return 180.0;
	} else if (turn == 2) {
		return 360.0;
	}
	return 90.0;
}

float sw_vis(float ang) {
	if (turn == 0) {
		return ang;
	} else if (turn == 1) {
		return ang * 0.75;
	}
	return ang - 12.0 * sin(radians(2.0 * ang));
}

mat3 sw_rot(vec3 a, float deg) {
	float r = radians(deg);
	float c = cos(r);
	float s = sin(r);
	mat3 k = mat3(vec3(0.0, a.z, -a.y), vec3(-a.z, 0.0, a.x), vec3(a.y, -a.x, 0.0));
	return mat3(1.0) + s * k + (1.0 - c) * (k * k);
}

vec4 sw_far(bool use_from) {
	vec4 acc = vec4(0.0);
	for (int y = 0; y < 3; y++) {
		for (int x = 0; x < 3; x++) {
			vec2 q = vec2(0.17 + 0.33 * float(x), 0.17 + 0.33 * float(y));
			acc += use_from ? texture(from_tex, q) : texture(to_tex, q);
		}
	}
	return acc / 9.0;
}

vec4 sw_plane(vec2 uv, float ang, bool use_from, vec4 far_col, out bool covered) {
	covered = false;
	float d = tr_camera_distance(lens);
	vec3 cam = vec3(0.0, 0.0, -d);
	vec3 dir = normalize(vec3(tr_world(uv), 0.0) - cam);
	mat3 r = sw_rot(sw_axis(), ang);
	mat3 ri = transpose(r);
	vec3 pv = vec3(0.0, 0.0, pivot);
	vec3 o = ri * (cam - pv) + pv;
	vec3 dl = ri * dir;
	vec3 n = r * vec3(0.0, 0.0, -1.0);
	float light = mix(1.0, 0.3 + 0.7 * abs(n.z), shading);
	if (abs(dl.z) < 0.000001) {
		if (seamless) {
			covered = true;
			return tr_shade(far_col, light);
		}
		return vec4(0.0);
	}
	float t = -o.z / dl.z;
	vec2 cuv = tr_frame_uv((o + dl * t).xy);
	if (!seamless) {
		if (t <= 0.0 || !tr_inside(cuv)) {
			return vec4(0.0);
		}
		covered = true;
		vec4 c = use_from ? texture(from_tex, cuv) : texture(to_tex, cuv);
		return tr_shade(c, light);
	}
	covered = true;
	vec4 c = use_from ? from_mirrored(cuv) : to_mirrored(cuv);
	float fog = smoothstep(8.0, 40.0, abs(t) / d);
	c = mix(c, far_col, fog * 0.45);
	return tr_shade(c, light);
}

vec4 sw_at(vec2 uv, float t, vec4 far_a, vec4 far_b, out float cover) {
	float e = sw_curve(t);
	float tn = sw_turn();
	bool use_from = t < 0.5;
	float ang = sw_vis(use_from ? tn * e : tn * (e - 1.0));
	bool covered;
	vec4 c = sw_plane(uv, ang, use_from, use_from ? far_a : far_b, covered);
	cover = covered ? 1.0 : 0.0;
	return c;
}

vec2 sw_pos(vec2 uv, float t, bool side_a) {
	float e = sw_curve(t);
	float tn = sw_turn();
	float ang = sw_vis(side_a ? tn * e : tn * (e - 1.0));
	float d = tr_camera_distance(lens);
	vec3 cam = vec3(0.0, 0.0, -d);
	vec3 dir = normalize(vec3(tr_world(uv), 0.0) - cam);
	mat3 ri = transpose(sw_rot(sw_axis(), ang));
	vec3 pv = vec3(0.0, 0.0, pivot);
	vec3 o = ri * (cam - pv) + pv;
	vec3 dl = ri * dir;
	if (abs(dl.z) < 0.000001) {
		return vec2(1000.0);
	}
	float th = -o.z / dl.z;
	return tr_frame_uv((o + dl * th).xy);
}

float sw_noise(vec2 uv) {
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
	vec4 far_a = vec4(0.0);
	vec4 far_b = vec4(0.0);
	if (seamless) {
		far_a = sw_far(true);
		far_b = sw_far(false);
	}
	float bg_weight = smoothstep(0.0, 0.08, p) * (1.0 - smoothstep(0.92, 1.0, p));
	vec4 bg = vec4(background.rgb * background.a, background.a) * bg_weight;
	float win = blur * (shutter / 360.0) * (turn == 2 ? 0.5 : 90.0 / sw_turn()) / (25.0 * max(duration, 0.05));
	win = min(win, 2.0 * min(p, 1.0 - p));
	if (win < 0.0005) {
		float cv;
		vec4 c = sw_at(uv, p, far_a, far_b, cv);
		return seamless ? c : tr_over(c, bg);
	}
	float t0 = p - 0.5 * win;
	float t1 = p + 0.5 * win;
	bool side_a = p < 0.5;
	vec2 a = sw_pos(uv, t0, side_a);
	vec2 m = sw_pos(uv, p, side_a);
	vec2 b = sw_pos(uv, t1, side_a);
	float len_px = (length((m - a) * frame_px) + length((b - m) * frame_px));
	float cap = (turn == 2 ? 0.045 : 0.07) * frame_px.x;
	if (turn > 0 && len_px > cap) {
		float k = max(cap / len_px, turn == 2 ? 0.15 : 0.35);
		k = mix(k, 1.0, turn == 2 ? 1.0 - smoothstep(0.0, 0.035, abs(p - 0.5)) : 0.0);
		win *= k;
		len_px *= k;
		t0 = p - 0.5 * win;
		t1 = p + 0.5 * win;
	}
	int n = clamp(int(ceil(len_px / STEP_PX)), 3, MAX_SAMPLES);
	if (t0 < 0.5 && t1 > 0.5) {
		n = MAX_SAMPLES;
	}
	float j = sw_noise(uv);
	vec4 acc = vec4(0.0);
	for (int i = 0; i < MAX_SAMPLES; i++) {
		if (i >= n) {
			break;
		}
		float t = t0 + (float(i) + j) / float(n) * win;
		float cv;
		vec4 c = sw_at(uv, t, far_a, far_b, cv);
		acc += seamless ? c : tr_over(c, bg);
	}
	return acc / float(n);
}

void fragment() {
	COLOR = transition(UV);
}

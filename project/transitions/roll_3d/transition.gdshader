shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform int turns = 0;
uniform float curvature : hint_range(0.0, 1.0) = 0.6;
uniform float blur : hint_range(0.0, 2.0) = 1.0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int curve = 0;

const int MAX_SAMPLES = 40;
const float STEP_PX = 1.25;
const float LENS = 40.0;

float rl_curve(float t) {
	t = clamp(t, 0.0, 1.0);
	if (curve == 2) {
		return t;
	}
	float k = curve == 1 ? 2.0 : 4.0;
	return t < 0.5 ? 0.5 * pow(2.0 * t, k) : 1.0 - 0.5 * pow(2.0 - 2.0 * t, k);
}

float rl_frames() {
	if (turns == 1) {
		return 3.0;
	} else if (turns == 2) {
		return 5.0;
	}
	return 1.0;
}

vec2 rl_local(vec2 w) {
	if (direction == 1) {
		return vec2(w.x, -w.y);
	} else if (direction == 2) {
		return vec2(w.y, -w.x);
	} else if (direction == 3) {
		return vec2(w.y, w.x);
	}
	return w;
}

vec2 rl_uv(float a, float f) {
	float ratio = tr_ratio();
	if (direction == 0) {
		return vec2(a / ratio + 0.5, f);
	} else if (direction == 1) {
		return vec2(a / ratio + 0.5, 1.0 - f);
	} else if (direction == 2) {
		return vec2(f, 0.5 - a);
	}
	return vec2(1.0 - f, 0.5 - a);
}

vec4 rl_at(vec2 uv, float t, out float cover, out vec2 cpos) {
	cover = 0.0;
	cpos = vec2(1000.0);
	float e = rl_curve(t);
	float n = rl_frames();
	float scroll = n * e;
	float ratio = tr_ratio();
	bool sideways = direction >= 2;
	float len_b = sideways ? ratio : 1.0;
	float kap = curvature * 2.0 * pow(sin(TR_PI * e), 1.5) / pow(len_b, 1.45);
	vec2 s = rl_local(tr_world(uv));
	float d = tr_camera_distance(LENS);
	vec3 dir = vec3(s.x, s.y, d);
	float aa = kap * (dir.y * dir.y + dir.z * dir.z);
	float bb = dir.z * (1.0 + kap * d);
	float cc = d * (kap * d + 2.0);
	float disc = bb * bb - aa * cc;
	if (disc < 0.0) {
		return vec4(0.0);
	}
	float th = cc / (bb + sqrt(disc));
	float hy = th * dir.y;
	float hz = th * dir.z - d;
	float ha = th * dir.x;
	float phi = 0.0;
	float arc = hy;
	if (kap > 0.0001) {
		phi = atan(kap * hy, 1.0 - kap * hz);
		arc = phi / kap;
	}
	float c = scroll - arc / len_b;
	cpos = vec2(ha, c * len_b);
	float k = floor(c + 0.5);
	float f = c - k + 0.5;
	bool use_from = c < n * 0.5;
	float tile = use_from ? k : k - n;
	if (mod(abs(tile), 2.0) > 0.5) {
		f = 1.0 - f;
	}
	vec2 q = rl_uv(ha, clamp(f, 0.0, 1.0));
	vec4 col = use_from ? from_mirrored(q) : to_mirrored(q);
	float light = mix(1.0, 0.4 + 0.6 * pow(max(cos(phi), 0.0), 0.8), shading);
	cover = 1.0;
	return tr_shade(col, light);
}

float rl_noise(vec2 uv) {
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
	float bg_weight = smoothstep(0.0, 0.08, p) * (1.0 - smoothstep(0.92, 1.0, p));
	vec4 bg = vec4(background.rgb * background.a, background.a) * bg_weight;
	float win = blur / (25.0 * max(duration, 0.05));
	win = min(win, 2.0 * min(p, 1.0 - p));
	float cv;
	vec2 pm;
	vec4 cm = rl_at(uv, p, cv, pm);
	if (win < 0.0005) {
		return cv > 0.0 ? cm : bg;
	}
	float t0 = p - 0.5 * win;
	float t1 = p + 0.5 * win;
	vec2 pa;
	vec2 pb;
	float ca;
	float cb;
	vec4 sa = rl_at(uv, t0, ca, pa);
	vec4 sb = rl_at(uv, t1, cb, pb);
	float len_px = (length(pm - pa) + length(pb - pm)) * frame_px.y;
	int n = clamp(int(ceil(len_px / STEP_PX)), 3, MAX_SAMPLES);
	float j = rl_noise(uv);
	vec4 acc = vec4(0.0);
	for (int i = 0; i < MAX_SAMPLES; i++) {
		if (i >= n) {
			break;
		}
		float t = t0 + (float(i) + j) / float(n) * win;
		float c1;
		vec2 q1;
		vec4 c = rl_at(uv, t, c1, q1);
		acc += c1 > 0.0 ? c : bg;
	}
	return acc / float(n);
}

void fragment() {
	COLOR = transition(UV);
}

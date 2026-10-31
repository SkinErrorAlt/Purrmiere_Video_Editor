shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int move = 0;
uniform int direction = 0;
uniform float warp : hint_range(-1.0, 1.0) = 0.6;
uniform float amount : hint_range(0.0, 1.0) = 0.3;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float fringe : hint_range(0.0, 1.0) = 0.4;
uniform float blur : hint_range(0.0, 2.0) = 1.0;
uniform float blend : hint_range(0.0, 8.0) = 2.0;
uniform int curve = 0;

const int MAX_SAMPLES = 28;
const float STEP_PX = 1.75;

float lw_curve(float t) {
	t = clamp(t, 0.0, 1.0);
	if (curve == 2) {
		return t;
	}
	float k = curve == 1 ? 2.0 : 4.0;
	return t < 0.5 ? 0.5 * pow(2.0 * t, k) : 1.0 - 0.5 * pow(2.0 - 2.0 * t, k);
}

vec2 lw_slide() {
	vec2 d = vec2(-1.0, 0.0);
	if (direction == 1) {
		d = vec2(1.0, 0.0);
	} else if (direction == 2) {
		d = vec2(0.0, 1.0);
	} else if (direction == 3) {
		d = vec2(0.0, -1.0);
	} else if (direction == 4) {
		d = vec2(-1.0, 1.0);
	} else if (direction == 5) {
		d = vec2(1.0, 1.0);
	} else if (direction == 6) {
		d = vec2(-1.0, -1.0);
	} else if (direction == 7) {
		d = vec2(1.0, -1.0);
	}
	return normalize(d);
}

vec2 lw_lens(vec2 q, float k) {
	float r2 = dot(q, q);
	if (k >= 0.0) {
		return q * (1.0 + k * r2);
	}
	return q / sqrt(1.0 - k * r2);
}

vec2 lw_raw(vec2 w, float mu, float chan) {
	float ratio = tr_ratio();
	float s = abs(mu);
	vec2 c = vec2((centre.x - 0.5) * ratio, 0.5 - centre.y);
	vec2 q = w - c;
	float k = warp * 1.3 * s * s;
	vec2 lq = lw_lens(q, k);
	float df = fringe * 0.035 * s * s * dot(q, q);
	lq *= 1.0 + chan * df;
	float zoom_log = log(1.0 + 3.0 * amount);
	float z = 1.0;
	float ang = 0.0;
	vec2 off = vec2(0.0);
	if (move == 0) {
		z = exp(zoom_log * mu);
	} else if (move == 1) {
		z = exp(-zoom_log * mu);
	} else if (move == 2) {
		off = lw_slide() * amount * ratio * mu;
	} else if (move == 3) {
		ang = -amount * TR_PI * mu;
	} else {
		ang = amount * TR_PI * mu;
	}
	return tr_rotate(lq / z, -ang) - off + c;
}

float lw_cover(float mu) {
	float s = abs(mu);
	float wc = 1.0 - smoothstep(0.45, 0.85, s);
	if (wc <= 0.0) {
		return 1.0;
	}
	vec2 hb = vec2(tr_ratio() * 0.5, 0.5);
	float worst = 1.0;
	for (int i = 0; i < 4; i++) {
		vec2 dir = vec2(float(i % 2) * 2.0 - 1.0, float(i / 2) * 2.0 - 1.0);
		vec2 src = lw_raw(dir * hb, mu, 0.0);
		worst = max(worst, max(abs(src.x) / hb.x, abs(src.y) / hb.y));
	}
	return mix(1.0, worst, wc);
}

vec2 lw_src(vec2 uv, float mu, float chan, float cov) {
	return tr_frame_uv(lw_raw(tr_world(uv), mu, chan) / cov);
}

float lw_wb(float t) {
	float hb = blend / (50.0 * max(duration, 0.05));
	return hb > 0.0 ? smoothstep(0.5 - hb, 0.5 + hb, t) : step(0.5, t);
}

vec2 lw_pos(vec2 uv, float t) {
	float e = lw_curve(t);
	float mu = t < 0.5 ? 2.0 * e : 2.0 * e - 2.0;
	return lw_src(uv, mu, 0.0, lw_cover(mu));
}

vec4 lw_take(vec2 uv, float mu, bool use_from) {
	float cov = lw_cover(mu);
	vec2 q = lw_src(uv, mu, 0.0, cov);
	vec4 c = use_from ? from_mirrored(q) : to_mirrored(q);
	if (fringe > 0.0) {
		vec2 qr = lw_src(uv, mu, -1.0, cov);
		vec2 qb = q * 2.0 - qr;
		c.r = (use_from ? from_mirrored(qr) : to_mirrored(qr)).r;
		c.b = (use_from ? from_mirrored(qb) : to_mirrored(qb)).b;
	}
	return c;
}

vec4 lw_at(vec2 uv, float t) {
	float e = lw_curve(t);
	float wb = lw_wb(t);
	vec4 c = vec4(0.0);
	if (wb < 1.0) {
		c += lw_take(uv, 2.0 * e, true) * (1.0 - wb);
	}
	if (wb > 0.0) {
		c += lw_take(uv, 2.0 * e - 2.0, false) * wb;
	}
	return c;
}

float lw_noise(vec2 uv) {
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
		return lw_at(uv, p);
	}
	float t0 = p - 0.5 * win;
	float t1 = p + 0.5 * win;
	int n = MAX_SAMPLES;
	if (t1 < 0.5 - 0.06 || t0 > 0.5 + 0.06) {
		vec2 a = lw_pos(uv, t0);
		vec2 m = lw_pos(uv, p);
		vec2 b = lw_pos(uv, t1);
		float len_px = (length(m - a) + length(b - m)) * max(frame_px.x, frame_px.y);
		n = clamp(int(ceil(len_px / STEP_PX)), 3, MAX_SAMPLES);
	}
	float j = lw_noise(uv);
	vec4 acc = vec4(0.0);
	for (int i = 0; i < MAX_SAMPLES; i++) {
		if (i >= n) {
			break;
		}
		float t = t0 + (float(i) + j) / float(n) * win;
		acc += lw_at(uv, t);
	}
	return acc / float(n);
}

void fragment() {
	COLOR = transition(UV);
}

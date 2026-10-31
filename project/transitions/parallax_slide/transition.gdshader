shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform int panels : hint_range(1, 6) = 3;
uniform float stagger : hint_range(0.0, 1.0) = 0.3;
uniform float parallax : hint_range(0.0, 1.0) = 0.5;
uniform float push : hint_range(0.0, 1.0) = 0.3;
uniform float dim : hint_range(0.0, 1.0) = 0.4;
uniform float shadow : hint_range(0.0, 1.0) = 0.6;
uniform float blur : hint_range(0.0, 2.0) = 0.5;
uniform int timing = 0;

const int MAX_SAMPLES = 32;
const float STEP_PX = 1.25;

float ps_ease(float t) {
	t = clamp(t, 0.0, 1.0);
	if (timing == 1) {
		return t * t * (3.0 - 2.0 * t);
	} else if (timing == 2) {
		return 1.0 - pow(1.0 - t, 3.0);
	} else if (timing == 3) {
		return t;
	}
	return t < 0.5 ? 16.0 * pow(t, 5.0) : 1.0 - 0.5 * pow(2.0 - 2.0 * t, 5.0);
}

vec2 ps_local(vec2 uv) {
	if (direction == 1) {
		return vec2(1.0 - uv.x, uv.y);
	} else if (direction == 2) {
		return vec2(uv.y, uv.x);
	} else if (direction == 3) {
		return vec2(1.0 - uv.y, uv.x);
	}
	return uv;
}

vec2 ps_uv(vec2 l) {
	if (direction == 1) {
		return vec2(1.0 - l.x, l.y);
	} else if (direction == 2) {
		return vec2(l.y, l.x);
	} else if (direction == 3) {
		return vec2(l.y, 1.0 - l.x);
	}
	return l;
}

float ps_window(float t, float lane) {
	int n = max(panels, 1);
	if (n == 1) {
		return ps_ease(t);
	}
	float st = clamp(stagger, 0.0, 0.9);
	float delay = st * lane / float(n - 1);
	return ps_ease((t - delay) / (1.0 - st));
}

vec4 ps_lane(vec2 uv, float t, float lane) {
	vec2 l = ps_local(uv);
	float w = ps_window(t, lane);
	float edge = 1.0 - w;
	if (l.x >= edge) {
		vec2 src = vec2(l.x - parallax * (1.0 - w), l.y);
		return to_at(ps_uv(src));
	}
	vec2 src = vec2(l.x + push * w, l.y);
	vec4 c = from_at(ps_uv(src));
	float dist = edge - l.x;
	float sh = shadow * (0.5 * exp(-dist / 0.03) + 0.5 * exp(-dist / 0.22)) * smoothstep(0.0, 0.06, w);
	float light = (1.0 - dim * w) * (1.0 - min(sh, 0.92));
	return tr_shade(c, light);
}

float ps_noise(vec2 uv) {
	vec2 p = floor(uv * frame_px);
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec4 ps_blurred(vec2 uv, float p, float lane) {
	float win = blur / (25.0 * max(duration, 0.05));
	win = min(win, 2.0 * min(p, 1.0 - p));
	if (win < 0.0005) {
		return ps_lane(uv, p, lane);
	}
	float t0 = p - 0.5 * win;
	float t1 = p + 0.5 * win;
	float along = direction >= 2 ? frame_px.y : frame_px.x;
	float len_px = abs(ps_window(t1, lane) - ps_window(t0, lane)) * along;
	int n = clamp(int(ceil(len_px / STEP_PX)), 3, MAX_SAMPLES);
	float j = ps_noise(uv);
	vec4 acc = vec4(0.0);
	for (int i = 0; i < MAX_SAMPLES; i++) {
		if (i >= n) {
			break;
		}
		float t = t0 + (float(i) + j) / float(n) * win;
		acc += ps_lane(uv, t, lane);
	}
	return acc / float(n);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	if (p <= 0.0) {
		return texture(from_tex, uv);
	}
	if (p >= 1.0) {
		return texture(to_tex, uv);
	}
	int n = max(panels, 1);
	vec2 l = ps_local(uv);
	float pos = l.y * float(n);
	float lane = clamp(floor(pos), 0.0, float(n - 1));
	vec4 c = ps_blurred(uv, p, lane);
	if (n > 1) {
		float across = direction >= 2 ? frame_px.x : frame_px.y;
		float px_lane = across / float(n);
		float f = pos - lane;
		float d_lo = f * px_lane;
		float d_hi = (1.0 - f) * px_lane;
		if (d_lo < 0.75 && lane > 0.0) {
			c = mix(ps_blurred(uv, p, lane - 1.0), c, 0.5 + d_lo / 1.5);
		} else if (d_hi < 0.75 && lane < float(n - 1)) {
			c = mix(ps_blurred(uv, p, lane + 1.0), c, 0.5 + d_hi / 1.5);
		}
	}
	return c;
}

void fragment() {
	COLOR = transition(UV);
}

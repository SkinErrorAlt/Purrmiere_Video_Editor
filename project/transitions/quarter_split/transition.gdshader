shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int pieces = 0;
uniform int motion = 0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float gap : hint_range(0.0, 80.0) = 0.0;
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform float blur : hint_range(0.0, 2.0) = 0.5;
uniform int curve = 0;

const int MAX_SAMPLES = 32;
const float STEP_PX = 1.5;

float qs_ease(float t) {
	t = clamp(t, 0.0, 1.0);
	if (curve == 1) {
		return t * t * t;
	} else if (curve == 2) {
		return 1.0 - pow(1.0 - t, 3.0);
	} else if (curve == 3) {
		return t;
	}
	return t < 0.5 ? 4.0 * t * t * t : 1.0 - 0.5 * pow(2.0 - 2.0 * t, 3.0);
}

float qs_box(vec2 p, vec2 lo, vec2 hi) {
	vec2 d = max(lo - p, p - hi);
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

vec4 qs_out(vec2 uv, float e, bool pieces_from) {
	vec2 c = clamp(centre, vec2(0.02), vec2(0.98));
	vec2 g = vec2(gap * px_scale) / frame_px * smoothstep(0.0, 0.15, e);
	vec4 piece = vec4(0.0);
	bool hit = false;
	float sd = 1000.0;
	vec2 light_off = vec2(0.012, 0.02) * vec2(1.0 / tr_ratio(), 1.0);
	for (int k = 0; k < 4; k++) {
		vec2 corner = vec2(float(k % 2), float(k / 2));
		vec2 lo = vec2(0.0);
		vec2 hi = vec2(1.0);
		vec2 travel = vec2(0.0);
		if (pieces == 0) {
			lo = vec2(corner.x > 0.5 ? c.x : 0.0, corner.y > 0.5 ? c.y : 0.0);
			hi = vec2(corner.x > 0.5 ? 1.0 : c.x, corner.y > 0.5 ? 1.0 : c.y);
			travel = corner - c;
			travel += sign(travel) * g;
		} else if (pieces == 1) {
			if (k > 1) {
				continue;
			}
			lo = vec2(corner.x > 0.5 ? c.x : 0.0, 0.0);
			hi = vec2(corner.x > 0.5 ? 1.0 : c.x, 1.0);
			travel = vec2(corner.x - c.x, 0.0);
			travel.x += sign(travel.x) * g.x;
		} else {
			if (k % 2 == 1) {
				continue;
			}
			lo = vec2(0.0, corner.y > 0.5 ? c.y : 0.0);
			hi = vec2(1.0, corner.y > 0.5 ? 1.0 : c.y);
			travel = vec2(0.0, corner.y - c.y);
			travel.y += sign(travel.y) * g.y;
		}
		vec2 off = travel * e;
		vec2 src = uv - off;
		if (!hit && src.x >= lo.x && src.x <= hi.x && src.y >= lo.y && src.y <= hi.y) {
			hit = true;
			piece = pieces_from ? texture(from_tex, src) : texture(to_tex, src);
		}
		vec2 slo = max(lo + off, vec2(0.0));
		vec2 shi = min(hi + off, vec2(1.0));
		sd = min(sd, qs_box((uv - light_off * e) * vec2(tr_ratio(), 1.0), slo * vec2(tr_ratio(), 1.0), shi * vec2(tr_ratio(), 1.0)));
	}
	vec4 under = pieces_from ? texture(to_tex, uv) : texture(from_tex, uv);
	float fade = 1.0 - smoothstep(0.8, 1.0, e);
	float sh = shadow * 0.6 * (1.0 - smoothstep(-0.01, 0.06, sd)) * fade * smoothstep(0.0, 0.05, e);
	under = tr_shade(under, 1.0 - sh);
	return hit ? piece : under;
}

vec4 qs_at(vec2 uv, float t) {
	if (motion == 1) {
		return qs_out(uv, qs_ease(1.0 - t), false);
	}
	return qs_out(uv, qs_ease(t), true);
}

float qs_noise(vec2 uv) {
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
		return qs_at(uv, p);
	}
	float t0 = p - 0.5 * win;
	float t1 = p + 0.5 * win;
	float len_px = abs(qs_ease(t1) - qs_ease(t0)) * length(frame_px);
	int n = clamp(int(ceil(len_px / STEP_PX)), 3, MAX_SAMPLES);
	float j = qs_noise(uv);
	vec4 acc = vec4(0.0);
	for (int i = 0; i < MAX_SAMPLES; i++) {
		if (i >= n) {
			break;
		}
		float t = t0 + (float(i) + j) / float(n) * win;
		acc += qs_at(uv, t);
	}
	return acc / float(n);
}

void fragment() {
	COLOR = transition(UV);
}

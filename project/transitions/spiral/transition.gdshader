shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int turns : hint_range(1, 12) = 4;
uniform int shape = 0;
uniform int direction = 0;
uniform int rotation = 0;
uniform float softness : hint_range(0.0, 0.2) = 0.01;
uniform int curve = 0;

float w_sweep(float v, float p, float soft) {
	float s = max(soft, 0.0001);
	float e = mix(-s, 1.0, p);
	return 1.0 - smoothstep(e, e + s, v);
}

float clock_angle(vec2 w) {
	if (dot(w, w) < 0.000000000001) {
		w = vec2(0.0, 0.000001);
	}
	return atan(w.x, w.y);
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	vec2 c = vec2(uv.x - 0.5, 0.5 - uv.y);
	float d;
	float a;
	if (shape == 1) {
		vec2 w = tr_world(uv);
		d = length(w) / (0.5 * length(vec2(tr_ratio(), 1.0)));
		a = clock_angle(w);
	} else {
		d = max(abs(c.x), abs(c.y)) * 2.0;
		a = 0.0;
	}
	d = clamp(d, 0.0, 1.0);
	float turn = 2.0 * TR_PI;
	float ang;
	if (shape == 1) {
		ang = rotation == 1 ? fract((-a + TR_PI * 0.25) / turn) : fract((a + TR_PI * 0.25) / turn);
	} else {
		vec2 q = vec2(rotation == 1 ? -c.x : c.x, -c.y) / max(max(abs(c.x), abs(c.y)), 0.000001);
		if (abs(q.y) >= abs(q.x)) {
			ang = q.y < 0.0 ? (q.x + 1.0) * 0.125 : 0.5 + (1.0 - q.x) * 0.125;
		} else {
			ang = q.x > 0.0 ? 0.25 + (q.y + 1.0) * 0.125 : 0.75 + (1.0 - q.y) * 0.125;
		}
		ang = fract(ang);
	}
	float n = float(max(turns, 1));
	float w2 = (1.0 - d) * n - (shape == 1 ? ang : floor(ang * 4.0) * 0.25);
	float o = max(floor(w2), 0.0) + ang;
	float v = clamp(o / (n + (shape == 1 ? 0.0 : 0.25)), 0.0, 1.0);
	if (direction == 1) {
		v = 1.0 - v;
	}
	float ring_px = max(turn * max(d, 0.05) * 0.5 * frame_px.y, 1.0);
	float px = min(1.0 / (n * ring_px), 0.05);
	float m = w_sweep(v, p, max(softness, px));
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}

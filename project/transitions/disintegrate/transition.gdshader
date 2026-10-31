shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float grain : hint_range(2.0, 24.0) = 5.0;
uniform float drift_angle : hint_range(-180.0, 180.0) = 30.0;
uniform float drift : hint_range(0.0, 2.0) = 0.7;
uniform float turbulence : hint_range(0.0, 1.0) = 0.5;
uniform float spread : hint_range(0.0, 1.0) = 0.6;

vec4 lay(vec4 top, float cov, vec4 under, float leak) {
	return top * cov + under * (1.0 - cov + cov * (1.0 - top.a) * leak);
}

vec4 lay_w(vec4 weighted, float cov, vec4 under, float leak) {
	return weighted + under * (1.0 - cov + max(cov - weighted.a, 0.0) * leak);
}

float life(vec2 h, float t, int layer) {
	vec2 half_frame = vec2(tr_ratio() * 0.5, 0.5);
	vec2 n01 = (h + half_frame) / (2.0 * half_frame);
	float along = n01.x;
	if (direction == 1) {
		along = 1.0 - n01.x;
	} else if (direction == 2) {
		along = 1.0 - n01.y;
	} else if (direction == 3) {
		along = n01.y;
	}
	float n = tr_noise(h * 7.0 + vec2(3.1, 8.7));
	float sweep = spread * 0.75;
	float delay = sweep * (0.8 * along + 0.2 * n) + float(layer) * 0.05;
	float span = 1.0 - sweep - 0.1;
	return clamp((t - delay) / span, 0.0, 1.0);
}

vec2 motion(vec2 h, float s) {
	float a = radians(drift_angle);
	vec2 v = vec2(cos(a), sin(a)) * drift * pow(s, 1.5);
	vec2 turb = vec2(tr_noise(h * 3.0 + vec2(s * 2.0, 0.0)), tr_noise(h * 3.0 + vec2(9.0, -s * 2.0))) - 0.5;
	return v + turb * turbulence * 0.35 * s;
}

vec4 transition(vec2 uv) {
	float p = progress;
	float leak = clamp(min(p, 1.0 - p) * 8.0, 0.0, 1.0);
	vec4 under = to_at(uv);
	if (p <= 0.0) {
		return lay(from_at(uv), 1.0, under, leak);
	}
	vec2 w = tr_world(uv);
	float ts = max(grain * px_scale, 1.0) / max(frame_px.y, 1.0);
	vec2 half_frame = vec2(tr_ratio() * 0.5, 0.5);
	vec4 top_c = vec4(0.0);
	float top_v = 0.0;
	float top_s = -1.0;
	vec4 und_c = vec4(0.0);
	float und_v = 0.0;
	float und_s = -1.0;
	float cov = 0.0;
	for (int layer = 0; layer < 3; layer++) {
		vec2 h = w;
		for (int i = 0; i < 3; i++) {
			vec2 cc = (floor(h / ts) + 0.5) * ts;
			float s = life(cc, p, layer);
			h = w - motion(cc, s);
		}
		vec2 base = floor(h / ts);
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				vec2 cell = base + vec2(float(dx), float(dy));
				if (int(floor(tr_hash(cell + vec2(1.0, 7.0)) * 3.0)) != layer) {
					continue;
				}
				vec2 cc = (cell + 0.5) * ts;
				float s = life(cc, p, layer);
				if (s >= 0.999) {
					continue;
				}
				vec2 pos = cc + motion(cc, s);
				float scale = 1.0 - 0.6 * s;
				vec2 local = (w - pos) / scale;
				if (abs(local.x) > ts * 0.5 || abs(local.y) > ts * 0.5) {
					continue;
				}
				vec2 home = cc + local;
				vec2 in_frame = half_frame - abs(home);
				if (in_frame.x < 0.0 || in_frame.y < 0.0) {
					continue;
				}
				vec4 sc = from_at(tr_frame_uv(home));
				vec4 pc = tr_shade(sc, 1.0 + 0.25 * smoothstep(0.0, 0.3, s));
				float cv = 1.0 - smoothstep(0.35, 1.0, s);
				if (s > top_s) {
					und_c = top_c;
					und_v = top_v;
					und_s = top_s;
					top_c = pc;
					top_v = cv;
					top_s = s;
				} else if (s > und_s) {
					und_c = pc;
					und_v = cv;
					und_s = s;
				}
			}
		}
	}
	cov = top_v + und_v * (1.0 - top_v);
	return lay_w(top_c * top_v + und_c * und_v * (1.0 - top_v), cov, under, leak);
}

void fragment() {
	COLOR = transition(UV);
}

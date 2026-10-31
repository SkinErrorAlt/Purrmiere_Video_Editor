shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int pieces : hint_range(8, 200) = 60;
uniform float piece_size : hint_range(0.2, 1.0) = 0.7;
uniform float burst : hint_range(0.0, 3.0) = 1.0;
uniform float gravity : hint_range(0.0, 3.0) = 1.0;
uniform float drift : hint_range(-2.0, 2.0) = 0.0;
uniform float flutter : hint_range(0.0, 1.0) = 0.7;
uniform float spin : hint_range(0.0, 2.0) = 0.6;
uniform float stagger : hint_range(0.0, 1.0) = 0.5;
uniform vec2 centre = vec2(0.5, 0.5);

float cell_size() {
	return tr_ratio() / float(clamp(pieces, 8, 200));
}

float reach() {
	return length(abs(tr_world(centre)) + vec2(tr_ratio() * 0.5, 0.5));
}

float life(vec2 h, float t, int layer) {
	vec2 c = tr_world(centre);
	float n = tr_noise(h * 2.3 + vec2(float(layer) * 7.1, 3.7));
	float spread = stagger * 0.45;
	float delay = spread * (0.45 * clamp(length(h - c) / reach(), 0.0, 1.0) + 0.55 * n) + float(layer) * stagger * 0.09;
	float span = mix(1.0 - spread - stagger * 0.18, 1.0 - delay, 0.85);
	return clamp((t - delay) / max(span, 0.05), 0.0, 1.0);
}

float spread_of(int layer) {
	return burst * (0.7 + 0.3 * float(layer));
}

float expand(float s) {
	return s * (1.0 - 0.5 * s);
}

vec2 fall_line(int layer) {
	float margin = cell_size() * 2.2 + 3.0 / max(frame_px.y, 1.0);
	float k = (1.0 + 0.5 * 0.35 * spread_of(layer)) * max(1.0, 0.55 + 0.45 * gravity);
	return vec2(0.5 * k + margin, k);
}

float fall_curve(float s) {
	float g = clamp(gravity / 2.0, 0.0, 1.0);
	float q = mix(4.5, 2.2, g);
	float lw = mix(0.32, 0.58, g);
	return lw * s + (1.0 - lw) * pow(s, q);
}

float drift_x(float s, int layer) {
	float sway = flutter * 0.07 * sin(TR_PI * (3.0 * s + 0.7 * float(layer))) * s;
	return sway + drift * s * s;
}

vec2 piece_pos(vec2 h, float s, int layer) {
	vec2 c = tr_world(centre);
	float e = 1.0 + spread_of(layer) * expand(s);
	vec2 fl = fall_line(layer);
	float f = fall_curve(s);
	float ey = 1.0 + 0.35 * spread_of(layer) * expand(s);
	return vec2(c.x + (h.x - c.x) * e + drift_x(s, layer), c.y + (h.y - c.y) * ey - (fl.x + fl.y * h.y) * f);
}

vec2 home_at(vec2 w, float s, int layer) {
	vec2 c = tr_world(centre);
	float e = 1.0 + spread_of(layer) * expand(s);
	vec2 fl = fall_line(layer);
	float f = fall_curve(s);
	float hx = c.x + (w.x - c.x - drift_x(s, layer)) / e;
	float ey = 1.0 + 0.35 * spread_of(layer) * expand(s);
	float den = ey - fl.y * f;
	if (abs(den) < 0.001) {
		return vec2(hx, 100.0);
	}
	float hy = (w.y - c.y + c.y * ey + fl.x * f) / den;
	return vec2(hx, hy);
}

vec2 site(vec2 cell, float ts) {
	return (cell + 0.5 + (tr_hash2(cell + vec2(71.0, 19.0)) - 0.5) * 0.8) * ts;
}

vec4 transition(vec2 uv) {
	float p = progress;
	vec4 under = to_at(uv);
	if (p <= 0.0) {
		return from_at(uv);
	}
	vec2 w = tr_world(uv);
	vec2 c = tr_world(centre);
	float ts = cell_size();
	float px_world = 1.0 / max(frame_px.y, 1.0);
	vec2 half_frame = vec2(tr_ratio() * 0.5, 0.5);
	vec4 top_c = vec4(0.0);
	float top_v = 0.0;
	float top_s = -1.0;
	vec4 und_c = vec4(0.0);
	float und_v = 0.0;
	float und_s = -1.0;
	for (int layer = 0; layer < 3; layer++) {
		float lo = 0.0;
		float hi = 1.0;
		for (int i = 0; i < 7; i++) {
			float mid = (lo + hi) * 0.5;
			if (life(home_at(w, mid, layer), p, layer) > mid) {
				lo = mid;
			} else {
				hi = mid;
			}
		}
		vec2 hl = home_at(w, (lo + hi) * 0.5, layer) / ts;
		vec2 base = floor(hl);
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				vec2 cell = base + vec2(float(dx), float(dy));
				if (int(floor(tr_hash(cell + vec2(5.0, 3.0)) * 3.0)) != layer) {
					continue;
				}
				vec2 cc = site(cell, ts);
				vec2 in_cell = half_frame - abs(cc);
				if (in_cell.x < -ts || in_cell.y < -ts) {
					continue;
				}
				float s = life(cc, p, layer);
				vec2 rnd = tr_hash2(cell + vec2(17.0, 29.0));
				vec2 jit = tr_hash2(cell + vec2(41.0, 13.0)) - 0.5;
				float kick = smoothstep(0.0, 0.1, s);
				vec2 pos = piece_pos(cc, s, layer) + jit * ts * 0.5 * kick;
				float turn = (rnd.x - 0.5) * 2.0 * spin * 2.0 * TR_PI * s + (jit.x - jit.y) * 2.0 * kick;
				float ph = s * flutter * 3.0 * TR_PI * (0.5 + rnd.y);
				float fx = cos(ph);
				float sx = max(abs(fx), 0.04);
				float scale = mix(1.0, piece_size * mix(0.55, 1.2, tr_hash(cell + vec2(23.0, 7.0))), smoothstep(0.0, 0.08, s)) * (1.0 + 0.4 * s);
				vec2 local = tr_rotate(w - pos, -turn) / scale;
				local.x /= sx;
				vec2 home = cc + vec2(fx < 0.0 ? -local.x : local.x, local.y);
				vec2 d0 = home - cc;
				float own = dot(d0, d0);
				if (own > ts * ts * 2.5) {
					continue;
				}
				float edge = 1e9;
				for (int ny = -1; ny <= 1; ny++) {
					for (int nx = -1; nx <= 1; nx++) {
						if (nx == 0 && ny == 0) {
							continue;
						}
						vec2 sn = site(cell + vec2(float(nx), float(ny)), ts);
						vec2 dn = home - sn;
						edge = min(edge, (dot(dn, dn) - own) / (2.0 * length(sn - cc)));
					}
				}
				if (tr_hash(cell + vec2(61.0, 3.0)) < 0.3) {
					float rc = mix(2.0, 0.42, smoothstep(0.0, 0.12, s)) * ts;
					edge = min(edge, rc - sqrt(own));
				}
				vec2 in_frame = half_frame - abs(home);
				edge = min(edge, min(in_frame.x, in_frame.y)) * scale * mix(sx, 1.0, 0.5);
				float aa = smoothstep(0.0, 0.1, s) * px_world;
				float cv = aa > 0.0 ? clamp(edge / aa + 0.5, 0.0, 1.0) : (edge >= 0.0 ? 1.0 : 0.0);
				if (cv <= 0.0) {
					continue;
				}
				float light = mix(0.55, 1.0, abs(fx)) * (fx < 0.0 ? 0.8 : 1.0);
				vec4 pc = tr_shade(from_at(tr_frame_uv(home)), light);
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
	float cov = top_v + und_v * (1.0 - top_v);
	vec4 weighted = top_c * top_v + und_c * und_v * (1.0 - top_v);
	float leak = clamp(min(p, 1.0 - p) * 8.0, 0.0, 1.0);
	return weighted + under * (1.0 - cov + max(cov - weighted.a, 0.0) * leak);
}

void fragment() {
	COLOR = transition(UV);
}

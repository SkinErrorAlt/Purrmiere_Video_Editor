shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int shape = 0;
uniform float width : hint_range(0.05, 0.8) = 0.3;
uniform int ribs : hint_range(2, 40) = 10;
uniform float refraction : hint_range(0.0, 1.0) = 0.5;
uniform float dispersion : hint_range(0.0, 1.0) = 0.25;
uniform float frost : hint_range(0.0, 1.0) = 0.0;
uniform float highlight : hint_range(0.0, 1.0) = 0.6;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform int curve = 1;

float rw_trace(float u, float ior) {
	vec2 pt = vec2(u, sqrt(max(1.0 - u * u, 0.0)));
	vec2 t1 = refract(vec2(0.0, -1.0), pt, 1.0 / ior);
	float t = -2.0 * dot(pt, t1);
	vec2 ex = pt + t * t1;
	vec2 t2 = refract(t1, -normalize(ex), ior);
	if (dot(t2, t2) < 0.0001 || t2.y > -0.0001) {
		return 1000.0;
	}
	float zp = -3.0;
	return ex.x + t2.x * ((zp - ex.y) / t2.y);
}

float rw_rib(float u, float ior) {
	float rc = 1.6;
	float h = sqrt(rc * rc - u * u) - sqrt(rc * rc - 1.0);
	vec2 nrm = vec2(u, sqrt(rc * rc - u * u)) / rc;
	vec2 t1 = refract(vec2(0.0, -1.0), nrm, 1.0 / ior);
	if (t1.y > -0.0001) {
		return u;
	}
	float t = (h + 1.0) / -t1.y;
	float px = u + t1.x * t;
	vec2 t2 = refract(t1, vec2(0.0, 1.0), ior);
	if (t2.y > -0.0001) {
		return px;
	}
	return px + t2.x / -t2.y * 5.0;
}

vec4 rw_pick(vec2 w, bool use_to) {
	vec2 q = tr_frame_uv(w);
	return use_to ? to_mirrored(q) : from_mirrored(q);
}

vec4 rw_bubble(vec2 uv, vec2 w, vec2 wc, float p) {
	vec2 hr = vec2(tr_ratio() * 0.5, 0.5);
	float far = length(max(abs(wc - hr), abs(wc + hr)));
	float px = 1.0 / frame_px.y;
	float bev = 0.18;
	float rb = mix(-2.0 * px, far / (1.0 - bev) + 0.03, p);
	vec2 dv = w - wc;
	float r = length(dv);
	if (r >= rb + 0.5 * px) {
		return from_at(uv);
	}
	float band = bev * max(rb, 0.0);
	float t = clamp((r - (rb - band)) / max(band, 0.00001), 0.0, 1.0);
	if (t <= 0.0) {
		return to_at(uv);
	}
	vec2 dir = r > 0.00001 ? dv / r : vec2(1.0, 0.0);
	float slope = t * t / sqrt(max(1.0 - 0.92 * t * t, 0.08));
	float ior = 1.0 + 0.8 * refraction;
	float disp = dispersion * 0.05 * refraction * (1.0 - t * t);
	vec3 col = vec3(0.0);
	float alpha = 0.0;
	for (int c = 0; c < 3; c++) {
		float k = (ior + (float(c) - 1.0) * disp - 1.0) / 0.4;
		float rs = max(r - slope * k * band * 0.9, 0.0);
		vec4 acc = vec4(0.0);
		for (int j = 0; j < 3; j++) {
			float o = (float(j) - 1.0) * slope * k * px * 1.5;
			acc += to_mirrored(tr_frame_uv(wc + dir * max(rs + o, 0.0)));
		}
		acc /= 3.0;
		col[c] = acc[c];
		alpha += acc.a / 3.0;
	}
	col *= 1.0 - 0.18 * t * t;
	float edge_px = (rb - r) * frame_px.y;
	float rim = exp(-pow(edge_px / 1.6, 2.0));
	float ang = dot(dir, normalize(vec2(-0.6, 0.8)));
	float arc = exp(-pow((t - 0.55) / 0.12, 2.0)) * smoothstep(0.4, 0.95, ang) * 0.45;
	col += vec3(highlight * (rim * 0.9 + arc)) * alpha;
	vec4 glass = vec4(min(col, vec3(alpha)), alpha);
	float cov = clamp((rb - r) / px + 0.5, 0.0, 1.0);
	return mix(from_at(uv), glass, cov);
}

vec4 transition(vec2 uv) {
	float p = tr_ease(progress, curve == 1 ? 3 : 0);
	vec2 w = tr_world(uv);
	float ratio = tr_ratio();
	float a = radians(angle);
	vec2 n = vec2(cos(a), sin(a));
	float ext = abs(n.x) * ratio * 0.5 + abs(n.y) * 0.5;
	float R = width * 0.5;
	vec2 wc = tr_world(centre);
	float d;
	float rr;
	vec2 perp;
	float front;
	bool behind;
	if (shape == 1) {
		return rw_bubble(uv, w, wc, p);
	}
	if (shape == 2) {
		float pane = width * 2.0;
		front = mix(-ext - pane * 0.6, ext + pane * 0.6, p);
		float s = dot(w, n);
		float rel = s - (front - pane * 0.5);
		float ribw = pane / float(ribs);
		float k = floor(rel / ribw);
		perp = n;
		rr = ribw * 0.5;
		d = rel - (k + 0.5) * ribw;
		behind = rel < 0.0 || (rel < pane && k + 0.5 < float(ribs) * 0.5);
		if (rel < 0.0 || rel >= pane) {
			rr = 0.0;
			behind = rel < 0.0;
		}
	} else {
		front = mix(-ext - R * 1.05, ext + R * 1.05, p);
		d = dot(w, n) - front;
		perp = n;
		rr = R;
		behind = d < 0.0;
	}
	float px = 1.0 / frame_px.y;
	if (rr <= 0.0 || abs(d) >= rr + px) {
		return behind ? to_at(uv) : from_at(uv);
	}
	float u = clamp(d / rr, -0.9999, 0.9999);
	float ior = 1.0 + 0.8 * refraction;
	float eps = px / rr;
	float xa = shape == 2 ? rw_rib(u - eps, ior) : rw_trace(u - eps, ior);
	float xb = shape == 2 ? rw_rib(u + eps, ior) : rw_trace(u + eps, ior);
	float spp = (xa > 999.0 || xb > 999.0) ? 4.0 : abs(xb - xa) / (2.0 * eps);
	float squeeze = max(spp - 1.0, 0.0);
	float disp = dispersion * 0.06 * refraction / (1.0 + squeeze * squeeze * 0.8);
	float foot = min(spp * px, rr * 0.6);
	vec2 base = w - perp * d;
	vec3 col = vec3(0.0);
	float alpha = 0.0;
	float dark = 0.0;
	int taps = (frost > 0.0 || spp > 1.5) ? 4 : 1;
	for (int c = 0; c < 3; c++) {
		float x = shape == 2 ? rw_rib(u, ior + (float(c) - 1.0) * disp) : rw_trace(u, ior + (float(c) - 1.0) * disp);
		if (x > 999.0) {
			dark += 1.0;
			x = u;
		}
		vec4 acc = vec4(0.0);
		for (int k = 0; k < 4; k++) {
			if (k >= taps) {
				break;
			}
			float ang = float(k) * 2.39996 + 0.7;
			vec2 j = vec2(cos(ang), sin(ang)) * sqrt((float(k) + 0.5) / 4.0) * frost * rr * 0.35;
			j += perp * (taps > 1 ? (float(k) / 3.0 - 0.5) * foot : 0.0);
			vec2 sw = base + perp * (x * rr) + j;
			bool to_side = shape == 2 ? behind : x * rr < 0.0;
			acc += rw_pick(sw, to_side);
		}
		acc /= float(taps);
		col[c] = acc[c];
		alpha += acc.a / 3.0;
	}
	float edge_dark = 1.0 - 0.5 * (dark / 3.0);
	col *= edge_dark * (0.97 - 0.25 * pow(abs(u), 6.0));
	float edge_px = (1.0 - abs(u)) * rr * frame_px.y;
	float line = exp(-pow(edge_px / max(2.0 * px_scale * frame_px.y / frame_px.y, 0.6), 2.0));
	float sheen = exp(-pow((u + 0.5) / 0.14, 2.0)) * 0.35 + exp(-pow((u - 0.72) / 0.06, 2.0)) * 0.12;
	float spec = highlight * (line * 0.9 + sheen) * smoothstep(0.0, 0.02, refraction + 0.02);
	col += vec3(spec) * max(alpha, 0.0);
	vec4 glass = vec4(min(col, vec3(alpha)), alpha);
	float cov = clamp((rr - abs(d)) / px + 0.5, 0.0, 1.0);
	vec4 outside = behind ? to_at(uv) : from_at(uv);
	return mix(outside, glass, cov);
}

void fragment() {
	COLOR = transition(UV);
}

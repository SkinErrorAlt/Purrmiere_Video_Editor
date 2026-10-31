shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform float fold_share : hint_range(0.2, 0.8) = 0.45;
uniform float size : hint_range(0.05, 1.5) = 0.35;
uniform float speed : hint_range(0.25, 4.0) = 1.0;
uniform int path = 5;
uniform vec2 path_start = vec2(0.5, 0.55);
uniform vec2 path_a = vec2(0.64, 0.64);
uniform vec2 path_b = vec2(0.8, 0.48);
uniform vec2 path_c = vec2(0.88, 0.24);
uniform vec2 path_end = vec2(1.12, -0.08);
uniform float recede : hint_range(0.0, 8.0) = 2.5;
uniform float bank : hint_range(0.0, 1.0) = 0.6;
uniform float flap_amount : hint_range(0.0, 60.0) = 45.0;
uniform float flap_speed : hint_range(0.0, 8.0) = 2.5;
uniform int flap_ease = 0;
uniform bool trail = true;
uniform vec4 trail_colour : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform float trail_width : hint_range(0.002, 0.08) = 0.016;
uniform float trail_length : hint_range(0.1, 3.0) = 0.9;
uniform float trail_fade : hint_range(0.0, 1.0) = 0.5;
uniform float back_fade : hint_range(0.0, 1.0) = 0.85;
uniform vec4 paper : source_color = vec4(0.94, 0.94, 0.92, 1.0);
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec3 cam_eye() {
	return vec3(0.0, 0.0, -tr_camera_distance(lens));
}

vec3 cam_dir(vec2 uv) {
	return normalize(vec3(tr_world(uv), 0.0) - cam_eye());
}

vec4 plane_cast(vec3 ro, vec3 rd, mat3 r, vec3 pos) {
	vec3 o = transpose(r) * (ro - pos);
	vec3 d = transpose(r) * rd;
	float t = abs(d.z) < 0.000001 ? -1.0 : -o.z / d.z;
	vec3 h = o + d * max(t, 0.0);
	return vec4(h.x / tr_ratio() + 0.5, 0.5 - h.y, d.z > 0.0 ? 1.0 : -1.0, t);
}

vec3 pivot_place(mat3 r, vec3 pivot, vec3 offset) {
	return pivot - r * pivot + offset;
}

float box_cover(vec4 hit, vec4 box) {
	vec2 fw = max(fwidth(hit.xy), vec2(0.00001));
	vec2 lo = (hit.xy - box.xy) / fw;
	vec2 hi = (box.zw - hit.xy) / fw;
	float c = clamp(min(min(lo.x, lo.y), min(hi.x, hi.y)) + 0.5, 0.0, 1.0);
	return hit.w > 0.0 ? c : 0.0;
}

float edge_cover(vec4 hit) {
	return box_cover(hit, vec4(0.0, 0.0, 1.0, 1.0));
}

float face_light(mat3 r) {
	return mix(1.0, abs((r * vec3(0.0, 0.0, -1.0)).z), shading);
}

vec4 bg_fill() {
	float w = clamp(min(progress, 1.0 - progress) * 25.0, 0.0, 1.0);
	return vec4(background.rgb * background.a, background.a) * w;
}

mat3 axis_rot(vec3 k, float a) {
	float c = cos(a);
	float s = sin(a);
	mat3 kx = mat3(vec3(0.0, k.z, -k.y), vec3(-k.z, 0.0, k.x), vec3(k.y, -k.x, 0.0));
	mat3 kk = mat3(k * k.x, k * k.y, k * k.z);
	return mat3(c) + kx * s + kk * (1.0 - c);
}

void about(inout mat3 r, inout vec3 t, mat3 q, vec3 c) {
	r = q * r;
	t = q * (t - c) + c;
}

vec4 mat_quat(mat3 m) {
	float tr = m[0][0] + m[1][1] + m[2][2];
	vec4 q;
	if (tr > 0.0) {
		float s = sqrt(tr + 1.0) * 2.0;
		q = vec4((m[1][2] - m[2][1]) / s, (m[2][0] - m[0][2]) / s, (m[0][1] - m[1][0]) / s, 0.25 * s);
	} else if (m[0][0] > m[1][1] && m[0][0] > m[2][2]) {
		float s = sqrt(1.0 + m[0][0] - m[1][1] - m[2][2]) * 2.0;
		q = vec4(0.25 * s, (m[1][0] + m[0][1]) / s, (m[2][0] + m[0][2]) / s, (m[1][2] - m[2][1]) / s);
	} else if (m[1][1] > m[2][2]) {
		float s = sqrt(1.0 + m[1][1] - m[0][0] - m[2][2]) * 2.0;
		q = vec4((m[1][0] + m[0][1]) / s, 0.25 * s, (m[2][1] + m[1][2]) / s, (m[2][0] - m[0][2]) / s);
	} else {
		float s = sqrt(1.0 + m[2][2] - m[0][0] - m[1][1]) * 2.0;
		q = vec4((m[2][0] + m[0][2]) / s, (m[2][1] + m[1][2]) / s, 0.25 * s, (m[0][1] - m[1][0]) / s);
	}
	return normalize(q);
}

mat3 quat_mat(vec4 q) {
	float x = q.x;
	float y = q.y;
	float z = q.z;
	float w = q.w;
	return mat3(
		vec3(1.0 - 2.0 * (y * y + z * z), 2.0 * (x * y + z * w), 2.0 * (x * z - y * w)),
		vec3(2.0 * (x * y - z * w), 1.0 - 2.0 * (x * x + z * z), 2.0 * (y * z + x * w)),
		vec3(2.0 * (x * z + y * w), 2.0 * (y * z - x * w), 1.0 - 2.0 * (x * x + y * y)));
}

vec2 catmull(vec2 a, vec2 b, vec2 c, vec2 d, float t) {
	return 0.5 * (2.0 * b + (c - a) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (3.0 * b - a - 3.0 * c + d) * t * t * t);
}

vec3 path_raw(float u) {
	u = clamp(u, 0.0, 1.0);
	vec2 st = path == 5 ? path_start : vec2(0.5, 0.55);
	float ar = tr_ratio();
	if (path == 0) {
		return vec3(st + vec2(0.12 * u, -0.5 * u + 0.12 * u * (1.0 - u)), recede * 1.6 * u * u);
	} else if (path == 1 || path == 2) {
		float sx = path == 1 ? -1.0 : 1.0;
		return vec3(st + vec2(sx * 0.72 * u, 0.24 * sin(TR_PI * u) - 0.62 * u * u), recede * 0.5 * u * u);
	} else if (path == 3) {
		float th = 2.0 * TR_PI * smoothstep(0.08, 0.8, u);
		float rr = 0.2;
		float out_t = pow(max(u - 0.78, 0.0) / 0.22, 1.5);
		vec2 w = vec2(rr * sin(th) + 0.12 * u, rr * (1.0 - cos(th)) + 0.25 * out_t);
		return vec3(st + vec2(w.x / ar - 0.18 + 1.05 * out_t, -w.y), 0.3 + recede * 0.25 * smoothstep(0.75, 1.0, u));
	} else if (path == 4) {
		float th = 4.0 * TR_PI * u;
		float rr = 0.14 * (1.0 - 0.3 * u);
		vec2 w = vec2(rr * sin(th), rr * (1.0 - cos(th)) + 0.18 * u);
		return vec3(st + vec2(w.x / ar, -w.y), recede * 1.8 * u);
	}
	vec2 pts[5] = vec2[5](path_start, path_a, path_b, path_c, path_end);
	float sg = u * 4.0;
	int k = int(min(floor(sg), 3.0));
	float f = sg - float(k);
	vec2 p0 = k == 0 ? 2.0 * pts[0] - pts[1] : pts[max(k - 1, 0)];
	vec2 p3 = k == 3 ? 2.0 * pts[4] - pts[3] : pts[min(k + 2, 4)];
	return vec3(catmull(p0, pts[k], pts[k + 1], p3, f), recede * u * u);
}

vec3 path_uvz(float u) {
	if (u < 0.0) {
		return path_raw(0.0) + (path_raw(0.002) - path_raw(0.0)) / 0.002 * u;
	} else if (u > 1.0) {
		return path_raw(1.0) + (path_raw(1.0) - path_raw(0.998)) / 0.002 * (u - 1.0);
	}
	return path_raw(u);
}

vec3 path_world(float u) {
	vec3 p = path_uvz(u);
	float cd = tr_camera_distance(lens);
	return vec3(tr_world(p.xy) * (cd + p.z) / cd, p.z);
}

mat3 flight_frame(float u) {
	float h = 0.01;
	vec3 pa = path_world(u - h);
	vec3 pb = path_world(u);
	vec3 pc = path_world(u + h);
	vec3 dlt = pc - pa;
	float dl = dot(dlt, dlt);
	vec3 f = dl > 0.0000001 ? dlt / sqrt(dl) : vec3(1.0, 0.0, 0.0);
	vec3 acc = pc - 2.0 * pb + pa;
	vec3 kap = dl > 0.0000001 ? 4.0 * (acc - f * dot(acc, f)) / dl : vec3(0.0);
	vec3 upr = vec3(0.0, 1.0, -1.1) + kap * bank * 0.45;
	vec3 perp = upr - f * dot(upr, f);
	if (dot(perp, perp) < 0.000001) {
		vec3 alt = vec3(0.0, 0.0, -1.0);
		perp = alt - f * dot(alt, f);
	}
	if (dot(perp, perp) < 0.000001) {
		perp = vec3(1.0, 0.0, 0.0) - f * f.x;
	}
	vec3 upv = normalize(perp);
	return mat3(f, cross(upv, f), upv);
}

float flight_u(float t) {
	float t0 = fold_share * 0.72;
	float tau = clamp((t - t0) / (1.0 - t0), 0.0, 1.0);
	float x = tau * speed / 0.85;
	return x * (0.6 + 0.4 * x);
}

float flap_wave(float ph) {
	float w = sin(ph);
	if (flap_ease == 1) {
		return sign(w) * pow(abs(w), 0.45);
	} else if (flap_ease == 2) {
		return w * smoothstep(0.15, 0.6, 0.5 + 0.5 * sin(ph * 0.25 - 1.2));
	}
	return w;
}

float dist_seg(vec2 p, vec2 a, vec2 b, out float along) {
	vec2 ab = b - a;
	float l2 = dot(ab, ab);
	along = l2 > 0.0 ? clamp(dot(p - a, ab) / l2, 0.0, 1.0) : 0.0;
	return length(p - a - ab * along);
}

vec4 contrail(vec2 uv, float t) {
	if (!trail || t <= fold_share) {
		return vec4(0.0);
	}
	float cd = tr_camera_distance(lens);
	vec2 s = tr_world(uv);
	float span = trail_length / max(duration, 0.001);
	float best = 0.0;
	vec3 prev = path_world(flight_u(t));
	float prev_age = 0.0;
	for (int i = 1; i <= 64; i++) {
		float age = float(i) / 64.0;
		float ti = t - span * age;
		if (ti < fold_share - span / 64.0) {
			break;
		}
		vec3 cur = path_world(flight_u(max(ti, fold_share)));
		vec2 sa = prev.xy * cd / max(cd + prev.z, 0.01);
		vec2 sb = cur.xy * cd / max(cd + cur.z, 0.01);
		float along;
		float dd = dist_seg(s, sa, sb, along);
		float ag = mix(prev_age, age, along);
		float zz = mix(prev.z, cur.z, along);
		float w = trail_width * cd / max(cd + zz, 0.01) * (1.0 + 1.6 * ag);
		float ta = exp(-2.0 * (dd / w) * (dd / w)) * pow(max(1.0 - ag, 0.0), 1.0 + 3.0 * trail_fade);
		best = max(best, ta);
		prev = cur;
		prev_age = age;
	}
	float env = clamp((t - fold_share) * max(duration, 0.001) / 0.15, 0.0, 1.0);
	float a = best * env * trail_colour.a;
	return vec4(trail_colour.rgb * a, a);
}

vec4 plane_sample(vec2 uv, mat3 g, vec3 pos, float sc, float t1, float beta, float gam, float tv, out float cover) {
	float a = tr_ratio() * 0.5;
	float wl = 0.14;
	vec3 ro = cam_eye();
	vec3 rd = cam_dir(uv);
	vec3 light_dir = normalize(vec3(-0.3, 0.7, -0.6));
	vec4 best = vec4(0.0);
	float bd = 1e9;
	vec4 second = vec4(0.0);
	float bd2 = 1e9;
	float best_cov = 0.0;
	float second_cov = 0.0;
	vec4 third = vec4(0.0);
	float bd3 = 1e9;
	float third_cov = 0.0;
	float hs = 0.022;
	mat3 hinge_c_top = axis_rot(normalize(vec3(-1.0, 1.0, 0.0)), TR_PI * t1 / 3.0);
	mat3 hinge_c_bot = axis_rot(normalize(vec3(1.0, 1.0, 0.0)), TR_PI * t1 / 3.0);
	mat3 hinge_w_top = axis_rot(vec3(1.0, 0.0, 0.0), -gam / 3.0);
	mat3 hinge_w_bot = axis_rot(vec3(1.0, 0.0, 0.0), gam / 3.0);
	mat3 half_top = axis_rot(vec3(1.0, 0.0, 0.0), beta);
	mat3 half_bot = axis_rot(vec3(1.0, 0.0, 0.0), -beta);
	for (int hi = 0; hi < 2; hi++) {
		float h = hi == 0 ? 1.0 : -1.0;
		vec2 nin = h > 0.0 ? vec2(0.70710678, 0.70710678) : vec2(0.70710678, -0.70710678);
		mat3 hc = h > 0.0 ? hinge_c_top : hinge_c_bot;
		mat3 hw = h > 0.0 ? hinge_w_top : hinge_w_bot;
		mat3 hh = h > 0.0 ? half_top : half_bot;
		for (int ci = 0; ci <= 3; ci++) {
			mat3 rc = mat3(1.0);
			vec3 tc = vec3(0.0);
			for (int j = 3; j >= 1; j--) {
				if (j <= ci) {
					about(rc, tc, hc, vec3(vec2(a, 0.0) + nin * float(j - 1) * hs, 0.0));
				}
			}
			for (int wi = 0; wi <= 3; wi++) {
				mat3 r = rc;
				vec3 t = tc;
				for (int j = 3; j >= 1; j--) {
					if (j <= wi) {
						about(r, t, hw, vec3(0.0, h * (wl + float(j - 1) * hs), 0.0));
					}
				}
				about(r, t, hh, vec3(0.0));
				r = g * r * sc;
				t = g * t * sc + pos;
				mat3 ri = transpose(r) / (sc * sc);
				vec3 o = ri * (ro - t);
				vec3 dd = ri * rd;
				if (abs(dd.z) < 0.0000001) {
					continue;
				}
				float l = -o.z / dd.z;
				if (l <= 0.0 || l >= bd3) {
					continue;
				}
				vec2 sp = (o + dd * l).xy;
				float px_sheet = l * rd.z * rd.z / (tr_camera_distance(lens) * frame_px.y) / (sc * max(abs(dd.z) * sc, 0.45));
				if (abs(sp.x) > a + px_sheet || abs(sp.y) > 0.5 + px_sheet || h * sp.y < -0.006) {
					continue;
				}
				float s_c = dot(sp - vec2(a, 0.0), nin);
				float lo_c = ci == 0 ? -1e9 : float(ci - 1) * hs - 0.012;
				float hi_c = ci == 3 ? 1e9 : float(ci) * hs + 0.012;
				if (s_c < lo_c || s_c > hi_c) {
					continue;
				}
				vec3 ph = rc * vec3(sp, 0.0) + tc;
				float s_w = h * ph.y - wl;
				float lo_w = wi == 0 ? -1e9 : float(wi - 1) * hs - 0.012;
				float hi_w = wi == 3 ? 1e9 : float(wi) * hs + 0.012;
				if (s_w < lo_w || s_w > hi_w) {
					continue;
				}
				vec4 col = texture(from_tex, tr_frame_uv(sp));
				vec3 nrm = normalize(r * vec3(0.0, 0.0, -1.0));
				if (dd.z < 0.0) {
					col = mix(col, vec4(paper.rgb, 1.0) * col.a, back_fade);
				}
				float lt = max(mix(abs(nrm.z), 0.35 + 0.65 * abs(dot(nrm, light_dir)), tv), 0.3);
				float e_out = min(a - abs(sp.x), 0.5 - abs(sp.y));
				float cv = clamp(e_out / max(px_sheet, 0.000001) + 0.5, 0.0, 1.0);
				if (cv <= 0.0) {
					continue;
				}
				vec4 shaded = tr_shade(col, mix(1.0, lt, shading)) * cv;
				if (l < bd) {
					third = second;
					bd3 = bd2;
					third_cov = second_cov;
					second = best;
					bd2 = bd;
					second_cov = best_cov;
					best = shaded;
					bd = l;
					best_cov = cv;
				} else if (l < bd2) {
					third = second;
					bd3 = bd2;
					third_cov = second_cov;
					second = shaded;
					bd2 = l;
					second_cov = cv;
				} else if (l < bd3) {
					third = shaded;
					bd3 = l;
					third_cov = cv;
				}
			}
		}
	}
	cover = best_cov + (second_cov + third_cov * (1.0 - second_cov)) * (1.0 - best_cov);
	return best + (second + third * (1.0 - second_cov)) * (1.0 - best_cov);
}

vec4 transition(vec2 uv) {
	float p = progress;
	float a = tr_ratio() * 0.5;
	float wl = 0.14;
	float ff = clamp(p / fold_share, 0.0, 1.0);
	float t1 = smoothstep(0.0, 0.45, ff);
	float t2 = smoothstep(0.3, 0.75, ff);
	float t3 = smoothstep(0.6, 0.95, ff);
	float tv = smoothstep(0.1, 1.0, ff);
	float beta = radians(89.5) * t2;
	float since = max(p - fold_share, 0.0) * max(duration, 0.001);
	float flap = radians(flap_amount) * smoothstep(0.0, 0.3, since) * flap_wave(since * flap_speed * 2.0 * TR_PI);
	float gam = radians(89.5) * t3 + flap;
	mat3 g;
	vec3 pos;
	float sc;
	if (p < fold_share) {
		float u0 = flight_u(p);
		vec4 q1 = mat_quat(flight_frame(u0));
		vec4 q0 = vec4(0.0, 0.0, 0.0, 1.0);
		if (q1.w < 0.0) {
			q1 = -q1;
		}
		g = quat_mat(normalize(mix(q0, q1, tv)));
		pos = path_world(u0) * tv;
		sc = mix(1.0, size, tv);
	} else {
		float u = flight_u(p);
		g = flight_frame(u);
		pos = path_world(u);
		sc = size;
	}
	float cover;
	float sub;
	vec4 best = plane_sample(uv, g, pos, sc, t1, beta, gam, tv, cover);
	if (fwidth(cover) > 0.02) {
		vec2 pxs = 1.0 / frame_px;
		vec4 acc = best * 2.0;
		acc += plane_sample(uv + pxs * vec2(0.375, 0.125), g, pos, sc, t1, beta, gam, tv, sub);
		acc += plane_sample(uv + pxs * vec2(-0.125, 0.375), g, pos, sc, t1, beta, gam, tv, sub);
		acc += plane_sample(uv + pxs * vec2(-0.375, -0.125), g, pos, sc, t1, beta, gam, tv, sub);
		acc += plane_sample(uv + pxs * vec2(0.125, -0.375), g, pos, sc, t1, beta, gam, tv, sub);
		best = acc / 6.0;
	}
	float gone = 1.0 - smoothstep(0.9, 1.0, p);
	best *= gone;
	vec4 smoke = contrail(uv, p) * gone;
	vec4 under = to_at(uv) * clamp(p * 25.0, 0.0, 1.0);
	return tr_over(best, tr_over(smoke, tr_over(under, bg_fill())));
}

void fragment() {
	COLOR = transition(UV);
}

shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform float lift : hint_range(0.0, 1.0) = 0.7;
uniform float fold : hint_range(0.1, 1.0) = 0.6;
uniform float spin : hint_range(0.0, 2.0) = 1.0;
uniform int strips : hint_range(0, 16) = 8;
uniform float lens : hint_range(10.0, 90.0) = 45.0;
uniform float slant : hint_range(-60.0, 60.0) = 25.0;

vec2 to_wind(vec2 w) {
	if (direction == 1) {
		return vec2(-w.x, w.y);
	} else if (direction == 2) {
		return vec2(w.y, -w.x);
	} else if (direction == 3) {
		return vec2(-w.y, w.x);
	}
	return w;
}

vec2 from_wind(vec2 q) {
	if (direction == 1) {
		return vec2(-q.x, q.y);
	} else if (direction == 2) {
		return vec2(-q.y, q.x);
	} else if (direction == 3) {
		return vec2(q.y, -q.x);
	}
	return q;
}

vec2 extent() {
	return direction >= 2 ? vec2(0.5, tr_ratio() * 0.5) : vec2(tr_ratio() * 0.5, 0.5);
}

float gust(float p) {
	return pow(smoothstep(0.25, 1.0, p), 1.7);
}

mat3 pose(float p) {
	float g = gust(p);
	float e1 = smoothstep(0.0, 0.5, p);
	float yaw = spin * (0.25 * e1 + 0.9 * g);
	float roll = spin * (0.12 * e1 + 0.35 * g);
	mat3 ry = mat3(vec3(cos(yaw), 0.0, -sin(yaw)), vec3(0.0, 1.0, 0.0), vec3(sin(yaw), 0.0, cos(yaw)));
	mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(roll), sin(roll)), vec3(0.0, -sin(roll), cos(roll)));
	return ry * rx;
}

vec3 travel(float g) {
	return vec3(5.0 * extent().x * g, 0.2 * sin(TR_PI * g) * lift, 0.8 * g);
}

vec2 slant_dir() {
	float a = radians(slant);
	return vec2(cos(a), sin(a));
}

vec2 to_fold(vec2 m) {
	vec2 c = slant_dir();
	return vec2(c.x * m.x + c.y * m.y, -c.y * m.x + c.x * m.y);
}

vec2 from_fold(vec2 f) {
	vec2 c = slant_dir();
	return vec2(c.x * f.x - c.y * f.y, c.y * f.x + c.x * f.y);
}

vec3 fold_shape(float p) {
	vec2 e = extent();
	vec2 c = slant_dir();
	float start = -(abs(c.x) * e.x + abs(c.y) * e.y);
	float e1 = smoothstep(0.0, 0.5, p);
	float theta = lift * 3.0 * e1;
	float len = (0.15 + 0.45 * e1) * 2.0 * e.x * fold;
	float rad = 0.08 + 0.18 * fold;
	return vec3(start + len, rad, theta);
}

vec3 bend(vec2 m, float p) {
	vec3 f = fold_shape(p);
	vec2 fm = to_fold(m);
	float s = f.x - fm.x;
	if (s <= 0.0 || f.z <= 0.0) {
		return vec3(m, 0.0);
	}
	float arc = f.y * f.z;
	vec2 bz;
	if (s < arc) {
		float ph = s / f.y;
		bz = vec2(f.x - f.y * sin(ph), -f.y * (1.0 - cos(ph)));
	} else {
		float rest = s - arc;
		bz = vec2(f.x - f.y * sin(f.z) - rest * cos(f.z), -f.y * (1.0 - cos(f.z)) - rest * sin(f.z));
	}
	return vec3(from_fold(vec2(bz.x, fm.y)), bz.y);
}

vec3 sheet_point(vec2 m, float p) {
	return pose(p) * bend(m, p) + travel(gust(p));
}

vec2 project(vec3 x, float d) {
	return x.xy * d / max(x.z + d, 0.0001);
}

float strip_time(int k) {
	return 0.15 + 0.3 * tr_hash(vec2(float(k), 3.1));
}

float strip_depth(int k) {
	return extent().x * (0.04 + 0.08 * tr_hash(vec2(float(k), 7.7)));
}

bool strip_torn(int k) {
	return tr_hash(vec2(float(k), 1.9)) > 0.3;
}

bool in_hole(vec2 m, float p) {
	vec2 e = extent();
	int n = clamp(strips, 0, 16);
	if (n == 0) {
		return false;
	}
	float band = 2.0 * e.y / float(n);
	int k = int(clamp(floor((m.y + e.y) / band), 0.0, float(n - 1)));
	return strip_torn(k) && p > strip_time(k) && m.x < -e.x + strip_depth(k);
}

vec4 shade(vec4 c, vec3 n, vec3 dir, float amount) {
	vec3 light = normalize(vec3(-0.4, 0.6, -0.7));
	bool back = dot(n, dir) < 0.0;
	vec3 nf = back ? n : -n;
	float diff = max(dot(nf, light), 0.0);
	float spec = pow(max(dot(nf, normalize(light - dir)), 0.0), 24.0);
	float lit = (back ? 0.5 : 0.68) + 0.4 * diff;
	c = tr_shade(c, mix(1.0, lit, amount));
	c.rgb += vec3(spec * 0.25 * amount) * c.a;
	return c;
}

void consider(float t, float fu, vec3 o, vec3 v, float p, float d, vec3 dir, float amount, inout vec4 best_c, inout float best_t, inout float best_v) {
	if (t <= 0.0 || t >= best_t) {
		return;
	}
	vec2 e = extent();
	vec2 m = from_fold(vec2(fu, o.y + v.y * t));
	if (in_hole(m, p)) {
		return;
	}
	float px_world = 1.0 / max(frame_px.y, 1.0);
	vec3 x = sheet_point(m, p);
	vec3 tx = sheet_point(m + vec2(0.002, 0.0), p) - x;
	vec3 ty = sheet_point(m + vec2(0.0, 0.002), p) - x;
	float kx = length(project(x + tx, d) - project(x, d)) / 0.002;
	float ky = length(project(x + ty, d) - project(x, d)) / 0.002;
	vec2 inside = (e - abs(m)) * vec2(kx, ky);
	float edge = min(inside.x, inside.y);
	float cv = amount > 0.0 ? clamp(edge / (px_world * amount) + 0.5, 0.0, 1.0) : (edge >= 0.0 ? 1.0 : 0.0);
	if (cv <= 0.0) {
		return;
	}
	vec3 n = normalize(cross(tx, ty));
	vec4 c = from_at(tr_frame_uv(from_wind(clamp(m, -e, e))));
	best_c = shade(c, n, dir, amount);
	best_t = t;
	best_v = cv;
}

vec4 transition(vec2 uv) {
	float p = progress;
	if (p <= 0.0) {
		return from_at(uv);
	}
	vec4 under = to_at(uv);
	float leak = clamp(min(p, 1.0 - p) * 8.0, 0.0, 1.0);
	float d = tr_camera_distance(lens);
	vec2 e = extent();
	vec2 q = to_wind(tr_world(uv));
	vec3 cam = vec3(0.0, 0.0, -d);
	vec3 dir = normalize(vec3(q, d));
	float amount = smoothstep(0.0, 0.1, p);
	vec4 best_c = vec4(0.0);
	float best_t = 1e9;
	float best_v = 0.0;
	float g = gust(p);
	mat3 inv = transpose(pose(p));
	vec3 o = inv * (cam - travel(g));
	vec3 v = inv * dir;
	o = vec3(to_fold(o.xy), o.z);
	v = vec3(to_fold(v.xy), v.z);
	vec3 f = fold_shape(p);
	if (abs(v.z) > 1e-6) {
		float t = -o.z / v.z;
		float x = o.x + v.x * t;
		if (x >= f.x || f.z <= 0.0) {
			consider(t, x, o, v, p, d, dir, amount, best_c, best_t, best_v);
		}
	}
	if (f.z > 0.0) {
		vec2 oc = vec2(o.x - f.x, o.z + f.y);
		vec2 vc = vec2(v.x, v.z);
		float qa = dot(vc, vc);
		float qb = 2.0 * dot(oc, vc);
		float qc = dot(oc, oc) - f.y * f.y;
		float disc = qb * qb - 4.0 * qa * qc;
		if (disc >= 0.0 && qa > 1e-9) {
			float sq = sqrt(disc);
			for (int i = 0; i < 2; i++) {
				float t = (-qb + (i == 0 ? -sq : sq)) / (2.0 * qa);
				vec2 h = oc + vc * t;
				float ph = atan(-h.x, h.y);
				if (ph >= 0.0 && ph <= f.z) {
					consider(t, f.x - f.y * ph, o, v, p, d, dir, amount, best_c, best_t, best_v);
				}
			}
		}
		vec2 p0 = vec2(f.x - f.y * sin(f.z), -f.y * (1.0 - cos(f.z)));
		vec2 dd = vec2(-cos(f.z), -sin(f.z));
		float den = vc.x * dd.y - vc.y * dd.x;
		if (abs(den) > 1e-7) {
			vec2 r = p0 - vec2(o.x, o.z);
			float t = (r.x * dd.y - r.y * dd.x) / den;
			float u = (r.x * vc.y - r.y * vc.x) / den;
			if (u >= 0.0) {
				consider(t, f.x - f.y * f.z - u, o, v, p, d, dir, amount, best_c, best_t, best_v);
			}
		}
	}
	float best_z = best_t < 1e8 ? (cam + dir * best_t).z : 1e9;
	int count = clamp(strips, 0, 16);
	float band = count > 0 ? 2.0 * e.y / float(count) : 1.0;
	for (int k = 0; k < 16; k++) {
		if (k >= count) {
			break;
		}
		float pk = strip_time(k);
		if (!strip_torn(k) || p <= pk) {
			continue;
		}
		float dk = strip_depth(k);
		vec2 mc = vec2(-e.x + dk * 0.5, -e.y + (float(k) + 0.5) * band);
		vec3 c0 = sheet_point(mc, pk);
		vec3 ax = normalize(sheet_point(mc + vec2(0.002, 0.0), pk) - c0);
		vec3 ay = normalize(sheet_point(mc + vec2(0.0, 0.002), pk) - c0);
		vec3 az = normalize(cross(ax, ay));
		ay = cross(az, ax);
		float dt = p - pk;
		float h = tr_hash(vec2(float(k), 5.3));
		float a = dt * TR_PI * 3.0 * (0.7 + 0.6 * h) * spin;
		vec3 bz = az * cos(a) + cross(ay, az) * sin(a);
		vec3 bx = normalize(cross(ay, bz));
		vec3 centre = c0 + vec3(2.5 * dt + 6.0 * dt * dt, (0.4 * h - 0.1) * dt - 0.6 * dt * dt, 0.6 * dt);
		vec2 sc = project(centre, d);
		float rad = (dk + band) * d / max(centre.z + d, 0.05);
		if (centre.z + d < 0.05 || length(sc - q) > rad) {
			continue;
		}
		float den = dot(dir, bz);
		if (abs(den) < 1e-5) {
			continue;
		}
		float t = dot(centre - cam, bz) / den;
		vec3 hp = cam + dir * t - centre;
		vec2 local = vec2(dot(hp, bx), dot(hp, ay));
		if (abs(local.x) > dk * 0.5 || abs(local.y) > band * 0.5 || t <= 0.0) {
			continue;
		}
		float z = (cam + dir * t).z;
		if (z >= best_z) {
			continue;
		}
		vec4 c = from_at(tr_frame_uv(from_wind(mc + local)));
		best_c = shade(c, bz, dir, 1.0);
		best_z = z;
		best_v = 1.0;
	}
	return best_c * best_v + under * (1.0 - best_v + best_v * (1.0 - best_c.a) * leak);
}

void fragment() {
	COLOR = transition(UV);
}

shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 centre = vec2(0.5, 0.5);
uniform float size : hint_range(0.01, 0.6) = 0.15;
uniform float push : hint_range(-1.0, 1.0) = 0.8;
uniform float reach : hint_range(0.02, 1.0) = 0.16;
uniform float shape_length : hint_range(0.0, 1.5) = 0.0;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform vec2 centre_b = vec2(0.72, 0.5);
uniform float push_b : hint_range(-1.0, 1.0) = 0.0;
uniform float wrinkles : hint_range(0.0, 1.0) = 0.6;
uniform float stretch : hint_range(0.0, 1.0) = 0.5;
uniform float tilt : hint_range(-80.0, 80.0) = 0.0;
uniform float swivel : hint_range(-80.0, 80.0) = 0.0;
uniform float roll : hint_range(-180.0, 180.0) = 0.0;
uniform float camera_distance : hint_range(0.5, 8.0) = 1.3737;
uniform float fov : hint_range(5.0, 120.0) = 40.0;
uniform float scale : hint_range(0.1, 4.0) = 1.0;
uniform float light_angle : hint_range(-180.0, 180.0) = -135.0;
uniform float light_height : hint_range(2.0, 90.0) = 40.0;
uniform float shadows : hint_range(0.0, 1.0) = 0.8;
uniform float softness : hint_range(0.0, 1.0) = 0.6;
uniform float shine : hint_range(0.0, 1.0) = 0.55;
uniform float gloss : hint_range(0.0, 1.0) = 0.2;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);

vec3 rot_x(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(v.x, c * v.y + s * v.z, -s * v.y + c * v.z);
}

vec3 rot_y(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * v.x - s * v.z, v.y, s * v.x + c * v.z);
}

vec3 rot_z(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * v.x - s * v.y, s * v.x + c * v.y, v.z);
}

vec3 to_local(vec3 v) {
	return rot_x(rot_y(rot_z(v, -radians(roll)), -radians(swivel)), -radians(tilt));
}

vec3 safe_inv(vec3 d) {
	vec3 s = vec3(d.x < 0.0 ? -1.0 : 1.0, d.y < 0.0 ? -1.0 : 1.0, d.z < 0.0 ? -1.0 : 1.0);
	return s / max(abs(d), vec3(1e-7));
}

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), u) * 2.0 - 1.0;
}

vec2 seg_point(vec2 q, vec2 c, float len, float ang) {
	vec2 dir = vec2(cos(ang), sin(ang));
	float t = clamp(dot(q - c, dir), -0.5 * len, 0.5 * len);
	return c + dir * t;
}

float prof(float r, float R, float lam) {
	return exp(-(sqrt(r * r + R * R) - R) / lam);
}

float noise2(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash11(i.x + i.y * 57.0);
	float b = hash11(i.x + 1.0 + i.y * 57.0);
	float c = hash11(i.x + (i.y + 1.0) * 57.0);
	float d = hash11(i.x + 1.0 + (i.y + 1.0) * 57.0);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

float rect_exit(vec2 p0, vec2 dir, float a) {
	vec2 b = vec2(0.5 * a, 0.5);
	float tx = dir.x > 1e-5 ? (b.x - p0.x) / dir.x : (dir.x < -1e-5 ? (-b.x - p0.x) / dir.x : 1e5);
	float ty = dir.y > 1e-5 ? (b.y - p0.y) / dir.y : (dir.y < -1e-5 ? (-b.y - p0.y) / dir.y : 1e5);
	return max(min(tx, ty), 0.002);
}

float tent(vec2 q, vec2 c, float amount, float hmax, float sd, float a, bool fine) {
	vec2 p0 = seg_point(q, c, shape_length, radians(angle));
	vec2 off = q - p0;
	float r = length(off);
	vec2 dir = r > 1e-6 ? off / r : vec2(1.0, 0.0);
	float R = max(size, 0.005);
	float lam = max(reach, 0.01);
	float rb = max(rect_exit(p0, dir, a), r);
	float fb = prof(rb, R, lam);
	float fr = (prof(r, R, lam) - fb) / max(1.0 - fb, 0.05);
	if (!fine) {
		return amount * hmax * fr;
	}
	float ang = atan(off.y, off.x);
	float ridge_n = floor(6.0 + 6.0 * wrinkles);
	float phase = ang * ridge_n + 2.4 * noise2(dir * 1.2 + sd) + 1.2 * noise2(dir * 2.9 + sd * 1.7);
	float ridge = sin(phase) * (0.55 + 0.45 * noise2(dir * 2.1 + sd * 2.9));
	float env = smoothstep(R * 0.6, R * 1.5, r) * exp(-max(r - R, 0.0) / (lam * 2.2)) * clamp((rb - r) / max(lam, 0.02), 0.0, 1.0);
	return amount * hmax * fr + abs(amount) * hmax * wrinkles * 0.06 * env * ridge * sqrt(max(fr, 0.0));
}

float field(vec2 q, float a, bool fine) {
	float hmax = 0.3;
	vec2 ca = vec2((centre.x - 0.5) * a, centre.y - 0.5);
	vec2 cb = vec2((centre_b.x - 0.5) * a, centre_b.y - 0.5);
	float sd = float(seed) * 7.31;
	float h1 = tent(q, ca, push, hmax, sd, a, fine);
	float h2 = abs(push_b) > 0.0001 ? tent(q, cb, push_b, hmax, sd + 13.7, a, fine) : 0.0;
	float h = h1 + h2;
	if (push >= 0.0 && push_b >= 0.0) {
		float k = 30.0;
		h = log(max(exp(k * h1) + exp(k * h2) - 1.0, 1e-6)) / k;
	}
	return h;
}

vec2 material_uv(vec2 q, float a) {
	vec2 ca = vec2((centre.x - 0.5) * a, centre.y - 0.5);
	vec2 cb = vec2((centre_b.x - 0.5) * a, centre_b.y - 0.5);
	float ang = radians(angle);
	float m = 0.38 * stretch;
	vec2 oa = q - seg_point(q, ca, shape_length, ang);
	vec2 ob = q - seg_point(q, cb, shape_length, ang);
	float R = max(size, 0.005);
	float lam = max(reach, 0.01);
	float wa = push * exp(-(sqrt(dot(oa, oa) + R * R) - R) / lam);
	float wb = push_b * exp(-(sqrt(dot(ob, ob) + R * R) - R) / lam);
	vec2 m_q = q - oa * m * wa - ob * m * wb;
	return vec2(m_q.x / a + 0.5, m_q.y + 0.5);
}

void fragment() {
	vec2 full = max(vec2(textureSize(TEXTURE, 0)), vec2(1.0));
	float a = full.x / full.y;
	float f = 0.5 / tan(radians(clamp(fov, 1.0, 170.0)) * 0.5);
	float sc = max(scale, 0.01);
	vec2 s = vec2((UV.x - 0.5) * a, UV.y - 0.5);
	vec3 o = to_local(vec3(0.0, 0.0, -camera_distance)) / sc;
	vec3 d = to_local(vec3(s, f)) / sc;
	float up = 0.3 * (max(push, 0.0) + max(push_b, 0.0)) * (1.0 + 0.08 * wrinkles) + 0.0004;
	float down = 0.3 * (max(-push, 0.0) + max(-push_b, 0.0)) * (1.0 + 0.08 * wrinkles) + 0.0004;
	vec3 bmin = vec3(-0.5 * a, -0.5, -up);
	vec3 bmax = vec3(0.5 * a, 0.5, down);
	vec3 inv = safe_inv(d);
	vec3 t1 = (bmin - o) * inv;
	vec3 t2 = (bmax - o) * inv;
	vec3 tlo = min(t1, t2);
	vec3 thi = max(t1, t2);
	float tmin = max(max(tlo.x, tlo.y), max(tlo.z, 0.0));
	float tmax = min(min(thi.x, thi.y), thi.z);
	vec4 outc = vec4(0.0);
	float wr_pad = 0.3 * (abs(push) + abs(push_b)) * wrinkles * 0.06;
	bool flat_sheet = abs(push) < 0.0001 && abs(push_b) < 0.0001;
	if (d.z > 1e-6 && tmax > tmin) {
		bool hit = false;
		float th = tmax;
		float tp = tmin;
		if (flat_sheet) {
			th = -o.z / d.z;
			hit = th >= tmin - 1e-5 && th <= tmax + 1e-5;
		} else {
			float travel = (tmax - tmin) * length(d.xy) * full.y;
			int n = int(clamp(travel / 4.0, 8.0, 64.0));
			float dt = (tmax - tmin) / float(n);
			for (int i = 0; i <= n; i++) {
				float t = tmin + dt * float(i);
				vec3 p = o + d * t;
				if (p.z >= -field(p.xy, a, false) - wr_pad) {
					hit = true;
					th = t;
					break;
				}
				tp = t;
			}
			if (hit && th > tmin) {
				float lo = tp;
				float hi = min(th + (tmax - tmin) / float(n), tmax);
				for (int k = 0; k < 8; k++) {
					float mid = 0.5 * (lo + hi);
					vec3 p = o + d * mid;
					if (p.z >= -field(p.xy, a, true)) {
						hi = mid;
					} else {
						lo = mid;
					}
				}
				th = hi;
			}
		}
		if (hit) {
			vec3 p = o + d * th;
			vec2 uv = flat_sheet ? vec2(p.x / a + 0.5, p.y + 0.5) : material_uv(p.xy, a);
			vec4 c = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
			vec3 n = vec3(0.0, 0.0, -1.0);
			float strain = 0.0;
			float ao = 1.0;
			float la = radians(light_angle);
			float le = radians(clamp(light_height, 1.0, 90.0));
			vec3 L = normalize(vec3(cos(la) * cos(le), sin(la) * cos(le), -sin(le)));
			float sh = 1.0;
			if (!flat_sheet) {
				float e = 1.5 / full.y;
				float hx = (field(p.xy + vec2(e, 0.0), a, true) - field(p.xy - vec2(e, 0.0), a, true)) / (2.0 * e);
				float hy = (field(p.xy + vec2(0.0, e), a, true) - field(p.xy - vec2(0.0, e), a, true)) / (2.0 * e);
				n = normalize(vec3(-hx, -hy, -1.0));
				vec2 ca = vec2((centre.x - 0.5) * a, centre.y - 0.5);
				float R = max(size, 0.005);
				float lam = max(reach, 0.01);
				float near_a = exp(-(sqrt(dot(p.xy - ca, p.xy - ca) + R * R) - R) / lam);
				vec2 cb = vec2((centre_b.x - 0.5) * a, centre_b.y - 0.5);
				float near_b = exp(-(sqrt(dot(p.xy - cb, p.xy - cb) + R * R) - R) / lam);
				strain = clamp((sqrt(1.0 + hx * hx + hy * hy) - 1.0) * 1.6 + 0.9 * (abs(push) * near_a + abs(push_b) * near_b), 0.0, 1.5);
				float occ = 0.0;
				float rho = max(reach, 0.03) * 0.6;
				float h0 = field(p.xy, a, false);
				for (int m = 0; m < 6; m++) {
					float an = float(m) * 1.0472 + 0.4;
					occ += max(field(p.xy + vec2(cos(an), sin(an)) * rho, a, false) - h0, 0.0);
				}
				ao = 1.0 - clamp(occ / (6.0 * rho) * 1.4, 0.0, 0.6);
				if (shadows > 0.001) {
					float k = mix(32.0, 2.0, softness);
					float res = 1.0;
					float span = (up + p.z) / max(-L.z, 0.03) + 0.001;
					span = min(span, 1.2);
					for (int j = 1; j <= 14; j++) {
						float t = span * float(j) / 14.0;
						vec3 q = p + L * t;
						float clear = -field(q.xy, a, false) - q.z + 0.0025;
						res = min(res, clamp(k * clear / t, 0.0, 1.0));
					}
					sh = mix(1.0, res, shadows);
				}
			}
			float amb = 0.18;
			float flat_d = max((-L.z + 0.15) / 1.15, 0.05);
			float diff = max((dot(n, L) + 0.15) / 1.15, 0.0) * sh;
			float lit = (amb * ao + (1.0 - amb) * diff) / (amb + (1.0 - amb) * flat_d);
			float ca_ = max(c.a, 0.0001);
			vec3 alb = c.rgb / ca_;
			float pale = clamp(strain * stretch, 0.0, 1.0);
			vec2 kp = uv * full / 2.6;
			float knit = (0.5 + 0.5 * sin(kp.x * 6.2832)) * (0.5 + 0.5 * sin(kp.y * 6.2832 + 3.1416 * floor(kp.x)));
			alb = mix(alb, mix(alb, vec3(dot(alb, vec3(0.3, 0.59, 0.11))), 0.6) * 0.45 + 0.55, smoothstep(0.0, 1.0, pale) * 0.85);
			alb *= 1.0 - smoothstep(0.0, 1.0, pale) * 0.14 * knit;
			vec3 V = normalize(-d);
			vec3 hv = normalize(L + V);
			float spec = pow(max(dot(n, hv), 0.0), mix(6.0, 120.0, gloss * gloss)) * shine * (0.35 + 1.4 * gloss) * sh * (flat_sheet ? 1.0 : 1.0 + pale);
			vec3 rgb = flat_sheet ? alb : alb * lit + vec3(1.0, 0.98, 0.95) * spec;
			outc = vec4(rgb * c.a, c.a);
		}
	}
	COLOR = outc;
}

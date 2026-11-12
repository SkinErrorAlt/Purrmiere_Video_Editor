shader_type canvas_item;
render_mode blend_disabled;

uniform int pinned = 0;
uniform float wind : hint_range(0.0, 1.0) = 0.55;
uniform float fold_size : hint_range(0.1, 3.0) = 0.75;
uniform float speed : hint_range(0.0, 4.0) = 1.0;
uniform float gusts : hint_range(0.0, 1.0) = 0.4;
uniform float flutter : hint_range(0.0, 1.0) = 0.5;
uniform float weave : hint_range(0.0, 1.0) = 0.5;
uniform float weave_size : hint_range(1.0, 12.0) = 3.0;
uniform float translucency : hint_range(0.0, 1.0) = 0.35;
uniform float tilt : hint_range(-80.0, 80.0) = 0.0;
uniform float swivel : hint_range(-80.0, 80.0) = 0.0;
uniform float roll : hint_range(-180.0, 180.0) = 0.0;
uniform float camera_distance : hint_range(0.5, 8.0) = 1.3737;
uniform float fov : hint_range(5.0, 120.0) = 40.0;
uniform float scale : hint_range(0.1, 4.0) = 1.0;
uniform float light_angle : hint_range(-180.0, 180.0) = -130.0;
uniform float light_height : hint_range(2.0, 90.0) = 40.0;
uniform float shadows : hint_range(0.0, 1.0) = 0.8;
uniform float shine : hint_range(0.0, 1.0) = 0.4;
uniform int seed : hint_range(0, 999) = 0;
uniform float time = 0.0;
uniform float px_scale = 1.0;

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

float amp_now() {
	float sd = float(seed) * 3.71;
	float g = 1.0 + gusts * 0.55 * noise1(time * 0.45 * max(speed, 0.05) + sd) + gusts * 0.25 * noise1(time * 1.3 * max(speed, 0.05) + sd * 2.0);
	return 0.13 * wind * max(g, 0.2);
}

vec3 phases(float s, float w) {
	float sd = float(seed) * 1.618;
	float lam = max(fold_size, 0.05);
	float c = 1.15 * speed;
	float k1 = 6.2832 / lam;
	float k2 = 6.2832 / (lam * 0.57);
	float k3 = 6.2832 / (lam * 0.29);
	float p1 = k1 * (s * 0.97 + w * 0.25) - k1 * c * time + sd;
	float p2 = k2 * (s * 0.9 - w * 0.43) - k2 * c * 1.1 * time + sd * 2.3;
	float p3 = k3 * (s * 0.77 + w * 0.64) - k3 * c * 1.35 * time + sd * 4.1;
	return vec3(p1, p2, p3);
}

float grow(float s, float len) {
	return pow(clamp(s / len, 0.0, 1.0), 0.75);
}

float zwave(float s, float w, float len, float amp) {
	vec3 ph = phases(s, w);
	float g = grow(s, len);
	float tip = g * g;
	float z = sin(ph.x) + 0.22 * sin(2.0 * ph.x + 0.6) + 0.5 * sin(ph.y) + flutter * 0.32 * tip * sin(ph.z);
	return amp * g * z;
}

float contraction(float s, float w, float len, float amp) {
	vec3 ph = phases(s, w);
	float lam = max(fold_size, 0.05);
	float k1 = 6.2832 / lam * 0.97;
	float k2 = 6.2832 / (lam * 0.57) * 0.9;
	float g = grow(s, len);
	float a1 = amp * g * k1;
	float a2 = amp * g * k2 * 0.5;
	float c = a1 * a1 * 0.25 * (s / 2.5 + sin(2.0 * ph.x) / (2.0 * k1)) + a2 * a2 * 0.25 * (s / 2.5 + sin(2.0 * ph.y) / (2.0 * k2));
	return clamp(c, 0.0, 0.4 * s);
}

vec2 to_frame(vec2 p, float a) {
	if (pinned == 1) {
		return vec2(0.5 * a - p.x, p.y);
	} else if (pinned == 2) {
		return vec2(p.y + 0.5, p.x);
	}
	return vec2(p.x + 0.5 * a, p.y);
}

vec2 from_frame(vec2 sw, float a) {
	if (pinned == 1) {
		return vec2(0.5 * a - sw.x, sw.y);
	} else if (pinned == 2) {
		return vec2(sw.y, sw.x - 0.5);
	}
	return vec2(sw.x - 0.5 * a, sw.y);
}

vec4 cloth(vec2 p, float a, float amp, float margin) {
	float len = pinned == 2 ? 1.0 : a;
	float half_w = pinned == 2 ? 0.5 * a : 0.5;
	vec2 sw = to_frame(p, a);
	float sm = sw.x;
	for (int i = 0; i < 3; i++) {
		sm = sw.x + contraction(sm, sw.y, len, amp);
	}
	vec3 ph = phases(sm, sw.y);
	float wm = sw.y - 0.28 * amp * grow(sm, len) * sin(ph.x + 1.1) * (abs(sw.y) / half_w);
	float z = zwave(sm, wm, len, amp);
	bool inside = sm >= -margin && sm <= len + margin && abs(wm) <= half_w + margin;
	vec2 m = from_frame(vec2(sm, wm), a);
	return vec4(m, z, inside ? 1.0 : 0.0);
}

void fragment() {
	vec2 full = max(vec2(textureSize(TEXTURE, 0)), vec2(1.0));
	float a = full.x / full.y;
	float f = 0.5 / tan(radians(clamp(fov, 1.0, 170.0)) * 0.5);
	float sc = max(scale, 0.01);
	vec2 s = vec2((UV.x - 0.5) * a, UV.y - 0.5);
	vec3 o = to_local(vec3(0.0, 0.0, -camera_distance)) / sc;
	vec3 d = to_local(vec3(s, f)) / sc;
	float amp = amp_now();
	float edge_m = 3.0 / full.y;
	float zmax = amp * (1.72 + 0.32 * flutter) + 0.0006;
	vec3 bmin = vec3(-0.5 * a - 2.0 * edge_m, -0.5 - 2.0 * edge_m, -zmax);
	vec3 bmax = vec3(0.5 * a + 2.0 * edge_m, 0.5 + 2.0 * edge_m, zmax);
	vec3 inv = safe_inv(d);
	vec3 t1 = (bmin - o) * inv;
	vec3 t2 = (bmax - o) * inv;
	vec3 tlo = min(t1, t2);
	vec3 thi = max(t1, t2);
	float tmin = max(max(tlo.x, tlo.y), max(tlo.z, 0.0));
	float tmax = min(min(thi.x, thi.y), thi.z);
	vec4 outc = vec4(0.0);
	bool calm = amp < 0.00001;
	if (d.z > 1e-6 && tmax > tmin) {
		bool hit = false;
		bool back = false;
		float th = tmax;
		vec4 cl = vec4(0.0);
		if (calm) {
			th = -o.z / d.z;
			vec3 p = o + d * th;
			cl = vec4(p.xy, 0.0, 1.0);
			hit = th >= tmin - 1e-5 && th <= tmax + 1e-5 && abs(p.x) <= 0.5 * a + 1e-5 && abs(p.y) <= 0.5 + 1e-5;
		} else {
			float travel = (tmax - tmin) * length(d.xy) * full.y;
			int n = int(clamp(travel / 2.0, 20.0, 72.0));
			float dt = (tmax - tmin) / float(n);
			float prev_g = 0.0;
			float prev_t = tmin;
			bool have = false;
			for (int i = 0; i <= n; i++) {
				float t = tmin + dt * float(i);
				vec3 p = o + d * t;
				vec4 c = cloth(p.xy, a, amp, edge_m);
				if (c.w < 0.5) {
					have = false;
					continue;
				}
				float g = p.z - c.z;
				if (have && sign(g) != sign(prev_g)) {
					float lo = prev_t;
					float hi = t;
					bool from_front = prev_g < 0.0;
					for (int k = 0; k < 6; k++) {
						float mid = 0.5 * (lo + hi);
						vec3 pm = o + d * mid;
						vec4 cm = cloth(pm.xy, a, amp, edge_m);
						float gm = pm.z - cm.z;
						if ((gm < 0.0) == from_front) {
							lo = mid;
						} else {
							hi = mid;
						}
					}
					th = hi;
					back = !from_front;
					hit = true;
					break;
				}
				if (!have && i == 0 && g >= 0.0) {
					back = true;
				}
				have = true;
				prev_g = g;
				prev_t = t;
			}
			if (hit) {
				vec3 p = o + d * th;
				cl = cloth(p.xy, a, amp, edge_m);
				hit = cl.w > 0.5;
			}
		}
		if (hit) {
			vec3 p = o + d * th;
			vec2 uv = clamp(vec2(cl.x / a + 0.5, cl.y + 0.5), vec2(0.0), vec2(1.0));
			vec4 col = texture(TEXTURE, uv);
			vec3 n = vec3(0.0, 0.0, -1.0);
			float la = radians(light_angle);
			float le = radians(clamp(light_height, 1.0, 90.0));
			vec3 L = normalize(vec3(cos(la) * cos(le), sin(la) * cos(le), -sin(le)));
			float sh = 1.0;
			vec3 tan_s = vec3(1.0, 0.0, 0.0);
			if (!calm) {
				float e = 1.5 / full.y;
				float zx = (cloth(p.xy + vec2(e, 0.0), a, amp, edge_m).z - cloth(p.xy - vec2(e, 0.0), a, amp, edge_m).z) / (2.0 * e);
				float zy = (cloth(p.xy + vec2(0.0, e), a, amp, edge_m).z - cloth(p.xy - vec2(0.0, e), a, amp, edge_m).z) / (2.0 * e);
				n = normalize(vec3(zx, zy, -1.0));
				tan_s = normalize(pinned == 2 ? vec3(0.0, 1.0, zy) : vec3(1.0, 0.0, zx));
				if (back) {
					n = -n;
				}
				if (shadows > 0.001 && dot(n, L) > 0.0) {
					float res = 1.0;
					float span = min((zmax + p.z) / max(-L.z, 0.05), 0.8);
					for (int j = 1; j <= 14; j++) {
						float t = span * float(j) / 14.0;
						vec3 q = p + L * t;
						vec4 cq = cloth(q.xy, a, amp, edge_m);
						if (cq.w < 0.5) {
							continue;
						}
						float clear = (cq.z - q.z) * (back ? -1.0 : 1.0) + 0.002;
						res = min(res, clamp(18.0 * clear / t, 0.0, 1.0));
					}
					sh = mix(1.0, res, shadows);
				}
			}
			float ca = max(col.a, 0.0001);
			vec3 alb = col.rgb / ca;
			vec2 wp = vec2(cl.x / a + 0.5, cl.y + 0.5) * full / max(weave_size * px_scale, 0.5);
			vec2 cell = floor(wp);
			vec2 fr = fract(wp);
			bool warp_on_top = mod(cell.x + cell.y, 2.0) < 1.0;
			float across = warp_on_top ? fr.y : fr.x;
			float thread = sin(3.1416 * across);
			float foot = max(fwidth(wp.x), fwidth(wp.y));
			float wv = weave * clamp(1.6 - foot, 0.0, 1.0);
			vec3 T = warp_on_top ? tan_s : normalize(cross(n, tan_s));
			if (!calm) {
				alb *= 1.0 - wv * 0.08 * (1.0 - thread);
			}
			float amb = 0.2;
			float flat_d = max(-L.z, 0.05);
			float ndl = dot(n, L);
			float diff = max(ndl, 0.0) * sh;
			vec3 Lb = normalize(vec3(-L.x * 0.4, -L.y * 0.4, 1.0));
			float through = translucency * 0.55 * max(dot(-n, Lb), 0.0) * (1.0 - 0.6 * max(ndl, 0.0) * sh) * (back ? 0.5 : 1.0);
			float lit = (amb + (1.0 - amb) * diff) / (amb + (1.0 - amb) * flat_d) + through / (amb + (1.0 - amb) * flat_d);
			vec3 V = normalize(-d);
			vec3 H = normalize(L + V);
			float th_d = dot(T, H);
			float aniso = pow(sqrt(max(1.0 - th_d * th_d, 0.0)), mix(18.0, 60.0, wv)) * mix(1.0, thread, wv);
			float iso = pow(max(dot(n, H), 0.0), 24.0);
			float spec = shine * mix(iso, aniso, 0.5 + 0.5 * wv) * sh * (back ? 0.4 : 1.0) * 0.8;
			if (calm) {
				spec = 0.0;
				lit = 1.0;
			}
			vec3 rgb = alb * lit + vec3(1.0, 0.98, 0.95) * spec;
			if (back) {
				rgb *= 0.82;
			}
			outc = vec4(rgb * col.a, col.a);
		}
	}
	COLOR = outc;
}

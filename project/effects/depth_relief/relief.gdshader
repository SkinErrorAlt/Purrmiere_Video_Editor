shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int source = 0;
uniform float height : hint_range(0.0, 100.0) = 35.0;
uniform float detail : hint_range(0.0, 1.0) = 0.3;
uniform float tilt : hint_range(-80.0, 80.0) = 22.0;
uniform float swivel : hint_range(-80.0, 80.0) = -18.0;
uniform float roll : hint_range(-180.0, 180.0) = 0.0;
uniform float camera_distance : hint_range(0.5, 8.0) = 1.3737;
uniform float fov : hint_range(5.0, 120.0) = 40.0;
uniform float scale : hint_range(0.1, 4.0) = 0.84;
uniform float light_angle : hint_range(-180.0, 180.0) = -135.0;
uniform float light_height : hint_range(2.0, 90.0) = 38.0;
uniform float shadows : hint_range(0.0, 1.0) = 0.85;
uniform float softness : hint_range(0.0, 1.0) = 0.3;
uniform float shine : hint_range(0.0, 1.0) = 0.35;
uniform float gloss : hint_range(0.0, 1.0) = 0.5;
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

float hgt(sampler2D t, vec2 uv) {
	vec4 c = texture(t, uv);
	return c.r + c.g / 255.0;
}

float signal(vec4 c) {
	float a = max(c.a, 0.0001);
	vec3 s = clamp(c.rgb / a, 0.0, 1.0);
	float v = dot(s, vec3(0.2126, 0.7152, 0.0722));
	if (source == 1) {
		v = 1.0 - v;
	} else if (source == 2) {
		v = s.r;
	} else if (source == 3) {
		v = s.g;
	} else if (source == 4) {
		v = s.b;
	} else if (source == 5) {
		float mx = max(s.r, max(s.g, s.b));
		float mn = min(s.r, min(s.g, s.b));
		v = mx > 0.0001 ? (mx - mn) / mx : 0.0;
	} else if (source == 6) {
		v = 1.0;
	}
	return v * c.a;
}

vec3 safe_inv(vec3 d) {
	vec3 s = vec3(d.x < 0.0 ? -1.0 : 1.0, d.y < 0.0 ? -1.0 : 1.0, d.z < 0.0 ? -1.0 : 1.0);
	return s / max(abs(d), vec3(1e-7));
}

void fragment() {
	vec2 full = max(vec2(textureSize(effect_tex, 0)), vec2(1.0));
	float a = full.x / full.y;
	float f = 0.5 / tan(radians(clamp(fov, 1.0, 170.0)) * 0.5);
	float sc = max(scale, 0.01);
	vec2 s = vec2((UV.x - 0.5) * a, UV.y - 0.5);
	vec3 o = to_local(vec3(0.0, 0.0, -camera_distance)) / sc;
	vec3 d = to_local(vec3(s, f)) / sc;
	float H = clamp(height, 0.0, 100.0) / 100.0 * 0.3;
	vec4 outc = vec4(0.0);
	vec3 bmin = vec3(-0.5 * a, -0.5, -H - 0.0004);
	vec3 bmax = vec3(0.5 * a, 0.5, 0.0004);
	vec3 inv = safe_inv(d);
	vec3 t1 = (bmin - o) * inv;
	vec3 t2 = (bmax - o) * inv;
	vec3 tlo = min(t1, t2);
	vec3 thi = max(t1, t2);
	float tmin = max(max(tlo.x, tlo.y), max(tlo.z, 0.0));
	float tmax = min(min(thi.x, thi.y), thi.z);
	int entry = tlo.z >= max(tlo.x, tlo.y) ? 2 : (tlo.x >= tlo.y ? 0 : 1);
	if (d.z > 1e-6 && tmax > tmin) {
		bool hit = false;
		bool wall = false;
		float th = tmax;
		float tp = tmin;
		if (H < 0.00002) {
			th = -o.z / d.z;
			hit = th >= tmin - 1e-5 && th <= tmax + 1e-5;
		} else {
			float travel = (tmax - tmin) * length(d.xy) * full.y;
			int n = int(clamp(travel / 2.0, 6.0, 110.0));
			float dt = (tmax - tmin) / float(n);
			for (int i = 0; i <= n; i++) {
				float t = tmin + dt * float(i);
				vec3 p = o + d * t;
				vec2 uv = vec2(p.x / a + 0.5, p.y + 0.5);
				if (p.z >= -H * hgt(TEXTURE, uv)) {
					hit = true;
					th = t;
					wall = i == 0 && entry != 2;
					break;
				}
				tp = t;
			}
			if (hit && !wall && th > tmin) {
				float lo = tp;
				float hi = th;
				for (int k = 0; k < 10; k++) {
					float mid = 0.5 * (lo + hi);
					vec3 p = o + d * mid;
					if (p.z >= -H * hgt(TEXTURE, vec2(p.x / a + 0.5, p.y + 0.5))) {
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
			vec2 uv = clamp(vec2(p.x / a + 0.5, p.y + 0.5), vec2(0.0), vec2(1.0));
			vec4 c = texture(effect_tex, uv);
			vec3 n = vec3(0.0, 0.0, -1.0);
			float cav = 0.0;
			if (wall) {
				n = entry == 0 ? vec3(sign(-d.x), 0.0, 0.0) : vec3(0.0, sign(-d.y), 0.0);
			} else if (H >= 0.00002) {
				vec2 e = 1.0 / max(tex_size, vec2(1.0));
				float hx = (hgt(TEXTURE, uv + vec2(e.x, 0.0)) - hgt(TEXTURE, uv - vec2(e.x, 0.0))) / (2.0 * e.x * a);
				float hy = (hgt(TEXTURE, uv + vec2(0.0, e.y)) - hgt(TEXTURE, uv - vec2(0.0, e.y))) / (2.0 * e.y);
				vec2 fe = 1.0 / full;
				float gx = (signal(texture(effect_tex, uv + vec2(fe.x, 0.0))) - signal(texture(effect_tex, uv - vec2(fe.x, 0.0)))) * 0.5;
				float gy = (signal(texture(effect_tex, uv + vec2(0.0, fe.y))) - signal(texture(effect_tex, uv - vec2(0.0, fe.y)))) * 0.5;
				float bump = detail * 3.0 * clamp(height / 25.0, 0.0, 1.0);
				n = normalize(vec3(-H * hx - gx * bump, -H * hy - gy * bump, -1.0));
				cav = texture(TEXTURE, uv).b * clamp(height / 30.0, 0.0, 1.0);
			}
			float la = radians(light_angle);
			float le = radians(clamp(light_height, 1.0, 90.0));
			vec3 L = normalize(vec3(cos(la) * cos(le), sin(la) * cos(le), -sin(le)));
			float sh = 1.0;
			if (shadows > 0.001 && H >= 0.00002 && !wall) {
				float texit = min((p.z + H + 0.0004) / max(-L.z, 0.02), 1.5);
				float k = mix(48.0, 3.0, softness);
				float res = 1.0;
				for (int j = 1; j <= 24; j++) {
					float t = texit * float(j) / 24.0;
					vec3 q = p + L * t;
					vec2 uq = vec2(q.x / a + 0.5, q.y + 0.5);
					if (uq.x < 0.0 || uq.y < 0.0 || uq.x > 1.0 || uq.y > 1.0) {
						break;
					}
					float clear = -H * hgt(TEXTURE, uq) - q.z + H * 0.012;
					res = min(res, clamp(k * clear / t, 0.0, 1.0));
				}
				sh = mix(1.0, res, shadows);
			}
			float amb = 0.32;
			float flat_d = max(-L.z, 0.05);
			float diff = max(dot(n, L), 0.0) * sh;
			float lit = (amb + (1.0 - amb) * diff) / (amb + (1.0 - amb) * flat_d);
			float ao = 1.0 - cav * 0.75;
			vec3 V = normalize(-d);
			vec3 hv = normalize(L + V);
			float spec = pow(max(dot(n, hv), 0.0), mix(6.0, 180.0, gloss * gloss)) * shine * (0.35 + 1.4 * gloss) * sh;
			vec3 rgb = c.rgb * lit * ao + vec3(1.0, 0.97, 0.92) * spec * c.a;
			if (wall) {
				rgb *= 0.92;
			}
			outc = vec4(rgb, c.a);
		}
	}
	COLOR = outc;
}

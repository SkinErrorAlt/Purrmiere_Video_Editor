shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D vmap : filter_linear, repeat_disable;
uniform float melt : hint_range(0.0, 1.0) = 0.5;
uniform float thickness : hint_range(0.0, 1.0) = 0.5;
uniform float tilt : hint_range(-80.0, 80.0) = 0.0;
uniform float swivel : hint_range(-80.0, 80.0) = 0.0;
uniform float roll : hint_range(-180.0, 180.0) = 0.0;
uniform float camera_distance : hint_range(0.5, 8.0) = 1.3737;
uniform float fov : hint_range(5.0, 120.0) = 40.0;
uniform float scale : hint_range(0.1, 4.0) = 1.0;
uniform float light_angle : hint_range(-180.0, 180.0) = -120.0;
uniform float light_height : hint_range(2.0, 90.0) = 40.0;
uniform float shadows : hint_range(0.0, 1.0) = 0.75;
uniform float shine : hint_range(0.0, 1.0) = 0.7;
uniform float gloss : hint_range(0.0, 1.0) = 0.75;
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

float surf(sampler2D tx, vec2 uv, float t0, float a) {
	vec4 m = texture(tx, uv);
	float s = m.r + m.g / 255.0;
	return -t0 * (10.0 * s - 1.0);
}

void fragment() {
	vec2 full = max(vec2(textureSize(effect_tex, 0)), vec2(1.0));
	float a = full.x / full.y;
	float f = 0.5 / tan(radians(clamp(fov, 1.0, 170.0)) * 0.5);
	float sc = max(scale, 0.01);
	vec2 s = vec2((UV.x - 0.5) * a, UV.y - 0.5);
	vec3 o = to_local(vec3(0.0, 0.0, -camera_distance)) / sc;
	vec3 d = to_local(vec3(s, f)) / sc;
	float t0 = 0.006 + 0.044 * thickness;
	float zfront = t0 * 9.0 + 0.0005;
	vec3 bmin = vec3(-0.5 * a, -0.5, -zfront);
	vec3 bmax = vec3(0.5 * a, 0.5, t0 + 0.0005);
	vec3 inv = safe_inv(d);
	vec3 t1 = (bmin - o) * inv;
	vec3 t2 = (bmax - o) * inv;
	vec3 tlo = min(t1, t2);
	vec3 thi = max(t1, t2);
	float tmin = max(max(tlo.x, tlo.y), max(tlo.z, 0.0));
	float tmax = min(min(thi.x, thi.y), thi.z);
	vec4 outc = vec4(0.0);
	bool still = melt < 0.00001;
	if (d.z > 1e-6 && tmax > tmin) {
		bool hit = false;
		float th = tmax;
		float tp = tmin;
		if (still) {
			th = -o.z / d.z;
			hit = th >= tmin - 1e-5 && th <= tmax + 1e-5;
		} else {
			float travel = (tmax - tmin) * length(d.xy) * full.y;
			int n = int(clamp(travel / 2.0, 8.0, 96.0));
			float dt = (tmax - tmin) / float(n);
			for (int i = 0; i <= n; i++) {
				float t = tmin + dt * float(i);
				vec3 p = o + d * t;
				vec2 uv = vec2(p.x / a + 0.5, p.y + 0.5);
				if (texture(TEXTURE, uv).b > 0.5 && p.z >= surf(TEXTURE, uv, t0, a)) {
					hit = true;
					th = t;
					break;
				}
				tp = t;
			}
			if (hit && th > tmin) {
				float lo = tp;
				float hi = th;
				for (int k = 0; k < 6; k++) {
					float mid = 0.5 * (lo + hi);
					vec3 p = o + d * mid;
					vec2 uv = vec2(p.x / a + 0.5, p.y + 0.5);
					if (texture(TEXTURE, uv).b > 0.5 && p.z >= surf(TEXTURE, uv, t0, a)) {
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
			vec4 vm = texture(vmap, uv);
			float v = still ? uv.y : vm.r + vm.g / 255.0;
			vec4 c = texture(effect_tex, vec2(uv.x, v));
			vec3 n = vec3(0.0, 0.0, -1.0);
			float la = radians(light_angle);
			float le = radians(clamp(light_height, 1.0, 90.0));
			vec3 L = normalize(vec3(cos(la) * cos(le), sin(la) * cos(le), -sin(le)));
			float sh = 1.0;
			float wet = smoothstep(0.0, 0.08, melt);
			float thick_now = 1.0;
			if (!still) {
				vec2 e = 1.0 / max(tex_size, vec2(1.0));
				float zx = (surf(TEXTURE, uv + vec2(e.x, 0.0), t0, a) - surf(TEXTURE, uv - vec2(e.x, 0.0), t0, a)) / (2.0 * e.x * a);
				float zy = (surf(TEXTURE, uv + vec2(0.0, e.y), t0, a) - surf(TEXTURE, uv - vec2(0.0, e.y), t0, a)) / (2.0 * e.y);
				n = normalize(vec3(zx, zy, -1.0));
				vec4 tm = texture(TEXTURE, uv);
				thick_now = 10.0 * (tm.r + tm.g / 255.0);
				if (shadows > 0.001) {
					float res = 1.0;
					float span = min((zfront + p.z) / max(-L.z, 0.05), 0.9);
					for (int j = 1; j <= 18; j++) {
						float t = span * float(j) / 18.0;
						vec3 q = p + L * t;
						vec2 uq = vec2(q.x / a + 0.5, q.y + 0.5);
						if (uq.x < 0.0 || uq.y < 0.0 || uq.x > 1.0 || uq.y > 1.0) {
							break;
						}
						if (texture(TEXTURE, uq).b < 0.5) {
							continue;
						}
						float clear = surf(TEXTURE, uq, t0, a) - q.z + 0.0015;
						res = min(res, clamp(20.0 * clear / t, 0.0, 1.0));
					}
					sh = mix(1.0, res, shadows);
				}
			}
			float ca = max(c.a, 0.0001);
			vec3 alb = c.rgb / ca;
			float deep = clamp((thick_now - 1.0) / 8.0, 0.0, 1.0) * wet;
			float grey = dot(alb, vec3(0.2126, 0.7152, 0.0722));
			alb = mix(alb, clamp(mix(vec3(grey), alb, 1.35) * 0.86, 0.0, 1.0), deep);
			float amb = 0.3;
			float flat_d = max(-L.z, 0.05);
			float diff = max(dot(n, L), 0.0) * sh;
			float lit = (amb + (1.0 - amb) * diff) / (amb + (1.0 - amb) * flat_d);
			vec3 V = normalize(-d);
			vec3 H = normalize(L + V);
			float fres = 0.04 + 0.96 * pow(1.0 - max(dot(n, V), 0.0), 5.0);
			float spec = pow(max(dot(n, H), 0.0), mix(10.0, 260.0, gloss * gloss)) * (0.3 + 2.2 * gloss) * shine * sh;
			vec3 rgb = alb * lit + vec3(1.0, 0.98, 0.95) * (spec + fres * shine * 0.35 * (0.6 + 0.4 * sh)) * wet;
			if (still) {
				rgb = alb;
			}
			outc = vec4(rgb * c.a, c.a);
		}
	}
	COLOR = outc;
}

shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int finish = 1;
uniform float rise : hint_range(0.0, 1.0) = 1.0;
uniform float height : hint_range(0.0, 100.0) = 30.0;
uniform float pin_size : hint_range(4.0, 60.0) = 12.0;
uniform vec2 origin = vec2(0.5, 0.5);
uniform float spread : hint_range(0.0, 1.0) = 0.0;
uniform float friction : hint_range(0.0, 1.0) = 0.35;
uniform float tilt : hint_range(-80.0, 80.0) = 24.0;
uniform float swivel : hint_range(-80.0, 80.0) = -18.0;
uniform float roll : hint_range(-180.0, 180.0) = 0.0;
uniform float camera_distance : hint_range(0.5, 8.0) = 1.3737;
uniform float fov : hint_range(5.0, 120.0) = 40.0;
uniform float scale : hint_range(0.1, 4.0) = 0.86;
uniform float light_angle : hint_range(-180.0, 180.0) = -130.0;
uniform float light_height : hint_range(2.0, 90.0) = 35.0;
uniform float shadows : hint_range(0.0, 1.0) = 0.85;
uniform float shine : hint_range(0.0, 1.0) = 0.7;
uniform int seed : hint_range(0, 999) = 0;
uniform float px_scale = 1.0;
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

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec4 hex_cell(vec2 p) {
	vec2 s = vec2(1.0, 1.7320508);
	vec4 hc = floor(vec4(p, p - vec2(0.5, 0.8660254)) / s.xyxy) + 0.5;
	vec4 h = vec4(p - hc.xy * s, p - (hc.zw + 0.5) * s);
	return dot(h.xy, h.xy) < dot(h.zw, h.zw) ? vec4(h.xy, hc.xy * s) : vec4(h.zw, (hc.zw + 0.5) * s);
}

float pin_top(sampler2D hm, vec2 centre, float a, float hmax, float far) {
	vec2 uv = vec2(centre.x / a + 0.5, centre.y + 0.5);
	vec4 c = texture(hm, clamp(uv, vec2(0.0), vec2(1.0)));
	float h = c.r + c.g / 255.0;
	float rnd = hash21(centre * 311.7 + float(seed) * 1.37);
	float dist = length(uv - origin) / far;
	float local = clamp((rise * (1.0 + spread * 1.2) - spread * 1.2 * dist) , 0.0, 1.0);
	local = clamp(local * (1.0 + friction * 0.6) - friction * 0.6 * rnd, 0.0, 1.0);
	local = smoothstep(0.0, 1.0, local);
	float stick = 1.0 - friction * 0.18 * hash21(centre * 97.1 + float(seed) * 2.9);
	return hmax * h * local * stick;
}

float field(sampler2D hm, vec2 p, float a, float sp, float hmax, float far, float gap_depth, out vec3 info) {
	vec4 hc = hex_cell(p / sp);
	vec2 off = hc.xy * sp;
	vec2 centre = hc.zw * sp;
	float r = 0.44 * sp;
	float rho = length(off);
	info = vec3(off, 0.0);
	if (abs(centre.x) > 0.5 * a - 0.3 * sp || abs(centre.y) > 0.5 - 0.3 * sp) {
		return gap_depth;
	}
	if (rho >= r) {
		return gap_depth;
	}
	float top = pin_top(hm, centre, a, hmax, far);
	info.z = top;
	float k = rho / r;
	float cap = 0.32 * r * (sqrt(max(1.0 - k * k, 0.0)) - 1.0);
	return -(top + cap);
}

vec3 env(vec3 r) {
	float up = -r.y;
	vec3 sky = mix(vec3(0.55, 0.58, 0.62), vec3(1.0, 0.99, 0.97), smoothstep(0.0, 0.7, up));
	vec3 ground = mix(vec3(0.16, 0.15, 0.14), vec3(0.32, 0.31, 0.3), smoothstep(-0.8, 0.0, up));
	return mix(ground, sky, smoothstep(-0.08, 0.08, up));
}

void fragment() {
	vec2 full = max(vec2(textureSize(effect_tex, 0)), vec2(1.0));
	float a = full.x / full.y;
	float f = 0.5 / tan(radians(clamp(fov, 1.0, 170.0)) * 0.5);
	float sc = max(scale, 0.01);
	vec2 s = vec2((UV.x - 0.5) * a, UV.y - 0.5);
	vec3 o = to_local(vec3(0.0, 0.0, -camera_distance)) / sc;
	vec3 d = to_local(vec3(s, f)) / sc;
	float sp = max(pin_size * max(px_scale, 0.0001) * 2.0 / full.y, 2.0 / full.y);
	float hmax = clamp(height, 0.0, 100.0) / 100.0 * 0.25;
	float gap_depth = 0.9 * sp;
	vec2 oo = origin;
	float far = max(max(length(vec2(0.0, 0.0) - oo), length(vec2(1.0, 0.0) - oo)), max(length(vec2(0.0, 1.0) - oo), length(vec2(1.0, 1.0) - oo)));
	vec3 bmin = vec3(-0.5 * a, -0.5, -hmax - 0.2 * sp - 0.0005);
	vec3 bmax = vec3(0.5 * a, 0.5, gap_depth);
	vec3 inv = safe_inv(d);
	vec3 t1 = (bmin - o) * inv;
	vec3 t2 = (bmax - o) * inv;
	vec3 tlo = min(t1, t2);
	vec3 thi = max(t1, t2);
	float tmin = max(max(tlo.x, tlo.y), max(tlo.z, 0.0));
	float tmax = min(min(thi.x, thi.y), thi.z);
	vec4 outc = vec4(0.0);
	if (d.z > 1e-6 && tmax > tmin) {
		float dxy = length(d.xy);
		float step_t = dxy > 1e-6 ? (0.18 * sp) / dxy : (tmax - tmin);
		int n = int(clamp((tmax - tmin) / step_t, 4.0, 160.0));
		float dt = (tmax - tmin) / float(n);
		bool hit = false;
		float th = tmax;
		float tp = tmin;
		vec3 info = vec3(0.0);
		for (int i = 0; i <= n; i++) {
			float t = tmin + dt * float(i);
			vec3 p = o + d * t;
			vec3 inf;
			float z = field(TEXTURE, p.xy, a, sp, hmax, far, gap_depth, inf);
			if (p.z >= z) {
				hit = true;
				th = t;
				info = inf;
				break;
			}
			tp = t;
		}
		if (hit && th > tmin) {
			float lo = tp;
			float hi = th;
			for (int k = 0; k < 7; k++) {
				float mid = 0.5 * (lo + hi);
				vec3 p = o + d * mid;
				vec3 inf;
				float z = field(TEXTURE, p.xy, a, sp, hmax, far, gap_depth, inf);
				if (p.z >= z) {
					hi = mid;
				} else {
					lo = mid;
				}
			}
			th = hi;
		}
		if (hit) {
			vec3 p = o + d * th;
			vec3 inf;
			float z = field(TEXTURE, p.xy, a, sp, hmax, far, gap_depth, inf);
			vec4 hc = hex_cell(p.xy / sp);
			vec2 centre = hc.zw * sp;
			vec2 off = hc.xy * sp;
			float r = 0.44 * sp;
			float rho = length(off);
			bool gap = z >= gap_depth - 1e-6;
			float top = inf.z;
			bool side = !gap && p.z > -(top) + 0.002 * sp && rho > r * 0.93;
			vec3 n = vec3(0.0, 0.0, -1.0);
			if (gap) {
				n = vec3(0.0, 0.0, -1.0);
			} else if (rho > r * 0.985 || side) {
				n = normalize(vec3(off, 0.0));
			} else {
				float k = rho / r;
				float sq = sqrt(max(1.0 - k * k, 0.02));
				n = normalize(vec3(off / r * 0.32 / sq, -1.0));
			}
			vec2 uv = clamp(vec2(centre.x / a + 0.5, centre.y + 0.5), vec2(0.0), vec2(1.0));
			vec4 pc = texture(effect_tex, uv);
			float pa = max(pc.a, 0.0001);
			vec3 pic = pc.rgb / pa;
			float la = radians(light_angle);
			float le = radians(clamp(light_height, 1.0, 90.0));
			vec3 L = normalize(vec3(cos(la) * cos(le), sin(la) * cos(le), -sin(le)));
			float sh = 1.0;
			if (shadows > 0.001) {
				float res = 1.0;
				float span = min((hmax + 0.3 * sp + p.z) / max(-L.z, 0.05), 0.6);
				vec3 start = p + n * 0.02 * sp;
				for (int j = 1; j <= 20; j++) {
					float t = span * float(j) / 20.0;
					vec3 q = start + L * t;
					vec3 qi;
					float zq = field(TEXTURE, q.xy, a, sp, hmax, far, gap_depth, qi);
					float clear = zq - q.z;
					res = min(res, clamp(10.0 * clear / t + 0.2, 0.0, 1.0));
				}
				sh = mix(1.0, res, shadows);
			}
			vec3 V = normalize(-d);
			vec3 H = normalize(L + V);
			vec3 R = reflect(-V, n);
			float ndl = max(dot(n, L), 0.0);
			vec3 steel = vec3(0.72, 0.73, 0.75);
			vec3 base_col = finish == 0 ? steel : (finish == 1 ? pic : mix(steel, pic, 0.55));
			float metal = finish == 0 ? 1.0 : (finish == 1 ? 0.25 : 0.8);
			if (side) {
				base_col = finish == 1 ? mix(steel, pic, 0.25) * 0.8 : steel * 0.85;
				metal = 0.9;
			}
			float occl = gap ? 0.18 : 1.0;
			vec3 diffuse = base_col * (0.28 + 0.9 * ndl * sh) * (1.0 - metal * 0.6);
			vec3 refl = env(R) * base_col * metal * (0.45 + 0.55 * sh);
			float spec = pow(max(dot(n, H), 0.0), side ? 40.0 : 90.0) * shine * 1.6 * sh;
			vec3 rgb = (diffuse + refl) * occl + vec3(1.0, 0.98, 0.95) * spec * occl;
			if (gap) {
				rgb = base_col * 0.06;
			}
			float alpha = pc.a;
			outc = vec4(rgb * alpha, alpha);
		}
	}
	COLOR = outc;
}

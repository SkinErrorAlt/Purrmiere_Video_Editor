shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 position = vec2(0.6, 0.55);
uniform float angle : hint_range(-180.0, 180.0) = -8.0;
uniform float size : hint_range(10.0, 1000.0) = 130.0;
uniform int style : hint_range(0, 3) = 0;
uniform float rate : hint_range(0.2, 20.0) = 6.0;
uniform float start : hint_range(0.0, 600.0) = 0.0;
uniform int shots : hint_range(0, 500) = 0;
uniform float smoke : hint_range(0.0, 1.0) = 0.4;
uniform float light : hint_range(0.0, 1.0) = 0.6;
uniform bool vary = true;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;
uniform float seq_fps = 30.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec4 h42(vec2 p) {
	vec4 q = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	q += dot(q, q.wzxy + 33.33);
	return fract((q.xxyz + q.yzzw) * q.zywx);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h12(i);
	float b = h12(i + vec2(1.0, 0.0));
	float c = h12(i + vec2(0.0, 1.0));
	float d = h12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.07 + vec2(13.1, 7.7);
		a *= 0.5;
	}
	return s / 0.9375;
}

float lobe(vec2 q, float ang, float len, float wid) {
	vec2 d = vec2(cos(ang), sin(ang));
	float along = dot(q, d);
	float side = dot(q, vec2(-d.y, d.x));
	float u = along / max(len, 0.001);
	if (u <= 0.0 || u >= 1.0) {
		return 0.0;
	}
	float w = wid * len * 0.42 * sqrt(u) * pow(1.0 - u, 0.8) + 0.012;
	return exp(-side * side / (w * w)) * pow(1.0 - u, 1.3) * smoothstep(0.0, 0.12, u + 0.05);
}

float flash_shape(vec2 q, int st, vec4 r1, vec4 r2, float fire) {
	float j = vary ? 1.0 : 0.0;
	float s = 0.0;
	float core = exp(-(pow((q.x - 0.05) / 0.12, 2.0) + pow(q.y / 0.075, 2.0)));
	s += core * 3.6;
	float body_len = st == 2 ? 1.2 : (st == 1 ? 0.7 : (st == 3 ? 0.55 : 0.95));
	s += lobe(q, 0.0, body_len * mix(1.0, mix(0.8, 1.2, r2.x), j), 1.5) * 0.75;
	s += exp(-dot(q - vec2(0.12, 0.0), q - vec2(0.12, 0.0)) / 0.03) * 1.2;
	if (st == 0) {
		s += lobe(q, 0.0, 1.55 * mix(1.0, mix(0.75, 1.25, r1.x), j), 0.32) * 1.7;
		s += lobe(q, radians(28.0 + 10.0 * (r1.y - 0.5) * j), 0.7 * mix(1.0, mix(0.6, 1.3, r1.z), j), 0.5) * 1.25;
		s += lobe(q, radians(-28.0 + 10.0 * (r1.w - 0.5) * j), 0.7 * mix(1.0, mix(0.6, 1.3, r2.x), j), 0.5) * 1.25;
		s += lobe(q, radians(62.0 + 12.0 * (r2.y - 0.5) * j), 0.42 * mix(1.0, mix(0.5, 1.4, r2.z), j), 0.5) * 0.9;
		s += lobe(q, radians(-62.0 + 12.0 * (r2.w - 0.5) * j), 0.42 * mix(1.0, mix(0.5, 1.4, r1.x), j), 0.5) * 0.9;
	} else if (st == 1) {
		s += lobe(q, 0.0, 0.7 * mix(1.0, mix(0.8, 1.2, r1.x), j), 0.7) * 1.5;
		for (int k = 0; k < 6; k++) {
			float fk = float(k);
			vec4 rk = h42(vec2(fk * 3.1 + r1.y * 50.0 * j, r2.z * 40.0 * j + 7.0));
			float a = radians(mix(-80.0, 80.0, (fk + 0.5 + (rk.x - 0.5) * 0.7) / 6.0));
			s += lobe(q, a, mix(0.45, 0.85, rk.y) * (1.0 - 0.3 * abs(a)), 0.42) * mix(0.9, 1.4, rk.z);
		}
	} else if (st == 2) {
		s += lobe(q, 0.0, 1.35 * mix(1.0, mix(0.8, 1.2, r1.x), j), 1.05) * 1.7;
		s += lobe(q, radians(16.0 * (r1.y - 0.5) * j + 14.0), 0.95, 0.7) * 0.9;
		s += lobe(q, radians(16.0 * (r1.z - 0.5) * j - 14.0), 0.95, 0.7) * 0.9;
		s += lobe(q, radians(48.0 + 10.0 * (r2.x - 0.5) * j), 0.45, 0.6) * 0.7;
		s += lobe(q, radians(-48.0 + 10.0 * (r2.y - 0.5) * j), 0.45, 0.6) * 0.7;
	} else {
		s += lobe(q, 0.0, 0.62 * mix(1.0, mix(0.75, 1.25, r1.x), j), 0.45) * 1.3;
		s += lobe(q, radians(82.0 + 10.0 * (r1.y - 0.5) * j), 0.95 * mix(1.0, mix(0.75, 1.25, r1.z), j), 0.38) * 1.7;
		s += lobe(q, radians(-82.0 + 10.0 * (r1.w - 0.5) * j), 0.95 * mix(1.0, mix(0.75, 1.25, r2.x), j), 0.38) * 1.7;
		s += lobe(q, radians(40.0 + 10.0 * (r2.y - 0.5) * j), 0.5, 0.45) * 0.9;
		s += lobe(q, radians(-40.0 + 10.0 * (r2.z - 0.5) * j), 0.5, 0.45) * 0.9;
	}
	return s * fire * 1.9;
}

vec3 fire_light(float e) {
	return vec3(e, e * e * 0.7 + e * 0.22, e * e * e * 0.35);
}

void fragment() {
	vec4 pic = texture(TEXTURE, UV);
	float a0 = pic.a;
	vec3 rgb = a0 > 0.0001 ? pic.rgb / a0 : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 p = UV * sz;
	vec2 mz = position * sz;
	float L = max(size * ps, 1.0);
	float sd = mod(float(seed), 9973.0);
	float r8 = max(rate, 0.2);
	float fps = max(seq_fps, 1.0);
	float t = clip_time - start;
	vec3 add = vec3(0.0);
	float scene = 0.0;
	float smoke_d = 0.0;
	float smoke_lit = 0.0;
	if (t >= 0.0) {
		float kn = floor(t * r8 + 0.0001);
		if (shots > 0) {
			kn = min(kn, float(shots) - 1.0);
		}
		for (int n = 0; n < 12; n++) {
			float k = kn - float(n);
			if (k < 0.0) {
				break;
			}
			float ts = k / r8;
			float age = t - ts;
			vec4 r1 = h42(vec2(k * 1.31 + 5.0, sd + 3.0));
			vec4 r2 = h42(vec2(k * 0.77 + 41.0, sd + 9.0));
			float jit = vary ? 1.0 : 0.0;
			float ang = radians(angle + (r1.z - 0.5) * 6.0 * jit);
			vec2 dir = vec2(cos(ang), sin(ang));
			vec2 rel = p - mz;
			vec2 q = vec2(dot(rel, dir), dot(rel, vec2(-dir.y, dir.x))) / L;
			float fi = floor(age * fps + 0.02);
			if (fi < 2.0) {
				float strength = fi < 0.5 ? 1.0 : 0.33;
				float grow = fi < 0.5 ? 1.0 : 1.2;
				float sc = mix(1.0, mix(0.85, 1.15, r2.w), jit);
				vec2 qq = q / (grow * sc);
				qq.y /= mix(1.0, mix(0.75, 1.05, r1.w), jit);
				float ra = length(qq);
				if (ra < 2.6) {
					vec2 polar = vec2(atan(qq.y, qq.x) * 2.2, log(ra + 0.04) * 3.2);
					float fire = 0.35 + 1.25 * pow(fbm(polar * vec2(1.6, 1.0) + vec2(0.0, -fi * 2.0) + (vary ? r1.xy * 37.0 : vec2(3.0, 5.0))), 1.3) * (0.75 + 0.5 * fbm(qq * 9.0 + (vary ? r2.yz * 23.0 : vec2(1.0, 2.0))));
					float e = flash_shape(qq, style, r1, r2, fire) * strength;
					if (fi > 0.5) {
						e = min(e, 1.4);
					}
					add += fire_light(e);
				}
				float flick = vary ? mix(0.75, 1.0, r2.x) : 0.9;
				add += vec3(1.0, 0.62, 0.28) * exp(-length(q) / 0.55) * 0.45 * strength * flick;
				scene = max(scene, strength * flick);
			}
			if (smoke > 0.0 && age < 2.2) {
				vec4 r3 = h42(vec2(k * 2.13 + 17.0, sd + 23.0));
				float travel = 1.5 * (1.0 - exp(-age * 3.5)) * mix(0.75, 1.2, r3.x);
				vec2 c = vec2(0.35 + travel, (r3.y - 0.5) * 0.3) ;
				vec2 world_up = vec2(dot(vec2(0.0, -1.0), dir), dot(vec2(0.0, -1.0), vec2(-dir.y, dir.x)));
				c += world_up * age * 0.35;
				float rad = 0.25 + 0.75 * sqrt(age) * mix(0.8, 1.2, r3.z);
				vec2 dq = (q - c) / rad;
				float dl = length(dq);
				if (dl < 1.3) {
					float nz = fbm(dq * 2.2 + r3.zw * 31.0 + vec2(age * 0.6, -age * 0.4));
					float body = smoothstep(1.2, 0.2, dl + (nz - 0.5) * 0.9);
					float dens = body * smoothstep(0.0, 0.05, age) * exp(-age / 0.6) * 0.32;
					smoke_d = 1.0 - (1.0 - smoke_d) * (1.0 - clamp(dens * smoke, 0.0, 1.0));
					if (floor(age * fps + 0.02) < 1.0) {
						smoke_lit = max(smoke_lit, body);
					}
				}
			}
		}
	}
	vec2 dv = (p - mz) / max(L * 5.0, 1.0);
	float fall = 1.0 / (1.0 + dot(dv, dv));
	float lit = light * scene * (0.25 + 0.75 * fall);
	vec3 warm = vec3(1.0, 0.68, 0.38);
	vec3 o = rgb * (1.0 + warm * lit * 1.6) + warm * lit * 0.05;
	vec3 smoke_col = mix(vec3(0.5, 0.49, 0.47), vec3(1.0, 0.7, 0.4), smoke_lit * 0.8) * (0.55 + 0.45 * clamp(1.0 - dot(o, vec3(0.33)), 0.0, 1.0));
	o = mix(o, max(smoke_col, o * 0.6), smoke_d);
	o += vec3(1.0) - exp(-add * 1.2);
	COLOR = vec4(clamp(o, 0.0, 1.0) * a0, a0);
}

shader_type canvas_item;
render_mode blend_disabled;

uniform float decay : hint_range(0.0, 1.0) = 0.45;
uniform float edge_rot : hint_range(0.0, 1.0) = 0.6;
uniform float foxing : hint_range(0.0, 1.0) = 0.5;
uniform float ghost : hint_range(0.0, 1.0) = 0.5;
uniform float thickness : hint_range(0.0, 40.0) = 7.0;
uniform float view_angle : hint_range(-180.0, 180.0) = 40.0;
uniform float haze : hint_range(0.0, 1.0) = 0.35;
uniform float glass_tint : hint_range(0.0, 1.0) = 0.5;
uniform float wave : hint_range(0.0, 1.0) = 0.3;
uniform float scale : hint_range(0.2, 3.0) = 1.0;
uniform vec4 backing : source_color = vec4(0.07, 0.06, 0.05, 1.0);
uniform bool flip = false;
uniform int seed : hint_range(0, 999) = 7;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
vec2 h22(vec2 p) { return vec2(h12(p), h12(p + 19.19)); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + 3.7; a *= 0.5; } return s / 0.96875; }
float fbm3(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 3; i++) { s += a * vn(p); p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + 3.7; a *= 0.5; } return s / 0.875; }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }

vec3 tarnish(float s) {
	vec3 c = mix(vec3(1.0), vec3(1.0, 0.86, 0.6), smoothstep(0.0, 0.35, s));
	c = mix(c, vec3(0.7, 0.46, 0.28), smoothstep(0.35, 0.6, s));
	c = mix(c, vec3(0.5, 0.3, 0.47), smoothstep(0.6, 0.78, s));
	c = mix(c, vec3(0.24, 0.3, 0.52), smoothstep(0.78, 0.9, s));
	return mix(c, vec3(0.16, 0.16, 0.2), smoothstep(0.9, 1.0, s));
}

float spots(vec2 q, float cell, float chance, float sd, out float halo) {
	vec2 id = floor(q / cell);
	vec2 f = q / cell - id;
	vec2 r = h22(id + sd);
	vec2 at = 0.3 + 0.4 * h22(id + sd + 7.3);
	float rr = mix(0.05, 0.12, r.y);
	vec2 d = f - at;
	float wob = 1.0 + 0.45 * (vn(vec2(atan(d.y, d.x) * 1.6, 0.0) + id * 3.1) - 0.5) + 0.25 * (vn(q / cell * 9.0) - 0.5);
	float dist = length(d) * wob;
	float on = step(1.0 - chance, r.x);
	halo = on * smoothstep(rr * 2.1, rr * 0.9, dist);
	return on * smoothstep(rr, rr * 0.55, dist);
}

void fragment() {
	vec2 ts = max(tex_size, vec2(1.0));
	float asp = ts.x / ts.y;
	float sd = float(seed) * 13.37;
	vec2 q = UV * vec2(asp, 1.0) / scale + vec2(sd * 0.11, sd * 0.07);
	vec2 su = flip ? vec2(1.0 - UV.x, UV.y) : UV;
	vec2 wq = UV * vec2(asp, 1.0) * vec2(1.2, 5.5) + sd;
	vec2 wv = vec2(vn(wq) - 0.5, vn(wq + 31.7) - 0.5) + 0.5 * vec2(vn(wq * 2.3 + 4.0) - 0.5, vn(wq * 2.3 + 9.0) - 0.5);
	su += wv * wave * vec2(0.0035, 0.006);
	vec4 c0 = texture(TEXTURE, su);
	vec3 sharp = unp(c0);
	vec3 soft = vec3(0.0);
	vec2 tx = px_scale / ts;
	for (int i = 0; i < 10; i++) {
		float fi = float(i) + 0.5;
		float an = fi * 2.39996;
		float rd = sqrt(fi / 10.0) * 7.0;
		soft += unp(texture(TEXTURE, su + vec2(cos(an), sin(an)) * rd * tx));
	}
	soft /= 10.0;
	vec3 main_c = mix(sharp, soft, haze * 0.75);
	main_c = main_c * (1.0 - 0.1 * haze) + haze * 0.07 * vec3(0.88, 0.9, 0.86);
	float ar = radians(view_angle);
	vec2 gdir = vec2(cos(ar), sin(ar));
	vec4 gc = texture(TEXTURE, su + gdir * thickness * tx);
	vec3 gs = unp(gc) * gc.a;
	vec3 tint = mix(vec3(1.0), vec3(0.83, 0.93, 0.86), glass_tint);
	vec3 front = gs * ghost * 0.24;
	vec2 wp = vec2(fbm(q * 1.3), fbm(q * 1.3 + 5.2));
	float n = fbm(q * 2.0 + wp * 1.6);
	float fine = fbm3(q * 16.0 + wp * 4.0);
	float e = min(min(UV.x, 1.0 - UV.x) * asp, min(UV.y, 1.0 - UV.y));
	float edge_term = edge_rot * decay * 0.85 * pow(1.0 - smoothstep(0.0, 0.32, e), 1.4);
	float field = n + edge_term + (fine - 0.5) * 0.14;
	float th = 1.0 - decay * 0.5;
	float on = step(0.0005, decay);
	float rot = smoothstep(th, th + 0.012, field) * on;
	float band = 0.05;
	float s = clamp((field - (th - band)) / band, 0.0, 1.0) * on;
	float wide = clamp((field - (th - band * 5.0)) / (band * 5.0), 0.0, 1.0) * on;
	vec3 tr = tarnish(s);
	vec3 tm = mix(vec3(dot(tr, vec3(0.333))), tr, 0.55) * mix(vec3(1.0), vec3(1.0, 0.96, 0.88), wide * wide);
	vec3 silver = main_c * tint * 0.93 * tm;
	float smoke = wide * wide * (0.55 + 0.45 * fbm3(q * 7.0 + wp));
	silver = mix(silver, vec3(dot(silver, vec3(0.3, 0.5, 0.2))) * 0.8 + vec3(0.05, 0.05, 0.045), smoke * 0.6);
	vec2 P = UV * ts / max(px_scale, 0.0001);
	float speck = smoothstep(0.0, 0.06, vn(P / 2.3 + sd) - (1.0 - 0.45 * pow(wide, 3.0)));
	speck = max(speck, smoothstep(0.0, 0.05, vn(P / 5.5 + sd + 50.0) - (1.0 - 0.3 * pow(wide, 4.0))));
	silver = mix(silver, backing.rgb * tint, speck * on);
	silver += front;
	float deep = smoothstep(th, th + 0.18, field);
	float islands = step(0.6 + 0.3 * deep, fbm3(q * 34.0 + wp * 2.0)) * (1.0 - deep);
	vec3 back = backing.rgb * (0.65 + 0.7 * fbm3(q * 45.0 + 11.0)) * mix(vec3(1.0), vec3(1.15, 1.0, 0.85), vn(q * 6.0));
	vec3 rotted = back * tint + front * 1.1;
	rotted = mix(rotted, mix(main_c, vec3(dot(main_c, vec3(0.333))), 0.4) * tint * 0.62 + front, islands * 0.85);
	vec3 o = mix(silver, rotted, rot);
	float halo_a = 0.0;
	float halo_b = 0.0;
	float halo_c = 0.0;
	float cluster = smoothstep(0.4, 0.72, fbm3(q * 1.7 + 21.0));
	float sp = spots(q, 0.035, foxing * 0.55 * cluster, sd, halo_a);
	sp = max(sp, spots(q + 3.1, 0.09, foxing * 0.3 * cluster, sd + 5.0, halo_b));
	sp = max(sp, spots(q + 7.7, 0.24, foxing * 0.14, sd + 9.0, halo_c));
	float halo = max(halo_a, max(halo_b, halo_c));
	o = mix(o, mix(o, vec3(dot(o, vec3(0.333))), 0.5) * vec3(0.86, 0.8, 0.7), halo * 0.6);
	o = mix(o, back * vec3(1.9, 1.6, 1.3) + front, sp * 0.85);
	COLOR = vec4(clamp(o, 0.0, 1.0) * c0.a, c0.a);
}
